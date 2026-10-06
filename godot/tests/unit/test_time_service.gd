extends TestCase

## P0-007: session / game / offline clocks and time-band events.

var _now := 1_700_000_000.0

func _new_service(state: Node = null) -> Node:
	var service: Node = load("res://autoload/time_service.gd").new()
	service.wall_clock = func() -> float: return _now
	service.state = state
	return service

func _new_state() -> Node:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	return state

func test_default_day_is_24_real_minutes() -> void:
	var service := _new_service()
	assert_true(absf(service.minutes_per_real_second() - 1.0) < 0.0001, "1 game minute per real second")
	service.game_minutes = 0.0
	service.advance(60.0)
	assert_true(absf(service.game_minutes - 60.0) < 0.001)
	service.free()

func test_game_clock_wraps_at_midnight() -> void:
	var service := _new_service()
	service.game_minutes = 1439.0
	service.advance(3.0)
	assert_true(absf(service.game_minutes - 2.0) < 0.001, "clock was %s" % service.game_minutes)
	service.free()

func test_pause_and_non_positive_delta_do_not_advance() -> void:
	var service := _new_service()
	service.game_minutes = 100.0
	service.paused = true
	service.advance(30.0)
	assert_eq(service.game_minutes, 100.0)
	service.paused = false
	service.advance(-5.0)
	service.advance(0.0)
	assert_eq(service.game_minutes, 100.0, "negative or zero delta must not move the clock")
	service.free()

func test_band_boundaries_match_content() -> void:
	var starts: Dictionary = ContentDB.balance["time"]["band_starts_hour"]
	# balance.json (P1-005): dawn 5, morning 7, day 11, dusk 17, night 20.
	var cases := {0.0: "night", 4.99: "night", 5.0: "dawn", 6.99: "dawn", 7.0: "morning", 10.99: "morning",
		11.0: "day", 16.99: "day", 17.0: "dusk", 19.99: "dusk", 20.0: "night", 23.99: "night"}
	for hour in cases:
		assert_eq(TimeService.band_for_minutes(hour * 60.0, starts), cases[hour], "hour %s" % hour)
	assert_eq(TimeService.band_for_minutes(-60.0, starts), "night", "negative minutes wrap to the previous day")
	assert_eq(TimeService.band_for_minutes(25.0 * 60.0, starts), "night", "minutes past a day wrap")

func test_every_band_is_reachable_and_known() -> void:
	var service := _new_service()
	var seen := {}
	for hour in range(24):
		service.game_minutes = hour * 60.0
		seen[service.get_time_band()] = true
	for band in TimeService.TIME_BANDS:
		assert_true(seen.has(band), "band %s never reached" % band)
	assert_eq(seen.size(), TimeService.TIME_BANDS.size())
	service.free()

func test_band_change_event_fires_once_per_change() -> void:
	var service := _new_service()
	var bands: Array = []
	var handler := func(band: String) -> void: bands.append(band)
	EventBus.game_time_band_changed.connect(handler)
	service.set_game_minutes(4.0 * 60.0)  # night
	bands.clear()
	service.advance(30.0)   # 04:00 -> 04:30, still night (1 real second = 1 game minute)
	service.advance(40.0)   # -> 05:10 dawn
	service.advance(10.0)   # -> 05:20 still dawn
	service.advance(120.0)  # -> 07:20 morning
	service.advance(240.0)  # -> 11:20 day
	EventBus.game_time_band_changed.disconnect(handler)
	assert_deep_eq(bands, ["dawn", "morning", "day"])
	service.free()

func test_offline_seconds_clamps_to_cap_and_never_goes_negative() -> void:
	var service := _new_service()
	var now := int(_now)
	assert_eq(service.offline_seconds(now - 90), 90)
	assert_eq(service.offline_seconds(now - 30 * 3600), TimeService.OFFLINE_CAP_SEC, "long absence must clamp to 12h")
	assert_eq(service.offline_seconds(now + 5000), 0, "clock set back must not produce negative time")
	assert_eq(service.offline_seconds(now), 0)
	service.free()

