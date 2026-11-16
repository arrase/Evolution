class_name EvoActionMenu
extends RefCounted

## Feasible, targeted actions for a settlement this turn.

const MAX_NEIGHBORS := 5
const MAX_SETTLE_OPTIONS := 3
const MAX_OPTIONS := 18
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


static func _reachable_deme_hops(a: EvoTypes.Deme, state: EvoTypes.WorldState, max_hops: int = 2) -> Dictionary:
	var mobility := EvoPayoffs.vector(a, state).spatial_mobility
	var visited: Dictionary = {}
	var dist_by_hex: Dictionary = {}
	var deme_hops: Dictionary = {}
	var queue: Array[String] = []
	for hid in a.urban_hex_ids:
		visited[hid] = true
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
			if visited.has(nid):
				continue
			visited[nid] = true
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if not is_passable_for(ncell, mobility):
				continue
			for oid in ncell.deme_ids:
				if oid != a.id and not deme_hops.has(oid):
					deme_hops[oid] = cur_d + 1
			if cur_d + 1 < max_hops and (ncell.deme_ids.is_empty() or _is_friendly_deme(a, ncell.deme_ids[0], state)):
				dist_by_hex[nid] = cur_d + 1
				queue.append(nid)
	return deme_hops


static func passable_hop_distance(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState, max_hops: int = 2) -> int:
	if a.id == b.id:
		return 0
	var hops := _reachable_deme_hops(a, state, max_hops)
	return int(hops[b.id]) if hops.has(b.id) else 999


