class_name WaterfallView
extends Node2D

## The little waterfall at the pond's upper right (main-world mockup, D-018): a sheet of water falling
## over a rock lip into a ring of foam. Streaks slide down the sheet; the picture is redrawn a few
## times a second (the graphics profile's waterfall_fps), never every frame, and Reduced Motion freezes it. The surrounding rocks
## are ordinary props in the layout. Placeholder until the animated sheet in
## assets/design/ASSET_REQUESTS.md §1 arrives.

const STREAKS := 9

var area := Rect2()
var reduced_motion := false
## Seconds between redraws (from the graphics profile).
var frame_sec := 1.0 / 12.0
## 0..1 how lively the water looks (the restoration level's share of the best palette).
var flow := 1.0

var _clock := 0.0
var _frame_timer := 0.0

func setup(rect: Rect2) -> void:
	area = rect
	queue_redraw()

func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion:
		return
	_clock += delta
	_frame_timer += delta
	if _frame_timer >= frame_sec:
		_frame_timer = 0.0
		queue_redraw()

func _draw() -> void:
	if area.size.x <= 0.0:
		return
	var top := area.position
	var width := area.size.x
	var height := area.size.y
	var water := Color("#bfe8e6").lerp(Color("#a99f7a"), 1.0 - flow)
	# The sheet narrows a little towards the bottom, like water leaving a lip of rock.
	var sheet := PackedVector2Array([top, top + Vector2(width, 0), top + Vector2(width * 0.92, height), top + Vector2(width * 0.08, height)])
	draw_colored_polygon(sheet, Color(water, 0.9))
	draw_line(top + Vector2(-4, 2), top + Vector2(width + 4, 2), Color(1, 1, 1, 0.85), 5.0)
	for i in STREAKS:
		var x := lerpf(width * 0.12, width * 0.88, (i + 0.5) / STREAKS)
		var speed := 60.0 + PropPainter.noise(Vector2(i, 3), 7) * 50.0
		var offset := 0.0 if reduced_motion else fmod(_clock * speed + PropPainter.noise(Vector2(i, 1), 2) * height, height)
		var length := height * (0.25 + PropPainter.noise(Vector2(i, 5), 4) * 0.2)
		var start := offset - length
		draw_line(top + Vector2(x, maxf(0.0, start)), top + Vector2(x, minf(height, offset)), Color(1, 1, 1, 0.55), 2.5)
	# Foam where it lands.
	var base := top + Vector2(width * 0.5, height)
	for i in 7:
		var angle := PI * (i / 6.0)
		var wobble := 0.0 if reduced_motion else sin(_clock * 3.0 + i) * 3.0
		draw_circle(base + Vector2(cos(angle) * width * 0.55, sin(angle) * 6.0 - 4.0 + wobble), 9.0 + (i % 3) * 3.0, Color(1, 1, 1, 0.75))
