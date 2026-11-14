class_name EvoDiplomacyPhase
extends RefCounted

## Resolves peaceful interactions chosen this turn: aid, pacts, tribute and unions.


static func has_border_crop_contact(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> bool:
	for nid in EvoTypes.urban_perimeter_hex_ids(a, state):
		if (state.cells[nid] as EvoTypes.HexCell).owner_deme_id == b.id:
			return true
	for nid in EvoTypes.urban_perimeter_hex_ids(b, state):
		if (state.cells[nid] as EvoTypes.HexCell).owner_deme_id == a.id:
			return true
	return false


static func adjacent_target(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	var target_id := str(deme.chosen_action["target"])
	if not state.demes.has(target_id):
		return null
	var other: EvoTypes.Deme = state.demes[target_id]
	return other if EvoPayoffs.min_urban_distance(deme, other, state) == 1 else null


static func tribute_or_raid_target(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	var target_id := str(deme.chosen_action["target"])
	if not state.demes.has(target_id):
		return null
	var other: EvoTypes.Deme = state.demes[target_id]
	if EvoPayoffs.min_urban_distance(deme, other, state) == 1 or has_border_crop_contact(deme, other, state):
		return other
	return null


static func resolve(state: EvoTypes.WorldState, lang: String, income_by_deme: Dictionary = {}) -> void:
	for did in state.demes.keys():
		if not state.demes.has(did):
			continue
		var deme: EvoTypes.Deme = state.demes[did]
		var action_type := str(deme.chosen_action["type"])
		if action_type not in ["aid", "offer_pact", "accept_pact", "demand_tribute", "pay_tribute", "unite", "accept_union"]:
			continue
		var other := tribute_or_raid_target(deme, state) if action_type in ["demand_tribute", "pay_tribute"] else adjacent_target(deme, state)
		if other == null:
			deme.last_outcome = "Your %s could not happen: the target is no longer in contact." % action_type.replace("_", " ")
			continue
		match action_type:
			"aid":
				_aid(deme, other, state, lang)
			"offer_pact":
				_offer(deme, other, state, "pact", lang, income_by_deme)
			"accept_pact":
				if EvoRelations.has_open_proposal(state, other.id, deme.id, "pact"):
					_form_pact(deme, other, state, lang)
			"demand_tribute":
				_demand_tribute(deme, other, state, lang)
			"pay_tribute":
				if EvoRelations.has_open_proposal(state, other.id, deme.id, "tribute"):
					_pay_tribute(deme, other, state, lang)
			"unite":
				_offer(deme, other, state, "union", lang, income_by_deme)
			"accept_union":
				if EvoRelations.has_open_proposal(state, other.id, deme.id, "union"):
					_accept_union(deme, other, state, lang, income_by_deme)
	_emit_pact_flows(state)


static func _aid(deme: EvoTypes.Deme, other: EvoTypes.Deme, state: EvoTypes.WorldState, lang: String) -> void:
	var amount := minf(EvoPayoffs.aid_amount(deme), deme.energy_reserves)
	deme.energy_reserves -= amount
	other.energy_reserves += amount
	var rel := EvoRelations.record(state, deme, other, 0.25, "%s gave %d food to %s" % [deme.name, int(amount), other.name])
	EvoRelations.adjust_reputation(deme, 0.05)
	deme.last_outcome = "You gave %d food to %s." % [int(amount), other.name]
	EvoRelations.remember(deme, state, "You gave %d food in aid to %s%s." % [int(amount), other.name, EvoRelations.posture_tag(deme)])
	EvoRelations.remember(other, state, "%s gave you %d food." % [deme.name, int(amount)])
	EvoSettlementPhase.push_flow(state, deme, other, "cooperate", 0.6)
	EvoTypes.push_event(state, "aid", deme.hex_id, other.hex_id, deme.id, other.id, amount, 0)
	if rel.proposal_from == other.id and rel.proposal_kind == "pact":
		_form_pact(deme, other, state, lang)


static func _offer(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	kind: String,
	lang: String,
	income_by_deme: Dictionary
) -> void:
	var rel := EvoTypes.get_relation(state, deme.id, other.id)
	if rel.feud_turns > 0:
		deme.last_outcome = "%s refuses to talk while the feud lasts." % other.name
		return
	if rel.proposal_from != "" and rel.proposal_kind == "tribute":
		deme.last_outcome = "Cannot propose %s while a tribute ultimatum is pending." % kind
		return
	var mutual := rel.proposal_from == other.id and rel.proposal_kind == kind
	if mutual and kind == "pact":
		_form_pact(deme, other, state, lang)
		return
	if mutual and kind == "union":
		_accept_union(deme, other, state, lang, income_by_deme)
		return
	if kind == "pact" and (other.lineage_id == deme.lineage_id or rel.trust >= 0.30):
		_form_pact(deme, other, state, lang)
		return
	var label := "an alliance" if kind == "pact" else "a union"
	EvoRelations.record(state, deme, other, 0.10, "%s proposed %s to %s" % [deme.name, kind, other.name])
	EvoRelations.propose(state, deme, other, kind, 0.0)
	deme.last_outcome = "You proposed %s to %s; they will answer next turn." % [label, other.name]
	EvoRelations.remember(deme, state, "You proposed %s to %s%s." % [label, other.name, EvoRelations.posture_tag(deme)])
	var ev_type := "offer_union" if kind == "union" else "offer_pact"
	EvoTypes.push_event(state, ev_type, deme.hex_id, other.hex_id, deme.id, other.id, 0.0, 0)
	var params := {"deme_a": deme.name, "deme_b": other.name, "hex_a": deme.hex_id, "hex_b": other.hex_id}
	EvoSettlementPhase.chronicle(state, "chronicle-%s-%d-%s-%s" % [ev_type, state.generation, deme.id, other.id], "diplomacy", lang, "chronicle_" + ev_type, params, deme.hex_id, deme)


static func _form_pact(deme: EvoTypes.Deme, other: EvoTypes.Deme, state: EvoTypes.WorldState, lang: String) -> void:
	var rel := EvoRelations.record(state, deme, other, 0.2, "%s and %s sealed an alliance" % [deme.name, other.name])
	rel.pact_turns = maxi(1, rel.pact_turns)
	EvoRelations.clear_proposal(rel)
	deme.last_outcome = "You are now allied with %s." % other.name
	EvoRelations.remember(deme, state, "You sealed an alliance with %s%s." % [other.name, EvoRelations.posture_tag(deme)])
	EvoRelations.remember(other, state, "%s sealed an alliance with you." % deme.name)
	EvoTypes.push_event(state, "pact", deme.hex_id, other.hex_id, deme.id, other.id, 1.0, 0)
	var params := {"deme_a": deme.name, "deme_b": other.name, "hex": "%s <-> %s" % [deme.hex_id, other.hex_id]}
	EvoSettlementPhase.chronicle(state, "chronicle-pact-%d-%s" % [state.generation, EvoTypes.make_pair_key(deme.id, other.id)], "pact", lang, "chronicle_pact", params, deme.hex_id, deme)


static func _demand_tribute(deme: EvoTypes.Deme, other: EvoTypes.Deme, state: EvoTypes.WorldState, lang: String) -> void:
	var rel := EvoTypes.get_relation(state, deme.id, other.id)
	if rel.pact_turns > 0 or rel.truce_turns > 0 or rel.proposal_from != "":
		deme.last_outcome = "You cannot demand tribute from %s now." % other.name
		return
	var amount := EvoPayoffs.tribute_amount(other)
	EvoRelations.propose(state, deme, other, "tribute", amount)
	deme.last_outcome = "You demanded %d food from %s; they answer next turn." % [int(amount), other.name]
	EvoRelations.remember(deme, state, "You demanded %d food tribute from %s%s." % [int(amount), other.name, EvoRelations.posture_tag(deme)])
	EvoRelations.remember(other, state, "%s demanded %d food tribute from you." % [deme.name, int(amount)])
	EvoTypes.push_event(state, "demand_tribute", deme.hex_id, other.hex_id, deme.id, other.id, amount, 0)
	var params := {"demander": deme.name, "target": other.name, "amount": str(int(amount)), "hex": other.hex_id}
	EvoSettlementPhase.chronicle(state, "chronicle-demand-tribute-%d-%s-%s" % [state.generation, deme.id, other.id], "diplomacy", lang, "chronicle_demand_tribute", params, other.hex_id, deme)


static func _pay_tribute(deme: EvoTypes.Deme, other: EvoTypes.Deme, state: EvoTypes.WorldState, lang: String) -> void:
	var rel := EvoRelations.record(state, deme, other, 0.05, "%s paid tribute to %s" % [deme.name, other.name])
	var amount := minf(rel.proposal_amount, deme.energy_reserves)
	deme.energy_reserves -= amount
	other.energy_reserves += amount
	rel.truce_turns = EvoPayoffs.TRUCE_AFTER_TRIBUTE
	EvoRelations.clear_proposal(rel)
	deme.last_outcome = "You paid %d food to %s for a %d-turn truce." % [int(amount), other.name, EvoPayoffs.TRUCE_AFTER_TRIBUTE]
	EvoRelations.remember(deme, state, "You paid %d food tribute to %s (%d-turn truce)%s." % [int(amount), other.name, EvoPayoffs.TRUCE_AFTER_TRIBUTE, EvoRelations.posture_tag(deme)])
	EvoRelations.remember(other, state, "%s paid you %d food in tribute." % [deme.name, int(amount)])
	EvoSettlementPhase.push_flow(state, deme, other, "tribute", 0.75)
	EvoTypes.push_event(state, "tribute", deme.hex_id, other.hex_id, deme.id, other.id, amount, 0)
	var params := {"raider": other.name, "victim": deme.name, "loot": str(int(amount)), "hex": deme.hex_id}
	EvoSettlementPhase.chronicle(state, "chronicle-tribute-%d-%s-%s" % [state.generation, deme.id, other.id], "tribute", lang, "chronicle_tribute", params, deme.hex_id, deme)


static func _accept_union(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String,
	income_by_deme: Dictionary
) -> void:
	EvoRelations.clear_proposal(EvoTypes.get_relation(state, deme.id, other.id))
	deme.last_outcome = "You united with %s." % other.name
	EvoRelations.remember(other, state, "%s accepted your union." % deme.name)
	EvoSettlementPhase.unite(deme, other, state, lang, income_by_deme)


static func _emit_pact_flows(state: EvoTypes.WorldState) -> void:
	for pk in state.relations.keys():
		var rel: EvoTypes.Relation = state.relations[pk]
		if rel.pact_turns <= 0:
			continue
		var ids := str(pk).split("__")
		if not state.demes.has(ids[0]) or not state.demes.has(ids[1]):
			continue
		var a: EvoTypes.Deme = state.demes[ids[0]]
		var b: EvoTypes.Deme = state.demes[ids[1]]
		if EvoPayoffs.min_urban_distance(a, b, state) == 1:
			EvoSettlementPhase.push_flow(state, a, b, "pact", 0.8)
