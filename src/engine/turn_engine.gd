class_name EvoTurnEngine
extends RefCounted

const COST_SET_BIOME: int = 10
const COST_ADJUST_ALTITUDE: int = 15
const COST_ADJUST_CAPACITY: int = 10
const COST_ADJUST_SEA_LEVEL: int = 25


static func advance_generation(state: EvoTypes.WorldState, lang: String = "es") -> Dictionary:
	var prev_chronicle_count := state.chronicle.size()

	EvoEnvPhase.run_environmental_phase(state, lang)
	EvoDecisionModel.evaluate_all_demes(state, lang, false)
	EvoBiophysPhase.run_biophysical_phase(state, lang)
	EvoMilestonePhase.run_milestone_phase(state, lang)

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

	EvoDecisionModel.prefetch_for_state(state)

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
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		if d.walled_union_id != "" and (d.get_village_tier() < 2 or not state.cells.has(d.hex_id)):
			d.walled_union_id = ""
	var changed := true
	while changed:
		changed = false
		for did in state.demes.keys():
			var d: EvoTypes.Deme = state.demes[did]
			if d.walled_union_id == "":
				continue
			var d_cell: EvoTypes.HexCell = state.cells[d.hex_id]
			var has_adjacent_partner := false
			for nid in HexMath.get_neighbor_ids(d_cell.q, d_cell.r, state.cells):
				var ncell: EvoTypes.HexCell = state.cells[nid]
				for oid in ncell.deme_ids:
					if oid != d.id and state.demes.has(oid):
						var od: EvoTypes.Deme = state.demes[oid]
						if od.population > 0 and od.walled_union_id == d.walled_union_id and od.get_village_tier() >= 2:
							var pk := EvoTypes.make_pair_key(d.id, od.id)
							if int(state.active_pacts.get(pk, 0)) >= 0:
								has_adjacent_partner = true
								break
				if has_adjacent_partner:
					break
			if not has_adjacent_partner:
				d.walled_union_id = ""
				changed = true


static func _displace_submerged_demes(state: EvoTypes.WorldState, lang: String = "es") -> void:
	var is_en := lang == "en"
	for cid in state.cells.keys():
		var cell: EvoTypes.HexCell = state.cells[cid]
		var is_uninhabitable := cell.biome in ["ocean", "high_mountain"] or cell.altitude > 0.85
		if is_uninhabitable:
			cell.land_use = "wild"
			cell.owner_deme_id = ""
			cell.has_ruins = false
		if not is_uninhabitable or cell.deme_ids.is_empty():
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
				if ncell.biome not in ["ocean", "high_mountain"] and ncell.altitude <= 0.85 and ncell.deme_ids.is_empty():
					candidates.append(ncell)

			candidates.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
				return a.current_resources > b.current_resources
			)

			if not candidates.is_empty():
				var target_cell := candidates[0]
				target_cell.owner_deme_id = ""
				target_cell.land_use = "wild"
				target_cell.has_ruins = false
				deme.hex_id = target_cell.id
				deme.energy_reserves = snappedf(deme.energy_reserves * 0.80, 0.01)
				target_cell.deme_ids.append(deme.id)

				for rcid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
					var rcell: EvoTypes.HexCell = state.cells[rcid]
					if rcell.owner_deme_id == deme.id and HexMath.hex_distance(rcell.q, rcell.r, target_cell.q, target_cell.r) != 1:
						rcell.owner_deme_id = ""
						rcell.land_use = "wild"

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
				for rcid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
					var rcell: EvoTypes.HexCell = state.cells[rcid]
					if rcell.owner_deme_id == deme_id:
						rcell.owner_deme_id = ""
						rcell.land_use = "wild"
				var drowned_pacts: Array[String] = []
				for pk_var in state.active_pacts.keys():
					var pk := str(pk_var)
					var sep := "__" if pk.contains("__") else "|"
					var parts := pk.split(sep)
					if parts.size() == 2 and (parts[0] == deme_id or parts[1] == deme_id):
						drowned_pacts.append(pk)
				for pk in drowned_pacts:
					state.active_pacts.erase(pk)
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

	_revalidate_walled_unions(state)
	EvoEcologyInteraction.enforce_rural_hinterland_quotas(state)

	var valid_flows: Array[EvoTypes.HexEdgeFlow] = []
	for fl in state.active_flows:
		if fl.from_deme_id != "" and not state.demes.has(fl.from_deme_id):
			continue
		if fl.to_deme_id != "" and not state.demes.has(fl.to_deme_id):
			continue
		if fl.flow_type != "migration":
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
		var fa := str(conn.get("from_deme_id", ""))
		var fb := str(conn.get("to_deme_id", ""))
		if (fa != "" and not state.demes.has(fa)) or (fb != "" and not state.demes.has(fb)):
			continue
		var ha := str(conn.get("from_hex_id", ""))
		var hb := str(conn.get("to_hex_id", ""))
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
		cell.land_use = "wild"
		cell.owner_deme_id = ""
		cell.has_ruins = false
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
		elif cell.owner_deme_id != "" and cell.land_use in ["crops", "pasture"]:
			cell.land_use = "pasture" if cell.biome in ["arid_steppe", "tundra"] else "crops"

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
		if cell.biome in ["ocean", "high_mountain"] or cell.altitude > 0.85:
			cell.land_use = "wild"
			cell.owner_deme_id = ""
			cell.has_ruins = false
		elif cell.owner_deme_id != "" and cell.land_use in ["crops", "pasture"]:
			cell.land_use = "pasture" if cell.biome in ["arid_steppe", "tundra"] else "crops"

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
