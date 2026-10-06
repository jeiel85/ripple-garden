extends TestCase

## The assembled game scene: the world builds from data, the UI drives the fishing loop, settings reach
## the engine, and playing does not grow the node tree. Runs the real scene headless on the autoload
## GameState (reset afterwards) with saving blocked, so the player's save is never touched.

const SCENE := "res://world/game_root.tscn"

var _was_blocked := false

func _start(fresh_game: bool = true) -> GameRoot:
	if fresh_game:
		GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	_was_blocked = save_service.write_blocked
	save_service.write_blocked = true
	var packed: PackedScene = load(SCENE)
	var root: GameRoot = packed.instantiate()
	root.load_save = false
	tree.root.add_child(root)
	return root

func _stop(root: GameRoot) -> void:
	root.free()
	GameState.new_game()
	for bus_name in SettingsApplier.VOLUME_BUSES.values():
		AudioService.set_bus_volume_linear(bus_name, 1.0)
	tree.root.get_node("SaveService").write_blocked = _was_blocked
	Engine.max_fps = 0

func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

## Plays one whole fishing attempt through the controller like an attentive player.
func _play_attempt(root: GameRoot, seed_value: int) -> void:
	var fishing := root.fishing
	fishing.set_seed(seed_value)
	assert_true(root.ui.world_input.cast_quick(), "cast refused")
	var elapsed := 0.0
	while elapsed < 240.0:
		match fishing.state:
			FishingController.State.HOOK:
				fishing.tap()
			FishingController.State.FIGHT:
				fishing.set_reeling(fishing.fight.tension < 0.5)
			FishingController.State.INSPECT:
				root.ui.inspect_panel.release_pressed.emit()
			FishingController.State.READY:
				if elapsed > 0.0:
					return
		fishing.advance(1.0 / 30.0)
		elapsed += 1.0 / 30.0
	fail("the attempt never finished")

func test_the_scene_builds_the_region_from_data() -> void:
	var root := _start()
	assert_eq(root.region_id, "region_01_quiet_pond")
	assert_not_null(root.region.habitat_map)
	assert_eq(root.region.zones_root.get_child_count(), ContentDB.get_layout(root.region_id)["zones"].size())
	assert_eq(root.region.weather.current_id, "clear")
	assert_true(root.region.props.visible_props(0).size() > 0)
	assert_not_null(root.ui.hud)
	assert_eq(root.fishing.region_id, root.region_id)
	_stop(root)

func test_a_whole_fishing_loop_through_the_ui_updates_the_world() -> void:
	var root := _start()
	_play_attempt(root, 12)
	assert_eq(root.fishing.state, FishingController.State.READY)
	assert_eq(GameState.discovered_count(), 1)
	var species := GameState.get_species_population(root.region_id)
	assert_eq(species.size(), 1)
	root.region.fish_presenter.refresh()
	assert_eq(root.region.fish_presenter.agent_count(), 1, "the released fish must appear in the pond")
	assert_true(GameState.get_ripple() > 0)
	assert_false(root.ui.is_panel_open(), "the inspect screen must close after releasing")
	assert_true(root.ui.toast.is_showing(), "releasing should leave a quiet message")
	_stop(root)

func test_inspect_screen_opens_on_landing_and_blocks_world_input() -> void:
	var root := _start()
	root.fishing.spawn_fish("fish_crucian_carp")
	root.ui.world_input.cast_quick()
	var elapsed := 0.0
	while root.fishing.state != FishingController.State.INSPECT and elapsed < 240.0:
		if root.fishing.state == FishingController.State.HOOK:
			root.fishing.tap()
		if root.fishing.state == FishingController.State.FIGHT:
			root.fishing.set_reeling(root.fishing.fight.tension < 0.5)
		root.fishing.advance(1.0 / 30.0)
		elapsed += 1.0 / 30.0
	assert_eq(root.fishing.state, FishingController.State.INSPECT)
	assert_eq(root.ui.current_panel(), root.ui.inspect_panel)
	assert_false(root.ui.world_input.enabled)
	assert_false(root.ui.hud.visible)
	root.ui.inspect_panel.journal_pressed.emit()
	assert_eq(root.ui.current_panel(), root.ui.journal_panel)
	root.ui.close_panel()
	assert_eq(root.ui.current_panel(), root.ui.inspect_panel, "closing the journal returns to the catch")
	root.ui.inspect_panel.release_pressed.emit()
	assert_false(root.ui.is_panel_open())
	_stop(root)

