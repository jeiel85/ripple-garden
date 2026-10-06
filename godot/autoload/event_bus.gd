extends Node

## Global event vocabulary (TECH_SPEC §3). Data flow is
## UI -> command (method call on a domain service) -> state update -> event -> UI refresh.
##
## Conventions (enforced by tests/unit/test_event_bus.gd):
##  - An event is a fact that already happened: past tense (`fish_caught`) or `<thing>_changed`.
##    Requests and commands are method calls on a service, never signals here.
##  - Every parameter is explicitly typed. No `Dictionary` payloads and no untyped/Variant
##    parameters: a payload shape change must break callers at parse time, not at runtime.
##  - Content is referenced by its string id (`fish_id`, `region_id`, ...); never by Node or
##    Resource references, so events stay valid across scene changes and are loggable.
##  - Only domain services emit events (GameState, SaveService, FishingController, ...).
##    UI listens and issues commands; it never emits and never mutates state.
##  - Per-frame data (fight tension, fish positions) does not go through the bus; the owner
##    exposes its own signal to the one view that needs it.

# --- fishing flow ---
signal cast_landed(position: Vector2, habitat: String)
signal bite_hinted()
signal fish_hooked(fish_id: String)
## `reason` is one of "missed_hook", "line_slack", "line_snapped".
signal fish_escaped(fish_id: String, reason: String)
signal fishing_cancelled()
signal fish_caught(fish_id: String, size_cm: float, first_discovery: bool)
signal fish_released(fish_id: String, region_id: String, size_cm: float)

# --- persistent state ---
## The whole state was swapped (new game, load, debug reset); views must refresh everything.
signal game_state_replaced()
signal economy_changed(ripple: int, memory: int)
signal collection_changed(fish_id: String)
signal region_population_changed(region_id: String, fish_id: String, population: int)
signal region_restoration_points_changed(region_id: String, points: int)
signal region_restoration_changed(region_id: String, level: int)
signal inventory_changed()
## Read the new value through GameState.get_setting(key).
signal settings_changed(key: String)

# --- world clock ---
signal game_time_band_changed(time_band: String)
signal weather_changed(weather_id: String)

# --- persistence ---
signal save_completed()
signal save_failed(message: String)
## A backup was used because the primary save was unreadable. `source` is the file name used.
signal save_recovered(source: String)
