class_name EvoPresets
extends RefCounted


static func _make_cell(
	q: int,
	r: int,
	biome: String,
	temp: float,
	hum: float,
	alt: float,
	res: float,
	k: float,
	k_max: float,
	regen: float
) -> EvoTypes.HexCell:
	var c := EvoTypes.HexCell.new()
	c.id = HexMath.make_id(q, r)
	c.q = q
	c.r = r
	c.s = -q - r
	c.biome = biome
	c.temperature = temp
	c.humidity = hum
	c.altitude = alt
	c.current_resources = res
	c.carrying_capacity = k
	c.carrying_capacity_max = k_max
	c.seasonal_regen_rate = regen
	c.deme_ids = []
	return c


static func create_preset_world(
	preset_id: String,
	lang: String = "es",
	strategy_a_id: String = "strat-cooperation",
	strategy_b_id: String = "strat-war"
) -> EvoTypes.WorldState:
	var state := EvoTypes.WorldState.new()
	state.preset_id = preset_id
	state.world_name = EvoI18n.preset_title(lang, preset_id)
	state.generation = 0
	state.season = "wet_warm"
	state.selective_pressure_points = 30
	state.selective_pressure_regen_per_turn = 15
	state.unlimited_pressure_mode = false
	state.free_sandbox_mode = false
	state.auto_pause_on_milestone = false
	state.traits_catalog = EvoCatalog.create_base_traits_catalog(lang)
	state.decisions_catalog = EvoCatalog.create_base_decisions_catalog(lang)
	state.strategies_catalog = EvoCatalog.create_base_strategies_catalog(lang)
	EvoUserSettings.load_user_catalog_into(state)

	state.strategy_a_id = strategy_a_id if state.strategies_catalog.has(strategy_a_id) else "strat-cooperation"
	state.strategy_b_id = strategy_b_id if state.strategies_catalog.has(strategy_b_id) else "strat-war"

	var is_en := lang == "en"

	if preset_id == "preset-darwin-archipelago":
		_build_darwin_archipelago(state, lang, is_en)
	elif preset_id == "preset-finite-island":
		_build_finite_island(state, lang, is_en)
	else:
		_build_rift_savanna(state, lang, is_en)

	EvoDecisionModel.evaluate_all_demes(state, lang)
	for did in state.demes.keys():
		state.previous_populations[did] = (state.demes[did] as EvoTypes.Deme).population
	return state


