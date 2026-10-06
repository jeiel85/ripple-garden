extends TestCase

## P1-009 photo mode (GDD §17): from water-mind's save button the player frames the pond (pan, zoom),
## picks a frame and the signature, and takes the picture; leaving puts the camera back.

const SCENE := "res://world/game_root.tscn"

var _was_blocked := false

func _start() -> GameRoot:
	GameState.new_game()
	var save_service: Node = tree.root.get_node("SaveService")
	_was_blocked = save_service.write_blocked
	save_service.write_blocked = true
	var root: GameRoot = (load(SCENE) as PackedScene).instantiate()
	root.load_save = false
	tree.root.add_child(root)
	return root

func _stop(root: GameRoot) -> void:
	root.free()
	GameState.new_game()
	tree.root.get_node("SaveService").write_blocked = _was_blocked

func _open(root: GameRoot) -> PhotoMode:
	root.ui.enter_water_mind()
	root.ui.water_mind.photo_requested.emit()
	return root.ui.photo_mode

# --- framing ---

func test_the_view_never_leaves_the_diorama() -> void:
	var bounds := PhotoMode.BOUNDS
	var view := bounds.size
	assert_eq(PhotoMode.clamp_center(Vector2(0, 0), 1.0, view, bounds), CameraController.DESIGN_CENTER, "at 1x there is nowhere to pan")
	var zoomed := PhotoMode.clamp_center(Vector2(-500, 5000), 2.0, view, bounds)
	assert_eq(zoomed, Vector2(180, 960), "at 2x the view stops at the corner")
	var wide := PhotoMode.clamp_center(Vector2(10, 640), 1.0, Vector2(1000, 1280), bounds)
	assert_eq(wide.x, 360.0, "a view wider than the diorama stays centred")

func test_the_save_button_opens_photo_mode_instead_of_shooting_at_once() -> void:
	var root := _start()
	var photo := _open(root)
	assert_true(photo.active)
	assert_true(photo.controls_visible())
	assert_false(root.ui.water_mind.is_chrome_visible(), "the water-mind buttons step aside")
	assert_true(root.ui.water_mind.idle_paused, "the picture must not dim while it is framed")
	root.ui.water_mind._process(9999.0)
	assert_false(root.ui.water_mind.is_dimmed())
	_stop(root)

func test_zoom_and_pan_move_the_camera_and_back_restores_it() -> void:
	var root := _start()
	var photo := _open(root)
	photo.set_zoom(2.0)
	assert_true(root.camera.zoom.is_equal_approx(Vector2.ONE * 2.0))
	photo.pan(Vector2(100, -100))  # dragging right and up shows more to the left and below
	assert_true(root.camera.position.x < CameraController.DESIGN_CENTER.x)
	assert_true(root.camera.position.y > CameraController.DESIGN_CENTER.y)
	photo.set_zoom(99.0)
	assert_eq(photo.zoom, PhotoMode.MAX_ZOOM)
	assert_true(photo._zoom_in.disabled)
	photo.set_zoom(0.1)
	assert_eq(photo.zoom, PhotoMode.MIN_ZOOM)
	assert_true(photo._zoom_out.disabled)
	photo.set_zoom(1.5)
	photo.exit()
	assert_false(photo.active)
	assert_true(root.camera.zoom.is_equal_approx(Vector2.ONE), "the camera is the diorama's again")
	assert_true(root.camera.position.is_equal_approx(CameraController.DESIGN_CENTER))
	assert_true(root.ui.water_mind.active, "back to water-mind, not out of it")
	assert_true(root.ui.water_mind.is_chrome_visible())
	assert_false(root.ui.water_mind.idle_paused)
	_stop(root)

func test_frames_cycle_and_the_signature_toggles() -> void:
	var root := _start()
	var photo := _open(root)
	var seen: Array[String] = []
	for i in PhotoMode.FRAMES.size():
		seen.append(photo.frame_id)
		photo.cycle_frame()
	assert_eq(photo.frame_id, PhotoMode.FRAMES[0], "the frames go round")
	assert_eq(seen.size(), PhotoMode.FRAMES.size())
	assert_true(photo.logo)
	photo.toggle_logo()
	assert_false(photo.logo)
	assert_eq(photo._logo_button.text, String(TranslationServer.translate("ui.photo.logo_off")))
	_stop(root)

