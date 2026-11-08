class_name EvoTerrainSprites
extends EvoPixelCanvas


static func draw_terrain_sprite(sprite_name: String) -> Image:
	match sprite_name:
		"tree_tropical", "tree_canopy":
			return _draw_tree_tropical()
		"tree_tropical_2", "palm_cluster":
			return _draw_tree_tropical_2()
		"tree_savanna", "savanna_tree", "acacia_tree":
			return _draw_tree_savanna()
		"tree_savanna_2":
			return _draw_tree_savanna_2()
		"tree_tundra", "pine_tree":
			return _draw_tree_tundra()
		"tree_tundra_2":
			return _draw_tree_tundra_2()
		"bush_arid":
			return _draw_bush_arid()
		"bush_berry", "bush_cluster":
			return _draw_bush_berry()
		"fallen_log":
			return _draw_fallen_log()
		"mossy_rock":
			return _draw_mossy_rock()
		"tall_grass":
			return _draw_tall_grass()
		"dry_scrub":
			return _draw_dry_scrub()
		"rock_mountain", "mountain_peak":
			return _draw_rock_mountain()
		"coastal_reeds", "marsh_reeds":
			return _draw_coastal_reeds()
		"tree_stump":
			return _draw_tree_stump()
		"soil_crack":
			return _draw_soil_crack()
		_:
			return _draw_wildflowers()


