# Cognitive System 1 & Ollama Client (`src/engine/cognitive`)

## Overview
Implements cognitive decision-making, geopolitical context analysis, environmental weight modulation, emergent trait synthesis, and asynchronous HTTP worker communication with local Ollama System 1 models (`d3:4b` and `tev1:4b`).

## Interface
- `[heuristic_scorer.gd:EvoHeuristicScorer]` — Static decision eligibility filter, geopolitical context inspector, environmental probability modulator, System 1 prompt formatter, and emergent milestone trait synthesizer.
- `[heuristic_scorer.gd:DEFAULT_SYSTEM_ONE_MODEL]` — Primary System 1 model tag constant (`EvoUserSettings.DEFAULT_PRIMARY_MODEL`).
- `[heuristic_scorer.gd:SECONDARY_SYSTEM_ONE_MODEL]` — Secondary System 1 model tag constant (`EvoUserSettings.DEFAULT_SECONDARY_MODEL`).
- `[heuristic_scorer.gd:resolve_deme_decision_model_tag]` — Deterministically maps a `deme_id` to the primary or secondary Ollama model tag.
- `[heuristic_scorer.gd:is_decision_eligible]` — Evaluates whether a `Deme` satisfies a `DecisionDef`'s biological/cultural trait prerequisites and rival adjacency constraints.
- `[heuristic_scorer.gd:get_eligible_decisions]` — Returns eligible `Array[EvoTypes.DecisionDef]` for a deme.
- `[heuristic_scorer.gd:get_eligible_decision_ids]` — Returns eligible `Array[String]` decision IDs for a deme.
- `[heuristic_scorer.gd:pick_dominant_decision]` — Returns the decision ID with the highest probability (defaulting to `dec-conservative-forage`).
- `[heuristic_scorer.gd:inspect_geopolitical_context]` — Computes and caches intra/adjacent rivals, active pacts, vendettas, horde threats, social memory digest, resource adequacy, rural hinterland count (`owned_rural_count`, `needs_rural_hinterland`), urban `salubrity`, and `in_walled_union` for a deme.
- `[heuristic_scorer.gd:compute_environmental_decision_weights]` — Computes normalized decision weights modulated by resource adequacy, season, crowding, traits, geopolitical threats, urban `salubrity`, and rural hinterland needs.
- `[heuristic_scorer.gd:modulate_deme_probabilities_for_turn]` — Blends current deme probabilities (`0.30`) with environmental weights (`0.70`) and updates `last_decision_probabilities` and `last_dominant_decision_id`.
- `[heuristic_scorer.gd:normalize_decision_probabilities]` — Normalizes raw scores across `eligible_ids` to sum to `1.0000` (snapped to `0.0001`) and identifies `dominant_decision_id`.
- `[heuristic_scorer.gd:compute_baseline_mobility]` — Computes net `spatial_mobility` across a deme's traits clamped to `[-1.5, 1.5]`.
- `[heuristic_scorer.gd:build_top_strategy_prior]` — Returns the top 3 baseline strategy decision weights for a deme.
- `[heuristic_scorer.gd:build_geopolitics_summary]` — Returns a compact geopolitical context dictionary for System 1 payloads.
- `[heuristic_scorer.gd:build_compact_system_one_state]` — Builds the 4-line ecological, demographic, trait, and neighbor briefing string for System 1 evaluation.
- `[heuristic_scorer.gd:build_compact_decision_criteria]` — Builds compact vector and description criteria strings for eligible decisions.
- `[heuristic_scorer.gd:compute_deme_evaluation_signature]` — Computes a deterministic signature string for caching System 1 evaluations (`build_deme_evaluation_signature` is an alias).
- `[heuristic_scorer.gd:invalidate_state_caches]` — Removes cached metadata entries from `WorldState`, `TraitDef`, `DecisionDef`, `Deme`, and `HexCell` instances.
- `[heuristic_scorer.gd:build_contextual_justification]` — Formats localized (`es`/`en`) justification text citing the active Ollama System 1 model tag and geopolitical context.
- `[heuristic_scorer.gd:synthesize_milestone_trait]` — Synthesizes a thermodynamically balanced emergent biological or cultural `EvoTypes.TraitDef` for evolutionary milestones.
- `[ollama_client.gd:EvoOllamaClient]` — Thread-safe asynchronous HTTP client and `WorkerThreadPool` manager for local Ollama `/api/tags`, `/api/pull`, and `/v1/systemone` endpoints.
- `[ollama_client.gd:DEFAULT_OLLAMA_HOST]` — Default Ollama host `"127.0.0.1"`.
- `[ollama_client.gd:DEFAULT_OLLAMA_PORT]` — Default Ollama port `11434`.
- `[ollama_client.gd:DEFAULT_SYSTEM_ONE_MODEL]` — Default primary System 1 model tag (`EvoUserSettings.DEFAULT_PRIMARY_MODEL`).
- `[ollama_client.gd:SECONDARY_SYSTEM_ONE_MODEL]` — Default secondary System 1 model tag (`EvoUserSettings.DEFAULT_SECONDARY_MODEL`).
- `[ollama_client.gd:STATUS_TIMEOUT_MS]` — Status probe timeout (`1500` ms).
- `[ollama_client.gd:EVAL_TIMEOUT_MS]` — System 1 evaluation request timeout (`60000` ms).
- `[ollama_client.gd:PULL_STALL_TIMEOUT_MS]` — Model pull stall timeout (`60000` ms).
- `[ollama_client.gd:SYSTEM_ONE_INSTRUCTIONS]` — System 1 evaluation instruction prompt string.
- `[ollama_client.gd:clear_cache]` — Increments `_cache_epoch` and clears live signature caches and pending jobs.
- `[ollama_client.gd:check_ollama_status]` — Returns cached Ollama connectivity/model readiness and optionally launches an asynchronous probe (`refresh_ollama_status_async` forces refresh).
- `[ollama_client.gd:filter_decision_models_from_tags]` — Filters `/api/tags` models that include `"decision"` in `capabilities`.
- `[ollama_client.gd:start_pull_models]` — Starts a background worker to stream `/api/pull` for missing model tags (`trigger_auto_pull_missing_models`, `cancel_pull`, `get_pull_state`).
- `[ollama_client.gd:build_compact_system_one_state]` — Packages briefing, `strategy_traits_prior`, `geopolitics`, and `memory` dictionary for System 1 requests.
- `[ollama_client.gd:build_live_job]` — Constructs an Ollama evaluation job dictionary for a representative deme and signature.
- `[ollama_client.gd:can_enqueue_jobs]` — Checks whether Ollama worker jobs can be enqueued (`needs_prefetch`, `has_cached_or_can_enqueue`).
- `[ollama_client.gd:lookup_or_enqueue_single_deme]` — Returns a cached signature evaluation or enqueues a background System 1 job.
- `[ollama_client.gd:seed_signature_cache]` — Injects a precomputed evaluation entry into `_live_signature_cache`.
- `[ollama_client.gd:sync_and_enqueue_batch]` — Returns cached batch evaluations and enqueues missing signature jobs (`prefetch_for_reps`, `pop_newly_completed`, `has_pending_jobs`, `wait_for_workers`).

