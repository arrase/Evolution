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

	r._assert(EvoActionMenu.MAX_NEIGHBORS == 5 and EvoActionMenu.MAX_SETTLE_OPTIONS == 3 and EvoActionMenu.MAX_OPTIONS == 18, "EvoActionMenu caps are MAX_NEIGHBORS=5, MAX_SETTLE_OPTIONS=3, MAX_OPTIONS=18")

	var dom_menu := EvoActionMenu.build_domestic(west, rift)
	r._assert(dom_menu.has("forage") and dom_menu.has("intensify") and dom_menu.has("fortify") and dom_menu.has("innovate"), "EvoActionMenu.build_domestic includes forage, intensify, plus fortify and innovate when eligible")
	var dom_criteria := EvoOutcomeForecast.describe_domestic_menu(west, dom_menu, rift)
	r._assert(dom_criteria.size() == dom_menu.size() and str(dom_criteria["innovate"]).contains(str(int(EvoPayoffs.INNOVATE_COST_RESERVES))) and EvoOutcomeForecast.describe_domestic(west, "innovate", rift) == str(dom_criteria["innovate"]), "EvoOutcomeForecast.describe_domestic_menu and describe_domestic quantify domestic options including innovate cost (%d food)" % int(EvoPayoffs.INNOVATE_COST_RESERVES))
	var neutral_posture := EvoOutcomeForecast._describe_posture_formatted("open_harvest", 100.0, 105.0, 60.0, 1, 2, 1)
	r._assert(not neutral_posture.contains("unnecessarily") and not neutral_posture.contains("HIGH RISK!"), "EvoOutcomeForecast._describe_posture_formatted uses neutral quantitative wording")

	# Generation-0 isolation across all 3 presets (1v1 founders, zero premature diplomatic/military actions)
	var social_military_types: Array[String] = [
		"offer_pact", "accept_pact", "trade", "aid",
		"demand_tribute", "pay_tribute", "raid", "conquer",
		"betray", "unite", "accept_union"
	]
	for pid in EvoCatalog.PRESET_IDS:
		var pw := EvoCatalog.create_preset_world(pid, "en", "strat-cooperation", "strat-war")
		r._assert(pw.demes.size() == 2, "Preset %s initializes 1v1 with 2 demes at Generation 0" % pid)
		for did in pw.demes.keys():
			var d: EvoTypes.Deme = pw.demes[did]
			r._assert(EvoActionMenu.contact_demes(d, pw).is_empty(), "Preset %s founder %s has empty contact_demes at Generation 0" % [pid, did])
			var gen0_menu := EvoActionMenu.build(d, pw)
			var has_social_mil := false
			var only_none_or_settle := true
			for opt in gen0_menu:
				var otype := str(opt["type"])
				if otype in social_military_types:
					has_social_mil = true
				if otype != "none" and otype != "settle":
					only_none_or_settle = false
			r._assert(
				not has_social_mil and only_none_or_settle,
				"Preset %s founder %s Generation-0 external menu excludes social and military actions" % [pid, did]
			)
			if d.biological_trait_ids.has("bio-r-strategy") and d.population >= EvoPayoffs.settle_min_pop(d):
				r._assert(gen0_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "settle"), "Preset %s r-strategy founder %s unlocks settle at Generation 0" % [pid, did])
			else:
				r._assert(gen0_menu.size() == 1 and str(gen0_menu[0]["key"]) == "none", "Preset %s K-strategy founder %s starts with only 'none' external action at Generation 0" % [pid, did])

	var menu := EvoActionMenu.build(west, rift)
	var east_menu := EvoActionMenu.build(east, rift)
	r._assert(menu.size() == 1 and str(menu[0]["key"]) == "none", "Isolated Gen-0 K-strategy founder external menu contains only 'none'")
	r._assert(east_menu.size() >= 2 and east_menu.size() <= EvoActionMenu.MAX_OPTIONS, "EvoActionMenu.build generates bounded feasible external menu for r-strategy founder (%d options)" % east_menu.size())
	var has_none := false
	var has_domestic_in_external := false
	var all_forecasts_nonempty := true
	for opt in east_menu:
		var k := str(opt["key"])
		if k == "none":
			has_none = true
		if k in ["forage", "intensify", "fortify", "innovate"]:
			has_domestic_in_external = true
		var fc := EvoOutcomeForecast.describe(east, opt, rift)
		if fc.strip_edges() == "":
			all_forecasts_nonempty = false
	r._assert(has_none and not has_domestic_in_external, "External action menu includes 'none' and excludes domestic actions")
	r._assert(all_forecasts_nonempty, "EvoOutcomeForecast.describe produces quantified payoff text for every feasible option")

	# Unclaimed wilderness vs. physical border contact (distance-2 and distance-3)
	var border_world := EvoCatalog.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	for cid in border_world.cells.keys():
		var c: EvoTypes.HexCell = border_world.cells[cid]
		c.deme_ids.clear()
		c.owner_deme_id = ""
		c.land_use = "wild"
		c.biome = "savanna"
		c.altitude = 0.45
		c.current_resources = 220.0
	var bw_a: EvoTypes.Deme = border_world.demes["deme-rift-west"]
	var bw_b: EvoTypes.Deme = border_world.demes["deme-rift-east"]
	bw_a.hex_id = "0,0"
	bw_a.urban_hex_ids = ["0,0"]
	bw_a.population = 180
	bw_a.energy_reserves = 140.0
	bw_b.hex_id = "2,0"
	bw_b.urban_hex_ids = ["2,0"]
	bw_b.population = 120
	bw_b.energy_reserves = 140.0
	(border_world.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([bw_a.id])
	(border_world.cells["2,0"] as EvoTypes.HexCell).deme_ids.assign([bw_b.id])

	# Verify '- isolated' when a settlement has no passable perimeter neighbors or contacts
	for nid in HexMath.get_neighbor_ids(0, 0, border_world.cells):
		(border_world.cells[nid] as EvoTypes.HexCell).biome = "ocean"
	var isolated_report := EvoSituationReport.build(bw_a, border_world)
	r._assert(isolated_report.contains("Neighbors & borders:\n- isolated"), "EvoSituationReport reports '- isolated' when settlement has no passable neighbors")
	for nid in HexMath.get_neighbor_ids(0, 0, border_world.cells):
		(border_world.cells[nid] as EvoTypes.HexCell).biome = "savanna"

	# Distance-2 unclaimed wilderness ("1,0" wild) grants NO social or conquest contact; claiming "1,0" as crops grants both
	r._assert(
		(border_world.cells["1,0"] as EvoTypes.HexCell).owner_deme_id == ""
		and not EvoActionMenu.has_social_contact(bw_a, bw_b, border_world)
		and not EvoActionMenu.can_reach_for_conquest(bw_a, bw_b, border_world),
		"Distance-2 demes separated by unclaimed wild (1,0) have has_social_contact == false and can_reach_for_conquest == false"
	)
	(border_world.cells["1,0"] as EvoTypes.HexCell).owner_deme_id = bw_a.id
	(border_world.cells["1,0"] as EvoTypes.HexCell).land_use = "crops"
	r._assert(
		EvoActionMenu.has_social_contact(bw_a, bw_b, border_world)
		and EvoActionMenu.can_reach_for_conquest(bw_a, bw_b, border_world),
		"Claiming intervening field (1,0) as crops establishes distance-2 social and conquest contact"
	)
	var d2_menu := EvoActionMenu.build(bw_a, border_world)
	r._assert(
		d2_menu.size() >= 2 and d2_menu.size() <= EvoActionMenu.MAX_OPTIONS
		and d2_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "offer_pact" and str(o["target"]) == bw_b.id)
		and d2_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "conquer" and str(o["target"]) == bw_b.id),
		"Distance-2 border contact unlocks offer_pact and urban conquer in bounded EvoActionMenu"
	)
	var d2_report := EvoSituationReport.build(bw_a, border_world)
	r._assert(d2_report.contains("Neighbors & borders:") and d2_report.contains(bw_b.name), "EvoSituationReport includes contact neighbor details under Neighbors & borders")

	# Distance-3 territorial contact: touching rural fields allow social contact, border raid & tribute without urban conquer or unite
	(border_world.cells["2,0"] as EvoTypes.HexCell).deme_ids.clear()
	bw_b.hex_id = "3,0"
	bw_b.urban_hex_ids = ["3,0"]
	(border_world.cells["3,0"] as EvoTypes.HexCell).deme_ids.assign([bw_b.id])
	(border_world.cells["2,0"] as EvoTypes.HexCell).owner_deme_id = bw_b.id
	(border_world.cells["2,0"] as EvoTypes.HexCell).land_use = "crops"
	r._assert(EvoPayoffs.min_urban_distance(bw_a, bw_b, border_world) == 3 and EvoActionMenu.has_territorial_contact(bw_a, bw_b, border_world) and EvoActionMenu.has_social_contact(bw_a, bw_b, border_world), "Distance-3 touching rural fields establish territorial and social contact")
	r._assert(not EvoActionMenu.can_reach_for_conquest(bw_a, bw_b, border_world), "Distance-3 territorial contact does not unlock urban conquest")
	var bw_menu := EvoActionMenu.build(bw_a, border_world)
	r._assert(
		bw_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "raid" and str(o["target"]) == bw_b.id)
		and bw_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "demand_tribute" and str(o["target"]) == bw_b.id)
		and not bw_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) in ["conquer", "unite"] and str(o["target"]) == bw_b.id),
		"Distance-3 territorial contact unlocks border raid and demand_tribute without urban conquer or unite"
	)

	# Prepare /v1/systemone job & payload (3 questions: posture, domestic, decision)
	var job := EvoActionPolicy.prepare_deme_menu(west, rift)
	var payload := EvoOllamaClient.build_payload(job, "d3:4b")
	r._assert(typeof(payload["state"]) == TYPE_STRING and str(payload["state"]) != "", "/v1/systemone payload['state'] is a non-empty plain String")
	r._assert(not payload.has("options"), "/v1/systemone payload omits options override so models use native context")
	var questions: Dictionary = payload["questions"]
	r._assert(questions.size() == 3 and questions.has("posture") and questions.has("domestic") and questions.has("decision"), "/v1/systemone payload['questions'] has exact 3 entries: 'posture', 'domestic', and 'decision'")
	var q_posture: Dictionary = questions["posture"]
	var q_domestic: Dictionary = questions["domestic"]
	var q_decision: Dictionary = questions["decision"]
	r._assert(str(q_posture["type"]) == "choice" and (q_posture["criteria"] as Dictionary).size() == 3, "'posture' question is type 'choice' with 3 defense posture criteria")
	r._assert(str(q_domestic["type"]) == "choice" and (q_domestic["criteria"] as Dictionary).size() == dom_menu.size(), "'domestic' question is type 'choice' with domestic priority criteria")
	r._assert(str(q_decision["type"]) == "choice" and not (q_decision["criteria"] as Dictionary).is_empty(), "'decision' question is type 'choice' with external action forecast criteria")

	# Pure ethos/identity instructions (no if/then numeric rules)
	var strat_coop: EvoTypes.StrategyDef = rift.strategies_catalog[west.strategy_id]
	var instr := EvoActionPolicy.build_instructions(west, rift)
	r._assert(instr.contains(strat_coop.description) and instr.contains("Cooperative Alliance"), "EvoActionPolicy.build_instructions embeds StrategyDef.description and doctrine")
	for axis_tok in ["K-strategy", "social_cohesion", "spatial_mobility", "innovation_rate", "ecological_impact", "transmission_threshold"]:
		r._assert(instr.contains(axis_tok), "EvoActionPolicy.build_instructions includes biophysical profile metric '%s'" % axis_tok)
	r._assert(
		instr.contains("civic endurance")
		and instr.contains("solidarity with kin")
		and instr.contains("ecological balance")
		and not instr.contains("if "),
		"EvoActionPolicy.build_instructions uses pure ethos/identity trait directives without if/then numeric rules"
	)

	# Situation report: Neighbors & borders, Regional radar (3-4 hexes), Horizons, domestic/posture, scorched ruins, Recent history
	var perim_ids := EvoTypes.urban_perimeter_hex_ids(west, rift)
	for nid in perim_ids:
		var pc: EvoTypes.HexCell = rift.cells[nid]
		if EvoActionMenu.is_passable(pc) and pc.deme_ids.is_empty():
			pc.ruin_turns = 2
			pc.has_ruins = true
			break
	EvoOllamaClient.clear_cache()
	west.domestic_action = "forage"
	west.chosen_action = EvoActionMenu.option("none")
	east.domestic_action = "intensify"
	east.chosen_action = EvoActionMenu.option("none")
	EvoTurnEngine.advance_generation(rift, "en")
	r._assert(not west.memory.is_empty() and not east.memory.is_empty(), "EvoTurnEngine records domestic economic actions in deme.memory when external action is 'none'")

	var report := EvoSituationReport.build(west, rift)
	r._assert(report.contains("Horizons:"), "EvoSituationReport.build includes Horizons:")
	r._assert(report.contains("Neighbors & borders:") and report.contains("Regional radar (3-4 hexes):"), "EvoSituationReport.build includes Neighbors & borders and Regional radar (3-4 hexes)")
	r._assert(report.contains("domestic forage, posture open harvest"), "EvoSituationReport.build includes active domestic focus and rural defense posture")
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

	# 2. Category-level sharpening at TEMPERATURE=0.45: singletons sharpen upward, multi-target social actions avoid dilution
	var single_sharp := EvoActionPolicy._sharpen_and_normalize({"forage": 0.55, "intensify": 0.45}, ["forage", "intensify"])
	r._assert(float(single_sharp["forage"]) > 0.55, "TEMPERATURE=0.45 sharpens singleton raw probability 0.55 upward (%.4f)" % float(single_sharp["forage"]))
	var multi_keys: Array = ["none", "trade:b", "trade:c", "trade:d"]
	var multi_raw := {"none": 0.25, "trade:b": 0.15, "trade:c": 0.15, "trade:d": 0.15}
	var multi_sharp := EvoActionPolicy._sharpen_and_normalize(multi_raw, multi_keys)
	var trade_mass := float(multi_sharp["trade:b"]) + float(multi_sharp["trade:c"]) + float(multi_sharp["trade:d"])
	r._assert(trade_mass > float(multi_sharp["none"]) and trade_mass > 0.70, "Category-level sharpening preserves multi-target trade mass (%.4f) above singleton none (%.4f)" % [trade_mass, float(multi_sharp["none"])])

	# 3. apply_live_result sets deterministic argmax preview on action, domestic, and posture WITHOUT consuming state.rng
	db.population = 150
	db.energy_reserves = 120.0
	EvoActionPolicy.prepare_deme_menu(da, world)
	EvoActionPolicy.prepare_deme_menu(db, world)
	var ext_key_a := ""
	for k in da.action_forecasts.keys():
		if str(k) != "none":
			ext_key_a = str(k)
			break
	var ext_key_b := ""
	for k in db.action_forecasts.keys():
		if str(k) != "none":
			ext_key_b = str(k)
			break
	r._assert(ext_key_a != "" and ext_key_b != "", "Both test demes expose non-'none' external actions for live evaluation sampling")
	world.rng.seed = 202611
	var rng_state_before := world.rng.state
	var live_entry_a := {
		"probabilities": {ext_key_a: 0.55, "none": 0.45},
		"domestic_probabilities": {"forage": 0.55, "intensify": 0.45},
		"posture_probabilities": {"open_harvest": 0.25, "patrol_fields": 0.60, "mobilized_garrison": 0.15},
		"confidence": 0.88
	}
	var live_entry_b := {
		"probabilities": {"none": 0.56, ext_key_b: 0.44},
		"domestic_probabilities": {"intensify": 0.58, "forage": 0.42},
		"posture_probabilities": {"open_harvest": 0.20, "patrol_fields": 0.25, "mobilized_garrison": 0.55},
		"confidence": 0.91
	}
	EvoActionPolicy.apply_live_result(da, live_entry_a)
	EvoActionPolicy.apply_live_result(db, live_entry_b)
	r._assert(world.rng.state == rng_state_before, "EvoActionPolicy.apply_live_result does NOT consume state.rng")
	r._assert(
		str(da.chosen_action["key"]) == ext_key_a
		and da.domestic_action == "forage"
		and da.defense_posture == "patrol_fields",
		"apply_live_result sets deterministic argmax preview on external action, domestic_action, and defense_posture"
	)
	r._assert(float(da.domestic_probabilities["forage"]) > 0.55, "TEMPERATURE=0.45 sharpens domestic probability 0.55 upward (%.4f)" % float(da.domestic_probabilities["forage"]))

	# 4. finalize_turn_decisions samples stochastically from state.rng in sorted deme_id order and is 100% seed-reproducible
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
		and da.domestic_action == clone_da.domestic_action
		and db.domestic_action == clone_db.domestic_action
		and da.defense_posture == clone_da.defense_posture
		and db.defense_posture == clone_db.defense_posture
		and world.rng.state == world_clone.rng.state,
		"finalize_turn_decisions samples identically in sorted deme_id order regardless of async worker completion order"
	)

	# Verify non-argmax outcome occurs across repeated rolls (true stochastic sampling, not frozen argmax)
	var saw_intensify := false
	var saw_none := false
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 12345
	for _i in range(40):
		EvoActionPolicy.sample_turn_decisions(da, test_rng)
		if da.domestic_action == "intensify":
			saw_intensify = true
		if str(da.chosen_action["key"]) == "none":
			saw_none = true
		if saw_intensify and saw_none:
			break
	r._assert(saw_intensify and saw_none, "sample_turn_decisions samples non-dominant domestic and external options proportionally at TEMPERATURE=0.45")
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
	var max_pan_frame_ms: float = 0.0
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

		main.camera.pan_offset += Vector2(-14.0, 10.0)
		main.camera._target_pan = main.camera.pan_offset
		var pan_t0 := Time.get_ticks_usec()
		main.camera._process(0.016)
		main.world_renderer._process(0.016)
		main._process(0.016)
		max_pan_frame_ms = maxf(max_pan_frame_ms, float(Time.get_ticks_usec() - pan_t0) / 1000.0)

	print("[PERF] check_ollama_status=%.3f ms | evaluate_all_demes(16)=%.3f ms | max_turn_step_while_panning=%.3f ms | max_pan_frame=%.3f ms" % [
		status_ms, eval_ms, max_step_and_frame_ms, max_pan_frame_ms
	])
	r._assert(max_pan_frame_ms < 10.0, "Camera panning frame with 16 demes renders smoothly without rebuild stutter (max %.3f ms)" % max_pan_frame_ms)
	r._assert(max_step_and_frame_ms < 45.0, "Turn step (3-question prep) + renderer rebuild while panning with 16 demes completes promptly (max %.3f ms)" % max_step_and_frame_ms)

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
