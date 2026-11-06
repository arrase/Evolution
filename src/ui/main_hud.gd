class_name EvoMainHud
extends Control

signal preset_selected(preset_id: String)
signal export_json_requested(file_path: String)
signal import_json_requested(file_path: String)
signal state_imported(new_state: EvoTypes.WorldState)
signal play_pause_toggled(is_playing: bool)
signal step_generation_requested()
signal speed_changed(is_fast: bool)
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

const PRESET_LIST: Array[String] = EvoHudTopBar.PRESET_LIST
const DEFAULT_EXPORT_PATH: String = "user://evolution_world_state.json"
const HOTBAR_SLOTS_DEF: Array[Dictionary] = EvoHudHotbarDock.HOTBAR_SLOTS_DEF

var _world_state: EvoTypes.WorldState = null
var _lang: String = "es"
var _is_playing: bool = false
var _is_fast: bool = false

var _active_tool: String = "inspect"
var _active_sub_mode: String = "savanna"
var _brush_radius: int = 1
var _active_lens: String = "biome"

var _selected_hex_id: String = "0,0"
var _selected_deme_id: String = ""
var _highlighted_lineage_id: String = ""
var _last_seen_chronicle_count: int = 0

var _step_1_done: bool = false
var _step_2_done: bool = false
var _step_3_done: bool = false

# Top-Left Valley Sign, Artifacts & Living Village Medallions
var _preset_option: OptionButton
var _export_btn: Button
var _import_btn: Button
var _notebook_btn: Button
var _tree_btn: Button
var _lab_btn: Button
var _lens_cycle_btn: Button
var _lens_strip_panel: PanelContainer
var _lens_buttons: Dictionary = {} # lens_id -> Button
var _legend_toggle_btn: Button
var _legend_panel: PanelContainer
var _legend_vbox: VBoxContainer
var _villages_title_lbl: Label
var _villages_list_vbox: VBoxContainer
var _village_buttons_pool: Array[Button] = []
var _empty_villages_lbl: Label
var _last_hotbar_visual_key: String = ""

# Top-Right Stardew Clock & Cognitive Engine Widget
var _season_portrait: EvoHudTopBar.SeasonTidePortrait
var _season_icon: TextureRect
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

# Bottom-Center 10-Slot Stardew Inventory Hotbar
var _hotbar_slot_buttons: Array[Button] = []
var _tool_buttons: Dictionary = {} # tool_id -> Button
var _equipped_tool_banner: PanelContainer
var _equipped_tool_lbl: Label
var _sub_options_panel: PanelContainer
var _sub_options_flow: HFlowContainer
var _radius_1_btn: Button
var _radius_2_btn: Button

# Right Floating Parchment Scroll Inspector (`StardewScrollInspector`)
var _inspector_frame: PanelContainer
var _inspector_body_vbox: VBoxContainer
var _inspector_minimized: bool = false
var _inspector_minimize_btn: Button
var _inspector_tab: String = "deme" # "deme" | "traits" | "habitat"
var _village_prev_btn: Button
var _village_selector_opt: OptionButton
var _village_next_btn: Button
var _inspector_header_swatch: ColorRect
var _inspector_header_title: Label
var _inspector_header_hl_btn: Button
var _inspector_model_badge_lbl: Label
var _tab_deme_btn: Button
var _tab_traits_btn: Button
var _tab_habitat_btn: Button
var _inspector_scroll: ScrollContainer
var _deme_sheet_vbox: VBoxContainer
var _traits_sheet_vbox: VBoxContainer
var _hex_sheet_vbox: VBoxContainer

# Banners, Toasts & First Steps
var _milestone_banner: PanelContainer
var _banner_title_lbl: Label
var _banner_summary_lbl: Label
var _toast_vbox: VBoxContainer
var _first_steps_panel: PanelContainer
var _step1_lbl: Label
var _step2_lbl: Label
var _step3_lbl: Label
var _missing_models_modal: PanelContainer
var _missing_models_title_lbl: Label
var _missing_models_desc_lbl: Label
var _missing_models_progress_bar: ProgressBar
var _missing_models_status_lbl: Label
var _missing_models_download_btn: Button
var _missing_models_skip_btn: Button
var _startup_models_checked: bool = false
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
	theme = EvoStardewStyle.get_theme()
	_build_ui()
	set_process(true)
	set_process_unhandled_key_input(true)


