class_name EvoActionPolicy
extends RefCounted

const TEMPERATURE := 0.45

const TRAIT_DIRECTIVES: Dictionary = {
	"bio-r-strategy": "Your people are prolific pioneers who reproduce quickly and disperse into open frontier lands.",
	"bio-k-strategy": "Your people invest in longevity, civic endurance, fortified settlements, sanitation, and well-provisioned daughter communities.",
	"bio-encephalization": "Your people possess high cognitive curiosity, valuing steady experimentation, cultural tradition, and intellectual exchange.",
	"bio-social-instinct": "Your people feel deep solidarity with kin and trusted companions, finding strength in mutual aid and shared defense.",
	"bio-thermal-tolerance": "Your people are hardy and adaptable across extreme climates, mountain passes, and coastal crossings.",
	"bio-digestive-spec": "Your people draw reliable sustenance from varied wild flora and cultivated crops across diverse biomes.",
	"cul-communal-conservation": "Your culture holds the land in communal trust, revering ecological balance, generous stewardship, and enduring civic unions.",
	"cul-interdeme-barter": "Your culture prizes commerce, honest dealing, commercial reputation, and peaceful trade networks across neighbors.",
	"cul-warrior-expansion": "Your culture honors martial prowess, bold raiding, tribute, and territorial conquest.",
	"cul-extraction-tools": "Your culture crafts specialized tools for intensive harvesting and ambitious extraction.",
	"cul-fire-processing": "Your culture masters fire and thermal food preparation, stretching harvests into greater vitality."
}


static func _emergent_directive(tdef: EvoTypes.TraitDef) -> String:
	var v := tdef.vector
	if v.ecological_impact >= 0.20:
		return "Your tradition of %s upholds habitat stewardship and cooperative stability." % tdef.name
	if v.spatial_mobility >= 0.25:
		return "Your tradition of %s drives far-ranging movement across corridors, trade routes, and borderlands." % tdef.name
	if v.social_cohesion >= 0.22:
		return "Your tradition of %s strengthens collective defense, bonds, and civic unity." % tdef.name
	if v.extraction_efficiency >= 0.22:
		return "Your tradition of %s favors skilled harvesting and abundant sustenance." % tdef.name
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
	parts.append("Weigh your external relations, settlement expansion, and strategic outlook over the next 10 turns, and choose the external action that best reflects your people's ethos and situation.")
	return " ".join(parts)


