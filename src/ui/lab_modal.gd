class_name EvoLabModal
extends Control

signal catalog_item_saved(item_type: String, item_data: Dictionary)
signal inject_trait_requested(deme_id: String, trait_id: String)
signal strategy_saved(strategy_id: String)
signal strategy_assigned(slot: String, strategy_id: String)
signal modal_closed()

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

var _active_tab: String:
	get:
		return _current_tab
	set(value):
		_current_tab = value

var _editing_id: String:
	get:
		return _selected_id
	set(value):
		_selected_id = value

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

	# Strategy Emblem & Color row
	_strategy_emblem_row = HBoxContainer.new()
	_strategy_emblem_row.add_theme_constant_override("separation", 10)
	form_vbox.add_child(_strategy_emblem_row)

	_strategy_icon_lbl = Label.new()
	_strategy_icon_lbl.custom_minimum_size = Vector2(110, 0)
	_strategy_emblem_row.add_child(_strategy_icon_lbl)

	strategy_icon_option = OptionButton.new()
	strategy_icon_option.custom_minimum_size = Vector2(90, 0)
	for i in range(STRATEGY_ICONS.size()):
		strategy_icon_option.add_item(STRATEGY_ICONS[i], i)
		strategy_icon_option.set_item_metadata(i, STRATEGY_ICONS[i])
	_strategy_emblem_row.add_child(strategy_icon_option)

	_strategy_color_lbl = Label.new()
	_strategy_emblem_row.add_child(_strategy_color_lbl)

	strategy_color_picker = ColorPickerButton.new()
	strategy_color_picker.custom_minimum_size = Vector2(56, 28)
	strategy_color_picker.edit_alpha = false
	strategy_color_picker.color = Color("#10B981")
	_strategy_emblem_row.add_child(strategy_color_picker)

	for swatch_hex in STRATEGY_SWATCH_COLORS:
		var swatch_btn := Button.new()
		swatch_btn.custom_minimum_size = Vector2(22, 22)
		var col := Color(swatch_hex)
		swatch_btn.add_theme_stylebox_override("normal", EvoUiStyle.make_button_style(col, col.darkened(0.35), 1, 2, 2))
		swatch_btn.add_theme_stylebox_override("hover", EvoUiStyle.make_button_style(col.lightened(0.15), EvoUiStyle.COLOR_GOLD_BRIGHT, 2, 2, 2))
		swatch_btn.pressed.connect(func() -> void: strategy_color_picker.color = col)
		_strategy_emblem_row.add_child(swatch_btn)

	# Strategy Traits Selection Box
	_strategy_traits_card = PanelContainer.new()
	_strategy_traits_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 10))
	form_vbox.add_child(_strategy_traits_card)

	var strat_traits_outer := VBoxContainer.new()
	strat_traits_outer.add_theme_constant_override("separation", 6)
	_strategy_traits_card.add_child(strat_traits_outer)

	_strategy_traits_title_lbl = Label.new()
	_strategy_traits_title_lbl.add_theme_font_size_override("font_size", 14)
	_strategy_traits_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	strat_traits_outer.add_child(_strategy_traits_title_lbl)

	strategy_traits_box = VBoxContainer.new()
	strategy_traits_box.add_theme_constant_override("separation", 4)
	strat_traits_outer.add_child(strategy_traits_box)

	# Strategy Combined Biophysical Vector Preview
	_strategy_vector_card = PanelContainer.new()
	_strategy_vector_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#f4e2b8"), EvoUiStyle.COLOR_GOLD_BEVEL, 10))
	form_vbox.add_child(_strategy_vector_card)

	var strat_vec_vbox := VBoxContainer.new()
	strat_vec_vbox.add_theme_constant_override("separation", 4)
	_strategy_vector_card.add_child(strat_vec_vbox)

	_strategy_vector_title_lbl = Label.new()
	_strategy_vector_title_lbl.add_theme_font_size_override("font_size", 14)
	_strategy_vector_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	strat_vec_vbox.add_child(_strategy_vector_title_lbl)

	strategy_vector_label = Label.new()
	strategy_vector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strategy_vector_label.add_theme_font_size_override("font_size", 12)
	strategy_vector_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	strat_vec_vbox.add_child(strategy_vector_label)

	# Trait / Decision specific controls
	enables_culture_check = CheckBox.new()
	form_vbox.add_child(enables_culture_check)

	_archetype_row = HBoxContainer.new()
	_archetype_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(_archetype_row)

	_archetype_lbl = Label.new()
	_archetype_lbl.custom_minimum_size = Vector2(110, 0)
	_archetype_row.add_child(_archetype_lbl)

	_archetype_option = OptionButton.new()
	_archetype_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archetype_row.add_child(_archetype_option)

	# 6 Sliders box (for traits & decisions)
	_sliders_card = PanelContainer.new()
	_sliders_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 10))
	form_vbox.add_child(_sliders_card)

	var sliders_vbox := VBoxContainer.new()
	sliders_vbox.add_theme_constant_override("separation", 6)
	_sliders_card.add_child(sliders_vbox)

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
		slider.step = 0.01
		slider.value = 0.20 if s_key == "transmission_threshold" else 0.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_slider_value_changed.bind(s_key))
		row.add_child(slider)
		sliders[s_key] = slider

		var v_lbl := Label.new()
		v_lbl.custom_minimum_size = Vector2(54, 0)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(v_lbl)
		_slider_val_labels[s_key] = v_lbl

	# Live Thermodynamic Meter (for traits & decisions)
	_thermo_card = PanelContainer.new()
	_thermo_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#f4e2b8"), EvoUiStyle.COLOR_GOLD_BEVEL, 10))
	form_vbox.add_child(_thermo_card)

	var thermo_vbox := VBoxContainer.new()
	thermo_vbox.add_theme_constant_override("separation", 6)
	_thermo_card.add_child(thermo_vbox)

	var thermo_top := HBoxContainer.new()
	thermo_vbox.add_child(thermo_top)

	_thermo_title_lbl = Label.new()
	_thermo_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thermo_title_lbl.add_theme_font_size_override("font_size", 14)
	_thermo_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	thermo_top.add_child(_thermo_title_lbl)

	auto_balance_button = Button.new()
	auto_balance_button.pressed.connect(_auto_balance_vector)
	thermo_top.add_child(auto_balance_button)

	balance_bar = ProgressBar.new()
	balance_bar.min_value = 0.0
	balance_bar.max_value = 1.8
	balance_bar.show_percentage = false
	balance_bar.custom_minimum_size = Vector2(0, 14)
	thermo_vbox.add_child(balance_bar)

	_thermo_metrics_lbl = Label.new()
	_thermo_metrics_lbl.add_theme_font_size_override("font_size", 12)
	_thermo_metrics_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	thermo_vbox.add_child(_thermo_metrics_lbl)

	balance_status_label = Label.new()
	balance_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balance_status_label.add_theme_font_size_override("font_size", 12)
	thermo_vbox.add_child(balance_status_label)

	# Bottom Actions
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 10)
	form_vbox.add_child(actions_hbox)

	save_item_button = Button.new()
	save_item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_item_button.pressed.connect(_save_current_item)
	actions_hbox.add_child(save_item_button)

	_strategy_matchup_row = HBoxContainer.new()
	_strategy_matchup_row.add_theme_constant_override("separation", 10)
	form_vbox.add_child(_strategy_matchup_row)

	use_strategy_a_button = Button.new()
	use_strategy_a_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use_strategy_a_button.pressed.connect(_on_use_strategy_slot_pressed.bind("a"))
	_strategy_matchup_row.add_child(use_strategy_a_button)

	use_strategy_b_button = Button.new()
	use_strategy_b_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use_strategy_b_button.pressed.connect(_on_use_strategy_slot_pressed.bind("b"))
	_strategy_matchup_row.add_child(use_strategy_b_button)

	_inject_row = HBoxContainer.new()
	_inject_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(_inject_row)

	_inject_deme_lbl = Label.new()
	_inject_row.add_child(_inject_deme_lbl)

	inject_deme_option = OptionButton.new()
	inject_deme_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inject_deme_option.item_selected.connect(_on_inject_deme_option_selected)
	_inject_row.add_child(inject_deme_option)

	inject_button = Button.new()
	inject_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inject_button.pressed.connect(_on_inject_pressed)
	_inject_row.add_child(inject_button)

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
	modal_closed.emit()


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
		id_edit.text = _next_custom_id("strat")
		name_edit.text = EvoUiStyle.tr_text(_lang, "Estrategia Personalizada", "Custom Strategy")
		desc_edit.text = EvoUiStyle.tr_text(
			_lang,
			"Doctrina bio-cultural diseñada en el laboratorio para el duelo de estrategias.",
			"Bio-cultural doctrine crafted in the laboratory for the strategy duel."
		)
		_select_strategy_icon("🛡️")
		strategy_color_picker.color = Color("#10B981")
		_rebuild_strategy_trait_checks()
		_set_checked_strategy_trait_ids(["bio-k-strategy", "bio-social-instinct", "cul-communal-conservation"])
	elif _current_tab == "biological":
		id_edit.text = _next_custom_id("bio")
		name_edit.text = EvoUiStyle.tr_text(_lang, "Adaptación Metabólica", "Metabolic Adaptation")
		desc_edit.text = EvoUiStyle.tr_text(
			_lang,
			"Rasgo biológico experimental diseñado en el laboratorio.",
			"Experimental biological trait crafted in the lab."
		)
		enables_culture_check.button_pressed = false
		_set_vector_to_sliders(EvoTypes.BiophysicalVector.new(0.15, 0.30, 0.05, 0.20, 0.10, 0.20))
	elif _current_tab == "cultural":
		id_edit.text = _next_custom_id("cul")
		name_edit.text = EvoUiStyle.tr_text(_lang, "Tradición Artesanal", "Artisanal Tradition")
		desc_edit.text = EvoUiStyle.tr_text(
			_lang,
			"Práctica cultural transmitida socialmente entre generaciones.",
			"Socially transmitted cultural practice across generations."
		)
		_set_vector_to_sliders(EvoTypes.BiophysicalVector.new(0.20, 0.35, 0.15, 0.10, 0.35, 0.45))
	else:
		id_edit.text = _next_custom_id("dec")
		name_edit.text = EvoUiStyle.tr_text(_lang, "Estrategia Adaptativa", "Adaptive Strategy")
		desc_edit.text = EvoUiStyle.tr_text(
			_lang,
			"Patrón conductual colectivo evaluado por las aldeas.",
			"Collective behavioral pattern evaluated by villages."
		)
		_select_archetype("custom")
		_set_vector_to_sliders(EvoTypes.BiophysicalVector.new(0.20, 0.35, 0.10, 0.15, 0.20, 0.25))

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
		var strat := _build_strategy_from_form()
		strat.name = clean_name
		strat.description = clean_desc
		strat.origin = "user"
		if _world_state != null:
			_world_state.strategies_catalog[strat.id] = strat
			EvoUserSettings.save_user_catalog(_world_state)
		_selected_id = strat.id
		id_edit.text = strat.id
		strategy_saved.emit(strat.id)
		catalog_item_saved.emit("strategy", strat.to_dict())
		_rebuild_catalog_list()
		_update_labels()
		_update_strategy_vector_preview()
		_show_saved_feedback(strat.id)
		return

	var raw_vec := _read_vector_from_sliders()
	var free_mode := _world_state.free_sandbox_mode if _world_state != null else false
	var final_vec := raw_vec if free_mode else EvoUiStyle.balance_vector(raw_vec)
	_set_vector_to_sliders(final_vec)
	_update_thermodynamics_preview()

	if _current_tab == "decision":
		var dec := EvoTypes.DecisionDef.new()
		dec.id = _resolve_target_id("dec")
		dec.name = clean_name
		dec.description = clean_desc
		dec.archetype = _get_selected_archetype()
		dec.origin = "user"
		dec.vector = final_vec
		if _world_state != null and _world_state.decisions_catalog.has(dec.id):
			var prev_dec: EvoTypes.DecisionDef = _world_state.decisions_catalog[dec.id]
			dec.required_trait_ids = prev_dec.required_trait_ids.duplicate()
		if _world_state != null:
			_world_state.decisions_catalog[dec.id] = dec
			EvoUserSettings.save_user_catalog(_world_state)
		_selected_id = dec.id
		id_edit.text = dec.id
		catalog_item_saved.emit("decision", dec.to_dict())
		_rebuild_catalog_list()
		_update_labels()
		_show_saved_feedback(dec.id)
	else:
		var prefix := "bio" if _current_tab == "biological" else "cul"
		var tr := EvoTypes.TraitDef.new()
		tr.id = _resolve_target_id(prefix)
		tr.name = clean_name
		tr.description = clean_desc
		tr.category = _current_tab
		tr.origin = "user"
		tr.vector = final_vec
		tr.enables_cultural_transmission = enables_culture_check.button_pressed if _current_tab == "biological" else false
		if _world_state != null and _world_state.traits_catalog.has(tr.id):
			var prev_tr: EvoTypes.TraitDef = _world_state.traits_catalog[tr.id]
			tr.mutually_exclusive_with = prev_tr.mutually_exclusive_with.duplicate()
		if _world_state != null:
			_world_state.traits_catalog[tr.id] = tr
			EvoUserSettings.save_user_catalog(_world_state)
		_selected_id = tr.id
		id_edit.text = tr.id
		_rebuild_strategy_trait_checks()
		catalog_item_saved.emit("trait", tr.to_dict())
		_rebuild_catalog_list()
		_update_labels()
		_show_saved_feedback(tr.id)


