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
	if deme_id in ["deme-rift-west", "deme-island-1", "deme-darwin-founder"]:
		return p_tag
	if deme_id in ["deme-rift-east", "deme-island-2", "deme-darwin-rival"]:
		return s_tag
	var h: int = 0
	for i in range(deme_id.length()):
		h = (h * 31 + deme_id.unicode_at(i)) & 0x7FFFFFFF
	return p_tag if (h % 2 == 0) else s_tag


static func is_decision_eligible(
	deme: EvoTypes.Deme,
	dec: EvoTypes.DecisionDef,
	traits_catalog: Dictionary = {},
	state: EvoTypes.WorldState = null
) -> bool:
	if dec.id in ["dec-explore-innovate", "dec-exchange-symbiosis"]:
		var has_cap := false
		if not traits_catalog.is_empty():
			has_cap = EvoCatalog.deme_has_cultural_capacity(deme, traits_catalog)
		else:
			for tid in deme.biological_trait_ids:
				if tid in ["bio-encephalization", "bio-social-instinct"]:
					has_cap = true
					break
		if not has_cap:
			return false
		if dec.required_trait_ids == ["bio-encephalization", "bio-social-instinct"]:
			return true
	if state != null and dec.id == "dec-territorial-dispute":
		if not _has_nearby_rival_deme(deme, state):
			return false
	if dec.required_trait_ids.is_empty():
		return true
	for req_id in dec.required_trait_ids:
		if deme.biological_trait_ids.has(req_id) or deme.cultural_trait_ids.has(req_id):
			return true
	return false