func test_the_capture_hides_the_controls_but_keeps_the_frame() -> void:
	var root := _start()
	var photo := _open(root)
	photo.cycle_frame()
	var hidden := root.ui.hide_for_photo()
	assert_false(photo.controls_visible(), "no buttons in the picture")
	assert_true(photo._picture.is_visible_in_tree(), "the frame and signature belong to the picture")
	assert_false(root.ui.toast.visible)
	root.ui.restore_after_photo(hidden)
	assert_true(photo.controls_visible())
	assert_false(root.ui.water_mind.is_chrome_visible(), "water-mind stays tucked away behind photo mode")
	_stop(root)

func test_leaving_water_mind_also_leaves_photo_mode() -> void:
	var root := _start()
	var photo := _open(root)
	photo.set_zoom(2.0)
	root.ui.water_mind.exit()
	assert_false(photo.active)
	assert_true(root.camera.zoom.is_equal_approx(Vector2.ONE))
	_stop(root)

func test_photo_mode_controls_fit_a_phone() -> void:
	var host := Control.new()
	host.size = Vector2(720, 1280)
	host.theme = UiTheme.build(1.0, false, false)
	tree.root.add_child(host)
	var photo := PhotoMode.new()
	host.add_child(photo)
	photo.enter(null, "")
	await tree.process_frame
	await tree.process_frame
	for button in [photo._frame_button, photo._logo_button, photo._zoom_in, photo._zoom_out]:
		var rect: Rect2 = (button as Button).get_global_rect()
		assert_true(rect.position.x >= -1.0 and rect.end.x <= 721.0 and rect.end.y <= 1281.0, "%s at %s" % [button.tooltip_text, rect])
		assert_true(rect.size.x >= UiTheme.TOUCH_MIN_PX - 0.5 and rect.size.y >= UiTheme.TOUCH_MIN_PX - 0.5)
	assert_false(photo._zoom_in.get_global_rect().intersects(photo._zoom_out.get_global_rect()), "the zoom buttons do not overlap")
	host.free()

func test_framing_wins_over_a_restoration_pulse() -> void:
	var camera := CameraController.new()
	tree.root.add_child(camera)
	camera.restoration_pulse(3.0)
	camera.focus_on(Vector2(300, 700), 2.0, 0.0)
	if camera._tween != null and camera._tween.is_valid():
		camera._tween.custom_step(3.0)  # play the pulse to its end
	assert_true(camera.zoom.is_equal_approx(Vector2.ONE * 2.0), "the pulse must not pull the photo's zoom back (zoom %s)" % camera.zoom)
	camera.free()

# Found on the emulator: Japanese captions spilled out of the round buttons.
func test_round_button_captions_fit_their_circle_in_every_language() -> void:
	var previous := TranslationServer.get_locale()
	var theme := UiTheme.build(1.0, false, false)
	var font: Font = theme.default_font if theme.default_font != null else ThemeDB.fallback_font
	var size: int = theme.get_font_size("font_size", "RoundButton")
	for locale in ["ko", "en", "ja"]:
		TranslationServer.set_locale(locale)
		var keys: Array = ["ui.photo.back", "ui.photo.shutter", "ui.photo.logo_on", "ui.photo.logo_off",
			"ui.water_mind.save", "ui.water_mind.time", "ui.water_mind.weather", "ui.water_mind.bgm"]
		for frame_id in PhotoMode.FRAMES:
			keys.append("ui.photo.frame." + frame_id)
		for key in keys:
			var text := String(TranslationServer.translate(key))
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			assert_true(width <= 120.0 - 20.0, "%s %s '%s' is %.0f px wide for a 120 px circle" % [locale, key, text, width])
	TranslationServer.set_locale(previous)

# Found on the emulator: the water-mind hint lay over the water-mind buttons.
func test_messages_sit_above_whatever_holds_the_bottom() -> void:
	var root := _start()
	root.ui.apply_insets(0.0, 40.0)
	assert_eq(root.ui.toast.offset_bottom, -(UIController.TOAST_BOTTOM + 40.0), "above the navigation row and the gesture bar")
	root.ui.enter_water_mind()
	assert_eq(root.ui.toast.offset_bottom, -(UIController.WATER_MIND_TOAST_BOTTOM + 40.0))
	root.ui.open_photo_mode()
	assert_eq(root.ui.toast.offset_bottom, -(UIController.PHOTO_TOAST_BOTTOM + 40.0))
	root.ui.photo_mode.exit()
	assert_eq(root.ui.toast.offset_bottom, -(UIController.WATER_MIND_TOAST_BOTTOM + 40.0))
	root.ui.water_mind.exit()
	assert_eq(root.ui.toast.offset_bottom, -(UIController.TOAST_BOTTOM + 40.0))
	_stop(root)
