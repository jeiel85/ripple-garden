class_name GearPanel
extends Control

## The equipment screen (UI_UX §2 Gear, mockup 05, D-019): a wooden "장비" sign, tabs for rods, bait,
## bags and accessories, the chosen item large (picture, grade, description, the rod's three
## character bars, and one clear action), the list of the tab's items, and two small summaries of the
## bait being carried and the bag carrying it.
##
## The screen only asks; LoadoutService decides what can be equipped or bought and tells the screen
## what to say about every item (owned / price / which restoration opens it / a keepsake to come).

signal close_pressed
signal message(text: String)

const FULLSCREEN := true
const KEEPS_STATUS := true

## [category, icon, tab label key]
const TABS: Array = [
	["rod", "rod", "ui.gear.tab.rod"], ["bait", "bait", "ui.gear.tab.bait"],
	["bag", "bag", "ui.gear.tab.bag"], ["accessory", "hat", "ui.gear.tab.accessory"],
]

var tab := "rod"
var selected_id := ""

var _loadout: LoadoutService
var _tabs: Dictionary = {}
var _art: ItemArt
var _name: Label
var _grade: Label
var _grade_pill: PanelContainer
var _desc: Label
var _details: VBoxContainer
var _actions: HBoxContainer
var _dots: HBoxContainer
var _list_title: Label
var _list_icon: TextureRect
var _list_count: Label
var _list: HBoxContainer
var _list_scroll: ScrollContainer
var _cards: Dictionary = {}
var _bait_summary: HBoxContainer
var _bait_count: Label
var _bag_summary: HBoxContainer
var _bag_count: Label

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var page := MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 16)
	page.add_theme_constant_override("margin_top", 112)
	page.add_theme_constant_override("margin_bottom", 20)
	add_child(page)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var column := UiKit.vbox(12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	# Header: back, then the wooden sign with its subtitle.
	var header := UiKit.hbox(10)
	var back := UiKit.icon_button("back", "", func() -> void: close_pressed.emit(), "CircleButton", UiTheme.ICON_L)
	back.tooltip_text = tr("ui.back")
	back.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN_PX, UiTheme.TOUCH_MIN_PX)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	var sign_board := PanelContainer.new()
	sign_board.theme_type_variation = "SignPanel"
	sign_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sign_row := UiKit.hbox(14)
	sign_row.add_child(UiKit.icon("gear", UiTheme.ICON_L, UiTheme.WOOD_TEXT))
	var sign_text := UiKit.vbox(0)
	sign_text.add_child(UiKit.label(tr("ui.gear.title"), "SignLabel", HORIZONTAL_ALIGNMENT_LEFT, false))
	var subtitle := UiKit.label(tr("ui.gear.subtitle"), "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	subtitle.add_theme_color_override("font_color", UiTheme.WOOD_TEXT)
	sign_text.add_child(subtitle)
	sign_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_row.add_child(sign_text)
	sign_board.add_child(sign_row)
	header.add_child(sign_board)
	column.add_child(header)

	var tab_row := UiKit.hbox(6)
	for entry in TABS:
		var category: String = entry[0]
		var button := UiKit.icon_button(entry[1], tr(entry[2]), func() -> void: select_tab(category), "TabButton", UiTheme.ICON_S, false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[category] = button
		tab_row.add_child(button)
	column.add_child(tab_row)

	column.add_child(_build_featured())
	column.add_child(_build_list())
	var summaries := UiKit.hbox(10)
	summaries.add_child(_build_summary("bait"))
	summaries.add_child(_build_summary("bag"))
	column.add_child(summaries)

func _build_featured() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	var row := UiKit.hbox(14)
	var picture := UiKit.vbox(6)
	var art_box := Control.new()
	art_box.custom_minimum_size = Vector2(230, 200)
	_art = ItemArt.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_box.add_child(_art)
	for side in [-1, 1]:
		var arrow := UiKit.icon_button("back" if side < 0 else "forward", "", func() -> void: _step(side), "CircleButton", UiTheme.ICON_S)
		arrow.tooltip_text = tr("ui.gear.prev") if side < 0 else tr("ui.gear.next")
		arrow.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN_PX * 0.75, UiTheme.TOUCH_MIN_PX * 0.75)
		if side > 0:
			arrow.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			arrow.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		else:
			arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		arrow.grow_vertical = Control.GROW_DIRECTION_BOTH
		art_box.add_child(arrow)
	picture.add_child(art_box)
	_dots = UiKit.hbox(8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	picture.add_child(_dots)
	row.add_child(picture)

	var info := UiKit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UiKit.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	info.add_child(_name)
	_grade_pill = PanelContainer.new()
	_grade_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grade = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	_grade_pill.add_child(_grade)
	info.add_child(_grade_pill)
	_desc = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	_desc.custom_minimum_size.x = 200
	UiKit.text_size(_desc, "small")
	info.add_child(_desc)
	_details = UiKit.vbox(6)
	info.add_child(_details)
	_actions = UiKit.hbox(8)
	info.add_child(_actions)
	row.add_child(info)
	card.add_child(UiKit.margin(row, 12))
	return card

func _build_list() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	var box := UiKit.vbox(8)
	var head := UiKit.hbox(8)
	_list_icon = UiKit.icon("rod", UiTheme.ICON_M, UiTheme.INK)
	head.add_child(_list_icon)
	_list_title = UiKit.label("", "", HORIZONTAL_ALIGNMENT_LEFT, false)
	_list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_list_title)
	_list_count = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT, false)
	head.add_child(_list_count)
	box.add_child(head)
	_list_scroll = ScrollContainer.new()
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.custom_minimum_size = Vector2(0, 178)
	_list = UiKit.hbox(8)
	_list_scroll.add_child(_list)
	box.add_child(_list_scroll)
	card.add_child(UiKit.margin(box, 14))
	return card

