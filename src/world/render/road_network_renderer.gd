class_name EvoRoadNetworkRenderer
extends RefCounted


static func collect_roads(r: Node2D) -> Array[Dictionary]:
	var roads: Array[Dictionary] = []
	var handled_deme_pairs: Dictionary = {}
	var handled_hex_pairs: Dictionary = {}
	var intra_hex_badge_drawn: Dictionary = {}
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

	for flow in state.active_flows:
		if not state.cells.has(flow.from_hex_id) or not state.cells.has(flow.to_hex_id):
			continue
		var cell_a: EvoTypes.HexCell = state.cells[flow.from_hex_id]
		var cell_b: EvoTypes.HexCell = state.cells[flow.to_hex_id]
		var is_same_hex := cell_a.id == cell_b.id
		var h_key := make_pair_key(flow.from_hex_id, flow.to_hex_id)
		if not is_same_hex and handled_hex_pairs.has(h_key):
			continue
		if is_same_hex and flow.from_deme_id != "" and flow.to_deme_id != "" and handled_deme_pairs.has(make_pair_key(flow.from_deme_id, flow.to_deme_id)):
			continue

		var endpoints := resolve_road_endpoints(r, cell_a, cell_b, flow.from_deme_id, flow.to_deme_id)
		var trim_a := get_cell_plaza_trim(cell_a)
		var trim_b := get_cell_plaza_trim(cell_b)
		var trimmed := trim_road_segment(
			endpoints["p_a"] as Vector2,
			endpoints["p_b"] as Vector2,
			trim_a,
			trim_b
		)
		var p_a: Vector2 = trimmed["p_a"]
		var p_b: Vector2 = trimmed["p_b"]
		var curve_f := 0.035 if is_same_hex else 0.045
		var is_prio: bool = (
			cell_a.id == r.selected_hex_id
			or cell_b.id == r.selected_hex_id
			or cell_a.id == r.hovered_hex_id
			or cell_b.id == r.hovered_hex_id
		)

		if not is_same_hex:
			handled_hex_pairs[h_key] = true
		if flow.from_deme_id != "" and flow.to_deme_id != "":
			handled_deme_pairs[make_pair_key(flow.from_deme_id, flow.to_deme_id)] = true

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
		if effective_type in ["exchange", "cooperate"] and flow.from_deme_id != "" and flow.to_deme_id != "":
			if EvoTypes.is_pact_active(state, flow.from_deme_id, flow.to_deme_id):
				effective_type = "pact"

		match effective_type:
			"war":
				var b_pos: Vector2 = r._cell_top_center(cell_a) if is_same_hex else (p_a + p_b) * 0.5
				var show_badge := register_road_badge(r, b_pos, badge_positions, true)
				roads.append({
					"kind": "war",
					"hex_a": cell_a.id,
					"hex_b": cell_b.id,
					"world_a": endpoints["world_a"],
					"z_a": endpoints["z_a"],
					"trim_a": trim_a,
					"world_b": endpoints["world_b"],
					"z_b": endpoints["z_b"],
					"trim_b": trim_b,
					"badge_world": HexMath.axial_to_world(cell_a.q, cell_a.r),
					"badge_z": r._get_cell_top_z(cell_a),
					"p_a": p_a,
					"p_b": p_b,
					"is_same_hex": is_same_hex,
					"curve_factor": curve_f,
					"show_badge": show_badge,
					"show_traffic": true,
					"badge_pos": b_pos,
					"color": flow_color
				})
			"raid":
				var b_pos: Vector2 = r._cell_top_center(cell_a) if is_same_hex else (p_a + p_b) * 0.5
				var show_badge := register_road_badge(r, b_pos, badge_positions, true)
				roads.append({
					"kind": "raid",
					"hex_a": cell_a.id,
					"hex_b": cell_b.id,
					"world_a": endpoints["world_a"],
					"z_a": endpoints["z_a"],
					"trim_a": trim_a,
					"world_b": endpoints["world_b"],
					"z_b": endpoints["z_b"],
					"trim_b": trim_b,
					"badge_world": HexMath.axial_to_world(cell_a.q, cell_a.r),
					"badge_z": r._get_cell_top_z(cell_a),
					"p_a": p_a,
					"p_b": p_b,
					"is_same_hex": is_same_hex,
					"curve_factor": curve_f,
					"show_badge": show_badge,
					"show_traffic": true,
					"badge_pos": b_pos,
					"color": flow_color
				})
			"betrayal":
				var b_pos: Vector2 = r._cell_top_center(cell_a) if is_same_hex else (p_a + p_b) * 0.5
				var show_badge := register_road_badge(r, b_pos, badge_positions, true)
				roads.append({
					"kind": "betrayal",
					"hex_a": cell_a.id,
					"hex_b": cell_b.id,
					"world_a": endpoints["world_a"],
					"z_a": endpoints["z_a"],
					"trim_a": trim_a,
					"world_b": endpoints["world_b"],
					"z_b": endpoints["z_b"],
					"trim_b": trim_b,
					"badge_world": HexMath.axial_to_world(cell_a.q, cell_a.r),
					"badge_z": r._get_cell_top_z(cell_a),
					"p_a": p_a,
					"p_b": p_b,
					"is_same_hex": is_same_hex,
					"curve_factor": curve_f,
					"show_badge": show_badge,
					"badge_pos": b_pos
				})
			"pact":
				var b_pos := sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f)
				var show_badge := register_road_badge(r, b_pos, badge_positions, true)
				var show_traffic := claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, true)
				roads.append({
					"kind": "pact",
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
					"is_same_hex": is_same_hex,
					"curve_factor": curve_f,
					"show_badge": show_badge,
					"show_traffic": show_traffic,
					"badge_pos": b_pos,
					"color": Color("#10b981")
				})
			"dispute":
				var b_pos: Vector2 = r._cell_top_center(cell_a) if is_same_hex else (p_a + p_b) * 0.5
				var show_badge := true
				if is_same_hex:
					show_badge = not intra_hex_badge_drawn.has(cell_a.id)
					intra_hex_badge_drawn[cell_a.id] = true
				if show_badge:
					show_badge = register_road_badge(r, b_pos, badge_positions, is_prio)
				roads.append({
					"kind": "dispute",
					"hex_a": cell_a.id,
					"hex_b": cell_b.id,
					"world_a": endpoints["world_a"],
					"z_a": endpoints["z_a"],
					"trim_a": trim_a,
					"world_b": endpoints["world_b"],
					"z_b": endpoints["z_b"],
					"trim_b": trim_b,
					"badge_world": HexMath.axial_to_world(cell_a.q, cell_a.r),
					"badge_z": r._get_cell_top_z(cell_a),
					"p_a": p_a,
					"p_b": p_b,
					"is_same_hex": is_same_hex,
					"show_badge": show_badge,
					"badge_pos": b_pos
				})
			"exchange", "cooperate", "merge":
				var kind := "bridge" if (not is_same_hex and should_use_bridge(r, cell_a, cell_b)) else "collab"
				var b_pos := bridge_arch_point(p_a, p_b, 0.5) if kind == "bridge" else sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f)
				var show_badge := register_road_badge(r, b_pos, badge_positions, is_prio)
				var show_traffic := claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, is_prio)
				roads.append({
					"kind": kind,
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
					"is_same_hex": is_same_hex,
					"curve_factor": curve_f,
					"show_badge": show_badge,
					"show_traffic": show_traffic,
					"color": Color("#eab308")
				})
			"migration":
				roads.append({
					"kind": "expedition",
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
					"curve_factor": curve_f
				})

	var all_demes: Array[EvoTypes.Deme] = []
	for d_id in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[d_id]
		if d.population > 0 and state.cells.has(d.hex_id):
			all_demes.append(d)

	var connected_deme_ids: Dictionary = {}
	for d in all_demes:
		var ca: EvoTypes.HexCell = state.cells[d.hex_id]
		if ca.deme_ids.size() > 1:
			connected_deme_ids[d.id] = true
			continue
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, state.cells):
			if not (state.cells[n_id] as EvoTypes.HexCell).deme_ids.is_empty():
				connected_deme_ids[d.id] = true
				break

	for hex_id in state.cells:
		var ca: EvoTypes.HexCell = state.cells[hex_id]
		if ca.deme_ids.size() < 2:
			continue
		var z_ca: float = r._get_cell_top_z(ca)
		var world_ca := HexMath.axial_to_world(ca.q, ca.r)
		for i in range(ca.deme_ids.size()):
			var id_a: String = ca.deme_ids[i]
			if not state.demes.has(id_a):
				continue
			var da: EvoTypes.Deme = state.demes[id_a]
			for j in range(i + 1, ca.deme_ids.size()):
				var id_b: String = ca.deme_ids[j]
				if not state.demes.has(id_b):
					continue
				var db: EvoTypes.Deme = state.demes[id_b]
				var d_key := make_pair_key(da.id, db.id)
				if handled_deme_pairs.has(d_key):
					continue
				handled_deme_pairs[d_key] = true

				var trim_r := get_cell_plaza_trim(ca)
				var world_a := get_deme_world_pos(ca, da.id)
				var world_b := get_deme_world_pos(ca, db.id)
				var trimmed := trim_road_segment(r._project(world_a, z_ca), r._project(world_b, z_ca), trim_r, trim_r)
				var p_a: Vector2 = trimmed["p_a"]
				var p_b: Vector2 = trimmed["p_b"]
				var is_prio: bool = (ca.id == r.selected_hex_id or ca.id == r.hovered_hex_id)

				match classify_village_pair_relation(r, da, db):
					"pact":
						var b_pos := sample_road_curve(p_a, p_b, 0.5, 1.0, 0.035)
						var show_badge := register_road_badge(r, b_pos, badge_positions, true)
						var show_traffic := claim_road_traffic(ca.id, ca.id, hex_traffic_counts, true)
						roads.append({
							"kind": "pact",
							"hex_a": ca.id,
							"hex_b": ca.id,
							"world_a": world_a,
							"z_a": z_ca,
							"trim_a": trim_r,
							"world_b": world_b,
							"z_b": z_ca,
							"trim_b": trim_r,
							"p_a": p_a,
							"p_b": p_b,
							"is_same_hex": true,
							"curve_factor": 0.035,
							"show_badge": show_badge,
							"show_traffic": show_traffic,
							"badge_pos": b_pos,
							"color": Color("#10b981")
						})
					"dispute_front":
						var b_pos: Vector2 = r._cell_top_center(ca)
						var show_badge := not intra_hex_badge_drawn.has(ca.id)
						intra_hex_badge_drawn[ca.id] = true
						if show_badge:
							show_badge = register_road_badge(r, b_pos, badge_positions, is_prio)
						roads.append({
							"kind": "dispute",
							"world_a": world_a,
							"z_a": z_ca,
							"trim_a": trim_r,
							"world_b": world_b,
							"z_b": z_ca,
							"trim_b": trim_r,
							"badge_world": world_ca,
							"badge_z": z_ca,
							"p_a": p_a,
							"p_b": p_b,
							"is_same_hex": true,
							"show_badge": show_badge,
							"badge_pos": b_pos
						})
					"active_road":
						var b_pos := sample_road_curve(p_a, p_b, 0.5, 1.0, 0.035)
						var show_badge := register_road_badge(r, b_pos, badge_positions, is_prio)
						var show_traffic := claim_road_traffic(ca.id, ca.id, hex_traffic_counts, is_prio)
						roads.append({
							"kind": "collab",
							"hex_a": ca.id,
							"hex_b": ca.id,
							"world_a": world_a,
							"z_a": z_ca,
							"trim_a": trim_r,
							"world_b": world_b,
							"z_b": z_ca,
							"trim_b": trim_r,
							"p_a": p_a,
							"p_b": p_b,
							"is_same_hex": true,
							"curve_factor": 0.035,
							"show_badge": show_badge,
							"show_traffic": show_traffic,
							"color": Color(da.color)
						})
					_:
						var dis_age := get_disused_road_age(r, da.id, db.id, ca.id, ca.id)
						if dis_age > 0 or (state.generation == 0 and state.active_flows.is_empty()):
							var b_pos := (p_a + p_b) * 0.5
							var show_badge := register_road_badge(r, b_pos, badge_positions, is_prio)
							roads.append({
								"kind": "broken",
								"world_a": world_a,
								"z_a": z_ca,
								"trim_a": trim_r,
								"world_b": world_b,
								"z_b": z_ca,
								"trim_b": trim_r,
								"p_a": p_a,
								"p_b": p_b,
								"show_badge": show_badge,
								"alpha": 0.52 if dis_age == 2 else 0.90
							})

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
			var trimmed := trim_road_segment(
				r._project(world_a, z_a),
				r._project(world_b, z_b),
				trim_a,
				trim_b
			)
			var p_a: Vector2 = trimmed["p_a"]
			var p_b: Vector2 = trimmed["p_b"]
			var is_prio: bool = (
				ca.id == r.selected_hex_id
				or cb.id == r.selected_hex_id
				or ca.id == r.hovered_hex_id
				or cb.id == r.hovered_hex_id
			)

			match classify_village_pair_relation(r, da, db):
				"pact":
					var b_pos := sample_road_curve(p_a, p_b, 0.5, 1.0, 0.045)
					var show_badge := register_road_badge(r, b_pos, badge_positions, true)
					var show_traffic := claim_road_traffic(ca.id, cb.id, hex_traffic_counts, true)
					roads.append({
						"kind": "pact",
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
						"is_same_hex": false,
						"curve_factor": 0.045,
						"show_badge": show_badge,
						"show_traffic": show_traffic,
						"badge_pos": b_pos,
						"color": Color("#10b981")
					})
				"dispute_front":
					var b_pos := (p_a + p_b) * 0.5
					var show_badge := register_road_badge(r, b_pos, badge_positions, is_prio)
					roads.append({
						"kind": "dispute",
						"world_a": world_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": world_b,
						"z_b": z_b,
						"trim_b": trim_b,
						"p_a": p_a,
						"p_b": p_b,
						"is_same_hex": false,
						"show_badge": show_badge,
						"badge_pos": b_pos
					})
				"active_road":
					var kind := "bridge" if should_use_bridge(r, ca, cb) else "collab"
					var b_pos := bridge_arch_point(p_a, p_b, 0.5) if kind == "bridge" else sample_road_curve(p_a, p_b, 0.5, 1.0, 0.045)
					var show_badge := register_road_badge(r, b_pos, badge_positions, is_prio)
					var show_traffic := claim_road_traffic(ca.id, cb.id, hex_traffic_counts, is_prio)
					roads.append({
						"kind": kind,
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
						"is_same_hex": false,
						"curve_factor": 0.045,
						"show_badge": show_badge,
						"show_traffic": show_traffic,
						"color": Color(da.color)
					})
				_:
					var dis_age := get_disused_road_age(r, da.id, db.id, ca.id, cb.id)
					if dis_age > 0:
						var b_pos := (p_a + p_b) * 0.5
						var show_badge := register_road_badge(r, b_pos, badge_positions, is_prio)
						roads.append({
							"kind": "broken",
							"world_a": world_a,
							"z_a": z_a,
							"trim_a": trim_a,
							"world_b": world_b,
							"z_b": z_b,
							"trim_b": trim_b,
							"p_a": p_a,
							"p_b": p_b,
							"show_badge": show_badge,
							"alpha": 0.52 if dis_age == 2 else 0.90
						})

	if state.generation <= 2 and all_demes.size() == 2 and state.cells.has("0,0") and (state.cells["0,0"] as EvoTypes.HexCell).deme_ids.is_empty():
		var da: EvoTypes.Deme = all_demes[0]
		var db: EvoTypes.Deme = all_demes[1]
		if not connected_deme_ids.has(da.id) and not connected_deme_ids.has(db.id):
			var d_key := make_pair_key(da.id, db.id)
			if not handled_deme_pairs.has(d_key):
				handled_deme_pairs[d_key] = true
				var ca: EvoTypes.HexCell = state.cells[da.hex_id]
				var cb: EvoTypes.HexCell = state.cells[db.hex_id]
				var c_mid: EvoTypes.HexCell = state.cells["0,0"]
				var w_a := get_deme_world_pos(ca, da.id)
				var z_a: float = r._get_cell_top_z(ca)
				var trim_a := get_cell_plaza_trim(ca)
				var w_mid := HexMath.axial_to_world(c_mid.q, c_mid.r)
				var z_mid: float = r._get_cell_top_z(c_mid)
				var w_b := get_deme_world_pos(cb, db.id)
				var z_b: float = r._get_cell_top_z(cb)
				var trim_b := get_cell_plaza_trim(cb)
				var p_mid: Vector2 = r._project(w_mid, z_mid)
				var seg1 := trim_road_segment(r._project(w_a, z_a), p_mid, trim_a, 18.0)
				var seg2 := trim_road_segment(p_mid, r._project(w_b, z_b), 18.0, trim_b)
				var alpha_val := 0.90 if state.generation <= 1 else 0.55
				roads.append({
					"kind": "broken",
					"world_a": w_a,
					"z_a": z_a,
					"trim_a": trim_a,
					"world_b": w_mid,
					"z_b": z_mid,
					"trim_b": 18.0,
					"p_a": seg1["p_a"],
					"p_b": seg1["p_b"],
					"show_badge": true,
					"alpha": alpha_val
				})
				roads.append({
					"kind": "broken",
					"world_a": w_mid,
					"z_a": z_mid,
					"trim_a": 18.0,
					"world_b": w_b,
					"z_b": z_b,
					"trim_b": trim_b,
					"p_a": seg2["p_a"],
					"p_b": seg2["p_b"],
					"show_badge": true,
					"alpha": alpha_val
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
					roads.append({
						"kind": "expedition",
						"world_a": w_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": w_b,
						"z_b": z_b,
						"trim_b": 18.0,
						"p_a": seg["p_a"],
						"p_b": seg["p_b"],
						"curve_factor": 0.14
					})

	for disused in state.disused_connections:
		var age_val := int(disused.get("age", 1))
		if age_val > 2:
			continue
		var from_id := str(disused.get("from_hex_id", ""))
		var to_id := str(disused.get("to_hex_id", ""))
		if not state.cells.has(from_id) or not state.cells.has(to_id):
			continue
		var ca: EvoTypes.HexCell = state.cells[from_id]
		var cb: EvoTypes.HexCell = state.cells[to_id]
		if HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r) > 1:
			continue
		var is_same_hex := from_id == to_id
		var h_key := make_pair_key(from_id, to_id)
		var fa := str(disused.get("from_deme_id", ""))
		var fb := str(disused.get("to_deme_id", ""))
		var d_key := make_pair_key(fa, fb) if (fa != "" and fb != "") else ""
		if not is_same_hex and handled_hex_pairs.has(h_key):
			continue
		if d_key != "" and handled_deme_pairs.has(d_key):
			continue
		if not is_same_hex:
			handled_hex_pairs[h_key] = true
		if d_key != "":
			handled_deme_pairs[d_key] = true

		var endpoints := resolve_road_endpoints(r, ca, cb, fa, fb)
		var trim_a := get_cell_plaza_trim(ca)
		var trim_b := get_cell_plaza_trim(cb)
		var seg := trim_road_segment(
			endpoints["p_a"] as Vector2,
			endpoints["p_b"] as Vector2,
			trim_a,
			trim_b
		)
		var p_a: Vector2 = seg["p_a"]
		var p_b: Vector2 = seg["p_b"]
		var is_prio: bool = (
			from_id == r.selected_hex_id
			or to_id == r.selected_hex_id
			or from_id == r.hovered_hex_id
			or to_id == r.hovered_hex_id
		)
		var show_badge := register_road_badge(r, (p_a + p_b) * 0.5, badge_positions, is_prio)
		roads.append({
			"kind": "broken",
			"world_a": endpoints["world_a"],
			"z_a": endpoints["z_a"],
			"trim_a": trim_a,
			"world_b": endpoints["world_b"],
			"z_b": endpoints["z_b"],
			"trim_b": trim_b,
			"p_a": p_a,
			"p_b": p_b,
			"show_badge": show_badge,
			"alpha": 0.52 if age_val == 2 else 0.90
		})

	return prune_redundant_triangle_chords(r, roads)


static func prune_redundant_triangle_chords(r: Node2D, roads: Array[Dictionary]) -> Array[Dictionary]:
	var state: EvoTypes.WorldState = r.world_state
	var coop_pairs: Dictionary = {}
	for rd in roads:
		var k := str(rd.get("kind", ""))
		if k in ["collab", "bridge"] and not bool(rd.get("is_same_hex", false)):
			var ha := str(rd.get("hex_a", ""))
			var hb := str(rd.get("hex_b", ""))
			if ha != "" and hb != "":
				coop_pairs[make_pair_key(ha, hb)] = true

	var result: Array[Dictionary] = []
	for rd in roads:
		var k := str(rd.get("kind", ""))
		if k in ["collab", "bridge"] and not bool(rd.get("is_same_hex", false)):
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
	var curve_f := float(road.get("curve_factor", 0.045))
	var curve_sign := -1.0 if road.get("kind", "") == "expedition" else 1.0
	var diff := p_b - p_a
	var dist := diff.length()
	var perp := Vector2(-diff.y, diff.x).normalized() if dist > 0.01 else Vector2.UP
	road["ctrl"] = (p_a + p_b) * 0.5 + perp * (minf(dist * curve_f, 12.0) * curve_sign)
	if force_reproject and road.get("kind", "") in ["dispute", "war", "raid", "betrayal", "pact"]:
		if bool(road.get("is_same_hex", false)) and road.has("badge_world"):
			road["badge_pos"] = r._project(road["badge_world"] as Vector2, float(road["badge_z"]))
		else:
			road["badge_pos"] = (p_a + p_b) * 0.5


static func reproject_roads(r: Node2D) -> void:
	for road in r._roads:
		project_road_entry(r, road, true)


static func _draw_road_network(r: Node2D) -> void:
	draw_network_roads(r)


static func draw_network_roads(r: Node2D) -> void:
	for road in r._roads:
		match road["kind"]:
			"pact":
				draw_pact_highway(r, road)
			"war":
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
			"war":
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


static func make_pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


static func get_cell_plaza_trim(cell: EvoTypes.HexCell) -> float:
	var count := cell.deme_ids.size()
	if count <= 0:
		return 16.0
	var sf := 1.0 if count == 1 else (0.86 if count == 2 else 0.78)
	return 44.0 * sf


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
	else:
		for v in r._villages:
			if badge_pos.distance_squared_to(v["pos"] as Vector2) < min_v_dist_sq:
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


static func get_deme_world_pos(cell: EvoTypes.HexCell, deme_id: String) -> Vector2:
	var w_xy := HexMath.axial_to_world(cell.q, cell.r)
	var idx := cell.deme_ids.find(deme_id)
	if idx >= 0:
		w_xy += HexMath.compute_village_sector_offset(idx, cell.deme_ids.size(), HexMath.HEX_SIZE)
	return w_xy


static func find_closest_deme_pair(r: Node2D, cell_a: EvoTypes.HexCell, cell_b: EvoTypes.HexCell) -> Dictionary:
	var demes: Dictionary = r.world_state.demes
	var best_da: EvoTypes.Deme = null
	var best_db: EvoTypes.Deme = null
	var best_wa := Vector2.ZERO
	var best_wb := Vector2.ZERO
	var best_dist_sq := INF
	var pact_da: EvoTypes.Deme = null
	var pact_db: EvoTypes.Deme = null
	var pact_wa := Vector2.ZERO
	var pact_wb := Vector2.ZERO
	var pact_dist_sq := INF
	var count_a := cell_a.deme_ids.size()
	var count_b := cell_b.deme_ids.size()
	var w_ca := HexMath.axial_to_world(cell_a.q, cell_a.r)
	var w_cb := HexMath.axial_to_world(cell_b.q, cell_b.r)
	var wb_list := PackedVector2Array()
	wb_list.resize(count_b)
	for j in range(count_b):
		wb_list[j] = w_cb + HexMath.compute_village_sector_offset(j, count_b, HexMath.HEX_SIZE)
	var has_pacts: bool = not (r.world_state as EvoTypes.WorldState).active_pacts.is_empty()
	for i in range(count_a):
		var id_a: String = cell_a.deme_ids[i]
		if not demes.has(id_a):
			continue
		var da: EvoTypes.Deme = demes[id_a]
		var wa := w_ca + HexMath.compute_village_sector_offset(i, count_a, HexMath.HEX_SIZE)
		for j in range(count_b):
			var id_b: String = cell_b.deme_ids[j]
			if not demes.has(id_b):
				continue
			var db: EvoTypes.Deme = demes[id_b]
			var wb := wb_list[j]
			var d2 := wa.distance_squared_to(wb)
			if has_pacts and EvoTypes.is_pact_active(r.world_state, id_a, id_b) and d2 < pact_dist_sq:
				pact_dist_sq = d2
				pact_da = da
				pact_db = db
				pact_wa = wa
				pact_wb = wb
			if d2 < best_dist_sq:
				best_dist_sq = d2
				best_da = da
				best_db = db
				best_wa = wa
				best_wb = wb
	if pact_da != null and pact_db != null:
		return {"da": pact_da, "db": pact_db, "wa": pact_wa, "wb": pact_wb}
	if best_da == null or best_db == null:
		return {}
	return {"da": best_da, "db": best_db, "wa": best_wa, "wb": best_wb}


static func resolve_road_endpoints(
	r: Node2D,
	cell_a: EvoTypes.HexCell,
	cell_b: EvoTypes.HexCell,
	from_deme_id: String,
	to_deme_id: String
) -> Dictionary:
	if cell_a.id == cell_b.id and r.has_meta("_deme_v_cache"):
		var dv: Dictionary = r.get_meta("_deme_v_cache")
		if dv.has(from_deme_id) and dv.has(to_deme_id):
			var va: Dictionary = dv[from_deme_id]
			var vb: Dictionary = dv[to_deme_id]
			return {
				"world_a": va["world_xy"],
				"z_a": va["top_z"],
				"world_b": vb["world_xy"],
				"z_b": vb["top_z"],
				"p_a": va["pos"],
				"p_b": vb["pos"]
			}
	var world_a: Vector2
	var world_b: Vector2
	if cell_a.id != cell_b.id and not cell_a.deme_ids.is_empty() and not cell_b.deme_ids.is_empty():
		var closest := find_closest_deme_pair(r, cell_a, cell_b)
		if not closest.is_empty():
			world_a = closest["wa"]
			world_b = closest["wb"]
			if r.has_meta("_deme_v_cache"):
				var dv: Dictionary = r.get_meta("_deme_v_cache")
				var id_a := (closest["da"] as EvoTypes.Deme).id
				var id_b := (closest["db"] as EvoTypes.Deme).id
				if dv.has(id_a) and dv.has(id_b):
					var va: Dictionary = dv[id_a]
					var vb: Dictionary = dv[id_b]
					return {
						"world_a": world_a,
						"z_a": va["top_z"],
						"world_b": world_b,
						"z_b": vb["top_z"],
						"p_a": va["pos"],
						"p_b": vb["pos"]
					}
		else:
			world_a = get_flow_endpoint_world(cell_a, from_deme_id, 0)
			world_b = get_flow_endpoint_world(cell_b, to_deme_id, 1)
	else:
		world_a = get_flow_endpoint_world(cell_a, from_deme_id, 0)
		world_b = get_flow_endpoint_world(cell_b, to_deme_id, 1)
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


static func get_flow_endpoint_world(cell: EvoTypes.HexCell, deme_id: String, fallback_idx: int) -> Vector2:
	var w_xy := HexMath.axial_to_world(cell.q, cell.r)
	var idx := cell.deme_ids.find(deme_id)
	if idx == -1 and cell.deme_ids.size() > 0:
		idx = fallback_idx % cell.deme_ids.size()
	if idx >= 0:
		w_xy += HexMath.compute_village_sector_offset(idx, cell.deme_ids.size(), HexMath.HEX_SIZE)
	return w_xy


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
	var is_intra_hex := bool(road.get("is_same_hex", dist < 210.0))

	var stop_a := p_a.lerp(p_b, 0.34 if is_intra_hex else 0.38)
	var stop_b := p_b.lerp(p_a, 0.34 if is_intra_hex else 0.38)
	ci.draw_line(p_a, stop_a, Color("#3b2313"), 9.2 if is_intra_hex else 10.8)
	ci.draw_line(p_a, stop_a, Color("#785233"), 6.0 if is_intra_hex else 7.2)
	ci.draw_line(p_b, stop_b, Color("#3b2313"), 9.2 if is_intra_hex else 10.8)
	ci.draw_line(p_b, stop_b, Color("#785233"), 6.0 if is_intra_hex else 7.2)

	var scorch_rx := 15.0 if is_intra_hex else 22.0
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, scorch_rx, scorch_rx * 0.58, Color(0.16, 0.08, 0.05, 0.72))
	ci.draw_line(mid - perp * scorch_rx, mid + perp * scorch_rx, Color("#dc2626"), 2.8)

	if is_intra_hex:
		EvoWorldOverlayRenderer.draw_centered_sprite(ci, "barricade_spikes", mid + Vector2(0, 3.0), 1.35)
	else:
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

	# Subtle golden-emerald border glow & reinforced stone highway
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


