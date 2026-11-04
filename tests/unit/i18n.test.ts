import { describe, expect, it, vi } from "vitest";
import {
  changeAppLocale,
  detectBrowserLocale,
  i18n,
  LANGUAGE_LABELS,
  LOCALE_RESOURCES,
  matchSupportedLocale
} from "../../src/i18n";
import { loadLocaleFromLocalStorage, LOCALE_STORAGE_KEY } from "../../src/store/persistence";
import { BiomeTypeSchema, DEFAULT_LOCALE, SUPPORTED_LOCALES } from "../../src/types/simulation";

const EXPECTED_DECISION_IDS = [
  "dec-conservative-forage",
  "dec-intensive-overexploit",
  "dec-selective-migration",
  "dec-cooperate-store",
  "dec-exchange-symbiosis",
  "dec-territorial-dispute",
  "dec-explore-innovate"
] as const;

const EXPECTED_TRAIT_IDS = [
  "bio-r-strategy",
  "bio-k-strategy",
  "bio-digestive-spec",
  "bio-thermal-tolerance",
  "bio-encephalization",
  "bio-social-instinct",
  "cul-fire-processing",
  "cul-extraction-tools",
  "cul-communal-conservation",
  "cul-interdeme-barter",
  "cul-warrior-expansion"
] as const;

const EXPECTED_PRESET_IDS = [
  "preset-rift-savanna",
  "preset-darwin-archipelago",
  "preset-finite-island"
] as const;

function collectLeafEntries(node: Record<string, unknown>, prefix: string): Array<[string, unknown]> {
  const entries: Array<[string, unknown]> = [];
  for (const [key, value] of Object.entries(node)) {
    const fullKey = prefix.length > 0 ? `${prefix}.${key}` : key;
    if (typeof value === "object" && value !== null && !Array.isArray(value)) {
      entries.push(...collectLeafEntries(value as Record<string, unknown>, fullKey));
    } else {
      entries.push([fullKey, value]);
    }
  }
  return entries;
}

