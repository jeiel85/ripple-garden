extends Node

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const BACKUP_1 := "user://save_backup_1.json"
const BACKUP_2 := "user://save_backup_2.json"
const CURRENT_VERSION := 1

func save_game() -> bool:
    GameState.ensure_initialized()
    GameState.data["save_version"] = CURRENT_VERSION
    GameState.data["profile"]["last_session_at"] = int(Time.get_unix_time_from_system())
    var text := JSON.stringify(GameState.data)
    var tmp := FileAccess.open(TMP_PATH, FileAccess.WRITE)
    if tmp == null:
        EventBus.save_failed.emit("Unable to open temporary save.")
        return false
    tmp.store_string(text)
    tmp.close()

    if FileAccess.file_exists(BACKUP_1):
        _copy_file(BACKUP_1, BACKUP_2)
    if FileAccess.file_exists(SAVE_PATH):
        _copy_file(SAVE_PATH, BACKUP_1)
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    var err := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(TMP_PATH),
        ProjectSettings.globalize_path(SAVE_PATH)
    )
    if err != OK:
        EventBus.save_failed.emit("Unable to finalize save.")
        return false
    EventBus.save_completed.emit()
    return true

func load_game() -> bool:
    for path in [SAVE_PATH, BACKUP_1, BACKUP_2]:
        var loaded := _load_candidate(path)
        if not loaded.is_empty():
            GameState.data = _migrate(loaded)
            return true
    GameState.new_game()
    return false

func _load_candidate(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    if not parsed.has("save_version"):
        return {}
    return parsed

func _migrate(input: Dictionary) -> Dictionary:
    var result := input.duplicate(true)
    var version := int(result.get("save_version", 1))
    while version < CURRENT_VERSION:
        # Add explicit vN -> vN+1 migration functions here.
        version += 1
        result["save_version"] = version
    return result

func _copy_file(from_path: String, to_path: String) -> void:
    var src := FileAccess.open(from_path, FileAccess.READ)
    if src == null:
        return
    var bytes := src.get_buffer(src.get_length())
    src.close()
    var dst := FileAccess.open(to_path, FileAccess.WRITE)
    if dst == null:
        return
    dst.store_buffer(bytes)
    dst.close()
