class_name EvoPayoffs
extends RefCounted

## Pure economic and military formulas. The outcome forecasts shown to the decision
## model and the turn resolution both call these functions, so what a settlement is
## told it will get is exactly what the engine computes.

const WALL_DEFENSE: Array[float] = [0.0, 0.5, 1.0, 1.6]
const WALL_LOOT_SHIELD: Array[float] = [0.0, 0.25, 0.5, 0.75]
const WALL_UPKEEP: Array[float] = [0.0, 1.5, 3.0, 5.0]
const FORTIFY_COST_RESERVES: Array[float] = [20.0, 40.0, 65.0]
const FORTIFY_COST_HEX: Array[float] = [12.0, 22.0, 32.0]
const FORTIFY_MIN_POP: Array[int] = [35, 65, 100]

const COMBAT_EXPONENT := 2.5
const RAID_TROOP_SHARE := 0.45
const CONQUEST_TROOP_SHARE := 0.55
const RAID_MOBILIZATION := 0.35
const CONQUEST_MOBILIZATION := 0.65
const SURPRISE_MOBILIZATION := 0.22
const ALLY_SUPPORT_SHARE := 0.22

const FORAGE_BONUS := 0.20
const INTENSIFY_BONUS := 0.55
const INTENSIFY_K_LOSS := 0.07
const PACT_HARVEST_BONUS := 0.12
const TRADE_SHARE := 0.18
const BIRTH_COST := 2.0
const BASE_GROWTH_RATE := 0.10
const SETTLE_MIN_POP := 80
const MIN_VIABLE_POP := 10
const INNOVATION_STEP := 0.35

const FEUD_AFTER_RAID := 4
const FEUD_AFTER_WAR := 6
const FEUD_AFTER_BETRAYAL := 8
const FEUD_AFTER_REFUSED_TRIBUTE := 2
const TRUCE_AFTER_TRIBUTE := 3


