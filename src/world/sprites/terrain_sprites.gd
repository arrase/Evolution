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
		"bush_arid":
			return _draw_bush_arid()
		"bush_berry":
			return _draw_bush_berry()
		"fallen_log":
			return _draw_fallen_log()
		"mossy_rock":
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


static func draw_hex_tile(biome: String) -> Image:
	var w := 224
	var h := 192
	var img := _new_canvas(w, h)
	var cx := 112.0
	var cy := 96.0

	match biome:
		"tropical_forest":
			var tones := [
				Color("#1c6e38"),
				Color("#258545"),
				Color("#2f9e53"),
				Color("#3eb864")
			]
			for y in range(h):
				for x in range(w):
					var dist := Vector2((float(x) - cx) / 104.0, (float(y) - cy) / 88.0).length()
					var n := _hash2d(x / 2, y / 2, 11) % 4
					var fine := _hash2d(x, y, 17) % 5
					var idx := clampi(n + (1 if dist < 0.62 else 0) - (1 if dist > 0.86 else 0), 0, 3)
					var col: Color = tones[idx]
					if fine == 0:
						col = col.lightened(0.06)
					elif fine == 1:
						col = col.darkened(0.06)
					_px(img, x, y, col)

			for ms in [
				Vector2i(68, 60), Vector2i(148, 56), Vector2i(56, 120),
				Vector2i(156, 124), Vector2i(110, 96), Vector2i(92, 140)
			]:
				_ellipse(img, ms.x, ms.y, 8, 4, Color("#21783d"))
				_ellipse(img, ms.x + 1, ms.y, 5, 2, Color("#34a856"))

			for i in range(48):
				var fx := 24 + (_hash2d(i, 1, 31) % 176)
				var fy := 20 + (_hash2d(i, 2, 31) % 152)
				if i % 3 == 0:
					_line(img, fx, fy, fx - 3, fy - 2, Color("#124d26"))
					_line(img, fx, fy, fx + 3, fy - 2, Color("#124d26"))
					_line(img, fx, fy - 1, fx - 2, fy - 3, Color("#52d173"))
					_line(img, fx, fy - 1, fx + 2, fy - 3, Color("#52d173"))
					_px(img, fx, fy - 2, Color("#7ae582"))
				elif i % 3 == 1:
					var fl_col := Color("#ff6b8b") if i % 2 == 0 else Color("#ffd166")
					_px(img, fx, fy + 1, Color("#1b6332"))
					_px(img, fx - 1, fy, fl_col)
					_px(img, fx + 1, fy, fl_col)
					_px(img, fx, fy - 1, fl_col)
					_px(img, fx, fy, Color("#fff8d6"))
				else:
					_ellipse(img, fx, fy, 2, 1, Color("#576066"))
					_px(img, fx, fy - 1, Color("#49c468"))

		"savanna":
			var tones := [
				Color("#ab7e24"),
				Color("#c4932d"),
				Color("#d9ab3b"),
				Color("#e8be4e")
			]
			for y in range(h):
				for x in range(w):
					var dist := Vector2((float(x) - cx) / 104.0, (float(y) - cy) / 88.0).length()
					var wave := int(sin(float(x) * 0.10 + float(y) * 0.06) * 1.5)
					var n := (_hash2d(x / 2, y / 2, 23) + wave) % 4
					var idx := clampi(abs(n) + (1 if dist < 0.58 else 0), 0, 3)
					var col: Color = tones[idx]
					if _hash2d(x, y, 29) % 6 == 0:
						col = col.lightened(0.07)
					_px(img, x, y, col)

			for dp in [
				Vector2i(72, 72), Vector2i(148, 112), Vector2i(88, 128), Vector2i(136, 64)
			]:
				_ellipse(img, dp.x, dp.y, 7, 3, Color("#bd8b28"))

			for i in range(54):
				var gx := 20 + (_hash2d(i, 3, 41) % 184)
				var gy := 18 + (_hash2d(i, 4, 41) % 156)
				if i % 3 != 0:
					_line(img, gx, gy, gx - 1, gy - 3, Color("#8c6518"))
					_line(img, gx + 1, gy, gx + 2, gy - 4, Color("#f2d06b"))
					_px(img, gx, gy - 2, Color("#e3b646"))
				else:
					_ellipse(img, gx, gy, 3, 2, Color("#8f4426"))
					_px(img, gx - 1, gy - 1, Color("#b85d38"))

		"arid_steppe":
			var tones := [
				Color("#b86628"),
				Color("#cc7735"),
				Color("#de8b47"),
				Color("#eda05c")
			]
			for y in range(h):
				for x in range(w):
					var ripple := sin(float(y) * 0.28 + sin(float(x) * 0.06) * 2.2)
					var idx := 1
					if ripple > 0.55:
						idx = 3
					elif ripple > 0.0:
						idx = 2
					elif ripple < -0.55:
						idx = 0
					if _hash2d(x, y, 53) % 5 == 0:
						idx = clampi(idx + 1, 0, 3)
					_px(img, x, y, tones[idx])

			for i in range(56):
				var sx := 24 + (_hash2d(i, 5, 61) % 176)
				var sy := 20 + (_hash2d(i, 6, 61) % 152)
				if i % 4 == 0:
					_line(img, sx - 4, sy, sx + 3, sy + 2, Color("#6e3819"))
					_line(img, sx, sy + 1, sx + 2, sy + 4, Color("#6e3819"))
				elif i % 2 == 0:
					_ellipse(img, sx, sy, 3, 2, Color("#7d4122"))
					_px(img, sx, sy - 1, Color("#a65a32"))
				else:
					_px(img, sx, sy, Color("#687530"))
					_px(img, sx - 1, sy - 1, Color("#83913f"))
					_px(img, sx + 1, sy - 1, Color("#83913f"))

		"tundra":
			var tones := [
				Color("#9eb6c4"),
				Color("#b8cedb"),
				Color("#d2e3ed"),
				Color("#eaf4f8")
			]
			for y in range(h):
				for x in range(w):
					var dist := Vector2((float(x) - cx) / 104.0, (float(y) - cy) / 88.0).length()
					var n := _hash2d(x / 2, y / 2, 71) % 4
					var idx := clampi(n + (1 if dist < 0.65 else 0), 0, 3)
					_px(img, x, y, tones[idx])

			for mp in [
				Vector2i(68, 68), Vector2i(144, 72), Vector2i(96, 124), Vector2i(128, 52)
			]:
				_ellipse(img, mp.x, mp.y, 8, 4, Color("#a5bfd0"))

			for i in range(40):
				var ix := 24 + (_hash2d(i, 7, 79) % 176)
				var iy := 20 + (_hash2d(i, 8, 79) % 152)
				if i % 2 == 0:
					_px(img, ix, iy, Color("#ffffff"))
					_px(img, ix - 1, iy, Color("#7dd3fc"))
					_px(img, ix + 1, iy, Color("#7dd3fc"))
					_px(img, ix, iy - 1, Color("#38bdf8"))
					_px(img, ix, iy + 1, Color("#38bdf8"))
				else:
					_ellipse(img, ix, iy, 3, 2, Color("#475569"))
					_px(img, ix, iy - 1, Color("#e2e8f0"))

		"high_mountain":
			var tones := [
				Color("#524e4a"),
				Color("#69645f"),
				Color("#807a74"),
				Color("#99928b")
			]
			for y in range(h):
				for x in range(w):
					var band := ((y + int(sin(float(x) * 0.08) * 5.0)) / 9) % 4
					var n := _hash2d(x, y, 89) % 4
					var idx := clampi((band + (1 if n > 2 else 0)) % 4, 0, 3)
					_px(img, x, y, tones[idx])

			var snow_caps := [
				Vector2i(92, 56), Vector2i(132, 68), Vector2i(108, 104),
				Vector2i(72, 96), Vector2i(148, 116), Vector2i(68, 132)
			]
			for sc in snow_caps:
				_ellipse(img, sc.x, sc.y, 15, 7, Color("#cbd5e1"))
				_ellipse(img, sc.x, sc.y - 1, 11, 4, Color("#f1f5f9"))

			for i in range(38):
				var rx := 26 + (_hash2d(i, 9, 97) % 172)
				var ry := 24 + (_hash2d(i, 10, 97) % 144)
				_line(img, rx - 4, ry, rx + 4, ry + 1, Color("#2e2b29"))
				_line(img, rx - 3, ry - 1, rx + 3, ry, Color("#b5afa8"))

		"coastal_shallows":
			for y in range(h):
				for x in range(w):
					var d := Vector2((float(x) - cx) / 96.0, (float(y) - cy) / 80.0).length()
					var jitter := float(_hash2d(x / 2, y / 2, 103) % 10) * 0.018
					var dj := d + jitter
					var col := Color("#258f86")
					if dj < 0.50:
						col = Color("#ebd294") if _hash2d(x, y, 107) % 3 == 0 else Color("#d9be7e")
					elif dj < 0.60:
						col = Color("#c2a361")
					elif dj < 0.68:
						col = Color("#e0f7fa")
					elif dj < 0.84:
						col = Color("#45c4b8") if _hash2d(x, y, 109) % 2 == 0 else Color("#32a89d")
					_px(img, x, y, col)

			var shells := [
				Vector2i(96, 84), Vector2i(128, 100), Vector2i(84, 108),
				Vector2i(116, 72), Vector2i(74, 86), Vector2i(138, 82)
			]
			for idx in range(shells.size()):
				var sp: Vector2i = shells[idx]
				if idx % 2 == 0:
					_px(img, sp.x, sp.y, Color("#fb923c"))
					_px(img, sp.x - 1, sp.y, Color("#f97316"))
					_px(img, sp.x + 1, sp.y, Color("#f97316"))
					_px(img, sp.x, sp.y - 1, Color("#f97316"))
					_px(img, sp.x, sp.y + 1, Color("#f97316"))
				else:
					_rect(img, sp.x - 1, sp.y - 1, 3, 2, Color("#ff9ebb"))
					_px(img, sp.x, sp.y, Color("#ffe3ec"))

		_:
			var tones := [
				Color("#134263"),
				Color("#19547d"),
				Color("#216899"),
				Color("#2b7bb3")
			]
			for y in range(h):
				for x in range(w):
					var wave := sin(float(x) * 0.11 + float(y) * 0.15)
					var idx := 1
					if wave > 0.55:
						idx = 3
					elif wave > 0.0:
						idx = 2
					elif wave < -0.55:
						idx = 0
					_px(img, x, y, tones[idx])
			for i in range(36):
				var wx := 24 + (_hash2d(i, 11, 131) % 176)
				var wy := 20 + (_hash2d(i, 12, 131) % 152)
				_line(img, wx - 5, wy, wx + 5, wy, Color("#7dd3fc"))
				_line(img, wx - 3, wy - 1, wx + 3, wy - 1, Color("#e0f2fe"))

	return img


