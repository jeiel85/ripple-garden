extends TestCase

## P0-011..P0-016: the fishing state machine end to end — cast, wait, bite timing, hook window
## (normal / relaxed / auto), fight, catch, inspect and release.

const DT := 1.0 / 30.0
const WATER := Vector2(360, 600)

var _states: Array = []
var _events: Array = []

func _make(seed_value: int = 1) -> Array:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	var controller := FishingController.new()
	controller.game_state = state
	controller.set_seed(seed_value)
	controller.context_provider = func() -> Dictionary: return {"time_band": "day", "weather_id": "clear"}
	_states = []
	controller.state_changed.connect(func(_previous: int, current: int) -> void: _states.append(current))
	return [controller, state]

func _free(parts: Array) -> void:
	parts[0].free()
	parts[1].free()

func _until(controller: FishingController, target: int, max_seconds: float = 90.0) -> float:
	var elapsed := 0.0
	while controller.state != target and elapsed < max_seconds:
		controller.advance(DT)
		elapsed += DT
	return elapsed

## Plays the whole attempt like an attentive player and returns when the controller is READY again.
func _play(controller: FishingController, max_seconds: float = 180.0) -> void:
	var elapsed := 0.0
	while elapsed < max_seconds:
		match controller.state:
			FishingController.State.HOOK:  # waits for the window to open, like a player reacting to the bite
				controller.tap()
			FishingController.State.FIGHT:
				controller.set_reeling(controller.fight.tension < 0.5)
			FishingController.State.INSPECT:
				controller.release_catch()
			FishingController.State.READY:
				if elapsed > 0.0:
					return
		controller.advance(DT)
		elapsed += DT

func _record(signal_to_watch: Signal) -> Array:
	var seen: Array = []
	signal_to_watch.connect(func(a: Variant = null, b: Variant = null, c: Variant = null) -> void: seen.append([a, b, c]))
	return seen

# --- state machine ---

func test_transition_table_covers_every_state() -> void:
	for state_value in FishingController.State.values():
		assert_true(FishingController.TRANSITIONS.has(state_value), "no transitions for %s" % FishingController.State.keys()[state_value])
	# The flow in GDD §7 is reachable edge by edge.
	var flow := [
		FishingController.State.READY, FishingController.State.AIM, FishingController.State.CAST,
		FishingController.State.WAIT, FishingController.State.BITE_HINT, FishingController.State.HOOK,
		FishingController.State.FIGHT, FishingController.State.LAND, FishingController.State.INSPECT,
		FishingController.State.RELEASE, FishingController.State.READY,
	]
	for i in flow.size() - 1:
		assert_true(flow[i + 1] in FishingController.TRANSITIONS[flow[i]], "missing edge %d -> %d" % [flow[i], flow[i + 1]])

func test_illegal_transitions_are_refused() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	expect_engine_error("illegal transition READY -> FIGHT")
	assert_false(controller._enter(FishingController.State.FIGHT))
	assert_eq(controller.state, FishingController.State.READY)
	assert_true(controller._enter(FishingController.State.AIM))
	expect_engine_error("illegal transition AIM -> HOOK")
	assert_false(controller._enter(FishingController.State.HOOK))
	_free(parts)

func test_full_attempt_walks_every_state_in_order_and_pays_out() -> void:
	var parts := _make(5)
	var controller: FishingController = parts[0]
	var state: Node = parts[1]
	var released := _record(EventBus.fish_released)
	var caught := _record(EventBus.fish_caught)
	assert_true(controller.begin_aim())
	assert_true(controller.cast(WATER, "shallow"))
	_play(controller)
	assert_eq(controller.state, FishingController.State.READY)
	var S := FishingController.State
	assert_deep_eq(_states, [S.AIM, S.CAST, S.WAIT, S.BITE_HINT, S.HOOK, S.FIGHT, S.LAND, S.INSPECT, S.RELEASE, S.READY])
	assert_eq(caught.size(), 1)
	assert_eq(released.size(), 1)
	var fish_id: String = caught[0][0]
	assert_true(state.has_discovered(fish_id))
	assert_eq(state.get_collection_record(fish_id)["releases"], 1)
	assert_eq(state.get_population("region_01_quiet_pond", fish_id), 1)
	assert_true(state.get_ripple() > 0)
	assert_true(state.get_restoration_points("region_01_quiet_pond") > 0)
	assert_deep_eq(state.get_pending_catch(), {}, "pending catch must be cleared after release")
	assert_not_null(controller.last_reward)
	_free(parts)

