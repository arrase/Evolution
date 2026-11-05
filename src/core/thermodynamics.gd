class_name EvoThermodynamics
extends RefCounted

const BASE_BUDGET: float = 0.60


static func round4(value: float) -> float:
	return snappedf(value, 0.0001)


static func clamp_vector(vector: EvoTypes.BiophysicalVector) -> EvoTypes.BiophysicalVector:
	return EvoTypes.BiophysicalVector.new(
		round4(clampf(vector.metabolic_cost, -1.0, 1.0)),
		round4(clampf(vector.extraction_efficiency, -1.0, 1.0)),
		round4(clampf(vector.ecological_impact, -1.0, 1.0)),
		round4(clampf(vector.spatial_mobility, -1.0, 1.0)),
		round4(clampf(vector.social_cohesion, -1.0, 1.0)),
		round4(clampf(vector.transmission_threshold, 0.0, 1.0))
	)


static func evaluate_thermodynamics(vector: EvoTypes.BiophysicalVector) -> Dictionary:
	var clamped := clamp_vector(vector)
	var positive_advantages := round4(
		maxf(0.0, clamped.extraction_efficiency)
		+ maxf(0.0, clamped.spatial_mobility)
		+ maxf(0.0, clamped.social_cohesion)
	)
	var current_cost := round4(clamped.metabolic_cost - minf(0.0, clamped.ecological_impact))
	var required_cost := round4(0.5 * (positive_advantages - BASE_BUDGET)) if positive_advantages > BASE_BUDGET else 0.0
	var is_balanced := positive_advantages <= BASE_BUDGET or current_cost >= required_cost - 0.000001

	return {
		"positive_advantages": positive_advantages,
		"current_cost": current_cost,
		"required_cost": required_cost,
		"is_balanced": is_balanced
	}


static func validate_and_balance_thermodynamics(
	vector: EvoTypes.BiophysicalVector,
	free_sandbox_mode: bool = false
) -> EvoTypes.BiophysicalVector:
	var clamped := clamp_vector(vector)
	var metrics := evaluate_thermodynamics(clamped)

	if free_sandbox_mode or bool(metrics["is_balanced"]):
		return clamped

	var required_cost := float(metrics["required_cost"])
	var target_metabolic := required_cost + minf(0.0, clamped.ecological_impact)
	var adjusted_metabolic := minf(1.0, round4(target_metabolic))
	var adjusted_eco := clamped.ecological_impact

	if target_metabolic > 1.0:
		var excess := target_metabolic - 1.0
		var base_eco := minf(0.0, clamped.ecological_impact)
		adjusted_eco = maxf(-1.0, round4(base_eco - excess))

	clamped.metabolic_cost = adjusted_metabolic
	clamped.ecological_impact = adjusted_eco
	return clamped
