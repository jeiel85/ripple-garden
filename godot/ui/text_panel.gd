class_name TextPanel
extends PanelContainer

## A titled, scrollable block of text with a Close button (open-source licenses).

signal close_pressed

var _title: Label
var _body: Label

func _init() -> void:
	custom_minimum_size = Vector2(640, 980)
	var box := UiKit.vbox(12)
	var header := UiKit.hbox(12)
	_title = UiKit.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(UiKit.button(tr("ui.close"), func() -> void: close_pressed.emit()))
	box.add_child(header)
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

## The licences shown in Settings: the game's own notice plus the engine's licence text.
static func licenses_text() -> String:
	return "%s\n\n%s" % [TranslationServer.translate("ui.licenses.intro"), Engine.get_license_text()]
