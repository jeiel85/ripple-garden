class_name SaveMigrator
extends RefCounted

## Brings a parsed save up to SaveSchema.CURRENT_VERSION (DATA_SCHEMA §6).
##
## Rules:
##  - Migrations run one version at a time, in order: `migrations[N]` turns a vN save into vN+1.
##  - A save newer than this build is refused untouched; downgrading would silently drop data.
##  - After the last step the save is normalized (defaults injected, unknown fields kept),
##    content id aliases are applied, and the result must pass SaveSchema.validate().
##  - The caller (SaveService) backs the original file up before it is replaced by a migrated one.
##
## Production migrations are listed by production_migrations(); tests inject their own table through
## the constructor.
##
##   1 -> 2 (D-019)  Saves from before counted baits get a marker so GameState can give their owned
##                   baits the starting stock (the starting numbers are content, which a migration does
##                   not read). The marker is the only change; everything else is filled by normalize.

## Set by the 1 -> 2 migration on inventories that had no bait stock yet; GameState consumes it.
const LEGACY_BAIT_MARKER := "needs_starting_bait_stock"

## from_version -> Callable(save: Dictionary) -> Dictionary (the save at from_version + 1).
static func production_migrations() -> Dictionary:
	return {1: _v1_to_v2}

static func _v1_to_v2(save: Dictionary) -> Dictionary:
	var inventory: Variant = save.get("inventory")
	if typeof(inventory) == TYPE_DICTIONARY and not inventory.has("bait_counts"):
		inventory[LEGACY_BAIT_MARKER] = true
	return save

var current_version: int
var _migrations: Dictionary
var _aliases: Dictionary

## `aliases` is {"fish": {old_id: new_id}, "rods": ..., "baits": ..., "regions": ...}.
## `migrations` defaults to production_migrations() when null.
func _init(version: int = SaveSchema.CURRENT_VERSION, migrations: Variant = null,
		aliases: Dictionary = {}) -> void:
	current_version = version
	_migrations = migrations if migrations is Dictionary else production_migrations()
	_aliases = aliases

## Returns {"ok": bool, "save": Dictionary, "from_version": int, "error": String, "newer": bool}.
## `save` is only meaningful when ok. `newer` marks a save written by a newer build.
func migrate(raw: Variant, now: int) -> Dictionary:
	var failure := {"ok": false, "save": {}, "from_version": 0, "error": "", "newer": false}
	if typeof(raw) != TYPE_DICTIONARY:
		failure["error"] = "save is not an object"
		return failure
	var version_value: Variant = raw.get("save_version")
	if not SaveSchema._is_number(version_value) or float(version_value) != floorf(float(version_value)) \
			or version_value < 1:
		failure["error"] = "save_version missing or invalid"
		return failure
	var from_version := int(version_value)
	failure["from_version"] = from_version
	if from_version > current_version:
		failure["error"] = "save is version %d but this build only understands up to %d" % [from_version, current_version]
		failure["newer"] = true
		return failure

	var save: Dictionary = raw.duplicate(true)
	for version in range(from_version, current_version):
		if not _migrations.has(version):
			failure["error"] = "no migration from version %d to %d" % [version, version + 1]
			return failure
		var migrated: Variant = _migrations[version].call(save.duplicate(true))
		if typeof(migrated) != TYPE_DICTIONARY:
			failure["error"] = "migration from version %d returned %s instead of an object" % [version, type_string(typeof(migrated))]
			return failure
		save = migrated
		save["save_version"] = version + 1

	save = SaveSchema.normalize(save, now)
	save["save_version"] = current_version
	save = apply_aliases(save, _aliases)
	var problems := SaveSchema.validate(save)
	if not problems.is_empty():
		failure["error"] = "migrated save is invalid: %s" % "; ".join(problems)
		return failure
	return {"ok": true, "save": save, "from_version": from_version, "error": "", "newer": false}

# --- content id aliases ---

