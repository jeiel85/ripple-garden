class_name RegionEnvironment
extends Node2D

## Backdrop of the region (TECH_SPEC §2 "Environment"): sky with sun/moon/stars, hills, ground,
## the pond and its bank, and the lighting for the whole world. Everything is drawn from the
## region layout (data/region_layouts.json) and the current restoration level; nothing here
## keeps state that is not derived from those and the game clock.
##
## Lighting: a CanvasModulate dims/tints the world by time of day and weather. The sky is drawn
## pre-divided by the time-of-day light so it keeps its own look under that modulate.
##
## Restoration changes are blended: `set_level(level, true)` eases water, grass and canopy colors
## from the previous palette to the new one while PropsLayer fades the new props in.

const SKY_TOP := -3000.0
const GROUND_BOTTOM := 3600.0
const WORLD_LEFT := -2600.0
const WORLD_RIGHT := 3300.0
const BANK_WIDTH := 26.0
const STAR_COUNT := 70
const LIGHT_STEP_SEC := 0.2

var region_id := ""
var layout: Dictionary = {}
var level := 0
## 0..1 progress from the previous palette to the current one.
var palette_blend := 1.0

var weather: WeatherService = null
var hours_provider := Callable()

## Level shown at the start of the current transition (fractional if one was interrupted).
var _from_level := 0.0
var _from_palette: Dictionary = {}
var _to_palette: Dictionary = {}
var _sky: Node2D
var _ground: Node2D
var _water: Polygon2D
var _waterfall: WaterfallView = null
var _modulate: CanvasModulate
var _pond: PackedVector2Array
var _bank: PackedVector2Array
var _light_timer := 0.0
var _tween: Tween
var _time_light := Color.WHITE

func setup(p_region_id: String, p_layout: Dictionary, p_weather: WeatherService, p_level: int) -> void:
	region_id = p_region_id
	layout = p_layout
	weather = p_weather
	level = p_level
	# The layout's pond is a coarse outline (it also drives habitats); the drawn shore is smoothed.
	_pond = smooth(HabitatZone.to_polygon(layout["pond"]), 3)
	var offset := Geometry2D.offset_polygon(_pond, BANK_WIDTH)
	_bank = smooth(offset[0], 1) if not offset.is_empty() else _pond
	_to_palette = palette_for(level)
	_from_palette = _to_palette
	_from_level = float(level)
	palette_blend = 1.0

	_sky = Node2D.new()
	_sky.name = "Sky"
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_water = Polygon2D.new()
	_water.name = "Water"
	_water.polygon = _pond
	var material := ShaderMaterial.new()
	material.shader = load("res://world/water.gdshader")
	material.set_shader_parameter("pond_top", _bounds_y(true))
	material.set_shader_parameter("pond_bottom", _bounds_y(false))
	_water.material = material
	add_child(_water)
	var fall: Variant = layout.get("waterfall")
	if typeof(fall) == TYPE_DICTIONARY:
		_waterfall = WaterfallView.new()
		_waterfall.name = "Waterfall"
		_waterfall.setup(Rect2(float(fall["x"]), float(fall["y"]), float(fall["width"]), float(fall["height"])))
		add_child(_waterfall)
	_modulate = CanvasModulate.new()
	_modulate.name = "Lighting"
	add_child(_modulate)
	_apply_palette()
	_update_lighting()

func _process(delta: float) -> void:
	_light_timer += delta
	if _light_timer >= LIGHT_STEP_SEC:
		_light_timer = 0.0
		_update_lighting()

# --- palette (restoration level) ---

func palette_for(for_level: int) -> Dictionary:
	var levels: Array = layout["levels"]
	var entry: Dictionary = levels[clampi(for_level, 0, levels.size() - 1)]
	var palette := {}
	for key in entry:
		palette[key] = Color(entry[key])
	return palette

