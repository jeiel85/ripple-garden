extends TestCase

## BACKLOG "WAIT 중 앰비언트 이벤트": a leaping fish or a frog near the bobber while the line is out.

const DT := 1.0 / 30.0
const WATER := Vector2(360, 600)

func _make(seed_value: int = 7) -> Array:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	var controller := FishingController.new()
	controller.game_state = state
	controller.set_seed(seed_value)
	controller.context_provider = func() -> Dictionary: return {"time_band": "day", "weather_id": "clear"}
	var ambience := WaitAmbience.new()
	tree.root.add_child(ambience)
	ambience.setup(controller, null, "region_01_quiet_pond", Callable(), seed_value)
	return [controller, state, ambience]

func _free(parts: Array) -> void:
	parts[2].free()
	parts[0].free()
	parts[1].free()

## Casts and runs the cast out to WAIT. `habitat` overrides what the cast landed in, which is what
## decides whether the small event is a leaping fish or a frog.
func _to_wait(controller: FishingController, habitat: String = "") -> void:
	controller.begin_aim()
	controller.cast(WATER, "shallow")
	if not habitat.is_empty():
		controller.habitat = habitat
	var guard := 0
	while controller.state == FishingController.State.CAST and guard < 300:
		controller.advance(DT)
		guard += 1

func test_a_leaping_fish_happens_once_during_the_wait() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var ambience: WaitAmbience = parts[2]
	_to_wait(controller, "riffle")
	assert_eq(controller.state, FishingController.State.WAIT)
	assert_true(ambience.pending_delay() > 0.0, "a long wait plans one small event")
	var elapsed := 0.0
	while elapsed < 3.0 and not ambience.is_active():
		ambience.tick(DT)
		elapsed += DT
	assert_true(ambience.is_active(), "the leaping fish happens within the wait")
	assert_eq(ambience.active_kind(), "leap")
	assert_true(ambience.event_position().distance_to(controller.landing) < 120.0,
		"the event happens near the bobber, not across the pond")
	while ambience.is_active() and elapsed < 6.0:
		ambience.tick(DT)
		elapsed += DT
	assert_false(ambience.is_active(), "the event ends")
	assert_eq(ambience.pending_delay(), -1.0, "one event per cast")
	for i in 120:
		ambience.tick(DT)
	assert_false(ambience.is_active(), "no second event before the nibble")
	_free(parts)

func test_a_short_wait_has_no_room_for_an_event() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var ambience: WaitAmbience = parts[2]
	_to_wait(controller, "riffle")
	# A wait this short would end in the middle of the event: it is skipped rather than cut off.
	controller._timer = 1.0
	ambience._plan()
	assert_eq(ambience.pending_delay(), -1.0)
	for i in 90:
		ambience.tick(DT)
	assert_false(ambience.is_active())
	_free(parts)

func test_pulling_the_line_back_clears_the_planned_event() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var ambience: WaitAmbience = parts[2]
	_to_wait(controller, "riffle")
	assert_true(ambience.pending_delay() > 0.0)
	controller.tap()  # the player pulls the line back
	assert_eq(controller.state, FishingController.State.READY)
	assert_eq(ambience.pending_delay(), -1.0, "a cancelled cast keeps no event")
	for i in 90:
		ambience.tick(DT)
	assert_false(ambience.is_active())
	_free(parts)

func test_still_reedy_water_gets_the_frog() -> void:
	var ambience := WaitAmbience.new()
	assert_eq(ambience.kind_for("riffle"), "leap")
	assert_eq(ambience.kind_for("open_water"), "leap")
	assert_eq(ambience.kind_for("pool"), "frog")
	assert_eq(ambience.kind_for("reed"), "frog")
	assert_eq(ambience.kind_for("lagoon"), "frog")
	ambience.free()

func test_reduced_motion_keeps_the_event_and_drops_the_arc() -> void:
	GameState.set_setting("reduced_motion", true)
	var parts := _make()
	var controller: FishingController = parts[0]
	var ambience: WaitAmbience = parts[2]
	_to_wait(controller, "riffle")
	var elapsed := 0.0
	while elapsed < 3.0 and not ambience.is_active():
		ambience.tick(DT)
		elapsed += DT
	assert_true(ambience.is_active(), "the event still happens")
	assert_true(ambience.reduced_motion, "only the ring on the water is drawn")
	ambience._clear()
	_free(parts)
	GameState.set_setting("reduced_motion", false)
