class_name EvoSituationReport
extends RefCounted

## Natural-language briefing given to the decision model: doctrine, goal-relevant
## state, neighbors with their relationship history, memory and pending proposals.

const DIRECTIONS := {
	Vector2i(1, 0): "E", Vector2i(1, -1): "NE", Vector2i(0, -1): "NW",
	Vector2i(-1, 0): "W", Vector2i(-1, 1): "SW", Vector2i(0, 1): "SE"
}


static func doctrine_of(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var strategy: EvoTypes.StrategyDef = state.strategies_catalog[deme.strategy_id]
	return strategy.doctrine if strategy.doctrine != "" else strategy.description


static func culture_name(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> String:
	var strategy: EvoTypes.StrategyDef = state.strategies_catalog[deme.strategy_id]
	return EvoI18n.strategy_text(strategy.id, "name", strategy.name, "en")


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


static func _neighbor_lines(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Array[String]:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var lines: Array[String] = []
	for nid in HexMath.get_neighbor_ids(cell.q, cell.r, state.cells):
		var ncell: EvoTypes.HexCell = state.cells[nid]
		var dir := str(DIRECTIONS[Vector2i(ncell.q - cell.q, ncell.r - cell.r)])
		if not EvoActionMenu.is_passable(ncell):
			continue
		if ncell.deme_ids.is_empty():
			var use := "your fields" if ncell.owner_deme_id == deme.id else ("fields of another settlement" if ncell.owner_deme_id != "" else "empty")
			lines.append("- %s (%s): %s %s, land %d." % [dir, ncell.id, use, ncell.biome.replace("_", " "), int(ncell.current_resources)])
			continue
		var other: EvoTypes.Deme = state.demes[ncell.deme_ids[0]]
		lines.append("- %s (%s) %s [%s culture]: %d people, food %d, %s; %s; reputation %s." % [
			dir, ncell.id, other.name, culture_name(other, state), other.population, int(other.energy_reserves),
			EvoOutcomeForecast.WALL_NAMES[other.defense_tier], _relation_text(deme, other, state),
			EvoRelations.reputation_word(other.reputation)
		])
	return lines


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
		var partner_id := EvoTypes.pair_partner(str(pk), deme.id)
		if partner_id == "" or rel.proposal_from != partner_id:
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
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var need := EvoPayoffs.food_need(deme, cell, state)
	var turns_of_food := deme.energy_reserves / maxf(1.0, need)
	var land_pct := int(roundf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max) * 100.0))
	var lines: Array[String] = [
		"Culture: %s" % doctrine_of(deme, state),
		"Turn %d, %s season. Settlement %s (hex %s, %s): %d people, food stock %d (%.1f turns of need), last turn %s%d food, land at %d%% of capacity, %s." % [
			state.generation, "wet" if state.season == "wet_warm" else "dry", deme.name, cell.id, cell.biome.replace("_", " "),
			deme.population, int(deme.energy_reserves), turns_of_food, "+" if deme.last_energy_delta >= 0.0 else "",
			int(roundf(deme.last_energy_delta)), land_pct, EvoOutcomeForecast.WALL_NAMES[deme.defense_tier]
		],
		"Your reputation among neighbors: %s." % EvoRelations.reputation_word(deme.reputation),
		_lineage_line(deme, state),
		"Neighbors:"
	]
	var neighbor_lines := _neighbor_lines(deme, state)
	lines.append_array(neighbor_lines if not neighbor_lines.is_empty() else ["- none reachable"])
	if deme.last_outcome != "":
		lines.append("Your last action: %s" % deme.last_outcome)
	if not deme.memory.is_empty():
		lines.append("Recent history: %s" % " | ".join(deme.memory))
	var pending := _pending_lines(deme, state)
	if not pending.is_empty():
		lines.append("Pending: %s" % " ".join(pending))
	return "\n".join(lines)
