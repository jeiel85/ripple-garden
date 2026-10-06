class_name EncounterResolver
extends RefCounted

## Decides which fish bites (GDD §8, TECH_SPEC §8):
##
##   FinalWeight = BaseWeight x Time x Weather x Bait x Ecosystem x Pity x Temporary
##
## over the fish that live in the region and in the habitat the line landed in. Habitat is a
## filter rather than a multiplier: a fish either lives there or it does not.
##
## The resolver is pure: all randomness comes from the RandomNumberGenerator the caller passes
## in, so a seed reproduces a whole session (QA) and tests are deterministic. It never touches
## global state or the global RNG. Tuning values come from balance.json (`encounter`).

## Everything the resolver needs to know about the cast.
class Request:
	var habitat := ""
	var time_band := ""
	var weather_id := ""
	## Tags provided by the equipped bait; empty when no bait is used.
	var bait_tags: Array = []
	var ecosystem_level := 0
	## fish_id -> number of times the player lost that rare fish in a row (resets on success).
	var miss_counts: Dictionary = {}
	## fish_id -> temporary multiplier (events, debug). Missing means 1.0.
	var modifiers: Dictionary = {}

class Encounter:
	var fish_id := ""
	var size_cm := 0.0
	var rarity := 1
	var behavior := ""
	## The weight this fish had in the roll, and the chance it had (for debugging and tests).
	var weight := 0.0
	var probability := 0.0
	var pity_multiplier := 1.0
	var candidate_count := 0

var _tuning: Dictionary

func _init(tuning: Dictionary) -> void:
	_tuning = tuning

## Returns the encounter, or null when no fish can bite here (nothing lives in this habitat, or
## every candidate has zero weight).
func resolve(request: Request, candidates: Array, rng: RandomNumberGenerator) -> Encounter:
	var weights: Array[float] = []
	var pool: Array = []
	var total := 0.0
	for fish_def in candidates:
		if not request.habitat in fish_def["habitats"]:
			continue
		var weight := calculate_weight(fish_def, request)
		if weight <= 0.0 or not is_finite(weight):
			continue
		pool.append(fish_def)
		weights.append(weight)
		total += weight
	if pool.is_empty():
		return null

	# randf() is in [0, 1), so a zero-weight entry can never be selected.
	var roll := rng.randf() * total
	var picked := pool.size() - 1
	var cursor := 0.0
	for i in pool.size():
		cursor += weights[i]
		if roll < cursor:
			picked = i
			break

	var fish_def: Dictionary = pool[picked]
	var encounter := Encounter.new()
	encounter.fish_id = fish_def["id"]
	encounter.rarity = int(fish_def["rarity"])
	encounter.behavior = fish_def["behavior"]
	encounter.weight = weights[picked]
	encounter.probability = weights[picked] / total
	encounter.pity_multiplier = pity_multiplier(fish_def, request)
	encounter.candidate_count = pool.size()
	encounter.size_cm = roll_size(fish_def, rng)
	return encounter

func calculate_weight(fish_def: Dictionary, request: Request) -> float:
	var weight := float(fish_def["base_weight"])
	weight *= float(fish_def["time_bands"].get(request.time_band, 1.0))
	weight *= float(fish_def["weather"].get(request.weather_id, 1.0))
	weight *= bait_multiplier(fish_def, request.bait_tags)
	weight *= ecosystem_multiplier(fish_def, request.ecosystem_level)
	weight *= pity_multiplier(fish_def, request)
	weight *= float(request.modifiers.get(fish_def["id"], 1.0))
	return weight

func bait_multiplier(fish_def: Dictionary, bait_tags: Array) -> float:
	for tag in bait_tags:
		if tag in fish_def["bait_tags"]:
			return float(_tuning["bait_match_multiplier"])
	return 1.0

## Healthier water attracts rarer species: the bonus scales with rarity (none for tier 1, full
## for tier 5) and with the restoration level.
func ecosystem_multiplier(fish_def: Dictionary, ecosystem_level: int) -> float:
	var rarity_share := (float(fish_def["rarity"]) - 1.0) / 4.0
	return 1.0 + maxi(0, ecosystem_level) * float(_tuning["ecosystem_rarity_bonus_per_level"]) * rarity_share

## BALANCE §3: `1 + min(cap, misses * step)` for rare fish the player keeps losing.
func pity_multiplier(fish_def: Dictionary, request: Request) -> float:
	if int(fish_def["rarity"]) < int(_tuning["pity_min_rarity"]):
		return 1.0
	var misses: int = request.miss_counts.get(fish_def["id"], 0)
	return 1.0 + minf(float(_tuning["pity_cap"]), misses * float(_tuning["pity_step"]))

## Size within the species range, skewed toward the small end so big catches stay special.
func roll_size(fish_def: Dictionary, rng: RandomNumberGenerator) -> float:
	var range_cm: Dictionary = fish_def["size_cm"]
	var share := pow(rng.randf(), float(_tuning["size_skew"]))
	var size := snappedf(lerpf(float(range_cm["min"]), float(range_cm["max"]), share), 0.1)
	return clampf(size, float(range_cm["min"]), float(range_cm["max"]))