static func _has_nearby_rival_deme(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> bool:
	if state == null or not state.cells.has(deme.hex_id):
		return true
	var geo := EvoGeopoliticsInspector.inspect_geopolitical_context(deme, state.cells[deme.hex_id], state)
	var has_warrior := EvoCatalog.deme_has_trait(deme, "cul-warrior-expansion")
	return (
		bool(geo.get("has_adjacent_rival", false))
		or bool(geo.get("has_betrayal_temptation", false))
		or bool(geo.get("has_hinterland_rival", false))
		or bool(geo.get("has_raiding_temptation", false))
		or (has_warrior and (bool(geo.get("has_nearby_2hex_rival", false)) or bool(geo.get("has_pact_neighbor", false))))
	)


static func get_eligible_decisions(
	deme: EvoTypes.Deme,
	decisions_catalog: Dictionary,
	traits_catalog: Dictionary = {},
	state: EvoTypes.WorldState = null
) -> Array[EvoTypes.DecisionDef]:
	var effective_traits := traits_catalog if not traits_catalog.is_empty() else (state.traits_catalog if state != null else {})
	var result: Array[EvoTypes.DecisionDef] = []
	for dec_id in decisions_catalog.keys():
		var dec: EvoTypes.DecisionDef = decisions_catalog[dec_id]
		if is_decision_eligible(deme, dec, effective_traits):
			result.append(dec)
	if state != null and result.size() > 1 and not _has_nearby_rival_deme(deme, state):
		var filtered: Array[EvoTypes.DecisionDef] = []
		for dec in result:
			if dec.id != "dec-territorial-dispute":
				filtered.append(dec)
		if not filtered.is_empty():
			result = filtered
	return result


static func get_eligible_decision_ids(
	deme: EvoTypes.Deme,
	decisions_catalog: Dictionary,
	traits_catalog: Dictionary = {},
	state: EvoTypes.WorldState = null
) -> Array[String]:
	var eligible_decs := get_eligible_decisions(deme, decisions_catalog, traits_catalog, state)
	var ids: Array[String] = []
	for dec in eligible_decs:
		ids.append(dec.id)
	return ids


static func pick_dominant_decision(probs: Dictionary) -> String:
	var best_id := "dec-conservative-forage"
	var best_prob := -1.0
	for dec_id in probs.keys():
		var p := float(probs[dec_id])
		if p > best_prob:
			best_prob = p
			best_id = str(dec_id)
	return best_id


static func build_env_weights_cache_key(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> String:
	var pacts_hash: int = state.active_pacts.hash() if (state != null and not state.active_pacts.is_empty()) else 0
	var n_hash := EvoGeopoliticsInspector._compute_neighbor_state_hash(cell, state)
	return "%d|%s|%s|%d|%d|%d|%.1f|%d|%d|%d|%s|%s|%s|%d|%d" % [
		state.generation if state != null else -1,
		state.season if state != null else "",
		cell.id if cell != null else "",
		int(cell.current_resources) if cell != null else 0,
		int(cell.carrying_capacity) if cell != null else 0,
		deme.population,
		deme.energy_reserves,
		deme.defense_tier,
		deme.merged_count,
		int(roundf(deme.salubrity * 100.0)),
		deme.walled_union_id,
		",".join(deme.biological_trait_ids),
		",".join(deme.cultural_trait_ids),
		pacts_hash,
		n_hash
	]


static func compute_environmental_decision_weights(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var traits_cat := state.traits_catalog if state != null else {}
	var decs_cat := state.decisions_catalog if (state != null and not state.decisions_catalog.is_empty()) else EvoCatalog.create_base_decisions_catalog()
	var base_w_key := "%s|%s|%d" % [
		",".join(deme.biological_trait_ids),
		",".join(deme.cultural_trait_ids),
		decs_cat.size()
	]
	var base_probs: Dictionary
	var base_eligible: Array[String]
	var deme_vec: EvoTypes.BiophysicalVector
	if deme.has_meta("base_w_key") and str(deme.get_meta("base_w_key")) == base_w_key:
		base_probs = deme.get_meta("base_w_probs") as Dictionary
		base_eligible = deme.get_meta("base_w_elig") as Array[String]
		deme_vec = deme.get_meta("base_w_vec") as EvoTypes.BiophysicalVector
	else:
		base_probs = EvoCatalog.compute_baseline_decision_weights(deme, traits_cat)["probabilities"] as Dictionary
		base_eligible = get_eligible_decision_ids(deme, decs_cat, traits_cat, null)
		deme_vec = EvoCatalog.compute_deme_vector(deme, traits_cat)
		deme.set_meta("base_w_key", base_w_key)
		deme.set_meta("base_w_probs", base_probs)
		deme.set_meta("base_w_elig", base_eligible)
		deme.set_meta("base_w_vec", deme_vec)

	var weights: Dictionary = base_probs.duplicate()
	var geo := EvoGeopoliticsInspector.inspect_geopolitical_context(deme, cell, state) if (cell != null and state != null) else {}
	var has_warrior := EvoCatalog.deme_has_trait(deme, "cul-warrior-expansion")
	var has_adjacent_rival: bool = bool(geo.get("has_adjacent_rival", true))
	var has_hinterland_rival: bool = bool(geo.get("has_hinterland_rival", false))
	var has_nearby_2hex_rival: bool = bool(geo.get("has_nearby_2hex_rival", false))
	var has_raiding_temptation: bool = bool(geo.get("has_raiding_temptation", false))
	var has_betrayal_temptation: bool = bool(geo.get("has_betrayal_temptation", false))
	var has_pact_neighbor: bool = bool(geo.get("has_pact_neighbor", false))
	var dispute_eligible: bool = (
		has_adjacent_rival
		or has_betrayal_temptation
		or has_hinterland_rival
		or has_raiding_temptation
		or (has_warrior and (has_nearby_2hex_rival or has_pact_neighbor))
	)
	var eligible_ids: Array[String] = base_eligible
	if state != null and base_eligible.size() > 1 and not dispute_eligible:
		weights["dec-territorial-dispute"] = 0.0
		var filtered: Array[String] = []
		for dec_id in base_eligible:
			if dec_id == "dec-territorial-dispute":
				continue
			filtered.append(dec_id)
		if not filtered.is_empty():
			eligible_ids = filtered

	for dec_id in eligible_ids:
		if not weights.has(dec_id):
			weights[dec_id] = 0.08

	if cell == null or state == null:
		return normalize_decision_probabilities(weights, eligible_ids)["probabilities"]

	var cell_pop := int(geo.get("cell_pop", deme.population))
	var adequacy := cell.current_resources / maxf(1.0, float(cell_pop) * 0.85)
	var k_ratio := cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max)
	var reserve_stress := clampf((60.0 - deme.energy_reserves) / 60.0, 0.0, 1.0)
	var crowding := clampf(float(cell_pop) / maxf(1.0, cell.carrying_capacity), 0.0, 2.0)

	var neighbor_has_surplus := bool(geo["neighbor_has_surplus"])
	var neighbor_is_weaker := bool(geo["neighbor_is_weaker"])
	var has_active_pact := bool(geo["has_active_pact"])
	var is_abundant := adequacy >= 1.25 and deme.energy_reserves >= 55.0 and state.season == "wet_warm" and crowding < 0.85
	var warrior_frontline := has_warrior and deme.population >= 50 and (has_adjacent_rival or has_hinterland_rival or has_raiding_temptation or has_betrayal_temptation or has_nearby_2hex_rival)

	if is_abundant:
		if (not has_warrior or deme.population < 50) and weights.has("dec-territorial-dispute"):
			weights["dec-territorial-dispute"] = float(weights["dec-territorial-dispute"]) * 0.18
		if weights.has("dec-intensive-overexploit"):
			weights["dec-intensive-overexploit"] = float(weights["dec-intensive-overexploit"]) * 0.45
		if not warrior_frontline:
			if weights.has("dec-conservative-forage"):
				weights["dec-conservative-forage"] = float(weights["dec-conservative-forage"]) * 1.95
			if weights.has("dec-cooperate-store"):
				weights["dec-cooperate-store"] = float(weights["dec-cooperate-store"]) * 1.35
			if weights.has("dec-exchange-symbiosis"):
				weights["dec-exchange-symbiosis"] = float(weights["dec-exchange-symbiosis"]) * 1.35
			if weights.has("dec-explore-innovate"):
				weights["dec-explore-innovate"] = float(weights["dec-explore-innovate"]) * 1.45
	elif adequacy < 1.05 or state.season == "dry_cold" or reserve_stress > 0.25 or k_ratio < 0.78 or crowding >= 0.85:
		var env_pressure := clampf(
			(1.15 - adequacy) * 0.6
			+ reserve_stress * 0.5
			+ (0.25 if state.season == "dry_cold" else 0.0)
			+ maxf(0.0, crowding - 0.75) * 0.5
			+ maxf(0.0, 0.85 - k_ratio) * 0.5,
			0.0,
			2.0
		)
		var vec := deme_vec
		var is_martial := (
			has_warrior
			or EvoCatalog.deme_has_trait(deme, "cul-extraction-tools")
			or EvoCatalog.deme_has_trait(deme, "bio-r-strategy")
			or vec.social_cohesion < 0.0
		)
		if is_martial:
			var opp_mult := 1.35 if (neighbor_has_surplus or neighbor_is_weaker or has_raiding_temptation) else 1.0
			var disp_boost := 1.0 + env_pressure * (1.8 if has_warrior else 1.1) * opp_mult
			if weights.has("dec-territorial-dispute"):
				weights["dec-territorial-dispute"] = float(weights["dec-territorial-dispute"]) * disp_boost
			if weights.has("dec-intensive-overexploit"):
				weights["dec-intensive-overexploit"] = float(weights["dec-intensive-overexploit"]) * (1.0 + env_pressure * 1.15)
			if has_adjacent_rival and (has_warrior or crowding > 0.80) and weights.has("dec-selective-migration"):
				weights["dec-selective-migration"] = float(weights["dec-selective-migration"]) * (1.0 + env_pressure * 1.25)

		var is_cooperative := (
			EvoCatalog.deme_has_trait(deme, "cul-communal-conservation")
			or (EvoCatalog.deme_has_trait(deme, "bio-social-instinct") and not has_warrior and not EvoCatalog.deme_has_trait(deme, "bio-r-strategy"))
			or (has_active_pact and not is_martial and not has_betrayal_temptation)
		)
		if is_cooperative:
			if weights.has("dec-cooperate-store"):
				weights["dec-cooperate-store"] = float(weights["dec-cooperate-store"]) * (1.0 + env_pressure * 1.35)
			if weights.has("dec-conservative-forage"):
				weights["dec-conservative-forage"] = float(weights["dec-conservative-forage"]) * (1.0 + env_pressure * 0.90)

		var is_trade_mobile := (
			EvoCatalog.deme_has_trait(deme, "cul-interdeme-barter")
			or EvoCatalog.deme_has_trait(deme, "bio-thermal-tolerance")
		)
		if is_trade_mobile:
			if weights.has("dec-exchange-symbiosis"):
				weights["dec-exchange-symbiosis"] = float(weights["dec-exchange-symbiosis"]) * (1.0 + env_pressure * 1.40)
			if weights.has("dec-selective-migration"):
				weights["dec-selective-migration"] = float(weights["dec-selective-migration"]) * (1.0 + env_pressure * 1.30)

		var is_cognitive := (
			EvoCatalog.deme_has_trait(deme, "bio-encephalization")
			or EvoCatalog.deme_has_trait(deme, "bio-digestive-spec")
			or EvoCatalog.deme_has_trait(deme, "cul-fire-processing")
		)
		if is_cognitive and weights.has("dec-explore-innovate"):
			weights["dec-explore-innovate"] = float(weights["dec-explore-innovate"]) * (1.0 + env_pressure * 1.35)

	if has_warrior and (deme.population >= 50 or not is_abundant):
		var has_target := has_adjacent_rival or has_hinterland_rival or has_raiding_temptation or has_betrayal_temptation or has_nearby_2hex_rival
		if has_target and weights.has("dec-territorial-dispute"):
			var w_boost := 1.55
			if has_adjacent_rival or has_hinterland_rival:
				w_boost += 0.45
			if has_raiding_temptation:
				w_boost += 0.28
			if has_betrayal_temptation:
				w_boost += 0.25
			if has_nearby_2hex_rival:
				w_boost += 0.22
			weights["dec-territorial-dispute"] = float(weights["dec-territorial-dispute"]) * w_boost
			if weights.has("dec-intensive-overexploit"):
				weights["dec-intensive-overexploit"] = float(weights["dec-intensive-overexploit"]) * 0.52
			if weights.has("dec-cooperate-store"):
				weights["dec-cooperate-store"] = float(weights["dec-cooperate-store"]) * 0.42
			if weights.has("dec-exchange-symbiosis"):
				weights["dec-exchange-symbiosis"] = float(weights["dec-exchange-symbiosis"]) * 0.35
			if weights.has("dec-conservative-forage"):
				weights["dec-conservative-forage"] = float(weights["dec-conservative-forage"]) * 0.58

	if has_betrayal_temptation and (not is_abundant or (has_warrior and deme.population >= 50)):
		if weights.has("dec-territorial-dispute"):
			weights["dec-territorial-dispute"] = float(weights["dec-territorial-dispute"]) * (1.55 + 0.35 * reserve_stress)
		if weights.has("dec-intensive-overexploit"):
			weights["dec-intensive-overexploit"] = float(weights["dec-intensive-overexploit"]) * (1.30 + 0.25 * reserve_stress)

	if not has_warrior and int(geo.get("owned_rural_count", 0)) >= 2 and int(geo.get("extended_frontier_count", 0)) > 0:
		var pop_ratio := float(cell_pop) / maxf(1.0, cell.carrying_capacity)
		if (pop_ratio >= 0.72 or int(geo.get("adjacent_rivals", 0)) > 0) and weights.has("dec-selective-migration"):
			weights["dec-selective-migration"] = float(weights["dec-selective-migration"]) + 0.32 + clampf(pop_ratio - 0.65, 0.0, 0.5) * 0.45

	if bool(geo.get("nearby_horde_threat", false)) or int(geo.get("active_vendettas", 0)) > 0:
		var has_warrior_trait := EvoCatalog.deme_has_trait(deme, "cul-warrior-expansion")
		if not has_warrior_trait:
			if weights.has("dec-cooperate-store"):
				weights["dec-cooperate-store"] = float(weights["dec-cooperate-store"]) * 1.28
			if weights.has("dec-exchange-symbiosis"):
				weights["dec-exchange-symbiosis"] = float(weights["dec-exchange-symbiosis"]) * 1.18
		if has_warrior_trait:
			if weights.has("dec-territorial-dispute"):
				weights["dec-territorial-dispute"] = float(weights["dec-territorial-dispute"]) * 1.22

	var cur_salubrity := float(geo.get("salubrity", deme.salubrity))
	if cur_salubrity < 0.55 or bool(geo.get("has_same_tier_ally", false)):
		if weights.has("dec-cooperate-store"):
			weights["dec-cooperate-store"] = float(weights["dec-cooperate-store"]) * 1.22
		if weights.has("dec-exchange-symbiosis"):
			weights["dec-exchange-symbiosis"] = float(weights["dec-exchange-symbiosis"]) * 1.18
	if cur_salubrity < 0.35 and weights.has("dec-intensive-overexploit"):
		weights["dec-intensive-overexploit"] = float(weights["dec-intensive-overexploit"]) * 0.75

	if bool(geo.get("needs_rural_hinterland", false)):
		if weights.has("dec-selective-migration"):
			weights["dec-selective-migration"] = float(weights["dec-selective-migration"]) * 1.25
		if weights.has("dec-intensive-overexploit"):
			weights["dec-intensive-overexploit"] = float(weights["dec-intensive-overexploit"]) * 1.15

	if weights.has("dec-exchange-symbiosis"):
		if not bool(geo.get("has_nearby_deme", false)):
			weights["dec-exchange-symbiosis"] = float(weights["dec-exchange-symbiosis"]) * 0.25

	if weights.has("dec-explore-innovate"):
		var emergent_cul_count: int = 0
		for tid in deme.cultural_trait_ids:
			if traits_cat.has(tid) and (traits_cat[tid] as EvoTypes.TraitDef).origin == "emergent":
				emergent_cul_count += 1
		if emergent_cul_count >= 2:
			weights["dec-explore-innovate"] = float(weights["dec-explore-innovate"]) * 0.15

	return normalize_decision_probabilities(weights, eligible_ids)["probabilities"]


static func blend_with_environmental_weights(
	current_probs: Dictionary,
	env_weights: Dictionary,
	eligible_ids: Array[String],
	cur_weight: float = 0.30,
	env_weight: float = 0.70
) -> Dictionary:
	var blended: Dictionary = {}
	for dec_id in eligible_ids:
		var env_w := float(env_weights.get(dec_id, 0.0))
		var cur_p := float(current_probs.get(dec_id, 0.0))
		blended[dec_id] = (cur_weight * cur_p + env_weight * env_w) if env_w > 0.0 else 0.0
	return normalize_decision_probabilities(blended, eligible_ids)


static func modulate_deme_probabilities_for_turn(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> void:
	if deme == null or cell == null or state == null:
		return
	var env_weights := compute_environmental_decision_weights(deme, cell, state)
	deme.set_meta("env_w_key", build_env_weights_cache_key(deme, cell, state))
	deme.set_meta("env_w_val", env_weights)
	var eligible_ids: Array[String] = []
	for k in env_weights.keys():
		eligible_ids.append(str(k))
	if eligible_ids.is_empty():
		return

	if deme.last_decision_probabilities.size() <= 1 and float(deme.last_decision_probabilities.get("dec-conservative-forage", 0.0)) >= 0.999:
		EvoCatalog.compute_strategy_baseline_probabilities(deme, state.traits_catalog)

	var norm := blend_with_environmental_weights(deme.last_decision_probabilities, env_weights, eligible_ids, 0.30, 0.70)
	deme.last_decision_probabilities = norm["probabilities"]
	deme.last_dominant_decision_id = pick_dominant_decision(deme.last_decision_probabilities)


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


static func inspect_geopolitical_context(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	return EvoGeopoliticsInspector.inspect_geopolitical_context(deme, cell, state)


static func _get_sorted_passable_neighbors(
	deme: EvoTypes.Deme,
	current_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Array[Dictionary]:
	return EvoGeopoliticsInspector._get_sorted_passable_neighbors(deme, current_cell, state)


static func _get_primary_cell_occupant(cell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	return EvoGeopoliticsInspector._get_primary_cell_occupant(cell, state)


static func _format_neighbor_occupant_label(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> String:
	return EvoGeopoliticsInspector._format_neighbor_occupant_label(deme, other, state)


static func _format_neighbor_sig_tag(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	ncell: EvoTypes.HexCell = null
) -> String:
	return EvoGeopoliticsInspector._format_neighbor_sig_tag(deme, other, state, ncell)


static func build_geopolitics_summary(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	return EvoGeopoliticsInspector.build_geopolitics_summary(deme, cell, state)


static func build_deme_memory_summary(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	active_vendettas: int = 0,
	nearby_horde_threat: bool = false
) -> String:
	return EvoGeopoliticsInspector.build_deme_memory_summary(deme, state, active_vendettas, nearby_horde_threat)


static func invalidate_state_caches(state: EvoTypes.WorldState) -> void:
	EvoGeopoliticsInspector.invalidate_state_caches(state)


static func build_top_strategy_prior(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	return EvoPromptBuilder.build_top_strategy_prior(deme, cell, state)


static func build_compact_system_one_state(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	precomputed_top_prior: Dictionary = {},
	precomputed_geo_summary: Dictionary = {}
) -> String:
	return EvoPromptBuilder.build_compact_system_one_state(deme, state, precomputed_top_prior, precomputed_geo_summary)


static func build_compact_decision_criteria(eligible_decisions: Array[EvoTypes.DecisionDef]) -> Dictionary:
	return EvoPromptBuilder.build_compact_decision_criteria(eligible_decisions)


static func compute_deme_evaluation_signature(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	return EvoPromptBuilder.compute_deme_evaluation_signature(deme, state)


static func build_contextual_justification(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	dominant_id: String,
	dominant_prob: float,
	lang: String,
	confidence: float = 0.85
) -> String:
	return EvoPromptBuilder.build_contextual_justification(deme, cell, state, dominant_id, dominant_prob, lang, confidence)


static func _slugify(text: String) -> String:
	return EvoPromptBuilder._slugify(text)


static func synthesize_milestone_trait(
	state: EvoTypes.WorldState,
	deme: EvoTypes.Deme,
	trigger_type: String,
	lang: String = "es"
) -> EvoTypes.TraitDef:
	return EvoPromptBuilder.synthesize_milestone_trait(state, deme, trigger_type, lang)
