extends TestCase

## DATA_SCHEMA §7: every localization key referenced by content must exist in
## res://data/localization.csv with Korean and English text. Japanese is tracked separately by
## P1-013 (KO/EN/JA localization). The rule itself lives in LocalizationCheck, which the
## content-validation command (tools/validate_content.gd) uses too.

func _content() -> Dictionary:
	var content_db := tree.root.get_node("ContentDB")
	return {
		"fish": content_db.fish, "regions": content_db.regions, "rods": content_db.rods,
		"baits": content_db.baits, "weather": content_db.weather,
	}

func test_content_localization_keys_exist() -> void:
	var refs := LocalizationCheck.references(_content())
	assert_true(refs.size() > 100, "no content loaded (%d references)" % refs.size())
	var problems := LocalizationCheck.problems(LocalizationCheck.read_csv(), refs)
	assert_eq(problems, PackedStringArray(), "localization problems")

func test_missing_keys_and_missing_locales_are_reported() -> void:
	var rows := {
		"a.name": {"ko": "가", "en": "A", "ja": ""},
		"b.name": {"ko": "나", "en": "", "ja": ""},
	}
	var refs := [["owner_a", "a.name"], ["owner_b", "b.name"], ["owner_c", "c.name"]]
	var problems := LocalizationCheck.problems(rows, refs)
	assert_eq(problems.size(), 2, str(problems))
	assert_true("\n".join(problems).contains("'b.name' has no en text"))
	assert_true("\n".join(problems).contains("localization key 'c.name' is missing"))
	assert_eq(LocalizationCheck.problems({}, refs).size(), 1, "an unreadable CSV is one clear problem")

func test_japanese_is_not_required_yet() -> void:
	var rows := {"a.name": {"ko": "가", "en": "A", "ja": ""}}
	assert_eq(LocalizationCheck.problems(rows, [["owner", "a.name"]]), PackedStringArray())

func test_references_cover_every_content_category() -> void:
	var owners := {}
	for reference in LocalizationCheck.references(_content()):
		owners[reference[0].split("_")[0]] = true
	for prefix in ["fish", "region", "rod", "bait", "weather"]:
		assert_true(owners.has(prefix) or prefix == "weather", "no references from %s" % prefix)
	var weather_refs := LocalizationCheck.references(_content()).filter(func(r: Array) -> bool: return r[1].begins_with("weather."))
	assert_eq(weather_refs.size(), tree.root.get_node("ContentDB").weather.size())

func test_the_shipped_csv_parses_with_quoted_commas_and_all_locale_columns() -> void:
	var rows := LocalizationCheck.read_csv()
	assert_true(rows.size() > 300)
	assert_true(rows.has("ui.hint.reel"), "a row whose text contains a comma must parse")
	for locale in ["ko", "en", "ja"]:
		assert_true(rows["ui.hint.reel"].has(locale))
