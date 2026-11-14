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


static func decision_label(state: EvoTypes.WorldState, lang: String, action_type: String) -> String:
	if state.decisions_catalog.has(action_type):
		return EvoI18n.decision_name(lang, state.decisions_catalog[action_type])
	var key := "decision." + action_type + ".name"
	var res := EvoI18n.t(lang, key)
	return res if res != key else action_type


static func _action_icon_name(action_type: String, fallback_archetype: String) -> String:
	match action_type:
		"forage":
			return "icon_forage"
		"intensify":
			return "icon_overexploit"
		"fortify":
			return "icon_defense"
		"innovate":
			return "icon_innovate"
		"settle":
			return "icon_migrate"
		"trade", "pay_tribute":
			return "icon_exchange"
		"aid":
			return "icon_cooperate"
		"offer_pact", "accept_pact":
			return "icon_pact"
		"unite", "accept_union":
			return "icon_merge"
		"demand_tribute":
			return "icon_tribute"
		"raid":
			return "icon_raid"
		"betray":
			return "icon_betrayal"
		"conquer":
			return "icon_war"
	return "icon_" + fallback_archetype


static func _intention_color(action_type: String) -> Color:
	match action_type:
		"raid", "demand_tribute":
			return Color("#f97316")
		"conquer":
			return Color("#ef4444")
		"betray":
			return Color("#e11d48")
		"offer_pact", "accept_pact", "aid":
			return Color("#34d399")
		"unite", "accept_union":
			return Color("#fbbf24")
		"trade", "pay_tribute":
			return Color("#38bdf8")
		"settle":
			return Color("#fde047")
	return Color("#cbd5e1")


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

	var now: float = r._anim_time
	if int((now - delta) * 12.0) != int(now * 12.0):
		var state: EvoTypes.WorldState = r.world_state
		for rel: EvoTypes.Relation in state.relations.values():
			if rel.proposal_kind != "":
				r._overlay_dirty = true
				break


static func draw_overlay(r: Node2D) -> void:
	if r.world_state == null:
		return
	r._deme_hit_rects.clear()
	draw_brush_radius_overlay(r)
	_draw_active_lens_overlay(r)
	_draw_pending_proposals(r)
	_draw_relational_focus_overlay(r)
	EvoEventFxRenderer.draw_event_underlay(r)
	_draw_deme_billboards(r)
	_draw_pending_proposal_bubbles(r)
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


static func _sample_bezier(p_a: Vector2, ctrl: Vector2, p_b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u) * p_a + (2.0 * u * t) * ctrl + (t * t) * p_b


static func _draw_dashed_screen_line(ci: CanvasItem, p_a: Vector2, p_b: Vector2, col: Color, width: float) -> void:
	var dist := p_a.distance_to(p_b)
	if dist < 4.0:
		return
	var steps := maxi(4, int(dist / 16.0))
	var dashes := PackedVector2Array()
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := minf(1.0, (float(i) + 0.56) / float(steps))
		dashes.append(p_a.lerp(p_b, t0))
		dashes.append(p_a.lerp(p_b, t1))
	if dashes.size() >= 2:
		ci.draw_multiline(dashes, col, width)


static func _draw_dotted_bezier_arc(
	ci: CanvasItem,
	p_a: Vector2,
	ctrl: Vector2,
	p_b: Vector2,
	col: Color,
	width: float,
	phase_offset: float,
	with_arrow: bool
) -> Vector2:
	var approx_len := p_a.distance_to(ctrl) + ctrl.distance_to(p_b)
	var segs := clampi(int(approx_len / 14.0), 6, 36)
	var shadow_dashes := PackedVector2Array()
	var main_dashes := PackedVector2Array()
	var shadow_col := Color(0.06, 0.03, 0.02, 0.60 * col.a)

	for i in range(segs):
		var s0 := (float(i) + phase_offset) / float(segs)
		if s0 >= 0.96:
			s0 -= 1.0
		var s1 := s0 + 0.52 / float(segs)
		var c0 := clampf(s0, 0.0, 0.96)
		var c1 := clampf(s1, 0.0, 0.96)
		if c1 - c0 < 0.008:
			continue
		var a_pt := _sample_bezier(p_a, ctrl, p_b, c0)
		var b_pt := _sample_bezier(p_a, ctrl, p_b, c1)
		shadow_dashes.append(a_pt)
		shadow_dashes.append(b_pt)
		main_dashes.append(a_pt)
		main_dashes.append(b_pt)

	if shadow_dashes.size() >= 2:
		ci.draw_multiline(shadow_dashes, shadow_col, width + 2.0)
		ci.draw_multiline(main_dashes, col, width)

	if with_arrow:
		var tip := _sample_bezier(p_a, ctrl, p_b, 0.98)
		var prev := _sample_bezier(p_a, ctrl, p_b, 0.90)
		var fallback_dir := (p_b - p_a).normalized() if p_a.distance_to(p_b) > 0.01 else Vector2.RIGHT
		var dir := (tip - prev).normalized() if tip.distance_to(prev) > 0.01 else fallback_dir
		var perp := Vector2(-dir.y, dir.x)
		var tri := PackedVector2Array([
			tip + dir * 5.5,
			tip - dir * 6.5 + perp * 4.8,
			tip - dir * 6.5 - perp * 4.8
		])
		ci.draw_colored_polygon(tri, col)

	return _sample_bezier(p_a, ctrl, p_b, 0.50)


