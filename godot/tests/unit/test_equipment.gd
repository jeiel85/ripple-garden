extends TestCase

## P1-003 / P1-004 (D-019): rods with grades and character, counted baits carried in a bag, accessories,
## buying with game currency, keepsakes that arrive by themselves, and the bait a bite uses up.

const R1 := "region_01_quiet_pond"

func _fresh() -> LoadoutService:
	GameState.new_game()
	return LoadoutService.new(GameState)

func _restore_to(level: int) -> void:
	GameState.add_restoration_points(R1, 100000)
	GameState.set_restoration_level(R1, level)

# --- starting kit ---

func test_a_new_game_starts_with_a_bag_a_hat_and_some_bait() -> void:
	var loadout := _fresh()
	assert_eq(GameState.get_equipped_bag(), "bag_basic")
	assert_eq(GameState.get_equipped_accessory(), "acc_straw_hat")
	assert_eq(GameState.get_bait_count("bait_worm"), 6)
	assert_eq(loadout.bait_stock("bait_bread"), -1, "dough never runs out")
	assert_true(loadout.carried_baits() <= loadout.bag_capacity(), "the starting stock fits the starting bag")
	assert_true(loadout.free_bag_space() > 0, "there is room to buy a first pack")
	assert_eq(SaveSchema.validate(GameState.snapshot()), PackedStringArray())

func test_saves_from_before_bags_get_the_starting_kit() -> void:
	GameState.new_game()
	var old := GameState.snapshot()
	old["inventory"] = {"rods": ["rod_bamboo"], "baits": ["bait_bread", "bait_worm"], "equipped_rod": "rod_bamboo", "equipped_bait": "bait_worm"}
	GameState.load_data(old)
	assert_eq(GameState.get_equipped_bag(), "bag_basic")
	assert_eq(GameState.get_equipped_accessory(), "acc_straw_hat")
	assert_eq(GameState.get_bait_count("bait_worm"), 6, "owned counted baits get the starting stock")
	assert_eq(GameState.get_bait_count("bait_corn"), 0, "baits not owned get nothing")

