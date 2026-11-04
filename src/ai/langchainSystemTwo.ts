import { ChatOllama } from "@langchain/ollama";
import { z } from "zod";
import { validateAndBalanceThermodynamics } from "../engine/thermodynamics";
import {
  DecisionArchetypeSchema,
  MilestoneSynthesisInput,
  SupportedLocale,
  SynthesizedTraitProposal,
  SynthesizedTraitProposalSchema,
  UserCoDesignInput,
  UserCoDesignOutput,
  UserCoDesignOutputSchema
} from "../types/simulation";

export const DEFAULT_SYSTEM_TWO_BASE_URL = "http://127.0.0.1:11434";
export const DEFAULT_SYSTEM_TWO_MODEL = "gemma4:e2b";
export const DEFAULT_SYSTEM_TWO_TIMEOUT_MS = 15000;

const RawBiophysicalVectorSchema = z.object({
  metabolicCost: z.number(),
  extractionEfficiency: z.number(),
  ecologicalImpact: z.number(),
  spatialMobility: z.number(),
  socialCohesion: z.number(),
  transmissionThreshold: z.number()
});

const RawSynthesizedTraitProposalSchema = z.object({
  name: z.string(),
  category: z.string().optional(),
  semanticDescriptor: z.string(),
  affinityCondition: z.string(),
  biophysicalVector: RawBiophysicalVectorSchema,
  chronicleTitle: z.string(),
  chronicleBody: z.string()
});

const RawUserCoDesignOutputSchema = z.object({
  name: z.string(),
  semanticDescriptor: z.string(),
  affinityCondition: z.string(),
  archetype: DecisionArchetypeSchema,
  biophysicalVector: RawBiophysicalVectorSchema
});

export const LOCALE_LANGUAGE_NAMES: Record<SupportedLocale, string> = {
  en: "English",
  es: "Spanish",
  zh: "Simplified Chinese",
  fr: "French",
  de: "German",
  pt: "Portuguese",
  ja: "Japanese",
  ru: "Russian"
};

const chatOllamaClientsByKey = new Map<string, ChatOllama>();

export function getChatOllamaClient(
  baseUrl: string = DEFAULT_SYSTEM_TWO_BASE_URL,
  modelTag: string = DEFAULT_SYSTEM_TWO_MODEL
): ChatOllama {
  const key = `${baseUrl}|${modelTag}`;
  const existing = chatOllamaClientsByKey.get(key);
  if (existing) {
    return existing;
  }
  const client = new ChatOllama({
    model: modelTag,
    baseUrl,
    temperature: 0.35,
    think: false,
    numPredict: 260,
    keepAlive: "30m"
  });
  chatOllamaClientsByKey.set(key, client);
  return client;
}

function clampTextLength(text: string, minLength: number, maxLength: number, padSuffix: string): string {
  const trimmed = text.trim();
  const padded = trimmed.length < minLength ? `${trimmed} ${padSuffix}`.trim() : trimmed;
  return padded.slice(0, maxLength);
}

export function ensureUniqueTraitName(
  proposedName: string,
  input: MilestoneSynthesisInput
): string {
  const forbidden = new Set(
    [
      ...input.deme.existingTraitNames,
      ...(input.globalEmergentTraitNames ? input.globalEmergentTraitNames : [])
    ].map((name) => name.trim().toLowerCase())
  );

  const trimmed = proposedName.trim();
  if (trimmed.length > 0 && !forbidden.has(trimmed.toLowerCase())) {
    return trimmed.slice(0, 60);
  }

  const baseText = (trimmed || "Adaptation").replace(/\s*\([^)]*\)\s*$/, "").trim();
  const candidates = [
    `${baseText} (${input.cell.biome} G${input.generation})`,
    `${baseText} (${input.cell.biome} ${input.deme.name.slice(0, 12).trim()} G${input.generation})`,
    `${baseText} (${input.cell.biome} G${input.generation} II)`,
    `${baseText} (${input.cell.biome} G${input.generation} III)`
  ];

  for (const candidate of candidates) {
    const sliced = candidate.slice(0, 60).trim();
    if (!forbidden.has(sliced.toLowerCase())) {
      return sliced;
    }
  }

  return `${baseText.slice(0, 38).trim()} (${input.deme.id.slice(0, 10)} G${input.generation})`.slice(
    0,
    60
  );
}

