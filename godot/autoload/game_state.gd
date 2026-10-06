extends Node

## The player's persistent state (PlayerSave, DATA_SCHEMA §3-5) and the only code allowed to
## change it. UI and presenters read through the getters (which return copies) and issue
## commands to domain services; those services call the mutators here, and every mutator
## announces the change on EventBus.
##
## `data` is exactly what SaveService writes; do not add fields without updating SaveSchema
## (defaults + normalization) and, if the layout changes, a migration.

const MAX_CURRENCY := SaveSchema.MAX_CURRENCY
const MAX_POPULATION := SaveSchema.MAX_POPULATION

## Bumped by every mutation so SaveService can tell whether there is anything new to write.
var revision: int = 0
var data: Dictionary = {}

func _now() -> int:
	return int(Time.get_unix_time_from_system())

# --- lifecycle ---

func new_game() -> void:
	data = SaveSchema.default_save(_now())
	var starting: Dictionary = ContentDB.balance.get("starting_inventory", {})
	var inventory: Dictionary = data["inventory"]
	for key in ["rods", "baits", "bags", "accessories", "decorations"]:
		inventory[key] = starting.get(key, []).duplicate()
	inventory["decorations_seen"] = inventory["decorations"].duplicate()
	for key in ["equipped_rod", "equipped_bait", "equipped_bag", "equipped_accessory"]:
		inventory[key] = starting.get(key, "")
	var stock: Dictionary = starting.get("bait_counts", {})
	for bait_id in stock:
		inventory["bait_counts"][bait_id] = int(stock[bait_id])  # JSON numbers arrive as floats
	_place_starting_camps()
	_replaced()

## Puts the starting decorations into each region's camp (balance.json starting_camp).
func _place_starting_camps() -> void:
	var camps: Dictionary = ContentDB.balance.get("starting_camp", {})
	for region_id in camps:
		var region := _region(region_id)
		if not region["camp"].is_empty():
			continue
		for slot_id in camps[region_id]:
			region["camp"][slot_id] = {"item": camps[region_id][slot_id], "flip": false}

## Replaces the whole state with a loaded save, filling defaults and fixing types.
func load_data(loaded: Dictionary) -> void:
	var raw_inventory: Variant = loaded.get("inventory")
	# A save from before counted baits: either migrated from disk (the migrator left a marker, because it
	# already normalized the save) or handed in raw (no stock field at all).
	var old_save: bool = typeof(raw_inventory) == TYPE_DICTIONARY \
		and (raw_inventory.get(SaveMigrator.LEGACY_BAIT_MARKER) == true or not raw_inventory.has("bait_counts"))
	data = SaveSchema.normalize(loaded, _now())
	data["inventory"].erase(SaveMigrator.LEGACY_BAIT_MARKER)
	_fill_starting_equipment(old_save)
	_replaced()

## Saves from before bags and counted baits (D-019) get the starting bag and hat, and their owned
## consumable baits a starting stock, so nobody opens an old save to an empty bag.
func _fill_starting_equipment(old_save: bool) -> void:
	var starting: Dictionary = ContentDB.balance.get("starting_inventory", {})
	var inventory: Dictionary = data["inventory"]
	for pair in [["bags", "equipped_bag"], ["accessories", "equipped_accessory"]]:
		if inventory[pair[0]].is_empty():
			inventory[pair[0]] = starting.get(pair[0], []).duplicate()
			inventory[pair[1]] = starting.get(pair[1], "")
	if inventory["decorations"].is_empty():
		# Saves from before the camp (P1-002) get the starting decorations, already placed.
		inventory["decorations"] = starting.get("decorations", []).duplicate()
		inventory["decorations_seen"] = inventory["decorations"].duplicate()
		_place_starting_camps()
	if old_save:
		var stock: Dictionary = starting.get("bait_counts", {})
		for bait_id in inventory["baits"]:
			if stock.has(bait_id):
				inventory["bait_counts"][bait_id] = int(stock[bait_id])

func ensure_initialized() -> void:
	if data.is_empty():
		new_game()

