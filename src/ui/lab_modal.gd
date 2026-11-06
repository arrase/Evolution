class_name EvoLabModal
extends Control

signal catalog_item_saved(item_type: String, item_data: Dictionary)
signal inject_trait_requested(deme_id: String, trait_id: String)
signal modal_closed()

const SLIDER_KEYS: Array[String] = [
	"metabolic_cost",
	"extraction_efficiency",
	"ecological_impact",
	"spatial_mobility",
	"social_cohesion",
	"transmission_threshold"
]

var _world_state: EvoTypes.WorldState = null
var _lang: String = "es"
var _selected_deme_id: String = ""
var _active_tab: String = "biological" # "biological" | "cultural" | "decision"
var _editing_id: String = ""
var _updating_sliders: bool = false

var _title_label: Label
var _close_btn: Button
var _tab_bio_btn: Button
var _tab_cul_btn: Button
var _tab_dec_btn: Button
var _new_item_btn: Button
var _items_list_vbox: VBoxContainer

var _form_header_lbl: Label
var _name_lbl: Label
var _name_input: LineEdit
var _desc_lbl: Label
var _desc_input: LineEdit
var _culture_check: CheckBox
var _archetype_row: HBoxContainer
var _archetype_lbl: Label
var _archetype_option: OptionButton

var _slider_controls: Dictionary = {} # key -> HSlider
var _slider_title_labels: Dictionary = {} # key -> Label
var _slider_val_labels: Dictionary = {} # key -> Label

