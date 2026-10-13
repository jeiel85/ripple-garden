extends TestCase

## D-035: travelling between open regions. The saved region is built when it can still be visited, the
## map offers "떠나기" for an open region with a world, and every region with a world (the forest valley,
## the reed river) is a whole, fishable world with its own sounds and signature moment. Runs the real scene headless on the autoload GameState with saving blocked.

const SCENE := "res://world/game_root.tscn"
const R1 := "region_01_quiet_pond"
const R2 := "region_02_forest_stream"
const R3 := "region_03_reed_river"
const R4 := "region_04_blue_coast"
## A region whose world has not arrived yet.
const NO_WORLD := "region_05_moonlight_isle"
const DT := 1.0 / 30.0

var _was_blocked := false

func _open_r2() -> void:
	var condition: Dictionary = RegionUnlocks.entry(R2)["condition"]
	GameState.add_restoration_points(R1, 100000)
	GameState.set_restoration_level(R1, int(condition["restoration_level"]))
	for fish_def in ContentDB.get_fish_for_region(R1):
		GameState.record_encounter(fish_def["id"], float(fish_def["size_cm"]["min"]))

func _start() -> GameRoot:
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

func test_a_new_game_and_an_old_save_start_in_the_start_region() -> void:
	GameState.new_game()
	assert_eq(GameState.get_current_region(), "")
	assert_eq(RegionUnlocks.start_region(), R1)
	assert_eq(GameRoot.pick_region(GameState), R1)

func test_a_saved_region_is_used_only_while_it_can_be_visited() -> void:
	GameState.new_game()
	GameState.set_current_region(R2)
	assert_eq(GameRoot.pick_region(GameState), R1, "a locked region is never built")
	_open_r2()
	assert_eq(GameRoot.pick_region(GameState), R2)
	GameState.set_current_region(NO_WORLD)
	assert_eq(GameRoot.pick_region(GameState), R1, "a region without a world falls back to the start")
	GameState.set_current_region("region_99_gone")
	assert_eq(GameRoot.pick_region(GameState), R1, "an unknown id falls back to the start")
	GameState.new_game()

func test_the_current_region_survives_a_save_round_trip_and_bad_values() -> void:
	var save := SaveSchema.default_save(1000)
	save["profile"]["current_region"] = R2
	assert_eq(SaveSchema.normalize(JSON.parse_string(JSON.stringify(save)), 1000)["profile"]["current_region"], R2)
	save["profile"]["current_region"] = 42
	assert_eq(SaveSchema.normalize(save, 1000)["profile"]["current_region"], "")
	save["profile"].erase("current_region")
	assert_eq(SaveSchema.normalize(save, 1000)["profile"]["current_region"], "", "a save from before travelling")
	assert_true(SaveSchema.validate(SaveSchema.normalize(save, 1000)).is_empty())

## Opens `region_id` the way a player would: every region before it on the unlock chain restored and
## all its fish met.
func _open_up_to(region_id: String) -> void:
	var previous: String = RegionUnlocks.entry(region_id)["condition"].get("region", "")
	if previous.is_empty():
		return
	_open_up_to(previous)
	GameState.add_restoration_points(previous, 100000)
	GameState.set_restoration_level(previous, 10)
	for fish_def in ContentDB.get_fish_for_region(previous):
		GameState.record_encounter(fish_def["id"], float(fish_def["size_cm"]["min"]))

## Regions other than the start one whose world exists (the ones a player can travel to).
func _visited_regions() -> Array:
	return ContentDB.regions.keys().filter(func(id: String) -> bool:
		return id != RegionUnlocks.start_region() and RegionUnlocks.has_world(id))

func test_regions_two_to_four_have_worlds() -> void:
	for region_id in [R2, R3, R4]:
		assert_true(region_id in _visited_regions(), "%s has no world" % region_id)

func test_the_game_builds_each_region_when_the_player_is_there() -> void:
	for region_id in _visited_regions():
		GameState.new_game()
		_open_up_to(region_id)
		GameState.set_current_region(region_id)
		var root := _start()
		assert_eq(root.region_id, region_id)
		assert_eq(root.fishing.region_id, region_id)
		assert_true(root.region.environment.has_scene_art(), "%s painting is missing" % region_id)
		assert_eq(root.ui.hud.region_label.text, tr(ContentDB.get_region(region_id)["name_key"]))
		_stop(root)

func test_every_habitat_of_each_region_can_be_reached_with_the_starting_rod() -> void:
	for region_id in _visited_regions():
		GameState.new_game()
		_open_up_to(region_id)
		GameState.set_current_region(region_id)
		var root := _start()
		var aim := root.ui.world_input.aim()
		var reached := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 4000:
			var direction := aim.forward.rotated(rng.randf_range(-deg_to_rad(CastAim.MAX_ANGLE_DEG), deg_to_rad(CastAim.MAX_ANGLE_DEG)))
			var point := aim.landing_for(aim.origin + direction * rng.randf_range(aim.min_distance, aim.max_distance))
			reached[root.region.habitat_map.habitat_at(point)] = true
		for habitat in ContentDB.get_region(region_id)["habitats"]:
			assert_true(reached.has(habitat), "%s: %s cannot be reached from the angler with the starting rod" % [region_id, habitat])
		_stop(root)

