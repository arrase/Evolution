class_name EvoEventFxRenderer
extends RefCounted

const MAJOR_TYPES: Array[String] = [
	"war", "war_repelled", "siege", "betrayal", "raid", "raid_repelled",
	"epidemic", "epidemic_spread", "famine", "extinction",
	"pact", "walled_union", "absorption", "allopatric_speciation",
	"demand_tribute"
]

const DIRECTIONAL_TYPES: Array[String] = [
	"war", "war_repelled", "siege", "raid", "raid_repelled",
	"tribute", "demand_tribute", "betrayal", "colonize", "absorption",
	"epidemic_spread", "symbiosis", "pillage",
	"offer_pact", "offer_union", "aid", "trade"
]

const BILATERAL_TYPES: Array[String] = ["pact", "walled_union"]
const REPELLED_TYPES: Array[String] = ["raid_repelled", "war_repelled"]
const DELTA_MAGNITUDE_TYPES: Array[String] = [
	"raid", "pillage", "betrayal", "war", "tribute",
	"aid", "trade", "colonize", "absorption"
]


static func enqueue_turn(r: Node2D, events: Array[Dictionary], replay_seconds: float) -> void:
	r._fx_active.clear()
	if events.is_empty():
		return

	var major: Array[Dictionary] = []
	var minor: Array[Dictionary] = []
	for ev in events:
		if MAJOR_TYPES.has(str(ev["type"])):
			major.append(ev)
		else:
			minor.append(ev)

	for ev in minor:
		var item := ev.duplicate()
		item["start"] = r._anim_time
		item["life"] = 1.55
		item["minor"] = true
		r._fx_active.append(item)

	if not major.is_empty():
		var slot := clampf(replay_seconds * 0.72 / maxf(1.0, float(major.size())), 0.12, 0.85)
		var major_life := maxf(1.65, slot * 2.15)
		for i in range(major.size()):
			var item := major[i].duplicate()
			item["start"] = r._anim_time + float(i) * slot
			item["life"] = major_life
			item["minor"] = false
			r._fx_active.append(item)


static func _get_event_icon_name(ev_type: String) -> String:
	match ev_type:
		"war":
			return "icon_war"
		"war_repelled", "raid_repelled", "fortify", "defense":
			return "icon_defense"
		"siege":
			return "icon_siege"
		"raid", "pillage":
			return "icon_raid"
		"betrayal":
			return "icon_betrayal"
		"vendetta":
			return "icon_vendetta"
		"pact", "offer_pact":
			return "icon_pact"
		"aid":
			return "icon_cooperate"
		"trade", "symbiosis":
			return "icon_exchange"
		"tribute", "demand_tribute":
			return "icon_tribute"
		"walled_union", "offer_union", "absorption", "merge":
			return "icon_merge"
		"colonize":
			return "icon_migrate"
		"epidemic", "epidemic_spread":
			return "icon_epidemic"
		"epidemic_recovered":
			return "icon_immune"
		"famine":
			return "icon_famine"
		"extinction":
			return "icon_casualties"
		"allopatric_speciation", "cultural_innovation", "baldwin_trait":
			return "icon_innovate"
	return "icon_custom"


static func _get_event_color(ev_type: String) -> Color:
	match ev_type:
		"raid_repelled", "war_repelled":
			return Color("#38bdf8")
		"offer_pact":
			return Color("#34d399")
		"offer_union":
			return Color("#fbbf24")
		"demand_tribute":
			return Color("#f59e0b")
		"aid":
			return Color("#2dd4bf")
		"trade":
			return Color("#38bdf8")
	return EvoUiStyle.get_event_type_color(ev_type)


static func _get_event_glyph(ev_type: String) -> String:
	match ev_type:
		"war", "raid", "pillage", "siege":
			return "⚔"
		"betrayal":
			return "🗡"
		"raid_repelled", "war_repelled", "fortify":
			return "🛡"
		"pact", "offer_pact", "symbiosis":
			return "🤝"
		"walled_union", "offer_union", "absorption", "merge":
			return "🏛"
		"tribute", "demand_tribute":
			return "🪙"
		"aid":
			return "🎁"
		"trade":
			return "⚖"
		"colonize":
			return "🚩"
		"epidemic", "epidemic_spread":
			return "☣"
		"epidemic_recovered":
			return "✚"
		"famine":
			return "🌾"
		"extinction":
			return "💀"
		"allopatric_speciation", "cultural_innovation", "baldwin_trait":
			return "🧬"
	return "•"


