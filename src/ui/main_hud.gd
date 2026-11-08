class_name EvoMainHud
extends Control

signal preset_selected(preset_id: String)
signal matchup_changed(strategy_a_id: String, strategy_b_id: String)
signal matchup_reset_requested()
signal state_imported(new_state: EvoTypes.WorldState)
signal play_pause_toggled(is_playing: bool)
signal step_generation_requested()
signal speed_changed(speed_index: int)
signal language_changed(lang: String)
signal settings_changed(auto_pause: bool, unlimited_pressure: bool, free_sandbox: bool)
signal decision_models_changed()
signal camera_preset_requested(action: String, value: float)
signal tool_changed(tool_id: String, sub_mode: String, brush_radius: int)
signal sea_level_change_requested(delta: float)
signal lens_changed(lens_id: String)
signal deme_selected(deme_id: String, hex_id: String)
signal hex_jump_requested(hex_id: String, deme_id: String)
signal lineage_highlight_requested(lineage_id: String)
signal inject_trait_requested(deme_id: String, trait_id: String)
signal catalog_item_saved(item_type: String, item_data: Dictionary)
signal quit_requested()

const PRESET_LIST: Array[String] = EvoHudTopBar.PRESET_LIST
const DEFAULT_EXPORT_PATH: String = "user://evolution_world_state.json"
const HOTBAR_SLOTS_DEF: Array[Dictionary] = EvoHudHotbarDock.HOTBAR_SLOTS_DEF

var _world_state: EvoTypes.WorldState = null
var _lang: String = "es"
var _is_playing: bool = false
var _speed_index: int = 1
var _suppress_strategy_signal: bool = false

var _active_tool: String = "inspect"
var _active_sub_mode: String = "savanna"
var _brush_radius: int = 1
var _active_lens: String = "biome"

var _selected_hex_id: String = "0,0"
var _selected_deme_id: String = ""
var _highlighted_lineage_id: String = ""

# Top-Left Valley Sign, Strategy Matchup Selector & Artifacts
var _preset_option: OptionButton
var strategy_a_swatch: ColorRect
var strategy_a_option: OptionButton
var matchup_vs_label: Label
var strategy_b_swatch: ColorRect
var strategy_b_option: OptionButton
var matchup_reset_button: Button
var _export_btn: Button
var _import_btn: Button
var _notebook_btn: Button
var _tree_btn: Button
var _lab_btn: Button
var _lens_strip_panel: PanelContainer
var _lens_buttons: Dictionary = {} # lens_id -> Button
var _legend_toggle_btn: Button
var _legend_panel: PanelContainer
var _legend_vbox: VBoxContainer
var _last_hotbar_visual_key: String = ""

# Top-Right Clock & Cognitive Engine Widget
var _season_portrait: EvoHudTopBar.SeasonTidePortrait
var _gen_label: Label
var _season_label: Label
var _sea_level_label: Label
var _play_btn: Button
var _step_btn: Button
var _speed_btn: Button
var _pressure_bar: ProgressBar
var _pressure_label: Label
var _settings_btn: Button

# Settings, Camera & Ollama Models Diagnostic Popup
var _settings_popup: PanelContainer
var _models_diag_lbl: Label
var _primary_model_lbl: Label
var _primary_model_opt: OptionButton
var _refresh_models_btn: Button
var _secondary_model_lbl: Label
var _secondary_model_opt: OptionButton
var _context_window_lbl: Label
var _context_window_input: LineEdit
var _lang_es_btn: Button
var _lang_en_btn: Button
var _auto_pause_check: CheckBox
var _unlimited_pressure_check: CheckBox
var _free_sandbox_check: CheckBox
var _cam_lbl: Label

# Bottom-Center 10-Slot Inventory Hotbar
var _hotbar_slot_buttons: Array[Button] = []
var _tool_buttons: Dictionary = {} # tool_id -> Button
var _sub_options_panel: PanelContainer
var _sub_options_flow: HFlowContainer
var _radius_1_btn: Button
var _radius_2_btn: Button