static func build_posture_instructions(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	return "%s Choose the rural defense posture that balances harvest yield against the military security of your fields and borders." % EvoSituationReport.doctrine_of(deme, state)


static func build_domestic_instructions(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	return "%s Choose the domestic priority for your home settlement this turn—balancing steady sustenance, intensive extraction, fortification, or cultural experimentation according to your ethos and reserves." % EvoSituationReport.doctrine_of(deme, state)


static func prepare_deme_menu(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	var hops_map := EvoActionMenu.settle_corridor_hops(deme, state)
	var s_targets := EvoActionMenu.settle_targets_with_hops(deme, state, hops_map)
	var contacts := EvoActionMenu.sorted_contact_demes(deme, state)
	var raid_cache: Dictionary = {}
	var menu := EvoActionMenu.build_with_targets(deme, state, s_targets, contacts, raid_cache)
	var forecasts := EvoOutcomeForecast.describe_menu(deme, menu, state, hops_map, raid_cache)
	var probs: Dictionary = {}
	var uniform_p := snappedf(1.0 / float(maxi(1, menu.size())), 0.0001)
	for opt in menu:
		probs[str(opt["key"])] = uniform_p
	deme.action_forecasts = forecasts
	deme.action_probabilities = probs
	deme.chosen_action = menu[0]

	var dom_menu := EvoActionMenu.build_domestic(deme, state)
	var dom_criteria := EvoOutcomeForecast.describe_domestic_menu(deme, dom_menu, state)
	var dom_probs: Dictionary = {}
	var uniform_dom := snappedf(1.0 / float(maxi(1, dom_menu.size())), 0.0001)
	for dk in dom_menu:
		dom_probs[dk] = uniform_dom
	deme.domestic_forecasts = dom_criteria
	deme.domestic_probabilities = dom_probs
	deme.domestic_action = dom_menu[0]

	if not EvoTypes.DEFENSE_POSTURES.has(deme.defense_posture):
		deme.defense_posture = "open_harvest"
	var threats := EvoActionMenu.threat_counts_from(deme, contacts, state)
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
		"briefing": EvoSituationReport.build_with_corridors(deme, state, hops_map, s_targets, contacts),
		"posture_instructions": build_posture_instructions(deme, state),
		"posture_criteria": posture_criteria.duplicate(),
		"domestic_instructions": build_domestic_instructions(deme, state),
		"domestic_criteria": dom_criteria.duplicate(),
		"instructions": build_instructions(deme, state),
		"criteria": forecasts.duplicate()
	}


static func _sharpen_and_normalize(probabilities: Dictionary, keys: Array) -> Dictionary:
	if keys.is_empty():
		return {}
	var inv_temp := 1.0 / TEMPERATURE
	var cat_keys: Dictionary = {}
	var cat_sum: Dictionary = {}
	var inner_w: Dictionary = {}
	var cat_inner_total: Dictionary = {}

	for k in keys:
		var cat := str(EvoActionMenu.parse_key(str(k))["type"])
		var raw_p := maxf(0.0, float(probabilities[k])) if probabilities.has(k) else 0.0
		if not cat_keys.has(cat):
			cat_keys[cat] = []
			cat_sum[cat] = 0.0
			cat_inner_total[cat] = 0.0
		(cat_keys[cat] as Array).append(k)
		cat_sum[cat] = float(cat_sum[cat]) + raw_p
		var iw := pow(raw_p, inv_temp) if raw_p > 0.0 else 0.0
		inner_w[k] = iw
		cat_inner_total[cat] = float(cat_inner_total[cat]) + iw

	var cat_weight: Dictionary = {}
	var total_cat_weight := 0.0
	for cat in cat_sum.keys():
		var cs := float(cat_sum[cat])
		var cw := pow(cs, inv_temp) if cs > 0.0 else 0.0
		cat_weight[cat] = cw
		total_cat_weight += cw

	var norm: Dictionary = {}
	if total_cat_weight <= 0.0:
		var u := snappedf(1.0 / float(keys.size()), 0.0001)
		for k in keys:
			norm[k] = u
		return norm

	for cat in cat_keys.keys():
		var cat_share := float(cat_weight[cat]) / total_cat_weight
		var inner_total := float(cat_inner_total[cat])
		for k in (cat_keys[cat] as Array):
			var p := cat_share * (float(inner_w[k]) / inner_total) if inner_total > 0.0 else 0.0
			norm[k] = snappedf(p, 0.0001)
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
	var total := 0.0
	var last_pos := str(keys[0])
	for k in keys:
		var p := maxf(0.0, float(probs[k])) if probs.has(k) else 0.0
		if p > 0.0:
			total += p
			last_pos = str(k)
	if total <= 0.0:
		return str(keys[0])
	var roll := rng.randf() * total
	var accum := 0.0
	for k in keys:
		var p := maxf(0.0, float(probs[k])) if probs.has(k) else 0.0
		accum += p
		if p > 0.0 and roll <= accum:
			return str(k)
	return last_pos


static func apply_live_result(deme: EvoTypes.Deme, entry: Dictionary) -> void:
	var action_keys := deme.action_forecasts.keys()
	if not action_keys.is_empty() and entry.has("probabilities"):
		deme.action_probabilities = _sharpen_and_normalize(entry["probabilities"], action_keys)
		deme.chosen_action = EvoActionMenu.parse_key(_argmax_key(deme.action_probabilities, action_keys))

	var dom_keys := deme.domestic_forecasts.keys()
	if not dom_keys.is_empty() and entry.has("domestic_probabilities"):
		deme.domestic_probabilities = _sharpen_and_normalize(entry["domestic_probabilities"], dom_keys)
		deme.domestic_action = _argmax_key(deme.domestic_probabilities, dom_keys)

	if entry.has("posture_probabilities"):
		deme.posture_probabilities = _sharpen_and_normalize(entry["posture_probabilities"], EvoTypes.DEFENSE_POSTURES)
		deme.defense_posture = _argmax_key(deme.posture_probabilities, EvoTypes.DEFENSE_POSTURES)

	if entry.has("confidence"):
		deme.last_confidence = float(entry["confidence"])
	deme.pending_raw_eval = entry.duplicate(true)


static func sample_turn_decisions(deme: EvoTypes.Deme, rng: RandomNumberGenerator) -> void:
	if not deme.posture_probabilities.is_empty():
		deme.defense_posture = _sample_key(deme.posture_probabilities, EvoTypes.DEFENSE_POSTURES, rng)
	var dom_keys := deme.domestic_forecasts.keys()
	if not dom_keys.is_empty() and not deme.domestic_probabilities.is_empty():
		deme.domestic_action = _sample_key(deme.domestic_probabilities, dom_keys, rng)
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