describe("i18n configuration and 8-locale dictionary parity (FR-015, SC-006)", () => {
  it("initializes i18n with English ('en') as the default and fallback language", () => {
    expect(DEFAULT_LOCALE).toBe("en");
    expect(i18n.language).toBe("en");
    expect(SUPPORTED_LOCALES).toEqual(["en", "es", "zh", "fr", "de", "pt", "ja", "ru"]);
    for (const locale of SUPPORTED_LOCALES) {
      expect(LANGUAGE_LABELS[locale].trim().length).toBeGreaterThan(0);
    }
  });

  it("ensures 100% identical flattened leaf key sets and non-empty strings across all 8 locales", () => {
    const englishLeaves = collectLeafEntries(
      LOCALE_RESOURCES.en.translation as unknown as Record<string, unknown>,
      ""
    );
    const englishKeys = englishLeaves.map(([key]) => key).sort();
    expect(englishKeys.length).toBeGreaterThan(100);

    for (const locale of SUPPORTED_LOCALES) {
      const localeLeaves = collectLeafEntries(
        LOCALE_RESOURCES[locale].translation as unknown as Record<string, unknown>,
        ""
      );
      const localeKeys = localeLeaves.map(([key]) => key).sort();
      expect(localeKeys).toEqual(englishKeys);

      for (const [, value] of localeLeaves) {
        expect(typeof value).toBe("string");
        expect((value as string).trim().length).toBeGreaterThan(0);
      }
    }
  });

  it("includes all 7 base decisions, 11 base traits, 7 biomes, and 3 scientific presets in all 8 locales", () => {
    const expectedBiomes = BiomeTypeSchema.options;
    expect(expectedBiomes).toHaveLength(7);
    expect(EXPECTED_DECISION_IDS).toHaveLength(7);
    expect(EXPECTED_TRAIT_IDS).toHaveLength(11);
    expect(EXPECTED_PRESET_IDS).toHaveLength(3);

    for (const locale of SUPPORTED_LOCALES) {
      const dictionary = LOCALE_RESOURCES[locale].translation;

      for (const biome of expectedBiomes) {
        expect(dictionary.biomes[biome].trim().length).toBeGreaterThan(0);
      }

      for (const presetId of EXPECTED_PRESET_IDS) {
        const preset = dictionary.presets[presetId];
        expect(preset.name.trim().length).toBeGreaterThan(0);
        expect(preset.description.trim().length).toBeGreaterThan(0);
        expect(preset.scientificHypothesis.trim().length).toBeGreaterThan(0);
      }

      for (const decisionId of EXPECTED_DECISION_IDS) {
        const decision = dictionary.catalog.decisions[decisionId];
        expect(decision.name.length).toBeGreaterThanOrEqual(1);
        expect(decision.name.length).toBeLessThanOrEqual(60);
        expect(decision.semanticDescriptor.length).toBeGreaterThanOrEqual(10);
        expect(decision.semanticDescriptor.length).toBeLessThanOrEqual(300);
      }

      for (const traitId of EXPECTED_TRAIT_IDS) {
        const trait = dictionary.catalog.traits[traitId];
        expect(trait.name.length).toBeGreaterThanOrEqual(1);
        expect(trait.name.length).toBeLessThanOrEqual(60);
        expect(trait.semanticDescriptor.length).toBeGreaterThanOrEqual(10);
        expect(trait.semanticDescriptor.length).toBeLessThanOrEqual(300);
        expect(trait.affinityCondition.length).toBeGreaterThanOrEqual(5);
        expect(trait.affinityCondition.length).toBeLessThanOrEqual(200);
      }
    }
  });

  it("dynamically switches language across all 8 locales via changeAppLocale and restores back to 'en'", async () => {
    for (const locale of SUPPORTED_LOCALES) {
      await changeAppLocale(locale);
      expect(i18n.language).toBe(locale);
      expect(i18n.t("app.title")).toBe(LOCALE_RESOURCES[locale].translation.app.title);
      expect(i18n.t("catalog.decisions.dec-conservative-forage.name")).toBe(
        LOCALE_RESOURCES[locale].translation.catalog.decisions["dec-conservative-forage"].name
      );
      expect(i18n.t("presets.preset-rift-savanna.name")).toBe(
        LOCALE_RESOURCES[locale].translation.presets["preset-rift-savanna"].name
      );
    }

    await changeAppLocale("en");
    expect(i18n.language).toBe("en");
    expect(i18n.t("app.title")).toBe("Evolution Population Simulator");
  });

  it("normalizes BCP-47 browser language tags and matches the first supported locale", () => {
    expect(matchSupportedLocale(["es-ES", "en-US"])).toBe("es");
    expect(matchSupportedLocale(["pt-BR", "es"])).toBe("pt");
    expect(matchSupportedLocale(["zh-CN", "ja-JP"])).toBe("zh");
    expect(matchSupportedLocale(["it-IT", "fr-CA", "en"])).toBe("fr");
    expect(matchSupportedLocale(["it-IT", "nl-NL"])).toBe("en");
    expect(matchSupportedLocale([])).toBe("en");
  });

  it("detects browser locale from navigator and resolves default 'en' or stored localStorage locale when present", () => {
    vi.stubGlobal("navigator", { languages: ["es-MX", "en-US"], language: "es-MX" });
    let storedLocale: string | null = null;
    vi.stubGlobal("localStorage", {
      getItem: (key: string) => (key === LOCALE_STORAGE_KEY ? storedLocale : null)
    });

    expect( detectBrowserLocale()).toBe("es");
    expect(loadLocaleFromLocalStorage()).toBe("en");

    storedLocale = "de";
    expect(loadLocaleFromLocalStorage()).toBe("de");

    vi.unstubAllGlobals();
  });

  it("includes all 4 village scale tiers, 3D infrastructures, and 3D orbital camera keys across all 8 locales (FR-010)", () => {
    const villageTiers = ["camp", "hamlet", "village", "settlement"] as const;
    const infrastructureKeys = [
      "road",
      "ramp",
      "bridge",
      "disusedRoad",
      "disputeFront",
      "expedition",
      "totem",
      "ruins"
    ] as const;
    const cameraKeys = [
      "rotateLeft",
      "rotateRight",
      "tiltView",
      "zoomIn",
      "zoomOut",
      "resetView"
    ] as const;

    for (const locale of SUPPORTED_LOCALES) {
      const mapDict = LOCALE_RESOURCES[locale].translation.map;
      expect(mapDict.villageScale.trim().length).toBeGreaterThan(0);
      expect(mapDict.infrastructureTitle.trim().length).toBeGreaterThan(0);

      for (const tier of villageTiers) {
        expect(mapDict.villageTiers[tier].trim().length).toBeGreaterThan(0);
      }
      for (const infraKey of infrastructureKeys) {
        expect(mapDict.infrastructures[infraKey].trim().length).toBeGreaterThan(0);
      }
      for (const camKey of cameraKeys) {
        expect(mapDict[camKey].trim().length).toBeGreaterThan(0);
      }
    }
  });
});