export function buildMilestoneSynthesisPrompt(input: MilestoneSynthesisInput): string {
  const expectedCategory = input.triggerType === "cultural_innovation" ? "cultural" : "biological";
  const languageName = LOCALE_LANGUAGE_NAMES[input.locale];
  const seasonSuffix = input.season ? ` (season: ${input.season})` : "";

  const energyDetails: string[] = [];
  if (input.deme.energyReserves !== undefined) {
    energyDetails.push(`energyReserves=${Math.round(input.deme.energyReserves)}`);
  }
  if (input.deme.lastEnergyDelta !== undefined) {
    const sign = input.deme.lastEnergyDelta >= 0 ? "+" : "";
    energyDetails.push(`lastEnergyDelta=${sign}${Math.round(input.deme.lastEnergyDelta)}`);
  }
  const energySuffix = energyDetails.length > 0 ? `, ${energyDetails.join(", ")}` : "";

  const resourceDetails: string[] = [];
  if (input.cell.currentResources !== undefined) {
    resourceDetails.push(`currentResources=${Math.round(input.cell.currentResources)}`);
  }
  if (input.cell.carryingCapacity !== undefined) {
    resourceDetails.push(`carryingCapacity=${Math.round(input.cell.carryingCapacity)}`);
  }
  if (
    input.cell.carryingCapacity !== undefined &&
    input.cell.carryingCapacityMax !== undefined
  ) {
    const healthPct = Math.round(
      (input.cell.carryingCapacity / Math.max(1, input.cell.carryingCapacityMax)) * 100
    );
    resourceDetails.push(
      `health=${healthPct}% of Kmax=${Math.round(input.cell.carryingCapacityMax)}`
    );
  }
  const resourceSuffix = resourceDetails.length > 0 ? `, ${resourceDetails.join(", ")}` : "";

  const allForbiddenNames = Array.from(
    new Set([
      ...input.deme.existingTraitNames,
      ...(input.globalEmergentTraitNames ? input.globalEmergentTraitNames : [])
    ])
  );

  const lines = [
    `You are the Evolutionary & Socio-Cultural Naturalist Engine (System 2).`,
    `Write ALL text fields (name, semanticDescriptor, affinityCondition, chronicleTitle, chronicleBody) strictly in ${languageName} (locale: ${input.locale}).`,
    `Keep all text fields concise (1-2 sentences max: name <= 60 chars, semanticDescriptor 20-150 chars, affinityCondition 10-100 chars, chronicleBody 30-180 chars).`,
    `Milestone trigger: ${input.triggerType} at generation ${input.generation}${seasonSuffix}.`,
    `Required category: "${expectedCategory}".`,
    `Deme "${input.deme.name}" (population: ${input.deme.population}${energySuffix}) repeatedly selected "${input.deme.dominantDecisionName}".`,
    `Existing traits (do NOT duplicate any of these names): ${allForbiddenNames.join(", ") || "none"}.`,
    `Hex cell environment: biome=${input.cell.biome}, temperature=${input.cell.temperature}, humidity=${input.cell.humidity}, altitude=${input.cell.altitude}${resourceSuffix}.`
  ];

  if (input.recentChronicleTitles && input.recentChronicleTitles.length > 0) {
    lines.push(
      `Recent lineage chronicles: ${input.recentChronicleTitles.slice(0, 3).join(" | ")}.`
    );
  }

  lines.push(
    `Synthesize a unique, scientifically grounded emergent ${expectedCategory} adaptation with a balanced 6-axis biophysicalVector (metabolicCost, extractionEfficiency, ecologicalImpact, spatialMobility, socialCohesion in [-1, 1], transmissionThreshold in [0, 1]) and a concise causal Naturalist Notebook chronicle.`
  );

  return lines.join("\n");
}

