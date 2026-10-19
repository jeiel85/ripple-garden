class_name UiSound
extends RefCounted

## One-shot interface sounds (BACKLOG "오디오: 버튼 소리"), data-driven from data/audio.json `ui`.
## Every UiKit button presses through here, so the players are a fixed pool under the scene tree
## root: a mashed button cuts an older sound instead of adding a voice (TECH_SPEC §14 soak goal).
## Loudness is the Ui bus's, set by the volume_ui setting through SettingsApplier.

const VOICES := 2
const DEFAULT_BUS := "Ui"

static var _players: Array[AudioStreamPlayer] = []
static var _next := 0
static var _streams: Dictionary = {}
static var _last := ""

## Plays one interface sound; false when it is unknown or audio.json has no ui section.
static func play(sound: String) -> bool:
	var ui: Dictionary = ContentDB.audio.get("ui", {})
	var sounds: Dictionary = ui.get("sounds", {})
	if not sounds.has(sound):
		return false
	var path: String = sounds[sound].get("stream", "")
	if path.is_empty():
		return false
	var player := _player()
	if player == null:
		return false
	if not _streams.has(path):
		_streams[path] = load(path)
		if _streams[path] == null:
			push_warning("UiSound: %s could not be loaded" % path)
			return false
	player.stream = _streams[path]
	player.bus = ui.get("bus", DEFAULT_BUS)
	player.volume_db = AmbientMix.to_db(float(sounds[sound].get("volume", 0.5)))
	player.play()
	_last = sound
	return true

## The sound last played (tests, debug).
static func last_played() -> String:
	return _last

## The pooled player count, which never grows (tests, debug).
static func voice_count() -> int:
	return _players.size()

## Round-robin over the pool, created on first use under the scene tree root.
static func _player() -> AudioStreamPlayer:
	if _players.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		var root: Window = tree.root
		for i in VOICES:
			var player := AudioStreamPlayer.new()
			player.name = "UiSound_%d" % i
			root.add_child(player)
			_players.append(player)
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	return player
