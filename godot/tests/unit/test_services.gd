extends TestCase

## The command boundary between the screens and GameState: equipment and tutorial hints.

func _new_state() -> Node:
	var state: Node = load("res://autoload/game_state.gd").new()
	state.new_game()
	return state

func test_loadout_equips_owned_content_only() -> void:
	var state := _new_state()
	var loadout := LoadoutService.new(state)
	assert_true(loadout.equip_rod("rod_light"))
	assert_eq(state.get_equipped_rod(), "rod_light")
	assert_false(loadout.equip_rod("rod_old_master"), "an unowned rod cannot be equipped")
	assert_false(loadout.equip_rod("rod_nonexistent"), "unknown content is refused")
	assert_eq(state.get_equipped_rod(), "rod_light", "a refused command changes nothing")
	assert_true(loadout.equip_bait("bait_worm"))
	assert_false(loadout.equip_bait("bait_squid"))
	assert_false(loadout.equip_bait(""))
	assert_eq(state.get_equipped_bait(), "bait_worm")
	state.free()

func test_loadout_changes_are_announced() -> void:
	var state := _new_state()
	var announced: Array = []
	var handler := func() -> void: announced.append(true)
	EventBus.inventory_changed.connect(handler)
	LoadoutService.new(state).equip_rod("rod_light")
	LoadoutService.new(state).equip_rod("rod_old_master")
	EventBus.inventory_changed.disconnect(handler)
	assert_eq(announced.size(), 1, "only the successful change is an event")
	state.free()

func test_a_hint_is_taken_once_and_stays_seen_across_a_save() -> void:
	var state := _new_state()
	var hints := TutorialHints.new(state, "region_01_quiet_pond")
	assert_true(hints.take("hint_cast"))
	assert_false(hints.take("hint_cast"), "a hint is shown once")
	assert_true(hints.take("hint_hook"), "other hints are independent")
	var reloaded: Node = load("res://autoload/game_state.gd").new()
	reloaded.load_data(JSON.parse_string(JSON.stringify(state.snapshot())))
	assert_false(TutorialHints.new(reloaded, "region_01_quiet_pond").take("hint_cast"), "seen survives a restart")
	reloaded.free()
	state.free()

func test_turning_hints_off_silences_them_without_using_them_up() -> void:
	var state := _new_state()
	state.set_setting("tutorial_hints", false)
	var hints := TutorialHints.new(state, "region_01_quiet_pond")
	assert_false(hints.take("hint_cast"))
	assert_false(state.has_seen_event("region_01_quiet_pond", "hint_cast"), "a silenced hint is not consumed")
	state.set_setting("tutorial_hints", true)
	assert_true(hints.take("hint_cast"), "it is still available once hints are back on")
	state.free()
