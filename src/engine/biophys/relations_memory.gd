class_name EvoRelations
extends RefCounted

## Bilateral trust, feuds, truces, proposals, public reputation and per-settlement memory.

const MEMORY_LENGTH := 8


static func remember(deme: EvoTypes.Deme, state: EvoTypes.WorldState, text: String) -> void:
	deme.memory.push_front("T%d: %s" % [state.generation, text])
	if deme.memory.size() > MEMORY_LENGTH:
		deme.memory.resize(MEMORY_LENGTH)


static func record(state: EvoTypes.WorldState, a: EvoTypes.Deme, b: EvoTypes.Deme, trust_delta: float, event_text: String) -> EvoTypes.Relation:
	var rel := EvoTypes.get_relation(state, a.id, b.id)
	rel.trust = clampf(rel.trust + trust_delta, -1.0, 1.0)
	rel.last_event = "T%d %s" % [state.generation, event_text]
	return rel


static func start_feud(rel: EvoTypes.Relation, turns: int) -> void:
	rel.feud_turns = maxi(rel.feud_turns, turns)
	rel.pact_turns = 0
	rel.truce_turns = 0
	rel.proposal_from = ""
	rel.proposal_kind = ""


static func adjust_reputation(deme: EvoTypes.Deme, delta: float) -> void:
	deme.reputation = clampf(deme.reputation + delta, -1.0, 1.0)


static func propose(state: EvoTypes.WorldState, from: EvoTypes.Deme, to: EvoTypes.Deme, kind: String, amount: float) -> void:
	var rel := EvoTypes.get_relation(state, from.id, to.id)
	rel.proposal_from = from.id
	rel.proposal_kind = kind
	rel.proposal_amount = amount
	rel.proposal_gen = state.generation


## A proposal that `responder` may answer this turn.
static func has_open_proposal(state: EvoTypes.WorldState, proposer_id: String, responder_id: String, kind: String) -> bool:
	var key := EvoTypes.make_pair_key(proposer_id, responder_id)
	if not state.relations.has(key):
		return false
	var rel: EvoTypes.Relation = state.relations[key]
	return rel.proposal_from == proposer_id and rel.proposal_kind == kind


static func clear_proposal(rel: EvoTypes.Relation) -> void:
	rel.proposal_from = ""
	rel.proposal_kind = ""
	rel.proposal_amount = 0.0
	rel.proposal_gen = -1


## End-of-turn bookkeeping: timers advance and unanswered proposals expire.
static func tick(state: EvoTypes.WorldState) -> void:
	for pk in state.relations.keys():
		var rel: EvoTypes.Relation = state.relations[pk]
		if rel.pact_turns > 0:
			rel.pact_turns += 1
		rel.feud_turns = maxi(0, rel.feud_turns - 1)
		rel.truce_turns = maxi(0, rel.truce_turns - 1)
		if rel.proposal_from != "" and rel.proposal_gen < state.generation:
			if rel.proposal_kind == "tribute":
				_refuse_tribute(state, str(pk), rel)
			clear_proposal(rel)

	var friendly_pairs: Dictionary = {}
	for fl in state.active_flows:
		if fl.flow_type in ["exchange", "cooperate", "pact"]:
			friendly_pairs[EvoTypes.make_pair_key(fl.from_deme_id, fl.to_deme_id)] = true
	var updated_disused: Array[Dictionary] = []
	for conn in state.disused_connections:
		var pk := EvoTypes.make_pair_key(str(conn["from_deme_id"]), str(conn["to_deme_id"]))
		if friendly_pairs.has(pk):
			continue
		if int(conn["age"]) == 0:
			conn["age"] = 1
		updated_disused.append(conn)
	state.disused_connections = updated_disused


static func _refuse_tribute(state: EvoTypes.WorldState, pair_key: String, rel: EvoTypes.Relation) -> void:
	var demander_id := rel.proposal_from
	var target_id := EvoTypes.pair_partner(pair_key, demander_id)
	if not state.demes.has(demander_id) or not state.demes.has(target_id):
		return
	var demander: EvoTypes.Deme = state.demes[demander_id]
	var target: EvoTypes.Deme = state.demes[target_id]
	rel.feud_turns = maxi(rel.feud_turns, EvoPayoffs.FEUD_AFTER_REFUSED_TRIBUTE)
	rel.trust = clampf(rel.trust - 0.2, -1.0, 1.0)
	rel.last_event = "T%d %s refused to pay tribute to %s" % [state.generation, target.name, demander.name]
	remember(demander, state, "%s refused your tribute demand." % target.name)
	remember(target, state, "You refused %s's tribute demand." % demander.name)
	var ca: EvoTypes.HexCell = state.cells[demander.hex_id]
	var cb: EvoTypes.HexCell = state.cells[target.hex_id]
	if HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r) == 1 and target.defense_tier < 3:
		EvoConflictPhase._raid(demander, target, rel, state, "en", false)


static func trust_word(trust: float) -> String:
	if trust >= 0.5:
		return "high"
	if trust >= 0.15:
		return "good"
	if trust > -0.15:
		return "neutral"
	if trust > -0.5:
		return "low"
	return "hostile"


static func reputation_word(reputation: float) -> String:
	if reputation >= 0.3:
		return "generous and reliable"
	if reputation >= 0.1:
		return "reliable"
	if reputation > -0.15:
		return "unremarkable"
	if reputation > -0.4:
		return "aggressive"
	return "treacherous"