static func format_event_pill_text(ev: Dictionary, lang: String) -> String:
	var ev_type := str(ev["type"])
	var text := "%s %s" % [_get_event_glyph(ev_type), EvoI18n.event_verb(ev_type, lang)]
	var mag_i := int(round(float(ev["magnitude"])))
	if mag_i > 0 and DELTA_MAGNITUDE_TYPES.has(ev_type):
		text += " +%d" % mag_i
	var casualties := int(ev["casualties"])
	if casualties > 0:
		text += " -%d💀" % casualties
	return text


static func _sample_bezier(p_a: Vector2, ctrl: Vector2, p_b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u) * p_a + (2.0 * u * t) * ctrl + (t * t) * p_b


static func _draw_icon_medallion(ci: CanvasItem, pos: Vector2, icon_name: String, border_col: Color, alpha: float) -> void:
	var bg := Color(0.10, 0.06, 0.03, 0.92 * alpha)
	var b_col := border_col.lightened(0.18)
	b_col.a = alpha
	ci.draw_circle(pos, 11.5, bg)
	ci.draw_arc(pos, 11.5, 0.0, TAU, 20, b_col, 1.8)
	var tex: ImageTexture = EvoPixelArtGen.get_texture(icon_name)
	ci.draw_texture_rect(
		tex,
		Rect2(pos - Vector2(8.5, 8.5), Vector2(17.0, 17.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)


static func _draw_hex_wave(
	ci: CanvasItem,
	to_screen: Transform2D,
	center: Vector2,
	top_pts: PackedVector2Array,
	scale_r: float,
	col: Color,
	width: float
) -> void:
	var wave_pts := PackedVector2Array()
	wave_pts.resize(7)
	for i in range(7):
		wave_pts[i] = to_screen * center.lerp(top_pts[i % 6], scale_r)
	ci.draw_polyline(wave_pts, col, width)


static func _draw_curved_segment(
	ci: CanvasItem,
	p_a: Vector2,
	ctrl: Vector2,
	p_b: Vector2,
	s_from: float,
	s_to: float,
	col: Color,
	alpha: float,
	with_arrow: bool
) -> Vector2:
	var steps := 14
	var pts := PackedVector2Array()
	for s_i in range(steps + 1):
		var st := lerpf(s_from, s_to, float(s_i) / float(steps))
		pts.append(_sample_bezier(p_a, ctrl, p_b, st))
	var shadow_col := Color(0.07, 0.04, 0.02, 0.68 * alpha)
	var arc_col := col.lightened(0.14)
	arc_col.a = alpha
	ci.draw_polyline(pts, shadow_col, 5.6)
	ci.draw_polyline(pts, arc_col, 3.2)

	var tip := pts[pts.size() - 1]
	if with_arrow:
		var prev := pts[maxi(0, pts.size() - 2)]
		var fallback_dir := (p_b - p_a).normalized() if p_a.distance_to(p_b) > 0.01 else Vector2.RIGHT
		var tip_dir := (tip - prev).normalized() if tip.distance_to(prev) > 0.01 else fallback_dir
		var tip_perp := Vector2(-tip_dir.y, tip_dir.x)
		var tri := PackedVector2Array([
			tip + tip_dir * 6.5,
			tip - tip_dir * 7.5 + tip_perp * 5.8,
			tip - tip_dir * 7.5 - tip_perp * 5.8
		])
		ci.draw_colored_polygon(tri, arc_col)
		ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), shadow_col, 1.4)
	return tip


static func draw_event_fx(r: Node2D) -> void:
	draw_event_underlay(r)
	draw_event_floating_texts(r)


