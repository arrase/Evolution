import { demeHasCulturalCapacity } from "../catalog/baseTraits";
import {
  DEFAULT_LOCALE,
  type ChronicleEntry,
  type Deme,
  type LineageNode,
  type MilestoneSynthesisInput,
  type SupportedLocale,
  type SynthesizedTraitProposal,
  type TraitDefinition,
  type WorldState
} from "../types/simulation";
import { validateAndBalanceThermodynamics } from "./thermodynamics";

const SPECIATION_PALETTE = [
  "#E07A5F",
  "#3D85C6",
  "#81B29A",
  "#F2CC8F",
  "#9B5DE5",
  "#F15BB5",
  "#00BBF9",
  "#00F5D4"
];

function computeTraitSetDivergence(setA: Set<string>, setB: Set<string>): number {
  const union = new Set([...setA, ...setB]);
  if (union.size === 0) {
    return 0;
  }

  let intersection = 0;
  for (const item of setA) {
    if (setB.has(item)) {
      intersection += 1;
    }
  }

  return Number((1 - intersection / union.size).toFixed(4));
}

function slugifyTraitName(name: string): string {
  const cleaned = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 28)
    .replace(/-+$/g, "");

  return cleaned.length > 0 ? cleaned : "adaptation";
}

function selectDistinctLineageColor(
  currentColor: string,
  lineageTree: Record<string, LineageNode>
): string {
  const usedColors = new Set(Object.values(lineageTree).map((node) => node.color.toUpperCase()));
  for (const candidate of SPECIATION_PALETTE) {
    if (
      candidate.toUpperCase() !== currentColor.toUpperCase() &&
      !usedColors.has(candidate.toUpperCase())
    ) {
      return candidate;
    }
  }
  for (const candidate of SPECIATION_PALETTE) {
    if (candidate.toUpperCase() !== currentColor.toUpperCase()) {
      return candidate;
    }
  }
  return "#3D85C6";
}

function resolveExistingTraitNames(deme: Deme, state: WorldState): string[] {
  const allIds = [...deme.biologicalTraitIds, ...deme.culturalTraitIds];
  return allIds.map((id) => {
    const trait = state.traitsCatalog[id];
    return trait !== undefined ? trait.name : id;
  });
}

function resolveDecisionName(decisionId: string, state: WorldState): string {
  const decision = state.decisionsCatalog[decisionId];
  return decision !== undefined ? decision.name : decisionId;
}

export function detectEvolutionaryMilestones(
  state: WorldState,
  locale?: SupportedLocale
): MilestoneSynthesisInput[] {
  const resolvedLocale: SupportedLocale = locale !== undefined ? locale : DEFAULT_LOCALE;
  const milestones: MilestoneSynthesisInput[] = [];

  for (const deme of Object.values(state.demes)) {
    const cell = state.cells[deme.hexId];
    if (cell === undefined) {
      continue;
    }
    const existingTraitNames = resolveExistingTraitNames(deme, state);

    let triggeredBaldwinDecisionId: string | null = null;
    for (const [decisionId, count] of Object.entries(deme.baldwinCounters)) {
      const prob = deme.lastDecisionProbabilities[decisionId];
      const hasActiveProbability = prob !== undefined && prob >= 0.35;
      if (
        decisionId !== "dec-conservative-forage" &&
        count >= 8 &&
        (hasActiveProbability || deme.lastDominantDecisionId === decisionId)
      ) {
        triggeredBaldwinDecisionId = decisionId;
        break;
      }
    }

    if (triggeredBaldwinDecisionId !== null) {
      milestones.push({
        locale: resolvedLocale,
        triggerType: "baldwin_assimilation",
        generation: state.generation,
        deme: {
          id: deme.id,
          name: deme.name,
          population: deme.population,
          dominantDecisionName: resolveDecisionName(triggeredBaldwinDecisionId, state),
          existingTraitNames
        },
        cell: {
          biome: cell.biome,
          temperature: cell.temperature,
          humidity: cell.humidity,
          altitude: cell.altitude
        }
      });
    }

    if (deme.innovationCounter >= 1.0 && demeHasCulturalCapacity(deme, state.traitsCatalog)) {
      milestones.push({
        locale: resolvedLocale,
        triggerType: "cultural_innovation",
        generation: state.generation,
        deme: {
          id: deme.id,
          name: deme.name,
          population: deme.population,
          dominantDecisionName: resolveDecisionName(deme.lastDominantDecisionId, state),
          existingTraitNames
        },
        cell: {
          biome: cell.biome,
          temperature: cell.temperature,
          humidity: cell.humidity,
          altitude: cell.altitude
        }
      });
    }

    if (deme.isolationTurns >= 10) {
      const lineageNode = state.lineageTree[deme.lineageId];
      const founderTraits =
        lineageNode !== undefined ? new Set(lineageNode.acquiredTraitIds) : new Set<string>();
      const demeTraits = new Set([...deme.biologicalTraitIds, ...deme.culturalTraitIds]);

      const hasNovelBioTrait = deme.biologicalTraitIds.some(
        (traitId) => !founderTraits.has(traitId)
      );
      const divergenceFromFounder = computeTraitSetDivergence(demeTraits, founderTraits);
      const founderCell =
        lineageNode !== undefined ? state.cells[lineageNode.founderHexId] : undefined;
      const inDistinctBiomeAfterIsolation =
        founderCell !== undefined && founderCell.biome !== cell.biome;

      if (hasNovelBioTrait || divergenceFromFounder >= 0.30 || inDistinctBiomeAfterIsolation) {
        milestones.push({
          locale: resolvedLocale,
          triggerType: "allopatric_speciation",
          generation: state.generation,
          deme: {
            id: deme.id,
            name: deme.name,
            population: deme.population,
            dominantDecisionName: resolveDecisionName(deme.lastDominantDecisionId, state),
            existingTraitNames
          },
          cell: {
            biome: cell.biome,
            temperature: cell.temperature,
            humidity: cell.humidity,
            altitude: cell.altitude
          }
        });
      }
    }
  }

  return milestones;
}

