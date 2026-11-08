class_name EvoRoadNetworkRenderer
extends RefCounted

const FLOW_PRIORITY: Dictionary = {
	"merge": 130,
	"war": 120,
	"siege": 110,
	"betrayal": 100,
	"raid": 90,
	"tribute": 80,
	"pact": 70,
	"migration": 60,
	"collab": 50,
	"symbiosis": 40,
	"exchange": 30,
	"cooperate": 20,
	"dispute": 10
}

static var _spiral_buf_a := PackedVector2Array()
static var _spiral_buf_b := PackedVector2Array()


static func collect_roads(r: Node2D) -> Array[Dictionary]:
	var roads: Array[Dictionary] = []
	var handled_deme_pairs: Dictionary = {}
	var handled_hex_pairs: Dictionary = {}
	var badge_positions: Array[Vector2] = []
	var hex_traffic_counts: Dictionary = {}
	var state: EvoTypes.WorldState = r.world_state
	var v_positions := PackedVector2Array()
	var deme_village: Dictionary = {}
	var deme_road_stance: Dictionary = {}
	var catalog: Dictionary = state.decisions_catalog

	for v in r._villages:
		v_positions.append(v["pos"] as Vector2)
		var did: String = v["deme_id"]
		deme_village[did] = v
		if state.demes.has(did):
			var d: EvoTypes.Deme = state.demes[did]
			var p_disp := 0.0
			var p_over := 0.0
			var p_coop := 0.0
			for dec_id in d.last_decision_probabilities.keys():
				var prob := float(d.last_decision_probabilities[dec_id])
				var arch := ""
				if catalog.has(dec_id):
					arch = (catalog[dec_id] as EvoTypes.DecisionDef).archetype
				else:
					var s := str(dec_id)
					if s.contains("dispute"):
						arch = "dispute"
					elif s.contains("overexploit"):
						arch = "overexploit"
					elif s.contains("cooperate") or s.contains("exchange"):
						arch = "cooperate"
				if arch == "dispute":
					p_disp += prob
				elif arch == "overexploit":
					p_over += prob
				elif arch == "cooperate" or arch == "exchange":
					p_coop += prob
			var dom_arch: String = v["archetype"]
			deme_road_stance[did] = {
				"arch": dom_arch,
				"conflict": p_disp >= 0.10 or p_over >= 0.30 or dom_arch == "dispute" or dom_arch == "overexploit",
				"coop": p_coop >= 0.14 or dom_arch == "cooperate" or dom_arch == "exchange"
			}
	r.set_meta("_v_pos_cache", v_positions)
	r.set_meta("_deme_v_cache", deme_village)
	r.set_meta("_deme_stance_cache", deme_road_stance)

	var best_flow_by_pair: Dictionary = {}
	var ordered_pair_keys: Array[String] = []
	for flow in state.active_flows:
		if not state.cells.has(flow.from_hex_id) or not state.cells.has(flow.to_hex_id):
			continue
		if flow.from_hex_id == flow.to_hex_id:
			continue
		var h_key := make_pair_key(flow.from_hex_id, flow.to_hex_id)
		var prio: int = int(FLOW_PRIORITY.get(flow.flow_type, 0))
		if not best_flow_by_pair.has(h_key):
			best_flow_by_pair[h_key] = flow
			ordered_pair_keys.append(h_key)
		else:
			var cur_best: EvoTypes.HexEdgeFlow = best_flow_by_pair[h_key]
			if prio > int(FLOW_PRIORITY.get(cur_best.flow_type, 0)):
				best_flow_by_pair[h_key] = flow

	for h_key in ordered_pair_keys:
		var flow: EvoTypes.HexEdgeFlow = best_flow_by_pair[h_key]
		var cell_a: EvoTypes.HexCell = state.cells[flow.from_hex_id]
		var cell_b: EvoTypes.HexCell = state.cells[flow.to_hex_id]
		handled_hex_pairs[h_key] = true

		var da_id: String = flow.from_deme_id if flow.from_deme_id != "" else (cell_a.deme_ids[0] if not cell_a.deme_ids.is_empty() else "")
		var db_id: String = flow.to_deme_id if flow.to_deme_id != "" else (cell_b.deme_ids[0] if not cell_b.deme_ids.is_empty() else "")
		if da_id != "" and db_id != "":
			handled_deme_pairs[make_pair_key(da_id, db_id)] = true

		var is_pact := (da_id != "" and db_id != "" and EvoTypes.is_pact_active(state, da_id, db_id))
		var is_vendetta := (da_id != "" and db_id != "" and is_vendetta_pair(state, da_id, db_id))

		var endpoints := resolve_road_endpoints(r, cell_a, cell_b, da_id, db_id)
		var trim_a := get_cell_plaza_trim(cell_a)
		var trim_b := get_cell_plaza_trim(cell_b)
		var trimmed := trim_road_segment(endpoints["p_a"] as Vector2, endpoints["p_b"] as Vector2, trim_a, trim_b)
		var p_a: Vector2 = trimmed["p_a"]
		var p_b: Vector2 = trimmed["p_b"]
		var edge_mid := (p_a + p_b) * 0.5
		var edge_tangent := compute_edge_tangent(p_a, p_b)
		var curve_f := 0.045
		var is_prio: bool = (
			cell_a.id == r.selected_hex_id
			or cell_b.id == r.selected_hex_id
			or cell_a.id == r.hovered_hex_id
			or cell_b.id == r.hovered_hex_id
		)

		var flow_color := Color("#eab308")
		if da_id != "" and deme_village.has(da_id):
			flow_color = deme_village[da_id]["strat_color"]
		elif da_id != "" and state.demes.has(da_id):
			flow_color = EvoPropFloraRenderer.resolve_deme_strategy_color(state, state.demes[da_id])

		var effective_type := flow.flow_type
		if effective_type in ["exchange", "cooperate", "symbiosis", "trade"]:
			if is_pact:
				effective_type = "pact"
			else:
				effective_type = "symbiosis"
		elif effective_type == "migration":
			effective_type = "migration"

		var show_badge := register_road_badge(r, edge_mid, badge_positions, is_prio or effective_type in ["war", "siege", "raid", "pact", "betrayal", "tribute", "merge"])
		var show_traffic := claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, is_prio or effective_type in ["pact", "tribute", "merge"])

		var kind := effective_type
		if effective_type == "symbiosis" and should_use_bridge(r, cell_a, cell_b):
			kind = "bridge"

		roads.append({
			"kind": kind,
			"flow_type": effective_type,
			"hex_a": cell_a.id,
			"hex_b": cell_b.id,
			"world_a": endpoints["world_a"],
			"z_a": endpoints["z_a"],
			"trim_a": trim_a,
			"world_b": endpoints["world_b"],
			"z_b": endpoints["z_b"],
			"trim_b": trim_b,
			"p_a": p_a,
			"p_b": p_b,
			"edge_mid": edge_mid,
			"edge_tangent": edge_tangent,
			"is_pact": is_pact or kind == "pact",
			"is_vendetta": is_vendetta or kind in ["dispute", "war", "siege", "raid", "betrayal"],
			"curve_factor": 0.14 if kind in ["migration", "expedition"] else curve_f,
			"show_badge": show_badge,
			"show_traffic": show_traffic,
			"badge_pos": edge_mid,
			"color": Color("#10b981") if kind == "pact" else flow_color
		})

	var all_demes: Array[EvoTypes.Deme] = []
	for d_id in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[d_id]
		if d.population > 0 and state.cells.has(d.hex_id):
			all_demes.append(d)

	var connected_deme_ids: Dictionary = {}
	for d in all_demes:
		var ca: EvoTypes.HexCell = state.cells[d.hex_id]
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, state.cells):
			if not (state.cells[n_id] as EvoTypes.HexCell).deme_ids.is_empty():
				connected_deme_ids[d.id] = true
				break

	for hex_id in state.cells:
		var ca: EvoTypes.HexCell = state.cells[hex_id]
		if ca.deme_ids.is_empty():
			continue
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, state.cells):
			var cb: EvoTypes.HexCell = state.cells[n_id]
			if cb.deme_ids.is_empty():
				continue
			var h_key := make_pair_key(ca.id, cb.id)
			if handled_hex_pairs.has(h_key):
				continue
			handled_hex_pairs[h_key] = true

			var pair := find_closest_deme_pair(r, ca, cb)
			if pair.is_empty():
				continue
			var da: EvoTypes.Deme = pair["da"]
			var db: EvoTypes.Deme = pair["db"]
			handled_deme_pairs[make_pair_key(da.id, db.id)] = true

			var world_a: Vector2 = pair["wa"]
			var z_a: float = r._get_cell_top_z(ca)
			var trim_a := get_cell_plaza_trim(ca)
			var world_b: Vector2 = pair["wb"]
			var z_b: float = r._get_cell_top_z(cb)
			var trim_b := get_cell_plaza_trim(cb)
			var trimmed := trim_road_segment(r._project(world_a, z_a), r._project(world_b, z_b), trim_a, trim_b)
			var p_a: Vector2 = trimmed["p_a"]
			var p_b: Vector2 = trimmed["p_b"]
			var edge_mid := (p_a + p_b) * 0.5
			var edge_tangent := compute_edge_tangent(p_a, p_b)
			var is_prio: bool = (
				ca.id == r.selected_hex_id
				or cb.id == r.selected_hex_id
				or ca.id == r.hovered_hex_id
				or cb.id == r.hovered_hex_id
			)
			var is_pact := EvoTypes.is_pact_active(state, da.id, db.id)
			var is_vendetta := is_vendetta_pair(state, da.id, db.id)
			var rel := "pact" if is_pact else ("dispute_front" if is_vendetta else classify_village_pair_relation(r, da, db))

			match rel:
				"pact":
					var show_badge := register_road_badge(r, edge_mid, badge_positions, true)
					var show_traffic := claim_road_traffic(ca.id, cb.id, hex_traffic_counts, true)
					roads.append({
						"kind": "pact",
						"flow_type": "pact",
						"hex_a": ca.id,
						"hex_b": cb.id,
						"world_a": world_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": world_b,
						"z_b": z_b,
						"trim_b": trim_b,
						"p_a": p_a,
						"p_b": p_b,
						"edge_mid": edge_mid,
						"edge_tangent": edge_tangent,
						"is_pact": true,
						"is_vendetta": false,
						"curve_factor": 0.045,
						"show_badge": show_badge,
						"show_traffic": show_traffic,
						"badge_pos": edge_mid,
						"color": Color("#10b981")
					})
				"dispute_front":
					var show_badge := register_road_badge(r, edge_mid, badge_positions, is_prio)
					roads.append({
						"kind": "dispute",
						"flow_type": "dispute",
						"hex_a": ca.id,
						"hex_b": cb.id,
						"world_a": world_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": world_b,
						"z_b": z_b,
						"trim_b": trim_b,
						"p_a": p_a,
						"p_b": p_b,
						"edge_mid": edge_mid,
						"edge_tangent": edge_tangent,
						"is_pact": false,
						"is_vendetta": true,
						"show_badge": show_badge,
						"badge_pos": edge_mid,
						"color": Color("#ef4444")
					})
				"active_road":
					var kind := "bridge" if should_use_bridge(r, ca, cb) else "symbiosis"
					var show_badge := register_road_badge(r, edge_mid, badge_positions, is_prio)
					var show_traffic := claim_road_traffic(ca.id, cb.id, hex_traffic_counts, is_prio)
					roads.append({
						"kind": kind,
						"flow_type": "symbiosis",
						"hex_a": ca.id,
						"hex_b": cb.id,
						"world_a": world_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": world_b,
						"z_b": z_b,
						"trim_b": trim_b,
						"p_a": p_a,
						"p_b": p_b,
						"edge_mid": edge_mid,
						"edge_tangent": edge_tangent,
						"is_pact": false,
						"is_vendetta": false,
						"curve_factor": 0.045,
						"show_badge": show_badge,
						"show_traffic": show_traffic,
						"badge_pos": edge_mid,
						"color": EvoPropFloraRenderer.resolve_deme_strategy_color(state, da)
					})
				_:
					var dis_age := get_disused_road_age(r, da.id, db.id, ca.id, cb.id)
					if dis_age > 0:
						var show_badge := register_road_badge(r, edge_mid, badge_positions, is_prio)
						roads.append({
							"kind": "broken",
							"hex_a": ca.id,
							"hex_b": cb.id,
							"world_a": world_a,
							"z_a": z_a,
							"trim_a": trim_a,
							"world_b": world_b,
							"z_b": z_b,
							"trim_b": trim_b,
							"p_a": p_a,
							"p_b": p_b,
							"edge_mid": edge_mid,
							"edge_tangent": edge_tangent,
							"show_badge": show_badge,
							"alpha": 0.52 if dis_age == 2 else 0.90
						})

	for da in all_demes:
		if connected_deme_ids.has(da.id):
			continue
		var ca: EvoTypes.HexCell = state.cells[da.hex_id]
		var w_a := get_deme_world_pos(ca, da.id)
		var z_a: float = r._get_cell_top_z(ca)
		var p_a_raw: Vector2 = r._project(w_a, z_a)
		var trim_a := get_cell_plaza_trim(ca)
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[n_id]
			if ncell.biome == "coastal_shallows" and ncell.altitude >= state.sea_level:
				var h_key := make_pair_key(ca.id, ncell.id)
				if not handled_hex_pairs.has(h_key):
					handled_hex_pairs[h_key] = true
					var w_b := HexMath.axial_to_world(ncell.q, ncell.r)
					var z_b: float = r._get_cell_top_z(ncell)
					var seg := trim_road_segment(p_a_raw, r._project(w_b, z_b), trim_a, 18.0)
					var p_a: Vector2 = seg["p_a"]
					var p_b: Vector2 = seg["p_b"]
					roads.append({
						"kind": "expedition",
						"flow_type": "migration",
						"hex_a": ca.id,
						"hex_b": ncell.id,
						"world_a": w_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": w_b,
						"z_b": z_b,
						"trim_b": 18.0,
						"p_a": p_a,
						"p_b": p_b,
						"edge_mid": (p_a + p_b) * 0.5,
						"edge_tangent": compute_edge_tangent(p_a, p_b),
						"curve_factor": 0.14
					})

	for disused in state.disused_connections:
		var age_val := int(disused.get("age", 1))
		if age_val > 2:
			continue
		var from_id := str(disused.get("from_hex_id", ""))
		var to_id := str(disused.get("to_hex_id", ""))
		if from_id == to_id or not state.cells.has(from_id) or not state.cells.has(to_id):
			continue
		var ca: EvoTypes.HexCell = state.cells[from_id]
		var cb: EvoTypes.HexCell = state.cells[to_id]
		if HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r) > 1:
			continue
		var h_key := make_pair_key(from_id, to_id)
		if handled_hex_pairs.has(h_key):
			continue
		handled_hex_pairs[h_key] = true

		var fa := str(disused.get("from_deme_id", ""))
		var fb := str(disused.get("to_deme_id", ""))
		var endpoints := resolve_road_endpoints(r, ca, cb, fa, fb)
		var trim_a := get_cell_plaza_trim(ca)
		var trim_b := get_cell_plaza_trim(cb)
		var seg := trim_road_segment(endpoints["p_a"] as Vector2, endpoints["p_b"] as Vector2, trim_a, trim_b)
		var p_a: Vector2 = seg["p_a"]
		var p_b: Vector2 = seg["p_b"]
		var edge_mid := (p_a + p_b) * 0.5
		roads.append({
			"kind": "broken",
			"hex_a": from_id,
			"hex_b": to_id,
			"world_a": endpoints["world_a"],
			"z_a": endpoints["z_a"],
			"trim_a": trim_a,
			"world_b": endpoints["world_b"],
			"z_b": endpoints["z_b"],
			"trim_b": trim_b,
			"p_a": p_a,
			"p_b": p_b,
			"edge_mid": edge_mid,
			"edge_tangent": compute_edge_tangent(p_a, p_b),
			"show_badge": register_road_badge(r, edge_mid, badge_positions, false),
			"alpha": 0.52 if age_val == 2 else 0.90
		})

	return prune_redundant_triangle_chords(r, roads)


