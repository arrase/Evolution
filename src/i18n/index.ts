import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import { DEFAULT_LOCALE, SUPPORTED_LOCALES, type SupportedLocale } from "../types/simulation";
import de from "./locales/de.json";
import en from "./locales/en.json";
import es from "./locales/es.json";
import fr from "./locales/fr.json";
import ja from "./locales/ja.json";
import pt from "./locales/pt.json";
import ru from "./locales/ru.json";
import zh from "./locales/zh.json";

export const LANGUAGE_LABELS: Record<SupportedLocale, string> = {
  en: "English",
  es: "Español",
  zh: "中文",
  fr: "Français",
  de: "Deutsch",
  pt: "Português",
  ja: "日本語",
  ru: "Русский"
};

export const LOCALE_RESOURCES: Record<SupportedLocale, { translation: typeof en }> = {
  en: { translation: en },
  es: { translation: es },
  zh: { translation: zh },
  fr: { translation: fr },
  de: { translation: de },
  pt: { translation: pt },
  ja: { translation: ja },
  ru: { translation: ru }
};

void i18n.use(initReactI18next).init({
  resources: LOCALE_RESOURCES,
  lng: DEFAULT_LOCALE,
  fallbackLng: DEFAULT_LOCALE,
  interpolation: {
    escapeValue: false
  }
});

export function matchSupportedLocale(languageTags: readonly string[]): SupportedLocale {
  for (const tag of languageTags) {
    const primarySubtag = tag.split(/[-_]/)[0]!.toLowerCase();
    const matched = SUPPORTED_LOCALES.find((locale) => locale === primarySubtag);
    if (matched !== undefined) {
      return matched;
    }
  }
  return DEFAULT_LOCALE;
}

export function detectBrowserLocale(): SupportedLocale {
  if (typeof navigator === "undefined") {
    return DEFAULT_LOCALE;
  }
  const tags = navigator.languages.length > 0 ? navigator.languages : [navigator.language];
  return matchSupportedLocale(tags);
}

export async function changeAppLocale(locale: SupportedLocale): Promise<void> {
  await i18n.changeLanguage(locale);
  if (typeof document !== "undefined") {
    document.documentElement.lang = locale;
    document.title = i18n.t("app.title");
  }
}

export { i18n };
export default i18n;
