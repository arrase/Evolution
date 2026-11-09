class_name EvoTypes
extends RefCounted

const BIOMES: Array[String] = [
	"tropical_forest",
	"savanna",
	"arid_steppe",
	"tundra",
	"high_mountain",
	"coastal_shallows",
	"ocean"
]

const ARCHETYPES: Array[String] = [
	"forage",
	"overexploit",
	"migrate",
	"cooperate",
	"exchange",
	"dispute",
	"innovate",
	"pact",
	"raid",
	"war",
	"betrayal"
]

const SPECIATION_PALETTE: Array[String] = [
	"#E07A5F",
	"#3D85C6",
	"#81B29A",
	"#F2CC8F",
	"#9B5DE5",
	"#F15BB5",
	"#00BBF9",
	"#00F5D4"
]

const EVENT_TYPES: Array[String] = [
	"pact", "betrayal", "raid", "tribute", "pillage",
	"war", "war_repelled", "siege", "fortify", "walled_union",
	"absorption", "colonize", "epidemic", "epidemic_spread",
	"epidemic_recovered", "famine", "extinction",
	"allopatric_speciation", "cultural_innovation", "baldwin_trait", "symbiosis"
]

const STATS_HISTORY_LIMIT: int = 200

const BIOME_CLIMATE_DEFAULTS: Dictionary = {
	"tropical_forest": {"temperature": 0.45, "humidity": 0.85, "min_alt": 0.28, "max_alt": 0.65, "regen": 0.28, "k_max": 600.0},
	"savanna": {"temperature": 0.50, "humidity": 0.40, "min_alt": 0.28, "max_alt": 0.65, "regen": 0.18, "k_max": 420.0},
	"arid_steppe": {"temperature": 0.65, "humidity": 0.20, "min_alt": 0.30, "max_alt": 0.70, "regen": 0.12, "k_max": 280.0},
	"tundra": {"temperature": -0.55, "humidity": 0.35, "min_alt": 0.35, "max_alt": 0.74, "regen": 0.10, "k_max": 240.0},
	"high_mountain": {"temperature": -0.40, "humidity": 0.25, "min_alt": 0.78, "max_alt": 0.98, "regen": 0.08, "k_max": 140.0},
	"coastal_shallows": {"temperature": 0.20, "humidity": 0.70, "min_alt": 0.14, "max_alt": 0.24, "regen": 0.20, "k_max": 260.0},
	"ocean": {"temperature": 0.10, "humidity": 0.90, "min_alt": 0.02, "max_alt": 0.08, "regen": 0.02, "k_max": 50.0}
}


class BiophysicalVector extends RefCounted:
	var metabolic_cost: float = 0.0
	var extraction_efficiency: float = 0.0
	var ecological_impact: float = 0.0
	var spatial_mobility: float = 0.0
	var social_cohesion: float = 0.0
	var transmission_threshold: float = 0.0

	func _init(
		p_cost: float = 0.0,
		p_extract: float = 0.0,
		p_eco: float = 0.0,
		p_mobility: float = 0.0,
		p_cohesion: float = 0.0,
		p_threshold: float = 0.0
	) -> void:
		metabolic_cost = p_cost
		extraction_efficiency = p_extract
		ecological_impact = p_eco
		spatial_mobility = p_mobility
		social_cohesion = p_cohesion
		transmission_threshold = p_threshold

	func duplicate_vec() -> BiophysicalVector:
		return BiophysicalVector.new(
			metabolic_cost,
			extraction_efficiency,
			ecological_impact,
			spatial_mobility,
			social_cohesion,
			transmission_threshold
		)

	func to_dict() -> Dictionary:
		return {
			"metabolicCost": metabolic_cost,
			"extractionEfficiency": extraction_efficiency,
			"ecologicalImpact": ecological_impact,
			"spatialMobility": spatial_mobility,
			"socialCohesion": social_cohesion,
			"transmissionThreshold": transmission_threshold
		}

	static func from_dict(d: Dictionary) -> BiophysicalVector:
		return BiophysicalVector.new(
			float(d["metabolicCost"]),
			float(d["extractionEfficiency"]),
			float(d["ecologicalImpact"]),
			float(d["spatialMobility"]),
			float(d["socialCohesion"]),
			float(d["transmissionThreshold"])
		)


