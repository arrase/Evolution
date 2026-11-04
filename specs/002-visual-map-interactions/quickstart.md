# Quickstart & Validation Guide: Visualización 2.5D del Terreno e Interacciones Expresivas de los Habitantes

**Feature**: `002-visual-map-interactions`  
**Date**: 2026-11-04

## Prerequisites

- Node.js 22+ and npm installed.
- Dependencies installed via `npm install`.

## Automated Validation Commands

1. **Typecheck (Strict TypeScript 7)**:
   ```bash
   npm run typecheck
   ```
2. **Unit, Contract & Integration Test Suite (Vitest)**:
   ```bash
   npm test
   ```
3. **Production Bundle Verification**:
   ```bash
   npm run build
   ```

## Visual & Interactive Verification Scenarios

1. **2.5D Terrain & Biome Motifs (US1)**:
   - Start the dev server (`npm run dev`) and load *"The Rift and the Savanna"* preset.
   - Verify that high-altitude mountain and savanna cells rise visually with a 2.5D side skirt above coastal shallows and ocean cells, each biome displays its distinct vector illustration, and terrestrial cells show their integrated resource bar and degradation contour when overexploited.
2. **Expressive Deme Tokens (US2)**:
   - Step 1 generation (`Step`) and observe the deme tokens on the map.
   - Verify each deme displays its outer vital status ring (`thriving`, `stable`, `struggling`, `starving`), its top-right dominant decision archetype icon badge, and its top-left cultural badge when cultural traditions are present.
3. **Direct Deme-to-Deme Interaction Arcs (US3)**:
   - Advance generations until two cohabiting or neighboring demes engage in `exchange`, `dispute`, or `migration`.
   - Verify that curved animated arcs connect the participating deme tokens directly (including between cohabiting demes inside the same hexagon) with a midpoint interaction icon, and hovering the cell summarizes the active interactions.
4. **Map Pan & Zoom (US4)**:
   - Use the bottom-right `+`, `-`, and `Reset` camera controls or mouse wheel/drag in `Inspect` mode to zoom into a multi-deme hexagon ($>2\times$) and pan across the board, then reset to `100%`.
