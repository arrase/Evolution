class_name EvoEcologyInteraction
extends RefCounted

const DEFENSE_TIER_BONUS: Array[float] = [0.0, 0.45, 0.95, 1.55]
const DEFENSE_ATTENUATION_SCALE: Array[float] = [1.0, 0.75, 0.50, 0.30]


static func get_max_rural_quota(tier: int) -> int:
	return 0 if tier < 2 else (1 if tier == 2 else (2 if tier == 3 else 4))


static func compute_effective_vector(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> EvoTypes.BiophysicalVector:
	var cost: float = 0.0
	var extract: float = 0.0
	var eco: float = 0.0
	var mobility: float = 0.0
	var cohesion: float = 0.0
	var threshold: float = 0.0

	for tid in deme.biological_trait_ids:
		if state.traits_catalog.has(tid):
			var v := (state.traits_catalog[tid] as EvoTypes.TraitDef).vector
			cost += v.metabolic_cost
			extract += v.extraction_efficiency
			eco += v.ecological_impact
			mobility += v.spatial_mobility
			cohesion += v.social_cohesion
			threshold += v.transmission_threshold

	for tid in deme.cultural_trait_ids:
		if state.traits_catalog.has(tid):
			var v := (state.traits_catalog[tid] as EvoTypes.TraitDef).vector
			cost += v.metabolic_cost
			extract += v.extraction_efficiency
			eco += v.ecological_impact
			mobility += v.spatial_mobility
			cohesion += v.social_cohesion
			threshold += v.transmission_threshold

	for dec_id in deme.last_decision_probabilities.keys():
		var prob: float = float(deme.last_decision_probabilities[dec_id])
		if prob > 0.0 and state.decisions_catalog.has(dec_id):
			var v := (state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).vector
			cost += prob * v.metabolic_cost
			extract += prob * v.extraction_efficiency
			eco += prob * v.ecological_impact
			mobility += prob * v.spatial_mobility
			cohesion += prob * v.social_cohesion
			threshold += prob * v.transmission_threshold

	return EvoTypes.BiophysicalVector.new(
		snappedf(clampf(cost, -1.5, 1.5), 0.0001),
		snappedf(clampf(extract, -1.5, 1.5), 0.0001),
		snappedf(clampf(eco, -1.5, 1.5), 0.0001),
		snappedf(clampf(mobility, -1.5, 1.5), 0.0001),
		snappedf(clampf(cohesion, -1.5, 1.5), 0.0001),
		snappedf(clampf(threshold, 0.0, 1.5), 0.0001)
	)


static func get_archetype_prob(
	deme: EvoTypes.Deme,
	decisions_catalog: Dictionary,
	archetype: String
) -> float:
	var total: float = 0.0
	for dec_id in deme.last_decision_probabilities.keys():
		if decisions_catalog.has(dec_id):
			var dec: EvoTypes.DecisionDef = decisions_catalog[dec_id]
			if dec.archetype == archetype:
				total += float(deme.last_decision_probabilities[dec_id])
	return total


static func _can_acquire_trait(
	deme: EvoTypes.Deme,
	trait_id: String,
	traits_catalog: Dictionary
) -> bool:
	if deme.cultural_trait_ids.has(trait_id) or deme.biological_trait_ids.has(trait_id):
		return false
	if not traits_catalog.has(trait_id):
		return false
	var tdef: EvoTypes.TraitDef = traits_catalog[trait_id]
	for existing_id in deme.biological_trait_ids:
		if tdef.mutually_exclusive_with.has(existing_id):
			return false
		if traits_catalog.has(existing_id) and (traits_catalog[existing_id] as EvoTypes.TraitDef).mutually_exclusive_with.has(trait_id):
			return false
	for existing_id in deme.cultural_trait_ids:
		if tdef.mutually_exclusive_with.has(existing_id):
			return false
		if traits_catalog.has(existing_id) and (traits_catalog[existing_id] as EvoTypes.TraitDef).mutually_exclusive_with.has(trait_id):
			return false
	return true


static func compute_pact_defense_bonus(
	victim: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> float:
	if (state.active_pacts.is_empty() and victim.walled_union_id == "") or not state.cells.has(victim.hex_id):
		return 0.0
	var v_cell: EvoTypes.HexCell = state.cells[victim.hex_id]
	var bonus: float = 0.0
	for ally_id in v_cell.deme_ids:
		if ally_id != victim.id and state.demes.has(ally_id):
			var ally: EvoTypes.Deme = state.demes[ally_id]
			var in_union := victim.walled_union_id != "" and ally.walled_union_id == victim.walled_union_id
			if in_union or EvoTypes.is_pact_active(state, victim.id, ally_id):
				bonus += 0.25 * clampf(float(ally.population) / maxf(20.0, float(victim.population)), 0.4, 1.5) + 0.08 * float(ally.defense_tier)
	for nid in HexMath.get_neighbor_ids(v_cell.q, v_cell.r, state.cells):
		var a_cell: EvoTypes.HexCell = state.cells[nid]
		for ally_id in a_cell.deme_ids:
			if ally_id != victim.id and state.demes.has(ally_id):
				var ally: EvoTypes.Deme = state.demes[ally_id]
				var in_union := victim.walled_union_id != "" and ally.walled_union_id == victim.walled_union_id
				if in_union or EvoTypes.is_pact_active(state, victim.id, ally_id):
					bonus += 0.25 * clampf(float(ally.population) / maxf(20.0, float(victim.population)), 0.4, 1.5) + 0.08 * float(ally.defense_tier)
					if in_union:
						bonus += 0.20
	return clampf(bonus, 0.0, 1.10)


static func _compute_caloric_need(
	deme: EvoTypes.Deme,
	v_eff: EvoTypes.BiophysicalVector
) -> float:
	return maxf(1.0, float(deme.population) * 0.42 * (1.0 + 0.55 * v_eff.metabolic_cost))


static func _is_deme_stressed_for_betrayal(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	v_eff: EvoTypes.BiophysicalVector,
	extracted: float
) -> bool:
	var needed := _compute_caloric_need(deme, v_eff)
	var adequacy := extracted / needed
	var has_resource_deficit := (
		adequacy < 0.98
		or deme.energy_reserves < 45.0
		or cell.carrying_capacity < cell.carrying_capacity_max * 0.72
	)
	if state.season == "dry_cold":
		return has_resource_deficit or deme.energy_reserves < 60.0
	return adequacy < 0.85 or deme.energy_reserves < 35.0


static func _is_opportunistic_betrayer(
	deme: EvoTypes.Deme,
	p_coop: float,
	_p_exch: float,
	p_disp: float,
	p_over: float,
	v_eff: EvoTypes.BiophysicalVector,
	formal_pact_active: bool,
	victim_defense_tier: int = 0
) -> bool:
	if not formal_pact_active:
		return false
	var has_warrior: bool = deme.cultural_trait_ids.has("cul-warrior-expansion")
	if deme.cultural_trait_ids.has("cul-communal-conservation") and not has_warrior and p_coop >= 0.22:
		return false
	if v_eff.social_cohesion > 0.85 and not has_warrior and p_coop >= 0.38:
		return false
	var agg_score: float = (
		p_disp
		+ 0.75 * p_over
		+ (0.16 if has_warrior else 0.0)
		+ (0.12 if deme.biological_trait_ids.has("bio-r-strategy") else 0.0)
		+ (0.10 if deme.cultural_trait_ids.has("cul-extraction-tools") else 0.0)
		+ (0.06 if (deme.cultural_trait_ids.has("cul-interdeme-barter") or deme.cultural_trait_ids.has("cul-fire-processing")) else 0.0)
	)
	return agg_score >= (0.26 if victim_defense_tier >= 2 else 0.18) or p_disp >= 0.16


static func _execute_betrayal(
	betrayer: EvoTypes.Deme,
	victim: EvoTypes.Deme,
	c_betrayer: EvoTypes.HexCell,
	c_victim: EvoTypes.HexCell,
	pair_key: String,
	state: EvoTypes.WorldState,
	lang: String,
	extracted_energy_by_deme: Dictionary,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow]
) -> void:
	var ext_victim := float(extracted_energy_by_deme.get(victim.id, 0.0))
	var impact_scale: float = clampf(float(betrayer.population) / maxf(20.0, float(victim.population)), 0.25, 1.35) * DEFENSE_ATTENUATION_SCALE[clampi(victim.defense_tier, 0, 3)]
	var desired_loot: float = snappedf(clampf((victim.energy_reserves * 0.30 + ext_victim * 0.25) * impact_scale, 8.0, 45.0), 0.01)
	var from_reserves := minf(victim.energy_reserves, desired_loot * 0.70)
	var from_ext := minf(ext_victim, desired_loot - from_reserves)
	if from_reserves + from_ext < desired_loot:
		from_reserves = minf(victim.energy_reserves, from_reserves + (desired_loot - (from_reserves + from_ext)))
	var loot := snappedf(from_reserves + from_ext, 0.01)
	victim.energy_reserves = maxf(0.0, snappedf(victim.energy_reserves - from_reserves, 0.01))
	extracted_energy_by_deme[victim.id] = maxf(0.0, snappedf(ext_victim - from_ext, 0.01))
	betrayer.energy_reserves = minf(220.0, snappedf(betrayer.energy_reserves + loot, 0.01))

	var base_cas_rate: float = 0.14 if betrayer.cultural_trait_ids.has("cul-warrior-expansion") else 0.09
	var casualties: int = maxi(2, mini(int(round(float(betrayer.population) * 0.45)), int(round(float(victim.population) * clampf(base_cas_rate * impact_scale, 0.03, 0.18)))))
	victim.population = maxi(5, victim.population - casualties)

	state.active_pacts[pair_key] = -4

	if c_betrayer.id != c_victim.id:
		var updated_existing := false
		for conn in state.disused_connections:
			var ca := str(conn.get("from_deme_id", ""))
			var cb := str(conn.get("to_deme_id", ""))
			if (ca == betrayer.id and cb == victim.id) or (ca == victim.id and cb == betrayer.id):
				conn["from_hex_id"] = c_betrayer.id
				conn["to_hex_id"] = c_victim.id
				conn["age"] = 1
				conn["broken_gen"] = state.generation
				updated_existing = true
				break
		if not updated_existing:
			state.disused_connections.append({
				"from_hex_id": c_betrayer.id,
				"to_hex_id": c_victim.id,
				"from_deme_id": betrayer.id,
				"to_deme_id": victim.id,
				"age": 1,
				"broken_gen": state.generation
			})

	var flow := EvoTypes.HexEdgeFlow.new()
	flow.from_hex_id = c_betrayer.id
	flow.to_hex_id = c_victim.id
	flow.flow_type = "betrayal"
	flow.intensity = 1.0
	flow.from_deme_id = betrayer.id
	flow.to_deme_id = victim.id
	state.active_flows.append(flow)
	turn_geopolitical_flows.append(flow)

	var params := {
		"betrayer": betrayer.name,
		"victim": victim.name,
		"loot": str(int(round(loot))),
		"hex": c_victim.id
	}
	var entry := EvoTypes.ChronicleEntry.new()
	entry.id = "chronicle-betrayal-%d-%s-%s" % [state.generation, betrayer.id, victim.id]
	entry.generation = state.generation
	entry.event_type = "betrayal"
	entry.title = EvoI18n.t(lang, "chronicle_betrayal_title", params)
	entry.causal_explanation = EvoI18n.t(lang, "chronicle_betrayal_desc", params)
	entry.hex_id = c_victim.id
	entry.deme_id = betrayer.id
	entry.lineage_id = betrayer.lineage_id
	state.chronicle.append(entry)


static func _run_pacts_and_betrayals(
	state: EvoTypes.WorldState,
	lang: String,
	effective_vec_by_deme: Dictionary,
	extracted_energy_by_deme: Dictionary,
	symbiosis_bonus_applied: Dictionary,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow],
	betrayed_pairs_this_turn: Dictionary,
	arch_probs: Dictionary,
	adjacent_pairs: Array,
	existing_flows_by_key: Dictionary
) -> void:
	var has_warrior: Dictionary = {}
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		has_warrior[d.id] = d.cultural_trait_ids.has("cul-warrior-expansion")

	var warrior_threat_by_deme: Dictionary = {}
	for pair in adjacent_pairs:
		var da: EvoTypes.Deme = pair[0]
		var db: EvoTypes.Deme = pair[2]
		if da.lineage_id != db.lineage_id and not EvoTypes.is_pact_active(state, da.id, db.id):
			if bool(has_warrior[da.id]):
				warrior_threat_by_deme[db.id] = true
			if bool(has_warrior[db.id]):
				warrior_threat_by_deme[da.id] = true

	var logged_pact_hex_pairs: Dictionary = {}

	for pair in adjacent_pairs:
		var d1: EvoTypes.Deme = pair[0]
		var c1: EvoTypes.HexCell = pair[1]
		var d2: EvoTypes.Deme = pair[2]
		var c2: EvoTypes.HexCell = pair[3]
		var pair_key: String = pair[4]

		var pact_turns := int(state.active_pacts.get(pair_key, 0))
		if pact_turns < 0:
			pact_turns += 1
			if pact_turns == 0:
				state.active_pacts.erase(pair_key)
			else:
				state.active_pacts[pair_key] = pact_turns
			continue

		var ap1: Array = arch_probs[d1.id]
		var p_coop_1: float = float(ap1[0])
		var p_exch_1: float = float(ap1[1])
		var p_disp_1: float = float(ap1[2])
		var p_over_1: float = float(ap1[3])

		var formal_pact := pact_turns >= 2

		var v1: EvoTypes.BiophysicalVector = effective_vec_by_deme[d1.id]
		var v2: EvoTypes.BiophysicalVector = effective_vec_by_deme[d2.id]
		var ext_1 := float(extracted_energy_by_deme.get(d1.id, 0.0))
		var ext_2 := float(extracted_energy_by_deme.get(d2.id, 0.0))

		var ap2: Array = arch_probs[d2.id]
		var p_coop_2: float = float(ap2[0])
		var p_exch_2: float = float(ap2[1])
		var p_disp_2: float = float(ap2[2])
		var p_over_2: float = float(ap2[3])

		if formal_pact and not (d1.walled_union_id != "" and d1.walled_union_id == d2.walled_union_id):
			var d1_wants_betray := _is_opportunistic_betrayer(
				d1, p_coop_1, p_exch_1, p_disp_1, p_over_1, v1, formal_pact, d2.defense_tier
			)
			var d2_wants_betray := _is_opportunistic_betrayer(
				d2, p_coop_2, p_exch_2, p_disp_2, p_over_2, v2, formal_pact, d1.defense_tier
			)
			var d1_can_betray := float(d1.population) >= float(d2.population) * 0.45 and d2.energy_reserves >= 45.0
			var d2_can_betray := float(d2.population) >= float(d1.population) * 0.45 and d1.energy_reserves >= 45.0
			var d1_winter_greed := (
				d1.lineage_id != d2.lineage_id
				and state.season == "dry_cold"
				and d2.energy_reserves >= 75.0
				and d2.energy_reserves > d1.energy_reserves * 1.25
			)
			var d2_winter_greed := (
				d1.lineage_id != d2.lineage_id
				and state.season == "dry_cold"
				and d1.energy_reserves >= 75.0
				and d1.energy_reserves > d2.energy_reserves * 1.25
			)
			var d1_betrays := (
				d1_wants_betray
				and d1_can_betray
				and (_is_deme_stressed_for_betrayal(d1, c1, state, v1, ext_1) or d1_winter_greed)
			)
			var d2_betrays := (
				d2_wants_betray
				and d2_can_betray
				and (_is_deme_stressed_for_betrayal(d2, c2, state, v2, ext_2) or d2_winter_greed)
			)
			if d1_betrays or d2_betrays:
				betrayed_pairs_this_turn[pair_key] = true
				if d1_betrays:
					_execute_betrayal(d1, d2, c1, c2, pair_key, state, lang, extracted_energy_by_deme, turn_geopolitical_flows)
				else:
					_execute_betrayal(d2, d1, c2, c1, pair_key, state, lang, extracted_energy_by_deme, turn_geopolitical_flows)
				continue

		var both_strong_coop := (
			p_coop_1 + p_exch_1 >= 0.36 and p_disp_1 < 0.18
			and p_coop_2 + p_exch_2 >= 0.36 and p_disp_2 < 0.18
		)
		var has_warrior_threat := bool(warrior_threat_by_deme.get(d1.id, false)) or bool(warrior_threat_by_deme.get(d2.id, false))
		var coop_thresh := 0.22 if has_warrior_threat else 0.30
		var coop_1: bool = p_coop_1 + p_exch_1 >= coop_thresh and p_disp_1 < 0.22 and (not bool(has_warrior[d1.id]) or both_strong_coop)
		var coop_2: bool = p_coop_2 + p_exch_2 >= coop_thresh and p_disp_2 < 0.22 and (not bool(has_warrior[d2.id]) or both_strong_coop)
		if coop_1 and coop_2:
			var next_turns := pact_turns + 1
			state.active_pacts[pair_key] = next_turns
			var hex_pair_key := ("%s|%s" % [c1.id, c2.id]) if c1.id <= c2.id else ("%s|%s" % [c2.id, c1.id])
			if next_turns == 2 and not logged_pact_hex_pairs.has(hex_pair_key):
				logged_pact_hex_pairs[hex_pair_key] = true
				var hex_label := c1.id if c1.id == c2.id else "%s <-> %s" % [c1.id, c2.id]
				var params := {
					"deme_a": d1.name,
					"deme_b": d2.name,
					"hex": hex_label
				}
				var entry := EvoTypes.ChronicleEntry.new()
				entry.id = "chronicle-pact-%d-%s" % [state.generation, pair_key]
				entry.generation = state.generation
				entry.event_type = "pact"
				entry.title = EvoI18n.t(lang, "chronicle_pact_title", params)
				entry.causal_explanation = EvoI18n.t(lang, "chronicle_pact_desc", params)
				entry.hex_id = c1.id
				entry.deme_id = d1.id
				entry.lineage_id = d1.lineage_id
				state.chronicle.append(entry)

			if next_turns >= 2:
				if not symbiosis_bonus_applied.has(d1.id):
					extracted_energy_by_deme[d1.id] = snappedf(ext_1 * 1.15, 0.0001)
					symbiosis_bonus_applied[d1.id] = true
				if not symbiosis_bonus_applied.has(d2.id):
					extracted_energy_by_deme[d2.id] = snappedf(ext_2 * 1.15, 0.0001)
					symbiosis_bonus_applied[d2.id] = true

				var need_1 := _compute_caloric_need(d1, v1)
				var need_2 := _compute_caloric_need(d2, v2)
				var d1_distress := d1.energy_reserves < 35.0 or float(extracted_energy_by_deme[d1.id]) < need_1
				var d2_distress := d2.energy_reserves < 35.0 or float(extracted_energy_by_deme[d2.id]) < need_2

				if d1_distress and not d2_distress and d2.energy_reserves > 60.0:
					var transfer := snappedf(minf(14.0, (d2.energy_reserves - 50.0) * 0.25), 0.01)
					d2.energy_reserves = maxf(0.0, snappedf(d2.energy_reserves - transfer, 0.01))
					d1.energy_reserves = snappedf(d1.energy_reserves + transfer, 0.01)
				elif d2_distress and not d1_distress and d1.energy_reserves > 60.0:
					var transfer := snappedf(minf(14.0, (d1.energy_reserves - 50.0) * 0.25), 0.01)
					d1.energy_reserves = maxf(0.0, snappedf(d1.energy_reserves - transfer, 0.01))
					d2.energy_reserves = snappedf(d2.energy_reserves + transfer, 0.01)

				var flow_key := pair_key if c1.id == c2.id else hex_pair_key
				if existing_flows_by_key.has(flow_key):
					var ex_flow: EvoTypes.HexEdgeFlow = existing_flows_by_key[flow_key]
					ex_flow.flow_type = "pact"
					ex_flow.intensity = 0.80
				else:
					var flow := EvoTypes.HexEdgeFlow.new()
					flow.from_hex_id = c1.id
					flow.to_hex_id = c2.id
					flow.flow_type = "pact"
					flow.intensity = 0.80
					flow.from_deme_id = d1.id
					flow.to_deme_id = d2.id
					state.active_flows.append(flow)
					turn_geopolitical_flows.append(flow)
					existing_flows_by_key[flow_key] = flow
		elif pact_turns > 0 and ((p_coop_1 + p_exch_1 < 0.18 and p_coop_2 + p_exch_2 < 0.18) or p_disp_1 >= 0.28 or p_disp_2 >= 0.28):
			var decayed := pact_turns - 1
			if decayed <= 0:
				state.active_pacts.erase(pair_key)
			else:
				state.active_pacts[pair_key] = decayed


