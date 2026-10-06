extends TestCase

## P0-024 / UI building blocks: the settings screen, toast queue, fight meter, theme and journal cards.

func _fresh_state() -> void:
	GameState.new_game()

func _panel() -> SettingsPanel:
	var panel := SettingsPanel.new()
	tree.root.add_child(panel)
	panel.refresh()
	return panel

# --- settings panel ---

func test_every_setting_has_a_control_or_is_explicitly_hidden() -> void:
	var shown := {}
	for section in SettingsPanel.SECTIONS:
		for row in section["rows"]:
			shown[row[0]] = true
	for key in SaveSchema.SETTING_SPECS:
		assert_true(shown.has(key) or key in SettingsPanel.HIDDEN_KEYS, "setting '%s' cannot be changed in the UI" % key)
	for key in shown:
		assert_true(SaveSchema.is_known_setting(key), "the UI offers unknown setting '%s'" % key)

func test_panel_controls_mirror_the_save_without_echoing_changes() -> void:
	_fresh_state()
	GameState.set_setting("auto_hook", true)
	GameState.set_setting("text_scale", 1.3)
	GameState.set_setting("quality", "high")
	var changes: Array = []
	var handler := func(key: String) -> void: changes.append(key)
	EventBus.settings_changed.connect(handler)
	var panel := _panel()
	assert_true((panel.control_for("auto_hook") as CheckButton).button_pressed)
	assert_true(absf((panel.control_for("text_scale") as HSlider).value - 1.3) < 0.001)
	assert_eq((panel.control_for("quality") as OptionButton).selected, 2)
	assert_true(changes.is_empty(), "showing the panel must not rewrite settings")
	EventBus.settings_changed.disconnect(handler)
	panel.free()
	_fresh_state()

func test_toggling_a_control_changes_the_setting() -> void:
	_fresh_state()
	var panel := _panel()
	(panel.control_for("haptics") as CheckButton).button_pressed = false
	assert_eq(GameState.get_setting("haptics"), false)
	(panel.control_for("reduced_motion") as CheckButton).button_pressed = true
	assert_eq(GameState.get_setting("reduced_motion"), true)
	(panel.control_for("volume_bgm") as HSlider).value = 0.35
	assert_eq(GameState.get_setting("volume_bgm"), 0.35)
	var fps := panel.control_for("fps_cap") as OptionButton
	fps.select(1)
	fps.item_selected.emit(1)
	assert_eq(GameState.get_setting("fps_cap"), 60)
	panel.free()
	_fresh_state()

func test_panel_follows_changes_made_elsewhere() -> void:
	_fresh_state()
	var panel := _panel()
	GameState.set_setting("large_ui", true)
	assert_true((panel.control_for("large_ui") as CheckButton).button_pressed)
	GameState.set_setting("volume_water", 0.15)
	assert_true(absf((panel.control_for("volume_water") as HSlider).value - 0.15) < 0.001)
	panel.free()
	_fresh_state()

func test_slider_ranges_match_the_setting_specs() -> void:
	var panel := _panel()
	for section in SettingsPanel.SECTIONS:
		for row in section["rows"]:
			if row[1] != "slider":
				continue
			var spec: Dictionary = SaveSchema.SETTING_SPECS[row[0]]
			var slider := panel.control_for(row[0]) as HSlider
			assert_eq(slider.min_value, float(spec["min"]), "%s min" % row[0])
			assert_eq(slider.max_value, float(spec["max"]), "%s max" % row[0])
	panel.free()

# --- toast ---

func test_toast_queues_messages_without_overlap_or_duplicates() -> void:
	var toast := Toast.new()
	toast.reduced_motion = true
	tree.root.add_child(toast)
	toast.show_message("first")
	toast.show_message("first")  # duplicate of the one being shown
	toast.show_message("second")
	toast.show_message("second")  # duplicate in the queue
	toast.show_message("")        # empty is ignored
	assert_true(toast.is_showing())
	assert_eq(toast._label.text, "first")
	assert_eq(toast.pending_count(), 1)
	toast._next()
	assert_eq(toast._label.text, "second")
	assert_eq(toast.pending_count(), 0)
	toast._next()
	assert_false(toast.is_showing())
	assert_false(toast.visible)
	toast.free()

# --- fight meter ---

func test_fight_meter_names_the_tension_in_words() -> void:
	var meter := FightMeter.new()
	tree.root.add_child(meter)
	meter.configure(0.3, 0.75, false)
	meter.update_values(0.5, 0.2)
	var ok_text: String = meter._word.text
	meter.update_values(0.9, 0.2)
	var high_text: String = meter._word.text
	meter.update_values(0.1, 0.2)
	var low_text: String = meter._word.text
	assert_true(ok_text != high_text and high_text != low_text and ok_text != low_text, "the three states must read differently")
	assert_eq(ok_text, String(TranslationServer.translate("ui.fight.tension.ok")))
	meter.free()

# --- theme ---

