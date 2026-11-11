class_name EvoRuralHinterland
extends RefCounted


static func get_max_rural_quota(tier: int) -> int:
	return 0 if tier < 2 else (1 if tier == 2 else (2 if tier == 3 else 4))


static func deme_rural_quota(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> int:
	var any_habitable := false
	for hid in deme.urban_hex_ids:
		if state.cells.has(hid):
			var c: EvoTypes.HexCell = state.cells[hid]
			if c.biome not in ["ocean", "high_mountain"] and c.altitude <= 0.85:
				any_habitable = true
				break
	if not any_habitable:
		return 0
	return get_max_rural_quota(deme.get_village_tier()) + maxi(0, deme.urban_hex_ids.size() - 1)


static func _release_all_deme_rural_hexes(state: EvoTypes.WorldState, deme_id: String) -> void:
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.owner_deme_id == deme_id:
			cell.owner_deme_id = ""
			cell.land_use = "wild"


static func _score_rural_candidate(cell: EvoTypes.HexCell) -> float:
	return cell.current_resources


static func enforce_rural_hinterland_quotas(state: EvoTypes.WorldState) -> void:
	var perimeters_by_deme: Dictionary = {}
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		var pset: Dictionary = {}
		for nid in EvoTypes.urban_perimeter_hex_ids(d, state):
			pset[nid] = true
		perimeters_by_deme[did] = pset

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if not cell.deme_ids.is_empty() or cell.biome in ["ocean", "high_mountain"] or cell.altitude > 0.85:
			cell.land_use = "wild"
			cell.owner_deme_id = ""
			if not cell.deme_ids.is_empty() or cell.biome == "ocean":
				cell.has_ruins = false
				cell.ruin_turns = 0
		elif cell.owner_deme_id != "":
			if not state.demes.has(cell.owner_deme_id) or cell.ruin_turns > 0 or not (perimeters_by_deme[cell.owner_deme_id] as Dictionary).has(cell.id):
				cell.land_use = "wild"
				cell.owner_deme_id = ""

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		var max_rural := deme_rural_quota(deme, state)
		var owned_neighbors := owned_hexes(deme, state)
		if owned_neighbors.size() > max_rural:
			owned_neighbors.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				return _score_rural_candidate(a) < _score_rural_candidate(b)
			)
			while owned_neighbors.size() > max_rural:
				var rel_cell: EvoTypes.HexCell = owned_neighbors.pop_front()
				rel_cell.owner_deme_id = ""
				rel_cell.land_use = "wild"


static func claim_hinterlands(state: EvoTypes.WorldState) -> void:
	enforce_rural_hinterland_quotas(state)
	var sorted_demes: Array[EvoTypes.Deme] = []
	for did in state.demes.keys():
		sorted_demes.append(state.demes[did])
	sorted_demes.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool:
		if a.population != b.population:
			return a.population > b.population
		return a.id < b.id
	)
	for deme in sorted_demes:
		var max_rural := deme_rural_quota(deme, state)
		var owned := owned_hexes(deme, state)
		if owned.size() >= max_rural:
			continue
		var reserved_settle := str(deme.chosen_action["target"]) if str(deme.chosen_action["type"]) == "settle" else ""
		var unclaimed: Array[EvoTypes.HexCell] = []
		for nid in EvoTypes.urban_perimeter_hex_ids(deme, state):
			if nid == reserved_settle:
				continue
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.deme_ids.is_empty() and ncell.owner_deme_id == "" and ncell.ruin_turns == 0 and ncell.biome not in ["ocean", "high_mountain"] and ncell.altitude <= 0.85:
				unclaimed.append(ncell)
		unclaimed.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
			return _score_rural_candidate(a) > _score_rural_candidate(b)
		)
		for ncell in unclaimed.slice(0, max_rural - owned.size()):
			ncell.owner_deme_id = deme.id
			ncell.land_use = "pasture" if ncell.biome in ["arid_steppe", "tundra"] else "crops"


static func owned_hexes(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.HexCell]:
	var owned: Array[EvoTypes.HexCell] = []
	for nid in EvoTypes.urban_perimeter_hex_ids(deme, state):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if ncell.owner_deme_id == deme.id:
			owned.append(ncell)
	return owned


static func _hex_yield_for_posture(
	deme: EvoTypes.Deme,
	ncell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	posture: String
) -> float:
	var extraction := EvoPayoffs.vector(deme, state).extraction_efficiency
	var cap_mult := clampf(0.24 + 0.16 * maxf(0.0, extraction), 0.24, 0.42)
	var biome_mult := 0.85 if ((ncell.biome in ["arid_steppe", "tundra"]) == (ncell.land_use == "pasture")) else 0.72
	var posture_mult := float(EvoPayoffs.POSTURE_HARVEST_MULT[posture])
	return minf(ncell.current_resources, float(deme.population) * cap_mult) * biome_mult * posture_mult


static func _hex_yield(deme: EvoTypes.Deme, ncell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> float:
	return _hex_yield_for_posture(deme, ncell, state, deme.defense_posture)


static func rural_yield_for_posture(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	posture: String
) -> float:
	var owned := owned_hexes(deme, state)
	if owned.is_empty():
		return 0.0
	var extraction := EvoPayoffs.vector(deme, state).extraction_efficiency
	var cap := float(deme.population) * clampf(0.24 + 0.16 * maxf(0.0, extraction), 0.24, 0.42)
	var posture_mult := float(EvoPayoffs.POSTURE_HARVEST_MULT[posture])
	var total := 0.0
	for ncell in owned:
		var biome_mult := 0.85 if ((ncell.biome in ["arid_steppe", "tundra"]) == (ncell.land_use == "pasture")) else 0.72
		total += minf(ncell.current_resources, cap) * biome_mult * posture_mult
	return total


static func rural_yield_estimate(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return rural_yield_for_posture(deme, state, deme.defense_posture)


static func harvest_rural(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var total := 0.0
	for ncell in owned_hexes(deme, state):
		var harvest := _hex_yield(deme, ncell, state)
		ncell.current_resources = maxf(0.0, ncell.current_resources - harvest)
		total += harvest
	return total
