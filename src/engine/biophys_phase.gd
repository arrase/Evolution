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
	if turn_geopolitical_flows.is_empty():
		return
	var active_set: Dictionary = {}
	for fl in state.active_flows:
		active_set[fl] = true
	for geo_flow in turn_geopolitical_flows:
		if geo_flow.from_deme_id == geo_flow.to_deme_id and geo_flow.from_hex_id == geo_flow.to_hex_id and geo_flow.flow_type != "migration":
			continue
		if not active_set.has(geo_flow):
			active_set[geo_flow] = true
			state.active_flows.append(geo_flow)


static func run_ecology_and_borders_step(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
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
	_build_edge_flows(state, turn_geopolitical_flows)

	var ctx := {
		"initial_pop_by_deme": initial_pop_by_deme,
		"effective_vec_by_deme": effective_vec_by_deme,
		"hawk_penalty_by_deme": hawk_penalty_by_deme,
		"extracted_energy_by_deme": extracted_energy_by_deme,
		"turn_geopolitical_flows": turn_geopolitical_flows
	}
	state.set_meta("_step3_ctx", ctx)
	return ctx


static func run_demography_and_migration_step(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var initial_pop_by_deme: Dictionary = {}
	var effective_vec_by_deme: Dictionary = {}
	var hawk_penalty_by_deme: Dictionary = {}
	var extracted_energy_by_deme: Dictionary = {}
	var turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow] = []

	if state.has_meta("_step3_ctx"):
		var ctx: Dictionary = state.get_meta("_step3_ctx")
		state.remove_meta("_step3_ctx")
		initial_pop_by_deme = ctx["initial_pop_by_deme"]
		effective_vec_by_deme = ctx["effective_vec_by_deme"]
		hawk_penalty_by_deme = ctx["hawk_penalty_by_deme"]
		extracted_energy_by_deme = ctx["extracted_energy_by_deme"]
		turn_geopolitical_flows = ctx["turn_geopolitical_flows"]

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if not initial_pop_by_deme.has(deme.id):
			initial_pop_by_deme[deme.id] = deme.population
		if not hawk_penalty_by_deme.has(deme.id):
			hawk_penalty_by_deme[deme.id] = 1.0
		if not extracted_energy_by_deme.has(deme.id):
			extracted_energy_by_deme[deme.id] = 0.0
		if not effective_vec_by_deme.has(deme.id):
			effective_vec_by_deme[deme.id] = compute_effective_vector(deme, state)

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


static func run_biophysical_phase(state: EvoTypes.WorldState, lang: String = "es") -> void:
	run_ecology_and_borders_step(state, lang)
	run_demography_and_migration_step(state, lang)
