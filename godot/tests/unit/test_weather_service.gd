extends TestCase

## P0-021: weather clear / cloudy / rain — data-driven cycle, no flicker, region-restricted.

const REGION := "region_01_quiet_pond"

func _service(seed_value: int = 1) -> WeatherService:
	var service := WeatherService.new()
	service.rng.seed = seed_value
	service.start(REGION)
	return service

func test_slice_weather_definitions_exist_for_the_region() -> void:
	for weather_id in ContentDB.get_region(REGION)["weather"]:
		assert_false(ContentDB.get_weather(weather_id).is_empty(), "%s undefined" % weather_id)

func test_starts_clear_and_announces_it() -> void:
	var announced: Array = []
	var handler := func(weather_id: String) -> void: announced.append(weather_id)
	EventBus.weather_changed.connect(handler)
	var service := _service()
	EventBus.weather_changed.disconnect(handler)
	assert_eq(service.current_id, "clear")
	assert_deep_eq(announced, ["clear"])
	assert_eq(service.blend, 1.0)
	service.free()

func test_every_stay_lasts_at_least_its_minimum_and_transitions_are_gentle() -> void:
	var service := _service(7)
	var changes: Array = []  # [time, from, to]
	var clock := [0.0]
	var handler := func(weather_id: String) -> void: changes.append([clock[0], weather_id])
	EventBus.weather_changed.connect(handler)
	var dt := 1.0
	for i in 3 * 86400 / 24:  # three game days of real time at 24 min per day = 3 * 1440 s
		clock[0] += dt
		service.advance(dt)
	EventBus.weather_changed.disconnect(handler)
	assert_true(changes.size() >= 4, "weather should change over three days (changes: %d)" % changes.size())
	for i in range(1, changes.size()):
		var stay: float = changes[i][0] - changes[i - 1][0]
		var previous_id: String = changes[i - 1][1]
		var minimum: float = ContentDB.get_weather(previous_id)["duration_sec"]["min"]
		assert_true(stay >= minimum - dt, "%s lasted only %.0fs (minimum %.0fs)" % [previous_id, stay, minimum])
	service.free()

func test_only_the_regions_weather_is_ever_chosen() -> void:
	var allowed: Array = ContentDB.get_region(REGION)["weather"]
	var service := _service(3)
	var seen := {}
	var handler := func(weather_id: String) -> void: seen[weather_id] = true
	EventBus.weather_changed.connect(handler)
	for i in 20000:
		service.advance(1.0)
	EventBus.weather_changed.disconnect(handler)
	for weather_id in seen:
		assert_true(weather_id in allowed, "%s is not a weather of the region" % weather_id)
	assert_true(seen.size() >= 3, "all three weathers should occur: %s" % [seen.keys()])
	service.free()

func test_blend_eases_from_zero_to_one_during_a_transition() -> void:
	var service := _service(5)
	assert_true(service.set_weather("rain"))
	assert_eq(service.previous_id, "clear")
	assert_eq(service.blend, 0.0)
	var last := 0.0
	var transition: float = ContentDB.get_weather("rain")["transition_sec"]
	for i in int(transition) + 2:
		service.advance(1.0)
		assert_true(service.blend >= last, "blend went backwards")
		last = service.blend
	assert_eq(service.blend, 1.0)
	service.free()

func test_visual_blends_between_previous_and_current() -> void:
	var service := _service()
	var clear_visual := service.visual()
	assert_eq(clear_visual["rain"], 0.0)
	service.set_weather("rain")
	var at_start := service.visual()
	assert_true(absf(at_start["rain"] - 0.0) < 0.001, "no rain at the start of the transition")
	service.advance(ContentDB.get_weather("rain")["transition_sec"] / 2.0)
	var halfway := service.visual()
	assert_true(halfway["rain"] > 0.0 and halfway["rain"] < 1.0, "rain %.2f" % halfway["rain"])
	assert_true(halfway["brightness"] < clear_visual["brightness"])
	service.advance(60.0)
	var settled := service.visual()
	assert_true(absf(settled["rain"] - 1.0) < 0.001)
	assert_true(settled["tint"] is Color)
	service.free()

func test_set_weather_rejects_unknown_and_undefined_weather() -> void:
	var service := _service()
	assert_false(service.set_weather("snow"))
	assert_false(service.set_weather("storm"), "storms belong to other regions, not the pond")
	assert_eq(service.current_id, "clear")
	assert_true(service.set_weather("cloudy"))
	assert_eq(service.current_id, "cloudy")
	service.free()

func test_same_seed_gives_the_same_weather_sequence() -> void:
	var sequences: Array = []
	for run in 2:
		var service := _service(11)
		var sequence: Array = []
		var handler := func(weather_id: String) -> void: sequence.append(weather_id)
		EventBus.weather_changed.connect(handler)
		for i in 6000:
			service.advance(1.0)
		EventBus.weather_changed.disconnect(handler)
		sequences.append(sequence)
		service.free()
	assert_deep_eq(sequences[0], sequences[1])

func test_advancing_before_start_or_with_bad_delta_is_harmless() -> void:
	var idle := WeatherService.new()
	idle.advance(10.0)
	assert_eq(idle.current_id, "")
	assert_eq(idle.visual()["rain"], 0.0)
	idle.free()
	var service := _service()
	service.advance(-5.0)
	service.advance(0.0)
	assert_eq(service.current_id, "clear")
	service.free()
