class_name JournalPanel
extends Control

## The fish journal (UI_UX §5, mockup 04): a wooden "도감" sign, the count of species met, tabs, a
## notebook of fish cards on the left and the page of the chosen fish on the right.
##
## What a card and a page show grows with how often the fish was met (JournalModel): an unmet species
## is a silhouette named "???", a met one shows its name and size, and the page opens its preferred
## time, home and story at 3/5/10 meetings — every locked line says how many meetings it needs, so
## ignorance is never punished. A crown marks a fully known species, "NEW" one met but not looked at
## yet (looking at its page clears it, and with it the dot on the journal button and the "All" tab).
##
## Tabs follow the world: all species, one per region group, the rare ones (rarity 4+), and the moments
## seen by the water (P1-008), which use the same notebook: cards on the left, the page on the right.

signal close_pressed

const FULLSCREEN := true
const KEEPS_NAV := true

## [tab id, icon, label key, region ids (empty = every region), minimum rarity]
const TABS: Array = [
	["all", "fish", "ui.journal.tab.all", [], 1],
	["pond", "lake", "ui.journal.tab.pond", ["region_01_quiet_pond"], 1],
	["valley", "valley", "ui.journal.tab.valley", ["region_02_forest_stream"], 1],
	["river", "freshwater", "ui.journal.tab.river", ["region_03_reed_river"], 1],
	["sea", "sea", "ui.journal.tab.sea", ["region_04_blue_coast", "region_05_moonlight_isle"], 1],
	["special", "special", "ui.journal.tab.special", [], 4],
	["moments", "star", "ui.journal.tab.moments", [], 0],
]
const SORTS: PackedStringArray = ["found", "name", "size"]
## Height of a moment's picture on its card (168 px tall): leaves room for a two-line name under it.
const MOMENT_CARD_PICTURE_PX := 80.0

var journal: JournalModel
var region_id := ""
var tab := "all"
var sort_mode := "found"
var selected_id := ""

