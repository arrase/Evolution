class_name EvoTurnEngine
extends RefCounted

const COST_SET_BIOME: int = 10
const COST_ADJUST_ALTITUDE: int = 15
const COST_ADJUST_CAPACITY: int = 10
const COST_ADJUST_SEA_LEVEL: int = 25


static func _collect_chronicle_summary(
	state: EvoTypes.WorldState,
	start_idx: int,
	phase_num: int,
	phase_id: String
) -> Dictionary:
	var new_entries: Array[EvoTypes.ChronicleEntry] = []
	var has_milestone := false
	var has_macro_outcome := false
	var milestone_entry: EvoTypes.ChronicleEntry = null
	var outcome_entry: EvoTypes.ChronicleEntry = null

	for i in range(maxi(0, start_idx), state.chronicle.size()):
		var entry := state.chronicle[i]
		new_entries.append(entry)
		if entry.event_type in ["baldwin_trait", "cultural_innovation", "allopatric_speciation"]:
			has_milestone = true
			milestone_entry = entry
		elif entry.event_type in ["total_extinction", "single_survivor", "ecological_equilibrium"]:
			has_macro_outcome = true
			outcome_entry = entry

	return {
		"phase": phase_num,
		"phase_id": phase_id,
		"generation": state.generation,
		"new_entries": new_entries,
		"has_milestone": has_milestone,
		"has_macro_outcome": has_macro_outcome,
		"milestone_entry": milestone_entry,
		"outcome_entry": outcome_entry
	}


