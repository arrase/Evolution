class_name EvoHeuristicScorer
extends RefCounted

const DEFAULT_SYSTEM_ONE_MODEL: String = "d3:4b"
const SECONDARY_SYSTEM_ONE_MODEL: String = "tev1:4b"


static func resolve_deme_decision_model_tag(
	deme_id: String,
	primary_tag: String = DEFAULT_SYSTEM_ONE_MODEL,
	secondary_tag: String = SECONDARY_SYSTEM_ONE_MODEL
) -> String:
	if deme_id in ["deme-rift-west", "deme-island-1", "deme-island-3", "deme-darwin-founder"]:
		return primary_tag
	if deme_id in ["deme-rift-east", "deme-island-2"]:
		return secondary_tag
	var h: int = 0
	for i in range(deme_id.length()):
		h = (h * 31 + deme_id.unicode_at(i)) & 0x7FFFFFFF
	return primary_tag if (h % 2 == 0) else secondary_tag


static func is_decision_eligible(deme: EvoTypes.Deme, dec: EvoTypes.DecisionDef) -> bool:
	if dec.required_trait_ids.is_empty():
		return true
	for req_id in dec.required_trait_ids:
		if deme.biological_trait_ids.has(req_id) or deme.cultural_trait_ids.has(req_id):
			return true
	return false


static func get_eligible_decisions(deme: EvoTypes.Deme, decisions_catalog: Dictionary) -> Array[EvoTypes.DecisionDef]:
	var result: Array[EvoTypes.DecisionDef] = []
	for dec_id in decisions_catalog.keys():
		var dec: EvoTypes.DecisionDef = decisions_catalog[dec_id]
		if is_decision_eligible(deme, dec):
			result.append(dec)
	return result


static func normalize_decision_probabilities(
	raw_scores: Dictionary,
	eligible_ids: Array[String]
) -> Dictionary:
	if eligible_ids.is_empty():
		return {"probabilities": {}, "dominant_decision_id": ""}

	var positive_scores: Dictionary = {}
	var sum_scores: float = 0.0

	for dec_id in eligible_ids:
		var val: float = float(raw_scores[dec_id]) if raw_scores.has(dec_id) else 0.0
		var clean_score: float = val if (not is_nan(val) and not is_inf(val) and val > 0.0) else 0.0
		positive_scores[dec_id] = clean_score
		sum_scores += clean_score

	if sum_scores <= 0.0:
		var uniform_weight: float = 1.0 / float(eligible_ids.size())
		for dec_id in eligible_ids:
			positive_scores[dec_id] = uniform_weight
		sum_scores = 1.0

	var max_decision_id: String = eligible_ids[0]
	var max_score: float = -1.0

	for dec_id in eligible_ids:
		var s: float = float(positive_scores[dec_id])
		if s > max_score:
			max_score = s
			max_decision_id = dec_id

	var temp_probs: Dictionary = {}
	var other_sum: float = 0.0
	var highest_other_id: String = ""
	var highest_other_prob: float = -1.0

	for dec_id in eligible_ids:
		if dec_id == max_decision_id:
			continue
		var s: float = float(positive_scores[dec_id])
		var rounded: float = snappedf(s / sum_scores, 0.0001)
		temp_probs[dec_id] = rounded
		other_sum += rounded
		if rounded > highest_other_prob:
			highest_other_prob = rounded
			highest_other_id = dec_id

	var complement: float = snappedf(maxf(0.0, 1.0 - other_sum), 0.0001)
	if highest_other_id != "" and highest_other_prob > complement:
		temp_probs[max_decision_id] = highest_other_prob
		temp_probs[highest_other_id] = complement
	else:
		temp_probs[max_decision_id] = complement

	var probabilities: Dictionary = {}
	probabilities[max_decision_id] = temp_probs[max_decision_id]
	for dec_id in eligible_ids:
		if dec_id != max_decision_id:
			probabilities[dec_id] = temp_probs[dec_id]

	return {
		"probabilities": probabilities,
		"dominant_decision_id": max_decision_id
	}


