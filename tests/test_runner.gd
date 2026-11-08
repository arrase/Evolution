extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _suite_cfg_dir: String = ""
var _suite_cfg_path: String = ""


func _init() -> void:
	_suite_cfg_dir = "/tmp/evolution_test_suite_%d" % Time.get_ticks_usec()
	_suite_cfg_path = _suite_cfg_dir.path_join("settings.json")
	EvoUserSettings.config_path_override = _suite_cfg_path
	print("=== EVOLUTION GODOT 4 CORE SIMULATION TEST SUITE ===")
	_test_thermodynamics()
	_test_catalog_and_presets()
	_test_strategies_duel_and_persistence()
	_test_decision_model_and_normalization()
	_test_hawk_dove_and_symbiosis()
	_test_tragedy_of_the_commons()
	_test_baldwin_innovation_and_speciation()
	_test_kin_merge_fission_and_macro_outcome()
	_test_interventions()
	_test_serialization_roundtrip()
	_test_25_generations_all_presets()
	_test_main_scene_and_ui_integration()
	_test_nonblocking_async_decision_and_smooth_panning()
	_test_emergent_geopolitics_and_visual_artifacts()
	_test_social_memory_defense_tribute_and_synoecism()
	_test_bugfix_regressions()

	EvoDecisionModel.wait_for_workers()
	var suite_catalog_path := _suite_cfg_dir.path_join("user_catalog.json")
	if FileAccess.file_exists(suite_catalog_path):
		DirAccess.remove_absolute(suite_catalog_path)
	if FileAccess.file_exists(_suite_cfg_path):
		DirAccess.remove_absolute(_suite_cfg_path)
	if DirAccess.dir_exists_absolute(_suite_cfg_dir):
		DirAccess.remove_absolute(_suite_cfg_dir)
	EvoUserSettings.config_path_override = ""
	print("====================================================")
	print("PASSED: %d | FAILED: %d" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] " + msg)


func _test_thermodynamics() -> void:
	print("-- Testing Thermodynamics --")
	var balanced_vec := EvoTypes.BiophysicalVector.new(0.10, 0.25, 0.05, 0.20, 0.10, 0.15)
	var m1 := EvoThermodynamics.evaluate_thermodynamics(balanced_vec)
	_assert(is_equal_approx(float(m1["positive_advantages"]), 0.55), "Balanced positive advantages == 0.55")
	_assert(is_equal_approx(float(m1["required_cost"]), 0.0), "No required cost below 0.60 budget")
	_assert(bool(m1["is_balanced"]), "Vector within 0.60 budget is balanced")

	var unbalanced_vec := EvoTypes.BiophysicalVector.new(0.0, 0.80, 0.10, 0.50, 0.50, 0.20)
	var m2 := EvoThermodynamics.evaluate_thermodynamics(unbalanced_vec)
	# A+ = 1.80 -> C_req = 0.5 * (1.80 - 0.60) = 0.60
	_assert(is_equal_approx(float(m2["positive_advantages"]), 1.80), "Positive advantages == 1.80")
	_assert(is_equal_approx(float(m2["required_cost"]), 0.60), "Required cost == 0.60")
	_assert(not bool(m2["is_balanced"]), "Uncompensated vector is not balanced")

	var fixed_vec := EvoThermodynamics.validate_and_balance_thermodynamics(unbalanced_vec, false)
	var m2_after := EvoThermodynamics.evaluate_thermodynamics(fixed_vec)
	_assert(bool(m2_after["is_balanced"]), "Validated vector is balanced")
	_assert(is_equal_approx(fixed_vec.metabolic_cost, 0.60), "Adjusted metabolic cost == 0.60")

	var sandbox_vec := EvoThermodynamics.validate_and_balance_thermodynamics(unbalanced_vec, true)
	_assert(is_equal_approx(sandbox_vec.metabolic_cost, 0.0), "Free sandbox preserves uncompensated cost")


func _test_catalog_and_presets() -> void:
	print("-- Testing Catalog & Scientific Presets --")
	var rift := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	_assert(rift.cells.size() == 169, "Rift Savanna radius 7 has 169 cells")
	_assert(rift.demes.size() == 2, "Rift Savanna starts with 2 demes")
	_assert(rift.traits_catalog.size() == 11, "Base catalog has 11 traits (6 bio + 5 cul)")
	_assert(rift.decisions_catalog.size() == 7, "Base catalog has 7 decisions")

	var darwin := EvoCatalog.create_preset_world("preset-darwin-archipelago", "en")
	_assert(darwin.cells.size() == 169, "Darwin Archipelago radius 7 has 169 cells")
	_assert(darwin.demes.size() == 2 and darwin.demes.has("deme-darwin-founder") and darwin.demes.has("deme-darwin-rival"), "Darwin Archipelago starts with 2 rival founder demes (1v1)")
	_assert(darwin.glacial_sea_level_cycle, "Darwin Archipelago has glacial sea level cycle enabled")

	var island := EvoCatalog.create_preset_world("preset-finite-island", "es")
	_assert(island.cells.size() == 169, "Finite Island radius 7 has 169 cells")
	_assert(island.demes.size() == 2 and island.demes.has("deme-island-1") and island.demes.has("deme-island-2"), "Finite Island starts with 2 rival clans (1v1)")

	var west: EvoTypes.Deme = rift.demes["deme-rift-west"]
	_assert(EvoCatalog.deme_has_cultural_capacity(west, rift.traits_catalog), "West deme has cultural capacity via bio-social-instinct")
	var injected := EvoCatalog.inject_trait_into_deme(rift, "deme-rift-west", "bio-r-strategy", "es")
	_assert(injected, "Injecting bio-r-strategy succeeds")
	_assert(west.biological_trait_ids.has("bio-r-strategy"), "West deme now has bio-r-strategy")
	_assert(not west.biological_trait_ids.has("bio-k-strategy"), "Mutually exclusive bio-k-strategy was removed")


func _test_strategies_duel_and_persistence() -> void:
	print("-- Testing 1v1 Strategy Duel, Inheritance, Persistence & Forge UI --")
	# 1. Base strategies catalog & vector computation
	var base_strats := EvoCatalog.create_base_strategies_catalog("es")
	var base_traits := EvoCatalog.create_base_traits_catalog("es")
	var expected_strat_ids: Array[String] = [
		"strat-cooperation",
		"strat-expansion",
		"strat-trade",
		"strat-war",
		"strat-innovation"
	]
	_assert(base_strats.size() == 5, "Base strategies catalog has 5 default strategies")
	for sid in expected_strat_ids:
		_assert(base_strats.has(sid), "Base strategies catalog includes %s" % sid)
		var s: EvoTypes.StrategyDef = base_strats[sid]
		var vec := EvoCatalog.compute_strategy_vector(s, base_traits)
		_assert(vec != null and vec.extraction_efficiency > 0.0, "Strategy %s computes valid biophysical vector" % sid)

	# 2. 1v1 strategy matchup initialization in create_preset_world
	var duel_world := EvoCatalog.create_preset_world("preset-rift-savanna", "en", "strat-trade", "strat-innovation")
	_assert(duel_world.strategy_a_id == "strat-trade" and duel_world.strategy_b_id == "strat-innovation", "Preset world records strategy_a_id and strategy_b_id")
	var west: EvoTypes.Deme = duel_world.demes["deme-rift-west"]
	var east: EvoTypes.Deme = duel_world.demes["deme-rift-east"]
	var strat_trade: EvoTypes.StrategyDef = duel_world.strategies_catalog["strat-trade"]
	var strat_innov: EvoTypes.StrategyDef = duel_world.strategies_catalog["strat-innovation"]
	_assert(west.strategy_id == "strat-trade" and west.color == strat_trade.color, "Slot A deme receives strat-trade id and color")
	_assert(west.biological_trait_ids == strat_trade.biological_trait_ids and west.cultural_trait_ids == strat_trade.cultural_trait_ids, "Slot A deme receives strat-trade biological and cultural traits")
	_assert(east.strategy_id == "strat-innovation" and east.color == strat_innov.color, "Slot B deme receives strat-innovation id and color")
	_assert(east.biological_trait_ids == strat_innov.biological_trait_ids and east.cultural_trait_ids == strat_innov.cultural_trait_ids, "Slot B deme receives strat-innovation biological and cultural traits")
	var lin_w: EvoTypes.LineageNode = duel_world.lineage_tree[west.lineage_id]
	var lin_e: EvoTypes.LineageNode = duel_world.lineage_tree[east.lineage_id]
	_assert(lin_w.strategy_id == "strat-trade" and lin_w.color == strat_trade.color and lin_w.biological_trait_ids == strat_trade.biological_trait_ids, "Slot A lineage node synchronized with strat-trade")
	_assert(lin_e.strategy_id == "strat-innovation" and lin_e.color == strat_innov.color and lin_e.biological_trait_ids == strat_innov.biological_trait_ids, "Slot B lineage node synchronized with strat-innovation")

	# 3. Strategy inheritance across colonist budding migration and allopatric speciation
	west.population = 140
	west.energy_reserves = 200.0
	west.last_decision_probabilities = {"dec-selective-migration": 0.90, "dec-conservative-forage": 0.10}
	west.last_dominant_decision_id = "dec-selective-migration"
	var init_pops := {west.id: west.population, east.id: east.population}
	var eff_vecs := {
		west.id: EvoEcologyInteraction.compute_effective_vector(west, duel_world),
		east.id: EvoEcologyInteraction.compute_effective_vector(east, duel_world)
	}
	var ext_energy := {west.id: 90.0, east.id: 90.0}
	EvoDemographyMigration.run_demography_and_migration_phase(duel_world, "en", init_pops, eff_vecs, {}, ext_energy)
	var budded_daughter: EvoTypes.Deme = null
	for did in duel_world.demes.keys():
		if did != "deme-rift-west" and did != "deme-rift-east":
			budded_daughter = duel_world.demes[did]
			break
	_assert(budded_daughter != null and budded_daughter.strategy_id == "strat-trade", "Colonist budding migration preserves parent strategy_id")

	var spec_world := EvoCatalog.create_preset_world("preset-darwin-archipelago", "en", "strat-expansion", "strat-war")
	spec_world.generation = 12
	var darwin_founder: EvoTypes.Deme = spec_world.demes["deme-darwin-founder"]
	(spec_world.cells[darwin_founder.hex_id] as EvoTypes.HexCell).deme_ids.erase(darwin_founder.id)
	darwin_founder.hex_id = "0,-2"
	(spec_world.cells["0,-2"] as EvoTypes.HexCell).deme_ids.append(darwin_founder.id)
	darwin_founder.isolation_turns = 10
	var spec_entries := EvoMilestonePhase.run_milestone_phase(spec_world, "en")
	_assert(not spec_entries.is_empty() and darwin_founder.strategy_id == "strat-expansion", "Allopatric speciation preserves deme strategy_id")
	_assert((spec_world.lineage_tree[darwin_founder.lineage_id] as EvoTypes.LineageNode).strategy_id == "strat-expansion", "Allopatric speciation child lineage preserves strategy_id")

	# 4. JSON persistence of custom user strategies and traits via EvoUserSettings
	var tmp_dir := "/tmp/evolution_test_catalog_%d" % Time.get_ticks_usec()
	var tmp_settings_path := tmp_dir.path_join("settings.json")
	EvoUserSettings.config_path_override = tmp_settings_path

	var custom_tr := EvoTypes.TraitDef.new()
	custom_tr.id = "bio-custom-carapace"
	custom_tr.name = "Chitinous Carapace"
	custom_tr.category = "biological"
	custom_tr.origin = "user"
	custom_tr.description = "Custom defensive adaptation."
	custom_tr.vector = EvoTypes.BiophysicalVector.new(0.15, 0.25, 0.05, 0.10, 0.20, 0.20)
	duel_world.traits_catalog[custom_tr.id] = custom_tr

	var custom_st := EvoTypes.StrategyDef.new()
	custom_st.id = "strat-custom-fortress"
	custom_st.name = "Fortress Doctrine"
	custom_st.description = "Custom defensive strategy."
	custom_st.icon = "🛡️"
	custom_st.color = "#14B8A6"
	custom_st.origin = "user"
	custom_st.biological_trait_ids = ["bio-k-strategy", "bio-social-instinct", "bio-custom-carapace"]
	custom_st.cultural_trait_ids = ["cul-communal-conservation"]
	duel_world.strategies_catalog[custom_st.id] = custom_st

	EvoUserSettings.save_user_catalog(duel_world)
	var catalog_json_path := EvoUserSettings.get_user_catalog_path()
	_assert(FileAccess.file_exists(catalog_json_path), "EvoUserSettings.save_user_catalog writes user_catalog.json")

	var fresh_state := EvoTypes.WorldState.new()
	fresh_state.traits_catalog = EvoCatalog.create_base_traits_catalog("en")
	fresh_state.decisions_catalog = EvoCatalog.create_base_decisions_catalog("en")
	fresh_state.strategies_catalog = EvoCatalog.create_base_strategies_catalog("en")
	EvoUserSettings.load_user_catalog_into(fresh_state)
	_assert(fresh_state.traits_catalog.has("bio-custom-carapace"), "load_user_catalog_into restores custom user trait")
	_assert(fresh_state.strategies_catalog.has("strat-custom-fortress"), "load_user_catalog_into restores custom user strategy")
	_assert((fresh_state.strategies_catalog["strat-custom-fortress"] as EvoTypes.StrategyDef).name == "Fortress Doctrine", "Restored custom user strategy preserves name and metadata")

	# 5. UI integration in EvoMainController, EvoMainHud & EvoLabModal
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	root.add_child(main)
	if main.camera == null:
		main._ready()
	main.hud._set_startup_blocked(false)

	var opt_a := main.hud.strategy_a_option
	var opt_b := main.hud.strategy_b_option
	_assert(opt_a != null and opt_b != null and opt_a.item_count >= 5 and opt_b.item_count >= 5, "HUD strategy_a_option and strategy_b_option populated with strategies")
	_assert(str(opt_a.get_item_metadata(opt_a.selected)) == main.world_state.strategy_a_id, "strategy_a_option selection reflects world_state.strategy_a_id")
	_assert(str(opt_b.get_item_metadata(opt_b.selected)) == main.world_state.strategy_b_id, "strategy_b_option selection reflects world_state.strategy_b_id")

	main.hud.open_lab_modal()
	var lab := main.hud.lab_modal
	lab._switch_tab("strategy")
	lab._start_new_item()
	var cb_k: CheckBox = lab.strategy_trait_checks["bio-k-strategy"]
	var cb_r: CheckBox = lab.strategy_trait_checks["bio-r-strategy"]
	cb_k.button_pressed = true
	cb_r.button_pressed = true
	_assert(cb_r.button_pressed and not cb_k.button_pressed, "Lab strategy trait checkboxes enforce mutual exclusion between bio-r-strategy and bio-k-strategy")

	lab.id_edit.text = "strat-custom-duelist"
	lab.name_edit.text = "Duelist Doctrine"
	lab._save_current_item()
	_assert(main.world_state.strategies_catalog.has("strat-custom-duelist"), "Saving custom strategy in Lab Modal adds it to strategies_catalog")

	main.set_matchup_strategies("strat-custom-duelist", "strat-trade")
	_assert(main.world_state.generation == 0 and main.world_state.strategy_a_id == "strat-custom-duelist" and main.world_state.strategy_b_id == "strat-trade", "set_matchup_strategies resets to Generation 0 with selected strategies")
	_assert((main.world_state.demes["deme-rift-west"] as EvoTypes.Deme).strategy_id == "strat-custom-duelist", "Founder deme A updated with custom strategy")

	main.step_generation()
	_assert(main.world_state.generation == 1, "Generation advances before reset_matchup")
	main.reset_matchup()
	_assert(main.world_state.generation == 0 and main.world_state.strategies_catalog.has("strat-custom-duelist") and main.world_state.strategy_a_id == "strat-custom-duelist", "reset_matchup resets to Generation 0 and preserves custom user strategies")

	main.hud.select_deme("deme-rift-west")
	_assert(main.hud.deme_strategy_label != null and "Duelist Doctrine" in main.hud.deme_strategy_label.text, "Inspector deme_strategy_label displays selected village strategy")

	main.free()
	if FileAccess.file_exists(catalog_json_path):
		DirAccess.remove_absolute(catalog_json_path)
	if FileAccess.file_exists(tmp_settings_path):
		DirAccess.remove_absolute(tmp_settings_path)
	if DirAccess.dir_exists_absolute(tmp_dir):
		DirAccess.remove_absolute(tmp_dir)
	EvoUserSettings.config_path_override = _suite_cfg_path


