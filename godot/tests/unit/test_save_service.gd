extends TestCase

## P0-005 / P0-027: SaveService — atomic write, rotating backups, recovery and lifecycle.
## Every test uses its own scratch directory under user://test_saves and fresh GameState /
## SaveService instances, never the autoloads, so the player's real save is never touched.

const ROOT := "user://test_saves"

var _service: Node
var _state: Node
var _dir := ""

func _begin(test_name: String) -> void:
	_dir = ROOT.path_join(test_name) + "/"
	_wipe(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	_service = _new_service()
	_state = _service.state
	_state.new_game()

## A second, independent service+state pair on the same directory: stands for "the next run".
func _new_service() -> Node:
	var service: Node = load("res://autoload/save_service.gd").new()
	service.base_dir = _dir
	service.state = load("res://autoload/game_state.gd").new()
	return service

func _end() -> void:
	_service.state.free()
	_service.free()
	_wipe(_dir)

func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path.path_join(file_name)))

func _file(name: String) -> String:
	return _dir.path_join(name)

func _read(name: String) -> String:
	return FileAccess.get_file_as_string(_file(name))

func _write(name: String, text: String) -> void:
	var file := FileAccess.open(_file(name), FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _saved_ripple(name: String) -> int:
	return int(JSON.parse_string(_read(name))["economy"]["ripple"])

func _fill_state(state: Node) -> void:
	state.add_ripple(123)
	state.add_memory(7)
	state.record_encounter("fish_crucian_carp", 14.5, "steady")
	state.record_release("fish_crucian_carp")
	state.add_population("region_01_quiet_pond", "fish_crucian_carp", 2)
	state.add_restoration_points("region_01_quiet_pond", 30)
	state.set_restoration_level("region_01_quiet_pond", 1)
	state.set_setting("text_scale", 1.25)
	state.set_pending_catch({"fish_id": "fish_minnow", "size_cm": 11.0, "region_id": "region_01_quiet_pond"})

# --- round trip ---

func test_save_load_roundtrip_is_equal() -> void:
	_begin("roundtrip")
	_fill_state(_state)
	assert_true(_service.save_game(), _service.last_error)
	var next_run := _new_service()
	assert_eq(next_run.load_game(), "primary")
	assert_deep_eq(next_run.state.snapshot(), _state.snapshot(), "state changed across save/load")
	next_run.state.free()
	next_run.free()
	_end()

func test_save_is_human_readable_json_with_version() -> void:
	_begin("readable")
	_service.save_game()
	var parsed: Variant = JSON.parse_string(_read(SaveService.SAVE_FILE))
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	assert_eq(int(parsed["save_version"]), SaveSchema.CURRENT_VERSION)
	assert_false(FileAccess.file_exists(_file(SaveService.TMP_FILE)), "temporary file left behind")
	_end()

func test_save_completed_event_is_emitted() -> void:
	_begin("event")
	var completed: Array = []
	var handler := func() -> void: completed.append(true)
	EventBus.save_completed.connect(handler)
	_service.save_game()
	EventBus.save_completed.disconnect(handler)
	assert_eq(completed.size(), 1)
	_end()

# --- backups ---

func test_backups_rotate_over_three_generations() -> void:
	_begin("rotation")
	_state.add_ripple(1)
	assert_true(_service.save_game())
	assert_false(FileAccess.file_exists(_file(SaveService.BACKUP_1_FILE)), "first save has nothing to back up")
	_state.add_ripple(1)
	assert_true(_service.save_game())
	_state.add_ripple(1)
	assert_true(_service.save_game())
	_state.add_ripple(1)
	assert_true(_service.save_game())
	assert_eq(_saved_ripple(SaveService.SAVE_FILE), 4)
	assert_eq(_saved_ripple(SaveService.BACKUP_1_FILE), 3)
	assert_eq(_saved_ripple(SaveService.BACKUP_2_FILE), 2)
	_end()

func test_corrupt_primary_recovers_from_backup_1() -> void:
	_begin("recover_backup1")
	_state.add_ripple(10)
	_service.save_game()
	_state.add_ripple(10)
	_service.save_game()
	_write(SaveService.SAVE_FILE, "{ this is not json")

	var recovered: Array = []
	var handler := func(source: String) -> void: recovered.append(source)
	EventBus.save_recovered.connect(handler)
	var next_run := _new_service()
	var source: String = next_run.load_game()
	EventBus.save_recovered.disconnect(handler)

	assert_eq(source, "backup_1")
	assert_deep_eq(recovered, [SaveService.BACKUP_1_FILE])
	assert_eq(next_run.state.get_ripple(), 10, "must restore the previous generation")
	assert_true(FileAccess.file_exists(_file(SaveService.CORRUPT_FILE)), "damaged primary must be kept for diagnostics")
	# The primary was rewritten, so the following run loads it directly.
	var third_run := _new_service()
	assert_eq(third_run.load_game(), "primary")
	assert_eq(third_run.state.get_ripple(), 10)
	for node in [next_run.state, next_run, third_run.state, third_run]:
		node.free()
	_end()

func test_truncated_primary_and_backup_recover_from_backup_2() -> void:
	_begin("recover_backup2")
	for i in 3:
		_state.add_ripple(5)
		_service.save_game()
	var full := _read(SaveService.SAVE_FILE)
	_write(SaveService.SAVE_FILE, full.substr(0, full.length() / 2))
	_write(SaveService.BACKUP_1_FILE, "")
	var next_run := _new_service()
	assert_eq(next_run.load_game(), "backup_2")
	assert_eq(next_run.state.get_ripple(), 5)
	next_run.state.free()
	next_run.free()
	_end()

func test_corrupt_primary_does_not_rotate_over_good_backups() -> void:
	_begin("no_poison_rotation")
	for i in 3:
		_state.add_ripple(1)
		_service.save_game()
	var backup_1 := _read(SaveService.BACKUP_1_FILE)
	var backup_2 := _read(SaveService.BACKUP_2_FILE)
	_write(SaveService.SAVE_FILE, "garbage")
	_state.add_ripple(1)
	assert_true(_service.save_game())
	assert_eq(_read(SaveService.BACKUP_1_FILE), backup_1, "good backup 1 was overwritten by a bad primary")
	assert_eq(_read(SaveService.BACKUP_2_FILE), backup_2, "good backup 2 was overwritten")
	assert_eq(_read(SaveService.CORRUPT_FILE), "garbage")
	assert_eq(_saved_ripple(SaveService.SAVE_FILE), 4)
	_end()

func test_every_candidate_damaged_starts_a_new_game() -> void:
	_begin("all_damaged")
	for name in [SaveService.SAVE_FILE, SaveService.BACKUP_1_FILE, SaveService.BACKUP_2_FILE]:
		_write(name, "###")
	var next_run := _new_service()
	assert_eq(next_run.load_game(), "new_game")
	assert_eq(next_run.state.get_ripple(), 0)
	assert_false(next_run.write_blocked, "damaged saves are not a reason to refuse writing")
	next_run.state.free()
	next_run.free()
	_end()

func test_no_files_starts_a_new_game() -> void:
	_begin("fresh")
	var next_run := _new_service()
	assert_eq(next_run.load_game(), "new_game")
	assert_eq(SaveSchema.validate(next_run.state.data), PackedStringArray())
	next_run.state.free()
	next_run.free()
	_end()

# --- interrupted / failing writes ---

func test_interrupted_temporary_write_is_ignored_and_cleaned() -> void:
	_begin("interrupted")
	_state.add_ripple(9)
	_service.save_game()
	_write(SaveService.TMP_FILE, "{\"save_version\": 1, \"economy\": {\"rip")  # power cut mid-write
	var next_run := _new_service()
	assert_eq(next_run.load_game(), "primary")
	assert_eq(next_run.state.get_ripple(), 9)
	assert_false(FileAccess.file_exists(_file(SaveService.TMP_FILE)), "stale temporary file kept")
	next_run.state.free()
	next_run.free()
	_end()

func test_invalid_state_is_never_written() -> void:
	_begin("invalid_state")
	_state.add_ripple(3)
	_service.save_game()
	var before := _read(SaveService.SAVE_FILE)
	_state.data["economy"]["ripple"] = -50
	var failures: Array = []
	var handler := func(message: String) -> void: failures.append(message)
	EventBus.save_failed.connect(handler)
	assert_false(_service.save_game())
	EventBus.save_failed.disconnect(handler)
	assert_eq(failures.size(), 1)
	assert_true(failures[0].contains("invalid state"), failures[0])
	assert_eq(_read(SaveService.SAVE_FILE), before, "existing save damaged by a refused write")
	_end()

func test_unwritable_directory_fails_cleanly() -> void:
	_begin("unwritable")
	_write("blocker", "a file where a directory is expected")
	_service.base_dir = _file("blocker") + "/inside/"
	expect_engine_error("Could not create directory")
	var failures: Array = []
	var handler := func(message: String) -> void: failures.append(message)
	EventBus.save_failed.connect(handler)
	assert_false(_service.save_game())
	EventBus.save_failed.disconnect(handler)
	assert_eq(failures.size(), 1)
	assert_false(_service.last_error.is_empty())
	_end()

# --- versions ---

func test_newer_version_save_blocks_writing_and_is_left_untouched() -> void:
	_begin("newer_version")
	var future := SaveSchema.default_save(1_700_000_000)
	future["save_version"] = SaveSchema.CURRENT_VERSION + 1
	future["economy"]["ripple"] = 777
	_write(SaveService.SAVE_FILE, JSON.stringify(future))
	var before := _read(SaveService.SAVE_FILE)
	var next_run := _new_service()
	assert_eq(next_run.load_game(), "blocked")
	assert_true(next_run.write_blocked)
	assert_false(next_run.save_game(), "must not overwrite a newer save")
	assert_false(next_run.save_if_dirty())
	assert_eq(_read(SaveService.SAVE_FILE), before)
	assert_eq(next_run.state.get_ripple(), 0, "newer data must not be half-loaded")
	next_run.state.free()
	next_run.free()
	_end()

func test_save_missing_version_is_treated_as_damaged() -> void:
	_begin("no_version")
	_write(SaveService.SAVE_FILE, JSON.stringify({"economy": {"ripple": 5}}))
	var next_run := _new_service()
	assert_eq(next_run.load_game(), "new_game")
	next_run.state.free()
	next_run.free()
	_end()

func test_migration_backs_up_the_original_then_loads_migrated_state() -> void:
	_begin("migration")
	var old_save := SaveSchema.default_save(1_700_000_000)
	old_save["economy"]["ripple"] = 21
	_write(SaveService.SAVE_FILE, JSON.stringify(old_save))
	var upgrade := func(save: Dictionary) -> Dictionary:
		save["economy"]["ripple"] = int(save["economy"]["ripple"]) + 1000
		return save
	var next_run := _new_service()
	next_run.migrator_override = SaveMigrator.new(2, {1: upgrade})
	assert_eq(next_run.load_game(), "primary")
	assert_eq(next_run.state.get_ripple(), 1021)
	assert_true(FileAccess.file_exists(_file("save_pre_migration_v1.json")), "no backup before migrating")
	assert_eq(_saved_ripple("save_pre_migration_v1.json"), 21, "backup must hold the original data")
	assert_eq(int(JSON.parse_string(_read(SaveService.SAVE_FILE))["save_version"]), 2, "migrated save not written")
	next_run.state.free()
	next_run.free()
	_end()

# --- lifecycle ---

func test_pause_and_close_notifications_flush_unsaved_changes() -> void:
	_begin("lifecycle")
	_state.add_ripple(5)
	_service._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_saved_ripple(SaveService.SAVE_FILE), 5, "pause did not save")
	_state.add_ripple(5)
	_service._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_saved_ripple(SaveService.SAVE_FILE), 10, "close request did not save")
	_end()