func _auto_balance_vector() -> void:
	var vec := _read_vector_from_sliders()
	var balanced := EvoUiStyle.balance_vector(vec)
	_set_vector_to_sliders(balanced)
	_update_thermodynamics_preview()


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


func _rebuild_strategy_trait_checks() -> void:
	if strategy_traits_box == null:
		return
	for child in strategy_traits_box.get_children():
		child.queue_free()
	strategy_trait_checks.clear()

	var traits_cat: Dictionary = _world_state.traits_catalog if _world_state != null else EvoCatalog.create_base_traits_catalog(_lang)

	var bio_hdr := Label.new()
	bio_hdr.text = "🧬 " + EvoI18n.t(_lang, "panel.traits_bio")
	bio_hdr.add_theme_font_size_override("font_size", 13)
	bio_hdr.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	strategy_traits_box.add_child(bio_hdr)

	for tid in traits_cat.keys():
		var t: EvoTypes.TraitDef = traits_cat[tid]
		if t.category != "biological":
			continue
		var cb := _make_strategy_trait_checkbox(t)
		strategy_trait_checks[t.id] = cb
		strategy_traits_box.add_child(cb)

	var cul_hdr := Label.new()
	cul_hdr.text = "🔥 " + EvoI18n.t(_lang, "panel.traits_cul")
	cul_hdr.add_theme_font_size_override("font_size", 13)
	cul_hdr.add_theme_color_override("font_color", EvoUiStyle.COLOR_PURPLE_CULTURE)
	strategy_traits_box.add_child(cul_hdr)

	for tid in traits_cat.keys():
		var t: EvoTypes.TraitDef = traits_cat[tid]
		if t.category != "cultural":
			continue
		var cb := _make_strategy_trait_checkbox(t)
		strategy_trait_checks[t.id] = cb
		strategy_traits_box.add_child(cb)