static func is_vendetta_pair(state: EvoTypes.WorldState, id_a: String, id_b: String) -> bool:
	var pk := EvoTypes.make_pair_key(id_a, id_b)
	return int(state.active_pacts.get(pk, 0)) < 0


static func compute_edge_tangent(p_a: Vector2, p_b: Vector2) -> Vector2:
	var diff := p_b - p_a
	var len := diff.length()
	if len < 0.01:
		return Vector2.UP
	var dir := diff / len
	return Vector2(-dir.y, dir.x)


static func prune_redundant_triangle_chords(r: Node2D, roads: Array[Dictionary]) -> Array[Dictionary]:
	var state: EvoTypes.WorldState = r.world_state
	var coop_pairs: Dictionary = {}
	for rd in roads:
		var k := str(rd.get("kind", ""))
		if k in ["collab", "symbiosis", "bridge"]:
			var ha := str(rd.get("hex_a", ""))
			var hb := str(rd.get("hex_b", ""))
			if ha != "" and hb != "":
				coop_pairs[make_pair_key(ha, hb)] = true

	var result: Array[Dictionary] = []
	for rd in roads:
		var k := str(rd.get("kind", ""))
		if k in ["collab", "symbiosis", "bridge"]:
			var ha := str(rd.get("hex_a", ""))
			var hb := str(rd.get("hex_b", ""))
			if state.cells.has(ha) and state.cells.has(hb):
				var ca: EvoTypes.HexCell = state.cells[ha]
				var cb: EvoTypes.HexCell = state.cells[hb]
				if ca.r == cb.r and abs(ca.q - cb.q) == 1:
					var has_triangle_bypass := false
					for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, state.cells):
						if n_id == hb:
							continue
						var nc: EvoTypes.HexCell = state.cells[n_id]
						if HexMath.hex_distance(cb.q, cb.r, nc.q, nc.r) == 1:
							if coop_pairs.has(make_pair_key(ha, n_id)) and coop_pairs.has(make_pair_key(hb, n_id)):
								has_triangle_bypass = true
								break
					if has_triangle_bypass:
						continue
		project_road_entry(r, rd, false)
		result.append(rd)
	return result


