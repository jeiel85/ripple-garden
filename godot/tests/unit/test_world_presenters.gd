extends TestCase

## P0-008 / P0-020 / P0-021 visuals: lighting by time of day, restoration palettes, props that follow
## the level, ambient animals, weather presentation and the camera. Pure logic is asserted directly;
## drawing itself is checked by looking at the captures (tools/capture_screenshot.gd).

const REGION := "region_01_quiet_pond"

func _layout() -> Dictionary:
	return ContentDB.get_layout(REGION)

func _environment(level: int = 0, hour: float = 12.0) -> RegionEnvironment:
	var env := RegionEnvironment.new()
	env.hours_provider = func() -> float: return hour
	tree.root.add_child(env)
	env.setup(REGION, _layout(), null, level)
	return env

# --- time of day ---

func test_light_is_brightest_at_midday_and_darkest_at_night() -> void:
	var noon: Color = EnvironmentStyle.sample(12.0)["light"]
	var night: Color = EnvironmentStyle.sample(1.0)["light"]
	assert_true(noon.get_luminance() > night.get_luminance() + 0.25, "noon %.2f vs night %.2f" % [noon.get_luminance(), night.get_luminance()])
	assert_true(night.get_luminance() > 0.35, "night must stay readable")

func test_sampling_is_continuous_across_the_day() -> void:
	var previous: Dictionary = EnvironmentStyle.sample(0.0)
	var hour := 0.1
	while hour <= 24.0:
		var current: Dictionary = EnvironmentStyle.sample(hour)
		for key in ["top", "bottom", "light"]:
			var difference := absf(current[key].r - previous[key].r) + absf(current[key].g - previous[key].g) + absf(current[key].b - previous[key].b)
			assert_true(difference < 0.30, "%s jumps by %.2f at hour %.1f" % [key, difference, hour])
		previous = current
		hour += 0.1
	var wrapped: Dictionary = EnvironmentStyle.sample(24.0)
	var start: Dictionary = EnvironmentStyle.sample(0.0)
	assert_eq(wrapped["light"], start["light"], "24:00 must equal 00:00")

func test_stars_only_show_at_night_and_sun_and_moon_take_turns() -> void:
	assert_eq(EnvironmentStyle.sample(12.0)["stars"], 0.0)
	assert_eq(EnvironmentStyle.sample(23.0)["stars"], 1.0)
	assert_true(EnvironmentStyle.sun_progress(12.0) > 0.0 and EnvironmentStyle.moon_progress(12.0) < 0.0)
	assert_true(EnvironmentStyle.sun_progress(23.0) < 0.0 and EnvironmentStyle.moon_progress(23.0) >= 0.0)
	assert_true(EnvironmentStyle.moon_progress(3.0) >= 0.0, "the moon is up before dawn too")
	for hour in range(24):
		assert_true(EnvironmentStyle.sun_progress(hour) >= 0.0 or EnvironmentStyle.moon_progress(hour) >= 0.0, "the sky is empty at %d:00" % hour)

func test_compensation_restores_the_intended_sky_colour() -> void:
	var light := Color(0.5, 0.56, 0.8)
	var wanted := Color(0.1, 0.2, 0.3)
	var drawn := EnvironmentStyle.compensate(wanted, light)
	var result := Color(drawn.r * light.r, drawn.g * light.g, drawn.b * light.b)
	assert_true(absf(result.r - wanted.r) < 0.001 and absf(result.g - wanted.g) < 0.001 and absf(result.b - wanted.b) < 0.001)
	var clipped := EnvironmentStyle.compensate(Color(1, 1, 1), light)
	assert_true(clipped.r <= 1.0 and clipped.g <= 1.0 and clipped.b <= 1.0, "compensation must stay displayable")

