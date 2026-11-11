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

const POSTURE_HARVEST_MULT: Dictionary = {
	"open_harvest": 1.0,
	"patrol_fields": 0.90,
	"mobilized_garrison": 0.78
}
const POSTURE_RURAL_MOBILIZATION: Dictionary = {
	"open_harvest": 0.25,
	"patrol_fields": 0.55,
	"mobilized_garrison": 0.80
}
const POSTURE_CROP_SHIELD: Dictionary = {
	"open_harvest": 0.0,
	"patrol_fields": 0.65,
	"mobilized_garrison": 0.85
}
const URBAN_FORAGE_MULT: Array[float] = [1.0, 1.0, 0.90, 0.65, 0.40]

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
const BASE_GROWTH_RATE := 0.115
const SETTLE_MIN_POP := 105
const MIN_VIABLE_POP := 10
const INNOVATION_STEP := 0.22

const FEUD_AFTER_RAID := 4
const FEUD_AFTER_WAR := 6
const FEUD_AFTER_BETRAYAL := 8
const FEUD_AFTER_REFUSED_TRIBUTE := 2
const TRUCE_AFTER_TRIBUTE := 3


static func vector(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> EvoTypes.BiophysicalVector:
	var h: int = deme.biological_trait_ids.hash() ^ (deme.cultural_trait_ids.hash() * 31) ^ state.traits_catalog.size()
	if deme._cached_vector == null or deme._cached_vector_hash != h:
		deme._cached_vector = EvoCatalog.compute_deme_vector(deme, state.traits_catalog)
		deme._cached_vector_hash = h
	return deme._cached_vector


# --- Economy -----------------------------------------------------------------

static func food_need(deme: EvoTypes.Deme, cell: EvoTypes.HexCell, state: EvoTypes.WorldState) -> float:
	var v := vector(deme, state)
	var climate_stress := 0.20 * absf(cell.temperature) * maxf(0.0, 1.0 - maxf(0.0, v.spatial_mobility))
	return float(deme.population) * 0.42 * (1.0 + 0.55 * v.metabolic_cost + climate_stress) + WALL_UPKEEP[deme.defense_tier]


static func home_demand_for_posture(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	action_type: String,
	posture: String
) -> float:
	var v := vector(deme, state)
	var bonus := FORAGE_BONUS if action_type == "forage" else (INTENSIFY_BONUS if action_type == "intensify" else 0.0)
	var mult := URBAN_FORAGE_MULT[deme.get_village_tier()] * float(POSTURE_HARVEST_MULT[posture])
	return float(deme.population) * 0.5 * (1.0 + 0.4 * v.extraction_efficiency) * (1.0 + bonus) * mult


static func home_demand(deme: EvoTypes.Deme, state: EvoTypes.WorldState, action_type: String) -> float:
	return home_demand_for_posture(deme, state, action_type, deme.defense_posture)


static func urban_harvest_for_posture(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	action_type: String,
	posture: String
) -> float:
	var available := 0.0
	for hid in deme.urban_hex_ids:
		available += (state.cells[hid] as EvoTypes.HexCell).current_resources
	return minf(available, home_demand_for_posture(deme, state, action_type, posture))


static func urban_harvest(deme: EvoTypes.Deme, state: EvoTypes.WorldState, action_type: String) -> float:
	return urban_harvest_for_posture(deme, state, action_type, deme.defense_posture)


static func home_harvest(deme: EvoTypes.Deme, cell: EvoTypes.HexCell, state: EvoTypes.WorldState, action_type: String) -> float:
	if deme.urban_hex_ids.is_empty():
		return minf(cell.current_resources, home_demand(deme, state, action_type))
	return urban_harvest(deme, state, action_type)


static func expected_income_for_posture(
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	action_type: String,
	posture: String
) -> float:
	var urban := urban_harvest_for_posture(deme, state, action_type, posture)
	var rural := EvoRuralHinterland.rural_yield_for_posture(deme, state, posture)
	return (urban + rural) * pact_multiplier(deme, state)


static func expected_income(deme: EvoTypes.Deme, state: EvoTypes.WorldState, action_type: String) -> float:
	return expected_income_for_posture(deme, state, action_type, deme.defense_posture)


static func pact_multiplier(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var pacts := 0
	for pk in state.relations.keys():
		if (state.relations[pk] as EvoTypes.Relation).pact_turns > 0 and EvoTypes.pair_partner(str(pk), deme.id) != "":
			pacts += 1
	return 1.0 + PACT_HARVEST_BONUS * float(mini(pacts, 3))


static func trade_gain(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var ca: EvoTypes.HexCell = state.cells[a.hex_id]
	var cb: EvoTypes.HexCell = state.cells[b.hex_id]
	var complementarity := 1.0 + (0.4 if ca.biome != cb.biome else 0.0) + (0.2 if a.cultural_trait_ids != b.cultural_trait_ids else 0.0)
	var a_barter := a.cultural_trait_ids.has("cul-interdeme-barter")
	var b_barter := b.cultural_trait_ids.has("cul-interdeme-barter")
	var barter_mult := 1.45 if (a_barter and b_barter) else (1.25 if (a_barter or b_barter) else 1.0)
	var volume := minf(expected_income(a, state, "none"), expected_income(b, state, "none"))
	return TRADE_SHARE * volume * complementarity * barter_mult


static func unreciprocated_trade_gain(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return (0.75 if EvoTypes.is_pact_active(state, a.id, b.id) else 0.55) * trade_gain(a, b, state)


static func aid_amount(deme: EvoTypes.Deme) -> float:
	return roundf(clampf(deme.energy_reserves * 0.2, 5.0, 20.0))


static func tribute_amount(target: EvoTypes.Deme) -> float:
	return roundf(clampf(target.energy_reserves * 0.25, 8.0, 40.0))


static func storage_cap(deme: EvoTypes.Deme) -> float:
	return 80.0 * float(maxi(1, deme.urban_hex_ids.size())) + float(deme.population)


static func effective_carrying_capacity(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var total := 0.0
	for hid in deme.urban_hex_ids:
		total += (state.cells[hid] as EvoTypes.HexCell).carrying_capacity
	for rcell in EvoRuralHinterland.owned_hexes(deme, state):
		total += 0.55 * rcell.carrying_capacity
	return total


static func growth_rate(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var d := clampf(float(deme.population) / maxf(40.0, effective_carrying_capacity(deme, state)), 0.0, 1.4)
	var base: float
	if deme.biological_trait_ids.has("bio-r-strategy"):
		base = 0.16 * maxf(0.15, 1.0 - 0.55 * d)
	elif deme.biological_trait_ids.has("bio-k-strategy"):
		base = 0.095 * maxf(0.35, 1.0 - 0.20 * d)
	else:
		base = 0.115 * maxf(0.25, 1.0 - 0.35 * d)
	return base * (0.35 + 0.65 * deme.salubrity)


static func settle_min_pop(deme: EvoTypes.Deme) -> int:
	if deme.biological_trait_ids.has("bio-r-strategy"):
		return 65
	if deme.biological_trait_ids.has("bio-k-strategy"):
		return 145
	return 105


static func settle_min_reserves(deme: EvoTypes.Deme) -> float:
	if deme.biological_trait_ids.has("bio-r-strategy"):
		return 32.0
	if deme.biological_trait_ids.has("bio-k-strategy"):
		return 75.0
	return 55.0


static func settlers(deme: EvoTypes.Deme) -> int:
	if deme.biological_trait_ids.has("bio-r-strategy"):
		return clampi(int(roundf(float(deme.population) * 0.34)), 22, maxi(22, deme.population - 35))
	if deme.biological_trait_ids.has("bio-k-strategy"):
		return clampi(int(roundf(float(deme.population) * 0.24)), 30, maxi(30, deme.population - 50))
	return clampi(int(roundf(float(deme.population) * 0.30)), 24, maxi(24, deme.population - 45))


static func _fortify_discount(deme: EvoTypes.Deme) -> float:
	if deme.biological_trait_ids.has("bio-k-strategy") or deme.cultural_trait_ids.has("cul-communal-conservation"):
		return 0.80
	return 1.0


static func fortify_cost_reserves(deme: EvoTypes.Deme) -> float:
	return roundf(FORTIFY_COST_RESERVES[deme.defense_tier] * _fortify_discount(deme))


static func fortify_cost_hex(deme: EvoTypes.Deme) -> float:
	return roundf(FORTIFY_COST_HEX[deme.defense_tier] * _fortify_discount(deme))


static func can_fortify(deme: EvoTypes.Deme, cell: EvoTypes.HexCell) -> bool:
	var tier := deme.defense_tier
	return (
		tier < 3
		and deme.population >= FORTIFY_MIN_POP[tier]
		and deme.energy_reserves >= fortify_cost_reserves(deme)
		and cell.current_resources >= fortify_cost_hex(deme)
	)


static func innovation_step(deme: EvoTypes.Deme, _state: EvoTypes.WorldState) -> float:
	if deme.biological_trait_ids.has("bio-encephalization"):
		return minf(0.55, 0.37 + 0.04 * float(deme.cultural_trait_ids.size()))
	var martial_drag := -0.05 if deme.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	return clampf(0.15 + martial_drag + 0.03 * float(deme.cultural_trait_ids.size()), 0.12, 0.30)


# --- Spatial & Combat --------------------------------------------------------

static func min_urban_distance(a: EvoTypes.Deme, b: EvoTypes.Deme, state: EvoTypes.WorldState) -> int:
	var best := 999
	for ha in a.urban_hex_ids:
		var ca: EvoTypes.HexCell = state.cells[ha]
		for hb in b.urban_hex_ids:
			var cb: EvoTypes.HexCell = state.cells[hb]
			best = mini(best, HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r))
	return best


static func closest_defender_field(
	attacker: EvoTypes.Deme,
	defender: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> EvoTypes.HexCell:
	var best_field: EvoTypes.HexCell = null
	var best_dist := 999
	for field in EvoRuralHinterland.owned_hexes(defender, state):
		for ha in attacker.urban_hex_ids:
			var ca: EvoTypes.HexCell = state.cells[ha]
			var dist := HexMath.hex_distance(field.q, field.r, ca.q, ca.r)
			if dist < best_dist or (dist == best_dist and best_field != null and field.current_resources > best_field.current_resources):
				best_dist = dist
				best_field = field
	return best_field


static func field_plunder_amount(field: EvoTypes.HexCell, defender: EvoTypes.Deme, surprise: bool) -> float:
	if field == null:
		return 0.0
	var shield := 0.0 if surprise else float(POSTURE_CROP_SHIELD[defender.defense_posture])
	return roundf(minf(field.current_resources * 0.32, 26.0) * (1.0 - shield))


static func attack_multiplier(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	var v := vector(deme, state)
	var martial := 0.45 if deme.cultural_trait_ids.has("cul-warrior-expansion") else 0.0
	return 1.0 + 0.6 * maxf(0.0, v.spatial_mobility) + 0.2 * maxf(0.0, v.extraction_efficiency) + martial


static func _ally_support_on_hex(
	nid: String,
	attacker: EvoTypes.Deme,
	state: EvoTypes.WorldState,
	seen: Dictionary
) -> float:
	var bonus := 0.0
	for oid in (state.cells[nid] as EvoTypes.HexCell).deme_ids:
		if seen.has(oid) or not state.demes.has(oid):
			continue
		seen[oid] = true
		var other: EvoTypes.Deme = state.demes[oid]
		var pk := EvoTypes.make_pair_key(attacker.id, oid)
		var rel: EvoTypes.Relation = state.relations[pk] if state.relations.has(pk) else null
		var allied := rel != null and rel.pact_turns > 0
		var peaceful_kin := other.lineage_id == attacker.lineage_id and (rel == null or rel.feud_turns == 0)
		if allied or peaceful_kin:
			bonus += ALLY_SUPPORT_SHARE * float(other.population) * cohesion_multiplier(other, state)
	return bonus


static func flanking_support(
	attacker: EvoTypes.Deme,
	defender: EvoTypes.Deme,
	target_field: EvoTypes.HexCell,
	state: EvoTypes.WorldState
) -> float:
	var seen: Dictionary = {attacker.id: true, defender.id: true}
	var bonus := 0.0
	for nid in EvoTypes.urban_perimeter_hex_ids(defender, state):
		bonus += _ally_support_on_hex(nid, attacker, state, seen)
	if target_field != null:
		for fnid in HexMath.get_neighbor_ids(target_field.q, target_field.r, state.cells):
			bonus += _ally_support_on_hex(fnid, attacker, state, seen)
	return bonus


static func cohesion_multiplier(deme: EvoTypes.Deme, state: EvoTypes.WorldState) -> float:
	return 1.0 + 0.6 * maxf(0.0, vector(deme, state).social_cohesion)


static func defense_power(
	defender: EvoTypes.Deme,
	attacker_id: String,
	mobilized_share: float,
	with_allies: bool,
	state: EvoTypes.WorldState,
	use_walls: bool = true
) -> float:
	var wall_bonus := WALL_DEFENSE[defender.defense_tier] if use_walls else 0.0
	var power := float(defender.population) * mobilized_share * cohesion_multiplier(defender, state) * (1.0 + wall_bonus)
	if not with_allies:
		return power
	var seen_allies: Dictionary = {defender.id: true, attacker_id: true}
	for nid in EvoTypes.urban_perimeter_hex_ids(defender, state):
		for oid in (state.cells[nid] as EvoTypes.HexCell).deme_ids:
			if seen_allies.has(oid):
				continue
			seen_allies[oid] = true
			var other: EvoTypes.Deme = state.demes[oid]
			if EvoTypes.is_pact_active(state, defender.id, oid):
				power += ALLY_SUPPORT_SHARE * float(other.population) * cohesion_multiplier(other, state)
	return power


static func win_probability(attack: float, defense: float) -> float:
	var a := pow(maxf(attack, 0.0), COMBAT_EXPONENT)
	var d := pow(maxf(defense, 0.0), COMBAT_EXPONENT)
	return a / (a + d) if a + d > 0.0 else 0.0


## Odds and stakes of a raid (or a surprise raid on an ally when `surprise` is true).
static func raid_odds(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, state: EvoTypes.WorldState, surprise: bool) -> Dictionary:
	var troops := int(roundf(float(attacker.population) * RAID_TROOP_SHARE))
	var target_field := closest_defender_field(attacker, defender, state)
	var castle_blocks_city := not surprise and defender.defense_tier >= 3
	var border_only := not surprise and (min_urban_distance(attacker, defender, state) > 1 or castle_blocks_city)
	if castle_blocks_city and target_field == null:
		return {
			"p_win": 0.0,
			"troops": troops,
			"loot": 0.0,
			"granary_loot": 0.0,
			"field_loot": 0.0,
			"border_only": border_only,
			"attacker_loss_win": 0,
			"defender_loss_win": 0,
			"attacker_loss_lose": int(roundf(float(troops) * 0.30)),
			"defender_loss_lose": 1
		}
	var attack := float(troops) * attack_multiplier(attacker, state) + (0.0 if surprise else flanking_support(attacker, defender, target_field, state))
	var mobilized := SURPRISE_MOBILIZATION if surprise else float(POSTURE_RURAL_MOBILIZATION[defender.defense_posture])
	var defense := defense_power(defender, attacker.id, mobilized, not surprise, state, not border_only)
	var field_loot := field_plunder_amount(target_field, defender, surprise)
	var granary_loot := 0.0
	if not border_only:
		var loot_share := 0.75 if surprise else 0.45
		var shield := 0.25 * WALL_LOOT_SHIELD[defender.defense_tier] if surprise else WALL_LOOT_SHIELD[defender.defense_tier]
		var cap_mult := 3.0 if surprise else 2.2
		granary_loot = roundf(minf(defender.energy_reserves * loot_share, float(troops) * cap_mult) * (1.0 - shield))
	var total_loot := granary_loot + field_loot
	return {
		"p_win": win_probability(attack, defense),
		"troops": troops,
		"loot": total_loot,
		"granary_loot": granary_loot,
		"field_loot": field_loot,
		"border_only": border_only,
		"attacker_loss_win": int(roundf(float(troops) * 0.05)),
		"defender_loss_win": int(roundf(float(troops) * (0.10 if border_only else 0.15))),
		"attacker_loss_lose": int(roundf(float(troops) * (0.20 if border_only else 0.25))),
		"defender_loss_lose": int(roundf(float(troops) * 0.04))
	}


static func conquest_odds(attacker: EvoTypes.Deme, defender: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	var troops := int(roundf(float(attacker.population) * CONQUEST_TROOP_SHARE))
	var attack := float(troops) * attack_multiplier(attacker, state) + flanking_support(attacker, defender, null, state)
	var defense := defense_power(defender, attacker.id, CONQUEST_MOBILIZATION, true, state, true)
	return {
		"p_win": win_probability(attack, defense),
		"troops": troops,
		"attacker_loss_win": int(roundf(float(troops) * 0.15)),
		"defender_loss_win": int(roundf(float(defender.population) * 0.30)),
		"attacker_loss_lose": int(roundf(float(troops) * 0.40)),
		"defender_loss_lose": int(roundf(float(defender.population) * 0.06))
	}
