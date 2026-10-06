class_name FishingView
extends Node2D

## What fishing looks like on the pond: rod, line, bobber, the landing ring while aiming, ripples,
## the bite cue and the line's strain during the fight. It listens to the FishingController and
## EventBus and never changes state (UI_UX §4, TECH_SPEC §9: the controller does not know views).
##
## Tension is shown by colour *and* thickness/shape of the line plus the HUD meter, so the state
## is never colour-only. With Reduced Motion the bobber stops bobbing and ripples are fewer.

const BOBBER_RADIUS := 9.0
const RING_LIFETIME := 1.6
const MAX_RINGS := 8
const CAST_ARC_HEIGHT := 170.0

var origin := Vector2(360, 1090)
var rod_base := Vector2(360, 1190)
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

func setup(controller: FishingController, rod_tip: Vector2) -> void:
	_controller = controller
	origin = rod_tip
	rod_base = rod_tip + Vector2(0, 90)
	_bobber = origin
	controller.state_changed.connect(_on_state_changed)
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

func _draw() -> void:
	# Rod: a gentle curve from the angler up to the tip.
	draw_polyline(PackedVector2Array([rod_base, rod_base.lerp(origin, 0.55) + Vector2(10, 0), origin]), Color("#5d4630"), 6.0, true)
	draw_circle(rod_base, 9.0, Color("#3f3022"))

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

	if visual_bite_cue and (_state == FishingController.State.BITE_HINT or _state == FishingController.State.HOOK):
		var bubble := _bobber + Vector2(0, -46)
		draw_circle(bubble, 20.0, Color("#fff3c4"))
		draw_arc(bubble, 20.0, 0.0, TAU, 24, Color("#d9a521"), 3.0)
		draw_string(ThemeDB.fallback_font, bubble + Vector2(-5, 9), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("#7a4b00"))

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
