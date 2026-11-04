import { Ollama } from "ollama/browser";
import { validateAndBalanceThermodynamics } from "../engine/thermodynamics";
import {
  BiophysicalVector,
  CognitiveProvider,
  DecisionArchetype,
  DemeDecisionEvaluationInput,
  DemeDecisionEvaluationOutput,
  MilestoneSynthesisInput,
  OllamaStatusReport,
  SupportedLocale,
  SynthesizedTraitProposal,
  SynthesizedTraitProposalSchema,
  UserCoDesignInput,
  UserCoDesignOutput,
  UserCoDesignOutputSchema
} from "../types/simulation";
import {
  coDesignCatalogItemWithGemma,
  DEFAULT_SYSTEM_TWO_MODEL,
  DEFAULT_SYSTEM_TWO_TIMEOUT_MS,
  synthesizeMilestoneWithGemma
} from "./langchainSystemTwo";
import {
  buildContextualJustification,
  DEFAULT_OLLAMA_HOST,
  DEFAULT_SYSTEM_ONE_MODEL,
  DEFAULT_SYSTEM_ONE_TIMEOUT_MS,
  evaluateDemeWithOllamaSystemOne,
  normalizeDecisionProbabilities
} from "./ollamaSystemOne";

const MOCK_MILESTONE_TEMPLATES: Record<
  SupportedLocale,
  {
    biologicalName: string;
    culturalName: string;
    descriptorPrefix: string;
    affinityPrefix: string;
    chronicleTitlePrefix: string;
    chronicleBodyPrefix: string;
  }
> = {
  en: {
    biologicalName: "Adaptive Homeostasis",
    culturalName: "Cooperative Ecological Tradition",
    descriptorPrefix: "Emergent adaptation consolidating sustained behavioral selection in",
    affinityPrefix: "High adaptive fitness in",
    chronicleTitlePrefix: "Evolutionary Milestone in",
    chronicleBodyPrefix: "Through sustained generational selection, the deme consolidated a heritable adaptation tailored to"
  },
  es: {
    biologicalName: "Homeostasis Adaptativa",
    culturalName: "Tradición Ecológica Cooperativa",
    descriptorPrefix: "Adaptación emergente que consolida la selección conductual sostenida en",
    affinityPrefix: "Alta eficacia adaptativa en",
    chronicleTitlePrefix: "Hito Evolutivo en",
    chronicleBodyPrefix: "Tras varias generaciones de presión selectiva sostenida, el deme consolidó una adaptación ajustada a"
  },
  zh: {
    biologicalName: "适应性稳态",
    culturalName: "生态协作传统",
    descriptorPrefix: "在持续的选择压力下形成的涌现适应性特征，适应于",
    affinityPrefix: "高度适应于",
    chronicleTitlePrefix: "进化里程碑：",
    chronicleBodyPrefix: "经过多代持续的环境选择，该亚群成功固定了适应于以下环境的特征："
  },
  fr: {
    biologicalName: "Homéostasie Adaptative",
    culturalName: "Tradition Écologique Coopérative",
    descriptorPrefix: "Adaptation émergente consolidant la sélection comportementale soutenue dans",
    affinityPrefix: "Haute valeur adaptative dans",
    chronicleTitlePrefix: "Jalon Évolutif dans",
    chronicleBodyPrefix: "Grâce à une sélection générationnelle soutenue, le dème a consolidé une adaptation propre à"
  },
  de: {
    biologicalName: "Adaptive Homöostase",
    culturalName: "Kooperative Ökologische Tradition",
    descriptorPrefix: "Emergente Anpassung durch anhaltende Verhaltensselektion im Biom",
    affinityPrefix: "Hohe Anpassungsfähigkeit in",
    chronicleTitlePrefix: "Evolutionärer Meilenstein in",
    chronicleBodyPrefix: "Durch anhaltenden Selektionsdruck über Generationen hinweg entwickelte die Population eine Anpassung für"
  },
  pt: {
    biologicalName: "Homeostase Adaptativa",
    culturalName: "Tradição Ecológica Cooperativa",
    descriptorPrefix: "Adaptação emergente que consolida a seleção comportamental sustentada em",
    affinityPrefix: "Alta aptidão adaptativa em",
    chronicleTitlePrefix: "Marco Evolutivo em",
    chronicleBodyPrefix: "Através de pressão seletiva sustentada por gerações, o deme consolidou uma adaptação para"
  },
  ja: {
    biologicalName: "適応的ホメオスタシス",
    culturalName: "協力的生態伝統",
    descriptorPrefix: "持続的な行動選択によって定着した創発的適応：",
    affinityPrefix: "高い適応度を示す環境：",
    chronicleTitlePrefix: "進化のマイルストーン：",
    chronicleBodyPrefix: "世代を超えた持続的な選択圧により、デームは次の環境に適応した形質を定着させました："
  },
  ru: {
    biologicalName: "Адаптивный Гомеостаз",
    culturalName: "Кооперативная Экологическая Традиция",
    descriptorPrefix: "Эмерджентная адаптация, закрепляющая устойчивый поведенческий отбор в биоме",
    affinityPrefix: "Высокая приспособленность в условиях",
    chronicleTitlePrefix: "Эволюционная веха в",
    chronicleBodyPrefix: "В результате длительного давления отбора популяция закрепила адаптацию к среде"
  }
};

