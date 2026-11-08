class_name EvoEnvPhase
extends RefCounted


static func _prune_stale_pacts(state: EvoTypes.WorldState) -> void:
	if state.active_pacts.is_empty():
		return
	var sep := EvoTypes.make_pair_key("a", "b").trim_prefix("a").trim_suffix("b")
	var stale_keys: Array[String] = []
	for pk_var in state.active_pacts.keys():
		var pk := str(pk_var)
		var parts := pk.split(sep)
		if parts.size() != 2 or not state.demes.has(parts[0]) or not state.demes.has(parts[1]):
			stale_keys.append(pk)
	for pk in stale_keys:
		state.active_pacts.erase(pk)


static func run_environmental_phase(state: EvoTypes.WorldState, lang: String = "es") -> void:
	_prune_stale_pacts(state)

	var prev_generation := state.generation
	var next_generation := state.generation + 1
	state.generation = next_generation
	state.season = "dry_cold" if state.season == "wet_warm" else "wet_warm"
	var gamma_season: float = 1.20 if state.season == "wet_warm" else 0.75

	var prev_exchange_conns: Array[Dictionary] = []
	var conn_idx_by_pair: Dictionary = {}
	for existing_conn in state.disused_connections:
		var c_copy := existing_conn.duplicate()
		c_copy["age"] = int(existing_conn.get("age", 0)) + 1
		c_copy["broken_gen"] = int(existing_conn.get("broken_gen", prev_generation))
		var pk := EvoTypes.make_pair_key(str(c_copy.get("from_deme_id", "")), str(c_copy.get("to_deme_id", "")))
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
	state.recent_extinction_hexes.clear()

	if state.glacial_sea_level_cycle and next_generation % 8 == 0:
		state.sea_level = 0.12 if ((next_generation / 8) % 2 == 0) else 0.25

	var biome_changed_hexes: Dictionary = {}
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.altitude < state.sea_level and cell.biome != "ocean":
			EvoTurnEngine._apply_biome_climate_defaults(cell, "ocean")
			biome_changed_hexes[cell.id] = true
		elif cell.altitude >= state.sea_level and cell.biome == "ocean":
			if cell.altitude < 0.25:
				cell.biome = "coastal_shallows"
			elif cell.altitude < 0.55:
				cell.biome = "savanna"
			elif cell.altitude < 0.78:
				cell.biome = "arid_steppe"
			else:
				cell.biome = "high_mountain"
			var defaults: Dictionary = EvoTypes.BIOME_CLIMATE_DEFAULTS[cell.biome]
			cell.temperature = float(defaults["temperature"])
			cell.humidity = float(defaults["humidity"])
			cell.seasonal_regen_rate = float(defaults["regen"])
			cell.carrying_capacity_max = maxf(float(defaults["k_max"]), cell.carrying_capacity_max)
			cell.carrying_capacity = maxf(roundf(cell.carrying_capacity_max * 0.88), cell.carrying_capacity)
			cell.current_resources = maxf(cell.current_resources, roundf(cell.carrying_capacity * 0.35))
			biome_changed_hexes[cell.id] = true

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.biome == "ocean" and not cell.deme_ids.is_empty():
			var resident_ids := cell.deme_ids.duplicate()
			for deme_id in resident_ids:
				if not state.demes.has(deme_id):
					cell.deme_ids.erase(deme_id)
					continue
				var deme: EvoTypes.Deme = state.demes[deme_id]
				EvoDemographyMigration.evacuate_or_merge_displaced_deme(deme, cell, state, lang, "submerge")

	_prune_stale_pacts(state)

	var delta_temp: float = 0.04 if state.season == "wet_warm" else -0.04
	var delta_hum: float = 0.05 if state.season == "wet_warm" else -0.05

	var collapsed_prev_gen_hexes: Dictionary = {}
	for idx in range(state.chronicle.size() - 1, -1, -1):
		var entry: EvoTypes.ChronicleEntry = state.chronicle[idx]
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

		cell.temperature = clampf(snappedf(cell.temperature + delta_temp, 0.01), -1.0, 1.0)
		cell.humidity = clampf(snappedf(cell.humidity + delta_hum, 0.01), 0.0, 1.0)

		var suffered_collapse := collapsed_prev_gen_hexes.has(cell.id)
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

	state.selective_pressure_points += state.selective_pressure_regen_per_turn