func test_a_whole_attempt_in_each_region_catches_one_of_its_fish() -> void:
	for region_id in _visited_regions():
		GameState.new_game()
		_open_up_to(region_id)
		GameState.set_current_region(region_id)
		var root := _start()
		root.fishing.set_seed(4)
		var caught: Array = []
		var on_catch := func(fish_id: String, _size: float, _first: bool) -> void: caught.append(fish_id)
		EventBus.fish_caught.connect(on_catch)
		var local_fish: Array = ContentDB.get_fish_for_region(region_id).map(func(def: Dictionary) -> String: return def["id"])
		var elapsed := 0.0
		while caught.is_empty() and elapsed < 900.0:
			match root.fishing.state:
				FishingController.State.READY:
					root.ui.world_input.cast_quick()
				FishingController.State.HOOK:
					root.fishing.tap()
				FishingController.State.FIGHT:
					root.fishing.set_reeling(root.fishing.fight.tension < 0.5)
				FishingController.State.INSPECT:
					root.ui.inspect_panel.release_pressed.emit()
			root.fishing.advance(DT)
			elapsed += DT
		EventBus.fish_caught.disconnect(on_catch)
		assert_false(caught.is_empty(), "nothing was caught in %s" % region_id)
		for fish_id in caught:
			assert_true(fish_id in local_fish, "%s is not a fish of %s" % [fish_id, region_id])
		_stop(root)

func test_each_region_has_its_own_soundscape_and_signature_moment() -> void:
	# CONTENT_PLAN §3: a region is not done without a distinct soundscape and a memorable ambient moment.
	var pond_water: String = AmbientMix.for_region(ContentDB.audio, R1)["loops"].filter(func(loop: Dictionary) -> bool: return loop["id"] == "water")[0]["stream"]
	for region_id in _visited_regions():
		var mix := AmbientMix.for_region(ContentDB.audio, region_id)
		var water: String = mix["loops"].filter(func(loop: Dictionary) -> bool: return loop["id"] == "water")[0]["stream"]
		assert_true(water != pond_water, "%s sounds like the pond" % region_id)
		var own_clips: Array = mix["wildlife"]["clips"].filter(func(clip: Dictionary) -> bool: return clip.has("regions"))
		assert_false(own_clips.is_empty(), "%s has no wildlife of its own" % region_id)
		var signature := ContentDB.moments.values().filter(func(moment: Dictionary) -> bool:
			return region_id in moment["when"].get("region", []))
		assert_false(signature.is_empty(), "%s has no signature moment" % region_id)
	for clip in AmbientMix.for_region(ContentDB.audio, R1)["wildlife"]["clips"]:
		assert_false(clip.has("regions"), "%s belongs to another region but sounds at the pond" % clip["id"])

func test_a_signature_moment_happens_only_in_its_region() -> void:
	GameState.new_game()
	var pond := MomentService.new(GameState, R1)
	var river := MomentService.new(GameState, R3)
	for service in [pond, river]:
		service.context_provider = func() -> Dictionary: return {"weather": "clear", "band": "dusk", "water_mind": false}
	GameState.add_restoration_points(R1, 100000)
	GameState.set_restoration_level(R1, 10)
	assert_false("moment_heron_reeds" in pond.check(), "the river's heron appeared at the pond")
	GameState.add_restoration_points(R3, 100000)
	GameState.set_restoration_level(R3, 4)
	assert_true("moment_heron_reeds" in river.check())
	GameState.new_game()

func test_travel_is_refused_while_a_line_is_out_and_to_regions_that_cannot_be_visited() -> void:
	GameState.new_game()
	var root := _start()
	assert_false(root.travel(R2), "a locked region")
	_open_r2()
	assert_false(root.travel(R3), "a region still locked")
	assert_false(root.travel(NO_WORLD), "a region without a world")
	assert_false(root.travel(R1), "where the player already is")
	assert_true(root.ui.world_input.cast_quick())
	assert_false(root.travel(R2), "a line is out")
	assert_eq(GameState.get_current_region(), "")
	root.fishing.cancel()
	assert_true(root.travel(R2))
	assert_eq(GameState.get_current_region(), R2, "the choice is saved for the rebuilt scene")
	_stop(root)

func test_the_map_offers_travel_to_an_open_region_only() -> void:
	GameState.new_game()
	var root := _start()
	var map := root.ui.map_panel
	root.ui._open(map)
	map.tap(R2)
	assert_eq(map.travel_target(), "", "a locked island offers no journey")
	_open_r2()
	map.refresh()
	assert_true(map.tap(R2).contains(tr("region.forest_stream.name")))
	assert_eq(map.travel_target(), R2)
	map.travel_requested.emit(R2)
	assert_eq(GameState.get_current_region(), R2, "떠나기 did not reach the game root")
	map.tap(R1)
	assert_eq(map.travel_target(), "", "the current island offers no journey")
	_stop(root)

func test_the_map_says_why_it_cannot_leave_while_fishing() -> void:
	GameState.new_game()
	_open_r2()
	var root := _start()
	assert_true(root.ui.world_input.cast_quick())
	root.ui._on_travel_requested(R2)
	assert_eq(root.ui.map_panel.note_text(), tr("ui.map.travel_busy"))
	assert_eq(GameState.get_current_region(), "")
	_stop(root)

func test_the_valley_can_be_restored_like_the_pond() -> void:
	GameState.new_game()
	var restoration := RestorationService.new(GameState, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	assert_eq(restoration.max_level(R2), restoration.max_level(R1), "the valley is capped below the pond")
	assert_eq(restoration.max_level(R3), restoration.max_level(R1), "the river is capped below the pond")
	assert_eq(restoration.max_level(R4), restoration.max_level(R1), "the coast is capped below the pond")
	assert_eq(restoration.max_level(NO_WORLD), 0, "a region without a world cannot be restored yet")
	GameState.add_restoration_points(R2, restoration.points_for_level(1))
	assert_true(restoration.can_restore(R2))
	assert_true(restoration.restore(R2))
	assert_eq(GameState.get_restoration_level(R2), 1)
	GameState.new_game()
