class_name EvoTestEngineBiophys
extends RefCounted


static func run(r) -> void:
	_test_payoffs_and_canonical_scenarios(r)
	_test_rk_and_biophysical_trait_divergence(r)
	_test_rural_defense_postures_and_scorched_ruins(r)
	_test_tragedy_of_the_commons(r)
	_test_fortify_innovate_baldwin_and_speciation(r)
	_test_diplomacy_trade_aid_pacts_and_tribute(r)
	_test_conflict_raids_betrayal_conquest_and_kin_feuds(r)
	_test_multi_hex_fusion_corridors_and_partial_conquest(r)
	_test_player_interventions_and_multi_gen_stability(r)
	_test_epidemic_contagion_and_immunity(r)


static func _place_deme(state: EvoTypes.WorldState, deme: EvoTypes.Deme, hex_id: String) -> void:
	for old_hid in deme.urban_hex_ids:
		if state.cells.has(old_hid):
			(state.cells[old_hid] as EvoTypes.HexCell).deme_ids.erase(deme.id)
	if state.cells.has(deme.hex_id):
		(state.cells[deme.hex_id] as EvoTypes.HexCell).deme_ids.erase(deme.id)
	deme.hex_id = hex_id
	deme.urban_hex_ids = [hex_id]
	var cell: EvoTypes.HexCell = state.cells[hex_id]
	cell.biome = "savanna"
	cell.altitude = 0.45
	cell.owner_deme_id = ""
	cell.land_use = "wild"
	cell.ruin_turns = 0
	cell.has_ruins = false
	cell.deme_ids.assign([deme.id])


static func _test_payoffs_and_canonical_scenarios(r) -> void:
	print("-- Testing EvoPayoffs Monotonicity & Canonical Scenario Forecasts --")
	var state := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var att: EvoTypes.Deme = state.demes["deme-rift-west"]
	var def: EvoTypes.Deme = state.demes["deme-rift-east"]
	_place_deme(state, att, "0,0")
	_place_deme(state, def, "1,0")

	att.population = 110
	def.population = 70
	def.defense_tier = 0
	def.energy_reserves = 120.0
	var odds_base: Dictionary = EvoPayoffs.raid_odds(att, def, state, false)
	var odds_surprise: Dictionary = EvoPayoffs.raid_odds(att, def, state, true)
	def.defense_tier = 2
	var odds_walled: Dictionary = EvoPayoffs.raid_odds(att, def, state, false)
	def.defense_tier = 3
	var odds_castle: Dictionary = EvoPayoffs.raid_odds(att, def, state, false)
	r._assert(float(odds_surprise["p_win"]) > float(odds_base["p_win"]), "Surprise betrayal boosts raid p_win (%.2f > %.2f)" % [float(odds_surprise["p_win"]), float(odds_base["p_win"])])
	r._assert(float(odds_base["p_win"]) > float(odds_walled["p_win"]), "Defender walls reduce raid p_win (%.2f > %.2f)" % [float(odds_base["p_win"]), float(odds_walled["p_win"])])
	r._assert(float(odds_castle["loot"]) < float(odds_base["loot"]) * 0.30, "Tier 3 Castle shields non-surprise raid loot")

	def.defense_tier = 0
	var conq_base: Dictionary = EvoPayoffs.conquest_odds(att, def, state)
	def.defense_tier = 2
	var conq_walled: Dictionary = EvoPayoffs.conquest_odds(att, def, state)
	r._assert(float(conq_base["p_win"]) > float(conq_walled["p_win"]), "Defender walls reduce conquest p_win (%.2f > %.2f)" % [float(conq_base["p_win"]), float(conq_walled["p_win"])])

	# Canonical Scenario 1: Open virgin frontier -> settle option present with daughter camp forecast
	att.population = 120
	att.energy_reserves = 140.0
	var menu_frontier := EvoActionMenu.build(att, state)
	var found_settle := false
	for opt in menu_frontier:
		if str(opt["type"]) == "settle":
			found_settle = true
			var fc := EvoOutcomeForecast.describe(att, opt, state)
			r._assert(fc.contains("Found a new ") and fc.contains("camp") and fc.contains("settlers"), "Settle forecast quantifies new daughter camp and settlers")
			break
	r._assert(found_settle, "Action menu includes settle option when r-strategy thresholds are met")

	# Canonical Scenario 2: Complementary biome neighbor -> trade forecast shows positive food and trust gain
	(state.cells["0,0"] as EvoTypes.HexCell).biome = "savanna"
	(state.cells["1,0"] as EvoTypes.HexCell).biome = "alluvial_plains"
	var trade_opt := EvoActionMenu.option("trade", def.id)
	var trade_fc := EvoOutcomeForecast.describe(att, trade_opt, state)
	r._assert(trade_fc.contains("Trade with") and trade_fc.contains("trust +0.12"), "Trade forecast quantifies mutual trade yield and trust gain")

	# Canonical Scenario 3: Tribute demand from last turn -> pay_tribute option appears and quantifies raid risk
	state.generation = 2
	var rel: EvoTypes.Relation = EvoTypes.get_relation(state, att.id, def.id)
	rel.proposal_from = att.id
	rel.proposal_kind = "tribute"
	rel.proposal_amount = 24.0
	rel.proposal_gen = 1
	def.energy_reserves = 90.0
	var menu_def := EvoActionMenu.build(def, state)
	var has_pay_trib := false
	for opt in menu_def:
		if str(opt["type"]) == "pay_tribute" and str(opt["target"]) == att.id:
			has_pay_trib = true
			var fc := EvoOutcomeForecast.describe(def, opt, state)
			r._assert(fc.contains("truce") and fc.contains("immediately raid with"), "pay_tribute forecast highlights truce and raid threat if refused")
	r._assert(has_pay_trib, "Defender menu includes pay_tribute when tribute demand from previous turn is active")

	# Canonical Scenario 4: Active alliance + rich target -> warrior betray option appears with surprise loot & reputation cost
	rel.proposal_from = ""
	rel.proposal_kind = ""
	rel.pact_turns = 4
	def.energy_reserves = 180.0
	def.defense_tier = 0
	var menu_betray := EvoActionMenu.build(att, state)
	var has_betray := false
	for opt in menu_betray:
		if str(opt["type"]) == "betray" and str(opt["target"]) == def.id:
			has_betray = true
			var fc := EvoOutcomeForecast.describe(att, opt, state)
			r._assert(fc.contains("surprise attack") and fc.contains("reputation -0.50"), "betray forecast quantifies surprise loot and reputation cost")
	r._assert(has_betray, "Allied neighbor unlocks betray option in warrior action menu")


