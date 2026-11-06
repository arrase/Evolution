extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== EVOLUTION GODOT 4 CORE SIMULATION TEST SUITE ===")
	_test_thermodynamics()
	_test_catalog_and_presets()
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

	EvoDecisionModel.wait_for_workers()
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
	_assert(rift.cells.size() == 91, "Rift Savanna radius 5 has 91 cells")
	_assert(rift.demes.size() == 2, "Rift Savanna starts with 2 demes")
	_assert(rift.traits_catalog.size() == 11, "Base catalog has 11 traits (6 bio + 5 cul)")
	_assert(rift.decisions_catalog.size() == 7, "Base catalog has 7 decisions")

	var darwin := EvoCatalog.create_preset_world("preset-darwin-archipelago", "en")
	_assert(darwin.cells.size() == 91, "Darwin Archipelago radius 5 has 91 cells")
	_assert(darwin.demes.size() == 1, "Darwin Archipelago starts with 1 founder deme")
	_assert(darwin.glacial_sea_level_cycle, "Darwin Archipelago has glacial sea level cycle enabled")

	var island := EvoCatalog.create_preset_world("preset-finite-island", "es")
	_assert(island.cells.size() == 61, "Finite Island radius 4 has 61 cells")
	_assert(island.demes.size() == 3, "Finite Island starts with 3 rival clans in 0,0")

	var west: EvoTypes.Deme = rift.demes["deme-rift-west"]
	_assert(EvoCatalog.deme_has_cultural_capacity(west, rift.traits_catalog), "West deme has cultural capacity via bio-social-instinct")
	var injected := EvoCatalog.inject_trait_into_deme(rift, "deme-rift-west", "bio-r-strategy", "es")
	_assert(injected, "Injecting bio-r-strategy succeeds")
	_assert(west.biological_trait_ids.has("bio-r-strategy"), "West deme now has bio-r-strategy")
	_assert(not west.biological_trait_ids.has("bio-k-strategy"), "Mutually exclusive bio-k-strategy was removed")


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


func _test_hawk_dove_and_symbiosis() -> void:
	print("-- Testing Hawk-Dove Dispute & Symbiosis --")
	var state := EvoCatalog.create_preset_world("preset-finite-island", "es")
	var d1: EvoTypes.Deme = state.demes["deme-island-1"]
	var d2: EvoTypes.Deme = state.demes["deme-island-2"]
	var d3: EvoTypes.Deme = state.demes["deme-island-3"]

	# Force Hawk vs Hawk between d1 and d2
	d1.last_decision_probabilities = {"dec-territorial-dispute": 0.60, "dec-conservative-forage": 0.40}
	d2.last_decision_probabilities = {"dec-territorial-dispute": 0.60, "dec-conservative-forage": 0.40}
	d3.last_decision_probabilities = {"dec-conservative-forage": 1.0}
	EvoBiophysPhase.run_biophysical_phase(state, "es")

	var has_dispute_flow := false
	for fl in state.active_flows:
		if fl.flow_type == "dispute":
			has_dispute_flow = true
			break
	_assert(has_dispute_flow, "Hawk vs Hawk generates dispute flow")
	_assert(d1.population < 320 and d2.population < 320, "Hawks suffer casualties and metabolic penalty")

	# Force Symbiosis and Horizontal Cultural Diffusion between d1 and d3
	state.active_flows.clear()
	d1.cultural_trait_ids = ["cul-fire-processing"]
	d3.cultural_trait_ids = []
	d1.last_decision_probabilities = {"dec-exchange-symbiosis": 0.80, "dec-cooperate-store": 0.20}
	d3.last_decision_probabilities = {"dec-exchange-symbiosis": 0.80, "dec-cooperate-store": 0.20}
	d2.last_decision_probabilities = {"dec-conservative-forage": 1.0}
	EvoBiophysPhase.run_biophysical_phase(state, "es")
	_assert(d3.cultural_trait_ids.has("cul-fire-processing"), "Horizontal cultural diffusion transmitted cul-fire-processing to d3")