static func draw_hex_tile(biome: String) -> Image:
	var w := 256
	var h := 224
	var img := _new_canvas(w, h)
	var cx := 128.0
	var cy := 112.0

	match biome:
		"tropical_forest":
			var top_c := Color("#4ca83b")
			var bot_c := Color("#297324")
			for y in range(h):
				var t := float(y) / float(h - 1)
				img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, t))
			_aa_ellipse(img, cx, cy, 98.0, 82.0, Color(0.38, 0.74, 0.28, 0.45))
			var moss_spots := [
				Vector2(68, 62), Vector2(182, 58), Vector2(58, 142),
				Vector2(188, 146), Vector2(128, 108), Vector2(104, 162),
				Vector2(154, 82), Vector2(88, 96)
			]
			for ms in moss_spots:
				_aa_ellipse(img, ms.x, ms.y, 24.0, 13.0, Color("#246920"))
				_aa_ellipse(img, ms.x - 2.0, ms.y - 1.0, 16.0, 8.0, Color("#5ec447"))
			for i in range(42):
				var fx := 24.0 + float(_hash2d(i, 1, 31) % 208)
				var fy := 20.0 + float(_hash2d(i, 2, 31) % 184)
				_aa_line(img, fx, fy, fx - 5.0, fy - 4.0, Color("#1b4f18"), 2.0)
				_aa_line(img, fx, fy, fx + 5.0, fy - 4.0, Color("#1b4f18"), 2.0)
				_aa_line(img, fx, fy - 1.0, fx - 3.0, fy - 6.0, Color("#7ae55c"), 1.6)
				_aa_line(img, fx, fy - 1.0, fx + 3.0, fy - 6.0, Color("#7ae55c"), 1.6)

		"savanna":
			var top_c := Color("#9bd142")
			var bot_c := Color("#6ea326")
			for y in range(h):
				var t := float(y) / float(h - 1)
				img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, t))
			_aa_ellipse(img, cx, cy - 6.0, 96.0, 80.0, Color(0.68, 0.88, 0.32, 0.42))
			for dp in [Vector2(76, 76), Vector2(172, 126), Vector2(98, 152), Vector2(158, 72)]:
				_aa_ellipse(img, dp.x, dp.y, 22.0, 11.0, Color("#80b52c"))
			for i in range(48):
				var gx := 22.0 + float(_hash2d(i, 3, 41) % 212)
				var gy := 18.0 + float(_hash2d(i, 4, 41) % 188)
				_aa_line(img, gx, gy, gx - 3.0, gy - 6.0, Color("#4c7816"), 1.8)
				_aa_line(img, gx + 2.0, gy, gx + 4.0, gy - 7.0, Color("#b5e550"), 1.6)

		"arid_steppe":
			var top_c := Color("#f5d17f")
			var bot_c := Color("#d9a44a")
			for y in range(h):
				var t := float(y) / float(h - 1)
				img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, t))
			_aa_ellipse(img, cx, cy, 102.0, 84.0, Color(0.98, 0.86, 0.56, 0.35))
			# Illustrated Voronoi mud crack network matching land.jpeg / land2.jpeg
			var seeds: Array[Vector2] = []
			for gy in range(5):
				for gx in range(6):
					var sx := 22.0 + float(gx) * 42.0 + float(_hash2d(gx, gy, 53) % 22 - 11)
					var sy := 20.0 + float(gy) * 44.0 + float(_hash2d(gx, gy, 59) % 20 - 10)
					seeds.append(Vector2(sx, sy))
			for i in range(seeds.size()):
				var a := seeds[i]
				for j in range(i + 1, seeds.size()):
					var b := seeds[j]
					var d := a.distance_to(b)
					if d > 24.0 and d < 62.0:
						var mid := (a + b) * 0.5 + Vector2(float(_hash2d(i, j, 61) % 9 - 4), float(_hash2d(j, i, 67) % 9 - 4))
						_aa_line(img, a.x, a.y, mid.x, mid.y, Color("#78471e"), 2.0)
						_aa_line(img, mid.x, mid.y, b.x, b.y, Color("#78471e"), 2.0)
						_aa_line(img, a.x, a.y + 1.0, mid.x, mid.y + 1.0, Color("#f7dc9c"), 1.0)

		"tundra":
			var top_c := Color("#eef6fa")
			var bot_c := Color("#b3cde0")
			for y in range(h):
				var t := float(y) / float(h - 1)
				img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, t))
			for mp in [Vector2(76, 78), Vector2(174, 82), Vector2(112, 148), Vector2(148, 60)]:
				_aa_ellipse(img, mp.x, mp.y, 26.0, 12.0, Color("#9bbcd1"))
				_aa_ellipse(img, mp.x - 3.0, mp.y - 2.0, 18.0, 8.0, Color("#ffffff"))
			for i in range(32):
				var ix := 26.0 + float(_hash2d(i, 7, 79) % 204)
				var iy := 22.0 + float(_hash2d(i, 8, 79) % 180)
				_aa_line(img, ix - 4.0, iy, ix + 4.0, iy, Color("#ffffff"), 1.8)
				_aa_line(img, ix, iy - 4.0, ix, iy + 4.0, Color("#7dd3fc"), 1.6)

		"high_mountain":
			var top_c := Color("#8c857e")
			var bot_c := Color("#59534e")
			for y in range(h):
				var t := float(y) / float(h - 1)
				img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, t))
			var snow_caps := [
				Vector2(104, 64), Vector2(152, 78), Vector2(124, 120),
				Vector2(82, 112), Vector2(170, 134), Vector2(78, 152)
			]
			for sc in snow_caps:
				_aa_ellipse(img, sc.x, sc.y, 24.0, 12.0, Color("#cbd5e1"))
				_aa_ellipse(img, sc.x - 2.0, sc.y - 2.0, 17.0, 8.0, Color("#f8fafc"))
			for i in range(28):
				var rx := 28.0 + float(_hash2d(i, 9, 97) % 200)
				var ry := 24.0 + float(_hash2d(i, 10, 97) % 176)
				_aa_line(img, rx - 8.0, ry, rx + 8.0, ry + 3.0, Color("#332f2c"), 2.2)
				_aa_line(img, rx - 6.0, ry - 2.0, rx + 6.0, ry + 1.0, Color("#b8b0a8"), 1.5)

		"coastal_shallows":
			var top_c := Color("#4fd1c5")
			var bot_c := Color("#289994")
			for y in range(h):
				var t := float(y) / float(h - 1)
				img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, t))
			# Sandy shoal bank & double white foam contours matching land2.jpeg
			_aa_ellipse(img, cx - 18.0, cy - 10.0, 88.0, 70.0, Color("#e8f8fa"))
			_aa_ellipse(img, cx - 22.0, cy - 12.0, 78.0, 62.0, Color("#7de2d8"))
			_aa_ellipse(img, cx - 26.0, cy - 14.0, 66.0, 50.0, Color("#f2fafd"))
			_aa_ellipse(img, cx - 30.0, cy - 16.0, 58.0, 44.0, Color("#ebcf8d"))
			_aa_ellipse(img, cx - 34.0, cy - 18.0, 44.0, 32.0, Color("#f5dfa6"))
			for i in range(18):
				var wx := 36.0 + float(_hash2d(i, 11, 109) % 184)
				var wy := 28.0 + float(_hash2d(i, 12, 109) % 168)
				_aa_line(img, wx - 10.0, wy, wx + 10.0, wy - 2.0, Color(0.94, 0.99, 1.0, 0.75), 2.2)

		_:
			var top_c := Color("#23689b")
			var bot_c := Color("#154266")
			for y in range(h):
				var t := float(y) / float(h - 1)
				img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, t))
			for i in range(28):
				var wx := 26.0 + float(_hash2d(i, 11, 131) % 204)
				var wy := 22.0 + float(_hash2d(i, 12, 131) % 180)
				_aa_line(img, wx - 12.0, wy, wx, wy - 3.0, Color("#7dd3fc"), 2.4)
				_aa_line(img, wx, wy - 3.0, wx + 12.0, wy, Color("#7dd3fc"), 2.4)
				_aa_line(img, wx - 7.0, wy - 2.0, wx + 7.0, wy - 2.0, Color("#e0f2fe"), 1.6)

	return img