static func _draw_solid_bezier_arc(
	ci: CanvasItem,
	p_a: Vector2,
	ctrl: Vector2,
	p_b: Vector2,
	col: Color,
	width: float
) -> Vector2:
	var steps := 18
	var pts := PackedVector2Array()
	pts.resize(steps + 1)
	for i in range(steps + 1):
		pts[i] = _sample_bezier(p_a, ctrl, p_b, float(i) / float(steps))
	ci.draw_polyline(pts, Color(0.06, 0.03, 0.02, 0.58 * col.a), width + 2.2)
	ci.draw_polyline(pts, col, width)
	return _sample_bezier(p_a, ctrl, p_b, 0.50)


static func _closest_urban_hex_pair(
	r: Node2D,
	state: EvoTypes.WorldState,
	d_a: EvoTypes.Deme,
	d_b: EvoTypes.Deme
) -> Array[String]:
	var best_ha := d_a.hex_id
	var best_hb := d_b.hex_id
	var best_dist := 999999
	for ha in d_a.urban_hex_ids:
		if not state.cells.has(ha) or not r._hex_centers.has(ha):
			continue
		var ca: EvoTypes.HexCell = state.cells[ha]
		for hb in d_b.urban_hex_ids:
			if not state.cells.has(hb) or not r._hex_centers.has(hb):
				continue
			var cb: EvoTypes.HexCell = state.cells[hb]
			var hd := HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r)
			if hd < best_dist:
				best_dist = hd
				best_ha = ha
				best_hb = hb
	return [best_ha, best_hb]


static func _draw_compact_tag_pill(
	ci: CanvasItem,
	font: Font,
	center: Vector2,
	text_str: String,
	border_col: Color,
	text_col: Color,
	font_size: int
) -> Rect2:
	var txt_w := font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pw := maxf(34.0, txt_w + 12.0)
	var ph := 17.0
	var rect := Rect2(center.x - pw * 0.5, center.y - ph * 0.5, pw, ph)
	ci.draw_rect(Rect2(rect.position + Vector2(0.0, 2.0), rect.size), Color(0.0, 0.0, 0.0, 0.36), true)
	ci.draw_rect(rect, Color(0.10, 0.06, 0.03, 0.92), true)
	ci.draw_rect(rect, border_col, false, 1.3)
	ci.draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + 12.5),
		text_str,
		HORIZONTAL_ALIGNMENT_CENTER,
		pw,
		font_size,
		text_col
	)
	return rect


static func _proposal_visuals(kind: String) -> Dictionary:
	match kind:
		"pact":
			return {"bubble": "🤝?", "color": Color("#34d399")}
		"union":
			return {"bubble": "🏛?", "color": Color("#fbbf24")}
		"tribute":
			return {"bubble": "🪙!", "color": Color("#f59e0b")}
	return {}


static func _draw_pending_proposals(r: Node2D) -> void:
	var state: EvoTypes.WorldState = r.world_state
	if state.relations.is_empty():
		return
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var phase := fposmod(r._anim_time * 1.6, 1.0)

	for pk_var in state.relations.keys():
		var rel: EvoTypes.Relation = state.relations[pk_var]
		if rel.proposal_kind not in ["pact", "union", "tribute"] or rel.proposal_from == "":
			continue
		var parts := str(pk_var).split("__")
		if parts.size() != 2 or not state.demes.has(parts[0]) or not state.demes.has(parts[1]):
			continue
		var sender_id := rel.proposal_from
		var receiver_id := parts[1] if parts[0] == sender_id else (parts[0] if parts[1] == sender_id else "")
		if receiver_id == "":
			continue
		var sender: EvoTypes.Deme = state.demes[sender_id]
		var receiver: EvoTypes.Deme = state.demes[receiver_id]
		var hex_pair := _closest_urban_hex_pair(r, state, sender, receiver)
		if not r._hex_centers.has(hex_pair[0]) or not r._hex_centers.has(hex_pair[1]):
			continue

		var p_from: Vector2 = to_screen * (r._hex_centers[hex_pair[0]] as Vector2)
		var p_to: Vector2 = to_screen * (r._hex_centers[hex_pair[1]] as Vector2)
		var diff := p_to - p_from
		var dist := diff.length()
		if dist < 8.0:
			continue
		var dir := diff / dist
		var s_pt := p_from + dir * minf(22.0, dist * 0.16)
		var e_pt := p_to - dir * minf(24.0, dist * 0.18)
		var ctrl := (s_pt + e_pt) * 0.5 + Vector2(0.0, -clampf(dist * 0.24, 22.0, 54.0))
		var vis := _proposal_visuals(rel.proposal_kind)
		var arc_col: Color = vis["color"]
		arc_col.a = 0.88
		_draw_dotted_bezier_arc(ci, s_pt, ctrl, e_pt, arc_col, 2.4, phase, true)


