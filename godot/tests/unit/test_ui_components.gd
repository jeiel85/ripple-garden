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
	# The coded boxes compared (the shipped frame pictures replace them outside High Contrast).
	ArtLibrary.use_root("res://tests/fixtures/no_art")
	var normal := UiTheme.build(1.0, false, false)
	var contrast := UiTheme.build(1.0, false, true)
	ArtLibrary.use_root(ArtLibrary.DEFAULT_ROOT)
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

func test_gear_fits_the_page_at_the_largest_text_scale() -> void:
	# BACKLOG "최대 글자 크기에서 장비 화면 가로 넘침": the bait and bag summaries needed 769 px side
	# by side in Japanese at 160% + Large UI, against a 688 px page. ResponsiveRow stacks them.
	var previous := TranslationServer.get_locale()
	_fresh_state()
	for locale in ["ko", "en", "ja"]:
		TranslationServer.set_locale(locale)
		var host := Control.new()
		host.theme = UiTheme.build(1.6, true, false)
		host.size = Vector2(720, 1280)
		tree.root.add_child(host)
		var panel := GearPanel.new()
		host.add_child(panel)
		panel.setup(LoadoutService.new(GameState))
		panel.select_tab("rod")
		await tree.process_frame
		await tree.process_frame
		var page := panel.get_child(0) as Control
		assert_true(page.get_combined_minimum_size().x <= 720.0,
			"the gear page needs %.0f px in %s at 160%% + Large UI" % [page.get_combined_minimum_size().x, locale])
		var rows := _responsive_rows(panel)
		assert_eq(rows.size(), 2, "the featured card and the summaries share the responsive row")
		for row in rows:
			assert_true(row.size.x <= 720.0, "a responsive row grew past the page")
		# The summaries are the second row; at 720 px they cannot sit side by side in any language.
		var summaries := rows[1] as ResponsiveRow
		assert_true(summaries.vertical, "the summaries stack instead of running off the page in %s" % locale)
		host.size = Vector2(1080, 1280)
		await tree.process_frame
		await tree.process_frame
		assert_false(summaries.vertical, "a wide page puts the summaries back side by side")
		host.free()
	TranslationServer.set_locale(previous)
	_fresh_state()

func test_a_responsive_row_stacks_only_when_side_by_side_does_not_fit() -> void:
	var row := ResponsiveRow.new(10)
	for text in ["가나다라마바사", "아자차카타파하"]:
		var card := PanelContainer.new()
		var words := Label.new()
		words.text = text
		card.add_child(words)
		row.add_child(card)
	var needed := row.needed_width()
	assert_true(needed > 120.0 and needed < 600.0, "the two cards need %.0f px side by side" % needed)
	assert_true(row.fits(600.0), "a wide page keeps the cards side by side")
	assert_false(row.fits(120.0), "a narrow page cannot hold them side by side")
	row.free()

func _responsive_rows(node: Node) -> Array:
	var found: Array = []
	if node is ResponsiveRow:
		found.append(node)
	for child in node.get_children():
		found.append_array(_responsive_rows(child))
	return found

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
	for locale in ["ko", "en", "ja"]:
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

func test_mockup_pieces_replace_their_controls_and_step_aside_in_high_contrast() -> void:
	if not ArtLibrary.has("ui", "sign_journal"):
		return  # the pieces are optional art (D-032)
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")  # the pieces have Korean words baked in
	GameState.set_setting("high_contrast_meter", false)
	var host := Control.new()
	host.theme = UiTheme.build(1.0, false, false)
	tree.root.add_child(host)
	var board := UiKit.sign_board("fish", "도감", "sign_journal")
	host.add_child(board)
	assert_true(board.get_meta("mockup_picture", false), "the board cut from the mockup is shown")
	assert_false(board.get_child(0).visible, "the drawn icon and title hide under it")
	assert_eq(board.tooltip_text, "도감", "it keeps its name")
	GameState.set_setting("high_contrast_meter", true)
	host.theme = UiTheme.build(1.0, false, true)
	assert_false(board.get_meta("mockup_picture", true), "High Contrast gives the drawn board back")
	assert_true(board.get_child(0).visible)
	GameState.set_setting("high_contrast_meter", false)
	TranslationServer.set_locale("en")
	var english := UiKit.sign_board("fish", "Journal", "sign_journal")
	host.add_child(english)
	assert_false(english.get_meta("mockup_picture", true), "the Korean picture is not used in another language")
	TranslationServer.set_locale(previous)
	host.free()

func test_mockup_picture_buttons_grow_with_large_ui() -> void:
	if not ArtLibrary.has("ui", "btn_map_back"):
		return
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	GameState.set_setting("high_contrast_meter", false)
	GameState.set_setting("large_ui", false)
	var host := Control.new()
	host.theme = UiTheme.build(1.0, false, false)
	tree.root.add_child(host)
	var back := UiKit.icon_button("back", "뒤로", func() -> void: pass)
	UiKit.mockup_picture(back, "btn_map_back", [])
	host.add_child(back)
	assert_true(back.custom_minimum_size.y >= UiTheme.TOUCH_MIN_PX)
	GameState.set_setting("large_ui", true)
	host.theme = UiTheme.build(1.0, true, false)
	assert_true(back.custom_minimum_size.x >= UiTheme.TOUCH_MIN_LARGE_PX and back.custom_minimum_size.y >= UiTheme.TOUCH_MIN_LARGE_PX,
		"Large UI makes the touch target bigger around the picture")
	GameState.set_setting("large_ui", false)
	TranslationServer.set_locale(previous)
	host.free()

