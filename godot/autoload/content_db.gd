extends Node

var fish: Dictionary = {}
var regions: Dictionary = {}
var rods: Dictionary = {}
var baits: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	fish = _load_by_id("res://data/fish_catalog.json")
	regions = _load_by_id("res://data/regions.json")
	rods = _load_by_id("res://data/rods.json")
	baits = _load_by_id("res://data/baits.json")

func _load_by_id(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing content file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Expected JSON array: %s" % path)
		return {}
	var result: Dictionary = {}
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY or not item.has("id"):
			push_error("Invalid content item in %s" % path)
			continue
		var item_id: String = str(item["id"])
		if result.has(item_id):
			push_error("Duplicate id %s in %s" % [item_id, path])
			continue
		result[item_id] = item
	return result
