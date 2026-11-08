# Simulation Turn Engine (`src/engine`)

## Overview
Orchestrates the core generation turn pipeline and player selective-pressure interventions. Each generation advances deterministically through four sequential phases—environmental cycling (`EvoEnvPhase`), cognitive System 1 decision evaluation (`EvoDecisionModel`), biophysical and demographic interactions (`EvoBiophysPhase`), and evolutionary milestones/macro-outcomes (`EvoMilestonePhase`)—followed by asynchronous Ollama prefetching.

## Interface
- `[turn_engine.gd:EvoTurnEngine]` — Top-level turn execution and player environmental brush intervention controller.
- `[turn_engine.gd:COST_SET_BIOME]` — Selective pressure point cost (`10`) for `apply_set_biome`.
- `[turn_engine.gd:COST_ADJUST_ALTITUDE]` — Selective pressure point cost (`15`) for `apply_adjust_altitude`.
- `[turn_engine.gd:COST_ADJUST_CAPACITY]` — Selective pressure point cost (`10`) for `apply_adjust_carrying_capacity`.
- `[turn_engine.gd:COST_ADJUST_SEA_LEVEL]` — Selective pressure point cost (`25`) for `apply_adjust_sea_level`.
- `[turn_engine.gd:advance_generation]` — Executes all four generation phases in order, triggers `EvoDecisionModel.prefetch_for_state`, and returns `{ "generation", "new_entries", "has_milestone", "has_macro_outcome", "milestone_entry", "outcome_entry" }`.
- `[turn_engine.gd:apply_set_biome]` — Applies biome brush to `hex_ids`, deducts `COST_SET_BIOME`, and evacuates/drowns submerged demes.
- `[turn_engine.gd:apply_adjust_altitude]` — Adjusts hex altitude by `delta`, updates altitude-driven biome transitions, deducts `COST_ADJUST_ALTITUDE`, and displaces submerged demes.
- `[turn_engine.gd:apply_adjust_carrying_capacity]` — Scales hex carrying capacity and resources by `1.0 + factor_delta` and deducts `COST_ADJUST_CAPACITY`.
- `[turn_engine.gd:apply_adjust_sea_level]` — Adjusts global `sea_level` within `[0.0, 0.50]`, submerges or emerges cells, deducts `COST_ADJUST_SEA_LEVEL`, and displaces submerged demes.
- `[env_phase.gd:EvoEnvPhase]` — Phase 1 environmental processor (`run_environmental_phase`) handling generation increment, seasonal alternation (`wet_warm` / `dry_cold`), glacial sea-level cycles, coastal submergence evacuation/extinction, climate/resource regeneration, and selective pressure point regeneration.
- `[decision_model.gd:EvoDecisionModel]` — Phase 2 cognitive decision facade coordinating `EvoHeuristicScorer` and `EvoOllamaClient`; constants `DEFAULT_OLLAMA_HOST`, `DEFAULT_OLLAMA_PORT`, `DEFAULT_SYSTEM_ONE_MODEL`, `SECONDARY_SYSTEM_ONE_MODEL`; static methods `resolve_deme_decision_model_tag`, `reassign_world_models`, `check_ollama_status`, `refresh_ollama_status_async`, `is_decision_eligible`, `get_eligible_decisions`, `get_eligible_decision_ids`, `pick_dominant_decision`, `compute_environmental_decision_weights`, `modulate_deme_probabilities_for_turn`, `blend_with_environmental_weights`, `normalize_decision_probabilities`, `compute_baseline_mobility`, `build_compact_system_one_state`, `build_compact_decision_criteria`, `compute_deme_evaluation_signature`, `build_deme_evaluation_signature`, `build_contextual_justification`, `invalidate_state_caches`, `evaluate_deme`, `evaluate_all_demes`, `prefetch_for_state`, `apply_completed_live_results`, `has_pending_jobs`, `wait_for_workers`, `synthesize_milestone_trait`.
- `[biophys_phase.gd:EvoBiophysPhase]` — Phase 3 biophysical facade (`run_biophysical_phase`, `compute_effective_vector`, `get_archetype_prob`, `is_hex_passable_for_deme`, `compute_deme_divergence`) coordinating `EvoEcologyInteraction` and `EvoDemographyMigration`.
- `[milestone_phase.gd:EvoMilestonePhase]` — Phase 4 milestone and macro-outcome processor (`run_milestone_phase`) evaluating `allopatric_speciation`, `baldwin_assimilation`, `cultural_innovation`, `total_extinction`, `single_survivor`, and `ecological_equilibrium`.
- Subdirectories:
  - [Biophysical & Demographic Engine](./biophys/README.md)
  - [Cognitive System 1 & Ollama Client](./cognitive/README.md)

