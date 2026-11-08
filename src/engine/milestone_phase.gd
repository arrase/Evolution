class_name EvoMilestonePhase
extends RefCounted


static func _compute_set_divergence(set_a: Dictionary, set_b: Dictionary) -> float:
	var union_set: Dictionary = set_a.duplicate()
	for k in set_b.keys():
		union_set[k] = true
	if union_set.is_empty():
		return 0.0
	var inter: int = 0
	for k in set_a.keys():
		if set_b.has(k):
			inter += 1
	return snappedf(1.0 - float(inter) / float(union_set.size()), 0.0001)


static func _select_distinct_color(current_color: String, lineage_tree: Dictionary) -> String:
	var used: Dictionary = {}
	for lid in lineage_tree.keys():
		var node: EvoTypes.LineageNode = lineage_tree[lid]
		used[node.color.to_upper()] = true

	for candidate in EvoTypes.SPECIATION_PALETTE:
		var up := candidate.to_upper()
		if up != current_color.to_upper() and not used.has(up):
			return candidate

	for candidate in EvoTypes.SPECIATION_PALETTE:
		if candidate.to_upper() != current_color.to_upper():
			return candidate

	return "#3D85C6"


static func _get_root_lineage_id(lid: String, lineage_tree: Dictionary) -> String:
	var cur := lid
	var visited: Dictionary = {cur: true}
	var steps := 0
	while lineage_tree.has(cur) and steps < 64:
		var p_id := (lineage_tree[cur] as EvoTypes.LineageNode).parent_id
		if p_id == "" or not lineage_tree.has(p_id) or visited.has(p_id):
			break
		visited[p_id] = true
		cur = p_id
		steps += 1
	return cur