func test_playing_many_attempts_does_not_grow_the_node_tree() -> void:
	var root := _start()
	_play_attempt(root, 1)
	root.region.fish_presenter.refresh()
	var baseline := _count_nodes(root)
	for attempt in 8:
		_play_attempt(root, 100 + attempt)
		root.region.fish_presenter.refresh()
	var after := _count_nodes(root)
	# A few new species may add pooled fish (bounded by the quality budget); nothing else may grow.
	var fish_nodes := root.region.fish_presenter.agent_count() + root.region.fish_presenter.pool_size()
	assert_true(after - baseline <= fish_nodes * 2 + 8, "node count grew from %d to %d" % [baseline, after])
	_stop(root)

func test_restoration_flow_changes_the_world() -> void:
	var root := _start()
	GameState.add_restoration_points(root.region_id, 60)
	assert_true(root.restoration.can_restore(root.region_id))
	assert_eq(root.region.environment.level, 0)
	root.ui.open_restoration()
	assert_eq(root.ui.current_panel(), root.ui.restoration_panel)
	root.ui.restoration_panel.confirmed.emit()
	assert_eq(GameState.get_restoration_level(root.region_id), 1)
	assert_eq(root.region.environment.level, 1, "the world must show the new level")
	assert_false(root.ui.is_panel_open())
	_stop(root)

func test_restoration_never_exceeds_the_slice_cap() -> void:
	var root := _start()
	GameState.add_restoration_points(root.region_id, 100000)
	for i in 12:
		root.restoration.restore(root.region_id)
	assert_eq(GameState.get_restoration_level(root.region_id), int(ContentDB.balance["vertical_slice"]["max_restoration_level"]))
	_stop(root)

func test_settings_reach_the_engine_and_the_presenters() -> void:
	var root := _start()
	GameState.set_setting("volume_water", 0.3)
	assert_true(absf(AudioService.get_bus_volume_linear("Water") - 0.3) < 0.01)
	GameState.set_setting("volume_water", 1.0)

	GameState.set_setting("fps_cap", 60)
	assert_eq(Engine.max_fps, 60)
	GameState.set_setting("battery_saver", true)
	assert_eq(Engine.max_fps, 30, "Battery Saver forces 30 fps")
	GameState.set_setting("battery_saver", false)
	assert_eq(Engine.max_fps, 60)

	GameState.set_setting("reduced_motion", true)
	assert_true(root.camera.reduced_motion)
	assert_true(root.region.fishing_view.reduced_motion)
	assert_true(root.ui.toast.reduced_motion)
	GameState.set_setting("camera_shake", false)
	assert_false(root.camera.shake_enabled)
	GameState.set_setting("visual_bite_cue", true)
	assert_true(root.region.fishing_view.visual_bite_cue)

	GameState.set_setting("quality", "low")
	var low_rain: int = root.region.weather_presenter._rain.amount
	GameState.set_setting("quality", "high")
	assert_true(root.region.weather_presenter._rain.amount > low_rain)
	GameState.set_setting("battery_saver", true)
	var saver_rain: int = root.region.weather_presenter._rain.amount
	assert_true(saver_rain < 320, "Battery Saver must reduce rain (%d)" % saver_rain)
	_stop(root)

func test_text_scale_and_large_ui_rebuild_the_theme() -> void:
	var root := _start()
	var before: int = root.ui.root.theme.default_font_size
	GameState.set_setting("text_scale", 1.5)
	assert_true(root.ui.root.theme.default_font_size > before)
	var scaled: int = root.ui.root.theme.default_font_size
	GameState.set_setting("large_ui", true)
	assert_true(root.ui.root.theme.default_font_size > scaled)
	assert_true(root.ui.hud.cta_button.custom_minimum_size.y >= UiTheme.TOUCH_MIN_LARGE_PX, "touch targets must grow with Large UI")
	_stop(root)

