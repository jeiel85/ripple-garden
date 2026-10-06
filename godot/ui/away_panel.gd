class_name AwayPanel
extends PanelContainer

## "While you were away" (GDD §14, P1-007): one short card after an absence — how long, which fish
## multiplied and the Ripple that trickled in — and a single button to go and look. It points at the
## world rather than at numbers: the new fish are already swimming when the card closes. Never stacked
## with other rewards; shown once per absence.

signal close_pressed

const MAX_FISH_LINES := 4

var _title: Label
var _rows: VBoxContainer

func _init() -> void:
	custom_minimum_size = Vector2(600, 0)
	var box := UiKit.vbox(12)
	var head := UiKit.hbox(10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UiKit.icon("clock", 40.0, UiTheme.GREEN))
	_title = UiKit.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, true)
	head.add_child(_title)
	box.add_child(head)
	_rows = UiKit.vbox(8)
	box.add_child(_rows)
	var look := UiKit.centered_button("lotus", tr("ui.away.look"), func() -> void: close_pressed.emit(), "PrimaryButton", 36.0)
	look.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(look)
	add_child(UiKit.margin(box, 26))

func show_summary(summary: OfflineService.Summary) -> void:
	_title.text = tr("ui.away.title") % maxi(1, roundi(summary.hours())) if summary.hours() >= 1.0 else tr("ui.away.title_short")
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var fish_ids: Array = summary.fish_added.keys()
	for i in mini(fish_ids.size(), MAX_FISH_LINES):
		var fish_id: String = fish_ids[i]
		_rows.add_child(_row("fish", tr("ui.away.fish") % [tr(ContentDB.get_fish(fish_id).get("name_key", "")), summary.fish_added[fish_id]]))
	if fish_ids.size() > MAX_FISH_LINES:
		_rows.add_child(_row("fish", tr("ui.away.more_fish") % (fish_ids.size() - MAX_FISH_LINES)))
	if summary.ripple > 0:
		_rows.add_child(_row("ripple", tr("ui.away.ripple") % summary.ripple))
	if _rows.get_child_count() == 0:
		_rows.add_child(_row("lotus", tr("ui.away.quiet")))

func line_count() -> int:
	return _rows.get_child_count()

func _row(icon_name: String, text: String) -> Control:
	var row := UiKit.hbox(10)
	row.add_child(UiKit.icon(icon_name, 32.0, UiTheme.INK_DIM))
	var label := UiKit.label(text, "", HORIZONTAL_ALIGNMENT_LEFT, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row
