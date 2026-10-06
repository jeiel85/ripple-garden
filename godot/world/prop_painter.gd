class_name PropPainter
extends RefCounted

## Draws the region's scenery with 2D primitives (placeholder art, D-011). Each function paints
## onto a CanvasItem so it can be used from any node's `_draw`. Shapes are deterministic: a
## pseudo-random value derived from the prop's position and index replaces a random generator,
## so a prop never changes between redraws.
##
## `palette` is the restoration-level palette from the layout ({"grass", "canopy", ...} colors).

const WOOD := Color("#6b4f3a")
const WOOD_DARK := Color("#4a362a")
const ROCK := Color("#8a8d92")
const ROCK_LIGHT := Color("#a9acb1")
const REED := Color("#7a9a52")
const REED_TIP := Color("#7a5a3a")
const PAD := Color("#4f9a5a")
const FLOWERS: Array[Color] = [Color("#f08fb0"), Color("#f3d36b"), Color("#f4f1ea"), Color("#b69be6")]
const RUST := Color("#8a5a44")
const BUCKET := Color("#7b8794")

static func draw_prop(canvas: CanvasItem, kind: String, at: Vector2, scale: float, level: int, palette: Dictionary) -> void:
	match kind:
		"tree": _tree(canvas, at, scale, level, palette)
		"bush": _bush(canvas, at, scale, level, palette)
		"rock": _rock(canvas, at, scale)
		"stump": _stump(canvas, at, scale)
		"junk": _junk(canvas, at, scale)
		"grass_tuft": _grass_tuft(canvas, at, scale, palette)
		"reed": _reed(canvas, at, scale, level, palette)
		"lily_pad": _lily_pad(canvas, at, scale, level)
		"flower": _flower(canvas, at, scale)

## Stable 0..1 value for (position, index).
static func noise(at: Vector2, index: int) -> float:
	return float(absi(hash(Vector3i(int(at.x), int(at.y), index))) % 1000) / 1000.0

static func _ellipse(center: Vector2, radius: Vector2, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * i / steps
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

static func _tree(canvas: CanvasItem, at: Vector2, scale: float, level: int, palette: Dictionary) -> void:
	var height := 120.0 * scale
	var trunk_width := 9.0 * scale
	var trunk := PackedVector2Array([
		at + Vector2(-trunk_width, 0), at + Vector2(trunk_width, 0),
		at + Vector2(trunk_width * 0.5, -height), at + Vector2(-trunk_width * 0.5, -height)])
	canvas.draw_colored_polygon(trunk, WOOD)
	var top := at + Vector2(0, -height)
	# Bare branches show at every level; leaves fill in as the pond recovers.
	for i in 5:
		var angle := deg_to_rad(-90.0 + (i - 2) * 28.0 + (noise(at, i) - 0.5) * 12.0)
		canvas.draw_line(top + Vector2(0, 14.0 * scale), top + Vector2.from_angle(angle) * 46.0 * scale, WOOD_DARK, 3.0 * scale)
	var clumps: int = [0, 2, 5, 8, 10, 12][clampi(level, 0, 5)]
	var canopy: Color = palette["canopy"]
	for i in clumps:
		var angle := TAU * (float(i) / maxf(clumps, 1.0)) + noise(at, i + 10)
		var offset := Vector2(cos(angle) * 30.0, sin(angle) * 20.0 - 22.0) * scale
		var shade := canopy.lightened(0.18) if i % 3 == 0 else (canopy.darkened(0.12) if i % 3 == 1 else canopy)
		canvas.draw_circle(top + offset, (24.0 + noise(at, i + 20) * 12.0) * scale, shade)
	if level >= 5:
		for i in 7:
			var angle := noise(at, i + 40) * TAU
			canvas.draw_circle(top + Vector2(cos(angle) * 34.0, sin(angle) * 26.0 - 18.0) * scale, 4.0 * scale, FLOWERS[0].lightened(0.2))

static func _bush(canvas: CanvasItem, at: Vector2, scale: float, level: int, palette: Dictionary) -> void:
	var canopy: Color = palette["canopy"]
	canvas.draw_circle(at + Vector2(-20, -16) * scale, 26.0 * scale, canopy.darkened(0.1))
	canvas.draw_circle(at + Vector2(20, -14) * scale, 24.0 * scale, canopy.darkened(0.05))
	canvas.draw_circle(at + Vector2(0, -28) * scale, 30.0 * scale, canopy)
	if level >= 5:
		for i in 4:
			canvas.draw_circle(at + Vector2((noise(at, i) - 0.5) * 60.0, -20.0 - noise(at, i + 5) * 30.0) * scale, 4.0 * scale, FLOWERS[i % FLOWERS.size()])

static func _rock(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var points := PackedVector2Array([
		at + Vector2(-34, 0) * scale, at + Vector2(-26, -22) * scale, at + Vector2(-6, -32) * scale,
		at + Vector2(18, -26) * scale, at + Vector2(34, -4) * scale, at + Vector2(26, 6) * scale,
		at + Vector2(-20, 8) * scale])
	canvas.draw_colored_polygon(points, ROCK)
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-26, -22) * scale, at + Vector2(-6, -32) * scale, at + Vector2(6, -18) * scale, at + Vector2(-14, -8) * scale]), ROCK_LIGHT)

