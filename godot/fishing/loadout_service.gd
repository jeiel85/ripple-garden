class_name LoadoutService
extends RefCounted

## The command boundary for equipment (TECH_SPEC §3: UI -> command -> service -> state, GDD §12, D-019).
## Four categories, as in the equipment mockup: "rod", "bait", "bag", "accessory".
##
##   equip      only owned items; a counted bait needs stock, a bag must hold what is carried
##   offer      what the screen should say about an item: owned, buyable (price), locked (which
##              restoration opens it), a keepsake still to come, too dear, or no room in the bag
##   buy        spends Ripple or Memory and grants the item; baits come in packs that must fit the bag
##   grants     "event" keepsakes arrive by themselves when their moment comes (never sold, No FOMO)
##   bites      a bite uses one of the equipped counted bait; when the last one goes, the endless
##              bait is equipped so the player can always keep fishing
##
## Equipment changes how and where you fish, never how strong you are: rods trade control,
## sensitivity and durability against each other.

const CATEGORIES: PackedStringArray = ["rod", "bait", "bag", "accessory", "decoration"]

## Offer states.
const OWNED := "owned"
const BUY := "buy"
const LOCKED := "locked"
const GIFT_LATER := "gift_later"
const TOO_DEAR := "too_dear"
const BAG_FULL := "bag_full"

var _state: Node

func _init(game_state: Node) -> void:
	_state = game_state

# --- equipping ---

## Equips an owned rod. Returns false (nothing changes) for unknown or unowned rods.
func equip_rod(rod_id: String) -> bool:
	if ContentDB.get_rod(rod_id).is_empty():
		return false
	return _state.equip_rod(rod_id)

## Equips an owned bait. A counted bait with nothing left cannot be equipped.
func equip_bait(bait_id: String) -> bool:
	var bait := ContentDB.get_bait(bait_id)
	if bait.is_empty():
		return false
	if bait["consumable"] == true and _state.get_bait_count(bait_id) <= 0:
		return false
	return _state.equip_bait(bait_id)

## Equips an owned bag, unless it is too small for the baits being carried.
func equip_bag(bag_id: String) -> bool:
	var bag := ContentDB.get_bag(bag_id)
	if bag.is_empty() or carried_baits() > int(bag["capacity"]):
		return false
	return _state.equip_bag(bag_id)

func equip_accessory(accessory_id: String) -> bool:
	if ContentDB.get_accessory(accessory_id).is_empty():
		return false
	return _state.equip_accessory(accessory_id)

func equip(category: String, item_id: String) -> bool:
	match category:
		"rod": return equip_rod(item_id)
		"bait": return equip_bait(item_id)
		"bag": return equip_bag(item_id)
		"accessory": return equip_accessory(item_id)
	return false

func equipped(category: String) -> String:
	match category:
		"rod": return _state.get_equipped_rod()
		"bait": return _state.get_equipped_bait()
		"bag": return _state.get_equipped_bag()
		"accessory": return _state.get_equipped_accessory()
	return ""

func owned(category: String) -> Array:
	match category:
		"rod": return _state.get_owned_rods()
		"bait": return _state.get_owned_baits()
		"bag": return _state.get_owned_bags()
		"accessory": return _state.get_owned_accessories()
		"decoration": return _state.get_owned_decorations()
	return []

func is_owned(category: String, item_id: String) -> bool:
	return item_id in owned(category)

## Every item of a category in content order (the equipment screen's list).
static func catalog(category: String) -> Array:
	match category:
		"rod": return ContentDB.rods.keys()
		"bait": return ContentDB.baits.keys()
		"bag": return ContentDB.bags.keys()
		"accessory": return ContentDB.accessories.keys()
		"decoration": return ContentDB.decorations.keys()
	return []

# --- bag and baits ---

## How many counted baits the equipped bag holds.
func bag_capacity() -> int:
	return int(ContentDB.get_bag(_state.get_equipped_bag()).get("capacity", 0))

## How many counted baits are being carried (endless baits do not take room).
func carried_baits() -> int:
	var total := 0
	var counts: Dictionary = _state.get_bait_counts()
	for bait_id in counts:
		total += int(counts[bait_id])
	return total

func free_bag_space() -> int:
	return maxi(0, bag_capacity() - carried_baits())

## Stock of a bait; -1 for an endless bait.
func bait_stock(bait_id: String) -> int:
	if ContentDB.get_bait(bait_id).get("consumable", true) == false:
		return -1
	return _state.get_bait_count(bait_id)

## A bite took the bait: one of the equipped counted bait is used. When that was the last one, the
## first owned endless bait is equipped instead and `bait_ran_out` is announced. Returns whether a
## bait was used.
func use_bait_for_bite() -> bool:
	var bait_id: String = _state.get_equipped_bait()
	if ContentDB.get_bait(bait_id).get("consumable", false) != true:
		return false
	if not _state.take_bait(bait_id):
		return false
	if _state.get_bait_count(bait_id) <= 0:
		var replacement := endless_bait()
		if not replacement.is_empty() and _state.equip_bait(replacement):
			EventBus.bait_ran_out.emit(bait_id, replacement)
	return true

