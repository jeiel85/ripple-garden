extends TestCase

## P1-014 graphics quality profiles and P1-015 Battery Saver: one resolved profile from balance.json
## that the presenters follow, a higher tier never shows less, and Battery Saver only trims.

const SCENE := "res://world/game_root.tscn"
const REGION := "region_01_quiet_pond"

var _was_blocked := false

func _graphics() -> Dictionary:
	return ContentDB.balance["graphics"]

func _start() -> GameRoot:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	_was_blocked = save_service.write_blocked
	save_service.write_blocked = true
	var packed: PackedScene = load(SCENE)
	var root: GameRoot = packed.instantiate()
	root.load_save = false
	tree.root.add_child(root)
	return root

func _stop(root: GameRoot) -> void:
	root.free()
	GameState.new_game()
	tree.root.get_node("SaveService").write_blocked = _was_blocked
	Engine.max_fps = 0

func _raw_with_graphics(graphics: Dictionary) -> Dictionary:
	var raw: Dictionary = {}
	for category in ContentValidator.FILE_NAMES:
		raw[category] = JSON.parse_string(FileAccess.get_file_as_string("res://data".path_join(ContentValidator.FILE_NAMES[category])))
	raw["balance"]["graphics"] = graphics
	return raw

func _has_error(result: Dictionary, substring: String) -> bool:
	for problem in result["errors"]:
		if problem.contains(substring):
			return true
	return false

# --- resolving ---

func test_higher_tiers_never_show_less() -> void:
	var low := GraphicsProfile.resolve(_graphics(), "low", false)
	var medium := GraphicsProfile.resolve(_graphics(), "medium", false)
	var high := GraphicsProfile.resolve(_graphics(), "high", false)
	for field in ["rain", "wildlife", "stars", "waterfall_fps"]:
		assert_true(low[field] <= medium[field] and medium[field] <= high[field], "%s: %s / %s / %s" % [field, low[field], medium[field], high[field]])
	assert_true(low["rain"] < high["rain"], "quality must make a visible difference")
	assert_false(low["water_glints"], "low quality skips the glint waves")
	assert_true(high["water_glints"])

func test_battery_saver_only_trims() -> void:
	for quality in GraphicsProfile.QUALITIES:
		var normal := GraphicsProfile.resolve(_graphics(), quality, false)
		var saver := GraphicsProfile.resolve(_graphics(), quality, true)
		assert_true(saver["rain"] <= normal["rain"] and saver["rain"] >= GraphicsProfile.MIN_RAIN, "%s rain %d" % [quality, saver["rain"]])
		assert_true(saver["wildlife"] <= normal["wildlife"])
		assert_true(saver["waterfall_fps"] <= normal["waterfall_fps"])
		assert_true(saver["stars"] == normal["stars"], "stars are drawn once per light step and cost nothing per frame")
		assert_false(saver["water_glints"], "Battery Saver keeps the water calm")
	var high := GraphicsProfile.resolve(_graphics(), "high", false)
	assert_true(GraphicsProfile.resolve(_graphics(), "high", true)["rain"] < high["rain"])

func test_unknown_quality_is_medium() -> void:
	assert_deep_eq(GraphicsProfile.resolve(_graphics(), "ultra", false), GraphicsProfile.resolve(_graphics(), "medium", false))

func test_a_tier_never_hides_every_animal_of_a_kind() -> void:
	assert_eq(GraphicsProfile.scaled_count(1, 0.25), 1)
	assert_eq(GraphicsProfile.scaled_count(6, 0.5), 3)
	assert_eq(GraphicsProfile.scaled_count(0, 1.0), 0)

# --- presenters ---

func test_wildlife_share_thins_the_animals() -> void:
	var animals := AmbientAnimalPresenter.new()
	tree.root.add_child(animals)
	animals.setup(ContentDB.get_layout(REGION), 10, "dusk")
	var full := animals.animal_count()
	animals.set_wildlife(0.5)
	var half := animals.animal_count()
	assert_true(full > 0 and half < full and half > 0, "full %d half %d" % [full, half])
	animals.free()

