class_name EvoEcologyInteraction
extends RefCounted

const DEFENSE_TIER_BONUS: Array[float] = [0.0, 0.45, 0.95, 1.55]
const DEFENSE_ATTENUATION_SCALE: Array[float] = [1.0, 0.75, 0.50, 0.30]


static func get_max_rural_quota(tier: int) -> int:
	return EvoRuralHinterland.get_max_rural_quota(tier)


static func enforce_rural_hinterland_quotas(state: EvoTypes.WorldState) -> void:
	EvoRuralHinterland.enforce_rural_hinterland_quotas(state)


static func _update_and_harvest_rural_hinterlands(
	state: EvoTypes.WorldState,
	effective_vec_by_deme: Dictionary,
	extracted_energy_by_deme: Dictionary
) -> void:
	EvoRuralHinterland._update_and_harvest_rural_hinterlands(state, effective_vec_by_deme, extracted_energy_by_deme)


static func compute_pact_defense_bonus(
	victim: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> float:
	return EvoDiplomacyRaids.compute_pact_defense_bonus(victim, state)


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
	EvoDiplomacyRaids._execute_betrayal(
		betrayer,
		victim,
		c_betrayer,
		c_victim,
		pair_key,
		state,
		lang,
		extracted_energy_by_deme,
		turn_geopolitical_flows
	)


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
	EvoDiplomacyRaids._run_pacts_and_betrayals(
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


static func _run_defense_fortification_phase(
	state: EvoTypes.WorldState,
	lang: String,
	arch_probs: Dictionary
) -> void:
	EvoDiplomacyRaids._run_defense_fortification_phase(state, lang, arch_probs)


static func _can_attempt_raid(
	raider: EvoTypes.Deme,
	victim: EvoTypes.Deme,
	c_raider: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	vec_r: EvoTypes.BiophysicalVector,
	extracted_energy_by_deme: Dictionary,
	ap_r: Array = []
) -> bool:
	return EvoDiplomacyRaids._can_attempt_raid(
		raider,
		victim,
		c_raider,
		state,
		vec_r,
		extracted_energy_by_deme,
		ap_r
	)


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
	return EvoDiplomacyRaids._execute_raid_if_successful(
		raider,
		victim,
		c_raider,
		c_victim,
		state,
		lang,
		vec_r,
		vec_v,
		extracted_energy_by_deme,
		turn_geopolitical_flows,
		ap_r,
		ap_v
	)


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
	EvoDiplomacyRaids._run_cross_border_raids(
		state,
		lang,
		effective_vec_by_deme,
		extracted_energy_by_deme,
		turn_geopolitical_flows,
		betrayed_pairs_this_turn,
		arch_probs,
		adjacent_pairs
	)


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


static func compute_all_archetype_probs(
	deme: EvoTypes.Deme,
	decisions_catalog: Dictionary
) -> Array:
	var p_coop: float = 0.0
	var p_exch: float = 0.0
	var p_disp: float = 0.0
	var p_over: float = 0.0
	for dec_id in deme.last_decision_probabilities.keys():
		if decisions_catalog.has(dec_id):
			var arch := (decisions_catalog[dec_id] as EvoTypes.DecisionDef).archetype
			var prob := float(deme.last_decision_probabilities[dec_id])
			if arch == "cooperate":
				p_coop += prob
			elif arch == "exchange":
				p_exch += prob
			elif arch == "dispute":
				p_disp += prob
			elif arch == "overexploit":
				p_over += prob
	return [p_coop, p_exch, p_disp, p_over]


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
		arch_probs[d.id] = compute_all_archetype_probs(d, state.decisions_catalog)
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
		if cell.deme_ids.is_empty():
			continue
		var deme: EvoTypes.Deme = state.demes.get(cell.deme_ids[0])
		if deme == null:
			continue

		var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[deme.id]
		var tier := deme.get_village_tier()
		var urban_forage_mult: float = 1.0 if tier <= 2 else (0.55 if tier == 3 else 0.30)
		var total_demand := maxf(
			0.0,
			float(deme.population) * 0.50 * (1.0 + 0.60 * v_eff.extraction_efficiency) * urban_forage_mult
		)
		var total_extracted := minf(cell.current_resources, total_demand)
		extracted_energy_by_deme[deme.id] = total_extracted
		cell.current_resources = maxf(0.0, snappedf(cell.current_resources - total_extracted, 0.01))

		var gamma_season := 1.20 if state.season == "wet_warm" else 0.75
		var natural_regen := cell.carrying_capacity * cell.seasonal_regen_rate * gamma_season
		var sum_eco_impact := v_eff.ecological_impact
		var has_intensive_overexploit := float((arch_probs[deme.id] as Array)[3]) >= 0.30

		var already_logged_tragedy := tragedy_hexes.has(cell.id)

		if (total_extracted > natural_regen or (cell.current_resources <= 0.0 and total_demand > natural_regen)) and (sum_eco_impact < -0.15 or (has_intensive_overexploit and sum_eco_impact < -0.10)):
			var degraded_k := maxf(10.0, snappedf(cell.carrying_capacity * (1.0 + 0.13 * sum_eco_impact), 0.01))
			cell.carrying_capacity = degraded_k
			if cell.current_resources > degraded_k:
				cell.current_resources = degraded_k

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
				entry.deme_id = deme.id
				entry.lineage_id = deme.lineage_id
				state.chronicle.append(entry)
		elif sum_eco_impact > 0.10 and not has_intensive_overexploit:
			cell.carrying_capacity = snappedf(
				clampf(cell.carrying_capacity * (1.0 + 0.05 * sum_eco_impact), 10.0, cell.carrying_capacity_max),
				0.01
			)

	EvoRuralHinterland._update_and_harvest_rural_hinterlands(state, effective_vec_by_deme, extracted_energy_by_deme)

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
			if bad1 or c2.biome == "ocean" or c2.altitude > 0.85:
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

				var can_transfer_inter_hex := true
				if donor.lineage_id != receiver.lineage_id:
					var p_disp_d := float((arch_probs[donor.id] as Array)[2])
					var p_disp_r := float((arch_probs[receiver.id] as Array)[2])
					var has_pact := EvoTypes.is_pact_active(state, donor.id, receiver.id)
					var either_warrior := donor.cultural_trait_ids.has("cul-warrior-expansion") or receiver.cultural_trait_ids.has("cul-warrior-expansion")
					if p_disp_d >= 0.22 or p_disp_r >= 0.22:
						can_transfer_inter_hex = false
					elif either_warrior and not has_pact:
						can_transfer_inter_hex = false
				if can_transfer_inter_hex and EvoCatalog.deme_has_cultural_capacity(receiver, state.traits_catalog):
					var receiver_social := (effective_vec_by_deme[receiver.id] as EvoTypes.BiophysicalVector).social_cohesion
					for tid_var in donor_initial_traits:
						var tid := str(tid_var)
						if donor.lineage_id != receiver.lineage_id and tid == "cul-communal-conservation" and receiver.cultural_trait_ids.has("cul-warrior-expansion"):
							continue
						if not _can_acquire_trait(receiver, tid, state.traits_catalog):
							continue
						var tdef: EvoTypes.TraitDef = state.traits_catalog[tid]
						if receiver_social >= tdef.vector.transmission_threshold:
							receiver.cultural_trait_ids.append(tid)
							effective_vec_by_deme[receiver.id] = compute_effective_vector(receiver, state)
							EvoTypes.push_event(state, "symbiosis", donor_cell.id, ncell.id, donor.id, receiver.id, 1.0, 0)
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
	EvoDiplomacyRaids._run_pacts_and_betrayals(
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
	EvoDiplomacyRaids._run_cross_border_raids(
		state,
		lang,
		effective_vec_by_deme,
		extracted_energy_by_deme,
		turn_geopolitical_flows,
		betrayed_pairs_this_turn,
		arch_probs,
		adjacent_pairs
	)
	EvoDiplomacyRaids._run_defense_fortification_phase(state, lang, arch_probs)