static func _draw_tree_tropical() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 34.0, 12.0, 0.38)

	# Gnarled broadleaf trunk & buttress roots with dark ink outline
	var trunk := PackedVector2Array([
		Vector2(56, 56), Vector2(72, 56), Vector2(75, 96),
		Vector2(86, 112), Vector2(68, 112), Vector2(64, 102),
		Vector2(60, 112), Vector2(42, 112), Vector2(53, 96)
	])
	_poly_outlined(img, trunk, Color("#8c5230"), Color("#593118"), C_OUTLINE, 2.4)
	_aa_line(img, 62.0, 62.0, 60.0, 102.0, Color("#a86840"), 2.2)
	_aa_line(img, 54.0, 62.0, 40.0, 44.0, C_OUTLINE, 3.5)
	_aa_line(img, 74.0, 62.0, 88.0, 46.0, C_OUTLINE, 3.5)

	# Multi-layered illustrated canopy puffs matching land.jpeg
	var back_puffs := [
		Vector3(38, 56, 24), Vector3(90, 56, 24), Vector3(64, 34, 28)
	]
	for bp in back_puffs:
		_aa_circle_outlined(img, bp.x, bp.y, bp.z, Color("#1f6e32"), C_OUTLINE, 2.6)

	var mid_puffs := [
		Vector3(46, 46, 24), Vector3(82, 48, 23), Vector3(64, 54, 26)
	]
	for mp in mid_puffs:
		_aa_circle_outlined(img, mp.x, mp.y, mp.z, Color("#329642"), C_OUTLINE, 2.4)

	# Inner sunlit foliage clusters
	_aa_circle(img, 44.0, 42.0, 17.0, Color("#52bf58"))
	_aa_circle(img, 78.0, 44.0, 16.0, Color("#45ad4b"))
	_aa_circle(img, 62.0, 30.0, 19.0, Color("#62cf63"))
	_aa_circle(img, 62.0, 48.0, 18.0, Color("#4eb854"))
	_aa_ellipse(img, 58.0, 24.0, 12.0, 7.0, Color("#86e87e"))

	# Crisp comic leaf contour arcs inside the crown
	_aa_line(img, 48.0, 52.0, 58.0, 46.0, C_OUTLINE, 2.0)
	_aa_line(img, 70.0, 50.0, 80.0, 56.0, C_OUTLINE, 2.0)
	return img


