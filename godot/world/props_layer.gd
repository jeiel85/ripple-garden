class_name PropsLayer
extends Node2D

## Scenery above the water (TECH_SPEC §2 "Props"): trees, rocks, reeds, lily pads, flowers, and the
## camp's decorations (P1-002). Which scenery exists depends on the restoration level (`min_level`/
## `max_level` in the layout): junk and stumps disappear, grass, reeds, lily pads, flowers and bushes
## appear. The camp comes from the save: each placed decoration is drawn at its slot, turned if the
## player turned it. Everything is drawn back to front by y. Props are static, so the layer only
## redraws when the level, the palette or the camp changes.

var layout: Dictionary = {}
var environment: RegionEnvironment = null
var reduced_motion := false
var region_id := ""

func setup(p_layout: Dictionary, p_environment: RegionEnvironment, p_region_id: String = "") -> void:
	layout = p_layout
	environment = p_environment
	region_id = p_region_id
	if not region_id.is_empty():
		EventBus.camp_changed.connect(func(changed: String) -> void:
			if changed == region_id:
				queue_redraw())
		EventBus.game_state_replaced.connect(queue_redraw)
	queue_redraw()

## Props present at `level`, in the layout's drawing order (back to front by y).
func visible_props(level: int) -> Array:
	var shown: Array = []
	for prop in layout["props"]:
		if level >= int(prop.get("min_level", 0)) and level <= int(prop.get("max_level", 999)):
			shown.append(prop)
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	return shown

## The camp's decorations as props: {"kind", "x", "y", "scale", "flip"} for each filled slot.
func camp_props() -> Array:
	var result: Array = []
	if region_id.is_empty():
		return result
	var camp: Dictionary = GameState.get_camp(region_id)
	for slot in CampService.slots(region_id):
		if not camp.has(slot["id"]):
			continue
		var decoration := ContentDB.get_decoration(camp[slot["id"]]["item"])
		if decoration.is_empty():
			continue
		var at: Vector2 = slot["position"]
		result.append({"kind": decoration["prop"], "x": at.x, "y": at.y, "scale": float(decoration["scale"]),
			"flip": camp[slot["id"]]["flip"] == true, "camp": true})
	return result

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
	var everything := visible_props(level) + camp_props()
	everything.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for prop in everything:
		var at := Vector2(float(prop["x"]), float(prop["y"]))
		var is_new: bool = not prop.has("camp") and not (from_level >= int(prop.get("min_level", 0)) and from_level <= int(prop.get("max_level", 999)))
		var fade := blend if is_new else 1.0
		var grow := 0.4 + 0.6 * fade
		var mirror := -1.0 if prop.get("flip", false) == true else 1.0
		if fade < 1.0 or mirror < 0.0:
			draw_set_transform(at, 0.0, Vector2(grow * mirror, grow))
			PropPainter.draw_prop(self, prop["kind"], Vector2.ZERO, float(prop.get("scale", 1.0)), level, palette)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			PropPainter.draw_prop(self, prop["kind"], at, float(prop.get("scale", 1.0)), level, palette)

func _process(_delta: float) -> void:
	# Only while a palette transition is running; a settled level costs nothing.
	if environment != null and environment.palette_blend < 1.0:
		queue_redraw()
