class_name CampService
extends RefCounted

## The camp (GDD §15, UI_UX §7, mockup 06, P1-002): the emotional anchor by the water. A region's layout
## names a few anchor slots around the camp clearing; the player puts owned decorations into them,
## turns them, or puts them away. Decorations are bought with Ripple through LoadoutService (category
## "decoration"); this service only arranges them. Slot placement (not free dragging) keeps it easy on
## a phone.
##
## A small "new" dot invites a visit when a decoration has become available that the player has not
## looked at in the camp screen yet (UI_UX §1).

var _state: Node
var _loadout: LoadoutService

func _init(game_state: Node, loadout: LoadoutService) -> void:
	_state = game_state
	_loadout = loadout

## [{"id", "position": Vector2}] for the region, in layout order.
static func slots(region_id: String) -> Array:
	var result: Array = []
	for slot in ContentDB.get_layout(region_id).get("camp_slots", []):
		result.append({"id": slot["id"], "position": Vector2(float(slot["x"]), float(slot["y"]))})
	return result

static func slot_position(region_id: String, slot_id: String) -> Vector2:
	for slot in slots(region_id):
		if slot["id"] == slot_id:
			return slot["position"]
	return Vector2.ZERO

## The decoration in a slot ("" when empty).
func item_in(region_id: String, slot_id: String) -> String:
	return _state.get_camp(region_id).get(slot_id, {}).get("item", "")

## The slot a decoration stands in ("" when it is put away).
func slot_of(region_id: String, decoration_id: String) -> String:
	var camp: Dictionary = _state.get_camp(region_id)
	for slot_id in camp:
		if camp[slot_id]["item"] == decoration_id:
			return slot_id
	return ""

## Puts an owned decoration into a slot of the region (moving it from where it stood).
func place(region_id: String, slot_id: String, decoration_id: String) -> bool:
	if not _is_slot(region_id, slot_id) or ContentDB.get_decoration(decoration_id).is_empty():
		return false
	var flip: bool = _state.get_camp(region_id).get(slot_id, {}).get("flip", false)
	return _state.place_decoration(region_id, slot_id, decoration_id, flip)

func remove(region_id: String, slot_id: String) -> void:
	_state.clear_camp_slot(region_id, slot_id)

func turn(region_id: String, slot_id: String) -> void:
	_state.flip_camp_slot(region_id, slot_id)

## Buys a decoration (Ripple) and places it at once. Returns false when it cannot be bought.
func buy_and_place(region_id: String, slot_id: String, decoration_id: String) -> bool:
	if not _is_slot(region_id, slot_id) or not _loadout.buy("decoration", decoration_id):
		return false
	return place(region_id, slot_id, decoration_id)

## Decorations available to look at (owned, or unlocked for sale) that the camp screen has not shown yet.
func has_news() -> bool:
	for decoration_id in LoadoutService.catalog("decoration"):
		if _is_available(decoration_id) and not _state.has_seen_decoration(decoration_id):
			return true
	return false

## The camp screen was opened: everything available now counts as seen.
func mark_seen() -> void:
	var available: Array = []
	for decoration_id in LoadoutService.catalog("decoration"):
		if _is_available(decoration_id):
			available.append(decoration_id)
	_state.mark_decorations_seen(available)

func _is_available(decoration_id: String) -> bool:
	if _loadout.is_owned("decoration", decoration_id):
		return true
	return _loadout.offer("decoration", decoration_id)["state"] in [LoadoutService.BUY, LoadoutService.TOO_DEAR]

static func _is_slot(region_id: String, slot_id: String) -> bool:
	for slot in slots(region_id):
		if slot["id"] == slot_id:
			return true
	return false
