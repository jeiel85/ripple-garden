extends TestCase

## P1-005 / P1-006: five time bands (a morning between dawn and day) and six kinds of weather, with mist
## lying on the water and soft lightning in a storm.

func test_five_bands_in_order_and_every_fish_knows_them() -> void:
	assert_deep_eq(Array(TimeService.TIME_BANDS), ["dawn", "morning", "day", "dusk", "night"])
	for fish_id in ContentDB.fish:
		var bands: Dictionary = ContentDB.get_fish(fish_id)["time_bands"]
		assert_true(bands.has("morning"), "%s has no morning multiplier" % fish_id)

func test_six_weathers_are_defined_and_the_pond_has_five() -> void:
	assert_eq(ContentDB.weather.size(), 6)
	for weather_id in ["clear", "cloudy", "rain", "mist", "storm", "sunshower"]:
		assert_false(ContentDB.get_weather(weather_id).is_empty(), "%s is missing" % weather_id)
	assert_deep_eq(ContentDB.get_region("region_01_quiet_pond")["weather"], ["clear", "cloudy", "rain", "mist", "sunshower"])

func test_weather_visuals_carry_fog_and_lightning() -> void:
	var service := WeatherService.new()
	tree.root.add_child(service)
	service.start("region_01_quiet_pond")
	assert_eq(service.visual()["fog"], 0.0)
	service.set_weather("mist")
	service.advance(60.0)
	assert_true(float(service.visual()["fog"]) > 0.5, "mist lies on the water")
	assert_true(service.set_preview("sunshower"))
	assert_true(float(service.visual()["rain"]) > 0.0 and float(service.visual()["brightness"]) >= 1.0, "a sunshower is rain in sunlight")
	service.free()

func test_lightning_flashes_in_a_storm_but_never_with_reduced_motion() -> void:
	var service := WeatherService.new()
	tree.root.add_child(service)
	service.region_id = "region_03_reed_river"
	service.start("region_03_reed_river")
	assert_true(service.set_weather("storm"))
	service.advance(60.0)
	var presenter := WeatherPresenter.new()
	tree.root.add_child(presenter)
	presenter.setup(service, PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]))
	presenter.rng.seed = 4
	var flashed := false
	for i in 900:
		presenter._process(1.0 / 30.0)
		flashed = flashed or presenter.flash_strength() > 0.0
	assert_true(flashed, "a storm flashes now and then")
	presenter._flash = 1.0  # a flash on screen at the moment Reduced Motion is switched on
	presenter.reduced_motion = true
	presenter._process(1.0 / 30.0)
	assert_eq(presenter.flash_strength(), 0.0, "the flash already showing goes at once")
	for i in 900:
		presenter._process(1.0 / 30.0)
		assert_eq(presenter.flash_strength(), 0.0, "Reduced Motion never flashes")
	presenter.free()
	service.free()

func test_water_mind_previews_every_band() -> void:
	assert_deep_eq(Array(WaterMindOverlay.PREVIEW_BANDS), Array(TimeService.TIME_BANDS))
	for band in TimeService.TIME_BANDS:
		var hour := UIController.preview_hour(band)
		assert_eq(TimeService.band_for_minutes(hour * 60.0, ContentDB.balance["time"]["band_starts_hour"]), band)
