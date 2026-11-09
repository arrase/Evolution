class_name EvoTestEngineBiophys
extends RefCounted


static func run(r) -> void:
	_test_payoffs_and_canonical_scenarios(r)
	_test_tragedy_of_the_commons(r)
	_test_fortify_innovate_baldwin_and_speciation(r)
	_test_diplomacy_trade_aid_pacts_and_tribute(r)
	_test_conflict_raids_betrayal_and_conquest(r)
	_test_settling_unions_and_rural_hinterlands(r)
	_test_player_interventions_and_multi_gen_stability(r)
	_test_epidemic_contagion_and_immunity(r)


static func _test_payoffs_and_canonical_scenarios(r) -> void:
	print("-- Testing EvoPayoffs Monotonicity & Canonical Scenario Forecasts --")
	var state := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var att: EvoTypes.Deme = state.demes["deme-rift-west"]
	var def: EvoTypes.Deme = state.demes["deme-rift-east"]
	(state.cells[att.hex_id] as EvoTypes.HexCell).deme_ids.erase(att.id)
	(state.cells[def.hex_id] as EvoTypes.HexCell).deme_ids.erase(def.id)
	att.hex_id = "0,0"
	def.hex_id = "1,0"
	(state.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([att.id])
	(state.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([def.id])

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
	r._assert(float(odds_castle["loot"]) < float(odds_base["loot"]) * 0.30, "Tier 3 Castle shields >= 75%% of raid loot")

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
			r._assert(fc.contains("Found a new camp") and fc.contains("settlers"), "Settle forecast quantifies new daughter camp and settlers")
			break
	r._assert(found_settle, "Action menu includes settle option when pop >= 45")

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

	# Canonical Scenario 4: Severe scarcity + rich ally -> betray option appears with surprise loot & distrust warning
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
	r._assert(has_betray, "Allied neighbor unlocks betray option in action menu")


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

	# 2. Innovate action & Cultural Innovation milestone
	var state_c := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var east_c: EvoTypes.Deme = state_c.demes["deme-rift-east"]
	east_c.cultural_trait_ids.clear()
	east_c.energy_reserves = 120.0
	east_c.chosen_action = EvoActionMenu.option("innovate")
	EvoEconomyPhase.invest(state_c, "es")
	r._assert(east_c.innovation_counter > 0.0, "Innovate action advances innovation_counter (%.2f)" % east_c.innovation_counter)

	east_c.innovation_counter = 1.15
	east_c.last_energy_delta = 5.0
	var entries_c := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	r._assert(entries_c.size() == 1 and entries_c[0].event_type == "cultural_innovation", "Cultural innovation triggers at counter >= 1.0")
	r._assert(east_c.cultural_trait_ids.size() == 1, "Deme acquires 1st newly synthesized cultural tradition")

	east_c.innovation_counter = 1.25
	east_c.last_energy_delta = 5.0
	var entries_c2 := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	r._assert(entries_c2.size() == 1 and entries_c2[0].event_type == "cultural_innovation" and east_c.cultural_trait_ids.size() == 2, "Deme acquires 2nd emergent cultural trait")

	east_c.innovation_counter = 1.25
	east_c.last_energy_delta = 5.0
	var entries_c3 := EvoMilestonePhase.run_milestone_phase(state_c, "es")
	r._assert(entries_c3.is_empty() and east_c.cultural_trait_ids.size() == 2, "Cultural innovation caps at 2 emergent cultural traits")

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
	(state_s.cells["0,-2"] as EvoTypes.HexCell).deme_ids.append(founder.id)
	founder.isolation_turns = 10
	var old_lineage := founder.lineage_id
	var old_color := founder.color
	var entries_s := EvoMilestonePhase.run_milestone_phase(state_s, "es")
	r._assert(entries_s.size() == 1 and entries_s[0].event_type == "allopatric_speciation", "Allopatric speciation triggers at isolation >= 10 in distinct biome")
	r._assert(founder.lineage_id != old_lineage and founder.color != old_color, "Speciated deme receives new lineage ID and distinct color")
	r._assert(state_s.lineage_tree.size() == 3, "Lineage tree now has 3 nodes")


static func _test_diplomacy_trade_aid_pacts_and_tribute(r) -> void:
	print("-- Testing Diplomacy: Reciprocal Trade, Aid, Pacts & Tribute Coercion --")
	var state := EvoPresets.create_preset_world("preset-finite-island", "en", "strat-cooperation", "strat-trade")
	var d1: EvoTypes.Deme = state.demes["deme-island-1"]
	var d2: EvoTypes.Deme = state.demes["deme-island-2"]
	(state.cells[d1.hex_id] as EvoTypes.HexCell).deme_ids.erase(d1.id)
	(state.cells[d2.hex_id] as EvoTypes.HexCell).deme_ids.erase(d2.id)
	d1.hex_id = "0,0"
	d2.hex_id = "1,0"
	(state.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([d1.id])
	(state.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([d2.id])

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

	# 3. Offer Pact -> Accept Pact on next turn (or mutual offer_pact on same turn)
	d1.chosen_action = EvoActionMenu.option("offer_pact", d2.id)
	d2.chosen_action = EvoActionMenu.option("offer_pact", d1.id)
	EvoDiplomacyPhase.resolve(state, "en")
	r._assert(EvoTypes.is_pact_active(state, d1.id, d2.id), "Mutual offer_pact forms active alliance")
	var has_pact_chronicle := false
	for e in state.chronicle:
		if e.event_type == "pact":
			has_pact_chronicle = true
			break
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

	# Next turn: d2 pays tribute
	state.generation += 1
	var d1_res_before := d1.energy_reserves
	d1.chosen_action = EvoActionMenu.option("forage")
	d2.chosen_action = EvoActionMenu.option("pay_tribute", d1.id)
	EvoDiplomacyPhase.resolve(state, "en")
	r._assert(d1.energy_reserves > d1_res_before and rel.truce_turns == EvoPayoffs.TRUCE_AFTER_TRIBUTE, "pay_tribute transfers food and grants truce")
	var has_trib_chronicle := false
	for e in state.chronicle:
		if e.event_type == "tribute":
			has_trib_chronicle = true
			break
	r._assert(has_trib_chronicle, "pay_tribute logs 'tribute' ChronicleEntry")

	# Demand tribute again and refuse -> feud_turns > 0
	rel.truce_turns = 0
	d1.chosen_action = EvoActionMenu.option("demand_tribute", d2.id)
	d2.chosen_action = EvoActionMenu.option("forage")
	EvoDiplomacyPhase.resolve(state, "en")
	state.generation += 1
	d1.chosen_action = EvoActionMenu.option("forage")
	d2.chosen_action = EvoActionMenu.option("forage")
	EvoDiplomacyPhase.resolve(state, "en")
	EvoRelations.tick(state)
	r._assert(EvoTypes.is_vendetta_active(state, d1.id, d2.id), "Ignoring a tribute demand triggers active feud/vendetta")


static func _test_conflict_raids_betrayal_and_conquest(r) -> void:
	print("-- Testing Conflict: Raids, Hinterland Pillaging, Betrayal & Territorial Conquest --")
	# 1. Cross-border Raid + Rural Hinterland Pillaging
	var state_r := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var r_att: EvoTypes.Deme = state_r.demes["deme-rift-west"]
	var r_def: EvoTypes.Deme = state_r.demes["deme-rift-east"]
	(state_r.cells[r_att.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_att.id)
	(state_r.cells[r_def.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_def.id)
	r_att.hex_id = "0,0"
	r_def.hex_id = "1,0"
	(state_r.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([r_att.id])
	(state_r.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([r_def.id])
	var farm_cell: EvoTypes.HexCell = state_r.cells["1,-1"]
	farm_cell.biome = "savanna"
	farm_cell.altitude = 0.45
	farm_cell.current_resources = 200.0
	farm_cell.owner_deme_id = r_def.id
	farm_cell.land_use = "crops"
	farm_cell.has_ruins = false

	r_att.population = 180
	r_att.energy_reserves = 25.0
	r_def.population = 35
	r_def.defense_tier = 0
	r_def.energy_reserves = 150.0
	r_att.chosen_action = EvoActionMenu.option("raid", r_def.id)
	r_def.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_r, "en")
	r._assert(r_att.energy_reserves > 25.0 and r_def.energy_reserves < 150.0, "Raid loots food reserves from defender")
	r._assert(farm_cell.has_ruins and farm_cell.land_use == "wild" and farm_cell.owner_deme_id == "", "Successful raid pillages defender rural hinterland into ruins")
	r._assert(EvoTypes.is_vendetta_active(state_r, r_att.id, r_def.id), "Raid activates bilateral feud/vendetta")

	# 2. Opportunistic Betrayal + Third-Party Ally Alert
	var state_b := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var b_att: EvoTypes.Deme = state_b.demes["deme-rift-west"]
	var b_vic: EvoTypes.Deme = state_b.demes["deme-rift-east"]
	(state_b.cells[b_att.hex_id] as EvoTypes.HexCell).deme_ids.erase(b_att.id)
	(state_b.cells[b_vic.hex_id] as EvoTypes.HexCell).deme_ids.erase(b_vic.id)
	b_att.hex_id = "0,0"
	b_vic.hex_id = "1,0"
	(state_b.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([b_att.id])
	(state_b.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([b_vic.id])
	var b_ally := b_vic.duplicate_deme()
	b_ally.id = "deme-third-ally"
	b_ally.name = "Third Ally"
	b_ally.hex_id = "-1,0"
	state_b.demes[b_ally.id] = b_ally
	(state_b.cells["-1,0"] as EvoTypes.HexCell).deme_ids.assign([b_ally.id])
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

	# 3. Territorial Conquest (Hex Occupation & Defender Displacement)
	var state_w := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var w_att: EvoTypes.Deme = state_w.demes["deme-rift-west"]
	var w_def: EvoTypes.Deme = state_w.demes["deme-rift-east"]
	(state_w.cells[w_att.hex_id] as EvoTypes.HexCell).deme_ids.erase(w_att.id)
	(state_w.cells[w_def.hex_id] as EvoTypes.HexCell).deme_ids.erase(w_def.id)
	w_att.hex_id = "0,0"
	w_def.hex_id = "1,0"
	(state_w.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([w_att.id])
	(state_w.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([w_def.id])
	w_att.population = 220
	w_att.energy_reserves = 140.0
	w_def.population = 35
	w_def.defense_tier = 0
	w_def.energy_reserves = 80.0
	w_att.chosen_action = EvoActionMenu.option("conquer", w_def.id)
	w_def.chosen_action = EvoActionMenu.option("forage")
	EvoConflictPhase.resolve(state_w, "en")
	var target_cell: EvoTypes.HexCell = state_w.cells["1,0"]
	r._assert(target_cell.deme_ids.size() == 1 and target_cell.deme_ids[0] != w_def.id, "Conquering warband occupies target hex (1,0) and displaces defender")
	var has_war_chronicle := false
	for e in state_w.chronicle:
		if e.event_type == "war":
			has_war_chronicle = true
			break
	r._assert(has_war_chronicle, "Conquest logs 'war' ChronicleEntry")


static func _test_settling_unions_and_rural_hinterlands(r) -> void:
	print("-- Testing Settling, Asymmetric & Equal-Tier Unions, and Rural Hinterlands --")
	# 1. Asymmetric Union (tier_a != tier_b) absorbs smaller partner and converts vacated hex to rural hinterland
	var state_u1 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var u1_a: EvoTypes.Deme = state_u1.demes["deme-rift-west"]
	var u1_b: EvoTypes.Deme = state_u1.demes["deme-rift-east"]
	(state_u1.cells[u1_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(u1_a.id)
	(state_u1.cells[u1_b.hex_id] as EvoTypes.HexCell).deme_ids.erase(u1_b.id)
	u1_a.hex_id = "0,0"
	u1_b.hex_id = "1,0"
	(state_u1.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([u1_a.id])
	(state_u1.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([u1_b.id])
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

	# 2. Equal-Tier Union (tier_a == tier_b >= 2) creates Multi-Hex Walled Union
	var state_u2 := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-cooperation", "strat-trade")
	var u2_a: EvoTypes.Deme = state_u2.demes["deme-rift-west"]
	var u2_b: EvoTypes.Deme = state_u2.demes["deme-rift-east"]
	(state_u2.cells[u2_a.hex_id] as EvoTypes.HexCell).deme_ids.erase(u2_a.id)
	(state_u2.cells[u2_b.hex_id] as EvoTypes.HexCell).deme_ids.erase(u2_b.id)
	u2_a.hex_id = "0,0"
	u2_b.hex_id = "1,0"
	(state_u2.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([u2_a.id])
	(state_u2.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([u2_b.id])
	u2_a.population = 135
	u2_b.population = 135
	u2_a.defense_tier = 1
	u2_b.defense_tier = 1
	EvoTypes.get_relation(state_u2, u2_a.id, u2_b.id).pact_turns = 4
	u2_a.chosen_action = EvoActionMenu.option("unite", u2_b.id)
	u2_b.chosen_action = EvoActionMenu.option("unite", u2_a.id)
	EvoDiplomacyPhase.resolve(state_u2, "en")
	r._assert(state_u2.demes.size() == 2 and u2_a.walled_union_id != "" and u2_a.walled_union_id == u2_b.walled_union_id, "Equal-tier union creates shared Multi-Hex Walled Union")

	# 3. Rural Hinterland claiming & harvest yield bonus
	var state_rh := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	var rh_city: EvoTypes.Deme = state_rh.demes["deme-rift-west"]
	(state_rh.cells[rh_city.hex_id] as EvoTypes.HexCell).deme_ids.erase(rh_city.id)
	rh_city.hex_id = "0,0"
	(state_rh.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([rh_city.id])
	rh_city.population = 210
	rh_city.defense_tier = 1
	EvoRuralHinterland.claim_hinterlands(state_rh)
	var owned := EvoRuralHinterland.owned_hexes(rh_city, state_rh)
	var yield_est := EvoRuralHinterland.rural_yield_estimate(rh_city, state_rh)
	r._assert(owned.size() == 2 and yield_est > 0.0, "Tier 3 city claims 2 rural hinterland hexes with positive food yield (%.1f)" % yield_est)


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
