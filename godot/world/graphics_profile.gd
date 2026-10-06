class_name GraphicsProfile
extends RefCounted

## Graphics quality tiers and Battery Saver (P1-014, P1-015, TECH_SPEC §13-14) as one resolved
## profile. balance.json `graphics` holds a tier per quality (rain drops, wildlife share, stars,
## water glints, waterfall frame rate) and what Battery Saver trims from it; the swimming-fish
## budget stays in `population` because PopulationModel owns it. SettingsApplier resolves the
## profile once per settings change and hands it to the presenters.

const QUALITIES: PackedStringArray = ["low", "medium", "high"]
const TIER_FIELDS: PackedStringArray = ["rain", "wildlife", "stars", "water_glints", "waterfall_fps"]
## Below this the rain stops reading as rain.
const MIN_RAIN := 20

## The profile for a quality ("low" / "medium" / "high"; anything else is medium) and Battery Saver.
static func resolve(graphics: Dictionary, quality: String, battery_saver: bool) -> Dictionary:
	var tiers: Dictionary = graphics["quality"]
	var tier: Dictionary = tiers[quality] if tiers.has(quality) else tiers["medium"]
	var profile := {
		"rain": int(tier["rain"]),
		"wildlife": float(tier["wildlife"]),
		"stars": int(tier["stars"]),
		"water_glints": tier["water_glints"] == true,
		"waterfall_fps": int(tier["waterfall_fps"]),
	}
	if battery_saver:
		var saver: Dictionary = graphics["battery_saver"]
		profile["rain"] = maxi(MIN_RAIN, roundi(profile["rain"] * float(saver["rain_factor"])))
		profile["wildlife"] = profile["wildlife"] * float(saver["wildlife_factor"])
		profile["water_glints"] = profile["water_glints"] and saver["water_glints"] == true
		profile["waterfall_fps"] = mini(profile["waterfall_fps"], int(saver["waterfall_fps"]))
	return profile

## The profile from the shipped balance data.
static func for_settings(quality: String, battery_saver: bool) -> Dictionary:
	return resolve(ContentDB.balance["graphics"], quality, battery_saver)

## How many of `count` animals stay out at a wildlife share: at least one when any were placed,
## so a tier never hides a restoration reward entirely.
static func scaled_count(count: int, wildlife: float) -> int:
	return 0 if count <= 0 else maxi(1, roundi(count * wildlife))