static func has_territorial_contact(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> bool:
	if a.id == b.id:
		return false
	var a_fields: Array[EvoTypes.HexCell] = []
	for nid in EvoTypes.urban_perimeter_hex_ids(a, state):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if ncell.owner_deme_id == b.id:
			return true
		if ncell.owner_deme_id == a.id:
			a_fields.append(ncell)
	for nid in EvoTypes.urban_perimeter_hex_ids(b, state):
		if (state.cells[nid] as EvoTypes.HexCell).owner_deme_id == a.id:
			return true
	for fc in a_fields:
		for fnid in HexMath.get_neighbor_ids(fc.q, fc.r, state.cells):
			if (state.cells[fnid] as EvoTypes.HexCell).owner_deme_id == b.id:
				return true
	return false


static func has_social_contact(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> bool:
	return a.id != b.id and (passable_hop_distance(a, b, state, 1) <= 1 or has_territorial_contact(a, b, state))


static func can_reach_for_conquest(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> bool:
	return has_social_contact(a, b, state) and passable_hop_distance(a, b, state, 2) <= 2


static func contact_demes(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.Deme]:
	var contact_ids: Dictionary = _reachable_deme_hops(deme, state, 1)
	for nid in EvoTypes.urban_perimeter_hex_ids(deme, state):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if ncell.owner_deme_id != "" and ncell.owner_deme_id != deme.id:
			contact_ids[ncell.owner_deme_id] = true
		if ncell.owner_deme_id == deme.id:
			for fnid in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
				var fcell: EvoTypes.HexCell = state.cells[fnid]
				if fcell.owner_deme_id != "" and fcell.owner_deme_id != deme.id:
					contact_ids[fcell.owner_deme_id] = true
				for oid in fcell.deme_ids:
					if oid != deme.id:
						contact_ids[oid] = true
	var result: Array[EvoTypes.Deme] = []
	for oid: String in contact_ids.keys():
		if state.demes.has(oid):
			var other: EvoTypes.Deme = state.demes[oid]
			if other.population > 0:
				result.append(other)
	return result


static func sorted_contact_demes(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[EvoTypes.Deme]:
	var contacts := contact_demes(deme, state)
	contacts.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool:
		var sa := _salience(deme, a, state)
		var sb := _salience(deme, b, state)
		if not is_equal_approx(sa, sb):
			return sa > sb
		return a.id < b.id
	)
	return contacts


static func threat_counts_from(
	deme: EvoTypes.Deme,
	contacts: Array[EvoTypes.Deme],
	state: EvoTypes.WorldState
) -> Vector2i:
	var seen: Dictionary = {deme.id: true}
	var total := 0
	var feuds := 0
	for other in contacts:
		if seen.has(other.id):
			continue
		seen[other.id] = true
		if other.population < 35:
			continue
		var pk := EvoTypes.make_pair_key(deme.id, other.id)
		var rel: EvoTypes.Relation = state.relations[pk] if state.relations.has(pk) else EvoTypes.Relation.new()
		if rel.pact_turns > 0 or rel.truce_turns > 0:
			continue
		if other.lineage_id != deme.lineage_id or rel.trust < 0.15 or rel.feud_turns > 0:
			total += 1
			if rel.feud_turns > 0:
				feuds += 1
	return Vector2i(total, feuds)


static func raid_threat_counts(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Vector2i:
	return threat_counts_from(deme, contact_demes(deme, state), state)


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


static func _adjacent_to_allied_city(cell: EvoTypes.HexCell, deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> bool:
	for nn_id in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
		var nn: EvoTypes.HexCell = state.cells[nn_id]
		for oid in nn.deme_ids:
			if oid != deme.id and state.demes.has(oid):
				var other: EvoTypes.Deme = state.demes[oid]
				if other.get_village_tier() >= 2 and EvoTypes.is_pact_active(state, deme.id, oid):
					return true
	return false


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
		var is_wild := c.owner_deme_id == ""
		var is_own_field := c.owner_deme_id == deme.id and deme.population >= 155
		if c.deme_ids.is_empty() and c.ruin_turns == 0 and (is_wild or is_own_field):
			result.append(c)
			var bonus := _frontier_bridge_bonus_for(c, deme, state, mobility)
			if is_own_field and _adjacent_to_allied_city(c, deme, state):
				bonus += 80.0
			scores[hid] = c.current_resources + bonus

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


static func build_domestic(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[String]:
	var options: Array[String] = ["forage", "intensify"]
	if EvoPayoffs.can_fortify(deme, state.cells[deme.hex_id]):
		options.append("fortify")
	if EvoPayoffs.can_innovate(deme, state):
		options.append("innovate")
	return options


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
	return build_with_targets(deme, state, targets, sorted_contact_demes(deme, state), {})


static func build_with_targets(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	s_targets: Array[EvoTypes.HexCell],
	p_contacts: Array[EvoTypes.Deme],
	raid_cache: Dictionary
) -> Array[Dictionary]:
	var responses: Array[Dictionary] = []
	var options: Array[Dictionary] = [option("none")]
	if deme.population >= EvoPayoffs.settle_min_pop(deme) and deme.energy_reserves >= EvoPayoffs.settle_min_reserves(deme):
		for target: EvoTypes.HexCell in s_targets.slice(0, MAX_SETTLE_OPTIONS):
			options.append(option("settle", target.id))

	var contacts := p_contacts.duplicate()
	contacts.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool:
		var sa := _salience(deme, a, state)
		var sb := _salience(deme, b, state)
		if not is_equal_approx(sa, sb):
			return sa > sb
		return a.id < b.id
	)

	for other: EvoTypes.Deme in state.demes.values():
		if other.id == deme.id or other.population <= 0:
			continue
		var has_pact := EvoRelations.has_open_proposal(state, other.id, deme.id, "pact")
		var has_union := EvoRelations.has_open_proposal(state, other.id, deme.id, "union")
		var has_tribute := EvoRelations.has_open_proposal(state, other.id, deme.id, "tribute")
		if not (has_pact or has_union or has_tribute):
			continue
		if not (has_social_contact(deme, other, state) or has_social_contact(other, deme, state)):
			continue
		if has_pact:
			responses.append(option("accept_pact", other.id))
		if has_union and EvoPayoffs.min_urban_distance(deme, other, state) == 1:
			responses.append(option("accept_union", other.id))
		if has_tribute:
			responses.append(option("pay_tribute", other.id))

	var per_neighbor_opts: Array = []
	for other: EvoTypes.Deme in contacts.slice(0, MAX_NEIGHBORS):
		var key := EvoTypes.make_pair_key(deme.id, other.id)
		var rel: EvoTypes.Relation = state.relations[key] if state.relations.has(key) else EvoTypes.Relation.new()
		var n_opts: Array[Dictionary] = []
		var urban_dist := EvoPayoffs.min_urban_distance(deme, other, state)

		if rel.feud_turns == 0:
			n_opts.append(option("trade", other.id))
			if deme.energy_reserves >= 35.0 and other.energy_reserves < EvoPayoffs.storage_cap(other) * 0.85:
				n_opts.append(option("aid", other.id))

		var ta := deme.get_village_tier()
		var tb := other.get_village_tier()
		var both_cities := ta >= 2 and tb >= 2
		var can_unite := (
			(both_cities and deme.urban_hex_ids.size() + other.urban_hex_ids.size() <= EvoTypes.MAX_URBAN_HEXES)
			or (not both_cities and maxi(ta, tb) >= 2)
		)
		if urban_dist == 1 and rel.pact_turns >= 3 and rel.proposal_from == "" and can_unite:
			n_opts.append(option("unite", other.id))

		if rel.pact_turns > 0:
			if deme.population >= 35:
				n_opts.append(option("betray", other.id))
		else:
			if rel.proposal_from == "":
				n_opts.append(option("offer_pact", other.id))
			if rel.truce_turns == 0:
				if deme.population >= 35 and (other.defense_tier < 3 or EvoPayoffs.closest_defender_field(deme, other, state) != null):
					n_opts.append(option("raid", other.id))
				var post_conquest_home := deme.population - int(roundf(float(deme.population) * EvoPayoffs.CONQUEST_TROOP_SHARE))
				if can_reach_for_conquest(deme, other, state) and deme.population >= 65 and post_conquest_home >= 25:
					n_opts.append(option("conquer", other.id))
				if rel.proposal_from == "" and other.energy_reserves >= 18.0:
					var odds_n := EvoPayoffs.raid_odds(deme, other, state, false)
					raid_cache[other.id] = odds_n
					if float(odds_n["p_win"]) >= 0.28:
						n_opts.append(option("demand_tribute", other.id))

		if not n_opts.is_empty():
			per_neighbor_opts.append(n_opts)

	var max_per_neighbor := 0
	for n_list in per_neighbor_opts:
		max_per_neighbor = maxi(max_per_neighbor, (n_list as Array[Dictionary]).size())
	for pass_idx in range(max_per_neighbor):
		for n_list in per_neighbor_opts:
			var n_opts: Array[Dictionary] = n_list
			if pass_idx < n_opts.size():
				options.append(n_opts[pass_idx])

	var combined: Array[Dictionary] = []
	combined.append_array(responses)
	combined.append_array(options)
	if combined.size() > MAX_OPTIONS:
		combined.resize(MAX_OPTIONS)
	return combined
