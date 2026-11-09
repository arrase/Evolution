extends SceneTree

const MATCHUPS: Array[Dictionary] = [
	{"preset": "preset-rift-savanna", "strat_a": "strat-cooperation", "strat_b": "strat-war"},
	{"preset": "preset-finite-island", "strat_a": "strat-trade", "strat_b": "strat-expansion"},
	{"preset": "preset-darwin-archipelago", "strat_a": "strat-innovation", "strat_b": "strat-war"},
	{"preset": "preset-finite-island", "strat_a": "strat-cooperation", "strat_b": "strat-expansion"}
]


func _init() -> void:
	var gens_env := OS.get_environment("SIM_GENS")
	var max_gens := int(gens_env) if gens_env != "" else 30
	var status := EvoOllamaClient._probe_ollama_status_sync()
	print("=== EVOLUTION LIVE OLLAMA EMERGENCE HARNESS (%d GENS x %d MATCHUPS) ===" % [max_gens, MATCHUPS.size()])
	print("Ollama status: connected=%s | primary=%s (%s) | secondary=%s (%s) | ctx=%d" % [
		str(status["connected"]),
		str(status["primary_tag"]),
		str(status["primary_ready"]),
		str(status["secondary_tag"]),
		str(status["secondary_ready"]),
		EvoUserSettings.context_length
	])
	if not bool(status["connected"]):
		printerr("ERROR: Ollama is offline. Cannot run live emergence simulation.")
		quit(1)
		return

	var global_actions: Dictionary = {}
	var global_chronicle: Dictionary = {}
	var global_turn_events: Dictionary = {}
	var actions_by_strat: Dictionary = {}

	for idx in range(MATCHUPS.size()):
		var m: Dictionary = MATCHUPS[idx]
		var preset_id := str(m["preset"])
		var strat_a := str(m["strat_a"])
		var strat_b := str(m["strat_b"])
		print("\n--------------------------------------------------------------------------------")
		print("Matchup %d/%d: %s | %s (A) vs %s (B)" % [idx + 1, MATCHUPS.size(), preset_id, strat_a, strat_b])
		var t0 := Time.get_ticks_msec()
		var state := EvoPresets.create_preset_world(preset_id, "en", strat_a, strat_b)
		state.rng_seed = 1337 + idx * 101
		state.rng.seed = state.rng_seed
		var m_actions: Dictionary = {}
		var m_turn_events: Dictionary = {}

		for _g in range(max_gens):
			while EvoDecisionModel.has_pending_jobs():
				OS.delay_msec(10)
			EvoDecisionModel.apply_completed_live_results(state, "en", -1)
			for did in state.demes.keys():
				var d: EvoTypes.Deme = state.demes[did]
				var act_type := str(d.chosen_action["type"])
				m_actions[act_type] = int(m_actions.get(act_type, 0)) + 1
				global_actions[act_type] = int(global_actions.get(act_type, 0)) + 1
				if not actions_by_strat.has(d.strategy_id):
					actions_by_strat[d.strategy_id] = {}
				var s_map: Dictionary = actions_by_strat[d.strategy_id]
				s_map[act_type] = int(s_map.get(act_type, 0)) + 1

			EvoTurnEngine.advance_generation(state, "en")
			for ev in state.turn_events:
				var et := str(ev["type"])
				m_turn_events[et] = int(m_turn_events.get(et, 0)) + 1
				global_turn_events[et] = int(global_turn_events.get(et, 0)) + 1

		EvoDecisionModel.wait_for_workers()
		var elapsed_s := float(Time.get_ticks_msec() - t0) / 1000.0

		var m_chronicle: Dictionary = {}
		for entry in state.chronicle:
			m_chronicle[entry.event_type] = int(m_chronicle.get(entry.event_type, 0)) + 1
			global_chronicle[entry.event_type] = int(global_chronicle.get(entry.event_type, 0)) + 1

		var pop_a := 0
		var pop_b := 0
		var demes_a := 0
		var demes_b := 0
		var max_tier_a := 0
		var max_tier_b := 0
		for did in state.demes.keys():
			var d: EvoTypes.Deme = state.demes[did]
			if d.strategy_id == strat_a:
				pop_a += d.population
				demes_a += 1
				max_tier_a = maxi(max_tier_a, d.get_village_tier())
			else:
				pop_b += d.population
				demes_b += 1
				max_tier_b = maxi(max_tier_b, d.get_village_tier())

		var active_pacts := 0
		var active_feuds := 0
		for pk in state.relations.keys():
			var rel: EvoTypes.Relation = state.relations[pk]
			if rel.pact_turns > 0:
				active_pacts += 1
			if rel.feud_turns > 0:
				active_feuds += 1

		print("Completed in %.1fs | Final A (%s): %d settlements, %d pop, max tier %d | Final B (%s): %d settlements, %d pop, max tier %d | Active pacts=%d, feuds=%d" % [
			elapsed_s, strat_a, demes_a, pop_a, max_tier_a, strat_b, demes_b, pop_b, max_tier_b, active_pacts, active_feuds
		])
		print("  Actions chosen: %s" % JSON.stringify(m_actions))
		print("  Turn events:    %s" % JSON.stringify(m_turn_events))
		print("  Chronicle logs: %s" % JSON.stringify(m_chronicle))

	print("\n================================================================================")
	print("=== AGGREGATE EMERGENCE SUMMARY ===")
	print("Global Actions Chosen: %s" % JSON.stringify(global_actions))
	print("Global Turn Events:    %s" % JSON.stringify(global_turn_events))
	print("Global Chronicle Logs: %s" % JSON.stringify(global_chronicle))
	print("Actions by Strategy:")
	for sid in actions_by_strat.keys():
		print("  %s: %s" % [sid, JSON.stringify(actions_by_strat[sid])])
	quit(0)
