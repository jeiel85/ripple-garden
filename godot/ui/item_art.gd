class_name ItemArt
extends Control

## Placeholder picture of an equipment item for the equipment screen (mockup 05), until the item art of
## assets/design/ASSET_REQUESTS.md §6 arrives: a soft round backdrop tinted by grade, and the item drawn
## from simple shapes — a rod with cork grip and reel, a bait by its kind, a backpack in the bag's
## colour, a hat in the accessory's colours. Locked items are drawn faded.

const GRADE_TINTS := {
	"common": Color("#dfe6cf"), "uncommon": Color("#e6dccb"), "rare": Color("#d6dde6"), "event": Color("#f0d9de"),
}
const GRADE_ACCENTS := {
	"common": Color("#8a6440"), "uncommon": Color("#5f7a4a"), "rare": Color("#34465f"), "event": Color("#c46b86"),
}

var category := "rod"
var item_id := ""
var faded := false

func _init(p_category: String = "rod", p_item_id: String = "") -> void:
	category = p_category
	item_id = p_item_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(110, 110)

func show_item(p_category: String, p_item_id: String, p_faded: bool = false) -> void:
	category = p_category
	item_id = p_item_id
	faded = p_faded
	queue_redraw()

func _draw() -> void:
	var def := ContentDB.get_item(category, item_id)
	if def.is_empty():
		return
	var grade: String = def.get("grade", "common")
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.46
	draw_circle(center, radius, GRADE_TINTS.get(grade, GRADE_TINTS["common"]))
	draw_circle(center + Vector2(-radius * 0.3, -radius * 0.25), radius * 0.35, Color(1, 1, 1, 0.25))
	var s := radius / 50.0
	match category:
		"rod": _rod(center, s, GRADE_ACCENTS.get(grade, GRADE_ACCENTS["common"]), grade == "event")
		"bait": _bait(center, s, def.get("tags", []))
		"bag": _bag(center, s, Color(def.get("color", "#6f8a5a")))
		"accessory": _hat(center, s, Color(def.get("hat", "#ece0c2")), Color(def.get("band", "#5f7a4a")))
	if faded:
		draw_circle(center, radius, Color(0.95, 0.92, 0.86, 0.55))
		draw_texture_rect(UiIcons.texture("lock"), Rect2(center - Vector2(18, 18) * s * 1.2, Vector2(36, 36) * s * 1.2), false, Color(UiTheme.INK, 0.8))

func _rod(c: Vector2, s: float, accent: Color, blossoms: bool) -> void:
	var butt := c + Vector2(-34, 38) * s
	var tip := c + Vector2(34, -44) * s
	draw_line(tip, tip + Vector2(0, 46) * s, Color(1, 1, 1, 0.8), 1.2)
	draw_line(butt, tip, accent, 4.0 * s, true)
	draw_line(butt, butt.lerp(tip, 0.3), Color("#c9a26b"), 7.0 * s, true)  # cork grip
	var reel := butt.lerp(tip, 0.22) + Vector2(8, 4) * s
	draw_circle(reel, 9.0 * s, Color("#c9c4b8"))
	draw_circle(reel, 4.0 * s, Color("#6c675e"))
	for t in [0.45, 0.65, 0.85]:
		draw_circle(butt.lerp(tip, t), 2.2 * s, Color("#d8c38f"))
	if blossoms:
		for t in [0.35, 0.55, 0.75]:
			var at := butt.lerp(tip, t) + Vector2(5, 3) * s
			for i in 5:
				draw_circle(at + Vector2.from_angle(TAU * i / 5.0) * 3.5 * s, 2.6 * s, Color("#f6c3d3"))
			draw_circle(at, 1.6 * s, Color("#f3d36b"))

