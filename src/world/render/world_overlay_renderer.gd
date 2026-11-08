class_name EvoWorldOverlayRenderer
extends RefCounted

const C_SELECTION := Color("#fde047")
const BADGE_W := 124.0
const BADGE_H := 32.0
const SHIELD_W := 26.0

static var _unit_circle_16: PackedVector2Array = PackedVector2Array()
static var _unit_circle_19: PackedVector2Array = PackedVector2Array()


static func _ensure_unit_circles() -> void:
	if not _unit_circle_16.is_empty():
		return
	_unit_circle_16.resize(16)
	for i in range(16):
		var a := TAU * float(i) / 16.0
		_unit_circle_16[i] = Vector2(cos(a), sin(a))
	_unit_circle_19.resize(19)
	for i in range(19):
		var a := TAU * float(i) / 18.0
		_unit_circle_19[i] = Vector2(cos(a), sin(a))


static func _resolve_deme_strategy_visuals(
	world_state: EvoTypes.WorldState,
	deme: EvoTypes.Deme,
	lang: String = "es"
) -> Dictionary:
	var fallback_color := Color.from_string(deme.color, Color(0.88, 0.48, 0.37))
	var slot_tag := "A" if deme.strategy_id == world_state.strategy_a_id else ("B" if deme.strategy_id == world_state.strategy_b_id else "")
	if world_state.strategies_catalog.has(deme.strategy_id):
		var strategy: EvoTypes.StrategyDef = world_state.strategies_catalog[deme.strategy_id]
		return {
			"icon": strategy.icon,
			"color": Color.from_string(strategy.color, fallback_color),
			"name": EvoI18n.strategy_name(lang, strategy),
			"slot_tag": slot_tag
		}
	return {
		"icon": "🛡️",
		"color": fallback_color,
		"name": deme.name,
		"slot_tag": slot_tag
	}


static func draw_centered_sprite(
	ci: CanvasItem,
	sprite_name: String,
	center_pos: Vector2,
	scale_val: float,
	modulate_col: Color = Color.WHITE
) -> void:
	var tex: ImageTexture = EvoPixelArtGen.get_texture(sprite_name)
	var sz: Vector2 = tex.get_size() * (scale_val * 0.25)
	ci.draw_texture_rect(
		tex,
		Rect2(Vector2(center_pos.x - sz.x * 0.5, center_pos.y - sz.y * 0.78), sz),
		false,
		modulate_col
	)


