extends SceneTree

const DEFAULT_MATCHUPS: Array[Dictionary] = [
	{"preset": "preset-rift-savanna", "strat_a": "strat-cooperation", "strat_b": "strat-war"},
	{"preset": "preset-finite-island", "strat_a": "strat-trade", "strat_b": "strat-expansion"},
	{"preset": "preset-darwin-archipelago", "strat_a": "strat-innovation", "strat_b": "strat-war"},
	{"preset": "preset-finite-island", "strat_a": "strat-cooperation", "strat_b": "strat-expansion"}
]


func _new_slot_telemetry(strat_id: String, model_tag: String) -> Dictionary:
	return {
		"strategy_id": strat_id,
		"model_tag": model_tag,
		"postures": {"open_harvest": 0, "patrol_fields": 0, "mobilized_garrison": 0},
		"actions": {}
	}


func _summarize_slot(state: EvoTypes.WorldState, slot: String, telem: Dictionary) -> Dictionary:
	var surviving := 0
	var total_pop := 0
	var total_reserves := 0.0
	var def_sum := 0
	var max_def := 0
	var multi_hex_cities := 0
	var deme_ids_in_slot: Dictionary = {}

	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		if d.faction_slot != slot:
			continue
		deme_ids_in_slot[d.id] = true
		surviving += 1
		total_pop += d.population
		total_reserves += d.energy_reserves
		def_sum += d.defense_tier
		max_def = maxi(max_def, d.defense_tier)
		if d.is_multi_hex():
			multi_hex_cities += 1

	var rural_hexes := 0
	for cid in state.cells.keys():
		var c: EvoTypes.HexCell = state.cells[cid]
		if c.owner_deme_id != "" and deme_ids_in_slot.has(c.owner_deme_id) and c.land_use in ["crops", "pasture"]:
			rural_hexes += 1

	var mean_def := float(def_sum) / float(surviving) if surviving > 0 else 0.0
	return {
		"slot": slot,
		"strategy_id": telem["strategy_id"],
		"model_tag": telem["model_tag"],
		"surviving_settlements": surviving,
		"total_population": total_pop,
		"total_reserves": snappedf(total_reserves, 0.1),
		"mean_defense_tier": snappedf(mean_def, 0.01),
		"max_defense_tier": max_def,
		"multi_hex_cities": multi_hex_cities,
		"owned_rural_hexes": rural_hexes,
		"posture_distribution": telem["postures"],
		"action_distribution": telem["actions"]
	}