## Deep copy that is safe to serialize or hand to another thread.
func snapshot() -> Dictionary:
	ensure_initialized()
	return data.duplicate(true)

func _replaced() -> void:
	revision += 1
	EventBus.game_state_replaced.emit()

func _changed() -> void:
	revision += 1

# --- profile ---

func get_game_minutes() -> float:
	ensure_initialized()
	return data["profile"]["game_minutes"]

func set_game_minutes(minutes: float) -> void:
	ensure_initialized()
	var clamped := clampf(minutes, 0.0, 1440.0)
	if data["profile"]["game_minutes"] != clamped:
		data["profile"]["game_minutes"] = clamped
		_changed()

func get_last_session_at() -> int:
	ensure_initialized()
	return data["profile"]["last_session_at"]

func touch_session(at: int) -> void:
	ensure_initialized()
	at = maxi(0, at)
	if data["profile"]["last_session_at"] != at:
		data["profile"]["last_session_at"] = at
		_changed()

# --- economy ---

func get_ripple() -> int:
	ensure_initialized()
	return data["economy"]["ripple"]

func get_memory() -> int:
	ensure_initialized()
	return data["economy"]["memory"]

func add_ripple(amount: int) -> void:
	_add_currency("ripple", amount)

func add_memory(amount: int) -> void:
	_add_currency("memory", amount)

func spend_ripple(amount: int) -> bool:
	return _spend_currency("ripple", amount)

func spend_memory(amount: int) -> bool:
	return _spend_currency("memory", amount)

func _add_currency(key: String, amount: int) -> void:
	if amount < 0:
		push_error("GameState: cannot add a negative amount of %s (%d); use spend" % [key, amount])
		return
	ensure_initialized()
	data["economy"][key] = mini(MAX_CURRENCY, data["economy"][key] + amount)
	_economy_changed()

func _spend_currency(key: String, amount: int) -> bool:
	if amount < 0:
		push_error("GameState: cannot spend a negative amount of %s (%d)" % [key, amount])
		return false
	ensure_initialized()
	if data["economy"][key] < amount:
		return false
	data["economy"][key] -= amount
	_economy_changed()
	return true

func _economy_changed() -> void:
	_changed()
	EventBus.economy_changed.emit(data["economy"]["ripple"], data["economy"]["memory"])

# --- collection ---

func has_discovered(fish_id: String) -> bool:
	ensure_initialized()
	return data["collection"].has(fish_id) and data["collection"][fish_id]["encounters"] > 0

## Number of distinct species with at least one encounter.
func discovered_count() -> int:
	ensure_initialized()
	var count := 0
	for fish_id in data["collection"]:
		if data["collection"][fish_id]["encounters"] > 0:
			count += 1
	return count

## Copy of the record, or the default (all zero) record for an unseen species.
func get_collection_record(fish_id: String) -> Dictionary:
	ensure_initialized()
	if data["collection"].has(fish_id):
		return data["collection"][fish_id].duplicate(true)
	return SaveSchema.default_collection_record()

## Records a catch. Returns true when this is the species' first discovery. `weather_id` is the
## weather at the moment (kept for the journal's "weather on the day you met").
func record_encounter(fish_id: String, size_cm: float, behavior: String = "", weather_id: String = "") -> bool:
	ensure_initialized()
	var now := _now()
	var is_new := not has_discovered(fish_id)
	if not data["collection"].has(fish_id):
		data["collection"][fish_id] = SaveSchema.default_collection_record()
	var record: Dictionary = data["collection"][fish_id]
	record["encounters"] += 1
	if is_new:
		record["first_seen_at"] = now
		record["largest_cm"] = size_cm
		record["smallest_cm"] = size_cm
		record["first_weather"] = weather_id
		record["journal_seen"] = false
	else:
		record["largest_cm"] = maxf(record["largest_cm"], size_cm)
		record["smallest_cm"] = minf(record["smallest_cm"], size_cm)
	record["last_seen_at"] = now
	if not behavior.is_empty() and not record["observed_behaviors"].has(behavior):
		record["observed_behaviors"].append(behavior)
	_changed()
	EventBus.collection_changed.emit(fish_id)
	return is_new