func test_theme_scales_with_text_size_and_large_ui() -> void:
	var small := UiTheme.build(0.8, false, false)
	var normal := UiTheme.build(1.0, false, false)
	var big := UiTheme.build(1.6, false, false)
	var large := UiTheme.build(1.0, true, false)
	assert_true(small.default_font_size < normal.default_font_size and normal.default_font_size < big.default_font_size)
	assert_true(large.default_font_size > normal.default_font_size)
	assert_eq(UiTheme.font_px(5.0, false), UiTheme.font_px(1.6, false), "text scale is clamped")
	assert_true(UiTheme.touch_min(true) > UiTheme.touch_min(false))
	assert_true(UiTheme.touch_min(false) >= 96.0, "48 dp at 2 px per dp")

func test_high_contrast_theme_uses_stronger_borders() -> void:
	var normal := UiTheme.build(1.0, false, false)
	var contrast := UiTheme.build(1.0, false, true)
	var normal_box := normal.get_stylebox("normal", "Button") as StyleBoxFlat
	var contrast_box := contrast.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_true(contrast_box.border_width_left > normal_box.border_width_left)
	assert_true((contrast.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.a > (normal.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.a)

# --- journal / gear / restoration panels ---

func test_journal_panel_lists_every_species_and_hides_the_unmet() -> void:
	_fresh_state()
	GameState.record_encounter("fish_crucian_carp", 12.0, "steady")
	var panel := JournalPanel.new()
	tree.root.add_child(panel)
	panel.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), "region_01_quiet_pond")
	panel.refresh()
	assert_eq(panel.card_count(), ContentDB.fish.size(), "the All tab lists every species of the game")
	assert_eq(panel._counter.text, "%d / %d" % [1, ContentDB.fish.size()])
	panel.select_tab("pond")
	assert_eq(panel.card_count(), 10, "the pond tab lists the pond's species")
	assert_eq(panel._progress.text, String(TranslationServer.translate("ui.journal.progress")) % [1, 10])
	panel.free()
	_fresh_state()

func test_gear_panel_equips_owned_items_only_through_the_state() -> void:
	_fresh_state()
	var panel := GearPanel.new()
	panel.setup(LoadoutService.new(GameState))
	tree.root.add_child(panel)
	panel.select_tab("rod")
	assert_eq(panel.card_count(), ContentDB.rods.size(), "every rod is listed, owned or not")
	panel.select_item("rod_light")
	panel._equip()
	assert_eq(GameState.get_equipped_rod(), "rod_light")
	panel.select_tab("bait")
	assert_eq(panel.card_count(), ContentDB.baits.size())
	panel.select_item("bait_worm")
	panel._equip()
	assert_eq(GameState.get_equipped_bait(), "bait_worm")
	panel.select_tab("rod")
	panel.select_item("rod_old_master")
	panel._equip()  # not owned: the service refuses
	assert_eq(GameState.get_equipped_rod(), "rod_light")
	panel.free()
	_fresh_state()

func test_restoration_panel_states_the_requirement_and_the_cap() -> void:
	_fresh_state()
	var restoration := RestorationService.new(GameState, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	var panel := RestorationPanel.new()
	tree.root.add_child(panel)
	panel.setup(restoration, "region_01_quiet_pond")
	panel.refresh()
	assert_true(panel._confirm.disabled, "no points yet")
	assert_true(panel._brings.visible)
	GameState.add_restoration_points("region_01_quiet_pond", 25)
	panel.refresh()
	assert_false(panel._confirm.disabled)
	GameState.add_restoration_points("region_01_quiet_pond", 100000)
	GameState.set_restoration_level("region_01_quiet_pond", int(ContentDB.balance["vertical_slice"]["max_restoration_level"]))
	panel.refresh()
	assert_true(panel._confirm.disabled)
	assert_false(panel._brings.visible)
	panel.free()
	_fresh_state()

func test_restoration_panel_names_what_the_next_stage_brings() -> void:
	_fresh_state()
	var restoration := RestorationService.new(GameState, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	var panel := RestorationPanel.new()
	tree.root.add_child(panel)
	panel.setup(restoration, "region_01_quiet_pond")
	for level in range(1, int(ContentDB.balance["vertical_slice"]["max_restoration_level"]) + 1):
		var names := panel._next_stage_names(level)
		assert_false(names.is_empty(), "stage %d promises nothing" % level)
	assert_true(panel._next_stage_names(2).contains(String(TranslationServer.translate("ui.prop.reed"))))
	panel.free()

# --- panels fit the screen in every language ---

func test_modal_width_never_exceeds_the_screen() -> void:
	assert_eq(UIController.fit_width(640.0, 720.0), 640.0, "a normal phone keeps the design width")
	assert_eq(UIController.fit_width(640.0, 600.0), 552.0, "a narrow screen shrinks the panel and keeps a margin")
	assert_true(UIController.fit_width(640.0, 400.0) < 400.0)

func test_no_panel_is_wider_than_its_design_width_in_korean_or_english() -> void:
	var previous := TranslationServer.get_locale()
	_fresh_state()
	var restoration := RestorationService.new(GameState, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	# Measured with the real UI theme (30 px text): the default theme's 16 px text would hide the problem.
	var theme := UiTheme.build(1.0, false, false)
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		var panels: Array = []
		var settings := SettingsPanel.new()
		panels.append(settings)
		var restore := RestorationPanel.new()
		restore.setup(restoration, "region_01_quiet_pond")
		panels.append(restore)
		var journal := JournalPanel.new()
		journal.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), "region_01_quiet_pond")
		panels.append(journal)
		var inspect := InspectPanel.new()
		panels.append(inspect)
		var licenses := TextPanel.new()
		licenses.show_text("Licenses", TextPanel.licenses_text())
		panels.append(licenses)
		for panel in panels:
			panel.theme = theme
			tree.root.add_child(panel)
			if panel.has_method("refresh"):
				panel.refresh()
			var design_width: float = panel.custom_minimum_size.x
			assert_true(panel.get_combined_minimum_size().x <= design_width + 1.0,
				"%s needs %.0f px in %s but is designed for %.0f" % [panel.get_script().get_path().get_file(), panel.get_combined_minimum_size().x, locale, design_width])
			panel.free()
	TranslationServer.set_locale(previous)
	_fresh_state()

# --- review fixes ---

func test_refreshing_the_journal_leaves_no_stale_cards_in_the_layout() -> void:
	_fresh_state()
	var panel := JournalPanel.new()
	tree.root.add_child(panel)
	panel.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), "region_01_quiet_pond")
	panel.refresh()
	panel.refresh()
	panel.refresh()
	assert_eq(panel._list.get_child_count(), panel.card_count(), "old cards must leave the list immediately")
	panel.free()
	_fresh_state()

