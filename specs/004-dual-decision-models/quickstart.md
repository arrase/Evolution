# Quickstart & Validation Guide: `004-dual-decision-models`

## Prerequisites

- Node.js 20+ and npm installed.
- Local Ollama server running at `http://127.0.0.1:11434` with the three models installed:
  ```bash
  ollama pull d3:4b
  ollama pull tev1:4b
  ollama pull gemma4:e2b
  ```

## 1. Automated Typecheck & Test Suite Validation

Run the full TypeScript compiler check and Vitest suite (unit, contract, and 30-generation preset integration tests):

```bash
npm run typecheck && npm test
```

**Expected Outcome**:
- Zero TypeScript errors.
- 100% of unit, contract, and integration test suites pass.
- Contract tests in `tests/contract/cognitiveSchemas.test.ts` verify:
  - Deterministic population-to-model assignment (`d3:4b` and `tev1:4b`).
  - Model-isolated evaluation signatures (`computeDemeEvaluationSignature`).
  - Tri-model `checkStatus()` reporting (`d3:4b`, `tev1:4b`, `gemma4:e2b`).

## 2. Live 3-Model VRAM & Concurrent Turn Verification

Verify that all 3 models load simultaneously at `100% GPU` in VRAM and execute concurrent per-population decisions:

```bash
ollama ps
nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free --format=csv,noheader
```

**Expected Outcome**:
- `d3:4b`, `tev1:4b`, and `gemma4:e2b` all show `100% GPU` in `ollama ps`.
- Total VRAM usage remains `< 15,500 MiB` on a 16 GB GPU (`~15,032 MiB` used, `~816 MiB` free).