func test_every_hud_button_meets_the_touch_target_size() -> void:
	var root := _start()
	for button in [root.ui.hud.journal_button, root.ui.hud.gear_button, root.ui.hud.restore_button,
			root.ui.hud.settings_button, root.ui.hud.water_mind_button, root.ui.hud.cta_button]:
		assert_true(button.custom_minimum_size.y >= UiTheme.TOUCH_MIN_PX, "%s is too small to tap" % button.text)
	_stop(root)

func test_hud_fades_when_idle_and_the_waking_touch_does_not_cast() -> void:
	var root := _start()
	var hud: Hud = root.ui.hud
	hud.reduced_motion = true
	hud._process(Hud.IDLE_FADE_SEC + 0.1)
	assert_true(hud.is_faded())
	assert_false(hud.bottom_bar.visible, "invisible buttons would still catch touches")
	var landing_before: Variant = root.ui.world_input.last_landing
	root.ui.world_input._on_press(Vector2(360, 700))
	assert_false(hud.is_faded(), "a touch must bring the HUD back")
	assert_eq(root.fishing.state, FishingController.State.READY, "the waking touch must not start aiming")
	assert_eq(root.ui.world_input.last_landing, landing_before)
	_stop(root)

func test_hud_does_not_fade_during_fishing() -> void:
	var root := _start()
	root.ui.world_input.cast_quick()
	root.ui.hud._process(Hud.IDLE_FADE_SEC * 3.0)
	assert_false(root.ui.hud.is_faded(), "the fishing button must stay available while a line is out")
	_stop(root)

func test_aiming_on_land_shows_an_invalid_ring_and_casting_is_refused_gently() -> void:
	var root := _start()
	var rejected: Array = []
	root.fishing.cast_rejected.connect(func(reason: String) -> void: rejected.append(reason))
	root.ui.world_input._on_press(Vector2(360, 1000))
	root.ui.world_input._on_release(Vector2(60, 1150))  # far left and low: not water
	assert_eq(root.fishing.state, FishingController.State.READY)
	assert_deep_eq(rejected, ["no_fish_here"])
	_stop(root)

func test_water_mind_hides_the_hud_and_dims_after_the_configured_time() -> void:
	var root := _start()
	GameState.set_setting("reduced_motion", true)
	GameState.set_setting("water_mind_dim_minutes", 1)
	var changes: Array = []
	var handler := func(active: bool) -> void: changes.append(active)
	EventBus.water_mind_changed.connect(handler)
	root.ui.enter_water_mind()
	assert_true(root.ui.water_mind.active)
	assert_false(root.ui.hud.visible)
	assert_false(root.ui.world_input.enabled)
	assert_false(root.ui.water_mind.is_dimmed())
	root.ui.water_mind._process(30.0)
	assert_false(root.ui.water_mind.is_dimmed())
	root.ui.water_mind._process(31.0)
	assert_true(root.ui.water_mind.is_dimmed(), "the picture should dim after the idle time")
	root.ui.water_mind._touched()
	assert_false(root.ui.water_mind.is_dimmed(), "a touch undims")
	root.ui.water_mind.exit()
	assert_true(root.ui.hud.visible)
	assert_true(root.ui.world_input.enabled)
	EventBus.water_mind_changed.disconnect(handler)
	assert_deep_eq(changes, [true, false])
	_stop(root)

func test_water_mind_battery_hint_is_shown_once() -> void:
	var root := _start()
	root.ui.enter_water_mind()
	assert_eq(GameState.get_setting("battery_saver_hint_seen"), true)
	var queued_first: int = root.ui.toast.pending_count()
	root.ui.water_mind.exit()
	root.ui.enter_water_mind()
	assert_true(root.ui.toast.pending_count() <= queued_first, "the battery hint must not repeat")
	_stop(root)

func test_water_mind_mixer_changes_the_volume_settings() -> void:
	var root := _start()
	root.ui.enter_water_mind()
	var slider: HSlider = root.ui.water_mind._sliders["volume_wind"]
	slider.value = 0.25
	assert_eq(GameState.get_setting("volume_wind"), 0.25)
	assert_true(absf(AudioService.get_bus_volume_linear("Wind") - 0.25) < 0.01)
	GameState.set_setting("volume_wind", 0.6)
	_stop(root)

