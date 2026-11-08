class_name EvoDiplomacyRaids
extends RefCounted


static func compute_pact_defense_bonus(
	victim: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> float:
	if (state.active_pacts.is_empty() and victim.walled_union_id == "") or not state.cells.has(victim.hex_id):
		return 0.0
	var v_cell: EvoTypes.HexCell = state.cells[victim.hex_id]
	var bonus: float = 0.0
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


static func _sever_friendly_connection(
	state: EvoTypes.WorldState,
	deme_a: EvoTypes.Deme,
	deme_b: EvoTypes.Deme,
	cell_a: EvoTypes.HexCell,
	cell_b: EvoTypes.HexCell
) -> void:
	if cell_a.id == cell_b.id:
		return
	var updated_existing := false
	for conn in state.disused_connections:
		var ca := str(conn.get("from_deme_id", ""))
		var cb := str(conn.get("to_deme_id", ""))
		if (ca == deme_a.id and cb == deme_b.id) or (ca == deme_b.id and cb == deme_a.id):
			conn["from_hex_id"] = cell_a.id
			conn["to_hex_id"] = cell_b.id
			conn["age"] = 1
			conn["broken_gen"] = state.generation
			updated_existing = true
			break
	if not updated_existing:
		state.disused_connections.append({
			"from_hex_id": cell_a.id,
			"to_hex_id": cell_b.id,
			"from_deme_id": deme_a.id,
			"to_deme_id": deme_b.id,
			"age": 1,
			"broken_gen": state.generation
		})


static func _age_disused_connections(state: EvoTypes.WorldState) -> void:
	var kept: Array[Dictionary] = []
	for conn in state.disused_connections:
		var age := int(conn.get("age", 0)) + 1
		if age <= 8:
			conn["age"] = age
			kept.append(conn)
	state.disused_connections = kept


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
	var impact_scale: float = clampf(float(betrayer.population) / maxf(20.0, float(victim.population)), 0.25, 1.35) * EvoEcologyInteraction.DEFENSE_ATTENUATION_SCALE[clampi(victim.defense_tier, 0, 3)]
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
	EvoTypes.push_event(state, "betrayal", c_betrayer.id, c_victim.id, betrayer.id, victim.id, loot, casualties)

	_sever_friendly_connection(state, betrayer, victim, c_betrayer, c_victim)

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

		var either_warrior := bool(has_warrior[d1.id]) or bool(has_warrior[d2.id])
		var rival_warrior_block := d1.lineage_id != d2.lineage_id and either_warrior and (
			pact_turns == 1
			or (bool(has_warrior[d1.id]) and (float(d1.population) >= float(d2.population) * 0.75 or p_disp_1 >= 0.08))
			or (bool(has_warrior[d2.id]) and (float(d2.population) >= float(d1.population) * 0.75 or p_disp_2 >= 0.08))
		)
		var both_strong_coop := (
			not rival_warrior_block
			and p_coop_1 + p_exch_1 >= 0.36 and p_disp_1 < 0.18
			and p_coop_2 + p_exch_2 >= 0.36 and p_disp_2 < 0.18
		)
		var has_warrior_threat := bool(warrior_threat_by_deme.get(d1.id, false)) or bool(warrior_threat_by_deme.get(d2.id, false))
		var coop_thresh := 0.22 if has_warrior_threat else 0.30
		var coop_1: bool = not rival_warrior_block and p_coop_1 + p_exch_1 >= coop_thresh and p_disp_1 < 0.22 and (not bool(has_warrior[d1.id]) or both_strong_coop)
		var coop_2: bool = not rival_warrior_block and p_coop_2 + p_exch_2 >= coop_thresh and p_disp_2 < 0.22 and (not bool(has_warrior[d2.id]) or both_strong_coop)
		if coop_1 and coop_2:
			var next_turns := pact_turns + 1
			state.active_pacts[pair_key] = next_turns
			var hex_pair_key := ("%s|%s" % [c1.id, c2.id]) if c1.id <= c2.id else ("%s|%s" % [c2.id, c1.id])
			if pact_turns < 2 and next_turns >= 2 and not logged_pact_hex_pairs.has(hex_pair_key):
				logged_pact_hex_pairs[hex_pair_key] = true
				EvoTypes.push_event(state, "pact", c1.id, c2.id, d1.id, d2.id, float(next_turns), 0)
				var hex_label := "%s <-> %s" % [c1.id, c2.id]
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

				if existing_flows_by_key.has(hex_pair_key):
					var ex_flow: EvoTypes.HexEdgeFlow = existing_flows_by_key[hex_pair_key]
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
					existing_flows_by_key[hex_pair_key] = flow
		elif pact_turns == 1 and (rival_warrior_block or p_disp_1 >= 0.22 or p_disp_2 >= 0.22):
			state.active_pacts.erase(pair_key)
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
			deme.cultural_trait_ids.has("cul-communal-conservation")
			or deme.biological_trait_ids.has("bio-k-strategy")
		)
		var has_rival := false
		var allies: Array[EvoTypes.Deme] = []
		if not (p_coop_exch >= 0.25 or has_fort_trait) or (deme.energy_reserves < req_res and not state.active_pacts.is_empty()):
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
		EvoTypes.push_event(state, "fortify", cell.id, cell.id, deme.id, "", float(deme.defense_tier), 0)

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
	var p_disp := float(ap_r[2]) if ap_r.size() >= 4 else EvoEcologyInteraction.get_archetype_prob(raider, state.decisions_catalog, "dispute")
	var p_over := float(ap_r[3]) if ap_r.size() >= 4 else EvoEcologyInteraction.get_archetype_prob(raider, state.decisions_catalog, "overexploit")
	if p_disp + p_over < 0.28:
		return false

	var ext_r := float(extracted_energy_by_deme.get(raider.id, 0.0))
	var need_r := _compute_caloric_need(raider, vec_r)
	var adequacy_r := ext_r / need_r
	var k_ratio := c_raider.carrying_capacity / maxf(10.0, c_raider.carrying_capacity_max)
	var warrior_offensive := raider.cultural_trait_ids.has("cul-warrior-expansion") and raider.population >= 50 and p_disp >= 0.25
	var env_pressure := (
		warrior_offensive
		or adequacy_r < 1.12
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


static func _can_pay_tribute(
	victim: EvoTypes.Deme,
	p_v_coop: float,
	p_v_exch: float,
	p_v_disp: float
) -> bool:
	return (
		victim.defense_tier <= 2
		and victim.energy_reserves >= 35.0
		and (
			p_v_exch >= 0.18
			or (victim.cultural_trait_ids.has("cul-interdeme-barter") and (p_v_coop + p_v_exch) >= 0.10)
			or ((victim.population >= 55 or victim.defense_tier >= 1) and (p_v_coop + p_v_exch) >= 0.34 and p_v_disp < 0.20)
		)
	)


static func _execute_tribute(
	raider: EvoTypes.Deme,
	victim: EvoTypes.Deme,
	c_raider: EvoTypes.HexCell,
	c_victim: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	lang: String,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow]
) -> bool:
	var tribute := snappedf(clampf(victim.energy_reserves * 0.18, 10.0, 28.0), 0.1)
	victim.energy_reserves = maxf(0.0, snappedf(victim.energy_reserves - tribute, 0.01))
	raider.energy_reserves = minf(220.0, snappedf(raider.energy_reserves + tribute, 0.01))
	state.active_pacts[EvoTypes.make_pair_key(raider.id, victim.id)] = 1

	var t_flow := EvoTypes.HexEdgeFlow.new()
	t_flow.from_hex_id = c_victim.id
	t_flow.to_hex_id = c_raider.id
	t_flow.flow_type = "tribute"
	t_flow.intensity = 0.75
	t_flow.from_deme_id = victim.id
	t_flow.to_deme_id = raider.id
	state.active_flows.append(t_flow)
	turn_geopolitical_flows.append(t_flow)
	EvoTypes.push_event(state, "tribute", c_victim.id, c_raider.id, victim.id, raider.id, tribute, 0)

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