class TraitDef extends RefCounted:
	var id: String = ""
	var name: String = ""
	var category: String = "biological" # "biological" | "cultural"
	var origin: String = "catalog" # "catalog" | "emergent" | "custom"
	var description: String = ""
	var vector: BiophysicalVector = BiophysicalVector.new()
	var mutually_exclusive_with: Array[String] = []
	var enables_cultural_transmission: bool = false

	func duplicate_trait() -> TraitDef:
		var t := TraitDef.new()
		t.id = id
		t.name = name
		t.category = category
		t.origin = origin
		t.description = description
		t.vector = vector.duplicate_vec()
		t.mutually_exclusive_with = mutually_exclusive_with.duplicate()
		t.enables_cultural_transmission = enables_cultural_transmission
		return t

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"category": category,
			"origin": origin,
			"description": description,
			"vector": vector.to_dict(),
			"mutuallyExclusiveWith": mutually_exclusive_with.duplicate(),
			"enablesCulturalTransmission": enables_cultural_transmission
		}

	static func from_dict(d: Dictionary) -> TraitDef:
		var t := TraitDef.new()
		t.id = str(d["id"])
		t.name = str(d["name"])
		t.category = str(d["category"])
		t.origin = str(d["origin"])
		t.description = str(d["description"])
		t.vector = BiophysicalVector.from_dict(d["vector"])
		t.mutually_exclusive_with = []
		for item in d["mutuallyExclusiveWith"]:
			t.mutually_exclusive_with.append(str(item))
		t.enables_cultural_transmission = bool(d["enablesCulturalTransmission"])
		return t


# Fixed catalog of action types a settlement can choose each turn ("forage", "raid", ...).
# `archetype` selects the village action sprite; `vector` feeds Baldwin assimilation.
class DecisionDef extends RefCounted:
	var id: String = ""
	var name: String = ""
	var archetype: String = "forage"
	var origin: String = "catalog"
	var description: String = ""
	var vector: BiophysicalVector = BiophysicalVector.new()

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"archetype": archetype,
			"origin": origin,
			"description": description,
			"vector": vector.to_dict()
		}

	static func from_dict(d: Dictionary) -> DecisionDef:
		var dec := DecisionDef.new()
		dec.id = str(d["id"])
		dec.name = str(d["name"])
		dec.archetype = str(d["archetype"])
		dec.origin = str(d["origin"])
		dec.description = str(d["description"])
		dec.vector = BiophysicalVector.from_dict(d["vector"])
		return dec


# Bilateral relationship between two settlements (keyed by `make_pair_key`).
class Relation extends RefCounted:
	var pact_turns: int = 0 # > 0 means an active alliance pact
	var trust: float = 0.0 # [-1, 1]
	var feud_turns: int = 0 # > 0 means active hostility after raids, betrayals or wars
	var truce_turns: int = 0 # > 0 after tribute was paid
	var proposal_from: String = "" # deme id that made a pending proposal
	var proposal_kind: String = "" # "pact" | "union" | "tribute"
	var proposal_amount: float = 0.0
	var proposal_gen: int = -1
	var last_event: String = ""

	func to_dict() -> Dictionary:
		return {
			"pactTurns": pact_turns,
			"trust": trust,
			"feudTurns": feud_turns,
			"truceTurns": truce_turns,
			"proposalFrom": proposal_from,
			"proposalKind": proposal_kind,
			"proposalAmount": proposal_amount,
			"proposalGen": proposal_gen,
			"lastEvent": last_event
		}

	static func from_dict(d: Dictionary) -> Relation:
		var r := Relation.new()
		r.pact_turns = int(d["pactTurns"])
		r.trust = float(d["trust"])
		r.feud_turns = int(d["feudTurns"])
		r.truce_turns = int(d["truceTurns"])
		r.proposal_from = str(d["proposalFrom"])
		r.proposal_kind = str(d["proposalKind"])
		r.proposal_amount = float(d["proposalAmount"])
		r.proposal_gen = int(d["proposalGen"])
		r.last_event = str(d["lastEvent"])
		return r


class StrategyDef extends RefCounted:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon: String = "🛡️"
	var color: String = "#10B981"
	var origin: String = "base" # "base" | "user"
	var doctrine: String = "" # cultural persona given to the decision model
	var biological_trait_ids: Array[String] = []
	var cultural_trait_ids: Array[String] = []

	func duplicate_strategy() -> StrategyDef:
		var s := StrategyDef.new()
		s.id = id
		s.name = name
		s.description = description
		s.icon = icon
		s.color = color
		s.origin = origin
		s.doctrine = doctrine
		s.biological_trait_ids = biological_trait_ids.duplicate()
		s.cultural_trait_ids = cultural_trait_ids.duplicate()
		return s

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"description": description,
			"icon": icon,
			"color": color,
			"origin": origin,
			"doctrine": doctrine,
			"biological_trait_ids": biological_trait_ids.duplicate(),
			"cultural_trait_ids": cultural_trait_ids.duplicate()
		}

	static func from_dict(data: Dictionary) -> StrategyDef:
		var s := StrategyDef.new()
		s.id = str(data["id"])
		s.name = str(data["name"])
		s.description = str(data["description"]) if data.has("description") else ""
		s.icon = str(data["icon"]) if data.has("icon") else "🛡️"
		s.color = str(data["color"]) if data.has("color") else "#10B981"
		s.origin = str(data["origin"]) if data.has("origin") else "base"
		s.doctrine = str(data["doctrine"]) if data.has("doctrine") else ""
		s.biological_trait_ids = []
		for item in data["biological_trait_ids"]:
			s.biological_trait_ids.append(str(item))
		s.cultural_trait_ids = []
		for item in data["cultural_trait_ids"]:
			s.cultural_trait_ids.append(str(item))
		return s


