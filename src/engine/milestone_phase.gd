class_name EvoMilestonePhase
extends RefCounted

const CULTURAL_ARCHETYPES: Array[Dictionary] = [
	{
		"id": "agrarian",
		"en": "Agrarian Terrace Tradition",
		"es": "Tradición de Terrazas Agrarias",
		"vec": [0.08, 0.34, 0.12, 0.08, 0.16, 0.32]
	},
	{
		"id": "wayfinder",
		"en": "Wayfinder Navigation",
		"es": "Navegación de Pioneros",
		"vec": [0.08, 0.18, 0.08, 0.38, 0.14, 0.30]
	},
	{
		"id": "masonry",
		"en": "Fortified Masonry",
		"es": "Mampostería Fortificada",
		"vec": [0.07, 0.20, 0.16, 0.06, 0.34, 0.34]
	},
	{
		"id": "mercantile",
		"en": "Mercantile Guild Charter",
		"es": "Fuero de Gremios Mercantiles",
		"vec": [0.06, 0.24, 0.10, 0.24, 0.28, 0.28]
	},
	{
		"id": "martial",
		"en": "Martial Vanguard Code",
		"es": "Código de Vanguardia Marcial",
		"vec": [0.14, 0.26, -0.08, 0.34, 0.22, 0.30]
	},
	{
		"id": "agroforestry",
		"en": "Communal Agroforestry",
		"es": "Agroforestería Comunal",
		"vec": [0.05, 0.24, 0.30, 0.08, 0.28, 0.32]
	}
]


static func _slugify(text: String) -> String:
	var lower := text.to_lower()
	var out := ""
	var prev_dash := false
	for i in range(lower.length()):
		var ch := lower[i]
		var is_alnum := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		if is_alnum:
			out += ch
			prev_dash = false
		elif not prev_dash and out.length() > 0:
			out += "-"
			prev_dash = true
	out = out.trim_suffix("-")
	if out.length() > 28:
		out = out.substr(0, 28).trim_suffix("-")
	return out if out.length() > 0 else "adaptation"


