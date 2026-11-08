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
		if deme_b.biological_trait_ids.has(tid) or deme_b.cultural_trait_ids.has(tid):
			intersection_count += 1
	for tid in deme_a.cultural_trait_ids:
		if deme_b.biological_trait_ids.has(tid) or deme_b.cultural_trait_ids.has(tid):
			intersection_count += 1
	var union_size := count_a + count_b - intersection_count
	if union_size <= 0:
		return 0.0
	return snappedf(1.0 - float(intersection_count) / float(union_size), 0.0001)


static func _strip_coord_suffix(name_str: String) -> String:
	return EvoWarfareInvasion._strip_coord_suffix(name_str)


static func _strip_migration_suffix(id_str: String) -> String:
	return EvoWarfareInvasion._strip_migration_suffix(id_str)


static func _compute_combat_forces(
	attacker: EvoTypes.Deme,
	warband_pop: int,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> Vector2:
	return EvoWarfareInvasion._compute_combat_forces(attacker, warband_pop, defender, state)


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
	return EvoWarfareInvasion._execute_territorial_invasion(
		attacker,
		origin_cell,
		target_cell,
		defender,
		state,
		lang,
		geo_flows,
		newly_created_demes,
		initial_pop_by_deme,
		pre_fission_pop_by_deme,
		effective_vec_by_deme
	)


static func compute_deme_salubrity(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> float:
	return EvoEpidemicSalubrity.compute_deme_salubrity(deme, cell, state)


static func _run_epidemic_phase(
	state: EvoTypes.WorldState,
	lang: String,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow]
) -> void:
	EvoEpidemicSalubrity._run_epidemic_phase(state, lang, turn_geopolitical_flows)


static func run_synoecism_phase(
	state: EvoTypes.WorldState,
	lang: String,
	newly_created_demes: Dictionary,
	had_lineage_contact: Dictionary,
	rival_dist_cache: Dictionary = {}
) -> void:
	EvoSynoecismUnions.run_synoecism_phase(state, lang, newly_created_demes, had_lineage_contact, rival_dist_cache)


static func _merge_deme_into(
	state: EvoTypes.WorldState,
	deme_a: EvoTypes.Deme,
	deme_b: EvoTypes.Deme,
	cell_a: EvoTypes.HexCell,
	newly_created_demes: Dictionary,
	had_lineage_contact: Dictionary,
	is_synoecism: bool,
	lang: String
) -> void:
	EvoSynoecismUnions._merge_deme_into(
		state,
		deme_a,
		deme_b,
		cell_a,
		newly_created_demes,
		had_lineage_contact,
		is_synoecism,
		lang
	)


static func _is_connected_to_founder(
	cell: EvoTypes.HexCell,
	founder_hex_id: String,
	mobility: float,
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> bool:
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


static func _min_distance_to_rival(
	cell: EvoTypes.HexCell,
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	cache: Dictionary = {}
) -> int:
	var has_personal_pact := false
	if not state.active_pacts.is_empty():
		var prefix := deme.id + "__"
		var suffix := "__" + deme.id
		for pk_var in state.active_pacts.keys():
			if int(state.active_pacts[pk_var]) >= 2:
				var pk := str(pk_var)
				if pk.begins_with(prefix) or pk.ends_with(suffix):
					has_personal_pact = true
					break
	var c_key := (deme.id + "|" + cell.id) if has_personal_pact else (deme.lineage_id + "|" + cell.id)
	if cache.has(c_key):
		return int(cache[c_key])
	var min_dist := 999
	var visited_hexes: Dictionary = {}
	for oid in state.demes.keys():
		var other: EvoTypes.Deme = state.demes[oid]
		if other.lineage_id == deme.lineage_id or (has_personal_pact and EvoTypes.is_pact_active(state, deme.id, other.id)):
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
		if not c.deme_ids.is_empty() and state.demes.has(c.deme_ids[0]):
			c_pop = (state.demes[c.deme_ids[0]] as EvoTypes.Deme).population
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
		deme.last_food_intake = snappedf(extracted, 0.01)
		deme.last_food_need = snappedf(metabolic_cost + fort_upkeep, 0.01)
		var delta_e := extracted - metabolic_cost - fort_upkeep
		var prev_reserves := deme.energy_reserves
		var reserve_draw := minf(-delta_e, prev_reserves * 0.50) if (delta_e < 0.0 and prev_reserves > 0.30 * float(deme.population)) else 0.0
		var effective_delta_e := delta_e + reserve_draw

		deme.last_energy_delta = snappedf(delta_e, 0.01)
		deme.energy_reserves = maxf(0.0, snappedf(prev_reserves + delta_e, 0.01))
		if deme.energy_reserves <= 0.0 and delta_e < -8.0 and deme.defense_tier > 0:
			deme.defense_tier = maxi(0, deme.defense_tier - 1)

		EvoEpidemicSalubrity.compute_deme_salubrity(deme, cell, state)

		var raw_growth := (effective_delta_e / maxf(10.0, float(deme.population))) * 0.45
		if raw_growth > 0.0:
			raw_growth *= clampf(0.30 + 0.70 * deme.salubrity, 0.25, 1.0)
			if not deme.biological_trait_ids.has("bio-r-strategy") and float(deme.population) > cell.carrying_capacity:
				var over_ratio := float(deme.population) / maxf(20.0, cell.carrying_capacity)
				raw_growth *= clampf(1.45 - over_ratio, 0.0, 1.0)
		if deme.biological_trait_ids.has("bio-r-strategy") and raw_growth > 0.0:
			var cell_pop: int = int(cell_pop_by_hex[cell.id])
			var crowding := float(cell_pop) / maxf(10.0, cell.carrying_capacity)
			if crowding < 0.55:
				raw_growth *= 1.28
			elif crowding > 1.0:
				raw_growth *= clampf(1.45 - crowding, 0.0, 1.0)
			elif crowding >= 0.65:
				raw_growth *= 1.05
			else:
				raw_growth *= 1.16
		var growth_rate := clampf(raw_growth, -0.45, 0.35)
		if deme.biological_trait_ids.has("bio-k-strategy"):
			growth_rate = clampf(growth_rate * 0.88, -0.45, 0.35)

		var pop_before_growth := deme.population
		var next_pop := int(roundf(float(deme.population) * (1.0 + growth_rate)))
		deme.population = (deme.population - 1) if (effective_delta_e < 0.0 and next_pop >= deme.population) else next_pop
		if deme.get_vital_status() == "starving" and delta_e < 0.0:
			var famine_losses := maxi(0, pop_before_growth - deme.population)
			EvoTypes.push_event(state, "famine", cell.id, cell.id, deme.id, deme.id, -delta_e, famine_losses)
			if not EvoEpidemicSalubrity._has_recent_famine_chronicle(state, deme.id):
				var fam_params := {
					"deme": deme.name,
					"hex": cell.id,
					"casualties": str(famine_losses)
				}
				var fam_entry := EvoTypes.ChronicleEntry.new()
				fam_entry.id = "chronicle-famine-%d-%s" % [state.generation, deme.id]
				fam_entry.generation = state.generation
				fam_entry.event_type = "famine"
				fam_entry.title = EvoI18n.t(lang, "chronicle_famine_title", fam_params)
				fam_entry.causal_explanation = EvoI18n.t(lang, "chronicle_famine_desc", fam_params)
				fam_entry.hex_id = cell.id
				fam_entry.deme_id = deme.id
				fam_entry.lineage_id = deme.lineage_id
				state.chronicle.append(fam_entry)

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

	EvoEpidemicSalubrity._run_epidemic_phase(state, lang, turn_geopolitical_flows)
	for did in state.demes.keys():
		pre_fission_pop_by_deme[did] = (state.demes[did] as EvoTypes.Deme).population

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

		if martial_trigger:
			if EvoWarfareInvasion.try_territorial_invasion(
				deme,
				current_cell,
				state,
				lang,
				turn_geopolitical_flows,
				newly_created_demes,
				initial_pop_by_deme,
				pre_fission_pop_by_deme,
				effective_vec_by_deme,
				rival_dist_cache
			):
				continue

		var is_emergency := (
			current_cell.current_resources < float(deme.population) * 0.20
			and deme.energy_reserves < float(deme.population) * 0.35
		)
		var has_warrior := deme.cultural_trait_ids.has("cul-warrior-expansion")
		var owned_rural_hexes: int = 0
		for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.owner_deme_id == deme.id and ncell.deme_ids.is_empty():
				owned_rural_hexes += 1
		var overcrowded_hinterland_bud := (
			deme.population >= 160
			and owned_rural_hexes >= 2
			and (float(deme.population) >= current_cell.carrying_capacity * 0.78 or p_migrate >= 0.10)
		)
		var martial_fission_trigger := martial_trigger and (not has_warrior or deme.get_village_tier() >= 2 or deme.population >= 85)
		var has_intentional_migration := (
			martial_fission_trigger
			or overcrowded_hinterland_bud
			or deme.last_dominant_decision_id == "dec-selective-migration"
			or p_migrate >= 0.15
			or current_cell.biome == "coastal_shallows"
			or is_emergency
		)
		var eff_p_migrate := p_migrate
		if martial_fission_trigger:
			eff_p_migrate = maxf(eff_p_migrate, 0.95)
		elif overcrowded_hinterland_bud:
			eff_p_migrate = maxf(eff_p_migrate, 0.55)
		elif is_emergency:
			eff_p_migrate = maxf(eff_p_migrate, 0.35)
		elif current_cell.biome == "coastal_shallows" or deme.last_dominant_decision_id == "dec-selective-migration":
			eff_p_migrate = maxf(eff_p_migrate, 0.25)
		var migrants := int(floor(float(deme.population) * eff_p_migrate * 0.45))
		var min_pop_for_forced_fission := 25 if (is_emergency or current_cell.biome == "coastal_shallows") else (85 if (has_warrior and deme.get_village_tier() == 1) else 55)
		if has_intentional_migration and deme.population >= min_pop_for_forced_fission and migrants < 10:
			migrants = 10

		if not has_intentional_migration:
			continue

		var cur_rival_dist: int = _min_distance_to_rival(current_cell, deme, state, rival_dist_cache)
		var min_keep_pop: int = 10 if (is_emergency or current_cell.biome == "coastal_shallows") else (45 if has_warrior else 15)
		if not is_emergency and current_cell.biome != "coastal_shallows":
			var c_tier: int = deme.get_village_tier()
			if c_tier == 4:
				min_keep_pop = 280
			elif c_tier == 3:
				min_keep_pop = 170
			elif c_tier == 2:
				min_keep_pop = 90 if deme.defense_tier == 1 else 120
			if not is_martial_expander and cur_rival_dist <= 2 and deme.defense_tier < 2:
				min_keep_pop = maxi(min_keep_pop, 115)

		migrants = mini(migrants, deme.population - min_keep_pop)
		if migrants < 10 or (deme.population - migrants) < min_keep_pop:
			continue

		var is_pure_martial_march := (
			martial_fission_trigger
			and deme.last_dominant_decision_id != "dec-selective-migration"
			and current_cell.biome != "coastal_shallows"
			and not is_emergency
		)
		if is_pure_martial_march and cur_rival_dist > 2 and _has_vanguard_closer_to_rival(deme, cur_rival_dist, state, rival_dist_cache):
			continue
		var v_eff_mobility := v_eff.spatial_mobility
		var mig_mobility := clampf(v_eff_mobility + p_migrate * 0.25, -1.5, 1.5)
		if is_emergency or current_cell.biome == "coastal_shallows":
			mig_mobility = maxf(mig_mobility, 0.35)
		if is_martial_expander:
			mig_mobility = maxf(mig_mobility, 0.35)
		var owned_rural: int = 0
		var candidates: Array[EvoTypes.HexCell] = []
		var seen_cand: Dictionary = {current_cell.id: true}
		for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.owner_deme_id == deme.id and ncell.deme_ids.is_empty():
				if ncell.land_use == "crops" or ncell.land_use == "pasture":
					owned_rural += 1
				for nn_id in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
					if seen_cand.has(nn_id):
						continue
					var nn_cell: EvoTypes.HexCell = state.cells[nn_id]
					if not is_hex_passable_for_deme(nn_cell, mig_mobility):
						continue
					if not nn_cell.deme_ids.is_empty() or nn_cell.owner_deme_id != "":
						continue
					var nn_dist := _min_distance_to_rival(nn_cell, deme, state, rival_dist_cache) if is_martial_expander else 999
					if is_pure_martial_march and (nn_dist > cur_rival_dist or (cur_rival_dist > 1 and nn_dist == cur_rival_dist)):
						continue
					seen_cand[nn_id] = true
					candidates.append(nn_cell)
			if seen_cand.has(nid):
				continue
			if not is_hex_passable_for_deme(ncell, mig_mobility):
				continue
			if not ncell.deme_ids.is_empty():
				continue
			if ncell.owner_deme_id != "" and not (is_martial_expander and ncell.owner_deme_id == deme.id):
				continue
			var n_dist := _min_distance_to_rival(ncell, deme, state, rival_dist_cache) if is_martial_expander else 999
			if is_pure_martial_march and (n_dist > cur_rival_dist or (cur_rival_dist > 1 and n_dist == cur_rival_dist)):
				continue
			seen_cand[nid] = true
			candidates.append(ncell)

		if candidates.is_empty():
			continue

		var max_rural_q: int = EvoRuralHinterland.get_max_rural_quota(deme.get_village_tier())
		var reserve_farms: int = maxi(0, mini(2, max_rural_q - owned_rural))
		if (
			not is_martial_expander
			and not is_emergency
			and not overcrowded_hinterland_bud
			and current_cell.biome != "coastal_shallows"
			and deme.population <= int(current_cell.carrying_capacity * 0.70)
			and candidates.size() <= reserve_farms
		):
			continue

		var target_cell: EvoTypes.HexCell = candidates[0]
		if candidates.size() > 1:
			var best_score := -INF
			for cand in candidates:
				var sc := cand.current_resources
				var dc := _min_distance_to_rival(cand, deme, state, rival_dist_cache)
				if has_warrior:
					if cur_rival_dist < 999 and (dc < cur_rival_dist or (cur_rival_dist == 1 and dc == 1)):
						sc += 45.0 + float(maxi(0, 10 - dc)) * 8.0
				else:
					if dc <= 1:
						var adj_rival_threat: float = 0.0
						for rnid in HexMath.get_neighbor_ids(cand.q, cand.r, state.cells):
							var rncell: EvoTypes.HexCell = state.cells[rnid]
							for roid in rncell.deme_ids:
								if state.demes.has(roid):
									var r_other: EvoTypes.Deme = state.demes[roid]
									if r_other.lineage_id != deme.lineage_id and not EvoTypes.is_pact_active(state, deme.id, r_other.id):
										adj_rival_threat += float(r_other.population) * (1.0 + 0.35 * float(r_other.defense_tier))
						sc -= 380.0 + adj_rival_threat * 1.5
					elif dc == 2:
						sc -= 80.0
					else:
						sc += float(mini(dc, 5)) * 45.0
				if sc > best_score:
					best_score = sc
					target_cell = cand
		target_cell.owner_deme_id = ""
		target_cell.land_use = "wild"
		target_cell.has_ruins = false
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
		if deme.has_meta("base_w_key"):
			daughter.set_meta("base_w_key", deme.get_meta("base_w_key"))
			daughter.set_meta("base_w_probs", deme.get_meta("base_w_probs"))
			daughter.set_meta("base_w_elig", deme.get_meta("base_w_elig"))
			daughter.set_meta("base_w_vec", deme.get_meta("base_w_vec"))

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
		EvoTypes.push_event(state, "colonize", current_cell.id, target_cell.id, deme.id, daughter_id, float(migrants), 0)

	var post_fission_ids := state.demes.keys()
	for did in post_fission_ids:
		if not state.demes.has(did):
			continue
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.population < 10:
			if state.cells.has(deme.hex_id):
				var ecell: EvoTypes.HexCell = state.cells[deme.hex_id]
				ecell.deme_ids.erase(deme.id)
				if ecell.biome != "ocean" and ecell.deme_ids.is_empty():
					ecell.has_ruins = true
				for rcid in HexMath.get_neighbor_ids(ecell.q, ecell.r, state.cells):
					var r_cell: EvoTypes.HexCell = state.cells[rcid]
					if r_cell.owner_deme_id == deme.id:
						r_cell.owner_deme_id = ""
						r_cell.land_use = "wild"
						r_cell.has_ruins = true
			EvoTypes.push_event(state, "extinction", deme.hex_id, deme.hex_id, deme.id, "", 0.0, deme.population)
			state.demes.erase(deme.id)
			var extinct_pacts: Array[String] = []
			for pk_var in state.active_pacts.keys():
				var pk := str(pk_var)
				var parts := pk.split("__")
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
				if tid == "cul-warrior-expansion" and deme.population >= 12:
					continue
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

	EvoSynoecismUnions.run_synoecism_phase(state, lang, newly_created_demes, had_lineage_contact, rival_dist_cache)

	EvoTurnEngine._revalidate_walled_unions(state)
	EvoRuralHinterland.enforce_rural_hinterland_quotas(state)

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
	var surv_coop: Array[float] = []
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(d.hex_id):
			continue
		surviving_demes.append(d)
		surviving_cells.append(state.cells[d.hex_id])
		var pd: float = 0.0
		var pc: float = 0.0
		for dec_id in d.last_decision_probabilities.keys():
			if state.decisions_catalog.has(dec_id):
				var arch := (state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).archetype
				var prob := float(d.last_decision_probabilities[dec_id])
				if arch == "dispute":
					pd += prob
				elif arch == "cooperate":
					pc += prob
		surv_disp.append(pd)
		surv_coop.append(pc)

	var s_count := surviving_demes.size()
	for idx_a in range(s_count):
		var deme_a := surviving_demes[idx_a]
		var id_a := deme_a.id
		var cell_a := surviving_cells[idx_a]
		var qa := cell_a.q
		var ra := cell_a.r
		var bad_a := cell_a.altitude > 0.85 or cell_a.biome == "ocean"
		var p_disp_a := surv_disp[idx_a]
		var p_coop_a := surv_coop[idx_a]
		var coop_ok_a := p_coop_a >= 0.14 or deme_a.last_dominant_decision_id == "dec-cooperate-store"

		for idx_b in range(idx_a + 1, s_count):
			var cell_b := surviving_cells[idx_b]
			var dq := qa - cell_b.q
			var dr := ra - cell_b.r
			if absi(dq) > 1 or absi(dr) > 1 or absi(dq + dr) > 1:
				continue
			if bad_a or cell_b.altitude > 0.85 or cell_b.biome == "ocean":
				continue

			var deme_b := surviving_demes[idx_b]
			var id_b := deme_b.id
			var p_disp_b := surv_disp[idx_b]
			var p_coop_b := surv_coop[idx_b]
			var coop_ok_b := p_coop_b >= 0.14 or deme_b.last_dominant_decision_id == "dec-cooperate-store"

			var pair_key := "%s|%s" % [id_a, id_b]
			var pact_key := ("%s__%s" % [id_a, id_b]) if id_a < id_b else ("%s__%s" % [id_b, id_a])
			var is_rival := deme_a.lineage_id != deme_b.lineage_id and int(state.active_pacts.get(pact_key, 0)) < 2
			var has_conflict_pressure := p_disp_a >= 0.25 or p_disp_b >= 0.25
			if is_rival and has_conflict_pressure:
				if not dispute_flow_pairs.has(pair_key):
					dispute_flow_pairs[pair_key] = true
					social_flow_pairs[pair_key] = true
					var hex_pair_key := ("%s|%s" % [cell_a.id, cell_b.id]) if cell_a.id <= cell_b.id else ("%s|%s" % [cell_b.id, cell_a.id])
					if not dispute_flow_pairs.has(hex_pair_key):
						dispute_flow_pairs[hex_pair_key] = true
						var disp_flow := EvoTypes.HexEdgeFlow.new()
						disp_flow.from_hex_id = cell_a.id
						disp_flow.to_hex_id = cell_b.id
						disp_flow.flow_type = "dispute"
						disp_flow.intensity = snappedf(clampf(maxf(p_disp_a, p_disp_b), 0.35, 0.90), 0.01)
						disp_flow.from_deme_id = id_a
						disp_flow.to_deme_id = id_b
						state.active_flows.append(disp_flow)
			elif coop_ok_a and coop_ok_b:
				if not social_flow_pairs.has(pair_key):
					social_flow_pairs[pair_key] = true
					friendly_flow_pairs[pair_key] = true
					friendly_flow_pairs["%s|%s" % [id_b, id_a]] = true
					var hex_pair_key := ("%s|%s" % [cell_a.id, cell_b.id]) if cell_a.id <= cell_b.id else ("%s|%s" % [cell_b.id, cell_a.id])
					if not social_flow_pairs.has(hex_pair_key):
						social_flow_pairs[hex_pair_key] = true
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
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		d.last_population_delta = d.population - int(initial_pop_by_deme.get(d.id, d.population))
