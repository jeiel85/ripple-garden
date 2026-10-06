class_name AmbientAnimalPresenter
extends Node2D

## Small wildlife that appears as the pond recovers (GDD §6 ambient animals, §19 "first
## environmental animal"): dragonflies, butterflies and fireflies defined in the layout with a
## `min_level` and the time bands they are out. They are decoration with a purpose (a visible
## reward for restoration) and are never a source of currency (CONTENT_PLAN §1).
##
## Motion is a closed-form wander (sines around a home point), so there is no per-animal state to
## update or save, and the total is capped by the layout (a few dozen at most) and trimmed by the
## graphics profile's wildlife share (low quality, Battery Saver). With Reduced Motion the animals
## still appear but drift much more slowly.

var layout: Dictionary = {}
var level := 0
var time_band := "day"
var reduced_motion := false
## Share of the layout's animals that are drawn (GraphicsProfile "wildlife").
var wildlife := 1.0

var _motes: Array[Dictionary] = []
var _clock := 0.0

func setup(p_layout: Dictionary, p_level: int, p_time_band: String) -> void:
	layout = p_layout
	level = p_level
	time_band = p_time_band
	EventBus.game_time_band_changed.connect(func(band: String) -> void: set_time_band(band))
	_rebuild()

func set_level(new_level: int) -> void:
	level = new_level
	_rebuild()

func set_time_band(band: String) -> void:
	time_band = band
	_rebuild()

func set_wildlife(share: float) -> void:
	if is_equal_approx(share, wildlife):
		return
	wildlife = share
	_rebuild()

## Animals out right now: {kind: count}. The wildlife share applies to each kind's total, not to every
## layout entry (two entries of three butterflies at 0.5 are three butterflies, not 2 + 2).
func current_counts() -> Dictionary:
	var counts := {}
	for animal in layout.get("ambient_animals", []):
		if level >= int(animal["min_level"]) and time_band in animal["time_bands"]:
			counts[animal["kind"]] = int(counts.get(animal["kind"], 0)) + int(animal["count"])
	for kind in counts:
		counts[kind] = GraphicsProfile.scaled_count(counts[kind], wildlife)
	return counts

func animal_count() -> int:
	return _motes.size()

func _rebuild() -> void:
	_motes.clear()
	var pond := HabitatZone.to_polygon(layout.get("pond", []))
	if pond.size() < 3:
		return
	var bounds := Rect2(pond[0], Vector2.ZERO)
	for point in pond:
		bounds = bounds.expand(point)
	bounds = bounds.grow(60.0)
	var counts := current_counts()
	for kind in counts:
		for i in int(counts[kind]):
			var seed_point := Vector2(i * 37.0 + kind.length() * 11.0, 5.0 + i)
			_motes.append({
				"kind": kind,
				"home": Vector2(
					bounds.position.x + PropPainter.noise(seed_point, 1) * bounds.size.x,
					bounds.position.y + 40.0 + PropPainter.noise(seed_point, 2) * (bounds.size.y - 80.0)),
				"radius": Vector2(40.0 + PropPainter.noise(seed_point, 3) * 70.0, 20.0 + PropPainter.noise(seed_point, 4) * 40.0),
				"speed": 0.5 + PropPainter.noise(seed_point, 5) * 0.9,
				"phase": PropPainter.noise(seed_point, 6) * TAU,
			})
	set_process(not _motes.is_empty())
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta * (0.25 if reduced_motion else 1.0)
	queue_redraw()

func _position_of(mote: Dictionary) -> Vector2:
	var t: float = _clock * float(mote["speed"]) + float(mote["phase"])
	var radius: Vector2 = mote["radius"]
	return mote["home"] + Vector2(cos(t) * radius.x, sin(t * 1.3) * radius.y)

func _draw() -> void:
	for mote in _motes:
		var at := _position_of(mote)
		match mote["kind"]:
			"dragonfly":
				var flutter := absf(sin(_clock * 28.0 + float(mote["phase"])))
				draw_line(at + Vector2(-9, 0), at + Vector2(9, 0), Color("#3d7fc2"), 2.5)
				draw_circle(at + Vector2(9, 0), 2.5, Color("#2d5f94"))
				draw_colored_polygon(_wing(at + Vector2(1, -1), 8.0, 3.0 + flutter * 2.0, -1.0), Color(0.9, 0.97, 1.0, 0.7))
				draw_colored_polygon(_wing(at + Vector2(1, 1), 8.0, 3.0 + flutter * 2.0, 1.0), Color(0.9, 0.97, 1.0, 0.7))
			"butterfly":
				var flap := 0.35 + absf(sin(_clock * 9.0 + float(mote["phase"]))) * 0.65
				var tint := Color("#f0a0c0") if int(mote["phase"] * 10.0) % 2 == 0 else Color("#f2d36b")
				draw_colored_polygon(_wing(at, 10.0 * flap, 8.0, -1.0), tint)
				draw_colored_polygon(_wing(at, 10.0 * flap, 8.0, 1.0), tint)
				draw_line(at + Vector2(0, -5), at + Vector2(0, 5), Color("#4a3b36"), 2.0)
			"bird":
				# A little bluebird gliding over the pond, wings beating now and then.
				var beat := sin(_clock * 12.0 + float(mote["phase"])) * (0.6 if sin(_clock * 0.7 + float(mote["phase"])) > 0.0 else 0.15)
				draw_colored_polygon(_wing(at, 9.0, 5.0, 1.0), Color("#4f86c6"))
				draw_line(at, at + Vector2(-10, -6.0 - beat * 8.0), Color("#3f6fa8"), 3.0)
				draw_line(at, at + Vector2(10, -6.0 - beat * 8.0), Color("#3f6fa8"), 3.0)
				draw_circle(at + Vector2(6, 1), 3.0, Color("#f2efe6"))
			"firefly":
				var glow := 0.45 + 0.55 * (sin(_clock * 2.2 + float(mote["phase"]) * 3.0) * 0.5 + 0.5)
				draw_circle(at, 9.0, Color(1.0, 0.95, 0.45, 0.10 * glow))
				draw_circle(at, 5.0, Color(1.0, 0.95, 0.45, 0.30 * glow))
				draw_circle(at, 2.0, Color(1.0, 1.0, 0.8, glow))

static func _wing(at: Vector2, width: float, height: float, side: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var angle := TAU * i / 8.0
		points.append(at + Vector2(cos(angle) * width * 0.5, side * (height * 0.5 + sin(angle) * height * 0.5)))
	return points
