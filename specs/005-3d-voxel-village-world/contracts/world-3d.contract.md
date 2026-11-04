# Contract: 3D Voxel World, Village Settlements & Inter-Village Infrastructure

**Feature**: `005-3d-voxel-village-world`  
**Date**: 2026-11-04

## 1. Pure 3D Voxel Scene Builder Contract (`src/engine/world3d.ts`)

1. **`projectPoint3D(point, camera, origin)`**:
   - MUST rotate `(point.x - origin.x, point.y - origin.y, point.z)` by `camera.yawDeg` ($\in [0, 360)$) around the vertical Z axis and tilt by `camera.pitchDeg` ($\in [25, 80]$), scaling by `camera.zoom` ($\in [0.85, 3.25]$) and offsetting by `(camera.panX, camera.panY)`.
   - MUST return deterministic `{ screenX, screenY, depthZ }` values for any angle.

2. **`classifyTerritoryEcology(cell, seaLevel)`**:
   - MUST quantize `cell.altitude` into `altitudeTier` $\in \{0..10\}$ (`0` for `ocean`, `1..10` for terrestrial cells) and bound `topZ <= 0.85 * HEX_SIZE` (`FR-001`).
   - MUST classify `resourceTier` into `"high"` ($\ge 0.65$), `"medium"` ($0.30\text{–}0.64$), or `"low"` ($< 0.30$) based on `cell.currentResources / cell.carryingCapacityMax` (`FR-003`).
   - MUST classify `healthState` into `"healthy"` ($\ge 0.85$), `"degraded"` ($0.60\text{–}0.84$), or `"collapsed"` ($< 0.60$) based on `cell.carryingCapacity / cell.carryingCapacityMax` (`FR-003`).

3. **`getVillageTier(population)`**:
   - MUST deterministically map `population` into the 4 settlement tiers (`FR-004`):
     - `10..49` $\rightarrow$ `"camp"` (Level `1`, `"I"`)
     - `50..149` $\rightarrow$ `"hamlet"` (Level `2`, `"II"`)
     - `150..399` $\rightarrow$ `"village"` (Level `3`, `"III"`)
     - `>= 400` $\rightarrow$ `"settlement"` (Level `4`, `"IV"`)

4. **`classifyConnectionKind(cellA, cellB, seaLevel)`**:
   - MUST return (`FR-007`):
     - `"bridge"` when `cellA.biome === "coastal_shallows"` or `cellB.biome === "coastal_shallows"` or `cellA.altitude <= seaLevel + 0.04` or `cellB.altitude <= seaLevel + 0.04` or `Math.abs(cellA.altitude - cellB.altitude) >= 0.25`.
     - `"ramp"` when `cellA.id !== cellB.id`, neither cell is coastal/inundated, and `0.10 <= Math.abs(cellA.altitude - cellB.altitude) < 0.25`.
     - `"road"` when `cellA.id === cellB.id` or `Math.abs(cellA.altitude - cellB.altitude) < 0.10` (and neither cell is coastal/inundated).

5. **`buildWorld3DScene(world, camera, options)`**:
   - MUST sort `territories` in back-to-front order by camera-space `depthKey` for any `yawDeg` $\in [0, 360)$.
   - MUST clear biome vegetation/rock props from occupied village footprints and active infrastructure corridors (`FR-006`).
   - MUST generate local activity structures for all 8 `DecisionArchetype` values (`forage`, `overexploit`, `migrate`, `cooperate`, `exchange`, `dispute`, `innovate`, `custom`) and a central cultural monolith when `culturalTraitIds.length > 0` (`FR-005`).
   - MUST enforce `dispute_front` precedence over `road`/`ramp`/`bridge` between the same pair of villages (`FR-008`).
   - MUST emit 1-turn `"disused"` commercial routes, 1-turn `"merge_integration"` trails on sibling merges, and 1-turn `ExtinctionRuins3D` only on true extinctions when given `previousWorld` from generation $t - 1$ (`FR-004`, `FR-007`).

---

## 2. Interactive 3D Viewport, Camera & UI Synchronization Contract (`src/components/HexMapCanvas.tsx`, `MapLegend.tsx`, `ContextPanel.tsx`)

1. **Accessible Orbital Camera Controls (`FR-009`)**:
   - On-screen HUD buttons MUST provide single-click controls for `Rotate Left`, `Rotate Right`, `Tilt View`, `Zoom In`, `Zoom Out`, and `Reset View`.
   - Keyboard shortcuts on the map canvas MUST support `W/A/S/D` or Arrow keys for panning, `Q/E` for orbital rotation, `R/F` for tilt, `+/-` for zoom, and `0` for reset.
   - Pointer drag when `activeBrush.kind !== "inspect"` MUST apply the Selective Pressure brush to hovered 3D territories without rotating or panning the camera.

2. **Occlusion-Safe Floating Village Billboards (`FR-005`, `FR-009`)**:
   - Every active village MUST render a top-layer floating button (`role="button"`, `tabIndex={0}`) at its projected 3D anchor displaying its lineage color, vital status ring, population count, settlement tier (`I–IV`), and dominant decision archetype glyph.
   - Clicking or pressing `Enter`/`Space` on either the 3D village blocks or its floating billboard MUST select the village (`selectDeme`) and its territory (`selectHex`), even when a taller mountain column stands in front of the village.

3. **Legend, HoverCard, ContextPanel & Lineage Beacon Parity (`FR-010`)**:
   - `MapLegend` MUST display the 4 village scale tiers (`camp`, `hamlet`, `village`, `settlement`) and the 3D infrastructure visual keys (`road`, `ramp`, `bridge`, `dispute_front`, `expedition`, `totem`).
   - Both the map `HoverCard` and `ContextPanel` MUST display the localized village tier name (`I – Camp`, `II – Hamlet`, `III – Village`, `IV – Complex Settlement`) alongside population and vital status.
   - When `highlightedLineageId` is active, matching 3D villages MUST display a vertical 3D light beacon in their lineage color while non-matching villages are visually dimmed.
   - All new translation keys MUST be present and non-empty across all 8 supported locales (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`).