func test_state_changes_are_announced_on_the_event_bus() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var transitions := _record(EventBus.fishing_state_changed)
	controller.cast(WATER, "shallow")
	assert_deep_eq(transitions[0].slice(0, 2), ["ready", "cast"])
	_until(controller, FishingController.State.BITE_HINT)
	assert_deep_eq(transitions.back().slice(0, 2), ["wait", "bite_hint"])
	_free(parts)

# --- cast ---

func test_cast_into_land_or_empty_habitat_is_rejected() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var rejections := _record(controller.cast_rejected)
	assert_false(controller.cast(WATER, ""))
	assert_false(controller.cast(WATER, "lagoon"))
	assert_eq(controller.state, FishingController.State.READY)
	assert_eq(rejections.size(), 2)
	assert_eq(rejections[0][0], "no_fish_here")
	_free(parts)

func test_rejected_cast_from_aim_returns_to_ready() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	controller.begin_aim()
	assert_false(controller.cast(WATER, ""))
	assert_eq(controller.state, FishingController.State.READY)
	_free(parts)

func test_cast_while_busy_is_rejected() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var rejections := _record(controller.cast_rejected)
	controller.cast(WATER, "shallow")
	assert_false(controller.cast(WATER, "shallow"))
	assert_eq(rejections.back()[0], "busy")
	assert_eq(controller.state, FishingController.State.CAST)
	_free(parts)

func test_cast_duration_and_landing_event() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var landed := _record(EventBus.cast_landed)
	controller.cast(Vector2(300, 500), "vegetation")
	var cast_time := _until(controller, FishingController.State.WAIT)
	var range_def: Dictionary = ContentDB.balance["fishing"]["cast_sec"]
	assert_true(cast_time >= range_def["min"] - DT and cast_time <= range_def["max"] + DT, "cast took %.2fs" % cast_time)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0][0], Vector2(300, 500))
	assert_eq(landed[0][1], "vegetation")
	_free(parts)

# --- bite timing ---

func test_wait_respects_floor_and_rod_speed() -> void:
	for rod_id in ["rod_bamboo", "rod_light", "rod_long"]:
		var parts := _make(3)
		var controller: FishingController = parts[0]
		parts[1].grant_rod(rod_id)
		parts[1].equip_rod(rod_id)
		var wait: Dictionary = ContentDB.balance["fishing"]["wait_sec"]
		var speed: float = ContentDB.get_rod(rod_id)["bite_speed"]
		for attempt in 12:
			controller.cast(WATER, "shallow")
			_until(controller, FishingController.State.WAIT)
			var waited := _until(controller, FishingController.State.BITE_HINT)
			assert_true(waited >= wait["floor"] - DT, "%s waited only %.2fs" % [rod_id, waited])
			assert_true(waited <= wait["max"] / speed + DT * 2, "%s waited %.2fs" % [rod_id, waited])
			controller.cancel()
		_free(parts)

func test_bite_hint_is_announced_before_the_hook_window() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var hints := _record(EventBus.bite_hinted)
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.BITE_HINT)
	assert_eq(hints.size(), 1)
	var hint_time := _until(controller, FishingController.State.HOOK)
	var hint_range: Dictionary = ContentDB.balance["fishing"]["bite_hint_sec"]
	assert_true(hint_time >= hint_range["min"] - DT and hint_time <= hint_range["max"] + DT, "hint lasted %.2fs" % hint_time)
	_free(parts)

func test_tapping_while_waiting_pulls_the_line_back_without_penalty() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var cancelled := _record(EventBus.fishing_cancelled)
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.WAIT)
	assert_true(controller.tap())
	assert_eq(controller.state, FishingController.State.READY)
	assert_eq(cancelled.size(), 1)
	assert_true(controller._miss_counts.is_empty())
	assert_false(controller.tap(), "tap in READY does nothing")
	_free(parts)

# --- hook window ---

func test_hook_window_matches_normal_and_relaxed_settings() -> void:
	for relaxed in [false, true]:
		var parts := _make(2)
		var controller: FishingController = parts[0]
		parts[1].set_setting("relaxed_hook", relaxed)
		var key := "hook_window_relaxed_sec" if relaxed else "hook_window_sec"
		var window: Dictionary = ContentDB.balance["fishing"][key]
		for attempt in 8:
			controller.cast(WATER, "shallow")
			_until(controller, FishingController.State.HOOK)
			var open_for := _until(controller, FishingController.State.READY)
			assert_true(open_for >= window["min"] - DT and open_for <= window["max"] + DT,
				"relaxed=%s window %.2fs outside %s" % [relaxed, open_for, window])
		_free(parts)