static func _run_defense_fortification_phase(
	state: EvoTypes.WorldState,
	lang: String,
	arch_probs: Dictionary
) -> void:
	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.defense_tier >= 3 or not state.cells.has(deme.hex_id):
			continue
		var req_pop: int = 38 if deme.defense_tier == 0 else (65 if deme.defense_tier == 1 else 100)
		if deme.population < req_pop:
			continue
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var req_res: float = 58.0 if deme.defense_tier == 0 else (92.0 if deme.defense_tier == 1 else 130.0)
		var req_cell_res: float = 35.0 if deme.defense_tier == 0 else (55.0 if deme.defense_tier == 1 else 75.0)
		if cell.current_resources < req_cell_res or deme.energy_reserves < req_res - 35.0:
			continue
		var ap: Array = arch_probs.get(deme.id, [0.0, 0.0, 0.0, 0.0])
		var p_coop_exch := float(ap[0]) + float(ap[1])
		var has_fort_trait := (
			deme.cultural_trait_ids.has("cul-symbolic-storage")
			or deme.cultural_trait_ids.has("cul-communal-conservation")
			or deme.biological_trait_ids.has("bio-k-strategy")
		)
		var has_rival := false
		var allies: Array[EvoTypes.Deme] = []
		if not (p_coop_exch >= 0.25 or has_fort_trait) or (deme.energy_reserves < req_res and not state.active_pacts.is_empty()):
			for oid in cell.deme_ids:
				if oid != deme.id and state.demes.has(oid):
					var other: EvoTypes.Deme = state.demes[oid]
					if EvoTypes.is_pact_active(state, deme.id, other.id):
						allies.append(other)
					elif other.lineage_id != deme.lineage_id:
						has_rival = true
			for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
				var ncell: EvoTypes.HexCell = state.cells[nid]
				for oid in ncell.deme_ids:
					if oid != deme.id and state.demes.has(oid):
						var other: EvoTypes.Deme = state.demes[oid]
						if EvoTypes.is_pact_active(state, deme.id, other.id):
							allies.append(other)
						elif other.lineage_id != deme.lineage_id:
							has_rival = true

		if not (p_coop_exch >= 0.25 or has_fort_trait or has_rival):
			continue

		var cost_res: float = 25.0 if deme.defense_tier == 0 else (45.0 if deme.defense_tier == 1 else 65.0)
		var cost_cell: float = 15.0 if deme.defense_tier == 0 else (25.0 if deme.defense_tier == 1 else 35.0)

		if has_fort_trait:
			cost_res = snappedf(cost_res * 0.85, 0.01)
			cost_cell = snappedf(cost_cell * 0.85, 0.01)

		if deme.energy_reserves < req_res and (req_res - deme.energy_reserves) <= 35.0 and not allies.is_empty():
			for ally in allies:
				if ally.energy_reserves >= 80.0:
					var needed := req_res - deme.energy_reserves
					var contrib := snappedf(minf(needed, minf(30.0, ally.energy_reserves - 55.0)), 0.01)
					if contrib > 0.0:
						ally.energy_reserves = maxf(0.0, snappedf(ally.energy_reserves - contrib, 0.01))
						deme.energy_reserves = snappedf(deme.energy_reserves + contrib, 0.01)
					if deme.energy_reserves >= req_res:
						break

		if deme.energy_reserves < req_res:
			continue

		deme.energy_reserves = maxf(0.0, snappedf(deme.energy_reserves - cost_res, 0.01))
		cell.current_resources = maxf(0.0, snappedf(cell.current_resources - cost_cell, 0.01))
		deme.defense_tier += 1

		if deme.defense_tier >= 2:
			var params := {
				"deme": deme.name,
				"tier_name": EvoI18n.t(lang, "inspector_defense_%d" % deme.defense_tier),
				"hex": cell.id
			}
			var entry := EvoTypes.ChronicleEntry.new()
			entry.id = "chronicle-fortify-%d-%s-%d" % [state.generation, deme.id, deme.defense_tier]
			entry.generation = state.generation
			entry.event_type = "fortify"
			entry.title = EvoI18n.t(lang, "chronicle_fortify_title", params)
			entry.causal_explanation = EvoI18n.t(lang, "chronicle_fortify_desc", params)
			entry.hex_id = cell.id
			entry.deme_id = deme.id
			entry.lineage_id = deme.lineage_id
			state.chronicle.append(entry)


