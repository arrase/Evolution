class_name EvoOutcomeForecast
extends RefCounted

## English, quantified expected outcome of each menu option. These texts are the
## decision criteria scored by the model, so they are the explicit reward signal.

const WALL_NAMES: Array[String] = ["no walls", "a palisade", "stone walls", "a castle"]
const POSTURE_NAMES: Dictionary = {
	"open_harvest": "open harvest",
	"patrol_fields": "patrolling fields",
	"mobilized_garrison": "mobilized garrison"
}


static func _pct(p: float) -> String:
	return "%d%%" % int(roundf(p * 100.0))


static func _food(value: float) -> String:
	return str(int(roundf(value)))


static func union_kind(a: EvoTypes.Deme, b: EvoTypes.Deme) -> String:
	return "walled_union" if a.get_village_tier() >= 2 and b.get_village_tier() >= 2 else "absorption"


static func _describe_posture_formatted(
	posture: String,
	base_inc: float,
	forage_inc: float,
	need: float,
	fields_n: int,
	raid_threats: int,
	feud_threats: int
) -> String:
	var mob := _pct(float(EvoPayoffs.POSTURE_RURAL_MOBILIZATION[posture]))
	var shield := _pct(float(EvoPayoffs.POSTURE_CROP_SHIELD[posture]))
	if raid_threats == 0:
		match posture:
			"open_harvest":
				return "Open harvest (100%% harvest: ~%s food, %s if foraging; need %s): %s militia mobilized — 0 raiders in range, so full 100%% harvest across your %d fields is completely safe." % [
					_food(base_inc), _food(forage_inc), _food(need), mob, fields_n
				]
			"patrol_fields":
				return "Patrol fields (90%% harvest: ~%s food, %s if foraging; need %s): %s militia mobilized, %s crop shield — sacrifices 10%% food yield unnecessarily because 0 raiders are in range." % [
					_food(base_inc), _food(forage_inc), _food(need), mob, shield
				]
			"mobilized_garrison":
				return "Mobilized garrison (78%% harvest: ~%s food, %s if foraging; need %s): %s militia mobilized, %s crop shield — sacrifices 22%% food yield unnecessarily because 0 raiders are in range." % [
					_food(base_inc), _food(forage_inc), _food(need), mob, shield
				]
	var feud_note := ", %d active feud(s)" % feud_threats if feud_threats > 0 else ""
	match posture:
		"open_harvest":
			if fields_n > 0:
				return "Open harvest (100%% harvest: ~%s food, %s if foraging; need %s): %s militia mobilized, 0%% crop shield — HIGH RISK: %d potential raider(s) in range%s can plunder you and burn your %d fields for 3 turns!" % [
					_food(base_inc), _food(forage_inc), _food(need), mob, raid_threats, feud_note, fields_n
				]
			return "Open harvest (100%% harvest: ~%s food, %s if foraging; need %s): %s militia mobilized — %d potential raider(s) in range%s (0 cultivated fields owned, light urban defense if raided)." % [
				_food(base_inc), _food(forage_inc), _food(need), mob, raid_threats, feud_note
			]
		"patrol_fields":
			return "Patrol fields (90%% harvest: ~%s food, %s if foraging; need %s): %s militia mobilized, %s crop shield — active border patrols against %d potential raider(s) in range%s intercept raids and protect %d fields from burning." % [
				_food(base_inc), _food(forage_inc), _food(need), mob, shield, raid_threats, feud_note, fields_n
			]
		"mobilized_garrison":
			return "Mobilized garrison (78%% harvest: ~%s food, %s if foraging; need %s): %s militia mobilized, %s crop shield — heavy war defense against %d potential raider(s) in range%s shields your settlement and %d fields during feuds or outnumbered threats." % [
				_food(base_inc), _food(forage_inc), _food(need), mob, shield, raid_threats, feud_note, fields_n
			]
	return posture


static func describe_posture(deme: EvoTypes.Deme, posture: String, state: EvoTypes.WorldState) -> String:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var threats := EvoActionMenu.raid_threat_counts(deme, state)
	return _describe_posture_formatted(
		posture,
		EvoPayoffs.expected_income_for_posture(deme, state, "none", posture),
		EvoPayoffs.expected_income_for_posture(deme, state, "forage", posture),
		EvoPayoffs.food_need(deme, cell, state),
		EvoRuralHinterland.owned_hexes(deme, state).size(),
		threats.x,
		threats.y
	)


