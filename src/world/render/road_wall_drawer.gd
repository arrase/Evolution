class_name EvoRoadWallDrawer
extends RefCounted


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


static func draw_network_roads(r: Node2D) -> void:
	draw_settlement_perimeter_walls(r)
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


static func draw_animated_roads(r: Node2D) -> void:
	var anim_layer: Node2D = r._anim_layer
	var vis_rect: Rect2 = r._visible_world_rect
	var anim_time: float = r._anim_time
	for road in r._roads:
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not vis_rect.has_point(p_a) and not vis_rect.has_point(p_b):
			continue
		var curve_f: float = float(road.get("curve_factor", 0.14))
		match road["kind"]:
			"pact":
				if bool(road.get("show_traffic", true)):
					var diff := p_b - p_a
					var perp := Vector2(-diff.y, diff.x).normalized() if diff.length() > 0.01 else Vector2.UP
					var raw_t1 := fposmod(anim_time * 0.34 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var raw_t2 := fposmod(raw_t1 + 0.5, 1.0)
					var pos_1 := sample_road_curve(p_a, p_b, lerpf(0.18, 0.82, raw_t1), 1.0, curve_f) + perp * 3.2 + Vector2(0, -6.0)
					var pos_2 := sample_road_curve(p_a, p_b, lerpf(0.82, 0.18, raw_t2), 1.0, curve_f) - perp * 3.2 + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", pos_1, 1.55)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", pos_2, 1.55)
			"merge":
				if bool(road.get("show_traffic", true)):
					var raw_m := fposmod(anim_time * 0.36 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var wagon_pos := sample_road_curve(p_a, p_b, lerpf(0.18, 0.82, raw_m), 1.0, curve_f) + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "settler_wagon", wagon_pos, 1.55)
			"tribute":
				if bool(road.get("show_traffic", true)):
					var raw_tr := fposmod(anim_time * 0.36 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var cart_pos := sample_road_curve(p_a, p_b, lerpf(0.18, 0.82, raw_tr), 1.0, curve_f) + Vector2(0, -6.0)
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
					var t_cart := lerpf(0.22, 0.78, raw_t)
					EvoWorldOverlayRenderer.draw_centered_sprite(
						anim_layer,
						"caravan_cart",
						sample_road_curve(p_a, p_b, t_cart, 1.0, curve_f) + Vector2(0, -6.0),
						1.55
					)
			"bridge":
				if bool(road.get("show_traffic", true)):
					var raw_b := fposmod(anim_time * 0.32, 1.0)
					var cart_pos := bridge_arch_point(p_a, p_b, lerpf(0.20, 0.80, raw_b)) + Vector2(0, -6.0)
					EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "caravan_cart", cart_pos, 1.55)
			"dispute":
				if bool(road.get("show_badge", true)):
					draw_battle_sparks(r, road.get("badge_pos", (p_a + p_b) * 0.5))
			"expedition":
				var raw_w := fposmod(anim_time * 0.38, 1.0)
				var wagon_pos := sample_road_curve(p_a, p_b, lerpf(0.20, 0.82, raw_w), -1.0, curve_f) + Vector2(0, -6.0)
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
	var curve_f: float = float(road.get("curve_factor", 0.14))
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 26
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))

	ci.draw_polyline(pts, Color("#4a3219"), 16.0)
	ci.draw_polyline(pts, Color("#8c6d46"), 12.8)
	ci.draw_polyline(pts, Color("#d6b88a"), 9.0)

	for i in range(1, segments):
		var pt := pts[i]
		var dir := (pts[i + 1] - pts[i - 1]).normalized()
		var perp := Vector2(-dir.y, dir.x)
		ci.draw_circle(pt + perp * 2.8, 3.2, Color("#e6ccb2") if i % 2 == 0 else Color("#c4a474"))
		ci.draw_circle(pt - perp * 2.8, 2.9, Color("#b89566"))

	var road_len := p_a.distance_to(p_b)
	if road_len > 150.0:
		var road_dir := (p_b - p_a) / road_len
		var road_perp := Vector2(-road_dir.y, road_dir.x)
		var lantern_pt := sample_road_curve(p_a, p_b, 0.30, 1.0, curve_f) + road_perp * 15.0 + Vector2(0, -5.0)
		ci.draw_circle(lantern_pt + Vector2(2.0, -7.0), 13.0, Color(1.0, 0.88, 0.38, 0.25))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "road_lantern", lantern_pt, 1.35)

	if show_badge:
		var mid := sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f) + Vector2(0, -14.0)
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
	var mid := (p_a + p_b) * 0.5

	var stop_a := p_a.lerp(p_b, 0.38)
	var stop_b := p_b.lerp(p_a, 0.38)
	ci.draw_line(p_a, stop_a, Color("#3b2313"), 10.8)
	ci.draw_line(p_a, stop_a, Color("#785233"), 7.2)
	ci.draw_line(p_b, stop_b, Color("#3b2313"), 10.8)
	ci.draw_line(p_b, stop_b, Color("#785233"), 7.2)

	var scorch_rx := 22.0
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, scorch_rx, scorch_rx * 0.58, Color(0.16, 0.08, 0.05, 0.72))
	ci.draw_line(mid - perp * scorch_rx, mid + perp * scorch_rx, Color("#dc2626"), 2.8)

	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "barricade_spikes", p_a.lerp(p_b, 0.40) + Vector2(0, 3.0), 1.50)
	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "barricade_spikes", p_a.lerp(p_b, 0.60) + Vector2(0, 3.0), 1.50)


