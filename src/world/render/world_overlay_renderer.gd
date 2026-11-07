class_name EvoWorldOverlayRenderer
extends RefCounted

const C_SELECTION := Color("#fde047")
const BADGE_W := 114.0
const BADGE_H := 30.0
const SHIELD_W := 26.0


static func _resolve_deme_strategy_visuals(world_state: EvoTypes.WorldState, deme: EvoTypes.Deme) -> Dictionary:
	var fallback_color := Color.from_string(deme.color, Color(0.88, 0.48, 0.37))
	var slot_tag := "A" if deme.strategy_id == world_state.strategy_a_id else ("B" if deme.strategy_id == world_state.strategy_b_id else "")
	if world_state.strategies_catalog.has(deme.strategy_id):
		var strategy: EvoTypes.StrategyDef = world_state.strategies_catalog[deme.strategy_id]
		var current_lang := (
			"en"
			if world_state.world_name != EvoI18n.preset_title("es", world_state.preset_id)
			and (
				strategy.name == EvoI18n.strategy_text(strategy.id, "name", "", "en")
				or (
					world_state.traits_catalog.has("bio-k-strategy")
					and (world_state.traits_catalog["bio-k-strategy"] as EvoTypes.TraitDef).name.begins_with("K-")
				)
			)
			else "es"
		)
		return {
			"icon": strategy.icon,
			"color": Color.from_string(strategy.color, fallback_color),
			"name": EvoI18n.strategy_name(current_lang, strategy),
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
	_draw_deme_billboards(r)
	draw_seasonal_particles(r)


static func _draw_deme_billboards(r: Node2D) -> void:
	var to_screen: Transform2D = r._world_layer.transform
	var vp_size := r.get_viewport_rect().size if r.is_inside_tree() else Vector2(1600.0, 960.0)
	var screen_cull_rect := Rect2(Vector2(-240.0, -200.0), vp_size + Vector2(480.0, 400.0))

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
		var strat_vis := _resolve_deme_strategy_visuals(r.world_state, deme)
		var strat_color: Color = strat_vis["color"]

		if not drawn_hex_rings.has(hex_id):
			drawn_hex_rings[hex_id] = true
			_draw_hex_strategy_ring(r, hex_id, screen_pos, sf, strat_color, alpha)

		r._deme_hit_rects.append({
			"rect": to_screen * (village["hit_rect"] as Rect2),
			"deme_id": deme.id,
			"hex_id": hex_id
		})
		var crest_pos: Vector2 = (to_screen * (v_pos + Vector2(0.0, -54.0 * sf))) + Vector2(0.0, -16.0)
		draw_village_billboard(r, village, crest_pos)


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

	var strat_vis := _resolve_deme_strategy_visuals(r.world_state, deme)
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
	shield_border.a = alpha
	ci.draw_rect(shield_rect, shield_border, false, 1.4)
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
	if top_text.length() > 13:
		top_text = top_text.substr(0, 12) + "…"
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

	var pop_text := "%d hab" % deme.population
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

	var archetype: String = village["archetype"]
	var dec_tex: ImageTexture = EvoPixelArtGen.get_texture("icon_" + archetype)
	ci.draw_texture_rect(
		dec_tex,
		Rect2(Vector2(rect.end.x - 18.0, rect.position.y + 14.0), Vector2(14.0, 14.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
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
