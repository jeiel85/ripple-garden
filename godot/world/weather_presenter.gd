class_name WeatherPresenter
extends Node2D

## Shows the current weather (P0-021): drifting clouds, falling rain and rings on the pond.
## It reads WeatherService.visual() every frame, so conditions ease in and out with the
## service's transition instead of switching. Rain is one CPUParticles2D (GL Compatibility
## friendly) whose count follows graphics quality and Battery Saver; with Reduced Motion the
## clouds hold still.

const RAIN_AMOUNT := {"low": 90, "medium": 180, "high": 320}
const MAX_RIPPLES := 14
const RIPPLE_LIFETIME := 1.2
const CLOUD_Y_MIN := 20.0
const CLOUD_Y_MAX := 300.0

var weather: WeatherService = null
var pond: PackedVector2Array = PackedVector2Array()
var reduced_motion := false
var quality := "medium"
var battery_saver := false
var rng := RandomNumberGenerator.new()

var _rain: CPUParticles2D
var _clouds: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _ripple_clock := 0.0
var _pond_bounds := Rect2()

func setup(p_weather: WeatherService, pond_polygon: PackedVector2Array) -> void:
	weather = p_weather
	pond = pond_polygon
	rng.randomize()
	_pond_bounds = Rect2(pond[0], Vector2.ZERO)
	for point in pond:
		_pond_bounds = _pond_bounds.expand(point)
	for i in 7:
		_clouds.append({
			"x": rng.randf_range(-300.0, 1020.0),
			"y": rng.randf_range(CLOUD_Y_MIN, CLOUD_Y_MAX),
			"size": rng.randf_range(0.8, 1.6),
			"speed": rng.randf_range(4.0, 11.0),
		})
	_rain = CPUParticles2D.new()
	_rain.name = "Rain"
	_rain.position = Vector2(360, -260)
	_rain.emitting = false
	_rain.local_coords = false
	_rain.lifetime = 1.5
	_rain.preprocess = 1.5
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(1100, 4)
	_rain.direction = Vector2(-0.18, 1.0)
	_rain.spread = 1.5
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 1050.0
	_rain.initial_velocity_max = 1250.0
	_rain.color = Color(0.82, 0.9, 1.0, 0.55)
	_rain.texture = _streak_texture()
	add_child(_rain)
	apply_quality(quality, battery_saver)

func apply_quality(new_quality: String, new_battery_saver: bool) -> void:
	quality = new_quality
	battery_saver = new_battery_saver
	var amount: int = RAIN_AMOUNT.get(quality, RAIN_AMOUNT["medium"])
	_rain.amount = maxi(20, roundi(amount * (0.5 if battery_saver else 1.0)))

func _process(delta: float) -> void:
	if weather == null or weather.current_id.is_empty():
		return
	var visual := weather.visual()
	var rain: float = visual["rain"]
	_rain.emitting = rain > 0.02
	_rain.modulate.a = clampf(rain, 0.0, 1.0)

	var cloud: float = visual["cloud"]
	if not reduced_motion:
		for puff in _clouds:
			puff["x"] = fposmod(float(puff["x"]) + float(puff["speed"]) * delta + 300.0, 1320.0) - 300.0

	if rain > 0.05:
		_ripple_clock += delta
		var interval := lerpf(0.5, 0.08, rain)
		if _ripple_clock >= interval and _ripples.size() < MAX_RIPPLES:
			_ripple_clock = 0.0
			_ripples.append({"pos": _random_pond_point(), "age": 0.0})
	for ripple in _ripples:
		ripple["age"] += delta
	_ripples = _ripples.filter(func(r: Dictionary) -> bool: return r["age"] < RIPPLE_LIFETIME)
	if cloud > 0.02 or not _ripples.is_empty():
		queue_redraw()

func _random_pond_point() -> Vector2:
	for attempt in 12:
		var point := Vector2(
			rng.randf_range(_pond_bounds.position.x, _pond_bounds.end.x),
			rng.randf_range(_pond_bounds.position.y, _pond_bounds.end.y))
		if Geometry2D.is_point_in_polygon(point, pond):
			return point
	return _pond_bounds.get_center()

func _draw() -> void:
	if weather == null or weather.current_id.is_empty():
		return
	var visual := weather.visual()
	var cloud: float = visual["cloud"]
	var shade := Color.WHITE.lerp(Color("#9aa6b4"), clampf(float(visual["rain"]), 0.0, 1.0))
	for puff in _clouds:
		var base := Vector2(float(puff["x"]), float(puff["y"]))
		var size: float = float(puff["size"])
		var alpha := cloud * 0.62
		for part in [[-46.0, 6.0, 38.0], [0.0, -10.0, 50.0], [48.0, 4.0, 40.0], [92.0, 12.0, 30.0]]:
			draw_circle(base + Vector2(part[0], part[1]) * size, part[2] * size, Color(shade.r, shade.g, shade.b, alpha))
	for ripple in _ripples:
		var life: float = ripple["age"] / RIPPLE_LIFETIME
		var radius := 4.0 + life * 20.0
		var points := PackedVector2Array()
		for i in 15:
			var angle := TAU * i / 14.0
			points.append(ripple["pos"] + Vector2(cos(angle) * radius, sin(angle) * radius * 0.45))
		draw_polyline(points, Color(1, 1, 1, (1.0 - life) * 0.55), 1.5, true)

static func _streak_texture() -> Texture2D:
	var image := Image.create(2, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		var alpha := float(y) / 21.0
		for x in 2:
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)
