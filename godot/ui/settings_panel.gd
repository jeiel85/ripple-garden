class_name SettingsPanel
extends PanelContainer

## Settings (UI_UX §9): gameplay, accessibility, graphics, audio, water-mind and support. Every row is
## generated from SECTIONS and bound to a GameState setting, so a setting that exists in the save
## schema but is missing here is caught by a test. Changes are applied immediately through
## GameState.set_setting, which announces them on EventBus; this panel never touches the engine.

signal close_pressed
signal message(text: String)
signal licenses_pressed

## [setting key, kind, extra...]: toggle | slider(min, max, step) | option(values)
const SECTIONS: Array = [
	{"title": "ui.settings.gameplay", "rows": [
		["relaxed_hook", "toggle"], ["auto_hook", "toggle"], ["real_time_mode", "toggle"], ["tutorial_hints", "toggle"]]},
	{"title": "ui.settings.accessibility", "rows": [
		["text_scale", "slider", 0.8, 1.6, 0.1], ["large_ui", "toggle"], ["reduced_motion", "toggle"],
		["camera_shake", "toggle"], ["haptics", "toggle"], ["high_contrast_meter", "toggle"], ["visual_bite_cue", "toggle"]]},
	{"title": "ui.settings.graphics", "rows": [
		["quality", "option", ["low", "medium", "high"]], ["fps_cap", "option", [30, 60]], ["battery_saver", "toggle"]]},
	{"title": "ui.settings.audio", "rows": [
		["volume_master", "slider", 0.0, 1.0, 0.05], ["volume_bgm", "slider", 0.0, 1.0, 0.05],
		["volume_water", "slider", 0.0, 1.0, 0.05], ["volume_wind", "slider", 0.0, 1.0, 0.05],
		["volume_wildlife", "slider", 0.0, 1.0, 0.05], ["volume_weather", "slider", 0.0, 1.0, 0.05],
		["volume_fishing", "slider", 0.0, 1.0, 0.05], ["volume_camp", "slider", 0.0, 1.0, 0.05]]},
	{"title": "ui.settings.water_mind", "rows": [["water_mind_dim_minutes", "slider", 0, 60, 1]]},
]

## Settings that are intentionally not shown (internal bookkeeping).
const HIDDEN_KEYS: PackedStringArray = ["battery_saver_hint_seen"]

var _syncing := false
var _controls: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(640, 980)
	var box := UiKit.vbox(12)
	var header := UiKit.hbox(12)
	var title := UiKit.label(tr("ui.settings.title"), "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.button(tr("ui.close"), func() -> void: close_pressed.emit()))
	box.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UiKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)

	for section in SECTIONS:
		list.add_child(UiKit.spacer(8))
		list.add_child(UiKit.label(tr(section["title"]), "TitleLabel"))
		for row in section["rows"]:
			list.add_child(_row(row))
	list.add_child(UiKit.spacer(8))
	list.add_child(UiKit.label(tr("ui.settings.support"), "TitleLabel"))
	list.add_child(UiKit.button(tr("ui.support.export_diagnostics"), _export_diagnostics))
	list.add_child(UiKit.button(tr("ui.support.licenses"), func() -> void: licenses_pressed.emit()))
	add_child(UiKit.margin(box, 24))
	EventBus.settings_changed.connect(func(_key: String) -> void: refresh())
	EventBus.game_state_replaced.connect(refresh)

## Re-reads every control from the save (without echoing the values back as changes).
func refresh() -> void:
	_syncing = true
	for key in _controls:
		var control: Control = _controls[key]
		var value: Variant = GameState.get_setting(key)
		if control is CheckButton:
			control.button_pressed = value == true
		elif control is HSlider:
			control.value = float(value)
			_update_slider_label(key)
		elif control is OptionButton:
			var values: Array = control.get_meta("values")
			control.select(maxi(0, values.find(value)))
	_syncing = false

func control_for(key: String) -> Control:
	return _controls.get(key)

func _row(spec: Array) -> Control:
	var key: String = spec[0]
	match spec[1]:
		"toggle":
			var toggle := CheckButton.new()
			toggle.text = tr("ui.setting." + key)
			toggle.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX)
			toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long labels wrap instead of widening the panel
			toggle.toggled.connect(func(on: bool) -> void:
				if not _syncing:
					GameState.set_setting(key, on))
			_controls[key] = toggle
			return toggle
		"slider":
			var box := UiKit.vbox(4)
			var caption := UiKit.label("", "", HORIZONTAL_ALIGNMENT_LEFT, true)
			caption.name = "Caption"
			box.add_child(caption)
			var slider := HSlider.new()
			slider.min_value = float(spec[2])
			slider.max_value = float(spec[3])
			slider.step = float(spec[4])
			slider.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX * 0.7)
			slider.value_changed.connect(func(value: float) -> void:
				if _syncing:
					return
				GameState.set_setting(key, value)
				_update_slider_label(key))
			box.add_child(slider)
			box.set_meta("caption", caption)
			slider.set_meta("caption", caption)
			_controls[key] = slider
			return box
		"option":
			var box := UiKit.hbox(12)
			var caption := UiKit.label(tr("ui.setting." + key), "", HORIZONTAL_ALIGNMENT_LEFT, true)
			caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(caption)
			var option := OptionButton.new()
			option.custom_minimum_size = Vector2(220, UiTheme.TOUCH_MIN_PX)
			var values: Array = spec[2]
			for value in values:
				option.add_item(tr("ui.%s.%s" % [key, str(value)]) if key == "quality" else str(value))
			option.set_meta("values", values)
			option.item_selected.connect(func(index: int) -> void:
				if not _syncing:
					GameState.set_setting(key, values[index]))
			box.add_child(option)
			_controls[key] = option
			return box
	return Control.new()

func _update_slider_label(key: String) -> void:
	var slider: HSlider = _controls[key]
	var caption: Label = slider.get_meta("caption")
	var shown := "%d%%" % roundi(slider.value * 100.0) if slider.max_value <= 1.0 else str(roundi(slider.value))
	if key == "text_scale":
		shown = "%d%%" % roundi(slider.value * 100.0)
	caption.text = "%s  %s" % [tr("ui.setting." + key), shown]

func _export_diagnostics() -> void:
	var result := DiagnosticsExporter.export_to_file()
	message.emit(tr("ui.support.diagnostics_saved") % result if not result.is_empty() else tr("ui.support.diagnostics_failed"))
