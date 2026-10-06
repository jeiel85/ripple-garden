class_name ContentValidator
extends RefCounted

## Validates raw parsed content (DATA_SCHEMA §7) and returns only the entries
## that passed, indexed by id. Entries with any error are excluded so runtime
## code never sees malformed definitions; every problem is reported in `errors`.
##
## Input:  {"fish": Array, "regions": Array, "rods": Array, "baits": Array,
##          "progression": Dictionary, "balance": Dictionary, "aliases": Dictionary,
##          "behaviors": Array} — a value may be null when its file
##          could not be read (the loader reports that error itself).
## Output: {"fish": {id: def}, "regions": {...}, "rods": {...}, "baits": {...},
##          "progression": Dictionary (empty if invalid), "balance": Dictionary (empty if invalid),
##          "aliases": Dictionary (empty if invalid), "behaviors": {id: def},
##          "errors": PackedStringArray}

const TIME_BANDS: PackedStringArray = preload("res://autoload/time_service.gd").TIME_BANDS

const FILE_NAMES := {
	"fish": "fish_catalog.json",
	"regions": "regions.json",
	"rods": "rods.json",
	"baits": "baits.json",
	"progression": "progression.json",
	"balance": "balance.json",
	"aliases": "content_aliases.json",
	"behaviors": "behaviors.json",
	"weather": "weather.json",
	"layouts": "region_layouts.json",
	"audio": "audio.json",
	"equipment": "equipment.json",
	"decorations": "decorations.json",
}

const ID_PATTERNS := {
	"fish": "^fish_[a-z0-9_]+$",
	"regions": "^region_[0-9]{2}_[a-z0-9_]+$",
	"rods": "^rod_[a-z0-9_]+$",
	"baits": "^bait_[a-z0-9_]+$",
	"behaviors": "^[a-z][a-z0-9_]*$",
	"weather": "^[a-z][a-z0-9_]*$",
	"bags": "^bag_[a-z0-9_]+$",
	"accessories": "^acc_[a-z0-9_]+$",
	"decorations": "^deco_[a-z0-9_]+$",
}
const DECORATION_CATEGORIES: PackedStringArray = ["furniture", "ornament"]
## How an island is drawn on the region map (world/region_map_view.gd).
const MAP_STYLES: PackedStringArray = ["pond", "valley", "river", "coast", "isle"]
## Lists that live inside another file (equipment.json holds bags and accessories).
const LIST_FILES := {"bags": "equipment.json", "accessories": "equipment.json"}
## Equipment grades (GDD §12, D-019). "event" items are granted by a moment, never sold.
const GRADES: PackedStringArray = ["common", "uncommon", "rare", "event"]
const CURRENCIES: PackedStringArray = ["ripple", "memory"]

const AUDIO_BUSES: PackedStringArray = preload("res://autoload/audio_service.gd").REQUIRED_BUSES
const AUDIO_CUES: PackedStringArray = ["cast", "landed", "bite", "hooked", "caught", "released", "escaped"]
const PROP_KINDS: PackedStringArray = PropKinds.PROPS
const ANIMAL_KINDS: PackedStringArray = PropKinds.ANIMALS
## How far past the design viewport a region's pond and scenery may extend (wider/taller screens).
const LAYOUT_BLEED := Vector2(480, 320)
const HEX_COLOR := "^#[0-9a-fA-F]{6}$"

static func validate(raw: Dictionary) -> Dictionary:
	var v := ContentValidator.new()
	var regions := v._validate_list(raw.get("regions"), "regions", v._check_region)
	v._regions = regions
	var baits := v._validate_list(raw.get("baits"), "baits", v._check_bait)
	for bait_def in baits.values():
		for tag in bait_def["tags"]:
			v._bait_tags[tag] = true
	var rods := v._validate_list(raw.get("rods"), "rods", v._check_rod)
	var behaviors := v._validate_list(raw.get("behaviors"), "behaviors", v._check_behavior)
	v._behaviors = behaviors
	var fish := v._validate_list(raw.get("fish"), "fish", v._check_fish)
	var progression := v._validate_progression(raw.get("progression"), regions, fish)
	var weather := v._validate_list(raw.get("weather"), "weather", v._check_weather)
	v._check_weather_links(weather)
	var equipment_raw: Variant = raw.get("equipment")
	var bags := {}
	var accessories := {}
	if equipment_raw != null and typeof(equipment_raw) != TYPE_DICTIONARY:
		v._errors.append("equipment.json: top level must be an object with bags and accessories")
	elif equipment_raw != null:
		bags = v._validate_list(equipment_raw.get("bags"), "bags", v._check_bag)
		accessories = v._validate_list(equipment_raw.get("accessories"), "accessories", v._check_accessory)
	var decorations := v._validate_list(raw.get("decorations"), "decorations", v._check_decoration)
	var balance := v._validate_balance(raw.get("balance"), regions, rods, baits, bags, accessories)
	var layouts := v._validate_layouts(raw.get("layouts"), regions, weather, balance)
	v._check_starting_camp(balance, layouts, decorations)
	var audio := v._validate_audio(raw.get("audio"))
	var aliases := v._validate_aliases(raw.get("aliases"), {"fish": fish, "rods": rods, "baits": baits, "regions": regions})
	return {
		"fish": fish,
		"regions": regions,
		"rods": rods,
		"baits": baits,
		"progression": progression,
		"balance": balance,
		"aliases": aliases,
		"behaviors": behaviors,
		"weather": weather,
		"layouts": layouts,
		"audio": audio,
		"bags": bags,
		"accessories": accessories,
		"decorations": decorations,
		"errors": v._errors,
	}

var _errors := PackedStringArray()
var _regions: Dictionary = {}
var _bait_tags: Dictionary = {}
var _behaviors: Dictionary = {}
var _item_errors := PackedStringArray()

func _validate_list(items: Variant, category: String, check: Callable) -> Dictionary:
	var file_name: String = LIST_FILES.get(category, FILE_NAMES.get(category, ""))
	var result: Dictionary = {}
	if items == null:
		return result
	if typeof(items) != TYPE_ARRAY:
		_errors.append("%s: top level must be an array" % file_name)
		return result
	var id_regex := RegEx.create_from_string(ID_PATTERNS[category])
	# Tracked separately from `result` so a duplicate of a rejected entry is still caught.
	var seen_ids: Dictionary = {}
	for i in items.size():
		var item: Variant = items[i]
		var label := "%s[%d]" % [file_name, i]
		if typeof(item) != TYPE_DICTIONARY:
			_errors.append("%s: entry must be an object" % label)
			continue
		var item_id: Variant = item.get("id")
		if typeof(item_id) != TYPE_STRING or id_regex.search(item_id) == null:
			_errors.append("%s.id: must match %s (got %s)" % [label, ID_PATTERNS[category], var_to_str(item_id)])
			continue
		label = "%s[%s]" % [file_name, item_id]
		if seen_ids.has(item_id):
			_errors.append("%s: duplicate id" % label)
			continue
		seen_ids[item_id] = true
		_item_errors.clear()
		check.call(item)
		if _item_errors.is_empty():
			result[item_id] = item
		else:
			for problem in _item_errors:
				_errors.append("%s.%s" % [label, problem])
	return result

# --- per-category checks: each appends "field: message" to _item_errors ---

