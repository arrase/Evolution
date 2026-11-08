class_name EvoDemographyMigration
extends RefCounted


static func is_hex_passable_for_deme(cell: EvoTypes.HexCell, spatial_mobility: float) -> bool:
	return cell.biome != "ocean" and cell.altitude <= 0.85 and (cell.altitude - 0.50) <= spatial_mobility


static func compute_deme_divergence(deme_a: EvoTypes.Deme, deme_b: EvoTypes.Deme) -> float:
	var count_a := deme_a.biological_trait_ids.size() + deme_a.cultural_trait_ids.size()
	var count_b := deme_b.biological_trait_ids.size() + deme_b.cultural_trait_ids.size()
	if count_a == 0 and count_b == 0:
		return 0.0
	var intersection_count: int = 0
	for tid in deme_a.biological_trait_ids:
		if deme_b.biological_trait_ids.has(tid):
			intersection_count += 1
	for tid in deme_a.cultural_trait_ids:
		if deme_b.cultural_trait_ids.has(tid):
			intersection_count += 1
	var union_size := count_a + count_b - intersection_count
	if union_size <= 0:
		return 0.0
	return snappedf(1.0 - float(intersection_count) / float(union_size), 0.0001)


static func _strip_coord_suffix(name_str: String) -> String:
	var open_idx := name_str.rfind(" (")
	if open_idx > 0 and name_str.ends_with(")"):
		var inside := name_str.substr(open_idx + 2, name_str.length() - open_idx - 3)
		if inside.contains(","):
			return name_str.substr(0, open_idx)
	return name_str


static func _strip_migration_suffix(id_str: String) -> String:
	for i in range(1, id_str.length() - 2):
		if id_str.unicode_at(i) == 45: # '-'
			var tag := id_str.unicode_at(i + 1)
			var d := id_str.unicode_at(i + 2)
			if (tag == 109 or tag == 119) and d >= 48 and d <= 57: # 'm' or 'w' followed by '0'..'9'
				return id_str.substr(0, i)
	return id_str


