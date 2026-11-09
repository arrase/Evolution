class_name EvoRuralHinterland
extends RefCounted


static func get_max_rural_quota(tier: int) -> int:
	return 0 if tier < 2 else (1 if tier == 2 else (2 if tier == 3 else 4))


static func _release_all_deme_rural_hexes(state: EvoTypes.WorldState, deme_id: String) -> void:
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.owner_deme_id == deme_id:
			cell.owner_deme_id = ""
			cell.land_use = "wild"


static func _score_rural_candidate(cell: EvoTypes.HexCell) -> float:
	return cell.current_resources


static func enforce_rural_hinterland_quotas(state: EvoTypes.WorldState) -> void:
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if not cell.deme_ids.is_empty() or cell.biome in ["ocean", "high_mountain"] or cell.altitude > 0.85:
			cell.land_use = "wild"
			cell.owner_deme_id = ""
			if not cell.deme_ids.is_empty() or cell.biome == "ocean":
				cell.has_ruins = false
		elif cell.owner_deme_id != "":
			if not state.demes.has(cell.owner_deme_id):
				cell.land_use = "wild"
				cell.owner_deme_id = ""
			else:
				var owner: EvoTypes.Deme = state.demes[cell.owner_deme_id]
				if not state.cells.has(owner.hex_id):
					cell.land_use = "wild"
					cell.owner_deme_id = ""
				else:
					var ocell: EvoTypes.HexCell = state.cells[owner.hex_id]
					if HexMath.hex_distance(cell.q, cell.r, ocell.q, ocell.r) != 1:
						cell.land_use = "wild"
						cell.owner_deme_id = ""

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(deme.hex_id):
			continue
		var dcell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var tier := deme.get_village_tier()
		var max_rural: int = get_max_rural_quota(tier)
		if dcell.biome in ["ocean", "high_mountain"] or dcell.altitude > 0.85:
			max_rural = 0

		var owned_neighbors: Array[EvoTypes.HexCell] = []
		for nid in HexMath.get_neighbor_ids(dcell.q, dcell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.owner_deme_id == deme.id:
				owned_neighbors.append(ncell)

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
	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		var dcell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var max_rural := get_max_rural_quota(deme.get_village_tier())
		var owned := owned_hexes(deme, state)
		if owned.size() >= max_rural:
			continue
		var unclaimed: Array[EvoTypes.HexCell] = []
		for nid in HexMath.get_neighbor_ids(dcell.q, dcell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.deme_ids.is_empty() and ncell.owner_deme_id == "" and ncell.biome not in ["ocean", "high_mountain"] and ncell.altitude <= 0.85:
				unclaimed.append(ncell)
		unclaimed.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
			return _score_rural_candidate(a) > _score_rural_candidate(b)
		)
		for ncell in unclaimed.slice(0, max_rural - owned.size()):
			ncell.owner_deme_id = deme.id
			ncell.has_ruins = false
			ncell.land_use = "pasture" if ncell.biome in ["arid_steppe", "tundra"] else "crops"


static func owned_hexes(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.HexCell]:
	var dcell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var owned: Array[EvoTypes.HexCell] = []
	for nid in HexMath.get_neighbor_ids(dcell.q, dcell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if ncell.owner_deme_id == deme.id:
			owned.append(ncell)
	return owned


static func _hex_yield(deme: EvoTypes.Deme, ncell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> float:
	var extraction := EvoPayoffs.vector(deme, state).extraction_efficiency
	var cap_mult := clampf(0.16 + 0.12 * maxf(0.0, extraction), 0.16, 0.30)
	return minf(ncell.current_resources, float(deme.population) * cap_mult) * 0.65


static func rural_yield_estimate(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var total := 0.0
	for ncell in owned_hexes(deme, state):
		total += _hex_yield(deme, ncell, state)
	return total


static func harvest_rural(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var total := 0.0
	for ncell in owned_hexes(deme, state):
		var harvest := _hex_yield(deme, ncell, state)
		ncell.current_resources = maxf(0.0, ncell.current_resources - harvest)
		total += harvest
	return total
