class_name RegionRuntime
extends Node2D

## One region as it exists at runtime (TECH_SPEC §2). It builds the habitat zones from the layout
## data, wires the presenters to the region and exposes what the rest of the game needs: the
## habitat map for casts, the aim geometry for the equipped rod, and the restoration look.
##
## Scene children (world/game_root.tscn): Environment, HabitatZones, FishPopulationPresenter,
## Props, AmbientAnimalPresenter, FishingView, WeatherPresenter and the WeatherService.

var region_id := ""
var layout: Dictionary = {}
var habitat_map: HabitatMap = null

@onready var environment: RegionEnvironment = $Environment
@onready var zones_root: Node2D = $HabitatZones
@onready var fish_presenter: FishPopulationPresenter = $FishPopulationPresenter
@onready var props: PropsLayer = $Props
@onready var animals: AmbientAnimalPresenter = $AmbientAnimalPresenter
@onready var fishing_view: FishingView = $FishingView
@onready var weather_presenter: WeatherPresenter = $WeatherPresenter
@onready var weather: WeatherService = $WeatherService

## Builds everything from the region's layout. `level` is the restoration level to show.
func setup(p_region_id: String, level: int, time_band: String) -> bool:
	region_id = p_region_id
	layout = ContentDB.get_layout(region_id)
	if layout.is_empty():
		push_error("RegionRuntime: region %s has no layout" % region_id)
		return false
	weather.start(region_id)
	var zone_nodes: Array[HabitatZone] = []
	habitat_map = HabitatMap.from_layout(layout, zone_nodes)
	for zone in zone_nodes:
		zones_root.add_child(zone)
	environment.setup(region_id, layout, weather, level)
	props.setup(layout, environment)
	fish_presenter.setup(region_id, habitat_map)
	animals.setup(layout, level, time_band)
	weather_presenter.setup(weather, habitat_map.pond)
	return true

## Rod tip where the line leaves the angler.
func rod_origin() -> Vector2:
	return Vector2(float(layout["rod_origin"][0]), float(layout["rod_origin"][1]))

## Aim geometry for a rod (`rod_range` is the rod's 0..1 range stat).
func cast_aim_for(rod_range: float) -> CastAim:
	var reach: Dictionary = layout["cast_reach_px"]
	var aim := CastAim.new(rod_origin(), float(reach["near"]), CastAim.reach_for_rod(rod_range, float(reach["near"]), float(reach["far"])),
		float(layout.get("cast_forward_deg", 0.0)))
	return aim

## Where the angler sits (the rod is held from here), or a point under the rod tip when the layout
## has no angler.
func angler_position() -> Vector2:
	var angler: Variant = layout.get("angler")
	if typeof(angler) == TYPE_DICTIONARY:
		return Vector2(float(angler["x"]), float(angler["y"]))
	return rod_origin() + Vector2(0, 90)

## Shows a restoration level. With `animate` the world eases to it (UI_UX §6: a short, quiet change).
func apply_level(level: int, animate: bool) -> void:
	environment.set_level(level, animate)
	props.refresh()
	animals.set_level(level)

func set_debug_zones(on: bool) -> void:
	for zone in zones_root.get_children():
		if zone is HabitatZone:
			zone.debug_draw = on