# Right Floating Parchment Scroll Inspector
var _inspector_frame: PanelContainer
var _inspector_body_vbox: VBoxContainer
var _inspector_minimized: bool = false
var _inspector_minimize_btn: Button
var _inspector_tab: String = "deme" # "deme" | "traits" | "habitat"
var _village_prev_btn: Button
var _village_selector_opt: OptionButton
var deme_selector_option: OptionButton
var _village_next_btn: Button
var _inspector_header_swatch: ColorRect
var _inspector_header_hl_btn: Button
var _inspector_model_badge_lbl: Label
var _strategy_badge_panel: PanelContainer
var deme_strategy_label: Label
var _tab_deme_btn: Button
var _tab_traits_btn: Button
var _tab_habitat_btn: Button
var _inspector_scroll: ScrollContainer
var _deme_sheet_vbox: VBoxContainer
var _traits_sheet_vbox: VBoxContainer
var _hex_sheet_vbox: VBoxContainer

# Top-Center A-vs-B Stats Strip & History Chart
var _stats_strip_panel: PanelContainer
var _stats_chart_panel: PanelContainer
var _stats_chart_toggle_btn: Button
var _stats_chart_metric: String = "population"

# Banners & Live Chronicle Feed
var _milestone_banner: PanelContainer
var _banner_title_lbl: Label
var _banner_summary_lbl: Label
var _last_shown_macro_outcome: String = ""
var _event_feed_panel: PanelContainer
var _event_feed_vbox: VBoxContainer
var _event_feed_filter: String = "all"
var _event_feed_collapsed: bool = false
var _missing_models_modal: Control
var _missing_models_title_lbl: Label
var _missing_models_desc_lbl: Label
var _missing_models_progress_bar: ProgressBar
var _missing_models_status_lbl: Label
var _missing_models_download_btn: Button
var _missing_models_skip_btn: Button
var _startup_models_checked: bool = false
var _ollama_startup_blocked: bool = false
var _pull_in_progress: bool = false
var _pending_missing_models: Array[String] = []

# Modals
var notebook_modal: EvoNotebookModal
var tree_modal: EvoTreeModal
var lab_modal: EvoLabModal


func _ready() -> void:
	if _preset_option != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = EvoUiStyle.get_theme()
	_build_ui()
	set_process(true)
	set_process_unhandled_key_input(true)


func _process(_delta: float) -> void:
	_poll_ollama_startup_and_download()


func _set_startup_blocked(blocked: bool) -> void:
	_ollama_startup_blocked = blocked
	if _play_btn != null:
		_play_btn.disabled = blocked
	if _step_btn != null:
		_step_btn.disabled = blocked
	if blocked and _is_playing:
		_is_playing = false
		_update_static_labels()
		play_pause_toggled.emit(false)


func _poll_ollama_startup_and_download() -> void:
	if not _startup_models_checked:
		var status := EvoDecisionModel.check_ollama_status(false)
		if bool(status["probed"]):
			_startup_models_checked = true
			EvoHudTopBar.refresh_decision_model_selectors(self)
			if not bool(status["connected"]):
				EvoHudBannersToasts.show_ollama_offline_popup(self)
			else:
				var missing: Array = status["missing_models"]
				if not missing.is_empty():
					_pending_missing_models.clear()
					for m in missing:
						_pending_missing_models.append(str(m))
					EvoHudBannersToasts.show_missing_models_popup(self, _pending_missing_models)
				else:
					_set_startup_blocked(false)

	if _pull_in_progress and _missing_models_modal != null and _missing_models_modal.visible:
		var pull_st := EvoOllamaClient.get_pull_state()
		if bool(pull_st["running"]):
			_missing_models_progress_bar.value = float(pull_st["percent"])
			_missing_models_status_lbl.text = str(pull_st["status_text"])
		elif bool(pull_st["done"]):
			_pull_in_progress = false
			_set_startup_blocked(false)
			_missing_models_modal.visible = false
			_apply_decision_models_update()
		elif bool(pull_st["failed"]):
			_pull_in_progress = false
			_missing_models_download_btn.disabled = false
			_missing_models_status_lbl.text = EvoUiStyle.tr_text(
				_lang,
				"⚠️ Error al descargar los modelos desde Ollama.",
				"⚠️ Failed to download models from Ollama."
			)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if get_viewport() != null and get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if _ollama_startup_blocked or (_missing_models_modal != null and _missing_models_modal.visible):
		return
	if (notebook_modal != null and notebook_modal.visible) or (tree_modal != null and tree_modal.visible) or (lab_modal != null and lab_modal.visible):
		return
	if ke.keycode == KEY_TAB:
		_on_lens_cycle_btn_pressed()
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	var slot_idx := -1
	match ke.keycode:
		KEY_1, KEY_KP_1:
			slot_idx = 0
		KEY_2, KEY_KP_2:
			slot_idx = 1
		KEY_3, KEY_KP_3:
			slot_idx = 2
		KEY_4, KEY_KP_4:
			slot_idx = 3
		KEY_5, KEY_KP_5:
			slot_idx = 4
		KEY_6, KEY_KP_6:
			slot_idx = 5
		KEY_7, KEY_KP_7:
			slot_idx = 6
		KEY_8, KEY_KP_8:
			slot_idx = 7
		KEY_9, KEY_KP_9:
			slot_idx = 8
		KEY_0, KEY_KP_0:
			slot_idx = 9
	if slot_idx >= 0:
		_on_hotbar_slot_pressed(slot_idx)
		if get_viewport() != null and ke.keycode != KEY_0 and ke.keycode != KEY_KP_0:
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	EvoHudTopBar.build_top_left_valley_sign_and_medallions(self)
	EvoHudStatsStrip.build_stats_strip(self)
	EvoHudTopBar.build_top_right_clock(self)
	EvoHudTopBar.build_settings_popup(self)
	EvoHudHotbarDock.build_bottom_hotbar(self)
	EvoHudHotbarDock.build_legend_panel(self)
	EvoHudInspectorPanel.build_right_scroll_inspector(self)
	EvoHudBannersToasts.build_banners_and_toasts(self)
	EvoHudBannersToasts.build_event_feed_panel(self)
	_build_modals()
	_update_static_labels()
	_rebuild_sub_tool_options()
	_rebuild_legend_content()