static func describe_postures_with_threats(deme: EvoTypes.Deme, state: EvoTypes.WorldState, threats: Vector2i) -> Dictionary:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var need := EvoPayoffs.food_need(deme, cell, state)
	var owned := EvoRuralHinterland.owned_hexes(deme, state)
	var fields_n := owned.size()
	var pact_mult := EvoPayoffs.pact_multiplier(deme, state)
	var open_rural := 0.0
	if fields_n > 0:
		var extraction := EvoPayoffs.vector(deme, state).extraction_efficiency
		var cap := float(deme.population) * clampf(0.24 + 0.16 * maxf(0.0, extraction), 0.24, 0.42)
		for ncell in owned:
			var biome_mult := 0.85 if ((ncell.biome in ["arid_steppe", "tundra"]) == (ncell.land_use == "pasture")) else 0.72
			open_rural += minf(ncell.current_resources, cap) * biome_mult
	var criteria: Dictionary = {}
	for p in EvoTypes.DEFENSE_POSTURES:
		var p_mult := float(EvoPayoffs.POSTURE_HARVEST_MULT[p])
		var rural_p := open_rural * p_mult
		var base_inc := (EvoPayoffs.urban_harvest_for_posture(deme, state, "none", p) + rural_p) * pact_mult
		var forage_inc := (EvoPayoffs.urban_harvest_for_posture(deme, state, "forage", p) + rural_p) * pact_mult
		criteria[p] = _describe_posture_formatted(p, base_inc, forage_inc, need, fields_n, threats.x, threats.y)
	return criteria


