class_name EncounterResolver
extends RefCounted

func choose_fish(
    candidates: Array,
    habitat: String,
    time_band: String,
    weather_id: String,
    bait_tags: Array,
    rng: RandomNumberGenerator
) -> Dictionary:
    var weighted: Array = []
    var total := 0.0

    for fish_def in candidates:
        if not habitat in fish_def.get("habitats", []):
            continue
        var weight := float(fish_def.get("base_weight", 0.0))
        weight *= float(fish_def.get("time_bands", {}).get(time_band, 1.0))
        weight *= float(fish_def.get("weather", {}).get(weather_id, 1.0))
        var preferred_baits: Array = fish_def.get("bait_tags", [])
        var bait_match := false
        for tag in bait_tags:
            if tag in preferred_baits:
                bait_match = true
                break
        if bait_match:
            weight *= 1.35
        if weight <= 0.0:
            continue
        weighted.append({"fish": fish_def, "weight": weight})
        total += weight

    if total <= 0.0:
        return {}

    var roll := rng.randf_range(0.0, total)
    var cursor := 0.0
    for item in weighted:
        cursor += item["weight"]
        if roll <= cursor:
            return item["fish"]
    return weighted.back()["fish"]
