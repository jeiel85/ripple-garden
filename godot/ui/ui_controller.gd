class_name UIController
extends CanvasLayer

## Owns every screen and wires them to the game (TECH_SPEC §3): input becomes commands on
## the domain services, state changes arrive as EventBus events and refresh the views. Panels are
## shown one at a time in a modal host (no stacked popups).
##
## Layers, bottom to top: world input, HUD (side buttons, fishing row), fight meter, toast, modal host,
## the HUD's top and bottom bars, water-mind overlay, debug menu. The two bars sit above the modal host
## so a full-screen panel can keep them (D-018): the catch result, equipment, camp and map keep the
## status bar (`KEEPS_STATUS`), the journal keeps the navigation row (`KEEPS_NAV`). Small panels
## (settings, restoration) are centred over a dimmed scene and hide both.

var game: Dictionary = {}

var root: Control
var world_input: WorldInput
var hud: Hud
var fight_meter: FightMeter
var toast: Toast
var water_mind: WaterMindOverlay
var inspect_panel: InspectPanel
var journal_panel: JournalPanel
var gear_panel: GearPanel
var restoration_panel: RestorationPanel
var camp_panel: CampPanel
var map_panel: RegionMapPanel
var settings_panel: SettingsPanel
var licenses_panel: TextPanel
var debug_menu: DebugMenu = null

var _modal_host: Control
var _backdrop: ColorRect
var _modal_center: CenterContainer
var _modal_full: Control
var _chrome: Control
var _current_panel: Control = null
var _fishing: FishingController
var _region: RegionRuntime
var _restoration: RestorationService
var _hints: TutorialHints
var _camp: CampService
var _camera: CameraController
var _region_id := ""
## Set by "다시 낚시": cast again as soon as the released fish is gone.
var _recast_after_release := false

func _init() -> void:
	layer = 10

## `deps`: fishing, region, restoration, journal, loadout, camp, camera, hints, debug (nullable), region_id.
func setup(deps: Dictionary) -> void:
	game = deps
	_fishing = deps["fishing"]
	_region = deps["region"]
	_restoration = deps["restoration"]
	_hints = deps["hints"]
	_camp = deps["camp"]
	_camera = deps.get("camera")
	_region_id = deps["region_id"]

	root = Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hud = Hud.new()
	world_input = WorldInput.new()
	root.add_child(world_input)
	root.add_child(hud)
	# The meter sits just above the fishing row, so the pond and the bobber stay clear.
	fight_meter = FightMeter.new()
	fight_meter.visible = false
	fight_meter.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fight_meter.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fight_meter.offset_bottom = -300
	fight_meter.offset_top = -432
	fight_meter.offset_left = 40
	fight_meter.offset_right = -40
	root.add_child(fight_meter)

	# Toasts are drawn under the modal host: a message never covers an open screen.
	toast = Toast.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_bottom = -196  # just above the navigation row, like the mockups' tip pill
	root.add_child(toast)
	_build_modal_host()
	_chrome = Control.new()
	_chrome.name = "Chrome"
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_chrome)
	hud.remove_child(hud.top_bar)
	hud.remove_child(hud.bottom_bar)
	_chrome.add_child(hud.top_bar)
	_chrome.add_child(hud.bottom_bar)
	water_mind = WaterMindOverlay.new()
	water_mind.weather_choices = _region.weather.allowed_ids()
	root.add_child(water_mind)
	_build_panels(deps)

	hud.setup(_fishing, _region_id, _region.weather)
	world_input.setup(_fishing, _region, hud)
	hud.journal_pressed.connect(_on_journal_pressed)
	hud.gear_pressed.connect(open_gear)
	hud.restore_pressed.connect(func() -> void: _toggle(restoration_panel))
	hud.camp_pressed.connect(open_camp)
	hud.map_pressed.connect(func() -> void: _toggle(map_panel))
	hud.settings_pressed.connect(func() -> void: _toggle(settings_panel))
	hud.water_mind_pressed.connect(enter_water_mind)
	hud.cta_down.connect(_on_cta_down)
	hud.cta_up.connect(_on_cta_up)
	hud.cancel_pressed.connect(func() -> void: _fishing.cancel())
	water_mind.exited.connect(exit_water_mind)
	water_mind.message.connect(show_message)
	water_mind.photo_requested.connect(save_photo)
	water_mind.time_preview_changed.connect(_on_time_preview)
	water_mind.weather_preview_changed.connect(_on_weather_preview)

	_fishing.fight_updated.connect(fight_meter.update_values)
	_fishing.cast_rejected.connect(_on_cast_rejected)
	EventBus.fishing_state_changed.connect(_on_fishing_state_changed)
	EventBus.fish_escaped.connect(_on_fish_escaped)
	EventBus.fishing_cancelled.connect(func() -> void: show_message(tr("ui.toast.cancelled")))
	EventBus.fish_released.connect(_on_fish_released)
	EventBus.collection_changed.connect(func(_fish_id: String) -> void: _refresh_journal_notice())
	EventBus.region_restoration_changed.connect(func(_changed: String, _level: int) -> void: _refresh_camp_notice())
	EventBus.economy_changed.connect(func(_ripple: int, _memory: int) -> void: _refresh_camp_notice())
	EventBus.bait_ran_out.connect(func(bait_id: String, replacement_id: String) -> void:
		show_message(tr("ui.toast.bait_out") % [tr(ContentDB.get_bait(bait_id).get("name_key", "")), tr(ContentDB.get_bait(replacement_id).get("name_key", ""))]))
	EventBus.item_granted.connect(func(category: String, item_id: String) -> void:
		show_message(tr("ui.toast.gift") % tr(ContentDB.get_item(category, item_id).get("name_key", ""))))
	EventBus.region_restoration_points_changed.connect(func(_region_id_changed: String, _points: int) -> void: _refresh_restore_hint())
	EventBus.region_restoration_changed.connect(func(_region_id_changed: String, _level: int) -> void: _refresh_restore_hint())
	EventBus.save_recovered.connect(func(_source: String) -> void: show_message(tr("ui.save.recovered")))
	EventBus.save_failed.connect(func(_text: String) -> void: show_message(tr("ui.save.failed")))
	EventBus.settings_changed.connect(_on_setting_changed)
	EventBus.game_state_replaced.connect(_on_state_replaced)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_theme()
	_refresh_restore_hint()
	_refresh_journal_notice()
	_refresh_camp_notice()
	_show_first_hint()

