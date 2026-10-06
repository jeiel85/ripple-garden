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

func test_aliases_must_lead_to_existing_ids() -> void:
	var raw := _raw()
	raw["aliases"]["fish"] = {"fish_old_name": "fish_crucian_carp", "fish_older": "fish_old_name"}
	var result := ContentValidator.validate(raw)
	assert_eq(result["errors"], PackedStringArray(), "valid alias chain rejected")
	assert_false(result["aliases"].is_empty())

	raw = _raw()
	raw["aliases"]["fish"] = {"fish_gone": "fish_never_existed"}
	_assert_error(ContentValidator.validate(raw), "content_aliases.json.fish[fish_gone]: must lead to an existing fish id")

func test_alias_cycles_and_live_ids_are_rejected() -> void:
	var raw := _raw()
	raw["aliases"]["baits"] = {"bait_a": "bait_b", "bait_b": "bait_a"}
	_assert_error(ContentValidator.validate(raw), "without looping")
	raw = _raw()
	raw["aliases"]["rods"] = {"rod_bamboo": "rod_light"}
	var result := ContentValidator.validate(raw)
	_assert_error(result, "the old id still exists as content")
	assert_true(result["aliases"].is_empty(), "invalid alias table kept")

func test_relaxed_hook_windows_must_not_be_shorter_at_either_end() -> void:
	var raw := _raw()
	raw["balance"]["fishing"]["hook_window_sec"] = {"min": 1.5, "max": 10.0}
	var result := ContentValidator.validate(raw)
	_assert_error(result, "relaxed windows must not be shorter than the normal ones")
	assert_true(result["balance"].is_empty())

# --- weather, layouts, population, journal ---

func test_weather_must_outlast_its_transition() -> void:
	var raw := _raw()
	_find(raw["weather"], "rain")["duration_sec"] = {"min": 15, "max": 60}
	var result := ContentValidator.validate(raw)
	_assert_error(result, "the shortest stay must be at least twice transition_sec")
	assert_false(result["weather"].has("rain"))

func test_weather_transitions_must_lead_to_defined_weather() -> void:
	var raw := _raw()
	_find(raw["weather"], "clear")["next"] = {"snow": 1.0}
	_assert_error(ContentValidator.validate(raw), "weather.json[clear].next: unknown weather 'snow'")

func test_weather_visual_values_are_checked() -> void:
	var raw := _raw()
	_find(raw["weather"], "cloudy")["visual"]["tint"] = "grey"
	_assert_error(ContentValidator.validate(raw), "visual.tint: must be a #rrggbb color")

func test_region_with_layout_needs_its_weather_defined() -> void:
	var raw := _raw()
	raw["weather"].pop_back()  # rain
	_assert_error(ContentValidator.validate(raw), "region lists weather 'rain' that weather.json does not define")

func test_layout_zone_habitat_must_belong_to_the_region() -> void:
	var raw := _raw()
	raw["layouts"]["region_01_quiet_pond"]["zones"][1]["habitat"] = "lagoon"
	var result := ContentValidator.validate(raw)
	_assert_error(result, "is not a habitat of the region")
	assert_true(result["layouts"].is_empty(), "invalid layout kept")

func test_layout_must_cover_every_habitat() -> void:
	var raw := _raw()
	var zones: Array = raw["layouts"]["region_01_quiet_pond"]["zones"]
	for i in range(zones.size() - 1, -1, -1):
		if zones[i]["habitat"] == "bottom":
			zones.remove_at(i)
	_assert_error(ContentValidator.validate(raw), "habitat 'bottom' has no zone")

func test_layout_props_and_animals_use_known_kinds_inside_the_viewport() -> void:
	var raw := _raw()
	var layout: Dictionary = raw["layouts"]["region_01_quiet_pond"]
	layout["props"][0]["kind"] = "spaceship"
	layout["props"][1]["x"] = 5000
	layout["ambient_animals"][0]["kind"] = "dragon"
	var result := ContentValidator.validate(raw)
	_assert_error(result, "unknown prop 'spaceship'")
	_assert_error(result, "x and y must be inside the viewport")
	_assert_error(result, "unknown animal 'dragon'")