func _build_modals() -> void:
	notebook_modal = EvoNotebookModal.new()
	notebook_modal.visible = false
	notebook_modal.z_index = 40
	notebook_modal.jump_to_hex_requested.connect(_on_modal_jump_to_hex)
	add_child(notebook_modal)

	tree_modal = EvoTreeModal.new()
	tree_modal.visible = false
	tree_modal.z_index = 40
	tree_modal.lineage_highlight_requested.connect(_on_lineage_highlight_from_modal)
	add_child(tree_modal)

	lab_modal = EvoLabModal.new()
	lab_modal.visible = false
	lab_modal.z_index = 40
	lab_modal.catalog_item_saved.connect(_on_lab_item_saved)
	lab_modal.inject_trait_requested.connect(_on_lab_inject_trait)
	add_child(lab_modal)


func setup(world_state: EvoTypes.WorldState, lang: String = "es") -> void:
	if _preset_option == null:
		_ready()
	_lang = lang
	set_world_state(world_state)
	_update_static_labels()
	refresh(world_state)


func set_world_state(world_state: EvoTypes.WorldState) -> void:
	_world_state = world_state
	_last_shown_macro_outcome = ""
	if _milestone_banner != null:
		_milestone_banner.visible = false
	if _world_state != null:
		refresh_strategies(_world_state, _lang)
		if _selected_deme_id == "" or not _world_state.demes.has(_selected_deme_id):
			if not _world_state.demes.is_empty():
				var first_id := str(_world_state.demes.keys()[0])
				_selected_deme_id = first_id
				var d: EvoTypes.Deme = _world_state.demes[first_id]
				_selected_hex_id = d.hex_id
			else:
				_selected_deme_id = ""
		if not _world_state.cells.has(_selected_hex_id) and not _world_state.cells.is_empty():
			_selected_hex_id = str(_world_state.cells.keys()[0])
	refresh(_world_state)


func refresh(world_state: EvoTypes.WorldState = null, is_playing_override: Variant = null) -> void:
	if world_state != null:
		_world_state = world_state
	if is_playing_override is bool:
		_is_playing = bool(is_playing_override)
	if _world_state == null:
		return

	if _world_state.macro_outcome_type == "":
		_last_shown_macro_outcome = ""
	elif _world_state.macro_outcome_type != _last_shown_macro_outcome:
		_last_shown_macro_outcome = _world_state.macro_outcome_type
		show_milestone_banner(_world_state.macro_outcome_title, _world_state.macro_outcome_summary, true)

	EvoHudStatsStrip.refresh_stats_strip(self)
	EvoHudBannersToasts.refresh_event_feed(self)
	_update_top_bar_state()
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()
	if _legend_panel != null and _legend_panel.visible:
		_rebuild_legend_content()
	_update_hotbar_visuals()

	if notebook_modal != null and notebook_modal.visible:
		notebook_modal.refresh(_world_state)
	if tree_modal != null and tree_modal.visible:
		tree_modal.refresh(_world_state)
	if lab_modal != null and lab_modal.visible:
		lab_modal.refresh(_world_state, _selected_deme_id)


