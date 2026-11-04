# Phase 0 Research: Mundo 3D de Bloques, Aldeas Vivas e Infraestructuras Visuales de Interacción

**Feature**: `005-3d-voxel-village-world`  
**Date**: 2026-11-04

## 1. Pure 3D Orbital Voxel-Hex Projection & Flat-Shaded Block Engine

- **Decision**: Implement a pure, deterministic 3D orbital projection and voxel-block scene builder in `src/engine/world3d.ts` paired with declarative multi-layer 3D polygon and voxel-prism rendering in `src/components/HexMapCanvas.tsx`:
  1. **3D Coordinate & Camera Transform**: Map each hexagonal cell's base axial coordinates `(q, r)` from `honeycomb-grid` to world ground coordinates $(x, y)$ and quantize `cell.altitude` ($[0.0, 1.0]$) into **10 discrete block tiers** (`tier = Math.max(1, Math.ceil(cell.altitude * 10))` for terrestrial cells, `0–1` for ocean basins), bounding maximum column height to $H_{\max} = 0.85 \cdot \text{HEX\_SIZE}$ ($32.3\text{ px}$ at base scale) to prevent blind mountain walls (`FR-001`).
  2. **True Orbital Rotation (`yaw`) & Pitch (`pitch`)**: Transform any 3D point $(x, y, z)$ around the world center by orbital `yawDeg` $\in [0^\circ, 360^\circ)$ and `pitchDeg` $\in [25^\circ, 80^\circ]$, outputting screen coordinates $(screenX, screenY)$ and camera-space depth `depthZ` for exact back-to-front 3D painter's sorting of hex columns, voxel props, village structures, and inter-village bridges.
  3. **90s/2000s Flat-Shaded Block Aesthetic**: Render each voxel prism (`VoxelBox3D`) and stepped hex stratum with crisp flat-shaded top, front-left, and front-right faces modulated by the seasonal directional sun vector (`wet_warm` warm golden light vs. `dry_cold` cool crisp light) and a translucent 3D water plane at $z_{\text{water}} = \text{seaLevel} \cdot H_{\max}$ (`FR-002`).
- **Rationale**: Delivers genuine $360^\circ$ orbital 3D rotation, adjustable tilt, stepped block strata, 3D voxel buildings, and elevated bridges while preserving 100% deterministic unit testability in Vitest, native DOM/ARIA keyboard accessibility, instant pointer hit-testing for Selective Pressure brushes, and zero external 3D engine bundle bloat (strictly honoring Constitution Principles I, IV, and V).
- **Alternatives Considered**:
  - *Imperative WebGL engine (`three.js` / `@react-three/fiber`)*: Rejected because it introduces ~600 KB of external runtime dependencies, complicates headless Vitest testing without WebGL mocks, breaks native SVG/DOM accessibility on territories and villages, and conflicts with Constitution Principle I (KISS) and Principle IV.
  - *Fixed-angle 2.5D vertical offset without orbital rotation (previous `002` implementation)*: Rejected because it cannot rotate around mountains, cannot render multi-block 3D villages with vertical architectural tiers, and cannot represent 3D bridges on pillars vs. stepped ramps.

## 2. The 3D Village (`VillageSettlement3D`) as the Collective Unit of Simulation

- **Decision**: Materialize every active `Deme` as a 3D Village settlement (`VillageSettlement3D`) positioned on a dedicated sector of its territory's top plateau (`FR-004`, `FR-005`, `FR-006`):
  1. **4 Architectural Tiers by Population (`getVillageTier(population)`)**:
     - **Tier 1 — Camp (`camp`, `10–49`)**: 2 rudimentary block huts + central hearth block.
     - **Tier 2 — Hamlet (`hamlet`, `50–149`)**: 3–4 block cottages around a cleared square + basic storage blocks.
     - **Tier 3 — Consolidated Village (`village`, `150–399`)**: 5–6 multi-block dwellings, communal storehouse, and lineage-colored banner towers.
     - **Tier 4 — Complex Settlement (`settlement`, `400+`)**: Multi-story central citadel/hall, dense peripheral dwellings, and low perimeter block walls.
  2. **Automatic Footprint Clearing & Cohabitation Compaction**: Exclude biome vegetation/rock voxel props from occupied village sectors and road/bridge corridors. When 2 or 3 villages cohabit a hex, assign them to 2 or 3 non-overlapping radial sectors ($34\%$ or $26\%$ of plateau radius) and scale Tier 3/4 villages vertically (+1 block story) rather than expanding horizontally (`FR-006`).
  3. **Local Activity Structures for All 8 Decision Archetypes**: Every village renders a dedicated 3D activity structure inside its perimeter matching its dominant `DecisionArchetype` (`forage` crop beds, `overexploit` felled stumps & smoking quarry pit, `cooperate` golden-roofed communal granary, `exchange` market stall with trade bales, `dispute` wooden block palisade & watchtower, `migrate` staging camp with supply carts, `innovate` workshop/monolith with glowing discovery cubes, `custom` lineage-draped experimental pavilion), plus a central **Cultural Totem / Monolith** when `culturalTraitIds.length > 0` (`FR-005`).
- **Rationale**: Ensures that even an isolated village with no neighbors visibly expresses its collective decision archetype, vital status (`thriving`, `stable`, `struggling`, `starving`), cultural heritage, and demographic scale in 3D.
- **Alternatives Considered**:
  - *Scaling a single cube's size by population*: Rejected because a single scaled cube does not look like a living village or communicate architectural growth.

## 3. Deterministic 3D Roads, Stepped Ramps, Pillar Bridges & Lifecycle Memory

