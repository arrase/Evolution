import { Ollama, SystemOneChoiceAnswer } from "ollama/browser";
import {
  BiophysicalVector,
  DemeDecisionEvaluationInput,
  DemeDecisionEvaluationOutput,
  SupportedLocale
} from "../types/simulation";

export const DEFAULT_OLLAMA_HOST = "http://127.0.0.1:11434";
export const DEFAULT_SYSTEM_ONE_MODEL = "d3:4b";
export const DEFAULT_SYSTEM_ONE_TIMEOUT_MS = 5000;

export interface EvaluateSystemOneOptions {
  host?: string;
  modelTag?: string;
  timeoutMs?: number;
}

const ollamaClientsByHost = new Map<string, Ollama>();

export function getOllamaClient(host: string = DEFAULT_OLLAMA_HOST): Ollama {
  const existing = ollamaClientsByHost.get(host);
  if (existing) {
    return existing;
  }
  const client = new Ollama({
    host,
    fetch: (url, init) =>
      fetch(url, {
        ...init,
        signal: AbortSignal.timeout(DEFAULT_SYSTEM_ONE_TIMEOUT_MS)
      })
  });
  ollamaClientsByHost.set(host, client);
  return client;
}

const JUSTIFICATION_LABELS: Record<
  SupportedLocale,
  {
    biome: string;
    resources: string;
    traits: string;
    none: string;
    dominant: string;
    confidence: string;
  }
> = {
  en: {
    biome: "Biome",
    resources: "Resources",
    traits: "Key traits",
    none: "None",
    dominant: "Dominant decision",
    confidence: "confidence"
  },
  es: {
    biome: "Bioma",
    resources: "Recursos",
    traits: "Rasgos clave",
    none: "Ninguno",
    dominant: "Decisión dominante",
    confidence: "confianza"
  },
  zh: {
    biome: "生物群系",
    resources: "资源",
    traits: "关键特征",
    none: "无",
    dominant: "主导决策",
    confidence: "置信度"
  },
  fr: {
    biome: "Biome",
    resources: "Ressources",
    traits: "Traits clés",
    none: "Aucun",
    dominant: "Décision dominante",
    confidence: "confiance"
  },
  de: {
    biome: "Biom",
    resources: "Ressourcen",
    traits: "Schlüsselmerkmale",
    none: "Keine",
    dominant: "Dominante Entscheidung",
    confidence: "Konfidenz"
  },
  pt: {
    biome: "Bioma",
    resources: "Recursos",
    traits: "Traços-chave",
    none: "Nenhum",
    dominant: "Decisão dominante",
    confidence: "confiança"
  },
  ja: {
    biome: "バイオーム",
    resources: "資源",
    traits: "主要特性",
    none: "なし",
    dominant: "優位な意思決定",
    confidence: "信頼度"
  },
  ru: {
    biome: "Биом",
    resources: "Ресурсы",
    traits: "Ключевые черты",
    none: "Нет",
    dominant: "Доминирующее решение",
    confidence: "уверенность"
  }
};

export function normalizeDecisionProbabilities(
  rawScores: Record<string, number>,
  eligibleDecisionIds: string[]
): { probabilities: Record<string, number>; dominantDecisionId: string } {
  if (eligibleDecisionIds.length === 0) {
    return { probabilities: {}, dominantDecisionId: "" };
  }

  const positiveScores: Record<string, number> = {};
  let sum = 0;

  for (const id of eligibleDecisionIds) {
    const val = rawScores[id];
    const cleanScore = typeof val === "number" && Number.isFinite(val) && val > 0 ? val : 0;
    positiveScores[id] = cleanScore;
    sum += cleanScore;
  }

  if (sum <= 0) {
    const uniformWeight = 1 / eligibleDecisionIds.length;
    for (const id of eligibleDecisionIds) {
      positiveScores[id] = uniformWeight;
    }
    sum = 1;
  }

  let maxDecisionId: string = eligibleDecisionIds[0]!;
  let maxScore = -1;

  for (const id of eligibleDecisionIds) {
    const score = positiveScores[id]!;
    if (score > maxScore) {
      maxScore = score;
      maxDecisionId = id;
    }
  }

  const tempProbabilities: Record<string, number> = {};
  let otherSum = 0;
  let highestOtherId = "";
  let highestOtherProb = -1;

  for (const id of eligibleDecisionIds) {
    if (id === maxDecisionId) {
      continue;
    }
    const score = positiveScores[id]!;
    const rounded = Number((score / sum).toFixed(4));
    tempProbabilities[id] = rounded;
    otherSum += rounded;
    if (rounded > highestOtherProb) {
      highestOtherProb = rounded;
      highestOtherId = id;
    }
  }

  const complement = Number(Math.max(0, 1 - otherSum).toFixed(4));
  if (highestOtherId && highestOtherProb > complement) {
    tempProbabilities[maxDecisionId] = highestOtherProb;
    tempProbabilities[highestOtherId] = complement;
  } else {
    tempProbabilities[maxDecisionId] = complement;
  }

  const probabilities: Record<string, number> = {
    [maxDecisionId]: tempProbabilities[maxDecisionId]!
  };
  for (const id of eligibleDecisionIds) {
    if (id !== maxDecisionId) {
      probabilities[id] = tempProbabilities[id]!;
    }
  }

  return {
    probabilities,
    dominantDecisionId: maxDecisionId
  };
}

