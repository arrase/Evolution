class_name EvoTestCognitiveOllama
extends RefCounted


static func run(r) -> void:
	_test_decision_model(r)
	_test_nonblocking_async_decision_and_smooth_panning(r)


static func _test_decision_model(r) -> void:
	print("-- Testing Decision Model & Normalization --")
	var ids: Array[String] = ["d1", "d2", "d3"]
	var raw := {"d1": 0.52, "d2": 0.31, "d3": 0.17}
	var norm := EvoDecisionModel.normalize_decision_probabilities(raw, ids)
	var probs: Dictionary = norm["probabilities"]
	var sum_p: float = 0.0
	for k in probs.keys():
		sum_p += float(probs[k])
	r._assert(is_equal_approx(sum_p, 1.0), "Normalized probabilities sum to 1.0000")
	r._assert(str(norm["dominant_decision_id"]) == "d1", "Dominant decision is d1")

	# Verify deterministic heuristic decision scorer has been completely removed
	var dm_inst := EvoDecisionModel.new()
	var hs_inst := EvoHeuristicScorer.new()
	r._assert(not dm_inst.has_method("evaluate_deme_heuristic"), "EvoDecisionModel has no evaluate_deme_heuristic fallback")
	r._assert(not hs_inst.has_method("evaluate_deme_heuristic"), "EvoHeuristicScorer has no evaluate_deme_heuristic fallback")

	# Verify pure Ollama System 1 model evaluation via signature cache
	var rift := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var west: EvoTypes.Deme = rift.demes["deme-rift-west"]
	var east: EvoTypes.Deme = rift.demes["deme-rift-east"]
	var west_sig := EvoDecisionModel.compute_deme_evaluation_signature(west, rift)
	var east_sig := EvoDecisionModel.compute_deme_evaluation_signature(east, rift)
	EvoOllamaClient.seed_signature_cache(west_sig, {
		"probabilities": {"dec-conservative-forage": 0.65, "dec-cooperate-store": 0.35},
		"dominant_decision_id": "dec-conservative-forage",
		"confidence": 0.88
	})
	EvoOllamaClient.seed_signature_cache(east_sig, {
		"probabilities": {"dec-cooperate-store": 0.70, "dec-selective-migration": 0.30},
		"dominant_decision_id": "dec-cooperate-store",
		"confidence": 0.91
	})
	EvoDecisionModel.evaluate_all_demes(rift, "es")
	r._assert(west.last_dominant_decision_id == "dec-conservative-forage", "West forest deme applies Ollama System 1 decision")
	r._assert(east.last_dominant_decision_id == "dec-cooperate-store", "East savanna deme applies Ollama System 1 decision")
	r._assert("Ollama System 1" in west.last_justification, "Justification reflects live neural Ollama System 1 evaluation")
	EvoOllamaClient.clear_cache()


static func _test_nonblocking_async_decision_and_smooth_panning(r) -> void:
	print("-- Testing Non-Blocking Async Decision Model & Smooth Late-Game Panning --")
	var t0_usec := Time.get_ticks_usec()
	var status := EvoDecisionModel.check_ollama_status(true)
	var status_ms := float(Time.get_ticks_usec() - t0_usec) / 1000.0
	r._assert(status.has("primary_tag") and status.has("secondary_tag"), "check_ollama_status(true) returns valid status dictionary immediately")
	r._assert(status_ms < 15.0, "check_ollama_status(true) is non-blocking on main thread (took %.3f ms)" % status_ms)

	# Build a late-game world with 16 diverse demes across different hexes and live models enabled
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
		d.population = 80 + (i * 15)
		d.energy_reserves = 60.0 + float(i * 2)
		d.lineage_id = "lineage-west" if (i % 2 == 0) else "lineage-east"
		d.color = "#f59e0b" if (i % 2 == 0) else "#10b981"
		d.biological_trait_ids.assign(["bio-thermal-tolerance", "bio-social-instinct"])
		if i % 3 == 0:
			d.cultural_trait_ids.assign(["cul-communal-conservation"])
		d.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(d.id)
		state.demes[d.id] = d
		(state.cells[target_hid] as EvoTypes.HexCell).deme_ids.append(d.id)

	r._assert(state.demes.size() >= 16, "Late-game stress world populated with %d demes" % state.demes.size())

	var eval_start_usec := Time.get_ticks_usec()
	EvoDecisionModel.evaluate_all_demes(state, "es")
	var eval_ms := float(Time.get_ticks_usec() - eval_start_usec) / 1000.0
	r._assert(eval_ms < 15.0, "evaluate_all_demes with 16 demes & live models enabled is non-blocking (took %.3f ms)" % eval_ms)

	# Simulate 6 generations of continuous camera panning + turn progression + rendering rebuilds
	main.world_renderer.refresh()
	main.world_renderer._process(0.016)
	r._assert(not main.world_renderer._column_state_cache.is_empty(), "WorldRenderer column visual state cache populated")
	r._assert(not main.world_renderer._cell_flora_cache.is_empty(), "WorldRenderer static flora prop cache populated")

	var max_step_and_frame_ms: float = 0.0
	for _step_i in range(6):
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

	# Verify zoom pivot invariance around cursor offset and outer-ring pan reachability at MAX_ZOOM
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

	# Verify bounded deme.id length across migrations
	var max_id_len: int = 0
	for did in state.demes.keys():
		max_id_len = maxi(max_id_len, str(did).length())
	r._assert(max_id_len < 64, "Deme IDs remain compact and bounded across generations (max len %d)" % max_id_len)

	main.free()