static func _pillage_victim_rural_hex(
	raider: EvoTypes.Deme,
	victim: EvoTypes.Deme,
	c_raider: EvoTypes.HexCell,
	c_victim: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	loot_scale: float,
	raider_score: float,
	defense_score: float
) -> float:
	for rcid in HexMath.get_neighbor_ids(c_victim.q, c_victim.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[rcid]
		if ncell.owner_deme_id == victim.id:
			var r_plunder: float = snappedf(minf(ncell.current_resources * 0.20 * loot_scale, 18.0 * loot_scale), 0.01)
			ncell.current_resources = maxf(0.0, snappedf(ncell.current_resources - r_plunder, 0.01))
			if victim.defense_tier == 0 or (victim.defense_tier == 1 and raider_score >= defense_score * 1.35):
				ncell.owner_deme_id = ""
				ncell.land_use = "wild"
				ncell.has_ruins = true
				EvoTypes.push_event(state, "pillage", c_raider.id, ncell.id, raider.id, victim.id, r_plunder, 0)
			raider.energy_reserves = minf(220.0, snappedf(raider.energy_reserves + r_plunder, 0.01))
			return r_plunder
	return 0.0


static func _execute_raid(
	raider: EvoTypes.Deme,
	victim: EvoTypes.Deme,
	c_raider: EvoTypes.HexCell,
	c_victim: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	lang: String,
	extracted_energy_by_deme: Dictionary,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow],
	raider_score: float,
	defense_score: float
) -> bool:
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

	var r_plunder := _pillage_victim_rural_hex(raider, victim, c_raider, c_victim, state, loot_scale, raider_score, defense_score)
	if r_plunder > 0.0:
		loot = snappedf(loot + r_plunder, 0.01)

	var pk := EvoTypes.make_pair_key(raider.id, victim.id)
	if int(state.active_pacts.get(pk, 0)) < 2:
		state.active_pacts[pk] = mini(-2, int(state.active_pacts.get(pk, 0)))
	EvoTypes.push_event(state, "raid", c_raider.id, c_victim.id, raider.id, victim.id, loot, v_loss + r_loss)

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
	var p_r_disp := float(ap_r[2]) if ap_r.size() >= 4 else EvoEcologyInteraction.get_archetype_prob(raider, state.decisions_catalog, "dispute")
	var p_r_over := float(ap_r[3]) if ap_r.size() >= 4 else EvoEcologyInteraction.get_archetype_prob(raider, state.decisions_catalog, "overexploit")
	var p_v_disp := float(ap_v[2]) if ap_v.size() >= 4 else EvoEcologyInteraction.get_archetype_prob(victim, state.decisions_catalog, "dispute")
	var p_v_coop := float(ap_v[0]) if ap_v.size() >= 4 else EvoEcologyInteraction.get_archetype_prob(victim, state.decisions_catalog, "cooperate")
	var p_v_exch := float(ap_v[1]) if ap_v.size() >= 4 else EvoEcologyInteraction.get_archetype_prob(victim, state.decisions_catalog, "exchange")

	var warrior_r := 0.35 if raider.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var warrior_v := 0.30 if victim.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	var pact_defense_bonus := compute_pact_defense_bonus(victim, state)
	var fort_bonus: float = EvoEcologyInteraction.DEFENSE_TIER_BONUS[clampi(victim.defense_tier, 0, 3)]

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

	if _can_pay_tribute(victim, p_v_coop, p_v_exch, p_v_disp):
		return _execute_tribute(raider, victim, c_raider, c_victim, state, lang, turn_geopolitical_flows)

	return _execute_raid(
		raider,
		victim,
		c_raider,
		c_victim,
		state,
		lang,
		extracted_energy_by_deme,
		turn_geopolitical_flows,
		raider_score,
		defense_score
	)


