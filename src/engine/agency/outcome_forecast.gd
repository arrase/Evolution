class_name EvoOutcomeForecast
extends RefCounted

## English, quantified expected outcome of each menu option. These texts are the
## decision criteria scored by the model, so they are the explicit reward signal.

const WALL_NAMES: Array[String] = ["no walls", "a palisade", "stone walls", "a castle"]


static func _pct(p: float) -> String:
	return "%d%%" % int(roundf(p * 100.0))


static func _food(value: float) -> String:
	return str(int(roundf(value)))


static func union_kind(a: EvoTypes.Deme, b: EvoTypes.Deme) -> String:
	var ta := a.get_village_tier()
	var tb := b.get_village_tier()
	return "walled_union" if ta == tb and ta >= 2 else "absorption"


static func describe(deme: EvoTypes.Deme, opt: Dictionary, state: EvoTypes.WorldState) -> String:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var action_type := str(opt["type"])
	var target := str(opt["target"])
	var other: EvoTypes.Deme = state.demes[target] if state.demes.has(target) else null
	var need := EvoPayoffs.food_need(deme, cell, state)
	var base_income := EvoPayoffs.expected_income(deme, state, "none")
	match action_type:
		"forage":
			var income := EvoPayoffs.expected_income(deme, state, "forage")
			return "Forage carefully: harvest %s food this turn (need %s), land stays healthy." % [_food(income), _food(need)]
		"intensify":
			var income := EvoPayoffs.expected_income(deme, state, "intensify")
			var extra := income - base_income
			var k_pct := int(roundf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max) * 100.0))
			return "Overexploit the land: harvest %s food (+%s extra now, need %s), but land capacity drops 7%% permanently (now %d%% of max)." % [_food(income), _food(extra), _food(need), k_pct]
		"fortify":
			var tier := deme.defense_tier
			return "Build %s (harvest %s food, spend %s food): defenders fight +%s stronger, raiders steal %s less, upkeep %s food/turn." % [
				WALL_NAMES[tier + 1],
				_food(base_income),
				_food(EvoPayoffs.FORTIFY_COST_RESERVES[tier]),
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
			var n := EvoPayoffs.settlers(deme)
			var food := deme.energy_reserves * float(n) / float(deme.population)
			return "Found a new camp at %s (%s, land %s): +1 settlement for your lineage with %d settlers and %s food (you keep %d people and harvest %s food)." % [
				target, hex.biome.replace("_", " "), _food(hex.current_resources), n, _food(food), deme.population - n, _food(base_income)
			]
		"trade":
			var gain := EvoPayoffs.trade_gain(deme, other, state)
			var alone := EvoPayoffs.unreciprocated_trade_gain(deme, other, state)
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
			var odds_t := EvoPayoffs.raid_odds(deme, other, state, false)
			var trib := EvoPayoffs.tribute_amount(other)
			return "Demand %s food tribute from %s (harvest %s food + %s tribute = %s food if paid, zero casualties; your raid win chance is %s): if they refuse next turn, your raiders automatically strike for ~%s food." % [
				_food(trib), other.name, _food(base_income), _food(trib), _food(base_income + trib), _pct(float(odds_t["p_win"])), _food(float(odds_t["loot"]))
			]
		"pay_tribute":
			var key := EvoTypes.make_pair_key(deme.id, other.id)
			var amount := (state.relations[key] as EvoTypes.Relation).proposal_amount
			var threat := EvoPayoffs.raid_odds(other, deme, state, false)
			return "Pay %s food tribute to %s (harvest %s food): buys a %d-turn truce and avoids raid casualties (if you refuse, they immediately raid with %s win chance to steal ~%s food)." % [
				_food(amount), other.name, _food(base_income), EvoPayoffs.TRUCE_AFTER_TRIBUTE, _pct(float(threat["p_win"])), _food(float(threat["loot"]))
			]
		"raid":
			var odds := EvoPayoffs.raid_odds(deme, other, state, false)
			var loot := float(odds["loot"])
			return "Raid %s with %d fighters (win chance %s): harvest %s food + steal ~%s food on win = ~%s food and pillage 1 field (you lose ~%d, they lose ~%d; on loss you lose ~%d). Starts %d-turn feud." % [
				other.name, int(odds["troops"]), _pct(float(odds["p_win"])), _food(base_income), _food(loot), _food(base_income + loot),
				int(odds["attacker_loss_win"]), int(odds["defender_loss_win"]), int(odds["attacker_loss_lose"]), EvoPayoffs.FEUD_AFTER_RAID
			]
		"betray":
			var odds := EvoPayoffs.raid_odds(deme, other, state, true)
			var loot := float(odds["loot"])
			return "Betray ally %s with a surprise attack while their gates are open (win chance %s): harvest %s food + seize ~%s food and 1 field on win = ~%s food (they lose ~%d, on loss you lose ~%d; breaks pact, %d-turn feud, reputation -0.50)." % [
				other.name, _pct(float(odds["p_win"])), _food(base_income), _food(loot), _food(base_income + loot), int(odds["defender_loss_win"]),
				int(odds["attacker_loss_lose"]), EvoPayoffs.FEUD_AFTER_BETRAYAL
			]
		"conquer":
			var odds := EvoPayoffs.conquest_odds(deme, other, state)
			var fields := EvoRuralHinterland.owned_hexes(other, state).size()
			var loot := roundf(other.energy_reserves * 0.5)
			return "Conquer %s with %d warriors (win chance %s): harvest %s food + capture their hex%s and +%s food on win = ~%s food (+1 settlement, they lose ~%d and flee or are absorbed; on loss ~%d warriors die). Starts %d-turn feud." % [
				other.name, int(odds["troops"]), _pct(float(odds["p_win"])), _food(base_income),
				" and %d fields" % fields if fields > 0 else "", _food(loot), _food(base_income + loot), int(odds["defender_loss_win"]), int(odds["attacker_loss_lose"]), EvoPayoffs.FEUD_AFTER_WAR
			]
		"unite", "accept_union":
			var verb := "Propose to unite with" if action_type == "unite" else "Accept union with"
			var outcome := (
				"both cities keep their hexes, share walls and defend as one"
				if union_kind(deme, other) == "walled_union"
				else "merge into a single larger city (%d people together)" % (deme.population + other.population)
			)
			var timing := " if they accept next turn" if action_type == "unite" else ""
			return "%s %s%s (harvest %s food): %s." % [verb, other.name, timing, _food(base_income), outcome]
	return action_type