func _make_strategy_trait_checkbox(t: EvoTypes.TraitDef) -> CheckBox:
	var cb := CheckBox.new()
	var t_name := EvoI18n.trait_name(_lang, t)
	var summary := _format_trait_vector_summary(t.vector)
	var culture_tag := ""
	if t.enables_cultural_transmission:
		culture_tag = " [★ Cultura]" if _lang != "en" else " [★ Culture]"
	cb.text = "%s%s  (%s)" % [t_name, culture_tag, summary]
	cb.tooltip_text = EvoI18n.trait_description(_lang, t)
	cb.toggled.connect(_on_strategy_trait_toggled.bind(t.id))
	return cb


func _format_trait_vector_summary(v: EvoTypes.BiophysicalVector) -> String:
	var parts: Array[String] = []
	if not is_zero_approx(v.metabolic_cost):
		parts.append("Cost %+.2f" % v.metabolic_cost)
	if not is_zero_approx(v.extraction_efficiency):
		parts.append("Ext %+.2f" % v.extraction_efficiency)
	if not is_zero_approx(v.ecological_impact):
		parts.append("Eco %+.2f" % v.ecological_impact)
	if not is_zero_approx(v.spatial_mobility):
		parts.append("Mob %+.2f" % v.spatial_mobility)
	if not is_zero_approx(v.social_cohesion):
		parts.append("Soc %+.2f" % v.social_cohesion)
	return ", ".join(parts) if not parts.is_empty() else "0.00"


