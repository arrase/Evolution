class_name EvoSituationReport
extends RefCounted

## Concise, high-signal objective situation report given to `/v1/systemone`.

const DIRECTIONS: Dictionary = {
	Vector2i(1, 0): "E", Vector2i(1, -1): "NE", Vector2i(0, -1): "NW",
	Vector2i(-1, 0): "W", Vector2i(-1, 1): "SW", Vector2i(0, 1): "SE"
}

const TRAIT_EFFECT_NOTES: Dictionary = {
	"bio-r-strategy": "r-Strategy (fast low-density births, early settle at 65 pop & 32 food)",
	"bio-k-strategy": "K-Strategy (resilient high-density growth, -20% wall cost, +salubrity, settle at 145 pop)",
	"bio-digestive-spec": "Omnivorous Digestion (+harvest & crop extraction)",
	"bio-thermal-tolerance": "Thermal Tolerance (climate resilience, high-pass mobility)",
	"bio-encephalization": "Encephalization (+fast innovation, higher food upkeep, enables culture)",
	"bio-social-instinct": "Instinctive Sociability (+cohesion & ally defense, enables culture)",
	"cul-fire-processing": "Fire Processing (-food upkeep, +harvest)",
	"cul-extraction-tools": "Extraction Tools (+high harvest & crop yield, erodes K when non-foraging)",
	"cul-communal-conservation": "Communal Conservation (restores K each turn, -20% wall cost, +salubrity)",
	"cul-interdeme-barter": "Inter-Deme Barter (+25% trade yield, +45% when trading with fellow merchants)",
	"cul-warrior-expansion": "Warrior Tradition (+30% attack power, erodes K under overuse)"
}


