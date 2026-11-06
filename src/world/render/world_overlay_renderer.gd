class_name EvoWorldOverlayRenderer
extends RefCounted

const C_SELECTION := Color("#fde047")


static func draw_centered_sprite(
	ci: CanvasItem,
	sprite_name: String,
	center_pos: Vector2,
	scale_val: float,
	modulate_col: Color = Color.WHITE
) -> void:
	var tex: ImageTexture = EvoPixelArtGen.get_texture(sprite_name)
	var sz: Vector2 = tex.get_size() * scale_val
	ci.draw_texture_rect(
		tex,
		Rect2(Vector2(center_pos.x - sz.x * 0.5, center_pos.y - sz.y * 0.78), sz),
		false,
		modulate_col
	)


static func draw_ellipse_filled(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func draw_ellipse_outline(
	ci: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	col: Color,
	width: float
) -> void:
	var pts := PackedVector2Array()
	for i in range(19):
		var a := TAU * float(i) / 18.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, col, width)


static func init_particles(particles: Array[Dictionary]) -> void:
	particles.clear()
	for i in range(42):
		particles.append({
			"x": float((i * 97) % 1600),
			"y": float((i * 53) % 960),
			"speed": 14.0 + float((i * 19) % 22),
			"phase": float(i) * 0.65,
			"size": 2.0 + float(i % 2)
		})


static func update_particles(r: Node2D, delta: float) -> void:
	if r.world_state == null:
		return
	var vp_size := r.get_viewport_rect().size if r.is_inside_tree() else Vector2(1600.0, 960.0)
	var is_wet: bool = r.world_state.season == "wet_warm"
	for p in r._particles:
		var spd: float = p["speed"]
		var ph: float = p["phase"] + delta * 1.4
		p["phase"] = ph
		if is_wet:
			p["y"] = fposmod(float(p["y"]) - spd * 0.45 * delta, vp_size.y)
			p["x"] = fposmod(float(p["x"]) + sin(ph) * 14.0 * delta, vp_size.x)
		else:
			p["y"] = fposmod(float(p["y"]) + spd * 1.15 * delta, vp_size.y)
			p["x"] = fposmod(float(p["x"]) + cos(ph) * 18.0 * delta, vp_size.x)


static func draw_overlay(r: Node2D) -> void:
	if r.world_state == null:
		return
	var to_screen: Transform2D = r._world_layer.transform
	var vp_size := r.get_viewport_rect().size if r.is_inside_tree() else Vector2(1600.0, 960.0)
	var screen_cull_rect := Rect2(Vector2(-240.0, -200.0), vp_size + Vector2(480.0, 400.0))

	r._deme_hit_rects.clear()
	for village in r._villages:
		var v_pos: Vector2 = village["pos"]
		var screen_pos: Vector2 = to_screen * v_pos
		if not screen_cull_rect.has_point(screen_pos):
			continue
		var deme_id := str(village.get("deme_id", (village["deme"] as EvoTypes.Deme).id))
		var hex_id := str(village.get("hex_id", ""))
		r._deme_hit_rects.append({
			"rect": to_screen * (village["hit_rect"] as Rect2),
			"deme_id": deme_id,
			"hex_id": hex_id
		})
		var crest_pos: Vector2 = to_screen * (v_pos + Vector2(0.0, 30.0 * float(village["sf"])))
		draw_village_billboard(r, village, crest_pos)
	draw_seasonal_particles(r)


static func draw_village_billboard(r: Node2D, village: Dictionary, pos: Vector2) -> void:
	var ci: Node2D = r._overlay_layer
	var deme: EvoTypes.Deme = village["deme"]
	var is_dimmed: bool = village["is_dimmed"]

	var font := ThemeDB.fallback_font
	var sub_text: String = village["sub_text"]
	var box_size: Vector2 = village["box_size"]
	var rect := Rect2(pos.x - box_size.x * 0.5, pos.y - box_size.y * 0.5, box_size.x, box_size.y)

	var alpha := 0.48 if is_dimmed else 0.96
	var is_selected: bool = deme.id == r.selected_deme_id
	var is_hovered: bool = deme.id == r.hovered_deme_id

	if is_selected:
		ci.draw_rect(rect.grow(2.0), Color(1.0, 0.88, 0.28, 0.38 * alpha), false, 2.0)
		var pip_top := Vector2(pos.x, rect.position.y - 3.5)
		ci.draw_colored_polygon(
			PackedVector2Array([pip_top, pip_top + Vector2(-3.5, 3.5), pip_top + Vector2(3.5, 3.5)]),
			C_SELECTION
		)

	ci.draw_rect(Rect2(rect.position + Vector2(0, 1.5), rect.size), Color(0, 0, 0, 0.34 * alpha), true)
	ci.draw_rect(rect, Color(0.14, 0.08, 0.04, 0.90 * alpha), true)

	var border_col := C_SELECTION if is_selected else (Color(1.0, 0.92, 0.68, alpha) if is_hovered else Color("#78472a"))
	border_col.a = alpha
	var border_w := 2.0 if is_selected else (1.6 if is_hovered else 1.2)
	ci.draw_rect(rect, border_col, false, border_w)

	var shield_c := Vector2(rect.position.x + 8.5, pos.y)
	ci.draw_circle(shield_c, 4.6, Color(0.08, 0.04, 0.02, alpha))
	var lin_col := Color(deme.color)
	lin_col.a = alpha
	ci.draw_circle(shield_c, 3.8, lin_col)
	ci.draw_circle(shield_c + Vector2(-1.0, -1.0), 1.1, lin_col.lightened(0.32))

	var text_col := Color("#fde047") if is_selected else Color("#fef3c7")
	text_col.a = alpha
	ci.draw_string(font, Vector2(rect.position.x + 15.5, pos.y + 3.5), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)
	r._deme_hit_rects.append({"rect": rect, "deme_id": deme.id, "hex_id": village["hex_id"]})


static func draw_seasonal_particles(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var is_wet: bool = r.world_state.season == "wet_warm"
	for p in r._particles:
		var sz: float = p["size"]
		var glow := 0.45 + 0.35 * sin(float(p["phase"]) * 2.0)
		var col := Color(1.0, 0.88, 0.38, glow) if is_wet else Color(0.90, 0.96, 1.0, glow)
		ci.draw_rect(Rect2(Vector2(float(p["x"]), float(p["y"])), Vector2(sz, sz)), col, true)
