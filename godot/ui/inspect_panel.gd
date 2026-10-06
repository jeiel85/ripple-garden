class_name InspectPanel
extends Control

## The catch-result screen (UI_UX §4 Inspect, mockup 03): a quiet celebration over the blurred
## pond. A first discovery gets the laurel header "새로운 물고기를 낚았어요!", the fish is shown large
## with a pinned note naming its rarity, and a wooden frame holds the name, size, a short
## observational line and where/when it was met. There is no sell or keep button (GDD §11):
##   방생 (release)       let it go and stay
##   기록 (record)        look at it in the journal (it was recorded the moment it was caught, D-010)
##   다시 낚시 (fish again) let it go and cast again right away — the emphasised wooden action
## Unmet species show their name only once caught, because the catch itself is the discovery.

signal release_pressed
signal journal_pressed
signal fish_again_pressed

## Full-screen panel that keeps the status bar visible (see UIController._open).
const FULLSCREEN := true
const KEEPS_STATUS := true

var _header_icon_left: TextureRect
var _header_icon_right: TextureRect
var _badge: Label
var _portrait: UiKit.FishPortrait
var _rarity_title: Label
var _rarity_line: Label
var _name: Label
var _size: Label
var _flavor: Label
var _place: Label
var _when: Label
var _meetings: Label
var _hint: Label
var _release: Button
var _journal: Button
var _again: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var page := MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 28)
	page.add_theme_constant_override("margin_top", 124)
	page.add_theme_constant_override("margin_bottom", 30)
	add_child(page)
	var column := UiKit.vbox(10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(column)

	# Header: a small fish, then the title between two laurel branches.
	var fish_mark := UiKit.icon("fish", 36.0, UiTheme.PILL_TEXT)
	fish_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(fish_mark)
	var header := UiKit.hbox(12)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	_header_icon_left = UiKit.icon("laurel", 72.0, Color("#e8d9a0"))
	_header_icon_right = UiKit.icon("laurel", 72.0, Color("#e8d9a0"))
	_header_icon_right.flip_h = true
	_badge = UiKit.label("", "BigLabel", HORIZONTAL_ALIGNMENT_CENTER, true)
	_badge.theme_type_variation = "LightLabel"
	_badge.add_theme_font_size_override("font_size", 40)
	_badge.custom_minimum_size.x = 420
	header.add_child(_header_icon_left)
	header.add_child(_badge)
	header.add_child(_header_icon_right)
	column.add_child(header)

	# The fish, with the rarity note pinned at its upper right.
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 190)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = UiKit.FishPortrait.new()
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_right = -120
	hero.add_child(_portrait)
	var note := PanelContainer.new()
	note.theme_type_variation = "NoteCard"
	note.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	note.offset_left = -200
	note.offset_top = 0
	note.rotation_degrees = 4.0
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note_box := UiKit.vbox(4)
	var note_title := UiKit.hbox(6)
	note_title.alignment = BoxContainer.ALIGNMENT_CENTER
	note_title.add_child(UiKit.icon("memory", 30.0, UiTheme.GREEN))
	_rarity_title = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER, false)
	note_title.add_child(_rarity_title)
	note_box.add_child(note_title)
	_rarity_line = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, true)
	_rarity_line.custom_minimum_size.x = 160
	note_box.add_child(_rarity_line)
	note.add_child(note_box)
	hero.add_child(note)
	column.add_child(hero)

	# The wooden frame with the paper card.
	var frame := PanelContainer.new()
	frame.theme_type_variation = "WoodPanel"
	var paper := PanelContainer.new()
	paper.theme_type_variation = "CardPanel"
	var info := UiKit.vbox(8)
	_name = UiKit.label("", "BigLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	info.add_child(_name)
	var size_row := UiKit.hbox(14)
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var size_pill := PanelContainer.new()
	size_pill.theme_type_variation = "NoteCard"
	_size = UiKit.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	size_pill.add_child(_size)
	size_row.add_child(size_pill)
	_meetings = UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	size_row.add_child(_meetings)
	info.add_child(size_row)
	_flavor = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER, true)
	info.add_child(_flavor)
	var line := ColorRect.new()
	line.color = Color(UiTheme.CREAM_BORDER, 0.8)
	line.custom_minimum_size = Vector2(0, 2)
	info.add_child(line)
	var facts := UiKit.hbox(14)
	facts.add_child(_fact("pin", "ui.catch.place"))
	facts.add_child(UiKit.divider(56, Color(UiTheme.CREAM_BORDER, 0.9)))
	facts.add_child(_fact("calendar", "ui.catch.when"))
	info.add_child(facts)
	_hint = UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	info.add_child(_hint)
	paper.add_child(UiKit.margin(info, 16))
	frame.add_child(paper)
	column.add_child(frame)

	column.add_child(UiKit.spacer(6))
	var actions := UiKit.hbox(14)
	_release = UiKit.action_card("release", tr("ui.inspect.release"), tr("ui.inspect.release_sub"), func() -> void: release_pressed.emit())
	_journal = UiKit.action_card("record", tr("ui.inspect.journal"), tr("ui.inspect.journal_sub"), func() -> void: journal_pressed.emit())
	_again = UiKit.action_card("hook", tr("ui.inspect.fish_again"), tr("ui.inspect.fish_again_sub"), func() -> void: fish_again_pressed.emit(), "WaterButton")
	for button in [_release, _journal, _again]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	column.add_child(actions)

