class_name EvoRoadNetworkRenderer
extends RefCounted

const DISPUTE_FRONT_MIN_PROB: float = 0.30


static func _flow_priority(flow_type: String) -> int:
	match flow_type:
		"betrayal", "siege":
			return 90
		"war", "raid", "raid_repelled":
			return 80
		"union", "merge", "colonize", "migration":
			return 70
		"tribute":
			return 60
		"trade", "exchange", "aid", "cooperate":
			return 50
		"pact":
			return 40
		"dispute":
			return 30
		"rural_farm":
			return 20
	return 10


static func collect_roads(r: Node2D) -> Array[Dictionary]:
	var roads: Array[Dictionary] = []
	var handled_deme_pairs: Dictionary = {}
	var handled_hex_pairs: Dictionary = {}
	var handled_rural_cells: Dictionary = {}
	var badge_positions: Array[Vector2] = []
	var hex_traffic_counts: Dictionary = {}
	var state: EvoTypes.WorldState = r.world_state
	var v_positions := PackedVector2Array()
	var deme_village: Dictionary = {}
	var deme_road_stance: Dictionary = {}
	for v in r._villages:
		v_positions.append(v["pos"] as Vector2)
		var did: String = v["deme_id"]
		if not deme_village.has(did) or bool(v["is_capital"]):
			deme_village[did] = v
		if state.demes.has(did):
			var dom_arch: String = v["archetype"]
			deme_road_stance[did] = {
				"arch": dom_arch,
				"conflict": dom_arch in ["dispute", "raid", "war", "betrayal", "overexploit"],
				"coop": dom_arch in ["cooperate", "exchange", "pact"]
			}
	r.set_meta("_v_pos_cache", v_positions)
	r.set_meta("_deme_v_cache", deme_village)
	r.set_meta("_deme_stance_cache", deme_road_stance)

	var sorted_flows: Array[EvoTypes.HexEdgeFlow] = state.active_flows.duplicate()
	sorted_flows.sort_custom(func(a: EvoTypes.HexEdgeFlow, b: EvoTypes.HexEdgeFlow) -> bool:
		return _flow_priority(a.flow_type) > _flow_priority(b.flow_type)
	)

	for flow in sorted_flows:
		if not state.cells.has(flow.from_hex_id) or not state.cells.has(flow.to_hex_id):
			continue
		if flow.from_hex_id == flow.to_hex_id:
			continue
		var cell_a: EvoTypes.HexCell = state.cells[flow.from_hex_id]
		var cell_b: EvoTypes.HexCell = state.cells[flow.to_hex_id]
		var h_key := make_pair_key(flow.from_hex_id, flow.to_hex_id)
		if handled_hex_pairs.has(h_key):
			continue

		var endpoints := resolve_road_endpoints(r, cell_a, cell_b, flow.from_deme_id, flow.to_deme_id)
		var trim_a := 22.0 if (cell_a.deme_ids.is_empty() and cell_a.land_use in ["crops", "pasture"]) else get_cell_plaza_trim(cell_a)
		var trim_b := 22.0 if (cell_b.deme_ids.is_empty() and cell_b.land_use in ["crops", "pasture"]) else get_cell_plaza_trim(cell_b)
		var curve_f := 0.045
		var is_prio: bool = (
			cell_a.id == r.selected_hex_id
			or cell_b.id == r.selected_hex_id
			or cell_a.id == r.hovered_hex_id
			or cell_b.id == r.hovered_hex_id
		)

		var flow_color := Color("#eab308")
		if flow.from_deme_id != "" and deme_village.has(flow.from_deme_id):
			flow_color = deme_village[flow.from_deme_id]["strat_color"]
		elif flow.from_deme_id != "" and state.demes.has(flow.from_deme_id):
			flow_color = EvoPropFloraRenderer.resolve_deme_strategy_color(state, state.demes[flow.from_deme_id])
		elif not cell_a.deme_ids.is_empty() and deme_village.has(cell_a.deme_ids[0]):
			flow_color = deme_village[cell_a.deme_ids[0]]["strat_color"]
		elif not cell_a.deme_ids.is_empty() and state.demes.has(cell_a.deme_ids[0]):
			flow_color = EvoPropFloraRenderer.resolve_deme_strategy_color(state, state.demes[cell_a.deme_ids[0]])

		var effective_type := flow.flow_type
		var d_from_id := flow.from_deme_id if flow.from_deme_id != "" else (cell_a.deme_ids[0] if not cell_a.deme_ids.is_empty() else "")
		var d_to_id := flow.to_deme_id if flow.to_deme_id != "" else (cell_b.deme_ids[0] if not cell_b.deme_ids.is_empty() else "")
		if d_from_id != "" and d_to_id != "" and state.demes.has(d_from_id) and state.demes.has(d_to_id):
			var d1: EvoTypes.Deme = state.demes[d_from_id]
			var d2: EvoTypes.Deme = state.demes[d_to_id]
			if d1.id == d2.id and effective_type in ["exchange", "cooperate", "trade", "aid", "pact", "merge", "union"]:
				effective_type = "merge"
				curve_f = 0.0
		if effective_type in ["exchange", "cooperate", "trade", "aid"] and flow.from_deme_id != "" and flow.to_deme_id != "":
			if EvoTypes.is_pact_active(state, flow.from_deme_id, flow.to_deme_id):
				effective_type = "pact"

		var road: Dictionary = {
			"hex_a": cell_a.id,
			"hex_b": cell_b.id,
			"world_a": endpoints["world_a"],
			"z_a": endpoints["z_a"],
			"trim_a": trim_a,
			"world_b": endpoints["world_b"],
			"z_b": endpoints["z_b"],
			"trim_b": trim_b,
			"curve_factor": curve_f,
			"active_flow": true,
			"flow_type": flow.flow_type,
			"color": flow_color
		}

		var matched := true
		match effective_type:
			"war", "siege":
				road["kind"] = effective_type
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, true)
				road["badge_pos"] = b_pos
				road["show_traffic"] = true
			"raid", "raid_repelled":
				road["kind"] = "raid"
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, true)
				road["show_traffic"] = true
			"tribute":
				road["kind"] = "tribute"
				road["color"] = Color("#f59e0b")
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, true)
				road["show_traffic"] = claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, true)
			"merge", "union":
				road["kind"] = "merge"
				road["color"] = Color("#fbbf24")
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, true)
				road["show_traffic"] = claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, true)
			"betrayal":
				road["kind"] = "betrayal"
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, true)
				road["badge_pos"] = b_pos
				road["show_traffic"] = true
			"pact":
				road["kind"] = "pact"
				road["color"] = Color("#10b981")
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, true)
				road["show_traffic"] = claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, true)
			"dispute":
				road["kind"] = "dispute"
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, is_prio)
				road["badge_pos"] = b_pos
				road["show_traffic"] = false
			"exchange", "cooperate", "trade", "aid":
				var kind := "bridge" if should_use_bridge(r, cell_a, cell_b) else "collab"
				road["kind"] = kind
				road["color"] = Color("#eab308") if effective_type in ["exchange", "trade"] else flow_color
				project_road_entry(r, road, true)
				var b_pos := sample_road_path(road, 0.5, 1.0)
				road["show_badge"] = register_road_badge(r, b_pos, badge_positions, is_prio)
				road["show_traffic"] = claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, is_prio)
			"migration", "colonize":
				road["kind"] = "expedition"
				project_road_entry(r, road, true)
				road["show_badge"] = false
				road["show_traffic"] = true
			"rural_farm":
				road["kind"] = "rural_farm"
				road["curve_factor"] = 0.035
				project_road_entry(r, road, true)
				road["show_badge"] = false
				road["show_traffic"] = claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, is_prio)
				if cell_a.deme_ids.is_empty():
					handled_rural_cells[cell_a.id] = true
				if cell_b.deme_ids.is_empty():
					handled_rural_cells[cell_b.id] = true
			_:
				matched = false

		if matched:
			handled_hex_pairs[h_key] = true
			if flow.from_deme_id != "" and flow.to_deme_id != "" and flow.from_deme_id != flow.to_deme_id:
				handled_deme_pairs[make_pair_key(flow.from_deme_id, flow.to_deme_id)] = true
			roads.append(road)

	var all_demes: Array[EvoTypes.Deme] = []
	for d_id in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[d_id]
		if d.population > 0 and state.cells.has(d.hex_id):
			all_demes.append(d)

	for d in all_demes:
		var strat_col := EvoPropFloraRenderer.resolve_deme_strategy_color(state, d)
		for u_hid in d.urban_hex_ids:
			if not state.cells.has(u_hid):
				continue
			var ca: EvoTypes.HexCell = state.cells[u_hid]
			var world_a := HexMath.axial_to_world(ca.q, ca.r)
			var z_a: float = r._get_cell_top_z(ca)
			var trim_a := get_cell_plaza_trim(ca)
			for dir_idx in range(6):
				var n_id: String = r._neighbor_id(ca, dir_idx)
				if not state.cells.has(n_id):
					continue
				var cb: EvoTypes.HexCell = state.cells[n_id]
				if cb.deme_ids.is_empty() and cb.owner_deme_id == d.id and (cb.land_use in ["crops", "pasture"]):
					var h_key := make_pair_key(ca.id, cb.id)
					if not handled_hex_pairs.has(h_key) and not handled_rural_cells.has(cb.id):
						handled_hex_pairs[h_key] = true
						handled_rural_cells[cb.id] = true
						var world_b := HexMath.axial_to_world(cb.q, cb.r)
						var z_b: float = r._get_cell_top_z(cb)
						var rural_road: Dictionary = {
							"kind": "rural_farm",
							"hex_a": ca.id,
							"hex_b": cb.id,
							"world_a": world_a,
							"z_a": z_a,
							"trim_a": trim_a,
							"world_b": world_b,
							"z_b": z_b,
							"trim_b": 22.0,
							"curve_factor": 0.035,
							"show_badge": false,
							"show_traffic": false,
							"active_flow": false,
							"flow_type": "",
							"color": strat_col
						}
						project_road_entry(r, rural_road, true)
						roads.append(rural_road)

	for d in all_demes:
		for u_hid in d.urban_hex_ids:
			if not state.cells.has(u_hid):
				continue
			var ca: EvoTypes.HexCell = state.cells[u_hid]
			for dir_idx in range(6):
				var n_id: String = r._neighbor_id(ca, dir_idx)
				if not state.cells.has(n_id):
					continue
				var cb: EvoTypes.HexCell = state.cells[n_id]
				if cb.deme_ids.is_empty():
					continue
				var h_key := make_pair_key(ca.id, cb.id)
				if handled_hex_pairs.has(h_key):
					continue

				var pair := find_closest_deme_pair(r, ca, cb)
				if pair.is_empty():
					continue
				var da: EvoTypes.Deme = pair["da"]
				var db: EvoTypes.Deme = pair["db"]
				var world_a: Vector2 = pair["wa"]
				var z_a: float = r._get_cell_top_z(ca)
				var trim_a := get_cell_plaza_trim(ca)
				var world_b: Vector2 = pair["wb"]
				var z_b: float = r._get_cell_top_z(cb)
				var trim_b := get_cell_plaza_trim(cb)

				if da.id == db.id:
					handled_hex_pairs[h_key] = true
					var merge_road: Dictionary = {
						"kind": "merge",
						"hex_a": ca.id,
						"hex_b": cb.id,
						"world_a": world_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": world_b,
						"z_b": z_b,
						"trim_b": trim_b,
						"curve_factor": 0.0,
						"show_traffic": false,
						"active_flow": false,
						"flow_type": "",
						"color": Color("#fbbf24")
					}
					project_road_entry(r, merge_road, true)
					merge_road["show_badge"] = register_road_badge(r, sample_road_path(merge_road, 0.5, 1.0), badge_positions, true)
					roads.append(merge_road)
					continue

				var d_pair_key := make_pair_key(da.id, db.id)
				if handled_deme_pairs.has(d_pair_key):
					continue
				handled_hex_pairs[h_key] = true
				handled_deme_pairs[d_pair_key] = true

				var is_prio: bool = (
					ca.id == r.selected_hex_id
					or cb.id == r.selected_hex_id
					or ca.id == r.hovered_hex_id
					or cb.id == r.hovered_hex_id
				)

				match classify_village_pair_relation(r, da, db):
					"pact":
						var pact_road: Dictionary = {
							"kind": "pact",
							"hex_a": ca.id,
							"hex_b": cb.id,
							"world_a": world_a,
							"z_a": z_a,
							"trim_a": trim_a,
							"world_b": world_b,
							"z_b": z_b,
							"trim_b": trim_b,
							"curve_factor": 0.045,
							"show_traffic": false,
							"active_flow": false,
							"flow_type": "",
							"color": Color("#10b981")
						}
						project_road_entry(r, pact_road, true)
						pact_road["show_badge"] = register_road_badge(r, sample_road_path(pact_road, 0.5, 1.0), badge_positions, true)
						roads.append(pact_road)
					"dispute_front":
						var disp_road: Dictionary = {
							"kind": "dispute",
							"hex_a": ca.id,
							"hex_b": cb.id,
							"world_a": world_a,
							"z_a": z_a,
							"trim_a": trim_a,
							"world_b": world_b,
							"z_b": z_b,
							"trim_b": trim_b,
							"show_traffic": false,
							"active_flow": false,
							"flow_type": ""
						}
						project_road_entry(r, disp_road, true)
						var b_pos := sample_road_path(disp_road, 0.5, 1.0)
						disp_road["show_badge"] = register_road_badge(r, b_pos, badge_positions, is_prio)
						disp_road["badge_pos"] = b_pos
						roads.append(disp_road)
					"active_road":
						var kind := "bridge" if should_use_bridge(r, ca, cb) else "collab"
						var col_road: Dictionary = {
							"kind": kind,
							"hex_a": ca.id,
							"hex_b": cb.id,
							"world_a": world_a,
							"z_a": z_a,
							"trim_a": trim_a,
							"world_b": world_b,
							"z_b": z_b,
							"trim_b": trim_b,
							"curve_factor": 0.045,
							"show_traffic": false,
							"active_flow": false,
							"flow_type": "",
							"color": Color(da.color)
						}
						project_road_entry(r, col_road, true)
						col_road["show_badge"] = register_road_badge(r, sample_road_path(col_road, 0.5, 1.0), badge_positions, is_prio)
						roads.append(col_road)
					_:
						var dis_age := get_disused_road_age(r, da.id, db.id, ca.id, cb.id)
						if dis_age > 0:
							var brk_road: Dictionary = {
								"kind": "broken",
								"hex_a": ca.id,
								"hex_b": cb.id,
								"world_a": world_a,
								"z_a": z_a,
								"trim_a": trim_a,
								"world_b": world_b,
								"z_b": z_b,
								"trim_b": trim_b,
								"show_traffic": false,
								"active_flow": false,
								"flow_type": "",
								"alpha": 0.52 if dis_age == 2 else 0.90
							}
							project_road_entry(r, brk_road, true)
							brk_road["show_badge"] = register_road_badge(r, sample_road_path(brk_road, 0.5, 1.0), badge_positions, is_prio)
							roads.append(brk_road)

	for disused in state.disused_connections:
		var age_val := int(disused.get("age", 1))
		if age_val > 2:
			continue
		var from_id := str(disused.get("from_hex_id", ""))
		var to_id := str(disused.get("to_hex_id", ""))
		if not state.cells.has(from_id) or not state.cells.has(to_id) or from_id == to_id:
			continue
		var ca: EvoTypes.HexCell = state.cells[from_id]
		var cb: EvoTypes.HexCell = state.cells[to_id]
		if HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r) > 1:
			continue
		var h_key := make_pair_key(from_id, to_id)
		var fa := str(disused.get("from_deme_id", ""))
		var fb := str(disused.get("to_deme_id", ""))
		var d_key := make_pair_key(fa, fb) if (fa != "" and fb != "") else ""
		if handled_hex_pairs.has(h_key):
			continue
		if d_key != "" and handled_deme_pairs.has(d_key):
			continue
		handled_hex_pairs[h_key] = true
		if d_key != "":
			handled_deme_pairs[d_key] = true

		var endpoints := resolve_road_endpoints(r, ca, cb, fa, fb)
		var trim_a := get_cell_plaza_trim(ca)
		var trim_b := get_cell_plaza_trim(cb)
		var is_prio: bool = (
			from_id == r.selected_hex_id
			or to_id == r.selected_hex_id
			or from_id == r.hovered_hex_id
			or to_id == r.hovered_hex_id
		)
		var dis_road: Dictionary = {
			"kind": "broken",
			"hex_a": ca.id,
			"hex_b": cb.id,
			"world_a": endpoints["world_a"],
			"z_a": endpoints["z_a"],
			"trim_a": trim_a,
			"world_b": endpoints["world_b"],
			"z_b": endpoints["z_b"],
			"trim_b": trim_b,
			"show_traffic": false,
			"active_flow": false,
			"flow_type": "",
			"alpha": 0.52 if age_val == 2 else 0.90
		}
		project_road_entry(r, dis_road, true)
		dis_road["show_badge"] = register_road_badge(r, sample_road_path(dis_road, 0.5, 1.0), badge_positions, is_prio)
		roads.append(dis_road)

	return prune_redundant_triangle_chords(r, roads)


