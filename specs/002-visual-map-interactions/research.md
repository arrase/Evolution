# Phase 0 Research: Visualización 2.5D del Terreno e Interacciones Expresivas de los Habitantes

**Feature**: `002-visual-map-interactions`  
**Date**: 2026-11-04

## 1. 2.5D Topographic Hex Projection in Declarative SVG

- **Decision**: Render each hexagonal cell using a 2.5D layered SVG projection sorted in back-to-front painter's order (by axial row `r` / pixel `centerY`), combining:
  1. An extruded lower rim (south-west and south-east side faces derived from the lower 3 vertices of the pointy-top hexagon) whose vertical depth scales with `altitude` ($2\text{ px}$ for coastal/lowlands up to $10\text{ px}$ for high mountains, $0\text{ px}$ for ocean).
  2. Radial/linear SVG biome gradients and crisp vector topographic motifs (forest canopy, savanna acacia, steppe dunes, tundra frost crystal, mountain twin peaks, coastal ripples, ocean swells).
  3. Integrated ecological overlays on terrestrial cells: a resource abundance bar/pips (`currentResources / carryingCapacityMax`) and a habitat degradation contour when `carryingCapacity < 0.85 * carryingCapacityMax`.
- **Rationale**: Preserves 100% compatibility with `honeycomb-grid@4.1.5`, pointer events, brush painting, and accessibility roles without adding imperative WebGL/Canvas dependencies (`pixi.js` or `three.js`), directly honoring Constitution Principle I (KISS & YAGNI) and Principle IV.
- **Alternatives Considered**:
  - *Full 3D WebGL (`three.js`) or 2D Canvas (`pixi.js`)*: Rejected because it breaks native DOM/ARIA accessibility on hexes and demes, adds heavy bundle overhead, and duplicates hit-testing logic.
  - *Flat 2D color-only polygons (status quo)*: Rejected because altitude, biome identity, and habitat degradation are invisible without switching lenses or opening the side panel.

## 2. Expressive Deme Visual Tokens (Action Archetype, Vital Status & Culture)

- **Decision**: Upgrade each deme SVG group into a multi-signal token:
  1. **Outer Vital Status Ring**: Colored by deterministic energy status (`thriving`, `stable`, `struggling`, `starving`) extracted into a shared pure helper `getDemeStatus(deme)` used by both `HexMapCanvas` and `ContextPanel`.
  2. **Dominant Decision Archetype Badge**: A circular badge anchored at the top-right perimeter of the deme circle displaying a distinct vector icon for the dominant decision's `DecisionArchetype` (`forage`, `overexploit`, `migrate`, `cooperate`, `exchange`, `dispute`, `innovate`, `custom`).
  3. **Cultural Tradition Indicator**: A purple/gold cultural indicator badge anchored at the top-left perimeter when `deme.culturalTraitIds.length > 0`.
- **Rationale**: Enables players to read the behavioral strategy, demographic health, and cultural evolution of every population across the map in a single glance.
- **Alternatives Considered**:
  - *Text labels for every deme's decision on the map*: Rejected because text strings in 8 languages would clutter adjacent hexes and overlap when 3 demes cohabit.

## 3. Direct Animated Deme-to-Deme Interaction Arcs

- **Decision**: Extend `HexEdgeFlow` with an optional `targetDemeId?: string` populated by `resolveBiophysicalAndDemographicPhase` in `src/engine/biophysicalPhase.ts` for intra-hex disputes, intra/inter-hex symbiotic exchanges, and migratory fission. In `HexMapCanvas.tsx`, compute exact pixel coordinates for each deme token (`hexCenter + DEME_OFFSETS`) and render quadratic Bézier arcs (`<path>`) connecting source and target deme tokens directly, with CSS dash-offset flow animation (respecting `prefers-reduced-motion`) and a midpoint interaction badge.
- **Rationale**: Eliminates the ambiguous cell-wide dashed circle previously used for intra-hex flows (`fromHexId === toHexId`) and visually links the exact populations that are fighting, trading, or splitting. Keeping `targetDemeId` optional ensures backward compatibility with previously saved/exported JSON worlds.
- **Alternatives Considered**:
  - *Keeping cell-center-to-cell-center straight lines*: Rejected because it fails to show which specific demes inside a multi-deme cell are interacting.

## 4. Interactive Map Camera (Pan & Zoom)

- **Decision**: Implement lightweight camera state (`zoom` clamped to $[1.0, 2.75]$ and `pan: { x, y }`) inside `HexMapCanvas.tsx` by dynamically transforming the SVG `viewBox` (or inner viewport group) with pointer-wheel zoom, pointer-drag panning in `inspect` mode (distinguishing $< 5\text{ px}$ click from drag), and an on-screen HUD control cluster (`Zoom In`, `Zoom Out`, `Reset View`).
- **Rationale**: Zero external dependencies required; computing a zoomed/panned `viewBox` keeps SVG vector rendering infinitely sharp at any zoom level and preserves native browser coordinate mapping.
- **Alternatives Considered**:
  - *External pan/zoom libraries (`d3-zoom` or `react-zoom-pan-pinch`)*: Rejected per KISS & YAGNI because a 30-line pure viewBox/transform state handles wheel, drag, and reset controls cleanly without fighting brush painting events.
