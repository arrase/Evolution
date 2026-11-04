# Quickstart Validation Guide: Optimización de Velocidad por Turno y Enriquecimiento del Contexto Cognitivo

**Feature**: `003-ollama-perf-context`  
**Date**: 2026-11-04

## Prerequisites

- Node.js `v24+` and project dependencies installed (`npm install`).
- Local Ollama server (`v0.40+`) running on `http://127.0.0.1:11434` with `d3:4b` and `gemma4:e4b-it-qat` installed (for live cognitive verification; automated unit/contract/integration suites run deterministically via `vitest`).

## 1. Automated Verification Suite

Run the full typecheck and test suite (unit, contract, and 30-generation scientific preset integration benchmarks):

```bash
npm run typecheck
npm test
```

### Expected Outcomes
- `tsc --noEmit` exits with `0` errors.
- All test suites (`cognitiveSchemas.test.ts`, `biophysicalPhase.test.ts`, `hexGrid.test.ts`, `thermodynamics.test.ts`, `i18n.test.ts`, `scientificPresets.test.ts`) pass 100%.
- New unit/contract tests in `tests/contract/cognitiveSchemas.test.ts` and `tests/unit/biophysicalPhase.test.ts` verify:
  1. `buildCompactSystemOneState` reduces input payload size by `> 35%` while exposing `resourceAdequacyRatio`, `totalCellPopulation`, `rivalDemesCount`, trait biophysical vectors, and passable neighbor opportunities.
  2. `computeDemeEvaluationSignature` deduplicates equivalent deme evaluations within the same generational turn while preserving deme-specific justifications.
  3. Stationary demes with low migration probability (`pMigrate < 0.20`) and adequate local resources do not spawn daughter demes every turn, whereas demes with `pMigrate >= 0.20` or emergency resource scarcity fission as expected.
  4. `executeGenerationalTurn` processes at most 1 milestone synthesis per turn and forwards enriched causal/anti-duplication context to `synthesizeMilestone`.

## 2. Live Interactive Verification

Start the development server:

```bash
npm run dev
```

1. **Rift & Savanna (30 Generations in Auto-Play Fast)**:
   - Select *"The Rift and the Savanna"* and run `Auto-Play (Fast)` through generation 30.
   - Verify that western forest demes remain cohesive (`Conservative Foraging`) without splintering into dozens of micro-clans, eastern savanna demes adapt and disperse coherently, and milestone turns resolve in `~3.3 s` instead of blocking for `30+ s`.
2. **Finite Island (Competition & Overexploitation)**:
   - Select *"The Finite Island"* and step 1 generation with live Ollama (`d3:4b`).
   - Verify in the side Context Panel that the clans recognize the 960-individual overcrowding and extraction tools, selecting `Intensive Overexploitation` or `Territorial Dispute` and triggering the *Tragedy of the Commons*.
