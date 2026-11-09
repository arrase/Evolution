class_name EvoSettlementPhase
extends RefCounted

## Settlement lifecycle: founding camps, occupying conquered hexes, synoecism and
## walled unions, extinction and isolation tracking for allopatric speciation.


static func strip_migration_suffix(id_str: String) -> String:
	for i in range(1, id_str.length() - 2):
		if id_str[i] == "-" and id_str[i + 1] in ["m", "w"] and id_str[i + 2].is_valid_int():
			return id_str.substr(0, i)
	return id_str


static func strip_coord_suffix(name_str: String) -> String:
	var open_idx := name_str.rfind(" (")
	if open_idx > 0 and name_str.ends_with(")") and name_str.substr(open_idx).contains(","):
		return name_str.substr(0, open_idx)
	return name_str


static func compute_deme_divergence(deme_a: EvoTypes.Deme, deme_b: EvoTypes.Deme) -> float:
	var set_a: Dictionary = {}
	for tid in deme_a.biological_trait_ids + deme_a.cultural_trait_ids:
		set_a[tid] = true
	var set_b: Dictionary = {}
	for tid in deme_b.biological_trait_ids + deme_b.cultural_trait_ids:
		set_b[tid] = true
	var union_size := set_a.size()
	var shared := 0
	for tid in set_b.keys():
		if set_a.has(tid):
			shared += 1
		else:
			union_size += 1
	return 0.0 if union_size == 0 else snappedf(1.0 - float(shared) / float(union_size), 0.0001)