static func draw_event_underlay(r: Node2D) -> void:
	if r._fx_active.is_empty():
		return
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var now: float = r._anim_time

	var idx: int = (r._fx_active as Array).size() - 1
	while idx >= 0:
		var ev_chk: Dictionary = r._fx_active[idx]
		if now > float(ev_chk["start"]) + float(ev_chk["life"]):
			r._fx_active.remove_at(idx)
		idx -= 1

	for ev in r._fx_active:
		var start: float = float(ev["start"])
		if now < start:
			continue
		var life: float = float(ev["life"])
		var t := clampf((now - start) / maxf(0.01, life), 0.0, 1.0)
		var base_alpha := 0.80 if bool(ev["minor"]) else 0.96

		var ev_type := str(ev["type"])
		var from_hex := str(ev["from_hex"])
		var to_hex := str(ev["to_hex"])
		var col := _get_event_color(ev_type)
		var icon_name := _get_event_icon_name(ev_type)

		# Stage 1 (0.00 .. 0.25): Expanding pulse at origin hex
		if t <= 0.25:
			var origin_hex := from_hex if (from_hex != "" and r._hex_centers.has(from_hex) and r._hex_polys.has(from_hex)) else to_hex
			if r._hex_centers.has(origin_hex) and r._hex_polys.has(origin_hex):
				var p1 := clampf(t / 0.25, 0.0, 1.0)
				var pulse_col := col.lightened(0.20)
				pulse_col.a = base_alpha * (1.0 - p1 * 0.72)
				_draw_hex_wave(
					ci,
					to_screen,
					r._hex_centers[origin_hex] as Vector2,
					r._hex_polys[origin_hex] as PackedVector2Array,
					lerpf(0.24, 0.94, p1),
					pulse_col,
					3.0
				)

		# Stage 2 (0.15 .. 0.72): Projectile / emblem traveling along curved arc
		if t >= 0.15 and t <= 0.72:
			var p2 := clampf((t - 0.15) / 0.57, 0.0, 1.0)
			var fade2 := minf(clampf(p2 / 0.14, 0.0, 1.0), clampf((1.0 - p2) / 0.16, 0.0, 1.0))
			var alpha2 := base_alpha * fade2
			if alpha2 > 0.02:
				if from_hex != to_hex and r._hex_centers.has(from_hex) and r._hex_centers.has(to_hex):
					var p_a: Vector2 = to_screen * (r._hex_centers[from_hex] as Vector2)
					var p_b: Vector2 = to_screen * (r._hex_centers[to_hex] as Vector2)
					var diff := p_b - p_a
					var dist := diff.length()
					if dist > 4.0:
						var dir := diff / dist
						var perp := Vector2(-dir.y, dir.x)
						var start_pt := p_a + dir * minf(22.0, dist * 0.16)
						var end_pt := p_b - dir * minf(24.0, dist * 0.18)
						var lift := Vector2(0.0, -clampf(dist * 0.24, 22.0, 54.0))
						var ctrl := (start_pt + end_pt) * 0.5 + lift + perp * minf(dist * 0.08, 16.0)

						if REPELLED_TYPES.has(ev_type):
							var clash_s := 0.52
							var clash_pt := _sample_bezier(start_pt, ctrl, end_pt, clash_s)
							if p2 <= 0.52:
								var fwd := (p2 / 0.52) * clash_s
								var tail_s := maxf(0.0, fwd - 0.28)
								var atk_icon := "icon_war" if ev_type == "war_repelled" else "icon_raid"
								var tip_pt := _draw_curved_segment(ci, start_pt, ctrl, end_pt, tail_s, maxf(0.04, fwd), Color("#f97316"), alpha2, true)
								_draw_icon_medallion(ci, tip_pt, atk_icon, Color("#f97316"), alpha2)
							else:
								var recoil := clampf((p2 - 0.52) / 0.48, 0.0, 1.0)
								var bounce_end := start_pt.lerp(clash_pt, 0.20) + Vector2(0.0, 16.0)
								var bounce_ctrl := (clash_pt + bounce_end) * 0.5 + Vector2(0.0, -18.0)
								var b_tail := maxf(0.0, recoil - 0.35)
								var b_tip := _draw_curved_segment(ci, clash_pt, bounce_ctrl, bounce_end, b_tail, maxf(0.05, recoil), Color("#fb923c"), alpha2 * (1.0 - recoil * 0.35), false)
								var atk_icon := "icon_war" if ev_type == "war_repelled" else "icon_raid"
								_draw_icon_medallion(ci, b_tip, atk_icon, Color("#fb923c"), alpha2 * (1.0 - recoil * 0.45))

								# Blue/white shield flash at border clash point
								var flash_a := alpha2 * (1.0 - recoil * 0.65)
								ci.draw_circle(clash_pt, lerpf(11.0, 20.0, recoil), Color(0.88, 0.96, 1.0, 0.78 * flash_a))
								ci.draw_arc(clash_pt, lerpf(12.0, 28.0, recoil), 0.0, TAU, 24, Color(0.22, 0.74, 0.97, flash_a), 2.8)
								ci.draw_arc(clash_pt, lerpf(8.0, 18.0, recoil), 0.0, TAU, 20, Color(1.0, 1.0, 1.0, flash_a), 2.0)
								_draw_icon_medallion(ci, clash_pt, "icon_defense", Color("#e0f2fe"), flash_a)
						elif BILATERAL_TYPES.has(ev_type):
							var span_t := clampf(p2 * 1.25, 0.08, 1.0)
							_draw_curved_segment(ci, start_pt, ctrl + perp * 3.0, end_pt, 0.0, span_t, col, alpha2, false)
							var emb_pt := _sample_bezier(start_pt, ctrl, end_pt, 0.5 * span_t)
							_draw_icon_medallion(ci, emb_pt, icon_name, col, alpha2)
						elif DIRECTIONAL_TYPES.has(ev_type) or from_hex != to_hex:
							var tail_s := maxf(0.0, p2 - 0.42)
							var head_s := maxf(0.05, p2)
							var tip_pt := _draw_curved_segment(ci, start_pt, ctrl, end_pt, tail_s, head_s, col, alpha2, true)
							_draw_icon_medallion(ci, tip_pt, icon_name, col, alpha2)
				elif r._hex_centers.has(to_hex):
					var screen_center: Vector2 = to_screen * (r._hex_centers[to_hex] as Vector2)
					_draw_icon_medallion(ci, screen_center + Vector2(0.0, lerpf(-16.0, -34.0, p2)), icon_name, col, alpha2)

		# Stage 3 (0.50 .. 1.00): Impact wave on destination hex
		if t >= 0.50 and r._hex_polys.has(to_hex) and r._hex_centers.has(to_hex):
			var p3 := clampf((t - 0.50) / 0.50, 0.0, 1.0)
			var impact_col := col.lightened(0.18)
			impact_col.a = base_alpha * (1.0 - p3 * 0.82)
			_draw_hex_wave(
				ci,
				to_screen,
				r._hex_centers[to_hex] as Vector2,
				r._hex_polys[to_hex] as PackedVector2Array,
				lerpf(0.28, 0.96, p3),
				impact_col,
				3.2
			)


