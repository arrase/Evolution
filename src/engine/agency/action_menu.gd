class_name EvoActionMenu
extends RefCounted

## Feasible, targeted actions for a settlement this turn.

const MAX_NEIGHBORS := 4
const MAX_SETTLE_OPTIONS := 3
const MAX_OPTIONS := 14
const MAX_EMERGENT_CULTURAL := 3


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


static func is_passable_for(cell: EvoTypes.HexCell, mobility: float = 0.0) -> bool:
	var max_alt := 0.88 if mobility >= 0.45 else 0.85
	return cell.biome != "ocean" and (cell.biome != "high_mountain" or mobility >= 0.45) and cell.altitude <= max_alt


static func max_settle_hops(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> int:
	return 3 if EvoPayoffs.vector(deme, state).spatial_mobility >= 0.45 else 2


static func neighbor_demes(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.Deme]:
	var mobility := EvoPayoffs.vector(deme, state).spatial_mobility
	var result: Array[EvoTypes.Deme] = []
	var seen: Dictionary = {deme.id: true}
	for nid in EvoTypes.urban_perimeter_hex_ids(deme, state):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if not is_passable_for(ncell, mobility):
			continue
		for oid in ncell.deme_ids:
			if not seen.has(oid) and state.demes.has(oid):
				seen[oid] = true
				result.append(state.demes[oid])
	return result


static func border_field_rivals(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.Deme]:
	var mobility := EvoPayoffs.vector(deme, state).spatial_mobility
	var perim := EvoTypes.urban_perimeter_hex_ids(deme, state)
	var seen: Dictionary = {deme.id: true}
	for nid in perim:
		var pcell: EvoTypes.HexCell = state.cells[nid]
		if is_passable_for(pcell, mobility):
			for oid in pcell.deme_ids:
				seen[oid] = true
	var result: Array[EvoTypes.Deme] = []
	for nid in perim:
		var ncell: EvoTypes.HexCell = state.cells[nid]
		var oid := ncell.owner_deme_id
		if oid == "" or seen.has(oid) or not state.demes.has(oid):
			continue
		var other: EvoTypes.Deme = state.demes[oid]
		var pk := EvoTypes.make_pair_key(deme.id, other.id)
		var rel: EvoTypes.Relation = state.relations[pk] if state.relations.has(pk) else null
		if rel != null and (rel.pact_turns > 0 or rel.truce_turns > 0):
			continue
		if other.lineage_id != deme.lineage_id or (rel != null and rel.feud_turns > 0):
			seen[oid] = true
			result.append(other)
	return result


static func field_raiders(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.Deme]:
	var mobility := EvoPayoffs.vector(deme, state).spatial_mobility
	var perim := EvoTypes.urban_perimeter_hex_ids(deme, state)
	var seen: Dictionary = {deme.id: true}
	for pid in perim:
		var pcell: EvoTypes.HexCell = state.cells[pid]
		if is_passable_for(pcell, mobility):
			for oid in pcell.deme_ids:
				seen[oid] = true
	var result: Array[EvoTypes.Deme] = []
	for pid in perim:
		var field: EvoTypes.HexCell = state.cells[pid]
		if field.owner_deme_id != deme.id or field.land_use not in ["crops", "pasture"]:
			continue
		for nid in HexMath.get_neighbor_ids(field.q, field.r, state.cells):
			for oid in (state.cells[nid] as EvoTypes.HexCell).deme_ids:
				if seen.has(oid) or not state.demes.has(oid):
					continue
				var other: EvoTypes.Deme = state.demes[oid]
				var pk := EvoTypes.make_pair_key(deme.id, other.id)
				var rel: EvoTypes.Relation = state.relations[pk] if state.relations.has(pk) else null
				if rel != null and (rel.pact_turns > 0 or rel.truce_turns > 0):
					continue
				if other.lineage_id != deme.lineage_id or (rel != null and rel.feud_turns > 0):
					seen[oid] = true
					result.append(other)
	return result


static func threat_counts_from(
	deme: EvoTypes.Deme,
	neighbors: Array[EvoTypes.Deme],
	raiders: Array[EvoTypes.Deme],
	state: EvoTypes.WorldState
) -> Vector2i:
	var seen: Dictionary = {deme.id: true}
	var total := 0
	var feuds := 0
	for other in neighbors:
		if not seen.has(other.id):
			seen[other.id] = true
			var d1 := _threat_delta(deme, other, state)
			total += d1.x
			feuds += d1.y
	for other in raiders:
		if not seen.has(other.id):
			seen[other.id] = true
			var d2 := _threat_delta(deme, other, state)
			total += d2.x
			feuds += d2.y
	return Vector2i(total, feuds)


static func raid_threat_counts(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Vector2i:
	return threat_counts_from(deme, neighbor_demes(deme, state), field_raiders(deme, state), state)


static func _threat_delta(deme: EvoTypes.Deme, other: EvoTypes.Deme, state: EvoTypes.WorldState) -> Vector2i:
	if other.population < 35:
		return Vector2i.ZERO
	var pk := EvoTypes.make_pair_key(deme.id, other.id)
	var rel: EvoTypes.Relation = state.relations[pk] if state.relations.has(pk) else null
	if rel != null and (rel.pact_turns > 0 or rel.truce_turns > 0):
		return Vector2i.ZERO
	var has_feud := rel != null and rel.feud_turns > 0
	if other.lineage_id != deme.lineage_id or has_feud:
		return Vector2i(1, 1 if has_feud else 0)
	return Vector2i.ZERO


static func _min_dist_to_urban(cell: EvoTypes.HexCell, deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> int:
	var best := 999
	for hid in deme.urban_hex_ids:
		var ucell: EvoTypes.HexCell = state.cells[hid]
		best = mini(best, HexMath.hex_distance(cell.q, cell.r, ucell.q, ucell.r))
	return best


static func _is_friendly_deme(deme: EvoTypes.Deme, other_id: String, state: EvoTypes.WorldState) -> bool:
	if other_id == deme.id:
		return true
	if not state.demes.has(other_id):
		return false
	var other: EvoTypes.Deme = state.demes[other_id]
	if EvoTypes.is_pact_active(state, deme.id, other_id):
		return true
	return other.lineage_id == deme.lineage_id and not EvoTypes.is_vendetta_active(state, deme.id, other_id)


static func _can_traverse_for_settle(cell: EvoTypes.HexCell, deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> bool:
	if not cell.deme_ids.is_empty():
		return _is_friendly_deme(deme, cell.deme_ids[0], state)
	if cell.owner_deme_id != "":
		return _is_friendly_deme(deme, cell.owner_deme_id, state)
	return true


static func _frontier_bridge_bonus_for(cell: EvoTypes.HexCell, deme: EvoTypes.Deme, state: EvoTypes.WorldState, mobility: float) -> float:
	for nn_id in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
		var nn: EvoTypes.HexCell = state.cells[nn_id]
		if is_passable_for(nn, mobility) and nn.deme_ids.is_empty() and nn.owner_deme_id == "" and _min_dist_to_urban(nn, deme, state) > 1:
			return 120.0
	return 0.0


static func frontier_bridge_bonus(cell: EvoTypes.HexCell, deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return _frontier_bridge_bonus_for(cell, deme, state, EvoPayoffs.vector(deme, state).spatial_mobility)


static func settle_corridor_hops(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	var mobility := EvoPayoffs.vector(deme, state).spatial_mobility
	var max_hops := 3 if mobility >= 0.45 else 2
	var dist_by_hex: Dictionary = {}
	var queue: Array[String] = []
	for hid in deme.urban_hex_ids:
		dist_by_hex[hid] = 0
		queue.append(hid)
	var head := 0
	while head < queue.size():
		var cur_id := queue[head]
		head += 1
		var cur_d := int(dist_by_hex[cur_id])
		if cur_d >= max_hops:
			continue
		var cur_cell: EvoTypes.HexCell = state.cells[cur_id]
		for nid in HexMath.get_neighbor_ids(cur_cell.q, cur_cell.r, state.cells):
			if dist_by_hex.has(nid):
				continue
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if not is_passable_for(ncell, mobility) or not _can_traverse_for_settle(ncell, deme, state):
				continue
			dist_by_hex[nid] = cur_d + 1
			queue.append(nid)
	return dist_by_hex


static func settle_hop_distance(deme: EvoTypes.Deme, target_hex_id: String, state: EvoTypes.WorldState) -> int:
	var min_d := _min_dist_to_urban(state.cells[target_hex_id], deme, state)
	if min_d <= 1:
		return min_d
	var hops := settle_corridor_hops(deme, state)
	if hops.has(target_hex_id):
		return int(hops[target_hex_id])
	return min_d


static func settle_targets_with_hops(deme: EvoTypes.Deme, state: EvoTypes.WorldState, hops: Dictionary) -> Array[EvoTypes.HexCell]:
	var mobility := EvoPayoffs.vector(deme, state).spatial_mobility
	var result: Array[EvoTypes.HexCell] = []
	var scores: Dictionary = {}
	for hid in hops.keys():
		if int(hops[hid]) == 0:
			continue
		var c: EvoTypes.HexCell = state.cells[hid]
		if c.deme_ids.is_empty() and c.owner_deme_id == "" and c.ruin_turns == 0:
			result.append(c)
			scores[hid] = c.current_resources + _frontier_bridge_bonus_for(c, deme, state, mobility)

	result.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
		var sa := float(scores[a.id])
		var sb := float(scores[b.id])
		if not is_equal_approx(sa, sb):
			return sa > sb
		var ha := int(hops[a.id])
		var hb := int(hops[b.id])
		if ha != hb:
			return ha < hb
		return a.id < b.id
	)

	if result.is_empty() and deme.population >= 260:
		for nid in EvoTypes.urban_perimeter_hex_ids(deme, state):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if is_passable_for(ncell, mobility) and ncell.deme_ids.is_empty() and ncell.owner_deme_id == deme.id and ncell.ruin_turns == 0:
				result.append(ncell)
		result.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
			return a.current_resources > b.current_resources
		)
	return result


static func settle_targets(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.HexCell]:
	return settle_targets_with_hops(deme, state, settle_corridor_hops(deme, state))


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
		score += 1200.0
	return score


static func build(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[Dictionary]:
	var hops := settle_corridor_hops(deme, state)
	var targets := settle_targets_with_hops(deme, state, hops)
	return build_with_targets(deme, state, targets, neighbor_demes(deme, state), border_field_rivals(deme, state), {})


static func build_with_targets(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	s_targets: Array[EvoTypes.HexCell],
	p_neighbors: Array[EvoTypes.Deme],
	p_rivals: Array[EvoTypes.Deme],
	raid_cache: Dictionary
) -> Array[Dictionary]:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var responses: Array[Dictionary] = []
	var options: Array[Dictionary] = [option("forage"), option("intensify")]
	var kin_secondary: Array[Dictionary] = []
	if EvoPayoffs.can_fortify(deme, cell):
		options.append(option("fortify"))
	if EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog) and EvoMilestonePhase.count_emergent_cultural_traits(deme, state) < MAX_EMERGENT_CULTURAL:
		options.append(option("innovate"))
	if deme.population >= EvoPayoffs.settle_min_pop(deme) and deme.energy_reserves >= EvoPayoffs.settle_min_reserves(deme):
		for target: EvoTypes.HexCell in s_targets.slice(0, MAX_SETTLE_OPTIONS):
			options.append(option("settle", target.id))

	var neighbors := p_neighbors.duplicate()
	neighbors.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool:
		return _salience(deme, a, state) > _salience(deme, b, state)
	)
	var handled_tribute_from: Dictionary = {}
	var vec := EvoPayoffs.vector(deme, state)
	var food_req := EvoPayoffs.food_need(deme, cell, state)

	for other: EvoTypes.Deme in neighbors.slice(0, MAX_NEIGHBORS):
		var key := EvoTypes.make_pair_key(deme.id, other.id)
		var rel: EvoTypes.Relation = state.relations[key] if state.relations.has(key) else EvoTypes.Relation.new()
		var kin: bool = other.lineage_id == deme.lineage_id
		var bucket: Array[Dictionary] = kin_secondary if (kin and rel.feud_turns == 0) else options
		if EvoRelations.has_open_proposal(state, other.id, deme.id, "pact"):
			responses.append(option("accept_pact", other.id))
		if EvoRelations.has_open_proposal(state, other.id, deme.id, "union"):
			responses.append(option("accept_union", other.id))
		if EvoRelations.has_open_proposal(state, other.id, deme.id, "tribute"):
			responses.append(option("pay_tribute", other.id))
			handled_tribute_from[other.id] = true

		var is_warrior := deme.cultural_trait_ids.has("cul-warrior-expansion")
		if rel.feud_turns == 0 and (kin or not is_warrior or rel.pact_turns > 0):
			bucket.append(option("trade", other.id))
		if rel.feud_turns == 0 and (not is_warrior or kin or rel.pact_turns > 0) and deme.energy_reserves >= 40.0 and other.energy_reserves < float(other.population) * 0.9:
			bucket.append(option("aid", other.id))

		var ta := deme.get_village_tier()
		var tb := other.get_village_tier()
		var both_cities := ta >= 2 and tb >= 2
		var can_unite := (
			(both_cities and deme.urban_hex_ids.size() + other.urban_hex_ids.size() <= EvoTypes.MAX_URBAN_HEXES)
			or (not both_cities and maxi(ta, tb) >= 2)
		)
		if rel.pact_turns >= 3 and rel.proposal_from == "" and can_unite:
			options.append(option("unite", other.id))

		if rel.pact_turns > 0:
			if deme.population >= 35:
				var cohesive_peaceful := vec.social_cohesion >= 0.55 and not deme.cultural_trait_ids.has("cul-warrior-expansion")
				var desperate_or_distrustful := deme.energy_reserves < food_req * 1.1 or rel.trust < 0.0
				var martial_opportunity := deme.cultural_trait_ids.has("cul-warrior-expansion") and rel.pact_turns >= 2 and other.energy_reserves >= 65.0
				var allow_betray := (not cohesive_peaceful or desperate_or_distrustful) and (not kin or desperate_or_distrustful or martial_opportunity)
				if allow_betray:
					options.append(option("betray", other.id))
			continue

		if rel.feud_turns == 0 and rel.pact_turns == 0 and rel.proposal_from == "" and (kin or (rel.trust >= 0.0 and (not is_warrior or rel.trust >= 0.15))):
			bucket.append(option("offer_pact", other.id))

		if rel.truce_turns > 0 or (kin and rel.feud_turns == 0):
			continue
		if deme.population >= 35 and (other.defense_tier < 3 or EvoPayoffs.closest_defender_field(deme, other, state) != null):
			options.append(option("raid", other.id))
		var post_conquest_home := deme.population - int(roundf(float(deme.population) * EvoPayoffs.CONQUEST_TROOP_SHARE))
		if deme.population >= 65 and post_conquest_home >= 25:
			options.append(option("conquer", other.id))
		if rel.proposal_from == "" and other.energy_reserves >= 20.0:
			var odds_n := EvoPayoffs.raid_odds(deme, other, state, false)
			raid_cache[other.id] = odds_n
			if float(odds_n["p_win"]) >= 0.35:
				options.append(option("demand_tribute", other.id))

	for partner_id: String in state.demes.keys():
		if partner_id == deme.id or handled_tribute_from.has(partner_id):
			continue
		if EvoRelations.has_open_proposal(state, partner_id, deme.id, "tribute"):
			var partner: EvoTypes.Deme = state.demes[partner_id]
			if EvoDiplomacyPhase.has_border_crop_contact(deme, partner, state):
				responses.append(option("pay_tribute", partner.id))
				handled_tribute_from[partner.id] = true

	var rivals := p_rivals.duplicate()
	rivals.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool:
		return _salience(deme, a, state) > _salience(deme, b, state)
	)
	for other: EvoTypes.Deme in rivals.slice(0, 2):
		var key := EvoTypes.make_pair_key(deme.id, other.id)
		var rel: EvoTypes.Relation = state.relations[key] if state.relations.has(key) else EvoTypes.Relation.new()
		if rel.pact_turns > 0 or rel.truce_turns > 0 or (other.lineage_id == deme.lineage_id and rel.feud_turns == 0):
			continue
		if deme.population >= 35:
			options.append(option("raid", other.id))
		if rel.proposal_from == "" and other.energy_reserves >= 20.0:
			var odds_r := EvoPayoffs.raid_odds(deme, other, state, false)
			raid_cache[other.id] = odds_r
			if float(odds_r["p_win"]) >= 0.35:
				options.append(option("demand_tribute", other.id))

	return (responses + options + kin_secondary).slice(0, MAX_OPTIONS)