func _build_modal_host() -> void:
	_modal_host = Control.new()
	_modal_host.name = "ModalHost"
	_modal_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_host.visible = false
	root.add_child(_modal_host)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_host.add_child(_backdrop)
	_modal_center = CenterContainer.new()
	_modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_host.add_child(_modal_center)
	_modal_full = Control.new()
	_modal_full.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_host.add_child(_modal_full)

func _build_panels(deps: Dictionary) -> void:
	inspect_panel = InspectPanel.new()
	inspect_panel.release_pressed.connect(func() -> void: _fishing.release_catch())
	inspect_panel.journal_pressed.connect(record_catch)
	inspect_panel.fish_again_pressed.connect(fish_again)
	journal_panel = JournalPanel.new()
	journal_panel.setup(deps["journal"], _region_id)
	journal_panel.close_pressed.connect(close_panel)
	gear_panel = GearPanel.new()
	gear_panel.setup(deps["loadout"])
	gear_panel.close_pressed.connect(close_panel)
	gear_panel.message.connect(show_message)
	restoration_panel = RestorationPanel.new()
	restoration_panel.setup(_restoration, _region_id)
	restoration_panel.close_pressed.connect(close_panel)
	restoration_panel.confirmed.connect(_on_restore_confirmed)
	camp_panel = CampPanel.new()
	camp_panel.setup(_camp, deps["loadout"], _region_id)
	camp_panel.close_pressed.connect(close_panel)
	map_panel = RegionMapPanel.new()
	map_panel.setup(RegionUnlocks.new(GameState), _region_id)
	map_panel.close_pressed.connect(close_panel)
	settings_panel = SettingsPanel.new()
	settings_panel.close_pressed.connect(close_panel)
	settings_panel.message.connect(show_message)
	settings_panel.licenses_pressed.connect(func() -> void:
		licenses_panel.show_text(tr("ui.support.licenses"), TextPanel.licenses_text())
		_open(licenses_panel))
	licenses_panel = TextPanel.new()
	licenses_panel.close_pressed.connect(func() -> void: _open(settings_panel))
	if deps.get("debug") != null:
		debug_menu = DebugMenu.new()
		debug_menu.setup(deps["debug"], _region_id)
		debug_menu.close_pressed.connect(close_panel)
		debug_menu.message.connect(show_message)

# --- panels ---

## Width a modal panel may take: its design width, but never more than the screen minus a margin
## (a narrow phone must not push the panel's edge off screen).
static func fit_width(design_width: float, available_width: float) -> float:
	return minf(design_width, available_width - 48.0)

