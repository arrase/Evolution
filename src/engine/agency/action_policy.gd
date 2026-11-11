class_name EvoActionPolicy
extends RefCounted

const TEMPERATURE := 0.45

const TRAIT_DIRECTIVES: Dictionary = {
	"bio-r-strategy": "Proliferate and disperse early: colonize open frontier hexes and land bridges as soon as population and food allow.",
	"bio-k-strategy": "Build enduring Tier III-IV fortified cities with strong food buffers and sanitation first, then found well-supplied daughter colonies once population exceeds 160 so your cities never overcrowd into famine and allied Tier II+ cities can unite.",
	"bio-encephalization": "Leverage high cognition: prioritize innovating early to unlock permanent cultural traditions, diffuse knowledge through trade, and sustain steady surpluses for neural upkeep and expansion.",
	"bio-social-instinct": "Maintain tight solidarity with kin and sworn allies in shared defense and collective action.",
	"bio-thermal-tolerance": "Exploit harsh climates and mountain or coastal corridors where rivals falter.",
	"bio-digestive-spec": "Sustain steady caloric surpluses across diverse biomes through reliable foraging and cultivation.",
	"cul-communal-conservation": "Protect carrying capacity above 80% (avoid overexploitation unless starving), favor alliances, mutual aid, and multi-hex walled city unions over destructive raids.",
	"cul-interdeme-barter": "Prioritize profitable trade networks, pacts, commercial reputation, and multi-hex walled city unions with trusted partners so partners reciprocate.",
	"cul-warrior-expansion": "Prioritize martial dominance over foreign rivals: whenever `demand_tribute`, `raid`, or `conquer` against a foreign settlement has >= 40% win chance, choose martial action over passive foraging, scholarly innovation, or foreign pacts.",
	"cul-extraction-tools": "Use specialized toolkits for high harvest yields while offsetting habitat wear through expansion, trade, or rotation.",
	"cul-fire-processing": "Channel caloric surpluses from thermal food processing into steady demographic and civic investments."
}


static func _emergent_directive(tdef: EvoTypes.TraitDef) -> String:
	var v := tdef.vector
	if v.ecological_impact >= 0.20:
		return "Uphold %s by stewarding habitat capacity and cooperative stability." % tdef.name
	if v.spatial_mobility >= 0.25:
		return "Apply %s to extend reach across corridors, trade routes, or border campaigns." % tdef.name
	if v.social_cohesion >= 0.22:
		return "Apply %s to strengthen collective defense, alliances, and civic unity." % tdef.name
	if v.extraction_efficiency >= 0.22:
		return "Apply %s to maximize sustainable food surpluses." % tdef.name
	return ""


