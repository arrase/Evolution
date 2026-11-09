class_name EvoEventFxRenderer
extends RefCounted

const MAJOR_TYPES: Array[String] = [
	"war", "war_repelled", "siege", "betrayal", "raid",
	"epidemic", "epidemic_spread", "famine", "extinction",
	"pact", "walled_union", "absorption", "allopatric_speciation"
]

const DIRECTIONAL_TYPES: Array[String] = [
	"war", "war_repelled", "raid", "tribute", "betrayal",
	"colonize", "absorption", "epidemic_spread", "symbiosis", "pillage"
]

const BILATERAL_TYPES: Array[String] = ["pact", "walled_union"]


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
		item["life"] = 1.35
		item["minor"] = true
		r._fx_active.append(item)

	if not major.is_empty():
		var slot := clampf(replay_seconds * 0.72 / maxf(1.0, float(major.size())), 0.12, 0.85)
		var major_life := maxf(1.5, slot * 2.1)
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
		"war_repelled", "fortify", "defense":
			return "icon_defense"
		"siege":
			return "icon_siege"
		"raid", "pillage":
			return "icon_raid"
		"betrayal":
			return "icon_betrayal"
		"vendetta":
			return "icon_vendetta"
		"pact":
			return "icon_pact"
		"tribute":
			return "icon_tribute"
		"walled_union", "absorption", "merge":
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
		"symbiosis":
			return "icon_exchange"
	return "icon_custom"


static func _sample_bezier(p_a: Vector2, ctrl: Vector2, p_b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u) * p_a + (2.0 * u * t) * ctrl + (t * t) * p_b


static func _draw_icon_medallion(ci: CanvasItem, pos: Vector2, icon_name: String, border_col: Color, alpha: float) -> void:
	var bg := Color(0.10, 0.06, 0.03, 0.92 * alpha)
	var b_col := border_col.lightened(0.15)
	b_col.a = alpha
	ci.draw_circle(pos, 12.0, bg)
	ci.draw_arc(pos, 12.0, 0.0, TAU, 20, b_col, 2.0)
	var tex: ImageTexture = EvoPixelArtGen.get_texture(icon_name)
	ci.draw_texture_rect(
		tex,
		Rect2(pos - Vector2(9.0, 9.0), Vector2(18.0, 18.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)


static func draw_event_underlay(r: Node2D) -> void:
	if r._fx_active.is_empty():
		return
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var now: float = r._anim_time

	var idx: int = (r._fx_active as Array).size() - 1
	while idx >= 0:
		var ev: Dictionary = r._fx_active[idx]
		if now > float(ev["start"]) + float(ev["life"]):
			r._fx_active.remove_at(idx)
		idx -= 1

	for ev in r._fx_active:
		var start: float = float(ev["start"])
		if now < start:
			continue
		var life: float = float(ev["life"])
		var t := clampf((now - start) / maxf(0.01, life), 0.0, 1.0)
		var base_alpha := 0.65 if bool(ev["minor"]) else 0.96
		var fade := minf(clampf(t / 0.12, 0.0, 1.0), clampf((1.0 - t) / 0.25, 0.0, 1.0))
		var alpha := base_alpha * fade
		if alpha <= 0.02:
			continue

		var ev_type := str(ev["type"])
		var from_hex := str(ev["from_hex"])
		var to_hex := str(ev["to_hex"])
		var col := EvoUiStyle.get_event_type_color(ev_type)
		var icon_name := _get_event_icon_name(ev_type)

		if from_hex != to_hex and r._hex_centers.has(from_hex) and r._hex_centers.has(to_hex):
			var p_a: Vector2 = to_screen * (r._hex_centers[from_hex] as Vector2)
			var p_b: Vector2 = to_screen * (r._hex_centers[to_hex] as Vector2)
			var diff := p_b - p_a
			var dist := diff.length()
			if dist > 4.0:
				var dir := diff / dist
				var perp := Vector2(-dir.y, dir.x)
				var start_pt := p_a + dir * minf(24.0, dist * 0.18)
				var end_pt := p_b - dir * minf(28.0, dist * 0.22)

				if BILATERAL_TYPES.has(ev_type):
					var pulse := 0.75 + 0.25 * sin(now * 8.0)
					var glow_col := col
					glow_col.a = 0.36 * alpha * pulse
					var line_col := col.lightened(0.20)
					line_col.a = alpha
					ci.draw_line(start_pt, end_pt, glow_col, 10.0)
					ci.draw_line(start_pt + perp * 3.0, end_pt + perp * 3.0, line_col, 2.6)
					ci.draw_line(start_pt - perp * 3.0, end_pt - perp * 3.0, line_col, 2.6)
					_draw_icon_medallion(ci, (start_pt + end_pt) * 0.5, icon_name, col, alpha)
				elif DIRECTIONAL_TYPES.has(ev_type) or from_hex != to_hex:
					var ctrl := (start_pt + end_pt) * 0.5 + perp * minf(dist * 0.18, 36.0)
					var head_t := clampf(t / 0.35, 0.08, 1.0)
					var steps := 16
					var pts := PackedVector2Array()
					for s_i in range(steps + 1):
						var st := (float(s_i) / float(steps)) * head_t
						pts.append(_sample_bezier(start_pt, ctrl, end_pt, st))

					var shadow_col := Color(0.08, 0.04, 0.02, 0.72 * alpha)
					var arc_col := col.lightened(0.12)
					arc_col.a = alpha
					ci.draw_polyline(pts, shadow_col, 6.5)
					ci.draw_polyline(pts, arc_col, 3.8)

					var tip := pts[pts.size() - 1]
					var prev := pts[maxi(0, pts.size() - 2)]
					var tip_dir := (tip - prev).normalized() if tip.distance_to(prev) > 0.01 else dir
					var tip_perp := Vector2(-tip_dir.y, tip_dir.x)
					var tri := PackedVector2Array([
						tip + tip_dir * 7.0,
						tip - tip_dir * 8.0 + tip_perp * 6.5,
						tip - tip_dir * 8.0 - tip_perp * 6.5
					])
					ci.draw_colored_polygon(tri, arc_col)
					ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), shadow_col, 1.6)

					var mid_pt := _sample_bezier(start_pt, ctrl, end_pt, 0.5 * head_t)
					_draw_icon_medallion(ci, mid_pt, icon_name, col, alpha)

		if (from_hex == to_hex or not BILATERAL_TYPES.has(ev_type)) and r._hex_polys.has(to_hex) and r._hex_centers.has(to_hex):
			var center: Vector2 = r._hex_centers[to_hex]
			var top_pts: PackedVector2Array = r._hex_polys[to_hex]
			var wave_t := fposmod(t * 1.4, 1.0)
			var scale_r := lerpf(0.32, 0.96, wave_t)
			var wave_pts := PackedVector2Array()
			wave_pts.resize(7)
			for i in range(7):
				wave_pts[i] = to_screen * center.lerp(top_pts[i % 6], scale_r)
			var wave_col := col.lightened(0.15)
			wave_col.a = alpha * (1.0 - wave_t * 0.75)
			ci.draw_polyline(wave_pts, wave_col, 3.2)
			if from_hex == to_hex:
				var screen_center: Vector2 = to_screen * center
				_draw_icon_medallion(ci, screen_center + Vector2(0.0, -34.0), icon_name, col, alpha)