static func _draw_tree_tropical_2() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 30.0, 10.0, 0.36)

	# Curved segmented palm trunk matching land.jpeg / land2.jpeg
	var segs := 10
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(110.0, 46.0, t0)
		var y1 := lerpf(110.0, 46.0, t1)
		var x0 := 62.0 + sin(t0 * 2.6) * 8.0
		var x1 := 62.0 + sin(t1 * 2.6) * 8.0
		var w0 := lerpf(7.5, 4.2, t0)
		var w1 := lerpf(7.5, 4.2, t1)
		var quad := PackedVector2Array([
			Vector2(x0 - w0, y0), Vector2(x1 - w1, y1),
			Vector2(x1 + w1, y1), Vector2(x0 + w0, y0)
		])
		_poly_outlined(img, quad, Color("#9e6238"), Color("#704222"), C_OUTLINE, 2.2)

	var top_pt := Vector2(62.0 + sin(2.6) * 8.0, 46.0)
	# Coconuts at crown base
	_aa_circle_outlined(img, top_pt.x - 5.0, top_pt.y + 3.0, 5.5, Color("#5c3418"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, top_pt.x + 5.0, top_pt.y + 4.0, 5.5, Color("#6e4020"), C_OUTLINE, 2.0)

	# Sweeping illustrated palm fronds
	var fronds := [
		[Vector2(-44, 14), Vector2(-24, -14)],
		[Vector2(-36, -12), Vector2(-16, -24)],
		[Vector2(0, -26), Vector2(-4, -16)],
		[Vector2(38, -10), Vector2(18, -22)],
		[Vector2(44, 16), Vector2(24, -12)],
		[Vector2(-26, 26), Vector2(-14, 4)],
		[Vector2(28, 26), Vector2(14, 4)]
	]
	for f in fronds:
		var tip: Vector2 = top_pt + (f[0] as Vector2)
		var ctrl: Vector2 = top_pt + (f[1] as Vector2)
		var leaf := PackedVector2Array([
			top_pt,
			ctrl + Vector2(0, -7),
			tip,
			ctrl + Vector2(0, 5)
		])
		_poly_outlined(img, leaf, Color("#65cf58"), Color("#278234"), C_OUTLINE, 2.2)
		_aa_line(img, top_pt.x, top_pt.y, tip.x, tip.y, Color("#1c5e24"), 1.8)
	return img


static func _draw_tree_savanna() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 38.0, 12.0, 0.35)

	# Gnarled branching umbrella acacia trunk matching land.jpeg bottom-right
	var trunk := PackedVector2Array([
		Vector2(58, 66), Vector2(68, 66), Vector2(72, 110), Vector2(54, 110)
	])
	_poly_outlined(img, trunk, Color("#8a542e"), Color("#593318"), C_OUTLINE, 2.4)
	_aa_line(img, 62.0, 74.0, 36.0, 48.0, Color("#6e3f20"), 5.0)
	_aa_line(img, 62.0, 74.0, 36.0, 48.0, C_OUTLINE, 6.8)
	_aa_line(img, 62.0, 74.0, 36.0, 48.0, Color("#824c28"), 3.6)

	_aa_line(img, 64.0, 72.0, 92.0, 50.0, C_OUTLINE, 6.8)
	_aa_line(img, 64.0, 72.0, 92.0, 50.0, Color("#824c28"), 3.6)

	_aa_line(img, 63.0, 68.0, 62.0, 42.0, C_OUTLINE, 6.4)
	_aa_line(img, 63.0, 68.0, 62.0, 42.0, Color("#824c28"), 3.4)

	# Flat-topped umbrella canopy layers
	_aa_ellipse_outlined(img, 36.0, 48.0, 26.0, 10.0, Color("#4f8728"), C_OUTLINE, 2.4)
	_aa_ellipse_outlined(img, 92.0, 50.0, 26.0, 10.0, Color("#467a22"), C_OUTLINE, 2.4)
	_aa_ellipse_outlined(img, 64.0, 38.0, 46.0, 14.0, Color("#68a832"), C_OUTLINE, 2.6)
	_aa_ellipse(img, 62.0, 35.0, 38.0, 9.0, Color("#88c940"))
	_aa_ellipse(img, 56.0, 32.0, 24.0, 5.5, Color("#a5e052"))
	return img


