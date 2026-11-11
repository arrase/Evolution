class_name EvoTurnEngine
extends RefCounted

const COST_SET_BIOME: int = 10
const COST_ADJUST_ALTITUDE: int = 15
const COST_ADJUST_CAPACITY: int = 10
const COST_ADJUST_SEA_LEVEL: int = 25


static func advance_generation(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	var prev_chronicle_count := state.chronicle.size()

	EvoDecisionModel.apply_completed_live_results(state, lang, -1)
	EvoDecisionModel.finalize_turn_decisions(state)
	EvoEnvPhase.run_environmental_phase(state, lang)
	EvoBiophysPhase.run_biophysical_phase(state, lang)
	EvoMilestonePhase.run_milestone_phase(state, lang)
	EvoTypes.record_turn_stats(state)
	EvoDecisionModel.evaluate_all_demes(state, lang, true)

	var new_entries: Array[EvoTypes.ChronicleEntry] = []
	var has_milestone := false
	var has_macro_outcome := false
	var milestone_entry: EvoTypes.ChronicleEntry = null
	var outcome_entry: EvoTypes.ChronicleEntry = null

	for i in range(prev_chronicle_count, state.chronicle.size()):
		var entry := state.chronicle[i]
		new_entries.append(entry)
		if entry.event_type in ["baldwin_trait", "cultural_innovation", "allopatric_speciation"]:
			has_milestone = true
			milestone_entry = entry
		elif entry.event_type in ["total_extinction", "single_survivor", "ecological_equilibrium"]:
			has_macro_outcome = true
			outcome_entry = entry

	return {
		"generation": state.generation,
		"new_entries": new_entries,
		"has_milestone": has_milestone,
		"has_macro_outcome": has_macro_outcome,
		"milestone_entry": milestone_entry,
		"outcome_entry": outcome_entry
	}


static func _can_afford(state: EvoTypes.WorldState, cost: int) -> bool:
	return state.unlimited_pressure_mode or state.selective_pressure_points >= cost


static func _spend_points(state: EvoTypes.WorldState, cost: int) -> void:
	if not state.unlimited_pressure_mode:
		state.selective_pressure_points -= cost


static func _revalidate_walled_unions(state: EvoTypes.WorldState) -> void:
	EvoSettlementPhase.revalidate_walled_unions(state)


static func _apply_biome_climate_defaults(cell: EvoTypes.HexCell, biome_id: String, reset_to_healthy: bool = false) -> void:
	if not EvoTypes.BIOME_CLIMATE_DEFAULTS.has(biome_id):
		return
	var defaults: Dictionary = EvoTypes.BIOME_CLIMATE_DEFAULTS[biome_id]
	cell.biome = biome_id
	cell.temperature = float(defaults["temperature"])
	cell.humidity = float(defaults["humidity"])
	cell.seasonal_regen_rate = float(defaults["regen"])
	cell.carrying_capacity_max = float(defaults["k_max"])
	if biome_id == "ocean":
		cell.carrying_capacity_max = 50.0
		cell.carrying_capacity = 50.0
		cell.current_resources = 0.0
		cell.seasonal_regen_rate = 0.05
		cell.land_use = "wild"
		cell.owner_deme_id = ""
		cell.has_ruins = false
		cell.ruin_turns = 0
	elif reset_to_healthy:
		cell.carrying_capacity = snappedf(clampf(cell.carrying_capacity_max * 0.90, 20.0, cell.carrying_capacity_max), 0.01)
		cell.current_resources = snappedf(clampf(cell.carrying_capacity * 0.85, 10.0, cell.carrying_capacity), 0.01)
	else:
		cell.carrying_capacity = snappedf(clampf(maxf(cell.carrying_capacity, cell.carrying_capacity_max * 0.88), 20.0, cell.carrying_capacity_max), 0.01)
		cell.current_resources = snappedf(clampf(maxf(cell.current_resources, cell.carrying_capacity * 0.50), 10.0, cell.carrying_capacity), 0.01)


static func apply_set_biome(
	state: EvoTypes.WorldState,
	hex_ids: Array[String],
	target_biome: String,
	lang: String = "es"
) -> bool:
	if hex_ids.is_empty() or not EvoTypes.BIOME_CLIMATE_DEFAULTS.has(target_biome):
		return false
	if not _can_afford(state, COST_SET_BIOME):
		return false

	var defaults: Dictionary = EvoTypes.BIOME_CLIMATE_DEFAULTS[target_biome]
	var changed := false

	for hid in hex_ids:
		if not state.cells.has(hid):
			continue
		var cell: EvoTypes.HexCell = state.cells[hid]
		if cell.biome == target_biome:
			continue
		changed = true
		_apply_biome_climate_defaults(cell, target_biome, true)
		if target_biome == "ocean":
			cell.altitude = snappedf(clampf(cell.altitude, 0.0, maxf(0.0, state.sea_level - 0.02)), 0.01)
		else:
			var min_land_alt := maxf(state.sea_level + 0.02, float(defaults["min_alt"]))
			var max_land_alt := maxf(min_land_alt, float(defaults["max_alt"]))
			cell.altitude = snappedf(clampf(cell.altitude, min_land_alt, max_land_alt), 0.01)
		if cell.biome in ["ocean", "high_mountain"] or cell.altitude > 0.85:
			cell.land_use = "wild"
			cell.owner_deme_id = ""
			cell.has_ruins = false
			cell.ruin_turns = 0
		elif cell.owner_deme_id != "" and cell.land_use in ["crops", "pasture"]:
			cell.land_use = "pasture" if cell.biome in ["arid_steppe", "tundra"] else "crops"

	if not changed:
		return false
	_spend_points(state, COST_SET_BIOME)
	EvoEnvPhase.resolve_submerged_demes(state, lang)
	EvoDecisionModel.evaluate_all_demes(state, lang, true)
	return true


static func apply_adjust_altitude(
	state: EvoTypes.WorldState,
	hex_ids: Array[String],
	delta: float,
	lang: String = "es"
) -> bool:
	if hex_ids.is_empty() or not _can_afford(state, COST_ADJUST_ALTITUDE):
		return false

	var changed := false

	for hid in hex_ids:
		if not state.cells.has(hid):
			continue
		var cell: EvoTypes.HexCell = state.cells[hid]
		var prev_biome := cell.biome
		var prev_alt := cell.altitude
		var next_alt := snappedf(clampf(cell.altitude + delta, 0.0, 1.0), 0.01)
		if is_equal_approx(next_alt, prev_alt):
			continue
		changed = true
		cell.altitude = next_alt

		var next_biome := prev_biome
		if next_alt < state.sea_level:
			next_biome = "ocean"
		elif prev_biome == "ocean" and next_alt >= state.sea_level:
			if next_alt < 0.28:
				next_biome = "coastal_shallows"
			elif next_alt < 0.55:
				next_biome = "savanna"
			elif next_alt < 0.78:
				next_biome = "arid_steppe"
			else:
				next_biome = "high_mountain"
		elif next_alt >= 0.78:
			next_biome = "high_mountain"
		elif prev_biome == "coastal_shallows" and next_alt >= 0.28:
			next_biome = "savanna" if next_alt < 0.55 else ("arid_steppe" if next_alt < 0.78 else "high_mountain")
		elif delta < 0.0 and prev_biome == "high_mountain" and next_alt < 0.78:
			next_biome = "coastal_shallows" if next_alt < 0.28 else ("savanna" if next_alt < 0.55 else "arid_steppe")
		elif delta < 0.0 and next_alt >= state.sea_level and next_alt < 0.28 and prev_biome != "coastal_shallows":
			next_biome = "coastal_shallows"

		if next_biome != prev_biome or next_biome == "ocean":
			_apply_biome_climate_defaults(cell, next_biome, prev_biome == "ocean")
		if cell.biome in ["ocean", "high_mountain"] or cell.altitude > 0.85:
			cell.land_use = "wild"
			cell.owner_deme_id = ""
			cell.has_ruins = false
			cell.ruin_turns = 0
		elif cell.owner_deme_id != "" and cell.land_use in ["crops", "pasture"]:
			cell.land_use = "pasture" if cell.biome in ["arid_steppe", "tundra"] else "crops"

	if not changed:
		return false
	_spend_points(state, COST_ADJUST_ALTITUDE)
	EvoEnvPhase.resolve_submerged_demes(state, lang)
	EvoDecisionModel.evaluate_all_demes(state, lang, true)
	return true


static func apply_adjust_carrying_capacity(
	state: EvoTypes.WorldState,
	hex_ids: Array[String],
	factor_delta: float,
	lang: String = "es"
) -> bool:
	if hex_ids.is_empty() or not _can_afford(state, COST_ADJUST_CAPACITY):
		return false

	var factor := 1.0 + factor_delta
	var changed := false

	for hid in hex_ids:
		if not state.cells.has(hid):
			continue
		var cell: EvoTypes.HexCell = state.cells[hid]
		if cell.biome == "ocean":
			continue
		var prev_k := cell.carrying_capacity
		var prev_r := cell.current_resources
		var next_k := snappedf(clampf(prev_k * factor, 10.0, cell.carrying_capacity_max), 0.01)
		var next_r := prev_r
		if factor_delta > 0.0:
			var added_res := maxf(
				cell.current_resources * factor,
				cell.current_resources + prev_k * factor_delta
			)
			next_r = clampf(roundf(added_res), 0.0, next_k)
		else:
			next_r = snappedf(clampf(cell.current_resources * 0.78, 0.0, next_k), 0.01)
		if not is_equal_approx(next_k, prev_k) or not is_equal_approx(next_r, prev_r):
			cell.carrying_capacity = next_k
			cell.current_resources = next_r
			changed = true

	if not changed:
		return false
	_spend_points(state, COST_ADJUST_CAPACITY)
	EvoDecisionModel.evaluate_all_demes(state, lang, true)
	return true


static func apply_adjust_sea_level(
	state: EvoTypes.WorldState,
	delta: float,
	lang: String = "es"
) -> bool:
	if not _can_afford(state, COST_ADJUST_SEA_LEVEL):
		return false

	var next_sea_level := snappedf(clampf(state.sea_level + delta, 0.0, 0.50), 0.01)
	if is_equal_approx(next_sea_level, state.sea_level):
		return false
	_spend_points(state, COST_ADJUST_SEA_LEVEL)
	state.sea_level = next_sea_level

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		EvoEnvPhase.apply_cell_sea_level_transition(cell, next_sea_level)

	EvoEnvPhase.resolve_submerged_demes(state, lang)
	EvoDecisionModel.evaluate_all_demes(state, lang, true)
	return true
