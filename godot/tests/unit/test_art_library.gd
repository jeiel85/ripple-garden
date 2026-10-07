extends TestCase

## D-029 drawn-art pipeline: a picture in res://art replaces the placeholder shapes, a missing one
## leaves them in place. The fixture folder holds flat-colour stand-ins with the real file names.

const REGION := "region_01_quiet_pond"
const FIXTURES := "res://tests/fixtures/art"
## A folder without any picture: the game as it looks before (or without) drawn art.
const NO_ART := "res://tests/fixtures/no_art"

func _with_fixtures() -> void:
	ArtLibrary.use_root(FIXTURES)

func _restore() -> void:
	ArtLibrary.use_root(ArtLibrary.DEFAULT_ROOT)

func _without_art() -> void:
	ArtLibrary.use_root(NO_ART)

func _environment(level: int) -> RegionEnvironment:
	var env := RegionEnvironment.new()
	env.hours_provider = func() -> float: return 12.0
	tree.root.add_child(env)
	env.setup(REGION, ContentDB.get_layout(REGION), null, level)
	return env

# --- the library ---

func test_a_missing_picture_is_null_and_an_existing_one_loads() -> void:
	_with_fixtures()
	assert_true(ArtLibrary.texture("props", "no_such_prop") == null)
	assert_not_null(ArtLibrary.texture("props", "tent"))
	assert_true(ArtLibrary.has("world", "r01_scene"))
	assert_false(ArtLibrary.has("world", "r99_scene"))
	_restore()

func test_the_game_folder_ships_the_region_01_scene_the_angler_the_ui_frames_and_the_moments() -> void:
	_restore()
	for pose in ["idle", "cast", "bite", "reel", "hold"]:
		assert_not_null(ArtLibrary.texture("character", "angler_" + pose), "Asset Drop 09: %s" % pose)
	assert_not_null(ArtLibrary.texture("world", "r01_scene"), "Asset Drop 08")
	for frame in UiTheme.FRAMES.values() + ["ui_reel_button", "ui_tension_bar", "ui_notebook_binding", "ui_leaf_corner_01"]:
		assert_not_null(ArtLibrary.texture("ui", frame), "Asset Drop 10: %s" % frame)
	for moment_id in ContentDB.moments:
		assert_not_null(ArtLibrary.texture("moments", moment_id), "Asset Drop 07/11: %s" % moment_id)
	assert_not_null(ArtLibrary.texture("world", "r01_scene_barren"), "the restored painting fades in over its barren twin")

func test_variants_cycle_and_are_stable_for_the_same_pick() -> void:
	_with_fixtures()
	var first := ArtLibrary.variant("props", "lily_pad", 0)
	var second := ArtLibrary.variant("props", "lily_pad", 1)
	assert_not_null(first)
	assert_true(first != second, "lily_pad_02 is the second variant")
	assert_eq(ArtLibrary.variant("props", "lily_pad", 2), first, "two variants: pick 2 wraps to the first")
	assert_eq(ArtLibrary.variant("props", "lily_pad", 7), ArtLibrary.variant("props", "lily_pad", 7))
	assert_eq(ArtLibrary.variant("props", "tent", 5), ArtLibrary.texture("props", "tent"), "one picture serves every pick")
	assert_true(ArtLibrary.variant("props", "bench", 0) == null)
	_restore()

func test_metadata_layers_defaults_base_and_exact_name() -> void:
	_with_fixtures()
	var reel := ArtLibrary.meta("character", "angler_reel", "angler")
	assert_eq(float(reel["height"]), 100.0, "from the category default")
	assert_eq(ArtLibrary.point(reel, "hands", Vector2.ZERO), Vector2(0.25, 0.25), "the pose's own entry wins")
	var idle := ArtLibrary.meta("character", "angler_idle", "angler")
	assert_eq(ArtLibrary.point(idle, "hands", Vector2.ZERO), Vector2(0.5, 0.5))
	assert_eq(float(ArtLibrary.meta("props", "lily_pad")["width"]), 40.0)
	assert_eq(float(ArtLibrary.meta("props", "tent")["width"]), 60.0)
	_restore()

