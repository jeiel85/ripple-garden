extends Node

const OFFLINE_CAP_SEC := 12 * 60 * 60
## Every value get_time_band() can return. Content time_bands keys are validated against this.
const TIME_BANDS: PackedStringArray = ["dawn", "day", "dusk", "night"]
var game_minutes: float = 8.0 * 60.0
var minutes_per_real_second: float = 1.0
var paused := false

func _process(delta: float) -> void:
	if paused:
		return
	game_minutes = fmod(game_minutes + delta * minutes_per_real_second, 1440.0)

func get_time_band() -> String:
	var h := game_minutes / 60.0
	if h < 6.0:
		return "night"
	if h < 9.0:
		return "dawn"
	if h < 17.0:
		return "day"
	if h < 20.0:
		return "dusk"
	return "night"

func offline_seconds(last_session_at: int) -> int:
	var now := int(Time.get_unix_time_from_system())
	return clampi(now - last_session_at, 0, OFFLINE_CAP_SEC)