static func _test_rk_and_biophysical_trait_divergence(r) -> void:
	print("-- Testing r/K Thresholds, Logistic Growth, Ecological Impact & Barter Yield --")
	var state := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-expansion", "strat-cooperation")
	var d_r: EvoTypes.Deme = state.demes["deme-rift-west"]
	var d_k: EvoTypes.Deme = state.demes["deme-rift-east"]
	_place_deme(state, d_r, "0,0")
	_place_deme(state, d_k, "0,3")

	r._assert(EvoPayoffs.settle_min_pop(d_r) == 65 and EvoPayoffs.settle_min_pop(d_k) == 145, "r-strategy settles at lower pop threshold (65 vs 145 for K-strategy)")
	r._assert(EvoPayoffs.settle_min_reserves(d_r) < EvoPayoffs.settle_min_reserves(d_k), "r-strategy requires lower food buffer to settle (32 vs 75)")

	# At pop 100: r-strategy sends ~34 settlers and unlocks settle; K-strategy at pop 100 cannot settle yet (needs 145; at 150 sends ~36 leaving >=114)
	d_r.population = 100
	d_r.energy_reserves = 80.0
	d_k.population = 100
	d_k.energy_reserves = 80.0
	r._assert(EvoPayoffs.settlers(d_r) == 34, "r-strategy sends 34% settlers at pop 100")
	var r_has_settle := EvoActionMenu.build(d_r, state).any(func(o: Dictionary) -> bool: return str(o["type"]) == "settle")
	var k_has_settle := EvoActionMenu.build(d_k, state).any(func(o: Dictionary) -> bool: return str(o["type"]) == "settle")
	r._assert(r_has_settle and not k_has_settle, "At pop 100, strat-expansion unlocks settle while K-selected strat-cooperation waits to build urban density")

	# Logistic growth below 0.6K: r-strategy grows faster than K-strategy on identical cell
	var cell_r: EvoTypes.HexCell = state.cells[d_r.hex_id]
	var cell_k: EvoTypes.HexCell = state.cells[d_k.hex_id]
	cell_r.carrying_capacity = 300.0
	cell_r.carrying_capacity_max = 300.0
	cell_k.carrying_capacity = 300.0
	cell_k.carrying_capacity_max = 300.0
	d_r.population = 90
	d_k.population = 90
	d_r.salubrity = 0.85
	d_k.salubrity = 0.85
	var g_r := EvoPayoffs.growth_rate(d_r, state)
	var g_k := EvoPayoffs.growth_rate(d_k, state)
	r._assert(g_r > g_k, "Below 0.6K, bio-r-strategy logistic growth_rate exceeds bio-k-strategy (%.4f > %.4f)" % [g_r, g_k])

	# Ecological impact scales habitat wear vs recovery during harvest_all
	var state_eco := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var d_war: EvoTypes.Deme = state_eco.demes["deme-rift-west"]
	var d_coop: EvoTypes.Deme = state_eco.demes["deme-rift-east"]
	_place_deme(state_eco, d_war, "-2,0")
	_place_deme(state_eco, d_coop, "2,0")
	var c_war: EvoTypes.HexCell = state_eco.cells["-2,0"]
	var c_coop: EvoTypes.HexCell = state_eco.cells["2,0"]
	c_war.carrying_capacity_max = 300.0
	c_war.carrying_capacity = 240.0
	c_coop.carrying_capacity_max = 300.0
	c_coop.carrying_capacity = 240.0
	d_war.chosen_action = EvoActionMenu.option("raid", d_coop.id)
	d_coop.chosen_action = EvoActionMenu.option("forage")
	EvoEconomyPhase.harvest(state_eco, "en")
	r._assert(c_war.carrying_capacity < 240.0 and c_coop.carrying_capacity > 240.0, "Negative ecological_impact depletes K on non-forage turns while cul-communal-conservation restores K")

	# cul-interdeme-barter boosts trade_gain (+25% one partner, +45% mutual merchants)
	var state_tr := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-expansion")
	var ta: EvoTypes.Deme = state_tr.demes["deme-rift-west"]
	var tb: EvoTypes.Deme = state_tr.demes["deme-rift-east"]
	_place_deme(state_tr, ta, "0,0")
	_place_deme(state_tr, tb, "1,0")
	(state_tr.cells["0,0"] as EvoTypes.HexCell).biome = "savanna"
	(state_tr.cells["1,0"] as EvoTypes.HexCell).biome = "alluvial_plains"
	ta.cultural_trait_ids.erase("cul-interdeme-barter")
	tb.cultural_trait_ids.erase("cul-interdeme-barter")
	var gain_none := EvoPayoffs.trade_gain(ta, tb, state_tr)
	ta.cultural_trait_ids.append("cul-interdeme-barter")
	var gain_one := EvoPayoffs.trade_gain(ta, tb, state_tr)
	tb.cultural_trait_ids.append("cul-interdeme-barter")
	var gain_both := EvoPayoffs.trade_gain(ta, tb, state_tr)
	r._assert(gain_one > gain_none and gain_both > gain_one, "cul-interdeme-barter increases exchange/accept_trade yield (%.1f < %.1f < %.1f)" % [gain_none, gain_one, gain_both])