export function buildContextualJustification(
  input: DemeDecisionEvaluationInput,
  dominantDecisionId: string,
  dominantProbability: number,
  confidence: number
): string {
  const labels = JUSTIFICATION_LABELS[input.locale];
  const allTraitNames = [
    ...input.deme.activeBiologicalTraits.map((t) => t.name),
    ...input.deme.activeCulturalTraits.map((t) => t.name)
  ];
  const traitText = allTraitNames.length > 0 ? allTraitNames.join(", ") : labels.none;
  const dominantDecision = input.eligibleDecisions.find((d) => d.id === dominantDecisionId);
  const dominantName = dominantDecision ? dominantDecision.name : dominantDecisionId;
  const currentRes = Math.round(input.currentCell.currentResources);
  const capacity = Math.round(input.currentCell.carryingCapacity);
  const pct = (dominantProbability * 100).toFixed(1);
  const confPct = (confidence * 100).toFixed(0);

  return `[${labels.biome}: ${input.currentCell.biome} | ${labels.resources}: ${currentRes}/${capacity} | ${labels.traits}: ${traitText}] → ${labels.dominant}: ${dominantName} (${pct}%, ${labels.confidence} ${confPct}%)`;
}

function formatSignedMetric(value: number): string {
  const rounded = Number(value.toFixed(2));
  return `${rounded >= 0 ? "+" : ""}${rounded}`;
}

function computeVitalityStatus(
  energyReserves: number,
  lastEnergyDelta: number,
  resourceAdequacyRatio: number
): "starving" | "struggling" | "thriving" | "stable" {
  if (energyReserves < 25 || (lastEnergyDelta < -15 && energyReserves < 50)) {
    return "starving";
  }
  if (lastEnergyDelta < -3 || resourceAdequacyRatio < 0.85) {
    return "struggling";
  }
  if (energyReserves >= 75 && lastEnergyDelta >= 0 && resourceAdequacyRatio >= 1.3) {
    return "thriving";
  }
  return "stable";
}

function getSortedPassableNeighbors(
  neighborCells: DemeDecisionEvaluationInput["neighborCells"]
): DemeDecisionEvaluationInput["neighborCells"] {
  return neighborCells
    .filter((n) => n.isPassable)
    .slice()
    .sort((a, b) => {
      const aPop = a.totalPopulation !== undefined ? a.totalPopulation : a.demesCount * 50;
      const bPop = b.totalPopulation !== undefined ? b.totalPopulation : b.demesCount * 50;
      const aScore = a.currentResources / Math.max(10, aPop);
      const bScore = b.currentResources / Math.max(10, bPop);
      return bScore - aScore;
    });
}

function formatCompactTrait(trait: {
  name: string;
  affinityCondition: string;
  biophysicalVector?: BiophysicalVector;
}): string {
  if (trait.biophysicalVector) {
    const v = trait.biophysicalVector;
    return `${trait.name}[cost:${formatSignedMetric(v.metabolicCost)},extract:${formatSignedMetric(v.extractionEfficiency)},eco:${formatSignedMetric(v.ecologicalImpact)},mobility:${formatSignedMetric(v.spatialMobility)},cohesion:${formatSignedMetric(v.socialCohesion)}]`;
  }
  return `${trait.name}[${trait.affinityCondition.slice(0, 18).trim()}]`;
}

