class_name RestorationService
extends RefCounted

## Restoration levels (GDD §9, BALANCE §4, UI_UX §6). Releasing fish earns restoration points
## (CatchService); points only accumulate. A level is *earned* when the points reach its
## threshold, but it takes effect when the player chooses to restore, which is what triggers the
## visible change in the world. Levels cannot be lost and points are never spent.
##
## In the vertical slice a region can reach `vertical_slice.max_restoration_level` (5); points
## keep accumulating past that, so raising the cap later (P1-001) loses nothing.

class Requirement:
	var region_id := ""
	var level := 0
	## Level the player would reach by restoring now (level + 1), or `level` when at the cap.
	var next_level := 0
	var points := 0
	var points_needed := 0
	var can_restore := false
	var at_cap := false

var _state: Node
var _thresholds: Array
var _slice: Dictionary

## `thresholds` is progression.json `restoration_points` (cumulative points per level),
## `slice` is balance.json `vertical_slice`.
func _init(game_state: Node, thresholds: Array, slice: Dictionary) -> void:
	_state = game_state
	_thresholds = thresholds
	_slice = slice

## Highest level the player can currently reach in the region.
func max_level(region_id: String) -> int:
	if region_id == _slice["region_id"]:
		return mini(int(_slice["max_restoration_level"]), _thresholds.size() - 1)
	return 0

## Cumulative points needed for `level`; clamped to the table.
func points_for_level(level: int) -> int:
	return int(_thresholds[clampi(level, 0, _thresholds.size() - 1)])

## The level the accumulated points would justify, ignoring the cap and the player's choice.
func level_for_points(points: int) -> int:
	var level := 0
	for i in _thresholds.size():
		if points >= int(_thresholds[i]):
			level = i
	return level

func get_requirement(region_id: String) -> Requirement:
	var requirement := Requirement.new()
	requirement.region_id = region_id
	requirement.level = _state.get_restoration_level(region_id)
	requirement.points = _state.get_restoration_points(region_id)
	requirement.at_cap = requirement.level >= max_level(region_id)
	if requirement.at_cap:
		requirement.next_level = requirement.level
		requirement.points_needed = 0
	else:
		requirement.next_level = requirement.level + 1
		requirement.points_needed = points_for_level(requirement.next_level)
		requirement.can_restore = requirement.points >= requirement.points_needed
	return requirement

func can_restore(region_id: String) -> bool:
	return get_requirement(region_id).can_restore

## Raises the region by one level when the points allow it. Returns whether it did.
func restore(region_id: String) -> bool:
	var requirement := get_requirement(region_id)
	if not requirement.can_restore:
		return false
	_state.set_restoration_level(region_id, requirement.next_level)
	return true

## How many levels the current points could still pay for (for a gentle "ready" hint in the UI).
func levels_available(region_id: String) -> int:
	var level: int = _state.get_restoration_level(region_id)
	var reachable := mini(level_for_points(_state.get_restoration_points(region_id)), max_level(region_id))
	return maxi(0, reachable - level)