## The palette currently on screen (blended while a transition runs).
func current_palette() -> Dictionary:
	var blended := {}
	for key in _to_palette:
		blended[key] = (_from_palette[key] as Color).lerp(_to_palette[key], palette_blend)
	return blended

## Switches to a restoration level. With `animate`, colors ease over `duration` seconds.
func set_level(new_level: int, animate: bool, duration: float = 3.0) -> void:
	if new_level == level and palette_blend >= 1.0:
		return
	_from_palette = current_palette()
	_from_level = displayed_level()
	_to_palette = palette_for(new_level)
	level = new_level
	if _tween != null:
		_tween.kill()
	if animate and duration > 0.0:
		palette_blend = 0.0
		_tween = create_tween()
		_tween.tween_method(_set_blend, 0.0, 1.0, duration)
	else:
		_set_blend(1.0)

func _set_blend(value: float) -> void:
	palette_blend = value
	_apply_palette()

func _apply_palette() -> void:
	var palette := current_palette()
	var material := _water.material as ShaderMaterial
	material.set_shader_parameter("deep_color", palette["water_deep"])
	material.set_shader_parameter("shallow_color", palette["water_shallow"])
	material.set_shader_parameter("shimmer", clampf(0.25 + 0.75 * _level_progress(), 0.0, 1.0))
	if _waterfall != null:
		_waterfall.flow = _level_progress()
		_waterfall.queue_redraw()
	_ground.queue_redraw()

## Reduced Motion stops the water's drift; the surface stays a still picture.
func set_reduced_motion(on: bool) -> void:
	(_water.material as ShaderMaterial).set_shader_parameter("motion", 0.0 if on else 1.0)
	if _waterfall != null:
		_waterfall.set_reduced_motion(on)

## The level the current transition started from (equals `level` once settled).
func previous_level() -> int:
	return int(roundf(_from_level))

## The level on screen, fractional while a transition is blending.
func displayed_level() -> float:
	return lerpf(_from_level, float(level), palette_blend)

## 0 at the barest level, 1 at the best the slice offers (fractional while blending).
func _level_progress() -> float:
	var top := float(maxi(1, layout["levels"].size() - 1))
	return clampf(displayed_level() / top, 0.0, 1.0)

# --- lighting ---

func _hours() -> float:
	return float(hours_provider.call()) if hours_provider.is_valid() else TimeService.get_hours()

func _update_lighting() -> void:
	var style := EnvironmentStyle.sample(_hours())
	_time_light = style["light"]
	var weather_light := Color.WHITE
	if weather != null:
		var visual := weather.visual()
		weather_light = (visual["tint"] as Color) * float(visual["brightness"])
		weather_light.a = 1.0
	_modulate.color = _time_light * weather_light
	_sky.queue_redraw()

## Re-reads the clock and weather at once (water-mind previews change them between light steps).
func refresh_lighting() -> void:
	_light_timer = 0.0
	_update_lighting()

## The color the world is multiplied by right now (for tests and other presenters).
func current_light() -> Color:
	return _modulate.color

# --- drawing ---

func _draw_sky() -> void:
	var hours := _hours()
	var style := EnvironmentStyle.sample(hours)
	var light: Color = style["light"]
	var top := EnvironmentStyle.compensate(style["top"], light)
	var bottom := EnvironmentStyle.compensate(style["bottom"], light)
	var horizon: float = layout["horizon_y"]
	_sky.draw_rect(Rect2(WORLD_LEFT, SKY_TOP, WORLD_RIGHT - WORLD_LEFT, horizon + 80.0 - SKY_TOP), top)
	var band_top := horizon - 520.0
	_sky.draw_polygon(
		PackedVector2Array([Vector2(WORLD_LEFT, band_top), Vector2(WORLD_RIGHT, band_top), Vector2(WORLD_RIGHT, horizon + 80.0), Vector2(WORLD_LEFT, horizon + 80.0)]),
		PackedColorArray([top, top, bottom, bottom]))

	var star_alpha: float = style["stars"]
	if star_alpha > 0.01:
		for i in STAR_COUNT:
			var x := PropPainter.noise(Vector2(i, 1), 1) * 1100.0 - 190.0
			var y := PropPainter.noise(Vector2(i, 2), 2) * (horizon - 40.0)
			_sky.draw_circle(Vector2(x, y), 1.2 + PropPainter.noise(Vector2(i, 3), 3) * 1.4,
				EnvironmentStyle.compensate(Color(1, 1, 0.92, star_alpha * 0.9), light))

	var sun := EnvironmentStyle.sun_progress(hours)
	if sun >= 0.0:
		_draw_orb(_arc_position(sun, horizon), 38.0, Color("#fff3c4"), light)
	var moon := EnvironmentStyle.moon_progress(hours)
	if moon >= 0.0:
		_draw_orb(_arc_position(moon, horizon), 30.0, Color("#eef2ff"), light)