static func _stump(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-22, 0) * scale, at + Vector2(22, 0) * scale, at + Vector2(16, -34) * scale, at + Vector2(-16, -34) * scale]), WOOD_DARK)
	canvas.draw_colored_polygon(_ellipse(at + Vector2(0, -34) * scale, Vector2(16, 6) * scale), WOOD.lightened(0.15))
	canvas.draw_arc(at + Vector2(0, -34) * scale, 7.0 * scale, 0.0, TAU, 12, WOOD, 1.5 * scale)

static func _junk(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	# An old bucket tipped on its side: the kind of thing a neglected pond collects.
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-20, -4) * scale, at + Vector2(20, -10) * scale, at + Vector2(24, 6) * scale, at + Vector2(-16, 10) * scale]), BUCKET)
	canvas.draw_colored_polygon(_ellipse(at + Vector2(22, -2) * scale, Vector2(5, 8) * scale, 10), RUST)
	canvas.draw_line(at + Vector2(-20, -4) * scale, at + Vector2(-26, -16) * scale, RUST, 2.0 * scale)

static func _grass_tuft(canvas: CanvasItem, at: Vector2, scale: float, palette: Dictionary) -> void:
	var grass: Color = palette["grass"]
	for i in 6:
		var lean := (i - 2.5) * 5.0
		var blade_height := (20.0 + noise(at, i) * 14.0) * scale
		canvas.draw_colored_polygon(PackedVector2Array([
			at + Vector2((i - 2.5) * 4.0 - 2.5, 0) * scale, at + Vector2((i - 2.5) * 4.0 + 2.5, 0) * scale,
			at + Vector2((i - 2.5) * 4.0 + lean, -blade_height)]), grass.darkened(0.08 * (i % 3)))

static func _reed(canvas: CanvasItem, at: Vector2, scale: float, level: int, palette: Dictionary) -> void:
	var grass: Color = palette["grass"]
	for i in 5:
		var base := at + Vector2((i - 2) * 7.0, 0) * scale
		var tip := base + Vector2((noise(at, i) - 0.5) * 22.0, -(70.0 + noise(at, i + 7) * 40.0)) * scale
		canvas.draw_line(base, tip, REED.lerp(grass, 0.4), 3.0 * scale)
		if level >= 3 and i % 2 == 0:
			canvas.draw_line(tip, tip + (tip - base).normalized() * 16.0 * scale, REED_TIP, 6.0 * scale)

static func _lily_pad(canvas: CanvasItem, at: Vector2, scale: float, level: int) -> void:
	var pad := _ellipse(at, Vector2(30, 13) * scale, 18)
	canvas.draw_colored_polygon(pad, PAD)
	canvas.draw_line(at, at + Vector2(24, -3) * scale, PAD.darkened(0.25), 2.0 * scale)  # leaf vein
	if level >= 4:
		canvas.draw_circle(at + Vector2(-6, -4) * scale, 6.0 * scale, FLOWERS[0].lightened(0.3))
		canvas.draw_circle(at + Vector2(-6, -4) * scale, 2.5 * scale, FLOWERS[1])

static func _flower(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var color := FLOWERS[int(noise(at, 3) * FLOWERS.size()) % FLOWERS.size()]
	canvas.draw_line(at, at + Vector2(0, -26) * scale, Color("#4d8a4a"), 2.5 * scale)
	var head := at + Vector2(0, -28) * scale
	for i in 5:
		canvas.draw_circle(head + Vector2.from_angle(TAU * i / 5.0) * 5.5 * scale, 4.2 * scale, color)
	canvas.draw_circle(head, 3.0 * scale, Color("#f3d36b"))