class HexCell extends RefCounted:
	var id: String = "0,0"
	var q: int = 0
	var r: int = 0
	var s: int = 0
	var biome: String = "savanna"
	var temperature: float = 0.5
	var humidity: float = 0.4
	var altitude: float = 0.4
	var current_resources: float = 300.0
	var carrying_capacity: float = 400.0
	var carrying_capacity_max: float = 450.0
	var seasonal_regen_rate: float = 0.18
	var deme_ids: Array[String] = []
	var land_use: String = "wild"
	var owner_deme_id: String = ""
	var has_ruins: bool = false

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"q": q,
			"r": r,
			"s": s,
			"biome": biome,
			"temperature": temperature,
			"humidity": humidity,
			"altitude": altitude,
			"currentResources": current_resources,
			"carryingCapacity": carrying_capacity,
			"carryingCapacityMax": carrying_capacity_max,
			"seasonalRegenRate": seasonal_regen_rate,
			"demeIds": deme_ids.duplicate(),
			"landUse": land_use,
			"ownerDemeId": owner_deme_id,
			"hasRuins": has_ruins
		}

	static func from_dict(d: Dictionary) -> HexCell:
		var c := HexCell.new()
		c.id = str(d["id"])
		c.q = int(d["q"])
		c.r = int(d["r"])
		c.s = int(d["s"])
		c.biome = str(d["biome"])
		c.temperature = float(d["temperature"])
		c.humidity = float(d["humidity"])
		c.altitude = float(d["altitude"])
		c.current_resources = float(d["currentResources"])
		c.carrying_capacity = float(d["carryingCapacity"])
		c.carrying_capacity_max = float(d["carryingCapacityMax"])
		c.seasonal_regen_rate = float(d["seasonalRegenRate"])
		c.deme_ids = []
		for item in d["demeIds"]:
			c.deme_ids.append(str(item))
		if d.has("landUse"):
			c.land_use = str(d["landUse"])
		if d.has("ownerDemeId"):
			c.owner_deme_id = str(d["ownerDemeId"])
		if d.has("hasRuins"):
			c.has_ruins = bool(d["hasRuins"])
		return c