static func _draw_tree_tropical() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 10, 3, C_SHADOW)
	_rect(img, 16, 20, 4, 12, Color("#6e3f23"))
	_rect(img, 17, 20, 2, 12, Color("#8c5330"))
	_line(img, 15, 27, 12, 32, Color("#593119"))
	_line(img, 20, 27, 23, 32, Color("#593119"))
	_circle(img, 18, 15, 11, Color("#0f5e36"))
	_circle(img, 12, 17, 7, Color("#147543"))
	_circle(img, 24, 17, 7, Color("#11663b"))
	_circle(img, 18, 12, 9, Color("#1d9454"))
	_circle(img, 15, 9, 6, Color("#34b86a"))
	_circle(img, 22, 13, 5, Color("#27a65c"))
	_line(img, 10, 20, 10, 26, Color("#1d8049"))
	_line(img, 25, 20, 25, 25, Color("#1d8049"))
	_px(img, 13, 10, Color("#ff6b8b"))
	_px(img, 14, 10, Color("#ffd166"))
	_px(img, 22, 14, Color("#ff6b8b"))
	_px(img, 21, 14, Color("#ffd166"))
	_px(img, 17, 17, Color("#ff9f1c"))
	_apply_soft_outline(img, Color("#172617"))
	return img


static func _draw_tree_tropical_2() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 9, 3, C_SHADOW)
	for y in range(13, 32):
		var curve_x := 18 + int(sin(float(y - 13) * 0.18) * 2.5)
		_rect(img, curve_x - 2, y, 4, 1, Color("#7c4728") if y % 2 == 0 else Color("#995b36"))
	_circle(img, 16, 13, 2, Color("#5c3317"))
	_circle(img, 20, 13, 2, Color("#6b3e26"))
	var frond_tips := [
		Vector2i(5, 14), Vector2i(8, 7), Vector2i(18, 3),
		Vector2i(28, 7), Vector2i(31, 14), Vector2i(10, 20), Vector2i(26, 20)
	]
	for tip in frond_tips:
		_line(img, 18, 11, tip.x, tip.y, Color("#16703d"))
		_line(img, 18, 10, tip.x, tip.y - 1, Color("#2eb865"))
		_line(img, 18, 12, tip.x, tip.y + 1, Color("#1e8f4e"))
	_circle(img, 18, 10, 4, Color("#4ad67d"))
	_apply_soft_outline(img, Color("#142618"))
	return img


