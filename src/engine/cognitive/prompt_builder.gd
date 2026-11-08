class_name EvoPromptBuilder
extends RefCounted


static func _format_signed_metric(val: float) -> String:
	var r := snappedf(val, 0.01)
	return ("+" if r >= 0.0 else "") + str(r)


static func _format_compact_trait(t: EvoTypes.TraitDef) -> String:
	if t.has_meta("compact_str"):
		return str(t.get_meta("compact_str"))
	var v := t.vector
	var s := "%s[cost:%s,extract:%s,eco:%s,mobility:%s,cohesion:%s]" % [
		t.name,
		_format_signed_metric(v.metabolic_cost),
		_format_signed_metric(v.extraction_efficiency),
		_format_signed_metric(v.ecological_impact),
		_format_signed_metric(v.spatial_mobility),
		_format_signed_metric(v.social_cohesion)
	]
	t.set_meta("compact_str", s)
	return s


static func _compute_vitality_status(
	energy_reserves: float,
	last_energy_delta: float,
	_resource_adequacy_ratio: float = 1.0
) -> String:
	if energy_reserves < 25.0 or last_energy_delta <= -10.0:
		return "starving"
	if (last_energy_delta >= 10.0 and energy_reserves >= 40.0) or energy_reserves >= 120.0:
		return "thriving"
	if last_energy_delta < -5.0:
		return "declining"
	return "stable"