class Deme extends RefCounted:
	var id: String = ""
	var name: String = ""
	var lineage_id: String = ""
	var strategy_id: String = ""
	var color: String = "#E07A5F"
	var hex_id: String = "0,0"
	var population: int = 100
	var energy_reserves: float = 100.0
	var last_energy_delta: float = 0.0
	var biological_trait_ids: Array[String] = []
	var cultural_trait_ids: Array[String] = []
	var baldwin_counters: Dictionary = {} # String -> int
	var innovation_counter: float = 0.0
	var isolation_turns: int = 0
	var decision_model_tag: String = EvoUserSettings.primary_model
	var last_confidence: float = 0.0
	var chosen_action: Dictionary = {"key": "forage", "type": "forage", "target": ""}
	var action_probabilities: Dictionary = {} # action key -> probability from the decision model
	var action_forecasts: Dictionary = {} # action key -> forecast text shown to the decision model
	var last_outcome: String = ""
	var memory: Array[String] = []
	var reputation: float = 0.0 # [-1, 1], visible to every neighbor
	var defense_tier: int = 0
	var merged_count: int = 0
	var secondary_color: String = ""
	var salubrity: float = 1.0
	var walled_union_id: String = ""
	var infection_turns: int = 0
	var immunity_turns: int = 0
	var last_food_intake: float = 0.0
	var last_food_need: float = 0.0
	var last_population_delta: int = 0

	func duplicate_deme() -> Deme:
		var d := Deme.new()
		d.id = id
		d.name = name
		d.lineage_id = lineage_id
		d.strategy_id = strategy_id
		d.color = color
		d.hex_id = hex_id
		d.population = population
		d.energy_reserves = energy_reserves
		d.last_energy_delta = last_energy_delta
		d.biological_trait_ids = biological_trait_ids.duplicate()
		d.cultural_trait_ids = cultural_trait_ids.duplicate()
		d.baldwin_counters = baldwin_counters.duplicate()
		d.innovation_counter = innovation_counter
		d.isolation_turns = isolation_turns
		d.decision_model_tag = decision_model_tag
		d.last_confidence = last_confidence
		d.chosen_action = chosen_action.duplicate()
		d.action_probabilities = action_probabilities.duplicate()
		d.action_forecasts = action_forecasts.duplicate()
		d.last_outcome = last_outcome
		d.memory = memory.duplicate()
		d.reputation = reputation
		d.defense_tier = defense_tier
		d.merged_count = merged_count
		d.secondary_color = secondary_color
		d.salubrity = salubrity
		d.walled_union_id = walled_union_id
		d.infection_turns = infection_turns
		d.immunity_turns = immunity_turns
		d.last_food_intake = last_food_intake
		d.last_food_need = last_food_need
		d.last_population_delta = last_population_delta
		return d

	func get_vital_status() -> String:
		if population <= 0:
			return "extinct"
		if energy_reserves < 25.0 or last_energy_delta <= -10.0:
			return "starving"
		if (last_energy_delta >= 10.0 and energy_reserves >= 40.0) or energy_reserves >= 120.0:
			return "thriving"
		if last_energy_delta < -5.0:
			return "declining"
		return "stable"

	func get_village_tier() -> int:
		if population >= 380 or (population >= 280 and (defense_tier >= 2 or merged_count >= 1 or walled_union_id != "")):
			return 4
		if population >= 240 or (population >= 170 and (defense_tier >= 1 or merged_count >= 1)):
			return 3
		if population >= 120 or defense_tier == 1:
			return 2
		return 1

	func get_village_roman() -> String:
		var tier := get_village_tier()
		if tier == 4:
			return "IV"
		if tier == 3:
			return "III"
		if tier == 2:
			return "II"
		return "I"

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"lineageId": lineage_id,
			"strategy_id": strategy_id,
			"color": color,
			"hexId": hex_id,
			"population": population,
			"energyReserves": energy_reserves,
			"lastEnergyDelta": last_energy_delta,
			"biologicalTraitIds": biological_trait_ids.duplicate(),
			"culturalTraitIds": cultural_trait_ids.duplicate(),
			"baldwinCounters": baldwin_counters.duplicate(),
			"innovationCounter": innovation_counter,
			"isolationTurns": isolation_turns,
			"decisionModelTag": decision_model_tag,
			"lastConfidence": last_confidence,
			"chosenAction": chosen_action.duplicate(),
			"actionProbabilities": action_probabilities.duplicate(),
			"actionForecasts": action_forecasts.duplicate(),
			"lastOutcome": last_outcome,
			"memory": memory.duplicate(),
			"reputation": reputation,
			"defenseTier": defense_tier,
			"mergedCount": merged_count,
			"secondaryColor": secondary_color,
			"salubrity": salubrity,
			"walledUnionId": walled_union_id,
			"infectionTurns": infection_turns,
			"immunityTurns": immunity_turns,
			"lastFoodIntake": last_food_intake,
			"lastFoodNeed": last_food_need,
			"lastPopulationDelta": last_population_delta
		}

	static func from_dict(dict_data: Dictionary) -> Deme:
		var d := Deme.new()
		d.id = str(dict_data["id"])
		d.name = str(dict_data["name"])
		d.lineage_id = str(dict_data["lineageId"])
		d.strategy_id = str(dict_data["strategy_id"])
		d.color = str(dict_data["color"])
		d.hex_id = str(dict_data["hexId"])
		d.population = int(dict_data["population"])
		d.energy_reserves = float(dict_data["energyReserves"])
		d.last_energy_delta = float(dict_data["lastEnergyDelta"])
		d.biological_trait_ids = []
		for item in dict_data["biologicalTraitIds"]:
			d.biological_trait_ids.append(str(item))
		d.cultural_trait_ids = []
		for item in dict_data["culturalTraitIds"]:
			d.cultural_trait_ids.append(str(item))
		d.baldwin_counters = {}
		var raw_bc: Dictionary = dict_data["baldwinCounters"]
		for k in raw_bc.keys():
			d.baldwin_counters[str(k)] = int(raw_bc[k])
		d.innovation_counter = float(dict_data["innovationCounter"])
		d.isolation_turns = int(dict_data["isolationTurns"])
		d.decision_model_tag = str(dict_data["decisionModelTag"])
		d.last_confidence = float(dict_data["lastConfidence"])
		d.chosen_action = (dict_data["chosenAction"] as Dictionary).duplicate()
		d.action_probabilities = (dict_data["actionProbabilities"] as Dictionary).duplicate()
		d.action_forecasts = (dict_data["actionForecasts"] as Dictionary).duplicate()
		d.last_outcome = str(dict_data["lastOutcome"])
		d.memory = []
		for item in dict_data["memory"]:
			d.memory.append(str(item))
		d.reputation = float(dict_data["reputation"])
		d.defense_tier = int(dict_data["defenseTier"])
		d.merged_count = int(dict_data["mergedCount"])
		d.secondary_color = str(dict_data["secondaryColor"])
		d.salubrity = float(dict_data["salubrity"])
		d.walled_union_id = str(dict_data["walledUnionId"])
		d.infection_turns = int(dict_data["infectionTurns"])
		d.immunity_turns = int(dict_data["immunityTurns"])
		d.last_food_intake = float(dict_data["lastFoodIntake"])
		d.last_food_need = float(dict_data["lastFoodNeed"])
		d.last_population_delta = int(dict_data["lastPopulationDelta"])
		return d


