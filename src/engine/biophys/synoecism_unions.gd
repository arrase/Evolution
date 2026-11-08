class_name EvoSynoecismUnions
extends RefCounted


static func run_synoecism_phase(
	state: EvoTypes.WorldState,
	lang: String,
	newly_created_demes: Dictionary,
	had_lineage_contact: Dictionary,
	rival_dist_cache: Dictionary = {}
) -> void:
	var candidate_union_pairs: Array[Array] = []
	var seen_union_pair_keys: Dictionary = {}
	for did in state.demes.keys():
		var d1: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(d1.hex_id):
			continue
		var c1: EvoTypes.HexCell = state.cells[d1.hex_id]
		if c1.biome == "ocean" or c1.altitude > 0.85:
			continue
		for nid in HexMath.get_neighbor_ids(c1.q, c1.r, state.cells):
			var c2: EvoTypes.HexCell = state.cells[nid]
			if c2.biome == "ocean" or c2.altitude > 0.85 or c2.deme_ids.is_empty():
				continue
			var id_2 := c2.deme_ids[0]
			if id_2 == d1.id or not state.demes.has(id_2):
				continue
			var pk := EvoTypes.make_pair_key(d1.id, id_2)
			if seen_union_pair_keys.has(pk):
				continue
			seen_union_pair_keys[pk] = true
			candidate_union_pairs.append([d1.id, id_2, pk])

	for pair_info in candidate_union_pairs:
		var id_1 := str(pair_info[0])
		var id_2 := str(pair_info[1])
		var pk := str(pair_info[2])
		if not state.demes.has(id_1) or not state.demes.has(id_2):
			continue
		var d1: EvoTypes.Deme = state.demes[id_1]
		var d2: EvoTypes.Deme = state.demes[id_2]
		if not state.cells.has(d1.hex_id) or not state.cells.has(d2.hex_id):
			continue
		var c1: EvoTypes.HexCell = state.cells[d1.hex_id]
		var c2: EvoTypes.HexCell = state.cells[d2.hex_id]
		if c1.biome == "ocean" or c1.altitude > 0.85 or c2.biome == "ocean" or c2.altitude > 0.85:
			continue
		if HexMath.hex_distance(c1.q, c1.r, c2.q, c2.r) != 1:
			continue
		if d1.population < 25 or d2.population < 25 or newly_created_demes.has(d1.id) or newly_created_demes.has(d2.id):
			continue

		var pact_val := int(state.active_pacts.get(pk, 0))
		var qualifies := false
		if pact_val >= 3:
			var has_threat_or_fort := d1.defense_tier >= 1 or d2.defense_tier >= 1
			if not has_threat_or_fort:
				for c_chk in [c1, c2]:
					for nid in HexMath.get_neighbor_ids(c_chk.q, c_chk.r, state.cells):
						var ncell: EvoTypes.HexCell = state.cells[nid]
						for oid in ncell.deme_ids:
							if state.demes.has(oid):
								var od: EvoTypes.Deme = state.demes[oid]
								if od.id != d1.id and od.id != d2.id and od.lineage_id != d1.lineage_id and od.lineage_id != d2.lineage_id and not EvoTypes.is_pact_active(state, d1.id, od.id):
									has_threat_or_fort = true
									break
			if pact_val >= 4 or has_threat_or_fort:
				var p1_coop := (
					EvoEcologyInteraction.get_archetype_prob(d1, state.decisions_catalog, "cooperate")
					+ EvoEcologyInteraction.get_archetype_prob(d1, state.decisions_catalog, "exchange")
				)
				var p2_coop := (
					EvoEcologyInteraction.get_archetype_prob(d2, state.decisions_catalog, "cooperate")
					+ EvoEcologyInteraction.get_archetype_prob(d2, state.decisions_catalog, "exchange")
				)
				if p1_coop >= 0.30 and p2_coop >= 0.30:
					qualifies = true

		var both_besieging_warriors := (
			d1.lineage_id == d2.lineage_id
			and d1.cultural_trait_ids.has("cul-warrior-expansion")
			and EvoDemographyMigration._min_distance_to_rival(c1, d1, state, rival_dist_cache) == 1
			and EvoDemographyMigration._min_distance_to_rival(c2, d2, state, rival_dist_cache) == 1
		)
		if not qualifies and not both_besieging_warriors and d1.lineage_id == d2.lineage_id and pact_val >= 0 and EvoDemographyMigration.compute_deme_divergence(d1, d2) <= 0.25:
			if d1.cultural_trait_ids.has("cul-warrior-expansion") and d1.get_village_tier() == 1 and d2.get_village_tier() == 1 and d1.population + d2.population >= 90 and float(d1.population + d2.population) <= maxf(c1.carrying_capacity_max, c2.carrying_capacity_max) * 1.35:
				qualifies = true
			else:
				var d1_has_empty := false
				for nid in HexMath.get_neighbor_ids(c1.q, c1.r, state.cells):
					var ncell: EvoTypes.HexCell = state.cells[nid]
					if ncell.biome != "ocean" and ncell.altitude <= 0.85 and ncell.deme_ids.is_empty() and ncell.owner_deme_id == "":
						d1_has_empty = true
						break
				var d2_has_empty := false
				for nid in HexMath.get_neighbor_ids(c2.q, c2.r, state.cells):
					var ncell: EvoTypes.HexCell = state.cells[nid]
					if ncell.biome != "ocean" and ncell.altitude <= 0.85 and ncell.deme_ids.is_empty() and ncell.owner_deme_id == "":
						d2_has_empty = true
						break
				if not d1_has_empty or not d2_has_empty:
					qualifies = true

		if not qualifies:
			continue

		if d1.walled_union_id != "" and d1.walled_union_id == d2.walled_union_id:
			var u_flow := EvoTypes.HexEdgeFlow.new()
			u_flow.from_hex_id = c1.id
			u_flow.to_hex_id = c2.id
			u_flow.flow_type = "merge"
			u_flow.intensity = 0.85
			u_flow.from_deme_id = d1.id
			u_flow.to_deme_id = d2.id
			state.active_flows.append(u_flow)
			had_lineage_contact[d1.id] = true
			had_lineage_contact[d2.id] = true
			continue

		var t1 := d1.get_village_tier()
		var t2 := d2.get_village_tier()
		var tier1_warrior_consolidate := (
			t1 == 1 and t2 == 1
			and d1.lineage_id == d2.lineage_id
			and d1.cultural_trait_ids.has("cul-warrior-expansion")
			and d1.population + d2.population >= 90
			and float(d1.population + d2.population) <= maxf(c1.carrying_capacity_max, c2.carrying_capacity_max) * 1.35
		)

		if t1 != t2 or tier1_warrior_consolidate:
			if float(d1.population + d2.population) > maxf(c1.carrying_capacity_max, c2.carrying_capacity_max) * 1.45:
				continue
			var d1_hosts := (d1.population >= d2.population) if t1 == t2 else (t1 > t2)
			if d1.lineage_id == d2.lineage_id and d1.cultural_trait_ids.has("cul-warrior-expansion"):
				var dist_1 := EvoDemographyMigration._min_distance_to_rival(c1, d1, state, rival_dist_cache)
				var dist_2 := EvoDemographyMigration._min_distance_to_rival(c2, d2, state, rival_dist_cache)
				if dist_1 != dist_2:
					d1_hosts = dist_1 < dist_2
			var host_deme := d1 if d1_hosts else d2
			var joiner_deme := d2 if d1_hosts else d1
			var host_cell := c1 if d1_hosts else c2
			var joiner_cell := c2 if d1_hosts else c1
			var joiner_id := joiner_deme.id
			_merge_deme_into(
				state,
				host_deme,
				joiner_deme,
				host_cell,
				newly_created_demes,
				had_lineage_contact,
				true,
				lang
			)
			joiner_cell.owner_deme_id = host_deme.id
			joiner_cell.has_ruins = false
			joiner_cell.land_use = "pasture" if joiner_cell.biome in ["arid_steppe", "tundra"] else "crops"
			for rcid in HexMath.get_neighbor_ids(joiner_cell.q, joiner_cell.r, state.cells):
				var r_cell: EvoTypes.HexCell = state.cells[rcid]
				if r_cell.owner_deme_id == joiner_id:
					if HexMath.hex_distance(r_cell.q, r_cell.r, host_cell.q, host_cell.r) == 1:
						r_cell.owner_deme_id = host_deme.id
					else:
						r_cell.owner_deme_id = ""
						r_cell.land_use = "wild"
			var host_tier := host_deme.get_village_tier()
			var host_max_rural: int = EvoRuralHinterland.get_max_rural_quota(host_tier)
			var host_rural: Array[EvoTypes.HexCell] = []
			for rcid in HexMath.get_neighbor_ids(host_cell.q, host_cell.r, state.cells):
				var r_cell: EvoTypes.HexCell = state.cells[rcid]
				if r_cell.owner_deme_id == host_deme.id:
					host_rural.append(r_cell)
			if host_rural.size() > host_max_rural:
				host_rural.sort_custom(func(a: EvoTypes.HexCell, b: EvoTypes.HexCell) -> bool:
					return a.current_resources < b.current_resources
				)
				while host_rural.size() > host_max_rural:
					var rel_cell: EvoTypes.HexCell = host_rural.pop_front()
					rel_cell.owner_deme_id = ""
					rel_cell.land_use = "wild"
		elif t1 >= 2:
			var already_united := d1.walled_union_id != "" and d1.walled_union_id == d2.walled_union_id
			if not already_united:
				var target_union_id := ""
				if d1.walled_union_id == "" and d2.walled_union_id == "":
					var min_id := d1.id if d1.id < d2.id else d2.id
					var max_id := d2.id if d1.id < d2.id else d1.id
					target_union_id = "union-%s-%s" % [min_id, max_id]
				elif d1.walled_union_id != "" and d2.walled_union_id == "":
					var count_1 := 0
					for od_id in state.demes.keys():
						if (state.demes[od_id] as EvoTypes.Deme).walled_union_id == d1.walled_union_id:
							count_1 += 1
					if count_1 < 3:
						target_union_id = d1.walled_union_id
				elif d2.walled_union_id != "" and d1.walled_union_id == "":
					var count_2 := 0
					for od_id in state.demes.keys():
						if (state.demes[od_id] as EvoTypes.Deme).walled_union_id == d2.walled_union_id:
							count_2 += 1
					if count_2 < 3:
						target_union_id = d2.walled_union_id
				if target_union_id != "":
					d1.walled_union_id = target_union_id
					d2.walled_union_id = target_union_id
					d1.defense_tier = maxi(d1.defense_tier, 1)
					d2.defense_tier = maxi(d2.defense_tier, 1)
					EvoTypes.push_event(state, "walled_union", c1.id, c2.id, d1.id, d2.id, 1.0, 0)
					var u_params := {
						"deme_a": d1.name,
						"deme_b": d2.name,
						"hex": "%s <-> %s" % [c1.id, c2.id]
					}
					var u_entry := EvoTypes.ChronicleEntry.new()
					u_entry.id = "chronicle-union-%d-%s" % [state.generation, pk]
					u_entry.generation = state.generation
					u_entry.event_type = "merge"
					u_entry.title = EvoI18n.t(lang, "chronicle_walled_union_title", u_params)
					u_entry.causal_explanation = EvoI18n.t(lang, "chronicle_walled_union_desc", u_params)
					u_entry.hex_id = c1.id
					u_entry.deme_id = d1.id
					u_entry.lineage_id = d1.lineage_id
					state.chronicle.append(u_entry)

			if d1.walled_union_id != "" and d1.walled_union_id == d2.walled_union_id:
				var u_flow := EvoTypes.HexEdgeFlow.new()
				u_flow.from_hex_id = c1.id
				u_flow.to_hex_id = c2.id
				u_flow.flow_type = "merge"
				u_flow.intensity = 0.85
				u_flow.from_deme_id = d1.id
				u_flow.to_deme_id = d2.id
				state.active_flows.append(u_flow)
				had_lineage_contact[d1.id] = true
				had_lineage_contact[d2.id] = true


