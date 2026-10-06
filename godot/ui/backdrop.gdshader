shader_type canvas_item;

// Backdrop behind full-screen panels (catch result, journal...): the scene softened and tinted, like
// the blurred pond in the mockups. A lower mip level of the screen gives a cheap blur; renderers
// without screen mipmaps simply show the tint over a sharp scene.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.5;
uniform vec4 tint : source_color = vec4(0.12, 0.1, 0.06, 0.28);

void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(scene, tint.rgb, tint.a), 1.0);
}
