class_name CameraController
extends Camera2D

## The fixed diorama camera (TECH_SPEC §2). The world is composed for a 720x1280 portrait view
## centred here; on wider or taller screens the viewport simply shows more of the scenery that
## the environment draws past the design edges.
##
## It only adds two gentle effects: a slow zoom pulse when the pond is restored (UI_UX §6), and a
## small shake when a line snaps. Camera Shake off or Reduced Motion removes the shake, and
## Reduced Motion replaces the zoom with a stationary view (the UI flashes a soft highlight).

const DESIGN_CENTER := Vector2(360, 640)

var reduced_motion := false
var shake_enabled := true

var _tween: Tween
var _shake_tween: Tween

func _ready() -> void:
	position = DESIGN_CENTER
	make_current()

## Slow zoom in and back out over `duration` seconds. No-op with Reduced Motion.
func restoration_pulse(duration: float = 3.0) -> void:
	if reduced_motion:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "zoom", Vector2.ONE * 1.07, duration * 0.5)
	_tween.tween_property(self, "zoom", Vector2.ONE, duration * 0.5)

## A short, small jolt. No-op when disabled or with Reduced Motion.
func shake(strength: float = 6.0, duration: float = 0.25) -> void:
	if reduced_motion or not shake_enabled:
		return
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for i in 5:
		var falloff := 1.0 - float(i) / 5.0
		_shake_tween.tween_property(self, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff, duration / 5.0)
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.05)
