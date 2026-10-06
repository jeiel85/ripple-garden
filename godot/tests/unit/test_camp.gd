extends TestCase

## P1-002: the camp — anchor slots by the clearing, decorations placed, turned, put away and bought,
## a "new" dot for decorations not looked at yet, and the camp drawn in the world.

const R1 := "region_01_quiet_pond"

func _services() -> Array:
	GameState.new_game()
	var loadout := LoadoutService.new(GameState)
	return [CampService.new(GameState, loadout), loadout]

func test_a_new_game_starts_with_the_starting_camp() -> void:
	var camp: CampService = _services()[0]
	var starting: Dictionary = ContentDB.balance["starting_camp"][R1]
	for slot_id in starting:
		assert_eq(camp.item_in(R1, slot_id), starting[slot_id])
	assert_eq(GameState.get_owned_decorations().size(), ContentDB.balance["starting_inventory"]["decorations"].size())
	assert_eq(SaveSchema.validate(GameState.snapshot()), PackedStringArray())

func test_placing_moves_a_decoration_and_slots_hold_one_each() -> void:
	var camp: CampService = _services()[0]
	var tent_slot := camp.slot_of(R1, "deco_tent")
	assert_true(camp.place(R1, "camp_5", "deco_tent"))
	assert_eq(camp.item_in(R1, "camp_5"), "deco_tent")
	assert_eq(camp.item_in(R1, tent_slot), "", "the tent left its old spot")
	assert_true(camp.place(R1, "camp_5", "deco_lantern"))
	assert_eq(camp.slot_of(R1, "deco_tent"), "", "a slot holds one decoration: the tent was put away")
	camp.turn(R1, "camp_5")
	assert_eq(GameState.get_camp(R1)["camp_5"]["flip"], true)
	camp.remove(R1, "camp_5")
	assert_eq(camp.item_in(R1, "camp_5"), "")

func test_only_owned_decorations_go_into_real_slots() -> void:
	var camp: CampService = _services()[0]
	assert_false(camp.place(R1, "camp_4", "deco_campfire"), "not owned")
	assert_false(camp.place(R1, "nowhere", "deco_tent"), "not a slot of the layout")
	assert_false(camp.place(R1, "camp_4", "deco_spaceship"), "not a decoration")

func test_buying_a_decoration_places_it() -> void:
	var parts := _services()
	var camp: CampService = parts[0]
	assert_false(camp.buy_and_place(R1, "camp_4", "deco_wood_table"), "no Ripple yet")
	GameState.add_ripple(500)
	assert_true(camp.buy_and_place(R1, "camp_4", "deco_wood_table"))
	assert_eq(GameState.get_ripple(), 500 - int(ContentDB.get_decoration("deco_wood_table")["price"]["amount"]))
	assert_eq(camp.item_in(R1, "camp_4"), "deco_wood_table")
	assert_false(camp.buy_and_place(R1, "camp_5", "deco_campfire"), "the campfire waits for stage 2")

func test_the_camp_dot_marks_decorations_not_looked_at() -> void:
	var camp: CampService = _services()[0]
	assert_true(camp.has_news(), "decorations for sale are new at first")
	camp.mark_seen()
	assert_false(camp.has_news())
	GameState.add_restoration_points(R1, 100000)
	GameState.set_restoration_level(R1, 2)
	assert_true(camp.has_news(), "a restored stage brings new decorations to look at")
	camp.mark_seen()
	assert_false(camp.has_news())

func test_saves_from_before_the_camp_get_the_starting_camp() -> void:
	GameState.new_game()
	var old := GameState.snapshot()
	old["inventory"].erase("decorations")
	old["inventory"].erase("decorations_seen")
	for region_id in old["regions"]:
		old["regions"][region_id].erase("camp")
	GameState.load_data(old)
	assert_eq(GameState.get_camp(R1)["camp_1"]["item"], "deco_tent")
	assert_true(GameState.get_owned_decorations().has("deco_lantern"))

func test_a_damaged_camp_keeps_each_decoration_once() -> void:
	var camp := SaveSchema.normalize_camp({"a": {"item": "deco_tent"}, "b": {"item": "deco_tent"}, "c": "junk", "d": {"item": 5}})
	assert_eq(camp.size(), 1)
	assert_true(camp.has("a") or camp.has("b"))

func test_the_world_draws_the_camp() -> void:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	var was_blocked: bool = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load("res://world/game_root.tscn") as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	var kinds: Array = root.region.props.camp_props().map(func(prop: Dictionary) -> String: return prop["kind"])
	assert_true("tent" in kinds and "camp_chair" in kinds)
	root.camp.turn(R1, "camp_1")
	var turned: Array = root.region.props.camp_props().filter(func(prop: Dictionary) -> bool: return prop["kind"] == "tent")
	assert_eq(turned[0]["flip"], true)
	# The camp screen moves the camera in and marks what is there as seen.
	GameState.set_setting("reduced_motion", true)
	root.ui.open_camp()
	assert_eq(root.ui.current_panel(), root.ui.camp_panel)
	assert_true(root.camera.zoom.x > 1.0, "the camera moves in on the camp")
	assert_false(root.camp.has_news())
	root.ui.close_panel()
	assert_eq(root.camera.zoom, Vector2.ONE, "and back out after")
	root.free()
	save_service.write_blocked = was_blocked
	GameState.new_game()

func test_the_camp_screen_buys_through_the_done_button() -> void:
	var parts := _services()
	var camp: CampService = parts[0]
	var panel := CampPanel.new()
	tree.root.add_child(panel)
	panel.setup(camp, parts[1], R1)
	panel.refresh()
	assert_true(panel.card_count() == ContentDB.decorations.size())
	panel.select_slot("camp_4")
	GameState.add_ripple(500)
	panel.choose("deco_signboard")
	assert_eq(panel.pending, "deco_signboard", "a decoration not owned is offered first")
	assert_eq(camp.item_in(R1, "camp_4"), "")
	panel._confirm()
	assert_eq(camp.item_in(R1, "camp_4"), "deco_signboard", "the done button buys and places it")
	panel.choose("deco_lantern")
	assert_eq(camp.item_in(R1, "camp_4"), "deco_lantern", "an owned decoration goes straight in")
	panel.select_tab("placed")
	for decoration_id in panel._card_nodes:
		assert_false(camp.slot_of(R1, decoration_id).is_empty(), "the placed tab shows placed decorations only")
	panel.free()
	GameState.new_game()

func test_the_starting_camp_must_fit_the_layout() -> void:
	var raw: Dictionary = {}
	for category in ContentValidator.FILE_NAMES:
		raw[category] = JSON.parse_string(FileAccess.get_file_as_string("res://data".path_join(ContentValidator.FILE_NAMES[category])))
	raw["balance"]["starting_camp"][R1]["camp_9"] = "deco_tent"
	var errors := "\n".join(ContentValidator.validate(raw)["errors"])
	assert_true(errors.contains("'camp_9' is not a camp slot"), errors)
	assert_true(errors.contains("deco_tent is placed twice"), errors)
