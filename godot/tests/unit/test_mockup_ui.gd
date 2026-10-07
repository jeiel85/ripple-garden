extends TestCase

## D-018: the interface rebuilt after the design mockups — icons, the status bar that fits any width,
## the fishing row, the catch result's "fish again", water-mind previews and photos, the journal's
## tabs and NEW badges, the angler's cast direction, and full-screen panels that stay on screen.

const SCENE := "res://world/game_root.tscn"

var _was_blocked := false

func _start() -> GameRoot:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	_was_blocked = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load(SCENE) as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	return root

func _stop(root: GameRoot) -> void:
	root.free()
	GameState.new_game()
	tree.root.get_node("SaveService").write_blocked = _was_blocked

func _land_a_fish(root: GameRoot, fish_id: String = "fish_crucian_carp") -> void:
	root.fishing.spawn_fish(fish_id)
	root.ui.world_input.cast_quick()
	var elapsed := 0.0
	while root.fishing.state != FishingController.State.INSPECT and elapsed < 240.0:
		if root.fishing.state == FishingController.State.HOOK:
			root.fishing.tap()
		if root.fishing.state == FishingController.State.FIGHT:
			root.fishing.set_reeling(root.fishing.fight.tension < 0.5)
		root.fishing.advance(1.0 / 30.0)
		elapsed += 1.0 / 30.0
	assert_eq(root.fishing.state, FishingController.State.INSPECT, "the fish was never landed")

# --- icons ---

func test_every_listed_icon_exists_and_every_icon_file_is_listed() -> void:
	for icon_name in UiIcons.NAMES:
		assert_true(ResourceLoader.exists(UiIcons.DIR + icon_name + ".svg"), "icon %s is missing" % icon_name)
		assert_true(UiIcons.texture(icon_name) is Texture2D)
	for file_name in DirAccess.get_files_at(UiIcons.DIR):
		if not file_name.ends_with(".svg"):
			continue
		var stem := file_name.get_basename()
		assert_true(stem in UiIcons.NAMES or stem.begins_with("theme_"), "%s is drawn but not listed in UiIcons.NAMES" % stem)

func test_an_unknown_icon_is_reported_not_fatal() -> void:
	expect_engine_error("unknown icon")
	assert_not_null(UiIcons.texture("no_such_icon"))
	assert_eq(UiIcons.for_weather("storm"), "storm")
	assert_eq(UiIcons.for_weather("snow"), "weather")

# --- status bar ---

func test_clock_and_count_formatting() -> void:
	assert_eq(Hud.clock_text(14.534), "14:32")
	assert_eq(Hud.clock_text(0.0), "00:00")
	assert_eq(Hud.clock_text(24.0), "00:00")
	assert_eq(Hud.format_count(0), "0")
	assert_eq(Hud.format_count(1240), "1,240")
	assert_eq(Hud.format_count(999999999), "999,999,999")

func test_the_top_bar_drops_optional_words_before_squeezing_the_region_name() -> void:
	var root := _start()
	await tree.process_frame
	var hud: Hud = root.ui.hud
	hud.fit_top_bar(4000.0)
	assert_true(hud.currency_words[0].visible and hud.weather_label.visible, "a wide screen shows every word")
	assert_false(hud.region_label.clip_text)
	# Widths come from the row itself, so the test holds for any font the platform draws with.
	var full := (hud.top_bar.get_child(0) as Control).get_combined_minimum_size().x + 32.0
	hud.fit_top_bar(full - 1.0)
	assert_false(hud.currency_words[0].visible, "the currency words go first")
	assert_true(hud.weather_label.visible, "the weather word stays while there is room")
	assert_false(hud.region_label.clip_text)
	hud.fit_top_bar(360.0)
	assert_false(hud.currency_words[0].visible)
	assert_false(hud.weather_label.visible)
	assert_true(hud.region_label.clip_text, "only the last resort shortens the region name")
	assert_true(hud.region_label.custom_minimum_size.x >= 48.0)
	_stop(root)

func test_the_status_bar_shows_region_clock_weather_and_currencies() -> void:
	var root := _start()
	GameState.add_ripple(1240)
	GameState.add_memory(28)
	var hud: Hud = root.ui.hud
	assert_eq(hud.region_label.text, String(TranslationServer.translate("region.quiet_pond.name")))
	assert_eq(hud.clock_label.text, Hud.clock_text(TimeService.get_hours()))
	assert_eq(hud.ripple_label.text, "1,240")
	assert_eq(hud.memory_label.text, "28")
	_stop(root)

