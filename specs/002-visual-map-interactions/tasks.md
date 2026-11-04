# Tasks: Visualización 2.5D del Terreno e Interacciones Expresivas de los Habitantes

**Input**: Design documents from `/specs/002-visual-map-interactions/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [visual-map.contract.md](./contracts/visual-map.contract.md)

**Tests**: Automated unit tests included for 2.5D hex geometry, biophysical `targetDemeId` emission, and 8-locale `i18n` parity (`SC-004`).

**Organization**: Tasks are grouped by user story (`US1` through `US4`) to enable independent implementation and verification.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Exact repository-relative file paths included in every task description

---

## Phase 1: Setup (Shared Styling & Animations)

**Purpose**: Add shared CSS animation rules for interaction arcs with full reduced-motion accessibility support.

- [X] T001 Add `.flow-arc-animated` dash-offset animation and `@media (prefers-reduced-motion: no-preference)` rules in `src/index.css`

---

## Phase 2: Foundational (Data Schema, Shared Visual Palette & i18n Dictionaries)

**Purpose**: Core schema extensions, shared status/palette helpers, and 8-locale translation keys required across all user stories.

- [X] T002 Extend `HexEdgeFlowSchema` in `src/types/simulation.ts` with `targetDemeId: z.string().min(1).optional()` while keeping `fromHexId` (`/^-?\d+,-?\d+$/`), `toHexId` (`/^-?\d+,-?\d+$/`), `demeId` (`min(1)`), `color` (`/^#[0-9A-Fa-f]{6}$/`), `type` (`HexEdgeFlowTypeSchema`), and `intensity` (`min(0.05).max(1.0)`)
- [X] T003 [P] Add `DemeVitalStatus` (`"thriving" | "stable" | "struggling" | "starving"`), `getDemeStatus(deme: Deme)` (`lastEnergyDelta >= 10` -> `"thriving"`, `>= 0` -> `"stable"`, `energyReserves > 40` -> `"struggling"`, else `"starving"`), `DEME_STATUS_RINGS`, `BIOME_RELIEF_COLORS`, and `DECISION_ARCHETYPE_VISUALS` (all 8 `DecisionArchetype` values) in `src/components/palette.ts`
- [X] T004 [P] Add localized map camera, archetype, vital status, and interaction keys across all 8 locale files in `src/i18n/locales/en.json`, `src/i18n/locales/es.json`, `src/i18n/locales/zh.json`, `src/i18n/locales/fr.json`, `src/i18n/locales/de.json`, `src/i18n/locales/pt.json`, `src/i18n/locales/ja.json`, and `src/i18n/locales/ru.json`

**Checkpoint**: Foundational schema, shared visual palette, and 8-locale i18n dictionaries ready.

---

## Phase 3: User Story 1 - Terreno Hexagonal 2.5D con Biomas Ilustrados e Indicadores Ecológicos Integrados (Priority: P1) 🎯 MVP

**Goal**: Render the hexagonal terrain in 2.5D with altitude-proportional side skirts in back-to-front painter's order, biome-specific SVG vector illustrations for all 7 biomes, and integrated resource abundance and habitat degradation overlays (`carryingCapacity < 0.85 * carryingCapacityMax`) directly on terrestrial cells (`FR-001`, `FR-002`, `FR-003`, `SC-001`).

**Independent Test**: Load any preset in the `biome` lens and verify that terrestrial hexes exhibit 2.5D elevation skirts proportional to `altitude`, each of the 7 biomes renders its distinct topographic motif, and terrestrial cells display resource bars and degradation contours when overexploited.

### Tests for User Story 1

- [X] T005 [P] [US1] Add unit tests for `computeHex25DGeometry` (`elevationPx` in `[0, 10]`, `topPolygonPoints`, `leftSkirtPoints`, `rightSkirtPoints`) and painter's order sorting in `tests/unit/hexGrid.test.ts`

### Implementation for User Story 1

