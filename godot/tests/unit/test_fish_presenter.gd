extends TestCase

## P0-019: visible fish — bounded, pooled, throttled and kept inside the water.

const REGION := "region_01_quiet_pond"

var _zone_nodes: Array[HabitatZone] = []

func _setup() -> Array:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	_zone_nodes = []
	var map := HabitatMap.from_layout(ContentDB.get_layout(REGION), _zone_nodes)
	var presenter := FishPopulationPresenter.new()
	presenter.game_state = state
	presenter.rng.seed = 5
	presenter.setup(REGION, map)
	return [presenter, state, map]

func _teardown(parts: Array) -> void:
	parts[0].free()
	parts[1].free()
	for zone in _zone_nodes:
		zone.free()
	_zone_nodes.clear()

func _populate(state: Node, amount: int) -> void:
	for fish_def in ContentDB.get_fish_for_region(REGION):
		state.add_population(REGION, fish_def["id"], amount)

func _total_nodes(presenter: FishPopulationPresenter) -> int:
	return presenter.agent_count() + presenter.pool_size()

func test_no_population_means_no_fish() -> void:
	var parts := _setup()
	assert_eq(parts[0].agent_count(), 0)
	_teardown(parts)

func test_agents_follow_the_population_steps() -> void:
	var parts := _setup()
	parts[1].add_population(REGION, "fish_minnow", 5)
	parts[0].refresh()
	assert_eq(parts[0].agent_count(), 1)
	parts[1].add_population(REGION, "fish_minnow", 10)  # 15 -> 2 visible
	parts[0].refresh()
	assert_eq(parts[0].agent_count(), 2)
	parts[1].add_population(REGION, "fish_minnow", 60)  # 75 -> 4 visible
	parts[0].refresh()
	assert_eq(parts[0].agent_count(), 4)
	for agent in parts[0].active_agents():
		assert_eq(agent.fish_id, "fish_minnow")
	_teardown(parts)

func test_the_budget_caps_visible_fish_by_quality_and_battery_saver() -> void:
	var parts := _setup()
	_populate(parts[1], 100)
	parts[0].refresh()
	var medium: int = parts[0].agent_count()
	assert_true(medium <= 35 and medium >= 10, "medium shows %d fish" % medium)
	parts[1].set_setting("quality", "low")
	parts[0].refresh()
	assert_true(parts[0].agent_count() <= 20)
	assert_true(parts[0].agent_count() < medium)
	parts[1].set_setting("quality", "high")
	parts[0].refresh()
	assert_true(parts[0].agent_count() > medium - 1 and parts[0].agent_count() <= 50)
	parts[1].set_setting("battery_saver", true)
	parts[0].refresh()
	assert_true(parts[0].agent_count() < 50, "Battery Saver must lower the population shown")
	_teardown(parts)

func test_agents_are_pooled_and_never_exceed_the_budget_in_nodes() -> void:
	var parts := _setup()
	_populate(parts[1], 100)
	parts[0].refresh()
	var peak := _total_nodes(parts[0])
	# Shrink and grow repeatedly: nodes are reused, so the total never grows past the peak.
	for round_index in 6:
		parts[1].set_setting("quality", "low")
		parts[0].refresh()
		parts[1].set_setting("quality", "medium")
		parts[0].refresh()
	assert_eq(_total_nodes(parts[0]), peak, "pooled agents must be reused, not recreated")
	assert_eq(parts[0].get_child_count(), peak)
	_teardown(parts)

func test_removed_species_return_to_the_pool() -> void:
	var parts := _setup()
	parts[1].add_population(REGION, "fish_minnow", 5)
	parts[1].add_population(REGION, "fish_loach", 5)
	parts[0].refresh()
	assert_eq(parts[0].agent_count(), 2)
	parts[1].load_data({"save_version": 1})  # a different game: nothing lives here
	parts[0].refresh()
	assert_eq(parts[0].agent_count(), 0)
	assert_eq(parts[0].pool_size(), 2)
	for agent in parts[0].get_children():
		assert_false(agent.visible, "pooled agents must be hidden")
	_teardown(parts)

