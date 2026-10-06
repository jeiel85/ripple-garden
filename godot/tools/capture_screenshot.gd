extends SceneTree

## Developer tool: runs the game scene in a real window, applies a scenario and saves a PNG, so
## visual work can be reviewed without playing. Not part of the game (excluded from exports).
##
## godot --path godot -s res://tools/capture_screenshot.gd -- --out=C:/tmp/shot.png [options]
##
##   --level=N       restoration level 0..5          --hour=H       game hour 0..24
##   --weather=ID    clear | cloudy | rain           --populate=N   N of every species released
##   --panel=NAME    journal | gear | restore | settings | debug | licenses | water_mind
##   --state=NAME    wait | fight | inspect          --seed=N       RNG seed for the scenario
##   --frames=N      frames to run before capture (default 40)
##   --hc            high contrast + large UI        --reduced      reduced motion
##   --size=WxH      window size (default 405x720)

var _args := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var size_text: String = _args.get("size", "405x720")
	var size_parts := size_text.split("x")
	root.size = Vector2i(int(size_parts[0]), int(size_parts[1]))
	# Autoloads are not compile-time names in a SceneTree script, so fetch them from the tree.
	var save_service: Node = root.get_node("SaveService")
	var game_state: Node = root.get_node("GameState")
	var content: Node = root.get_node("ContentDB")
	var time_service: Node = root.get_node("TimeService")
	save_service.write_blocked = true  # a capture must never touch the player's save
	game_state.new_game()

	var packed: PackedScene = load("res://world/game_root.tscn")
	var game: Node = packed.instantiate()
	game.load_save = false
	root.add_child(game)
	await process_frame
	var region_id: String = game.region_id
	# Project classes cannot be named statically here: this script compiles before the autoloads exist.
	var states: Dictionary = load("res://fishing/fishing_controller.gd").State

	if _args.has("hc"):
		game_state.set_setting("high_contrast_meter", true)
		game_state.set_setting("large_ui", true)
	if _args.has("reduced"):
		game_state.set_setting("reduced_motion", true)
	if _args.has("populate"):
		for fish_def in content.get_fish_for_region(region_id):
			game_state.record_encounter(fish_def["id"], float(fish_def["size_cm"]["min"]), fish_def["behavior"])
			game_state.add_population(region_id, fish_def["id"], int(_args["populate"]))
	if _args.has("level"):
		game_state.add_restoration_points(region_id, 100000)
		game_state.set_restoration_level(region_id, int(_args["level"]))
		game.region.apply_level(int(_args["level"]), false)
	if _args.has("hour"):
		time_service.set_game_minutes(float(_args["hour"]) * 60.0)
	if _args.has("weather"):
		game.region.weather.set_weather(_args["weather"])
		game.region.weather.advance(60.0)
	if _args.has("seed"):
		game.fishing.set_seed(int(_args["seed"]))
	game.region.fish_presenter.refresh()

	match _args.get("state", ""):
		"wait", "fight", "inspect":
			game.fishing.spawn_fish("fish_crucian_carp")
			game.ui.world_input.cast_quick()
			_advance(game, 1.5)
			if _args["state"] != "wait":
				_advance(game, 60.0, states["BITE_HINT"])
				game.fishing.tap()
				_advance(game, 1.0)
			if _args["state"] == "inspect":
				while game.fishing.state == states["FIGHT"]:
					game.fishing.set_reeling(game.fishing.fight.tension < 0.5)
					game.fishing.advance(1.0 / 30.0)
				_advance(game, 3.0, states["INSPECT"])

	match _args.get("panel", ""):
		"journal": game.ui.open_journal()
		"gear": game.ui._open(game.ui.gear_panel)
		"restore": game.ui.open_restoration()
		"settings": game.ui._open(game.ui.settings_panel)
		"debug": game.ui.toggle_debug_menu()
		"water_mind": game.ui.enter_water_mind()
		"licenses":
			game.ui.licenses_panel.show_text("Licenses", load("res://ui/text_panel.gd").licenses_text())
			game.ui._open(game.ui.licenses_panel)

	for i in int(_args.get("frames", "40")):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var out_path: String = _args.get("out", "user://capture.png")
	var error := image.save_png(out_path)
	print("captured %s (%dx%d) error=%s" % [out_path, image.get_width(), image.get_height(), error_string(error)])
	quit(0 if error == OK else 1)

## Steps the fishing controller forward without waiting for real time, optionally until `until`.
func _advance(game: Node, seconds: float, until: int = -1) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		if until >= 0 and game.fishing.state == until:
			return
		game.fishing.advance(1.0 / 30.0)
		elapsed += 1.0 / 30.0
