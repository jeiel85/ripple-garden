class_name InspectPanel
extends PanelContainer

## The moment after landing a fish (UI_UX §4 Inspect): who it is, how big, and whether it is a
## new discovery. "Release" is the primary action; the journal is secondary. There is no sell or
## keep button anywhere (GDD §11). Unmet species show their name only once caught, because the
## catch itself is the discovery.

signal release_pressed
signal journal_pressed

var _badge: Label
var _portrait: UiKit.FishPortrait
var _name: Label
var _size: Label
var _meetings: Label
var _hint: Label
var _release: Button
var _journal: Button

func _init() -> void:
	custom_minimum_size = Vector2(620, 0)
	var box := UiKit.vbox(14)
	_badge = UiKit.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_portrait = UiKit.FishPortrait.new()
	_portrait.custom_minimum_size = Vector2(0, 150)
	_name = UiKit.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_size = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_meetings = UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_hint = UiKit.label("", "DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_release = UiKit.button(tr("ui.inspect.release"), func() -> void: release_pressed.emit(), true, UiTheme.TOUCH_MIN_PX * 1.15)
	_journal = UiKit.button(tr("ui.inspect.journal"), func() -> void: journal_pressed.emit())
	for node in [_badge, _portrait, _name, _size, _meetings, _hint, UiKit.spacer(6), _release, _journal]:
		box.add_child(node)
	add_child(UiKit.margin(box, 26))

func _focus_release() -> void:
	# Deferred: by then the panel may already have been closed again.
	if _release.is_inside_tree():
		_release.grab_focus()

## `pending` is the pending-catch info: fish_id, size_cm, first_discovery. `hint_text` is an optional
## one-line tutorial hint shown under the details.
func show_catch(pending: Dictionary, hint_text: String = "") -> void:
	_hint.text = hint_text
	_hint.visible = not hint_text.is_empty()
	var fish_id: String = pending["fish_id"]
	var def := ContentDB.get_fish(fish_id)
	var first: bool = pending.get("first_discovery", false) == true
	_badge.text = tr("ui.inspect.new_discovery") if first else ""
	_badge.visible = first
	_portrait.fish_id = fish_id
	_portrait.known = true
	_portrait.queue_redraw()
	_name.text = tr(def.get("name_key", ""))
	_size.text = tr("ui.inspect.size") % float(pending["size_cm"])
	var record := GameState.get_collection_record(fish_id)
	_meetings.text = tr("ui.inspect.encounters") % int(record["encounters"])
	_focus_release.call_deferred()