static func doctrine_of(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var strategy: EvoTypes.StrategyDef = state.strategies_catalog[deme.strategy_id]
	var doc := EvoI18n.strategy_doctrine("en", strategy)
	if doc != "":
		return doc
	return strategy.doctrine if strategy.doctrine != "" else EvoI18n.strategy_description("en", strategy)


static func culture_name(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var strategy: EvoTypes.StrategyDef = state.strategies_catalog[deme.strategy_id]
	return EvoI18n.strategy_text(strategy.id, "name", strategy.name, "en")


static func _compass_dir(from_cell: EvoTypes.HexCell, to_cell: EvoTypes.HexCell) -> String:
	var dq := to_cell.q - from_cell.q
	var dr := to_cell.r - from_cell.r
	var delta := Vector2i(dq, dr)
	if DIRECTIONS.has(delta):
		return str(DIRECTIONS[delta])
	var x := float(dq) + 0.5 * float(dr)
	var y := 0.8660254 * float(dr)
	if absf(y) < 0.25:
		return "E" if x >= 0.0 else "W"
	if y < 0.0:
		return "NE" if x >= 0.0 else "NW"
	return "SE" if x >= 0.0 else "SW"


static func _describe_trait(tid: String, state: EvoTypes.WorldState) -> String:
	if TRAIT_EFFECT_NOTES.has(tid):
		return str(TRAIT_EFFECT_NOTES[tid])
	var tdef: EvoTypes.TraitDef = state.traits_catalog[tid]
	var tname := EvoI18n.trait_name("en", tdef)
	var tags: Array[String] = []
	if tdef.vector.extraction_efficiency >= 0.18:
		tags.append("+harvest")
	if tdef.vector.ecological_impact >= 0.18:
		tags.append("+K conservation")
	elif tdef.vector.ecological_impact <= -0.12:
		tags.append("-K erosion")
	if tdef.vector.spatial_mobility >= 0.22:
		tags.append("+mobility/attack")
	if tdef.vector.social_cohesion >= 0.20:
		tags.append("+cohesion/defense")
	return "%s (%s)" % [tname, ", ".join(tags) if not tags.is_empty() else "adaptive trait"]


static func _traits_line(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var items: Array[String] = []
	for tid in deme.biological_trait_ids + deme.cultural_trait_ids:
		if state.traits_catalog.has(tid):
			items.append(_describe_trait(tid, state))
	return "Active traits: %s." % ("; ".join(items) if not items.is_empty() else "none")


static func _horizons_line(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	neighbors: Array[EvoTypes.Deme]
) -> String:
	var items: Array[String] = []
	if deme.defense_tier < 3:
		var next_wall := EvoOutcomeForecast.WALL_NAMES[deme.defense_tier + 1]
		var req_pop := EvoPayoffs.FORTIFY_MIN_POP[deme.defense_tier]
		var req_food := EvoPayoffs.fortify_cost_reserves(deme)
		if EvoPayoffs.can_fortify(deme, cell):
			items.append("fortify %s READY (%d food)" % [next_wall, int(req_food)])
		else:
			var need_parts: Array[String] = []
			if deme.population < req_pop:
				need_parts.append("+%d pop (at %d)" % [req_pop - deme.population, req_pop])
			if deme.energy_reserves < req_food:
				need_parts.append("+%d food (at %d)" % [int(ceilf(req_food - deme.energy_reserves)), int(req_food)])
			if cell.current_resources < EvoPayoffs.fortify_cost_hex(deme):
				need_parts.append("hex land >= %d" % int(EvoPayoffs.fortify_cost_hex(deme)))
			items.append("next wall (%s) needs %s" % [next_wall, " & ".join(need_parts)])

	var s_pop := EvoPayoffs.settle_min_pop(deme)
	var s_food := EvoPayoffs.settle_min_reserves(deme)
	if deme.population >= s_pop and deme.energy_reserves >= s_food:
		items.append("settle READY (threshold %d pop, %d food)" % [s_pop, int(s_food)])
	else:
		items.append("settle unlocks at %d pop & %d food" % [s_pop, int(s_food)])

	for other in neighbors:
		var pk := EvoTypes.make_pair_key(deme.id, other.id)
		if state.relations.has(pk):
			var rel: EvoTypes.Relation = state.relations[pk]
			if rel.pact_turns in [1, 2]:
				items.append("union with %s in %d turn(s)" % [other.name, 3 - rel.pact_turns])

	if EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog) and EvoMilestonePhase.count_emergent_cultural_traits(deme, state) < EvoActionMenu.MAX_EMERGENT_CULTURAL:
		items.append("innovation %.2f/1.0 (+%.2f/turn)" % [deme.innovation_counter, EvoPayoffs.innovation_step(deme, state)])

	if state.glacial_sea_level_cycle:
		var turns_left := 8 - (state.generation % 8)
		var shift_gen := state.generation + turns_left
		var will_fall := ((shift_gen / 8) % 2) == 0
		if will_fall:
			items.append("glacial cycle: sea FALLS in %d turn(s) (coastal bridges emerge)" % turns_left)
		else:
			var warn := " — WARNING: coastal shallows will flood!" if turns_left <= 3 else ""
			items.append("glacial cycle: sea RISES in %d turn(s)%s" % [turns_left, warn])

	return "Horizons: %s." % " | ".join(items)


static func _relation_text(deme: EvoTypes.Deme, other: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var key := EvoTypes.make_pair_key(deme.id, other.id)
	var parts: Array[String] = []
	parts.append("your kin" if other.lineage_id == deme.lineage_id else "foreign lineage")
	if not state.relations.has(key):
		parts.append("no treaty, no history")
		return ", ".join(parts)
	var rel: EvoTypes.Relation = state.relations[key]
	if rel.pact_turns > 0:
		parts.append("ALLIED for %d turns" % rel.pact_turns)
	elif rel.feud_turns > 0:
		parts.append("FEUD (%d turns left)" % rel.feud_turns)
	elif rel.truce_turns > 0:
		parts.append("truce (%d turns left)" % rel.truce_turns)
	else:
		parts.append("no treaty")
	parts.append("trust %s" % EvoRelations.trust_word(rel.trust))
	if rel.last_event != "":
		parts.append("last: %s" % rel.last_event)
	return ", ".join(parts)


static func _perimeter_lines(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	rivals: Array[EvoTypes.Deme],
	raiders: Array[EvoTypes.Deme]
) -> Array[String]:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var mobility := EvoPayoffs.vector(deme, state).spatial_mobility
	var lines: Array[String] = []
	var seen_demes: Dictionary = {deme.id: true}

	for nid in EvoTypes.urban_perimeter_hex_ids(deme, state):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		if not EvoActionMenu.is_passable_for(ncell, mobility):
			continue
		var dir := _compass_dir(cell, ncell)
		if ncell.deme_ids.is_empty():
			var status_txt := "wild"
			if ncell.ruin_turns > 0:
				status_txt = "scorched ruins (%d turns to recover)" % ncell.ruin_turns
			elif ncell.owner_deme_id == deme.id:
				status_txt = "your %s" % ncell.land_use
			elif ncell.owner_deme_id != "" and state.demes.has(ncell.owner_deme_id):
				status_txt = "%s of %s" % [ncell.land_use, (state.demes[ncell.owner_deme_id] as EvoTypes.Deme).name]
			lines.append("- %s (%s): %s, %s, land %d." % [dir, ncell.id, status_txt, ncell.biome.replace("_", " "), int(ncell.current_resources)])
			continue

		var oid := ncell.deme_ids[0]
		if seen_demes.has(oid) or not state.demes.has(oid):
			continue
		seen_demes[oid] = true
		var other: EvoTypes.Deme = state.demes[oid]
		var size_tag := "Tier %s %d-hex city" % [other.get_village_roman(), other.urban_hex_ids.size()] if other.urban_hex_ids.size() > 1 else "Tier %s" % other.get_village_roman()
		lines.append("- %s (%s) %s [%s culture, %s]: %d people, food %d, %s, posture %s; %s; reputation %s." % [
			dir, ncell.id, other.name, culture_name(other, state), size_tag, other.population, int(other.energy_reserves),
			EvoOutcomeForecast.WALL_NAMES[other.defense_tier], str(EvoOutcomeForecast.POSTURE_NAMES[other.defense_posture]),
			_relation_text(deme, other, state), EvoRelations.reputation_word(other.reputation)
		])

	for rival in rivals:
		var rcell: EvoTypes.HexCell = state.cells[rival.hex_id]
		lines.append("- Border-crop rival %s (%s, %s, [%s culture]): %d people, food %d, %s, posture %s; their crops touch your border (%s); reputation %s." % [
			rival.name, _compass_dir(cell, rcell), rival.hex_id, culture_name(rival, state), rival.population, int(rival.energy_reserves),
			EvoOutcomeForecast.WALL_NAMES[rival.defense_tier], str(EvoOutcomeForecast.POSTURE_NAMES[rival.defense_posture]),
			_relation_text(deme, rival, state), EvoRelations.reputation_word(rival.reputation)
		])
	for raider in raiders:
		var fcell: EvoTypes.HexCell = state.cells[raider.hex_id]
		lines.append("- Field-border threat %s (%s, %s, [%s culture]): %d people, food %d, %s, posture %s; their settlement borders your cultivated fields (%s); reputation %s." % [
			raider.name, _compass_dir(cell, fcell), raider.hex_id, culture_name(raider, state), raider.population, int(raider.energy_reserves),
			EvoOutcomeForecast.WALL_NAMES[raider.defense_tier], str(EvoOutcomeForecast.POSTURE_NAMES[raider.defense_posture]),
			_relation_text(deme, raider, state), EvoRelations.reputation_word(raider.reputation)
		])
	return lines


static func _corridor_line_from(deme: EvoTypes.Deme, state: EvoTypes.WorldState, hops_map: Dictionary, targets: Array[EvoTypes.HexCell]) -> String:
	if targets.is_empty():
		return ""
	var parts: Array[String] = []
	for t in targets.slice(0, 4):
		var h := int(hops_map[t.id]) if hops_map.has(t.id) else EvoActionMenu.settle_hop_distance(deme, t.id, state)
		var bridge := ", land bridge" if t.biome == "coastal_shallows" else ""
		parts.append("%s (%d-hop %s%s, land %d)" % [t.id, h, t.biome.replace("_", " "), bridge, int(t.current_resources)])
	return "Colonization corridors (up to %d hops): %s." % [EvoActionMenu.max_settle_hops(deme, state), "; ".join(parts)]


static func _corridor_line(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var hops_map := EvoActionMenu.settle_corridor_hops(deme, state)
	var targets := EvoActionMenu.settle_targets_with_hops(deme, state, hops_map)
	return _corridor_line_from(deme, state, hops_map, targets)


static func _lineage_line(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var own_n := 0
	var own_pop := 0
	var other_n := 0
	var other_pop := 0
	for d: EvoTypes.Deme in state.demes.values():
		if d.lineage_id == deme.lineage_id:
			own_n += 1
			own_pop += d.population
		else:
			other_n += 1
			other_pop += d.population
	return "Your lineage: %d settlements, %d people. Rival lineages: %d settlements, %d people." % [own_n, own_pop, other_n, other_pop]


static func _pending_lines(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[String]:
	var lines: Array[String] = []
	for pk in state.relations.keys():
		var rel: EvoTypes.Relation = state.relations[pk]
		if rel.proposal_from == "" or rel.proposal_from == deme.id:
			continue
		var partner_id := EvoTypes.pair_partner(str(pk), deme.id)
		if partner_id == "" or rel.proposal_from != partner_id or not state.demes.has(partner_id):
			continue
		var partner: EvoTypes.Deme = state.demes[partner_id]
		match rel.proposal_kind:
			"pact":
				lines.append("%s proposes an alliance." % partner.name)
			"union":
				lines.append("%s proposes to unite with you." % partner.name)
			"tribute":
				lines.append("%s demands %d food as tribute, or else." % [partner.name, int(rel.proposal_amount)])
	return lines


static func build(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var hops_map := EvoActionMenu.settle_corridor_hops(deme, state)
	var targets := EvoActionMenu.settle_targets_with_hops(deme, state, hops_map)
	return build_with_corridors(
		deme,
		state,
		hops_map,
		targets,
		EvoActionMenu.neighbor_demes(deme, state),
		EvoActionMenu.border_field_rivals(deme, state),
		EvoActionMenu.field_raiders(deme, state)
	)


static func build_with_corridors(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	hops_map: Dictionary,
	targets: Array[EvoTypes.HexCell],
	neighbors: Array[EvoTypes.Deme],
	rivals: Array[EvoTypes.Deme],
	raiders: Array[EvoTypes.Deme]
) -> String:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var need := EvoPayoffs.food_need(deme, cell, state)
	var turns_of_food := deme.energy_reserves / maxf(1.0, need)
	var k_sum := 0.0
	var k_max_sum := 0.0
	for hid in deme.urban_hex_ids:
		var uc: EvoTypes.HexCell = state.cells[hid]
		k_sum += uc.carrying_capacity
		k_max_sum += uc.carrying_capacity_max
	var land_pct := int(roundf(k_sum / maxf(1.0, k_max_sum) * 100.0))
	var fields_owned := EvoRuralHinterland.owned_hexes(deme, state).size()
	var fields_quota := EvoRuralHinterland.deme_rural_quota(deme, state)
	var sal_pct := int(roundf(deme.salubrity * 100.0))
	var sal_warn := " (EPIDEMIC RISK!)" if deme.salubrity < 0.42 else ""
	if deme.infection_turns > 0:
		sal_warn = " (INFECTED, %d turns left)" % deme.infection_turns
	var loc_desc := (
		"Tier %s %d-hex city %s (districts: %s; %s)" % [deme.get_village_roman(), deme.urban_hex_ids.size(), deme.name, ", ".join(deme.urban_hex_ids), cell.biome.replace("_", " ")]
		if deme.urban_hex_ids.size() > 1
		else "Tier %s settlement %s (hex %s, %s)" % [deme.get_village_roman(), deme.name, cell.id, cell.biome.replace("_", " ")]
	)

	var lines: Array[String] = [
		"Turn %d, %s season. %s: %d people, food stock %d (%.1f turns of need), last turn %s%d food, urban land at %d%% capacity, %d/%d cultivated fields, %s, posture %s, salubrity %d%%%s." % [
			state.generation, "wet" if state.season == "wet_warm" else "dry", loc_desc, deme.population,
			int(deme.energy_reserves), turns_of_food, "+" if deme.last_energy_delta >= 0.0 else "",
			int(roundf(deme.last_energy_delta)), land_pct, fields_owned, fields_quota,
			EvoOutcomeForecast.WALL_NAMES[deme.defense_tier], str(EvoOutcomeForecast.POSTURE_NAMES[deme.defense_posture]),
			sal_pct, sal_warn
		],
		_traits_line(deme, state),
		_horizons_line(deme, cell, state, neighbors),
		"Your reputation among neighbors: %s. %s" % [EvoRelations.reputation_word(deme.reputation), _lineage_line(deme, state)],
		"Perimeter & neighbors:"
	]
	var perim := _perimeter_lines(deme, state, rivals, raiders)
	lines.append_array(perim if not perim.is_empty() else ["- isolated (no passable neighbors)"])
	var corridors := _corridor_line_from(deme, state, hops_map, targets)
	if corridors != "":
		lines.append(corridors)
	var pending := _pending_lines(deme, state)
	if not pending.is_empty():
		lines.append("Pending proposals: %s" % " ".join(pending))
	if deme.last_outcome != "":
		lines.append("Your last action: %s" % deme.last_outcome)
	if not deme.memory.is_empty():
		lines.append("Recent history: %s" % " | ".join(deme.memory.slice(0, EvoRelations.MEMORY_LENGTH)))
	return "\n".join(lines)
