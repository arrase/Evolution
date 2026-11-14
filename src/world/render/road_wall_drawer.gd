class_name EvoRoadWallDrawer
extends RefCounted

const WALL_RADIUS: float = 0.78
const FRONT_EPS: float = 0.5
const EDGE_DIR_MAP: Array[int] = [0, 5, 4, 3, 2, 1]
const INK := Color("#23150c")


static func sample_road_curve(
	p_a: Vector2,
	p_b: Vector2,
	t: float,
	curve_sign: float,
	curve_factor: float = 0.045
) -> Vector2:
	var diff := p_b - p_a
	var dist := diff.length()
	var perp := Vector2(-diff.y, diff.x).normalized() if dist > 0.01 else Vector2.UP
	var ctrl := (p_a + p_b) * 0.5 + perp * (minf(dist * curve_factor, 12.0) * curve_sign)
	var u := 1.0 - t
	return (u * u) * p_a + (2.0 * u * t) * ctrl + (t * t) * p_b


static func bridge_arch_point(p_a: Vector2, p_b: Vector2, t: float) -> Vector2:
	return p_a.lerp(p_b, t) + Vector2(0, sin(t * PI) * -10.0)


static func sample_road_path(road: Dictionary, t: float, curve_sign: float = 1.0) -> Vector2:
	if str(road.get("kind", "")) == "bridge":
		return bridge_arch_point(road["p_a"] as Vector2, road["p_b"] as Vector2, t)
	if road.has("points"):
		var pts: PackedVector2Array = road["points"]
		var l0 := pts[0].distance_to(pts[1])
		var l1 := pts[1].distance_to(pts[2])
		var l2 := pts[2].distance_to(pts[3])
		var total := l0 + l1 + l2
		if total < 0.01:
			return pts[0]
		var target := clampf(t, 0.0, 1.0) * total
		if target <= l0:
			return pts[0].lerp(pts[1], target / maxf(0.01, l0))
		if target <= l0 + l1:
			return pts[1].lerp(pts[2], (target - l0) / maxf(0.01, l1))
		return pts[2].lerp(pts[3], (target - l0 - l1) / maxf(0.01, l2))
	var curve_f: float = float(road.get("curve_factor", 0.045))
	return sample_road_curve(road["p_a"] as Vector2, road["p_b"] as Vector2, t, curve_sign, curve_f)


