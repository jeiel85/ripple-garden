class_name OfflineService
extends RefCounted

## What happened by the pond while the player was away (GDD §14, BALANCE §7, P1-007). Not a full
## simulation: an aggregate over the time away (already clamped to the 12 h cap by TimeService).
##
##   fish     species that were released here have quietly multiplied: a few more of each, scaled by
##            hours away and by how restored the pond is (a living pond breeds better)
##   ripples  a small trickle of Ripple, so returning is a little gift, never a reason to stay away
##   nothing  restoration points: progress stages are earned by playing, so 8 hours away can never
##            skip a stage (BALANCE §7)
##
## Every number comes from balance.json `offline`. The result is a Summary the interface turns into a
## short "while you were away" card; the world shows the new fish by itself (population events).
## Randomness only through the RandomNumberGenerator given, so a seed reproduces a summary.

class Summary:
	var seconds := 0
	## {fish_id: how many were added}
	var fish_added: Dictionary = {}
	var ripple := 0

	func is_empty() -> bool:
		return fish_added.is_empty() and ripple == 0

	func hours() -> float:
		return seconds / 3600.0

	## Adds another absence that came before this one was shown (both already applied to the save).
	func merge(other: Summary) -> void:
		seconds += other.seconds
		ripple += other.ripple
		for fish_id in other.fish_added:
			fish_added[fish_id] = int(fish_added.get(fish_id, 0)) + int(other.fish_added[fish_id])

var _state: Node
var _config: Dictionary

func _init(game_state: Node, config: Dictionary) -> void:
	_state = game_state
	_config = config

## Applies the time away to the region and returns what changed. Shorter absences than
## `offline.min_minutes` change nothing (a quick app switch is not "being away").
func apply(region_id: String, seconds: int, rng: RandomNumberGenerator) -> Summary:
	var summary := Summary.new()
	summary.seconds = seconds
	if seconds < int(_config["min_minutes"]) * 60:
		return summary
	var hours := minf(seconds / 3600.0, float(_config["cap_hours"]))
	var level: int = _state.get_restoration_level(region_id)
	# Each released species grows by about one fish per `hours_per_fish` hours, faster in a restored pond,
	# capped per species so a long absence never floods the pond.
	var speed := 1.0 + float(_config["level_speedup"]) * level
	var expected := hours * speed / float(_config["hours_per_fish"])
	for fish_id in _state.get_species_population(region_id):
		var whole := int(floorf(expected))
		var extra := 1 if rng.randf() < expected - whole else 0
		var added := mini(whole + extra, int(_config["max_fish_per_species"]))
		if added > 0:
			_state.add_population(region_id, fish_id, added)
			summary.fish_added[fish_id] = added
	summary.ripple = mini(roundi(hours * (float(_config["ripple_per_hour"]) + float(_config["ripple_per_level_hour"]) * level)),
		int(_config["max_ripple"]))
	if summary.ripple > 0:
		_state.add_ripple(summary.ripple)
	return summary