static func _draw_tree_savanna() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 10, 3, C_SHADOW)
	_line(img, 17, 31, 18, 18, Color("#6b3e26"))
	_line(img, 18, 31, 19, 18, Color("#8a5232"))
	_line(img, 18, 19, 11, 13, Color("#6b3e26"))
	_line(img, 19, 19, 26, 14, Color("#6b3e26"))
	_ellipse(img, 18, 12, 14, 4, Color("#6e7821"))
	_ellipse(img, 18, 11, 12, 3, Color("#8fa329"))
	_ellipse(img, 16, 9, 9, 2, Color("#b8c93a"))
	_ellipse(img, 25, 14, 7, 2, Color("#7d8c24"))
	_ellipse(img, 10, 14, 7, 2, Color("#9eb32d"))
	_apply_soft_outline(img, Color("#292111"))
	return img


static func _draw_tree_savanna_2() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 10, 3, C_SHADOW)
	for y in range(15, 32):
		var hw := 3 + int(float(y - 15) * 0.22)
		_rect(img, 18 - hw, y, hw * 2 + 1, 1, Color("#8a5a3c") if y % 3 != 0 else Color("#70472e"))
		_rect(img, 18 - hw + 1, y, hw, 1, Color("#a36d4b"))
	_ellipse(img, 12, 13, 6, 4, Color("#7d8c24"))
	_ellipse(img, 24, 13, 6, 4, Color("#6e7821"))
	_ellipse(img, 18, 10, 8, 5, Color("#9eb32d"))
	_ellipse(img, 17, 9, 5, 3, Color("#c5d945"))
	_apply_soft_outline(img, Color("#292111"))
	return img