static func _can_attempt_raid(
	raider: EvoTypes.Deme,
	victim: EvoTypes.Deme,
	c_raider: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	vec_r: EvoTypes.BiophysicalVector,
	extracted_energy_by_deme: Dictionary,
	ap_r: Array = []
) -> bool:
	if victim.defense_tier >= 3:
		return false
	if _has_recent_raid_chronicle(state, raider.id, victim.id):
		return false
	var p_disp := float(ap_r[2]) if ap_r.size() >= 4 else get_archetype_prob(raider, state.decisions_catalog, "dispute")
	var p_over := float(ap_r[3]) if ap_r.size() >= 4 else get_archetype_prob(raider, state.decisions_catalog, "overexploit")
	if p_disp + p_over < 0.28:
		return false

	var ext_r := float(extracted_energy_by_deme.get(raider.id, 0.0))
	var need_r := _compute_caloric_need(raider, vec_r)
	var adequacy_r := ext_r / need_r
	var k_ratio := c_raider.carrying_capacity / maxf(10.0, c_raider.carrying_capacity_max)
	var env_pressure := (
		adequacy_r < 1.12
		or raider.energy_reserves < 65.0
		or state.season == "dry_cold"
		or k_ratio < 0.80
	)
	if not env_pressure:
		return false

	var has_raiding_capability := (
		vec_r.extraction_efficiency > 0.20
		or vec_r.spatial_mobility > 0.20
		or raider.cultural_trait_ids.has("cul-warrior-expansion")
		or raider.cultural_trait_ids.has("cul-extraction-tools")
	)
	if not has_raiding_capability:
		return false

	var ext_v := float(extracted_energy_by_deme.get(victim.id, 0.0))
	return victim.energy_reserves >= 28.0 or ext_v >= 25.0


