// The surface of a planet or moon (game/system/celestial_body.gd): two colours split by a fractal noise over the
// sphere, such as sea and land, with caps of a third colour near the poles. The noise comes from the direction from
// the body's centre, so the pattern is fixed to the body and needs no textures or random numbers. Placeholder look
// until the art style is chosen.
shader_type spatial;

uniform vec3 low_colour : source_color = vec3(0.08, 0.2, 0.35);
uniform vec3 high_colour : source_color = vec3(0.3, 0.42, 0.22);
uniform vec3 pole_colour : source_color = vec3(0.85, 0.88, 0.92);
uniform float low_roughness : hint_range(0.0, 1.0) = 0.35;
uniform float high_roughness : hint_range(0.0, 1.0) = 0.9;
// Share of the surface (by noise value) that takes the low colour.
uniform float level : hint_range(0.0, 1.0) = 0.52;
// How sharp the edge between the two colours is.
uniform float edge = 0.02;
// How many features fit around the body: bigger is busier.
uniform float scale = 2.2;
// How far from the equator (0 to 1, the sine of the latitude) the pole caps start; above 1 means none.
uniform float pole_start = 0.82;

varying vec3 v_dir;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), u.x);
	float b = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), u.x);
	float c = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), u.x);
	float d = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), u.x);
	return mix(mix(a, b, u.y), mix(c, d, u.y), u.z);
}

// Five octaves, each half the size and half the strength of the last; about 0 to 1.
float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += value_noise(p) * amp;
		p = p * 2.03 + vec3(17.1, 9.3, 4.7);
		amp *= 0.5;
	}
	return sum / 0.96875;
}

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 dir = normalize(v_dir);
	float h = fbm(dir * scale + vec3(11.0));
	float high = smoothstep(level - edge, level + edge, h);
	vec3 col = mix(low_colour, high_colour, high);
	// A little light and shade within each colour, so it reads as ground rather than paint.
	col *= 0.85 + 0.3 * fbm(dir * scale * 6.0);
	float pole = smoothstep(pole_start, pole_start + 0.04, abs(dir.y) + (h - 0.5) * 0.15);
	ALBEDO = mix(col, pole_colour, pole);
	ROUGHNESS = mix(mix(low_roughness, high_roughness, high), 0.6, pole);
}
