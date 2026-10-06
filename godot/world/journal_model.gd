class_name JournalModel
extends RefCounted

## What the journal shows for each species (GDD §10, UI_UX §5). Information is revealed by how
## many times the player has met the fish, so ignorance is never punished: an unmet species is a
## silhouette with a gentle hint, not a "???".
##
##   encounters >= size       name and size
##   encounters >= time_bands the time of day it prefers
##   encounters >= habitats   where it lives
##   encounters >= behavior   how it behaves and its description
##
## The thresholds are balance.json `journal.reveal_at_encounters`. Pure data in, pure data out.

class Entry:
	var fish_id := ""
	var discovered := false
	var encounters := 0
	var releases := 0
	var largest_cm := 0.0
	var smallest_cm := 0.0
	var rarity := 1
	var show_name := false
	var show_size := false
	var show_time_bands := false
	var show_habitats := false
	var show_behavior := false
	## 0..4: how many of the four information tiers are open (0 = silhouette only).
	var tier := 0
	## The next encounter count that unlocks more, or 0 when everything is open.
	var next_unlock_at := 0

var _reveal: Dictionary

func _init(reveal_at_encounters: Dictionary) -> void:
	_reveal = reveal_at_encounters

func entry_for(fish_def: Dictionary, record: Dictionary) -> Entry:
	var entry := Entry.new()
	entry.fish_id = fish_def["id"]
	entry.rarity = int(fish_def["rarity"])
	entry.encounters = int(record["encounters"])
	entry.releases = int(record["releases"])
	entry.largest_cm = float(record["largest_cm"])
	entry.smallest_cm = float(record["smallest_cm"])
	entry.discovered = entry.encounters > 0
	entry.show_name = entry.encounters >= int(_reveal["size"])
	entry.show_size = entry.show_name
	entry.show_time_bands = entry.encounters >= int(_reveal["time_bands"])
	entry.show_habitats = entry.encounters >= int(_reveal["habitats"])
	entry.show_behavior = entry.encounters >= int(_reveal["behavior"])
	entry.tier = int(entry.show_name) + int(entry.show_time_bands) + int(entry.show_habitats) + int(entry.show_behavior)
	for field in ["size", "time_bands", "habitats", "behavior"]:
		var threshold := int(_reveal[field])
		if entry.encounters < threshold:
			entry.next_unlock_at = threshold
			break
	return entry

## Entries for every species living in the region, in catalog order.
func entries_for_region(region_id: String, game_state: Node) -> Array[Entry]:
	var entries: Array[Entry] = []
	for fish_def in ContentDB.get_fish_for_region(region_id):
		entries.append(entry_for(fish_def, game_state.get_collection_record(fish_def["id"])))
	return entries

## {"discovered": n, "total": n} for the region.
func completion(region_id: String, game_state: Node) -> Dictionary:
	var discovered := 0
	var species := ContentDB.get_fish_for_region(region_id)
	for fish_def in species:
		if game_state.has_discovered(fish_def["id"]):
			discovered += 1
	return {"discovered": discovered, "total": species.size()}