static func vector(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> EvoTypes.BiophysicalVector:
	return EvoCatalog.compute_deme_vector(deme, state.traits_catalog)


# --- Economy -----------------------------------------------------------------

static func food_need(deme: EvoTypes.Deme, cell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> float:
	var v := vector(deme, state)
	var climate_stress := 0.20 * absf(cell.temperature) * maxf(0.0, 1.0 - maxf(0.0, v.spatial_mobility))
	return float(deme.population) * 0.42 * (1.0 + 0.55 * v.metabolic_cost + climate_stress) + WALL_UPKEEP[deme.defense_tier]


static func home_demand(deme: EvoTypes.Deme, state: EvoTypes.WorldState, action_type: String) -> float:
	var v := vector(deme, state)
	var bonus := FORAGE_BONUS if action_type == "forage" else (INTENSIFY_BONUS if action_type == "intensify" else 0.0)
	return float(deme.population) * 0.5 * (1.0 + 0.4 * v.extraction_efficiency) * (1.0 + bonus)


static func home_harvest(deme: EvoTypes.Deme, cell: EvoTypes.HexCell, state: EvoTypes.WorldState, action_type: String) -> float:
	return minf(cell.current_resources, home_demand(deme, state, action_type))


static func expected_income(deme: EvoTypes.Deme, state: EvoTypes.WorldState, action_type: String) -> float:
	var cell: EvoTypes.HexCell = state.cells[deme.hex_id]
	var base := home_harvest(deme, cell, state, action_type) + EvoRuralHinterland.rural_yield_estimate(deme, state)
	return base * pact_multiplier(deme, state)


static func pact_multiplier(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var pacts := 0
	for pk in state.relations.keys():
		if EvoTypes.pair_partner(str(pk), deme.id) != "" and (state.relations[pk] as EvoTypes.Relation).pact_turns > 0:
			pacts += 1
	return 1.0 + PACT_HARVEST_BONUS * float(mini(pacts, 3))


static func trade_gain(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var ca: EvoTypes.HexCell = state.cells[a.hex_id]
	var cb: EvoTypes.HexCell = state.cells[b.hex_id]
	var complementarity := 1.0 + (0.4 if ca.biome != cb.biome else 0.0) + (0.2 if a.cultural_trait_ids != b.cultural_trait_ids else 0.0)
	var volume := minf(expected_income(a, state, "none"), expected_income(b, state, "none"))
	return TRADE_SHARE * volume * complementarity


static func unreciprocated_trade_gain(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return (0.75 if EvoTypes.is_pact_active(state, a.id, b.id) else 0.55) * trade_gain(a, b, state)


static func aid_amount(deme: EvoTypes.Deme) -> float:
	return roundf(clampf(deme.energy_reserves * 0.2, 5.0, 20.0))


static func tribute_amount(target: EvoTypes.Deme) -> float:
	return roundf(clampf(target.energy_reserves * 0.25, 8.0, 40.0))


static func storage_cap(deme: EvoTypes.Deme) -> float:
	return 80.0 + float(deme.population)


static func growth_rate(deme: EvoTypes.Deme) -> float:
	var life_history := 1.35 if deme.biological_trait_ids.has("bio-r-strategy") else (0.85 if deme.biological_trait_ids.has("bio-k-strategy") else 1.0)
	return BASE_GROWTH_RATE * (0.3 + 0.7 * deme.salubrity) * life_history


static func settlers(deme: EvoTypes.Deme) -> int:
	return clampi(int(roundf(float(deme.population) * 0.30)), 24, deme.population - 50)


static func can_fortify(deme: EvoTypes.Deme, cell: EvoTypes.HexCell) -> bool:
	var tier := deme.defense_tier
	return (
		tier < 3
		and deme.population >= FORTIFY_MIN_POP[tier]
		and deme.energy_reserves >= FORTIFY_COST_RESERVES[tier]
		and cell.current_resources >= FORTIFY_COST_HEX[tier]
	)


static func innovation_step(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return INNOVATION_STEP + 0.2 * vector(deme, state).transmission_threshold


# --- Combat ------------------------------------------------------------------

static func attack_multiplier(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var v := vector(deme, state)
	var martial := 0.30 if deme.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	return 1.0 + 0.6 * maxf(0.0, v.spatial_mobility) + 0.2 * maxf(0.0, v.extraction_efficiency) + martial


static func cohesion_multiplier(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return 1.0 + 0.6 * maxf(0.0, vector(deme, state).social_cohesion)


static func defense_power(
	defender: EvoTypes.Deme,
	attacker_id: String,
	mobilized_share: float,
	with_allies: bool,
	state: EvoTypes.WorldState
) -> float:
	var power := float(defender.population) * mobilized_share * cohesion_multiplier(defender, state) * (1.0 + WALL_DEFENSE[defender.defense_tier])
	if not with_allies:
		return power
	var dcell: EvoTypes.HexCell = state.cells[defender.hex_id]
	for nid in HexMath.get_neighbor_ids(dcell.q, dcell.r, state.cells):
		for oid in (state.cells[nid] as EvoTypes.HexCell).deme_ids:
			if oid == attacker_id or oid == defender.id:
				continue
			var other: EvoTypes.Deme = state.demes[oid]
			var same_union := defender.walled_union_id != "" and other.walled_union_id == defender.walled_union_id
			if same_union or EvoTypes.is_pact_active(state, defender.id, oid):
				power += ALLY_SUPPORT_SHARE * float(other.population) * cohesion_multiplier(other, state)
	return power


static func win_probability(attack: float, defense: float) -> float:
	var a := pow(maxf(attack, 0.0), COMBAT_EXPONENT)
	var d := pow(maxf(defense, 0.0), COMBAT_EXPONENT)
	return a / (a + d) if a + d > 0.0 else 0.0


## Odds and stakes of a raid (or a surprise raid on an ally when `surprise` is true).
static func raid_odds(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, state: EvoTypes.WorldState, surprise: bool) -> Dictionary:
	if not surprise and defender.defense_tier >= 3:
		return {
			"p_win": 0.0,
			"troops": int(roundf(float(attacker.population) * RAID_TROOP_SHARE)),
			"loot": 0.0,
			"attacker_loss_win": 0,
			"defender_loss_win": 0,
			"attacker_loss_lose": int(roundf(float(attacker.population) * RAID_TROOP_SHARE * 0.30)),
			"defender_loss_lose": 1
		}
	var troops := int(roundf(float(attacker.population) * RAID_TROOP_SHARE))
	var attack := float(troops) * attack_multiplier(attacker, state)
	var mobilized := SURPRISE_MOBILIZATION if surprise else RAID_MOBILIZATION
	var defense := defense_power(defender, attacker.id, mobilized, not surprise, state)
	var loot_share := 0.75 if surprise else 0.45
	var shield := 0.25 * WALL_LOOT_SHIELD[defender.defense_tier] if surprise else WALL_LOOT_SHIELD[defender.defense_tier]
	var cap_mult := 3.0 if surprise else 2.2
	var loot := minf(defender.energy_reserves * loot_share, float(troops) * cap_mult) * (1.0 - shield)
	return {
		"p_win": win_probability(attack, defense),
		"troops": troops,
		"loot": roundf(loot),
		"attacker_loss_win": int(roundf(float(troops) * 0.05)),
		"defender_loss_win": int(roundf(float(troops) * 0.15)),
		"attacker_loss_lose": int(roundf(float(troops) * 0.25)),
		"defender_loss_lose": int(roundf(float(troops) * 0.04))
	}


static func conquest_odds(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	var troops := int(roundf(float(attacker.population) * CONQUEST_TROOP_SHARE))
	var attack := float(troops) * attack_multiplier(attacker, state)
	var defense := defense_power(defender, attacker.id, CONQUEST_MOBILIZATION, true, state)
	return {
		"p_win": win_probability(attack, defense),
		"troops": troops,
		"attacker_loss_win": int(roundf(float(troops) * 0.15)),
		"defender_loss_win": int(roundf(float(defender.population) * 0.30)),
		"attacker_loss_lose": int(roundf(float(troops) * 0.40)),
		"defender_loss_lose": int(roundf(float(defender.population) * 0.06))
	}
