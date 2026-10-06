class_name WoodStyle
extends StyleBox

## The wooden plank look of the mockups' main buttons and sign boards (D-018): a rounded board with
## a lighter top edge, darker grain lines and, optionally, a band of pond water along the bottom
## (the "낚시" button). It is a StyleBox so the Theme can use it like any other box and it scales
## to any size; the grain is derived from the size alone, so it never flickers between redraws.
##
## Placeholder for the wood 9-patch frames requested in assets/design/ASSET_REQUESTS.md §4.

var base := StyleBoxFlat.new()
var grain_color := Color(0.25, 0.14, 0.07, 0.22)
var highlight_color := Color(1.0, 0.9, 0.72, 0.28)
## Draws a water band along the bottom edge when true.
var water := false
var water_color := Color("#7fc3b8")

func _init(color: Color = Color("#8a5a36"), border: Color = Color("#5e3b22"), border_width: int = 3, radius: int = 26) -> void:
	base.bg_color = color
	base.border_color = border
	base.set_border_width_all(border_width)
	base.set_corner_radius_all(radius)
	base.shadow_color = Color(0, 0, 0, 0.22)
	base.shadow_size = 6
	base.shadow_offset = Vector2(0, 4)
	base.anti_aliasing = true

func set_margins(horizontal: float, vertical: float) -> void:
	content_margin_left = horizontal
	content_margin_right = horizontal
	content_margin_top = vertical
	content_margin_bottom = vertical

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	base.draw(to_canvas_item, rect)
	var radius := float(base.corner_radius_top_left)
	var inset := maxf(radius * 0.8, 8.0)
	var left := rect.position.x + inset
	var right := rect.end.x - inset
	if right <= left:
		return
	var border := float(base.border_width_top)
	# A soft highlight just inside the top edge.
	var top_y := rect.position.y + border + 3.0
	RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(left, top_y), Vector2(right, top_y), highlight_color, 2.0, true)
	# Grain: gently waving lines, spaced by the board's height.
	var lines := clampi(int(rect.size.y / 14.0), 2, 9)
	var seed_value := int(rect.size.x * 7.0 + rect.size.y * 13.0)
	for i in lines:
		var t := (i + 0.5) / lines
		var y := rect.position.y + border + 6.0 + t * (rect.size.y - border * 2.0 - 12.0)
		var start := left + _noise(seed_value, i) * rect.size.x * 0.25
		var end := right - _noise(seed_value, i + 31) * rect.size.x * 0.25
		if end - start < 12.0:
			continue
		var points := PackedVector2Array()
		var steps := 8
		var phase := _noise(seed_value, i + 7) * TAU
		for s in steps + 1:
			var x := lerpf(start, end, float(s) / steps)
			points.append(Vector2(x, y + sin(phase + s * 0.9) * 1.6))
		RenderingServer.canvas_item_add_polyline(to_canvas_item, points, PackedColorArray([grain_color]), 1.5, true)
	if water:
		_draw_water(to_canvas_item, rect, radius)

## A shallow band of water along the bottom, kept inside the rounded corners.
func _draw_water(to_canvas_item: RID, rect: Rect2, radius: float) -> void:
	var band := minf(rect.size.y * 0.22, 26.0)
	var bottom := rect.end.y - float(base.border_width_bottom) - 2.0
	var left := rect.position.x + radius * 0.7
	var right := rect.end.x - radius * 0.7
	var points := PackedVector2Array()
	var steps := 16
	for s in steps + 1:
		var x := lerpf(left, right, float(s) / steps)
		points.append(Vector2(x, bottom - band + sin(s * 0.85) * 3.0))
	points.append(Vector2(right, bottom))
	points.append(Vector2(left, bottom))
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([Color(water_color, 0.85)]))
	var crest := PackedVector2Array()
	for s in steps + 1:
		crest.append(points[s])
	RenderingServer.canvas_item_add_polyline(to_canvas_item, crest, PackedColorArray([Color(1, 1, 1, 0.55)]), 2.0, true)

static func _noise(seed_value: int, index: int) -> float:
	return float(absi(hash(Vector2i(seed_value, index))) % 1000) / 1000.0