## The small bait / bag summaries under the list ("미끼 보유 8/16", "가방 슬롯 12/20", "변경").
func _build_summary(category: String) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(8)
	var head := UiKit.hbox(6)
	head.add_child(UiKit.icon(category if category == "bait" else "bag", UiTheme.ICON_S, UiTheme.INK))
	var title := UiKit.label(tr("ui.gear.tab." + category), "", HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.text_size(title, "small")  # two summaries share a row: a compact head
	head.add_child(title)
	var count := UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT, false)
	UiKit.text_size(count, "caption")
	head.add_child(count)
	box.add_child(head)
	var items := UiKit.hbox(6)
	box.add_child(items)
	var change := UiKit.icon_button(category if category == "bait" else "bag", tr("ui.gear.change"), func() -> void: select_tab(category), "GreenButton", UiTheme.ICON_M, false)
	box.add_child(change)
	card.add_child(UiKit.margin(box, 12))
	if category == "bait":
		_bait_summary = items
		_bait_count = count
	else:
		_bag_summary = items
		_bag_count = count
	return card

func setup(loadout: LoadoutService) -> void:
	_loadout = loadout

func select_tab(category: String) -> void:
	tab = category
	selected_id = _loadout.equipped(category)
	refresh()

func select_item(item_id: String) -> void:
	selected_id = item_id
	refresh()

## Rebuilds everything from the current save.
func refresh() -> void:
	if _loadout == null:
		return
	var items := LoadoutService.catalog(tab)
	if selected_id.is_empty() or not selected_id in items:
		selected_id = _loadout.equipped(tab)
	for category in _tabs:
		(_tabs[category] as Button).theme_type_variation = "TabSelected" if category == tab else "TabButton"
	_fill_list(items)
	_show_featured()
	_fill_summaries()

func card_count() -> int:
	return _cards.size()

# --- featured item ---

func _show_featured() -> void:
	var def := ContentDB.get_item(tab, selected_id)
	var deal := _loadout.offer(tab, selected_id)
	_art.show_item(tab, selected_id, deal["state"] == LoadoutService.LOCKED)
	_name.text = tr(def.get("name_key", ""))
	_desc.text = tr(def.get("desc_key", ""))
	var grade: String = def.get("grade", "")
	_grade_pill.visible = not grade.is_empty()
	if not grade.is_empty():
		_grade.text = tr("ui.gear.grade." + grade)
		_grade_pill.add_theme_stylebox_override("panel", grade_box(grade))
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	match tab:
		"rod":
			var stats := LoadoutService.rod_stats(def)
			_details.add_child(_stat_bar("ui.gear.stat.control", "rod", stats["control"], Color("#6f9a52")))
			_details.add_child(_stat_bar("ui.gear.stat.sensitivity", "clock", stats["sensitivity"], Color("#5f86b0")))
			_details.add_child(_stat_bar("ui.gear.stat.durability", "star", stats["durability"], Color("#b07a4f")))
			_details.add_child(UiKit.label(tr("ui.gear.reach") % roundi(float(def.get("range", 0.0)) * 100.0), "SmallLabel"))
		"bait":
			var stock := _loadout.bait_stock(selected_id)
			_details.add_child(UiKit.label(tr("ui.gear.endless") if stock < 0 else tr("ui.gear.count") % stock, ""))
		"bag":
			_details.add_child(UiKit.label(tr("ui.gear.capacity") % int(def.get("capacity", 0)), ""))
	_fill_actions(deal)
	for child in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	var items := LoadoutService.catalog(tab)
	var index := items.find(selected_id)
	for i in range(maxi(0, index - 2), mini(items.size(), index + 3)):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = UiTheme.INK if i == index else Color(UiTheme.INK, 0.25)
		_dots.add_child(dot)

