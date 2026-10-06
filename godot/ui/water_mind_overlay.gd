class_name WaterMindOverlay
extends Control

## Water-mind mode (GDD §16, UI_UX §8): every HUD element disappears and the pond is left to be
## watched. A tap shows a minimal overlay (exit and the sound mixer); it hides itself again after a
## few idle seconds. After N idle minutes (setting, 0 = never) the picture dims to spare OLED
## burn-in and battery, and a one-time hint points to Battery Saver. The mixer works on the same
## volume settings as the audio section of Settings.

signal exited
signal message(text: String)

const MENU_HIDE_SEC := 5.0
const DIM_ALPHA := 0.6
const DIM_FADE_SEC := 6.0
const MIXER_KEYS: PackedStringArray = ["volume_bgm", "volume_water", "volume_wind", "volume_wildlife", "volume_weather", "volume_camp"]

var active := false
var reduced_motion := false

var _dim: ColorRect
var _menu: PanelContainer
var _sliders: Dictionary = {}
var _idle_sec := 0.0
var _menu_idle := 0.0
var _dim_tween: Tween
var _syncing := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var box := UiKit.vbox(12)
	box.add_child(UiKit.button(tr("ui.water_mind.exit"), exit, true))
	box.add_child(UiKit.label(tr("ui.water_mind.mixer"), "DimLabel"))
	for key in MIXER_KEYS:
		var caption := UiKit.label(tr("ui.setting." + key), "", HORIZONTAL_ALIGNMENT_LEFT, true)
		box.add_child(caption)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX * 0.7)
		slider.value_changed.connect(func(value: float) -> void:
			if not _syncing:
				GameState.set_setting(key, value)
			_menu_idle = 0.0)
		box.add_child(slider)
		_sliders[key] = slider
	_menu = UiKit.modal(box, 560)
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.visible = false
	add_child(_menu)

func enter() -> void:
	if active:
		return
	active = true
	visible = true
	_idle_sec = 0.0
	_dim.color.a = 0.0
	_menu.visible = false
	EventBus.water_mind_changed.emit(true)
	message.emit(tr("ui.water_mind.hint"))
	if GameState.get_setting("battery_saver") != true and GameState.get_setting("battery_saver_hint_seen") != true:
		GameState.set_setting("battery_saver_hint_seen", true)  # shown once, never nagged
		message.emit(tr("ui.water_mind.battery_hint"))

func exit() -> void:
	if not active:
		return
	active = false
	visible = false
	_menu.visible = false
	if _dim_tween != null:
		_dim_tween.kill()
	EventBus.water_mind_changed.emit(false)
	exited.emit()

func is_menu_open() -> bool:
	return _menu.visible

func is_dimmed() -> bool:
	return _dim.color.a > 0.01

## Idle minutes before dimming (0 = never), from settings.
func dim_after_sec() -> float:
	return float(GameState.get_setting("water_mind_dim_minutes")) * 60.0

func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		_touched()
		_menu.visible = not _menu.visible  # a tap on the bare water toggles the small menu
		_menu_idle = 0.0
		if _menu.visible:
			_sync_sliders()

func _touched() -> void:
	_idle_sec = 0.0
	if _dim_tween != null:
		_dim_tween.kill()
	_dim.color.a = 0.0

func _sync_sliders() -> void:
	_syncing = true
	for key in _sliders:
		(_sliders[key] as HSlider).value = float(GameState.get_setting(key))
	_syncing = false

func _process(delta: float) -> void:
	if not active:
		return
	if _menu.visible:
		_menu_idle += delta
		if _menu_idle >= MENU_HIDE_SEC:
			_menu.visible = false
		return
	var limit := dim_after_sec()
	if limit <= 0.0 or is_dimmed() and _dim_tween != null and _dim_tween.is_running():
		return
	_idle_sec += delta
	if _idle_sec >= limit and not is_dimmed():
		if reduced_motion:
			_dim.color.a = DIM_ALPHA
		else:
			_dim_tween = create_tween()
			_dim_tween.tween_property(_dim, "color:a", DIM_ALPHA, DIM_FADE_SEC)
