class_name EvoTerrainSprites
extends EvoPixelCanvas


static func draw_terrain_sprite(sprite_name: String) -> Image:
	match sprite_name:
		"tree_tropical":
			return _draw_tree_tropical()
		"tree_tropical_2":
			return _draw_tree_tropical_2()
		"tree_savanna":
			return _draw_tree_savanna()
		"tree_savanna_2":
			return _draw_tree_savanna_2()
		"tree_tundra":
			return _draw_tree_tundra()
		"tree_tundra_2":
			return _draw_tree_tundra_2()
		"bush_arid", "cactus_arid", "cactus_saguaro":
			return _draw_bush_arid()
		"bush_berry":
			return _draw_bush_berry()
		"fallen_log":
			return _draw_fallen_log()
		"mossy_rock", "rock_boulder":
			return _draw_mossy_rock()
		"tall_grass":
			return _draw_tall_grass()
		"dry_scrub":
			return _draw_dry_scrub()
		"rock_mountain":
			return _draw_rock_mountain()
		"coastal_reeds":
			return _draw_coastal_reeds()
		"tree_stump":
			return _draw_tree_stump()
		"soil_crack":
			return _draw_soil_crack()
		_:
			return _draw_wildflowers()


static func _paint_biome_surface(
	img: Image,
	col_dark: Color,
	col_mid: Color,
	col_light: Color,
	stria_col: Color,
	stria_strength: float,
	freq: float,
	seed_val: int
) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		var fy := float(y)
		var v_grad := (fy / float(h - 1) - 0.5) * 0.08
		for x in range(w):
			var fx := float(x)
			var n_broad := _fbm2d(fx * freq, fy * freq * 1.18, seed_val)
			var n_fine := _value_noise2d(fx * 0.19, fy * 0.22, seed_val + 101)
			var speck := (float(_hash2d(x, y, seed_val + 307) & 31) / 31.0 - 0.5) * 0.035
			var tone := clampf(n_broad * 0.72 + n_fine * 0.28 + speck - v_grad, 0.0, 1.0)
			var base_c: Color
			if tone < 0.5:
				base_c = col_dark.lerp(col_mid, tone * 2.0)
			else:
				base_c = col_mid.lerp(col_light, (tone - 0.5) * 2.0)

			var diag_phase := (fx * 0.72 + fy * 1.08) * 0.075 + n_broad * 1.85
			var stria_mask := _value_noise2d(fx * 0.055, fy * 0.065, seed_val + 211)
			var stria := (0.5 + 0.5 * sin(diag_phase * TAU)) * stria_mask * stria_strength
			img.set_pixel(x, y, base_c.lerp(stria_col, stria))


