class_name CampPanel
extends Control

## Decorating the camp (UI_UX §7, mockup 06, P1-002). The world stays in view and the camera moves in on
## the camp clearing; every anchor slot is marked with a dashed diamond, and the chosen one carries three
## round buttons — turn, done (or buy), put away. A cream sheet at the bottom lists the decorations in four
## tabs (all / placed / furniture / ornaments) and closes with the wooden "완료" button.
##
## Choosing a card puts an owned decoration into the chosen slot at once. A decoration not owned yet is
## offered: its price appears on the done button and pressing it buys and places it. Locked ones say which
## restoration opens them. The screen only asks; CampService and LoadoutService decide.
##
## Its own answers (price, locked, not enough, bought) appear in the pill under the title: the global
## toast sits under open screens, and this sheet covers it.

signal close_pressed

const FULLSCREEN := true
const KEEPS_STATUS := true
## No blur or dim: decorating happens in the world itself.
const BACKDROP := "none"
const TABS: Array = [
	["all", "decorate", "ui.camp.tab.all"], ["placed", "layout", "ui.camp.tab.placed"],
	["furniture", "furniture", "ui.camp.tab.furniture"], ["ornament", "ornament", "ui.camp.tab.ornament"],
]
const MARKER_PX := 96.0

var region_id := ""
var tab := "all"
var selected_slot := ""
## A decoration chosen but not owned yet: the done button buys it.
var pending := ""

var _camp: CampService
var _loadout: LoadoutService
var _markers: Control
var _slot_buttons: Dictionary = {}
var _turn_button: Button
var _confirm_button: Button
var _remove_button: Button
var _tabs: Dictionary = {}
var _cards: HBoxContainer
var _card_nodes: Dictionary = {}
var _note: Label

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_markers = Control.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers)

	var header := UiKit.hbox(10)
	header.position = Vector2(16, 112)
	var back := UiKit.icon_button("back", "", func() -> void: close_pressed.emit(), "CircleButton", UiTheme.ICON_L)
	back.tooltip_text = tr("ui.back")
	back.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN_PX, UiTheme.TOUCH_MIN_PX)
	header.add_child(back)
	var titles := UiKit.vbox(6)
	titles.add_child(UiKit.sign_board("camp", tr("ui.camp.title")))
	var hint := PanelContainer.new()
	hint.theme_type_variation = "PillPanel"
	_note = UiKit.label(tr("ui.camp.subtitle"), "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	hint.add_child(_note)
	titles.add_child(hint)
	header.add_child(titles)
	add_child(header)

	# Cream circles for turning and putting away, a green one for done (mockup 06).
	_turn_button = UiKit.icon_button("rotate", "", func() -> void: _turn(), "CircleButton", UiTheme.ICON_L)
	_turn_button.tooltip_text = tr("ui.camp.turn")
	_confirm_button = UiKit.icon_button("check", "", func() -> void: _confirm(), "GreenCircle", UiTheme.ICON_L)
	_confirm_button.tooltip_text = tr("ui.camp.done_slot")
	_remove_button = UiKit.icon_button("trash", "", func() -> void: _remove(), "CircleButton", UiTheme.ICON_L)
	_remove_button.tooltip_text = tr("ui.camp.remove")
	_remove_button.add_theme_color_override("icon_normal_color", UiTheme.NOTICE)
	for button in [_turn_button, _remove_button]:
		button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN_PX, UiTheme.TOUCH_MIN_PX)
	_confirm_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN_PX * 1.1, UiTheme.TOUCH_MIN_PX * 1.1)
	for button in [_turn_button, _confirm_button, _remove_button]:
		add_child(button)

	var sheet := PanelContainer.new()
	sheet.theme_type_variation = "PaperPanel"
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.offset_left = 8
	sheet.offset_right = -8
	sheet.offset_bottom = -8
	var box := UiKit.vbox(10)
	var tab_row := UiKit.hbox(6)
	for entry in TABS:
		var tab_id: String = entry[0]
		var button := UiKit.icon_button(entry[1], tr(entry[2]), func() -> void: select_tab(tab_id), "TabButton", UiTheme.ICON_S, false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[tab_id] = button
		tab_row.add_child(button)
	box.add_child(tab_row)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 186)
	_cards = UiKit.hbox(8)
	scroll.add_child(_cards)
	box.add_child(scroll)
	var done := UiKit.centered_button("check", tr("ui.camp.finish"), func() -> void: close_pressed.emit(), "WaterButton")
	done.custom_minimum_size = Vector2(320, UiTheme.TOUCH_MIN_PX * 1.2)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(done)
	sheet.add_child(UiKit.margin(box, 14))
	add_child(sheet)

