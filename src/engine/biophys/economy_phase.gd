class_name EvoEconomyPhase
extends RefCounted

## Harvest (forage/intensify, fields, pacts, reciprocal trade), self-investment
## (fortify, innovate) and metabolism (food need, births, famine, salubrity).


static func harvest(state: EvoTypes.WorldState, lang: String) -> Dictionary:
	EvoRuralHinterland.claim_hinterlands(state)
	var income_by_deme: Dictionary = {}
	for deme: EvoTypes.Deme in state.demes.values():
		var action_type := str(deme.chosen_action["type"])
		var home := EvoPayoffs.urban_harvest(deme, state, action_type)
		_deduct_urban_harvest(deme, home, state)
		if action_type == "intensify":
			for hid in deme.urban_hex_ids:
				_degrade_land(deme, state.cells[hid], state, lang, EvoPayoffs.INTENSIFY_K_LOSS)
		var rural := EvoRuralHinterland.harvest_rural(deme, state)
		_apply_ecological_impact(deme, action_type, state, lang)
		var income := (home + rural) * EvoPayoffs.pact_multiplier(deme, state)
		income_by_deme[deme.id] = income
		var ptag := EvoRelations.posture_tag(deme)
		if action_type == "forage":
			deme.last_outcome = "You foraged and harvested %d food." % int(income)
			EvoRelations.remember(deme, state, "You foraged (+%d food, stock %d)%s." % [int(income), int(deme.energy_reserves + income), ptag])
		elif action_type == "intensify":
			deme.last_outcome = "You overexploited the land and harvested %d food." % int(income)
			EvoRelations.remember(deme, state, "You overexploited the land (+%d food)%s." % [int(income), ptag])

	var trade_gain_by_deme: Dictionary = {}
	for deme: EvoTypes.Deme in state.demes.values():
		if str(deme.chosen_action["type"]) != "trade":
			continue
		var other := EvoDiplomacyPhase.adjacent_target(deme, state)
		if other == null:
			deme.last_outcome = "Your trade partner is gone."
			continue
		var reciprocated := str(other.chosen_action["key"]) == "trade:" + deme.id
		var gain := EvoPayoffs.trade_gain(deme, other, state) if reciprocated else EvoPayoffs.unreciprocated_trade_gain(deme, other, state)
		trade_gain_by_deme[deme.id] = gain
		var rel := EvoRelations.record(state, deme, other, 0.12 if reciprocated else 0.08, "%s traded with %s" % [deme.name, other.name])
		EvoCulture.diffuse(other, deme, state, lang)
		if rel.proposal_from == other.id and rel.proposal_kind == "pact":
			EvoDiplomacyPhase._form_pact(deme, other, state, lang)
		var ptag := EvoRelations.posture_tag(deme)
		if reciprocated:
			deme.last_outcome = "You traded with %s: +%d food." % [other.name, int(gain)]
			EvoRelations.remember(deme, state, "You traded mutually with %s (+%d food)%s." % [other.name, int(gain), ptag])
			if deme.id < other.id:
				EvoSettlementPhase.push_flow(state, deme, other, "exchange", 0.65)
				EvoRelations.adjust_reputation(deme, 0.03)
				EvoRelations.adjust_reputation(other, 0.03)
		else:
			deme.last_outcome = "You traded with %s (+%d food)." % [other.name, int(gain)]
			EvoRelations.remember(deme, state, "You traded with %s (+%d food)%s." % [other.name, int(gain), ptag])
			EvoSettlementPhase.push_flow(state, deme, other, "exchange", 0.45)
			EvoRelations.adjust_reputation(deme, 0.02)
			EvoRelations.remember(other, state, "%s traded with you (+trust)." % deme.name)
		EvoTypes.push_event(state, "trade", deme.hex_id, other.hex_id, deme.id, other.id, gain, 0)
	for did in trade_gain_by_deme.keys():
		income_by_deme[did] = float(income_by_deme[did]) + float(trade_gain_by_deme[did])

	for deme: EvoTypes.Deme in state.demes.values():
		deme.energy_reserves += float(income_by_deme[deme.id])
	return income_by_deme


static func _deduct_urban_harvest(deme: EvoTypes.Deme, amount: float, state: EvoTypes.WorldState) -> void:
	if amount <= 0.0:
		return
	var total_avail := 0.0
	for hid in deme.urban_hex_ids:
		total_avail += (state.cells[hid] as EvoTypes.HexCell).current_resources
	if total_avail <= 0.0:
		return
	for hid in deme.urban_hex_ids:
		var ucell: EvoTypes.HexCell = state.cells[hid]
		var share := ucell.current_resources / total_avail
		ucell.current_resources = maxf(0.0, ucell.current_resources - amount * share)


static func _apply_ecological_impact(
	deme: EvoTypes.Deme,
	action_type: String,
	state: EvoTypes.WorldState,
	lang: String
) -> void:
	var eco := EvoPayoffs.vector(deme, state).ecological_impact
	if eco >= -0.10 and eco <= 0.20:
		return
	var exploited: Array[EvoTypes.HexCell] = []
	for hid in deme.urban_hex_ids:
		exploited.append(state.cells[hid])
	exploited.append_array(EvoRuralHinterland.owned_hexes(deme, state))
	for ecell in exploited:
		if eco < -0.10 and action_type != "forage":
			_degrade_land(deme, ecell, state, lang, 0.015 * absf(eco))
		elif eco > 0.20:
			ecell.carrying_capacity = minf(
				ecell.carrying_capacity_max,
				ecell.carrying_capacity + 0.02 * eco * ecell.carrying_capacity_max
			)