## A layout constant a panel script declares (FULLSCREEN, KEEPS_STATUS, KEEPS_NAV); false if absent.
static func panel_flag(panel: Control, flag: String) -> bool:
	return script_constant(panel, flag) == true

static func script_constant(panel: Control, constant: String) -> Variant:
	var script := panel.get_script() as Script
	return script.get_script_constant_map().get(constant) if script != null else null

func _open(panel: Control) -> void:
	if water_mind.active:
		return
	var fullscreen := panel_flag(panel, "FULLSCREEN")
	if not fullscreen:
		if not panel.has_meta("design_width"):
			panel.set_meta("design_width", panel.custom_minimum_size.x)
		panel.custom_minimum_size.x = fit_width(float(panel.get_meta("design_width")), get_viewport().get_visible_rect().size.x)
	if _current_panel != null:
		if _current_panel == camp_panel and panel != camp_panel and _camera != null:
			_camera.clear_focus()  # the camp gave way to another screen: the world zooms back out
		_current_panel.get_parent().remove_child(_current_panel)
	_current_panel = panel
	(_modal_full if fullscreen else _modal_center).add_child(panel)
	_set_backdrop(fullscreen)
	_backdrop.visible = not (script_constant(panel, "BACKDROP") == "none")
	if panel.has_method("refresh"):
		panel.refresh()
	_modal_host.visible = true
	hud.visible = false
	hud.allow_top = panel_flag(panel, "KEEPS_STATUS")
	hud.allow_bottom = panel_flag(panel, "KEEPS_NAV")
	hud.apply_visibility()
	world_input.enabled = false

func _set_backdrop(fullscreen: bool) -> void:
	if fullscreen:
		var material := ShaderMaterial.new()
		material.shader = load("res://ui/backdrop.gdshader")
		_backdrop.material = material
		_backdrop.color = Color.WHITE
	else:
		_backdrop.material = null
		_backdrop.color = Color(0.1, 0.07, 0.03, 0.5)

## Opens `panel`, or closes it when it is already the open one (the navigation buttons toggle).
func _toggle(panel: Control) -> void:
	if _current_panel == panel:
		close_panel()
	else:
		_open(panel)

func close_panel() -> void:
	if _current_panel == camp_panel and _camera != null:
		_camera.clear_focus()
	if _current_panel != null:
		_current_panel.get_parent().remove_child(_current_panel)
		_current_panel = null
	_modal_host.visible = false
	hud.visible = not water_mind.active
	hud.allow_top = not water_mind.active
	hud.allow_bottom = not water_mind.active
	hud.apply_visibility()
	hud.wake()
	world_input.enabled = not water_mind.active
	# The inspect screen is part of the fishing flow: closing a side panel returns to it.
	if _fishing.state == FishingController.State.INSPECT:
		_show_inspect()

func is_panel_open() -> bool:
	return _current_panel != null

func current_panel() -> Control:
	return _current_panel

func open_journal(fish_id: String = "") -> void:
	if not fish_id.is_empty():
		journal_panel.preselect(fish_id)  # before opening: the opening refresh must land on this fish
	_open(journal_panel)

func _on_journal_pressed() -> void:
	if _current_panel == journal_panel:
		close_panel()
	else:
		open_journal()

## Opens the camp screen: the camera moves in on the clearing and what is new there counts as seen.
func open_camp() -> void:
	if _current_panel == camp_panel:
		close_panel()
		return
	_open(camp_panel)
	if _current_panel != camp_panel:
		return
	var focus: Dictionary = ContentDB.get_layout(_region_id).get("camp_focus", {})
	if _camera != null and not focus.is_empty():
		_camera.focus_on(Vector2(float(focus["x"]), float(focus["y"])), float(focus["zoom"]))
	_camp.mark_seen()
	_refresh_camp_notice()

func _refresh_camp_notice() -> void:
	hud.set_camp_notice(_camp.has_news())

## Opens the equipment screen on the rods tab with the equipped rod chosen.
func open_gear() -> void:
	if _current_panel == gear_panel:
		close_panel()
		return
	_open(gear_panel)
	gear_panel.select_tab("rod")

func open_restoration() -> void:
	_open(restoration_panel)

func _show_inspect() -> void:
	var pending := GameState.get_pending_catch()
	if pending.is_empty():
		return
	_open(inspect_panel)
	# The hint is part of the panel: a toast would be drawn behind the panel and never be read.
	inspect_panel.show_catch(pending, tr("ui.hint.release") if _hints.take("hint_release") else "")

func toggle_debug_menu() -> void:
	if debug_menu == null:
		return
	if _current_panel == debug_menu:
		close_panel()
	else:
		_open(debug_menu)

