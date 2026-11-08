shader_type canvas_item;

// biome_id: 0=tropical_forest, 1=savanna, 2=arid_steppe, 3=tundra, 4=high_mountain, 5=coastal_shallows
uniform int biome_id = 0;
// land_use_id: 0=wild, 1=crops, 2=pasture
uniform int land_use_id = 0;
uniform float k_ratio : hint_range(0.0, 1.5) = 1.0;
uniform vec4 base_tint : source_color = vec4(1.0);

varying vec2 v_pos;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float voronoi_cracks(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg, mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return md;
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	vec4 tex_col = texture(TEXTURE, UV) * COLOR * base_tint;
	vec2 p = UV * 6.0 + v_pos * 0.025;
	vec3 col = tex_col.rgb;

	// Inner hex bevel lighting and dark sepia rim accent (#23150c)
	vec2 centered_uv = UV - vec2(0.5);
	float radial = length(centered_uv) * 2.0;
	float top_left_light = clamp((-centered_uv.x * 0.65 - centered_uv.y * 0.85) + 0.5, 0.0, 1.0);
	col *= mix(0.92, 1.08, top_left_light);

	if (land_use_id == 1) {
		// Crops: golden plowed furrow rows with warm harvest sheen
		float angle_coord = (p.x * 0.85 + p.y * 0.52) * 5.2;
		float furrow = 0.5 + 0.5 * sin(angle_coord * 6.28318);
		float sheen = 0.5 + 0.5 * sin(TIME * 1.6 + p.x * 1.8);
		vec3 soil_dark = vec3(0.48, 0.33, 0.16);
		vec3 wheat_gold = mix(vec3(0.84, 0.66, 0.22), vec3(0.95, 0.80, 0.32), sheen * 0.45);
		vec3 crop_pattern = mix(soil_dark, wheat_gold, smoothstep(0.22, 0.72, furrow));
		col = mix(col, crop_pattern, 0.38);
	} else if (land_use_id == 2) {
		// Pasture: lush fenced meadow grass pattern
		float meadow_wave = sin(p.x * 3.4) * cos(p.y * 3.4);
		float ring = smoothstep(0.62, 0.68, radial) * (1.0 - smoothstep(0.68, 0.74, radial));
		vec3 lush_green = mix(vec3(0.36, 0.66, 0.24), vec3(0.52, 0.78, 0.30), 0.5 + 0.5 * meadow_wave);
		col = mix(col, lush_green, 0.32);
		col = mix(col, vec3(0.45, 0.28, 0.14), ring * 0.35);
	} else {
		// Wild biome surface details
		if (biome_id == 2) {
			// Arid steppe: Voronoi mud cracks matching land.jpeg / land2.jpeg
			float edge = voronoi_cracks(p * 1.15);
			float crack = 1.0 - smoothstep(0.02, 0.065, edge);
			col = mix(col, vec3(0.32, 0.18, 0.09), crack * 0.48);
		} else if (biome_id == 0 || biome_id == 1) {
			// Forest / Savanna: dappled canopy and grass tuft modulation
			float dapple = sin(p.x * 2.8 + sin(p.y * 2.2)) * cos(p.y * 2.6);
			col *= (1.0 + dapple * 0.06);
		} else if (biome_id == 3 || biome_id == 4) {
			// Tundra / Mountain: crisp frost facets and snow sparkle
			vec2 h = hash22(floor(p * 4.0));
			float sparkle = smoothstep(0.88, 0.98, h.x) * (0.6 + 0.4 * sin(TIME * 2.0 + h.y * 6.28));
			col = mix(col, vec3(0.95, 0.98, 1.0), sparkle * 0.28);
		} else if (biome_id == 5) {
			// Coastal shallows: gentle turquoise caustics
			float ripple = sin(p.x * 3.2 - TIME * 1.4) * cos(p.y * 3.0 + TIME * 1.1);
			col = mix(col, vec3(0.82, 0.96, 0.98), smoothstep(0.45, 0.85, ripple) * 0.22);
		}
	}

	// Ecological health (k_ratio) saturation / dryness modulation
	float k_clamped = clamp(k_ratio, 0.0, 1.0);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 parched = mix(vec3(luma), vec3(0.58, 0.46, 0.32), 0.35);
	col = mix(parched, col, 0.45 + 0.55 * k_clamped);

	// Subtle inner bevel highlight and dark ink rim
	float inner_bevel = smoothstep(0.76, 0.88, radial) * (1.0 - smoothstep(0.88, 0.96, radial));
	col += vec3(0.06, 0.05, 0.03) * inner_bevel * top_left_light;

	COLOR = vec4(col, tex_col.a);
}