# --- fishing row ---

func test_the_bottom_row_turns_into_the_fishing_controls_while_a_line_is_out() -> void:
	var root := _start()
	var hud: Hud = root.ui.hud
	assert_true(hud.bottom_bar.visible)
	assert_false(hud.fishing_bar.visible)
	hud.set_cta_for_state("fight")
	assert_false(hud.bottom_bar.visible, "navigation hides while fighting")
	assert_true(hud.fishing_bar.visible)
	assert_false(hud.action_button.disabled, "the reel button works during the fight")
	assert_true(hud.fishing_journal_button.disabled, "the journal cannot be opened mid-fight")
	assert_true(hud.settings_button.disabled, "nor the settings")
	assert_true(hud.status_button.disabled, "nor the map")
	assert_true(hud.restore_button.disabled, "restoration waits until the line is in")
	hud.set_cta_for_state("wait")
	assert_true(hud.action_button.disabled, "nothing to hook before a bite")
	assert_false(hud.fishing_journal_button.disabled)
	assert_false(hud.settings_button.disabled)
	assert_true(hud.restore_button.disabled, "a restoration screen over a waiting line would let the bite slip")
	hud.set_cta_for_state("ready")
	assert_true(hud.bottom_bar.visible)
	assert_false(hud.fishing_bar.visible)
	assert_false(hud.restore_button.disabled)
	_stop(root)

func test_a_bite_closes_the_journal_opened_while_waiting() -> void:
	var root := _start()
	root.ui.open_journal()
	assert_true(root.ui.journal_panel.is_inside_tree())
	EventBus.fishing_state_changed.emit("wait", "bite_hint")
	assert_false(root.ui.journal_panel.is_inside_tree(), "the bite must be answerable")
	root.ui._open(root.ui.map_panel)
	EventBus.fishing_state_changed.emit("wait", "bite_hint")
	assert_false(root.ui.map_panel.is_inside_tree(), "the map gives way to a bite too")
	_stop(root)

func test_cancel_reels_the_line_in() -> void:
	var root := _start()
	root.ui.world_input.cast_quick()
	root.fishing.advance(2.0)
	assert_eq(root.fishing.state, FishingController.State.WAIT)
	root.ui.hud.cancel_pressed.emit()
	assert_eq(root.fishing.state, FishingController.State.READY)
	_stop(root)

func test_the_reel_ring_follows_the_landing_progress() -> void:
	var button := Hud.ReelButton.new()
	button.set_progress(0.4)
	assert_true(absf(button.progress - 0.4) < 0.001)
	button.set_progress(3.0)
	assert_eq(button.progress, 1.0)
	button.free()

# --- catch result ---

func test_fish_again_releases_and_casts_at_once() -> void:
	var root := _start()
	_land_a_fish(root)
	assert_eq(root.ui.current_panel(), root.ui.inspect_panel)
	root.ui.inspect_panel.fish_again_pressed.emit()
	assert_eq(GameState.get_collection_record("fish_crucian_carp")["releases"], 1, "fishing again lets the fish go")
	var elapsed := 0.0
	while root.fishing.state != FishingController.State.CAST and elapsed < 5.0:
		root.fishing.advance(1.0 / 30.0)
		elapsed += 1.0 / 30.0
	assert_eq(root.fishing.state, FishingController.State.CAST, "and the line goes straight back out")
	assert_false(root.ui.is_panel_open())
	_stop(root)

func test_the_catch_result_names_rarity_place_and_date() -> void:
	var root := _start()
	_land_a_fish(root)
	var panel: InspectPanel = root.ui.inspect_panel
	assert_eq(panel._rarity_title.text, String(TranslationServer.translate("ui.rarity.1")))
	assert_eq(panel._place.text, String(TranslationServer.translate("region.quiet_pond.name")))
	assert_false(panel._when.text.is_empty())
	assert_true(panel._header_icon_left.visible, "a first discovery gets the laurels")
	_stop(root)

func test_dates_read_as_local_day_and_time() -> void:
	var text := InspectPanel.date_text(0)
	assert_true(text.contains("1970") or text.contains("1969"), text)
	assert_false(InspectPanel.date_text(0, false).contains(":"), "the day-only form has no time")