## Rewrites ids of removed/renamed content to their replacements, merging records when the new
## id already has data. Alias chains (a -> b -> c) are followed; a cycle leaves the id alone.
static func apply_aliases(save: Dictionary, aliases: Dictionary) -> Dictionary:
	if aliases.is_empty():
		return save
	var result := save.duplicate(true)
	var fish_aliases: Dictionary = aliases.get("fish", {})
	var region_aliases: Dictionary = aliases.get("regions", {})

	# Collection and per-region populations are keyed by fish id.
	result["collection"] = _remap_keys(result["collection"], fish_aliases, _merge_collection_records)
	for region_id in result["regions"]:
		var region: Dictionary = result["regions"][region_id]
		region["species_population"] = _remap_keys(region["species_population"], fish_aliases, _sum_ints)
	result["regions"] = _remap_keys(result["regions"], region_aliases, _merge_regions)

	var inventory: Dictionary = result["inventory"]
	inventory["rods"] = _remap_list(inventory["rods"], aliases.get("rods", {}))
	inventory["baits"] = _remap_list(inventory["baits"], aliases.get("baits", {}))
	inventory["equipped_rod"] = _resolve(inventory["equipped_rod"], aliases.get("rods", {}))
	inventory["equipped_bait"] = _resolve(inventory["equipped_bait"], aliases.get("baits", {}))
	# Bait stock follows its bait: a renamed bait keeps its count (merged if the new id already had some).
	inventory["bait_counts"] = _remap_keys(inventory.get("bait_counts", {}), aliases.get("baits", {}), _sum_bait_counts)

	var pending: Dictionary = result["session"]["pending_catch"]
	if pending.has("fish_id"):
		pending["fish_id"] = _resolve(pending["fish_id"], fish_aliases)
	if pending.has("region_id"):
		pending["region_id"] = _resolve(pending["region_id"], region_aliases)
	return result

static func _resolve(item_id: Variant, aliases: Dictionary) -> Variant:
	var current: Variant = item_id
	var hops := 0
	while aliases.has(current):
		current = aliases[current]
		hops += 1
		if hops > aliases.size():
			return item_id  # cycle: keep the original id rather than loop forever
	return current

static func _remap_list(items: Array, aliases: Dictionary) -> Array:
	var result: Array = []
	for item in items:
		var resolved: Variant = _resolve(item, aliases)
		if not result.has(resolved):
			result.append(resolved)
	return result

static func _remap_keys(source: Dictionary, aliases: Dictionary, merge: Callable) -> Dictionary:
	var result := {}
	for key in source:
		var target: Variant = _resolve(key, aliases)
		result[target] = merge.call(result[target], source[key]) if result.has(target) else source[key]
	return result

static func _sum_ints(a: int, b: int) -> int:
	return mini(a + b, SaveSchema.MAX_POPULATION)

static func _sum_bait_counts(a: int, b: int) -> int:
	return mini(a + b, SaveSchema.MAX_BAIT_COUNT)

static func _merge_collection_records(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged := a.duplicate(true)
	merged["encounters"] = a["encounters"] + b["encounters"]
	merged["releases"] = a["releases"] + b["releases"]
	merged["largest_cm"] = maxf(a["largest_cm"], b["largest_cm"])
	merged["smallest_cm"] = _min_nonzero(a["smallest_cm"], b["smallest_cm"])
	merged["first_seen_at"] = int(_min_nonzero(a["first_seen_at"], b["first_seen_at"]))
	merged["last_seen_at"] = maxi(a["last_seen_at"], b["last_seen_at"])
	for behavior in b["observed_behaviors"]:
		if not merged["observed_behaviors"].has(behavior):
			merged["observed_behaviors"].append(behavior)
	return merged

static func _merge_regions(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged := a.duplicate(true)
	merged["restoration_level"] = maxi(a["restoration_level"], b["restoration_level"])
	merged["restoration_points"] = maxi(a["restoration_points"], b["restoration_points"])
	for fish_id in b["species_population"]:
		merged["species_population"][fish_id] = mini(
			merged["species_population"].get(fish_id, 0) + b["species_population"][fish_id], SaveSchema.MAX_POPULATION)
	for key in ["unlocked_spots", "seen_events"]:
		for entry in b[key]:
			if not merged[key].has(entry):
				merged[key].append(entry)
	return merged

## Smaller of two values where 0 means "unset".
static func _min_nonzero(a: float, b: float) -> float:
	if a == 0.0:
		return b
	if b == 0.0:
		return a
	return minf(a, b)