static func _is_connected_to_founder(
	cell: EvoTypes.HexCell,
	founder_hex_id: String,
	mobility: float,
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> bool:
	for oid in cell.deme_ids:
		if oid != deme.id and state.demes.has(oid) and (state.demes[oid] as EvoTypes.Deme).lineage_id == deme.lineage_id:
			return true
	if founder_hex_id != "" and cell.id == founder_hex_id:
		return true
	var visited: Dictionary = {cell.id: 0}
	var queue: Array[String] = [cell.id]
	var head := 0
	while head < queue.size():
		var cur_id := queue[head]
		head += 1
		var cur_dist: int = int(visited[cur_id])
		if cur_dist >= 3:
			continue
		var cur_cell: EvoTypes.HexCell = state.cells[cur_id]
		for nid in HexMath.get_neighbor_ids(cur_cell.q, cur_cell.r, state.cells):
			if visited.has(nid):
				continue
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if not is_hex_passable_for_deme(ncell, mobility):
				continue
			if nid == founder_hex_id:
				return true
			for oid in ncell.deme_ids:
				if oid != deme.id and state.demes.has(oid) and (state.demes[oid] as EvoTypes.Deme).lineage_id == deme.lineage_id:
					return true
			visited[nid] = cur_dist + 1
			queue.append(nid)
	return false


static func _compute_combat_forces(
	attacker: EvoTypes.Deme,
	warband_pop: int,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> Vector2:
	var att_vec := EvoCatalog.compute_deme_vector(attacker, state.traits_catalog)
	var def_vec := EvoCatalog.compute_deme_vector(defender, state.traits_catalog)
	var pact_bonus := EvoEcologyInteraction.compute_pact_defense_bonus(defender, state)
	var p_att_disp := EvoEcologyInteraction.get_archetype_prob(attacker, state.decisions_catalog, "dispute")
	if p_att_disp <= 0.0 and attacker.last_decision_probabilities.has("dec-territorial-dispute"):
		p_att_disp = float(attacker.last_decision_probabilities["dec-territorial-dispute"])

	var att_warrior := 0.45 if attacker.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var att_r_strat := 0.20 if attacker.biological_trait_ids.has("bio-r-strategy") else 0.0
	var def_warrior := 0.35 if defender.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var fort_bonus: float = EvoEcologyInteraction.DEFENSE_TIER_BONUS[clampi(defender.defense_tier, 0, 3)]

	var flank_bonus := 0.0
	if state.cells.has(defender.hex_id):
		var dcell: EvoTypes.HexCell = state.cells[defender.hex_id]
		var nids := HexMath.get_neighbor_ids(dcell.q, dcell.r, state.cells)
		for oid in dcell.deme_ids:
			if state.demes.has(oid):
				var ally_att: EvoTypes.Deme = state.demes[oid]
				if ally_att.id != attacker.id and ally_att.lineage_id == attacker.lineage_id and ally_att.population >= 35:
					flank_bonus = minf(0.85, flank_bonus + 0.28)
		for nid in nids:
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if not ncell.deme_ids.is_empty():
				for oid in ncell.deme_ids:
					if state.demes.has(oid):
						var ally_att: EvoTypes.Deme = state.demes[oid]
						if ally_att.id != attacker.id and ally_att.lineage_id == attacker.lineage_id and ally_att.population >= 35:
							flank_bonus = minf(0.85, flank_bonus + 0.28)

	var att_force := (
		float(warband_pop)
		* (1.0 + 0.55 * maxf(0.0, att_vec.extraction_efficiency) + att_warrior + att_r_strat + flank_bonus)
		* (0.75 + p_att_disp)
	)
	var def_force := (
		float(defender.population)
		* (1.0 + 0.60 * maxf(0.0, def_vec.social_cohesion) + pact_bonus + def_warrior + fort_bonus)
	)
	return Vector2(att_force, def_force)


static func _min_distance_to_rival(
	cell: EvoTypes.HexCell,
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	cache: Dictionary = {}
) -> int:
	var c_key := (cell.id + "|" + deme.lineage_id) if state.active_pacts.is_empty() else (cell.id + "|" + deme.id)
	if cache.has(c_key):
		return int(cache[c_key])
	var min_dist := 999
	var visited_hexes: Dictionary = {}
	for oid in state.demes.keys():
		var other: EvoTypes.Deme = state.demes[oid]
		if other.lineage_id == deme.lineage_id or EvoTypes.is_pact_active(state, deme.id, other.id):
			continue
		if visited_hexes.has(other.hex_id) or not state.cells.has(other.hex_id):
			continue
		visited_hexes[other.hex_id] = true
		var ocell: EvoTypes.HexCell = state.cells[other.hex_id]
		var d := HexMath.hex_distance(cell.q, cell.r, ocell.q, ocell.r)
		if d < min_dist:
			min_dist = d
	cache[c_key] = min_dist
	return min_dist


static func _has_vanguard_closer_to_rival(
	deme: EvoTypes.Deme,
	cur_rival_dist: int,
	state: EvoTypes.WorldState,
	cache: Dictionary = {}
) -> bool:
	for oid in state.demes.keys():
		var other: EvoTypes.Deme = state.demes[oid]
		if other.id == deme.id or other.lineage_id != deme.lineage_id:
			continue
		if other.population < 45 or not state.cells.has(other.hex_id):
			continue
		var ocell: EvoTypes.HexCell = state.cells[other.hex_id]
		if _min_distance_to_rival(ocell, other, state, cache) < cur_rival_dist:
			return true
	return false


static func _clean_deme_pacts_and_lineage(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> void:
	var stale_pacts: Array[String] = []
	for pk_var in state.active_pacts.keys():
		var pk := str(pk_var)
		var sep := "__" if pk.contains("__") else "|"
		var parts := pk.split(sep)
		if parts.size() == 2 and (parts[0] == deme.id or parts[1] == deme.id):
			stale_pacts.append(pk)
	for pk in stale_pacts:
		state.active_pacts.erase(pk)

	var has_relatives := false
	for rem_id in state.demes.keys():
		var rem: EvoTypes.Deme = state.demes[rem_id]
		if rem.lineage_id == deme.lineage_id:
			has_relatives = true
			break
	if not has_relatives and state.lineage_tree.has(deme.lineage_id):
		(state.lineage_tree[deme.lineage_id] as EvoTypes.LineageNode).extinct_generation = state.generation


static func _log_deme_extinction(
	deme: EvoTypes.Deme,
	hex_id: String,
	state: EvoTypes.WorldState,
	lang: String,
	reason: String = "invasion"
) -> void:
	var is_en := lang == "en"
	if not state.recent_extinction_hexes.has(hex_id):
		state.recent_extinction_hexes.append(hex_id)

	var entry := EvoTypes.ChronicleEntry.new()
	if reason in ["submerge", "submerge_brush"]:
		var prefix := "chronicle-submerge-brush" if reason == "submerge_brush" else "chronicle-submerge"
		entry.id = "%s-%d-%s" % [prefix, state.generation, deme.id]
		entry.title = ("%s Submerged" if is_en else "%s Sumergido") % deme.name
		entry.causal_explanation = (
			"%s went extinct when cell (%s) submerged into ocean with no accessible terrestrial refuge." % [deme.name, hex_id]
			if is_en
			else "%s se extinguió cuando la celda (%s) quedó sumergida en el océano sin refugio terrestre accesible." % [deme.name, hex_id]
		)
	else:
		entry.id = "chronicle-extinct-%d-%s" % [state.generation, deme.id]
		entry.title = ("%s Extinct" if is_en else "%s Extinguió") % deme.name
		entry.causal_explanation = (
			"%s fell below minimum viable population (%d) in hex (%s)." % [deme.name, deme.population, hex_id]
			if is_en
			else "%s cayó por debajo de la población mínima viable (%d) en el hexágono (%s)." % [deme.name, deme.population, hex_id]
		)
	entry.generation = state.generation
	entry.event_type = "extinction"
	entry.hex_id = hex_id
	entry.deme_id = deme.id
	entry.lineage_id = deme.lineage_id
	state.chronicle.append(entry)


static func evacuate_or_merge_displaced_deme(
	deme: EvoTypes.Deme,
	origin_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	lang: String,
	reason: String = "invasion",
	pre_fission_pop_by_deme: Dictionary = {},
	effective_vec_by_deme: Dictionary = {}
) -> void:
	origin_cell.deme_ids.erase(deme.id)

	var empty_candidates: Array[EvoTypes.HexCell] = []
	var merge_candidates: Array[EvoTypes.Deme] = []
	for nid in HexMath.get_neighbor_ids(origin_cell.q, origin_cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if ncell.biome == "ocean" or ncell.altitude > 0.85:
			continue
		if ncell.deme_ids.is_empty():
			empty_candidates.append(ncell)
		else:
			var res_id := ncell.get_resident_deme_id()
			var ally: EvoTypes.Deme = state.demes.get(res_id)
			if ally != null and ally.id != deme.id:
				if EvoTypes.is_pact_active(state, deme.id, ally.id) or (ally.lineage_id == deme.lineage_id and compute_deme_divergence(deme, ally) <= 0.35):
					merge_candidates.append(ally)

	if not empty_candidates.is_empty():
		empty_candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
			return a.current_resources > b.current_resources
		)
		var target_cell := empty_candidates[0]
		deme.hex_id = target_cell.id
		deme.defense_tier = 0
		target_cell.set_resident_deme_id(deme.id)
		if reason in ["submerge", "submerge_brush"]:
			deme.energy_reserves = snappedf(deme.energy_reserves * 0.80, 0.01)

		var flow := EvoTypes.HexEdgeFlow.new()
		flow.from_hex_id = origin_cell.id
		flow.to_hex_id = target_cell.id
		flow.flow_type = "migration"
		flow.intensity = 0.65
		flow.from_deme_id = deme.id
		flow.to_deme_id = deme.id
		state.active_flows.append(flow)
		return

	if not merge_candidates.is_empty():
		merge_candidates.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool:
			return a.population > b.population
		)
		var ally := merge_candidates[0]
		var prev_ally_pop := ally.population
		ally.population += deme.population
		if not pre_fission_pop_by_deme.is_empty():
			pre_fission_pop_by_deme[ally.id] = int(pre_fission_pop_by_deme.get(ally.id, prev_ally_pop)) + deme.population
		ally.energy_reserves = minf(280.0, snappedf(ally.energy_reserves + deme.energy_reserves * 0.80, 0.01))
		var traits_changed := false
		if EvoCatalog.deme_has_cultural_capacity(ally, state.traits_catalog):
			for tid in deme.cultural_trait_ids:
				if EvoEcologyInteraction._can_acquire_trait(ally, tid, state.traits_catalog):
					ally.cultural_trait_ids.append(tid)
					traits_changed = true
		if traits_changed:
			if state.lineage_tree.has(ally.lineage_id):
				var lin_node: EvoTypes.LineageNode = state.lineage_tree[ally.lineage_id]
				for tid in ally.cultural_trait_ids:
					if not lin_node.cultural_trait_ids.has(tid):
						lin_node.cultural_trait_ids.append(tid)
			if not effective_vec_by_deme.is_empty():
				effective_vec_by_deme[ally.id] = EvoEcologyInteraction.compute_effective_vector(ally, state)
		ally.merged_count += 1
		if ally.secondary_color == "" and deme.color != "" and deme.color != ally.color:
			ally.secondary_color = deme.color

		var kept_flows: Array[EvoTypes.HexEdgeFlow] = []
		for fl in state.active_flows:
			if fl.to_deme_id == deme.id:
				fl.to_deme_id = ally.id
			if fl.from_deme_id == deme.id:
				fl.from_deme_id = ally.id
			if fl.from_deme_id == fl.to_deme_id and not (fl.flow_type in ["migration", "merge"]):
				continue
			kept_flows.append(fl)
		state.active_flows = kept_flows

		if not state.disused_connections.is_empty():
			var kept_disused: Array[Dictionary] = []
			for dc in state.disused_connections:
				if str(dc["from_deme_id"]) == deme.id:
					dc["from_deme_id"] = ally.id
				if str(dc["to_deme_id"]) == deme.id:
					dc["to_deme_id"] = ally.id
				if str(dc["from_deme_id"]) == str(dc["to_deme_id"]):
					continue
				kept_disused.append(dc)
			state.disused_connections = kept_disused

		var flow := EvoTypes.HexEdgeFlow.new()
		flow.from_hex_id = origin_cell.id
		flow.to_hex_id = ally.hex_id
		flow.flow_type = "merge"
		flow.intensity = 0.75
		flow.from_deme_id = deme.id
		flow.to_deme_id = ally.id
		state.active_flows.append(flow)

		state.demes.erase(deme.id)
		_clean_deme_pacts_and_lineage(deme, state)
		return

	state.demes.erase(deme.id)
	_clean_deme_pacts_and_lineage(deme, state)
	_log_deme_extinction(deme, origin_cell.id, state, lang, reason)


static func _execute_territorial_invasion(
	attacker: EvoTypes.Deme,
	origin_cell: EvoTypes.HexCell,
	target_cell: EvoTypes.HexCell,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String,
	geo_flows: Array[EvoTypes.HexEdgeFlow],
	newly_created_demes: Dictionary,
	initial_pop_by_deme: Dictionary,
	pre_fission_pop_by_deme: Dictionary,
	effective_vec_by_deme: Dictionary
) -> void:
	var original_pop := attacker.population
	var warband_pop := int(round(float(attacker.population) * 0.48))
	attacker.population -= warband_pop

	var forces := _compute_combat_forces(attacker, warband_pop, defender, state)
	var att_force := forces.x
	var def_force := forces.y

	if att_force >= def_force:
		var captured_tier := maxi(0, defender.defense_tier - 1)
		var att_loss := maxi(2, int(round(float(warband_pop) * clampf(0.22 * (def_force / maxf(1.0, att_force)), 0.08, 0.35))))
		var def_loss := maxi(4, int(round(float(defender.population) * clampf(0.35 * (att_force / maxf(1.0, def_force)), 0.20, 0.55))))
		var loot := roundf(defender.energy_reserves * 0.38)
		defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - loot, 0.01))
		defender.population = maxi(0, defender.population - def_loss)
		defender.defense_tier = 0
		target_cell.deme_ids.erase(defender.id)

		var energy_fraction := attacker.energy_reserves * (float(warband_pop) / float(maxi(1, original_pop)))
		attacker.energy_reserves = maxf(0.0, snappedf(attacker.energy_reserves - energy_fraction, 0.01))
		var warband_energy := snappedf(energy_fraction * 0.85 + loot, 0.01)
		var surviving_warband := maxi(10, warband_pop - att_loss)

		if defender.population >= 10:
			evacuate_or_merge_displaced_deme(defender, target_cell, state, lang, "invasion", pre_fission_pop_by_deme, effective_vec_by_deme)
			if state.demes.has(defender.id):
				pre_fission_pop_by_deme[defender.id] = defender.population
				state.active_pacts[EvoTypes.make_pair_key(attacker.id, defender.id)] = -3
			else:
				pre_fission_pop_by_deme.erase(defender.id)
		else:
			pre_fission_pop_by_deme.erase(defender.id)
			state.demes.erase(defender.id)
			_clean_deme_pacts_and_lineage(defender, state)
			_log_deme_extinction(defender, target_cell.id, state, lang, "invasion")

		var base_id := _strip_migration_suffix(attacker.id)
		var warband_id := "%s-w%d" % [base_id, state.generation]
		var dup_idx := 2
		while state.demes.has(warband_id):
			warband_id = "%s-w%d-%d" % [base_id, state.generation, dup_idx]
			dup_idx += 1
		var base_name := _strip_coord_suffix(attacker.name)
		var warband_name := ("%s (%s)" % [base_name, target_cell.id]).substr(0, 60)

		var warband := EvoTypes.Deme.new()
		warband.id = warband_id
		warband.name = warband_name
		warband.lineage_id = attacker.lineage_id
		warband.strategy_id = attacker.strategy_id
		warband.color = attacker.color
		warband.hex_id = target_cell.id
		warband.population = surviving_warband
		warband.energy_reserves = warband_energy
		warband.last_energy_delta = 0.0
		warband.biological_trait_ids = attacker.biological_trait_ids.duplicate()
		warband.cultural_trait_ids = attacker.cultural_trait_ids.duplicate()
		warband.baldwin_counters = {}
		warband.innovation_counter = 0.0
		warband.isolation_turns = 0
		warband.defense_tier = captured_tier
		warband.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(warband_id)
		warband.last_confidence = attacker.last_confidence
		warband.last_decision_probabilities = attacker.last_decision_probabilities.duplicate()
		warband.last_dominant_decision_id = attacker.last_dominant_decision_id
		warband.last_justification = attacker.last_justification
		warband.set_meta("_fission_gen", state.generation)

		state.demes[warband_id] = warband
		newly_created_demes[warband_id] = true
		target_cell.set_resident_deme_id(warband_id)
		initial_pop_by_deme[warband_id] = surviving_warband
		pre_fission_pop_by_deme[warband_id] = surviving_warband
		effective_vec_by_deme[warband_id] = effective_vec_by_deme[attacker.id]

		var flow := EvoTypes.HexEdgeFlow.new()
		flow.from_hex_id = origin_cell.id
		flow.to_hex_id = target_cell.id
		flow.flow_type = "war"
		flow.intensity = 1.0
		flow.from_deme_id = attacker.id
		flow.to_deme_id = warband_id
		state.active_flows.append(flow)
		geo_flows.append(flow)

		var params := {
			"attacker": attacker.name,
			"defender": defender.name,
			"hex": target_cell.id,
			"casualties": str(att_loss + def_loss),
			"loot": str(int(round(loot)))
		}
		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-war-win-%d-%s-%s" % [state.generation, attacker.id, defender.id]
		entry.generation = state.generation
		entry.event_type = "war"
		entry.title = EvoI18n.t(lang, "chronicle_war_victory_title", params)
		entry.causal_explanation = EvoI18n.t(lang, "chronicle_war_victory_desc", params)
		entry.hex_id = target_cell.id
		entry.deme_id = warband_id
		entry.lineage_id = attacker.lineage_id
		state.chronicle.append(entry)
	else:
		var def_tier := clampi(defender.defense_tier, 0, 3)
		var loss_rate := 0.28 + 0.06 * float(def_tier)
		var att_loss := maxi(4, int(round(float(warband_pop) * loss_rate)))
		var def_loss := maxi(2, int(round(float(defender.population) * (0.16 - 0.02 * float(def_tier)))))
		var survivors := maxi(0, warband_pop - att_loss)
		attacker.population += survivors
		attacker.energy_reserves = maxf(0.0, snappedf(attacker.energy_reserves - 15.0, 0.01))
		pre_fission_pop_by_deme[attacker.id] = attacker.population
		defender.population = maxi(10, defender.population - def_loss)
		pre_fission_pop_by_deme[defender.id] = defender.population

		for pk in state.active_pacts.keys():
			var sep := "__" if str(pk).contains("__") else "|"
			var parts := str(pk).split(sep)
			if parts.size() == 2 and (parts[0] == defender.id or parts[1] == defender.id):
				if int(state.active_pacts[pk]) > 0:
					state.active_pacts[pk] = int(state.active_pacts[pk]) + 1

		var ad_pk := EvoTypes.make_pair_key(attacker.id, defender.id)
		if int(state.active_pacts.get(ad_pk, 0)) <= 0:
			state.active_pacts[ad_pk] = mini(-2, int(state.active_pacts.get(ad_pk, 0)))

		if def_tier >= 1:
			var is_isolated_defender := defender.merged_count == 0 and EvoEcologyInteraction.compute_pact_defense_bonus(defender, state) <= 0.0
			if att_force >= def_force * 0.80:
				if defender.energy_reserves >= 10.0 and not is_isolated_defender:
					defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - 10.0, 0.01))
				else:
					defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - 10.0, 0.01))
					defender.defense_tier = maxi(0, defender.defense_tier - 1)
			elif is_isolated_defender and att_force >= def_force * 0.45:
				defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - 10.0, 0.01))
				defender.defense_tier = maxi(0, defender.defense_tier - 1)

		var siege_flow := EvoTypes.HexEdgeFlow.new()
		siege_flow.from_hex_id = origin_cell.id
		siege_flow.to_hex_id = target_cell.id
		siege_flow.flow_type = "siege"
		siege_flow.intensity = 0.90
		siege_flow.from_deme_id = attacker.id
		siege_flow.to_deme_id = defender.id
		state.active_flows.append(siege_flow)
		geo_flows.append(siege_flow)

		var siege_params := {
			"defender": defender.name,
			"attacker": attacker.name,
			"hex": target_cell.id,
			"casualties": str(att_loss + def_loss)
		}
		var siege_entry := EvoTypes.ChronicleEntry.new()
		siege_entry.id = "chronicle-siege-%d-%s-%s" % [state.generation, defender.id, attacker.id]
		siege_entry.generation = state.generation
		siege_entry.event_type = "siege"
		siege_entry.title = EvoI18n.t(lang, "chronicle_siege_title", siege_params)
		siege_entry.causal_explanation = EvoI18n.t(lang, "chronicle_siege_desc", siege_params)
		siege_entry.hex_id = target_cell.id
		siege_entry.deme_id = defender.id
		siege_entry.lineage_id = defender.lineage_id
		state.chronicle.append(siege_entry)

		var params := {
			"defender": defender.name,
			"attacker": attacker.name,
			"hex": target_cell.id,
			"casualties": str(att_loss + def_loss)
		}
		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-war-repel-%d-%s-%s" % [state.generation, defender.id, attacker.id]
		entry.generation = state.generation
		entry.event_type = "war"
		entry.title = EvoI18n.t(lang, "chronicle_war_repelled_title", params)
		entry.causal_explanation = EvoI18n.t(lang, "chronicle_war_repelled_desc", params)
		entry.hex_id = target_cell.id
		entry.deme_id = defender.id
		entry.lineage_id = defender.lineage_id
		state.chronicle.append(entry)

		if attacker.population < 10:
			origin_cell.deme_ids.erase(attacker.id)
			pre_fission_pop_by_deme.erase(attacker.id)
			state.demes.erase(attacker.id)
			_clean_deme_pacts_and_lineage(attacker, state)
			_log_deme_extinction(attacker, origin_cell.id, state, lang, "invasion")