static func draw_hex_tile(biome: String) -> Image:
	var w := 256
	var h := 224
	var img := _new_canvas(w, h)

	match biome:
		"tropical_forest":
			_paint_biome_surface(
				img,
				Color("#286b23"),
				Color("#398a30"),
				Color("#4fa840"),
				Color("#65bf4e"),
				0.15,
				0.032,
				17
			)
			for i in range(36):
				var fx := 18.0 + float(_hash2d(i, 1, 31) % 220)
				var fy := 16.0 + float(_hash2d(i, 2, 31) % 192)
				_aa_line(img, fx, fy, fx - 3.5, fy - 3.0, Color(0.11, 0.31, 0.10, 0.34), 1.5)
				_aa_line(img, fx + 1.0, fy - 0.5, fx + 4.0, fy - 3.5, Color(0.49, 0.86, 0.36, 0.30), 1.3)

		"savanna":
			_paint_biome_surface(
				img,
				Color("#749c28"),
				Color("#8fb838"),
				Color("#b0d14d"),
				Color("#d1c654"),
				0.18,
				0.030,
				41
			)
			for i in range(40):
				var gx := 18.0 + float(_hash2d(i, 3, 43) % 220)
				var gy := 16.0 + float(_hash2d(i, 4, 43) % 192)
				_aa_line(img, gx, gy, gx - 2.5, gy - 4.5, Color(0.32, 0.49, 0.10, 0.32), 1.4)
				_aa_line(img, gx + 1.5, gy, gx + 3.5, gy - 5.0, Color(0.78, 0.91, 0.38, 0.32), 1.3)

		"arid_steppe":
			_paint_biome_surface(
				img,
				Color("#c99448"),
				Color("#e0b264"),
				Color("#f2cf88"),
				Color("#b57934"),
				0.20,
				0.028,
				59
			)
			for i in range(22):
				var sx := 22.0 + float(_hash2d(i, 5, 67) % 212)
				var sy := 18.0 + float(_hash2d(i, 6, 67) % 188)
				var dx := 6.0 + float(_hash2d(i, 7, 67) % 7)
				var dy := 3.0 + float(_hash2d(i, 8, 67) % 5)
				_aa_line(img, sx - dx, sy - dy, sx + dx, sy + dy, Color(0.45, 0.27, 0.12, 0.26), 1.3)
				_aa_line(img, sx - dx, sy - dy + 1.2, sx + dx, sy + dy + 1.2, Color(0.98, 0.89, 0.66, 0.24), 1.0)

		"tundra":
			_paint_biome_surface(
				img,
				Color("#b8cfe0"),
				Color("#d5e6f2"),
				Color("#eff6fb"),
				Color("#9bb8cf"),
				0.18,
				0.028,
				79
			)
			for i in range(24):
				var ix := 20.0 + float(_hash2d(i, 7, 83) % 216)
				var iy := 18.0 + float(_hash2d(i, 8, 83) % 188)
				_aa_line(img, ix - 7.0, iy - 3.0, ix + 7.0, iy + 3.0, Color(1.0, 1.0, 1.0, 0.38), 1.5)
				_aa_line(img, ix - 5.0, iy - 1.5, ix + 5.0, iy + 4.5, Color(0.56, 0.73, 0.85, 0.25), 1.2)

		"high_mountain":
			_paint_biome_surface(
				img,
				Color("#5c5854"),
				Color("#78736e"),
				Color("#96908a"),
				Color("#a8b2bd"),
				0.22,
				0.034,
				97
			)
			for i in range(30):
				var rx := 20.0 + float(_hash2d(i, 9, 103) % 216)
				var ry := 18.0 + float(_hash2d(i, 10, 103) % 188)
				var span := 8.0 + float(_hash2d(i, 11, 103) % 9)
				_aa_line(img, rx - span, ry - span * 0.52, rx + span, ry + span * 0.52, Color(0.22, 0.20, 0.19, 0.34), 1.6)
				_aa_line(img, rx - span + 1.0, ry - span * 0.52 - 1.3, rx + span + 1.0, ry + span * 0.52 - 1.3, Color(0.78, 0.76, 0.73, 0.30), 1.2)

		"coastal_shallows":
			_paint_biome_surface(
				img,
				Color("#2b9993"),
				Color("#42bdb4"),
				Color("#6ce0d4"),
				Color("#d6ebd0"),
				0.18,
				0.026,
				113
			)
			for i in range(20):
				var wx := 22.0 + float(_hash2d(i, 11, 127) % 212)
				var wy := 20.0 + float(_hash2d(i, 12, 127) % 184)
				_aa_line(img, wx - 8.0, wy + 1.0, wx + 8.0, wy - 1.5, Color(0.92, 0.99, 1.0, 0.34), 1.5)

		_:
			_paint_biome_surface(
				img,
				Color("#154569"),
				Color("#1f5d8a"),
				Color("#2c77ab"),
				Color("#529ecc"),
				0.16,
				0.025,
				139
			)
			for i in range(22):
				var wx := 22.0 + float(_hash2d(i, 13, 149) % 212)
				var wy := 20.0 + float(_hash2d(i, 14, 149) % 184)
				_aa_line(img, wx - 9.0, wy + 1.0, wx, wy - 1.5, Color(0.62, 0.86, 0.98, 0.28), 1.6)
				_aa_line(img, wx, wy - 1.5, wx + 9.0, wy + 1.0, Color(0.62, 0.86, 0.98, 0.28), 1.6)

	return img


static func _draw_tree_tropical() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 111.0, 36.0, 12.5, 0.38)

	# Flared buttress trunk with 135 deg sunlit left bark & shaded right bark
	var trunk_l := PackedVector2Array([
		Vector2(55, 52), Vector2(64, 52), Vector2(65, 104),
		Vector2(58, 112), Vector2(40, 112), Vector2(52, 95)
	])
	var trunk_r := PackedVector2Array([
		Vector2(64, 52), Vector2(73, 52), Vector2(76, 95),
		Vector2(88, 112), Vector2(68, 112), Vector2(64, 104)
	])
	_poly_outlined(img, trunk_l, Color("#a4683e"), Color("#784726"), C_OUTLINE, 2.2)
	_poly_outlined(img, trunk_r, Color("#6e3f20"), Color("#472612"), C_OUTLINE, 2.2)
	_aa_line(img, 58.0, 58.0, 55.0, 98.0, Color("#bd8052"), 2.0)

	# Spreading upper limbs & hanging jungle liana vines
	_aa_line(img, 58.0, 62.0, 38.0, 44.0, C_OUTLINE, 5.5)
	_aa_line(img, 58.0, 62.0, 38.0, 44.0, Color("#8f5630"), 3.0)
	_aa_line(img, 70.0, 62.0, 90.0, 46.0, C_OUTLINE, 5.5)
	_aa_line(img, 70.0, 62.0, 90.0, 46.0, Color("#593218"), 3.0)
	_aa_line(img, 42.0, 56.0, 44.0, 82.0, Color("#296e2c"), 2.0)
	_aa_line(img, 84.0, 58.0, 82.0, 80.0, Color("#1f5422"), 2.0)

	# Clustered 3-tone foliage crown lit from top-left (135 deg)
	_draw_foliage_clump(img, 88.0, 54.0, 21.0, Color("#184f24"), Color("#297836"), Color("#48a64c"))
	_draw_foliage_clump(img, 40.0, 52.0, 22.0, Color("#1d5c2a"), Color("#328c3f"), Color("#5ec458"))
	_draw_foliage_clump(img, 68.0, 56.0, 22.0, Color("#1b5728"), Color("#2f853b"), Color("#52b550"))
	_draw_foliage_clump(img, 76.0, 38.0, 21.0, Color("#1e5e2b"), Color("#359442"), Color("#63cc5c"))
	_draw_foliage_clump(img, 52.0, 34.0, 24.0, Color("#22692f"), Color("#3da349"), Color("#78de68"))

	# Basal fern tuft at roots
	_draw_foliage_clump(img, 50.0, 108.0, 8.5, Color("#1b5728"), Color("#328c3f"), Color("#63cc5c"))
	return img