static func step_phase_1_environment(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	var start_idx := state.chronicle.size()
	state.set_meta("_turn_start_chronicle_count", start_idx)
	state.set_meta("_in_flight_micro_phase", 1)
	EvoEnvPhase.run_environmental_phase(state, lang)
	EvoDecisionModel.invalidate_state_caches(state)
	EvoDecisionModel.prefetch_for_state(state, true)
	return _collect_chronicle_summary(state, start_idx, 1, "environment")


static func step_phase_2_decisions(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	var start_idx := state.chronicle.size()
	state.set_meta("_in_flight_micro_phase", 2)
	EvoDecisionModel.evaluate_all_demes(state, lang, false)
	return _collect_chronicle_summary(state, start_idx, 2, "decisions")


static func step_phase_3_ecology_borders(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	var start_idx := state.chronicle.size()
	state.set_meta("_in_flight_micro_phase", 3)
	EvoBiophysPhase.run_ecology_and_borders_step(state, lang)
	return _collect_chronicle_summary(state, start_idx, 3, "ecology_borders")


static func step_phase_4_demography_milestones(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	if state.has_meta("_in_flight_micro_phase"):
		state.remove_meta("_in_flight_micro_phase")
	var turn_start_idx := state.chronicle.size()
	if state.has_meta("_turn_start_chronicle_count"):
		turn_start_idx = int(state.get_meta("_turn_start_chronicle_count"))
		state.remove_meta("_turn_start_chronicle_count")
	EvoBiophysPhase.run_demography_and_migration_step(state, lang)
	EvoMilestonePhase.run_milestone_phase(state, lang)
	var summary := _collect_chronicle_summary(state, turn_start_idx, 4, "demography_milestones")
	EvoDecisionModel.invalidate_state_caches(state)
	var cur_season := state.season
	state.season = "dry_cold" if cur_season == "wet_warm" else "wet_warm"
	EvoDecisionModel.prefetch_for_state(state, false)
	state.season = cur_season
	EvoDecisionModel.invalidate_state_caches(state)
	return summary


static func complete_in_flight_turn(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	var phase := int(state.get_meta("_in_flight_micro_phase", 0)) if state.has_meta("_in_flight_micro_phase") else 0
	if phase == 0:
		if state.has_meta("_step3_ctx"):
			phase = 3
		elif state.has_meta("_turn_start_chronicle_count"):
			phase = 1
	if phase not in [1, 2, 3]:
		return {}
	if phase < 2:
		step_phase_2_decisions(state, lang)
	if phase < 3:
		step_phase_3_ecology_borders(state, lang)
	return step_phase_4_demography_milestones(state, lang)


static func flush_pending_micro_phases(state: EvoTypes.WorldState, active_phase: int = 0, lang: String = "es") -> void:
	if not state.has_meta("_in_flight_micro_phase") and active_phase in [1, 2, 3] and (state.has_meta("_turn_start_chronicle_count") or state.has_meta("_step3_ctx")):
		state.set_meta("_in_flight_micro_phase", active_phase)
	complete_in_flight_turn(state, lang)


static func advance_generation(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	step_phase_1_environment(state, lang)
	step_phase_2_decisions(state, lang)
	step_phase_3_ecology_borders(state, lang)
	return step_phase_4_demography_milestones(state, lang)


static func _can_afford(state: EvoTypes.WorldState, cost: int) -> bool:
	return state.unlimited_pressure_mode or state.selective_pressure_points >= cost


static func _spend_points(state: EvoTypes.WorldState, cost: int) -> void:
	if not state.unlimited_pressure_mode:
		state.selective_pressure_points -= cost


static func _displace_submerged_demes(state: EvoTypes.WorldState, lang: String = "es") -> void:
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.biome != "ocean" or cell.deme_ids.is_empty():
			continue

		var resident_ids := cell.deme_ids.duplicate()
		for deme_id in resident_ids:
			if not state.demes.has(deme_id):
				cell.deme_ids.erase(deme_id)
				continue
			var deme: EvoTypes.Deme = state.demes[deme_id]
			EvoDemographyMigration.evacuate_or_merge_displaced_deme(deme, cell, state, lang, "submerge_brush")

	var valid_flows: Array[EvoTypes.HexEdgeFlow] = []
	for fl in state.active_flows:
		if fl.from_deme_id != "" and not state.demes.has(fl.from_deme_id) and fl.flow_type != "merge":
			continue
		if fl.to_deme_id != "" and not state.demes.has(fl.to_deme_id):
			continue
		if fl.flow_type not in ["migration", "merge"]:
			if fl.from_deme_id != "" and state.demes.has(fl.from_deme_id):
				fl.from_hex_id = (state.demes[fl.from_deme_id] as EvoTypes.Deme).hex_id
			if fl.to_deme_id != "" and state.demes.has(fl.to_deme_id):
				fl.to_hex_id = (state.demes[fl.to_deme_id] as EvoTypes.Deme).hex_id
			if (state.cells.has(fl.from_hex_id) and (state.cells[fl.from_hex_id] as EvoTypes.HexCell).biome == "ocean") or (state.cells.has(fl.to_hex_id) and (state.cells[fl.to_hex_id] as EvoTypes.HexCell).biome == "ocean"):
				continue
		else:
			if state.cells.has(fl.to_hex_id) and (state.cells[fl.to_hex_id] as EvoTypes.HexCell).biome == "ocean":
				continue
		valid_flows.append(fl)
	state.active_flows = valid_flows

	var valid_conns: Array[Dictionary] = []
	for conn in state.disused_connections:
		var fa := str(conn["from_deme_id"])
		var fb := str(conn["to_deme_id"])
		if (fa != "" and not state.demes.has(fa)) or (fb != "" and not state.demes.has(fb)):
			continue
		var ha := str(conn["from_hex_id"])
		var hb := str(conn["to_hex_id"])
		if (state.cells.has(ha) and (state.cells[ha] as EvoTypes.HexCell).biome == "ocean") or (state.cells.has(hb) and (state.cells[hb] as EvoTypes.HexCell).biome == "ocean"):
			continue
		valid_conns.append(conn)
	state.disused_connections = valid_conns


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

	if not changed:
		return false
	_spend_points(state, COST_SET_BIOME)
	_displace_submerged_demes(state, lang)
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

	if not changed:
		return false
	_spend_points(state, COST_ADJUST_ALTITUDE)
	_displace_submerged_demes(state, lang)
	return true


static func apply_adjust_carrying_capacity(
	state: EvoTypes.WorldState,
	hex_ids: Array[String],
	factor_delta: float
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
			var degrade_factor := 0.78 if factor_delta < 0.0 else factor
			next_r = snappedf(clampf(cell.current_resources * degrade_factor, 0.0, next_k), 0.01)
		if not is_equal_approx(next_k, prev_k) or not is_equal_approx(next_r, prev_r):
			cell.carrying_capacity = next_k
			cell.current_resources = next_r
			changed = true

	if not changed:
		return false
	_spend_points(state, COST_ADJUST_CAPACITY)
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
		if cell.altitude < next_sea_level and cell.biome != "ocean":
			_apply_biome_climate_defaults(cell, "ocean", true)
		elif cell.altitude >= next_sea_level and cell.biome == "ocean":
			var emerged_biome := "coastal_shallows"
			if cell.altitude >= 0.78:
				emerged_biome = "high_mountain"
			elif cell.altitude >= 0.55:
				emerged_biome = "arid_steppe"
			elif cell.altitude >= 0.25:
				emerged_biome = "savanna"
			_apply_biome_climate_defaults(cell, emerged_biome, false)

	_displace_submerged_demes(state, lang)
	return true
