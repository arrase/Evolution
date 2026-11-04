import {
  buildContextualJustification,
  computeDemeEvaluationSignature
} from "../ai/ollamaSystemOne";
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
  evaluateMacroEvolutionaryOutcome,
  prioritizeEvolutionaryMilestones
} from "./milestonePhase";

export async function executeGenerationalTurn(
  state: WorldState,
  provider: CognitiveProvider,
  locale?: SupportedLocale
): Promise<WorldState> {
  const activeLocale: SupportedLocale = locale !== undefined ? locale : DEFAULT_LOCALE;
  const afterEnv = runEnvironmentalPhase(state);

  const decisionsByDemeId: Record<string, DemeDecisionEvaluationOutput> = {};
  const signatureCache = new Map<string, DemeDecisionEvaluationOutput>();
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
        semanticDescriptor: decision.semanticDescriptor,
        archetype: decision.archetype,
        biophysicalVector: decision.biophysicalVector
      }));

    const activeBiologicalTraits = deme.biologicalTraitIds
      .map((id) => afterEnv.traitsCatalog[id])
      .filter((trait): trait is NonNullable<typeof trait> => trait !== undefined)
      .map((trait) => ({
        id: trait.id,
        name: trait.name,
        semanticDescriptor: trait.semanticDescriptor,
        affinityCondition: trait.affinityCondition,
        biophysicalVector: trait.biophysicalVector
      }));

    const activeCulturalTraits = deme.culturalTraitIds
      .map((id) => afterEnv.traitsCatalog[id])
      .filter((trait): trait is NonNullable<typeof trait> => trait !== undefined)
      .map((trait) => ({
        id: trait.id,
        name: trait.name,
        semanticDescriptor: trait.semanticDescriptor,
        affinityCondition: trait.affinityCondition,
        biophysicalVector: trait.biophysicalVector
      }));

    const baselineVector = computeEffectiveBiophysicalVector(deme, afterEnv, {});
    const migrateDecisionMobility = allDecisions
      .filter(
        (decision) =>
          decision.archetype === "migrate" &&
          (decision.requiredTraitIds.length === 0 ||
            decision.requiredTraitIds.some((reqId) => demeTraitSet.has(reqId)))
      )
      .reduce((maxMob, decision) => Math.max(maxMob, decision.biophysicalVector.spatialMobility), 0);
    const effectiveMigrationMobility = Math.min(
      1.5,
      baselineVector.spatialMobility + migrateDecisionMobility
    );
    const neighborCells = getExistingNeighborCells(currentCell, afterEnv.cells).map(
      (neighbor) => {
        const totalNeighborPop = neighbor.demeIds.reduce((sum, otherId) => {
          const other = afterEnv.demes[otherId];
          return sum + (other !== undefined ? other.population : 0);
        }, 0);
        return {
          id: neighbor.id,
          biome: neighbor.biome,
          temperature: neighbor.temperature,
          humidity: neighbor.humidity,
          altitude: neighbor.altitude,
          currentResources: neighbor.currentResources,
          carryingCapacity: neighbor.carryingCapacity,
          demesCount: neighbor.demeIds.length,
          totalPopulation: totalNeighborPop,
          isPassable: isHexPassableForDeme(neighbor, effectiveMigrationMobility)
        };
      }
    );

    let totalCellPopulation = 0;
    let rivalDemesCount = 0;
    let kinDemesCount = 0;
    for (const otherId of currentCell.demeIds) {
      const other = afterEnv.demes[otherId];
      if (other === undefined) {
        continue;
      }
      totalCellPopulation += other.population;
      if (other.id !== deme.id) {
        if (other.lineageId === deme.lineageId) {
          kinDemesCount += 1;
        } else {
          rivalDemesCount += 1;
        }
      }
    }

    const baldwinProgress = Object.values(deme.baldwinCounters).reduce(
      (maxVal, count) => Math.max(maxVal, count),
      0
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
        lastDominantDecisionId: deme.lastDominantDecisionId,
        baldwinProgress,
        innovationProgress: deme.innovationCounter,
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
        cohabitingDemesCount: Math.max(0, currentCell.demeIds.length - 1),
        totalCellPopulation,
        rivalDemesCount,
        kinDemesCount
      },
      neighborCells,
      eligibleDecisions
    };

    const signature = computeDemeEvaluationSignature(evaluationInput);
    const cachedEvaluation = signatureCache.get(signature);
    if (cachedEvaluation !== undefined) {
      const dominantProb = cachedEvaluation.probabilities[cachedEvaluation.dominantDecisionId];
      decisionsByDemeId[deme.id] = {
        probabilities: { ...cachedEvaluation.probabilities },
        dominantDecisionId: cachedEvaluation.dominantDecisionId,
        confidence: cachedEvaluation.confidence,
        justification: buildContextualJustification(
          evaluationInput,
          cachedEvaluation.dominantDecisionId,
          dominantProb !== undefined ? dominantProb : 0.5,
          cachedEvaluation.confidence
        )
      };
    } else {
      const evaluated = await provider.evaluateDemeDecisions(evaluationInput);
      signatureCache.set(signature, evaluated);
      decisionsByDemeId[deme.id] = evaluated;
    }
  }

  let afterMilestones = resolveBiophysicalAndDemographicPhase(afterEnv, decisionsByDemeId);

  const milestoneInputs = prioritizeEvolutionaryMilestones(
    detectEvolutionaryMilestones(afterMilestones, activeLocale)
  ).slice(0, 1);
  for (const milestoneInput of milestoneInputs) {
    const latestDeme = afterMilestones.demes[milestoneInput.deme.id];
    const existingTraitNames =
      latestDeme !== undefined
        ? [...latestDeme.biologicalTraitIds, ...latestDeme.culturalTraitIds].map((id) => {
            const trait = afterMilestones.traitsCatalog[id];
            return trait !== undefined ? trait.name : id;
          })
        : milestoneInput.deme.existingTraitNames;

    const updatedInput = {
      ...milestoneInput,
      deme: {
        ...milestoneInput.deme,
        existingTraitNames
      }
    };

    const proposal = await provider.synthesizeMilestone(updatedInput);
    afterMilestones = applySynthesizedMilestone(afterMilestones, updatedInput, proposal);
  }

  return evaluateMacroEvolutionaryOutcome(state, afterMilestones, activeLocale);
}