static func _draw_tree_savanna_2() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 34.0, 11.0, 0.36)

	var trunk := PackedVector2Array([
		Vector2(52, 54), Vector2(76, 54), Vector2(84, 110), Vector2(44, 110)
	])
	_poly_outlined(img, trunk, Color("#9c633e"), Color("#694025"), C_OUTLINE, 2.5)
	_aa_line(img, 60.0, 60.0, 56.0, 106.0, Color("#b57850"), 2.2)

	_aa_ellipse_outlined(img, 42.0, 50.0, 24.0, 15.0, Color("#568f2c"), C_OUTLINE, 2.4)
	_aa_ellipse_outlined(img, 86.0, 50.0, 24.0, 15.0, Color("#4b8025"), C_OUTLINE, 2.4)
	_aa_ellipse_outlined(img, 64.0, 38.0, 32.0, 18.0, Color("#73b538"), C_OUTLINE, 2.5)
	_aa_ellipse(img, 60.0, 33.0, 22.0, 11.0, Color("#96d648"))
	return img


static func _draw_tree_tundra() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 30.0, 10.0, 0.36)

	var trunk := PackedVector2Array([
		Vector2(58, 86), Vector2(70, 86), Vector2(72, 112), Vector2(56, 112)
	])
	_poly_outlined(img, trunk, Color("#6b4226"), Color("#422714"), C_OUTLINE, 2.4)

	# 3 tiered conifer cones with snow caps
	for tier in range(3):
		var idx := 2 - tier
		var top_y := 14.0 + float(idx) * 22.0
		var bot_y := top_y + 34.0
		var hw := 22.0 + float(idx) * 11.0
		var cone := PackedVector2Array([
			Vector2(64.0, top_y),
			Vector2(64.0 + hw, bot_y),
			Vector2(64.0, bot_y + 5.0),
			Vector2(64.0 - hw, bot_y)
		])
		_poly_outlined(img, cone, Color("#2f7556"), Color("#1b4734"), C_OUTLINE, 2.4)
		var snow := PackedVector2Array([
			Vector2(64.0, top_y),
			Vector2(64.0 + hw * 0.58, top_y + 18.0),
			Vector2(64.0, top_y + 21.0),
			Vector2(64.0 - hw * 0.58, top_y + 18.0)
		])
		_poly_outlined(img, snow, Color("#ffffff"), Color("#cfe4f2"), C_OUTLINE, 2.0)
	return img


static func _draw_tree_tundra_2() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 34.0, 11.0, 0.36)
	for tree_i in range(2):
		var cx := 46.0 if tree_i == 0 else 82.0
		var scale_f := 1.0 if tree_i == 0 else 0.84
		var base_y := 110.0
		var trunk := PackedVector2Array([
			Vector2(cx - 4.0, base_y - 18.0), Vector2(cx + 4.0, base_y - 18.0),
			Vector2(cx + 5.0, base_y), Vector2(cx - 5.0, base_y)
		])
		_poly_outlined(img, trunk, Color("#6b4226"), Color("#422714"), C_OUTLINE, 2.2)
		for tier in range(3):
			var idx := 2 - tier
			var top_y := (20.0 if tree_i == 0 else 32.0) + float(idx) * 19.0 * scale_f
			var bot_y := top_y + 28.0 * scale_f
			var hw := (16.0 + float(idx) * 8.0) * scale_f
			var cone := PackedVector2Array([
				Vector2(cx, top_y),
				Vector2(cx + hw, bot_y),
				Vector2(cx - hw, bot_y)
			])
			_poly_outlined(img, cone, Color("#2c6e50"), Color("#194230"), C_OUTLINE, 2.2)
			var snow := PackedVector2Array([
				Vector2(cx, top_y),
				Vector2(cx + hw * 0.52, top_y + 13.0 * scale_f),
				Vector2(cx - hw * 0.52, top_y + 13.0 * scale_f)
			])
			_poly_outlined(img, snow, Color("#f8fafc"), Color("#cbd5e1"), C_OUTLINE, 1.8)
	return img