class LineageNode extends RefCounted:
	var id: String = ""
	var name: String = ""
	var parent_id: String = ""
	var strategy_id: String = ""
	var color: String = "#E07A5F"
	var founded_generation: int = 0
	var extinct_generation: int = -1
	var founder_hex_id: String = "0,0"
	var divergence_reason: String = "initial" # "initial" | "allopatric_speciation" | "cultural_schism" | "baldwin_assimilation"
	var acquired_trait_ids: Array[String] = []
	var biological_trait_ids: Array[String] = []
	var cultural_trait_ids: Array[String] = []

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"parentId": parent_id,
			"strategy_id": strategy_id,
			"color": color,
			"foundedGeneration": founded_generation,
			"extinctGeneration": extinct_generation,
			"founderHexId": founder_hex_id,
			"divergenceReason": divergence_reason,
			"acquiredTraitIds": acquired_trait_ids.duplicate(),
			"biologicalTraitIds": biological_trait_ids.duplicate(),
			"culturalTraitIds": cultural_trait_ids.duplicate()
		}

	static func from_dict(d: Dictionary) -> LineageNode:
		var n := LineageNode.new()
		n.id = str(d["id"])
		n.name = str(d["name"])
		n.parent_id = str(d["parentId"]) if d.has("parentId") and d["parentId"] != null else ""
		n.strategy_id = str(d["strategy_id"])
		n.color = str(d["color"])
		n.founded_generation = int(d["foundedGeneration"])
		n.extinct_generation = int(d["extinctGeneration"]) if d.has("extinctGeneration") and d["extinctGeneration"] != null else -1
		n.founder_hex_id = str(d["founderHexId"])
		n.divergence_reason = str(d["divergenceReason"])
		n.acquired_trait_ids = []
		for item in d["acquiredTraitIds"]:
			n.acquired_trait_ids.append(str(item))
		n.biological_trait_ids = []
		if d.has("biologicalTraitIds"):
			for item in d["biologicalTraitIds"]:
				n.biological_trait_ids.append(str(item))
		n.cultural_trait_ids = []
		if d.has("culturalTraitIds"):
			for item in d["culturalTraitIds"]:
				n.cultural_trait_ids.append(str(item))
		return n


class ChronicleEntry extends RefCounted:
	var id: String = ""
	var generation: int = 0
	var event_type: String = "" # "baldwin_trait" | "cultural_innovation" | "allopatric_speciation" | "extinction" | "tragedy_of_commons" | "symbiosis" | "cultural_loss" | "war" | "raid" | "pact" | "betrayal"
	var title: String = ""
	var causal_explanation: String = ""
	var hex_id: String = "0,0"
	var deme_id: String = ""
	var lineage_id: String = ""
	var trait_id: String = ""

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"generation": generation,
			"event_type": event_type,
			"title": title,
			"causal_explanation": causal_explanation,
			"hexId": hex_id,
			"demeId": deme_id,
			"lineageId": lineage_id,
			"traitId": trait_id
		}

	static func from_dict(d: Dictionary) -> ChronicleEntry:
		var e := ChronicleEntry.new()
		e.id = str(d["id"])
		e.generation = int(d["generation"])
		e.event_type = str(d["event_type"])
		e.title = str(d["title"])
		e.causal_explanation = str(d["causal_explanation"])
		e.hex_id = str(d["hexId"])
		e.deme_id = str(d["demeId"]) if d.has("demeId") else ""
		e.lineage_id = str(d["lineageId"]) if d.has("lineageId") else ""
		e.trait_id = str(d["traitId"]) if d.has("traitId") else ""
		return e


class HexEdgeFlow extends RefCounted:
	var from_hex_id: String = "0,0"
	var to_hex_id: String = "0,0"
	var flow_type: String = "migration" # "migration" | "exchange" | "dispute" | "merge" | "war" | "raid" | "pact" | "betrayal"
	var intensity: float = 0.5
	var from_deme_id: String = ""
	var to_deme_id: String = ""

	func to_dict() -> Dictionary:
		return {
			"fromHexId": from_hex_id,
			"toHexId": to_hex_id,
			"flow_type": flow_type,
			"intensity": intensity,
			"fromDemeId": from_deme_id,
			"toDemeId": to_deme_id
		}

	static func from_dict(d: Dictionary) -> HexEdgeFlow:
		var f := HexEdgeFlow.new()
		f.from_hex_id = str(d["fromHexId"])
		f.to_hex_id = str(d["toHexId"])
		f.flow_type = str(d["flow_type"])
		f.intensity = float(d["intensity"])
		f.from_deme_id = str(d["fromDemeId"]) if d.has("fromDemeId") else ""
		f.to_deme_id = str(d["toDemeId"]) if d.has("toDemeId") else ""
		return f