static func draw_broken_cut_road(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var alpha: float = float(road.get("alpha", 0.90))
	var show_badge: bool = bool(road.get("show_badge", true))
	var mod_col := Color(1.0, 1.0, 1.0, alpha)
	var mid := (p_a + p_b) * 0.5

	for rng in [Vector2(0.08, 0.36), Vector2(0.64, 0.92)]:
		var steps := 7
		for i in range(steps + 1):
			var pt := p_a.lerp(p_b, lerpf(rng.x, rng.y, float(i) / float(steps)))
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
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.14))
	var steps := 18
	for i in range(1, steps):
		var pt := sample_road_curve(p_a, p_b, float(i) / float(steps), -1.0, curve_f)
		ci.draw_circle(pt, 4.8, Color("#0369a1"))
		ci.draw_circle(pt, 3.2, Color("#bae6fd") if i % 2 == 0 else Color("#e0f2fe"))


static func draw_pact_highway(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 28
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))

	ci.draw_polyline(pts, Color(0.06, 0.73, 0.51, 0.36), 22.0)
	ci.draw_polyline(pts, Color("#f59e0b"), 17.2)
	ci.draw_polyline(pts, Color("#475569"), 14.0)
	ci.draw_polyline(pts, Color("#cbd5e1"), 10.2)

	for i in range(1, segments):
		var pt := pts[i]
		var dir := (pts[i + 1] - pts[i - 1]).normalized()
		var perp := Vector2(-dir.y, dir.x)
		ci.draw_circle(pt + perp * 3.0, 3.2, Color("#f8fafc") if i % 2 == 0 else Color("#94a3b8"))
		ci.draw_circle(pt - perp * 3.0, 3.0, Color("#e2e8f0") if i % 2 == 1 else Color("#94a3b8"))
		if i % 3 == 0:
			ci.draw_circle(pt, 2.2, Color("#10b981") if i % 6 == 0 else Color("#fbbf24"))

	var mid_curve := sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f)
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
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 26
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))

	ci.draw_polyline(pts, Color(0.98, 0.75, 0.14, 0.38), 22.0)
	ci.draw_polyline(pts, Color("#10b981"), 16.5)
	ci.draw_polyline(pts, Color("#fbbf24"), 12.5)
	ci.draw_polyline(pts, Color("#fef3c7"), 8.5)

	var mid_curve := sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f)
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
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	var show_badge: bool = bool(road.get("show_badge", true))

	var segments := 24
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))

	ci.draw_polyline(pts, Color("#78350f"), 15.0)
	ci.draw_polyline(pts, Color("#d97706"), 11.2)
	ci.draw_polyline(pts, Color("#fbbf24"), 7.5)
	draw_road_direction_arrow(ci, p_a, p_b, Color("#fde047"), Color("#78350f"))

	var mid_curve := sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f)
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
	var mid := (p_a + p_b) * 0.5

	ci.draw_line(p_a, p_b, Color(0.50, 0.07, 0.07, 0.42), 20.0)
	ci.draw_line(p_a, p_b, Color("#2a0a0a"), 14.8)
	ci.draw_line(p_a, p_b, Color("#5c1919"), 10.4)
	ci.draw_line(p_a, p_b, Color("#991b1b"), 5.6)
	draw_road_direction_arrow(ci, p_a, p_b, Color("#ef4444"), Color("#2a0a0a"))

	var scorch_rx := 22.0
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, scorch_rx, scorch_rx * 0.58, Color(0.18, 0.04, 0.04, 0.78))
	ci.draw_line(mid - perp * scorch_rx, mid + perp * scorch_rx, Color("#ef4444"), 3.0)

	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "prop_war_banner", p_a.lerp(p_b, 0.40) + perp * 14.0 + Vector2(0, 3.0), 1.45)
	EvoWorldOverlayRenderer.draw_centered_sprite(ci, "prop_war_banner", p_a.lerp(p_b, 0.60) - perp * 14.0 + Vector2(0, 3.0), 1.45)