var _thermo_title_lbl: Label
var _thermo_metrics_lbl: Label
var _thermo_status_lbl: Label
var _auto_balance_btn: Button
var _save_btn: Button
var _inject_btn: Button
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
	frame.custom_minimum_size = Vector2(980, 650)
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

	# 3 Tabs bar
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(tabs_hbox)

	_tab_bio_btn = Button.new()
	_tab_bio_btn.pressed.connect(_on_tab_selected.bind("biological"))
	tabs_hbox.add_child(_tab_bio_btn)

	_tab_cul_btn = Button.new()
	_tab_cul_btn.pressed.connect(_on_tab_selected.bind("cultural"))
	tabs_hbox.add_child(_tab_cul_btn)

	_tab_dec_btn = Button.new()
	_tab_dec_btn.pressed.connect(_on_tab_selected.bind("decision"))
	tabs_hbox.add_child(_tab_dec_btn)

	# Content split: Catalog List (left) + Craft Form (right)
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(body_hbox)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(10, true))
	body_hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	_new_item_btn = Button.new()
	_new_item_btn.pressed.connect(_on_new_item_pressed)
	left_vbox.add_child(_new_item_btn)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(list_scroll)

	_items_list_vbox = VBoxContainer.new()
	_items_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_list_vbox.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_items_list_vbox)

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

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(name_row)

	_name_lbl = Label.new()
	_name_lbl.custom_minimum_size = Vector2(110, 0)
	name_row.add_child(_name_lbl)

	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_input)

	var desc_row := HBoxContainer.new()
	desc_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(desc_row)

	_desc_lbl = Label.new()
	_desc_lbl.custom_minimum_size = Vector2(110, 0)
	desc_row.add_child(_desc_lbl)

	_desc_input = LineEdit.new()
	_desc_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_row.add_child(_desc_input)

	_culture_check = CheckBox.new()
	form_vbox.add_child(_culture_check)

	_archetype_row = HBoxContainer.new()
	_archetype_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(_archetype_row)

	_archetype_lbl = Label.new()
	_archetype_lbl.custom_minimum_size = Vector2(110, 0)
	_archetype_row.add_child(_archetype_lbl)

	_archetype_option = OptionButton.new()
	_archetype_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archetype_row.add_child(_archetype_option)

	# 6 Sliders box
	var sliders_card := PanelContainer.new()
	sliders_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 10))
	form_vbox.add_child(sliders_card)

	var sliders_vbox := VBoxContainer.new()
	sliders_vbox.add_theme_constant_override("separation", 6)
	sliders_card.add_child(sliders_vbox)

	for s_key in SLIDER_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		sliders_vbox.add_child(row)

		var t_lbl := Label.new()
		t_lbl.custom_minimum_size = Vector2(210, 0)
		t_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(t_lbl)
		_slider_title_labels[s_key] = t_lbl

		var slider := HSlider.new()
		slider.min_value = 0.0 if s_key == "transmission_threshold" else -1.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = 0.20 if s_key == "transmission_threshold" else 0.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_slider_value_changed.bind(s_key))
		row.add_child(slider)
		_slider_controls[s_key] = slider

		var v_lbl := Label.new()
		v_lbl.custom_minimum_size = Vector2(54, 0)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(v_lbl)
		_slider_val_labels[s_key] = v_lbl

	# Live Thermodynamic Meter
	var thermo_card := PanelContainer.new()
	thermo_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#f4e2b8"), EvoUiStyle.COLOR_GOLD_BEVEL, 10))
	form_vbox.add_child(thermo_card)

	var thermo_vbox := VBoxContainer.new()
	thermo_vbox.add_theme_constant_override("separation", 6)
	thermo_card.add_child(thermo_vbox)

	var thermo_top := HBoxContainer.new()
	thermo_vbox.add_child(thermo_top)

	_thermo_title_lbl = Label.new()
	_thermo_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thermo_title_lbl.add_theme_font_size_override("font_size", 14)
	_thermo_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	thermo_top.add_child(_thermo_title_lbl)

	_auto_balance_btn = Button.new()
	_auto_balance_btn.pressed.connect(_on_auto_balance_pressed)
	thermo_top.add_child(_auto_balance_btn)

	_thermo_metrics_lbl = Label.new()
	_thermo_metrics_lbl.add_theme_font_size_override("font_size", 12)
	_thermo_metrics_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	thermo_vbox.add_child(_thermo_metrics_lbl)

	_thermo_status_lbl = Label.new()
	_thermo_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thermo_status_lbl.add_theme_font_size_override("font_size", 12)
	thermo_vbox.add_child(_thermo_status_lbl)

	# Bottom Actions
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 10)
	form_vbox.add_child(actions_hbox)

	_save_btn = Button.new()
	_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_btn.pressed.connect(_on_save_pressed)
	actions_hbox.add_child(_save_btn)

	_inject_btn = Button.new()
	_inject_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inject_btn.pressed.connect(_on_inject_pressed)
	actions_hbox.add_child(_inject_btn)

	_feedback_lbl = Label.new()
	_feedback_lbl.add_theme_font_size_override("font_size", 12)
	_feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	form_vbox.add_child(_feedback_lbl)

	_rebuild_archetype_options()
	_update_labels()
	_reset_form_for_new()


func open_modal(world_state: EvoTypes.WorldState, lang: String = "es", selected_deme_id: String = "") -> void:
	if _title_label == null:
		_ready()
	_world_state = world_state
	_lang = lang
	_selected_deme_id = selected_deme_id
	_feedback_lbl.text = ""
	visible = true
	_rebuild_archetype_options()
	if _editing_id == "":
		_reset_form_for_new()
	else:
		_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()


func refresh(world_state: EvoTypes.WorldState, selected_deme_id: String = "") -> void:
	_world_state = world_state
	if selected_deme_id != "":
		_selected_deme_id = selected_deme_id
	if visible:
		_rebuild_catalog_list()
		_update_thermodynamics_preview()


func set_language(lang: String) -> void:
	_lang = lang
	if _title_label == null:
		return
	_rebuild_archetype_options()
	if _editing_id == "":
		_reset_form_for_new()
	else:
		_update_labels()
	if visible:
		_rebuild_catalog_list()
		_update_thermodynamics_preview()


func close_modal() -> void:
	visible = false
	modal_closed.emit()


