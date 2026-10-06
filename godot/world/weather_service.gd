class_name WeatherService
extends Node

## Data-driven weather (TECH_SPEC §11, weather.json). One weather at a time for the region:
## it stays for a random duration, then moves to a neighbour chosen by weight, easing over the
## definition's `transition_sec`. Each weather stays at least twice as long as its transition
## (ContentValidator), so conditions never flicker. Weather is an experience, not a debuff
## (GDD §13): the fish tables just have different multipliers.
##
## Time only advances through `advance(delta)`; randomness only through `rng` (seedable).

## Eased progress 0..1 of the current transition (1 = settled).
var blend := 1.0
var current_id := ""
var previous_id := ""
var region_id := ""
var rng := RandomNumberGenerator.new()
## Weather definitions; defaults to ContentDB.weather. Tests may inject their own.
var definitions: Dictionary = {}

var _time_left := 0.0
var _transition_left := 0.0
var _transition_total := 0.0

func _ready() -> void:
	rng.randomize()

func _process(delta: float) -> void:
	advance(delta)

func _definitions() -> Dictionary:
	return definitions if not definitions.is_empty() else ContentDB.weather

## Weather the region can have: its own list restricted to what is defined.
func allowed_ids() -> Array:
	var allowed: Array = []
	for weather_id in ContentDB.get_region(region_id).get("weather", []):
		if _definitions().has(weather_id):
			allowed.append(weather_id)
	return allowed

## Starts the cycle for a region. Begins with "clear" when the region has it.
func start(p_region_id: String) -> void:
	region_id = p_region_id
	var allowed := allowed_ids()
	if allowed.is_empty():
		push_error("WeatherService: region %s has no defined weather" % region_id)
		return
	var first: String = "clear" if "clear" in allowed else allowed[0]
	current_id = first
	previous_id = first
	blend = 1.0
	_transition_left = 0.0
	_time_left = _roll_duration(first)
	EventBus.weather_changed.emit(first)

func advance(delta: float) -> void:
	if current_id.is_empty() or delta <= 0.0:
		return
	if _transition_left > 0.0:
		_transition_left = maxf(0.0, _transition_left - delta)
		blend = 1.0 if _transition_left <= 0.0 else 1.0 - _transition_left / _transition_total
	_time_left -= delta
	if _time_left <= 0.0:
		var next_id := _pick_next()
		if next_id.is_empty():
			_time_left = _roll_duration(current_id)
		else:
			_begin(next_id)

## Switches to `weather_id` right away (debug menu). Returns false for unknown or disallowed ids.
func set_weather(weather_id: String) -> bool:
	if not weather_id in allowed_ids():
		return false
	if weather_id != current_id:
		_begin(weather_id)
	else:
		_time_left = _roll_duration(weather_id)
	return true

func _begin(weather_id: String) -> void:
	previous_id = current_id
	current_id = weather_id
	_transition_total = float(_definitions()[weather_id]["transition_sec"])
	_transition_left = _transition_total
	blend = 0.0 if _transition_total > 0.0 else 1.0
	_time_left = _roll_duration(weather_id)
	EventBus.weather_changed.emit(weather_id)

func _roll_duration(weather_id: String) -> float:
	var range_def: Dictionary = _definitions()[weather_id]["duration_sec"]
	return rng.randf_range(float(range_def["min"]), float(range_def["max"]))

func _pick_next() -> String:
	var allowed := allowed_ids()
	var weights := {}
	var total := 0.0
	for weather_id in _definitions()[current_id]["next"]:
		if weather_id in allowed:
			weights[weather_id] = float(_definitions()[current_id]["next"][weather_id])
			total += weights[weather_id]
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	var cursor := 0.0
	var ids: Array = weights.keys()
	ids.sort()
	for weather_id in ids:
		cursor += weights[weather_id]
		if roll < cursor:
			return weather_id
	return ids.back()

## Visual parameters blended between the previous and current weather:
## {"cloud": 0..1, "rain": 0..1, "brightness": float, "tint": Color}.
func visual() -> Dictionary:
	if current_id.is_empty():
		return {"cloud": 0.0, "rain": 0.0, "brightness": 1.0, "tint": Color.WHITE}
	var from: Dictionary = _definitions()[previous_id]["visual"]
	var to: Dictionary = _definitions()[current_id]["visual"]
	var t := smoothstep(0.0, 1.0, blend)
	return {
		"cloud": lerpf(float(from["cloud"]), float(to["cloud"]), t),
		"rain": lerpf(float(from["rain"]), float(to["rain"]), t),
		"brightness": lerpf(float(from["brightness"]), float(to["brightness"]), t),
		"tint": Color(from["tint"]).lerp(Color(to["tint"]), t),
	}