export function buildCompactSystemOneState(input: DemeDecisionEvaluationInput): string {
  const totalCellPopulation =
    input.currentCell.totalCellPopulation !== undefined
      ? input.currentCell.totalCellPopulation
      : input.deme.population * (1 + input.currentCell.cohabitingDemesCount);
  const resourceAdequacyRatio = Number(
    (input.currentCell.currentResources / Math.max(10, totalCellPopulation * 0.48)).toFixed(2)
  );
  const healthPct = Math.round(
    (input.currentCell.carryingCapacity / Math.max(1, input.currentCell.carryingCapacityMax)) * 100
  );
  const vitality = computeVitalityStatus(
    input.deme.energyReserves,
    input.deme.lastEnergyDelta,
    resourceAdequacyRatio
  );
  const rivalCount =
    input.currentCell.rivalDemesCount !== undefined
      ? input.currentCell.rivalDemesCount
      : input.currentCell.cohabitingDemesCount;
  const kinCount =
    input.currentCell.kinDemesCount !== undefined ? input.currentCell.kinDemesCount : 0;

  const line1 = `Gen ${input.generation} (${input.season}) | Hex ${input.currentCell.id} (${input.currentCell.biome}): resources=${Math.round(input.currentCell.currentResources)}/${Math.round(input.currentCell.carryingCapacity)} (health=${healthPct}% of Kmax=${Math.round(input.currentCell.carryingCapacityMax)}), caloricAdequacy=${resourceAdequacyRatio}x, temp=${input.currentCell.temperature}, hum=${input.currentCell.humidity}, alt=${input.currentCell.altitude}`;
  const line2 = `Deme "${input.deme.name}": pop=${input.deme.population} (${vitality}), reserves=${Math.round(input.deme.energyReserves)}, delta=${input.deme.lastEnergyDelta >= 0 ? "+" : ""}${Math.round(input.deme.lastEnergyDelta)} | CellCompetition: totalPop=${totalCellPopulation}, cohabiting=${input.currentCell.cohabitingDemesCount} (rivals=${rivalCount}, kin=${kinCount})`;

  const allTraits = [
    ...input.deme.activeBiologicalTraits.map(formatCompactTrait),
    ...input.deme.activeCulturalTraits.map(formatCompactTrait)
  ];
  const line3 = `Traits: ${allTraits.length > 0 ? allTraits.join("; ") : "none"}`;

  const topNeighbors = getSortedPassableNeighbors(input.neighborCells).slice(0, 3);
  const neighborsText =
    topNeighbors.length > 0
      ? topNeighbors
          .map((n) => {
            const nPop = n.totalPopulation !== undefined ? n.totalPopulation : n.demesCount * 50;
            return `${n.id}(${n.biome}, res=${Math.round(n.currentResources)}, pop=${nPop}, ${n.demesCount === 0 ? "empty" : "occupied"})`;
          })
          .join(", ")
      : "none";
  const line4 = `lastDominant=${input.deme.lastDominantDecisionId ?? "none"}, baldwin=${input.deme.baldwinProgress ?? 0}/8, innovation=${(input.deme.innovationProgress ?? 0).toFixed(2)}/2.0 | Neighbors: ${neighborsText}`;

  const hasExtractionTools = input.deme.activeCulturalTraits.some(
    (t) => t.id === "cul-extraction-tools" || t.name.toLowerCase().includes("extraction")
  );
  const hasOpenBridge =
    input.currentCell.biome === "coastal_shallows" ||
    topNeighbors.some((n) => n.biome === "coastal_shallows" && n.demesCount === 0);

  let line5: string;
  if (hasOpenBridge) {
    line5 = "Cue: Open coastal_shallows land bridge favors migration.";
  } else if (hasExtractionTools) {
    line5 =
      "Cue: Specialized Extraction Tools and rival competition drive Intensive Overexploitation and Territorial Dispute to maximize immediate extraction.";
  } else if (resourceAdequacyRatio < 0.85 || vitality === "starving") {
    line5 = "Cue: Resource scarcity favors cooperation or migration.";
  } else if (
    input.currentCell.biome === "savanna" ||
    input.currentCell.biome === "arid_steppe" ||
    input.currentCell.humidity <= 0.5
  ) {
    line5 = "Cue: Seasonal savanna aridity favors cooperation and migration.";
  } else {
    line5 = `Cue: Abundant stable ${input.currentCell.biome} favors conservative foraging.`;
  }

  return [line1, line2, line3, line4, line5].join("\n");
}

export function buildCompactDecisionCriteria(
  eligibleDecisions: DemeDecisionEvaluationInput["eligibleDecisions"]
): Record<string, string> {
  const criteria: Record<string, string> = {};
  for (const decision of eligibleDecisions) {
    if (decision.biophysicalVector) {
      const v = decision.biophysicalVector;
      const vecText = `[cost:${formatSignedMetric(v.metabolicCost)},extract:${formatSignedMetric(v.extractionEfficiency)},eco:${formatSignedMetric(v.ecologicalImpact)},mobility:${formatSignedMetric(v.spatialMobility)},cohesion:${formatSignedMetric(v.socialCohesion)}]`;
      criteria[decision.id] = `${decision.name} ${vecText}: ${decision.semanticDescriptor}`.slice(
        0,
        120
      );
    } else {
      criteria[decision.id] = `${decision.name}: ${decision.semanticDescriptor}`.slice(0, 120);
    }
  }
  return criteria;
}

