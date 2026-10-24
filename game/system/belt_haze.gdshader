// The haze along an asteroid belt (game/system/asteroid_belt.gd): a faint band of dust on a flat ring, so the belt
// reads from afar where its rocks are too small to see. It thins out towards the band's edges and close to the camera,
// so flying in the belt shows rocks, not a fog sheet. Placeholder look until the art style is chosen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.55, 0.5, 0.44);
uniform float opacity : hint_range(0.0, 1.0) = 0.22;
// Within this distance (m) of the camera the haze is gone; past fade_full it is at full strength.
uniform float fade_near = 4000.0;
uniform float fade_full = 20000.0;

void fragment() {
	// UV.x runs across the band, 0 at its inner edge to 1 at its outer edge.
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float profile = smoothstep(0.0, 0.6, across);
	float dist = length(VERTEX);
	float near_fade = smoothstep(fade_near, fade_full, dist);
	ALBEDO = colour;
	ALPHA = opacity * profile * near_fade;
}
