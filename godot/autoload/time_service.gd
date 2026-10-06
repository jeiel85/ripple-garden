extends Node

## Clocks (TECH_SPEC §10).
##  - Session clock: monotonic seconds since launch; unaffected by wall-clock changes.
##  - Game clock: minutes since midnight in [0, 1440). By default one game day is 24 real minutes
##    (GDD §13). With Real-time Mode on it follows the device's local time instead.
##  - Offline: time away is the wall-clock difference, clamped to [0, 12h], so a clock set back
##    never yields negative time and a long absence never yields an unbounded jump.
##  - Time-band events: `EventBus.game_time_band_changed` fires only when the band changes.
##
## Day length and band boundaries are content (`balance.json` -> `time`). The fallbacks below
## apply only when that content failed to load; ContentDB.errors already reports why.

const OFFLINE_CAP_SEC := 12 * 60 * 60
## Every value get_time_band() can return. Content time_bands keys are validated against this.
const TIME_BANDS: PackedStringArray = ["dawn", "morning", "day", "dusk", "night"]
const FALLBACK_DAY_LENGTH_SEC := 1440.0
const FALLBACK_BAND_STARTS := {"dawn": 5.0, "morning": 7.0, "day": 11.0, "dusk": 17.0, "night": 20.0}
const MINUTES_PER_DAY := 1440.0

var game_minutes: float = 8.0 * 60.0
var paused := false
var real_time_mode := false
## Tests inject deterministic clocks. wall_clock() -> unix seconds, local_minutes() -> 0..1440.
var wall_clock := Callable()
var local_minutes := Callable()
## State holder; defaults to the GameState autoload, tests inject their own instance.
var state: Node = null

var _start_msec := 0
var _band := ""
var _paused_at := -1.0

func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	_band = get_time_band()
	EventBus.game_state_replaced.connect(restore_from_state)
	EventBus.settings_changed.connect(_on_setting_changed)
	SaveService.about_to_save.connect(sync_to_state)

func _process(delta: float) -> void:
	advance(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		on_app_paused()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		on_app_resumed()

# --- clocks ---

## Monotonic seconds since the game started.
func session_seconds() -> float:
	return (Time.get_ticks_msec() - _start_msec) / 1000.0

func minutes_per_real_second() -> float:
	return MINUTES_PER_DAY / _day_length_sec()

## Moves the game clock forward by `delta` real seconds.
func advance(delta: float) -> void:
	if paused or delta <= 0.0:
		return
	_advance_game(delta)

func _advance_game(real_seconds: float) -> void:
	if real_time_mode:
		game_minutes = _local_minutes()
	else:
		game_minutes = fposmod(game_minutes + real_seconds * minutes_per_real_second(), MINUTES_PER_DAY)
	_check_band()

func set_game_minutes(minutes: float) -> void:
	game_minutes = fposmod(minutes, MINUTES_PER_DAY)
	_check_band()

func get_hours() -> float:
	return game_minutes / 60.0

func get_time_band() -> String:
	return band_for_minutes(game_minutes, _band_starts())

## Band for a time of day. Bands begin at `starts[band]` hours; the last one (night) wraps past
## midnight to the first band's start.
static func band_for_minutes(minutes: float, starts: Dictionary) -> String:
	var hour := fposmod(minutes, MINUTES_PER_DAY) / 60.0
	var current: String = TIME_BANDS[TIME_BANDS.size() - 1]  # before the first start we are still in the night band
	for band in TIME_BANDS:
		if hour >= float(starts[band]):
			current = band
	return current

func _check_band() -> void:
	var band := get_time_band()
	if band != _band:
		_band = band
		EventBus.game_time_band_changed.emit(band)

# --- offline ---

## Seconds away since `last_session_at` (unix seconds), clamped to [0, OFFLINE_CAP_SEC].
func offline_seconds(last_session_at: int) -> int:
	return clampi(int(_wall_now()) - last_session_at, 0, OFFLINE_CAP_SEC)

## Offline seconds announced but not yet handled by the world. The load-time catch-up happens before the
## game scene has connected to EventBus, so the scene claims it once it is ready (P1-007).
var _unclaimed_offline := 0

## Returns the offline seconds nobody has handled yet and forgets them.
func claim_offline() -> int:
	var away := _unclaimed_offline
	_unclaimed_offline = 0
	return away

func _announce_offline(away: int) -> void:
	_unclaimed_offline = mini(OFFLINE_CAP_SEC, _unclaimed_offline + away)
	EventBus.offline_time_elapsed.emit(away)

func on_app_paused() -> void:
	_paused_at = _wall_now()

## The app is back after being suspended: the clock catches up on the (clamped) time away.
func on_app_resumed() -> void:
	if _paused_at < 0.0:
		return
	var away := clampi(int(_wall_now() - _paused_at), 0, OFFLINE_CAP_SEC)
	_paused_at = -1.0
	if away > 0:
		_advance_game(away)
		_announce_offline(away)

## Pretends the player was away for `seconds` (clamped like a real absence): the game clock catches
## up and the offline event fires. Used by the QA debug menu; returns the seconds applied.
func skip_time(seconds: int) -> int:
	if not BuildProfile.debug_tools_enabled():
		return 0  # defence in depth: only the QA tools may fast-forward the clock
	var away := clampi(seconds, 0, OFFLINE_CAP_SEC)
	if away > 0:
		_advance_game(away)
		_announce_offline(away)
	return away

# --- persistence ---

## Writes the game clock into GameState (called right before every save).
func sync_to_state() -> void:
	_state().set_game_minutes(game_minutes)

## Adopts the clock stored in GameState and catches up on time spent offline. Runs whenever the
## whole state is replaced (new game, load, debug reset).
func restore_from_state() -> void:
	real_time_mode = _state().get_setting("real_time_mode") == true
	game_minutes = _state().get_game_minutes()
	var away := offline_seconds(_state().get_last_session_at())
	if away > 0:
		_advance_game(away)
	_check_band()
	if away > 0:
		_announce_offline(away)

func _on_setting_changed(key: String) -> void:
	if key != "real_time_mode":
		return
	real_time_mode = _state().get_setting(key) == true
	if real_time_mode:
		game_minutes = _local_minutes()
	_check_band()

# --- config / providers ---

func _state() -> Node:
	return state if state != null else GameState

func _day_length_sec() -> float:
	var time_config: Dictionary = ContentDB.balance.get("time", {})
	return float(time_config.get("day_length_real_sec", FALLBACK_DAY_LENGTH_SEC))

func _band_starts() -> Dictionary:
	var time_config: Dictionary = ContentDB.balance.get("time", {})
	return time_config.get("band_starts_hour", FALLBACK_BAND_STARTS)

func _wall_now() -> float:
	return wall_clock.call() if wall_clock.is_valid() else Time.get_unix_time_from_system()

func _local_minutes() -> float:
	if local_minutes.is_valid():
		return local_minutes.call()
	var now := Time.get_time_dict_from_system(false)
	return now["hour"] * 60.0 + now["minute"] + now["second"] / 60.0
