class_name FishingController
extends Node

## The fishing state machine (GDD §7, TECH_SPEC §9):
##   READY -> AIM -> CAST -> WAIT -> BITE_HINT -> HOOK -> FIGHT -> LAND -> INSPECT -> RELEASE
##
## It knows nothing about views: it owns state transitions and timers, and announces what
## happened on EventBus; animation, sound and haptics subscribe. Input arrives as commands
## (`begin_aim`, `cast`, `tap`, `set_reeling`, `release_catch`, `cancel`).
##
## Everything that can fail does so gently: a missed hook or a lost fight just ends the attempt
## (`fish_escaped`) and the player is back at READY with nothing lost (GDD "Failure").
##
## Time only advances through `advance(delta)`, which `_process` calls while a timed state is
## active; tests call it directly. All randomness comes from `rng` (seedable for QA).

enum State { READY, AIM, CAST, WAIT, BITE_HINT, HOOK, FIGHT, LAND, INSPECT, RELEASE }

## The only legal transitions. Anything else is a bug and is refused with an error.
const TRANSITIONS := {
	# READY -> INSPECT exists only for resume_pending_catch() after a crash or force-close.
	State.READY: [State.AIM, State.CAST, State.INSPECT],
	State.AIM: [State.CAST, State.READY],
	State.CAST: [State.WAIT, State.READY],
	State.WAIT: [State.BITE_HINT, State.READY],
	State.BITE_HINT: [State.HOOK, State.FIGHT, State.READY],
	State.HOOK: [State.FIGHT, State.READY],
	State.FIGHT: [State.LAND, State.READY],
	State.LAND: [State.INSPECT],
	State.INSPECT: [State.RELEASE],
	State.RELEASE: [State.READY],
}

const TIMED_STATES: Array = [State.CAST, State.WAIT, State.BITE_HINT, State.HOOK, State.LAND, State.RELEASE]

signal state_changed(previous: State, current: State)
## Per-frame fight data for the one view that draws the meter (not an EventBus event).
signal fight_updated(tension: float, progress: float)
## A cast was refused; `reason` is "busy" or "no_fish_here". The attempt never started.
signal cast_rejected(reason: String)

var state: State = State.READY
var region_id := "region_01_quiet_pond"
var rng := RandomNumberGenerator.new()
## Where the current/last line landed and the habitat there.
var landing := Vector2.ZERO
var habitat := ""
var reeling := false
## The fish on the line (null while nothing has bitten) and the active fight, if any.
var encounter: EncounterResolver.Encounter = null
var fight: FightSimulation = null
## What the player earned by releasing the last catch; null until a release happens.
var last_reward: CatchService.Reward = null

## Injectable collaborators; tests replace them, the game uses the autoloads.
var game_state: Node = null
## () -> {"time_band": String, "weather_id": String}; defaults to TimeService + clear weather.
var context_provider := Callable()
## Called right after a fish is landed and after it is released, so a crash cannot lose either.
## The game wires it to SaveService.save_if_dirty; it stays empty in tests, which must never save.
var save_hook := Callable()

var _resolver: EncounterResolver
var _catches: CatchService
var _timer := 0.0
var _miss_counts: Dictionary = {}
var _forced_fish_id := ""

func _ready() -> void:
	rng.randomize()
	set_process(false)

func _process(delta: float) -> void:
	advance(delta)

func set_seed(seed_value: int) -> void:
	rng.seed = seed_value

func _state() -> Node:
	return game_state if game_state != null else GameState

func _config() -> Dictionary:
	return ContentDB.balance["fishing"]

func _resolver_instance() -> EncounterResolver:
	if _resolver == null:
		_resolver = EncounterResolver.new(ContentDB.balance["encounter"])
	return _resolver

func _catch_service() -> CatchService:
	if _catches == null:
		_catches = CatchService.new(_state(), ContentDB.balance["rewards"])
	return _catches

# --- commands ---

func begin_aim() -> bool:
	return _enter(State.AIM)

## Casts towards `target`, which landed in `habitat_tag` ("" means not water). Refused (and the
## controller stays or returns to READY) when the line cannot land on water with fish.
func cast(target: Vector2, habitat_tag: String) -> bool:
	if state != State.READY and state != State.AIM:
		cast_rejected.emit("busy")
		return false
	if not _can_fish_in(habitat_tag):
		if state == State.AIM:
			_enter(State.READY)
		cast_rejected.emit("no_fish_here")
		return false
	landing = target
	habitat = habitat_tag
	_timer = _roll(_config()["cast_sec"])
	return _enter(State.CAST)

