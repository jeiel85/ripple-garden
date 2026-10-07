class_name ArtLibrary
extends RefCounted

## Drawn art that replaces the placeholder shapes (D-029). Every painter asks here first and keeps
## drawing its shapes when the answer is null, so pictures can arrive one file at a time
## (assets/design/ASSET_REQUESTS.md) without breaking anything that has none yet.
##
## Files live at `res://art/<category>/<name>.png`:
##   world/<prefix>_scene.png, _scene_barren.png, _foreground.png   (prefix = the layout's "art")
##   character/angler_<pose>.png                                    (idle, cast, bite, reel, hold)
##   fish/<fish id>_top.png, <fish id>_side.png                     (head right / head left)
##   props/<prop kind>.png, <prop kind>_02.png, ...                 (variants are picked per position)
##   items/<item id>.png                                            (equipment screen: rods, baits, bags, accessories)
##
## How large a picture is drawn and which point of it sits on the anchor comes from `art.json`
## ({category: {"*": defaults, name: overrides}}), so tuning the placement is a data change.
## A PNG is only loadable after Godot imported it (open the editor once or run `--import`).

const DEFAULT_ROOT := "res://art"
## The tallest portrait screen a scene painting must fill (20:9 phones). The camera shows the design
## area centred and, with `stretch/aspect = expand`, more of the world above and below on taller screens.
const TALLEST_PORTRAIT := 20.0 / 9.0

## Tests point this at a fixture folder (`use_root`).
static var root := DEFAULT_ROOT
static var _textures := {}
static var _variants := {}
static var _meta: Dictionary = {}
static var _meta_loaded := false

## Switches the folder art is read from and forgets everything cached from the previous one.
static func use_root(path: String) -> void:
	root = path
	_textures.clear()
	_variants.clear()
	_meta = {}
	_meta_loaded = false

## The picture `<category>/<name>.png`, or null when it has not been drawn yet.
static func texture(category: String, name: String) -> Texture2D:
	var path := "%s/%s/%s.png" % [root, category, name]
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[path]

static func has(category: String, name: String) -> bool:
	return texture(category, name) != null

## One of the variants `name`, `name_02`, `name_03`, ... chosen by `pick` (stable for the same pick),
## or null when not even `name` exists.
static func variant(category: String, name: String, pick: int) -> Texture2D:
	var key := category + "/" + name
	if not _variants.has(key):
		var found: Array[Texture2D] = []
		var next := texture(category, name)
		while next != null:
			found.append(next)
			next = texture(category, "%s_%02d" % [name, found.size() + 1])
		_variants[key] = found
	var list: Array = _variants[key]
	return null if list.is_empty() else list[posmod(pick, list.size())]

## Placement data for a picture: the category's "*" defaults, then `base`'s entry (a prop kind, the
## angler), then the exact name's, later ones overriding earlier keys.
static func meta(category: String, name: String, base: String = "") -> Dictionary:
	if not _meta_loaded:
		_meta_loaded = true
		var path := root + "/art.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY:
				_meta = parsed
			else:
				push_error("ArtLibrary: %s is not a JSON object" % path)
	var entries: Dictionary = _meta.get(category, {})
	var result := {}
	for key in ["*", base, name]:
		if not key.is_empty() and typeof(entries.get(key)) == TYPE_DICTIONARY:
			result.merge(entries[key], true)
	return result

## A two-number list from the metadata as a Vector2 (fractions of the picture), or `fallback`.
static func point(data: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = data.get(key)
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

## Where a picture lands when drawn `width` wide with its `anchor` (fractions of the picture) at `at`.
static func placed_rect(tex: Texture2D, at: Vector2, width: float, anchor: Vector2) -> Rect2:
	var size := Vector2(width, width * tex.get_height() / maxf(1.0, tex.get_width()))
	return Rect2(at - anchor * size, size)

## Where a full-scene layer lies in the world: centred on the design area and tall enough to fill the
## tallest portrait screen, so no device sees past it. The placement is the same on every device (the
## region layout is aligned to the painting once); a 16:9 screen shows the middle of it.
static func scene_rect(tex: Texture2D, design: Vector2) -> Rect2:
	var height := maxf(design.y, design.x * TALLEST_PORTRAIT)
	var width := height * tex.get_width() / maxf(1.0, tex.get_height())
	return Rect2(design / 2.0 - Vector2(width, height) / 2.0, Vector2(width, height))

## The largest rect with the picture's proportions that fits in `box`, centred.
static func fit_rect(tex: Texture2D, box: Rect2) -> Rect2:
	var ratio := float(tex.get_width()) / maxf(1.0, tex.get_height())
	var size := Vector2(box.size.x, box.size.x / ratio)
	if size.y > box.size.y:
		size = Vector2(box.size.y * ratio, box.size.y)
	return Rect2(box.position + (box.size - size) / 2.0, size)
