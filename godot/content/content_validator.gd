class_name ContentValidator
extends RefCounted

## Validates raw parsed content (DATA_SCHEMA §7) and returns only the entries
## that passed, indexed by id. Entries with any error are excluded so runtime
## code never sees malformed definitions; every problem is reported in `errors`.
##
## Input:  {"fish": Array, "regions": Array, "rods": Array, "baits": Array,
##          "progression": Dictionary} — a value may be null when its file
##          could not be read (the loader reports that error itself).
## Output: {"fish": {id: def}, "regions": {...}, "rods": {...}, "baits": {...},
##          "progression": Dictionary (empty if invalid), "errors": PackedStringArray}

const TIME_BANDS: PackedStringArray = preload("res://autoload/time_service.gd").TIME_BANDS

const FILE_NAMES := {
	"fish": "fish_catalog.json",
	"regions": "regions.json",
	"rods": "rods.json",
	"baits": "baits.json",
	"progression": "progression.json",
}

const ID_PATTERNS := {
	"fish": "^fish_[a-z0-9_]+$",
	"regions": "^region_[0-9]{2}_[a-z0-9_]+$",
	"rods": "^rod_[a-z0-9_]+$",
	"baits": "^bait_[a-z0-9_]+$",
}

static func validate(raw: Dictionary) -> Dictionary:
	var v := ContentValidator.new()
	var regions := v._validate_list(raw.get("regions"), "regions", v._check_region)
	v._regions = regions
	var baits := v._validate_list(raw.get("baits"), "baits", v._check_bait)
	for bait_def in baits.values():
		for tag in bait_def["tags"]:
			v._bait_tags[tag] = true
	var rods := v._validate_list(raw.get("rods"), "rods", v._check_rod)
	var fish := v._validate_list(raw.get("fish"), "fish", v._check_fish)
	var progression := v._validate_progression(raw.get("progression"), regions)
	return {
		"fish": fish,
		"regions": regions,
		"rods": rods,
		"baits": baits,
		"progression": progression,
		"errors": v._errors,
	}

var _errors := PackedStringArray()
var _regions: Dictionary = {}
var _bait_tags: Dictionary = {}
var _item_errors := PackedStringArray()

func _validate_list(items: Variant, category: String, check: Callable) -> Dictionary:
	var file_name: String = FILE_NAMES[category]
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

func _check_bait(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string_list(d, "tags")
	if typeof(d.get("consumable")) != TYPE_BOOL:
		_item_errors.append("consumable: must be true or false")

func _check_rod(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_number(d, "range", 0.0, 1.0, false)
	_require_number(d, "bite_speed", 0.0, INF, false)
	_require_number(d, "tension_assist", 0.0, 1.0, true)
	_require_string_list(d, "tags")

func _check_fish(d: Dictionary) -> void:
	_require_string(d, "name_key")
	_require_string(d, "journal_key")
	_require_string(d, "behavior")
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

func _validate_progression(data: Variant, regions: Dictionary) -> Dictionary:
	var file_name: String = FILE_NAMES["progression"]
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
