extends TestCase

## D-029 drawn-art pipeline: a picture in res://art replaces the placeholder shapes, a missing one
## leaves them in place. The fixture folder holds flat-colour stand-ins with the real file names.

const REGION := "region_01_quiet_pond"
const FIXTURES := "res://tests/fixtures/art"

func _with_fixtures() -> void:
	ArtLibrary.use_root(FIXTURES)

func _restore() -> void:
	ArtLibrary.use_root(ArtLibrary.DEFAULT_ROOT)

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

func test_the_game_folder_has_no_pictures_yet_so_shapes_stay() -> void:
	_restore()
	assert_true(ArtLibrary.texture("character", "angler_idle") == null, "the shipped game draws the angler from shapes until art arrives")
	assert_true(ArtLibrary.texture("world", "r01_scene") == null)

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
	var cover := ArtLibrary.cover_rect(scene, Vector2(720, 1280))
	assert_eq(cover.size.y, 1280.0)
	assert_true(cover.size.x > 720.0 and is_equal_approx(cover.get_center().x, 360.0), "a 2:3 scene overflows a 9:16 screen evenly")
	var fit := ArtLibrary.fit_rect(tent, Rect2(0, 0, 100, 100))
	assert_eq(fit, Rect2(0, 12.5, 100, 75))
	_restore()

# --- the world ---

func test_a_painted_scene_replaces_the_drawn_backdrop_and_fades_with_restoration() -> void:
	_restore()
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

func test_over_a_painted_scene_only_the_changing_props_are_drawn() -> void:
	_with_fixtures()
	var env := _environment(5)
	var props := PropsLayer.new()
	tree.root.add_child(props)
	props.setup(ContentDB.get_layout(REGION), env)
	var drawn := props.drawn_props(5)
	assert_false(drawn.is_empty())
	for prop in drawn:
		assert_false(PropsLayer.is_permanent(prop), "%s is in the painting" % prop["kind"])
	assert_true(props.visible_props(5).size() > drawn.size(), "trees, rocks and the dock are painted")
	props.queue_free()
	env.queue_free()
	_restore()
	var plain := _environment(5)
	var plain_props := PropsLayer.new()
	tree.root.add_child(plain_props)
	plain_props.setup(ContentDB.get_layout(REGION), plain)
	assert_eq(plain_props.drawn_props(5).size(), plain_props.visible_props(5).size(), "without a painting every prop is drawn")
	plain_props.queue_free()
	plain.queue_free()

func test_the_foreground_only_exists_as_art() -> void:
	_restore()
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
	_restore()
	var controller := FishingController.new()
	tree.root.add_child(controller)
	var view := FishingView.new()
	tree.root.add_child(view)
	view.setup(controller, Vector2(430, 450), Vector2(300, 640))
	assert_true(view.angler_art().is_empty())
	assert_eq(view.current_rod_base(), Vector2(300, 640) + FishingView.HANDS)
	view.queue_free()
	controller.queue_free()

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
