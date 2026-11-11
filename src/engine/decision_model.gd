class_name EvoDecisionModel
extends RefCounted


static func resolve_model_for_slot(
	faction_slot: String,
	primary_tag: String = "",
	secondary_tag: String = ""
) -> String:
	var p_tag := primary_tag if primary_tag != "" else EvoUserSettings.primary_model
	var s_tag := secondary_tag if secondary_tag != "" else EvoUserSettings.secondary_model
	return s_tag if faction_slot == "B" else p_tag


static func reassign_world_models(state: EvoTypes.WorldState) -> void:
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		deme.decision_model_tag = resolve_model_for_slot(deme.faction_slot)


static func check_ollama_status(force_refresh: bool = false) -> Dictionary:
	return EvoOllamaClient.check_ollama_status(force_refresh)


static func evaluate_deme(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	enqueue_job: bool = false
) -> Dictionary:
	if deme.decision_model_tag == "":
		deme.decision_model_tag = resolve_model_for_slot(deme.faction_slot)
	if not state.cells.has(deme.hex_id):
		return {
			"chosen_action": deme.chosen_action,
			"probabilities": deme.action_probabilities,
			"forecasts": deme.action_forecasts,
			"defense_posture": deme.defense_posture,
			"posture_probabilities": deme.posture_probabilities,
			"posture_forecasts": deme.posture_forecasts,
			"confidence": deme.last_confidence
		}
	var job := EvoActionPolicy.prepare_deme_menu(deme, state)
	var ready := EvoOllamaClient.take_result(deme.id)
	if not ready.is_empty():
		EvoActionPolicy.apply_live_result(deme, ready)
	elif enqueue_job:
		EvoOllamaClient.enqueue_jobs([job])
	return {
		"chosen_action": deme.chosen_action,
		"probabilities": deme.action_probabilities,
		"forecasts": deme.action_forecasts,
		"defense_posture": deme.defense_posture,
		"posture_probabilities": deme.posture_probabilities,
		"posture_forecasts": deme.posture_forecasts,
		"confidence": deme.last_confidence
	}


static func evaluate_all_demes(
	state: EvoTypes.WorldState,
	_lang: String = "es",
	enqueue_jobs: bool = true
) -> void:
	if enqueue_jobs:
		EvoOllamaClient.clear_cache()
	var jobs: Array[Dictionary] = []
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		if deme.decision_model_tag == "":
			deme.decision_model_tag = resolve_model_for_slot(deme.faction_slot)
		if not state.cells.has(deme.hex_id):
			continue
		var job := EvoActionPolicy.prepare_deme_menu(deme, state)
		var ready := EvoOllamaClient.take_result(deme.id)
		if not ready.is_empty():
			EvoActionPolicy.apply_live_result(deme, ready)
		elif enqueue_jobs:
			jobs.append(job)
	if enqueue_jobs and not jobs.is_empty():
		EvoOllamaClient.enqueue_jobs(jobs)


static func apply_completed_live_results(state: EvoTypes.WorldState, _lang: String, last_seen_rev: int) -> Dictionary:
	var popped := EvoOllamaClient.pop_newly_completed(last_seen_rev)
	var current_rev := int(popped["revision"])
	var newly_completed: Dictionary = popped["newly_completed"]
	if newly_completed.is_empty():
		return {"updated": false, "dom_changed": false, "revision": current_rev}

	var any_updated := false
	var any_changed := false
	for deme_id in newly_completed.keys():
		if not state.demes.has(deme_id):
			continue
		var deme: EvoTypes.Deme = state.demes[deme_id]
		var prev_key := str(deme.chosen_action["key"])
		var prev_posture := deme.defense_posture
		var entry: Dictionary = newly_completed[deme_id]
		EvoActionPolicy.apply_live_result(deme, entry)
		if str(deme.chosen_action["key"]) != prev_key or deme.defense_posture != prev_posture:
			any_changed = true
		any_updated = true

	return {"updated": any_updated, "dom_changed": any_changed, "revision": current_rev}


static func finalize_turn_decisions(state: EvoTypes.WorldState) -> void:
	var ids := state.demes.keys()
	ids.sort()
	for did in ids:
		var deme: EvoTypes.Deme = state.demes[did]
		if not deme.pending_raw_eval.is_empty():
			EvoActionPolicy.sample_turn_decisions(deme, state.rng)
			deme.pending_raw_eval = {}


static func has_pending_jobs() -> bool:
	return EvoOllamaClient.has_pending_jobs()


static func wait_for_workers() -> void:
	EvoOllamaClient.wait_for_workers()


static func _slugify(text: String) -> String:
	return EvoMilestonePhase._slugify(text)


static func synthesize_milestone_trait(
	state: EvoTypes.WorldState,
	deme: EvoTypes.Deme,
	trigger_type: String,
	lang: String = "es"
) -> EvoTypes.TraitDef:
	return EvoMilestonePhase.synthesize_milestone_trait(state, deme, trigger_type, lang)