func _enter_tree() -> void:
	_note.text = tr("ui.camp.subtitle")  # every visit starts with the instructions

## The line under the title (instructions, or the answer to the last choice).
func note_text() -> String:
	return _note.text

func _say(text: String) -> void:
	_note.text = text

func setup(camp: CampService, loadout: LoadoutService, p_region_id: String) -> void:
	_camp = camp
	_loadout = loadout
	region_id = p_region_id
	EventBus.camp_changed.connect(func(changed: String) -> void:
		if changed == region_id and is_inside_tree():
			refresh())
	EventBus.economy_changed.connect(func(_ripple: int, _memory: int) -> void:
		if is_inside_tree():
			_fill_cards())

## Rebuilds the slot markers and the cards from the save; chooses a slot if none is chosen.
func refresh() -> void:
	if _camp == null:
		return
	if selected_slot.is_empty() or not _has_slot(selected_slot):
		selected_slot = _first_empty_slot()
	_build_markers()
	for tab_id in _tabs:
		(_tabs[tab_id] as Button).theme_type_variation = "TabSelected" if tab_id == tab else "TabButton"
	_fill_cards()
	_place_buttons()

func select_tab(tab_id: String) -> void:
	tab = tab_id
	refresh()

func select_slot(slot_id: String) -> void:
	selected_slot = slot_id
	pending = ""
	refresh()

## Chooses a decoration for the selected slot (see the class description).
func choose(decoration_id: String) -> void:
	if tab == "placed":
		var where := _camp.slot_of(region_id, decoration_id)
		if not where.is_empty():
			select_slot(where)
		return
	if _loadout.is_owned("decoration", decoration_id):
		pending = ""
		_camp.place(region_id, selected_slot, decoration_id)
		return
	var deal := _loadout.offer("decoration", decoration_id)
	# The latest tap wins: a decoration that cannot be bought drops an earlier offer, so the done
	# button never buys something the player has moved on from.
	if deal["state"] != LoadoutService.BUY and not pending.is_empty():
		pending = ""
		_fill_cards()
		_place_buttons()
	match deal["state"]:
		LoadoutService.BUY:
			pending = decoration_id
			_fill_cards()
			_place_buttons()
			_say(tr("ui.camp.buy_hint") % [tr(ContentDB.get_decoration(decoration_id)["name_key"]), tr("ui.currency." + String(deal["currency"])), deal["amount"]])
		LoadoutService.TOO_DEAR:
			_say(tr("ui.gear.not_enough") % tr("ui.currency." + String(deal["currency"])))
		LoadoutService.LOCKED:
			_say(tr("ui.gear.locked") % [tr(ContentDB.get_region(deal["region"]).get("name_key", "")), deal["level"]])

func card_count() -> int:
	return _card_nodes.size()

# --- slot markers and their three buttons ---

func _build_markers() -> void:
	for child in _markers.get_children():
		_markers.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	for slot in CampService.slots(region_id):
		var slot_id: String = slot["id"]
		var marker := SlotMarker.new()
		marker.selected = slot_id == selected_slot
		marker.filled = not _camp.item_in(region_id, slot_id).is_empty()
		marker.tooltip_text = tr("ui.camp.slot")
		marker.pressed.connect(func() -> void: select_slot(slot_id))
		_markers.add_child(marker)
		_slot_buttons[slot_id] = marker
	_place_markers()