static func draw_war_animated_invasion(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := road.get("badge_pos", (p_a + p_b) * 0.5) as Vector2

	var pulse := 0.55 + 0.45 * sin(anim_time * 7.5)
	anim_layer.draw_line(p_a, p_b, Color(0.94, 0.27, 0.27, 0.52 * pulse), 4.2)
	for c_i in range(3):
		var t_chev := fposmod(anim_time * 0.55 + float(c_i) * 0.33, 1.0)
		var c_pos := p_a.lerp(p_b, lerpf(0.15, 0.85, t_chev))
		var tip := c_pos + dir * 6.0
		var wing_l := c_pos - dir * 5.0 + perp * 6.0
		var wing_r := c_pos - dir * 5.0 - perp * 6.0
		anim_layer.draw_line(wing_l, tip, Color("#fca5a5"), 2.4)
		anim_layer.draw_line(wing_r, tip, Color("#fca5a5"), 2.4)

	var v_textures: Array = road.get("villager_textures", [])
	var atk_col: Color = road.get("color", Color("#ef4444"))
	for w_i in range(3):
		var raw_w := fposmod(anim_time * 0.38 + float(w_i) * 0.28, 1.0)
		var w_pos := p_a.lerp(p_b, lerpf(0.14, 0.72, raw_w)) + perp * (float(w_i - 1) * 4.5)
		if v_textures.size() >= 3:
			var frame := 1 + (int(anim_time * 7.0 + float(w_i)) % 2)
			var tex: ImageTexture = v_textures[frame]
			var sz := tex.get_size() * (2.45 * 0.32)
			anim_layer.draw_texture_rect(tex, Rect2(w_pos - Vector2(sz.x * 0.5, sz.y * 0.85), sz), false)
		var spear_base := w_pos + Vector2(-4.0, -6.0)
		var spear_tip := spear_base + dir * 14.0 + Vector2(0, -10.0)
		anim_layer.draw_line(spear_base, spear_tip, Color("#cbd5e1"), 2.0)
		anim_layer.draw_circle(spear_tip, 2.2, Color("#fde047"))
		var shield_pos := w_pos + Vector2(5.0, -11.0)
		anim_layer.draw_circle(shield_pos, 4.5, Color("#cbd5e1"))
		anim_layer.draw_circle(shield_pos, 3.2, atk_col)

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
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	var steps := 14
	var prev_pt := p_a
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var jag := 0.0 if i == steps else (5.5 if i % 2 == 1 else -5.5)
		var next_pt := p_a.lerp(p_b, t) + perp * jag
		if i % 2 == 1:
			ci.draw_line(prev_pt, next_pt, Color("#431407"), 8.5)
			ci.draw_line(prev_pt, next_pt, Color("#ef4444"), 5.5)
			ci.draw_line(prev_pt, next_pt, Color("#f97316"), 3.2)
		else:
			ci.draw_circle((prev_pt + next_pt) * 0.5, 3.2, Color("#fb923c"))
		prev_pt = next_pt
	draw_road_direction_arrow(ci, p_a, p_b, Color("#f97316"), Color("#431407"))

	if show_badge:
		var mid := (p_a + p_b) * 0.5 + Vector2(0, -14.0)
		ci.draw_circle(mid, 11.5, Color("#7c2d12"))
		ci.draw_circle(mid, 9.5, Color("#f97316"))
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "icon_raid", mid + Vector2(0, 6.2), 1.35)


static func draw_raid_animated_plunder(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var v_textures: Array = road.get("villager_textures", [])

	for r_i in range(2):
		var raw_r := fposmod(anim_time * 0.62 + float(r_i) * 0.48, 1.0)
		var r_pos := p_b.lerp(p_a, lerpf(0.14, 0.86, raw_r))
		if v_textures.size() >= 3:
			var frame := 1 + (int(anim_time * 9.0 + float(r_i)) % 2)
			var tex: ImageTexture = v_textures[frame]
			var sz := tex.get_size() * (2.45 * 0.32)
			anim_layer.draw_texture_rect(tex, Rect2(r_pos - Vector2(sz.x * 0.5, sz.y * 0.85), sz), false)
		EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "prop_raid_loot", r_pos + Vector2(7.0, -5.0), 1.05)


static func draw_betrayal_road(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := (p_a + p_b) * 0.5

	var stop_a := p_a.lerp(p_b, 0.36)
	var stop_b := p_b.lerp(p_a, 0.36)
	ci.draw_line(p_a, stop_a, Color("#334155"), 14.0)
	ci.draw_line(p_a, stop_a, Color("#94a3b8"), 9.2)
	ci.draw_line(p_b, stop_b, Color("#334155"), 14.0)
	ci.draw_line(p_b, stop_b, Color("#94a3b8"), 9.2)

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
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var mid := road.get("badge_pos", (p_a + p_b) * 0.5) as Vector2
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
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.035))
	var segments := 20
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))

	ci.draw_polyline(pts, Color("#23150c"), 11.5)
	ci.draw_polyline(pts, Color("#6b4423"), 8.5)
	ci.draw_polyline(pts, Color("#c29b61"), 5.2)
	for i in range(2, segments, 2):
		ci.draw_circle(pts[i], 2.0, Color("#8c5e35"))


