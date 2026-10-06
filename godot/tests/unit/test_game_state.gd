extends TestCase

## P0-004: GameState domain model. Every test uses a fresh instance, not the autoload, so the
## running game's state is never touched; events still go through the real EventBus.

func _new_state() -> Node:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	return state

func test_new_game_matches_default_schema_plus_starting_inventory() -> void:
	var state := _new_state()
	var starting: Dictionary = ContentDB.balance["starting_inventory"]
	assert_eq(SaveSchema.validate(state.data), PackedStringArray())
	assert_deep_eq(state.get_owned_rods(), starting["rods"])
	assert_deep_eq(state.get_owned_baits(), starting["baits"])
	assert_eq(state.get_equipped_rod(), starting["equipped_rod"])
	assert_eq(state.get_equipped_bait(), starting["equipped_bait"])
	assert_eq(state.get_ripple(), 0)
	assert_eq(state.discovered_count(), 0)
	state.free()

func test_economy_add_spend_and_events() -> void:
	var state := _new_state()
	var events: Array = []
	var handler := func(ripple: int, memory: int) -> void: events.append([ripple, memory])
	EventBus.economy_changed.connect(handler)
	state.add_ripple(30)
	state.add_memory(4)
	assert_true(state.spend_ripple(10))
	assert_false(state.spend_ripple(21), "overspend must fail")
	assert_eq(state.get_ripple(), 20, "failed spend must not change the balance")
	EventBus.economy_changed.disconnect(handler)
	assert_deep_eq(events, [[30, 0], [30, 4], [20, 4]])
	state.free()

func test_negative_amounts_are_rejected_with_an_error() -> void:
	var state := _new_state()
	expect_engine_error("cannot add a negative amount of ripple")
	state.add_ripple(-5)
	expect_engine_error("cannot spend a negative amount of memory")
	assert_false(state.spend_memory(-1))
	assert_eq(state.get_ripple(), 0)
	assert_eq(state.get_memory(), 0)
	state.free()

func test_currency_is_capped() -> void:
	var state := _new_state()
	state.add_ripple(state.MAX_CURRENCY)
	state.add_ripple(1000)
	assert_eq(state.get_ripple(), state.MAX_CURRENCY)
	state.free()

func test_first_encounter_is_a_discovery_and_tracks_sizes() -> void:
	var state := _new_state()
	var changed: Array = []
	var handler := func(fish_id: String) -> void: changed.append(fish_id)
	EventBus.collection_changed.connect(handler)
	assert_true(state.record_encounter("fish_crucian_carp", 12.0, "steady"))
	assert_false(state.record_encounter("fish_crucian_carp", 20.0, "steady"))
	assert_false(state.record_encounter("fish_crucian_carp", 8.0, "steady"))
	EventBus.collection_changed.disconnect(handler)
	var record: Dictionary = state.get_collection_record("fish_crucian_carp")
	assert_eq(record["encounters"], 3)
	assert_eq(record["largest_cm"], 20.0)
	assert_eq(record["smallest_cm"], 8.0)
	assert_deep_eq(record["observed_behaviors"], ["steady"])
	assert_true(record["first_seen_at"] > 0)
	assert_eq(changed.size(), 3)
	assert_eq(state.discovered_count(), 1)
	assert_true(state.has_discovered("fish_crucian_carp"))
	assert_false(state.has_discovered("fish_minnow"))
	state.free()

func test_release_requires_a_discovery() -> void:
	var state := _new_state()
	expect_engine_error("release recorded for undiscovered fish")
	state.record_release("fish_minnow")
	assert_eq(state.get_collection_record("fish_minnow")["releases"], 0)
	state.record_encounter("fish_minnow", 10.0)
	state.record_release("fish_minnow")
	assert_eq(state.get_collection_record("fish_minnow")["releases"], 1)
	state.free()

func test_getters_return_copies() -> void:
	var state := _new_state()
	state.record_encounter("fish_minnow", 10.0)
	var record: Dictionary = state.get_collection_record("fish_minnow")
	record["encounters"] = 999
	assert_eq(state.get_collection_record("fish_minnow")["encounters"], 1, "record leaked internal state")
	var rods: Array = state.get_owned_rods()
	rods.clear()
	assert_false(state.get_owned_rods().is_empty(), "inventory leaked internal state")
	var snapshot: Dictionary = state.snapshot()
	snapshot["economy"]["ripple"] = 12345
	assert_eq(state.get_ripple(), 0, "snapshot leaked internal state")
	state.free()

func test_region_points_level_and_population() -> void:
	var state := _new_state()
	var region := "region_01_quiet_pond"
	var seen: Array = []
	var on_points := func(region_id: String, points: int) -> void: seen.append(["points", region_id, points])
	var on_level := func(region_id: String, level: int) -> void: seen.append(["level", region_id, level])
	var on_population := func(region_id: String, fish_id: String, population: int) -> void:
		seen.append(["pop", region_id, fish_id, population])
	EventBus.region_restoration_points_changed.connect(on_points)
	EventBus.region_restoration_changed.connect(on_level)
	EventBus.region_population_changed.connect(on_population)

	state.add_restoration_points(region, 25)
	state.set_restoration_level(region, 1)
	state.set_restoration_level(region, 1)  # unchanged: no second event
	state.add_population(region, "fish_minnow", 2)
	state.add_population(region, "fish_minnow", 1)

	EventBus.region_restoration_points_changed.disconnect(on_points)
	EventBus.region_restoration_changed.disconnect(on_level)
	EventBus.region_population_changed.disconnect(on_population)
	assert_deep_eq(seen, [
		["points", region, 25], ["level", region, 1],
		["pop", region, "fish_minnow", 2], ["pop", region, "fish_minnow", 3],
	])
	assert_eq(state.get_restoration_points(region), 25)
	assert_eq(state.get_restoration_level(region), 1)
	assert_eq(state.get_population(region, "fish_minnow"), 3)
	assert_eq(state.get_population(region, "fish_loach"), 0)
	assert_eq(state.get_population("region_02_forest_stream", "fish_minnow"), 0)
	assert_deep_eq(state.get_species_population(region), {"fish_minnow": 3})
	state.free()