## A pin/calendar fact: icon, a small caption and the value. Returns the box; the value label is
## stored under the caption key.
func _fact(icon_name: String, caption_key: String) -> Control:
	var box := UiKit.hbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(UiKit.icon(icon_name, 40.0, UiTheme.INK_DIM))
	var text := UiKit.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiKit.label(tr(caption_key), "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT, false))
	var value := UiKit.label("", "", HORIZONTAL_ALIGNMENT_LEFT, true)
	value.custom_minimum_size.x = 150  # wraps inside its half instead of letter by letter
	text.add_child(value)
	box.add_child(text)
	if caption_key == "ui.catch.place":
		_place = value
	else:
		_when = value
	return box

func _focus_default() -> void:
	# Deferred: by then the panel may already have been closed again.
	if _again.is_inside_tree():
		_again.grab_focus()

## `pending` is the pending-catch info: fish_id, region_id, size_cm, first_discovery. `hint_text` is an
## optional one-line tutorial hint shown in the card.
func show_catch(pending: Dictionary, hint_text: String = "") -> void:
	_hint.text = hint_text
	_hint.visible = not hint_text.is_empty()
	var fish_id: String = pending["fish_id"]
	var def := ContentDB.get_fish(fish_id)
	var first: bool = pending.get("first_discovery", false) == true
	_badge.text = tr("ui.inspect.new_discovery") if first else tr("ui.inspect.caught")
	_header_icon_left.visible = first
	_header_icon_right.visible = first
	_portrait.fish_id = fish_id
	_portrait.known = true
	_portrait.queue_redraw()
	var rarity := int(def.get("rarity", 1))
	_rarity_title.text = tr("ui.rarity.%d" % rarity)
	_rarity_line.text = tr("ui.rarity.%d.line" % rarity)
	_name.text = tr(def.get("name_key", ""))
	_size.text = tr("ui.inspect.size") % float(pending["size_cm"])
	_flavor.text = tr("ui.catch.flavor." + String(def.get("behavior", "steady")))
	var region_id: String = pending.get("region_id", "")
	_place.text = tr(ContentDB.get_region(region_id).get("name_key", "")) if not region_id.is_empty() else ""
	var record := GameState.get_collection_record(fish_id)
	var seen_at := int(record["last_seen_at"])
	_when.text = date_text(seen_at) if seen_at > 0 else ""
	_meetings.text = tr("ui.inspect.encounters") % int(record["encounters"])
	_focus_default.call_deferred()

## "2026. 10. 6. 14:32" style local date and time of a unix timestamp ("2026. 10. 6." without the time).
static func date_text(unix_time: int, with_time: bool = true) -> String:
	var local := Time.get_datetime_dict_from_unix_time(unix_time + _utc_offset_sec())
	if not with_time:
		return TranslationServer.translate("ui.date.day_format") % [local["year"], local["month"], local["day"]]
	return TranslationServer.translate("ui.date.format") % [local["year"], local["month"], local["day"], local["hour"], local["minute"]]

static func _utc_offset_sec() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