static func build_road_polyline(road: Dictionary, segments: int = 24, curve_sign: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if road.has("points"):
		var raw: PackedVector2Array = road["points"]
		var n0 := maxi(2, segments * 2 / 5)
		var n1 := maxi(2, segments / 5)
		var n2 := maxi(2, segments - n0 - n1)
		for i in range(n0):
			out.append(raw[0].lerp(raw[1], float(i) / float(n0)))
		for i in range(n1):
			out.append(raw[1].lerp(raw[2], float(i) / float(n1)))
		for i in range(n2 + 1):
			out.append(raw[2].lerp(raw[3], float(i) / float(n2)))
		return out
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	for i in range(segments + 1):
		out.append(sample_road_curve(p_a, p_b, float(i) / float(segments), curve_sign, curve_f))
	return out


static func draw_cliff_ramp_steps(
	ci: CanvasItem,
	road: Dictionary,
	width: float,
	tread_col: Color,
	border_col: Color
) -> void:
	if not road.has("points"):
		return
	var r_pts: PackedVector2Array = road["points"]
	var rim_a: Vector2 = r_pts[1]
	var rim_b: Vector2 = r_pts[2]
	var slope := rim_b - rim_a
	var slope_len := slope.length()
	if slope_len < 4.0:
		return
	var dir := slope / slope_len
	var perp := Vector2(-dir.y, dir.x)
	var hw := width * 0.5
	ci.draw_line(rim_a - perp * (hw + 1.8), rim_b - perp * (hw + 1.8), border_col, 3.0)
	ci.draw_line(rim_a + perp * (hw + 1.8), rim_b + perp * (hw + 1.8), border_col, 3.0)
	var step_count := clampi(int(slope_len / 5.5), 3, 10)
	for s_i in range(1, step_count):
		var sc := rim_a.lerp(rim_b, float(s_i) / float(step_count))
		ci.draw_line(sc - perp * hw, sc + perp * hw, border_col, 2.5)
		ci.draw_line(sc - perp * (hw - 1.0) + Vector2(0.0, -1.0), sc + perp * (hw - 1.0) + Vector2(0.0, -1.0), tread_col, 1.8)


static func draw_network_roads(r: Node2D) -> void:
	var has_cull: bool = r._visible_world_rect.size != Vector2.ZERO
	var cull_rect: Rect2 = r._visible_world_rect.grow(HexMath.HEX_SIZE * 1.5) if has_cull else Rect2()
	for road in r._roads:
		if has_cull:
			var p_a: Vector2 = road["p_a"]
			var p_b: Vector2 = road["p_b"]
			if not cull_rect.has_point(p_a) and not cull_rect.has_point(p_b):
				continue
		match road["kind"]:
			"pact":
				draw_pact_highway(r, road)
			"merge":
				draw_merge_avenue(r, road)
			"tribute":
				draw_tribute_route(r, road)
			"war", "siege":
				draw_war_corridor(r, road)
			"raid":
				draw_raid_trail(r, road)
			"betrayal":
				draw_betrayal_road(r, road)
			"collab":
				draw_collaboration_route(r, road)
			"bridge":
				draw_wooden_bridge(r, road)
			"dispute":
				draw_dispute_barricade_front(r, road)
			"broken":
				draw_broken_cut_road(r, road)
			"expedition":
				draw_migration_expedition(r, road)
			"rural_farm":
				draw_rural_farm_track(r, road)
	draw_settlement_back_walls(r)


static func draw_animated_roads(r: Node2D) -> void:
	var anim_layer: Node2D = r._anim_layer
	var vis_rect: Rect2 = r._visible_world_rect
	var anim_time: float = r._anim_time
	for road in r._roads:
		if not bool(road.get("active_flow", false)):
			continue
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not vis_rect.has_point(p_a) and not vis_rect.has_point(p_b):
			continue
		match road["kind"]:
			"pact":
				if bool(road.get("show_traffic", true)):
					var diff := p_b - p_a
					var perp := Vector2(-diff.y, diff.x).normalized() if diff.length() > 0.01 else Vector2.UP
					var raw_t1 := fposmod(anim_time * 0.34 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var raw_t2 := fposmod(raw_t1 + 0.5, 1.0)
					var pos_1 := sample_road_path(road, lerpf(0.18, 0.82, raw_t1), 1.0) + perp * 3.2 + Vector2(0, -6.0)
					var pos_2 := sample_road_path(road, lerpf(0.82, 0.18, raw_t2), 1.0) - perp * 3.2 + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", pos_1, 1.55)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", pos_2, 1.55)
			"merge":
				if bool(road.get("show_traffic", true)):
					var raw_m := fposmod(anim_time * 0.36 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var wagon_pos := sample_road_path(road, lerpf(0.18, 0.82, raw_m), 1.0) + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "settler_wagon", wagon_pos, 1.55)
			"tribute":
				if bool(road.get("show_traffic", true)):
					var raw_tr := fposmod(anim_time * 0.36 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var cart_pos := sample_road_path(road, lerpf(0.18, 0.82, raw_tr), 1.0) + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", cart_pos, 1.55)
			"war", "siege":
				draw_war_animated_invasion(r, road)
			"raid":
				draw_raid_animated_plunder(r, road)
			"betrayal":
				draw_betrayal_animated_ruin(r, road)
			"collab":
				if bool(road.get("show_traffic", true)):
					var raw_t := fposmod(anim_time * 0.32 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var cart_pos := sample_road_path(road, lerpf(0.22, 0.78, raw_t), 1.0) + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", cart_pos, 1.55)
			"bridge":
				if bool(road.get("show_traffic", true)):
					var raw_b := fposmod(anim_time * 0.32, 1.0)
					var cart_pos := bridge_arch_point(p_a, p_b, lerpf(0.20, 0.80, raw_b)) + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", cart_pos, 1.55)
			"dispute":
				if bool(road.get("show_badge", true)):
					draw_battle_sparks(r, road.get("badge_pos", sample_road_path(road, 0.5, 1.0)))
			"expedition":
				var raw_w := fposmod(anim_time * 0.38, 1.0)
				var wagon_pos := sample_road_path(road, lerpf(0.20, 0.82, raw_w), -1.0) + Vector2(0, -6.0)
				EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "settler_wagon", wagon_pos, 1.55)


static func draw_battle_sparks(r: Node2D, mid: Vector2) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var pulse := 1.0 + 0.22 * sin(anim_time * 8.5)
	for s_i in range(4):
		var ang := anim_time * 5.0 + float(s_i) * (TAU * 0.25)
		var spark_pos := mid + Vector2(cos(ang) * 11.0, sin(ang) * 6.5 - 6.0)
		anim_layer.draw_circle(spark_pos, 3.0, Color("#fde047") if s_i % 2 == 0 else Color("#f97316"))

	var badge_pos := mid + Vector2(0, -18.0)
	anim_layer.draw_circle(badge_pos, 14.0 * pulse, Color(0.94, 0.20, 0.20, 0.38))
	EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "icon_conflict_swords", badge_pos + Vector2(0, 8.0), 1.20)


static func draw_collaboration_route(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 26
	var pts := build_road_polyline(road, segments, 1.0)

	ci.draw_polyline(pts, Color("#4a3219"), 16.0)
	ci.draw_polyline(pts, Color("#8c6d46"), 12.8)
	ci.draw_polyline(pts, Color("#d6b88a"), 9.0)
	draw_cliff_ramp_steps(ci, road, 12.8, Color("#e6ccb2"), Color("#4a3219"))

	for i in range(1, pts.size() - 1):
		var pt := pts[i]
		var seg_d := pts[i + 1] - pts[i - 1]
		var dir := seg_d.normalized() if seg_d.length() > 0.01 else Vector2.RIGHT
		var perp := Vector2(-dir.y, dir.x)
		ci.draw_circle(pt + perp * 2.8, 3.2, Color("#e6ccb2") if i % 2 == 0 else Color("#c4a474"))
		ci.draw_circle(pt - perp * 2.8, 2.9, Color("#b89566"))

	var road_len := p_a.distance_to(p_b)
	if road_len > 150.0:
		var road_dir := (p_b - p_a) / road_len
		var road_perp := Vector2(-road_dir.y, road_dir.x)
		var lantern_pt := sample_road_path(road, 0.30, 1.0) + road_perp * 15.0 + Vector2(0, -5.0)
		ci.draw_circle(lantern_pt + Vector2(2.0, -7.0), 13.0, Color(1.0, 0.88, 0.38, 0.25))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "road_lantern", lantern_pt, 1.35)

	if show_badge:
		var mid := sample_road_path(road, 0.5, 1.0) + Vector2(0, -14.0)
		ci.draw_circle(mid, 11.5, Color("#064e3b"))
		ci.draw_circle(mid, 9.5, Color("#10b981"))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_coop_link", mid + Vector2(0, 6.8), 1.05)


static func draw_wooden_bridge(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var show_badge: bool = bool(road.get("show_badge", true))
	var diff := p_b - p_a
	var dir := diff.normalized() if diff.length() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	for t_pile in [0.22, 0.50, 0.78]:
		var base_pt := p_a.lerp(p_b, t_pile)
		var pile_top := base_pt + Vector2(0, -4.0)
		var pile_bot := base_pt + Vector2(0, 18.0)
		ci.draw_line(pile_top - perp * 6.0, pile_bot - perp * 6.0, Color("#3d2314"), 4.2)
		ci.draw_line(pile_top + perp * 6.0, pile_bot + perp * 6.0, Color("#4a2c18"), 4.2)
		ci.draw_line(pile_bot - Vector2(9.0, 0), pile_bot + Vector2(9.0, 0), Color(0.88, 0.97, 1.0, 0.65), 2.2)

	var steps := 20
	var curve_pts := PackedVector2Array()
	var rail_left := PackedVector2Array()
	var rail_right := PackedVector2Array()
	for i in range(steps + 1):
		var pt := bridge_arch_point(p_a, p_b, float(i) / float(steps))
		curve_pts.append(pt)
		rail_left.append(pt - perp * 7.6 + Vector2(0, -5.2))
		rail_right.append(pt + perp * 7.6 + Vector2(0, -5.2))

	ci.draw_polyline(curve_pts, Color("#3d2314"), 15.8)
	ci.draw_polyline(curve_pts, Color("#b07d4f"), 11.6)

	for i in range(1, steps):
		var c := curve_pts[i]
		ci.draw_line(c - perp * 7.0, c + perp * 7.0, Color("#d4a373") if i % 2 == 0 else Color("#8c5830"), 3.4)

	ci.draw_polyline(rail_left, Color("#6b3e26"), 2.8)
	ci.draw_polyline(rail_right, Color("#6b3e26"), 2.8)

	if show_badge:
		var mid := curve_pts[steps / 2] + Vector2(0, -15.0)
		ci.draw_circle(mid, 11.5, Color("#064e3b"))
		ci.draw_circle(mid, 9.5, Color("#10b981"))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_coop_link", mid + Vector2(0, 6.8), 1.05)


static func draw_dispute_barricade_front(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := sample_road_path(road, 0.5, 1.0)

	var stub_a := PackedVector2Array()
	var stub_b := PackedVector2Array()
	for i in range(7):
		stub_a.append(sample_road_path(road, lerpf(0.0, 0.38, float(i) / 6.0), 1.0))
		stub_b.append(sample_road_path(road, lerpf(0.62, 1.0, float(i) / 6.0), 1.0))
	ci.draw_polyline(stub_a, Color("#3b2313"), 10.8)
	ci.draw_polyline(stub_a, Color("#785233"), 7.2)
	ci.draw_polyline(stub_b, Color("#3b2313"), 10.8)
	ci.draw_polyline(stub_b, Color("#785233"), 7.2)

	var scorch_rx := 22.0
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, scorch_rx, scorch_rx * 0.58, Color(0.16, 0.08, 0.05, 0.72))
	ci.draw_line(mid - perp * scorch_rx, mid + perp * scorch_rx, Color("#dc2626"), 2.8)

	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "barricade_spikes", sample_road_path(road, 0.40, 1.0) + Vector2(0, 3.0), 1.50)
	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "barricade_spikes", sample_road_path(road, 0.60, 1.0) + Vector2(0, 3.0), 1.50)