func test_reading_an_unknown_region_does_not_create_it() -> void:
	var state := _new_state()
	state.get_restoration_level("region_03_reed_river")
	state.get_population("region_03_reed_river", "fish_x")
	assert_false(state.data["regions"].has("region_03_reed_river"), "reads must not mutate state")
	state.free()

func test_inventory_only_equips_owned_items() -> void:
	var state := _new_state()
	assert_false(state.equip_rod("rod_old_master"))
	assert_eq(state.get_equipped_rod(), ContentDB.balance["starting_inventory"]["equipped_rod"])
	state.grant_rod("rod_old_master")
	state.grant_rod("rod_old_master")
	assert_eq(state.get_owned_rods().count("rod_old_master"), 1, "grant must be idempotent")
	assert_true(state.equip_rod("rod_old_master"))
	assert_eq(state.get_equipped_rod(), "rod_old_master")
	state.free()

func test_settings_are_sanitized_and_emit_only_on_change() -> void:
	var state := _new_state()
	var keys: Array = []
	var handler := func(key: String) -> void: keys.append(key)
	EventBus.settings_changed.connect(handler)
	assert_true(state.set_setting("text_scale", 5.0))
	assert_eq(state.get_setting("text_scale"), 1.6, "value must be clamped")
	assert_true(state.set_setting("text_scale", 1.6), "re-setting the same value is fine")
	assert_true(state.set_setting("auto_hook", true))
	assert_eq(state.get_setting("auto_hook"), true)
	assert_true(state.set_setting("quality", "nonsense"))
	assert_eq(state.get_setting("quality"), "medium", "invalid enum falls back to default")
	assert_false(state.set_setting("not_a_setting", 1))
	EventBus.settings_changed.disconnect(handler)
	assert_deep_eq(keys, ["text_scale", "auto_hook"])
	state.free()

func test_load_data_normalizes_and_announces_replacement() -> void:
	var state := _new_state()
	var replaced: Array = []
	var handler := func() -> void: replaced.append(true)
	EventBus.game_state_replaced.connect(handler)
	var revision_before: int = state.revision
	state.load_data({"save_version": 1, "economy": {"ripple": 12.0}, "collection": {"fish_minnow": {"encounters": 2.0}}})
	EventBus.game_state_replaced.disconnect(handler)
	assert_eq(replaced.size(), 1)
	assert_true(state.revision > revision_before)
	assert_eq(typeof(state.get_ripple()), TYPE_INT)
	assert_eq(state.get_ripple(), 12)
	assert_eq(state.get_collection_record("fish_minnow")["encounters"], 2)
	assert_eq(SaveSchema.validate(state.data), PackedStringArray())
	state.free()

func test_every_mutation_bumps_revision() -> void:
	var state := _new_state()
	var before: int = state.revision
	state.add_ripple(1)
	state.record_encounter("fish_minnow", 5.0)
	state.add_population("region_01_quiet_pond", "fish_minnow", 1)
	state.set_setting("haptics", false)
	state.set_pending_catch({"fish_id": "fish_minnow"})
	assert_eq(state.revision, before + 5)
	state.free()

func test_pending_catch_roundtrip() -> void:
	var state := _new_state()
	assert_deep_eq(state.get_pending_catch(), {})
	state.set_pending_catch({"fish_id": "fish_minnow", "size_cm": 11.5, "region_id": "region_01_quiet_pond"})
	assert_eq(state.get_pending_catch()["fish_id"], "fish_minnow")
	state.clear_pending_catch()
	assert_deep_eq(state.get_pending_catch(), {})
	state.free()

func test_profile_mutators_advance_revision_only_when_value_changes() -> void:
	var state := _new_state()
	state.set_game_minutes(300.0)
	var after_clock: int = state.revision
	state.set_game_minutes(300.0)
	assert_eq(state.revision, after_clock, "same value must not look like a change")
	state.set_game_minutes(301.0)
	assert_eq(state.revision, after_clock + 1)
	var before_touch: int = state.revision
	state.touch_session(1_700_000_123)
	assert_eq(state.revision, before_touch + 1)
	state.touch_session(1_700_000_123)
	assert_eq(state.revision, before_touch + 1)
	state.free()

func test_release_is_rejected_for_a_zero_encounter_record() -> void:
	var state := _new_state()
	# A loaded save may hold a key whose record is all zeros; it is not a discovery.
	state.load_data({"save_version": 1, "collection": {"fish_minnow": {}}})
	assert_false(state.has_discovered("fish_minnow"))
	expect_engine_error("release recorded for undiscovered fish")
	state.record_release("fish_minnow")
	assert_eq(state.get_collection_record("fish_minnow")["releases"], 0)
	state.free()

func test_awards_never_lower_a_loaded_balance() -> void:
	var state := _new_state()
	state.load_data({"save_version": 1, "economy": {"ripple": 2_000_000_000}})
	var before: int = state.get_ripple()
	state.add_ripple(5)
	assert_true(state.get_ripple() >= before, "an award reduced the balance (%d -> %d)" % [before, state.get_ripple()])
	state.free()