static func _merge_deme_into(
	state: EvoTypes.WorldState,
	deme_a: EvoTypes.Deme,
	deme_b: EvoTypes.Deme,
	cell_a: EvoTypes.HexCell,
	newly_created_demes: Dictionary,
	had_lineage_contact: Dictionary,
	is_synoecism: bool,
	lang: String
) -> void:
	var old_name_a := deme_a.name
	var old_name_b := deme_b.name
	var from_hex_id := deme_b.hex_id
	var absorbed_pop := deme_b.population
	var total_pop := deme_a.population + deme_b.population
	var a_new := newly_created_demes.has(deme_a.id)
	var b_new := newly_created_demes.has(deme_b.id)
	var w_a := (
		1.0
		if (b_new and not a_new)
		else (0.0 if (a_new and not b_new) else float(deme_a.population) / float(maxi(1, total_pop)))
	)
	var w_b := 1.0 - w_a

	deme_a.innovation_counter = minf(
		2.0,
		snappedf(deme_a.innovation_counter * w_a + deme_b.innovation_counter * w_b, 0.0001)
	)

	var all_keys: Dictionary = {}
	for k in deme_a.baldwin_counters.keys():
		all_keys[k] = true
	for k in deme_b.baldwin_counters.keys():
		all_keys[k] = true
	var merged_counters: Dictionary = {}
	for k in all_keys.keys():
		var ca: int = int(deme_a.baldwin_counters[k]) if deme_a.baldwin_counters.has(k) else 0
		var cb: int = int(deme_b.baldwin_counters[k]) if deme_b.baldwin_counters.has(k) else 0
		merged_counters[k] = int(roundf(float(ca) * w_a + float(cb) * w_b))
	deme_a.baldwin_counters = merged_counters

	deme_a.population = total_pop
	deme_a.energy_reserves = minf(280.0, snappedf(deme_a.energy_reserves + deme_b.energy_reserves, 0.01))
	for tid in deme_b.biological_trait_ids:
		if EvoEcologyInteraction._can_acquire_trait(deme_a, tid, state.traits_catalog):
			deme_a.biological_trait_ids.append(tid)
	for tid in deme_b.cultural_trait_ids:
		if EvoEcologyInteraction._can_acquire_trait(deme_a, tid, state.traits_catalog):
			deme_a.cultural_trait_ids.append(tid)

	if state.lineage_tree.has(deme_a.lineage_id):
		var lin_node: EvoTypes.LineageNode = state.lineage_tree[deme_a.lineage_id]
		for tid in deme_a.biological_trait_ids:
			if not lin_node.biological_trait_ids.has(tid):
				lin_node.biological_trait_ids.append(tid)
		for tid in deme_a.cultural_trait_ids:
			if not lin_node.cultural_trait_ids.has(tid):
				lin_node.cultural_trait_ids.append(tid)

	var combined_tier := maxi(deme_a.defense_tier, deme_b.defense_tier)
	if is_synoecism and deme_a.population >= 90 and combined_tier < 3:
		combined_tier = mini(3, maxi(2, combined_tier + 1))
	deme_a.defense_tier = combined_tier

	if is_synoecism:
		deme_a.merged_count += 1 + deme_b.merged_count
		if deme_b.color != "" and deme_b.color != deme_a.color:
			deme_a.secondary_color = deme_b.color
		elif deme_a.secondary_color == "":
			deme_a.secondary_color = deme_b.secondary_color if deme_b.secondary_color != "" else deme_b.color
		cell_a.carrying_capacity = minf(cell_a.carrying_capacity_max * 1.25, cell_a.carrying_capacity + 20.0)
		var merge_params := {
			"deme_a": old_name_a,
			"deme_b": old_name_b,
			"hex": cell_a.id,
			"pop": str(deme_a.population)
		}
		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-merge-%d-%s-%s" % [state.generation, deme_a.id, deme_b.id]
		entry.generation = state.generation
		entry.event_type = "merge"
		entry.title = EvoI18n.t(lang, "chronicle_merge_title", merge_params)
		entry.causal_explanation = EvoI18n.t(lang, "chronicle_merge_desc", merge_params)
		entry.hex_id = cell_a.id
		entry.deme_id = deme_a.id
		entry.lineage_id = deme_a.lineage_id
		state.chronicle.append(entry)
		EvoTypes.push_event(state, "absorption", from_hex_id, cell_a.id, deme_a.id, deme_b.id, float(absorbed_pop), 0)

	var kept_flows: Array[EvoTypes.HexEdgeFlow] = []
	for fl in state.active_flows:
		if fl.to_deme_id == deme_b.id:
			fl.to_deme_id = deme_a.id
			fl.to_hex_id = cell_a.id
		if fl.from_deme_id == deme_b.id:
			fl.from_deme_id = deme_a.id
			fl.from_hex_id = cell_a.id
		if fl.from_deme_id == fl.to_deme_id and fl.from_hex_id == fl.to_hex_id and not (fl.flow_type in ["migration", "merge"]):
			continue
		kept_flows.append(fl)
	state.active_flows = kept_flows

	if not state.active_pacts.is_empty():
		var pacts_to_erase: Array[String] = []
		var pacts_to_set: Dictionary = {}
		for pk_var in state.active_pacts.keys():
			var pk := str(pk_var)
			if not pk.contains(deme_b.id):
				continue
			var parts := pk.split("__")
			if parts.size() == 2 and (parts[0] == deme_b.id or parts[1] == deme_b.id):
				pacts_to_erase.append(pk)
				var partner_id := parts[1] if parts[0] == deme_b.id else parts[0]
				if partner_id != deme_a.id and not b_new and state.demes.has(partner_id):
					var partner_deme: EvoTypes.Deme = state.demes[partner_id]
					var b_val: int = int(state.active_pacts[pk])
					if b_val > 0 and partner_deme.lineage_id != deme_a.lineage_id and (not is_synoecism or deme_a.cultural_trait_ids.has("cul-warrior-expansion") or partner_deme.cultural_trait_ids.has("cul-warrior-expansion")):
						continue
					var new_pk := EvoTypes.make_pair_key(deme_a.id, partner_id)
					var existing_val: int = int(state.active_pacts[new_pk]) if state.active_pacts.has(new_pk) else 0
					pacts_to_set[new_pk] = maxi(existing_val, b_val)
		for pk in pacts_to_erase:
			state.active_pacts.erase(pk)
		for new_pk in pacts_to_set.keys():
			state.active_pacts[new_pk] = pacts_to_set[new_pk]

	if not b_new and not state.disused_connections.is_empty():
		var kept_disused: Array[Dictionary] = []
		for dc in state.disused_connections:
			if str(dc.get("from_deme_id", "")) == deme_b.id:
				dc["from_deme_id"] = deme_a.id
			if str(dc.get("to_deme_id", "")) == deme_b.id:
				dc["to_deme_id"] = deme_a.id
			if str(dc.get("from_deme_id", "")) == str(dc.get("to_deme_id", "")):
				continue
			kept_disused.append(dc)
		state.disused_connections = kept_disused

	var merge_flow := EvoTypes.HexEdgeFlow.new()
	merge_flow.from_hex_id = from_hex_id
	merge_flow.to_hex_id = cell_a.id
	merge_flow.flow_type = "merge"
	merge_flow.intensity = 0.85 if is_synoecism else 0.65
	merge_flow.from_deme_id = deme_a.id
	merge_flow.to_deme_id = deme_a.id
	state.active_flows.append(merge_flow)

	if state.cells.has(from_hex_id):
		(state.cells[from_hex_id] as EvoTypes.HexCell).deme_ids.erase(deme_b.id)
	cell_a.deme_ids.erase(deme_b.id)
	state.demes.erase(deme_b.id)
	had_lineage_contact[deme_a.id] = true
