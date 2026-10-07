extends TestCase

## The bundled fonts and the type and icon scales (D-031): every string can be drawn by its language's
## fonts (the fonts are subsets, tools/subset_fonts.py), and sizes come from the named scales only.

const CSV := "res://data/localization.csv"

## {"ko": [...], "en": [...], "ja": [...]}: every translated string of the game.
func _strings() -> Dictionary:
	var columns := {}
	var file := FileAccess.open(CSV, FileAccess.READ)
	var header := file.get_csv_line()
	for i in range(1, header.size()):
		columns[header[i]] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		for i in range(1, mini(row.size(), header.size())):
			(columns[header[i]] as Array).append(row[i])
	return columns

## The characters of `texts` that neither the face of `font` nor its fallback can draw.
func _missing(font: FontVariation, texts: Array) -> String:
	var missing := {}
	for text in texts:
		for ch in String(text):
			var code := ch.unicode_at(0)
			if code > 0x20 and not font.base_font.has_char(code) and not (font.fallbacks[0] as Font).has_char(code):
				missing[ch] = true
	return "".join(PackedStringArray(missing.keys()))

## Letters a language's own face must have (a symbol or another language's name may come from the fallback).
func _letters_missing(font: FontVariation, texts: Array, letter: RegEx) -> String:
	var missing := {}
	for text in texts:
		for found in letter.search_all(String(text)):
			var ch := found.get_string()
			if not font.base_font.has_char(ch.unicode_at(0)):
				missing[ch] = true
	return "".join(PackedStringArray(missing.keys()))

func test_every_string_can_be_drawn_by_its_languages_fonts() -> void:
	var strings := _strings()
	var letters := {"ko": RegEx.create_from_string("[가-힣A-Za-z0-9]"), "en": RegEx.create_from_string("[A-Za-z0-9]"),
		"ja": RegEx.create_from_string("[ぁ-んァ-ヶ]")}
	for locale in ["ko", "en", "ja"]:
		var fonts := UiTheme.fonts_for(locale)
		for role in ["body", "title"]:
			var gaps := _missing(fonts[role], strings[locale])
			assert_true(gaps.is_empty(), "%s %s fonts lack %s: run tools/subset_fonts.py" % [locale, role, gaps])
			var foreign := _letters_missing(fonts[role], strings[locale], letters[locale])
			assert_true(foreign.is_empty(), "%s %s face draws %s from the fallback" % [locale, role, foreign])

func test_japanese_starts_from_its_own_face_and_falls_back_to_the_other() -> void:
	var korean := UiTheme.fonts_for("ko")
	var japanese := UiTheme.fonts_for("ja")
	assert_true((korean["body"] as FontVariation).base_font.resource_path.ends_with("GowunDodum-Regular.woff2"))
	assert_true((korean["title"] as FontVariation).base_font.resource_path.ends_with("Jua-Regular.woff2"))
	assert_true((japanese["body"] as FontVariation).base_font.resource_path.ends_with("MPLUSRounded1c-Regular.woff2"))
	assert_eq((japanese["body"] as FontVariation).fallbacks[0], (korean["body"] as FontVariation).base_font)

func test_the_theme_uses_the_bundled_fonts_and_the_named_sizes() -> void:
	var theme := UiTheme.build(1.0, false, false)
	assert_true(theme.default_font is FontVariation)
	assert_true(theme.get_font("font", "SignLabel") != theme.default_font, "signs are lettered")
	assert_eq(theme.get_font_size("caption", UiTheme.SIZES_TYPE), 21)
	assert_eq(theme.get_font_size("font_size", "SmallLabel"), theme.get_font_size("small", UiTheme.SIZES_TYPE))
	assert_eq(UiTheme.build(1.4, false, false).get_font_size("caption", UiTheme.SIZES_TYPE), 29, "Text Scale grows every size")

func test_a_named_text_size_follows_the_theme() -> void:
	var host := Control.new()
	host.theme = UiTheme.build(1.0, false, false)
	tree.root.add_child(host)
	var caption := UiKit.label("x")
	UiKit.text_size(caption, "caption")
	host.add_child(caption)
	assert_eq(caption.get_theme_font_size("font_size"), 21)
	host.theme = UiTheme.build(1.4, false, false)
	assert_eq(caption.get_theme_font_size("font_size"), 29, "a rebuilt theme (Text Scale) resizes it")
	host.free()

func test_screens_take_text_and_icon_sizes_from_the_scales() -> void:
	var fixed_text := RegEx.create_from_string("font_size_override\\(\"font_size\", \\d")
	var fixed_icon := RegEx.create_from_string("\\b(icon|icon_button|centered_button)\\([^\\n]*, \\d+\\.0[,)]")
	for file in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string("res://ui/" + file)
		assert_true(fixed_text.search(source) == null, "%s sets a text size in pixels: use UiKit.text_size" % file)
		assert_true(fixed_icon.search(source) == null, "%s sizes an icon in pixels: use UiTheme.ICON_*" % file)
