class_name EvoTestCoreDomain
extends RefCounted


static func run(r) -> void:
	_test_thermodynamics(r)
	_test_catalog_and_presets(r)
	_test_strategy_duel_and_forge(r)
	_test_serialization(r)


static func _test_thermodynamics(r) -> void:
	print("-- Testing Thermodynamics --")
	var balanced_vec := EvoTypes.BiophysicalVector.new(0.10, 0.25, 0.05, 0.20, 0.10, 0.15)
	var m1 := EvoThermodynamics.evaluate_thermodynamics(balanced_vec)
	r._assert(is_equal_approx(float(m1["positive_advantages"]), 0.55), "Balanced positive advantages == 0.55")
	r._assert(is_equal_approx(float(m1["required_cost"]), 0.0), "No required cost below 0.60 budget")
	r._assert(bool(m1["is_balanced"]), "Vector within 0.60 budget is balanced")

	var unbalanced_vec := EvoTypes.BiophysicalVector.new(0.0, 0.80, 0.10, 0.50, 0.50, 0.20)
	var m2 := EvoThermodynamics.evaluate_thermodynamics(unbalanced_vec)
	# A+ = 1.80 -> C_req = 0.5 * (1.80 - 0.60) = 0.60
	r._assert(is_equal_approx(float(m2["positive_advantages"]), 1.80), "Positive advantages == 1.80")
	r._assert(is_equal_approx(float(m2["required_cost"]), 0.60), "Required cost == 0.60")
	r._assert(not bool(m2["is_balanced"]), "Uncompensated vector is not balanced")

	var fixed_vec := EvoThermodynamics.validate_and_balance_thermodynamics(unbalanced_vec, false)
	var m2_after := EvoThermodynamics.evaluate_thermodynamics(fixed_vec)
	r._assert(bool(m2_after["is_balanced"]), "Validated vector is balanced")
	r._assert(is_equal_approx(fixed_vec.metabolic_cost, 0.60), "Adjusted metabolic cost == 0.60")

	var sandbox_vec := EvoThermodynamics.validate_and_balance_thermodynamics(unbalanced_vec, true)
	r._assert(is_equal_approx(sandbox_vec.metabolic_cost, 0.0), "Free sandbox preserves uncompensated cost")


static func _test_catalog_and_presets(r) -> void:
	print("-- Testing Catalog & Scientific Presets --")
	var rift := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	r._assert(rift.cells.size() == 169, "Rift Savanna radius 7 has 169 cells")
	r._assert(rift.demes.size() == 2, "Rift Savanna starts with 2 demes")
	r._assert(rift.traits_catalog.size() == 11, "Base catalog has 11 traits (6 bio + 5 cul)")
	r._assert(rift.decisions_catalog.size() == 7, "Base catalog has 7 decisions")

	var darwin := EvoCatalog.create_preset_world("preset-darwin-archipelago", "en")
	r._assert(darwin.cells.size() == 169, "Darwin Archipelago radius 7 has 169 cells")
	r._assert(darwin.demes.size() == 2 and darwin.demes.has("deme-darwin-founder") and darwin.demes.has("deme-darwin-rival"), "Darwin Archipelago starts with 2 rival founder demes (1v1)")
	r._assert(darwin.glacial_sea_level_cycle, "Darwin Archipelago has glacial sea level cycle enabled")

	var island := EvoCatalog.create_preset_world("preset-finite-island", "es")
	r._assert(island.cells.size() == 169, "Finite Island radius 7 has 169 cells")
	r._assert(island.demes.size() == 2 and island.demes.has("deme-island-1") and island.demes.has("deme-island-2"), "Finite Island starts with 2 rival clans (1v1)")

	var west: EvoTypes.Deme = rift.demes["deme-rift-west"]
	r._assert(EvoCatalog.deme_has_cultural_capacity(west, rift.traits_catalog), "West deme has cultural capacity via bio-social-instinct")
	var injected := EvoCatalog.inject_trait_into_deme(rift, "deme-rift-west", "bio-r-strategy", "es")
	r._assert(injected, "Injecting bio-r-strategy succeeds")
	r._assert(west.biological_trait_ids.has("bio-r-strategy"), "West deme now has bio-r-strategy")
	r._assert(not west.biological_trait_ids.has("bio-k-strategy"), "Mutually exclusive bio-k-strategy was removed")