static func _draw_tree_tundra() -> Image:
	var img := _new_canvas(32, 34)
	_ellipse(img, 16, 30, 8, 2, C_SHADOW)
	_rect(img, 15, 24, 3, 6, Color("#4f311c"))
	for tier in range(3):
		var top_y: int = 4 + tier * 6
		var half_w: int = 5 + tier * 3
		for row in range(8):
			var w_row: int = int(float(row) / 7.0 * float(half_w))
			var py: int = top_y + row
			for dx in range(-w_row, w_row + 1):
				var col := Color("#1e4d3b") if dx > 0 else Color("#2b6951")
				if row <= 2 or (row == 3 and (dx + tier) % 2 == 0):
					col = Color("#eef6fa") if dx <= 0 else Color("#cbe0ec")
				_px(img, 16 + dx, py, col)
	_apply_soft_outline(img, Color("#162429"))
	return img


static func _draw_tree_tundra_2() -> Image:
	var img := _new_canvas(32, 34)
	_ellipse(img, 16, 30, 9, 2, C_SHADOW)
	for idx in range(2):
		var cx := 11 if idx == 0 else 21
		var top_y := 6 if idx == 0 else 10
		_rect(img, cx - 1, 25, 2, 5, Color("#4f311c"))
		for row in range(19 - idx * 3):
			var hw := 1 + int(float(row) * 0.34)
			var py := top_y + row
			for dx in range(-hw, hw + 1):
				var col := Color("#245945") if dx <= 0 else Color("#194233")
				if row % 5 <= 1:
					col = Color("#f0f7fa") if dx <= 0 else Color("#c8dfeb")
				_px(img, cx + dx, py, col)
	_apply_soft_outline(img, Color("#162429"))
	return img