static func _run_cross_border_raids(
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
	var raided_by_deme: Dictionary = {}
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
				raided_by_deme[d1.id] = true
				continue

		if _can_attempt_raid(d2, d1, c2, state, v2, extracted_energy_by_deme, ap2):
			if _execute_raid_if_successful(d2, d1, c2, c1, state, lang, v2, v1, extracted_energy_by_deme, turn_geopolitical_flows, ap2, ap1):
				raided_pairs[pair_key] = true
				raided_by_deme[d2.id] = true

	for raider_id in state.demes.keys():
		if raided_by_deme.has(raider_id):
			continue
		var raider: EvoTypes.Deme = state.demes[raider_id]
		if not raider.cultural_trait_ids.has("cul-warrior-expansion") or not state.cells.has(raider.hex_id):
			continue
		var ap_r: Array = arch_probs.get(raider.id, [0.0, 0.0, 0.0, 0.0])
		if float(ap_r[2]) < 0.25:
			continue
		var c_raider: EvoTypes.HexCell = state.cells[raider.hex_id]
		if c_raider.biome == "ocean" or c_raider.altitude > 0.85:
			continue
		var v_r: EvoTypes.BiophysicalVector = effective_vec_by_deme[raider.id]
		var best_victim: EvoTypes.Deme = null
		var best_c_victim: EvoTypes.HexCell = null
		var best_wealth: float = -1.0
		var seen_d2_victims: Dictionary = {}
		for nid in HexMath.get_neighbor_ids(c_raider.q, c_raider.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if ncell.biome == "ocean" or ncell.altitude > 0.85:
				continue
			for n2id in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
				if n2id == c_raider.id:
					continue
				var n2cell: EvoTypes.HexCell = state.cells[n2id]
				if n2cell.biome == "ocean" or n2cell.altitude > 0.85 or HexMath.hex_distance(c_raider.q, c_raider.r, n2cell.q, n2cell.r) != 2:
					continue
				var target_ids: Array[String] = []
				for vid in n2cell.deme_ids:
					target_ids.append(vid)
				if n2cell.owner_deme_id != "" and n2cell.owner_deme_id != raider.id and n2cell.land_use in ["crops", "pasture"] and not target_ids.has(n2cell.owner_deme_id):
					target_ids.append(n2cell.owner_deme_id)
				for vid in target_ids:
					if seen_d2_victims.has(vid) or not state.demes.has(vid):
						continue
					seen_d2_victims[vid] = true
					var victim: EvoTypes.Deme = state.demes[vid]
					if victim.id == raider.id or victim.lineage_id == raider.lineage_id or not state.cells.has(victim.hex_id):
						continue
					var pk := EvoTypes.make_pair_key(raider.id, victim.id)
					if betrayed_pairs_this_turn.has(pk) or raided_pairs.has(pk) or int(state.active_pacts.get(pk, 0)) >= 2:
						continue
					if not _can_attempt_raid(raider, victim, c_raider, state, v_r, extracted_energy_by_deme, ap_r):
						continue
					var wealth := victim.energy_reserves + float(extracted_energy_by_deme.get(victim.id, 0.0)) + n2cell.current_resources * 0.15
					if wealth > best_wealth:
						best_wealth = wealth
						best_victim = victim
						best_c_victim = state.cells[victim.hex_id]
		if best_victim != null and best_c_victim != null:
			var v_v: EvoTypes.BiophysicalVector = effective_vec_by_deme[best_victim.id]
			var ap_v: Array = arch_probs[best_victim.id]
			var pk := EvoTypes.make_pair_key(raider.id, best_victim.id)
			if _execute_raid_if_successful(raider, best_victim, c_raider, best_c_victim, state, lang, v_r, v_v, extracted_energy_by_deme, turn_geopolitical_flows, ap_r, ap_v):
				raided_pairs[pk] = true
				raided_by_deme[raider.id] = true


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
	_run_cross_border_raids(
		state,
		lang,
		effective_vec_by_deme,
		extracted_energy_by_deme,
		turn_geopolitical_flows,
		betrayed_pairs_this_turn,
		arch_probs,
		adjacent_pairs
	)
