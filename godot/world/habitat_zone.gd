class_name HabitatZone
extends Node2D

## One habitat area of a region: a polygon tagged with a habitat id (GDD §8, TECH_SPEC §2
## "HabitatZones"). Zones overlap on purpose: a later (higher in the list) zone is drawn over
## an earlier one, so a big base zone plus small overlays describes a pond without gaps.
## Where the line lands decides which fish can bite; the tag must be one of the region's
## habitats (ContentValidator checks the layout data).

@export var habitat_tag := ""
@export var polygon := PackedVector2Array()
## Tint used by the debug overlay only; zones draw nothing in a normal run.
@export var debug_color := Color(1, 1, 1, 0.25)

var debug_draw := false:
	set(value):
		debug_draw = value
		queue_redraw()

static func from_layout(zone: Dictionary) -> HabitatZone:
	var node := HabitatZone.new()
	node.habitat_tag = zone["habitat"]
	node.polygon = to_polygon(zone["polygon"])
	node.name = "Zone_%s" % node.habitat_tag
	return node

## Converts layout JSON points ([[x, y], ...]) to a polygon.
static func to_polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(float(point[0]), float(point[1])))
	return result

## Whether a point in the parent's coordinate space lies inside the zone.
func contains_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(point), polygon)

## Polygon area in square pixels (shoelace); used to pick zones in proportion to their size.
func area() -> float:
	var total := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) / 2.0

func _draw() -> void:
	if debug_draw and polygon.size() >= 3:
		draw_colored_polygon(polygon, debug_color)
		draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color(1, 1, 1, 0.8), 2.0)