static func _build_darwin_archipelago(state: EvoTypes.WorldState, lang: String, is_en: bool) -> void:
	state.map_radius = 5
	state.sea_level = 0.12
	state.glacial_sea_level_cycle = true

	var central_duel_ids := {"-1,0": true, "1,0": true}
	var bridge_ids := {"0,-1": true, "0,1": true, "2,0": true}
	var north_ids := {"0,-2": true, "0,-3": true}
	var south_ids := {"0,2": true, "0,3": true}
	var east_ids := {"3,0": true, "3,-1": true}

	for coord in HexMath.generate_hex_spiral(state.map_radius):
		var cid := HexMath.make_id(coord.x, coord.y)
		if cid == "0,0":
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.20, 0.75, 0.40, 320.0, 395.0, 450.0, 0.24)
		elif central_duel_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.22, 0.75, 0.65, 220.0, 220.0, 220.0, 0.24)
		elif bridge_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "coastal_shallows", 0.15, 0.65, 0.18, 200.0, 230.0, 260.0, 0.22)
		elif north_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "tundra", -0.55, 0.40, 0.55, 360.0, 380.0, 420.0, 0.24)
		elif south_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.55, 0.85, 0.45, 420.0, 450.0, 500.0, 0.28)
		elif east_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "arid_steppe", 0.65, 0.25, 0.45, 330.0, 360.0, 400.0, 0.22)
		else:
			state.cells[cid] = _make_cell(coord.x, coord.y, "ocean", 0.10, 0.90, 0.05, 0.0, 20.0, 60.0, 0.05)

	var lin_a := EvoTypes.LineageNode.new()
	lin_a.id = "lineage-darwin-a"
	lin_a.parent_id = ""
	lin_a.name = "Western Archipelago Lineage" if is_en else "Linaje Occidental del Archipiélago"
	lin_a.founded_generation = 0
	lin_a.extinct_generation = -1
	lin_a.founder_hex_id = "-1,0"
	lin_a.divergence_reason = "initial"
	state.lineage_tree[lin_a.id] = lin_a

	var founder := EvoTypes.Deme.new()
	founder.id = "deme-darwin-founder"
	founder.name = "Western Island Founders" if is_en else "Fundadores Insulares del Oeste"
	founder.lineage_id = lin_a.id
	founder.hex_id = "-1,0"
	founder.population = 95
	founder.energy_reserves = 165.0
	founder.last_energy_delta = 12.0
	founder.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(founder.id)
	EvoCatalog.apply_strategy_to_deme(state, founder, state.strategy_a_id, lang)
	state.demes[founder.id] = founder
	(state.cells["-1,0"] as EvoTypes.HexCell).deme_ids.append(founder.id)

	var lin_b := EvoTypes.LineageNode.new()
	lin_b.id = "lineage-darwin-b"
	lin_b.parent_id = ""
	lin_b.name = "Eastern Archipelago Lineage" if is_en else "Linaje Oriental del Archipiélago"
	lin_b.founded_generation = 0
	lin_b.extinct_generation = -1
	lin_b.founder_hex_id = "1,0"
	lin_b.divergence_reason = "initial"
	state.lineage_tree[lin_b.id] = lin_b

	var rival := EvoTypes.Deme.new()
	rival.id = "deme-darwin-rival"
	rival.name = "Eastern Island Rivals" if is_en else "Rivales Insulares del Este"
	rival.lineage_id = lin_b.id
	rival.hex_id = "1,0"
	rival.population = 95
	rival.energy_reserves = 165.0
	rival.last_energy_delta = 10.0
	rival.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(rival.id)
	EvoCatalog.apply_strategy_to_deme(state, rival, state.strategy_b_id, lang)
	state.demes[rival.id] = rival
	(state.cells["1,0"] as EvoTypes.HexCell).deme_ids.append(rival.id)


static func _build_finite_island(state: EvoTypes.WorldState, lang: String, is_en: bool) -> void:
	state.map_radius = 4
	state.sea_level = 0.20
	state.glacial_sea_level_cycle = false

	for coord in HexMath.generate_hex_spiral(state.map_radius):
		var cid := HexMath.make_id(coord.x, coord.y)
		var dist := HexMath.hex_distance(0, 0, coord.x, coord.y)
		if dist <= 1:
			state.cells[cid] = _make_cell(coord.x, coord.y, "savanna", 0.30, 0.55, 0.42, 580.0, 600.0, 600.0, 0.08)
		elif dist == 2:
			state.cells[cid] = _make_cell(coord.x, coord.y, "arid_steppe", 0.45, 0.30, 0.48, 200.0, 250.0, 280.0, 0.08)
		else:
			state.cells[cid] = _make_cell(coord.x, coord.y, "ocean", 0.15, 0.90, 0.05, 0.0, 20.0, 60.0, 0.05)

	var clan_configs := [
		{
			"id": "deme-island-1",
			"name": "Northern Quarry Clan" if is_en else "Clan de la Cantera Norte",
			"lineage_id": "lineage-island-1",
			"lineage_name": "Northern Quarry Lineage" if is_en else "Linaje de la Cantera Norte",
			"hex_id": "-1,0",
			"strategy_id": state.strategy_a_id
		},
		{
			"id": "deme-island-2",
			"name": "Southern Timber Clan" if is_en else "Clan Maderero del Sur",
			"lineage_id": "lineage-island-2",
			"lineage_name": "Southern Timber Lineage" if is_en else "Linaje Maderero del Sur",
			"hex_id": "1,0",
			"strategy_id": state.strategy_b_id
		}
	]

	for cfg in clan_configs:
		var hex_id := str(cfg["hex_id"])
		var lin := EvoTypes.LineageNode.new()
		lin.id = str(cfg["lineage_id"])
		lin.parent_id = ""
		lin.name = str(cfg["lineage_name"])
		lin.founded_generation = 0
		lin.extinct_generation = -1
		lin.founder_hex_id = hex_id
		lin.divergence_reason = "initial"
		state.lineage_tree[lin.id] = lin

		var deme := EvoTypes.Deme.new()
		deme.id = str(cfg["id"])
		deme.name = str(cfg["name"])
		deme.lineage_id = lin.id
		deme.hex_id = hex_id
		deme.population = 95
		deme.energy_reserves = 140.0
		deme.last_energy_delta = 8.0
		deme.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(deme.id)
		EvoCatalog.apply_strategy_to_deme(state, deme, str(cfg["strategy_id"]), lang)
		state.demes[deme.id] = deme
		(state.cells[hex_id] as EvoTypes.HexCell).deme_ids.append(deme.id)