## The one clear thing to do with the item (two for a bait: use it, and add a pack).
func _fill_actions(deal: Dictionary) -> void:
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var owned := _loadout.is_owned(tab, selected_id)
	if owned:
		var is_equipped := _loadout.equipped(tab) == selected_id
		var usable := tab != "bait" or _loadout.bait_stock(selected_id) != 0
		var equip := UiKit.icon_button("check", tr("ui.gear.equipped") if is_equipped else tr("ui.gear.equip"),
			func() -> void: _equip(), "GreenButton", UiTheme.ICON_M, false)
		# "Equipped" stays solid green like the mockup; pressing it does nothing.
		equip.disabled = not usable
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not usable:
			equip.text = tr("ui.gear.out_of_stock")
		_actions.add_child(equip)
		if tab != "bait" or deal["currency"].is_empty():
			return
	var action := _offer_button(deal)
	if action != null:
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actions.add_child(action)

func _offer_button(deal: Dictionary) -> Button:
	var currency := tr("ui.currency." + String(deal["currency"])) if not String(deal["currency"]).is_empty() else ""
	match deal["state"]:
		LoadoutService.BUY:
			var text := tr("ui.gear.buy_pack") % [deal["pack"], currency, deal["amount"]] if tab == "bait" else tr("ui.gear.buy") % [currency, deal["amount"]]
			return UiKit.icon_button(deal["currency"] if deal["currency"] == "ripple" else "memory", text, func() -> void: _buy(), "WaterButton", UiTheme.ICON_M, false)
		LoadoutService.TOO_DEAR:
			return _disabled("ripple" if deal["currency"] == "ripple" else "memory", "%s · %s %d" % [tr("ui.gear.not_enough") % currency, currency, deal["amount"]])
		LoadoutService.LOCKED:
			return _disabled("lock", tr("ui.gear.locked") % [_region_name(deal["region"]), deal["level"]])
		LoadoutService.GIFT_LATER:
			return _disabled("star", tr("ui.gear.granted") % [_region_name(deal["region"]), deal["level"]])
		LoadoutService.BAG_FULL:
			return _disabled("bag", tr("ui.gear.bag_full"))
	return null

func _disabled(icon_name: String, text: String) -> Button:
	var button := UiKit.icon_button(icon_name, text, func() -> void: pass, "", UiTheme.ICON_S, false)
	button.disabled = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.text_size(button, "caption")
	return button