func _arc_position(progress: float, horizon: float) -> Vector2:
	return Vector2(lerpf(90.0, 630.0, progress), horizon - 40.0 - sin(progress * PI) * 300.0)

func _draw_orb(center: Vector2, radius: float, color: Color, light: Color) -> void:
	for i in 4:
		var halo := EnvironmentStyle.compensate(Color(color.r, color.g, color.b, 0.07), light)
		_sky.draw_circle(center, radius * (2.8 - i * 0.55), halo)
	_sky.draw_circle(center, radius, EnvironmentStyle.compensate(color, light))

func _draw_ground() -> void:
	var palette := current_palette()
	var grass: Color = palette["grass"]
	var horizon: float = layout["horizon_y"]
	var haze := EnvironmentStyle.compensate(EnvironmentStyle.sample(_hours())["bottom"], _time_light)

	# Distant hills fade towards the haze colour.
	for layer in 2:
		var points := PackedVector2Array()
		var base := horizon - 10.0 - layer * 26.0
		var x := WORLD_LEFT
		while x <= WORLD_RIGHT:
			points.append(Vector2(x, base - 34.0 - 26.0 * sin(x * 0.011 + layer * 1.7) - 14.0 * sin(x * 0.027 + layer)))
			x += 40.0
		points.append(Vector2(WORLD_RIGHT, horizon + 60.0))
		points.append(Vector2(WORLD_LEFT, horizon + 60.0))
		_ground.draw_colored_polygon(points, grass.lerp(haze, 0.62 - layer * 0.2).darkened(0.1 * layer))

	# The meadow, lighter at the horizon and deeper towards the viewer.
	var far_tone := grass.lerp(haze, 0.25)
	var near_tone := grass.darkened(0.18)
	_ground.draw_polygon(
		PackedVector2Array([Vector2(WORLD_LEFT, horizon), Vector2(WORLD_RIGHT, horizon), Vector2(WORLD_RIGHT, GROUND_BOTTOM), Vector2(WORLD_LEFT, GROUND_BOTTOM)]),
		PackedColorArray([far_tone, far_tone, near_tone, near_tone]))

	# Bank around the water, then a darker rim where grass meets water.
	var bank_color := grass.lerp(Color("#8a6f4d"), 0.55 - 0.45 * _level_progress())
	_ground.draw_colored_polygon(_bank, bank_color)
	_ground.draw_polyline(_bank + PackedVector2Array([_bank[0]]), bank_color.darkened(0.25), 3.0)

## Chaikin corner cutting: each pass replaces every corner by two points a quarter of the way along
## the adjoining edges, which rounds an outline without moving it far.
static func smooth(points: PackedVector2Array, passes: int) -> PackedVector2Array:
	var result := points
	for pass_index in passes:
		var next := PackedVector2Array()
		for i in result.size():
			var a := result[i]
			var b := result[(i + 1) % result.size()]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		result = next
	return result

func _bounds_y(top: bool) -> float:
	var extreme: float = _pond[0].y
	for point in _pond:
		extreme = minf(extreme, point.y) if top else maxf(extreme, point.y)
	return extreme
