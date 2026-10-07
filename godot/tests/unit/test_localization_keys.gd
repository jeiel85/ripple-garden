extends TestCase

## DATA_SCHEMA §7: every localization key referenced by content must exist in
## res://data/localization.csv, and every row has Korean, English and Japanese text with the same
## placeholders (P1-013). The rule itself lives in LocalizationCheck, which the content-validation
## command (tools/validate_content.gd) uses too.

func _content() -> Dictionary:
	var content_db := tree.root.get_node("ContentDB")
	return {
		"fish": content_db.fish, "regions": content_db.regions, "rods": content_db.rods,
		"baits": content_db.baits, "weather": content_db.weather,
		"bags": content_db.bags, "accessories": content_db.accessories, "decorations": content_db.decorations, "moments": content_db.moments,
	}

func test_content_localization_keys_exist() -> void:
	var refs := LocalizationCheck.references(_content())
	assert_true(refs.size() > 100, "no content loaded (%d references)" % refs.size())
	var problems := LocalizationCheck.problems(LocalizationCheck.read_csv(), refs)
	assert_eq(problems, PackedStringArray(), "localization problems")

func test_missing_keys_and_missing_locales_are_reported() -> void:
	var rows := {
		"a.name": {"ko": "가", "en": "A", "ja": "あ"},
		"b.name": {"ko": "나", "en": "", "ja": "い"},
	}
	var refs := [["owner_a", "a.name"], ["owner_b", "b.name"], ["owner_c", "c.name"]]
	var problems := LocalizationCheck.problems(rows, refs)
	assert_eq(problems.size(), 2, str(problems))
	assert_true("\n".join(problems).contains("'b.name' has no en text"))
	assert_true("\n".join(problems).contains("localization key 'c.name' is missing"))
	assert_eq(LocalizationCheck.problems({}, refs).size(), 1, "an unreadable CSV is one clear problem")