## Invariants
- `[heuristic_scorer.gd:normalize_decision_probabilities]` — Output probabilities across `eligible_ids` are non-negative, snapped to `0.0001`, and sum to `1.0000` via complement adjustment on `max_decision_id`.
- `[heuristic_scorer.gd:is_decision_eligible]` — `dec-explore-innovate` and `dec-exchange-symbiosis` require cultural capacity (`bio-encephalization` or `bio-social-instinct`); `dec-territorial-dispute` requires an intra-hex or adjacent rival deme when `state != null`.
- `[heuristic_scorer.gd:synthesize_milestone_trait]` — Synthesized emergent traits are balanced via `EvoThermodynamics.validate_and_balance_thermodynamics(raw_vec, false)` and receive unique IDs and names (`<= 60` characters).
- `[ollama_client.gd:_mutex]` — All reads and writes to shared worker state (`_cached_ollama_status`, `_live_signature_cache`, `_pending_jobs_by_sig`, `_newly_completed_sigs`, `_pull_state`) are guarded by `_mutex`.
- `[ollama_client.gd:_run_ollama_worker]` — Completed worker batch results are discarded if `_cache_epoch` changed while the batch was in flight.

## Side Effects
- `[heuristic_scorer.gd:modulate_deme_probabilities_for_turn]` — Mutates `deme.last_decision_probabilities`, `deme.last_dominant_decision_id`, and stores memoization metadata (`geo_ctx_*`, `pass_n_*`, `env_w_*`, `base_w_*`, `sig_cache_*`) on `Deme`, `HexCell`, `TraitDef`, `DecisionDef`, and `WorldState` objects.
- `[ollama_client.gd:check_ollama_status]` — Spawns `WorkerThreadPool` tasks and performs non-blocking TCP/HTTP requests (`HTTPClient`) to `127.0.0.1:11434` (`/api/tags`, `/api/pull`, `/v1/systemone`).
- `[ollama_client.gd:sync_and_enqueue_batch]` — Mutates static cross-thread caches (`_live_signature_cache`, `_pending_jobs_by_sig`, `_newly_completed_sigs`, `_completed_revision`).

## Verification
- Run: `godot --headless --path . --script res://tests/test_runner.gd`
