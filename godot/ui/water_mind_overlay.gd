class_name WaterMindOverlay
extends Control

## Water-mind mode (GDD §16, UI_UX §8, mockup 08): the HUD disappears and the pond is left to be
## watched. A light overlay remains, in the mockup's layout:
##   top-left   "물멍 모드" badge — pressing it leaves the mode
##   top-right  "UI 숨기기" — hides the overlay; a tap on the water brings it back
##   bottom     Save (a photo of the scene), Time and Weather (preview another time of day or weather
##              on screen only; the real clock and weather keep running), BGM (the sound mixer)
## The overlay hides itself after a few idle seconds. After N idle minutes (setting, 0 = never) the
## picture dims to spare OLED burn-in and battery, and a one-time hint points to Battery Saver. The
## mixer works on the same volume settings as the audio section of Settings.

signal exited
signal message(text: String)
signal photo_requested
## The player cycled the on-screen time of day ("" = back to the real clock).
signal time_preview_changed(band: String)
## The player cycled the on-screen weather ("" = back to the real weather).
signal weather_preview_changed(weather_id: String)

const MENU_HIDE_SEC := 6.0
const DIM_ALPHA := 0.6
const DIM_FADE_SEC := 6.0
const MIXER_KEYS: PackedStringArray = ["volume_bgm", "volume_water", "volume_wind", "volume_wildlife", "volume_weather", "volume_camp"]
## The time-of-day preview cycles through these bands, then back to the real clock.
const PREVIEW_BANDS: PackedStringArray = TimeService.TIME_BANDS

var active := false
var reduced_motion := false
## Weather ids the picker cycles through (the region's own list; set by the UIController).
var weather_choices: Array = []
var time_preview := ""
var weather_preview := ""

var _dim: ColorRect
var _chrome: Control
var _badge: Button
var _hide_button: Button
var _photo_button: Button
var _time_button: Button
var _weather_button: Button
var _mixer_button: Button
var _mixer: PanelContainer
var _sliders: Dictionary = {}
var _idle_sec := 0.0
var _menu_idle := 0.0
var _dim_tween: Tween
var _syncing := false
## While photo mode frames a picture the overlay neither hides nor dims (a dimmed photo is no photo).
var idle_paused := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_chrome = Control.new()
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chrome)

	_badge = UiKit.icon_button("lotus", tr("ui.water_mind.badge"), exit, "PillButton", 34.0, false)
	_badge.tooltip_text = tr("ui.water_mind.exit")
	_badge.position = Vector2(20, 20)
	_chrome.add_child(_badge)
	_hide_button = UiKit.icon_button("eye_off", tr("ui.water_mind.hide_ui"), hide_chrome, "PillButton", 34.0, false)
	_hide_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hide_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hide_button.offset_right = -20
	_hide_button.offset_top = 20
	_chrome.add_child(_hide_button)

	var row := UiKit.hbox(22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -70
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_button = UiKit.round_button("camera", tr("ui.water_mind.save"), _request_photo, true, 128.0)
	_time_button = UiKit.round_button("clock", tr("ui.water_mind.time"), _cycle_time, true, 128.0)
	_weather_button = UiKit.round_button("weather", tr("ui.water_mind.weather"), _cycle_weather, true, 128.0)
	_mixer_button = UiKit.round_button("music", tr("ui.water_mind.bgm"), _toggle_mixer, true, 128.0)
	for button in [_photo_button, _time_button, _weather_button, _mixer_button]:
		row.add_child(button)
	_chrome.add_child(row)

	var box := UiKit.vbox(10)
	box.add_child(UiKit.label(tr("ui.water_mind.mixer"), "TitleLabel"))
	for key in MIXER_KEYS:
		var caption := UiKit.label(tr("ui.setting." + key), "", HORIZONTAL_ALIGNMENT_LEFT, true)
		box.add_child(caption)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX)
		slider.value_changed.connect(func(value: float) -> void:
			if not _syncing:
				GameState.set_setting(key, value)
			_menu_idle = 0.0)
		box.add_child(slider)
		_sliders[key] = slider
	_mixer = UiKit.modal(box, 560)
	_mixer.set_anchors_preset(Control.PRESET_CENTER)
	_mixer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mixer.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mixer.visible = false
	_chrome.add_child(_mixer)