## Invariants
- `[turn_engine.gd:advance_generation]` — Generation phases always run in strict order: `EvoEnvPhase.run_environmental_phase` -> `EvoDecisionModel.evaluate_all_demes` -> `EvoBiophysPhase.run_biophysical_phase` -> `EvoMilestonePhase.run_milestone_phase` -> `EvoDecisionModel.prefetch_for_state`.
- `[turn_engine.gd:_displace_submerged_demes]` & `[env_phase.gd:run_environmental_phase]` — Flooded/drowned demes only relocate to empty passable neighbor hexes (`ncell.deme_ids.is_empty()`), maintaining `cell.deme_ids.size() <= 1`, and submergence resets `land_use = "wild"`, `owner_deme_id = ""`, and `has_ruins = false`.
- `[turn_engine.gd:_can_afford]` — Player brush interventions require `state.unlimited_pressure_mode` or `state.selective_pressure_points >= cost`, and points are only deducted if at least one cell or sea level state actually changes.
- `[env_phase.gd:run_environmental_phase]` — Terrestrial cell carrying capacity is clamped to `[10.0, cell.carrying_capacity_max]`, ocean cells maintain `current_resources == 0.0`, and cells that suffered `tragedy_of_commons` in the preceding generation recover carrying capacity at rate `0.005` instead of `0.05`.
- `[decision_model.gd:blend_with_environmental_weights]` — Live Ollama System 1 probabilities are blended at `0.75` model weight and `0.25` environmental weight and normalized to sum to `1.0000`.
- `[milestone_phase.gd:run_milestone_phase]` — At most one evolutionary milestone is synthesized per turn, ordered by priority: `allopatric_speciation` (priority 0, `isolation_turns >= 10`, `< 3` emergent biological traits) > `baldwin_assimilation` (priority 1, `baldwin_counters >= 8`, `< 3` emergent biological traits) > `cultural_innovation` (priority 2, `innovation_counter >= 1.0`, `< 2` emergent cultural traits, `last_energy_delta >= 0.0`).
- `[milestone_phase.gd:run_milestone_phase]` — `ecological_equilibrium` triggers only when `state.generation >= 30`, `state.quiet_turns >= 8` (no migration, no chronicle entries, and all deme populations within 5% of `previous_populations`), and neither `ecological_equilibrium` nor `single_survivor` has been logged previously.

## Side Effects
- `[turn_engine.gd:advance_generation]` — Mutates `EvoTypes.WorldState` in place across all four simulation phases and schedules asynchronous Ollama prefetch jobs via `EvoDecisionModel.prefetch_for_state`.
- `[turn_engine.gd:apply_set_biome]` — Mutates `state.cells`, `state.selective_pressure_points`, `state.demes`, `state.active_flows`, `state.active_pacts`, `state.disused_connections`, `state.recent_extinction_hexes`, `state.lineage_tree`, and `state.chronicle`.
- `[env_phase.gd:run_environmental_phase]` — Mutates `state.generation`, `state.season`, `state.sea_level`, `state.disused_connections`, `state.active_flows`, `state.recent_extinction_hexes`, `state.cells`, `state.demes`, `state.lineage_tree`, `state.chronicle`, and `state.selective_pressure_points`.
- `[decision_model.gd:evaluate_all_demes]` — Mutates `deme.decision_model_tag`, `deme.last_decision_probabilities`, `deme.last_dominant_decision_id`, `deme.last_confidence`, `deme.last_justification`, and enqueues background jobs in `EvoOllamaClient`.
- `[milestone_phase.gd:run_milestone_phase]` — Registers newly synthesized emergent `TraitDef` objects in `state.traits_catalog`, inserts speciated `LineageNode` entries into `state.lineage_tree`, updates `state.macro_outcome_type`/`title`/`summary`, updates `state.quiet_turns` and `state.previous_populations`, and appends milestone/macro-outcome entries to `state.chronicle`.

## Verification
- Run: `godot --headless --path . --script res://tests/test_runner.gd`
