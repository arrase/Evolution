# Quickstart & Validation Guide: Mundo 3D de Bloques, Aldeas Vivas e Infraestructuras Visuales de Interacción

**Feature**: `005-3d-voxel-village-world`  
**Date**: 2026-11-04

## Prerequisites

- Node.js 22+ and npm installed.
- Dependencies installed via `npm install`.
- Ollama running locally with `d3:4b`, `tev1:4b`, and `gemma4:e2b` (for live AI turns; deterministic engine/3D tests run without live Ollama).

## Automated Validation Commands

1. **Typecheck (Strict TypeScript)**:
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

1. **3D Stepped Voxel Terrain, Water Plane & Biome Props (US1)**:
   - Start the dev server (`npm run dev`) and load *"The Rift and the Savanna"* or *"Darwin's Archipelago"*.
   - Verify that each territory rises as a 3D stepped block column quantized into up to 10 height levels ($\le 0.85 \cdot R_{\text{hex}}$), ocean and coastal shallows render a 3D water plane at `seaLevel`, and each of the 7 biomes displays 3D block props reflecting resource abundance (`high`, `medium`, `low`) and habitat health (`healthy`, `degraded`, `collapsed`).
2. **Living 3D Villages & 4 Architectural Tiers (US2)**:
   - Inspect villages across generations as their populations grow or shrink.
   - Verify that villages transition across the 4 architectural tiers (**I – Camp**, **II – Hamlet**, **III – Consolidated Village**, **IV – Complex Settlement**), display their lineage color, vital status plinth/smoke, cultural monolith when cultural traits are active, and local activity structures for all 8 decision archetypes (see [world-3d.contract.md](./contracts/world-3d.contract.md)).
3. **3D Roads, Stepped Ramps, Pillar Bridges, Fortifications & Lifecycle Memory (US3)**:
   - Observe interacting villages in *"The Finite Island"* or *"The Rift and the Savanna"*.
   - Verify that trading or actively cooperating villages are linked by **Flat Block Roads** ($|\Delta \text{altitude}| < 0.10$), **Stepped Ramps** ($0.10 \le |\Delta \text{altitude}| < 0.25$), or **3D Pillar Bridges** (over coastal shallows/water or $|\Delta \text{altitude}| \ge 0.25$) with moving caravans and 1-turn disused decay.
   - Verify that territorial disputes erect **Fortified Dispute Fronts** (overriding commercial roads) and migrations trace **3D Expedition Trails**, while sibling merges show an integration path and true extinctions show 1-turn stone ruins.
4. **3D Orbital Camera, Occlusion-Safe Billboards & Selective Pressure Brushes (US4)**:
   - Use the bottom-right HUD camera buttons (`Rotate Left`, `Rotate Right`, `Tilt View`, `Zoom In`, `Zoom Out`, `Reset View`), keyboard shortcuts (`WASD`, `Q/E`, `R/F`), or pointer gestures to orbit $360^\circ$ and tilt between $25^\circ$ and $80^\circ$.
   - Click a village's floating billboard behind a mountain to select it and verify the camera smoothly centers on its territory and `ContextPanel` displays its settlement tier.
   - Activate a Selective Pressure brush (`Terrain` or `Climate`) and drag across multiple 3D columns to confirm the block columns update immediately without rotating or panning the camera.