export async function synthesizeMilestoneWithGemma(
  input: MilestoneSynthesisInput,
  options?: { baseUrl?: string; modelTag?: string; timeoutMs?: number }
): Promise<SynthesizedTraitProposal> {
  const baseUrl = options?.baseUrl ? options.baseUrl : DEFAULT_SYSTEM_TWO_BASE_URL;
  const modelTag = options?.modelTag ? options.modelTag : DEFAULT_SYSTEM_TWO_MODEL;
  const timeoutMs = options?.timeoutMs ? options.timeoutMs : DEFAULT_SYSTEM_TWO_TIMEOUT_MS;

  const expectedCategory = input.triggerType === "cultural_innovation" ? "cultural" : "biological";
  const llm = getChatOllamaClient(baseUrl, modelTag);

  const structuredLlm = llm.withStructuredOutput(RawSynthesizedTraitProposalSchema, {
    method: "jsonSchema"
  });

  const prompt = buildMilestoneSynthesisPrompt(input);

  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutHandle = setTimeout(() => {
      reject(new Error(`Ollama System 2 milestone synthesis timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  try {
    const rawProposal = await Promise.race([
      structuredLlm.invoke(prompt, { signal: AbortSignal.timeout(timeoutMs) }),
      timeoutPromise
    ]);

    const { balancedVector } = validateAndBalanceThermodynamics(rawProposal.biophysicalVector, false);
    const cleanName = ensureUniqueTraitName(
      clampTextLength(rawProposal.name, 1, 60, "Adaptation"),
      input
    );
    const cleanDesc = clampTextLength(
      rawProposal.semanticDescriptor,
      10,
      300,
      "Adaptive evolutionary response to environmental pressure."
    );

    return SynthesizedTraitProposalSchema.parse({
      name: cleanName,
      category: expectedCategory,
      semanticDescriptor: cleanDesc,
      affinityCondition: clampTextLength(
        rawProposal.affinityCondition,
        5,
        200,
        `High affinity in ${input.cell.biome}`
      ),
      biophysicalVector: balancedVector,
      chronicleTitle: rawProposal.chronicleTitle.trim() || cleanName,
      chronicleBody: rawProposal.chronicleBody.trim() || cleanDesc
    });
  } finally {
    if (timeoutHandle !== undefined) {
      clearTimeout(timeoutHandle);
    }
  }
}

export async function coDesignCatalogItemWithGemma(
  input: UserCoDesignInput,
  options?: { baseUrl?: string; modelTag?: string; timeoutMs?: number }
): Promise<UserCoDesignOutput> {
  const baseUrl = options?.baseUrl ? options.baseUrl : DEFAULT_SYSTEM_TWO_BASE_URL;
  const modelTag = options?.modelTag ? options.modelTag : DEFAULT_SYSTEM_TWO_MODEL;
  const timeoutMs = options?.timeoutMs ? options.timeoutMs : DEFAULT_SYSTEM_TWO_TIMEOUT_MS;
  const languageName = LOCALE_LANGUAGE_NAMES[input.locale];

  const llm = getChatOllamaClient(baseUrl, modelTag);

  const structuredLlm = llm.withStructuredOutput(RawUserCoDesignOutputSchema, {
    method: "jsonSchema"
  });

  const prompt = [
    `You are the Evolutionary & Socio-Cultural Catalog Co-Design Assistant (System 2).`,
    `Write ALL text fields (name, semanticDescriptor, affinityCondition) strictly in ${languageName} (locale: ${input.locale}).`,
    `Keep all text fields concise (1-2 sentences max: name <= 60 chars, semanticDescriptor 20-150 chars, affinityCondition 10-100 chars).`,
    `Target catalog item type: "${input.targetType}".`,
    `User concept: "${input.userConcept}".`,
    `Generate a scientifically grounded catalog definition with a 6-axis biophysicalVector (metabolicCost, extractionEfficiency, ecologicalImpact, spatialMobility, socialCohesion in [-1.0, 1.0], transmissionThreshold in [0.0, 1.0]) respecting thermodynamic trade-offs (high advantages in extractionEfficiency, spatialMobility, or socialCohesion require commensurate metabolicCost or negative ecologicalImpact).`
  ].join("\n");

  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutHandle = setTimeout(() => {
      reject(new Error(`Ollama System 2 co-design timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  try {
    const rawOutput = await Promise.race([
      structuredLlm.invoke(prompt, { signal: AbortSignal.timeout(timeoutMs) }),
      timeoutPromise
    ]);

    const { balancedVector } = validateAndBalanceThermodynamics(rawOutput.biophysicalVector, false);

    return UserCoDesignOutputSchema.parse({
      name: clampTextLength(rawOutput.name, 1, 60, "Concept"),
      semanticDescriptor: clampTextLength(
        rawOutput.semanticDescriptor,
        10,
        300,
        "Behavioral or evolutionary adaptation."
      ),
      affinityCondition: clampTextLength(
        rawOutput.affinityCondition,
        5,
        200,
        "Variable ecological conditions"
      ),
      archetype: rawOutput.archetype,
      biophysicalVector: balancedVector
    });
  } finally {
    if (timeoutHandle !== undefined) {
      clearTimeout(timeoutHandle);
    }
  }
}
