shader_type canvas_item;

uniform vec4 deep_color : source_color = vec4(0.11, 0.34, 0.52, 1.0);
uniform vec4 mid_color : source_color = vec4(0.16, 0.48, 0.68, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.68, 0.76, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 0.92);
uniform float wave_speed : hint_range(0.1, 4.0) = 1.15;
uniform float wave_scale : hint_range(0.5, 20.0) = 6.0;
uniform float foam_intensity : hint_range(0.0, 1.5) = 0.65;

varying vec2 v_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	vec2 coord = UV * wave_scale + v_pos * 0.012;
	float t = TIME * wave_speed;

	float n1 = value_noise(coord * 1.4 + vec2(t * 0.35, -t * 0.22));
	float n2 = value_noise(coord * 2.8 - vec2(t * 0.28, t * 0.40));
	float wave_band = sin(coord.x * 2.6 + coord.y * 3.4 - t * 1.6 + n1 * 2.8);
	float secondary_band = cos(coord.x * 4.1 - coord.y * 2.7 + t * 1.2 + n2 * 2.2);

	float depth_mix = clamp(0.5 + 0.35 * n1 + 0.15 * n2, 0.0, 1.0);
	vec3 water_rgb = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.15, 0.72, depth_mix));
	water_rgb = mix(water_rgb, shallow_color.rgb, smoothstep(0.55, 0.95, n1 * 0.6 + n2 * 0.4));

	// Illustrated stylized wave crest bands matching land.jpeg / land2.jpeg
	float crest = smoothstep(0.62, 0.86, wave_band * 0.65 + secondary_band * 0.35);
	float shimmer = smoothstep(0.74, 0.92, n1 * 0.55 + n2 * 0.45);
	water_rgb = mix(water_rgb, shallow_color.rgb * 1.15, shimmer * 0.42);

	// Rhythmic white shoreline/wave foam contours
	float edge_dist = length(UV - vec2(0.5)) * 2.0;
	float shore_ring = smoothstep(0.68, 0.94, edge_dist + 0.08 * sin(t * 1.8 + n1 * 5.0));
	float foam_mask = clamp((crest * 0.78 + shore_ring * 0.55 * step(0.01, UV.x + UV.y)) * foam_intensity, 0.0, 1.0);
	vec3 final_rgb = mix(water_rgb, foam_color.rgb, foam_mask * foam_color.a);

	COLOR = vec4(final_rgb, 1.0);
}