static func describe_postures(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	return describe_postures_with_threats(deme, state, EvoActionMenu.raid_threat_counts(deme, state))


static func describe_menu(
	deme: EvoTypes.Deme,
	menu: Array[Dictionary],
	state: EvoTypes.WorldState,
	hops_map: Dictionary,
	raid_cache: Dictionary
) -> Dictionary:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var need := EvoPayoffs.food_need(deme, cell, state)
	var rural := EvoRuralHinterland.rural_yield_estimate(deme, state)
	var pact_mult := EvoPayoffs.pact_multiplier(deme, state)
	var base_income := (EvoPayoffs.urban_harvest(deme, state, "none") + rural) * pact_mult
	var forage_income := (EvoPayoffs.urban_harvest(deme, state, "forage") + rural) * pact_mult
	var intensify_income := (EvoPayoffs.urban_harvest(deme, state, "intensify") + rural) * pact_mult
	var forecasts: Dictionary = {}
	for opt in menu:
		forecasts[str(opt["key"])] = _describe_with_totals(deme, opt, state, cell, need, base_income, raid_cache, hops_map, forage_income, intensify_income)
	return forecasts


static func describe(deme: EvoTypes.Deme, opt: Dictionary, state: EvoTypes.WorldState) -> String:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	return _describe_with_totals(
		deme,
		opt,
		state,
		cell,
		EvoPayoffs.food_need(deme, cell, state),
		EvoPayoffs.expected_income(deme, state, "none"),
		{},
		{},
		-1.0,
		-1.0
	)


static func _cached_raid_odds(
	deme: EvoTypes.Deme,
	other: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	raid_cache: Dictionary
) -> Dictionary:
	if not raid_cache.has(other.id):
		raid_cache[other.id] = EvoPayoffs.raid_odds(deme, other, state, false)
	return raid_cache[other.id]


static func _describe_with_totals(
	deme: EvoTypes.Deme,
	opt: Dictionary,
	state: EvoTypes.WorldState,
	cell: EvoTypes.HexCell,
	need: float,
	base_income: float,
	raid_cache: Dictionary,
	hops_map: Dictionary,
	forage_income: float,
	intensify_income: float
) -> String:
	var action_type := str(opt["type"])
	var target := str(opt["target"])
	var other: EvoTypes.Deme = state.demes[target] if state.demes.has(target) else null
	match action_type:
		"forage":
			var income := forage_income if forage_income >= 0.0 else EvoPayoffs.expected_income(deme, state, "forage")
			return "Forage carefully: harvest %s food this turn (need %s), land stays healthy." % [_food(income), _food(need)]
		"intensify":
			var income := intensify_income if intensify_income >= 0.0 else EvoPayoffs.expected_income(deme, state, "intensify")
			var extra := income - base_income
			var k_pct := int(roundf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max) * 100.0))
			return "Overexploit the land: harvest %s food (+%s extra now, need %s), but land capacity drops 7%% permanently (now %d%% of max)." % [_food(income), _food(extra), _food(need), k_pct]
		"fortify":
			var tier := deme.defense_tier
			var cost_res := EvoPayoffs.fortify_cost_reserves(deme)
			var tier_promo := "promotes settlement to Tier II (+1 cultivated field), " if (tier == 0 and deme.get_village_tier() == 1) else ""
			return "Build %s (harvest %s food, spend %s food): %sdefenders fight +%s stronger, raiders steal %s less, upkeep %s food/turn." % [
				WALL_NAMES[tier + 1],
				_food(base_income),
				_food(cost_res),
				tier_promo,
				_pct(EvoPayoffs.WALL_DEFENSE[tier + 1] - EvoPayoffs.WALL_DEFENSE[tier]),
				_pct(EvoPayoffs.WALL_LOOT_SHIELD[tier + 1]),
				_food(EvoPayoffs.WALL_UPKEEP[tier + 1])
			]
		"innovate":
			var step := EvoPayoffs.innovation_step(deme, state)
			return "Experiment with new techniques (harvest %s food): innovation %.2f -> %.2f of 1.0; at 1.0 you unlock a permanent cultural tradition." % [
				_food(base_income), deme.innovation_counter, minf(1.0, deme.innovation_counter + step)
			]
		"settle":
			var hex: EvoTypes.HexCell = state.cells[target]
			var hops := int(hops_map[target]) if hops_map.has(target) else EvoActionMenu.settle_hop_distance(deme, target, state)
			var n := EvoPayoffs.settlers(deme)
			var post_pop := deme.population - n
			var food := (deme.energy_reserves + base_income) * float(n) / float(deme.population)
			var post_harvest := base_income * (float(post_pop) / float(maxi(1, deme.population)))
			var field_note := "converts 1 of your own fields" if hex.owner_deme_id == deme.id else "keeps your cultivated fields intact"
			return "Found a new %d-hop camp at %s (%s, land %s): +1 settlement for your lineage with %d settlers and ~%s food (you harvest %s food now, keep %d people with ~%s future harvest, %s)." % [
				hops, target, hex.biome.replace("_", " "), _food(hex.current_resources), n, _food(food), _food(base_income), post_pop, _food(post_harvest), field_note
			]
		"trade":
			var gain := EvoPayoffs.trade_gain(deme, other, state)
			var alone := (0.75 if EvoTypes.is_pact_active(state, deme.id, other.id) else 0.55) * gain
			return "Trade with %s: harvest %s food + %s trade bonus = %s food (%s if mutual trade), trust +0.12, and diffuse cultural knowledge." % [
				other.name, _food(base_income), _food(alone), _food(base_income + alone), _food(base_income + gain)
			]
		"aid":
			var amt := EvoPayoffs.aid_amount(deme)
			return "Give %s surplus food to %s (you harvest %s food): trust +0.25, reputation improves, and seals any open alliance offer." % [_food(amt), other.name, _food(base_income)]
		"offer_pact":
			var instant := other.lineage_id == deme.lineage_id or (state.relations.has(EvoTypes.make_pair_key(deme.id, other.id)) and (state.relations[EvoTypes.make_pair_key(deme.id, other.id)] as EvoTypes.Relation).trust >= 0.30)
			return "Form an alliance with %s (harvest %s food): %s, both gain +%s food harvest every turn and mutual defense against attackers." % [
				other.name, _food(base_income), "seals immediately" if instant else "if they accept", _pct(EvoPayoffs.PACT_HARVEST_BONUS)
			]
		"accept_pact":
			return "Accept %s's alliance (harvest %s food): seals alliance immediately, both gain +%s food harvest every turn and mutual defense." % [
				other.name, _food(base_income), _pct(EvoPayoffs.PACT_HARVEST_BONUS)
			]
		"demand_tribute":
			var odds_t := _cached_raid_odds(deme, other, state, raid_cache)
			var trib := EvoPayoffs.tribute_amount(other)
			return "Demand %s food tribute from %s (harvest %s food + %s tribute = %s food if paid, zero casualties; your raid win chance vs their %s is %s): if they refuse next turn, your raiders automatically strike for ~%s food." % [
				_food(trib), other.name, _food(base_income), _food(trib), _food(base_income + trib),
				str(POSTURE_NAMES[other.defense_posture]), _pct(float(odds_t["p_win"])), _food(float(odds_t["loot"]))
			]
		"pay_tribute":
			var key := EvoTypes.make_pair_key(deme.id, other.id)
			var amount := (state.relations[key] as EvoTypes.Relation).proposal_amount
			var threat := EvoPayoffs.raid_odds(other, deme, state, false)
			var projected_after := deme.energy_reserves + base_income - amount - need
			var famine_warn := " WARNING: paying leaves you %s food short of need (%s), causing famine!" % [_food(-projected_after), _food(need)] if projected_after < 0.0 else ""
			return "Pay %s food tribute to %s (harvest %s food): buys a %d-turn truce and avoids raid casualties (if you refuse, they immediately raid with %s win chance to steal ~%s food).%s" % [
				_food(amount), other.name, _food(base_income), EvoPayoffs.TRUCE_AFTER_TRIBUTE, _pct(float(threat["p_win"])), _food(float(threat["loot"])), famine_warn
			]
		"raid":
			var odds := _cached_raid_odds(deme, other, state, raid_cache)
			var loot := float(odds["loot"])
			var def_posture := str(POSTURE_NAMES[other.defense_posture])
			if bool(odds["border_only"]):
				return "Raid %s's border crops with %d fighters (their posture: %s, win chance %s): harvest %s food + plunder ~%s crop food on win = ~%s food and burn their field for 3 turns if unshielded (you lose ~%d, they lose ~%d; on loss you lose ~%d). Starts %d-turn feud." % [
					other.name, int(odds["troops"]), def_posture, _pct(float(odds["p_win"])), _food(base_income), _food(loot), _food(base_income + loot),
					int(odds["attacker_loss_win"]), int(odds["defender_loss_win"]), int(odds["attacker_loss_lose"]), EvoPayoffs.FEUD_AFTER_RAID
				]
			return "Raid %s with %d fighters (their posture: %s, win chance %s): harvest %s food + steal ~%s food on win = ~%s food and strike 1 field (you lose ~%d, they lose ~%d; on loss you lose ~%d). Starts %d-turn feud." % [
				other.name, int(odds["troops"]), def_posture, _pct(float(odds["p_win"])), _food(base_income), _food(loot), _food(base_income + loot),
				int(odds["attacker_loss_win"]), int(odds["defender_loss_win"]), int(odds["attacker_loss_lose"]), EvoPayoffs.FEUD_AFTER_RAID
			]
		"betray":
			var odds := EvoPayoffs.raid_odds(deme, other, state, true)
			var loot := float(odds["loot"])
			return "Betray ally %s with a surprise attack while their gates are open (win chance %s): harvest %s food + seize ~%s food and scorch 1 field on win = ~%s food (you lose ~%d, they lose ~%d; on loss you lose ~%d; breaks pact, %d-turn feud, reputation -0.50)." % [
				other.name, _pct(float(odds["p_win"])), _food(base_income), _food(loot), _food(base_income + loot),
				int(odds["attacker_loss_win"]), int(odds["defender_loss_win"]), int(odds["attacker_loss_lose"]), EvoPayoffs.FEUD_AFTER_BETRAYAL
			]
		"conquer":
			var odds := EvoPayoffs.conquest_odds(deme, other, state)
			var troops := int(odds["troops"])
			var rations := roundf(minf((deme.energy_reserves + base_income) * 0.25, float(troops) * 1.2))
			var fields := EvoRuralHinterland.owned_hexes(other, state).size()
			var loot := roundf(other.energy_reserves * 0.5)
			var target_desc := "1 of their %d urban districts" % other.urban_hex_ids.size() if other.urban_hex_ids.size() > 1 else ("their hex%s" % (" and %d fields" % fields if fields > 0 else ""))
			return "Conquer %s with %d warriors (their posture: %s, win chance %s): harvest %s food, send %s campaign rations + seize ~%s loot on win to hold %s (+1 settlement, you lose ~%d, they lose ~%d; on loss ~%d warriors die). Starts %d-turn feud." % [
				other.name, troops, str(POSTURE_NAMES[other.defense_posture]), _pct(float(odds["p_win"])), _food(base_income),
				_food(rations), _food(loot), target_desc, int(odds["attacker_loss_win"]), int(odds["defender_loss_win"]), int(odds["attacker_loss_lose"]), EvoPayoffs.FEUD_AFTER_WAR
			]
		"unite", "accept_union":
			var verb := "Propose to unite with" if action_type == "unite" else "Accept union with"
			var total_pop := deme.population + other.population
			var total_hexes := deme.urban_hex_ids.size() + other.urban_hex_ids.size()
			var outcome := (
				"fuse permanently into a %d-hex walled city (%d people together, stone walls, +1 field quota, shared granary) under one unified command" % [total_hexes, total_pop]
				if union_kind(deme, other) == "walled_union"
				else "merge into a single larger city (%d people together)" % total_pop
			)
			var timing := " if they accept next turn" if action_type == "unite" else ""
			return "%s %s%s (harvest %s food): %s." % [verb, other.name, timing, _food(base_income), outcome]
	return action_type
