# Contract: 2.5D Hex Map & Expressive Deme Interaction Rendering

**Feature**: `002-visual-map-interactions`  
**Date**: 2026-11-04

## 1. Biophysical Flow Target Emission (`src/engine/biophysicalPhase.ts`)

`resolveBiophysicalAndDemographicPhase(state, decisionsByDemeId)` MUST populate `targetDemeId` on every emitted `HexEdgeFlow`:

1. **Hawk vs. Hawk Dispute (`type: "dispute"`, `fromHexId === toHexId`)**:
   - Each disputing hawk at index `i` in `hawks` emits a flow targeting its opponent hawk at `(i + 1) % hawks.length` (`targetDemeId: opponentHawk.id`).
2. **Hawk vs. Dove Dispute (`type: "dispute"`, `fromHexId === toHexId`)**:
   - Each disputing hawk emits a flow targeting the primary resident dove (`targetDemeId: doves[0].id`).
3. **Intra-Hex Symbiotic Exchange (`type: "exchange"`, `fromHexId === toHexId`)**:
   - Each exchanger at index `i` in `exchangers` emits a flow targeting its cohabiting exchange partner at `(i + 1) % exchangers.length` (`targetDemeId: partner.id`).
4. **Inter-Hex Symbiotic Exchange (`type: "exchange"`, `fromHexId !== toHexId`)**:
   - Each donor emits a flow targeting the neighbor receiver deme (`targetDemeId: receiver.id`).
5. **Migratory Fission (`type: "migration"`, `fromHexId !== toHexId`)**:
   - The parent deme emits a flow targeting the newly created daughter deme (`targetDemeId: daughterId`).

## 2. 2.5D Terrain & Ecological Overlay Contract (`src/components/HexMapCanvas.tsx`)

1. **Back-to-Front Painter's Order**:
   - `cellList` MUST be sorted by ascending `centerY` (and `centerX` tie-breaker) so southern 2.5D elevated cells naturally overlap the lower rims of northern cells without z-fighting.
2. **2.5D Extrusion & Biome Illustration**:
   - Every non-ocean cell MUST render a two-tone lower 3D skirt (`leftSkirtPoints`, `rightSkirtPoints`) proportional to `cell.altitude` and a top polygon shifted by `-elevationPx`.
   - In `mapLens === "biome"`, each cell MUST render its biome-specific SVG illustration motif (`tropical_forest`, `savanna`, `arid_steppe`, `tundra`, `high_mountain`, `coastal_shallows`, `ocean`).
3. **Integrated Resource & Degradation Signals**:
   - Every non-ocean cell MUST display a resource level indicator proportional to `cell.currentResources / cell.carryingCapacityMax`.
   - Every non-ocean cell with `cell.carryingCapacity < 0.85 * cell.carryingCapacityMax` MUST render a visible habitat degradation warning ring/contour even when `mapLens === "biome"`.

## 3. Expressive Deme Token & Direct Arc Contract (`src/components/HexMapCanvas.tsx`)

1. **Deme Token Anatomy**:
   - Outer vital status ring colored by `getDemeStatus(deme)` (`thriving`, `stable`, `struggling`, `starving`).
   - Lineage-colored core circle with population label.
   - Top-right archetype badge showing the vector glyph for `dominantArchetype` (`forage`, `overexploit`, `migrate`, `cooperate`, `exchange`, `dispute`, `innovate`, `custom`).
   - Top-left cultural indicator badge when `deme.culturalTraitIds.length > 0`.
2. **Direct Deme-to-Deme Quadratic Bézier Arcs**:
   - Every `HexEdgeFlow` MUST render as a curved `<path>` between the pixel coordinates of `flow.demeId` and `flow.targetDemeId` (falling back to cell center only when a referenced deme is absent), with a midpoint badge indicating `migration`, `exchange`, or `dispute`.
3. **Interactive Pan & Zoom**:
   - `HexMapCanvas` MUST provide `Zoom In`, `Zoom Out`, and `Reset View` controls, wheel zoom ($1.0\times\text{--}2.75\times$), and pointer-drag panning in `inspect` mode.