func test_settings_reach_every_presenter() -> void:
	var root := _start()
	var env := root.region.environment
	GameState.set_setting("battery_saver", false)
	GameState.set_setting("quality", "high")
	var high := GraphicsProfile.for_settings("high", false)
	assert_eq(root.region.weather_presenter._rain.amount, int(high["rain"]))
	assert_eq(env.star_count, int(high["stars"]))
	assert_true(env.water_glints())
	assert_true(is_equal_approx(env.waterfall_frame_sec(), 1.0 / float(high["waterfall_fps"])))
	assert_true(is_equal_approx(root.region.animals.wildlife, float(high["wildlife"])))

	GameState.set_setting("quality", "low")
	var low := GraphicsProfile.for_settings("low", false)
	assert_eq(root.region.weather_presenter._rain.amount, int(low["rain"]))
	assert_eq(env.star_count, int(low["stars"]))
	assert_false(env.water_glints(), "low quality turns the glints off in the shader")
	assert_true(is_equal_approx(root.region.animals.wildlife, float(low["wildlife"])))

	GameState.set_setting("quality", "high")
	GameState.set_setting("battery_saver", true)
	var saver := GraphicsProfile.for_settings("high", true)
	assert_eq(Engine.max_fps, SettingsApplier.BATTERY_SAVER_FPS)
	assert_eq(root.region.weather_presenter._rain.amount, int(saver["rain"]))
	assert_false(env.water_glints())
	assert_true(is_equal_approx(env.waterfall_frame_sec(), 1.0 / float(saver["waterfall_fps"])))
	var saver_fish := root.region.fish_presenter.agent_budget()
	GameState.set_setting("battery_saver", false)
	assert_true(saver_fish < root.region.fish_presenter.agent_budget(), "Battery Saver also trims the swimming fish")
	_stop(root)

# --- validation ---

func test_shipped_graphics_are_valid() -> void:
	var result := ContentValidator.validate(_raw_with_graphics(_graphics().duplicate(true)))
	assert_eq(result["errors"], PackedStringArray())

func test_a_tier_that_shows_less_than_the_one_below_is_rejected() -> void:
	var graphics: Dictionary = _graphics().duplicate(true)
	graphics["quality"]["high"]["rain"] = 10
	assert_true(_has_error(ContentValidator.validate(_raw_with_graphics(graphics)), "graphics.quality.high.rain"))
	graphics = _graphics().duplicate(true)
	graphics["quality"]["high"]["stars"] = 1
	assert_true(_has_error(ContentValidator.validate(_raw_with_graphics(graphics)), "graphics.quality.high.stars: must not be lower"))

func test_a_missing_tier_or_saver_field_is_rejected() -> void:
	var graphics: Dictionary = _graphics().duplicate(true)
	graphics["quality"].erase("medium")
	assert_true(_has_error(ContentValidator.validate(_raw_with_graphics(graphics)), "graphics.quality.medium: must be an object"))
	graphics = _graphics().duplicate(true)
	graphics["battery_saver"]["rain_factor"] = 1.5
	assert_true(_has_error(ContentValidator.validate(_raw_with_graphics(graphics)), "graphics.battery_saver.rain_factor"))
	graphics = _graphics().duplicate(true)
	graphics["battery_saver"].erase("water_glints")
	assert_true(_has_error(ContentValidator.validate(_raw_with_graphics(graphics)), "graphics.battery_saver.water_glints"))

func test_the_wildlife_share_applies_to_each_kind_as_a_whole() -> void:
	var animals := AmbientAnimalPresenter.new()
	tree.root.add_child(animals)
	var layout := {"pond": ContentDB.get_layout(REGION)["pond"], "ambient_animals": [
		{"kind": "butterfly", "count": 3, "min_level": 0, "time_bands": ["day"]},
		{"kind": "butterfly", "count": 3, "min_level": 0, "time_bands": ["day"]},
	]}
	animals.setup(layout, 0, "day")
	animals.set_wildlife(0.5)
	assert_eq(animals.current_counts()["butterfly"], 3, "half of six, not round(1.5) twice")
	animals.free()

func test_android_sends_pinch_gestures_to_photo_mode() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/pointing/android/enable_pan_and_scale_gestures", false),
		"without it Android never sends InputEventMagnifyGesture")