# --- fishing flow ---

func _on_cta_down() -> void:
	# The fishing button stays on screen under the journal: it leaves the journal and casts.
	if _current_panel != null and _fishing.state in [FishingController.State.READY, FishingController.State.AIM]:
		close_panel()
	match _fishing.state:
		FishingController.State.READY, FishingController.State.AIM:
			world_input.cast_quick()
		FishingController.State.BITE_HINT, FishingController.State.HOOK:
			_fishing.tap()
		FishingController.State.FIGHT:
			_fishing.set_reeling(true)

func _on_cta_up() -> void:
	if _fishing.state == FishingController.State.FIGHT:
		_fishing.set_reeling(false)

## "기록": the catch is already in the journal (D-010); let the fish go and open its page. Like the other
## two actions it releases, so nothing is left pending behind the journal.
func record_catch() -> void:
	var fish_id: String = GameState.get_pending_catch().get("fish_id", "")
	if _fishing.release_catch() and not fish_id.is_empty():
		open_journal(fish_id)

## "다시 낚시": let the fish go and cast again at the same spot as soon as it is back in the water.
func fish_again() -> void:
	if _fishing.release_catch():
		_recast_after_release = true

func _on_fishing_state_changed(_previous: String, current: String) -> void:
	# Messages sit above whatever occupies the bottom: the navigation row, or the meter and reel button.
	toast.offset_bottom = -470.0 if current in Hud.FISHING_STATES else -196.0
	var fighting := current == "fight"
	fight_meter.visible = fighting  # the meter means nothing before the fish is hooked
	if fighting:
		var band: Dictionary = ContentDB.balance["fishing"]["fight"]["band"]
		fight_meter.configure(float(band["min"]), float(band["max"]), GameState.get_setting("high_contrast_meter") == true)
		fight_meter.update_values(0.5, _fishing.fight.progress if _fishing.fight != null else 0.0)
		_hint_once("hint_reel", "ui.hint.reel")
	elif current == "bite_hint":
		# A look opened while waiting (journal, settings, map) gives way to the bite, so it can still be hooked.
		if _current_panel in [journal_panel, settings_panel, map_panel]:
			close_panel()
		_hint_once("hint_hook", "ui.hint.hook")
	elif current == "inspect":
		_show_inspect()
	if current == "ready" and _current_panel == inspect_panel:
		close_panel()
	if current == "ready" and _recast_after_release:
		_recast_after_release = false
		if _current_panel == null and not water_mind.active:
			world_input.cast_quick()

func _on_cast_rejected(reason: String) -> void:
	show_message(tr("ui.toast.no_fish_here") if reason == "no_fish_here" else "")

func _on_fish_escaped(_fish_id: String, _reason: String) -> void:
	show_message(tr("ui.toast.escaped"))
	show_message(tr("ui.toast.escaped_retry"))

func _on_fish_released(fish_id: String, _region: String, _size_cm: float) -> void:
	if _current_panel == inspect_panel:
		close_panel()
	var reward := _fishing.last_reward
	var name_text := tr(ContentDB.get_fish(fish_id).get("name_key", ""))
	show_message(tr("ui.toast.released") % name_text)
	if reward != null:
		var parts: Array[String] = [tr("ui.toast.ripple") % reward.ripple]
		if reward.memory > 0:
			parts.append(tr("ui.toast.memory") % reward.memory)
		show_message("  ·  ".join(parts))

func _on_restore_confirmed() -> void:
	if _restoration.restore(_region_id):
		close_panel()
		show_message(tr("ui.restore.done"))

func _refresh_restore_hint() -> void:
	hud.set_restore_ready(_restoration.can_restore(_region_id))

func _refresh_journal_notice() -> void:
	hud.set_journal_notice(GameState.has_unseen_journal_entries())

func _on_state_replaced() -> void:
	_apply_theme()
	hud.refresh_currency()
	_refresh_restore_hint()
	_refresh_journal_notice()

# --- hints (Tutorial Hints setting) ---

func _show_first_hint() -> void:
	_hint_once("hint_cast", "ui.hint.cast")

func _hint_once(event_id: String, key: String) -> void:
	if _hints.take(event_id):
		show_message(tr(key))

func show_message(text: String) -> void:
	toast.show_message(text)

# --- water-mind ---

