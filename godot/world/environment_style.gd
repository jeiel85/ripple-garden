class_name EnvironmentStyle
extends RefCounted

## Time-of-day look: sky colors, the light that tints everything but the sky, star visibility and
## the sun/moon arc, sampled continuously from the game hour (0..24) instead of switching at
## band boundaries. Keyframes are visual style (placeholder art direction), not content.
##
## The sky is drawn pre-divided by the light, so the CanvasModulate that dims the rest of the
## world brings it back to the intended color (see RegionEnvironment).

## [hour, sky_top, sky_bottom, light, star_alpha]
const KEYS: Array = [
	[0.0, "#050b24", "#162547", "#8091c8", 1.0],
	[5.0, "#050b24", "#162547", "#8091c8", 1.0],
	[6.5, "#465a96", "#f0a58a", "#ffcdb8", 0.35],
	[8.0, "#86b0de", "#ffd7b0", "#fff0e0", 0.0],
	[9.5, "#5da7e6", "#bfe3f7", "#ffffff", 0.0],
	[16.5, "#5da7e6", "#bfe3f7", "#ffffff", 0.0],
	[18.0, "#5b78b8", "#ffb27a", "#ffd2a8", 0.0],
	[19.5, "#2c3a70", "#c26f7f", "#b8a0c0", 0.4],
	[21.0, "#050b24", "#162547", "#8091c8", 1.0],
	[24.0, "#050b24", "#162547", "#8091c8", 1.0],
]

const SUN_FROM_HOUR := 6.0
const SUN_TO_HOUR := 19.0

## {"top": Color, "bottom": Color, "light": Color, "stars": float} for a game hour.
static func sample(hours: float) -> Dictionary:
	var hour := fposmod(hours, 24.0)
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= float(a[0]) and hour <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			var t: float = 0.0 if span <= 0.0 else (hour - float(a[0])) / span
			return {
				"top": Color(a[1]).lerp(Color(b[1]), t),
				"bottom": Color(a[2]).lerp(Color(b[2]), t),
				"light": Color(a[3]).lerp(Color(b[3]), t),
				"stars": lerpf(float(a[4]), float(b[4]), t),
			}
	var last: Array = KEYS.back()
	return {"top": Color(last[1]), "bottom": Color(last[2]), "light": Color(last[3]), "stars": float(last[4])}

## 0..1 along the sun's path when it is up, or -1 when it is below the horizon.
static func sun_progress(hours: float) -> float:
	var hour := fposmod(hours, 24.0)
	if hour < SUN_FROM_HOUR or hour > SUN_TO_HOUR:
		return -1.0
	return (hour - SUN_FROM_HOUR) / (SUN_TO_HOUR - SUN_FROM_HOUR)

## 0..1 along the moon's path while it is up (evening to morning), or -1 by day.
static func moon_progress(hours: float) -> float:
	var hour := fposmod(hours, 24.0)
	if hour >= SUN_TO_HOUR:
		return (hour - SUN_TO_HOUR) / (24.0 - SUN_TO_HOUR + SUN_FROM_HOUR)
	if hour <= SUN_FROM_HOUR:
		return (hour + 24.0 - SUN_TO_HOUR) / (24.0 - SUN_TO_HOUR + SUN_FROM_HOUR)
	return -1.0

## Divides a color by the light so that light * result == color (clamped to displayable range).
static func compensate(color: Color, light: Color) -> Color:
	return Color(
		minf(color.r / maxf(light.r, 0.05), 1.0),
		minf(color.g / maxf(light.g, 0.05), 1.0),
		minf(color.b / maxf(light.b, 0.05), 1.0), color.a)
