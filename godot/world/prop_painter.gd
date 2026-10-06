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

const CANVAS := Color("#e8dcc0")
const CANVAS_DARK := Color("#cdbd9b")
const SAGE := Color("#7f9a6a")
const PLANK := Color("#9a6b43")
const PLANK_DARK := Color("#6e4a2d")
const ROPE := Color("#c9b083")
const LAMP := Color("#ffd27a")
const SOIL := Color("#b39566")

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
		"camp_ground": _camp_ground(canvas, at, scale, palette)
		"tent": _tent(canvas, at, scale)
		"camp_chair": _camp_chair(canvas, at, scale)
		"crate": _crate(canvas, at, scale)
		"lantern": _lantern(canvas, at, scale)
		"signboard": _signboard(canvas, at, scale)
		"birdhouse": _birdhouse(canvas, at, scale)
		"stepping_stone": _stepping_stone(canvas, at, scale)
		"dock": _dock(canvas, at, scale)
		"cat": _cat(canvas, at, scale)
		"frog": _frog(canvas, at, scale)

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

# --- the main-world mockup's scenery (D-018) ---

static func _quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([a, b, c, d]), color)

## A worn clearing with a woven rug: the camp's floor.
static func _camp_ground(canvas: CanvasItem, at: Vector2, scale: float, palette: Dictionary) -> void:
	var soil := SOIL.lerp(palette["grass"], 0.35)
	canvas.draw_colored_polygon(_ellipse(at, Vector2(150, 78) * scale, 24), soil)
	canvas.draw_colored_polygon(_ellipse(at + Vector2(10, 6) * scale, Vector2(118, 56) * scale, 24), soil.lightened(0.08))
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	_quad(canvas, p.call(-10, 18), p.call(70, -8), p.call(118, 26), p.call(38, 54), CANVAS)
	_quad(canvas, p.call(-2, 20), p.call(70, -2), p.call(108, 26), p.call(38, 48), CANVAS_DARK)
	for i in 4:
		var t := 0.2 + i * 0.2
		canvas.draw_line(p.call(-2, 20).lerp(p.call(38, 48), t), p.call(70, -2).lerp(p.call(108, 26), t), CANVAS, 2.0 * scale)

