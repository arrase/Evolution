class_name EvoPixelCanvas
extends RefCounted

const C_OUTLINE := Color("#23150c")
const C_SHADOW := Color(0.06, 0.04, 0.02, 0.35)


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


static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(y, y + h):
		for px_i in range(x, x + w):
			_px(img, px_i, py, col)


static func _rect_outlined(img: Image, x: int, y: int, w: int, h: int, fill: Color, outline: Color = C_OUTLINE) -> void:
	_rect(img, x, y, w, h, fill)
	for px_i in range(x, x + w):
		_px(img, px_i, y, outline)
		_px(img, px_i, y + h - 1, outline)
	for py in range(y, y + h):
		_px(img, x, py, outline)
		_px(img, x + w - 1, py, outline)


static func _circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var r2 := r * r
	for py in range(cy - r, cy + r + 1):
		for px_i in range(cx - r, cx + r + 1):
			var dx := px_i - cx
			var dy := py - cy
			if dx * dx + dy * dy <= r2:
				_px(img, px_i, py, col)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for py in range(cy - ry, cy + ry + 1):
		for px_i in range(cx - rx, cx + rx + 1):
			var nx := float(px_i - cx) / float(rx)
			var ny := float(py - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				_px(img, px_i, py, col)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx: int = abs(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -abs(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var cx: int = x0
	var cy: int = y0
	while true:
		_px(img, cx, cy, col)
		if cx == x1 and cy == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy


static func _apply_soft_outline(img: Image, outline_col: Color = C_OUTLINE) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var copy := img.duplicate() as Image
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(h):
		for x in range(w):
			var c := copy.get_pixel(x, y)
			if c.a > 0.5:
				continue
			for d in dirs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					var nc := copy.get_pixel(nx, ny)
					if nc.a > 0.85:
						img.set_pixel(x, y, outline_col)
						break