func _stat_bar(caption_key: String, icon_name: String, value: int, color: Color) -> Control:
	var row := UiKit.hbox(8)
	row.add_child(UiKit.icon(icon_name, UiTheme.ICON_S, UiTheme.INK_DIM))
	var caption := UiKit.label(tr(caption_key), "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	caption.custom_minimum_size.x = 76
	UiKit.text_size(caption, "caption")
	row.add_child(caption)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = value
	bar.custom_minimum_size = Vector2(80, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	row.add_child(UiKit.label(str(value), "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT, false))
	return row

# --- list ---

func _fill_list(items: Array) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	_list_icon.texture = UiIcons.texture(TABS[_tab_index()][1])
	_list_title.text = tr("ui.gear.list." + tab)
	_list_count.text = tr("ui.gear.owned") % [_loadout.owned(tab).size(), items.size()]
	for item_id in items:
		var card := _card(item_id)
		_cards[item_id] = card
		_list.add_child(card)
	if _cards.has(selected_id):
		_list_scroll.ensure_control_visible.call_deferred(_cards[selected_id])

func _card(item_id: String) -> Button:
	var def := ContentDB.get_item(tab, item_id)
	var deal := _loadout.offer(tab, item_id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(146, 176)
	card.theme_type_variation = "CardSelected" if item_id == selected_id else ""
	card.tooltip_text = tr(def.get("name_key", ""))
	card.pressed.connect(func() -> void: select_item(item_id))
	var box := UiKit.vbox(2)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 6
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := ItemArt.new(tab, item_id)
	art.faded = deal["state"] == LoadoutService.LOCKED
	art.custom_minimum_size = Vector2(0, 92)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	var caption := UiKit.label(tr(def.get("name_key", "")), "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	caption.add_theme_color_override("font_color", UiTheme.INK)
	UiKit.text_size(caption, "caption")
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(caption)
	var grade: String = def.get("grade", "")
	if not grade.is_empty():
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", grade_box(grade))
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var grade_label := UiKit.label(tr("ui.gear.grade." + grade), "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
		UiKit.text_size(grade_label, "caption")
		grade_label.add_theme_color_override("font_color", Color.WHITE)
		pill.add_child(grade_label)
		box.add_child(pill)
	elif tab == "bait":
		var stock := _loadout.bait_stock(item_id)
		box.add_child(UiKit.label(tr("ui.gear.endless") if stock < 0 else tr("ui.gear.count") % stock, "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
	card.add_child(box)
	if _loadout.equipped(tab) == item_id:
		var check := _badge("check", UiTheme.GREEN)
		card.add_child(check)
	return card

static func _badge(icon_name: String, color: Color) -> Control:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 4)
	badge.add_theme_stylebox_override("panel", style)
	badge.add_child(UiKit.icon(icon_name, UiTheme.ICON_S, Color.WHITE))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = -4
	badge.offset_top = 4
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge

## The coloured pill behind a grade name: grey-beige, blue, purple, pink (mockup 05).
static func grade_box(grade: String) -> StyleBoxFlat:
	var colors := {"common": Color("#b5a88f"), "uncommon": Color("#6f94c9"), "rare": Color("#9a7cc9"), "event": Color("#e0849f")}
	var style := StyleBoxFlat.new()
	style.bg_color = colors.get(grade, colors["common"])
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

# --- summaries ---

func _fill_summaries() -> void:
	for box in [_bait_summary, _bag_summary]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_bait_count.text = tr("ui.gear.owned") % [_loadout.owned("bait").size(), LoadoutService.catalog("bait").size()]
	_bag_count.text = tr("ui.gear.slots") % [_loadout.carried_baits(), _loadout.bag_capacity()]
	for bait_id in _loadout.owned("bait").slice(0, 4):
		_bait_summary.add_child(_mini("bait", bait_id))
	for bag_id in _loadout.owned("bag").slice(0, 4):
		_bag_summary.add_child(_mini("bag", bag_id))

func _mini(category: String, item_id: String) -> Control:
	var box := UiKit.vbox(0)
	var art := ItemArt.new(category, item_id)
	art.custom_minimum_size = Vector2(62, 62)
	box.add_child(art)
	var text := ""
	if category == "bait":
		var stock := _loadout.bait_stock(item_id)
		text = "∞" if stock < 0 else "x%d" % stock
	var caption := UiKit.label(text, "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	UiKit.text_size(caption, "caption")
	box.add_child(caption)
	if _loadout.equipped(category) == item_id:
		art.add_child(_badge("check", UiTheme.GREEN))
	return box

# --- commands ---

func _equip() -> void:
	if _loadout.equipped(tab) == selected_id:
		return
	if _loadout.equip(tab, selected_id):
		refresh()

func _buy() -> void:
	var def := ContentDB.get_item(tab, selected_id)
	if _loadout.buy(tab, selected_id):
		message.emit(tr("ui.toast.bought") % tr(def.get("name_key", "")))
		refresh()

func _step(direction: int) -> void:
	var items := LoadoutService.catalog(tab)
	if items.is_empty():
		return
	var index := items.find(selected_id)
	select_item(items[posmod(index + direction, items.size())])

func _tab_index() -> int:
	for i in TABS.size():
		if TABS[i][0] == tab:
			return i
	return 0

static func _region_name(region_id: String) -> String:
	return TranslationServer.translate(ContentDB.get_region(region_id).get("name_key", region_id))