var _counter: Label
var _progress: Label
var _tabs: Dictionary = {}
var _all_dot: UiKit.NoticeDot
var _list: GridContainer
var _scroll: ScrollContainer
var _sort_button: Button
var _cards: Dictionary = {}
var _page: VBoxContainer
var _page_name: Label
var _page_line: Label
var _page_portrait: UiKit.FishPortrait
## A moment's drawn picture (`moments/<id>.png`), in the portrait's place on a moment's page.
var _page_moment: TextureRect
var _page_rows: VBoxContainer
var _home_title: Label
var _home_text: Label
var _home_place: Label
var _home_view: HomeView

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var page := MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 18)
	page.add_theme_constant_override("margin_top", 26)
	page.add_theme_constant_override("margin_bottom", 176)  # the navigation row stays visible below
	add_child(page)
	var column := UiKit.vbox(12)
	page.add_child(column)

	# Header: back, hanging sign with subtitle, species counter.
	var header := UiKit.hbox(10)
	var back := UiKit.icon_button("back", "", func() -> void: close_pressed.emit(), "CircleButton", UiTheme.ICON_L)
	back.tooltip_text = tr("ui.back")
	back.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN_PX, UiTheme.TOUCH_MIN_PX)
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(back)
	var title_column := UiKit.vbox(6)
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sign_board := UiKit.sign_board("fish", tr("ui.journal.title"))
	sign_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_column.add_child(sign_board)
	var subtitle := UiKit.label(tr("ui.journal.subtitle"), "LightLabel", HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.text_size(subtitle, "caption")
	title_column.add_child(subtitle)
	header.add_child(title_column)
	var counter_pill := PanelContainer.new()
	counter_pill.theme_type_variation = "PillPanel"
	counter_pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var counter_box := UiKit.hbox(8)
	counter_box.add_child(UiKit.icon("fish", UiTheme.ICON_M, UiTheme.PILL_TEXT))
	var counter_text := UiKit.vbox(0)
	var counter_caption := UiKit.label(tr("ui.journal.found"), "PillLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	UiKit.text_size(counter_caption, "caption")
	counter_text.add_child(counter_caption)
	_counter = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	counter_text.add_child(_counter)
	counter_box.add_child(counter_text)
	counter_pill.add_child(counter_box)
	header.add_child(counter_pill)
	column.add_child(header)

	# Tabs.
	var tab_row := UiKit.hbox(6)
	for entry in TABS:
		var tab_id: String = entry[0]
		var button := UiKit.icon_button(entry[1], tr(entry[2]), func() -> void: select_tab(tab_id), "TabButton", UiTheme.ICON_S, false)
		button.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX)
		button.add_theme_constant_override("h_separation", 2)
		button.custom_minimum_size.x = 104
		_tabs[tab_id] = button
		tab_row.add_child(button)
	_all_dot = UiKit.notice_dot(_tabs["all"])
	# Seven tabs do not fit a phone in every language: the strip scrolls sideways instead of squeezing.
	var tab_scroll := ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size.y = UiTheme.TOUCH_MIN_PX + 8
	tab_scroll.add_child(tab_row)
	column.add_child(tab_scroll)

	# Notebook: cards on the left, the chosen fish on the right.
	var book := UiKit.hbox(8)
	book.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := PanelContainer.new()
	left.theme_type_variation = "NotebookPanel"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.92
	var left_box := UiKit.vbox(8)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	left_box.add_child(_scroll)
	var left_footer := UiKit.hbox(8)
	var progress_pill := PanelContainer.new()
	progress_pill.theme_type_variation = "PillPanel"
	var progress_row := UiKit.hbox(6)
	_progress = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	UiKit.text_size(_progress, "caption")
	progress_row.add_child(_progress)
	progress_pill.add_child(progress_row)
	progress_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_footer.add_child(progress_pill)
	_sort_button = UiKit.icon_button("sort", "", _next_sort, "", UiTheme.ICON_S, false)
	_sort_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sort_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.text_size(_sort_button, "caption")
	_sort_button.add_theme_constant_override("h_separation", 4)
	left_footer.add_child(_sort_button)
	left_box.add_child(left_footer)
	left.add_child(UiKit.margin(left_box, 12))
	book.add_child(left)

	var right := PanelContainer.new()
	right.theme_type_variation = "PaperPanel"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page = UiKit.vbox(10)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_name = UiKit.label("", "BigLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	_page.add_child(_page_name)
	_page_line = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	_page.add_child(_page_line)
	var picture := PanelContainer.new()
	var water := StyleBoxFlat.new()
	water.bg_color = Color("#7cc4bd")
	water.set_corner_radius_all(18)
	water.border_color = Color("#5aa39b")
	water.set_border_width_all(2)
	picture.add_theme_stylebox_override("panel", water)
	_page_portrait = UiKit.FishPortrait.new()
	_page_portrait.custom_minimum_size = Vector2(0, 170)
	picture.add_child(_page_portrait)
	_page_moment = _moment_picture(null, 170.0)
	_page_moment.visible = false
	picture.add_child(_page_moment)
	_page.add_child(picture)
	_page_rows = UiKit.vbox(0)
	_page.add_child(_page_rows)
	var home := PanelContainer.new()
	home.theme_type_variation = "CardPanel"
	var home_box := UiKit.vbox(6)
	var home_head := UiKit.hbox(6)
	home_head.add_child(UiKit.icon("star", UiTheme.ICON_S, UiTheme.GOLD))
	_home_title = UiKit.label(tr("ui.journal.home"), "", HORIZONTAL_ALIGNMENT_LEFT, false)
	home_head.add_child(_home_title)
	home_box.add_child(home_head)
	_home_view = HomeView.new()
	_home_view.custom_minimum_size = Vector2(0, 110)
	_home_place = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	var place_pill := PanelContainer.new()
	place_pill.theme_type_variation = "PillPanel"
	place_pill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	place_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	place_pill.offset_left = 8
	place_pill.offset_bottom = -8
	var place_row := UiKit.hbox(4)
	place_row.add_child(UiKit.icon("pin", UiTheme.ICON_S, UiTheme.PILL_TEXT))
	place_row.add_child(_home_place)
	place_pill.add_child(place_row)
	_home_view.add_child(place_pill)
	home_box.add_child(_home_view)
	_home_text = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	home_box.add_child(_home_text)
	home.add_child(UiKit.margin(home_box, 12))
	_page.add_child(home)
	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_right", 12)  # keep the text clear of the scroll bar
	page_margin.add_child(_page)
	right_scroll.add_child(page_margin)
	right.add_child(UiKit.margin(right_scroll, 14))
	book.add_child(right)
	column.add_child(book)

func setup(p_journal: JournalModel, p_region_id: String) -> void:
	journal = p_journal
	region_id = p_region_id

## Rebuilds the cards and the page from the current save.
func refresh() -> void:
	if tab == "moments":
		_refresh_moments()
		return
	_page_rows.get_parent().get_child(_page_rows.get_index() + 1).visible = true  # the home-waters card
	_page_portrait.get_parent().visible = true
	_page_portrait.visible = true
	_page_moment.visible = false
	for child in _list.get_children():
		_list.remove_child(child)  # gone at once: a queued free would leave old cards in the layout this frame
		child.queue_free()
	_cards.clear()
	var all_entries := _entries_for("all")
	var discovered := 0
	for entry in all_entries:
		if entry.discovered:
			discovered += 1
	_counter.text = "%d / %d" % [discovered, all_entries.size()]
	var entries := _sorted(_entries_for(tab))
	var tab_found := 0
	for entry in entries:
		if entry.discovered:
			tab_found += 1
		var card := _card(entry)
		_cards[entry.fish_id] = card
		_list.add_child(card)
	_progress.text = tr("ui.journal.progress") % [tab_found, entries.size()]
	for tab_id in _tabs:
		(_tabs[tab_id] as Button).theme_type_variation = "TabSelected" if tab_id == tab else "TabButton"
	_sort_button.text = tr("ui.journal.sort." + sort_mode)
	_sort_button.visible = true
	if selected_id.is_empty() or not _cards.has(selected_id):
		selected_id = _first_interesting(entries)
	_show_page(selected_id)
	_all_dot.visible = GameState.has_unseen_journal_entries()
	if _cards.has(selected_id):
		_scroll_to_card.call_deferred(_cards[selected_id])

## Deferred: by then the journal may have been closed (or the card rebuilt) in the same frame.
func _scroll_to_card(card: Control) -> void:
	if is_instance_valid(card) and card.is_inside_tree() and _scroll.is_ancestor_of(card):
		_scroll.ensure_control_visible(card)

func select_tab(tab_id: String) -> void:
	tab = tab_id
	selected_id = ""
	refresh()

## Chooses the page to show at the next refresh without building anything yet, switching to the "all"
## tab when the current one does not hold the fish. Used before the panel opens, so the refresh that
## opening does lands on this fish (and never shows, and marks as seen, another one first).
func preselect(fish_id: String) -> void:
	if ContentDB.get_fish(fish_id).is_empty():
		return
	var in_tab := false
	for entry in _entries_for(tab):
		if entry.fish_id == fish_id:
			in_tab = true
			break
	if not in_tab:
		tab = "all"
	selected_id = fish_id

## Opens the page of `fish_id` now (see `preselect`).
func focus_fish(fish_id: String) -> void:
	preselect(fish_id)
	refresh()

func card_count() -> int:
	return _cards.size()

func select_fish(fish_id: String) -> void:
	selected_id = fish_id
	for id in _cards:
		(_cards[id] as Button).theme_type_variation = "CardSelected" if id == fish_id else ""
	_show_page(fish_id)

func _next_sort() -> void:
	sort_mode = SORTS[(SORTS.find(sort_mode) + 1) % SORTS.size()]
	refresh()

# --- data ---

func _entries_for(tab_id: String) -> Array[JournalModel.Entry]:
	var spec: Array = TABS[0]
	for entry in TABS:
		if entry[0] == tab_id:
			spec = entry
	var regions: Array = spec[3]
	var min_rarity: int = spec[4]
	var entries: Array[JournalModel.Entry] = []
	for fish_id in ContentDB.fish:
		var def: Dictionary = ContentDB.fish[fish_id]
		if int(def["rarity"]) < min_rarity:
			continue
		if not regions.is_empty() and not _shares_region(def, regions):
			continue
		entries.append(journal.entry_for(def, GameState.get_collection_record(fish_id)))
	return entries

static func _shares_region(def: Dictionary, regions: Array) -> bool:
	for id in def.get("regions", []):
		if id in regions:
			return true
	return false

func _sorted(entries: Array[JournalModel.Entry]) -> Array[JournalModel.Entry]:
	var order := {}
	for i in entries.size():
		order[entries[i].fish_id] = i
	var records := {}
	for entry in entries:
		records[entry.fish_id] = GameState.get_collection_record(entry.fish_id)
	var names := {}
	for entry in entries:
		names[entry.fish_id] = tr(ContentDB.get_fish(entry.fish_id).get("name_key", ""))
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a: JournalModel.Entry, b: JournalModel.Entry) -> bool:
		if a.discovered != b.discovered:
			return a.discovered  # met species first, the unmet keep catalog order after them
		if not a.discovered:
			return order[a.fish_id] < order[b.fish_id]
		match sort_mode:
			"name":
				return names[a.fish_id] < names[b.fish_id]
			"size":
				if a.largest_cm != b.largest_cm:
					return a.largest_cm > b.largest_cm
		var first_a := int(records[a.fish_id]["first_seen_at"])
		var first_b := int(records[b.fish_id]["first_seen_at"])
		if first_a != first_b:
			return first_a < first_b
		return order[a.fish_id] < order[b.fish_id])
	return sorted

