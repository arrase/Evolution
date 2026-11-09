class_name EvoConflictPhase
extends RefCounted

## Resolves betrayals, raids and conquests with `EvoPayoffs` odds and the world RNG.


static func resolve(state: EvoTypes.WorldState, lang: String) -> void:
	for action_type in ["betray", "raid", "conquer"]:
		for did in state.demes.keys():
			if not state.demes.has(did):
				continue
			var deme: EvoTypes.Deme = state.demes[did]
			if str(deme.chosen_action["type"]) != action_type:
				continue
			var other := EvoDiplomacyPhase.adjacent_target(deme, state)
			if other == null or other.lineage_id == deme.lineage_id:
				deme.last_outcome = "Your %s was called off: no valid target." % action_type
				continue
			var rel := EvoTypes.get_relation(state, deme.id, other.id)
			var allied := rel.pact_turns > 0
			if (action_type == "betray") != allied or rel.truce_turns > 0:
				deme.last_outcome = "Your %s against %s was called off." % [action_type, other.name]
				continue
			if action_type == "conquer":
				_conquer(deme, other, rel, state, lang)
			else:
				_raid(deme, other, rel, state, lang, action_type == "betray")


static func _warn_allies(attacker: EvoTypes.Deme, victim: EvoTypes.Deme, state: EvoTypes.WorldState) -> void:
	for pk in state.relations.keys():
		var ally_id := EvoTypes.pair_partner(str(pk), victim.id)
		if ally_id == "" or ally_id == attacker.id or (state.relations[pk] as EvoTypes.Relation).pact_turns <= 0:
			continue
		var ally: EvoTypes.Deme = state.demes[ally_id]
		EvoRelations.record(state, ally, attacker, -0.2, "%s attacked %s's ally %s" % [attacker.name, ally.name, victim.name])
		EvoRelations.remember(ally, state, "%s attacked your ally %s." % [attacker.name, victim.name])


static func _raid(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, rel: EvoTypes.Relation, state: EvoTypes.WorldState, lang: String, surprise: bool) -> void:
	var odds := EvoPayoffs.raid_odds(attacker, defender, state, surprise)
	var provoked := rel.feud_turns > 0
	var won := state.rng.randf() < float(odds["p_win"])
	var verb := "betrayed" if surprise else "raided"
	var loot := 0.0
	var a_loss := mini(attacker.population, int(odds["attacker_loss_win"]) if won else int(odds["attacker_loss_lose"]))
	var d_loss := mini(defender.population, int(odds["defender_loss_win"]) if won else int(odds["defender_loss_lose"]))
	attacker.population -= a_loss
	defender.population -= d_loss
	if won:
		loot = minf(float(odds["loot"]), defender.energy_reserves) + _pillage_field(attacker, defender, state)
		defender.energy_reserves = maxf(0.0, defender.energy_reserves - minf(float(odds["loot"]), defender.energy_reserves))
		attacker.energy_reserves += loot
		attacker.last_outcome = "You %s %s and won: +%d food, lost %d, they lost %d." % [verb, defender.name, int(loot), a_loss, d_loss]
		EvoRelations.remember(defender, state, "%s %s you: you lost %d food and %d people." % [attacker.name, verb, int(loot), d_loss])
	else:
		attacker.last_outcome = "You %s %s but were repelled: lost %d people." % [verb, defender.name, a_loss]
		EvoRelations.remember(defender, state, "You repelled %s's %s (they lost %d)." % [attacker.name, "betrayal" if surprise else "raid", a_loss])

	EvoRelations.start_feud(rel, EvoPayoffs.FEUD_AFTER_BETRAYAL if surprise else EvoPayoffs.FEUD_AFTER_RAID)
	EvoRelations.record(state, attacker, defender, -1.0 if surprise else -0.5, "%s %s %s" % [attacker.name, verb, defender.name])
	EvoRelations.adjust_reputation(attacker, -0.5 if surprise else (0.0 if provoked else -0.08))
	_warn_allies(attacker, defender, state)
	if surprise:
		state.disused_connections.append({
			"from_hex_id": attacker.hex_id,
			"to_hex_id": defender.hex_id,
			"from_deme_id": attacker.id,
			"to_deme_id": defender.id,
			"age": 1,
			"broken_gen": state.generation
		})

	var event_type := "betrayal" if surprise else "raid"
	EvoSettlementPhase.push_flow(state, attacker, defender, event_type, 1.0 if surprise else clampf(loot / 32.0, 0.5, 1.0))
	EvoTypes.push_event(state, event_type, attacker.hex_id, defender.hex_id, attacker.id, defender.id, loot, a_loss + d_loss)
	if not won and not surprise:
		return
	var params := {"raider": attacker.name, "betrayer": attacker.name, "victim": defender.name, "loot": str(int(loot)), "hex": defender.hex_id}
	EvoSettlementPhase.chronicle(state, "chronicle-%s-%d-%s-%s" % [event_type, state.generation, attacker.id, defender.id], event_type, lang,
		"chronicle_" + event_type, params, defender.hex_id, attacker)


