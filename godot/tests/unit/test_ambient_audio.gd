extends TestCase

## P0-022: ambient audio layering — loops follow weather/time, wildlife follows band and recovery,
## fishing cues play, and the voice count stays bounded.

const REGION := "region_01_quiet_pond"

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _audio(band: String = "day", cloud: float = 0.0, rain: float = 0.0, level: int = 0) -> AmbientAudio:
	var node := AmbientAudio.new()
	node.rng.seed = 1
	node.context_provider = func() -> Dictionary: return {"time_band": band, "cloud": cloud, "rain": rain, "level": level}
	tree.root.add_child(node)
	node.setup(REGION, null)
	return node

# --- data ---

func test_audio_content_is_valid_and_every_stream_loads() -> void:
	assert_false(ContentDB.audio.is_empty(), "audio.json failed validation: %s" % ContentDB.errors)
	var paths: Array = []
	for loop in ContentDB.audio["loops"]:
		paths.append(loop["stream"])
	for clip in ContentDB.audio["wildlife"]["clips"]:
		paths.append(clip["stream"])
	for cue in ContentDB.audio["cues"].values():
		paths.append(cue["stream"])
	for path in paths:
		var stream: Variant = load(path)
		assert_true(stream is AudioStreamWAV, "%s did not import as a WAV" % path)
		if stream is AudioStreamWAV:
			assert_true(stream.get_length() > 0.1, "%s is suspiciously short" % path)

func test_loops_are_long_enough_and_start_where_they_end() -> void:
	for loop in ContentDB.audio["loops"]:
		var stream: AudioStreamWAV = load(loop["stream"])
		assert_true(stream.get_length() >= 5.0, "%s loops too quickly" % loop["id"])
		# A click at the loop point would be a jump between the last and the first sample. The source
		# file is checked (the imported stream may be compressed): 16-bit mono after a 44-byte header.
		# Noise changes a lot between neighbouring samples anyway, so the jump at the loop point is
		# compared with the signal's own typical step.
		var bytes := FileAccess.get_file_as_bytes(loop["stream"])
		var typical_step := 0.0
		for i in 2000:
			typical_step += absf(bytes.decode_s16(44 + (i + 1) * 2) - bytes.decode_s16(44 + i * 2)) / 32768.0
		typical_step /= 2000.0
		var jump := absf(bytes.decode_s16(44) - bytes.decode_s16(bytes.size() - 2)) / 32768.0
		assert_true(jump <= typical_step * 6.0 + 0.02, "%s: loop point jumps by %.3f (typical step %.3f)" % [loop["id"], jump, typical_step])

func test_every_bus_named_in_the_data_exists() -> void:
	for loop in ContentDB.audio["loops"]:
		assert_true(AudioServer.get_bus_index(loop["bus"]) >= 0, loop["bus"])
	assert_true(AudioServer.get_bus_index(ContentDB.audio["wildlife"]["bus"]) >= 0)
	for cue in ContentDB.audio["cues"].values():
		assert_true(AudioServer.get_bus_index(cue["bus"]) >= 0, cue["bus"])

# --- mix rules ---

func test_loop_targets_follow_weather_and_time() -> void:
	var config: Dictionary = ContentDB.audio
	var clear := AmbientMix.loop_targets(config, "day", 0.1, 0.0)
	var rain := AmbientMix.loop_targets(config, "day", 1.0, 1.0)
	var night := AmbientMix.loop_targets(config, "night", 0.1, 0.0)
	assert_eq(clear["rain"], 0.0, "no rain sound in clear weather")
	assert_true(rain["rain"] > 0.5)
	assert_true(rain["water"] > clear["water"], "rain makes the water louder")
	assert_true(rain["wind"] > clear["wind"], "clouds bring wind")
	assert_true(night["wind"] < clear["wind"], "nights are calmer")
	for targets in [clear, rain, night]:
		for loop_id in targets:
			assert_true(targets[loop_id] >= 0.0 and targets[loop_id] <= 1.0, "%s out of range" % loop_id)

