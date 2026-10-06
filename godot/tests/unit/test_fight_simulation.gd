extends TestCase

## P0-015: fight tension simulation. Besides mechanics, these tests check the balance data: every
## shipped species must be landable by a steady player, and the two lazy strategies (never reel,
## always reel) must lose, otherwise the fight would have no skill in it.

const DT := 1.0 / 60.0
const STEADY_ROD_ASSIST := 0.1  # the weakest assist among the starter rods

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _fight(fish_id: String, seed_value: int = 1, assist: float = STEADY_ROD_ASSIST) -> FightSimulation:
	var fish_def := ContentDB.get_fish(fish_id)
	return FightSimulation.new(fish_def, ContentDB.get_behavior(fish_def["behavior"]),
		ContentDB.balance["fishing"]["fight"], assist, _rng(seed_value))

## Reels whenever tension is below the middle of the band: what a calm, attentive player does.
func _play_steady(sim: FightSimulation, max_seconds: float = 120.0, dt: float = DT) -> void:
	var middle := (sim.band_min() + sim.band_max()) / 2.0
	var elapsed := 0.0
	while sim.result == FightSimulation.Result.ONGOING and elapsed < max_seconds:
		sim.step(dt, sim.tension < middle)
		elapsed += dt

func test_every_species_can_be_landed_by_a_steady_player() -> void:
	for fish_id in ContentDB.fish:
		for seed_value in [1, 2, 3]:
			var sim := _fight(fish_id, seed_value)
			_play_steady(sim)
			assert_eq(sim.result, FightSimulation.Result.LANDED, "%s (seed %d) ended %s after %.1fs" % [
				fish_id, seed_value, FightSimulation.Result.keys()[sim.result], sim.elapsed])

func test_a_well_played_fight_lasts_about_the_species_duration() -> void:
	for fish_id in ContentDB.get_fish_for_region("region_01_quiet_pond").map(func(f: Dictionary) -> String: return f["id"]):
		var sim := _fight(fish_id)
		_play_steady(sim)
		var duration: float = ContentDB.get_fish(fish_id)["fight"]["duration_sec"]
		assert_true(sim.elapsed > duration * 0.3 and sim.elapsed < duration * 2.0,
			"%s: fight took %.1fs against a nominal %.1fs" % [fish_id, sim.elapsed, duration])

func test_never_reeling_loses_the_fish_to_a_slack_line() -> void:
	var sim := _fight("fish_crucian_carp")
	var elapsed := 0.0
	while sim.result == FightSimulation.Result.ONGOING and elapsed < 60.0:
		sim.step(DT, false)
		elapsed += DT
	assert_eq(sim.result, FightSimulation.Result.SLACK)
	assert_true(elapsed < 10.0, "a slack line should end the fight reasonably soon (%.1fs)" % elapsed)

func test_reeling_forever_snaps_the_line() -> void:
	var sim := _fight("fish_crucian_carp")
	var elapsed := 0.0
	while sim.result == FightSimulation.Result.ONGOING and elapsed < 60.0:
		sim.step(DT, true)
		elapsed += DT
	assert_eq(sim.result, FightSimulation.Result.SNAPPED)

func test_same_seed_gives_the_same_fight() -> void:
	var first := _fight("fish_catfish", 42)
	var second := _fight("fish_catfish", 42)
	for i in 600:
		var holding := (i / 20) % 2 == 0
		first.step(DT, holding)
		second.step(DT, holding)
	assert_eq(first.tension, second.tension)
	assert_eq(first.progress, second.progress)
	assert_eq(first.result, second.result)

func test_tension_and_progress_stay_in_range() -> void:
	var sim := _fight("fish_snakehead", 7)
	for i in 1200:
		sim.step(DT, (i / 15) % 3 != 0)
		assert_true(sim.tension >= 0.0 and sim.tension <= 1.0, "tension %f" % sim.tension)
		assert_true(sim.progress >= 0.0 and sim.progress <= 1.0, "progress %f" % sim.progress)
		if sim.result != FightSimulation.Result.ONGOING:
			break

func test_progress_only_advances_inside_the_safe_band() -> void:
	var sim := _fight("fish_crucian_carp")
	var start := sim.progress
	# One long hold drives the tension out of the band's top; progress must not have kept rising.
	var peak := start
	for i in 300:
		sim.step(DT, true)
		peak = maxf(peak, sim.progress)
		if sim.result != FightSimulation.Result.ONGOING:
			break
	var after_overtight := sim.progress
	assert_true(after_overtight <= peak, "progress cannot grow while the line is overtight")
	assert_true(sim.tension > sim.band_max() or sim.result != FightSimulation.Result.ONGOING)

func test_step_after_the_end_changes_nothing() -> void:
	var sim := _fight("fish_crucian_carp")
	_play_steady(sim)
	var tension := sim.tension
	var elapsed := sim.elapsed
	sim.step(1.0, true)
	assert_eq(sim.tension, tension)
	assert_eq(sim.elapsed, elapsed)

func test_non_positive_delta_is_ignored() -> void:
	var sim := _fight("fish_crucian_carp")
	sim.step(0.0, true)
	sim.step(-1.0, true)
	assert_eq(sim.elapsed, 0.0)

func test_zigzag_pulls_in_both_directions_while_other_behaviors_only_tighten() -> void:
	var zigzag := _fight("fish_catfish", 5)  # behavior zigzag
	var steady := _fight("fish_crucian_carp", 5)  # behavior steady
	var zig_signs := {}
	var steady_signs := {}
	for i in 1800:
		zigzag.step(DT, (i / 30) % 2 == 0)
		steady.step(DT, (i / 30) % 2 == 0)
		if zigzag.pull_offset != 0.0:
			zig_signs[signf(zigzag.pull_offset)] = true
		if steady.pull_offset != 0.0:
			steady_signs[signf(steady.pull_offset)] = true
	assert_eq(zig_signs.size(), 2, "zigzag must pull both ways")
	assert_eq(steady_signs.keys(), [1.0], "a steady fish only pulls tighter")

func test_rod_assist_dampens_the_fish() -> void:
	var peak_without := 0.0
	var peak_with := 0.0
	var plain := _fight("fish_snakehead", 9, 0.0)
	var assisted := _fight("fish_snakehead", 9, 0.3)
	for i in 1800:
		plain.step(DT, (i / 30) % 2 == 0)
		assisted.step(DT, (i / 30) % 2 == 0)
		peak_without = maxf(peak_without, absf(plain.pull_offset))
		peak_with = maxf(peak_with, absf(assisted.pull_offset))
	assert_true(peak_with < peak_without, "assist %.3f vs none %.3f" % [peak_with, peak_without])

func test_outcome_is_stable_across_frame_rates() -> void:
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0]:
		var sim := _fight("fish_largemouth_bass", 11)
		_play_steady(sim, 120.0, dt)
		assert_eq(sim.result, FightSimulation.Result.LANDED, "frame time %.4f" % dt)

func test_behavior_content_is_referenced_by_every_fish() -> void:
	for fish_id in ContentDB.fish:
		assert_false(ContentDB.get_behavior(ContentDB.fish[fish_id]["behavior"]).is_empty(), fish_id)
