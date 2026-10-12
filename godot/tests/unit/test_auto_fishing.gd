extends TestCase

## D-034 auto fishing: hidden until enough species are met, then the game casts, hooks, reels and lets
## the catch go by itself through the same commands a player uses. Runs the real scene headless on the
## autoload GameState with saving blocked (like test_game_root).

const SCENE := "res://world/game_root.tscn"
const DT := 1.0 / 30.0

var _was_blocked := false

func _start() -> GameRoot:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	_was_blocked = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load(SCENE) as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	return root

func _stop(root: GameRoot) -> void:
	root.free()
	GameState.new_game()
	tree.root.get_node("SaveService").write_blocked = _was_blocked

## Meets as many of the region's species as auto fishing asks for.
func _finish_onboarding(root: GameRoot) -> void:
	var needed := int(ContentDB.balance["auto_fishing"]["unlock_species"])
	var species := ContentDB.get_fish_for_region(root.region_id)
	for i in needed:
		GameState.record_encounter(species[i]["id"], 10.0)

## Runs the auto fisher and the controller together for up to `seconds` of game time.
func _run(root: GameRoot, seconds: float, stop_when := Callable()) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		root.ui.auto_fishing.step(DT)
		root.fishing.advance(DT)
		elapsed += DT
		if stop_when.is_valid() and stop_when.call():
			return

func test_auto_fishing_stays_hidden_and_refused_until_the_onboarding_is_over() -> void:
	var root := _start()
	assert_false(AutoFishing.is_available(GameState))
	assert_false(root.ui.hud.auto_button.visible, "the switch shows before it can be used")
	assert_false(root.ui.auto_fishing.set_enabled(true))
	assert_false(root.ui.auto_fishing.enabled)
	_finish_onboarding(root)
	assert_true(AutoFishing.is_available(GameState))
	assert_true(root.ui.hud.auto_button.visible, "meeting the species did not bring the switch")
	_stop(root)

func test_the_game_fishes_by_itself_and_releases_what_it_lands() -> void:
	var root := _start()
	_finish_onboarding(root)
	root.fishing.set_seed(7)
	root.ui.auto_fishing.rng.seed = 7
	var released: Array = []
	var on_release := func(fish_id: String, _region: String, _size: float) -> void: released.append(fish_id)
	EventBus.fish_released.connect(on_release)
	root.ui.toggle_auto_fishing()
	assert_true(root.ui.auto_fishing.enabled)
	assert_true(root.ui.hud.auto_button.button_pressed, "the switch does not show it is on")
	_run(root, 600.0, func() -> bool: return released.size() >= 3)
	EventBus.fish_released.disconnect(on_release)
	assert_true(released.size() >= 3, "only %d fish released in 10 minutes of auto fishing" % released.size())
	assert_true(GameState.get_pending_catch().is_empty(), "a landed fish was left in hand")
	_stop(root)

func test_no_cast_starts_while_a_screen_is_open() -> void:
	var root := _start()
	_finish_onboarding(root)
	root.ui.toggle_auto_fishing()
	root.ui.open_journal()
	_run(root, 10.0)
	assert_eq(root.fishing.state, FishingController.State.READY, "it cast behind the journal")
	root.ui.close_panel()
	_run(root, 5.0)
	assert_true(root.fishing.state != FishingController.State.READY, "it did not cast once the journal closed")
	_stop(root)

func test_turning_it_off_mid_fight_gives_the_line_back() -> void:
	var root := _start()
	_finish_onboarding(root)
	root.fishing.set_seed(3)
	root.ui.toggle_auto_fishing()
	_run(root, 120.0, func() -> bool: return root.fishing.state == FishingController.State.FIGHT and root.fishing.reeling)
	assert_eq(root.fishing.state, FishingController.State.FIGHT, "no fight began")
	root.ui.toggle_auto_fishing()
	assert_false(root.ui.auto_fishing.enabled)
	assert_false(root.fishing.reeling, "the reel is still held after turning auto fishing off")
	root.ui.auto_fishing.step(DT)
	assert_false(root.fishing.reeling, "auto fishing still reels while off")
	_stop(root)

func test_cast_spots_are_on_water_that_holds_fish() -> void:
	var root := _start()
	var auto := root.ui.auto_fishing
	auto.rng.seed = 11
	var habitat_at: Callable = root.region.habitat_map.habitat_at
	for i in 20:
		var spot: Variant = auto.pick_spot(root.ui.world_input.aim(), habitat_at)
		assert_true(spot is Vector2, "no spot found")
		assert_true(root.fishing.can_fish_in(root.region.habitat_map.habitat_at(spot)), "spot %s holds no fish" % str(spot))
	_stop(root)

func test_it_reels_in_the_lower_half_of_the_band_only() -> void:
	assert_true(AutoFishing.should_reel(0.2, 0.3, 0.75))
	assert_true(AutoFishing.should_reel(0.5, 0.3, 0.75))
	assert_false(AutoFishing.should_reel(0.6, 0.3, 0.75))
	assert_false(AutoFishing.should_reel(0.9, 0.3, 0.75))

func test_the_ready_note_is_shown_once_per_save() -> void:
	var root := _start()
	var start_region: String = ContentDB.balance["vertical_slice"]["region_id"]
	assert_false(GameState.has_seen_event(start_region, UIController.AUTO_READY_EVENT))
	_finish_onboarding(root)
	assert_true(GameState.has_seen_event(start_region, UIController.AUTO_READY_EVENT), "the ready note was not shown")
	_stop(root)

func test_the_ready_note_waits_for_a_catch_still_in_hand_at_startup() -> void:
	GameState.new_game()
	var start_region: String = ContentDB.balance["vertical_slice"]["region_id"]
	var species := ContentDB.get_fish_for_region(start_region)
	for i in int(ContentDB.balance["auto_fishing"]["unlock_species"]):
		GameState.record_encounter(species[i]["id"], 10.0)
	GameState.set_pending_catch({"fish_id": species[0]["id"], "region_id": start_region, "size_cm": 10.0, "rarity": 1, "first_discovery": false})
	var save_service: Node = tree.root.get_node("SaveService")
	_was_blocked = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load(SCENE) as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	await tree.process_frame  # the deferred refresh runs after the game root has started
	assert_eq(root.fishing.state, FishingController.State.INSPECT)
	assert_false(GameState.has_seen_event(start_region, UIController.AUTO_READY_EVENT), "the note was used up behind the catch result")
	root.ui.inspect_panel.release_pressed.emit()
	_run(root, 3.0, func() -> bool: return root.fishing.state == FishingController.State.READY)
	assert_true(GameState.has_seen_event(start_region, UIController.AUTO_READY_EVENT), "the note never came after the catch was released")
	_stop(root)
