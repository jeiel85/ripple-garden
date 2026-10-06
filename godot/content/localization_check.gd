class_name LocalizationCheck
extends RefCounted

## "Localization key presence" of DATA_SCHEMA §7: every name/description key that content points at
## must exist in data/localization.csv with Korean and English text (Japanese follows in P1-013).
## Shared by the content-validation command (tools/validate_content.gd) and the unit tests, so the
## rule has one implementation.

const CSV_PATH := "res://data/localization.csv"
const REQUIRED_LOCALES: PackedStringArray = ["ko", "en"]

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
	for category in ["regions", "rods", "baits", "weather"]:
		for definition in content[category].values():
			refs.append([definition["id"], definition["name_key"]])
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
