# Implementation Plan: Mundo 3D de Bloques, Aldeas Vivas e Infraestructuras Visuales de Interacción

**Branch**: `005-3d-voxel-village-world` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/005-3d-voxel-village-world/spec.md`

## Summary

Transform the simulation viewport from a flat/2.5D board into a tactile **3D Voxel/Block World** with a classic late-90s/early-2000s strategy & *Minecraft* diorama aesthetic, where **Villages (`VillageSettlement3D`)** act as the living collective unit of simulation and inter-village interactions materialize as 3D physical structures:
- **3D Stepped Voxel Terrain & Volumetric Biomes (US1):** Implement a pure, deterministic 3D orbital projection and voxel-block scene builder (`src/engine/world3d.ts`) that extrudes each hexagonal cell into up to **10 discrete block tiers** proportional to `altitude` (bounded to $\le 0.85 \cdot \text{HEX\_SIZE}$), renders a translucent 3D sea plane at `seaLevel`, applies seasonal directional flat-shading (`wet_warm` vs. `dry_cold`), and populates 3D biome voxel props modulated by 3 resource abundance tiers ($R / K_{\max}$) and 3 ecological health states ($K / K_{\max}$).
- **3D Living Villages with 4 Architectural Tiers & Lifecycle Transitions (US2):** Materialize every active `Deme` as a 3D Village settlement that scales organically across **4 architectural tiers** (**I – Camp** `10–49`, **II – Hamlet** `50–149`, **III – Consolidated Village** `150–399`, **IV – Complex Settlement** `400+`), clears biome vegetation under village footprints and roads, compacts vertically when up to 3 villages cohabit a territory, displays lineage colors, vital status plinths/hearth smoke, central cultural monoliths, local activity structures for all 8 decision archetypes (including `custom`), and distinguishes sibling merges (`merge_integration`) from true extinctions (`ExtinctionRuins3D`).
- **Deterministic 3D Roads, Stepped Ramps, Pillar Bridges, Fortifications & Expeditions (US3):** Connect trading (`exchange`) and actively collaborating (`cooperate`) villages via **Flat Block Roads** ($|\Delta \text{altitude}| < 0.10$), **Stepped Block Ramps** ($0.10 \le |\Delta \text{altitude}| < 0.25$), or **3D Pillar Bridges** (over `coastal_shallows`/inundation-level terrain or steep $|\Delta \text{altitude}| \ge 0.25$) with moving caravans and 1-turn disused decay; render **Fortified Dispute Fronts** (with strict precedence over commercial paths) and **3D Migration Expedition Routes**.
- **Accessible 3D Orbital Camera, Occlusion-Safe Billboards & UI Integration (US4):** Provide $360^\circ$ orbital rotation (`yawDeg`), adjustable tilt (`pitchDeg` $\in [25^\circ, 80^\circ]$), zoom ($\ge 3\times$), and pan via an on-screen HUD camera cluster, keyboard shortcuts (`WASD`, `Q/E`, `R/F`), and pointer gestures without conflicting with Selective Pressure brush dragging; render clickable occlusion-safe floating village billboards, 3D lineage light beacons (`highlightedLineageId`), updated `MapLegend` and `ContextPanel` village tier badges, and full 8-locale `i18n` parity.

## Technical Context

**Language/Version**: TypeScript `7.0.2` (strict mode, ESM `"type": "module"`)  
**Primary Dependencies**:
- Build, UI & State: `vite@8.3.5`, `@vitejs/plugin-react@6.2.1`, `react@19.3.1`, `react-dom@19.3.1`, `zustand@5.0.16`, `i18next@26.7.1`, `react-i18next@17.1.12`, `tailwindcss@4.3.4`, `@tailwindcss/vite@4.3.4`, `lucide-react@1.67.0`
- Spatial Hex Geometry & Schema Validation: `honeycomb-grid@4.1.5`, `zod@4.6.7`
- Cognitive Orchestration: `ollama@0.6.4`, `@langchain/ollama@1.3.0`, `@langchain/core@1.3.4`

**Storage**: Client-side `localStorage` and portable JSON export/import validated with `zod@4.6.7` (100% backward-compatible `WorldStateSchema`).  
**Testing**: `vitest@5.1.0` for deterministic unit tests (`world3d.test.ts`, `hexGrid.test.ts`, `biophysicalPhase.test.ts`, `i18n.test.ts`), contract tests (`cognitiveSchemas.test.ts`), and integration tests (`scientificPresets.test.ts`).  
**Target Platform**: Modern Desktop Web Browser.  
**Project Type**: Interactive Web Simulation Application (Single-Project SPA with decoupled pure simulation and 3D scene engine).  
**Performance Goals**:
- `< 100 ms` 3D scene construction, depth sorting, and Selective Pressure brush updates across 61–169 hexagonal territories and up to 15 active villages (`SC-004`).

**Constraints**:
- Strict adherence to KISS & YAGNI (Constitution Principle I): pure top-to-bottom 3D projection and voxel builder functions in `src/engine/world3d.ts`, zero external 3D engine bloat, top-of-file imports only, full `prefers-reduced-motion` compliance, and 100% deterministic unit testability.

**Scale/Scope**:
- 10 discrete block altitude tiers ($\le 0.85 \cdot R_{\text{hex}}$), 7 volumetric 3D biomes, 3 resource abundance tiers, 3 habitat health states, 4 architectural village tiers, 8 local decision archetype structures, 6 inter-village structure/transition types (`road`, `ramp`, `bridge`, `dispute_front`, `expedition`, `merge_integration` + `ExtinctionRuins3D`), $360^\circ$ orbital camera with $[25^\circ, 80^\circ]$ pitch, and 8-locale `i18n` parity (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked and verified after Phase 1 design.*

| Constitution Principle | Pre-Research Check | Post-Design Check | Verification Evidence |
| :--- | :---: | :---: | :--- |
| **I. Radical Simplicity & Zero Defensive Bloat (KISS & YAGNI)** | PASS | PASS | Pure, linear 3D projection and voxel scene builder in `src/engine/world3d.ts` with zero external 3D framework dependencies, top-of-file imports, and no speculative abstractions. |
| **II. Scientific Rigor & Bio-Cultural Fidelity** | PASS | PASS | Biophysical laws, thermodynamic conservation, and demographic rules remain pure and untouched; 3D structures deterministically reflect $R/K_{\max}$, $K/K_{\max}$, Hawk-Dove disputes, symbiosis, cooperation, and migratory fission. |
| **III. Dual-Frequency Multi-Model Cognitive Architecture (`d3:4b` + `tev1:4b` & `gemma4:e2b`)** | PASS | PASS | Fully preserved; each 3D Village (`Deme`) continues to be evaluated by `d3:4b` or `tev1:4b` in System 1 and milestones synthesized by `gemma4:e2b` in System 2. |
| **IV. Curated Modern TypeScript Ecosystem** | PASS | PASS | Leverages existing `honeycomb-grid@4.1.5`, `zod@4.6.7`, `zustand@5.0.16`, `i18next@26.7.1`, and declarative React 19 rendering without adding redundant dependencies. |
| **V. Transparent & Interactive Sandbox UX** | PASS | PASS | Upgrades the map into an orbital 3D Voxel World with 3D Villages, Roads, Ramps, Bridges, Fortifications, occlusion-safe billboards, updated Legend and Context Panel, and 8-locale `i18n` support (`en` default). |

## Project Structure

### Documentation (this feature)

```text
specs/005-3d-voxel-village-world/
├── plan.md                                  # Implementation plan (/speckit-plan)
├── research.md                              # Phase 0 architectural & 3D voxel research
├── data-model.md                            # Phase 1 3D camera, territory, village & infrastructure models
├── quickstart.md                            # Phase 1 validation & test guide
├── checklists/
│   └── requirements.md                      # Spec quality checklist (/speckit-specify)
├── contracts/
│   └── world-3d.contract.md                 # 3D voxel scene builder & interactive viewport contracts
└── tasks.md                                 # Phase 2 actionable tasks (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── engine/
│   ├── hexGrid.ts                           # Existing hex grid topology & neighbor math
│   └── world3d.ts                           # Pure 3D orbital projection, 10-tier hex columns, 4-tier villages, roads/ramps/bridges & lifecycle transitions
├── store/
│   └── useSimulationStore.ts                # Track previousWorld snapshot on turn step/preset load for 1-turn disused routes, merges & extinction ruins
├── components/
│   ├── palette.ts                           # Add 3D block shading helpers, village tier metadata & 3D infrastructure visual styles
│   ├── HexMapCanvas.tsx                     # 3D Voxel World renderer, orbital camera (yaw/pitch/zoom/pan), 3D brushes & occlusion-safe village billboards
│   ├── ContextPanel.tsx                     # Display localized Village Tier (I–IV) badge and focus camera on selected village
│   └── MapLegend.tsx                        # Display 4 Village Tiers & 3D Infrastructure legend (Road, Ramp, Bridge, Dispute Front, Expedition, Totem)
├── i18n/
│   └── locales/                             # Add village tiers, 3D infrastructures & orbital camera keys across all 8 locales (en, es, zh, fr, de, pt, ja, ru)
└── index.css                                # Add 3D caravan/particle/beacon styles respecting prefers-reduced-motion

tests/
├── unit/
│   ├── world3d.test.ts                      # Unit tests for 3D projection, 10-tier altitude, 4 village tiers, footprint clearing, road/ramp/bridge rules & lifecycle memory
│   ├── hexGrid.test.ts                      # Existing hex geometry tests
│   ├── biophysicalPhase.test.ts             # Existing biophysical & flow tests
│   └── i18n.test.ts                         # Verify 100% locale key parity across all 8 languages including new 3D village & infrastructure keys
```

**Structure Decision**: Add a single focused pure-engine module `src/engine/world3d.ts` (and its unit test suite `tests/unit/world3d.test.ts`) for all 3D mathematical projection, voxel geometry generation, and deterministic infrastructure classification, while updating `HexMapCanvas.tsx`, `MapLegend.tsx`, `ContextPanel.tsx`, `palette.ts`, `useSimulationStore.ts`, and the 8 locale files in place.

## Complexity Tracking

No Constitution violations exist. All 5 Core Principles pass without exception.