class WorldState extends RefCounted:
	var preset_id: String = "preset-rift-savanna"
	var world_name: String = "The Rift and the Savanna"
	var generation: int = 0
	var season: String = "wet_warm" # "wet_warm" | "dry_cold"
	var map_radius: int = 5
	var sea_level: float = 0.12
	var glacial_sea_level_cycle: bool = false
	var selective_pressure_points: int = 30
	var selective_pressure_regen_per_turn: int = 15
	var unlimited_pressure_mode: bool = false
	var free_sandbox_mode: bool = false
	var auto_pause_on_milestone: bool = false
	var cells: Dictionary = {} # String (hex_id) -> HexCell
	var demes: Dictionary = {} # String (deme_id) -> Deme
	var traits_catalog: Dictionary = {} # String (trait_id) -> TraitDef
	var decisions_catalog: Dictionary = {} # String (decision_id) -> DecisionDef
	var strategies_catalog: Dictionary = {} # String (strategy_id) -> StrategyDef
	var strategy_a_id: String = "strat-cooperation"
	var strategy_b_id: String = "strat-war"
	var lineage_tree: Dictionary = {} # String (lineage_id) -> LineageNode
	var chronicle: Array[ChronicleEntry] = []
	var active_flows: Array[HexEdgeFlow] = []
	var relations: Dictionary = {} # pair_key ("idA__idB" sorted) -> Relation
	var rng_seed: int = 1
	var rng := RandomNumberGenerator.new()
	var recent_extinction_hexes: Array[String] = [] # hex_ids that had real extinction this turn
	var disused_connections: Array[Dictionary] = [] # previous turn roads/bridges
	var quiet_turns: int = 0
	var previous_populations: Dictionary = {} # String (deme_id) -> int
	var macro_outcome_type: String = "" # "" | "total_extinction" | "single_survivor" | "ecological_equilibrium"
	var macro_outcome_title: String = ""
	var macro_outcome_summary: String = ""
	var turn_events: Array[Dictionary] = []
	var stats_history: Array[Dictionary] = []

	func to_dict() -> Dictionary:
		var cells_dict := {}
		for k in cells.keys():
			cells_dict[k] = (cells[k] as HexCell).to_dict()
		var demes_dict := {}
		for k in demes.keys():
			demes_dict[k] = (demes[k] as Deme).to_dict()
		var traits_dict := {}
		for k in traits_catalog.keys():
			traits_dict[k] = (traits_catalog[k] as TraitDef).to_dict()
		var decisions_dict := {}
		for k in decisions_catalog.keys():
			decisions_dict[k] = (decisions_catalog[k] as DecisionDef).to_dict()
		var strategies_dict := {}
		for k in strategies_catalog.keys():
			strategies_dict[k] = (strategies_catalog[k] as StrategyDef).to_dict()
		var lineage_dict := {}
		for k in lineage_tree.keys():
			lineage_dict[k] = (lineage_tree[k] as LineageNode).to_dict()
		var chron_arr := []
		for entry in chronicle:
			chron_arr.append(entry.to_dict())
		var flows_arr := []
		for fl in active_flows:
			flows_arr.append(fl.to_dict())
		var relations_dict := {}
		for k in relations.keys():
			relations_dict[k] = (relations[k] as Relation).to_dict()
		return {
			"presetId": preset_id,
			"worldName": world_name,
			"generation": generation,
			"season": season,
			"mapRadius": map_radius,
			"seaLevel": sea_level,
			"glacialSeaLevelCycle": glacial_sea_level_cycle,
			"selectivePressurePoints": selective_pressure_points,
			"selectivePressureRegenPerTurn": selective_pressure_regen_per_turn,
			"unlimitedPressureMode": unlimited_pressure_mode,
			"freeSandboxMode": free_sandbox_mode,
			"autoPauseOnMilestone": auto_pause_on_milestone,
			"strategy_a_id": strategy_a_id,
			"strategy_b_id": strategy_b_id,
			"cells": cells_dict,
			"demes": demes_dict,
			"traitsCatalog": traits_dict,
			"decisionsCatalog": decisions_dict,
			"strategies_catalog": strategies_dict,
			"lineageTree": lineage_dict,
			"chronicle": chron_arr,
			"activeFlows": flows_arr,
			"relations": relations_dict,
			"rngSeed": rng_seed,
			"rngState": rng.state,
			"recentExtinctionHexes": recent_extinction_hexes.duplicate(),
			"disusedConnections": disused_connections.duplicate(true),
			"quietTurns": quiet_turns,
			"previousPopulations": previous_populations.duplicate(),
			"macroOutcomeType": macro_outcome_type,
			"macroOutcomeTitle": macro_outcome_title,
			"macroOutcomeSummary": macro_outcome_summary,
			"statsHistory": stats_history.duplicate(true)
		}

	static func from_dict(d: Dictionary) -> WorldState:
		var s := WorldState.new()
		s.preset_id = str(d["presetId"])
		s.world_name = str(d["worldName"])
		s.generation = int(d["generation"])
		s.season = str(d["season"])
		s.map_radius = int(d["mapRadius"])
		s.sea_level = float(d["seaLevel"])
		s.glacial_sea_level_cycle = bool(d["glacialSeaLevelCycle"])
		s.selective_pressure_points = int(d["selectivePressurePoints"])
		s.selective_pressure_regen_per_turn = int(d["selectivePressureRegenPerTurn"])
		s.unlimited_pressure_mode = bool(d["unlimitedPressureMode"])
		s.free_sandbox_mode = bool(d["freeSandboxMode"])
		s.auto_pause_on_milestone = bool(d["autoPauseOnMilestone"])
		s.strategy_a_id = str(d["strategy_a_id"])
		s.strategy_b_id = str(d["strategy_b_id"])
		for k in d["cells"].keys():
			s.cells[str(k)] = HexCell.from_dict(d["cells"][k])
		for k in d["demes"].keys():
			s.demes[str(k)] = Deme.from_dict(d["demes"][k])
		for cid in s.cells.keys():
			(s.cells[cid] as HexCell).deme_ids.clear()
		var invalid_deme_ids: Array[String] = []
		for did in s.demes.keys():
			var dm: Deme = s.demes[did]
			if not s.cells.has(dm.hex_id):
				invalid_deme_ids.append(did)
				continue
			var host_cell: HexCell = s.cells[dm.hex_id]
			host_cell.deme_ids.append(dm.id)
		for did in invalid_deme_ids:
			s.demes.erase(did)
		for k in d["traitsCatalog"].keys():
			s.traits_catalog[str(k)] = TraitDef.from_dict(d["traitsCatalog"][k])
		for k in d["decisionsCatalog"].keys():
			s.decisions_catalog[str(k)] = DecisionDef.from_dict(d["decisionsCatalog"][k])
		var raw_strats: Dictionary = d["strategies_catalog"]
		for k in raw_strats.keys():
			s.strategies_catalog[str(k)] = StrategyDef.from_dict(raw_strats[k])
		for k in d["lineageTree"].keys():
			s.lineage_tree[str(k)] = LineageNode.from_dict(d["lineageTree"][k])
		for item in d["chronicle"]:
			s.chronicle.append(ChronicleEntry.from_dict(item))
		for item in d["activeFlows"]:
			s.active_flows.append(HexEdgeFlow.from_dict(item))
		s.relations = {}
		var raw_relations: Dictionary = d["relations"]
		for k in raw_relations.keys():
			s.relations[str(k)] = Relation.from_dict(raw_relations[k])
		s.rng_seed = int(d["rngSeed"])
		s.rng.seed = s.rng_seed
		s.rng.state = int(d["rngState"])
		s.recent_extinction_hexes = []
		if d.has("recentExtinctionHexes"):
			for item in d["recentExtinctionHexes"]:
				s.recent_extinction_hexes.append(str(item))
		s.disused_connections = []
		if d.has("disusedConnections"):
			for item in d["disusedConnections"]:
				if item is Dictionary:
					s.disused_connections.append((item as Dictionary).duplicate(true))
		s.quiet_turns = int(d["quietTurns"]) if d.has("quietTurns") else 0
		s.previous_populations = {}
		if d.has("previousPopulations"):
			var raw_prev: Dictionary = d["previousPopulations"]
			for k in raw_prev.keys():
				s.previous_populations[str(k)] = int(raw_prev[k])
		else:
			for deme_id in s.demes.keys():
				s.previous_populations[str(deme_id)] = (s.demes[deme_id] as Deme).population
		s.macro_outcome_type = str(d["macroOutcomeType"]) if d.has("macroOutcomeType") else ""
		s.macro_outcome_title = str(d["macroOutcomeTitle"]) if d.has("macroOutcomeTitle") else ""
		s.macro_outcome_summary = str(d["macroOutcomeSummary"]) if d.has("macroOutcomeSummary") else ""
		s.stats_history = []
		for item in d["statsHistory"]:
			s.stats_history.append((item as Dictionary).duplicate(true))
		return s