static func _draw_bush_arid() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 28.0, 9.0, 0.34)
	# Desert boulder + saguaro cactus with flowers
	var rock := PackedVector2Array([
		Vector2(70, 92), Vector2(88, 86), Vector2(98, 98), Vector2(92, 108), Vector2(66, 108)
	])
	_poly_outlined(img, rock, Color("#c98a4b"), Color("#8c5828"), C_OUTLINE, 2.2)

	var main_stem := PackedVector2Array([
		Vector2(52, 34), Vector2(66, 34), Vector2(68, 108), Vector2(50, 108)
	])
	_poly_outlined(img, main_stem, Color("#58b05c"), Color("#2f7534"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 59.0, 34.0, 7.0, Color("#58b05c"), C_OUTLINE, 2.4)

	var left_arm := PackedVector2Array([
		Vector2(34, 48), Vector2(44, 48), Vector2(44, 64), Vector2(52, 64),
		Vector2(52, 74), Vector2(34, 74)
	])
	_poly_outlined(img, left_arm, Color("#58b05c"), Color("#2f7534"), C_OUTLINE, 2.2)

	var right_arm := PackedVector2Array([
		Vector2(66, 56), Vector2(82, 56), Vector2(82, 42), Vector2(92, 42),
		Vector2(92, 68), Vector2(66, 68)
	])
	_poly_outlined(img, right_arm, Color("#4ea352"), Color("#2b6930"), C_OUTLINE, 2.2)
	_aa_circle_outlined(img, 59.0, 26.0, 4.5, Color("#ff5964"), C_OUTLINE, 1.8)
	return img


static func _draw_bush_berry() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 32.0, 10.0, 0.35)
	_aa_circle_outlined(img, 46.0, 86.0, 20.0, Color("#247834"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 82.0, 86.0, 20.0, Color("#1f692d"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 64.0, 74.0, 24.0, Color("#379c47"), C_OUTLINE, 2.5)
	_aa_circle(img, 58.0, 68.0, 16.0, Color("#58c462"))

	var berries := [
		Vector2(44, 82), Vector2(56, 70), Vector2(74, 72),
		Vector2(82, 86), Vector2(64, 88), Vector2(50, 92), Vector2(72, 92)
	]
	for b in berries:
		_aa_circle_outlined(img, b.x, b.y, 4.2, Color("#ef4444"), C_OUTLINE, 1.6)
		_aa_circle(img, b.x - 1.0, b.y - 1.0, 1.5, Color("#fecaca"))
	return img


static func _draw_fallen_log() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 104.0, 38.0, 10.0, 0.34)
	var body := PackedVector2Array([
		Vector2(24, 78), Vector2(102, 72), Vector2(104, 96), Vector2(26, 102)
	])
	_poly_outlined(img, body, Color("#8c5330"), Color("#593118"), C_OUTLINE, 2.4)
	_aa_ellipse_outlined(img, 25.0, 90.0, 7.0, 12.0, Color("#deb887"), C_OUTLINE, 2.2)
	_aa_ellipse_outlined(img, 103.0, 84.0, 6.0, 12.0, Color("#4a2c18"), C_OUTLINE, 2.2)
	# Moss patch on top of log
	var moss := PackedVector2Array([
		Vector2(42, 75), Vector2(82, 72), Vector2(86, 82), Vector2(40, 84)
	])
	_poly_outlined(img, moss, Color("#5ce07a"), Color("#2d9447"), C_OUTLINE, 2.0)
	return img


static func _draw_mossy_rock() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 34.0, 10.0, 0.35)
	var left_facet := PackedVector2Array([
		Vector2(30, 98), Vector2(46, 66), Vector2(68, 60), Vector2(66, 104)
	])
	var right_facet := PackedVector2Array([
		Vector2(68, 60), Vector2(92, 70), Vector2(98, 98), Vector2(66, 104)
	])
	_poly_outlined(img, left_facet, Color("#949ba3"), Color("#6c727a"), C_OUTLINE, 2.4)
	_poly_outlined(img, right_facet, Color("#6c727a"), Color("#494e54"), C_OUTLINE, 2.4)
	var moss := PackedVector2Array([
		Vector2(44, 66), Vector2(68, 58), Vector2(84, 68), Vector2(64, 76)
	])
	_poly_outlined(img, moss, Color("#65cf58"), Color("#2b8230"), C_OUTLINE, 2.0)
	return img


