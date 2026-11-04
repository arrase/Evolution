import { DecisionDefinition } from "../types/simulation";

export const BASE_DECISIONS: DecisionDefinition[] = [
  {
    id: "dec-conservative-forage",
    name: "Conservative Foraging",
    archetype: "forage",
    semanticDescriptor:
      "Low-risk, energy-efficient opportunistic gathering and grazing within local carrying capacity limits, preserving habitat regeneration when resources are stable and competition is low.",
    requiredTraitIds: [],
    biophysicalVector: {
      metabolicCost: 0.10,
      extractionEfficiency: 0.35,
      ecologicalImpact: 0.10,
      spatialMobility: 0.00,
      socialCohesion: 0.05,
      transmissionThreshold: 0.05
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "dec-intensive-overexploit",
    name: "Intensive Overexploitation",
    archetype: "overexploit",
    semanticDescriptor:
      "Aggressive, high-yield biomass extraction that maximizes immediate caloric intake under demographic pressure or caloric deficit at the expense of severe habitat carrying capacity degradation.",
    requiredTraitIds: [],
    biophysicalVector: {
      metabolicCost: 0.25,
      extractionEfficiency: 0.85,
      ecologicalImpact: -0.65,
      spatialMobility: 0.00,
      socialCohesion: -0.10,
      transmissionThreshold: 0.10
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "dec-selective-migration",
    name: "Selective Migration",
    archetype: "migrate",
    semanticDescriptor:
      "Directed spatial dispersal toward adjacent passable hexes with superior resource-to-population ratios when local biomass is depleted, overcrowded, or climatically hostile.",
    requiredTraitIds: [],
    biophysicalVector: {
      metabolicCost: 0.30,
      extractionEfficiency: 0.15,
      ecologicalImpact: 0.15,
      spatialMobility: 0.75,
      socialCohesion: 0.05,
      transmissionThreshold: 0.10
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "dec-cooperate-store",
    name: "Cooperation & Storage",
    archetype: "cooperate",
    semanticDescriptor:
      "Collective resource pooling, food preservation, and mutual defense that buffer seasonal scarcity, strengthen intra-deme cohesion, and sustain high population densities.",
    requiredTraitIds: [],
    biophysicalVector: {
      metabolicCost: 0.25,
      extractionEfficiency: 0.45,
      ecologicalImpact: 0.15,
      spatialMobility: -0.10,
      socialCohesion: 0.65,
      transmissionThreshold: 0.35
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "dec-exchange-symbiosis",
    name: "Exchange / Symbiosis",
    archetype: "exchange",
    semanticDescriptor:
      "Reciprocal resource exchange, niche partitioning, and horizontal cultural transmission with cohabiting or neighboring demes, generating non-zero-sum energetic surpluses.",
    requiredTraitIds: ["bio-encephalization", "bio-social-instinct"],
    biophysicalVector: {
      metabolicCost: 0.35,
      extractionEfficiency: 0.50,
      ecologicalImpact: 0.20,
      spatialMobility: 0.20,
      socialCohesion: 0.60,
      transmissionThreshold: 0.45
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "dec-territorial-dispute",
    name: "Territorial Dispute",
    archetype: "dispute",
    semanticDescriptor:
      "Agonistic Hawk-strategy resource monopolization and territorial exclusion against rival demes in shared hexes, seizing competitor biomass shares at high metabolic and demographic risk.",
    requiredTraitIds: [],
    biophysicalVector: {
      metabolicCost: 0.55,
      extractionEfficiency: 0.40,
      ecologicalImpact: -0.30,
      spatialMobility: 0.25,
      socialCohesion: 0.55,
      transmissionThreshold: 0.20
    },
    origin: "base",
    freeSandboxMode: false
  },
  {
    id: "dec-explore-innovate",
    name: "Exploration / Innovation",
    archetype: "innovate",
    semanticDescriptor:
      "High-cost cognitive experimentation, tool prototyping, and ecological reconnaissance that sacrifices immediate foraging yield to accumulate cultural innovation and adaptive plasticity.",
    requiredTraitIds: [],
    biophysicalVector: {
      metabolicCost: 0.50,
      extractionEfficiency: 0.15,
      ecologicalImpact: 0.00,
      spatialMobility: 0.40,
      socialCohesion: 0.35,
      transmissionThreshold: 0.65
    },
    origin: "base",
    freeSandboxMode: false
  }
];

export function createBaseDecisionsCatalog(): Record<string, DecisionDefinition> {
  const catalog: Record<string, DecisionDefinition> = {};
  for (const decision of BASE_DECISIONS) {
    catalog[decision.id] = {
      ...decision,
      requiredTraitIds: [...decision.requiredTraitIds],
      biophysicalVector: { ...decision.biophysicalVector }
    };
  }
  return catalog;
}