static func _build_rift_savanna(state: EvoTypes.WorldState, lang: String, is_en: bool) -> void:
	state.preset_id = "preset-rift-savanna"
	state.world_name = EvoI18n.preset_title(lang, "preset-rift-savanna")
	state.map_radius = 5
	state.sea_level = 0.12
	state.glacial_sea_level_cycle = false

	for coord in HexMath.generate_hex_spiral(state.map_radius):
		var cid := HexMath.make_id(coord.x, coord.y)
		if coord.x == 0 and coord.y == 0:
			state.cells[cid] = _make_cell(0, 0, "savanna", 0.25, 0.45, 0.52, 240.0, 280.0, 320.0, 0.18)
		elif coord.x == 0:
			state.cells[cid] = _make_cell(coord.x, coord.y, "high_mountain", -0.35, 0.25, 0.88, 70.0, 108.0, 120.0, 0.08)
		elif coord.x < 0:
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.45, 0.85, 0.35, 560.0, 600.0, 650.0, 0.30)
		else:
			var is_savanna := int(abs(coord.x + coord.y)) % 2 == 1
			var b := "savanna" if is_savanna else "arid_steppe"
			state.cells[cid] = _make_cell(coord.x, coord.y, b, 0.60, 0.30, 0.42, 260.0, 335.0, 380.0, 0.16)

	var lin_west := EvoTypes.LineageNode.new()
	lin_west.id = "lineage-rift-west"
	lin_west.parent_id = ""
	lin_west.name = "Western Rift Lineage" if is_en else "Linaje Occidental del Rift"
	lin_west.founded_generation = 0
	lin_west.extinct_generation = -1
	lin_west.founder_hex_id = "-2,1"
	lin_west.divergence_reason = "initial"
	state.lineage_tree[lin_west.id] = lin_west

	var west_deme := EvoTypes.Deme.new()
	west_deme.id = "deme-rift-west"
	west_deme.name = "Western Forest Hominids" if is_en else "Homínidos del Bosque Occidental"
	west_deme.lineage_id = lin_west.id
	west_deme.hex_id = "-2,1"
	west_deme.population = 140
	west_deme.energy_reserves = 180.0
	west_deme.last_energy_delta = 12.0
	west_deme.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(west_deme.id)
	EvoCatalog.apply_strategy_to_deme(state, west_deme, state.strategy_a_id, lang)
	state.demes[west_deme.id] = west_deme
	(state.cells["-2,1"] as EvoTypes.HexCell).deme_ids.append(west_deme.id)

	var lin_east := EvoTypes.LineageNode.new()
	lin_east.id = "lineage-rift-east"
	lin_east.parent_id = ""
	lin_east.name = "Eastern Rift Lineage" if is_en else "Linaje Oriental del Rift"
	lin_east.founded_generation = 0
	lin_east.extinct_generation = -1
	lin_east.founder_hex_id = "2,-1"
	lin_east.divergence_reason = "initial"
	state.lineage_tree[lin_east.id] = lin_east

	var east_deme := EvoTypes.Deme.new()
	east_deme.id = "deme-rift-east"
	east_deme.name = "Eastern Savanna Hominids" if is_en else "Homínidos de la Sabana Oriental"
	east_deme.lineage_id = lin_east.id
	east_deme.hex_id = "2,-1"
	east_deme.population = 140
	east_deme.energy_reserves = 180.0
	east_deme.last_energy_delta = 8.0
	east_deme.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(east_deme.id)
	EvoCatalog.apply_strategy_to_deme(state, east_deme, state.strategy_b_id, lang)
	state.demes[east_deme.id] = east_deme
	(state.cells["2,-1"] as EvoTypes.HexCell).deme_ids.append(east_deme.id)
