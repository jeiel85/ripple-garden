class_name AmbientAudio
extends Node

## Plays the soundscape described by data/audio.json (P0-022): looping water, wind and rain layers
## on their own buses, randomised wildlife one-shots and the fishing cues. Layer loudness eases
## towards the target from AmbientMix (weather, time of day) so conditions never jump. Everything is
## pooled: three loop players plus a small fixed pool of one-shot players, so the number of audio
## voices is bounded no matter how long the game runs (TECH_SPEC §14 soak goal).
##
## The sounds are generated placeholders (tools/generate_placeholder_audio.py, D-013). The BGM bus
## is intentionally silent until music is produced.

const ONE_SHOT_VOICES := 6
const TARGET_STEP_SEC := 0.25

var config: Dictionary = {}
var region_id := ""
var rng := RandomNumberGenerator.new()
## () -> {"time_band": String, "cloud": float, "rain": float, "level": int}; defaults read the game.
var context_provider := Callable()

var _loops: Dictionary = {}
var _shots: Array[AudioStreamPlayer] = []
var _next_shot := 0
var _wildlife_left := 0.0
var _step_left := 0.0
var _cue_streams: Dictionary = {}
var _clip_streams: Dictionary = {}
var _context: Dictionary = {}
var _weather: WeatherService = null

## `weather` provides the cloud/rain amounts; the rest comes from TimeService and GameState.
func setup(p_region_id: String, weather: WeatherService) -> void:
	config = ContentDB.audio
	region_id = p_region_id
	_weather = weather
	rng.randomize()
	if config.is_empty():
		push_error("AmbientAudio: audio.json is missing or invalid; the soundscape stays silent")
		return
	for loop in config["loops"]:
		var player := AudioStreamPlayer.new()
		player.name = "Loop_%s" % loop["id"]
		player.stream = _loop_stream(loop["stream"])
		player.bus = loop["bus"]
		player.volume_db = -80.0
		add_child(player)
		player.play()
		_loops[loop["id"]] = {"player": player, "current": 0.0, "target": 0.0}
	for i in ONE_SHOT_VOICES:
		var shot := AudioStreamPlayer.new()
		shot.name = "OneShot_%d" % i
		add_child(shot)
		_shots.append(shot)
	for cue_id in config["cues"]:
		_cue_streams[cue_id] = load(config["cues"][cue_id]["stream"])
	for clip in config["wildlife"]["clips"]:
		_clip_streams[clip["id"]] = load(clip["stream"])
	_wildlife_left = AmbientMix.next_delay(config, _level(), rng)
	_refresh_context()
	for loop_id in _loops:
		_loops[loop_id]["current"] = _loops[loop_id]["target"]  # start at the right loudness, no swell-in
	_apply_volumes(0.0)

	EventBus.fishing_state_changed.connect(func(_previous: String, current: String) -> void:
		if current == "cast":
			play_cue("cast"))
	EventBus.cast_landed.connect(func(_position: Vector2, _habitat: String) -> void: play_cue("landed"))
	EventBus.bite_hinted.connect(func() -> void: play_cue("bite"))
	EventBus.fish_hooked.connect(func(_fish_id: String) -> void: play_cue("hooked"))
	EventBus.fish_caught.connect(func(_fish_id: String, _size_cm: float, _first: bool) -> void: play_cue("caught"))
	EventBus.fish_released.connect(func(_fish_id: String, _region: String, _size_cm: float) -> void: play_cue("released"))
	EventBus.fish_escaped.connect(func(_fish_id: String, _reason: String) -> void: play_cue("escaped"))

## Loop streams repeat forever without a click (the files are cross-faded at generation time). The
## loop end is the stream's length in samples, which holds for every import format (the default
## import compresses WAVs to QOA, so the byte size says nothing about the sample count).
func _loop_stream(path: String) -> AudioStream:
	var source: AudioStreamWAV = load(path)
	var stream: AudioStreamWAV = source.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(source.get_length() * source.mix_rate)
	return stream

func _level() -> int:
	return GameState.get_restoration_level(region_id)

func _read_context() -> Dictionary:
	if context_provider.is_valid():
		return context_provider.call()
	var visual := _weather.visual() if _weather != null else {"cloud": 0.0, "rain": 0.0}
	return {"time_band": TimeService.get_time_band(), "cloud": visual["cloud"], "rain": visual["rain"], "level": _level()}

func _refresh_context() -> void:
	_context = _read_context()
	var targets := AmbientMix.loop_targets(config, _context["time_band"], _context["cloud"], _context["rain"])
	for loop_id in _loops:
		_loops[loop_id]["target"] = targets.get(loop_id, 0.0)

func _process(delta: float) -> void:
	if config.is_empty():
		return
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = TARGET_STEP_SEC
		_refresh_context()
	_apply_volumes(delta)
	_wildlife_left -= delta
	if _wildlife_left <= 0.0:
		_wildlife_left = AmbientMix.next_delay(config, _context.get("level", 0), rng) * (1.6 if GameState.get_setting("battery_saver") == true else 1.0)
		play_wildlife()

## Moves every loop towards its target by at most `fade_per_sec` and pauses silent ones.
func _apply_volumes(delta: float) -> void:
	var step := float(config["fade_per_sec"]) * delta
	for loop_id in _loops:
		var entry: Dictionary = _loops[loop_id]
		entry["current"] = move_toward(entry["current"], entry["target"], step)
		var player: AudioStreamPlayer = entry["player"]
		player.volume_db = AmbientMix.to_db(entry["current"])
		player.stream_paused = entry["current"] <= 0.0005 and entry["target"] <= 0.0005

## Plays one wildlife clip suited to now. Returns the clip id, or "" when it is quiet here.
func play_wildlife() -> String:
	var clip := AmbientMix.pick_clip(config, _context.get("time_band", "day"), _context.get("level", 0), rng)
	if clip.is_empty():
		return ""
	_play_one_shot(_clip_streams[clip["id"]], config["wildlife"]["bus"], AmbientMix.clip_volume(config, rng))
	return clip["id"]

## Plays a fishing cue ("cast", "landed", "bite", "hooked", "caught", "released", "escaped").
func play_cue(cue_id: String) -> bool:
	if not _cue_streams.has(cue_id):
		return false
	var cue: Dictionary = config["cues"][cue_id]
	_play_one_shot(_cue_streams[cue_id], cue["bus"], float(cue["volume"]))
	return true

func _play_one_shot(stream: AudioStream, bus: String, volume: float) -> void:
	# Round-robin over a fixed pool: an old sound is cut rather than adding another voice.
	var player := _shots[_next_shot]
	_next_shot = (_next_shot + 1) % _shots.size()
	player.stream = stream
	player.bus = bus
	player.volume_db = AmbientMix.to_db(volume)
	player.play()

# --- inspection (tests, debug) ---

func loop_target(loop_id: String) -> float:
	return _loops[loop_id]["target"] if _loops.has(loop_id) else -1.0

func loop_volume(loop_id: String) -> float:
	return _loops[loop_id]["current"] if _loops.has(loop_id) else -1.0

func loop_player(loop_id: String) -> AudioStreamPlayer:
	return _loops[loop_id]["player"] if _loops.has(loop_id) else null

func voice_count() -> int:
	return _loops.size() + _shots.size()

func refresh_now() -> void:
	_refresh_context()