static func _pillage_field(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var fields := EvoRuralHinterland.owned_hexes(defender, state)
	if fields.is_empty():
		return 0.0
	var field := fields[0]
	var plunder := minf(field.current_resources * 0.3, 20.0)
	field.current_resources -= plunder
	if defender.defense_tier < 2:
		field.owner_deme_id = ""
		field.land_use = "wild"
		field.has_ruins = true
		EvoTypes.push_event(state, "pillage", attacker.hex_id, field.id, attacker.id, defender.id, plunder, 0)
	return plunder


static func _conquer(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, rel: EvoTypes.Relation, state: EvoTypes.WorldState, lang: String) -> void:
	var odds := EvoPayoffs.conquest_odds(attacker, defender, state)
	var troops := int(odds["troops"])
	var provoked := rel.feud_turns > 0
	var origin_hex := attacker.hex_id
	var target_hex := defender.hex_id
	var params := {"attacker": attacker.name, "defender": defender.name, "hex": target_hex}
	EvoRelations.start_feud(rel, EvoPayoffs.FEUD_AFTER_WAR)
	EvoRelations.record(state, attacker, defender, -0.7, "%s attacked %s to conquer it" % [attacker.name, defender.name])
	EvoRelations.adjust_reputation(attacker, 0.0 if provoked else -0.15)
	_warn_allies(attacker, defender, state)
	attacker.population -= troops

	if state.rng.randf() < float(odds["p_win"]):
		var a_loss := int(odds["attacker_loss_win"])
		var d_loss := mini(defender.population, int(odds["defender_loss_win"]))
		defender.population -= d_loss
		var loot := roundf(defender.energy_reserves * 0.5)
		defender.energy_reserves -= loot
		var captured_tier := maxi(0, defender.defense_tier - 1)
		var warband := EvoSettlementPhase.occupy_conquered_hex(attacker, defender, troops - a_loss, loot, captured_tier, state)
		EvoRelations.start_feud(EvoTypes.get_relation(state, warband.id, defender.id), EvoPayoffs.FEUD_AFTER_WAR)
		attacker.last_outcome = "You conquered %s's hex %s: %d warriors now hold it with %d food." % [defender.name, target_hex, warband.population, int(loot)]
		EvoRelations.remember(warband, state, "Your warriors took this hex from %s." % defender.name)
		EvoRelations.remember(defender, state, "%s conquered your home %s; %d of your people died." % [attacker.name, target_hex, d_loss])
		var flow := EvoTypes.HexEdgeFlow.new()
		flow.from_hex_id = origin_hex
		flow.to_hex_id = target_hex
		flow.flow_type = "war"
		flow.intensity = 1.0
		flow.from_deme_id = attacker.id
		flow.to_deme_id = warband.id
		state.active_flows.append(flow)
		EvoTypes.push_event(state, "war", origin_hex, target_hex, attacker.id, defender.id, loot, a_loss + d_loss)
		params["casualties"] = str(a_loss + d_loss)
		params["loot"] = str(int(loot))
		EvoSettlementPhase.chronicle(state, "chronicle-war-win-%d-%s-%s" % [state.generation, attacker.id, defender.id], "war", lang,
			"chronicle_war_victory", params, target_hex, warband)
		return

	var lost := int(odds["attacker_loss_lose"])
	var d_lost := mini(defender.population, int(odds["defender_loss_lose"]))
	attacker.population += troops - lost
	defender.population -= d_lost
	params["casualties"] = str(lost + d_lost)
	attacker.last_outcome = "Your assault on %s failed: %d warriors died." % [defender.name, lost]
	EvoRelations.remember(defender, state, "You repelled %s's invasion (they lost %d)." % [attacker.name, lost])
	EvoSettlementPhase.push_flow(state, attacker, defender, "war", 0.85)
	EvoTypes.push_event(state, "war_repelled", origin_hex, target_hex, attacker.id, defender.id, 0.0, lost + d_lost)
	if defender.defense_tier >= 1:
		EvoSettlementPhase.push_flow(state, attacker, defender, "siege", 0.9)
		EvoTypes.push_event(state, "siege", origin_hex, target_hex, attacker.id, defender.id, float(defender.defense_tier), d_lost)
		EvoSettlementPhase.chronicle(state, "chronicle-siege-%d-%s-%s" % [state.generation, defender.id, attacker.id], "siege", lang,
			"chronicle_siege", params, target_hex, defender)
	EvoSettlementPhase.chronicle(state, "chronicle-war-repel-%d-%s-%s" % [state.generation, defender.id, attacker.id], "war", lang,
		"chronicle_war_repelled", params, target_hex, defender)