static func _draw_tall_grass() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 22.0, 7.0, 0.28)
	var blades := [
		[Vector2(46, 104), Vector2(32, 56)],
		[Vector2(54, 106), Vector2(44, 46)],
		[Vector2(62, 106), Vector2(60, 40)],
		[Vector2(68, 106), Vector2(74, 44)],
		[Vector2(76, 104), Vector2(90, 54)],
		[Vector2(82, 104), Vector2(98, 68)]
	]
	for b in blades:
		var base: Vector2 = b[0]
		var tip: Vector2 = b[1]
		var blade_poly := PackedVector2Array([
			base + Vector2(-3.5, 0),
			tip,
			base + Vector2(3.5, 0)
		])
		_poly_outlined(img, blade_poly, Color("#a3e635"), Color("#3f8226"), C_OUTLINE, 2.0)
	return img


static func _draw_dry_scrub() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 26.0, 8.0, 0.30)
	# Illustrated golden-brown desert scrub tuft matching land.jpeg bottom-right
	var spikes := [
		Vector2(30, 68), Vector2(40, 52), Vector2(54, 44),
		Vector2(66, 40), Vector2(78, 46), Vector2(90, 56), Vector2(98, 72)
	]
	for sp in spikes:
		var blade := PackedVector2Array([
			Vector2(60, 104),
			sp,
			Vector2(68, 104)
		])
		_poly_outlined(img, blade, Color("#d4a359"), Color("#855826"), C_OUTLINE, 2.0)
	return img


static func _draw_rock_mountain() -> Image:
	var img := _new_canvas(160, 160)
	_drop_shadow(img, 80.0, 142.0, 64.0, 18.0, 0.40)

	# Back-left secondary peak
	var bl_left := PackedVector2Array([
		Vector2(14, 134), Vector2(48, 44), Vector2(56, 134)
	])
	var bl_right := PackedVector2Array([
		Vector2(48, 44), Vector2(86, 134), Vector2(56, 134)
	])
	_poly_outlined(img, bl_left, Color("#a39589"), Color("#7d7065"), C_OUTLINE, 2.5)
	_poly_outlined(img, bl_right, Color("#6e6258"), Color("#4f463e"), C_OUTLINE, 2.5)
	var bl_snow := PackedVector2Array([
		Vector2(48, 44), Vector2(64, 82), Vector2(52, 76), Vector2(42, 86), Vector2(33, 80)
	])
	_poly_outlined(img, bl_snow, Color("#ffffff"), Color("#d0e0ec"), C_OUTLINE, 2.2)

	# Back-right secondary peak
	var br_left := PackedVector2Array([
		Vector2(76, 134), Vector2(114, 50), Vector2(118, 134)
	])
	var br_right := PackedVector2Array([
		Vector2(114, 50), Vector2(148, 134), Vector2(118, 134)
	])
	_poly_outlined(img, br_left, Color("#9e9084"), Color("#786b60"), C_OUTLINE, 2.5)
	_poly_outlined(img, br_right, Color("#665a50"), Color("#473e37"), C_OUTLINE, 2.5)
	var br_snow := PackedVector2Array([
		Vector2(114, 50), Vector2(129, 86), Vector2(118, 80), Vector2(108, 88), Vector2(99, 82)
	])
	_poly_outlined(img, br_snow, Color("#ffffff"), Color("#cbdbe8"), C_OUTLINE, 2.2)

	# Tall central main peak with faceted ridge matching land.jpeg top-right
	var m_left := PackedVector2Array([
		Vector2(34, 140), Vector2(80, 18), Vector2(84, 142)
	])
	var m_right := PackedVector2Array([
		Vector2(80, 18), Vector2(130, 140), Vector2(84, 142)
	])
	_poly_outlined(img, m_left, Color("#b0a194"), Color("#85776b"), C_OUTLINE, 2.8)
	_poly_outlined(img, m_right, Color("#73665b"), Color("#524840"), C_OUTLINE, 2.8)

	# Snow cap on main peak (sunlit left facet + cool blue-grey right facet)
	var snow_l := PackedVector2Array([
		Vector2(80, 18), Vector2(82, 76), Vector2(68, 68), Vector2(58, 78)
	])
	var snow_r := PackedVector2Array([
		Vector2(80, 18), Vector2(102, 74), Vector2(92, 66), Vector2(82, 76)
	])
	_poly_outlined(img, snow_l, Color("#ffffff"), Color("#eef6fc"), C_OUTLINE, 2.4)
	_poly_outlined(img, snow_r, Color("#dce8f2"), Color("#b8ccdc"), C_OUTLINE, 2.4)

	# Foreground foothills
	var fh_l := PackedVector2Array([
		Vector2(48, 142), Vector2(72, 92), Vector2(96, 142)
	])
	_poly_outlined(img, fh_l, Color("#96887c"), Color("#63584e"), C_OUTLINE, 2.4)
	return img