static func run_demography_and_migration_phase(
	state: EvoTypes.WorldState,
	lang: String,
	initial_pop_by_deme: Dictionary,
	effective_vec_by_deme: Dictionary,
	hawk_penalty_by_deme: Dictionary,
	extracted_energy_by_deme: Dictionary,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow] = []
) -> void:
	var is_en := lang == "en"
	var had_lineage_contact: Dictionary = {}
	var newly_created_demes: Dictionary = {}
	var pre_fission_pop_by_deme: Dictionary = {}

	var cell_pop_by_hex: Dictionary = {}
	for cid in state.cells.keys():
		var c: EvoTypes.HexCell = state.cells[cid]
		var c_pop: int = 0
		for r_id in c.deme_ids:
			if state.demes.has(r_id):
				c_pop += (state.demes[r_id] as EvoTypes.Deme).population
		cell_pop_by_hex[cid] = c_pop

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(deme.hex_id):
			continue
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[deme.id]
		var hawk_mult: float = float(hawk_penalty_by_deme[deme.id]) if hawk_penalty_by_deme.has(deme.id) else 1.0
		var extracted: float = float(extracted_energy_by_deme[deme.id]) if extracted_energy_by_deme.has(deme.id) else 0.0

		var metabolic_cost := (
			float(deme.population)
			* 0.42
			* (
				1.0
				+ 0.55 * v_eff.metabolic_cost
				+ 0.20 * absf(cell.temperature) * maxf(0.0, 1.0 - maxf(0.0, v_eff.spatial_mobility))
			)
			* hawk_mult
		)

		var fort_upkeep: float = [0.0, 1.5, 3.0, 5.0][clampi(deme.defense_tier, 0, 3)]
		var delta_e := extracted - metabolic_cost - fort_upkeep
		var prev_reserves := deme.energy_reserves
		var reserve_draw := minf(-delta_e, prev_reserves * 0.50) if (delta_e < 0.0 and prev_reserves > 0.30 * float(deme.population)) else 0.0
		var effective_delta_e := delta_e + reserve_draw

		deme.last_energy_delta = snappedf(delta_e, 0.01)
		deme.energy_reserves = maxf(0.0, snappedf(prev_reserves + delta_e, 0.01))
		if deme.energy_reserves <= 0.0 and delta_e < -8.0 and deme.defense_tier > 0:
			deme.defense_tier = maxi(0, deme.defense_tier - 1)

		var raw_growth := (effective_delta_e / maxf(10.0, float(deme.population))) * 0.45
		if deme.biological_trait_ids.has("bio-r-strategy") and raw_growth > 0.0:
			var cell_pop: int = int(cell_pop_by_hex[cell.id])
			var crowding := float(cell_pop) / maxf(10.0, cell.carrying_capacity)
			if crowding < 0.55:
				raw_growth *= 1.28
			elif crowding >= 0.65:
				raw_growth *= 1.05
			else:
				raw_growth *= 1.16
		var growth_rate := clampf(raw_growth, -0.45, 0.35)
		if deme.biological_trait_ids.has("bio-k-strategy"):
			growth_rate = clampf(growth_rate * 0.88, -0.45, 0.35)

		var next_pop := int(roundf(float(deme.population) * (1.0 + growth_rate)))
		deme.population = (deme.population - 1) if (effective_delta_e < 0.0 and next_pop >= deme.population) else next_pop
		pre_fission_pop_by_deme[deme.id] = deme.population

		var p_explore: float = 0.0
		var p_cooperate: float = 0.0
		var p_migrate_d: float = 0.0
		var p_dispute_d: float = 0.0
		for dec_id in deme.last_decision_probabilities.keys():
			var prob := float(deme.last_decision_probabilities[dec_id])
			var arch := (state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).archetype if state.decisions_catalog.has(dec_id) else ""
			if arch != "forage" and prob >= 0.35:
				var cur_c: int = int(deme.baldwin_counters[dec_id]) if deme.baldwin_counters.has(dec_id) else 0
				deme.baldwin_counters[dec_id] = cur_c + 1
			if arch == "innovate":
				p_explore += prob
			elif arch == "cooperate":
				p_cooperate += prob
			elif arch == "migrate":
				p_migrate_d += prob
			elif arch == "dispute":
				p_dispute_d += prob
		deme.set_meta("_turn_p_mig", p_migrate_d)
		deme.set_meta("_turn_p_disp", p_dispute_d)

		if EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog):
			var p_innovate := p_explore + 0.35 * p_cooperate
			deme.innovation_counter = minf(2.0, snappedf(deme.innovation_counter + p_innovate * 0.45, 0.0001))

	var pre_fission_ids := state.demes.keys()
	var rival_dist_cache: Dictionary = {}
	for did in pre_fission_ids:
		if not state.demes.has(did):
			continue
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.population < 20 or not state.cells.has(deme.hex_id):
			continue
		var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[deme.id]
		var p_migrate := float(deme.get_meta("_turn_p_mig", 0.0))
		var p_dispute := float(deme.get_meta("_turn_p_disp", 0.0))
		var extracted := float(extracted_energy_by_deme.get(deme.id, 0.0))
		var needed := maxf(1.0, float(deme.population) * 0.42 * (1.0 + 0.55 * v_eff.metabolic_cost))
		var adequacy := extracted / needed
		var k_ratio := current_cell.carrying_capacity / maxf(10.0, current_cell.carrying_capacity_max)

		var has_martial_profile := (
			deme.cultural_trait_ids.has("cul-warrior-expansion")
			or (p_dispute >= 0.24 and v_eff.extraction_efficiency > 0.25 and v_eff.social_cohesion <= 0.15)
		)
		var has_martial_pressure := (
			adequacy < 1.25
			or state.season == "dry_cold"
			or deme.energy_reserves < 70.0
			or k_ratio < 0.85
			or deme.population >= 78
		)
		var is_martial_expander := has_martial_profile and has_martial_pressure
		var martial_trigger := (
			is_martial_expander
			and deme.population >= 55
			and deme.energy_reserves >= 40.0
			and (
				p_migrate + p_dispute >= 0.30
				or (deme.cultural_trait_ids.has("cul-warrior-expansion") and deme.population >= 75)
			)
		)

		var neighbor_ids := HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells)

		if martial_trigger:
			var warband_pop := int(round(float(deme.population) * 0.48))
			var best_target_cell: EvoTypes.HexCell = null
			var best_defender: EvoTypes.Deme = null
			var best_ratio := -1.0

			for nid in neighbor_ids:
				var ncell: EvoTypes.HexCell = state.cells[nid]
				if ncell.biome == "ocean" or ncell.altitude > 0.85:
					continue
				for oid in ncell.deme_ids:
					if not state.demes.has(oid):
						continue
					var other: EvoTypes.Deme = state.demes[oid]
					if other.lineage_id == deme.lineage_id or EvoTypes.is_pact_active(state, deme.id, other.id):
						continue
					var already_raided := false
					for fl in state.active_flows:
						if fl.flow_type in ["raid", "tribute"] and fl.from_deme_id == deme.id and fl.to_deme_id == other.id:
							already_raided = true
							break
					if already_raided:
						continue
					var forces := _compute_combat_forces(deme, warband_pop, other, state)
					if (
						forces.x >= forces.y * 0.82
						or (adequacy < 0.75 and forces.x >= forces.y * 0.68)
						or (deme.cultural_trait_ids.has("cul-warrior-expansion") and forces.x >= forces.y * 0.45)
					):
						var ratio := forces.x / maxf(1.0, forces.y)
						if ratio > best_ratio:
							best_ratio = ratio
							best_target_cell = ncell
							best_defender = other

			if best_target_cell != null and best_defender != null:
				_execute_territorial_invasion(
					deme,
					current_cell,
					best_target_cell,
					best_defender,
					state,
					lang,
					turn_geopolitical_flows,
					newly_created_demes,
					initial_pop_by_deme,
					pre_fission_pop_by_deme,
					effective_vec_by_deme
				)
				rival_dist_cache.clear()
				continue

		var is_emergency := (
			current_cell.current_resources < float(deme.population) * 0.20
			and deme.energy_reserves < float(deme.population) * 0.35
		)
		var has_intentional_migration := (
			martial_trigger
			or deme.last_dominant_decision_id == "dec-selective-migration"
			or p_migrate >= 0.15
			or current_cell.biome == "coastal_shallows"
			or is_emergency
		)
		var eff_p_migrate := p_migrate
		if martial_trigger:
			eff_p_migrate = maxf(eff_p_migrate, 0.95)
		elif is_emergency:
			eff_p_migrate = maxf(eff_p_migrate, 0.35)
		elif current_cell.biome == "coastal_shallows" or deme.last_dominant_decision_id == "dec-selective-migration":
			eff_p_migrate = maxf(eff_p_migrate, 0.25)
		var migrants := int(floor(float(deme.population) * eff_p_migrate * 0.45))
		var min_pop_for_forced_fission := 25 if (is_emergency or current_cell.biome == "coastal_shallows") else 55
		if has_intentional_migration and deme.population >= min_pop_for_forced_fission and migrants < 10:
			migrants = 10

		if not has_intentional_migration or migrants < 10 or (deme.population - migrants) < 10:
			continue

		var cur_rival_dist := _min_distance_to_rival(current_cell, deme, state, rival_dist_cache) if is_martial_expander else 999
		var is_pure_martial_march := (
			martial_trigger
			and deme.last_dominant_decision_id != "dec-selective-migration"
			and current_cell.biome != "coastal_shallows"
			and not is_emergency
		)
		if is_pure_martial_march and _has_vanguard_closer_to_rival(deme, cur_rival_dist, state, rival_dist_cache):
			continue
		var v_eff_mobility := v_eff.spatial_mobility
		var mig_mobility := clampf(v_eff_mobility + p_migrate * 0.25, -1.5, 1.5)
		if is_emergency or current_cell.biome == "coastal_shallows":
			mig_mobility = maxf(mig_mobility, 0.35)
		if is_martial_expander:
			mig_mobility = maxf(mig_mobility, 0.35)
		var candidates: Array[EvoTypes.HexCell] = []
		var reinforce_candidates: Array[EvoTypes.HexCell] = []
		for nid in neighbor_ids:
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if not is_hex_passable_for_deme(ncell, mig_mobility):
				continue
			var n_dist := _min_distance_to_rival(ncell, deme, state, rival_dist_cache) if is_martial_expander else 999
			if is_pure_martial_march and n_dist >= cur_rival_dist:
				continue
			if ncell.deme_ids.is_empty():
				candidates.append(ncell)
			else:
				var res_id := ncell.get_resident_deme_id()
				if state.demes.has(res_id):
					var other: EvoTypes.Deme = state.demes[res_id]
					if other.lineage_id == deme.lineage_id and compute_deme_divergence(deme, other) <= 0.25 and other.population < 75:
						reinforce_candidates.append(ncell)

		if candidates.is_empty() and reinforce_candidates.is_empty():
			continue

		var is_reinforcing := candidates.is_empty()
		var pool := reinforce_candidates if is_reinforcing else candidates
		var target_cell: EvoTypes.HexCell = pool[0]
		if pool.size() > 1:
			var best_score := -INF
			for cand in pool:
				var sc := cand.current_resources / float(cand.deme_ids.size() + 1)
				if is_martial_expander and cur_rival_dist < 999:
					var dc := _min_distance_to_rival(cand, deme, state, rival_dist_cache)
					if dc < cur_rival_dist:
						sc += 45.0 + float(maxi(0, 10 - dc)) * 8.0
				if sc > best_score:
					best_score = sc
					target_cell = cand
		var original_pop := deme.population
		var energy_fraction := deme.energy_reserves * (float(migrants) / float(original_pop))
		var transferred_energy := snappedf(energy_fraction * 0.85, 0.01)

		deme.population -= migrants
		deme.energy_reserves = maxf(0.0, snappedf(deme.energy_reserves - energy_fraction, 0.01))

		if is_reinforcing:
			var other_id := target_cell.get_resident_deme_id()
			var other: EvoTypes.Deme = state.demes[other_id]
			other.population += migrants
			other.energy_reserves = minf(280.0, snappedf(other.energy_reserves + transferred_energy, 0.01))
			pre_fission_pop_by_deme[other.id] = other.population
			had_lineage_contact[deme.id] = true
			had_lineage_contact[other.id] = true

			var r_flow := EvoTypes.HexEdgeFlow.new()
			r_flow.from_hex_id = current_cell.id
			r_flow.to_hex_id = target_cell.id
			r_flow.flow_type = "merge"
			r_flow.intensity = snappedf(clampf(float(migrants) / float(original_pop), 0.05, 1.0), 0.01)
			r_flow.from_deme_id = deme.id
			r_flow.to_deme_id = other.id
			state.active_flows.append(r_flow)
			continue

		var root_id := _strip_migration_suffix(deme.id)
		var daughter_id := "%s-m%d-%d_%d" % [root_id, state.generation, target_cell.q, target_cell.r]
		var dup_idx := 2
		while state.demes.has(daughter_id):
			daughter_id = "%s-m%d-%d_%d-%d" % [root_id, state.generation, target_cell.q, target_cell.r, dup_idx]
			dup_idx += 1
		var base_name := _strip_coord_suffix(deme.name)
		var daughter_name := ("%s (%s)" % [base_name, target_cell.id]).substr(0, 60)

		var daughter := EvoTypes.Deme.new()
		daughter.id = daughter_id
		daughter.name = daughter_name
		daughter.lineage_id = deme.lineage_id
		daughter.strategy_id = deme.strategy_id
		daughter.color = deme.color
		daughter.hex_id = target_cell.id
		daughter.population = migrants
		daughter.energy_reserves = transferred_energy
		daughter.last_energy_delta = 0.0
		daughter.biological_trait_ids = deme.biological_trait_ids.duplicate()
		daughter.cultural_trait_ids = deme.cultural_trait_ids.duplicate()
		daughter.baldwin_counters = {}
		daughter.innovation_counter = 0.0
		daughter.isolation_turns = 0
		daughter.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(daughter.id)
		daughter.last_confidence = deme.last_confidence
		daughter.last_decision_probabilities = deme.last_decision_probabilities.duplicate()
		daughter.last_dominant_decision_id = deme.last_dominant_decision_id
		daughter.last_justification = deme.last_justification
		daughter.set_meta("_fission_gen", state.generation)
		if deme.has_meta("base_w_key"):
			daughter.set_meta("base_w_key", deme.get_meta("base_w_key"))
			daughter.set_meta("base_w_probs", deme.get_meta("base_w_probs"))
			daughter.set_meta("base_w_elig", deme.get_meta("base_w_elig"))
			daughter.set_meta("base_w_vec", deme.get_meta("base_w_vec"))

		state.demes[daughter_id] = daughter
		newly_created_demes[daughter_id] = true
		target_cell.set_resident_deme_id(daughter_id)
		rival_dist_cache.clear()
		initial_pop_by_deme[daughter_id] = migrants
		pre_fission_pop_by_deme[daughter_id] = migrants
		effective_vec_by_deme[daughter_id] = effective_vec_by_deme[deme.id]

		var flow := EvoTypes.HexEdgeFlow.new()
		flow.from_hex_id = current_cell.id
		flow.to_hex_id = target_cell.id
		flow.flow_type = "migration"
		flow.intensity = snappedf(clampf(float(migrants) / float(original_pop), 0.05, 1.0), 0.01)
		flow.from_deme_id = deme.id
		flow.to_deme_id = daughter_id
		state.active_flows.append(flow)

	var post_fission_ids := state.demes.keys()
	for did in post_fission_ids:
		if not state.demes.has(did):
			continue
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.population < 10:
			if state.cells.has(deme.hex_id):
				(state.cells[deme.hex_id] as EvoTypes.HexCell).deme_ids.erase(deme.id)
			state.demes.erase(deme.id)
			var extinct_pacts: Array[String] = []
			for pk_var in state.active_pacts.keys():
				var pk := str(pk_var)
				var sep := "__" if pk.contains("__") else "|"
				var parts := pk.split(sep)
				if parts.size() == 2 and (parts[0] == deme.id or parts[1] == deme.id):
					extinct_pacts.append(pk)
			for pk in extinct_pacts:
				state.active_pacts.erase(pk)
			if not state.recent_extinction_hexes.has(deme.hex_id):
				state.recent_extinction_hexes.append(deme.hex_id)

			var entry := EvoTypes.ChronicleEntry.new()
			entry.id = "chronicle-extinct-%d-%s" % [state.generation, deme.id]
			entry.generation = state.generation
			entry.event_type = "extinction"
			entry.title = ("%s Extinct" if is_en else "%s Extinguió") % deme.name
			entry.causal_explanation = (
				"%s fell below minimum viable population (%d) in hex (%s)." % [deme.name, deme.population, deme.hex_id]
				if is_en
				else "%s cayó por debajo de la población mínima viable (%d) en el hexágono (%s)." % [deme.name, deme.population, deme.hex_id]
			)
			entry.hex_id = deme.hex_id
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
				(state.lineage_tree[deme.lineage_id] as EvoTypes.LineageNode).extinct_generation = state.generation
			continue

		var init_pop: int = int(initial_pop_by_deme[deme.id]) if initial_pop_by_deme.has(deme.id) else deme.population
		var pre_fission_pop: int = int(pre_fission_pop_by_deme[deme.id]) if pre_fission_pop_by_deme.has(deme.id) else deme.population
		var lost_half := float(pre_fission_pop) <= float(init_pop) * 0.50
		var small_bottleneck := pre_fission_pop < 50 and pre_fission_pop < init_pop

		if not newly_created_demes.has(deme.id) and (lost_half or small_bottleneck) and not deme.cultural_trait_ids.is_empty():
			var highest_tid := ""
			var highest_thresh := -1.0
			for tid in deme.cultural_trait_ids:
				var thresh: float = (state.traits_catalog[tid] as EvoTypes.TraitDef).vector.transmission_threshold if state.traits_catalog.has(tid) else 0.0
				if thresh > highest_thresh:
					highest_thresh = thresh
					highest_tid = tid
			if highest_tid != "":
				deme.cultural_trait_ids.erase(highest_tid)
				var lost_name := EvoI18n.trait_name(lang, state.traits_catalog[highest_tid]) if state.traits_catalog.has(highest_tid) else highest_tid
				var entry := EvoTypes.ChronicleEntry.new()
				entry.id = "chronicle-culloss-%d-%s-%s" % [state.generation, deme.id, highest_tid]
				entry.generation = state.generation
				entry.event_type = "cultural_loss"
				entry.title = ("Cultural Loss: %s" if is_en else "Pérdida Cultural: %s") % lost_name
				entry.causal_explanation = (
					"%s experienced a demographic bottleneck (pop %d) and lost %s." % [deme.name, deme.population, lost_name]
					if is_en
					else "%s sufrió un cuello de botella demográfico (pob. %d) y perdió %s." % [deme.name, deme.population, lost_name]
				)
				entry.hex_id = deme.hex_id
				entry.deme_id = deme.id
				entry.lineage_id = deme.lineage_id
				entry.trait_id = highest_tid
				state.chronicle.append(entry)

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		var i := 0
		while i < cell.deme_ids.size():
			var j := i + 1
			while j < cell.deme_ids.size():
				var id_a := cell.deme_ids[i]
				var id_b := cell.deme_ids[j]
				if state.demes.has(id_a) and state.demes.has(id_b):
					var deme_a: EvoTypes.Deme = state.demes[id_a]
					var deme_b: EvoTypes.Deme = state.demes[id_b]
					var same_lineage_merge := deme_a.lineage_id == deme_b.lineage_id and compute_deme_divergence(deme_a, deme_b) <= 0.25
					var pact_synoecism := int(state.active_pacts.get(EvoTypes.make_pair_key(deme_a.id, deme_b.id), 0)) >= 3
					if same_lineage_merge or pact_synoecism:
						var host_d := deme_a if deme_a.population >= deme_b.population else deme_b
						var join_d := deme_b if deme_a.population >= deme_b.population else deme_a
						_merge_deme_into(
							state,
							host_d,
							join_d,
							cell,
							newly_created_demes,
							had_lineage_contact,
							pact_synoecism,
							lang,
							effective_vec_by_deme
						)
						continue
				j += 1
			i += 1

	var kin_deme_ids := state.demes.keys()
	for idx_1 in range(kin_deme_ids.size()):
		var id_1 := str(kin_deme_ids[idx_1])
		if not state.demes.has(id_1) or newly_created_demes.has(id_1):
			continue
		var d1: EvoTypes.Deme = state.demes[id_1]
		if d1.has_meta("_fission_gen") and state.generation - int(d1.get_meta("_fission_gen")) <= 3:
			continue
		if not state.cells.has(d1.hex_id):
			continue
		var c1: EvoTypes.HexCell = state.cells[d1.hex_id]
		if c1.biome == "ocean" or c1.altitude > 0.85:
			continue
		for nid in HexMath.get_neighbor_ids(c1.q, c1.r, state.cells):
			var c2: EvoTypes.HexCell = state.cells[nid]
			if c2.biome == "ocean" or c2.altitude > 0.85 or c2.deme_ids.is_empty():
				continue
			var id_2 := c2.get_resident_deme_id()
			if id_2 == "" or id_2 == d1.id or not state.demes.has(id_2) or newly_created_demes.has(id_2):
				continue
			var d2: EvoTypes.Deme = state.demes[id_2]
			if d2.has_meta("_fission_gen") and state.generation - int(d2.get_meta("_fission_gen")) <= 3:
				continue
			if d1.lineage_id != d2.lineage_id or compute_deme_divergence(d1, d2) > 0.25:
				continue
			var d1_hosts := (
				d1.defense_tier > d2.defense_tier
				or (d1.defense_tier == d2.defense_tier and d1.population >= d2.population)
			)
			var host_deme := d1 if d1_hosts else d2
			var joiner_deme := d2 if d1_hosts else d1
			var host_cell := c1 if d1_hosts else c2
			_merge_deme_into(
				state,
				host_deme,
				joiner_deme,
				host_cell,
				newly_created_demes,
				had_lineage_contact,
				false,
				lang,
				effective_vec_by_deme
			)
			break

	var pact_keys := state.active_pacts.keys()
	for pk_var in pact_keys:
		var pk := str(pk_var)
		if not state.active_pacts.has(pk):
			continue
		var pact_val := int(state.active_pacts[pk])
		if pact_val < 3:
			continue
		var sep := "__" if pk.contains("__") else "|"
		var parts := pk.split(sep)
		if parts.size() != 2:
			continue
		var id_1 := parts[0]
		var id_2 := parts[1]
		if not state.demes.has(id_1) or not state.demes.has(id_2):
			continue
		var d1: EvoTypes.Deme = state.demes[id_1]
		var d2: EvoTypes.Deme = state.demes[id_2]
		if not state.cells.has(d1.hex_id) or not state.cells.has(d2.hex_id):
			continue
		var c1: EvoTypes.HexCell = state.cells[d1.hex_id]
		var c2: EvoTypes.HexCell = state.cells[d2.hex_id]
		if c1.biome == "ocean" or c1.altitude > 0.85 or c2.biome == "ocean" or c2.altitude > 0.85:
			continue
		var dist := HexMath.hex_distance(c1.q, c1.r, c2.q, c2.r)
		if dist != 1:
			continue
		var d1_hosts := (
			d1.defense_tier > d2.defense_tier
			or (d1.defense_tier == d2.defense_tier and d1.population >= d2.population)
		)
		var host_deme := d1 if d1_hosts else d2
		var joiner_deme := d2 if d1_hosts else d1
		var host_cell := c1 if d1_hosts else c2
		_merge_deme_into(
			state,
			host_deme,
			joiner_deme,
			host_cell,
			newly_created_demes,
			had_lineage_contact,
			true,
			lang,
			effective_vec_by_deme
		)

	var conn_cache: Dictionary = {}
	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(deme.hex_id):
			continue
		if had_lineage_contact.has(deme.id):
			deme.isolation_turns = 0
			continue
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var founder_hex_id := ""
		if state.lineage_tree.has(deme.lineage_id):
			founder_hex_id = (state.lineage_tree[deme.lineage_id] as EvoTypes.LineageNode).founder_hex_id

		if founder_hex_id != "" and deme.hex_id == founder_hex_id:
			deme.isolation_turns = 0
			continue

		var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[deme.id] if effective_vec_by_deme.has(deme.id) else EvoEcologyInteraction.compute_effective_vector(deme, state)
		var c_key := "%s|%s|%.2f" % [cell.id, deme.lineage_id, v_eff.spatial_mobility]
		var is_conn: bool
		if conn_cache.has(c_key):
			is_conn = bool(conn_cache[c_key])
		else:
			is_conn = _is_connected_to_founder(cell, founder_hex_id, v_eff.spatial_mobility, deme, state)
			conn_cache[c_key] = is_conn
		if is_conn:
			deme.isolation_turns = 0
		else:
			deme.isolation_turns += 1

	var dispute_flow_pairs: Dictionary = {}
	var social_flow_pairs: Dictionary = {}
	var friendly_flow_pairs: Dictionary = {}
	for fl in state.active_flows:
		var pair_ab := "%s|%s" % [fl.from_deme_id, fl.to_deme_id]
		var pair_ba := "%s|%s" % [fl.to_deme_id, fl.from_deme_id]
		var hex_ab := ("%s|%s" % [fl.from_hex_id, fl.to_hex_id]) if fl.from_hex_id <= fl.to_hex_id else ("%s|%s" % [fl.to_hex_id, fl.from_hex_id])
		if fl.flow_type in ["dispute", "war", "raid", "betrayal", "siege"]:
			dispute_flow_pairs[pair_ab] = true
			dispute_flow_pairs[pair_ba] = true
			social_flow_pairs[pair_ab] = true
			social_flow_pairs[pair_ba] = true
			if fl.from_hex_id != fl.to_hex_id:
				dispute_flow_pairs[hex_ab] = true
				social_flow_pairs[hex_ab] = true
		elif fl.flow_type in ["exchange", "cooperate", "pact", "tribute", "merge"]:
			social_flow_pairs[pair_ab] = true
			social_flow_pairs[pair_ba] = true
			friendly_flow_pairs[pair_ab] = true
			friendly_flow_pairs[pair_ba] = true
			if fl.from_hex_id != fl.to_hex_id:
				social_flow_pairs[hex_ab] = true

	var surviving_demes: Array[EvoTypes.Deme] = []
	var surviving_cells: Array[EvoTypes.HexCell] = []
	var surv_disp: Array[float] = []
	var surv_over: Array[float] = []
	var surv_coop: Array[float] = []
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(d.hex_id):
			continue
		surviving_demes.append(d)
		surviving_cells.append(state.cells[d.hex_id])
		var pd: float = 0.0
		var po: float = 0.0
		var pc: float = 0.0
		for dec_id in d.last_decision_probabilities.keys():
			if state.decisions_catalog.has(dec_id):
				var arch := (state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).archetype
				var prob := float(d.last_decision_probabilities[dec_id])
				if arch == "dispute":
					pd += prob
				elif arch == "overexploit":
					po += prob
				elif arch == "cooperate":
					pc += prob
		surv_disp.append(pd)
		surv_over.append(po)
		surv_coop.append(pc)

	var s_count := surviving_demes.size()
	var surv_idx_by_id: Dictionary = {}
	for idx_a in range(s_count):
		surv_idx_by_id[surviving_demes[idx_a].id] = idx_a

	for idx_a in range(s_count):
		var deme_a := surviving_demes[idx_a]
		var id_a := deme_a.id
		var cell_a := surviving_cells[idx_a]
		var bad_a := cell_a.altitude > 0.85 or cell_a.biome == "ocean"
		var p_disp_a := surv_disp[idx_a]
		var p_over_a := surv_over[idx_a]
		var p_coop_a := surv_coop[idx_a]
		var coop_ok_a := p_coop_a >= 0.14 or deme_a.last_dominant_decision_id == "dec-cooperate-store"

		var candidate_cells: Array[EvoTypes.HexCell] = [cell_a]
		if not bad_a:
			for nid in HexMath.get_neighbor_ids(cell_a.q, cell_a.r, state.cells):
				var ncell: EvoTypes.HexCell = state.cells[nid]
				if not ncell.deme_ids.is_empty() and ncell.altitude <= 0.85 and ncell.biome != "ocean":
					candidate_cells.append(ncell)

		for cell_b in candidate_cells:
			var same_hex := cell_a.id == cell_b.id
			for id_b in cell_b.deme_ids:
				if not surv_idx_by_id.has(id_b):
					continue
				var idx_b: int = int(surv_idx_by_id[id_b])
				if idx_b <= idx_a:
					continue
				var deme_b := surviving_demes[idx_b]
				var p_disp_b := surv_disp[idx_b]
				var p_over_b := surv_over[idx_b]
				var p_coop_b := surv_coop[idx_b]
				var coop_ok_b := p_coop_b >= 0.14 or deme_b.last_dominant_decision_id == "dec-cooperate-store"

				var pair_key := "%s|%s" % [id_a, id_b]
				var pact_key := ("%s__%s" % [id_a, id_b]) if id_a < id_b else ("%s__%s" % [id_b, id_a])
				var is_rival := deme_a.lineage_id != deme_b.lineage_id and int(state.active_pacts.get(pact_key, 0)) < 2
				var has_conflict_pressure := (
					(p_disp_a >= 0.12 or p_disp_b >= 0.12 or p_over_a >= 0.35 or p_over_b >= 0.35)
					if same_hex
					else (p_disp_a >= 0.25 or p_disp_b >= 0.25)
				)
				if is_rival and has_conflict_pressure:
					if not dispute_flow_pairs.has(pair_key):
						dispute_flow_pairs[pair_key] = true
						social_flow_pairs[pair_key] = true
						var hex_pair_key := ("%s|%s" % [cell_a.id, cell_b.id]) if cell_a.id <= cell_b.id else ("%s|%s" % [cell_b.id, cell_a.id])
						if same_hex or not dispute_flow_pairs.has(hex_pair_key):
							if not same_hex:
								dispute_flow_pairs[hex_pair_key] = true
							var disp_flow := EvoTypes.HexEdgeFlow.new()
							disp_flow.from_hex_id = cell_a.id
							disp_flow.to_hex_id = cell_b.id
							disp_flow.flow_type = "dispute"
							disp_flow.intensity = snappedf(
								clampf(maxf(maxf(p_disp_a, p_disp_b), (maxf(p_over_a, p_over_b) * 0.85) if same_hex else 0.0), 0.35, 0.90),
								0.01
							)
							disp_flow.from_deme_id = id_a
							disp_flow.to_deme_id = id_b
							state.active_flows.append(disp_flow)
				elif coop_ok_a and coop_ok_b:
					if not social_flow_pairs.has(pair_key):
						social_flow_pairs[pair_key] = true
						friendly_flow_pairs[pair_key] = true
						friendly_flow_pairs["%s|%s" % [id_b, id_a]] = true
						var hex_pair_key := ("%s|%s" % [cell_a.id, cell_b.id]) if cell_a.id <= cell_b.id else ("%s|%s" % [cell_b.id, cell_a.id])
						if same_hex or not social_flow_pairs.has(hex_pair_key):
							if not same_hex:
								social_flow_pairs[hex_pair_key] = true
							var coop_flow := EvoTypes.HexEdgeFlow.new()
							coop_flow.from_hex_id = cell_a.id
							coop_flow.to_hex_id = cell_b.id
							coop_flow.flow_type = "cooperate"
							coop_flow.intensity = snappedf(clampf((p_coop_a + p_coop_b) * 0.85, 0.30, 0.85), 0.01)
							coop_flow.from_deme_id = id_a
							coop_flow.to_deme_id = id_b
							state.active_flows.append(coop_flow)

	for cid in state.cells.keys():
		var c: EvoTypes.HexCell = state.cells[cid]
		var valid_ids: Array[String] = []
		for did in c.deme_ids:
			if state.demes.has(did) and (state.demes[did] as EvoTypes.Deme).hex_id == c.id:
				valid_ids.append(did)
		c.deme_ids = valid_ids
		if c.deme_ids.size() > 1:
			var keep_id := c.deme_ids[0]
			var extras := c.deme_ids.slice(1)
			c.set_resident_deme_id(keep_id)
			for ex_id in extras:
				if state.demes.has(ex_id):
					evacuate_or_merge_displaced_deme(state.demes[ex_id], c, state, lang, "invasion", pre_fission_pop_by_deme, effective_vec_by_deme)

	var filtered_disused: Array[Dictionary] = []
	for conn in state.disused_connections:
		var fa := str(conn["from_deme_id"]) if conn.has("from_deme_id") else ""
		var fb := str(conn["to_deme_id"]) if conn.has("to_deme_id") else ""
		if fa == fb or not state.demes.has(fa) or not state.demes.has(fb):
			continue
		if not friendly_flow_pairs.has("%s|%s" % [fa, fb]):
			var conn_age := int(conn.get("age", 0))
			if conn_age <= 0:
				conn_age = 1
				conn["age"] = 1
			if conn_age <= 8:
				filtered_disused.append(conn)
	state.disused_connections = filtered_disused


