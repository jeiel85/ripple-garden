class_name DebugMenu
extends PanelContainer

## QA menu over DebugService. Opened with F12 (or a long press on the status line) in debug and QA
## builds; it does not exist in release. Text here is deliberately plain (not localised): it is a
## developer tool and never shown to players.

signal close_pressed
signal message(text: String)

var service: DebugService
var region_id := ""

var _fish_picker: OptionButton
var _level_picker: SpinBox

func _init() -> void:
	custom_minimum_size = Vector2(640, 980)

func setup(p_service: DebugService, p_region_id: String) -> void:
	service = p_service
	region_id = p_region_id
	var box := UiKit.vbox(10)
	var header := UiKit.hbox(12)
	var title := UiKit.label("Debug (%s build)" % BuildProfile.profile(), "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.button("Close", func() -> void: close_pressed.emit()))
	box.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UiKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)

	list.add_child(UiKit.label("Time of day", "DimLabel"))
	var times := UiKit.hbox(8)
	for band in DebugService.BAND_HOURS:
		times.add_child(_wide_button(band, func() -> void: _report(service.set_time_band(band), "time: %s" % band)))
	list.add_child(times)

	list.add_child(UiKit.label("Weather", "DimLabel"))
	var weathers := UiKit.hbox(8)
	for weather_id in service.weather.allowed_ids():
		weathers.add_child(_wide_button(weather_id, func() -> void: _report(service.set_weather(weather_id), "weather: %s" % weather_id)))
	list.add_child(weathers)

	list.add_child(UiKit.label("Next bite", "DimLabel"))
	_fish_picker = OptionButton.new()
	_fish_picker.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX)
	for fish_def in ContentDB.get_fish_for_region(region_id):
		_fish_picker.add_item(fish_def["id"].trim_prefix("fish_"))
		_fish_picker.set_item_metadata(_fish_picker.item_count - 1, fish_def["id"])
	list.add_child(_fish_picker)
	list.add_child(UiKit.button("Spawn at next bite", func() -> void:
		var fish_id: String = _fish_picker.get_item_metadata(_fish_picker.selected)
		message.emit("next bite: %s" % fish_id if service.spawn_fish(fish_id) else "refused")))

	list.add_child(UiKit.label("Restoration level", "DimLabel"))
	_level_picker = SpinBox.new()
	_level_picker.min_value = 0
	_level_picker.max_value = service.restoration.max_level(region_id)
	_level_picker.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX)
	list.add_child(_level_picker)
	list.add_child(UiKit.button("Set level", func() -> void:
		message.emit("level %d" % int(_level_picker.value) if service.set_restoration(region_id, int(_level_picker.value)) else "refused")))

	list.add_child(UiKit.label("Currency", "DimLabel"))
	list.add_child(UiKit.button("+1000 Ripple, +100 Memory", func() -> void:
		message.emit("granted" if service.grant_currency(1000, 100) else "refused")))

	list.add_child(UiKit.label("Offline", "DimLabel"))
	var offline := UiKit.hbox(8)
	for hours in [1, 8, 24]:
		offline.add_child(_wide_button("+%dh" % hours, func() -> void: message.emit("offline %ds applied" % service.simulate_offline(hours * 3600))))
	list.add_child(offline)

	list.add_child(UiKit.label("Save", "DimLabel"))
	list.add_child(UiKit.button("Corrupt save (keeps a copy)", func() -> void:
		message.emit("save corrupted, copy kept" if service.corrupt_save_copy() else "no save to corrupt")))
	list.add_child(UiKit.button("Reload save (recovery test)", func() -> void: message.emit("loaded from: %s" % service.reload_save())))
	add_child(UiKit.margin(box, 24))

func _report(ok: bool, text: String) -> void:
	message.emit(text if ok else "refused")

static func _wide_button(text: String, callback: Callable) -> Button:
	var button := UiKit.button(text, callback)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