func test_agents_stay_in_the_water_while_swimming() -> void:
	var parts := _setup()
	_populate(parts[1], 100)
	parts[0].refresh()
	var map: HabitatMap = parts[2]
	for agent in parts[0].active_agents():
		assert_true(map.is_water(agent.position), "%s spawned on land at %s" % [agent.fish_id, agent.position])
	for frame in 900:
		parts[0]._process(1.0 / 30.0)
	for agent in parts[0].active_agents():
		assert_true(map.is_water(agent.position), "%s left the pond at %s" % [agent.fish_id, agent.position])
	_teardown(parts)

func test_fish_actually_move() -> void:
	var parts := _setup()
	parts[1].add_population(REGION, "fish_minnow", 5)
	parts[0].refresh()
	var agent: FishAgent = parts[0].active_agents()[0]
	var start := agent.position
	for frame in 300:
		parts[0]._process(1.0 / 30.0)
	assert_true(agent.position.distance_to(start) > 20.0, "the fish never swam")
	_teardown(parts)

func test_near_agents_think_more_often_than_far_ones() -> void:
	var parts := _setup()
	parts[1].add_population(REGION, "fish_minnow", 5)
	parts[1].add_population(REGION, "fish_loach", 5)
	parts[0].refresh()
	var agents: Array[FishAgent] = parts[0].active_agents()
	# Two spots in the water that are further apart than the "near" radius.
	agents[0].position = Vector2(200, 700)
	agents[1].position = Vector2(520, 800)
	assert_true(parts[2].is_water(agents[0].position) and parts[2].is_water(agents[1].position))
	assert_true(agents[0].position.distance_to(agents[1].position) > FishPopulationPresenter.NEAR_RADIUS)
	parts[0].focus = agents[0].position
	for agent in agents:
		agent.think_left = 0.0
	parts[0]._process(0.001)
	assert_true(agents[0].think_left <= FishPopulationPresenter.NEAR_TICK_SEC + 0.001, "near agent ticks fast")
	assert_true(agents[1].think_left >= FishPopulationPresenter.FAR_TICK_SEC - 0.001, "far agent ticks slowly")
	parts[1].set_setting("battery_saver", true)
	for agent in agents:
		agent.think_left = 0.0
	parts[0]._process(0.001)
	assert_true(agents[0].think_left >= FishPopulationPresenter.NEAR_TICK_SEC * 1.9, "Battery Saver halves the AI rate")
	_teardown(parts)

func test_a_released_fish_is_welcomed_where_the_line_was() -> void:
	var parts := _setup()
	parts[1].add_population(REGION, "fish_catfish", 1)
	parts[0].welcome_released_fish("fish_catfish", Vector2(360, 760))
	var agent: FishAgent = parts[0].active_agents()[0]
	assert_eq(agent.fish_id, "fish_catfish")
	assert_eq(agent.position, Vector2(360, 760))
	assert_true(agent.highlight > 0.0, "the newcomer is marked with a ring")
	parts[0].welcome_released_fish("fish_catfish", Vector2(10, 10))  # on land: lands in the pond instead
	assert_true(parts[2].is_water(parts[0].active_agents()[0].position))
	_teardown(parts)

func test_species_look_different_from_each_other() -> void:
	var colors := {}
	var lengths := {}
	for fish_def in ContentDB.get_fish_for_region(REGION):
		var agent := FishAgent.new()
		agent.configure(fish_def)
		colors[agent.body_color.to_html()] = true
		lengths[snappedf(agent.length_px, 0.5)] = true
		agent.free()
	assert_true(colors.size() >= 8, "only %d distinct colours across 10 species" % colors.size())
	assert_true(lengths.size() >= 4, "species should differ in size too")