# --- water-mind ---

func test_water_mind_previews_change_the_view_not_the_world() -> void:
	var root := _start()
	root.ui.enter_water_mind()
	var weather := root.region.weather
	var real_weather := weather.current_id
	root.ui.water_mind._cycle_weather()
	assert_false(weather.preview_id.is_empty())
	assert_eq(weather.current_id, real_weather, "the real weather keeps running underneath")
	assert_eq(root.ui.water_mind.weather_preview, weather.preview_id)
	root.ui.water_mind._cycle_time()
	assert_true(root.region.environment.hours_provider.is_valid(), "the scene shows the chosen time of day")
	var dawn_hour := UIController.preview_hour("dawn")
	assert_true(dawn_hour >= 6.0 and dawn_hour < 9.0, "dawn preview at %.1f" % dawn_hour)
	root.ui.water_mind.exit()
	assert_true(weather.preview_id.is_empty(), "leaving restores the real weather")
	assert_false(root.region.environment.hours_provider.is_valid(), "and the real clock")
	_stop(root)

func test_the_overlay_hides_and_comes_back_with_a_tap() -> void:
	var root := _start()
	var overlay := root.ui.water_mind
	root.ui.enter_water_mind()
	assert_true(overlay.is_chrome_visible())
	overlay.hide_chrome()
	assert_false(overlay.is_chrome_visible())
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	overlay._gui_input(tap)
	assert_true(overlay.is_chrome_visible())
	overlay._process(WaterMindOverlay.MENU_HIDE_SEC + 0.1)
	assert_false(overlay.is_chrome_visible(), "the overlay tucks itself away when idle")
	_stop(root)

func test_saving_a_photo_leaves_a_showing_message_on_screen() -> void:
	var root := _start()
	root.ui.enter_water_mind()  # shows the water-mind hint
	assert_true(root.ui.toast.visible)
	assert_true(root.ui.water_mind.is_chrome_visible())
	# The capture itself waits for a drawn frame (not available headless); its hide/restore pair is tested.
	var hidden := root.ui.hide_for_photo()
	assert_false(root.ui.toast.visible, "nothing covers the picture")
	assert_false(root.ui.water_mind.is_chrome_visible())
	root.ui.restore_after_photo(hidden)
	assert_true(root.ui.toast.visible, "the message hidden for the picture comes back")
	assert_true(root.ui.water_mind.is_chrome_visible())
	_stop(root)

func test_photos_are_saved_as_png_with_a_time_stamped_name() -> void:
	var dir := "user://test_photos"
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.AQUA)
	var path := PhotoSaver.save(image, dir)
	assert_false(path.is_empty())
	assert_true(FileAccess.file_exists(path))
	assert_true(path.get_file().begins_with("ripple_garden_"))
	var second := PhotoSaver.save(image, dir)
	assert_true(second != path, "two photos in the same second keep both")
	for file_name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)
	expect_engine_error("nothing to save")
	assert_eq(PhotoSaver.save(Image.new(), dir), "")
	assert_eq(PhotoSaver.file_stem({"year": 2026, "month": 10, "day": 6, "hour": 14, "minute": 3, "second": 5}), "ripple_garden_20261006_140305")

# --- journal ---

func test_a_new_species_is_new_until_its_page_is_seen() -> void:
	GameState.new_game()
	assert_false(GameState.has_unseen_journal_entries())
	GameState.record_encounter("fish_minnow", 9.0, "dasher", "rain")
	assert_true(GameState.has_unseen_journal_entries())
	assert_eq(GameState.get_collection_record("fish_minnow")["first_weather"], "rain")
	GameState.record_encounter("fish_minnow", 11.0, "dasher", "clear")
	assert_eq(GameState.get_collection_record("fish_minnow")["first_weather"], "rain", "the first day's weather is kept")
	GameState.mark_journal_seen("fish_minnow")
	assert_false(GameState.has_unseen_journal_entries())
	GameState.new_game()

func test_records_from_older_saves_are_not_flagged_new() -> void:
	var save := SaveSchema.normalize({"collection": {"fish_minnow": {"encounters": 3}}}, 0)
	assert_eq(save["collection"]["fish_minnow"]["journal_seen"], true)
	assert_eq(save["collection"]["fish_minnow"]["first_weather"], "")
	assert_eq(SaveSchema.default_collection_record()["journal_seen"], false)