func _test_tragedy_of_the_commons() -> void:
	print("-- Testing Tragedy of the Commons --")
	var island := EvoCatalog.create_preset_world("preset-finite-island", "es")
	for did in island.demes.keys():
		var d: EvoTypes.Deme = island.demes[did]
		d.last_decision_probabilities = {"dec-intensive-overexploit": 0.65, "dec-territorial-dispute": 0.20, "dec-conservative-forage": 0.15}
		d.last_dominant_decision_id = "dec-intensive-overexploit"
	var tragedy_occurred := false
	for _g in range(12):
		EvoTurnEngine.advance_generation(island, "es")
		for entry in island.chronicle:
			if entry.event_type == "tragedy_of_commons":
				tragedy_occurred = true
				break
		if tragedy_occurred:
			break
	_assert(tragedy_occurred, "Finite Island without conservation triggers Tragedy of the Commons")
	var center_cell: EvoTypes.HexCell = island.cells["0,0"]
	_assert(center_cell.carrying_capacity < 0.60 * center_cell.carrying_capacity_max, "Center cell K degraded below 60% of Kmax")


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
	(state_s.cells["0,0"] as EvoTypes.HexCell).deme_ids.clear()
	founder.hex_id = "0,-2" # North tundra island
	(state_s.cells["0,-2"] as EvoTypes.HexCell).deme_ids.append(founder.id)
	founder.isolation_turns = 10
	var old_lineage := founder.lineage_id
	var old_color := founder.color
	var entries_s := EvoMilestonePhase.run_milestone_phase(state_s, "es")
	_assert(entries_s.size() == 1 and entries_s[0].event_type == "allopatric_speciation", "Allopatric speciation triggers at isolation >= 10 in distinct biome")
	_assert(founder.lineage_id != old_lineage, "Speciated deme receives new lineage ID")
	_assert(founder.color != old_color, "Speciated deme receives new distinct color")
	_assert(state_s.lineage_tree.size() == 2, "Lineage tree now has 2 nodes")


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
	_assert(EvoUserSettings.get_config_dir().ends_with("/.config/Evolution"), "Default config dir points to ~/.config/Evolution")
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
	EvoUserSettings.config_path_override = ""
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
	_assert(main.world_state.cells.size() == 91, "Darwin preset has 91 cells in main")
	main.step_generation()

	main.load_preset("preset-finite-island")
	_assert(main.world_state.preset_id == "preset-finite-island", "Switched to preset-finite-island")
	_assert(main.world_state.cells.size() == 61, "Finite Island preset has 61 cells in main")
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
	var coop_fl := EvoTypes.HexEdgeFlow.new()
	coop_fl.from_hex_id = "0,0"
	coop_fl.to_hex_id = "0,0"
	coop_fl.flow_type = "cooperate"
	coop_fl.from_deme_id = "deme-island-1"
	coop_fl.to_deme_id = "deme-island-2"
	life_state.active_flows.append(coop_fl)
	EvoEnvPhase.run_environmental_phase(life_state, "es")
	_assert(life_state.disused_connections.size() == 1 and int(life_state.disused_connections[0].get("age", -1)) == 0, "Active friendly flow recorded into disused_connections with age 0")
	# Force dispute so the friendly flow is severed
	(life_state.demes["deme-island-1"] as EvoTypes.Deme).last_decision_probabilities = {"dec-territorial-dispute": 0.90, "dec-conservative-forage": 0.10}
	(life_state.demes["deme-island-2"] as EvoTypes.Deme).last_decision_probabilities = {"dec-territorial-dispute": 0.90, "dec-conservative-forage": 0.10}
	EvoBiophysPhase.run_biophysical_phase(life_state, "es")
	_assert(life_state.disused_connections.size() == 1 and int(life_state.disused_connections[0].get("age", 0)) == 1, "Severed friendly flow ages to 1 in biophys_phase")
	main.hud.set_world_state(life_state)
	var rel_lines := main.hud._build_deme_relations_lines(life_state.demes["deme-island-1"] as EvoTypes.Deme)
	_assert(rel_lines.size() >= 2, "HUD inspector preserves both active/severed paths and cohabiting village relations without information loss")

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
		d.biological_trait_ids.assign(["bio-endurance-locomotion", "bio-social-instinct"])
		if i % 3 == 0:
			d.cultural_trait_ids.assign(["cul-cooperative-networks"])
		d.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(d.id)
		state.demes[d.id] = d
		(state.cells[target_hid] as EvoTypes.HexCell).deme_ids.append(d.id)

	_assert(state.demes.size() >= 16, "Late-game stress world populated with %d demes" % state.demes.size())

	var eval_start_usec := Time.get_ticks_usec()
	EvoDecisionModel.evaluate_all_demes(state, "es")
	var eval_ms := float(Time.get_ticks_usec() - eval_start_usec) / 1000.0
	_assert(eval_ms < 15.0, "evaluate_all_demes with 16 demes & live models enabled is non-blocking (took %.3f ms)" % eval_ms)

	# Simulate 6 generations of continuous camera panning + turn progression + rendering rebuilds
	main.world_renderer._process(0.016)
	_assert(not main.world_renderer._column_state_cache.is_empty(), "WorldRenderer column visual state cache populated")
	_assert(not main.world_renderer._cell_flora_cache.is_empty(), "WorldRenderer static flora prop cache populated")

	var max_step_and_frame_ms: float = 0.0
	for step_i in range(6):
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