func _process(_delta: float) -> void:
	# The camera glides in when the screen opens; the markers follow the world while it moves.
	if is_visible_in_tree():
		_place_markers()
		_place_buttons()

func _place_markers() -> void:
	if not is_inside_tree():
		return
	var to_screen := get_viewport().get_canvas_transform()
	for slot in CampService.slots(region_id):
		var marker: Control = _slot_buttons.get(slot["id"])
		if marker != null:
			marker.size = Vector2(MARKER_PX, MARKER_PX)
			marker.position = to_screen * (slot["position"] as Vector2) - marker.size / 2.0

func _place_buttons() -> void:
	var marker: Control = _slot_buttons.get(selected_slot)
	var shown := marker != null
	for button in [_turn_button, _confirm_button, _remove_button]:
		button.visible = shown
	if not shown:
		return
	var center := marker.position + marker.size / 2.0
	_turn_button.position = center + Vector2(-158, -70)
	_confirm_button.position = center + Vector2(-53, -168)
	_remove_button.position = center + Vector2(62, -70)
	_remove_button.disabled = _camp.item_in(region_id, selected_slot).is_empty()
	_turn_button.disabled = _remove_button.disabled
	if pending.is_empty():
		_confirm_button.text = ""
		_confirm_button.tooltip_text = tr("ui.camp.done_slot")
	else:
		# The price rides on the done button: pressing it buys and places.
		var deal := _loadout.offer("decoration", pending)
		_confirm_button.text = str(deal["amount"])
		_confirm_button.tooltip_text = "%s · %s %d" % [tr("ui.camp.buy_place"), tr("ui.currency." + String(deal["currency"])), deal["amount"]]

func _confirm() -> void:
	if pending.is_empty():
		selected_slot = ""  # done with this slot
		_build_markers()
		_place_buttons()
		return
	var decoration_id := pending
	pending = ""
	if _camp.buy_and_place(region_id, selected_slot, decoration_id):
		_say(tr("ui.toast.bought") % tr(ContentDB.get_decoration(decoration_id)["name_key"]))
	refresh()

func _turn() -> void:
	_camp.turn(region_id, selected_slot)

func _remove() -> void:
	_camp.remove(region_id, selected_slot)

# --- cards ---

func _fill_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_card_nodes.clear()
	for decoration_id in LoadoutService.catalog("decoration"):
		var def := ContentDB.get_decoration(decoration_id)
		match tab:
			"placed":
				if _camp.slot_of(region_id, decoration_id).is_empty():
					continue
			"furniture", "ornament":
				if def["category"] != tab:
					continue
		var card := _card(decoration_id)
		_card_nodes[decoration_id] = card
		_cards.add_child(card)