func _on_strategy_trait_toggled(is_checked: bool, trait_id: String) -> void:
	if _updating_strategy_checks:
		return
	var traits_cat: Dictionary = _world_state.traits_catalog if _world_state != null else {}
	_updating_strategy_checks = true

	if is_checked:
		if trait_id == "bio-r-strategy" and strategy_trait_checks.has("bio-k-strategy"):
			(strategy_trait_checks["bio-k-strategy"] as CheckBox).button_pressed = false
		elif trait_id == "bio-k-strategy" and strategy_trait_checks.has("bio-r-strategy"):
			(strategy_trait_checks["bio-r-strategy"] as CheckBox).button_pressed = false

		if traits_cat.has(trait_id):
			var tr: EvoTypes.TraitDef = traits_cat[trait_id]
			for ex_id in tr.mutually_exclusive_with:
				if strategy_trait_checks.has(ex_id):
					(strategy_trait_checks[ex_id] as CheckBox).button_pressed = false
			for other_id in traits_cat.keys():
				var other_tr: EvoTypes.TraitDef = traits_cat[other_id]
				if other_tr.mutually_exclusive_with.has(trait_id) and strategy_trait_checks.has(other_id):
					(strategy_trait_checks[other_id] as CheckBox).button_pressed = false

			if tr.category == "cultural" and not _has_checked_cultural_capacity(traits_cat):
				var enabled_any := false
				for bid in ["bio-social-instinct", "bio-encephalization"]:
					if strategy_trait_checks.has(bid):
						var can_enable := not traits_cat.has(bid) or (traits_cat[bid] as EvoTypes.TraitDef).enables_cultural_transmission
						if can_enable:
							(strategy_trait_checks[bid] as CheckBox).button_pressed = true
							enabled_any = true
							break
				if not enabled_any:
					for bid in traits_cat.keys():
						var btr: EvoTypes.TraitDef = traits_cat[bid]
						if btr.category == "biological" and btr.enables_cultural_transmission and strategy_trait_checks.has(bid):
							(strategy_trait_checks[bid] as CheckBox).button_pressed = true
							break
	else:
		var is_culture_enabler := false
		if traits_cat.has(trait_id):
			var tr: EvoTypes.TraitDef = traits_cat[trait_id]
			is_culture_enabler = (tr.category == "biological" and tr.enables_cultural_transmission)
		else:
			is_culture_enabler = trait_id in ["bio-social-instinct", "bio-encephalization"]
		if is_culture_enabler and not _has_checked_cultural_capacity(traits_cat):
			for cid in strategy_trait_checks.keys():
				var is_cul := str(cid).begins_with("cul-")
				if traits_cat.has(cid):
					is_cul = (traits_cat[cid] as EvoTypes.TraitDef).category == "cultural"
				if is_cul:
					(strategy_trait_checks[cid] as CheckBox).button_pressed = false

	_updating_strategy_checks = false
	_update_strategy_vector_preview()


