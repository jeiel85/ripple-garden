class_name UIController
extends CanvasLayer

## Owns every screen and wires them to the game (TECH_SPEC §3): input becomes commands on
## the domain services, state changes arrive as EventBus events and refresh the views. Panels are
## shown one at a time in a modal host (no stacked popups); the HUD hides while one is open.
##
## Layers, bottom to top: world input, HUD, modal host, toast, water-mind overlay, debug menu.

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
var settings_panel: SettingsPanel
var licenses_panel: TextPanel
var debug_menu: DebugMenu = null

var _modal_host: Control
var _modal_center: CenterContainer
var _current_panel: Control = null
var _fishing: FishingController
var _region: RegionRuntime
var _restoration: RestorationService
var _region_id := ""

func _init() -> void:
	layer = 10

## `deps`: fishing, region, restoration, journal, debug (nullable), region_id.
func setup(deps: Dictionary) -> void:
	game = deps
	_fishing = deps["fishing"]
	_region = deps["region"]
	_restoration = deps["restoration"]
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
	# The meter sits under the status line, over the sky, so the pond and the thumb stay clear.
	fight_meter = FightMeter.new()
	fight_meter.visible = false
	fight_meter.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fight_meter.offset_top = 235
	fight_meter.offset_left = 30
	fight_meter.offset_right = -30
	root.add_child(fight_meter)

	# Toasts are drawn under the modal host: a message never covers an open screen.
	toast = Toast.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_bottom = -290
	root.add_child(toast)
	_build_modal_host()
	water_mind = WaterMindOverlay.new()
	root.add_child(water_mind)
	_build_panels(deps)

	hud.setup(_fishing, _region_id, _region.weather)
	world_input.setup(_fishing, _region, hud)
	hud.journal_pressed.connect(open_journal)
	hud.gear_pressed.connect(func() -> void: _open(gear_panel))
	hud.restore_pressed.connect(open_restoration)
	hud.settings_pressed.connect(func() -> void: _open(settings_panel))
	hud.water_mind_pressed.connect(enter_water_mind)
	hud.cta_down.connect(_on_cta_down)
	hud.cta_up.connect(_on_cta_up)
	water_mind.exited.connect(exit_water_mind)
	water_mind.message.connect(show_message)

	_fishing.fight_updated.connect(fight_meter.update_values)
	_fishing.cast_rejected.connect(_on_cast_rejected)
	EventBus.fishing_state_changed.connect(_on_fishing_state_changed)
	EventBus.fish_escaped.connect(_on_fish_escaped)
	EventBus.fishing_cancelled.connect(func() -> void: show_message(tr("ui.toast.cancelled")))
	EventBus.fish_released.connect(_on_fish_released)
	EventBus.region_restoration_points_changed.connect(func(_region_id_changed: String, _points: int) -> void: _refresh_restore_hint())
	EventBus.region_restoration_changed.connect(func(_region_id_changed: String, _level: int) -> void: _refresh_restore_hint())
	EventBus.save_recovered.connect(func(_source: String) -> void: show_message(tr("ui.save.recovered")))
	EventBus.save_failed.connect(func(_text: String) -> void: show_message(tr("ui.save.failed")))
	EventBus.settings_changed.connect(_on_setting_changed)
	EventBus.game_state_replaced.connect(_apply_theme)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_theme()
	_refresh_restore_hint()
	_show_first_hint()

func _build_modal_host() -> void:
	_modal_host = ColorRect.new()
	(_modal_host as ColorRect).color = Color(0, 0, 0, 0.5)
	_modal_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_host.visible = false
	root.add_child(_modal_host)
	_modal_center = CenterContainer.new()
	_modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_host.add_child(_modal_center)

func _build_panels(deps: Dictionary) -> void:
	inspect_panel = InspectPanel.new()
	inspect_panel.release_pressed.connect(func() -> void: _fishing.release_catch())
	inspect_panel.journal_pressed.connect(func() -> void: open_journal(_fishing.encounter.fish_id if _fishing.encounter != null else ""))
	journal_panel = JournalPanel.new()
	journal_panel.setup(deps["journal"], _region_id)
	journal_panel.close_pressed.connect(_back_from_journal)
	gear_panel = GearPanel.new()
	gear_panel.close_pressed.connect(close_panel)
	restoration_panel = RestorationPanel.new()
	restoration_panel.setup(_restoration, _region_id)
	restoration_panel.close_pressed.connect(close_panel)
	restoration_panel.confirmed.connect(_on_restore_confirmed)
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

