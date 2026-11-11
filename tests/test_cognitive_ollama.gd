class_name EvoTestCognitiveOllama
extends RefCounted


static func run(r) -> void:
	_test_decision_model_and_systemone_payload(r)
	_test_slot_routing_and_deterministic_turn_sampling(r)
	_test_nonblocking_async_decision_and_smooth_panning(r)


static func _test_decision_model_and_systemone_payload(r) -> void:
	print("-- Testing Decision Model, /v1/systemone Payload, Normative Instructions & Situation Report --")
	var ids: Array[String] = ["forage", "intensify", "settle:-1,1"]
	var raw := {"forage": 0.52, "intensify": 0.31, "settle:-1,1": 0.17}
	var probs := EvoOllamaClient.normalize_probabilities(raw, ids)
	var sum_p: float = 0.0
	for k in probs.keys():
		sum_p += float(probs[k])
	r._assert(is_equal_approx(sum_p, 1.0), "Normalized probabilities sum to 1.0000")
	r._assert(is_equal_approx(float(probs["forage"]), 0.52), "Normalized probability for forage is 0.52")

	var dm_inst := EvoDecisionModel.new()
	r._assert(not dm_inst.has_method("evaluate_deme_heuristic"), "EvoDecisionModel has no evaluate_deme_heuristic fallback")

	var rift := EvoCatalog.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-war")
	var west: EvoTypes.Deme = rift.demes["deme-rift-west"]
	var east: EvoTypes.Deme = rift.demes["deme-rift-east"]

	var menu := EvoActionMenu.build(west, rift)
	r._assert(menu.size() >= 3 and menu.size() <= 14, "EvoActionMenu.build generates bounded feasible menu (%d options)" % menu.size())
	var has_forage := false
	var all_forecasts_nonempty := true
	for opt in menu:
		if str(opt["key"]) == "forage":
			has_forage = true
		var fc := EvoOutcomeForecast.describe(west, opt, rift)
		if fc.strip_edges() == "":
			all_forecasts_nonempty = false
	r._assert(has_forage, "Action menu always includes baseline forage option")
	r._assert(all_forecasts_nonempty, "EvoOutcomeForecast.describe produces quantified payoff text for every feasible option")

	# Prepare /v1/systemone job & payload
	var job := EvoActionPolicy.prepare_deme_menu(west, rift)
	var payload := EvoOllamaClient.build_payload(job, "d3:4b")
	r._assert(typeof(payload["state"]) == TYPE_STRING and str(payload["state"]) != "", "/v1/systemone payload['state'] is a non-empty plain String")
	r._assert(not payload.has("options"), "/v1/systemone payload omits options override so models use native context")
	var questions: Dictionary = payload["questions"]
	r._assert(questions.size() == 2 and questions.has("posture") and questions.has("decision"), "/v1/systemone payload['questions'] has exact 2 entries: 'posture' and 'decision'")
	var q_posture: Dictionary = questions["posture"]
	var q_decision: Dictionary = questions["decision"]
	r._assert(str(q_posture["type"]) == "choice" and (q_posture["criteria"] as Dictionary).size() == 3, "'posture' question is type 'choice' with 3 defense posture criteria")
	r._assert(str(q_decision["type"]) == "choice" and not (q_decision["criteria"] as Dictionary).is_empty(), "'decision' question is type 'choice' with action forecast criteria")

	# Normative instructions: strategy doctrine + StrategyDef.description + biophysical profile + active bio-*/cul-* directives
	var strat_coop: EvoTypes.StrategyDef = rift.strategies_catalog[west.strategy_id]
	var instr := EvoActionPolicy.build_instructions(west, rift)
	r._assert(instr.contains(strat_coop.description) and instr.contains("Cooperative Alliance"), "EvoActionPolicy.build_instructions embeds StrategyDef.description and doctrine")
	for axis_tok in ["K-strategy", "social_cohesion", "spatial_mobility", "innovation_rate", "ecological_impact", "transmission_threshold"]:
		r._assert(instr.contains(axis_tok), "EvoActionPolicy.build_instructions includes biophysical profile metric '%s'" % axis_tok)
	r._assert(instr.contains("Tier III-IV fortified cities") and instr.contains("Protect carrying capacity above 80%"), "EvoActionPolicy.build_instructions includes active bio-* and cul-* trait directives")

	# Situation report: Horizons, posture / field security, scorched ruins, and Recent history after turn advance
	var perim_ids := EvoTypes.urban_perimeter_hex_ids(west, rift)
	for nid in perim_ids:
		var pc: EvoTypes.HexCell = rift.cells[nid]
		if EvoActionMenu.is_passable(pc) and pc.deme_ids.is_empty():
			pc.ruin_turns = 2
			pc.has_ruins = true
			break
	west.chosen_action = EvoActionMenu.option("forage")
	east.chosen_action = EvoActionMenu.option("intensify")
	EvoTurnEngine.advance_generation(rift, "en")
	r._assert(not west.memory.is_empty() and not east.memory.is_empty(), "EvoTurnEngine records own economic actions in deme.memory so memory is never empty after turns advance")

	var report := EvoSituationReport.build(west, rift)
	r._assert(report.contains("Horizons:"), "EvoSituationReport.build includes Horizons:")
	r._assert(report.contains("posture open harvest"), "EvoSituationReport.build includes rural field security posture")
	r._assert(report.contains("scorched ruins (1 turns to recover)"), "EvoSituationReport.build reports nearby ruined fields and recovery countdown")
	r._assert(report.contains("Recent history:") and report.contains("foraged"), "EvoSituationReport.build includes Recent history with deme's own past turn actions")


