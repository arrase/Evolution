class_name EvoConflictPhase
extends RefCounted

## Resolves betrayals, raids and conquests with `EvoPayoffs` odds and the world RNG.


static func resolve(state: EvoTypes.WorldState, lang: String) -> void:
	EvoRelations.resolve_expired_tributes(state, lang)
	for action_type in ["betray", "raid", "conquer"]:
		for did in state.demes.keys():
			if not state.demes.has(did):
				continue
			var deme: EvoTypes.Deme = state.demes[did]
			if str(deme.chosen_action["type"]) != action_type:
				continue
			var other := (
				EvoDiplomacyPhase.tribute_or_raid_target(deme, state)
				if action_type == "raid"
				else EvoDiplomacyPhase.adjacent_target(deme, state)
			)
			if other != null and action_type == "raid" and EvoPayoffs.min_urban_distance(deme, other, state) > 1:
				if EvoPayoffs.closest_defender_field(deme, other, state) == null:
					other = null
			if other == null:
				deme.last_outcome = "Your %s was called off: no valid target." % action_type
				continue
			var rel := EvoTypes.get_relation(state, deme.id, other.id)
			if action_type != "betray" and other.lineage_id == deme.lineage_id and rel.feud_turns == 0:
				deme.last_outcome = "Your %s was called off: %s is peaceful kin." % [action_type, other.name]
				continue
			var allied := rel.pact_turns > 0
			if (action_type == "betray") != allied or rel.truce_turns > 0:
				deme.last_outcome = "Your %s against %s was called off." % [action_type, other.name]
				continue
			if action_type == "conquer":
				_conquer(deme, other, rel, state, lang)
			else:
				_raid(deme, other, rel, state, lang, action_type == "betray", false)


static func _warn_allies(attacker: EvoTypes.Deme, victim: EvoTypes.Deme, state: EvoTypes.WorldState) -> void:
	for pk in state.relations.keys():
		var ally_id := EvoTypes.pair_partner(str(pk), victim.id)
		if ally_id == "" or ally_id == attacker.id or not state.demes.has(ally_id) or (state.relations[pk] as EvoTypes.Relation).pact_turns <= 0:
			continue
		var ally: EvoTypes.Deme = state.demes[ally_id]
		EvoRelations.record(state, ally, attacker, -0.2, "%s attacked %s's ally %s" % [attacker.name, ally.name, victim.name])
		EvoRelations.remember(ally, state, "%s attacked your ally %s." % [attacker.name, victim.name])


static func _posture_phrase(posture: String) -> String:
	if posture == "mobilized_garrison":
		return "mobilized garrison"
	if posture == "patrol_fields":
		return "field patrols"
	return "unprotected fields"


static func _raid(
	attacker: EvoTypes.Deme,
	defender: EvoTypes.Deme,
	rel: EvoTypes.Relation,
	state: EvoTypes.WorldState,
	lang: String,
	surprise: bool,
	from_tribute_refusal: bool = false
) -> void:
	var odds := EvoPayoffs.raid_odds(attacker, defender, state, surprise)
	var border_only := bool(odds["border_only"])
	var p_win := float(odds["p_win"])
	var provoked := rel.feud_turns > 0 or from_tribute_refusal
	var won := state.rng.randf() < p_win
	var verb := "betrayed" if surprise else "raided"
	var loot := 0.0
	var a_loss := mini(attacker.population, int(odds["attacker_loss_win"]) if won else int(odds["attacker_loss_lose"]))
	var d_loss := mini(defender.population, int(odds["defender_loss_win"]) if won else int(odds["defender_loss_lose"]))
	attacker.population -= a_loss
	defender.population -= d_loss
	var target_hex := defender.hex_id
	var ptag := EvoRelations.posture_tag(attacker)
	if won:
		var granary_loot := 0.0 if border_only else minf(float(odds["granary_loot"]), defender.energy_reserves)
		defender.energy_reserves = maxf(0.0, defender.energy_reserves - granary_loot)
		var field_res := _pillage_field(attacker, defender, state, surprise, p_win)
		var field_hex := str(field_res["hex_id"])
		var scorched := bool(field_res["scorched"])
		if border_only and field_hex != "":
			target_hex = field_hex
		loot = granary_loot + float(field_res["plunder"])
		attacker.energy_reserves += loot
		var field_note_att := ""
		var field_note_def := ""
		if field_hex != "":
			if scorched:
				field_note_att = ", scorching crops at %s" % field_hex
				field_note_def = " and burned your crops at %s (3 turns ruined)" % field_hex
			else:
				field_note_att = " (their %s saved crops at %s from burning)" % [_posture_phrase(defender.defense_posture), field_hex]
				field_note_def = " (your %s saved crops at %s from burning)" % [_posture_phrase(defender.defense_posture), field_hex]
		if not from_tribute_refusal:
			attacker.last_outcome = "You %s %s and won: +%d food, lost %d, they lost %d%s." % [verb, defender.name, int(loot), a_loss, d_loss, field_note_att]
		EvoRelations.remember(attacker, state, "You %s %s (+%d food, -%d pop%s)%s." % [verb, defender.name, int(loot), a_loss, field_note_att, ptag])
		EvoRelations.remember(defender, state, "%s %s you: -%d food, -%d people%s." % [attacker.name, verb, int(loot), d_loss, field_note_def])
	else:
		if not from_tribute_refusal:
			attacker.last_outcome = "You %s %s but were repelled by their %s: lost %d people." % [verb, defender.name, _posture_phrase(defender.defense_posture), a_loss]
		EvoRelations.remember(attacker, state, "Your %s on %s was repelled by their %s (-%d pop)%s." % ["betrayal" if surprise else "raid", defender.name, _posture_phrase(defender.defense_posture), a_loss, ptag])
		EvoRelations.remember(defender, state, "Your %s repelled %s's %s (they lost %d)." % [_posture_phrase(defender.defense_posture), attacker.name, "betrayal" if surprise else "raid", a_loss])

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
	EvoTypes.push_event(state, event_type, attacker.hex_id, target_hex, attacker.id, defender.id, loot, a_loss + d_loss)
	if not won and not surprise:
		return
	var params := {"raider": attacker.name, "betrayer": attacker.name, "victim": defender.name, "loot": str(int(loot)), "hex": target_hex}
	EvoSettlementPhase.chronicle(state, "chronicle-%s-%d-%s-%s" % [event_type, state.generation, attacker.id, defender.id], event_type, lang,
		"chronicle_" + event_type, params, target_hex, attacker)


