import { describe, expect, it } from "vitest";
import { LiveCognitiveProvider, MockCognitiveProvider } from "../../src/ai/cognitiveProvider";
import {
  buildContextualJustification,
  evaluateDemeWithOllamaSystemOne,
  normalizeDecisionProbabilities
} from "../../src/ai/ollamaSystemOne";
import { computeThermodynamicMetrics } from "../../src/engine/thermodynamics";
import {
  DemeDecisionEvaluationInput,
  SUPPORTED_LOCALES,
  SynthesizedTraitProposalSchema,
  UserCoDesignOutputSchema
} from "../../src/types/simulation";

const SAMPLE_ELIGIBLE_DECISIONS = [
  {
    id: "dec-conservative-forage",
    name: "Conservative Foraging",
    semanticDescriptor: "Sustainable resource extraction within local regeneration bounds."
  },
  {
    id: "dec-intensive-overexploit",
    name: "Intensive Overexploitation",
    semanticDescriptor: "Aggressive short-term biomass extraction degrading carrying capacity."
  },
  {
    id: "dec-selective-migration",
    name: "Selective Migration",
    semanticDescriptor: "Targeted dispersal into neighboring hex cells with higher resources."
  },
  {
    id: "dec-cooperate-store",
    name: "Cooperation & Storage",
    semanticDescriptor: "Collective resource pooling and cooperative defense."
  },
  {
    id: "dec-exchange-symbiosis",
    name: "Exchange / Symbiosis",
    semanticDescriptor: "Mutualistic trade and horizontal cultural transmission."
  },
  {
    id: "dec-territorial-dispute",
    name: "Territorial Dispute",
    semanticDescriptor: "Hawk-strategy confrontation to capture carrying capacity share."
  },
  {
    id: "dec-explore-innovate",
    name: "Exploration / Innovation",
    semanticDescriptor: "Cognitive investment in behavioral experimentation and innovation."
  }
];

function createSampleEvaluationInput(
  overrides?: Partial<DemeDecisionEvaluationInput>
): DemeDecisionEvaluationInput {
  return {
    locale: "en",
    generation: 5,
    season: "wet_warm",
    deme: {
      id: "deme-1",
      name: "Rift Hominids",
      population: 120,
      energyReserves: 80,
      lastEnergyDelta: 12,
      activeBiologicalTraits: [
        {
          id: "bio-k-strategy",
          name: "K-Strategy",
          semanticDescriptor: "High parental investment and longevity.",
          affinityCondition: "Stable or competitive habitats"
        },
        {
          id: "bio-social-instinct",
          name: "Social Instinct",
          semanticDescriptor: "Gregarious cohesion enabling cultural transmission.",
          affinityCondition: "Cooperative group environments"
        }
      ],
      activeCulturalTraits: []
    },
    currentCell: {
      id: "2,-1",
      biome: "savanna",
      temperature: 0.4,
      humidity: 0.3,
      altitude: 0.35,
      currentResources: 180,
      carryingCapacity: 260,
      carryingCapacityMax: 300,
      cohabitingDemesCount: 1
    },
    neighborCells: [
      {
        id: "2,0",
        biome: "savanna",
        temperature: 0.35,
        humidity: 0.35,
        altitude: 0.32,
        currentResources: 220,
        carryingCapacity: 280,
        demesCount: 0,
        isPassable: true
      }
    ],
    eligibleDecisions: SAMPLE_ELIGIBLE_DECISIONS,
    ...overrides
  };
}