func _has_checked_cultural_capacity(traits_cat: Dictionary) -> bool:
	for tid in strategy_trait_checks.keys():
		var cb: CheckBox = strategy_trait_checks[tid]
		if not cb.button_pressed:
			continue
		if traits_cat.has(tid):
			var tr: EvoTypes.TraitDef = traits_cat[tid]
			if tr.category == "biological" and tr.enables_cultural_transmission:
				return true
		elif tid in ["bio-social-instinct", "bio-encephalization"]:
			return true
	return false


func _get_checked_strategy_trait_ids() -> Array[String]:
	var res: Array[String] = []
	for tid in strategy_trait_checks.keys():
		if (strategy_trait_checks[tid] as CheckBox).button_pressed:
			res.append(str(tid))
	return res


func _set_checked_strategy_trait_ids(trait_ids: Array) -> void:
	_updating_strategy_checks = true
	for tid in strategy_trait_checks.keys():
		(strategy_trait_checks[tid] as CheckBox).button_pressed = trait_ids.has(tid)
	_updating_strategy_checks = false
	_update_strategy_vector_preview()


func _are_traits_mutually_exclusive(tid_a: String, tid_b: String, traits_cat: Dictionary) -> bool:
	if (tid_a == "bio-r-strategy" and tid_b == "bio-k-strategy") or (tid_a == "bio-k-strategy" and tid_b == "bio-r-strategy"):
		return true
	if traits_cat.has(tid_a) and (traits_cat[tid_a] as EvoTypes.TraitDef).mutually_exclusive_with.has(tid_b):
		return true
	if traits_cat.has(tid_b) and (traits_cat[tid_b] as EvoTypes.TraitDef).mutually_exclusive_with.has(tid_a):
		return true
	return false


func _build_strategy_from_form() -> EvoTypes.StrategyDef:
	var strat := EvoTypes.StrategyDef.new()
	strat.id = _resolve_target_id("strat")
	strat.name = name_edit.text.strip_edges()
	if strat.name == "":
		strat.name = "Custom Strategy"
	strat.description = desc_edit.text.strip_edges()
	strat.icon = _get_selected_strategy_icon()
	strat.color = "#" + strategy_color_picker.color.to_html(false).to_upper()

	var traits_cat: Dictionary = _world_state.traits_catalog if _world_state != null else {}
	var bio_ids: Array[String] = []
	var cul_ids: Array[String] = []
	var accepted_ids: Array[String] = []
	for tid_var in strategy_trait_checks.keys():
		var tid := str(tid_var)
		var cb: CheckBox = strategy_trait_checks[tid_var]
		if not cb.button_pressed:
			continue
		var has_conflict := false
		for kept_id in accepted_ids:
			if _are_traits_mutually_exclusive(tid, kept_id, traits_cat):
				has_conflict = true
				break
		if has_conflict:
			continue
		accepted_ids.append(tid)
		var is_cul := tid.begins_with("cul-")
		if traits_cat.has(tid):
			is_cul = (traits_cat[tid] as EvoTypes.TraitDef).category == "cultural"
		if is_cul:
			cul_ids.append(tid)
		else:
			bio_ids.append(tid)

	if not cul_ids.is_empty():
		var has_cap := false
		for bid in bio_ids:
			if traits_cat.has(bid):
				if (traits_cat[bid] as EvoTypes.TraitDef).enables_cultural_transmission:
					has_cap = true
					break
			elif bid in ["bio-social-instinct", "bio-encephalization"]:
				has_cap = true
				break
		if not has_cap:
			var fallback_bio := ""
			for cand in ["bio-social-instinct", "bio-encephalization"]:
				if not traits_cat.has(cand) or (traits_cat[cand] as EvoTypes.TraitDef).enables_cultural_transmission:
					fallback_bio = cand
					break
			if fallback_bio == "":
				for tid in traits_cat.keys():
					var t: EvoTypes.TraitDef = traits_cat[tid]
					if t.category == "biological" and t.enables_cultural_transmission:
						fallback_bio = t.id
						break
			if fallback_bio != "" and not bio_ids.has(fallback_bio):
				bio_ids.append(fallback_bio)
			elif fallback_bio == "":
				cul_ids.clear()

	strat.biological_trait_ids = bio_ids
	strat.cultural_trait_ids = cul_ids
	return strat