static func run_milestone_phase(
	state: EvoTypes.WorldState,
	lang: String = "es"
) -> Array[EvoTypes.ChronicleEntry]:
	var added_entries: Array[EvoTypes.ChronicleEntry] = []
	var is_en := lang == "en"

	var candidates: Array[Dictionary] = []

	for did in state.demes.keys():
		var deme: EvoTypes.Deme = state.demes[did]
		if not state.cells.has(deme.hex_id):
			continue
		var cell: EvoTypes.HexCell = state.cells[deme.hex_id]

		var emergent_bio_count: int = 0
		for tid in deme.biological_trait_ids:
			if state.traits_catalog.has(tid) and (state.traits_catalog[tid] as EvoTypes.TraitDef).origin == "emergent":
				emergent_bio_count += 1

		var emergent_cul_count: int = 0
		for tid in deme.cultural_trait_ids:
			if state.traits_catalog.has(tid) and (state.traits_catalog[tid] as EvoTypes.TraitDef).origin == "emergent":
				emergent_cul_count += 1

		if deme.isolation_turns >= 10 and emergent_bio_count < 3:
			var founder_lineage: EvoTypes.LineageNode = state.lineage_tree[deme.lineage_id] if state.lineage_tree.has(deme.lineage_id) else null
			var founder_traits: Dictionary = {}
			if founder_lineage != null:
				for tid in founder_lineage.acquired_trait_ids:
					if not state.traits_catalog.has(tid) or (state.traits_catalog[tid] as EvoTypes.TraitDef).category == "biological":
						founder_traits[tid] = true

			var deme_traits: Dictionary = {}
			var has_novel_bio := false
			for tid in deme.biological_trait_ids:
				deme_traits[tid] = true
				if not founder_traits.has(tid):
					has_novel_bio = true

			var div_from_founder := _compute_set_divergence(deme_traits, founder_traits)
			var founder_cell: EvoTypes.HexCell = (
				state.cells[founder_lineage.founder_hex_id]
				if (founder_lineage != null and state.cells.has(founder_lineage.founder_hex_id))
				else null
			)
			var in_distinct_biome := founder_cell != null and founder_cell.biome != cell.biome
			var separated_from_founder := (
				founder_cell == null
				or founder_cell.id != cell.id
				or (state.generation == 0 and emergent_bio_count == 0 and div_from_founder >= 0.70)
			)

			if separated_from_founder and (has_novel_bio or div_from_founder >= 0.30 or in_distinct_biome):
				candidates.append({
					"priority": 0,
					"trigger_type": "allopatric_speciation",
					"deme_id": deme.id,
					"decision_id": deme.last_dominant_decision_id
				})

		var triggered_baldwin_dec := ""
		for dec_id in deme.baldwin_counters.keys():
			var cnt: int = int(deme.baldwin_counters[dec_id])
			var prob: float = float(deme.last_decision_probabilities[dec_id]) if deme.last_decision_probabilities.has(dec_id) else 0.0
			if dec_id != "dec-conservative-forage" and cnt >= 8 and (prob >= 0.35 or deme.last_dominant_decision_id == dec_id):
				triggered_baldwin_dec = str(dec_id)
				break

		if triggered_baldwin_dec != "" and emergent_bio_count < 3:
			candidates.append({
				"priority": 1,
				"trigger_type": "baldwin_assimilation",
				"deme_id": deme.id,
				"decision_id": triggered_baldwin_dec
			})

		if deme.innovation_counter >= 1.0 and EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog) and emergent_cul_count < 2 and deme.last_energy_delta >= 0.0:
			candidates.append({
				"priority": 2,
				"trigger_type": "cultural_innovation",
				"deme_id": deme.id,
				"decision_id": deme.last_dominant_decision_id
			})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) < int(b["priority"])
	)

	if not candidates.is_empty():
		var top: Dictionary = candidates[0]
		var target_id := str(top["deme_id"])
		var trigger_type := str(top["trigger_type"])
		var dec_id := str(top["decision_id"])

		if state.demes.has(target_id):
			var deme: EvoTypes.Deme = state.demes[target_id]
			deme.set_meta("baldwin_decision_id", dec_id)
			var new_trait := EvoDecisionModel.synthesize_milestone_trait(state, deme, trigger_type, lang)
			state.traits_catalog[new_trait.id] = new_trait

			if new_trait.category == "biological":
				if not deme.biological_trait_ids.has(new_trait.id):
					deme.biological_trait_ids.append(new_trait.id)
			else:
				if not deme.cultural_trait_ids.has(new_trait.id):
					deme.cultural_trait_ids.append(new_trait.id)

			var ancestor_hex_id := deme.hex_id
			if trigger_type == "baldwin_assimilation":
				deme.baldwin_counters[dec_id] = 0
				if state.lineage_tree.has(deme.lineage_id):
					var lin_b: EvoTypes.LineageNode = state.lineage_tree[deme.lineage_id]
					lin_b.biological_trait_ids = deme.biological_trait_ids.duplicate()
					lin_b.cultural_trait_ids = deme.cultural_trait_ids.duplicate()
					if not lin_b.acquired_trait_ids.has(new_trait.id):
						lin_b.acquired_trait_ids.append(new_trait.id)
			elif trigger_type == "cultural_innovation":
				deme.innovation_counter = maxf(0.0, snappedf(deme.innovation_counter - 1.0, 0.0001))
				if state.lineage_tree.has(deme.lineage_id):
					var lin_c: EvoTypes.LineageNode = state.lineage_tree[deme.lineage_id]
					lin_c.biological_trait_ids = deme.biological_trait_ids.duplicate()
					lin_c.cultural_trait_ids = deme.cultural_trait_ids.duplicate()
					if not lin_c.acquired_trait_ids.has(new_trait.id):
						lin_c.acquired_trait_ids.append(new_trait.id)
			elif trigger_type == "allopatric_speciation":
				var old_lineage_id := deme.lineage_id
				ancestor_hex_id = (state.lineage_tree[old_lineage_id] as EvoTypes.LineageNode).founder_hex_id if state.lineage_tree.has(old_lineage_id) else deme.hex_id
				deme.isolation_turns = 0
				var slug := EvoDecisionModel._slugify(new_trait.name)
				var san_deme := EvoDecisionModel._slugify(deme.id)
				var base_lin_id := "lineage-%d-%s" % [state.generation, slug]
				var new_lin_id := base_lin_id if not state.lineage_tree.has(base_lin_id) else "%s-%s" % [base_lin_id, san_deme]
				var l_suf := 2
				while state.lineage_tree.has(new_lin_id):
					new_lin_id = "%s-%s-%d" % [base_lin_id, san_deme, l_suf]
					l_suf += 1

				var next_color := _select_distinct_color(deme.color, state.lineage_tree)
				var new_node := EvoTypes.LineageNode.new()
				new_node.id = new_lin_id
				new_node.parent_id = old_lineage_id
				new_node.name = new_trait.name
				new_node.strategy_id = deme.strategy_id
				new_node.color = next_color
				new_node.founded_generation = state.generation
				new_node.extinct_generation = -1
				new_node.founder_hex_id = deme.hex_id
				new_node.divergence_reason = "allopatric_speciation"
				new_node.biological_trait_ids = deme.biological_trait_ids.duplicate()
				new_node.cultural_trait_ids = deme.cultural_trait_ids.duplicate()
				var acq: Array[String] = []
				for tid in deme.biological_trait_ids:
					if not acq.has(tid):
						acq.append(tid)
				for tid in deme.cultural_trait_ids:
					if not acq.has(tid):
						acq.append(tid)
				new_node.acquired_trait_ids = acq

				state.lineage_tree[new_lin_id] = new_node
				deme.lineage_id = new_lin_id
				deme.color = next_color

				if state.lineage_tree.has(old_lineage_id):
					var any_old := false
					for odid in state.demes.keys():
						if (state.demes[odid] as EvoTypes.Deme).lineage_id == old_lineage_id:
							any_old = true
							break
					if not any_old:
						(state.lineage_tree[old_lineage_id] as EvoTypes.LineageNode).extinct_generation = state.generation

			var chronicle_type := "baldwin_trait" if trigger_type == "baldwin_assimilation" else trigger_type
			EvoTypes.push_event(state, chronicle_type, ancestor_hex_id if chronicle_type == "allopatric_speciation" else deme.hex_id, deme.hex_id, deme.id)
			var entry := EvoTypes.ChronicleEntry.new()
			entry.id = "chronicle-%s-%d-%s" % [chronicle_type, state.generation, deme.id]
			entry.generation = state.generation
			entry.event_type = chronicle_type
			entry.title = "%s: %s" % [deme.name, new_trait.name]
			entry.causal_explanation = new_trait.description
			entry.hex_id = deme.hex_id
			entry.deme_id = deme.id
			entry.lineage_id = deme.lineage_id
			entry.trait_id = new_trait.id
			state.chronicle.append(entry)
			added_entries.append(entry)

	if state.demes.is_empty():
		state.quiet_turns = 0
		state.macro_outcome_type = "total_extinction"
		state.macro_outcome_title = "Total Extinction" if is_en else "Extinción Total"
		state.macro_outcome_summary = (
			"All populations have gone extinct across the ecosystem."
			if is_en
			else "Todas las poblaciones se han extinguido en el ecosistema."
		)
		var already_logged_total := false
		for e in state.chronicle:
			if e.event_type == "total_extinction":
				already_logged_total = true
				break
		if not already_logged_total:
			var ext_entry := EvoTypes.ChronicleEntry.new()
			ext_entry.id = "chronicle-total-extinction-%d" % state.generation
			ext_entry.generation = state.generation
			ext_entry.event_type = "total_extinction"
			ext_entry.title = state.macro_outcome_title
			ext_entry.causal_explanation = state.macro_outcome_summary
			state.chronicle.append(ext_entry)
			added_entries.append(ext_entry)
		state.previous_populations.clear()
		return added_entries

	var living_demes: Array[EvoTypes.Deme] = []
	for did in state.demes.keys():
		living_demes.append(state.demes[did])
	var survivor := living_demes[0]
	var survivor_root_id := EvoDemographyMigration._strip_migration_suffix(survivor.id)

	var ancestor_lineages: Dictionary = {survivor.lineage_id: true}
	var cur_lid := survivor.lineage_id
	var guard := 0
	while state.lineage_tree.has(cur_lid) and guard < 64:
		var p_lid := (state.lineage_tree[cur_lid] as EvoTypes.LineageNode).parent_id
		if p_lid == "" or ancestor_lineages.has(p_lid):
			break
		ancestor_lineages[p_lid] = true
		cur_lid = p_lid
		guard += 1

	var has_prior_extinction := false
	var has_non_migrant_extinction := false
	var already_logged_single := false
	var already_logged_eq := false
	var had_chronicle_this_turn := false

	for e in state.chronicle:
		if e.generation == state.generation:
			had_chronicle_this_turn = true
		if e.event_type == "extinction":
			has_prior_extinction = true
			var e_root_id := EvoDemographyMigration._strip_migration_suffix(e.deme_id)
			if not ancestor_lineages.has(e.lineage_id) or (e_root_id != survivor_root_id and e_root_id == e.deme_id):
				has_non_migrant_extinction = true
		elif e.event_type == "single_survivor":
			already_logged_single = true
		elif e.event_type == "ecological_equilibrium":
			already_logged_eq = true

	var living_lineages: Dictionary = {}
	var living_root_lineages: Dictionary = {}
	var total_pop: int = 0
	for d in living_demes:
		living_lineages[d.lineage_id] = true
		living_root_lineages[_get_root_lineage_id(d.lineage_id, state.lineage_tree)] = true
		total_pop += d.population

	var total_lineages := state.lineage_tree.size()
	var root_all_extinct: Dictionary = {}
	for lid in state.lineage_tree.keys():
		var r_id := _get_root_lineage_id(str(lid), state.lineage_tree)
		if living_root_lineages.has(r_id):
			continue
		if not root_all_extinct.has(r_id):
			root_all_extinct[r_id] = true
		if (state.lineage_tree[lid] as EvoTypes.LineageNode).extinct_generation < 0:
			root_all_extinct[r_id] = false

	var has_extinct_root_lineage := false
	for r_id in root_all_extinct.keys():
		if bool(root_all_extinct[r_id]):
			has_extinct_root_lineage = true
			break

	var is_single_survivor_deme := (
		total_lineages == 1
		and living_demes.size() == 1
		and survivor.merged_count == 0
		and state.generation >= 15
		and has_non_migrant_extinction
	)
	var is_single_surviving_lineage := (
		total_lineages > 1
		and has_extinct_root_lineage
		and living_root_lineages.size() == 1
		and not (living_demes.size() == 1 and survivor.merged_count > 0 and not has_non_migrant_extinction)
	)

	if has_prior_extinction and not already_logged_single and (is_single_survivor_deme or is_single_surviving_lineage):
		state.quiet_turns = 0
		var lin_node: EvoTypes.LineageNode = state.lineage_tree[survivor.lineage_id] if state.lineage_tree.has(survivor.lineage_id) else null
		var display_name := survivor.name if (living_demes.size() == 1 or lin_node == null) else lin_node.name
		var title_str := ("Evolutionary Hegemony: %s" if is_en else "Hegemonía Evolutiva: %s") % display_name
		var body_str := (
			"After competitive and environmental extinctions eliminated rival populations, %s (%d individuals) remains as the sole surviving lineage." % [display_name, total_pop]
			if is_en
			else "Tras la extinción competitiva y ambiental de las demás poblaciones, %s (%d individuos) prevalece como único superviviente." % [display_name, total_pop]
		)
		state.macro_outcome_type = "single_survivor"
		state.macro_outcome_title = title_str
		state.macro_outcome_summary = body_str

		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-single-survivor-%d-%s" % [state.generation, survivor.id]
		entry.generation = state.generation
		entry.event_type = "single_survivor"
		entry.title = title_str
		entry.causal_explanation = body_str
		entry.hex_id = survivor.hex_id
		entry.deme_id = survivor.id
		entry.lineage_id = survivor.lineage_id
		state.chronicle.append(entry)
		added_entries.append(entry)
	else:
		var had_migration := false
		for fl in state.active_flows:
			if fl.flow_type == "migration":
				had_migration = true
				break

		var same_deme_set := state.previous_populations.size() == living_demes.size()
		if same_deme_set:
			for d in living_demes:
				if not state.previous_populations.has(d.id):
					same_deme_set = false
					break

		var populations_stable := same_deme_set
		if populations_stable:
			for d in living_demes:
				var prev_p: int = int(state.previous_populations[d.id])
				if prev_p <= 0 or absf(float(d.population - prev_p)) / float(prev_p) > 0.05:
					populations_stable = false
					break

		if not had_migration and not had_chronicle_this_turn and populations_stable:
			state.quiet_turns += 1
		else:
			state.quiet_turns = 0

		if state.generation >= 30 and state.quiet_turns >= 8 and not already_logged_eq and not already_logged_single:
			var eq_title := "Ecological & Demographic Equilibrium Reached" if is_en else "Equilibrio Ecológico y Demográfico Alcanzado"
			var eq_body := (
				"Across 8 consecutive generations (4 full seasonal cycles), %d active subpopulations (%d total individuals) stabilized in dynamic equilibrium with local carrying capacity." % [living_demes.size(), total_pop]
				if is_en
				else "Durante 8 generaciones consecutivas (4 ciclos estacionales completos), %d subpoblaciones activas (%d individuos en total) se estabilizaron en equilibrio dinámico con la capacidad de carga local." % [living_demes.size(), total_pop]
			)
			state.macro_outcome_type = "ecological_equilibrium"
			state.macro_outcome_title = eq_title
			state.macro_outcome_summary = eq_body

			var entry := EvoTypes.ChronicleEntry.new()
			entry.id = "chronicle-equilibrium-%d-%s" % [state.generation, survivor.id]
			entry.generation = state.generation
			entry.event_type = "ecological_equilibrium"
			entry.title = eq_title
			entry.causal_explanation = eq_body
			entry.hex_id = survivor.hex_id
			entry.deme_id = survivor.id
			entry.lineage_id = survivor.lineage_id
			state.chronicle.append(entry)
			added_entries.append(entry)

	state.previous_populations.clear()
	for d in living_demes:
		state.previous_populations[d.id] = d.population

	return added_entries