static func count_emergent_cultural_traits(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> int:
	var count := 0
	for tid in deme.cultural_trait_ids:
		if state.traits_catalog.has(tid) and (state.traits_catalog[tid] as EvoTypes.TraitDef).origin == "emergent":
			count += 1
	return count


static func _bc(deme: EvoTypes.Deme, key: String) -> int:
	return int(deme.baldwin_counters[key]) if deme.baldwin_counters.has(key) else 0


static func _select_cultural_archetype(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> Dictionary:
	var owned_names_lower: Array[String] = []
	for tid in deme.cultural_trait_ids:
		if state.traits_catalog.has(tid):
			owned_names_lower.append((state.traits_catalog[tid] as EvoTypes.TraitDef).name.to_lower())

	var scores: Dictionary = {
		"agrarian": float(_bc(deme, "intensify") + _bc(deme, "innovate")) + (2.5 if deme.strategy_id == "strat-innovation" else 0.0),
		"wayfinder": float(_bc(deme, "settle") * 2) + (3.0 if deme.strategy_id == "strat-expansion" or cell.biome == "coastal_shallows" else 0.0),
		"masonry": float(_bc(deme, "fortify") * 2 + deme.defense_tier * 2) + (1.5 if deme.biological_trait_ids.has("bio-k-strategy") else 0.0),
		"mercantile": float(_bc(deme, "trade") * 2) + (3.0 if deme.strategy_id == "strat-trade" or deme.cultural_trait_ids.has("cul-interdeme-barter") else 0.0),
		"martial": float(_bc(deme, "raid") + _bc(deme, "conquer") * 2 + _bc(deme, "demand_tribute") + _bc(deme, "betray")) + (3.0 if deme.strategy_id == "strat-war" or deme.cultural_trait_ids.has("cul-warrior-expansion") else 0.0),
		"agroforestry": float(_bc(deme, "aid") + _bc(deme, "offer_pact") + _bc(deme, "accept_pact") + _bc(deme, "unite")) + (3.0 if deme.strategy_id == "strat-cooperation" or deme.cultural_trait_ids.has("cul-communal-conservation") else 0.5)
	}

	var best_arch: Dictionary = CULTURAL_ARCHETYPES[0]
	var best_score := -9999.0
	for arch in CULTURAL_ARCHETYPES:
		var aid := str(arch["id"])
		var en_lower := str(arch["en"]).to_lower()
		var es_lower := str(arch["es"]).to_lower()
		var already_owned := false
		for oname in owned_names_lower:
			if oname.begins_with(en_lower) or oname.begins_with(es_lower):
				already_owned = true
				break
		var s := float(scores[aid]) - (100.0 if already_owned else 0.0)
		if s > best_score:
			best_score = s
			best_arch = arch
	return best_arch


static func synthesize_milestone_trait(
	state: EvoTypes.WorldState,
	deme: EvoTypes.Deme,
	trigger_type: String,
	lang: String = "es"
) -> EvoTypes.TraitDef:
	var is_en := lang == "en"
	var category := "cultural" if trigger_type == "cultural_innovation" else "biological"
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id] if state.cells.has(deme.hex_id) else EvoTypes.HexCell.new()
	var biome_label := EvoI18n.biome_name(lang, cell.biome)

	var base_name := ""
	var raw_vec: EvoTypes.BiophysicalVector
	var baldwin_dec_id := str(deme.get_meta("baldwin_decision_id", "")) if deme.has_meta("baldwin_decision_id") else ""
	if baldwin_dec_id == "":
		baldwin_dec_id = str(deme.chosen_action["type"])

	if category == "cultural":
		var arch := _select_cultural_archetype(deme, cell, state)
		base_name = str(arch["en"]) if is_en else str(arch["es"])
		var v_arr: Array = arch["vec"]
		raw_vec = EvoTypes.BiophysicalVector.new(
			float(v_arr[0]),
			float(v_arr[1]),
			float(v_arr[2]),
			float(v_arr[3]),
			float(v_arr[4]),
			float(v_arr[5])
		)
	elif trigger_type == "allopatric_speciation":
		base_name = "Allopatric Divergence" if is_en else "Divergencia Alopátrica"
		raw_vec = EvoTypes.BiophysicalVector.new(0.18, 0.35, 0.10, 0.30, 0.20, 0.20)
	else:
		base_name = "Adaptive Homeostasis" if is_en else "Homeostasis Adaptativa"
		if baldwin_dec_id != "" and state.decisions_catalog.has(baldwin_dec_id):
			var dom_dec: EvoTypes.DecisionDef = state.decisions_catalog[baldwin_dec_id]
			var dv := dom_dec.vector
			raw_vec = EvoTypes.BiophysicalVector.new(
				maxf(0.10, dv.metabolic_cost * 0.70),
				clampf(maxf(0.15, dv.extraction_efficiency * 0.80), 0.0, 0.85),
				clampf(dv.ecological_impact * 0.60, -0.50, 0.50),
				clampf(maxf(0.10, dv.spatial_mobility * 0.80), 0.0, 0.85),
				clampf(maxf(0.10, dv.social_cohesion * 0.80), 0.0, 0.85),
				clampf(maxf(0.20, dv.transmission_threshold * 0.80), 0.10, 0.85)
			)
		else:
			raw_vec = EvoTypes.BiophysicalVector.new(0.18, 0.35, 0.10, 0.30, 0.20, 0.20)

	var candidate_name := "%s (%s)" % [base_name, biome_label]
	if candidate_name.length() > 60:
		candidate_name = candidate_name.substr(0, 60)

	var existing_names: Dictionary = {}
	for tid in state.traits_catalog.keys():
		var t: EvoTypes.TraitDef = state.traits_catalog[tid]
		existing_names[t.name.to_lower()] = true

	var final_name := candidate_name
	var suffix := 2
	while existing_names.has(final_name.to_lower()):
		var suffix_str := " #%d" % suffix
		final_name = candidate_name.substr(0, maxi(1, 60 - suffix_str.length())) + suffix_str
		suffix += 1

	var balanced_vec := EvoThermodynamics.validate_and_balance_thermodynamics(raw_vec, false)

	var slug := _slugify(final_name)
	var sanitized_deme := _slugify(deme.id)
	var base_id := "emergent-%d-%s" % [state.generation, slug]
	var trait_id := base_id if not state.traits_catalog.has(base_id) else "%s-%s" % [base_id, sanitized_deme]
	var id_suffix := 2
	while state.traits_catalog.has(trait_id):
		trait_id = "%s-%s-%d" % [base_id, sanitized_deme, id_suffix]
		id_suffix += 1

	var dom_name := baldwin_dec_id if trigger_type == "baldwin_assimilation" else str(deme.chosen_action["type"])
	if state.decisions_catalog.has(dom_name):
		dom_name = EvoI18n.decision_name(lang, state.decisions_catalog[dom_name])

	var desc := (
		"Emergent adaptation consolidating sustained behavioral selection in %s (%s)." % [biome_label, dom_name]
		if is_en
		else "Adaptación emergente que consolida la selección conductual sostenida en %s (%s)." % [biome_label, dom_name]
	)

	var trait_def := EvoTypes.TraitDef.new()
	trait_def.id = trait_id
	trait_def.name = final_name
	trait_def.category = category
	trait_def.origin = "emergent"
	trait_def.description = desc
	trait_def.vector = balanced_vec
	trait_def.mutually_exclusive_with = []
	trait_def.enables_cultural_transmission = false
	return trait_def


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
		var action_type := str(deme.chosen_action["type"])

		var emergent_bio_count: int = 0
		for tid in deme.biological_trait_ids:
			if state.traits_catalog.has(tid) and (state.traits_catalog[tid] as EvoTypes.TraitDef).origin == "emergent":
				emergent_bio_count += 1

		var emergent_cul_count := count_emergent_cultural_traits(deme, state)

		if deme.isolation_turns >= 10 and emergent_bio_count < 3:
			var founder_lineage: EvoTypes.LineageNode = state.lineage_tree[deme.lineage_id] if state.lineage_tree.has(deme.lineage_id) else null
			var founder_cell: EvoTypes.HexCell = (
				state.cells[founder_lineage.founder_hex_id]
				if (founder_lineage != null and state.cells.has(founder_lineage.founder_hex_id))
				else null
			)
			var separated_from_founder := founder_cell == null or not deme.urban_hex_ids.has(founder_cell.id)
			if separated_from_founder:
				candidates.append({
					"priority": 0,
					"trigger_type": "allopatric_speciation",
					"deme_id": deme.id,
					"decision_id": action_type
				})

		var triggered_baldwin_dec := ""
		for dec_id in deme.baldwin_counters.keys():
			var cnt: int = int(deme.baldwin_counters[dec_id])
			if str(dec_id) != "forage" and cnt >= 8:
				triggered_baldwin_dec = str(dec_id)
				break

		if triggered_baldwin_dec != "" and emergent_bio_count < 3:
			candidates.append({
				"priority": 1,
				"trigger_type": "baldwin_assimilation",
				"deme_id": deme.id,
				"decision_id": triggered_baldwin_dec
			})

		if deme.innovation_counter >= 1.0 and EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog) and emergent_cul_count < EvoActionMenu.MAX_EMERGENT_CULTURAL and (deme.last_energy_delta >= 0.0 or deme.energy_reserves >= 35.0):
			candidates.append({
				"priority": 2,
				"trigger_type": "cultural_innovation",
				"deme_id": deme.id,
				"decision_id": action_type
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
			var new_trait := synthesize_milestone_trait(state, deme, trigger_type, lang)
			state.traits_catalog[new_trait.id] = new_trait

			if new_trait.category == "biological":
				if not deme.biological_trait_ids.has(new_trait.id):
					deme.biological_trait_ids.append(new_trait.id)
			else:
				if not deme.cultural_trait_ids.has(new_trait.id):
					deme.cultural_trait_ids.append(new_trait.id)
			EvoRelations.remember(deme, state, "Unlocked %s!" % new_trait.name)

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
				var slug := _slugify(new_trait.name)
				var san_deme := _slugify(deme.id)
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
	var survivor_root_id := EvoSettlementPhase.strip_migration_suffix(survivor.id)

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
			var e_root_id := EvoSettlementPhase.strip_migration_suffix(e.deme_id)
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
