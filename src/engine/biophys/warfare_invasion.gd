class_name EvoWarfareInvasion
extends RefCounted


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


static func _compute_combat_forces(
	attacker: EvoTypes.Deme,
	warband_pop: int,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> Vector2:
	var att_vec := EvoCatalog.compute_deme_vector(attacker, state.traits_catalog)
	var def_vec := EvoCatalog.compute_deme_vector(defender, state.traits_catalog)
	var pact_bonus := EvoDiplomacyRaids.compute_pact_defense_bonus(defender, state)
	var p_att_disp := EvoEcologyInteraction.get_archetype_prob(attacker, state.decisions_catalog, "dispute")
	if p_att_disp <= 0.0 and attacker.last_decision_probabilities.has("dec-territorial-dispute"):
		p_att_disp = float(attacker.last_decision_probabilities["dec-territorial-dispute"])

	var att_warrior := 0.45 if attacker.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var att_r_strat := 0.20 if attacker.biological_trait_ids.has("bio-r-strategy") else 0.0
	var def_warrior := 0.35 if defender.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var fort_bonus: float = EvoEcologyInteraction.DEFENSE_TIER_BONUS[clampi(defender.defense_tier, 0, 3)]
	var eff_def_pop := float(defender.population)
	var union_fort_bonus := 0.0

	var def_rural_bonus := 0.0
	var flanking_support_pop := 0.0
	var coalition_support_pop := 0.0
	if state.cells.has(defender.hex_id):
		var dcell: EvoTypes.HexCell = state.cells[defender.hex_id]
		var nids := HexMath.get_neighbor_ids(dcell.q, dcell.r, state.cells)
		var owned_rural_count := 0
		for nid in nids:
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.owner_deme_id == defender.id and (ncell.land_use == "crops" or ncell.land_use == "pasture"):
				owned_rural_count += 1
			for oid in ncell.deme_ids:
				if oid != attacker.id and oid != defender.id and state.demes.has(oid):
					var od: EvoTypes.Deme = state.demes[oid]
					if od.population > 0 and (od.lineage_id == attacker.lineage_id or EvoTypes.is_pact_active(state, attacker.id, od.id)):
						flanking_support_pop += float(od.population)
						coalition_support_pop += 0.32 * float(od.population)
		def_rural_bonus = minf(0.24, float(owned_rural_count) * 0.08)
		if defender.walled_union_id != "":
			for nid in nids:
				var ncell: EvoTypes.HexCell = state.cells[nid]
				for p_id in ncell.deme_ids:
					if p_id != defender.id and state.demes.has(p_id):
						var u_partner: EvoTypes.Deme = state.demes[p_id]
						if (
							u_partner.population > 0
							and u_partner.walled_union_id == defender.walled_union_id
							and int(state.active_pacts.get(EvoTypes.make_pair_key(defender.id, u_partner.id), 0)) >= 0
						):
							eff_def_pop += 0.55 * float(u_partner.population)
							union_fort_bonus += 0.25 * EvoEcologyInteraction.DEFENSE_TIER_BONUS[clampi(u_partner.defense_tier, 0, 3)]

	var eff_warband_pop: float = float(warband_pop) + minf(float(warband_pop) * 1.20, coalition_support_pop)
	var flank_bonus: float = 1.0 + clampf((flanking_support_pop / maxf(25.0, float(defender.population))) * 0.38, 0.0, 0.50)
	var att_mult := (
		(1.0 + 0.55 * maxf(0.0, att_vec.extraction_efficiency) + att_warrior + att_r_strat)
		* (0.75 + p_att_disp)
	)
	var att_force: float = eff_warband_pop * att_mult * flank_bonus
	var def_force := (
		eff_def_pop
		* (1.0 + 0.60 * maxf(0.0, def_vec.social_cohesion) + pact_bonus + def_warrior + fort_bonus + union_fort_bonus + def_rural_bonus)
	)
	return Vector2(att_force, def_force)


static func _resolve_war_pillage_or_conquest(
	attacker: EvoTypes.Deme,
	origin_cell: EvoTypes.HexCell,
	target_cell: EvoTypes.HexCell,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	force_ratio: float,
	def_tier: int
) -> void:
	var r_plunder: float = 0.0
	var pillaged_rural := false
	if force_ratio >= 0.75 and def_tier <= 1:
		for rcid in HexMath.get_neighbor_ids(target_cell.q, target_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[rcid]
			if ncell.owner_deme_id == defender.id and (ncell.land_use == "crops" or ncell.land_use == "pasture"):
				ncell.owner_deme_id = ""
				ncell.land_use = "wild"
				ncell.has_ruins = true
				r_plunder = snappedf(minf(defender.energy_reserves * 0.18, 22.0), 0.01)
				pillaged_rural = true
				EvoTypes.push_event(state, "pillage", origin_cell.id, ncell.id, attacker.id, defender.id, r_plunder, 0)
				break
		if not pillaged_rural and def_tier == 0:
			r_plunder = snappedf(minf(defender.energy_reserves * 0.12, 14.0), 0.01)
	if r_plunder > 0.0:
		defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - r_plunder, 0.01))
		attacker.energy_reserves = minf(220.0, snappedf(attacker.energy_reserves + r_plunder, 0.01))


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
) -> bool:
	var original_pop := attacker.population
	var warband_pop := int(round(float(attacker.population) * 0.48))
	attacker.population -= warband_pop

	var forces := _compute_combat_forces(attacker, warband_pop, defender, state)
	var att_force := forces.x
	var def_force := forces.y

	if att_force >= def_force * 0.92:
		var captured_tier := maxi(0, defender.defense_tier - 1)
		var att_loss := maxi(2, int(round(float(warband_pop) * clampf(0.22 * (def_force / maxf(1.0, att_force)), 0.08, 0.35))))
		var def_loss := maxi(4, int(round(float(defender.population) * clampf(0.35 * (att_force / maxf(1.0, def_force)), 0.20, 0.55))))
		var loot := roundf(defender.energy_reserves * 0.38)
		defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - loot, 0.01))
		defender.population = maxi(0, defender.population - def_loss)
		pre_fission_pop_by_deme[defender.id] = defender.population

		var energy_fraction := attacker.energy_reserves * (float(warband_pop) / float(maxi(1, original_pop)))
		attacker.energy_reserves = maxf(0.0, snappedf(attacker.energy_reserves - energy_fraction, 0.01))
		var warband_energy := snappedf(energy_fraction * 0.85 + loot, 0.01)
		var surviving_warband := maxi(10, warband_pop - att_loss)

		var retreated := false
		if defender.population >= 10:
			var retreat_candidates: Array[EvoTypes.HexCell] = []
			for nid in HexMath.get_neighbor_ids(target_cell.q, target_cell.r, state.cells):
				if nid == origin_cell.id:
					continue
				var rcell: EvoTypes.HexCell = state.cells[nid]
				if rcell.biome != "ocean" and rcell.altitude <= 0.85 and rcell.deme_ids.is_empty():
					retreat_candidates.append(rcell)
			retreat_candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				return a.current_resources > b.current_resources
			)
			if not retreat_candidates.is_empty():
				var retreat_cell := retreat_candidates[0]
				retreat_cell.owner_deme_id = ""
				retreat_cell.land_use = "wild"
				retreat_cell.has_ruins = false
				target_cell.deme_ids.erase(defender.id)
				defender.hex_id = retreat_cell.id
				defender.defense_tier = 0
				defender.walled_union_id = ""
				retreat_cell.deme_ids.append(defender.id)
				retreated = true
		if not retreated:
			surviving_warband += maxi(0, defender.population / 3)
			target_cell.deme_ids.erase(defender.id)
			defender.population = 0
			defender.defense_tier = 0
			defender.walled_union_id = ""
			pre_fission_pop_by_deme[defender.id] = 0

		state.active_pacts[EvoTypes.make_pair_key(attacker.id, defender.id)] = -3

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

		var wb_tier := warband.get_village_tier()
		var wb_max_rural: int = EvoRuralHinterland.get_max_rural_quota(wb_tier)
		var wb_rural: Array[EvoTypes.HexCell] = []
		for rcid in HexMath.get_neighbor_ids(target_cell.q, target_cell.r, state.cells):
			var r_cell: EvoTypes.HexCell = state.cells[rcid]
			if r_cell.owner_deme_id == defender.id:
				r_cell.owner_deme_id = warband_id
			if r_cell.owner_deme_id == warband_id:
				wb_rural.append(r_cell)
		if wb_rural.size() > wb_max_rural:
			wb_rural.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				return a.current_resources < b.current_resources
			)
			while wb_rural.size() > wb_max_rural:
				var rel_cell: EvoTypes.HexCell = wb_rural.pop_front()
				rel_cell.owner_deme_id = ""
				rel_cell.land_use = "wild"

		target_cell.owner_deme_id = ""
		target_cell.land_use = "wild"
		target_cell.has_ruins = false
		target_cell.deme_ids.clear()
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
		EvoTypes.push_event(state, "war", origin_cell.id, target_cell.id, attacker.id, defender.id, loot, att_loss + def_loss)

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
		return true
	else:
		var def_tier := clampi(defender.defense_tier, 0, 3)
		var force_ratio: float = clampf(att_force / maxf(1.0, def_force), 0.05, 1.0)
		var def_cas_scale: float = EvoEcologyInteraction.DEFENSE_ATTENUATION_SCALE[def_tier]
		var scaled_def_loss: int = int(round(float(defender.population) * 0.11 * pow(force_ratio, 1.4) * def_cas_scale))
		var def_losses: int = clampi(scaled_def_loss, 1, maxi(1, int(round(float(warband_pop) * 0.35 * def_cas_scale))))
		defender.population = maxi(10, defender.population - def_losses)
		pre_fission_pop_by_deme[defender.id] = defender.population

		var att_losses: int = maxi(2, int(round(float(warband_pop) * (0.45 + 0.10 * float(def_tier)))))
		var surviving_attackers: int = maxi(0, warband_pop - att_losses)
		var att_cell: EvoTypes.HexCell = state.cells[attacker.hex_id] if state.cells.has(attacker.hex_id) else origin_cell
		if attacker.population > 0 and (
			attacker.hex_id == target_cell.id
			or (att_cell != null and HexMath.hex_distance(att_cell.q, att_cell.r, target_cell.q, target_cell.r) <= 1)
		):
			attacker.population = maxi(10, attacker.population + surviving_attackers)
		attacker.energy_reserves = maxf(0.0, snappedf(attacker.energy_reserves - 15.0, 0.01))

		_resolve_war_pillage_or_conquest(attacker, origin_cell, target_cell, defender, state, force_ratio, def_tier)

		for pk in state.active_pacts.keys():
			var parts := str(pk).split("__")
			if parts.size() == 2 and (parts[0] == defender.id or parts[1] == defender.id):
				if int(state.active_pacts[pk]) >= 2:
					state.active_pacts[pk] = int(state.active_pacts[pk]) + 1

		var ad_pk := EvoTypes.make_pair_key(attacker.id, defender.id)
		if int(state.active_pacts.get(ad_pk, 0)) <= 0:
			state.active_pacts[ad_pk] = mini(-2, int(state.active_pacts.get(ad_pk, 0)))

		var flow := EvoTypes.HexEdgeFlow.new()
		flow.from_hex_id = origin_cell.id
		flow.to_hex_id = target_cell.id
		flow.flow_type = "war"
		flow.intensity = 0.85
		flow.from_deme_id = attacker.id
		flow.to_deme_id = defender.id
		state.active_flows.append(flow)
		geo_flows.append(flow)
		EvoTypes.push_event(state, "war_repelled", origin_cell.id, target_cell.id, attacker.id, defender.id, 0.0, att_losses + def_losses)

		if def_tier >= 1:
			var is_isolated_defender := defender.merged_count == 0 and EvoDiplomacyRaids.compute_pact_defense_bonus(defender, state) <= 0.0
			if force_ratio >= 0.75:
				defender.energy_reserves = maxf(0.0, snappedf(defender.energy_reserves - 6.0, 0.01))
			if (
				att_force >= def_force * 0.82
				and float(warband_pop) >= float(defender.population) * 0.45
				and (defender.energy_reserves < 10.0 or is_isolated_defender)
			):
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
			EvoTypes.push_event(state, "siege", origin_cell.id, target_cell.id, attacker.id, defender.id, float(defender.defense_tier), def_losses)

			var siege_params := {
				"defender": defender.name,
				"attacker": attacker.name,
				"hex": target_cell.id,
				"casualties": str(att_losses + def_losses)
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
			"casualties": str(att_losses + def_losses)
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
		return false


static func try_territorial_invasion(
	deme: EvoTypes.Deme,
	current_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	lang: String,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow],
	newly_created_demes: Dictionary,
	initial_pop_by_deme: Dictionary,
	pre_fission_pop_by_deme: Dictionary,
	effective_vec_by_deme: Dictionary,
	rival_dist_cache: Dictionary
) -> bool:
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
			var already_raided := false
			for fl in state.active_flows:
				if (fl.flow_type == "raid" and fl.from_deme_id == deme.id and fl.to_deme_id == other.id) or (fl.flow_type == "tribute" and ((fl.from_deme_id == other.id and fl.to_deme_id == deme.id) or (fl.from_deme_id == deme.id and fl.to_deme_id == other.id))):
					already_raided = true
					break
			if already_raided:
				continue
			var forces := _compute_combat_forces(deme, warband_pop, other, state)
			if (
				forces.x >= forces.y * 0.82
				or (other.defense_tier <= 1 and forces.x >= forces.y * 0.55)
				or (deme.cultural_trait_ids.has("cul-warrior-expansion") and other.defense_tier <= 1 and forces.x >= forces.y * 0.50)
			):
				var ratio := forces.x / maxf(1.0, forces.y)
				if ratio > best_ratio:
					best_ratio = ratio
					best_target_cell = ncell
					best_defender = other

	if best_target_cell != null and best_defender != null:
		var invaded := _execute_territorial_invasion(
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
		if invaded:
			rival_dist_cache.clear()
		return true
	return false