static func _test_rural_defense_postures_and_scorched_ruins(r) -> void:
	print("-- Testing Rural Defense Postures & 3-Turn Persistent Scorched Ruins --")
	var state := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var att: EvoTypes.Deme = state.demes["deme-rift-west"]
	var def: EvoTypes.Deme = state.demes["deme-rift-east"]
	_place_deme(state, att, "0,0")
	_place_deme(state, def, "1,0")
	def.population = 140
	def.defense_tier = 1
	EvoRuralHinterland.claim_hinterlands(state)
	var def_fields := EvoRuralHinterland.owned_hexes(def, state)
	r._assert(not def_fields.is_empty(), "Defender claims cultivated field before posture tests")

	# 1. Harvest multipliers across open_harvest, patrol_fields, mobilized_garrison
	def.defense_posture = "open_harvest"
	var h_open := EvoPayoffs.urban_harvest(def, state, "forage")
	var r_open := EvoRuralHinterland.rural_yield_estimate(def, state)
	def.defense_posture = "patrol_fields"
	var h_patrol := EvoPayoffs.urban_harvest(def, state, "forage")
	var r_patrol := EvoRuralHinterland.rural_yield_estimate(def, state)
	def.defense_posture = "mobilized_garrison"
	var h_garrison := EvoPayoffs.urban_harvest(def, state, "forage")
	var r_garrison := EvoRuralHinterland.rural_yield_estimate(def, state)
	r._assert(is_equal_approx(float(EvoPayoffs.POSTURE_HARVEST_MULT["open_harvest"]), 1.0) and h_open > h_patrol and h_patrol > h_garrison, "Home harvest scales monotonically with defense_posture (%.1f > %.1f > %.1f)" % [h_open, h_patrol, h_garrison])
	r._assert(r_open > r_patrol and r_patrol > r_garrison, "Rural field yield scales monotonically with defense_posture (%.1f > %.1f > %.1f)" % [r_open, r_patrol, r_garrison])

	# 2. Raid interception bonus across postures
	att.population = 140
	def.defense_posture = "open_harvest"
	var p_open := float(EvoPayoffs.raid_odds(att, def, state, false)["p_win"])
	def.defense_posture = "patrol_fields"
	var p_patrol := float(EvoPayoffs.raid_odds(att, def, state, false)["p_win"])
	def.defense_posture = "mobilized_garrison"
	var p_garrison := float(EvoPayoffs.raid_odds(att, def, state, false)["p_win"])
	r._assert(p_open > p_patrol and p_patrol > p_garrison, "Escalating rural defense posture lowers attacker raid p_win (%.2f > %.2f > %.2f)" % [p_open, p_patrol, p_garrison])

	# 3. Crop-burning protection: patrol_fields saves crops when p_win < 0.72, burns when p_win >= 0.72; mobilized_garrison saves crops on non-surprise raids
	var target_field := EvoPayoffs.closest_defender_field(att, def, state)
	target_field.current_resources = 200.0
	def.defense_posture = "patrol_fields"
	var res_patrol_save := EvoConflictPhase._pillage_field(att, def, state, false, 0.65)
	r._assert(not bool(res_patrol_save["scorched"]) and target_field.owner_deme_id == def.id and target_field.ruin_turns == 0, "patrol_fields saves crops from burning when raid p_win < 0.72")

	def.defense_posture = "mobilized_garrison"
	var res_garrison_save := EvoConflictPhase._pillage_field(att, def, state, false, 0.90)
	r._assert(not bool(res_garrison_save["scorched"]) and target_field.owner_deme_id == def.id and target_field.ruin_turns == 0, "mobilized_garrison saves crops against non-surprise raids even at high p_win")

	def.defense_posture = "patrol_fields"
	var res_patrol_burn := EvoConflictPhase._pillage_field(att, def, state, false, 0.80)
	r._assert(bool(res_patrol_burn["scorched"]) and target_field.ruin_turns == 3 and target_field.has_ruins and target_field.owner_deme_id == "", "patrol_fields loses field to 3-turn scorched ruins when overwhelming raid p_win >= 0.72")

	# 4. Persistent Scorched Ruins: blocked from claiming/harvesting/settling for 3 turns, reported in SituationReport, decrements cleanly in EvoEnvPhase
	var sit_ruins := EvoSituationReport.build(def, state)
	r._assert(sit_ruins.contains("scorched ruins (3 turns to recover)"), "EvoSituationReport reports active scorched ruins with remaining recovery turns")

	for expected_after in [2, 1, 0]:
		EvoRuralHinterland.claim_hinterlands(state)
		r._assert(target_field.owner_deme_id == "" and target_field.land_use == "wild", "Scorched ruin cannot be reclaimed while ruin_turns > 0")
		var settle_ids := EvoActionMenu.settle_targets(def, state).map(func(c: EvoTypes.HexCell) -> String: return c.id)
		r._assert(not settle_ids.has(target_field.id), "Scorched ruin cannot be settled while ruin_turns > 0")
		EvoEnvPhase.run_environmental_phase(state, "en")
		r._assert(target_field.ruin_turns == expected_after, "EvoEnvPhase decrements ruin_turns to %d" % expected_after)

	r._assert(not target_field.has_ruins, "has_ruins clears automatically once ruin_turns reaches 0")
	def.population = 210
	target_field.current_resources = 999.0
	EvoRuralHinterland.claim_hinterlands(state)
	r._assert(target_field.owner_deme_id != "", "Recovered field (ruin_turns == 0) can be reclaimed again")


static func _test_tragedy_of_the_commons(r) -> void:
	print("-- Testing Tragedy of the Commons via Repeated Intensify --")
	var island := EvoCatalog.create_preset_world("preset-finite-island", "es")
	var tragedy_occurred := false
	var tragedy_hex_id := ""
	for _g in range(14):
		for did in island.demes.keys():
			var d: EvoTypes.Deme = island.demes[did]
			d.chosen_action = EvoActionMenu.option("intensify")
		EvoTurnEngine.advance_generation(island, "es")
		for entry in island.chronicle:
			if entry.event_type == "tragedy_of_commons":
				tragedy_occurred = true
				tragedy_hex_id = entry.hex_id
				break
		if tragedy_occurred:
			break
	r._assert(tragedy_occurred, "Repeated intensive extraction on Finite Island triggers Tragedy of the Commons")
	var degraded_cell: EvoTypes.HexCell = island.cells[tragedy_hex_id]
	r._assert(degraded_cell.carrying_capacity < 0.60 * degraded_cell.carrying_capacity_max, "Overexploited cell K degraded below 60% of Kmax")


static func _test_fortify_innovate_baldwin_and_speciation(r) -> void:
	print("-- Testing Fortify, Innovate, Baldwin Assimilation & Allopatric Speciation --")
	# 1. Multi-tier fortification (0 -> 1 -> 2 -> 3)
	var state_f := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	var d_f: EvoTypes.Deme = state_f.demes["deme-rift-west"]
	var c_f: EvoTypes.HexCell = state_f.cells[d_f.hex_id]
	d_f.population = 130
	d_f.energy_reserves = 300.0
	c_f.current_resources = 500.0
	for target_tier in [1, 2, 3]:
		d_f.chosen_action = EvoActionMenu.option("fortify")
		EvoEconomyPhase.invest(state_f, "en")
		r._assert(d_f.defense_tier == target_tier, "Fortify action upgrades defense_tier to %d" % target_tier)
	var fortify_logs := 0
	for e in state_f.chronicle:
		if e.event_type == "fortify" and e.deme_id == d_f.id:
			fortify_logs += 1
	r._assert(fortify_logs >= 2, "Upgrading to Tier 2 and Tier 3 logs 'fortify' ChronicleEntries")

	# 2. Innovate action & Cultural Innovation milestone (caps at MAX_EMERGENT_CULTURAL == 3)
	var state_c := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var east_c: EvoTypes.Deme = state_c.demes["deme-rift-east"]
	east_c.cultural_trait_ids.clear()
	east_c.energy_reserves = 120.0
	east_c.chosen_action = EvoActionMenu.option("innovate")
	EvoEconomyPhase.invest(state_c, "es")
	r._assert(east_c.innovation_counter > 0.0, "Innovate action advances innovation_counter (%.2f)" % east_c.innovation_counter)

	for expected_count in [1, 2, 3]:
		east_c.innovation_counter = 1.20
		east_c.last_energy_delta = 5.0
		var entries_ci := EvoMilestonePhase.run_milestone_phase(state_c, "es")
		r._assert(entries_ci.size() == 1 and entries_ci[0].event_type == "cultural_innovation" and east_c.cultural_trait_ids.size() == expected_count, "Deme acquires emergent cultural trait #%d" % expected_count)

	east_c.innovation_counter = 1.25
	east_c.last_energy_delta = 5.0
	var entries_c4 := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	r._assert(entries_c4.is_empty() and east_c.cultural_trait_ids.size() == EvoActionMenu.MAX_EMERGENT_CULTURAL, "Cultural innovation caps at MAX_EMERGENT_CULTURAL (3) emergent traits")

	# 3. Baldwin assimilation
	var state_b := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var east_b: EvoTypes.Deme = state_b.demes["deme-rift-east"]
	east_b.baldwin_counters["intensify"] = 8
	east_b.chosen_action = EvoActionMenu.option("intensify")
	var entries_b := EvoMilestonePhase.run_milestone_phase(state_b, "es")
	r._assert(entries_b.size() == 1 and entries_b[0].event_type == "baldwin_trait", "Baldwin assimilation triggers at counter >= 8")
	r._assert(int(east_b.baldwin_counters["intensify"]) == 0, "Baldwin counter resets to 0 after assimilation")

	# 4. Allopatric speciation
	var state_s := EvoCatalog.create_preset_world("preset-darwin-archipelago", "es")
	state_s.generation = 12
	var founder: EvoTypes.Deme = state_s.demes["deme-darwin-founder"]
	(state_s.cells[founder.hex_id] as EvoTypes.HexCell).deme_ids.erase(founder.id)
	founder.hex_id = "0,-2"
	founder.urban_hex_ids = ["0,-2"]
	(state_s.cells["0,-2"] as EvoTypes.HexCell).deme_ids.append(founder.id)
	founder.isolation_turns = 10
	var old_lineage := founder.lineage_id
	var old_color := founder.color
	var entries_s := EvoMilestonePhase.run_milestone_phase(state_s, "es")
	r._assert(entries_s.size() == 1 and entries_s[0].event_type == "allopatric_speciation", "Allopatric speciation triggers at isolation >= 10")
	r._assert(founder.lineage_id != old_lineage and founder.color != old_color, "Speciated deme receives new lineage ID and distinct color")
	r._assert(state_s.lineage_tree.size() == 3, "Lineage tree now has 3 nodes")


