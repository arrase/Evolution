class_name EvoEnvPhase
extends RefCounted


static func run_environmental_phase(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var prev_generation := state.generation
	var next_generation := state.generation + 1
	state.generation = next_generation
	state.season = "dry_cold" if state.season == "wet_warm" else "wet_warm"
	var gamma_season: float = 1.20 if state.season == "wet_warm" else 0.75

	var prev_exchange_conns: Array[Dictionary] = []
	for existing_conn in state.disused_connections:
		prev_exchange_conns.append(existing_conn.duplicate())
	for fl in state.active_flows:
		if fl.flow_type in ["exchange", "cooperate"]:
			var fa := fl.from_deme_id
			var fb := fl.to_deme_id
			var already_saved := false
			for conn in prev_exchange_conns:
				var ca := str(conn["from_deme_id"])
				var cb := str(conn["to_deme_id"])
				if (ca == fa and cb == fb) or (ca == fb and cb == fa):
					conn["from_hex_id"] = fl.from_hex_id
					conn["to_hex_id"] = fl.to_hex_id
					already_saved = true
					break
			if not already_saved:
				prev_exchange_conns.append({
					"from_hex_id": fl.from_hex_id,
					"to_hex_id": fl.to_hex_id,
					"from_deme_id": fa,
					"to_deme_id": fb
				})
	state.disused_connections = prev_exchange_conns
	state.active_flows.clear()
	state.recent_extinction_hexes.clear()

	if (state.glacial_sea_level_cycle or state.preset_id == "preset-darwin-archipelago") and next_generation % 8 == 0:
		state.sea_level = 0.12 if ((next_generation / 8) % 2 == 0) else 0.25

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.altitude < state.sea_level and cell.biome != "ocean":
			cell.biome = "ocean"
		elif cell.altitude >= state.sea_level and cell.biome == "ocean":
			if cell.altitude < 0.25:
				cell.biome = "coastal_shallows"
			elif cell.altitude < 0.55:
				cell.biome = "savanna"
			elif cell.altitude < 0.78:
				cell.biome = "arid_steppe"
			else:
				cell.biome = "high_mountain"
			cell.carrying_capacity_max = maxf(160.0, cell.carrying_capacity_max)
			cell.carrying_capacity = maxf(roundf(cell.carrying_capacity_max * 0.88), cell.carrying_capacity)
			cell.current_resources = maxf(cell.current_resources, roundf(cell.carrying_capacity * 0.35))

	var is_en := lang == "en"
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.biome == "ocean" and not cell.deme_ids.is_empty():
			var resident_ids := cell.deme_ids.duplicate()
			cell.deme_ids.clear()

			for deme_id in resident_ids:
				if not state.demes.has(deme_id):
					continue
				var deme: EvoTypes.Deme = state.demes[deme_id]

				var candidates: Array[EvoTypes.HexCell] = []
				for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
					var ncell: EvoTypes.HexCell = state.cells[nid]
					if ncell.biome != "ocean" and ncell.deme_ids.size() < 3 and ncell.altitude <= 0.85:
						candidates.append(ncell)

				candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
					return a.current_resources > b.current_resources
				)

				if not candidates.is_empty():
					var target_cell := candidates[0]
					deme.hex_id = target_cell.id
					deme.energy_reserves = snappedf(deme.energy_reserves * 0.80, 0.01)
					target_cell.deme_ids.append(deme.id)

					var flow := EvoTypes.HexEdgeFlow.new()
					flow.from_hex_id = cell.id
					flow.to_hex_id = target_cell.id
					flow.flow_type = "migration"
					flow.intensity = 0.65
					flow.from_deme_id = deme.id
					flow.to_deme_id = deme.id
					state.active_flows.append(flow)
				else:
					state.demes.erase(deme_id)
					if not state.recent_extinction_hexes.has(cell.id):
						state.recent_extinction_hexes.append(cell.id)

					var entry := EvoTypes.ChronicleEntry.new()
					entry.id = "chronicle-submerge-%d-%s" % [next_generation, deme.id]
					entry.generation = next_generation
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

					var has_relatives := false
					for rem_id in state.demes.keys():
						var rem: EvoTypes.Deme = state.demes[rem_id]
						if rem.lineage_id == deme.lineage_id:
							has_relatives = true
							break
					if not has_relatives and state.lineage_tree.has(deme.lineage_id):
						(state.lineage_tree[deme.lineage_id] as EvoTypes.LineageNode).extinct_generation = next_generation

	var delta_temp: float = 0.04 if state.season == "wet_warm" else -0.04
	var delta_hum: float = 0.05 if state.season == "wet_warm" else -0.05

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.biome == "ocean":
			cell.current_resources = 0.0
			continue

		cell.temperature = clampf(snappedf(cell.temperature + delta_temp, 0.01), -1.0, 1.0)
		cell.humidity = clampf(snappedf(cell.humidity + delta_hum, 0.01), 0.0, 1.0)

		var suffered_collapse := false
		for entry in state.chronicle:
			if entry.event_type == "tragedy_of_commons" and entry.hex_id == cell.id and entry.generation == prev_generation:
				suffered_collapse = true
				break

		var recovery_rate: float = 0.005 if (suffered_collapse or cell.current_resources <= 0.0) else 0.05
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

	state.selective_pressure_points += state.selective_pressure_regen_per_turn
