// The glow of a planet's atmosphere (game/system/celestial_body.gd): a shell a little bigger than the planet, brightest
// at its rim, where the eye looks through the most air, and dark on the planet's night side. Additive, so it only
// ever lightens what is behind it. Placeholder look until the art style is chosen.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.35, 0.6, 1.0);
uniform float strength = 1.4;
// Higher keeps the glow nearer the rim.
uniform float sharpness = 3.0;
// Towards the sun, world space (set by SolarSystem from its sun light).
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = 1.0 - facing;
	// Fades in from the rim's very edge so the shell's outline never shows as a hard line.
	float glow = pow(rim, sharpness) * smoothstep(0.0, 0.25, facing);
	vec3 sun_view = normalize((VIEW_MATRIX * vec4(sun_direction, 0.0)).xyz);
	float day = smoothstep(-0.25, 0.35, dot(NORMAL, sun_view));
	ALBEDO = colour * glow * day * strength;
}