static func draw_event_floating_texts(r: Node2D) -> void:
	if r._fx_active.is_empty():
		return
	var ci: Node2D = r._overlay_layer
	var to_screen: Transform2D = r._world_layer.transform
	var font := ThemeDB.fallback_font
	var now: float = r._anim_time
	var stack_by_hex: Dictionary = {}

	for ev in r._fx_active:
		var start: float = float(ev["start"])
		var life: float = float(ev["life"])
		if now < start or now > start + life:
			continue
		var to_hex := str(ev["to_hex"])
		if not r._hex_centers.has(to_hex):
			continue
		var t := clampf((now - start) / maxf(0.01, life), 0.0, 1.0)
		var alpha := minf(clampf(t / 0.10, 0.0, 1.0), clampf((1.0 - t) / 0.25, 0.0, 1.0))
		if alpha <= 0.02:
			continue

		var ev_type := str(ev["type"])
		var casualties := int(ev["casualties"])
		var magnitude := float(ev["magnitude"])
		var pills: Array[Dictionary] = []

		if casualties > 0:
			pills.append({
				"icon": "icon_casualties",
				"text": "-%d" % casualties,
				"color": Color("#fca5a5"),
				"border": Color("#ef4444")
			})
		if magnitude >= 1.0 and ev_type in ["raid", "tribute", "betrayal", "pillage", "war"]:
			pills.append({
				"icon": "icon_loot",
				"text": "+%d" % int(round(magnitude)),
				"color": Color("#fef08a"),
				"border": Color("#eab308")
			})
		elif magnitude >= 1.0 and ev_type in ["colonize", "absorption"]:
			pills.append({
				"icon": "icon_migrants",
				"text": "+%d" % int(round(magnitude)),
				"color": Color("#bae6fd"),
				"border": Color("#38bdf8")
			})

		if pills.is_empty():
			continue

		var screen_pos: Vector2 = to_screen * (r._hex_centers[to_hex] as Vector2)
		var hex_slot := int(stack_by_hex.get(to_hex, 0))
		for pill in pills:
			var y_off := -102.0 - t * 32.0 - float(hex_slot) * 20.0
			hex_slot += 1
			var pill_w := 56.0
			var pill_h := 18.0
			var rect := Rect2(screen_pos.x - pill_w * 0.5, screen_pos.y + y_off, pill_w, pill_h)
			var bg := Color(0.09, 0.05, 0.03, 0.92 * alpha)
			var border_col: Color = pill["border"]
			border_col.a = alpha
			ci.draw_rect(rect, bg, true)
			ci.draw_rect(rect, border_col, false, 1.5)
			var tex: ImageTexture = EvoPixelArtGen.get_texture(str(pill["icon"]))
			ci.draw_texture_rect(
				tex,
				Rect2(rect.position + Vector2(3.0, 2.0), Vector2(14.0, 14.0)),
				false,
				Color(1.0, 1.0, 1.0, alpha)
			)
			var txt_col: Color = pill["color"]
			txt_col.a = alpha
			ci.draw_string(
				font,
				Vector2(rect.position.x + 19.0, rect.position.y + 13.0),
				str(pill["text"]),
				HORIZONTAL_ALIGNMENT_LEFT,
				pill_w - 21.0,
				11,
				txt_col
			)
		stack_by_hex[to_hex] = hex_slot