func _process(delta: float) -> void:
	EvoHudBannersToasts.process_toasts(_toast_vbox, delta)
	_poll_ollama_startup_and_download()


func _poll_ollama_startup_and_download() -> void:
	if not _startup_models_checked:
		var status := EvoDecisionModel.check_ollama_status(false)
		if bool(status["probed"]):
			_startup_models_checked = true
			EvoHudTopBar.refresh_decision_model_selectors(self)
			var missing: Array = status["missing_models"]
			if not missing.is_empty():
				_pending_missing_models.clear()
				for m in missing:
					_pending_missing_models.append(str(m))
				EvoHudBannersToasts.show_missing_models_popup(self, _pending_missing_models)

	if _pull_in_progress and _missing_models_modal != null and _missing_models_modal.visible:
		var pull_st := EvoOllamaClient.get_pull_state()
		if bool(pull_st["running"]):
			_missing_models_progress_bar.value = float(pull_st["percent"])
			_missing_models_status_lbl.text = str(pull_st["status_text"])
		elif bool(pull_st["done"]):
			_pull_in_progress = false
			_missing_models_modal.visible = false
			_apply_decision_models_update()
		elif bool(pull_st["failed"]):
			_pull_in_progress = false
			_missing_models_download_btn.disabled = false
			_missing_models_status_lbl.text = EvoStardewStyle.tr_text(
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
	if (notebook_modal != null and notebook_modal.visible) or (tree_modal != null and tree_modal.visible) or (lab_modal != null and lab_modal.visible):
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
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	EvoHudTopBar.build_top_left_valley_sign_and_medallions(self)
	EvoHudTopBar.build_top_right_stardew_clock(self)
	EvoHudTopBar.build_settings_popup(self)
	EvoHudHotbarDock.build_bottom_stardew_hotbar(self)
	EvoHudHotbarDock.build_legend_panel(self)
	EvoHudInspectorPanel.build_right_scroll_inspector(self)
	EvoHudBannersToasts.build_banners_and_toasts(self)
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
	if _milestone_banner != null:
		_milestone_banner.visible = false
	if _toast_vbox != null:
		for child in _toast_vbox.get_children():
			child.queue_free()
	if _world_state != null:
		_last_seen_chronicle_count = _world_state.chronicle.size()
		if _selected_deme_id == "" or not _world_state.demes.has(_selected_deme_id):
			if not _world_state.demes.is_empty():
				var first_id := str(_world_state.demes.keys()[0])
				_selected_deme_id = first_id
				var d: EvoTypes.Deme = _world_state.demes[first_id]
				_selected_hex_id = d.hex_id
		if not _world_state.cells.has(_selected_hex_id) and not _world_state.cells.is_empty():
			_selected_hex_id = str(_world_state.cells.keys()[0])
	refresh(_world_state)


func refresh(world_state: EvoTypes.WorldState = null) -> void:
	if world_state != null:
		_world_state = world_state
	if _world_state == null:
		return

	if _world_state.chronicle.size() > _last_seen_chronicle_count:
		for i in range(_last_seen_chronicle_count, _world_state.chronicle.size()):
			var entry: EvoTypes.ChronicleEntry = _world_state.chronicle[i]
			push_chronicle_toast(entry)
		_last_seen_chronicle_count = _world_state.chronicle.size()
	elif _world_state.chronicle.size() < _last_seen_chronicle_count:
		_last_seen_chronicle_count = _world_state.chronicle.size()

	if _world_state.macro_outcome_type != "":
		show_milestone_banner(_world_state.macro_outcome_title, _world_state.macro_outcome_summary, true)

	_update_top_bar_state()
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()
	_update_first_steps_labels()
	_update_hotbar_visuals()

	if notebook_modal != null and notebook_modal.visible:
		notebook_modal.refresh(_world_state)
	if tree_modal != null and tree_modal.visible:
		tree_modal.refresh(_world_state)
	if lab_modal != null and lab_modal.visible:
		lab_modal.refresh(_world_state, _selected_deme_id)


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
			_step_1_done = true
			if _inspector_tab == "habitat":
				_set_inspector_tab("deme")
		else:
			_selected_deme_id = ""
			_set_inspector_tab("habitat")
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()
	_update_first_steps_labels()


func select_deme(deme_id: String) -> void:
	if _world_state == null or not _world_state.demes.has(deme_id):
		return
	_selected_deme_id = deme_id
	var d: EvoTypes.Deme = _world_state.demes[deme_id]
	_selected_hex_id = d.hex_id
	_step_1_done = true
	if _inspector_minimized:
		_on_toggle_inspector_minimize()
	if _inspector_tab == "habitat":
		_set_inspector_tab("deme")
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()
	_update_first_steps_labels()


func set_playing_state(is_playing: bool) -> void:
	_is_playing = is_playing
	_update_static_labels()


func set_language(lang: String) -> void:
	_lang = lang
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


func mark_tool_used() -> void:
	_step_2_done = true
	_update_first_steps_labels()


func mark_generation_advanced() -> void:
	_step_3_done = true
	_update_first_steps_labels()


func get_active_tool() -> String:
	return _active_tool


func get_active_sub_mode() -> String:
	return _active_sub_mode


func get_brush_radius() -> int:
	return _brush_radius


func get_active_lens() -> String:
	return _active_lens


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


func push_chronicle_toast(entry: EvoTypes.ChronicleEntry) -> void:
	EvoHudBannersToasts.push_chronicle_toast(self, entry)


func _update_static_labels() -> void:
	EvoHudTopBar.update_static_labels(self)
	_update_hotbar_visuals()
	_update_first_steps_labels()


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


func _build_deme_relations_lines(d: EvoTypes.Deme) -> Array[String]:
	return EvoHudInspectorPanel.build_deme_relations_lines(_world_state, _lang, d)


func _update_first_steps_labels() -> void:
	EvoHudBannersToasts.update_first_steps_labels(self)


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
	_inspector_frame.offset_bottom = 204 if _inspector_minimized else 865
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
	if _active_tool != "inspect":
		_step_2_done = true
	_update_static_labels()
	_rebuild_sub_tool_options()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_lens_cycle_btn_pressed() -> void:
	var order := ["biome", "food", "health"]
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
			EvoStardewStyle.tr_text(_lang, "Mundo Exportado (JSON)", "World Exported (JSON)"),
			EvoStardewStyle.tr_text(_lang, "Guardado en %s" % DEFAULT_EXPORT_PATH, "Saved to %s" % DEFAULT_EXPORT_PATH),
			false
		)
	export_json_requested.emit(DEFAULT_EXPORT_PATH)


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
	import_json_requested.emit(DEFAULT_EXPORT_PATH)


