class_name PropsLayer
extends Node2D

## Scenery above the water (TECH_SPEC §2 "Props"): trees, rocks, reeds, lily pads, flowers, and the
## camp's decorations (P1-002). Which scenery exists depends on the restoration level (`min_level`/
## `max_level` in the layout): junk and stumps disappear, grass, reeds, lily pads, flowers and bushes
## appear. The camp comes from the save: each placed decoration is drawn at its slot, turned if the
## player turned it. Everything is drawn back to front by y. Props are static, so the layer only
## redraws when the level, the palette or the camp changes — or when an animated prop (drawn art with
## pose frames, `<kind>_f2`, ...: a frog that blinks or croaks) takes up or leaves a pose, a few times a
## minute. Reduced Motion keeps every prop in its first pose.
##
## With a painted scene (ArtLibrary, D-029) the props that exist at every level and are of a kind the
## painting shows (trees, rocks, the dock: PropKinds.SCENE_PAINTED) are part of it and not drawn again.
## Everything else — restoration props, the camp, and permanent props the painting leaves out (a crate,
## bushes) — is drawn on top.

## Every few seconds (POSE_EVERY..2x, per prop) an animated prop holds one of its other poses this long.
const POSE_EVERY := 6.0
const POSE_SEC := 0.7

var layout: Dictionary = {}
var environment: RegionEnvironment = null
var reduced_motion := false
var _clock := 0.0
## Animated props drawn last time and the pose each was drawn in.
var _animated: Array = []
var _poses: Array = []
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

## True for scenery that is in the region at every restoration level.
static func is_permanent(prop: Dictionary) -> bool:
	return not prop.has("min_level") and not prop.has("max_level")

## True when a scene painting already shows this prop: there at every level and of a painted kind.
static func is_in_painting(prop: Dictionary) -> bool:
	return is_permanent(prop) and String(prop["kind"]) in PropKinds.SCENE_PAINTED

## Layout props drawn on top of the backdrop at `level`: all of them over the drawn-shape backdrop,
## all but the painted ones over a scene painting.
func drawn_props(level: int) -> Array:
	var shown := visible_props(level)
	if environment != null and environment.has_scene_art():
		shown = shown.filter(func(prop: Dictionary) -> bool: return not is_in_painting(prop))
	return shown

func refresh() -> void:
	queue_redraw()

## The pose an animated prop shows at `time`: 0 (its picture) most of the time, now and then one of
## its other frames for POSE_SEC, in turn. Always 0 for a still prop or under Reduced Motion.
func pose_at(prop: Dictionary, time: float) -> int:
	var count := ArtLibrary.frames("props", prop["kind"]).size()
	if count < 2 or reduced_motion:
		return 0
	var at := Vector2(float(prop["x"]), float(prop["y"]))
	var every := POSE_EVERY * (1.0 + PropPainter.noise(at, 21))
	var shifted := time + PropPainter.noise(at, 22) * every
	if fmod(shifted, every) >= POSE_SEC:
		return 0
	return 1 + int(shifted / every) % (count - 1)

func _draw() -> void:
	if environment == null:
		return
	var palette := environment.current_palette()
	var level := environment.level
	# While a restoration blends, show the props of the old level too, fading the old ones out.
	var from_level := environment.previous_level()
	var blend := environment.palette_blend
	var everything := drawn_props(level) + camp_props()
	everything.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	_animated.clear()
	_poses.clear()
	for prop in everything:
		var at := Vector2(float(prop["x"]), float(prop["y"]))
		var is_new: bool = not prop.has("camp") and not (from_level >= int(prop.get("min_level", 0)) and from_level <= int(prop.get("max_level", 999)))
		var fade := blend if is_new else 1.0
		var grow := 0.4 + 0.6 * fade
		var mirror := -1.0 if prop.get("flip", false) == true else 1.0
		var variant := int(PropPainter.noise(at, 11) * 1000.0)
		var pose := 0
		if ArtLibrary.frames("props", prop["kind"]).size() > 1:
			pose = pose_at(prop, _clock)
			_animated.append(prop)
			_poses.append(pose)
		if fade < 1.0 or mirror < 0.0:
			draw_set_transform(at, 0.0, Vector2(grow * mirror, grow))
			PropPainter.draw_prop(self, prop["kind"], Vector2.ZERO, float(prop.get("scale", 1.0)), level, palette, variant, pose)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			PropPainter.draw_prop(self, prop["kind"], at, float(prop.get("scale", 1.0)), level, palette, variant, pose)

func _process(delta: float) -> void:
	_clock += delta
	# Only while a palette transition is running or an animated prop changes pose; a settled level costs nothing.
	if environment != null and environment.palette_blend < 1.0:
		queue_redraw()
		return
	for i in _animated.size():
		if pose_at(_animated[i], _clock) != _poses[i]:
			queue_redraw()
			return
