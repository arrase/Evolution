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
	state.next_deme_seq = 1
	state.rng_seed = int(absi(("%s|%s|%s" % [preset_id, state.strategy_a_id, state.strategy_b_id]).hash())) + 1
	state.rng.seed = state.rng_seed

	var is_en := lang == "en"

	if preset_id == "preset-darwin-archipelago":
		_build_darwin_archipelago(state, is_en)
	elif preset_id == "preset-finite-island":
		_build_finite_island(state, is_en)
	else:
		_build_rift_savanna(state, lang, is_en)

	EvoRuralHinterland.claim_hinterlands(state)
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		state.previous_populations[did] = d.population
	EvoDecisionModel.evaluate_all_demes(state, lang, true)
	return state


static func _spawn_founder_deme(
	state: EvoTypes.WorldState,
	deme_id: String,
	deme_name: String,
	lin_id: String,
	lin_name: String,
	slot: String,
	hex_id: String,
	pop: int,
	reserves: float,
	last_delta: float
) -> void:
	var lin := EvoTypes.LineageNode.new()
	lin.id = lin_id
	lin.parent_id = ""
	lin.name = lin_name
	lin.founded_generation = 0
	lin.extinct_generation = -1
	lin.founder_hex_id = hex_id
	lin.divergence_reason = "initial"
	state.lineage_tree[lin.id] = lin

	var deme := EvoTypes.Deme.new()
	deme.id = deme_id
	deme.name = deme_name
	deme.lineage_id = lin.id
	deme.faction_slot = slot
	deme.strategy_id = state.strategy_a_id if slot == "A" else state.strategy_b_id
	deme.hex_id = hex_id
	deme.urban_hex_ids = [hex_id]
	deme.population = pop
	deme.energy_reserves = reserves
	deme.last_energy_delta = last_delta
	deme.decision_model_tag = EvoDecisionModel.resolve_model_for_slot(deme.faction_slot)
	EvoCatalog.apply_strategy_to_deme(state, deme, deme.strategy_id)
	state.demes[deme.id] = deme
	(state.cells[hex_id] as EvoTypes.HexCell).deme_ids.append(deme.id)


static func _build_darwin_archipelago(state: EvoTypes.WorldState, is_en: bool) -> void:
	state.map_radius = 5
	state.sea_level = 0.12
	state.glacial_sea_level_cycle = true

	var central_duel_ids := {"-1,0": true, "1,0": true, "-2,1": true, "2,-1": true, "-1,1": true, "1,-1": true}
	var bridge_ids := {"0,-1": true, "0,1": true, "-2,0": true, "2,0": true, "0,-3": true, "0,3": true, "3,-1": true}
	var north_ids := {"0,-2": true, "1,-2": true, "-1,-2": true, "0,-4": true, "1,-3": true}
	var south_ids := {"0,2": true, "-1,2": true, "1,2": true, "0,4": true, "-1,3": true}
	var east_ids := {"3,0": true, "3,1": true, "4,-1": true, "4,0": true}
	var west_ids := {"-3,1": true, "-3,0": true, "-4,1": true}

	for coord in HexMath.generate_hex_spiral(state.map_radius):
		var cid := HexMath.make_id(coord.x, coord.y)
		if cid == "0,0":
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.20, 0.75, 0.42, 350.0, 390.0, 430.0, 0.24)
		elif central_duel_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.22, 0.75, 0.52, 270.0, 310.0, 340.0, 0.24)
		elif bridge_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "coastal_shallows", 0.15, 0.65, 0.18, 200.0, 230.0, 260.0, 0.22)
		elif north_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "tundra", -0.55, 0.40, 0.55, 300.0, 330.0, 370.0, 0.22)
		elif south_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.55, 0.85, 0.45, 320.0, 360.0, 400.0, 0.26)
		elif east_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "arid_steppe", 0.65, 0.25, 0.45, 270.0, 310.0, 350.0, 0.20)
		elif west_ids.has(cid):
			state.cells[cid] = _make_cell(coord.x, coord.y, "savanna", 0.45, 0.45, 0.45, 270.0, 310.0, 350.0, 0.20)
		else:
			state.cells[cid] = _make_cell(coord.x, coord.y, "ocean", 0.10, 0.90, 0.05, 0.0, 20.0, 60.0, 0.05)

	_spawn_founder_deme(
		state,
		"deme-darwin-founder",
		"Western Island Founders" if is_en else "Fundadores Insulares del Oeste",
		"lineage-darwin-a",
		"Western Archipelago Lineage" if is_en else "Linaje Occidental del Archipiélago",
		"A", "-2,1", 95, 120.0, 12.0
	)
	_spawn_founder_deme(
		state,
		"deme-darwin-rival",
		"Eastern Island Rivals" if is_en else "Rivales Insulares del Este",
		"lineage-darwin-b",
		"Eastern Archipelago Lineage" if is_en else "Linaje Oriental del Archipiélago",
		"B", "2,-1", 95, 120.0, 10.0
	)


