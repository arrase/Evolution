class_name EvoEnvPhase
extends RefCounted


static func _prune_stale_relations(state: EvoTypes.WorldState) -> void:
	if state.relations.is_empty():
		return
	var stale_keys: Array[String] = []
	for pk_var in state.relations.keys():
		var pk := str(pk_var)
		var parts := pk.split("__")
		if parts.size() != 2 or not state.demes.has(parts[0]) or not state.demes.has(parts[1]):
			stale_keys.append(pk)
	for pk in stale_keys:
		state.relations.erase(pk)


static func apply_cell_sea_level_transition(cell: EvoTypes.HexCell, sea_level: float) -> bool:
	if cell.altitude < sea_level and cell.biome != "ocean":
		EvoTurnEngine._apply_biome_climate_defaults(cell, "ocean", true)
		return true
	if cell.altitude >= sea_level and cell.biome == "ocean":
		var emerged_biome := "coastal_shallows"
		if cell.altitude >= 0.78:
			emerged_biome = "high_mountain"
		elif cell.altitude >= 0.55:
			emerged_biome = "arid_steppe"
		elif cell.altitude >= 0.25:
			emerged_biome = "savanna"
		EvoTurnEngine._apply_biome_climate_defaults(cell, emerged_biome, false)
		return true
	return false


static func step_cell_seasonal_climate(
	cell: EvoTypes.HexCell,
	delta_temp: float,
	delta_hum: float,
	gamma_season: float,
	suffered_collapse: bool
) -> void:
	cell.temperature = clampf(snappedf(cell.temperature + delta_temp, 0.01), -1.0, 1.0)
	cell.humidity = clampf(snappedf(cell.humidity + delta_hum, 0.01), 0.0, 1.0)
	var recovery_rate: float = 0.005 if suffered_collapse else 0.05
	var next_k := clampf(
		snappedf(cell.carrying_capacity + recovery_rate * (cell.carrying_capacity_max - cell.carrying_capacity), 0.01),
		10.0,
		cell.carrying_capacity_max
	)
	var next_r := minf(
		next_k,
		snappedf(cell.current_resources + next_k * cell.seasonal_regen_rate * gamma_season, 0.01)
	)
	cell.carrying_capacity = next_k
	cell.current_resources = next_r


static func run_environmental_phase(state: EvoTypes.WorldState, lang: String = "es") -> void:
	_prune_stale_relations(state)

	var prev_generation := state.generation
	var next_generation := state.generation + 1
	state.generation = next_generation
	state.season = "dry_cold" if state.season == "wet_warm" else "wet_warm"
	var gamma_season: float = 1.20 if state.season == "wet_warm" else 0.75

	var prev_exchange_conns: Array[Dictionary] = []
	var conn_idx_by_pair: Dictionary = {}
	for existing_conn in state.disused_connections:
		var next_age := int(existing_conn["age"]) + 1
		if next_age > 2:
			continue
		var c_copy := existing_conn.duplicate()
		c_copy["age"] = next_age
		var pk := EvoTypes.make_pair_key(str(c_copy["from_deme_id"]), str(c_copy["to_deme_id"]))
		conn_idx_by_pair[pk] = prev_exchange_conns.size()
		prev_exchange_conns.append(c_copy)
	for fl in state.active_flows:
		if fl.flow_type in ["exchange", "cooperate", "pact"]:
			var fa := fl.from_deme_id
			var fb := fl.to_deme_id
			var pk := EvoTypes.make_pair_key(fa, fb)
			if conn_idx_by_pair.has(pk):
				var conn: Dictionary = prev_exchange_conns[int(conn_idx_by_pair[pk])]
				conn["from_hex_id"] = fl.from_hex_id
				conn["to_hex_id"] = fl.to_hex_id
				conn["age"] = 0
				conn["broken_gen"] = next_generation
			else:
				conn_idx_by_pair[pk] = prev_exchange_conns.size()
				prev_exchange_conns.append({
					"from_hex_id": fl.from_hex_id,
					"to_hex_id": fl.to_hex_id,
					"from_deme_id": fa,
					"to_deme_id": fb,
					"age": 0,
					"broken_gen": next_generation
				})
	state.disused_connections = prev_exchange_conns
	state.active_flows.clear()
	state.turn_events.clear()
	state.recent_extinction_hexes.clear()

	if state.glacial_sea_level_cycle and next_generation % 8 == 0:
		state.sea_level = 0.12 if ((next_generation / 8) % 2 == 0) else 0.25

	var biome_changed_hexes: Dictionary = {}
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if apply_cell_sea_level_transition(cell, state.sea_level):
			biome_changed_hexes[cell.id] = true

	resolve_submerged_demes(state, lang)
	_prune_stale_relations(state)

	var delta_temp: float = 0.04 if state.season == "wet_warm" else -0.04
	var delta_hum: float = 0.05 if state.season == "wet_warm" else -0.05

	var collapsed_prev_gen_hexes: Dictionary = {}
	for i in range(state.chronicle.size() - 1, -1, -1):
		var entry := state.chronicle[i]
		if entry.generation < prev_generation:
			break
		if entry.event_type == "tragedy_of_commons" and entry.generation == prev_generation:
			collapsed_prev_gen_hexes[entry.hex_id] = true

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.biome == "ocean":
			cell.current_resources = 0.0
			continue
		if biome_changed_hexes.has(cell.id):
			continue

		step_cell_seasonal_climate(cell, delta_temp, delta_hum, gamma_season, collapsed_prev_gen_hexes.has(cell.id))

	state.selective_pressure_points += state.selective_pressure_regen_per_turn


