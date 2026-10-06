extends TestCase

## P0-016 / P0-018: catching, inspecting and releasing — journal entry, pending catch, rewards,
## population and restoration points (BALANCE §5-6).

const REGION := "region_01_quiet_pond"

func _setup() -> Array:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	return [state, CatchService.new(state, ContentDB.balance["rewards"])]

func _encounter(fish_id: String, size_cm: float) -> EncounterResolver.Encounter:
	var def := ContentDB.get_fish(fish_id)
	var encounter := EncounterResolver.Encounter.new()
	encounter.fish_id = fish_id
	encounter.size_cm = size_cm
	encounter.rarity = int(def["rarity"])
	encounter.behavior = def["behavior"]
	return encounter

func test_begin_catch_records_the_encounter_and_saves_a_pending_catch() -> void:
	var parts := _setup()
	var state: Node = parts[0]
	var caught: Array = []
	var handler := func(fish_id: String, size_cm: float, first: bool) -> void: caught.append([fish_id, size_cm, first])
	EventBus.fish_caught.connect(handler)
	var pending: Dictionary = parts[1].begin_catch(_encounter("fish_crucian_carp", 14.5), REGION)
	EventBus.fish_caught.disconnect(handler)
	assert_deep_eq(caught, [["fish_crucian_carp", 14.5, true]])
	assert_true(state.has_discovered("fish_crucian_carp"))
	assert_eq(state.get_pending_catch()["fish_id"], "fish_crucian_carp")
	assert_eq(pending["first_discovery"], true)
	assert_eq(state.get_collection_record("fish_crucian_carp")["releases"], 0, "not released yet")
	state.free()

func test_first_release_gives_memory_and_discovery_bonus() -> void:
	var parts := _setup()
	var state: Node = parts[0]
	var rewards: Dictionary = ContentDB.balance["rewards"]
	parts[1].begin_catch(_encounter("fish_crucian_carp", 14.5), REGION)
	var reward: CatchService.Reward = parts[1].release_catch()
	assert_not_null(reward)
	var expected_points: int = int(rewards["restoration_points_by_rarity"]["1"]) + int(rewards["first_discovery_restoration_bonus"])
	assert_eq(reward.restoration_points, expected_points)
	assert_eq(reward.memory, int(rewards["memory_first_discovery_by_rarity"]["1"]))
	assert_true(reward.ripple >= int(rewards["ripple_by_rarity"]["1"]["min"]) and reward.ripple <= int(rewards["ripple_by_rarity"]["1"]["max"]))
	assert_eq(reward.population, 1)
	assert_eq(state.get_ripple(), reward.ripple)
	assert_eq(state.get_memory(), reward.memory)
	assert_eq(state.get_restoration_points(REGION), expected_points)
	assert_eq(state.get_population(REGION, "fish_crucian_carp"), 1)
	assert_eq(state.get_collection_record("fish_crucian_carp")["releases"], 1)
	assert_deep_eq(state.get_pending_catch(), {})
	state.free()

func test_release_emits_fish_released() -> void:
	var parts := _setup()
	var released: Array = []
	var handler := func(fish_id: String, region_id: String, size_cm: float) -> void: released.append([fish_id, region_id, size_cm])
	EventBus.fish_released.connect(handler)
	parts[1].begin_catch(_encounter("fish_minnow", 20.0), REGION)
	parts[1].release_catch()
	EventBus.fish_released.disconnect(handler)
	assert_deep_eq(released, [["fish_minnow", REGION, 20.0]])
	parts[0].free()

func test_repeat_catches_pay_less_but_never_nothing() -> void:
	var parts := _setup()
	var service: CatchService = parts[1]
	var first_points := 0
	var last_points := 0
	for i in 60:
		service.begin_catch(_encounter("fish_crucian_carp", 14.5), REGION)
		var reward: CatchService.Reward = service.release_catch()
		if i == 1:
			first_points = reward.restoration_points  # first repeat (the discovery bonus is gone)
		last_points = reward.restoration_points
		assert_true(reward.ripple >= 1 and reward.restoration_points >= 1, "release %d paid nothing" % i)
		assert_eq(reward.memory if i > 0 else -1, 0 if i > 0 else -1, "memory is for discoveries only")
	assert_true(last_points < first_points, "repeats should decay (%d -> %d)" % [first_points, last_points])
	assert_true(last_points >= 1)
	parts[0].free()

func test_repeat_multiplier_has_a_floor() -> void:
	var service: CatchService = _setup()[1]
	var rewards: Dictionary = ContentDB.balance["rewards"]
	assert_eq(service.repeat_multiplier(0), 1.0)
	assert_true(service.repeat_multiplier(5) < 1.0)
	assert_eq(service.repeat_multiplier(100000), float(rewards["repeat_floor"]))
	assert_eq(service.repeat_multiplier(-3), 1.0, "negative counts must not boost rewards")

func test_bigger_fish_pay_more_ripple() -> void:
	var small_ripple := 0
	var large_ripple := 0
	for size_cm in [5.0, 25.0]:
		var parts := _setup()
		parts[1].begin_catch(_encounter("fish_crucian_carp", size_cm), REGION)
		var reward: CatchService.Reward = parts[1].release_catch()
		if size_cm == 5.0:
			small_ripple = reward.ripple
		else:
			large_ripple = reward.ripple
		parts[0].free()
	assert_true(large_ripple > small_ripple, "%d vs %d" % [large_ripple, small_ripple])

func test_rarer_fish_pay_more() -> void:
	var common_points := 0
	var rare_points := 0
	for fish_id in ["fish_crucian_carp", "fish_snakehead"]:
		var parts := _setup()
		parts[1].begin_catch(_encounter(fish_id, 10.0), REGION)
		var reward: CatchService.Reward = parts[1].release_catch()
		if fish_id == "fish_crucian_carp":
			common_points = reward.restoration_points
		else:
			rare_points = reward.restoration_points
		parts[0].free()
	assert_true(rare_points > common_points)

func test_release_without_a_pending_catch_returns_null() -> void:
	var parts := _setup()
	assert_eq(parts[1].release_catch(), null)
	assert_eq(parts[0].get_ripple(), 0)
	parts[0].free()

func test_double_release_only_pays_once() -> void:
	var parts := _setup()
	parts[1].begin_catch(_encounter("fish_minnow", 20.0), REGION)
	assert_not_null(parts[1].release_catch())
	var ripple_after_first: int = parts[0].get_ripple()
	assert_eq(parts[1].release_catch(), null)
	assert_eq(parts[0].get_ripple(), ripple_after_first)
	parts[0].free()

func test_pending_catch_survives_a_save_round_trip() -> void:
	var parts := _setup()
	parts[1].begin_catch(_encounter("fish_bluegill", 22.0), REGION)
	var restored: Node = load("res://autoload/game_state.gd").new()
	restored.load_data(JSON.parse_string(JSON.stringify(parts[0].snapshot())))
	var reloaded: Dictionary = restored.get_pending_catch()
	assert_eq(typeof(reloaded["rarity"]), TYPE_INT, "rarity must be an int again after the JSON round trip")
	assert_eq(typeof(reloaded["size_cm"]), TYPE_FLOAT)
	assert_eq(reloaded["first_discovery"], true)
	var service := CatchService.new(restored, ContentDB.balance["rewards"])
	var reward: CatchService.Reward = service.release_catch()
	assert_not_null(reward, "a catch pending at save time must be releasable after loading")
	assert_eq(restored.get_population(REGION, "fish_bluegill"), 1)
	restored.free()
	parts[0].free()
