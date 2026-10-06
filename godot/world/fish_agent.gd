class_name FishAgent
extends Node2D

## One visible fish: a pooled node that swims in the pond (TECH_SPEC §6-7). It is only a
## representative of the persistent population; it carries no state worth saving. The
## presenter steers it (desired velocity from a throttled "AI tick"), the agent only draws
## itself and wiggles its tail every frame so motion stays smooth between ticks.
##
## Look: a silhouette whose size follows the species' size range and whose colour is derived
## deterministically from the fish id (placeholder art, D-011); rarer fish are more saturated.

const MIN_LENGTH_PX := 16.0
const MAX_LENGTH_PX := 46.0

var fish_id := ""
var habitats: Array = []
var behavior := "steady"
var length_px := 24.0
var base_speed := 36.0
var body_color := Color.WHITE
var accent_color := Color.WHITE

## Set by the presenter's AI tick; integrated every frame.
var velocity := Vector2.ZERO
var heading := 0.0
var target := Vector2.ZERO
var think_left := 0.0
var burst_left := 0.0
var wander_phase := 0.0
## Seconds left of the "welcome" ring drawn around a freshly released fish.
var highlight := 0.0

var _tail: Node2D
var _swim_phase := 0.0

func _init() -> void:
	_tail = Node2D.new()
	_tail.name = "Tail"
	_tail.draw.connect(_draw_tail)
	add_child(_tail)

## Prepares the (possibly reused) agent for a species. Resets all transient motion state.
func configure(fish_def: Dictionary) -> void:
	fish_id = fish_def["id"]
	habitats = fish_def["habitats"]
	behavior = fish_def["behavior"]
	var size_range: Dictionary = fish_def["size_cm"]
	var share := clampf(inverse_lerp(5.0, 90.0, (float(size_range["min"]) + float(size_range["max"])) / 2.0), 0.0, 1.0)
	length_px = lerpf(MIN_LENGTH_PX, MAX_LENGTH_PX, sqrt(share))
	base_speed = 26.0 + 14.0 * (1.0 - share)
	var rarity := int(fish_def["rarity"])
	var hue := float(absi(hash(fish_id)) % 360) / 360.0
	body_color = Color.from_hsv(hue, 0.30 + 0.07 * rarity, 0.78 - 0.02 * rarity)
	accent_color = Color.from_hsv(fposmod(hue + 0.08, 1.0), 0.55 + 0.08 * rarity, 0.9)
	velocity = Vector2.ZERO
	target = Vector2.ZERO  # a pooled agent must not keep swimming to the previous species' destination
	heading = randf() * TAU
	think_left = 0.0
	burst_left = 0.0
	highlight = 0.0
	_swim_phase = randf() * TAU
	wander_phase = randf() * TAU
	rotation = heading
	_tail.position = Vector2(-length_px * 0.42, 0)
	queue_redraw()
	_tail.queue_redraw()

## Per-frame visual update: turn towards the velocity and wiggle the tail.
func animate(delta: float, reduced_motion: bool) -> void:
	if velocity.length_squared() > 1.0:
		heading = lerp_angle(heading, velocity.angle(), clampf(delta * 6.0, 0.0, 1.0))
		rotation = heading
	_swim_phase += delta * (3.0 + velocity.length() / 14.0)
	_tail.rotation = sin(_swim_phase) * (0.18 if reduced_motion else 0.45)
	if highlight > 0.0:
		highlight = maxf(0.0, highlight - delta)
		queue_redraw()

func _draw() -> void:
	var half := length_px / 2.0
	var body := PackedVector2Array()
	for i in 14:
		var angle := TAU * i / 14.0
		body.append(Vector2(cos(angle) * half, sin(angle) * half * 0.42))
	draw_colored_polygon(body, body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-half * 0.2, -half * 0.3), Vector2(half * 0.35, -half * 0.12), Vector2(half * 0.35, half * 0.12), Vector2(-half * 0.2, half * 0.3)]),
		Color(accent_color.r, accent_color.g, accent_color.b, 0.55))
	draw_circle(Vector2(half * 0.62, -half * 0.08), maxf(1.5, half * 0.07), Color(0.08, 0.1, 0.12))
	if highlight > 0.0:
		var alpha := clampf(highlight / 2.5, 0.0, 1.0)
		draw_arc(Vector2.ZERO, half + 8.0 + (1.0 - alpha) * 22.0, 0.0, TAU, 28, Color(1, 1, 1, alpha * 0.85), 2.5)

func _draw_tail() -> void:
	var size := length_px * 0.34
	_tail.draw_colored_polygon(PackedVector2Array([Vector2(size * 0.4, 0), Vector2(-size, -size * 0.7), Vector2(-size * 0.55, 0), Vector2(-size, size * 0.7)]),
		body_color.darkened(0.12))
