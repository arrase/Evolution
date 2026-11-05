class_name EvoCatalog
extends RefCounted

const PRESET_IDS: Array[String] = [
	"preset-rift-savanna",
	"preset-darwin-archipelago",
	"preset-finite-island"
]


static func _make_trait(
	p_id: String,
	p_category: String,
	p_cost: float,
	p_extract: float,
	p_eco: float,
	p_mobility: float,
	p_cohesion: float,
	p_threshold: float,
	p_exclusive: Array[String],
	p_enables_culture: bool,
	lang: String
) -> EvoTypes.TraitDef:
	var t := EvoTypes.TraitDef.new()
	t.id = p_id
	t.category = p_category
	t.origin = "catalog"
	t.name = EvoI18n.t(lang, "trait." + p_id + ".name")
	t.description = EvoI18n.t(lang, "trait." + p_id + ".desc")
	t.vector = EvoTypes.BiophysicalVector.new(p_cost, p_extract, p_eco, p_mobility, p_cohesion, p_threshold)
	t.mutually_exclusive_with = p_exclusive.duplicate()
	t.enables_cultural_transmission = p_enables_culture
	return t


static func _make_decision(
	p_id: String,
	p_archetype: String,
	p_cost: float,
	p_extract: float,
	p_eco: float,
	p_mobility: float,
	p_cohesion: float,
	p_threshold: float,
	p_required_traits: Array[String],
	lang: String
) -> EvoTypes.DecisionDef:
	var d := EvoTypes.DecisionDef.new()
	d.id = p_id
	d.archetype = p_archetype
	d.name = EvoI18n.t(lang, "decision." + p_id + ".name")
	d.description = EvoI18n.t(lang, "decision." + p_id + ".desc")
	d.vector = EvoTypes.BiophysicalVector.new(p_cost, p_extract, p_eco, p_mobility, p_cohesion, p_threshold)
	d.required_trait_ids = p_required_traits.duplicate()
	return d


static func create_base_traits_catalog(lang: String = "es") -> Dictionary:
	var traits: Array[EvoTypes.TraitDef] = [
		_make_trait("bio-r-strategy", "biological", -0.15, 0.20, -0.20, 0.25, -0.15, 0.05, ["bio-k-strategy"], false, lang),
		_make_trait("bio-k-strategy", "biological", 0.20, 0.25, 0.15, 0.05, 0.40, 0.30, ["bio-r-strategy"], false, lang),
		_make_trait("bio-digestive-spec", "biological", 0.10, 0.45, 0.05, 0.15, 0.00, 0.10, [], false, lang),
		_make_trait("bio-thermal-tolerance", "biological", 0.15, 0.20, 0.05, 0.45, 0.10, 0.10, [], false, lang),
		_make_trait("bio-encephalization", "biological", 0.45, 0.35, 0.00, 0.20, 0.45, 0.60, [], true, lang),
		_make_trait("bio-social-instinct", "biological", 0.20, 0.20, 0.05, 0.10, 0.60, 0.45, [], true, lang),
		_make_trait("cul-fire-processing", "cultural", -0.10, 0.35, -0.25, 0.10, 0.15, 0.40, [], false, lang),
		_make_trait("cul-extraction-tools", "cultural", 0.25, 0.65, -0.25, 0.10, 0.20, 0.50, [], false, lang),
		_make_trait("cul-communal-conservation", "cultural", 0.15, 0.25, 0.55, 0.00, 0.50, 0.55, [], false, lang),
		_make_trait("cul-interdeme-barter", "cultural", 0.35, 0.40, 0.15, 0.30, 0.50, 0.60, [], false, lang),
		_make_trait("cul-warrior-expansion", "cultural", 0.45, 0.30, -0.35, 0.45, 0.60, 0.45, [], false, lang)
	]
	var catalog: Dictionary = {}
	for t in traits:
		catalog[t.id] = t
	return catalog


static func create_base_decisions_catalog(lang: String = "es") -> Dictionary:
	var decisions: Array[EvoTypes.DecisionDef] = [
		_make_decision("dec-conservative-forage", "forage", 0.10, 0.35, 0.10, 0.00, 0.05, 0.05, [], lang),
		_make_decision("dec-intensive-overexploit", "overexploit", 0.25, 0.85, -0.65, 0.00, -0.10, 0.10, [], lang),
		_make_decision("dec-selective-migration", "migrate", 0.30, 0.15, 0.15, 0.75, 0.05, 0.10, [], lang),
		_make_decision("dec-cooperate-store", "cooperate", 0.25, 0.45, 0.15, -0.10, 0.65, 0.35, [], lang),
		_make_decision("dec-exchange-symbiosis", "exchange", 0.35, 0.50, 0.20, 0.20, 0.60, 0.45, ["bio-encephalization", "bio-social-instinct"], lang),
		_make_decision("dec-territorial-dispute", "dispute", 0.55, 0.40, -0.30, 0.25, 0.55, 0.20, [], lang),
		_make_decision("dec-explore-innovate", "innovate", 0.50, 0.15, 0.00, 0.40, 0.35, 0.65, [], lang)
	]
	var catalog: Dictionary = {}
	for d in decisions:
		catalog[d.id] = d
	return catalog