func test_clean_state_is_not_rewritten() -> void:
	_begin("clean")
	_state.add_ripple(1)
	assert_true(_service.has_unsaved_changes())
	assert_true(_service.save_if_dirty())
	assert_false(_service.has_unsaved_changes())
	assert_false(_service.save_if_dirty(), "unchanged state was written again")
	assert_false(FileAccess.file_exists(_file(SaveService.BACKUP_1_FILE)), "needless rewrite rotated a backup")
	_end()

func test_about_to_save_lets_services_sync_state_first() -> void:
	_begin("about_to_save")
	var sync := func() -> void: _state.set_game_minutes(600.0)
	_service.about_to_save.connect(sync)
	_service.save_game()
	var parsed: Variant = JSON.parse_string(_read(SaveService.SAVE_FILE))
	assert_eq(parsed["profile"]["game_minutes"], 600.0)
	_end()

func test_clock_only_progress_still_gets_saved() -> void:
	_begin("clock_only")
	_service.save_game()
	var clock := {"minutes": 480.0}
	var sync := func() -> void: _state.set_game_minutes(clock["minutes"])
	_service.about_to_save.connect(sync)
	assert_false(_service.save_if_dirty(), "nothing changed yet")
	clock["minutes"] = 555.0  # the game clock advanced; no other state was touched
	assert_true(_service.save_if_dirty(), "a moved clock must count as a change")
	assert_eq(JSON.parse_string(_read(SaveService.SAVE_FILE))["profile"]["game_minutes"], 555.0)
	assert_false(_service.save_if_dirty(), "and be clean afterwards")
	_end()

