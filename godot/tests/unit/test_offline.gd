extends TestCase

## P1-007: the pond catches up on time away — released fish multiply a little, a small Ripple trickle,
## never a skipped restoration stage — and one short card says what changed.

const R1 := "region_01_quiet_pond"

func _service() -> OfflineService:
	return OfflineService.new(GameState, ContentDB.balance["offline"])

func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_a_short_absence_changes_nothing() -> void:
	GameState.new_game()
	GameState.add_population(R1, "fish_minnow", 3)
	var summary := _service().apply(R1, 5 * 60, _rng())
	assert_true(summary.is_empty())
	assert_eq(GameState.get_population(R1, "fish_minnow"), 3)
	assert_eq(GameState.get_ripple(), 0)

func test_eight_hours_away_grow_the_pond_but_skip_no_stage() -> void:
	GameState.new_game()
	GameState.add_population(R1, "fish_minnow", 3)
	GameState.add_population(R1, "fish_catfish", 1)
	GameState.add_restoration_points(R1, 300)
	GameState.set_restoration_level(R1, 5)
	var points_before := GameState.get_restoration_points(R1)
	var summary := _service().apply(R1, 8 * 3600, _rng())
	var config: Dictionary = ContentDB.balance["offline"]
	assert_eq(summary.fish_added.size(), 2, "every released species grows")
	for fish_id in summary.fish_added:
		assert_true(summary.fish_added[fish_id] >= 1 and summary.fish_added[fish_id] <= int(config["max_fish_per_species"]))
	assert_eq(GameState.get_population(R1, "fish_minnow"), 3 + int(summary.fish_added["fish_minnow"]))
	assert_true(summary.ripple > 0 and summary.ripple <= int(config["max_ripple"]))
	assert_eq(GameState.get_ripple(), summary.ripple)
	assert_eq(GameState.get_restoration_points(R1), points_before, "BALANCE §7: time away never earns a stage")
	assert_eq(GameState.get_restoration_level(R1), 5)
	GameState.new_game()

func test_species_never_released_do_not_appear() -> void:
	GameState.new_game()
	var summary := _service().apply(R1, 12 * 3600, _rng())
	assert_true(summary.fish_added.is_empty(), "nothing was released, so nothing breeds")
	assert_true(summary.ripple > 0, "a small trickle still arrives")

func test_the_same_absence_gives_the_same_summary() -> void:
	var results: Array = []
	for run in 2:
		GameState.new_game()
		GameState.add_population(R1, "fish_minnow", 2)
		var summary := _service().apply(R1, 5 * 3600 + 17, _rng(99))
		results.append([summary.fish_added, summary.ripple])
	assert_deep_eq(results[0], results[1])
	GameState.new_game()

func test_offline_seconds_are_claimed_once() -> void:
	TimeService.claim_offline()
	TimeService._announce_offline(3600)
	assert_eq(TimeService.claim_offline(), 3600)
	assert_eq(TimeService.claim_offline(), 0, "handled once")

func test_returning_shows_one_short_card() -> void:
	GameState.new_game()
	GameState.add_population(R1, "fish_minnow", 2)
	var save_service: Node = tree.root.get_node("SaveService")
	var was_blocked: bool = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load("res://world/game_root.tscn") as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	TimeService.claim_offline()
	TimeService._announce_offline(6 * 3600)  # as if the app came back after six hours
	assert_eq(root.ui.current_panel(), root.ui.away_panel)
	assert_true(root.ui.away_panel.line_count() >= 1)
	root.ui.away_panel.close_pressed.emit()
	assert_false(root.ui.is_panel_open())
	# Coming back while another screen is open: the card waits for it to close instead of being lost.
	root.ui.open_journal()
	TimeService._announce_offline(3 * 3600)
	assert_eq(root.ui.current_panel(), root.ui.journal_panel)
	assert_true(root.ui.has_pending_away())
	root.ui.close_panel()
	assert_eq(root.ui.current_panel(), root.ui.away_panel, "shown once the journal closed")
	root.ui.away_panel.close_pressed.emit()
	# Coming back with a line out: the card waits for the line to come in, so a bite is never hidden.
	root.ui.world_input.cast_quick()
	assert_true(root.fishing.state in [FishingController.State.CAST, FishingController.State.WAIT], "the line is out")
	TimeService._announce_offline(3 * 3600)
	assert_false(root.ui.is_panel_open(), "nothing covers a waiting line")
	root.fishing.cancel()
	assert_eq(root.ui.current_panel(), root.ui.away_panel, "shown when the line is back in")
	root.ui.away_panel.close_pressed.emit()
	root.free()
	save_service.write_blocked = was_blocked
	GameState.new_game()

# Found on the emulator: the title broke after every letter and "Take a look" spilled out of its button.
func test_the_card_lays_out_in_every_language() -> void:
	var previous := TranslationServer.get_locale()
	var summary := OfflineService.Summary.new()
	summary.seconds = 8 * 3600
	summary.fish_added = {"fish_catfish": 2, "fish_minnow": 2}
	summary.ripple = 31
	for locale in ["ko", "en", "ja"]:
		TranslationServer.set_locale(locale)
		var host := Control.new()
		host.size = Vector2(720, 1280)
		host.theme = UiTheme.build(1.0, false, false)
		tree.root.add_child(host)
		var card := AwayPanel.new()
		host.add_child(card)
		card.show_summary(summary)
		await tree.process_frame
		await tree.process_frame
		assert_true(card._title.get_line_count() <= 2, "%s: the title wraps into %d lines" % [locale, card._title.get_line_count()])
		var look: Button = card.find_children("*", "Button", true, false)[0]
		var word: Label = look.get_meta("label")
		assert_true(word.get_global_rect().end.x <= look.get_global_rect().end.x + 1.0, "%s: the button's word spills out" % locale)
		host.free()
	TranslationServer.set_locale(previous)