static func draw_broken_cut_road(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var alpha: float = float(road.get("alpha", 0.90))
	var show_badge: bool = bool(road.get("show_badge", true))
	var mod_col := Color(1.0, 1.0, 1.0, alpha)
	var mid := sample_road_path(road, 0.5, 1.0)

	for rng in [Vector2(0.08, 0.36), Vector2(0.64, 0.92)]:
		var steps := 7
		for i in range(steps + 1):
			var pt := sample_road_path(road, lerpf(rng.x, rng.y, float(i) / float(steps)), 1.0)
			ci.draw_circle(pt, 5.2, Color("#47423c") * mod_col)
			ci.draw_circle(pt, 3.6, (Color("#8c8479") if i % 2 == 0 else Color("#6e675f")) * mod_col)

	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "soil_crack", mid + Vector2(0, 5.0), 1.30, mod_col)
	ci.draw_circle(mid + Vector2(-8.0, 3.0), 4.6, Color("#4d7c0f") * mod_col)
	ci.draw_circle(mid + Vector2(8.0, 1.5), 4.0, Color("#65a30d") * mod_col)

	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "road_block_sign", mid + Vector2(0, 4.0), 1.30, mod_col)
	if show_badge:
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_broken_link", mid + Vector2(0, -11.0), 1.05, mod_col)


static func draw_migration_expedition(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var steps := 18
	for i in range(1, steps):
		var pt := sample_road_path(road, float(i) / float(steps), -1.0)
		ci.draw_circle(pt, 4.8, Color("#0369a1"))
		ci.draw_circle(pt, 3.2, Color("#bae6fd") if i % 2 == 0 else Color("#e0f2fe"))


static func draw_pact_highway(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 28
	var pts := build_road_polyline(road, segments, 1.0)

	ci.draw_polyline(pts, Color(0.06, 0.73, 0.51, 0.36), 22.0)
	ci.draw_polyline(pts, Color("#f59e0b"), 17.2)
	ci.draw_polyline(pts, Color("#475569"), 14.0)
	ci.draw_polyline(pts, Color("#cbd5e1"), 10.2)
	draw_cliff_ramp_steps(ci, road, 14.0, Color("#e2e8f0"), Color("#334155"))

	for i in range(1, pts.size() - 1):
		var pt := pts[i]
		var seg_d := pts[i + 1] - pts[i - 1]
		var dir := seg_d.normalized() if seg_d.length() > 0.01 else Vector2.RIGHT
		var perp := Vector2(-dir.y, dir.x)
		ci.draw_circle(pt + perp * 3.0, 3.2, Color("#f8fafc") if i % 2 == 0 else Color("#94a3b8"))
		ci.draw_circle(pt - perp * 3.0, 3.0, Color("#e2e8f0") if i % 2 == 1 else Color("#94a3b8"))
		if i % 3 == 0:
			ci.draw_circle(pt, 2.2, Color("#10b981") if i % 6 == 0 else Color("#fbbf24"))

	var mid_curve := sample_road_path(road, 0.5, 1.0)
	var road_len := p_a.distance_to(p_b)
	if road_len > 90.0:
		var road_dir := (p_b - p_a) / road_len
		var road_perp := Vector2(-road_dir.y, road_dir.x)
		var totem_pt := mid_curve + road_perp * 16.0 + Vector2(0, 2.0)
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "prop_pact_totem", totem_pt, 1.45)

	if show_badge:
		var mid := mid_curve + Vector2(0, -15.0)
		ci.draw_circle(mid, 12.5, Color("#f59e0b"))
		ci.draw_circle(mid, 10.5, Color("#064e3b"))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_pact", mid + Vector2(0, 6.5), 1.35)


static func draw_merge_avenue(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 26
	var pts := build_road_polyline(road, segments, 1.0)

	ci.draw_polyline(pts, Color(0.98, 0.75, 0.14, 0.38), 22.0)
	ci.draw_polyline(pts, Color("#10b981"), 16.5)
	ci.draw_polyline(pts, Color("#fbbf24"), 12.5)
	ci.draw_polyline(pts, Color("#fef3c7"), 8.5)
	draw_cliff_ramp_steps(ci, road, 13.5, Color("#fef3c7"), Color("#78350f"))

	var mid_curve := sample_road_path(road, 0.5, 1.0)
	if show_badge:
		var mid := mid_curve + Vector2(0, -15.0)
		ci.draw_circle(mid, 12.5, Color("#fbbf24"))
		ci.draw_circle(mid, 10.5, Color("#064e3b"))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_merge", mid + Vector2(0, 6.5), 1.35)


static func draw_road_direction_arrow(
	ci: CanvasItem,
	from_pt: Vector2,
	to_pt: Vector2,
	fill_col: Color,
	outline_col: Color = Color("#23150c")
) -> void:
	var diff := to_pt - from_pt
	var dist := diff.length()
	if dist < 12.0:
		return
	var dir := diff / dist
	var perp := Vector2(-dir.y, dir.x)
	var tip := from_pt.lerp(to_pt, 0.78)
	var tri := PackedVector2Array([
		tip + dir * 7.5,
		tip - dir * 8.0 + perp * 7.0,
		tip - dir * 8.0 - perp * 7.0
	])
	ci.draw_colored_polygon(tri, fill_col)
	ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), outline_col, 2.0)


