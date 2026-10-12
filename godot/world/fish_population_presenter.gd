class_name FishPopulationPresenter
extends Node2D

## Draws the persistent population as swimming fish (TECH_SPEC §6-7, P0-019).
##
## The save holds numbers; this node shows a bounded set of representatives picked by
## PopulationModel, pooled so nothing is created or freed while playing: when the population
## shrinks, agents go back to the pool, and the total never exceeds the quality budget (so the
## node count cannot grow without bound). No code here scans the fish catalog per frame: species
## definitions are looked up once when an agent is configured.
##
## AI is throttled: agents near the focus point (the bobber) re-plan about 15 times a second,
## the rest about 3 times a second (halved again in Battery Saver). Movement is integrated
## every frame from the last plan, so motion stays smooth regardless of the tick rate.

const NEAR_RADIUS := 260.0
const NEAR_TICK_SEC := 1.0 / 15.0
const FAR_TICK_SEC := 1.0 / 3.0
const ARRIVE_DISTANCE := 16.0
## The approaching fish stops this far below the bobber (a nibble seen from above, not on top of it).
const APPROACH_BELOW := 10.0

var region_id := ""
var habitat_map: HabitatMap = null
var rng := RandomNumberGenerator.new()
## Position of interest (the line in the water); far from everything when no line is out.
var focus := Vector2(-100000, -100000)
var reduced_motion := false
## Test seam: replaces GameState as the source of populations and settings.
var game_state: Node = null

var _model: PopulationModel
var _active: Array[FishAgent] = []
var _pool: Array[FishAgent] = []
var _refresh_queued := false

func setup(p_region_id: String, map: HabitatMap) -> void:
	region_id = p_region_id
	habitat_map = map
	_model = PopulationModel.new(ContentDB.balance["population"])
	rng.randomize()
	EventBus.region_population_changed.connect(func(_region: String, _fish: String, _population: int) -> void: queue_refresh())
	EventBus.game_state_replaced.connect(queue_refresh)
	EventBus.settings_changed.connect(_on_setting_changed)
	refresh()

func _state() -> Node:
	return game_state if game_state != null else GameState

func _on_setting_changed(key: String) -> void:
	if key in ["quality", "battery_saver", "reduced_motion"]:
		reduced_motion = _state().get_setting("reduced_motion") == true
		queue_refresh()

## Coalesces bursts of population events into one refresh on the next idle frame.
func queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()

func agent_budget() -> int:
	return _model.total_cap(String(_state().get_setting("quality")), _state().get_setting("battery_saver") == true)

## Brings the visible fish in line with the saved population.
func refresh() -> void:
	_refresh_queued = false
	if habitat_map == null:
		return
	var desired := _model.compose(_state().get_species_population(region_id), agent_budget())
	var present := {}
	for agent in _active:
		present[agent.fish_id] = present.get(agent.fish_id, 0) + 1
	# Remove surplus first so the pool has agents to hand out below.
	for i in range(_active.size() - 1, -1, -1):
		var agent := _active[i]
		if present[agent.fish_id] > desired.get(agent.fish_id, 0):
			present[agent.fish_id] -= 1
			_release(agent)
	for fish_id in desired:
		var have := 0
		for agent in _active:
			if agent.fish_id == fish_id:
				have += 1
		for i in range(have, desired[fish_id]):
			_acquire(fish_id)

func _acquire(fish_id: String) -> FishAgent:
	var fish_def := ContentDB.get_fish(fish_id)
	if fish_def.is_empty():
		return null
	var agent: FishAgent
	if _pool.is_empty():
		agent = FishAgent.new()
		add_child(agent)
	else:
		agent = _pool.pop_back()
	agent.configure(fish_def)
	agent.position = habitat_map.random_point(agent.habitats, rng)
	agent.visible = true
	_active.append(agent)
	return agent

func _release(agent: FishAgent) -> void:
	_active.erase(agent)
	agent.visible = false
	_pool.append(agent)

## The release moment (GDD §19 "First Wow"): a representative of the species appears where the
## line was, with a ring around it, and swims off into the pond.
func welcome_released_fish(fish_id: String, at: Vector2) -> void:
	refresh()
	var chosen: FishAgent = null
	for agent in _active:
		if agent.fish_id == fish_id:
			chosen = agent
			if agent.highlight <= 0.0:
				break
	if chosen == null:
		return
	chosen.position = at if habitat_map.is_water(at) else habitat_map.random_point(chosen.habitats, rng)
	chosen.highlight = 2.5
	chosen.think_left = 0.0

