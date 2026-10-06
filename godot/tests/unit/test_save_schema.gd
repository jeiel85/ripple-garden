extends TestCase

## P0-004: PlayerSave defaults, normalization (defaults injected, unknown fields kept,
## types coerced) and the sanity check.

const NOW := 1_700_000_000

func test_default_save_is_valid_and_versioned() -> void:
	var save := SaveSchema.default_save(NOW)
	assert_eq(save["save_version"], SaveSchema.CURRENT_VERSION)
	assert_eq(SaveSchema.validate(save), PackedStringArray(), "default save invalid")
	assert_eq(save["profile"]["created_at"], NOW)

func test_normalizing_a_normalized_save_is_a_no_op() -> void:
	var save := SaveSchema.default_save(NOW)
	assert_deep_eq(SaveSchema.normalize(save, NOW + 99), save)

func test_missing_fields_get_defaults() -> void:
	var normalized := SaveSchema.normalize({"save_version": 1, "economy": {"ripple": 7}}, NOW)
	assert_eq(normalized["economy"]["ripple"], 7)
	assert_eq(normalized["economy"]["memory"], 0)
	assert_eq(normalized["settings"]["haptics"], true)
	assert_eq(normalized["profile"]["created_at"], NOW)
	assert_eq(SaveSchema.validate(normalized), PackedStringArray())

func test_unknown_fields_are_preserved() -> void:
	var raw := SaveSchema.default_save(NOW)
	raw["future_top_level"] = {"x": 1}
	raw["profile"]["future_profile_field"] = "keep"
	raw["settings"]["future_setting"] = 3
	raw["regions"]["region_01_quiet_pond"] = {"future_region_field": [1, 2]}
	raw["collection"]["fish_crucian_carp"] = {"encounters": 2, "future_record_field": true}
	var normalized := SaveSchema.normalize(raw, NOW)
	assert_deep_eq(normalized["future_top_level"], {"x": 1})
	assert_eq(normalized["profile"]["future_profile_field"], "keep")
	assert_eq(normalized["settings"]["future_setting"], 3)
	assert_deep_eq(normalized["regions"]["region_01_quiet_pond"]["future_region_field"], [1, 2])
	assert_eq(normalized["collection"]["fish_crucian_carp"]["future_record_field"], true)
	assert_eq(normalized["collection"]["fish_crucian_carp"]["encounters"], 2)

func test_json_floats_are_coerced_back_to_ints() -> void:
	var parsed: Variant = JSON.parse_string(JSON.stringify(SaveSchema.default_save(NOW)))
	assert_eq(typeof(parsed["economy"]["ripple"]), TYPE_FLOAT, "premise: JSON parses numbers as float")
	var normalized := SaveSchema.normalize(parsed, NOW)
	assert_eq(typeof(normalized["economy"]["ripple"]), TYPE_INT)
	assert_eq(typeof(normalized["profile"]["created_at"]), TYPE_INT)
	assert_eq(typeof(normalized["save_version"]), TYPE_INT)
	assert_deep_eq(normalized, SaveSchema.default_save(NOW))

func test_wrong_types_fall_back_to_defaults_and_clamp() -> void:
	var raw := {
		"economy": {"ripple": "lots", "memory": -5},
		"settings": {"text_scale": 9.0, "haptics": "yes", "quality": "ultra", "fps_cap": 45},
		"inventory": {"rods": "rod_bamboo", "baits": ["bait_bread", 3, "bait_bread"]},
		"regions": {"region_01_quiet_pond": {"restoration_level": -2, "species_population": {"fish_a": -4, "fish_b": 3.0}}},
	}
	var normalized := SaveSchema.normalize(raw, NOW)
	assert_eq(normalized["economy"]["ripple"], 0)
	assert_eq(normalized["economy"]["memory"], 0)
	assert_eq(normalized["settings"]["text_scale"], 1.6)
	assert_eq(normalized["settings"]["haptics"], true)
	assert_eq(normalized["settings"]["quality"], "medium")
	assert_eq(normalized["settings"]["fps_cap"], 30)
	assert_deep_eq(normalized["inventory"]["rods"], [])
	assert_deep_eq(normalized["inventory"]["baits"], ["bait_bread"])
	var region: Dictionary = normalized["regions"]["region_01_quiet_pond"]
	assert_eq(region["restoration_level"], 0)
	assert_eq(region["species_population"]["fish_a"], 0)
	assert_eq(region["species_population"]["fish_b"], 3)
	assert_eq(SaveSchema.validate(normalized), PackedStringArray())

func test_non_dictionary_input_yields_default_save() -> void:
	assert_deep_eq(SaveSchema.normalize("garbage", NOW), SaveSchema.default_save(NOW))
	assert_deep_eq(SaveSchema.normalize(null, NOW), SaveSchema.default_save(NOW))

func test_validate_reports_structural_problems() -> void:
	assert_false(SaveSchema.validate(null).is_empty())
	var save := SaveSchema.default_save(NOW)
	save["economy"]["ripple"] = -1
	save["regions"]["region_01_quiet_pond"] = {"restoration_level": 0.5}
	var problems := "\n".join(SaveSchema.validate(save))
	assert_true(problems.contains("economy.ripple"), problems)
	assert_true(problems.contains("regions.region_01_quiet_pond.restoration_level"), problems)
	var missing_section := SaveSchema.default_save(NOW)
	missing_section.erase("collection")
	assert_true("\n".join(SaveSchema.validate(missing_section)).contains("collection must be an object"))

func test_every_setting_default_survives_sanitizing() -> void:
	for key in SaveSchema.SETTING_SPECS:
		var default_value: Variant = SaveSchema.SETTING_SPECS[key]["default"]
		assert_eq(SaveSchema.sanitize_setting(key, default_value), default_value, "setting %s" % key)

func test_missing_equipment_falls_back_to_first_owned_item() -> void:
	var legacy := {"save_version": 1, "inventory": {"rods": ["rod_bamboo", "rod_light"], "baits": ["bait_bread"]}}
	var normalized := SaveSchema.normalize(legacy, NOW)
	assert_eq(normalized["inventory"]["equipped_rod"], "rod_bamboo")
	assert_eq(normalized["inventory"]["equipped_bait"], "bait_bread")

func test_equipped_item_that_is_not_owned_is_replaced() -> void:
	var raw := {"save_version": 1, "inventory": {"rods": ["rod_light"], "baits": [], "equipped_rod": "rod_gone", "equipped_bait": "bait_gone"}}
	var normalized := SaveSchema.normalize(raw, NOW)
	assert_eq(normalized["inventory"]["equipped_rod"], "rod_light")
	assert_eq(normalized["inventory"]["equipped_bait"], "", "nothing owned means nothing equipped")

func test_valid_equipment_is_kept() -> void:
	var raw := {"save_version": 1, "inventory": {"rods": ["rod_bamboo", "rod_light"], "baits": ["bait_bread"], "equipped_rod": "rod_light"}}
	assert_eq(SaveSchema.normalize(raw, NOW)["inventory"]["equipped_rod"], "rod_light")