static func prune_redundant_triangle_chords(r: Node2D, roads: Array[Dictionary]) -> Array[Dictionary]:
	var state: EvoTypes.WorldState = r.world_state
	var coop_pairs: Dictionary = {}
	for rd in roads:
		var k := str(rd.get("kind", ""))
		if k in ["collab", "bridge"]:
			var ha := str(rd.get("hex_a", ""))
			var hb := str(rd.get("hex_b", ""))
			if ha != "" and hb != "":
				coop_pairs[make_pair_key(ha, hb)] = true

	var result: Array[Dictionary] = []
	for rd in roads:
		var k := str(rd.get("kind", ""))
		if k in ["collab", "bridge"] and not bool(rd.get("active_flow", false)):
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
		if rd.has("color"):
			rd["villager_textures"] = EvoPropFloraRenderer.get_villager_textures_for_color(r, rd["color"])
		project_road_entry(r, rd, false)
		result.append(rd)
	return result


static func project_road_entry(r: Node2D, road: Dictionary, force_reproject: bool = true) -> void:
	if force_reproject or not road.has("p_a"):
		var world_a: Vector2 = road["world_a"]
		var z_a := float(road["z_a"])
		var trim_a := float(road["trim_a"])
		var world_b: Vector2 = road["world_b"]
		var z_b := float(road["z_b"])
		var trim_b := float(road["trim_b"])
		var kind := str(road.get("kind", ""))
		var w_diff := world_b - world_a
		var w_len := w_diff.length()

		if absf(z_a - z_b) > 2.0 and kind != "bridge" and w_len > 24.0:
			var w_dir := w_diff / w_len
			var mid_w := (world_a + world_b) * 0.5
			var p_a_center: Vector2 = r._project(world_a, z_a)
			var p_rim_a: Vector2 = r._project(mid_w - w_dir * 6.0, z_a)
			var p_rim_b: Vector2 = r._project(mid_w + w_dir * 6.0, z_b)
			var p_b_center: Vector2 = r._project(world_b, z_b)

			var seg_a := p_rim_a - p_a_center
			var len_a := seg_a.length()
			var p_a: Vector2 = p_a_center + (seg_a / len_a) * minf(trim_a, len_a * 0.65) if len_a > 1.0 else p_a_center

			var seg_b := p_b_center - p_rim_b
			var len_b := seg_b.length()
			var p_b: Vector2 = p_b_center - (seg_b / len_b) * minf(trim_b, len_b * 0.65) if len_b > 1.0 else p_b_center

			road["p_a"] = p_a
			road["p_b"] = p_b
			road["points"] = PackedVector2Array([p_a, p_rim_a, p_rim_b, p_b])
		else:
			var raw_a: Vector2 = r._project(world_a, z_a)
			var raw_b: Vector2 = r._project(world_b, z_b)
			var trimmed := trim_road_segment(raw_a, raw_b, trim_a, trim_b)
			road["p_a"] = trimmed["p_a"]
			road["p_b"] = trimmed["p_b"]
			road.erase("points")

	if force_reproject and road.get("kind", "") in ["dispute", "war", "siege", "betrayal"]:
		road["badge_pos"] = sample_road_path(road, 0.5, 1.0)