static func draw_ellipse_filled(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	_ensure_unit_circles()
	var pts := PackedVector2Array()
	pts.resize(16)
	for i in range(16):
		var u := _unit_circle_16[i]
		pts[i] = Vector2(center.x + u.x * rx, center.y + u.y * ry)
	ci.draw_colored_polygon(pts, col)


static func draw_ellipse_outline(
	ci: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	col: Color,
	width: float
) -> void:
	_ensure_unit_circles()
	var pts := PackedVector2Array()
	pts.resize(19)
	for i in range(19):
		var u := _unit_circle_19[i]
		pts[i] = Vector2(center.x + u.x * rx, center.y + u.y * ry)
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
	draw_brush_radius_overlay(r)
	_draw_deme_billboards(r)
	draw_seasonal_particles(r)


static func draw_brush_radius_overlay(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var brush_col := Color("#38bdf8") if r.active_tool == "inspect" else Color("#fb923c")
	for hex_id in r._brush_hexes:
		if hex_id == r.selected_hex_id or not r._hex_polys.has(hex_id):
			continue
		var top_pts: PackedVector2Array = r._hex_polys[hex_id]
		var pts := PackedVector2Array()
		pts.resize(7)
		for i in range(7):
			pts[i] = to_screen * top_pts[i % 6]
		ci.draw_polyline(pts, brush_col, 2.6)

	if r.selected_hex_id != "" and r._hex_polys.has(r.selected_hex_id):
		var sel_pts: PackedVector2Array = r._hex_polys[r.selected_hex_id]
		var pts := PackedVector2Array()
		pts.resize(7)
		for i in range(7):
			pts[i] = to_screen * sel_pts[i % 6]
		ci.draw_polyline(pts, C_SELECTION, 3.4)


static func _draw_billboards(r: Node2D) -> void:
	_draw_deme_billboards(r)


static func _draw_deme_billboards(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var zoom: float = r.camera.zoom_level if r.camera != null else 1.0
	var vp_size := r.get_viewport_rect().size if r.is_inside_tree() else Vector2(1600.0, 960.0)
	var screen_cull_rect := Rect2(Vector2(-240.0, -200.0), vp_size + Vector2(480.0, 400.0))

	r._deme_hit_rects.clear()
	_draw_rural_territory_overlays(r, to_screen, screen_cull_rect)

	for village in r._villages:
		var v_pos: Vector2 = village["pos"]
		var screen_pos: Vector2 = to_screen * v_pos
		if not screen_cull_rect.has_point(screen_pos):
			continue
		var deme: EvoTypes.Deme = village["deme"]
		var hex_id: String = village["hex_id"]
		var sf: float = village["sf"]
		var is_dimmed: bool = village["is_dimmed"]
		var alpha := 0.48 if is_dimmed else 0.96
		var strat_vis: Dictionary = village["strat_visuals"]
		var strat_color: Color = strat_vis["color"]

		_draw_hex_strategy_ring(r, hex_id, screen_pos, sf, strat_color, alpha)

		var is_merged: bool = deme.merged_count > 0 or deme.walled_union_id != ""
		var plinth_r: float = (58.0 if is_merged else 52.0) * sf * zoom
		var plaza_screen: Vector2 = to_screen * (v_pos + Vector2(0.0, 8.0 * sf))
		var modulate_col: Color = village["modulate"]
		if bool(village.get("in_siege", false)):
			var siege_pulse := 0.65 + 0.35 * sin(r._anim_time * 6.5)
			var siege_r := plinth_r + 12.5 * sf * zoom
			draw_ellipse_outline(
				ci,
				plaza_screen,
				siege_r,
				siege_r * 0.58,
				Color(0.98, 0.32, 0.12, 0.85 * siege_pulse) * modulate_col,
				3.2 * sf
			)
		if deme.id == r.selected_deme_id:
			var sel_r := plinth_r + 11.0 * sf * zoom
			draw_ellipse_outline(ci, plaza_screen, sel_r, sel_r * 0.58, C_SELECTION, 4.2)
		elif deme.id == r.hovered_deme_id:
			var hov_r := plinth_r + 9.5 * sf * zoom
			draw_ellipse_outline(ci, plaza_screen, hov_r, hov_r * 0.58, Color(1.0, 0.92, 0.68, 0.88), 2.8)

		r._deme_hit_rects.append({
			"rect": to_screen * (village["hit_rect"] as Rect2),
			"deme_id": deme.id,
			"hex_id": hex_id
		})
		var crest_pos: Vector2 = (to_screen * (v_pos + Vector2(0.0, -68.0 * sf))) + Vector2(0.0, -16.0)
		draw_village_billboard(r, village, crest_pos)


static func _draw_rural_territory_overlays(r: Node2D, to_screen: Transform2D, screen_cull_rect: Rect2) -> void:
	var ci: Node2D = r._overlay_layer
	var state: EvoTypes.WorldState = r.world_state
	var font := ThemeDB.fallback_font
	for hex_id in r._rural_cell_ids:
		if not state.cells.has(hex_id) or not r._hex_centers.has(hex_id) or not r._hex_polys.has(hex_id):
			continue
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		if not cell.deme_ids.is_empty() or not (cell.land_use in ["crops", "pasture"]) or cell.owner_deme_id == "":
			continue
		var center: Vector2 = r._hex_centers[hex_id]
		var screen_pos: Vector2 = to_screen * center
		if not screen_cull_rect.has_point(screen_pos):
			continue
		var owner_deme: EvoTypes.Deme
		var strat_color: Color
		if r._village_by_deme_id.has(cell.owner_deme_id):
			var owner_village: Dictionary = r._village_by_deme_id[cell.owner_deme_id]
			owner_deme = owner_village["deme"]
			strat_color = owner_village["strat_color"]
		elif state.demes.has(cell.owner_deme_id):
			owner_deme = state.demes[cell.owner_deme_id]
			strat_color = _resolve_deme_strategy_visuals(state, owner_deme, r.lang)["color"]
		else:
			continue
		var top_pts: PackedVector2Array = r._hex_polys[hex_id]
		var border_pts := PackedVector2Array()
		border_pts.resize(7)
		for i in range(7):
			border_pts[i] = to_screen * center.lerp(top_pts[i % 6], 0.86)
		var ring_col := strat_color
		ring_col.a = 0.42
		ci.draw_polyline(border_pts, ring_col, 1.8)

		var show_label: bool = (
			hex_id == r.selected_hex_id
			or hex_id == r.hovered_hex_id
			or owner_deme.id == r.selected_deme_id
			or owner_deme.id == r.hovered_deme_id
		)
		if show_label:
			var strat_vis := _resolve_deme_strategy_visuals(state, owner_deme, r.lang)
			var short_name := str(strat_vis["name"]).split(" ")[0]
			var slot_tag := str(strat_vis["slot_tag"])
			var tag_str := ("%s·%s" % [slot_tag, short_name]) if slot_tag != "" else short_name
			var icon_str := "🌾" if cell.land_use == "crops" else "🐑"
			var label_str := "%s %s (%s)" % [icon_str, tag_str, owner_deme.hex_id]
			if label_str.length() > 22:
				label_str = label_str.substr(0, 21) + "…"
			var pill_w := 130.0
			var pill_h := 20.0
			var pill_rect := Rect2(screen_pos.x - pill_w * 0.5, screen_pos.y - 34.0, pill_w, pill_h)
			ci.draw_rect(pill_rect, Color(0.11, 0.07, 0.04, 0.88), true)
			ci.draw_rect(pill_rect, strat_color, false, 1.5)
			ci.draw_string(
				font,
				Vector2(pill_rect.position.x + 5.0, pill_rect.position.y + 14.0),
				label_str,
				HORIZONTAL_ALIGNMENT_CENTER,
				pill_w - 10.0,
				10,
				Color("#fef3c7")
			)


static func _draw_hex_strategy_ring(
	r: Node2D,
	hex_id: String,
	screen_pos: Vector2,
	sf: float,
	strat_color: Color,
	alpha: float
) -> void:
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	if r._hex_polys.has(hex_id) and r._hex_centers.has(hex_id):
		var top_pts: PackedVector2Array = r._hex_polys[hex_id]
		var center: Vector2 = r._hex_centers[hex_id]
		var outer_pts := PackedVector2Array()
		var inner_pts := PackedVector2Array()
		for i in range(7):
			var corner := top_pts[i % 6]
			outer_pts.append(to_screen * center.lerp(corner, 0.90))
			inner_pts.append(to_screen * center.lerp(corner, 0.84))
		var glow_col := strat_color
		glow_col.a = 0.24 * alpha
		ci.draw_polyline(outer_pts, glow_col, 5.0)
		var ring_col := strat_color.lightened(0.15)
		ring_col.a = 0.72 * alpha
		ci.draw_polyline(outer_pts, ring_col, 2.2)
		var crest_col := strat_color
		crest_col.a = 0.34 * alpha
		ci.draw_polyline(inner_pts, crest_col, 1.4)
	else:
		var fallback_col := strat_color
		fallback_col.a = 0.65 * alpha
		draw_ellipse_outline(ci, screen_pos, 64.0 * sf, 37.0 * sf, fallback_col, 2.2)


static func draw_village_billboard(r: Node2D, village: Dictionary, pos: Vector2) -> void:
	var ci: Node2D = r._overlay_layer
	var deme: EvoTypes.Deme = village["deme"]
	var is_dimmed: bool = village["is_dimmed"]
	var font := ThemeDB.fallback_font

	var strat_vis: Dictionary = village["strat_visuals"]
	var strat_color: Color = strat_vis["color"]
	var strat_icon: String = strat_vis["icon"]
	var strat_name: String = strat_vis["name"]
	var slot_tag: String = strat_vis["slot_tag"]

	var badge_w := BADGE_W
	var badge_h := BADGE_H
	var rect := Rect2(pos.x - badge_w * 0.5, pos.y - badge_h * 0.5, badge_w, badge_h)

	var alpha := 0.48 if is_dimmed else 0.96
	var is_selected: bool = deme.id == r.selected_deme_id
	var is_hovered: bool = deme.id == r.hovered_deme_id
	var is_highlighted: bool = r.highlighted_lineage_id != "" and deme.lineage_id == r.highlighted_lineage_id

	if is_selected or is_highlighted:
		var glow_col := C_SELECTION if is_selected else strat_color.lightened(0.30)
		glow_col.a = 0.40 * alpha
		ci.draw_rect(rect.grow(2.0), glow_col, false, 2.0)
		var pip_tip := Vector2(pos.x, rect.end.y + 4.0)
		ci.draw_colored_polygon(
			PackedVector2Array([pip_tip, pip_tip + Vector2(-4.0, -4.0), pip_tip + Vector2(4.0, -4.0)]),
			C_SELECTION if is_selected else strat_color.lightened(0.25)
		)

	ci.draw_rect(Rect2(rect.position + Vector2(0.0, 2.0), rect.size), Color(0.0, 0.0, 0.0, 0.38 * alpha), true)
	ci.draw_rect(rect, Color(0.11, 0.07, 0.04, 0.92 * alpha), true)

	var shield_rect := Rect2(rect.position, Vector2(SHIELD_W, badge_h))
	var shield_fill := strat_color.darkened(0.25)
	shield_fill.a = 0.95 * alpha
	ci.draw_rect(shield_rect, shield_fill, true)
	var shield_border := strat_color.lightened(0.12)
	var shield_border_w := 1.4
	if deme.defense_tier == 1:
		shield_border = Color("#b45309")
		shield_border_w = 1.8
	elif deme.defense_tier == 2:
		shield_border = Color("#cbd5e1")
		shield_border_w = 2.0
	elif deme.defense_tier >= 3:
		shield_border = Color("#fbbf24")
		shield_border_w = 2.5
	shield_border.a = alpha
	ci.draw_rect(shield_rect, shield_border, false, shield_border_w)
	ci.draw_string(
		font,
		Vector2(shield_rect.position.x, shield_rect.position.y + 20.0),
		strat_icon,
		HORIZONTAL_ALIGNMENT_CENTER,
		SHIELD_W,
		14,
		Color(1.0, 1.0, 1.0, alpha)
	)

	var short_name := strat_name.split(" ")[0]
	var top_text := ("%s · %s" % [slot_tag, short_name]) if slot_tag != "" else short_name
	if top_text.length() > 14:
		top_text = top_text.substr(0, 13) + "…"
	var top_col := strat_color.lightened(0.35)
	top_col.a = alpha
	ci.draw_string(
		font,
		Vector2(rect.position.x + SHIELD_W + 5.0, rect.position.y + 12.0),
		top_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		badge_w - SHIELD_W - 16.0,
		10,
		top_col
	)

	var roman_str := deme.get_village_roman()
	var pop_text := ("%s · %d pop" if r.lang == "en" else "%s · %d hab") % [roman_str, deme.population]
	var pop_col := Color("#fde047") if is_selected else Color("#fef3c7")
	pop_col.a = alpha
	ci.draw_string(
		font,
		Vector2(rect.position.x + SHIELD_W + 5.0, rect.position.y + 25.0),
		pop_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		badge_w - SHIELD_W - 24.0,
		10,
		pop_col
	)

	if deme.salubrity < 0.75 or deme.get_village_tier() >= 3:
		var sal_col := Color("#10b981") if deme.salubrity >= 0.75 else (Color("#f59e0b") if deme.salubrity >= 0.40 else Color("#ef4444"))
		sal_col.a = alpha
		var dot_pos := Vector2(rect.end.x - 9.0, rect.position.y + 7.5)
		ci.draw_circle(dot_pos, 4.2, Color("#23150c") * Color(1, 1, 1, alpha))
		ci.draw_circle(dot_pos, 3.0, sal_col)
		var bar_bg := Rect2(rect.position.x + SHIELD_W + 5.0, rect.end.y - 3.5, badge_w - SHIELD_W - 26.0, 2.0)
		ci.draw_rect(bar_bg, Color(0.0, 0.0, 0.0, 0.45 * alpha), true)
		ci.draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * clampf(deme.salubrity, 0.05, 1.0), bar_bg.size.y)), sal_col, true)

	var archetype: String = village["archetype"]
	var dec_tex: ImageTexture = EvoPixelArtGen.get_texture("icon_" + archetype)
	ci.draw_texture_rect(
		dec_tex,
		Rect2(Vector2(rect.end.x - 18.0, rect.position.y + 14.0), Vector2(14.0, 14.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)

	var geo_icons: Array = village.get("geo_icons", [])
	for g_idx in range(geo_icons.size()):
		var g_type := str(geo_icons[g_idx])
		var pill_rect := Rect2(
			Vector2(rect.end.x + 3.0 + float(g_idx) * 20.0, rect.position.y + 6.0),
			Vector2(18.0, 18.0)
		)
		var g_col := EvoUiStyle.get_event_type_color(g_type)
		var pill_bg := Color(0.11, 0.07, 0.04, 0.94 * alpha)
		ci.draw_rect(pill_rect, pill_bg, true)
		var g_tex: ImageTexture = EvoPixelArtGen.get_texture("icon_" + g_type)
		ci.draw_texture_rect(
			g_tex,
			Rect2(pill_rect.position + Vector2(1.0, 1.0), Vector2(16.0, 16.0)),
			false,
			Color(1.0, 1.0, 1.0, alpha)
		)
		var pill_border := g_col.lightened(0.12)
		pill_border.a = alpha
		ci.draw_rect(pill_rect, pill_border, false, 1.5)

	var border_col := (
		C_SELECTION
		if is_selected
		else (strat_color.lightened(0.35) if (is_hovered or is_highlighted) else strat_color)
	)
	border_col.a = alpha
	var border_w := 2.2 if is_selected else (1.8 if (is_hovered or is_highlighted) else 1.4)
	ci.draw_rect(rect, border_col, false, border_w)

	r._deme_hit_rects.append({"rect": rect, "deme_id": deme.id, "hex_id": village["hex_id"]})


static func draw_seasonal_particles(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var is_wet: bool = r.world_state.season == "wet_warm"
	for p in r._particles:
		var sz: float = p["size"]
		var glow := 0.45 + 0.35 * sin(float(p["phase"]) * 2.0)
		var col := Color(1.0, 0.88, 0.38, glow) if is_wet else Color(0.90, 0.96, 1.0, glow)
		ci.draw_rect(Rect2(Vector2(float(p["x"]), float(p["y"])), Vector2(sz, sz)), col, true)
