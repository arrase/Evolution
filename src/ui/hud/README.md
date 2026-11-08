# HUD Sub-Components (`src/ui/hud`)

## Overview
Provides modular UI construction and state-synchronization helpers for `EvoMainHud`. This package splits the heads-up display into four focused builders: top-left/top-right status and control bars (`EvoHudTopBar`), the bottom 10-slot environmental intervention hotbar and valley legend (`EvoHudHotbarDock`), the right-hand 3-tab parchment scroll inspector (`EvoHudInspectorPanel`), and the milestone banners, chronicle toast stack, and blocking Ollama startup modals (`EvoHudBannersToasts`).

## Interface
- `[hud_banners_toasts.gd:EvoHudBannersToasts]` — `build_banners_and_toasts(hud)`, `build_legend_panel(hud)`, `refresh_legend_texts(hud)`, `show_ollama_offline_popup(hud)`, `show_missing_models_popup(hud, missing_models)`, `process_toasts(toast_vbox, delta)`, `show_milestone_banner(hud, title, summary, is_macro)`, `push_chronicle_toast(hud, entry)`, `update_first_steps_labels(hud)`.
- `[hud_hotbar_dock.gd:EvoHudHotbarDock]` — `HOTBAR_SLOTS_DEF`, `refresh_legend(state, lang)`, `build_bottom_hotbar(hud)`, `build_legend_panel(hud)`, `get_slot_title_and_desc(lang, slot_idx)`, `get_active_hotbar_slot_index(active_tool, active_sub_mode)`, `update_hotbar_visuals(hud)`, `rebuild_sub_tool_options(hud)`, `rebuild_legend_content(hud)`, `refresh_legend_for_hud(hud, state, lang)`.
- `[hud_inspector_panel.gd:EvoHudInspectorPanel]` — `deme_strategy_label`, `deme_selector_option`, `build_right_scroll_inspector(hud)`, `rebuild_villages_list(hud)`, `rebuild_deme_sheet(hud)`, `rebuild_hex_sheet(hud)`, `format_active_pacts_summary(world_state, lang, d)`, `build_deme_relations_lines(world_state, lang, d)`.
- `[hud_top_bar.gd:EvoHudTopBar]` — Signals `matchup_changed(strategy_a_id, strategy_b_id)`, `matchup_reset_requested()`; constants `PRESET_LIST`, `BASE_STRATEGY_ORDER`; properties `strategy_a_swatch`, `strategy_a_option`, `matchup_vs_label`, `strategy_b_swatch`, `strategy_b_option`, `matchup_reset_button`; inner class `SeasonTidePortrait` (`set_state(p_wet_warm, p_sea_level)`); methods `refresh_strategies(state, lang)`, `refresh(state, is_playing)`, `set_language(lang)`, `build_top_left_valley_sign_and_medallions(hud)`, `build_top_right_clock(hud)`, `build_settings_popup(hud)`, `refresh_strategies_for_hud(hud, state, lang)`, `update_static_labels(hud)`, `update_top_bar_state(hud)`, `refresh_decision_model_selectors(hud)`.

## Invariants
- `[hud_hotbar_dock.gd:HOTBAR_SLOTS_DEF]` — Defines 10 fixed slots (`0..9`, keys `1..0`) with deterministic selective-pressure costs (`inspect`: `0`, `set_biome`: `10`, `adjust_altitude`: `15`, `adjust_carrying_capacity`: `10`, `sea_level`: `25`).
- `[hud_banners_toasts.gd:show_ollama_offline_popup]` / `[hud_banners_toasts.gd:show_missing_models_popup]` — Always invoke `hud._set_startup_blocked(true)` to prevent simulation playback until Ollama and required decision models are ready.
- `[hud_banners_toasts.gd:push_chronicle_toast]` — Deduplicates consecutive toasts with matching `generation` and `event_type`, limits `_toast_vbox` to at most 2 active toast nodes, and assigns each toast a `3.8` second `ttl`.
- `[hud_top_bar.gd:refresh_strategies_for_hud]` — Preserves `BASE_STRATEGY_ORDER` before appending sorted user strategies and guards option selection changes with `_suppress_strategy_signal`.
- `[hud_inspector_panel.gd:rebuild_villages_list]` — Orders living demes by descending `population` and disables previous/next cycle buttons unless at least 2 demes are alive.

## Side Effects
- `[hud_top_bar.gd:build_top_left_valley_sign_and_medallions]`, `[hud_top_bar.gd:build_top_right_clock]`, `[hud_top_bar.gd:build_settings_popup]`, `[hud_hotbar_dock.gd:build_bottom_hotbar]`, `[hud_hotbar_dock.gd:build_legend_panel]`, `[hud_inspector_panel.gd:build_right_scroll_inspector]`, `[hud_banners_toasts.gd:build_banners_and_toasts]` — Instantiate Godot `Control` nodes and bind them directly to properties and metadata on the host `EvoMainHud` instance.
- `[hud_top_bar.gd:refresh_decision_model_selectors]` — Queries `EvoDecisionModel.check_ollama_status(false)` and reads `EvoUserSettings.primary_model` and `EvoUserSettings.secondary_model`.

## Verification
- Run: `godot --headless --path . --script res://tests/test_runner.gd`
