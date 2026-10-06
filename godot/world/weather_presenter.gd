class_name WeatherPresenter
extends Node2D

## Shows the current weather (P0-021, P1-006): drifting clouds, falling rain and rings on the pond, a low
## mist over the water, and now and then a soft lightning flash in a storm (never with Reduced Motion).
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
var _visual: Dictionary = {}
var _ripple_clock := 0.0
var _pond_bounds := Rect2()
var _flash := 0.0
var _next_flash := 6.0

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
	_visual = weather.visual()  # once per frame; _draw reuses it
	var visual := _visual
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
	var index := _ripples.size() - 1
	while index >= 0:  # age and drop in place: no new array every frame
		_ripples[index]["age"] += delta
		if _ripples[index]["age"] >= RIPPLE_LIFETIME:
			_ripples.remove_at(index)
		index -= 1
	var lightning: float = visual.get("lightning", 0.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	if lightning > 0.01 and not reduced_motion:
		_next_flash -= delta * lightning
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = rng.randf_range(4.0, 12.0)
	if cloud > 0.02 or not _ripples.is_empty() or float(visual.get("fog", 0.0)) > 0.01 or _flash > 0.0:
		queue_redraw()

## 0..1 brightness of the current lightning flash (for tests).
func flash_strength() -> float:
	return _flash

func _random_pond_point() -> Vector2:
	for attempt in 12:
		var point := Vector2(
			rng.randf_range(_pond_bounds.position.x, _pond_bounds.end.x),
			rng.randf_range(_pond_bounds.position.y, _pond_bounds.end.y))
		if Geometry2D.is_point_in_polygon(point, pond):
			return point
	return _pond_bounds.get_center()

func _draw() -> void:
	if weather == null or weather.current_id.is_empty() or _visual.is_empty():
		return
	var visual := _visual
	var cloud: float = visual["cloud"]
	var shade := Color.WHITE.lerp(Color("#9aa6b4"), clampf(float(visual["rain"]), 0.0, 1.0))
	for puff in _clouds:
		var base := Vector2(float(puff["x"]), float(puff["y"]))
		var size: float = float(puff["size"])
		var alpha := cloud * 0.62
		for part in [[-46.0, 6.0, 38.0], [0.0, -10.0, 50.0], [48.0, 4.0, 40.0], [92.0, 12.0, 30.0]]:
			draw_circle(base + Vector2(part[0], part[1]) * size, part[2] * size, Color(shade.r, shade.g, shade.b, alpha))
	var fog: float = visual.get("fog", 0.0)
	if fog > 0.01:
		# Soft bands of mist lying on the water, a little thicker towards the far bank.
		for band in 5:
			var y := _pond_bounds.position.y + _pond_bounds.size.y * (band + 0.5) / 5.0
			var drift := 0.0 if reduced_motion else sin(Time.get_ticks_msec() / 4000.0 + band) * 30.0
			var left := _pond_bounds.position.x - 200.0 + drift
			var right := _pond_bounds.end.x + 200.0 + drift
			var mist := Color(0.95, 0.97, 0.98, fog * (0.3 - band * 0.03))
			var clear := Color(mist, 0.0)
			# Each band fades out above and below, so the mist has no edges.
			for half in [[-70.0, 0.0, clear, mist], [0.0, 70.0, mist, clear]]:
				var top: float = y + half[0]
				var bottom: float = y + half[1]
				draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]),
					PackedColorArray([half[2], half[2], half[3], half[3]]))
	if _flash > 0.0:
		draw_rect(Rect2(-1000, -1000, 3000, 3600), Color(1, 1, 1, _flash * 0.35))
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