func test_scenery_may_bleed_past_the_viewport_but_zones_may_not() -> void:
	var raw := _raw()
	var layout: Dictionary = raw["layouts"]["region_01_quiet_pond"]
	layout["props"][0]["x"] = -120  # inside the bleed margin: wider screens show it
	layout["pond"][0] = [-200, 330]
	var result := ContentValidator.validate(raw)
	assert_false(result["layouts"].is_empty(), "bleed is allowed for scenery and the pond: %s" % [result["errors"]])
	raw = _raw()
	raw["layouts"]["region_01_quiet_pond"]["zones"][0]["polygon"][0] = [-40, 400]
	_assert_error(ContentValidator.validate(raw), "zones[0].polygon: every point must be [x, y] inside the viewport")
	raw = _raw()
	raw["layouts"]["region_01_quiet_pond"]["props"][0]["x"] = -2000
	_assert_error(ContentValidator.validate(raw), "x and y must be inside the viewport or its bleed margin")

func test_layout_angler_waterfall_and_cast_direction_are_checked() -> void:
	var raw := _raw()
	var layout: Dictionary = raw["layouts"]["region_01_quiet_pond"]
	layout["cast_forward_deg"] = 400
	layout["angler"] = {"x": 900, "y": 640}
	layout["waterfall"] = {"x": 590, "y": 120, "width": 0, "height": 140}
	var result := ContentValidator.validate(raw)
	_assert_error(result, "cast_forward_deg: must be a number in -180..180")
	_assert_error(result, "angler: must be {x, y} inside the viewport")
	_assert_error(result, "waterfall: must be {x, y, width > 0, height > 0}")

func test_layout_needs_a_palette_for_every_slice_level() -> void:
	var raw := _raw()
	raw["layouts"]["region_01_quiet_pond"]["levels"].pop_back()
	_assert_error(ContentValidator.validate(raw), "needs 6 palettes")

func test_layout_for_unknown_region_is_rejected() -> void:
	var raw := _raw()
	raw["layouts"]["region_09_nowhere"] = raw["layouts"]["region_01_quiet_pond"].duplicate(true)
	_assert_error(ContentValidator.validate(raw), "region_09_nowhere]: unknown or invalid region")

func test_population_steps_must_increase() -> void:
	var raw := _raw()
	raw["balance"]["population"]["visible_by_population"][2]["visible"] = 1
	_assert_error(ContentValidator.validate(raw), "visible_by_population[2]")
	raw = _raw()
	raw["balance"]["population"]["total_agents_by_quality"]["high"] = 10
	_assert_error(ContentValidator.validate(raw), "must not be smaller than the lower quality tier")

func test_journal_information_must_unlock_in_order() -> void:
	var raw := _raw()
	raw["balance"]["journal"]["reveal_at_encounters"]["habitats"] = 2
	_assert_error(ContentValidator.validate(raw), "information must unlock in the order")

# --- audio ---

func test_audio_streams_buses_and_cues_are_checked() -> void:
	var raw := _raw()
	raw["audio"]["loops"][0]["stream"] = "res://audio/streams/missing.wav"
	_assert_error(ContentValidator.validate(raw), "audio.json.loops[0].stream: file not found")
	raw = _raw()
	raw["audio"]["loops"][1]["bus"] = "Reverb"
	_assert_error(ContentValidator.validate(raw), "audio.json.loops[1].bus: must be one of")
	raw = _raw()
	raw["audio"]["cues"].erase("caught")
	var result := ContentValidator.validate(raw)
	_assert_error(result, "audio.json.cues.caught: missing")
	assert_true(result["audio"].is_empty(), "invalid audio kept")

func test_audio_wildlife_and_mix_rules_are_checked() -> void:
	var raw := _raw()
	raw["audio"]["wildlife"]["clips"][0]["bands"] = ["midnight"]
	_assert_error(ContentValidator.validate(raw), "'midnight' is not a known time band")
	raw = _raw()
	raw["audio"]["mix"]["water"]["base"] = 3.0
	_assert_error(ContentValidator.validate(raw), "audio.json.mix.water.base")
	raw = _raw()
	raw["audio"]["mix"].erase("rain")
	_assert_error(ContentValidator.validate(raw), "audio.json.mix.rain: every loop needs mix settings")

func test_audio_mix_rules_need_every_key_they_read() -> void:
	for pair in [["wind", "night_factor"], ["water", "rain_boost"], ["rain", "gain"]]:
		var raw := _raw()
		raw["audio"]["mix"][pair[0]].erase(pair[1])
		var result := ContentValidator.validate(raw)
		_assert_error(result, "audio.json.mix.%s.%s: required by the mix rules" % [pair[0], pair[1]])
		assert_true(result["audio"].is_empty(), "invalid mix kept")
