class_name EvoDemographyMigration
extends RefCounted


static func is_hex_passable_for_deme(cell: EvoTypes.HexCell, spatial_mobility: float) -> bool:
	return cell.biome != "ocean" and (cell.altitude - 0.50) <= spatial_mobility


static func compute_deme_divergence(deme_a: EvoTypes.Deme, deme_b: EvoTypes.Deme) -> float:
	var set_a: Dictionary = {}
	for tid in deme_a.biological_trait_ids:
		set_a[tid] = true
	for tid in deme_a.cultural_trait_ids:
		set_a[tid] = true

	var set_b: Dictionary = {}
	for tid in deme_b.biological_trait_ids:
		set_b[tid] = true
	for tid in deme_b.cultural_trait_ids:
		set_b[tid] = true

	var union_set: Dictionary = set_a.duplicate()
	for tid in set_b.keys():
		union_set[tid] = true

	if union_set.is_empty():
		return 0.0

	var intersection_count: int = 0
	for tid in set_a.keys():
		if set_b.has(tid):
			intersection_count += 1

	return snappedf(1.0 - float(intersection_count) / float(union_set.size()), 0.0001)


static func _strip_coord_suffix(name_str: String) -> String:
	var open_idx := name_str.rfind(" (")
	if open_idx > 0 and name_str.ends_with(")"):
		var inside := name_str.substr(open_idx + 2, name_str.length() - open_idx - 3)
		if inside.contains(","):
			return name_str.substr(0, open_idx)
	return name_str


static func _strip_migration_suffix(id_str: String) -> String:
	var m_idx := id_str.find("-m")
	var w_idx := id_str.find("-w")
	var cut_idx := -1
	if m_idx > 0 and w_idx > 0:
		cut_idx = mini(m_idx, w_idx)
	elif m_idx > 0:
		cut_idx = m_idx
	elif w_idx > 0:
		cut_idx = w_idx
	if cut_idx > 0:
		return id_str.substr(0, cut_idx)
	return id_str


static func _is_connected_to_founder(
	cell: EvoTypes.HexCell,
	founder_hex_id: String,
	mobility: float,
	cells: Dictionary
) -> bool:
	if founder_hex_id == "" or not cells.has(founder_hex_id):
		return false
	if cell.id == founder_hex_id:
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
		var cur_cell: EvoTypes.HexCell = cells[cur_id]
		for nid in HexMath.get_neighbor_ids(cur_cell.q, cur_cell.r, cells):
			if visited.has(nid):
				continue
			var ncell: EvoTypes.HexCell = cells[nid]
			if not is_hex_passable_for_deme(ncell, mobility):
				continue
			if nid == founder_hex_id:
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

	var att_force := (
		float(warband_pop)
		* (1.0 + 0.55 * maxf(0.0, att_vec.extraction_efficiency) + att_warrior + att_r_strat)
		* (0.75 + p_att_disp)
	)
	var def_force := (
		float(defender.population)
		* (1.0 + 0.60 * maxf(0.0, def_vec.social_cohesion) + pact_bonus + def_warrior)
	)
	return Vector2(att_force, def_force)


