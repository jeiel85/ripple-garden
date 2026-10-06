class_name PopulationModel
extends RefCounted

## Turns the persistent per-species population into the handful of fish actually drawn
## (TECH_SPEC §6). The save stores numbers; the screen shows representatives:
##
##   population 1..10 -> 1 fish, 11..30 -> 2, 31..60 -> 3, 61+ -> 4   (balance.json `population`)
##
## and the total number of swimming agents is capped by graphics quality (and Battery Saver).
## When the cap bites, each species keeps at least one fish for as long as possible and the
## most numerous species give up fish first, so a rare newcomer never disappears for a crowd of
## carp. Pure and deterministic.

var _steps: Array
var _totals: Dictionary
var _battery_factor: float

## `population_config` is balance.json `population`.
func _init(population_config: Dictionary) -> void:
	_steps = population_config["visible_by_population"]
	_totals = population_config["total_agents_by_quality"]
	_battery_factor = float(population_config["battery_saver_agent_factor"])

## Fish shown for a species of `population` individuals (0 when it is absent).
func visible_count(population: int) -> int:
	if population <= 0:
		return 0
	for step in _steps:
		if population <= int(step["up_to"]):
			return int(step["visible"])
	return int(_steps.back()["visible"])

## Agent budget for a quality tier ("low", "medium", "high"); Battery Saver reduces it.
func total_cap(quality: String, battery_saver: bool) -> int:
	var cap := int(_totals.get(quality, _totals["medium"]))
	if battery_saver:
		cap = maxi(1, roundi(cap * _battery_factor))
	return cap

## {fish_id: fish drawn} for `populations` ({fish_id: population}) within `cap` agents.
func compose(populations: Dictionary, cap: int) -> Dictionary:
	var counts := {}
	var total := 0
	var ids: Array = populations.keys()
	ids.sort()
	for fish_id in ids:
		var shown := visible_count(int(populations[fish_id]))
		if shown > 0:
			counts[fish_id] = shown
			total += shown

	# Too many species for even one fish each: keep the ones with the largest populations.
	if counts.size() > cap:
		var by_population: Array = counts.keys()
		by_population.sort_custom(func(a: String, b: String) -> bool:
			var pa: int = populations[a]
			var pb: int = populations[b]
			return pa > pb or (pa == pb and a < b))
		var kept := {}
		for i in cap:
			kept[by_population[i]] = 1
		return kept

	# Otherwise shave the largest groups first until the budget fits.
	while total > cap:
		var biggest := ""
		for fish_id in ids:
			if counts.has(fish_id) and counts[fish_id] > 1 and (biggest.is_empty() or counts[fish_id] > counts[biggest]):
				biggest = fish_id
		if biggest.is_empty():
			break
		counts[biggest] -= 1
		total -= 1
	return counts