func _rebuild_archetype_options() -> void:
	if _archetype_option == null:
		return
	var prev_idx := maxi(0, _archetype_option.selected)
	_archetype_option.clear()
	for i in range(EvoTypes.ARCHETYPES.size()):
		var arch: String = EvoTypes.ARCHETYPES[i]
		_archetype_option.add_item(EvoUiStyle.get_archetype_label(arch, _lang), i)
		_archetype_option.set_item_metadata(i, arch)
	if prev_idx < _archetype_option.item_count:
		_archetype_option.select(prev_idx)


func _update_labels() -> void:
	if _title_label == null:
		return
	_title_label.text = EvoUiStyle.tr_text(
		_lang,
		"⚗️ Forja de Rasgos y Decisiones — Laboratorio Evolutivo",
		"⚗️ Trait & Decision Forge — Evolutionary Laboratory"
	)
	_close_btn.text = EvoUiStyle.tr_text(_lang, "✕ Cerrar", "✕ Close")
	_tab_bio_btn.text = EvoUiStyle.tr_text(_lang, "🧬 Rasgos Biológicos", "🧬 Biological Traits")
	_tab_cul_btn.text = EvoUiStyle.tr_text(_lang, "🔥 Tradiciones Culturales", "🔥 Cultural Traditions")
	_tab_dec_btn.text = EvoUiStyle.tr_text(_lang, "⚖️ Decisiones Conductuales", "⚖️ Behavioral Decisions")

	EvoUiStyle.apply_button_active(_tab_bio_btn, _active_tab == "biological")
	EvoUiStyle.apply_button_active(_tab_cul_btn, _active_tab == "cultural")
	EvoUiStyle.apply_button_active(_tab_dec_btn, _active_tab == "decision")

	_new_item_btn.text = EvoUiStyle.tr_text(_lang, "+ Crear Nuevo", "+ Create New")
	_name_lbl.text = EvoUiStyle.tr_text(_lang, "Nombre:", "Name:")
	_desc_lbl.text = EvoUiStyle.tr_text(_lang, "Descripción:", "Description:")
	_culture_check.text = EvoUiStyle.tr_text(
		_lang,
		"Habilita transmisión cultural (enablesCulturalTransmission)",
		"Enables cultural transmission (enablesCulturalTransmission)"
	)
	_archetype_lbl.text = EvoUiStyle.tr_text(_lang, "Arquetipo:", "Archetype:")

	_culture_check.visible = (_active_tab == "biological")
	_archetype_row.visible = (_active_tab == "decision")

	var slider_names_es := {
		"metabolic_cost": "Coste Metabólico (-1 a +1)",
		"extraction_efficiency": "Eficiencia de Extracción (-1 a +1)",
		"ecological_impact": "Impacto Ecológico (-1 a +1)",
		"spatial_mobility": "Movilidad Espacial (-1 a +1)",
		"social_cohesion": "Cohesión Social (-1 a +1)",
		"transmission_threshold": "Umbral de Transmisión (0 a +1)"
	}
	var slider_names_en := {
		"metabolic_cost": "Metabolic Cost (-1 to +1)",
		"extraction_efficiency": "Extraction Efficiency (-1 to +1)",
		"ecological_impact": "Ecological Impact (-1 to +1)",
		"spatial_mobility": "Spatial Mobility (-1 to +1)",
		"social_cohesion": "Social Cohesion (-1 to +1)",
		"transmission_threshold": "Transmission Threshold (0 to +1)"
	}
	for s_key in SLIDER_KEYS:
		var lbl: Label = _slider_title_labels[s_key]
		lbl.text = str(slider_names_en[s_key]) if _lang == "en" else str(slider_names_es[s_key])

	_thermo_title_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"⚖️ Medidor de Equilibrio Termodinámico en Vivo",
		"⚖️ Live Thermodynamic Balance Meter"
	)
	_auto_balance_btn.text = EvoUiStyle.tr_text(_lang, "Auto-Equilibrar Vector", "Auto-Balance Vector")
	_save_btn.text = EvoUiStyle.tr_text(_lang, "💾 Guardar en el Catálogo", "💾 Save to Catalog")
	_inject_btn.text = EvoUiStyle.tr_text(_lang, "💉 Inyectar en Aldea Seleccionada", "💉 Inject into Selected Village")
	_inject_btn.visible = (_active_tab != "decision")
	_inject_btn.disabled = (_selected_deme_id == "" or _world_state == null or not _world_state.demes.has(_selected_deme_id))

	if _editing_id == "":
		_form_header_lbl.text = EvoUiStyle.tr_text(_lang, "✨ Nuevo Elemento Experimental", "✨ New Experimental Item")
	else:
		_form_header_lbl.text = EvoUiStyle.tr_text(_lang, "🛠️ Editando: %s" % _editing_id, "🛠️ Editing: %s" % _editing_id)