func test_shipped_metadata_names_only_real_prop_kinds() -> void:
	_restore()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ArtLibrary.DEFAULT_ROOT + "/art.json"))
	assert_true(typeof(parsed) == TYPE_DICTIONARY, "art.json must be a JSON object")
	for kind in parsed.get("props", {}):
		assert_true(kind == "*" or kind in PropKinds.PROPS, "art.json names an unknown prop kind '%s'" % kind)

func test_rects_keep_the_picture_proportions() -> void:
	_with_fixtures()
	var tent := ArtLibrary.texture("props", "tent")  # 40 x 30
	var placed := ArtLibrary.placed_rect(tent, Vector2(100, 200), 80.0, Vector2(0.5, 1.0))
	assert_eq(placed, Rect2(60, 140, 80, 60), "foot centred on the anchor point")
	var scene := ArtLibrary.texture("world", "r01_scene")  # 60 x 90 (2:3)
	var cover := ArtLibrary.scene_rect(scene, Vector2(720, 1280))
	assert_true(is_equal_approx(cover.get_center().x, 360.0) and is_equal_approx(cover.get_center().y, 640.0), "centred where the camera looks")
	# The camera (centred on the design area, stretch aspect "expand") shows 720 x 1600 on a 20:9 phone
	# and 960 x 1280 on a 3:4 tablet: the painting must reach past both.
	for visible in [Vector2(720, 1600), Vector2(960, 1280), Vector2(720, 1280)]:
		var seen := Rect2(Vector2(360, 640) - visible / 2.0, visible)
		assert_true(cover.encloses(seen), "a %s view sees past the painting %s" % [visible, cover])
	var fit := ArtLibrary.fit_rect(tent, Rect2(0, 0, 100, 100))
	assert_eq(fit, Rect2(0, 12.5, 100, 75))
	_restore()

# --- the world ---

func test_a_painted_scene_replaces_the_drawn_backdrop_and_fades_with_restoration() -> void:
	_without_art()
	var plain := _environment(0)
	assert_false(plain.has_scene_art())
	plain.queue_free()
	_with_fixtures()
	var barren := _environment(0)
	var restored := _environment(10)
	assert_true(barren.has_scene_art())
	assert_eq(barren.scene_restored_share(), 0.0, "level 0 shows only the barren painting")
	assert_eq(restored.scene_restored_share(), 1.0)
	assert_true(barren.get_node("Waterfall").visible == false, "the painting has its own waterfall")
	var water := barren.get_node("Water") as Polygon2D
	assert_eq((water.material as ShaderMaterial).get_shader_parameter("overlay"), true, "water only adds its glints")
	barren.queue_free()
	restored.queue_free()
	_restore()

func test_a_barren_painting_alone_does_not_replace_the_backdrop() -> void:
	# Pictures arrive one at a time: without the restored painting a fully restored pond would stay barren.
	ArtLibrary.use_root("res://tests/fixtures/art_barren_only")
	assert_true(ArtLibrary.has("world", "r01_scene_barren"))
	var env := _environment(10)
	assert_false(env.has_scene_art(), "the drawn backdrop stays until the restored painting exists")
	assert_true(env.get_node("Waterfall").visible)
	env.queue_free()
	_restore()

func test_over_a_painted_scene_the_painted_props_are_not_drawn_again() -> void:
	_with_fixtures()
	var env := _environment(5)
	var props := PropsLayer.new()
	tree.root.add_child(props)
	props.setup(ContentDB.get_layout(REGION), env)
	var drawn := props.drawn_props(5)
	assert_false(drawn.is_empty())
	var drawn_kinds := {}
	for prop in drawn:
		assert_false(PropsLayer.is_in_painting(prop), "%s is in the painting" % prop["kind"])
		drawn_kinds[prop["kind"]] = true
	for kind in ["tree", "dock", "stepping_stone", "camp_ground"]:
		assert_false(drawn_kinds.has(kind), "%s is painted" % kind)
	# Permanent props the scene request tells the artist to leave out stay on top of the painting.
	assert_true(drawn_kinds.has("crate"), "the crate on the dock is not in the painting")
	assert_true(drawn.any(func(prop: Dictionary) -> bool: return prop["kind"] == "bush" and PropsLayer.is_permanent(prop)),
		"the front bushes are not in the painting")
	assert_true(props.visible_props(5).size() > drawn.size(), "trees, rocks and the dock are painted")
	for kind in PropKinds.SCENE_PAINTED:
		assert_true(kind in PropKinds.PROPS, "%s is not a prop kind" % kind)
	props.queue_free()
	env.queue_free()
	_without_art()
	var plain := _environment(5)
	var plain_props := PropsLayer.new()
	tree.root.add_child(plain_props)
	plain_props.setup(ContentDB.get_layout(REGION), plain)
	assert_eq(plain_props.drawn_props(5).size(), plain_props.visible_props(5).size(), "without a painting every prop is drawn")
	plain_props.queue_free()
	plain.queue_free()
	_restore()

