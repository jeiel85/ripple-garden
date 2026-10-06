class_name LoadoutService
extends RefCounted

## The command boundary for choosing equipment (TECH_SPEC §3: UI -> command -> service -> state).
## The gear screen asks this service to equip a rod or bait; the service checks that the item is
## real content the player owns and only then lets GameState change. Equipment changes how and where
## you fish, never how strong you are (GDD §12).

var _state: Node

func _init(game_state: Node) -> void:
	_state = game_state

## Equips an owned rod. Returns false (nothing changes) for unknown or unowned rods.
func equip_rod(rod_id: String) -> bool:
	if ContentDB.get_rod(rod_id).is_empty():
		return false
	return _state.equip_rod(rod_id)

## Equips an owned bait. Returns false (nothing changes) for unknown or unowned baits.
func equip_bait(bait_id: String) -> bool:
	if ContentDB.get_bait(bait_id).is_empty():
		return false
	return _state.equip_bait(bait_id)