## The player looked at the species in the journal: its NEW badge goes away.
func mark_journal_seen(fish_id: String) -> void:
	ensure_initialized()
	if not has_discovered(fish_id) or data["collection"][fish_id]["journal_seen"] == true:
		return
	data["collection"][fish_id]["journal_seen"] = true
	_changed()
	EventBus.collection_changed.emit(fish_id)

## Whether any met species has not been looked at in the journal yet.
func has_unseen_journal_entries() -> bool:
	ensure_initialized()
	for fish_id in data["collection"]:
		var record: Dictionary = data["collection"][fish_id]
		if record["encounters"] > 0 and record["journal_seen"] != true:
			return true
	return false

func record_release(fish_id: String) -> void:
	ensure_initialized()
	if not has_discovered(fish_id):
		push_error("GameState: release recorded for undiscovered fish %s" % fish_id)
		return
	data["collection"][fish_id]["releases"] += 1
	_changed()
	EventBus.collection_changed.emit(fish_id)

# --- regions ---

func get_restoration_level(region_id: String) -> int:
	return _region_value(region_id, "restoration_level")

func get_restoration_points(region_id: String) -> int:
	return _region_value(region_id, "restoration_points")

func add_restoration_points(region_id: String, points: int) -> void:
	if points < 0:
		push_error("GameState: restoration points cannot be negative (%d)" % points)
		return
	var region := _region(region_id)
	region["restoration_points"] = mini(MAX_CURRENCY, region["restoration_points"] + points)
	_changed()
	EventBus.region_restoration_points_changed.emit(region_id, region["restoration_points"])

func set_restoration_level(region_id: String, level: int) -> void:
	var region := _region(region_id)
	level = maxi(0, level)
	if region["restoration_level"] == level:
		return
	region["restoration_level"] = level
	_changed()
	EventBus.region_restoration_changed.emit(region_id, level)

func get_population(region_id: String, fish_id: String) -> int:
	ensure_initialized()
	if not data["regions"].has(region_id):
		return 0
	return data["regions"][region_id]["species_population"].get(fish_id, 0)

## Copy of {fish_id: population} for the region, only species that are present.
func get_species_population(region_id: String) -> Dictionary:
	ensure_initialized()
	if not data["regions"].has(region_id):
		return {}
	return data["regions"][region_id]["species_population"].duplicate()

func add_population(region_id: String, fish_id: String, amount: int) -> void:
	if amount < 0:
		push_error("GameState: population change cannot be negative (%d)" % amount)
		return
	var region := _region(region_id)
	var population := mini(MAX_POPULATION, region["species_population"].get(fish_id, 0) + amount)
	region["species_population"][fish_id] = population
	_changed()
	EventBus.region_population_changed.emit(region_id, fish_id, population)

func has_seen_event(region_id: String, event_id: String) -> bool:
	ensure_initialized()
	return data["regions"].has(region_id) and data["regions"][region_id]["seen_events"].has(event_id)

func mark_event_seen(region_id: String, event_id: String) -> void:
	var region := _region(region_id)
	if not region["seen_events"].has(event_id):
		region["seen_events"].append(event_id)
		_changed()

func _region(region_id: String) -> Dictionary:
	ensure_initialized()
	if not data["regions"].has(region_id):
		data["regions"][region_id] = SaveSchema.default_region(region_id)
	return data["regions"][region_id]

func _region_value(region_id: String, key: String) -> int:
	ensure_initialized()
	if not data["regions"].has(region_id):
		return 0
	return data["regions"][region_id][key]

# --- inventory ---

func get_owned_rods() -> Array:
	ensure_initialized()
	return data["inventory"]["rods"].duplicate()

func get_owned_baits() -> Array:
	ensure_initialized()
	return data["inventory"]["baits"].duplicate()

func get_equipped_rod() -> String:
	ensure_initialized()
	return data["inventory"]["equipped_rod"]

func get_equipped_bait() -> String:
	ensure_initialized()
	return data["inventory"]["equipped_bait"]

