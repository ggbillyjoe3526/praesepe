// The sky: a dark field of stars with a faint band, and the sun's disc where the scene's sun light points. Stars come
// from a hash of the view direction, so they never move and need no random numbers. Placeholder look until the art
// style is chosen.
shader_type sky;

uniform vec3 deep_colour : source_color = vec3(0.004, 0.006, 0.014);
uniform vec3 band_colour : source_color = vec3(0.05, 0.045, 0.07);
uniform vec3 band_axis = vec3(0.3, 0.9, 0.25);
uniform float star_density = 0.018;
uniform vec3 sun_colour : source_color = vec3(1.0, 0.92, 0.78);
uniform float sun_size = 0.9995;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// One layer of stars: the view direction picks a cell on a 3D grid, and each cell may hold one star. `radius` is the
// star's size in radians: about 1.5 px at 1080p and a 75 degree view, so stars never shimmer below a pixel.
float stars(vec3 dir, float cells, float threshold, float radius) {
	vec3 p = dir * cells;
	vec3 cell = floor(p);
	float h = hash13(cell);
	if (h > threshold) {
		return 0.0;
	}
	float r = radius * cells;
	// Kept inside its cell, so no star is cut off at a cell's edge.
	vec3 star_at = cell + r + vec3(hash13(cell + 17.0), hash13(cell + 41.0), hash13(cell + 73.0)) * (1.0 - 2.0 * r);
	float d = length(p - star_at);
	float brightness = 0.35 + 0.65 * hash13(cell + 5.0);
	return brightness * smoothstep(r, 0.0, d);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float band = pow(1.0 - abs(dot(dir, normalize(band_axis))), 6.0);
	vec3 col = deep_colour + band_colour * band;
	col += vec3(stars(dir, 160.0, star_density, 0.0018)) * 0.9;
	col += vec3(stars(dir, 300.0, star_density * 0.7 + band * 0.08, 0.0012)) * 0.5;
	if (LIGHT0_ENABLED) {
		float sun = dot(dir, LIGHT0_DIRECTION);
		col += sun_colour * smoothstep(sun_size - 0.0004, sun_size, sun) * 6.0;
		col += sun_colour * pow(max(sun, 0.0), 300.0) * 0.25;
	}
	COLOR = col;
}