static func _test_slot_routing_and_deterministic_turn_sampling(r) -> void:
	print("-- Testing Faction Slot Routing, Control Mode & Deterministic TEMPERATURE=0.45 Turn Sampling --")
	r._assert(is_equal_approx(EvoActionPolicy.TEMPERATURE, 0.45), "EvoActionPolicy.TEMPERATURE is 0.45")

	var prev_p := EvoUserSettings.primary_model
	var prev_s := EvoUserSettings.secondary_model

	# 1. Independent routing for Slot A vs Slot B + identical-model scientific control mode
	EvoUserSettings.primary_model = "d3:4b"
	EvoUserSettings.secondary_model = "tev1:4b"
	r._assert(EvoDecisionModel.resolve_model_for_slot("A") == "d3:4b" and EvoDecisionModel.resolve_model_for_slot("B") == "tev1:4b", "resolve_model_for_slot routes A -> primary_model and B -> secondary_model")

	var world := EvoCatalog.create_preset_world("preset-rift-savanna", "en", "strat-expansion", "strat-trade")
	var da: EvoTypes.Deme = world.demes["deme-rift-west"]
	var db: EvoTypes.Deme = world.demes["deme-rift-east"]
	EvoDecisionModel.reassign_world_models(world)
	r._assert(da.decision_model_tag == "d3:4b" and db.decision_model_tag == "tev1:4b", "reassign_world_models assigns distinct models by faction_slot")

	EvoUserSettings.primary_model = "d3:4b"
	EvoUserSettings.secondary_model = "d3:4b"
	EvoDecisionModel.reassign_world_models(world)
	r._assert(da.decision_model_tag == "d3:4b" and db.decision_model_tag == "d3:4b", "Control mode (primary_model == secondary_model) assigns identical model to both slots")

	EvoUserSettings.primary_model = prev_p
	EvoUserSettings.secondary_model = prev_s

	# 2. apply_live_result sets deterministic argmax preview WITHOUT consuming state.rng
	EvoActionPolicy.prepare_deme_menu(da, world)
	EvoActionPolicy.prepare_deme_menu(db, world)
	world.rng.seed = 202611
	var rng_state_before := world.rng.state
	var live_entry_a := {
		"probabilities": {"forage": 0.55, "intensify": 0.45},
		"posture_probabilities": {"open_harvest": 0.25, "patrol_fields": 0.60, "mobilized_garrison": 0.15},
		"confidence": 0.88
	}
	var live_entry_b := {
		"probabilities": {"intensify": 0.58, "forage": 0.42},
		"posture_probabilities": {"open_harvest": 0.20, "patrol_fields": 0.25, "mobilized_garrison": 0.55},
		"confidence": 0.91
	}
	EvoActionPolicy.apply_live_result(da, live_entry_a)
	EvoActionPolicy.apply_live_result(db, live_entry_b)
	r._assert(world.rng.state == rng_state_before, "EvoActionPolicy.apply_live_result does NOT consume state.rng")
	r._assert(str(da.chosen_action["key"]) == "forage" and da.defense_posture == "patrol_fields", "apply_live_result sets deterministic argmax preview on action and posture")
	r._assert(float(da.action_probabilities["forage"]) > 0.55, "TEMPERATURE=0.45 sharpens raw probability 0.55 upward (%.4f)" % float(da.action_probabilities["forage"]))

	# 3. finalize_turn_decisions samples stochastically from state.rng in sorted deme_id order and is 100% seed-reproducible
	var world_clone := EvoTypes.WorldState.from_dict(world.to_dict())
	var clone_da: EvoTypes.Deme = world_clone.demes["deme-rift-west"]
	var clone_db: EvoTypes.Deme = world_clone.demes["deme-rift-east"]
	EvoActionPolicy.prepare_deme_menu(clone_da, world_clone)
	EvoActionPolicy.prepare_deme_menu(clone_db, world_clone)
	# Apply in reverse arrival order on clone to prove finalize_turn_decisions sorts deme_ids deterministically
	EvoActionPolicy.apply_live_result(clone_db, live_entry_b)
	EvoActionPolicy.apply_live_result(clone_da, live_entry_a)

	world.rng.seed = 987654
	world_clone.rng.seed = 987654
	EvoDecisionModel.finalize_turn_decisions(world)
	EvoDecisionModel.finalize_turn_decisions(world_clone)
	r._assert(world.rng.state != rng_state_before and da.pending_raw_eval.is_empty() and db.pending_raw_eval.is_empty(), "finalize_turn_decisions consumes state.rng and clears pending_raw_eval")
	r._assert(
		str(da.chosen_action["key"]) == str(clone_da.chosen_action["key"])
		and str(db.chosen_action["key"]) == str(clone_db.chosen_action["key"])
		and da.defense_posture == clone_da.defense_posture
		and db.defense_posture == clone_db.defense_posture
		and world.rng.state == world_clone.rng.state,
		"finalize_turn_decisions samples identically in sorted deme_id order regardless of async worker completion order"
	)

	# Verify non-argmax outcome occurs across repeated rolls (true stochastic sampling, not frozen argmax)
	var saw_intensify := false
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 12345
	for _i in range(30):
		EvoActionPolicy.sample_turn_decisions(da, test_rng)
		if str(da.chosen_action["key"]) == "intensify":
			saw_intensify = true
			break
	r._assert(saw_intensify, "sample_turn_decisions samples non-dominant feasible options proportionally at TEMPERATURE=0.45")
	EvoOllamaClient.clear_cache()