static func _test_diplomacy_trade_aid_pacts_and_tribute(r) -> void:
	print("-- Testing Diplomacy: Reciprocal Trade, Aid, Pacts & Tribute Coercion --")
	var state := EvoPresets.create_preset_world("preset-finite-island", "en", "strat-cooperation", "strat-trade")
	var d1: EvoTypes.Deme = state.demes["deme-island-1"]
	var d2: EvoTypes.Deme = state.demes["deme-island-2"]
	_place_deme(state, d1, "0,0")
	_place_deme(state, d2, "1,0")

	# 1. Reciprocal Trade + Horizontal Cultural Diffusion
	d1.cultural_trait_ids.assign(["cul-fire-processing"])
	d2.cultural_trait_ids.clear()
	d1.chosen_action = EvoActionMenu.option("trade", d2.id)
	d2.chosen_action = EvoActionMenu.option("trade", d1.id)
	EvoBiophysPhase.run_biophysical_phase(state, "en")
	r._assert(d2.cultural_trait_ids.has("cul-fire-processing"), "Reciprocal trade diffuses cul-fire-processing to partner")
	r._assert(EvoTypes.get_relation(state, d1.id, d2.id).trust > 0.0, "Reciprocal trade increases bilateral trust")

	# 2. Aid transfer
	d1.energy_reserves = 140.0
	d2.energy_reserves = 20.0
	var rep_before := d1.reputation
	d1.chosen_action = EvoActionMenu.option("aid", d2.id)
	d2.chosen_action = EvoActionMenu.option("forage")
	EvoDiplomacyPhase.resolve(state, "en")
	r._assert(d2.energy_reserves > 20.0 and d1.reputation > rep_before, "Aid transfers food reserves to neighbor and raises sender reputation")

	# 3. Mutual offer_pact forms active alliance
	d1.chosen_action = EvoActionMenu.option("offer_pact", d2.id)
	d2.chosen_action = EvoActionMenu.option("offer_pact", d1.id)
	EvoDiplomacyPhase.resolve(state, "en")
	r._assert(EvoTypes.is_pact_active(state, d1.id, d2.id), "Mutual offer_pact forms active alliance")
	var has_pact_chronicle := state.chronicle.any(func(e: EvoTypes.ChronicleEntry) -> bool: return e.event_type == "pact")
	r._assert(has_pact_chronicle, "Pact formation logs 'pact' ChronicleEntry")
	r._assert(EvoPayoffs.pact_multiplier(d1, state) > 1.0, "Active pact provides harvest multiplier bonus")

	# 4. Demand Tribute -> Pay Tribute vs Refusal
	var rel: EvoTypes.Relation = EvoTypes.get_relation(state, d1.id, d2.id)
	rel.pact_turns = 0
	d1.population = 130
	d2.population = 55
	d1.energy_reserves = 40.0
	d2.energy_reserves = 100.0
	d1.chosen_action = EvoActionMenu.option("demand_tribute", d2.id)
	d2.chosen_action = EvoActionMenu.option("forage")
	EvoDiplomacyPhase.resolve(state, "en")
	r._assert(rel.proposal_kind == "tribute" and rel.proposal_from == d1.id, "demand_tribute posts tribute proposal for next turn")

	state.generation += 1
	var d1_res_before := d1.energy_reserves
	d1.chosen_action = EvoActionMenu.option("forage")
	d2.chosen_action = EvoActionMenu.option("pay_tribute", d1.id)
	EvoDiplomacyPhase.resolve(state, "en")
	r._assert(d1.energy_reserves > d1_res_before and rel.truce_turns == EvoPayoffs.TRUCE_AFTER_TRIBUTE, "pay_tribute transfers food and grants truce")
	var has_trib_chronicle := state.chronicle.any(func(e: EvoTypes.ChronicleEntry) -> bool: return e.event_type == "tribute")
	r._assert(has_trib_chronicle, "pay_tribute logs 'tribute' ChronicleEntry")

	# Demand tribute again and refuse -> punitive raid & feud_turns > 0
	rel.truce_turns = 0
	d1.chosen_action = EvoActionMenu.option("demand_tribute", d2.id)
	d2.chosen_action = EvoActionMenu.option("forage")
	EvoDiplomacyPhase.resolve(state, "en")
	state.generation += 1
	d1.chosen_action = EvoActionMenu.option("forage")
	d2.chosen_action = EvoActionMenu.option("forage")
	EvoDiplomacyPhase.resolve(state, "en")
	EvoConflictPhase.resolve(state, "en")
	r._assert(EvoTypes.is_vendetta_active(state, d1.id, d2.id), "Ignoring a tribute demand triggers punitive raid and active feud/vendetta")