static func compute_baseline_mobility(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var mobility: float = 0.0
	for tid in deme.biological_trait_ids:
		if state.traits_catalog.has(tid):
			mobility += (state.traits_catalog[tid] as EvoTypes.TraitDef).vector.spatial_mobility
	for tid in deme.cultural_trait_ids:
		if state.traits_catalog.has(tid):
			mobility += (state.traits_catalog[tid] as EvoTypes.TraitDef).vector.spatial_mobility
	return clampf(mobility, -1.5, 1.5)


static func _format_signed_metric(val: float) -> String:
	var r := snappedf(val, 0.01)
	return ("+" if r >= 0.0 else "") + str(r)


static func _format_compact_trait(t: EvoTypes.TraitDef) -> String:
	var v := t.vector
	return "%s[cost:%s,extract:%s,eco:%s,mobility:%s,cohesion:%s]" % [
		t.name,
		_format_signed_metric(v.metabolic_cost),
		_format_signed_metric(v.extraction_efficiency),
		_format_signed_metric(v.ecological_impact),
		_format_signed_metric(v.spatial_mobility),
		_format_signed_metric(v.social_cohesion)
	]


static func _compute_vitality_status(
	energy_reserves: float,
	last_energy_delta: float,
	resource_adequacy_ratio: float
) -> String:
	if energy_reserves < 25.0 or (last_energy_delta < -15.0 and energy_reserves < 50.0):
		return "starving"
	if last_energy_delta < -3.0 or resource_adequacy_ratio < 0.85:
		return "struggling"
	if energy_reserves >= 75.0 and last_energy_delta >= 0.0 and resource_adequacy_ratio >= 1.3:
		return "thriving"
	return "stable"


static func _get_sorted_passable_neighbors(
	deme: EvoTypes.Deme,
	current_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Array[Dictionary]:
	var eligible_decisions := get_eligible_decisions(deme, state.decisions_catalog)
	var base_mobility := compute_baseline_mobility(deme, state)
	var max_migrate_mob: float = 0.0
	for dec in eligible_decisions:
		if dec.archetype == "migrate":
			max_migrate_mob = maxf(max_migrate_mob, dec.vector.spatial_mobility)
	var effective_mig_mobility := minf(1.5, base_mobility + max_migrate_mob)

	var passable: Array[Dictionary] = []
	for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		var is_passable := ncell.biome != "ocean" and (ncell.altitude - 0.50) <= effective_mig_mobility
		if not is_passable:
			continue
		var total_pop: int = 0
		for oid in ncell.deme_ids:
			if state.demes.has(oid):
				total_pop += (state.demes[oid] as EvoTypes.Deme).population
		passable.append({
			"id": ncell.id,
			"biome": ncell.biome,
			"current_resources": ncell.current_resources,
			"demes_count": ncell.deme_ids.size(),
			"total_population": total_pop
		})

	passable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: float = float(a["current_resources"]) / maxf(10.0, float(a["total_population"]))
		var b_score: float = float(b["current_resources"]) / maxf(10.0, float(b["total_population"]))
		return a_score > b_score
	)
	return passable


static func build_compact_system_one_state(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var total_cell_pop: int = 0
	var rival_count: int = 0
	var kin_count: int = 0
	for oid in current_cell.deme_ids:
		if state.demes.has(oid):
			var other: EvoTypes.Deme = state.demes[oid]
			total_cell_pop += other.population
			if other.id != deme.id:
				if other.lineage_id == deme.lineage_id:
					kin_count += 1
				else:
					rival_count += 1
	if total_cell_pop <= 0:
		total_cell_pop = deme.population
	var cohabiting_count: int = maxi(0, current_cell.deme_ids.size() - 1)

	var resource_adequacy_ratio := snappedf(
		current_cell.current_resources / maxf(10.0, float(total_cell_pop) * 0.48),
		0.01
	)
	var health_pct := int(roundf(
		(current_cell.carrying_capacity / maxf(1.0, current_cell.carrying_capacity_max)) * 100.0
	))
	var vitality := _compute_vitality_status(deme.energy_reserves, deme.last_energy_delta, resource_adequacy_ratio)

	var line1 := "Gen %d (%s) | Hex %s (%s): resources=%d/%d (health=%d%% of Kmax=%d), caloricAdequacy=%sx, temp=%s, hum=%s, alt=%s" % [
		state.generation,
		state.season,
		current_cell.id,
		current_cell.biome,
		int(roundf(current_cell.current_resources)),
		int(roundf(current_cell.carrying_capacity)),
		health_pct,
		int(roundf(current_cell.carrying_capacity_max)),
		str(resource_adequacy_ratio),
		str(current_cell.temperature),
		str(current_cell.humidity),
		str(current_cell.altitude)
	]

	var delta_int := int(roundf(deme.last_energy_delta))
	var delta_str := ("+%d" % delta_int) if deme.last_energy_delta >= 0.0 else ("%d" % delta_int)
	var line2 := "Deme \"%s\": pop=%d (%s), reserves=%d, delta=%s | CellCompetition: totalPop=%d, cohabiting=%d (rivals=%d, kin=%d)" % [
		deme.name,
		deme.population,
		vitality,
		int(roundf(deme.energy_reserves)),
		delta_str,
		total_cell_pop,
		cohabiting_count,
		rival_count,
		kin_count
	]

	var all_traits: Array[String] = []
	for tid in deme.biological_trait_ids:
		if state.traits_catalog.has(tid):
			all_traits.append(_format_compact_trait(state.traits_catalog[tid]))
	for tid in deme.cultural_trait_ids:
		if state.traits_catalog.has(tid):
			all_traits.append(_format_compact_trait(state.traits_catalog[tid]))
	var line3 := "Traits: %s" % ("; ".join(all_traits) if not all_traits.is_empty() else "none")

	var passable_neighbors := _get_sorted_passable_neighbors(deme, current_cell, state)
	var top_neighbors := passable_neighbors.slice(0, 3)
	var neighbor_parts: Array[String] = []
	var has_open_bridge := current_cell.biome == "coastal_shallows"
	for n in top_neighbors:
		var n_biome := str(n["biome"])
		var n_count := int(n["demes_count"])
		if n_biome == "coastal_shallows" and n_count == 0:
			has_open_bridge = true
		neighbor_parts.append("%s(%s, res=%d, pop=%d, %s)" % [
			str(n["id"]),
			n_biome,
			int(roundf(float(n["current_resources"]))),
			int(n["total_population"]),
			"empty" if n_count == 0 else "occupied"
		])
	var neighbors_text := ", ".join(neighbor_parts) if not neighbor_parts.is_empty() else "none"

	var baldwin_progress: int = 0
	for k in deme.baldwin_counters.keys():
		baldwin_progress = maxi(baldwin_progress, int(deme.baldwin_counters[k]))
	var dom_str := deme.last_dominant_decision_id if deme.last_dominant_decision_id != "" else "none"
	var line4 := "lastDominant=%s, baldwin=%d/8, innovation=%.2f/2.0 | Neighbors: %s" % [
		dom_str,
		baldwin_progress,
		deme.innovation_counter,
		neighbors_text
	]

	var has_extraction_tools := deme.cultural_trait_ids.has("cul-extraction-tools")
	var line5 := ""
	if has_open_bridge:
		line5 = "Cue: Open coastal_shallows land bridge favors migration."
	elif has_extraction_tools:
		line5 = "Cue: Specialized Extraction Tools and rival competition drive Intensive Overexploitation and Territorial Dispute to maximize immediate extraction."
	elif resource_adequacy_ratio < 0.85 or vitality == "starving":
		line5 = "Cue: Resource scarcity favors cooperation or migration."
	elif current_cell.biome == "savanna" or current_cell.biome == "arid_steppe" or current_cell.humidity <= 0.50:
		line5 = "Cue: Seasonal savanna aridity favors cooperation and migration."
	else:
		line5 = "Cue: Abundant stable %s favors conservative foraging." % current_cell.biome

	return "\n".join([line1, line2, line3, line4, line5])


static func build_compact_decision_criteria(eligible_decisions: Array[EvoTypes.DecisionDef]) -> Dictionary:
	var criteria: Dictionary = {}
	for dec in eligible_decisions:
		var v := dec.vector
		var vec_text := "[cost:%s,extract:%s,eco:%s,mobility:%s,cohesion:%s]" % [
			_format_signed_metric(v.metabolic_cost),
			_format_signed_metric(v.extraction_efficiency),
			_format_signed_metric(v.ecological_impact),
			_format_signed_metric(v.spatial_mobility),
			_format_signed_metric(v.social_cohesion)
		]
		var full_text := "%s %s: %s" % [dec.name, vec_text, dec.description]
		criteria[dec.id] = full_text.substr(0, 120)
	return criteria


static func compute_deme_evaluation_signature(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var model_key := deme.decision_model_tag if deme.decision_model_tag != "" else resolve_deme_decision_model_tag(deme.id)
	if not state.cells.has(deme.hex_id):
		return "%s|%s|missing" % [model_key, state.season]

	var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var total_cell_pop: int = 0
	var rival_count: int = 0
	var kin_count: int = 0
	for oid in current_cell.deme_ids:
		if state.demes.has(oid):
			var other: EvoTypes.Deme = state.demes[oid]
			total_cell_pop += other.population
			if other.id != deme.id:
				if other.lineage_id == deme.lineage_id:
					kin_count += 1
				else:
					rival_count += 1
	if total_cell_pop <= 0:
		total_cell_pop = deme.population

	var resource_adequacy_ratio := snappedf(
		current_cell.current_resources / maxf(10.0, float(total_cell_pop) * 0.48),
		0.01
	)
	var adequacy_bucket := mini(6, int(floor(resource_adequacy_ratio * 2.0)))
	var health_bucket := int(floor(
		(current_cell.carrying_capacity / maxf(1.0, current_cell.carrying_capacity_max)) * 4.0
	))
	var vitality := _compute_vitality_status(deme.energy_reserves, deme.last_energy_delta, resource_adequacy_ratio)
	var competition_key := "%d:%d:%s" % [rival_count, kin_count, "viable" if deme.population >= 40 else "small"]

	var all_tids: Array[String] = []
	for tid in deme.biological_trait_ids:
		all_tids.append(tid)
	for tid in deme.cultural_trait_ids:
		all_tids.append(tid)
	all_tids.sort()
	var traits_key := ",".join(all_tids)
	var dominant_key := deme.last_dominant_decision_id

	var passable_neighbors := _get_sorted_passable_neighbors(deme, current_cell, state).slice(0, 2)
	var n_keys: Array[String] = []
	for n in passable_neighbors:
		var n_count := int(n["demes_count"])
		var n_res_bucket := int(roundf(float(n["current_resources"]) / 100.0))
		n_keys.append("%s:%s:%d" % [str(n["biome"]), "empty" if n_count == 0 else "occupied", n_res_bucket])
	var neighbor_key := ",".join(n_keys)

	return "%s|%s|%s|%d|%d|%s|%s|%s|%s|%s" % [
		model_key,
		state.season,
		current_cell.biome,
		adequacy_bucket,
		health_bucket,
		vitality,
		competition_key,
		traits_key,
		dominant_key,
		neighbor_key
	]


static func evaluate_deme_heuristic(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String = "es"
) -> Dictionary:
	if deme.decision_model_tag == "" or (deme.id in ["deme-rift-east", "deme-island-2"] and deme.decision_model_tag == DEFAULT_SYSTEM_ONE_MODEL):
		deme.decision_model_tag = resolve_deme_decision_model_tag(deme.id)

	if not state.cells.has(deme.hex_id):
		return {
			"probabilities": deme.last_decision_probabilities,
			"dominant_decision_id": deme.last_dominant_decision_id,
			"confidence": deme.last_confidence,
			"justification": deme.last_justification
		}

	var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var eligible_decisions := get_eligible_decisions(deme, state.decisions_catalog)

	var base_mobility := compute_baseline_mobility(deme, state)
	var max_migrate_mob: float = 0.0
	for dec in eligible_decisions:
		if dec.archetype == "migrate":
			max_migrate_mob = maxf(max_migrate_mob, dec.vector.spatial_mobility)
	var effective_mig_mobility := minf(1.5, base_mobility + max_migrate_mob)

	var neighbor_ids := HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells)
	var has_ocean_neighbor: bool = false
	var has_passable_empty_shallows: bool = false

	for nid in neighbor_ids:
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if ncell.biome == "ocean":
			has_ocean_neighbor = true
		var is_passable := ncell.biome != "ocean" and (ncell.altitude - 0.50) <= effective_mig_mobility
		if is_passable and ncell.biome == "coastal_shallows" and ncell.deme_ids.is_empty():
			has_passable_empty_shallows = true

	var total_cell_pop: int = 0
	var rival_demes_count: int = 0
	for other_id in current_cell.deme_ids:
		if state.demes.has(other_id):
			var other: EvoTypes.Deme = state.demes[other_id]
			total_cell_pop += other.population
			if other.id != deme.id and other.lineage_id != deme.lineage_id:
				rival_demes_count += 1
	if total_cell_pop <= 0:
		total_cell_pop = deme.population

	var resource_adequacy_ratio: float = current_cell.current_resources / maxf(10.0, float(total_cell_pop) * 0.48)
	var has_extraction_tools := deme.cultural_trait_ids.has("cul-extraction-tools")
	var has_communal_conservation := deme.cultural_trait_ids.has("cul-communal-conservation")

	var has_open_land_bridge := (
		current_cell.biome == "coastal_shallows"
		or (current_cell.id == "0,0" and state.generation <= 7 and has_passable_empty_shallows)
	)
	var is_insular_or_alpine := (
		has_ocean_neighbor
		or current_cell.biome == "tundra"
		or current_cell.biome == "high_mountain"
	)
	var is_arid_or_savanna := (
		current_cell.biome == "savanna"
		or current_cell.biome == "arid_steppe"
		or current_cell.humidity <= 0.50
	)

	var is_secondary_model := deme.decision_model_tag == SECONDARY_SYSTEM_ONE_MODEL
	var base_weights: Dictionary = {}
	var active_branch: String = "stable_forest"

	if has_extraction_tools and not has_communal_conservation:
		active_branch = "tech_overexploit"
		base_weights = {
			"dec-intensive-overexploit": (0.54 if is_secondary_model else 0.58) if rival_demes_count > 0 else 0.54,
			"dec-territorial-dispute": (0.18 if is_secondary_model else 0.14) if rival_demes_count > 0 else 0.12,
			"dec-conservative-forage": 0.10,
			"dec-cooperate-store": 0.06,
			"dec-selective-migration": 0.04 if rival_demes_count > 0 else 0.10,
			"dec-exchange-symbiosis": 0.04,
			"dec-explore-innovate": 0.04
		}
	elif has_open_land_bridge:
		if deme.population >= 40:
			active_branch = "land_bridge_colonize"
			base_weights = {
				"dec-selective-migration": 0.48 if is_secondary_model else 0.52,
				"dec-cooperate-store": 0.22 if is_secondary_model else 0.20,
				"dec-conservative-forage": 0.10,
				"dec-explore-innovate": 0.10 if is_secondary_model else 0.08,
				"dec-exchange-symbiosis": 0.04,
				"dec-intensive-overexploit": 0.03,
				"dec-territorial-dispute": 0.03
			}
		else:
			active_branch = "land_bridge_recover"
			base_weights = {
				"dec-cooperate-store": 0.40,
				"dec-conservative-forage": 0.24,
				"dec-selective-migration": 0.18,
				"dec-explore-innovate": 0.08,
				"dec-exchange-symbiosis": 0.04,
				"dec-intensive-overexploit": 0.03,
				"dec-territorial-dispute": 0.03
			}
	elif is_insular_or_alpine:
		active_branch = "insular_alpine"
		base_weights = {
			"dec-cooperate-store": 0.44 if is_secondary_model else 0.46,
			"dec-explore-innovate": 0.20 if is_secondary_model else 0.18,
			"dec-conservative-forage": 0.16,
			"dec-exchange-symbiosis": 0.08,
			"dec-selective-migration": 0.04,
			"dec-intensive-overexploit": 0.04,
			"dec-territorial-dispute": 0.04
		}
	elif is_arid_or_savanna:
		active_branch = "arid_savanna"
		base_weights = {
			"dec-cooperate-store": 0.40 if is_secondary_model else 0.42,
			"dec-selective-migration": 0.18 if is_secondary_model else 0.16,
			"dec-explore-innovate": 0.14,
			"dec-conservative-forage": 0.12,
			"dec-exchange-symbiosis": 0.08,
			"dec-intensive-overexploit": 0.04,
			"dec-territorial-dispute": 0.04
		}
	elif resource_adequacy_ratio < 0.70 and rival_demes_count > 0:
		active_branch = "scarcity_competition"
		base_weights = {
			"dec-cooperate-store": 0.36,
			"dec-conservative-forage": 0.28,
			"dec-selective-migration": 0.16,
			"dec-exchange-symbiosis": 0.08,
			"dec-explore-innovate": 0.04,
			"dec-intensive-overexploit": 0.04,
			"dec-territorial-dispute": 0.04
		}
	else:
		active_branch = "stable_forest"
		base_weights = {
			"dec-conservative-forage": 0.50 if is_secondary_model else 0.52,
			"dec-cooperate-store": 0.16 if is_secondary_model else 0.14,
			"dec-exchange-symbiosis": 0.10,
			"dec-selective-migration": 0.08,
			"dec-explore-innovate": 0.08,
			"dec-intensive-overexploit": 0.04,
			"dec-territorial-dispute": 0.04
		}

	var raw_scores: Dictionary = {}
	var eligible_ids: Array[String] = []
	for dec in eligible_decisions:
		eligible_ids.append(dec.id)
		raw_scores[dec.id] = float(base_weights[dec.id]) if base_weights.has(dec.id) else 0.08

	var normalized := normalize_decision_probabilities(raw_scores, eligible_ids)
	var probs: Dictionary = normalized["probabilities"]
	var dominant_id: String = str(normalized["dominant_decision_id"])
	var dominant_prob: float = float(probs[dominant_id]) if probs.has(dominant_id) else 0.5
	var confidence: float = 0.85
	var justification := build_contextual_justification(
		deme,
		current_cell,
		state,
		dominant_id,
		dominant_prob,
		active_branch,
		lang,
		confidence
	)

	return {
		"probabilities": probs,
		"dominant_decision_id": dominant_id,
		"confidence": confidence,
		"active_branch": active_branch,
		"justification": justification
	}


static func build_contextual_justification(
	deme: EvoTypes.Deme,
	_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	dominant_id: String,
	dominant_prob: float,
	active_branch: String,
	lang: String,
	_confidence: float = 0.85
) -> String:
	var is_en := lang == "en"
	var model_tag := deme.decision_model_tag if deme.decision_model_tag != "" else resolve_deme_decision_model_tag(deme.id)
	var dec_name := dominant_id
	if state.decisions_catalog.has(dominant_id):
		dec_name = EvoI18n.decision_name(lang, state.decisions_catalog[dominant_id])
	var pct_str := "%.1f%%" % (dominant_prob * 100.0)

	var branch_reason := ""
	if is_en:
		match active_branch:
			"live_system_one":
				branch_reason = "Live neural decision evaluation via Ollama System 1 (%s)." % model_tag
			"tech_overexploit":
				branch_reason = "Specialized extraction tools without communal conservation drive intensive harvesting and territorial pressure."
			"land_bridge_colonize":
				branch_reason = "Exposed coastal land bridges and viable population size favor rapid spatial dispersal."
			"land_bridge_recover":
				branch_reason = "Small population on coastal corridor prioritizes cooperative storage before migrating."
			"insular_alpine":
				branch_reason = "Bounded insular or harsh alpine/tundra conditions select for communal storage and innovation."
			"arid_savanna":
				branch_reason = "Seasonal aridity in savanna/steppe habitats selects for cooperative storage and mobility."
			"scarcity_competition":
				branch_reason = "Resource scarcity under inter-lineage competition favors collective rationing and dispersal."
			_:
				branch_reason = "Predictable habitat biomass supports low-risk conservative foraging within carrying capacity."
	else:
		match active_branch:
			"live_system_one":
				branch_reason = "Evaluación neuronal de decisión en vivo mediante Ollama System 1 (%s)." % model_tag
			"tech_overexploit":
				branch_reason = "Las herramientas de extracción sin normas de conservación impulsan la sobreexplotación intensiva y la presión territorial."
			"land_bridge_colonize":
				branch_reason = "Los puentes terrestres costeros abiertos y la población viable favorecen la colonización espacial."
			"land_bridge_recover":
				branch_reason = "La baja población en el corredor costero prioriza cooperar y almacenar antes de migrar."
			"insular_alpine":
				branch_reason = "El confinamiento insular o el rigor alpino/tundra seleccionan almacenamiento cooperativo e innovación."
			"arid_savanna":
				branch_reason = "La aridez estacional de sabana/estepa selecciona almacenamiento cooperativo y movilidad."
			"scarcity_competition":
				branch_reason = "La escasez de recursos bajo competencia rival favorece la cooperación y la migración."
			_:
				branch_reason = "La biomasa predecible del hábitat sostiene el forrajeo conservador dentro de la capacidad de carga."
	return "%s (%s): %s" % [dec_name, pct_str, branch_reason]


static func _slugify(text: String) -> String:
	var lower := text.to_lower()
	var out := ""
	var prev_dash := false
	for i in range(lower.length()):
		var ch := lower[i]
		var is_alnum := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		if is_alnum:
			out += ch
			prev_dash = false
		elif not prev_dash and out.length() > 0:
			out += "-"
			prev_dash = true
	out = out.trim_suffix("-")
	if out.length() > 28:
		out = out.substr(0, 28).trim_suffix("-")
	return out if out.length() > 0 else "adaptation"


static func synthesize_milestone_trait(
	state: EvoTypes.WorldState,
	deme: EvoTypes.Deme,
	trigger_type: String,
	lang: String = "es"
) -> EvoTypes.TraitDef:
	var is_en := lang == "en"
	var category := "cultural" if trigger_type == "cultural_innovation" else "biological"
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id] if state.cells.has(deme.hex_id) else EvoTypes.HexCell.new()
	var biome_label := EvoI18n.biome_name(lang, cell.biome)

	var base_name := ""
	if category == "cultural":
		base_name = "Cooperative Ecological Tradition" if is_en else "Tradición Ecológica Cooperativa"
	elif trigger_type == "allopatric_speciation":
		base_name = "Allopatric Divergence" if is_en else "Divergencia Alopátrica"
	else:
		base_name = "Adaptive Homeostasis" if is_en else "Homeostasis Adaptativa"

	var candidate_name := "%s (%s)" % [base_name, biome_label]
	if candidate_name.length() > 60:
		candidate_name = candidate_name.substr(0, 60)

	var existing_names: Dictionary = {}
	for tid in state.traits_catalog.keys():
		var t: EvoTypes.TraitDef = state.traits_catalog[tid]
		existing_names[t.name.to_lower()] = true

	var final_name := candidate_name
	var suffix := 2
	while existing_names.has(final_name.to_lower()):
		var suffix_str := " #%d" % suffix
		final_name = candidate_name.substr(0, max(1, 60 - suffix_str.length())) + suffix_str
		suffix += 1

	var raw_vec: EvoTypes.BiophysicalVector
	if category == "cultural":
		raw_vec = EvoTypes.BiophysicalVector.new(0.20, 0.35, 0.20, 0.15, 0.40, 0.45)
	else:
		raw_vec = EvoTypes.BiophysicalVector.new(0.18, 0.35, 0.10, 0.30, 0.20, 0.20)
	var balanced_vec := EvoThermodynamics.validate_and_balance_thermodynamics(raw_vec, false)

	var slug := _slugify(final_name)
	var sanitized_deme := _slugify(deme.id)
	var base_id := "emergent-%d-%s" % [state.generation, slug]
	var trait_id := base_id if not state.traits_catalog.has(base_id) else "%s-%s" % [base_id, sanitized_deme]
	var id_suffix := 2
	while state.traits_catalog.has(trait_id):
		trait_id = "%s-%s-%d" % [base_id, sanitized_deme, id_suffix]
		id_suffix += 1

	var dom_name := deme.last_dominant_decision_id
	if state.decisions_catalog.has(dom_name):
		dom_name = EvoI18n.decision_name(lang, state.decisions_catalog[dom_name])

	var desc := ""
	if is_en:
		desc = "Emergent adaptation consolidating sustained behavioral selection in %s (%s)." % [biome_label, dom_name]
	else:
		desc = "Adaptación emergente que consolida la selección conductual sostenida en %s (%s)." % [biome_label, dom_name]

	var trait_def := EvoTypes.TraitDef.new()
	trait_def.id = trait_id
	trait_def.name = final_name
	trait_def.category = category
	trait_def.origin = "emergent"
	trait_def.description = desc
	trait_def.vector = balanced_vec
	trait_def.mutually_exclusive_with = []
	trait_def.enables_cultural_transmission = false
	return trait_def