static func _draw_pending_proposal_bubbles(r: Node2D) -> void:
	var state: EvoTypes.WorldState = r.world_state
	if state.relations.is_empty():
		return
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var font := ThemeDB.fallback_font
	var bob := sin(r._anim_time * 4.2) * 2.0
	var slot_by_receiver: Dictionary = {}

	for pk_var in state.relations.keys():
		var rel: EvoTypes.Relation = state.relations[pk_var]
		if rel.proposal_kind not in ["pact", "union", "tribute"] or rel.proposal_from == "":
			continue
		var parts := str(pk_var).split("__")
		if parts.size() != 2 or not state.demes.has(parts[0]) or not state.demes.has(parts[1]):
			continue
		var sender_id := rel.proposal_from
		var receiver_id := parts[1] if parts[0] == sender_id else (parts[0] if parts[1] == sender_id else "")
		if receiver_id == "":
			continue
		var receiver: EvoTypes.Deme = state.demes[receiver_id]
		if not r._hex_centers.has(receiver.hex_id):
			continue

		var vis := _proposal_visuals(rel.proposal_kind)
		var col: Color = vis["color"]
		var bubble_text := str(vis["bubble"])
		var recv_slot: int = int(slot_by_receiver[receiver_id]) if slot_by_receiver.has(receiver_id) else 0
		slot_by_receiver[receiver_id] = recv_slot + 1

		var recv_screen: Vector2 = to_screen * (r._hex_centers[receiver.hex_id] as Vector2)
		var bubble_center := recv_screen + Vector2(34.0 + float(recv_slot) * 38.0, -32.0 + bob)
		var bw := 34.0
		var bh := 20.0
		var rect := Rect2(bubble_center.x - bw * 0.5, bubble_center.y - bh * 0.5, bw, bh)

		var tail_tip := Vector2(rect.position.x - 5.0, rect.end.y - 3.0)
		var tail_pts := PackedVector2Array([
			tail_tip,
			Vector2(rect.position.x + 1.0, rect.end.y - 9.0),
			Vector2(rect.position.x + 6.0, rect.end.y - 1.0)
		])
		ci.draw_rect(Rect2(rect.position + Vector2(0.0, 2.0), rect.size), Color(0.0, 0.0, 0.0, 0.40), true)
		ci.draw_colored_polygon(tail_pts, col)
		ci.draw_rect(rect, Color(0.10, 0.06, 0.03, 0.95), true)
		ci.draw_rect(rect, col, false, 1.6)
		ci.draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 14.0),
			bubble_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			bw,
			11,
			Color("#fffbeb")
		)
		r._deme_hit_rects.append({
			"rect": rect.grow(2.0),
			"deme_id": receiver.id,
			"hex_id": receiver.hex_id
		})


