class_name FishingView
extends Node2D

## What fishing looks like on the pond: rod, line, bobber, the landing ring while aiming, ripples,
## the bite cue and the line's strain during the fight. It listens to the FishingController and
## EventBus and never changes state (UI_UX §4, TECH_SPEC §9: the controller does not know views).
##
## Tension is shown by colour *and* thickness/shape of the line plus the HUD meter, so the state
## is never colour-only. With Reduced Motion the bobber stops bobbing and ripples are fewer.
##
## The angler is drawn art when ArtLibrary has `character/angler_<pose>.png` (D-029): one picture per
## fishing state, the idle one standing in for poses not drawn yet, and the rod held from the picture's
## hands (`art.json`). Without any picture the angler is drawn from shapes.
## The picture wears the straw hat; another equipped hat (D-019) is drawn over it from
## `hats/<accessory id>.png`, its `anchor` on the pose's `head` point, `hat_width` of the picture wide.
## A hat without a picture leaves the drawn straw hat showing.

const BOBBER_RADIUS := 9.0
const RING_LIFETIME := 1.6
const MAX_RINGS := 8
const CAST_ARC_HEIGHT := 170.0
## The angler's hands relative to the seat: where the rod is held.
const HANDS := Vector2(30, -40)

var origin := Vector2(360, 1090)
var rod_base := Vector2(360, 1190)
## Where the angler sits (the chair seat), or (-1, -1) when the layout places no angler.
var angler := Vector2(-1, -1)
var reduced_motion := false
## Accessibility: show an exclamation bubble at the bobber when a fish bites.
var visual_bite_cue := false

var _controller: FishingController
var _aim_active := false
var _aim_point := Vector2.ZERO
var _aim_valid := true
var _landing := Vector2.ZERO
var _bobber := Vector2.ZERO
var _bobber_shown := false
var _state: int = FishingController.State.READY
var _cast_elapsed := 0.0
var _cast_duration := 1.0
var _dip := 0.0
var _clock := 0.0
var _tension := 0.5
var _progress := 0.0
var _rings: Array[Dictionary] = []

func setup(controller: FishingController, rod_tip: Vector2, angler_at: Vector2 = Vector2(-1, -1)) -> void:
	_controller = controller
	origin = rod_tip
	angler = angler_at
	rod_base = angler + HANDS if has_angler() else rod_tip + Vector2(0, 90)
	_bobber = origin
	controller.state_changed.connect(_on_state_changed)
	EventBus.inventory_changed.connect(queue_redraw)  # a new hat shows at once
	EventBus.game_state_replaced.connect(queue_redraw)
	controller.fight_updated.connect(_on_fight_updated)
	EventBus.bite_hinted.connect(_on_bite_hinted)
	EventBus.cast_landed.connect(_on_cast_landed)
	EventBus.fish_escaped.connect(func(_fish_id: String, _reason: String) -> void: _add_ring(_bobber, 1.2))
	EventBus.fish_hooked.connect(func(_fish_id: String) -> void: _add_ring(_bobber, 1.4))
	set_process(true)

## Where the line would land if released now (shown as a ring while the player drags).
func show_aim(point: Vector2, valid: bool) -> void:
	_aim_active = true
	_aim_point = point
	_aim_valid = valid
	queue_redraw()

func hide_aim() -> void:
	_aim_active = false
	queue_redraw()

func bobber_position() -> Vector2:
	return _bobber

func is_line_out() -> bool:
	return _bobber_shown

func _on_state_changed(_previous: int, current: int) -> void:
	_state = current
	match current:
		FishingController.State.CAST:
			_landing = _controller.landing
			_bobber_shown = true
			_cast_elapsed = 0.0
			_cast_duration = 0.9
			_aim_active = false
		FishingController.State.READY, FishingController.State.INSPECT:
			_bobber_shown = false
			_dip = 0.0
		FishingController.State.FIGHT:
			_tension = 0.5
			_progress = _controller.fight.progress if _controller.fight != null else 0.0
	queue_redraw()

func _on_cast_landed(position: Vector2, _habitat: String) -> void:
	_add_ring(position, 1.0)

func _on_bite_hinted() -> void:
	_dip = 1.0
	_add_ring(_bobber, 0.9)

func _on_fight_updated(tension: float, progress: float) -> void:
	_tension = tension
	_progress = progress

func _add_ring(at: Vector2, strength: float) -> void:
	if reduced_motion and not _rings.is_empty():
		return
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append({"pos": at, "age": 0.0, "strength": strength})