func _open(panel: Control) -> void:
	if water_mind.active:
		return
	if not panel.has_meta("design_width"):
		panel.set_meta("design_width", panel.custom_minimum_size.x)
	panel.custom_minimum_size.x = fit_width(float(panel.get_meta("design_width")), get_viewport().get_visible_rect().size.x)
	if _current_panel != null:
		_modal_center.remove_child(_current_panel)
	_current_panel = panel
	_modal_center.add_child(panel)
	if panel.has_method("refresh"):
		panel.refresh()
	_modal_host.visible = true
	hud.visible = false
	world_input.enabled = false

func close_panel() -> void:
	if _current_panel != null:
		_modal_center.remove_child(_current_panel)
		_current_panel = null
	_modal_host.visible = false
	hud.visible = true
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
	_open(journal_panel)
	if not fish_id.is_empty():
		journal_panel.focus_fish(fish_id)

func _back_from_journal() -> void:
	close_panel()

func open_restoration() -> void:
	_open(restoration_panel)

func _show_inspect() -> void:
	var pending := GameState.get_pending_catch()
	if pending.is_empty():
		return
	_open(inspect_panel)
	inspect_panel.show_catch(pending)
	if GameState.get_setting("tutorial_hints") == true:
		_hint_once("hint_release", "ui.hint.release")

func toggle_debug_menu() -> void:
	if debug_menu == null:
		return
	if _current_panel == debug_menu:
		close_panel()
	else:
		_open(debug_menu)

# --- fishing flow ---

func _on_cta_down() -> void:
	match _fishing.state:
		FishingController.State.READY, FishingController.State.AIM:
			world_input.cast_quick()
		FishingController.State.WAIT, FishingController.State.BITE_HINT, FishingController.State.HOOK:
			_fishing.tap()
		FishingController.State.FIGHT:
			_fishing.set_reeling(true)

func _on_cta_up() -> void:
	if _fishing.state == FishingController.State.FIGHT:
		_fishing.set_reeling(false)

func _on_fishing_state_changed(_previous: String, current: String) -> void:
	var fighting := current == "fight"
	fight_meter.visible = fighting  # the meter means nothing before the fish is hooked
	if fighting:
		var band: Dictionary = ContentDB.balance["fishing"]["fight"]["band"]
		fight_meter.configure(float(band["min"]), float(band["max"]), GameState.get_setting("high_contrast_meter") == true)
		fight_meter.update_values(0.5, _fishing.fight.progress if _fishing.fight != null else 0.0)
		_hint_once("hint_reel", "ui.hint.reel")
	elif current == "bite_hint":
		_hint_once("hint_hook", "ui.hint.hook")
	elif current == "inspect":
		_show_inspect()
	if current == "ready" and _current_panel == inspect_panel:
		close_panel()

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

# --- hints (Tutorial Hints setting) ---

func _show_first_hint() -> void:
	if GameState.get_setting("tutorial_hints") == true:
		_hint_once("hint_cast", "ui.hint.cast")

func _hint_once(event_id: String, key: String) -> void:
	if GameState.get_setting("tutorial_hints") != true or GameState.has_seen_event(_region_id, event_id):
		return
	GameState.mark_event_seen(_region_id, event_id)
	show_message(tr(key))

func show_message(text: String) -> void:
	toast.show_message(text)

# --- water-mind ---

func enter_water_mind() -> void:
	if _current_panel != null:
		close_panel()
	hud.visible = false
	fight_meter.visible = false
	world_input.enabled = false
	water_mind.enter()

func exit_water_mind() -> void:
	hud.visible = true
	hud.wake()
	world_input.enabled = true

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

func _apply_layout() -> void:
	var window_size := get_viewport().get_visible_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var top_inset := 0.0
	var bottom_inset := 0.0
	if screen.y > 0 and safe.size.y > 0:
		var scale := window_size.y / float(screen.y)
		top_inset = float(safe.position.y) * scale
		bottom_inset = maxf(0.0, float(screen.y - safe.end.y)) * scale
	hud.apply_layout(top_inset, bottom_inset, UiTheme.touch_min(GameState.get_setting("large_ui") == true))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_debug_menu()

func _input(event: InputEvent) -> void:
	# A key wakes a faded HUD. Touches are handled by WorldInput, which consumes the waking press so
	# that bringing the HUD back never casts a line by accident.
	if event is InputEventKey and event.pressed:
		hud.wake()
