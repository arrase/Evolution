# Phase 1 Data Model: Visualización 2.5D del Terreno e Interacciones Expresivas de los Habitantes

**Feature**: `002-visual-map-interactions`  
**Date**: 2026-11-04

## 1. Schema Extensions (`src/types/simulation.ts`)

### `HexEdgeFlowSchema` & `HexEdgeFlow`

Extends the turn interaction flow record with an optional `targetDemeId` field so intra-hex and inter-hex interactions link directly to the participating target `Deme`:

```ts
export const HexEdgeFlowSchema = z.object({
  fromHexId: z.string().regex(/^-?\d+,-?\d+$/),
  toHexId: z.string().regex(/^-?\d+,-?\d+$/),
  demeId: z.string().min(1),
  targetDemeId: z.string().min(1).optional(),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  type: HexEdgeFlowTypeSchema,
  intensity: z.number().min(0.05).max(1.0)
});
```

**Validation & Resolution Rules**:
- `fromHexId` and `toHexId`: Required axial coordinate strings matching `/^-?\d+,-?\d+$/`.
- `demeId`: Required non-empty string (`min(1)`) identifying the initiating/source `Deme`.
- `targetDemeId`: Optional non-empty string (`min(1)`).
  - For **intra-hex `dispute`** (Hawk vs. Hawk or Hawk vs. Dove): Set to the opponent `Deme.id` in the same cell.
  - For **intra-hex or inter-hex `exchange`**: Set to the receiving/partner `Deme.id`.
  - For **inter-hex `migration`**: Set to the newly created daughter `Deme.id` in `toHexId`.
  - When omitted (e.g., imported legacy JSON states), the renderer resolves the target coordinate to a cohabiting counterparty deme in `toHexId` or to `toHexId`'s pixel center.

---

## 2. Visual Projection & Token Models (`src/components/palette.ts` & `src/engine/hexGrid.ts`)

### `DemeVitalStatus`

Shared deterministic classification of a `Deme`'s energetic health used across `HexMapCanvas`, `ContextPanel`, and `MapLegend`:

- Values: `"thriving" | "stable" | "struggling" | "starving"`
- Derivation rule (`getDemeStatus(deme: Deme)`):
  - `deme.lastEnergyDelta >= 10` $\rightarrow$ `"thriving"`
  - `0 <= deme.lastEnergyDelta < 10` $\rightarrow$ `"stable"`
  - `deme.lastEnergyDelta < 0 && deme.energyReserves > 40` $\rightarrow$ `"struggling"`
  - `deme.lastEnergyDelta < 0 && deme.energyReserves <= 40` $\rightarrow$ `"starving"`

### `Hex25DGeometry`

Computed 2.5D pixel projection for each `HexCell`:

- `centerX: number`, `centerY: number`: Base hex center from `honeycomb-grid`.
- `elevationPx: number`: Vertical relief offset (`0` for `ocean`, `Math.round(2 + cell.altitude * 8)` for terrestrial biomes, bounded in $[0, 10]$).
- `topPolygonPoints: string`: Top hex face vertices shifted by `-elevationPx` on the Y axis.
- `leftSkirtPoints: string`: South-west extrusion quad connecting the lower-left and bottom vertices from `-elevationPx` to base `0`.
- `rightSkirtPoints: string`: South-east extrusion quad connecting the bottom and lower-right vertices from `-elevationPx` to base `0`.

### `DemeTokenPosition`

Exact board coordinate for each `Deme` on the 2.5D top face of its `HexCell`:

- `demeId: string`
- `hexId: string`
- `x: number`: `centerX + offset.dx`
- `y: number`: `centerY - elevationPx + offset.dy`
- `radius: number`: `Math.max(9, Math.min(14, Math.log10(population) * 6))`
- `dominantArchetype: DecisionArchetype`: Resolved from `world.decisionsCatalog[deme.lastDominantDecisionId].archetype`.
- `vitalStatus: DemeVitalStatus`: Resolved via `getDemeStatus(deme)`.
- `hasCulture: boolean`: `deme.culturalTraitIds.length > 0`.
