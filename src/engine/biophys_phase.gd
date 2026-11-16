class_name EvoBiophysPhase
extends RefCounted


static func _increment_baldwin(deme: EvoTypes.Deme, action_type: String) -> void:
	var prev_cnt := int(deme.baldwin_counters[action_type]) if deme.baldwin_counters.has(action_type) else 0
	deme.baldwin_counters[action_type] = prev_cnt + 1


static func run_biophysical_phase(state: EvoTypes.WorldState, lang: String = "es") -> void:
	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.domestic_action != "forage":
			_increment_baldwin(deme, deme.domestic_action)
		var ext_type := str(deme.chosen_action["type"])
		if ext_type != "none" and ext_type != "forage" and ext_type != deme.domestic_action:
			_increment_baldwin(deme, ext_type)

	var income_by_deme := EvoEconomyPhase.harvest(state, lang)
	EvoDiplomacyPhase.resolve(state, lang, income_by_deme)
	EvoEconomyPhase.invest(state, lang)
	EvoConflictPhase.resolve(state, lang)
	EvoSettlementPhase.remove_extinct(state, lang)
	EvoSettlementPhase.resolve_settling(state)
	EvoEconomyPhase.metabolize(state, income_by_deme, lang)
	EvoEpidemicSalubrity._run_epidemic_phase(state, lang, [])
	EvoSettlementPhase.remove_extinct(state, lang)
	EvoSettlementPhase.revalidate_walled_unions(state)
	EvoRuralHinterland.enforce_rural_hinterland_quotas(state)
	EvoSettlementPhase.update_isolation(state)
	EvoRelations.tick(state)
