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
	return abs(h ^ (h >> 16))


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
	var w := img.get_width()
	var h := img.get_height()
	var y0 := maxi(0, int(floor(cy - ry - 1.0)))
	var y1 := mini(h - 1, int(ceil(cy + ry + 1.0)))
	var x0 := maxi(0, int(floor(cx - rx - 1.0)))
	var x1 := mini(w - 1, int(ceil(cx + rx + 1.0)))
	for py in range(y0, y1 + 1):
		var ny := (float(py) - cy) / ry
		var ny2 := ny * ny
		if ny2 >= 1.0:
			continue
		for px_i in range(x0, x1 + 1):
			var nx := (float(px_i) - cx) / rx
			var d2 := nx * nx + ny2
			if d2 < 1.0:
				var falloff := clampf((1.0 - sqrt(d2)) * 2.2, 0.0, 1.0)
				_blend_px(img, px_i, py, Color(0.05, 0.03, 0.02, alpha * falloff))


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
			var ix_start := maxi(0, int(ceil(x_left - 0.5)))
			var ix_end := mini(w - 1, int(floor(x_right + 0.5)))
			if ix_end >= ix_start:
				if row_col.a >= 0.995:
					img.fill_rect(Rect2i(ix_start, py, ix_end - ix_start + 1, 1), row_col)
				else:
					for px_i in range(ix_start, ix_end + 1):
						_blend_px(img, px_i, py, row_col)
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
		_poly_outlined(img, left_face, left_col.lightened(0.06), left_col.darkened(0.08), C_OUTLINE, outline_w)

		var right_face := PackedVector2Array([t_front, t_right, b_right, b_front])
		_poly_outlined(img, right_face, right_col.lightened(0.04), right_col.darkened(0.10), C_OUTLINE, outline_w)

	var top_face := PackedVector2Array([t_back, t_right, t_front, t_left])
	_poly_outlined(img, top_face, top_col.lightened(0.06), top_col.darkened(0.04), C_OUTLINE, outline_w)


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

	# Back-left slope (drawn first so front faces occlude it cleanly)
	var left_slope := PackedVector2Array([e_left, e_back, p_back, p_front])
	_poly_outlined(img, left_slope, left_slope_col.lightened(0.06), left_slope_col.darkened(0.08), C_OUTLINE, outline_w)

	# Front-left triangular gable wall
	var gable_face := PackedVector2Array([e_left, p_front, e_front])
	_poly_outlined(img, gable_face, gable_col.lightened(0.05), gable_col.darkened(0.06), C_OUTLINE, outline_w)

	# Front-right main visible roof slope
	var right_slope := PackedVector2Array([p_front, p_back, e_right, e_front])
	_poly_outlined(img, right_slope, right_slope_col.lightened(0.08), right_slope_col.darkened(0.10), C_OUTLINE, outline_w)
