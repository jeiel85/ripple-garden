extends TestCase

## DATA_SCHEMA §7: every localization key referenced by content must exist in
## res://data/localization.csv with Korean and English text. Japanese is
## tracked separately by P1-013 (KO/EN/JA localization).

const CSV_PATH := "res://data/localization.csv"
const REQUIRED_LOCALES: PackedStringArray = ["ko", "en"]

func _read_csv() -> Dictionary:
	var rows: Dictionary = {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		fail("cannot open %s" % CSV_PATH)
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < header.size() or line[0].is_empty():
			continue
		var row: Dictionary = {}
		for i in header.size():
			row[header[i]] = line[i]
		rows[line[0]] = row
	return rows

func test_content_localization_keys_exist() -> void:
	var rows := _read_csv()
	var content_db := tree.root.get_node("ContentDB")
	var references: Array = []
	for fish_def in content_db.fish.values():
		references.append([fish_def["id"], fish_def["name_key"]])
		references.append([fish_def["id"], fish_def["journal_key"]])
	for collection in [content_db.regions, content_db.rods, content_db.baits]:
		for definition in collection.values():
			references.append([definition["id"], definition["name_key"]])
	assert_true(references.size() > 0, "no content loaded")

	for reference in references:
		var key: String = reference[1]
		if not rows.has(key):
			fail("%s: localization key '%s' missing from %s" % [reference[0], key, CSV_PATH])
			continue
		for locale in REQUIRED_LOCALES:
			if str(rows[key].get(locale, "")).strip_edges().is_empty():
				fail("%s: '%s' has no %s text" % [reference[0], key, locale])
