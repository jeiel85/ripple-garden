class_name AutoFishing
extends Node

## Auto fishing (owner's request 2026-10-12, D-034): once the first steps are behind the player (enough
## species met, balance.json `auto_fishing.unlock_species`) a switch lets the game fish by itself. It
## casts at a spot where fish live, sets the hook, reels while keeping the tension in the band and lets
## the catch go after a short look.
##
## It only issues the commands a player would (`cast_at`, `hook`, `set_reeling`, `release_catch`), so
## rewards, bait use and escapes are exactly those of fishing by hand. It is a switch for this session,
## not a saved setting: every start is hands-on until the player turns it on again.

signal enabled_changed(on: bool)

## Tries for a cast spot on water fish live in before falling back to the quick cast.
const SPOT_TRIES := 24
## Share of the rod's sideways reach the spots are picked from (the far edges are mostly bank).
const SPREAD := 0.8

var enabled := false
var fishing: FishingController
var world_input: WorldInput
## () -> bool: true while no new cast should start (an open screen, water-mind, photo mode).
var blocked := Callable()
var rng := RandomNumberGenerator.new()

var _config: Dictionary = {}
var _wait := 0.0

func _ready() -> void:
	rng.randomize()
	set_process(false)

func setup(p_fishing: FishingController, p_world_input: WorldInput, p_blocked: Callable = Callable()) -> void:
	fishing = p_fishing
	world_input = p_world_input
	blocked = p_blocked
	_config = ContentDB.balance["auto_fishing"]
	fishing.state_changed.connect(_on_state_changed)

## Whether the player has come far enough to fish automatically.
static func is_available(game_state: Node) -> bool:
	return game_state.discovered_count() >= int(ContentDB.balance["auto_fishing"]["unlock_species"])

## Turns auto fishing on or off. Refused (false) while it is not available yet.
func set_enabled(on: bool) -> bool:
	if on and not is_available(GameState):
		return false
	if enabled == on:
		return true
	enabled = on
	set_process(on)
	_restart_wait()
	if not on:
		fishing.set_reeling(false)  # a fight in progress goes back to the player's hands
	enabled_changed.emit(on)
	return true

func _process(delta: float) -> void:
	step(delta)

## Advances the auto fisher by `delta` seconds (tests call it directly).
func step(delta: float) -> void:
	if not enabled:
		return
	match fishing.state:
		FishingController.State.READY:
			if blocked.is_valid() and blocked.call():
				_wait = _seconds("cast_delay_sec")  # a pause starts over once the screen is clear
				return
			_wait -= delta
			if _wait <= 0.0:
				_wait = _seconds("cast_delay_sec")
				_cast()
		FishingController.State.BITE_HINT, FishingController.State.HOOK:
			_wait -= delta
			if _wait <= 0.0:
				fishing.hook()
		FishingController.State.FIGHT:
			if fishing.fight != null:
				fishing.set_reeling(should_reel(fishing.fight.tension, fishing.fight.band_min(), fishing.fight.band_max()))
		FishingController.State.INSPECT:
			_wait -= delta
			if _wait <= 0.0:
				_wait = _seconds("inspect_sec")
				fishing.release_catch()

## Reel while the tension is in the lower half of the band, let go in the upper half: the line rises and
## falls around the middle of the band whatever the fish does.
static func should_reel(tension: float, band_min: float, band_max: float) -> bool:
	return tension < (band_min + band_max) * 0.5

## A landing point within the rod's reach on water that holds fish here, or null if none was found.
func pick_spot(aim: CastAim, habitat_at: Callable) -> Variant:
	var limit := deg_to_rad(CastAim.MAX_ANGLE_DEG) * SPREAD
	for i in SPOT_TRIES:
		var direction := aim.forward.rotated(rng.randf_range(-limit, limit))
		var point := aim.landing_for(aim.origin + direction * rng.randf_range(aim.min_distance, aim.max_distance))
		if fishing.can_fish_in(String(habitat_at.call(point))):
			return point
	return null

func _cast() -> void:
	var spot: Variant = pick_spot(world_input.aim(), world_input.region.habitat_map.habitat_at)
	if spot is Vector2:
		world_input.cast_at(spot)
	else:
		world_input.cast_quick()

func _on_state_changed(previous: FishingController.State, current: FishingController.State) -> void:
	# The bobber dipping and the hook window are one moment to the auto fisher: its reaction time runs on.
	if previous == FishingController.State.BITE_HINT and current == FishingController.State.HOOK:
		return
	_restart_wait()

func _restart_wait() -> void:
	match fishing.state:
		FishingController.State.READY:
			_wait = _seconds("cast_delay_sec")
		FishingController.State.BITE_HINT, FishingController.State.HOOK:
			_wait = _seconds("hook_delay_sec")
		FishingController.State.INSPECT:
			_wait = _seconds("inspect_sec")
		_:
			_wait = 0.0

func _seconds(key: String) -> float:
	return float(_config.get(key, 1.0))
