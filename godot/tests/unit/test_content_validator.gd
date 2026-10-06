extends TestCase

## P0-002: ContentValidator rules (DATA_SCHEMA §7). Each test corrupts one
## field of a deep copy of the shipped data and checks the reported error and
## that the broken entry is excluded.

const DATA_DIR := "res://data"

func _raw() -> Dictionary:
	var raw: Dictionary = {}
	for category in ContentValidator.FILE_NAMES:
		var text := FileAccess.get_file_as_string(DATA_DIR.path_join(ContentValidator.FILE_NAMES[category]))
		raw[category] = JSON.parse_string(text)
	return raw

func _find(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if item.get("id") == item_id:
			return item
	return {}

func _assert_error(result: Dictionary, substring: String) -> void:
	for problem in result["errors"]:
		if problem.contains(substring):
			return
	fail("no error containing '%s'; errors were: %s" % [substring, result["errors"]])

func test_shipped_content_is_valid() -> void:
	var result := ContentValidator.validate(_raw())
	assert_eq(result["errors"], PackedStringArray(), "shipped content errors")
	assert_eq(result["fish"].size(), 72, "fish count")
	assert_eq(result["regions"].size(), 5, "region count")
	assert_eq(result["rods"].size(), 12, "rod count")
	assert_eq(result["baits"].size(), 16, "bait count")
	assert_false(result["progression"].is_empty(), "progression dropped")
	assert_false(result["balance"].is_empty(), "balance dropped")

func test_duplicate_id_keeps_first_entry() -> void:
	var raw := _raw()
	var copy: Dictionary = raw["fish"][0].duplicate(true)
	copy["rarity"] = 3
	raw["fish"].append(copy)
	var result := ContentValidator.validate(raw)
	_assert_error(result, "fish_catalog.json[%s]: duplicate id" % copy["id"])
	assert_eq(result["fish"][copy["id"]]["rarity"], raw["fish"][0]["rarity"], "first entry kept")

func test_invalid_id_pattern_rejected() -> void:
	var raw := _raw()
	raw["rods"][0]["id"] = "Bamboo Rod"
	var result := ContentValidator.validate(raw)
	_assert_error(result, "rods.json[0].id: must match")
	assert_eq(result["rods"].size(), 11, "invalid rod excluded")

func test_fish_rarity_must_be_integer_1_to_5() -> void:
	for bad_value in [0, 6, 2.5, "3"]:
		var raw := _raw()
		var target := _find(raw["fish"], "fish_crucian_carp")
		target["rarity"] = bad_value
		var result := ContentValidator.validate(raw)
		_assert_error(result, "fish_catalog.json[fish_crucian_carp].rarity: must be an integer 1..5")
		assert_false(result["fish"].has("fish_crucian_carp"), "fish with rarity %s kept" % var_to_str(bad_value))

func test_fish_base_weight_must_be_positive() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["base_weight"] = 0
	_assert_error(ContentValidator.validate(raw), "[fish_crucian_carp].base_weight: must be a number in (0")

func test_fish_size_range() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["size_cm"] = {"min": 20, "max": 20}
	_assert_error(ContentValidator.validate(raw), "[fish_crucian_carp].size_cm: requires 0 < min < max")

func test_fish_missing_localization_key_field() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp").erase("journal_key")
	_assert_error(ContentValidator.validate(raw), "[fish_crucian_carp].journal_key: must be a non-empty string")

func test_fish_unknown_region_reference() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["regions"] = ["region_09_nowhere"]
	_assert_error(ContentValidator.validate(raw), "regions: unknown or invalid region 'region_09_nowhere'")

func test_fish_habitat_must_exist_in_its_regions() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["habitats"] = ["reef"]
	_assert_error(ContentValidator.validate(raw), "habitats: 'reef' does not exist in any of the fish's regions")

func test_fish_bait_tag_must_be_provided_by_a_bait() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["bait_tags"] = ["chocolate"]
	_assert_error(ContentValidator.validate(raw), "bait_tags: no bait provides tag 'chocolate'")

func test_fish_time_band_keys_must_be_known() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["time_bands"]["noon"] = 1.0
	_assert_error(ContentValidator.validate(raw), "time_bands: 'noon' is not a known time band")

func test_fish_weather_must_exist_in_its_regions() -> void:
	var raw := _raw()
	# Region 01 has clear/cloudy/rain only.
	_find(raw["fish"], "fish_crucian_carp")["weather"]["storm"] = 1.2
	_assert_error(ContentValidator.validate(raw), "weather: 'storm' is not a known weather in the fish's regions")

func test_fish_negative_modifier_rejected() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["time_bands"]["day"] = -1
	_assert_error(ContentValidator.validate(raw), "time_bands.day: multiplier must be a number >= 0")

func test_fish_fight_strength_range() -> void:
	var raw := _raw()
	_find(raw["fish"], "fish_crucian_carp")["fight"]["strength"] = 1.5
	_assert_error(ContentValidator.validate(raw), "fight.strength: must be a number in [0")

func test_invalid_region_cascades_to_its_fish() -> void:
	var raw := _raw()
	_find(raw["regions"], "region_01_quiet_pond").erase("restoration_levels")
	var result := ContentValidator.validate(raw)
	_assert_error(result, "regions.json[region_01_quiet_pond].restoration_levels")
	_assert_error(result, "[fish_crucian_carp].regions: unknown or invalid region 'region_01_quiet_pond'")
	assert_false(result["regions"].has("region_01_quiet_pond"))
	assert_false(result["fish"].has("fish_crucian_carp"))

func test_bait_consumable_must_be_bool() -> void:
	var raw := _raw()
	_find(raw["baits"], "bait_bread")["consumable"] = "yes"
	_assert_error(ContentValidator.validate(raw), "baits.json[bait_bread].consumable: must be true or false")

func test_rod_range_must_be_positive() -> void:
	var raw := _raw()
	_find(raw["rods"], "rod_bamboo")["range"] = 0
	_assert_error(ContentValidator.validate(raw), "rods.json[rod_bamboo].range: must be a number in (0")

func test_top_level_must_be_array() -> void:
	var raw := _raw()
	raw["baits"] = {"bait_bread": {}}
	var result := ContentValidator.validate(raw)
	_assert_error(result, "baits.json: top level must be an array")
	assert_eq(result["baits"].size(), 0)

func test_progression_points_strictly_increasing() -> void:
	var raw := _raw()
	raw["progression"]["restoration_points"][3] = 60
	var result := ContentValidator.validate(raw)
	_assert_error(result, "progression.json.restoration_points[3]: must be greater than the previous value")
	assert_true(result["progression"].is_empty(), "invalid progression kept")

func test_progression_points_match_region_levels() -> void:
	var raw := _raw()
	raw["progression"]["restoration_points"].pop_back()
	_assert_error(ContentValidator.validate(raw), "restoration_points: 10 entries but")

func test_progression_unlocks_reference_known_regions() -> void:
	var raw := _raw()
	raw["progression"]["region_unlocks"][1]["condition"]["region"] = "region_09_nowhere"
	_assert_error(ContentValidator.validate(raw), "region_unlocks[1].condition.region: unknown or invalid region")

func test_progression_requires_one_start_and_unlock_per_region() -> void:
	var raw := _raw()
	raw["progression"]["region_unlocks"].pop_back()
	raw["progression"]["region_unlocks"][1]["condition"] = {"type": "start"}
	var result := ContentValidator.validate(raw)
	_assert_error(result, "exactly one region must have condition type 'start' (found 2)")
	_assert_error(result, "no unlock entry for region_05_moonlight_isle")

func test_duplicate_of_rejected_entry_is_still_caught() -> void:
	# Codex review PR #4: a rejected first entry must not let a later duplicate through.
	var raw := _raw()
	var valid_copy: Dictionary = _find(raw["fish"], "fish_crucian_carp").duplicate(true)
	_find(raw["fish"], "fish_crucian_carp")["rarity"] = 9
	raw["fish"].append(valid_copy)
	var result := ContentValidator.validate(raw)
	_assert_error(result, "[fish_crucian_carp].rarity: must be an integer 1..5")
	_assert_error(result, "fish_catalog.json[fish_crucian_carp]: duplicate id")
	assert_false(result["fish"].has("fish_crucian_carp"), "duplicate of a rejected entry was accepted")

func test_unlock_cycle_is_rejected() -> void:
	# Codex review PR #4: regions that depend on each other can never unlock.
	var raw := _raw()
	for entry in raw["progression"]["region_unlocks"]:
		if entry["region_id"] == "region_02_forest_stream":
			entry["condition"]["region"] = "region_03_reed_river"
	var result := ContentValidator.validate(raw)
	_assert_error(result, "unlock chain of region_02_forest_stream loops")
	_assert_error(result, "unlock chain of region_03_reed_river loops")
	assert_true(result["progression"].is_empty(), "cyclic progression kept")

func test_unlock_self_dependency_is_rejected() -> void:
	var raw := _raw()
	for entry in raw["progression"]["region_unlocks"]:
		if entry["region_id"] == "region_05_moonlight_isle":
			entry["condition"]["region"] = "region_05_moonlight_isle"
	_assert_error(ContentValidator.validate(raw), "unlock chain of region_05_moonlight_isle loops")

func test_non_finite_numbers_are_rejected() -> void:
	# Codex review PR #4: overflowing JSON literals parse to INF.
	var parsed: Variant = JSON.parse_string('{"w": 1e999}')
	assert_false(is_finite(parsed["w"]), "precondition: 1e999 parses to a non-finite float")
	var raw := _raw()
	var target := _find(raw["fish"], "fish_crucian_carp")
	target["base_weight"] = parsed["w"]
	target["fight"]["duration_sec"] = INF
	target["time_bands"]["day"] = NAN
	var result := ContentValidator.validate(raw)
	_assert_error(result, "[fish_crucian_carp].base_weight: must be a number")
	_assert_error(result, "[fish_crucian_carp].fight.duration_sec: must be a number")
	_assert_error(result, "[fish_crucian_carp].time_bands.day: multiplier must be a number >= 0")
	assert_false(result["fish"].has("fish_crucian_carp"))

func test_unreachable_unique_fish_threshold_is_rejected() -> void:
	# Codex re-review PR #4: a threshold above the species living in the
	# prerequisite region can never be met (progression softlock).
	var raw := _raw()
	for entry in raw["progression"]["region_unlocks"]:
		if entry["region_id"] == "region_02_forest_stream":
			entry["condition"]["unique_fish"] = 11  # Region 01 has 10 species
	var result := ContentValidator.validate(raw)
	_assert_error(result, "condition.unique_fish: 11 exceeds the 10 species that live in region_01_quiet_pond")
	assert_true(result["progression"].is_empty(), "unreachable progression kept")

func test_balance_starting_inventory_must_reference_known_items() -> void:
	var raw := _raw()
	raw["balance"]["starting_inventory"]["rods"].append("rod_nonexistent")
	var result := ContentValidator.validate(raw)
	_assert_error(result, "balance.json.starting_inventory.rods: unknown or invalid id")
	assert_true(result["balance"].is_empty(), "invalid balance kept")

func test_balance_equipped_items_must_be_owned() -> void:
	var raw := _raw()
	raw["balance"]["starting_inventory"]["equipped_bait"] = "bait_squid"
	var result := ContentValidator.validate(raw)
	_assert_error(result, "starting_inventory.equipped_bait: must be one of starting_inventory.baits")

func test_balance_vertical_slice_region_and_level_range() -> void:
	var raw := _raw()
	raw["balance"]["vertical_slice"]["region_id"] = "region_09_nowhere"
	_assert_error(ContentValidator.validate(raw), "balance.json.vertical_slice.region_id: unknown or invalid region")
	raw = _raw()
	raw["balance"]["vertical_slice"]["max_restoration_level"] = 11
	_assert_error(ContentValidator.validate(raw), "vertical_slice.max_restoration_level: must be an integer 1..10")

func test_balance_starting_inventory_rejects_duplicate_ids() -> void:
	var raw := _raw()
	raw["balance"]["starting_inventory"]["baits"].append("bait_bread")
	var result := ContentValidator.validate(raw)
	_assert_error(result, "balance.json.starting_inventory.baits: duplicate id")
	assert_true(result["balance"].is_empty(), "balance with duplicates kept")
