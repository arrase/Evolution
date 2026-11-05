class_name EvoTurnEngine
extends RefCounted

const COST_SET_BIOME: int = 10
const COST_ADJUST_ALTITUDE: int = 15
const COST_ADJUST_CAPACITY: int = 10
const COST_ADJUST_SEA_LEVEL: int = 25


static func advance_generation(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	var prev_chronicle_count := state.chronicle.size()

	EvoEnvPhase.run_environmental_phase(state, lang)
	EvoDecisionModel.evaluate_all_demes(state, lang)
	EvoBiophysPhase.run_biophysical_phase(state, lang)
	EvoMilestonePhase.run_milestone_phase(state, lang)

	var new_entries: Array[EvoTypes.ChronicleEntry] = []
	var has_milestone := false
	var has_macro_outcome := state.macro_outcome_type != ""
	var milestone_entry: EvoTypes.ChronicleEntry = null
	var outcome_entry: EvoTypes.ChronicleEntry = null

	for i in range(prev_chronicle_count, state.chronicle.size()):
		var entry := state.chronicle[i]
		new_entries.append(entry)
		if entry.event_type in ["baldwin_trait", "cultural_innovation", "allopatric_speciation"]:
			has_milestone = true
			milestone_entry = entry
		elif entry.event_type in ["single_survivor", "ecological_equilibrium"]:
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


static func _displace_submerged_demes(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var is_en := lang == "en"
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.biome != "ocean" or cell.deme_ids.is_empty():
			continue

		var resident_ids := cell.deme_ids.duplicate()
		cell.deme_ids.clear()

		for deme_id in resident_ids:
			if not state.demes.has(deme_id):
				continue
			var deme: EvoTypes.Deme = state.demes[deme_id]

			var candidates: Array[EvoTypes.HexCell] = []
			for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
				var ncell: EvoTypes.HexCell = state.cells[nid]
				if ncell.biome != "ocean" and ncell.deme_ids.size() < 3:
					candidates.append(ncell)

			candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				return a.current_resources > b.current_resources
			)

			if not candidates.is_empty():
				var target_cell := candidates[0]
				deme.hex_id = target_cell.id
				deme.energy_reserves = snappedf(deme.energy_reserves * 0.80, 0.01)
				target_cell.deme_ids.append(deme.id)

				var flow := EvoTypes.HexEdgeFlow.new()
				flow.from_hex_id = cell.id
				flow.to_hex_id = target_cell.id
				flow.flow_type = "migration"
				flow.intensity = 0.65
				flow.from_deme_id = deme.id
				flow.to_deme_id = deme.id
				state.active_flows.append(flow)
			else:
				state.demes.erase(deme_id)
				if not state.recent_extinction_hexes.has(cell.id):
					state.recent_extinction_hexes.append(cell.id)

				var entry := EvoTypes.ChronicleEntry.new()
				entry.id = "chronicle-submerge-brush-%d-%s" % [state.generation, deme.id]
				entry.generation = state.generation
				entry.event_type = "extinction"
				entry.title = ("%s Submerged" if is_en else "%s Sumergido") % deme.name
				entry.causal_explanation = (
					"%s went extinct when cell (%s) submerged into ocean with no accessible terrestrial refuge." % [deme.name, cell.id]
					if is_en
					else "%s se extinguió cuando la celda (%s) quedó sumergida en el océano sin refugio terrestre accesible." % [deme.name, cell.id]
				)
				entry.hex_id = cell.id
				entry.deme_id = deme.id
				entry.lineage_id = deme.lineage_id
				state.chronicle.append(entry)

				var has_relatives := false
				for rem_id in state.demes.keys():
					var rem: EvoTypes.Deme = state.demes[rem_id]
					if rem.lineage_id == deme.lineage_id:
						has_relatives = true
						break
				if not has_relatives and state.lineage_tree.has(deme.lineage_id):
					(state.lineage_tree[deme.lineage_id] as EvoTypes.LineageNode).extinct_generation = state.generation


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

	_spend_points(state, COST_SET_BIOME)
	var defaults: Dictionary = EvoTypes.BIOME_CLIMATE_DEFAULTS[target_biome]

	for hid in hex_ids:
		if not state.cells.has(hid):
			continue
		var cell: EvoTypes.HexCell = state.cells[hid]
		cell.biome = target_biome
		cell.temperature = float(defaults["temperature"])
		cell.humidity = float(defaults["humidity"])
		cell.altitude = snappedf(
			clampf(cell.altitude, float(defaults["min_alt"]), float(defaults["max_alt"])),
			0.01
		)

		if target_biome == "ocean":
			cell.current_resources = 0.0
		else:
			if cell.altitude < state.sea_level:
				cell.altitude = snappedf(minf(1.0, state.sea_level + 0.05), 0.01)
			if cell.carrying_capacity_max < 120.0:
				cell.carrying_capacity_max = 300.0
			elif cell.carrying_capacity_max < 220.0:
				cell.carrying_capacity_max = 220.0
			if cell.carrying_capacity < 80.0:
				cell.carrying_capacity = minf(cell.carrying_capacity_max, maxf(cell.carrying_capacity, 220.0))
				cell.current_resources = minf(cell.carrying_capacity, maxf(cell.current_resources, 180.0))

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

	_spend_points(state, COST_ADJUST_ALTITUDE)

	for hid in hex_ids:
		if not state.cells.has(hid):
			continue
		var cell: EvoTypes.HexCell = state.cells[hid]
		var next_alt := snappedf(clampf(cell.altitude + delta, 0.0, 1.0), 0.01)
		cell.altitude = next_alt

		if next_alt < state.sea_level:
			cell.biome = "ocean"
			cell.current_resources = 0.0
		elif cell.biome == "ocean" and next_alt >= state.sea_level:
			cell.biome = "coastal_shallows" if next_alt < 0.25 else "savanna"
			cell.carrying_capacity_max = maxf(200.0, cell.carrying_capacity_max)
			cell.carrying_capacity = maxf(120.0, cell.carrying_capacity)
			cell.current_resources = maxf(80.0, cell.current_resources)
		elif next_alt >= 0.78:
			cell.biome = "high_mountain"
			cell.temperature = minf(cell.temperature, -0.30)
		elif delta < 0.0 and cell.biome == "high_mountain" and next_alt < 0.78:
			cell.biome = "savanna" if next_alt < 0.55 else "arid_steppe"
			cell.temperature = maxf(cell.temperature, 0.20)

	_displace_submerged_demes(state, lang)
	return true


static func apply_adjust_carrying_capacity(
	state: EvoTypes.WorldState,
	hex_ids: Array[String],
	factor_delta: float
) -> bool:
	if hex_ids.is_empty() or not _can_afford(state, COST_ADJUST_CAPACITY):
		return false

	_spend_points(state, COST_ADJUST_CAPACITY)
	var factor := 1.0 + factor_delta

	for hid in hex_ids:
		if not state.cells.has(hid):
			continue
		var cell: EvoTypes.HexCell = state.cells[hid]
		var next_k := snappedf(clampf(cell.carrying_capacity * factor, 10.0, cell.carrying_capacity_max), 0.01)
		cell.carrying_capacity = next_k
		if factor_delta > 0.0:
			var added_res := maxf(
				cell.current_resources * factor,
				cell.current_resources + cell.carrying_capacity * factor_delta
			)
			cell.current_resources = clampf(roundf(added_res), 0.0, next_k)
		else:
			cell.current_resources = snappedf(clampf(cell.current_resources * factor, 0.0, next_k), 0.01)

	return true


static func apply_adjust_sea_level(
	state: EvoTypes.WorldState,
	delta: float,
	lang: String = "es"
) -> bool:
	if not _can_afford(state, COST_ADJUST_SEA_LEVEL):
		return false

	_spend_points(state, COST_ADJUST_SEA_LEVEL)
	var next_sea_level := snappedf(clampf(state.sea_level + delta, 0.0, 0.50), 0.01)
	state.sea_level = next_sea_level

	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		if cell.altitude < next_sea_level and cell.biome != "ocean":
			cell.biome = "ocean"
			cell.current_resources = 0.0
		elif cell.altitude >= next_sea_level and cell.biome == "ocean":
			if cell.altitude < 0.25:
				cell.biome = "coastal_shallows"
			elif cell.altitude < 0.55:
				cell.biome = "savanna"
			elif cell.altitude < 0.78:
				cell.biome = "arid_steppe"
			else:
				cell.biome = "high_mountain"
			cell.carrying_capacity_max = maxf(160.0, cell.carrying_capacity_max)
			cell.carrying_capacity = maxf(roundf(cell.carrying_capacity_max * 0.88), cell.carrying_capacity)
			cell.current_resources = maxf(cell.current_resources, roundf(cell.carrying_capacity * 0.35))

	_displace_submerged_demes(state, lang)
	return true
