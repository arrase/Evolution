class_name EvoPixelCanvas
extends RefCounted

const C_OUTLINE := Color("#23150c")


static func _new_canvas(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _hash2d(x: int, y: int, seed_val: int = 0) -> int:
	var h: int = (x * 374761393) + (y * 668265263) + (seed_val * 1442695041)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


static func _value_noise2d(x: float, y: float, seed_val: int) -> float:
	var ix := int(floor(x))
	var iy := int(floor(y))
	var fx := x - float(ix)
	var fy := y - float(iy)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var n00 := float(_hash2d(ix, iy, seed_val) & 1023) / 1023.0
	var n10 := float(_hash2d(ix + 1, iy, seed_val) & 1023) / 1023.0
	var n01 := float(_hash2d(ix, iy + 1, seed_val) & 1023) / 1023.0
	var n11 := float(_hash2d(ix + 1, iy + 1, seed_val) & 1023) / 1023.0
	return lerpf(lerpf(n00, n10, ux), lerpf(n01, n11, ux), uy)


static func _fbm2d(x: float, y: float, seed_val: int) -> float:
	var v := _value_noise2d(x, y, seed_val) * 0.58
	v += _value_noise2d(x * 2.07 + 13.7, y * 2.07 + 7.3, seed_val + 31) * 0.29
	v += _value_noise2d(x * 4.31 + 29.1, y * 4.31 + 19.4, seed_val + 73) * 0.13
	return v


static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, col)


static func _blend_px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height() or col.a <= 0.001:
		return
	if col.a >= 0.995:
		img.set_pixel(x, y, col)
		return
	var dst := img.get_pixel(x, y)
	if dst.a <= 0.001:
		img.set_pixel(x, y, col)
		return
	var out_a := col.a + dst.a * (1.0 - col.a)
	var inv_a := 1.0 / maxf(0.0001, out_a)
	var r := (col.r * col.a + dst.r * dst.a * (1.0 - col.a)) * inv_a
	var g := (col.g * col.a + dst.g * dst.a * (1.0 - col.a)) * inv_a
	var b := (col.b * col.a + dst.b * dst.a * (1.0 - col.a)) * inv_a
	img.set_pixel(x, y, Color(r, g, b, out_a))


static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var x0 := maxi(0, x)
	var y0 := maxi(0, y)
	var x1 := mini(img.get_width(), x + w)
	var y1 := mini(img.get_height(), y + h)
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), col)


static func _rect_outlined(img: Image, x: int, y: int, w: int, h: int, fill: Color, outline: Color = C_OUTLINE) -> void:
	_rect(img, x, y, w, h, fill)
	for px_i in range(x, x + w):
		_px(img, px_i, y, outline)
		_px(img, px_i, y + h - 1, outline)
	for py in range(y, y + h):
		_px(img, x, py, outline)
		_px(img, x + w - 1, py, outline)


static func _drop_shadow(img: Image, cx: float, cy: float, rx: float, ry: float, alpha: float = 0.34) -> void:
	if rx <= 0.5 or ry <= 0.5:
		return
	var scx := cx + rx * 0.10
	var scy := cy + ry * 0.08
	var w := img.get_width()
	var h := img.get_height()
	var y0 := maxi(0, int(floor(scy - ry - 1.0)))
	var y1 := mini(h - 1, int(ceil(scy + ry + 1.0)))
	var x0 := maxi(0, int(floor(scx - rx - 1.0)))
	var x1 := mini(w - 1, int(ceil(scx + rx + 1.0)))
	for py in range(y0, y1 + 1):
		var ny := (float(py) - scy) / ry
		var ny2 := ny * ny
		if ny2 >= 1.0:
			continue
		for px_i in range(x0, x1 + 1):
			var nx := (float(px_i) - scx) / rx
			var d2 := nx * nx + ny2
			if d2 < 1.0:
				var falloff := 1.0 - sqrt(d2)
				var smooth_a := alpha * clampf(falloff * falloff * 2.1, 0.0, 1.0)
				_blend_px(img, px_i, py, Color(0.05, 0.03, 0.02, smooth_a))


