class_name GearPanel
extends PanelContainer

## Rod and bait selection (UI_UX §2 Gear). Equipment changes how and where you fish, not how
## strong you are (GDD §12): a rod's reach and bite speed, a bait's pull on certain fish.
## The vertical slice offers the starter rods and baits from balance.json; shops and crafting
## are production-phase features.

signal close_pressed

var _rods_box: VBoxContainer
var _baits_box: VBoxContainer

func _init() -> void:
	custom_minimum_size = Vector2(640, 0)
	var box := UiKit.vbox(14)
	var header := UiKit.hbox(12)
	var title := UiKit.label(tr("ui.gear.title"), "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.button(tr("ui.close"), func() -> void: close_pressed.emit()))
	box.add_child(header)
	box.add_child(UiKit.label(tr("ui.gear.rod"), "DimLabel"))
	_rods_box = UiKit.vbox(10)
	box.add_child(_rods_box)
	box.add_child(UiKit.label(tr("ui.gear.bait"), "DimLabel"))
	_baits_box = UiKit.vbox(10)
	box.add_child(_baits_box)
	add_child(UiKit.margin(box, 24))

func refresh() -> void:
	_fill(_rods_box, GameState.get_owned_rods(), GameState.get_equipped_rod(), true)
	_fill(_baits_box, GameState.get_owned_baits(), GameState.get_equipped_bait(), false)

func _fill(box: VBoxContainer, ids: Array, equipped_id: String, is_rod: bool) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for item_id in ids:
		var def := ContentDB.get_rod(item_id) if is_rod else ContentDB.get_bait(item_id)
		if def.is_empty():
			continue
		var equipped: bool = item_id == equipped_id
		var label := tr(def["name_key"])
		if is_rod:
			label = "%s\n%s" % [label, tr("ui.gear.rod_stats") % [roundi(float(def["range"]) * 100.0), float(def["bite_speed"])]]
		if equipped:
			label = tr("ui.gear.item_equipped") % label  # the state is also in the text, never colour alone
		var button := UiKit.button(label, func() -> void: _equip(item_id, is_rod), equipped)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(button)

func _equip(item_id: String, is_rod: bool) -> void:
	if is_rod:
		GameState.equip_rod(item_id)
	else:
		GameState.equip_bait(item_id)
	refresh()