static func _draw_palm_stem(img: Image, base: Vector2, top: Vector2, bend_x: float, w_base: float, w_top: float) -> void:
	var segs := 9
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(base.y, top.y, t0)
		var y1 := lerpf(base.y, top.y, t1)
		var x0 := lerpf(base.x, top.x, t0) + sin(t0 * PI) * bend_x
		var x1 := lerpf(base.x, top.x, t1) + sin(t1 * PI) * bend_x
		var hw0 := lerpf(w_base, w_top, t0)
		var hw1 := lerpf(w_base, w_top, t1)
		var quad_l := PackedVector2Array([
			Vector2(x0 - hw0, y0), Vector2(x1 - hw1, y1),
			Vector2(x1, y1), Vector2(x0, y0)
		])
		var quad_r := PackedVector2Array([
			Vector2(x0, y0), Vector2(x1, y1),
			Vector2(x1 + hw1, y1), Vector2(x0 + hw0, y0)
		])
		_poly_filled(img, quad_l, Color("#b57848"), Color("#915b33"))
		_poly_filled(img, quad_r, Color("#784825"), Color("#573218"))
		_aa_line(img, x0 - hw0, y0, x1 - hw1, y1, C_OUTLINE, 2.0)
		_aa_line(img, x0 + hw0, y0, x1 + hw1, y1, C_OUTLINE, 2.0)
		_aa_line(img, x1 - hw1, y1, x1 + hw1, y1, C_OUTLINE, 1.4)


static func _draw_palm_crown(img: Image, center: Vector2, scale_f: float) -> void:
	_aa_circle_outlined(img, center.x - 4.5 * scale_f, center.y + 3.5 * scale_f, 4.8 * scale_f, Color("#6e4020"), C_OUTLINE, 1.8)
	_aa_circle_outlined(img, center.x + 4.5 * scale_f, center.y + 4.0 * scale_f, 4.8 * scale_f, Color("#4f2c14"), C_OUTLINE, 1.8)

	var fronds := [
		[Vector2(-44, 14), Vector2(-24, -13), true],
		[Vector2(-36, -14), Vector2(-16, -24), true],
		[Vector2(-4, -28), Vector2(-4, -16), true],
		[Vector2(36, -12), Vector2(18, -22), false],
		[Vector2(44, 14), Vector2(24, -11), false],
		[Vector2(-26, 26), Vector2(-14, 5), true],
		[Vector2(28, 26), Vector2(14, 5), false]
	]
	for f in fronds:
		var tip: Vector2 = center + (f[0] as Vector2) * scale_f
		var ctrl: Vector2 = center + (f[1] as Vector2) * scale_f
		var sunlit: bool = bool(f[2])
		var c_top := Color("#7be064") if sunlit else Color("#4cb04c")
		var c_bot := Color("#338f3c") if sunlit else Color("#20662c")
		var leaf := PackedVector2Array([
			center,
			ctrl + Vector2(0, -6.5 * scale_f),
			tip,
			ctrl + Vector2(0, 4.5 * scale_f)
		])
		_poly_outlined(img, leaf, c_top, c_bot, C_OUTLINE, 2.0)
		_aa_line(img, center.x, center.y, tip.x, tip.y, Color("#1b5424"), 1.5)


static func _draw_tree_tropical_2() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 111.0, 34.0, 11.5, 0.36)

	# Companion smaller palm on right + tall primary palm on left
	_draw_palm_stem(img, Vector2(72, 111), Vector2(88, 62), 5.0, 5.2, 3.0)
	_draw_palm_crown(img, Vector2(88, 62), 0.72)

	_draw_palm_stem(img, Vector2(58, 112), Vector2(50, 40), -7.0, 7.2, 4.0)
	_draw_palm_crown(img, Vector2(50, 40), 0.96)

	_draw_foliage_clump(img, 64.0, 108.0, 10.0, Color("#1d5c2a"), Color("#359442"), Color("#6ad462"))
	return img


