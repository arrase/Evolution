# Source Root & Main Controller (`src`)

## Overview
Contains the top-level Godot scene controller (`EvoMainController` in `main.gd`) that wires together the simulation state, turn loop timer, asynchronous Ollama result polling, 2.5D world renderer, orbital camera controller, and HUD/modal signal handlers, alongside the four core architectural packages (`core`, `engine`, `ui`, and `world`).

## Interface
- `[main.gd:EvoMainController]` — Root `Node2D` controller attached to `res://scenes/main.tscn`.
  - Constants: `NORMAL_STEP_INTERVAL` (`1.50`), `FAST_STEP_INTERVAL` (`0.30`), `SLOT_A_DEME_IDS` (`["deme-rift-west", "deme-darwin-founder", "deme-island-1"]`), `SLOT_B_DEME_IDS` (`["deme-rift-east", "deme-darwin-rival", "deme-island-2"]`).
  - Properties: `world_state`, `camera`, `world_renderer`, `ui_layer`, `hud`, `lang`, `current_lang`, `lab_modal`, `is_playing`, `is_fast`, `quit_on_close_enabled`.
  - Methods: `load_preset(preset_id, strategy_a_id, strategy_b_id)`, `set_matchup_strategies(strategy_a_id, strategy_b_id)`, `reset_matchup()`, `step_generation()`.
- Subdirectories:
  - [Core (`./core`)](./core/README.md) — Foundational data models (`EvoTypes`), 6-axis thermodynamics (`EvoThermodynamics`), axial hex math (`HexMath`), catalogs (`EvoCatalog`), presets (`EvoPresets`), i18n (`EvoI18n`), and persistent user settings (`EvoUserSettings`).
  - [Simulation Turn Engine (`./engine`)](./engine/README.md) — Four-phase generational turn pipeline (`EvoTurnEngine`, `EvoEnvPhase`, `EvoDecisionModel`, `EvoBiophysPhase`, `EvoMilestonePhase`), biophysical demography/ecology (`./engine/biophys`), and cognitive System 1 / Ollama client (`./engine/cognitive`).
  - [UI Subsystem (`./ui`)](./ui/README.md) — Root HUD (`EvoMainHud`), pixel-art parchment/wood styling (`EvoUiStyle`), interactive modals (`EvoLabModal`, `EvoNotebookModal`, `EvoTreeModal`), and modular HUD sub-builders (`./ui/hud`).
  - [2.5D World Presentation & Asset Subsystem (`./world`)](./world/README.md) — 2.5D hex world renderer (`EvoWorldRenderer`), orbital camera (`EvoCameraController`), procedural pixel-art asset cache (`EvoPixelArtGen`), render pass helpers (`./world/render`), and sprite generators (`./world/sprites`).

## Invariants
- `[main.gd:_process]` — Auto-play generation stepping (`_play_timer >= interval`) never advances to the next generation while `EvoDecisionModel.has_pending_jobs()` is `true`.
- `[main.gd:step_generation]` / `[main.gd:_on_play_pause_toggled]` / `[main.gd:_unhandled_key_input]` — Simulation playback and manual generation stepping are blocked whenever `hud._ollama_startup_blocked` is `true` or `hud._missing_models_modal` is visible; `KEY_SPACE` also yields when a `LineEdit`/`TextEdit` holds focus or any HUD modal/popup is open.
- `[main.gd:load_preset]` — Loading or resetting a scenario preset preserves all `user` and `custom`-origin traits, decisions, and strategies from the previous `world_state` catalogs before reapplying `strategy_a_id` and `strategy_b_id` to `SLOT_A_DEME_IDS` and `SLOT_B_DEME_IDS`.
- `[main.gd:step_generation]` — Automatically pauses playback (`is_playing = false`) when `res["has_macro_outcome"]` is `true` or when `world_state.auto_pause_on_milestone` and `res["has_milestone"]` are both `true`.

## Side Effects
- `[main.gd:_ready]` — Loads disk settings via `EvoUserSettings.load_settings()`, probes local Ollama connectivity via `EvoDecisionModel.check_ollama_status(true)`, instantiates and adds child nodes (`EvoCameraController`, `EvoWorldRenderer`, `CanvasLayer`, `EvoMainHud`), and initializes `preset-rift-savanna`.
- `[main.gd:_exit_tree]` / `[main.gd:_on_quit_requested]` — Blocks until background Ollama worker threads finish via `EvoDecisionModel.wait_for_workers()` and terminates the scene tree (`get_tree().quit()`) when `quit_on_close_enabled` is `true`.
- `[main.gd:_on_strategy_saved]` / `[main.gd:_on_catalog_item_saved]` — Persists custom catalog items to `~/.config/Evolution/user_catalog.json` via `EvoUserSettings.save_user_catalog(world_state)`, clears `EvoOllamaClient` cache, invalidates state caches, and triggers `EvoDecisionModel.evaluate_all_demes` and `EvoDecisionModel.prefetch_for_state`.

## Verification
- Run: `godot --headless --path . --script res://tests/test_runner.gd`