static func _draw_relational_focus_overlay(r: Node2D) -> void:
	var focus_id: String = r.hovered_deme_id if r.hovered_deme_id != "" else r.selected_deme_id
	var state: EvoTypes.WorldState = r.world_state
	if focus_id == "" or not state.demes.has(focus_id):
		return

	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var font := ThemeDB.fallback_font
	var focus_deme: EvoTypes.Deme = state.demes[focus_id]
	var strat_vis := _resolve_deme_strategy_visuals(state, focus_deme, r.lang)
	var faction_col: Color = strat_vis["color"]
	var has_cap: bool = r._hex_centers.has(focus_deme.hex_id)
	var cap_screen: Vector2 = (to_screen * (r._hex_centers[focus_deme.hex_id] as Vector2)) if has_cap else Vector2.ZERO

	# 1. Rural hexes owned by focus_deme: subtle faction corner brackets + faint dotted tether to capital
	var corner_col := faction_col.lightened(0.24)
	corner_col.a = 0.88
	var tether_col := faction_col.lightened(0.18)
	tether_col.a = 0.36
	for hex_id in r._rural_cell_ids:
		if not state.cells.has(hex_id) or not r._hex_polys.has(hex_id) or not r._hex_centers.has(hex_id):
			continue
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		if cell.owner_deme_id != focus_id or not cell.deme_ids.is_empty():
			continue
		var center: Vector2 = r._hex_centers[hex_id]
		var top_pts: PackedVector2Array = r._hex_polys[hex_id]
		var bracket_lines := PackedVector2Array()
		for v_i in range(6):
			var c_cur: Vector2 = to_screen * center.lerp(top_pts[v_i], 0.90)
			var c_prev: Vector2 = to_screen * center.lerp(top_pts[(v_i + 5) % 6], 0.90)
			var c_next: Vector2 = to_screen * center.lerp(top_pts[(v_i + 1) % 6], 0.90)
			bracket_lines.append(c_cur)
			bracket_lines.append(c_cur.lerp(c_prev, 0.24))
			bracket_lines.append(c_cur)
			bracket_lines.append(c_cur.lerp(c_next, 0.24))
		ci.draw_multiline(bracket_lines, corner_col, 2.0)

		if has_cap:
			var rural_screen: Vector2 = to_screen * center
			var diff_r := cap_screen - rural_screen
			var dist_r := diff_r.length()
			if dist_r > 18.0:
				var dir_r := diff_r / dist_r
				_draw_dashed_screen_line(
					ci,
					rural_screen + dir_r * minf(16.0, dist_r * 0.18),
					cap_screen - dir_r * minf(22.0, dist_r * 0.22),
					tether_col,
					1.5
				)

	# 2. Diplomatic arcs toward demes with active pact, feud, or truce
	for pk_var in state.relations.keys():
		var partner_id := EvoTypes.pair_partner(str(pk_var), focus_id)
		if partner_id == "" or not state.demes.has(partner_id):
			continue
		var rel: EvoTypes.Relation = state.relations[pk_var]
		var rel_col := Color.TRANSPARENT
		var rel_tag := ""
		if rel.pact_turns > 0:
			rel_col = Color("#10b981")
			rel_tag = "🤝 %dt" % rel.pact_turns
		elif rel.feud_turns > 0:
			rel_col = Color("#e11d48")
			rel_tag = "⚔ %dt" % rel.feud_turns
		elif rel.truce_turns > 0:
			rel_col = Color("#f59e0b")
			rel_tag = "🏳 %dt" % rel.truce_turns
		else:
			continue

		var partner: EvoTypes.Deme = state.demes[partner_id]
		var hex_pair := _closest_urban_hex_pair(r, state, focus_deme, partner)
		if not r._hex_centers.has(hex_pair[0]) or not r._hex_centers.has(hex_pair[1]):
			continue
		var p_a: Vector2 = to_screen * (r._hex_centers[hex_pair[0]] as Vector2)
		var p_b: Vector2 = to_screen * (r._hex_centers[hex_pair[1]] as Vector2)
		var diff := p_b - p_a
		var dist := diff.length()
		if dist < 8.0:
			continue
		var dir := diff / dist
		var s_pt := p_a + dir * minf(20.0, dist * 0.15)
		var e_pt := p_b - dir * minf(20.0, dist * 0.15)
		var ctrl := (s_pt + e_pt) * 0.5 + Vector2(0.0, -clampf(dist * 0.18, 18.0, 44.0))
		rel_col.a = 0.88
		var mid_pt := _draw_solid_bezier_arc(ci, s_pt, ctrl, e_pt, rel_col, 2.4)
		_draw_compact_tag_pill(ci, font, mid_pt, rel_tag, rel_col, Color("#fef3c7"), 10)

	# 3. Intention Arc (chosen_action with non-empty target)
	var chosen: Dictionary = focus_deme.chosen_action
	var target_str := str(chosen["target"]) if chosen.has("target") else ""
	var act_type := str(chosen["type"]) if chosen.has("type") else ""
	if target_str != "" and act_type != "":
		var orig_hex := focus_deme.hex_id
		var dest_hex := ""
		if state.demes.has(target_str):
			var target_deme: EvoTypes.Deme = state.demes[target_str]
			var pair := _closest_urban_hex_pair(r, state, focus_deme, target_deme)
			orig_hex = pair[0]
			dest_hex = pair[1]
		elif state.cells.has(target_str):
			dest_hex = target_str
			var t_cell: EvoTypes.HexCell = state.cells[dest_hex]
			var best_d := 999999
			for uh in focus_deme.urban_hex_ids:
				if state.cells.has(uh) and r._hex_centers.has(uh):
					var uc: EvoTypes.HexCell = state.cells[uh]
					var d_val := HexMath.hex_distance(uc.q, uc.r, t_cell.q, t_cell.r)
					if d_val < best_d:
						best_d = d_val
						orig_hex = uh

		if dest_hex != "" and orig_hex != dest_hex and r._hex_centers.has(orig_hex) and r._hex_centers.has(dest_hex):
			var p_from: Vector2 = to_screen * (r._hex_centers[orig_hex] as Vector2)
			var p_to: Vector2 = to_screen * (r._hex_centers[dest_hex] as Vector2)
			var diff_i := p_to - p_from
			var dist_i := diff_i.length()
			if dist_i >= 8.0:
				var dir_i := diff_i / dist_i
				var s_i := p_from + dir_i * minf(22.0, dist_i * 0.16)
				var e_i := p_to - dir_i * minf(22.0, dist_i * 0.18)
				var ctrl_i := (s_i + e_i) * 0.5 + Vector2(0.0, -clampf(dist_i * 0.30, 32.0, 70.0))
				var int_col := _intention_color(act_type)
				int_col.a = 0.94
				var apex := _draw_dotted_bezier_arc(ci, s_i, ctrl_i, e_i, int_col, 2.4, 0.0, true)
				var act_label := "🎯 " + decision_label(state, r.lang, act_type)
				_draw_compact_tag_pill(ci, font, apex + Vector2(0.0, -4.0), act_label, int_col, Color("#fffbeb"), 10)


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
		for d: EvoTypes.Deme in state.demes.values():
			if not d.is_multi_hex():
				continue
			var n_urb := d.urban_hex_ids.size()
			for i in range(n_urb):
				var h_a := d.urban_hex_ids[i]
				if not state.cells.has(h_a) or not r._hex_centers.has(h_a):
					continue
				var c_a: EvoTypes.HexCell = state.cells[h_a]
				for j in range(i + 1, n_urb):
					var h_b := d.urban_hex_ids[j]
					if not state.cells.has(h_b) or not r._hex_centers.has(h_b):
						continue
					var c_b: EvoTypes.HexCell = state.cells[h_b]
					if HexMath.hex_distance(c_a.q, c_a.r, c_b.q, c_b.r) != 1:
						continue
					var p_a: Vector2 = to_screen * (r._hex_centers[h_a] as Vector2)
					var p_b: Vector2 = to_screen * (r._hex_centers[h_b] as Vector2)
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
			var pair := _closest_urban_hex_pair(r, state, d_a, d_b)
			var best_ha := pair[0]
			var best_hb := pair[1]
			if not r._hex_centers.has(best_ha) or not r._hex_centers.has(best_hb):
				continue
			var p_a: Vector2 = to_screen * (r._hex_centers[best_ha] as Vector2)
			var p_b: Vector2 = to_screen * (r._hex_centers[best_hb] as Vector2)
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
				_draw_dashed_screen_line(ci, p_a, p_b, Color("#f59e0b"), 2.2)

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
			elif flow.flow_type in ["war", "siege", "raid", "raid_repelled", "tribute", "betrayal"]:
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
				if bool(village["is_capital"]):
					_draw_lens_icon_pill(
						ci,
						font,
						screen_center + Vector2(0.0, -28.0),
						"icon_epidemic",
						"%dt" % deme.infection_turns,
						Color("#84cc16")
					)
			elif deme.immunity_turns > 0:
				ci.draw_polyline(ring_pts, Color("#06b6d4"), 3.2 * sqrt(inv_zoom))
				if bool(village["is_capital"]):
					_draw_lens_icon_pill(
						ci,
						font,
						screen_center + Vector2(0.0, -28.0),
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
			if not bool(village["is_capital"]):
				continue
			var deme: EvoTypes.Deme = village["deme"]
			var hex_id: String = village["hex_id"]
			if not r._hex_centers.has(hex_id):
				continue
			var screen_center: Vector2 = to_screen * (r._hex_centers[hex_id] as Vector2)
			var ratio := (deme.last_food_intake / maxf(1.0, deme.last_food_need)) if deme.last_food_need > 0.0 else 1.0
			var pct := int(round(clampf(ratio, 0.0, 2.5) * 100.0))
			var col := Color("#10b981") if pct >= 100 else (Color("#f59e0b") if pct >= 75 else Color("#ef4444"))
			_draw_lens_icon_pill(ci, font, screen_center + Vector2(0.0, -28.0), "icon_forage", "%d%%" % pct, col)

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

		var is_merged: bool = deme.merged_count > 0 or deme.is_multi_hex()
		var plinth_r: float = (58.0 if is_merged else 52.0) * zoom_val
		var plaza_screen: Vector2 = to_screen * (v_pos + Vector2(0.0, 8.0))
		var modulate_col: Color = village["modulate"]
		if bool(village["in_siege"]):
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

		var raw_bldg_rect: Rect2 = to_screen * (village["hit_rect"] as Rect2)
		var min_center_rect := Rect2(screen_pos - Vector2(26.0, 26.0), Vector2(52.0, 52.0))
		r._deme_hit_rects.append({
			"rect": raw_bldg_rect.merge(min_center_rect),
			"deme_id": deme.id,
			"hex_id": hex_id
		})

		if bool(village["is_capital"]):
			var foot_pos: Vector2 = (to_screen * (v_pos + Vector2(0.0, 54.0))) + Vector2(0.0, 8.0 if is_macro else 0.0)
			draw_village_billboard(r, village, foot_pos)


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
		ring_col.a = 0.34
		ci.draw_polyline(border_pts, ring_col, 1.5)

		if hex_id == r.selected_hex_id or hex_id == r.hovered_hex_id:
			var strat_vis := _resolve_deme_strategy_visuals(state, owner_deme, r.lang)
			var short_name := str(strat_vis["name"]).split(" ")[0]
			var slot_tag := str(strat_vis["slot_tag"])
			var tag_str := ("%s·%s" % [slot_tag, short_name]) if slot_tag != "" else short_name
			var txt_w := font.get_string_size(tag_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var pill_w := maxf(76.0, txt_w + 26.0)
			var pill_h := 18.0
			var pill_rect := Rect2(screen_pos.x - pill_w * 0.5, screen_pos.y - 30.0, pill_w, pill_h)
			ci.draw_rect(pill_rect, Color(0.11, 0.07, 0.04, 0.88), true)
			ci.draw_rect(pill_rect, strat_color, false, 1.4)
			var icon_name := "icon_forage" if cell.land_use == "crops" else "icon_cooperate"
			var icon_tex: ImageTexture = EvoPixelArtGen.get_texture(icon_name)
			ci.draw_texture_rect(
				icon_tex,
				Rect2(pill_rect.position + Vector2(3.0, 2.0), Vector2(14.0, 14.0)),
				false
			)
			ci.draw_string(
				font,
				Vector2(pill_rect.position.x + 20.0, pill_rect.position.y + 13.0),
				tag_str,
				HORIZONTAL_ALIGNMENT_LEFT,
				pill_w - 23.0,
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


static func _short_posture_text(posture: String, lang: String) -> String:
	var is_en := lang == "en"
	match posture:
		"patrol_fields":
			return "🛡 Patrol" if is_en else "🛡 Patrulla"
		"mobilized_garrison":
			return "⚔ Garrison" if is_en else "⚔ Guarnición"
	return "🌾 Open" if is_en else "🌾 Abierta"


static func _compact_traits_summary(state: EvoTypes.WorldState, deme: EvoTypes.Deme, lang: String) -> String:
	var bio_n := deme.biological_trait_ids.size()
	var cul_n := deme.cultural_trait_ids.size()
	var summary := "🧬%d 🔥%d" % [bio_n, cul_n]
	var labels: Array[String] = []
	var combined := deme.cultural_trait_ids + deme.biological_trait_ids
	for tid in combined:
		if state.traits_catalog.has(tid):
			var full_name := EvoI18n.trait_name(lang, state.traits_catalog[tid])
			var word := full_name.split(" ")[0]
			if word.length() > 11:
				word = word.substr(0, 10) + "…"
			labels.append(word)
			if labels.size() >= 2:
				break
	if not labels.is_empty():
		summary += " · " + ", ".join(labels)
	return summary


static func draw_village_billboard(r: Node2D, village: Dictionary, pos: Vector2) -> void:
	var ci: Node2D = r._overlay_layer
	var state: EvoTypes.WorldState = r.world_state
	var deme: EvoTypes.Deme = village["deme"]
	var is_dimmed: bool = village["is_dimmed"]
	var font := ThemeDB.fallback_font
	var zoom_val: float = r.camera.zoom_level if r.camera != null else 1.0
	var is_macro: bool = zoom_val < 0.30

	var strat_vis: Dictionary = village["strat_visuals"]
	var strat_color: Color = strat_vis["color"]
	var strat_name: String = strat_vis["name"]
	var strat_letter: String = str(strat_vis["slot_tag"])
	if strat_letter == "":
		strat_letter = "B" if EvoTypes._is_side_b_deme(state, deme) else "A"

	var is_selected: bool = deme.id == r.selected_deme_id
	var is_hovered: bool = deme.id == r.hovered_deme_id
	var is_highlighted: bool = r.highlighted_lineage_id != "" and deme.lineage_id == r.highlighted_lineage_id
	var alpha := 0.48 if is_dimmed else 0.96

	var short_name := strat_letter
	if not is_macro:
		short_name = strat_name.split(" ")[0]
		if short_name.length() > 11:
			short_name = short_name.substr(0, 10) + "…"

	var main_text := "%s · %d" % [short_name, deme.population]
	var font_sz := 10 if is_macro else 11
	var shield_w := 20.0 if is_macro else 24.0
	var action_col_w := 18.0 if is_macro else 21.0
	var txt_w := font.get_string_size(main_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
	var badge_w := shield_w + maxf(50.0 if is_macro else 74.0, txt_w + 12.0) + action_col_w
	var badge_h := 20.0 if is_macro else 23.0
	var rect := Rect2(pos.x - badge_w * 0.5, pos.y - badge_h * 0.5, badge_w, badge_h)

	if is_selected or is_hovered or is_highlighted:
		var glow_col := C_SELECTION if is_selected else strat_color.lightened(0.30)
		glow_col.a = 0.42 * alpha
		ci.draw_rect(rect.grow(2.0), glow_col, false, 2.0)
		var pip_tip := Vector2(pos.x, rect.position.y - 4.5)
		var pip_col := C_SELECTION if is_selected else strat_color.lightened(0.28)
		pip_col.a = alpha
		ci.draw_colored_polygon(
			PackedVector2Array([pip_tip, pip_tip + Vector2(-4.5, 4.5), pip_tip + Vector2(4.5, 4.5)]),
			pip_col
		)

	# Drop shadow + dark parchment-wood base
	ci.draw_rect(Rect2(rect.position + Vector2(0.0, 2.5), rect.size), Color(0.0, 0.0, 0.0, 0.40 * alpha), true)
	ci.draw_rect(rect, Color(0.10, 0.06, 0.04, 0.93 * alpha), true)

	# Left heraldic shield [Escudo Color + Tier Romano]
	var shield_rect := Rect2(rect.position, Vector2(shield_w, badge_h))
	var shield_fill := strat_color.darkened(0.20)
	shield_fill.a = 0.96 * alpha
	ci.draw_rect(shield_rect, shield_fill, true)
	var crest_top := strat_color.lightened(0.08)
	crest_top.a = 0.45 * alpha
	ci.draw_rect(Rect2(shield_rect.position, Vector2(shield_w, badge_h * 0.46)), crest_top, true)
	if deme.secondary_color != "":
		var sec_col := Color.from_string(deme.secondary_color, strat_color)
		sec_col.a = 0.78 * alpha
		ci.draw_rect(Rect2(shield_rect.position.x, shield_rect.end.y - 4.0, shield_w, 4.0), sec_col, true)

	var shield_border := strat_color.lightened(0.18)
	var shield_border_w := 1.4
	if deme.defense_tier == 1:
		shield_border = Color("#b45309")
		shield_border_w = 1.8
	elif deme.defense_tier == 2:
		shield_border = Color("#cbd5e1")
		shield_border_w = 2.0
	elif deme.defense_tier >= 3:
		shield_border = Color("#fbbf24")
		shield_border_w = 2.4
	shield_border.a = alpha
	ci.draw_rect(shield_rect, shield_border, false, shield_border_w)

	var tier_roman := deme.get_village_roman()
	ci.draw_string(
		font,
		Vector2(shield_rect.position.x, shield_rect.position.y + (14.0 if is_macro else 15.5)),
		tier_roman,
		HORIZONTAL_ALIGNMENT_CENTER,
		shield_w,
		9 if is_macro else 10,
		Color(1.0, 0.98, 0.92, alpha)
	)

	# Center label: Nombre Corto · Pob
	var pop_col := Color("#fde047") if is_selected else Color("#fef3c7")
	pop_col.a = alpha
	ci.draw_string(
		font,
		Vector2(rect.position.x + shield_w + 6.0, rect.position.y + (13.5 if is_macro else 15.0)),
		main_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		badge_w - shield_w - action_col_w - 8.0,
		font_sz,
		pop_col
	)

	# Right divider + [Icono Acción]
	var sep_x := rect.end.x - action_col_w
	ci.draw_line(
		Vector2(sep_x, rect.position.y + 3.0),
		Vector2(sep_x, rect.end.y - 5.0),
		Color(1.0, 0.94, 0.82, 0.24 * alpha),
		1.0
	)
	var chosen: Dictionary = deme.chosen_action
	var act_type := str(chosen["type"]) if chosen.has("type") else ""
	var icon_name := _action_icon_name(act_type, str(village["archetype"]))
	var icon_sz := 13.0 if is_macro else 14.0
	var icon_pos := Vector2(
		sep_x + (action_col_w - icon_sz) * 0.5,
		rect.position.y + (badge_h - 3.0 - icon_sz) * 0.5
	)
	var dec_tex: ImageTexture = EvoPixelArtGen.get_texture(icon_name)
	ci.draw_texture_rect(dec_tex, Rect2(icon_pos, Vector2(icon_sz, icon_sz)), false, Color(1.0, 1.0, 1.0, alpha))

	# Bottom 3 px micro-bar for reserves (left) and salubrity/health (right)
	var is_starving := deme.get_vital_status() == "starving"
	var bar_x := rect.position.x + shield_w + 1.0
	var bar_total_w := rect.end.x - bar_x - 1.0
	var bar_y := rect.end.y - 3.0
	var half_w := maxf(4.0, (bar_total_w - 2.0) * 0.5)

	var res_cap := maxf(45.0, float(deme.population) * 1.1)
	var res_ratio := clampf(deme.energy_reserves / res_cap, 0.06, 1.0)
	var res_col := Color("#ef4444") if is_starving else Color("#fbbf24")
	res_col.a = alpha
	ci.draw_rect(Rect2(bar_x, bar_y, half_w, 3.0), Color(0.0, 0.0, 0.0, 0.56 * alpha), true)
	ci.draw_rect(Rect2(bar_x, bar_y, half_w * res_ratio, 3.0), res_col, true)

	var sal_ratio := clampf(deme.salubrity, 0.06, 1.0)
	var sal_col := Color("#10b981") if deme.salubrity >= 0.70 else (Color("#f59e0b") if deme.salubrity >= 0.40 else Color("#ef4444"))
	if deme.infection_turns > 0:
		sal_col = Color("#84cc16")
	sal_col.a = alpha
	var sal_x := bar_x + half_w + 2.0
	ci.draw_rect(Rect2(sal_x, bar_y, half_w, 3.0), Color(0.0, 0.0, 0.0, 0.56 * alpha), true)
	ci.draw_rect(Rect2(sal_x, bar_y, half_w * sal_ratio, 3.0), sal_col, true)

	var border_col := (
		C_SELECTION
		if is_selected
		else (strat_color.lightened(0.35) if (is_hovered or is_highlighted) else strat_color)
	)
	border_col.a = alpha
	var border_w := 2.0 if is_selected else (1.7 if (is_hovered or is_highlighted) else 1.3)
	ci.draw_rect(rect, border_col, false, border_w)

	var hit_rect := rect
	if is_selected or is_hovered:
		var line1 := "%s · 🧠 %d%%" % [_short_posture_text(deme.defense_posture, r.lang), int(round(deme.last_confidence * 100.0))]
		var line2 := _compact_traits_summary(state, deme, r.lang)
		var w1 := font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var w2 := font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var detail_w := clampf(maxf(badge_w, maxf(w1, w2) + 14.0), badge_w, 214.0)
		var detail_h := 28.0
		var detail_rect := Rect2(pos.x - detail_w * 0.5, rect.end.y + 2.0, detail_w, detail_h)

		ci.draw_rect(Rect2(detail_rect.position + Vector2(0.0, 2.0), detail_rect.size), Color(0.0, 0.0, 0.0, 0.36 * alpha), true)
		ci.draw_rect(detail_rect, Color(0.09, 0.06, 0.03, 0.94 * alpha), true)
		ci.draw_rect(detail_rect, border_col, false, 1.2)

		var l1_col := Color("#fef3c7")
		l1_col.a = alpha
		ci.draw_string(
			font,
			Vector2(detail_rect.position.x + 6.0, detail_rect.position.y + 12.0),
			line1,
			HORIZONTAL_ALIGNMENT_LEFT,
			detail_w - 12.0,
			10,
			l1_col
		)
		var l2_col := Color("#cbd5e1")
		l2_col.a = alpha
		ci.draw_string(
			font,
			Vector2(detail_rect.position.x + 6.0, detail_rect.position.y + 23.5),
			line2,
			HORIZONTAL_ALIGNMENT_LEFT,
			detail_w - 12.0,
			9,
			l2_col
		)
		hit_rect = rect.merge(detail_rect)

	r._deme_hit_rects.append({"rect": hit_rect, "deme_id": deme.id, "hex_id": str(village["hex_id"])})


static func draw_seasonal_particles(r: Node2D) -> void:
	var ci: Node2D = r._overlay_layer
	var is_wet: bool = r.world_state.season == "wet_warm"
	for p in r._particles:
		var sz: float = p["size"]
		var glow := 0.45 + 0.35 * sin(float(p["phase"]) * 2.0)
		var col := Color(1.0, 0.88, 0.38, glow) if is_wet else Color(0.90, 0.96, 1.0, glow)
		ci.draw_rect(Rect2(Vector2(float(p["x"]), float(p["y"])), Vector2(sz, sz)), col, true)
