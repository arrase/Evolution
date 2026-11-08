class_name EvoWorldOverlayRenderer
extends RefCounted

const C_SELECTION := Color("#fde047")
const BADGE_W := 114.0
const BADGE_H := 30.0
const SHIELD_W := 26.0

static var _unit_circle_16 := PackedVector2Array()
static var _unit_circle_19 := PackedVector2Array()
static var _ellipse_fill_buf := PackedVector2Array()
static var _ellipse_line_buf := PackedVector2Array()


static func _ensure_ellipse_tables() -> void:
	if not _unit_circle_16.is_empty():
		return
	_unit_circle_16.resize(16)
	_ellipse_fill_buf.resize(16)
	for i in range(16):
		var a := TAU * float(i) / 16.0
		_unit_circle_16[i] = Vector2(cos(a), sin(a))
	_unit_circle_19.resize(19)
	_ellipse_line_buf.resize(19)
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
	var strat_icon := "🛡️"
	var strat_color := fallback_color
	var strat_name := deme.name
	if world_state.strategies_catalog.has(deme.strategy_id):
		var strategy: EvoTypes.StrategyDef = world_state.strategies_catalog[deme.strategy_id]
		strat_icon = strategy.icon
		strat_color = Color.from_string(strategy.color, fallback_color)
		strat_name = EvoI18n.strategy_name(lang, strategy)
	var short_name := strat_name.split(" ")[0]
	var short_label := ("%s · %s" % [slot_tag, short_name]) if slot_tag != "" else short_name
	if short_label.length() > 13:
		short_label = short_label.substr(0, 12) + "…"
	return {
		"icon": strat_icon,
		"color": strat_color,
		"name": strat_name,
		"label": strat_name,
		"short_label": short_label,
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
	var sz: Vector2 = tex.get_size() * scale_val
	ci.draw_texture_rect(
		tex,
		Rect2(Vector2(center_pos.x - sz.x * 0.5, center_pos.y - sz.y * 0.78), sz),
		false,
		modulate_col
	)


static func draw_ellipse_filled(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	_ensure_ellipse_tables()
	var radii := Vector2(rx, ry)
	for i in range(16):
		_ellipse_fill_buf[i] = center + _unit_circle_16[i] * radii
	ci.draw_colored_polygon(_ellipse_fill_buf, col)


static func draw_ellipse_outline(
	ci: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	col: Color,
	width: float
) -> void:
	_ensure_ellipse_tables()
	var radii := Vector2(rx, ry)
	for i in range(19):
		_ellipse_line_buf[i] = center + _unit_circle_19[i] * radii
	ci.draw_polyline(_ellipse_line_buf, col, width)


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
	if r.active_micro_phase >= 1 and r.active_micro_phase <= 4:
		_draw_micro_phase_highlights(r)
	_draw_deme_billboards(r)
	draw_seasonal_particles(r)


static func _draw_deme_billboards(r: Node2D) -> void:
	var to_screen: Transform2D = r._world_layer.transform
	var vp_size := r.get_viewport_rect().size if r.is_inside_tree() else Vector2(1600.0, 960.0)
	var screen_cull_rect := Rect2(Vector2(-240.0, -200.0), vp_size + Vector2(480.0, 400.0))
	var weights: Vector3 = r.get_zoom_tier_weights()
	var tier: String = r.get_semantic_zoom_tier()

	r._deme_hit_rects.clear()
	var drawn_hex_rings: Dictionary = {}
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

		if tier == "macro":
			_draw_macro_medallion(r, village, screen_pos, alpha)
			continue

		r._deme_hit_rects.append({
			"rect": to_screen * (village["hit_rect"] as Rect2),
			"deme_id": deme.id,
			"hex_id": hex_id
		})

		if not drawn_hex_rings.has(hex_id):
			drawn_hex_rings[hex_id] = true
			_draw_hex_strategy_ring(r, hex_id, screen_pos, sf, strat_color, alpha)

		var crest_pos: Vector2 = (to_screen * (v_pos + Vector2(0.0, -54.0 * sf))) + Vector2(0.0, -16.0)
		draw_village_billboard(r, village, crest_pos)

		if weights.z > 0.05 or tier == "micro":
			_draw_micro_diagnostics(r, village, v_pos, screen_pos, crest_pos, alpha * clampf(weights.z * 1.4, 0.45, 1.0))


static func _draw_macro_medallion(r: Node2D, village: Dictionary, center: Vector2, alpha: float) -> void:
	var ci: Node2D = r._overlay_layer
	var deme: EvoTypes.Deme = village["deme"]
	var font := ThemeDB.fallback_font
	var strat_vis: Dictionary = village["strat_visuals"]
	var strat_color: Color = strat_vis["color"]
	var strat_icon: String = strat_vis["icon"]
	var status_col: Color = village["status_col"]
	var is_selected: bool = deme.id == r.selected_deme_id
	var is_hovered: bool = deme.id == r.hovered_deme_id
	var rad := 22.0

	ci.draw_circle(center + Vector2(0.0, 2.0), rad + 1.5, Color(0.0, 0.0, 0.0, 0.42 * alpha))
	ci.draw_circle(center, rad, Color(0.10, 0.07, 0.05, 0.94 * alpha))

	var ring_col := C_SELECTION if is_selected else (strat_color.lightened(0.28) if is_hovered else strat_color)
	ring_col.a = alpha
	ci.draw_arc(center, rad, 0.0, TAU, 28, ring_col, 3.2 if is_selected else 2.4)

	var vital_col := status_col
	vital_col.a = 0.90 * alpha
	ci.draw_arc(center, rad - 3.2, -PI * 0.85, -PI * 0.15, 16, vital_col, 2.2)

	ci.draw_string(
		font,
		Vector2(center.x - rad, center.y - 2.0),
		strat_icon,
		HORIZONTAL_ALIGNMENT_CENTER,
		rad * 2.0,
		13,
		Color(1.0, 1.0, 1.0, alpha)
	)
	var pop_str := str(deme.population)
	var pop_col := Color("#fde047") if is_selected else Color("#fef3c7")
	pop_col.a = alpha
	ci.draw_string(
		font,
		Vector2(center.x - rad, center.y + 13.0),
		pop_str,
		HORIZONTAL_ALIGNMENT_CENTER,
		rad * 2.0,
		10,
		pop_col
	)
	r._deme_hit_rects.append({
		"rect": Rect2(center - Vector2(rad + 2.0, rad + 2.0), Vector2((rad + 2.0) * 2.0, (rad + 2.0) * 2.0)),
		"deme_id": deme.id,
		"hex_id": village["hex_id"]
	})


static func _draw_micro_diagnostics(
	r: Node2D,
	village: Dictionary,
	v_pos: Vector2,
	screen_pos: Vector2,
	crest_pos: Vector2,
	alpha: float
) -> void:
	var ci: Node2D = r._overlay_layer
	var deme: EvoTypes.Deme = village["deme"]
	var font := ThemeDB.fallback_font
	var to_screen: Transform2D = r._world_layer.transform
	var sf: float = village["sf"]

	# 1. Energy Delta Badge (+12.0 E in green or -8.5 E in red)
	var e_delta: float = float(r._deme_energy_delta.get(deme.id, 0.0))
	var e_text := "%+0.1f E" % e_delta
	var e_col := Color("#34d399") if e_delta >= 0.0 else Color("#fb7185")
	e_col.a = alpha
	var e_rect := Rect2(crest_pos.x - BADGE_W * 0.5 - 56.0, crest_pos.y - 10.0, 52.0, 20.0)
	ci.draw_rect(e_rect, Color(0.09, 0.06, 0.04, 0.92 * alpha), true)
	ci.draw_rect(e_rect, e_col, false, 1.4)
	ci.draw_string(font, Vector2(e_rect.position.x + 2.0, e_rect.position.y + 14.0), e_text, HORIZONTAL_ALIGNMENT_CENTER, e_rect.size.x - 4.0, 9, e_col)

	# 2. Evolutionary Progress Pips/Arcs (Baldwin /8, Innovation %, Isolation /10)
	var max_baldwin := 0
	for b_val in deme.baldwin_counters.values():
		max_baldwin = maxi(max_baldwin, int(b_val))
	var innov_pct := int(round(clampf(deme.innovation_counter, 0.0, 1.0) * 100.0))
	var iso_turns := clampi(deme.isolation_turns, 0, 10)

	var z_scale: float = r.camera.zoom_level if r.camera != null else 1.0
	var diag_w := 142.0
	var diag_h := 20.0
	var diag_y_off := maxf(46.0, 48.0 * sf * z_scale)
	var diag_rect := Rect2(screen_pos.x - diag_w * 0.5, screen_pos.y + diag_y_off, diag_w, diag_h)
	ci.draw_rect(diag_rect, Color(0.09, 0.06, 0.04, 0.90 * alpha), true)
	ci.draw_rect(diag_rect, Color(0.78, 0.65, 0.42, 0.72 * alpha), false, 1.2)

	var diag_str := "🧬%d/8  💡%d%%  🏝️%d/10" % [clampi(max_baldwin, 0, 8), innov_pct, iso_turns]
	ci.draw_string(
		font,
		Vector2(diag_rect.position.x + 4.0, diag_rect.position.y + 13.0),
		diag_str,
		HORIZONTAL_ALIGNMENT_CENTER,
		diag_w - 8.0,
		9,
		Color(0.98, 0.95, 0.84, alpha)
	)
	# Mini progress bar segments at bottom of diagnostic strip
	var seg_w := (diag_w - 12.0) / 3.0
	var ratios := [
		clampf(float(max_baldwin) / 8.0, 0.0, 1.0),
		clampf(deme.innovation_counter, 0.0, 1.0),
		clampf(float(iso_turns) / 10.0, 0.0, 1.0)
	]
	var bar_cols := [Color("#34d399"), Color("#fbbf24"), Color("#38bdf8")]
	for i in range(3):
		var bx := diag_rect.position.x + 4.0 + float(i) * (seg_w + 2.0)
		var by := diag_rect.end.y - 3.5
		ci.draw_rect(Rect2(bx, by, seg_w, 2.0), Color(0.25, 0.22, 0.18, 0.8 * alpha), true)
		var fc: Color = bar_cols[i]
		fc.a = alpha
		ci.draw_rect(Rect2(bx, by, seg_w * ratios[i], 2.0), fc, true)

	# 3. Compact labels on Ring 1 trait structures when zoom >= 1.55 or selected/hovered
	var show_trait_labels: bool = (
		(r.camera != null and r.camera.zoom_level >= 1.55)
		or deme.id == r.selected_deme_id
		or deme.id == r.hovered_deme_id
	)
	if show_trait_labels:
		var morph: Dictionary = village["morphology"]
		var ring_1: Array = morph["ring_1_traits"]
		var plaza_center := v_pos + Vector2(0.0, 6.0 * sf)
		var plinth_r := (56.0 if deme.merged_count > 0 else 51.0) * sf
		var ring1_rx := plinth_r * 0.84 * sf
		var ring1_ry := ring1_rx * 0.58
		for t_mod in ring_1:
			var t_name: String = t_mod["trait_label"]
			var ang := deg_to_rad(float(t_mod["angle_deg"]) - 90.0)
			var out_dir := Vector2(cos(ang), sin(ang))
			var t_world := plaza_center + Vector2(out_dir.x * ring1_rx, out_dir.y * ring1_ry)
			var t_scr := (to_screen * t_world) + Vector2(out_dir.x * 18.0, out_dir.y * 8.0 - 16.0)
			var lw := 68.0
			var lh := 14.0
			var l_rect := Rect2(t_scr.x - lw * 0.5, t_scr.y - lh * 0.5, lw, lh)
			var t_col: Color = t_mod["trait_color"]
			t_col.a = alpha
			ci.draw_rect(l_rect, Color(0.08, 0.06, 0.04, 0.86 * alpha), true)
			ci.draw_rect(l_rect, t_col, false, 1.0)
			ci.draw_string(font, Vector2(l_rect.position.x + 2.0, l_rect.position.y + 10.0), t_name, HORIZONTAL_ALIGNMENT_CENTER, lw - 4.0, 8, Color(0.98, 0.96, 0.90, alpha))


static func _draw_micro_phase_highlights(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var phase: int = r.active_micro_phase
	var pulse := fposmod(r._anim_time * 2.0, 1.0)
	var zoom_s: float = r.camera.zoom_level if r.camera != null else 1.0
	var font := ThemeDB.fallback_font

	if phase == 1:
		# Phase 1 (Environment): Expanding emerald/amber resource pulse ring on terrestrial hexes
		for hex_id in r._sorted_hex_ids:
			var cell: EvoTypes.HexCell = r.world_state.cells[hex_id]
			if r._is_water(cell) or not r._hex_centers.has(hex_id):
				continue
			var c_scr: Vector2 = to_screen * (r._hex_centers[hex_id] as Vector2)
			var k_ratio := clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
			var p_col := Color("#10b981") if k_ratio >= 0.75 else Color("#f59e0b")
			p_col.a = (1.0 - pulse) * 0.65
			var rad := lerpf(16.0, 56.0, pulse) * zoom_s
			draw_ellipse_outline(ci, c_scr, rad, rad * 0.58, p_col, 2.4)
	elif phase == 2:
		# Phase 2 (System 1 Decision): Prominent Decision Intent Crest + dashed intent tether
		for village in r._villages:
			var v_pos: Vector2 = village["pos"]
			var v_scr: Vector2 = to_screen * v_pos
			var crest_c := v_scr + Vector2(0.0, -102.0)
			var strat_col: Color = village["strat_color"]
			ci.draw_circle(crest_c, 16.0 + pulse * 6.0, Color(strat_col.r, strat_col.g, strat_col.b, (1.0 - pulse) * 0.65))
			ci.draw_circle(crest_c, 13.0, Color(0.10, 0.07, 0.04, 0.95))
			ci.draw_arc(crest_c, 13.0, 0.0, TAU, 20, C_SELECTION, 2.2)
			var dec_tex: ImageTexture = EvoPixelArtGen.get_texture("icon_" + str(village["archetype"]))
			ci.draw_texture_rect(dec_tex, Rect2(crest_c - Vector2(8.0, 8.0), Vector2(16.0, 16.0)), false)

			var hex_id: String = village["hex_id"]
			if r.world_state.cells.has(hex_id):
				var cell: EvoTypes.HexCell = r.world_state.cells[hex_id]
				for n_id in HexMath.get_neighbor_ids(cell.q, cell.r, r.world_state.cells):
					var ncell: EvoTypes.HexCell = r.world_state.cells[n_id]
					if not ncell.deme_ids.is_empty() and r._hex_centers.has(n_id):
						var n_scr: Vector2 = to_screen * (r._hex_centers[n_id] as Vector2)
						for seg_i in range(6):
							var t0 := float(seg_i) / 6.0
							var t1 := t0 + 0.08
							ci.draw_line(v_scr.lerp(n_scr, t0), v_scr.lerp(n_scr, t1), C_SELECTION, 2.0)
						break
	elif phase == 3:
		# Phase 3 (Ecology & Borders): Pulsing border clash / symbiosis ring on active shared hex edges
		for road in r._roads:
			var edge_mid: Vector2 = road.get("edge_mid", ((road["p_a"] as Vector2) + (road["p_b"] as Vector2)) * 0.5)
			var mid_scr: Vector2 = to_screen * edge_mid
			var is_conflict: bool = str(road.get("kind", "")) in ["dispute", "war", "siege", "raid", "betrayal"]
			var b_col := Color("#ef4444") if is_conflict else Color("#10b981")
			b_col.a = (1.0 - pulse) * 0.85
			var rad := lerpf(12.0, 44.0, pulse) * zoom_s
			ci.draw_arc(mid_scr, rad, 0.0, TAU, 24, b_col, 3.2)
	elif phase == 4:
		# Phase 4 (Demography & Milestones): Floating +Pop / -Pop delta indicator above settlements
		for village in r._villages:
			var deme: EvoTypes.Deme = village["deme"]
			var v_scr: Vector2 = to_screen * (village["pos"] as Vector2)
			var pop_delta: int = int(r._deme_pop_delta.get(deme.id, 0))
			var d_str := "%+d Pop" % pop_delta if r.lang == "en" else "%+d Hab" % pop_delta
			var d_col := Color("#34d399") if pop_delta >= 0 else Color("#fb7185")
			var float_pos := v_scr + Vector2(-32.0, -96.0 - pulse * 14.0)
			ci.draw_rect(Rect2(float_pos, Vector2(64.0, 18.0)), Color(0.08, 0.06, 0.04, 0.90), true)
			ci.draw_rect(Rect2(float_pos, Vector2(64.0, 18.0)), d_col, false, 1.5)
			ci.draw_string(font, float_pos + Vector2(2.0, 13.0), d_str, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 10, d_col)


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
	var top_text: String = strat_vis["short_label"]
	var status_col: Color = village["status_col"]

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

	var top_col := strat_color.lightened(0.35)
	top_col.a = alpha
	ci.draw_string(
		font,
		Vector2(rect.position.x + SHIELD_W + 5.0, rect.position.y + 12.0),
		top_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		badge_w - SHIELD_W - 8.0,
		10,
		top_col
	)

	# Vital status dot + population text
	var dot_col := status_col
	dot_col.a = alpha
	ci.draw_circle(Vector2(rect.position.x + SHIELD_W + 8.0, rect.position.y + 21.5), 3.0, dot_col)

	var pop_text: String = village["sub_text"]
	var pop_col := Color("#fde047") if is_selected else Color("#fef3c7")
	pop_col.a = alpha
	ci.draw_string(
		font,
		Vector2(rect.position.x + SHIELD_W + 14.0, rect.position.y + 25.0),
		pop_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		badge_w - SHIELD_W - 32.0,
		10,
		pop_col
	)

	var archetype: String = village["archetype"]
	var dec_tex: ImageTexture = EvoPixelArtGen.get_texture("icon_" + archetype)
	ci.draw_texture_rect(
		dec_tex,
		Rect2(Vector2(rect.end.x - 18.0, rect.position.y + 14.0), Vector2(14.0, 14.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)

	var geo_icons: Array = village["geo_icons"]
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