describe("Cognitive Engine Contracts (System 1 & System 2)", () => {
  describe("T015: System 1 Probability Normalization & Fail-Safe", () => {
    it("normalizes arbitrary decision scores so that sum(P_i) === 1.0 exactly", () => {
      const eligibleIds = SAMPLE_ELIGIBLE_DECISIONS.map((d) => d.id);
      const rawScores = {
        "dec-conservative-forage": 1.333333,
        "dec-intensive-overexploit": 0.25,
        "dec-selective-migration": 2.71828,
        "dec-cooperate-store": 4.11111,
        "dec-exchange-symbiosis": 0.9999,
        "dec-territorial-dispute": 0.1234,
        "dec-explore-innovate": 1.41421
      };

      const { probabilities, dominantDecisionId } = normalizeDecisionProbabilities(
        rawScores,
        eligibleIds
      );

      expect(dominantDecisionId).toBe("dec-cooperate-store");
      const total = Object.values(probabilities).reduce((acc, p) => acc + p, 0);
      expect(Math.abs(total - 1.0)).toBeLessThan(1e-9);
      for (const id of eligibleIds) {
        expect(probabilities[id]).toBeGreaterThanOrEqual(0);
        expect(probabilities[id]).toBeLessThanOrEqual(1);
      }
    });

    it("handles all-zero or negative scores by assigning a normalized uniform distribution", () => {
      const eligibleIds = ["dec-a", "dec-b", "dec-c"];
      const { probabilities, dominantDecisionId } = normalizeDecisionProbabilities(
        { "dec-a": 0, "dec-b": -5, "dec-c": Number.NaN },
        eligibleIds
      );

      expect(dominantDecisionId).toBe("dec-a");
      const total = Object.values(probabilities).reduce((acc, p) => acc + p, 0);
      expect(Math.abs(total - 1.0)).toBeLessThan(1e-9);
      expect(probabilities["dec-a"]).toBeCloseTo(0.3334, 4);
      expect(probabilities["dec-b"]).toBeCloseTo(0.3333, 4);
      expect(probabilities["dec-c"]).toBeCloseTo(0.3333, 4);
    });

    it("builds localized contextual justifications across all 8 supported locales (SC-003, FR-015)", () => {
      for (const locale of SUPPORTED_LOCALES) {
        const input = createSampleEvaluationInput({ locale });
        const text = buildContextualJustification(
          input,
          "dec-cooperate-store",
          0.42,
          0.88
        );
        expect(text).toContain("savanna");
        expect(text).toContain("180/260");
        expect(text).toContain("K-Strategy");
        expect(text).toContain("Cooperation & Storage");
        expect(text).toContain("42.0%");
        expect(text).toContain("88%");
      }
    });

    it("fails cleanly on unreachable Ollama host or timeout without hanging (Edge Case 2)", async () => {
      const input = createSampleEvaluationInput();
      await expect(
        evaluateDemeWithOllamaSystemOne(input, {
          host: "http://127.0.0.1:59999",
          timeoutMs: 250
        })
      ).rejects.toThrow();

      const unreachableProvider = new LiveCognitiveProvider({
        host: "http://127.0.0.1:59999",
        systemOneTimeoutMs: 250,
        systemTwoTimeoutMs: 250
      });
      const status = await unreachableProvider.checkStatus();
      expect(status.connected).toBe(false);
      expect(status.systemOneModelReady).toBe(false);
      expect(status.systemTwoModelReady).toBe(false);
      expect(status.missingCommands).toContain("ollama pull d3:4b");
      expect(status.missingCommands).toContain("ollama pull gemma4:e4b-it-qat");
    });
  });

  describe("T021, T032, T037: MockCognitiveProvider Context Sensitivity & System 2 Schemas", () => {
    const provider = new MockCognitiveProvider();

    it("evaluates context-sensitive decisions matching all 3 scientific preset hypotheses (SC-001)", async () => {
      const savannaInput = createSampleEvaluationInput();
      const savannaOut = await provider.evaluateDemeDecisions(savannaInput);
      expect(savannaOut.dominantDecisionId).toBe("dec-cooperate-store");
      const savannaCoop = savannaOut.probabilities["dec-cooperate-store"]!;
      const savannaMig = savannaOut.probabilities["dec-selective-migration"]!;
      expect(savannaCoop).toBeGreaterThanOrEqual(0.35);
      expect(savannaCoop + savannaMig).toBeGreaterThan(0.5);

      const forestInput = createSampleEvaluationInput({
        currentCell: {
          id: "-2,1",
          biome: "tropical_forest",
          temperature: 0.3,
          humidity: 0.85,
          altitude: 0.25,
          currentResources: 350,
          carryingCapacity: 400,
          carryingCapacityMax: 400,
          cohabitingDemesCount: 1
        },
        neighborCells: []
      });
      const forestOut = await provider.evaluateDemeDecisions(forestInput);
      expect(forestOut.dominantDecisionId).toBe("dec-conservative-forage");
      expect(forestOut.probabilities["dec-conservative-forage"]).toBeGreaterThanOrEqual(0.48);

      const finiteIslandInput = createSampleEvaluationInput({
        deme: {
          ...savannaInput.deme,
          activeCulturalTraits: [
            {
              id: "cul-extraction-tools",
              name: "Extraction Tools",
              semanticDescriptor: "Specialized lithic and wooden extraction tools.",
              affinityCondition: "High-biomass habitats"
            }
          ]
        }
      });
      const finiteIslandOut = await provider.evaluateDemeDecisions(finiteIslandInput);
      expect(finiteIslandOut.dominantDecisionId).toBe("dec-intensive-overexploit");
      expect(finiteIslandOut.probabilities["dec-intensive-overexploit"]).toBeGreaterThanOrEqual(
        0.5
      );

      const landBridgeInput = createSampleEvaluationInput({
        currentCell: {
          id: "0,0",
          biome: "savanna",
          temperature: 0.2,
          humidity: 0.6,
          altitude: 0.35,
          currentResources: 250,
          carryingCapacity: 300,
          carryingCapacityMax: 300,
          cohabitingDemesCount: 1
        },
        neighborCells: [
          {
            id: "1,0",
            biome: "coastal_shallows",
            temperature: 0.2,
            humidity: 0.7,
            altitude: 0.18,
            currentResources: 160,
            carryingCapacity: 200,
            demesCount: 0,
            isPassable: true
          }
        ]
      });
      const landBridgeOut = await provider.evaluateDemeDecisions(landBridgeInput);
      expect(landBridgeOut.dominantDecisionId).toBe("dec-selective-migration");
      expect(landBridgeOut.probabilities["dec-selective-migration"]).toBeGreaterThanOrEqual(0.38);
    });

    it("synthesizes valid, thermodynamically balanced Milestone proposals across locales (T037, SC-005)", async () => {
      for (const locale of SUPPORTED_LOCALES) {
        const proposal = await provider.synthesizeMilestone({
          locale,
          triggerType: "baldwin_assimilation",
          generation: 8,
          deme: {
            id: "deme-east",
            name: "Eastern Hominids",
            population: 145,
            dominantDecisionName: "Cooperation & Storage",
            existingTraitNames: ["K-Strategy", "Social Instinct"]
          },
          cell: {
            biome: "savanna",
            temperature: 0.4,
            humidity: 0.3,
            altitude: 0.35
          }
        });

        const parsed = SynthesizedTraitProposalSchema.parse(proposal);
        expect(parsed.category).toBe("biological");
        const metrics = computeThermodynamicMetrics(parsed.biophysicalVector);
        expect(metrics.isBalanced).toBe(true);
      }
    });

    it("synthesizes valid, thermodynamically balanced Co-Design catalog items across locales (T032, SC-005)", async () => {
      for (const locale of SUPPORTED_LOCALES) {
        const output = await provider.coDesignCatalogItem({
          locale,
          userConcept: "Cooperative seasonal fishing nets",
          targetType: "cultural_trait"
        });

        const parsed = UserCoDesignOutputSchema.parse(output);
        const metrics = computeThermodynamicMetrics(parsed.biophysicalVector);
        expect(metrics.isBalanced).toBe(true);
      }
    });
  });
});
