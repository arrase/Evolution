class_name EvoLabModal
extends Control

signal catalog_item_saved(item_type: String, item_data: Dictionary)
signal inject_trait_requested(deme_id: String, trait_id: String)
signal strategy_saved(strategy_id: String)
signal strategy_assigned(slot: String, strategy_id: String)

const SLIDER_KEYS: Array[String] = [
	"metabolic_cost",
	"extraction_efficiency",
	"ecological_impact",
	"spatial_mobility",
	"social_cohesion",
	"transmission_threshold"
]

const STRATEGY_ICONS: Array[String] = [
	"🤝", "🧭", "⚖️", "⚔️", "🔬", "🛡️", "🌿", "🔥", "👑", "⚡"
]

const STRATEGY_SWATCH_COLORS: Array[String] = [
	"#10B981", "#3B82F6", "#F59E0B", "#EF4444", "#A855F7", "#EC4899", "#14B8A6", "#F97316"
]

var _world_state: EvoTypes.WorldState = null
var _lang: String = "es"
var _selected_deme_id: String = ""
var _current_tab: String = "strategy"
var _selected_id: String = ""
var _updating_sliders: bool = false
var _updating_strategy_checks: bool = false
var _custom_counter: int = 0

# Public controls required by HUD and test suite
var tab_strategy_btn: Button
var tab_bio_btn: Button
var tab_cul_btn: Button
var tab_dec_btn: Button
var item_list: VBoxContainer
var new_item_button: Button
var id_edit: LineEdit
var name_edit: LineEdit
var desc_edit: TextEdit
var enables_culture_check: CheckBox
var sliders: Dictionary = {}
var balance_bar: ProgressBar
var balance_status_label: Label
var auto_balance_button: Button
var save_item_button: Button
var inject_deme_option: OptionButton
var inject_button: Button

# Strategy-specific controls
var strategy_icon_option: OptionButton
var strategy_color_picker: ColorPickerButton
var strategy_traits_box: VBoxContainer
var strategy_trait_checks: Dictionary = {}
var strategy_vector_label: Label
var use_strategy_a_button: Button
var use_strategy_b_button: Button

# Internal layout & labels
var _title_label: Label
var _close_btn: Button
var _form_header_lbl: Label
var _id_lbl: Label
var _name_lbl: Label
var _desc_lbl: Label
var _archetype_row: HBoxContainer
var _archetype_lbl: Label
var _archetype_option: OptionButton

var _strategy_emblem_row: HBoxContainer
var _strategy_icon_lbl: Label
var _strategy_color_lbl: Label
var _strategy_traits_card: PanelContainer
var _strategy_traits_title_lbl: Label
var _strategy_vector_card: PanelContainer
var _strategy_vector_title_lbl: Label
var _strategy_matchup_row: HBoxContainer

var _sliders_card: PanelContainer
var _slider_title_labels: Dictionary = {}
var _slider_val_labels: Dictionary = {}
var _thermo_card: PanelContainer
var _thermo_title_lbl: Label
var _thermo_metrics_lbl: Label
var _inject_row: HBoxContainer
var _inject_deme_lbl: Label
var _feedback_lbl: Label


