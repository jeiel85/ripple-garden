extends TestCase

## Every string the interface shows must exist in the localization CSV in Korean, English and Japanese
## (UI_UX §12, DATA_SCHEMA §7). Literal `tr("key")` calls are found by scanning the source;
## keys built at runtime (`"ui.time." + band`, settings, habitats...) are checked by expanding
## the data that feeds them.

const CSV_PATH := "res://data/localization.csv"
const SOURCE_DIRS: PackedStringArray = ["res://ui", "res://world", "res://fishing"]

func _read_csv() -> Dictionary:
	var rows: Dictionary = {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= header.size() and not line[0].is_empty():
			var row: Dictionary = {}
			for i in header.size():
				row[header[i]] = line[i]
			rows[line[0]] = row
	return rows

func _require(rows: Dictionary, key: String, where: String) -> void:
	if not rows.has(key):
		fail("%s: localization key '%s' is missing" % [where, key])
		return
	for locale in ["ko", "en", "ja"]:
		if str(rows[key].get(locale, "")).strip_edges().is_empty():
			fail("%s: '%s' has no %s text" % [where, key, locale])

func _source_files() -> PackedStringArray:
	var files := PackedStringArray()
	for dir_path in SOURCE_DIRS:
		for file_name in DirAccess.get_files_at(dir_path):
			if file_name.ends_with(".gd"):
				files.append(dir_path.path_join(file_name))
	return files

func test_every_literal_translation_key_in_the_source_exists() -> void:
	var rows := _read_csv()
	var literal := RegEx.create_from_string("\\btr\\(\"([A-Za-z0-9_.]+)\"\\)")
	var checked := 0
	for path in _source_files():
		var text := FileAccess.get_file_as_string(path)
		for match_result in literal.search_all(text):
			_require(rows, match_result.get_string(1), path.get_file())
			checked += 1
	assert_true(checked > 40, "expected many tr() calls, found %d" % checked)

func test_keys_built_at_runtime_exist_for_every_value() -> void:
	var rows := _read_csv()
	for band in TimeService.TIME_BANDS:
		_require(rows, "ui.time." + band, "time band")
	for weather_id in ContentDB.weather:
		_require(rows, ContentDB.weather[weather_id]["name_key"], "weather " + weather_id)
	for region_def in ContentDB.regions.values():
		for habitat in region_def["habitats"]:
			_require(rows, "ui.habitat." + habitat, region_def["id"])
	for behavior_id in ContentDB.behaviors:
		_require(rows, "ui.behavior." + behavior_id, "behavior")
	for kind in PropKinds.PROPS:
		_require(rows, "ui.prop." + kind, "prop")
	for kind in PropKinds.ANIMALS:
		_require(rows, "ui.animal." + kind, "animal")
	for quality in SaveSchema.QUALITY_OPTIONS:
		_require(rows, "ui.quality." + quality, "quality")
	for key in SaveSchema.SETTING_SPECS:
		if not key in SettingsPanel.HIDDEN_KEYS:
			_require(rows, "ui.setting." + key, "setting")
	for section in SettingsPanel.SECTIONS:
		_require(rows, section["title"], "settings section")
	for key in Hud.CTA_BY_STATE.values().map(func(entry: Array) -> String: return entry[0]):
		_require(rows, key, "fishing button")
	for key in WaterMindOverlay.MIXER_KEYS:
		_require(rows, "ui.setting." + key, "mixer")

func test_every_cta_state_is_a_fishing_state() -> void:
	var states: Array = FishingController.State.keys().map(func(state_name: String) -> String: return state_name.to_lower())
	for state_name in states:
		assert_true(Hud.CTA_BY_STATE.has(state_name), "the fishing button has no entry for %s" % state_name)
	for state_name in Hud.CTA_BY_STATE:
		assert_true(state_name in states, "%s is not a fishing state" % state_name)

func test_format_strings_take_the_expected_arguments() -> void:
	var rows := _read_csv()
	var expectations := {
		"ui.status.line": 3, "ui.toast.released": 1, "ui.toast.ripple": 1, "ui.toast.memory": 1,
		"ui.inspect.size": 1, "ui.inspect.encounters": 1, "ui.journal.progress": 2, "ui.journal.size_range": 2,
		"ui.journal.met": 1, "ui.journal.time": 1, "ui.journal.habitat": 1, "ui.journal.behavior": 1,
		"ui.journal.next_unlock": 1, "ui.gear.rod_stats": 2, "ui.gear.item_equipped": 1, "ui.restore.level": 2,
		"ui.restore.points": 2, "ui.restore.points_total": 1, "ui.restore.next_brings": 1,
		"ui.support.diagnostics_saved": 1,
	}
	for key in expectations:
		for locale in ["ko", "en", "ja"]:
			var text: String = rows[key][locale]
			var placeholders := RegEx.create_from_string("%[-+0-9.]*[sdf]").search_all(text).size()
			assert_eq(placeholders, int(expectations[key]), "%s (%s) has %d placeholders" % [key, locale, placeholders])
