extends TestCase

## P0-010: seeded weighted encounter resolution (QA_TEST_PLAN §2 "Encounter").

const REGION := "region_01_quiet_pond"

func _resolver() -> EncounterResolver:
	return EncounterResolver.new(ContentDB.balance["encounter"])

func _request(habitat: String = "shallow") -> EncounterResolver.Request:
	var request := EncounterResolver.Request.new()
	request.habitat = habitat
	request.time_band = "day"
	request.weather_id = "clear"
	return request

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _fish(fish_id: String, weight: float, rarity: int = 1, habitats: Array = ["shallow"]) -> Dictionary:
	return {"id": fish_id, "base_weight": weight, "rarity": rarity, "habitats": habitats,
		"time_bands": {}, "weather": {}, "bait_tags": ["bread"], "behavior": "steady",
		"size_cm": {"min": 10.0, "max": 20.0}}

func _sequence(seed_value: int, count: int) -> Array:
	var resolver := _resolver()
	var rng := _rng(seed_value)
	var request := _request()
	var candidates := ContentDB.get_fish_for_region(REGION)
	var ids: Array = []
	for i in count:
		var encounter := resolver.resolve(request, candidates, rng)
		ids.append("%s:%s" % [encounter.fish_id, encounter.size_cm])
	return ids

# --- determinism ---

func test_same_seed_reproduces_the_same_sequence() -> void:
	assert_deep_eq(_sequence(12345, 40), _sequence(12345, 40))

func test_different_seeds_diverge() -> void:
	assert_true(_sequence(1, 40) != _sequence(2, 40), "different seeds produced identical sequences")

func test_resolver_does_not_consume_the_global_rng() -> void:
	seed(99)
	var expected := randi()
	seed(99)
	_sequence(7, 10)
	assert_eq(randi(), expected, "resolver must only use the RNG it is given")

# --- candidate filtering ---

func test_only_fish_living_in_the_habitat_are_candidates() -> void:
	var resolver := _resolver()
	var candidates := [_fish("fish_a", 5.0, 1, ["shallow"]), _fish("fish_b", 5.0, 1, ["bottom"])]
	var rng := _rng(3)
	for i in 50:
		assert_eq(resolver.resolve(_request("shallow"), candidates, rng).fish_id, "fish_a")
		assert_eq(resolver.resolve(_request("bottom"), candidates, rng).fish_id, "fish_b")

func test_no_candidates_in_habitat_returns_null() -> void:
	var resolver := _resolver()
	assert_eq(resolver.resolve(_request("lagoon"), ContentDB.get_fish_for_region(REGION), _rng(1)), null)
	assert_eq(resolver.resolve(_request("shallow"), [], _rng(1)), null)

func test_zero_and_negative_weights_never_crash_or_win() -> void:
	var resolver := _resolver()
	var candidates := [_fish("fish_zero", 0.0), _fish("fish_negative", -3.0), _fish("fish_ok", 1.0)]
	var rng := _rng(5)
	for i in 100:
		assert_eq(resolver.resolve(_request(), candidates, rng).fish_id, "fish_ok")
	assert_eq(resolver.resolve(_request(), [_fish("fish_zero", 0.0)], rng), null, "all-zero pool must yield null")

func test_zero_time_multiplier_removes_the_fish() -> void:
	var resolver := _resolver()
	var night_only := _fish("fish_night", 5.0)
	night_only["time_bands"] = {"day": 0.0, "night": 1.0}
	var candidates := [night_only, _fish("fish_any", 1.0)]
	var rng := _rng(8)
	for i in 50:
		assert_eq(resolver.resolve(_request(), candidates, rng).fish_id, "fish_any")
	var request := _request()
	request.time_band = "night"
	var seen := {}
	for i in 200:
		seen[resolver.resolve(request, candidates, rng).fish_id] = true
	assert_true(seen.has("fish_night"))

# --- weighting ---

func test_selection_frequency_follows_weights() -> void:
	var resolver := _resolver()
	var candidates := ContentDB.get_fish_for_region(REGION)
	var request := _request("shallow")
	var expected := {}
	var total := 0.0
	for fish_def in candidates:
		if "shallow" in fish_def["habitats"]:
			expected[fish_def["id"]] = resolver.calculate_weight(fish_def, request)
			total += expected[fish_def["id"]]
	var counts := {}
	var rng := _rng(2024)
	var rolls := 30000
	for i in rolls:
		var picked := resolver.resolve(request, candidates, rng).fish_id
		counts[picked] = counts.get(picked, 0) + 1
	for fish_id in expected:
		var share := float(counts.get(fish_id, 0)) / rolls
		assert_true(absf(share - expected[fish_id] / total) < 0.012,
			"%s: observed %.4f expected %.4f" % [fish_id, share, expected[fish_id] / total])
	assert_eq(counts.size(), expected.size(), "a candidate never appeared in %d rolls" % rolls)

func test_time_weather_and_bait_multipliers_apply() -> void:
	var resolver := _resolver()
	var fish_def := _fish("fish_a", 10.0)
	fish_def["time_bands"] = {"dusk": 1.5}
	fish_def["weather"] = {"rain": 2.0}
	var request := _request()
	assert_eq(resolver.calculate_weight(fish_def, request), 10.0)
	request.time_band = "dusk"
	request.weather_id = "rain"
	assert_true(absf(resolver.calculate_weight(fish_def, request) - 30.0) < 0.0001)
	request.bait_tags = ["bread"]
	var bait: float = ContentDB.balance["encounter"]["bait_match_multiplier"]
	assert_true(absf(resolver.calculate_weight(fish_def, request) - 30.0 * bait) < 0.0001)
	request.bait_tags = ["worm"]
	assert_true(absf(resolver.calculate_weight(fish_def, request) - 30.0) < 0.0001, "a non-matching bait must not boost")

