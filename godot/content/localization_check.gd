class_name LocalizationCheck
extends RefCounted

## "Localization key presence" of DATA_SCHEMA §7: every name/description key that content points at
## must exist in data/localization.csv, and every row needs Korean, English and Japanese text (P1-013)
## whose format placeholders (%s, %d, %.1f…) match the Korean in kind, count and order — Godot fills them
## by position, so a translation that reorders them would put the wrong value in the wrong place.
## Shared by the content-validation command (tools/validate_content.gd) and the unit tests, so the
## rule has one implementation.

const CSV_PATH := "res://data/localization.csv"
const REQUIRED_LOCALES: PackedStringArray = ["ko", "en", "ja"]
## The languages a player can pick (settings "language"); "auto" follows the device.
const LANGUAGES: PackedStringArray = ["ko", "en", "ja"]
const FALLBACK := "en"

## The locale to use for a language setting and the device language ("auto" follows the device, and a
## device language the game is not translated into falls back to English).
static func locale_for(setting: String, device_language: String) -> String:
	if setting in LANGUAGES:
		return setting
	return device_language if device_language in LANGUAGES else FALLBACK

## printf placeholders of `text` in order ("%s", "%d", "%.1f", "%02d"); "%%" is a literal percent sign.
static func placeholders(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	var pattern := RegEx.create_from_string("%(%|[-+ 0]?\\d*(?:\\.\\d+)?[sdfxXc])")
	for result in pattern.search_all(text):
		if result.get_string() != "%%":
			found.append(result.get_string())
	return found

## Every row: all required languages present, and their placeholders the same as the Korean's.
static func row_problems(rows: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for key in rows:
		var row: Dictionary = rows[key]
		var source := placeholders(str(row.get("ko", "")))
		for locale in REQUIRED_LOCALES:
			var text := str(row.get(locale, ""))
			if text.strip_edges().is_empty():
				found.append("%s: '%s' has no %s text" % [CSV_PATH, key, locale])
			elif locale != "ko" and placeholders(text) != source:
				found.append("%s: '%s' %s placeholders %s do not match ko %s" % [CSV_PATH, key, locale, placeholders(text), source])
	return found

## {key: {"ko": text, "en": text, "ja": text}} for every row with a key. Empty when unreadable.
static func read_csv(path: String = CSV_PATH) -> Dictionary:
	var rows := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < header.size() or line[0].is_empty():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i]
		rows[line[0]] = row
	return rows

## Every (owner, key) pair the content refers to.
static func references(content: Dictionary) -> Array:
	var refs: Array = []
	for fish_def in content["fish"].values():
		refs.append([fish_def["id"], fish_def["name_key"]])
		refs.append([fish_def["id"], fish_def["journal_key"]])
	for category in ["regions", "rods", "baits", "weather", "bags", "accessories", "decorations"]:
		for definition in content.get(category, {}).values():
			refs.append([definition["id"], definition["name_key"]])
			if definition.has("desc_key"):
				refs.append([definition["id"], definition["desc_key"]])
	for moment in content.get("moments", {}).values():
		for key in ["name_key", "desc_key", "hint_key"]:
			refs.append([moment["id"], moment[key]])
	return refs

## Problems found: a missing key, or a required locale without text. Empty means all good.
static func problems(rows: Dictionary, refs: Array) -> PackedStringArray:
	var found := PackedStringArray()
	if rows.is_empty():
		found.append("%s: cannot be read or has no rows" % CSV_PATH)
		return found
	for reference in refs:
		var key: String = reference[1]
		if not rows.has(key):
			found.append("%s: localization key '%s' is missing from %s" % [reference[0], key, CSV_PATH])
			continue
		for locale in REQUIRED_LOCALES:
			if str(rows[key].get(locale, "")).strip_edges().is_empty():
				found.append("%s: '%s' has no %s text" % [reference[0], key, locale])
	return found
