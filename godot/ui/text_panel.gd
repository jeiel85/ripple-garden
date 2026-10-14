class_name TextPanel
extends PanelContainer

## A titled, scrollable block of text with a Close button (open-source licenses).

signal close_pressed

var _title: Label
var _body: Label

func _init() -> void:
	custom_minimum_size = Vector2(640, 980)
	var box := UiKit.vbox(12)
	_title = UiKit.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	box.add_child(UiKit.dialog_header(_title, func() -> void: close_pressed.emit()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = UiKit.label("", "DimLabel")
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	box.add_child(scroll)
	add_child(UiKit.margin(box, 24))

func show_text(title: String, body: String) -> void:
	_title.text = title
	_body.text = body

## The licences shown in Settings: the game's own notice, the bundled fonts' (D-031) and the engine's.
static func licenses_text() -> String:
	var fonts := FileAccess.get_file_as_string(UiTheme.FONT_DIR + "OFL.txt")  # exported by the presets' include_filter
	var sounds := FileAccess.get_file_as_string("res://audio/CREDITS.txt")  # the music and recordings (D-039)
	return "%s\n\n%s\n\n%s\n\n%s" % [TranslationServer.translate("ui.licenses.intro"), sounds, fonts, Engine.get_license_text()]