## The single input for "act now": pull the line back while waiting, set the hook once the fish
## bites. Returns whether it did anything.
func tap() -> bool:
	match state:
		State.WAIT:
			return cancel()
		State.BITE_HINT, State.HOOK:
			return hook()
	return false

## Sets the hook. Accepted as soon as the bobber dips (BITE_HINT) and during the hook window.
func hook() -> bool:
	if state != State.BITE_HINT and state != State.HOOK:
		return false
	if encounter == null:
		return false
	return _start_fight()

## Whether the player is reeling (screen held). Only matters during the fight.
func set_reeling(on: bool) -> void:
	reeling = on

## Gives up the attempt without penalty. Allowed until the fish is landed.
func cancel() -> bool:
	if state in [State.AIM, State.CAST, State.WAIT, State.BITE_HINT, State.HOOK, State.FIGHT]:
		var announce := state != State.AIM
		_finish_attempt()
		if announce:
			EventBus.fishing_cancelled.emit()
		return true
	return false

## Lets the inspected fish go and applies the rewards. Returns false outside INSPECT.
func release_catch() -> bool:
	if state != State.INSPECT:
		return false
	var reward := _catch_service().release_catch()
	if reward == null:
		push_error("FishingController: INSPECT without a pending catch")
		_enter(State.RELEASE)  # the only exit from INSPECT
		_finish_attempt()
		return false
	last_reward = reward
	_request_save()
	_timer = float(_config()["release_sec"])
	return _enter(State.RELEASE)

## After a crash or force-close with a fish still in hand, goes straight back to inspecting it so
## the player can release it. Returns whether there was a pending catch.
func resume_pending_catch() -> bool:
	if state != State.READY:
		return false
	var pending: Dictionary = _state().get_pending_catch()
	if pending.is_empty():
		return false
	encounter = EncounterResolver.Encounter.new()
	encounter.fish_id = pending["fish_id"]
	encounter.size_cm = float(pending["size_cm"])
	encounter.rarity = int(pending["rarity"])
	var def := ContentDB.get_fish(encounter.fish_id)
	encounter.behavior = def.get("behavior", "")
	region_id = pending["region_id"]
	return _enter(State.INSPECT)

## QA hook (debug menu "spawn fish"): the next bite is this fish instead of a random one.
func spawn_fish(fish_id: String) -> bool:
	if ContentDB.get_fish(fish_id).is_empty():
		return false
	_forced_fish_id = fish_id
	return true

# --- time ---

## Advances timers and the fight by `delta` seconds.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	if state == State.FIGHT:
		_advance_fight(delta)
		return
	if not state in TIMED_STATES:
		return
	_timer -= delta
	if _timer <= 0.0:
		var leftover := -_timer
		_on_timeout()
		if leftover > 0.0:
			advance(leftover)  # a long frame can cross more than one state boundary

func _on_timeout() -> void:
	match state:
		State.CAST:
			_land_cast()
		State.WAIT:
			if encounter == null:
				_finish_attempt()  # nothing here would bite right now
				EventBus.fishing_cancelled.emit()
			else:
				_timer = _roll(_config()["bite_hint_sec"])
				if _enter(State.BITE_HINT):
					EventBus.bite_hinted.emit()
		State.BITE_HINT:
			var window_key := "hook_window_relaxed_sec" if _state().get_setting("relaxed_hook") == true else "hook_window_sec"
			_timer = _roll(_config()[window_key])
			if _enter(State.HOOK) and _state().get_setting("auto_hook") == true:
				hook()  # Auto Hook has no penalty (GDD §7)
		State.HOOK:
			_escape("missed_hook")
		State.LAND:
			_enter(State.INSPECT)
		State.RELEASE:
			_finish_attempt()

func _land_cast() -> void:
	EventBus.cast_landed.emit(landing, habitat)
	encounter = _roll_encounter()
	_timer = _roll_wait()
	_enter(State.WAIT)

