class_name SaveSchema
extends RefCounted

## PlayerSave v1 layout (DATA_SCHEMA §3-5): defaults, normalization and a sanity check.
## This is the single description of what a save looks like; GameState builds new games from
## it, SaveService validates with it before writing and after reading, and migrations end by
## normalizing against it.
##
## Rules (DATA_SCHEMA §6): missing fields get defaults, unknown fields are preserved, and
## numbers are coerced to their declared type. JSON parses every number as float, so
## normalization is also what makes a save round-trip equal to the in-memory state.

const CURRENT_VERSION := 1
## Upper bounds so a damaged or hand-edited save cannot hold values the game would later
## clamp downward (which would make an award reduce a balance).
const MAX_CURRENCY := 999_999_999
const MAX_POPULATION := 9999

const QUALITY_OPTIONS: PackedStringArray = ["low", "medium", "high"]
const FPS_OPTIONS: Array = [30, 60]

## Player-facing settings (UI_UX §9). `type` is the JSON-level type; numbers may carry a range,
## strings an `options` list. Content ids never appear here.
const SETTING_SPECS := {
	# Gameplay
	"relaxed_hook": {"default": false},
	"auto_hook": {"default": false},
	"real_time_mode": {"default": false},
	"tutorial_hints": {"default": true},
	# Accessibility
	"text_scale": {"default": 1.0, "min": 0.8, "max": 1.6},
	"large_ui": {"default": false},
	"reduced_motion": {"default": false},
	"camera_shake": {"default": true},
	"haptics": {"default": true},
	"high_contrast_meter": {"default": false},
	"visual_bite_cue": {"default": false},
	# Graphics
	"quality": {"default": "medium", "options": QUALITY_OPTIONS},
	"fps_cap": {"default": 30, "options_int": FPS_OPTIONS},
	"battery_saver": {"default": false},
	# Audio (linear 0..1 per bus)
	"volume_master": {"default": 1.0, "min": 0.0, "max": 1.0},
	"volume_bgm": {"default": 0.7, "min": 0.0, "max": 1.0},
	"volume_water": {"default": 0.8, "min": 0.0, "max": 1.0},
	"volume_wind": {"default": 0.6, "min": 0.0, "max": 1.0},
	"volume_wildlife": {"default": 0.7, "min": 0.0, "max": 1.0},
	"volume_weather": {"default": 0.7, "min": 0.0, "max": 1.0},
	"volume_fishing": {"default": 0.8, "min": 0.0, "max": 1.0},
	"volume_camp": {"default": 0.7, "min": 0.0, "max": 1.0},
	# Water-mind (UI_UX §8): minutes of inactivity before dimming, 0 = never.
	"water_mind_dim_minutes": {"default": 5, "min": 0, "max": 60},
	"battery_saver_hint_seen": {"default": false},
}

static func default_settings() -> Dictionary:
	var settings := {}
	for key in SETTING_SPECS:
		settings[key] = SETTING_SPECS[key]["default"]
	return settings

## Returns `value` coerced into the setting's domain, or the default when the type does not
## fit. `is_known_setting(key)` must hold. Numeric values are clamped, never rejected.
static func sanitize_setting(key: String, value: Variant) -> Variant:
	var spec: Dictionary = SETTING_SPECS[key]
	var default_value: Variant = spec["default"]
	match typeof(default_value):
		TYPE_BOOL:
			return value if typeof(value) == TYPE_BOOL else default_value
		TYPE_STRING:
			return value if typeof(value) == TYPE_STRING and value in spec["options"] else default_value
		TYPE_INT:
			if not _is_number(value):
				return default_value
			var as_int := roundi(float(value))
			if spec.has("options_int"):
				return as_int if as_int in spec["options_int"] else default_value
			return clampi(as_int, int(spec["min"]), int(spec["max"]))
		TYPE_FLOAT:
			if not _is_number(value):
				return default_value
			return clampf(float(value), float(spec["min"]), float(spec["max"]))
	return default_value

static func is_known_setting(key: String) -> bool:
	return SETTING_SPECS.has(key)

static func default_region(_region_id: String = "") -> Dictionary:
	return {
		"restoration_level": 0,
		"restoration_points": 0,
		"species_population": {},
		"unlocked_spots": [],
		"seen_events": [],
	}

static func default_collection_record() -> Dictionary:
	return {
		"encounters": 0,
		"releases": 0,
		"largest_cm": 0.0,
		"smallest_cm": 0.0,
		"first_seen_at": 0,
		"last_seen_at": 0,
		"observed_behaviors": [],
	}

