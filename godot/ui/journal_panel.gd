class_name JournalPanel
extends PanelContainer

## The fish journal (UI_UX §5). Species you have not met are a dark silhouette with a gentle
## hint, never a "???": ignorance is not punished. What is shown about a met species grows with
## how often you have met it (JournalModel), and the card says when more will be revealed.

signal close_pressed

var journal: JournalModel
var region_id := ""

var _title: Label
var _progress: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _cards: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(640, 980)
	var box := UiKit.vbox(12)
	var header := UiKit.hbox(12)
	_title = UiKit.label(tr("ui.journal.title"), "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(UiKit.button(tr("ui.close"), func() -> void: close_pressed.emit()))
	box.add_child(header)
	_progress = UiKit.label("", "DimLabel")
	box.add_child(_progress)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UiKit.vbox(12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	box.add_child(_scroll)
	add_child(UiKit.margin(box, 24))

func setup(p_journal: JournalModel, p_region_id: String) -> void:
	journal = p_journal
	region_id = p_region_id

## Rebuilds the cards from the current save.
func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_cards.clear()
	var completion := journal.completion(region_id, GameState)
	_progress.text = tr("ui.journal.progress") % [completion["discovered"], completion["total"]]
	for entry in journal.entries_for_region(region_id, GameState):
		var card := _card(entry)
		_cards[entry.fish_id] = card
		_list.add_child(card)

func focus_fish(fish_id: String) -> void:
	if _cards.has(fish_id):
		_scroll.ensure_control_visible.call_deferred(_cards[fish_id])

func card_count() -> int:
	return _cards.size()

func _card(entry: JournalModel.Entry) -> Control:
	var def := ContentDB.get_fish(entry.fish_id)
	var panel := PanelContainer.new()
	var row := UiKit.hbox(16)
	var portrait := UiKit.FishPortrait.new(entry.fish_id, entry.discovered)
	portrait.custom_minimum_size = Vector2(150, 96)
	row.add_child(portrait)

	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if entry.show_name:
		info.add_child(UiKit.label(tr(def["name_key"]), "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false))
		info.add_child(UiKit.label(tr("ui.journal.size_range") % [entry.smallest_cm, entry.largest_cm], "DimLabel"))
		info.add_child(UiKit.label(tr("ui.journal.met") % entry.encounters, "DimLabel"))
	else:
		info.add_child(UiKit.label(tr("ui.journal.unknown_name"), "TitleLabel"))
		info.add_child(UiKit.label(tr("ui.journal.unknown_hint"), "DimLabel"))
	if entry.show_time_bands:
		var names: Array[String] = []
		for band in TimeService.TIME_BANDS:
			if float(def["time_bands"].get(band, 1.0)) >= 1.05:
				names.append(tr("ui.time." + band))
		if not names.is_empty():
			info.add_child(UiKit.label(tr("ui.journal.time") % ", ".join(names), "DimLabel"))
	if entry.show_habitats:
		var places: Array[String] = []
		for habitat in def["habitats"]:
			places.append(tr("ui.habitat." + habitat))
		info.add_child(UiKit.label(tr("ui.journal.habitat") % ", ".join(places), "DimLabel"))
	if entry.show_behavior:
		info.add_child(UiKit.label(tr("ui.journal.behavior") % tr("ui.behavior." + def["behavior"]), "DimLabel"))
		info.add_child(UiKit.label(tr(def["journal_key"]), "DimLabel"))
	if entry.next_unlock_at > 0 and entry.show_name:
		info.add_child(UiKit.label(tr("ui.journal.next_unlock") % entry.next_unlock_at, "DimLabel"))
	row.add_child(info)
	panel.add_child(UiKit.margin(row, 14))
	return panel
