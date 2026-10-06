class_name PropKinds
extends RefCounted

## The vocabulary of things a region layout (data/region_layouts.json) may place. The painters in
## world/ know how to draw exactly these; ContentValidator rejects any other kind so a typo in
## the data can never silently draw nothing.

const PROPS: PackedStringArray = [
	"tree", "bush", "rock", "stump", "junk", "grass_tuft", "reed", "lily_pad", "flower",
]
const ANIMALS: PackedStringArray = ["dragonfly", "butterfly", "firefly"]