func grant_rod(rod_id: String) -> void:
	ensure_initialized()
	if not data["inventory"]["rods"].has(rod_id):
		data["inventory"]["rods"].append(rod_id)
		_inventory_changed()

func grant_bait(bait_id: String) -> void:
	ensure_initialized()
	if not data["inventory"]["baits"].has(bait_id):
		data["inventory"]["baits"].append(bait_id)
		_inventory_changed()

## Only owned rods can be equipped. Returns false (state unchanged) otherwise.
func equip_rod(rod_id: String) -> bool:
	ensure_initialized()
	if not data["inventory"]["rods"].has(rod_id):
		return false
	data["inventory"]["equipped_rod"] = rod_id
	_inventory_changed()
	return true

func equip_bait(bait_id: String) -> bool:
	ensure_initialized()
	if not data["inventory"]["baits"].has(bait_id):
		return false
	data["inventory"]["equipped_bait"] = bait_id
	_inventory_changed()
	return true

func get_owned_bags() -> Array:
	ensure_initialized()
	return data["inventory"]["bags"].duplicate()

func get_equipped_bag() -> String:
	ensure_initialized()
	return data["inventory"]["equipped_bag"]

func get_owned_accessories() -> Array:
	ensure_initialized()
	return data["inventory"]["accessories"].duplicate()

func get_equipped_accessory() -> String:
	ensure_initialized()
	return data["inventory"]["equipped_accessory"]

func grant_bag(bag_id: String) -> void:
	_grant("bags", bag_id)

func grant_accessory(accessory_id: String) -> void:
	_grant("accessories", accessory_id)

func equip_bag(bag_id: String) -> bool:
	return _equip("bags", "equipped_bag", bag_id)

func equip_accessory(accessory_id: String) -> bool:
	return _equip("accessories", "equipped_accessory", accessory_id)

## Counted stock of a bait (0 for baits never stocked; endless baits are not counted).
func get_bait_count(bait_id: String) -> int:
	ensure_initialized()
	return data["inventory"]["bait_counts"].get(bait_id, 0)

## Every counted bait and its stock.
func get_bait_counts() -> Dictionary:
	ensure_initialized()
	return data["inventory"]["bait_counts"].duplicate()

## Adds `amount` (>= 0) baits to the stock. Capacity is the LoadoutService's rule, not the save's.
func add_baits(bait_id: String, amount: int) -> void:
	if amount < 0:
		push_error("GameState: cannot add a negative number of baits (%d)" % amount)
		return
	ensure_initialized()
	var counts: Dictionary = data["inventory"]["bait_counts"]
	counts[bait_id] = mini(SaveSchema.MAX_BAIT_COUNT, counts.get(bait_id, 0) + amount)
	_inventory_changed()

## Uses one bait. Returns false (nothing changes) when there is none left.
func take_bait(bait_id: String) -> bool:
	ensure_initialized()
	var counts: Dictionary = data["inventory"]["bait_counts"]
	if counts.get(bait_id, 0) <= 0:
		return false
	counts[bait_id] -= 1
	_inventory_changed()
	return true

# --- moments (P1-008) ---

func has_moment(moment_id: String) -> bool:
	ensure_initialized()
	return data["moments"].has(moment_id)

## When a moment was first seen (unix seconds), 0 if never.
func moment_seen_at(moment_id: String) -> int:
	ensure_initialized()
	return data["moments"].get(moment_id, 0)

func record_moment(moment_id: String) -> void:
	ensure_initialized()
	if data["moments"].has(moment_id):
		return
	data["moments"][moment_id] = _now()
	_changed()

# --- camp (P1-002) ---

func get_owned_decorations() -> Array:
	ensure_initialized()
	return data["inventory"]["decorations"].duplicate()

func grant_decoration(decoration_id: String) -> void:
	_grant("decorations", decoration_id)

func has_seen_decoration(decoration_id: String) -> bool:
	ensure_initialized()
	return data["inventory"]["decorations_seen"].has(decoration_id)

func mark_decorations_seen(decoration_ids: Array) -> void:
	ensure_initialized()
	var seen: Array = data["inventory"]["decorations_seen"]
	var changed := false
	for decoration_id in decoration_ids:
		if not seen.has(decoration_id):
			seen.append(decoration_id)
			changed = true
	if changed:
		_changed()

