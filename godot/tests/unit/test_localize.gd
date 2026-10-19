extends TestCase

## Korean particles (BACKLOG "한국어 조사 자동 선택"): the shipped strings write the choice
## ("을(를)") and Loc fills it from the word before it. The keys under test are derived from the
## shipped CSV, so a new choosing string is covered the moment it is added.

func _shown(text: String) -> String:
	return text.replace(KeepWordsTranslation.JOINER, "")

# --- the choice itself (locale-independent) ---

func test_a_final_consonant_takes_the_consonant_form() -> void:
	assert_eq(KoreanParticles.resolve("떡밥을(를) 챙겼어요"), "떡밥을 챙겼어요")
	assert_eq(KoreanParticles.resolve("연못이(가) 물었어요"), "연못이 물었어요")
	assert_eq(KoreanParticles.resolve("연못은(는) 조용해요"), "연못은 조용해요")
	assert_eq(KoreanParticles.resolve("떡밥과(와) 미끼"), "떡밥과 미끼")

func test_a_vowel_ending_takes_the_vowel_form() -> void:
	assert_eq(KoreanParticles.resolve("미끼을(를) 다 썼어요"), "미끼를 다 썼어요")
	assert_eq(KoreanParticles.resolve("물고기이(가) 헤엄쳐요"), "물고기가 헤엄쳐요")
	assert_eq(KoreanParticles.resolve("물가은(는) 잠잔해요"), "물가는 잠잔해요")
	assert_eq(KoreanParticles.resolve("물고기과(와) 떡밥"), "물고기와 떡밥")

func test_ero_follows_the_final_consonant_but_a_lier_takes_ro() -> void:
	assert_eq(KoreanParticles.resolve("떡밥(으)로 바꿨어요"), "떡밥으로 바꿨어요")
	assert_eq(KoreanParticles.resolve("미끼(으)로 바꿨어요"), "미끼로 바꿨어요")
	assert_eq(KoreanParticles.resolve("달(으)로 갔어요"), "달로 갔어요", "a ㄹ final takes 로")
	assert_eq(KoreanParticles.resolve("서울(으)로 갔어요"), "서울로 갔어요")

func test_numbers_and_latin_read_with_a_final_consonant() -> void:
	assert_eq(KoreanParticles.resolve("3을(를) 골랐어요"), "3을 골랐어요")
	assert_eq(KoreanParticles.resolve("12이(가) 보여요"), "12이 보여요")
	assert_eq(KoreanParticles.resolve("A을(를) 골랐어요"), "A을 골랐어요")
	assert_eq(KoreanParticles.resolve("A(으)로 갔어요"), "A으로 갔어요")

func test_a_marker_at_the_start_of_a_line_has_nothing_to_read() -> void:
	assert_eq(KoreanParticles.resolve("을(를) 골랐어요"), "을 골랐어요")

func test_several_choices_in_one_string_resolve_from_their_own_words() -> void:
	assert_eq(KoreanParticles.resolve("떡밥을(를) 다 써서 지렁이(으)로 바꿨어요"), "떡밥을 다 써서 지렁이로 바꿨어요")

func test_strings_without_a_choice_are_returned_unchanged() -> void:
	assert_eq(KoreanParticles.resolve("낚시대를 드리우고"), "낚시대를 드리우고")
	assert_eq(KoreanParticles.resolve("Got %s"), "Got %s")
	assert_eq(KoreanParticles.resolve("%sをプレゼントされました"), "%sをプレゼントされました")

func test_the_word_joiners_between_the_markers_letters_are_stripped() -> void:
	var joiner := KeepWordsTranslation.JOINER
	assert_eq(KoreanParticles.resolve("물고기" + joiner + "을" + joiner + "(" + joiner + "를" + joiner + ")"), "물고기를")

# --- the shipped strings, through Loc ---

