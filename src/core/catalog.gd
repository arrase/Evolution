class_name EvoCatalog
extends RefCounted

const PRESET_IDS: Array[String] = [
	"preset-rift-savanna",
	"preset-darwin-archipelago",
	"preset-finite-island"
]

const DEFAULT_STRATEGY_A_ID: String = "strat-cooperation"
const DEFAULT_STRATEGY_B_ID: String = "strat-war"


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
	d.origin = "catalog"
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
		_make_decision("dec-explore-innovate", "innovate", 0.50, 0.15, 0.00, 0.40, 0.35, 0.65, ["bio-encephalization", "bio-social-instinct"], lang)
	]
	var catalog: Dictionary = {}
	for d in decisions:
		catalog[d.id] = d
	return catalog


static func _make_strategy(
	p_id: String,
	p_icon: String,
	p_color: String,
	p_bio: Array[String],
	p_cul: Array[String],
	lang: String
) -> EvoTypes.StrategyDef:
	var s := EvoTypes.StrategyDef.new()
	s.id = p_id
	s.name = EvoI18n.strategy_text(p_id, "name", p_id, lang)
	s.description = EvoI18n.strategy_text(p_id, "desc", "", lang)
	s.icon = p_icon
	s.color = p_color
	s.origin = "base"
	s.biological_trait_ids = p_bio.duplicate()
	s.cultural_trait_ids = p_cul.duplicate()
	return s


static func create_base_strategies_catalog(lang: String = "es") -> Dictionary:
	var strategies: Array[EvoTypes.StrategyDef] = [
		_make_strategy("strat-cooperation", "🤝", "#10B981", ["bio-k-strategy", "bio-social-instinct"], ["cul-communal-conservation"], lang),
		_make_strategy("strat-expansion", "🧭", "#3B82F6", ["bio-r-strategy", "bio-thermal-tolerance", "bio-social-instinct"], ["cul-fire-processing"], lang),
		_make_strategy("strat-trade", "⚖️", "#F59E0B", ["bio-k-strategy", "bio-encephalization"], ["cul-interdeme-barter"], lang),
		_make_strategy("strat-war", "⚔️", "#EF4444", ["bio-r-strategy", "bio-social-instinct"], ["cul-warrior-expansion", "cul-extraction-tools"], lang),
		_make_strategy("strat-innovation", "🔬", "#A855F7", ["bio-encephalization", "bio-digestive-spec"], ["cul-fire-processing", "cul-extraction-tools"], lang)
	]
	var catalog: Dictionary = {}
	for s in strategies:
		catalog[s.id] = s
	return catalog


static func compute_strategy_vector(strategy: EvoTypes.StrategyDef, traits_catalog: Dictionary) -> EvoTypes.BiophysicalVector:
	var cost: float = 0.0
	var extract: float = 0.0
	var eco: float = 0.0
	var mobility: float = 0.0
	var cohesion: float = 0.0
	var threshold: float = 0.0
	for tid in strategy.biological_trait_ids:
		if traits_catalog.has(tid):
			var v := (traits_catalog[tid] as EvoTypes.TraitDef).vector
			cost += v.metabolic_cost
			extract += v.extraction_efficiency
			eco += v.ecological_impact
			mobility += v.spatial_mobility
			cohesion += v.social_cohesion
			threshold += v.transmission_threshold
	for tid in strategy.cultural_trait_ids:
		if traits_catalog.has(tid):
			var v := (traits_catalog[tid] as EvoTypes.TraitDef).vector
			cost += v.metabolic_cost
			extract += v.extraction_efficiency
			eco += v.ecological_impact
			mobility += v.spatial_mobility
			cohesion += v.social_cohesion
			threshold += v.transmission_threshold
	return EvoThermodynamics.clamp_vector(
		EvoTypes.BiophysicalVector.new(cost, extract, eco, mobility, cohesion, threshold)
	)


static func compute_deme_vector(deme: EvoTypes.Deme, traits_catalog: Dictionary) -> EvoTypes.BiophysicalVector:
	var cost: float = 0.0
	var extract: float = 0.0
	var eco: float = 0.0
	var mobility: float = 0.0
	var cohesion: float = 0.0
	var threshold: float = 0.0
	for tid in deme.biological_trait_ids:
		if traits_catalog.has(tid):
			var v := (traits_catalog[tid] as EvoTypes.TraitDef).vector
			cost += v.metabolic_cost
			extract += v.extraction_efficiency
			eco += v.ecological_impact
			mobility += v.spatial_mobility
			cohesion += v.social_cohesion
			threshold += v.transmission_threshold
	for tid in deme.cultural_trait_ids:
		if traits_catalog.has(tid):
			var v := (traits_catalog[tid] as EvoTypes.TraitDef).vector
			cost += v.metabolic_cost
			extract += v.extraction_efficiency
			eco += v.ecological_impact
			mobility += v.spatial_mobility
			cohesion += v.social_cohesion
			threshold += v.transmission_threshold
	return EvoThermodynamics.clamp_vector(
		EvoTypes.BiophysicalVector.new(cost, extract, eco, mobility, cohesion, threshold)
	)


static func deme_has_trait(deme: EvoTypes.Deme, trait_id: String) -> bool:
	return deme.biological_trait_ids.has(trait_id) or deme.cultural_trait_ids.has(trait_id)