## Copy of the region's camp: {slot_id: {"item": decoration_id, "flip": bool}}.
func get_camp(region_id: String) -> Dictionary:
	ensure_initialized()
	if not data["regions"].has(region_id):
		return {}
	return data["regions"][region_id]["camp"].duplicate(true)

## Puts an owned decoration into a slot (moving it if it stood elsewhere). Returns false otherwise.
func place_decoration(region_id: String, slot_id: String, decoration_id: String, flip: bool = false) -> bool:
	ensure_initialized()
	if not data["inventory"]["decorations"].has(decoration_id) or slot_id.is_empty():
		return false
	var camp: Dictionary = _region(region_id)["camp"]
	for other in camp.keys():
		if camp[other]["item"] == decoration_id:
			camp.erase(other)
	camp[slot_id] = {"item": decoration_id, "flip": flip}
	_camp_changed(region_id)
	return true

func clear_camp_slot(region_id: String, slot_id: String) -> void:
	ensure_initialized()
	if data["regions"].has(region_id) and data["regions"][region_id]["camp"].has(slot_id):
		data["regions"][region_id]["camp"].erase(slot_id)
		_camp_changed(region_id)

func flip_camp_slot(region_id: String, slot_id: String) -> void:
	ensure_initialized()
	if data["regions"].has(region_id) and data["regions"][region_id]["camp"].has(slot_id):
		var entry: Dictionary = data["regions"][region_id]["camp"][slot_id]
		entry["flip"] = not entry["flip"]
		_camp_changed(region_id)

func _camp_changed(region_id: String) -> void:
	_changed()
	EventBus.camp_changed.emit(region_id)

func _grant(list_key: String, item_id: String) -> void:
	ensure_initialized()
	if not data["inventory"][list_key].has(item_id):
		data["inventory"][list_key].append(item_id)
		_inventory_changed()

func _equip(list_key: String, equipped_key: String, item_id: String) -> bool:
	ensure_initialized()
	if not data["inventory"][list_key].has(item_id):
		return false
	data["inventory"][equipped_key] = item_id
	_inventory_changed()
	return true

func _inventory_changed() -> void:
	_changed()
	EventBus.inventory_changed.emit()

# --- settings ---

func get_setting(key: String) -> Variant:
	ensure_initialized()
	if data["settings"].has(key):
		return data["settings"][key]
	if SaveSchema.is_known_setting(key):
		return SaveSchema.SETTING_SPECS[key]["default"]
	push_warning("GameState: unknown setting '%s'" % key)
	return null

## Stores a sanitized value (clamped / validated against SaveSchema). Returns false for
## unknown keys. Emits settings_changed only when the stored value actually changed.
func set_setting(key: String, value: Variant) -> bool:
	if not SaveSchema.is_known_setting(key):
		push_warning("GameState: unknown setting '%s'" % key)
		return false
	ensure_initialized()
	var clean: Variant = SaveSchema.sanitize_setting(key, value)
	if data["settings"].get(key) == clean and typeof(data["settings"].get(key)) == typeof(clean):
		return true
	data["settings"][key] = clean
	_changed()
	EventBus.settings_changed.emit(key)
	return true

# --- pending catch (caught but not yet released) ---

func get_pending_catch() -> Dictionary:
	ensure_initialized()
	return data["session"]["pending_catch"].duplicate(true)

## Stores a catch that has not been released yet. The info is normalized like a loaded save, so a
## malformed catch is refused (an error is logged and nothing is stored) instead of poisoning the save.
func set_pending_catch(catch_info: Dictionary) -> void:
	ensure_initialized()
	var clean := SaveSchema.normalize_pending_catch(catch_info)
	if clean.is_empty() and not catch_info.is_empty():
		push_error("GameState: refusing a malformed pending catch: %s" % var_to_str(catch_info))
	data["session"]["pending_catch"] = clean
	_changed()

func clear_pending_catch() -> void:
	set_pending_catch({})