static func _draw_bush_arid() -> Image:
	var img := _new_canvas(26, 26)
	_ellipse(img, 13, 22, 7, 2, C_SHADOW)
	_rect(img, 11, 7, 4, 15, Color("#3a7d44"))
	_rect(img, 12, 7, 2, 15, Color("#52a35d"))
	_rect(img, 7, 11, 4, 3, Color("#3a7d44"))
	_rect(img, 7, 8, 3, 4, Color("#52a35d"))
	_rect(img, 15, 13, 4, 3, Color("#3a7d44"))
	_rect(img, 16, 10, 3, 4, Color("#3a7d44"))
	_px(img, 12, 6, Color("#ff5964"))
	_px(img, 13, 6, Color("#ffe74c"))
	_ellipse(img, 18, 20, 4, 2, Color("#9c662c"))
	_px(img, 17, 19, Color("#c48b3f"))
	_apply_soft_outline(img, Color("#241b10"))
	return img


static func _draw_bush_berry() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 20, 8, 2, C_SHADOW)
	_circle(img, 9, 15, 5, Color("#156134"))
	_circle(img, 15, 15, 5, Color("#12522b"))
	_circle(img, 12, 12, 6, Color("#1f8749"))
	_circle(img, 11, 11, 4, Color("#34b364"))
	var berries := [
		Vector2i(8, 13), Vector2i(14, 11), Vector2i(11, 15),
		Vector2i(16, 15), Vector2i(10, 10)
	]
	for b in berries:
		_px(img, b.x, b.y, Color("#ef4444"))
		_px(img, b.x + 1, b.y, Color("#dc2626"))
		_px(img, b.x, b.y - 1, Color("#fca5a5"))
	_apply_soft_outline(img, Color("#142617"))
	return img


static func _draw_fallen_log() -> Image:
	var img := _new_canvas(28, 20)
	_ellipse(img, 14, 16, 11, 2, C_SHADOW)
	_rect(img, 5, 10, 18, 6, Color("#6e3f23"))
	_rect(img, 5, 11, 18, 2, Color("#8c5330"))
	_ellipse(img, 5, 13, 2, 3, Color("#d4a373"))
	_px(img, 5, 13, Color("#3d2314"))
	_ellipse(img, 23, 13, 2, 3, Color("#4a2c18"))
	_rect(img, 8, 9, 9, 2, Color("#2d9447"))
	_rect(img, 10, 8, 5, 1, Color("#4cc470"))
	_px(img, 19, 8, Color("#fefae0"))
	_rect(img, 18, 6, 3, 2, Color("#ef4444"))
	_px(img, 19, 6, Color("#ffffff"))
	_apply_soft_outline(img, C_OUTLINE)
	return img


static func _draw_mossy_rock() -> Image:
	var img := _new_canvas(26, 22)
	_ellipse(img, 13, 18, 9, 2, C_SHADOW)
	_ellipse(img, 13, 14, 8, 5, Color("#64686e"))
	_ellipse(img, 12, 13, 6, 4, Color("#848991"))
	_ellipse(img, 11, 11, 5, 2, Color("#34a853"))
	_ellipse(img, 12, 10, 3, 1, Color("#5ce07a"))
	_px(img, 16, 14, Color("#ffd166"))
	_apply_soft_outline(img, Color("#22252a"))
	return img


static func _draw_tall_grass() -> Image:
	var img := _new_canvas(20, 20)
	var blades := [4, 7, 10, 13, 16]
	for i in range(blades.size()):
		var bx: int = blades[i]
		var top_y: int = 5 + (i % 2) * 2
		var bend: int = -1 if i % 2 == 0 else 1
		_line(img, bx, 17, bx + bend, top_y, Color("#248243"))
		_line(img, bx + 1, 17, bx + bend + 1, top_y + 1, Color("#46bf6b"))
		_px(img, bx + bend, top_y - 1, Color("#eab308"))
	_apply_soft_outline(img, Color("#152e1c"))
	return img


