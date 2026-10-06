class_name DebugService
extends RefCounted

## QA / developer commands (AI_AGENT_GUIDE §9, TECH_SPEC §18): set time, set weather, spawn fish,
## set restoration, grant currency, simulate offline and corrupt a save. The commands are plain
## methods so tests can drive them; the DebugMenu is just buttons over them.
##
## Every command checks `enabled` first and does nothing in a release build, so a debug path can
## never alter a player's game even if something calls it.

## Midpoints (hours) used to jump to a time band.
const BAND_HOURS := {"dawn": 7.0, "day": 12.0, "dusk": 18.0, "night": 23.0}

var enabled := BuildProfile.debug_tools_enabled()
var fishing: FishingController
var weather: WeatherService
var time: Node
var state: Node
var save: Node
var restoration: RestorationService

func _init(p_fishing: FishingController, p_weather: WeatherService, p_time: Node, p_state: Node,
		p_save: Node, p_restoration: RestorationService) -> void:
	fishing = p_fishing
	weather = p_weather
	time = p_time
	state = p_state
	save = p_save
	restoration = p_restoration

func set_time_band(band: String) -> bool:
	if not enabled or not BAND_HOURS.has(band):
		return false
	time.set_game_minutes(float(BAND_HOURS[band]) * 60.0)
	return true

func set_hour(hours: float) -> bool:
	if not enabled:
		return false
	time.set_game_minutes(clampf(hours, 0.0, 23.99) * 60.0)
	return true

func set_weather(weather_id: String) -> bool:
	return enabled and weather.set_weather(weather_id)

## The next bite will be `fish_id`.
func spawn_fish(fish_id: String) -> bool:
	return enabled and fishing.spawn_fish(fish_id)

## Jumps a region to `level` (clamped to what the slice allows), granting the points that level
## needs so the save stays consistent.
func set_restoration(region_id: String, level: int) -> bool:
	if not enabled:
		return false
	level = clampi(level, 0, restoration.max_level(region_id))
	var needed := restoration.points_for_level(level)
	var have: int = state.get_restoration_points(region_id)
	if have < needed:
		state.add_restoration_points(region_id, needed - have)
	state.set_restoration_level(region_id, level)
	return true

func grant_currency(ripple: int, memory: int) -> bool:
	if not enabled or ripple < 0 or memory < 0:
		return false
	state.add_ripple(ripple)
	state.add_memory(memory)
	return true

## Returns the number of offline seconds applied (0 when disabled).
func simulate_offline(seconds: int) -> int:
	return time.skip_time(seconds) if enabled else 0

## Keeps a copy of the save and truncates the real one to exercise recovery.
func corrupt_save_copy() -> bool:
	return enabled and save.qa_corrupt_primary()

## Reloads the save from disk (to see recovery from a corrupted primary).
func reload_save() -> String:
	return save.load_game() if enabled else ""
