class_name EvoEpidemicSalubrity
extends RefCounted


static func compute_deme_salubrity(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> float:
	var union_partners: int = 0
	if deme.walled_union_id != "":
		for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			for p_id in ncell.deme_ids:
				if p_id != deme.id and state.demes.has(p_id):
					var partner: EvoTypes.Deme = state.demes[p_id]
					if partner.population > 0 and partner.walled_union_id == deme.walled_union_id:
						union_partners += 1

	var sal_crowding := (
		float(deme.population) / maxf(20.0, cell.carrying_capacity)
		+ 0.16 * float(maxi(0, deme.get_village_tier() - 2))
		+ 0.14 * float(union_partners)
	)
	var sanitation := (
		(0.20 if deme.cultural_trait_ids.has("cul-communal-conservation") else 0.0)
		+ (0.14 if deme.biological_trait_ids.has("bio-k-strategy") else 0.0)
		+ 0.08 * maxf(0.0, cell.humidity)
	)
	var target_salubrity := clampf(1.12 - 0.48 * maxf(0.0, sal_crowding - 0.60) + sanitation, 0.05, 1.0)
	deme.salubrity = snappedf(lerpf(deme.salubrity, target_salubrity, 0.45), 0.0001)
	return deme.salubrity


static func _has_recent_famine_chronicle(state: EvoTypes.WorldState, deme_id: String) -> bool:
	var cutoff := state.generation - 2
	for i in range(state.chronicle.size() - 1, -1, -1):
		var entry := state.chronicle[i]
		if entry.generation < cutoff:
			break
		if entry.event_type == "famine" and entry.deme_id == deme_id:
			return true
	return false


static func _run_epidemic_phase(
	state: EvoTypes.WorldState,
	lang: String,
	turn_geopolitical_flows: Array[EvoTypes.HexEdgeFlow]
) -> void:
	var infected_sources: Array[EvoTypes.Deme] = []
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		if d.infection_turns > 0 and state.cells.has(d.hex_id):
			infected_sources.append(d)

	var newly_infected_by_target: Dictionary = {}
	if not infected_sources.is_empty():
		var contact_pairs: Dictionary = {}
		for fl in state.active_flows:
			if fl.flow_type in ["exchange", "cooperate", "pact", "tribute", "raid", "war", "siege"] and fl.from_deme_id != "" and fl.to_deme_id != "":
				contact_pairs[EvoTypes.make_pair_key(fl.from_deme_id, fl.to_deme_id)] = true
		for fl in turn_geopolitical_flows:
			if fl.flow_type in ["exchange", "cooperate", "pact", "tribute", "raid", "war", "siege"] and fl.from_deme_id != "" and fl.to_deme_id != "":
				contact_pairs[EvoTypes.make_pair_key(fl.from_deme_id, fl.to_deme_id)] = true

		for source_deme in infected_sources:
			for tid in state.demes.keys():
				if tid == source_deme.id or newly_infected_by_target.has(tid):
					continue
				var target_deme: EvoTypes.Deme = state.demes[tid]
				if target_deme.infection_turns > 0 or target_deme.immunity_turns > 0 or target_deme.salubrity >= 0.70 or target_deme.population < 40:
					continue
				var pk := EvoTypes.make_pair_key(source_deme.id, target_deme.id)
				if EvoTypes.is_pact_active(state, source_deme.id, target_deme.id) or contact_pairs.has(pk):
					newly_infected_by_target[target_deme.id] = source_deme.id

	var was_active_or_immune: Dictionary = {}
	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.infection_turns > 0 or deme.immunity_turns > 0:
			was_active_or_immune[deme.id] = true
		if deme.immunity_turns > 0:
			deme.immunity_turns -= 1
		elif deme.infection_turns > 0:
			var loss := maxi(4, int(round(float(deme.population) * 0.06)))
			deme.population = maxi(10, deme.population - loss)
			deme.infection_turns -= 1
			if deme.infection_turns == 0:
				deme.immunity_turns = 6
				deme.salubrity = minf(1.0, snappedf(deme.salubrity + 0.25, 0.0001))
				EvoTypes.push_event(state, "epidemic_recovered", deme.hex_id, deme.hex_id, deme.id, deme.id, deme.salubrity, 0)
				var rec_params := {
					"deme": deme.name,
					"hex": deme.hex_id
				}
				var rec_entry := EvoTypes.ChronicleEntry.new()
				rec_entry.id = "chronicle-epi-rec-%d-%s" % [state.generation, deme.id]
				rec_entry.generation = state.generation
				rec_entry.event_type = "epidemic_recovered"
				rec_entry.title = EvoI18n.t(lang, "chronicle_epidemic_recovered_title", rec_params)
				rec_entry.causal_explanation = EvoI18n.t(lang, "chronicle_epidemic_recovered_desc", rec_params)
				rec_entry.hex_id = deme.hex_id
				rec_entry.deme_id = deme.id
				rec_entry.lineage_id = deme.lineage_id
				state.chronicle.append(rec_entry)

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if was_active_or_immune.has(deme.id):
			continue
		if deme.infection_turns == 0 and deme.immunity_turns == 0 and deme.salubrity < 0.35 and deme.population >= 130:
			var epi_loss := maxi(10, int(round(float(deme.population) * 0.15)))
			deme.population = maxi(10, deme.population - epi_loss)
			deme.infection_turns = 2
			EvoTypes.push_event(state, "epidemic", deme.hex_id, deme.hex_id, deme.id, deme.id, deme.salubrity, epi_loss)
			var epi_params := {
				"deme": deme.name,
				"hex": deme.hex_id,
				"casualties": str(epi_loss)
			}
			var epi_entry := EvoTypes.ChronicleEntry.new()
			epi_entry.id = "chronicle-epidemic-%d-%s" % [state.generation, deme.id]
			epi_entry.generation = state.generation
			epi_entry.event_type = "epidemic"
			epi_entry.title = EvoI18n.t(lang, "chronicle_epidemic_title", epi_params)
			epi_entry.causal_explanation = EvoI18n.t(lang, "chronicle_epidemic_desc", epi_params)
			epi_entry.hex_id = deme.hex_id
			epi_entry.deme_id = deme.id
			epi_entry.lineage_id = deme.lineage_id
			state.chronicle.append(epi_entry)

	for target_id in newly_infected_by_target.keys():
		var source_id := str(newly_infected_by_target[target_id])
		if not state.demes.has(target_id) or not state.demes.has(source_id):
			continue
		var target_deme: EvoTypes.Deme = state.demes[target_id]
		var source_deme: EvoTypes.Deme = state.demes[source_id]
		if target_deme.infection_turns == 0 and target_deme.immunity_turns == 0:
			var spread_loss := maxi(5, int(round(float(target_deme.population) * 0.08)))
			target_deme.population = maxi(10, target_deme.population - spread_loss)
			target_deme.infection_turns = 2
			EvoTypes.push_event(
				state,
				"epidemic_spread",
				source_deme.hex_id,
				target_deme.hex_id,
				source_deme.id,
				target_deme.id,
				target_deme.salubrity,
				spread_loss
			)
			var sp_params := {
				"deme": target_deme.name,
				"source": source_deme.name,
				"hex": target_deme.hex_id,
				"casualties": str(spread_loss)
			}
			var sp_entry := EvoTypes.ChronicleEntry.new()
			sp_entry.id = "chronicle-epi-spread-%d-%s-%s" % [state.generation, source_deme.id, target_deme.id]
			sp_entry.generation = state.generation
			sp_entry.event_type = "epidemic_spread"
			sp_entry.title = EvoI18n.t(lang, "chronicle_epidemic_spread_title", sp_params)
			sp_entry.causal_explanation = EvoI18n.t(lang, "chronicle_epidemic_spread_desc", sp_params)
			sp_entry.hex_id = target_deme.hex_id
			sp_entry.deme_id = target_deme.id
			sp_entry.lineage_id = target_deme.lineage_id
			state.chronicle.append(sp_entry)
