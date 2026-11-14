shader_type canvas_item;

uniform float macro_strength : hint_range(0.0, 2.0) = 1.15;
uniform float meso_strength : hint_range(0.0, 0.5) = 0.15;
uniform float micro_relief_strength : hint_range(0.0, 0.4) = 0.085;
uniform float shallow_wave_speed : hint_range(0.1, 3.0) = 0.95;

varying vec2 v_world_pos;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float micro_height(vec2 wp, vec2 wp_rot) {
	return value_noise(wp * 0.034 + vec2(7.3, 19.1)) * 0.55
		+ value_noise(wp_rot * 0.053 - vec2(31.7, 13.9)) * 0.45;
}

void vertex() {
	v_world_pos = VERTEX;
}

void fragment() {
	vec4 tex_col = texture(TEXTURE, UV);
	vec4 base = tex_col * COLOR;

	if (UV.x + UV.y < 0.02) {
		float cliff_lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
		float cliff_chroma = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
		float rock_grain_mask = step(0.95, base.a) * smoothstep(0.14, 0.22, cliff_lum) * (1.0 - smoothstep(0.30, 0.44, cliff_chroma));
		float grain = (value_noise(v_world_pos * 0.045) - 0.5) * 0.07;
		COLOR = vec4(clamp(base.rgb * (1.0 + grain * rock_grain_mask), 0.0, 1.0), base.a);
	} else {
		vec2 wp = v_world_pos;
		vec2 wp_rot = vec2(wp.x * 0.8 - wp.y * 0.6, wp.x * 0.6 + wp.y * 0.8);

		float n_macro = value_noise(wp * 0.0016) * 0.65 + value_noise(wp_rot * 0.0038 + vec2(19.4, 7.2)) * 0.35;
		float n_meso = value_noise(wp * 0.012 + vec2(43.1, -21.7)) * 0.60 + value_noise(wp_rot * 0.027 - vec2(11.3, 53.9)) * 0.40;

		float h_nw = micro_height(wp, wp_rot);
		vec2 wp_se = wp + vec2(6.0, 6.0);
		vec2 wp_se_rot = vec2(wp_se.x * 0.8 - wp_se.y * 0.6, wp_se.x * 0.6 + wp_se.y * 0.8);
		float h_se = micro_height(wp_se, wp_se_rot);
		float micro_slope = h_nw - h_se;

		float macro_t = clamp(0.5 + (n_macro - 0.5) * macro_strength, 0.0, 1.0);
		vec3 sun_cloud = mix(vec3(0.90, 0.94, 1.01), vec3(1.09, 1.06, 0.98), macro_t);
		float meso_mod = 1.0 + (n_meso - 0.5) * meso_strength;
		vec3 lit_rgb = base.rgb * sun_cloud * meso_mod + micro_slope * micro_relief_strength * vec3(1.04, 1.01, 0.94);

		float cyan_excess = min(tex_col.g, tex_col.b) - tex_col.r;
		float shallow_mask = smoothstep(0.18, 0.34, cyan_excess);
		float t = TIME * shallow_wave_speed;
		float wave_a = sin(wp.x * 0.045 + wp.y * 0.062 - t * 1.7 + n_meso * 3.2);
		float wave_b = cos(wp.x * 0.068 - wp.y * 0.041 + t * 1.3 + n_macro * 2.6);
		float ripple = 0.5 + 0.5 * (wave_a * 0.6 + wave_b * 0.4);
		float spec_glint = smoothstep(0.76, 0.95, ripple) * (0.55 + 0.45 * h_nw);
		vec3 shallow_rgb = lit_rgb * vec3(0.93, 1.03, 1.06) + vec3(0.18, 0.23, 0.25) * spec_glint;
		lit_rgb = mix(lit_rgb, shallow_rgb, shallow_mask * 0.78);

		float tex_max = max(tex_col.r, max(tex_col.g, tex_col.b));
		float tex_min = min(tex_col.r, min(tex_col.g, tex_col.b));
		float tex_chroma = tex_max - tex_min;
		float tex_lum = dot(tex_col.rgb, vec3(0.299, 0.587, 0.114));
		float mountain_mask = (1.0 - smoothstep(0.08, 0.19, tex_chroma)) * smoothstep(0.28, 0.40, tex_lum) * (1.0 - smoothstep(0.63, 0.75, tex_lum));
		float tundra_mask = (1.0 - smoothstep(0.14, 0.24, tex_chroma)) * smoothstep(0.70, 0.84, tex_lum);

		float crest_field = n_macro * 0.45 + n_meso * 0.40 + clamp(0.5 + micro_slope * 1.4, 0.0, 1.0) * 0.15;
		float snow_cap = smoothstep(0.55, 0.76, crest_field);
		float rock_hollow = 1.0 - smoothstep(0.24, 0.44, crest_field);

		vec3 snow_tint = vec3(0.93, 0.96, 0.99) * mix(vec3(1.0), COLOR.rgb, 0.65);
		lit_rgb = mix(lit_rgb, lit_rgb * vec3(0.80, 0.82, 0.86), mountain_mask * rock_hollow * 0.48);
		lit_rgb = mix(lit_rgb, snow_tint, mountain_mask * snow_cap * 0.56);
		lit_rgb = mix(lit_rgb, lit_rgb * vec3(0.82, 0.85, 0.89), tundra_mask * rock_hollow * 0.28);

		COLOR = vec4(clamp(lit_rgb, 0.0, 1.0), base.a);
	}
}
