shader_type canvas_item;

uniform float sway_strength = 0.0;
uniform float glow_strength = 0.0;
uniform float time_offset = 0.0;

void vertex() {
	VERTEX.x += sin(TIME * 2.2 + time_offset + UV.x * 3.0) * sway_strength * (1.0 - UV.y) * (1.0 - UV.y);
}

void fragment() {
	vec4 tex_col = texture(TEXTURE, UV) * COLOR;
	vec3 rgb = tex_col.rgb;
	if (glow_strength > 0.0) {
		float flicker = 0.78 + 0.22 * sin(TIME * 7.5 + time_offset * 2.3) * cos(TIME * 4.3 + UV.y * 5.0);
		float warm_mask = smoothstep(0.45, 0.85, rgb.r) * smoothstep(0.25, 0.75, rgb.g);
		vec3 warm_boost = vec3(1.0, 0.72, 0.28) * glow_strength * flicker * (0.35 + 0.65 * warm_mask);
		rgb = clamp(rgb + warm_boost, vec3(0.0), vec3(1.0));
	}
	COLOR = vec4(rgb, tex_col.a);
}