static func _resolve_event_target_deme(state: EvoTypes.WorldState, ev: Dictionary, to_hex: String) -> String:
	var raw_to := str(ev["to_deme"])
	if raw_to != "" and state.demes.has(raw_to):
		return raw_to
	if state.cells.has(to_hex):
		var cell: EvoTypes.HexCell = state.cells[to_hex]
		if not cell.deme_ids.is_empty() and state.demes.has(cell.deme_ids[0]):
			return cell.deme_ids[0]
	var raw_from := str(ev["from_deme"])
	if raw_from != "" and state.demes.has(raw_from):
		var fd: EvoTypes.Deme = state.demes[raw_from]
		if fd.urban_hex_ids.has(to_hex):
			return raw_from
	return ""


static func _intersect_ray_with_rect(origin: Vector2, dir: Vector2, bounds: Rect2) -> Vector2:
	var best_t := 1e9
	if absf(dir.x) > 0.0001:
		var tx := ((bounds.end.x if dir.x > 0.0 else bounds.position.x) - origin.x) / dir.x
		if tx > 0.0 and tx < best_t:
			best_t = tx
	if absf(dir.y) > 0.0001:
		var ty := ((bounds.end.y if dir.y > 0.0 else bounds.position.y) - origin.y) / dir.y
		if ty > 0.0 and ty < best_t:
			best_t = ty
	if best_t >= 1e8:
		return origin
	return origin + dir * best_t


static func _draw_soft_pill(
	ci: CanvasItem,
	font: Font,
	rect: Rect2,
	text: String,
	accent_col: Color,
	text_col: Color,
	alpha: float,
	font_size: int
) -> void:
	ci.draw_rect(Rect2(rect.position + Vector2(0.0, 3.0), rect.size).grow(1.5), Color(0.0, 0.0, 0.0, 0.34 * alpha), true)
	ci.draw_rect(Rect2(rect.position + Vector2(0.0, 1.5), rect.size), Color(0.0, 0.0, 0.0, 0.28 * alpha), true)
	ci.draw_rect(rect, Color(0.09, 0.06, 0.04, 0.94 * alpha), true)

	var strip_col := accent_col.lightened(0.16)
	strip_col.a = alpha
	ci.draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), strip_col, true)

	var border_col := accent_col.lightened(0.22)
	border_col.a = 0.92 * alpha
	ci.draw_rect(rect, border_col, false, 1.4)

	var fg := text_col
	fg.a = alpha
	ci.draw_string(
		font,
		Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y * 0.5 + float(font_size) * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 12.0,
		font_size,
		fg
	)