func test_the_restoration_bar_is_full_at_the_cap_even_after_a_partial_stage() -> void:
	_fresh_state()
	var restoration := RestorationService.new(GameState, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	var panel := RestorationPanel.new()
	tree.root.add_child(panel)
	panel.setup(restoration, "region_01_quiet_pond")
	GameState.add_restoration_points("region_01_quiet_pond", 150)
	GameState.set_restoration_level("region_01_quiet_pond", 3)
	panel.refresh()  # leaves max_value at the next stage's requirement
	GameState.add_restoration_points("region_01_quiet_pond", 5000)
	GameState.set_restoration_level("region_01_quiet_pond", int(ContentDB.balance["vertical_slice"]["max_restoration_level"]))
	panel.refresh()
	assert_eq(panel._bar.value, panel._bar.max_value, "the bar must read full at the cap")
	panel.free()
	_fresh_state()

func test_restore_ready_is_shown_by_text_as_well_as_colour() -> void:
	var hud := Hud.new()
	tree.root.add_child(hud)
	hud.set_restore_ready(false)
	var idle_text := hud.restore_button.tooltip_text
	hud.set_restore_ready(true)
	assert_true(hud.restore_button.tooltip_text != idle_text, "the name must change, not only the colour")
	assert_true(hud.restore_dot.visible, "a dot marks the button")
	hud.set_restore_ready(false)
	assert_eq(hud.restore_button.tooltip_text, idle_text)
	assert_false(hud.restore_dot.visible)
	hud.free()

func test_sliders_and_popup_rows_are_full_size_touch_targets() -> void:
	var panel := _panel()
	for section in SettingsPanel.SECTIONS:
		for row in section["rows"]:
			if row[1] == "slider":
				assert_true((panel.control_for(row[0]) as HSlider).custom_minimum_size.y >= UiTheme.TOUCH_MIN_PX, "%s slider is too thin to touch" % row[0])
	panel.free()
	var theme := UiTheme.build(1.0, false, false)
	var font_height := ThemeDB.fallback_font.get_height(theme.default_font_size)
	assert_true(font_height + theme.get_constant("v_separation", "PopupMenu") >= UiTheme.TOUCH_MIN_PX - 8.0, "drop-down rows are too short to tap")

func test_safe_insets_apply_only_on_mobile_screens() -> void:
	var safe := Rect2i(0, 100, 1080, 2250)
	assert_eq(UIController.safe_insets(safe, Vector2i(1080, 2400), 1600.0, false), Vector2.ZERO, "a desktop window must get no insets")
	var mobile := UIController.safe_insets(safe, Vector2i(1080, 2400), 1600.0, true)
	assert_true(absf(mobile.x - 100.0 * 1600.0 / 2400.0) < 0.01)
	assert_true(absf(mobile.y - 50.0 * 1600.0 / 2400.0) < 0.01)
	assert_eq(UIController.safe_insets(Rect2i(), Vector2i(1080, 2400), 1600.0, true), Vector2.ZERO)
	assert_eq(UIController.safe_insets(safe, Vector2i(0, 0), 1600.0, true), Vector2.ZERO)