static func compute_baseline_decision_weights(deme: EvoTypes.Deme, traits_catalog: Dictionary = {}) -> Dictionary:
	var effective_traits := traits_catalog if not traits_catalog.is_empty() else create_base_traits_catalog()
	var vec := compute_deme_vector(deme, effective_traits)
	var has_cultural_cap := deme_has_cultural_capacity(deme, effective_traits) or deme_has_trait(deme, "bio-encephalization") or deme_has_trait(deme, "bio-social-instinct")
	var has_warrior := deme_has_trait(deme, "cul-warrior-expansion")
	var has_r_strat := deme_has_trait(deme, "bio-r-strategy")
	var coop_cohesion := 0.0 if has_warrior else maxf(0.0, vec.social_cohesion) * (0.18 if has_r_strat else 0.45)

	var raw_scores := {
		"dec-conservative-forage": (
			0.22
			+ maxf(0.0, vec.ecological_impact) * 0.45
			+ (0.20 if deme_has_trait(deme, "cul-communal-conservation") else 0.0)
		),
		"dec-intensive-overexploit": (
			0.08
			+ maxf(0.0, vec.extraction_efficiency) * 0.35
			+ maxf(0.0, -vec.ecological_impact) * 0.30
			+ (0.18 if deme_has_trait(deme, "cul-extraction-tools") else 0.0)
			+ (0.12 if has_r_strat else 0.0)
		),
		"dec-selective-migration": (
			0.10
			+ maxf(0.0, vec.spatial_mobility) * 0.45
			+ (0.28 if (deme_has_trait(deme, "bio-thermal-tolerance") or deme_has_trait(deme, "bio-endurance-locomotion")) else 0.0)
			+ (0.16 if (has_warrior or has_r_strat) else 0.0)
		),
		"dec-cooperate-store": (
			0.12
			+ coop_cohesion
			+ (0.25 if (deme_has_trait(deme, "cul-communal-conservation") or deme_has_trait(deme, "cul-cooperative-networks")) else 0.0)
			+ (0.15 if (deme_has_trait(deme, "bio-social-instinct") and not has_warrior and not has_r_strat) else 0.0)
		),
		"dec-exchange-symbiosis": (
			0.08
			+ (0.0 if has_warrior else maxf(0.0, vec.social_cohesion) * 0.25)
			+ maxf(0.0, vec.spatial_mobility) * 0.25
			+ (0.48 if deme_has_trait(deme, "cul-interdeme-barter") else 0.0)
		) if has_cultural_cap else 0.0,
		"dec-territorial-dispute": (
			0.04
			+ maxf(0.0, vec.extraction_efficiency) * 0.25
			+ maxf(0.0, -vec.ecological_impact) * 0.25
			+ maxf(0.0, -vec.social_cohesion) * 0.40
			+ (0.55 if has_warrior else 0.0)
			+ (0.12 if has_r_strat else 0.0)
		),
		"dec-explore-innovate": (
			0.08
			+ maxf(0.0, vec.transmission_threshold) * 0.50
			+ (0.35 if (deme_has_trait(deme, "cul-fire-processing") or deme_has_trait(deme, "cul-symbolic-archive")) else 0.0)
			+ (0.30 if (deme_has_trait(deme, "bio-encephalization") or deme_has_trait(deme, "bio-neural-plasticity")) else 0.0)
		) if has_cultural_cap else 0.0
	}

	var eligible_ids: Array[String] = [
		"dec-conservative-forage",
		"dec-intensive-overexploit",
		"dec-selective-migration",
		"dec-cooperate-store",
		"dec-territorial-dispute"
	]
	if has_cultural_cap:
		eligible_ids.append("dec-exchange-symbiosis")
		eligible_ids.append("dec-explore-innovate")

	return EvoHeuristicScorer.normalize_decision_probabilities(raw_scores, eligible_ids)


static func compute_strategy_baseline_probabilities(deme: EvoTypes.Deme, traits_catalog: Dictionary = {}) -> Dictionary:
	var norm := compute_baseline_decision_weights(deme, traits_catalog)
	var probs: Dictionary = norm["probabilities"]
	deme.last_decision_probabilities = probs.duplicate()
	deme.last_dominant_decision_id = str(norm["dominant_decision_id"])
	return probs


static func apply_strategy_to_deme(
	state: EvoTypes.WorldState,
	deme: EvoTypes.Deme,
	strategy_id: String,
	_lang: String = "es"
) -> void:
	if not state.strategies_catalog.has(strategy_id):
		return
	var strategy: EvoTypes.StrategyDef = state.strategies_catalog[strategy_id]
	deme.strategy_id = strategy.id
	deme.color = strategy.color
	deme.biological_trait_ids = strategy.biological_trait_ids.duplicate()
	if deme_has_cultural_capacity(deme, state.traits_catalog):
		deme.cultural_trait_ids = strategy.cultural_trait_ids.duplicate()
	else:
		deme.cultural_trait_ids = []

	compute_strategy_baseline_probabilities(deme, state.traits_catalog)

	if state.lineage_tree.has(deme.lineage_id):
		var lin: EvoTypes.LineageNode = state.lineage_tree[deme.lineage_id]
		lin.strategy_id = strategy.id
		lin.color = strategy.color
		lin.biological_trait_ids = deme.biological_trait_ids.duplicate()
		lin.cultural_trait_ids = deme.cultural_trait_ids.duplicate()
		var acq: Array[String] = deme.biological_trait_ids.duplicate()
		for cid in deme.cultural_trait_ids:
			if not acq.has(cid):
				acq.append(cid)
		lin.acquired_trait_ids = acq


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


static func create_preset_world(
	preset_id: String,
	lang: String = "es",
	strategy_a_id: String = DEFAULT_STRATEGY_A_ID,
	strategy_b_id: String = DEFAULT_STRATEGY_B_ID
) -> EvoTypes.WorldState:
	return EvoPresets.create_preset_world(
		preset_id,
		lang,
		strategy_a_id,
		strategy_b_id
	)