func refresh_inspector_only(state: EvoTypes.WorldState = null) -> void:
	if state != null:
		_world_state = state
	if _world_state == null:
		return
	_update_top_bar_state()
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()


func refresh_strategies(state: EvoTypes.WorldState, lang: String = "es") -> void:
	EvoHudTopBar.refresh_strategies_for_hud(self, state, lang)


func _rebuild_active_inspector_sheet() -> void:
	if _inspector_minimized:
		return
	if _inspector_tab == "habitat":
		_rebuild_hex_sheet()
	else:
		_rebuild_deme_sheet()


func select_hex(hex_id: String) -> void:
	_selected_hex_id = hex_id
	if _world_state != null and _world_state.cells.has(hex_id):
		var cell: EvoTypes.HexCell = _world_state.cells[hex_id]
		if not cell.deme_ids.is_empty():
			if not cell.deme_ids.has(_selected_deme_id):
				_selected_deme_id = cell.deme_ids[0]
			if _inspector_tab == "habitat":
				_set_inspector_tab("deme")
		else:
			_selected_deme_id = ""
			_set_inspector_tab("habitat")
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()


func select_deme(deme_id: String) -> void:
	if _world_state == null or not _world_state.demes.has(deme_id):
		return
	_selected_deme_id = deme_id
	var d: EvoTypes.Deme = _world_state.demes[deme_id]
	_selected_hex_id = d.hex_id
	if _inspector_minimized:
		_on_toggle_inspector_minimize()
	if _inspector_tab == "habitat":
		_set_inspector_tab("deme")
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()


func set_playing_state(is_playing: bool) -> void:
	_is_playing = is_playing
	_update_static_labels()


func set_language(lang: String) -> void:
	_lang = lang
	refresh_strategies(_world_state, _lang)
	_update_static_labels()
	_rebuild_sub_tool_options()
	_rebuild_legend_content()
	if notebook_modal != null:
		notebook_modal.set_language(_lang)
	if tree_modal != null:
		tree_modal.set_language(_lang)
	if lab_modal != null:
		lab_modal.set_language(_lang)
	refresh(_world_state)


func get_active_tool() -> String:
	return _active_tool


func get_active_sub_mode() -> String:
	return _active_sub_mode


func get_brush_radius() -> int:
	return _brush_radius


func open_notebook_modal() -> void:
	notebook_modal.open_modal(_world_state, _lang)


func open_tree_modal(lineage_id: String = "") -> void:
	var target_lin := lineage_id
	if target_lin == "" and _world_state != null and _world_state.demes.has(_selected_deme_id):
		var d: EvoTypes.Deme = _world_state.demes[_selected_deme_id]
		target_lin = d.lineage_id
	tree_modal.open_modal(_world_state, _lang, target_lin)


func open_lab_modal() -> void:
	lab_modal.open_modal(_world_state, _lang, _selected_deme_id)


func show_milestone_banner(title: String, summary: String, is_macro: bool = false) -> void:
	EvoHudBannersToasts.show_milestone_banner(self, title, summary, is_macro)


func _update_static_labels() -> void:
	EvoHudTopBar.update_static_labels(self)
	_update_hotbar_visuals()


func _update_top_bar_state() -> void:
	EvoHudTopBar.update_top_bar_state(self)


func _update_hotbar_visuals() -> void:
	EvoHudHotbarDock.update_hotbar_visuals(self)


func _rebuild_sub_tool_options() -> void:
	EvoHudHotbarDock.rebuild_sub_tool_options(self)


func _rebuild_legend_content() -> void:
	EvoHudHotbarDock.rebuild_legend_content(self)


func _rebuild_villages_list() -> void:
	EvoHudInspectorPanel.rebuild_villages_list(self)