static func _draw_tree_savanna() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 111.0, 40.0, 12.5, 0.35)

	# Sculpted forked acacia trunk & spreading boughs
	var trunk := PackedVector2Array([
		Vector2(57, 68), Vector2(69, 68), Vector2(73, 111), Vector2(53, 111)
	])
	_poly_outlined(img, trunk, Color("#9c6239"), Color("#5c351b"), C_OUTLINE, 2.3)
	_aa_line(img, 60.0, 70.0, 58.0, 108.0, Color("#b87b4e"), 2.2)

	var branches := [
		[Vector2(61, 74), Vector2(32, 48), Color("#945b33")],
		[Vector2(65, 73), Vector2(96, 52), Color("#63391d")],
		[Vector2(63, 70), Vector2(58, 38), Color("#8c542e")],
		[Vector2(64, 70), Vector2(78, 40), Color("#6e4020")]
	]
	for br in branches:
		var p0: Vector2 = br[0]
		var p1: Vector2 = br[1]
		var bc: Color = br[2]
		_aa_line(img, p0.x, p0.y, p1.x, p1.y, C_OUTLINE, 6.4)
		_aa_line(img, p0.x, p0.y, p1.x, p1.y, bc, 3.4)

	# Tiered flat-topped umbrella canopies with 3-tone 135 deg volume
	_aa_ellipse_outlined(img, 94.0, 51.0, 27.0, 9.5, Color("#3d6b1e"), C_OUTLINE, 2.2)
	_aa_ellipse(img, 92.0, 49.0, 23.0, 7.0, Color("#5e962c"))
	_aa_ellipse(img, 86.0, 47.0, 14.0, 4.5, Color("#84bf3f"))

	_aa_ellipse_outlined(img, 34.0, 47.0, 28.0, 10.0, Color("#467823"), C_OUTLINE, 2.2)
	_aa_ellipse(img, 32.0, 44.5, 24.0, 7.5, Color("#6da832"))
	_aa_ellipse(img, 26.0, 42.5, 15.0, 4.8, Color("#9bd64b"))

	_aa_ellipse_outlined(img, 64.0, 36.0, 46.0, 13.5, Color("#487a24"), C_OUTLINE, 2.4)
	_aa_ellipse(img, 62.0, 33.5, 41.0, 10.5, Color("#73b036"))
	_aa_ellipse(img, 54.0, 30.5, 28.0, 7.0, Color("#9ed94c"))
	_aa_ellipse(img, 46.0, 28.5, 15.0, 4.2, Color("#bef068"))
	return img


static func _draw_tree_savanna_2() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 111.0, 36.0, 11.5, 0.36)

	# Stout bottle-shaped Baobab trunk with sunlit left & shaded right grooves
	var trunk_l := PackedVector2Array([
		Vector2(52, 54), Vector2(64, 54), Vector2(64, 111), Vector2(42, 111), Vector2(46, 82)
	])
	var trunk_r := PackedVector2Array([
		Vector2(64, 54), Vector2(76, 54), Vector2(82, 82), Vector2(86, 111), Vector2(64, 111)
	])
	_poly_outlined(img, trunk_l, Color("#b0764d"), Color("#855332"), C_OUTLINE, 2.3)
	_poly_outlined(img, trunk_r, Color("#78492b"), Color("#522f1a"), C_OUTLINE, 2.3)
	_aa_line(img, 56.0, 60.0, 52.0, 106.0, Color("#c78e65"), 2.2)
	_aa_line(img, 70.0, 60.0, 75.0, 106.0, Color("#452614"), 2.0)

	# Clustered 3-tone olive-gold crowns
	_draw_foliage_clump(img, 86.0, 50.0, 18.0, Color("#3b661d"), Color("#5c942c"), Color("#86c240"))
	_draw_foliage_clump(img, 42.0, 48.0, 19.0, Color("#437321"), Color("#68a332"), Color("#99d64a"))
	_draw_foliage_clump(img, 64.0, 38.0, 24.0, Color("#467823"), Color("#70ad36"), Color("#a5e052"))
	return img


static func _draw_spruce_single(img: Image, cx: float, base_y: float, scale_f: float) -> void:
	var tw := 5.5 * scale_f
	var trunk := PackedVector2Array([
		Vector2(cx - tw, base_y - 22.0 * scale_f),
		Vector2(cx + tw, base_y - 22.0 * scale_f),
		Vector2(cx + tw * 1.25, base_y),
		Vector2(cx - tw * 1.25, base_y)
	])
	_poly_outlined(img, trunk, Color("#7c4d2b"), Color("#452814"), C_OUTLINE, 2.2)

	for tier in range(4):
		var idx := 3 - tier
		var top_y := (base_y - 96.0 * scale_f) + float(idx) * 18.5 * scale_f
		var bot_y := top_y + 29.0 * scale_f
		var hw := (15.0 + float(idx) * 8.5) * scale_f

		var bough_l := PackedVector2Array([
			Vector2(cx, top_y),
			Vector2(cx, bot_y + 4.0 * scale_f),
			Vector2(cx - hw * 0.55, bot_y + 2.0 * scale_f),
			Vector2(cx - hw, bot_y - 2.0 * scale_f)
		])
		var bough_r := PackedVector2Array([
			Vector2(cx, top_y),
			Vector2(cx + hw, bot_y - 2.0 * scale_f),
			Vector2(cx + hw * 0.55, bot_y + 2.0 * scale_f),
			Vector2(cx, bot_y + 4.0 * scale_f)
		])
		_poly_outlined(img, bough_l, Color("#3b8564"), Color("#235942"), C_OUTLINE, 2.1)
		_poly_outlined(img, bough_r, Color("#245c44"), Color("#143829"), C_OUTLINE, 2.1)

		var snow_l := PackedVector2Array([
			Vector2(cx, top_y),
			Vector2(cx, top_y + 15.0 * scale_f),
			Vector2(cx - hw * 0.62, top_y + 13.0 * scale_f)
		])
		var snow_r := PackedVector2Array([
			Vector2(cx, top_y),
			Vector2(cx + hw * 0.54, top_y + 12.5 * scale_f),
			Vector2(cx, top_y + 15.0 * scale_f)
		])
		_poly_outlined(img, snow_l, Color("#ffffff"), Color("#e6f2fa"), C_OUTLINE, 1.8)
		_poly_outlined(img, snow_r, Color("#d4e5f2"), Color("#b0cadb"), C_OUTLINE, 1.8)


