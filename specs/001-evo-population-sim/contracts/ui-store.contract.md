# Contract: Single-View Web UI & Zustand Store

**Feature**: `001-evo-population-sim`
**Module**: `src/store/useSimulationStore.ts` & `src/components/`
**Requirements Covered**: `FR-001`, `FR-005`, `FR-010`, `FR-011`, `FR-012`, `FR-014`, `FR-015`, `SC-002`..`SC-006`

## 1. Layout Integrado de Vista Única (`FR-010`, `FR-015`)

La aplicación se renderiza en un único viewport (`100vw x 100vh`) con **inglés (`en`) como idioma por defecto** y soporte `i18n` reactivo (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`), dividido en 4 regiones permanentes más un cajón/modal de Laboratorio:

1. **Barra Superior de Control Temporal y Estado (`TopControlBar.tsx`)**:
   - Selector de Preset Científico (`"El Rift y la Sabana"`, `"Archipiélago de Darwin"`, `"La Isla Finita"`) y **Selector de Idioma (`en` por defecto, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`)**.
   - Indicadores de `Generación`, `Estación Climática` (`Húmeda/Cálida` vs. `Seca/Fría`), `Nivel del Mar` y `Estado de Ollama` (`d3:4b` + `gemma4:e4b-it-qat`).
   - Controles de reproducción (`Pausa`, `Paso +1 Gen`, `Auto-Play Normal [1.5s]`, `Auto-Play Rápido [0.3s]`) e interruptor opcional `Auto-Pausa en Hitos` (**desactivado por defecto**, `autoPauseOnMilestone: false`, de modo que el `Auto-Play` corre continuamente hasta alcanzar un desenlace macro-evolutivo: `total_extinction`, `single_survivor` o `ecological_equilibrium`).
   - Botones para abrir el **Laboratorio de Catálogo**, el **Árbol Filo-Cultural**, el **Cuaderno del Naturalista** y **Exportar / Importar JSON**.
2. **Lienzo Central del Mapa Hexagonal (`HexMapCanvas.tsx`)**:
   - `<svg>` interactivo generado con `honeycomb-grid@4.1.5` mostrando las **5 capas visuales de cada hexágono** (`FR-001`):
     1. Polígono base coloreado según `biome` y sombreado de `altitude`.
     2. Indicador central de biomasa/recursos (`currentResources`).
     3. Anillo perimetral segmentado o arco proporcional a la salud ecológica ($K / K_{\max}$).
     4. Hasta 3 nodos circulares coloreados representando los `Deme` presentes (con radio escalado logarítmicamente según `population`).
     5. Vectores direccionales animados (`<line>` con `marker-end`) sobre las 6 aristas para los `HexEdgeFlow` del turno (`migration`, `exchange`, `dispute`).
3. **Barra Inferior de Pincel de Presión Selectiva (`SelectivePressureToolbar.tsx` — `FR-011`)**:
   - Muestra los **Puntos de Presión Ambiental** disponibles y el conmutador `Presupuesto Ilimitado`.
   - Herramientas de pincel (aplicables por clic o arrastre sobre hexágonos, con radio `1` o `2`):
     - `Cambiar Bioma / Clima` (Coste: `10 pts` por celda)
     - `Elevar Cordillera (+Altitud)` / `Hundir Cuenca (-Altitud)` (Coste: `15 pts` por celda)
     - `Enriquecer / Agotar Recursos y K` (Coste: `10 pts` por celda)
     - `Oscilar Nivel del Mar Global` (Coste: `25 pts`)
4. **Panel Lateral Derecho: Inspector Cognitivo y Crónica en Vivo (`CognitiveInspectorPanel.tsx` — `FR-010`, `SC-003`)**:
   - Propiedades del hexágono seleccionado (`q, r`, bioma, $T$, humedad, altitud, $R$, $K / K_{\max}$).
   - Selector de *deme* dentro del hexágono y ficha completa: población, reservas calóricas, $\Delta E$, contadores de Baldwin / Innovación / Aislamiento.
   - **Barras de Probabilidad de `d3` en Vivo**: gráfico horizontal ordenado con el porcentaje exacto ($0\text{--}100\%$) asignado a cada decisión en la última generación y la justificación contextual.
   - Lista de Rasgos Biológicos y Tradiciones Culturales activos (con botón `+ Inyectar Rasgo del Catálogo` para experimentación directa según `US3`).

---

## 2. Contrato de Estado (`SimulationStore`)

```typescript
export type PlaybackMode = "paused" | "stepping" | "playing_normal" | "playing_fast" | "milestone_paused" | "error_paused";

export type BrushTool =
  | { kind: "inspect" }
  | { kind: "set_biome"; biome: BiomeType; radius: 1 | 2; cost: number }
  | { kind: "adjust_altitude"; delta: number; radius: 1 | 2; cost: number }
  | { kind: "adjust_carrying_capacity"; deltaFactor: number; radius: 1 | 2; cost: number }
  | { kind: "adjust_sea_level"; delta: number; cost: number };

export interface SimulationStore {
  locale: SupportedLocale; // Default: "en"
  world: WorldState;
  playbackMode: PlaybackMode;
  selectedHexId: string | null;
  selectedDemeId: string | null;
  activeBrush: BrushTool;
  activeModal: "none" | "catalog_lab" | "phylo_tree" | "naturalist_notebook" | "ollama_diagnostics";
  highlightedLineageId: string | null;
  latestMilestoneChronicle: ChronicleEntry | null;
  ollamaStatus: OllamaStatusReport | null;
  lastError: string | null;

  // Actions
  setLocale: (locale: SupportedLocale) => void;
  loadPreset: (presetId: string) => void;
  stepGeneration: () => Promise<void>;
  setPlaybackMode: (mode: PlaybackMode) => void;
  toggleAutoPauseOnMilestone: () => void;
   toggleUnlimitedPressure: () => void;
  selectHex: (hexId: string) => void;
  selectDeme: (demeId: string) => void;
  setActiveBrush: (brush: BrushTool) => void;
  applyBrushToHex: (hexId: string) => void;
  upsertTrait: (trait: TraitDefinition) => void;
  upsertDecision: (decision: DecisionDefinition) => void;
  injectTraitIntoDeme: (demeId: string, traitId: string) => void;
  exportWorldJson: () => string;
  importWorldJson: (jsonPayload: string) => void;
  refreshOllamaStatus: () => Promise<void>;
}
```