func _rebuild_deme_sheet() -> void:
	EvoHudInspectorPanel.rebuild_deme_sheet(self)


func _rebuild_hex_sheet() -> void:
	EvoHudInspectorPanel.rebuild_hex_sheet(self)


func _build_deme_relations_lines(d: EvoTypes.Deme) -> Array[Dictionary]:
	return EvoHudInspectorPanel.build_deme_relations_lines(_world_state, _lang, d)


func _on_strategy_option_selected(_index: int) -> void:
	if _suppress_strategy_signal or strategy_a_option == null or strategy_b_option == null:
		return
	var sel_a := maxi(0, strategy_a_option.selected)
	var sel_b := maxi(0, strategy_b_option.selected)
	var strat_a_id := str(strategy_a_option.get_item_metadata(sel_a)) if strategy_a_option.item_count > 0 else EvoCatalog.DEFAULT_STRATEGY_A_ID
	var strat_b_id := str(strategy_b_option.get_item_metadata(sel_b)) if strategy_b_option.item_count > 0 else EvoCatalog.DEFAULT_STRATEGY_B_ID
	matchup_changed.emit(strat_a_id, strat_b_id)


func _on_matchup_reset_pressed() -> void:
	matchup_reset_requested.emit()


func _on_village_selector_item_selected(index: int) -> void:
	if _village_selector_opt == null or index < 0 or index >= _village_selector_opt.item_count:
		return
	var deme_id := str(_village_selector_opt.get_item_metadata(index))
	if deme_id != "" and _world_state != null and _world_state.demes.has(deme_id):
		var d: EvoTypes.Deme = _world_state.demes[deme_id]
		_on_village_list_item_pressed(d.id, d.hex_id)


func _on_village_cycle_pressed(step: int) -> void:
	if _village_selector_opt == null or _village_selector_opt.item_count <= 1:
		return
	var cur := maxi(0, _village_selector_opt.selected)
	var next_idx := posmod(cur + step, _village_selector_opt.item_count)
	_village_selector_opt.select(next_idx)
	_on_village_selector_item_selected(next_idx)


func _inject_trait_into_deme(deme_id: String, trait_id: String) -> void:
	if _world_state != null:
		EvoCatalog.inject_trait_into_deme(_world_state, deme_id, trait_id, _lang)
	inject_trait_requested.emit(deme_id, trait_id)
	refresh(_world_state)


func _set_inspector_tab(tab_id: String) -> void:
	_inspector_tab = tab_id
	if _deme_sheet_vbox != null:
		_deme_sheet_vbox.visible = (_inspector_tab == "deme")
	if _traits_sheet_vbox != null:
		_traits_sheet_vbox.visible = (_inspector_tab == "traits")
	if _hex_sheet_vbox != null:
		_hex_sheet_vbox.visible = (_inspector_tab == "habitat")
	_update_static_labels()


func _on_inspector_tab_pressed(tab_id: String) -> void:
	_set_inspector_tab(tab_id)
	_rebuild_active_inspector_sheet()


func _on_toggle_inspector_minimize() -> void:
	_inspector_minimized = not _inspector_minimized
	_inspector_body_vbox.visible = not _inspector_minimized
	_inspector_minimize_btn.text = "▸" if _inspector_minimized else "▾"
	_inspector_frame.offset_bottom = 228 if _inspector_minimized else 865
	if not _inspector_minimized:
		_rebuild_active_inspector_sheet()


func _on_header_highlight_pressed() -> void:
	if _world_state != null and _world_state.demes.has(_selected_deme_id):
		var d: EvoTypes.Deme = _world_state.demes[_selected_deme_id]
		_on_toggle_highlight_lineage(d.lineage_id)


