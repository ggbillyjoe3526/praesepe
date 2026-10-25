shader_type spatial;
// The faint light along a port's way in (game/arrival/guide_light.gd): a soft beam, brightest down its middle and at
// the port's end, fading out toward its far end and close to the camera, so flying through it never dazzles. Seen
// along its length (lined up on it) it glows all round, so it never vanishes just when the pilot is on the line.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.4, 0.9, 1.0, 1.0);
// How bright it is (0 to 1).
uniform float strength = 0.3;
// How long (m) the beam is along its mesh's y axis, which points away from the port.
uniform float beam_length = 400.0;
// Within this distance (m) of the camera it fades out.
uniform float near_fade = 30.0;

varying float along;
varying vec3 axis;

void vertex() {
	along = clamp(VERTEX.y / beam_length + 0.5, 0.0, 1.0);
	axis = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	// Across the beam, how square-on this bit is to the eye: 1 down its middle, 0 at its edges.
	vec3 view_across = VIEW - axis * dot(VIEW, axis);
	vec3 normal_across = NORMAL - axis * dot(NORMAL, axis);
	float across = abs(dot(normalize(normal_across), normalize(view_across + vec3(1e-5))));
	// Looking along the beam there are no edges to fade: it glows all round.
	float core = mix(1.0, across * across, clamp(length(view_across), 0.0, 1.0));
	float fade = pow(1.0 - along, 1.5);
	float near = smoothstep(near_fade * 0.3, near_fade, length(VERTEX));
	ALBEDO = colour.rgb;
	ALPHA = strength * core * fade * near;
}
