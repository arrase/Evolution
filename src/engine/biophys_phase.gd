class_name EvoBiophysPhase
extends RefCounted


static func compute_effective_vector(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> EvoTypes.BiophysicalVector:
	return EvoEcologyInteraction.compute_effective_vector(deme, state)


static func get_archetype_prob(
	deme: EvoTypes.Deme,
	decisions_catalog: Dictionary,
	archetype: String
) -> float:
	return EvoEcologyInteraction.get_archetype_prob(deme, decisions_catalog, archetype)


static func is_hex_passable_for_deme(cell: EvoTypes.HexCell, spatial_mobility: float) -> bool:
	return EvoDemographyMigration.is_hex_passable_for_deme(cell, spatial_mobility)


static func compute_deme_divergence(deme_a: EvoTypes.Deme, deme_b: EvoTypes.Deme) -> float:
	return EvoDemographyMigration.compute_deme_divergence(deme_a, deme_b)


static func _build_edge_flows(
	state: EvoTypes.WorldState,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow]
) -> void:
	for geo_flow in turn_geopolitical_flows:
		if not state.active_flows.has(geo_flow):
			state.active_flows.append(geo_flow)


static func run_biophysical_phase(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var initial_pop_by_deme: Dictionary = {}
	var effective_vec_by_deme: Dictionary = {}
	var hawk_penalty_by_deme: Dictionary = {}
	var extracted_energy_by_deme: Dictionary = {}
	var turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow] = []

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.last_decision_probabilities.is_empty() and state.cells.has(deme.hex_id):
			var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
			EvoHeuristicScorer.modulate_deme_probabilities_for_turn(deme, cell, state)
		initial_pop_by_deme[deme.id] = deme.population
		hawk_penalty_by_deme[deme.id] = 1.0
		extracted_energy_by_deme[deme.id] = 0.0
		effective_vec_by_deme[deme.id] = compute_effective_vector(deme, state)

	EvoEcologyInteraction.run_resource_and_symbiosis_phase(
		state,
		lang,
		effective_vec_by_deme,
		hawk_penalty_by_deme,
		extracted_energy_by_deme,
		turn_geopolitical_flows
	)
	EvoDemographyMigration.run_demography_and_migration_phase(
		state,
		lang,
		initial_pop_by_deme,
		effective_vec_by_deme,
		hawk_penalty_by_deme,
		extracted_energy_by_deme,
		turn_geopolitical_flows
	)
	_build_edge_flows(state, turn_geopolitical_flows)