static func deme_has_cultural_capacity(deme: EvoTypes.Deme, traits_catalog: Dictionary) -> bool:
	for tid in deme.biological_trait_ids:
		if traits_catalog.has(tid):
			var t: EvoTypes.TraitDef = traits_catalog[tid]
			if t.enables_cultural_transmission:
				return true
	return false


static func inject_trait_into_deme(
	state: EvoTypes.WorldState,
	deme_id: String,
	trait_id: String,
	lang: String = "es"
) -> bool:
	if not state.demes.has(deme_id) or not state.traits_catalog.has(trait_id):
		return false

	var deme: EvoTypes.Deme = state.demes[deme_id]
	var trait_def: EvoTypes.TraitDef = state.traits_catalog[trait_id]

	var excluded: Dictionary = {}
	for ex_id in trait_def.mutually_exclusive_with:
		excluded[ex_id] = true
	for other_id in state.traits_catalog.keys():
		var other_trait: EvoTypes.TraitDef = state.traits_catalog[other_id]
		if other_trait.mutually_exclusive_with.has(trait_id):
			excluded[other_trait.id] = true

	var next_bio: Array[String] = []
	for tid in deme.biological_trait_ids:
		if not excluded.has(tid):
			next_bio.append(tid)

	var next_cul: Array[String] = []
	for tid in deme.cultural_trait_ids:
		if not excluded.has(tid):
			next_cul.append(tid)

	if trait_def.category == "biological":
		if not next_bio.has(trait_id):
			next_bio.append(trait_id)
		deme.biological_trait_ids = next_bio
		deme.cultural_trait_ids = next_cul
		if not deme_has_cultural_capacity(deme, state.traits_catalog):
			deme.cultural_trait_ids = []
	else:
		var temp_deme := deme.duplicate_deme()
		temp_deme.biological_trait_ids = next_bio
		if not deme_has_cultural_capacity(temp_deme, state.traits_catalog):
			return false
		if not next_cul.has(trait_id):
			next_cul.append(trait_id)
		deme.biological_trait_ids = next_bio
		deme.cultural_trait_ids = next_cul

	var eval_res := EvoDecisionModel.evaluate_deme(deme, state, lang)
	deme.last_decision_probabilities = eval_res["probabilities"]
	deme.last_dominant_decision_id = str(eval_res["dominant_decision_id"])
	deme.last_confidence = float(eval_res["confidence"]) if eval_res.has("confidence") else 0.85
	deme.last_justification = str(eval_res["justification"])
	return true


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