static func _aa_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	if r <= 0.0:
		return
	var w := img.get_width()
	var h := img.get_height()
	var y0 := maxi(0, int(floor(cy - r - 1.0)))
	var y1 := mini(h - 1, int(ceil(cy + r + 1.0)))
	var r_outer := r + 0.75
	var r_inner := maxf(0.0, r - 0.75)
	var r_inner2 := r_inner * r_inner
	var r_outer2 := r_outer * r_outer
	for py in range(y0, y1 + 1):
		var dy := float(py) - cy
		var dy2 := dy * dy
		if dy2 >= r_outer2:
			continue
		var max_dx := sqrt(r_outer2 - dy2)
		var x0 := maxi(0, int(floor(cx - max_dx)))
		var x1 := mini(w - 1, int(ceil(cx + max_dx)))
		if col.a >= 0.995 and dy2 < r_inner2:
			var in_dx := sqrt(r_inner2 - dy2)
			var ix0 := maxi(x0, int(ceil(cx - in_dx)))
			var ix1 := mini(x1, int(floor(cx + in_dx)))
			if ix1 >= ix0:
				img.fill_rect(Rect2i(ix0, py, ix1 - ix0 + 1, 1), col)
				for px_i in range(x0, ix0):
					var d := sqrt((float(px_i) - cx) * (float(px_i) - cx) + dy2)
					var cov := clampf(r + 0.5 - d, 0.0, 1.0)
					if cov > 0.0:
						_blend_px(img, px_i, py, Color(col.r, col.g, col.b, col.a * cov))
				for px_i in range(ix1 + 1, x1 + 1):
					var d := sqrt((float(px_i) - cx) * (float(px_i) - cx) + dy2)
					var cov := clampf(r + 0.5 - d, 0.0, 1.0)
					if cov > 0.0:
						_blend_px(img, px_i, py, Color(col.r, col.g, col.b, col.a * cov))
				continue
		for px_i in range(x0, x1 + 1):
			var d := sqrt((float(px_i) - cx) * (float(px_i) - cx) + dy2)
			var cov := clampf(r + 0.5 - d, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, px_i, py, Color(col.r, col.g, col.b, col.a * cov))


static func _aa_circle_outlined(
	img: Image,
	cx: float,
	cy: float,
	r: float,
	fill_col: Color,
	outline_col: Color = C_OUTLINE,
	outline_w: float = 2.0
) -> void:
	_aa_circle(img, cx, cy, r + outline_w * 0.5, outline_col)
	_aa_circle(img, cx, cy, maxf(0.5, r - outline_w * 0.5), fill_col)


static func _aa_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.2 or ry <= 0.2:
		return
	var w := img.get_width()
	var h := img.get_height()
	var y0 := maxi(0, int(floor(cy - ry - 1.5)))
	var y1 := mini(h - 1, int(ceil(cy + ry + 1.5)))
	var x0 := maxi(0, int(floor(cx - rx - 1.5)))
	var x1 := mini(w - 1, int(ceil(cx + rx + 1.5)))
	var avg_r := (rx + ry) * 0.5
	var feather := 1.0 / maxf(1.0, avg_r)
	for py in range(y0, y1 + 1):
		var ny := (float(py) - cy) / ry
		var ny2 := ny * ny
		if ny2 > 1.25:
			continue
		for px_i in range(x0, x1 + 1):
			var nx := (float(px_i) - cx) / rx
			var dist := sqrt(nx * nx + ny2)
			var cov := clampf((1.0 + feather * 0.5 - dist) / feather, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, px_i, py, Color(col.r, col.g, col.b, col.a * cov))


static func _aa_ellipse_outlined(
	img: Image,
	cx: float,
	cy: float,
	rx: float,
	ry: float,
	fill_col: Color,
	outline_col: Color = C_OUTLINE,
	outline_w: float = 2.0
) -> void:
	_aa_ellipse(img, cx, cy, rx + outline_w * 0.5, ry + outline_w * 0.5, outline_col)
	_aa_ellipse(img, cx, cy, maxf(0.5, rx - outline_w * 0.5), maxf(0.5, ry - outline_w * 0.5), fill_col)