func test_a_save_with_counts_keeps_them() -> void:
	GameState.new_game()
	GameState.add_baits("bait_worm", 3)
	var saved := GameState.snapshot()
	GameState.load_data(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(GameState.get_bait_count("bait_worm"), 9)

# --- offers and buying ---

func test_a_rod_is_locked_until_its_stage_then_bought_with_ripple() -> void:
	var loadout := _fresh()
	var deal := loadout.offer("rod", "rod_long")
	assert_eq(deal["state"], LoadoutService.LOCKED)
	assert_eq(deal["region"], R1)
	assert_eq(deal["level"], 2)
	assert_false(loadout.buy("rod", "rod_long"), "a locked rod cannot be bought")
	_restore_to(2)
	assert_eq(loadout.offer("rod", "rod_long")["state"], LoadoutService.TOO_DEAR)
	GameState.add_ripple(200)
	assert_eq(loadout.offer("rod", "rod_long")["state"], LoadoutService.BUY)
	assert_true(loadout.buy("rod", "rod_long"))
	assert_eq(GameState.get_ripple(), 20)
	assert_true(loadout.is_owned("rod", "rod_long"))
	assert_eq(loadout.offer("rod", "rod_long")["state"], LoadoutService.OWNED)
	assert_false(loadout.buy("rod", "rod_long"), "nothing is bought twice")
	assert_eq(GameState.get_ripple(), 20)

func test_memory_items_spend_memory() -> void:
	var loadout := _fresh()
	GameState.add_memory(15)
	assert_eq(loadout.offer("accessory", "acc_bucket_hat")["currency"], "memory")
	assert_true(loadout.buy("accessory", "acc_bucket_hat"))
	assert_eq(GameState.get_memory(), 0)
	assert_true(loadout.equip_accessory("acc_bucket_hat"))

func test_bait_comes_in_packs_that_must_fit_the_bag() -> void:
	var loadout := _fresh()
	GameState.add_ripple(1000)
	var space := loadout.free_bag_space()
	var pack := int(ContentDB.balance["equipment"]["bait_pack_size"])
	var deal := loadout.offer("bait", "bait_worm")
	assert_eq(deal["state"], LoadoutService.BUY)
	assert_eq(deal["pack"], mini(pack, space))
	var before := GameState.get_bait_count("bait_worm")
	assert_true(loadout.buy("bait", "bait_worm"))
	assert_eq(GameState.get_bait_count("bait_worm"), before + deal["pack"])
	while loadout.free_bag_space() > 0:
		assert_true(loadout.buy("bait", "bait_corn"))
	assert_eq(loadout.offer("bait", "bait_corn")["state"], LoadoutService.BAG_FULL)
	assert_false(loadout.buy("bait", "bait_corn"), "a full bag takes no more")
	assert_eq(loadout.carried_baits(), loadout.bag_capacity())

func test_a_partial_pack_costs_its_share() -> void:
	var loadout := _fresh()
	GameState.add_ripple(1000)
	GameState.add_baits("bait_worm", loadout.free_bag_space() - 3)
	var deal := loadout.offer("bait", "bait_corn")
	assert_eq(deal["pack"], 3)
	var full_price := int(ContentDB.get_bait("bait_corn")["price"]["amount"])
	assert_eq(deal["amount"], ceili(full_price * 3.0 / ContentDB.balance["equipment"]["bait_pack_size"]))

func test_a_bigger_bag_makes_room_and_a_small_bag_cannot_hold_too_much() -> void:
	var loadout := _fresh()
	_restore_to(3)
	GameState.add_ripple(2000)
	assert_true(loadout.buy("bag", "bag_leather"))
	assert_true(loadout.equip_bag("bag_leather"))
	assert_eq(loadout.bag_capacity(), 40)
	GameState.add_baits("bait_worm", 30 - loadout.carried_baits())
	assert_false(loadout.equip_bag("bag_basic"), "the basic bag cannot hold 30 baits")
	assert_eq(GameState.get_equipped_bag(), "bag_leather")

# --- keepsakes ---

func test_an_event_rod_is_never_sold_and_arrives_with_its_moment() -> void:
	var loadout := _fresh()
	GameState.add_ripple(100000)
	assert_eq(loadout.offer("rod", "rod_old_master")["state"], LoadoutService.GIFT_LATER)
	assert_false(loadout.buy("rod", "rod_old_master"))
	assert_true(loadout.grant_keepsakes().is_empty(), "nothing before the moment")
	var granted: Array = []
	var handler := func(category: String, item_id: String) -> void: granted.append([category, item_id])
	EventBus.item_granted.connect(handler)
	_restore_to(5)
	var gifts := loadout.grant_keepsakes()
	EventBus.item_granted.disconnect(handler)
	assert_true(["rod", "rod_old_master"] in gifts)
	assert_true(["rod", "rod_old_master"] in granted)
	assert_true(loadout.is_owned("rod", "rod_old_master"))
	assert_true(loadout.grant_keepsakes().is_empty(), "a keepsake arrives once")

func test_restoring_in_the_game_hands_over_the_keepsake() -> void:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	var was_blocked: bool = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load("res://world/game_root.tscn") as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	_restore_to(5)
	assert_true(GameState.get_owned_rods().has("rod_old_master"))
	root.free()
	save_service.write_blocked = was_blocked

# --- equipping and bites ---

func test_an_empty_counted_bait_cannot_be_equipped() -> void:
	var loadout := _fresh()
	assert_true(loadout.equip_bait("bait_worm"))
	while GameState.take_bait("bait_worm"):
		pass
	assert_true(loadout.equip_bait("bait_bread"))
	assert_false(loadout.equip_bait("bait_worm"), "nothing left to put on the hook")

func test_a_bite_uses_one_bait_and_the_last_one_switches_to_dough() -> void:
	var loadout := _fresh()
	loadout.equip_bait("bait_insect")
	var ran_out: Array = []
	var handler := func(bait_id: String, replacement: String) -> void: ran_out.append([bait_id, replacement])
	EventBus.bait_ran_out.connect(handler)
	var stock := GameState.get_bait_count("bait_insect")
	assert_true(loadout.use_bait_for_bite())
	assert_eq(GameState.get_bait_count("bait_insect"), stock - 1)
	while GameState.get_bait_count("bait_insect") > 0:
		loadout.use_bait_for_bite()
	EventBus.bait_ran_out.disconnect(handler)
	assert_eq(GameState.get_equipped_bait(), "bait_bread", "the endless bait takes over")
	assert_deep_eq(ran_out, [["bait_insect", "bait_bread"]])
	assert_false(loadout.use_bait_for_bite(), "dough is never used up")
	assert_eq(GameState.get_equipped_bait(), "bait_bread")

func test_the_fishing_controller_spends_the_bait_when_a_fish_bites() -> void:
	var loadout := _fresh()
	loadout.equip_bait("bait_worm")
	var stock := GameState.get_bait_count("bait_worm")
	var controller := FishingController.new()
	tree.root.add_child(controller)
	controller.loadout = loadout
	controller.set_seed(5)
	controller.spawn_fish("fish_crucian_carp")
	assert_true(controller.cast(Vector2(560, 520), "open_water"))
	var elapsed := 0.0
	while controller.state != FishingController.State.BITE_HINT and elapsed < 60.0:
		controller.advance(0.1)
		elapsed += 0.1
	assert_eq(controller.state, FishingController.State.BITE_HINT)
	assert_eq(GameState.get_bait_count("bait_worm"), stock - 1, "the fish took the bait")
	controller.cancel()
	assert_eq(GameState.get_bait_count("bait_worm"), stock - 1, "cancelling does not give it back")
	controller.free()

func test_an_empty_counted_bait_attracts_nothing_special() -> void:
	var loadout := _fresh()
	loadout.equip_bait("bait_worm")
	var controller := FishingController.new()
	assert_false(controller._bait_tags().is_empty())
	while GameState.take_bait("bait_worm"):
		pass
	assert_true(controller._bait_tags().is_empty())
	controller.free()

# --- rods ---

func test_rod_character_reads_from_its_play_values() -> void:
	var bamboo := LoadoutService.rod_stats(ContentDB.get_rod("rod_bamboo"))
	assert_deep_eq(bamboo, {"control": 43, "sensitivity": 50, "durability": 50})
	for rod_id in ContentDB.rods:
		var stats := LoadoutService.rod_stats(ContentDB.get_rod(rod_id))
		for key in stats:
			assert_true(stats[key] >= 0 and stats[key] <= 100, "%s %s out of range" % [rod_id, key])

func test_no_rod_is_simply_better_than_another() -> void:
	# GDD §12: a different rod, not a stronger one. No rod is at least as good as another in every play value
	# (reach, bite speed, tension assist, line strength) and better in one: a tie is not a trade-off.
	var fields: PackedStringArray = ["range", "bite_speed", "tension_assist", "line_strength"]
	for a in ContentDB.rods:
		for b in ContentDB.rods:
			if a == b:
				continue
			var never_worse := true
			var once_better := false
			for field in fields:
				var va := float(ContentDB.get_rod(a)[field])
				var vb := float(ContentDB.get_rod(b)[field])
				never_worse = never_worse and va >= vb
				once_better = once_better or va > vb
			assert_false(never_worse and once_better, "%s is at least as good as %s at everything" % [a, b])

func test_a_stronger_line_takes_longer_to_snap() -> void:
	var config: Dictionary = ContentDB.balance["fishing"]["fight"].duplicate(true)
	config["hold_target"] = 1.0  # reel past the snap threshold on purpose
	var fish := ContentDB.get_fish("fish_snakehead")
	var behavior := ContentDB.get_behavior(fish["behavior"])
	var times: Array[float] = []
	for strength in [0.0, 1.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var fight := FightSimulation.new(fish, behavior, config, 0.0, rng, strength)
		var elapsed := 0.0
		while fight.result == FightSimulation.Result.ONGOING and elapsed < 30.0:
			fight.step(1.0 / 30.0, true)
			elapsed += 1.0 / 30.0
		assert_eq(fight.result, FightSimulation.Result.SNAPPED, "holding forever snaps the line")
		times.append(elapsed)
	assert_true(times[1] > times[0], "durability buys time (%.2f vs %.2f s)" % [times[1], times[0]])

# --- content rules ---

func test_equipment_content_rules() -> void:
	var raw: Dictionary = {}
	for category in ContentValidator.FILE_NAMES:
		raw[category] = JSON.parse_string(FileAccess.get_file_as_string("res://data".path_join(ContentValidator.FILE_NAMES[category])))
	var rods: Array = raw["rods"]
	for rod in rods:
		if rod["id"] == "rod_old_master":
			rod["price"] = {"currency": "ripple", "amount": 5}
		if rod["id"] == "rod_long":
			rod["grade"] = "event"
	raw["equipment"]["bags"][0]["capacity"] = 1
	raw["balance"]["starting_inventory"]["baits"] = ["bait_worm"]
	raw["balance"]["starting_inventory"]["equipped_bait"] = "bait_worm"
	raw["balance"]["starting_inventory"]["bait_counts"] = {"bait_worm": 6}
	var errors := "\n".join(ContentValidator.validate(raw)["errors"])
	assert_true(errors.contains("never also sold"), errors)
	assert_true(errors.contains("event items (and only they)"), errors)
	assert_true(errors.contains("do not fit the starting bag"), errors)
	assert_true(errors.contains("needs an endless"), errors)

func test_a_version_1_save_from_disk_gets_the_starting_bait_stock() -> void:
	# The real loading path: the migrator normalizes first, so the old-save signal must survive it.
	GameState.new_game()
	var old := GameState.snapshot()
	old["save_version"] = 1
	old["inventory"] = {"rods": ["rod_bamboo"], "baits": ["bait_bread", "bait_worm", "bait_corn"], "equipped_rod": "rod_bamboo", "equipped_bait": "bait_worm"}
	var result := SaveMigrator.new().migrate(JSON.parse_string(JSON.stringify(old)), 0)
	assert_true(result["ok"], result["error"])
	assert_eq(result["save"]["save_version"], SaveSchema.CURRENT_VERSION)
	GameState.load_data(result["save"])
	assert_eq(GameState.get_bait_count("bait_worm"), 6, "owned counted baits get the starting stock")
	assert_eq(GameState.get_bait_count("bait_corn"), 4)
	assert_false(GameState.snapshot()["inventory"].has(SaveMigrator.LEGACY_BAIT_MARKER), "the marker never reaches a written save")
	GameState.new_game()

func test_a_version_2_save_keeps_its_empty_stock() -> void:
	GameState.new_game()
	while GameState.take_bait("bait_worm"):
		pass
	var result := SaveMigrator.new().migrate(JSON.parse_string(JSON.stringify(GameState.snapshot())), 0)
	GameState.load_data(result["save"])
	assert_eq(GameState.get_bait_count("bait_worm"), 0, "a used-up bait is not refilled on load")
	GameState.new_game()