static func draw_settlement_perimeter_walls(r: Node2D) -> void:
	var ci: Node2D = r._network_layer
	var state: EvoTypes.WorldState = r.world_state
	const EDGE_DIR_MAP: Array[int] = [0, 5, 4, 3, 2, 1]
	const INK := Color("#23150c")
	var has_cull: bool = r._visible_world_rect.size != Vector2.ZERO
	var cull_rect: Rect2 = r._visible_world_rect.grow(HexMath.HEX_SIZE * 1.5) if has_cull else Rect2()

	for village in r._villages:
		var center: Vector2 = village["pos"]
		if has_cull and not cull_rect.has_point(center):
			continue
		var deme: EvoTypes.Deme = village["deme"]
		var has_union: bool = deme.is_multi_hex()
		if deme.defense_tier < 1 and not has_union:
			continue
		var hex_id: String = village["hex_id"]
		if not state.cells.has(hex_id) or not r._hex_polys.has(hex_id):
			continue
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		var top_pts: PackedVector2Array = r._hex_polys[hex_id]
		var mod_col: Color = village["modulate"]
		var strat_col: Color = village["strat_color"]
		var is_stone: bool = deme.defense_tier >= 2 or has_union
		var wall_r := 0.78

		var edge_suppressed: Array[bool] = [false, false, false, false, false, false]
		if has_union:
			for e in range(6):
				var dir_idx: int = EDGE_DIR_MAP[e]
				var nb_id: String = r._neighbor_id(cell, dir_idx)
				if state.cells.has(nb_id):
					var nb_cell: EvoTypes.HexCell = state.cells[nb_id]
					if not nb_cell.deme_ids.is_empty() and nb_cell.deme_ids[0] == deme.id:
						edge_suppressed[e] = true

		for e in range(6):
			if edge_suppressed[e]:
				continue
			var next_e: int = (e + 1) % 6
			var c0 := center.lerp(top_pts[e], wall_r)
			var c1 := center.lerp(top_pts[next_e], wall_r)

			if is_stone:
				var wall_h := 11.0
				var t0 := c0 + Vector2(0.0, -wall_h)
				var t1 := c1 + Vector2(0.0, -wall_h)
				var wall_quad := PackedVector2Array([t0, t1, c1, c0])
				ci.draw_colored_polygon(wall_quad, Color("#64748b") * mod_col)
				ci.draw_polyline(PackedVector2Array([t0, t1, c1, c0, t0]), INK * mod_col, 1.8)
				ci.draw_line(t0, t1, Color("#cbd5e1") * mod_col, 4.4)
				for m_i in range(5):
					var mt := (float(m_i) + 0.5) / 5.0
					var m_pt := t0.lerp(t1, mt) + Vector2(0.0, -2.5)
					ci.draw_rect(Rect2(m_pt - Vector2(3.2, 2.5), Vector2(6.4, 4.5)), Color("#e2e8f0") * mod_col, true)
					ci.draw_rect(Rect2(m_pt - Vector2(3.2, 2.5), Vector2(6.4, 4.5)), INK * mod_col, false, 1.2)
			else:
				ci.draw_line(c0, c1, INK * mod_col, 6.2)
				ci.draw_line(c0, c1, Color("#5c3a21") * mod_col, 4.2)
				for s_i in range(9):
					var st := float(s_i) / 8.0
					var sb := c0.lerp(c1, st)
					var st_top := sb + Vector2(0.0, -8.5)
					ci.draw_line(sb, st_top, INK * mod_col, 3.6)
					ci.draw_line(sb, st_top, Color("#8c5230") * mod_col, 2.2)
					ci.draw_circle(st_top, 1.4, Color("#fde68a") * mod_col)

		if is_stone:
			var wall_h := 11.0
			for v in range(6):
				var prev_e: int = (v + 5) % 6
				if edge_suppressed[v] and edge_suppressed[prev_e]:
					continue
				var cv := center.lerp(top_pts[v], wall_r)
				ci.draw_circle(cv + Vector2(0.0, -wall_h * 0.5), 7.5, INK * mod_col)
				ci.draw_circle(cv + Vector2(0.0, -wall_h * 0.5), 5.8, Color("#94a3b8") * mod_col)
				ci.draw_circle(cv + Vector2(0.0, -wall_h - 2.0), 4.8, strat_col * mod_col)