static func project_road_entry(r: Node2D, road: Dictionary, force_reproject: bool = true) -> void:
	var p_a: Vector2
	var p_b: Vector2
	if force_reproject or not road.has("p_a"):
		var raw_a: Vector2 = r._project(road["world_a"] as Vector2, float(road["z_a"]))
		var raw_b: Vector2 = r._project(road["world_b"] as Vector2, float(road["z_b"]))
		var trimmed := trim_road_segment(raw_a, raw_b, float(road["trim_a"]), float(road["trim_b"]))
		p_a = trimmed["p_a"]
		p_b = trimmed["p_b"]
		road["p_a"] = p_a
		road["p_b"] = p_b
	else:
		p_a = road["p_a"]
		p_b = road["p_b"]
	road["a_pos"] = p_a
	road["b_pos"] = p_b
	var edge_mid := (p_a + p_b) * 0.5
	var edge_tangent := compute_edge_tangent(p_a, p_b)
	road["edge_mid"] = edge_mid
	road["edge_tangent"] = edge_tangent
	road["badge_pos"] = edge_mid
	var curve_f := float(road.get("curve_factor", 0.045))
	var curve_sign := -1.0 if road.get("kind", "") in ["expedition", "migration"] else 1.0
	var dist := p_a.distance_to(p_b)
	road["ctrl"] = edge_mid + edge_tangent * (minf(dist * curve_f, 12.0) * curve_sign)


