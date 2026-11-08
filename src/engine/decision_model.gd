class_name EvoDecisionModel
extends RefCounted


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


static func is_decision_eligible(
	deme: EvoTypes.Deme,
	dec: EvoTypes.DecisionDef,
	traits_catalog: Dictionary = {},
	state: EvoTypes.WorldState = null
) -> bool:
	return EvoHeuristicScorer.is_decision_eligible(deme, dec, traits_catalog, state)


static func blend_with_environmental_weights(
	model_probs: Dictionary,
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var env_weights: Dictionary = {}
	var eligible_ids: Array[String] = []
	if deme != null and cell != null and state != null:
		var w_key := EvoHeuristicScorer.build_env_weights_cache_key(deme, cell, state)
		if deme.has_meta("env_w_key") and str(deme.get_meta("env_w_key")) == w_key:
			env_weights = deme.get_meta("env_w_val") as Dictionary
		else:
			env_weights = EvoHeuristicScorer.compute_environmental_decision_weights(deme, cell, state)
			deme.set_meta("env_w_key", w_key)
			deme.set_meta("env_w_val", env_weights)
		for k in env_weights.keys():
			eligible_ids.append(str(k))
	else:
		eligible_ids = EvoHeuristicScorer.get_eligible_decision_ids(deme, state.decisions_catalog, state.traits_catalog, state)
		if not eligible_ids.is_empty():
			env_weights = EvoHeuristicScorer.compute_environmental_decision_weights(deme, cell, state)
	if eligible_ids.is_empty():
		return {"probabilities": model_probs.duplicate(), "dominant_decision_id": EvoHeuristicScorer.pick_dominant_decision(model_probs)}
	var norm_model: Dictionary = EvoHeuristicScorer.normalize_decision_probabilities(model_probs, eligible_ids)["probabilities"]
	var env_blend_ratio: float = 0.25
	var effective_env_ratio: float = clampf(env_blend_ratio, 0.45, 0.65) if float(env_weights.get("dec-territorial-dispute", 0.0)) >= 0.30 else env_blend_ratio
	var model_ratio: float = 1.0 - effective_env_ratio
	var blended: Dictionary = {}
	for dec_id in eligible_ids:
		var m_prob := float(norm_model.get(dec_id, 0.0))
		var e_weight := float(env_weights.get(dec_id, 0.0))
		blended[dec_id] = model_ratio * m_prob + effective_env_ratio * e_weight
	return EvoHeuristicScorer.normalize_decision_probabilities(blended, eligible_ids)


static func normalize_decision_probabilities(
	raw_scores: Dictionary,
	eligible_ids: Array[String]
) -> Dictionary:
	return EvoHeuristicScorer.normalize_decision_probabilities(raw_scores, eligible_ids)


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


static func invalidate_state_caches(state: EvoTypes.WorldState) -> void:
	EvoHeuristicScorer.invalidate_state_caches(state)


static func evaluate_deme(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String = "es"
) -> Dictionary:
	if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2", "deme-darwin-rival"] and deme.decision_model_tag == EvoUserSettings.primary_model):
		deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)

	if not state.cells.has(deme.hex_id):
		return {
			"probabilities": deme.last_decision_probabilities,
			"dominant_decision_id": deme.last_dominant_decision_id,
			"confidence": deme.last_confidence,
			"justification": deme.last_justification
		}

	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	EvoHeuristicScorer.modulate_deme_probabilities_for_turn(deme, cell, state)
	var fallback_dom_prob := float(deme.last_decision_probabilities.get(deme.last_dominant_decision_id, 0.5))
	if deme.last_justification == "":
		deme.last_justification = build_contextual_justification(
			deme,
			cell,
			state,
			deme.last_dominant_decision_id,
			fallback_dom_prob,
			lang,
			deme.last_confidence
		)

	var sig := compute_deme_evaluation_signature(deme, state)
	deme.set_meta("eval_sig", sig)
	var cached_entry := EvoOllamaClient.lookup_or_enqueue_single_deme(sig, deme, state)
	if not cached_entry.is_empty():
		var blended := blend_with_environmental_weights(cached_entry["probabilities"], deme, cell, state)
		var probs: Dictionary = blended["probabilities"]
		var dominant_id: String = str(blended["dominant_decision_id"])
		var confidence: float = float(cached_entry["confidence"])
		var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
		var justification := build_contextual_justification(
			deme,
			cell,
			state,
			dominant_id,
			dominant_prob,
			lang,
			confidence
		)
		deme.last_decision_probabilities = probs.duplicate()
		deme.last_dominant_decision_id = dominant_id
		deme.last_confidence = confidence
		deme.last_justification = justification
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


