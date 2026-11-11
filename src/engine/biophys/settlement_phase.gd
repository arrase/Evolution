class_name EvoSettlementPhase
extends RefCounted

## Settlement lifecycle: founding camps, occupying conquered hexes, synoecism and
## multi-hex walled unions, extinction and isolation tracking for allopatric speciation.


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


static func closest_defender_urban_cell(
	attacker: EvoTypes.Deme,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> EvoTypes.HexCell:
	var best_cell: EvoTypes.HexCell = state.cells[defender.hex_id]
	var best_dist := 999
	for hd in defender.urban_hex_ids:
		var cd: EvoTypes.HexCell = state.cells[hd]
		for ha in attacker.urban_hex_ids:
			var ca: EvoTypes.HexCell = state.cells[ha]
			var dist := HexMath.hex_distance(cd.q, cd.r, ca.q, ca.r)
			if dist < best_dist:
				best_dist = dist
				best_cell = cd
	return best_cell


static func closest_urban_hex_to(
	from_deme: EvoTypes.Deme,
	to_deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> String:
	var best_hex := from_deme.hex_id
	var best_dist := 999
	for ha in from_deme.urban_hex_ids:
		var ca: EvoTypes.HexCell = state.cells[ha]
		for hb in to_deme.urban_hex_ids:
			var cb: EvoTypes.HexCell = state.cells[hb]
			var dist := HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r)
			if dist < best_dist:
				best_dist = dist
				best_hex = ha
	return best_hex


static func _closest_urban_hex_to_cell(deme: EvoTypes.Deme, target: EvoTypes.HexCell, state: EvoTypes.WorldState) -> String:
	var best_hex := deme.hex_id
	var best_dist := 999
	for ha in deme.urban_hex_ids:
		var ca: EvoTypes.HexCell = state.cells[ha]
		var dist := HexMath.hex_distance(ca.q, ca.r, target.q, target.r)
		if dist < best_dist:
			best_dist = dist
			best_hex = ha
	return best_hex


static func _new_daughter(parent: EvoTypes.Deme, marker: String, hex: EvoTypes.HexCell, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	var root_id := strip_migration_suffix(parent.id)
	var seq := state.next_deme_seq
	state.next_deme_seq += 1
	var daughter_id := "%s-%s%d-%d_%d-%d" % [root_id, marker, state.generation, hex.q, hex.r, seq]
	var daughter := EvoTypes.Deme.new()
	daughter.id = daughter_id
	daughter.name = ("%s (%s)" % [strip_coord_suffix(parent.name), hex.id]).substr(0, 60)
	daughter.lineage_id = parent.lineage_id
	daughter.strategy_id = parent.strategy_id
	daughter.faction_slot = parent.faction_slot
	daughter.color = parent.color
	daughter.hex_id = hex.id
	daughter.urban_hex_ids = [hex.id]
	daughter.biological_trait_ids = parent.biological_trait_ids.duplicate()
	daughter.cultural_trait_ids = parent.cultural_trait_ids.duplicate()
	daughter.decision_model_tag = parent.decision_model_tag
	daughter.reputation = parent.reputation
	daughter.salubrity = parent.salubrity
	hex.owner_deme_id = ""
	hex.land_use = "wild"
	hex.has_ruins = false
	hex.ruin_turns = 0
	hex.deme_ids = [daughter_id]
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
		if deme.population < EvoPayoffs.settle_min_pop(deme) or deme.energy_reserves < EvoPayoffs.settle_min_reserves(deme) or valid_targets.is_empty():
			deme.last_outcome = "Your settlers could not leave: the land at %s is no longer free or you lack people/food." % target_id
			continue
		var daughter := found_camp(deme, valid_targets[0], state)
		deme.last_outcome = "You founded a camp at %s with %d settlers." % [target_id, daughter.population]


static func found_camp(deme: EvoTypes.Deme, hex: EvoTypes.HexCell, state: EvoTypes.WorldState) -> EvoTypes.Deme:
	var n := EvoPayoffs.settlers(deme)
	var food := deme.energy_reserves * float(n) / float(deme.population)
	var origin_hex := _closest_urban_hex_to_cell(deme, hex, state)
	var daughter := _new_daughter(deme, "m", hex, state)
	daughter.population = n
	daughter.energy_reserves = food
	deme.population -= n
	deme.energy_reserves -= food
	EvoRelations.remember(deme, state, "You founded a colony at %s (%d settlers)%s." % [hex.id, n, EvoRelations.posture_tag(deme)])
	EvoRelations.remember(daughter, state, "Founded by settlers from %s." % deme.name)
	_push_flow(state, origin_hex, hex.id, "migration", 0.6, deme.id, daughter.id)
	EvoTypes.push_event(state, "colonize", origin_hex, hex.id, deme.id, daughter.id, float(n), 0)
	return daughter


## The defender loses its assaulted district to the conquering warband: if multi-hex,
## only the assaulted district is detached; if single-hex, it flees to an empty wild
## neighbor hex or is absorbed (one third of survivors join) if surrounded.
static func occupy_conquered_hex(
	attacker: EvoTypes.Deme,
	defender: EvoTypes.Deme,
	warband_pop: int,
	loot: float,
	captured_tier: int,
	state: EvoTypes.WorldState
) -> EvoTypes.Deme:
	var target_cell := closest_defender_urban_cell(attacker, defender, state)
	var prev_fields := EvoRuralHinterland.owned_hexes(defender, state)
	var captured_fields: Array[EvoTypes.HexCell] = []
	var absorbed := 0

	if defender.urban_hex_ids.size() > 1:
		defender.urban_hex_ids.erase(target_cell.id)
		target_cell.deme_ids.erase(defender.id)
		defender.hex_id = defender.urban_hex_ids[0]
		var remaining_perim: Dictionary = {}
		for nid in EvoTypes.urban_perimeter_hex_ids(defender, state):
			remaining_perim[nid] = true
		for field in prev_fields:
			if not remaining_perim.has(field.id):
				if HexMath.hex_distance(field.q, field.r, target_cell.q, target_cell.r) == 1:
					captured_fields.append(field)
				else:
					field.owner_deme_id = ""
					field.land_use = "wild"
	else:
		var refuge: EvoTypes.HexCell = null
		for nid in HexMath.get_neighbor_ids(target_cell.q, target_cell.r, state.cells):
			var rcell: EvoTypes.HexCell = state.cells[nid]
			if EvoActionMenu.is_passable(rcell) and rcell.deme_ids.is_empty() and rcell.owner_deme_id == "" and rcell.ruin_turns == 0 and (refuge == null or rcell.current_resources > refuge.current_resources):
				refuge = rcell
		for field in prev_fields:
			if HexMath.hex_distance(field.q, field.r, target_cell.q, target_cell.r) == 1:
				captured_fields.append(field)
			else:
				field.owner_deme_id = ""
				field.land_use = "wild"
		target_cell.deme_ids.erase(defender.id)
		if refuge != null and defender.population >= EvoPayoffs.MIN_VIABLE_POP:
			refuge.owner_deme_id = ""
			refuge.land_use = "wild"
			refuge.has_ruins = false
			refuge.ruin_turns = 0
			refuge.deme_ids = [defender.id]
			defender.hex_id = refuge.id
			defender.urban_hex_ids = [refuge.id]
			_push_flow(state, target_cell.id, refuge.id, "migration", 0.5, defender.id, defender.id)
		else:
			absorbed = defender.population / 3
			defender.population = 0
		defender.defense_tier = 0

	var warband := _new_daughter(attacker, "w", target_cell, state)
	warband.population = warband_pop + absorbed
	warband.energy_reserves = loot
	warband.defense_tier = captured_tier
	for field in captured_fields:
		field.owner_deme_id = warband.id
	if defender.urban_hex_ids.size() > 1:
		revalidate_walled_unions(state)
	return warband


static func _merge_traits_and_relations(host: EvoTypes.Deme, joiner: EvoTypes.Deme, state: EvoTypes.WorldState) -> void:
	if joiner.color != host.color:
		host.secondary_color = joiner.color
	for tid in joiner.biological_trait_ids + joiner.cultural_trait_ids:
		if EvoCulture.can_acquire_trait(host, tid, state.traits_catalog):
			if (state.traits_catalog[tid] as EvoTypes.TraitDef).category == "biological":
				host.biological_trait_ids.append(tid)
			else:
				host.cultural_trait_ids.append(tid)
	for pk in state.relations.keys():
		var partner := EvoTypes.pair_partner(str(pk), joiner.id)
		if partner == "" or partner == host.id:
			continue
		var j_rel: EvoTypes.Relation = state.relations[pk]
		var h_key := EvoTypes.make_pair_key(host.id, partner)
		if not state.relations.has(h_key):
			var copied := EvoTypes.Relation.from_dict(j_rel.to_dict())
			if copied.proposal_from == joiner.id:
				copied.proposal_from = host.id
			state.relations[h_key] = copied
		else:
			var h_rel: EvoTypes.Relation = state.relations[h_key]
			h_rel.pact_turns = maxi(h_rel.pact_turns, j_rel.pact_turns)
			h_rel.trust = maxf(h_rel.trust, j_rel.trust)
			h_rel.truce_turns = maxi(h_rel.truce_turns, j_rel.truce_turns)
			if h_rel.pact_turns > 0:
				h_rel.feud_turns = 0
	for fl in state.active_flows:
		if fl.from_deme_id == joiner.id:
			fl.from_deme_id = host.id
		if fl.to_deme_id == joiner.id:
			fl.to_deme_id = host.id
	EvoTypes.erase_deme_relations(state, joiner.id)


static func unite(
	a: EvoTypes.Deme,
	b: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String,
	income_by_deme: Dictionary = {}
) -> void:
	if EvoOutcomeForecast.union_kind(a, b) == "walled_union":
		if a.urban_hex_ids.size() + b.urban_hex_ids.size() > EvoTypes.MAX_URBAN_HEXES:
			a.last_outcome = "Walled city already at maximum district size (%d)." % EvoTypes.MAX_URBAN_HEXES
			return
		var a_hosts := a.urban_hex_ids.size() > b.urban_hex_ids.size() or (a.urban_hex_ids.size() == b.urban_hex_ids.size() and a.population >= b.population)
		var host := a if a_hosts else b
		var joiner := b if a_hosts else a
		var host_hex := host.hex_id
		var joiner_hex := joiner.hex_id
		var joiner_name := joiner.name
		var joiner_lineage := joiner.lineage_id
		var joiner_fields := EvoRuralHinterland.owned_hexes(joiner, state)

		host.population += joiner.population
		if income_by_deme.has(host.id) or income_by_deme.has(joiner.id):
			income_by_deme[host.id] = float(income_by_deme.get(host.id, 0.0)) + float(income_by_deme.get(joiner.id, 0.0))
			income_by_deme.erase(joiner.id)
		for u_hid in joiner.urban_hex_ids:
			if not host.urban_hex_ids.has(u_hid):
				host.urban_hex_ids.append(u_hid)
			var u_cell: EvoTypes.HexCell = state.cells[u_hid]
			u_cell.deme_ids = [host.id]
			u_cell.owner_deme_id = ""
			u_cell.land_use = "wild"
			u_cell.has_ruins = false
			u_cell.ruin_turns = 0
		host.energy_reserves = minf(EvoPayoffs.storage_cap(host), host.energy_reserves + joiner.energy_reserves)
		host.defense_tier = maxi(2, maxi(host.defense_tier, joiner.defense_tier))
		host.merged_count += 1 + joiner.merged_count
		host.innovation_counter = maxf(host.innovation_counter, joiner.innovation_counter)

		var host_perim: Dictionary = {}
		for nid in EvoTypes.urban_perimeter_hex_ids(host, state):
			host_perim[nid] = true
		for field in joiner_fields:
			if field.deme_ids.is_empty():
				if host_perim.has(field.id):
					field.owner_deme_id = host.id
				else:
					field.owner_deme_id = ""
					field.land_use = "wild"

		_merge_traits_and_relations(host, joiner, state)
		state.demes.erase(joiner.id)
		mark_lineage_if_extinct(state, joiner_lineage)

		EvoTypes.push_event(state, "walled_union", joiner_hex, host_hex, host.id, host.id, float(host.urban_hex_ids.size()), 0)
		_push_flow(state, joiner_hex, host_hex, "merge", 0.9, host.id, host.id)
		host.last_outcome = "You fused walls with %s into a %d-hex city (%d people)." % [joiner_name, host.urban_hex_ids.size(), host.population]
		EvoRelations.remember(host, state, "Fused permanently with %s into a %d-hex walled city (%d people)." % [joiner_name, host.urban_hex_ids.size(), host.population])
		var params := {"deme_a": host.name, "deme_b": joiner_name, "hex": "%s <-> %s" % [host_hex, joiner_hex]}
		_chronicle(state, "chronicle-union-%d-%s-%s" % [state.generation, host.id, joiner.id], "merge",
			EvoI18n.t(lang, "chronicle_walled_union_title", params), EvoI18n.t(lang, "chronicle_walled_union_desc", params), host_hex, host)
		return

	var a_hosts := a.get_village_tier() > b.get_village_tier() or (a.get_village_tier() == b.get_village_tier() and a.population >= b.population)
	var host := a if a_hosts else b
	var joiner := b if a_hosts else a
	merge_into(host, joiner, state, lang, income_by_deme)


static func merge_into(
	host: EvoTypes.Deme,
	joiner: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	lang: String,
	income_by_deme: Dictionary = {}
) -> void:
	var host_cell: EvoTypes.HexCell = state.cells[host.hex_id]
	var joiner_cell: EvoTypes.HexCell = state.cells[joiner.hex_id]
	var joiner_lineage := joiner.lineage_id
	var joiner_pop := joiner.population
	var joiner_name := joiner.name
	var joiner_fields := EvoRuralHinterland.owned_hexes(joiner, state)
	var params := {"deme_a": host.name, "deme_b": joiner_name, "hex": host_cell.id, "pop": str(host.population + joiner_pop)}

	host.population += joiner_pop
	if income_by_deme.has(host.id) or income_by_deme.has(joiner.id):
		income_by_deme[host.id] = float(income_by_deme.get(host.id, 0.0)) + float(income_by_deme.get(joiner.id, 0.0))
		income_by_deme.erase(joiner.id)
	host.energy_reserves = minf(EvoPayoffs.storage_cap(host), host.energy_reserves + joiner.energy_reserves)
	host.defense_tier = maxi(host.defense_tier, joiner.defense_tier)
	host.merged_count += 1 + joiner.merged_count
	host.innovation_counter = maxf(host.innovation_counter, joiner.innovation_counter)
	host_cell.carrying_capacity = minf(host_cell.carrying_capacity_max * 1.25, host_cell.carrying_capacity + 20.0)

	var host_perim: Dictionary = {}
	for nid in EvoTypes.urban_perimeter_hex_ids(host, state):
		host_perim[nid] = true
	for u_hid in joiner.urban_hex_ids:
		var u_cell: EvoTypes.HexCell = state.cells[u_hid]
		u_cell.deme_ids.erase(joiner.id)
		if host_perim.has(u_hid):
			u_cell.owner_deme_id = host.id
			u_cell.land_use = "pasture" if u_cell.biome in ["arid_steppe", "tundra"] else "crops"
		else:
			u_cell.owner_deme_id = ""
			u_cell.land_use = "wild"
	for field in joiner_fields:
		if host_perim.has(field.id):
			field.owner_deme_id = host.id
		else:
			field.owner_deme_id = ""
			field.land_use = "wild"

	_merge_traits_and_relations(host, joiner, state)
	state.demes.erase(joiner.id)
	mark_lineage_if_extinct(state, joiner_lineage)

	EvoTypes.push_event(state, "absorption", joiner_cell.id, host_cell.id, host.id, joiner.id, float(joiner_pop), 0)
	_push_flow(state, joiner_cell.id, host_cell.id, "merge", 0.85, host.id, host.id)
	host.last_outcome = "%s united into your city (%d people)." % [joiner_name, host.population]
	EvoRelations.remember(host, state, "%s joined your settlement (%d people)." % [joiner_name, host.population])
	_chronicle(state, "chronicle-merge-%d-%s-%s" % [state.generation, host.id, joiner.id], "merge",
		EvoI18n.t(lang, "chronicle_merge_title", params), EvoI18n.t(lang, "chronicle_merge_desc", params), host_cell.id, host)


static func remove_extinct(state: EvoTypes.WorldState, lang: String) -> void:
	var is_en := lang == "en"
	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if deme.population >= EvoPayoffs.MIN_VIABLE_POP:
			continue
		for field in EvoRuralHinterland.owned_hexes(deme, state):
			field.owner_deme_id = ""
			field.land_use = "wild"
			field.has_ruins = true
			field.ruin_turns = 3
		for hid in deme.urban_hex_ids:
			var ucell: EvoTypes.HexCell = state.cells[hid]
			ucell.deme_ids.erase(deme.id)
			if deme.population > 0 and ucell.biome != "ocean":
				ucell.has_ruins = true
				ucell.ruin_turns = 3
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


static func _lineage_anchor_hex(lineage_id: String, state: EvoTypes.WorldState) -> String:
	var founder_hex := (state.lineage_tree[lineage_id] as EvoTypes.LineageNode).founder_hex_id
	if state.cells.has(founder_hex):
		for oid in (state.cells[founder_hex] as EvoTypes.HexCell).deme_ids:
			if state.demes.has(oid) and (state.demes[oid] as EvoTypes.Deme).lineage_id == lineage_id:
				return founder_hex
	var anchor_deme: EvoTypes.Deme = null
	for d: EvoTypes.Deme in state.demes.values():
		if d.lineage_id != lineage_id:
			continue
		var is_root := strip_migration_suffix(d.id) == d.id
		if anchor_deme == null:
			anchor_deme = d
		else:
			var prev_root := strip_migration_suffix(anchor_deme.id) == anchor_deme.id
			if (is_root and not prev_root) or (is_root == prev_root and d.id < anchor_deme.id):
				anchor_deme = d
	return anchor_deme.hex_id if anchor_deme != null else founder_hex


static func _reachable_landmass(anchor_hex_id: String, mobility: float, state: EvoTypes.WorldState) -> Dictionary:
	if not state.cells.has(anchor_hex_id):
		return {}
	var visited: Dictionary = {anchor_hex_id: true}
	var queue: Array[String] = [anchor_hex_id]
	var head := 0
	while head < queue.size():
		var cur_cell: EvoTypes.HexCell = state.cells[queue[head]]
		head += 1
		for nid in HexMath.get_neighbor_ids(cur_cell.q, cur_cell.r, state.cells):
			var ncell: EvoTypes.HexCell = state.cells[nid]
			if visited.has(nid) or not EvoActionMenu.is_passable_for(ncell, mobility):
				continue
			visited[nid] = true
			queue.append(nid)
	return visited


static func update_isolation(state: EvoTypes.WorldState) -> void:
	var anchors: Dictionary = {}
	var landmass_cache: Dictionary = {}
	for d: EvoTypes.Deme in state.demes.values():
		if not anchors.has(d.lineage_id):
			anchors[d.lineage_id] = _lineage_anchor_hex(d.lineage_id, state)
		var anchor_hex := str(anchors[d.lineage_id])
		var mobility := EvoPayoffs.vector(d, state).spatial_mobility
		var cache_key := "%s|%d" % [anchor_hex, 1 if mobility >= 0.45 else 0]
		if not landmass_cache.has(cache_key):
			landmass_cache[cache_key] = _reachable_landmass(anchor_hex, mobility, state)
		var reachable: Dictionary = landmass_cache[cache_key]
		if d.hex_id == anchor_hex or reachable.has(d.hex_id):
			d.isolation_turns = 0
		else:
			d.isolation_turns += 1


## Ensures every multi-hex settlement's `urban_hex_ids` remain contiguous; if a middle
## district was conquered or submerged, splits disconnected components cleanly.
static func revalidate_walled_unions(state: EvoTypes.WorldState) -> void:
	for did in state.demes.keys():
		if not state.demes.has(did):
			continue
		var d: EvoTypes.Deme = state.demes[did]
		if d.urban_hex_ids.size() <= 1:
			continue
		var urban_set: Dictionary = {}
		for hid in d.urban_hex_ids:
			urban_set[hid] = true
		var connected: Dictionary = {d.urban_hex_ids[0]: true}
		var queue: Array[String] = [d.urban_hex_ids[0]]
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			var cc: EvoTypes.HexCell = state.cells[cur]
			for nid in HexMath.get_neighbor_ids(cc.q, cc.r, state.cells):
				if urban_set.has(nid) and not connected.has(nid):
					connected[nid] = true
					queue.append(nid)
		if connected.size() == d.urban_hex_ids.size():
			continue
		var main_ids: Array[String] = []
		var detached_ids: Array[String] = []
		for hid in d.urban_hex_ids:
			if connected.has(hid):
				main_ids.append(hid)
			else:
				detached_ids.append(hid)
		var total_hexes := d.urban_hex_ids.size()
		d.urban_hex_ids = main_ids
		d.hex_id = main_ids[0]
		for det_hid in detached_ids:
			var det_cell: EvoTypes.HexCell = state.cells[det_hid]
			det_cell.deme_ids.erase(d.id)
			var split_pop := maxi(EvoPayoffs.MIN_VIABLE_POP, d.population / total_hexes)
			if d.population - split_pop < EvoPayoffs.MIN_VIABLE_POP:
				continue
			var split_food := d.energy_reserves * (float(split_pop) / float(d.population))
			var sister := _new_daughter(d, "m", det_cell, state)
			sister.population = split_pop
			sister.energy_reserves = split_food
			sister.defense_tier = d.defense_tier
			d.population -= split_pop
			d.energy_reserves -= split_food
			var rel := EvoTypes.get_relation(state, d.id, sister.id)
			rel.pact_turns = 3
			rel.trust = 0.6


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
	var from_hex := closest_urban_hex_to(a, b, state)
	var to_hex := closest_urban_hex_to(b, a, state)
	_push_flow(state, from_hex, to_hex, flow_type, intensity, a.id, b.id)


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