- [X] T006 [US1] Implement `computeHex25DGeometry(q: number, r: number, altitude: number, isOcean: boolean)` and `sortCellsFor25DPainterOrder(cells: HexCell[])` in `src/engine/hexGrid.ts`
- [X] T007 [US1] Render 2.5D extruded hex skirts, biome radial gradients, 7 biome SVG motifs (`tropical_forest`, `savanna`, `arid_steppe`, `tundra`, `high_mountain`, `coastal_shallows`, `ocean`), coastal shoreline contours, integrated resource level meter (`currentResources / carryingCapacityMax`), and habitat degradation warning contour (`carryingCapacity < 0.85 * carryingCapacityMax`) in `src/components/HexMapCanvas.tsx`

**Checkpoint**: User Story 1 (2.5D Terrain, Biome Illustrations & Ecological Overlays) is complete and independently verifiable.

---

## Phase 4: User Story 2 - Fichas Expresivas de Habitantes (*Demes*) con Acción Dominante, Estado Vital y Cultura (Priority: P1)

**Goal**: Render each `Deme` token on the 2.5D top face of its hex with an outer vital status ring (`thriving`, `stable`, `struggling`, `starving`), a top-right dominant decision archetype icon badge across all 8 archetypes (`forage`, `overexploit`, `migrate`, `cooperate`, `exchange`, `dispute`, `innovate`, `custom`), and a top-left cultural tradition badge when `culturalTraitIds.length > 0` (`FR-004`, `FR-005`, `SC-002`).

**Independent Test**: Step 1 generation and verify every `Deme` token displays its vital status ring matching `ContextPanel`, its dominant decision archetype icon badge, and its cultural badge when cultural traits are present.

### Implementation for User Story 2

- [X] T008 [P] [US2] Refactor `src/components/ContextPanel.tsx` to import and use the shared `getDemeStatus` and `DemeVitalStatus` from `src/components/palette.ts`
- [X] T009 [US2] Upgrade `renderCellDemes` in `src/components/HexMapCanvas.tsx` with elevated 2.5D positioning, expanded 3-deme spacing (`DEME_OFFSETS`), vital status ring (`DEME_STATUS_RINGS`), top-right dominant decision archetype vector badge (`DECISION_ARCHETYPE_VISUALS`), and top-left cultural tradition badge (`culturalTraitIds.length > 0`)
- [X] T010 [P] [US2] Update `src/components/MapLegend.tsx` to display vital status ring indicators and dominant decision archetype legend items using the localized keys

**Checkpoint**: User Story 2 (Expressive Deme Tokens & Synchronized Legend/Panel Status) is complete and independently verifiable.

---

## Phase 5: User Story 3 - Arcos Animados de Interacción Directa Deme-a-Deme (Priority: P1)

**Goal**: Populate `targetDemeId` on all `HexEdgeFlow` records during biophysical resolution and render curved, animated quadratic Bézier arcs directly connecting participating `Deme` tokens (both intra-hex and inter-hex) with midpoint interaction badges and enriched hover cards (`FR-006`, `FR-007`, `SC-003`).

**Independent Test**: Execute turns with intra-hex disputes/exchanges and inter-hex exchanges/migrations and verify that curved animated arcs directly link the participating `Deme` tokens with midpoint badges instead of cell-wide dashed circles.

### Tests for User Story 3

- [X] T011 [P] [US3] Add unit tests in `tests/unit/biophysicalPhase.test.ts` verifying that `resolveBiophysicalAndDemographicPhase` populates `targetDemeId` on Hawk-Hawk dispute, Hawk-Dove dispute, intra-hex exchange, inter-hex exchange, and migratory fission flows

### Implementation for User Story 3

- [X] T012 [US3] Update `resolveBiophysicalAndDemographicPhase` in `src/engine/biophysicalPhase.ts` to populate `targetDemeId` on all emitted `dispute`, `exchange`, and `migration` flows
- [X] T013 [US3] Replace `renderFlowVector` and update `renderHoverCard` in `src/components/HexMapCanvas.tsx` to compute exact `DemeTokenPosition` coordinates, draw curved animated quadratic Bézier arcs (`<path>`) with midpoint interaction badges between source and target demes (with legacy fallback when `targetDemeId` is omitted), and list resident dominant actions and active cell interactions in the hover card

**Checkpoint**: User Story 3 (Direct Animated Deme-to-Deme Interaction Arcs & Enriched Hover Card) is complete and independently verifiable.

---

