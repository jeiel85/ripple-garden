shader_type canvas_item;

// The pond surface. Polygon2D sits at the origin, so VERTEX is world space.
// Murky water (low restoration) barely shimmers; clear water sparkles.

uniform vec4 deep_color : source_color = vec4(0.09, 0.4, 0.51, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.27, 0.7, 0.65, 1.0);
uniform float pond_top = 520.0;
uniform float pond_bottom = 980.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.6;
uniform float motion : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	float depth = clamp((world_pos.y - pond_top) / (pond_bottom - pond_top), 0.0, 1.0);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.0, 1.0, depth));

	float t = TIME * motion;
	float wave = sin(world_pos.x * 0.11 + t * 0.9 + sin(world_pos.y * 0.07 + t * 0.5) * 2.0) * 0.5 + 0.5;
	float glint = smoothstep(0.92, 1.0, wave) * 0.10 * shimmer;
	float soft = (sin(world_pos.y * 0.16 - t * 0.7 + world_pos.x * 0.05) * 0.5 + 0.5) * 0.025 * shimmer;
	COLOR = vec4(base + vec3(glint + soft), 1.0);
}
