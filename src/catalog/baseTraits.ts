import { TraitDefinition } from "../types/simulation";

export const BASE_BIOLOGICAL_TRAITS: TraitDefinition[] = [
  {
    id: "bio-r-strategy",
    name: "r-Strategy (Prolific)",
    category: "biological",
    semanticDescriptor:
      "Life-history adaptation prioritizing rapid maturation, high fecundity, and low per-offspring energetic investment, enabling explosive demographic rebound and rapid dispersal in unstable habitats.",
    affinityCondition:
      "Favors Intensive Overexploitation and Selective Migration during resource pulses or post-disturbance colonization.",
    mutuallyExclusiveWith: ["bio-k-strategy"],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: -0.15,
      extractionEfficiency: 0.20,
      ecologicalImpact: -0.20,
      spatialMobility: 0.25,
      socialCohesion: -0.15,
      transmissionThreshold: 0.05
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "bio-k-strategy",
    name: "K-Strategy (Parental Investment)",
    category: "biological",
    semanticDescriptor:
      "Life-history adaptation prioritizing extended longevity, delayed maturation, and intensive parental care that buffers demographic oscillations near habitat carrying capacity.",
    affinityCondition:
      "Favors Cooperation & Storage and Conservative Foraging in high-density, resource-predictable environments.",
    mutuallyExclusiveWith: ["bio-r-strategy"],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: 0.20,
      extractionEfficiency: 0.25,
      ecologicalImpact: 0.15,
      spatialMobility: 0.05,
      socialCohesion: 0.40,
      transmissionThreshold: 0.30
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "bio-digestive-spec",
    name: "Omnivorous Digestive Specialization",
    category: "biological",
    semanticDescriptor:
      "Enzymatic and gastrointestinal plasticity capable of detoxifying fibrous flora, tubers, and diverse fauna across heterogeneous biomes, raising caloric extraction efficiency.",
    affinityCondition:
      "Favors Conservative Foraging and Intensive Overexploitation across diverse or seasonally shifting biomes.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: 0.10,
      extractionEfficiency: 0.45,
      ecologicalImpact: 0.05,
      spatialMobility: 0.15,
      socialCohesion: 0.00,
      transmissionThreshold: 0.10
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "bio-thermal-tolerance",
    name: "Thermal & Hydric Tolerance",
    category: "biological",
    semanticDescriptor:
      "Physiological thermoregulation and water-conservation adaptations that reduce metabolic penalties in extreme arid, glacial, or high-altitude environments and facilitate barrier traversal.",
    affinityCondition:
      "Favors Selective Migration and Exploration & Innovation across steep climatic gradients and high-altitude passes.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: 0.15,
      extractionEfficiency: 0.20,
      ecologicalImpact: 0.05,
      spatialMobility: 0.45,
      socialCohesion: 0.10,
      transmissionThreshold: 0.10
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "bio-encephalization",
    name: "Encephalization (Expensive Tissue)",
    category: "biological",
    semanticDescriptor:
      "Expansion of neocortical volume and executive cognition at a steep resting metabolic cost, unlocking cumulative cultural transmission, tool innovation, and complex symbolic exchange.",
    affinityCondition:
      "Strongly favors Exploration & Innovation, Inter-Deme Exchange & Symbiosis, and Cooperation & Storage.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: true,
    biophysicalVector: {
      metabolicCost: 0.45,
      extractionEfficiency: 0.35,
      ecologicalImpact: 0.00,
      spatialMobility: 0.20,
      socialCohesion: 0.45,
      transmissionThreshold: 0.60
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "bio-social-instinct",
    name: "Instinctive Sociability (Gregariousness)",
    category: "biological",
    semanticDescriptor:
      "Neuroendocrine predisposition toward kin altruism, affective coordination, and social learning that lowers intragroup conflict and enables horizontal and vertical cultural transmission.",
    affinityCondition:
      "Favors Cooperation & Storage and Inter-Deme Exchange & Symbiosis when multiple demes or high densities co-occur.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: true,
    biophysicalVector: {
      metabolicCost: 0.20,
      extractionEfficiency: 0.20,
      ecologicalImpact: 0.05,
      spatialMobility: 0.10,
      socialCohesion: 0.60,
      transmissionThreshold: 0.45
    },
    origin: "base",
    freeSandboxMode: false
  }
];

export const BASE_CULTURAL_TRAITS: TraitDefinition[] = [
  {
    id: "cul-fire-processing",
    name: "Fire & Food Processing",
    category: "cultural",
    semanticDescriptor:
      "Socially transmitted mastery of controlled fire and thermal food preparation that externalizes digestion, lowers net metabolic expenditure, and increases caloric bioavailability at a slight ecological cost.",
    affinityCondition:
      "Favors Cooperation & Storage and Conservative Foraging in cold or resource-dense woodland and savanna biomes.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: -0.10,
      extractionEfficiency: 0.35,
      ecologicalImpact: -0.25,
      spatialMobility: 0.10,
      socialCohesion: 0.15,
      transmissionThreshold: 0.40
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "cul-extraction-tools",
    name: "Specialized Extraction Tools",
    category: "cultural",
    semanticDescriptor:
      "Cumulative lithic and organic toolkit tradition for intensive hunting, harvesting, and substrate excavation that sharply boosts resource extraction while accelerating habitat depletion.",
    affinityCondition:
      "Favors Intensive Overexploitation and Cooperation & Storage when abundant local biomass can be rapidly harvested.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: 0.25,
      extractionEfficiency: 0.65,
      ecologicalImpact: -0.25,
      spatialMobility: 0.10,
      socialCohesion: 0.20,
      transmissionThreshold: 0.50
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "cul-communal-conservation",
    name: "Communal Conservation Norms",
    category: "cultural",
    semanticDescriptor:
      "Institutionalized taboos, seasonal harvesting quotas, and ecological stewardship norms that prevent the Tragedy of the Commons and actively regenerate local carrying capacity.",
    affinityCondition:
      "Strongly favors Conservative Foraging and Cooperation & Storage when carrying capacity is stressed or shared.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: 0.15,
      extractionEfficiency: 0.25,
      ecologicalImpact: 0.55,
      spatialMobility: 0.00,
      socialCohesion: 0.50,
      transmissionThreshold: 0.55
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "cul-interdeme-barter",
    name: "Inter-Deme Barter Networks",
    category: "cultural",
    semanticDescriptor:
      "Codified protocols of inter-group diplomacy, gift exchange, and trade corridors that facilitate peaceful cohabitation, mutual caloric bonuses, and rapid diffusion of cultural innovations.",
    affinityCondition:
      "Strongly favors Inter-Deme Exchange & Symbiosis and Selective Migration when neighboring or cohabiting demes are present.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: 0.35,
      extractionEfficiency: 0.40,
      ecologicalImpact: 0.15,
      spatialMobility: 0.30,
      socialCohesion: 0.50,
      transmissionThreshold: 0.60
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "cul-warrior-expansion",
    name: "Expansionist Warrior Tradition",
    category: "cultural",
    semanticDescriptor:
      "Militarized age-set organization, coalitionary raiding doctrines, and territorial expansion norms that maximize competitive dominance in inter-deme disputes at high energetic and ecological cost.",
    affinityCondition:
      "Strongly favors Territorial Dispute and Selective Migration when competing demes occupy resource-rich hexes.",
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: {
      metabolicCost: 0.45,
      extractionEfficiency: 0.30,
      ecologicalImpact: -0.35,
      spatialMobility: 0.45,
      socialCohesion: 0.60,
      transmissionThreshold: 0.45
    },
    origin: "base",
    freeSandboxMode: false
  }
];

export const BASE_TRAITS: TraitDefinition[] = [
  ...BASE_BIOLOGICAL_TRAITS,
  ...BASE_CULTURAL_TRAITS
];

export function createBaseTraitsCatalog(): Record<string, TraitDefinition> {
  const catalog: Record<string, TraitDefinition> = {};
  for (const trait of BASE_TRAITS) {
    catalog[trait.id] = {
      ...trait,
      mutuallyExclusiveWith: [...trait.mutuallyExclusiveWith],
      biophysicalVector: { ...trait.biophysicalVector }
    };
  }
  return catalog;
}

export function demeHasCulturalCapacity(
  deme: { biologicalTraitIds: string[] },
  traitsCatalog: Record<string, TraitDefinition>
): boolean {
  return deme.biologicalTraitIds.some((traitId) => {
    const trait = traitsCatalog[traitId];
    return trait !== undefined && trait.enablesCulturalTransmission;
  });
}