func _ready() -> void:
	if _title_label != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = EvoUiStyle.get_theme()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_modal()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.03, 0.01, 0.72)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1020, 680)
	frame.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(14))
	center.add_child(frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	frame.add_child(main_vbox)

	# Header
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_header_box(12, 8))
	main_vbox.add_child(header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_panel.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.pressed.connect(close_modal)
	header_hbox.add_child(_close_btn)

	# 4 Tabs bar
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(tabs_hbox)

	tab_strategy_btn = Button.new()
	tab_strategy_btn.pressed.connect(_switch_tab.bind("strategy"))
	tabs_hbox.add_child(tab_strategy_btn)

	tab_bio_btn = Button.new()
	tab_bio_btn.pressed.connect(_switch_tab.bind("biological"))
	tabs_hbox.add_child(tab_bio_btn)

	tab_cul_btn = Button.new()
	tab_cul_btn.pressed.connect(_switch_tab.bind("cultural"))
	tabs_hbox.add_child(tab_cul_btn)

	tab_dec_btn = Button.new()
	tab_dec_btn.pressed.connect(_switch_tab.bind("decision"))
	tabs_hbox.add_child(tab_dec_btn)

	# Body split: Left catalog list + Right editor
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(body_hbox)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(10, true))
	body_hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	new_item_button = Button.new()
	new_item_button.pressed.connect(_start_new_item)
	left_vbox.add_child(new_item_button)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(list_scroll)

	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 6)
	list_scroll.add_child(item_list)

	# Right panel: Editor Form
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(12, false))
	body_hbox.add_child(right_panel)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_scroll)

	var form_vbox := VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 8)
	right_scroll.add_child(form_vbox)

	_form_header_lbl = Label.new()
	_form_header_lbl.add_theme_font_size_override("font_size", 16)
	_form_header_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	form_vbox.add_child(_form_header_lbl)

	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(id_row)

	_id_lbl = Label.new()
	_id_lbl.custom_minimum_size = Vector2(110, 0)
	id_row.add_child(_id_lbl)

	id_edit = LineEdit.new()
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(id_edit)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(name_row)

	_name_lbl = Label.new()
	_name_lbl.custom_minimum_size = Vector2(110, 0)
	name_row.add_child(_name_lbl)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)

	var desc_row := HBoxContainer.new()
	desc_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(desc_row)

	_desc_lbl = Label.new()
	_desc_lbl.custom_minimum_size = Vector2(110, 0)
	desc_row.add_child(_desc_lbl)

	desc_edit = TextEdit.new()
	desc_edit.custom_minimum_size = Vector2(0, 56)
	desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	desc_row.add_child(desc_edit)

	EvoLabStrategyEditor.build_strategy_form(self, form_vbox)
	EvoLabThermoForm.build_thermo_form(self, form_vbox)

	# Bottom Actions
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 10)
	form_vbox.add_child(actions_hbox)

	save_item_button = Button.new()
	save_item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_item_button.pressed.connect(_save_current_item)
	actions_hbox.add_child(save_item_button)

	EvoLabStrategyEditor.build_matchup_and_inject_rows(self, form_vbox)

	_feedback_lbl = Label.new()
	_feedback_lbl.add_theme_font_size_override("font_size", 12)
	_feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	form_vbox.add_child(_feedback_lbl)

	_rebuild_archetype_options()
	_rebuild_strategy_trait_checks()
	_start_new_item()


func setup(state: EvoTypes.WorldState, lang: String = "es", selected_deme_id: String = "") -> void:
	if _title_label == null:
		_ready()
	_world_state = state
	_lang = lang
	if selected_deme_id != "":
		_selected_deme_id = selected_deme_id
	elif _world_state != null and not _world_state.demes.has(_selected_deme_id):
		_selected_deme_id = str(_world_state.demes.keys()[0]) if not _world_state.demes.is_empty() else ""
	_feedback_lbl.text = ""
	_rebuild_archetype_options()
	_rebuild_inject_deme_options()
	_rebuild_strategy_trait_checks()
	if _selected_id == "":
		_start_new_item()
	else:
		_load_selected_item_into_form()
		_update_labels()
		_rebuild_catalog_list()
		_update_thermodynamics_preview()
		_update_strategy_vector_preview()


func open_modal(world_state: EvoTypes.WorldState, lang: String = "es", selected_deme_id: String = "") -> void:
	setup(world_state, lang, selected_deme_id)
	visible = true


func refresh(world_state: EvoTypes.WorldState = null, selected_deme_id: String = "") -> void:
	if world_state != null:
		_world_state = world_state
	if selected_deme_id != "":
		_selected_deme_id = selected_deme_id
	if _title_label == null:
		return
	_rebuild_inject_deme_options()
	var checked_ids := _get_checked_strategy_trait_ids()
	_rebuild_strategy_trait_checks()
	_set_checked_strategy_trait_ids(checked_ids)
	_rebuild_catalog_list()
	_update_labels()
	_update_thermodynamics_preview()
	_update_strategy_vector_preview()


func set_language(lang: String) -> void:
	_lang = lang
	if _title_label == null:
		return
	_rebuild_archetype_options()
	_rebuild_inject_deme_options()
	var checked_ids := _get_checked_strategy_trait_ids()
	_rebuild_strategy_trait_checks()
	_set_checked_strategy_trait_ids(checked_ids)
	if _selected_id != "":
		_load_selected_item_into_form()
	_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()
	_update_strategy_vector_preview()


func close_modal() -> void:
	visible = false


func _switch_tab(tab: String) -> void:
	if _title_label == null:
		_ready()
	_current_tab = tab
	_start_new_item()


func _start_new_item() -> void:
	if _title_label == null:
		_ready()
	_selected_id = ""
	id_edit.text = ""
	_feedback_lbl.text = ""

	if _current_tab == "strategy":
		EvoLabStrategyEditor.init_new_strategy(self)
	else:
		EvoLabThermoForm.init_new_trait_or_decision(self)

	_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()
	_update_strategy_vector_preview()


func _save_current_item() -> void:
	if _title_label == null:
		_ready()
	var clean_name := name_edit.text.strip_edges()
	if clean_name == "":
		clean_name = "Custom Item"
	var clean_desc := desc_edit.text.strip_edges()

	if _current_tab == "strategy":
		EvoLabStrategyEditor.save_strategy(self, clean_name, clean_desc)
	else:
		EvoLabThermoForm.save_trait_or_decision(self, clean_name, clean_desc)