static func draw_tribute_route(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 24
	var pts := build_road_polyline(road, segments, 1.0)

	ci.draw_polyline(pts, Color("#78350f"), 15.0)
	ci.draw_polyline(pts, Color("#d97706"), 11.2)
	ci.draw_polyline(pts, Color("#fbbf24"), 7.5)
	draw_cliff_ramp_steps(ci, road, 11.2, Color("#fde047"), Color("#78350f"))
	draw_road_direction_arrow(ci, sample_road_path(road, 0.62, 1.0), sample_road_path(road, 0.86, 1.0), Color("#fde047"), Color("#78350f"))

	var mid_curve := sample_road_path(road, 0.5, 1.0)
	if show_badge:
		var mid := mid_curve + Vector2(0, -15.0)
		ci.draw_circle(mid, 12.0, Color("#78350f"))
		ci.draw_circle(mid, 10.0, Color("#f59e0b"))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_tribute", mid + Vector2(0, 6.5), 1.35)


static func draw_war_corridor(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := sample_road_path(road, 0.5, 1.0)
	var pts := build_road_polyline(road, 20, 0.0)

	ci.draw_polyline(pts, Color(0.50, 0.07, 0.07, 0.42), 20.0)
	ci.draw_polyline(pts, Color("#2a0a0a"), 14.8)
	ci.draw_polyline(pts, Color("#5c1919"), 10.4)
	ci.draw_polyline(pts, Color("#991b1b"), 5.6)
	draw_cliff_ramp_steps(ci, road, 11.6, Color("#b91c1c"), Color("#2a0a0a"))
	draw_road_direction_arrow(ci, sample_road_path(road, 0.62, 0.0), sample_road_path(road, 0.86, 0.0), Color("#ef4444"), Color("#2a0a0a"))

	var scorch_rx := 22.0
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, scorch_rx, scorch_rx * 0.58, Color(0.18, 0.04, 0.04, 0.78))
	ci.draw_line(mid - perp * scorch_rx, mid + perp * scorch_rx, Color("#ef4444"), 3.0)

	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "prop_war_banner", sample_road_path(road, 0.40, 0.0) + perp * 14.0 + Vector2(0, 3.0), 1.45)
	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "prop_war_banner", sample_road_path(road, 0.60, 0.0) - perp * 14.0 + Vector2(0, 3.0), 1.45)


static func draw_war_animated_invasion(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var mid := road.get("badge_pos", sample_road_path(road, 0.5, 0.0)) as Vector2

	var pulse := 0.55 + 0.45 * sin(anim_time * 7.5)
	var pts := build_road_polyline(road, 16, 0.0)
	anim_layer.draw_polyline(pts, Color(0.94, 0.27, 0.27, 0.52 * pulse), 4.2)
	for c_i in range(3):
		var t_chev := lerpf(0.15, 0.85, fposmod(anim_time * 0.55 + float(c_i) * 0.33, 1.0))
		var c_pos := sample_road_path(road, t_chev, 0.0)
		var c_next := sample_road_path(road, minf(1.0, t_chev + 0.06), 0.0)
		var seg := c_next - c_pos
		var dir := seg.normalized() if seg.length() > 0.01 else Vector2.RIGHT
		var perp := Vector2(-dir.y, dir.x)
		var tip := c_pos + dir * 6.0
		var wing_l := c_pos - dir * 5.0 + perp * 6.0
		var wing_r := c_pos - dir * 5.0 - perp * 6.0
		anim_layer.draw_line(wing_l, tip, Color("#fca5a5"), 2.4)
		anim_layer.draw_line(wing_r, tip, Color("#fca5a5"), 2.4)

	EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "effect_battle_sparks", mid + Vector2(0, 4.0), 1.15 + 0.20 * pulse)
	for s_i in range(5):
		var ang := anim_time * 6.0 + float(s_i) * (TAU * 0.20)
		var spark_pos := mid + Vector2(cos(ang) * 13.0, sin(ang) * 7.5 - 6.0)
		anim_layer.draw_circle(spark_pos, 3.2, Color("#fde047") if s_i % 2 == 0 else Color("#ef4444"))

	if bool(road.get("show_badge", true)):
		var badge_pos := mid + Vector2(0, -18.0)
		var is_siege_road := str(road.get("kind", "")) == "siege"
		anim_layer.draw_circle(badge_pos, 14.5 * (0.92 + 0.16 * pulse), Color(0.94, 0.20, 0.20, 0.42))
		anim_layer.draw_circle(badge_pos, 10.5, Color("#7f1d1d"))
		EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "icon_siege" if is_siege_road else "icon_war", badge_pos + Vector2(0, 6.5), 1.35)