func _rebuild_catalog_list() -> void:
	if _items_list_vbox == null:
		return
	for child in _items_list_vbox.get_children():
		child.queue_free()

	if _world_state == null:
		return

	if _active_tab == "decision":
		for dec_id in _world_state.decisions_catalog.keys():
			var dec: EvoTypes.DecisionDef = _world_state.decisions_catalog[dec_id]
			var btn := Button.new()
			btn.text = "%s [%s]" % [dec.name, dec.archetype]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			EvoUiStyle.apply_button_active(btn, _editing_id == dec.id)
			btn.pressed.connect(_on_catalog_decision_clicked.bind(dec.id))
			_items_list_vbox.add_child(btn)
	else:
		for t_id in _world_state.traits_catalog.keys():
			var t: EvoTypes.TraitDef = _world_state.traits_catalog[t_id]
			if t.category != _active_tab:
				continue
			var btn := Button.new()
			btn.text = t.name
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			EvoUiStyle.apply_button_active(btn, _editing_id == t.id)
			btn.pressed.connect(_on_catalog_trait_clicked.bind(t.id))
			_items_list_vbox.add_child(btn)


func _reset_form_for_new() -> void:
	_editing_id = ""
	_feedback_lbl.text = ""
	if _active_tab == "biological":
		_name_input.text = EvoUiStyle.tr_text(_lang, "Adaptación Metabólica", "Metabolic Adaptation")
		_desc_input.text = EvoUiStyle.tr_text(_lang, "Rasgo biológico experimental diseñado en el laboratorio.", "Experimental biological trait crafted in the lab.")
		_culture_check.button_pressed = false
		_set_vector_to_sliders(EvoTypes.BiophysicalVector.new(0.15, 0.30, 0.05, 0.20, 0.10, 0.20))
	elif _active_tab == "cultural":
		_name_input.text = EvoUiStyle.tr_text(_lang, "Tradición Artesanal", "Artisanal Tradition")
		_desc_input.text = EvoUiStyle.tr_text(_lang, "Práctica cultural transmitida socialmente entre generaciones.", "Socially transmitted cultural practice across generations.")
		_set_vector_to_sliders(EvoTypes.BiophysicalVector.new(0.20, 0.35, 0.15, 0.10, 0.35, 0.45))
	else:
		_name_input.text = EvoUiStyle.tr_text(_lang, "Estrategia Adaptativa", "Adaptive Strategy")
		_desc_input.text = EvoUiStyle.tr_text(_lang, "Patrón conductual colectivo evaluado por las aldeas.", "Collective behavioral pattern evaluated by villages.")
		_select_archetype("custom")
		_set_vector_to_sliders(EvoTypes.BiophysicalVector.new(0.20, 0.35, 0.10, 0.15, 0.20, 0.25))
	_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()


func _set_vector_to_sliders(vec: EvoTypes.BiophysicalVector) -> void:
	_updating_sliders = true
	(_slider_controls["metabolic_cost"] as HSlider).value = vec.metabolic_cost
	(_slider_controls["extraction_efficiency"] as HSlider).value = vec.extraction_efficiency
	(_slider_controls["ecological_impact"] as HSlider).value = vec.ecological_impact
	(_slider_controls["spatial_mobility"] as HSlider).value = vec.spatial_mobility
	(_slider_controls["social_cohesion"] as HSlider).value = vec.social_cohesion
	(_slider_controls["transmission_threshold"] as HSlider).value = vec.transmission_threshold
	_updating_sliders = false
	_refresh_slider_value_labels()