func _catalog_has_id(candidate: String) -> bool:
	if _world_state == null:
		return false
	return (
		_world_state.strategies_catalog.has(candidate)
		or _world_state.traits_catalog.has(candidate)
		or _world_state.decisions_catalog.has(candidate)
	)


func _next_custom_id(prefix: String) -> String:
	_custom_counter += 1
	var candidate := "%s-custom-%d" % [prefix, _custom_counter]
	while _catalog_has_id(candidate):
		_custom_counter += 1
		candidate = "%s-custom-%d" % [prefix, _custom_counter]
	return candidate


func _resolve_target_id(prefix: String) -> String:
	var manual_id := id_edit.text.strip_edges()
	if manual_id != "":
		return manual_id
	if _selected_id != "":
		return _selected_id
	return _next_custom_id(prefix)


func _show_saved_feedback(saved_id: String) -> void:
	_feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	_feedback_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"✓ Guardado en el catálogo (%s)" % saved_id,
		"✓ Saved to catalog (%s)" % saved_id
	)


func _update_labels() -> void:
	if _title_label == null:
		return
	var is_strat := (_current_tab == "strategy")

	_title_label.text = EvoUiStyle.tr_text(
		_lang,
		"⚗️ Forja de Estrategias, Rasgos y Decisiones — Laboratorio Evolutivo",
		"⚗️ Strategy, Trait & Decision Forge — Evolutionary Laboratory"
	)
	_close_btn.text = EvoUiStyle.tr_text(_lang, "✕ Cerrar", "✕ Close")
	tab_strategy_btn.text = EvoI18n.t(_lang, "lab_tab_strat")
	tab_bio_btn.text = EvoUiStyle.tr_text(_lang, "🧬 Rasgos Biológicos", "🧬 Biological Traits")
	tab_cul_btn.text = EvoUiStyle.tr_text(_lang, "🔥 Tradiciones Culturales", "🔥 Cultural Traditions")
	tab_dec_btn.text = EvoUiStyle.tr_text(_lang, "⚖️ Decisiones Conductuales", "⚖️ Behavioral Decisions")

	EvoUiStyle.apply_button_active(tab_strategy_btn, _current_tab == "strategy")
	EvoUiStyle.apply_button_active(tab_bio_btn, _current_tab == "biological")
	EvoUiStyle.apply_button_active(tab_cul_btn, _current_tab == "cultural")
	EvoUiStyle.apply_button_active(tab_dec_btn, _current_tab == "decision")

	new_item_button.text = EvoI18n.t(_lang, "lab_new_strat") if is_strat else EvoUiStyle.tr_text(_lang, "+ Crear Nuevo", "+ Create New")
	_id_lbl.text = "ID:"
	id_edit.placeholder_text = "strat-custom" if is_strat else "custom-id"
	_name_lbl.text = EvoUiStyle.tr_text(_lang, "Nombre:", "Name:")
	_desc_lbl.text = EvoUiStyle.tr_text(_lang, "Descripción:", "Description:")

	EvoLabStrategyEditor.refresh_strategy_and_inject_labels(self, is_strat)
	EvoLabThermoForm.refresh_thermo_labels(self, is_strat)

	save_item_button.text = EvoI18n.t(_lang, "lab_save_strat") if is_strat else EvoUiStyle.tr_text(_lang, "💾 Guardar en el Catálogo", "💾 Save to Catalog")

	if _selected_id == "":
		_form_header_lbl.text = EvoI18n.t(_lang, "lab_new_strat") if is_strat else EvoUiStyle.tr_text(_lang, "✨ Nuevo Elemento Experimental", "✨ New Experimental Item")
	else:
		_form_header_lbl.text = EvoUiStyle.tr_text(_lang, "🛠️ Editando: %s" % _selected_id, "🛠️ Editing: %s" % _selected_id)