func _roll_encounter() -> EncounterResolver.Encounter:
	var candidates := ContentDB.get_fish_for_region(region_id)
	if not _forced_fish_id.is_empty():
		var forced := EncounterResolver.Encounter.new()
		var def := ContentDB.get_fish(_forced_fish_id)
		forced.fish_id = _forced_fish_id
		forced.rarity = int(def["rarity"])
		forced.behavior = def["behavior"]
		forced.size_cm = _resolver_instance().roll_size(def, rng)
		forced.probability = 1.0
		_forced_fish_id = ""
		return forced
	return _resolver_instance().resolve(_make_request(), candidates, rng)

func _make_request() -> EncounterResolver.Request:
	var context := _context()
	var request := EncounterResolver.Request.new()
	request.habitat = habitat
	request.time_band = context["time_band"]
	request.weather_id = context["weather_id"]
	request.bait_tags = ContentDB.get_bait(_state().get_equipped_bait()).get("tags", [])
	request.ecosystem_level = _state().get_restoration_level(region_id)
	request.miss_counts = _miss_counts
	return request

func _context() -> Dictionary:
	if context_provider.is_valid():
		return context_provider.call()
	return {"time_band": TimeService.get_time_band(), "weather_id": "clear"}

## Wait until the bite: random in the configured range, faster with a more sensitive rod, never
## below the floor (GDD §7 WAIT).
func _roll_wait() -> float:
	var wait: Dictionary = _config()["wait_sec"]
	var rod := ContentDB.get_rod(_state().get_equipped_rod())
	var seconds := _roll(wait) / maxf(0.1, float(rod.get("bite_speed", 1.0)))
	return maxf(float(wait["floor"]), seconds)

func _can_fish_in(habitat_tag: String) -> bool:
	if habitat_tag.is_empty():
		return false
	for fish_def in ContentDB.get_fish_for_region(region_id):
		if habitat_tag in fish_def["habitats"]:
			return true
	return false

# --- fight ---

func _start_fight() -> bool:
	var fish_def := ContentDB.get_fish(encounter.fish_id)
	var behavior := ContentDB.get_behavior(encounter.behavior)
	var rod := ContentDB.get_rod(_state().get_equipped_rod())
	fight = FightSimulation.new(fish_def, behavior, _config()["fight"], float(rod.get("tension_assist", 0.0)), rng)
	if not _enter(State.FIGHT):
		fight = null
		return false
	EventBus.fish_hooked.emit(encounter.fish_id)
	return true

func _advance_fight(delta: float) -> void:
	fight.step(delta, reeling)
	fight_updated.emit(fight.tension, fight.progress)
	match fight.result:
		FightSimulation.Result.LANDED:
			_land_fish()
		FightSimulation.Result.SLACK:
			_escape("line_slack")
		FightSimulation.Result.SNAPPED:
			_escape("line_snapped")

func _land_fish() -> void:
	_miss_counts.erase(encounter.fish_id)
	_catch_service().begin_catch(encounter, region_id)
	_request_save()  # the discovery and the pending catch reach the disk now, not at the next autosave
	_timer = float(_config()["land_sec"])
	_enter(State.LAND)

func _escape(reason: String) -> void:
	var fish_id := encounter.fish_id
	if encounter.rarity >= int(ContentDB.balance["encounter"]["pity_min_rarity"]):
		_miss_counts[fish_id] = _miss_counts.get(fish_id, 0) + 1
	_finish_attempt()
	EventBus.fish_escaped.emit(fish_id, reason)

func _request_save() -> void:
	if save_hook.is_valid():
		save_hook.call()

# --- transitions ---

func _enter(next_state: State) -> bool:
	if not next_state in TRANSITIONS[state]:
		push_error("FishingController: illegal transition %s -> %s" % [State.keys()[state], State.keys()[next_state]])
		return false
	var previous := state
	state = next_state
	set_process(state in TIMED_STATES or state == State.FIGHT)
	EventBus.fishing_state_changed.emit(State.keys()[previous].to_lower(), State.keys()[state].to_lower())
	state_changed.emit(previous, state)
	return true

## Back to READY and forget everything about the attempt.
func _finish_attempt() -> void:
	encounter = null
	fight = null
	reeling = false
	_timer = 0.0
	if state != State.READY:
		_enter(State.READY)

func _roll(range_def: Dictionary) -> float:
	return rng.randf_range(float(range_def["min"]), float(range_def["max"]))
