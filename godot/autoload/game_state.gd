extends Node

## The player's persistent state (PlayerSave, DATA_SCHEMA §3-5) and the only code allowed to
## change it. UI and presenters read through the getters (which return copies) and issue
## commands to domain services; those services call the mutators here, and every mutator
## announces the change on EventBus.
##
## `data` is exactly what SaveService writes; do not add fields without updating SaveSchema
## (defaults + normalization) and, if the layout changes, a migration.

const MAX_CURRENCY := 999_999_999
const MAX_POPULATION := 9999

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
	inventory["rods"] = starting.get("rods", []).duplicate()
	inventory["baits"] = starting.get("baits", []).duplicate()
	inventory["equipped_rod"] = starting.get("equipped_rod", "")
	inventory["equipped_bait"] = starting.get("equipped_bait", "")
	_replaced()

## Replaces the whole state with a loaded save, filling defaults and fixing types.
func load_data(loaded: Dictionary) -> void:
	data = SaveSchema.normalize(loaded, _now())
	_replaced()

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

## Records a catch. Returns true when this is the species' first discovery.
func record_encounter(fish_id: String, size_cm: float, behavior: String = "") -> bool:
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
	else:
		record["largest_cm"] = maxf(record["largest_cm"], size_cm)
		record["smallest_cm"] = minf(record["smallest_cm"], size_cm)
	record["last_seen_at"] = now
	if not behavior.is_empty() and not record["observed_behaviors"].has(behavior):
		record["observed_behaviors"].append(behavior)
	_changed()
	EventBus.collection_changed.emit(fish_id)
	return is_new

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

func set_pending_catch(catch_info: Dictionary) -> void:
	ensure_initialized()
	data["session"]["pending_catch"] = catch_info.duplicate(true)
	_changed()

func clear_pending_catch() -> void:
	set_pending_catch({})