static func reproject_roads(r: Node2D) -> void:
	for road in r._roads:
		project_road_entry(r, road, true)


static func draw_network_roads(r: Node2D) -> void:
	for road in r._roads:
		var kind := str(road.get("kind", ""))
		match kind:
			"pact":
				draw_pact_highway(r, road)
				draw_pact_border_front(r, road)
			"merge":
				draw_merge_avenue(r, road)
			"tribute":
				draw_tribute_route(r, road)
			"war", "siege":
				draw_war_corridor(r, road)
				draw_conflict_border_front(r, road)
			"raid":
				draw_raid_trail(r, road)
				draw_conflict_border_front(r, road)
			"betrayal":
				draw_betrayal_road(r, road)
				draw_conflict_border_front(r, road)
			"symbiosis", "exchange", "collab":
				draw_collaboration_route(r, road)
			"bridge":
				draw_wooden_bridge(r, road)
			"dispute":
				draw_dispute_barricade_front(r, road)
				draw_conflict_border_front(r, road)
			"broken":
				draw_broken_cut_road(r, road)
			"expedition", "migration":
				draw_migration_expedition(r, road)


static func draw_pact_border_front(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var edge_mid: Vector2 = road["edge_mid"]
	var tangent: Vector2 = road["edge_tangent"]
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var axis := (p_b - p_a).normalized() if p_a.distance_to(p_b) > 0.01 else Vector2.RIGHT

	# Shared hex edge golden-emerald double diplomatic border line
	var e0 := edge_mid - tangent * 30.0
	var e1 := edge_mid + tangent * 30.0
	ci.draw_line(e0 - axis * 2.5, e1 - axis * 2.5, Color("#10b981"), 2.6)
	ci.draw_line(e0 + axis * 2.5, e1 + axis * 2.5, Color("#fbbf24"), 2.6)

	# Stone bridge arch spanning edge_mid
	var arch_a := edge_mid - axis * 14.0
	var arch_b := edge_mid + axis * 14.0
	ci.draw_line(arch_a - tangent * 6.5, arch_b - tangent * 6.5, Color("#cbd5e1"), 3.0)
	ci.draw_line(arch_a + tangent * 6.5, arch_b + tangent * 6.5, Color("#cbd5e1"), 3.0)
	ci.draw_circle(e0, 3.5, Color("#fbbf24"))
	ci.draw_circle(e1, 3.5, Color("#fbbf24"))


static func draw_conflict_border_front(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var edge_mid: Vector2 = road["edge_mid"]
	var tangent: Vector2 = road["edge_tangent"]
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var axis := (p_b - p_a).normalized() if p_a.distance_to(p_b) > 0.01 else Vector2.RIGHT

	# Crimson-iron jagged barricade along shared hex edge
	var jag_pts := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var t := lerpf(-28.0, 28.0, float(i) / float(steps))
		var offset := (4.5 if i % 2 == 0 else -4.5)
		jag_pts.append(edge_mid + tangent * t + axis * offset)
	ci.draw_polyline(jag_pts, Color("#1e293b"), 4.2)
	ci.draw_polyline(jag_pts, Color("#dc2626"), 2.2)

	# Crossed iron lances at border front
	for s_pos in [edge_mid - tangent * 12.0, edge_mid + tangent * 12.0]:
		ci.draw_line(s_pos - axis * 7.0 - tangent * 4.0, s_pos + axis * 7.0 + tangent * 4.0, Color("#94a3b8"), 2.0)
		ci.draw_line(s_pos - axis * 7.0 + tangent * 4.0, s_pos + axis * 7.0 - tangent * 4.0, Color("#fca5a5"), 2.0)


static func draw_animated_roads(r: Node2D) -> void:
	var anim_layer: Node2D = r._anim_layer
	var vis_rect: Rect2 = r._visible_world_rect
	var anim_time: float = r._anim_time
	for road in r._roads:
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not vis_rect.has_point(p_a) and not vis_rect.has_point(p_b):
			continue
		var edge_mid: Vector2 = road.get("edge_mid", (p_a + p_b) * 0.5)
		var tangent: Vector2 = road.get("edge_tangent", compute_edge_tangent(p_a, p_b))
		var axis := (p_b - p_a).normalized() if p_a.distance_to(p_b) > 0.01 else Vector2.RIGHT
		var kind := str(road.get("kind", ""))

		match kind:
			"pact":
				for i in range(3):
					var t_fwd := fposmod(anim_time * 0.36 + float(i) * 0.33, 1.0)
					var t_rev := 1.0 - t_fwd
					var pos_1 := p_a.lerp(p_b, lerpf(0.14, 0.86, t_fwd)) + tangent * 3.5
					var pos_2 := p_a.lerp(p_b, lerpf(0.14, 0.86, t_rev)) - tangent * 3.5
					anim_layer.draw_circle(pos_1, 3.8, Color("#10b981"))
					anim_layer.draw_circle(pos_1, 2.0, Color("#fef08a"))
					anim_layer.draw_circle(pos_2, 3.8, Color("#f59e0b"))
					anim_layer.draw_circle(pos_2, 2.0, Color("#fef08a"))
			"symbiosis", "exchange", "collab", "bridge":
				# Trait-transfer spiral beams along conduit
				var segs := 18
				if _spiral_buf_a.size() != segs + 1:
					_spiral_buf_a.resize(segs + 1)
					_spiral_buf_b.resize(segs + 1)
				for i in range(segs + 1):
					var u := float(i) / float(segs)
					var base_pt := p_a.lerp(p_b, u)
					var wave := sin(u * TAU * 2.0 - anim_time * 5.0) * 5.5
					_spiral_buf_a[i] = base_pt + tangent * wave
					_spiral_buf_b[i] = base_pt - tangent * wave
				anim_layer.draw_polyline(_spiral_buf_a, Color(0.22, 0.74, 0.97, 0.72), 2.2)
				anim_layer.draw_polyline(_spiral_buf_b, Color(0.98, 0.75, 0.14, 0.72), 2.2)
				var mote_t := fposmod(anim_time * 0.48, 1.0)
				anim_layer.draw_circle(p_a.lerp(p_b, mote_t), 4.0, Color("#fef08a"))
			"merge":
				for i in range(3):
					var u := fposmod(anim_time * 0.45 + float(i) * 0.33, 1.0)
					var pt := p_a.lerp(p_b, u)
					anim_layer.draw_circle(pt, 5.0, Color("#fbbf24"))
					anim_layer.draw_circle(pt, 2.8, Color("#10b981"))
			"tribute":
				for i in range(3):
					var u := fposmod(anim_time * 0.42 + float(i) * 0.33, 1.0)
					var pt := p_a.lerp(p_b, lerpf(0.12, 0.88, u))
					anim_layer.draw_circle(pt, 4.5, Color("#d97706"))
					anim_layer.draw_circle(pt, 2.5, Color("#fef08a"))
			"war", "siege":
				draw_war_animated_invasion(r, road)
			"raid":
				draw_raid_animated_plunder(r, road)
			"betrayal":
				draw_betrayal_animated_ruin(r, road)
			"dispute":
				# Directional annexation chevrons & Hawk-Hawk clash shockwaves
				for c_i in range(3):
					var u := fposmod(anim_time * 0.50 + float(c_i) * 0.33, 1.0)
					var c_pos := p_a.lerp(p_b, lerpf(0.16, 0.84, u))
					var tip := c_pos + axis * 5.5
					anim_layer.draw_line(c_pos - axis * 4.5 + tangent * 5.5, tip, Color("#fca5a5"), 2.2)
					anim_layer.draw_line(c_pos - axis * 4.5 - tangent * 5.5, tip, Color("#fca5a5"), 2.2)
				draw_battle_sparks(r, edge_mid)
			"expedition", "migration":
				for i in range(3):
					var u := fposmod(anim_time * 0.44 + float(i) * 0.33, 1.0)
					var c_pos := p_a.lerp(p_b, lerpf(0.14, 0.88, u))
					var tip := c_pos + axis * 6.0
					anim_layer.draw_line(c_pos - axis * 4.5 + tangent * 5.0, tip, Color("#38bdf8"), 2.4)
					anim_layer.draw_line(c_pos - axis * 4.5 - tangent * 5.0, tip, Color("#38bdf8"), 2.4)


static func draw_battle_sparks(r: Node2D, mid: Vector2) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var pulse := fposmod(anim_time * 1.8, 1.0)
	anim_layer.draw_arc(mid, lerpf(6.0, 22.0, pulse), 0.0, TAU, 20, Color(0.94, 0.27, 0.27, (1.0 - pulse) * 0.75), 2.2)
	for s_i in range(4):
		var ang := anim_time * 5.0 + float(s_i) * (TAU * 0.25)
		var spark_pos := mid + Vector2(cos(ang) * 10.0, sin(ang) * 6.0 - 4.0)
		anim_layer.draw_circle(spark_pos, 2.8, Color("#fde047") if s_i % 2 == 0 else Color("#f97316"))


static func make_pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


static func get_cell_plaza_trim(cell: EvoTypes.HexCell) -> float:
	return 16.0 if cell.deme_ids.is_empty() else 46.0


static func trim_road_segment(p_a: Vector2, p_b: Vector2, trim_a: float, trim_b: float) -> Dictionary:
	var diff := p_b - p_a
	var dist := diff.length()
	if dist < 1.0:
		return {"p_a": p_a, "p_b": p_b}
	var dir := diff / dist
	var ta := minf(trim_a, dist * 0.30)
	var tb := minf(trim_b, dist * 0.30)
	return {"p_a": p_a + dir * ta, "p_b": p_b - dir * tb}


static func register_road_badge(
	r: Node2D,
	badge_pos: Vector2,
	badge_positions: Array[Vector2],
	is_priority: bool
) -> bool:
	var min_v_dist_sq := (42.0 * 42.0) if is_priority else (54.0 * 54.0)
	if r.has_meta("_v_pos_cache"):
		var v_positions: PackedVector2Array = r.get_meta("_v_pos_cache")
		for vp in v_positions:
			if badge_pos.distance_squared_to(vp) < min_v_dist_sq:
				return false
	var min_b_dist_sq := (34.0 * 34.0) if is_priority else (48.0 * 48.0)
	for bp in badge_positions:
		if badge_pos.distance_squared_to(bp) < min_b_dist_sq:
			return false
	badge_positions.append(badge_pos)
	return true


static func claim_road_traffic(
	hex_a: String,
	hex_b: String,
	hex_traffic_counts: Dictionary,
	is_priority: bool
) -> bool:
	var count_a := int(hex_traffic_counts.get(hex_a, 0))
	var count_b := int(hex_traffic_counts.get(hex_b, 0))
	if not is_priority and (count_a >= 3 or count_b >= 3):
		return false
	hex_traffic_counts[hex_a] = count_a + 1
	if hex_b != hex_a:
		hex_traffic_counts[hex_b] = count_b + 1
	return true


static func get_disused_road_age(r: Node2D, da_id: String, db_id: String, hex_a: String, hex_b: String) -> int:
	for dis in r.world_state.disused_connections:
		var age_val := int(dis.get("age", 1))
		if age_val > 2:
			continue
		var fa := str(dis.get("from_deme_id", ""))
		var fb := str(dis.get("to_deme_id", ""))
		if (fa == da_id and fb == db_id) or (fa == db_id and fb == da_id):
			return maxi(1, age_val)
		var ha := str(dis.get("from_hex_id", ""))
		var hb := str(dis.get("to_hex_id", ""))
		if hex_a != hex_b and ((ha == hex_a and hb == hex_b) or (ha == hex_b and hb == hex_a)):
			return maxi(1, age_val)
	return -1


static func should_use_bridge(r: Node2D, cell_a: EvoTypes.HexCell, cell_b: EvoTypes.HexCell) -> bool:
	return (
		cell_a.biome == "coastal_shallows"
		or cell_b.biome == "coastal_shallows"
		or cell_a.altitude < r.world_state.sea_level
		or cell_b.altitude < r.world_state.sea_level
		or absf(cell_a.altitude - cell_b.altitude) >= 0.20
	)


static func get_deme_archetype_prob(r: Node2D, deme: EvoTypes.Deme, target_arch: String) -> float:
	var total := 0.0
	var catalog: Dictionary = r.world_state.decisions_catalog
	for dec_id in deme.last_decision_probabilities.keys():
		var prob := float(deme.last_decision_probabilities[dec_id])
		if catalog.has(dec_id):
			var d_def: EvoTypes.DecisionDef = catalog[dec_id]
			if d_def.archetype == target_arch:
				total += prob
		elif str(dec_id).contains(target_arch):
			total += prob
	return total


static func classify_village_pair_relation(r: Node2D, da: EvoTypes.Deme, db: EvoTypes.Deme) -> String:
	if EvoTypes.is_pact_active(r.world_state, da.id, db.id):
		return "pact"
	if is_vendetta_pair(r.world_state, da.id, db.id):
		return "dispute_front"

	var stance_cache: Dictionary = r.get_meta("_deme_stance_cache") if r.has_meta("_deme_stance_cache") else {}
	if stance_cache.has(da.id) and stance_cache.has(db.id):
		var sa: Dictionary = stance_cache[da.id]
		var sb: Dictionary = stance_cache[db.id]
		var arch_a_c: String = sa["arch"]
		var arch_b_c: String = sb["arch"]
		var has_conflict_c: bool = bool(sa["conflict"]) or bool(sb["conflict"])
		if da.lineage_id != db.lineage_id and has_conflict_c:
			return "dispute_front"
		if arch_a_c == "dispute" or arch_b_c == "dispute":
			return "dispute_front"
		if bool(sa["coop"]) or bool(sb["coop"]):
			return "active_road"
		if da.lineage_id == db.lineage_id and da.isolation_turns < 3 and db.isolation_turns < 3 and not has_conflict_c:
			return "active_road"
		return "broken_road"

	var arch_a: String = r._get_deme_dominant_archetype(da)
	var arch_b: String = r._get_deme_dominant_archetype(db)
	var disp_a := get_deme_archetype_prob(r, da, "dispute")
	var disp_b := get_deme_archetype_prob(r, db, "dispute")
	var over_a := get_deme_archetype_prob(r, da, "overexploit")
	var over_b := get_deme_archetype_prob(r, db, "overexploit")
	var has_conflict_stance: bool = (
		disp_a >= 0.10 or disp_b >= 0.10
		or over_a >= 0.30 or over_b >= 0.30
		or arch_a == "dispute" or arch_b == "dispute"
		or arch_a == "overexploit" or arch_b == "overexploit"
	)
	if da.lineage_id != db.lineage_id and has_conflict_stance:
		return "dispute_front"
	if arch_a == "dispute" or arch_b == "dispute":
		return "dispute_front"
	var coop_a := get_deme_archetype_prob(r, da, "cooperate") + get_deme_archetype_prob(r, da, "exchange")
	var coop_b := get_deme_archetype_prob(r, db, "cooperate") + get_deme_archetype_prob(r, db, "exchange")
	if coop_a >= 0.14 or coop_b >= 0.14 or arch_a in ["cooperate", "exchange"] or arch_b in ["cooperate", "exchange"]:
		return "active_road"
	if da.lineage_id == db.lineage_id and da.isolation_turns < 3 and db.isolation_turns < 3 and not has_conflict_stance:
		return "active_road"
	return "broken_road"


static func get_deme_world_pos(cell: EvoTypes.HexCell, _deme_id: String) -> Vector2:
	return HexMath.axial_to_world(cell.q, cell.r)


static func find_closest_deme_pair(r: Node2D, cell_a: EvoTypes.HexCell, cell_b: EvoTypes.HexCell) -> Dictionary:
	if cell_a.deme_ids.is_empty() or cell_b.deme_ids.is_empty():
		return {}
	var demes: Dictionary = r.world_state.demes
	var id_a: String = cell_a.deme_ids[0]
	var id_b: String = cell_b.deme_ids[0]
	if not demes.has(id_a) or not demes.has(id_b):
		return {}
	return {
		"da": demes[id_a],
		"db": demes[id_b],
		"wa": HexMath.axial_to_world(cell_a.q, cell_a.r),
		"wb": HexMath.axial_to_world(cell_b.q, cell_b.r)
	}


static func resolve_road_endpoints(
	r: Node2D,
	cell_a: EvoTypes.HexCell,
	cell_b: EvoTypes.HexCell,
	_from_deme_id: String,
	_to_deme_id: String
) -> Dictionary:
	var world_a := HexMath.axial_to_world(cell_a.q, cell_a.r)
	var world_b := HexMath.axial_to_world(cell_b.q, cell_b.r)
	var z_a: float = r._get_cell_top_z(cell_a)
	var z_b: float = r._get_cell_top_z(cell_b)
	return {
		"world_a": world_a,
		"z_a": z_a,
		"world_b": world_b,
		"z_b": z_b,
		"p_a": r._project(world_a, z_a),
		"p_b": r._project(world_b, z_b)
	}


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


static func draw_collaboration_route(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	var segments := 20
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))
	ci.draw_polyline(pts, Color("#4a3219"), 12.0)
	ci.draw_polyline(pts, Color("#8c6d46"), 9.0)
	ci.draw_polyline(pts, Color("#d6b88a"), 5.5)


static func draw_wooden_bridge(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var perp: Vector2 = road.get("edge_tangent", compute_edge_tangent(p_a, p_b))
	var steps := 18
	var curve_pts := PackedVector2Array()
	var rail_left := PackedVector2Array()
	var rail_right := PackedVector2Array()
	for i in range(steps + 1):
		var pt := bridge_arch_point(p_a, p_b, float(i) / float(steps))
		curve_pts.append(pt)
		rail_left.append(pt - perp * 6.5 + Vector2(0, -4.0))
		rail_right.append(pt + perp * 6.5 + Vector2(0, -4.0))
	ci.draw_polyline(curve_pts, Color("#3d2314"), 13.0)
	ci.draw_polyline(curve_pts, Color("#b07d4f"), 9.5)
	ci.draw_polyline(rail_left, Color("#6b3e26"), 2.2)
	ci.draw_polyline(rail_right, Color("#6b3e26"), 2.2)


static func draw_dispute_barricade_front(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var mid: Vector2 = road.get("edge_mid", (p_a + p_b) * 0.5)
	var stop_a := p_a.lerp(p_b, 0.38)
	var stop_b := p_b.lerp(p_a, 0.38)
	ci.draw_line(p_a, stop_a, Color("#3b2313"), 9.5)
	ci.draw_line(p_a, stop_a, Color("#785233"), 6.0)
	ci.draw_line(p_b, stop_b, Color("#3b2313"), 9.5)
	ci.draw_line(p_b, stop_b, Color("#785233"), 6.0)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, 18.0, 10.5, Color(0.16, 0.08, 0.05, 0.68))


static func draw_broken_cut_road(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var alpha: float = float(road.get("alpha", 0.90))
	var mod_col := Color(1.0, 1.0, 1.0, alpha)
	for rng in [Vector2(0.08, 0.36), Vector2(0.64, 0.92)]:
		for i in range(6):
			var pt := p_a.lerp(p_b, lerpf(rng.x, rng.y, float(i) / 5.0))
			ci.draw_circle(pt, 4.2, Color("#47423c") * mod_col)
			ci.draw_circle(pt, 2.8, Color("#8c8479") * mod_col)


static func draw_migration_expedition(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.14))
	var steps := 16
	for i in range(1, steps):
		var pt := sample_road_curve(p_a, p_b, float(i) / float(steps), -1.0, curve_f)
		ci.draw_circle(pt, 4.2, Color("#0369a1"))
		ci.draw_circle(pt, 2.6, Color("#bae6fd") if i % 2 == 0 else Color("#e0f2fe"))


static func draw_pact_highway(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	var segments := 22
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))
	ci.draw_polyline(pts, Color(0.06, 0.73, 0.51, 0.32), 18.0)
	ci.draw_polyline(pts, Color("#f59e0b"), 13.5)
	ci.draw_polyline(pts, Color("#475569"), 10.5)
	ci.draw_polyline(pts, Color("#cbd5e1"), 7.2)


static func draw_merge_avenue(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	var segments := 20
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))
	ci.draw_polyline(pts, Color(0.98, 0.75, 0.14, 0.36), 18.0)
	ci.draw_polyline(pts, Color("#10b981"), 13.5)
	ci.draw_polyline(pts, Color("#fbbf24"), 9.5)
	ci.draw_polyline(pts, Color("#fef3c7"), 6.0)


