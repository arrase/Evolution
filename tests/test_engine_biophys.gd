class_name EvoTestEngineBiophys
extends RefCounted


static func run(r) -> void:
	_test_hawk_dove_and_symbiosis(r)
	_test_tragedy_of_the_commons(r)
	_test_baldwin_innovation_and_speciation(r)
	_test_kin_merge_fission_and_macro_outcome(r)
	_test_player_interventions(r)
	_test_multi_generation_stability(r)
	_test_emergent_geopolitics_and_visual_artifacts(r)
	_test_social_memory_defense_tribute_and_synoecism(r)
	_test_epidemic_contagion_and_immunity(r)


static func _test_hawk_dove_and_symbiosis(r) -> void:
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
	r._assert(has_dispute_flow, "Hawk vs Hawk generates dispute flow")
	r._assert(d1.population < init_pop_1 and d2.population < init_pop_2, "Hawks suffer casualties and metabolic penalty")

	# Force Symbiosis and Horizontal Cultural Diffusion between d1 and d2
	state.active_flows.clear()
	d1.cultural_trait_ids.assign(["cul-fire-processing"])
	d2.cultural_trait_ids.clear()
	d1.last_decision_probabilities = {"dec-exchange-symbiosis": 0.80, "dec-cooperate-store": 0.20}
	d2.last_decision_probabilities = {"dec-exchange-symbiosis": 0.80, "dec-cooperate-store": 0.20}
	EvoBiophysPhase.run_biophysical_phase(state, "es")
	r._assert(d2.cultural_trait_ids.has("cul-fire-processing"), "Horizontal cultural diffusion transmitted cul-fire-processing to d2")


static func _test_tragedy_of_the_commons(r) -> void:
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
	r._assert(tragedy_occurred, "Finite Island without conservation triggers Tragedy of the Commons")
	var degraded_cell: EvoTypes.HexCell = island.cells[tragedy_hex_id] if island.cells.has(tragedy_hex_id) else island.cells["1,0"]
	r._assert(degraded_cell.carrying_capacity < 0.60 * degraded_cell.carrying_capacity_max, "Overexploited cell K degraded below 60% of Kmax")


static func _test_baldwin_innovation_and_speciation(r) -> void:
	print("-- Testing Baldwin Effect, Cultural Innovation & Allopatric Speciation --")
	# 1. Baldwin assimilation
	var state_b := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var east_b: EvoTypes.Deme = state_b.demes["deme-rift-east"]
	east_b.baldwin_counters["dec-cooperate-store"] = 8
	east_b.last_dominant_decision_id = "dec-cooperate-store"
	var entries_b := EvoMilestonePhase.run_milestone_phase(state_b, "es")
	r._assert(entries_b.size() == 1 and entries_b[0].event_type == "baldwin_trait", "Baldwin assimilation triggers at counter >= 8")
	r._assert(int(east_b.baldwin_counters["dec-cooperate-store"]) == 0, "Baldwin counter resets to 0 after assimilation")

	# 2. Cultural innovation & dec-explore-innovate eligibility
	var state_c := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var east_c: EvoTypes.Deme = state_c.demes["deme-rift-east"]
	east_c.cultural_trait_ids.clear()
	var innovate_dec: EvoTypes.DecisionDef = state_c.decisions_catalog["dec-explore-innovate"]
	r._assert(EvoDecisionModel.is_decision_eligible(east_c, innovate_dec, state_c.traits_catalog), "dec-explore-innovate is eligible for deme with cultural capacity")
	var non_cultural_deme := east_c.duplicate_deme()
	non_cultural_deme.biological_trait_ids.assign(["bio-k-strategy"])
	r._assert(not EvoDecisionModel.is_decision_eligible(non_cultural_deme, innovate_dec, state_c.traits_catalog), "dec-explore-innovate requires cultural capacity")

	east_c.innovation_counter = 1.15
	east_c.last_energy_delta = 5.0
	var entries_c := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	r._assert(entries_c.size() == 1 and entries_c[0].event_type == "cultural_innovation", "Cultural innovation triggers at counter >= 1.0")
	r._assert(east_c.cultural_trait_ids.size() == 1, "Deme acquires 1st newly synthesized cultural tradition")

	east_c.innovation_counter = 1.25
	east_c.last_energy_delta = 5.0
	var entries_c2 := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	r._assert(entries_c2.size() == 1 and entries_c2[0].event_type == "cultural_innovation" and east_c.cultural_trait_ids.size() == 2, "Deme can acquire a 2nd emergent cultural trait (emergent_cul_count < 2)")

	east_c.innovation_counter = 1.25
	east_c.last_energy_delta = 5.0
	var entries_c3 := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	r._assert(entries_c3.is_empty() and east_c.cultural_trait_ids.size() == 2, "Cultural innovation caps at 2 emergent cultural traits")

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
	r._assert(entries_s.size() == 1 and entries_s[0].event_type == "allopatric_speciation", "Allopatric speciation triggers at isolation >= 10 in distinct biome")
	r._assert(founder.lineage_id != old_lineage, "Speciated deme receives new lineage ID")
	r._assert(founder.color != old_color, "Speciated deme receives new distinct color")
	r._assert(state_s.lineage_tree.size() == 3, "Lineage tree now has 3 nodes (2 initial + 1 speciated)")