static func _draw_coastal_reeds() -> Image:
	var img := _new_canvas(128, 128)
	_aa_ellipse(img, 64.0, 108.0, 32.0, 9.0, Color(0.85, 0.97, 1.0, 0.65))
	var stalks := [42.0, 52.0, 62.0, 72.0, 82.0]
	for idx in range(stalks.size()):
		var sx: float = stalks[idx]
		var top_y: float = 30.0 + float(idx % 2) * 10.0
		var bend: float = -4.0 if idx % 2 == 0 else 4.0
		_aa_line(img, sx, 106.0, sx + bend, top_y, C_OUTLINE, 4.2)
		_aa_line(img, sx, 106.0, sx + bend, top_y, Color("#4da843"), 2.4)
		# Cattail brown cylinder head
		var head := PackedVector2Array([
			Vector2(sx + bend - 3.5, top_y + 8.0),
			Vector2(sx + bend + 3.5, top_y + 8.0),
			Vector2(sx + bend + 3.5, top_y + 24.0),
			Vector2(sx + bend - 3.5, top_y + 24.0)
		])
		_poly_outlined(img, head, Color("#7c4724"), Color("#4f2b14"), C_OUTLINE, 2.0)
	return img


static func _draw_tree_stump() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 30.0, 9.0, 0.35)
	var body := PackedVector2Array([
		Vector2(44, 72), Vector2(84, 72), Vector2(92, 106), Vector2(36, 106)
	])
	_poly_outlined(img, body, Color("#854f2d"), Color("#593119"), C_OUTLINE, 2.4)
	_aa_ellipse_outlined(img, 64.0, 72.0, 20.0, 9.0, Color("#deb887"), C_OUTLINE, 2.4)
	_aa_ellipse(img, 64.0, 72.0, 12.0, 5.0, Color("#b88655"))
	return img


static func _draw_soil_crack() -> Image:
	var img := _new_canvas(128, 128)
	_aa_line(img, 24.0, 68.0, 62.0, 76.0, Color("#3b1f0e"), 3.2)
	_aa_line(img, 62.0, 76.0, 102.0, 58.0, Color("#3b1f0e"), 3.0)
	_aa_line(img, 62.0, 76.0, 76.0, 104.0, Color("#3b1f0e"), 2.6)
	_aa_line(img, 44.0, 72.0, 30.0, 96.0, Color("#593119"), 2.2)
	return img


static func _draw_wildflowers() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 26.0, 8.0, 0.25)
	var spots := [
		{"x": 42.0, "y": 78.0, "c": Color("#ff6b8b")},
		{"x": 64.0, "y": 66.0, "c": Color("#ffd166")},
		{"x": 84.0, "y": 82.0, "c": Color("#70d6ff")},
		{"x": 54.0, "y": 92.0, "c": Color("#ff9f1c")}
	]
	for sp in spots:
		var sx: float = sp["x"]
		var sy: float = sp["y"]
		var fl_col: Color = sp["c"]
		_aa_line(img, sx, sy + 4.0, sx, sy + 20.0, Color("#2d8a4e"), 2.6)
		_aa_circle_outlined(img, sx, sy, 8.0, fl_col, C_OUTLINE, 2.0)
		_aa_circle(img, sx, sy, 3.5, Color("#fff3b0"))
	return img