static func _new_daughter(parent: EvoTypes.Deme, marker: String, hex: EvoTypes.HexCell, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	var root_id := strip_migration_suffix(parent.id)
	var daughter_id := "%s-%s%d-%d_%d" % [root_id, marker, state.generation, hex.q, hex.r]
	var daughter := EvoTypes.Deme.new()
	daughter.id = daughter_id
	daughter.name = ("%s (%s)" % [strip_coord_suffix(parent.name), hex.id]).substr(0, 60)
	daughter.lineage_id = parent.lineage_id
	daughter.strategy_id = parent.strategy_id
	daughter.color = parent.color
	daughter.hex_id = hex.id
	daughter.biological_trait_ids = parent.biological_trait_ids.duplicate()
	daughter.cultural_trait_ids = parent.cultural_trait_ids.duplicate()
	daughter.decision_model_tag = parent.decision_model_tag
	daughter.reputation = parent.reputation
	daughter.salubrity = parent.salubrity
	hex.owner_deme_id = ""
	hex.land_use = "wild"
	hex.has_ruins = false
	hex.deme_ids.append(daughter_id)
	state.demes[daughter_id] = daughter
	return daughter


static func resolve_settling(state: EvoTypes.WorldState) -> void:
	for did in state.demes.keys():
		if not state.demes.has(did):
			continue
		var deme: EvoTypes.Deme = state.demes[did]
		if str(deme.chosen_action["type"]) != "settle":
			continue
		var target_id := str(deme.chosen_action["target"])
		var valid_targets := EvoActionMenu.settle_targets(deme, state).filter(func(c: EvoTypes.HexCell) -> bool: return c.id == target_id)
		if deme.population < EvoPayoffs.SETTLE_MIN_POP or valid_targets.is_empty():
			deme.last_outcome = "Your settlers could not leave: the land at %s is no longer free or you are too few." % target_id
			continue
		var daughter := found_camp(deme, valid_targets[0], state)
		deme.last_outcome = "You founded a camp at %s with %d settlers." % [target_id, daughter.population]


static func found_camp(deme: EvoTypes.Deme, hex: EvoTypes.HexCell, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	var n := EvoPayoffs.settlers(deme)
	var food := deme.energy_reserves * float(n) / float(deme.population)
	var daughter := _new_daughter(deme, "m", hex, state)
	daughter.population = n
	daughter.energy_reserves = food
	deme.population -= n
	deme.energy_reserves -= food
	EvoRelations.remember(daughter, state, "Founded by settlers from %s." % deme.name)
	_push_flow(state, deme.hex_id, hex.id, "migration", 0.6, deme.id, daughter.id)
	EvoTypes.push_event(state, "colonize", deme.hex_id, hex.id, deme.id, daughter.id, float(n), 0)
	return daughter


## The defender leaves its hex to the conquering warband: it flees to the richest
## empty neighbor hex, or is absorbed (one third of survivors join) if surrounded.
static func occupy_conquered_hex(
	attacker: EvoTypes.Deme,
	defender: EvoTypes.Deme,
	warband_pop: int,
	loot: float,
	captured_tier: int,
	state: EvoTypes.WorldState
) -> EvoTypes.Deme:
	var target_cell: EvoTypes.HexCell = state.cells[defender.hex_id]
	var refuge: EvoTypes.HexCell = null
	for nid in HexMath.get_neighbor_ids(target_cell.q, target_cell.r, state.cells):
		var rcell: EvoTypes.HexCell = state.cells[nid]
		if EvoActionMenu.is_passable(rcell) and rcell.deme_ids.is_empty() and (refuge == null or rcell.current_resources > refuge.current_resources):
			refuge = rcell
	var captured_fields: Array[EvoTypes.HexCell] = EvoRuralHinterland.owned_hexes(defender, state)
	target_cell.deme_ids.erase(defender.id)
	var absorbed := 0
	if refuge != null and defender.population >= EvoPayoffs.MIN_VIABLE_POP:
		refuge.owner_deme_id = ""
		refuge.land_use = "wild"
		refuge.has_ruins = false
		refuge.deme_ids.append(defender.id)
		defender.hex_id = refuge.id
		_push_flow(state, target_cell.id, refuge.id, "migration", 0.5, defender.id, defender.id)
	else:
		absorbed = defender.population / 3
		defender.population = 0
	defender.defense_tier = 0
	defender.walled_union_id = ""

	var warband := _new_daughter(attacker, "w", target_cell, state)
	warband.population = warband_pop + absorbed
	warband.energy_reserves = loot
	warband.defense_tier = captured_tier
	for field in captured_fields:
		field.owner_deme_id = warband.id
	return warband


static func unite(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState, lang: String) -> void:
	var ca: EvoTypes.HexCell = state.cells[a.hex_id]
	var cb: EvoTypes.HexCell = state.cells[b.hex_id]
	if EvoOutcomeForecast.union_kind(a, b) == "walled_union":
		var union_id := a.walled_union_id if a.walled_union_id != "" else (b.walled_union_id if b.walled_union_id != "" else "union-%s" % EvoTypes.make_pair_key(a.id, b.id))
		a.walled_union_id = union_id
		b.walled_union_id = union_id
		a.defense_tier = maxi(a.defense_tier, 1)
		b.defense_tier = maxi(b.defense_tier, 1)
		EvoTypes.push_event(state, "walled_union", ca.id, cb.id, a.id, b.id, 1.0, 0)
		_push_flow(state, ca.id, cb.id, "merge", 0.85, a.id, b.id)
		var params := {"deme_a": a.name, "deme_b": b.name, "hex": "%s <-> %s" % [ca.id, cb.id]}
		_chronicle(state, "chronicle-union-%d-%s-%s" % [state.generation, a.id, b.id], "merge",
			EvoI18n.t(lang, "chronicle_walled_union_title", params), EvoI18n.t(lang, "chronicle_walled_union_desc", params), ca.id, a)
		return
	var a_hosts := a.get_village_tier() > b.get_village_tier() or (a.get_village_tier() == b.get_village_tier() and a.population >= b.population)
	var host := a if a_hosts else b
	var joiner := b if a_hosts else a
	merge_into(host, joiner, state, lang)


static func merge_into(host: EvoTypes.Deme, joiner: EvoTypes.Deme, state: EvoTypes.WorldState, lang: String) -> void:
	var host_cell: EvoTypes.HexCell = state.cells[host.hex_id]
	var joiner_cell: EvoTypes.HexCell = state.cells[joiner.hex_id]
	var params := {"deme_a": host.name, "deme_b": joiner.name, "hex": host_cell.id, "pop": str(host.population + joiner.population)}
	host.population += joiner.population
	host.energy_reserves = minf(EvoPayoffs.storage_cap(host), host.energy_reserves + joiner.energy_reserves)
	host.defense_tier = maxi(host.defense_tier, joiner.defense_tier)
	host.merged_count += 1 + joiner.merged_count
	host.innovation_counter = maxf(host.innovation_counter, joiner.innovation_counter)
	if joiner.color != host.color:
		host.secondary_color = joiner.color
	for tid in joiner.biological_trait_ids + joiner.cultural_trait_ids:
		if EvoCulture.can_acquire_trait(host, tid, state.traits_catalog):
			if (state.traits_catalog[tid] as EvoTypes.TraitDef).category == "biological":
				host.biological_trait_ids.append(tid)
			else:
				host.cultural_trait_ids.append(tid)
	host_cell.carrying_capacity = minf(host_cell.carrying_capacity_max * 1.25, host_cell.carrying_capacity + 20.0)
	for field in EvoRuralHinterland.owned_hexes(joiner, state):
		field.owner_deme_id = host.id if HexMath.hex_distance(field.q, field.r, host_cell.q, host_cell.r) == 1 else ""
	joiner_cell.deme_ids.erase(joiner.id)
	joiner_cell.owner_deme_id = host.id
	joiner_cell.land_use = "pasture" if joiner_cell.biome in ["arid_steppe", "tundra"] else "crops"
	for pk in state.relations.keys():
		var partner := EvoTypes.pair_partner(str(pk), joiner.id)
		if partner != "" and partner != host.id and not state.relations.has(EvoTypes.make_pair_key(host.id, partner)):
			state.relations[EvoTypes.make_pair_key(host.id, partner)] = state.relations[pk]
	EvoTypes.erase_deme_relations(state, joiner.id)
	state.demes.erase(joiner.id)
	EvoTypes.push_event(state, "absorption", joiner_cell.id, host_cell.id, host.id, joiner.id, float(joiner.population), 0)
	_push_flow(state, joiner_cell.id, host_cell.id, "merge", 0.85, host.id, host.id)
	EvoRelations.remember(host, state, "%s joined your settlement." % joiner.name)
	_chronicle(state, "chronicle-merge-%d-%s-%s" % [state.generation, host.id, joiner.id], "merge",
		EvoI18n.t(lang, "chronicle_merge_title", params), EvoI18n.t(lang, "chronicle_merge_desc", params), host_cell.id, host)


static func remove_extinct(state: EvoTypes.WorldState, lang: String) -> void:
	var is_en := lang == "en"
	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.population >= EvoPayoffs.MIN_VIABLE_POP:
			continue
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
		cell.deme_ids.erase(deme.id)
		if deme.population > 0:
			cell.has_ruins = cell.biome != "ocean"
		for field in EvoRuralHinterland.owned_hexes(deme, state):
			field.owner_deme_id = ""
			field.land_use = "wild"
			field.has_ruins = true
		EvoTypes.push_event(state, "extinction", deme.hex_id, deme.hex_id, deme.id, "", 0.0, deme.population)
		EvoTypes.erase_deme_relations(state, deme.id)
		state.demes.erase(deme.id)
		if not state.recent_extinction_hexes.has(deme.hex_id):
			state.recent_extinction_hexes.append(deme.hex_id)
		var title := ("%s Extinct" if is_en else "%s Extinguió") % deme.name
		var desc := (
			"%s fell below minimum viable population in hex (%s)." % [deme.name, deme.hex_id]
			if is_en
			else "%s cayó por debajo de la población mínima viable en el hexágono (%s)." % [deme.name, deme.hex_id]
		)
		_chronicle(state, "chronicle-extinct-%d-%s" % [state.generation, deme.id], "extinction", title, desc, deme.hex_id, deme)
		mark_lineage_if_extinct(state, deme.lineage_id)


static func mark_lineage_if_extinct(state: EvoTypes.WorldState, lineage_id: String) -> void:
	for d: EvoTypes.Deme in state.demes.values():
		if d.lineage_id == lineage_id:
			return
	if state.lineage_tree.has(lineage_id):
		(state.lineage_tree[lineage_id] as EvoTypes.LineageNode).extinct_generation = state.generation


static func _is_connected_to_founder(deme: EvoTypes.Deme, founder_hex_id: String, state: EvoTypes.WorldState) -> bool:
	var mobility := EvoPayoffs.vector(deme, state).spatial_mobility
	var visited: Dictionary = {deme.hex_id: 0}
	var queue: Array[String] = [deme.hex_id]
	var head := 0
	while head < queue.size():
		var cur_id := queue[head]
		head += 1
		if int(visited[cur_id]) >= 3:
			continue
		var cur_cell: EvoTypes.HexCell = state.cells[cur_id]
		for nid in HexMath.get_neighbor_ids(cur_cell.q, cur_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if visited.has(nid) or ncell.biome == "ocean" or ncell.altitude > 0.85 or ncell.altitude - 0.50 > mobility:
				continue
			if nid == founder_hex_id:
				return true
			for oid in ncell.deme_ids:
				if (state.demes[oid] as EvoTypes.Deme).lineage_id == deme.lineage_id:
					return true
			visited[nid] = int(visited[cur_id]) + 1
			queue.append(nid)
	return false


static func update_isolation(state: EvoTypes.WorldState) -> void:
	for d: EvoTypes.Deme in state.demes.values():
		var founder_hex := (state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).founder_hex_id
		if d.hex_id == founder_hex or _is_connected_to_founder(d, founder_hex, state):
			d.isolation_turns = 0
		else:
			d.isolation_turns += 1


static func revalidate_walled_unions(state: EvoTypes.WorldState) -> void:
	var changed := true
	while changed:
		changed = false
		for d: EvoTypes.Deme in state.demes.values():
			if d.walled_union_id == "":
				continue
			var has_partner := false
			if d.get_village_tier() >= 2 and EvoActionMenu.is_passable(state.cells[d.hex_id]):
				for other in EvoActionMenu.neighbor_demes(d, state):
					if other.walled_union_id == d.walled_union_id and other.get_village_tier() >= 2 and not EvoTypes.is_vendetta_active(state, d.id, other.id):
						has_partner = true
						break
			if not has_partner:
				d.walled_union_id = ""
				changed = true


static func _push_flow(state: EvoTypes.WorldState, from_hex: String, to_hex: String, flow_type: String, intensity: float, from_deme: String, to_deme: String) -> void:
	var flow := EvoTypes.HexEdgeFlow.new()
	flow.from_hex_id = from_hex
	flow.to_hex_id = to_hex
	flow.flow_type = flow_type
	flow.intensity = intensity
	flow.from_deme_id = from_deme
	flow.to_deme_id = to_deme
	state.active_flows.append(flow)


static func push_flow(state: EvoTypes.WorldState, a: EvoTypes.Deme, b: EvoTypes.Deme, flow_type: String, intensity: float) -> void:
	_push_flow(state, a.hex_id, b.hex_id, flow_type, intensity, a.id, b.id)


static func _chronicle(state: EvoTypes.WorldState, entry_id: String, event_type: String, title: String, desc: String, hex_id: String, deme: EvoTypes.Deme) -> void:
	var entry := EvoTypes.ChronicleEntry.new()
	entry.id = entry_id
	entry.generation = state.generation
	entry.event_type = event_type
	entry.title = title
	entry.causal_explanation = desc
	entry.hex_id = hex_id
	entry.deme_id = deme.id
	entry.lineage_id = deme.lineage_id
	state.chronicle.append(entry)


static func chronicle(state: EvoTypes.WorldState, entry_id: String, event_type: String, lang: String, key: String, params: Dictionary, hex_id: String, deme: EvoTypes.Deme) -> void:
	_chronicle(state, entry_id, event_type, EvoI18n.t(lang, key + "_title", params), EvoI18n.t(lang, key + "_desc", params), hex_id, deme)