func _update_strategy_vector_preview() -> void:
	if strategy_vector_label == null:
		return
	var temp_strat := _build_strategy_from_form()
	var traits_cat: Dictionary = _world_state.traits_catalog if _world_state != null else EvoCatalog.create_base_traits_catalog(_lang)
	var vec := EvoCatalog.compute_strategy_vector(temp_strat, traits_cat)
	strategy_vector_label.text = (
		"%s: %+.2f   |   %s: %+.2f   |   %s: %+.2f\n%s: %+.2f   |   %s: %+.2f   |   %s: %.2f" % [
			EvoI18n.t(_lang, "axis.metabolic_cost"), vec.metabolic_cost,
			EvoI18n.t(_lang, "axis.extraction_efficiency"), vec.extraction_efficiency,
			EvoI18n.t(_lang, "axis.ecological_impact"), vec.ecological_impact,
			EvoI18n.t(_lang, "axis.spatial_mobility"), vec.spatial_mobility,
			EvoI18n.t(_lang, "axis.social_cohesion"), vec.social_cohesion,
			EvoI18n.t(_lang, "axis.transmission_threshold"), vec.transmission_threshold
		]
	)


func _select_strategy_icon(icon: String) -> void:
	if strategy_icon_option == null:
		return
	for i in range(strategy_icon_option.item_count):
		if strategy_icon_option.get_item_text(i) == icon:
			strategy_icon_option.select(i)
			return
	if strategy_icon_option.item_count > 0:
		strategy_icon_option.select(0)


func _get_selected_strategy_icon() -> String:
	if strategy_icon_option == null:
		return "🛡️"
	var idx := strategy_icon_option.selected
	if idx >= 0 and idx < strategy_icon_option.item_count:
		return strategy_icon_option.get_item_text(idx)
	return "🛡️"


func _is_strategy_form_dirty(existing: EvoTypes.StrategyDef) -> bool:
	var form_strat := _build_strategy_from_form()
	if form_strat.id != existing.id or form_strat.name != existing.name or form_strat.description != existing.description:
		return true
	if form_strat.icon != existing.icon or form_strat.color.to_upper() != existing.color.to_upper():
		return true
	if form_strat.biological_trait_ids != existing.biological_trait_ids or form_strat.cultural_trait_ids != existing.cultural_trait_ids:
		return true
	return false


func _on_use_strategy_slot_pressed(slot: String) -> void:
	if _current_tab != "strategy":
		return
	var target_id := id_edit.text.strip_edges()
	if target_id == "":
		target_id = _selected_id
	if target_id == "" or _world_state == null or not _world_state.strategies_catalog.has(target_id) or _is_strategy_form_dirty(_world_state.strategies_catalog[target_id]):
		_save_current_item()
	if _world_state != null:
		if slot == "a":
			_world_state.strategy_a_id = _selected_id
		elif slot == "b":
			_world_state.strategy_b_id = _selected_id
	strategy_assigned.emit(slot, _selected_id)
	_feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	_feedback_lbl.text = "%s: %s" % [
		EvoI18n.t(_lang, "lab_use_strat_a" if slot == "a" else "lab_use_strat_b"),
		_selected_id
	]


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


func _rebuild_inject_deme_options() -> void:
	if inject_deme_option == null:
		return
	inject_deme_option.clear()
	if _world_state == null or _world_state.demes.is_empty():
		return
	var idx := 0
	var selected_idx := 0
	for did in _world_state.demes.keys():
		var d: EvoTypes.Deme = _world_state.demes[did]
		inject_deme_option.add_item(d.name, idx)
		inject_deme_option.set_item_metadata(idx, d.id)
		if d.id == _selected_deme_id:
			selected_idx = idx
		idx += 1
	inject_deme_option.select(selected_idx)
	_selected_deme_id = str(inject_deme_option.get_item_metadata(selected_idx))


