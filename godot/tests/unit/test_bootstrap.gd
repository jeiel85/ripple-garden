extends TestCase

## P0-001: project bootstrap — autoload registration, main scene, audio buses,
## portrait display configuration.

# TECH_SPEC §2 autoloads. EntitlementService is deferred to P1-011.
const EXPECTED_AUTOLOADS: PackedStringArray = [
	"EventBus", "GameState", "ContentDB", "SaveService", "TimeService", "AudioService",
]

func test_autoloads_registered_and_present() -> void:
	for autoload_name in EXPECTED_AUTOLOADS:
		assert_true(ProjectSettings.has_setting("autoload/" + autoload_name),
			"autoload/%s not registered" % autoload_name)
		assert_true(tree.root.has_node(autoload_name), "/root/%s missing" % autoload_name)

func test_save_service_dependencies_load_first() -> void:
	# SaveService touches EventBus and GameState, so they must be initialised before it.
	var save_index := tree.root.get_node("SaveService").get_index()
	assert_true(tree.root.get_node("EventBus").get_index() < save_index, "EventBus after SaveService")
	assert_true(tree.root.get_node("GameState").get_index() < save_index, "GameState after SaveService")

func test_content_db_loaded_static_content() -> void:
	var content_db := tree.root.get_node("ContentDB")
	assert_false(content_db.fish.is_empty(), "fish catalog empty")
	assert_false(content_db.regions.is_empty(), "regions empty")
	assert_false(content_db.rods.is_empty(), "rods empty")
	assert_false(content_db.baits.is_empty(), "baits empty")

func test_main_scene_instantiates() -> void:
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_false(main_scene_path.is_empty(), "main scene not configured")
	var packed: PackedScene = load(main_scene_path)
	assert_not_null(packed, "main scene failed to load: %s" % main_scene_path)
	if packed != null:
		var instance := packed.instantiate()
		assert_not_null(instance, "main scene failed to instantiate")
		if instance != null:
			instance.free()

func test_audio_bus_layout_matches_spec() -> void:
	var audio := tree.root.get_node("AudioService")
	assert_eq(audio.missing_buses(), PackedStringArray(), "missing audio buses")

func test_audio_bus_volume_roundtrip_and_clamp() -> void:
	var audio := tree.root.get_node("AudioService")
	var original: float = audio.get_bus_volume_linear("Water")
	assert_true(audio.set_bus_volume_linear("Water", 0.5))
	assert_true(absf(audio.get_bus_volume_linear("Water") - 0.5) < 0.001, "volume not applied")
	audio.set_bus_volume_linear("Water", 4.0)
	assert_true(absf(audio.get_bus_volume_linear("Water") - 1.0) < 0.001, "volume not clamped to 1")
	audio.set_bus_volume_linear("Water", original)
	assert_eq(audio.get_bus_volume_linear("NoSuchBus"), -1.0, "unknown bus volume")

func test_portrait_first_display_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "orientation")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "stretch aspect")
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_true(height > width, "base viewport must be portrait (%dx%d)" % [width, height])
