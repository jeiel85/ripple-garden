extends TestCase

## P0-017 (journal reveal tiers) and P0-018 (population -> visible fish).

const REGION := "region_01_quiet_pond"

func _journal() -> JournalModel:
	return JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"])

func _record(encounters: int) -> Dictionary:
	var record := SaveSchema.default_collection_record()
	record["encounters"] = encounters
	return record

func _population() -> PopulationModel:
	return PopulationModel.new(ContentDB.balance["population"])

# --- journal ---

func test_information_is_revealed_by_encounter_count() -> void:
	var fish_def := ContentDB.get_fish("fish_crucian_carp")
	var cases := {
		0: [false, false, false, false, 0],
		1: [true, false, false, false, 1],
		2: [true, false, false, false, 1],
		3: [true, true, false, false, 2],
		4: [true, true, false, false, 2],
		5: [true, true, true, false, 3],
		9: [true, true, true, false, 3],
		10: [true, true, true, true, 4],
		99: [true, true, true, true, 4],
	}
	for encounters in cases:
		var entry := _journal().entry_for(fish_def, _record(encounters))
		var expected: Array = cases[encounters]
		assert_deep_eq([entry.show_name, entry.show_time_bands, entry.show_habitats, entry.show_behavior, entry.tier], expected,
			"%d encounters" % encounters)

func test_next_unlock_points_at_the_following_threshold() -> void:
	var fish_def := ContentDB.get_fish("fish_crucian_carp")
	var reveal: Dictionary = ContentDB.balance["journal"]["reveal_at_encounters"]
	assert_eq(_journal().entry_for(fish_def, _record(0)).next_unlock_at, int(reveal["size"]))
	assert_eq(_journal().entry_for(fish_def, _record(int(reveal["size"]))).next_unlock_at, int(reveal["time_bands"]))
	assert_eq(_journal().entry_for(fish_def, _record(int(reveal["behavior"]))).next_unlock_at, 0, "everything open")

func test_undiscovered_species_are_listed_but_hidden() -> void:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	state.record_encounter("fish_crucian_carp", 12.0)
	var entries := _journal().entries_for_region(REGION, state)
	assert_eq(entries.size(), ContentDB.get_fish_for_region(REGION).size())
	var discovered := 0
	for entry in entries:
		if entry.discovered:
			discovered += 1
			assert_true(entry.show_name)
		else:
			assert_false(entry.show_name, "%s must stay a silhouette until met" % entry.fish_id)
			assert_eq(entry.tier, 0)
	assert_eq(discovered, 1)
	var completion := _journal().completion(REGION, state)
	assert_deep_eq(completion, {"discovered": 1, "total": 10})
	state.free()

func test_entry_carries_the_record_sizes() -> void:
	var record := _record(4)
	record["largest_cm"] = 31.5
	record["smallest_cm"] = 9.0
	record["releases"] = 3
	var entry := _journal().entry_for(ContentDB.get_fish("fish_minnow"), record)
	assert_eq(entry.largest_cm, 31.5)
	assert_eq(entry.smallest_cm, 9.0)
	assert_eq(entry.releases, 3)
	assert_eq(entry.rarity, 1)

# --- population ---

func test_visible_fish_follow_the_population_steps() -> void:
	var model := _population()
	var cases := {0: 0, -5: 0, 1: 1, 10: 1, 11: 2, 30: 2, 31: 3, 60: 3, 61: 4, 9999: 4, 100000: 4}
	for population in cases:
		assert_eq(model.visible_count(population), cases[population], "population %d" % population)

func test_agent_budget_depends_on_quality_and_battery_saver() -> void:
	var model := _population()
	assert_eq(model.total_cap("low", false), 20)
	assert_eq(model.total_cap("medium", false), 35)
	assert_eq(model.total_cap("high", false), 50)
	assert_eq(model.total_cap("unknown", false), 35, "unknown quality falls back to medium")
	assert_true(model.total_cap("medium", true) < model.total_cap("medium", false))
	assert_true(model.total_cap("low", true) >= 1)

func test_compose_keeps_species_and_respects_the_cap() -> void:
	var model := _population()
	var populations := {"fish_a": 5, "fish_b": 35, "fish_c": 100, "fish_d": 20}
	var full := model.compose(populations, 50)
	assert_deep_eq(full, {"fish_a": 1, "fish_b": 3, "fish_c": 4, "fish_d": 2})
	var trimmed := model.compose(populations, 6)
	var total := 0
	for fish_id in trimmed:
		total += trimmed[fish_id]
		assert_true(trimmed[fish_id] >= 1)
	assert_eq(total, 6)
	assert_eq(trimmed.size(), 4, "every species keeps a fish while the budget allows")
	assert_true(trimmed["fish_c"] >= trimmed["fish_a"], "larger populations keep more fish")

func test_compose_drops_the_smallest_populations_when_species_exceed_the_cap() -> void:
	var model := _population()
	var populations := {"fish_a": 1, "fish_b": 50, "fish_c": 20, "fish_d": 3}
	var result := model.compose(populations, 2)
	assert_deep_eq(result, {"fish_b": 1, "fish_c": 1})

func test_compose_ignores_absent_species_and_is_deterministic() -> void:
	var model := _population()
	var populations := {"fish_a": 0, "fish_b": 12, "fish_c": 12}
	assert_deep_eq(model.compose(populations, 35), {"fish_b": 2, "fish_c": 2})
	assert_deep_eq(model.compose(populations, 3), model.compose(populations, 3))
	assert_deep_eq(model.compose({}, 35), {})

func test_a_full_slice_population_fits_the_medium_budget_or_is_trimmed_not_overflowed() -> void:
	var model := _population()
	var populations := {}
	for fish_def in ContentDB.get_fish_for_region(REGION):
		populations[fish_def["id"]] = 100
	var shown := model.compose(populations, model.total_cap("medium", false))
	var total := 0
	for fish_id in shown:
		total += shown[fish_id]
	assert_true(total <= 35, "%d agents exceed the medium budget" % total)
	assert_eq(shown.size(), 10)
