# Biophysical & Demographic Engine (`src/engine/biophys`)

## Overview
Executes the biophysical, ecological, geopolitical, and demographic simulation rules for each generation turn under a strict 1-deme-per-hex spatial model. This package computes effective biophysical trait/decision vectors, resolves urban foraging penalties and rural hinterland (`crops`/`pasture`) claiming/harvesting/pillaging, mediates inter-hex Hawk-Dove competition, cultural symbiosis, and Tragedy of the Commons degradation, manages inter-deme pacts, betrayals, raids, tributes, and fortifications, and advances demographic growth, urban `salubrity` and epidemics, warband invasions, empty-hex colonist budding, extinctions (leaving ruins), asymmetric category absorptions, and multi-hex walled unions (`walled_union_id`).

## Interface
- `[ecology_interaction.gd:EvoEcologyInteraction]` — Static ecological and geopolitical interaction phase processor.
- `[ecology_interaction.gd:DEFENSE_TIER_BONUS]` — Constant array `[0.0, 0.45, 0.95, 1.55]` defining combat defense bonuses for fortification tiers `0..3`.
- `[ecology_interaction.gd:DEFENSE_ATTENUATION_SCALE]` — Constant array `[1.0, 0.75, 0.50, 0.30]` attenuating dispute, betrayal, and siege impact across fortification tiers `0..3`.
- `[ecology_interaction.gd:get_max_rural_quota]` — Returns the maximum rural hinterland hex quota (`0`, `1`, `2`, `4`) for settlement tiers `1..4`.
- `[ecology_interaction.gd:compute_effective_vector]` — Computes a deme's clamped `EvoTypes.BiophysicalVector` from its biological traits, cultural traits, and probability-weighted decisions.
- `[ecology_interaction.gd:get_archetype_prob]` — Sums decision probabilities matching a target `archetype` string.
- `[ecology_interaction.gd:compute_pact_defense_bonus]` — Computes allied defensive reinforcement bonus (clamped to `[0.0, 1.10]`) from active pacts and `walled_union_id` partners in adjacent hexes.
- `[ecology_interaction.gd:run_resource_and_symbiosis_phase]` — Resolves cell resource extraction (with `urban_forage_mult` for Tier 3–4 cities), rural hinterland claiming and harvesting (`_update_and_harvest_rural_hinterlands`), inter-hex Hawk-Dove competition, horizontal cultural diffusion, Tragedy of the Commons carrying-capacity degradation, inter-hex trade, pacts, betrayals, raids/tributes (including rural hinterland pillaging), and defense tier upgrades.
- `[demography_migration.gd:EvoDemographyMigration]` — Static demographic growth, salubrity/epidemic, migration, warband invasion, and deme unification processor.
- `[demography_migration.gd:is_hex_passable_for_deme]` — Returns true when a `HexCell` is terrestrial (`biome != "ocean"`), `altitude <= 0.85`, and `(altitude - 0.50) <= spatial_mobility`.
- `[demography_migration.gd:compute_deme_divergence]` — Computes Jaccard trait divergence (`[0.0, 1.0]`) across biological and cultural traits between two demes.
- `[demography_migration.gd:run_demography_and_migration_phase]` — Updates metabolic energy balance, urban `salubrity` and epidemic outbreaks, population growth, Baldwin and innovation counters, martial warband invasions (with pooled union defense and 1-deme-per-hex retreat/absorption), empty-hex colonist budding migration, extinctions (marking `has_ruins = true`), demographic bottleneck cultural loss, asymmetric category absorption vs. same-category walled unions (`walled_union_id`), and allopatric isolation turns.

## Invariants
- `[ecology_interaction.gd:compute_effective_vector]` — Effective vector components are clamped to `[-1.5, 1.5]` (`transmission_threshold` to `[0.0, 1.5]`) and snapped to `0.0001`.
- `[ecology_interaction.gd:_can_acquire_trait]` — A deme never acquires duplicate traits or traits listed in `mutually_exclusive_with` relative to its current biological and cultural traits.
- `[ecology_interaction.gd:run_resource_and_symbiosis_phase]` — Total extracted energy from a cell cannot exceed `cell.current_resources`, degraded `cell.carrying_capacity` never falls below `10.0`, and settlements of Tier 2/3/4 claim at most `1`/`2`/`4` adjacent empty passable terrestrial hexes as `"crops"` or `"pasture"`.
- `[ecology_interaction.gd:_run_defense_fortification_phase]` — `deme.defense_tier` is bounded to `0..3` and requires minimum population (`38`, `65`, `100`), deme energy reserves, and local cell resources to upgrade.
- `[demography_migration.gd:is_hex_passable_for_deme]` — Ocean cells and cells with `altitude > 0.85` cannot be colonized or traversed, and every cell maintains `deme_ids.size() <= 1`.
- `[demography_migration.gd:run_demography_and_migration_phase]` — Per-turn demographic `growth_rate` is clamped to `[-0.45, 0.35]`, `deme.salubrity` is clamped to `[0.05, 1.0]` (triggering epidemics when `< 0.35` and `population >= 130`), and `deme.innovation_counter` is capped at `2.0`.
- `[demography_migration.gd:run_demography_and_migration_phase]` — Demes dropping below `population < 10` go extinct and leave `cell.has_ruins = true`; colonist fission requires `migrants >= 10`, leaves the parent deme with at least `10` individuals (`min_keep_pop`), and targets only passable land cells that are empty and have no active rural ownership (`ncell.deme_ids.is_empty() and ncell.owner_deme_id == ""`); active Walled Unions (`walled_union_id`) persist when members advance to higher urban categories (`Tier II–IV`) without mutual absorption.
- `[demography_migration.gd:run_demography_and_migration_phase]` — Cultural loss bottlenecks (`lost_half` or `pre_fission_pop < 50`) are checked against `pre_fission_pop_by_deme` so healthy parent demes do not lose cultural traits solely from colonist budding.

## Side Effects
- `[ecology_interaction.gd:run_resource_and_symbiosis_phase]` — Mutates `state.cells` (`current_resources`, `carrying_capacity`, `land_use`, `owner_deme_id`, `has_ruins`), `state.demes` (`population`, `energy_reserves`, `cultural_trait_ids`, `defense_tier`), `state.active_pacts`, `state.disused_connections`, `state.active_flows`, and appends `symbiosis`, `tragedy_of_commons`, `pact`, `betrayal`, `raid`, `tribute`, and `fortify` entries to `state.chronicle`.
- `[demography_migration.gd:run_demography_and_migration_phase]` — Mutates `state.demes` (spawning `-m*` migrant daughters and `-w*` warbands, erasing extinct or absorbed demes, and updating demographic/salubrity/walled-union/counter fields), `state.cells` (`deme_ids`, `carrying_capacity`, `land_use`, `owner_deme_id`, `has_ruins`), `state.lineage_tree` (`extinct_generation`, trait lists), `state.active_pacts`, `state.active_flows`, `state.disused_connections`, `state.recent_extinction_hexes`, and appends `war`, `siege`, `epidemic`, `extinction`, `cultural_loss`, and `merge` entries to `state.chronicle`.

## Verification
- Run: `godot --headless --path . --script res://tests/test_runner.gd`
