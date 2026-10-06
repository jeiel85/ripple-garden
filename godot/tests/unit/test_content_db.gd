extends TestCase

## P0-002: ContentDB loading, error reporting and lookups.

const MALFORMED_DIR := "res://tests/fixtures/content_malformed"

func test_autoload_loaded_valid_content() -> void:
	var content_db := tree.root.get_node("ContentDB")
	assert_true(content_db.is_valid(), "content errors: %s" % content_db.errors)
	assert_false(content_db.progression.is_empty(), "progression not loaded")

func test_lookups_return_definition_or_empty() -> void:
	var content_db := tree.root.get_node("ContentDB")
	assert_eq(content_db.get_fish("fish_crucian_carp").get("id"), "fish_crucian_carp")
	assert_eq(content_db.get_region("region_01_quiet_pond").get("id"), "region_01_quiet_pond")
	assert_eq(content_db.get_rod("rod_bamboo").get("id"), "rod_bamboo")
	assert_eq(content_db.get_bait("bait_bread").get("id"), "bait_bread")
	assert_eq(content_db.get_fish("fish_does_not_exist"), {})

func test_missing_and_malformed_files_are_reported() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	assert_true(content_db.load_all(), "shipped content should load first")
	assert_false(content_db.fish.is_empty())

	expect_engine_error("fish_catalog.json: invalid JSON at line")
	for file_name in ["regions.json", "rods.json", "baits.json", "progression.json", "balance.json", "content_aliases.json", "behaviors.json", "weather.json", "region_layouts.json", "audio.json", "equipment.json"]:
		expect_engine_error("%s: file not found" % file_name)
	assert_false(content_db.load_all(MALFORMED_DIR), "malformed content reported valid")
	assert_false(content_db.is_valid())
	assert_eq(content_db.errors.size(), 12, "error count: %s" % content_db.errors)
	assert_true(content_db.fish.is_empty(), "previous content must be replaced")
	assert_true(content_db.regions.is_empty())
	assert_true(content_db.progression.is_empty())
	assert_true(content_db.balance.is_empty())
	assert_true(content_db.aliases.is_empty())
	content_db.free()
