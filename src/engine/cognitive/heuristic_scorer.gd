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
	var geo := inspect_geopolitical_context(deme, state.cells[deme.hex_id], state)
	return bool(geo["has_intra_rival"]) or bool(geo["has_adjacent_rival"])


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


static func _get_cell_total_population(cell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> int:
	if cell == null or state == null:
		return 0
	var total_pop: int = 0
	for oid in cell.deme_ids:
		if state.demes.has(oid):
			total_pop += (state.demes[oid] as EvoTypes.Deme).population
	return total_pop


static func inspect_geopolitical_context(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var has_pacts: bool = state != null and not state.active_pacts.is_empty()
	var pacts_hash: int = state.active_pacts.hash() if has_pacts else 0
	var cache_key := "%d|%s|%d|%d|%d|%d|%d|%d|%d|%.1f" % [
		state.generation if state != null else -1,
		cell.id if cell != null else "",
		pacts_hash,
		state.chronicle.size() if state != null else 0,
		state.demes.size() if state != null else 0,
		cell.deme_ids.size() if cell != null else 0,
		deme.population,
		deme.defense_tier,
		deme.merged_count,
		deme.energy_reserves
	]
	if deme != null and deme.has_meta("geo_ctx_key") and str(deme.get_meta("geo_ctx_key")) == cache_key:
		return deme.get_meta("geo_ctx_val") as Dictionary

	var has_intra_rival := false
	var has_adjacent_rival := false
	var has_nearby_deme := false
	var neighbor_has_surplus := false
	var neighbor_is_weaker := false
	var has_active_pact := false
	var active_pact_count: int = 0
	var active_vendettas: int = 0
	var adjacent_rivals_count: int = 0
	var nearby_horde_threat := false
	var max_neighbor_reserves: float = 0.0

	if has_pacts:
		var pacts_key := "%d|%d" % [state.generation, pacts_hash]
		var pact_counts: Dictionary
		var vendetta_counts: Dictionary
		if state.has_meta("pact_counts_key") and str(state.get_meta("pact_counts_key")) == pacts_key and state.has_meta("vendetta_counts_val"):
			pact_counts = state.get_meta("pact_counts_val") as Dictionary
			vendetta_counts = state.get_meta("vendetta_counts_val") as Dictionary
		else:
			pact_counts = {}
			vendetta_counts = {}
			for pk_var in state.active_pacts.keys():
				var p_val := int(state.active_pacts[pk_var])
				if p_val >= 2 or p_val < 0:
					var pk := str(pk_var)
					var sep := "__" if pk.contains("__") else "|"
					var parts := pk.split(sep)
					if parts.size() == 2 and state.demes.has(parts[0]) and state.demes.has(parts[1]):
						if p_val >= 2:
							pact_counts[parts[0]] = int(pact_counts.get(parts[0], 0)) + 1
							pact_counts[parts[1]] = int(pact_counts.get(parts[1], 0)) + 1
						else:
							vendetta_counts[parts[0]] = int(vendetta_counts.get(parts[0], 0)) + 1
							vendetta_counts[parts[1]] = int(vendetta_counts.get(parts[1], 0)) + 1
			state.set_meta("pact_counts_key", pacts_key)
			state.set_meta("pact_counts_val", pact_counts)
			state.set_meta("vendetta_counts_val", vendetta_counts)
		active_pact_count = int(pact_counts.get(deme.id, 0))
		active_vendettas = int(vendetta_counts.get(deme.id, 0))
		has_active_pact = active_pact_count > 0

	var cell_pop: int = deme.population
	if cell != null and state != null:
		var sum_pop: int = 0
		for oid in cell.deme_ids:
			if state.demes.has(oid):
				var other: EvoTypes.Deme = state.demes[oid]
				sum_pop += other.population
				if other.id != deme.id:
					has_nearby_deme = true
					max_neighbor_reserves = maxf(max_neighbor_reserves, other.energy_reserves)
					if other.lineage_id != deme.lineage_id and (not has_pacts or not EvoTypes.is_pact_active(state, deme.id, other.id)):
						has_intra_rival = true
						adjacent_rivals_count += 1
						if other.energy_reserves > deme.energy_reserves * 1.15:
							neighbor_has_surplus = true
						if other.population < int(float(deme.population) * 0.85) or other.energy_reserves < 45.0:
							neighbor_is_weaker = true
						if other.population >= 55 and (other.cultural_trait_ids.has("cul-warrior-expansion") or other.id.contains("-w") or other.last_dominant_decision_id == "dec-territorial-dispute"):
							nearby_horde_threat = true
		cell_pop = maxi(deme.population, sum_pop)

		for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			for oid in ncell.deme_ids:
				if state.demes.has(oid):
					var other: EvoTypes.Deme = state.demes[oid]
					if other.id != deme.id:
						has_nearby_deme = true
						max_neighbor_reserves = maxf(max_neighbor_reserves, other.energy_reserves)
						if other.lineage_id != deme.lineage_id and (not has_pacts or not EvoTypes.is_pact_active(state, deme.id, other.id)):
							has_adjacent_rival = true
							adjacent_rivals_count += 1
							if ncell.current_resources > cell.current_resources * 1.15 or other.energy_reserves > deme.energy_reserves * 1.15:
								neighbor_has_surplus = true
							if other.population < int(float(deme.population) * 0.85) or other.energy_reserves < 45.0:
								neighbor_is_weaker = true
							if ncell.biome != "ocean" and ncell.altitude <= 0.85 and other.population >= 55:
								if other.cultural_trait_ids.has("cul-warrior-expansion") or other.id.contains("-w") or other.last_dominant_decision_id == "dec-territorial-dispute":
									nearby_horde_threat = true
			if not nearby_horde_threat and ncell.biome != "ocean" and ncell.altitude <= 0.85:
				var horde_chk_key := "%d|%d" % [state.generation, state.demes.size()]
				var world_has_horde: bool = false
				if state.has_meta("world_horde_key") and str(state.get_meta("world_horde_key")) == horde_chk_key:
					world_has_horde = bool(state.get_meta("world_horde_val"))
				else:
					for hd_id in state.demes.keys():
						var hd: EvoTypes.Deme = state.demes[hd_id]
						if hd.population >= 55 and (hd.cultural_trait_ids.has("cul-warrior-expansion") or hd.id.contains("-w") or hd.last_dominant_decision_id == "dec-territorial-dispute"):
							world_has_horde = true
							break
					state.set_meta("world_horde_key", horde_chk_key)
					state.set_meta("world_horde_val", world_has_horde)
				if world_has_horde:
					for n2id in HexMath.get_neighbor_ids(ncell.q, ncell.r, state.cells):
						if n2id == cell.id:
							continue
						var n2cell: EvoTypes.HexCell = state.cells[n2id]
						if n2cell.deme_ids.is_empty() or n2cell.biome == "ocean" or n2cell.altitude > 0.85:
							continue
						for o2id in n2cell.deme_ids:
							if state.demes.has(o2id):
								var o2: EvoTypes.Deme = state.demes[o2id]
								if o2.id != deme.id and o2.population >= 55 and o2.lineage_id != deme.lineage_id and (not has_pacts or not EvoTypes.is_pact_active(state, deme.id, o2.id)):
									if o2.cultural_trait_ids.has("cul-warrior-expansion") or o2.id.contains("-w") or o2.last_dominant_decision_id == "dec-territorial-dispute":
										nearby_horde_threat = true
										break
						if nearby_horde_threat:
							break

	var mem_tokens: Array[String] = []
	if state != null and not state.chronicle.is_empty():
		var min_gen := state.generation - 6
		var idx := state.chronicle.size() - 1
		while idx >= 0 and mem_tokens.size() < 3:
			var entry: EvoTypes.ChronicleEntry = state.chronicle[idx]
			if entry.generation < min_gen:
				break
			if entry.deme_id == deme.id or entry.id.contains(deme.id) or entry.hex_id == deme.hex_id:
				var et := entry.event_type
				var tok := ""
				if et == "raid":
					tok = "raided@G%d" % entry.generation
				elif et in ["war", "betrayal", "pact", "fortify", "merge", "tribute", "siege"]:
					tok = "%s@G%d" % [et, entry.generation]
				if tok != "" and not mem_tokens.has(tok):
					mem_tokens.append(tok)
			idx -= 1
	if active_vendettas > 0:
		mem_tokens.append("vendettas=%d" % active_vendettas)
	if nearby_horde_threat:
		mem_tokens.append("horde_nearby")
	var memory_digest := "; ".join(mem_tokens) if not mem_tokens.is_empty() else "quiet"

	var adequacy := (cell.current_resources if cell != null else 300.0) / maxf(1.0, float(cell_pop) * 0.85)

	var res := {
		"has_intra_rival": has_intra_rival,
		"has_adjacent_rival": has_adjacent_rival,
		"has_nearby_deme": has_nearby_deme,
		"neighbor_has_surplus": neighbor_has_surplus,
		"neighbor_is_weaker": neighbor_is_weaker,
		"has_active_pact": has_active_pact,
		"active_pacts": active_pact_count,
		"active_vendettas": active_vendettas,
		"adjacent_rivals": adjacent_rivals_count,
		"nearby_horde_threat": nearby_horde_threat,
		"memory_digest": memory_digest,
		"neighbor_max_reserves": max_neighbor_reserves,
		"env_adequacy": adequacy,
		"cell_pop": cell_pop
	}
	if deme != null:
		deme.set_meta("geo_ctx_key", cache_key)
		deme.set_meta("geo_ctx_val", res)
	return res


static func compute_environmental_decision_weights(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var traits_cat := state.traits_catalog if state != null else {}
	var decs_cat := state.decisions_catalog if (state != null and not state.decisions_catalog.is_empty()) else EvoCatalog.create_base_decisions_catalog()
	var b_count := deme.biological_trait_ids.size()
	var c_count := deme.cultural_trait_ids.size()
	var base_w_key := "%d|%d|%s|%s" % [
		b_count,
		c_count,
		deme.biological_trait_ids[0] if b_count > 0 else "",
		deme.cultural_trait_ids[c_count - 1] if c_count > 0 else ""
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
	var geo := inspect_geopolitical_context(deme, cell, state) if (cell != null and state != null) else {}
	var eligible_ids: Array[String] = base_eligible
	if state != null and base_eligible.size() > 1 and not bool(geo.get("has_intra_rival", true)) and not bool(geo.get("has_adjacent_rival", true)):
		var filtered: Array[String] = []
		for dec_id in base_eligible:
			if dec_id != "dec-territorial-dispute":
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

	var has_adjacent_rival := bool(geo["has_adjacent_rival"])
	var neighbor_has_surplus := bool(geo["neighbor_has_surplus"])
	var neighbor_is_weaker := bool(geo["neighbor_is_weaker"])
	var has_active_pact := bool(geo["has_active_pact"])

	if adequacy >= 1.25 and deme.energy_reserves >= 55.0 and state.season == "wet_warm" and crowding < 0.85:
		if weights.has("dec-territorial-dispute"):
			weights["dec-territorial-dispute"] = float(weights["dec-territorial-dispute"]) * 0.18
		if weights.has("dec-intensive-overexploit"):
			weights["dec-intensive-overexploit"] = float(weights["dec-intensive-overexploit"]) * 0.45
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
		var has_warrior := EvoCatalog.deme_has_trait(deme, "cul-warrior-expansion")
		var is_martial := (
			has_warrior
			or EvoCatalog.deme_has_trait(deme, "cul-extraction-tools")
			or EvoCatalog.deme_has_trait(deme, "bio-r-strategy")
			or vec.extraction_efficiency > 0.3
			or vec.social_cohesion < 0.0
		)
		if is_martial:
			var opp_mult := 1.35 if (neighbor_has_surplus or neighbor_is_weaker) else 1.0
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
			or has_active_pact
		)
		if is_cooperative:
			if weights.has("dec-cooperate-store"):
				weights["dec-cooperate-store"] = float(weights["dec-cooperate-store"]) * (1.0 + env_pressure * 1.35)
			if weights.has("dec-conservative-forage"):
				weights["dec-conservative-forage"] = float(weights["dec-conservative-forage"]) * (1.0 + env_pressure * 0.90)

		var is_trade_mobile := (
			EvoCatalog.deme_has_trait(deme, "cul-interdeme-barter")
			or EvoCatalog.deme_has_trait(deme, "cul-symbolic-exchange")
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
			or EvoCatalog.deme_has_trait(deme, "cul-lithic-acheulean")
		)
		if is_cognitive and weights.has("dec-explore-innovate"):
			weights["dec-explore-innovate"] = float(weights["dec-explore-innovate"]) * (1.0 + env_pressure * 1.35)

	if bool(geo.get("nearby_horde_threat", false)) or int(geo.get("active_vendettas", 0)) > 0:
		var has_warrior_trait := EvoCatalog.deme_has_trait(deme, "cul-warrior-expansion")
		if not has_warrior_trait:
			if weights.has("dec-cooperate-store"):
				weights["dec-cooperate-store"] = float(weights["dec-cooperate-store"]) * 1.28
			if weights.has("dec-exchange-symbiosis"):
				weights["dec-exchange-symbiosis"] = float(weights["dec-exchange-symbiosis"]) * 1.18
		if has_warrior_trait or deme.defense_tier >= 2:
			if weights.has("dec-territorial-dispute"):
				weights["dec-territorial-dispute"] = float(weights["dec-territorial-dispute"]) * 1.22

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


static func modulate_deme_probabilities_for_turn(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> void:
	if deme == null or cell == null or state == null:
		return
	var env_weights := compute_environmental_decision_weights(deme, cell, state)
	deme.set_meta("env_w_key", "%d|%s|%d|%.1f" % [state.generation, cell.id, deme.population, deme.energy_reserves])
	deme.set_meta("env_w_val", env_weights)
	var eligible_ids: Array[String] = []
	for k in env_weights.keys():
		eligible_ids.append(str(k))
	if eligible_ids.is_empty():
		return

	if deme.last_decision_probabilities.size() <= 1 and float(deme.last_decision_probabilities.get("dec-conservative-forage", 0.0)) >= 0.999:
		EvoCatalog.compute_strategy_baseline_probabilities(deme, state.traits_catalog)

	var blended: Dictionary = {}
	for dec_id in eligible_ids:
		var env_w := float(env_weights.get(dec_id, 0.0))
		var cur_p := float(deme.last_decision_probabilities.get(dec_id, 0.0))
		blended[dec_id] = (0.30 * cur_p + 0.70 * env_w) if env_w > 0.0 else 0.0

	var norm := normalize_decision_probabilities(blended, eligible_ids)
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


static func _get_sorted_passable_neighbors(
	deme: EvoTypes.Deme,
	current_cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Array[Dictionary]:
	var n_cache_key := "%d|%s|%d|%d" % [
		state.generation if state != null else -1,
		current_cell.id if current_cell != null else "",
		deme.biological_trait_ids.size(),
		deme.cultural_trait_ids.size()
	]
	if deme != null and deme.has_meta("pass_n_key") and str(deme.get_meta("pass_n_key")) == n_cache_key:
		return deme.get_meta("pass_n_val") as Array[Dictionary]

	var mob_t_key := "%d|%d|%d" % [deme.biological_trait_ids.size(), deme.cultural_trait_ids.size(), state.decisions_catalog.size()]
	var effective_mig_mobility: float
	if deme != null and deme.has_meta("eff_mig_mob_key") and str(deme.get_meta("eff_mig_mob_key")) == mob_t_key:
		effective_mig_mobility = float(deme.get_meta("eff_mig_mob_val"))
	else:
		var base_mobility := compute_baseline_mobility(deme, state)
		var max_migrate_mob: float = 0.0
		for dec_id in state.decisions_catalog.keys():
			var dec: EvoTypes.DecisionDef = state.decisions_catalog[dec_id]
			if dec.archetype == "migrate" and is_decision_eligible(deme, dec, state.traits_catalog):
				max_migrate_mob = maxf(max_migrate_mob, dec.vector.spatial_mobility)
		effective_mig_mobility = minf(1.5, base_mobility + max_migrate_mob)
		if deme != null:
			deme.set_meta("eff_mig_mob_key", mob_t_key)
			deme.set_meta("eff_mig_mob_val", effective_mig_mobility)
	var cell_n_key := "%d|%.2f" % [state.generation if state != null else -1, effective_mig_mobility]
	if current_cell != null and current_cell.has_meta("cell_pass_n_key") and str(current_cell.get_meta("cell_pass_n_key")) == cell_n_key:
		var cached_pass := current_cell.get_meta("cell_pass_n_val") as Array[Dictionary]
		if deme != null:
			deme.set_meta("pass_n_key", n_cache_key)
			deme.set_meta("pass_n_val", cached_pass)
		return cached_pass

	var passable: Array[Dictionary] = []
	for nid in HexMath.get_neighbor_ids(current_cell.q, current_cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		var is_passable := ncell.biome != "ocean" and ncell.altitude <= 0.85 and (ncell.altitude - 0.50) <= effective_mig_mobility
		if not is_passable or ncell.deme_ids.size() >= 3:
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
			"total_population": total_pop,
			"score": ncell.current_resources / maxf(10.0, float(total_pop))
		})

	for i in range(1, passable.size()):
		var key_item: Dictionary = passable[i]
		var key_score: float = float(key_item["score"])
		var j: int = i - 1
		while j >= 0 and float(passable[j]["score"]) < key_score:
			passable[j + 1] = passable[j]
			j -= 1
		passable[j + 1] = key_item

	if passable.size() > 3:
		var top3 := passable.slice(0, 3)
		var has_occupied := false
		for item in top3:
			if int(item["demes_count"]) > 0:
				has_occupied = true
				break
		if not has_occupied:
			for i in range(3, passable.size()):
				if int(passable[i]["demes_count"]) > 0:
					top3[2] = passable[i]
					if current_cell != null:
						current_cell.set_meta("cell_pass_n_key", cell_n_key)
						current_cell.set_meta("cell_pass_n_val", top3)
					if deme != null:
						deme.set_meta("pass_n_key", n_cache_key)
						deme.set_meta("pass_n_val", top3)
					return top3
	if current_cell != null:
		current_cell.set_meta("cell_pass_n_key", cell_n_key)
		current_cell.set_meta("cell_pass_n_val", passable)
	if deme != null:
		deme.set_meta("pass_n_key", n_cache_key)
		deme.set_meta("pass_n_val", passable)
	return passable


static func _get_primary_cell_occupant(cell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	if cell == null or state == null or cell.deme_ids.is_empty():
		return null
	var best: EvoTypes.Deme = null
	for oid in cell.deme_ids:
		if state.demes.has(oid):
			var d: EvoTypes.Deme = state.demes[oid]
			if best == null or d.population > best.population:
				best = d
	return best


static func _format_neighbor_occupant_label(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> String:
	if other == null:
		return "empty"
	var rel_tag := "rival"
	if other.lineage_id == deme.lineage_id:
		rel_tag = "kin"
	elif EvoTypes.is_pact_active(state, deme.id, other.id):
		rel_tag = "ally"
	elif EvoTypes.is_vendetta_active(state, deme.id, other.id):
		rel_tag = "vendetta"

	var dom_arch := "forage"
	if state.decisions_catalog.has(other.last_dominant_decision_id):
		dom_arch = (state.decisions_catalog[other.last_dominant_decision_id] as EvoTypes.DecisionDef).archetype
	var posture_tag := "martial" if (other.cultural_trait_ids.has("cul-warrior-expansion") or dom_arch == "dispute") else dom_arch

	var strength_tag := "equal"
	if float(other.population) > float(deme.population) * 1.2:
		strength_tag = "stronger"
	elif float(other.population) < float(deme.population) * 0.8:
		strength_tag = "weaker"

	return "%s:%s:%s:def%d" % [rel_tag, posture_tag, strength_tag, other.defense_tier]


static func _format_neighbor_sig_tag(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> String:
	if other == null:
		return "empty"
	if other.lineage_id == deme.lineage_id:
		return "kin"
	if EvoTypes.is_pact_active(state, deme.id, other.id):
		return "ally"
	if EvoTypes.is_vendetta_active(state, deme.id, other.id):
		return "vendetta"
	var dom_arch := "forage"
	if state.decisions_catalog.has(other.last_dominant_decision_id):
		dom_arch = (state.decisions_catalog[other.last_dominant_decision_id] as EvoTypes.DecisionDef).archetype
	if other.cultural_trait_ids.has("cul-warrior-expansion") or dom_arch == "dispute":
		return "rival_martial"
	return "rival"


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


static func build_geopolitics_summary(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var geo := inspect_geopolitical_context(deme, cell, state)
	return {
		"active_pacts": int(geo["active_pacts"]),
		"active_vendettas": int(geo.get("active_vendettas", 0)),
		"adjacent_rivals": int(geo["adjacent_rivals"]),
		"defense_tier": deme.defense_tier,
		"merged_count": deme.merged_count,
		"horde_threat": bool(geo.get("nearby_horde_threat", false)),
		"memory": str(geo.get("memory_digest", "quiet")),
		"neighbor_max_reserves": snappedf(float(geo["neighbor_max_reserves"]), 0.1),
		"env_adequacy": snappedf(float(geo["env_adequacy"]), 0.01)
	}


static func build_compact_system_one_state(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	precomputed_top_prior: Dictionary = {},
	precomputed_geo_summary: Dictionary = {}
) -> String:
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
	var line2 := "Deme \"%s\": pop=%d (%s), reserves=%d, delta=%s, def=Lv%d, merged=%d | CellCompetition: totalPop=%d, cohabiting=%d (rivals=%d, kin=%d)" % [
		deme.name,
		deme.population,
		vitality,
		int(roundf(deme.energy_reserves)),
		delta_str,
		deme.defense_tier,
		deme.merged_count,
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
		var nid := str(n["id"])
		var n_biome := str(n["biome"])
		var n_count := int(n["demes_count"])
		var occ_label := "empty"
		if n_count > 0 and state.cells.has(nid):
			var primary_occ := _get_primary_cell_occupant(state.cells[nid], state)
			occ_label = _format_neighbor_occupant_label(deme, primary_occ, state)
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
	var top_prior := precomputed_top_prior if not precomputed_top_prior.is_empty() else build_top_strategy_prior(deme, current_cell, state)
	var geo_summary := precomputed_geo_summary if not precomputed_geo_summary.is_empty() else build_geopolitics_summary(deme, current_cell, state)
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
	var model_key := deme.decision_model_tag if deme.decision_model_tag != "" else resolve_deme_decision_model_tag(deme.id)
	if not state.cells.has(deme.hex_id):
		return "%s|%s|missing" % [model_key, state.season]

	var current_cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var pacts_hash: int = state.active_pacts.hash() if not state.active_pacts.is_empty() else 0
	var sig_cache_key := "%d|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		state.generation,
		model_key,
		deme.hex_id,
		deme.population,
		int(deme.energy_reserves),
		deme.defense_tier,
		deme.merged_count,
		state.demes.size(),
		state.chronicle.size(),
		current_cell.deme_ids.size(),
		int(current_cell.current_resources),
		pacts_hash,
		deme.biological_trait_ids.size() + deme.cultural_trait_ids.size()
	]
	if deme.has_meta("sig_cache_key") and str(deme.get_meta("sig_cache_key")) == sig_cache_key:
		return str(deme.get_meta("sig_cache_val"))
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
	var adequacy_bucket: int = 0 if resource_adequacy_ratio < 0.85 else (1 if resource_adequacy_ratio <= 1.35 else 2)
	var health_ratio := current_cell.carrying_capacity / maxf(1.0, current_cell.carrying_capacity_max)
	var health_bucket: int = 0 if health_ratio < 0.35 else (1 if health_ratio <= 0.80 else 2)
	var vitality := _compute_vitality_status(deme.energy_reserves, deme.last_energy_delta, resource_adequacy_ratio)
	var geo := inspect_geopolitical_context(deme, current_cell, state)
	var pact_count := int(geo["active_pacts"])
	var vendetta_flag := 1 if int(geo.get("active_vendettas", 0)) > 0 else 0
	var horde_flag := 1 if bool(geo.get("nearby_horde_threat", false)) else 0
	var surplus_flag := 1 if (bool(geo["neighbor_has_surplus"]) or bool(geo["neighbor_is_weaker"])) else 0
	var competition_key := "%d:%d:%s:%d:p%d:v%d:h%d:d%d:s%d" % [
		rival_count,
		kin_count,
		"viable" if deme.population >= 40 else "small",
		1 if (bool(geo["has_intra_rival"]) or bool(geo["has_adjacent_rival"])) else 0,
		pact_count,
		vendetta_flag,
		horde_flag,
		deme.defense_tier,
		surplus_flag
	]

	var traits_cache_key := "%d|%d" % [deme.biological_trait_ids.size(), deme.cultural_trait_ids.size()]
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

	var passable_neighbors := _get_sorted_passable_neighbors(deme, current_cell, state).slice(0, 3)
	var n_keys: Array[String] = []
	for n in passable_neighbors:
		var nid := str(n["id"])
		var n_count := int(n["demes_count"])
		var n_rel_tag := "empty"
		if n_count > 0 and state.cells.has(nid):
			var primary_occ := _get_primary_cell_occupant(state.cells[nid], state)
			n_rel_tag = _format_neighbor_sig_tag(deme, primary_occ, state)
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


static func invalidate_state_caches(state: EvoTypes.WorldState) -> void:
	if state == null:
		return
	if state.has_meta("dec_cat_hash"):
		state.remove_meta("dec_cat_hash")
	if state.has_meta("dec_cat_size"):
		state.remove_meta("dec_cat_size")
	if state.has_meta("pact_counts_key"):
		state.remove_meta("pact_counts_key")
	if state.has_meta("pact_counts_val"):
		state.remove_meta("pact_counts_val")
	if state.has_meta("vendetta_counts_val"):
		state.remove_meta("vendetta_counts_val")
	if state.has_meta("world_horde_key"):
		state.remove_meta("world_horde_key")
	if state.has_meta("world_horde_val"):
		state.remove_meta("world_horde_val")
	for tid in state.traits_catalog.keys():
		var t: EvoTypes.TraitDef = state.traits_catalog[tid]
		if t.has_meta("compact_str"):
			t.remove_meta("compact_str")
	for did in state.decisions_catalog.keys():
		var d: EvoTypes.DecisionDef = state.decisions_catalog[did]
		if d.has_meta("compact_criterion"):
			d.remove_meta("compact_criterion")
	for deme_id in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[deme_id]
		for k in ["geo_ctx_key", "pass_n_key", "env_w_key", "traits_sig_key", "base_w_key", "eff_mig_mob_key", "sig_cache_key"]:
			if deme.has_meta(k):
				deme.remove_meta(k)
	for cid in state.cells.keys():
		var c: EvoTypes.HexCell = state.cells[cid]
		if c.has_meta("cell_pass_n_key"):
			c.remove_meta("cell_pass_n_key")


static func build_deme_evaluation_signature(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	return compute_deme_evaluation_signature(deme, state)


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
	var model_tag := deme.decision_model_tag if deme.decision_model_tag != "" else resolve_deme_decision_model_tag(deme.id)
	var dec_name := dominant_id
	if state != null and state.decisions_catalog.has(dominant_id):
		dec_name = EvoI18n.decision_name(lang, state.decisions_catalog[dominant_id])
	var pct_str := "%.1f%%" % (dominant_prob * 100.0)
	var ctx_parts: Array[String] = []
	if deme != null and cell != null and state != null:
		var geo := inspect_geopolitical_context(deme, cell, state)
		if bool(geo.get("nearby_horde_threat", false)):
			ctx_parts.append("nearby horde threat" if is_en else "amenaza de horda cercana")
		if int(geo.get("active_vendettas", 0)) > 0:
			ctx_parts.append("active vendetta (%d)" % int(geo["active_vendettas"]) if is_en else "vendetta activa (%d)" % int(geo["active_vendettas"]))
		if int(geo.get("active_pacts", 0)) > 0:
			ctx_parts.append("allied pacts=%d" % int(geo["active_pacts"]) if is_en else "pactos aliados=%d" % int(geo["active_pacts"]))
		if deme.defense_tier > 0:
			ctx_parts.append("defense Lv.%d" % deme.defense_tier if is_en else "defensa Nv.%d" % deme.defense_tier)
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
