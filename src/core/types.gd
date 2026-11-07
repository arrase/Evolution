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
	"custom"
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


class DecisionDef extends RefCounted:
	var id: String = ""
	var name: String = ""
	var archetype: String = "forage"
	var origin: String = "catalog"
	var description: String = ""
	var vector: BiophysicalVector = BiophysicalVector.new()
	var required_trait_ids: Array[String] = []

	func duplicate_decision() -> DecisionDef:
		var dec := DecisionDef.new()
		dec.id = id
		dec.name = name
		dec.archetype = archetype
		dec.origin = origin
		dec.description = description
		dec.vector = vector.duplicate_vec()
		dec.required_trait_ids = required_trait_ids.duplicate()
		return dec

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"archetype": archetype,
			"origin": origin,
			"description": description,
			"vector": vector.to_dict(),
			"requiredTraitIds": required_trait_ids.duplicate()
		}

	static func from_dict(d: Dictionary) -> DecisionDef:
		var dec := DecisionDef.new()
		dec.id = str(d["id"])
		dec.name = str(d["name"])
		dec.archetype = str(d["archetype"])
		dec.origin = str(d["origin"]) if d.has("origin") else "catalog"
		dec.description = str(d["description"])
		dec.vector = BiophysicalVector.from_dict(d["vector"])
		dec.required_trait_ids = []
		for item in d["requiredTraitIds"]:
			dec.required_trait_ids.append(str(item))
		return dec


class StrategyDef extends RefCounted:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon: String = "🛡️"
	var color: String = "#10B981"
	var origin: String = "base" # "base" | "user"
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
			"biologicalTraitIds": biological_trait_ids.duplicate(),
			"culturalTraitIds": cultural_trait_ids.duplicate(),
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
		s.biological_trait_ids = []
		var raw_bio: Array = data["biologicalTraitIds"] if data.has("biologicalTraitIds") else (data["biological_trait_ids"] if data.has("biological_trait_ids") else [])
		for item in raw_bio:
			s.biological_trait_ids.append(str(item))
		s.cultural_trait_ids = []
		var raw_cul: Array = data["culturalTraitIds"] if data.has("culturalTraitIds") else (data["cultural_trait_ids"] if data.has("cultural_trait_ids") else [])
		for item in raw_cul:
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

	func duplicate_cell() -> HexCell:
		var c := HexCell.new()
		c.id = id
		c.q = q
		c.r = r
		c.s = s
		c.biome = biome
		c.temperature = temperature
		c.humidity = humidity
		c.altitude = altitude
		c.current_resources = current_resources
		c.carrying_capacity = carrying_capacity
		c.carrying_capacity_max = carrying_capacity_max
		c.seasonal_regen_rate = seasonal_regen_rate
		c.deme_ids = deme_ids.duplicate()
		return c

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
			"demeIds": deme_ids.duplicate()
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
	var last_confidence: float = 0.85
	var last_decision_probabilities: Dictionary = {"dec-conservative-forage": 1.0} # String -> float
	var last_dominant_decision_id: String = "dec-conservative-forage"
	var last_justification: String = ""

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
		d.last_decision_probabilities = last_decision_probabilities.duplicate()
		d.last_dominant_decision_id = last_dominant_decision_id
		d.last_justification = last_justification
		return d

	func get_vital_status() -> String:
		if last_energy_delta >= 10.0:
			return "thriving"
		if last_energy_delta >= 0.0:
			return "stable"
		if energy_reserves > 40.0:
			return "struggling"
		return "starving"

	func get_village_tier() -> int:
		if population >= 400:
			return 4
		if population >= 150:
			return 3
		if population >= 50:
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
			"strategyId": strategy_id,
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
			"lastDecisionProbabilities": last_decision_probabilities.duplicate(),
			"lastDominantDecisionId": last_dominant_decision_id,
			"lastJustification": last_justification
		}

	static func from_dict(dict_data: Dictionary) -> Deme:
		var d := Deme.new()
		d.id = str(dict_data["id"])
		d.name = str(dict_data["name"])
		d.lineage_id = str(dict_data["lineageId"])
		if dict_data.has("strategyId"):
			d.strategy_id = str(dict_data["strategyId"])
		elif dict_data.has("strategy_id"):
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
		d.decision_model_tag = str(dict_data["decisionModelTag"]) if dict_data.has("decisionModelTag") else EvoUserSettings.primary_model
		d.last_confidence = float(dict_data["lastConfidence"]) if dict_data.has("lastConfidence") else 0.85
		d.last_dominant_decision_id = str(dict_data["lastDominantDecisionId"])
		d.last_decision_probabilities = {}
		var raw_probs: Dictionary = dict_data["lastDecisionProbabilities"]
		for k in raw_probs.keys():
			d.last_decision_probabilities[str(k)] = float(raw_probs[k])
		if d.last_decision_probabilities.is_empty():
			var fallback_dec_id := d.last_dominant_decision_id if d.last_dominant_decision_id != "" else "dec-conservative-forage"
			d.last_decision_probabilities = {fallback_dec_id: 1.0}
		d.last_justification = str(dict_data["lastJustification"])
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

	func duplicate_node() -> LineageNode:
		var n := LineageNode.new()
		n.id = id
		n.name = name
		n.parent_id = parent_id
		n.strategy_id = strategy_id
		n.color = color
		n.founded_generation = founded_generation
		n.extinct_generation = extinct_generation
		n.founder_hex_id = founder_hex_id
		n.divergence_reason = divergence_reason
		n.acquired_trait_ids = acquired_trait_ids.duplicate()
		n.biological_trait_ids = biological_trait_ids.duplicate()
		n.cultural_trait_ids = cultural_trait_ids.duplicate()
		return n

	func duplicate_lineage() -> LineageNode:
		return duplicate_node()

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"parentId": parent_id,
			"strategyId": strategy_id,
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
		if d.has("strategyId"):
			n.strategy_id = str(d["strategyId"])
		elif d.has("strategy_id"):
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
	var event_type: String = "" # "baldwin_trait" | "cultural_innovation" | "allopatric_speciation" | "extinction" | "tragedy_of_commons" | "symbiosis" | "cultural_loss"
	var title: String = ""
	var causal_explanation: String = ""
	var hex_id: String = "0,0"
	var deme_id: String = ""
	var lineage_id: String = ""
	var trait_id: String = ""

	func duplicate_entry() -> ChronicleEntry:
		var e := ChronicleEntry.new()
		e.id = id
		e.generation = generation
		e.event_type = event_type
		e.title = title
		e.causal_explanation = causal_explanation
		e.hex_id = hex_id
		e.deme_id = deme_id
		e.lineage_id = lineage_id
		e.trait_id = trait_id
		return e

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"generation": generation,
			"eventType": event_type,
			"title": title,
			"causalExplanation": causal_explanation,
			"hexId": hex_id,
			"demeId": deme_id,
			"lineageId": lineage_id,
			"traitId": trait_id
		}

	static func from_dict(d: Dictionary) -> ChronicleEntry:
		var e := ChronicleEntry.new()
		e.id = str(d["id"])
		e.generation = int(d["generation"])
		e.event_type = str(d["eventType"])
		e.title = str(d["title"])
		e.causal_explanation = str(d["causalExplanation"])
		e.hex_id = str(d["hexId"])
		e.deme_id = str(d["demeId"]) if d.has("demeId") else ""
		e.lineage_id = str(d["lineageId"]) if d.has("lineageId") else ""
		e.trait_id = str(d["traitId"]) if d.has("traitId") else ""
		return e