static func _aa_line(
	img: Image,
	x0: float,
	y0: float,
	x1: float,
	y1: float,
	col: Color,
	thickness: float = 2.0
) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var hw := maxf(0.5, thickness * 0.5)
	var pad := hw + 1.0
	var min_y := maxi(0, int(floor(minf(y0, y1) - pad)))
	var max_y := mini(h - 1, int(ceil(maxf(y0, y1) + pad)))
	var ab := Vector2(x1 - x0, y1 - y0)
	var ab_len2 := ab.length_squared()
	var dy := y1 - y0
	var abs_dy := absf(dy)

	for py in range(min_y, max_y + 1):
		var fy := float(py)
		var row_min_x: float
		var row_max_x: float
		if abs_dy < 0.5:
			row_min_x = minf(x0, x1) - pad
			row_max_x = maxf(x0, x1) + pad
		else:
			var t_a := clampf((fy - pad - y0) / dy, 0.0, 1.0)
			var t_b := clampf((fy + pad - y0) / dy, 0.0, 1.0)
			var xa := x0 + t_a * ab.x
			var xb := x0 + t_b * ab.x
			row_min_x = minf(xa, xb) - pad
			row_max_x = maxf(xa, xb) + pad

		var ix0 := maxi(0, int(floor(row_min_x)))
		var ix1 := mini(w - 1, int(ceil(row_max_x)))
		for px_i in range(ix0, ix1 + 1):
			var p := Vector2(float(px_i), fy)
			var ap := p - Vector2(x0, y0)
			var t := clampf(ap.dot(ab) / ab_len2, 0.0, 1.0) if ab_len2 > 0.0001 else 0.0
			var closest := Vector2(x0, y0) + ab * t
			var d := p.distance_to(closest)
			var cov := clampf(hw + 0.5 - d, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, px_i, py, Color(col.r, col.g, col.b, col.a * cov))


static func _poly_filled(img: Image, points: PackedVector2Array, top_col: Color, bot_col: Color) -> void:
	var n := points.size()
	if n < 3:
		return
	var w := img.get_width()
	var h := img.get_height()
	var min_y := float(h)
	var max_y := 0.0
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	var y0 := maxi(0, int(floor(min_y)))
	var y1 := mini(h - 1, int(ceil(max_y)))
	var span_y := maxf(1.0, max_y - min_y)

	for py in range(y0, y1 + 1):
		var fy := float(py) + 0.5
		var nodes: Array[float] = []
		var j := n - 1
		for i in range(n):
			var pi := points[i]
			var pj := points[j]
			if (pi.y < fy and pj.y >= fy) or (pj.y < fy and pi.y >= fy):
				var ix := pi.x + (fy - pi.y) / (pj.y - pi.y) * (pj.x - pi.x)
				nodes.append(ix)
			j = i
		if nodes.size() < 2:
			continue
		nodes.sort()
		var t_grad := clampf((fy - min_y) / span_y, 0.0, 1.0)
		var row_col := top_col.lerp(bot_col, t_grad)
		var k := 0
		while k + 1 < nodes.size():
			var x_left := nodes[k]
			var x_right := nodes[k + 1]
			var ix_l := int(floor(x_left))
			var ix_r := int(floor(x_right))
			if ix_l == ix_r:
				var cov := clampf(x_right - x_left, 0.0, 1.0)
				_blend_px(img, ix_l, py, Color(row_col.r, row_col.g, row_col.b, row_col.a * cov))
			else:
				var cov_l := clampf(float(ix_l + 1) - x_left, 0.0, 1.0)
				if cov_l > 0.0:
					_blend_px(img, ix_l, py, Color(row_col.r, row_col.g, row_col.b, row_col.a * cov_l))
				var span_start := maxi(0, ix_l + 1)
				var span_end := mini(w - 1, ix_r - 1)
				if span_end >= span_start:
					if row_col.a >= 0.995:
						img.fill_rect(Rect2i(span_start, py, span_end - span_start + 1, 1), row_col)
					else:
						for px_i in range(span_start, span_end + 1):
							_blend_px(img, px_i, py, row_col)
				var cov_r := clampf(x_right - float(ix_r), 0.0, 1.0)
				if cov_r > 0.0:
					_blend_px(img, ix_r, py, Color(row_col.r, row_col.g, row_col.b, row_col.a * cov_r))
			k += 2


static func _poly_outlined(
	img: Image,
	points: PackedVector2Array,
	top_col: Color,
	bot_col: Color,
	outline_col: Color = C_OUTLINE,
	outline_w: float = 2.2
) -> void:
	_poly_filled(img, points, top_col, bot_col)
	if outline_w <= 0.0:
		return
	var n := points.size()
	for i in range(n):
		var a := points[i]
		var b := points[(i + 1) % n]
		_aa_line(img, a.x, a.y, b.x, b.y, outline_col, outline_w)


