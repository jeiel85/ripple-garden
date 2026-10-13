class_name PropKinds
extends RefCounted

## The vocabulary of things a region layout (data/region_layouts.json) may place. The painters in
## world/ know how to draw exactly these; ContentValidator rejects any other kind so a typo in
## the data can never silently draw nothing.

const PROPS: PackedStringArray = [
	"tree", "bush", "rock", "stump", "junk", "grass_tuft", "reed", "lily_pad", "flower",
	# The main-world mockup's scenery (D-018): the camp clearing and its furniture, the dock, stones.
	"camp_ground", "tent", "camp_chair", "crate", "lantern", "signboard", "birdhouse",
	"stepping_stone", "dock", "cat", "frog",
	# Camp decorations (P1-002) that only the camp places.
	"wood_table", "flower_pot", "campfire", "bench",
	# The last restoration stage's payoff (P1-001).
	"rainbow",
	# Scenery that belongs to one region (2026-10-13): valley, river, coast, isle.
	"mushroom", "fern", "cattail", "water_iris", "seashell", "starfish", "coral", "hibiscus",
	# Camp decorations of each region (2026-10-13).
	"log_seat", "stone_lantern", "rowboat", "net_rack", "parasol", "deck_chair", "hammock", "tiki_torch",
]
## Kinds that exist only as drawn art (godot/art/props): without the picture the painter draws a small
## mound in this colour, enough to see where the thing stands.
const ART_ONLY_COLORS := {
	"mushroom": Color("#a0704a"), "fern": Color("#4f8a3c"), "cattail": Color("#7a5a36"), "water_iris": Color("#e8c64a"),
	"seashell": Color("#f0d9c0"), "starfish": Color("#e8834a"), "coral": Color("#e47a8a"), "hibiscus": Color("#d8443c"),
	"log_seat": Color("#8a6040"), "stone_lantern": Color("#8c8a80"), "rowboat": Color("#9a6a42"), "net_rack": Color("#b89a6a"),
	"parasol": Color("#5a8fd0"), "deck_chair": Color("#c89a5a"), "hammock": Color("#d8c08a"), "tiki_torch": Color("#a07a48"),
}
## What a region's scene painting (D-029, assets/design/ASSET_REQUESTS.md §1 "남길 것") already shows:
## over a painting, layout props of these kinds that exist at every level are not drawn again.
const SCENE_PAINTED: PackedStringArray = ["tree", "rock", "camp_ground", "stepping_stone", "dock"]
const ANIMALS: PackedStringArray = ["dragonfly", "butterfly", "firefly", "bird"]
