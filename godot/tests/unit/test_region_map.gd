extends TestCase

## P1-010: which regions are open (derived from progress, never stored) and the region map screen.

const R1 := "region_01_quiet_pond"
const R2 := "region_02_forest_stream"
const R3 := "region_03_reed_river"

func _meet_species(region_id: String, count: int) -> void:
	var met := 0
	for fish_def in ContentDB.get_fish_for_region(region_id):
		if met >= count:
			return
		GameState.record_encounter(fish_def["id"], float(fish_def["size_cm"]["min"]))
		met += 1

func _restore(region_id: String, level: int) -> void:
	GameState.add_restoration_points(region_id, 100000)
	GameState.set_restoration_level(region_id, level)

func test_only_the_start_region_is_open_at_first() -> void:
	GameState.new_game()
	var unlocks := RegionUnlocks.new(GameState)
	assert_true(unlocks.is_unlocked(R1))
	for region_id in ContentDB.regions:
		if region_id != R1:
			assert_false(unlocks.is_unlocked(region_id), "%s must start locked" % region_id)
	assert_eq(unlocks.state_of(R1, R1), RegionUnlocks.CURRENT)
	assert_eq(unlocks.state_of(R2, R1), RegionUnlocks.LOCKED)

func test_a_region_opens_with_its_neighbours_restoration_and_species() -> void:
	GameState.new_game()
	var unlocks := RegionUnlocks.new(GameState)
	var need := unlocks.condition_of(R2)
	assert_eq(need["region"], R1)
	_restore(R1, int(need["level"]))
	assert_false(unlocks.is_unlocked(R2), "restoration alone is not enough")
	_meet_species(R1, int(need["fish"]) - 1)
	assert_false(unlocks.is_unlocked(R2))
	assert_eq(unlocks.condition_of(R2)["fish_now"], int(need["fish"]) - 1, "progress is reported")
	_meet_species(R1, int(need["fish"]))
	assert_true(unlocks.is_unlocked(R2))
	assert_eq(unlocks.state_of(R2, R1), RegionUnlocks.COMING, "open, its world arrives with P2")
	assert_false(unlocks.is_unlocked(R3), "the next region waits for this one's own progress")
	GameState.new_game()

func test_the_map_shows_every_island_and_says_what_each_needs() -> void:
	GameState.new_game()
	var panel := RegionMapPanel.new()
	panel.size = Vector2(720, 1280)
	tree.root.add_child(panel)
	panel.setup(RegionUnlocks.new(GameState), R1)
	panel.refresh()
	assert_eq(panel.sign_count(), ContentDB.regions.size())
	for region_id in ContentDB.regions:
		var button: Button = panel._signs[region_id].get_child(0)
		assert_true(button.get_combined_minimum_size().y >= UiTheme.TOUCH_MIN_PX, "%s sign is a full touch target" % region_id)
	assert_true(panel.tap(R1).contains(String(TranslationServer.translate("region.quiet_pond.name"))))
	var locked_text := panel.tap(R2)
	assert_true(locked_text.contains(String(TranslationServer.translate("region.quiet_pond.name"))), locked_text)
	assert_eq(panel.note_text(), locked_text, "the answer shows on the map itself: the toast is under this screen")
	panel.refresh()
	assert_eq(panel.note_text(), "", "a fresh visit starts without an old answer")
	panel.free()

func test_the_region_pill_opens_the_map() -> void:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	var was_blocked: bool = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load("res://world/game_root.tscn") as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	root.ui.hud.map_pressed.emit()
	assert_eq(root.ui.current_panel(), root.ui.map_panel)
	root.ui.hud.map_pressed.emit()
	assert_false(root.ui.is_panel_open(), "the pill toggles the map")
	root.free()
	save_service.write_blocked = was_blocked