static func draw_raid_trail(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var show_badge: bool = bool(road.get("show_badge", true))
	var repelled: bool = str(road.get("flow_type", "raid")) == "raid_repelled"
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	var steps := 14
	var prev_pt := sample_road_path(road, 0.0, 0.0)
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var jag := 0.0 if i == steps else (5.0 if i % 2 == 1 else -5.0)
		var next_pt := sample_road_path(road, t, 0.0) + perp * jag
		if i % 2 == 1:
			ci.draw_line(prev_pt, next_pt, Color("#431407"), 8.5)
			ci.draw_line(prev_pt, next_pt, Color("#64748b") if repelled else Color("#ef4444"), 5.5)
			ci.draw_line(prev_pt, next_pt, Color("#cbd5e1") if repelled else Color("#f97316"), 3.2)
		else:
			ci.draw_circle((prev_pt + next_pt) * 0.5, 3.2, Color("#94a3b8") if repelled else Color("#fb923c"))
		prev_pt = next_pt
	draw_cliff_ramp_steps(ci, road, 8.5, Color("#fb923c"), Color("#431407"))
	draw_road_direction_arrow(
		ci,
		sample_road_path(road, 0.54, 0.0),
		sample_road_path(road, 0.76, 0.0),
		Color("#38bdf8") if repelled else Color("#f97316"),
		Color("#23150c")
	)

	if show_badge:
		var mid := sample_road_path(road, 0.5, 0.0) + Vector2(0, -14.0)
		ci.draw_circle(mid, 11.5, Color("#1e293b") if repelled else Color("#7c2d12"))
		ci.draw_circle(mid, 9.5, Color("#38bdf8") if repelled else Color("#f97316"))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_defense" if repelled else "icon_raid", mid + Vector2(0, 6.2), 1.35)


static func draw_raid_animated_plunder(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var flow_type := str(road.get("flow_type", "raid"))

	if flow_type == "raid":
		for r_i in range(2):
			var raw_r := fposmod(anim_time * 0.52 + float(r_i) * 0.48, 1.0)
			var r_pos := sample_road_path(road, lerpf(0.84, 0.18, raw_r), 0.0)
			EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "prop_raid_loot", r_pos + Vector2(9.0, -5.0), 1.05)
	elif flow_type == "raid_repelled":
		var clash_pos := sample_road_path(road, 0.72, 0.0)
		var prev_pos := sample_road_path(road, 0.58, 0.0)
		var seg := clash_pos - prev_pos
		var dir := seg.normalized() if seg.length() > 0.01 else Vector2.RIGHT
		var perp := Vector2(-dir.y, dir.x)
		var pulse := 0.65 + 0.35 * sin(anim_time * 9.0)

		anim_layer.draw_line(clash_pos - perp * 15.0, clash_pos + perp * 15.0, Color("#0f172a"), 5.8)
		anim_layer.draw_line(clash_pos - perp * 14.0, clash_pos + perp * 14.0, Color(0.22, 0.74, 0.97, 0.88 * pulse), 3.4)
		EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "effect_battle_sparks", clash_pos + Vector2(0, 3.0), 1.02 + 0.18 * pulse)

		for d_i in range(2):
			var raw_d := fposmod(anim_time * 0.52 + float(d_i) * 0.46, 1.0)
			if raw_d >= 0.55:
				var retreat_t := (raw_d - 0.55) / 0.45
				var dust_pos := sample_road_path(road, lerpf(0.70, 0.22, retreat_t), 0.0) + Vector2(0.0, 2.0)
				anim_layer.draw_circle(dust_pos, lerpf(4.2, 2.0, retreat_t), Color(0.82, 0.74, 0.62, 0.52 * (1.0 - retreat_t)))


static func draw_betrayal_road(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := sample_road_path(road, 0.5, 0.0)

	var stub_a := PackedVector2Array()
	var stub_b := PackedVector2Array()
	for i in range(7):
		stub_a.append(sample_road_path(road, lerpf(0.0, 0.36, float(i) / 6.0), 0.0))
		stub_b.append(sample_road_path(road, lerpf(0.64, 1.0, float(i) / 6.0), 0.0))
	ci.draw_polyline(stub_a, Color("#334155"), 14.0)
	ci.draw_polyline(stub_a, Color("#94a3b8"), 9.2)
	ci.draw_polyline(stub_b, Color("#334155"), 14.0)
	ci.draw_polyline(stub_b, Color("#94a3b8"), 9.2)

	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, 22.0, 13.0, Color(0.18, 0.04, 0.22, 0.78))
	var f1 := mid - perp * 18.0 - dir * 6.0
	var f2 := mid - perp * 5.0 + dir * 7.0
	var f3 := mid + perp * 7.0 - dir * 6.0
	var f4 := mid + perp * 18.0 + dir * 5.0
	var fracture_pts := PackedVector2Array([f1, f2, f3, f4])
	ci.draw_polyline(fracture_pts, Color("#7e22ce"), 5.2)
	ci.draw_polyline(fracture_pts, Color("#be123c"), 3.0)
	ci.draw_polyline(fracture_pts, Color("#fda4af"), 1.4)

	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "prop_betrayal_ruin", mid + Vector2(0, 4.0), 1.50)


static func draw_betrayal_animated_ruin(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var mid := road.get("badge_pos", sample_road_path(road, 0.5, 0.0)) as Vector2
	var pulse := 1.0 + 0.22 * sin(anim_time * 7.0)

	for s_i in range(4):
		var phase := fposmod(anim_time * 0.45 + float(s_i) * 0.25, 1.0)
		var smoke_pos := mid + Vector2(sin(anim_time * 2.5 + float(s_i) * 1.7) * 10.0, -phase * 26.0 - 2.0)
		var smoke_col := Color(0.29, 0.08, 0.42, (1.0 - phase) * 0.68) if s_i % 2 == 0 else Color(0.20, 0.20, 0.24, (1.0 - phase) * 0.62)
		anim_layer.draw_circle(smoke_pos, lerpf(3.5, 6.5, phase), smoke_col)

	if bool(road.get("show_badge", true)):
		var badge_pos := mid + Vector2(0, -19.0)
		anim_layer.draw_circle(badge_pos, 14.0 * pulse, Color(0.75, 0.07, 0.24, 0.42))
		anim_layer.draw_circle(badge_pos, 10.0, Color("#4c0519"))
		EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "icon_betrayal", badge_pos + Vector2(0, 6.5), 1.35 * (0.95 + 0.08 * sin(anim_time * 7.0)))