func test_a_shipped_choosing_string_reads_naturally() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	assert_eq(_shown(Loc.t("ui.toast.bought", "떡밥")), "떡밥을 챙겼어요")
	assert_eq(_shown(Loc.t("ui.toast.bought", "미끼")), "미끼를 챙겼어요")
	assert_eq(_shown(Loc.t("ui.away.fish", ["붕어", 3])), "붕어가 3마리 늘었어요")
	assert_eq(_shown(Loc.t("ui.toast.bait_out", ["떡밥", "지렁이"])), "떡밥을 다 써서 지렁이로 바꿨어요")
	assert_eq(_shown(Loc.t("ui.map.travelling", "바닷가")), "바닷가로 가는 중이에요…")
	assert_eq(_shown(Loc.t("ui.map.coming", "바닷가")), "바닷가는 열렸어요. 이 물가의 풍경은 다음 업데이트에서 만날 수 있어요.")
	var locked := _shown(Loc.t("ui.map.locked", ["바닷가", 6, 3, 12, 4]))
	assert_true(locked.begins_with("바닷가를 6단계까지 복원(지금 3)"), locked)
	TranslationServer.set_locale(previous)

func test_english_and_japanese_are_untouched_by_particles() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(Loc.t("ui.toast.bought", "Bait"), "Got Bait")
	TranslationServer.set_locale("ja")
	assert_eq(Loc.t("ui.toast.bought", "餌"), "餌を手に入れました")
	TranslationServer.set_locale(previous)

func test_every_choosing_string_resolves_for_a_sample_name() -> void:
	var rows := LocalizationCheck.read_csv()
	var keys := _choosing_keys(rows)
	assert_true(keys.size() >= 8, "the shipped strings choose a particle (%d found)" % keys.size())
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	for key in keys:
		var text := Loc.t(key, _sample_args(rows[key].get("ko", "")))
		for marker in KoreanParticles.MARKERS:
			assert_false(marker in text, "'%s' still shows the choice %s: %s" % [key, marker, text])
	TranslationServer.set_locale(previous)

# --- guard: a choosing string must go through Loc ---

func test_no_choosing_string_is_formatted_with_a_bare_tr() -> void:
	var keys := _choosing_keys(LocalizationCheck.read_csv())
	var bad := PackedStringArray()
	for path in _script_files():
		var source := FileAccess.get_file_as_string(path)
		for key in keys:
			if _bare_tr(source, key):
				bad.append("%s formats '%s' with tr(); use Loc.t" % [path, key])
	assert_true(bad.is_empty(), "\n".join(bad))

func _choosing_keys(rows: Dictionary) -> Array:
	var keys := []
	for key in rows:
		var ko: String = rows[key].get("ko", "")
		for marker in KoreanParticles.MARKERS:
			if marker in ko:
				keys.append(key)
				break
	keys.sort()
	return keys

## One noun or number per placeholder, cycling through received- and vowel-ending names.
func _sample_args(ko: String) -> Array:
	var re := RegEx.new()
	assert_eq(re.compile("%([sd])"), 0, "the placeholder pattern compiles")
	var nouns := ["물고기", "떡밥", "바닷가"]
	var args := []
	var i := 0
	for hit in re.search_all(ko):
		args.append(nouns[i % nouns.size()] if hit.get_string(1) == "s" else 3)
		i += 1
	return args

func _script_files() -> PackedStringArray:
	var found := PackedStringArray()
	var pending := ["res://"]
	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub in dir.get_directories():
			pending.append(dir_path.path_join(sub))
		for file_name in dir.get_files():
			if file_name.ends_with(".gd"):
				found.append(dir_path.path_join(file_name))
	return found

## True when `source` formats `key` with a bare tr() — a method call on some other object does not
## count, so the match must not sit inside a longer name.
func _bare_tr(source: String, key: String) -> bool:
	var needle := 'tr("%s")' % key
	var at := source.find(needle)
	while at >= 0:
		if at == 0 or not source[at - 1] in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.":
			return true
		at = source.find(needle, at + 1)
	return false