export interface LiveCognitiveProviderOptions {
  host?: string;
  systemOneTag?: string;
  systemTwoTag?: string;
  systemOneTimeoutMs?: number;
  systemTwoTimeoutMs?: number;
}

export class LiveCognitiveProvider implements CognitiveProvider {
  private readonly host: string;
  private resolvedSystemOneTag: string;
  private resolvedSystemTwoTag: string;
  private readonly systemOneTimeoutMs: number;
  private readonly systemTwoTimeoutMs: number;

  constructor(options?: LiveCognitiveProviderOptions) {
    this.host = options?.host ? options.host : DEFAULT_OLLAMA_HOST;
    this.resolvedSystemOneTag = options?.systemOneTag
      ? options.systemOneTag
      : DEFAULT_SYSTEM_ONE_MODEL;
    this.resolvedSystemTwoTag = options?.systemTwoTag
      ? options.systemTwoTag
      : DEFAULT_SYSTEM_TWO_MODEL;
    this.systemOneTimeoutMs = options?.systemOneTimeoutMs
      ? options.systemOneTimeoutMs
      : DEFAULT_SYSTEM_ONE_TIMEOUT_MS;
    this.systemTwoTimeoutMs = options?.systemTwoTimeoutMs
      ? options.systemTwoTimeoutMs
      : DEFAULT_SYSTEM_TWO_TIMEOUT_MS;
  }

  async checkStatus(): Promise<OllamaStatusReport> {
    const client = new Ollama({
      host: this.host,
      fetch: (url, init) =>
        fetch(url, {
          ...init,
          signal: AbortSignal.timeout(3000)
        })
    });

    try {
      const listResponse = await client.list();
      const installedNames = listResponse.models.map((m) => m.name);

      const matchedD3 =
        installedNames.find((name) => name === this.resolvedSystemOneTag) ||
        installedNames.find((name) => name === "d3" || name.startsWith("d3:"));
      const matchedGemma =
        installedNames.find((name) => name === this.resolvedSystemTwoTag) ||
        installedNames.find((name) => name.startsWith("gemma4:e4b-it-qat")) ||
        installedNames.find((name) => name === "gemma4" || name.startsWith("gemma4:"));

      const systemOneModelReady = Boolean(matchedD3);
      const systemTwoModelReady = Boolean(matchedGemma);

      if (matchedD3) {
        this.resolvedSystemOneTag = matchedD3;
      }
      if (matchedGemma) {
        this.resolvedSystemTwoTag = matchedGemma;
      }

      const missingCommands: string[] = [];
      if (!systemOneModelReady) {
        missingCommands.push(`ollama pull ${DEFAULT_SYSTEM_ONE_MODEL}`);
      }
      if (!systemTwoModelReady) {
        missingCommands.push(`ollama pull ${DEFAULT_SYSTEM_TWO_MODEL}`);
      }

      return {
        connected: true,
        host: this.host,
        systemOneModelReady,
        resolvedSystemOneTag: this.resolvedSystemOneTag,
        systemTwoModelReady,
        resolvedSystemTwoTag: this.resolvedSystemTwoTag,
        missingCommands
      };
    } catch {
      return {
        connected: false,
        host: this.host,
        systemOneModelReady: false,
        resolvedSystemOneTag: this.resolvedSystemOneTag,
        systemTwoModelReady: false,
        resolvedSystemTwoTag: this.resolvedSystemTwoTag,
        missingCommands: [
          `ollama pull ${DEFAULT_SYSTEM_ONE_MODEL}`,
          `ollama pull ${DEFAULT_SYSTEM_TWO_MODEL}`
        ]
      };
    }
  }