static func _draw_tree_tundra() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 111.0, 32.0, 11.0, 0.36)
	_draw_spruce_single(img, 64.0, 112.0, 1.0)
	return img


static func _draw_tree_tundra_2() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 111.0, 36.0, 11.5, 0.36)
	_draw_spruce_single(img, 82.0, 108.0, 0.78)
	_draw_spruce_single(img, 46.0, 112.0, 0.94)
	# Small snow-dusted stone at base
	var stone := PackedVector2Array([
		Vector2(64, 112), Vector2(70, 99), Vector2(84, 101), Vector2(88, 112)
	])
	_poly_outlined(img, stone, Color("#94a3b8"), Color("#525e6e"), C_OUTLINE, 1.9)
	return img


static func _draw_bush_arid() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 109.0, 32.0, 10.0, 0.35)

	# Faceted warm sandstone boulder at base right
	var rock_l := PackedVector2Array([
		Vector2(66, 108), Vector2(74, 86), Vector2(86, 84), Vector2(84, 109)
	])
	var rock_r := PackedVector2Array([
		Vector2(86, 84), Vector2(100, 93), Vector2(96, 109), Vector2(84, 109)
	])
	_poly_outlined(img, rock_l, Color("#dba065"), Color("#b0743c"), C_OUTLINE, 2.1)
	_poly_outlined(img, rock_r, Color("#9c612e"), Color("#6e411c"), C_OUTLINE, 2.1)

	# Left arm of ribbed saguaro cactus
	var left_arm := PackedVector2Array([
		Vector2(32, 48), Vector2(44, 48), Vector2(44, 65), Vector2(52, 65),
		Vector2(52, 76), Vector2(32, 76)
	])
	_poly_outlined(img, left_arm, Color("#68c466"), Color("#347d39"), C_OUTLINE, 2.2)
	_aa_circle_outlined(img, 38.0, 48.0, 6.0, Color("#74cf6e"), C_OUTLINE, 2.1)

	# Right arm (in slight cooler shade)
	var right_arm := PackedVector2Array([
		Vector2(64, 58), Vector2(80, 58), Vector2(80, 42), Vector2(91, 42),
		Vector2(91, 70), Vector2(64, 70)
	])
	_poly_outlined(img, right_arm, Color("#4ca350"), Color("#26632b"), C_OUTLINE, 2.2)
	_aa_circle_outlined(img, 85.5, 42.0, 5.5, Color("#57b059"), C_OUTLINE, 2.1)

	# Central saguaro column with 135 deg lit left ribs & shaded right ribs
	var stem_l := PackedVector2Array([
		Vector2(50, 32), Vector2(59, 32), Vector2(59, 109), Vector2(49, 109)
	])
	var stem_r := PackedVector2Array([
		Vector2(59, 32), Vector2(68, 32), Vector2(69, 109), Vector2(59, 109)
	])
	_poly_filled(img, stem_l, Color("#76d470"), Color("#469c49"))
	_poly_filled(img, stem_r, Color("#469c49"), Color("#25612b"))
	_aa_circle_outlined(img, 59.0, 32.0, 9.0, Color("#68c466"), C_OUTLINE, 2.3)
	_poly_filled(img, stem_l, Color("#76d470"), Color("#469c49"))
	_poly_filled(img, stem_r, Color("#469c49"), Color("#25612b"))
	_aa_line(img, 50.0, 32.0, 49.0, 109.0, C_OUTLINE, 2.3)
	_aa_line(img, 68.0, 32.0, 69.0, 109.0, C_OUTLINE, 2.3)
	_aa_line(img, 49.0, 109.0, 69.0, 109.0, C_OUTLINE, 2.3)
	_aa_line(img, 55.0, 34.0, 55.0, 106.0, Color("#98eb8d"), 1.6)
	_aa_line(img, 63.0, 34.0, 63.0, 106.0, Color("#1d4d22"), 1.5)

	# Desert cactus blossoms on apex & arm
	_aa_circle_outlined(img, 59.0, 22.0, 5.0, Color("#fb7185"), C_OUTLINE, 1.8)
	_aa_circle(img, 58.0, 21.0, 2.2, Color("#fef08a"))
	_aa_circle_outlined(img, 38.0, 41.0, 3.8, Color("#f43f5e"), C_OUTLINE, 1.6)
	return img


static func _draw_bush_berry() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 35.0, 11.0, 0.36)

	_draw_foliage_clump(img, 82.0, 86.0, 19.0, Color("#184f24"), Color("#297a37"), Color("#4cb052"))
	_draw_foliage_clump(img, 45.0, 85.0, 20.0, Color("#1d5c2a"), Color("#328f41"), Color("#5ec75e"))
	_draw_foliage_clump(img, 64.0, 73.0, 23.0, Color("#20632d"), Color("#389c47"), Color("#70db6b"))

	var berries := [
		Vector2(42, 82), Vector2(55, 68), Vector2(73, 70),
		Vector2(84, 84), Vector2(64, 86), Vector2(50, 93),
		Vector2(74, 93), Vector2(62, 76)
	]
	for b in berries:
		_aa_circle_outlined(img, b.x, b.y, 4.4, Color("#dc2626"), C_OUTLINE, 1.6)
		_aa_circle(img, b.x - 1.2, b.y - 1.2, 1.6, Color("#fecaca"))
	return img