func _on_hotbar_slot_pressed(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= HOTBAR_SLOTS_DEF.size():
		return
	var def: Dictionary = HOTBAR_SLOTS_DEF[slot_idx]
	_active_tool = str(def["tool"])
	var sub := str(def["sub"])
	if sub != "":
		_active_sub_mode = sub
	_update_static_labels()
	_rebuild_sub_tool_options()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_lens_cycle_btn_pressed() -> void:
	var order := ["biome", "food", "health", "diplomacy", "territory"]
	var next_idx := (order.find(_active_lens) + 1) % order.size()
	_on_lens_pressed(str(order[next_idx]))


func _on_preset_selected(index: int) -> void:
	var preset_id := str(_preset_option.get_item_metadata(index))
	preset_selected.emit(preset_id)


func _on_export_pressed() -> void:
	if _world_state != null:
		var json_str := JSON.stringify(_world_state.to_dict(), "\t")
		var f := FileAccess.open(DEFAULT_EXPORT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(json_str)
			f.close()
		show_milestone_banner(
			EvoUiStyle.tr_text(_lang, "Mundo Exportado (JSON)", "World Exported (JSON)"),
			EvoUiStyle.tr_text(_lang, "Guardado en %s" % DEFAULT_EXPORT_PATH, "Saved to %s" % DEFAULT_EXPORT_PATH),
			false
		)


func _on_import_pressed() -> void:
	if FileAccess.file_exists(DEFAULT_EXPORT_PATH):
		var f := FileAccess.open(DEFAULT_EXPORT_PATH, FileAccess.READ)
		if f != null:
			var raw := f.get_as_text()
			f.close()
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				var imported := EvoTypes.WorldState.from_dict(parsed)
				set_world_state(imported)
				state_imported.emit(imported)


func _on_play_pressed() -> void:
	if _ollama_startup_blocked or (_missing_models_modal != null and _missing_models_modal.visible):
		return
	_is_playing = not _is_playing
	_update_static_labels()
	play_pause_toggled.emit(_is_playing)


func _on_step_pressed() -> void:
	if _ollama_startup_blocked or (_missing_models_modal != null and _missing_models_modal.visible):
		return
	step_generation_requested.emit()


func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % 3
	_update_static_labels()
	speed_changed.emit(_speed_index)


func _on_tree_btn_pressed() -> void:
	open_tree_modal()


func _on_settings_btn_pressed() -> void:
	_settings_popup.visible = not _settings_popup.visible
	if _settings_popup.visible:
		EvoDecisionModel.check_ollama_status(true)
		EvoHudTopBar.refresh_decision_model_selectors(self)


func _on_primary_model_selected(index: int) -> void:
	if _primary_model_opt == null or index < 0 or index >= _primary_model_opt.item_count:
		return
	var selected_tag := str(_primary_model_opt.get_item_metadata(index))
	if selected_tag == "" or selected_tag == EvoUserSettings.primary_model:
		return
	EvoUserSettings.primary_model = selected_tag
	EvoUserSettings.save_settings()
	_apply_decision_models_update()


func _on_secondary_model_selected(index: int) -> void:
	if _secondary_model_opt == null or index < 0 or index >= _secondary_model_opt.item_count:
		return
	var selected_tag := str(_secondary_model_opt.get_item_metadata(index))
	if selected_tag == "" or selected_tag == EvoUserSettings.secondary_model:
		return
	EvoUserSettings.secondary_model = selected_tag
	EvoUserSettings.save_settings()
	_apply_decision_models_update()


func _on_refresh_models_pressed() -> void:
	EvoOllamaClient.refresh_ollama_status_async()
	EvoHudTopBar.refresh_decision_model_selectors(self)
	_update_top_bar_state()


func _on_context_window_submitted(new_text: String) -> void:
	_commit_context_window_text(new_text)
	if _context_window_input != null:
		_context_window_input.release_focus()


func _on_context_window_focus_exited() -> void:
	if _context_window_input != null:
		_commit_context_window_text(_context_window_input.text)


func _commit_context_window_text(raw_text: String) -> void:
	var trimmed := raw_text.strip_edges()
	if trimmed.is_valid_int():
		var val := int(trimmed)
		if val > 0 and val != EvoUserSettings.context_length:
			EvoUserSettings.context_length = val
			EvoUserSettings.save_settings()
			EvoOllamaClient.clear_cache()
			if _world_state != null:
				EvoDecisionModel.evaluate_all_demes(_world_state, _lang)
			_update_top_bar_state()
	if _context_window_input != null:
		_context_window_input.text = str(EvoUserSettings.context_length)


func _apply_decision_models_update() -> void:
	EvoOllamaClient.clear_cache()
	EvoDecisionModel.check_ollama_status(true)
	if _world_state != null:
		EvoDecisionModel.reassign_world_models(_world_state)
		EvoDecisionModel.evaluate_all_demes(_world_state, _lang)
	_update_static_labels()
	refresh(_world_state)
	decision_models_changed.emit()


func _on_missing_models_download_pressed() -> void:
	if _pending_missing_models.is_empty():
		_missing_models_modal.visible = false
		return
	_pull_in_progress = true
	_missing_models_download_btn.disabled = true
	_missing_models_progress_bar.visible = true
	_missing_models_progress_bar.value = 0.0
	_missing_models_status_lbl.visible = true
	_missing_models_status_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"Iniciando descarga desde Ollama...",
		"Starting download from Ollama..."
	)
	EvoOllamaClient.start_pull_models(_pending_missing_models)


func _on_missing_models_skip_pressed() -> void:
	if _pull_in_progress:
		EvoOllamaClient.cancel_pull()
		_pull_in_progress = false
	if _missing_models_modal != null:
		_missing_models_modal.visible = false
	quit_requested.emit()


func _on_lang_selected(lang: String) -> void:
	set_language(lang)
	language_changed.emit(lang)


func _on_settings_toggled(_pressed: bool) -> void:
	var ap := _auto_pause_check.button_pressed
	var up := _unlimited_pressure_check.button_pressed
	var fs := _free_sandbox_check.button_pressed
	if _world_state != null:
		_world_state.auto_pause_on_milestone = ap
		_world_state.unlimited_pressure_mode = up
		_world_state.free_sandbox_mode = fs
		_update_top_bar_state()
	settings_changed.emit(ap, up, fs)


func _on_cam_preset_pressed(action: String, val: float) -> void:
	camera_preset_requested.emit(action, val)


func _on_tool_button_pressed(tool_id: String) -> void:
	_active_tool = tool_id
	if tool_id == "set_biome" and not EvoTypes.BIOMES.has(_active_sub_mode):
		_active_sub_mode = "savanna"
	elif tool_id == "adjust_altitude" and not (_active_sub_mode in ["raise", "lower"]):
		_active_sub_mode = "raise"
	elif tool_id == "adjust_carrying_capacity" and not (_active_sub_mode in ["enrich", "deplete"]):
		_active_sub_mode = "enrich"
	_update_static_labels()
	_rebuild_sub_tool_options()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_sub_mode_selected(sub_mode: String) -> void:
	_active_sub_mode = sub_mode
	_rebuild_sub_tool_options()
	_update_hotbar_visuals()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_sea_level_btn_pressed(delta: float) -> void:
	sea_level_change_requested.emit(delta)


func _on_brush_radius_pressed(rad: int) -> void:
	_brush_radius = rad
	_update_static_labels()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_lens_pressed(lens_id: String) -> void:
	_active_lens = lens_id
	_update_static_labels()
	if _legend_panel != null and _legend_panel.visible:
		_rebuild_legend_content()
	lens_changed.emit(_active_lens)


func _on_legend_toggle_pressed() -> void:
	_legend_panel.visible = not _legend_panel.visible
	if _legend_panel.visible:
		_rebuild_legend_content()
	_update_static_labels()


func _on_village_list_item_pressed(deme_id: String, hex_id: String) -> void:
	select_deme(deme_id)
	deme_selected.emit(deme_id, hex_id)


func _on_toggle_highlight_lineage(lineage_id: String) -> void:
	if _highlighted_lineage_id == lineage_id:
		_highlighted_lineage_id = ""
	else:
		_highlighted_lineage_id = lineage_id
	_rebuild_deme_sheet()
	lineage_highlight_requested.emit(_highlighted_lineage_id)


func _on_modal_jump_to_hex(hex_id: String, deme_id: String) -> void:
	if deme_id != "" and _world_state != null and _world_state.demes.has(deme_id):
		select_deme(deme_id)
	else:
		select_hex(hex_id)
	hex_jump_requested.emit(hex_id, deme_id)


func _on_lineage_highlight_from_modal(lineage_id: String) -> void:
	_highlighted_lineage_id = lineage_id
	_rebuild_deme_sheet()
	lineage_highlight_requested.emit(lineage_id)


func _on_lab_item_saved(item_type: String, item_data: Dictionary) -> void:
	refresh_strategies(_world_state, _lang)
	refresh(_world_state)
	catalog_item_saved.emit(item_type, item_data)


func _on_lab_inject_trait(deme_id: String, trait_id: String) -> void:
	_inject_trait_into_deme(deme_id, trait_id)