func test_missing_the_hook_window_lets_the_fish_go_gently() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var escaped := _record(EventBus.fish_escaped)
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.HOOK)
	_until(controller, FishingController.State.READY)
	assert_eq(escaped.size(), 1)
	assert_eq(escaped[0][1], "missed_hook")
	assert_eq(parts[1].discovered_count(), 0, "a miss must not touch the journal")
	assert_eq(parts[1].get_ripple(), 0)
	_free(parts)

func test_auto_hook_starts_the_fight_without_input() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	parts[1].set_setting("auto_hook", true)
	var hooked := _record(EventBus.fish_hooked)
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.FIGHT)
	assert_eq(controller.state, FishingController.State.FIGHT)
	assert_eq(hooked.size(), 1)
	assert_true(FishingController.State.HOOK in _states, "HOOK must still be passed through")
	_free(parts)

func test_hooking_early_during_the_bite_hint_is_accepted() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.BITE_HINT)
	assert_true(controller.tap())
	assert_eq(controller.state, FishingController.State.FIGHT)
	_free(parts)

# --- fight outcomes ---

func test_losing_the_fight_has_no_permanent_cost_and_rare_misses_feed_pity() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var escaped := _record(EventBus.fish_escaped)
	controller.spawn_fish("fish_snakehead")  # rarity 5
	controller.cast(WATER, "vegetation")
	_until(controller, FishingController.State.BITE_HINT)
	controller.tap()
	controller.set_reeling(false)  # never reel: the line goes slack
	_until(controller, FishingController.State.READY)
	assert_eq(escaped.size(), 1)
	assert_eq(escaped[0][1], "line_slack")
	assert_eq(controller._miss_counts.get("fish_snakehead", 0), 1)
	assert_eq(parts[1].discovered_count(), 0)

	controller.spawn_fish("fish_snakehead")
	controller.cast(WATER, "vegetation")
	_until(controller, FishingController.State.BITE_HINT)
	controller.tap()
	controller.set_reeling(true)  # always reel: the line snaps
	_until(controller, FishingController.State.READY)
	assert_eq(escaped[1][1], "line_snapped")
	assert_eq(controller._miss_counts["fish_snakehead"], 2)
	_free(parts)

func test_common_fish_misses_do_not_build_pity_and_success_resets_it() -> void:
	var parts := _make(4)
	var controller: FishingController = parts[0]
	controller.spawn_fish("fish_crucian_carp")  # rarity 1
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.HOOK)
	_until(controller, FishingController.State.READY)  # missed hook
	assert_false(controller._miss_counts.has("fish_crucian_carp"), "tier 1 misses must not count")

	controller._miss_counts["fish_snakehead"] = 3
	controller.spawn_fish("fish_snakehead")
	controller.cast(WATER, "vegetation")
	_play(controller)
	assert_true(parts[1].has_discovered("fish_snakehead"), "steady play lands the rare fish")
	assert_false(controller._miss_counts.has("fish_snakehead"), "catching the fish must reset its pity")
	_free(parts)

func test_cancel_during_fight_gives_up_without_penalty() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	controller.spawn_fish("fish_snakehead")
	controller.cast(WATER, "vegetation")
	_until(controller, FishingController.State.BITE_HINT)
	controller.tap()
	assert_eq(controller.state, FishingController.State.FIGHT)
	assert_true(controller.cancel())
	assert_eq(controller.state, FishingController.State.READY)
	assert_true(controller._miss_counts.is_empty())
	_free(parts)

func test_fight_updates_are_streamed_to_the_view() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var updates := _record(controller.fight_updated)
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.BITE_HINT)
	controller.tap()
	for i in 10:
		controller.advance(DT)
	assert_eq(updates.size(), 10)
	assert_true(updates[0][0] >= 0.0 and updates[0][0] <= 1.0)
	_free(parts)

# --- catch, inspect, release ---

func test_catch_is_recorded_before_release_and_survives_a_restart() -> void:
	var parts := _make(6)
	var controller: FishingController = parts[0]
	var state: Node = parts[1]
	controller.cast(WATER, "shallow")
	var elapsed := 0.0
	while controller.state != FishingController.State.INSPECT and elapsed < 120.0:
		if controller.state in [FishingController.State.BITE_HINT, FishingController.State.HOOK]:
			controller.tap()
		if controller.state == FishingController.State.FIGHT:
			controller.set_reeling(controller.fight.tension < 0.5)
		controller.advance(DT)
		elapsed += DT
	assert_eq(controller.state, FishingController.State.INSPECT)
	var pending: Dictionary = state.get_pending_catch()
	assert_false(pending.is_empty(), "the catch must be saved while inspecting")
	assert_true(state.has_discovered(pending["fish_id"]), "discovery is recorded as soon as the fish is landed")
	assert_eq(state.get_collection_record(pending["fish_id"])["releases"], 0)

	# "Restart": a fresh controller on the same state resumes at INSPECT and can release.
	var next_run := FishingController.new()
	next_run.game_state = state
	assert_true(next_run.resume_pending_catch())
	assert_eq(next_run.state, FishingController.State.INSPECT)
	assert_true(next_run.release_catch())
	assert_deep_eq(state.get_pending_catch(), {})
	assert_eq(state.get_collection_record(pending["fish_id"])["releases"], 1)
	next_run.free()
	_free(parts)

