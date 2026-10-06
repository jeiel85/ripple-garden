extends Node

## Read-only static content (fish, regions, rods, baits, progression) loaded
## from JSON and validated by ContentValidator. Invalid entries are excluded and
## every problem is logged with push_error and kept in `errors` for diagnostics.

const DEFAULT_DATA_DIR := "res://data"

var fish: Dictionary = {}
var regions: Dictionary = {}
var rods: Dictionary = {}
var baits: Dictionary = {}
var progression: Dictionary = {}
var errors := PackedStringArray()

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