func test_the_foreground_only_exists_as_art() -> void:
	ArtLibrary.use_root("res://tests/fixtures/art_barren_only")  # a folder without a foreground picture
	var none := ForegroundLayer.new()
	none.setup(ContentDB.get_layout(REGION))
	assert_false(none.has_art())
	none.free()
	_with_fixtures()
	var front := ForegroundLayer.new()
	front.setup(ContentDB.get_layout(REGION))
	assert_true(front.has_art())
	front.free()
	_restore()

# --- the angler ---

func test_the_angler_picture_follows_the_fishing_state_and_holds_the_rod_in_its_hands() -> void:
	_with_fixtures()
	var controller := FishingController.new()
	tree.root.add_child(controller)
	var view := FishingView.new()
	tree.root.add_child(view)
	var seat := Vector2(300, 640)
	view.setup(controller, Vector2(430, 450), seat)
	var idle := view.angler_art()
	assert_eq(idle["texture"], ArtLibrary.texture("character", "angler_idle"))
	assert_eq(idle["rect"], Rect2(seat - Vector2(40, 100), Vector2(80, 100)), "100 px tall, foot centred on the seat")
	assert_eq(view.current_rod_base(), seat + Vector2(0, -50), "hands at the picture's middle")

	view._on_state_changed(FishingController.State.READY, FishingController.State.FIGHT)
	assert_eq(view.angler_pose(), "reel")
	assert_eq(view.angler_art()["texture"], ArtLibrary.texture("character", "angler_reel"))
	assert_eq(view.current_rod_base(), seat + Vector2(-20, -75), "the reel pose holds the rod elsewhere")

	view._on_state_changed(FishingController.State.FIGHT, FishingController.State.BITE_HINT)
	assert_eq(view.angler_pose(), "bite")
	assert_eq(view.angler_art()["texture"], ArtLibrary.texture("character", "angler_idle"), "an undrawn pose falls back to idle")
	view.queue_free()
	controller.queue_free()
	_restore()

func test_without_pictures_the_angler_is_drawn_from_shapes() -> void:
	_without_art()
	var controller := FishingController.new()
	tree.root.add_child(controller)
	var view := FishingView.new()
	tree.root.add_child(view)
	view.setup(controller, Vector2(430, 450), Vector2(300, 640))
	assert_true(view.angler_art().is_empty())
	assert_eq(view.current_rod_base(), Vector2(300, 640) + FishingView.HANDS)
	view.queue_free()
	controller.queue_free()
	_restore()

# --- fish ---

func test_a_fish_with_a_top_view_swims_as_that_picture() -> void:
	_with_fixtures()
	var drawn := FishAgent.new()
	drawn.configure(ContentDB.get_fish("fish_crucian_carp"))
	assert_true(drawn.has_art())
	var sprite := drawn.get_node("Art") as Sprite2D
	assert_true(is_equal_approx(sprite.scale.x * 32.0, drawn.length_px * 2.0), "drawn top_length times the body length")
	assert_eq(sprite.modulate.a, 0.5, "see-through, under the surface")
	assert_false(drawn.get_node("Tail").visible, "the picture has its own tail")
	# A pooled agent reused for a species without art goes back to shapes.
	drawn.configure(ContentDB.get_fish("fish_minnow"))
	assert_false(drawn.has_art())
	assert_true(drawn.get_node("Tail").visible)
	drawn.free()
	_restore()

func test_a_fish_portrait_uses_the_side_view_when_there_is_one() -> void:
	_with_fixtures()
	var carp := UiKit.FishPortrait.new("fish_crucian_carp", false)
	var minnow := UiKit.FishPortrait.new("fish_minnow", true)
	assert_true(carp.has_art())
	assert_false(minnow.has_art())
	carp.free()
	minnow.free()
	_restore()

