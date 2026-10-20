class_name WaitAmbience
extends Node2D

## Small things that happen while the line is out (BACKLOG "WAIT 중 앰비언트 이벤트"): a fish arcs
## out of the water, or a frog hops in, a little way from the bobber. One event per cast, at a random
## moment inside the wait, and never over the nibble — the player should notice it without it ever
## looking like a bite.
##
## Presentation only: it listens to the fishing controller and never changes state (TECH_SPEC §9).
## Moving water (riffles, channels, open water) gets the leaping fish, still reedy edges get the frog.
## With Reduced Motion the arc is skipped and only the ring on the water remains.

const LEAP_TIME := 0.85
const FROG_TIME := 0.75
## How far from the bobber the event may happen: close enough to see, far enough not to read as a bite.
const SIDE_REACH := 64.0
const NEAR_REACH := 26.0
## A wait shorter than this has no room for an event before the nibble.
const MIN_WAIT := 1.8
## Habitats where a fish jumping clear of the water is the natural thing to see.
const LEAP_HABITATS: PackedStringArray = ["riffle", "channel", "open_water", "deep", "bottom", "reef"]

var reduced_motion := false

var _controller: FishingController
var _view: FishingView
var _region_id := ""
var _splash := Callable()
var _rng := RandomNumberGenerator.new()
var _delay := -1.0
var _kind := ""
var _at := Vector2.ZERO
var _age := 0.0
var _active := false

## `splash` plays a quiet water sound when the event lands (game_root passes the "landed" cue).
func setup(controller: FishingController, view: FishingView, region_id: String, splash: Callable = Callable(), rng_seed: int = 0) -> void:
	_controller = controller
	_view = view
	_region_id = region_id
	_splash = splash
	_rng.seed = rng_seed if rng_seed != 0 else hash(region_id)
	_controller.state_changed.connect(_on_state_changed)
	set_process(false)

## What would happen in this habitat: a leaping fish over moving water, a frog at a still, reedy edge.
func kind_for(habitat: String) -> String:
	return "leap" if habitat in LEAP_HABITATS else "frog"

func is_active() -> bool:
	return _active

func active_kind() -> String:
	return _kind if _active else ""

## Seconds until the planned event, or -1 when none is planned.
func pending_delay() -> float:
	return _delay

func event_position() -> Vector2:
	return _at

func _on_state_changed(_previous: int, current: int) -> void:
	if current == FishingController.State.WAIT:
		_plan()
	else:
		_clear()

func _plan() -> void:
	_clear()
	var left := _controller.time_left()
	var kind := kind_for(_controller.habitat)
	var duration := LEAP_TIME if kind == "leap" else FROG_TIME
	var latest := left - duration - 0.35
	if latest < 0.45:
		return  # too short a wait: the nibble would cut the event off
	_kind = kind
	var bobber := _view.bobber_position() if _view != null else _controller.landing
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	_at = bobber + Vector2(side * _rng.randf_range(NEAR_REACH * 0.4, SIDE_REACH), _rng.randf_range(4.0, 22.0))
	_delay = _rng.randf_range(0.35, minf(latest, 2.4))
	set_process(true)

func _clear() -> void:
	_delay = -1.0
	_kind = ""
	_active = false
	_age = 0.0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	tick(delta)

## Advances the event by `delta` seconds (the tree calls this; tests drive it directly).
func tick(delta: float) -> void:
	if _active:
		_age += delta
		queue_redraw()
		if _age >= _duration():
			_clear()
		return
	if _delay < 0.0:
		return
	_delay -= delta
	if _delay <= 0.0:
		_fire()

func _fire() -> void:
	_delay = -1.0
	_active = true
	_age = 0.0
	reduced_motion = GameState.get_setting("reduced_motion") == true
	if _splash.is_valid():
		_splash.call()
	queue_redraw()

func _duration() -> float:
	return LEAP_TIME if _kind == "leap" else FROG_TIME

func _draw() -> void:
	if not _active:
		return
	var t := clampf(_age / _duration(), 0.0, 1.0)
	var lift := sin(t * PI)
	var water := Color(0.93, 0.97, 1.0, 0.8)
	# Rings on the water where the event starts and where it comes back down.
	_ring(t, 0.0, 3.0 + 16.0 * clampf(t / 0.35, 0.0, 1.0), clampf(1.0 - t / 0.45, 0.0, 1.0), water)
	_ring(t, 0.65, 3.0 + 18.0 * clampf((t - 0.65) / 0.35, 0.0, 1.0), clampf((t - 0.65) / 0.35, 0.0, 1.0), water)
	if reduced_motion:
		return  # the rings alone: no arc across the water
	var height := 30.0 if _kind == "leap" else 18.0
	var pos := _at - Vector2(0, lift * height)
	if _kind == "leap":
		var tilt := (t - 0.5) * 1.4
		draw_set_transform(pos, tilt, Vector2.ONE)
		var body := Color(0.38, 0.48, 0.56, 0.95)
		draw_circle(Vector2.ZERO, 4.6, body)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-4.0, 0.0), Vector2(-9.5, -3.4), Vector2(-9.5, 3.4),
		]), body)
		draw_circle(Vector2(2.6, -1.2), 0.9, Color(1.0, 1.0, 1.0, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var frog := Color(0.36, 0.55, 0.32, 0.95)
		draw_circle(pos, 4.2, frog)
		draw_circle(pos + Vector2(-2.4, -2.0), 1.0, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(pos + Vector2(2.4, -2.0), 1.0, Color(1.0, 1.0, 1.0, 0.9))
		var stretch := 1.0 + lift * 1.4
		draw_line(pos + Vector2(-2.0, 3.0), pos + Vector2(-2.0 - stretch, 5.0), frog, 1.4)
		draw_line(pos + Vector2(2.0, 3.0), pos + Vector2(2.0 + stretch, 5.0), frog, 1.4)

## One expanding ring, faded out as it grows. `start` is the point in the event where it begins.
func _ring(t: float, start: float, radius: float, alpha: float, color: Color) -> void:
	if t < start or alpha <= 0.0:
		return
	draw_arc(_at, radius, 0.0, TAU, 28, Color(color, color.a * alpha), 1.6, true)
