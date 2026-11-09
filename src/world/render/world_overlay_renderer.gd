class_name EvoWorldOverlayRenderer
extends RefCounted

const C_SELECTION := Color("#fde047")
const EDGE_DIR_MAP: Array[int] = [0, 5, 4, 3, 2, 1]

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
	var slot_tag := "B" if EvoTypes._is_side_b_deme(world_state, deme) else "A"
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
	_draw_active_lens_overlay(r)
	EvoEventFxRenderer.draw_event_underlay(r)
	_draw_deme_billboards(r)
	EvoEventFxRenderer.draw_event_floating_texts(r)
	draw_seasonal_particles(r)


static func draw_brush_radius_overlay(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var zoom_val: float = r.camera.zoom_level if r.camera != null else 1.0
	var inv_zoom: float = clampf(1.0 / maxf(0.05, zoom_val), 0.8, 3.2)
	var brush_col := Color("#38bdf8") if r.active_tool == "inspect" else Color("#fb923c")
	for hex_id in r._brush_hexes:
		if hex_id == r.selected_hex_id or not r._hex_polys.has(hex_id):
			continue
		var top_pts: PackedVector2Array = r._hex_polys[hex_id]
		var pts := PackedVector2Array()
		pts.resize(7)
		for i in range(7):
			pts[i] = to_screen * top_pts[i % 6]
		ci.draw_polyline(pts, brush_col, 2.2 * sqrt(inv_zoom))

	if r.selected_hex_id != "" and r._hex_polys.has(r.selected_hex_id):
		var sel_pts: PackedVector2Array = r._hex_polys[r.selected_hex_id]
		var pts := PackedVector2Array()
		pts.resize(7)
		for i in range(7):
			pts[i] = to_screen * sel_pts[i % 6]
		ci.draw_polyline(pts, C_SELECTION, 3.0 * sqrt(inv_zoom))


static func _draw_dashed_screen_line(ci: CanvasItem, p_a: Vector2, p_b: Vector2, col: Color, width: float) -> void:
	var dist := p_a.distance_to(p_b)
	var steps := maxi(4, int(dist / 16.0))
	var dashes := PackedVector2Array()
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := minf(1.0, (float(i) + 0.58) / float(steps))
		dashes.append(p_a.lerp(p_b, t0))
		dashes.append(p_a.lerp(p_b, t1))
	if not dashes.is_empty():
		ci.draw_multiline(dashes, col, width)


static func _draw_lens_icon_pill(
	ci: CanvasItem,
	font: Font,
	pos: Vector2,
	icon_name: String,
	text_str: String,
	border_col: Color
) -> void:
	var pill_w := 44.0 if text_str != "" else 22.0
	var pill_h := 18.0
	var rect := Rect2(pos.x - pill_w * 0.5, pos.y - pill_h * 0.5, pill_w, pill_h)
	ci.draw_rect(rect, Color(0.10, 0.06, 0.03, 0.92), true)
	ci.draw_rect(rect, border_col, false, 1.5)
	var tex: ImageTexture = EvoPixelArtGen.get_texture(icon_name)
	ci.draw_texture_rect(
		tex,
		Rect2(rect.position + Vector2(3.0, 2.0), Vector2(14.0, 14.0)),
		false
	)
	if text_str != "":
		ci.draw_string(
			font,
			Vector2(rect.position.x + 19.0, rect.position.y + 13.0),
			text_str,
			HORIZONTAL_ALIGNMENT_LEFT,
			pill_w - 21.0,
			10,
			Color("#fef3c7")
		)


static func _resolve_cell_owner_deme(state: EvoTypes.WorldState, cell: EvoTypes.HexCell) -> EvoTypes.Deme:
	if not cell.deme_ids.is_empty() and state.demes.has(cell.deme_ids[0]):
		return state.demes[cell.deme_ids[0]]
	if (cell.land_use == "crops" or cell.land_use == "pasture") and cell.owner_deme_id != "" and state.demes.has(cell.owner_deme_id):
		return state.demes[cell.owner_deme_id]
	return null


static func _draw_active_lens_overlay(r: Node2D) -> void:
	var lens: String = r.active_lens
	if lens == "biome":
		return
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var state: EvoTypes.WorldState = r.world_state
	var font := ThemeDB.fallback_font
	var zoom_val: float = r.camera.zoom_level if r.camera != null else 1.0
	var inv_zoom: float = clampf(1.0 / maxf(0.05, zoom_val), 0.8, 3.2)

	if lens == "diplomacy":
		for d_a: EvoTypes.Deme in state.demes.values():
			if d_a.walled_union_id == "" or not r._hex_centers.has(d_a.hex_id):
				continue
			for d_b: EvoTypes.Deme in state.demes.values():
				if d_b.id <= d_a.id or d_b.walled_union_id != d_a.walled_union_id or not r._hex_centers.has(d_b.hex_id):
					continue
				var p_a: Vector2 = to_screen * (r._hex_centers[d_a.hex_id] as Vector2)
				var p_b: Vector2 = to_screen * (r._hex_centers[d_b.hex_id] as Vector2)
				var diff := p_b - p_a
				var perp := Vector2(-diff.y, diff.x).normalized() if diff.length() > 1.0 else Vector2.UP
				ci.draw_line(p_a, p_b, Color(0.08, 0.04, 0.02, 0.75), 9.0)
				ci.draw_line(p_a + perp * 2.5, p_b + perp * 2.5, Color("#fbbf24"), 2.6)
				ci.draw_line(p_a - perp * 2.5, p_b - perp * 2.5, Color("#fbbf24"), 2.6)
				_draw_lens_icon_pill(ci, font, (p_a + p_b) * 0.5, "icon_merge", "", Color("#fbbf24"))

		for pk_var in state.relations.keys():
			var pk := str(pk_var)
			var parts := pk.split("__")
			if parts.size() != 2 or not state.demes.has(parts[0]) or not state.demes.has(parts[1]):
				continue
			var d_a: EvoTypes.Deme = state.demes[parts[0]]
			var d_b: EvoTypes.Deme = state.demes[parts[1]]
			if not r._hex_centers.has(d_a.hex_id) or not r._hex_centers.has(d_b.hex_id):
				continue
			var p_a: Vector2 = to_screen * (r._hex_centers[d_a.hex_id] as Vector2)
			var p_b: Vector2 = to_screen * (r._hex_centers[d_b.hex_id] as Vector2)
			var rel: EvoTypes.Relation = state.relations[pk_var]
			if rel.pact_turns > 0:
				var w := clampf(2.5 + float(rel.pact_turns) * 0.7, 3.0, 6.5)
				ci.draw_line(p_a, p_b, Color(0.04, 0.18, 0.12, 0.80), w + 2.4)
				ci.draw_line(p_a, p_b, Color("#10b981"), w)
				_draw_lens_icon_pill(ci, font, (p_a + p_b) * 0.5, "icon_pact", str(rel.pact_turns), Color("#10b981"))
			elif rel.feud_turns > 0:
				_draw_dashed_screen_line(ci, p_a, p_b, Color("#ef4444"), 3.0)
				_draw_lens_icon_pill(ci, font, (p_a + p_b) * 0.5, "icon_vendetta", str(rel.feud_turns), Color("#ef4444"))
			elif rel.truce_turns > 0:
				_draw_dashed_screen_line(ci, p_a, p_b, Color("#6ee7b7"), 2.2)

		for flow in state.active_flows:
			if not r._hex_centers.has(flow.from_hex_id) or not r._hex_centers.has(flow.to_hex_id):
				continue
			if flow.from_hex_id == flow.to_hex_id:
				continue
			var p_a: Vector2 = to_screen * (r._hex_centers[flow.from_hex_id] as Vector2)
			var p_b: Vector2 = to_screen * (r._hex_centers[flow.to_hex_id] as Vector2)
			var diff := p_b - p_a
			var dist := diff.length()
			if dist < 8.0:
				continue
			var dir := diff / dist
			var perp := Vector2(-dir.y, dir.x)
			if flow.flow_type == "merge":
				ci.draw_line(p_a + perp * 2.5, p_b + perp * 2.5, Color("#fbbf24"), 2.4)
				ci.draw_line(p_a - perp * 2.5, p_b - perp * 2.5, Color("#fbbf24"), 2.4)
			elif flow.flow_type in ["war", "siege", "raid", "tribute", "betrayal"]:
				var col := EvoUiStyle.get_event_type_color(flow.flow_type)
				var s_pt := p_a + dir * minf(24.0, dist * 0.20)
				var e_pt := p_b - dir * minf(30.0, dist * 0.24)
				ci.draw_line(s_pt, e_pt, Color(0.08, 0.04, 0.02, 0.82), 6.0)
				ci.draw_line(s_pt, e_pt, col.lightened(0.12), 3.6)
				var tri := PackedVector2Array([
					e_pt + dir * 7.0,
					e_pt - dir * 8.0 + perp * 6.5,
					e_pt - dir * 8.0 - perp * 6.5
				])
				ci.draw_colored_polygon(tri, col.lightened(0.15))

	elif lens == "health":
		var pulse := 0.65 + 0.35 * sin(r._anim_time * 6.0)
		for village in r._villages:
			var deme: EvoTypes.Deme = village["deme"]
			var hex_id: String = village["hex_id"]
			if not r._hex_polys.has(hex_id) or not r._hex_centers.has(hex_id):
				continue
			var center: Vector2 = r._hex_centers[hex_id]
			var top_pts: PackedVector2Array = r._hex_polys[hex_id]
			var ring_pts := PackedVector2Array()
			ring_pts.resize(7)
			for i in range(7):
				ring_pts[i] = to_screen * center.lerp(top_pts[i % 6], 0.82)
			var screen_center: Vector2 = to_screen * center
			if deme.infection_turns > 0:
				var inf_col := Color(0.52, 0.80, 0.09, 0.88 * pulse)
				ci.draw_polyline(ring_pts, inf_col, 4.5 * sqrt(inv_zoom))
				_draw_lens_icon_pill(
					ci,
					font,
					screen_center + Vector2(0.0, 32.0),
					"icon_epidemic",
					"%dt" % deme.infection_turns,
					Color("#84cc16")
				)
			elif deme.immunity_turns > 0:
				ci.draw_polyline(ring_pts, Color("#06b6d4"), 3.2 * sqrt(inv_zoom))
				_draw_lens_icon_pill(
					ci,
					font,
					screen_center + Vector2(0.0, 32.0),
					"icon_immune",
					"%dt" % deme.immunity_turns,
					Color("#06b6d4")
				)
			elif deme.salubrity < 0.45:
				ci.draw_polyline(ring_pts, Color("#f59e0b"), 3.0 * sqrt(inv_zoom))

	elif lens == "territory":
		for hex_id in state.cells.keys():
			if not r._hex_polys.has(hex_id) or not r._hex_centers.has(hex_id):
				continue
			var cell: EvoTypes.HexCell = state.cells[hex_id]
			if r._is_water(cell):
				continue
			var owner := _resolve_cell_owner_deme(state, cell)
			if owner == null:
				continue
			var owner_side := "B" if EvoTypes._is_side_b_deme(state, owner) else "A"
			var strat_col := EvoPropFloraRenderer.resolve_deme_strategy_color(state, owner)
			var center: Vector2 = r._hex_centers[hex_id]
			var top_pts: PackedVector2Array = r._hex_polys[hex_id]
			for e in range(6):
				var nb_id: String = r._neighbor_id(cell, EDGE_DIR_MAP[e])
				var same_domain := false
				if state.cells.has(nb_id):
					var nb_cell: EvoTypes.HexCell = state.cells[nb_id]
					if not r._is_water(nb_cell):
						var nb_owner := _resolve_cell_owner_deme(state, nb_cell)
						if nb_owner != null:
							var nb_side := "B" if EvoTypes._is_side_b_deme(state, nb_owner) else "A"
							same_domain = (nb_side == owner_side and nb_owner.strategy_id == owner.strategy_id)
				if not same_domain:
					var c0: Vector2 = to_screen * center.lerp(top_pts[e], 0.94)
					var c1: Vector2 = to_screen * center.lerp(top_pts[(e + 1) % 6], 0.94)
					ci.draw_line(c0, c1, Color("#23150c"), 6.4 * sqrt(inv_zoom))
					ci.draw_line(c0, c1, strat_col.lightened(0.18), 3.8 * sqrt(inv_zoom))

	elif lens == "food":
		for village in r._villages:
			var deme: EvoTypes.Deme = village["deme"]
			var hex_id: String = village["hex_id"]
			if not r._hex_centers.has(hex_id):
				continue
			var screen_center: Vector2 = to_screen * (r._hex_centers[hex_id] as Vector2)
			var ratio := (deme.last_food_intake / maxf(1.0, deme.last_food_need)) if deme.last_food_need > 0.0 else 1.0
			var pct := int(round(clampf(ratio, 0.0, 2.5) * 100.0))
			var col := Color("#10b981") if pct >= 100 else (Color("#f59e0b") if pct >= 75 else Color("#ef4444"))
			_draw_lens_icon_pill(ci, font, screen_center + Vector2(0.0, 32.0), "icon_forage", "%d%%" % pct, col)

		for hex_id in r._rural_cell_ids:
			if not state.cells.has(hex_id) or not r._hex_centers.has(hex_id):
				continue
			var cell: EvoTypes.HexCell = state.cells[hex_id]
			var screen_center: Vector2 = to_screen * (r._hex_centers[hex_id] as Vector2)
			var icon_name := "icon_forage" if cell.land_use == "crops" else "icon_cooperate"
			var col := Color("#eab308") if cell.land_use == "crops" else Color("#10b981")
			_draw_lens_icon_pill(ci, font, screen_center, icon_name, "", col)


static func _draw_deme_billboards(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var zoom_val: float = r.camera.zoom_level if r.camera != null else 1.0
	var is_macro: bool = zoom_val < 0.30
	var inv_zoom: float = clampf(1.0 / maxf(0.05, zoom_val), 0.8, 3.2)
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
		var is_dimmed: bool = village["is_dimmed"]
		var alpha := 0.48 if is_dimmed else 0.96
		var strat_vis: Dictionary = village["strat_visuals"]
		var strat_color: Color = strat_vis["color"]

		_draw_hex_strategy_ring(r, hex_id, screen_pos, strat_color, alpha)

		var is_merged: bool = deme.merged_count > 0 or deme.walled_union_id != ""
		var plinth_r: float = (58.0 if is_merged else 52.0) * zoom_val
		var plaza_screen: Vector2 = to_screen * (v_pos + Vector2(0.0, 8.0))
		var modulate_col: Color = village["modulate"]
		if bool(village.get("in_siege", false)):
			var siege_pulse := 0.65 + 0.35 * sin(r._anim_time * 6.5)
			var siege_r := plinth_r + 12.5 * zoom_val
			draw_ellipse_outline(
				ci,
				plaza_screen,
				siege_r,
				siege_r * 0.58,
				Color(0.98, 0.32, 0.12, 0.85 * siege_pulse) * modulate_col,
				3.2 * sqrt(inv_zoom)
			)
		if deme.id == r.selected_deme_id:
			var sel_r := plinth_r + 11.0 * zoom_val
			draw_ellipse_outline(ci, plaza_screen, sel_r, sel_r * 0.58, C_SELECTION, 4.2 * sqrt(inv_zoom))
		elif deme.id == r.hovered_deme_id:
			var hov_r := plinth_r + 9.5 * zoom_val
			draw_ellipse_outline(ci, plaza_screen, hov_r, hov_r * 0.58, Color(1.0, 0.92, 0.68, 0.88), 2.8 * sqrt(inv_zoom))

		r._deme_hit_rects.append({
			"rect": to_screen * (village["hit_rect"] as Rect2),
			"deme_id": deme.id,
			"hex_id": hex_id
		})
		var crest_offset_y := -52.0 if is_macro else -68.0
		var crest_pos: Vector2 = (to_screen * (v_pos + Vector2(0.0, crest_offset_y))) + Vector2(0.0, -12.0 if is_macro else -16.0)
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
			var label_str := "%s (%s)" % [tag_str, owner_deme.hex_id]
			if label_str.length() > 20:
				label_str = label_str.substr(0, 19) + "…"
			var pill_w := 134.0
			var pill_h := 20.0
			var pill_rect := Rect2(screen_pos.x - pill_w * 0.5, screen_pos.y - 34.0, pill_w, pill_h)
			ci.draw_rect(pill_rect, Color(0.11, 0.07, 0.04, 0.88), true)
			ci.draw_rect(pill_rect, strat_color, false, 1.5)
			var icon_name := "icon_forage" if cell.land_use == "crops" else "icon_cooperate"
			var icon_tex: ImageTexture = EvoPixelArtGen.get_texture(icon_name)
			ci.draw_texture_rect(
				icon_tex,
				Rect2(pill_rect.position + Vector2(4.0, 3.0), Vector2(14.0, 14.0)),
				false
			)
			ci.draw_string(
				font,
				Vector2(pill_rect.position.x + 21.0, pill_rect.position.y + 14.0),
				label_str,
				HORIZONTAL_ALIGNMENT_LEFT,
				pill_w - 25.0,
				10,
				Color("#fef3c7")
			)


static func _draw_hex_strategy_ring(
	r: Node2D,
	hex_id: String,
	screen_pos: Vector2,
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
		draw_ellipse_outline(ci, screen_pos, 64.0, 37.0, fallback_col, 2.2)


static func draw_village_billboard(r: Node2D, village: Dictionary, pos: Vector2) -> void:
	var ci: Node2D = r._overlay_layer
	var deme: EvoTypes.Deme = village["deme"]
	var is_dimmed: bool = village["is_dimmed"]
	var font := ThemeDB.fallback_font
	var zoom_val: float = r.camera.zoom_level if r.camera != null else 1.0
	var is_macro: bool = zoom_val < 0.30
	var lod: int = 0 if zoom_val < 0.48 else (1 if zoom_val < 0.90 else 2)

	var strat_vis: Dictionary = village["strat_visuals"]
	var strat_color: Color = strat_vis["color"]
	var strat_name: String = strat_vis["name"]
	var strat_letter: String = str(strat_vis["slot_tag"])
	if strat_letter == "":
		strat_letter = "B" if EvoTypes._is_side_b_deme(r.world_state, deme) else "A"

	var badge_w := 96.0 if is_macro else (88.0 if lod == 0 else (134.0 if lod == 1 else 148.0))
	var badge_h := 24.0 if is_macro else (24.0 if lod == 0 else (36.0 if lod == 1 else 40.0))
	var shield_w := 6.0 if is_macro else (20.0 if lod == 0 else (24.0 if lod == 1 else 26.0))
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

	var shield_rect := Rect2(rect.position, Vector2(shield_w, badge_h))
	var shield_fill := strat_color if is_macro else strat_color.darkened(0.25)
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
	if not is_macro:
		ci.draw_rect(shield_rect, shield_border, false, shield_border_w)
		var tag_y := shield_rect.position.y + (16.0 if lod == 0 else (22.0 if lod == 1 else 24.0))
		ci.draw_string(
			font,
			Vector2(shield_rect.position.x, tag_y),
			strat_letter,
			HORIZONTAL_ALIGNMENT_CENTER,
			shield_w,
			11 if lod == 0 else 13,
			Color(1.0, 1.0, 1.0, alpha)
		)

	var tier_roman := deme.get_village_roman()
	var is_starving := deme.get_vital_status() == "starving"

	if is_macro:
		var macro_text := "%s %s·%d" % [strat_letter, tier_roman, deme.population]
		var pop_col := Color("#fde047") if is_selected else Color("#fef3c7")
		pop_col.a = alpha
		ci.draw_string(
			font,
			Vector2(rect.position.x + shield_w + 5.0, rect.position.y + 16.0),
			macro_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			badge_w - shield_w - 16.0,
			11,
			pop_col
		)
		var dot_col := Color("#10b981")
		if deme.infection_turns > 0:
			var pulse := 0.55 + 0.45 * sin(r._anim_time * 7.0)
			dot_col = Color("#84cc16") * pulse + Color(0.2, 0.3, 0.0, 1.0 - pulse)
		elif is_starving:
			dot_col = Color("#ef4444")
		elif deme.salubrity < 0.50:
			dot_col = Color("#f59e0b")
		dot_col.a = alpha
		var dot_pos := Vector2(rect.end.x - 8.0, rect.position.y + 12.0)
		ci.draw_circle(dot_pos, 4.0, Color(0.14, 0.08, 0.05, alpha))
		ci.draw_circle(dot_pos, 2.8, dot_col)
	elif lod == 0:
		var compact_text := "%s·%d" % [tier_roman, deme.population]
		var pop_col := Color("#fde047") if is_selected else Color("#fef3c7")
		pop_col.a = alpha
		ci.draw_string(
			font,
			Vector2(rect.position.x + shield_w + 4.0, rect.position.y + 16.0),
			compact_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			badge_w - shield_w - 16.0,
			10,
			pop_col
		)
		var dot_col := Color("#10b981")
		if deme.infection_turns > 0:
			var pulse := 0.55 + 0.45 * sin(r._anim_time * 7.0)
			dot_col = Color("#84cc16") * pulse + Color(0.2, 0.3, 0.0, 1.0 - pulse)
		elif is_starving:
			dot_col = Color("#ef4444")
		elif deme.salubrity < 0.50:
			dot_col = Color("#f59e0b")
		dot_col.a = alpha
		var dot_pos := Vector2(rect.end.x - 8.0, rect.position.y + 12.0)
		ci.draw_circle(dot_pos, 4.2, Color(0.14, 0.08, 0.05, alpha))
		ci.draw_circle(dot_pos, 3.0, dot_col)
	else:
		var short_name := strat_name.split(" ")[0]
		var top_text := "%s · %s" % [strat_letter, short_name]
		if top_text.length() > 14:
			top_text = top_text.substr(0, 13) + "…"
		var top_col := strat_color.lightened(0.35)
		top_col.a = alpha
		ci.draw_string(
			font,
			Vector2(rect.position.x + shield_w + 5.0, rect.position.y + 11.0),
			top_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			badge_w - shield_w - 22.0,
			10,
			top_col
		)

		var archetype: String = village["archetype"]
		var dec_tex: ImageTexture = EvoPixelArtGen.get_texture("icon_" + archetype)
		ci.draw_texture_rect(
			dec_tex,
			Rect2(Vector2(rect.end.x - 17.0, rect.position.y + 3.0), Vector2(14.0, 14.0)),
			false,
			Color(1.0, 1.0, 1.0, alpha)
		)

		var pop_base := "%s · %d" % [tier_roman, deme.population]
		var pop_col := Color("#fde047") if is_selected else Color("#fef3c7")
		pop_col.a = alpha
		var mid_x := rect.position.x + shield_w + 5.0
		ci.draw_string(
			font,
			Vector2(mid_x, rect.position.y + 23.0),
			pop_base,
			HORIZONTAL_ALIGNMENT_LEFT,
			64.0,
			10,
			pop_col
		)
		if deme.last_population_delta != 0:
			var delta_str := "(%+d)" % deme.last_population_delta
			var delta_col := Color("#4ade80") if deme.last_population_delta > 0 else Color("#f87171")
			delta_col.a = alpha
			ci.draw_string(
				font,
				Vector2(mid_x + 48.0, rect.position.y + 23.0),
				delta_str,
				HORIZONTAL_ALIGNMENT_LEFT,
				38.0,
				9,
				delta_col
			)

		if lod == 2:
			var cal_str := "%d cal" % int(round(deme.energy_reserves))
			var cal_col := Color("#fca5a5") if is_starving else Color("#fcd34d")
			cal_col.a = alpha * 0.90
			ci.draw_string(
				font,
				Vector2(rect.end.x - 42.0, rect.position.y + 23.0),
				cal_str,
				HORIZONTAL_ALIGNMENT_RIGHT,
				38.0,
				9,
				cal_col
			)

		var bar_area_x := rect.position.x + shield_w + 5.0
		var bar_area_w := badge_w - shield_w - 10.0
		var bar_y := rect.end.y - 5.5
		var single_w := (bar_area_w - 4.0) * 0.5

		var food_ratio := clampf(deme.last_food_intake / maxf(1.0, deme.last_food_need), 0.05, 1.0) if deme.last_food_need > 0.0 else 1.0
		var food_col := Color("#fbbf24") if (food_ratio >= 0.80 and not is_starving) else Color("#ef4444")
		food_col.a = alpha
		var food_bg := Rect2(bar_area_x, bar_y, single_w, 3.0)
		ci.draw_rect(food_bg, Color(0.0, 0.0, 0.0, 0.50 * alpha), true)
		ci.draw_rect(Rect2(food_bg.position, Vector2(single_w * food_ratio, 3.0)), food_col, true)

		var sal_ratio := clampf(deme.salubrity, 0.05, 1.0)
		var sal_col := Color("#10b981") if deme.salubrity >= 0.75 else (Color("#f59e0b") if deme.salubrity >= 0.40 else Color("#ef4444"))
		if deme.infection_turns > 0:
			sal_col = Color("#84cc16")
		sal_col.a = alpha
		var sal_bg := Rect2(bar_area_x + single_w + 4.0, bar_y, single_w, 3.0)
		ci.draw_rect(sal_bg, Color(0.0, 0.0, 0.0, 0.50 * alpha), true)
		ci.draw_rect(Rect2(sal_bg.position, Vector2(single_w * sal_ratio, 3.0)), sal_col, true)

	var geo_icons: Array = village.get("geo_icons", [])
	var max_icons := 0 if is_macro else (1 if lod == 0 else (3 if lod == 1 else 5))
	var shown_count := mini(geo_icons.size(), max_icons)
	var pill_y := rect.position.y + (badge_h - 18.0) * 0.5
	for g_idx in range(shown_count):
		var g_type := str(geo_icons[g_idx])
		var pill_rect := Rect2(
			Vector2(rect.end.x + 3.0 + float(g_idx) * 20.0, pill_y),
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

	if geo_icons.size() > max_icons and lod >= 1:
		var extra_count := geo_icons.size() - max_icons
		var extra_rect := Rect2(
			Vector2(rect.end.x + 3.0 + float(shown_count) * 20.0, pill_y),
			Vector2(22.0, 18.0)
		)
		ci.draw_rect(extra_rect, Color(0.11, 0.07, 0.04, 0.92 * alpha), true)
		ci.draw_rect(extra_rect, Color(0.85, 0.65, 0.25, alpha), false, 1.2)
		ci.draw_string(
			font,
			Vector2(extra_rect.position.x, extra_rect.position.y + 13.0),
			"+%d" % extra_count,
			HORIZONTAL_ALIGNMENT_CENTER,
			22.0,
			9,
			Color(1.0, 0.95, 0.80, alpha)
		)

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
