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
]
const ANIMALS: PackedStringArray = ["dragonfly", "butterfly", "firefly", "bird"]
