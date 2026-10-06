extends TestCase

## P0-025: QA commands (AI_AGENT_GUIDE §9) and the rule that a release build can never use them.

const REGION := "region_01_quiet_pond"
const ROOT := "user://test_saves/debug"

func _setup(enabled: bool) -> Array:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	var fishing := FishingController.new()
	fishing.game_state = state
	var weather := WeatherService.new()
	weather.rng.seed = 1
	weather.start(REGION)
	var time: Node = load("res://autoload/time_service.gd").new()
	time.state = state
	var save: Node = load("res://autoload/save_service.gd").new()
	save.base_dir = ROOT + "/"
	save.state = state
	DirAccess.make_dir_recursive_absolute(ROOT)
	var restoration := RestorationService.new(state, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	var service := DebugService.new(fishing, weather, time, state, save, restoration)
	service.enabled = enabled
	return [service, fishing, weather, time, state, save]

func _cleanup(parts: Array) -> void:
	for i in range(1, parts.size()):
		parts[i].free()
	var dir := DirAccess.open(ROOT)
	if dir != null:
		for file_name in dir.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT.path_join(file_name)))

func test_build_profile_matches_the_running_engine() -> void:
	var profile := BuildProfile.profile()
	assert_true(profile in ["debug", "qa", "release"])
	assert_eq(BuildProfile.debug_tools_enabled(), profile != "release")
	if OS.is_debug_build():
		assert_true(BuildProfile.debug_tools_enabled(), "debug builds must have the tools")
	assert_eq(DebugService.new(null, null, null, null, null, null).enabled, BuildProfile.debug_tools_enabled())

func test_every_command_is_refused_when_disabled() -> void:
	var parts := _setup(false)
	var service: DebugService = parts[0]
	var state: Node = parts[4]
	assert_false(service.set_time_band("night"))
	assert_false(service.set_hour(3.0))
	assert_false(service.set_weather("rain"))
	assert_false(service.spawn_fish("fish_minnow"))
	assert_false(service.set_restoration(REGION, 3))
	assert_false(service.grant_currency(500, 500))
	assert_eq(service.simulate_offline(3600), 0)
	assert_false(service.corrupt_save_copy())
	assert_eq(service.reload_save(), "")
	assert_eq(state.get_ripple(), 0, "a refused command must not change the game")
	assert_eq(state.get_restoration_level(REGION), 0)
	assert_eq(parts[2].current_id, "clear")
	_cleanup(parts)

func test_time_commands_set_the_game_clock() -> void:
	var parts := _setup(true)
	var service: DebugService = parts[0]
	var time: Node = parts[3]
	for band in DebugService.BAND_HOURS:
		assert_true(service.set_time_band(band))
		assert_eq(time.get_time_band(), band, "jumping to %s must land in that band" % band)
	assert_false(service.set_time_band("midnight_snack"))
	assert_true(service.set_hour(13.5))
	assert_eq(time.game_minutes, 810.0)
	_cleanup(parts)

func test_weather_and_spawn_commands() -> void:
	var parts := _setup(true)
	var service: DebugService = parts[0]
	assert_true(service.set_weather("rain"))
	assert_eq(parts[2].current_id, "rain")
	assert_false(service.set_weather("snow"))
	assert_true(service.spawn_fish("fish_bluegill"))
	assert_false(service.spawn_fish("fish_nonexistent"))
	_cleanup(parts)

func test_restoration_command_grants_points_and_respects_the_cap() -> void:
	var parts := _setup(true)
	var service: DebugService = parts[0]
	var state: Node = parts[4]
	assert_true(service.set_restoration(REGION, 3))
	assert_eq(state.get_restoration_level(REGION), 3)
	assert_true(state.get_restoration_points(REGION) >= int(ContentDB.progression["restoration_points"][3]),
		"the save must stay consistent: points justify the level")
	assert_true(service.set_restoration(REGION, 99))
	assert_eq(state.get_restoration_level(REGION), int(ContentDB.balance["vertical_slice"]["max_restoration_level"]))
	assert_true(service.set_restoration(REGION, 1))
	assert_eq(state.get_restoration_level(REGION), 1, "levels can be lowered for testing")
	_cleanup(parts)

func test_currency_command_rejects_negative_amounts() -> void:
	var parts := _setup(true)
	var service: DebugService = parts[0]
	assert_true(service.grant_currency(250, 10))
	assert_eq(parts[4].get_ripple(), 250)
	assert_eq(parts[4].get_memory(), 10)
	assert_false(service.grant_currency(-1, 0))
	assert_eq(parts[4].get_ripple(), 250)
	_cleanup(parts)

func test_offline_command_advances_the_clock_and_clamps() -> void:
	var parts := _setup(true)
	var service: DebugService = parts[0]
	var time: Node = parts[3]
	time.game_minutes = 0.0
	var elapsed: Array = []
	var handler := func(seconds: int) -> void: elapsed.append(seconds)
	EventBus.offline_time_elapsed.connect(handler)
	assert_eq(service.simulate_offline(600), 600)
	assert_eq(service.simulate_offline(100 * 3600), TimeService.OFFLINE_CAP_SEC, "an absence is clamped like a real one")
	assert_eq(service.simulate_offline(-50), 0)
	EventBus.offline_time_elapsed.disconnect(handler)
	assert_deep_eq(elapsed, [600, TimeService.OFFLINE_CAP_SEC])
	_cleanup(parts)

func test_corrupt_save_copy_keeps_a_copy_and_recovery_works() -> void:
	var parts := _setup(true)
	var service: DebugService = parts[0]
	var state: Node = parts[4]
	var save: Node = parts[5]
	assert_false(service.corrupt_save_copy(), "nothing to corrupt before the first save")
	state.add_ripple(10)
	save.save_game()
	state.add_ripple(10)
	save.save_game()
	assert_true(service.corrupt_save_copy())
	assert_true(FileAccess.file_exists(ROOT + "/save_qa_backup.json"), "the QA copy of the real save must be kept")
	var json := JSON.new()
	assert_true(json.parse(FileAccess.get_file_as_string(ROOT + "/save.json")) != OK, "the primary must be damaged")
	assert_eq(service.reload_save(), "backup_1", "recovery must come from the rotating backup")
	assert_eq(state.get_ripple(), 10)
	_cleanup(parts)

func test_diagnostics_report_has_versions_and_no_save_contents() -> void:
	GameState.new_game()
	var report := DiagnosticsExporter.build_report()
	assert_true(report.contains("version:"))
	assert_true(report.contains("profile:"))
	assert_true(report.contains("godot:"))
	GameState.set_pending_catch({"fish_id": "fish_secret_marker", "size_cm": 1.0, "region_id": REGION})
	GameState.record_encounter("fish_secret_marker2", 1.0)
	assert_false(DiagnosticsExporter.build_report().contains("fish_secret_marker"), "the report must not include save contents")
	var path := DiagnosticsExporter.export_to_file("user://test_saves/diagnostics_test.txt")
	assert_false(path.is_empty())
	assert_true(FileAccess.file_exists("user://test_saves/diagnostics_test.txt"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves/diagnostics_test.txt"))
	GameState.new_game()
