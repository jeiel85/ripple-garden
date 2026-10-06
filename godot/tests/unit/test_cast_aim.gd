extends TestCase

## P0-012: drag-to-aim cast geometry and P0-013 haptic feedback hooks.

const ORIGIN := Vector2(360, 1000)

func _aim() -> CastAim:
	return CastAim.new(ORIGIN, 150.0, 600.0)

func test_landing_is_clamped_to_the_rods_reach() -> void:
	var aim := _aim()
	var far := aim.landing_for(ORIGIN + Vector2(0, -2000))
	assert_true(absf(far.distance_to(ORIGIN) - 600.0) < 0.01, "far drag clamped to max reach")
	var near := aim.landing_for(ORIGIN + Vector2(0, -20))
	assert_true(absf(near.distance_to(ORIGIN) - 150.0) < 0.01, "short drag clamped to min reach")
	var middle := aim.landing_for(ORIGIN + Vector2(0, -300))
	assert_true(absf(middle.distance_to(ORIGIN) - 300.0) < 0.01, "in-range drag is kept")

func test_landing_never_points_backwards() -> void:
	var aim := _aim()
	for pointer in [ORIGIN + Vector2(0, 200), ORIGIN + Vector2(500, 0), ORIGIN + Vector2(-500, 40)]:
		var landing := aim.landing_for(pointer)
		assert_true(landing.y < ORIGIN.y, "landing %s is not in front of the rod" % landing)
		var angle := rad_to_deg(absf(Vector2.UP.angle_to(landing - ORIGIN)))
		assert_true(angle <= CastAim.MAX_ANGLE_DEG + 0.01, "angle %.1f exceeds the cone" % angle)

func test_pointer_on_the_origin_aims_straight_ahead() -> void:
	var landing := _aim().landing_for(ORIGIN)
	assert_true(absf(landing.x - ORIGIN.x) < 0.01 and landing.y < ORIGIN.y)

func test_aim_direction_follows_the_pointer() -> void:
	var aim := _aim()
	assert_true(aim.landing_for(ORIGIN + Vector2(200, -300)).x > ORIGIN.x)
	assert_true(aim.landing_for(ORIGIN + Vector2(-200, -300)).x < ORIGIN.x)

func test_dragging_back_onto_the_rod_cancels() -> void:
	var aim := _aim()
	assert_true(aim.is_cancel(ORIGIN + Vector2(10, 10)))
	assert_false(aim.is_cancel(ORIGIN + Vector2(0, -300)))

func test_tiny_drags_are_taps() -> void:
	assert_true(CastAim.is_tap(Vector2(100, 100), Vector2(110, 105)))
	assert_false(CastAim.is_tap(Vector2(100, 100), Vector2(100, 200)))

func test_quick_cast_reuses_the_last_landing_or_a_sensible_default() -> void:
	var aim := _aim()
	var default_point := aim.quick_cast_point(null)
	assert_true(default_point.y < ORIGIN.y and absf(default_point.x - ORIGIN.x) < 0.01)
	var remembered := Vector2(300, 500)
	assert_eq(aim.quick_cast_point(remembered), aim.landing_for(remembered))

func test_longer_rods_reach_further() -> void:
	var bamboo := CastAim.reach_for_rod(ContentDB.get_rod("rod_bamboo")["range"], 150.0, 600.0)
	var long_rod := CastAim.reach_for_rod(ContentDB.get_rod("rod_long")["range"], 150.0, 600.0)
	assert_true(long_rod > bamboo)
	assert_eq(CastAim.reach_for_rod(-1.0, 150.0, 600.0), 150.0)
	assert_eq(CastAim.reach_for_rod(5.0, 150.0, 600.0), 600.0)

# --- feedback ---

func _feedback(haptics: bool) -> Array:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	state.set_setting("haptics", haptics)
	var feedback := FishingFeedback.new()
	feedback.game_state = state
	var pulses: Array = []
	feedback.haptic_sink = func(duration_ms: int) -> void: pulses.append(duration_ms)
	return [feedback, state, pulses]

func test_pulses_fire_for_bite_hook_and_catch_when_haptics_are_on() -> void:
	var parts := _feedback(true)
	assert_true(parts[0].pulse("bite_hinted"))
	assert_true(parts[0].pulse("fish_hooked"))
	assert_true(parts[0].pulse("fish_caught"))
	assert_deep_eq(parts[2], [25, 45, 70])
	parts[0].free()
	parts[1].free()

func test_haptics_setting_silences_every_pulse() -> void:
	var parts := _feedback(false)
	assert_false(parts[0].pulse("bite_hinted"))
	assert_false(parts[0].pulse("fish_caught"))
	assert_true(parts[2].is_empty())
	parts[0].free()
	parts[1].free()

func test_failures_and_unknown_events_never_buzz() -> void:
	var parts := _feedback(true)
	assert_false(parts[0].pulse("fish_escaped"), "an escaped fish must stay quiet")
	assert_false(parts[0].pulse("nonsense"))
	assert_true(parts[2].is_empty())
	parts[0].free()
	parts[1].free()
