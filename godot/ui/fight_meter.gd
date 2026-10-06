class_name FightMeter
extends Control

## The line-tension meter shown while fighting (UI_UX §4 Fight), drawn like the bite/reel mockup: a
## rounded bar that runs from "weak" through the green safe band to "strong", with a fish riding on
## a marker at the current tension. It never relies on colour alone: the safe band has white
## brackets, the marker's *position* and the caption under the bar ("Just right" / "Too tight" /
## "Too loose") say the same thing, and High Contrast adds hatching to the unsafe zones and thick
## outlines. Landing progress is the ring around the round reel button (Hud.ReelButton).

const BAR_HEIGHT := 40.0
const MARKER_WIDTH := 12.0

var tension := 0.5
var progress := 0.0
var band_min := 0.3
var band_max := 0.75
var high_contrast := false

var _word: Label
var _weak: Label
var _strong: Label
var _bar_rect := Rect2()

func _init() -> void:
	custom_minimum_size = Vector2(560, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word = _caption(HORIZONTAL_ALIGNMENT_CENTER)
	_weak = _caption(HORIZONTAL_ALIGNMENT_LEFT)
	_strong = _caption(HORIZONTAL_ALIGNMENT_RIGHT)
	_weak.text = tr("ui.fight.weak")
	_strong.text = tr("ui.fight.strong")

func _caption(align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.theme_type_variation = "LightLabel"
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _ready() -> void:
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_bar_rect = Rect2(24, 46, size.x - 48, BAR_HEIGHT)
	var caption_y := _bar_rect.end.y + 6
	_word.position = Vector2(0, caption_y)
	_word.size = Vector2(size.x, 40)
	_weak.position = Vector2(_bar_rect.position.x, caption_y)
	_weak.size = Vector2(size.x * 0.3, 40)
	_strong.position = Vector2(_bar_rect.end.x - size.x * 0.3, caption_y)
	_strong.size = Vector2(size.x * 0.3, 40)
	queue_redraw()

## Updates the meter from the fight's numbers; the caption names the state in words.
func update_values(new_tension: float, new_progress: float) -> void:
	tension = new_tension
	progress = new_progress
	if tension > band_max:
		_word.text = tr("ui.fight.tension.high")
	elif tension < band_min:
		_word.text = tr("ui.fight.tension.low")
	else:
		_word.text = tr("ui.fight.tension.ok")
	queue_redraw()

func configure(p_band_min: float, p_band_max: float, p_high_contrast: bool) -> void:
	band_min = p_band_min
	band_max = p_band_max
	high_contrast = p_high_contrast
	queue_redraw()

func _x_at(value: float) -> float:
	return _bar_rect.position.x + _bar_rect.size.x * clampf(value, 0.0, 1.0)

## Colour of the bar at tension `value`: deep brown at the ends, orange towards the band, teal at the
## band's edges and fresh green in its middle (the mockup's gradient).
func _color_at(value: float) -> Color:
	var brown := Color("#5a3826")
	var orange := Color("#e0874a")
	var teal := Color("#3fb3a5")
	var green := Color("#9ad67a")
	if value < band_min:
		return brown.lerp(orange, clampf(value / maxf(band_min, 0.001), 0.0, 1.0))
	if value > band_max:
		return orange.lerp(brown, clampf((value - band_max) / maxf(1.0 - band_max, 0.001), 0.0, 1.0))
	var mid := (band_min + band_max) / 2.0
	var half := maxf((band_max - band_min) / 2.0, 0.001)
	return green.lerp(teal, clampf(absf(value - mid) / half, 0.0, 1.0))

func _draw() -> void:
	if _bar_rect.size.x <= 0.0:
		return
	var radius := BAR_HEIGHT / 2.0
	# Frame: a dark rounded rim, then the gradient in segments.
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.16, 0.1, 0.06, 0.92)
	frame.set_corner_radius_all(int(radius + 6))
	frame.border_color = Color.WHITE if high_contrast else Color(1, 0.94, 0.8, 0.55)
	frame.set_border_width_all(4 if high_contrast else 3)
	frame.anti_aliasing = true
	draw_style_box(frame, _bar_rect.grow(6))
	var segments := 48
	for i in segments:
		var from := float(i) / segments
		var to := float(i + 1) / segments
		var rect := Rect2(_x_at(from), _bar_rect.position.y, _x_at(to) - _x_at(from) + 0.6, BAR_HEIGHT)
		draw_rect(rect, _color_at((from + to) / 2.0), true)

	if high_contrast:
		# Hatch the unsafe zones so they differ from the safe zone by pattern, not hue.
		for zone in [Rect2(_bar_rect.position.x, _bar_rect.position.y, _x_at(band_min) - _bar_rect.position.x, BAR_HEIGHT),
				Rect2(_x_at(band_max), _bar_rect.position.y, _bar_rect.end.x - _x_at(band_max), BAR_HEIGHT)]:
			var x: float = zone.position.x
			while x < zone.end.x:
				draw_line(Vector2(x, zone.end.y), Vector2(minf(x + BAR_HEIGHT, zone.end.x), zone.position.y + maxf(0.0, BAR_HEIGHT - (zone.end.x - x))), Color(1, 1, 1, 0.7), 2.0)
				x += 14.0
	# Safe band brackets.
	for edge_x in [_x_at(band_min), _x_at(band_max)]:
		draw_line(Vector2(edge_x, _bar_rect.position.y - 6), Vector2(edge_x, _bar_rect.end.y + 6), Color.WHITE, 3.0)

	# Marker: a cream post through the bar with a small fish riding on top.
	var marker_x := _x_at(tension)
	var in_band := tension >= band_min and tension <= band_max
	var marker_color := Color("#fff6dc") if in_band else Color("#ffd2c4")
	var post := Rect2(marker_x - MARKER_WIDTH / 2.0, _bar_rect.position.y - 8, MARKER_WIDTH, BAR_HEIGHT + 16)
	var post_box := StyleBoxFlat.new()
	post_box.bg_color = marker_color
	post_box.set_corner_radius_all(6)
	post_box.border_color = Color(0.3, 0.2, 0.1, 0.8)
	post_box.set_border_width_all(2)
	draw_style_box(post_box, post)
	var fish := UiIcons.texture("fish")
	var fish_size := Vector2(46, 46)
	draw_texture_rect(fish, Rect2(Vector2(marker_x - fish_size.x / 2.0, post.position.y - fish_size.y - 2), fish_size), false,
		Color.WHITE if in_band else Color("#ffd2c4"))