static func _degrade_land(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	lang: String,
	loss_fraction: float = EvoPayoffs.INTENSIFY_K_LOSS
) -> void:
	var was_healthy := cell.carrying_capacity >= 0.60 * cell.carrying_capacity_max
	cell.carrying_capacity = maxf(10.0, cell.carrying_capacity * (1.0 - loss_fraction))
	cell.current_resources = minf(cell.current_resources, cell.carrying_capacity)
	if was_healthy and cell.carrying_capacity < 0.60 * cell.carrying_capacity_max:
		var is_en := lang == "en"
		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-tragedy-%d-%s" % [state.generation, cell.id]
		entry.generation = state.generation
		entry.event_type = "tragedy_of_commons"
		entry.title = ("Tragedy of the Commons in (%s)" if is_en else "Tragedia de los Comunes en (%s)") % cell.id
		entry.causal_explanation = (
			"Overexploitation by %s degraded carrying capacity below 60%% of its maximum." % deme.name
			if is_en
			else "La sobreexplotación de %s degradó la capacidad de carga por debajo del 60%% de su máximo." % deme.name
		)
		entry.hex_id = cell.id
		entry.deme_id = deme.id
		entry.lineage_id = deme.lineage_id
		state.chronicle.append(entry)


static func invest(state: EvoTypes.WorldState, lang: String) -> void:
	for deme: EvoTypes.Deme in state.demes.values():
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var ptag := EvoRelations.posture_tag(deme)
		match str(deme.chosen_action["type"]):
			"fortify":
				if not EvoPayoffs.can_fortify(deme, cell):
					deme.last_outcome = "You could not afford to fortify."
					continue
				deme.energy_reserves -= EvoPayoffs.fortify_cost_reserves(deme)
				cell.current_resources = maxf(0.0, cell.current_resources - EvoPayoffs.fortify_cost_hex(deme))
				deme.defense_tier += 1
				var wall_name := EvoOutcomeForecast.WALL_NAMES[deme.defense_tier]
				deme.last_outcome = "You built %s." % wall_name
				EvoRelations.remember(deme, state, "You built %s%s." % [wall_name, ptag])
				EvoTypes.push_event(state, "fortify", cell.id, cell.id, deme.id, "", float(deme.defense_tier), 0)
				if deme.defense_tier >= 2:
					var params := {"deme": deme.name, "tier_name": EvoI18n.t(lang, "inspector_defense_%d" % deme.defense_tier), "hex": cell.id}
					EvoSettlementPhase.chronicle(state, "chronicle-fortify-%d-%s" % [state.generation, deme.id], "fortify", lang, "chronicle_fortify", params, cell.id, deme)
			"innovate":
				var step := EvoPayoffs.innovation_step(deme, state)
				deme.innovation_counter = minf(2.0, deme.innovation_counter + step)
				deme.last_outcome = "You experimented: innovation now %.2f of 1.0." % deme.innovation_counter
				EvoRelations.remember(deme, state, "You innovated (%.2f/1.0)%s." % [minf(1.0, deme.innovation_counter), ptag])


static func metabolize(state: EvoTypes.WorldState, income_by_deme: Dictionary, lang: String) -> void:
	for deme: EvoTypes.Deme in state.demes.values():
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		var start_pop := deme.population
		var need := EvoPayoffs.food_need(deme, cell, state)
		var income := float(income_by_deme.get(deme.id, 0.0))
		deme.last_food_intake = snappedf(income, 0.01)
		deme.last_food_need = snappedf(need, 0.01)
		deme.last_energy_delta = snappedf(income - need, 0.01)
		deme.energy_reserves -= need
		EvoEpidemicSalubrity.compute_deme_salubrity(deme, cell, state)
		if deme.energy_reserves < 0.0:
			_famine(deme, cell, state, lang)
		else:
			var births := mini(
				int(roundf(float(deme.population) * EvoPayoffs.growth_rate(deme, state))),
				int(floor(maxf(0.0, deme.energy_reserves - 0.35 * need) / EvoPayoffs.BIRTH_COST))
			)
			deme.population += births
			deme.energy_reserves -= float(births) * EvoPayoffs.BIRTH_COST
		deme.energy_reserves = snappedf(minf(deme.energy_reserves, EvoPayoffs.storage_cap(deme)), 0.01)
		deme.last_population_delta = deme.population - start_pop


static func _famine(deme: EvoTypes.Deme, cell: EvoTypes.HexCell, state: EvoTypes.WorldState, lang: String) -> void:
	var deaths := mini(int(ceil(-deme.energy_reserves / 1.2)), int(ceil(float(deme.population) * 0.25)))
	deme.population -= deaths
	deme.energy_reserves = 0.0
	if deme.defense_tier > 0 and deaths > deme.population / 8:
		deme.defense_tier -= 1
	EvoRelations.remember(deme, state, "Famine killed %d of your people." % deaths)
	EvoTypes.push_event(state, "famine", cell.id, cell.id, deme.id, deme.id, float(deaths), deaths)
	if EvoEpidemicSalubrity._has_recent_famine_chronicle(state, deme.id):
		return
	var params := {"deme": deme.name, "hex": cell.id, "casualties": str(deaths)}
	EvoSettlementPhase.chronicle(state, "chronicle-famine-%d-%s" % [state.generation, deme.id], "famine", lang, "chronicle_famine", params, cell.id, deme)