static func _test_kin_merge_fission_and_macro_outcome(r) -> void:
	print("-- Testing Kin Merge Flow Redirection, Fission Bottleneck & Macro-Outcome Trigger --")
	# 1. Kin merging redirects from_deme_id and to_deme_id without corrupting inter-hex flow recipients
	var state_m := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var deme_a: EvoTypes.Deme = state_m.demes["deme-rift-west"]
	var deme_c: EvoTypes.Deme = state_m.demes["deme-rift-east"]
	(state_m.cells[deme_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(deme_a.id)
	deme_a.hex_id = "0,0"
	deme_a.population = 140
	deme_a.defense_tier = 1
	(state_m.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([deme_a.id])
	var deme_b := deme_a.duplicate_deme()
	deme_b.id = "deme-rift-west-m1"
	deme_b.name = "Clan Kin B"
	deme_b.hex_id = "-1,0"
	deme_b.population = 45
	deme_b.defense_tier = 0
	state_m.demes[deme_b.id] = deme_b
	(state_m.cells["-1,0"] as EvoTypes.HexCell).deme_ids.assign([deme_b.id])
	state_m.active_pacts[EvoTypes.make_pair_key(deme_a.id, deme_b.id)] = 3

	var inter_flow := EvoTypes.HexEdgeFlow.new()
	inter_flow.from_hex_id = "-1,0"
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
		d.last_decision_probabilities = {"dec-cooperate-store": 0.60, "dec-conservative-forage": 0.40}
		d.last_dominant_decision_id = "dec-cooperate-store"

	EvoDemographyMigration.run_demography_and_migration_phase(state_m, "es", initial_pops_m, eff_vecs_m, {}, ext_energy_m)
	r._assert(not state_m.demes.has(deme_b.id), "Kin deme_b merged into deme_a")
	var preserved_recipient := false
	for fl in state_m.active_flows:
		if fl.flow_type == "exchange" and fl.from_deme_id == deme_a.id and fl.from_hex_id == deme_a.hex_id and fl.to_deme_id == deme_c.id:
			preserved_recipient = true
			break
	r._assert(preserved_recipient, "Kin merge redirects from_deme_id to deme_a without overwriting inter-hex recipient deme_c")

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
	r._assert(parent_d.population < 50 and parent_d.cultural_trait_ids.has("cul-fire-processing") and not had_cultural_loss, "Healthy parent deme dropping below 50 pop solely due to fission migration does not suffer false cultural_loss")

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
	r._assert(state_mo.macro_outcome_type != "" and not bool(res_mo2["has_macro_outcome"]), "has_macro_outcome is false on subsequent turns after macro-outcome was already logged")


static func _test_player_interventions(r) -> void:
	print("-- Testing Player Interventions (Brushes) --")
	var state := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	state.selective_pressure_points = 100
	var targets: Array[String] = ["0,0"]

	var ok_biome := EvoTurnEngine.apply_set_biome(state, targets, "tundra", "es")
	var c0: EvoTypes.HexCell = state.cells["0,0"]
	var tundra_defs: Dictionary = EvoTypes.BIOME_CLIMATE_DEFAULTS["tundra"]
	r._assert(ok_biome and c0.biome == "tundra", "set_biome changes cell biome to tundra")
	r._assert(
		is_equal_approx(c0.seasonal_regen_rate, float(tundra_defs["regen"])) and is_equal_approx(c0.carrying_capacity_max, float(tundra_defs["k_max"])),
		"set_biome updates seasonal_regen_rate and carrying_capacity_max from BIOME_CLIMATE_DEFAULTS"
	)
	r._assert(state.selective_pressure_points == 90, "set_biome costs 10 points")

	var ok_alt := EvoTurnEngine.apply_adjust_altitude(state, targets, 0.18, "es")
	r._assert(ok_alt and state.selective_pressure_points == 75, "adjust_altitude costs 15 points")

	var ok_cap := EvoTurnEngine.apply_adjust_carrying_capacity(state, targets, 0.25)
	r._assert(ok_cap and state.selective_pressure_points == 65, "adjust_carrying_capacity costs 10 points")

	var prev_sea := state.sea_level
	var ok_sea := EvoTurnEngine.apply_adjust_sea_level(state, 0.05, "es")
	r._assert(ok_sea and is_equal_approx(state.sea_level, prev_sea + 0.05), "adjust_sea_level raises sea level by 0.05")
	r._assert(state.selective_pressure_points == 40, "adjust_sea_level costs 25 points")


static func _test_multi_generation_stability(r) -> void:
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
		r._assert(state.generation == 25, "%s reached generation 25 cleanly" % preset_id)
		for did in state.demes.keys():
			var deme: EvoTypes.Deme = state.demes[did]
			var sum_p: float = 0.0
			for p in deme.last_decision_probabilities.values():
				sum_p += float(p)
			r._assert(is_equal_approx(sum_p, 1.0), "%s deme %s probabilities sum to 1.0 at G25" % [preset_id, did])


static func _test_emergent_geopolitics_and_visual_artifacts(r) -> void:
	print("-- Testing Emergent Biophysical Geopolitics, Pacts, Raids, Betrayals, War & Visual Artifacts --")
	# 1. Strategy baseline probability differentiation & environmental weight modulation
	var state_base := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	var sample_deme: EvoTypes.Deme = state_base.demes["deme-rift-west"]

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-war")
	r._assert(sample_deme.last_dominant_decision_id == "dec-territorial-dispute", "strat-war baseline dominant decision is dec-territorial-dispute")
	var war_base_disp := float(sample_deme.last_decision_probabilities.get("dec-territorial-dispute", 0.0))

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-cooperation")
	r._assert(sample_deme.last_dominant_decision_id == "dec-cooperate-store", "strat-cooperation baseline dominant decision is dec-cooperate-store")

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-trade")
	r._assert(sample_deme.last_dominant_decision_id == "dec-exchange-symbiosis", "strat-trade baseline dominant decision is dec-exchange-symbiosis")

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-expansion")
	r._assert(sample_deme.last_dominant_decision_id == "dec-selective-migration", "strat-expansion baseline dominant decision is dec-selective-migration")

	EvoCatalog.apply_strategy_to_deme(state_base, sample_deme, "strat-innovation")
	r._assert(sample_deme.last_dominant_decision_id == "dec-explore-innovate", "strat-innovation baseline dominant decision is dec-explore-innovate")
	r._assert(war_base_disp > float(sample_deme.last_decision_probabilities.get("dec-territorial-dispute", 0.0)), "strat-war has higher baseline dispute weight than strat-innovation")

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
	r._assert(ab_w.last_dominant_decision_id != "dec-territorial-dispute", "In ecological abundance, strat-war does not default to territorial dispute")
	r._assert(ab_e.last_dominant_decision_id in ["dec-conservative-forage", "dec-cooperate-store"], "In ecological abundance, strat-cooperation favors peaceful foraging/storage")
	EvoBiophysPhase.run_biophysical_phase(state_ab, "en")
	var ab_conflicts := 0
	for fl in state_ab.active_flows:
		if fl.flow_type in ["war", "raid", "betrayal"]:
			ab_conflicts += 1
	r._assert(ab_conflicts == 0, "Zero wars, raids, or betrayals occur during ecological abundance")

	# Induce scarcity and verify dispute weight rises for martial deme
	state_ab.season = "dry_cold"
	(state_ab.cells["0,0"] as EvoTypes.HexCell).current_resources = 20.0
	ab_w.energy_reserves = 20.0
	ab_w.population = 75
	EvoCatalog.compute_strategy_baseline_probabilities(ab_w, state_ab.traits_catalog)
	EvoHeuristicScorer.modulate_deme_probabilities_for_turn(ab_w, state_ab.cells["0,0"], state_ab)
	var sc_disp_w := float(ab_w.last_decision_probabilities.get("dec-territorial-dispute", 0.0))
	r._assert(sc_disp_w > ab_disp_w, "Environmental scarcity + surplus neighbor increases martial dispute probability (%.3f > %.3f)" % [sc_disp_w, ab_disp_w])

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
	r._assert(EvoTypes.is_pact_active(state_pact, p_d1.id, p_d2.id), "Active pact forms after 2 consecutive cooperative/exchange turns")
	var has_pact_chronicle := false
	for e in state_pact.chronicle:
		if e.event_type == "pact":
			has_pact_chronicle = true
			break
	r._assert(has_pact_chronicle, "Chronicle logs formal pact event on turn 2")
	var has_pact_flow := false
	for fl in state_pact.active_flows:
		if fl.flow_type == "pact":
			has_pact_flow = true
			break
	r._assert(has_pact_flow, "Active pact emits 'pact' HexEdgeFlow")
	var def_bonus := EvoEcologyInteraction.compute_pact_defense_bonus(p_d1, state_pact)
	r._assert(def_bonus > 0.15, "Active pact provides mutual defense bonus (%.2f)" % def_bonus)

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
	r._assert(p_d1.energy_reserves > 20.0 and p_d2.energy_reserves < 130.0, "Pact risk-pooling transfers reserves from wealthy ally to distressed ally (%.1f, %.1f)" % [p_d1.energy_reserves, p_d2.energy_reserves])
	r._assert(not pact_geo_flows.is_empty(), "Ecology phase populates turn_geopolitical_flows")

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
	r._assert(not EvoTypes.is_pact_active(state_bet, b_d1.id, b_d2.id), "Betrayal erases active pact from state.active_pacts")
	r._assert(b_d1.energy_reserves > 16.0 and b_d2.energy_reserves < 135.0, "Betrayal plunders surprise loot from victim reserves to betrayer")
	r._assert(b_d2.population < b2_pop_before, "Betrayal inflicts surprise casualties on victim")
	r._assert(not state_bet.disused_connections.is_empty() and int(state_bet.disused_connections[0].get("age", 0)) >= 1, "Betrayal records severed road in state.disused_connections")
	var has_betrayal_flow := false
	for fl in state_bet.active_flows:
		if fl.flow_type == "betrayal":
			has_betrayal_flow = true
			break
	r._assert(has_betrayal_flow, "Betrayal emits 'betrayal' HexEdgeFlow")
	var has_betrayal_chronicle := false
	for e in state_bet.chronicle:
		if e.event_type == "betrayal":
			has_betrayal_chronicle = true
			break
	r._assert(has_betrayal_chronicle, "Betrayal logs 'betrayal' ChronicleEntry")

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
	r._assert(has_raid_flow, "Cross-border raid emits 'raid' HexEdgeFlow")
	r._assert(r_att.energy_reserves > 24.0 and r_vic.energy_reserves < 115.0, "Raid steals reserves from wealthy neighbor (raider %.1f, victim %.1f)" % [r_att.energy_reserves, r_vic.energy_reserves])
	var has_raid_chronicle := false
	for e in state_raid.chronicle:
		if e.event_type == "raid":
			has_raid_chronicle = true
			break
	r._assert(has_raid_chronicle, "Raid logs 'raid' ChronicleEntry")

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
	r._assert(war_events_count >= 1 and war_flows_seen >= 1, "strat-war marches and triggers real territorial invasions ('war' events=%d, flows=%d) in multi-turn simulation" % [war_events_count, war_flows_seen])
	r._assert(warband_created, "Territorial invasion spawns conquering warband demes ('-w') in target hexes")

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
		r._assert(FileAccess.file_exists(file_path), "Generated sprite PNG exists on disk: %s" % file_path)
		var tex := EvoPixelArtGen.get_texture(skey)
		r._assert(tex != null and tex.get_width() >= 16 and tex.get_height() >= 16, "Loaded sprite Texture2D is valid and non-empty: %s" % skey)

	for icon_key in ["war", "raid", "pact", "betrayal"]:
		var ui_tex := EvoUiStyle.get_pixel_icon(icon_key)
		r._assert(ui_tex != null, "EvoUiStyle.get_pixel_icon('%s') returns valid Texture2D" % icon_key)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	r.root.add_child(main)
	if main.camera == null:
		main._ready()

	main.world_state = state_pact
	main.world_renderer.set_world_state(state_pact)
	main.hud.set_world_state(state_pact)
	main.world_renderer._rebuild()
	main.world_renderer._process(0.016)

	var pact_summary := EvoHudInspectorPanel.format_active_pacts_summary(state_pact, "en", p_d1)
	r._assert(pact_summary.contains("🤝"), "EvoHudInspectorPanel.format_active_pacts_summary displays active pact partner")
	var pact_rel_lines := EvoHudInspectorPanel.build_deme_relations_lines(state_pact, "en", p_d1)
	r._assert(not pact_rel_lines.is_empty(), "EvoHudInspectorPanel.build_deme_relations_lines includes pact & relation lines")
	var pact_rel_texts_en: Array[String] = []
	for item in pact_rel_lines:
		pact_rel_texts_en.append(str(item["text"]))
	r._assert(not ("\n".join(pact_rel_texts_en)).contains("{partner}"), "EvoHudInspectorPanel.build_deme_relations_lines substitutes {partner} placeholder in English")
	var pact_rel_lines_es := EvoHudInspectorPanel.build_deme_relations_lines(state_pact, "es", p_d1)
	var pact_rel_texts_es: Array[String] = []
	for item in pact_rel_lines_es:
		pact_rel_texts_es.append(str(item["text"]))
	r._assert(not ("\n".join(pact_rel_texts_es)).contains("{partner}") and ("\n".join(pact_rel_texts_es)).contains("Pacto activo con "), "EvoHudInspectorPanel.build_deme_relations_lines substitutes {partner} placeholder in Spanish")

	main.hud.open_notebook_modal()
	for f_key in ["war", "raid", "pact", "betrayal"]:
		r._assert(main.hud.notebook_modal._filter_buttons.has(f_key), "EvoNotebookModal has filter button for '%s'" % f_key)
		main.hud.notebook_modal._on_filter_pressed(f_key)
		r._assert(main.hud.notebook_modal._active_filter == f_key, "EvoNotebookModal switches active filter to '%s'" % f_key)
	main.hud.notebook_modal.close_modal()

	main.free()


static func _test_social_memory_defense_tribute_and_synoecism(r) -> void:
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

	r._assert(
		EvoHeuristicScorer._format_neighbor_occupant_label(d_focus, d_rival, state_mem) == "rival:martial:stronger:def0",
		"Neighbor occupant label formats rival martial stronger deme with defense tier"
	)
	r._assert(
		EvoHeuristicScorer._format_neighbor_occupant_label(d_focus, d_kin, state_mem) == "kin:forage:weaker:def1",
		"Neighbor occupant label formats kin forage weaker deme with defense tier"
	)
	r._assert(
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

	r._assert(
		EvoHeuristicScorer._format_neighbor_occupant_label(d_focus, d_rival, state_mem) == "vendetta:martial:stronger:def0",
		"Neighbor occupant label reflects active vendetta against rival"
	)
	var geo_sum := EvoHeuristicScorer.build_geopolitics_summary(d_focus, state_mem.cells["0,0"], state_mem)
	r._assert(int(geo_sum.get("active_pacts", -1)) == 1, "build_geopolitics_summary reports active_pacts == 1")
	r._assert(int(geo_sum.get("active_vendettas", -1)) == 1, "build_geopolitics_summary reports active_vendettas == 1")
	r._assert(int(geo_sum.get("defense_tier", -1)) == 2, "build_geopolitics_summary reports defense_tier == 2")
	r._assert(bool(geo_sum.get("horde_threat", false)), "build_geopolitics_summary detects nearby horde_threat")
	var mem_str := str(geo_sum.get("memory", ""))
	r._assert(
		mem_str.contains("raided@G4") and mem_str.contains("vendettas=1") and mem_str.contains("horde_nearby"),
		"build_geopolitics_summary memory digest includes raid history, vendettas and horde threat (%s)" % mem_str
	)

	var compact_state := EvoHeuristicScorer.build_compact_system_one_state(d_focus, state_mem)
	r._assert(compact_state.contains("def=Lv2, merged=1"), "build_compact_system_one_state includes def=Lv2 and merged=1")
	r._assert(compact_state.contains("memory=") and compact_state.contains("raided@G4"), "build_compact_system_one_state includes historical memory")
	r._assert(compact_state.contains(":def"), "build_compact_system_one_state Neighbors list includes relational labels and defense tier")
	r._assert(compact_state.contains("\"active_vendettas\":1") and compact_state.contains("\"defense_tier\":2"), "build_compact_system_one_state geopolitics JSON includes active_vendettas and defense_tier")

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
	r._assert(d_def.defense_tier == 0, "Deme starts at defense_tier 0")

	var res_before_t1 := d_def.energy_reserves
	var cell_before_t1 := def_cell.current_resources
	EvoEcologyInteraction._run_defense_fortification_phase(state_def, "en", def_arch_probs)
	r._assert(d_def.defense_tier == 1, "_run_defense_fortification_phase upgrades defense_tier 0 -> 1 (Palisade)")
	r._assert(d_def.energy_reserves < res_before_t1 and def_cell.current_resources < cell_before_t1, "Tier 1 fortification consumes deme reserves and hex resources")

	EvoEcologyInteraction._run_defense_fortification_phase(state_def, "en", def_arch_probs)
	r._assert(d_def.defense_tier == 2, "_run_defense_fortification_phase upgrades defense_tier 1 -> 2 (Stone Wall)")

	EvoEcologyInteraction._run_defense_fortification_phase(state_def, "en", def_arch_probs)
	r._assert(d_def.defense_tier == 3, "_run_defense_fortification_phase upgrades defense_tier 2 -> 3 (Castle)")
	var fortify_chronicles := 0
	for e in state_def.chronicle:
		if e.event_type == "fortify" and e.deme_id == d_def.id:
			fortify_chronicles += 1
	r._assert(fortify_chronicles >= 2, "Upgrading to Tier 2 and Tier 3 logs 'fortify' ChronicleEntries")

	state_def.season = "dry_cold"
	d_att.population = 110
	d_att.energy_reserves = 20.0
	(state_def.cells["1,0"] as EvoTypes.HexCell).current_resources = 15.0
	d_att.last_decision_probabilities = {"dec-territorial-dispute": 0.60, "dec-intensive-overexploit": 0.25, "dec-conservative-forage": 0.15}
	var vec_att := EvoEcologyInteraction.compute_effective_vector(d_att, state_def)
	var raid_ext_map := {d_att.id: 10.0, d_def.id: 85.0}
	r._assert(
		not EvoEcologyInteraction._can_attempt_raid(d_att, d_def, state_def.cells["1,0"], state_def, vec_att, raid_ext_map, [0.05, 0.05, 0.60, 0.25]),
		"Tier 3 Castle is immune to _can_attempt_raid"
	)
	d_def.defense_tier = 0
	r._assert(
		EvoEcologyInteraction._can_attempt_raid(d_att, d_def, state_def.cells["1,0"], state_def, vec_att, raid_ext_map, [0.05, 0.05, 0.60, 0.25]),
		"Undefended deme (Tier 0) is vulnerable to _can_attempt_raid under same conditions"
	)
	var forces_t0 := EvoDemographyMigration._compute_combat_forces(d_att, 55, d_def, state_def)
	d_def.defense_tier = 3
	var forces_t3 := EvoDemographyMigration._compute_combat_forces(d_att, 55, d_def, state_def)
	r._assert(forces_t3.y > forces_t0.y * 1.50, "Tier 3 Castle significantly boosts defender force in _compute_combat_forces (%.1f vs %.1f)" % [forces_t3.y, forces_t0.y])

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
	r._assert(t_raider.population == 85 and t_trader.population == 45, "Paying tribute avoids raid casualties on both sides")
	r._assert(t_raider.energy_reserves > 22.0, "Raider receives tribute energy reserves (%.1f)" % t_raider.energy_reserves)
	var trib_pk := EvoTypes.make_pair_key(t_raider.id, t_trader.id)
	r._assert(int(state_trib.active_pacts.get(trib_pk, 0)) == 1, "Tribute establishes temporary truce (active_pacts == 1)")
	var has_tribute_flow := false
	for fl in state_trib.active_flows:
		if fl.flow_type == "tribute":
			has_tribute_flow = true
			break
	r._assert(has_tribute_flow, "Tribute payment emits 'tribute' HexEdgeFlow")
	var has_tribute_chronicle := false
	for e in state_trib.chronicle:
		if e.event_type == "tribute":
			has_tribute_chronicle = true
			break
	r._assert(has_tribute_chronicle, "Tribute payment logs 'tribute' ChronicleEntry")

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
	r._assert(int(state_trib.active_pacts.get(trib_pk, 0)) <= -2 and EvoTypes.is_vendetta_active(state_trib, t_raider.id, t_trader.id), "Raid sets negative active_pacts and activates vendetta")
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
	r._assert(int(state_trib.active_pacts.get(trib_pk, 0)) == -4 and EvoTypes.is_vendetta_active(state_trib, t_raider.id, t_trader.id), "Betrayal sets active_pacts to -4 (deep vendetta)")

	# 4. City Unification (Synoecism), Asymmetric Absorption & Multi-Hex Walled Unions
	# 4a. Asymmetric Category Absorption into a Tier 4 Metropolis with active_pacts >= 3
	var state_syn1 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var s1_a: EvoTypes.Deme = state_syn1.demes["deme-rift-west"]
	var s1_b: EvoTypes.Deme = state_syn1.demes["deme-rift-east"]
	(state_syn1.cells[s1_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(s1_a.id)
	(state_syn1.cells[s1_b.hex_id] as EvoTypes.HexCell).deme_ids.erase(s1_b.id)
	s1_a.hex_id = "0,0"
	s1_b.hex_id = "1,0"
	(state_syn1.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([s1_a.id])
	(state_syn1.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([s1_b.id])
	s1_a.population = 185
	s1_b.population = 125
	s1_a.defense_tier = 2
	s1_b.defense_tier = 0
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
	r._assert(state_syn1.demes.size() == 1, "Asymmetric Category Absorption (active_pacts >= 3) merges 2 allied demes into 1 unified city")
	r._assert(s1_a.merged_count >= 1, "Unified city increments merged_count (%d)" % s1_a.merged_count)
	r._assert(s1_a.population > 280, "Unified city combines populations (%d)" % s1_a.population)
	r._assert(s1_a.secondary_color == s1_b_color and s1_a.secondary_color != "", "Unified city records partner secondary_color (%s)" % s1_a.secondary_color)
	r._assert(s1_a.get_village_tier() == 4 and s1_a.get_village_roman() == "IV", "Unified citadel/metropolis reaches Tier 4 ('IV')")
	r._assert(
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
	r._assert(state_syn2.demes.size() == 1, "Asymmetric Category Absorption (tier_a != tier_b, active_pacts >= 4) absorbs lower-tier neighbor into host city")
	r._assert(s2_a.merged_count == 1 and s2_a.secondary_color == s2_b_color, "Host city sets merged_count == 1 and secondary_color")
	r._assert(s2_a.defense_tier >= 2, "Asymmetric absorption elevates host city defense_tier (%d)" % s2_a.defense_tier)
	var vacated_cell: EvoTypes.HexCell = state_syn2.cells["1,0"]
	r._assert(
		vacated_cell.deme_ids.is_empty() and vacated_cell.owner_deme_id == s2_a.id and vacated_cell.land_use in ["crops", "pasture"],
		"Asymmetric absorption converts vacated neighbor hex into rural hinterland (%s) owned by host city" % vacated_cell.land_use
	)
	var has_merge_flow := false
	for fl in state_syn2.active_flows:
		if fl.flow_type == "merge" and fl.from_hex_id == "1,0" and fl.to_hex_id == "0,0":
			has_merge_flow = true
			break
	r._assert(has_merge_flow, "Asymmetric absorption emits inter-hex 'merge' HexEdgeFlow")
	var has_merge_chronicle := false
	for e in state_syn2.chronicle:
		if e.event_type == "merge":
			has_merge_chronicle = true
			break
	r._assert(has_merge_chronicle, "Synoecism logs 'merge' ChronicleEntry")
	EvoMilestonePhase.run_milestone_phase(state_syn2, "en")
	r._assert(state_syn2.macro_outcome_type != "single_survivor", "Peaceful city unification does not falsely trigger single_survivor extinction outcome")

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
	r._assert(state_union.demes.size() == 2, "Same-category Multi-Hex Walled Union keeps both demes on their own hexes")
	r._assert(
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
	r._assert(union_forces.y > solo_forces.y * 1.25, "Walled union partner pools garrison population and fortification defense bonus (%.1f vs %.1f)" % [union_forces.y, solo_forces.y])

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
	r._assert(claimed_crops + claimed_pasture == 2 and claimed_crops >= 1 and claimed_pasture >= 1, "Tier 3 city claims both 'crops' and 'pasture' adjacent rural hinterlands")
	r._assert(float(r_ext[r_city.id]) > 40.0, "Rural hinterlands provide caloric harvest yield bonus to owning city (%.1f)" % float(r_ext[r_city.id]))

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
	r._assert(raid_ok and pillaged_ruins, "Successful raid pillages an owned rural hinterland hex (land_use='wild', has_ruins=true)")

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
	r._assert(has_epidemic_entry and e_deme.population < 200, "Overcrowded unsanitary city (salubrity < 0.35, pop >= 130) triggers 'epidemic' outbreak and casualties")

	# 4f. Strict 1-Deme-Per-Hex Invariant across multi-gen simulation, flood relocation, warband invasion & budding, plus Camera Yaw Lock
	var cam := EvoCameraController.new()
	r._assert(is_equal_approx(cam.yaw_deg, 0.0), "EvoCameraController locks yaw_deg to 0.0")
	cam.free()

	var inv_state := EvoPresets.create_preset_world("preset-darwin-archipelago", "en", "strat-expansion", "strat-war")
	var max_demes_per_cell := 0
	for _step in range(10):
		EvoTurnEngine.advance_generation(inv_state, "en")
		for cid in inv_state.cells.keys():
			var c: EvoTypes.HexCell = inv_state.cells[cid]
			if c.deme_ids.size() > max_demes_per_cell:
				max_demes_per_cell = c.deme_ids.size()
	r._assert(max_demes_per_cell <= 1, "Strict 1-deme-per-hex invariant (cell.deme_ids.size() <= 1) holds across 10 generations of expansion, war, and sea-level changes")

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
		r._assert(FileAccess.file_exists(file_path), "New Phase 3 sprite PNG exists on disk: %s" % file_path)
		var tex := EvoPixelArtGen.get_texture(skey)
		r._assert(tex != null and tex.get_width() >= 16 and tex.get_height() >= 16, "Loaded Phase 3 sprite Texture2D is valid and non-empty: %s" % skey)

	for icon_key in ["defense", "merge", "tribute", "siege", "fortify"]:
		var ui_tex := EvoUiStyle.get_pixel_icon(icon_key)
		r._assert(ui_tex != null, "EvoUiStyle.get_pixel_icon('%s') returns valid Texture2D" % icon_key)

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
	r._assert(not repel_invaded and (240 - repel_def.population) <= 4, "Small repelled warband (warband_pop=30) inflicts at most 4 casualties on fortified city (pop=240, def=2)")
	r._assert(repel_def.defense_tier == 2, "Small repelled warband does not downgrade fortified city's defense_tier (remains 2)")
	r._assert(repel_farm.owner_deme_id == repel_def.id and repel_farm.land_use == "crops" and not repel_farm.has_ruins, "Small repelled warband does not destroy or unclaim fortified city's active crops cell")

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
	r._assert(all_crops_protected, "Neither owning Tier IV city nor adjacent martial rival buds colonists onto active owned crops cells")
	r._assert(fp_city.population >= 280 and fp_city.get_village_tier() == 4, "Tier IV city (pop=285, def=2) respects min_keep_pop=280 and does not drop below Tier IV via normal budding")

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
	r._assert(stolen_energy > 0.0 and stolen_energy <= 6.75, "Small Hawk (pop=15) disputing large Dove city (pop=300, def=3) steals at most 0.45 * 15 = 6.75 energy (stole %.4f)" % stolen_energy)

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
	r._assert((300 - lg_dove.population) <= 7, "Small betrayer (pop=15) betraying large city (pop=300, def=2) inflicts at most int(round(15 * 0.45)) = 7 casualties (inflicted %d)" % (300 - lg_dove.population))

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
	r._assert(
		state_wu_persist.demes.has(wu_a.id) and state_wu_persist.demes.has(wu_b.id) and wu_a.walled_union_id == shared_union_id and wu_b.walled_union_id == shared_union_id,
		"Walled Union partners (Tier III pop=%d and Tier II pop=%d) preserve shared walled_union_id across tier advancement without absorbing each other" % [wu_a.population, wu_b.population]
	)


static func _test_epidemic_contagion_and_immunity(r) -> void:
	print("-- Testing Deterministic Epidemic Contagion & Immunity --")
	var state := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	for cid in state.cells.keys():
		(state.cells[cid] as EvoTypes.HexCell).deme_ids.clear()
	state.demes.clear()
	state.active_pacts.clear()
	state.turn_events.clear()
	state.chronicle.clear()

	var d_source := EvoTypes.Deme.new()
	d_source.id = "deme-epi-source"
	d_source.name = "Source Clan"
	d_source.hex_id = "0,0"
	d_source.population = 110
	d_source.salubrity = 0.30
	d_source.infection_turns = 2
	d_source.immunity_turns = 0
	d_source.lineage_id = "lineage-west"
	d_source.strategy_id = "strat-cooperation"
	d_source.color = "#10b981"

	var d_susceptible := EvoTypes.Deme.new()
	d_susceptible.id = "deme-epi-susceptible"
	d_susceptible.name = "Susceptible Clan"
	d_susceptible.hex_id = "1,0"
	d_susceptible.population = 100
	d_susceptible.salubrity = 0.50
	d_susceptible.infection_turns = 0
	d_susceptible.immunity_turns = 0
	d_susceptible.lineage_id = "lineage-west"
	d_susceptible.strategy_id = "strat-cooperation"
	d_susceptible.color = "#10b981"

	var d_healthy := EvoTypes.Deme.new()
	d_healthy.id = "deme-epi-healthy"
	d_healthy.name = "Healthy Clan"
	d_healthy.hex_id = "0,1"
	d_healthy.population = 100
	d_healthy.salubrity = 0.85
	d_healthy.infection_turns = 0
	d_healthy.immunity_turns = 0
	d_healthy.lineage_id = "lineage-east"
	d_healthy.strategy_id = "strat-trade"
	d_healthy.color = "#f59e0b"

	state.demes[d_source.id] = d_source
	state.demes[d_susceptible.id] = d_susceptible
	state.demes[d_healthy.id] = d_healthy
	(state.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([d_source.id])
	(state.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([d_susceptible.id])
	(state.cells["0,1"] as EvoTypes.HexCell).deme_ids.assign([d_healthy.id])
	(state.cells["0,0"] as EvoTypes.HexCell).carrying_capacity = 50.0
	(state.cells["0,0"] as EvoTypes.HexCell).humidity = 0.0
	(state.cells["1,0"] as EvoTypes.HexCell).carrying_capacity = 60.0
	(state.cells["1,0"] as EvoTypes.HexCell).humidity = 0.0
	(state.cells["0,1"] as EvoTypes.HexCell).carrying_capacity = 450.0
	(state.cells["0,1"] as EvoTypes.HexCell).humidity = 0.5

	state.active_pacts[EvoTypes.make_pair_key(d_source.id, d_susceptible.id)] = 3
	state.active_pacts[EvoTypes.make_pair_key(d_source.id, d_healthy.id)] = 3

	var zero_vec := EvoTypes.BiophysicalVector.new()
	var vecs := {
		d_source.id: zero_vec,
		d_susceptible.id: zero_vec,
		d_healthy.id: zero_vec
	}
	var hawks := {d_source.id: 1.0, d_susceptible.id: 1.0, d_healthy.id: 1.0}
	var ext := {d_source.id: 50.0, d_susceptible.id: 50.0, d_healthy.id: 50.0}

	state.generation = 1
	EvoDemographyMigration.run_demography_and_migration_phase(
		state,
		"en",
		{d_source.id: d_source.population, d_susceptible.id: d_susceptible.population, d_healthy.id: d_healthy.population},
		vecs,
		hawks,
		ext
	)

	r._assert(d_susceptible.infection_turns == 2, "Susceptible pact partner (salubrity < 0.70) catches contagion with infection_turns == 2")
	r._assert(d_healthy.infection_turns == 0, "Healthy pact partner (salubrity >= 0.70) resists epidemic contagion")
	var has_spread_event := false
	for ev in state.turn_events:
		if str(ev["type"]) == "epidemic_spread" and str(ev["to_deme"]) == d_susceptible.id:
			has_spread_event = true
			break
	var has_spread_chronicle := false
	for entry in state.chronicle:
		if entry.event_type == "epidemic_spread" and entry.deme_id == d_susceptible.id:
			has_spread_chronicle = true
			break
	r._assert(has_spread_event and has_spread_chronicle, "Contagion emits 'epidemic_spread' in both state.turn_events and state.chronicle")
	r._assert(d_source.infection_turns == 1, "Source deme decrements infection_turns from 2 to 1 after first turn")

	# Advance d_source through remaining infection turn -> recovery + immunity_turns == 6
	state.generation = 2
	state.turn_events.clear()
	EvoDemographyMigration.run_demography_and_migration_phase(
		state,
		"en",
		{d_source.id: d_source.population, d_susceptible.id: d_susceptible.population, d_healthy.id: d_healthy.population},
		vecs,
		hawks,
		ext
	)
	r._assert(d_source.infection_turns == 0 and d_source.immunity_turns == 6, "Recovered deme transitions to infection_turns == 0 and immunity_turns == 6")
	var has_recovered_event := false
	for ev in state.turn_events:
		if str(ev["type"]) == "epidemic_recovered" and str(ev["from_deme"]) == d_source.id:
			has_recovered_event = true
			break
	r._assert(has_recovered_event, "Epidemic recovery emits 'epidemic_recovered' in state.turn_events")

	# Verify immunity_turns > 0 prevents reinfection even if salubrity < 0.35 and population >= 130
	d_source.salubrity = 0.15
	d_source.population = 180
	(state.cells["0,0"] as EvoTypes.HexCell).carrying_capacity = 30.0
	state.generation = 3
	state.turn_events.clear()
	EvoDemographyMigration.run_demography_and_migration_phase(
		state,
		"en",
		{d_source.id: d_source.population, d_susceptible.id: d_susceptible.population, d_healthy.id: d_healthy.population},
		vecs,
		hawks,
		{d_source.id: 80.0, d_susceptible.id: 50.0, d_healthy.id: 50.0}
	)
	r._assert(d_source.infection_turns == 0 and d_source.immunity_turns == 5, "Immune deme (immunity_turns > 0) cannot be reinfected even when salubrity < 0.35 and population >= 130")