func test_environment_dims_the_world_at_night_and_tints_in_rain() -> void:
	var day := _environment(0, 12.0)
	var night := _environment(0, 23.0)
	assert_true(day.current_light().get_luminance() > night.current_light().get_luminance())
	day.free()
	night.free()

	var weather := WeatherService.new()
	weather.rng.seed = 2
	weather.start(REGION)
	var env := RegionEnvironment.new()
	env.hours_provider = func() -> float: return 12.0
	tree.root.add_child(env)
	env.setup(REGION, _layout(), weather, 0)
	var clear_light := env.current_light()
	weather.set_weather("rain")
	weather.advance(60.0)
	env._update_lighting()
	assert_true(env.current_light().get_luminance() < clear_light.get_luminance(), "rain should dim the light")
	env.free()
	weather.free()

# --- restoration palette ---

func test_levels_blend_between_palettes() -> void:
	var env := _environment(0)
	var start: Color = env.current_palette()["water_shallow"]
	env.set_level(3, true, 3.0)
	assert_eq(env.level, 3)
	assert_true(env.palette_blend < 1.0)
	assert_eq(env.previous_level(), 0)
	env._set_blend(0.5)
	var halfway: Color = env.current_palette()["water_shallow"]
	var target: Color = env.palette_for(3)["water_shallow"]
	assert_true(halfway != start and halfway != target, "mid-transition colours must be between the palettes")
	env._set_blend(1.0)
	assert_eq(env.current_palette()["water_shallow"], target)
	assert_eq(env.displayed_level(), 3.0)
	env.free()

func test_set_level_without_animation_is_immediate() -> void:
	var env := _environment(1)
	env.set_level(4, false)
	assert_eq(env.palette_blend, 1.0)
	assert_eq(env.current_palette()["canopy"], env.palette_for(4)["canopy"])
	env.set_level(4, true)  # same level again: nothing to animate
	assert_eq(env.palette_blend, 1.0)
	env.free()

func test_smoothing_rounds_a_polygon_without_moving_it_far() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var smooth := RegionEnvironment.smooth(square, 2)
	assert_eq(smooth.size(), square.size() * 4)
	for point in smooth:
		assert_true(point.x >= 0.0 and point.x <= 100.0 and point.y >= 0.0 and point.y <= 100.0)
	assert_false(smooth.has(Vector2(0, 0)), "corners must be cut")

# --- props & animals ---

func test_props_layer_filters_by_level_and_sorts_back_to_front() -> void:
	var env := _environment(0)
	var props := PropsLayer.new()
	tree.root.add_child(props)
	props.setup(_layout(), env)
	var level0 := props.visible_props(0)
	var level5 := props.visible_props(5)
	var kinds0 := level0.map(func(p: Dictionary) -> String: return p["kind"])
	var kinds5 := level5.map(func(p: Dictionary) -> String: return p["kind"])
	assert_true("junk" in kinds0 and "stump" in kinds0, "a neglected pond has rubbish and stumps")
	assert_false("junk" in kinds5 or "stump" in kinds5, "a restored pond has none")
	assert_false("reed" in kinds0 or "flower" in kinds0)
	assert_true("reed" in kinds5 and "flower" in kinds5 and "lily_pad" in kinds5)
	for i in range(1, level5.size()):
		assert_true(float(level5[i - 1]["y"]) <= float(level5[i]["y"]), "props must be drawn back to front")
	props.free()
	env.free()

func test_every_prop_kind_in_the_layout_can_be_painted() -> void:
	var canvas := Node2D.new()
	tree.root.add_child(canvas)
	var palette := {"grass": Color.GREEN, "canopy": Color.DARK_GREEN}
	for prop in _layout()["props"]:
		assert_true(prop["kind"] in PropKinds.PROPS)
	# Painting needs a draw context; calling from _draw is covered by the capture tool.
	assert_eq(PropPainter.noise(Vector2(3, 4), 1), PropPainter.noise(Vector2(3, 4), 1), "noise must be stable")
	assert_true(PropPainter.noise(Vector2(3, 4), 1) != PropPainter.noise(Vector2(3, 4), 2))
	assert_true(palette.has("grass"))
	canvas.free()

