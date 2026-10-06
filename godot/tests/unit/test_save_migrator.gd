extends TestCase

## P0-006: migration framework — ordered single-version steps, refusal of newer saves,
## default injection, unknown-field preservation and content id aliases.
## Production has only v1, so these tests inject synthetic version tables.

const NOW := 1_700_000_000

var call_order: Array = []

func _v1_save() -> Dictionary:
	var save := SaveSchema.default_save(NOW)
	save["economy"]["ripple"] = 40
	return save

func _step_1_to_2(save: Dictionary) -> Dictionary:
	call_order.append(1)
	save["economy"]["ripple"] = int(save["economy"]["ripple"]) * 2
	save["added_in_v2"] = "yes"
	return save

func _step_2_to_3(save: Dictionary) -> Dictionary:
	call_order.append(2)
	save["added_in_v3"] = save["added_in_v2"] + "!"
	return save

func _migrator(version: int, steps: Dictionary, aliases: Dictionary = {}) -> SaveMigrator:
	return SaveMigrator.new(version, steps, aliases)

func test_current_version_save_passes_through_unchanged() -> void:
	var save := _v1_save()
	var result := SaveMigrator.new().migrate(save, NOW)
	assert_true(result["ok"], result["error"])
	assert_eq(result["from_version"], 1)
	assert_deep_eq(result["save"], save)

func test_json_parsed_save_migrates_to_typed_save() -> void:
	var parsed: Variant = JSON.parse_string(JSON.stringify(_v1_save()))
	var result := SaveMigrator.new().migrate(parsed, NOW)
	assert_true(result["ok"], result["error"])
	assert_deep_eq(result["save"], _v1_save())

func test_steps_run_in_order_one_version_at_a_time() -> void:
	call_order.clear()
	var migrator := _migrator(3, {1: _step_1_to_2, 2: _step_2_to_3})
	var result := migrator.migrate(_v1_save(), NOW)
	assert_true(result["ok"], result["error"])
	assert_deep_eq(call_order, [1, 2])
	assert_eq(result["save"]["save_version"], 3)
	assert_eq(result["from_version"], 1)
	assert_eq(result["save"]["economy"]["ripple"], 80)
	assert_eq(result["save"]["added_in_v3"], "yes!")

func test_migrating_from_a_later_version_skips_earlier_steps() -> void:
	call_order.clear()
	var save := _v1_save()
	save["save_version"] = 2
	save["added_in_v2"] = "yes"
	var result := _migrator(3, {1: _step_1_to_2, 2: _step_2_to_3}).migrate(save, NOW)
	assert_true(result["ok"], result["error"])
	assert_deep_eq(call_order, [2])

func test_missing_step_is_an_error_not_a_skip() -> void:
	var result := _migrator(3, {2: _step_2_to_3}).migrate(_v1_save(), NOW)
	assert_false(result["ok"])
	assert_true(result["error"].contains("no migration from version 1 to 2"), result["error"])

func test_newer_save_is_refused_and_flagged() -> void:
	var save := _v1_save()
	save["save_version"] = 7
	var result := SaveMigrator.new().migrate(save, NOW)
	assert_false(result["ok"])
	assert_true(result["newer"])
	assert_eq(result["from_version"], 7)

func test_invalid_versions_are_rejected() -> void:
	for bad_version in [0, -1, 1.5, "1", null]:
		var save := _v1_save()
		save["save_version"] = bad_version
		var result := SaveMigrator.new().migrate(save, NOW)
		assert_false(result["ok"], "version %s accepted" % var_to_str(bad_version))
		assert_false(result["newer"])
	var no_version := _v1_save()
	no_version.erase("save_version")
	assert_false(SaveMigrator.new().migrate(no_version, NOW)["ok"], "missing version accepted")
	assert_false(SaveMigrator.new().migrate([1, 2], NOW)["ok"], "array accepted")

func test_float_version_from_json_is_accepted() -> void:
	var save := _v1_save()
	save["save_version"] = 1.0
	assert_true(SaveMigrator.new().migrate(save, NOW)["ok"])

func test_step_returning_garbage_is_an_error() -> void:
	var bad := func(_save: Dictionary) -> Variant: return null
	var result := _migrator(2, {1: bad}).migrate(_v1_save(), NOW)
	assert_false(result["ok"])
	assert_true(result["error"].contains("returned"), result["error"])

func test_migration_does_not_mutate_the_input() -> void:
	call_order.clear()
	var original := _v1_save()
	var snapshot := original.duplicate(true)
	_migrator(2, {1: _step_1_to_2}).migrate(original, NOW)
	assert_deep_eq(original, snapshot, "input save was mutated")

func test_unknown_fields_survive_migration() -> void:
	var save := _v1_save()
	save["from_a_future_feature"] = {"keep": [1, 2, 3]}
	save["profile"]["nickname"] = "pond keeper"
	var result := _migrator(2, {1: _step_1_to_2}).migrate(save, NOW)
	assert_true(result["ok"], result["error"])
	assert_deep_eq(result["save"]["from_a_future_feature"], {"keep": [1, 2, 3]})
	assert_eq(result["save"]["profile"]["nickname"], "pond keeper")