func test_wildlife_depends_on_time_band_and_recovery() -> void:
	var config: Dictionary = ContentDB.audio
	var ids := func(band: String, level: int) -> Array:
		return AmbientMix.clip_candidates(config, band, level).map(func(c: Dictionary) -> String: return c["id"])
	assert_deep_eq(ids.call("night", 0), [], "a barren pond is silent at night")
	assert_deep_eq(ids.call("day", 0), ["bird_a"])
	assert_true("frog" in ids.call("night", 1))
	assert_true("cricket" in ids.call("night", 2) and "cricket" not in ids.call("night", 1))
	assert_true("bird_b" in ids.call("day", 2))
	assert_false("frog" in ids.call("day", 5), "frogs only call at dusk and night")
	var rng := _rng(1)
	assert_deep_eq(AmbientMix.pick_clip(config, "night", 0, rng), {})

func test_clip_choice_is_weighted_and_reproducible() -> void:
	var config: Dictionary = ContentDB.audio
	var first := _rng(7)
	var second := _rng(7)
	for i in 30:
		assert_eq(AmbientMix.pick_clip(config, "night", 5, first)["id"], AmbientMix.pick_clip(config, "night", 5, second)["id"])
	var counts := {}
	var rng := _rng(3)
	for i in 3000:
		var id: String = AmbientMix.pick_clip(config, "night", 5, rng)["id"]
		counts[id] = counts.get(id, 0) + 1
	assert_true(counts["cricket"] > counts["fish_jump"] * 2, "heavier clips must be chosen more often: %s" % counts)

func test_a_livelier_pond_is_heard_more_often() -> void:
	var config: Dictionary = ContentDB.audio
	var level0 := 0.0
	var level5 := 0.0
	var rng := _rng(5)
	for i in 400:
		level0 += AmbientMix.next_delay(config, 0, rng)
		level5 += AmbientMix.next_delay(config, 5, rng)
	assert_true(level5 < level0 * 0.8, "average delay %.1f vs %.1f" % [level5 / 400.0, level0 / 400.0])
	var interval: Dictionary = config["wildlife"]["interval_sec"]
	assert_true(AmbientMix.next_delay(config, 0, rng) >= float(interval["min"]) - 0.001)

func test_db_conversion_has_a_silent_floor() -> void:
	assert_eq(AmbientMix.to_db(0.0), -80.0)
	assert_eq(AmbientMix.to_db(0.0001), -80.0)
	assert_true(absf(AmbientMix.to_db(1.0)) < 0.001)
	assert_true(AmbientMix.to_db(0.5) < 0.0)

# --- the node ---