func test_pause_saves_clock_progress_without_other_changes() -> void:
	_begin("pause_clock")
	_service.save_game()
	var sync := func() -> void: _state.set_game_minutes(900.0)
	_service.about_to_save.connect(sync)
	_service._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(JSON.parse_string(_read(SaveService.SAVE_FILE))["profile"]["game_minutes"], 900.0)
	_end()

func test_failed_finalize_leaves_every_previous_generation_intact() -> void:
	_begin("finalize_failure")
	for i in 3:
		_state.add_ripple(1)
		_service.save_game()
	var primary := _read(SaveService.SAVE_FILE)
	var backup_1 := _read(SaveService.BACKUP_1_FILE)
	var backup_2 := _read(SaveService.BACKUP_2_FILE)
	_service.finalize_override = func(_from: String, _to: String) -> Error: return ERR_FILE_NO_PERMISSION
	_state.add_ripple(1)
	var failures: Array = []
	var handler := func(message: String) -> void: failures.append(message)
	EventBus.save_failed.connect(handler)
	assert_false(_service.save_game())
	EventBus.save_failed.disconnect(handler)
	assert_eq(failures.size(), 1)
	assert_eq(_read(SaveService.SAVE_FILE), primary, "primary changed by a failed save")
	assert_eq(_read(SaveService.BACKUP_1_FILE), backup_1, "backup 1 lost by a failed save")
	assert_eq(_read(SaveService.BACKUP_2_FILE), backup_2, "backup 2 lost by a failed save")
	assert_false(FileAccess.file_exists(_file(SaveService.TMP_FILE)), "temporary file left behind")
	assert_true(_service.has_unsaved_changes(), "a failed save must leave the state dirty so it is retried")
	# Once the destination is writable again, saving works and rotates normally.
	_service.finalize_override = Callable()
	assert_true(_service.save_game())
	assert_eq(_saved_ripple(SaveService.SAVE_FILE), 4)
	_end()