  async evaluateDemeDecisions(
    input: DemeDecisionEvaluationInput
  ): Promise<DemeDecisionEvaluationOutput> {
    return evaluateDemeWithOllamaSystemOne(input, {
      host: this.host,
      modelTag: this.resolvedSystemOneTag,
      timeoutMs: this.systemOneTimeoutMs
    });
  }

  async synthesizeMilestone(
    input: MilestoneSynthesisInput
  ): Promise<SynthesizedTraitProposal> {
    return synthesizeMilestoneWithGemma(input, {
      baseUrl: this.host,
      modelTag: this.resolvedSystemTwoTag,
      timeoutMs: this.systemTwoTimeoutMs
    });
  }

  async coDesignCatalogItem(input: UserCoDesignInput): Promise<UserCoDesignOutput> {
    return coDesignCatalogItemWithGemma(input, {
      baseUrl: this.host,
      modelTag: this.resolvedSystemTwoTag,
      timeoutMs: this.systemTwoTimeoutMs
    });
  }
}

export class MockCognitiveProvider implements CognitiveProvider {
  async checkStatus(): Promise<OllamaStatusReport> {
    return {
      connected: true,
      host: "mock://deterministic",
      systemOneModelReady: true,
      resolvedSystemOneTag: DEFAULT_SYSTEM_ONE_MODEL,
      systemTwoModelReady: true,
      resolvedSystemTwoTag: DEFAULT_SYSTEM_TWO_MODEL,
      missingCommands: []
    };
  }

  async evaluateDemeDecisions(
    input: DemeDecisionEvaluationInput
  ): Promise<DemeDecisionEvaluationOutput> {
    const { currentCell, neighborCells, deme, eligibleDecisions } = input;
    const culturalIds = new Set(deme.activeCulturalTraits.map((t) => t.id));
    const hasExtractionTools = culturalIds.has("cul-extraction-tools");
    const hasCommunalConservation = culturalIds.has("cul-communal-conservation");

    const hasOpenLandBridge =
      currentCell.biome === "coastal_shallows" ||
      (currentCell.id === "0,0" &&
        input.generation <= 7 &&
        neighborCells.some(
          (n) => n.isPassable && n.biome === "coastal_shallows" && n.demesCount === 0
        ));

    const isInsularOrAlpine =
      neighborCells.some((n) => n.biome === "ocean") ||
      currentCell.biome === "tundra" ||
      currentCell.biome === "high_mountain";

    const isAridOrSavanna =
      currentCell.biome === "savanna" ||
      currentCell.biome === "arid_steppe" ||
      currentCell.humidity <= 0.5;

    let baseWeights: Record<string, number>;

    if (hasExtractionTools && !hasCommunalConservation) {
      baseWeights = {
        "dec-intensive-overexploit": 0.58,
        "dec-territorial-dispute": 0.14,
        "dec-conservative-forage": 0.1,
        "dec-cooperate-store": 0.06,
        "dec-selective-migration": 0.04,
        "dec-exchange-symbiosis": 0.04,
        "dec-explore-innovate": 0.04
      };
    } else if (hasOpenLandBridge) {
      if (deme.population >= 40) {
        baseWeights = {
          "dec-selective-migration": 0.52,
          "dec-cooperate-store": 0.2,
          "dec-conservative-forage": 0.1,
          "dec-explore-innovate": 0.08,
          "dec-exchange-symbiosis": 0.04,
          "dec-intensive-overexploit": 0.03,
          "dec-territorial-dispute": 0.03
        };
      } else {
        baseWeights = {
          "dec-cooperate-store": 0.44,
          "dec-conservative-forage": 0.26,
          "dec-selective-migration": 0.12,
          "dec-explore-innovate": 0.08,
          "dec-exchange-symbiosis": 0.04,
          "dec-intensive-overexploit": 0.03,
          "dec-territorial-dispute": 0.03
        };
      }
    } else if (isInsularOrAlpine) {
      baseWeights = {
        "dec-cooperate-store": 0.46,
        "dec-explore-innovate": 0.18,
        "dec-conservative-forage": 0.16,
        "dec-exchange-symbiosis": 0.08,
        "dec-selective-migration": 0.04,
        "dec-intensive-overexploit": 0.04,
        "dec-territorial-dispute": 0.04
      };
    } else if (isAridOrSavanna) {
      baseWeights = {
        "dec-cooperate-store": 0.42,
        "dec-selective-migration": 0.16,
        "dec-explore-innovate": 0.14,
        "dec-conservative-forage": 0.12,
        "dec-exchange-symbiosis": 0.08,
        "dec-intensive-overexploit": 0.04,
        "dec-territorial-dispute": 0.04
      };
    } else {
      baseWeights = {
        "dec-conservative-forage": 0.52,
        "dec-cooperate-store": 0.14,
        "dec-exchange-symbiosis": 0.1,
        "dec-selective-migration": 0.08,
        "dec-explore-innovate": 0.08,
        "dec-intensive-overexploit": 0.04,
        "dec-territorial-dispute": 0.04
      };
    }

    const rawScores: Record<string, number> = {};
    const eligibleIds: string[] = [];

    for (const decision of eligibleDecisions) {
      eligibleIds.push(decision.id);
      const weight = baseWeights[decision.id];
      rawScores[decision.id] = weight !== undefined ? weight : 0.08;
    }

    const { probabilities, dominantDecisionId } = normalizeDecisionProbabilities(
      rawScores,
      eligibleIds
    );
    const confidence = 0.88;
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
  }

