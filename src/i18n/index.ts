import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import { DEFAULT_LOCALE, type SupportedLocale } from "../types/simulation";
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

export async function changeAppLocale(locale: SupportedLocale): Promise<void> {
  await i18n.changeLanguage(locale);
}

export { i18n };
export default i18n;
