extends Node

## Persistence of GameState (TECH_SPEC §4-5). One JSON file, a temporary write, two rotating
## backups, migration on load and recovery from a damaged primary.
##
## Save transaction:
##   snapshot -> validate -> write save.tmp -> flush/close -> re-read and validate the tmp
##   -> rotate backups (only from a primary that is itself valid) -> rename tmp over primary.
## A failure at any step leaves the existing primary and backups untouched.
##
## Load order: primary, backup 1, backup 2; the first candidate that parses, migrates and
## validates wins. A damaged primary is kept as save_corrupt.json for diagnostics.

signal about_to_save()

const SAVE_FILE := "save.json"
const TMP_FILE := "save.tmp"
const BACKUP_1_FILE := "save_backup_1.json"
const BACKUP_2_FILE := "save_backup_2.json"
const CORRUPT_FILE := "save_corrupt.json"
const AUTOSAVE_INTERVAL_SEC := 60.0

## Where the files live. Tests point this at a scratch directory.
var base_dir := "user://"
## State to persist; defaults to the GameState autoload, tests inject their own instance.
var state: Node = null
## Set when the only readable saves come from a newer build: writing would destroy them.
var write_blocked := false
var last_error := ""

## Content id aliases applied on load; empty means "use ContentDB.aliases". Tests inject their own.
var aliases_override: Dictionary = {}
## Tests replace the final tmp -> primary rename to simulate a locked destination:
## (from_path, to_path) -> Error.
var finalize_override := Callable()
## Tests inject a migrator with a synthetic version table; production uses SaveMigrator.production_migrations().
var migrator_override: SaveMigrator = null

var _last_saved_revision := -1

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_INTERVAL_SEC
	timer.autostart = true
	timer.timeout.connect(_on_autosave_timeout)
	add_child(timer)

func _notification(what: int) -> void:
	# Mobile suspend, desktop focus loss and window close all flush unsaved progress.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_if_dirty()

func _on_autosave_timeout() -> void:
	save_if_dirty()

func _state() -> Node:
	return state if state != null else GameState

func _path(file_name: String) -> String:
	return base_dir.path_join(file_name)

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func has_unsaved_changes() -> bool:
	return _state().revision != _last_saved_revision

## Saves when something changed since the last write. Services that keep state outside GameState
## (the game clock) are synced first, otherwise a clock that only moved forward would look clean.
func save_if_dirty() -> bool:
	if write_blocked or _state().data.is_empty():
		return false
	about_to_save.emit()
	if not has_unsaved_changes():
		return false
	return save_game()

# --- save ---

## Writes the current state. Returns false (and emits save_failed) when nothing was replaced.
func save_game() -> bool:
	if write_blocked:
		return _fail("Saving is disabled so a save from a newer game version is not overwritten.")
	var game_state := _state()
	game_state.ensure_initialized()
	about_to_save.emit()
	game_state.touch_session(_now())
	var snapshot: Dictionary = game_state.snapshot()
	var revision: int = game_state.revision

	var problems := SaveSchema.validate(snapshot)
	if not problems.is_empty():
		return _fail("Refusing to save an invalid state: %s" % "; ".join(problems))
	var text := JSON.stringify(snapshot, "\t")

	var dir_error := DirAccess.make_dir_recursive_absolute(base_dir)
	if dir_error != OK:
		return _fail("Cannot create the save directory (%s)." % error_string(dir_error))

	var tmp_path := _path(TMP_FILE)
	var write_error := _write_text(tmp_path, text)
	if write_error == OK and _file_size(tmp_path) != text.to_utf8_buffer().size():
		write_error = ERR_FILE_CANT_WRITE  # truncated write, e.g. the disk filled up
	if write_error != OK:
		_remove(tmp_path)
		return _fail("Cannot write the temporary save (%s)." % error_string(write_error))
	if _read_candidate(tmp_path).get("problem", "") != "":
		_remove(tmp_path)
		return _fail("The temporary save did not read back correctly.")

	# Remember the backups so a failure from here on leaves the previous generations intact.
	var previous_backups := _read_backups()
	var rotate_error := _rotate_backups()
	if rotate_error != OK:
		_restore_backups(previous_backups)
		_remove(tmp_path)
		return _fail("Cannot rotate backups (%s)." % error_string(rotate_error))
	var rename_error: Error
	if finalize_override.is_valid():
		rename_error = finalize_override.call(tmp_path, _path(SAVE_FILE))
	else:
		rename_error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(_path(SAVE_FILE)))
	if rename_error != OK:
		_restore_backups(previous_backups)
		_remove(tmp_path)
		return _fail("Cannot finalize the save (%s)." % error_string(rename_error))

	_last_saved_revision = revision
	last_error = ""
	EventBus.save_completed.emit()
	return true

## Contents of both backup files ({file name: bytes}); a missing file is simply absent.
func _read_backups() -> Dictionary:
	var backups := {}
	for file_name in [BACKUP_1_FILE, BACKUP_2_FILE]:
		if FileAccess.file_exists(_path(file_name)):
			backups[file_name] = FileAccess.get_file_as_bytes(_path(file_name))
	return backups