func _bait(c: Vector2, s: float, tags: Array) -> void:
	var kind: String = tags[0] if not tags.is_empty() else "bread"
	match kind:
		"worm", "larva":
			var color := Color("#e58a8a") if kind == "worm" else Color("#efe2c0")
			var points := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				points.append(c + Vector2(lerpf(-30, 30, t), sin(t * TAU * 1.2) * 12.0) * s)
			draw_polyline(points, color, 11.0 * s, true)
			for i in 6:
				var at := points[i * 2]
				draw_line(at + Vector2(0, -5) * s, at + Vector2(0, 5) * s, color.darkened(0.2), 1.5 * s)
		"bread", "grain":
			var dough := Color("#e8d7a6") if kind == "bread" else Color("#f0c94a")
			if kind == "grain":
				for i in 7:
					draw_circle(c + Vector2(cos(i * 0.9) * 16.0, sin(i * 1.3) * 12.0) * s, 7.0 * s, dough)
			else:
				draw_circle(c, 24.0 * s, dough)
				draw_circle(c + Vector2(-7, -7) * s, 8.0 * s, dough.lightened(0.25))
				for i in 6:
					draw_circle(c + Vector2(cos(i * 1.7) * 14.0, sin(i * 2.3) * 12.0) * s, 1.6 * s, dough.darkened(0.25))
		"insect", "fruit":
			if kind == "fruit":
				for i in 3:
					draw_circle(c + Vector2(-10 + i * 10, i % 2 * 8) * s, 11.0 * s, Color("#c8414b"))
				draw_line(c + Vector2(0, -12) * s, c + Vector2(4, -24) * s, Color("#4d8a4a"), 3.0 * s)
			else:
				var green := Color("#86b04a") if not "special" in tags else Color("#9b86c9")
				draw_colored_polygon(_oval(c, Vector2(26, 9) * s), green)
				draw_circle(c + Vector2(-26, -2) * s, 8.0 * s, green)
				draw_line(c + Vector2(-8, 4) * s, c + Vector2(-18, 22) * s, green.darkened(0.2), 3.0 * s)
				draw_line(c + Vector2(6, 4) * s, c + Vector2(22, 22) * s, green.darkened(0.2), 3.0 * s)
				draw_line(c + Vector2(-30, -8) * s, c + Vector2(-40, -26) * s, green.darkened(0.3), 1.6 * s)
		"shrimp", "crab":
			var shell := Color("#ef8a4a") if kind == "shrimp" else Color("#d2553f")
			if kind == "shrimp":
				draw_arc(c, 20.0 * s, PI * 0.1, PI * 1.3, 16, shell, 11.0 * s, true)
				draw_line(c + Vector2(18, -4) * s, c + Vector2(34, -18) * s, shell.darkened(0.2), 1.5 * s)
			else:
				draw_colored_polygon(_oval(c, Vector2(24, 15) * s), shell)
				for side in [-1.0, 1.0]:
					draw_circle(c + Vector2(side * 30, -10) * s, 8.0 * s, shell)
		"small_fish":
			draw_colored_polygon(_oval(c, Vector2(26, 10) * s), Color("#b8c6cf"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(22, 0) * s, c + Vector2(36, -11) * s, c + Vector2(36, 11) * s]), Color("#9fb0bb"))
		"shellfish":
			draw_colored_polygon(_oval(c, Vector2(26, 18) * s), Color("#d9c2a0"))
			for i in 4:
				draw_line(c + Vector2(0, 16) * s, c + Vector2(-18 + i * 12, -14) * s, Color("#b39d7b"), 2.0 * s)
		"squid":
			draw_colored_polygon(_oval(c + Vector2(0, -8) * s, Vector2(13, 22) * s), Color("#f2ece0"))
			for i in 4:
				draw_line(c + Vector2(-6 + i * 4, 12) * s, c + Vector2(-8 + i * 5, 32) * s, Color("#e9dfcf"), 3.0 * s)
		"plant":
			for i in 3:
				var base := c + Vector2(-12 + i * 12, 26) * s
				draw_polyline(PackedVector2Array([base, base + Vector2(6, -18) * s, base + Vector2(-4, -36) * s]), Color("#5a9441"), 7.0 * s, true)
		_:
			draw_circle(c, 20.0 * s, Color("#e8d7a6"))

func _bag(c: Vector2, s: float, color: Color) -> void:
	draw_arc(c + Vector2(0, -26) * s, 12.0 * s, PI, TAU, 12, color.darkened(0.3), 4.0 * s, true)
	var body := Rect2(c + Vector2(-26, -26) * s, Vector2(52, 58) * s)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(14 * s))
	draw_style_box(box, body)
	var pocket := StyleBoxFlat.new()
	pocket.bg_color = color.darkened(0.18)
	pocket.set_corner_radius_all(int(8 * s))
	draw_style_box(pocket, Rect2(c + Vector2(-16, 4) * s, Vector2(32, 22) * s))
	draw_line(c + Vector2(-26, -10) * s, c + Vector2(26, -10) * s, color.darkened(0.25), 2.0 * s)

func _hat(c: Vector2, s: float, hat: Color, band: Color) -> void:
	draw_colored_polygon(_oval(c + Vector2(0, 10) * s, Vector2(40, 13) * s), hat.darkened(0.08))
	draw_colored_polygon(_oval(c + Vector2(0, -4) * s, Vector2(22, 20) * s), hat)
	draw_colored_polygon(_oval(c + Vector2(0, 6) * s, Vector2(22, 5) * s), band)

static func _oval(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
