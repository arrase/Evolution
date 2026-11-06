class_name EvoDecisionModel
extends RefCounted

const DEFAULT_OLLAMA_HOST: String = EvoOllamaClient.DEFAULT_OLLAMA_HOST
const DEFAULT_OLLAMA_PORT: int = EvoOllamaClient.DEFAULT_OLLAMA_PORT
const DEFAULT_SYSTEM_ONE_MODEL: String = EvoHeuristicScorer.DEFAULT_SYSTEM_ONE_MODEL
const SECONDARY_SYSTEM_ONE_MODEL: String = EvoHeuristicScorer.SECONDARY_SYSTEM_ONE_MODEL


static func resolve_deme_decision_model_tag(
	deme_id: String,
	primary_tag: String = DEFAULT_SYSTEM_ONE_MODEL,
	secondary_tag: String = SECONDARY_SYSTEM_ONE_MODEL
) -> String:
	return EvoHeuristicScorer.resolve_deme_decision_model_tag(deme_id, primary_tag, secondary_tag)


static func check_ollama_status(force_refresh: bool = false) -> Dictionary:
	return EvoOllamaClient.check_ollama_status(force_refresh)


static func is_decision_eligible(deme: EvoTypes.Deme, dec: EvoTypes.DecisionDef) -> bool:
	return EvoHeuristicScorer.is_decision_eligible(deme, dec)


static func get_eligible_decisions(deme: EvoTypes.Deme, decisions_catalog: Dictionary) -> Array[EvoTypes.DecisionDef]:
	return EvoHeuristicScorer.get_eligible_decisions(deme, decisions_catalog)


static func normalize_decision_probabilities(
	raw_scores: Dictionary,
	eligible_ids: Array[String]
) -> Dictionary:
	return EvoHeuristicScorer.normalize_decision_probabilities(raw_scores, eligible_ids)