func _check_region(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string_list(d, "habitats")
	_require_string_list(d, "weather")
	_require_int(d, "restoration_levels", 1, 100)
	# Where the island sits on the region map (P1-010): x, y in 0..1 of the map, a drawing style and a label icon.
	var place: Variant = d.get("map")
	if typeof(place) != TYPE_DICTIONARY or not _is_number(place.get("x")) or not _is_number(place.get("y")) \
			or place["x"] < 0.0 or place["x"] > 1.0 or place["y"] < 0.0 or place["y"] > 1.0 \
			or typeof(place.get("style")) != TYPE_STRING or not place["style"] in MAP_STYLES \
			or typeof(place.get("icon")) != TYPE_STRING or not UiIcons.has_icon(place["icon"]):
		_item_errors.append("map: must be {x: 0..1, y: 0..1, style: %s, icon: a name from UiIcons.NAMES}" % " | ".join(MAP_STYLES))

## Baits: `consumable` false means an endless supply (the fallback bait); a consumable bait is bought
## in packs for `price` once `unlock` is met.
func _check_bait(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string(d, "desc_key")
	_require_string_list(d, "tags")
	if typeof(d.get("consumable")) != TYPE_BOOL:
		_item_errors.append("consumable: must be true or false")
	_check_acquisition(d, false)

func _check_rod(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string(d, "desc_key")
	_require_number(d, "range", 0.0, 1.0, false)
	_require_number(d, "bite_speed", 0.0, INF, false)
	_require_number(d, "tension_assist", 0.0, 1.0, true)
	_require_number(d, "line_strength", 0.0, 1.0, true)
	_require_string_list(d, "tags")
	if typeof(d.get("grade")) != TYPE_STRING or not d["grade"] in GRADES:
		_item_errors.append("grade: must be one of %s" % ", ".join(GRADES))
	_check_acquisition(d, true)

func _check_bag(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string(d, "desc_key")
	_require_int(d, "capacity", 1, 999)
	_require_color(d, "color")
	_check_acquisition(d, false)

func _check_accessory(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string(d, "desc_key")
	_require_color(d, "hat")
	_require_color(d, "band")
	_check_acquisition(d, false)

## How an item is obtained: `price` {currency, amount} once `unlock` {region, restoration_level} is met,
## or `granted_by` the same kind of condition for event items (which are never sold, No FOMO). An item
## with neither is a starting item.
func _check_acquisition(d: Dictionary, has_grade: bool) -> void:
	for field in ["unlock", "granted_by"]:
		if d.has(field):
			var condition: Variant = d[field]
			if typeof(condition) != TYPE_DICTIONARY or typeof(condition.get("region")) != TYPE_STRING \
					or not _regions.has(condition["region"]) or not _is_int(condition.get("restoration_level")) \
					or condition["restoration_level"] < 0 or condition["restoration_level"] > 100:
				_item_errors.append("%s: must be {region: known region id, restoration_level: 0..100}" % field)
	if d.has("price"):
		var price: Variant = d["price"]
		if typeof(price) != TYPE_DICTIONARY or not price.get("currency") in CURRENCIES or not _is_int(price.get("amount")) \
				or price["amount"] < 1 or price["amount"] > 100000:
			_item_errors.append("price: must be {currency: %s, amount: 1..100000}" % " | ".join(CURRENCIES))
	if d.has("granted_by") and d.has("price"):
		_item_errors.append("granted_by: an item granted by a moment is never also sold")
	if has_grade and typeof(d.get("grade")) == TYPE_STRING:
		if (d["grade"] == "event") != d.has("granted_by"):
			_item_errors.append("grade: event items (and only they) are granted_by a moment")

## Camp decorations (P1-002): drawn as a known prop kind, bought like equipment.
func _check_decoration(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string(d, "desc_key")
	if typeof(d.get("category")) != TYPE_STRING or not d["category"] in DECORATION_CATEGORIES:
		_item_errors.append("category: must be one of %s" % ", ".join(DECORATION_CATEGORIES))
	if typeof(d.get("prop")) != TYPE_STRING or not d["prop"] in PROP_KINDS:
		_item_errors.append("prop: unknown prop kind %s" % var_to_str(d.get("prop")))
	_require_number(d, "scale", 0.2, 3.0, true)
	_check_acquisition(d, false)

## The starting decorations must be known, and the starting camp may only put owned decorations, each
## once, into slots its region's layout has.
func _check_starting_camp(balance: Dictionary, layouts: Dictionary, decorations: Dictionary) -> void:
	if balance.is_empty():
		return
	var file_name: String = FILE_NAMES["balance"]
	var starting: Dictionary = balance.get("starting_inventory", {})
	_check_owned_list(starting, "decorations", decorations, "starting_inventory.decorations")
	var camps: Variant = balance.get("starting_camp")
	if typeof(camps) != TYPE_DICTIONARY:
		_errors.append("%s.starting_camp: must be an object {region_id: {slot_id: decoration_id}}" % file_name)
		return
	for region_id in camps:
		var slots := {}
		for slot in layouts.get(region_id, {}).get("camp_slots", []):
			slots[slot["id"]] = true
		var placed := {}
		var camp: Variant = camps[region_id]
		if typeof(camp) != TYPE_DICTIONARY:
			_errors.append("%s.starting_camp.%s: must be an object {slot_id: decoration_id}" % [file_name, region_id])
			continue
		for slot_id in camp:
			var deco: Variant = camp[slot_id]
			if not slots.has(slot_id):
				_errors.append("%s.starting_camp.%s: '%s' is not a camp slot of the region's layout" % [file_name, region_id, slot_id])
			if typeof(deco) != TYPE_STRING or not deco in starting.get("decorations", []):
				_errors.append("%s.starting_camp.%s.%s: must be a starting decoration" % [file_name, region_id, slot_id])
			elif placed.has(deco):
				_errors.append("%s.starting_camp.%s: %s is placed twice" % [file_name, region_id, deco])
			placed[deco] = true

func _require_color(d: Dictionary, field: String) -> void:
	if typeof(d.get(field)) != TYPE_STRING or RegEx.create_from_string(HEX_COLOR).search(d[field]) == null:
		_item_errors.append("%s: must be a #rrggbb color" % field)

func _check_weather(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_min_max(d, "duration_sec", 10.0, 3600.0)
	_require_number(d, "transition_sec", 0.0, 120.0, false)
	var duration: Variant = d.get("duration_sec")
	if typeof(duration) == TYPE_DICTIONARY and _is_number(duration.get("min")) and _is_number(d.get("transition_sec")) \
			and duration["min"] < 2.0 * d["transition_sec"]:
		_item_errors.append("duration_sec: the shortest stay must be at least twice transition_sec so weather cannot flicker")
	var nxt: Variant = d.get("next")
	if typeof(nxt) != TYPE_DICTIONARY or nxt.is_empty():
		_item_errors.append("next: must be a non-empty object of weather id -> weight")
	else:
		for weather_id in nxt:
			if not _is_number(nxt[weather_id]) or nxt[weather_id] <= 0.0:
				_item_errors.append("next.%s: weight must be a number > 0" % weather_id)
	var visual: Variant = d.get("visual")
	if typeof(visual) != TYPE_DICTIONARY:
		_item_errors.append("visual: must be an object with cloud, rain, brightness and tint")
	else:
		_require_number(visual, "cloud", 0.0, 1.0, true, "visual.")
		_require_number(visual, "rain", 0.0, 1.0, true, "visual.")
		_require_number(visual, "brightness", 0.3, 1.2, true, "visual.")
		# P1-006: optional fog over the water and how often lightning flashes (0 = never).
		for optional in ["fog", "lightning"]:
			if visual.has(optional):
				_require_number(visual, optional, 0.0, 1.0, true, "visual.")
		if typeof(visual.get("tint")) != TYPE_STRING or RegEx.create_from_string(HEX_COLOR).search(visual["tint"]) == null:
			_item_errors.append("visual.tint: must be a #rrggbb color")

## Weather transitions may only lead to weather that exists.
func _check_weather_links(weather: Dictionary) -> void:
	for weather_id in weather:
		for target in weather[weather_id]["next"]:
			if not weather.has(target):
				_errors.append("weather.json[%s].next: unknown weather '%s'" % [weather_id, target])

func _check_behavior(d: Dictionary) -> void:
	_require_min_max(d, "pull_interval_sec", 0.1, 60.0)
	_require_min_max(d, "pull_duration_sec", 0.05, 30.0)
	_require_number(d, "pull_scale", 0.0, 3.0, false)
	if typeof(d.get("alternate")) != TYPE_BOOL:
		_item_errors.append("alternate: must be true or false")

func _check_fish(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string(d, "journal_key")
	if _require_string(d, "behavior") and not _behaviors.has(d["behavior"]):
		_item_errors.append("behavior: unknown behavior '%s'" % d["behavior"])
	_require_int(d, "rarity", 1, 5)
	_require_number(d, "base_weight", 0.0, INF, false)

	var fish_habitats: Dictionary = {}
	var fish_weather: Dictionary = {}
	if _require_string_list(d, "regions"):
		for region_id in d["regions"]:
			if not _regions.has(region_id):
				_item_errors.append("regions: unknown or invalid region '%s'" % region_id)
				continue
			for habitat in _regions[region_id]["habitats"]:
				fish_habitats[habitat] = true
			for weather_id in _regions[region_id]["weather"]:
				fish_weather[weather_id] = true

	if _require_string_list(d, "habitats"):
		for habitat in d["habitats"]:
			if not fish_habitats.has(habitat):
				_item_errors.append("habitats: '%s' does not exist in any of the fish's regions" % habitat)

	if _require_string_list(d, "bait_tags"):
		for tag in d["bait_tags"]:
			if not _bait_tags.has(tag):
				_item_errors.append("bait_tags: no bait provides tag '%s'" % tag)

	var size: Variant = d.get("size_cm")
	if typeof(size) != TYPE_DICTIONARY:
		_item_errors.append("size_cm: must be an object with min and max")
	elif not (_is_number(size.get("min")) and _is_number(size.get("max"))):
		_item_errors.append("size_cm: min and max must be numbers")
	elif size["min"] <= 0.0 or size["max"] <= size["min"]:
		_item_errors.append("size_cm: requires 0 < min < max (got %s..%s)" % [size["min"], size["max"]])

	_require_modifier_map(d, "time_bands", TIME_BANDS, "time band")
	_require_modifier_map(d, "weather", PackedStringArray(fish_weather.keys()), "weather in the fish's regions")

	var fight: Variant = d.get("fight")
	if typeof(fight) != TYPE_DICTIONARY:
		_item_errors.append("fight: must be an object with strength and duration_sec")
	else:
		_require_number(fight, "strength", 0.0, 1.0, true, "fight.")
		_require_number(fight, "duration_sec", 0.0, INF, false, "fight.")

func _validate_progression(data: Variant, regions: Dictionary, fish: Dictionary) -> Dictionary:
	var file_name: String = FILE_NAMES["progression"]
	# unique_fish is read as species discovered in the prerequisite region (the stricter
	# reading), so it must not exceed the species that live there.
	var species_per_region: Dictionary = {}
	for fish_def in fish.values():
		for region_id in fish_def["regions"]:
			species_per_region[region_id] = species_per_region.get(region_id, 0) + 1
	if data == null:
		return {}
	if typeof(data) != TYPE_DICTIONARY:
		_errors.append("%s: top level must be an object" % file_name)
		return {}
	var before := _errors.size()

	var points: Variant = data.get("restoration_points")
	if typeof(points) != TYPE_ARRAY or points.is_empty():
		_errors.append("%s.restoration_points: must be a non-empty array" % file_name)
	else:
		for i in points.size():
			if not _is_int(points[i]):
				_errors.append("%s.restoration_points[%d]: must be an integer" % [file_name, i])
			elif i == 0 and points[i] != 0:
				_errors.append("%s.restoration_points[0]: must be 0" % file_name)
			elif i > 0 and _is_int(points[i - 1]) and points[i] <= points[i - 1]:
				_errors.append("%s.restoration_points[%d]: must be greater than the previous value" % [file_name, i])
		for region_id in regions:
			var levels := int(regions[region_id]["restoration_levels"])
			if points.size() != levels + 1:
				_errors.append("%s.restoration_points: %d entries but %s has %d restoration levels (needs %d)" % [
					file_name, points.size(), region_id, levels, levels + 1])

	var unlocks: Variant = data.get("region_unlocks")
	if typeof(unlocks) != TYPE_ARRAY:
		_errors.append("%s.region_unlocks: must be an array" % file_name)
	else:
		var seen: Dictionary = {}
		var start_count := 0
		var prerequisite: Dictionary = {}  # region_id -> region that must progress first
		for i in unlocks.size():
			var label := "%s.region_unlocks[%d]" % [file_name, i]
			var entry: Variant = unlocks[i]
			if typeof(entry) != TYPE_DICTIONARY:
				_errors.append("%s: must be an object" % label)
				continue
			var region_id: Variant = entry.get("region_id")
			if not regions.has(region_id):
				_errors.append("%s.region_id: unknown or invalid region %s" % [label, var_to_str(region_id)])
			elif seen.has(region_id):
				_errors.append("%s.region_id: duplicate unlock for %s" % [label, region_id])
			seen[region_id] = true
			var condition: Variant = entry.get("condition")
			if typeof(condition) != TYPE_DICTIONARY:
				_errors.append("%s.condition: must be an object" % label)
			elif condition.get("type") == "start":
				start_count += 1
			else:
				var required_region: Variant = condition.get("region")
				if not regions.has(required_region):
					_errors.append("%s.condition.region: unknown or invalid region %s" % [label, var_to_str(required_region)])
				else:
					if regions.has(region_id):
						prerequisite[region_id] = required_region
					if not _is_int(condition.get("restoration_level")) \
							or condition["restoration_level"] < 0 \
							or condition["restoration_level"] > regions[required_region]["restoration_levels"]:
						_errors.append("%s.condition.restoration_level: must be an integer 0..%d" % [
							label, int(regions[required_region]["restoration_levels"])])
				if not _is_int(condition.get("unique_fish")) or condition["unique_fish"] < 0:
					_errors.append("%s.condition.unique_fish: must be a non-negative integer" % label)
				elif regions.has(required_region) \
						and condition["unique_fish"] > species_per_region.get(required_region, 0):
					_errors.append("%s.condition.unique_fish: %d exceeds the %d species that live in %s" % [
						label, int(condition["unique_fish"]), species_per_region.get(required_region, 0), required_region])
		if start_count != 1:
			_errors.append("%s.region_unlocks: exactly one region must have condition type 'start' (found %d)" % [
				file_name, start_count])
		for region_id in regions:
			if not seen.has(region_id):
				_errors.append("%s.region_unlocks: no unlock entry for %s" % [file_name, region_id])
		# Prerequisite chains must not loop: a region in a cycle can never unlock
		# (progression softlock, a QA release blocker). Chains that end anywhere
		# other than a start region are already reported above as missing/invalid entries.
		for region_id in prerequisite:
			var visited: Dictionary = {}
			var current: Variant = region_id
			while prerequisite.has(current) and not visited.has(current):
				visited[current] = true
				current = prerequisite[current]
			if prerequisite.has(current):
				_errors.append("%s.region_unlocks: unlock chain of %s loops and never reaches the start region" % [file_name, region_id])

	return data if _errors.size() == before else {}

func _validate_balance(data: Variant, regions: Dictionary, rods: Dictionary, baits: Dictionary,
		bags: Dictionary = {}, accessories: Dictionary = {}) -> Dictionary:
	var file_name: String = FILE_NAMES["balance"]
	if data == null:
		return {}
	if typeof(data) != TYPE_DICTIONARY:
		_errors.append("%s: top level must be an object" % file_name)
		return {}
	var before := _errors.size()

	var starting: Variant = data.get("starting_inventory")
	if typeof(starting) != TYPE_DICTIONARY:
		_errors.append("%s.starting_inventory: must be an object" % file_name)
	else:
		_check_owned_list(starting, "rods", rods, "starting_inventory.rods")
		_check_owned_list(starting, "baits", baits, "starting_inventory.baits")
		_check_owned_list(starting, "bags", bags, "starting_inventory.bags")
		_check_owned_list(starting, "accessories", accessories, "starting_inventory.accessories")
		for pair in [["equipped_rod", "rods"], ["equipped_bait", "baits"], ["equipped_bag", "bags"], ["equipped_accessory", "accessories"]]:
			var equipped: Variant = starting.get(pair[0])
			var owned: Variant = starting.get(pair[1])
			if typeof(owned) == TYPE_ARRAY and (typeof(equipped) != TYPE_STRING or not equipped in owned):
				_errors.append("%s.starting_inventory.%s: must be one of starting_inventory.%s (got %s)" % [
					file_name, pair[0], pair[1], var_to_str(equipped)])
		_check_starting_baits(starting, baits, bags)

	var offline: Variant = data.get("offline")
	if typeof(offline) != TYPE_DICTIONARY:
		_errors.append("%s.offline: must be an object" % file_name)
	else:
		_check_balance_number(offline, "offline", "min_minutes", 0, 600, true)
		_check_balance_number(offline, "offline", "cap_hours", 1, 24)
		_check_balance_number(offline, "offline", "hours_per_fish", 0.5, 48)
		_check_balance_number(offline, "offline", "level_speedup", 0, 1)
		_check_balance_number(offline, "offline", "max_fish_per_species", 0, 20, true)
		_check_balance_number(offline, "offline", "ripple_per_hour", 0, 100)
		_check_balance_number(offline, "offline", "ripple_per_level_hour", 0, 20)
		_check_balance_number(offline, "offline", "max_ripple", 0, 10000, true)

	var equipment: Variant = data.get("equipment")
	if typeof(equipment) != TYPE_DICTIONARY:
		_errors.append("%s.equipment: must be an object" % file_name)
	else:
		_check_balance_number(equipment, "equipment", "bait_pack_size", 1, 99, true)

	var time: Variant = data.get("time")
	if typeof(time) != TYPE_DICTIONARY:
		_errors.append("%s.time: must be an object" % file_name)
	else:
		var day_length: Variant = time.get("day_length_real_sec")
		if not _is_number(day_length) or day_length < 60.0 or day_length > 86400.0:
			_errors.append("%s.time.day_length_real_sec: must be a number in 60..86400 (got %s)" % [
				file_name, var_to_str(day_length)])
		var starts: Variant = time.get("band_starts_hour")
		if typeof(starts) != TYPE_DICTIONARY:
			_errors.append("%s.time.band_starts_hour: must be an object" % file_name)
		else:
			var previous := -1.0
			for band in TIME_BANDS:
				var hour: Variant = starts.get(band)
				if not _is_number(hour) or hour < 0.0 or hour >= 24.0:
					_errors.append("%s.time.band_starts_hour.%s: must be a number in 0..24 (got %s)" % [
						file_name, band, var_to_str(hour)])
				elif hour <= previous:
					_errors.append("%s.time.band_starts_hour.%s: bands must start in order %s" % [
						file_name, band, ", ".join(TIME_BANDS)])
				else:
					previous = hour
			for band in starts:
				if not band in TIME_BANDS:
					_errors.append("%s.time.band_starts_hour: '%s' is not a known time band" % [file_name, band])

	var encounter: Variant = data.get("encounter")
	if typeof(encounter) != TYPE_DICTIONARY:
		_errors.append("%s.encounter: must be an object" % file_name)
	else:
		_check_balance_number(encounter, "encounter", "bait_match_multiplier", 1.0, 10.0)
		_check_balance_number(encounter, "encounter", "pity_step", 0.0, 1.0)
		_check_balance_number(encounter, "encounter", "pity_cap", 0.0, 10.0)
		_check_balance_number(encounter, "encounter", "pity_min_rarity", 1.0, 5.0, true)
		_check_balance_number(encounter, "encounter", "ecosystem_rarity_bonus_per_level", 0.0, 2.0)
		_check_balance_number(encounter, "encounter", "size_skew", 0.1, 10.0)

	var fishing: Variant = data.get("fishing")
	if typeof(fishing) != TYPE_DICTIONARY:
		_errors.append("%s.fishing: must be an object" % file_name)
	else:
		_check_balance_range(fishing, "fishing", "cast_sec", 0.1, 10.0)
		_check_balance_range(fishing, "fishing", "wait_sec", 0.5, 120.0)
		_check_balance_range(fishing, "fishing", "bite_hint_sec", 0.1, 10.0)
		_check_balance_range(fishing, "fishing", "hook_window_sec", 0.3, 20.0)
		_check_balance_range(fishing, "fishing", "hook_window_relaxed_sec", 0.3, 20.0)
		for field in ["land_sec", "release_sec"]:
			_check_balance_number(fishing, "fishing", field, 0.1, 30.0)
		var wait: Variant = fishing.get("wait_sec")
		if typeof(wait) == TYPE_DICTIONARY:
			_check_balance_number(wait, "fishing.wait_sec", "floor", 0.5, 120.0)
			if _is_number(wait.get("floor")) and _is_number(wait.get("max")) and wait["floor"] > wait["max"]:
				_errors.append("%s.fishing.wait_sec.floor: must not exceed max" % file_name)
		var hook: Variant = fishing.get("hook_window_sec")
		var relaxed: Variant = fishing.get("hook_window_relaxed_sec")
		if typeof(hook) == TYPE_DICTIONARY and typeof(relaxed) == TYPE_DICTIONARY \
				and _is_number(hook.get("min")) and _is_number(relaxed.get("min")) \
				and _is_number(hook.get("max")) and _is_number(relaxed.get("max")) \
				and (relaxed["min"] < hook["min"] or relaxed["max"] < hook["max"]):
			_errors.append("%s.fishing.hook_window_relaxed_sec: relaxed windows must not be shorter than the normal ones (min and max)" % file_name)
		var fight: Variant = fishing.get("fight")
		if typeof(fight) != TYPE_DICTIONARY:
			_errors.append("%s.fishing.fight: must be an object" % file_name)
		else:
			_check_balance_range(fight, "fishing.fight", "band", 0.0, 1.0)
			for field in ["hold_target", "release_target", "start_progress", "slack_threshold", "snap_threshold"]:
				_check_balance_number(fight, "fishing.fight", field, 0.0, 1.0)
			for field in ["response_per_sec", "duration_scale", "slack_grace_sec", "snap_grace_sec"]:
				_check_balance_number(fight, "fishing.fight", field, 0.01, 60.0)
			for field in ["regress_above_band_per_sec", "regress_below_band_per_sec"]:
				_check_balance_number(fight, "fishing.fight", field, 0.0, 5.0)
			var band: Variant = fight.get("band")
			if typeof(band) == TYPE_DICTIONARY and _is_number(band.get("min")) and _is_number(band.get("max")):
				if _is_number(fight.get("release_target")) and fight["release_target"] >= band["min"]:
					_errors.append("%s.fishing.fight.release_target: must be below the safe band so letting go relaxes the line" % file_name)
				if _is_number(fight.get("hold_target")) and fight["hold_target"] <= band["max"]:
					_errors.append("%s.fishing.fight.hold_target: must be above the safe band so reeling tightens the line" % file_name)

	var rewards: Variant = data.get("rewards")
	if typeof(rewards) != TYPE_DICTIONARY:
		_errors.append("%s.rewards: must be an object" % file_name)
	else:
		var ripple_table: Variant = rewards.get("ripple_by_rarity")
		for rarity in ["1", "2", "3", "4", "5"]:
			if typeof(ripple_table) != TYPE_DICTIONARY:
				_errors.append("%s.rewards.ripple_by_rarity: must be an object keyed by rarity 1..5" % file_name)
				break
			_check_balance_range(ripple_table, "rewards.ripple_by_rarity", rarity, 0.0, 100000.0, true)
		for table_name in ["memory_first_discovery_by_rarity", "restoration_points_by_rarity"]:
			var table: Variant = rewards.get(table_name)
			if typeof(table) != TYPE_DICTIONARY:
				_errors.append("%s.rewards.%s: must be an object keyed by rarity 1..5" % [file_name, table_name])
				continue
			for rarity in ["1", "2", "3", "4", "5"]:
				_check_balance_number(table, "rewards." + table_name, rarity, 0.0, 100000.0, true)
		_check_balance_number(rewards, "rewards", "first_discovery_restoration_bonus", 0.0, 100000.0, true)
		_check_balance_number(rewards, "rewards", "repeat_decay_per_release", 0.0, 1.0)
		_check_balance_number(rewards, "rewards", "repeat_floor", 0.0, 1.0)
		if _is_number(rewards.get("repeat_floor")) and rewards["repeat_floor"] <= 0.0:
			_errors.append("%s.rewards.repeat_floor: must be above 0 so repeat catches never give nothing (BALANCE section 6)" % file_name)

	var population: Variant = data.get("population")
	if typeof(population) != TYPE_DICTIONARY:
		_errors.append("%s.population: must be an object" % file_name)
	else:
		var steps: Variant = population.get("visible_by_population")
		if typeof(steps) != TYPE_ARRAY or steps.is_empty():
			_errors.append("%s.population.visible_by_population: must be a non-empty array of {up_to, visible}" % file_name)
		else:
			var previous_limit := 0
			var previous_visible := 0
			for i in steps.size():
				var step: Variant = steps[i]
				if typeof(step) != TYPE_DICTIONARY or not _is_int(step.get("up_to")) or not _is_int(step.get("visible")):
					_errors.append("%s.population.visible_by_population[%d]: needs integer up_to and visible" % [file_name, i])
					break
				if step["up_to"] <= previous_limit or step["visible"] < previous_visible or step["visible"] < 1:
					_errors.append("%s.population.visible_by_population[%d]: up_to and visible must keep increasing (visible >= 1)" % [file_name, i])
					break
				previous_limit = int(step["up_to"])
				previous_visible = int(step["visible"])
		var totals: Variant = population.get("total_agents_by_quality")
		if typeof(totals) != TYPE_DICTIONARY:
			_errors.append("%s.population.total_agents_by_quality: must be an object with low, medium and high" % file_name)
		else:
			var last := 0
			for quality in ["low", "medium", "high"]:
				_check_balance_number(totals, "population.total_agents_by_quality", quality, 1.0, 500.0, true)
				if _is_number(totals.get(quality)):
					if totals[quality] < last:
						_errors.append("%s.population.total_agents_by_quality.%s: must not be smaller than the lower quality tier" % [file_name, quality])
					last = int(totals[quality])
		_check_balance_number(population, "population", "battery_saver_agent_factor", 0.1, 1.0)

	var journal: Variant = data.get("journal")
	if typeof(journal) != TYPE_DICTIONARY or typeof(journal.get("reveal_at_encounters")) != TYPE_DICTIONARY:
		_errors.append("%s.journal.reveal_at_encounters: must be an object" % file_name)
	else:
		var reveal: Dictionary = journal["reveal_at_encounters"]
		var previous_encounters := 0
		for field in ["size", "time_bands", "habitats", "behavior"]:
			_check_balance_number(reveal, "journal.reveal_at_encounters", field, 1.0, 1000.0, true)
			if _is_number(reveal.get(field)):
				if reveal[field] < previous_encounters:
					_errors.append("%s.journal.reveal_at_encounters.%s: information must unlock in the order size, time_bands, habitats, behavior" % [file_name, field])
				previous_encounters = int(reveal[field])

	var slice: Variant = data.get("vertical_slice")
	if typeof(slice) != TYPE_DICTIONARY:
		_errors.append("%s.vertical_slice: must be an object" % file_name)
	else:
		var region_id: Variant = slice.get("region_id")
		if not regions.has(region_id):
			_errors.append("%s.vertical_slice.region_id: unknown or invalid region %s" % [file_name, var_to_str(region_id)])
		elif not _is_int(slice.get("max_restoration_level")) 				or slice["max_restoration_level"] < 1 				or slice["max_restoration_level"] > regions[region_id]["restoration_levels"]:
			_errors.append("%s.vertical_slice.max_restoration_level: must be an integer 1..%d" % [
				file_name, int(regions[region_id]["restoration_levels"])])

	return data if _errors.size() == before else {}

## Content id aliases for old saves (DATA_SCHEMA §6): {category: {old_id: new_id}}. An old id must
## no longer exist, and following the chain must end at an existing id without looping.
func _validate_aliases(data: Variant, current: Dictionary) -> Dictionary:
	var file_name: String = FILE_NAMES["aliases"]
	if data == null:
		return {}
	if typeof(data) != TYPE_DICTIONARY:
		_errors.append("%s: top level must be an object" % file_name)
		return {}
	var before := _errors.size()
	for category in current:
		var table: Variant = data.get(category)
		if typeof(table) != TYPE_DICTIONARY:
			_errors.append("%s.%s: must be an object of old id -> new id" % [file_name, category])
			continue
		for old_id in table:
			var label := "%s.%s[%s]" % [file_name, category, old_id]
			if current[category].has(old_id):
				_errors.append("%s: the old id still exists as content" % label)
				continue
			var target: Variant = table[old_id]
			var hops := 0
			while typeof(target) == TYPE_STRING and table.has(target) and hops <= table.size():
				target = table[target]
				hops += 1
			if typeof(target) != TYPE_STRING or not current[category].has(target):
				_errors.append("%s: must lead to an existing %s id without looping (ends at %s)" % [
					label, category, var_to_str(target)])
	return data if _errors.size() == before else {}

## Region layouts (data/region_layouts.json): {region_id: layout}. Returns the valid layouts only.
## A region that has a layout must have every weather it lists defined, every habitat covered by
## at least one zone, and one visual palette per restoration level the slice can reach.
func _validate_layouts(data: Variant, regions: Dictionary, weather: Dictionary, balance: Dictionary) -> Dictionary:
	var file_name: String = FILE_NAMES["layouts"]
	var result: Dictionary = {}
	if data == null:
		return result
	if typeof(data) != TYPE_DICTIONARY:
		_errors.append("%s: top level must be an object keyed by region id" % file_name)
		return result
	var used_weather: Dictionary = {}
	for region_id in data:
		var label := "%s[%s]" % [file_name, region_id]
		if not regions.has(region_id):
			_errors.append("%s: unknown or invalid region" % label)
			continue
		var layout: Variant = data[region_id]
		if typeof(layout) != TYPE_DICTIONARY:
			_errors.append("%s: must be an object" % label)
			continue
		var before := _errors.size()
		var region: Dictionary = regions[region_id]
		for weather_id in region["weather"]:
			used_weather[weather_id] = true
			if not weather.has(weather_id):
				_errors.append("%s: region lists weather '%s' that weather.json does not define" % [label, weather_id])
		_check_layout(layout, region, balance, label)
		if _errors.size() == before:
			result[region_id] = layout
	for weather_id in weather:
		var in_any_region := false
		for region_def in regions.values():
			if weather_id in region_def["weather"]:
				in_any_region = true
		if not in_any_region:
			_errors.append("weather.json[%s]: no region lists this weather" % weather_id)
	return result

func _check_layout(layout: Dictionary, region: Dictionary, balance: Dictionary, label: String) -> void:
	var viewport: Variant = layout.get("viewport")
	var width := 0.0
	var height := 0.0
	if _is_point(viewport) and viewport[0] > 0 and viewport[1] > 0:
		width = float(viewport[0])
		height = float(viewport[1])
	else:
		_errors.append("%s.viewport: must be [width, height] > 0" % label)
	for field in ["rod_origin"]:
		if not _is_point_within(layout.get(field), width, height):
			_errors.append("%s.%s: must be a point inside the viewport" % [label, field])
	# The horizon may sit above the screen (a top-down view such as the main-world mockup has no sky).
	if not _is_number(layout.get("horizon_y")) or layout["horizon_y"] < -LAYOUT_BLEED.y * 4.0 or layout["horizon_y"] > height:
		_errors.append("%s.horizon_y: must be a number no lower than the viewport bottom" % label)
	if layout.has("cast_forward_deg") and (not _is_number(layout["cast_forward_deg"]) or absf(layout["cast_forward_deg"]) > 180.0):
		_errors.append("%s.cast_forward_deg: must be a number in -180..180" % label)
	if layout.has("angler"):
		var angler: Variant = layout["angler"]
		if typeof(angler) != TYPE_DICTIONARY or not _is_point_within([angler.get("x"), angler.get("y")], width, height):
			_errors.append("%s.angler: must be {x, y} inside the viewport" % label)
	if layout.has("waterfall"):
		var fall: Variant = layout["waterfall"]
		if typeof(fall) != TYPE_DICTIONARY or not _is_point_within_bleed([fall.get("x"), fall.get("y")], width, height) \
				or not _is_number(fall.get("width")) or not _is_number(fall.get("height")) or fall["width"] <= 0 or fall["height"] <= 0:
			_errors.append("%s.waterfall: must be {x, y, width > 0, height > 0} near the viewport" % label)
	var reach: Variant = layout.get("cast_reach_px")
	if typeof(reach) != TYPE_DICTIONARY or not _is_number(reach.get("near")) or not _is_number(reach.get("far")) \
			or reach["near"] <= 0 or reach["far"] <= reach["near"]:
		_errors.append("%s.cast_reach_px: requires 0 < near < far" % label)
	_check_polygon(layout.get("pond"), width, height, "%s.pond" % label, true)

	var covered: Dictionary = {}
	var zones: Variant = layout.get("zones")
	if typeof(zones) != TYPE_ARRAY or zones.is_empty():
		_errors.append("%s.zones: must be a non-empty array" % label)
	else:
		for i in zones.size():
			var zone: Variant = zones[i]
			if typeof(zone) != TYPE_DICTIONARY:
				_errors.append("%s.zones[%d]: must be an object" % [label, i])
				continue
			if typeof(zone.get("habitat")) != TYPE_STRING or not zone["habitat"] in region["habitats"]:
				_errors.append("%s.zones[%d].habitat: '%s' is not a habitat of the region" % [label, i, zone.get("habitat")])
			else:
				covered[zone["habitat"]] = true
			_check_polygon(zone.get("polygon"), width, height, "%s.zones[%d].polygon" % [label, i])
		for habitat in region["habitats"]:
			if not covered.has(habitat):
				_errors.append("%s.zones: habitat '%s' has no zone, so it could never be fished" % [label, habitat])

	var levels: Variant = layout.get("levels")
	var level_count := 0
	var color_pattern := RegEx.create_from_string(HEX_COLOR)
	if typeof(levels) != TYPE_ARRAY or levels.is_empty():
		_errors.append("%s.levels: must be a non-empty array, one palette per restoration level starting at 0" % label)
	else:
		level_count = levels.size()
		for i in levels.size():
			for field in ["water_deep", "water_shallow", "grass", "canopy"]:
				if typeof(levels[i]) != TYPE_DICTIONARY or typeof(levels[i].get(field)) != TYPE_STRING \
						or color_pattern.search(levels[i][field]) == null:
					_errors.append("%s.levels[%d].%s: must be a #rrggbb color" % [label, i, field])
		var slice: Variant = balance.get("vertical_slice")
		if typeof(slice) == TYPE_DICTIONARY and not slice.is_empty() and _is_int(slice.get("max_restoration_level")) \
				and region["id"] == slice.get("region_id") and levels.size() < int(slice["max_restoration_level"]) + 1:
			_errors.append("%s.levels: needs %d palettes (levels 0..%d of the vertical slice) but has %d" % [
				label, int(slice["max_restoration_level"]) + 1, int(slice["max_restoration_level"]), levels.size()])

	var props: Variant = layout.get("props")
	if typeof(props) != TYPE_ARRAY:
		_errors.append("%s.props: must be an array" % label)
	else:
		for i in props.size():
			var prop: Variant = props[i]
			var prop_label := "%s.props[%d]" % [label, i]
			if typeof(prop) != TYPE_DICTIONARY:
				_errors.append("%s: must be an object" % prop_label)
				continue
			if typeof(prop.get("kind")) != TYPE_STRING or not prop["kind"] in PROP_KINDS:
				_errors.append("%s.kind: unknown prop '%s' (known: %s)" % [prop_label, prop.get("kind"), ", ".join(PROP_KINDS)])
			if not _is_point_within_bleed([prop.get("x"), prop.get("y")], width, height):
				_errors.append("%s: x and y must be inside the viewport or its bleed margin" % prop_label)
			if prop.has("scale") and (not _is_number(prop["scale"]) or prop["scale"] < 0.2 or prop["scale"] > 3.0):
				_errors.append("%s.scale: must be a number in 0.2..3" % prop_label)
			var min_level: int = int(prop["min_level"]) if prop.has("min_level") and _is_int(prop["min_level"]) else 0
			var max_level: int = int(prop["max_level"]) if prop.has("max_level") and _is_int(prop["max_level"]) else 999
			for field in ["min_level", "max_level"]:
				if prop.has(field) and (not _is_int(prop[field]) or prop[field] < 0):
					_errors.append("%s.%s: must be an integer >= 0" % [prop_label, field])
			if min_level > max_level:
				_errors.append("%s: min_level must not exceed max_level" % prop_label)

	if layout.has("camp_slots"):
		var camp_slots: Variant = layout["camp_slots"]
		var slot_ids := {}
		if typeof(camp_slots) != TYPE_ARRAY:
			_errors.append("%s.camp_slots: must be an array" % label)
		else:
			for i in camp_slots.size():
				var slot: Variant = camp_slots[i]
				if typeof(slot) != TYPE_DICTIONARY or typeof(slot.get("id")) != TYPE_STRING or slot["id"].is_empty() \
						or not _is_point_within([slot.get("x"), slot.get("y")], width, height):
					_errors.append("%s.camp_slots[%d]: must be {id, x, y} inside the viewport" % [label, i])
				elif slot_ids.has(slot["id"]):
					_errors.append("%s.camp_slots[%d]: duplicate id %s" % [label, i, slot["id"]])
				else:
					slot_ids[slot["id"]] = true
	if layout.has("camp_focus"):
		var focus: Variant = layout["camp_focus"]
		if typeof(focus) != TYPE_DICTIONARY or not _is_point_within([focus.get("x"), focus.get("y")], width, height) \
				or not _is_number(focus.get("zoom")) or focus["zoom"] < 1.0 or focus["zoom"] > 3.0:
			_errors.append("%s.camp_focus: must be {x, y} inside the viewport and zoom 1..3" % label)

	var animals: Variant = layout.get("ambient_animals")
	if typeof(animals) != TYPE_ARRAY:
		_errors.append("%s.ambient_animals: must be an array" % label)
	else:
		for i in animals.size():
			var animal: Variant = animals[i]
			var animal_label := "%s.ambient_animals[%d]" % [label, i]
			if typeof(animal) != TYPE_DICTIONARY:
				_errors.append("%s: must be an object" % animal_label)
				continue
			if typeof(animal.get("kind")) != TYPE_STRING or not animal["kind"] in ANIMAL_KINDS:
				_errors.append("%s.kind: unknown animal '%s' (known: %s)" % [animal_label, animal.get("kind"), ", ".join(ANIMAL_KINDS)])
			if not _is_int(animal.get("count")) or animal["count"] < 1 or animal["count"] > 32:
				_errors.append("%s.count: must be an integer 1..32" % animal_label)
			if not _is_int(animal.get("min_level")) or animal["min_level"] < 0:
				_errors.append("%s.min_level: must be an integer >= 0" % animal_label)
			var bands: Variant = animal.get("time_bands")
			if typeof(bands) != TYPE_ARRAY or bands.is_empty():
				_errors.append("%s.time_bands: must be a non-empty array" % animal_label)
			else:
				for band in bands:
					if not band in TIME_BANDS:
						_errors.append("%s.time_bands: '%s' is not a known time band" % [animal_label, band])

## Audio mix (data/audio.json): loops, how weather/time shape them, wildlife one-shots and the
## fishing cues. Every stream must exist and every bus must be one of the project's buses.
func _validate_audio(data: Variant) -> Dictionary:
	var file_name: String = FILE_NAMES["audio"]
	if data == null:
		return {}
	if typeof(data) != TYPE_DICTIONARY:
		_errors.append("%s: top level must be an object" % file_name)
		return {}
	var before := _errors.size()

	var loops: Variant = data.get("loops")
	var loop_ids: Dictionary = {}
	if typeof(loops) != TYPE_ARRAY or loops.is_empty():
		_errors.append("%s.loops: must be a non-empty array" % file_name)
	else:
		for i in loops.size():
			var loop: Variant = loops[i]
			var label := "%s.loops[%d]" % [file_name, i]
			if typeof(loop) != TYPE_DICTIONARY or typeof(loop.get("id")) != TYPE_STRING:
				_errors.append("%s: needs an id, stream and bus" % label)
				continue
			if loop_ids.has(loop["id"]):
				_errors.append("%s.id: duplicate '%s'" % [label, loop["id"]])
			loop_ids[loop["id"]] = true
			_check_audio_source(loop, label)

	var mix: Variant = data.get("mix")
	if typeof(mix) != TYPE_DICTIONARY:
		_errors.append("%s.mix: must be an object" % file_name)
	else:
		for loop_id in loop_ids:
			if typeof(mix.get(loop_id)) != TYPE_DICTIONARY:
				_errors.append("%s.mix.%s: every loop needs mix settings" % [file_name, loop_id])
		# The mix rules (AmbientMix.loop_targets) read these keys unconditionally.
		var required := {"water": ["base", "rain_boost"], "wind": ["base", "cloud_boost", "night_factor"], "rain": ["gain"]}
		for loop_id in required:
			if typeof(mix.get(loop_id)) == TYPE_DICTIONARY:
				for key in required[loop_id]:
					if not mix[loop_id].has(key):
						_errors.append("%s.mix.%s.%s: required by the mix rules" % [file_name, loop_id, key])
		for loop_id in mix:
			if not loop_ids.has(loop_id):
				_errors.append("%s.mix.%s: no such loop" % [file_name, loop_id])
			elif typeof(mix[loop_id]) == TYPE_DICTIONARY:
				for key in mix[loop_id]:
					_check_balance_number(mix[loop_id], "mix." + loop_id, key, 0.0, 1.0, false, "audio")
	_check_balance_number(data, "mix", "fade_per_sec", 0.01, 5.0, false, "audio")

	var wildlife: Variant = data.get("wildlife")
	if typeof(wildlife) != TYPE_DICTIONARY:
		_errors.append("%s.wildlife: must be an object" % file_name)
	else:
		if not wildlife.get("bus") in AUDIO_BUSES:
			_errors.append("%s.wildlife.bus: must be one of %s" % [file_name, ", ".join(AUDIO_BUSES)])
		_check_balance_range(wildlife, "wildlife", "interval_sec", 0.5, 600.0, false, "audio")
		_check_balance_range(wildlife, "wildlife", "volume", 0.0, 1.0, false, "audio")
		_check_balance_number(wildlife, "wildlife", "level_speedup", 0.0, 2.0, false, "audio")
		var clips: Variant = wildlife.get("clips")
		if typeof(clips) != TYPE_ARRAY or clips.is_empty():
			_errors.append("%s.wildlife.clips: must be a non-empty array" % file_name)
		else:
			for i in clips.size():
				var clip: Variant = clips[i]
				var label := "%s.wildlife.clips[%d]" % [file_name, i]
				if typeof(clip) != TYPE_DICTIONARY:
					_errors.append("%s: must be an object" % label)
					continue
				if typeof(clip.get("stream")) != TYPE_STRING or not ResourceLoader.exists(clip["stream"]):
					_errors.append("%s.stream: file not found (%s)" % [label, var_to_str(clip.get("stream"))])
				if not _is_int(clip.get("min_level")) or clip["min_level"] < 0:
					_errors.append("%s.min_level: must be an integer >= 0" % label)
				if not _is_number(clip.get("weight")) or clip["weight"] <= 0.0:
					_errors.append("%s.weight: must be a number > 0" % label)
				var bands: Variant = clip.get("bands")
				if typeof(bands) != TYPE_ARRAY or bands.is_empty():
					_errors.append("%s.bands: must be a non-empty array" % label)
				else:
					for band in bands:
						if not band in TIME_BANDS:
							_errors.append("%s.bands: '%s' is not a known time band" % [label, band])

	var cues: Variant = data.get("cues")
	if typeof(cues) != TYPE_DICTIONARY:
		_errors.append("%s.cues: must be an object" % file_name)
	else:
		for cue_id in AUDIO_CUES:
			if typeof(cues.get(cue_id)) != TYPE_DICTIONARY:
				_errors.append("%s.cues.%s: missing" % [file_name, cue_id])
			else:
				_check_audio_source(cues[cue_id], "%s.cues.%s" % [file_name, cue_id])
				_check_balance_number(cues[cue_id], "cues." + cue_id, "volume", 0.0, 1.0, false, "audio")
	return data if _errors.size() == before else {}

func _check_audio_source(entry: Dictionary, label: String) -> void:
	if typeof(entry.get("stream")) != TYPE_STRING or not ResourceLoader.exists(entry["stream"]):
		_errors.append("%s.stream: file not found (%s)" % [label, var_to_str(entry.get("stream"))])
	if not entry.get("bus") in AUDIO_BUSES:
		_errors.append("%s.bus: must be one of %s (got %s)" % [label, ", ".join(AUDIO_BUSES), var_to_str(entry.get("bus"))])

## leed allows points in the margin around the viewport that wider or taller screens show (the pond
## and scenery continue past the design area so no edge is ever bare). Habitat zones never bleed: a cast
## must land where the design area can show it.
func _check_polygon(points: Variant, width: float, height: float, label: String, bleed: bool = false) -> void:
	if typeof(points) != TYPE_ARRAY or points.size() < 3:
		_errors.append("%s: must be a polygon with at least 3 points" % label)
		return
	for point in points:
		var inside := _is_point_within_bleed(point, width, height) if bleed else _is_point_within(point, width, height)
		if not inside:
			_errors.append("%s: every point must be [x, y] inside the viewport%s (got %s)" % [label, " or its bleed margin" if bleed else "", var_to_str(point)])
			return

static func _is_point(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() == 2 and _is_number(value[0]) and _is_number(value[1])

static func _is_point_within(value: Variant, width: float, height: float) -> bool:
	return _is_point(value) and value[0] >= 0 and value[0] <= width and value[1] >= 0 and value[1] <= height

static func _is_point_within_bleed(value: Variant, width: float, height: float) -> bool:
	return _is_point(value) and value[0] >= -LAYOUT_BLEED.x and value[0] <= width + LAYOUT_BLEED.x \
		and value[1] >= -LAYOUT_BLEED.y and value[1] <= height + LAYOUT_BLEED.y

## `section[field]` must be {"min": number, "max": number} with lo <= min <= max <= hi.
func _check_balance_range(section: Dictionary, section_name: String, field: String,
		lo: float, hi: float, integer: bool = false, file_key: String = "balance") -> void:
	var value: Variant = section.get(field)
	var label := "%s.%s.%s" % [FILE_NAMES[file_key], section_name, field]
	if typeof(value) != TYPE_DICTIONARY or not _is_number(value.get("min")) or not _is_number(value.get("max")):
		_errors.append("%s: must be an object with numeric min and max" % label)
		return
	if value["min"] < lo or value["max"] > hi or value["min"] > value["max"] \
			or (integer and not (_is_int(value["min"]) and _is_int(value["max"]))):
		_errors.append("%s: requires %s <= min <= max <= %s%s (got %s..%s)" % [
			label, lo, hi, " (integers)" if integer else "", value["min"], value["max"]])

## Appends an error unless `section[field]` is a finite number in [min_value, max_value]
## (an integer when `integer` is set).
func _check_balance_number(section: Dictionary, section_name: String, field: String,
		min_value: float, max_value: float, integer: bool = false, file_key: String = "balance") -> void:
	var value: Variant = section.get(field)
	if not _is_number(value) or value < min_value or value > max_value or (integer and not _is_int(value)):
		_errors.append("%s.%s.%s: must be %s in %s..%s (got %s)" % [
			FILE_NAMES[file_key], section_name, field, "an integer" if integer else "a number",
			min_value, max_value, var_to_str(value)])

## Starting bait stock: only owned consumable baits, fitting the starting bag, plus at least one endless
## bait so a player can always fish (D-019).
func _check_starting_baits(starting: Dictionary, baits: Dictionary, bags: Dictionary) -> void:
	var file_name: String = FILE_NAMES["balance"]
	var owned: Variant = starting.get("baits")
	var counts: Variant = starting.get("bait_counts")
	var carried := 0
	if typeof(counts) != TYPE_DICTIONARY:
		_errors.append("%s.starting_inventory.bait_counts: must be an object {bait_id: count}" % file_name)
	else:
		for bait_id in counts:
			if not baits.has(bait_id) or typeof(owned) != TYPE_ARRAY or not bait_id in owned or baits[bait_id]["consumable"] != true:
				_errors.append("%s.starting_inventory.bait_counts.%s: must be an owned consumable bait" % [file_name, bait_id])
			elif not _is_int(counts[bait_id]) or counts[bait_id] < 0:
				_errors.append("%s.starting_inventory.bait_counts.%s: must be an integer >= 0" % [file_name, bait_id])
			else:
				carried += int(counts[bait_id])
	var bag_id: Variant = starting.get("equipped_bag")
	if typeof(bag_id) == TYPE_STRING and bags.has(bag_id) and carried > int(bags[bag_id]["capacity"]):
		_errors.append("%s.starting_inventory.bait_counts: %d baits do not fit the starting bag (%d)" % [
			file_name, carried, int(bags[bag_id]["capacity"])])
	var endless := 0
	if typeof(owned) == TYPE_ARRAY:
		for bait_id in owned:
			if baits.has(bait_id) and baits[bait_id]["consumable"] == false:
				endless += 1
	if endless == 0:
		_errors.append("%s.starting_inventory.baits: needs an endless (consumable: false) bait so a player can always fish" % file_name)

func _check_owned_list(section: Dictionary, field: String, known: Dictionary, label: String) -> void:
	var file_name: String = FILE_NAMES["balance"]
	var value: Variant = section.get(field)
	if typeof(value) != TYPE_ARRAY or value.is_empty():
		_errors.append("%s.%s: must be a non-empty array" % [file_name, label])
		return
	var seen: Dictionary = {}
	for entry in value:
		if not known.has(entry):
			_errors.append("%s.%s: unknown or invalid id %s" % [file_name, label, var_to_str(entry)])
		elif seen.has(entry):
			_errors.append("%s.%s: duplicate id %s" % [file_name, label, var_to_str(entry)])
		seen[entry] = true

# --- field helpers ---

func _require_string(d: Dictionary, field: String) -> bool:
	var value: Variant = d.get(field)
	if typeof(value) != TYPE_STRING or value.strip_edges().is_empty():
		_item_errors.append("%s: must be a non-empty string" % field)
		return false
	return true

func _require_string_list(d: Dictionary, field: String) -> bool:
	var value: Variant = d.get(field)
	if typeof(value) != TYPE_ARRAY or value.is_empty():
		_item_errors.append("%s: must be a non-empty array" % field)
		return false
	var seen: Dictionary = {}
	for entry in value:
		if typeof(entry) != TYPE_STRING or entry.is_empty():
			_item_errors.append("%s: entries must be non-empty strings" % field)
			return false
		if seen.has(entry):
			_item_errors.append("%s: duplicate entry '%s'" % [field, entry])
			return false
		seen[entry] = true
	return true

func _require_int(d: Dictionary, field: String, min_value: int, max_value: int) -> void:
	var value: Variant = d.get(field)
	if not _is_int(value) or value < min_value or value > max_value:
		_item_errors.append("%s: must be an integer %d..%d (got %s)" % [field, min_value, max_value, var_to_str(value)])

## Range check is min < value <= max, or min <= value <= max when min_inclusive.
func _require_number(d: Dictionary, field: String, min_value: float, max_value: float,
		min_inclusive: bool, prefix: String = "") -> void:
	var value: Variant = d.get(field)
	var ok: bool = _is_number(value) and value <= max_value \
			and (value >= min_value if min_inclusive else value > min_value)
	if not ok:
		_item_errors.append("%s%s: must be a number in %s%s, %s] (got %s)" % [
			prefix, field, "[" if min_inclusive else "(", min_value, max_value, var_to_str(value)])

## `d[field]` must be {"min": number, "max": number} with lo <= min <= max <= hi.
func _require_min_max(d: Dictionary, field: String, lo: float, hi: float) -> void:
	var value: Variant = d.get(field)
	if typeof(value) != TYPE_DICTIONARY or not _is_number(value.get("min")) or not _is_number(value.get("max")):
		_item_errors.append("%s: must be an object with numeric min and max" % field)
	elif value["min"] < lo or value["max"] > hi or value["min"] > value["max"]:
		_item_errors.append("%s: requires %s <= min <= max <= %s (got %s..%s)" % [field, lo, hi, value["min"], value["max"]])

func _require_modifier_map(d: Dictionary, field: String, allowed: PackedStringArray, what: String) -> void:
	var value: Variant = d.get(field)
	if typeof(value) != TYPE_DICTIONARY:
		_item_errors.append("%s: must be an object of multipliers" % field)
		return
	for key in value:
		if not key in allowed:
			_item_errors.append("%s: '%s' is not a known %s" % [field, key, what])
		elif not _is_number(value[key]) or value[key] < 0.0:
			_item_errors.append("%s.%s: multiplier must be a number >= 0" % [field, key])

## Finite numbers only: an overflowing JSON literal such as 1e999 parses to INF.
static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value))

## JSON numbers arrive as floats; accept integral floats as integers.
static func _is_int(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))