static func draw_rural_farm_track(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var segments := 20
	var pts := build_road_polyline(road, segments, 1.0)

	ci.draw_polyline(pts, Color("#23150c"), 11.5)
	ci.draw_polyline(pts, Color("#6b4423"), 8.5)
	ci.draw_polyline(pts, Color("#c29b61"), 5.2)
	draw_cliff_ramp_steps(ci, road, 8.5, Color("#d4a373"), Color("#23150c"))
	for i in range(2, pts.size() - 1, 2):
		ci.draw_circle(pts[i], 2.0, Color("#8c5e35"))


static func collect_settlement_road_edges(r: Node2D) -> Dictionary:
	var road_edges: Dictionary = {}
	for road in r._roads:
		var kind := str(road.get("kind", ""))
		if kind in ["broken", "dispute", "betrayal"]:
			continue
		var hex_a := str(road.get("hex_a", ""))
		var hex_b := str(road.get("hex_b", ""))
		var world_a: Vector2 = road["world_a"]
		var world_b: Vector2 = road["world_b"]
		var w_ab := world_b - world_a
		if w_ab.length_squared() < 1.0:
			continue
		if hex_a != "":
			var edge_a := posmod(int(round(atan2(w_ab.y, w_ab.x) / (PI / 3.0))), 6)
			road_edges[hex_a] = int(road_edges.get(hex_a, 0)) | (1 << edge_a)
		if hex_b != "":
			var edge_b := posmod(int(round(atan2(-w_ab.y, -w_ab.x) / (PI / 3.0))), 6)
			road_edges[hex_b] = int(road_edges.get(hex_b, 0)) | (1 << edge_b)
	return road_edges


static func compute_village_front_wall_y(r: Node2D, village: Dictionary) -> float:
	var deme: EvoTypes.Deme = village["deme"]
	var has_union: bool = deme.is_multi_hex()
	if deme.defense_tier < 1 and not has_union:
		return INF
	var hex_id: String = village["hex_id"]
	if not r.world_state.cells.has(hex_id) or not r._hex_polys.has(hex_id):
		return INF
	var cell: EvoTypes.HexCell = r.world_state.cells[hex_id]
	var center: Vector2 = village["pos"]
	var top_pts: PackedVector2Array = r._hex_polys[hex_id]
	var max_y := -INF
	for e in range(6):
		if has_union:
			var nb_id: String = r._neighbor_id(cell, EDGE_DIR_MAP[e])
			if r.world_state.cells.has(nb_id):
				var nb_cell: EvoTypes.HexCell = r.world_state.cells[nb_id]
				if not nb_cell.deme_ids.is_empty() and nb_cell.deme_ids[0] == deme.id:
					continue
		var c0 := center.lerp(top_pts[e], WALL_RADIUS)
		var c1 := center.lerp(top_pts[(e + 1) % 6], WALL_RADIUS)
		var mid_y := (c0.y + c1.y) * 0.5
		if mid_y >= center.y - FRONT_EPS and mid_y > max_y:
			max_y = mid_y
	return max_y if max_y > -INF else (center.y + 48.0)


static func draw_settlement_perimeter_walls(r: Node2D) -> void:
	draw_settlement_back_walls(r)
	draw_settlement_front_walls(r, r._network_layer)


static func draw_settlement_back_walls(r: Node2D) -> void:
	var road_edges := collect_settlement_road_edges(r)
	var has_cull: bool = r._visible_world_rect.size != Vector2.ZERO
	var cull_rect: Rect2 = r._visible_world_rect.grow(HexMath.HEX_SIZE * 1.5) if has_cull else Rect2()
	for village in r._villages:
		if has_cull and not cull_rect.has_point(village["pos"] as Vector2):
			continue
		draw_village_wall_pass(r, village, r._network_layer, false, road_edges)


static func draw_settlement_front_walls(r: Node2D, target_layer: Node2D) -> void:
	var road_edges := collect_settlement_road_edges(r)
	var has_cull: bool = r._visible_world_rect.size != Vector2.ZERO
	var cull_rect: Rect2 = r._visible_world_rect.grow(HexMath.HEX_SIZE * 1.5) if has_cull else Rect2()
	var ordered: Array[Dictionary] = []
	for village in r._villages:
		if has_cull and not cull_rect.has_point(village["pos"] as Vector2):
			continue
		ordered.append(village)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y
	)
	for village in ordered:
		draw_village_wall_pass(r, village, target_layer, true, road_edges)


static func draw_village_wall_pass(
	r: Node2D,
	village: Dictionary,
	ci: CanvasItem,
	front_pass: bool,
	road_edges: Dictionary
) -> void:
	var state: EvoTypes.WorldState = r.world_state
	var deme: EvoTypes.Deme = village["deme"]
	var has_union: bool = deme.is_multi_hex()
	if deme.defense_tier < 1 and not has_union:
		return
	var hex_id: String = village["hex_id"]
	if not state.cells.has(hex_id) or not r._hex_polys.has(hex_id):
		return

	var cell: EvoTypes.HexCell = state.cells[hex_id]
	var center: Vector2 = village["pos"]
	var top_pts: PackedVector2Array = r._hex_polys[hex_id]
	var mod_col: Color = village["modulate"]
	var strat_col: Color = village["strat_color"]
	var is_stone: bool = deme.defense_tier >= 2 or has_union
	var gate_mask: int = int(road_edges.get(hex_id, 0))

	var edge_suppressed: Array[bool] = [false, false, false, false, false, false]
	var edge_is_front: Array[bool] = [false, false, false, false, false, false]
	var corners := PackedVector2Array()
	corners.resize(6)
	for v in range(6):
		corners[v] = center.lerp(top_pts[v], WALL_RADIUS)

	for e in range(6):
		if has_union:
			var nb_id: String = r._neighbor_id(cell, EDGE_DIR_MAP[e])
			if state.cells.has(nb_id):
				var nb_cell: EvoTypes.HexCell = state.cells[nb_id]
				if not nb_cell.deme_ids.is_empty() and nb_cell.deme_ids[0] == deme.id:
					edge_suppressed[e] = true
		var mid_y := (corners[e].y + corners[(e + 1) % 6].y) * 0.5
		edge_is_front[e] = mid_y >= center.y - FRONT_EPS

	var draw_order: Array[int] = [0, 1, 2, 3, 4, 5]
	draw_order.sort_custom(func(a: int, b: int) -> bool:
		return (corners[a].y + corners[(a + 1) % 6].y) < (corners[b].y + corners[(b + 1) % 6].y)
	)

	for e in draw_order:
		if edge_suppressed[e] or edge_is_front[e] != front_pass:
			continue
		var c0 := corners[e]
		var c1 := corners[(e + 1) % 6]
		var has_gate := (gate_mask & (1 << e)) != 0
		_draw_wall_edge(ci, center, c0, c1, e, is_stone, has_gate, mod_col, strat_col)

	for v in range(6):
		var prev_e: int = (v + 5) % 6
		var e_active := not edge_suppressed[v]
		var prev_active := not edge_suppressed[prev_e]
		if not e_active and not prev_active:
			continue
		var corner_front := (e_active and edge_is_front[v]) or (prev_active and edge_is_front[prev_e])
		if corner_front != front_pass:
			continue
		_draw_wall_corner_bastion(ci, corners[v], is_stone, mod_col, strat_col)


