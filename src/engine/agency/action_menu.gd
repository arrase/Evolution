class_name EvoActionMenu
extends RefCounted

## Feasible, targeted actions for a settlement this turn.

const MAX_NEIGHBORS := 3
const MAX_SETTLE_OPTIONS := 2
const MAX_OPTIONS := 14


static func option(action_type: String, target: String = "") -> Dictionary:
	return {
		"key": action_type if target == "" else "%s:%s" % [action_type, target],
		"type": action_type,
		"target": target
	}


static func parse_key(key: String) -> Dictionary:
	var sep := key.find(":")
	return option(key, "") if sep < 0 else option(key.substr(0, sep), key.substr(sep + 1))


static func is_passable(cell: EvoTypes.HexCell) -> bool:
	return cell.biome not in ["ocean", "high_mountain"] and cell.altitude <= 0.85


static func neighbor_demes(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.Deme]:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var result: Array[EvoTypes.Deme] = []
	for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if is_passable(ncell):
			for oid in ncell.deme_ids:
				result.append(state.demes[oid])
	return result


static func settle_targets(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.HexCell]:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var result: Array[EvoTypes.HexCell] = []
	for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if is_passable(ncell) and ncell.deme_ids.is_empty() and (ncell.owner_deme_id == "" or ncell.owner_deme_id == deme.id):
			result.append(ncell)
	result.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
		return a.current_resources > b.current_resources
	)
	return result


static func _salience(deme: EvoTypes.Deme, other: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var key := EvoTypes.make_pair_key(deme.id, other.id)
	var score := float(other.population)
	if state.relations.has(key):
		var rel: EvoTypes.Relation = state.relations[key]
		if rel.proposal_from == other.id:
			score += 10000.0
		if rel.pact_turns > 0 or rel.feud_turns > 0:
			score += 1000.0
	if other.lineage_id != deme.lineage_id:
		score += 500.0
	return score


static func build(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[Dictionary]:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var responses: Array[Dictionary] = []
	var options: Array[Dictionary] = [option("forage"), option("intensify")]
	if EvoPayoffs.can_fortify(deme, cell):
		options.append(option("fortify"))
	if EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog):
		options.append(option("innovate"))
	if deme.population >= EvoPayoffs.SETTLE_MIN_POP and deme.energy_reserves >= 45.0:
		for target: EvoTypes.HexCell in settle_targets(deme, state).slice(0, MAX_SETTLE_OPTIONS):
			options.append(option("settle", target.id))

	var neighbors := neighbor_demes(deme, state)
	neighbors.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool:
		return _salience(deme, a, state) > _salience(deme, b, state)
	)
	for other: EvoTypes.Deme in neighbors.slice(0, MAX_NEIGHBORS):
		var key := EvoTypes.make_pair_key(deme.id, other.id)
		var rel: EvoTypes.Relation = state.relations[key] if state.relations.has(key) else EvoTypes.Relation.new()
		var kin: bool = other.lineage_id == deme.lineage_id
		if EvoRelations.has_open_proposal(state, other.id, deme.id, "pact"):
			responses.append(option("accept_pact", other.id))
		if EvoRelations.has_open_proposal(state, other.id, deme.id, "union"):
			responses.append(option("accept_union", other.id))
		if EvoRelations.has_open_proposal(state, other.id, deme.id, "tribute"):
			responses.append(option("pay_tribute", other.id))
		if rel.feud_turns == 0:
			options.append(option("trade", other.id))
		if deme.energy_reserves >= 40.0 and other.energy_reserves < float(other.population) * 0.9:
			options.append(option("aid", other.id))
		if rel.pact_turns >= 3 and deme.get_village_tier() >= 2 and other.get_village_tier() >= 2 and deme.walled_union_id == "" and other.walled_union_id == "":
			options.append(option("unite", other.id))
		if rel.pact_turns > 0:
			if not kin:
				options.append(option("betray", other.id))
			continue
		if rel.feud_turns == 0 and rel.proposal_from != deme.id and (kin or rel.trust >= 0.12):
			options.append(option("offer_pact", other.id))
		if kin or rel.truce_turns > 0:
			continue
		if other.defense_tier < 3:
			options.append(option("raid", other.id))
		options.append(option("conquer", other.id))
		if rel.proposal_from == "" and other.energy_reserves >= 20.0 and float(EvoPayoffs.raid_odds(deme, other, state, false)["p_win"]) >= 0.35:
			options.append(option("demand_tribute", other.id))

	return (responses + options).slice(0, MAX_OPTIONS)