static func _test_conflict_raids_betrayal_conquest_and_kin_feuds(r) -> void:
	print("-- Testing Conflict: Raids, Distance-2 Border Raids, Kin Feuds, Betrayal & Monotonic Warband IDs --")
	# 1. Adjacent Raid + Scorched Rural Hinterland Pillaging
	var state_r := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var r_att: EvoTypes.Deme = state_r.demes["deme-rift-west"]
	var r_def: EvoTypes.Deme = state_r.demes["deme-rift-east"]
	_place_deme(state_r, r_att, "0,0")
	_place_deme(state_r, r_def, "1,0")
	var farm_cell: EvoTypes.HexCell = state_r.cells["1,-1"]
	farm_cell.biome = "savanna"
	farm_cell.altitude = 0.45
	farm_cell.current_resources = 200.0
	farm_cell.owner_deme_id = r_def.id
	farm_cell.land_use = "crops"

	r_att.population = 180
	r_att.energy_reserves = 25.0
	r_def.population = 35
	r_def.defense_tier = 0
	r_def.defense_posture = "open_harvest"
	r_def.energy_reserves = 150.0
	r_att.chosen_action = EvoActionMenu.option("raid", r_def.id)
	r_def.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_r, "en")
	r._assert(r_att.energy_reserves > 25.0 and r_def.energy_reserves < 150.0, "Adjacent raid loots food reserves from defender")
	r._assert(farm_cell.has_ruins and farm_cell.ruin_turns == 3 and farm_cell.land_use == "wild" and farm_cell.owner_deme_id == "", "Raid on open_harvest defender burns field into 3-turn ruins")
	r._assert(EvoTypes.is_vendetta_active(state_r, r_att.id, r_def.id), "Raid activates bilateral feud/vendetta")

	# 2. Distance-2 Cross-Border Crop Raid: pillages border field without looting urban granary
	var state_d2 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var d2_att: EvoTypes.Deme = state_d2.demes["deme-rift-west"]
	var d2_def: EvoTypes.Deme = state_d2.demes["deme-rift-east"]
	_place_deme(state_d2, d2_att, "0,0")
	_place_deme(state_d2, d2_def, "2,0")
	var border_crop: EvoTypes.HexCell = state_d2.cells["1,0"]
	border_crop.biome = "savanna"
	border_crop.altitude = 0.45
	border_crop.current_resources = 220.0
	border_crop.owner_deme_id = d2_def.id
	border_crop.land_use = "crops"
	d2_att.population = 240
	d2_att.energy_reserves = 40.0
	d2_def.population = 50
	d2_def.defense_tier = 1
	d2_def.defense_posture = "open_harvest"
	d2_def.energy_reserves = 160.0

	var d2_menu := EvoActionMenu.build(d2_att, state_d2)
	var has_d2_raid := d2_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "raid" and str(o["target"]) == d2_def.id)
	var has_d2_trib := d2_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "demand_tribute" and str(o["target"]) == d2_def.id)
	var has_d2_conq := d2_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "conquer" and str(o["target"]) == d2_def.id)
	r._assert(has_d2_raid and has_d2_trib and not has_d2_conq, "Distance-2 crop contact unlocks cross-border raid and demand_tribute without urban conquer")

	var d2_odds := EvoPayoffs.raid_odds(d2_att, d2_def, state_d2, false)
	r._assert(bool(d2_odds["border_only"]) and is_equal_approx(float(d2_odds["granary_loot"]), 0.0) and float(d2_odds["field_loot"]) > 0.0, "Distance-2 border raid sets border_only == true and granary_loot == 0")

	state_d2.rng.seed = 42
	d2_att.chosen_action = EvoActionMenu.option("raid", d2_def.id)
	d2_def.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_d2, "en")
	r._assert(is_equal_approx(d2_def.energy_reserves, 160.0) and d2_att.energy_reserves > 40.0 and border_crop.ruin_turns == 3, "Distance-2 border raid plunders & scorches border field while leaving urban granary untouched")

	# 3. Kin Blood-Feud Retaliation: peaceful kin protected, feuding kin targetable for raid & conquer
	var state_kin := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-war")
	var kin_a: EvoTypes.Deme = state_kin.demes["deme-rift-west"]
	var kin_b: EvoTypes.Deme = state_kin.demes["deme-rift-east"]
	kin_b.lineage_id = kin_a.lineage_id
	_place_deme(state_kin, kin_a, "0,0")
	_place_deme(state_kin, kin_b, "1,0")
	kin_a.population = 200
	kin_a.energy_reserves = 150.0
	kin_b.population = 45
	kin_b.energy_reserves = 100.0
	var kin_rel := EvoTypes.get_relation(state_kin, kin_a.id, kin_b.id)
	kin_rel.feud_turns = 0
	var peaceful_kin_menu := EvoActionMenu.build(kin_a, state_kin)
	r._assert(not peaceful_kin_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) in ["raid", "conquer"] and str(o["target"]) == kin_b.id), "Peaceful kin (feud_turns == 0) are protected from raid and conquer in ActionMenu")
	kin_a.chosen_action = EvoActionMenu.option("raid", kin_b.id)
	kin_b.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_kin, "en")
	r._assert(is_equal_approx(kin_b.energy_reserves, 100.0) and kin_a.last_outcome.contains("peaceful kin"), "EvoConflictPhase blocks raid against peaceful kin")

	# Betrayal ignites feud -> kin can now raid and conquer feuding kin
	kin_rel.pact_turns = 3
	kin_b.chosen_action = EvoActionMenu.option("betray", kin_a.id)
	kin_a.chosen_action = EvoActionMenu.option("forage")
	kin_b.population = 120
	EvoConflictPhase.resolve(state_kin, "en")
	r._assert(kin_rel.feud_turns > 0, "Kin betrayal ignites blood feud (feud_turns > 0)")
	var feud_kin_menu := EvoActionMenu.build(kin_a, state_kin)
	var can_retaliate_raid := feud_kin_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "raid" and str(o["target"]) == kin_b.id)
	var can_retaliate_conq := feud_kin_menu.any(func(o: Dictionary) -> bool: return str(o["type"]) == "conquer" and str(o["target"]) == kin_b.id)
	r._assert(can_retaliate_raid and can_retaliate_conq, "Active blood feud (feud_turns > 0) unlocks raid and conquer against kin")
	kin_b.population = 35
	state_kin.rng.seed = 7
	kin_a.chosen_action = EvoActionMenu.option("raid", kin_b.id)
	kin_b.chosen_action = EvoActionMenu.option("forage")
	var res_before_retaliation := kin_a.energy_reserves
	EvoConflictPhase.resolve(state_kin, "en")
	r._assert(kin_a.energy_reserves > res_before_retaliation, "Kin settlement successfully raids feuding kin during blood feud")

	# 4. Opportunistic Betrayal + Third-Party Ally Alert
	var state_b := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var b_att: EvoTypes.Deme = state_b.demes["deme-rift-west"]
	var b_vic: EvoTypes.Deme = state_b.demes["deme-rift-east"]
	_place_deme(state_b, b_att, "0,0")
	_place_deme(state_b, b_vic, "1,0")
	var b_ally := b_vic.duplicate_deme()
	b_ally.id = "deme-third-ally"
	b_ally.name = "Third Ally"
	state_b.demes[b_ally.id] = b_ally
	_place_deme(state_b, b_ally, "-1,0")
	EvoTypes.get_relation(state_b, b_att.id, b_vic.id).pact_turns = 4
	EvoTypes.get_relation(state_b, b_vic.id, b_ally.id).pact_turns = 4
	EvoTypes.get_relation(state_b, b_att.id, b_ally.id).trust = 0.50

	b_att.population = 160
	b_att.energy_reserves = 20.0
	b_vic.population = 40
	b_vic.energy_reserves = 160.0
	b_att.chosen_action = EvoActionMenu.option("betray", b_vic.id)
	b_vic.chosen_action = EvoActionMenu.option("forage")
	b_ally.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_b, "en")
	r._assert(not EvoTypes.is_pact_active(state_b, b_att.id, b_vic.id) and EvoTypes.is_vendetta_active(state_b, b_att.id, b_vic.id), "Betrayal shatters pact and sets deep feud")
	r._assert(b_att.energy_reserves > 20.0 and b_vic.energy_reserves < 160.0, "Betrayal plunders surprise loot from victim")
	r._assert(b_att.reputation < 0.0 and EvoTypes.get_relation(state_b, b_att.id, b_ally.id).trust < 0.50, "Betrayal damages global reputation and third-party ally trust")
	r._assert(not state_b.disused_connections.is_empty(), "Betrayal records severed road in state.disused_connections")

	# 5. Territorial Conquest & Monotonic next_deme_seq Warband IDs (2 simultaneous conquests on same generation)
	var state_w := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var w_att1: EvoTypes.Deme = state_w.demes["deme-rift-west"]
	var w_def1: EvoTypes.Deme = state_w.demes["deme-rift-east"]
	_place_deme(state_w, w_att1, "0,0")
	_place_deme(state_w, w_def1, "1,0")
	var w_att2 := w_att1.duplicate_deme()
	w_att2.id = "deme-rift-west-m1-0_3-1"
	w_att2.name = "Sister War Camp"
	state_w.demes[w_att2.id] = w_att2
	_place_deme(state_w, w_att2, "0,3")
	var w_def2 := w_def1.duplicate_deme()
	w_def2.id = "deme-rift-east-m1-1_3-2"
	w_def2.name = "Second Defender"
	state_w.demes[w_def2.id] = w_def2
	_place_deme(state_w, w_def2, "1,3")
	state_w.next_deme_seq = 3
	state_w.rng.seed = 11

	w_att1.population = 240
	w_att1.energy_reserves = 150.0
	w_def1.population = 35
	w_def1.energy_reserves = 80.0
	w_att2.population = 240
	w_att2.energy_reserves = 150.0
	w_def2.population = 35
	w_def2.energy_reserves = 80.0
	w_att1.chosen_action = EvoActionMenu.option("conquer", w_def1.id)
	w_att2.chosen_action = EvoActionMenu.option("conquer", w_def2.id)
	w_def1.chosen_action = EvoActionMenu.option("forage")
	w_def2.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_w, "en")

	var wb1_id := (state_w.cells["1,0"] as EvoTypes.HexCell).deme_ids[0]
	var wb2_id := (state_w.cells["1,3"] as EvoTypes.HexCell).deme_ids[0]
	r._assert(wb1_id != w_def1.id and wb2_id != w_def2.id and wb1_id != wb2_id, "Two simultaneous conquests produce distinct warband Deme IDs (%s vs %s)" % [wb1_id, wb2_id])
	r._assert(state_w.next_deme_seq == 5, "Monotonic next_deme_seq increments once per newly spawned warband")
	var has_war_chronicle := state_w.chronicle.any(func(e: EvoTypes.ChronicleEntry) -> bool: return e.event_type == "war")
	r._assert(has_war_chronicle, "Conquest logs 'war' ChronicleEntry")