static func _draw_fallen_log() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 103.0, 42.0, 11.0, 0.36)

	# Upper sunlit bark & lower shaded bark along angled trunk
	var top_bark := PackedVector2Array([
		Vector2(22, 80), Vector2(102, 71), Vector2(104, 83), Vector2(24, 92)
	])
	var bot_bark := PackedVector2Array([
		Vector2(24, 92), Vector2(104, 83), Vector2(103, 96), Vector2(25, 105)
	])
	_poly_filled(img, top_bark, Color("#9e6238"), Color("#7d4a27"))
	_poly_filled(img, bot_bark, Color("#63381c"), Color("#422310"))
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(22, 80), Vector2(102, 71), Vector2(103, 96), Vector2(25, 105)]),
		Color(0, 0, 0, 0),
		Color(0, 0, 0, 0),
		C_OUTLINE,
		2.4
	)
	_aa_line(img, 34.0, 86.0, 94.0, 79.0, Color("#b8784a"), 1.8)
	_aa_line(img, 38.0, 95.0, 96.0, 88.0, Color("#361c0c"), 1.8)

	# Cut heartwood end on left + hollow dark opening on right
	_aa_ellipse_outlined(img, 24.0, 92.5, 7.5, 12.5, Color("#e3be8c"), C_OUTLINE, 2.2)
	_aa_ellipse(img, 24.0, 92.5, 4.2, 7.2, Color("#b88652"))
	_aa_ellipse_outlined(img, 103.0, 83.5, 6.0, 12.0, Color("#3d2210"), C_OUTLINE, 2.2)

	# Plush 3-tone moss blanket on top-left of log + shelf fungi
	_draw_foliage_clump(img, 54.0, 76.0, 11.0, Color("#1f612d"), Color("#389c48"), Color("#72de70"))
	_draw_foliage_clump(img, 72.0, 75.0, 9.5, Color("#1f612d"), Color("#389c48"), Color("#72de70"))
	_aa_ellipse_outlined(img, 84.0, 89.0, 5.5, 3.0, Color("#f5d08a"), C_OUTLINE, 1.5)
	return img


static func _draw_mossy_rock() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 38.0, 11.5, 0.37)

	# Faceted granite boulder with 135 deg top-left sunlight, mid front & cool dark right facet
	var top_left_face := PackedVector2Array([
		Vector2(26, 96), Vector2(38, 66), Vector2(64, 54), Vector2(58, 78), Vector2(44, 104)
	])
	var front_mid_face := PackedVector2Array([
		Vector2(44, 104), Vector2(58, 78), Vector2(78, 80), Vector2(74, 106)
	])
	var right_shadow_face := PackedVector2Array([
		Vector2(64, 54), Vector2(92, 66), Vector2(100, 96), Vector2(74, 106), Vector2(78, 80), Vector2(58, 78)
	])
	_poly_outlined(img, top_left_face, Color("#bab5ad"), Color("#918d86"), C_OUTLINE, 2.3)
	_poly_outlined(img, front_mid_face, Color("#8c8983"), Color("#6b6965"), C_OUTLINE, 2.3)
	_poly_outlined(img, right_shadow_face, Color("#66686e"), Color("#45474d"), C_OUTLINE, 2.3)
	_aa_line(img, 39.0, 67.0, 64.0, 55.5, Color("#dedad2"), 2.0)
	_aa_line(img, 58.0, 78.0, 45.0, 102.0, Color("#d4cfc7"), 1.6)

	# Secondary companion stone in front-right
	var sub_l := PackedVector2Array([
		Vector2(76, 108), Vector2(84, 91), Vector2(96, 90), Vector2(94, 109)
	])
	var sub_r := PackedVector2Array([
		Vector2(96, 90), Vector2(108, 98), Vector2(105, 109), Vector2(94, 109)
	])
	_poly_outlined(img, sub_l, Color("#a8a49d"), Color("#7d7a74"), C_OUTLINE, 2.0)
	_poly_outlined(img, sub_r, Color("#595b61"), Color("#3e4045"), C_OUTLINE, 2.0)

	# Cushion moss along sunlit upper crest
	_draw_foliage_clump(img, 54.0, 60.0, 11.5, Color("#20632b"), Color("#3da347"), Color("#7be06c"))
	_draw_foliage_clump(img, 69.0, 63.0, 9.0, Color("#1c5726"), Color("#348f3e"), Color("#6ad45d"))
	return img


static func _draw_tall_grass() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 26.0, 8.0, 0.28)

	var back_blades := [
		[Vector2(44, 104), Vector2(28, 58)],
		[Vector2(56, 105), Vector2(48, 44)],
		[Vector2(70, 105), Vector2(78, 46)],
		[Vector2(82, 104), Vector2(98, 60)]
	]
	for b in back_blades:
		var base: Vector2 = b[0]
		var tip: Vector2 = b[1]
		var poly := PackedVector2Array([base + Vector2(-3.5, 0), tip, base + Vector2(3.5, 0)])
		_poly_outlined(img, poly, Color("#5ea32a"), Color("#2c5e18"), C_OUTLINE, 1.9)

	var front_blades := [
		[Vector2(48, 106), Vector2(36, 50)],
		[Vector2(60, 107), Vector2(58, 36)],
		[Vector2(66, 107), Vector2(70, 40)],
		[Vector2(76, 106), Vector2(88, 52)]
	]
	for b in front_blades:
		var base: Vector2 = b[0]
		var tip: Vector2 = b[1]
		var poly := PackedVector2Array([base + Vector2(-3.8, 0), tip, base + Vector2(3.8, 0)])
		_poly_outlined(img, poly, Color("#b2eb47"), Color("#4b8f24"), C_OUTLINE, 2.0)
		_aa_ellipse_outlined(img, tip.x, tip.y + 3.0, 3.2, 6.5, Color("#facc15"), C_OUTLINE, 1.5)
	return img


