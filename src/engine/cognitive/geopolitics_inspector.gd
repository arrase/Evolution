class_name EvoGeopoliticsInspector
extends RefCounted


static func _compute_neighbor_state_hash(cell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> int:
	if cell == null or state == null:
		return 0
	var h: int = 17
	h = ((h * 31) + cell.biome.hash()) & 0x7FFFFFFF
	h = ((h * 31) + int(cell.current_resources)) & 0x7FFFFFFF
	h = ((h * 31) + int(cell.carrying_capacity)) & 0x7FFFFFFF
	h = ((h * 31) + int(roundf(cell.altitude * 100.0))) & 0x7FFFFFFF
	for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		h = ((h * 31) + ncell.biome.hash()) & 0x7FFFFFFF
		h = ((h * 31) + int(ncell.current_resources)) & 0x7FFFFFFF
		h = ((h * 31) + int(roundf(ncell.altitude * 100.0))) & 0x7FFFFFFF
		h = ((h * 31) + ncell.land_use.hash()) & 0x7FFFFFFF
		h = ((h * 31) + ncell.owner_deme_id.hash()) & 0x7FFFFFFF
		for oid in ncell.deme_ids:
			if state.demes.has(oid):
				var od: EvoTypes.Deme = state.demes[oid]
				h = ((h * 31) + od.id.hash()) & 0x7FFFFFFF
				h = ((h * 31) + od.population) & 0x7FFFFFFF
				h = ((h * 31) + int(od.energy_reserves)) & 0x7FFFFFFF
				h = ((h * 31) + od.defense_tier) & 0x7FFFFFFF
				h = ((h * 31) + od.walled_union_id.hash()) & 0x7FFFFFFF
				h = ((h * 31) + od.last_dominant_decision_id.hash()) & 0x7FFFFFFF
		if ncell.owner_deme_id != "":
			for n2id in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
				if n2id == cell.id:
					continue
				var n2cell: EvoTypes.HexCell = state.cells[n2id]
				h = ((h * 31) + n2cell.land_use.hash()) & 0x7FFFFFFF
				h = ((h * 31) + n2cell.owner_deme_id.hash()) & 0x7FFFFFFF
				h = ((h * 31) + n2cell.deme_ids.size()) & 0x7FFFFFFF
	return h


static func build_deme_memory_summary(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	active_vendettas: int = 0,
	nearby_horde_threat: bool = false
) -> String:
	var mem_tokens: Array[String] = []
	if state != null and not state.chronicle.is_empty():
		var min_gen := state.generation - 6
		var idx := state.chronicle.size() - 1
		while idx >= 0 and mem_tokens.size() < 3:
			var entry: EvoTypes.ChronicleEntry = state.chronicle[idx]
			if entry.generation < min_gen:
				break
			if entry.deme_id == deme.id or entry.id.contains(deme.id) or entry.hex_id == deme.hex_id:
				var et := entry.event_type
				var tok := ""
				if et == "raid":
					tok = "raided@G%d" % entry.generation
				elif et in ["war", "betrayal", "pact", "fortify", "merge", "tribute", "siege", "epidemic"]:
					tok = "%s@G%d" % [et, entry.generation]
				if tok != "" and not mem_tokens.has(tok):
					mem_tokens.append(tok)
			idx -= 1
	if active_vendettas > 0:
		mem_tokens.append("vendettas=%d" % active_vendettas)
	if nearby_horde_threat:
		mem_tokens.append("horde_nearby")
	return "; ".join(mem_tokens) if not mem_tokens.is_empty() else "quiet"


static func inspect_geopolitical_context(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var has_pacts: bool = state != null and not state.active_pacts.is_empty()
	var pacts_hash: int = state.active_pacts.hash() if has_pacts else 0
	var n_hash := _compute_neighbor_state_hash(cell, state)
	var cache_key := "%d|%s|%s|%d|%d|%d|%d|%d|%d|%d|%.1f|%.2f|%s|%d" % [
		state.generation if state != null else -1,
		state.season if state != null else "",
		cell.id if cell != null else "",
		pacts_hash,
		state.chronicle.size() if state != null else 0,
		state.demes.size() if state != null else 0,
		cell.deme_ids.size() if cell != null else 0,
		deme.population,
		deme.defense_tier,
		deme.merged_count,
		deme.energy_reserves,
		deme.salubrity,
		deme.walled_union_id,
		n_hash
	]
	if deme != null and deme.has_meta("geo_ctx_key") and str(deme.get_meta("geo_ctx_key")) == cache_key:
		return deme.get_meta("geo_ctx_val") as Dictionary

	var has_adjacent_rival := false
	var has_hinterland_rival := false
	var has_nearby_2hex_rival := false
	var has_raiding_temptation := false
	var rich_rural_target_count: int = 0
	var has_pact_neighbor := false
	var max_pact_neighbor_pop: int = 0
	var max_rival_pop: int = 0
	var adj_rival_fort: int = 0
	var open_frontier_count: int = 0
	var extended_frontier_count: int = 0
	var has_nearby_deme := false
	var neighbor_has_surplus := false
	var neighbor_is_weaker := false
	var has_active_pact := false
	var active_pact_count: int = 0
	var active_vendettas: int = 0
	var adjacent_rivals_count: int = 0
	var nearby_horde_threat := false
	var neighbor_max_reserves: float = 0.0
	var owned_rural_count: int = 0
	var has_same_tier_ally := false
	var deme_tier := deme.get_village_tier()
	var has_warrior := EvoCatalog.deme_has_trait(deme, "cul-warrior-expansion")
	var has_communal := EvoCatalog.deme_has_trait(deme, "cul-communal-conservation")
	var warrior_betrayal_trigger := false
	var seen_open_frontier: Dictionary = {}
	var seen_ext_frontier: Dictionary = {}
	var seen_adj_rivals: Dictionary = {}
	var seen_raid_targets: Dictionary = {}

	if has_pacts:
		var pacts_key := "%d|%d" % [state.generation, pacts_hash]
		var pact_counts: Dictionary
		var vendetta_counts: Dictionary
		if state.has_meta("pact_counts_key") and str(state.get_meta("pact_counts_key")) == pacts_key and state.has_meta("vendetta_counts_val"):
			pact_counts = state.get_meta("pact_counts_val") as Dictionary
			vendetta_counts = state.get_meta("vendetta_counts_val") as Dictionary
		else:
			pact_counts = {}
			vendetta_counts = {}
			for pk_var in state.active_pacts.keys():
				var p_val := int(state.active_pacts[pk_var])
				if p_val >= 2 or p_val < 0:
					var pk := str(pk_var)
					var parts := pk.split("__")
					if parts.size() == 2 and state.demes.has(parts[0]) and state.demes.has(parts[1]):
						if p_val >= 2:
							pact_counts[parts[0]] = int(pact_counts.get(parts[0], 0)) + 1
							pact_counts[parts[1]] = int(pact_counts.get(parts[1], 0)) + 1
						else:
							vendetta_counts[parts[0]] = int(vendetta_counts.get(parts[0], 0)) + 1
							vendetta_counts[parts[1]] = int(vendetta_counts.get(parts[1], 0)) + 1
			state.set_meta("pact_counts_key", pacts_key)
			state.set_meta("pact_counts_val", pact_counts)
			state.set_meta("vendetta_counts_val", vendetta_counts)
		active_pact_count = int(pact_counts.get(deme.id, 0))
		active_vendettas = int(vendetta_counts.get(deme.id, 0))
		has_active_pact = active_pact_count > 0

	var cell_pop: int = deme.population
	if cell != null and state != null:
		for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			var ncell_passable := ncell.biome != "ocean" and ncell.altitude <= 0.85
			if ncell_passable and ncell.deme_ids.is_empty() and ncell.owner_deme_id == "":
				if not seen_open_frontier.has(nid):
					seen_open_frontier[nid] = true
					open_frontier_count += 1
			if ncell.owner_deme_id == deme.id and ncell.deme_ids.is_empty():
				owned_rural_count += 1
				for nn_id in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
					if nn_id == cell.id:
						continue
					var nn_cell: EvoTypes.HexCell = state.cells[nn_id]
					var nn_passable := nn_cell.biome != "ocean" and nn_cell.altitude <= 0.85
					if nn_passable and nn_cell.deme_ids.is_empty() and nn_cell.owner_deme_id == "":
						if not seen_ext_frontier.has(nn_id):
							seen_ext_frontier[nn_id] = true
							extended_frontier_count += 1
						if not seen_open_frontier.has(nn_id):
							seen_open_frontier[nn_id] = true
							open_frontier_count += 1
					for nn_did in nn_cell.deme_ids:
						if state.demes.has(nn_did):
							var nn_deme: EvoTypes.Deme = state.demes[nn_did]
							if nn_deme.id != deme.id and nn_deme.lineage_id != deme.lineage_id and (not has_pacts or not EvoTypes.is_pact_active(state, deme.id, nn_deme.id)):
								has_hinterland_rival = true
								has_adjacent_rival = true
								if not seen_adj_rivals.has(nn_deme.id):
									seen_adj_rivals[nn_deme.id] = true
									adjacent_rivals_count += 1
								max_rival_pop = maxi(max_rival_pop, nn_deme.population)
								adj_rival_fort = maxi(adj_rival_fort, nn_deme.defense_tier)
								if nn_cell.current_resources > cell.current_resources * 1.15 or nn_deme.energy_reserves > deme.energy_reserves * 1.15:
									neighbor_has_surplus = true
								var nn_eff: float = float(nn_deme.population) * (1.0 + 0.35 * float(nn_deme.defense_tier))
								if nn_eff < float(deme.population) * 0.85 or (nn_deme.energy_reserves < 45.0 and nn_deme.population <= deme.population and nn_deme.defense_tier <= deme.defense_tier):
									neighbor_is_weaker = true
			elif ncell.owner_deme_id == deme.id:
				owned_rural_count += 1
			elif ncell.owner_deme_id != "" and ncell.owner_deme_id != deme.id and ncell.land_use in ["crops", "pasture"] and state.demes.has(ncell.owner_deme_id):
				var owner_d: EvoTypes.Deme = state.demes[ncell.owner_deme_id]
				if owner_d.lineage_id != deme.lineage_id and (not has_pacts or not EvoTypes.is_pact_active(state, deme.id, owner_d.id)):
					if not seen_raid_targets.has(nid):
						seen_raid_targets[nid] = true
						has_raiding_temptation = true
						rich_rural_target_count += 1

			for oid in ncell.deme_ids:
				if state.demes.has(oid):
					var other: EvoTypes.Deme = state.demes[oid]
					if other.id != deme.id:
						has_nearby_deme = true
						neighbor_max_reserves = maxf(neighbor_max_reserves, other.energy_reserves)
						var pact_with_other := has_pacts and EvoTypes.is_pact_active(state, deme.id, other.id)
						if pact_with_other:
							has_pact_neighbor = true
							max_pact_neighbor_pop = maxi(max_pact_neighbor_pop, other.population)
							if has_warrior and not has_communal and (deme.population > int(float(other.population) * 1.15) or state.season == "dry_cold" or deme.energy_reserves < 65.0 or other.energy_reserves > 20.0):
								warrior_betrayal_trigger = true
						if other.get_village_tier() == deme_tier and deme_tier >= 2 and (other.lineage_id == deme.lineage_id or pact_with_other):
							has_same_tier_ally = true
						if other.lineage_id != deme.lineage_id and not pact_with_other:
							has_adjacent_rival = true
							if not seen_adj_rivals.has(other.id):
								seen_adj_rivals[other.id] = true
								adjacent_rivals_count += 1
							max_rival_pop = maxi(max_rival_pop, other.population)
							adj_rival_fort = maxi(adj_rival_fort, other.defense_tier)
							if ncell.current_resources > cell.current_resources * 1.15 or other.energy_reserves > deme.energy_reserves * 1.15:
								neighbor_has_surplus = true
							var other_eff: float = float(other.population) * (1.0 + 0.35 * float(other.defense_tier))
							if other_eff < float(deme.population) * 0.85 or (other.energy_reserves < 45.0 and other.population <= deme.population and other.defense_tier <= deme.defense_tier):
								neighbor_is_weaker = true
							if ncell_passable and other.population >= 55:
								if other.cultural_trait_ids.has("cul-warrior-expansion") or other.id.contains("-w") or other.last_dominant_decision_id == "dec-territorial-dispute":
									nearby_horde_threat = true
			if has_warrior and ncell_passable:
				for n2id in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
					if n2id == cell.id:
						continue
					var n2cell: EvoTypes.HexCell = state.cells[n2id]
					if n2cell.biome == "ocean" or n2cell.altitude > 0.85:
						continue
					if HexMath.hex_distance(cell.q, cell.r, n2cell.q, n2cell.r) == 2:
						if n2cell.owner_deme_id != "" and n2cell.owner_deme_id != deme.id and n2cell.land_use in ["crops", "pasture"] and state.demes.has(n2cell.owner_deme_id):
							var owner2_d: EvoTypes.Deme = state.demes[n2cell.owner_deme_id]
							if owner2_d.lineage_id != deme.lineage_id and (not has_pacts or not EvoTypes.is_pact_active(state, deme.id, owner2_d.id)):
								if not seen_raid_targets.has(n2id):
									seen_raid_targets[n2id] = true
									has_raiding_temptation = true
									rich_rural_target_count += 1
						for o2id in n2cell.deme_ids:
							if state.demes.has(o2id):
								var o2: EvoTypes.Deme = state.demes[o2id]
								if o2.id != deme.id and o2.lineage_id != deme.lineage_id and (not has_pacts or not EvoTypes.is_pact_active(state, deme.id, o2.id)):
									has_nearby_2hex_rival = true
									max_rival_pop = maxi(max_rival_pop, o2.population)
									if o2.population >= 55 and (o2.cultural_trait_ids.has("cul-warrior-expansion") or o2.id.contains("-w") or o2.last_dominant_decision_id == "dec-territorial-dispute"):
										nearby_horde_threat = true

	var memory_digest := build_deme_memory_summary(deme, state, active_vendettas, nearby_horde_threat)
	var adequacy := (cell.current_resources if cell != null else 300.0) / maxf(1.0, float(cell_pop) * 0.85)
	var needs_rural_hinterland := deme_tier >= 3 and owned_rural_count < 2
	var has_betrayal_temptation: bool = warrior_betrayal_trigger or (active_pact_count > 0 and state != null and not has_communal and (state.season == "dry_cold" or deme.energy_reserves < 65.0) and neighbor_max_reserves > deme.energy_reserves * 1.15)

	var res := {
		"has_adjacent_rival": has_adjacent_rival,
		"has_hinterland_rival": has_hinterland_rival,
		"has_nearby_2hex_rival": has_nearby_2hex_rival,
		"has_raiding_temptation": has_raiding_temptation,
		"rich_rural_target_count": rich_rural_target_count,
		"has_pact_neighbor": has_pact_neighbor,
		"max_pact_neighbor_pop": max_pact_neighbor_pop,
		"max_rival_pop": max_rival_pop,
		"adj_rival_fort": adj_rival_fort,
		"open_frontier_count": open_frontier_count,
		"extended_frontier_count": extended_frontier_count,
		"has_nearby_deme": has_nearby_deme,
		"neighbor_has_surplus": neighbor_has_surplus,
		"neighbor_is_weaker": neighbor_is_weaker,
		"has_active_pact": has_active_pact,
		"active_pacts": active_pact_count,
		"active_vendettas": active_vendettas,
		"adjacent_rivals": adjacent_rivals_count,
		"nearby_horde_threat": nearby_horde_threat,
		"memory_digest": memory_digest,
		"neighbor_max_reserves": neighbor_max_reserves,
		"env_adequacy": adequacy,
		"cell_pop": cell_pop,
		"village_tier": deme_tier,
		"owned_rural_count": owned_rural_count,
		"needs_rural_hinterland": needs_rural_hinterland,
		"salubrity": deme.salubrity,
		"in_walled_union": deme.walled_union_id != "",
		"has_same_tier_ally": has_same_tier_ally,
		"has_betrayal_temptation": has_betrayal_temptation
	}
	if deme != null:
		deme.set_meta("geo_ctx_key", cache_key)
		deme.set_meta("geo_ctx_val", res)
	return res


static func _compute_neighbor_migration_score(
	ncell: EvoTypes.HexCell,
	total_pop: int,
	has_warrior: bool,
	rival_cells: Array[EvoTypes.HexCell]
) -> float:
	var score := ncell.current_resources / maxf(10.0, float(total_pop))
	if not has_warrior and not rival_cells.is_empty():
		var dc: int = 99
		for rcell in rival_cells:
			dc = mini(dc, HexMath.hex_distance(ncell.q, ncell.r, rcell.q, rcell.r))
		if dc <= 1:
			score -= 260.0
		elif dc == 2:
			score -= 60.0
		else:
			score += float(mini(dc, 5)) * 35.0
	return score


static func _get_sorted_passable_neighbors(
	deme: EvoTypes.Deme,
	current_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Array[Dictionary]:
	var n_hash := _compute_neighbor_state_hash(current_cell, state)
	var traits_str := "%s|%s" % [",".join(deme.biological_trait_ids), ",".join(deme.cultural_trait_ids)]
	var n_cache_key := "%d|%s|%s|%d" % [
		state.generation if state != null else -1,
		current_cell.id if current_cell != null else "",
		traits_str,
		n_hash
	]
	if deme != null and deme.has_meta("pass_n_key") and str(deme.get_meta("pass_n_key")) == n_cache_key:
		return deme.get_meta("pass_n_val") as Array[Dictionary]

	var mob_t_key := "%s|%d" % [traits_str, state.decisions_catalog.size()]
	var effective_mig_mobility: float
	if deme != null and deme.has_meta("eff_mig_mob_key") and str(deme.get_meta("eff_mig_mob_key")) == mob_t_key:
		effective_mig_mobility = float(deme.get_meta("eff_mig_mob_val"))
	else:
		var base_mobility := EvoHeuristicScorer.compute_baseline_mobility(deme, state)
		var max_migrate_mob: float = 0.0
		for dec_id in state.decisions_catalog.keys():
			var dec: EvoTypes.DecisionDef = state.decisions_catalog[dec_id]
			if dec.archetype == "migrate" and EvoHeuristicScorer.is_decision_eligible(deme, dec, state.traits_catalog):
				max_migrate_mob = maxf(max_migrate_mob, dec.vector.spatial_mobility)
		effective_mig_mobility = minf(1.5, base_mobility + max_migrate_mob)
		if deme != null:
			deme.set_meta("eff_mig_mob_key", mob_t_key)
			deme.set_meta("eff_mig_mob_val", effective_mig_mobility)

	var has_warrior := EvoCatalog.deme_has_trait(deme, "cul-warrior-expansion")
	var candidate_cells: Array[EvoTypes.HexCell] = []
	var seen_cand: Dictionary = {current_cell.id: true}
	var has_extended_cand := false
	for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		seen_cand[nid] = true
		candidate_cells.append(ncell)
		if ncell.owner_deme_id == deme.id and ncell.deme_ids.is_empty():
			for nn_id in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
				if seen_cand.has(nn_id):
					continue
				var nn_cell: EvoTypes.HexCell = state.cells[nn_id]
				if nn_cell.deme_ids.is_empty() and nn_cell.owner_deme_id == "":
					seen_cand[nn_id] = true
					candidate_cells.append(nn_cell)
					has_extended_cand = true

	var rival_cells: Array[EvoTypes.HexCell] = []
	if not has_warrior and has_extended_cand and state != null:
		for did in state.demes.keys():
			var od: EvoTypes.Deme = state.demes[did]
			if od.id != deme.id and od.lineage_id != deme.lineage_id and not EvoTypes.is_pact_active(state, deme.id, od.id) and state.cells.has(od.hex_id):
				rival_cells.append(state.cells[od.hex_id])

	var passable: Array[Dictionary] = []
	for ncell in candidate_cells:
		var is_passable := ncell.biome != "ocean" and ncell.altitude <= 0.85 and (ncell.altitude - 0.50) <= effective_mig_mobility
		if not is_passable:
			continue
		var total_pop: int = 0
		for oid in ncell.deme_ids:
			if state.demes.has(oid):
				total_pop += (state.demes[oid] as EvoTypes.Deme).population
		var score := _compute_neighbor_migration_score(ncell, total_pop, has_warrior, rival_cells)
		passable.append({
			"id": ncell.id,
			"biome": ncell.biome,
			"current_resources": ncell.current_resources,
			"demes_count": ncell.deme_ids.size(),
			"total_population": total_pop,
			"score": score
		})

	for i in range(1, passable.size()):
		var key_item: Dictionary = passable[i]
		var key_score: float = float(key_item["score"])
		var j: int = i - 1
		while j >= 0 and float(passable[j]["score"]) < key_score:
			passable[j + 1] = passable[j]
			j -= 1
		passable[j + 1] = key_item

	if passable.size() > 3:
		var top3 := passable.slice(0, 3)
		var has_occupied := false
		for item in top3:
			if int(item["demes_count"]) > 0:
				has_occupied = true
				break
		if not has_occupied:
			for i in range(3, passable.size()):
				if int(passable[i]["demes_count"]) > 0:
					top3[2] = passable[i]
					if deme != null:
						deme.set_meta("pass_n_key", n_cache_key)
						deme.set_meta("pass_n_val", top3)
					return top3
	if deme != null:
		deme.set_meta("pass_n_key", n_cache_key)
		deme.set_meta("pass_n_val", passable)
	return passable


static func _get_primary_cell_occupant(cell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	if cell == null or state == null or cell.deme_ids.is_empty():
		return null
	return state.demes.get(cell.deme_ids[0]) as EvoTypes.Deme


static func _format_neighbor_occupant_label(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> String:
	if other == null:
		return "empty"
	var rel_tag := "rival"
	if other.lineage_id == deme.lineage_id:
		rel_tag = "kin"
	elif EvoTypes.is_pact_active(state, deme.id, other.id):
		rel_tag = "ally"
	elif EvoTypes.is_vendetta_active(state, deme.id, other.id):
		rel_tag = "vendetta"

	var dom_arch := "forage"
	if state.decisions_catalog.has(other.last_dominant_decision_id):
		dom_arch = (state.decisions_catalog[other.last_dominant_decision_id] as EvoTypes.DecisionDef).archetype
	var posture_tag := "martial" if (other.cultural_trait_ids.has("cul-warrior-expansion") or dom_arch == "dispute") else dom_arch

	var strength_tag := "equal"
	if float(other.population) > float(deme.population) * 1.2:
		strength_tag = "stronger"
	elif float(other.population) < float(deme.population) * 0.8:
		strength_tag = "weaker"

	return "%s:%s:%s:def%d" % [rel_tag, posture_tag, strength_tag, other.defense_tier]


static func _format_neighbor_sig_tag(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	ncell: EvoTypes.HexCell = null
) -> String:
	if other == null:
		if ncell != null and ncell.owner_deme_id != "" and ncell.land_use in ["crops", "pasture"]:
			return "rural_%s_%s" % [ncell.land_use, "own" if ncell.owner_deme_id == deme.id else "other"]
		return "empty"
	var rel_tag := "rival"
	if other.lineage_id == deme.lineage_id:
		rel_tag = "kin"
	elif EvoTypes.is_pact_active(state, deme.id, other.id):
		rel_tag = "ally"
	elif EvoTypes.is_vendetta_active(state, deme.id, other.id):
		rel_tag = "vendetta"
	else:
		var dom_arch := "forage"
		if state.decisions_catalog.has(other.last_dominant_decision_id):
			dom_arch = (state.decisions_catalog[other.last_dominant_decision_id] as EvoTypes.DecisionDef).archetype
		if other.cultural_trait_ids.has("cul-warrior-expansion") or dom_arch == "dispute":
			rel_tag = "rival_martial"
	var strength_tag := "equal"
	if float(other.population) > float(deme.population) * 1.2:
		strength_tag = "stronger"
	elif float(other.population) < float(deme.population) * 0.8:
		strength_tag = "weaker"
	return "%s:%s:def%d" % [rel_tag, strength_tag, other.defense_tier]


static func build_geopolitics_summary(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var geo := inspect_geopolitical_context(deme, cell, state)
	return {
		"active_pacts": int(geo["active_pacts"]),
		"active_vendettas": int(geo.get("active_vendettas", 0)),
		"adjacent_rivals": int(geo["adjacent_rivals"]),
		"village_tier": int(geo.get("village_tier", deme.get_village_tier())),
		"defense_tier": deme.defense_tier,
		"merged_count": deme.merged_count,
		"salubrity": snappedf(float(geo.get("salubrity", deme.salubrity)), 0.01),
		"owned_rural_count": int(geo.get("owned_rural_count", 0)),
		"needs_rural_hinterland": bool(geo.get("needs_rural_hinterland", false)),
		"in_walled_union": bool(geo.get("in_walled_union", deme.walled_union_id != "")),
		"has_same_tier_ally": bool(geo.get("has_same_tier_ally", false)),
		"horde_threat": bool(geo.get("nearby_horde_threat", false)),
		"memory": str(geo.get("memory_digest", "quiet")),
		"neighbor_max_reserves": snappedf(float(geo["neighbor_max_reserves"]), 0.1),
		"env_adequacy": snappedf(float(geo["env_adequacy"]), 0.01)
	}


static func invalidate_state_caches(state: EvoTypes.WorldState) -> void:
	if state == null:
		return
	if state.has_meta("dec_cat_hash"):
		state.remove_meta("dec_cat_hash")
	if state.has_meta("dec_cat_size"):
		state.remove_meta("dec_cat_size")
	if state.has_meta("pact_counts_key"):
		state.remove_meta("pact_counts_key")
	if state.has_meta("pact_counts_val"):
		state.remove_meta("pact_counts_val")
	if state.has_meta("vendetta_counts_val"):
		state.remove_meta("vendetta_counts_val")
	for tid in state.traits_catalog.keys():
		var t: EvoTypes.TraitDef = state.traits_catalog[tid]
		if t.has_meta("compact_str"):
			t.remove_meta("compact_str")
	for did in state.decisions_catalog.keys():
		var d: EvoTypes.DecisionDef = state.decisions_catalog[did]
		if d.has_meta("compact_criterion"):
			d.remove_meta("compact_criterion")
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		for k in ["geo_ctx_key", "pass_n_key", "env_w_key", "traits_sig_key", "base_w_key", "eff_mig_mob_key", "sig_cache_key"]:
			if deme.has_meta(k):
				deme.remove_meta(k)