static func push_event(
	state: WorldState,
	type: String,
	from_hex: String,
	to_hex: String,
	from_deme: String,
	to_deme: String = "",
	magnitude: float = 0.0,
	casualties: int = 0
) -> void:
	var actor_color := ""
	if state.demes.has(from_deme):
		var d: Deme = state.demes[from_deme]
		actor_color = (state.strategies_catalog[d.strategy_id] as StrategyDef).color if state.strategies_catalog.has(d.strategy_id) else d.color
	state.turn_events.append({
		"type": type,
		"from_hex": from_hex,
		"to_hex": to_hex if to_hex != "" else from_hex,
		"from_deme": from_deme,
		"to_deme": to_deme,
		"actor_color": actor_color,
		"magnitude": magnitude,
		"casualties": casualties
	})


static func _is_side_b_deme(state: WorldState, d: Deme) -> bool:
	if state.strategy_a_id != state.strategy_b_id:
		if d.strategy_id == state.strategy_b_id:
			return true
		if d.strategy_id == state.strategy_a_id:
			return false
	return d.id.begins_with("deme-rift-east") or d.id.begins_with("deme-darwin-rival") or d.id.begins_with("deme-island-2")


static func compute_world_stats(state: WorldState) -> Dictionary:
	var side_a := {
		"strategy_id": state.strategy_a_id,
		"villages": 0,
		"population": 0,
		"pop_delta": 0,
		"reserves": 0.0,
		"food_intake": 0.0,
		"food_need": 0.0,
		"food_ratio": 1.0,
		"salubrity_avg": 1.0,
		"infected": 0,
		"starving": 0,
		"rural_hexes": 0
	}
	var side_b := {
		"strategy_id": state.strategy_b_id,
		"villages": 0,
		"population": 0,
		"pop_delta": 0,
		"reserves": 0.0,
		"food_intake": 0.0,
		"food_need": 0.0,
		"food_ratio": 1.0,
		"salubrity_avg": 1.0,
		"infected": 0,
		"starving": 0,
		"rural_hexes": 0
	}
	var sal_sum_a: float = 0.0
	var sal_sum_b: float = 0.0
	var union_ids: Dictionary = {}

	for d: Deme in state.demes.values():
		if d.population <= 0:
			continue
		if d.walled_union_id != "":
			union_ids[d.walled_union_id] = true
		var is_b := _is_side_b_deme(state, d)
		var target: Dictionary = side_b if is_b else side_a
		target["villages"] = int(target["villages"]) + 1
		target["population"] = int(target["population"]) + d.population
		target["pop_delta"] = int(target["pop_delta"]) + d.last_population_delta
		target["reserves"] = float(target["reserves"]) + d.energy_reserves
		target["food_intake"] = float(target["food_intake"]) + d.last_food_intake
		target["food_need"] = float(target["food_need"]) + d.last_food_need
		if d.infection_turns > 0:
			target["infected"] = int(target["infected"]) + 1
		if d.get_vital_status() == "starving":
			target["starving"] = int(target["starving"]) + 1
		if is_b:
			sal_sum_b += d.salubrity
		else:
			sal_sum_a += d.salubrity

	for c: HexCell in state.cells.values():
		if c.owner_deme_id != "" and (c.land_use == "crops" or c.land_use == "pasture") and state.demes.has(c.owner_deme_id):
			var owner: Deme = state.demes[c.owner_deme_id]
			var target: Dictionary = side_b if _is_side_b_deme(state, owner) else side_a
			target["rural_hexes"] = int(target["rural_hexes"]) + 1

	var v_a := int(side_a["villages"])
	var v_b := int(side_b["villages"])
	var need_a := float(side_a["food_need"])
	var need_b := float(side_b["food_need"])
	side_a["food_ratio"] = clampf(float(side_a["food_intake"]) / maxf(1.0, need_a), 0.0, 2.0) if need_a > 0.0 else (1.0 if v_a > 0 else 0.0)
	side_b["food_ratio"] = clampf(float(side_b["food_intake"]) / maxf(1.0, need_b), 0.0, 2.0) if need_b > 0.0 else (1.0 if v_b > 0 else 0.0)
	side_a["salubrity_avg"] = (sal_sum_a / float(v_a)) if v_a > 0 else 0.0
	side_b["salubrity_avg"] = (sal_sum_b / float(v_b)) if v_b > 0 else 0.0

	var pacts_count: int = 0
	var vendettas_count: int = 0
	for pk in state.relations.keys():
		var rel: Relation = state.relations[pk]
		if rel.pact_turns > 0:
			pacts_count += 1
		elif rel.feud_turns > 0:
			vendettas_count += 1

	var wars_count: int = 0
	for ev in state.turn_events:
		if str(ev["type"]) in ["war", "war_repelled", "siege", "raid", "betrayal"]:
			wars_count += 1

	return {
		"generation": state.generation,
		"a": side_a,
		"b": side_b,
		"pacts": pacts_count,
		"vendettas": vendettas_count,
		"unions": union_ids.size(),
		"wars": wars_count
	}