static func reproject_roads(r: Node2D) -> void:
	for road in r._roads:
		project_road_entry(r, road, true)


static func draw_network_roads(r: Node2D) -> void:
	EvoRoadWallDrawer.draw_network_roads(r)


static func draw_animated_roads(r: Node2D) -> void:
	EvoRoadWallDrawer.draw_animated_roads(r)


static func draw_settlement_perimeter_walls(r: Node2D) -> void:
	EvoRoadWallDrawer.draw_settlement_perimeter_walls(r)


static func draw_settlement_back_walls(r: Node2D) -> void:
	EvoRoadWallDrawer.draw_settlement_back_walls(r)


static func draw_settlement_front_walls(r: Node2D, target_layer: Node2D) -> void:
	EvoRoadWallDrawer.draw_settlement_front_walls(r, target_layer)


static func sample_road_path(road: Dictionary, t: float, curve_sign: float = 1.0) -> Vector2:
	return EvoRoadWallDrawer.sample_road_path(road, t, curve_sign)


static func sample_road_curve(
	p_a: Vector2,
	p_b: Vector2,
	t: float,
	curve_sign: float,
	curve_factor: float = 0.045
) -> Vector2:
	return EvoRoadWallDrawer.sample_road_curve(p_a, p_b, t, curve_sign, curve_factor)


static func bridge_arch_point(p_a: Vector2, p_b: Vector2, t: float) -> Vector2:
	return EvoRoadWallDrawer.bridge_arch_point(p_a, p_b, t)


static func make_pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


static func get_cell_plaza_trim(cell: EvoTypes.HexCell) -> float:
	if cell.deme_ids.is_empty():
		return 16.0
	return 48.0


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
	)


static func classify_village_pair_relation(r: Node2D, da: EvoTypes.Deme, db: EvoTypes.Deme) -> String:
	if EvoTypes.is_pact_active(r.world_state, da.id, db.id):
		return "pact"
	if EvoTypes.is_vendetta_active(r.world_state, da.id, db.id):
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


static func get_deme_world_pos(cell: EvoTypes.HexCell, _deme_id: String = "") -> Vector2:
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
	_from_deme_id: String = "",
	_to_deme_id: String = ""
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


static func get_flow_endpoint_world(cell: EvoTypes.HexCell, _deme_id: String = "", _fallback_idx: int = 0) -> Vector2:
	return HexMath.axial_to_world(cell.q, cell.r)
