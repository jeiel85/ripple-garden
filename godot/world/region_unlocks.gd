class_name RegionUnlocks
extends RefCounted

## Which regions are open (P1-010, BALANCE §4): progression.json `region_unlocks` names, for every region,
## either the start or a condition on another region — its restoration stage and how many of its species
## have been met. Unlocking is derived from the save every time, never stored, so it can never disagree
## with the progress it depends on.
##
## Travelling needs a second region's world, which arrives with P2-001; until then an open region other
## than the current one says honestly that its world comes in a later update.

## Map states of a region.
const CURRENT := "current"
const LOCKED := "locked"
const COMING := "coming"

var _state: Node

func _init(game_state: Node) -> void:
	_state = game_state

## The unlock entry of a region ({} if none).
static func entry(region_id: String) -> Dictionary:
	for unlock in ContentDB.progression.get("region_unlocks", []):
		if unlock["region_id"] == region_id:
			return unlock
	return {}

func is_unlocked(region_id: String) -> bool:
	return _is_unlocked(region_id, 0)

func _is_unlocked(region_id: String, depth: int) -> bool:
	var unlock := entry(region_id)
	if unlock.is_empty() or depth > 16:
		return false
	var condition: Dictionary = unlock["condition"]
	if condition.get("type", "") == "start":
		return true
	var previous: String = condition["region"]
	return _is_unlocked(previous, depth + 1) \
		and _state.get_restoration_level(previous) >= int(condition["restoration_level"]) \
		and species_met(previous) >= int(condition["unique_fish"])

## Species of a region met at least once.
func species_met(region_id: String) -> int:
	var met := 0
	for fish_def in ContentDB.get_fish_for_region(region_id):
		if _state.has_discovered(fish_def["id"]):
			met += 1
	return met

static func species_total(region_id: String) -> int:
	return ContentDB.get_fish_for_region(region_id).size()

## What the map shows for a region: CURRENT, COMING (open, its world arrives later) or LOCKED.
func state_of(region_id: String, current_region: String) -> String:
	if region_id == current_region:
		return CURRENT
	return COMING if is_unlocked(region_id) else LOCKED

## The condition of a locked region as {"region", "level", "fish", "level_now", "fish_now"} ({} for the start).
func condition_of(region_id: String) -> Dictionary:
	var unlock := entry(region_id)
	if unlock.is_empty() or unlock["condition"].get("type", "") == "start":
		return {}
	var condition: Dictionary = unlock["condition"]
	var previous: String = condition["region"]
	return {
		"region": previous,
		"level": int(condition["restoration_level"]),
		"fish": int(condition["unique_fish"]),
		"level_now": _state.get_restoration_level(previous),
		"fish_now": species_met(previous),
	}