func _card(decoration_id: String) -> Button:
	var def := ContentDB.get_decoration(decoration_id)
	var owned := _loadout.is_owned("decoration", decoration_id)
	var deal := _loadout.offer("decoration", decoration_id)
	var in_slot := _camp.item_in(region_id, selected_slot) == decoration_id
	var card := Button.new()
	card.custom_minimum_size = Vector2(140, 180)
	card.theme_type_variation = "CardSelected" if in_slot or decoration_id == pending else ""
	card.tooltip_text = tr(def["name_key"])
	card.pressed.connect(func() -> void: choose(decoration_id))
	var box := UiKit.vbox(2)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 6
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := DecoArt.new(def["prop"], float(def["scale"]))
	art.faded = deal["state"] == LoadoutService.LOCKED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	var caption := UiKit.label(tr(def["name_key"]), "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	caption.add_theme_color_override("font_color", UiTheme.INK)
	UiKit.text_size(caption, "caption")
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(caption)
	if not owned:
		var price := UiKit.label("%s %d" % [tr("ui.currency." + String(deal["currency"])), deal["amount"]] if not String(deal["currency"]).is_empty() else "",
			"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
		UiKit.text_size(price, "caption")
		box.add_child(price)
	card.add_child(box)
	if not _camp.slot_of(region_id, decoration_id).is_empty():
		card.add_child(GearPanel._badge("check", UiTheme.GREEN))
	return card

func _first_empty_slot() -> String:
	var all := CampService.slots(region_id)
	for slot in all:
		if _camp.item_in(region_id, slot["id"]).is_empty():
			return slot["id"]
	return all[0]["id"] if not all.is_empty() else ""

func _has_slot(slot_id: String) -> bool:
	for slot in CampService.slots(region_id):
		if slot["id"] == slot_id:
			return true
	return false

## A camp anchor: a dashed diamond on the ground, bright and pulsing gently when chosen.
class SlotMarker extends Button:
	var selected := false
	var filled := false

	func _init() -> void:
		theme_type_variation = "FlatButton"
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, size.y * 0.18)
		var half := Vector2(size.x * 0.48, size.y * 0.22)
		var points := PackedVector2Array([c + Vector2(-half.x, 0), c + Vector2(0, -half.y), c + Vector2(half.x, 0), c + Vector2(0, half.y), c + Vector2(-half.x, 0)])
		var color := Color(1, 1, 1, 0.95) if selected else Color(1, 1, 1, 0.55)
		if selected:
			draw_colored_polygon(points.slice(0, 4), Color(0.85, 1, 0.7, 0.28))
		for i in 4:
			_dashed(points[i], points[i + 1], color, 3.0 if selected else 2.0)
		if not filled:
			draw_circle(c, 6.0, color)

	func _dashed(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		var length := a.distance_to(b)
		var steps := int(length / 12.0)
		for i in steps:
			if i % 2 == 0:
				draw_line(a.lerp(b, float(i) / steps), a.lerp(b, float(i + 1) / steps), color, width)

## A decoration's picture on a card, drawn with the same painter as the world, shrunk to fit the card
## by the prop's rough size (a tent is wide, a lantern small).
class DecoArt extends Control:
	const KIND_SIZE := {"tent": 2.3, "birdhouse": 1.7, "bench": 1.15, "wood_table": 1.05, "camp_chair": 0.95,
		"crate": 0.95, "campfire": 0.85, "signboard": 0.85, "lantern": 0.6, "flower_pot": 0.65}

	var kind := ""
	var art_scale := 1.0
	var faded := false

	func _init(p_kind: String = "", p_scale: float = 1.0) -> void:
		kind = p_kind
		art_scale = p_scale
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(110, 104)

	func _draw() -> void:
		var radius := minf(size.x, size.y) * 0.46
		draw_circle(size / 2.0, radius, Color("#e7efd9"))
		var palette := {"grass": Color("#76bf62"), "canopy": Color("#45a650"), "water_deep": Color("#16788f"), "water_shallow": Color("#5cc4b2")}
		var art := ArtLibrary.texture("props", kind)
		if art != null:  # drawn art fills the round backdrop whatever its size in the world
			var box := Rect2(size / 2.0 - Vector2.ONE * radius * 0.72, Vector2.ONE * radius * 1.44)
			draw_texture_rect(art, ArtLibrary.fit_rect(art, box), false)
		else:
			var fit := clampf(radius / 60.0, 0.4, 1.4) * art_scale / float(KIND_SIZE.get(kind, 1.0))
			PropPainter.draw_prop(self, kind, size / 2.0 + Vector2(0, radius * 0.55), fit, 5, palette)
		if faded:
			draw_circle(size / 2.0, radius, Color(0.95, 0.92, 0.86, 0.6))
			draw_texture_rect(UiIcons.texture("lock"), Rect2(size / 2.0 - Vector2(20, 20), Vector2(40, 40)), false, Color(UiTheme.INK, 0.8))