static func _build_finite_island(state: EvoTypes.WorldState, is_en: bool) -> void:
	state.map_radius = 5
	state.sea_level = 0.20
	state.glacial_sea_level_cycle = false

	for coord in HexMath.generate_hex_spiral(state.map_radius):
		var cid := HexMath.make_id(coord.x, coord.y)
		var dist := HexMath.hex_distance(0, 0, coord.x, coord.y)
		if dist <= 1:
			state.cells[cid] = _make_cell(coord.x, coord.y, "savanna", 0.30, 0.55, 0.42, 380.0, 420.0, 440.0, 0.14)
		elif dist == 2:
			state.cells[cid] = _make_cell(coord.x, coord.y, "arid_steppe", 0.45, 0.30, 0.48, 220.0, 260.0, 290.0, 0.12)
		elif dist == 3 and int(abs(coord.x - coord.y)) % 2 == 0:
			state.cells[cid] = _make_cell(coord.x, coord.y, "coastal_shallows", 0.22, 0.65, 0.24, 180.0, 210.0, 240.0, 0.15)
		else:
			state.cells[cid] = _make_cell(coord.x, coord.y, "ocean", 0.15, 0.90, 0.05, 0.0, 20.0, 60.0, 0.05)

	_spawn_founder_deme(
		state,
		"deme-island-1",
		"Northern Quarry Clan" if is_en else "Clan de la Cantera Norte",
		"lineage-island-1",
		"Northern Quarry Lineage" if is_en else "Linaje de la Cantera Norte",
		"A", "-2,1", 95, 120.0, 8.0
	)
	_spawn_founder_deme(
		state,
		"deme-island-2",
		"Southern Timber Clan" if is_en else "Clan Maderero del Sur",
		"lineage-island-2",
		"Southern Timber Lineage" if is_en else "Linaje Maderero del Sur",
		"B", "1,1", 95, 120.0, 8.0
	)


static func _build_rift_savanna(state: EvoTypes.WorldState, lang: String, is_en: bool) -> void:
	state.preset_id = "preset-rift-savanna"
	state.world_name = EvoI18n.preset_title(lang, "preset-rift-savanna")
	state.map_radius = 5
	state.sea_level = 0.12
	state.glacial_sea_level_cycle = false

	for coord in HexMath.generate_hex_spiral(state.map_radius):
		var cid := HexMath.make_id(coord.x, coord.y)
		if coord.x == 0 and (coord.y == 0 or abs(coord.y) == 2):
			state.cells[cid] = _make_cell(coord.x, coord.y, "savanna", 0.25, 0.45, 0.50, 380.0, 420.0, 460.0, 0.22)
		elif coord.x == 0:
			state.cells[cid] = _make_cell(coord.x, coord.y, "high_mountain", -0.35, 0.25, 0.88, 70.0, 108.0, 120.0, 0.08)
		elif coord.x == -1:
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.45, 0.85, 0.38, 360.0, 420.0, 460.0, 0.22)
		elif coord.x <= -2:
			state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.45, 0.85, 0.35, 260.0, 320.0, 360.0, 0.20)
		elif coord.x == 1:
			state.cells[cid] = _make_cell(coord.x, coord.y, "savanna", 0.55, 0.35, 0.42, 320.0, 360.0, 400.0, 0.18)
		else:
			var is_savanna := int(abs(coord.x + coord.y)) % 2 == 1
			var b := "savanna" if is_savanna else "arid_steppe"
			state.cells[cid] = _make_cell(coord.x, coord.y, b, 0.60, 0.30, 0.42, 220.0, 270.0, 310.0, 0.15)

	_spawn_founder_deme(
		state,
		"deme-rift-west",
		"Western Forest Hominids" if is_en else "Homínidos del Bosque Occidental",
		"lineage-rift-west",
		"Western Rift Lineage" if is_en else "Linaje Occidental del Rift",
		"A", "-2,1", 95, 120.0, 12.0
	)
	_spawn_founder_deme(
		state,
		"deme-rift-east",
		"Eastern Savanna Hominids" if is_en else "Homínidos de la Sabana Oriental",
		"lineage-rift-east",
		"Eastern Rift Lineage" if is_en else "Linaje Oriental del Rift",
		"B", "2,-1", 95, 120.0, 8.0
	)