func test_tutorial_hints_show_once_and_can_be_turned_off() -> void:
	var root := _start()
	assert_true(GameState.has_seen_event(root.region_id, "hint_cast"), "the first hint is shown at the start")
	_stop(root)
	GameState.new_game()
	GameState.set_setting("tutorial_hints", false)
	root = _start(false)
	assert_false(GameState.has_seen_event(root.region_id, "hint_cast"), "hints off must show nothing")
	_stop(root)

func test_debug_menu_exists_in_debug_builds_and_toggles() -> void:
	var root := _start()
	if BuildProfile.debug_tools_enabled():
		assert_not_null(root.ui.debug_menu)
		root.ui.toggle_debug_menu()
		assert_eq(root.ui.current_panel(), root.ui.debug_menu)
		root.ui.toggle_debug_menu()
		assert_false(root.ui.is_panel_open())
	else:
		assert_eq(root.ui.debug_menu, null, "release builds must not even create the debug menu")
	_stop(root)

func test_resuming_with_a_pending_catch_goes_straight_to_inspect() -> void:
	GameState.new_game()
	GameState.record_encounter("fish_minnow", 14.0, "heavy")
	GameState.set_pending_catch({"fish_id": "fish_minnow", "size_cm": 14.0, "region_id": "region_01_quiet_pond",
		"rarity": 1, "first_discovery": true})
	var root := _start(false)
	assert_eq(root.fishing.state, FishingController.State.INSPECT)
	assert_eq(root.ui.current_panel(), root.ui.inspect_panel)
	_stop(root)

func test_the_hud_lays_out_without_squashed_buttons_in_korean_and_english() -> void:
	var previous := TranslationServer.get_locale()
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		var root := _start()
		await tree.process_frame
		await tree.process_frame
		var hud: Hud = root.ui.hud
		var screen_width: float = tree.root.get_visible_rect().size.x
		for button in [hud.journal_button, hud.gear_button, hud.restore_button, hud.settings_button, hud.water_mind_button, hud.cta_button]:
			assert_true(button.size.x >= UiTheme.TOUCH_MIN_PX - 1.0, "%s (%s) is only %.0f px wide" % [button.text, locale, button.size.x])
			assert_true(button.size.y >= UiTheme.TOUCH_MIN_PX - 1.0, "%s (%s) is only %.0f px tall" % [button.text, locale, button.size.y])
			assert_true(button.get_global_rect().end.x <= screen_width + 1.0, "%s (%s) runs off the right edge" % [button.text, locale])
		assert_true(hud.status_pill.get_global_rect().end.x <= hud.currency_pill.get_global_rect().position.x + 1.0,
			"the status pill must stay left of the currencies (%s)" % locale)
		assert_true(hud.currency_pill.get_global_rect().end.x <= hud.settings_button.get_global_rect().position.x + 1.0,
			"the currencies must stay left of the settings button (%s)" % locale)
		assert_true(hud.currency_pill.get_global_rect().end.x <= screen_width + 1.0, "the top row runs off the screen (%s)" % locale)
		# Single-line buttons must not be wrapped letter by letter.
		for button in [hud.journal_button, hud.settings_button, hud.water_mind_button]:
			assert_true(button.size.y < UiTheme.TOUCH_MIN_PX * 1.8, "%s (%s) wraps into a tall pill" % [button.text, locale])
		_stop(root)
	TranslationServer.set_locale(previous)

func test_only_a_snapped_line_shakes_the_camera() -> void:
	var root := _start()
	root.camera.offset = Vector2.ZERO
	EventBus.fish_escaped.emit("fish_minnow", "missed_hook")
	EventBus.fish_escaped.emit("fish_minnow", "line_slack")
	assert_false(root.camera._shake_tween != null and root.camera._shake_tween.is_valid(), "gentle failures must not shake the screen")
	EventBus.fish_escaped.emit("fish_minnow", "line_snapped")
	assert_true(root.camera._shake_tween != null and root.camera._shake_tween.is_valid(), "a snapped line should jolt the camera")
	GameState.set_setting("camera_shake", false)
	root.camera._shake_tween = null
	EventBus.fish_escaped.emit("fish_minnow", "line_snapped")
	assert_true(root.camera._shake_tween == null, "Camera Shake off must be honoured")
	_stop(root)

func _toast_texts(root: GameRoot) -> Array:
	var texts: Array = root.ui.toast._queue.duplicate()
	texts.append(root.ui.toast._label.text)
	return texts