func test_an_equipment_item_uses_its_picture_when_there_is_one() -> void:
	_with_fixtures()
	var art := ItemArt.new("rod", "rod_bamboo")
	assert_true(art.has_art())
	art.show_item("rod", "rod_light")
	assert_false(art.has_art(), "an item without a picture keeps its shapes")
	art.free()
	_restore()

func test_shipped_item_pictures_are_named_after_real_items() -> void:
	_restore()
	const CATEGORIES := {"rod_": "rod", "bait_": "bait", "bag_": "bag", "acc_": "accessory"}
	for file in DirAccess.get_files_at(ArtLibrary.DEFAULT_ROOT + "/items"):
		if not file.ends_with(".png"):
			continue
		var id := file.get_basename()
		var category := ""
		for prefix in CATEGORIES:
			if id.begins_with(prefix):
				category = CATEGORIES[prefix]
		assert_false(category.is_empty() or ContentDB.get_item(category, id).is_empty(), "art/items/%s names no equipment item" % file)

# --- animation frames ---

func test_frames_are_the_picture_then_its_numbered_frames() -> void:
	_with_fixtures()
	assert_eq(ArtLibrary.frames("animals", "dragonfly").size(), 2)
	assert_eq(ArtLibrary.frames("animals", "dragonfly")[0], ArtLibrary.texture("animals", "dragonfly"), "the picture itself comes first")
	assert_eq(ArtLibrary.frames("props", "tent").size(), 1, "a still picture is one frame")
	assert_true(ArtLibrary.frames("animals", "bird").is_empty(), "no picture, no frames")
	_restore()

func test_shipped_frames_share_their_pictures_canvas() -> void:
	_restore()
	var frame_name := RegEx.create_from_string("_f\\d+$")
	for category in ["fish", "props", "animals"]:
		for file in DirAccess.get_files_at(ArtLibrary.DEFAULT_ROOT + "/" + category):
			if not file.ends_with(".png") or frame_name.search(file.get_basename()) != null:
				continue
			var frames := ArtLibrary.frames(category, file.get_basename())
			for frame in frames:
				assert_eq(frame.get_size(), frames[0].get_size(), "%s/%s: every frame on the same canvas, or the picture jumps" % [category, file])

func test_a_fish_tail_frame_follows_the_swim_stroke() -> void:
	assert_eq(FishAgent.tail_frame(0.0, 3), 0, "straight through the middle of the stroke")
	assert_eq(FishAgent.tail_frame(-0.9, 3), 1)
	assert_eq(FishAgent.tail_frame(0.9, 3), 2)
	assert_eq(FishAgent.tail_frame(0.9, 2), 1, "with one bent frame both ends use it")
	assert_eq(FishAgent.tail_frame(0.9, 1), 0)
	_with_fixtures()
	var fish := FishAgent.new()
	fish.configure(ContentDB.get_fish("fish_crucian_carp"))
	var sprite := fish.get_node("Art") as Sprite2D
	var seen := {}
	for i in 40:
		fish.animate(0.05, false)
		seen[sprite.texture] = true
	assert_eq(seen.size(), 2, "the tail beats through both frames")
	for i in 40:
		fish.animate(0.05, true)
		assert_eq(sprite.texture, ArtLibrary.texture("fish", "fish_crucian_carp_top"), "Reduced Motion keeps the straight picture")
	fish.free()
	_restore()

func test_an_animal_with_art_beats_its_wings_and_holds_still_under_reduced_motion() -> void:
	_with_fixtures()
	var animals := AmbientAnimalPresenter.new()
	tree.root.add_child(animals)
	animals.setup({"pond": ContentDB.get_layout(REGION)["pond"], "ambient_animals": [
		{"kind": "dragonfly", "count": 2, "min_level": 0, "time_bands": ["day"]},
		{"kind": "bird", "count": 1, "min_level": 0, "time_bands": ["day"]},
	]}, 0, "day")
	assert_true(animals.has_art("dragonfly"))
	assert_false(animals.has_art("bird"), "a kind without a picture keeps its shapes")
	var mote := {"phase": 0.3}
	var frames := {}
	for i in 30:
		animals._process(0.03)
		frames[animals.frame_index(mote, 2, 10.0)] = true
	assert_eq(frames.size(), 2, "wings beat through both frames")
	animals.reduced_motion = true
	assert_eq(animals.frame_index(mote, 2, 10.0), 0)
	animals.free()
	_restore()