func agent_count() -> int:
	return _active.size()

func pool_size() -> int:
	return _pool.size()

func active_agents() -> Array[FishAgent]:
	return _active

func _process(delta: float) -> void:
	var slow: bool = _state().get_setting("battery_saver") == true
	for agent in _active:
		agent.think_left -= delta
		agent.approach_left = maxf(agent.approach_left - delta, 0.0)
		if agent.think_left <= 0.0:
			var near := agent.position.distance_to(focus) < NEAR_RADIUS
			agent.think_left = (NEAR_TICK_SEC if near else FAR_TICK_SEC) * (2.0 if slow else 1.0)
			_think(agent)
		_move(agent, delta)
		agent.animate(delta, reduced_motion)

## A fish swims to the bobber before it bites (the fish that is going to bite: one of that species when the
## pond shows one, else the nearest fish), arriving under it in about `seconds`. Returns the agent, or null
## when there is no fish to send.
func approach(fish_id: String, at: Vector2, seconds: float) -> FishAgent:
	end_approach()
	var chosen: FishAgent = null
	var best := INF
	for agent in _active:
		# The same species first, then the nearest (a fish of another species is a far second choice).
		var score := agent.position.distance_to(at) + (0.0 if agent.fish_id == fish_id else 100000.0)
		if score < best:
			best = score
			chosen = agent
	if chosen == null:
		return null
	chosen.approach_to = at
	chosen.approach_left = maxf(seconds, 0.5)
	chosen.think_left = 0.0
	return chosen

## The approaching fish goes back to its own wandering (the line came out, the fish was hooked or it left).
func end_approach() -> void:
	for agent in _active:
		if agent.approach_to != Vector2.ZERO:
			agent.approach_to = Vector2.ZERO
			agent.target = Vector2.ZERO
			agent.think_left = 0.0

## The AI tick: pick a destination and a velocity for the species' temperament.
func _think(agent: FishAgent) -> void:
	if agent.approach_to != Vector2.ZERO:
		# Heading for the bobber, slowing to a hover just under it: a steady glide timed to the bite.
		var to_bobber := agent.approach_to + Vector2(0, APPROACH_BELOW) - agent.position
		var distance := to_bobber.length()
		if distance < ARRIVE_DISTANCE:
			agent.velocity = Vector2.ZERO
			return
		# Fast enough to be there for the bite (a fish going for food may hurry), never more than five times its cruise.
		var speed := clampf(distance / maxf(agent.approach_left, 0.3), agent.base_speed * 0.4, agent.base_speed * 5.0)
		agent.velocity = to_bobber / distance * speed
		return
	if agent.position.distance_to(agent.target) < ARRIVE_DISTANCE or agent.target == Vector2.ZERO:
		agent.target = habitat_map.random_point(agent.habitats, rng)
	var to_target := agent.target - agent.position
	var direction := to_target.normalized()
	var speed := agent.base_speed
	match agent.behavior:
		"dasher":
			if agent.burst_left > 0.0:
				speed *= 2.8
				agent.burst_left -= agent.think_left
			elif rng.randf() < 0.06:
				agent.burst_left = 0.6
		"heavy", "bottom":
			speed *= 0.7
		"surface":
			speed *= 1.2
		"zigzag":
			agent.wander_phase += 0.9
			direction = direction.rotated(sin(agent.wander_phase) * 0.8)
	agent.velocity = direction * speed

func _move(agent: FishAgent, delta: float) -> void:
	var next := agent.position + agent.velocity * delta
	if habitat_map.is_water(next):
		agent.position = next
	elif agent.approach_to != Vector2.ZERO:
		# On its way to the bobber a bank in between is skirted: slide along it on one axis.
		for step in [Vector2(agent.velocity.x, 0.0), Vector2(0.0, agent.velocity.y)]:
			if habitat_map.is_water(agent.position + step * delta):
				agent.position += step * delta
				break
	else:
		agent.velocity = Vector2.ZERO
		agent.target = Vector2.ZERO  # pick a new destination at the next tick
		agent.think_left = 0.0
