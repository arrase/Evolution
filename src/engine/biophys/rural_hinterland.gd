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


static func _update_and_harvest_rural_hinterlands(
	state: EvoTypes.WorldState,
	_effective_vec_by_deme: Dictionary,
	extracted_energy_by_deme: Dictionary
) -> void:
	enforce_rural_hinterland_quotas(state)

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
		var unclaimed_neighbors: Array[EvoTypes.HexCell] = []
		for nid in HexMath.get_neighbor_ids(dcell.q, dcell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.owner_deme_id == deme.id:
				owned_neighbors.append(ncell)
			elif max_rural > 0 and ncell.deme_ids.is_empty() and ncell.owner_deme_id == "" and ncell.biome not in ["ocean", "high_mountain"] and ncell.altitude <= 0.85:
				unclaimed_neighbors.append(ncell)

		if owned_neighbors.size() < max_rural and not unclaimed_neighbors.is_empty():
			unclaimed_neighbors.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				return _score_rural_candidate(a) > _score_rural_candidate(b)
			)
			for ncell in unclaimed_neighbors:
				if owned_neighbors.size() >= max_rural:
					break
				ncell.owner_deme_id = deme.id
				ncell.has_ruins = false
				ncell.land_use = "pasture" if ncell.biome in ["arid_steppe", "tundra"] else "crops"
				owned_neighbors.append(ncell)

		for ncell in owned_neighbors:
			var harvest := snappedf(minf(ncell.current_resources, float(deme.population) * 0.35) * 0.70, 0.01)
			if harvest > 0.0:
				ncell.current_resources = maxf(0.0, snappedf(ncell.current_resources - harvest, 0.01))
				extracted_energy_by_deme[deme.id] = snappedf(float(extracted_energy_by_deme.get(deme.id, 0.0)) + harvest, 0.0001)