static func record_turn_stats(state: WorldState) -> void:
	var snap := compute_world_stats(state)
	if not state.stats_history.is_empty() and int(state.stats_history.back()["generation"]) == state.generation:
		state.stats_history[state.stats_history.size() - 1] = snap
	else:
		state.stats_history.append(snap)
	while state.stats_history.size() > STATS_HISTORY_LIMIT:
		state.stats_history.pop_front()


static func make_pair_key(id_a: String, id_b: String) -> String:
	return (id_a + "__" + id_b) if id_a < id_b else (id_b + "__" + id_a)


static func is_pact_active(state: WorldState, id_a: String, id_b: String) -> bool:
	var key := make_pair_key(id_a, id_b)
	return state.relations.has(key) and (state.relations[key] as Relation).pact_turns > 0


static func is_vendetta_active(state: WorldState, id_a: String, id_b: String) -> bool:
	var key := make_pair_key(id_a, id_b)
	return state.relations.has(key) and (state.relations[key] as Relation).feud_turns > 0


static func get_relation(state: WorldState, id_a: String, id_b: String) -> Relation:
	var key := make_pair_key(id_a, id_b)
	if not state.relations.has(key):
		state.relations[key] = Relation.new()
	return state.relations[key]


static func pair_partner(pair_key: String, deme_id: String) -> String:
	var parts := pair_key.split("__")
	if parts[0] == deme_id:
		return parts[1]
	if parts[1] == deme_id:
		return parts[0]
	return ""


static func erase_deme_relations(state: WorldState, deme_id: String) -> void:
	for pk in state.relations.keys():
		if pair_partner(str(pk), deme_id) != "":
			state.relations.erase(pk)