static func draw_war_corridor(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := (p_a + p_b) * 0.5

	# Scorched dark-crimson dirt track
	ci.draw_line(p_a, p_b, Color(0.50, 0.07, 0.07, 0.42), 20.0)
	ci.draw_line(p_a, p_b, Color("#2a0a0a"), 14.8)
	ci.draw_line(p_a, p_b, Color("#5c1919"), 10.4)
	ci.draw_line(p_a, p_b, Color("#991b1b"), 5.6)

	var scorch_rx := 22.0
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, mid, scorch_rx, scorch_rx * 0.58, Color(0.18, 0.04, 0.04, 0.78))
	ci.draw_line(mid - perp * scorch_rx, mid + perp * scorch_rx, Color("#ef4444"), 3.0)

	# War banners planted near the border clash front
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

	# Pulsing red tactical vector
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

	# Column of marching warriors advancing from origin_hex (p_a) toward target_hex (p_b)
	var v_textures: Array = road.get("villager_textures", [])
	var atk_col: Color = road.get("color", Color("#ef4444"))
	for w_i in range(3):
		var raw_w := fposmod(anim_time * 0.38 + float(w_i) * 0.28, 1.0)
		var w_pos := p_a.lerp(p_b, lerpf(0.14, 0.72, raw_w)) + perp * (float(w_i - 1) * 4.5)
		if v_textures.size() >= 3:
			var frame := 1 + (int(anim_time * 7.0 + float(w_i)) % 2)
			var tex: ImageTexture = v_textures[frame]
			var sz := tex.get_size() * 2.45
			anim_layer.draw_texture_rect(tex, Rect2(w_pos - Vector2(sz.x * 0.5, sz.y * 0.85), sz), false)
		# Spear & shield accents on each marching warrior
		var spear_base := w_pos + Vector2(-4.0, -6.0)
		var spear_tip := spear_base + dir * 14.0 + Vector2(0, -10.0)
		anim_layer.draw_line(spear_base, spear_tip, Color("#cbd5e1"), 2.0)
		anim_layer.draw_circle(spear_tip, 2.2, Color("#fde047"))
		var shield_pos := w_pos + Vector2(5.0, -11.0)
		anim_layer.draw_circle(shield_pos, 4.5, Color("#cbd5e1"))
		anim_layer.draw_circle(shield_pos, 3.2, atk_col)

	# Clash front battle sparks & icon_war
	EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "effect_battle_sparks", mid + Vector2(0, 4.0), 1.15 + 0.20 * pulse)
	for s_i in range(5):
		var ang := anim_time * 6.0 + float(s_i) * (TAU * 0.20)
		var spark_pos := mid + Vector2(cos(ang) * 13.0, sin(ang) * 7.5 - 6.0)
		anim_layer.draw_circle(spark_pos, 3.2, Color("#fde047") if s_i % 2 == 0 else Color("#ef4444"))

	if bool(road.get("show_badge", true)):
		var badge_pos := mid + Vector2(0, -18.0)
		anim_layer.draw_circle(badge_pos, 14.5 * (0.92 + 0.16 * pulse), Color(0.94, 0.20, 0.20, 0.42))
		anim_layer.draw_circle(badge_pos, 10.5, Color("#7f1d1d"))
		EvoWorldOverlayRenderer.draw_centered_sprite(anim_layer, "icon_war", badge_pos + Vector2(0, 6.5), 1.35)