func test_resume_without_pending_catch_does_nothing() -> void:
	var parts := _make()
	assert_false(parts[0].resume_pending_catch())
	assert_eq(parts[0].state, FishingController.State.READY)
	_free(parts)

func test_release_is_only_possible_while_inspecting() -> void:
	var parts := _make()
	assert_false(parts[0].release_catch())
	parts[0].cast(WATER, "shallow")
	assert_false(parts[0].release_catch())
	_free(parts)

func test_there_is_no_way_to_sell_or_keep_a_fish() -> void:
	var controller := FishingController.new()
	for forbidden in ["sell", "sell_catch", "keep", "keep_catch", "discard"]:
		assert_false(controller.has_method(forbidden), "controller must not offer %s" % forbidden)
	controller.free()

func test_spawn_fish_forces_the_next_bite_and_rejects_unknown_ids() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	assert_false(controller.spawn_fish("fish_does_not_exist"))
	assert_true(controller.spawn_fish("fish_bluegill"))
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.BITE_HINT)
	assert_eq(controller.encounter.fish_id, "fish_bluegill")
	controller.cancel()
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.BITE_HINT)
	assert_true(controller.encounter != null, "the forced fish applies to one bite only")
	_free(parts)

func test_same_seed_reproduces_the_same_attempt() -> void:
	var results: Array = []
	for run in 2:
		var parts := _make(99)
		var controller: FishingController = parts[0]
		controller.cast(WATER, "shallow")
		var seconds := _until(controller, FishingController.State.BITE_HINT)
		results.append([controller.encounter.fish_id, controller.encounter.size_cm, snappedf(seconds, 0.001)])
		_free(parts)
	assert_deep_eq(results[0], results[1])

func test_context_provider_feeds_the_resolver() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	var calls: Array = []
	controller.context_provider = func() -> Dictionary:
		calls.append(true)
		return {"time_band": "night", "weather_id": "rain"}
	controller.cast(WATER, "shallow")
	_until(controller, FishingController.State.WAIT)
	assert_eq(calls.size(), 1, "context is read once per cast")
	_free(parts)

func test_a_long_frame_can_cross_several_state_boundaries() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	controller.cast(WATER, "shallow")
	controller.advance(1.5)   # finishes the cast
	assert_eq(controller.state, FishingController.State.WAIT)
	controller.advance(40.0)  # far longer than wait + hint + hook window
	assert_eq(controller.state, FishingController.State.READY, "the missed hook must resolve inside one long frame")
	_free(parts)

func test_landing_and_releasing_both_request_a_save() -> void:
	var parts := _make(6)
	var controller: FishingController = parts[0]
	var saves: Array = []
	controller.save_hook = func() -> void: saves.append(controller.state)
	controller.cast(WATER, "shallow")
	var elapsed := 0.0
	while controller.state != FishingController.State.INSPECT and elapsed < 120.0:
		if controller.state == FishingController.State.HOOK:
			controller.tap()
		if controller.state == FishingController.State.FIGHT:
			controller.set_reeling(controller.fight.tension < 0.5)
		controller.advance(DT)
		elapsed += DT
	assert_eq(saves.size(), 1, "the catch must be saved as soon as the fish is landed")
	assert_eq(saves[0], FishingController.State.FIGHT, "the save is requested at the moment of landing, before the animation")
	assert_true(controller.release_catch())
	assert_eq(saves.size(), 2, "releasing saves the rewards too")
	_free(parts)

func test_a_controller_without_a_save_hook_never_saves() -> void:
	var parts := _make(7)
	assert_false(parts[0].save_hook.is_valid(), "tests must never write the player's save")
	_free(parts)

func test_begin_aim_is_idempotent_and_refused_outside_ready() -> void:
	var parts := _make()
	var controller: FishingController = parts[0]
	assert_true(controller.begin_aim())
	assert_true(controller.begin_aim(), "a repeated press while aiming is fine")
	assert_eq(controller.state, FishingController.State.AIM)
	controller.cast(WATER, "shallow")
	assert_false(controller.begin_aim(), "no aiming while a line is out")
	assert_eq(controller.state, FishingController.State.CAST)
	_free(parts)