static func _test_multi_hex_fusion_corridors_and_partial_conquest(r) -> void:
	print("-- Testing Multi-Hex Deme Fusion, 3-Hex Cap, Partial District Conquest & 2-3 Hop Settle Corridors --")
	# 1. Asymmetric Union (tier_a != tier_b) absorbs smaller partner and converts vacated hex to rural hinterland
	var state_u1 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var u1_a: EvoTypes.Deme = state_u1.demes["deme-rift-west"]
	var u1_b: EvoTypes.Deme = state_u1.demes["deme-rift-east"]
	_place_deme(state_u1, u1_a, "0,0")
	_place_deme(state_u1, u1_b, "1,0")
	u1_a.population = 190
	u1_a.defense_tier = 1
	u1_b.population = 70
	u1_b.defense_tier = 0
	var u1_b_color := u1_b.color
	EvoTypes.get_relation(state_u1, u1_a.id, u1_b.id).pact_turns = 4
	u1_a.chosen_action = EvoActionMenu.option("unite", u1_b.id)
	u1_b.chosen_action = EvoActionMenu.option("unite", u1_a.id)
	EvoDiplomacyPhase.resolve(state_u1, "en")
	r._assert(state_u1.demes.size() == 1 and u1_a.merged_count == 1 and u1_a.secondary_color == u1_b_color, "Asymmetric union absorbs smaller partner into host city and records secondary_color")
	var vacated: EvoTypes.HexCell = state_u1.cells["1,0"]
	r._assert(vacated.deme_ids.is_empty() and vacated.owner_deme_id == u1_a.id and vacated.land_use in ["crops", "pasture"], "Vacated union hex becomes rural hinterland owned by host city")

	# 2. Equal-Tier Multi-Hex Deme Fusion (unite -> accept_union): fuses into ONE single Deme across 2 urban hexes
	var state_u2 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var u2_a: EvoTypes.Deme = state_u2.demes["deme-rift-west"]
	var u2_b: EvoTypes.Deme = state_u2.demes["deme-rift-east"]
	_place_deme(state_u2, u2_a, "0,0")
	_place_deme(state_u2, u2_b, "1,0")
	var third_partner := u2_a.duplicate_deme()
	third_partner.id = "deme-third-partner"
	third_partner.name = "Third City"
	state_u2.demes[third_partner.id] = third_partner
	_place_deme(state_u2, third_partner, "2,0")
	var fourth_partner := u2_a.duplicate_deme()
	fourth_partner.id = "deme-fourth-partner"
	fourth_partner.name = "Fourth City"
	state_u2.demes[fourth_partner.id] = fourth_partner
	_place_deme(state_u2, fourth_partner, "-1,0")

	u2_a.population = 150
	u2_b.population = 135
	u2_a.energy_reserves = 110.0
	u2_b.energy_reserves = 95.0
	u2_a.defense_tier = 1
	u2_b.defense_tier = 1
	EvoTypes.get_relation(state_u2, u2_a.id, u2_b.id).pact_turns = 4
	EvoTypes.get_relation(state_u2, u2_b.id, third_partner.id).pact_turns = 5
	EvoTypes.get_relation(state_u2, u2_b.id, third_partner.id).trust = 0.65

	# Turn 1: u2_a proposes unite; Turn 2: u2_b chooses accept_union
	u2_a.chosen_action = EvoActionMenu.option("unite", u2_b.id)
	u2_b.chosen_action = EvoActionMenu.option("forage")
	third_partner.chosen_action = EvoActionMenu.option("forage")
	fourth_partner.chosen_action = EvoActionMenu.option("forage")
	EvoDiplomacyPhase.resolve(state_u2, "en")
	state_u2.generation += 1
	u2_a.chosen_action = EvoActionMenu.option("forage")
	u2_b.chosen_action = EvoActionMenu.option("accept_union", u2_a.id)
	EvoDiplomacyPhase.resolve(state_u2, "en")

	r._assert(state_u2.demes.size() == 3 and state_u2.demes.has(u2_a.id) and not state_u2.demes.has(u2_b.id), "Equal-tier walled union fuses two cities into ONE single Deme and decreases state.demes by 1")
	r._assert(u2_a.is_multi_hex() and u2_a.urban_hex_ids == ["0,0", "1,0"], "Survivor Deme holds both urban_hex_ids ['0,0', '1,0']")
	r._assert((state_u2.cells["0,0"] as EvoTypes.HexCell).deme_ids == [u2_a.id] and (state_u2.cells["1,0"] as EvoTypes.HexCell).deme_ids == [u2_a.id], "Both urban hexes point cell.deme_ids == [survivor.id]")
	r._assert(u2_a.population == 285 and is_equal_approx(u2_a.energy_reserves, 205.0) and u2_a.defense_tier >= 2, "Fused Deme merges population, energy_reserves, and upgrades defense_tier >= 2")
	r._assert(u2_a.cultural_trait_ids.has("cul-interdeme-barter") and u2_a.biological_trait_ids.has("bio-encephalization"), "Fused Deme inherits compatible cultural_knowledge and biological adaptation_traits from partner")
	r._assert(EvoTypes.get_relation(state_u2, u2_a.id, third_partner.id).pact_turns == 5, "Fused Deme inherits external diplomatic relations from absorbed partner")

	# 3. Expansion to a 3rd urban hex (MAX_URBAN_HEXES == 3) and rejection of 4th hex union
	u2_a.population = 225
	u2_a.defense_tier = 1
	third_partner.population = 215
	third_partner.defense_tier = 1
	third_partner.urban_hex_ids = ["2,0"]
	u2_a.chosen_action = EvoActionMenu.option("unite", third_partner.id)
	third_partner.chosen_action = EvoActionMenu.option("unite", u2_a.id)
	EvoDiplomacyPhase.resolve(state_u2, "en")
	r._assert(u2_a.urban_hex_ids.size() == 3 and state_u2.demes.size() == 2 and (state_u2.cells["2,0"] as EvoTypes.HexCell).deme_ids == [u2_a.id], "Multi-hex city expands to 3rd urban hex (MAX_URBAN_HEXES == 3)")

	fourth_partner.population = 400
	fourth_partner.defense_tier = 2
	EvoTypes.get_relation(state_u2, u2_a.id, fourth_partner.id).pact_turns = 5
	var menu_at_cap := EvoActionMenu.build(u2_a, state_u2)
	r._assert(not menu_at_cap.any(func(o: Dictionary) -> bool: return str(o["type"]) == "unite" and str(o["target"]) == fourth_partner.id), "ActionMenu excludes 4th urban hex union once city reaches MAX_URBAN_HEXES (3)")
	EvoSettlementPhase.unite(u2_a, fourth_partner, state_u2, "en")
	r._assert(u2_a.urban_hex_ids.size() == 3 and state_u2.demes.has(fourth_partner.id), "EvoSettlementPhase.unite rejects 4th urban hex union")

	# 4. Partial District Conquest: strips only conquered district, shrinks pop & reserves, transfers/frees fields, keeps survivor alive
	var state_pc := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var pc_att: EvoTypes.Deme = state_pc.demes["deme-rift-west"]
	var pc_def: EvoTypes.Deme = state_pc.demes["deme-rift-east"]
	_place_deme(state_pc, pc_att, "2,0")
	_place_deme(state_pc, pc_def, "0,0")
	pc_def.urban_hex_ids = ["0,0", "1,0"]
	(state_pc.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([pc_def.id])
	(state_pc.cells["1,0"] as EvoTypes.HexCell).biome = "savanna"
	(state_pc.cells["1,0"] as EvoTypes.HexCell).altitude = 0.45

	# Set up 3 defender fields: "-1,0" (adjacent to surviving "0,0"), "2,-1" (adjacent only to conquered "1,0"), "-2,0" (isolated)
	for f_setup in [["-1,0", "crops", 200.0], ["2,-1", "crops", 190.0], ["-2,0", "crops", 120.0]]:
		var fc: EvoTypes.HexCell = state_pc.cells[f_setup[0]]
		fc.biome = "savanna"
		fc.altitude = 0.45
		fc.current_resources = f_setup[2]
		fc.owner_deme_id = pc_def.id
		fc.land_use = f_setup[1]

	pc_att.population = 650
	pc_att.energy_reserves = 260.0
	pc_def.population = 220
	pc_def.energy_reserves = 180.0
	pc_def.defense_tier = 1
	state_pc.rng.seed = 3
	pc_att.chosen_action = EvoActionMenu.option("conquer", pc_def.id)
	pc_def.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_pc, "en")
	EvoRuralHinterland.enforce_rural_hinterland_quotas(state_pc)

	var warband_id := (state_pc.cells["1,0"] as EvoTypes.HexCell).deme_ids[0]
	r._assert(state_pc.demes.has(pc_def.id) and pc_def.urban_hex_ids == ["0,0"] and warband_id != pc_def.id, "Partial district conquest strips only conquered district (1,0) and keeps surviving city alive on (0,0)")
	r._assert(pc_def.population < 220 and pc_def.population >= EvoPayoffs.MIN_VIABLE_POP and pc_def.energy_reserves < 180.0, "Partial district conquest shrinks surviving city population and energy_reserves")
	r._assert((state_pc.cells["-1,0"] as EvoTypes.HexCell).owner_deme_id == pc_def.id, "Field adjacent to surviving district remains owned by surviving city")
	r._assert((state_pc.cells["2,-1"] as EvoTypes.HexCell).owner_deme_id == warband_id, "Field adjacent only to conquered district transfers to conquering warband")
	r._assert((state_pc.cells["-2,0"] as EvoTypes.HexCell).owner_deme_id == "" and (state_pc.cells["-2,0"] as EvoTypes.HexCell).land_use == "wild", "Isolated field outside remaining perimeter is freed to wild")

	# 5. 2-3 Hop Corridor settle_targets: surrounded by own crops, finds wild candidates 2-3 hops away without cannibalizing own crops
	var state_cor := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-expansion")
	var d_coop_cor: EvoTypes.Deme = state_cor.demes["deme-rift-west"]
	var d_exp_cor: EvoTypes.Deme = state_cor.demes["deme-rift-east"]
	_place_deme(state_cor, d_coop_cor, "0,0")
	_place_deme(state_cor, d_exp_cor, "0,5")
	for cid in state_cor.cells.keys():
		var cc: EvoTypes.HexCell = state_cor.cells[cid]
		if cc.deme_ids.is_empty():
			cc.biome = "savanna"
			cc.altitude = 0.42
			cc.current_resources = 180.0
			cc.owner_deme_id = ""
			cc.land_use = "wild"
			cc.ruin_turns = 0
	for nid in HexMath.get_neighbor_ids(0, 0, state_cor.cells):
		var ring1: EvoTypes.HexCell = state_cor.cells[nid]
		ring1.owner_deme_id = d_coop_cor.id
		ring1.land_use = "crops"

	d_coop_cor.population = 180
	d_coop_cor.energy_reserves = 140.0
	var coop_targets := EvoActionMenu.settle_targets(d_coop_cor, state_cor)
	var coop_all_wild_2hop := not coop_targets.is_empty() and coop_targets.all(func(c: EvoTypes.HexCell) -> bool:
		return c.owner_deme_id == "" and c.land_use == "wild" and HexMath.hex_distance(0, 0, c.q, c.r) == 2
	)
	r._assert(coop_all_wild_2hop, "Settlement surrounded by own crops finds 2-hop wild settle candidates without targeting own crops")

	# Block ring 2 around (0,0) as owned crops too -> high-mobility strat-expansion reaches 3-hop wild frontier
	EvoCatalog.apply_strategy_to_deme(state_cor, d_coop_cor, "strat-expansion")
	for cid in state_cor.cells.keys():
		var cc: EvoTypes.HexCell = state_cor.cells[cid]
		if HexMath.hex_distance(0, 0, cc.q, cc.r) in [1, 2]:
			cc.owner_deme_id = d_coop_cor.id
			cc.land_use = "crops"
	var exp_targets_3hop := EvoActionMenu.settle_targets(d_coop_cor, state_cor)
	var exp_all_wild_3hop := not exp_targets_3hop.is_empty() and exp_targets_3hop.all(func(c: EvoTypes.HexCell) -> bool:
		return c.owner_deme_id == "" and c.land_use == "wild" and HexMath.hex_distance(0, 0, c.q, c.r) == 3
	)
	r._assert(EvoActionMenu.max_settle_hops(d_coop_cor, state_cor) == 3 and exp_all_wild_3hop, "High-mobility strat-expansion reaches 3-hop wild corridor targets without cannibalizing own crops")

	# Block ring 3 as well: below pop 260 returns empty; at pop >= 260 allows overflow onto own peripheral parcel
	for cid in state_cor.cells.keys():
		var cc: EvoTypes.HexCell = state_cor.cells[cid]
		if HexMath.hex_distance(0, 0, cc.q, cc.r) == 3:
			cc.owner_deme_id = d_coop_cor.id
			cc.land_use = "crops"
	d_coop_cor.population = 200
	r._assert(EvoActionMenu.settle_targets(d_coop_cor, state_cor).is_empty(), "When zero wild candidates exist and pop < 260, settle_targets never cannibalizes own crops")
	d_coop_cor.population = 270
	r._assert(not EvoActionMenu.settle_targets(d_coop_cor, state_cor).is_empty(), "When zero wild candidates exist and pop >= 260, overflow colony is allowed")


