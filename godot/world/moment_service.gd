class_name MomentService
extends RefCounted

## Moments (GDD §3 "관찰", UI_UX §2 Journal > Moments, P1-008): small things worth having seen — mist on a
## dawn pond, a sunshower, fireflies over a restored pond, watching the moon in water-mind. Each is
## defined in data/moments.json by a `when` condition; the first time the world matches it, the moment
## is written into the journal with a little Memory (the exploration currency, GDD §11).
##
## Conditions (all present keys must hold):
##   weather [ids]  band [time bands]  min_level n  water_mind true
##   caught_rarity n (a catch of at least this rarity)  camp_filled n (camp slots filled)
##   after_away true (the pond kept something for the player while they were away)
## The service is asked to look whenever something relevant changes; nothing runs per frame.

var region_id := ""

var _state: Node
## () -> {"weather": String, "band": String, "water_mind": bool}: the current scene (tests replace it).
var context_provider := Callable()

func _init(game_state: Node, p_region_id: String) -> void:
	_state = game_state
	region_id = p_region_id

## Records every moment whose condition holds now (plus the one-off facts in `event`). Returns the ids
## recorded this time.
func check(event: Dictionary = {}) -> Array:
	var context := _context()
	context.merge(event, true)
	var recorded: Array = []
	for moment_id in ContentDB.moments:
		if _state.has_moment(moment_id):
			continue
		var def: Dictionary = ContentDB.moments[moment_id]
		if matches(def["when"], context):
			_state.record_moment(moment_id)
			var memory := int(def.get("memory", 0))
			if memory > 0:
				_state.add_memory(memory)
			recorded.append(moment_id)
			EventBus.moment_recorded.emit(moment_id)
	return recorded

## Whether a `when` condition holds in `context` (pure; see the class description for the keys).
static func matches(when: Dictionary, context: Dictionary) -> bool:
	if when.has("weather") and not context.get("weather", "") in when["weather"]:
		return false
	if when.has("band") and not context.get("band", "") in when["band"]:
		return false
	if when.has("min_level") and int(context.get("level", 0)) < int(when["min_level"]):
		return false
	if when.has("water_mind") and context.get("water_mind", false) != when["water_mind"]:
		return false
	if when.has("caught_rarity") and int(context.get("caught_rarity", 0)) < int(when["caught_rarity"]):
		return false
	if when.has("camp_filled") and int(context.get("camp_filled", 0)) < int(when["camp_filled"]):
		return false
	if when.has("after_away") and context.get("after_away", false) != true:
		return false
	return true

func _context() -> Dictionary:
	var scene: Dictionary = context_provider.call() if context_provider.is_valid() else {}
	return {
		"weather": scene.get("weather", ""),
		"band": scene.get("band", TimeService.get_time_band()),
		"water_mind": scene.get("water_mind", false),
		"level": _state.get_restoration_level(region_id),
		"camp_filled": _state.get_camp(region_id).size(),
	}
