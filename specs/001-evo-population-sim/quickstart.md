# Quickstart & Validation Guide: Evolution Population Simulator

**Feature**: `001-evo-population-sim`
**Spec**: [spec.md](./spec.md)
**Data Model**: [data-model.md](./data-model.md)
**Contracts**: [cognitive-engine.contract.md](./contracts/cognitive-engine.contract.md) | [simulation-engine.contract.md](./contracts/simulation-engine.contract.md) | [ui-store.contract.md](./contracts/ui-store.contract.md)

## 1. Prerequisites

1. **Node.js & npm**: Node.js `>= 22.x` and `npm >= 10.x`.
2. **Local Ollama Service**: Ollama (`>= 0.40.11`, verified on `0.40.14`) running locally on `http://127.0.0.1:11434` with CORS enabled for local web origin (`OLLAMA_ORIGINS="*"`).
3. **Required Local Models**:
   ```bash
   ollama pull d3:4b
   ollama pull gemma4:e4b-it-qat
   ollama list
   ```

---

## 2. Project Setup & Execution Commands

```bash
# 1. Install dependencies from package.json
npm install

# 2. Run deterministic unit, contract, and preset simulation tests (Vitest)
npm test

# 3. Type-check strict TypeScript compilation
npm run typecheck

# 4. Launch the interactive web simulator
npm run dev
```

---

## 3. End-to-End Validation Scenarios

### Scenario 1: Deterministic Biophysical Engine & Scientific Presets (`US1`, `SC-001`, `SC-002`)
1. Run `npm test` to execute the automated test suite against [simulation-engine.contract.md](./contracts/simulation-engine.contract.md).
2. Confirm that:
   - **"El Rift y la Sabana"** (`preset-rift-savanna`) over 30 generations increases *Cooperación* + *Migración* probabilities above 50% in eastern savanna demes and triggers at least 1 Baldwin or Innovation milestone while western forest demes maintain *Forrajeo Conservador*.
   - **"Archipiélago de Darwin"** (`preset-darwin-archipelago`) colonizes islands across shallow land bridges during low sea-level phases (`seaLevel = 0.12`), isolates demes when sea level rises (`seaLevel = 0.25`), and records at least 1 allopatric speciation node in `lineageTree`.
   - **"La Isla Finita"** (`preset-finite-island`) degrades central hexagon carrying capacity $K$ below $60\%$ of $K_{\max}$ within 30 generations under unmitigated *Sobreexplotación Intensiva*.
   - Single-turn biophysical resolution completes in `< 100 ms`.

### Scenario 2: Live Cognitive Inspector, Selective Pressure Brush & Multi-Language i18n (`US1`, `US2`, `SC-003`, `SC-006`)
1. Start the web app (`npm run dev`) and open the URL printed by Vite in the browser.
2. Confirm that the UI, biomes, presets, and base catalog render in **English (`en`) by default**, and test switching across the 8 world languages (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`) via the language selector in the top bar without losing simulation state.
3. Click any occupied hexagon on the central map.
4. Confirm in the right-hand **Cognitive Inspector Panel** ([ui-store.contract.md](./contracts/ui-store.contract.md)) that the selected deme displays normalized decision probabilities summing to `100.0%`, its active biological/cultural traits, energy balance ($\Delta E$), and localized contextual justification.
5. Select the **Raise Mountain / Aridify** brush in the bottom toolbar, paint across adjacent hexagons, click `Step +1 Gen`, and confirm that `d3:4b` recalculates the deme's probability bars in `< 3 s`.

### Scenario 3: Open Catalog Editor, AI Co-Design & Thermodynamic Validation (`US3`, `SC-004`, `SC-005`)
1. Open the **Catalog Laboratory** modal from the top bar.
2. Enter a natural-language prompt (e.g., *"Trashumancia estacional de alta montaña"*) and click `Autocompletar con IA`.
3. Verify that `gemma4:e4b-it-qat` returns a structured proposal ([cognitive-engine.contract.md](./contracts/cognitive-engine.contract.md)) whose 6-axis `BiophysicalVector` satisfies the thermodynamic inequality in [data-model.md](./data-model.md#21-biophysicalvector-vector-biofísico-de-6-ejes--fr-007-sc-005).
4. Save the trait, inject it into a selected deme (or let it emerge naturally), step 1 generation, and verify its immediate effect in the Cognitive Inspector.

### Scenario 4: Open-Ended Evolutionary Milestones & Naturalist Notebook (`US4`, `FR-013`)
1. Enable `Auto-Pausa en Hitos` in the top control bar and run `Auto-Play Rápido`.
2. When a deme crosses the Baldwin threshold (`baldwinCounters[id] >= 8`), innovation threshold (`innovationCounter >= 1.0`), or allopatric speciation threshold (`isolationTurns >= 10`), verify that playback pauses automatically, `gemma4:e4b-it-qat` synthesizes a new emergent trait/tradition, a new entry appears in the **Naturalist Notebook**, and the **Phylo-Cultural Tree** (`d3-hierarchy`) renders the updated lineage node.