static func _draw_isometric_box(
	img: Image,
	cx: float,
	cy: float,
	w: float,
	d: float,
	h: float,
	top_col: Color,
	left_col: Color,
	right_col: Color,
	outline_w: float = 2.2
) -> void:
	var b_front := Vector2(cx, cy)
	var b_left := Vector2(cx - w, cy - w * 0.5)
	var b_right := Vector2(cx + d, cy - d * 0.5)
	var b_back := Vector2(cx + d - w, cy - (w + d) * 0.5)

	var t_front := b_front + Vector2(0.0, -h)
	var t_left := b_left + Vector2(0.0, -h)
	var t_right := b_right + Vector2(0.0, -h)
	var t_back := b_back + Vector2(0.0, -h)

	if h > 0.5:
		var left_face := PackedVector2Array([t_left, t_front, b_front, b_left])
		_poly_filled(img, left_face, left_col.lightened(0.08), left_col.darkened(0.09))

		var right_face := PackedVector2Array([t_front, t_right, b_right, b_front])
		_poly_filled(img, right_face, right_col.lightened(0.02), right_col.darkened(0.15))

		_aa_line(img, t_front.x - 1.2, t_front.y + 1.0, b_front.x - 1.2, b_front.y - 1.0, Color(1.0, 0.97, 0.88, 0.24), 1.8)

		if outline_w > 0.0:
			_aa_line(img, b_left.x, b_left.y, b_front.x, b_front.y, C_OUTLINE, outline_w)
			_aa_line(img, b_front.x, b_front.y, b_right.x, b_right.y, C_OUTLINE, outline_w)
			_aa_line(img, t_left.x, t_left.y, b_left.x, b_left.y, C_OUTLINE, outline_w)
			_aa_line(img, t_front.x, t_front.y, b_front.x, b_front.y, C_OUTLINE, outline_w * 0.92)
			_aa_line(img, t_right.x, t_right.y, b_right.x, b_right.y, C_OUTLINE, outline_w)

	var top_face := PackedVector2Array([t_back, t_right, t_front, t_left])
	_poly_outlined(img, top_face, top_col.lightened(0.08), top_col.darkened(0.04), C_OUTLINE, outline_w)


static func _draw_pitched_roof(
	img: Image,
	cx: float,
	cy: float,
	w: float,
	d: float,
	roof_h: float,
	left_slope_col: Color,
	right_slope_col: Color,
	gable_col: Color,
	outline_w: float = 2.2
) -> void:
	var e_front := Vector2(cx, cy)
	var e_left := Vector2(cx - w, cy - w * 0.5)
	var e_right := Vector2(cx + d, cy - d * 0.5)
	var e_back := Vector2(cx + d - w, cy - (w + d) * 0.5)

	var p_front := Vector2(cx - w * 0.5, cy - w * 0.25 - roof_h)
	var p_back := p_front + Vector2(d, -d * 0.5)

	# Cast eave shadow onto the upper walls below the roof overhang
	var shadow_r := PackedVector2Array([
		e_front, e_right, e_right + Vector2(-2.0, 6.0), e_front + Vector2(0.0, 6.5)
	])
	_poly_filled(img, shadow_r, Color(0.07, 0.04, 0.02, 0.36), Color(0.07, 0.04, 0.02, 0.06))
	var shadow_l := PackedVector2Array([
		e_left + Vector2(2.0, 1.0), e_front, e_front + Vector2(0.0, 5.0), e_left + Vector2(2.0, 5.0)
	])
	_poly_filled(img, shadow_l, Color(0.07, 0.04, 0.02, 0.26), Color(0.07, 0.04, 0.02, 0.04))

	# Back-left sunlit slope (135 deg top-left light)
	var left_slope := PackedVector2Array([e_left, e_back, p_back, p_front])
	_poly_outlined(img, left_slope, left_slope_col.lightened(0.10), left_slope_col.darkened(0.04), C_OUTLINE, outline_w)

	# Front-left triangular sunlit gable wall with under-verge shadow
	var gable_face := PackedVector2Array([e_left, p_front, e_front])
	_poly_outlined(img, gable_face, gable_col.lightened(0.06), gable_col.darkened(0.05), C_OUTLINE, outline_w)
	_aa_line(img, e_left.x + 2.0, e_left.y + 1.5, p_front.x, p_front.y + 3.0, Color(0.08, 0.04, 0.02, 0.28), 2.4)
	_aa_line(img, p_front.x, p_front.y + 3.0, e_front.x - 2.0, e_front.y + 1.5, Color(0.08, 0.04, 0.02, 0.32), 2.4)

	# Front-right main visible roof slope (cooler shaded side)
	var right_slope := PackedVector2Array([p_front, p_back, e_right, e_front])
	_poly_outlined(img, right_slope, right_slope_col.lightened(0.06), right_slope_col.darkened(0.12), C_OUTLINE, outline_w)
	_aa_line(img, p_front.x, p_front.y + 1.2, p_back.x, p_back.y + 1.2, right_slope_col.lightened(0.22), 1.8)


