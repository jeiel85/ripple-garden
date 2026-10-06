class_name DiagnosticsExporter
extends RefCounted

## "Export diagnostic info" (TECH_SPEC §17, UI_UX §9). Writes a plain-text report the player can
## send to support by hand. Nothing is ever uploaded and nothing personal is included: no save
## contents, no account data (there are none), only versions, device class, settings and counts.

const REPORT_PATH := "user://diagnostics.txt"

## The report text for the current session.
static func build_report() -> String:
	var lines: Array[String] = []
	lines.append("Ripple Garden diagnostics")
	lines.append("version: %s" % ProjectSettings.get_setting("application/config/version", "?"))
	lines.append("profile: %s" % BuildProfile.profile())
	lines.append("godot: %s" % Engine.get_version_info()["string"])
	lines.append("os: %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("locale: %s" % TranslationServer.get_locale())
	lines.append("renderer: %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))
	lines.append("window: %s" % str(DisplayServer.window_get_size()))
	lines.append("fps cap: %d" % Engine.max_fps)
	lines.append("content errors: %d" % ContentDB.errors.size())
	for error_line in ContentDB.errors:
		lines.append("  - %s" % error_line)
	lines.append("save: version %d, revision %d" % [SaveSchema.CURRENT_VERSION, GameState.revision])
	lines.append("last save error: %s" % (SaveService.last_error if not SaveService.last_error.is_empty() else "none"))
	lines.append("save writes blocked: %s" % SaveService.write_blocked)
	lines.append("settings:")
	var settings: Dictionary = GameState.snapshot().get("settings", {})
	var keys: Array = settings.keys()
	keys.sort()
	for key in keys:
		lines.append("  %s = %s" % [key, str(settings[key])])
	return "\n".join(lines) + "\n"

## Writes the report; returns the absolute file path, or "" when it could not be written.
static func export_to_file(path: String = REPORT_PATH) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(build_report())
	file.close()
	return ProjectSettings.globalize_path(path)
