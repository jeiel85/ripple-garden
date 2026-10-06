extends TestCase

## P0-020 (logic): restoration levels 0..5 in the vertical slice — earned by points, applied by
## the player's choice, never lost, capped by the slice.

const REGION := "region_01_quiet_pond"

func _setup() -> Array:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	var service := RestorationService.new(state, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	return [state, service]

func test_level_for_points_follows_the_threshold_table() -> void:
	var service: RestorationService = _setup()[1]
	var thresholds: Array = ContentDB.progression["restoration_points"]
	assert_eq(service.level_for_points(0), 0)
	assert_eq(service.level_for_points(int(thresholds[1]) - 1), 0)
	assert_eq(service.level_for_points(int(thresholds[1])), 1)
	assert_eq(service.level_for_points(int(thresholds[2]) - 1), 1)
	assert_eq(service.level_for_points(int(thresholds[2])), 2)
	assert_eq(service.level_for_points(int(thresholds.back())), thresholds.size() - 1)
	assert_eq(service.level_for_points(10_000_000), thresholds.size() - 1)

func test_fresh_region_needs_the_first_threshold() -> void:
	var parts := _setup()
	var requirement: RestorationService.Requirement = parts[1].get_requirement(REGION)
	assert_eq(requirement.level, 0)
	assert_eq(requirement.next_level, 1)
	assert_eq(requirement.points_needed, int(ContentDB.progression["restoration_points"][1]))
	assert_false(requirement.can_restore)
	assert_false(requirement.at_cap)
	assert_false(parts[1].restore(REGION), "restoring without enough points must fail")
	assert_eq(parts[0].get_restoration_level(REGION), 0)
	parts[0].free()

func test_restoring_raises_one_level_and_keeps_the_points() -> void:
	var parts := _setup()
	var state: Node = parts[0]
	var service: RestorationService = parts[1]
	var changed: Array = []
	var handler := func(region_id: String, level: int) -> void: changed.append([region_id, level])
	EventBus.region_restoration_changed.connect(handler)
	state.add_restoration_points(REGION, int(ContentDB.progression["restoration_points"][1]))
	assert_true(service.can_restore(REGION))
	assert_true(service.restore(REGION))
	EventBus.region_restoration_changed.disconnect(handler)
	assert_deep_eq(changed, [[REGION, 1]])
	assert_eq(state.get_restoration_level(REGION), 1)
	assert_eq(state.get_restoration_points(REGION), int(ContentDB.progression["restoration_points"][1]), "points are not spent")
	assert_false(service.can_restore(REGION), "the next level needs more points")
	state.free()

func test_many_points_still_restore_one_level_at_a_time() -> void:
	var parts := _setup()
	parts[0].add_restoration_points(REGION, 500)
	# progression.json: 390 points reach stage 6, the next stage needs 540.
	assert_eq(parts[1].levels_available(REGION), 6, "500 points earn six stages")
	var restores := 0
	while parts[1].restore(REGION):
		restores += 1
	assert_eq(restores, 6, "one stage per restore, each its own visible change")
	assert_eq(parts[0].get_restoration_level(REGION), 6)
	parts[0].free()

func test_the_slice_cap_stops_restoration_but_not_point_accumulation() -> void:
	var parts := _setup()
	var cap: int = ContentDB.balance["vertical_slice"]["max_restoration_level"]
	parts[0].add_restoration_points(REGION, 100000)
	parts[0].set_restoration_level(REGION, cap)
	var requirement: RestorationService.Requirement = parts[1].get_requirement(REGION)
	assert_true(requirement.at_cap)
	assert_false(requirement.can_restore)
	assert_eq(requirement.next_level, cap)
	assert_false(parts[1].restore(REGION))
	parts[0].add_restoration_points(REGION, 10)
	assert_eq(parts[0].get_restoration_points(REGION), 100010, "points keep accumulating past the cap")
	assert_eq(parts[1].levels_available(REGION), 0)
	parts[0].free()

func test_regions_outside_the_slice_are_not_restorable_yet() -> void:
	var parts := _setup()
	parts[0].add_restoration_points("region_02_forest_stream", 1000)
	var requirement: RestorationService.Requirement = parts[1].get_requirement("region_02_forest_stream")
	assert_true(requirement.at_cap)
	assert_false(parts[1].restore("region_02_forest_stream"))
	parts[0].free()

func test_two_first_discoveries_earn_the_first_restoration() -> void:
	# BALANCE §5: a meaningful restoration inside the first ten minutes (a handful of catches).
	var parts := _setup()
	var catches := CatchService.new(parts[0], ContentDB.balance["rewards"])
	for fish_id in ["fish_crucian_carp", "fish_common_carp"]:
		var def := ContentDB.get_fish(fish_id)
		var encounter := EncounterResolver.Encounter.new()
		encounter.fish_id = fish_id
		encounter.size_cm = float(def["size_cm"]["min"])
		encounter.rarity = int(def["rarity"])
		encounter.behavior = def["behavior"]
		catches.begin_catch(encounter, REGION)
		catches.release_catch()
	assert_true(parts[1].can_restore(REGION), "points: %d" % parts[0].get_restoration_points(REGION))
	parts[0].free()