## Puts the backups back exactly as `_read_backups` found them (best effort).
func _restore_backups(backups: Dictionary) -> void:
	for file_name in [BACKUP_1_FILE, BACKUP_2_FILE]:
		if backups.has(file_name):
			var file := FileAccess.open(_path(file_name), FileAccess.WRITE)
			if file != null:
				file.store_buffer(backups[file_name])
				file.close()
		else:
			_remove(_path(file_name))

## Moves primary -> backup 1 -> backup 2. A primary that does not validate is quarantined
## instead, so one bad save can never push the last good copies out of the rotation.
func _rotate_backups() -> Error:
	var primary := _path(SAVE_FILE)
	if not FileAccess.file_exists(primary):
		return OK
	if _read_candidate(primary).get("problem", "") != "":
		return DirAccess.copy_absolute(primary, _path(CORRUPT_FILE))
	if FileAccess.file_exists(_path(BACKUP_1_FILE)):
		var error := DirAccess.copy_absolute(_path(BACKUP_1_FILE), _path(BACKUP_2_FILE))
		if error != OK:
			return error
	return DirAccess.copy_absolute(primary, _path(BACKUP_1_FILE))

# --- load ---

## Loads the best available save into GameState and returns where it came from:
## "primary", "backup_1", "backup_2", "new_game" (nothing usable) or "blocked" (only newer-version
## saves exist, so a fresh game is started in memory and saving is disabled).
func load_game() -> String:
	write_blocked = false
	last_error = ""
	_remove(_path(TMP_FILE))  # leftover of an interrupted save; never a candidate
	var game_state := _state()
	var migrator := migrator_override
	if migrator == null:
		migrator = SaveMigrator.new(SaveSchema.CURRENT_VERSION, SaveMigrator.production_migrations(), _aliases())
	var saw_newer := false
	var damaged_primary := false

	for candidate in [["primary", SAVE_FILE], ["backup_1", BACKUP_1_FILE], ["backup_2", BACKUP_2_FILE]]:
		var source: String = candidate[0]
		var path := _path(candidate[1])
		if not FileAccess.file_exists(path):
			continue
		var read := _read_candidate(path)
		if read.get("problem", "") != "":
			push_warning("Save %s unusable: %s" % [candidate[1], read["problem"]])
			damaged_primary = damaged_primary or source == "primary"
			continue
		var result := migrator.migrate(read["data"], _now())
		if not result["ok"]:
			push_warning("Save %s cannot be loaded: %s" % [candidate[1], result["error"]])
			saw_newer = saw_newer or result["newer"]
			damaged_primary = damaged_primary or source == "primary"
			continue

		var migrated: bool = result["from_version"] < migrator.current_version
		if migrated:
			_backup_before_migration(path, result["from_version"])
		game_state.load_data(result["save"])
		if source != "primary":
			if damaged_primary:
				DirAccess.copy_absolute(_path(SAVE_FILE), _path(CORRUPT_FILE))
			EventBus.save_recovered.emit(candidate[1])
		# Re-establish a good primary right away after recovery or migration.
		if source != "primary" or migrated:
			save_game()
		else:
			_last_saved_revision = game_state.revision
		return source

	if saw_newer:
		write_blocked = true
		last_error = "Only saves from a newer game version were found."
		game_state.new_game()
		return "blocked"
	game_state.new_game()
	_last_saved_revision = -1
	return "new_game"

func _backup_before_migration(path: String, from_version: int) -> void:
	var target := _path("save_pre_migration_v%d.json" % from_version)
	if not FileAccess.file_exists(target):
		DirAccess.copy_absolute(path, target)

func _aliases() -> Dictionary:
	return aliases_override if not aliases_override.is_empty() else ContentDB.aliases

## QA hook: keeps a copy of the primary save as save_qa_backup.json, then truncates the primary to
## simulate corruption so recovery from the backups can be exercised. Returns whether it did.
func qa_corrupt_primary() -> bool:
	if not BuildProfile.debug_tools_enabled():
		return false  # defence in depth: DebugService already refuses, but this must never run in release
	var primary := _path(SAVE_FILE)
	if not FileAccess.file_exists(primary):
		return false
	if DirAccess.copy_absolute(primary, _path("save_qa_backup.json")) != OK:
		return false
	var text := FileAccess.get_file_as_string(primary)
	return _write_text(primary, text.substr(0, text.length() / 2)) == OK

## Reads and parses a save file. Returns {"data": Variant} or {"problem": String}.
func _read_candidate(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"problem": "cannot open (%s)" % error_string(FileAccess.get_open_error())}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"problem": "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"problem": "top level is not an object"}
	if not json.data.has("save_version"):
		return {"problem": "missing save_version"}
	return {"data": json.data}

# --- file helpers ---

func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> bool:
	last_error = message
	push_warning("SaveService: %s" % message)
	EventBus.save_failed.emit(message)
	return false