static func _has_recent_raid_chronicle(
	state: EvoTypes.WorldState,
	raider_id: String,
	victim_id: String
) -> bool:
	var suffix_ab := "-%s-%s" % [raider_id, victim_id]
	var suffix_ba := "-%s-%s" % [victim_id, raider_id]
	var cutoff := state.generation - 2
	for i in range(state.chronicle.size() - 1, -1, -1):
		var entry := state.chronicle[i]
		if entry.generation < cutoff:
			break
		if entry.event_type == "raid":
			if entry.id.ends_with(suffix_ab) or entry.id.ends_with(suffix_ba):
				return true
	return false


static func _execute_raid_if_successful(
	raider: EvoTypes.Deme,
	victim: EvoTypes.Deme,
	c_raider: EvoTypes.HexCell,
	c_victim: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	lang: String,
	vec_r: EvoTypes.BiophysicalVector,
	vec_v: EvoTypes.BiophysicalVector,
	extracted_energy_by_deme: Dictionary,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow],
	ap_r: Array = [],
	ap_v: Array = []
) -> bool:
	var p_r_disp := float(ap_r[2]) if ap_r.size() >= 4 else get_archetype_prob(raider, state.decisions_catalog, "dispute")
	var p_r_over := float(ap_r[3]) if ap_r.size() >= 4 else get_archetype_prob(raider, state.decisions_catalog, "overexploit")
	var p_v_disp := float(ap_v[2]) if ap_v.size() >= 4 else get_archetype_prob(victim, state.decisions_catalog, "dispute")
	var p_v_coop := float(ap_v[0]) if ap_v.size() >= 4 else get_archetype_prob(victim, state.decisions_catalog, "cooperate")
	var p_v_exch := float(ap_v[1]) if ap_v.size() >= 4 else get_archetype_prob(victim, state.decisions_catalog, "exchange")

	var warrior_r := 0.35 if raider.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var warrior_v := 0.30 if victim.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var pact_defense_bonus := compute_pact_defense_bonus(victim, state)
	var fort_bonus: float = DEFENSE_TIER_BONUS[clampi(victim.defense_tier, 0, 3)]

	var eff_victim_pop: float = float(victim.population)
	if victim.walled_union_id != "":
		for nid in HexMath.get_neighbor_ids(c_victim.q, c_victim.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			for pid in ncell.deme_ids:
				if pid != victim.id and state.demes.has(pid):
					var partner: EvoTypes.Deme = state.demes[pid]
					if partner.walled_union_id == victim.walled_union_id and int(state.active_pacts.get(EvoTypes.make_pair_key(victim.id, partner.id), 0)) >= 0:
						eff_victim_pop += 0.40 * float(partner.population)

	var raider_score := (
		float(raider.population)
		* (0.8 + 0.5 * vec_r.extraction_efficiency + 0.4 * vec_r.spatial_mobility + warrior_r)
		* (0.25 + p_r_disp + 0.5 * p_r_over)
	)
	var defense_score := (
		eff_victim_pop
		* (0.85 + 0.65 * vec_v.social_cohesion + pact_defense_bonus + warrior_v + fort_bonus)
		* (0.5 + p_v_disp + 0.5 * p_v_coop)
	)

	if raider_score <= defense_score * 0.92:
		return false

	if victim.defense_tier <= 2 and victim.energy_reserves >= 35.0 and (p_v_exch >= 0.18 or (victim.cultural_trait_ids.has("cul-interdeme-barter") and (p_v_coop + p_v_exch) >= 0.10) or ((victim.population >= 55 or victim.defense_tier >= 1) and (p_v_coop + p_v_exch) >= 0.34 and p_v_disp < 0.20)):
		var tribute := snappedf(clampf(victim.energy_reserves * 0.18, 10.0, 28.0), 0.1)
		victim.energy_reserves = maxf(0.0, snappedf(victim.energy_reserves - tribute, 0.01))
		raider.energy_reserves = minf(220.0, snappedf(raider.energy_reserves + tribute, 0.01))
		state.active_pacts[EvoTypes.make_pair_key(raider.id, victim.id)] = 1

		var t_flow := EvoTypes.HexEdgeFlow.new()
		t_flow.from_hex_id = c_victim.id
		t_flow.to_hex_id = c_raider.id
		t_flow.flow_type = "tribute"
		t_flow.intensity = 0.75
		t_flow.from_deme_id = raider.id
		t_flow.to_deme_id = victim.id
		state.active_flows.append(t_flow)
		turn_geopolitical_flows.append(t_flow)

		var t_params := {
			"raider": raider.name,
			"victim": victim.name,
			"loot": str(int(round(tribute))),
			"hex": c_victim.id
		}
		var t_entry := EvoTypes.ChronicleEntry.new()
		t_entry.id = "chronicle-tribute-%d-%s-%s" % [state.generation, victim.id, raider.id]
		t_entry.generation = state.generation
		t_entry.event_type = "tribute"
		t_entry.title = EvoI18n.t(lang, "chronicle_tribute_title", t_params)
		t_entry.causal_explanation = EvoI18n.t(lang, "chronicle_tribute_desc", t_params)
		t_entry.hex_id = c_victim.id
		t_entry.deme_id = victim.id
		t_entry.lineage_id = victim.lineage_id
		state.chronicle.append(t_entry)
		return true

	var tier_idx := clampi(victim.defense_tier, 0, 3)
	var loot_scale: float = [1.0, 0.75, 0.40, 0.0][tier_idx]
	var cas_scale: float = [1.0, 0.75, 0.50, 0.25][tier_idx]
	var ext_v := float(extracted_energy_by_deme.get(victim.id, 0.0))
	var force_ratio := clampf(raider_score / maxf(1.0, defense_score), 0.7, 1.5)
	var desired_loot := clampf((victim.energy_reserves * 0.28 + ext_v * 0.24) * force_ratio, 10.0, 42.0) * loot_scale

	var from_reserves := minf(victim.energy_reserves, desired_loot * 0.65)
	var from_ext := minf(ext_v, desired_loot - from_reserves)
	if from_reserves + from_ext < desired_loot:
		var rem := desired_loot - (from_reserves + from_ext)
		from_reserves = minf(victim.energy_reserves, from_reserves + rem)
	var loot := snappedf(from_reserves + from_ext, 0.01)

	victim.energy_reserves = maxf(0.0, snappedf(victim.energy_reserves - from_reserves, 0.01))
	extracted_energy_by_deme[victim.id] = maxf(0.0, snappedf(ext_v - from_ext, 0.01))
	extracted_energy_by_deme[raider.id] = snappedf(float(extracted_energy_by_deme.get(raider.id, 0.0)) + from_ext, 0.01)
	raider.energy_reserves = minf(220.0, snappedf(raider.energy_reserves + from_reserves, 0.01))

	var r_loss := maxi(1, int(round(float(raider.population) * 0.025)))
	var v_loss := maxi(1, mini(int(round(float(raider.population) * 0.14)), int(round(float(victim.population) * 0.04 * cas_scale))))
	raider.population = maxi(10, raider.population - r_loss)
	victim.population = maxi(8, victim.population - v_loss)

	for rcid in HexMath.get_neighbor_ids(c_victim.q, c_victim.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[rcid]
		if ncell.owner_deme_id == victim.id:
			var r_plunder: float = snappedf(minf(ncell.current_resources * 0.20 * loot_scale, 18.0 * loot_scale), 0.01)
			ncell.current_resources = maxf(0.0, snappedf(ncell.current_resources - r_plunder, 0.01))
			if victim.defense_tier == 0 or (victim.defense_tier == 1 and raider_score >= defense_score * 1.35):
				ncell.owner_deme_id = ""
				ncell.land_use = "wild"
				ncell.has_ruins = true
			raider.energy_reserves = minf(220.0, snappedf(raider.energy_reserves + r_plunder, 0.01))
			loot = snappedf(loot + r_plunder, 0.01)
			break

	var pk := EvoTypes.make_pair_key(raider.id, victim.id)
	if int(state.active_pacts.get(pk, 0)) < 2:
		state.active_pacts[pk] = mini(-2, int(state.active_pacts.get(pk, 0)))

	var flow := EvoTypes.HexEdgeFlow.new()
	flow.from_hex_id = c_raider.id
	flow.to_hex_id = c_victim.id
	flow.flow_type = "raid"
	flow.intensity = snappedf(clampf(loot / 32.0, 0.50, 1.0), 0.01)
	flow.from_deme_id = raider.id
	flow.to_deme_id = victim.id
	state.active_flows.append(flow)
	turn_geopolitical_flows.append(flow)

	if not _has_recent_raid_chronicle(state, raider.id, victim.id):
		var params := {
			"raider": raider.name,
			"victim": victim.name,
			"loot": str(int(round(loot))),
			"hex": c_victim.id
		}
		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-raid-%d-%s-%s" % [state.generation, raider.id, victim.id]
		entry.generation = state.generation
		entry.event_type = "raid"
		entry.title = EvoI18n.t(lang, "chronicle_raid_title", params)
		entry.causal_explanation = EvoI18n.t(lang, "chronicle_raid_desc", params)
		entry.hex_id = c_victim.id
		entry.deme_id = raider.id
		entry.lineage_id = raider.lineage_id
		state.chronicle.append(entry)

	return true


static func _run_raids(
	state: EvoTypes.WorldState,
	lang: String,
	effective_vec_by_deme: Dictionary,
	extracted_energy_by_deme: Dictionary,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow],
	betrayed_pairs_this_turn: Dictionary,
	arch_probs: Dictionary,
	adjacent_pairs: Array
) -> void:
	var any_raider := false
	for did in arch_probs.keys():
		var ap: Array = arch_probs[did]
		if float(ap[2]) + float(ap[3]) >= 0.28:
			any_raider = true
			break
	if not any_raider:
		return

	var raided_pairs: Dictionary = {}
	for pair in adjacent_pairs:
		var d1: EvoTypes.Deme = pair[0]
		var c1: EvoTypes.HexCell = pair[1]
		var d2: EvoTypes.Deme = pair[2]
		var c2: EvoTypes.HexCell = pair[3]
		var pair_key: String = pair[4]

		if betrayed_pairs_this_turn.has(pair_key) or raided_pairs.has(pair_key):
			continue
		if int(state.active_pacts.get(pair_key, 0)) >= 2:
			continue
		if d1.lineage_id == d2.lineage_id and EvoDemographyMigration.compute_deme_divergence(d1, d2) <= 0.35:
			continue

		var v1: EvoTypes.BiophysicalVector = effective_vec_by_deme[d1.id]
		var v2: EvoTypes.BiophysicalVector = effective_vec_by_deme[d2.id]
		var ap1: Array = arch_probs[d1.id]
		var ap2: Array = arch_probs[d2.id]

		if _can_attempt_raid(d1, d2, c1, state, v1, extracted_energy_by_deme, ap1):
			if _execute_raid_if_successful(d1, d2, c1, c2, state, lang, v1, v2, extracted_energy_by_deme, turn_geopolitical_flows, ap1, ap2):
				raided_pairs[pair_key] = true
				continue

		if _can_attempt_raid(d2, d1, c2, state, v2, extracted_energy_by_deme, ap2):
			if _execute_raid_if_successful(d2, d1, c2, c1, state, lang, v2, v1, extracted_energy_by_deme, turn_geopolitical_flows, ap2, ap1):
				raided_pairs[pair_key] = true


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
				return a.current_resources < b.current_resources
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
				return a.current_resources > b.current_resources
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


static func run_resource_and_symbiosis_phase(
	state: EvoTypes.WorldState,
	lang: String,
	effective_vec_by_deme: Dictionary,
	hawk_penalty_by_deme: Dictionary,
	extracted_energy_by_deme: Dictionary,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow] = []
) -> void:
	var is_en := lang == "en"
	var symbiosis_bonus_applied: Dictionary = {}
	var existing_flows_by_key: Dictionary = {}
	var initial_cultural_traits_by_deme: Dictionary = {}
	var arch_probs: Dictionary = {}
	var valid_demes: Array[EvoTypes.Deme] = []
	var valid_cells: Array[EvoTypes.HexCell] = []
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		initial_cultural_traits_by_deme[did] = d.cultural_trait_ids.duplicate()
		var p_coop: float = 0.0
		var p_exch: float = 0.0
		var p_disp: float = 0.0
		var p_over: float = 0.0
		for dec_id in d.last_decision_probabilities.keys():
			if state.decisions_catalog.has(dec_id):
				var arch := (state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).archetype
				var prob := float(d.last_decision_probabilities[dec_id])
				if arch == "cooperate":
					p_coop += prob
				elif arch == "exchange":
					p_exch += prob
				elif arch == "dispute":
					p_disp += prob
				elif arch == "overexploit":
					p_over += prob
		arch_probs[d.id] = [p_coop, p_exch, p_disp, p_over]
		if state.cells.has(d.hex_id):
			valid_demes.append(d)
			valid_cells.append(state.cells[d.hex_id])

	var tragedy_hexes: Dictionary = {}
	for i in range(state.chronicle.size() - 1, -1, -1):
		var entry := state.chronicle[i]
		if entry.event_type == "tragedy_of_commons":
			tragedy_hexes[entry.hex_id] = true

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		var resident_demes: Array[EvoTypes.Deme] = []
		for did in cell.deme_ids:
			if state.demes.has(did):
				resident_demes.append(state.demes[did])

		if resident_demes.is_empty():
			continue

		var demand_by_deme: Dictionary = {}
		for deme in resident_demes:
			var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[deme.id]
			var tier := deme.get_village_tier()
			var urban_forage_mult: float = 1.0 if tier <= 2 else (0.55 if tier == 3 else 0.30)
			demand_by_deme[deme.id] = maxf(
				0.0,
				float(deme.population) * 0.50 * (1.0 + 0.60 * v_eff.extraction_efficiency) * urban_forage_mult
			)

		var lineages_in_hex: Dictionary = {}
		for deme in resident_demes:
			lineages_in_hex[deme.lineage_id] = true
		var has_rival_lineages := lineages_in_hex.size() >= 2

		var hawks: Array[EvoTypes.Deme] = []
		var doves: Array[EvoTypes.Deme] = []
		var exchangers: Array[EvoTypes.Deme] = []

		for deme in resident_demes:
			var ap: Array = arch_probs[deme.id]
			var is_active_hawk := has_rival_lineages and float(ap[2]) >= 0.25
			if is_active_hawk:
				hawks.append(deme)
			else:
				doves.append(deme)
				if float(ap[1]) >= 0.20:
					exchangers.append(deme)

		var hawk_lineages: Dictionary = {}
		for hawk in hawks:
			hawk_lineages[hawk.lineage_id] = true
		var has_rival_hawks := hawk_lineages.size() >= 2

		if has_rival_lineages:
			if has_rival_hawks:
				for i in range(hawks.size()):
					var hawk := hawks[i]
					var opp := hawks[(i + 1) % hawks.size()]
					for candidate_opp in hawks:
						if candidate_opp.lineage_id != hawk.lineage_id:
							opp = candidate_opp
							break
					hawk.population = maxi(10, int(floor(float(hawk.population) * 0.85)))
					hawk_penalty_by_deme[hawk.id] = 1.25
					var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[hawk.id]
					var tier := hawk.get_village_tier()
					var urban_forage_mult: float = 1.0 if tier <= 2 else (0.55 if tier == 3 else 0.30)
					demand_by_deme[hawk.id] = maxf(
						0.0,
						float(hawk.population) * 0.50 * (1.0 + 0.60 * v_eff.extraction_efficiency) * urban_forage_mult
					)
					var flow := EvoTypes.HexEdgeFlow.new()
					flow.from_hex_id = cell.id
					flow.to_hex_id = cell.id
					flow.flow_type = "dispute"
					flow.intensity = 0.75
					flow.from_deme_id = hawk.id
					flow.to_deme_id = opp.id
					state.active_flows.append(flow)
			elif hawks.size() >= 1 and doves.size() >= 1:
				for hawk in hawks:
					var rival_doves: Array[EvoTypes.Deme] = []
					for dove in doves:
						if dove.lineage_id != hawk.lineage_id:
							rival_doves.append(dove)
					if rival_doves.is_empty():
						continue
					var sum_dove_social: float = 0.0
					for dove in rival_doves:
						sum_dove_social += (effective_vec_by_deme[dove.id] as EvoTypes.BiophysicalVector).social_cohesion
					var avg_dove_social := sum_dove_social / float(rival_doves.size())

					var hawk_social := (effective_vec_by_deme[hawk.id] as EvoTypes.BiophysicalVector).social_cohesion
					var capture_mult := 0.25 * (1.0 + maxf(0.0, hawk_social - avg_dove_social))
					var hawk_demand := float(demand_by_deme[hawk.id])
					var req_bonus := hawk_demand * capture_mult
					var total_dove_demand: float = 0.0
					for dove in rival_doves:
						total_dove_demand += float(demand_by_deme[dove.id])
					var actual_captured := minf(total_dove_demand, req_bonus)

					demand_by_deme[hawk.id] = hawk_demand + actual_captured
					if total_dove_demand > 0.0:
						for dove in rival_doves:
							var cur_d := float(demand_by_deme[dove.id])
							var share := cur_d / total_dove_demand
							demand_by_deme[dove.id] = maxf(0.0, cur_d - actual_captured * share)

					for dove in rival_doves:
						var flow := EvoTypes.HexEdgeFlow.new()
						flow.from_hex_id = cell.id
						flow.to_hex_id = cell.id
						flow.flow_type = "dispute"
						flow.intensity = 0.65
						flow.from_deme_id = hawk.id
						flow.to_deme_id = dove.id
						state.active_flows.append(flow)

		var total_demand: float = 0.0
		for deme in resident_demes:
			total_demand += float(demand_by_deme[deme.id])
		var total_extracted := minf(cell.current_resources, total_demand)

		for deme in resident_demes:
			var d_dem := float(demand_by_deme[deme.id])
			var ext := (total_extracted * (d_dem / total_demand)) if total_demand > 0.0 else 0.0
			extracted_energy_by_deme[deme.id] = ext

		cell.current_resources = maxf(0.0, snappedf(cell.current_resources - total_extracted, 0.01))

		if exchangers.size() >= 2:
			var logged_symbiosis_in_cell := false
			for i in range(exchangers.size()):
				var ex := exchangers[i]
				var partner := exchangers[(i + 1) % exchangers.size()]
				var base_ext := float(extracted_energy_by_deme[ex.id])
				extracted_energy_by_deme[ex.id] = snappedf(base_ext * 1.20, 0.0001)
				symbiosis_bonus_applied[ex.id] = true

				var flow := EvoTypes.HexEdgeFlow.new()
				flow.from_hex_id = cell.id
				flow.to_hex_id = cell.id
				flow.flow_type = "exchange"
				flow.intensity = 0.60
				flow.from_deme_id = ex.id
				flow.to_deme_id = partner.id
				state.active_flows.append(flow)
				var intra_pk := (ex.id + "__" + partner.id) if ex.id < partner.id else (partner.id + "__" + ex.id)
				existing_flows_by_key[intra_pk] = flow

			for donor in exchangers:
				var donor_initial_traits: Array = initial_cultural_traits_by_deme.get(donor.id, [])
				for receiver in exchangers:
					if donor.id == receiver.id:
						continue
					if not EvoCatalog.deme_has_cultural_capacity(receiver, state.traits_catalog):
						continue
					var receiver_social := (effective_vec_by_deme[receiver.id] as EvoTypes.BiophysicalVector).social_cohesion
					for tid_var in donor_initial_traits:
						var tid := str(tid_var)
						if not _can_acquire_trait(receiver, tid, state.traits_catalog):
							continue
						var tdef: EvoTypes.TraitDef = state.traits_catalog[tid]
						if receiver_social >= tdef.vector.transmission_threshold:
							receiver.cultural_trait_ids.append(tid)
							effective_vec_by_deme[receiver.id] = compute_effective_vector(receiver, state)
							if not logged_symbiosis_in_cell:
								logged_symbiosis_in_cell = true
								var tname := EvoI18n.trait_name(lang, tdef)
								var entry := EvoTypes.ChronicleEntry.new()
								entry.id = "chronicle-symbiosis-%d-%s-%s" % [state.generation, cell.id, receiver.id]
								entry.generation = state.generation
								entry.event_type = "symbiosis"
								entry.title = ("Cultural Symbiosis: %s" if is_en else "Simbiosis Cultural: %s") % tname
								entry.causal_explanation = (
									"%s acquired %s through symbiotic exchange with %s in hex (%s)." % [receiver.name, tname, donor.name, cell.id]
									if is_en
									else "%s adquirió %s mediante intercambio simbiótico con %s en el hexágono (%s)." % [receiver.name, tname, donor.name, cell.id]
								)
								entry.hex_id = cell.id
								entry.deme_id = receiver.id
								entry.lineage_id = receiver.lineage_id
								entry.trait_id = tid
								state.chronicle.append(entry)

		var gamma_season := 1.20 if state.season == "wet_warm" else 0.75
		var natural_regen := cell.carrying_capacity * cell.seasonal_regen_rate * gamma_season
		var sum_eco_impact: float = 0.0
		var has_intensive_overexploit := false
		for deme in resident_demes:
			sum_eco_impact += (effective_vec_by_deme[deme.id] as EvoTypes.BiophysicalVector).ecological_impact
			if float((arch_probs[deme.id] as Array)[3]) >= 0.30:
				has_intensive_overexploit = true

		var already_logged_tragedy := tragedy_hexes.has(cell.id)

		if (total_extracted > natural_regen or (cell.current_resources <= 0.0 and total_demand > natural_regen)) and (sum_eco_impact < -0.15 or (has_intensive_overexploit and sum_eco_impact < -0.10)):
			var degraded_k := maxf(10.0, snappedf(cell.carrying_capacity * (1.0 + 0.18 * sum_eco_impact), 0.01))
			cell.carrying_capacity = degraded_k
			if cell.current_resources > degraded_k:
				cell.current_resources = degraded_k

			var primary_deme := resident_demes[0]
			if not already_logged_tragedy and degraded_k < 0.60 * cell.carrying_capacity_max:
				tragedy_hexes[cell.id] = true
				var entry := EvoTypes.ChronicleEntry.new()
				entry.id = "chronicle-tragedy-%d-%s" % [state.generation, cell.id]
				entry.generation = state.generation
				entry.event_type = "tragedy_of_commons"
				entry.title = ("Tragedy of the Commons in (%s)" if is_en else "Tragedia de los Comunes en (%s)") % cell.id
				entry.causal_explanation = (
					"Intensive overexploitation degraded local carrying capacity to %.1f (below 60%% of maximum %.0f)." % [degraded_k, cell.carrying_capacity_max]
					if is_en
					else "La sobreexplotación intensiva degradó la capacidad de carga local a %.1f (por debajo del 60%% del máximo %.0f)." % [degraded_k, cell.carrying_capacity_max]
				)
				entry.hex_id = cell.id
				entry.deme_id = primary_deme.id
				entry.lineage_id = primary_deme.lineage_id
				state.chronicle.append(entry)
		elif sum_eco_impact > 0.10 and not has_intensive_overexploit:
			cell.carrying_capacity = snappedf(
				clampf(cell.carrying_capacity * (1.0 + 0.05 * sum_eco_impact), 10.0, cell.carrying_capacity_max),
				0.01
			)

	_update_and_harvest_rural_hinterlands(state, effective_vec_by_deme, extracted_energy_by_deme)

	var adjacent_pairs: Array = []
	var v_count := valid_demes.size()
	for i in range(v_count):
		var d1 := valid_demes[i]
		var c1 := valid_cells[i]
		var q1 := c1.q
		var r1 := c1.r
		var bad1 := c1.biome == "ocean" or c1.altitude > 0.85
		for j in range(i + 1, v_count):
			var c2 := valid_cells[j]
			var dq := q1 - c2.q
			var dr := r1 - c2.r
			if absi(dq) > 1 or absi(dr) > 1 or absi(dq + dr) > 1:
				continue
			if (dq != 0 or dr != 0) and (bad1 or c2.biome == "ocean" or c2.altitude > 0.85):
				continue
			var d2 := valid_demes[j]
			var pk := (d1.id + "__" + d2.id) if d1.id < d2.id else (d2.id + "__" + d1.id)
			adjacent_pairs.append([d1, c1, d2, c2, pk])

	for pair in adjacent_pairs:
		var d1: EvoTypes.Deme = pair[0]
		var c1: EvoTypes.HexCell = pair[1]
		var d2: EvoTypes.Deme = pair[2]
		var c2: EvoTypes.HexCell = pair[3]
		var pk: String = pair[4]
		if c1.id == c2.id:
			continue
		if d1.lineage_id == d2.lineage_id or int(state.active_pacts.get(pk, 0)) >= 2:
			continue
		var p_disp_1 := float((arch_probs[d1.id] as Array)[2])
		var p_disp_2 := float((arch_probs[d2.id] as Array)[2])
		if p_disp_1 < 0.25 and p_disp_2 < 0.25:
			continue
		if p_disp_1 >= 0.25 and p_disp_2 >= 0.25:
			var loss_1: float = clampf(0.12 * clampf(float(d2.population) / maxf(15.0, float(d1.population)), 0.20, 1.50) * DEFENSE_ATTENUATION_SCALE[clampi(d1.defense_tier, 0, 3)], 0.02, 0.18)
			var loss_2: float = clampf(0.12 * clampf(float(d1.population) / maxf(15.0, float(d2.population)), 0.20, 1.50) * DEFENSE_ATTENUATION_SCALE[clampi(d2.defense_tier, 0, 3)], 0.02, 0.18)
			d1.population = maxi(10, int(floor(float(d1.population) * (1.0 - loss_1))))
			d2.population = maxi(10, int(floor(float(d2.population) * (1.0 - loss_2))))
			hawk_penalty_by_deme[d1.id] = 1.25
			hawk_penalty_by_deme[d2.id] = 1.25
			var flow := EvoTypes.HexEdgeFlow.new()
			flow.from_hex_id = c1.id
			flow.to_hex_id = c2.id
			flow.flow_type = "dispute"
			flow.intensity = 0.75
			flow.from_deme_id = d1.id
			flow.to_deme_id = d2.id
			state.active_flows.append(flow)
		else:
			var hawk := d1 if p_disp_1 >= 0.25 else d2
			var dove := d2 if p_disp_1 >= 0.25 else d1
			var c_hawk := c1 if p_disp_1 >= 0.25 else c2
			var c_dove := c2 if p_disp_1 >= 0.25 else c1
			var hawk_social := (effective_vec_by_deme[hawk.id] as EvoTypes.BiophysicalVector).social_cohesion
			var dove_social := (effective_vec_by_deme[dove.id] as EvoTypes.BiophysicalVector).social_cohesion
			var pop_ratio: float = clampf(float(hawk.population) / maxf(15.0, float(dove.population)), 0.10, 1.40)
			var dove_def_scale: float = DEFENSE_ATTENUATION_SCALE[clampi(dove.defense_tier, 0, 3)]
			var capture_mult: float = 0.22 * (1.0 + maxf(0.0, hawk_social - dove_social)) * pop_ratio * dove_def_scale
			var dove_ext := float(extracted_energy_by_deme.get(dove.id, 0.0))
			var captured: float = snappedf(minf(dove_ext * capture_mult, float(hawk.population) * 0.45), 0.0001)
			extracted_energy_by_deme[hawk.id] = snappedf(float(extracted_energy_by_deme.get(hawk.id, 0.0)) + captured, 0.0001)
			extracted_energy_by_deme[dove.id] = maxf(0.0, snappedf(dove_ext - captured, 0.0001))
			var flow := EvoTypes.HexEdgeFlow.new()
			flow.from_hex_id = c_hawk.id
			flow.to_hex_id = c_dove.id
			flow.flow_type = "dispute"
			flow.intensity = 0.65
			flow.from_deme_id = hawk.id
			flow.to_deme_id = dove.id
			state.active_flows.append(flow)

	var exchange_flow_pairs: Dictionary = {}
	for donor_id in state.demes.keys():
		var donor: EvoTypes.Deme = state.demes[donor_id]
		if float((arch_probs[donor.id] as Array)[1]) < 0.20:
			continue
		if not state.cells.has(donor.hex_id):
			continue
		var donor_cell: EvoTypes.HexCell = state.cells[donor.hex_id]
		if donor_cell.biome == "ocean" or donor_cell.altitude > 0.85:
			continue
		var donor_initial_traits: Array = initial_cultural_traits_by_deme.get(donor.id, [])
		for nid in HexMath.get_neighbor_ids(donor_cell.q, donor_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.biome == "ocean" or ncell.altitude > 0.85:
				continue
			for ndeme_id in ncell.deme_ids:
				if not state.demes.has(ndeme_id):
					continue
				var receiver: EvoTypes.Deme = state.demes[ndeme_id]
				if float((arch_probs[receiver.id] as Array)[1]) < 0.20:
					continue

				if not symbiosis_bonus_applied.has(donor.id):
					var base_ext := float(extracted_energy_by_deme[donor.id])
					var trade_mult := (
						1.15
						+ (0.12 if donor_cell.biome != ncell.biome else 0.0)
						+ (0.08 if donor.cultural_trait_ids != receiver.cultural_trait_ids else 0.0)
					)
					extracted_energy_by_deme[donor.id] = snappedf(base_ext * trade_mult, 0.0001)
					symbiosis_bonus_applied[donor.id] = true

				var hex_pair_key := ("%s|%s" % [donor_cell.id, ncell.id]) if donor_cell.id <= ncell.id else ("%s|%s" % [ncell.id, donor_cell.id])
				if not exchange_flow_pairs.has(hex_pair_key):
					exchange_flow_pairs[hex_pair_key] = true
					var flow := EvoTypes.HexEdgeFlow.new()
					flow.from_hex_id = donor_cell.id
					flow.to_hex_id = ncell.id
					flow.flow_type = "exchange"
					flow.intensity = 0.55
					flow.from_deme_id = donor.id
					flow.to_deme_id = receiver.id
					state.active_flows.append(flow)
					existing_flows_by_key[hex_pair_key] = flow

				if EvoCatalog.deme_has_cultural_capacity(receiver, state.traits_catalog):
					var receiver_social := (effective_vec_by_deme[receiver.id] as EvoTypes.BiophysicalVector).social_cohesion
					for tid_var in donor_initial_traits:
						var tid := str(tid_var)
						if not _can_acquire_trait(receiver, tid, state.traits_catalog):
							continue
						var tdef: EvoTypes.TraitDef = state.traits_catalog[tid]
						if receiver_social >= tdef.vector.transmission_threshold:
							receiver.cultural_trait_ids.append(tid)
							effective_vec_by_deme[receiver.id] = compute_effective_vector(receiver, state)
							var tname := EvoI18n.trait_name(lang, tdef)
							var entry := EvoTypes.ChronicleEntry.new()
							entry.id = "chronicle-symbiosis-%d-%s-%s-%s" % [state.generation, ncell.id, receiver.id, tid]
							entry.generation = state.generation
							entry.event_type = "symbiosis"
							entry.title = ("Cultural Symbiosis: %s" if is_en else "Simbiosis Cultural: %s") % tname
							entry.causal_explanation = (
								"%s acquired %s through inter-deme exchange with %s across hexes (%s -> %s)." % [receiver.name, tname, donor.name, donor_cell.id, ncell.id]
								if is_en
								else "%s adquirió %s mediante intercambio inter-deme con %s entre hexágonos (%s -> %s)." % [receiver.name, tname, donor.name, donor_cell.id, ncell.id]
							)
							entry.hex_id = ncell.id
							entry.deme_id = receiver.id
							entry.lineage_id = receiver.lineage_id
							entry.trait_id = tid
							state.chronicle.append(entry)

	var betrayed_pairs_this_turn: Dictionary = {}
	_run_pacts_and_betrayals(
		state,
		lang,
		effective_vec_by_deme,
		extracted_energy_by_deme,
		symbiosis_bonus_applied,
		turn_geopolitical_flows,
		betrayed_pairs_this_turn,
		arch_probs,
		adjacent_pairs,
		existing_flows_by_key
	)
	_run_raids(
		state,
		lang,
		effective_vec_by_deme,
		extracted_energy_by_deme,
		turn_geopolitical_flows,
		betrayed_pairs_this_turn,
		arch_probs,
		adjacent_pairs
	)
	_run_defense_fortification_phase(state, lang, arch_probs)
