class_name Hud
extends Control

## The always-on interface (UI_UX §3): a status line and two small buttons on top, the shortcuts
## and the fishing button at the bottom. The scenery stays 70-80 % of the screen, the HUD fades
## after a few idle seconds and a touch brings it back. The single fishing button changes its
## label (and role) with the fishing state, so one thumb can do the whole loop.
##
## The HUD only reports presses; the UIController decides what they do. It never changes state.

signal journal_pressed
signal gear_pressed
signal restore_pressed
signal settings_pressed
signal water_mind_pressed
signal cta_down
signal cta_up

const IDLE_FADE_SEC := 5.0
const FADE_TIME := 0.5

## Fishing state (lower-case name) -> [label key, enabled].
const CTA_BY_STATE := {
	"ready": ["ui.cta.cast", true],
	"aim": ["ui.cta.cast", true],
	"cast": ["ui.cta.casting", false],
	"wait": ["ui.cta.pull_back", true],
	"bite_hint": ["ui.cta.hook", true],
	"hook": ["ui.cta.hook", true],
	"fight": ["ui.cta.reel", true],
	"land": ["ui.cta.landing", false],
	"inspect": ["ui.cta.landing", false],
	"release": ["ui.cta.releasing", false],
}

var reduced_motion := false
var status_label: Label
var cta_button: Button
var journal_button: Button
var gear_button: Button
var restore_button: Button
var settings_button: Button
var water_mind_button: Button
var top_bar: Control
var bottom_bar: Control

var _region_id := ""
var _weather: WeatherService = null
var _idle := 0.0
var _faded := false
var _fade_tween: Tween
var _can_fade := true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	top_bar = UiKit.margin(_build_top(), 20)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	bottom_bar = UiKit.margin(_build_bottom(), 20)
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_bar)

func _build_top() -> Control:
	var row := UiKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label = UiKit.label("", "", HORIZONTAL_ALIGNMENT_LEFT, false)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status_label)
	water_mind_button = UiKit.button(tr("ui.button.water_mind"), func() -> void: water_mind_pressed.emit())
	settings_button = UiKit.button(tr("ui.button.settings"), func() -> void: settings_pressed.emit())
	row.add_child(water_mind_button)
	row.add_child(settings_button)
	return row

func _build_bottom() -> Control:
	var row := UiKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journal_button = UiKit.button(tr("ui.button.journal"), func() -> void: journal_pressed.emit())
	gear_button = UiKit.button(tr("ui.button.gear"), func() -> void: gear_pressed.emit())
	cta_button = UiKit.button(tr("ui.cta.cast"), func() -> void: pass, true, UiTheme.TOUCH_MIN_PX * 1.2)
	cta_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cta_button.size_flags_stretch_ratio = 1.6
	cta_button.button_down.connect(func() -> void: cta_down.emit())
	cta_button.button_up.connect(func() -> void: cta_up.emit())
	restore_button = UiKit.button(tr("ui.button.restore"), func() -> void: restore_pressed.emit())
	# Long labels (large text, other languages) wrap instead of pushing the row off screen.
	for button in [journal_button, gear_button, restore_button, cta_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		button.add_theme_constant_override("h_separation", 0)
		button.custom_minimum_size.x = 60
	row.add_child(journal_button)
	row.add_child(gear_button)
	row.add_child(cta_button)
	row.add_child(restore_button)
	return row

func setup(fishing: FishingController, region_id: String, weather: WeatherService) -> void:
	_region_id = region_id
	_weather = weather
	EventBus.fishing_state_changed.connect(func(_previous: String, current: String) -> void: set_cta_for_state(current))
	EventBus.game_time_band_changed.connect(func(_band: String) -> void: refresh_status())
	EventBus.weather_changed.connect(func(_weather: String) -> void: refresh_status())
	set_cta_for_state(FishingController.State.keys()[fishing.state].to_lower())
	refresh_status()

## "Quiet Pond · Dusk · Rain" in the current language.
func refresh_status() -> void:
	var region_name := tr(ContentDB.get_region(_region_id).get("name_key", ""))
	var band_name := tr("ui.time." + TimeService.get_time_band())
	var weather_id := _weather.current_id if _weather != null else ""
	var weather_name := tr(ContentDB.get_weather(weather_id).get("name_key", "")) if not weather_id.is_empty() else ""
	status_label.text = tr("ui.status.line") % [region_name, band_name, weather_name]

func set_cta_for_state(state_name: String) -> void:
	var entry: Array = CTA_BY_STATE.get(state_name, CTA_BY_STATE["ready"])
	cta_button.text = tr(entry[0])
	cta_button.disabled = not entry[1]
	_can_fade = state_name == "ready"
	wake()

## A soft "ready" cue for restoration: the button turns accent-coloured, with no badge or count.
func set_restore_ready(is_ready: bool) -> void:
	restore_button.theme_type_variation = "PrimaryButton" if is_ready else ""

## Applies safe-area insets and the minimum touch size (design pixels).
func apply_layout(top_inset: float, bottom_inset: float, touch_min: float) -> void:
	top_bar.add_theme_constant_override("margin_top", 20 + int(top_inset))
	bottom_bar.add_theme_constant_override("margin_bottom", 20 + int(bottom_inset))
	for button in [journal_button, gear_button, restore_button, settings_button, water_mind_button]:
		button.custom_minimum_size.y = touch_min
	cta_button.custom_minimum_size.y = touch_min * 1.2

# --- idle fade ---

func is_faded() -> bool:
	return _faded

func _process(delta: float) -> void:
	if _faded or not _can_fade or not visible:
		return
	_idle += delta
	if _idle >= IDLE_FADE_SEC:
		fade_out()

func fade_out() -> void:
	if _faded:
		return
	_faded = true
	if _fade_tween != null:
		_fade_tween.kill()
	if reduced_motion:
		modulate.a = 0.0
		_hide_if_faded()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_fade_tween.tween_callback(_hide_if_faded)

func _hide_if_faded() -> void:
	# Invisible controls would still catch touches, so hide them for real.
	if _faded:
		top_bar.visible = false
		bottom_bar.visible = false

## Brings the HUD back (any touch) and restarts the idle timer.
func wake() -> void:
	_idle = 0.0
	if not _faded:
		return
	_faded = false
	if _fade_tween != null:
		_fade_tween.kill()
	top_bar.visible = true
	bottom_bar.visible = true
	modulate.a = 1.0 if reduced_motion else modulate.a
	if not reduced_motion:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)
