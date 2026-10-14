class_name AmbientMix
extends RefCounted

## The rules of the ambient soundscape (TECH_SPEC §12): continuous layers whose loudness follows
## weather and time of day, plus randomised wildlife one-shots whose choice and frequency follow the
## time band and how far the pond has recovered. Pure functions over data/audio.json, so they are
## deterministic given a seeded RandomNumberGenerator and testable without any audio device.

## The mix as it sounds in one region (CONTENT_PLAN §3 "distinct soundscape"): a copy of `config` with the
## region's entry under `regions` applied — its own loop recordings (`streams`: loop id -> file) and mix
## values (`mix`: loop id -> {key: value}) — and only the wildlife that lives there (a clip with a `regions`
## list sounds only in those regions; one without sounds everywhere).
static func for_region(config: Dictionary, region_id: String) -> Dictionary:
	var result := config.duplicate(true)
	if result.is_empty():
		return result
	var own: Dictionary = config.get("regions", {}).get(region_id, {})
	var streams: Dictionary = own.get("streams", {})
	for loop in result["loops"]:
		if streams.has(loop["id"]):
			loop["stream"] = streams[loop["id"]]
	var mix_changes: Dictionary = own.get("mix", {})
	for loop_id in mix_changes:
		result["mix"][loop_id].merge(mix_changes[loop_id], true)
	result["wildlife"]["clips"] = result["wildlife"]["clips"].filter(func(clip: Dictionary) -> bool:
		return not clip.has("regions") or region_id in clip["regions"])
	result["bgm"] = own.get("bgm", "")  # the region's music ("" = none)
	return result

## Target loudness (0..1) of every loop: {loop id: volume}. `cloud` and `rain` are 0..1.
static func loop_targets(config: Dictionary, time_band: String, cloud: float, rain: float) -> Dictionary:
	var mix: Dictionary = config["mix"]
	var water: Dictionary = mix["water"]
	var wind: Dictionary = mix["wind"]
	var wind_volume := float(wind["base"]) + float(wind["cloud_boost"]) * clampf(cloud, 0.0, 1.0)
	if time_band == "night":
		wind_volume *= float(wind["night_factor"])
	return {
		"water": clampf(float(water["base"]) + float(water["rain_boost"]) * clampf(rain, 0.0, 1.0), 0.0, 1.0),
		"wind": clampf(wind_volume, 0.0, 1.0),
		"rain": clampf(float(mix["rain"]["gain"]) * clampf(rain, 0.0, 1.0), 0.0, 1.0),
	}

## Wildlife clips that may sound now: right time band and the pond recovered enough.
static func clip_candidates(config: Dictionary, time_band: String, level: int) -> Array:
	var candidates: Array = []
	for clip in config["wildlife"]["clips"]:
		if time_band in clip["bands"] and level >= int(clip["min_level"]):
			candidates.append(clip)
	return candidates

## A weighted random clip for the moment, or {} when nothing fits (a barren night is silent).
static func pick_clip(config: Dictionary, time_band: String, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var candidates := clip_candidates(config, time_band, level)
	var total := 0.0
	for clip in candidates:
		total += float(clip["weight"])
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	var cursor := 0.0
	for clip in candidates:
		cursor += float(clip["weight"])
		if roll < cursor:
			return clip
	return candidates.back()

## Seconds until the next wildlife sound: a livelier (more restored) pond is heard more often.
static func next_delay(config: Dictionary, level: int, rng: RandomNumberGenerator) -> float:
	var interval: Dictionary = config["wildlife"]["interval_sec"]
	var speedup := 1.0 + maxi(0, level) * float(config["wildlife"]["level_speedup"])
	return rng.randf_range(float(interval["min"]), float(interval["max"])) / speedup

static func clip_volume(config: Dictionary, rng: RandomNumberGenerator) -> float:
	var volume: Dictionary = config["wildlife"]["volume"]
	return rng.randf_range(float(volume["min"]), float(volume["max"]))

static func to_db(linear: float) -> float:
	return -80.0 if linear <= 0.0005 else linear_to_db(linear)