static func _test_player_interventions_and_multi_gen_stability(r) -> void:
	print("-- Testing Player Interventions, 25-Gen Stability & Inspector Integration --")
	var state := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	state.selective_pressure_points = 100
	var targets: Array[String] = ["0,0"]

	var ok_biome := EvoTurnEngine.apply_set_biome(state, targets, "tundra", "es")
	var c0: EvoTypes.HexCell = state.cells["0,0"]
	var tundra_defs: Dictionary = EvoTypes.BIOME_CLIMATE_DEFAULTS["tundra"]
	r._assert(ok_biome and c0.biome == "tundra", "set_biome changes cell biome to tundra")
	r._assert(
		is_equal_approx(c0.seasonal_regen_rate, float(tundra_defs["regen"])) and is_equal_approx(c0.carrying_capacity_max, float(tundra_defs["k_max"])),
		"set_biome updates seasonal_regen_rate and carrying_capacity_max"
	)
	r._assert(state.selective_pressure_points == 90, "set_biome costs 10 points")
	r._assert(EvoTurnEngine.apply_adjust_altitude(state, targets, 0.18, "es") and state.selective_pressure_points == 75, "adjust_altitude costs 15 points")
	r._assert(EvoTurnEngine.apply_adjust_carrying_capacity(state, targets, 0.25) and state.selective_pressure_points == 65, "adjust_carrying_capacity costs 10 points")
	var prev_sea := state.sea_level
	r._assert(EvoTurnEngine.apply_adjust_sea_level(state, 0.05, "es") and is_equal_approx(state.sea_level, prev_sea + 0.05) and state.selective_pressure_points == 40, "adjust_sea_level raises sea level and costs 25 points")

	# 25 Generations stability + 1-deme-per-hex invariant across all 3 presets
	for preset_id in EvoCatalog.PRESET_IDS:
		var p_state := EvoCatalog.create_preset_world(preset_id, "es")
		var max_demes_per_cell := 0
		for _g in range(25):
			EvoTurnEngine.advance_generation(p_state, "es")
			for cid in p_state.cells.keys():
				var c: EvoTypes.HexCell = p_state.cells[cid]
				if c.deme_ids.size() > max_demes_per_cell:
					max_demes_per_cell = c.deme_ids.size()
		r._assert(p_state.generation == 25 and max_demes_per_cell <= 1, "%s reached generation 25 cleanly with <= 1 deme per hex" % preset_id)

	# Inspector formatting of active pacts and relations
	var state_pact := EvoPresets.create_preset_world("preset-finite-island", "en")
	var p_d1: EvoTypes.Deme = state_pact.demes["deme-island-1"]
	var p_d2: EvoTypes.Deme = state_pact.demes["deme-island-2"]
	EvoTypes.get_relation(state_pact, p_d1.id, p_d2.id).pact_turns = 5
	var pact_summary := EvoHudInspectorPanel.format_active_pacts_summary(state_pact, "en", p_d1)
	r._assert(pact_summary.contains("🤝"), "EvoHudInspectorPanel.format_active_pacts_summary displays active pact partner")
	var pact_rel_lines := EvoHudInspectorPanel.build_deme_relations_lines(state_pact, "en", p_d1)
	r._assert(not pact_rel_lines.is_empty(), "EvoHudInspectorPanel.build_deme_relations_lines includes pact & relation lines")