static func _tent(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_colored_polygon(_ellipse(p.call(10, 6), Vector2(95, 22) * scale), Color(0, 0, 0, 0.18))
	# Roof seen from the side, then the front gable with its glowing door.
	_quad(canvas, p.call(-20, -96), p.call(42, -122), p.call(98, -18), p.call(30, 8), CANVAS_DARK)
	canvas.draw_line(p.call(-20, -96), p.call(42, -122), CANVAS.lightened(0.2), 3.0 * scale)
	canvas.draw_colored_polygon(PackedVector2Array([p.call(-78, 2), p.call(30, 8), p.call(-20, -96)]), CANVAS)
	canvas.draw_colored_polygon(PackedVector2Array([p.call(-40, 4), p.call(4, 6), p.call(-20, -52)]), Color("#6e5536"))
	canvas.draw_colored_polygon(PackedVector2Array([p.call(-34, 4), p.call(-2, 5), p.call(-19, -36)]), LAMP.darkened(0.15))
	canvas.draw_circle(p.call(-19, -14), 9.0 * scale, Color(LAMP, 0.6))
	for anchor in [[p.call(-78, 2), p.call(-110, 18)], [p.call(98, -18), p.call(128, -4)]]:
		canvas.draw_line(anchor[0], anchor[1], ROPE, 1.5 * scale)
	canvas.draw_line(p.call(-20, -96), p.call(-20, -112), WOOD_DARK, 4.0 * scale)

static func _camp_chair(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_colored_polygon(_ellipse(p.call(4, 4), Vector2(34, 10) * scale), Color(0, 0, 0, 0.18))
	for leg in [[p.call(-26, 4), p.call(14, -28)], [p.call(22, 6), p.call(-16, -26)], [p.call(-24, -30), p.call(-24, 2)], [p.call(26, -26), p.call(26, 4)]]:
		canvas.draw_line(leg[0], leg[1], WOOD, 4.0 * scale)
	_quad(canvas, p.call(-26, -30), p.call(28, -28), p.call(24, -16), p.call(-22, -18), SAGE)  # seat
	_quad(canvas, p.call(-22, -76), p.call(26, -72), p.call(28, -30), p.call(-26, -32), SAGE.lightened(0.08))  # back
	canvas.draw_line(p.call(-24, -78), p.call(-26, -30), WOOD, 4.5 * scale)
	canvas.draw_line(p.call(27, -74), p.call(28, -28), WOOD, 4.5 * scale)
	# A pale leaf on the back, like the mockup's chair.
	canvas.draw_colored_polygon(_ellipse(p.call(1, -52), Vector2(9, 15) * scale, 10), Color(1, 1, 1, 0.45))

static func _crate(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_colored_polygon(_ellipse(p.call(4, 4), Vector2(42, 12) * scale), Color(0, 0, 0, 0.2))
	_quad(canvas, p.call(-36, -40), p.call(10, -54), p.call(44, -38), p.call(-2, -24), PLANK.lightened(0.12))  # top
	_quad(canvas, p.call(-36, -40), p.call(-2, -24), p.call(-2, 6), p.call(-36, -10), PLANK)  # front
	_quad(canvas, p.call(-2, -24), p.call(44, -38), p.call(44, -8), p.call(-2, 6), PLANK_DARK)  # side
	for i in 3:
		var y := -32.0 + i * 12.0
		canvas.draw_line(p.call(-36, y - 4), p.call(-2, y + 12), PLANK_DARK, 1.5 * scale)
		canvas.draw_line(p.call(-2, y + 12), p.call(44, y - 2), Color(0, 0, 0, 0.25), 1.5 * scale)

static func _lantern(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_circle(p.call(0, -20), 30.0 * scale, Color(LAMP, 0.18))
	canvas.draw_circle(p.call(0, -20), 18.0 * scale, Color(LAMP, 0.28))
	canvas.draw_rect(Rect2(p.call(-10, -6), Vector2(20, 6) * scale), WOOD_DARK)
	canvas.draw_rect(Rect2(p.call(-8, -32), Vector2(16, 26) * scale), LAMP)
	canvas.draw_rect(Rect2(p.call(-8, -32), Vector2(16, 26) * scale), WOOD_DARK, false, 2.0 * scale)
	canvas.draw_colored_polygon(PackedVector2Array([p.call(-12, -32), p.call(12, -32), p.call(0, -42)]), WOOD_DARK)
	canvas.draw_arc(p.call(0, -44), 6.0 * scale, PI, TAU, 8, WOOD_DARK, 2.0 * scale)

static func _signboard(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_line(p.call(-18, 0), p.call(-18, -40), WOOD_DARK, 5.0 * scale)
	canvas.draw_line(p.call(20, 2), p.call(20, -38), WOOD_DARK, 5.0 * scale)
	_quad(canvas, p.call(-36, -66), p.call(38, -60), p.call(38, -24), p.call(-36, -30), PLANK)
	canvas.draw_line(p.call(-36, -48), p.call(38, -42), PLANK_DARK, 1.5 * scale)
	canvas.draw_colored_polygon(_ellipse(p.call(1, -45), Vector2(7, 12) * scale, 10), Color(1, 0.95, 0.85, 0.7))

static func _birdhouse(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_line(p.call(0, 0), p.call(0, -110), WOOD_DARK, 7.0 * scale)
	canvas.draw_line(p.call(-24, -86), p.call(28, -84), WOOD, 4.0 * scale)  # perch
	canvas.draw_rect(Rect2(p.call(-20, -150), Vector2(40, 42) * scale), PLANK)
	canvas.draw_colored_polygon(PackedVector2Array([p.call(-28, -148), p.call(28, -148), p.call(0, -172)]), Color("#5f7a4a"))
	canvas.draw_circle(p.call(0, -130), 6.0 * scale, Color("#3a2a1c"))
	# A small blue bird on the perch.
	var bird: Vector2 = p.call(18, -92)
	canvas.draw_colored_polygon(_ellipse(bird, Vector2(9, 7) * scale, 12), Color("#4f86c6"))
	canvas.draw_colored_polygon(_ellipse(bird + Vector2(2, 2) * scale, Vector2(6, 4) * scale, 10), Color("#f2efe6"))
	canvas.draw_circle(bird + Vector2(-7, -4) * scale, 5.0 * scale, Color("#4f86c6"))
	canvas.draw_circle(bird + Vector2(-8, -5) * scale, 1.2 * scale, Color.BLACK)

static func _stepping_stone(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	canvas.draw_colored_polygon(_ellipse(at + Vector2(0, 4) * scale, Vector2(30, 13) * scale, 16), Color(0, 0, 0, 0.18))
	canvas.draw_colored_polygon(_ellipse(at, Vector2(30, 14) * scale, 16), ROCK)
	canvas.draw_colored_polygon(_ellipse(at + Vector2(-6, -4) * scale, Vector2(18, 7) * scale, 12), ROCK_LIGHT)
	canvas.draw_colored_polygon(_ellipse(at + Vector2(14, 2) * scale, Vector2(8, 4) * scale, 8), Color("#6f8f4f"))

## The wooden dock the angler sits on: a plank deck seen from above at an angle, its edge, the posts
## standing in the water, a rope railing along the back and a coil of rope by the front post.
static func _dock(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	var a: Vector2 = p.call(0, 0)
	var b: Vector2 = p.call(235, -95)
	var c: Vector2 = p.call(425, 95)
	var d: Vector2 = p.call(190, 190)
	var depth := Vector2(0, 16) * scale
	# Posts below the deck, reaching into the water.
	for post in [b, c, d, a.lerp(d, 0.5), d.lerp(c, 0.5)]:
		canvas.draw_rect(Rect2(post + Vector2(-9, 0) * scale, Vector2(18, 54) * scale), PLANK_DARK.darkened(0.2))
		canvas.draw_colored_polygon(_ellipse(post + Vector2(0, 54) * scale, Vector2(14, 5) * scale, 10), Color(1, 1, 1, 0.25))
	_quad(canvas, d, c, c + depth, d + depth, PLANK_DARK)
	_quad(canvas, a, d, d + depth, a + depth, PLANK_DARK.darkened(0.1))
	_quad(canvas, a, b, c, d, PLANK)
	for i in 12:
		var t := float(i + 1) / 13.0
		canvas.draw_line(a.lerp(d, t), b.lerp(c, t), PLANK_DARK, 1.6 * scale)
	for i in 3:
		var t := 0.15 + i * 0.32
		canvas.draw_line(a.lerp(b, t).lerp(d.lerp(c, t), 0.05), a.lerp(b, t).lerp(d.lerp(c, t), 0.95), Color(1, 0.9, 0.7, 0.12), 3.0 * scale)
	# Railing posts along the back edge with a rope between them.
	var tops: Array[Vector2] = []
	for t in [0.0, 0.5, 1.0]:
		var base := a.lerp(b, t)
		var top := base + Vector2(0, -56) * scale
		canvas.draw_line(base, top, PLANK_DARK, 9.0 * scale)
		canvas.draw_circle(top, 5.0 * scale, PLANK)
		tops.append(top)
	for i in tops.size() - 1:
		var mid := tops[i].lerp(tops[i + 1], 0.5) + Vector2(0, 10) * scale
		canvas.draw_polyline(PackedVector2Array([tops[i], mid, tops[i + 1]]), ROPE, 3.0 * scale, true)
	# Front post with a rope coil.
	var front := c + Vector2(-6, -8) * scale
	canvas.draw_rect(Rect2(front + Vector2(-11, -40) * scale, Vector2(22, 44) * scale), PLANK_DARK)
	canvas.draw_colored_polygon(_ellipse(front + Vector2(0, -40) * scale, Vector2(11, 5) * scale, 10), PLANK)
	for i in 3:
		canvas.draw_arc(front + Vector2(0, -18 + i * 7) * scale, 13.0 * scale, 0.2, PI - 0.2, 10, ROPE, 3.0 * scale)

static func _cat(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_colored_polygon(_ellipse(p.call(2, 6), Vector2(36, 9) * scale), Color(0, 0, 0, 0.18))
	canvas.draw_colored_polygon(_ellipse(p.call(0, -8), Vector2(34, 18) * scale, 18), Color("#f4efe4"))
	canvas.draw_colored_polygon(_ellipse(p.call(8, -14), Vector2(16, 10) * scale, 12), Color("#8a6a4f"))
	canvas.draw_colored_polygon(_ellipse(p.call(-22, -6), Vector2(14, 12) * scale, 14), Color("#f4efe4"))
	canvas.draw_colored_polygon(_ellipse(p.call(-25, -10), Vector2(8, 6) * scale, 10), Color("#5d5148"))
	for ear in [-1.0, 1.0]:
		canvas.draw_colored_polygon(PackedVector2Array([p.call(-28 + ear * 6, -14), p.call(-24 + ear * 10, -24), p.call(-20 + ear * 4, -13)]), Color("#5d5148"))
	canvas.draw_arc(p.call(-26, -5), 3.0 * scale, 0.2, PI - 0.2, 6, Color("#3a2f28"), 1.5 * scale)  # closed eye
	canvas.draw_arc(p.call(22, 0), 14.0 * scale, -0.6, 2.0, 10, Color("#8a6a4f"), 6.0 * scale)  # tail

static func _frog(canvas: CanvasItem, at: Vector2, scale: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_colored_polygon(_ellipse(p.call(0, -8), Vector2(14, 10) * scale, 14), Color("#6aa84f"))
	canvas.draw_colored_polygon(_ellipse(p.call(0, -5), Vector2(9, 5) * scale, 10), Color("#d8e6a6"))
	for side in [-1.0, 1.0]:
		canvas.draw_circle(p.call(side * 7, -17), 4.5 * scale, Color("#6aa84f"))
		canvas.draw_circle(p.call(side * 7, -17), 2.0 * scale, Color("#1f2a14"))
		canvas.draw_colored_polygon(_ellipse(p.call(side * 13, -2), Vector2(6, 3) * scale, 8), Color("#5a9441"))