func test_an_animated_prop_takes_a_pose_now_and_then() -> void:
	_with_fixtures()
	var props := PropsLayer.new()
	var frog := {"kind": "frog", "x": 100.0, "y": 200.0}
	var poses := {}
	var time := 0.0
	while time < 40.0:
		poses[props.pose_at(frog, time)] = int(poses.get(props.pose_at(frog, time), 0)) + 1
		time += 0.1
	assert_true(poses.has(1), "it takes its other pose")
	assert_true(poses[0] > poses[1] * 4, "but mostly sits in its picture: %s" % poses)
	assert_eq(props.pose_at({"kind": "tent", "x": 1.0, "y": 1.0}, 3.0), 0, "a still prop never changes")
	props.reduced_motion = true
	for t in [0.0, 5.0, 11.0, 23.0]:
		assert_eq(props.pose_at(frog, t), 0)
	props.free()
	_restore()

func test_a_seen_moment_shows_its_picture_and_an_unseen_one_does_not() -> void:
	_with_fixtures()
	GameState.new_game()
	GameState.record_moment("moment_rain_rings")
	var panel := JournalPanel.new()
	tree.root.add_child(panel)
	panel.setup(JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"]), REGION)
	panel.select_tab("moments")
	panel._show_moment("moment_rain_rings")
	assert_true(panel.page_shows_moment_art())
	panel._show_moment("moment_sunshower")
	assert_false(panel.page_shows_moment_art(), "no picture for a moment not seen yet")
	panel.select_tab("all")
	assert_false(panel.page_shows_moment_art())
	assert_true(panel._page_portrait.visible, "fish pages show the fish again")
	panel.free()
	GameState.new_game()
	_restore()

# --- UI frames ---

func test_without_frame_pictures_the_theme_keeps_its_coded_boxes() -> void:
	_without_art()
	var theme := UiTheme.build(1.0, false, false)
	assert_true(theme.get_stylebox("normal", "Button") is StyleBoxFlat)
	assert_true(theme.get_stylebox("panel", "WoodPanel") is WoodStyle)
	assert_true(theme.get_stylebox("panel", "SignPanel") is WoodStyle)
	assert_true(theme.get_stylebox("panel", "NotebookPanel") is StyleBoxFlat)
	_restore()

func test_a_frame_picture_replaces_its_box_and_keeps_the_layout() -> void:
	_without_art()
	var coded: StyleBox = UiTheme.build(1.0, false, false).get_stylebox("normal", "Button")
	_with_fixtures()
	var theme := UiTheme.build(1.0, false, false)
	var framed := theme.get_stylebox("normal", "Button") as ArtFrameStyle
	assert_not_null(framed, "the cream button picture replaces the coded box")
	assert_eq(framed.texture, ArtLibrary.texture("ui", "ui_cream_button"))
	assert_eq(framed.slice, Vector4(0.25, 0.25, 0.25, 0.25), "the slice from art.json")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(framed.get_content_margin(side), coded.get_content_margin(side), "the text sits where it did")
	assert_true((theme.get_stylebox("pressed", "Button") as ArtFrameStyle).tint.v < 1.0, "pressed is the same picture, darker")
	assert_true(theme.get_stylebox("normal", "TabButton") is StyleBoxFlat, "a frame not drawn yet keeps its box")
	assert_true(UiTheme.build(1.0, false, true).get_stylebox("normal", "Button") is StyleBoxFlat, "High Contrast keeps the coded boxes")
	_restore()

func test_leaf_corners_and_the_binding_decorate_the_coded_boxes() -> void:
	_with_fixtures()
	var theme := UiTheme.build(1.0, false, false)
	var wood := theme.get_stylebox("panel", "WoodPanel") as ArtFrameStyle
	assert_not_null(wood, "the leaf corner is drawn, the wood frame is not")
	assert_true(wood.texture == null and wood.fallback is WoodStyle, "so the coded wood board stays under the leaves")
	assert_eq(wood.corners[0], ArtLibrary.texture("ui", "ui_leaf_corner_01"))
	assert_true(wood.corners[1] == null, "a corner without a picture stays bare")
	assert_eq(wood.corner_size, 24.0)
	assert_true(theme.get_stylebox("panel", "SignPanel") is WoodStyle, "title boards take no leaf corners")
	var notebook := theme.get_stylebox("panel", "NotebookPanel") as ArtFrameStyle
	assert_eq(notebook.strip, ArtLibrary.texture("ui", "ui_notebook_binding"))
	assert_true(theme.get_stylebox("panel", "PanelContainer") is StyleBoxFlat, "only the journal's list has the binding")
	_restore()

func test_a_frame_is_scaled_so_its_slices_fit_the_control() -> void:
	_with_fixtures()
	var frame := ArtFrameStyle.from_art("ui_cream_button")  # 40 x 20, slices of 10 / 5 px
	assert_eq(frame.slice_px(), Vector4(10, 5, 10, 5))
	assert_eq(frame.scale_for(Vector2(200, 100)), 0.5, "the scale from art.json")
	assert_eq(frame.scale_for(Vector2(8, 100)), 0.4, "shrunk where the left and right slices would overlap")
	frame.scale = 0.0
	assert_eq(frame.scale_for(Vector2(80, 80)), 2.0, "without a scale, as large as the narrower side allows")
	assert_true(ArtFrameStyle.from_art("ui_wood_cta") == null)
	_restore()

func test_the_reel_button_and_the_tension_meter_use_their_pictures() -> void:
	_without_art()
	assert_true(Hud.ReelStyle.art() == null)
	var meter := FightMeter.new()
	assert_true(meter.frame_art() == null)
	_with_fixtures()
	assert_eq(Hud.ReelStyle.art(), ArtLibrary.texture("ui", "ui_reel_button"))
	var frame := meter.frame_art()
	assert_not_null(frame)
	assert_false(frame.draw_center, "the colour band shows through the frame")
	meter.high_contrast = true
	assert_true(meter.frame_art() == null, "High Contrast keeps the coded rim")
	meter.free()
	_restore()

# --- region map ---

func test_the_map_paints_its_pictures_and_keeps_shapes_for_the_rest() -> void:
	_with_fixtures()
	var map := RegionMapPanel.MapView.new()
	map.size = Vector2(720, 1280)
	var island := map.island_rect("region_01_quiet_pond")
	assert_true(is_equal_approx(island.size.x, map.island_radius() * 2.0), "two island radii wide (art.json)")
	assert_true(island.get_center().is_equal_approx(map.island_center("region_01_quiet_pond")))
	assert_false(map.island_rect("region_02_forest_stream").has_area(), "an island without a picture is drawn from shapes")
	var cover := RegionMapPanel.MapView.cover_rect(ArtLibrary.texture("map", "map_background"), Rect2(0, 0, 100, 100))
	assert_eq(cover, Rect2(-50, 0, 200, 100), "covers the area, cropped at the sides")
	map.free()
	_restore()

# --- the angler's hat ---

func test_an_equipped_hat_with_a_picture_is_drawn_over_the_angler() -> void:
	_with_fixtures()
	GameState.new_game()
	var controller := FishingController.new()
	tree.root.add_child(controller)
	var view := FishingView.new()
	tree.root.add_child(view)
	var seat := Vector2(300, 640)
	view.setup(controller, Vector2(430, 450), seat)
	assert_true(view.hat_art(view.angler_art()).is_empty(), "the straw hat is part of the angler picture")
	GameState.grant_accessory("acc_bucket_hat")
	assert_true(GameState.equip_accessory("acc_bucket_hat"))
	var hat := view.hat_art(view.angler_art())
	assert_eq(hat["texture"], ArtLibrary.texture("hats", "acc_bucket_hat"))
	# The 80 x 100 angler: head at (0.5, 0.25), the hat half its width, its default anchor (0.5, 0.6) on the head.
	assert_eq(hat["rect"], Rect2(seat + Vector2(-20, -75 - 12), Vector2(40, 20)))
	assert_true(view.hat_art({}).is_empty(), "no hat without an angler picture")
	view.queue_free()
	controller.queue_free()
	GameState.new_game()
	_restore()