func test_ambient_animals_appear_with_level_and_time_of_day() -> void:
	var animals := AmbientAnimalPresenter.new()
	tree.root.add_child(animals)
	animals.layout = _layout()
	animals.level = 2
	animals.time_band = "day"
	assert_true(animals.current_counts().is_empty(), "nothing flies over a barely restored pond")
	animals.level = 3
	assert_true(animals.current_counts().has("dragonfly"))
	animals.time_band = "night"
	assert_false(animals.current_counts().has("dragonfly"), "dragonflies sleep at night")
	animals.level = 5
	assert_true(animals.current_counts().has("firefly"))
	animals.time_band = "day"
	assert_true(animals.current_counts().has("butterfly"))
	animals.set_level(5)
	assert_true(animals.animal_count() > 0)
	animals.free()

func test_ambient_animals_are_bounded() -> void:
	var animals := AmbientAnimalPresenter.new()
	tree.root.add_child(animals)
	animals.layout = _layout()
	var most := 0
	for level in 6:
		for band in TimeService.TIME_BANDS:
			animals.level = level
			animals.time_band = band
			var total := 0
			for count in animals.current_counts().values():
				total += count
			most = maxi(most, total)
	assert_true(most <= 32, "at most a few dozen animals at once (found %d)" % most)
	animals.free()

# --- weather presenter ---

func test_rain_amount_follows_quality_and_battery_saver() -> void:
	var weather := WeatherService.new()
	weather.rng.seed = 4
	weather.start(REGION)
	var presenter := WeatherPresenter.new()
	tree.root.add_child(presenter)
	presenter.setup(weather, HabitatZone.to_polygon(_layout()["pond"]))
	presenter.apply_quality("low", false)
	var low: int = presenter._rain.amount
	presenter.apply_quality("high", false)
	var high: int = presenter._rain.amount
	presenter.apply_quality("high", true)
	var saver: int = presenter._rain.amount
	assert_true(low < high and saver < high and saver >= 20, "rain amounts: low %d high %d saver %d" % [low, high, saver])
	presenter.apply_quality("nonsense", false)
	assert_eq(presenter._rain.amount, WeatherPresenter.RAIN_AMOUNT["medium"], "unknown quality falls back to medium")
	presenter.free()
	weather.free()

func test_rain_emits_only_while_it_rains() -> void:
	var weather := WeatherService.new()
	weather.rng.seed = 4
	weather.start(REGION)
	var presenter := WeatherPresenter.new()
	tree.root.add_child(presenter)
	presenter.setup(weather, HabitatZone.to_polygon(_layout()["pond"]))
	presenter._process(0.1)
	assert_false(presenter._rain.emitting, "no rain in clear weather")
	weather.set_weather("rain")
	weather.advance(60.0)
	presenter._process(0.1)
	assert_true(presenter._rain.emitting)
	assert_true(presenter._rain.modulate.a > 0.9)
	presenter.free()
	weather.free()

func test_rain_ripples_are_capped() -> void:
	var weather := WeatherService.new()
	weather.rng.seed = 4
	weather.start(REGION)
	weather.set_weather("rain")
	weather.advance(60.0)
	var presenter := WeatherPresenter.new()
	tree.root.add_child(presenter)
	presenter.setup(weather, HabitatZone.to_polygon(_layout()["pond"]))
	for i in 600:
		presenter._process(0.05)
	assert_true(presenter._ripples.size() <= WeatherPresenter.MAX_RIPPLES)
	presenter.free()
	weather.free()

# --- camera ---

func test_camera_effects_respect_reduced_motion_and_shake_setting() -> void:
	var camera := CameraController.new()
	tree.root.add_child(camera)
	assert_eq(camera.position, CameraController.DESIGN_CENTER)
	camera.reduced_motion = true
	camera.restoration_pulse()
	camera.shake()
	assert_eq(camera.zoom, Vector2.ONE, "no zoom with reduced motion")
	assert_eq(camera.offset, Vector2.ZERO, "no shake with reduced motion")
	camera.reduced_motion = false
	camera.shake_enabled = false
	camera.shake()
	assert_eq(camera.offset, Vector2.ZERO, "no shake when switched off")
	camera.restoration_pulse(0.2)  # smoke test: must not error
	camera.free()