static func _biophysical_profile(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var v := EvoPayoffs.vector(deme, state)
	var rk := "r-strategy" if deme.biological_trait_ids.has("bio-r-strategy") else ("K-strategy" if deme.biological_trait_ids.has("bio-k-strategy") else "balanced r/K")
	return "Biophysical profile (%s): social_cohesion %+.2f, spatial_mobility %+.2f, innovation_rate +%.2f, ecological_impact %+.2f, transmission_threshold %.2f." % [
		rk, v.social_cohesion, v.spatial_mobility, EvoPayoffs.innovation_step(deme, state), v.ecological_impact, v.transmission_threshold
	]


static func build_instructions(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var strategy: EvoTypes.StrategyDef = state.strategies_catalog[deme.strategy_id]
	var doctrine := EvoSituationReport.doctrine_of(deme, state)
	var desc := EvoI18n.strategy_description("en", strategy)
	var parts: Array[String] = [doctrine]
	if desc != "" and desc != doctrine:
		parts.append(desc)
	parts.append(_biophysical_profile(deme, state))
	for tid in deme.biological_trait_ids + deme.cultural_trait_ids:
		if TRAIT_DIRECTIVES.has(tid):
			parts.append(str(TRAIT_DIRECTIVES[tid]))
		elif state.traits_catalog.has(tid):
			var em := _emergent_directive(state.traits_catalog[tid])
			if em != "":
				parts.append(em)
	parts.append("Choose the single action this turn that best fulfills your population's ethos and long-term survival over the next 10 turns, accounting for food thresholds, habitat health, memory, and neighbor reactions.")
	return " ".join(parts)


static func build_posture_instructions(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var parts: Array[String] = [EvoSituationReport.doctrine_of(deme, state)]
	parts.append("Choose `open_harvest` for full 100% food yield whenever 0 raiders are in range; switch to `patrol_fields` when unallied rivals threaten your settlement or cultivated fields, or `mobilized_garrison` during active feuds and heavy raid danger.")
	return " ".join(parts)


static func prepare_deme_menu(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	var hops_map := EvoActionMenu.settle_corridor_hops(deme, state)
	var s_targets := EvoActionMenu.settle_targets_with_hops(deme, state, hops_map)
	var neighbors := EvoActionMenu.neighbor_demes(deme, state)
	var rivals := EvoActionMenu.border_field_rivals(deme, state)
	var raiders := EvoActionMenu.field_raiders(deme, state)
	var raid_cache: Dictionary = {}
	var menu := EvoActionMenu.build_with_targets(deme, state, s_targets, neighbors, rivals, raid_cache)
	var forecasts := EvoOutcomeForecast.describe_menu(deme, menu, state, hops_map, raid_cache)
	var probs: Dictionary = {}
	var uniform_p := snappedf(1.0 / float(maxi(1, menu.size())), 0.0001)
	for opt in menu:
		probs[str(opt["key"])] = uniform_p
	deme.action_forecasts = forecasts
	deme.action_probabilities = probs
	deme.chosen_action = menu[0]

	if not EvoTypes.DEFENSE_POSTURES.has(deme.defense_posture):
		deme.defense_posture = "open_harvest"
	var threats := EvoActionMenu.threat_counts_from(deme, neighbors, raiders, state)
	var posture_criteria := EvoOutcomeForecast.describe_postures_with_threats(deme, state, threats)
	var posture_probs: Dictionary = {}
	var uniform_posture := snappedf(1.0 / float(EvoTypes.DEFENSE_POSTURES.size()), 0.0001)
	for p in EvoTypes.DEFENSE_POSTURES:
		posture_probs[p] = uniform_posture
	deme.posture_forecasts = posture_criteria
	deme.posture_probabilities = posture_probs
	deme.pending_raw_eval = {}

	return {
		"deme_id": deme.id,
		"preferred_tag": deme.decision_model_tag,
		"briefing": EvoSituationReport.build_with_corridors(deme, state, hops_map, s_targets, neighbors, rivals, raiders),
		"posture_instructions": build_posture_instructions(deme, state),
		"posture_criteria": posture_criteria.duplicate(),
		"instructions": build_instructions(deme, state),
		"criteria": forecasts.duplicate()
	}


static func _sharpen_and_normalize(probabilities: Dictionary, keys: Array) -> Dictionary:
	var sharpened: Dictionary = {}
	var total := 0.0
	for k in keys:
		var raw_p := maxf(0.0, float(probabilities[k])) if probabilities.has(k) else 0.0
		var w := pow(raw_p, 1.0 / TEMPERATURE) if raw_p > 0.0 else 0.0
		sharpened[k] = w
		total += w

	var norm: Dictionary = {}
	if total <= 0.0:
		var u := snappedf(1.0 / float(maxi(1, keys.size())), 0.0001)
		for k in keys:
			norm[k] = u
	else:
		for k in keys:
			norm[k] = snappedf(float(sharpened[k]) / total, 0.0001)
	return norm


static func _argmax_key(probs: Dictionary, keys: Array) -> String:
	var best_key := str(keys[0])
	var best_p := -1.0
	for k in keys:
		var p := float(probs[k]) if probs.has(k) else 0.0
		if p > best_p:
			best_p = p
			best_key = str(k)
	return best_key


static func _sample_key(probs: Dictionary, keys: Array, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	var accum := 0.0
	var chosen := str(keys[0])
	for k in keys:
		accum += float(probs[k]) if probs.has(k) else 0.0
		if roll <= accum:
			chosen = str(k)
			break
	return chosen


static func apply_live_result(deme: EvoTypes.Deme, entry: Dictionary) -> void:
	var action_keys := deme.action_forecasts.keys()
	if not action_keys.is_empty() and entry.has("probabilities"):
		deme.action_probabilities = _sharpen_and_normalize(entry["probabilities"], action_keys)
		deme.chosen_action = EvoActionMenu.parse_key(_argmax_key(deme.action_probabilities, action_keys))

	if entry.has("posture_probabilities"):
		deme.posture_probabilities = _sharpen_and_normalize(entry["posture_probabilities"], EvoTypes.DEFENSE_POSTURES)
		deme.defense_posture = _argmax_key(deme.posture_probabilities, EvoTypes.DEFENSE_POSTURES)

	if entry.has("confidence"):
		deme.last_confidence = float(entry["confidence"])
	deme.pending_raw_eval = entry.duplicate(true)


static func sample_turn_decisions(deme: EvoTypes.Deme, rng: RandomNumberGenerator) -> void:
	if not deme.posture_probabilities.is_empty():
		deme.defense_posture = _sample_key(deme.posture_probabilities, EvoTypes.DEFENSE_POSTURES, rng)
	var action_keys := deme.action_forecasts.keys()
	if not action_keys.is_empty() and not deme.action_probabilities.is_empty():
		var chosen_key := _sample_key(deme.action_probabilities, action_keys, rng)
		deme.chosen_action = EvoActionMenu.parse_key(chosen_key)


static func sample_action(
	deme: EvoTypes.Deme,
	probabilities: Dictionary,
	confidence: float,
	rng: RandomNumberGenerator
) -> void:
	var keys := deme.action_forecasts.keys()
	if keys.is_empty():
		return
	var norm := _sharpen_and_normalize(probabilities, keys)
	deme.action_probabilities = norm
	deme.last_confidence = confidence
	deme.chosen_action = EvoActionMenu.parse_key(_sample_key(norm, keys, rng))
