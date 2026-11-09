class_name EvoActionPolicy
extends RefCounted

const INSTRUCTIONS := "You lead this settlement. Choose the action that best grows your lineage's total population and territory over the next 10 turns, weighing the expected gains, risks, and how neighbors will react."
const TEMPERATURE := 0.8


static func prepare_deme_menu(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	var menu := EvoActionMenu.build(deme, state)
	var forecasts: Dictionary = {}
	var probs: Dictionary = {}
	var uniform_p := snappedf(1.0 / float(maxi(1, menu.size())), 0.0001)
	for opt in menu:
		var key := str(opt["key"])
		forecasts[key] = EvoOutcomeForecast.describe(deme, opt, state)
		probs[key] = uniform_p
	deme.action_forecasts = forecasts
	deme.action_probabilities = probs
	deme.chosen_action = menu[0]
	return {
		"deme_id": deme.id,
		"preferred_tag": deme.decision_model_tag,
		"briefing": EvoSituationReport.build(deme, state),
		"instructions": INSTRUCTIONS,
		"criteria": forecasts.duplicate()
	}


static func sample_action(
	deme: EvoTypes.Deme,
	probabilities: Dictionary,
	confidence: float,
	rng: RandomNumberGenerator
) -> void:
	var keys: Array[String] = []
	for k in deme.action_forecasts.keys():
		keys.append(str(k))
	if keys.is_empty():
		return

	var sharpened: Dictionary = {}
	var total := 0.0
	for k in keys:
		var raw_p := maxf(0.0, float(probabilities[k])) if probabilities.has(k) else 0.0
		var w := pow(raw_p, 1.0 / TEMPERATURE) if raw_p > 0.0 else 0.0
		sharpened[k] = w
		total += w

	var norm: Dictionary = {}
	if total <= 0.0:
		var u := snappedf(1.0 / float(keys.size()), 0.0001)
		for k in keys:
			norm[k] = u
	else:
		for k in keys:
			norm[k] = snappedf(float(sharpened[k]) / total, 0.0001)

	deme.action_probabilities = norm
	deme.last_confidence = confidence

	var roll := rng.randf()
	var accum := 0.0
	var chosen_key := keys[0]
	for k in keys:
		accum += float(norm[k])
		if roll <= accum:
			chosen_key = k
			break

	deme.chosen_action = EvoActionMenu.parse_key(chosen_key)