func test_missing_fields_are_filled_after_migration() -> void:
	var sparse := {"save_version": 1, "economy": {"ripple": 5}}
	var result := SaveMigrator.new().migrate(sparse, NOW)
	assert_true(result["ok"], result["error"])
	assert_eq(result["save"]["economy"]["memory"], 0)
	assert_deep_eq(result["save"]["settings"], SaveSchema.default_settings())

# --- aliases ---

func test_alias_renames_collection_population_inventory_and_pending() -> void:
	var save := _v1_save()
	save["collection"] = {"fish_old": {"encounters": 3, "releases": 2, "largest_cm": 20.0}}
	save["regions"] = {"region_01_quiet_pond": {"species_population": {"fish_old": 4}}}
	save["inventory"]["rods"] = ["rod_old"]
	save["inventory"]["equipped_rod"] = "rod_old"
	save["inventory"]["baits"] = ["bait_old"]
	save["session"]["pending_catch"] = {"fish_id": "fish_old", "region_id": "region_old"}
	var aliases := {"fish": {"fish_old": "fish_new"}, "rods": {"rod_old": "rod_new"},
		"baits": {"bait_old": "bait_new"}, "regions": {"region_old": "region_01_quiet_pond"}}
	var result := SaveMigrator.new(1, {}, aliases).migrate(save, NOW)
	assert_true(result["ok"], result["error"])
	var migrated: Dictionary = result["save"]
	assert_true(migrated["collection"].has("fish_new"))
	assert_false(migrated["collection"].has("fish_old"))
	assert_eq(migrated["collection"]["fish_new"]["encounters"], 3)
	assert_eq(migrated["regions"]["region_01_quiet_pond"]["species_population"], {"fish_new": 4})
	assert_deep_eq(migrated["inventory"]["rods"], ["rod_new"])
	assert_eq(migrated["inventory"]["equipped_rod"], "rod_new")
	assert_deep_eq(migrated["inventory"]["baits"], ["bait_new"])
	assert_eq(migrated["session"]["pending_catch"]["fish_id"], "fish_new")
	assert_eq(migrated["session"]["pending_catch"]["region_id"], "region_01_quiet_pond")

func test_alias_merges_when_new_id_already_has_data() -> void:
	var save := _v1_save()
	save["collection"] = {
		"fish_old": {"encounters": 3, "releases": 1, "largest_cm": 30.0, "smallest_cm": 9.0,
			"first_seen_at": 100, "last_seen_at": 200, "observed_behaviors": ["steady"]},
		"fish_new": {"encounters": 2, "releases": 2, "largest_cm": 25.0, "smallest_cm": 5.0,
			"first_seen_at": 50, "last_seen_at": 400, "observed_behaviors": ["dash"]},
	}
	save["regions"] = {"region_01_quiet_pond": {"species_population": {"fish_old": 3, "fish_new": 4}}}
	var aliases := {"fish": {"fish_old": "fish_new"}}
	var result := SaveMigrator.new(1, {}, aliases).migrate(save, NOW)
	assert_true(result["ok"], result["error"])
	var record: Dictionary = result["save"]["collection"]["fish_new"]
	assert_eq(record["encounters"], 5)
	assert_eq(record["releases"], 3)
	assert_eq(record["largest_cm"], 30.0)
	assert_eq(record["smallest_cm"], 5.0)
	assert_eq(record["first_seen_at"], 50)
	assert_eq(record["last_seen_at"], 400)
	var behaviors: Array = record["observed_behaviors"].duplicate()
	behaviors.sort()
	assert_deep_eq(behaviors, ["dash", "steady"])
	assert_eq(result["save"]["regions"]["region_01_quiet_pond"]["species_population"]["fish_new"], 7)

func test_alias_chains_resolve_and_cycles_do_not_hang() -> void:
	var save := _v1_save()
	save["collection"] = {"fish_a": {"encounters": 1}, "fish_x": {"encounters": 1}}
	var aliases := {"fish": {"fish_a": "fish_b", "fish_b": "fish_c", "fish_x": "fish_y", "fish_y": "fish_x"}}
	var result := SaveMigrator.new(1, {}, aliases).migrate(save, NOW)
	assert_true(result["ok"], result["error"])
	assert_true(result["save"]["collection"].has("fish_c"), "chain not followed")
	assert_true(result["save"]["collection"].has("fish_x"), "cyclic alias must leave the id alone")

func test_region_alias_merge_keeps_best_progress() -> void:
	var save := _v1_save()
	save["regions"] = {
		"region_old": {"restoration_level": 3, "restoration_points": 120, "species_population": {"fish_a": 2}, "seen_events": ["e1"]},
		"region_01_quiet_pond": {"restoration_level": 2, "restoration_points": 150, "species_population": {"fish_a": 1}, "seen_events": ["e2"]},
	}
	var result := SaveMigrator.new(1, {}, {"regions": {"region_old": "region_01_quiet_pond"}}).migrate(save, NOW)
	assert_true(result["ok"], result["error"])
	var region: Dictionary = result["save"]["regions"]["region_01_quiet_pond"]
	assert_eq(result["save"]["regions"].size(), 1)
	assert_eq(region["restoration_level"], 3)
	assert_eq(region["restoration_points"], 150)
	assert_eq(region["species_population"]["fish_a"], 3)
	assert_eq(region["seen_events"].size(), 2)