func _on_inject_deme_option_selected(index: int) -> void:
	if inject_deme_option == null or index < 0 or index >= inject_deme_option.item_count:
		return
	_selected_deme_id = str(inject_deme_option.get_item_metadata(index))
	_update_labels()


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

	_strategy_icon_lbl.text = EvoI18n.t(_lang, "lab_strat_icon") + ":"
	_strategy_color_lbl.text = EvoI18n.t(_lang, "lab_strat_color") + ":"
	_strategy_traits_title_lbl.text = EvoI18n.t(_lang, "lab_strat_traits")
	_strategy_vector_title_lbl.text = EvoI18n.t(_lang, "lab_strat_vector")
	use_strategy_a_button.text = EvoI18n.t(_lang, "lab_use_strat_a")
	use_strategy_b_button.text = EvoI18n.t(_lang, "lab_use_strat_b")

	enables_culture_check.text = EvoUiStyle.tr_text(
		_lang,
		"Habilita transmisión cultural (enablesCulturalTransmission)",
		"Enables cultural transmission (enablesCulturalTransmission)"
	)
	_archetype_lbl.text = EvoUiStyle.tr_text(_lang, "Arquetipo:", "Archetype:")

	_strategy_emblem_row.visible = is_strat
	_strategy_traits_card.visible = is_strat
	_strategy_vector_card.visible = is_strat
	_strategy_matchup_row.visible = is_strat

	enables_culture_check.visible = (_current_tab == "biological")
	_archetype_row.visible = (_current_tab == "decision")
	_sliders_card.visible = not is_strat
	_thermo_card.visible = not is_strat
	_inject_row.visible = (_current_tab in ["biological", "cultural"])

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
	auto_balance_button.text = EvoUiStyle.tr_text(_lang, "Auto-Equilibrar Vector", "Auto-Balance Vector")
	save_item_button.text = EvoI18n.t(_lang, "lab_save_strat") if is_strat else EvoUiStyle.tr_text(_lang, "💾 Guardar en el Catálogo", "💾 Save to Catalog")
	_inject_deme_lbl.text = EvoUiStyle.tr_text(_lang, "Aldea:", "Village:")
	inject_button.text = EvoUiStyle.tr_text(_lang, "💉 Inyectar en Aldea", "💉 Inject into Village")
	inject_button.disabled = (_selected_deme_id == "" or _world_state == null or not _world_state.demes.has(_selected_deme_id))

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


func _on_catalog_strategy_clicked(strategy_id: String) -> void:
	if _world_state == null or not _world_state.strategies_catalog.has(strategy_id):
		return
	var strat: EvoTypes.StrategyDef = _world_state.strategies_catalog[strategy_id]
	_selected_id = strat.id
	id_edit.text = strat.id
	name_edit.text = EvoI18n.strategy_name(_lang, strat)
	desc_edit.text = EvoI18n.strategy_description(_lang, strat)
	_select_strategy_icon(strat.icon)
	strategy_color_picker.color = Color.from_string(strat.color, Color("#10B981"))

	var combined_traits: Array[String] = []
	for bid in strat.biological_trait_ids:
		combined_traits.append(bid)
	for cid in strat.cultural_trait_ids:
		combined_traits.append(cid)
	_set_checked_strategy_trait_ids(combined_traits)

	_feedback_lbl.text = ""
	_update_labels()
	_rebuild_catalog_list()
	_update_strategy_vector_preview()


func _on_catalog_trait_clicked(trait_id: String) -> void:
	if _world_state == null or not _world_state.traits_catalog.has(trait_id):
		return
	var tr: EvoTypes.TraitDef = _world_state.traits_catalog[trait_id]
	_selected_id = tr.id
	id_edit.text = tr.id
	name_edit.text = EvoI18n.trait_name(_lang, tr)
	desc_edit.text = EvoI18n.trait_description(_lang, tr)
	enables_culture_check.button_pressed = tr.enables_cultural_transmission
	_set_vector_to_sliders(tr.vector)
	_feedback_lbl.text = ""
	_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()


func _on_catalog_decision_clicked(decision_id: String) -> void:
	if _world_state == null or not _world_state.decisions_catalog.has(decision_id):
		return
	var dec: EvoTypes.DecisionDef = _world_state.decisions_catalog[decision_id]
	_selected_id = dec.id
	id_edit.text = dec.id
	name_edit.text = EvoI18n.decision_name(_lang, dec)
	desc_edit.text = EvoI18n.decision_description(_lang, dec)
	_select_archetype(dec.archetype)
	_set_vector_to_sliders(dec.vector)
	_feedback_lbl.text = ""
	_update_labels()
	_rebuild_catalog_list()
	_update_thermodynamics_preview()


func _set_vector_to_sliders(vec: EvoTypes.BiophysicalVector) -> void:
	_updating_sliders = true
	(sliders["metabolic_cost"] as HSlider).value = vec.metabolic_cost
	(sliders["extraction_efficiency"] as HSlider).value = vec.extraction_efficiency
	(sliders["ecological_impact"] as HSlider).value = vec.ecological_impact
	(sliders["spatial_mobility"] as HSlider).value = vec.spatial_mobility
	(sliders["social_cohesion"] as HSlider).value = vec.social_cohesion
	(sliders["transmission_threshold"] as HSlider).value = vec.transmission_threshold
	_updating_sliders = false
	_refresh_slider_value_labels()


func _read_vector_from_sliders() -> EvoTypes.BiophysicalVector:
	return EvoTypes.BiophysicalVector.new(
		snappedf((sliders["metabolic_cost"] as HSlider).value, 0.01),
		snappedf((sliders["extraction_efficiency"] as HSlider).value, 0.01),
		snappedf((sliders["ecological_impact"] as HSlider).value, 0.01),
		snappedf((sliders["spatial_mobility"] as HSlider).value, 0.01),
		snappedf((sliders["social_cohesion"] as HSlider).value, 0.01),
		snappedf((sliders["transmission_threshold"] as HSlider).value, 0.01)
	)