func _process(delta: float) -> void:
	_clock += delta
	var active := _bobber_shown or _aim_active or not _rings.is_empty()
	if not active:
		return
	var index := _rings.size() - 1
	while index >= 0:  # age and drop in place: no new array every frame
		_rings[index]["age"] += delta
		if _rings[index]["age"] >= RING_LIFETIME:
			_rings.remove_at(index)
		index -= 1

	match _state:
		FishingController.State.CAST:
			_cast_elapsed += delta
			var t := clampf(_cast_elapsed / _cast_duration, 0.0, 1.0)
			_bobber = origin.lerp(_landing, t) + Vector2(0, -sin(t * PI) * CAST_ARC_HEIGHT)
		FishingController.State.WAIT, FishingController.State.BITE_HINT, FishingController.State.HOOK:
			var bob := 0.0 if reduced_motion else sin(_clock * 2.2) * 2.5
			_bobber = _landing + Vector2(0, bob + _dip * 9.0)
			_dip = maxf(0.0, _dip - delta * 1.6)
		FishingController.State.FIGHT:
			var thrash := 0.0 if reduced_motion else 1.0
			var shake := Vector2(sin(_clock * 17.0), cos(_clock * 13.0)) * 5.0 * _tension * thrash
			_bobber = _landing.lerp(origin + Vector2(0, -60), _progress * 0.55) + shake
		FishingController.State.LAND:
			_bobber = _bobber.lerp(origin + Vector2(0, -20), clampf(delta * 5.0, 0.0, 1.0))
	queue_redraw()

func has_angler() -> bool:
	return angler.x >= 0.0 and angler.y >= 0.0

## The angler's pose for the current fishing state (the name part of `angler_<pose>.png`).
func angler_pose() -> String:
	match _state:
		FishingController.State.CAST:
			return "cast"
		FishingController.State.BITE_HINT, FishingController.State.HOOK:
			return "bite"
		FishingController.State.FIGHT:
			return "reel"
		FishingController.State.LAND, FishingController.State.INSPECT:
			return "hold"
	return "idle"

## The angler's picture right now: {"texture", "rect", "hands"} in world space, or {} when the angler is
## drawn from shapes (no layout seat or no picture).
func angler_art() -> Dictionary:
	if not has_angler():
		return {}
	var pose := "angler_" + angler_pose()
	var tex := ArtLibrary.texture("character", pose)
	if tex == null:
		pose = "angler_idle"
		tex = ArtLibrary.texture("character", pose)
	if tex == null:
		return {}
	var data := ArtLibrary.meta("character", pose, "angler")
	var height := float(data.get("height", 150.0))
	var rect := ArtLibrary.placed_rect(tex, angler, height * tex.get_width() / maxf(1.0, tex.get_height()),
		ArtLibrary.point(data, "anchor", Vector2(0.5, 0.9)))
	return {"texture": tex, "rect": rect, "pose": pose,
		"hands": rect.position + ArtLibrary.point(data, "hands", Vector2(0.62, 0.42)) * rect.size}

## The equipped hat over the angler picture `art` (from `angler_art`): {"texture", "rect"}, or {} when
## there is no angler picture or the hat has no picture of its own.
func hat_art(art: Dictionary) -> Dictionary:
	if art.is_empty():
		return {}
	var accessory := GameState.get_equipped_accessory()
	var tex := ArtLibrary.texture("hats", accessory)
	if tex == null:
		return {}
	var pose_data := ArtLibrary.meta("character", art["pose"], "angler")
	var rect: Rect2 = art["rect"]
	var head := rect.position + ArtLibrary.point(pose_data, "head", Vector2(0.5, 0.2)) * rect.size
	var width := rect.size.x * float(pose_data.get("hat_width", 0.5))
	var anchor := ArtLibrary.point(ArtLibrary.meta("hats", accessory), "anchor", Vector2(0.5, 0.6))
	return {"texture": tex, "rect": ArtLibrary.placed_rect(tex, head, width, anchor)}

## Where the rod leaves the angler's hands.
func current_rod_base() -> Vector2:
	var art := angler_art()
	return art["hands"] if not art.is_empty() else rod_base

