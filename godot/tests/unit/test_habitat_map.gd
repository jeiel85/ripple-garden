extends TestCase

## P0-009: habitat zones and the map that resolves a cast landing to a habitat.

const REGION := "region_01_quiet_pond"

var _zone_nodes: Array[HabitatZone] = []

func _map() -> HabitatMap:
	_zone_nodes = []
	return HabitatMap.from_layout(ContentDB.get_layout(REGION), _zone_nodes)

func _free_zones() -> void:
	for zone in _zone_nodes:
		zone.free()
	_zone_nodes.clear()

func test_layout_exists_and_every_zone_uses_a_region_habitat() -> void:
	var layout := ContentDB.get_layout(REGION)
	assert_false(layout.is_empty(), "region 01 has no layout")
	var habitats: Array = ContentDB.get_region(REGION)["habitats"]
	for zone in layout["zones"]:
		assert_true(zone["habitat"] in habitats, "%s is not a habitat of %s" % [zone["habitat"], REGION])

func test_every_habitat_can_actually_be_fished() -> void:
	var map := _map()
	for habitat in ContentDB.get_region(REGION)["habitats"]:
		assert_true(map.coverage(habitat) > 0.04, "%s covers only %.1f%% of the pond" % [habitat, map.coverage(habitat) * 100.0])
	_free_zones()

func test_every_species_of_the_region_has_a_place_to_live() -> void:
	var map := _map()
	for fish_def in ContentDB.get_fish_for_region(REGION):
		var reachable := false
		for habitat in fish_def["habitats"]:
			reachable = reachable or map.coverage(habitat) > 0.0
		assert_true(reachable, "%s lives where no zone exists" % fish_def["id"])
	_free_zones()

func test_land_resolves_to_no_habitat() -> void:
	var map := _map()
	var layout := ContentDB.get_layout(REGION)
	assert_eq(map.habitat_at(Vector2(10, 10)), "", "sky")
	assert_eq(map.habitat_at(Vector2(float(layout["rod_origin"][0]), float(layout["rod_origin"][1]))), "", "the angler's own spot")
	assert_false(map.is_water(Vector2(10, 10)))
	_free_zones()

func test_pond_points_resolve_to_a_habitat_and_overlays_win() -> void:
	var map := _map()
	var center := map.pond_center()
	assert_true(map.is_water(center))
	assert_true(map.habitat_at(center) != "")
	# The bottom zone is an overlay on the open-water base zone.
	assert_eq(map.habitat_at(Vector2(360, 820)), "bottom")
	assert_eq(map.habitat_at(Vector2(360, 600)), "open_water")
	assert_eq(map.habitat_at(Vector2(190, 700)), "vegetation")
	assert_eq(map.habitat_at(Vector2(360, 950)), "shallow")
	_free_zones()

func test_random_points_land_in_the_requested_habitat() -> void:
	var map := _map()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for habitat in ContentDB.get_region(REGION)["habitats"]:
		for i in 60:
			var point := map.random_point([habitat], rng)
			assert_eq(map.habitat_at(point), habitat, "point %s" % point)
	var either := map.random_point(["bottom", "shallow"], rng)
	assert_true(map.habitat_at(either) in ["bottom", "shallow"])
	_free_zones()

func test_random_point_for_an_unknown_habitat_falls_back_to_the_pond() -> void:
	var map := _map()
	var rng := RandomNumberGenerator.new()
	assert_true(map.is_water(map.random_point(["lagoon"], rng)))
	_free_zones()

func test_zone_component_area_and_containment() -> void:
	var zone := HabitatZone.from_layout({"habitat": "shallow", "polygon": [[0, 0], [100, 0], [100, 50], [0, 50]]})
	assert_eq(zone.habitat_tag, "shallow")
	assert_eq(zone.area(), 5000.0)
	assert_true(zone.contains_point(Vector2(50, 25)))
	assert_false(zone.contains_point(Vector2(150, 25)))
	zone.position = Vector2(200, 0)
	assert_true(zone.contains_point(Vector2(250, 25)), "containment must respect the node's position")
	zone.free()

func test_layout_palettes_cover_every_slice_level() -> void:
	var layout := ContentDB.get_layout(REGION)
	var cap: int = ContentDB.balance["vertical_slice"]["max_restoration_level"]
	assert_true(layout["levels"].size() >= cap + 1, "needs a palette for levels 0..%d" % cap)
	# Restoration must be visible: the water gets lighter / clearer with every level.
	var previous := -1.0
	for i in cap + 1:
		var shallow := Color(layout["levels"][i]["water_shallow"])
		var greenness := shallow.g - shallow.r
		assert_true(greenness > previous, "level %d water is not clearer than level %d" % [i, i - 1])
		previous = greenness

func test_props_appear_progressively_with_restoration() -> void:
	var layout := ContentDB.get_layout(REGION)
	var cap: int = ContentDB.balance["vertical_slice"]["max_restoration_level"]
	var visible_by_level: Array = []
	for level in cap + 1:
		var count := 0
		for prop in layout["props"]:
			if level >= int(prop.get("min_level", 0)) and level <= int(prop.get("max_level", 999)):
				count += 1
		visible_by_level.append(count)
	# Every level must change something on screen (GDD §9: each stage has a visible change).
	for level in range(1, cap + 1):
		var added := 0
		var removed := 0
		for prop in layout["props"]:
			var now: bool = level >= int(prop.get("min_level", 0)) and level <= int(prop.get("max_level", 999))
			var before: bool = level - 1 >= int(prop.get("min_level", 0)) and level - 1 <= int(prop.get("max_level", 999))
			added += int(now and not before)
			removed += int(before and not now)
		var animals_added := 0
		for animal in layout["ambient_animals"]:
			animals_added += int(int(animal["min_level"]) == level)
		var palette_changed: bool = layout["levels"][level] != layout["levels"][level - 1]
		assert_true(added + removed + animals_added > 0 or palette_changed, "level %d changes nothing visible" % level)
	assert_true(visible_by_level[cap] > visible_by_level[0], "a restored pond should be fuller than a barren one")
