extends Node

## Read-only static content (fish, regions, rods, baits, progression, balance) loaded
## from JSON and validated by ContentValidator. Invalid entries are excluded and
## every problem is logged with push_error and kept in `errors` for diagnostics.

const DEFAULT_DATA_DIR := "res://data"

var fish: Dictionary = {}
var regions: Dictionary = {}
var rods: Dictionary = {}
var baits: Dictionary = {}
var progression: Dictionary = {}
var balance: Dictionary = {}
var aliases: Dictionary = {}
var behaviors: Dictionary = {}
var weather: Dictionary = {}
var layouts: Dictionary = {}
var audio: Dictionary = {}
var bags: Dictionary = {}
var accessories: Dictionary = {}
var decorations: Dictionary = {}
var moments: Dictionary = {}
var errors := PackedStringArray()

var _fish_by_region: Dictionary = {}

func _ready() -> void:
	load_all()

## Loads and validates every content file in `data_dir`. Returns true when the
## content is fully valid. Previously loaded content is replaced either way.
func load_all(data_dir: String = DEFAULT_DATA_DIR) -> bool:
	var load_errors := PackedStringArray()
	var raw: Dictionary = {}
	for category in ContentValidator.FILE_NAMES:
		raw[category] = _read_json(data_dir.path_join(ContentValidator.FILE_NAMES[category]), load_errors)

	var result := ContentValidator.validate(raw)
	fish = result["fish"]
	regions = result["regions"]
	rods = result["rods"]
	baits = result["baits"]
	progression = result["progression"]
	balance = result["balance"]
	aliases = result["aliases"]
	behaviors = result["behaviors"]
	weather = result["weather"]
	layouts = result["layouts"]
	audio = result["audio"]
	bags = result["bags"]
	accessories = result["accessories"]
	decorations = result["decorations"]
	moments = result["moments"]
	_fish_by_region.clear()
	errors = load_errors
	errors.append_array(result["errors"])

	for problem in errors:
		push_error("Content: %s" % problem)
	return errors.is_empty()

func is_valid() -> bool:
	return errors.is_empty()

## Returns the definition or an empty Dictionary when the id is unknown.
func get_fish(fish_id: String) -> Dictionary:
	return fish.get(fish_id, {})

func get_region(region_id: String) -> Dictionary:
	return regions.get(region_id, {})

## Fish definitions that live in `region_id`, in catalog order. Cached per load so callers
## (encounter rolls, presenters) never scan the whole catalog.
func get_fish_for_region(region_id: String) -> Array:
	if _fish_by_region.is_empty():
		for fish_def in fish.values():
			for fish_region in fish_def["regions"]:
				if not _fish_by_region.has(fish_region):
					_fish_by_region[fish_region] = []
				_fish_by_region[fish_region].append(fish_def)
	return _fish_by_region.get(region_id, [])

func get_weather(weather_id: String) -> Dictionary:
	return weather.get(weather_id, {})

## Layout (pond, habitat zones, restoration palettes, props) of a region; empty if it has none yet.
func get_layout(region_id: String) -> Dictionary:
	return layouts.get(region_id, {})

func get_behavior(behavior_id: String) -> Dictionary:
	return behaviors.get(behavior_id, {})

func get_rod(rod_id: String) -> Dictionary:
	return rods.get(rod_id, {})

func get_bait(bait_id: String) -> Dictionary:
	return baits.get(bait_id, {})

## Returns parsed JSON, or null (with an error recorded) when the file is
## missing, unreadable or malformed.
func _read_json(path: String, load_errors: PackedStringArray) -> Variant:
	var file_name := path.get_file()
	if not FileAccess.file_exists(path):
		load_errors.append("%s: file not found (%s)" % [file_name, path])
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		load_errors.append("%s: cannot read (%s)" % [file_name, error_string(FileAccess.get_open_error())])
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		load_errors.append("%s: invalid JSON at line %d: %s" % [
			file_name, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

func get_bag(bag_id: String) -> Dictionary:
	return bags.get(bag_id, {})

func get_accessory(accessory_id: String) -> Dictionary:
	return accessories.get(accessory_id, {})

func get_decoration(decoration_id: String) -> Dictionary:
	return decorations.get(decoration_id, {})

## Definition of an item by category: "rod", "bait", "bag", "accessory" or "decoration".
func get_item(category: String, item_id: String) -> Dictionary:
	match category:
		"rod": return get_rod(item_id)
		"bait": return get_bait(item_id)
		"bag": return get_bag(item_id)
		"accessory": return get_accessory(item_id)
		"decoration": return get_decoration(item_id)
	return {}