static func evaluate_all_demes(
	state: EvoTypes.WorldState,
	lang: String = "es",
	enqueue_missing: bool = true
) -> void:
	var need_sigs := EvoOllamaClient.has_cached_or_can_enqueue(enqueue_missing)
	var buckets: Dictionary = {}
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2", "deme-darwin-rival"] and deme.decision_model_tag == EvoUserSettings.primary_model):
			deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)
		if state.cells.has(deme.hex_id):
			var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
			EvoHeuristicScorer.modulate_deme_probabilities_for_turn(deme, cell, state)
			var dom_p := float(deme.last_decision_probabilities.get(deme.last_dominant_decision_id, 0.5))
			var just_key := "%s|%s|%.2f" % [lang, deme.last_dominant_decision_id, dom_p]
			if deme.last_justification == "" or not deme.has_meta("just_key") or str(deme.get_meta("just_key")) != just_key:
				deme.set_meta("just_key", just_key)
				deme.last_justification = build_contextual_justification(
					deme,
					cell,
					state,
					deme.last_dominant_decision_id,
					dom_p,
					lang,
					deme.last_confidence
				)
		if need_sigs:
			var sig := compute_deme_evaluation_signature(deme, state)
			deme.set_meta("eval_sig", sig)
			if buckets.has(sig):
				(buckets[sig]["demes"] as Array).append(deme)
			else:
				buckets[sig] = {
					"representative": deme,
					"demes": [deme]
				}

	if not need_sigs:
		return
	var live_results := EvoOllamaClient.sync_and_enqueue_batch(buckets, state, enqueue_missing)

	for sig in buckets.keys():
		if not live_results.has(sig):
			continue
		var bucket: Dictionary = buckets[sig]
		var group: Array = bucket["demes"]
		var entry: Dictionary = live_results[sig]
		var confidence: float = float(entry["confidence"])
		for d in group:
			var deme: EvoTypes.Deme = d
			var cell: EvoTypes.HexCell = state.cells[deme.hex_id] if state.cells.has(deme.hex_id) else null
			var blended := blend_with_environmental_weights(entry["probabilities"], deme, cell, state)
			var probs: Dictionary = blended["probabilities"]
			var dominant_id: String = str(blended["dominant_decision_id"])
			var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
			deme.last_decision_probabilities = probs.duplicate()
			deme.last_dominant_decision_id = dominant_id
			deme.last_confidence = confidence
			if cell != null:
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
	if state == null or state.demes.is_empty() or not EvoOllamaClient.needs_prefetch():
		return
	var reps_by_sig: Dictionary = {}
	var saved_eval_sigs: Dictionary = {}
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2", "deme-darwin-rival"] and deme.decision_model_tag == EvoUserSettings.primary_model):
			deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)
		var sig := compute_deme_evaluation_signature(deme, state)
		deme.set_meta("eval_sig", sig)
		saved_eval_sigs[deme_id] = sig
		if not reps_by_sig.has(sig):
			reps_by_sig[sig] = deme
			if reps_by_sig.size() >= 32:
				break

	EvoOllamaClient.prefetch_for_reps(reps_by_sig, state)
	if not EvoOllamaClient.needs_prefetch():
		return

	var climate_snapshot := EvoEnvPhase.project_next_turn_climate_in_place(state)

	var next_reps_by_sig: Dictionary = {}
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		var next_sig := compute_deme_evaluation_signature(deme, state)
		if not next_reps_by_sig.has(next_sig):
			next_reps_by_sig[next_sig] = deme
			if next_reps_by_sig.size() >= 32:
				break

	EvoOllamaClient.prefetch_for_reps(next_reps_by_sig, state)

	EvoEnvPhase.restore_projected_climate(state, climate_snapshot)
	for deme_id in saved_eval_sigs.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		deme.set_meta("eval_sig", saved_eval_sigs[deme_id])
		if deme.has_meta("sig_cache_key"):
			deme.remove_meta("sig_cache_key")
		if deme.has_meta("geo_ctx_key"):
			deme.remove_meta("geo_ctx_key")


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
			var cell: EvoTypes.HexCell = state.cells[deme.hex_id] if state.cells.has(deme.hex_id) else null
			var blended := blend_with_environmental_weights(entry["probabilities"], deme, cell, state)
			var probs: Dictionary = blended["probabilities"]
			var dominant_id: String = str(blended["dominant_decision_id"])
			var confidence: float = float(entry["confidence"])
			var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
			if deme.last_dominant_decision_id != dominant_id:
				any_dom_changed = true
			deme.last_decision_probabilities = probs.duplicate()
			deme.last_dominant_decision_id = dominant_id
			deme.last_confidence = confidence
			if cell != null:
				deme.last_justification = build_contextual_justification(
					deme,
					cell,
					state,
					dominant_id,
					dominant_prob,
					lang,
					confidence
				)
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