func _first_interesting(entries: Array[JournalModel.Entry]) -> String:
	for entry in entries:
		if entry.discovered and GameState.get_collection_record(entry.fish_id)["journal_seen"] != true:
			return entry.fish_id
	return entries[0].fish_id if not entries.is_empty() else ""

# --- cards ---

func _card(entry: JournalModel.Entry) -> Button:
	var def := ContentDB.get_fish(entry.fish_id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 168)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.theme_type_variation = "CardSelected" if entry.fish_id == selected_id else ""
	var fish_id := entry.fish_id
	card.pressed.connect(func() -> void: select_fish(fish_id))
	var name_text := tr(def["name_key"]) if entry.show_name else tr("ui.journal.unknown_name")
	card.tooltip_text = name_text
	var box := UiKit.vbox(2)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 8
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := UiKit.FishPortrait.new(entry.fish_id, entry.discovered)
	portrait.custom_minimum_size = Vector2(0, 104)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(portrait)
	var caption := UiKit.label(name_text, "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	caption.add_theme_color_override("font_color", UiTheme.INK)
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(caption)
	card.add_child(box)
	if entry.tier >= 4:
		var crown := UiKit.icon("crown", UiTheme.ICON_M, UiTheme.GOLD)
		crown.position = Vector2(10, 8)
		crown.size = Vector2(30, 30)
		card.add_child(crown)
	if entry.discovered and GameState.get_collection_record(entry.fish_id)["journal_seen"] != true:
		card.add_child(_new_badge())
	return card

static func _new_badge() -> Control:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.NOTICE
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	var text := UiKit.label("NEW", "PillLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	UiKit.text_size(text, "caption")
	badge.add_child(text)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = -8
	badge.offset_top = 8
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.name = "NewBadge"
	return badge

# --- page ---

func _show_page(fish_id: String) -> void:
	for child in _page_rows.get_children():
		_page_rows.remove_child(child)
		child.queue_free()
	var def := ContentDB.get_fish(fish_id)
	if def.is_empty():
		_page.visible = false
		return
	_page.visible = true
	var record := GameState.get_collection_record(fish_id)
	var entry := journal.entry_for(def, record)
	_page_portrait.fish_id = fish_id
	_page_portrait.known = entry.discovered
	_page_portrait.queue_redraw()
	if not entry.discovered:
		_page_name.text = tr("ui.journal.unknown_name")
		_page_line.text = tr("ui.journal.unknown_hint")
	else:
		_page_name.text = tr(def["name_key"])
		if entry.show_behavior:
			_page_line.text = "%s\n%s" % [tr("ui.behavior." + String(def.get("behavior", "steady"))), tr(def["journal_key"])]
		else:
			_page_line.text = tr("ui.catch.flavor." + String(def.get("behavior", "steady")))
	var reveal: Dictionary = ContentDB.balance["journal"]["reveal_at_encounters"]
	_row("calendar", "ui.journal.row.first_met", InspectPanel.date_text(int(record["first_seen_at"]), false) if entry.discovered else "", entry.discovered, int(reveal["size"]))
	var weather_id: String = record.get("first_weather", "")
	var weather_text := tr(ContentDB.get_weather(weather_id).get("name_key", "")) if not weather_id.is_empty() else tr("ui.journal.not_recorded")
	_row(UiIcons.for_weather(weather_id), "ui.journal.row.weather", weather_text, entry.discovered, int(reveal["size"]))
	var places: Array[String] = []
	for habitat in def["habitats"]:
		places.append(tr("ui.habitat." + habitat))
	_row("lake", "ui.journal.row.habitat", ", ".join(places), entry.show_habitats, int(reveal["habitats"]))
	var bands: Array[String] = []
	for band in TimeService.TIME_BANDS:
		if float(def["time_bands"].get(band, 1.0)) >= 1.05:
			bands.append(tr("ui.time." + band))
	_row("clock", "ui.journal.row.time", ", ".join(bands) if not bands.is_empty() else tr("ui.journal.any_time"), entry.show_time_bands, int(reveal["time_bands"]))
	_row("ruler", "ui.journal.row.largest", tr("ui.inspect.size") % entry.largest_cm, entry.discovered, int(reveal["size"]))
	_row("fish", "ui.journal.row.met", tr("ui.journal.times") % entry.encounters, entry.discovered, int(reveal["size"]))
	var home_region: String = def.get("regions", [""])[0]
	_home_place.text = tr(ContentDB.get_region(home_region).get("name_key", ""))
	_home_view.region_id = home_region
	_home_view.queue_redraw()
	_home_text.text = tr("ui.journal.home_text") % ", ".join(places) if entry.show_habitats else tr("ui.journal.locked") % int(reveal["habitats"])
	if entry.discovered:
		GameState.mark_journal_seen(fish_id)
		var badge := (_cards[fish_id] as Node).get_node_or_null("NewBadge") if _cards.has(fish_id) else null
		if badge != null:
			badge.queue_free()
		_all_dot.visible = GameState.has_unseen_journal_entries()

## One fact row; a locked fact says how many meetings open it.
func _row(icon_name: String, caption_key: String, value: String, open: bool, needed: int) -> void:
	# Two lines: the caption with its icon, then the value under it on the right. The page is too narrow
	# for both on one line: captions and values were squeezed into columns and broke every few letters.
	var row := UiKit.vbox(0)
	row.custom_minimum_size.y = 54
	var head := UiKit.hbox(8)
	head.add_child(UiKit.icon(icon_name, UiTheme.ICON_S, UiTheme.INK_DIM))
	var caption := UiKit.label(tr(caption_key), "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	UiKit.text_size(caption, "caption")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(caption)
	row.add_child(head)
	var shown := UiKit.label(value if open else tr("ui.journal.locked") % needed, "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT, true)
	if open:
		shown.add_theme_color_override("font_color", UiTheme.INK)
	row.add_child(shown)
	_page_rows.add_child(row)
	var line := ColorRect.new()
	line.color = Color(UiTheme.CREAM_BORDER, 0.6)
	line.custom_minimum_size = Vector2(0, 1)
	_page_rows.add_child(line)

# --- moments (P1-008) ---

func _refresh_moments() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	var seen := 0
	for moment_id in ContentDB.moments:
		if GameState.has_moment(moment_id):
			seen += 1
		var card := _moment_card(moment_id)
		_cards[moment_id] = card
		_list.add_child(card)
	_progress.text = tr("ui.journal.progress") % [seen, ContentDB.moments.size()]
	_sort_button.visible = false  # moments keep the order they are listed in; there is nothing to sort
	for tab_id in _tabs:
		(_tabs[tab_id] as Button).theme_type_variation = "TabSelected" if tab_id == tab else "TabButton"
	if selected_id.is_empty() or not _cards.has(selected_id):
		selected_id = ContentDB.moments.keys()[0] if not ContentDB.moments.is_empty() else ""
	_show_moment(selected_id)

func _moment_card(moment_id: String) -> Button:
	var def: Dictionary = ContentDB.moments[moment_id]
	var seen: bool = GameState.has_moment(moment_id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 168)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.theme_type_variation = "CardSelected" if moment_id == selected_id else ""
	card.pressed.connect(func() -> void:
		selected_id = moment_id
		for id in _cards:
			(_cards[id] as Button).theme_type_variation = "CardSelected" if id == moment_id else ""
		_show_moment(moment_id))
	var box := UiKit.vbox(6)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 18
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := ArtLibrary.texture("moments", moment_id) if seen else null
	var picture: Control
	if art != null:
		picture = _moment_picture(art, MOMENT_CARD_PICTURE_PX)
		picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		picture = UiKit.icon(def["icon"] if seen else "lock", UiTheme.ICON_XL, UiTheme.GREEN if seen else Color(UiTheme.INK_DIM, 0.5))
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(picture)
	var caption := UiKit.label(tr(def["name_key"]) if seen else tr("ui.journal.unknown_name"), "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, true)
	caption.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(caption)
	card.add_child(box)
	card.tooltip_text = caption.text
	return card

func _show_moment(moment_id: String) -> void:
	for child in _page_rows.get_children():
		_page_rows.remove_child(child)
		child.queue_free()
	_page_portrait.get_parent().visible = false
	_page_rows.get_parent().get_child(_page_rows.get_index() + 1).visible = false  # the home-waters card
	var def: Dictionary = ContentDB.moments.get(moment_id, {})
	if def.is_empty():
		return
	var seen: bool = GameState.has_moment(moment_id)
	var art := ArtLibrary.texture("moments", moment_id) if seen else null
	if art != null:  # a seen moment with a picture shows it; the others keep the page text-only
		_page_portrait.get_parent().visible = true
		_page_portrait.visible = false
		_page_moment.texture = art
		_page_moment.visible = true
	_page_name.text = tr(def["name_key"]) if seen else tr("ui.journal.unknown_name")
	_page_line.text = tr(def["desc_key"]) if seen else tr(def["hint_key"])
	_row("calendar", "ui.journal.row.seen_on", InspectPanel.date_text(GameState.moment_seen_at(moment_id), false) if seen else "", seen, 1)
	_row("memory", "ui.journal.row.memory", "+%d" % int(def.get("memory", 0)), true, 0)

## A moment's picture filling `height` px of its box, cropped to keep its proportions.
static func _moment_picture(art: Texture2D, height: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = art
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = Vector2(0, height)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

## True when the open moment page shows the moment's drawn picture.
func page_shows_moment_art() -> bool:
	return _page_moment.visible and _page_moment.get_parent().visible

## A tiny painted view of the species' home water (until region thumbnails arrive as art).
class HomeView extends Control:
	var region_id := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		var layout := ContentDB.get_layout(region_id)
		var palette: Dictionary = layout.get("levels", [{}])[-1] if not layout.is_empty() else {}
		var water := Color(palette.get("water_shallow", "#5fb3a9"))
		var grass := Color(palette.get("grass", "#6db35e"))
		var box := StyleBoxFlat.new()
		box.bg_color = grass
		box.set_corner_radius_all(14)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var pond := PackedVector2Array()
		for i in 24:
			var angle := TAU * i / 24.0
			pond.append(size * Vector2(0.55, 0.58) + Vector2(cos(angle) * size.x * 0.42, sin(angle) * size.y * 0.36))
		draw_colored_polygon(pond, water)
		for i in 3:
			draw_circle(size * Vector2(0.2 + i * 0.28, 0.2), size.y * 0.18, grass.darkened(0.25))
		draw_circle(size * Vector2(0.7, 0.62), size.y * 0.08, Color("#4f9a5a"))
		draw_circle(size * Vector2(0.68, 0.6), size.y * 0.035, Color("#fdfcf5"))