func _draw() -> void:
	var art := angler_art()
	if not art.is_empty():
		draw_texture_rect(art["texture"], art["rect"], false)
		var hat := hat_art(art)
		if not hat.is_empty():
			draw_texture_rect(hat["texture"], hat["rect"], false)
	elif has_angler():
		_draw_angler()
	var base: Vector2 = art["hands"] if not art.is_empty() else rod_base
	# Rod: a curve from the hands to the tip, bending towards the fish while fighting.
	var bend := Vector2(10, 0)
	if _state == FishingController.State.FIGHT:
		bend = (_bobber - origin).normalized() * (14.0 + 26.0 * _tension)
	var rod := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		rod.append(base.lerp(origin, t) + bend * sin(t * PI) * t)
	draw_polyline(rod, Color("#3f3022"), 7.0, true)
	draw_polyline(rod, Color("#8a6440"), 4.0, true)
	draw_circle(base + (origin - base).normalized() * 18.0, 8.0, Color("#c9c4b8"))  # reel
	draw_circle(base + (origin - base).normalized() * 18.0, 3.0, Color("#6c675e"))

	if _aim_active:
		var pulse := 1.0 if reduced_motion else 1.0 + sin(_clock * 4.0) * 0.08
		var color := Color(1, 1, 1, 0.85) if _aim_valid else Color(0.85, 0.85, 0.85, 0.5)
		_draw_ring(_aim_point, 26.0 * pulse, color, 3.0)
		_draw_ring(_aim_point, 12.0 * pulse, color, 2.0)
		if not _aim_valid:
			draw_line(_aim_point + Vector2(-8, -8), _aim_point + Vector2(8, 8), color, 3.0)
			draw_line(_aim_point + Vector2(-8, 8), _aim_point + Vector2(8, -8), color, 3.0)

	for ring in _rings:
		var life: float = ring["age"] / RING_LIFETIME
		_draw_ring(ring["pos"], 8.0 + life * 46.0 * float(ring["strength"]), Color(1, 1, 1, (1.0 - life) * 0.7), 2.0)

	if not _bobber_shown:
		return
	_draw_line_to_bobber()
	draw_circle(_bobber, BOBBER_RADIUS + 1.5, Color(0.1, 0.1, 0.1, 0.35))
	draw_circle(_bobber, BOBBER_RADIUS, Color("#f2f2f2"))
	draw_arc(_bobber, BOBBER_RADIUS * 0.6, PI, TAU, 10, Color("#e8483c"), BOBBER_RADIUS * 0.9)

	if _state == FishingController.State.BITE_HINT or _state == FishingController.State.HOOK:
		_draw_bite_callout()

	if _state == FishingController.State.FIGHT:
		# The fish under the surface: a dark shape that thrashes harder with more tension.
		draw_colored_polygon(_ellipse(_bobber + Vector2(0, 14), Vector2(26, 10)), Color(0.05, 0.12, 0.16, 0.5))

func _draw_line_to_bobber() -> void:
	var strained := _state == FishingController.State.FIGHT
	var color := Color(1, 1, 1, 0.85)
	var width := 2.0
	if strained:
		color = Color("#6fd08c").lerp(Color("#f4cf4c"), clampf((_tension - 0.3) / 0.3, 0.0, 1.0)).lerp(Color("#ef6a5a"), clampf((_tension - 0.7) / 0.3, 0.0, 1.0))
		width = 2.0 + _tension * 3.0
	var slack := 1.0 - (_tension if strained else 0.5)
	var mid := origin.lerp(_bobber, 0.5) + Vector2(0, 60.0 * slack)
	var points := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		points.append(origin.lerp(mid, t).lerp(mid.lerp(_bobber, t), t))
	draw_polyline(points, color, width, true)

func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	draw_polyline(_ellipse(center, Vector2(radius, radius * 0.45), 28) + PackedVector2Array([center + Vector2(radius, 0)]), color, width, true)