func _rebuild_catalog_list() -> void:
	if item_list == null:
		return
	for child in item_list.get_children():
		child.queue_free()

	if _world_state == null:
		return

	if _current_tab == "strategy":
		for strat_id in _world_state.strategies_catalog.keys():
			var strat: EvoTypes.StrategyDef = _world_state.strategies_catalog[strat_id]
			var btn := Button.new()
			var trait_count := strat.biological_trait_ids.size() + strat.cultural_trait_ids.size()
			var strat_title := EvoI18n.strategy_name(_lang, strat)
			var traits_word := "traits" if _lang == "en" else "rasgos"
			btn.text = "%s %s (%d %s)" % [strat.icon, strat_title, trait_count, traits_word]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var accent_col := Color.from_string(strat.color, Color("#10B981"))
			var is_sel := (_selected_id == strat.id)
			var bg_col := EvoUiStyle.COLOR_BTN_ACTIVE_BG.lerp(accent_col, 0.25) if is_sel else EvoUiStyle.COLOR_BTN_NORMAL.lerp(accent_col, 0.16)
			var style_box := EvoUiStyle.make_button_style(bg_col, accent_col, 3 if is_sel else 2)
			btn.add_theme_stylebox_override("normal", style_box)
			btn.add_theme_stylebox_override("hover", EvoUiStyle.make_button_style(bg_col.lightened(0.08), accent_col, 3))
			btn.pressed.connect(_on_catalog_strategy_clicked.bind(strat.id))
			item_list.add_child(btn)
	elif _current_tab == "decision":
		for dec_id in _world_state.decisions_catalog.keys():
			var dec: EvoTypes.DecisionDef = _world_state.decisions_catalog[dec_id]
			var btn := Button.new()
			btn.text = "%s [%s]" % [EvoI18n.decision_name(_lang, dec), dec.archetype]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			EvoUiStyle.apply_button_active(btn, _selected_id == dec.id)
			btn.pressed.connect(_on_catalog_decision_clicked.bind(dec.id))
			item_list.add_child(btn)
	else:
		for t_id in _world_state.traits_catalog.keys():
			var t: EvoTypes.TraitDef = _world_state.traits_catalog[t_id]
			if t.category != _current_tab:
				continue
			var btn := Button.new()
			btn.text = EvoI18n.trait_name(_lang, t)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			EvoUiStyle.apply_button_active(btn, _selected_id == t.id)
			btn.pressed.connect(_on_catalog_trait_clicked.bind(t.id))
			item_list.add_child(btn)


func _load_selected_item_into_form() -> void:
	if _world_state == null or _selected_id == "":
		return
	if _current_tab == "strategy" and _world_state.strategies_catalog.has(_selected_id):
		_on_catalog_strategy_clicked(_selected_id)
	elif _current_tab == "decision" and _world_state.decisions_catalog.has(_selected_id):
		_on_catalog_decision_clicked(_selected_id)
	elif _world_state.traits_catalog.has(_selected_id):
		_on_catalog_trait_clicked(_selected_id)


func _rebuild_strategy_trait_checks() -> void:
	EvoLabStrategyEditor.rebuild_strategy_trait_checks(self)


func _on_strategy_trait_toggled(is_checked: bool, trait_id: String) -> void:
	EvoLabStrategyEditor.on_strategy_trait_toggled(self, is_checked, trait_id)


func _get_checked_strategy_trait_ids() -> Array[String]:
	return EvoLabStrategyEditor.get_checked_strategy_trait_ids(self)


func _set_checked_strategy_trait_ids(trait_ids: Array) -> void:
	EvoLabStrategyEditor.set_checked_strategy_trait_ids(self, trait_ids)


func _build_strategy_from_form() -> EvoTypes.StrategyDef:
	return EvoLabStrategyEditor.build_strategy_from_form(self)


func _update_strategy_vector_preview() -> void:
	EvoLabStrategyEditor.update_strategy_vector_preview(self)


func _on_use_strategy_slot_pressed(slot: String) -> void:
	EvoLabStrategyEditor.on_use_strategy_slot_pressed(self, slot)


func _on_catalog_strategy_clicked(strategy_id: String) -> void:
	EvoLabStrategyEditor.on_catalog_strategy_clicked(self, strategy_id)


func _rebuild_inject_deme_options() -> void:
	EvoLabStrategyEditor.rebuild_inject_deme_options(self)


func _on_inject_deme_option_selected(index: int) -> void:
	EvoLabStrategyEditor.on_inject_deme_option_selected(self, index)


func _on_inject_pressed() -> void:
	EvoLabStrategyEditor.on_inject_pressed(self)


func _auto_balance_vector() -> void:
	EvoLabThermoForm.auto_balance_vector(self)


func _rebuild_archetype_options() -> void:
	EvoLabThermoForm.rebuild_archetype_options(self)


func _on_catalog_trait_clicked(trait_id: String) -> void:
	EvoLabThermoForm.on_catalog_trait_clicked(self, trait_id)


func _on_catalog_decision_clicked(decision_id: String) -> void:
	EvoLabThermoForm.on_catalog_decision_clicked(self, decision_id)


func _set_vector_to_sliders(vec: EvoTypes.BiophysicalVector) -> void:
	EvoLabThermoForm.set_vector_to_sliders(self, vec)


func _read_vector_from_sliders() -> EvoTypes.BiophysicalVector:
	return EvoLabThermoForm.read_vector_from_sliders(self)


func _update_thermodynamics_preview() -> void:
	EvoLabThermoForm.update_thermodynamics_preview(self)


func _on_slider_value_changed(val: float, key: String) -> void:
	EvoLabThermoForm.on_slider_value_changed(self, val, key)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_modal()