func _read_vector_from_sliders() -> EvoTypes.BiophysicalVector:
	return EvoTypes.BiophysicalVector.new(
		snappedf((_slider_controls["metabolic_cost"] as HSlider).value, 0.01),
		snappedf((_slider_controls["extraction_efficiency"] as HSlider).value, 0.01),
		snappedf((_slider_controls["ecological_impact"] as HSlider).value, 0.01),
		snappedf((_slider_controls["spatial_mobility"] as HSlider).value, 0.01),
		snappedf((_slider_controls["social_cohesion"] as HSlider).value, 0.01),
		snappedf((_slider_controls["transmission_threshold"] as HSlider).value, 0.01)
	)


func _refresh_slider_value_labels() -> void:
	for s_key in SLIDER_KEYS:
		var val: float = (_slider_controls[s_key] as HSlider).value
		var lbl: Label = _slider_val_labels[s_key]
		lbl.text = "%+.2f" % val if s_key != "transmission_threshold" else "%.2f" % val


func _update_thermodynamics_preview() -> void:
	if _thermo_metrics_lbl == null:
		return
	_refresh_slider_value_labels()
	var vec := _read_vector_from_sliders()
	var free_mode := _world_state.free_sandbox_mode if _world_state != null else false
	var eval_res := EvoUiStyle.evaluate_thermodynamics(vec, free_mode)
	var a_plus: float = float(eval_res["a_plus"])
	var c_actual: float = float(eval_res["c_actual"])
	var c_req: float = float(eval_res["c_req"])
	var is_bal: bool = bool(eval_res["is_balanced"])
	var bal_vec: EvoTypes.BiophysicalVector = eval_res["balanced_vector"]

	_thermo_metrics_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"Ventajas Positivas (A+): %.2f   |   Coste Actual (C_actual): %.2f   |   Coste Requerido (C_req): %.2f" % [a_plus, c_actual, c_req],
		"Positive Advantages (A+): %.2f   |   Actual Cost (C_actual): %.2f   |   Required Cost (C_req): %.2f" % [a_plus, c_actual, c_req]
	)

	if is_bal:
		_thermo_status_lbl.text = EvoUiStyle.tr_text(
			_lang,
			"✓ Cumple la Ley de Conservación Termodinámica (C_actual >= C_req).",
			"✓ Complies with the Law of Thermodynamic Conservation (C_actual >= C_req)."
		)
		_thermo_status_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	else:
		_thermo_status_lbl.text = EvoUiStyle.tr_text(
			_lang,
			"⚠ Exceso de ventaja sin coste: al guardar se auto-equilibrará a Coste Metabólico = %+.2f, Impacto Eco = %+.2f." % [bal_vec.metabolic_cost, bal_vec.ecological_impact],
			"⚠ Uncompensated advantage: saving will auto-balance to Metabolic Cost = %+.2f, Eco Impact = %+.2f." % [bal_vec.metabolic_cost, bal_vec.ecological_impact]
		)
		_thermo_status_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_AMBER_WARN)


func _select_archetype(archetype: String) -> void:
	for i in range(_archetype_option.item_count):
		if str(_archetype_option.get_item_metadata(i)) == archetype:
			_archetype_option.select(i)
			return


func _get_selected_archetype() -> String:
	var idx := _archetype_option.selected
	if idx >= 0 and idx < _archetype_option.item_count:
		return str(_archetype_option.get_item_metadata(idx))
	return "custom"


