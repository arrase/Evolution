# Tasks: Mundo 3D de Bloques, Aldeas Vivas e Infraestructuras Visuales de Interacción

**Input**: Design documents from `/specs/005-3d-voxel-village-world/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [world-3d.contract.md](./contracts/world-3d.contract.md), [quickstart.md](./quickstart.md)

**Tests**: Automated unit tests included in `tests/unit/world3d.test.ts` and `tests/unit/i18n.test.ts` to verify 100% of the deterministic 3D projection, ecological tiers, 4 village tiers, footprint clearing, road/ramp/bridge classification rules, lifecycle transitions, and 8-locale dictionary parity (`SC-001` through `SC-004`).

**Organization**: Tasks are grouped by user story (`US1` through `US4`) to enable independent implementation and verification of each increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Exact repository-relative file paths included in every task description

---

## Phase 1: Setup (Shared 3D Styling & Reduced-Motion Animations)

**Purpose**: Add shared CSS rules for 3D caravan motion, lineage light beacons, and reduced-motion accessibility compliance.

- [X] T001 Add `.voxel-caravan-animated`, `.lineage-beacon-pulse`, and `@media (prefers-reduced-motion: reduce)` static override rules in `src/index.css`

---

## Phase 2: Foundational (3D Projection Core, Store Snapshot Memory, Palette & 8-Locale i18n Dictionaries)

**Purpose**: Core 3D mathematical types/projection primitives, 1-turn previous world snapshot tracking in store, shared 3D palette metadata, and 8-locale translation dictionaries required by all user stories.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 Create `src/engine/world3d.ts` with core 3D types (`Camera3DState` with `yawDeg` normalized in `[0, 360)` default `0`, `pitchDeg` clamped in `[25, 80]` default `48`, `zoom` clamped in `[0.85, 3.25]` default `1.0`, `panX` default `0`, `panY` default `0`; `Point3D`; `ProjectedPoint3D`; `VoxelBox3D`), `MAX_COLUMN_HEIGHT_PX = Math.floor(HEX_SIZE * 0.85)`, and pure projection helpers `clampCamera3D(camera: Partial<Camera3DState>): Camera3DState`, `projectPoint3D(point: Point3D, camera: Camera3DState, origin?: { x: number; y: number }): ProjectedPoint3D`, and `projectVoxelBoxFaces(box: VoxelBox3D, camera: Camera3DState, season: SeasonType, origin?: { x: number; y: number })`
- [X] T003 [P] Extend `useSimulationStore` in `src/store/useSimulationStore.ts` with `previousWorld: WorldState | null` (set to the pre-step `world` inside `stepGeneration` and reset to `null` on `loadPreset` and `importWorldJson`) to support 1-turn visual memory for disused routes, sibling merges, and extinction ruins
- [X] T004 [P] Add 3D block shading helpers (`shadeColorHex`), village tier metadata (`VILLAGE_TIER_VISUALS` for `"camp" | "hamlet" | "village" | "settlement"`), and 3D infrastructure visual styles (`INFRASTRUCTURE_3D_STYLES` for `"road" | "ramp" | "bridge" | "dispute_front" | "expedition" | "merge_integration"`) in `src/components/palette.ts`
- [X] T005 [P] Add localized keys for the 4 village tiers (`camp`, `hamlet`, `village`, `settlement`), 3D infrastructures (`road`, `ramp`, `bridge`, `disusedRoad`, `disputeFront`, `expedition`, `totem`, `ruins`), and 3D orbital camera controls (`rotateLeft`, `rotateRight`, `tiltView`, `zoomIn`, `zoomOut`, `resetView`) across all 8 locale files in `src/i18n/locales/en.json`, `src/i18n/locales/es.json`, `src/i18n/locales/zh.json`, `src/i18n/locales/fr.json`, `src/i18n/locales/de.json`, `src/i18n/locales/pt.json`, `src/i18n/locales/ja.json`, and `src/i18n/locales/ru.json`

**Checkpoint**: Foundation ready — 3D projection math, 1-turn store snapshot memory, 3D palette styles, and 8-locale i18n keys are in place.

---

## Phase 3: User Story 1 - Mundo 3D por Bloques con Estética Clásica y Biomas Volumétricos Vivos (Priority: P1) 🎯 MVP

**Goal**: Represent the world in 3D as stepped hexagonal block columns quantized into 10 discrete height tiers ($\le 0.85 \cdot R_{\text{hex}}$), a 3D sea plane at `seaLevel`, seasonal directional flat-shading (`wet_warm` vs. `dry_cold`), and volumetric 3D biome voxel props reflecting 3 resource abundance tiers ($R / K_{\max}$) and 3 habitat health states ($K / K_{\max}$) (`FR-001`, `FR-002`, `FR-003`, `SC-001`).

**Independent Test**: Load any scientific preset and verify that each territory renders as a 3D stepped block column with up to 10 strata layers, ocean and coastal shallows display a 3D translucent water plane at `seaLevel`, and all 7 biomes render 3D block props that change density across the 3 resource tiers and show felled stumps/cracked earth in degraded and collapsed health states.

### Tests for User Story 1

- [X] T006 [P] [US1] Add unit tests in `tests/unit/world3d.test.ts` for `projectPoint3D`, `classifyTerritoryEcology` (`altitudeTier` in `0..10`, `topZ <= 0.85 * HEX_SIZE`, `resourceTier` thresholds `>= 0.65` `"high"`, `0.30..0.64` `"medium"`, `< 0.30` `"low"`, and `healthState` thresholds `>= 0.85` `"healthy"`, `0.60..0.84` `"degraded"`, `< 0.60` `"collapsed"`), and back-to-front 3D depth sorting across orbital `yawDeg` angles (`0`, `90`, `180`, `270`)

### Implementation for User Story 1

- [X] T007 [US1] Implement `VoxelHexTerritory3D`, `classifyTerritoryEcology(cell: HexCell, seaLevel: number)`, and `buildTerritoryBiomeVoxels(territory: VoxelHexTerritory3D, occupiedCircles: Array<{ x: number; y: number; radius: number }>, roadSegments: Array<{ x1: number; y1: number; x2: number; y2: number; width: number }>)` for all 7 biomes (`"tropical_forest" | "savanna" | "arid_steppe" | "tundra" | "high_mountain" | "coastal_shallows" | "ocean"`) in `src/engine/world3d.ts`
- [X] T008 [US1] Render 3D stepped hexagonal block columns (with geological strata lines along visible side faces), translucent 3D sea-level water prisms (`waterZ = seaLevel * MAX_COLUMN_HEIGHT_PX`), seasonal directional flat-shading (`wet_warm` vs. `dry_cold`), lens surface tinting (`biome`, `food`, `health`), and depth-sorted 3D biome voxel props in `src/components/HexMapCanvas.tsx`

**Checkpoint**: User Story 1 (3D Stepped Voxel Terrain, Sea-Level Plane & Volumetric Biomes) is complete and independently testable.

---

## Phase 4: User Story 2 - La Aldea como Unidad Mínima Viva con Crecimiento Físico y Decisiones Colectivas (Priority: P1)

**Goal**: Materialize every active `Deme` as a 3D Village settlement (`VillageSettlement3D`) that scales across 4 population tiers (`camp` `10–49`, `hamlet` `50–149`, `village` `150–399`, `settlement` `400+`), clears biome vegetation under its footprint, compacts vertically when 2 or 3 villages cohabit a territory, reflects vital status (`thriving`, `stable`, `struggling`, `starving`) and lineage color, erects a central Cultural Totem when `culturalTraitIds.length > 0`, and renders local 3D activity structures for all 8 decision archetypes (`FR-004`, `FR-005`, `FR-006`, `SC-002`).

**Independent Test**: Observe villages across turns as population, vital status, cultural traits, and cohabitation change, verifying 4 distinct 3D architectural tiers, automatic vegetation clearing, non-overlapping 3-village sectors, cultural monoliths, and 1-turn extinction ruins on true extinctions vs. integration trails on sibling merges.

### Tests for User Story 2

- [X] T009 [P] [US2] Add unit tests in `tests/unit/world3d.test.ts` for `getVillageTier(population)` (`10..49` -> `"camp"`, `50..149` -> `"hamlet"`, `150..399` -> `"village"`, `>= 400` -> `"settlement"`), cohabitation sector placement (`1`, `2`, and `3` villages with non-overlapping `footprintRadius` and `+25%` vertical height on Tier 3/4 cohabitation), automatic biome prop footprint clearing, local activity voxel generation across all 8 `DecisionArchetype` values (`"forage" | "overexploit" | "migrate" | "cooperate" | "exchange" | "dispute" | "innovate" | "custom"`), and `ExtinctionRuins3D` vs. `"merge_integration"` detection

### Implementation for User Story 2

- [X] T010 [US2] Implement `VillageSettlement3D`, `ExtinctionRuins3D`, `getVillageTier(population: number)`, `computeVillageSectorLayout(cellCenter: { x: number; y: number }, topZ: number, residentDemes: Deme[])`, and `buildVillageSettlementVoxels` (including 4 architectural tiers, vital status plinth/smoke, cultural monolith scaling with `culturalTraitIds.length`, and local activity structures for all 8 `DecisionArchetype` values) in `src/engine/world3d.ts`
- [X] T011 [US2] Render 3D Village settlements (`VillageSettlement3D`), hearth smoke/vital plinths, cultural monoliths, local decision activity blocks, and 1-turn collapsed `ExtinctionRuins3D` on territory plateaus in `src/components/HexMapCanvas.tsx`

**Checkpoint**: User Story 2 (3D Living Villages, 4 Architectural Tiers, Cohabitation Compaction & Local Activity Structures) is complete and independently testable.

---

## Phase 5: User Story 3 - Infraestructuras y Acciones Visuales 3D: Caminos, Puentes, Fortificaciones y Actividad Local (Priority: P1)

**Goal**: Materialize inter-village relationships as deterministic 3D structures (`InterVillageStructure3D`): **Flat Block Roads** ($|\Delta \text{altitude}| < 0.10$), **Stepped Block Ramps** ($0.10 \le |\Delta \text{altitude}| < 0.25$), and **3D Pillar Bridges** (over `coastal_shallows`/inundation-level terrain or $|\Delta \text{altitude}| \ge 0.25$) for both `exchange` and active `cooperate` connections (with moving caravans and 1-turn `"disused"` memory), **Fortified Dispute Fronts** (`dispute_front` with strict precedence over commercial paths), **Migration Expedition Routes** (`expedition`), and **Sibling Merge Integration Paths** (`merge_integration`) (`FR-007`, `FR-008`, `SC-003`).

**Independent Test**: Run turns with intra-hex and inter-hex trade, cooperation, territorial disputes, migratory fission, and sibling merges, verifying that the exact 3D road, stepped ramp, pillar bridge, fortified dispute front, or expedition trail is constructed between the participating villages and that commercial paths persist for 1 turn as `"disused"` when trade ceases.

### Tests for User Story 3

- [X] T012 [P] [US3] Add unit tests in `tests/unit/world3d.test.ts` for `classifyConnectionKind(cellA, cellB, seaLevel)` (`"road"` when `|Δaltitude| < 0.10`, `"ramp"` when `0.10 <= |Δaltitude| < 0.25` terrestrial, `"bridge"` when `coastal_shallows`, `altitude <= seaLevel + 0.04`, or `|Δaltitude| >= 0.25`), active cooperation road/bridge generation (`cooperate >= 0.25`), strict `dispute_front` precedence over `road`/`ramp`/`bridge`, and 1-turn `"disused"` decay when comparing `previousWorld` and `world`

### Implementation for User Story 3

- [X] T013 [US3] Implement `InterVillageStructure3D`, `classifyConnectionKind(cellA: HexCell, cellB: HexCell, seaLevel: number)`, and `buildInterVillageStructures3D(world: WorldState, previousWorld: WorldState | null, villagesByDemeId: Record<string, VillageSettlement3D>, territoriesByHexId: Record<string, VoxelHexTerritory3D>)` in `src/engine/world3d.ts`, and export unified `buildWorld3DScene`
- [X] T014 [US3] Render 3D `InterVillageStructure3D` blocks (`road` slabs, `ramp` steps, `bridge` decks and vertical support pillars, `dispute_front` palisades/barricades/clash sparks, `expedition` stepping stones and settler caravans, `merge_integration` trails, and weathered `"disused"` routes) in `src/components/HexMapCanvas.tsx`

**Checkpoint**: User Story 3 (Deterministic 3D Roads, Stepped Ramps, Pillar Bridges, Dispute Fronts & Expedition Trails) is complete and independently testable.

---

## Phase 6: User Story 4 - Cámara Orbital 3D Accesible, Integración con Paneles e Intervención Directa (Priority: P2)

**Goal**: Provide $360^\circ$ orbital camera rotation (`yawDeg`), adjustable tilt (`pitchDeg` $\in [25^\circ, 80^\circ]$), zoom ($\ge 3\times$), and pan operable via HUD buttons, keyboard shortcuts (`WASD`, `Q/E`, `R/F`, `+/-`, `0`), and pointer gestures without conflicting with Selective Pressure brush dragging; render clickable occlusion-safe village billboards, 3D lineage light beacons (`highlightedLineageId`), and synchronize `MapLegend` and `ContextPanel` (`FR-009`, `FR-010`, `SC-004`).

**Independent Test**: Orbit the camera $360^\circ$, tilt between $25^\circ$ and $80^\circ$, click an occluded village's floating billboard behind a high mountain to select it, verify camera focus and tier display in `ContextPanel`, filter a lineage to see 3D light beacons, and drag a Selective Pressure brush across 3D columns without moving the camera.

### Implementation for User Story 4

- [X] T015 [US4] Implement orbital `Camera3DState` controls (on-screen HUD cluster for `Rotate Left`, `Rotate Right`, `Tilt View`, `Zoom In`, `Zoom Out`, `Reset View`; keyboard shortcuts `WASD`/Arrows, `Q/E`, `R/F`, `+/-`, `0`; `Shift`/`Alt`/secondary-drag orbit and `inspect`-mode drag pan; strict brush-drag isolation when `activeBrush.kind !== "inspect"`), 3D volumetric brush preview rings, 3D `highlightedLineageId` beacons, current-turn chronicle `eventHexIds` golden 3D rings, and occlusion-safe clickable village billboards (`role="button"`, `tabIndex={0}`) in `src/components/HexMapCanvas.tsx`
- [X] T016 [P] [US4] Update `src/components/ContextPanel.tsx` to display the localized Village Tier badge (`I – Camp`, `II – Hamlet`, `III – Consolidated Village`, `IV – Complex Settlement`) in the population list and selected village header
- [X] T017 [P] [US4] Update `src/components/MapLegend.tsx` to display the 4 Village Scale Tiers (`camp`, `hamlet`, `village`, `settlement`) and the 3D Infrastructure legend items (`road`, `ramp`, `bridge`, `dispute_front`, `expedition`, `totem`)

**Checkpoint**: User Story 4 (Accessible Orbital 3D Camera, Occlusion-Safe Billboards, 3D Brush Preview & Synchronized UI Panels) is complete and independently testable.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verify 8-locale dictionary parity for all new 3D village/infrastructure/camera keys, run full test suite and performance benchmarks (`< 100 ms` scene build), and verify production bundle build.

- [X] T018 [P] Extend `tests/unit/i18n.test.ts` to assert that all new village tier, 3D infrastructure, and 3D camera translation keys exist and are non-empty across all 8 supported locales (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`), and add a `< 100 ms` scene build performance assertion in `tests/unit/world3d.test.ts` (`SC-004`)
- [X] T019 Run `npm run typecheck`, `npm test`, and `npm run build` to verify zero TypeScript errors, 100% passing unit/contract/integration tests, and clean production build per `specs/005-3d-voxel-village-world/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories until `world3d.ts` projection primitives, `previousWorld` store state, `palette.ts` 3D styles, and 8-locale `i18n` dictionaries are ready.
- **Phase 3 (US1 - 3D Voxel Terrain & Biomes)**: Depends on Phase 2 (`T002`–`T005`).
- **Phase 4 (US2 - 3D Villages & 4 Architectural Tiers)**: Depends on Phase 3 (`VoxelHexTerritory3D` top plateau height `topZ` and footprint clearing in `T007`).
- **Phase 5 (US3 - 3D Roads, Ramps, Bridges & Dispute Fronts)**: Depends on Phase 4 (`VillageSettlement3D` sector coordinates in `T010`).
- **Phase 6 (US4 - Orbital 3D Camera, Billboards & Panels)**: Depends on Phases 3–5 (`buildWorld3DScene` in `T013` and `HexMapCanvas.tsx` in `T014`); `T016` (`ContextPanel.tsx`) and `T017` (`MapLegend.tsx`) only depend on Phase 2 (`T004`, `T005`).
- **Phase 7 (Polish & Verification)**: Depends on Phases 1–6 completion.

### Parallel Opportunities

- In **Phase 2**: `T003` (`src/store/useSimulationStore.ts`), `T004` (`src/components/palette.ts`), and `T005` (`src/i18n/locales/*.json`) touch separate files and can run in parallel.
- Across **User Stories**: `T016` (`src/components/ContextPanel.tsx`) and `T017` (`src/components/MapLegend.tsx`) can be implemented in parallel with `T007`–`T015`.
- Test tasks `T006`, `T009`, `T012`, and `T018` validate distinct contracts in `tests/unit/world3d.test.ts` and `tests/unit/i18n.test.ts`.

---

## Parallel Example: Foundational & UI Panels

```bash
# Run Foundational tasks on separate files in parallel:
Task: "T003 [P] Extend useSimulationStore in src/store/useSimulationStore.ts with previousWorld snapshot"
Task: "T004 [P] Add 3D block shading helpers and village/infrastructure styles in src/components/palette.ts"
Task: "T005 [P] Add localized village tier, 3D infrastructure, and camera keys across all 8 locale files in src/i18n/locales/*.json"

# Run Panel & Legend updates in parallel with 3D Canvas work:
Task: "T016 [P] [US4] Update src/components/ContextPanel.tsx to display the localized Village Tier badge"
Task: "T017 [P] [US4] Update src/components/MapLegend.tsx to display the 4 Village Scale Tiers and 3D Infrastructure legend items"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational).
2. Complete Phase 3 (User Story 1: 3D Stepped Voxel Terrain, Sea-Level Water Plane & Volumetric Biomes).
3. **STOP and VALIDATE**: Verify 10-tier 3D block columns, 7 volumetric biomes, and resource/health ecological states in `tests/unit/world3d.test.ts` and the browser.

### Incremental Delivery

1. **Increment 1 (US1)**: 3D Stepped Voxel Terrain, Sea-Level Plane & Volumetric Biomes (`T001`–`T008`).
2. **Increment 2 (US2)**: 3D Living Villages with 4 Architectural Tiers, Cohabitation Compaction, Cultural Monoliths & 8 Local Decision Structures (`T009`–`T011`).
3. **Increment 3 (US3)**: Deterministic 3D Roads, Stepped Ramps, Pillar Bridges, Dispute Fronts, Expedition Trails & 1-Turn Lifecycle Memory (`T012`–`T014`).
4. **Increment 4 (US4 + Polish)**: Accessible $360^\circ$ Orbital Camera, Occlusion-Safe Billboards, 3D Brushes, Legend/ContextPanel Parity & Full Suite Validation (`T015`–`T019`).