static func _draw_wall_edge(
	ci: CanvasItem,
	center: Vector2,
	c0: Vector2,
	c1: Vector2,
	edge_idx: int,
	is_stone: bool,
	has_gate: bool,
	mod_col: Color,
	strat_col: Color
) -> void:
	var edge_len := c0.distance_to(c1)
	if edge_len < 6.0:
		return
	var mid := (c0 + c1) * 0.5
	var out_n := (mid - center).normalized()
	var in_vec := -out_n * 3.4
	var sun_t := clampf(0.5 - out_n.x * 0.55 - out_n.y * 0.12, 0.0, 1.0)

	if has_gate and edge_len > 56.0:
		var gate_half_t := clampf(19.0 / edge_len, 0.12, 0.22)
		var g0 := c0.lerp(c1, 0.5 - gate_half_t)
		var g1 := c0.lerp(c1, 0.5 + gate_half_t)
		if is_stone:
			_draw_stone_wall_span(ci, c0, g0, in_vec, sun_t, mod_col)
			_draw_stone_wall_span(ci, g1, c1, in_vec, sun_t, mod_col)
			_draw_stone_gatehouse(ci, g0, g1, sun_t, mod_col, strat_col)
		else:
			_draw_palisade_span(ci, c0, g0, edge_idx, sun_t, mod_col)
			_draw_palisade_span(ci, g1, c1, edge_idx + 3, sun_t, mod_col)
			_draw_palisade_gate(ci, g0, g1, mod_col, strat_col)
	else:
		if is_stone:
			_draw_stone_wall_span(ci, c0, c1, in_vec, sun_t, mod_col)
		else:
			_draw_palisade_span(ci, c0, c1, edge_idx, sun_t, mod_col)


static func _draw_stone_wall_span(
	ci: CanvasItem,
	s0: Vector2,
	s1: Vector2,
	in_vec: Vector2,
	sun_t: float,
	mod_col: Color
) -> void:
	var span_len := s0.distance_to(s1)
	if span_len < 4.0:
		return
	var wall_h := 21.0
	var sh_off := Vector2(6.5, 4.5)
	ci.draw_colored_polygon(
		PackedVector2Array([s0, s1, s1 + sh_off, s0 + sh_off]),
		Color(0.06, 0.04, 0.02, 0.30) * mod_col
	)

	var t0 := s0 + Vector2(0.0, -wall_h)
	var t1 := s1 + Vector2(0.0, -wall_h)
	var face_col := Color("#526277").lerp(Color("#94a3b8"), sun_t)
	var plinth_col := face_col.darkened(0.22)
	var cap_col := Color("#cbd5e1").lerp(Color("#f1f5f9"), sun_t)

	ci.draw_colored_polygon(PackedVector2Array([t0, t1, s1, s0]), face_col * mod_col)
	ci.draw_colored_polygon(
		PackedVector2Array([s0 + Vector2(0.0, -4.8), s1 + Vector2(0.0, -4.8), s1, s0]),
		plinth_col * mod_col
	)
	ci.draw_line(
		s0.lerp(t0, 0.52),
		s1.lerp(t1, 0.52),
		plinth_col * mod_col,
		1.5
	)

	var t0_in := t0 + in_vec + Vector2(0.0, -1.8)
	var t1_in := t1 + in_vec + Vector2(0.0, -1.8)
	ci.draw_colored_polygon(PackedVector2Array([t0_in, t1_in, t1, t0]), cap_col * mod_col)
	ci.draw_polyline(PackedVector2Array([t0_in, t1_in, t1, s1, s0, t0, t0_in]), INK * mod_col, 1.8)
	ci.draw_line(t0, t1, INK * mod_col, 1.4)

	var merlon_count := maxi(2, int(span_len / 22.0))
	var mh := Vector2(0.0, -4.8)
	for m_i in range(merlon_count):
		var mt0 := (float(m_i) + 0.16) / float(merlon_count)
		var mt1 := (float(m_i) + 0.72) / float(merlon_count)
		var mb0 := t0.lerp(t1, mt0)
		var mb1 := t0.lerp(t1, mt1)
		var m_quad := PackedVector2Array([mb0 + mh, mb1 + mh, mb1, mb0])
		ci.draw_colored_polygon(m_quad, face_col.lightened(0.14) * mod_col)
		ci.draw_line(mb0 + mh, mb1 + mh, cap_col * mod_col, 2.2)
		ci.draw_polyline(PackedVector2Array([mb0, mb0 + mh, mb1 + mh, mb1]), INK * mod_col, 1.4)


static func _draw_stone_gatehouse(
	ci: CanvasItem,
	g0: Vector2,
	g1: Vector2,
	sun_t: float,
	mod_col: Color,
	strat_col: Color
) -> void:
	var pier_h := 25.0
	var stone_lit := Color("#cbd5e1").lerp(Color("#f1f5f9"), sun_t)
	var stone_mid := Color("#64748b").lerp(Color("#94a3b8"), sun_t)
	var stone_shd := stone_mid.darkened(0.24)

	var lintel_top_0 := g0 + Vector2(0.0, -pier_h)
	var lintel_top_1 := g1 + Vector2(0.0, -pier_h)
	var lintel_bot_0 := g0 + Vector2(0.0, -pier_h + 6.5)
	var lintel_bot_1 := g1 + Vector2(0.0, -pier_h + 6.5)
	ci.draw_colored_polygon(
		PackedVector2Array([lintel_top_0, lintel_top_1, lintel_bot_1, lintel_bot_0]),
		stone_shd * mod_col
	)
	ci.draw_line(lintel_top_0, lintel_top_1, stone_lit * mod_col, 3.0)
	ci.draw_polyline(
		PackedVector2Array([lintel_top_0, lintel_top_1, lintel_bot_1, lintel_bot_0, lintel_top_0]),
		INK * mod_col,
		1.6
	)

	for gp: Vector2 in [g0, g1]:
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, gp + Vector2(3.5, 2.5), 6.5, 3.8, Color(0.06, 0.04, 0.02, 0.30) * mod_col)
		var p_rect := Rect2(gp.x - 4.8, gp.y - pier_h - 2.0, 9.6, pier_h + 2.5)
		ci.draw_rect(p_rect, stone_shd * mod_col, true)
		ci.draw_rect(Rect2(p_rect.position, Vector2(5.2, p_rect.size.y)), stone_mid.lightened(0.12) * mod_col, true)
		ci.draw_rect(Rect2(p_rect.position - Vector2(0.8, 2.2), Vector2(p_rect.size.x + 1.6, 3.4)), stone_lit * mod_col, true)
		ci.draw_rect(p_rect, INK * mod_col, false, 1.6)
		ci.draw_circle(gp + Vector2(0.0, -pier_h * 0.58), 2.4, strat_col * mod_col)