static func _draw_roof_courses(
	img: Image,
	cx: float,
	cy: float,
	w: float,
	d: float,
	roof_h: float,
	rows: int,
	course_col: Color,
	hi_col: Color,
	is_thatch: bool
) -> void:
	var e_front := Vector2(cx, cy)
	var e_right := Vector2(cx + d, cy - d * 0.5)
	var p_front := Vector2(cx - w * 0.5, cy - w * 0.25 - roof_h)
	var p_back := p_front + Vector2(d, -d * 0.5)

	for r_i in range(1, rows):
		var t := float(r_i) / float(rows)
		var a := p_front.lerp(e_front, t)
		var b := p_back.lerp(e_right, t)
		if is_thatch:
			var segs := 7
			for s_i in range(segs):
				var u := (float(s_i) + 0.5) / float(segs)
				var pt := a.lerp(b, u)
				var slope_dir := (e_front - p_front).normalized()
				_aa_line(img, pt.x, pt.y - 2.5, pt.x + slope_dir.x * 5.0, pt.y + slope_dir.y * 5.0, course_col, 1.5)
				if (s_i + r_i) % 2 == 0:
					_aa_line(img, pt.x - 1.0, pt.y - 2.0, pt.x + slope_dir.x * 3.8 - 1.0, pt.y + slope_dir.y * 3.8, hi_col, 1.2)
		else:
			_aa_line(img, a.x + 1.5, a.y - 0.8, b.x - 1.5, b.y + 0.8, course_col, 1.5)
			_aa_line(img, a.x + 1.5, a.y + 0.6, b.x - 1.5, b.y + 2.2, hi_col, 1.0)


static func _draw_iso_window(
	img: Image,
	cx: float,
	cy: float,
	hw: float,
	hh: float,
	on_right_wall: bool,
	glow_top: Color,
	glow_bot: Color
) -> void:
	var slope := -0.5 if on_right_wall else 0.5
	var p0 := Vector2(cx - hw, cy - hw * slope - hh)
	var p1 := Vector2(cx + hw, cy + hw * slope - hh)
	var p2 := Vector2(cx + hw, cy + hw * slope + hh)
	var p3 := Vector2(cx - hw, cy - hw * slope + hh)
	var sill_a := p3 + Vector2(-1.0, 1.2)
	var sill_b := p2 + Vector2(1.0, 1.2)
	_aa_ellipse(img, cx, cy, hw * 1.6, hh * 1.4, Color(glow_top.r, glow_top.g, glow_top.b, 0.22))
	_poly_outlined(img, PackedVector2Array([p0, p1, p2, p3]), glow_top, glow_bot, C_OUTLINE, 1.8)
	_aa_line(img, cx, cy - hh, cx, cy + hh, C_OUTLINE, 1.3)
	_aa_line(img, (p0.x + p3.x) * 0.5, (p0.y + p3.y) * 0.5, (p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5, C_OUTLINE, 1.2)
	_aa_line(img, sill_a.x, sill_a.y, sill_b.x, sill_b.y, C_OUTLINE, 2.0)


static func _draw_foliage_clump(
	img: Image,
	cx: float,
	cy: float,
	r: float,
	col_shadow: Color,
	col_mid: Color,
	col_light: Color
) -> void:
	var ow := 2.0
	var lobes := [
		Vector3(cx - r * 0.30, cy + r * 0.08, r * 0.72),
		Vector3(cx + r * 0.30, cy + r * 0.12, r * 0.70),
		Vector3(cx, cy - r * 0.18, r * 0.80),
		Vector3(cx, cy + r * 0.16, r * 0.74)
	]
	for lb in lobes:
		_aa_circle(img, lb.x, lb.y, lb.z + ow, C_OUTLINE)
	for lb in lobes:
		_aa_circle(img, lb.x, lb.y, lb.z, col_shadow)

	_aa_circle(img, cx - r * 0.24, cy, r * 0.64, col_mid)
	_aa_circle(img, cx + r * 0.16, cy - r * 0.04, r * 0.56, col_mid)
	_aa_circle(img, cx - r * 0.04, cy - r * 0.20, r * 0.70, col_mid)

	_aa_circle(img, cx - r * 0.24, cy - r * 0.22, r * 0.48, col_light)
	_aa_circle(img, cx + r * 0.02, cy - r * 0.30, r * 0.40, col_light)
	_aa_ellipse(img, cx - r * 0.28, cy - r * 0.34, r * 0.28, r * 0.18, col_light.lightened(0.22))