## Phase 6: User Story 4 - Navegación Interactiva con Zoom y Paneo en el Mapa (Priority: P2)

**Goal**: Enable smooth interactive camera zoom ($1.0\times\text{--}2.75\times$) and pan across the SVG map via on-screen controls (`Zoom In`, `Zoom Out`, `Reset View`), mouse wheel, and pointer drag in `inspect` mode without interfering with hex/deme selection or selective pressure brush painting (`FR-008`, `SC-004`).

**Independent Test**: Use `+`, `-`, `Reset View`, mouse wheel, and drag in `inspect` mode to zoom ($> 2.5\times$) and pan over populated hexes, and verify brush painting remains unaffected when a selective pressure brush is active.

### Implementation for User Story 4

- [X] T014 [US4] Implement camera state (`zoom` clamped in `[1.0, 2.75]` and `pan: { x, y }`), dynamic `viewBox` transformation, wheel zoom handler, pointer-drag pan in `inspect` mode, and bottom-right camera control bar (`Zoom In`, `Zoom Out`, `Reset View`) in `src/components/HexMapCanvas.tsx`

**Checkpoint**: User Story 4 (Interactive Pan & Zoom Camera Controls) is complete and independently verifiable.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Full test suite verification, 8-locale i18n parity check, and production build validation.

- [X] T015 Run `npm run typecheck`, `npm test` (including `tests/unit/i18n.test.ts`, `tests/unit/hexGrid.test.ts`, `tests/unit/biophysicalPhase.test.ts`), and `npm run build` to verify zero TypeScript errors and 100% test pass rate

---

## Phase 8: Convergence

- [X] T016 Render coastal shoreline contour on terrestrial cells bordering `ocean` neighbors in `src/components/HexMapCanvas.tsx` per FR-002 (partial)
- [X] T017 Add unit test for inter-hex `exchange` flow `targetDemeId` emission in `tests/unit/biophysicalPhase.test.ts` per FR-006 (partial)
- [X] T018 Display the cultural tradition badge (`map.cultureBadge`) indicator in `src/components/MapLegend.tsx` per FR-005 and FR-007 (partial)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 — prepares `HexEdgeFlowSchema`, `palette.ts`, and 8-locale `i18n` dictionaries.
- **Phase 3 (US1 - 2.5D Terrain)**: Depends on Phase 2 (`palette.ts`).
- **Phase 4 (US2 - Expressive Deme Tokens)**: Depends on Phase 2 (`palette.ts`, `i18n`) and Phase 3 (`computeHex25DGeometry` elevation offset).
- **Phase 5 (US3 - Direct Deme-to-Deme Arcs)**: Depends on Phase 2 (`HexEdgeFlowSchema`) and Phase 4 (`DemeTokenPosition` layout).
- **Phase 6 (US4 - Map Pan & Zoom)**: Depends on Phase 3–5 (`HexMapCanvas.tsx`).
- **Phase 7 (Polish & Verification)**: Depends on Phases 1–6 completion.

### Parallel Opportunities

- `T003` (`src/components/palette.ts`) and `T004` (`src/i18n/locales/*.ts`) can run in parallel.
- `T005` (`tests/unit/hexGrid.test.ts`) and `T011` (`tests/unit/biophysicalPhase.test.ts`) can run in parallel.
- `T008` (`src/components/ContextPanel.tsx`), `T010` (`src/components/MapLegend.tsx`), and `T012` (`src/engine/biophysicalPhase.ts`) touch separate files and can run in parallel.

## Implementation Strategy

1. **MVP Increment (Phases 1–3 / US1)**: Deliver 2.5D terrain projection, 7 biome illustrations, and integrated ecological indicators.
2. **Inhabitant Legibility Increment (Phase 4 / US2)**: Deliver expressive `Deme` tokens with vital status rings, dominant decision archetype badges, and cultural indicators.
3. **Interaction Clarity Increment (Phase 5 / US3)**: Deliver direct animated `Deme-to-Deme` quadratic Bézier arcs for intra-hex and inter-hex interactions.
4. **Spatial Navigation Increment (Phase 6–7 / US4)**: Deliver pan & zoom camera controls and validate all unit, contract, and integration tests.