static func default_save(now: int) -> Dictionary:
	return {
		"save_version": CURRENT_VERSION,
		"profile": {"created_at": now, "last_session_at": now, "game_minutes": 480.0},
		"economy": {"ripple": 0, "memory": 0},
		"regions": {},
		"collection": {},
		"inventory": {"rods": [], "baits": [], "equipped_rod": "", "equipped_bait": ""},
		"settings": default_settings(),
		"entitlement_cache": {"full_game": false},
		# A fish that was caught but not yet released when the game closed (see GameState).
		"session": {"pending_catch": {}},
	}

## Returns a copy of `raw` with every known field present and correctly typed, keeping
## unknown fields. Non-Dictionary input yields a default save.
static func normalize(raw: Variant, now: int) -> Dictionary:
	var result := default_save(now)
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var input: Dictionary = raw.duplicate(true)

	# Unknown top-level fields and unknown fields inside known sections are kept as-is.
	for key in input:
		if not result.has(key):
			result[key] = input[key]

	result["save_version"] = _int_or(input.get("save_version"), CURRENT_VERSION)
	_merge_section(result, input, "profile")
	_merge_section(result, input, "economy")
	_merge_section(result, input, "entitlement_cache")
	_merge_section(result, input, "session")
	_merge_section(result, input, "inventory")

	var profile: Dictionary = result["profile"]
	profile["created_at"] = maxi(0, _int_or(profile.get("created_at"), now))
	profile["last_session_at"] = maxi(0, _int_or(profile.get("last_session_at"), now))
	profile["game_minutes"] = _float_or(profile.get("game_minutes"), 480.0)

	var economy: Dictionary = result["economy"]
	economy["ripple"] = clampi(_int_or(economy.get("ripple"), 0), 0, MAX_CURRENCY)
	economy["memory"] = clampi(_int_or(economy.get("memory"), 0), 0, MAX_CURRENCY)

	var entitlement: Dictionary = result["entitlement_cache"]
	entitlement["full_game"] = entitlement.get("full_game") == true

	var inventory: Dictionary = result["inventory"]
	inventory["rods"] = _string_list(inventory.get("rods"))
	inventory["baits"] = _string_list(inventory.get("baits"))
	inventory["equipped_rod"] = _string_or(inventory.get("equipped_rod"), "")
	inventory["equipped_bait"] = _string_or(inventory.get("equipped_bait"), "")
	# Saves written before equipment was tracked own items but have nothing equipped; fall back to
	# the first owned item so the player never holds an invalid or empty equipment id.
	for pair in [["equipped_rod", "rods"], ["equipped_bait", "baits"]]:
		var owned: Array = inventory[pair[1]]
		if not owned.has(inventory[pair[0]]):
			inventory[pair[0]] = owned[0] if not owned.is_empty() else ""

	var session: Dictionary = result["session"]
	var pending: Variant = session.get("pending_catch")
	session["pending_catch"] = pending if typeof(pending) == TYPE_DICTIONARY else {}

	# Settings: known keys are sanitized, unknown keys survive untouched.
	var settings := default_settings()
	var raw_settings: Variant = input.get("settings")
	if typeof(raw_settings) == TYPE_DICTIONARY:
		for key in raw_settings:
			if typeof(key) == TYPE_STRING and is_known_setting(key):
				settings[key] = sanitize_setting(key, raw_settings[key])
			else:
				settings[key] = raw_settings[key]
	result["settings"] = settings

	var regions := {}
	var raw_regions: Variant = input.get("regions")
	if typeof(raw_regions) == TYPE_DICTIONARY:
		for region_id in raw_regions:
			regions[region_id] = _normalize_region(raw_regions[region_id])
	result["regions"] = regions

	var collection := {}
	var raw_collection: Variant = input.get("collection")
	if typeof(raw_collection) == TYPE_DICTIONARY:
		for fish_id in raw_collection:
			collection[fish_id] = _normalize_collection_record(raw_collection[fish_id])
	result["collection"] = collection
	return result

