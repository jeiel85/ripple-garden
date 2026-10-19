extends TestCase

## Interface sounds (BACKLOG "오디오: 버튼 소리"): the Ui bus, the data in audio.json `ui`, the
## pooled UiSound player and the wiring in every UiKit button. Settings rows themselves are covered
## by test_ui_components (schema ↔ panel ↔ localization); this file covers the sound path.

func _raw_audio() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/audio.json")
	return JSON.parse_string(text)

func _validate_audio(mutate: Callable) -> PackedStringArray:
	var raw := _raw_audio()
	mutate.call(raw)
	var result := ContentValidator.validate({"audio": raw})
	return result["errors"]

func _has_error(errors: PackedStringArray, substring: String) -> bool:
	for problem in errors:
		if String(problem).contains(substring):
			return true
	return false

# --- data (audio.json ui) ---

func test_the_shipped_ui_section_is_valid() -> void:
	var ui: Dictionary = _raw_audio().get("ui", {})
	assert_eq(ui.get("bus"), "Ui", "the click plays on the Ui bus")
	assert_true(ui.get("sounds", {}).has("click"), "a click sound is defined")
	var result := ContentValidator.validate(_raw_all())
	var errors: PackedStringArray = result["errors"]
	assert_eq(errors, PackedStringArray(), "shipped content errors")

func _raw_all() -> Dictionary:
	var raw: Dictionary = {}
	for category in ContentValidator.FILE_NAMES:
		var text := FileAccess.get_file_as_string("res://data/".path_join(ContentValidator.FILE_NAMES[category]))
		raw[category] = JSON.parse_string(text)
	return raw

func test_a_missing_ui_stream_is_reported() -> void:
	var errors := _validate_audio(func(raw: Dictionary) -> void:
		raw["ui"]["sounds"]["click"]["stream"] = "res://audio/streams/missing.wav")
	assert_true(_has_error(errors, "audio.json.ui.sounds.click.stream: file not found"), str(errors))

func test_a_bad_ui_bus_is_reported() -> void:
	var errors := _validate_audio(func(raw: Dictionary) -> void:
		raw["ui"]["bus"] = "Reverb")
	assert_true(_has_error(errors, "audio.json.ui.bus: must be one of"), str(errors))

func test_an_empty_ui_sounds_map_is_reported() -> void:
	var errors := _validate_audio(func(raw: Dictionary) -> void:
		raw["ui"]["sounds"] = {})
	assert_true(_has_error(errors, "audio.json.ui.sounds: must be a non-empty object"), str(errors))

func test_a_ui_sound_volume_must_be_in_range() -> void:
	var errors := _validate_audio(func(raw: Dictionary) -> void:
		raw["ui"]["sounds"]["click"]["volume"] = 2.0)
	assert_true(_has_error(errors, "ui.sounds.click.volume"), str(errors))

# --- the player ---

func test_click_plays_and_the_pool_stays_bounded() -> void:
	# Replace any pool from an earlier test: play often, count the players.
	for _i in 20:
		assert_true(UiSound.play("click"), "the shipped click plays")
	assert_eq(UiSound.last_played(), "click")
	assert_true(UiSound.voice_count() <= 2, "voices are pooled (%d)" % UiSound.voice_count())

func test_an_unknown_sound_is_a_no_op() -> void:
	assert_false(UiSound.play("splash"), "unknown sounds do nothing")
	assert_false(UiSound.play(""), "the empty name does nothing")

func test_the_ui_bus_exists() -> void:
	assert_eq(AudioService.missing_buses(), PackedStringArray(), "the bus layout has every bus the code asks for")
	assert_true("Ui" in AudioService.REQUIRED_BUSES, "Ui is a required bus")
	assert_eq(SettingsApplier.VOLUME_BUSES.get("volume_ui"), "Ui", "the volume_ui setting drives the Ui bus")

# --- the wiring ---

func test_every_uikit_button_clicks_when_pressed() -> void:
	var pressed := [false]
	var plain := UiKit.button("닫기", func() -> void: pressed[0] = true)
	var with_icon := UiKit.icon_button("close", "", func() -> void: pressed[0] = true)
	var card := UiKit.action_card("fish", "방생", "다음에도 또 만나길", func() -> void: pressed[0] = true)
	var centred := UiKit.centered_button("fish", "낚시", func() -> void: pressed[0] = true, "PrimaryButton")
	for button in [plain, with_icon, card, centred]:
		button.pressed.emit()
		assert_true(pressed[0], "the button still runs its callback")
		assert_eq(UiSound.last_played(), "click", "and clicks")
	for button in [plain, with_icon, card, centred]:
		button.free()