static func draw_event_floating_texts(r: Node2D) -> void:
	if r._fx_active.is_empty():
		return
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var font := ThemeDB.fallback_font
	var now: float = r._anim_time
	var lang: String = r.lang
	var state: EvoTypes.WorldState = r.world_state
	var vp_size := r.get_viewport_rect().size if r.is_inside_tree() else Vector2(1600.0, 960.0)
	var safe_rect := Rect2(Vector2.ZERO, vp_size).grow(-36.0)
	var ping_bounds := Rect2(Vector2(56.0, 56.0), Vector2(maxf(64.0, vp_size.x - 112.0), maxf(64.0, vp_size.y - 116.0)))
	var vp_center := vp_size * 0.5

	var stack_by_hex: Dictionary = {}
	var placed_pings: Array[Rect2] = []

	for ev in r._fx_active:
		var start: float = float(ev["start"])
		var life: float = float(ev["life"])
		if now < start or now > start + life:
			continue
		var to_hex := str(ev["to_hex"])
		if not r._hex_centers.has(to_hex):
			continue

		var t := clampf((now - start) / maxf(0.01, life), 0.0, 1.0)
		var ev_type := str(ev["type"])
		var col := _get_event_color(ev_type)
		var screen_pos: Vector2 = to_screen * (r._hex_centers[to_hex] as Vector2)

		# Off-screen edge ping when event occurs outside safe screen rect
		if not safe_rect.has_point(screen_pos):
			var ping_alpha := minf(clampf(t / 0.10, 0.0, 1.0), clampf((1.0 - t) / 0.20, 0.0, 1.0))
			if ping_alpha > 0.03:
				var diff := screen_pos - vp_center
				var dir := diff.normalized() if diff.length() > 0.01 else Vector2.RIGHT
				var edge_anchor := _intersect_ray_with_rect(vp_center, dir, ping_bounds)
				var ping_text := "%s %s" % [_get_event_glyph(ev_type), EvoI18n.event_verb(ev_type, lang)]
				var text_w := font.get_string_size(ping_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				var pw := maxf(68.0, text_w + 16.0)
				var ph := 22.0
				var ping_rect := Rect2(
					clampf(edge_anchor.x - pw * 0.5, 18.0, maxf(18.0, vp_size.x - pw - 18.0)),
					clampf(edge_anchor.y - ph * 0.5, 46.0, maxf(46.0, vp_size.y - ph - 52.0)),
					pw,
					ph
				)
				for existing in placed_pings:
					if ping_rect.intersects(existing.grow(3.0)):
						var shift_y := 25.0 if ping_rect.position.y + 25.0 + ph <= vp_size.y - 52.0 else -25.0
						ping_rect.position.y = clampf(ping_rect.position.y + shift_y, 46.0, maxf(46.0, vp_size.y - ph - 52.0))
				placed_pings.append(ping_rect)

				var pill_center := ping_rect.get_center()
				var arrow_base := pill_center + Vector2(dir.x * (pw * 0.5 + 2.0), dir.y * (ph * 0.5 + 2.0))
				var perp := Vector2(-dir.y, dir.x)
				var pulse := 0.80 + 0.20 * sin(now * 9.0)
				var arrow_col := col.lightened(0.24)
				arrow_col.a = ping_alpha * pulse
				var tri := PackedVector2Array([
					arrow_base + dir * 8.5,
					arrow_base - dir * 2.0 + perp * 5.2,
					arrow_base - dir * 2.0 - perp * 5.2
				])
				ci.draw_colored_polygon(tri, arrow_col)
				_draw_soft_pill(ci, font, ping_rect, ping_text, col, Color("#fff7ed"), ping_alpha, 11)

				var target_deme := _resolve_event_target_deme(state, ev, to_hex)
				r._deme_hit_rects.append({
					"rect": ping_rect.grow(4.0),
					"deme_id": target_deme,
					"hex_id": to_hex
				})
			continue

		# Stage 3 (0.50 .. 1.00): Crisp floating verb + delta pill at destination
		if t < 0.50:
			continue
		var p3 := clampf((t - 0.50) / 0.50, 0.0, 1.0)
		var pill_fade := minf(clampf(p3 / 0.16, 0.0, 1.0), clampf((1.0 - p3) / 0.28, 0.0, 1.0))
		var base_alpha := 0.88 if bool(ev["minor"]) else 0.98
		var alpha := base_alpha * pill_fade
		if alpha <= 0.02:
			continue

		var pill_text := format_event_pill_text(ev, lang)
		var txt_w := font.get_string_size(pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var pill_w := maxf(68.0, txt_w + 16.0)
		var pill_h := 20.0
		var hex_slot: int = int(stack_by_hex[to_hex]) if stack_by_hex.has(to_hex) else 0
		stack_by_hex[to_hex] = hex_slot + 1
		var y_off := -44.0 - p3 * 24.0 - float(hex_slot) * 23.0
		var rect := Rect2(screen_pos.x - pill_w * 0.5, screen_pos.y + y_off, pill_w, pill_h)
		_draw_soft_pill(ci, font, rect, pill_text, col, Color("#fef3c7"), alpha, 11)