static func _pillage_field(
	attacker: EvoTypes.Deme,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	surprise: bool,
	p_win: float
) -> Dictionary:
	var field := EvoPayoffs.closest_defender_field(attacker, defender, state)
	if field == null:
		return {"plunder": 0.0, "scorched": false, "hex_id": ""}
	var plunder := minf(field.current_resources, EvoPayoffs.field_plunder_amount(field, defender, surprise))
	field.current_resources = maxf(0.0, field.current_resources - plunder)
	var scorched := (
		defender.defense_posture == "open_harvest"
		or surprise
		or (defender.defense_posture == "patrol_fields" and p_win >= 0.72)
	)
	if scorched:
		field.owner_deme_id = ""
		field.land_use = "wild"
		field.ruin_turns = 3
		field.has_ruins = true
		EvoTypes.push_event(state, "pillage", attacker.hex_id, field.id, attacker.id, defender.id, plunder, 0)
	return {"plunder": plunder, "scorched": scorched, "hex_id": field.id}


static func _conquer(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, rel: EvoTypes.Relation, state: EvoTypes.WorldState, lang: String) -> void:
	var odds := EvoPayoffs.conquest_odds(attacker, defender, state)
	var troops := int(odds["troops"])
	var provoked := rel.feud_turns > 0
	var origin_hex := EvoSettlementPhase.closest_urban_hex_to(attacker, defender, state)
	var target_cell := EvoSettlementPhase.closest_defender_urban_cell(attacker, defender, state)
	var target_hex := target_cell.id
	var params := {"attacker": attacker.name, "defender": defender.name, "hex": target_hex}
	var ptag := EvoRelations.posture_tag(attacker)
	EvoRelations.start_feud(rel, EvoPayoffs.FEUD_AFTER_WAR)
	EvoRelations.record(state, attacker, defender, -0.7, "%s attacked %s to conquer it" % [attacker.name, defender.name])
	EvoRelations.adjust_reputation(attacker, 0.0 if provoked else -0.15)
	_warn_allies(attacker, defender, state)
	attacker.population -= troops

	if state.rng.randf() < float(odds["p_win"]):
		var a_loss := int(odds["attacker_loss_win"])
		var d_loss := mini(defender.population, int(odds["defender_loss_win"]))
		defender.population -= d_loss
		var rations := roundf(minf(attacker.energy_reserves * 0.25, float(troops) * 1.2))
		attacker.energy_reserves = maxf(0.0, attacker.energy_reserves - rations)
		var loot := roundf(defender.energy_reserves * 0.5)
		defender.energy_reserves -= loot
		var captured_tier := maxi(0, defender.defense_tier - 1)
		var warband := EvoSettlementPhase.occupy_conquered_hex(attacker, defender, troops - a_loss, rations + loot, captured_tier, state)
		if defender.population >= EvoPayoffs.MIN_VIABLE_POP:
			EvoRelations.start_feud(EvoTypes.get_relation(state, warband.id, defender.id), EvoPayoffs.FEUD_AFTER_WAR)
		attacker.last_outcome = "You conquered %s's hex %s: %d warriors now hold it with %d food." % [defender.name, target_hex, warband.population, int(warband.energy_reserves)]
		EvoRelations.remember(attacker, state, "You conquered %s's hex %s (%d warriors, %d rations+loot)%s." % [defender.name, target_hex, warband.population, int(warband.energy_reserves), ptag])
		EvoRelations.remember(warband, state, "Your warriors took hex %s from %s." % [target_hex, defender.name])
		EvoRelations.remember(defender, state, "%s conquered your district %s; %d of your people died." % [attacker.name, target_hex, d_loss])
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
	EvoRelations.remember(attacker, state, "Your invasion of %s failed (-%d warriors)%s." % [defender.name, lost, ptag])
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