static func resolve_submerged_demes(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var is_en := lang == "en"
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		var is_uninhabitable := cell.biome in ["ocean", "high_mountain"] or cell.altitude > 0.85
		if is_uninhabitable:
			cell.land_use = "wild"
			cell.owner_deme_id = ""
			cell.has_ruins = false
		if not is_uninhabitable or cell.deme_ids.is_empty():
			continue

		var resident_ids := cell.deme_ids.duplicate()
		cell.deme_ids.clear()

		for deme_id in resident_ids:
			if not state.demes.has(deme_id):
				continue
			var deme: EvoTypes.Deme = state.demes[deme_id]

			var candidates: Array[EvoTypes.HexCell] = []
			for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
				var ncell: EvoTypes.HexCell = state.cells[nid]
				if ncell.biome not in ["ocean", "high_mountain"] and ncell.altitude <= 0.85 and ncell.deme_ids.is_empty():
					candidates.append(ncell)

			candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				return a.current_resources > b.current_resources
			)

			if not candidates.is_empty():
				var target_cell := candidates[0]
				target_cell.owner_deme_id = ""
				target_cell.land_use = "wild"
				target_cell.has_ruins = false
				deme.hex_id = target_cell.id
				deme.energy_reserves = snappedf(deme.energy_reserves * 0.80, 0.01)
				target_cell.deme_ids.append(deme.id)

				for rcid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
					var rcell: EvoTypes.HexCell = state.cells[rcid]
					if rcell.owner_deme_id == deme.id and HexMath.hex_distance(rcell.q, rcell.r, target_cell.q, target_cell.r) != 1:
						rcell.owner_deme_id = ""
						rcell.land_use = "wild"

				var flow := EvoTypes.HexEdgeFlow.new()
				flow.from_hex_id = cell.id
				flow.to_hex_id = target_cell.id
				flow.flow_type = "migration"
				flow.intensity = 0.65
				flow.from_deme_id = deme.id
				flow.to_deme_id = deme.id
				state.active_flows.append(flow)
			else:
				EvoTypes.push_event(state, "extinction", cell.id, cell.id, deme.id, "", 0.0, deme.population)
				state.demes.erase(deme_id)
				cell.has_ruins = false
				for rcid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
					var rcell: EvoTypes.HexCell = state.cells[rcid]
					if rcell.owner_deme_id == deme_id:
						rcell.owner_deme_id = ""
						rcell.land_use = "wild"
				EvoTypes.erase_deme_relations(state, deme_id)
				if not state.recent_extinction_hexes.has(cell.id):
					state.recent_extinction_hexes.append(cell.id)

				var entry := EvoTypes.ChronicleEntry.new()
				entry.id = "chronicle-submerge-%d-%s" % [state.generation, deme.id]
				entry.generation = state.generation
				entry.event_type = "extinction"
				entry.title = ("%s Submerged" if is_en else "%s Sumergido") % deme.name
				entry.causal_explanation = (
					"%s went extinct when cell (%s) submerged into ocean with no accessible terrestrial refuge." % [deme.name, cell.id]
					if is_en
					else "%s se extinguió cuando la celda (%s) quedó sumergida en el océano sin refugio terrestre accesible." % [deme.name, cell.id]
				)
				entry.hex_id = cell.id
				entry.deme_id = deme.id
				entry.lineage_id = deme.lineage_id
				state.chronicle.append(entry)
				EvoSettlementPhase.mark_lineage_if_extinct(state, deme.lineage_id)

	EvoSettlementPhase.revalidate_walled_unions(state)
	EvoRuralHinterland.enforce_rural_hinterland_quotas(state)

	var valid_flows: Array[EvoTypes.HexEdgeFlow] = []
	for fl in state.active_flows:
		if fl.from_deme_id != "" and not state.demes.has(fl.from_deme_id):
			continue
		if fl.to_deme_id != "" and not state.demes.has(fl.to_deme_id):
			continue
		if fl.flow_type != "migration":
			if fl.from_deme_id != "" and state.demes.has(fl.from_deme_id):
				fl.from_hex_id = (state.demes[fl.from_deme_id] as EvoTypes.Deme).hex_id
			if fl.to_deme_id != "" and state.demes.has(fl.to_deme_id):
				fl.to_hex_id = (state.demes[fl.to_deme_id] as EvoTypes.Deme).hex_id
			if (state.cells.has(fl.from_hex_id) and (state.cells[fl.from_hex_id] as EvoTypes.HexCell).biome == "ocean") or (state.cells.has(fl.to_hex_id) and (state.cells[fl.to_hex_id] as EvoTypes.HexCell).biome == "ocean"):
				continue
		else:
			if state.cells.has(fl.to_hex_id) and (state.cells[fl.to_hex_id] as EvoTypes.HexCell).biome == "ocean":
				continue
		valid_flows.append(fl)
	state.active_flows = valid_flows

	var valid_conns: Array[Dictionary] = []
	for conn in state.disused_connections:
		var fa := str(conn["from_deme_id"])
		var fb := str(conn["to_deme_id"])
		if (fa != "" and not state.demes.has(fa)) or (fb != "" and not state.demes.has(fb)):
			continue
		var ha := str(conn["from_hex_id"])
		var hb := str(conn["to_hex_id"])
		if (state.cells.has(ha) and (state.cells[ha] as EvoTypes.HexCell).biome == "ocean") or (state.cells.has(hb) and (state.cells[hb] as EvoTypes.HexCell).biome == "ocean"):
			continue
		valid_conns.append(conn)
	state.disused_connections = valid_conns
