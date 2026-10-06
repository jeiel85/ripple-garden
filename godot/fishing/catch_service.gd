class_name CatchService
extends RefCounted

## What happens to a fish after the fight (GDD §3 core loop, BALANCE §5-6):
##
##   begin_catch   caught -> recorded in the journal and saved as `pending_catch` at once, so
##                 the discovery survives a crash or force-close while the player inspects it.
##   release_catch the player lets it go -> it joins the region's population, earns Ripple,
##                 restoration points and (on first discovery) Memory, and the pending catch is
##                 cleared.
##
## Every number comes from balance.json `rewards`. Repeat catches of a species pay a little less
## each time but never nothing (BALANCE §6). There is deliberately no way to sell a fish.

class Reward:
	var ripple := 0
	var memory := 0
	var restoration_points := 0
	var population := 0

var _game_state: Node
var _rewards: Dictionary

func _init(game_state: Node, rewards: Dictionary) -> void:
	_game_state = game_state
	_rewards = rewards

## Records the catch and returns the pending-catch info (also stored in the save).
func begin_catch(encounter: EncounterResolver.Encounter, region_id: String) -> Dictionary:
	var first_discovery: bool = _game_state.record_encounter(encounter.fish_id, encounter.size_cm, encounter.behavior)
	var pending := {
		"fish_id": encounter.fish_id,
		"size_cm": encounter.size_cm,
		"region_id": region_id,
		"rarity": encounter.rarity,
		"first_discovery": first_discovery,
	}
	_game_state.set_pending_catch(pending)
	EventBus.fish_caught.emit(encounter.fish_id, encounter.size_cm, first_discovery)
	return pending

## Releases the pending catch. Returns null when there is nothing to release.
func release_catch() -> Reward:
	var pending: Dictionary = _game_state.get_pending_catch()
	if pending.is_empty():
		return null
	var fish_id: String = pending["fish_id"]
	var region_id: String = pending["region_id"]
	var size_cm: float = float(pending["size_cm"])
	var rarity := clampi(int(pending["rarity"]), 1, 5)
	var first_discovery: bool = pending["first_discovery"] == true

	var releases_before: int = _game_state.get_collection_record(fish_id)["releases"]
	var decay := repeat_multiplier(releases_before)

	var reward := Reward.new()
	var ripple_range: Dictionary = _rewards["ripple_by_rarity"][str(rarity)]
	reward.ripple = maxi(1, roundi(lerpf(float(ripple_range["min"]), float(ripple_range["max"]), _size_share(fish_id, size_cm)) * decay))
	if first_discovery:
		reward.memory = int(_rewards["memory_first_discovery_by_rarity"][str(rarity)])
	var base_points := int(_rewards["restoration_points_by_rarity"][str(rarity)])
	if first_discovery:
		base_points += int(_rewards["first_discovery_restoration_bonus"])
	reward.restoration_points = maxi(1, roundi(base_points * decay))

	_game_state.record_release(fish_id)
	_game_state.add_population(region_id, fish_id, 1)
	_game_state.add_restoration_points(region_id, reward.restoration_points)
	_game_state.add_ripple(reward.ripple)
	if reward.memory > 0:
		_game_state.add_memory(reward.memory)
	reward.population = _game_state.get_population(region_id, fish_id)
	_game_state.clear_pending_catch()
	EventBus.fish_released.emit(fish_id, region_id, size_cm)
	return reward

## Reward multiplier for the next release of a species that has been released `releases` times.
func repeat_multiplier(releases: int) -> float:
	return maxf(float(_rewards["repeat_floor"]), 1.0 - float(_rewards["repeat_decay_per_release"]) * maxi(0, releases))

## 0..1 position of the fish's size inside its species range (bigger fish pay more Ripple).
func _size_share(fish_id: String, size_cm: float) -> float:
	var def := ContentDB.get_fish(fish_id)
	if def.is_empty():
		return 0.0
	var range_cm: Dictionary = def["size_cm"]
	return clampf((size_cm - float(range_cm["min"])) / (float(range_cm["max"]) - float(range_cm["min"])), 0.0, 1.0)
