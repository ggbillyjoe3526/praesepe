// Space dust: specks that fill a box around the camera and repeat forever, so speed and drift are readable in empty
// space (game/world/space_dust.gd). Each speck is a small quad stretched along the ship's motion, fading out towards
// the box's edge so the wrap is never seen. Presentation only.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The repeating box's size (m).
uniform float box_size = 400.0;
// The floating origin's offset wrapped into the box (FloatingOrigin.wrapped_offset), so a shift never moves the dust.
uniform vec3 lattice_shift = vec3(0.0);
// The camera's motion over one streak (m, world space): velocity times the streak time.
uniform vec3 streak = vec3(0.0);
uniform float speck_size = 0.35;
uniform float fade_near = 4.0;
uniform vec4 tint : source_color = vec4(0.75, 0.82, 1.0, 1.0);
// 1 normally, fading to 0 at cruise speeds (SpaceDust.fade_in).
uniform float strength = 1.0;

varying float v_fade;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 home = MODEL_MATRIX[3].xyz;
	vec3 half_box = vec3(box_size * 0.5);
	vec3 rel = mod(home - cam - lattice_shift + half_box, vec3(box_size)) - half_box;
	vec3 centre = cam + rel;
	float dist = length(rel);
	v_fade = smoothstep(fade_near, fade_near * 3.0, dist) * (1.0 - smoothstep(box_size * 0.3, box_size * 0.5, dist));
	vec3 to_cam = normalize(cam - centre);
	vec3 along = streak;
	float len = length(along);
	if (len < speck_size) {
		along = INV_VIEW_MATRIX[1].xyz * speck_size;
		len = speck_size;
	}
	vec3 across = cross(along, to_cam);
	if (length(across) < 0.0001) {
		// Flying straight at a speck: any sideways direction will do.
		across = INV_VIEW_MATRIX[0].xyz;
	}
	vec3 side = normalize(across) * speck_size * 0.5;
	// The quad's y runs from -0.5 (the tail) to 0.5 (the head); x is its width.
	vec3 world_pos = centre + along * VERTEX.y + side * (VERTEX.x * 2.0);
	// Long streaks are fainter, so the dust's brightness stays even at speed.
	v_fade *= clamp(speck_size * 4.0 / len, 0.15, 1.0) * strength;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
	if (v_fade <= 0.0) {
		// Faded out entirely: collapse the quad so it costs no drawing.
		POSITION = vec4(0.0);
	}
}

void fragment() {
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = tint.rgb;
	ALPHA = v_fade * edge * tint.a;
}