static func draw_raid_trail(r: Node2D, road: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var show_badge: bool = bool(road.get("show_badge", true))
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	# Fast, jagged amber-scarlet raiding trail with dashed stealth/plunder tracks
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

	# Fast-moving raider figures carrying prop_raid_loot back from target_hex (p_b) toward origin_hex (p_a)
	for r_i in range(2):
		var raw_r := fposmod(anim_time * 0.62 + float(r_i) * 0.48, 1.0)
		var r_pos := p_b.lerp(p_a, lerpf(0.14, 0.86, raw_r))
		if v_textures.size() >= 3:
			var frame := 1 + (int(anim_time * 9.0 + float(r_i)) % 2)
			var tex: ImageTexture = v_textures[frame]
			var sz := tex.get_size() * 2.45
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

	# Shattered alliance road stubs
	var stop_a := p_a.lerp(p_b, 0.36)
	var stop_b := p_b.lerp(p_a, 0.36)
	ci.draw_line(p_a, stop_a, Color("#334155"), 14.0)
	ci.draw_line(p_a, stop_a, Color("#94a3b8"), 9.2)
	ci.draw_line(p_b, stop_b, Color("#334155"), 14.0)
	ci.draw_line(p_b, stop_b, Color("#94a3b8"), 9.2)

	# Scorched dark violet/crimson crater & jagged fracture lines
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

	# Dark purple/charcoal smoke particles rising from shattered pact
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
