import {
  DEFAULT_LOCALE,
  type CognitiveProvider,
  type DemeDecisionEvaluationInput,
  type DemeDecisionEvaluationOutput,
  type SupportedLocale,
  type WorldState
} from "../types/simulation";
import {
  computeEffectiveBiophysicalVector,
  resolveBiophysicalAndDemographicPhase
} from "./biophysicalPhase";
import { runEnvironmentalPhase } from "./environmentalPhase";
import { getExistingNeighborCells, isHexPassableForDeme } from "./hexGrid";
import {
  applySynthesizedMilestone,
  detectEvolutionaryMilestones,
  evaluateMacroEvolutionaryOutcome
} from "./milestonePhase";

export async function executeGenerationalTurn(
  state: WorldState,
  provider: CognitiveProvider,
  locale?: SupportedLocale
): Promise<WorldState> {
  const activeLocale: SupportedLocale = locale !== undefined ? locale : DEFAULT_LOCALE;
  const afterEnv = runEnvironmentalPhase(state);

  const decisionsByDemeId: Record<string, DemeDecisionEvaluationOutput> = {};
  const allDecisions = Object.values(afterEnv.decisionsCatalog);

  for (const deme of Object.values(afterEnv.demes)) {
    const currentCell = afterEnv.cells[deme.hexId];
    if (currentCell === undefined) {
      continue;
    }

    const demeTraitSet = new Set([
      ...deme.biologicalTraitIds,
      ...deme.culturalTraitIds
    ]);

    const eligibleDecisions = allDecisions
      .filter(
        (decision) =>
          decision.requiredTraitIds.length === 0 ||
          decision.requiredTraitIds.some((reqId) => demeTraitSet.has(reqId))
      )
      .map((decision) => ({
        id: decision.id,
        name: decision.name,
        semanticDescriptor: decision.semanticDescriptor
      }));

    const activeBiologicalTraits = deme.biologicalTraitIds
      .map((id) => afterEnv.traitsCatalog[id])
      .filter((trait): trait is NonNullable<typeof trait> => trait !== undefined)
      .map((trait) => ({
        id: trait.id,
        name: trait.name,
        semanticDescriptor: trait.semanticDescriptor,
        affinityCondition: trait.affinityCondition
      }));

    const activeCulturalTraits = deme.culturalTraitIds
      .map((id) => afterEnv.traitsCatalog[id])
      .filter((trait): trait is NonNullable<typeof trait> => trait !== undefined)
      .map((trait) => ({
        id: trait.id,
        name: trait.name,
        semanticDescriptor: trait.semanticDescriptor,
        affinityCondition: trait.affinityCondition
      }));

    const baselineVector = computeEffectiveBiophysicalVector(deme, afterEnv, {});
    const neighborCells = getExistingNeighborCells(currentCell, afterEnv.cells).map(
      (neighbor) => ({
        id: neighbor.id,
        biome: neighbor.biome,
        temperature: neighbor.temperature,
        humidity: neighbor.humidity,
        altitude: neighbor.altitude,
        currentResources: neighbor.currentResources,
        carryingCapacity: neighbor.carryingCapacity,
        demesCount: neighbor.demeIds.length,
        isPassable: isHexPassableForDeme(neighbor, baselineVector.spatialMobility)
      })
    );

    const evaluationInput: DemeDecisionEvaluationInput = {
      locale: activeLocale,
      generation: afterEnv.generation,
      season: afterEnv.season,
      deme: {
        id: deme.id,
        name: deme.name,
        population: deme.population,
        energyReserves: deme.energyReserves,
        lastEnergyDelta: deme.lastEnergyDelta,
        activeBiologicalTraits,
        activeCulturalTraits
      },
      currentCell: {
        id: currentCell.id,
        biome: currentCell.biome,
        temperature: currentCell.temperature,
        humidity: currentCell.humidity,
        altitude: currentCell.altitude,
        currentResources: currentCell.currentResources,
        carryingCapacity: currentCell.carryingCapacity,
        carryingCapacityMax: currentCell.carryingCapacityMax,
        cohabitingDemesCount: Math.max(0, currentCell.demeIds.length - 1)
      },
      neighborCells,
      eligibleDecisions
    };

    decisionsByDemeId[deme.id] = await provider.evaluateDemeDecisions(evaluationInput);
  }

  let afterBio = resolveBiophysicalAndDemographicPhase(afterEnv, decisionsByDemeId);

  const milestoneInputs = detectEvolutionaryMilestones(afterBio, activeLocale).slice(0, 3);
  for (const milestoneInput of milestoneInputs) {
    const proposal = await provider.synthesizeMilestone(milestoneInput);
    afterBio = applySynthesizedMilestone(afterBio, milestoneInput, proposal);
  }

  return evaluateMacroEvolutionaryOutcome(state, afterBio, activeLocale);
}