func _init() -> void:
	var gens_env := OS.get_environment("SIM_GENS")
	var max_gens := int(gens_env) if gens_env != "" else 30
	var model_a_env := OS.get_environment("SIM_MODEL_A")
	var model_b_env := OS.get_environment("SIM_MODEL_B")
	if model_a_env != "":
		EvoUserSettings.primary_model = model_a_env
	if model_b_env != "":
		EvoUserSettings.secondary_model = model_b_env

	var preset_env := OS.get_environment("SIM_PRESET")
	var strat_a_env := OS.get_environment("SIM_STRAT_A")
	var strat_b_env := OS.get_environment("SIM_STRAT_B")
	var matchups: Array[Dictionary] = []
	if preset_env != "" or strat_a_env != "" or strat_b_env != "":
		matchups.append({
			"preset": preset_env if preset_env != "" else "preset-rift-savanna",
			"strat_a": strat_a_env if strat_a_env != "" else "strat-cooperation",
			"strat_b": strat_b_env if strat_b_env != "" else "strat-war"
		})
	else:
		matchups = DEFAULT_MATCHUPS.duplicate(true)

	var status := EvoOllamaClient._probe_ollama_status_sync()
	print("=== EVOLUTION LIVE OLLAMA EMERGENCE HARNESS (%d GENS x %d MATCHUPS) ===" % [max_gens, matchups.size()])
	print("Ollama status: connected=%s | Slot A=%s (%s) | Slot B=%s (%s)" % [
		str(status["connected"]),
		str(status["primary_tag"]),
		str(status["primary_ready"]),
		str(status["secondary_tag"]),
		str(status["secondary_ready"])
	])
	if not bool(status["connected"]):
		printerr("ERROR: Ollama is offline. Cannot run live emergence simulation.")
		quit(1)
		return

	var global_actions: Dictionary = {}
	var global_chronicle: Dictionary = {}
	var global_turn_events: Dictionary = {}
	var actions_by_strat: Dictionary = {}
	var postures_by_strat: Dictionary = {}

	for idx in range(matchups.size()):
		var m: Dictionary = matchups[idx]
		var preset_id := str(m["preset"])
		var strat_a := str(m["strat_a"])
		var strat_b := str(m["strat_b"])
		var model_a := EvoDecisionModel.resolve_model_for_slot("A")
		var model_b := EvoDecisionModel.resolve_model_for_slot("B")
		print("\n--------------------------------------------------------------------------------")
		print("Matchup %d/%d: %s | Slot A: %s [%s] vs Slot B: %s [%s]" % [
			idx + 1, matchups.size(), preset_id, strat_a, model_a, strat_b, model_b
		])
		var t0 := Time.get_ticks_msec()
		var state := EvoPresets.create_preset_world(preset_id, "en", strat_a, strat_b)
		state.rng_seed = 1337 + idx * 101
		state.rng.seed = state.rng_seed
		var slot_telem := {
			"A": _new_slot_telemetry(strat_a, model_a),
			"B": _new_slot_telemetry(strat_b, model_b)
		}
		var m_turn_events: Dictionary = {}

		for _g in range(max_gens):
			while EvoDecisionModel.has_pending_jobs():
				OS.delay_msec(10)
			EvoDecisionModel.apply_completed_live_results(state, "en", -1)
			EvoDecisionModel.finalize_turn_decisions(state)

			for did in state.demes.keys():
				var d: EvoTypes.Deme = state.demes[did]
				var slot_key := "B" if d.faction_slot == "B" else "A"
				var st: Dictionary = slot_telem[slot_key]
				var s_postures: Dictionary = st["postures"]
				var s_actions: Dictionary = st["actions"]
				var act_type := str(d.chosen_action["type"])
				s_postures[d.defense_posture] = int(s_postures[d.defense_posture]) + 1
				s_actions[act_type] = int(s_actions.get(act_type, 0)) + 1
				global_actions[act_type] = int(global_actions.get(act_type, 0)) + 1

				if not actions_by_strat.has(d.strategy_id):
					actions_by_strat[d.strategy_id] = {}
					postures_by_strat[d.strategy_id] = {"open_harvest": 0, "patrol_fields": 0, "mobilized_garrison": 0}
				var strat_acts: Dictionary = actions_by_strat[d.strategy_id]
				strat_acts[act_type] = int(strat_acts.get(act_type, 0)) + 1
				var strat_posts: Dictionary = postures_by_strat[d.strategy_id]
				strat_posts[d.defense_posture] = int(strat_posts[d.defense_posture]) + 1

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

		var active_ruins := 0
		for cid in state.cells.keys():
			if (state.cells[cid] as EvoTypes.HexCell).ruin_turns > 0:
				active_ruins += 1

		var active_pacts := 0
		var active_feuds := 0
		for pk in state.relations.keys():
			var rel: EvoTypes.Relation = state.relations[pk]
			if rel.pact_turns > 0:
				active_pacts += 1
			if rel.feud_turns > 0:
				active_feuds += 1

		var sum_a := _summarize_slot(state, "A", slot_telem["A"])
		var sum_b := _summarize_slot(state, "B", slot_telem["B"])

		print("Completed in %.1fs | Active pacts=%d, feuds=%d, active_ruined_hexes=%d" % [
			elapsed_s, active_pacts, active_feuds, active_ruins
		])
		for slot_summary in [sum_a, sum_b]:
			print("  [Slot %s] strategy=%s | model=%s | settlements=%d | pop=%d | reserves=%.1f | def_tier(mean=%.2f, max=%d) | multi_hex_cities=%d | rural_hexes=%d" % [
				str(slot_summary["slot"]),
				str(slot_summary["strategy_id"]),
				str(slot_summary["model_tag"]),
				int(slot_summary["surviving_settlements"]),
				int(slot_summary["total_population"]),
				float(slot_summary["total_reserves"]),
				float(slot_summary["mean_defense_tier"]),
				int(slot_summary["max_defense_tier"]),
				int(slot_summary["multi_hex_cities"]),
				int(slot_summary["owned_rural_hexes"])
			])
			print("    Postures: %s" % JSON.stringify(slot_summary["posture_distribution"]))
			print("    Actions:  %s" % JSON.stringify(slot_summary["action_distribution"]))
		print("  Turn events:    %s" % JSON.stringify(m_turn_events))
		print("  Chronicle logs: %s" % JSON.stringify(m_chronicle))

	print("\n================================================================================")
	print("=== AGGREGATE EMERGENCE SUMMARY ===")
	print("Global Actions Chosen: %s" % JSON.stringify(global_actions))
	print("Global Turn Events:    %s" % JSON.stringify(global_turn_events))
	print("Global Chronicle Logs: %s" % JSON.stringify(global_chronicle))
	print("Telemetry by Strategy:")
	for sid in actions_by_strat.keys():
		print("  %s -> postures=%s | actions=%s" % [
			sid, JSON.stringify(postures_by_strat[sid]), JSON.stringify(actions_by_strat[sid])
		])
	quit(0)