static func create_preset_world(preset_id: String, lang: String = "es") -> EvoTypes.WorldState:
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
	state.traits_catalog = create_base_traits_catalog(lang)
	state.decisions_catalog = create_base_decisions_catalog(lang)

	var is_en := lang == "en"

	if preset_id == "preset-darwin-archipelago":
		state.map_radius = 5
		state.sea_level = 0.12
		state.glacial_sea_level_cycle = true

		var bridge_ids := {"0,-1": true, "0,1": true, "1,0": true}
		var north_ids := {"0,-2": true, "0,-3": true}
		var south_ids := {"0,2": true, "0,3": true}
		var east_ids := {"2,0": true, "3,0": true}

		for coord in HexMath.generate_hex_spiral(state.map_radius):
			var cid := HexMath.make_id(coord.x, coord.y)
			if cid == "0,0":
				state.cells[cid] = _make_cell(coord.x, coord.y, "tropical_forest", 0.20, 0.75, 0.40, 320.0, 395.0, 450.0, 0.24)
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

		var founder := EvoTypes.Deme.new()
		founder.id = "deme-darwin-founder"
		founder.name = "Archipelago Founders" if is_en else "Fundadores del Archipiélago"
		founder.lineage_id = "lineage-darwin-ancestral"
		founder.color = "#3D85C6"
		founder.hex_id = "0,0"
		founder.population = 220
		founder.energy_reserves = 300.0
		founder.last_energy_delta = 15.0
		founder.biological_trait_ids = ["bio-r-strategy", "bio-thermal-tolerance", "bio-social-instinct"]
		founder.cultural_trait_ids = []
		founder.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(founder.id)
		state.demes[founder.id] = founder
		(state.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(founder.id)

		var lineage := EvoTypes.LineageNode.new()
		lineage.id = "lineage-darwin-ancestral"
		lineage.parent_id = ""
		lineage.name = "Archipelago Ancestors" if is_en else "Ancestros del Archipiélago"
		lineage.color = "#3D85C6"
		lineage.founded_generation = 0
		lineage.extinct_generation = -1
		lineage.founder_hex_id = "0,0"
		lineage.acquired_trait_ids = ["bio-r-strategy", "bio-thermal-tolerance", "bio-social-instinct"]
		lineage.divergence_reason = "initial"
		state.lineage_tree[lineage.id] = lineage

	elif preset_id == "preset-finite-island":
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
				"color": "#E07A5F"
			},
			{
				"id": "deme-island-2",
				"name": "Southern Timber Clan" if is_en else "Clan Maderero del Sur",
				"lineage_id": "lineage-island-2",
				"lineage_name": "Southern Timber Lineage" if is_en else "Linaje Maderero del Sur",
				"color": "#F2CC8F"
			},
			{
				"id": "deme-island-3",
				"name": "Eastern Ridge Clan" if is_en else "Clan de la Cresta Oriental",
				"lineage_id": "lineage-island-3",
				"lineage_name": "Eastern Ridge Lineage" if is_en else "Linaje de la Cresta Oriental",
				"color": "#9B5DE5"
			}
		]

		for cfg in clan_configs:
			var deme := EvoTypes.Deme.new()
			deme.id = str(cfg["id"])
			deme.name = str(cfg["name"])
			deme.lineage_id = str(cfg["lineage_id"])
			deme.color = str(cfg["color"])
			deme.hex_id = "0,0"
			deme.population = 320
			deme.energy_reserves = 400.0
			deme.last_energy_delta = -10.0
			deme.biological_trait_ids = ["bio-encephalization", "bio-k-strategy"]
			deme.cultural_trait_ids = ["cul-extraction-tools"]
			deme.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(deme.id)
			state.demes[deme.id] = deme
			(state.cells["0,0"] as EvoTypes.HexCell).deme_ids.append(deme.id)

			var lin := EvoTypes.LineageNode.new()
			lin.id = str(cfg["lineage_id"])
			lin.parent_id = ""
			lin.name = str(cfg["lineage_name"])
			lin.color = str(cfg["color"])
			lin.founded_generation = 0
			lin.extinct_generation = -1
			lin.founder_hex_id = "0,0"
			lin.acquired_trait_ids = ["bio-encephalization", "bio-k-strategy", "cul-extraction-tools"]
			lin.divergence_reason = "initial"
			state.lineage_tree[lin.id] = lin

	else:
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

		var west_deme := EvoTypes.Deme.new()
		west_deme.id = "deme-rift-west"
		west_deme.name = "Western Forest Hominids" if is_en else "Homínidos del Bosque Occidental"
		west_deme.lineage_id = "lineage-rift-ancestral"
		west_deme.color = "#E07A5F"
		west_deme.hex_id = "-2,1"
		west_deme.population = 140
		west_deme.energy_reserves = 180.0
		west_deme.last_energy_delta = 12.0
		west_deme.biological_trait_ids = ["bio-k-strategy", "bio-social-instinct"]
		west_deme.cultural_trait_ids = []
		west_deme.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(west_deme.id)
		state.demes[west_deme.id] = west_deme
		(state.cells["-2,1"] as EvoTypes.HexCell).deme_ids.append(west_deme.id)

		var east_deme := EvoTypes.Deme.new()
		east_deme.id = "deme-rift-east"
		east_deme.name = "Eastern Savanna Hominids" if is_en else "Homínidos de la Sabana Oriental"
		east_deme.lineage_id = "lineage-rift-ancestral"
		east_deme.color = "#E07A5F"
		east_deme.hex_id = "2,-1"
		east_deme.population = 140
		east_deme.energy_reserves = 180.0
		east_deme.last_energy_delta = 8.0
		east_deme.biological_trait_ids = ["bio-k-strategy", "bio-social-instinct"]
		east_deme.cultural_trait_ids = []
		east_deme.decision_model_tag = EvoDecisionModel.resolve_deme_decision_model_tag(east_deme.id)
		state.demes[east_deme.id] = east_deme
		(state.cells["2,-1"] as EvoTypes.HexCell).deme_ids.append(east_deme.id)

		var ancestral := EvoTypes.LineageNode.new()
		ancestral.id = "lineage-rift-ancestral"
		ancestral.parent_id = ""
		ancestral.name = "Rift Hominids" if is_en else "Homínidos del Rift"
		ancestral.color = "#E07A5F"
		ancestral.founded_generation = 0
		ancestral.extinct_generation = -1
		ancestral.founder_hex_id = "-2,1"
		ancestral.acquired_trait_ids = ["bio-k-strategy", "bio-social-instinct"]
		ancestral.divergence_reason = "initial"
		state.lineage_tree[ancestral.id] = ancestral

	EvoDecisionModel.evaluate_all_demes(state, lang)
	for did in state.demes.keys():
		state.previous_populations[did] = (state.demes[did] as EvoTypes.Deme).population
	return state
