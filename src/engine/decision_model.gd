class_name EvoDecisionModel
extends RefCounted

const DEFAULT_OLLAMA_HOST: String = EvoOllamaClient.DEFAULT_OLLAMA_HOST
const DEFAULT_OLLAMA_PORT: int = EvoOllamaClient.DEFAULT_OLLAMA_PORT
const DEFAULT_SYSTEM_ONE_MODEL: String = EvoHeuristicScorer.DEFAULT_SYSTEM_ONE_MODEL
const SECONDARY_SYSTEM_ONE_MODEL: String = EvoHeuristicScorer.SECONDARY_SYSTEM_ONE_MODEL


static func resolve_deme_decision_model_tag(
	deme_id: String,
	primary_tag: String = "",
	secondary_tag: String = ""
) -> String:
	return EvoHeuristicScorer.resolve_deme_decision_model_tag(deme_id, primary_tag, secondary_tag)


static func reassign_world_models(state: EvoTypes.WorldState) -> void:
	if state == null:
		return
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)


static func check_ollama_status(force_refresh: bool = false) -> Dictionary:
	return EvoOllamaClient.check_ollama_status(force_refresh)


static func refresh_ollama_status_async() -> void:
	EvoOllamaClient.refresh_ollama_status_async()


static func is_decision_eligible(deme: EvoTypes.Deme, dec: EvoTypes.DecisionDef, traits_catalog: Dictionary = {}) -> bool:
	return EvoHeuristicScorer.is_decision_eligible(deme, dec, traits_catalog)


static func get_eligible_decisions(
	deme: EvoTypes.Deme,
	decisions_catalog: Dictionary,
	traits_catalog: Dictionary = {},
	state: EvoTypes.WorldState = null
) -> Array[EvoTypes.DecisionDef]:
	return EvoHeuristicScorer.get_eligible_decisions(deme, decisions_catalog, traits_catalog, state)


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


static func build_contextual_justification(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	dominant_id: String,
	dominant_prob: float,
	lang: String,
	confidence: float = 0.85
) -> String:
	return EvoHeuristicScorer.build_contextual_justification(
		deme,
		cell,
		state,
		dominant_id,
		dominant_prob,
		lang,
		confidence
	)


static func evaluate_deme(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String = "es"
) -> Dictionary:
	if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2"] and deme.decision_model_tag == EvoUserSettings.primary_model):
		deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)

	if not state.cells.has(deme.hex_id):
		return {
			"probabilities": deme.last_decision_probabilities,
			"dominant_decision_id": deme.last_dominant_decision_id,
			"confidence": deme.last_confidence,
			"justification": deme.last_justification
		}

	var sig := compute_deme_evaluation_signature(deme, state)
	deme.set_meta("eval_sig", sig)
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
			lang,
			confidence
		)
		deme.last_confidence = confidence
		return {
			"probabilities": probs.duplicate(),
			"dominant_decision_id": dominant_id,
			"confidence": confidence,
			"justification": justification
		}

	return {
		"probabilities": deme.last_decision_probabilities,
		"dominant_decision_id": deme.last_dominant_decision_id,
		"confidence": deme.last_confidence,
		"justification": deme.last_justification
	}


static func evaluate_all_demes(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var buckets: Dictionary = {}
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2"] and deme.decision_model_tag == EvoUserSettings.primary_model):
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
		if not live_results.has(sig):
			continue
		var bucket: Dictionary = buckets[sig]
		var group: Array = bucket["demes"]
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
					lang,
					confidence
				)


static func prefetch_for_state(state: EvoTypes.WorldState) -> void:
	if state == null or state.demes.is_empty():
		return
	var reps_by_sig: Dictionary = {}
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2"] and deme.decision_model_tag == EvoUserSettings.primary_model):
			deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)
		var sig := compute_deme_evaluation_signature(deme, state)
		deme.set_meta("eval_sig", sig)
		if not reps_by_sig.has(sig):
			reps_by_sig[sig] = deme

	EvoOllamaClient.prefetch_for_reps(reps_by_sig, state)


static func apply_completed_live_results(state: EvoTypes.WorldState, lang: String, last_seen_rev: int) -> Dictionary:
	var popped := EvoOllamaClient.pop_newly_completed(
		last_seen_rev,
		state != null
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