export function applySynthesizedMilestone(
  state: WorldState,
  input: MilestoneSynthesisInput,
  proposal: SynthesizedTraitProposal
): WorldState {
  const targetDeme = state.demes[input.deme.id];
  if (targetDeme === undefined) {
    return state;
  }

  const { balancedVector } = validateAndBalanceThermodynamics(proposal.biophysicalVector, false);
  const slug = slugifyTraitName(proposal.name);
  const baseTraitId = `emergent-${state.generation}-${slug}`;
  const traitId =
    state.traitsCatalog[baseTraitId] === undefined
      ? baseTraitId
      : `${baseTraitId}-${slugifyTraitName(targetDeme.id)}`;

  const newTrait: TraitDefinition = {
    id: traitId,
    name: proposal.name,
    category: proposal.category,
    semanticDescriptor: proposal.semanticDescriptor,
    affinityCondition: proposal.affinityCondition,
    mutuallyExclusiveWith: [],
    enablesCulturalTransmission: false,
    biophysicalVector: balancedVector,
    origin: "emergent",
    freeSandboxMode: false
  };

  const traitsCatalog: Record<string, TraitDefinition> = {
    ...state.traitsCatalog,
    [traitId]: newTrait
  };

  const demes: Record<string, Deme> = {};
  for (const [id, deme] of Object.entries(state.demes)) {
    demes[id] = {
      ...deme,
      biologicalTraitIds: [...deme.biologicalTraitIds],
      culturalTraitIds: [...deme.culturalTraitIds],
      baldwinCounters: { ...deme.baldwinCounters },
      lastDecisionProbabilities: { ...deme.lastDecisionProbabilities }
    };
  }

  const lineageTree: Record<string, LineageNode> = {};
  for (const [id, node] of Object.entries(state.lineageTree)) {
    lineageTree[id] = {
      ...node,
      acquiredTraitIds: [...node.acquiredTraitIds]
    };
  }

  const chronicle: ChronicleEntry[] = [...state.chronicle];
  const deme = demes[targetDeme.id];
  if (deme === undefined) {
    return state;
  }

  if (proposal.category === "biological") {
    if (!deme.biologicalTraitIds.includes(traitId)) {
      deme.biologicalTraitIds.push(traitId);
    }
  } else {
    if (!deme.culturalTraitIds.includes(traitId)) {
      deme.culturalTraitIds.push(traitId);
    }
  }

  if (input.triggerType === "baldwin_assimilation") {
    for (const [decisionId, count] of Object.entries(deme.baldwinCounters)) {
      if (count >= 8) {
        deme.baldwinCounters[decisionId] = 0;
      }
    }
  } else if (input.triggerType === "cultural_innovation") {
    deme.innovationCounter = Math.max(0, Number((deme.innovationCounter - 1.0).toFixed(4)));
  } else if (input.triggerType === "allopatric_speciation") {
    deme.isolationTurns = 0;
    const newLineageId = `lineage-${state.generation}-${slug}`;
    const nextColor = selectDistinctLineageColor(deme.color, lineageTree);

    const newLineageNode: LineageNode = {
      id: newLineageId,
      parentId: deme.lineageId,
      name: proposal.name,
      color: nextColor,
      foundedGeneration: state.generation,
      extinctGeneration: null,
      founderHexId: deme.hexId,
      acquiredTraitIds: Array.from(
        new Set([...deme.biologicalTraitIds, ...deme.culturalTraitIds])
      ),
      divergenceReason: "allopatric_speciation"
    };

    lineageTree[newLineageId] = newLineageNode;
    deme.lineageId = newLineageId;
    deme.color = nextColor;
  }

  const chronicleType =
    input.triggerType === "baldwin_assimilation" ? "baldwin_trait" : input.triggerType;

  chronicle.push({
    id: `chronicle-${chronicleType}-${state.generation}-${deme.id}`,
    generation: state.generation,
    type: chronicleType,
    title: proposal.chronicleTitle,
    body: proposal.chronicleBody,
    demeId: deme.id,
    lineageId: deme.lineageId,
    hexId: deme.hexId
  });

  return {
    ...state,
    traitsCatalog,
    demes,
    lineageTree,
    chronicle
  };
}
