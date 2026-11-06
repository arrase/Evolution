class_name EvoEcologyInteraction
extends RefCounted


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


static func run_resource_and_symbiosis_phase(
	state: EvoTypes.WorldState,
	lang: String,
	effective_vec_by_deme: Dictionary,
	hawk_penalty_by_deme: Dictionary,
	extracted_energy_by_deme: Dictionary
) -> void:
	var is_en := lang == "en"
	var symbiosis_bonus_applied: Dictionary = {}

	var tragedy_hexes: Dictionary = {}
	for entry in state.chronicle:
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
			demand_by_deme[deme.id] = maxf(
				0.0,
				float(deme.population) * 0.50 * (1.0 + 0.60 * v_eff.extraction_efficiency)
			)

		var hawks: Array[EvoTypes.Deme] = []
		var doves: Array[EvoTypes.Deme] = []
		var exchangers: Array[EvoTypes.Deme] = []

		for deme in resident_demes:
			if get_archetype_prob(deme, state.decisions_catalog, "dispute") >= 0.25:
				hawks.append(deme)
			else:
				doves.append(deme)
			if get_archetype_prob(deme, state.decisions_catalog, "exchange") >= 0.20:
				exchangers.append(deme)

		if resident_demes.size() >= 2:
			if hawks.size() >= 2:
				for i in range(hawks.size()):
					var hawk := hawks[i]
					var opp := hawks[(i + 1) % hawks.size()]
					hawk.population = maxi(1, int(floor(float(hawk.population) * 0.85)))
					hawk_penalty_by_deme[hawk.id] = 1.25
					var v_eff: EvoTypes.BiophysicalVector = effective_vec_by_deme[hawk.id]
					demand_by_deme[hawk.id] = maxf(
						0.0,
						float(hawk.population) * 0.50 * (1.0 + 0.60 * v_eff.extraction_efficiency)
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
				var sum_dove_social: float = 0.0
				for dove in doves:
					sum_dove_social += (effective_vec_by_deme[dove.id] as EvoTypes.BiophysicalVector).social_cohesion
				var avg_dove_social := sum_dove_social / float(doves.size())

				for hawk in hawks:
					var hawk_social := (effective_vec_by_deme[hawk.id] as EvoTypes.BiophysicalVector).social_cohesion
					var capture_mult := 0.25 * (1.0 + maxf(0.0, hawk_social - avg_dove_social))
					var hawk_demand := float(demand_by_deme[hawk.id])
					var req_bonus := hawk_demand * capture_mult
					var total_dove_demand: float = 0.0
					for dove in doves:
						total_dove_demand += float(demand_by_deme[dove.id])
					var actual_captured := minf(total_dove_demand, req_bonus)

					demand_by_deme[hawk.id] = hawk_demand + actual_captured
					if total_dove_demand > 0.0:
						for dove in doves:
							var cur_d := float(demand_by_deme[dove.id])
							var share := cur_d / total_dove_demand
							demand_by_deme[dove.id] = maxf(0.0, cur_d - actual_captured * share)

					var flow := EvoTypes.HexEdgeFlow.new()
					flow.from_hex_id = cell.id
					flow.to_hex_id = cell.id
					flow.flow_type = "dispute"
					flow.intensity = 0.65
					flow.from_deme_id = hawk.id
					flow.to_deme_id = doves[0].id
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

			for donor in exchangers:
				for receiver in exchangers:
					if donor.id == receiver.id:
						continue
					if not EvoCatalog.deme_has_cultural_capacity(receiver, state.traits_catalog):
						continue
					var receiver_social := (effective_vec_by_deme[receiver.id] as EvoTypes.BiophysicalVector).social_cohesion
					for tid in donor.cultural_trait_ids:
						if receiver.cultural_trait_ids.has(tid):
							continue
						if state.traits_catalog.has(tid):
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

		var natural_regen := cell.carrying_capacity * cell.seasonal_regen_rate
		var sum_eco_impact: float = 0.0
		var has_intensive_overexploit := false
		for deme in resident_demes:
			sum_eco_impact += (effective_vec_by_deme[deme.id] as EvoTypes.BiophysicalVector).ecological_impact
			if get_archetype_prob(deme, state.decisions_catalog, "overexploit") >= 0.30:
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
		elif sum_eco_impact > 0.10 and not has_intensive_overexploit and not already_logged_tragedy:
			cell.carrying_capacity = snappedf(
				clampf(cell.carrying_capacity * (1.0 + 0.05 * sum_eco_impact), 10.0, cell.carrying_capacity_max),
				0.01
			)

	for donor_id in state.demes.keys():
		var donor: EvoTypes.Deme = state.demes[donor_id]
		if get_archetype_prob(donor, state.decisions_catalog, "exchange") < 0.20:
			continue
		if not state.cells.has(donor.hex_id):
			continue
		var donor_cell: EvoTypes.HexCell = state.cells[donor.hex_id]
		for nid in HexMath.get_neighbor_ids(donor_cell.q, donor_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			for ndeme_id in ncell.deme_ids:
				if not state.demes.has(ndeme_id):
					continue
				var receiver: EvoTypes.Deme = state.demes[ndeme_id]
				if get_archetype_prob(receiver, state.decisions_catalog, "exchange") < 0.20:
					continue

				if not symbiosis_bonus_applied.has(donor.id):
					var base_ext := float(extracted_energy_by_deme[donor.id])
					extracted_energy_by_deme[donor.id] = snappedf(base_ext * 1.20, 0.0001)
					symbiosis_bonus_applied[donor.id] = true

				var flow := EvoTypes.HexEdgeFlow.new()
				flow.from_hex_id = donor_cell.id
				flow.to_hex_id = ncell.id
				flow.flow_type = "exchange"
				flow.intensity = 0.55
				flow.from_deme_id = donor.id
				flow.to_deme_id = receiver.id
				state.active_flows.append(flow)

				if EvoCatalog.deme_has_cultural_capacity(receiver, state.traits_catalog):
					var receiver_social := (effective_vec_by_deme[receiver.id] as EvoTypes.BiophysicalVector).social_cohesion
					for tid in donor.cultural_trait_ids:
						if receiver.cultural_trait_ids.has(tid):
							continue
						if state.traits_catalog.has(tid):
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