static func compute_baseline_mobility(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return EvoHeuristicScorer.compute_baseline_mobility(deme, state)


static func build_compact_system_one_state(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	return EvoHeuristicScorer.build_compact_system_one_state(deme, state)


static func build_compact_decision_criteria(eligible_decisions: Array[EvoTypes.DecisionDef]) -> Dictionary:
	return EvoHeuristicScorer.build_compact_decision_criteria(eligible_decisions)


static func compute_deme_evaluation_signature(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	return EvoHeuristicScorer.compute_deme_evaluation_signature(deme, state)


static func evaluate_deme_heuristic(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String = "es"
) -> Dictionary:
	return EvoHeuristicScorer.evaluate_deme_heuristic(deme, state, lang)


static func build_contextual_justification(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	dominant_id: String,
	dominant_prob: float,
	active_branch: String,
	lang: String,
	confidence: float = 0.85
) -> String:
	return EvoHeuristicScorer.build_contextual_justification(
		deme,
		cell,
		state,
		dominant_id,
		dominant_prob,
		active_branch,
		lang,
		confidence
	)


static func evaluate_deme(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String = "es"
) -> Dictionary:
	if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2"] and deme.decision_model_tag == DEFAULT_SYSTEM_ONE_MODEL):
		deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)

	if not state.cells.has(deme.hex_id):
		return {
			"probabilities": deme.last_decision_probabilities,
			"dominant_decision_id": deme.last_dominant_decision_id,
			"confidence": deme.last_confidence,
			"justification": deme.last_justification
		}

	if state.use_live_decision_models:
		var sig := compute_deme_evaluation_signature(deme, state)
		var cached_entry := EvoOllamaClient.lookup_or_enqueue_single_deme(sig, deme, state)
		if not cached_entry.is_empty():
			var probs: Dictionary = cached_entry["probabilities"]
			var dominant_id: String = str(cached_entry["dominant_decision_id"])
			var confidence: float = float(cached_entry["confidence"])
			var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
			var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
			var justification := build_contextual_justification(
				deme,
				cell,
				state,
				dominant_id,
				dominant_prob,
				"live_system_one",
				lang,
				confidence
			)
			deme.last_confidence = confidence
			return {
				"probabilities": probs,
				"dominant_decision_id": dominant_id,
				"confidence": confidence,
				"justification": justification
			}

	return evaluate_deme_heuristic(deme, state, lang)


static func evaluate_all_demes(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var buckets: Dictionary = {}
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2"] and deme.decision_model_tag == DEFAULT_SYSTEM_ONE_MODEL):
			deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)
		var sig := compute_deme_evaluation_signature(deme, state)
		deme.set_meta("eval_sig", sig)
		if buckets.has(sig):
			(buckets[sig]["demes"] as Array).append(deme)
		else:
			buckets[sig] = {
				"representative": deme,
				"demes": [deme]
			}

	var live_results := EvoOllamaClient.sync_and_enqueue_batch(buckets, state)

	for sig in buckets.keys():
		var bucket: Dictionary = buckets[sig]
		var group: Array = bucket["demes"]
		if live_results.has(sig):
			var entry: Dictionary = live_results[sig]
			var probs: Dictionary = entry["probabilities"]
			var dominant_id: String = str(entry["dominant_decision_id"])
			var confidence: float = float(entry["confidence"])
			var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
			for d in group:
				var deme: EvoTypes.Deme = d
				deme.last_decision_probabilities = probs.duplicate()
				deme.last_dominant_decision_id = dominant_id
				deme.last_confidence = confidence
				if state.cells.has(deme.hex_id):
					var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
					deme.last_justification = build_contextual_justification(
						deme,
						cell,
						state,
						dominant_id,
						dominant_prob,
						"live_system_one",
						lang,
						confidence
					)
		else:
			var rep: EvoTypes.Deme = bucket["representative"]
			var heur := evaluate_deme_heuristic(rep, state, lang)
			var probs: Dictionary = heur["probabilities"]
			var dominant_id: String = str(heur["dominant_decision_id"])
			var confidence: float = float(heur.get("confidence", 0.85))
			var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
			var active_branch: String = str(heur.get("active_branch", "stable_forest"))
			var rep_just: String = str(heur["justification"])
			for d in group:
				var deme: EvoTypes.Deme = d
				deme.last_decision_probabilities = probs.duplicate()
				deme.last_dominant_decision_id = dominant_id
				deme.last_confidence = confidence
				if deme.hex_id == rep.hex_id or not state.cells.has(deme.hex_id):
					deme.last_justification = rep_just
				else:
					deme.last_justification = build_contextual_justification(
						deme,
						state.cells[deme.hex_id],
						state,
						dominant_id,
						dominant_prob,
						active_branch,
						lang,
						confidence
					)


static func prefetch_for_state(state: EvoTypes.WorldState) -> void:
	if state == null or not state.use_live_decision_models or state.demes.is_empty():
		return
	var reps_by_sig: Dictionary = {}
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2"] and deme.decision_model_tag == DEFAULT_SYSTEM_ONE_MODEL):
			deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)
		var sig := compute_deme_evaluation_signature(deme, state)
		deme.set_meta("eval_sig", sig)
		if not reps_by_sig.has(sig):
			reps_by_sig[sig] = deme

	EvoOllamaClient.prefetch_for_reps(reps_by_sig, state)


static func apply_completed_live_results(state: EvoTypes.WorldState, lang: String, last_seen_rev: int) -> Dictionary:
	var popped := EvoOllamaClient.pop_newly_completed(
		last_seen_rev,
		state != null and state.use_live_decision_models
	)
	var current_rev: int = int(popped["revision"])
	var newly_completed: Dictionary = popped["newly_completed"]
	if newly_completed.is_empty() or state == null:
		return {"updated": false, "dom_changed": false, "revision": current_rev}

	var any_updated := false
	var any_dom_changed := false
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		var sig: String = str(deme.get_meta("eval_sig", "")) if deme.has_meta("eval_sig") else compute_deme_evaluation_signature(deme, state)
		if newly_completed.has(sig):
			var entry: Dictionary = newly_completed[sig]
			var probs: Dictionary = entry["probabilities"]
			var dominant_id: String = str(entry["dominant_decision_id"])
			var confidence: float = float(entry["confidence"])
			var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
			var dom_changed := deme.last_dominant_decision_id != dominant_id
			deme.last_decision_probabilities = probs.duplicate()
			deme.last_dominant_decision_id = dominant_id
			deme.last_confidence = confidence
			if state.cells.has(deme.hex_id):
				var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
				deme.last_justification = build_contextual_justification(
					deme,
					cell,
					state,
					dominant_id,
					dominant_prob,
					"live_system_one",
					lang,
					confidence
				)
			if dom_changed:
				any_dom_changed = true
			if dom_changed or deme.id != "":
				any_updated = true

	return {"updated": any_updated, "dom_changed": any_dom_changed, "revision": current_rev}


static func has_pending_jobs() -> bool:
	return EvoOllamaClient.has_pending_jobs()


static func wait_for_workers() -> void:
	EvoOllamaClient.wait_for_workers()


static func _slugify(text: String) -> String:
	return EvoHeuristicScorer._slugify(text)


static func synthesize_milestone_trait(
	state: EvoTypes.WorldState,
	deme: EvoTypes.Deme,
	trigger_type: String,
	lang: String = "es"
) -> EvoTypes.TraitDef:
	return EvoHeuristicScorer.synthesize_milestone_trait(state, deme, trigger_type, lang)