# P1-013 makes Japanese a required language (it replaces the earlier "not required yet" rule).
func test_japanese_is_required() -> void:
	var rows := {"a.name": {"ko": "가", "en": "A", "ja": ""}}
	assert_true("
".join(LocalizationCheck.problems(rows, [["owner", "a.name"]])).contains("'a.name' has no ja text"))

func test_every_shipped_row_has_three_languages_with_matching_placeholders() -> void:
	assert_eq(LocalizationCheck.row_problems(LocalizationCheck.read_csv()), PackedStringArray())

func test_placeholders_must_match_the_korean_in_order() -> void:
	assert_eq(LocalizationCheck.placeholders("%s 100%% %d개 %.1fcm %02d"), PackedStringArray(["%s", "%d", "%.1f", "%02d"]))
	var rows := {
		"swapped": {"ko": "%s에서 %d마리", "en": "%d in %s", "ja": "%sで%d匹"},
		"dropped": {"ko": "%s +%d", "en": "%s +%d", "ja": "%s"},
		"fine": {"ko": "%s +%d", "en": "%s +%d", "ja": "%s +%d"},
	}
	var problems := "
".join(LocalizationCheck.row_problems(rows))
	assert_true(problems.contains("'swapped' en placeholders"), problems)
	assert_true(problems.contains("'dropped' ja placeholders"), problems)
	assert_false(problems.contains("'fine'"), problems)

func test_a_row_with_missing_columns_is_reported_not_skipped() -> void:
	assert_eq(LocalizationCheck.malformed_lines(), PackedStringArray(), "the shipped CSV has no broken rows")
	var path := "user://test_broken_localization.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('key,ko,en,ja
"a.name","가","A","あ"
"b.name","나","B"
"","다","C","う"
"a.name","라","D","え"
')
	file.close()
	var problems := LocalizationCheck.malformed_lines(path)
	assert_eq(problems.size(), 3, str(problems))
	assert_true(problems[0].contains(":3:"), problems[0])
	assert_true(problems[1].contains(":4: the key is empty"), problems[1])
	assert_true(problems[2].contains(":5: key 'a.name' is already on line 2"), problems[2])
	DirAccess.remove_absolute(path)

func test_the_language_setting_picks_the_locale() -> void:
	assert_eq(LocalizationCheck.locale_for("ja", "ko"), "ja", "an explicit choice wins over the device")
	assert_eq(LocalizationCheck.locale_for("auto", "ja"), "ja")
	assert_eq(LocalizationCheck.locale_for("auto", "ko"), "ko")
	assert_eq(LocalizationCheck.locale_for("auto", "de"), "en", "an untranslated device language reads English")
	assert_eq(LocalizationCheck.locale_for("klingon", "ko"), "ko", "an unknown setting follows the device")

func test_choosing_japanese_in_settings_switches_the_game() -> void:
	var previous := TranslationServer.get_locale()
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	var was_blocked: bool = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load("res://world/game_root.tscn") as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	GameState.set_setting("language", "ja")
	assert_eq(TranslationServer.get_locale(), "ja")
	assert_eq(String(TranslationServer.translate("ui.cta.cast")), "釣り")
	GameState.set_setting("language", "ko")
	assert_eq(String(TranslationServer.translate("ui.cta.cast")).replace(KeepWordsTranslation.JOINER, ""), "낚시",
		"Korean (set word by word: its letters are joined)")
	# A real game whose save cannot be written keeps its scene (a reload would read the old save back).
	root.load_save = true
	GameState.set_setting("language", "en")
	assert_true(root.is_inside_tree(), "the scene is not reloaded when the language could not be saved")
	var told := String(TranslationServer.translate("ui.toast.language_unsaved"))
	assert_true(root.ui.toast._label.text == told or told in root.ui.toast._queue, "the player is told why some text stays")
	root.load_save = false
	root.free()
	save_service.write_blocked = was_blocked
	GameState.new_game()
	TranslationServer.set_locale(previous)

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

# --- Korean line breaks ---

func test_korean_words_are_joined_and_placeholders_kept() -> void:
	var joiner := KeepWordsTranslation.JOINER
	assert_eq(KeepWordsTranslation.keep_words("손을 떼"), "손" + joiner + "을 떼")
	assert_eq(KeepWordsTranslation.keep_words("%d마리, %s을"), "%d" + joiner + "마" + joiner + "리" + joiner + ", %s" + joiner + "을",
		"a placeholder stays whole; punctuation sticks to its word")
	assert_eq(KeepWordsTranslation.keep_words("Cast the line"), "Cast the line", "only words with Hangul are joined")
	var once := KeepWordsTranslation.keep_words("보세요.")
	assert_eq(KeepWordsTranslation.keep_words(once), once, "joining twice changes nothing")
	assert_eq(KeepWordsTranslation.keep_words("%d%%를") % [50], "50%를", "an escaped percent sign still formats")

func test_a_korean_line_breaks_only_between_words() -> void:
	var text := KeepWordsTranslation.keep_words("물 위를 끌어서 던질 곳을 정하고 손을 떼 보세요.")
	var paragraph := TextParagraph.new()
	paragraph.add_string(text, SystemFont.new(), 30, "ko")
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	for width in [300.0, 330.0, 360.0]:
		paragraph.width = width
		for line in paragraph.get_line_count():
			var end := paragraph.get_line_range(line).y
			assert_true(end >= text.length() or text[end - 1] == " ", "line %d at width %d ends inside a word" % [line, width])

func test_the_korean_translation_keeps_words_together_once_installed() -> void:
	KeepWordsTranslation.install()
	KeepWordsTranslation.install()  # twice is harmless
	var installed := TranslationServer.get_translation_object("ko")
	assert_true(installed.has_meta(KeepWordsTranslation.MARK))
	assert_true(installed.get_script() == null, "a script-backed Translation left registered crashes the engine on exit")
	assert_true(installed.get_message_list().size() > 100, "every Korean message was copied")
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	var shown := String(TranslationServer.translate("ui.cta.cast"))
	assert_true(KeepWordsTranslation.JOINER in shown)
	assert_eq(shown.replace(KeepWordsTranslation.JOINER, ""), "낚시")
	TranslationServer.set_locale(previous)
