extends TestCase

## P1-008: moments — the first time the world matches a moment it is written into the journal with a
## little Memory; never twice; shown in the journal's Moments tab with a hint until then.

const R1 := "region_01_quiet_pond"

func _service(weather: String = "clear", band: String = "day", water_mind: bool = false) -> MomentService:
	var service := MomentService.new(GameState, R1)
	service.context_provider = func() -> Dictionary: return {"weather": weather, "band": band, "water_mind": water_mind}
	return service

func test_conditions_read_like_their_data() -> void:
	assert_true(MomentService.matches({"weather": ["rain"]}, {"weather": "rain"}))
	assert_false(MomentService.matches({"weather": ["rain"]}, {"weather": "clear"}))
	assert_true(MomentService.matches({"weather": ["mist"], "band": ["dawn", "morning"]}, {"weather": "mist", "band": "morning"}))
	assert_false(MomentService.matches({"weather": ["mist"], "band": ["dawn"]}, {"weather": "mist", "band": "day"}), "every key must hold")
	assert_false(MomentService.matches({"min_level": 5}, {"level": 4}))
	assert_true(MomentService.matches({"caught_rarity": 3}, {"caught_rarity": 4}))
	assert_false(MomentService.matches({"after_away": true}, {}))

func test_a_moment_is_recorded_once_with_its_memory() -> void:
	GameState.new_game()
	var recorded: Array = []
	var handler := func(moment_id: String) -> void: recorded.append(moment_id)
	EventBus.moment_recorded.connect(handler)
	var service := _service("rain")
	assert_true("moment_rain_rings" in service.check())
	assert_eq(GameState.get_memory(), int(ContentDB.moments["moment_rain_rings"]["memory"]))
	assert_true(service.check().is_empty(), "never twice")
	EventBus.moment_recorded.disconnect(handler)
	assert_deep_eq(recorded, ["moment_rain_rings"])
	assert_true(GameState.moment_seen_at("moment_rain_rings") > 0)
	GameState.new_game()

func test_one_off_facts_come_with_the_event() -> void:
	GameState.new_game()
	var service := _service()
	assert_false("moment_rare_meeting" in service.check({"caught_rarity": 2}))
	assert_true("moment_rare_meeting" in service.check({"caught_rarity": 3}))
	assert_true("moment_waiting_pond" in service.check({"after_away": true}))
	GameState.new_game()

func test_restoration_and_camp_moments_follow_the_save() -> void:
	GameState.new_game()
	var service := _service("clear", "night")
	assert_false("moment_firefly_night" in service.check())
	GameState.add_restoration_points(R1, 100000)
	GameState.set_restoration_level(R1, 5)
	assert_true("moment_firefly_night" in service.check())
	var loadout := LoadoutService.new(GameState)
	var camp := CampService.new(GameState, loadout)
	GameState.add_ripple(10000)
	for decoration_id in ["deco_wood_table", "deco_signboard"]:
		for slot in CampService.slots(R1):
			if camp.item_in(R1, slot["id"]).is_empty():
				camp.buy_and_place(R1, slot["id"], decoration_id)
				break
	assert_eq(GameState.get_camp(R1).size(), CampService.slots(R1).size())
	assert_true("moment_cozy_camp" in service.check())
	GameState.new_game()

func test_moments_survive_a_save_round_trip() -> void:
	GameState.new_game()
	GameState.record_moment("moment_sunshower")
	var saved := GameState.snapshot()
	GameState.load_data(JSON.parse_string(JSON.stringify(saved)))
	assert_true(GameState.has_moment("moment_sunshower"))
	assert_eq(SaveSchema.normalize({"moments": {"moment_x": "junk", "moment_y": 5}}, 0)["moments"], {"moment_y": 5})
	GameState.new_game()

func test_the_journal_lists_moments_with_hints_until_seen() -> void:
	GameState.new_game()
	GameState.record_moment("moment_rain_rings")
	var panel := JournalPanel.new()
	tree.root.add_child(panel)
	panel.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), R1)
	panel.select_tab("moments")
	assert_eq(panel.card_count(), ContentDB.moments.size())
	assert_eq(panel._progress.text, String(TranslationServer.translate("ui.journal.progress")) % [1, ContentDB.moments.size()])
	panel._show_moment("moment_sunshower")
	assert_eq(panel._page_line.text, String(TranslationServer.translate("moment.sunshower.hint")), "an unseen moment shows its hint")
	panel._show_moment("moment_rain_rings")
	assert_eq(panel._page_line.text, String(TranslationServer.translate("moment.rain_rings.desc")))
	panel.select_tab("all")
	assert_true(panel._page_portrait.get_parent().visible, "fish pages show their picture again")
	panel.free()
	GameState.new_game()

func test_watching_the_pond_at_night_is_a_moment() -> void:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	var was_blocked: bool = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load("res://world/game_root.tscn") as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	TimeService.set_game_minutes(23.0 * 60.0)
	root.ui.enter_water_mind()
	assert_true(GameState.has_moment("moment_moon_watch"))
	root.ui.water_mind.exit()
	root.free()
	save_service.write_blocked = was_blocked
	GameState.new_game()