static func _draw_palisade_span(
	ci: CanvasItem,
	s0: Vector2,
	s1: Vector2,
	seed_idx: int,
	sun_t: float,
	mod_col: Color
) -> void:
	var span_len := s0.distance_to(s1)
	if span_len < 4.0:
		return
	var sh_off := Vector2(5.5, 3.8)
	ci.draw_colored_polygon(
		PackedVector2Array([s0, s1, s1 + sh_off, s0 + sh_off]),
		Color(0.06, 0.04, 0.02, 0.28) * mod_col
	)
	ci.draw_line(s0, s1, INK * mod_col, 6.4)
	ci.draw_line(s0, s1, Color("#4a2c18") * mod_col, 4.2)

	var wood_dark := Color("#5c381e").lerp(Color("#784928"), sun_t)
	var wood_lit := Color("#8c5832").lerp(Color("#b5784a"), sun_t)
	var stake_count := maxi(3, int(span_len / 7.2))
	for s_i in range(stake_count + 1):
		var st := float(s_i) / float(stake_count)
		var sb := s0.lerp(s1, st)
		var h := 20.0 + float((s_i * 5 + seed_idx) % 3) * 1.8
		var st_shoulder := sb + Vector2(0.0, -h + 4.0)
		var st_tip := sb + Vector2(0.0, -h)
		ci.draw_line(sb, st_shoulder, INK * mod_col, 5.6)
		ci.draw_line(sb, st_shoulder, wood_dark * mod_col, 3.8)
		ci.draw_line(sb + Vector2(-0.8, 0.0), st_shoulder + Vector2(-0.8, 0.0), wood_lit * mod_col, 1.6)
		var tip_poly := PackedVector2Array([
			st_tip,
			st_shoulder + Vector2(2.4, 0.0),
			st_shoulder - Vector2(2.4, 0.0)
		])
		ci.draw_colored_polygon(tip_poly, Color("#e6c290") * mod_col)
		ci.draw_polyline(PackedVector2Array([tip_poly[2], tip_poly[0], tip_poly[1]]), INK * mod_col, 1.3)

	for rail_y in [-7.0, -14.0]:
		ci.draw_line(s0 + Vector2(0.0, rail_y), s1 + Vector2(0.0, rail_y), INK * mod_col, 3.2)
		ci.draw_line(s0 + Vector2(0.0, rail_y), s1 + Vector2(0.0, rail_y), Color("#704223") * mod_col, 1.8)


static func _draw_palisade_gate(
	ci: CanvasItem,
	g0: Vector2,
	g1: Vector2,
	mod_col: Color,
	strat_col: Color
) -> void:
	var post_h := 24.5
	var top_0 := g0 + Vector2(0.0, -post_h + 2.5)
	var top_1 := g1 + Vector2(0.0, -post_h + 2.5)
	ci.draw_line(top_0, top_1, INK * mod_col, 6.4)
	ci.draw_line(top_0, top_1, Color("#8c5832") * mod_col, 4.0)
	ci.draw_line(top_0 + Vector2(0.0, -1.0), top_1 + Vector2(0.0, -1.0), Color("#cfa072") * mod_col, 1.6)

	for gp: Vector2 in [g0, g1]:
		var p_top := gp + Vector2(0.0, -post_h)
		ci.draw_line(gp, p_top, INK * mod_col, 7.2)
		ci.draw_line(gp, p_top, Color("#6b3e22") * mod_col, 4.8)
		ci.draw_line(gp + Vector2(-1.0, 0.0), p_top + Vector2(-1.0, 0.0), Color("#a86b3e") * mod_col, 1.8)
		ci.draw_circle(p_top, 3.0, INK * mod_col)
		ci.draw_circle(p_top, 2.0, strat_col * mod_col)


static func _draw_wall_corner_bastion(
	ci: CanvasItem,
	cv: Vector2,
	is_stone: bool,
	mod_col: Color,
	strat_col: Color
) -> void:
	if is_stone:
		var tower_h := 23.5
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, cv + Vector2(4.5, 3.0), 9.0, 5.2, Color(0.06, 0.04, 0.02, 0.30) * mod_col)
		var body_rect := Rect2(cv.x - 6.6, cv.y - tower_h, 13.2, tower_h + 2.0)
		ci.draw_rect(body_rect, Color("#526277") * mod_col, true)
		ci.draw_rect(Rect2(body_rect.position, Vector2(7.0, body_rect.size.y)), Color("#94a3b8") * mod_col, true)
		ci.draw_rect(body_rect, INK * mod_col, false, 1.8)
		var cap_center := cv + Vector2(0.0, -tower_h)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, cap_center, 8.2, 4.8, INK * mod_col)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, cap_center, 6.8, 3.8, Color("#e2e8f0") * mod_col)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, cap_center + Vector2(0.0, -1.2), 4.4, 2.6, strat_col * mod_col)
	else:
		var post_top := cv + Vector2(0.0, -23.0)
		ci.draw_line(cv + Vector2(0.0, 1.5), post_top, INK * mod_col, 7.0)
		ci.draw_line(cv + Vector2(0.0, 1.5), post_top, Color("#6b3e22") * mod_col, 4.6)
		ci.draw_line(cv + Vector2(-1.0, 1.5), post_top + Vector2(-1.0, 0.0), Color("#a86b3e") * mod_col, 1.8)
		ci.draw_circle(post_top, 2.8, Color("#e6c290") * mod_col)
