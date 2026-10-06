class_name CastAim
extends RefCounted

## Geometry of the drag-to-aim cast (UI_UX §4 Aim). The finger marks where the line should land;
## the point is pulled into what the rod can reach and into a forward cone, and dragging back
## onto the rod cancels. No trajectory is drawn, only the landing ring.
##
## Pure and unit-tested; CastInputHandler feeds it pointer positions and draws the result.

## Releases closer than this to where the press started count as a tap (quick cast).
const TAP_MAX_DRAG_PX := 24.0
## Widest angle away from straight "up" the line may be cast.
const MAX_ANGLE_DEG := 80.0

## Where the line leaves the rod tip.
var origin := Vector2.ZERO
## Reach limits in pixels for the equipped rod.
var min_distance := 120.0
var max_distance := 600.0
## Releasing within this radius of the origin cancels the cast.
var cancel_radius := 56.0

func _init(origin_point: Vector2, near_px: float, far_px: float) -> void:
	origin = origin_point
	min_distance = near_px
	max_distance = far_px

## Reach for a rod: `rod_range` is the rod's 0..1 range stat mapped onto [near_px, far_px].
static func reach_for_rod(rod_range: float, near_px: float, far_px: float) -> float:
	return lerpf(near_px, far_px, clampf(rod_range, 0.0, 1.0))

## Landing point for a pointer position: distance clamped to [min, max] and the direction kept
## within MAX_ANGLE_DEG of straight up (negative y). A pointer on the origin aims straight up.
func landing_for(pointer: Vector2) -> Vector2:
	var offset := pointer - origin
	var distance := clampf(offset.length(), min_distance, max_distance)
	var direction := Vector2.UP
	if offset.length_squared() > 0.0001:
		var angle := Vector2.UP.angle_to(offset.normalized())
		var limit := deg_to_rad(MAX_ANGLE_DEG)
		direction = Vector2.UP.rotated(clampf(angle, -limit, limit))
	return origin + direction * distance

## True when the pointer is close enough to the rod that releasing should cancel.
func is_cancel(pointer: Vector2) -> bool:
	return pointer.distance_to(origin) <= cancel_radius

## True when a press-release moved so little that it should be treated as a tap.
static func is_tap(press: Vector2, release: Vector2) -> bool:
	return press.distance_to(release) <= TAP_MAX_DRAG_PX

## Default target for a quick cast: the last landing point if there is one, otherwise straight
## ahead at 60 % of the rod's reach.
func quick_cast_point(last_landing: Variant) -> Vector2:
	if last_landing is Vector2:
		return landing_for(last_landing)
	return origin + Vector2.UP * lerpf(min_distance, max_distance, 0.6)