static func draw_tribute_route(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.045))
	var segments := 20
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))
	ci.draw_polyline(pts, Color("#78350f"), 13.0)
	ci.draw_polyline(pts, Color("#d97706"), 9.5)
	ci.draw_polyline(pts, Color("#fbbf24"), 6.0)


static func draw_war_corridor(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var mid: Vector2 = road.get("edge_mid", (p_a + p_b) * 0.5)
	ci.draw_line(p_a, p_b, Color(0.50, 0.07, 0.07, 0.38), 16.0)
	ci.draw_line(p_a, p_b, Color("#2a0a0a"), 12.0)
	ci.draw_line(p_a, p_b, Color("#5c1919"), 8.0)
	ci.draw_line(p_a, p_b, Color("#991b1b"), 4.2)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, 18.0, 10.5, Color(0.18, 0.04, 0.04, 0.72))


static func draw_war_animated_invasion(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid: Vector2 = road.get("edge_mid", (p_a + p_b) * 0.5)

	var pulse := 0.55 + 0.45 * sin(anim_time * 7.5)
	anim_layer.draw_line(p_a, p_b, Color(0.94, 0.27, 0.27, 0.52 * pulse), 4.0)
	for c_i in range(3):
		var t_chev := fposmod(anim_time * 0.55 + float(c_i) * 0.33, 1.0)
		var c_pos := p_a.lerp(p_b, lerpf(0.15, 0.85, t_chev))
		var tip := c_pos + dir * 6.0
		anim_layer.draw_line(c_pos - dir * 5.0 + perp * 6.0, tip, Color("#fca5a5"), 2.4)
		anim_layer.draw_line(c_pos - dir * 5.0 - perp * 6.0, tip, Color("#fca5a5"), 2.4)

	var atk_col: Color = road.get("color", Color("#ef4444"))
	for w_i in range(3):
		var raw_w := fposmod(anim_time * 0.38 + float(w_i) * 0.28, 1.0)
		var w_pos := p_a.lerp(p_b, lerpf(0.14, 0.72, raw_w)) + perp * (float(w_i - 1) * 4.5)
		anim_layer.draw_circle(w_pos, 4.2, atk_col)
		var spear_tip := w_pos + dir * 10.0
		anim_layer.draw_line(w_pos, spear_tip, Color("#cbd5e1"), 2.0)
		anim_layer.draw_circle(spear_tip, 2.0, Color("#fde047"))
	draw_battle_sparks(r, mid)


static func draw_raid_trail(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var perp: Vector2 = road.get("edge_tangent", compute_edge_tangent(p_a, p_b))
	var steps := 12
	var prev_pt := p_a
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var jag := 0.0 if i == steps else (4.8 if i % 2 == 1 else -4.8)
		var next_pt := p_a.lerp(p_b, t) + perp * jag
		if i % 2 == 1:
			ci.draw_line(prev_pt, next_pt, Color("#431407"), 7.0)
			ci.draw_line(prev_pt, next_pt, Color("#ef4444"), 4.2)
		prev_pt = next_pt


static func draw_raid_animated_plunder(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	for r_i in range(2):
		var raw_r := fposmod(anim_time * 0.62 + float(r_i) * 0.48, 1.0)
		var r_pos := p_b.lerp(p_a, lerpf(0.14, 0.86, raw_r))
		anim_layer.draw_circle(r_pos, 4.5, Color("#f97316"))
		anim_layer.draw_circle(r_pos, 2.2, Color("#fde047"))


static func draw_betrayal_road(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var mid: Vector2 = road.get("edge_mid", (p_a + p_b) * 0.5)
	var stop_a := p_a.lerp(p_b, 0.36)
	var stop_b := p_b.lerp(p_a, 0.36)
	ci.draw_line(p_a, stop_a, Color("#334155"), 11.0)
	ci.draw_line(p_b, stop_b, Color("#334155"), 11.0)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, 18.0, 10.5, Color(0.18, 0.04, 0.22, 0.72))


static func draw_betrayal_animated_ruin(r: Node2D, road: Dictionary) -> void:
	var anim_layer: Node2D = r._anim_layer
	var anim_time: float = r._anim_time
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var mid: Vector2 = road.get("edge_mid", (p_a + p_b) * 0.5)
	for s_i in range(4):
		var phase := fposmod(anim_time * 0.45 + float(s_i) * 0.25, 1.0)
		var smoke_pos := mid + Vector2(sin(anim_time * 2.5 + float(s_i) * 1.7) * 9.0, -phase * 22.0)
		var smoke_col := Color(0.49, 0.13, 0.81, (1.0 - phase) * 0.65)
		anim_layer.draw_circle(smoke_pos, lerpf(3.0, 5.8, phase), smoke_col)