static func _merge_deme_into(
	state: EvoTypes.WorldState,
	deme_a: EvoTypes.Deme,
	deme_b: EvoTypes.Deme,
	cell_a: EvoTypes.HexCell,
	newly_created_demes: Dictionary,
	had_lineage_contact: Dictionary,
	is_synoecism: bool,
	lang: String,
	effective_vec_by_deme: Dictionary = {}
) -> void:
	var old_name_a := deme_a.name
	var old_name_b := deme_b.name
	var from_hex_id := deme_b.hex_id
	var total_pop := deme_a.population + deme_b.population
	var a_new := newly_created_demes.has(deme_a.id)
	var b_new := newly_created_demes.has(deme_b.id)
	var w_a := (
		1.0
		if (b_new and not a_new)
		else (0.0 if (a_new and not b_new) else float(deme_a.population) / float(maxi(1, total_pop)))
	)
	var w_b := 1.0 - w_a

	deme_a.innovation_counter = minf(
		2.0,
		snappedf(deme_a.innovation_counter * w_a + deme_b.innovation_counter * w_b, 0.0001)
	)

	var all_keys: Dictionary = {}
	for k in deme_a.baldwin_counters.keys():
		all_keys[k] = true
	for k in deme_b.baldwin_counters.keys():
		all_keys[k] = true
	var merged_counters: Dictionary = {}
	for k in all_keys.keys():
		var ca: int = int(deme_a.baldwin_counters[k]) if deme_a.baldwin_counters.has(k) else 0
		var cb: int = int(deme_b.baldwin_counters[k]) if deme_b.baldwin_counters.has(k) else 0
		merged_counters[k] = int(roundf(float(ca) * w_a + float(cb) * w_b))
	deme_a.baldwin_counters = merged_counters

	deme_a.population = total_pop
	deme_a.energy_reserves = minf(280.0, snappedf(deme_a.energy_reserves + deme_b.energy_reserves, 0.01))
	var traits_changed := false
	for tid in deme_b.biological_trait_ids:
		if EvoEcologyInteraction._can_acquire_trait(deme_a, tid, state.traits_catalog):
			deme_a.biological_trait_ids.append(tid)
			traits_changed = true
	for tid in deme_b.cultural_trait_ids:
		if EvoEcologyInteraction._can_acquire_trait(deme_a, tid, state.traits_catalog):
			deme_a.cultural_trait_ids.append(tid)
			traits_changed = true

	if traits_changed and not effective_vec_by_deme.is_empty():
		effective_vec_by_deme[deme_a.id] = EvoEcologyInteraction.compute_effective_vector(deme_a, state)

	if state.lineage_tree.has(deme_a.lineage_id):
		var lin_node: EvoTypes.LineageNode = state.lineage_tree[deme_a.lineage_id]
		for tid in deme_a.biological_trait_ids:
			if not lin_node.biological_trait_ids.has(tid):
				lin_node.biological_trait_ids.append(tid)
		for tid in deme_a.cultural_trait_ids:
			if not lin_node.cultural_trait_ids.has(tid):
				lin_node.cultural_trait_ids.append(tid)

	var combined_tier := maxi(deme_a.defense_tier, deme_b.defense_tier)
	if is_synoecism and deme_a.population >= 90 and combined_tier < 3:
		combined_tier = mini(3, maxi(2, combined_tier + 1))
	deme_a.defense_tier = combined_tier
	deme_a.merged_count += 1 + deme_b.merged_count

	if is_synoecism:
		if deme_b.color != "" and deme_b.color != deme_a.color:
			deme_a.secondary_color = deme_b.color
		elif deme_a.secondary_color == "":
			deme_a.secondary_color = deme_b.secondary_color if deme_b.secondary_color != "" else deme_b.color
		cell_a.carrying_capacity = minf(cell_a.carrying_capacity_max * 1.35, cell_a.carrying_capacity + 35.0)
		var merge_params := {
			"deme_a": old_name_a,
			"deme_b": old_name_b,
			"hex": cell_a.id,
			"pop": str(deme_a.population)
		}
		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-merge-%d-%s-%s" % [state.generation, deme_a.id, deme_b.id]
		entry.generation = state.generation
		entry.event_type = "merge"
		entry.title = EvoI18n.t(lang, "chronicle_merge_title", merge_params)
		entry.causal_explanation = EvoI18n.t(lang, "chronicle_merge_desc", merge_params)
		entry.hex_id = cell_a.id
		entry.deme_id = deme_a.id
		entry.lineage_id = deme_a.lineage_id
		state.chronicle.append(entry)

	var kept_flows: Array[EvoTypes.HexEdgeFlow] = []
	for fl in state.active_flows:
		if fl.to_deme_id == deme_b.id:
			fl.to_deme_id = deme_a.id
		if fl.from_deme_id == deme_b.id:
			fl.from_deme_id = deme_a.id
		if fl.from_deme_id == fl.to_deme_id and not (fl.flow_type in ["migration", "merge"]):
			continue
		kept_flows.append(fl)
	state.active_flows = kept_flows

	if not state.active_pacts.is_empty():
		var pacts_to_erase: Array[String] = []
		var pacts_to_set: Dictionary = {}
		for pk_var in state.active_pacts.keys():
			var pk := str(pk_var)
			if not pk.contains(deme_b.id):
				continue
			var sep := "__" if pk.contains("__") else "|"
			var parts := pk.split(sep)
			if parts.size() == 2 and (parts[0] == deme_b.id or parts[1] == deme_b.id):
				pacts_to_erase.append(pk)
				var partner_id := parts[1] if parts[0] == deme_b.id else parts[0]
				if partner_id != deme_a.id and not b_new:
					var new_pk := EvoTypes.make_pair_key(deme_a.id, partner_id)
					var existing_val: int = int(state.active_pacts[new_pk]) if state.active_pacts.has(new_pk) else 0
					var b_val: int = int(state.active_pacts[pk])
					var merged_val: int = 0
					if existing_val == 0:
						merged_val = b_val
					elif b_val == 0:
						merged_val = existing_val
					elif existing_val > 0 or b_val > 0:
						merged_val = maxi(existing_val, b_val)
					else:
						merged_val = mini(existing_val, b_val)
					if merged_val != 0:
						pacts_to_set[new_pk] = merged_val
		for pk in pacts_to_erase:
			state.active_pacts.erase(pk)
		for new_pk in pacts_to_set.keys():
			state.active_pacts[new_pk] = pacts_to_set[new_pk]

	if not b_new and not state.disused_connections.is_empty():
		var kept_disused: Array[Dictionary] = []
		for dc in state.disused_connections:
			if str(dc.get("from_deme_id", "")) == deme_b.id:
				dc["from_deme_id"] = deme_a.id
			if str(dc.get("to_deme_id", "")) == deme_b.id:
				dc["to_deme_id"] = deme_a.id
			if str(dc.get("from_deme_id", "")) == str(dc.get("to_deme_id", "")):
				continue
			kept_disused.append(dc)
		state.disused_connections = kept_disused

	var merge_flow := EvoTypes.HexEdgeFlow.new()
	merge_flow.from_hex_id = from_hex_id
	merge_flow.to_hex_id = cell_a.id
	merge_flow.flow_type = "merge"
	merge_flow.intensity = 0.85 if is_synoecism else 0.65
	merge_flow.from_deme_id = deme_b.id
	merge_flow.to_deme_id = deme_a.id
	state.active_flows.append(merge_flow)

	if state.cells.has(from_hex_id):
		(state.cells[from_hex_id] as EvoTypes.HexCell).deme_ids.erase(deme_b.id)
	cell_a.deme_ids.erase(deme_b.id)
	state.demes.erase(deme_b.id)
	if deme_b.lineage_id != deme_a.lineage_id and state.lineage_tree.has(deme_b.lineage_id):
		var has_relatives := false
		for rem_id in state.demes.keys():
			if (state.demes[rem_id] as EvoTypes.Deme).lineage_id == deme_b.lineage_id:
				has_relatives = true
				break
		if not has_relatives:
			(state.lineage_tree[deme_b.lineage_id] as EvoTypes.LineageNode).extinct_generation = state.generation
	had_lineage_contact[deme_a.id] = true