static func _min_distance_to_rival(
	cell: EvoTypes.HexCell,
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> int:
	var min_dist := 999
	for oid in state.demes.keys():
		var other: EvoTypes.Deme = state.demes[oid]
		if other.lineage_id == deme.lineage_id or EvoTypes.is_pact_active(state, deme.id, other.id):
			continue
		if not state.cells.has(other.hex_id):
			continue
		var ocell: EvoTypes.HexCell = state.cells[other.hex_id]
		var d := HexMath.hex_distance(cell.q, cell.r, ocell.q, ocell.r)
		if d < min_dist:
			min_dist = d
	return min_dist


static func _has_vanguard_closer_to_rival(
	deme: EvoTypes.Deme,
	cur_rival_dist: int,
	state: EvoTypes.WorldState
) -> bool:
	for oid in state.demes.keys():
		var other: EvoTypes.Deme = state.demes[oid]
		if other.id == deme.id or other.lineage_id != deme.lineage_id:
			continue
		if other.population < 45 or not state.cells.has(other.hex_id):
			continue
		var ocell: EvoTypes.HexCell = state.cells[other.hex_id]
		if _min_distance_to_rival(ocell, other, state) < cur_rival_dist:
			return true
	return false


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
		var att_loss := maxi(2, int(round(float(warband_pop) * clampf(0.22 * (def_force / maxf(1.0, att_force)), 0.08, 0.35))))
		var def_loss := maxi(4, int(round(float(defender.population) * clampf(0.35 * (att_force / maxf(1.0, def_force)), 0.20, 0.55))))
		var loot := roundf(defender.energy_reserves * 0.38)
		defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - loot, 0.01))
		defender.population = maxi(0, defender.population - def_loss)

		var energy_fraction := attacker.energy_reserves * (float(warband_pop) / float(maxi(1, original_pop)))
		attacker.energy_reserves = maxf(0.0, snappedf(attacker.energy_reserves - energy_fraction, 0.01))
		var warband_energy := snappedf(energy_fraction * 0.85 + loot, 0.01)
		var surviving_warband := maxi(10, warband_pop - att_loss)

		if defender.population >= 12:
			var retreat_candidates: Array[EvoTypes.HexCell] = []
			for nid in HexMath.get_neighbor_ids(target_cell.q, target_cell.r, state.cells):
				if nid == origin_cell.id:
					continue
				var rcell: EvoTypes.HexCell = state.cells[nid]
				if rcell.biome != "ocean" and rcell.altitude <= 0.85 and rcell.deme_ids.size() < 3:
					retreat_candidates.append(rcell)
			retreat_candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				var rivals_a := 0
				for did_a in a.deme_ids:
					if state.demes.has(did_a) and (state.demes[did_a] as EvoTypes.Deme).lineage_id != defender.lineage_id:
						rivals_a += 1
				var rivals_b := 0
				for did_b in b.deme_ids:
					if state.demes.has(did_b) and (state.demes[did_b] as EvoTypes.Deme).lineage_id != defender.lineage_id:
						rivals_b += 1
				if rivals_a != rivals_b:
					return rivals_a < rivals_b
				return a.current_resources > b.current_resources
			)
			if not retreat_candidates.is_empty():
				var retreat_cell := retreat_candidates[0]
				target_cell.deme_ids.erase(defender.id)
				defender.hex_id = retreat_cell.id
				if not retreat_cell.deme_ids.has(defender.id):
					retreat_cell.deme_ids.append(defender.id)

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
		warband.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(warband_id)
		warband.last_confidence = attacker.last_confidence
		warband.last_decision_probabilities = attacker.last_decision_probabilities.duplicate()
		warband.last_dominant_decision_id = attacker.last_dominant_decision_id
		warband.last_justification = attacker.last_justification

		state.demes[warband_id] = warband
		newly_created_demes[warband_id] = true
		target_cell.deme_ids.append(warband_id)
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
		var att_loss := maxi(4, int(round(float(warband_pop) * 0.42)))
		var def_loss := maxi(2, int(round(float(defender.population) * 0.16)))
		var survivors := maxi(0, warband_pop - att_loss)
		attacker.population = maxi(10, attacker.population + survivors)
		attacker.energy_reserves = maxf(0.0, snappedf(attacker.energy_reserves - 15.0, 0.01))
		defender.population = maxi(5, defender.population - def_loss)

		for pk in state.active_pacts.keys():
			if str(pk).contains(defender.id):
				state.active_pacts[pk] = int(state.active_pacts[pk]) + 1

		var flow := EvoTypes.HexEdgeFlow.new()
		flow.from_hex_id = origin_cell.id
		flow.to_hex_id = target_cell.id
		flow.flow_type = "war"
		flow.intensity = 0.85
		flow.from_deme_id = attacker.id
		flow.to_deme_id = defender.id
		state.active_flows.append(flow)
		geo_flows.append(flow)

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

		var delta_e := extracted - metabolic_cost
		var prev_reserves := deme.energy_reserves
		var reserve_draw := minf(-delta_e, prev_reserves * 0.50) if delta_e < 0.0 else 0.0
		var effective_delta_e := delta_e + reserve_draw

		deme.last_energy_delta = snappedf(delta_e, 0.01)
		deme.energy_reserves = maxf(0.0, snappedf(prev_reserves + delta_e, 0.01))

		var raw_growth := (effective_delta_e / maxf(10.0, float(deme.population))) * 0.45
		if deme.biological_trait_ids.has("bio-r-strategy") and raw_growth > 0.0:
			var cell_pop: int = 0
			for r_id in cell.deme_ids:
				if state.demes.has(r_id):
					cell_pop += (state.demes[r_id] as EvoTypes.Deme).population
			var crowding := float(cell_pop) / maxf(10.0, cell.carrying_capacity)
			if crowding < 0.55:
				raw_growth *= 1.28
			elif crowding >= 0.65:
				raw_growth *= 1.05
			else:
				raw_growth *= 1.16
		if deme.biological_trait_ids.has("bio-k-strategy"):
			raw_growth *= 0.75
		var growth_rate := clampf(raw_growth, -0.45, 0.35)

		var next_pop := int(roundf(float(deme.population) * (1.0 + growth_rate)))
		deme.population = (deme.population - 1) if (effective_delta_e < 0.0 and next_pop >= deme.population) else next_pop
		pre_fission_pop_by_deme[deme.id] = deme.population

		for dec_id in deme.last_decision_probabilities.keys():
			var prob := float(deme.last_decision_probabilities[dec_id])
			var arch := (state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).archetype if state.decisions_catalog.has(dec_id) else ""
			if arch != "forage" and prob >= 0.35:
				var cur_c: int = int(deme.baldwin_counters[dec_id]) if deme.baldwin_counters.has(dec_id) else 0
				deme.baldwin_counters[dec_id] = cur_c + 1

		if EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog):
			var p_explore := EvoEcologyInteraction.get_archetype_prob(deme, state.decisions_catalog, "innovate")
			var p_cooperate := EvoEcologyInteraction.get_archetype_prob(deme, state.decisions_catalog, "cooperate")
			var p_innovate := p_explore + 0.35 * p_cooperate
			deme.innovation_counter = minf(2.0, snappedf(deme.innovation_counter + p_innovate * 0.45, 0.0001))

	var pre_fission_ids := state.demes.keys()
	for did in pre_fission_ids:
		if not state.demes.has(did):
			continue
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.population < 20 or not state.cells.has(deme.hex_id):
			continue
		var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[deme.id]
		var p_migrate := EvoEcologyInteraction.get_archetype_prob(deme, state.decisions_catalog, "migrate")
		var p_dispute := EvoEcologyInteraction.get_archetype_prob(deme, state.decisions_catalog, "dispute")
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
			and (
				p_migrate + p_dispute >= 0.30
				or (deme.cultural_trait_ids.has("cul-warrior-expansion") and deme.population >= 75)
			)
		)

		if martial_trigger:
			var warband_pop := int(round(float(deme.population) * 0.48))
			var best_target_cell: EvoTypes.HexCell = null
			var best_defender: EvoTypes.Deme = null
			var best_ratio := -1.0

			for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
				var ncell: EvoTypes.HexCell = state.cells[nid]
				if ncell.biome == "ocean" or ncell.altitude > 0.85:
					continue
				for oid in ncell.deme_ids:
					if not state.demes.has(oid):
						continue
					var other: EvoTypes.Deme = state.demes[oid]
					if other.lineage_id == deme.lineage_id or EvoTypes.is_pact_active(state, deme.id, other.id):
						continue
					var forces := _compute_combat_forces(deme, warband_pop, other, state)
					if forces.x >= forces.y * 0.65 or adequacy < 0.80:
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
				continue

		var is_emergency := (
			current_cell.current_resources < float(deme.population) * 0.20
			and deme.energy_reserves < float(deme.population) * 0.35
		)
		var has_intentional_migration := (
			martial_trigger
			or deme.last_dominant_decision_id == "dec-selective-migration"
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

		var cur_rival_dist := _min_distance_to_rival(current_cell, deme, state) if is_martial_expander else 999
		var is_pure_martial_march := (
			martial_trigger
			and deme.last_dominant_decision_id != "dec-selective-migration"
			and current_cell.biome != "coastal_shallows"
			and not is_emergency
		)
		if is_pure_martial_march and _has_vanguard_closer_to_rival(deme, cur_rival_dist, state):
			continue
		var v_eff_mobility := v_eff.spatial_mobility
		var mig_mobility := clampf(v_eff_mobility + (1.0 - p_migrate) * 0.50, -1.5, 1.5)
		if is_martial_expander:
			mig_mobility = maxf(mig_mobility, 0.35)
		var candidates: Array[EvoTypes.HexCell] = []
		var reinforce_candidates: Array[EvoTypes.HexCell] = []
		for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if not is_hex_passable_for_deme(ncell, mig_mobility):
				continue
			if ncell.deme_ids.size() >= 3:
				continue
			var n_dist := _min_distance_to_rival(ncell, deme, state) if is_martial_expander else 999
			if is_pure_martial_march and n_dist >= cur_rival_dist:
				continue
			if not is_emergency:
				var has_compatible_kin := false
				var kin_pop := 0
				for oid in ncell.deme_ids:
					if state.demes.has(oid):
						var other: EvoTypes.Deme = state.demes[oid]
						if other.lineage_id == deme.lineage_id and compute_deme_divergence(deme, other) <= 0.25:
							has_compatible_kin = true
							kin_pop += other.population
				if has_compatible_kin:
					if is_pure_martial_march and n_dist < cur_rival_dist and kin_pop < 75:
						reinforce_candidates.append(ncell)
					continue
			candidates.append(ncell)

		if candidates.is_empty() and not reinforce_candidates.is_empty():
			candidates = reinforce_candidates

		candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
			var sa := a.current_resources / float(a.deme_ids.size() + 1)
			var sb := b.current_resources / float(b.deme_ids.size() + 1)
			if is_martial_expander and cur_rival_dist < 999:
				var da := _min_distance_to_rival(a, deme, state)
				var db := _min_distance_to_rival(b, deme, state)
				var bonus_a := (45.0 + float(maxi(0, 10 - da)) * 8.0) if da < cur_rival_dist else 0.0
				var bonus_b := (45.0 + float(maxi(0, 10 - db)) * 8.0) if db < cur_rival_dist else 0.0
				sa += bonus_a
				sb += bonus_b
			return sa > sb
		)

		if candidates.is_empty():
			continue

		var target_cell := candidates[0]
		var original_pop := deme.population
		var energy_fraction := deme.energy_reserves * (float(migrants) / float(original_pop))
		var transferred_energy := snappedf(energy_fraction * 0.85, 0.01)

		deme.population -= migrants
		deme.energy_reserves = maxf(0.0, snappedf(deme.energy_reserves - energy_fraction, 0.01))

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

		state.demes[daughter_id] = daughter
		newly_created_demes[daughter_id] = true
		target_cell.deme_ids.append(daughter_id)
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
					if deme_a.lineage_id == deme_b.lineage_id and compute_deme_divergence(deme_a, deme_b) <= 0.25:
						var total_pop := deme_a.population + deme_b.population
						var a_new := newly_created_demes.has(deme_a.id)
						var b_new := newly_created_demes.has(deme_b.id)
						var w_a := 1.0 if (b_new and not a_new) else (0.0 if (a_new and not b_new) else float(deme_a.population) / float(total_pop))
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
						deme_a.energy_reserves = snappedf(deme_a.energy_reserves + deme_b.energy_reserves, 0.01)
						for tid in deme_b.biological_trait_ids:
							if EvoEcologyInteraction._can_acquire_trait(deme_a, tid, state.traits_catalog):
								deme_a.biological_trait_ids.append(tid)
						for tid in deme_b.cultural_trait_ids:
							if EvoEcologyInteraction._can_acquire_trait(deme_a, tid, state.traits_catalog):
								deme_a.cultural_trait_ids.append(tid)

						var kept_flows: Array[EvoTypes.HexEdgeFlow] = []
						for fl in state.active_flows:
							if fl.to_deme_id == deme_b.id:
								fl.to_deme_id = deme_a.id
							if fl.from_deme_id == deme_b.id:
								fl.from_deme_id = deme_a.id
							if fl.from_deme_id == fl.to_deme_id and fl.from_hex_id == fl.to_hex_id and fl.flow_type != "migration":
								continue
							kept_flows.append(fl)
						state.active_flows = kept_flows
						for dc in state.disused_connections:
							if str(dc.get("from_deme_id", "")) == deme_b.id:
								dc["from_deme_id"] = deme_a.id
							if str(dc.get("to_deme_id", "")) == deme_b.id:
								dc["to_deme_id"] = deme_a.id

						var merge_flow := EvoTypes.HexEdgeFlow.new()
						merge_flow.from_hex_id = cell.id
						merge_flow.to_hex_id = cell.id
						merge_flow.flow_type = "merge"
						merge_flow.intensity = 0.65
						merge_flow.from_deme_id = deme_b.id
						merge_flow.to_deme_id = deme_a.id
						state.active_flows.append(merge_flow)

						state.demes.erase(deme_b.id)
						cell.deme_ids.remove_at(j)
						had_lineage_contact[deme_a.id] = true
						continue
				j += 1
			i += 1

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(deme.hex_id):
			continue
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var founder_hex_id := ""
		if state.lineage_tree.has(deme.lineage_id):
			founder_hex_id = (state.lineage_tree[deme.lineage_id] as EvoTypes.LineageNode).founder_hex_id

		if founder_hex_id != "" and deme.hex_id == founder_hex_id:
			deme.isolation_turns = 0
			continue

		var v_eff := EvoEcologyInteraction.compute_effective_vector(deme, state)
		var connected_to_founder := _is_connected_to_founder(cell, founder_hex_id, v_eff.spatial_mobility, state.cells)

		if had_lineage_contact.has(deme.id) or connected_to_founder:
			deme.isolation_turns = 0
		else:
			deme.isolation_turns += 1

	var dispute_flow_pairs: Dictionary = {}
	var social_flow_pairs: Dictionary = {}
	for fl in state.active_flows:
		var pair_ab := "%s|%s" % [fl.from_deme_id, fl.to_deme_id]
		var pair_ba := "%s|%s" % [fl.to_deme_id, fl.from_deme_id]
		if fl.flow_type in ["dispute", "war", "raid", "betrayal"]:
			dispute_flow_pairs[pair_ab] = true
			dispute_flow_pairs[pair_ba] = true
			social_flow_pairs[pair_ab] = true
			social_flow_pairs[pair_ba] = true
		elif fl.flow_type in ["exchange", "cooperate", "pact"]:
			social_flow_pairs[pair_ab] = true
			social_flow_pairs[pair_ba] = true

	var surviving_ids := state.demes.keys()
	for idx_a in range(surviving_ids.size()):
		var id_a := str(surviving_ids[idx_a])
		var deme_a: EvoTypes.Deme = state.demes[id_a]
		if not state.cells.has(deme_a.hex_id):
			continue
		var cell_a: EvoTypes.HexCell = state.cells[deme_a.hex_id]
		var p_disp_a := EvoEcologyInteraction.get_archetype_prob(deme_a, state.decisions_catalog, "dispute")
		var p_over_a := EvoEcologyInteraction.get_archetype_prob(deme_a, state.decisions_catalog, "overexploit")
		var p_coop_a := EvoEcologyInteraction.get_archetype_prob(deme_a, state.decisions_catalog, "cooperate")
		var coop_ok_a := p_coop_a >= 0.14 or deme_a.last_dominant_decision_id == "dec-cooperate-store"

		for idx_b in range(idx_a + 1, surviving_ids.size()):
			var id_b := str(surviving_ids[idx_b])
			var deme_b: EvoTypes.Deme = state.demes[id_b]
			if not state.cells.has(deme_b.hex_id):
				continue
			var cell_b: EvoTypes.HexCell = state.cells[deme_b.hex_id]
			var dist := HexMath.hex_distance(cell_a.q, cell_a.r, cell_b.q, cell_b.r)
			if dist > 1:
				continue
			var same_hex := dist == 0
			if not same_hex and (cell_a.altitude > 0.85 or cell_b.altitude > 0.85 or cell_a.biome == "ocean" or cell_b.biome == "ocean"):
				continue

			var p_disp_b := EvoEcologyInteraction.get_archetype_prob(deme_b, state.decisions_catalog, "dispute")
			var p_over_b := EvoEcologyInteraction.get_archetype_prob(deme_b, state.decisions_catalog, "overexploit")
			var p_coop_b := EvoEcologyInteraction.get_archetype_prob(deme_b, state.decisions_catalog, "cooperate")
			var coop_ok_b := p_coop_b >= 0.14 or deme_b.last_dominant_decision_id == "dec-cooperate-store"

			var pair_key := "%s|%s" % [id_a, id_b]
			var is_rival := deme_a.lineage_id != deme_b.lineage_id and not EvoTypes.is_pact_active(state, id_a, id_b)
			var has_conflict_pressure := (
				(p_disp_a >= 0.12 or p_disp_b >= 0.12 or p_over_a >= 0.35 or p_over_b >= 0.35)
				if same_hex
				else (p_disp_a >= 0.25 or p_disp_b >= 0.25)
			)
			if is_rival and has_conflict_pressure:
				if not dispute_flow_pairs.has(pair_key):
					dispute_flow_pairs[pair_key] = true
					social_flow_pairs[pair_key] = true
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
					var coop_flow := EvoTypes.HexEdgeFlow.new()
					coop_flow.from_hex_id = cell_a.id
					coop_flow.to_hex_id = cell_b.id
					coop_flow.flow_type = "cooperate"
					coop_flow.intensity = snappedf(clampf((p_coop_a + p_coop_b) * 0.85, 0.30, 0.85), 0.01)
					coop_flow.from_deme_id = id_a
					coop_flow.to_deme_id = id_b
					state.active_flows.append(coop_flow)

	var filtered_disused: Array[Dictionary] = []
	for conn in state.disused_connections:
		var fa := str(conn["from_deme_id"]) if conn.has("from_deme_id") else ""
		var fb := str(conn["to_deme_id"]) if conn.has("to_deme_id") else ""
		if not state.demes.has(fa) or not state.demes.has(fb):
			continue
		var still_active_friendly := false
		for fl in state.active_flows:
			if fl.flow_type in ["exchange", "cooperate", "pact"]:
				if (fl.from_deme_id == fa and fl.to_deme_id == fb) or (fl.from_deme_id == fb and fl.to_deme_id == fa):
					still_active_friendly = true
					break
		if not still_active_friendly:
			var conn_age := int(conn.get("age", 0))
			if conn_age <= 0:
				conn_age = 1
				conn["age"] = 1
			if conn_age <= 8:
				conn["from_hex_id"] = (state.demes[fa] as EvoTypes.Deme).hex_id
				conn["to_hex_id"] = (state.demes[fb] as EvoTypes.Deme).hex_id
				filtered_disused.append(conn)
	state.disused_connections = filtered_disused