- **Decision**: Compute inter-village 3D structures (`InterVillageStructure3D`) deterministically from `currentTurnFlows`, cohabiting/neighboring `cooperate` decisions, and a 1-turn visual memory buffer (`previousTurnSnapshot`) (`FR-007`, `FR-008`):
  1. **Commercial & Collaborative Path Classification (`classifyConnectionKind`)**:
     - Triggered when two cohabiting or adjacent villages share an active `exchange` flow OR when both adopt active cooperation (`getArchetypeProb(deme, "cooperate") >= 0.25` or dominant `cooperate`).
     - **`bridge` (3D Pillar Bridge)**: Selected when either connected territory is `coastal_shallows` or has inundation-level altitude ($\text{altitude} \le \text{seaLevel} + 0.04$), OR when the altitude difference between the two territories is steep ($|\Delta \text{altitude}| \ge 0.25$, $\ge 3$ block tiers). Rendered with a 3D deck spanning the gap, vertical support pillars down to the terrain/water, parapets, and moving caravan blocks.
     - **`ramp` (Stepped Block Ramp)**: Selected when two adjacent terrestrial territories (neither `coastal_shallows` nor inundated) have a moderate elevation difference ($0.10 \le |\Delta \text{altitude}| < 0.25$, $1\text{–}2$ block tiers). Rendered as stepped block stairs ascending the slope with caravan blocks.
     - **`road` (Flat Block Road)**: Selected when both villages are in the same territory or in adjacent terrestrial territories at the same block level ($|\Delta \text{altitude}| < 0.10$).
  2. **Conflict Precedence & Disused Route Decay**:
     - If a `dispute` flow exists between the same pair of villages in the current turn, a **Fortified Dispute Front** (`dispute_front`: opposing palisades, barricades, dark smoke, and red clash sparks) takes strict precedence over any commercial road/bridge between that pair.
     - If two surviving villages had an active `road`, `ramp`, or `bridge` in generation $t - 1$ that ceased in generation $t$ (and neither village died, submerged, nor entered a dispute), the structure renders for 1 additional generation with `status: "disused"` (weathered blocks, zero caravans).
  3. **Lifecycle Transition Differentiation (Merge vs. Evacuation vs. Extinction)**:
     - Comparing generation $t - 1$ to generation $t$:
       - If a deme in hex $H$ disappeared while a same-lineage sibling deme in hex $H$ increased its population (automatic Jaccard $< 0.25$ merge in `biophysicalPhase.ts`), render a 1-turn **Integration Path** (`merge_integration`) toward the surviving village instead of extinction ruins.
       - If a deme disappeared with a matching `chronicle` entry of `type === "extinction"` in generation $t$, render **Collapsed Stone Ruins** (`extinction_ruins`) on its sector for 1 generation.
- **Rationale**: Makes every rule in `FR-004`, `FR-007`, and `FR-008` 100% deterministic, mathematically testable, and immune to false visual ruins on sibling merges or coastal evacuations.
- **Alternatives Considered**:
  - *Mutating `WorldStateSchema` to persist visual decay arrays in saved JSON files*: Rejected per KISS & YAGNI because a lightweight 1-turn transition tracker in the view/store layer derives disused routes, sibling merges, and extinction ruins cleanly from consecutive `WorldState` snapshots without polluting the persisted scientific data model.

## 4. Accessible 3D Camera Controls, Occlusion-Safe Billboards & UI Integration

- **Decision**:
  1. **Occlusion-Safe Floating Billboards**: Render each village's compact label (lineage dot, vital status border, population count, Roman numeral tier `I–IV`, and dominant decision glyph) in a top-most SVG/DOM overlay anchored to the village's 3D roof projection, marked with `isOccludedByTerrain` when a taller front hex column overlaps its 3D footprint so the badge remains 100% visible, keyboard-focusable (`Tab`/`Enter`), and clickable (`FR-005`, `FR-009`).
  2. **Strict Gesture Separation & HUD Camera Cluster**:
     - When `activeBrush.kind !== "inspect"`, pointer drag over 3D territories exclusively applies the Selective Pressure brush with a 3D volumetric highlight ring on target hexes (`radius` 1 or 2).
     - Camera rotation (`yawDeg`), tilt (`pitchDeg`), zoom, and pan are operable via: (a) an on-screen HUD camera control cluster (`Rotate Left`, `Rotate Right`, `Tilt View`, `Zoom In`, `Zoom Out`, `Reset View`), (b) keyboard shortcuts (`WASD`/Arrows, `Q/E`, `R/F`, `+/-`, `0`), and (c) `Shift`/`Alt`/secondary-button drag or primary drag in `inspect` mode.
  3. **Legend, HoverCard & ContextPanel Synchronization**: Update `MapLegend.tsx`, `ContextPanel.tsx`, and the hover card in `HexMapCanvas.tsx` to display the 4 village tiers, the 3D infrastructure types (`road`, `ramp`, `bridge`, `dispute_front`, `expedition`, `totem`), 3D lineage light beacons (`highlightedLineageId`), and auto-pan camera focus when selecting a village from `ContextPanel` (`FR-010`).
- **Rationale**: Resolves all 4 UX risks identified in the adversarial 3D UX review (mountain occlusion, 3-village crowding, single-button/trackpad accessibility without brush conflicts, and panel/legend parity).
- **Alternatives Considered**:
  - *Rendering village labels inside the depth-sorted 3D geometry*: Rejected because front mountains would cover labels of valley/coastal villages and prevent selecting them without rotating the camera first.
