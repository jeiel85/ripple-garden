class_name PropsLayer
extends Node2D

## Scenery above the water (TECH_SPEC §2 "Props"): trees, rocks, reeds, lily pads, flowers.
## Which props exist depends on the restoration level (`min_level`/`max_level` in the layout):
## junk and stumps disappear, grass, reeds, lily pads, flowers and bushes appear. Props are
## static, so the layer only redraws when the level or the palette changes.

var layout: Dictionary = {}
var environment: RegionEnvironment = null
var reduced_motion := false

func setup(p_layout: Dictionary, p_environment: RegionEnvironment) -> void:
	layout = p_layout
	environment = p_environment
	queue_redraw()

## Props present at `level`, in the layout's drawing order (back to front by y).
func visible_props(level: int) -> Array:
	var shown: Array = []
	for prop in layout["props"]:
		if level >= int(prop.get("min_level", 0)) and level <= int(prop.get("max_level", 999)):
			shown.append(prop)
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	return shown

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if environment == null:
		return
	var palette := environment.current_palette()
	var level := environment.level
	# While a restoration blends, show the props of the old level too, fading the old ones out.
	var from_level := environment.previous_level()
	var blend := environment.palette_blend
	for prop in visible_props(level):
		var at := Vector2(float(prop["x"]), float(prop["y"]))
		var is_new := not (from_level >= int(prop.get("min_level", 0)) and from_level <= int(prop.get("max_level", 999)))
		var fade := blend if is_new else 1.0
		if fade < 1.0:
			draw_set_transform(at, 0.0, Vector2.ONE * (0.4 + 0.6 * fade))
			PropPainter.draw_prop(self, prop["kind"], Vector2.ZERO, float(prop.get("scale", 1.0)), level, palette)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			PropPainter.draw_prop(self, prop["kind"], at, float(prop.get("scale", 1.0)), level, palette)

func _process(_delta: float) -> void:
	# Only while a palette transition is running; a settled level costs nothing.
	if environment != null and environment.palette_blend < 1.0:
		queue_redraw()