static func build_top_strategy_prior(
	deme: EvoTypes.Deme,
	_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var traits_cat := state.traits_catalog if state != null else {}
	var base_probs: Dictionary = EvoCatalog.compute_baseline_decision_weights(deme, traits_cat)["probabilities"]
	var pairs: Array[Dictionary] = []
	for k in base_probs.keys():
		pairs.append({"id": str(k), "w": float(base_probs[k])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["w"]) > float(b["w"])
	)
	var top_prior: Dictionary = {}
	var limit := mini(3, pairs.size())
	for i in range(limit):
		top_prior[str(pairs[i]["id"])] = snappedf(float(pairs[i]["w"]), 0.001)
	return top_prior


static func build_compact_system_one_state(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	precomputed_top_prior: Dictionary = {},
	precomputed_geo_summary: Dictionary = {}
) -> String:
	var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var total_cell_pop: int = deme.population
	var rival_count: int = 0
	var kin_count: int = 0
	for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		for oid in ncell.deme_ids:
			if state.demes.has(oid):
				var other: EvoTypes.Deme = state.demes[oid]
				if other.id != deme.id:
					if other.lineage_id == deme.lineage_id:
						kin_count += 1
					else:
						rival_count += 1

	var resource_adequacy_ratio := snappedf(
		current_cell.current_resources / maxf(10.0, float(total_cell_pop) * 0.48),
		0.01
	)
	var health_pct := int(roundf(
		(current_cell.carrying_capacity / maxf(1.0, current_cell.carrying_capacity_max)) * 100.0
	))
	var vitality := _compute_vitality_status(deme.energy_reserves, deme.last_energy_delta, resource_adequacy_ratio)
	var top_prior := precomputed_top_prior if not precomputed_top_prior.is_empty() else build_top_strategy_prior(deme, current_cell, state)
	var geo_summary := precomputed_geo_summary if not precomputed_geo_summary.is_empty() else EvoGeopoliticsInspector.build_geopolitics_summary(deme, current_cell, state)

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
	var union_str := deme.walled_union_id if deme.walled_union_id != "" else "none"
	var line2 := "Deme \"%s\": pop=%d (%s), reserves=%d, delta=%s, def=Lv%d, merged=%d, tier=%d, salubrity=%.2f, rural=%d, union=%s | CellCompetition: totalPop=%d (rivals=%d, kin=%d)" % [
		deme.name,
		deme.population,
		vitality,
		int(roundf(deme.energy_reserves)),
		delta_str,
		deme.defense_tier,
		deme.merged_count,
		deme.get_village_tier(),
		deme.salubrity,
		int(geo_summary.get("owned_rural_count", 0)),
		union_str,
		total_cell_pop,
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

	var passable_neighbors := EvoGeopoliticsInspector._get_sorted_passable_neighbors(deme, current_cell, state)
	var top_neighbors := passable_neighbors.slice(0, 3)
	var neighbor_parts: Array[String] = []
	for n in top_neighbors:
		var nid := str(n["id"])
		var n_biome := str(n["biome"])
		var n_count := int(n["demes_count"])
		var occ_label := "empty"
		if state.cells.has(nid):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if n_count > 0:
				var primary_occ := EvoGeopoliticsInspector._get_primary_cell_occupant(ncell, state)
				occ_label = EvoGeopoliticsInspector._format_neighbor_occupant_label(deme, primary_occ, state)
			elif ncell.owner_deme_id != "" and ncell.land_use in ["crops", "pasture"]:
				occ_label = "rural:%s(%s)" % [ncell.land_use, "own" if ncell.owner_deme_id == deme.id else ncell.owner_deme_id]
		neighbor_parts.append("%s(%s, res=%d, pop=%d, %s)" % [
			nid,
			n_biome,
			int(roundf(float(n["current_resources"]))),
			int(n["total_population"]),
			occ_label
		])
	var neighbors_text := ", ".join(neighbor_parts) if not neighbor_parts.is_empty() else "none"

	var baldwin_progress: int = 0
	if deme.last_dominant_decision_id != "" and deme.baldwin_counters.has(deme.last_dominant_decision_id):
		baldwin_progress = int(deme.baldwin_counters[deme.last_dominant_decision_id])
	else:
		for k in deme.baldwin_counters.keys():
			baldwin_progress = maxi(baldwin_progress, int(deme.baldwin_counters[k]))
	var dom_str := deme.last_dominant_decision_id if deme.last_dominant_decision_id != "" else "none"
	var line4 := "lastDominant=%s, baldwin=%d/8, innovation=%.2f/1.0 | memory=%s | Neighbors: %s | strategy_traits_prior=%s | geopolitics=%s" % [
		dom_str,
		baldwin_progress,
		deme.innovation_counter,
		str(geo_summary.get("memory", "quiet")),
		neighbors_text,
		JSON.stringify(top_prior),
		JSON.stringify(geo_summary)
	]

	return "\n".join([line1, line2, line3, line4])


static func build_compact_decision_criteria(eligible_decisions: Array[EvoTypes.DecisionDef]) -> Dictionary:
	var criteria: Dictionary = {}
	for dec in eligible_decisions:
		if dec.has_meta("compact_criterion"):
			criteria[dec.id] = str(dec.get_meta("compact_criterion"))
			continue
		var v := dec.vector
		var vec_text := "[cost:%s,extract:%s,eco:%s,mobility:%s,cohesion:%s]" % [
			_format_signed_metric(v.metabolic_cost),
			_format_signed_metric(v.extraction_efficiency),
			_format_signed_metric(v.ecological_impact),
			_format_signed_metric(v.spatial_mobility),
			_format_signed_metric(v.social_cohesion)
		]
		var full_text := ("%s %s: %s" % [dec.name, vec_text, dec.description]).substr(0, 240)
		dec.set_meta("compact_criterion", full_text)
		criteria[dec.id] = full_text
	return criteria


static func compute_deme_evaluation_signature(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var model_key := deme.decision_model_tag if deme.decision_model_tag != "" else EvoHeuristicScorer.resolve_deme_decision_model_tag(deme.id)
	if not state.cells.has(deme.hex_id):
		return "%s|%s|missing" % [model_key, state.season]

	var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var pacts_hash: int = state.active_pacts.hash() if not state.active_pacts.is_empty() else 0
	var n_hash := EvoGeopoliticsInspector._compute_neighbor_state_hash(current_cell, state)
	var traits_cache_key := "%s|%s" % [",".join(deme.biological_trait_ids), ",".join(deme.cultural_trait_ids)]
	var sig_cache_key := "%d|%s|%s|%s|%s|%d|%d|%d|%d|%d|%s|%d|%d|%d|%d|%d|%d|%s|%d" % [
		state.generation,
		state.season,
		model_key,
		deme.hex_id,
		current_cell.biome,
		deme.population,
		int(deme.energy_reserves),
		deme.defense_tier,
		deme.merged_count,
		int(roundf(deme.salubrity * 100.0)),
		deme.walled_union_id,
		state.demes.size(),
		state.chronicle.size(),
		current_cell.deme_ids.size(),
		int(current_cell.current_resources),
		int(current_cell.carrying_capacity),
		pacts_hash,
		traits_cache_key,
		n_hash
	]
	if deme.has_meta("sig_cache_key") and str(deme.get_meta("sig_cache_key")) == sig_cache_key:
		return str(deme.get_meta("sig_cache_val"))
	var total_cell_pop: int = deme.population
	var rival_count: int = 0
	var kin_count: int = 0
	for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		for oid in ncell.deme_ids:
			if state.demes.has(oid):
				var other: EvoTypes.Deme = state.demes[oid]
				if other.id != deme.id:
					if other.lineage_id == deme.lineage_id:
						kin_count += 1
					else:
						rival_count += 1

	var resource_adequacy_ratio := snappedf(
		current_cell.current_resources / maxf(10.0, float(total_cell_pop) * 0.48),
		0.01
	)
	var adequacy_bucket: int = 0 if resource_adequacy_ratio < 0.85 else (1 if resource_adequacy_ratio <= 1.35 else 2)
	var health_ratio := current_cell.carrying_capacity / maxf(1.0, current_cell.carrying_capacity_max)
	var health_bucket: int = 0 if health_ratio < 0.35 else (1 if health_ratio <= 0.80 else 2)
	var vitality := _compute_vitality_status(deme.energy_reserves, deme.last_energy_delta, resource_adequacy_ratio)
	var geo := EvoGeopoliticsInspector.inspect_geopolitical_context(deme, current_cell, state)
	var pact_count := int(geo["active_pacts"])
	var vendetta_flag := 1 if int(geo.get("active_vendettas", 0)) > 0 else 0
	var horde_flag := 1 if bool(geo.get("nearby_horde_threat", false)) else 0
	var surplus_flag := 1 if (bool(geo["neighbor_has_surplus"]) or bool(geo["neighbor_is_weaker"])) else 0
	var sal_val := float(geo.get("salubrity", deme.salubrity))
	var sal_bucket: int = 0 if sal_val < 0.35 else (1 if sal_val < 0.55 else 2)
	var rural_count := int(geo.get("owned_rural_count", 0))
	var needs_rural_flag := 1 if bool(geo.get("needs_rural_hinterland", false)) else 0
	var union_flag := 1 if bool(geo.get("in_walled_union", deme.walled_union_id != "")) else 0
	var same_tier_ally_flag := 1 if bool(geo.get("has_same_tier_ally", false)) else 0
	var mem_tag := str(geo.get("memory_digest", "quiet"))
	var competition_key := "%d:%d:%s:%d:p%d:v%d:h%d:d%d:s%d:t%d:m%d:sal%d:r%d:nr%d:u%d:sta%d:%s" % [
		rival_count,
		kin_count,
		"viable" if deme.population >= 40 else "small",
		1 if bool(geo["has_adjacent_rival"]) else 0,
		pact_count,
		vendetta_flag,
		horde_flag,
		deme.defense_tier,
		surplus_flag,
		deme.get_village_tier(),
		deme.merged_count,
		sal_bucket,
		rural_count,
		needs_rural_flag,
		union_flag,
		same_tier_ally_flag,
		mem_tag
	]

	var traits_key: String
	if deme.has_meta("traits_sig_key") and str(deme.get_meta("traits_sig_key")) == traits_cache_key:
		traits_key = str(deme.get_meta("traits_sig_val"))
	else:
		var all_tids: Array[String] = []
		for tid in deme.biological_trait_ids:
			all_tids.append(tid)
		for tid in deme.cultural_trait_ids:
			all_tids.append(tid)
		all_tids.sort()
		var trait_parts: Array[String] = []
		for tid in all_tids:
			if state.traits_catalog.has(tid):
				var tv: EvoTypes.BiophysicalVector = (state.traits_catalog[tid] as EvoTypes.TraitDef).vector
				trait_parts.append("%s(%.2f,%.2f,%.2f,%.2f,%.2f)" % [
					tid,
					tv.metabolic_cost,
					tv.extraction_efficiency,
					tv.ecological_impact,
					tv.spatial_mobility,
					tv.social_cohesion
				])
			else:
				trait_parts.append(tid)
		traits_key = ",".join(trait_parts)
		deme.set_meta("traits_sig_key", traits_cache_key)
		deme.set_meta("traits_sig_val", traits_key)

	var dec_hash: int = 17
	if state.has_meta("dec_cat_hash") and int(state.get_meta("dec_cat_size", -1)) == state.decisions_catalog.size():
		dec_hash = int(state.get_meta("dec_cat_hash"))
	else:
		var dec_ids: Array[String] = []
		for did in state.decisions_catalog.keys():
			dec_ids.append(str(did))
		dec_ids.sort()
		for did in dec_ids:
			var d_def: EvoTypes.DecisionDef = state.decisions_catalog[did]
			var dv := d_def.vector
			var d_str := "%s:%.2f:%.2f:%.2f:%.2f:%.2f" % [
				did,
				dv.metabolic_cost,
				dv.extraction_efficiency,
				dv.ecological_impact,
				dv.spatial_mobility,
				dv.social_cohesion
			]
			dec_hash = ((dec_hash * 31) + d_str.hash()) & 0x7FFFFFFF
		state.set_meta("dec_cat_hash", dec_hash)
		state.set_meta("dec_cat_size", state.decisions_catalog.size())

	var dominant_key := "%x" % dec_hash

	var passable_neighbors := EvoGeopoliticsInspector._get_sorted_passable_neighbors(deme, current_cell, state).slice(0, 3)
	var n_keys: Array[String] = []
	for n in passable_neighbors:
		var nid := str(n["id"])
		var n_count := int(n["demes_count"])
		var n_rel_tag := "empty"
		if state.cells.has(nid):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			var primary_occ := EvoGeopoliticsInspector._get_primary_cell_occupant(ncell, state) if n_count > 0 else null
			n_rel_tag = EvoGeopoliticsInspector._format_neighbor_sig_tag(deme, primary_occ, state, ncell)
		var n_res_bucket := int(roundf(float(n["current_resources"]) / 150.0))
		n_keys.append("%s:%s:%d" % [str(n["biome"]), n_rel_tag, n_res_bucket])
	var neighbor_key := ",".join(n_keys)

	var final_sig := "%s|%s|%s|%d|%d|%s|%s|%s|%s|%s" % [
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
	deme.set_meta("sig_cache_key", sig_cache_key)
	deme.set_meta("sig_cache_val", final_sig)
	return final_sig


static func build_contextual_justification(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	dominant_id: String,
	dominant_prob: float,
	lang: String,
	_confidence: float = 0.85
) -> String:
	var is_en := lang == "en"
	var model_tag := deme.decision_model_tag if deme.decision_model_tag != "" else EvoHeuristicScorer.resolve_deme_decision_model_tag(deme.id)
	var dec_name := dominant_id
	if state != null and state.decisions_catalog.has(dominant_id):
		dec_name = EvoI18n.decision_name(lang, state.decisions_catalog[dominant_id])
	var pct_str := "%.1f%%" % (dominant_prob * 100.0)
	var ctx_parts: Array[String] = []
	if deme != null and cell != null and state != null:
		var geo := EvoGeopoliticsInspector.inspect_geopolitical_context(deme, cell, state)
		if bool(geo.get("nearby_horde_threat", false)):
			ctx_parts.append("nearby horde threat" if is_en else "amenaza de horda cercana")
		if int(geo.get("active_vendettas", 0)) > 0:
			ctx_parts.append("active vendetta (%d)" % int(geo["active_vendettas"]) if is_en else "vendetta activa (%d)" % int(geo["active_vendettas"]))
		if int(geo.get("active_pacts", 0)) > 0:
			ctx_parts.append("allied pacts=%d" % int(geo["active_pacts"]) if is_en else "pactos aliados=%d" % int(geo["active_pacts"]))
		if deme.defense_tier > 0:
			ctx_parts.append("defense Lv.%d" % deme.defense_tier if is_en else "defensa Nv.%d" % deme.defense_tier)
		if deme.salubrity < 0.55:
			ctx_parts.append("low salubrity (%d%%)" % int(roundf(deme.salubrity * 100.0)) if is_en else "baja salubridad (%d%%)" % int(roundf(deme.salubrity * 100.0)))
		if deme.walled_union_id != "":
			ctx_parts.append("walled union" if is_en else "unión amurallada")
		if int(geo.get("owned_rural_count", 0)) > 0:
			ctx_parts.append("rural=%d" % int(geo["owned_rural_count"]))
		var adeq := float(geo.get("env_adequacy", 1.0))
		if adeq < 0.85:
			ctx_parts.append("caloric deficit (%.2fx)" % adeq if is_en else "déficit calórico (%.2fx)" % adeq)
		elif adeq >= 1.35:
			ctx_parts.append("ecological surplus (%.2fx)" % adeq if is_en else "superávit ecológico (%.2fx)" % adeq)
		else:
			ctx_parts.append("adequacy %.2fx" % adeq if is_en else "adecuación %.2fx" % adeq)
	var ctx_suffix := (" [%s]" % ", ".join(ctx_parts)) if not ctx_parts.is_empty() else ""
	var model_reason := (
		"Live neural decision evaluation via Ollama System 1 (%s)%s." % [model_tag, ctx_suffix]
		if is_en
		else "Evaluación neuronal de decisión en vivo mediante Ollama System 1 (%s)%s." % [model_tag, ctx_suffix]
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

	var baldwin_dec_id := str(deme.get_meta("baldwin_decision_id", "")) if deme.has_meta("baldwin_decision_id") else ""
	if baldwin_dec_id == "":
		baldwin_dec_id = deme.last_dominant_decision_id

	var raw_vec: EvoTypes.BiophysicalVector
	if category == "cultural":
		raw_vec = EvoTypes.BiophysicalVector.new(0.20, 0.35, 0.20, 0.15, 0.40, 0.45)
	elif trigger_type == "baldwin_assimilation" and baldwin_dec_id != "" and state.decisions_catalog.has(baldwin_dec_id):
		var dom_dec: EvoTypes.DecisionDef = state.decisions_catalog[baldwin_dec_id]
		var dv := dom_dec.vector
		raw_vec = EvoTypes.BiophysicalVector.new(
			maxf(0.10, dv.metabolic_cost * 0.70),
			clampf(maxf(0.15, dv.extraction_efficiency * 0.80), 0.0, 0.85),
			clampf(dv.ecological_impact * 0.60, -0.50, 0.50),
			clampf(maxf(0.10, dv.spatial_mobility * 0.80), 0.0, 0.85),
			clampf(maxf(0.10, dv.social_cohesion * 0.80), 0.0, 0.85),
			clampf(maxf(0.20, dv.transmission_threshold * 0.80), 0.10, 0.85)
		)
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

	var dom_name := baldwin_dec_id if trigger_type == "baldwin_assimilation" else deme.last_dominant_decision_id
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
