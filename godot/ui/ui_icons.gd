class_name UiIcons
extends RefCounted

## The icon set (res://ui/icons, drawn by tools/generate_ui_icons.py). Icons are white silhouettes;
## controls tint them, so one picture serves cream buttons (dark brown) and dark pills (cream).
## Asking for a name that is not in NAMES is a programming error: it is reported and an empty
## texture comes back, so a typo never crashes a screen.

const DIR := "res://ui/icons/"
const NAMES: PackedStringArray = [
	"back", "bag", "bait", "bite", "calendar", "camera", "camp", "check", "clear", "clock", "close", "cloudy",
	"crown", "decorate", "eye_off", "fish", "forward", "freshwater", "furniture", "gear", "hat", "hook", "journal", "lake",
	"laurel", "layout", "lock", "lotus", "map", "memory", "mist", "mountain", "music", "night", "ornament", "pin",
	"rain", "record", "reel", "release", "ripple", "rod", "rotate", "ruler", "sea", "settings", "sort", "special",
	"sprout", "star", "storm", "trash", "valley", "weather",
]

static var _cache: Dictionary = {}

static func has_icon(icon_name: String) -> bool:
	return icon_name in NAMES

static func texture(icon_name: String) -> Texture2D:
	if _cache.has(icon_name):
		return _cache[icon_name]
	if not has_icon(icon_name):
		push_error("UiIcons: unknown icon '%s'" % icon_name)
		return PlaceholderTexture2D.new()
	var loaded: Texture2D = load(DIR + icon_name + ".svg")
	_cache[icon_name] = loaded
	return loaded

## Icon for a weather id; unknown weather gets the generic sun-and-cloud picture.
static func for_weather(weather_id: String) -> String:
	return weather_id if weather_id in ["clear", "cloudy", "rain", "mist", "storm"] else "weather"

## A theme picture (toggle switch, drop-down arrow) by file name without extension.
static func theme_texture(file_name: String) -> Texture2D:
	return load(DIR + file_name + ".svg")