func _save_current_item_to_catalog() -> String:
	var raw_vec := _read_vector_from_sliders()
	var free_mode := _world_state.free_sandbox_mode if _world_state != null else false
	var final_vec := raw_vec if free_mode else EvoUiStyle.balance_vector(raw_vec)
	_set_vector_to_sliders(final_vec)
	_update_thermodynamics_preview()

	var clean_name := _name_input.text.strip_edges()
	if clean_name == "":
		clean_name = "Custom Item"
	var clean_desc := _desc_input.text.strip_edges()

	if _active_tab == "decision":
		var dec := EvoTypes.DecisionDef.new()
		dec.id = _editing_id if _editing_id != "" else "dec-custom-%d" % (Time.get_ticks_msec() % 100000)
		dec.name = clean_name
		dec.description = clean_desc
		dec.archetype = _get_selected_archetype()
		dec.vector = final_vec
		if _world_state != null and _world_state.decisions_catalog.has(dec.id):
			var prev_dec: EvoTypes.DecisionDef = _world_state.decisions_catalog[dec.id]
			dec.required_trait_ids = prev_dec.required_trait_ids.duplicate()
		if _world_state != null:
			_world_state.decisions_catalog[dec.id] = dec
		_editing_id = dec.id
		catalog_item_saved.emit("decision", dec.to_dict())
		_rebuild_catalog_list()
		_update_labels()
		return dec.id
	else:
		var tr := EvoTypes.TraitDef.new()
		var prefix := "bio" if _active_tab == "biological" else "cul"
		tr.id = _editing_id if _editing_id != "" else "%s-custom-%d" % [prefix, Time.get_ticks_msec() % 100000]
		tr.name = clean_name
		tr.description = clean_desc
		tr.category = _active_tab
		tr.origin = "custom"
		tr.vector = final_vec
		tr.enables_cultural_transmission = _culture_check.button_pressed if _active_tab == "biological" else false
		if _world_state != null and _world_state.traits_catalog.has(tr.id):
			var prev_tr: EvoTypes.TraitDef = _world_state.traits_catalog[tr.id]
			tr.mutually_exclusive_with = prev_tr.mutually_exclusive_with.duplicate()
		if _world_state != null:
			_world_state.traits_catalog[tr.id] = tr
		_editing_id = tr.id
		catalog_item_saved.emit("trait", tr.to_dict())
		_rebuild_catalog_list()
		_update_labels()
		return tr.id


func _on_tab_selected(tab_key: String) -> void:
	_active_tab = tab_key
	_reset_form_for_new()


func _on_new_item_pressed() -> void:
	_reset_form_for_new()


func _on_catalog_trait_clicked(trait_id: String) -> void:
	if _world_state == null or not _world_state.traits_catalog.has(trait_id):
		return
	var tr: EvoTypes.TraitDef = _world_state.traits_catalog[trait_id]
	_editing_id = tr.id
	_name_input.text = tr.name
	_desc_input.text = tr.description
	_culture_check.button_pressed = tr.enables_cultural_transmission
	_set_vector_to_sliders(tr.vector)
	_feedback_lbl.text = ""
	_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()


func _on_catalog_decision_clicked(decision_id: String) -> void:
	if _world_state == null or not _world_state.decisions_catalog.has(decision_id):
		return
	var dec: EvoTypes.DecisionDef = _world_state.decisions_catalog[decision_id]
	_editing_id = dec.id
	_name_input.text = dec.name
	_desc_input.text = dec.description
	_select_archetype(dec.archetype)
	_set_vector_to_sliders(dec.vector)
	_feedback_lbl.text = ""
	_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()


func _on_slider_value_changed(_val: float, _key: String) -> void:
	if _updating_sliders:
		return
	_update_thermodynamics_preview()


func _on_auto_balance_pressed() -> void:
	var vec := _read_vector_from_sliders()
	var balanced := EvoUiStyle.balance_vector(vec)
	_set_vector_to_sliders(balanced)
	_update_thermodynamics_preview()


func _on_save_pressed() -> void:
	var saved_id := _save_current_item_to_catalog()
	_feedback_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"✓ Guardado en el catálogo (%s)" % saved_id,
		"✓ Saved to catalog (%s)" % saved_id
	)


func _on_inject_pressed() -> void:
	if _active_tab == "decision" or _selected_deme_id == "":
		return
	var saved_id := _save_current_item_to_catalog()
	inject_trait_requested.emit(_selected_deme_id, saved_id)
	_feedback_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"💉 Rasgo '%s' inyectado en la aldea seleccionada." % _name_input.text,
		"💉 Trait '%s' injected into selected village." % _name_input.text
	)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_modal()
