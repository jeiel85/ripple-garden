class_name PhotoMode
extends Control

## Photo mode (P1-009, GDD §17): entered from water-mind's "저장" button. The player frames the pond
## before taking the picture:
##   drag            pan the camera (kept inside the composed diorama)
##   pinch / wheel   zoom, also the + and − buttons for one-handed or switch play
##   액자            cycles a frame drawn over the picture (none, polaroid with place and date, wood, soft edges)
##   로고            the small "Ripple Garden" signature in the corner, on or off
##   촬영            hides these controls for one frame and saves what is left (picture, frame, signature)
##   돌아가기        back to water-mind with the camera where it was
## Saving to the phone's gallery and the OS share sheet are platform work (GDD §17); the picture goes to
## the game's own folder through PhotoSaver.

signal shutter_pressed
signal closed
signal message(text: String)

const FRAMES: PackedStringArray = ["none", "polaroid", "wood", "soft"]
const MIN_ZOOM := 1.0
const MAX_ZOOM := 2.5
const ZOOM_STEP := 1.25
## The composed diorama (720x1280 design space); panning never shows past it.
const BOUNDS := Rect2(0, 0, 720, 1280)
const POLAROID_STRIP := 160.0

var active := false
var frame_id := "none"
var logo := true
var zoom := 1.0
var center := CameraController.DESIGN_CENTER

var _camera: CameraController = null
var _picture: PhotoFrame
var _controls: Control
var _frame_button: Button
var _logo_button: Button
var _zoom_in: Button
var _zoom_out: Button
var _dragging := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_picture = PhotoFrame.new()
	add_child(_picture)

	_controls = Control.new()
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_controls)

	var row := UiKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -POLAROID_STRIP  # above the polaroid's caption strip, so the frame reads while composing
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.round_button("back", tr("ui.photo.back"), exit, true, 120.0))
	_frame_button = UiKit.round_button("frame", tr("ui.photo.frame"), cycle_frame, true, 120.0)
	row.add_child(_frame_button)
	var shutter := UiKit.round_button("camera", tr("ui.photo.shutter"), func() -> void: shutter_pressed.emit(), true, 150.0)
	shutter.theme_type_variation = "GreenCircle"
	row.add_child(shutter)
	_logo_button = UiKit.round_button("signature", tr("ui.photo.logo_on"), toggle_logo, true, 120.0)
	row.add_child(_logo_button)
	_controls.add_child(row)

	var zoom_column := UiKit.vbox(12)
	zoom_column.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	zoom_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	zoom_column.offset_right = -20
	zoom_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_in = UiKit.round_button("zoom_in", tr("ui.photo.zoom_in"), func() -> void: set_zoom(zoom * ZOOM_STEP))
	_zoom_out = UiKit.round_button("zoom_out", tr("ui.photo.zoom_out"), func() -> void: set_zoom(zoom / ZOOM_STEP))
	zoom_column.add_child(_zoom_in)
	zoom_column.add_child(_zoom_out)
	_controls.add_child(zoom_column)

## Opens photo mode over the scene. `caption` is the polaroid's line (place and date).
func enter(camera: CameraController, caption: String) -> void:
	if active:
		return
	active = true
	visible = true
	_camera = camera
	_picture.caption = caption
	zoom = 1.0
	center = CameraController.DESIGN_CENTER
	show_controls()
	_apply_view()
	_refresh()
	message.emit(tr("ui.photo.hint"))

func exit() -> void:
	if not active:
		return
	active = false
	visible = false
	_dragging = false
	if _camera != null:
		_camera.clear_focus(0.0)
	closed.emit()

func cycle_frame() -> void:
	var index := FRAMES.find(frame_id)
	frame_id = FRAMES[(index + 1) % FRAMES.size()]
	_refresh()

func toggle_logo() -> void:
	logo = not logo
	_refresh()

func set_zoom(value: float) -> void:
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_apply_view()
	_refresh()

## Moves the view by a drag of `screen_delta` pixels (the scene follows the finger).
func pan(screen_delta: Vector2) -> void:
	center -= screen_delta / zoom
	_apply_view()

## Moves the controls out of a notch and the gesture bar; the frame stays on the screen's edges.
func apply_insets(top: float, bottom: float) -> void:
	_controls.offset_top = top
	_controls.offset_bottom = -bottom

## The controls are hidden for the one captured frame; the frame and signature stay.
func hide_controls() -> void:
	_controls.visible = false

func show_controls() -> void:
	_controls.visible = true

func controls_visible() -> bool:
	return _controls.visible

## The camera centre that keeps a view of `view_size` at `zoom_level` inside `bounds` (centred on an
## axis where the view is wider than the bounds).
static func clamp_center(point: Vector2, zoom_level: float, view_size: Vector2, bounds: Rect2) -> Vector2:
	var half := view_size / (2.0 * zoom_level)
	var result := point
	for axis in 2:
		var lo := bounds.position[axis] + half[axis]
		var hi := bounds.end[axis] - half[axis]
		result[axis] = (bounds.position[axis] + bounds.end[axis]) * 0.5 if lo > hi else clampf(point[axis], lo, hi)
	return result