## The first owned bait that never runs out ("" if none, which content validation forbids).
func endless_bait() -> String:
	for bait_id in _state.get_owned_baits():
		if ContentDB.get_bait(bait_id).get("consumable", true) == false:
			return bait_id
	return ""

# --- acquiring ---

## What the equipment screen should say about an item:
## {"state": OWNED | BUY | LOCKED | GIFT_LATER | TOO_DEAR | BAG_FULL, "currency": String, "amount": int,
##  "pack": int (baits added by one purchase), "region": String, "level": int (the condition)}.
func offer(category: String, item_id: String) -> Dictionary:
	var def := ContentDB.get_item(category, item_id)
	var result := {"state": OWNED, "currency": "", "amount": 0, "pack": 0, "region": "", "level": 0}
	if def.is_empty():
		result["state"] = LOCKED
		return result
	var owned_already := is_owned(category, item_id)
	if owned_already and category != "bait":
		return result
	if def.has("granted_by"):
		result["state"] = OWNED if owned_already else GIFT_LATER
		result["region"] = def["granted_by"]["region"]
		result["level"] = int(def["granted_by"]["restoration_level"])
		return result
	if not def.has("price"):
		return result  # a starting item, or an endless bait
	result["currency"] = def["price"]["currency"]
	result["amount"] = int(def["price"]["amount"])
	if not is_unlocked(def):
		result["state"] = LOCKED
		result["region"] = def["unlock"]["region"]
		result["level"] = int(def["unlock"]["restoration_level"])
		return result
	if category == "bait":
		var pack_size := int(ContentDB.balance["equipment"]["bait_pack_size"])
		var pack := mini(pack_size, free_bag_space())
		result["pack"] = pack
		if pack <= 0:
			result["state"] = BAG_FULL
			return result
		# A pack that only partly fits costs its share (rounded up).
		result["amount"] = ceili(float(result["amount"]) * pack / pack_size)
	result["state"] = BUY if _balance(result["currency"]) >= result["amount"] else TOO_DEAR
	return result

## Buys the item (a pack of baits for a bait). Returns false and changes nothing unless the offer is BUY.
func buy(category: String, item_id: String) -> bool:
	var deal := offer(category, item_id)
	if deal["state"] != BUY:
		return false
	var paid: bool = _state.spend_ripple(deal["amount"]) if deal["currency"] == "ripple" else _state.spend_memory(deal["amount"])
	if not paid:
		return false
	match category:
		"rod": _state.grant_rod(item_id)
		"bait":
			_state.grant_bait(item_id)
			_state.add_baits(item_id, deal["pack"])
		"bag": _state.grant_bag(item_id)
		"accessory": _state.grant_accessory(item_id)
		"decoration": _state.grant_decoration(item_id)
	return true

## Whether an item's unlock condition (a restoration stage of a region) is met.
func is_unlocked(def: Dictionary) -> bool:
	if not def.has("unlock"):
		return true
	return _state.get_restoration_level(def["unlock"]["region"]) >= int(def["unlock"]["restoration_level"])

## Grants every keepsake whose moment has come and that is not owned yet. Returns [[category, id], ...].
func grant_keepsakes() -> Array:
	var granted: Array = []
	for category in CATEGORIES:
		for item_id in catalog(category):
			var def := ContentDB.get_item(category, item_id)
			if not def.has("granted_by") or is_owned(category, item_id):
				continue
			var condition: Dictionary = def["granted_by"]
			if _state.get_restoration_level(condition["region"]) < int(condition["restoration_level"]):
				continue
			match category:
				"rod": _state.grant_rod(item_id)
				"bait": _state.grant_bait(item_id)
				"bag": _state.grant_bag(item_id)
				"accessory": _state.grant_accessory(item_id)
				"decoration": _state.grant_decoration(item_id)
			granted.append([category, item_id])
			EventBus.item_granted.emit(category, item_id)
	return granted

func _balance(currency: String) -> int:
	return _state.get_ripple() if currency == "ripple" else _state.get_memory()

# --- rod character (the three bars of the equipment screen) ---

## {"control", "sensitivity", "durability"} 0..100 for a rod, from its play values: tension assist,
## bite speed and line strength. Display only; the play values stay the single source.
static func rod_stats(rod: Dictionary) -> Dictionary:
	return {
		"control": clampi(roundi(float(rod.get("tension_assist", 0.0)) / 0.35 * 100.0), 0, 100),
		"sensitivity": clampi(roundi((float(rod.get("bite_speed", 1.0)) - 0.85) / 0.3 * 100.0), 0, 100),
		"durability": clampi(roundi(float(rod.get("line_strength", 0.0)) * 100.0), 0, 100),
	}
