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
export const DEFAULT_SYSTEM_TWO_MODEL = "gemma4:e4b-it-qat";
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

function clampTextLength(text: string, minLength: number, maxLength: number, padSuffix: string): string {
  const trimmed = text.trim();
  const padded = trimmed.length < minLength ? `${trimmed} ${padSuffix}`.trim() : trimmed;
  return padded.slice(0, maxLength);
}

export async function synthesizeMilestoneWithGemma(
  input: MilestoneSynthesisInput,
  options?: { baseUrl?: string; modelTag?: string; timeoutMs?: number }
): Promise<SynthesizedTraitProposal> {
  const baseUrl = options?.baseUrl ? options.baseUrl : DEFAULT_SYSTEM_TWO_BASE_URL;
  const modelTag = options?.modelTag ? options.modelTag : DEFAULT_SYSTEM_TWO_MODEL;
  const timeoutMs = options?.timeoutMs ? options.timeoutMs : DEFAULT_SYSTEM_TWO_TIMEOUT_MS;

  const expectedCategory = input.triggerType === "cultural_innovation" ? "cultural" : "biological";
  const languageName = LOCALE_LANGUAGE_NAMES[input.locale];

  const llm = new ChatOllama({
    model: modelTag,
    baseUrl,
    temperature: 0.4,
    think: false,
    keepAlive: "30m"
  });

  const structuredLlm = llm.withStructuredOutput(RawSynthesizedTraitProposalSchema, {
    method: "jsonSchema"
  });

  const prompt = [
    `You are the Evolutionary & Socio-Cultural Naturalist Engine (System 2).`,
    `Write ALL text fields (name, semanticDescriptor, affinityCondition, chronicleTitle, chronicleBody) strictly in ${languageName} (locale: ${input.locale}).`,
    `Milestone trigger: ${input.triggerType} at generation ${input.generation}.`,
    `Required category: "${expectedCategory}".`,
    `Deme "${input.deme.name}" (population: ${input.deme.population}) repeatedly selected "${input.deme.dominantDecisionName}".`,
    `Existing traits: ${input.deme.existingTraitNames.join(", ")}.`,
    `Hex cell environment: biome=${input.cell.biome}, temperature=${input.cell.temperature}, humidity=${input.cell.humidity}, altitude=${input.cell.altitude}.`,
    `Synthesize a scientifically grounded emergent ${expectedCategory} adaptation with a balanced 6-axis biophysicalVector (metabolicCost, extractionEfficiency, ecologicalImpact, spatialMobility, socialCohesion in [-1, 1], transmissionThreshold in [0, 1]) and a causal Naturalist Notebook chronicle.`
  ].join("\n");

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
    const cleanName = clampTextLength(rawProposal.name, 1, 60, "Adaptation");
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

  const llm = new ChatOllama({
    model: modelTag,
    baseUrl,
    temperature: 0.4,
    think: false,
    keepAlive: "30m"
  });

  const structuredLlm = llm.withStructuredOutput(RawUserCoDesignOutputSchema, {
    method: "jsonSchema"
  });

  const prompt = [
    `You are the Evolutionary & Socio-Cultural Catalog Co-Design Assistant (System 2).`,
    `Write ALL text fields (name, semanticDescriptor, affinityCondition) strictly in ${languageName} (locale: ${input.locale}).`,
    `Field length constraints: name max 60 characters, semanticDescriptor 10-300 characters, affinityCondition 5-200 characters.`,
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