export function computeDemeEvaluationSignature(input: DemeDecisionEvaluationInput): string {
  const totalCellPopulation =
    input.currentCell.totalCellPopulation !== undefined
      ? input.currentCell.totalCellPopulation
      : input.deme.population * (1 + input.currentCell.cohabitingDemesCount);
  const resourceAdequacyRatio = Number(
    (input.currentCell.currentResources / Math.max(10, totalCellPopulation * 0.48)).toFixed(2)
  );
  const adequacyBucket = Math.min(6, Math.floor(resourceAdequacyRatio * 2));
  const healthBucket = Math.floor(
    (input.currentCell.carryingCapacity / Math.max(1, input.currentCell.carryingCapacityMax)) * 4
  );
  const vitality = computeVitalityStatus(
    input.deme.energyReserves,
    input.deme.lastEnergyDelta,
    resourceAdequacyRatio
  );
  const rivalCount =
    input.currentCell.rivalDemesCount !== undefined
      ? input.currentCell.rivalDemesCount
      : input.currentCell.cohabitingDemesCount;
  const kinCount =
    input.currentCell.kinDemesCount !== undefined ? input.currentCell.kinDemesCount : 0;
  const competitionKey = `${rivalCount}:${kinCount}:${input.deme.population >= 40 ? "viable" : "small"}`;
  const traitsKey = [
    ...input.deme.activeBiologicalTraits.map((t) => t.id),
    ...input.deme.activeCulturalTraits.map((t) => t.id)
  ]
    .sort()
    .join(",");
  const dominantKey = input.deme.lastDominantDecisionId ?? "";
  const neighborKey = getSortedPassableNeighbors(input.neighborCells)
    .slice(0, 2)
    .map(
      (n) =>
        `${n.biome}:${n.demesCount === 0 ? "empty" : "occupied"}:${Math.round(n.currentResources / 100)}`
    )
    .join(",");

  return `${input.season}|${input.currentCell.biome}|${adequacyBucket}|${healthBucket}|${vitality}|${competitionKey}|${traitsKey}|${dominantKey}|${neighborKey}`;
}

export async function evaluateDemeWithOllamaSystemOne(
  input: DemeDecisionEvaluationInput,
  options?: EvaluateSystemOneOptions
): Promise<DemeDecisionEvaluationOutput> {
  const host = options?.host ? options.host : DEFAULT_OLLAMA_HOST;
  const modelTag = options?.modelTag ? options.modelTag : DEFAULT_SYSTEM_ONE_MODEL;
  const timeoutMs = options?.timeoutMs ? options.timeoutMs : DEFAULT_SYSTEM_ONE_TIMEOUT_MS;

  const ollamaClient = getOllamaClient(host);
  const criteria = buildCompactDecisionCriteria(input.eligibleDecisions);
  const eligibleIds = input.eligibleDecisions.map((decision) => decision.id);

  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutHandle = setTimeout(() => {
      reject(new Error(`Ollama System 1 evaluation timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  try {
    const response = await Promise.race([
      ollamaClient.systemone({
        model: modelTag,
        keep_alive: "30m",
        state: {
          briefing: buildCompactSystemOneState(input)
        },
        questions: {
          decision: {
            type: "choice",
            instructions:
              "Evaluate the ecological, energetic, and social state of the deme and its passable neighbors to score each behavioral decision.",
            criteria
          }
        }
      }),
      timeoutPromise
    ]);

    const answer = response?.answers?.decision as SystemOneChoiceAnswer | undefined;
    if (
      !answer ||
      answer.type !== "choice" ||
      !answer.probabilities ||
      typeof answer.probabilities !== "object"
    ) {
      throw new Error("Ollama System 1 response did not contain a valid choice answer");
    }

    const { probabilities, dominantDecisionId } = normalizeDecisionProbabilities(
      answer.probabilities,
      eligibleIds
    );
    const rawConfidence = answer.confidence;
    const confidence = Number.isFinite(rawConfidence)
      ? Number(Math.min(1, Math.max(0, rawConfidence)).toFixed(4))
      : 0.75;
    const dominantProbability = probabilities[dominantDecisionId]!;
    const justification = buildContextualJustification(
      input,
      dominantDecisionId,
      dominantProbability,
      confidence
    );

    return {
      probabilities,
      dominantDecisionId,
      confidence,
      justification
    };
  } finally {
    if (timeoutHandle !== undefined) {
      clearTimeout(timeoutHandle);
    }
  }
}