func test_a_subtitle_pill_wraps_instead_of_widening_past_its_cap() -> void:
	# Codex review #94: at the largest text scale a one-line subtitle pushed the journal header off screen.
	var host := Control.new()
	host.theme = UiTheme.build(1.6, true, false)
	tree.root.add_child(host)
	var long := UiKit.subtitle_pill("물가에서 만난 소중한 물고기들을 하나하나 정성껏 기록해 두는 곳이에요")
	host.add_child(long)
	assert_true(long.get_combined_minimum_size().x <= UiKit.SUBTITLE_MAX_WIDTH + 80.0, "the pill grew to %d px" % long.get_combined_minimum_size().x)
	var short := UiKit.subtitle_pill("짧은 말")
	host.add_child(short)
	assert_true(short.get_combined_minimum_size().x < long.get_combined_minimum_size().x, "a short subtitle is not narrower")
	host.free()

## Every way out of a screen: `variation` CircleButton circles (back or close), none of them a worded button.
func _exit_buttons(node: Node) -> Array:
	var found := []
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.theme_type_variation == "CircleButton" and (button.tooltip_text == TranslationServer.translate("ui.close") \
				or button.tooltip_text == TranslationServer.translate("ui.back")):
			found.append(button)
		assert_true(button.text != TranslationServer.translate("ui.close"), "%s keeps a worded Close button" % node.get_class())
	return found

func test_every_page_and_dialog_leaves_through_the_same_circle() -> void:
	# The settings dialog's worded "닫기" button and the pages' back circles did not match (2026-10-14).
	_fresh_state()
	GameState.set_setting("large_ui", false)
	for screen in [SettingsPanel.new(), RestorationPanel.new(), TextPanel.new(), GearPanel.new(), JournalPanel.new()]:
		tree.root.add_child(screen)
		var exits := _exit_buttons(screen)
		assert_eq(exits.size(), 1, "%s has one way out" % screen.get_script().get_global_name())
		if exits.size() == 1:
			assert_eq((exits[0] as Button).custom_minimum_size, Vector2.ONE * UiTheme.TOUCH_MIN_PX)
		screen.free()

func test_the_way_out_grows_with_large_ui() -> void:
	GameState.set_setting("large_ui", false)
	var host := Control.new()
	host.theme = UiTheme.build(1.0, false, false)
	tree.root.add_child(host)
	var close := UiKit.exit_button("close", "닫기", func() -> void: pass)
	host.add_child(close)
	assert_eq(close.custom_minimum_size, Vector2.ONE * UiTheme.TOUCH_MIN_PX)
	GameState.set_setting("large_ui", true)
	host.theme = UiTheme.build(1.0, true, false)
	assert_eq(close.custom_minimum_size, Vector2.ONE * UiTheme.TOUCH_MIN_LARGE_PX)
	GameState.set_setting("large_ui", false)
	host.free()

func test_a_page_title_sits_on_the_page_centre_line() -> void:
	# The gear sign was centred in the space right of the back button, so it sat right of the screen's centre.
	var host := Control.new()
	host.theme = UiTheme.build(1.0, false, false)
	host.size = Vector2(720, 400)
	tree.root.add_child(host)
	var title := Label.new()
	title.text = "장비"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var header := UiKit.page_header(UiKit.exit_button("back", "뒤로", func() -> void: pass), title)
	header.size = Vector2(720, 0)
	host.add_child(header)
	header.size = Vector2(720, header.get_combined_minimum_size().y)
	header.notification(Container.NOTIFICATION_SORT_CHILDREN)
	assert_true(absf(title.position.x + title.size.x / 2.0 - 360.0) <= 1.0, "title centre at %.1f" % (title.position.x + title.size.x / 2.0))
	# Codex review #104: a trailing part wider than the back button (the journal's counter) must not pull it aside.
	var other := Label.new()
	other.text = "장비"
	other.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(200, 40)
	var with_counter := UiKit.page_header(UiKit.exit_button("back", "뒤로", func() -> void: pass), other, wide)
	host.add_child(with_counter)
	with_counter.size = Vector2(720, with_counter.get_combined_minimum_size().y)
	with_counter.notification(Container.NOTIFICATION_SORT_CHILDREN)
	assert_true(absf(other.position.x + other.size.x / 2.0 - 360.0) <= 1.0, "title centre at %.1f beside a wide counter" % (other.position.x + other.size.x / 2.0))
	host.free()

func test_the_top_bar_settings_circle_is_no_taller_than_a_status_pill() -> void:
	var theme := UiTheme.build(1.0, false, false)
	var style := theme.get_stylebox("normal", "TopBarButton") as InsetStyle
	var drawn := style.draw_rect_for(Rect2(Vector2.ZERO, Vector2.ONE * UiTheme.TOUCH_MIN_PX))
	assert_true(drawn.size.y < UiTheme.TOUCH_MIN_PX * 0.7, "the circle is %d px across" % drawn.size.y)