func enter() -> void:
	if active:
		return
	active = true
	visible = true
	_idle_sec = 0.0
	_menu_idle = 0.0
	_dim.color.a = 0.0
	_chrome.visible = true
	_mixer.visible = false
	time_preview = ""
	weather_preview = ""
	_refresh_captions()
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
	_mixer.visible = false
	if _dim_tween != null:
		_dim_tween.kill()
	# Previews are a view of this mode only: leaving restores the real time and weather.
	if not time_preview.is_empty():
		time_preview = ""
		time_preview_changed.emit("")
	if not weather_preview.is_empty():
		weather_preview = ""
		weather_preview_changed.emit("")
	EventBus.water_mind_changed.emit(false)
	exited.emit()

## The overlay (badge and buttons) is showing.
func is_chrome_visible() -> bool:
	return _chrome.visible

func is_menu_open() -> bool:
	return _mixer.visible

func is_dimmed() -> bool:
	return _dim.color.a > 0.01

func hide_chrome() -> void:
	_chrome.visible = false
	_mixer.visible = false

func show_chrome() -> void:
	_chrome.visible = true
	_menu_idle = 0.0

## Moves the badge and buttons out of a notch and the gesture bar; the dimming stays full screen.
func apply_insets(top: float, bottom: float) -> void:
	_chrome.offset_top = top
	_chrome.offset_bottom = -bottom

## Idle minutes before dimming (0 = never), from settings.
func dim_after_sec() -> float:
	return float(GameState.get_setting("water_mind_dim_minutes")) * 60.0

func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		_touched()
		# A tap on the bare water shows or hides the overlay.
		if _chrome.visible:
			hide_chrome()
		else:
			show_chrome()

func _touched() -> void:
	_idle_sec = 0.0
	_menu_idle = 0.0
	if _dim_tween != null:
		_dim_tween.kill()
	_dim.color.a = 0.0

func _request_photo() -> void:
	_touched()
	photo_requested.emit()

func _toggle_mixer() -> void:
	_touched()
	_mixer.visible = not _mixer.visible
	if _mixer.visible:
		_sync_sliders()

func _cycle_time() -> void:
	_touched()
	var index := PREVIEW_BANDS.find(time_preview)
	time_preview = PREVIEW_BANDS[index + 1] if index + 1 < PREVIEW_BANDS.size() else ""
	_refresh_captions()
	time_preview_changed.emit(time_preview)
	message.emit(tr("ui.time." + time_preview) if not time_preview.is_empty() else tr("ui.water_mind.real_time"))

func _cycle_weather() -> void:
	_touched()
	if weather_choices.is_empty():
		return
	var index := weather_choices.find(weather_preview)
	weather_preview = weather_choices[index + 1] if index + 1 < weather_choices.size() else ""
	_refresh_captions()
	weather_preview_changed.emit(weather_preview)
	message.emit(tr(ContentDB.get_weather(weather_preview).get("name_key", "")) if not weather_preview.is_empty() else tr("ui.water_mind.real_weather"))

func _refresh_captions() -> void:
	_time_button.text = tr("ui.time." + time_preview) if not time_preview.is_empty() else tr("ui.water_mind.time")
	_weather_button.text = tr(ContentDB.get_weather(weather_preview).get("name_key", "")) if not weather_preview.is_empty() else tr("ui.water_mind.weather")
	UiKit.fit_caption(_time_button)
	UiKit.fit_caption(_weather_button)
	_weather_button.icon = UiIcons.texture(UiIcons.for_weather(weather_preview))

func _sync_sliders() -> void:
	_syncing = true
	for key in _sliders:
		(_sliders[key] as HSlider).value = float(GameState.get_setting(key))
	_syncing = false

## Pauses or resumes the idle timers (photo mode on top).
func pause_idle(paused: bool) -> void:
	idle_paused = paused
	_touched()

func _process(delta: float) -> void:
	if not active or idle_paused:
		return
	if _chrome.visible:
		_menu_idle += delta
		if _menu_idle >= MENU_HIDE_SEC and not _mixer.visible:
			hide_chrome()
	if _mixer.visible:
		return  # never dim while the player is mixing
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