func _test_decision_model_and_normalization() -> void:
	print("-- Testing Decision Model & Normalization --")
	var ids: Array[String] = ["d1", "d2", "d3"]
	var raw := {"d1": 0.52, "d2": 0.31, "d3": 0.17}
	var norm := EvoDecisionModel.normalize_decision_probabilities(raw, ids)
	var probs: Dictionary = norm["probabilities"]
	var sum_p: float = 0.0
	for k in probs.keys():
		sum_p += float(probs[k])
	_assert(is_equal_approx(sum_p, 1.0), "Normalized probabilities sum to 1.0000")
	_assert(str(norm["dominant_decision_id"]) == "d1", "Dominant decision is d1")

	# Verify deterministic heuristic decision scorer has been completely removed
	var dm_inst := EvoDecisionModel.new()
	var hs_inst := EvoHeuristicScorer.new()
	_assert(not dm_inst.has_method("evaluate_deme_heuristic"), "EvoDecisionModel has no evaluate_deme_heuristic fallback")
	_assert(not hs_inst.has_method("evaluate_deme_heuristic"), "EvoHeuristicScorer has no evaluate_deme_heuristic fallback")

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
	_assert(west.last_dominant_decision_id == "dec-conservative-forage", "West forest deme applies Ollama System 1 decision")
	_assert(east.last_dominant_decision_id == "dec-cooperate-store", "East savanna deme applies Ollama System 1 decision")
	_assert("Ollama System 1" in west.last_justification, "Justification reflects live neural Ollama System 1 evaluation")
	EvoOllamaClient.clear_cache()


