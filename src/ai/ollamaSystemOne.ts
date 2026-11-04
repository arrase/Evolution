import { Ollama, SystemOneChoiceAnswer } from "ollama/browser";
import {
  DemeDecisionEvaluationInput,
  DemeDecisionEvaluationOutput,
  SupportedLocale
} from "../types/simulation";

export const DEFAULT_OLLAMA_HOST = "http://127.0.0.1:11434";
export const DEFAULT_SYSTEM_ONE_MODEL = "d3:4b";
export const DEFAULT_SYSTEM_ONE_TIMEOUT_MS = 5000;

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

export async function evaluateDemeWithOllamaSystemOne(
  input: DemeDecisionEvaluationInput,
  options?: { host?: string; modelTag?: string; timeoutMs?: number }
): Promise<DemeDecisionEvaluationOutput> {
  const host = options?.host ? options.host : DEFAULT_OLLAMA_HOST;
  const modelTag = options?.modelTag ? options.modelTag : DEFAULT_SYSTEM_ONE_MODEL;
  const timeoutMs = options?.timeoutMs ? options.timeoutMs : DEFAULT_SYSTEM_ONE_TIMEOUT_MS;

  const ollamaClient = new Ollama({
    host,
    fetch: (url, init) =>
      fetch(url, {
        ...init,
        signal: AbortSignal.timeout(timeoutMs)
      })
  });

  const criteria: Record<string, string | null> = {};
  const eligibleIds: string[] = [];

  for (const decision of input.eligibleDecisions) {
    criteria[decision.id] = decision.semanticDescriptor;
    eligibleIds.push(decision.id);
  }

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
          generation: input.generation,
          season: input.season,
          deme: input.deme,
          currentCell: input.currentCell,
          neighborCells: input.neighborCells
        },
        questions: {
          decision: {
            type: "choice",
            instructions:
              "Evaluate the ecological, energetic, and social state of the deme and its 6 neighboring hex cells to score each behavioral decision.",
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