  async synthesizeMilestone(
    input: MilestoneSynthesisInput
  ): Promise<SynthesizedTraitProposal> {
    const template = MOCK_MILESTONE_TEMPLATES[input.locale];
    const category = input.triggerType === "cultural_innovation" ? "cultural" : "biological";
    const baseName =
      category === "cultural" ? template.culturalName : template.biologicalName;
    const name = `${baseName} (${input.cell.biome} G${input.generation})`.slice(0, 60);

    const rawVector: BiophysicalVector =
      category === "cultural"
        ? {
            metabolicCost: 0.2,
            extractionEfficiency: 0.35,
            ecologicalImpact: 0.2,
            spatialMobility: 0.15,
            socialCohesion: 0.4,
            transmissionThreshold: 0.45
          }
        : {
            metabolicCost: 0.18,
            extractionEfficiency: 0.35,
            ecologicalImpact: 0.1,
            spatialMobility: 0.3,
            socialCohesion: 0.2,
            transmissionThreshold: 0.2
          };

    const { balancedVector } = validateAndBalanceThermodynamics(rawVector, false);

    return SynthesizedTraitProposalSchema.parse({
      name,
      category,
      semanticDescriptor:
        `${template.descriptorPrefix} ${input.cell.biome} (${input.deme.dominantDecisionName}).`.slice(
          0,
          300
        ),
      affinityCondition: `${template.affinityPrefix} ${input.cell.biome}`.slice(0, 200),
      biophysicalVector: balancedVector,
      chronicleTitle: `${template.chronicleTitlePrefix} ${input.deme.name} (G${input.generation})`,
      chronicleBody: `${template.chronicleBodyPrefix} ${input.cell.biome} (${input.deme.dominantDecisionName}).`
    });
  }

  async coDesignCatalogItem(input: UserCoDesignInput): Promise<UserCoDesignOutput> {
    const template = MOCK_MILESTONE_TEMPLATES[input.locale];
    const trimmedConcept = input.userConcept.trim() || template.culturalName;
    const name = trimmedConcept.slice(0, 60);

    const archetype: DecisionArchetype =
      input.targetType === "decision" ? "cooperate" : "custom";

    const rawVector: BiophysicalVector = {
      metabolicCost: 0.22,
      extractionEfficiency: 0.4,
      ecologicalImpact: 0.15,
      spatialMobility: 0.2,
      socialCohesion: 0.35,
      transmissionThreshold: 0.35
    };

    const { balancedVector } = validateAndBalanceThermodynamics(rawVector, false);

    return UserCoDesignOutputSchema.parse({
      name,
      semanticDescriptor: `${template.descriptorPrefix} ${trimmedConcept} (${input.targetType}).`.slice(
        0,
        300
      ),
      affinityCondition: `${template.affinityPrefix} ${trimmedConcept}`.slice(0, 200),
      archetype,
      biophysicalVector: balancedVector
    });
  }
}
