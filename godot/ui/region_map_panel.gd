class_name RegionMapPanel
extends Control

## The region map (UI_UX §2, mockup 07, P1-010): five islands on a sea under drifting clouds, joined by a
## dotted route. Each island carries a cream name sign and a dark pill with the species met there; the
## current island glows, locked ones are dimmed with a lock. Tapping a sign says where you are, what a
## locked island needs (its real condition and how far along you are), or that an open island's world
## comes in a later update — in a pill at the bottom of the map (the global toast sits under open screens,
## and the map covers it). Opened from the region pill of the status bar.
##
## The map is painted from shapes (MapView) until the map art of ASSET_REQUESTS §7 arrives (D-029):
## `map/map_background.png` replaces the sea and clouds, `map/map_island_<region id>.png` an island. The
## route, the glow of the current island, the locks and the signs stay the game's.

signal close_pressed

const FULLSCREEN := true
const KEEPS_STATUS := true
const BACKDROP := "none"

var current_region := ""

var _unlocks: RegionUnlocks
var _map: MapView
var _signs: Dictionary = {}
var _signs_layer: Control
var _note: PanelContainer
var _note_label: Label

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_map = MapView.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_map)
	_signs_layer = Control.new()
	_signs_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_signs_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_signs_layer)

	var title := UiKit.vbox(4)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 112
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board := UiKit.sign_board("map", tr("ui.map.title"))
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_child(board)
	var subtitle := UiKit.label(tr("ui.map.subtitle"), "LightLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	UiKit.text_size(subtitle, "caption")
	title.add_child(subtitle)
	add_child(title)

	var back := UiKit.icon_button("back", tr("ui.back"), func() -> void: close_pressed.emit(), "", UiTheme.ICON_L)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back.offset_left = 24
	back.offset_bottom = -28
	back.custom_minimum_size = Vector2(120, 120)
	add_child(back)

	_note = PanelContainer.new()
	_note.theme_type_variation = "PillPanel"
	_note.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_note.offset_left = 160
	_note.offset_right = -24
	_note.offset_bottom = -40
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	_note.add_child(_note_label)
	_note.visible = false
	add_child(_note)
	resized.connect(_place_signs)

func setup(unlocks: RegionUnlocks, p_current_region: String) -> void:
	_unlocks = unlocks
	current_region = p_current_region

func refresh() -> void:
	if _unlocks == null:
		return
	_note.visible = false
	var states := {}
	for region_id in ContentDB.regions:
		states[region_id] = _unlocks.state_of(region_id, current_region)
	_map.states = states
	_map.queue_redraw()
	for child in _signs_layer.get_children():
		_signs_layer.remove_child(child)
		child.queue_free()
	_signs.clear()
	for region_id in ContentDB.regions:
		var sign_box := _sign(region_id, states[region_id])
		_signs[region_id] = sign_box
		_signs_layer.add_child(sign_box)
	_place_signs()

func sign_count() -> int:
	return _signs.size()

## What tapping an island's sign says (and returns, for tests).
func tap(region_id: String) -> String:
	var text := ""
	match _unlocks.state_of(region_id, current_region):
		RegionUnlocks.CURRENT:
			text = tr("ui.map.here") % _name(region_id)
		RegionUnlocks.COMING:
			text = tr("ui.map.coming") % _name(region_id)
		RegionUnlocks.LOCKED:
			var condition := _unlocks.condition_of(region_id)
			text = tr("ui.map.locked") % [_name(condition["region"]), condition["level"], condition["level_now"],
				condition["fish"], condition["fish_now"]]
	_note_label.text = text
	_note.visible = not text.is_empty()
	return text

## The answer shown at the bottom of the map ("" when nothing was tapped yet).
func note_text() -> String:
	return _note_label.text if _note.visible else ""

func _sign(region_id: String, state: String) -> Control:
	var def := ContentDB.get_region(region_id)
	var box := UiKit.vbox(2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := UiKit.icon_button(def["map"]["icon"] if state != RegionUnlocks.LOCKED else "lock", _name(region_id),
		func() -> void: tap(region_id), "", UiTheme.ICON_M, false)
	UiKit.text_size(button, "small")
	button.custom_minimum_size.y = UiTheme.TOUCH_MIN_PX
	if state == RegionUnlocks.CURRENT:
		button.theme_type_variation = "CardSelected"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(button)
	var pill := PanelContainer.new()
	pill.theme_type_variation = "PillPanel"
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiKit.hbox(6)
	row.add_child(UiKit.icon("fish", UiTheme.ICON_S, UiTheme.PILL_TEXT))
	var count := UiKit.label("%d/%d" % [_unlocks.species_met(region_id), RegionUnlocks.species_total(region_id)], "PillLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	UiKit.text_size(count, "caption")
	row.add_child(count)
	pill.add_child(row)
	box.add_child(pill)
	return box

func _place_signs() -> void:
	for region_id in _signs:
		var box: Control = _signs[region_id]
		var at := _map.island_center(region_id) + Vector2(0, _map.island_radius() * 0.55)
		box.size = box.get_combined_minimum_size()
		box.position = at - Vector2(box.size.x / 2.0, 0)
		box.position.x = clampf(box.position.x, 8.0, size.x - box.size.x - 8.0)

static func _name(region_id: String) -> String:
	return TranslationServer.translate(ContentDB.get_region(region_id).get("name_key", region_id))

## The painted map: sea, clouds, the dotted route and five islands in their own styles.
class MapView extends Control:
	const SEA_BLEED := 300.0

	## {region_id: state} from RegionUnlocks.
	var states: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The map's drawing area: below the title, above the back button.
	func area() -> Rect2:
		return Rect2(0, 230, size.x, maxf(200.0, size.y - 380))

	func island_center(region_id: String) -> Vector2:
		var place: Dictionary = ContentDB.get_region(region_id).get("map", {"x": 0.5, "y": 0.5})
		var rect := area()
		return rect.position + Vector2(float(place["x"]) * rect.size.x, float(place["y"]) * rect.size.y)

	func island_radius() -> float:
		return minf(area().size.x, area().size.y) * 0.18

	## The whole area the map covers: the panel and the sea running on under a notch and the gesture bar.
	func backdrop_rect() -> Rect2:
		return Rect2(Vector2(0, -SEA_BLEED), size + Vector2(0, SEA_BLEED * 2.0))

	func _draw() -> void:
		var background := ArtLibrary.texture("map", "map_background")
		if background != null:
			draw_texture_rect(background, cover_rect(background, backdrop_rect()), false)
		else:
			draw_rect(backdrop_rect(), Color("#2a86ad"))
			var deep := Color("#1d6f96")
			for i in 6:
				draw_rect(Rect2(0, size.y * (0.5 + i * 0.08), size.x, size.y * 0.08), Color(deep, 0.1 * i))
			# Sparkles on the water.
			for i in 40:
				var at := Vector2(PropPainter.noise(Vector2(i, 7), 1) * size.x, PropPainter.noise(Vector2(i, 9), 2) * size.y)
				draw_line(at, at + Vector2(10, 0), Color(1, 1, 1, 0.25), 2.0)
		var ids: Array = ContentDB.regions.keys()
		for i in ids.size() - 1:
			_dotted(island_center(ids[i]), island_center(ids[i + 1]))
		for region_id in ids:
			_island(region_id)
		if background == null:
			# Clouds drifting at the edges.
			for corner in [Vector2(0.05, 0.12), Vector2(0.95, 0.2), Vector2(0.02, 0.62), Vector2(0.98, 0.7), Vector2(0.5, 0.97)]:
				var c := Vector2(corner.x * size.x, corner.y * size.y)
				for k in 4:
					draw_circle(c + Vector2((k - 1.5) * 34.0, sin(k) * 10.0), 40.0 - k * 4.0, Color(1, 1, 1, 0.85))

	## The smallest rect with the picture's proportions that covers `area`, centred: the background is
	## cropped at the sides or the ends rather than stretched or letterboxed.
	static func cover_rect(tex: Texture2D, area: Rect2) -> Rect2:
		var ratio := float(tex.get_width()) / maxf(1.0, tex.get_height())
		var size_px := Vector2(area.size.x, area.size.x / ratio)
		if size_px.y < area.size.y:
			size_px = Vector2(area.size.y * ratio, area.size.y)
		return Rect2(area.get_center() - size_px / 2.0, size_px)

	## Where the island picture of `region_id` is drawn: centred on the island, `width` island radii wide
	## (art.json "map"), or an empty rect when it has no picture.
	func island_rect(region_id: String) -> Rect2:
		var picture_name := "map_island_" + region_id
		var tex := ArtLibrary.texture("map", picture_name)
		if tex == null:
			return Rect2()
		var width := island_radius() * float(ArtLibrary.meta("map", picture_name, "island").get("width", 2.6))
		return ArtLibrary.placed_rect(tex, island_center(region_id), width, Vector2(0.5, 0.5))

	func _dotted(a: Vector2, b: Vector2) -> void:
		var mid := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * 30.0
		var steps := 22
		for i in steps:
			if i % 2 == 0:
				var t0 := float(i) / steps
				var t1 := float(i + 1) / steps
				draw_line(_bezier(a, mid, b, t0), _bezier(a, mid, b, t1), Color(1, 0.97, 0.9, 0.85), 4.0)

	static func _bezier(a: Vector2, m: Vector2, b: Vector2, t: float) -> Vector2:
		return a.lerp(m, t).lerp(m.lerp(b, t), t)

	func _island(region_id: String) -> void:
		var c := island_center(region_id)
		var r := island_radius()
		var state: String = states.get(region_id, RegionUnlocks.LOCKED)
		var style: String = ContentDB.get_region(region_id).get("map", {}).get("style", "pond")
		var land: Color = {"pond": Color("#7cbf5e"), "valley": Color("#6fa35a"), "river": Color("#86c066"),
			"coast": Color("#e8d39a"), "isle": Color("#3c4668")}.get(style, Color("#7cbf5e"))
		var picture := island_rect(region_id)
		if state == RegionUnlocks.CURRENT:
			if picture.has_area():
				# A soft warm halo around the drawn island: stacked ellipses, fainter the wider they go.
				for step in 6:
					var grow := 1.0 + step * 0.06
					draw_colored_polygon(PropPainter._ellipse(picture.get_center(), picture.size * 0.5 * grow), Color(1.0, 0.91, 0.6, 0.11))
			else:
				draw_colored_polygon(_blob(c, r * 1.14, region_id), Color("#ffe79a"))
		if picture.has_area():
			var dim := Color(0.45, 0.5, 0.62) if state == RegionUnlocks.LOCKED else Color.WHITE
			draw_texture_rect(ArtLibrary.texture("map", "map_island_" + region_id), picture, false, dim)
			if state == RegionUnlocks.LOCKED:
				draw_texture_rect(UiIcons.texture("lock"), Rect2(c - Vector2(28, 40), Vector2(56, 56)), false, Color(1, 1, 1, 0.9))
			return
		draw_colored_polygon(_blob(c + Vector2(0, r * 0.12), r, region_id), Color(0.35, 0.3, 0.25, 0.5))  # cliff
		draw_colored_polygon(_blob(c, r, region_id), land)
		match style:
			"pond": _pond(c, r)
			"valley": _valley(c, r)
			"river": _river(c, r)
			"coast": _coast(c, r)
			"isle": _isle(c, r)
		if state == RegionUnlocks.LOCKED:
			draw_colored_polygon(_blob(c, r, region_id), Color(0.08, 0.1, 0.16, 0.45))
			draw_texture_rect(UiIcons.texture("lock"), Rect2(c - Vector2(28, 40), Vector2(56, 56)), false, Color(1, 1, 1, 0.9))

	func _blob(c: Vector2, r: float, seed_id: String) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in 24:
			var angle := TAU * i / 24.0
			var wobble := 0.85 + PropPainter.noise(Vector2(i, seed_id.length()), seed_id.hash() % 97) * 0.25
			points.append(c + Vector2(cos(angle), sin(angle) * 0.72) * r * wobble)
		return points

	func _tree(at: Vector2, size_px: float, color: Color) -> void:
		draw_line(at, at + Vector2(0, -size_px * 0.6), Color("#6b4f3a"), 3.0)
		draw_circle(at + Vector2(0, -size_px * 0.8), size_px * 0.45, color)

	func _pine(at: Vector2, size_px: float) -> void:
		draw_colored_polygon(PackedVector2Array([at + Vector2(-size_px * 0.4, 0), at + Vector2(size_px * 0.4, 0), at + Vector2(0, -size_px * 1.3)]), Color("#2f6b45"))

	func _pond(c: Vector2, r: float) -> void:
		draw_colored_polygon(PropPainter._ellipse(c + Vector2(r * 0.15, r * 0.1), Vector2(r * 0.42, r * 0.24)), Color("#5cc4b2"))
		for p in [Vector2(-0.5, -0.25), Vector2(-0.2, -0.45), Vector2(0.4, -0.4), Vector2(0.6, 0.05)]:
			_tree(c + p * r, r * 0.3, Color("#4f9a45"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-0.55, 0.15) * r, c + Vector2(-0.3, 0.15) * r, c + Vector2(-0.42, -0.08) * r]), Color("#efe4c8"))

	func _valley(c: Vector2, r: float) -> void:
		draw_colored_polygon(PropPainter._ellipse(c + Vector2(0, r * 0.05), Vector2(r * 0.6, r * 0.32)), Color("#8b8f86"))
		draw_rect(Rect2(c + Vector2(-r * 0.06, -r * 0.35), Vector2(r * 0.12, r * 0.4)), Color("#e6f6f8"))
		for p in [Vector2(-0.55, -0.1), Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(0.55, -0.05), Vector2(0.15, 0.35)]:
			_pine(c + p * r, r * 0.32)

	func _river(c: Vector2, r: float) -> void:
		var points := PackedVector2Array()
		for i in 11:
			var t := float(i) / 10.0
			points.append(c + Vector2(lerpf(-0.8, 0.8, t) * r, sin(t * PI * 1.5) * r * 0.2))
		draw_polyline(points, Color("#5ab6d6"), r * 0.18, true)
		draw_rect(Rect2(c + Vector2(r * 0.3, -r * 0.45), Vector2(r * 0.3, r * 0.25)), Color("#9a6b43"))
		draw_arc(c + Vector2(r * 0.25, -r * 0.25), r * 0.12, 0.0, TAU, 12, Color("#6e4a2d"), 3.0)
		for p in [Vector2(-0.5, -0.35), Vector2(-0.2, -0.45), Vector2(0.0, 0.4), Vector2(-0.6, 0.25)]:
			_pine(c + p * r, r * 0.28)

	func _coast(c: Vector2, r: float) -> void:
		draw_colored_polygon(PropPainter._ellipse(c + Vector2(r * 0.25, r * 0.15), Vector2(r * 0.5, r * 0.25)), Color("#7fd0c8"))
		for p in [Vector2(-0.45, -0.1), Vector2(-0.2, -0.3)]:
			var at: Vector2 = c + p * r
			draw_line(at, at + Vector2(6, -r * 0.4), Color("#7a5a3a"), 3.0)
			for k in 5:
				draw_line(at + Vector2(6, -r * 0.4), at + Vector2(6, -r * 0.4) + Vector2.from_angle(PI + k * 0.6) * r * 0.2, Color("#3f8a4a"), 4.0)
		var house := c + Vector2(r * 0.45, -r * 0.35)
		draw_rect(Rect2(house + Vector2(-6, -30), Vector2(12, 30)), Color.WHITE)
		draw_rect(Rect2(house + Vector2(-6, -18), Vector2(12, 6)), Color("#d2553f"))
		draw_circle(house + Vector2(0, -34), 6.0, Color("#d2553f"))

	func _isle(c: Vector2, r: float) -> void:
		draw_circle(c + Vector2(r * 0.6, -r * 0.75), r * 0.16, Color("#f5f1dc"))
		for p in [Vector2(-0.4, -0.2), Vector2(-0.1, -0.4), Vector2(0.3, -0.3)]:
			_tree(c + p * r, r * 0.3, Color("#9b86c9"))
		for k in 3:
			draw_rect(Rect2(c + Vector2(r * (0.05 + k * 0.12), -r * 0.05), Vector2(r * 0.06, r * 0.3)), Color("#c9c4d8"))
		draw_rect(Rect2(c + Vector2(r * 0.02, -r * 0.1), Vector2(r * 0.36, r * 0.06)), Color("#c9c4d8"))