static func _draw_dry_scrub() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 28.0, 8.5, 0.30)

	var twigs := [
		Vector2(28, 68), Vector2(38, 50), Vector2(52, 42),
		Vector2(65, 38), Vector2(78, 44), Vector2(90, 54), Vector2(98, 70)
	]
	for idx in range(twigs.size()):
		var sp: Vector2 = twigs[idx]
		var sunlit := idx < 4
		var c_top := Color("#e6b96e") if sunlit else Color("#bf8d47")
		var c_bot := Color("#96652c") if sunlit else Color("#6e461b")
		var blade := PackedVector2Array([
			Vector2(58 + float(idx), 105),
			sp,
			Vector2(65 + float(idx), 105)
		])
		_poly_outlined(img, blade, c_top, c_bot, C_OUTLINE, 1.9)

	_aa_ellipse_outlined(img, 48.0, 105.0, 7.0, 4.0, Color("#b88a58"), C_OUTLINE, 1.7)
	_aa_ellipse_outlined(img, 78.0, 106.0, 6.0, 3.5, Color("#8a623a"), C_OUTLINE, 1.7)
	return img


static func _draw_rock_mountain() -> Image:
	var img := _new_canvas(160, 160)
	_drop_shadow(img, 80.0, 142.0, 66.0, 19.0, 0.42)

	# Back-left secondary peak (warm sunlit left, cool slate right)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(12, 134), Vector2(46, 44), Vector2(54, 134)]),
		Color("#b3a598"), Color("#877a6e"), C_OUTLINE, 2.4
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(46, 44), Vector2(84, 134), Vector2(54, 134)]),
		Color("#686468"), Color("#464347"), C_OUTLINE, 2.4
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(46, 44), Vector2(50, 78), Vector2(40, 72), Vector2(31, 80)]),
		Color("#ffffff"), Color("#e8f2fa"), C_OUTLINE, 2.0
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(46, 44), Vector2(62, 78), Vector2(50, 78)]),
		Color("#cfe0ee"), Color("#a9c0d4"), C_OUTLINE, 2.0
	)

	# Back-right secondary peak
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(78, 134), Vector2(116, 48), Vector2(118, 134)]),
		Color("#aba094"), Color("#7d7268"), C_OUTLINE, 2.4
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(116, 48), Vector2(150, 134), Vector2(118, 134)]),
		Color("#5e5b61"), Color("#3e3c42"), C_OUTLINE, 2.4
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(116, 48), Vector2(117, 80), Vector2(107, 74), Vector2(99, 82)]),
		Color("#ffffff"), Color("#e3eff8"), C_OUTLINE, 2.0
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(116, 48), Vector2(131, 82), Vector2(117, 80)]),
		Color("#c7daea"), Color("#a2bacf"), C_OUTLINE, 2.0
	)

	# Central commanding spire with 3 sculptural rock facets
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(30, 140), Vector2(78, 16), Vector2(72, 92), Vector2(58, 142)]),
		Color("#c2b4a6"), Color("#918377"), C_OUTLINE, 2.6
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(58, 142), Vector2(72, 92), Vector2(78, 16), Vector2(88, 96), Vector2(86, 142)]),
		Color("#968a7f"), Color("#6e655d"), C_OUTLINE, 2.4
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(78, 16), Vector2(132, 140), Vector2(86, 142), Vector2(88, 96)]),
		Color("#666369"), Color("#434147"), C_OUTLINE, 2.6
	)
	_aa_line(img, 77.5, 19.0, 71.5, 90.0, Color("#e8dfd5"), 2.0)

	# Sculpted alpine snowcap on central peak (135 deg sunlit left & cool blue shadow right)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(78, 16), Vector2(75, 72), Vector2(65, 64), Vector2(56, 74)]),
		Color("#ffffff"), Color("#edf5fc"), C_OUTLINE, 2.2
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(78, 16), Vector2(84, 74), Vector2(75, 72)]),
		Color("#dceaf5"), Color("#bdd2e4"), C_OUTLINE, 2.0
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(78, 16), Vector2(102, 72), Vector2(92, 64), Vector2(84, 74)]),
		Color("#c9dceb"), Color("#9fb8cc"), C_OUTLINE, 2.2
	)

	# Foreground faceted foothill crag
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(44, 143), Vector2(68, 98), Vector2(72, 143)]),
		Color("#ab9e92"), Color("#7d7268"), C_OUTLINE, 2.2
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(68, 98), Vector2(96, 143), Vector2(72, 143)]),
		Color("#615e63"), Color("#424045"), C_OUTLINE, 2.2
	)
	return img