func _test_hawk_dove_and_symbiosis() -> void:
	print("-- Testing Hawk-Dove Dispute & Symbiosis --")
	var state := EvoCatalog.create_preset_world("preset-finite-island", "es")
	var d1: EvoTypes.Deme = state.demes["deme-island-1"]
	var d2: EvoTypes.Deme = state.demes["deme-island-2"]

	# Place both rival clans on adjacent hexes 0,0 and 1,0 under 1-deme-per-hex invariant
	(state.cells[d1.hex_id] as EvoTypes.HexCell).deme_ids.erase(d1.id)
	(state.cells[d2.hex_id] as EvoTypes.HexCell).deme_ids.erase(d2.id)
	d1.hex_id = "0,0"
	d2.hex_id = "1,0"
	(state.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([d1.id])
	(state.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([d2.id])
	var init_pop_1 := d1.population
	var init_pop_2 := d2.population

	# Force Hawk vs Hawk between d1 and d2
	d1.last_decision_probabilities = {"dec-territorial-dispute": 0.60, "dec-conservative-forage": 0.40}
	d2.last_decision_probabilities = {"dec-territorial-dispute": 0.60, "dec-conservative-forage": 0.40}
	EvoBiophysPhase.run_biophysical_phase(state, "es")

	var has_dispute_flow := false
	for fl in state.active_flows:
		if fl.flow_type == "dispute":
			has_dispute_flow = true
			break
	_assert(has_dispute_flow, "Hawk vs Hawk generates dispute flow")
	_assert(d1.population < init_pop_1 and d2.population < init_pop_2, "Hawks suffer casualties and metabolic penalty")

	# Force Symbiosis and Horizontal Cultural Diffusion between d1 and d2
	state.active_flows.clear()
	d1.cultural_trait_ids.assign(["cul-fire-processing"])
	d2.cultural_trait_ids.clear()
	d1.last_decision_probabilities = {"dec-exchange-symbiosis": 0.80, "dec-cooperate-store": 0.20}
	d2.last_decision_probabilities = {"dec-exchange-symbiosis": 0.80, "dec-cooperate-store": 0.20}
	EvoBiophysPhase.run_biophysical_phase(state, "es")
	_assert(d2.cultural_trait_ids.has("cul-fire-processing"), "Horizontal cultural diffusion transmitted cul-fire-processing to d2")


func _test_tragedy_of_the_commons() -> void:
	print("-- Testing Tragedy of the Commons --")
	var island := EvoCatalog.create_preset_world("preset-finite-island", "es")
	for did in island.demes.keys():
		var d: EvoTypes.Deme = island.demes[did]
		d.last_decision_probabilities = {"dec-intensive-overexploit": 0.65, "dec-territorial-dispute": 0.20, "dec-conservative-forage": 0.15}
		d.last_dominant_decision_id = "dec-intensive-overexploit"
	var tragedy_occurred := false
	var tragedy_hex_id := ""
	for _g in range(12):
		EvoTurnEngine.advance_generation(island, "es")
		for entry in island.chronicle:
			if entry.event_type == "tragedy_of_commons":
				tragedy_occurred = true
				tragedy_hex_id = entry.hex_id
				break
		if tragedy_occurred:
			break
	_assert(tragedy_occurred, "Finite Island without conservation triggers Tragedy of the Commons")
	var degraded_cell: EvoTypes.HexCell = island.cells[tragedy_hex_id] if island.cells.has(tragedy_hex_id) else island.cells["1,0"]
	_assert(degraded_cell.carrying_capacity < 0.60 * degraded_cell.carrying_capacity_max, "Overexploited cell K degraded below 60% of Kmax")


func _test_baldwin_innovation_and_speciation() -> void:
	print("-- Testing Baldwin Effect, Cultural Innovation & Allopatric Speciation --")
	# 1. Baldwin assimilation
	var state_b := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var east_b: EvoTypes.Deme = state_b.demes["deme-rift-east"]
	east_b.baldwin_counters["dec-cooperate-store"] = 8
	east_b.last_dominant_decision_id = "dec-cooperate-store"
	var entries_b := EvoMilestonePhase.run_milestone_phase(state_b, "es")
	_assert(entries_b.size() == 1 and entries_b[0].event_type == "baldwin_trait", "Baldwin assimilation triggers at counter >= 8")
	_assert(int(east_b.baldwin_counters["dec-cooperate-store"]) == 0, "Baldwin counter resets to 0 after assimilation")

	# 2. Cultural innovation & dec-explore-innovate eligibility
	var state_c := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var east_c: EvoTypes.Deme = state_c.demes["deme-rift-east"]
	east_c.cultural_trait_ids.clear()
	var innovate_dec: EvoTypes.DecisionDef = state_c.decisions_catalog["dec-explore-innovate"]
	_assert(EvoDecisionModel.is_decision_eligible(east_c, innovate_dec, state_c.traits_catalog), "dec-explore-innovate is eligible for deme with cultural capacity")
	var non_cultural_deme := east_c.duplicate_deme()
	non_cultural_deme.biological_trait_ids.assign(["bio-k-strategy"])
	_assert(not EvoDecisionModel.is_decision_eligible(non_cultural_deme, innovate_dec, state_c.traits_catalog), "dec-explore-innovate requires cultural capacity")

	east_c.innovation_counter = 1.15
	east_c.last_energy_delta = 5.0
	var entries_c := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	_assert(entries_c.size() == 1 and entries_c[0].event_type == "cultural_innovation", "Cultural innovation triggers at counter >= 1.0")
	_assert(east_c.cultural_trait_ids.size() == 1, "Deme acquires 1st newly synthesized cultural tradition")

	east_c.innovation_counter = 1.25
	east_c.last_energy_delta = 5.0
	var entries_c2 := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	_assert(entries_c2.size() == 1 and entries_c2[0].event_type == "cultural_innovation" and east_c.cultural_trait_ids.size() == 2, "Deme can acquire a 2nd emergent cultural trait (emergent_cul_count < 2)")

	east_c.innovation_counter = 1.25
	east_c.last_energy_delta = 5.0
	var entries_c3 := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	_assert(entries_c3.is_empty() and east_c.cultural_trait_ids.size() == 2, "Cultural innovation caps at 2 emergent cultural traits")

	# 3. Allopatric speciation
	var state_s := EvoCatalog.create_preset_world("preset-darwin-archipelago", "es")
	state_s.generation = 12
	var founder: EvoTypes.Deme = state_s.demes["deme-darwin-founder"]
	(state_s.cells[founder.hex_id] as EvoTypes.HexCell).deme_ids.erase(founder.id)
	founder.hex_id = "0,-2" # North tundra island
	(state_s.cells["0,-2"] as EvoTypes.HexCell).deme_ids.append(founder.id)
	founder.isolation_turns = 10
	var old_lineage := founder.lineage_id
	var old_color := founder.color
	var entries_s := EvoMilestonePhase.run_milestone_phase(state_s, "es")
	_assert(entries_s.size() == 1 and entries_s[0].event_type == "allopatric_speciation", "Allopatric speciation triggers at isolation >= 10 in distinct biome")
	_assert(founder.lineage_id != old_lineage, "Speciated deme receives new lineage ID")
	_assert(founder.color != old_color, "Speciated deme receives new distinct color")
	_assert(state_s.lineage_tree.size() == 3, "Lineage tree now has 3 nodes (2 initial + 1 speciated)")


func _test_kin_merge_fission_and_macro_outcome() -> void:
	print("-- Testing Kin Merge Flow Redirection, Fission Bottleneck & Macro-Outcome Trigger --")
	# 1. Kin merging redirects from_deme_id and to_deme_id without corrupting inter-hex flow recipients
	var state_m := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var deme_a: EvoTypes.Deme = state_m.demes["deme-rift-west"]
	var deme_c: EvoTypes.Deme = state_m.demes["deme-rift-east"]
	var deme_b := deme_a.duplicate_deme()
	deme_b.id = "deme-rift-west-m1"
	deme_b.name = "Clan Kin B"
	deme_b.hex_id = deme_a.hex_id
	deme_b.population = 45
	state_m.demes[deme_b.id] = deme_b
	(state_m.cells[deme_a.hex_id] as EvoTypes.HexCell).deme_ids.append(deme_b.id)

	var inter_flow := EvoTypes.HexEdgeFlow.new()
	inter_flow.from_hex_id = deme_b.hex_id
	inter_flow.to_hex_id = deme_c.hex_id
	inter_flow.flow_type = "exchange"
	inter_flow.from_deme_id = deme_b.id
	inter_flow.to_deme_id = deme_c.id
	state_m.active_flows.append(inter_flow)

	var initial_pops_m := {deme_a.id: deme_a.population, deme_b.id: deme_b.population, deme_c.id: deme_c.population}
	var eff_vecs_m := {}
	var ext_energy_m := {}
	for did in state_m.demes.keys():
		var d: EvoTypes.Deme = state_m.demes[did]
		eff_vecs_m[did] = EvoEcologyInteraction.compute_effective_vector(d, state_m)
		ext_energy_m[did] = float(d.population) * 0.60
		d.last_decision_probabilities = {"dec-conservative-forage": 1.0}
		d.last_dominant_decision_id = "dec-conservative-forage"

	EvoDemographyMigration.run_demography_and_migration_phase(state_m, "es", initial_pops_m, eff_vecs_m, {}, ext_energy_m)
	_assert(not state_m.demes.has(deme_b.id), "Kin deme_b merged into deme_a")
	var preserved_recipient := false
	for fl in state_m.active_flows:
		if fl.flow_type == "exchange" and fl.from_deme_id == deme_a.id and fl.to_deme_id == deme_c.id:
			preserved_recipient = true
			break
	_assert(preserved_recipient, "Kin merge redirects from_deme_id to deme_a without overwriting inter-hex recipient deme_c")

	# 2. Fission migration does not falsely trigger cultural_loss bottleneck on a healthy parent deme
	var state_f := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var parent_d: EvoTypes.Deme = state_f.demes["deme-rift-west"]
	parent_d.population = 60
	parent_d.energy_reserves = 120.0
	parent_d.cultural_trait_ids.assign(["cul-fire-processing"])
	parent_d.last_decision_probabilities = {"dec-selective-migration": 0.90, "dec-conservative-forage": 0.10}
	parent_d.last_dominant_decision_id = "dec-selective-migration"
	var init_pops_f := {parent_d.id: 60, "deme-rift-east": 140}
	var eff_vecs_f := {}
	var ext_energy_f := {}
	for did in state_f.demes.keys():
		var d: EvoTypes.Deme = state_f.demes[did]
		eff_vecs_f[did] = EvoEcologyInteraction.compute_effective_vector(d, state_f)
		ext_energy_f[did] = float(d.population) * 0.65
	EvoDemographyMigration.run_demography_and_migration_phase(state_f, "es", init_pops_f, eff_vecs_f, {}, ext_energy_f)
	var had_cultural_loss := false
	for entry in state_f.chronicle:
		if entry.event_type == "cultural_loss" and entry.deme_id == parent_d.id:
			had_cultural_loss = true
			break
	_assert(parent_d.population < 50 and parent_d.cultural_trait_ids.has("cul-fire-processing") and not had_cultural_loss, "Healthy parent deme dropping below 50 pop solely due to fission migration does not suffer false cultural_loss")

	# 3. has_macro_outcome only triggers on the turn the macro-outcome is logged, not on subsequent turns
	var state_mo := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	state_mo.quiet_turns = 11
	for did in state_mo.demes.keys():
		var d: EvoTypes.Deme = state_mo.demes[did]
		state_mo.previous_populations[did] = d.population
		var sig := EvoDecisionModel.compute_deme_evaluation_signature(d, state_mo)
		EvoOllamaClient.seed_signature_cache(sig, {
			"probabilities": {"dec-conservative-forage": 1.0},
			"dominant_decision_id": "dec-conservative-forage",
			"confidence": 0.90
		})
	var res_mo1 := EvoTurnEngine.advance_generation(state_mo, "es")
	# Force ecological_equilibrium on a predictable quiet state if population shifted by >5%
	if not bool(res_mo1["has_macro_outcome"]):
		state_mo.macro_outcome_type = "ecological_equilibrium"
		var eq_entry := EvoTypes.ChronicleEntry.new()
		eq_entry.id = "chronicle-equilibrium-test"
		eq_entry.generation = state_mo.generation
		eq_entry.event_type = "ecological_equilibrium"
		state_mo.chronicle.append(eq_entry)
	var res_mo2 := EvoTurnEngine.advance_generation(state_mo, "es")
	_assert(state_mo.macro_outcome_type != "" and not bool(res_mo2["has_macro_outcome"]), "has_macro_outcome is false on subsequent turns after macro-outcome was already logged")


func _test_interventions() -> void:
	print("-- Testing Player Interventions (Brushes) --")
	var state := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	state.selective_pressure_points = 100
	var targets: Array[String] = ["0,0"]

	var ok_biome := EvoTurnEngine.apply_set_biome(state, targets, "tundra", "es")
	var c0: EvoTypes.HexCell = state.cells["0,0"]
	var tundra_defs: Dictionary = EvoTypes.BIOME_CLIMATE_DEFAULTS["tundra"]
	_assert(ok_biome and c0.biome == "tundra", "set_biome changes cell biome to tundra")
	_assert(
		is_equal_approx(c0.seasonal_regen_rate, float(tundra_defs["regen"])) and is_equal_approx(c0.carrying_capacity_max, float(tundra_defs["k_max"])),
		"set_biome updates seasonal_regen_rate and carrying_capacity_max from BIOME_CLIMATE_DEFAULTS"
	)
	_assert(state.selective_pressure_points == 90, "set_biome costs 10 points")

	var ok_alt := EvoTurnEngine.apply_adjust_altitude(state, targets, 0.18, "es")
	_assert(ok_alt and state.selective_pressure_points == 75, "adjust_altitude costs 15 points")

	var ok_cap := EvoTurnEngine.apply_adjust_carrying_capacity(state, targets, 0.25)
	_assert(ok_cap and state.selective_pressure_points == 65, "adjust_carrying_capacity costs 10 points")

	var prev_sea := state.sea_level
	var ok_sea := EvoTurnEngine.apply_adjust_sea_level(state, 0.05, "es")
	_assert(ok_sea and is_equal_approx(state.sea_level, prev_sea + 0.05), "adjust_sea_level raises sea level by 0.05")
	_assert(state.selective_pressure_points == 40, "adjust_sea_level costs 25 points")


func _test_serialization_roundtrip() -> void:
	print("-- Testing JSON Serialization Round-Trip --")
	var state := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	EvoTurnEngine.advance_generation(state, "es")
	state.recent_extinction_hexes.assign(["1,-1"])
	state.disused_connections.append({
		"from_hex_id": "-1,0",
		"to_hex_id": "1,0",
		"from_deme_id": "deme-rift-west",
		"to_deme_id": "deme-rift-east",
		"flow_type": "exchange",
		"age": 2
	})
	state.previous_populations["deme-rift-west"] = 177
	var json_str := JSON.stringify(state.to_dict())
	var parsed: Variant = JSON.parse_string(json_str)
	_assert(typeof(parsed) == TYPE_DICTIONARY, "Serialized state parses back as Dictionary")
	var restored := EvoTypes.WorldState.from_dict(parsed as Dictionary)
	_assert(restored.generation == state.generation, "Restored generation matches")
	_assert(restored.cells.size() == state.cells.size(), "Restored cells count matches")
	_assert(restored.demes.size() == state.demes.size(), "Restored demes count matches")
	_assert(restored.recent_extinction_hexes == state.recent_extinction_hexes, "Restored recent_extinction_hexes matches")
	_assert(restored.disused_connections.size() == 1 and int(restored.disused_connections[0]["age"]) == 2, "Restored disused_connections matches")
	_assert(int(restored.previous_populations.get("deme-rift-west", 0)) == 177, "Restored previous_populations matches")


func _test_25_generations_all_presets() -> void:
	print("-- Testing 25 Generations Across All 3 Presets --")
	var mock_model_entry := {
		"probabilities": {
			"dec-conservative-forage": 0.50,
			"dec-cooperate-store": 0.30,
			"dec-selective-migration": 0.20
		},
		"dominant_decision_id": "dec-conservative-forage",
		"confidence": 0.85
	}
	for preset_id in EvoCatalog.PRESET_IDS:
		var state := EvoCatalog.create_preset_world(preset_id, "es")
		for _g in range(25):
			for did in state.demes.keys():
				var d: EvoTypes.Deme = state.demes[did]
				var sig := EvoDecisionModel.compute_deme_evaluation_signature(d, state)
				EvoOllamaClient.seed_signature_cache(sig, mock_model_entry)
				d.last_decision_probabilities = (mock_model_entry["probabilities"] as Dictionary).duplicate()
				d.last_dominant_decision_id = str(mock_model_entry["dominant_decision_id"])
			EvoTurnEngine.advance_generation(state, "es")
		_assert(state.generation == 25, "%s reached generation 25 cleanly" % preset_id)
		for did in state.demes.keys():
			var deme: EvoTypes.Deme = state.demes[did]
			var sum_p: float = 0.0
			for p in deme.last_decision_probabilities.values():
				sum_p += float(p)
			_assert(is_equal_approx(sum_p, 1.0), "%s deme %s probabilities sum to 1.0 at G25" % [preset_id, did])


func _test_main_scene_and_ui_integration() -> void:
	print("-- Testing Main Scene, WorldRenderer & UI Integration --")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_assert(packed != null, "res://scenes/main.tscn loads as PackedScene")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	root.add_child(main)
	if main.camera == null:
		main._ready()

	_assert(main.camera != null, "main.camera exists and is configured")
	_assert(main.world_renderer != null, "main.world_renderer exists and is configured")
	_assert(main.hud != null, "main.hud exists and is configured")
	_assert(main.world_state != null, "main.world_state initialized on startup")

	# Verify all 52 PNG files in res://assets/sprites/ and ImageTexture generation
	EvoPixelArtGen.ensure_all_assets()
	var total_sprites: int = 0
	for s_name in EvoPixelArtGen.TERRAIN_SPRITES:
		var path := "res://assets/sprites/terrain/%s.png" % s_name
		_assert(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "Terrain PNG exists: %s" % path)
		var tex := EvoPixelArtGen.get_texture(s_name)
		_assert(tex != null and tex.get_width() > 0, "Valid ImageTexture for %s" % s_name)
		total_sprites += 1
	for s_name in EvoPixelArtGen.VILLAGE_SPRITES:
		var path := "res://assets/sprites/villages/%s.png" % s_name
		_assert(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "Village PNG exists: %s" % path)
		var tex := EvoPixelArtGen.get_texture(s_name)
		_assert(tex != null and tex.get_width() > 0, "Valid ImageTexture for %s" % s_name)
		total_sprites += 1
	for s_name in EvoPixelArtGen.UI_SPRITES:
		var path := "res://assets/sprites/ui/%s.png" % s_name
		_assert(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "UI PNG exists: %s" % path)
		var tex := EvoPixelArtGen.get_texture(s_name)
		_assert(tex != null and tex.get_width() > 0, "Valid ImageTexture for %s" % s_name)
		total_sprites += 1
	var expected_sprites := EvoPixelArtGen.TERRAIN_SPRITES.size() + EvoPixelArtGen.VILLAGE_SPRITES.size() + EvoPixelArtGen.UI_SPRITES.size()
	_assert(total_sprites == expected_sprites and total_sprites >= 60, "All %d pixel-art sprites verified" % total_sprites)

	# Verify Dual System 1 Decision Models (d3:4b + tev1:4b), Settings Persistence & Dynamic UI Text
	EvoUserSettings.config_path_override = ""
	_assert(EvoUserSettings.get_config_dir().ends_with("/.config/Evolution"), "Default config dir points to ~/.config/Evolution")
	EvoUserSettings.config_path_override = _suite_cfg_path
	_assert(EvoUserSettings.DEFAULT_CONTEXT_LENGTH == 8192, "Default context window size is 8192")
	_assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-rift-west") == "d3:4b", "deme-rift-west assigned to d3:4b")
	_assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-rift-east") == "tev1:4b", "deme-rift-east assigned to tev1:4b")
	_assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-island-1") == "d3:4b", "deme-island-1 assigned to d3:4b")
	_assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-island-2") == "tev1:4b", "deme-island-2 assigned to tev1:4b")
	var ollama_status := EvoDecisionModel.check_ollama_status()
	_assert(ollama_status.has("primary_tag") and ollama_status["primary_tag"] == "d3:4b", "Ollama status reports primary System 1 model d3:4b")
	_assert(ollama_status.has("secondary_tag") and ollama_status["secondary_tag"] == "tev1:4b", "Ollama status reports secondary System 1 model tev1:4b")

	var mock_tags := [
		{"name": "d3:4b", "capabilities": ["decision", "vision"]},
		{"name": "tev1:4b", "capabilities": ["decision"]},
		{"name": "embeddinggemma:latest", "capabilities": ["embedding"]}
	]
	var filtered_dec := EvoOllamaClient.filter_decision_models_from_tags(mock_tags)
	_assert(filtered_dec.size() == 2 and filtered_dec.has("d3:4b") and filtered_dec.has("tev1:4b"), "filter_decision_models_from_tags returns only models with 'decision' capability")

	var test_cfg_path := ProjectSettings.globalize_path("user://test_evolution_settings.json")
	EvoUserSettings.config_path_override = test_cfg_path
	EvoUserSettings.primary_model = "custom-dec-a:4b"
	EvoUserSettings.secondary_model = "custom-dec-b:4b"
	main.hud._commit_context_window_text("16384")
	_assert(FileAccess.file_exists(test_cfg_path), "Settings file saved on change")
	EvoUserSettings.primary_model = "d3:4b"
	EvoUserSettings.secondary_model = "tev1:4b"
	EvoUserSettings.context_length = 8192
	EvoUserSettings.load_settings()
	_assert(EvoUserSettings.primary_model == "custom-dec-a:4b" and EvoUserSettings.secondary_model == "custom-dec-b:4b" and EvoUserSettings.context_length == 16384, "Settings round-trip loads custom models and free-text context window 16384")
	main.hud._apply_decision_models_update()
	_assert("custom-dec-a:4b" in main.hud._models_diag_lbl.text and "custom-dec-b:4b" in main.hud._models_diag_lbl.text and "16384" in main.hud._models_diag_lbl.text, "HUD diagnostic card updates dynamically with active models and context window")
	_assert("custom-dec-a:4b" in main.hud._settings_btn.tooltip_text and "custom-dec-b:4b" in main.hud._settings_btn.tooltip_text, "Settings button tooltip updates dynamically when models change")
	var quit_signals: Array[int] = [0]
	main.hud.quit_requested.connect(func() -> void: quit_signals[0] += 1)

	# Verify Ollama Offline blocking popup prevents starting the game and closes app when dismissed
	EvoHudBannersToasts.show_ollama_offline_popup(main.hud)
	_assert(main.hud._missing_models_modal.visible and main.hud._ollama_startup_blocked, "Ollama offline popup is visible and blocks startup")
	_assert(main.hud._play_btn.disabled and main.hud._step_btn.disabled, "Play and Step buttons are disabled when Ollama is offline")
	_assert(not main.hud._missing_models_download_btn.visible, "Download button is hidden when Ollama is offline")
	var blocked_gen := main.world_state.generation
	main.hud._on_play_pressed()
	main.step_generation()
	_assert(not main.is_playing and main.world_state.generation == blocked_gen, "Game cannot start or advance generation while Ollama is offline")
	main.hud._on_missing_models_skip_pressed()
	_assert(not main.hud._missing_models_modal.visible and quit_signals[0] == 1, "Closing Ollama offline popup emits quit_requested to close the application")

	# Verify Missing Models popup also blocks startup and closes app if dismissed without downloading
	EvoHudBannersToasts.show_missing_models_popup(main.hud, ["missing-dec:4b"])
	_assert(main.hud._missing_models_modal.visible and "missing-dec:4b" in main.hud._missing_models_desc_lbl.text, "Missing models popup displays missing model tags at startup")
	_assert(main.hud._ollama_startup_blocked and main.hud._play_btn.disabled and main.hud._step_btn.disabled, "Missing models popup blocks game startup until downloaded")
	main.hud._on_missing_models_skip_pressed()
	_assert(not main.hud._missing_models_modal.visible and quit_signals[0] == 2, "Closing missing models popup emits quit_requested")

	# Unblock startup for subsequent UI interaction tests
	main.hud._set_startup_blocked(false)
	DirAccess.remove_absolute(test_cfg_path)
	EvoUserSettings.config_path_override = _suite_cfg_path
	EvoUserSettings.primary_model = EvoUserSettings.DEFAULT_PRIMARY_MODEL
	EvoUserSettings.secondary_model = EvoUserSettings.DEFAULT_SECONDARY_MODEL
	EvoUserSettings.context_length = EvoUserSettings.DEFAULT_CONTEXT_LENGTH
	main.hud._apply_decision_models_update()

	# Advance generations via main.step_generation()
	var gen_before := main.world_state.generation
	main.step_generation()
	main.step_generation()
	_assert(main.world_state.generation == gen_before + 2, "main.step_generation() advances world_state generation")
	_assert(main.world_renderer.world_state == main.world_state, "world_renderer tracks updated world_state")

	# Preset switching
	main.load_preset("preset-darwin-archipelago")
	_assert(main.world_state.preset_id == "preset-darwin-archipelago", "Switched to preset-darwin-archipelago")
	_assert(main.world_state.cells.size() == 169, "Darwin preset has 169 cells in main")
	main.step_generation()

	main.load_preset("preset-finite-island")
	_assert(main.world_state.preset_id == "preset-finite-island", "Switched to preset-finite-island")
	_assert(main.world_state.cells.size() == 169, "Finite Island preset has 169 cells in main")
	main.step_generation()

	# Language switching
	main._on_language_changed("en")
	_assert(main.lang == "en", "Language switched to en")
	main._on_language_changed("es")
	_assert(main.lang == "es", "Language switched back to es")

	# Map lenses switching
	for lens_id in ["food", "health", "biome"]:
		main.hud._on_lens_pressed(lens_id)
		_assert(main.world_renderer.active_lens == lens_id, "Lens switched to %s" % lens_id)

	# Modals opening and closing
	main.hud.open_notebook_modal()
	_assert(main.hud.notebook_modal.visible, "Notebook modal opens cleanly")
	main.hud.notebook_modal.close_modal()
	_assert(not main.hud.notebook_modal.visible, "Notebook modal closes cleanly")

	main.hud.open_tree_modal()
	_assert(main.hud.tree_modal.visible, "Tree modal opens cleanly")
	main.hud.tree_modal.close_modal()
	_assert(not main.hud.tree_modal.visible, "Tree modal closes cleanly")

	main.hud.open_lab_modal()
	_assert(main.hud.lab_modal.visible, "Lab modal opens cleanly")
	main.hud.lab_modal.close_modal()
	_assert(not main.hud.lab_modal.visible, "Lab modal closes cleanly")

	# Environmental tools via HUD and MainController
	main.world_state.selective_pressure_points = 100
	main.hud._on_tool_button_pressed("set_biome")
	main.hud._on_sub_mode_selected("tundra")
	main._on_world_hex_clicked("0,0", MOUSE_BUTTON_LEFT)
	_assert((main.world_state.cells["0,0"] as EvoTypes.HexCell).biome == "tundra", "Environmental tool set_biome applied via main controller")

	main.hud._on_tool_button_pressed("adjust_altitude")
	main.hud._on_sub_mode_selected("raise")
	var alt_before := (main.world_state.cells["0,0"] as EvoTypes.HexCell).altitude
	main._on_world_hex_clicked("0,0", MOUSE_BUTTON_LEFT)
	_assert((main.world_state.cells["0,0"] as EvoTypes.HexCell).altitude > alt_before, "Environmental tool adjust_altitude applied via main controller")

	main.hud._on_tool_button_pressed("adjust_carrying_capacity")
	main.hud._on_sub_mode_selected("enrich")
	main._on_world_hex_clicked("0,0", MOUSE_BUTTON_LEFT)

	var sea_before := main.world_state.sea_level
	main._on_sea_level_change_requested(0.05)
	_assert(is_equal_approx(main.world_state.sea_level, sea_before + 0.05), "Sea level tool applied via main controller")

	# Verify Expanded Hex Size (>= 220.0), >= 2x Village/Villager Scales & Lifecycle Anti-Overlap
	_assert(HexMath.HEX_SIZE >= 220.0, "HexMath.HEX_SIZE expanded to >= 220.0 (is %.1f)" % HexMath.HEX_SIZE)
	var b_layout := main.world_renderer._get_village_building_layout(2, 1.0, true, 2, "cooperate")
	_assert(b_layout.size() >= 3 and float(b_layout[0]["scale"]) >= 2.0, "Village building scale is >= 2.0x baseline")
	main.load_preset("preset-rift-savanna")
	main.world_renderer._rebuild()
	var moving_props := main.world_renderer._collect_moving_props()
	_assert(not moving_props.is_empty() and moving_props[0].rect.size.y >= 28.0, "Inhabitant/campfire moving props are >= 2x baseline size")

	# Verify disused_connections lifecycle aging and HUD inspector zero-information-loss
	var life_state := EvoCatalog.create_preset_world("preset-finite-island", "es")
	var ld1: EvoTypes.Deme = life_state.demes["deme-island-1"]
	var ld2: EvoTypes.Deme = life_state.demes["deme-island-2"]
	(life_state.cells[ld1.hex_id] as EvoTypes.HexCell).deme_ids.erase(ld1.id)
	(life_state.cells[ld2.hex_id] as EvoTypes.HexCell).deme_ids.erase(ld2.id)
	ld1.hex_id = "0,0"
	ld2.hex_id = "1,0"
	(life_state.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([ld1.id])
	(life_state.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([ld2.id])
	var coop_fl := EvoTypes.HexEdgeFlow.new()
	coop_fl.from_hex_id = "0,0"
	coop_fl.to_hex_id = "1,0"
	coop_fl.flow_type = "cooperate"
	coop_fl.from_deme_id = "deme-island-1"
	coop_fl.to_deme_id = "deme-island-2"
	life_state.active_flows.append(coop_fl)
	EvoEnvPhase.run_environmental_phase(life_state, "es")
	_assert(life_state.disused_connections.size() == 1 and int(life_state.disused_connections[0].get("age", -1)) == 0, "Active friendly flow recorded into disused_connections with age 0")
	# Force dispute so the friendly flow is severed
	ld1.last_decision_probabilities = {"dec-territorial-dispute": 0.90, "dec-conservative-forage": 0.10}
	ld2.last_decision_probabilities = {"dec-territorial-dispute": 0.90, "dec-conservative-forage": 0.10}
	EvoBiophysPhase.run_biophysical_phase(life_state, "es")
	_assert(life_state.disused_connections.size() == 1 and int(life_state.disused_connections[0].get("age", 0)) == 1, "Severed friendly flow ages to 1 in biophys_phase")
	main.hud.set_world_state(life_state)
	var rel_lines := main.hud._build_deme_relations_lines(ld1)
	_assert(rel_lines.size() >= 1, "HUD inspector preserves active/severed inter-hex relations without information loss")

	# Verify Right Inspector Village Selector & Cycling
	_assert(main.hud._village_selector_opt != null and main.hud._village_selector_opt.item_count == life_state.demes.size(), "Right Inspector village selector populated with all demes")
	var prev_sel_deme := main.hud._selected_deme_id
	main.hud._on_village_cycle_pressed(1)
	_assert(main.hud._selected_deme_id != prev_sel_deme, "Right Inspector village cycle button advances selected village")

	# Verify clicking an empty hex in inspect mode clears selected deme and switches inspector tab to habitat
	main.load_preset("preset-rift-savanna")
	main.hud._on_tool_button_pressed("inspect")
	var empty_hex_id := ""
	for hid in main.world_state.cells.keys():
		if (main.world_state.cells[hid] as EvoTypes.HexCell).deme_ids.is_empty():
			empty_hex_id = str(hid)
			break
	main._on_world_hex_clicked(empty_hex_id, MOUSE_BUTTON_LEFT)
	_assert(main.world_renderer.selected_deme_id == "" and main.hud._selected_deme_id == "" and main.hud._inspector_tab == "habitat", "Clicking empty hex in inspect mode clears selected deme and switches inspector tab to habitat")

	main.free()


func _test_nonblocking_async_decision_and_smooth_panning() -> void:
	print("-- Testing Non-Blocking Async Decision Model & Smooth Late-Game Panning --")
	var t0_usec := Time.get_ticks_usec()
	var status := EvoDecisionModel.check_ollama_status(true)
	var status_ms := float(Time.get_ticks_usec() - t0_usec) / 1000.0
	_assert(status.has("primary_tag") and status.has("secondary_tag"), "check_ollama_status(true) returns valid status dictionary immediately")
	_assert(status_ms < 15.0, "check_ollama_status(true) is non-blocking on main thread (took %.3f ms)" % status_ms)

	# Build a late-game world with 16 diverse demes across different hexes and live models enabled
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	root.add_child(main)
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

	_assert(state.demes.size() >= 16, "Late-game stress world populated with %d demes" % state.demes.size())

	var eval_start_usec := Time.get_ticks_usec()
	EvoDecisionModel.evaluate_all_demes(state, "es")
	var eval_ms := float(Time.get_ticks_usec() - eval_start_usec) / 1000.0
	_assert(eval_ms < 15.0, "evaluate_all_demes with 16 demes & live models enabled is non-blocking (took %.3f ms)" % eval_ms)

	# Simulate 6 generations of continuous camera panning + turn progression + rendering rebuilds
	main.world_renderer.refresh()
	main.world_renderer._process(0.016)
	_assert(not main.world_renderer._column_state_cache.is_empty(), "WorldRenderer column visual state cache populated")
	_assert(not main.world_renderer._cell_flora_cache.is_empty(), "WorldRenderer static flora prop cache populated")

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
	_assert(max_step_and_frame_ms < 25.0, "Turn step + renderer rebuild while panning with 16+ demes completes without stutter (max %.3f ms)" % max_step_and_frame_ms)

	# Verify zoom pivot invariance around cursor offset and outer-ring pan reachability at MAX_ZOOM
	main.camera.reset_camera()
	main.camera.pan_offset = main.camera._target_pan
	main.camera.zoom_level = main.camera._target_zoom
	var cursor_offset := Vector2(320.0, -180.0)
	var world_pt_before := (cursor_offset - main.camera._target_pan) / main.camera._target_zoom
	main.camera.zoom_by(0.45, cursor_offset)
	var world_pt_after := (cursor_offset - main.camera._target_pan) / main.camera._target_zoom
	_assert(world_pt_before.distance_to(world_pt_after) < 0.01, "Zoom around cursor pivot preserves exact world point under cursor")

	main.camera._target_zoom = EvoCameraController.MAX_ZOOM
	main.camera.focus_on_hex(5, 0, 0.5)
	_assert(main.camera._target_pan.length() > 5000.0, "Outer ring hexes are reachable at MAX_ZOOM without premature clamping")

	# Verify bounded deme.id length across migrations
	var max_id_len: int = 0
	for did in state.demes.keys():
		max_id_len = maxi(max_id_len, str(did).length())
	_assert(max_id_len < 64, "Deme IDs remain compact and bounded across generations (max len %d)" % max_id_len)

	main.free()


func _test_emergent_geopolitics_and_visual_artifacts() -> void:
	print("-- Testing Emergent Biophysical Geopolitics, Pacts, Raids, Betrayals, War & Visual Artifacts --")
	# 1. Strategy baseline probability differentiation & environmental weight modulation
	var state_base := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	var sample_deme: EvoTypes.Deme = state_base.demes["deme-rift-west"]

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-war", "en")
	_assert(sample_deme.last_dominant_decision_id == "dec-territorial-dispute", "strat-war baseline dominant decision is dec-territorial-dispute")
	var war_base_disp := float(sample_deme.last_decision_probabilities.get("dec-territorial-dispute", 0.0))

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-cooperation", "en")
	_assert(sample_deme.last_dominant_decision_id == "dec-cooperate-store", "strat-cooperation baseline dominant decision is dec-cooperate-store")

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-trade", "en")
	_assert(sample_deme.last_dominant_decision_id == "dec-exchange-symbiosis", "strat-trade baseline dominant decision is dec-exchange-symbiosis")

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-expansion", "en")
	_assert(sample_deme.last_dominant_decision_id == "dec-selective-migration", "strat-expansion baseline dominant decision is dec-selective-migration")

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-innovation", "en")
	_assert(sample_deme.last_dominant_decision_id == "dec-explore-innovate", "strat-innovation baseline dominant decision is dec-explore-innovate")
	_assert(war_base_disp > float(sample_deme.last_decision_probabilities.get("dec-territorial-dispute", 0.0)), "strat-war has higher baseline dispute weight than strat-innovation")

	# 2. Non-forcing of conflict in ecological abundance vs scarcity modulation
	var state_ab := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	state_ab.season = "wet_warm"
	var ab_w: EvoTypes.Deme = state_ab.demes["deme-rift-west"]
	var ab_e: EvoTypes.Deme = state_ab.demes["deme-rift-east"]
	(state_ab.cells[ab_w.hex_id] as EvoTypes.HexCell).deme_ids.erase(ab_w.id)
	(state_ab.cells[ab_e.hex_id] as EvoTypes.HexCell).deme_ids.erase(ab_e.id)
	ab_w.hex_id = "0,0"
	ab_e.hex_id = "1,0"
	(state_ab.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(ab_w.id)
	(state_ab.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(ab_e.id)
	for cid in ["0,0", "1,0"]:
		var c_ab: EvoTypes.HexCell = state_ab.cells[cid]
		c_ab.carrying_capacity = c_ab.carrying_capacity_max
		c_ab.current_resources = c_ab.carrying_capacity_max
	ab_w.population = 35
	ab_e.population = 35
	ab_w.energy_reserves = 90.0
	ab_e.energy_reserves = 90.0
	EvoHeuristicScorer.modulate_deme_probabilities_for_turn(ab_w, state_ab.cells["0,0"], state_ab)
	EvoHeuristicScorer.modulate_deme_probabilities_for_turn(ab_e, state_ab.cells["1,0"], state_ab)
	var ab_disp_w := float(ab_w.last_decision_probabilities.get("dec-territorial-dispute", 0.0))
	_assert(ab_w.last_dominant_decision_id != "dec-territorial-dispute", "In ecological abundance, strat-war does not default to territorial dispute")
	_assert(ab_e.last_dominant_decision_id in ["dec-conservative-forage", "dec-cooperate-store"], "In ecological abundance, strat-cooperation favors peaceful foraging/storage")
	EvoBiophysPhase.run_biophysical_phase(state_ab, "en")
	var ab_conflicts := 0
	for fl in state_ab.active_flows:
		if fl.flow_type in ["war", "raid", "betrayal"]:
			ab_conflicts += 1
	_assert(ab_conflicts == 0, "Zero wars, raids, or betrayals occur during ecological abundance")

	# Induce scarcity and verify dispute weight rises for martial deme
	state_ab.season = "dry_cold"
	(state_ab.cells["0,0"] as EvoTypes.HexCell).current_resources = 20.0
	ab_w.energy_reserves = 20.0
	ab_w.population = 75
	EvoCatalog.compute_strategy_baseline_probabilities(ab_w, state_ab.traits_catalog)
	EvoHeuristicScorer.modulate_deme_probabilities_for_turn(ab_w, state_ab.cells["0,0"], state_ab)
	var sc_disp_w := float(ab_w.last_decision_probabilities.get("dec-territorial-dispute", 0.0))
	_assert(sc_disp_w > ab_disp_w, "Environmental scarcity + surplus neighbor increases martial dispute probability (%.3f > %.3f)" % [sc_disp_w, ab_disp_w])

	# 3. Active Pact (pact) formation, caloric risk-pooling transfer & collective defense bonus
	var state_pact := EvoPresets.create_preset_world("preset-finite-island", "en", "strat-cooperation", "strat-trade")
	var p_d1: EvoTypes.Deme = state_pact.demes["deme-island-1"]
	var p_d2: EvoTypes.Deme = state_pact.demes["deme-island-2"]
	(state_pact.cells[p_d2.hex_id] as EvoTypes.HexCell).deme_ids.erase(p_d2.id)
	p_d2.hex_id = "0,-1"
	(state_pact.cells["0,-1"] as EvoTypes.HexCell).deme_ids.append(p_d2.id)
	for turn_i in range(2):
		p_d1.last_decision_probabilities = {"dec-cooperate-store": 0.70, "dec-conservative-forage": 0.30}
		p_d2.last_decision_probabilities = {"dec-exchange-symbiosis": 0.70, "dec-conservative-forage": 0.30}
		EvoBiophysPhase.run_biophysical_phase(state_pact, "en")
	_assert(EvoTypes.is_pact_active(state_pact, p_d1.id, p_d2.id), "Active pact forms after 2 consecutive cooperative/exchange turns")
	var has_pact_chronicle := false
	for e in state_pact.chronicle:
		if e.event_type == "pact":
			has_pact_chronicle = true
			break
	_assert(has_pact_chronicle, "Chronicle logs formal pact event on turn 2")
	var has_pact_flow := false
	for fl in state_pact.active_flows:
		if fl.flow_type == "pact":
			has_pact_flow = true
			break
	_assert(has_pact_flow, "Active pact emits 'pact' HexEdgeFlow")
	var def_bonus := EvoEcologyInteraction.compute_pact_defense_bonus(p_d1, state_pact)
	_assert(def_bonus > 0.15, "Active pact provides mutual defense bonus (%.2f)" % def_bonus)

	# Caloric risk-pooling during scarcity
	state_pact.season = "dry_cold"
	p_d1.energy_reserves = 20.0
	p_d2.energy_reserves = 130.0
	(state_pact.cells[p_d1.hex_id] as EvoTypes.HexCell).current_resources = 30.0
	(state_pact.cells[p_d2.hex_id] as EvoTypes.HexCell).current_resources = 500.0
	p_d1.last_decision_probabilities = {"dec-cooperate-store": 0.75, "dec-conservative-forage": 0.25}
	p_d2.last_decision_probabilities = {"dec-exchange-symbiosis": 0.75, "dec-conservative-forage": 0.25}
	var pact_vecs := {
		p_d1.id: EvoEcologyInteraction.compute_effective_vector(p_d1, state_pact),
		p_d2.id: EvoEcologyInteraction.compute_effective_vector(p_d2, state_pact)
	}
	var pact_hawks := {p_d1.id: 1.0, p_d2.id: 1.0}
	var pact_ext := {p_d1.id: 0.0, p_d2.id: 0.0}
	var pact_geo_flows: Array[EvoTypes.HexEdgeFlow] = []
	EvoEcologyInteraction.run_resource_and_symbiosis_phase(state_pact, "en", pact_vecs, pact_hawks, pact_ext, pact_geo_flows)
	_assert(p_d1.energy_reserves > 20.0 and p_d2.energy_reserves < 130.0, "Pact risk-pooling transfers reserves from wealthy ally to distressed ally (%.1f, %.1f)" % [p_d1.energy_reserves, p_d2.energy_reserves])
	_assert(not pact_geo_flows.is_empty(), "Ecology phase populates turn_geopolitical_flows")

	# 4. Opportunistic Betrayal (betrayal) under severe environmental stress
	var state_bet := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var b_d1: EvoTypes.Deme = state_bet.demes["deme-rift-west"]
	var b_d2: EvoTypes.Deme = state_bet.demes["deme-rift-east"]
	(state_bet.cells[b_d1.hex_id] as EvoTypes.HexCell).deme_ids.erase(b_d1.id)
	(state_bet.cells[b_d2.hex_id] as EvoTypes.HexCell).deme_ids.erase(b_d2.id)
	b_d1.hex_id = "0,0"
	b_d2.hex_id = "1,0"
	(state_bet.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(b_d1.id)
	(state_bet.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(b_d2.id)
	var bet_pk := EvoTypes.make_pair_key(b_d1.id, b_d2.id)
	state_bet.active_pacts[bet_pk] = 3
	state_bet.season = "dry_cold"
	(state_bet.cells["0,0"] as EvoTypes.HexCell).current_resources = 12.0
	(state_bet.cells["0,0"] as EvoTypes.HexCell).carrying_capacity = 75.0
	b_d1.energy_reserves = 16.0
	b_d2.energy_reserves = 135.0
	var b2_pop_before := b_d2.population
	b_d1.cultural_trait_ids.assign(["cul-warrior-expansion", "cul-extraction-tools"])
	b_d1.last_decision_probabilities = {
		"dec-territorial-dispute": 0.50,
		"dec-intensive-overexploit": 0.35,
		"dec-conservative-forage": 0.15
	}
	b_d2.last_decision_probabilities = {"dec-cooperate-store": 0.70, "dec-conservative-forage": 0.30}
	var bet_vecs := {
		b_d1.id: EvoEcologyInteraction.compute_effective_vector(b_d1, state_bet),
		b_d2.id: EvoEcologyInteraction.compute_effective_vector(b_d2, state_bet)
	}
	var bet_hawks := {b_d1.id: 1.0, b_d2.id: 1.0}
	var bet_ext := {b_d1.id: 0.0, b_d2.id: 0.0}
	var bet_geo_flows: Array[EvoTypes.HexEdgeFlow] = []
	EvoEcologyInteraction.run_resource_and_symbiosis_phase(state_bet, "en", bet_vecs, bet_hawks, bet_ext, bet_geo_flows)
	_assert(not EvoTypes.is_pact_active(state_bet, b_d1.id, b_d2.id), "Betrayal erases active pact from state.active_pacts")
	_assert(b_d1.energy_reserves > 16.0 and b_d2.energy_reserves < 135.0, "Betrayal plunders surprise loot from victim reserves to betrayer")
	_assert(b_d2.population < b2_pop_before, "Betrayal inflicts surprise casualties on victim")
	_assert(not state_bet.disused_connections.is_empty() and int(state_bet.disused_connections[0].get("age", 0)) >= 1, "Betrayal records severed road in state.disused_connections")
	var has_betrayal_flow := false
	for fl in state_bet.active_flows:
		if fl.flow_type == "betrayal":
			has_betrayal_flow = true
			break
	_assert(has_betrayal_flow, "Betrayal emits 'betrayal' HexEdgeFlow")
	var has_betrayal_chronicle := false
	for e in state_bet.chronicle:
		if e.event_type == "betrayal":
			has_betrayal_chronicle = true
			break
	_assert(has_betrayal_chronicle, "Betrayal logs 'betrayal' ChronicleEntry")

	# 5. Cross-border Raid (raid) under resource scarcity against a wealthy neighbor
	var state_raid := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var r_att: EvoTypes.Deme = state_raid.demes["deme-rift-west"]
	var r_vic: EvoTypes.Deme = state_raid.demes["deme-rift-east"]
	(state_raid.cells[r_att.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_att.id)
	(state_raid.cells[r_vic.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_vic.id)
	r_att.hex_id = "0,0"
	r_vic.hex_id = "1,0"
	(state_raid.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(r_att.id)
	(state_raid.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(r_vic.id)
	state_raid.season = "dry_cold"
	(state_raid.cells["0,0"] as EvoTypes.HexCell).current_resources = 20.0
	(state_raid.cells["1,0"] as EvoTypes.HexCell).current_resources = 260.0
	r_att.population = 75
	r_att.energy_reserves = 24.0
	r_vic.population = 45
	r_vic.energy_reserves = 115.0
	r_att.last_decision_probabilities = {}
	r_vic.last_decision_probabilities = {}
	EvoBiophysPhase.run_biophysical_phase(state_raid, "en")
	var has_raid_flow := false
	for fl in state_raid.active_flows:
		if fl.flow_type == "raid":
			has_raid_flow = true
			break
	_assert(has_raid_flow, "Cross-border raid emits 'raid' HexEdgeFlow")
	_assert(r_att.energy_reserves > 24.0 and r_vic.energy_reserves < 115.0, "Raid steals reserves from wealthy neighbor (raider %.1f, victim %.1f)" % [r_att.energy_reserves, r_vic.energy_reserves])
	var has_raid_chronicle := false
	for e in state_raid.chronicle:
		if e.event_type == "raid":
			has_raid_chronicle = true
			break
	_assert(has_raid_chronicle, "Raid logs 'raid' ChronicleEntry")

	# 6. Conquering Horde (strat-war) real territorial Invasion (war) across hexes in multi-generation simulation
	var state_war := EvoPresets.create_preset_world("preset-finite-island", "en", "strat-war", "strat-cooperation")
	var war_events_count := 0
	var war_flows_seen := 0
	var warband_created := false
	for g in range(18):
		EvoTurnEngine.advance_generation(state_war, "en")
		for fl in state_war.active_flows:
			if fl.flow_type == "war":
				war_flows_seen += 1
		for did in state_war.demes.keys():
			if str(did).contains("-w"):
				warband_created = true
	for e in state_war.chronicle:
		if e.event_type == "war":
			war_events_count += 1
	_assert(war_events_count >= 1 and war_flows_seen >= 1, "strat-war marches and triggers real territorial invasions ('war' events=%d, flows=%d) in multi-turn simulation" % [war_events_count, war_flows_seen])
	_assert(warband_created, "Territorial invasion spawns conquering warband demes ('-w') in target hexes")

	# 7. All 8 new procedural pixel-art sprites & UI/renderer integration
	EvoPixelArtGen.ensure_all_assets(true)
	var new_sprite_keys: Array[String] = [
		"prop_war_banner",
		"prop_raid_loot",
		"prop_pact_totem",
		"prop_betrayal_ruin",
		"icon_war",
		"icon_raid",
		"icon_pact",
		"icon_betrayal"
	]
	for skey in new_sprite_keys:
		var subdir := "villages" if skey.begins_with("prop_") else "ui"
		var file_path := "res://assets/sprites/%s/%s.png" % [subdir, skey]
		_assert(FileAccess.file_exists(file_path), "Generated sprite PNG exists on disk: %s" % file_path)
		var tex := EvoPixelArtGen.get_texture(skey)
		_assert(tex != null and tex.get_width() >= 16 and tex.get_height() >= 16, "Loaded sprite Texture2D is valid and non-empty: %s" % skey)

	for icon_key in ["war", "raid", "pact", "betrayal"]:
		var ui_tex := EvoUiStyle.get_pixel_icon(icon_key)
		_assert(ui_tex != null, "EvoUiStyle.get_pixel_icon('%s') returns valid Texture2D" % icon_key)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	root.add_child(main)
	if main.camera == null:
		main._ready()

	main.world_state = state_pact
	main.world_renderer.set_world_state(state_pact)
	main.hud.set_world_state(state_pact)
	main.world_renderer._rebuild()
	main.world_renderer._process(0.016)

	var pact_summary := EvoHudInspectorPanel.format_active_pacts_summary(state_pact, "en", p_d1)
	_assert(pact_summary.contains("🤝"), "EvoHudInspectorPanel.format_active_pacts_summary displays active pact partner")
	var pact_rel_lines := EvoHudInspectorPanel.build_deme_relations_lines(state_pact, "en", p_d1)
	_assert(not pact_rel_lines.is_empty(), "EvoHudInspectorPanel.build_deme_relations_lines includes pact & relation lines")
	_assert(not ("\n".join(pact_rel_lines)).contains("{partner}"), "EvoHudInspectorPanel.build_deme_relations_lines substitutes {partner} placeholder in English")
	var pact_rel_lines_es := EvoHudInspectorPanel.build_deme_relations_lines(state_pact, "es", p_d1)
	_assert(not ("\n".join(pact_rel_lines_es)).contains("{partner}") and ("\n".join(pact_rel_lines_es)).contains("Pacto activo con "), "EvoHudInspectorPanel.build_deme_relations_lines substitutes {partner} placeholder in Spanish")

	main.hud.open_notebook_modal()
	for f_key in ["war", "raid", "pact", "betrayal"]:
		_assert(main.hud.notebook_modal._filter_buttons.has(f_key), "EvoNotebookModal has filter button for '%s'" % f_key)
		main.hud.notebook_modal._on_filter_pressed(f_key)
		_assert(main.hud.notebook_modal._active_filter == f_key, "EvoNotebookModal switches active filter to '%s'" % f_key)
	main.hud.notebook_modal.close_modal()

	main.free()


func _test_bugfix_regressions() -> void:
	print("-- Testing Bugfix Regressions --")
	# 1. _strip_migration_suffix preserves root deme IDs and strips migration/warband suffixes
	_assert(EvoDemographyMigration._strip_migration_suffix("deme-rift-west") == "deme-rift-west", "_strip_migration_suffix preserves 'deme-rift-west'")
	_assert(EvoDemographyMigration._strip_migration_suffix("deme-rift-west-m3-0_0") == "deme-rift-west", "_strip_migration_suffix strips '-m3-0_0' suffix")
	_assert(EvoDemographyMigration._strip_migration_suffix("deme-rift-west-w2") == "deme-rift-west", "_strip_migration_suffix strips '-w2' suffix")

	# 2. resolve_deme_decision_model_tag assigns deme-darwin-rival to secondary model
	_assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-darwin-rival", "d3:4b", "tev1:4b") == "tev1:4b", "resolve_deme_decision_model_tag assigns 'deme-darwin-rival' to secondary model 'tev1:4b'")

	# 3. is_hex_passable_for_deme rejects altitude > 0.85 (0.88 mountain barrier)
	var mountain_cell := EvoTypes.HexCell.new()
	mountain_cell.id = "0,1"
	mountain_cell.biome = "mountain"
	mountain_cell.altitude = 0.88
	mountain_cell.carrying_capacity = 100.0
	_assert(not EvoDemographyMigration.is_hex_passable_for_deme(mountain_cell, 1.0), "is_hex_passable_for_deme rejects mountain barrier with altitude 0.88 (> 0.85)")

	# 4. validate_and_balance_thermodynamics preserves positive ecological_impact minus excess when target_metabolic > 1.0
	var high_vec := EvoTypes.BiophysicalVector.new(0.0, 1.0, 0.30, 1.0, 1.0, 0.0)
	# A+ = 3.0 -> required_cost = 0.5 * (3.0 - 0.60) = 1.20 -> target_metabolic = 1.20 -> excess = 0.20 -> ecological_impact = 0.30 - 0.20 = 0.10
	var balanced_high := EvoThermodynamics.validate_and_balance_thermodynamics(high_vec, false)
	_assert(is_equal_approx(balanced_high.metabolic_cost, 1.0), "validate_and_balance_thermodynamics caps metabolic_cost at 1.0 when target_metabolic > 1.0")
	_assert(is_equal_approx(balanced_high.ecological_impact, 0.10), "validate_and_balance_thermodynamics preserves positive ecological_impact minus excess (0.30 - 0.20 = 0.10)")

	# 5. EvoLabModal.refresh() preserves checked strategy traits in strategy_trait_checks
	var state := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var lab := EvoLabModal.new()
	root.add_child(lab)
	if lab._title_label == null:
		lab._ready()
	lab.open_modal(state, "es")
	lab._switch_tab("strategies")
	lab._start_new_item()
	(lab.strategy_trait_checks["bio-thermal-tolerance"] as CheckBox).button_pressed = true
	(lab.strategy_trait_checks["bio-social-instinct"] as CheckBox).button_pressed = true
	lab.refresh(state)
	_assert((lab.strategy_trait_checks["bio-thermal-tolerance"] as CheckBox).button_pressed and (lab.strategy_trait_checks["bio-social-instinct"] as CheckBox).button_pressed, "EvoLabModal.refresh() preserves checked strategy traits in strategy_trait_checks")
	lab.free()

	# 6. EvoUiStyle.get_village_tier_label matches Deme.get_village_tier() across all 4 tiers (I..IV)
	var tier_cases := [
		{"pop": 65, "merged": 0, "def": 0, "union": "", "tier": 1, "es": "I · Campamento", "en": "I · Camp"},
		{"pop": 90, "merged": 0, "def": 1, "union": "", "tier": 2, "es": "II · Aldea", "en": "II · Village"},
		{"pop": 140, "merged": 0, "def": 0, "union": "", "tier": 2, "es": "II · Aldea", "en": "II · Village"},
		{"pop": 185, "merged": 0, "def": 1, "union": "", "tier": 3, "es": "III · Villa", "en": "III · Town"},
		{"pop": 255, "merged": 0, "def": 0, "union": "", "tier": 3, "es": "III · Villa", "en": "III · Town"},
		{"pop": 295, "merged": 0, "def": 0, "union": "union-a-b", "tier": 4, "es": "IV · Metrópolis", "en": "IV · Metropolis"},
		{"pop": 395, "merged": 0, "def": 0, "union": "", "tier": 4, "es": "IV · Metrópolis", "en": "IV · Metropolis"}
	]
	for tc in tier_cases:
		var td := EvoTypes.Deme.new()
		td.population = int(tc["pop"])
		td.merged_count = int(tc["merged"])
		td.defense_tier = int(tc["def"])
		td.walled_union_id = str(tc["union"])
		var lbl_es := EvoUiStyle.get_village_tier_label(td.population, "es", td.merged_count, td.defense_tier, td.walled_union_id)
		var lbl_en := EvoUiStyle.get_village_tier_label(td.population, "en", td.merged_count, td.defense_tier, td.walled_union_id)
		_assert(
			td.get_village_tier() == int(tc["tier"]) and lbl_es == str(tc["es"]) and lbl_en == str(tc["en"]) and lbl_es.begins_with(td.get_village_roman() + " · "),
			"EvoUiStyle.get_village_tier_label matches Deme.get_village_tier() for tier %d (pop=%d, def=%d, union=%s)" % [int(tc["tier"]), td.population, td.defense_tier, td.walled_union_id]
		)

	# 7. max_rural quota enforcement releases excess rural hexes when a deme drops in tier
	var state_quota := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	var q_deme: EvoTypes.Deme = state_quota.demes["deme-rift-west"]
	var q_other: EvoTypes.Deme = state_quota.demes["deme-rift-east"]
	(state_quota.cells[q_deme.hex_id] as EvoTypes.HexCell).deme_ids.erase(q_deme.id)
	(state_quota.cells[q_other.hex_id] as EvoTypes.HexCell).deme_ids.erase(q_other.id)
	q_deme.hex_id = "0,0"
	q_other.hex_id = "0,4"
	(state_quota.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([q_deme.id])
	(state_quota.cells["0,4"] as EvoTypes.HexCell).deme_ids.assign([q_other.id])
	q_deme.population = 400
	q_deme.defense_tier = 2
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		var nc: EvoTypes.HexCell = state_quota.cells[nid]
		nc.biome = "savanna"
		nc.altitude = 0.45
		nc.current_resources = 500.0
	var q_vecs := {
		q_deme.id: EvoEcologyInteraction.compute_effective_vector(q_deme, state_quota),
		q_other.id: EvoEcologyInteraction.compute_effective_vector(q_other, state_quota)
	}
	var q_ext := {q_deme.id: 50.0, q_other.id: 50.0}
	EvoEcologyInteraction._update_and_harvest_rural_hinterlands(state_quota, q_vecs, q_ext)
	var count_t4 := 0
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		if (state_quota.cells[nid] as EvoTypes.HexCell).owner_deme_id == q_deme.id:
			count_t4 += 1
	_assert(count_t4 == 4, "Tier 4 deme claims 4 rural hinterland hexes")

	q_deme.population = 180
	q_deme.defense_tier = 1
	EvoEcologyInteraction._update_and_harvest_rural_hinterlands(state_quota, q_vecs, q_ext)
	var count_t3 := 0
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		if (state_quota.cells[nid] as EvoTypes.HexCell).owner_deme_id == q_deme.id:
			count_t3 += 1
	_assert(q_deme.get_village_tier() == 3 and count_t3 == 2, "Dropping to Tier 3 releases excess rural hexes down to max_rural == 2")

	q_deme.population = 70
	q_deme.defense_tier = 0
	EvoEcologyInteraction._update_and_harvest_rural_hinterlands(state_quota, q_vecs, q_ext)
	var count_t1 := 0
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		if (state_quota.cells[nid] as EvoTypes.HexCell).owner_deme_id == q_deme.id:
			count_t1 += 1
	_assert(q_deme.get_village_tier() == 1 and count_t1 == 0, "Dropping to Tier 1 releases all rural hexes (max_rural == 0)")

	# 8. Flood/mountain relocation clears non-adjacent rural hexes and revalidates walled_union_id
	var state_reloc := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	state_reloc.unlimited_pressure_mode = true
	var r_d1: EvoTypes.Deme = state_reloc.demes["deme-rift-west"]
	var r_d2: EvoTypes.Deme = state_reloc.demes["deme-rift-east"]
	(state_reloc.cells[r_d1.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_d1.id)
	(state_reloc.cells[r_d2.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_d2.id)
	r_d1.hex_id = "0,0"
	r_d2.hex_id = "1,0"
	(state_reloc.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([r_d1.id])
	(state_reloc.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([r_d2.id])
	r_d1.population = 180
	r_d2.population = 180
	r_d1.defense_tier = 1
	r_d2.defense_tier = 1
	r_d1.walled_union_id = "union-reloc-test"
	r_d2.walled_union_id = "union-reloc-test"
	state_reloc.active_pacts[EvoTypes.make_pair_key(r_d1.id, r_d2.id)] = 4
	for nid in HexMath.get_neighbor_ids(0, 0, state_reloc.cells):
		if nid != "1,0":
			var nc: EvoTypes.HexCell = state_reloc.cells[nid]
			nc.biome = "ocean"
			nc.altitude = 0.05
	var escape_cell: EvoTypes.HexCell = state_reloc.cells["-1,0"]
	escape_cell.biome = "savanna"
	escape_cell.altitude = 0.45
	escape_cell.current_resources = 500.0
	var far_rural_cell: EvoTypes.HexCell = state_reloc.cells["0,1"]
	far_rural_cell.biome = "savanna"
	far_rural_cell.altitude = 0.45
	far_rural_cell.current_resources = 10.0
	far_rural_cell.owner_deme_id = r_d1.id
	far_rural_cell.land_use = "crops"
	EvoTurnEngine.apply_set_biome(state_reloc, ["0,0"], "high_mountain", "en")
	_assert(r_d1.hex_id == "-1,0", "Displaced deme relocates from high_mountain (0,0) to richest passable neighbor (-1,0)")
	_assert(far_rural_cell.owner_deme_id == "" and far_rural_cell.land_use == "wild", "Relocation clears rural hex (0,1) that is no longer at hex_distance == 1 from (-1,0)")
	_assert(r_d1.walled_union_id == "" and r_d2.walled_union_id == "", "Relocation out of adjacency dissolves walled_union_id on both partners")

	# 9. EvoDecisionModel.prefetch_for_state warms cache keys matching post-EvoEnvPhase signatures on next generation
	var state_pf := EvoPresets.create_preset_world("preset-rift-savanna", "es")
	var pf_gen_before := state_pf.generation
	var pf_season_before := state_pf.season
	var pf_west: EvoTypes.Deme = state_pf.demes["deme-rift-west"]
	var pf_cell: EvoTypes.HexCell = state_pf.cells[pf_west.hex_id]
	var pf_k_before := pf_cell.carrying_capacity
	var pf_r_before := pf_cell.current_resources
	var pf_t_before := pf_cell.temperature
	var pf_h_before := pf_cell.humidity

	var state_sim_next := EvoTypes.WorldState.from_dict(state_pf.to_dict())
	EvoEnvPhase.run_environmental_phase(state_sim_next, "es")
	var sim_next_west: EvoTypes.Deme = state_sim_next.demes["deme-rift-west"]
	var expected_next_sig := EvoDecisionModel.compute_deme_evaluation_signature(sim_next_west, state_sim_next)

	# Simulate prefetch_for_state signature computation and verify state restoration
	EvoDecisionModel.prefetch_for_state(state_pf)
	_assert(
		state_pf.generation == pf_gen_before and state_pf.season == pf_season_before and is_equal_approx(pf_cell.carrying_capacity, pf_k_before) and is_equal_approx(pf_cell.current_resources, pf_r_before) and is_equal_approx(pf_cell.temperature, pf_t_before) and is_equal_approx(pf_cell.humidity, pf_h_before),
		"EvoDecisionModel.prefetch_for_state restores generation, season, and cell climate/resources after next-turn projection"
	)
	EvoOllamaClient.seed_signature_cache(expected_next_sig, {
		"probabilities": {"dec-cooperate-store": 0.80, "dec-conservative-forage": 0.20},
		"dominant_decision_id": "dec-cooperate-store",
		"confidence": 0.93
	})
	EvoEnvPhase.run_environmental_phase(state_pf, "es")
	var actual_next_sig := EvoDecisionModel.compute_deme_evaluation_signature(pf_west, state_pf)
	_assert(actual_next_sig == expected_next_sig, "Projected next-turn signature in prefetch_for_state matches actual post-EvoEnvPhase signature")
	EvoDecisionModel.evaluate_all_demes(state_pf, "es", false)
	_assert(pf_west.last_confidence == 0.93 and pf_west.last_dominant_decision_id == "dec-cooperate-store", "evaluate_all_demes hits prefetched post-EvoEnvPhase signature cache on next generation")
	EvoOllamaClient.clear_cache()


func _test_social_memory_defense_tribute_and_synoecism() -> void:
	print("-- Testing Social Memory, Multi-Tier Defense, Vendettas, Tribute, Synoecism & New Sprites --")
	# 1. LLM Historical Memory & Rich Neighbor Context
	var state_mem := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-war")
	state_mem.generation = 5
	var d_focus: EvoTypes.Deme = state_mem.demes["deme-rift-west"]
	var d_rival: EvoTypes.Deme = state_mem.demes["deme-rift-east"]
	(state_mem.cells[d_focus.hex_id] as EvoTypes.HexCell).deme_ids.erase(d_focus.id)
	(state_mem.cells[d_rival.hex_id] as EvoTypes.HexCell).deme_ids.erase(d_rival.id)
	d_focus.hex_id = "0,0"
	d_rival.hex_id = "1,0"
	(state_mem.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(d_focus.id)
	(state_mem.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(d_rival.id)
	d_focus.population = 80
	d_focus.defense_tier = 2
	d_focus.merged_count = 1
	d_rival.population = 120
	d_rival.defense_tier = 0
	d_rival.last_dominant_decision_id = "dec-territorial-dispute"

	var d_kin := d_focus.duplicate_deme()
	d_kin.id = "deme-kin-test"
	d_kin.name = "Clan Kin"
	d_kin.hex_id = "0,-1"
	d_kin.population = 45
	d_kin.defense_tier = 1
	d_kin.last_dominant_decision_id = "dec-conservative-forage"
	state_mem.demes[d_kin.id] = d_kin
	(state_mem.cells["0,-1"] as EvoTypes.HexCell).deme_ids.append(d_kin.id)

	var d_ally := d_focus.duplicate_deme()
	d_ally.id = "deme-ally-test"
	d_ally.name = "Clan Ally"
	d_ally.lineage_id = "lineage-ally-distinct"
	d_ally.hex_id = "-1,0"
	d_ally.population = 85
	d_ally.defense_tier = 2
	d_ally.last_dominant_decision_id = "dec-cooperate-store"
	state_mem.demes[d_ally.id] = d_ally
	(state_mem.cells["-1,0"] as EvoTypes.HexCell).deme_ids.append(d_ally.id)
	state_mem.active_pacts[EvoTypes.make_pair_key(d_focus.id, d_ally.id)] = 3

	_assert(
		EvoHeuristicScorer._format_neighbor_occupant_label(d_focus, d_rival, state_mem) == "rival:martial:stronger:def0",
		"Neighbor occupant label formats rival martial stronger deme with defense tier"
	)
	_assert(
		EvoHeuristicScorer._format_neighbor_occupant_label(d_focus, d_kin, state_mem) == "kin:forage:weaker:def1",
		"Neighbor occupant label formats kin forage weaker deme with defense tier"
	)
	_assert(
		EvoHeuristicScorer._format_neighbor_occupant_label(d_focus, d_ally, state_mem) == "ally:cooperate:equal:def2",
		"Neighbor occupant label formats allied cooperate equal deme with defense tier"
	)

	state_mem.active_pacts[EvoTypes.make_pair_key(d_focus.id, d_rival.id)] = -3
	var mem_raid_entry := EvoTypes.ChronicleEntry.new()
	mem_raid_entry.id = "chronicle-raid-4-%s-%s" % [d_rival.id, d_focus.id]
	mem_raid_entry.generation = 4
	mem_raid_entry.event_type = "raid"
	mem_raid_entry.hex_id = d_focus.hex_id
	mem_raid_entry.deme_id = d_rival.id
	state_mem.chronicle.append(mem_raid_entry)
	EvoHeuristicScorer.invalidate_state_caches(state_mem)

	_assert(
		EvoHeuristicScorer._format_neighbor_occupant_label(d_focus, d_rival, state_mem) == "vendetta:martial:stronger:def0",
		"Neighbor occupant label reflects active vendetta against rival"
	)
	var geo_sum := EvoHeuristicScorer.build_geopolitics_summary(d_focus, state_mem.cells["0,0"], state_mem)
	_assert(int(geo_sum.get("active_pacts", -1)) == 1, "build_geopolitics_summary reports active_pacts == 1")
	_assert(int(geo_sum.get("active_vendettas", -1)) == 1, "build_geopolitics_summary reports active_vendettas == 1")
	_assert(int(geo_sum.get("defense_tier", -1)) == 2, "build_geopolitics_summary reports defense_tier == 2")
	_assert(bool(geo_sum.get("horde_threat", false)), "build_geopolitics_summary detects nearby horde_threat")
	var mem_str := str(geo_sum.get("memory", ""))
	_assert(
		mem_str.contains("raided@G4") and mem_str.contains("vendettas=1") and mem_str.contains("horde_nearby"),
		"build_geopolitics_summary memory digest includes raid history, vendettas and horde threat (%s)" % mem_str
	)

	var compact_state := EvoHeuristicScorer.build_compact_system_one_state(d_focus, state_mem)
	_assert(compact_state.contains("def=Lv2, merged=1"), "build_compact_system_one_state includes def=Lv2 and merged=1")
	_assert(compact_state.contains("memory=") and compact_state.contains("raided@G4"), "build_compact_system_one_state includes historical memory")
	_assert(compact_state.contains(":def"), "build_compact_system_one_state Neighbors list includes relational labels and defense tier")
	_assert(compact_state.contains("\"active_vendettas\":1") and compact_state.contains("\"defense_tier\":2"), "build_compact_system_one_state geopolitics JSON includes active_vendettas and defense_tier")

	# 2. Multi-Tier Defense (0 -> 1 -> 2 -> 3) & Castle Raid Immunity
	var state_def := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-war")
	var d_def: EvoTypes.Deme = state_def.demes["deme-rift-west"]
	var d_att: EvoTypes.Deme = state_def.demes["deme-rift-east"]
	(state_def.cells[d_def.hex_id] as EvoTypes.HexCell).deme_ids.erase(d_def.id)
	(state_def.cells[d_att.hex_id] as EvoTypes.HexCell).deme_ids.erase(d_att.id)
	d_def.hex_id = "0,0"
	d_att.hex_id = "1,0"
	(state_def.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(d_def.id)
	(state_def.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(d_att.id)
	var def_cell: EvoTypes.HexCell = state_def.cells["0,0"]
	def_cell.current_resources = 320.0
	d_def.population = 120
	d_def.energy_reserves = 260.0
	var def_arch_probs := {
		d_def.id: [0.55, 0.25, 0.05, 0.05],
		d_att.id: [0.05, 0.05, 0.60, 0.20]
	}
	_assert(d_def.defense_tier == 0, "Deme starts at defense_tier 0")

	var res_before_t1 := d_def.energy_reserves
	var cell_before_t1 := def_cell.current_resources
	EvoEcologyInteraction._run_defense_fortification_phase(state_def, "en", def_arch_probs)
	_assert(d_def.defense_tier == 1, "_run_defense_fortification_phase upgrades defense_tier 0 -> 1 (Palisade)")
	_assert(d_def.energy_reserves < res_before_t1 and def_cell.current_resources < cell_before_t1, "Tier 1 fortification consumes deme reserves and hex resources")

	EvoEcologyInteraction._run_defense_fortification_phase(state_def, "en", def_arch_probs)
	_assert(d_def.defense_tier == 2, "_run_defense_fortification_phase upgrades defense_tier 1 -> 2 (Stone Wall)")

	EvoEcologyInteraction._run_defense_fortification_phase(state_def, "en", def_arch_probs)
	_assert(d_def.defense_tier == 3, "_run_defense_fortification_phase upgrades defense_tier 2 -> 3 (Castle)")
	var fortify_chronicles := 0
	for e in state_def.chronicle:
		if e.event_type == "fortify" and e.deme_id == d_def.id:
			fortify_chronicles += 1
	_assert(fortify_chronicles >= 2, "Upgrading to Tier 2 and Tier 3 logs 'fortify' ChronicleEntries")

	state_def.season = "dry_cold"
	d_att.population = 110
	d_att.energy_reserves = 20.0
	(state_def.cells["1,0"] as EvoTypes.HexCell).current_resources = 15.0
	d_att.last_decision_probabilities = {"dec-territorial-dispute": 0.60, "dec-intensive-overexploit": 0.25, "dec-conservative-forage": 0.15}
	var vec_att := EvoEcologyInteraction.compute_effective_vector(d_att, state_def)
	var raid_ext_map := {d_att.id: 10.0, d_def.id: 85.0}
	_assert(
		not EvoEcologyInteraction._can_attempt_raid(d_att, d_def, state_def.cells["1,0"], state_def, vec_att, raid_ext_map, [0.05, 0.05, 0.60, 0.25]),
		"Tier 3 Castle is immune to _can_attempt_raid"
	)
	d_def.defense_tier = 0
	_assert(
		EvoEcologyInteraction._can_attempt_raid(d_att, d_def, state_def.cells["1,0"], state_def, vec_att, raid_ext_map, [0.05, 0.05, 0.60, 0.25]),
		"Undefended deme (Tier 0) is vulnerable to _can_attempt_raid under same conditions"
	)
	var forces_t0 := EvoDemographyMigration._compute_combat_forces(d_att, 55, d_def, state_def)
	d_def.defense_tier = 3
	var forces_t3 := EvoDemographyMigration._compute_combat_forces(d_att, 55, d_def, state_def)
	_assert(forces_t3.y > forces_t0.y * 1.50, "Tier 3 Castle significantly boosts defender force in _compute_combat_forces (%.1f vs %.1f)" % [forces_t3.y, forces_t0.y])

	# 3. Vendettas & Tribute Appeasement
	var state_trib := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-trade")
	var t_raider: EvoTypes.Deme = state_trib.demes["deme-rift-west"]
	var t_trader: EvoTypes.Deme = state_trib.demes["deme-rift-east"]
	(state_trib.cells[t_raider.hex_id] as EvoTypes.HexCell).deme_ids.erase(t_raider.id)
	(state_trib.cells[t_trader.hex_id] as EvoTypes.HexCell).deme_ids.erase(t_trader.id)
	t_raider.hex_id = "0,0"
	t_trader.hex_id = "1,0"
	(state_trib.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(t_raider.id)
	(state_trib.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(t_trader.id)
	state_trib.season = "dry_cold"
	(state_trib.cells["0,0"] as EvoTypes.HexCell).current_resources = 18.0
	(state_trib.cells["1,0"] as EvoTypes.HexCell).current_resources = 220.0
	t_raider.population = 85
	t_raider.energy_reserves = 22.0
	t_trader.population = 45
	t_trader.energy_reserves = 120.0
	t_trader.defense_tier = 0
	t_raider.last_decision_probabilities = {"dec-territorial-dispute": 0.55, "dec-intensive-overexploit": 0.30, "dec-conservative-forage": 0.15}
	t_trader.last_decision_probabilities = {"dec-exchange-symbiosis": 0.55, "dec-cooperate-store": 0.30, "dec-conservative-forage": 0.15}
	var trib_vecs := {
		t_raider.id: EvoEcologyInteraction.compute_effective_vector(t_raider, state_trib),
		t_trader.id: EvoEcologyInteraction.compute_effective_vector(t_trader, state_trib)
	}
	var trib_hawks := {t_raider.id: 1.0, t_trader.id: 1.0}
	var trib_ext := {t_raider.id: 0.0, t_trader.id: 0.0}
	var trib_flows: Array[EvoTypes.HexEdgeFlow] = []
	EvoEcologyInteraction.run_resource_and_symbiosis_phase(state_trib, "en", trib_vecs, trib_hawks, trib_ext, trib_flows)
	_assert(t_raider.population == 85 and t_trader.population == 45, "Paying tribute avoids raid casualties on both sides")
	_assert(t_raider.energy_reserves > 22.0, "Raider receives tribute energy reserves (%.1f)" % t_raider.energy_reserves)
	var trib_pk := EvoTypes.make_pair_key(t_raider.id, t_trader.id)
	_assert(int(state_trib.active_pacts.get(trib_pk, 0)) == 1, "Tribute establishes temporary truce (active_pacts == 1)")
	var has_tribute_flow := false
	for fl in state_trib.active_flows:
		if fl.flow_type == "tribute":
			has_tribute_flow = true
			break
	_assert(has_tribute_flow, "Tribute payment emits 'tribute' HexEdgeFlow")
	var has_tribute_chronicle := false
	for e in state_trib.chronicle:
		if e.event_type == "tribute":
			has_tribute_chronicle = true
			break
	_assert(has_tribute_chronicle, "Tribute payment logs 'tribute' ChronicleEntry")

	# Verify raid/betrayal sets negative active_pacts and EvoTypes.is_vendetta_active == true
	state_trib.active_pacts[trib_pk] = 0
	t_trader.last_decision_probabilities = {"dec-conservative-forage": 0.85, "dec-territorial-dispute": 0.15}
	t_trader.defense_tier = 0
	t_trader.energy_reserves = 110.0
	state_trib.chronicle.clear()
	EvoEcologyInteraction._execute_raid_if_successful(
		t_raider,
		t_trader,
		state_trib.cells["0,0"],
		state_trib.cells["1,0"],
		state_trib,
		"en",
		trib_vecs[t_raider.id],
		trib_vecs[t_trader.id],
		{t_raider.id: 15.0, t_trader.id: 60.0},
		trib_flows,
		[0.0, 0.0, 0.55, 0.30],
		[0.0, 0.0, 0.15, 0.0]
	)
	_assert(int(state_trib.active_pacts.get(trib_pk, 0)) <= -2 and EvoTypes.is_vendetta_active(state_trib, t_raider.id, t_trader.id), "Raid sets negative active_pacts and activates vendetta")
	EvoEcologyInteraction._execute_betrayal(
		t_raider,
		t_trader,
		state_trib.cells["0,0"],
		state_trib.cells["1,0"],
		trib_pk,
		state_trib,
		"en",
		{t_raider.id: 15.0, t_trader.id: 60.0},
		trib_flows
	)
	_assert(int(state_trib.active_pacts.get(trib_pk, 0)) == -4 and EvoTypes.is_vendetta_active(state_trib, t_raider.id, t_trader.id), "Betrayal sets active_pacts to -4 (deep vendetta)")

	# 4. City Unification (Synoecism), Asymmetric Absorption & Multi-Hex Walled Unions
	# 4a. Same-hex safety-net synoecism with active_pacts >= 3
	var state_syn1 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var s1_a: EvoTypes.Deme = state_syn1.demes["deme-rift-west"]
	var s1_b: EvoTypes.Deme = state_syn1.demes["deme-rift-east"]
	(state_syn1.cells[s1_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(s1_a.id)
	(state_syn1.cells[s1_b.hex_id] as EvoTypes.HexCell).deme_ids.erase(s1_b.id)
	s1_a.hex_id = "0,0"
	s1_b.hex_id = "0,0"
	(state_syn1.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([s1_a.id, s1_b.id])
	s1_a.population = 185
	s1_b.population = 125
	s1_a.defense_tier = 2
	s1_a.energy_reserves = 120.0
	s1_b.energy_reserves = 110.0
	s1_a.last_decision_probabilities = {"dec-cooperate-store": 0.70, "dec-conservative-forage": 0.30}
	s1_b.last_decision_probabilities = {"dec-exchange-symbiosis": 0.70, "dec-conservative-forage": 0.30}
	var s1_b_color := s1_b.color
	state_syn1.active_pacts[EvoTypes.make_pair_key(s1_a.id, s1_b.id)] = 3
	var s1_init_pops := {s1_a.id: s1_a.population, s1_b.id: s1_b.population}
	var s1_vecs := {
		s1_a.id: EvoEcologyInteraction.compute_effective_vector(s1_a, state_syn1),
		s1_b.id: EvoEcologyInteraction.compute_effective_vector(s1_b, state_syn1)
	}
	var s1_ext := {s1_a.id: 95.0, s1_b.id: 75.0}
	EvoDemographyMigration.run_demography_and_migration_phase(state_syn1, "en", s1_init_pops, s1_vecs, {}, s1_ext)
	_assert(state_syn1.demes.size() == 1, "Same-hex synoecism (active_pacts >= 3) merges 2 allied demes into 1 unified city")
	_assert(s1_a.merged_count >= 1, "Unified city increments merged_count (%d)" % s1_a.merged_count)
	_assert(s1_a.population > 280, "Unified city combines populations (%d)" % s1_a.population)
	_assert(s1_a.secondary_color == s1_b_color and s1_a.secondary_color != "", "Unified city records partner secondary_color (%s)" % s1_a.secondary_color)
	_assert(s1_a.get_village_tier() == 4 and s1_a.get_village_roman() == "IV", "Unified citadel/metropolis reaches Tier 4 ('IV')")
	_assert(
		EvoUiStyle.get_village_tier_label(s1_a.population, "es", s1_a.merged_count, s1_a.defense_tier, s1_a.walled_union_id) == "IV · Metrópolis" and EvoUiStyle.get_village_tier_label(s1_a.population, "en", s1_a.merged_count, s1_a.defense_tier, s1_a.walled_union_id) == "IV · Metropolis",
		"EvoUiStyle.get_village_tier_label returns Metropolis label in ES and EN"
	)

	# 4b. Asymmetric Category Absorption (tier_a != tier_b) converts vacated hex into rural hinterland owned by host city
	var state_syn2 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-innovation")
	var s2_a: EvoTypes.Deme = state_syn2.demes["deme-rift-west"]
	var s2_b: EvoTypes.Deme = state_syn2.demes["deme-rift-east"]
	(state_syn2.cells[s2_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(s2_a.id)
	(state_syn2.cells[s2_b.hex_id] as EvoTypes.HexCell).deme_ids.erase(s2_b.id)
	s2_a.hex_id = "0,0"
	s2_b.hex_id = "1,0"
	(state_syn2.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(s2_a.id)
	(state_syn2.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(s2_b.id)
	s2_a.population = 180
	s2_a.defense_tier = 1
	s2_b.population = 70
	s2_b.defense_tier = 0
	s2_a.energy_reserves = 110.0
	s2_b.energy_reserves = 95.0
	s2_a.last_decision_probabilities = {"dec-cooperate-store": 0.65, "dec-exchange-symbiosis": 0.25, "dec-conservative-forage": 0.10}
	s2_b.last_decision_probabilities = {"dec-exchange-symbiosis": 0.55, "dec-cooperate-store": 0.30, "dec-explore-innovate": 0.15}
	var s2_b_color := s2_b.color
	state_syn2.active_pacts[EvoTypes.make_pair_key(s2_a.id, s2_b.id)] = 4
	var s2_init_pops := {s2_a.id: s2_a.population, s2_b.id: s2_b.population}
	var s2_vecs := {
		s2_a.id: EvoEcologyInteraction.compute_effective_vector(s2_a, state_syn2),
		s2_b.id: EvoEcologyInteraction.compute_effective_vector(s2_b, state_syn2)
	}
	var s2_ext := {s2_a.id: 95.0, s2_b.id: 50.0}
	EvoDemographyMigration.run_demography_and_migration_phase(state_syn2, "en", s2_init_pops, s2_vecs, {}, s2_ext)
	_assert(state_syn2.demes.size() == 1, "Asymmetric Category Absorption (tier_a != tier_b, active_pacts >= 4) absorbs lower-tier neighbor into host city")
	_assert(s2_a.merged_count == 1 and s2_a.secondary_color == s2_b_color, "Host city sets merged_count == 1 and secondary_color")
	_assert(s2_a.defense_tier >= 2, "Asymmetric absorption elevates host city defense_tier (%d)" % s2_a.defense_tier)
	var vacated_cell: EvoTypes.HexCell = state_syn2.cells["1,0"]
	_assert(
		vacated_cell.deme_ids.is_empty() and vacated_cell.owner_deme_id == s2_a.id and vacated_cell.land_use in ["crops", "pasture"],
		"Asymmetric absorption converts vacated neighbor hex into rural hinterland (%s) owned by host city" % vacated_cell.land_use
	)
	var has_merge_flow := false
	for fl in state_syn2.active_flows:
		if fl.flow_type == "merge" and fl.from_hex_id == "1,0" and fl.to_hex_id == "0,0":
			has_merge_flow = true
			break
	_assert(has_merge_flow, "Asymmetric absorption emits inter-hex 'merge' HexEdgeFlow")
	var has_merge_chronicle := false
	for e in state_syn2.chronicle:
		if e.event_type == "merge":
			has_merge_chronicle = true
			break
	_assert(has_merge_chronicle, "Synoecism logs 'merge' ChronicleEntry")
	EvoMilestonePhase.run_milestone_phase(state_syn2, "en")
	_assert(state_syn2.macro_outcome_type != "single_survivor", "Peaceful city unification does not falsely trigger single_survivor extinction outcome")

	# 4c. Same-Category Multi-Hex Walled Union (tier_a == tier_b >= 2)
	var state_union := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var u_a: EvoTypes.Deme = state_union.demes["deme-rift-west"]
	var u_b: EvoTypes.Deme = state_union.demes["deme-rift-east"]
	(state_union.cells[u_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(u_a.id)
	(state_union.cells[u_b.hex_id] as EvoTypes.HexCell).deme_ids.erase(u_b.id)
	u_a.hex_id = "0,0"
	u_b.hex_id = "1,0"
	(state_union.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([u_a.id])
	(state_union.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([u_b.id])
	u_a.population = 135
	u_b.population = 135
	u_a.defense_tier = 1
	u_b.defense_tier = 1
	u_a.energy_reserves = 120.0
	u_b.energy_reserves = 120.0
	u_a.last_decision_probabilities = {"dec-cooperate-store": 0.65, "dec-exchange-symbiosis": 0.25, "dec-conservative-forage": 0.10}
	u_b.last_decision_probabilities = {"dec-exchange-symbiosis": 0.60, "dec-cooperate-store": 0.30, "dec-conservative-forage": 0.10}
	state_union.active_pacts[EvoTypes.make_pair_key(u_a.id, u_b.id)] = 4
	var u_init_pops := {u_a.id: u_a.population, u_b.id: u_b.population}
	var u_vecs := {
		u_a.id: EvoEcologyInteraction.compute_effective_vector(u_a, state_union),
		u_b.id: EvoEcologyInteraction.compute_effective_vector(u_b, state_union)
	}
	var u_ext := {u_a.id: 85.0, u_b.id: 85.0}
	EvoDemographyMigration.run_demography_and_migration_phase(state_union, "en", u_init_pops, u_vecs, {}, u_ext)
	_assert(state_union.demes.size() == 2, "Same-category Multi-Hex Walled Union keeps both demes on their own hexes")
	_assert(
		u_a.walled_union_id != "" and u_a.walled_union_id == u_b.walled_union_id,
		"Same-category Multi-Hex Walled Union assigns shared walled_union_id (%s)" % u_a.walled_union_id
	)
	var solo_u := u_a.duplicate_deme()
	solo_u.walled_union_id = ""
	var dummy_att := EvoTypes.Deme.new()
	dummy_att.id = "att-test"
	dummy_att.lineage_id = "lin-att"
	dummy_att.population = 100
	var union_forces := EvoDemographyMigration._compute_combat_forces(dummy_att, 50, u_a, state_union)
	var solo_forces := EvoDemographyMigration._compute_combat_forces(dummy_att, 50, solo_u, state_union)
	_assert(union_forces.y > solo_forces.y * 1.25, "Walled union partner pools garrison population and fortification defense bonus (%.1f vs %.1f)" % [union_forces.y, solo_forces.y])

	# 4d. Rural Hinterlands (crops & pasture claiming, caloric harvest bonus, and raid/siege pillaging)
	var state_rural := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-war")
	var r_city: EvoTypes.Deme = state_rural.demes["deme-rift-west"]
	var r_raider: EvoTypes.Deme = state_rural.demes["deme-rift-east"]
	(state_rural.cells[r_city.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_city.id)
	(state_rural.cells[r_raider.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_raider.id)
	r_city.hex_id = "0,0"
	r_raider.hex_id = "0,3"
	(state_rural.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([r_city.id])
	(state_rural.cells["0,3"] as EvoTypes.HexCell).deme_ids.assign([r_raider.id])
	(state_rural.cells["0,0"] as EvoTypes.HexCell).biome = "savanna"
	(state_rural.cells["0,0"] as EvoTypes.HexCell).altitude = 0.45
	(state_rural.cells["1,0"] as EvoTypes.HexCell).biome = "savanna"
	(state_rural.cells["1,0"] as EvoTypes.HexCell).altitude = 0.45
	(state_rural.cells["1,0"] as EvoTypes.HexCell).current_resources = 900.0
	(state_rural.cells["0,1"] as EvoTypes.HexCell).biome = "arid_steppe"
	(state_rural.cells["0,1"] as EvoTypes.HexCell).altitude = 0.45
	(state_rural.cells["0,1"] as EvoTypes.HexCell).current_resources = 850.0
	r_city.population = 200
	r_city.defense_tier = 1 # Tier 3 city -> claims up to 2 rural hexes
	var r_vecs := {
		r_city.id: EvoEcologyInteraction.compute_effective_vector(r_city, state_rural),
		r_raider.id: EvoEcologyInteraction.compute_effective_vector(r_raider, state_rural)
	}
	var r_ext := {r_city.id: 40.0, r_raider.id: 40.0}
	EvoEcologyInteraction._update_and_harvest_rural_hinterlands(state_rural, r_vecs, r_ext)
	var claimed_crops := 0
	var claimed_pasture := 0
	for cid in HexMath.get_neighbor_ids(0, 0, state_rural.cells):
		var nc: EvoTypes.HexCell = state_rural.cells[cid]
		if nc.owner_deme_id == r_city.id:
			if nc.land_use == "crops":
				claimed_crops += 1
			elif nc.land_use == "pasture":
				claimed_pasture += 1
	_assert(claimed_crops + claimed_pasture == 2 and claimed_crops >= 1 and claimed_pasture >= 1, "Tier 3 city claims both 'crops' and 'pasture' adjacent rural hinterlands")
	_assert(float(r_ext[r_city.id]) > 40.0, "Rural hinterlands provide caloric harvest yield bonus to owning city (%.1f)" % float(r_ext[r_city.id]))

	# Raid pillages an owned rural hinterland hex into wild + has_ruins
	r_raider.population = 190
	r_raider.cultural_trait_ids.assign(["cul-warrior-expansion"])
	r_raider.last_decision_probabilities = {"dec-territorial-dispute": 0.70, "dec-intensive-overexploit": 0.30}
	r_city.population = 80
	r_city.defense_tier = 0
	r_city.energy_reserves = 45.0
	r_city.last_decision_probabilities = {"dec-conservative-forage": 1.0}
	var raid_flows: Array[EvoTypes.HexEdgeFlow] = []
	var raid_ok := EvoEcologyInteraction._execute_raid_if_successful(
		r_raider,
		r_city,
		state_rural.cells["0,3"],
		state_rural.cells["0,0"],
		state_rural,
		"en",
		EvoEcologyInteraction.compute_effective_vector(r_raider, state_rural),
		EvoEcologyInteraction.compute_effective_vector(r_city, state_rural),
		r_ext,
		raid_flows
	)
	var pillaged_ruins := false
	for cid in HexMath.get_neighbor_ids(0, 0, state_rural.cells):
		var nc: EvoTypes.HexCell = state_rural.cells[cid]
		if nc.has_ruins and nc.land_use == "wild" and nc.owner_deme_id == "":
			pillaged_ruins = true
			break
	_assert(raid_ok and pillaged_ruins, "Successful raid pillages an owned rural hinterland hex (land_use='wild', has_ruins=true)")

	# 4e. Urban Salubrity & Epidemic Outbreak (salubrity < 0.35 and population >= 130)
	var state_epi := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-expansion", "strat-cooperation")
	var e_deme: EvoTypes.Deme = state_epi.demes["deme-rift-west"]
	var e_cell: EvoTypes.HexCell = state_epi.cells[e_deme.hex_id]
	e_cell.carrying_capacity = 40.0
	e_cell.humidity = 0.0
	e_deme.biological_trait_ids.erase("bio-k-strategy")
	e_deme.cultural_trait_ids.erase("cul-communal-conservation")
	e_deme.population = 220
	e_deme.salubrity = 0.20
	e_deme.energy_reserves = 150.0
	var epi_init_pops := {}
	var epi_vecs := {}
	var epi_ext := {}
	for did in state_epi.demes.keys():
		var d: EvoTypes.Deme = state_epi.demes[did]
		epi_init_pops[did] = d.population
		epi_vecs[did] = EvoEcologyInteraction.compute_effective_vector(d, state_epi)
		epi_ext[did] = float(d.population) * 0.50
	EvoDemographyMigration.run_demography_and_migration_phase(state_epi, "en", epi_init_pops, epi_vecs, {}, epi_ext)
	var has_epidemic_entry := false
	for entry in state_epi.chronicle:
		if entry.event_type == "epidemic" and entry.deme_id == e_deme.id:
			has_epidemic_entry = true
			break
	_assert(has_epidemic_entry and e_deme.population < 200, "Overcrowded unsanitary city (salubrity < 0.35, pop >= 130) triggers 'epidemic' outbreak and casualties")

	# 4f. Strict 1-Deme-Per-Hex Invariant across multi-gen simulation, flood relocation, warband invasion & budding, plus Camera Yaw Lock & Sector Offset
	var cam := EvoCameraController.new()
	cam.rotate_by(35.0)
	_assert(is_equal_approx(cam.yaw_deg, 0.0), "EvoCameraController locks yaw_deg to 0.0 under rotate_by()")
	cam.free()
	_assert(HexMath.compute_village_sector_offset(0, 2, 100.0) == Vector2.ZERO, "HexMath.compute_village_sector_offset returns Vector2.ZERO for single-deme centered hexes")

	var inv_state := EvoPresets.create_preset_world("preset-darwin-archipelago", "en", "strat-expansion", "strat-war")
	var max_demes_per_cell := 0
	for _step in range(10):
		EvoTurnEngine.advance_generation(inv_state, "en")
		for cid in inv_state.cells.keys():
			var c: EvoTypes.HexCell = inv_state.cells[cid]
			if c.deme_ids.size() > max_demes_per_cell:
				max_demes_per_cell = c.deme_ids.size()
	_assert(max_demes_per_cell <= 1, "Strict 1-deme-per-hex invariant (cell.deme_ids.size() <= 1) holds across 10 generations of expansion, war, and sea-level changes")

	# 5. All 11 New Procedural Sprite Assets & UI Icons
	EvoPixelArtGen.ensure_all_assets(true)
	var phase3_sprites: Array[String] = [
		"tier5_metropolis",
		"prop_unity_monument",
		"prop_defense_palisade",
		"prop_defense_wall",
		"prop_defense_fortress",
		"prop_tribute_chest",
		"prop_siege_engine",
		"icon_defense",
		"icon_merge",
		"icon_tribute",
		"icon_siege"
	]
	for skey in phase3_sprites:
		var subdir := "ui" if skey.begins_with("icon_") else "villages"
		var file_path := "res://assets/sprites/%s/%s.png" % [subdir, skey]
		_assert(FileAccess.file_exists(file_path), "New Phase 3 sprite PNG exists on disk: %s" % file_path)
		var tex := EvoPixelArtGen.get_texture(skey)
		_assert(tex != null and tex.get_width() >= 16 and tex.get_height() >= 16, "Loaded Phase 3 sprite Texture2D is valid and non-empty: %s" % skey)

	for icon_key in ["defense", "merge", "tribute", "siege", "fortify"]:
		var ui_tex := EvoUiStyle.get_pixel_icon(icon_key)
		_assert(ui_tex != null, "EvoUiStyle.get_pixel_icon('%s') returns valid Texture2D" % icon_key)

	# 6. Social Interactions Rebalance Regressions (Military Scale, Farm Protection, Hawk-Dove/Betrayal Caps, Walled Union Persistence)
	# 6a. Repelled Small Army vs. Large Fortified City
	var state_repel := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var repel_att: EvoTypes.Deme = state_repel.demes["deme-rift-west"]
	var repel_def: EvoTypes.Deme = state_repel.demes["deme-rift-east"]
	(state_repel.cells[repel_att.hex_id] as EvoTypes.HexCell).deme_ids.erase(repel_att.id)
	(state_repel.cells[repel_def.hex_id] as EvoTypes.HexCell).deme_ids.erase(repel_def.id)
	repel_att.hex_id = "0,0"
	repel_def.hex_id = "1,0"
	(state_repel.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([repel_att.id])
	(state_repel.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([repel_def.id])
	repel_att.population = 62 # warband_pop = int(round(62 * 0.48)) == 30
	repel_att.energy_reserves = 80.0
	repel_att.last_decision_probabilities = {"dec-territorial-dispute": 0.65, "dec-conservative-forage": 0.35}
	repel_def.population = 240
	repel_def.defense_tier = 2
	repel_def.energy_reserves = 160.0
	repel_def.last_decision_probabilities = {"dec-cooperate-store": 0.70, "dec-conservative-forage": 0.30}
	var repel_farm: EvoTypes.HexCell = state_repel.cells["1,1"]
	repel_farm.biome = "savanna"
	repel_farm.altitude = 0.45
	repel_farm.owner_deme_id = repel_def.id
	repel_farm.land_use = "crops"
	repel_farm.has_ruins = false
	var repel_flows: Array[EvoTypes.HexEdgeFlow] = []
	var repel_invaded := EvoDemographyMigration._execute_territorial_invasion(
		repel_att,
		state_repel.cells["0,0"],
		state_repel.cells["1,0"],
		repel_def,
		state_repel,
		"en",
		repel_flows,
		{},
		{repel_att.id: 62, repel_def.id: 240},
		{repel_att.id: 62, repel_def.id: 240},
		{
			repel_att.id: EvoEcologyInteraction.compute_effective_vector(repel_att, state_repel),
			repel_def.id: EvoEcologyInteraction.compute_effective_vector(repel_def, state_repel)
		}
	)
	_assert(not repel_invaded and (240 - repel_def.population) <= 4, "Small repelled warband (warband_pop=30) inflicts at most 4 casualties on fortified city (pop=240, def=2)")
	_assert(repel_def.defense_tier == 2, "Small repelled warband does not downgrade fortified city's defense_tier (remains 2)")
	_assert(repel_farm.owner_deme_id == repel_def.id and repel_farm.land_use == "crops" and not repel_farm.has_ruins, "Small repelled warband does not destroy or unclaim fortified city's active crops cell")

	# 6b. Active Farm Colonization Protection & min_keep_pop
	var state_farm_prot := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-war")
	var fp_city: EvoTypes.Deme = state_farm_prot.demes["deme-rift-west"]
	var fp_rival: EvoTypes.Deme = state_farm_prot.demes["deme-rift-east"]
	(state_farm_prot.cells[fp_city.hex_id] as EvoTypes.HexCell).deme_ids.erase(fp_city.id)
	(state_farm_prot.cells[fp_rival.hex_id] as EvoTypes.HexCell).deme_ids.erase(fp_rival.id)
	fp_city.hex_id = "0,0"
	fp_rival.hex_id = "2,0"
	(state_farm_prot.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([fp_city.id])
	(state_farm_prot.cells["2,0"] as EvoTypes.HexCell).deme_ids.assign([fp_rival.id])
	(state_farm_prot.cells["0,0"] as EvoTypes.HexCell).temperature = 0.0
	(state_farm_prot.cells["0,0"] as EvoTypes.HexCell).carrying_capacity = 600.0
	(state_farm_prot.cells["0,0"] as EvoTypes.HexCell).current_resources = 600.0
	(state_farm_prot.cells["2,0"] as EvoTypes.HexCell).temperature = 0.0
	(state_farm_prot.cells["2,0"] as EvoTypes.HexCell).carrying_capacity = 300.0
	(state_farm_prot.cells["2,0"] as EvoTypes.HexCell).current_resources = 300.0
	fp_city.population = 285
	fp_city.defense_tier = 2
	fp_city.salubrity = 1.0
	fp_city.energy_reserves = 200.0
	fp_city.last_decision_probabilities = {"dec-selective-migration": 0.85, "dec-cooperate-store": 0.15}
	fp_city.last_dominant_decision_id = "dec-selective-migration"
	fp_rival.population = 65
	fp_rival.defense_tier = 0
	fp_rival.salubrity = 1.0
	fp_rival.energy_reserves = 100.0
	fp_rival.last_decision_probabilities = {"dec-selective-migration": 0.70, "dec-territorial-dispute": 0.30}
	fp_rival.last_dominant_decision_id = "dec-selective-migration"
	var fp_crops_ids: Array[String] = ["1,0", "1,-1", "0,1", "-1,1"]
	for cid in fp_crops_ids:
		var fc: EvoTypes.HexCell = state_farm_prot.cells[cid]
		fc.biome = "savanna"
		fc.altitude = 0.45
		fc.current_resources = 500.0
		fc.owner_deme_id = fp_city.id
		fc.land_use = "crops"
	for cid in ["0,-1", "-1,0"]:
		var wc: EvoTypes.HexCell = state_farm_prot.cells[cid]
		wc.biome = "savanna"
		wc.altitude = 0.45
		wc.current_resources = 500.0
		wc.owner_deme_id = ""
		wc.land_use = "wild"
	for nid in HexMath.get_neighbor_ids(2, 0, state_farm_prot.cells):
		if not fp_crops_ids.has(nid):
			var oc: EvoTypes.HexCell = state_farm_prot.cells[nid]
			oc.biome = "ocean"
			oc.altitude = 0.05
	var fp_vec_city := EvoEcologyInteraction.compute_effective_vector(fp_city, state_farm_prot)
	var fp_vec_rival := EvoEcologyInteraction.compute_effective_vector(fp_rival, state_farm_prot)
	var fp_ext := {
		fp_city.id: float(fp_city.population) * 0.42 * (1.0 + 0.55 * fp_vec_city.metabolic_cost) + 3.0,
		fp_rival.id: float(fp_rival.population) * 0.42 * (1.0 + 0.55 * fp_vec_rival.metabolic_cost)
	}
	EvoDemographyMigration.run_demography_and_migration_phase(
		state_farm_prot,
		"en",
		{fp_city.id: 285, fp_rival.id: 65},
		{fp_city.id: fp_vec_city, fp_rival.id: fp_vec_rival},
		{},
		fp_ext
	)
	var all_crops_protected := true
	for cid in fp_crops_ids:
		var fc: EvoTypes.HexCell = state_farm_prot.cells[cid]
		if not fc.deme_ids.is_empty() or fc.owner_deme_id != fp_city.id or fc.land_use != "crops":
			all_crops_protected = false
			break
	_assert(all_crops_protected, "Neither owning Tier IV city nor adjacent martial rival buds colonists onto active owned crops cells")
	_assert(fp_city.population >= 280 and fp_city.get_village_tier() == 4, "Tier IV city (pop=285, def=2) respects min_keep_pop=280 and does not drop below Tier IV via normal budding")

	# 6c. Proportional Hawk-Dove & Betrayal Cap
	var state_hd_cap := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var sm_hawk: EvoTypes.Deme = state_hd_cap.demes["deme-rift-west"]
	var lg_dove: EvoTypes.Deme = state_hd_cap.demes["deme-rift-east"]
	(state_hd_cap.cells[sm_hawk.hex_id] as EvoTypes.HexCell).deme_ids.erase(sm_hawk.id)
	(state_hd_cap.cells[lg_dove.hex_id] as EvoTypes.HexCell).deme_ids.erase(lg_dove.id)
	sm_hawk.hex_id = "0,0"
	lg_dove.hex_id = "1,0"
	(state_hd_cap.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([sm_hawk.id])
	(state_hd_cap.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([lg_dove.id])
	(state_hd_cap.cells["0,0"] as EvoTypes.HexCell).current_resources = 0.0
	(state_hd_cap.cells["1,0"] as EvoTypes.HexCell).current_resources = 600.0
	sm_hawk.population = 15
	sm_hawk.defense_tier = 0
	sm_hawk.last_decision_probabilities = {"dec-territorial-dispute": 0.80, "dec-conservative-forage": 0.20}
	lg_dove.population = 300
	lg_dove.defense_tier = 3
	lg_dove.last_decision_probabilities = {"dec-cooperate-store": 0.75, "dec-conservative-forage": 0.25}
	var hd_vecs := {
		sm_hawk.id: EvoEcologyInteraction.compute_effective_vector(sm_hawk, state_hd_cap),
		lg_dove.id: EvoEcologyInteraction.compute_effective_vector(lg_dove, state_hd_cap)
	}
	var hd_hawks := {sm_hawk.id: 1.0, lg_dove.id: 1.0}
	var hd_ext := {sm_hawk.id: 0.0, lg_dove.id: 0.0}
	var hd_flows: Array[EvoTypes.HexEdgeFlow] = []
	EvoEcologyInteraction.run_resource_and_symbiosis_phase(state_hd_cap, "en", hd_vecs, hd_hawks, hd_ext, hd_flows)
	var stolen_energy := float(hd_ext[sm_hawk.id])
	_assert(stolen_energy > 0.0 and stolen_energy <= 6.75, "Small Hawk (pop=15) disputing large Dove city (pop=300, def=3) steals at most 0.45 * 15 = 6.75 energy (stole %.4f)" % stolen_energy)

	lg_dove.population = 300
	lg_dove.defense_tier = 2
	lg_dove.energy_reserves = 200.0
	sm_hawk.population = 15
	sm_hawk.energy_reserves = 20.0
	var bet_cap_pk := EvoTypes.make_pair_key(sm_hawk.id, lg_dove.id)
	state_hd_cap.active_pacts[bet_cap_pk] = 3
	EvoEcologyInteraction._execute_betrayal(
		sm_hawk,
		lg_dove,
		state_hd_cap.cells["0,0"],
		state_hd_cap.cells["1,0"],
		bet_cap_pk,
		state_hd_cap,
		"en",
		{sm_hawk.id: 5.0, lg_dove.id: 120.0},
		hd_flows
	)
	_assert((300 - lg_dove.population) <= 7, "Small betrayer (pop=15) betraying large city (pop=300, def=2) inflicts at most int(round(15 * 0.45)) = 7 casualties (inflicted %d)" % (300 - lg_dove.population))

	# 6d. Walled Union Persistence Across Tier Advancement
	var state_wu_persist := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var wu_a: EvoTypes.Deme = state_wu_persist.demes["deme-rift-west"]
	var wu_b: EvoTypes.Deme = state_wu_persist.demes["deme-rift-east"]
	(state_wu_persist.cells[wu_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(wu_a.id)
	(state_wu_persist.cells[wu_b.hex_id] as EvoTypes.HexCell).deme_ids.erase(wu_b.id)
	wu_a.hex_id = "0,0"
	wu_b.hex_id = "1,0"
	(state_wu_persist.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([wu_a.id])
	(state_wu_persist.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([wu_b.id])
	(state_wu_persist.cells["0,0"] as EvoTypes.HexCell).carrying_capacity = 500.0
	(state_wu_persist.cells["0,0"] as EvoTypes.HexCell).current_resources = 500.0
	(state_wu_persist.cells["1,0"] as EvoTypes.HexCell).carrying_capacity = 500.0
	(state_wu_persist.cells["1,0"] as EvoTypes.HexCell).current_resources = 500.0
	var shared_union_id := "union-%s-%s" % [wu_b.id, wu_a.id]
	wu_a.population = 185
	wu_a.defense_tier = 1
	wu_a.walled_union_id = shared_union_id
	wu_a.energy_reserves = 140.0
	wu_a.last_decision_probabilities = {"dec-cooperate-store": 0.70, "dec-conservative-forage": 0.30}
	wu_a.last_dominant_decision_id = "dec-cooperate-store"
	wu_b.population = 155
	wu_b.defense_tier = 1
	wu_b.walled_union_id = shared_union_id
	wu_b.energy_reserves = 140.0
	wu_b.last_decision_probabilities = {"dec-exchange-symbiosis": 0.70, "dec-conservative-forage": 0.30}
	wu_b.last_dominant_decision_id = "dec-exchange-symbiosis"
	state_wu_persist.active_pacts[EvoTypes.make_pair_key(wu_a.id, wu_b.id)] = 5
	EvoBiophysPhase.run_biophysical_phase(state_wu_persist, "en")
	_assert(
		state_wu_persist.demes.has(wu_a.id) and state_wu_persist.demes.has(wu_b.id) and wu_a.walled_union_id == shared_union_id and wu_b.walled_union_id == shared_union_id,
		"Walled Union partners (Tier III pop=%d and Tier II pop=%d) preserve shared walled_union_id across tier advancement without absorbing each other" % [wu_a.population, wu_b.population]
	)