class HexEdgeFlow extends RefCounted:
	var from_hex_id: String = "0,0"
	var to_hex_id: String = "0,0"
	var flow_type: String = "migration" # "migration" | "exchange" | "dispute" | "merge"
	var intensity: float = 0.5
	var from_deme_id: String = ""
	var to_deme_id: String = ""

	func duplicate_flow() -> HexEdgeFlow:
		var f := HexEdgeFlow.new()
		f.from_hex_id = from_hex_id
		f.to_hex_id = to_hex_id
		f.flow_type = flow_type
		f.intensity = intensity
		f.from_deme_id = from_deme_id
		f.to_deme_id = to_deme_id
		return f

	func to_dict() -> Dictionary:
		return {
			"fromHexId": from_hex_id,
			"toHexId": to_hex_id,
			"type": flow_type,
			"intensity": intensity,
			"fromDemeId": from_deme_id,
			"toDemeId": to_deme_id
		}

	static func from_dict(d: Dictionary) -> HexEdgeFlow:
		var f := HexEdgeFlow.new()
		f.from_hex_id = str(d["fromHexId"])
		f.to_hex_id = str(d["toHexId"])
		f.flow_type = str(d["type"])
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
	var lineages: Dictionary:
		get:
			return lineage_tree
		set(value):
			lineage_tree = value
	var chronicle: Array[ChronicleEntry] = []
	var active_flows: Array[HexEdgeFlow] = []
	var recent_extinction_hexes: Array[String] = [] # hex_ids that had real extinction this turn
	var disused_connections: Array[Dictionary] = [] # previous turn roads/bridges
	var quiet_turns: int = 0
	var previous_populations: Dictionary = {} # String (deme_id) -> int
	var macro_outcome_type: String = "" # "" | "total_extinction" | "single_survivor" | "ecological_equilibrium"
	var macro_outcome_title: String = ""
	var macro_outcome_summary: String = ""

	func duplicate_state() -> WorldState:
		var s := WorldState.new()
		s.preset_id = preset_id
		s.world_name = world_name
		s.generation = generation
		s.season = season
		s.map_radius = map_radius
		s.sea_level = sea_level
		s.glacial_sea_level_cycle = glacial_sea_level_cycle
		s.selective_pressure_points = selective_pressure_points
		s.selective_pressure_regen_per_turn = selective_pressure_regen_per_turn
		s.unlimited_pressure_mode = unlimited_pressure_mode
		s.free_sandbox_mode = free_sandbox_mode
		s.auto_pause_on_milestone = auto_pause_on_milestone
		s.strategy_a_id = strategy_a_id
		s.strategy_b_id = strategy_b_id
		for k in cells.keys():
			s.cells[k] = (cells[k] as HexCell).duplicate_cell()
		for k in demes.keys():
			s.demes[k] = (demes[k] as Deme).duplicate_deme()
		for k in traits_catalog.keys():
			s.traits_catalog[k] = (traits_catalog[k] as TraitDef).duplicate_trait()
		for k in decisions_catalog.keys():
			s.decisions_catalog[k] = (decisions_catalog[k] as DecisionDef).duplicate_decision()
		for k in strategies_catalog.keys():
			s.strategies_catalog[k] = (strategies_catalog[k] as StrategyDef).duplicate_strategy()
		for k in lineage_tree.keys():
			s.lineage_tree[k] = (lineage_tree[k] as LineageNode).duplicate_node()
		for entry in chronicle:
			s.chronicle.append(entry.duplicate_entry())
		for fl in active_flows:
			s.active_flows.append(fl.duplicate_flow())
		s.recent_extinction_hexes = recent_extinction_hexes.duplicate()
		s.disused_connections = disused_connections.duplicate(true)
		s.quiet_turns = quiet_turns
		s.previous_populations = previous_populations.duplicate()
		s.macro_outcome_type = macro_outcome_type
		s.macro_outcome_title = macro_outcome_title
		s.macro_outcome_summary = macro_outcome_summary
		return s

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
			"strategyAId": strategy_a_id,
			"strategyBId": strategy_b_id,
			"strategy_a_id": strategy_a_id,
			"strategy_b_id": strategy_b_id,
			"cells": cells_dict,
			"demes": demes_dict,
			"traitsCatalog": traits_dict,
			"decisionsCatalog": decisions_dict,
			"strategiesCatalog": strategies_dict,
			"strategies_catalog": strategies_dict,
			"lineageTree": lineage_dict,
			"chronicle": chron_arr,
			"activeFlows": flows_arr,
			"recentExtinctionHexes": recent_extinction_hexes.duplicate(),
			"disusedConnections": disused_connections.duplicate(true),
			"quietTurns": quiet_turns,
			"previousPopulations": previous_populations.duplicate(),
			"macroOutcomeType": macro_outcome_type,
			"macroOutcomeTitle": macro_outcome_title,
			"macroOutcomeSummary": macro_outcome_summary
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
		if d.has("strategyAId"):
			s.strategy_a_id = str(d["strategyAId"])
		elif d.has("strategy_a_id"):
			s.strategy_a_id = str(d["strategy_a_id"])
		if d.has("strategyBId"):
			s.strategy_b_id = str(d["strategyBId"])
		elif d.has("strategy_b_id"):
			s.strategy_b_id = str(d["strategy_b_id"])
		for k in d["cells"].keys():
			s.cells[str(k)] = HexCell.from_dict(d["cells"][k])
		for k in d["demes"].keys():
			s.demes[str(k)] = Deme.from_dict(d["demes"][k])
		for k in d["traitsCatalog"].keys():
			s.traits_catalog[str(k)] = TraitDef.from_dict(d["traitsCatalog"][k])
		for k in d["decisionsCatalog"].keys():
			s.decisions_catalog[str(k)] = DecisionDef.from_dict(d["decisionsCatalog"][k])
		var raw_strats: Dictionary = d["strategiesCatalog"] if d.has("strategiesCatalog") else (d["strategies_catalog"] if d.has("strategies_catalog") else {})
		for k in raw_strats.keys():
			s.strategies_catalog[str(k)] = StrategyDef.from_dict(raw_strats[k])
		for k in d["lineageTree"].keys():
			s.lineage_tree[str(k)] = LineageNode.from_dict(d["lineageTree"][k])
		for item in d["chronicle"]:
			s.chronicle.append(ChronicleEntry.from_dict(item))
		for item in d["activeFlows"]:
			s.active_flows.append(HexEdgeFlow.from_dict(item))
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
		return s
