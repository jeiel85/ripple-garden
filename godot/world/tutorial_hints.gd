class_name TutorialHints
extends RefCounted

## Which tutorial hints still need to be shown (Tutorial Hints setting, UI_UX §9). A hint is shown
## once per save: asking for it with `take()` marks it as seen, so the interface never changes
## state itself and "seen" survives restarts. Turning the setting off silences every hint without
## using them up.

var _state: Node
var _region_id: String

func _init(game_state: Node, region_id: String) -> void:
	_state = game_state
	_region_id = region_id

## True when `hint_id` should be shown right now; marks it as seen when it does.
func take(hint_id: String) -> bool:
	if _state.get_setting("tutorial_hints") != true or _state.has_seen_event(_region_id, hint_id):
		return false
	_state.mark_event_seen(_region_id, hint_id)
	return true