static func _test_strategy_duel_and_forge(r) -> void:
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
	r._assert(base_strats.size() == 5, "Base strategies catalog has 5 default strategies")
	for sid in expected_strat_ids:
		r._assert(base_strats.has(sid), "Base strategies catalog includes %s" % sid)
		var s: EvoTypes.StrategyDef = base_strats[sid]
		var vec := EvoCatalog.compute_strategy_vector(s, base_traits)
		r._assert(vec != null and vec.extraction_efficiency > 0.0, "Strategy %s computes valid biophysical vector" % sid)

	# 2. 1v1 strategy matchup initialization in create_preset_world
	var duel_world := EvoCatalog.create_preset_world("preset-rift-savanna", "en", "strat-trade", "strat-innovation")
	r._assert(duel_world.strategy_a_id == "strat-trade" and duel_world.strategy_b_id == "strat-innovation", "Preset world records strategy_a_id and strategy_b_id")
	var west: EvoTypes.Deme = duel_world.demes["deme-rift-west"]
	var east: EvoTypes.Deme = duel_world.demes["deme-rift-east"]
	var strat_trade: EvoTypes.StrategyDef = duel_world.strategies_catalog["strat-trade"]
	var strat_innov: EvoTypes.StrategyDef = duel_world.strategies_catalog["strat-innovation"]
	r._assert(west.strategy_id == "strat-trade" and west.color == strat_trade.color, "Slot A deme receives strat-trade id and color")
	r._assert(west.biological_trait_ids == strat_trade.biological_trait_ids and west.cultural_trait_ids == strat_trade.cultural_trait_ids, "Slot A deme receives strat-trade biological and cultural traits")
	r._assert(east.strategy_id == "strat-innovation" and east.color == strat_innov.color, "Slot B deme receives strat-innovation id and color")
	r._assert(east.biological_trait_ids == strat_innov.biological_trait_ids and east.cultural_trait_ids == strat_innov.cultural_trait_ids, "Slot B deme receives strat-innovation biological and cultural traits")
	var lin_w: EvoTypes.LineageNode = duel_world.lineage_tree[west.lineage_id]
	var lin_e: EvoTypes.LineageNode = duel_world.lineage_tree[east.lineage_id]
	r._assert(lin_w.strategy_id == "strat-trade" and lin_w.color == strat_trade.color and lin_w.biological_trait_ids == strat_trade.biological_trait_ids, "Slot A lineage node synchronized with strat-trade")
	r._assert(lin_e.strategy_id == "strat-innovation" and lin_e.color == strat_innov.color and lin_e.biological_trait_ids == strat_innov.biological_trait_ids, "Slot B lineage node synchronized with strat-innovation")

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
	r._assert(budded_daughter != null and budded_daughter.strategy_id == "strat-trade", "Colonist budding migration preserves parent strategy_id")

	var spec_world := EvoCatalog.create_preset_world("preset-darwin-archipelago", "en", "strat-expansion", "strat-war")
	spec_world.generation = 12
	var darwin_founder: EvoTypes.Deme = spec_world.demes["deme-darwin-founder"]
	(spec_world.cells[darwin_founder.hex_id] as EvoTypes.HexCell).deme_ids.erase(darwin_founder.id)
	darwin_founder.hex_id = "0,-2"
	(spec_world.cells["0,-2"] as EvoTypes.HexCell).deme_ids.append(darwin_founder.id)
	darwin_founder.isolation_turns = 10
	var spec_entries := EvoMilestonePhase.run_milestone_phase(spec_world, "en")
	r._assert(not spec_entries.is_empty() and darwin_founder.strategy_id == "strat-expansion", "Allopatric speciation preserves deme strategy_id")
	r._assert((spec_world.lineage_tree[darwin_founder.lineage_id] as EvoTypes.LineageNode).strategy_id == "strat-expansion", "Allopatric speciation child lineage preserves strategy_id")

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
	r._assert(FileAccess.file_exists(catalog_json_path), "EvoUserSettings.save_user_catalog writes user_catalog.json")

	var fresh_state := EvoTypes.WorldState.new()
	fresh_state.traits_catalog = EvoCatalog.create_base_traits_catalog("en")
	fresh_state.decisions_catalog = EvoCatalog.create_base_decisions_catalog("en")
	fresh_state.strategies_catalog = EvoCatalog.create_base_strategies_catalog("en")
	EvoUserSettings.load_user_catalog_into(fresh_state)
	r._assert(fresh_state.traits_catalog.has("bio-custom-carapace"), "load_user_catalog_into restores custom user trait")
	r._assert(fresh_state.strategies_catalog.has("strat-custom-fortress"), "load_user_catalog_into restores custom user strategy")
	r._assert((fresh_state.strategies_catalog["strat-custom-fortress"] as EvoTypes.StrategyDef).name == "Fortress Doctrine", "Restored custom user strategy preserves name and metadata")

	# 5. UI integration in EvoMainController, EvoMainHud & EvoLabModal
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	r.root.add_child(main)
	if main.camera == null:
		main._ready()
	main.hud._set_startup_blocked(false)

	var opt_a := main.hud.strategy_a_option
	var opt_b := main.hud.strategy_b_option
	r._assert(opt_a != null and opt_b != null and opt_a.item_count >= 5 and opt_b.item_count >= 5, "HUD strategy_a_option and strategy_b_option populated with strategies")
	r._assert(str(opt_a.get_item_metadata(opt_a.selected)) == main.world_state.strategy_a_id, "strategy_a_option selection reflects world_state.strategy_a_id")
	r._assert(str(opt_b.get_item_metadata(opt_b.selected)) == main.world_state.strategy_b_id, "strategy_b_option selection reflects world_state.strategy_b_id")

	main.hud.open_lab_modal()
	var lab := main.hud.lab_modal
	lab._switch_tab("strategy")
	lab._start_new_item()
	var cb_k: CheckBox = lab.strategy_trait_checks["bio-k-strategy"]
	var cb_r: CheckBox = lab.strategy_trait_checks["bio-r-strategy"]
	cb_k.button_pressed = true
	cb_r.button_pressed = true
	r._assert(cb_r.button_pressed and not cb_k.button_pressed, "Lab strategy trait checkboxes enforce mutual exclusion between bio-r-strategy and bio-k-strategy")

	lab.id_edit.text = "strat-custom-duelist"
	lab.name_edit.text = "Duelist Doctrine"
	lab._save_current_item()
	r._assert(main.world_state.strategies_catalog.has("strat-custom-duelist"), "Saving custom strategy in Lab Modal adds it to strategies_catalog")

	main.set_matchup_strategies("strat-custom-duelist", "strat-trade")
	r._assert(main.world_state.generation == 0 and main.world_state.strategy_a_id == "strat-custom-duelist" and main.world_state.strategy_b_id == "strat-trade", "set_matchup_strategies resets to Generation 0 with selected strategies")
	r._assert((main.world_state.demes["deme-rift-west"] as EvoTypes.Deme).strategy_id == "strat-custom-duelist", "Founder deme A updated with custom strategy")

	main.step_generation()
	r._assert(main.world_state.generation == 1, "Generation advances before reset_matchup")
	main.reset_matchup()
	r._assert(main.world_state.generation == 0 and main.world_state.strategies_catalog.has("strat-custom-duelist") and main.world_state.strategy_a_id == "strat-custom-duelist", "reset_matchup resets to Generation 0 and preserves custom user strategies")

	main.hud.select_deme("deme-rift-west")
	r._assert(main.hud.deme_strategy_label != null and "Duelist Doctrine" in main.hud.deme_strategy_label.text, "Inspector deme_strategy_label displays selected village strategy")

	main.free()
	if FileAccess.file_exists(catalog_json_path):
		DirAccess.remove_absolute(catalog_json_path)
	if FileAccess.file_exists(tmp_settings_path):
		DirAccess.remove_absolute(tmp_settings_path)
	if DirAccess.dir_exists_absolute(tmp_dir):
		DirAccess.remove_absolute(tmp_dir)
	EvoUserSettings.config_path_override = r._suite_cfg_path


static func _test_serialization(r) -> void:
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
	r._assert(typeof(parsed) == TYPE_DICTIONARY, "Serialized state parses back as Dictionary")
	var restored := EvoTypes.WorldState.from_dict(parsed as Dictionary)
	r._assert(restored.generation == state.generation, "Restored generation matches")
	r._assert(restored.cells.size() == state.cells.size(), "Restored cells count matches")
	r._assert(restored.demes.size() == state.demes.size(), "Restored demes count matches")
	r._assert(restored.recent_extinction_hexes == state.recent_extinction_hexes, "Restored recent_extinction_hexes matches")
	r._assert(restored.disused_connections.size() == 1 and int(restored.disused_connections[0]["age"]) == 2, "Restored disused_connections matches")
	r._assert(int(restored.previous_populations.get("deme-rift-west", 0)) == 177, "Restored previous_populations matches")
