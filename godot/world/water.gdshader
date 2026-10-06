shader_type canvas_item;

// The pond surface. Polygon2D sits at the origin, so VERTEX is world space.
// Murky water (low restoration) barely shimmers; clear water sparkles.

uniform vec4 deep_color : source_color = vec4(0.09, 0.4, 0.51, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.27, 0.7, 0.65, 1.0);
uniform float pond_top = 520.0;
uniform float pond_bottom = 980.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.6;
uniform float motion : hint_range(0.0, 1.0) = 1.0;
// Low quality and Battery Saver skip the glint waves entirely (GraphicsProfile water_glints).
uniform bool glints = true;
// Over a painted scene (D-029) the painting has the water's colour: only the light on it moves.
uniform bool overlay = false;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	float depth = clamp((world_pos.y - pond_top) / (pond_bottom - pond_top), 0.0, 1.0);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.0, 1.0, depth));

	float t = TIME * motion;
	float glint = 0.0;
	if (glints) {
		// Two crossing waves multiplied give scattered glints instead of continuous stripes.
		float wave_a = sin(world_pos.x * 0.09 + t * 0.8 + sin(world_pos.y * 0.05 + t * 0.4) * 2.0) * 0.5 + 0.5;
		float wave_b = sin(world_pos.y * 0.12 - t * 0.6 + sin(world_pos.x * 0.04 - t * 0.3) * 2.0) * 0.5 + 0.5;
		glint = smoothstep(0.78, 0.96, wave_a * wave_b) * 0.11 * shimmer;
	}
	float soft = (sin(world_pos.y * 0.16 - t * 0.7 + world_pos.x * 0.05) * 0.5 + 0.5) * 0.025 * shimmer;
	if (overlay) {
		COLOR = vec4(vec3(1.0), clamp((glint + soft) * 2.2, 0.0, 1.0));
	} else {
		COLOR = vec4(base + vec3(glint + soft), 1.0);
	}
}
