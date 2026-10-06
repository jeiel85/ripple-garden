class_name FishingFeedback
extends Node

## Physical feedback for fishing events (P0-013): short haptic pulses on bite hint, hook and
## catch. Presenters for visuals and audio subscribe to the same EventBus events on their own,
## so this class is the single place that decides when the device buzzes and respects the
## player's Haptics setting. A missed or escaped fish gets no buzz: failure stays quiet.
##
## The pulse sink is injectable; the default uses Input.vibrate_handheld (a no-op off-device).

## Event -> duration in milliseconds.
const PULSES_MS := {
	"bite_hinted": 25,
	"fish_hooked": 45,
	"fish_caught": 70,
}

var haptic_sink := Callable()
var game_state: Node = null

func _ready() -> void:
	EventBus.bite_hinted.connect(func() -> void: pulse("bite_hinted"))
	EventBus.fish_hooked.connect(func(_fish_id: String) -> void: pulse("fish_hooked"))
	EventBus.fish_caught.connect(func(_fish_id: String, _size_cm: float, _first: bool) -> void: pulse("fish_caught"))

## Fires the pulse for `event_name` unless haptics are off. Returns whether it fired.
func pulse(event_name: String) -> bool:
	var settings_owner := game_state if game_state != null else GameState
	if settings_owner.get_setting("haptics") != true or not PULSES_MS.has(event_name):
		return false
	var duration: int = PULSES_MS[event_name]
	if haptic_sink.is_valid():
		haptic_sink.call(duration)
	else:
		Input.vibrate_handheld(duration)
	return true
