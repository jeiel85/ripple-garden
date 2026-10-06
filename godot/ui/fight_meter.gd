class_name FightMeter
extends Control

## The line-tension meter shown while hooking and fighting (UI_UX §4 Fight). It never relies on
## colour alone: the safe band is a labelled bracket with a solid fill, the current tension is a
## marker whose *position* and a word ("Just right" / "Too tight" / "Too loose") say the same
## thing, and High Contrast adds hatching and thick outlines. A thin bar below shows how close
## the fish is to landing.

const BAR_HEIGHT := 44.0
const MARKER_SIZE := 22.0

var tension := 0.5
var progress := 0.0
var band_min := 0.3
var band_max := 0.75
var high_contrast := false

var _word: Label
var _bar_rect := Rect2()

func _init() -> void:
	custom_minimum_size = Vector2(560, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word = Label.new()
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_word)

func _ready() -> void:
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_word.position = Vector2(0, 0)
	_word.size = Vector2(size.x, 40)
	_bar_rect = Rect2(20, 62, size.x - 40, BAR_HEIGHT)
	queue_redraw()

## Updates the meter from the fight's numbers. `in_band` words are localised here.
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

func _draw() -> void:
	if _bar_rect.size.x <= 0.0:
		return
	var outline := Color.WHITE if high_contrast else Color(1, 1, 1, 0.35)
	var outline_width := 4.0 if high_contrast else 2.0
	draw_rect(_bar_rect, Color(0.04, 0.1, 0.12, 0.9), true)

	# Safe band: solid fill with an up/down bracket at both ends.
	var safe := Rect2(_x_at(band_min), _bar_rect.position.y, _x_at(band_max) - _x_at(band_min), BAR_HEIGHT)
	draw_rect(safe, Color(0.36, 0.72, 0.52, 0.85 if high_contrast else 0.6), true)
	if high_contrast:
		# Hatch the unsafe zones so they differ from the safe zone by pattern, not hue.
		for zone in [Rect2(_bar_rect.position.x, _bar_rect.position.y, safe.position.x - _bar_rect.position.x, BAR_HEIGHT),
				Rect2(safe.end.x, _bar_rect.position.y, _bar_rect.end.x - safe.end.x, BAR_HEIGHT)]:
			var x: float = zone.position.x
			while x < zone.end.x:
				draw_line(Vector2(x, zone.end.y), Vector2(minf(x + BAR_HEIGHT, zone.end.x), zone.position.y + maxf(0.0, BAR_HEIGHT - (zone.end.x - x))), Color(1, 1, 1, 0.55), 2.0)
				x += 14.0
	for edge_x in [safe.position.x, safe.end.x]:
		draw_line(Vector2(edge_x, _bar_rect.position.y - 8), Vector2(edge_x, _bar_rect.end.y + 8), Color.WHITE, 3.0)
	draw_rect(_bar_rect, outline, false, outline_width)

	# Tension marker: a triangle above the bar plus a line through it.
	var marker_x := _x_at(tension)
	var in_band := tension >= band_min and tension <= band_max
	var marker_color := Color("#fff3c4") if in_band else Color("#ff9a8a")
	draw_line(Vector2(marker_x, _bar_rect.position.y - 4), Vector2(marker_x, _bar_rect.end.y + 4), marker_color, 5.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(marker_x - MARKER_SIZE / 2.0, _bar_rect.position.y - 6 - MARKER_SIZE),
		Vector2(marker_x + MARKER_SIZE / 2.0, _bar_rect.position.y - 6 - MARKER_SIZE),
		Vector2(marker_x, _bar_rect.position.y - 6)]), marker_color)

	# Landing progress.
	var progress_rect := Rect2(_bar_rect.position.x, _bar_rect.end.y + 22, _bar_rect.size.x, 14)
	draw_rect(progress_rect, Color(0.04, 0.1, 0.12, 0.9), true)
	draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * clampf(progress, 0.0, 1.0), progress_rect.size.y)), Color("#7fd0e8"), true)
	draw_rect(progress_rect, outline, false, outline_width * 0.6)