func _refresh_slider_value_labels() -> void:
	for s_key in SLIDER_KEYS:
		var val: float = (sliders[s_key] as HSlider).value
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

	balance_bar.value = clampf(a_plus, balance_bar.min_value, balance_bar.max_value)
	EvoUiStyle.style_progress_bar(balance_bar, EvoUiStyle.COLOR_GREEN_OK if is_bal else EvoUiStyle.COLOR_AMBER_WARN)

	_thermo_metrics_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"Ventajas Positivas (A+): %.2f   |   Coste Actual (C_actual): %.2f   |   Coste Requerido (C_req): %.2f" % [a_plus, c_actual, c_req],
		"Positive Advantages (A+): %.2f   |   Actual Cost (C_actual): %.2f   |   Required Cost (C_req): %.2f" % [a_plus, c_actual, c_req]
	)

	if is_bal:
		balance_status_label.text = EvoUiStyle.tr_text(
			_lang,
			"✓ Cumple la Ley de Conservación Termodinámica (C_actual >= C_req).",
			"✓ Complies with the Law of Thermodynamic Conservation (C_actual >= C_req)."
		)
		balance_status_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	else:
		balance_status_label.text = EvoUiStyle.tr_text(
			_lang,
			"⚠ Exceso de ventaja sin coste: al guardar se auto-equilibrará a Coste Metabólico = %+.2f, Impacto Eco = %+.2f." % [bal_vec.metabolic_cost, bal_vec.ecological_impact],
			"⚠ Uncompensated advantage: saving will auto-balance to Metabolic Cost = %+.2f, Eco Impact = %+.2f." % [bal_vec.metabolic_cost, bal_vec.ecological_impact]
		)
		balance_status_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_AMBER_WARN)


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


func _on_slider_value_changed(_val: float, _key: String) -> void:
	if _updating_sliders:
		return
	_update_thermodynamics_preview()


func _is_selected_builtin_trait_unmodified() -> bool:
	if _world_state == null or _selected_id == "" or not _world_state.traits_catalog.has(_selected_id):
		return false
	var existing: EvoTypes.TraitDef = _world_state.traits_catalog[_selected_id]
	if existing.origin not in ["catalog", "base"]:
		return false
	var target_id := id_edit.text.strip_edges()
	if target_id != "" and target_id != existing.id:
		return false
	var clean_name := name_edit.text.strip_edges()
	if clean_name != EvoI18n.trait_name(_lang, existing).strip_edges() and clean_name != existing.name.strip_edges():
		return false
	var clean_desc := desc_edit.text.strip_edges()
	if clean_desc != EvoI18n.trait_description(_lang, existing).strip_edges() and clean_desc != existing.description.strip_edges():
		return false
	if _current_tab == "biological" and enables_culture_check.button_pressed != existing.enables_cultural_transmission:
		return false
	var form_vec := _read_vector_from_sliders()
	var ex_vec := existing.vector
	return (
		is_equal_approx(form_vec.metabolic_cost, snappedf(ex_vec.metabolic_cost, 0.01))
		and is_equal_approx(form_vec.extraction_efficiency, snappedf(ex_vec.extraction_efficiency, 0.01))
		and is_equal_approx(form_vec.ecological_impact, snappedf(ex_vec.ecological_impact, 0.01))
		and is_equal_approx(form_vec.spatial_mobility, snappedf(ex_vec.spatial_mobility, 0.01))
		and is_equal_approx(form_vec.social_cohesion, snappedf(ex_vec.social_cohesion, 0.01))
		and is_equal_approx(form_vec.transmission_threshold, snappedf(ex_vec.transmission_threshold, 0.01))
	)


func _on_inject_pressed() -> void:
	if _current_tab not in ["biological", "cultural"] or _selected_deme_id == "":
		return
	if _current_tab == "cultural" and _world_state != null and _world_state.demes.has(_selected_deme_id):
		var target_deme: EvoTypes.Deme = _world_state.demes[_selected_deme_id]
		if not EvoCatalog.deme_has_cultural_capacity(target_deme, _world_state.traits_catalog):
			_feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_WARN)
			_feedback_lbl.text = EvoUiStyle.tr_text(
				_lang,
				"⚠ La aldea seleccionada carece de capacidad cultural (requiere Encefalización o Sociabilidad Instintiva).",
				"⚠ Selected village lacks cultural capacity (requires Encephalization or Instinctive Sociability)."
			)
			return
	if not _is_selected_builtin_trait_unmodified():
		_save_current_item()
	if _world_state != null:
		EvoCatalog.inject_trait_into_deme(_world_state, _selected_deme_id, _selected_id, _lang)
	_feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	inject_trait_requested.emit(_selected_deme_id, _selected_id)
	_feedback_lbl.text = EvoUiStyle.tr_text(
		_lang,
		"💉 Rasgo '%s' inyectado en la aldea seleccionada." % name_edit.text,
		"💉 Trait '%s' injected into selected village." % name_edit.text
	)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_modal()