static func _draw_dry_scrub() -> Image:
	var img := _new_canvas(22, 20)
	_ellipse(img, 11, 17, 6, 2, C_SHADOW)
	_line(img, 11, 16, 6, 9, Color("#784b27"))
	_line(img, 11, 16, 16, 8, Color("#784b27"))
	_line(img, 11, 16, 11, 7, Color("#996236"))
	_line(img, 9, 13, 5, 12, Color("#996236"))
	_line(img, 13, 12, 17, 11, Color("#996236"))
	_apply_soft_outline(img, Color("#2b1b0e"))
	return img


static func _draw_rock_mountain() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 27, 10, 3, C_SHADOW)
	for y in range(8, 27):
		var progress := float(y - 8) / 18.0
		var half_w := int(2.0 + progress * 9.0)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#6c6965")
			if dx < -2:
				col = Color("#8c8781")
			elif dx > 2:
				col = Color("#4f4c49")
			if y < 14 + (abs(dx) % 2):
				col = Color("#f4f9fc") if dx <= 0 else Color("#cfe0eb")
			_px(img, 16 + dx, y, col)
	_apply_soft_outline(img, Color("#242220"))
	return img


static func _draw_coastal_reeds() -> Image:
	var img := _new_canvas(24, 24)
	var stalks := [7, 10, 13, 16]
	for idx in range(stalks.size()):
		var sx: int = stalks[idx]
		var top_y: int = 6 + (idx % 2) * 2
		_line(img, sx, 20, sx, top_y, Color("#3d8c40"))
		_rect(img, sx - 1, top_y + 1, 2, 4, Color("#6b3e26"))
	_rect(img, 15, 18, 4, 3, Color("#ff9ebb"))
	_px(img, 16, 19, Color("#ffd6e0"))
	_apply_soft_outline(img, Color("#1d2b1f"))
	return img


static func _draw_tree_stump() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 19, 7, 2, C_SHADOW)
	_rect(img, 7, 13, 10, 6, Color("#6e3f23"))
	_rect(img, 8, 13, 4, 6, Color("#854f2d"))
	_px(img, 6, 18, Color("#593119"))
	_px(img, 17, 18, Color("#593119"))
	_ellipse(img, 12, 13, 5, 2, Color("#deb887"))
	_ellipse(img, 12, 13, 3, 1, Color("#b88655"))
	_px(img, 12, 13, Color("#6e3f23"))
	_apply_soft_outline(img, C_OUTLINE)
	return img


static func _draw_soil_crack() -> Image:
	var img := _new_canvas(24, 24)
	_line(img, 4, 12, 11, 14, Color("#3b1f0e"))
	_line(img, 11, 14, 19, 10, Color("#3b1f0e"))
	_line(img, 11, 14, 14, 20, Color("#3b1f0e"))
	_line(img, 8, 13, 5, 18, Color("#593119"))
	_line(img, 4, 11, 11, 13, Color("#8a5432"))
	return img


static func _draw_wildflowers() -> Image:
	var img := _new_canvas(24, 24)
	var spots := [
		{"x": 7, "y": 14, "c": Color("#ff6b8b")},
		{"x": 13, "y": 11, "c": Color("#ffd166")},
		{"x": 17, "y": 15, "c": Color("#70d6ff")},
		{"x": 10, "y": 18, "c": Color("#ff9f1c")}
	]
	for sp in spots:
		var sx: int = sp["x"]
		var sy: int = sp["y"]
		var fl_col: Color = sp["c"]
		_line(img, sx, sy + 1, sx, sy + 4, Color("#2d8a4e"))
		_px(img, sx - 1, sy, fl_col)
		_px(img, sx + 1, sy, fl_col)
		_px(img, sx, sy - 1, fl_col)
		_px(img, sx, sy + 1, fl_col)
		_px(img, sx, sy, Color("#fff3b0"))
	return img
