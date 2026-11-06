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


static func create_preset_world(preset_id: String, lang: String = "es") -> EvoTypes.WorldState:
	return EvoPresets.create_preset_world(
		preset_id,
		lang,
		create_base_traits_catalog(lang),
		create_base_decisions_catalog(lang)
	)