static func _test_nonblocking_async_decision_and_smooth_panning(r) -> void:
	print("-- Testing Non-Blocking Async Decision Model & Smooth Late-Game Panning --")
	var t0_usec := Time.get_ticks_usec()
	var status := EvoDecisionModel.check_ollama_status(true)
	var status_ms := float(Time.get_ticks_usec() - t0_usec) / 1000.0
	r._assert(status.has("primary_tag") and status.has("secondary_tag"), "check_ollama_status(true) returns valid status dictionary immediately")
	r._assert(status_ms < 15.0, "check_ollama_status(true) is non-blocking on main thread (took %.3f ms)" % status_ms)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	r.root.add_child(main)
	if main.camera == null:
		main._ready()

	main.load_preset("preset-rift-savanna")
	main.hud._set_startup_blocked(false)
	var state := main.world_state

	var land_hexes: Array[String] = []
	for hid in state.cells.keys():
		var c: EvoTypes.HexCell = state.cells[hid]
		if c.biome != "ocean" and c.deme_ids.is_empty():
			land_hexes.append(hid)

	for i in range(14):
		var target_hid := land_hexes[i % land_hexes.size()]
		var d := EvoTypes.Deme.new()
		d.id = "deme-perf-test-%d" % i
		d.name = "Clan Perf %d" % i
		d.hex_id = target_hid
		d.urban_hex_ids = [target_hid]
		d.faction_slot = "A" if (i % 2 == 0) else "B"
		d.population = 80 + (i * 15)
		d.energy_reserves = 60.0 + float(i * 2)
		d.lineage_id = "lineage-rift-west" if (i % 2 == 0) else "lineage-rift-east"
		d.strategy_id = "strat-cooperation" if (i % 2 == 0) else "strat-war"
		d.color = "#f59e0b" if (i % 2 == 0) else "#10b981"
		d.biological_trait_ids.assign(["bio-thermal-tolerance", "bio-social-instinct"])
		if i % 3 == 0:
			d.cultural_trait_ids.assign(["cul-communal-conservation"])
		d.decision_model_tag = EvoDecisionModel.resolve_model_for_slot(d.faction_slot)
		state.demes[d.id] = d
		(state.cells[target_hid] as EvoTypes.HexCell).deme_ids.append(d.id)

	r._assert(state.demes.size() >= 16, "Late-game stress world populated with %d demes" % state.demes.size())

	EvoDecisionModel.wait_for_workers()
	var eval_start_usec := Time.get_ticks_usec()
	EvoDecisionModel.evaluate_all_demes(state, "es")
	var eval_ms := float(Time.get_ticks_usec() - eval_start_usec) / 1000.0
	r._assert(eval_ms < 25.0, "evaluate_all_demes with 16 demes & live models enabled is non-blocking (took %.3f ms)" % eval_ms)

	main.world_renderer.refresh()
	main.world_renderer._process(0.016)
	r._assert(not main.world_renderer._column_state_cache.is_empty(), "WorldRenderer column visual state cache populated")
	r._assert(not main.world_renderer._cell_flora_cache.is_empty(), "WorldRenderer static flora prop cache populated")

	var max_step_and_frame_ms: float = 0.0
	for _step_i in range(6):
		EvoOllamaClient.clear_cache()
		main.camera.pan_offset += Vector2(28.0, -18.0)
		main.camera._target_pan = main.camera.pan_offset
		var frame_t0 := Time.get_ticks_usec()
		main.step_generation()
		main.camera._process(0.016)
		main.world_renderer._process(0.016)
		main._process(0.016)
		var frame_ms := float(Time.get_ticks_usec() - frame_t0) / 1000.0
		max_step_and_frame_ms = maxf(max_step_and_frame_ms, frame_ms)

	print("[PERF] check_ollama_status=%.3f ms | evaluate_all_demes(16)=%.3f ms | max_turn_step_while_panning=%.3f ms" % [
		status_ms, eval_ms, max_step_and_frame_ms
	])
	r._assert(max_step_and_frame_ms < 25.0, "Turn step + renderer rebuild while panning with 16+ demes completes without stutter (max %.3f ms)" % max_step_and_frame_ms)

	main.camera.reset_camera()
	main.camera.pan_offset = main.camera._target_pan
	main.camera.zoom_level = main.camera._target_zoom
	var cursor_offset := Vector2(320.0, -180.0)
	var world_pt_before := (cursor_offset - main.camera._target_pan) / main.camera._target_zoom
	main.camera.zoom_by(0.45, cursor_offset)
	var world_pt_after := (cursor_offset - main.camera._target_pan) / main.camera._target_zoom
	r._assert(world_pt_before.distance_to(world_pt_after) < 0.01, "Zoom around cursor pivot preserves exact world point under cursor")

	main.camera._target_zoom = EvoCameraController.MAX_ZOOM
	main.camera.focus_on_hex(5, 0, 0.5)
	r._assert(main.camera._target_pan.length() > 5000.0, "Outer ring hexes are reachable at MAX_ZOOM without premature clamping")

	var max_id_len: int = 0
	for did in state.demes.keys():
		max_id_len = maxi(max_id_len, str(did).length())
	r._assert(max_id_len < 64, "Deme IDs remain compact and bounded across generations (max len %d)" % max_id_len)

	main.free()
