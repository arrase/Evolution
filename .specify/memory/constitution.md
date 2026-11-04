<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0
- Modified principles:
  - IV. Curated Modern TypeScript Ecosystem (No Reinventing the Wheel) (added i18next / react-i18next mandate)
  - V. Transparent & Interactive Sandbox UX (added English default language and multi-language i18n requirement)
- Added sections: None
- Removed sections: None
- Templates requiring updates: None
- Follow-up TODOs: None
-->
# Evolution Population Simulator Constitution

## Core Principles

### I. Radical Simplicity & Zero Defensive Bloat (KISS & YAGNI)
Code and architecture MUST implement the exact requirements with the minimal, most direct, and readable design possible. Modules MUST follow a linear top-to-bottom control flow with single-responsibility functions. Unsolicited defensive bloat—such as speculative `try/catch` blocks, arbitrary fallback defaults (`??`, `||`), optional parameters where values are guaranteed by internal flow, or premature abstraction layers (factories, strategy interfaces with a single implementation)—is strictly prohibited (`MUST NOT` be introduced). All imports MUST be placed at the top of each file.

### II. Scientific Rigor & Bio-Cultural Fidelity
The simulation MUST enforce a strict separation between **behavioral intent** (probabilistic choices evaluated by AI models) and **biophysical consequence** (deterministic mathematical laws of energy conservation, carrying capacity $K$, metabolic cost, and demography). Authentic evolutionary and sociological phenomena—including $r/K$ selection trade-offs, the Baldwin Effect (behavioral plasticity guiding genetic assimilation), Dual Inheritance Theory (cumulative cultural traditions), Evolutionary Game Theory (Tragedy of the Commons, Hawk-Dove dynamics), and allopatric divergence—MUST emerge organically from these rules rather than scripted events.

### III. Dual-Frequency Cognitive Architecture (d3 + gemma4:e4b-it-qat)
AI model orchestration MUST separate high-frequency per-turn scoring from low-frequency generative synthesis:
- **System 1 (`d3` via Ollama):** MUST execute in the generational turn loop to evaluate each local subpopulation (*deme*) and its hexagonal neighborhood, returning normalized probability distributions over available decisions without free-form text generation overhead.
- **System 2 (`gemma4:e4b-it-qat` via Ollama/LangChain):** MUST execute exclusively on evolutionary/cultural milestones, user-initiated catalog creation, or lineage chronicle generation to synthesize new emergent traits/traditions, calibrate biophysical vectors within thermodynamic bounds, and document causal natural history.

### IV. Curated Modern TypeScript Ecosystem (No Reinventing the Wheel)
The application MUST be built in strict TypeScript using the latest stable versions of established open-source libraries rather than custom re-implementations of solved problems. Specifically, the stack MUST leverage the official `ollama` JavaScript SDK and LangChain.js (`@langchain/ollama`, `@langchain/core`, and `zod` for structured schema validation) for model interaction, a dedicated hexagonal grid library (such as `honeycomb-grid`) for axial/cube hex geometry and neighbor traversal, `i18next` and `react-i18next` for internationalization (i18n), and a modern reactive web UI and 2D SVG/canvas rendering stack.

### V. Transparent & Interactive Sandbox UX
The player acts as the **Selective Pressure** and **Evolutionary Architect**, never as a direct RTS unit commander. The web interface MUST default to **English (`en`)** and support live internationalization (`i18n`) across major world languages (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`), including localized AI outputs from System 2. The interface MUST provide:
- A **Hexagonal Grid Map** displaying biomes, carrying capacity ($K$), local *demes*, and inter-hex flows across the 6 equidistant edges.
- **Generational Turn Playback Controls** (`Pause`, `Step 1 Generation`, `Auto-Play`, `Auto-Pause on Milestones`, and a live `Language Selector`).
- A **Live Cognitive Inspector** exposing the exact decision probability distribution computed by `d3` for any selected *deme*.
- An **Open Catalog Editor** allowing the player to modify or create new Traits and Decisions (combining semantic descriptors for `d3` with bounded 6-axis biophysical vectors) and start from curated **Scientific Presets**.

## Architectural & Scientific Constraints

- **Unit of Simulation:** The primary cognitive and demographic unit is the **Deme** (a local subpopulation of a species/culture occupying a specific hexagonal cell), enabling thousands of represented individuals to be simulated fluidly.
- **6-Axis Biophysical Vector:** Every biological trait, cultural tradition, and behavioral decision MUST map to a standardized, bounded 6-axis biophysical vector: `metabolicCost`, `extractionEfficiency`, `ecologicalImpact`, `spatialMobility`, `socialCohesion`, and `transmissionThreshold`.
- **Thermodynamic Conservation:** No trait or decision created by the user or synthesized by `gemma4:e4b-it-qat` may violate thermodynamic trade-offs (high extraction or encephalization MUST carry commensurate metabolic or ecological costs).

## Specification & Development Workflow

- **Spec-First Discipline:** All features MUST progress through the Spec-Kit pipeline (`constitution` → `specify` → `clarify` → `plan` → `checklist` → `tasks` → `analyze`) before application code is written.
- **Adversarial Subagent Review:** Major specification and planning artifacts MUST be audited by independent review subagents to eliminate ambiguity, terminology drift, and coverage gaps prior to implementation.
- **Deterministic Core Testability:** The biophysical simulation engine and hex-grid spatial rules MUST be pure, deterministic functions testable independently of live Ollama model calls via mocked probability distributions.

## Governance

This Constitution is the highest governance authority for the Evolution Population Simulator repository. Any conflict between this document and downstream specifications, plans, or tasks is a CRITICAL defect requiring adjustment of the downstream artifact. Amendments to this Constitution require explicit semantic versioning (`MAJOR` for principle redefinitions/removals, `MINOR` for new principles or constraints, `PATCH` for clarifications) and a documented Sync Impact Report.

**Version**: 1.1.0 | **Ratified**: 2026-11-03 | **Last Amended**: 2026-11-03
