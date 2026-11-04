import { detectBrowserLocale } from "../i18n";
import {
  SupportedLocaleSchema,
  WorldStateSchema,
  type SupportedLocale,
  type WorldState
} from "../types/simulation";

export const WORLD_STORAGE_KEY = "evolution_sim_world_v2";
export const LOCALE_STORAGE_KEY = "evolution_sim_locale_v1";
export const FIRST_STEPS_STORAGE_KEY = "evolution_sim_first_steps_dismissed_v1";

export function serializeWorldState(world: WorldState): string {
  const validated = WorldStateSchema.parse(world);
  return JSON.stringify(validated, null, 2);
}

export function deserializeWorldState(jsonPayload: string): WorldState {
  const parsed: unknown = JSON.parse(jsonPayload);
  return WorldStateSchema.parse(parsed);
}

export function saveWorldToLocalStorage(world: WorldState): void {
  localStorage.setItem(WORLD_STORAGE_KEY, serializeWorldState(world));
}

export function loadWorldFromLocalStorage(): WorldState | null {
  const stored = localStorage.getItem(WORLD_STORAGE_KEY);
  if (stored === null) {
    return null;
  }
  return deserializeWorldState(stored);
}

export function saveLocaleToLocalStorage(locale: SupportedLocale): void {
  const validated = SupportedLocaleSchema.parse(locale);
  localStorage.setItem(LOCALE_STORAGE_KEY, validated);
}

export function loadLocaleFromLocalStorage(): SupportedLocale {
  const stored = localStorage.getItem(LOCALE_STORAGE_KEY);
  if (stored === null) {
    return detectBrowserLocale();
  }
  return SupportedLocaleSchema.parse(stored);
}

export function saveFirstStepsDismissed(): void {
  localStorage.setItem(FIRST_STEPS_STORAGE_KEY, "true");
}

export function loadFirstStepsDismissed(): boolean {
  return localStorage.getItem(FIRST_STEPS_STORAGE_KEY) === "true";
}

export function clearPersistedSession(): void {
  localStorage.removeItem(WORLD_STORAGE_KEY);
  localStorage.removeItem(LOCALE_STORAGE_KEY);
}