func enter_water_mind() -> void:
	# A fish in hand (landing, inspecting, releasing) is finished first; the screen is not left behind.
	if _fishing.state in [FishingController.State.LAND, FishingController.State.INSPECT, FishingController.State.RELEASE]:
		return
	# A line left out would bite and escape while nothing can be done about it: reel it in quietly.
	_fishing.cancel()
	if _current_panel != null:
		close_panel()
	hud.visible = false
	hud.allow_top = false
	hud.allow_bottom = false
	hud.apply_visibility()
	fight_meter.visible = false
	world_input.enabled = false
	water_mind.enter()

func exit_water_mind() -> void:
	hud.visible = true
	hud.allow_top = true
	hud.allow_bottom = true
	hud.apply_visibility()
	hud.wake()
	world_input.enabled = true
	if _fishing.state == FishingController.State.INSPECT:
		_show_inspect()  # a catch that arrived while the screen was hidden

func _on_time_preview(band: String) -> void:
	if band.is_empty():
		_region.environment.hours_provider = Callable()
	else:
		var hour := preview_hour(band)
		_region.environment.hours_provider = func() -> float: return hour
	_region.environment.refresh_lighting()

func _on_weather_preview(weather_id: String) -> void:
	if weather_id.is_empty():
		_region.weather.clear_preview()
	else:
		_region.weather.set_preview(weather_id)
	_region.environment.refresh_lighting()

## A representative hour inside a time band (the middle of it), from balance.json's band starts.
static func preview_hour(band: String) -> float:
	var starts: Dictionary = ContentDB.balance.get("time", {}).get("band_starts_hour", TimeService.FALLBACK_BAND_STARTS)
	var order := TimeService.TIME_BANDS
	var index := order.find(band)
	if index < 0:
		return 12.0
	var start := float(starts.get(band, 12.0))
	var next := float(starts.get(order[(index + 1) % order.size()], start + 3.0))
	if next <= start:
		next += 24.0
	return fposmod((start + next) / 2.0, 24.0)

## Saves a picture of the scene without the overlay (water-mind "저장").
func save_photo() -> void:
	var hidden := hide_for_photo()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	restore_after_photo(hidden)
	var path := PhotoSaver.save(image)
	show_message(tr("ui.photo.saved") % path if not path.is_empty() else tr("ui.photo.failed"))

## Hides the overlay and any message for the one captured frame; returns what to bring back.
func hide_for_photo() -> Dictionary:
	var shown := {"chrome": water_mind.is_chrome_visible(), "toast": toast.visible}
	water_mind.hide_chrome()
	toast.visible = false
	return shown

func restore_after_photo(shown: Dictionary) -> void:
	toast.visible = shown.get("toast", false)
	if shown.get("chrome", false):
		water_mind.show_chrome()

# --- settings: theme, layout ---

func _on_setting_changed(key: String) -> void:
	match key:
		"text_scale", "large_ui", "high_contrast_meter":
			_apply_theme()
		"reduced_motion":
			_apply_motion()

func _apply_theme() -> void:
	root.theme = UiTheme.build(
		float(GameState.get_setting("text_scale")),
		GameState.get_setting("large_ui") == true,
		GameState.get_setting("high_contrast_meter") == true)
	fight_meter.configure(fight_meter.band_min, fight_meter.band_max, GameState.get_setting("high_contrast_meter") == true)
	_apply_motion()
	_apply_layout()

func _apply_motion() -> void:
	var reduced: bool = GameState.get_setting("reduced_motion") == true
	hud.reduced_motion = reduced
	toast.reduced_motion = reduced
	water_mind.reduced_motion = reduced

## Top and bottom insets (design pixels) for a notch or gesture bar. `safe` is the usable area in screen
## pixels. Only mobile screens report meaningful insets: on a desktop the rectangle can be offset by other
## monitors or the taskbar, which would push the top bar off screen, so desktop gets none.
static func safe_insets(safe: Rect2i, screen: Vector2i, window_height: float, mobile: bool) -> Vector2:
	if not mobile or screen.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var scale := window_height / float(screen.y)
	return Vector2(maxf(0.0, float(safe.position.y)) * scale, maxf(0.0, float(screen.y - safe.end.y)) * scale)

func _apply_layout() -> void:
	var insets := safe_insets(DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size(),
		get_viewport().get_visible_rect().size.y, OS.has_feature("mobile"))
	hud.apply_layout(insets.x, insets.y, UiTheme.touch_min(GameState.get_setting("large_ui") == true))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_debug_menu()

func _input(event: InputEvent) -> void:
	# A key wakes a faded HUD. Touches are handled by WorldInput, which consumes the waking press so
	# that bringing the HUD back never casts a line by accident.
	if event is InputEventKey and event.pressed:
		hud.wake()