func _on_play_pressed() -> void:
	_is_playing = not _is_playing
	if _is_playing:
		_step_3_done = true
	_update_static_labels()
	play_pause_toggled.emit(_is_playing)


func _on_step_pressed() -> void:
	_step_3_done = true
	_update_first_steps_labels()
	step_generation_requested.emit()


func _on_speed_pressed() -> void:
	_is_fast = not _is_fast
	_update_static_labels()
	speed_changed.emit(_is_fast)


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
	EvoOllamaClient._probe_ollama_status_sync()
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
	_missing_models_status_lbl.text = EvoStardewStyle.tr_text(
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
	elif tool_id != "inspect":
		_step_2_done = true
	_update_static_labels()
	_rebuild_sub_tool_options()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_sub_mode_selected(sub_mode: String) -> void:
	_active_sub_mode = sub_mode
	_step_2_done = true
	_rebuild_sub_tool_options()
	_update_hotbar_visuals()
	_update_first_steps_labels()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_sea_level_btn_pressed(delta: float) -> void:
	_step_2_done = true
	_update_first_steps_labels()
	sea_level_change_requested.emit(delta)


func _on_brush_radius_pressed(rad: int) -> void:
	_brush_radius = rad
	_update_static_labels()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_lens_pressed(lens_id: String) -> void:
	_active_lens = lens_id
	_update_static_labels()
	lens_changed.emit(_active_lens)


func _on_legend_toggle_pressed() -> void:
	_legend_panel.visible = not _legend_panel.visible
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
	refresh(_world_state)
	catalog_item_saved.emit(item_type, item_data)


func _on_lab_inject_trait(deme_id: String, trait_id: String) -> void:
	_inject_trait_into_deme(deme_id, trait_id)