func test_the_release_toast_reports_this_catchs_own_reward_every_time() -> void:
	var root := _start()
	for attempt in 2:
		root.ui.toast._queue.clear()
		root.ui.toast._label.text = ""
		_play_attempt(root, 30 + attempt)
		var reward := root.fishing.last_reward
		assert_not_null(reward, "attempt %d paid nothing" % attempt)
		var expected := String(TranslationServer.translate("ui.toast.ripple")) % reward.ripple
		var shown := "\n".join(_toast_texts(root))
		assert_true(shown.contains(expected), "attempt %d: expected '%s' in %s" % [attempt, expected, _toast_texts(root)])
		if reward.memory > 0:
			assert_true(shown.contains(String(TranslationServer.translate("ui.toast.memory")) % reward.memory), "attempt %d: memory missing" % attempt)
	_stop(root)

func test_the_release_hint_is_inside_the_inspect_panel_and_shown_once() -> void:
	var root := _start()
	root.fishing.spawn_fish("fish_crucian_carp")
	root.ui.world_input.cast_quick()
	var elapsed := 0.0
	while root.fishing.state != FishingController.State.INSPECT and elapsed < 240.0:
		if root.fishing.state == FishingController.State.HOOK:
			root.fishing.tap()
		if root.fishing.state == FishingController.State.FIGHT:
			root.fishing.set_reeling(root.fishing.fight.tension < 0.5)
		root.fishing.advance(1.0 / 30.0)
		elapsed += 1.0 / 30.0
	assert_true(root.ui.inspect_panel._hint.visible, "the first inspect screen explains releasing")
	assert_false(root.ui.inspect_panel._hint.text.is_empty())
	root.ui.inspect_panel.release_pressed.emit()
	assert_false(root.ui.inspect_panel._hint.visible and root.ui.inspect_panel._hint.text.is_empty())
	root.ui.inspect_panel.show_catch({"fish_id": "fish_minnow", "size_cm": 10.0, "first_discovery": false})
	assert_false(root.ui.inspect_panel._hint.visible, "no hint without text")
	_stop(root)

func test_entering_water_mind_reels_in_a_line_that_is_out() -> void:
	var root := _start()
	root.ui.world_input.cast_quick()
	assert_eq(root.fishing.state, FishingController.State.CAST)
	root.ui.enter_water_mind()
	assert_true(root.ui.water_mind.active)
	assert_eq(root.fishing.state, FishingController.State.READY, "nothing may bite while the screen is hidden")
	root.fishing.advance(60.0)
	assert_eq(root.fishing.state, FishingController.State.READY)
	_stop(root)

func test_water_mind_waits_while_a_catch_is_in_hand() -> void:
	var root := _start()
	root.fishing.spawn_fish("fish_crucian_carp")
	root.ui.world_input.cast_quick()
	var elapsed := 0.0
	while root.fishing.state != FishingController.State.LAND and elapsed < 240.0:
		if root.fishing.state == FishingController.State.HOOK:
			root.fishing.tap()
		if root.fishing.state == FishingController.State.FIGHT:
			root.fishing.set_reeling(root.fishing.fight.tension < 0.5)
		root.fishing.advance(1.0 / 30.0)
		elapsed += 1.0 / 30.0
	assert_eq(root.fishing.state, FishingController.State.LAND)
	root.ui.enter_water_mind()
	assert_false(root.ui.water_mind.active, "a landed fish must be inspected and released first")
	root.fishing.advance(5.0)
	assert_eq(root.fishing.state, FishingController.State.INSPECT)
	assert_eq(root.ui.current_panel(), root.ui.inspect_panel, "and its screen must be there")
	_stop(root)

func test_leaving_water_mind_brings_back_a_catch_that_arrived_meanwhile() -> void:
	var root := _start()
	root.ui.enter_water_mind()
	GameState.set_pending_catch({"fish_id": "fish_minnow", "size_cm": 12.0, "region_id": root.region_id, "rarity": 1, "first_discovery": true})
	assert_true(root.fishing.resume_pending_catch())
	assert_false(root.ui.is_panel_open(), "nothing opens over water-mind")
	root.ui.water_mind.exit()
	assert_eq(root.ui.current_panel(), root.ui.inspect_panel)
	_stop(root)