static func _ellipse(center: Vector2, radius: Vector2, steps: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * i / steps
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

## The "입질!" speech bubble of the bite mockup, pointing at the bobber, with spark marks. The Visual
## Bite Cue setting adds a pulsing ring around the bobber for players who may miss the dip.
func _draw_bite_callout() -> void:
	var anchor := _bobber + Vector2(26, -34)
	var box := Rect2(anchor + Vector2(10, -64), Vector2(150, 56))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#2c2a22").lerp(Color(0, 0, 0), 0.1)
	style.bg_color.a = 0.82
	style.border_color = Color("#f3e6c8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(26)
	draw_colored_polygon(PackedVector2Array([anchor, box.position + Vector2(24, box.size.y - 2), box.position + Vector2(48, box.size.y - 2)]), style.bg_color)
	draw_style_box(style, box)
	var fish := UiIcons.texture("fish")
	draw_texture_rect(fish, Rect2(box.position + Vector2(14, 12), Vector2(34, 34)), false, Color("#f3e6c8"))
	draw_string(ThemeDB.fallback_font, box.position + Vector2(56, 38), tr("ui.fight.bite"), HORIZONTAL_ALIGNMENT_LEFT, 90, 26, Color("#fff4dc"))
	for spark in [Vector2(-30, -26), Vector2(-40, -6), Vector2(36, 10)]:
		var at: Vector2 = _bobber + spark
		draw_polyline(PackedVector2Array([at, at + Vector2(6, 8), at + Vector2(1, 10), at + Vector2(8, 18)]), Color("#ffd23f"), 3.0, true)
	if visual_bite_cue:
		var pulse := 1.0 if reduced_motion else 1.0 + 0.15 * sin(_clock * 8.0)
		_draw_ring(_bobber, 34.0 * pulse, Color("#ffd23f"), 4.0)

## The angler of the mockup, seated on a camp chair on the dock: straw hat with a green band and a
## flower, cream shirt, green overalls. Drawn here because the pose follows the fishing state (a
## startled lean when a fish bites, a firm lean back while reeling).
func _draw_angler() -> void:
	var lean := Vector2.ZERO
	if _state == FishingController.State.FIGHT:
		lean = Vector2(-4, 2)
	elif _state == FishingController.State.BITE_HINT or _state == FishingController.State.HOOK:
		lean = Vector2(3, -2)
	var seat := angler
	draw_colored_polygon(_ellipse(seat + Vector2(4, 22), Vector2(46, 12)), Color(0, 0, 0, 0.2))
	# Chair: back, legs, seat.
	draw_colored_polygon(PackedVector2Array([seat + Vector2(-34, -66), seat + Vector2(4, -74), seat + Vector2(8, -6), seat + Vector2(-30, 0)]), Color("#cfc7b0"))
	for leg in [[Vector2(-30, 0), Vector2(12, 26)], [Vector2(10, -4), Vector2(-24, 24)]]:
		draw_line(seat + leg[0], seat + leg[1], Color("#6b4f3a"), 4.0)
	draw_colored_polygon(PackedVector2Array([seat + Vector2(-30, -2), seat + Vector2(16, -10), seat + Vector2(26, 4), seat + Vector2(-20, 12)]), Color("#d9d1bb"))
	var body := seat + lean
	# Legs and boots towards the water.
	draw_line(body + Vector2(-2, -6), body + Vector2(30, 6), Color("#5c7046"), 13.0)
	draw_line(body + Vector2(30, 6), body + Vector2(36, 24), Color("#5c7046"), 11.0)
	draw_colored_polygon(_ellipse(body + Vector2(40, 28), Vector2(11, 6)), Color("#4a3426"))
	# Torso: overalls over a cream shirt.
	draw_colored_polygon(_ellipse(body + Vector2(-8, -30), Vector2(20, 28)), Color("#f1ead8"))
	draw_colored_polygon(PackedVector2Array([body + Vector2(-24, -24), body + Vector2(8, -28), body + Vector2(10, 0), body + Vector2(-22, 2)]), Color("#62774a"))
	draw_line(body + Vector2(-16, -26), body + Vector2(-12, -50), Color("#62774a"), 4.0)
	# Arms reaching for the rod.
	var hands := seat + HANDS
	draw_line(body + Vector2(-6, -44), hands, Color("#f1ead8"), 9.0)
	draw_circle(hands, 5.5, Color("#f0c9a4"))
	# Head, hair and the straw hat.
	var head := body + Vector2(-8, -66)
	draw_circle(head + Vector2(-4, 4), 15.0, Color("#5b3b26"))  # hair
	draw_circle(head, 13.0, Color("#f3d2b0"))
	# The hat is the equipped accessory (D-019).
	var accessory := ContentDB.get_accessory(GameState.get_equipped_accessory())
	var hat := Color(accessory.get("hat", "#ece0c2"))
	var band := Color(accessory.get("band", "#5f7a4a"))
	draw_colored_polygon(_ellipse(head + Vector2(0, -8), Vector2(34, 13)), hat)
	draw_colored_polygon(_ellipse(head + Vector2(0, -16), Vector2(18, 12)), hat.lightened(0.08))
	draw_colored_polygon(_ellipse(head + Vector2(0, -10), Vector2(18, 4)), band)
	draw_circle(head + Vector2(10, -11), 4.0, Color("#fdfbf3"))
	draw_circle(head + Vector2(10, -11), 1.6, Color("#f3c84b"))
	if _state == FishingController.State.BITE_HINT or _state == FishingController.State.HOOK:
		for mark in [[Vector2(-30, -30), Vector2(-38, -40)], [Vector2(-18, -40), Vector2(-20, -52)], [Vector2(2, -38), Vector2(8, -50)]]:
			draw_line(head + mark[0], head + mark[1], Color("#ffd23f"), 3.0)