func test_restore_catches_up_on_offline_time() -> void:
	var state := _new_state()
	state.set_game_minutes(600.0)
	state.touch_session(int(_now) - 120)
	var service := _new_service(state)
	var elapsed: Array = []
	var handler := func(seconds: int) -> void: elapsed.append(seconds)
	EventBus.offline_time_elapsed.connect(handler)
	service.restore_from_state()
	EventBus.offline_time_elapsed.disconnect(handler)
	assert_true(absf(service.game_minutes - 720.0) < 0.001, "120 s away = 120 game minutes; clock was %s" % service.game_minutes)
	assert_deep_eq(elapsed, [120])
	service.free()
	state.free()

func test_restore_after_new_game_has_no_offline_gap() -> void:
	var state := _new_state()
	state.touch_session(int(_now))
	var service := _new_service(state)
	var elapsed: Array = []
	var handler := func(seconds: int) -> void: elapsed.append(seconds)
	EventBus.offline_time_elapsed.connect(handler)
	service.restore_from_state()
	EventBus.offline_time_elapsed.disconnect(handler)
	assert_true(elapsed.is_empty(), "no event expected without an absence")
	assert_eq(service.game_minutes, 480.0)
	service.free()
	state.free()

func test_sync_to_state_stores_game_clock() -> void:
	var state := _new_state()
	var service := _new_service(state)
	service.game_minutes = 777.0
	service.sync_to_state()
	assert_eq(state.get_game_minutes(), 777.0)
	service.free()
	state.free()

func test_pause_resume_advances_by_time_away_with_clamping() -> void:
	var service := _new_service()
	service.game_minutes = 0.0
	service.on_app_paused()
	_now += 600.0
	service.on_app_resumed()
	assert_true(absf(service.game_minutes - 600.0) < 0.001, "resume must catch up on the 600 s away")

	service.on_app_paused()
	_now -= 3600.0  # wall clock set back while suspended
	var before: float = service.game_minutes
	service.on_app_resumed()
	assert_eq(service.game_minutes, before, "clock rollback must not move the game clock")

	service.on_app_resumed()  # resume without a matching pause is ignored
	assert_eq(service.game_minutes, before)

	service.on_app_paused()
	_now += 5.0 * 24.0 * 3600.0
	service.on_app_resumed()
	var expected := fposmod(before + TimeService.OFFLINE_CAP_SEC * service.minutes_per_real_second(), 1440.0)
	assert_true(absf(service.game_minutes - expected) < 0.01, "absence clamps to the 12h cap")
	service.free()

func test_real_time_mode_follows_local_clock() -> void:
	var service := _new_service()
	service.real_time_mode = true
	service.local_minutes = func() -> float: return 13.0 * 60.0 + 30.0
	service.advance(1.0)
	assert_eq(service.game_minutes, 810.0)
	assert_eq(service.get_time_band(), "day")
	service.free()

func test_enabling_real_time_mode_setting_snaps_to_local_clock() -> void:
	var state := _new_state()
	var service := _new_service(state)
	service.local_minutes = func() -> float: return 22.0 * 60.0
	state.set_setting("real_time_mode", true)
	service._on_setting_changed("real_time_mode")
	assert_true(service.real_time_mode)
	assert_eq(service.game_minutes, 1320.0)
	service._on_setting_changed("haptics")  # unrelated keys are ignored
	service.free()
	state.free()

func test_session_clock_is_monotonic() -> void:
	var service := _new_service()
	service._start_msec = Time.get_ticks_msec()
	var first: float = service.session_seconds()
	var second: float = service.session_seconds()
	assert_true(first >= 0.0 and second >= first)
	service.free()

func test_balance_time_config_is_validated() -> void:
	var raw: Dictionary = {}
	for category in ContentValidator.FILE_NAMES:
		raw[category] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + ContentValidator.FILE_NAMES[category]))
	raw["balance"]["time"]["band_starts_hour"]["day"] = 5.0  # before dawn
	var result := ContentValidator.validate(raw)
	assert_true("\n".join(result["errors"]).contains("bands must start in order"), "\n".join(result["errors"]))
	raw["balance"]["time"]["band_starts_hour"]["day"] = 9.0
	raw["balance"]["time"]["day_length_real_sec"] = 5.0
	result = ContentValidator.validate(raw)
	assert_true("\n".join(result["errors"]).contains("day_length_real_sec"), "\n".join(result["errors"]))