func _apply_view() -> void:
	center = clamp_center(center, zoom, get_viewport_rect().size if is_inside_tree() else BOUNDS.size, BOUNDS)
	if _camera != null:
		_camera.focus_on(center, zoom, 0.0)

func _refresh() -> void:
	_picture.frame_id = frame_id
	_picture.logo = logo
	_picture.queue_redraw()
	_frame_button.text = tr("ui.photo.frame." + frame_id)
	_frame_button.tooltip_text = tr("ui.photo.frame") + " · " + _frame_button.text
	_logo_button.text = tr("ui.photo.logo_on") if logo else tr("ui.photo.logo_off")
	_logo_button.tooltip_text = _logo_button.text
	_zoom_in.disabled = zoom >= MAX_ZOOM - 0.001
	_zoom_out.disabled = zoom <= MIN_ZOOM + 0.001

func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom * ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom / ZOOM_STEP)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan((event as InputEventMouseMotion).relative)
		accept_event()
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom * (event as InputEventMagnifyGesture).factor)
		accept_event()


## What is drawn over the picture and saved with it: the chosen frame and the signature.
class PhotoFrame extends Control:
	const POLAROID_SIDE := 28.0
	const POLAROID_BOTTOM := PhotoMode.POLAROID_STRIP
	const WOOD_WIDTH := 34.0
	const SOFT_DEPTH := 150.0
	const SIGNATURE := "Ripple Garden"

	var frame_id := "none"
	var logo := true
	var caption := ""

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		var font := get_theme_default_font()
		var font_size := get_theme_default_font_size()
		match frame_id:
			"polaroid":
				_border(area, Vector4(POLAROID_SIDE, POLAROID_SIDE, POLAROID_SIDE, POLAROID_BOTTOM), UiTheme.PAPER)
				draw_rect(area.grow_individual(-POLAROID_SIDE, -POLAROID_SIDE, -POLAROID_SIDE, -POLAROID_BOTTOM), UiTheme.CREAM_BORDER, false, 2.0)
				var baseline := area.end.y - POLAROID_BOTTOM * 0.5 + font_size * 0.35
				draw_string(font, Vector2(POLAROID_SIDE + 8.0, baseline), caption, HORIZONTAL_ALIGNMENT_LEFT,
					area.size.x * 0.6, font_size, UiTheme.INK)
			"wood":
				_border(area, Vector4(WOOD_WIDTH, WOOD_WIDTH, WOOD_WIDTH, WOOD_WIDTH), UiTheme.WOOD)
				draw_rect(area.grow(-3.0), UiTheme.WOOD_BORDER, false, 4.0)
				draw_rect(area.grow(-WOOD_WIDTH), UiTheme.WOOD_BORDER, false, 4.0)
				for i in 6:  # a little grain
					var y := WOOD_WIDTH * (0.25 + 0.1 * i)
					draw_line(Vector2(WOOD_WIDTH, y), Vector2(area.size.x - WOOD_WIDTH, y), Color(UiTheme.WOOD_BORDER, 0.35), 1.5)
					draw_line(Vector2(WOOD_WIDTH, area.size.y - y), Vector2(area.size.x - WOOD_WIDTH, area.size.y - y), Color(UiTheme.WOOD_BORDER, 0.35), 1.5)
			"soft":
				_soft_edges(area)
		if logo:
			var text_size := font.get_string_size(SIGNATURE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var inset := Vector2(POLAROID_SIDE + 8.0, POLAROID_BOTTOM * 0.5 - font_size * 0.35) if frame_id == "polaroid" \
				else Vector2(WOOD_WIDTH + 18.0, WOOD_WIDTH + 18.0) if frame_id == "wood" else Vector2(26.0, 30.0)
			var at := Vector2(area.end.x - inset.x - text_size.x, area.end.y - inset.y)
			var ink := UiTheme.INK_DIM if frame_id == "polaroid" else Color(1, 1, 1, 0.9)
			if frame_id != "polaroid":
				draw_string(font, at + Vector2(2, 2), SIGNATURE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.35))
			draw_string(font, at, SIGNATURE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

	## Four bands around `area`: left, top, right, bottom widths in x, y, z, w.
	func _border(area: Rect2, widths: Vector4, color: Color) -> void:
		draw_rect(Rect2(area.position, Vector2(widths.x, area.size.y)), color)
		draw_rect(Rect2(area.position, Vector2(area.size.x, widths.y)), color)
		draw_rect(Rect2(Vector2(area.end.x - widths.z, area.position.y), Vector2(widths.z, area.size.y)), color)
		draw_rect(Rect2(Vector2(area.position.x, area.end.y - widths.w), Vector2(area.size.x, widths.w)), color)

	## Edges that fade into a warm shade, like an old photograph.
	func _soft_edges(area: Rect2) -> void:
		var shade := Color(0.16, 0.11, 0.06, 0.45)
		var clear := Color(shade, 0.0)
		var outer := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
		var inner_rect := area.grow(-SOFT_DEPTH)
		var inner := [inner_rect.position, Vector2(inner_rect.end.x, inner_rect.position.y), inner_rect.end, Vector2(inner_rect.position.x, inner_rect.end.y)]
		for i in 4:
			var j := (i + 1) % 4
			draw_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), PackedColorArray([shade, shade, clear, clear]))