static func _test_epidemic_contagion_and_immunity(r) -> void:
	print("-- Testing Deterministic Epidemic Outbreak, Contagion & Immunity --")
	var state := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	for cid in state.cells.keys():
		(state.cells[cid] as EvoTypes.HexCell).deme_ids.clear()
	state.demes.clear()
	state.relations.clear()
	state.turn_events.clear()
	state.chronicle.clear()

	var d_source := EvoTypes.Deme.new()
	d_source.id = "deme-epi-source"
	d_source.name = "Source Clan"
	d_source.hex_id = "0,0"
	d_source.urban_hex_ids = ["0,0"]
	d_source.population = 150
	d_source.salubrity = 0.25
	d_source.infection_turns = 2
	d_source.immunity_turns = 0
	d_source.lineage_id = "lineage-west"
	d_source.strategy_id = "strat-cooperation"
	d_source.color = "#10b981"

	var d_susceptible := EvoTypes.Deme.new()
	d_susceptible.id = "deme-epi-susceptible"
	d_susceptible.name = "Susceptible Clan"
	d_susceptible.hex_id = "1,0"
	d_susceptible.urban_hex_ids = ["1,0"]
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
	d_healthy.urban_hex_ids = ["0,1"]
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

	EvoTypes.get_relation(state, d_source.id, d_susceptible.id).pact_turns = 3
	EvoTypes.get_relation(state, d_source.id, d_healthy.id).pact_turns = 3

	state.generation = 1
	EvoEpidemicSalubrity._run_epidemic_phase(state, "en", [])

	r._assert(d_susceptible.infection_turns == 2, "Susceptible pact partner (salubrity < 0.70) catches contagion with infection_turns == 2")
	r._assert(d_healthy.infection_turns == 0, "Healthy pact partner (salubrity >= 0.70) resists epidemic contagion")
	r._assert(d_source.infection_turns == 1, "Source deme decrements infection_turns from 2 to 1 after first turn")

	state.generation = 2
	state.turn_events.clear()
	EvoEpidemicSalubrity._run_epidemic_phase(state, "en", [])
	r._assert(d_source.infection_turns == 0 and d_source.immunity_turns == 6, "Recovered deme transitions to infection_turns == 0 and immunity_turns == 6")

	d_source.salubrity = 0.15
	d_source.population = 180
	state.generation = 3
	state.turn_events.clear()
	EvoEpidemicSalubrity._run_epidemic_phase(state, "en", [])
	r._assert(d_source.infection_turns == 0 and d_source.immunity_turns == 5, "Immune deme (immunity_turns > 0) cannot be reinfected even when salubrity < 0.35 and population >= 130")