func test_journal_tabs_split_the_world_and_the_page_clears_new() -> void:
	GameState.new_game()
	GameState.record_encounter("fish_crucian_carp", 12.0, "steady", "clear")
	var panel := JournalPanel.new()
	tree.root.add_child(panel)
	panel.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), "region_01_quiet_pond")
	panel.refresh()
	assert_eq(panel.selected_id, "fish_crucian_carp", "the page opens on the newly met fish")
	assert_false(GameState.has_unseen_journal_entries(), "showing its page clears NEW")
	var total := 0
	for tab in ["pond", "valley", "river", "sea"]:
		panel.select_tab(tab)
		total += panel.card_count()
	assert_eq(total, ContentDB.fish.size(), "every species belongs to exactly one place tab")
	panel.select_tab("special")
	for fish_id in panel._cards:
		assert_true(int(ContentDB.get_fish(fish_id)["rarity"]) >= 4, "%s is not special" % fish_id)
	panel.focus_fish("fish_crucian_carp")
	assert_eq(panel.tab, "all", "focusing a fish outside the tab switches to All")
	assert_eq(panel.selected_id, "fish_crucian_carp")
	panel.free()
	GameState.new_game()

func test_opening_the_journal_on_a_fish_leaves_other_new_fish_new() -> void:
	var root := _start()
	GameState.record_encounter("fish_minnow", 9.0, "dasher", "clear")
	GameState.record_encounter("fish_crucian_carp", 12.0, "steady", "clear")
	root.ui.open_journal("fish_crucian_carp")
	assert_eq(root.ui.journal_panel.selected_id, "fish_crucian_carp")
	assert_eq(GameState.get_collection_record("fish_crucian_carp")["journal_seen"], true)
	assert_eq(GameState.get_collection_record("fish_minnow")["journal_seen"], false, "a fish never shown stays NEW")
	_stop(root)

func test_journal_sorting_keeps_unmet_species_last() -> void:
	GameState.new_game()
	GameState.record_encounter("fish_snakehead", 60.0, "heavy")
	GameState.record_encounter("fish_minnow", 8.0, "dasher")
	var panel := JournalPanel.new()
	tree.root.add_child(panel)
	panel.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), "region_01_quiet_pond")
	panel.select_tab("pond")
	for mode in JournalPanel.SORTS:
		panel.sort_mode = mode
		panel.refresh()
		var order: Array = panel._cards.keys()
		assert_true(order.find("fish_snakehead") < 2 and order.find("fish_minnow") < 2, "met species come first (%s)" % mode)
	panel.sort_mode = "size"
	panel.refresh()
	assert_eq(panel._cards.keys()[0], "fish_snakehead", "the biggest first")
	panel.free()
	GameState.new_game()

# --- world ---

func test_the_angler_casts_out_over_the_pond() -> void:
	var layout := ContentDB.get_layout("region_01_quiet_pond")
	var region := RegionRuntime.new()
	region.layout = layout
	var aim := region.cast_aim_for(1.0)
	region.free()
	var quick := aim.quick_cast_point(null)
	var map_zones: Array[HabitatZone] = []
	var map := HabitatMap.from_layout(layout, map_zones)
	assert_true(map.habitat_at(quick) != "", "the default cast must land on fishable water (%s)" % quick)
	var behind := aim.landing_for(aim.origin - aim.forward * 300.0)
	assert_true(rad_to_deg(absf(aim.forward.angle_to(behind - aim.origin))) <= CastAim.MAX_ANGLE_DEG + 0.01, "never backwards")
	for zone in map_zones:
		zone.free()

func test_cast_aim_turns_with_the_forward_direction() -> void:
	var aim := CastAim.new(Vector2(100, 100), 50.0, 200.0, 90.0)
	assert_true(aim.forward.distance_to(Vector2.RIGHT) < 0.001)
	assert_true(aim.landing_for(Vector2(100, 100)).x > 100.0, "a press on the rod aims straight ahead (right)")
	assert_true(aim.quick_cast_point(null).x > 100.0)

# --- full-screen panels fit the phone ---