func test_temporary_modifier_scales_one_fish() -> void:
	var resolver := _resolver()
	var fish_def := _fish("fish_a", 4.0)
	var request := _request()
	request.modifiers = {"fish_a": 3.0}
	assert_eq(resolver.calculate_weight(fish_def, request), 12.0)

func test_ecosystem_level_boosts_rare_fish_more() -> void:
	var resolver := _resolver()
	var common := _fish("fish_common", 1.0, 1)
	var legendary := _fish("fish_legend", 1.0, 5)
	assert_eq(resolver.ecosystem_multiplier(common, 5), 1.0, "tier 1 gets no ecosystem bonus")
	assert_eq(resolver.ecosystem_multiplier(legendary, 0), 1.0)
	var bonus: float = ContentDB.balance["encounter"]["ecosystem_rarity_bonus_per_level"]
	assert_true(absf(resolver.ecosystem_multiplier(legendary, 5) - (1.0 + 5.0 * bonus)) < 0.0001)
	assert_true(resolver.ecosystem_multiplier(legendary, 3) < resolver.ecosystem_multiplier(legendary, 5))
	assert_eq(resolver.ecosystem_multiplier(legendary, -4), 1.0, "negative level must not reduce weight")

# --- pity ---

func test_pity_grows_per_miss_and_is_capped() -> void:
	var resolver := _resolver()
	var rare := _fish("fish_rare", 1.0, 4)
	var request := _request()
	var step: float = ContentDB.balance["encounter"]["pity_step"]
	var cap: float = ContentDB.balance["encounter"]["pity_cap"]
	assert_eq(resolver.pity_multiplier(rare, request), 1.0)
	request.miss_counts = {"fish_rare": 2}
	assert_true(absf(resolver.pity_multiplier(rare, request) - (1.0 + 2.0 * step)) < 0.0001)
	request.miss_counts = {"fish_rare": 1000}
	assert_true(absf(resolver.pity_multiplier(rare, request) - (1.0 + cap)) < 0.0001, "pity must be capped")

func test_pity_only_applies_to_rare_fish_and_resets_without_misses() -> void:
	var resolver := _resolver()
	var common := _fish("fish_common", 1.0, 1)
	var request := _request()
	request.miss_counts = {"fish_common": 9}
	assert_eq(resolver.pity_multiplier(common, request), 1.0, "tier 1 fish must not receive pity")
	var rare := _fish("fish_rare", 1.0, 3)
	request.miss_counts = {"fish_rare": 4}
	assert_true(resolver.pity_multiplier(rare, request) > 1.0)
	request.miss_counts = {}
	assert_eq(resolver.pity_multiplier(rare, request), 1.0, "clearing misses resets pity")

func test_pity_makes_the_missed_rare_fish_more_likely() -> void:
	var resolver := _resolver()
	var candidates := [_fish("fish_common", 10.0, 1), _fish("fish_rare", 1.0, 4)]
	var request := _request()
	var before := resolver.resolve(request, candidates, _rng(1))
	request.miss_counts = {"fish_rare": 10}
	var rng := _rng(1)
	var rare_count := 0
	for i in 4000:
		if resolver.resolve(request, candidates, rng).fish_id == "fish_rare":
			rare_count += 1
	var expected_share := 2.0 / 12.0  # weight 1 x (1 + cap 1.0) against 10
	assert_true(absf(rare_count / 4000.0 - expected_share) < 0.02, "rare share %.3f" % (rare_count / 4000.0))
	assert_not_null(before)

# --- output ---

func test_encounter_metadata_and_size_range() -> void:
	var resolver := _resolver()
	var candidates := ContentDB.get_fish_for_region(REGION)
	var request := _request("open_water")
	var rng := _rng(77)
	for i in 300:
		var encounter := resolver.resolve(request, candidates, rng)
		var def := ContentDB.get_fish(encounter.fish_id)
		assert_true("open_water" in def["habitats"], "%s does not live in open_water" % encounter.fish_id)
		assert_true(encounter.size_cm >= def["size_cm"]["min"] and encounter.size_cm <= def["size_cm"]["max"],
			"%s size %s outside %s" % [encounter.fish_id, encounter.size_cm, def["size_cm"]])
		assert_eq(encounter.rarity, int(def["rarity"]))
		assert_eq(encounter.behavior, def["behavior"])
		assert_true(encounter.probability > 0.0 and encounter.probability <= 1.0)
		assert_true(encounter.candidate_count >= 1)

func test_sizes_skew_small() -> void:
	var resolver := _resolver()
	var fish_def := _fish("fish_a", 1.0)
	var rng := _rng(4)
	var below_midpoint := 0
	for i in 2000:
		if resolver.roll_size(fish_def, rng) < 15.0:
			below_midpoint += 1
	assert_true(below_midpoint > 1000, "size distribution should favour small fish (%d/2000 below midpoint)" % below_midpoint)

func test_region_fish_cache_returns_only_that_region() -> void:
	var fish_list := ContentDB.get_fish_for_region(REGION)
	assert_eq(fish_list.size(), 10)
	for fish_def in fish_list:
		assert_true(REGION in fish_def["regions"])
	assert_true(ContentDB.get_fish_for_region("region_09_nowhere").is_empty())
