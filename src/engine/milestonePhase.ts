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

const OUTCOME_TEXTS: Record<
  SupportedLocale,
  {
    singleSurvivorTitle: (name: string) => string;
    singleSurvivorBody: (name: string, pop: number) => string;
    equilibriumTitle: string;
    equilibriumBody: (demeCount: number, totalPop: number) => string;
  }
> = {
  en: {
    singleSurvivorTitle: (name) => `Evolutionary Hegemony: ${name}`,
    singleSurvivorBody: (name, pop) =>
      `After competitive and environmental extinctions eliminated rival populations, ${name} (${pop} individuals) remains as the sole surviving lineage.`,
    equilibriumTitle: "Ecological & Demographic Equilibrium Reached",
    equilibriumBody: (demeCount, totalPop) =>
      `Across 8 consecutive generations (4 full seasonal cycles), ${demeCount} active subpopulations (${totalPop} total individuals) stabilized in dynamic equilibrium with local carrying capacity.`
  },
  es: {
    singleSurvivorTitle: (name) => `Hegemonía Evolutiva: ${name}`,
    singleSurvivorBody: (name, pop) =>
      `Tras la extinción competitiva y ambiental de las demás poblaciones, ${name} (${pop} individuos) prevalece como único superviviente.`,
    equilibriumTitle: "Equilibrio Ecológico y Demográfico Alcanzado",
    equilibriumBody: (demeCount, totalPop) =>
      `Durante 8 generaciones consecutivas (4 ciclos estacionales completos), ${demeCount} subpoblaciones activas (${totalPop} individuos en total) se estabilizaron en equilibrio dinámico con la capacidad de carga local.`
  },
  zh: {
    singleSurvivorTitle: (name) => `进化主导：${name}`,
    singleSurvivorBody: (name, pop) =>
      `在竞争与环境灭绝淘汰了其他种群后，${name}（${pop} 个体）成为唯一幸存的世系。`,
    equilibriumTitle: "已达到生态与人口平衡",
    equilibriumBody: (demeCount, totalPop) =>
      `在连续 8 代（4 个完整季节周期）中，${demeCount} 个活跃亚群（共 ${totalPop} 个体）与当地环境承载力达到了动态平衡。`
  },
  fr: {
    singleSurvivorTitle: (name) => `Hégémonie Évolutive : ${name}`,
    singleSurvivorBody: (name, pop) =>
      `Après l'extinction des populations rivales, ${name} (${pop} individus) demeure la seule population survivante.`,
    equilibriumTitle: "Équilibre Écologique et Démographique Atteint",
    equilibriumBody: (demeCount, totalPop) =>
      `Sur 8 générations consécutives (4 cycles saisonniers complets), ${demeCount} sous-populations actives (${totalPop} individus au total) se sont stabilisées en équilibre dynamique avec la capacité de charge locale.`
  },
  de: {
    singleSurvivorTitle: (name) => `Evolutionäre Hegemonie: ${name}`,
    singleSurvivorBody: (name, pop) =>
      `Nach dem Aussterben konkurrierender Populationen verbleibt ${name} (${pop} Individuen) als einzige überlebende Linie.`,
    equilibriumTitle: "Ökologisches und Demografisches Gleichgewicht Erreicht",
    equilibriumBody: (demeCount, totalPop) =>
      `Über 8 aufeinanderfolgende Generationen (4 vollständige Saisonzyklen) haben sich ${demeCount} aktive Subpopulationen (insgesamt ${totalPop} Individuen) im dynamischen Gleichgewicht mit der lokalen Tragfähigkeit stabilisiert.`
  },
  pt: {
    singleSurvivorTitle: (name) => `Hegemonia Evolutiva: ${name}`,
    singleSurvivorBody: (name, pop) =>
      `Após a extinção competitiva e ambiental das populações rivais, ${name} (${pop} indivíduos) permanece como única sobrevivente.`,
    equilibriumTitle: "Equilíbrio Ecológico e Demográfico Alcançado",
    equilibriumBody: (demeCount, totalPop) =>
      `Durante 8 gerações consecutivas (4 ciclos sazonais completos), ${demeCount} subpopulações ativas (${totalPop} indivíduos no total) estabilizaram-se em equilíbrio dinâmico com a capacidade de suporte local.`
  },
  ja: {
    singleSurvivorTitle: (name) => `進化的覇権：${name}`,
    singleSurvivorBody: (name, pop) =>
      `競合他集団の絶滅を経て、${name}（${pop} 個体）が唯一の生存系統として残りました。`,
    equilibriumTitle: "生態学的・人口学的均衡に到達",
    equilibriumBody: (demeCount, totalPop) =>
      `連続8世代（4季節サイクル）にわたり、${demeCount} 個の活動デーム（計 ${totalPop} 個体）が地域の環境収容力と動的均衡に達しました。`
  },
  ru: {
    singleSurvivorTitle: (name) => `Эволюционная гегемония: ${name}`,
    singleSurvivorBody: (name, pop) =>
      `После вымирания конкурирующих популяций ${name} (${pop} особей) остается единственной выжившей линией.`,
    equilibriumTitle: "Достигнуто экологическое и демографическое равновесие",
    equilibriumBody: (demeCount, totalPop) =>
      `На протяжении 8 поколений подряд (4 полных сезонных цикла) ${demeCount} активных субпопуляций (всего ${totalPop} особей) стабилизировались в динамическом равновесии с локальной емкостью среды.`
  }
};

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
    const emergentBioCount = deme.biologicalTraitIds.filter((id) => {
      const trait = state.traitsCatalog[id];
      return trait !== undefined && trait.origin === "emergent";
    }).length;
    const emergentCulturalCount = deme.culturalTraitIds.filter((id) => {
      const trait = state.traitsCatalog[id];
      return trait !== undefined && trait.origin === "emergent";
    }).length;

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

    if (triggeredBaldwinDecisionId !== null && emergentBioCount < 3) {
      milestones.push({
        locale: resolvedLocale,
        triggerType: "baldwin_assimilation",
        triggeredByDecisionId: triggeredBaldwinDecisionId,
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

    if (
      deme.innovationCounter >= 1.0 &&
      demeHasCulturalCapacity(deme, state.traitsCatalog) &&
      emergentCulturalCount < 3
    ) {
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

    if (deme.isolationTurns >= 10 && emergentBioCount < 3) {
      const founderLineage = state.lineageTree[deme.lineageId];
      const founderTraits =
        founderLineage !== undefined ? new Set(founderLineage.acquiredTraitIds) : new Set<string>();
      const demeTraits = new Set([...deme.biologicalTraitIds, ...deme.culturalTraitIds]);

      const hasNovelBioTrait = deme.biologicalTraitIds.some(
        (traitId) => !founderTraits.has(traitId)
      );
      const divergenceFromFounder = computeTraitSetDivergence(demeTraits, founderTraits);
      const founderCell =
        founderLineage !== undefined ? state.cells[founderLineage.founderHexId] : undefined;
      const inDistinctBiomeAfterIsolation =
        founderCell !== undefined && founderCell.biome !== cell.biome;
      const separatedFromFounderHex =
        founderCell === undefined ||
        founderCell.id !== cell.id ||
        (state.generation === 0 && emergentBioCount === 0 && divergenceFromFounder >= 0.70);

      if (
        separatedFromFounderHex &&
        (hasNovelBioTrait ||
          divergenceFromFounder >= 0.30 ||
          (inDistinctBiomeAfterIsolation &&
            deme.biologicalTraitIds.length > 0 &&
            founderLineage !== undefined &&
            founderLineage.foundedGeneration < state.generation))
      ) {
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
  const sanitizedDemeId = targetDeme.id
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  const baseTraitId = `emergent-${state.generation}-${slug}`;
  let traitId =
    state.traitsCatalog[baseTraitId] === undefined
      ? baseTraitId
      : `${baseTraitId}-${sanitizedDemeId}`;
  let traitSuffix = 2;
  while (state.traitsCatalog[traitId] !== undefined) {
    traitId = `${baseTraitId}-${sanitizedDemeId}-${traitSuffix}`;
    traitSuffix += 1;
  }

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
    if (input.triggeredByDecisionId !== undefined) {
      deme.baldwinCounters[input.triggeredByDecisionId] = 0;
    } else {
      for (const [decisionId, count] of Object.entries(deme.baldwinCounters)) {
        if (count >= 8) {
          deme.baldwinCounters[decisionId] = 0;
          break;
        }
      }
    }
  } else if (input.triggerType === "cultural_innovation") {
    deme.innovationCounter = Math.max(0, Number((deme.innovationCounter - 1.0).toFixed(4)));
  } else if (input.triggerType === "allopatric_speciation") {
    const oldLineageId = deme.lineageId;
    deme.isolationTurns = 0;
    let newLineageId = `lineage-${state.generation}-${slug}`;
    if (lineageTree[newLineageId] !== undefined) {
      newLineageId = `${newLineageId}-${sanitizedDemeId}`;
    }
    let lineageSuffix = 2;
    while (lineageTree[newLineageId] !== undefined) {
      newLineageId = `lineage-${state.generation}-${slug}-${sanitizedDemeId}-${lineageSuffix}`;
      lineageSuffix += 1;
    }
    const nextColor = selectDistinctLineageColor(deme.color, lineageTree);

    const newLineageNode: LineageNode = {
      id: newLineageId,
      parentId: oldLineageId,
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

    const oldLineageNode = lineageTree[oldLineageId];
    if (
      oldLineageNode !== undefined &&
      Object.values(demes).every((d) => d.lineageId !== oldLineageId)
    ) {
      lineageTree[oldLineageId] = {
        ...oldLineageNode,
        extinctGeneration: state.generation
      };
    }
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

export function evaluateMacroEvolutionaryOutcome(
  previousState: WorldState,
  nextState: WorldState,
  locale?: SupportedLocale
): WorldState {
  const resolvedLocale: SupportedLocale = locale !== undefined ? locale : DEFAULT_LOCALE;
  const texts = OUTCOME_TEXTS[resolvedLocale];
  const livingDemes = Object.values(nextState.demes);

  if (livingDemes.length === 0) {
    return {
      ...nextState,
      quietTurns: 0
    };
  }

  const survivor = livingDemes[0]!;
  const hasPriorExtinction = nextState.chronicle.some((entry) => entry.type === "extinction");
  const hasNonMigrantExtinction = nextState.chronicle.some(
    (entry) =>
      entry.type === "extinction" &&
      (entry.lineageId !== survivor.lineageId || !/-m\d+-/.test(entry.demeId))
  );
  const alreadyLoggedSingleSurvivor = nextState.chronicle.some(
    (entry) => entry.type === "single_survivor"
  );
  const livingLineageIds = new Set(livingDemes.map((deme) => deme.lineageId));
  const totalLineages = Object.keys(nextState.lineageTree).length;
  const hasExtinctLineage = Object.values(nextState.lineageTree).some(
    (node) => node.extinctGeneration !== null
  );
  const isSingleSurvivorDeme =
    totalLineages === 1 &&
    livingDemes.length === 1 &&
    nextState.generation >= 15 &&
    hasNonMigrantExtinction;
  const isSingleSurvivingLineage =
    totalLineages > 1 && hasExtinctLineage && livingLineageIds.size === 1;

  if (
    hasPriorExtinction &&
    !alreadyLoggedSingleSurvivor &&
    (isSingleSurvivorDeme || isSingleSurvivingLineage)
  ) {
    const totalSurvivorPop = livingDemes.reduce((sum, d) => sum + d.population, 0);
    const lineageNode = nextState.lineageTree[survivor.lineageId];
    const displayName =
      livingDemes.length === 1 || lineageNode === undefined ? survivor.name : lineageNode.name;

    return {
      ...nextState,
      quietTurns: 0,
      chronicle: [
        ...nextState.chronicle,
        {
          id: `chronicle-single-survivor-${nextState.generation}-${survivor.id}`,
          generation: nextState.generation,
          type: "single_survivor",
          title: texts.singleSurvivorTitle(displayName),
          body: texts.singleSurvivorBody(displayName, totalSurvivorPop),
          demeId: survivor.id,
          lineageId: survivor.lineageId,
          hexId: survivor.hexId
        }
      ]
    };
  }

  const hadMigration = nextState.currentTurnFlows.some((flow) => flow.type === "migration");
  const hadChronicleEvent = nextState.chronicle.length > previousState.chronicle.length;
  const prevDemeIds = Object.keys(previousState.demes);
  const nextDemeIds = Object.keys(nextState.demes);
  const sameDemeSet =
    prevDemeIds.length === nextDemeIds.length &&
    nextDemeIds.every((id) => previousState.demes[id] !== undefined);

  const populationsStable =
    sameDemeSet &&
    livingDemes.every((deme) => {
      const prevDeme = previousState.demes[deme.id];
      if (prevDeme === undefined) {
        return false;
      }
      return Math.abs(deme.population - prevDeme.population) / prevDeme.population <= 0.05;
    });

  const prevQuietTurns = previousState.quietTurns !== undefined ? previousState.quietTurns : 0;
  const nextQuietTurns =
    !hadMigration && !hadChronicleEvent && populationsStable ? prevQuietTurns + 1 : 0;

  const alreadyLoggedEquilibrium = nextState.chronicle.some(
    (entry) => entry.type === "ecological_equilibrium"
  );

  if (nextState.generation >= 30 && nextQuietTurns >= 8 && !alreadyLoggedEquilibrium) {
    const primaryDeme = livingDemes[0]!;
    const totalPop = livingDemes.reduce((sum, d) => sum + d.population, 0);

    return {
      ...nextState,
      quietTurns: nextQuietTurns,
      chronicle: [
        ...nextState.chronicle,
        {
          id: `chronicle-equilibrium-${nextState.generation}-${primaryDeme.id}`,
          generation: nextState.generation,
          type: "ecological_equilibrium",
          title: texts.equilibriumTitle,
          body: texts.equilibriumBody(livingDemes.length, totalPop),
          demeId: primaryDeme.id,
          lineageId: primaryDeme.lineageId,
          hexId: primaryDeme.hexId
        }
      ]
    };
  }

  return {
    ...nextState,
    quietTurns: nextQuietTurns
  };
}