func test_full_screen_panels_stay_inside_a_phone_screen() -> void:
	var previous := TranslationServer.get_locale()
	GameState.new_game()
	GameState.record_encounter("fish_crucian_carp", 12.0, "steady", "clear")
	for locale in ["ko", "en", "ja"]:
		TranslationServer.set_locale(locale)
		var host := Control.new()
		host.size = Vector2(720, 1280)
		host.theme = UiTheme.build(1.0, false, false)
		tree.root.add_child(host)
		var journal := JournalPanel.new()
		journal.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), "region_01_quiet_pond")
		var inspect := InspectPanel.new()
		var gear := GearPanel.new()
		gear.setup(LoadoutService.new(GameState))
		for panel in [journal, inspect, gear]:
			host.add_child(panel)
		journal.refresh()
		gear.select_tab("rod")
		inspect.show_catch({"fish_id": "fish_crucian_carp", "size_cm": 12.0, "region_id": "region_01_quiet_pond", "first_discovery": true})
		await tree.process_frame
		await tree.process_frame
		for panel in [journal, inspect, gear]:
			_assert_inside(panel, 720.0, "%s (%s)" % [panel.get_script().get_path().get_file(), locale])
		host.free()
	TranslationServer.set_locale(previous)
	GameState.new_game()

func test_a_notch_pushes_screens_and_overlays_down_together() -> void:
	var root := _start()
	root.ui.apply_insets(90.0, 60.0)
	root.ui._open(root.ui.map_panel)
	await tree.process_frame
	await tree.process_frame
	var status_bottom := root.ui.hud.top_bar.get_global_rect().end.y
	var title: Control = root.ui.map_panel.get_child(2)
	assert_true(title.get_global_rect().position.y >= status_bottom - 1.0,
		"the map title (%.0f) must start below the status bar (%.0f)" % [title.get_global_rect().position.y, status_bottom])
	root.ui.close_panel()
	root.ui.enter_water_mind()
	await tree.process_frame
	assert_true(root.ui.water_mind._badge.get_global_rect().position.y >= 90.0, "the water-mind badge clears the notch")
	_stop(root)

## Checks every visible control. Content that scrolls sideways is clipped by its ScrollContainer, so
## only the container has to fit; a container that only scrolls vertically must fit its content too.
func _assert_inside(node: Node, width: float, label: String) -> void:
	for child in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			var rect := (child as Control).get_global_rect()
			if rect.end.x > width + 1.0:
				fail("%s: %s ends at %.0f px, past the %.0f px screen" % [label, child.name, rect.end.x, width])
				return
		if not (child is ScrollContainer and (child as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED):
			_assert_inside(child, width, label)

## Content of a scroll area that scrolls only up and down must fit its width, or the right edge is cut.
func _assert_fits_scrolls(node: Node, label: String) -> void:
	for child in node.get_children():
		if child is ScrollContainer and (child as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			var scroll := child as ScrollContainer
			for content in scroll.get_children():
				if content is Control and not content is ScrollBar:
					var wanted := (content as Control).get_combined_minimum_size().x
					var room := scroll.size.x - (scroll.get_v_scroll_bar().size.x if scroll.get_v_scroll_bar().visible else 0.0)
					assert_true(wanted <= room + 1.0, "%s: %s needs %.0f px in a %.0f px scroll area" % [label, content.name, wanted, room])
		_assert_fits_scrolls(child, label)

func test_scrolling_pages_are_not_cut_at_the_right_edge() -> void:
	var previous := TranslationServer.get_locale()
	GameState.new_game()
	GameState.record_encounter("fish_crucian_carp", 12.0, "steady", "clear")
	for locale in ["ko", "en", "ja"]:
		TranslationServer.set_locale(locale)
		var host := Control.new()
		host.size = Vector2(720, 1280)
		host.theme = UiTheme.build(1.0, false, false)
		tree.root.add_child(host)
		var journal := JournalPanel.new()
		journal.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), "region_01_quiet_pond")
		var gear := GearPanel.new()
		gear.setup(LoadoutService.new(GameState))
		for panel in [journal, gear]:
			host.add_child(panel)
		journal.refresh()
		journal.select_fish("fish_crucian_carp")
		gear.select_tab("rod")
		await tree.process_frame
		await tree.process_frame
		for panel in [journal, gear]:
			_assert_fits_scrolls(panel, "%s (%s)" % [panel.get_script().get_path().get_file(), locale])
		host.free()
	TranslationServer.set_locale(previous)
	GameState.new_game()
