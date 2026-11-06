class_name EvoHeuristicScorer
extends RefCounted

const DEFAULT_SYSTEM_ONE_MODEL: String = EvoUserSettings.DEFAULT_PRIMARY_MODEL
const SECONDARY_SYSTEM_ONE_MODEL: String = EvoUserSettings.DEFAULT_SECONDARY_MODEL


static func resolve_deme_decision_model_tag(
	deme_id: String,
	primary_tag: String = "",
	secondary_tag: String = ""
) -> String:
	var p_tag := primary_tag if primary_tag != "" else EvoUserSettings.primary_model
	var s_tag := secondary_tag if secondary_tag != "" else EvoUserSettings.secondary_model
	if deme_id in ["deme-rift-west", "deme-island-1", "deme-island-3", "deme-darwin-founder"]:
		return p_tag
	if deme_id in ["deme-rift-east", "deme-island-2"]:
		return s_tag
	var h: int = 0
	for i in range(deme_id.length()):
		h = (h * 31 + deme_id.unicode_at(i)) & 0x7FFFFFFF
	return p_tag if (h % 2 == 0) else s_tag


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
	for n in top_neighbors:
		var n_biome := str(n["biome"])
		var n_count := int(n["demes_count"])
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

	return "\n".join([line1, line2, line3, line4])


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


static func build_contextual_justification(
	deme: EvoTypes.Deme,
	_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	dominant_id: String,
	dominant_prob: float,
	lang: String,
	_confidence: float = 0.85
) -> String:
	var is_en := lang == "en"
	var model_tag := deme.decision_model_tag if deme.decision_model_tag != "" else resolve_deme_decision_model_tag(deme.id)
	var dec_name := dominant_id
	if state.decisions_catalog.has(dominant_id):
		dec_name = EvoI18n.decision_name(lang, state.decisions_catalog[dominant_id])
	var pct_str := "%.1f%%" % (dominant_prob * 100.0)
	var model_reason := (
		"Live neural decision evaluation via Ollama System 1 (%s)." % model_tag
		if is_en
		else "Evaluación neuronal de decisión en vivo mediante Ollama System 1 (%s)." % model_tag
	)
	return "%s (%s): %s" % [dec_name, pct_str, model_reason]


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