## Sanity check for a normalized save. Returns human-readable problems; empty means the save
## is safe to write and to load. It checks shape and ranges, not content ids.
static func validate(save: Variant) -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(save) != TYPE_DICTIONARY:
		problems.append("save is not an object")
		return problems
	var version: Variant = save.get("save_version")
	if typeof(version) != TYPE_INT or version < 1:
		problems.append("save_version must be an integer >= 1")
	for section in ["profile", "economy", "regions", "collection", "inventory", "settings", "entitlement_cache", "session"]:
		if typeof(save.get(section)) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % section)
	if not problems.is_empty():
		return problems

	for key in ["created_at", "last_session_at"]:
		if typeof(save["profile"].get(key)) != TYPE_INT or save["profile"][key] < 0:
			problems.append("profile.%s must be a non-negative integer" % key)
	if typeof(save["profile"].get("game_minutes")) != TYPE_FLOAT:
		problems.append("profile.game_minutes must be a number")
	for key in ["ripple", "memory"]:
		if typeof(save["economy"].get(key)) != TYPE_INT or save["economy"][key] < 0 or save["economy"][key] > MAX_CURRENCY:
			problems.append("economy.%s must be an integer in 0..%d" % [key, MAX_CURRENCY])

	for region_id in save["regions"]:
		var region: Variant = save["regions"][region_id]
		if typeof(region) != TYPE_DICTIONARY:
			problems.append("regions.%s must be an object" % region_id)
			continue
		for key in ["restoration_level", "restoration_points"]:
			if typeof(region.get(key)) != TYPE_INT or region[key] < 0:
				problems.append("regions.%s.%s must be a non-negative integer" % [region_id, key])
		if typeof(region.get("species_population")) != TYPE_DICTIONARY:
			problems.append("regions.%s.species_population must be an object" % region_id)
		else:
			for fish_id in region["species_population"]:
				var population: Variant = region["species_population"][fish_id]
				if typeof(population) != TYPE_INT or population < 0:
					problems.append("regions.%s.species_population.%s must be a non-negative integer" % [region_id, fish_id])

	for fish_id in save["collection"]:
		var record: Variant = save["collection"][fish_id]
		if typeof(record) != TYPE_DICTIONARY:
			problems.append("collection.%s must be an object" % fish_id)
			continue
		for key in ["encounters", "releases"]:
			if typeof(record.get(key)) != TYPE_INT or record[key] < 0:
				problems.append("collection.%s.%s must be a non-negative integer" % [fish_id, key])
		for key in ["largest_cm", "smallest_cm"]:
			if typeof(record.get(key)) != TYPE_FLOAT or record[key] < 0.0:
				problems.append("collection.%s.%s must be a non-negative number" % [fish_id, key])
	return problems

# --- helpers ---

static func _normalize_region(raw: Variant) -> Dictionary:
	var region := default_region()
	if typeof(raw) != TYPE_DICTIONARY:
		return region
	for key in raw:
		if not region.has(key):
			region[key] = raw[key]
	region["restoration_level"] = maxi(0, _int_or(raw.get("restoration_level"), 0))
	region["restoration_points"] = clampi(_int_or(raw.get("restoration_points"), 0), 0, MAX_CURRENCY)
	var population := {}
	var raw_population: Variant = raw.get("species_population")
	if typeof(raw_population) == TYPE_DICTIONARY:
		for fish_id in raw_population:
			population[fish_id] = clampi(_int_or(raw_population[fish_id], 0), 0, MAX_POPULATION)
	region["species_population"] = population
	region["unlocked_spots"] = _string_list(raw.get("unlocked_spots"))
	region["seen_events"] = _string_list(raw.get("seen_events"))
	return region

static func _normalize_collection_record(raw: Variant) -> Dictionary:
	var record := default_collection_record()
	if typeof(raw) != TYPE_DICTIONARY:
		return record
	for key in raw:
		if not record.has(key):
			record[key] = raw[key]
	record["encounters"] = maxi(0, _int_or(raw.get("encounters"), 0))
	record["releases"] = maxi(0, _int_or(raw.get("releases"), 0))
	record["largest_cm"] = maxf(0.0, _float_or(raw.get("largest_cm"), 0.0))
	record["smallest_cm"] = maxf(0.0, _float_or(raw.get("smallest_cm"), 0.0))
	record["first_seen_at"] = maxi(0, _int_or(raw.get("first_seen_at"), 0))
	record["last_seen_at"] = maxi(0, _int_or(raw.get("last_seen_at"), 0))
	record["observed_behaviors"] = _string_list(raw.get("observed_behaviors"))
	return record

## Copies a known section from `input` over the default, keeping unknown keys inside it.
static func _merge_section(result: Dictionary, input: Dictionary, section: String) -> void:
	var raw: Variant = input.get(section)
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var merged: Dictionary = result[section]
	for key in raw:
		merged[key] = raw[key]

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value))

static func _int_or(value: Variant, fallback: int) -> int:
	if not _is_number(value):
		return fallback
	return roundi(float(value))

static func _float_or(value: Variant, fallback: float) -> float:
	return float(value) if _is_number(value) else fallback

static func _string_or(value: Variant, fallback: String) -> String:
	return value if typeof(value) == TYPE_STRING else fallback

static func _string_list(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_STRING and not result.has(entry):
			result.append(entry)
	return result
