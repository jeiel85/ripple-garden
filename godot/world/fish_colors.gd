class_name FishColors
extends RefCounted

## Placeholder colouring for a species until its drawn art arrives (assets/design/ASSET_REQUESTS.md
## §3): a stable pick from a palette of natural fish tones (olive, silver-blue, gold, bronze, koi
## orange...) so the pond looks like the mockups' and never like a box of sweets. Rarer fish are a
## little richer. The swimming agents and the journal/catch portraits share it, so a fish looks the
## same everywhere.

const PALETTE: Array[Color] = [
	Color("#8a8455"), Color("#7f9db0"), Color("#c9a25a"), Color("#5d6b55"), Color("#d9783f"),
	Color("#a9654c"), Color("#9a7a4a"), Color("#6f8796"), Color("#7d9468"), Color("#5e6874"),
]

## {"body", "belly", "fin", "accent"} for a species.
static func for_species(fish_id: String, rarity: int) -> Dictionary:
	var base := PALETTE[absi(hash(fish_id)) % PALETTE.size()]
	var richness := clampf((rarity - 1) * 0.06, 0.0, 0.24)
	var body := Color.from_hsv(base.h, clampf(base.s + richness, 0.0, 1.0), clampf(base.v + richness * 0.3, 0.0, 1.0))
	return {
		"body": body,
		"belly": body.lerp(Color("#f6efdc"), 0.6),
		"fin": Color(body.darkened(0.15), 0.85),
		"accent": body.lightened(0.35),
	}