static func _draw_coastal_reeds() -> Image:
	var img := _new_canvas(128, 128)
	_aa_ellipse(img, 64.0, 108.0, 36.0, 10.0, Color(0.75, 0.95, 1.0, 0.52))
	_aa_ellipse(img, 64.0, 108.0, 24.0, 6.0, Color(0.92, 0.99, 1.0, 0.65))

	var stalks := [40.0, 50.0, 60.0, 70.0, 80.0, 88.0]
	for idx in range(stalks.size()):
		var sx: float = stalks[idx]
		var top_y: float = 28.0 + float(idx % 3) * 8.0
		var bend: float = -4.5 if idx % 2 == 0 else 4.0
		_aa_line(img, sx, 107.0, sx + bend, top_y, C_OUTLINE, 4.2)
		_aa_line(img, sx, 107.0, sx + bend, top_y, Color("#5ec24e") if idx < 3 else Color("#3c9434"), 2.3)
		if idx % 2 == 0 or idx == 3:
			var hx := sx + bend * 0.72
			var hy := top_y + 14.0
			var head := PackedVector2Array([
				Vector2(hx - 3.6, hy - 8.0), Vector2(hx + 3.6, hy - 8.0),
				Vector2(hx + 3.6, hy + 8.0), Vector2(hx - 3.6, hy + 8.0)
			])
			_poly_outlined(img, head, Color("#8c522b"), Color("#4d2913"), C_OUTLINE, 1.9)
			_aa_line(img, hx - 1.5, hy - 6.0, hx - 1.5, hy + 6.0, Color("#b57445"), 1.3)
	return img


static func _draw_tree_stump() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 32.0, 10.0, 0.36)

	var body_l := PackedVector2Array([
		Vector2(44, 72), Vector2(64, 72), Vector2(64, 107), Vector2(34, 107), Vector2(42, 94)
	])
	var body_r := PackedVector2Array([
		Vector2(64, 72), Vector2(84, 72), Vector2(86, 94), Vector2(94, 107), Vector2(64, 107)
	])
	_poly_outlined(img, body_l, Color("#9c6038"), Color("#6e4123"), C_OUTLINE, 2.3)
	_poly_outlined(img, body_r, Color("#6b3e20"), Color("#422411"), C_OUTLINE, 2.3)
	_aa_ellipse_outlined(img, 64.0, 72.0, 20.0, 8.5, Color("#e8c594"), C_OUTLINE, 2.3)
	_aa_ellipse_outlined(img, 64.0, 72.0, 13.0, 5.2, Color("#cfa06b"), Color("#99683b"), 1.4)
	_aa_ellipse(img, 64.0, 72.0, 5.5, 2.2, Color("#8c582e"))

	# Sprouting sapling leaf & basal moss
	_aa_line(img, 44.0, 76.0, 34.0, 62.0, C_OUTLINE, 3.4)
	_aa_line(img, 44.0, 76.0, 34.0, 62.0, Color("#4ead48"), 1.8)
	_aa_ellipse_outlined(img, 31.0, 59.0, 6.5, 3.8, Color("#7ae068"), C_OUTLINE, 1.6)
	_draw_foliage_clump(img, 50.0, 102.0, 7.5, Color("#1f612d"), Color("#389c48"), Color("#72de70"))
	return img


static func _draw_soil_crack() -> Image:
	var img := _new_canvas(128, 128)
	var segs := [
		[Vector2(22, 68), Vector2(58, 76), 3.4],
		[Vector2(58, 76), Vector2(104, 58), 3.0],
		[Vector2(58, 76), Vector2(76, 104), 2.6],
		[Vector2(42, 72), Vector2(28, 96), 2.2]
	]
	for sg in segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var w: float = float(sg[2])
		_aa_line(img, a.x + 1.2, a.y + 1.8, b.x + 1.2, b.y + 1.8, Color("#ebca8d"), w * 0.8)
		_aa_line(img, a.x, a.y, b.x, b.y, Color("#361b0b"), w)
	return img


static func _draw_wildflowers() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 28.0, 8.5, 0.26)
	_draw_foliage_clump(img, 54.0, 96.0, 14.0, Color("#1e5e2b"), Color("#359442"), Color("#68cf60"))
	_draw_foliage_clump(img, 74.0, 97.0, 13.0, Color("#1b5426"), Color("#2e823a"), Color("#57bf52"))

	var blooms := [
		[42.0, 76.0, Color("#fb7185")],
		[64.0, 64.0, Color("#fbbf24")],
		[84.0, 78.0, Color("#60a5fa")],
		[56.0, 86.0, Color("#c084fc")],
		[74.0, 88.0, Color("#f97316")]
	]
	for bl in blooms:
		var bx: float = float(bl[0])
		var by: float = float(bl[1])
		var col: Color = bl[2]
		_aa_line(img, bx, by + 4.0, bx + 2.0, 102.0, C_OUTLINE, 3.4)
		_aa_line(img, bx, by + 4.0, bx + 2.0, 102.0, Color("#3da349"), 1.8)
		for p_i in range(5):
			var ang := TAU * float(p_i) / 5.0 - 0.4
			var px_p := bx + cos(ang) * 5.2
			var py_p := by + sin(ang) * 4.6
			var p_col := col.lightened(0.12) if p_i < 3 else col.darkened(0.08)
			_aa_circle_outlined(img, px_p, py_p, 4.2, p_col, C_OUTLINE, 1.5)
		_aa_circle_outlined(img, bx, by, 3.4, Color("#fef08a"), C_OUTLINE, 1.4)
	return img
