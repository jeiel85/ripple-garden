class_name HabitatMap
extends RefCounted

## Answers "what habitat is at this point?" for a region (cast landing, fish placement). Built
## from the region's HabitatZone nodes plus its pond outline. Zones later in the list win over
## earlier ones where they overlap.

var pond := PackedVector2Array()
var _zones: Array[HabitatZone] = []

func _init(pond_polygon: PackedVector2Array, zones: Array[HabitatZone]) -> void:
	pond = pond_polygon
	_zones = zones

## Habitat tag at `point`, or "" when the point is not on a habitat (land, outside the pond). Zones may
## poke slightly past the pond outline, so a point must be on the water as well as inside a zone.
func habitat_at(point: Vector2) -> String:
	if not is_water(point):
		return ""
	for i in range(_zones.size() - 1, -1, -1):
		if _zones[i].contains_point(point):
			return _zones[i].habitat_tag
	return ""

func is_water(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, pond)

## A random point whose habitat is one of `habitats`, picked in proportion to zone areas. Falls
## back to the first matching zone's first vertex pulled towards its centre when sampling keeps
## landing under an overlay (cannot happen with sane layouts; it keeps callers crash-free).
func random_point(habitats: Array, rng: RandomNumberGenerator) -> Vector2:
	var candidates: Array[HabitatZone] = []
	var total_area := 0.0
	for zone in _zones:
		if zone.habitat_tag in habitats:
			candidates.append(zone)
			total_area += zone.area()
	if candidates.is_empty():
		return pond_center()
	for attempt in 40:
		var pick := rng.randf() * total_area
		var chosen := candidates[0]
		for zone in candidates:
			pick -= zone.area()
			if pick <= 0.0:
				chosen = zone
				break
		var bounds := _bounds(chosen.polygon)
		var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if habitat_at(point) in habitats:  # on the water and in a zone of this habitat
			return point
	return candidates[0].polygon[0].lerp(_bounds(candidates[0].polygon).get_center(), 0.5)

func pond_center() -> Vector2:
	return _bounds(pond).get_center()

## Share (0..1) of the pond's bounding box grid that resolves to `habitat`, for tests and tools.
func coverage(habitat: String, step: float = 8.0) -> float:
	var bounds := _bounds(pond)
	var inside := 0
	var matching := 0
	var y := bounds.position.y
	while y < bounds.end.y:
		var x := bounds.position.x
		while x < bounds.end.x:
			var point := Vector2(x, y)
			if is_water(point):
				inside += 1
				if habitat_at(point) == habitat:
					matching += 1
			x += step
		y += step
	return 0.0 if inside == 0 else float(matching) / inside

static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		rect = rect.expand(point)
	return rect

## Builds the map and its zone nodes for a layout (data/region_layouts.json entry). The caller
## adds the returned nodes to the scene so they exist as components of the region.
static func from_layout(layout: Dictionary, zone_nodes: Array[HabitatZone]) -> HabitatMap:
	for zone in layout["zones"]:
		zone_nodes.append(HabitatZone.from_layout(zone))
	return HabitatMap.new(HabitatZone.to_polygon(layout["pond"]), zone_nodes)