func test_layers_are_created_on_their_buses_and_loop() -> void:
	var audio := _audio("day", 1.0, 1.0)  # rain, so that every layer is audible
	for loop in ContentDB.audio["loops"]:
		var player := audio.loop_player(loop["id"])
		assert_not_null(player, loop["id"])
		assert_eq(String(player.bus), loop["bus"])
		assert_true(player.playing, "%s is not playing" % loop["id"])
		var looped := player.stream as AudioStreamWAV
		assert_eq(looped.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_eq(looped.loop_end, roundi(looped.get_length() * looped.mix_rate), "the loop must cover the whole stream")
	audio.free()

func test_loops_start_at_their_target_and_silent_layers_are_paused() -> void:
	var clear := _audio("day", 0.1, 0.0)
	assert_true(clear.loop_volume("water") > 0.4)
	assert_eq(clear.loop_volume("rain"), 0.0)
	assert_true(clear.loop_player("rain").stream_paused, "a silent layer should not cost CPU")
	assert_false(clear.loop_player("water").stream_paused)
	clear.free()
	var rainy := _audio("day", 1.0, 1.0)
	assert_true(rainy.loop_volume("rain") > 0.5)
	assert_false(rainy.loop_player("rain").stream_paused)
	rainy.free()

func test_layers_fade_instead_of_jumping() -> void:
	var rain := [0.0]
	var node := AmbientAudio.new()
	node.rng.seed = 2
	node.context_provider = func() -> Dictionary: return {"time_band": "day", "cloud": rain[0], "rain": rain[0], "level": 0}
	tree.root.add_child(node)
	node.setup(REGION, null)
	assert_eq(node.loop_volume("rain"), 0.0)
	rain[0] = 1.0
	node.refresh_now()
	node._process(1.0)
	var after_one_second: float = node.loop_volume("rain")
	assert_true(after_one_second > 0.0 and after_one_second <= float(ContentDB.audio["fade_per_sec"]) + 0.001, "rain rose by %.2f in 1 s" % after_one_second)
	assert_true(after_one_second < node.loop_target("rain"), "it should still be fading in")
	for i in 10:
		node._process(1.0)
	assert_true(absf(node.loop_volume("rain") - node.loop_target("rain")) < 0.001)
	node.free()

func test_the_voice_count_is_bounded() -> void:
	var audio := _audio("night", 0.0, 0.0, 5)
	var voices := audio.voice_count()
	var children := audio.get_child_count()
	for i in 80:
		audio.play_cue("caught")
		audio.play_wildlife()
	assert_eq(audio.voice_count(), voices, "playing sounds must never add players")
	assert_eq(audio.get_child_count(), children)
	assert_true(voices <= 12, "%d players" % voices)
	audio.free()

func test_cues_play_and_unknown_cues_are_refused() -> void:
	var audio := _audio()
	for cue_id in ContentDB.audio["cues"]:
		assert_true(audio.play_cue(cue_id), cue_id)
	assert_false(audio.play_cue("nonsense"))
	audio.free()

func test_fishing_events_trigger_their_cues() -> void:
	var audio := _audio()
	var playing := func() -> int:
		var count := 0
		for child in audio.get_children():
			if child.name.begins_with("OneShot") and (child as AudioStreamPlayer).playing:
				count += 1
		return count
	assert_eq(playing.call(), 0)
	EventBus.bite_hinted.emit()
	assert_eq(playing.call(), 1, "the bite cue must sound")
	EventBus.fish_caught.emit("fish_minnow", 10.0, false)
	assert_eq(playing.call(), 2)
	EventBus.fishing_state_changed.emit("ready", "cast")
	assert_eq(playing.call(), 3, "casting has a sound")
	EventBus.fishing_state_changed.emit("cast", "wait")
	assert_eq(playing.call(), 3, "other state changes are silent")
	audio.free()

func test_a_barren_night_stays_quiet_and_a_restored_day_has_birds() -> void:
	var barren := _audio("night", 0.0, 0.0, 0)
	assert_eq(barren.play_wildlife(), "")
	barren.free()
	var lively := _audio("day", 0.0, 0.0, 4)
	var heard := {}
	for i in 60:
		heard[lively.play_wildlife()] = true
	assert_true(heard.has("bird_a"))
	assert_false(heard.has("frog"))
	lively.free()

func test_battery_saver_slows_the_wildlife_schedule() -> void:
	var audio := _audio("day", 0.0, 0.0, 3)
	var normal := _wildlife_wait(audio)
	GameState.new_game()
	GameState.set_setting("battery_saver", true)
	var saver := _wildlife_wait(audio)
	GameState.new_game()
	assert_true(saver > normal * 1.2, "saver %.1f vs normal %.1f" % [saver, normal])
	audio.free()

## Seconds the wildlife timer is set to after it fires (same seed each time).
func _wildlife_wait(audio: AmbientAudio) -> float:
	audio.rng.seed = 11
	audio._wildlife_left = 0.0
	audio._process(0.01)
	return audio._wildlife_left
