class_name EvoLabThermoForm
extends RefCounted


static func build_thermo_form(modal: Control, form_vbox: VBoxContainer) -> void:
	modal.enables_culture_check = CheckBox.new()
	form_vbox.add_child(modal.enables_culture_check)

	# 6 Sliders box (for traits)
	modal._sliders_card = PanelContainer.new()
	modal._sliders_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 10))
	form_vbox.add_child(modal._sliders_card)

	var sliders_vbox := VBoxContainer.new()
	sliders_vbox.add_theme_constant_override("separation", 6)
	modal._sliders_card.add_child(sliders_vbox)

	for s_key in modal.SLIDER_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		sliders_vbox.add_child(row)

		var t_lbl := Label.new()
		t_lbl.custom_minimum_size = Vector2(210, 0)
		t_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(t_lbl)
		modal._slider_title_labels[s_key] = t_lbl

		var slider := HSlider.new()
		slider.min_value = 0.0 if s_key == "transmission_threshold" else -1.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = 0.20 if s_key == "transmission_threshold" else 0.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(modal._on_slider_value_changed.bind(s_key))
		row.add_child(slider)
		modal.sliders[s_key] = slider

		var v_lbl := Label.new()
		v_lbl.custom_minimum_size = Vector2(54, 0)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(v_lbl)
		modal._slider_val_labels[s_key] = v_lbl

	# Live Thermodynamic Meter (for traits & decisions)
	modal._thermo_card = PanelContainer.new()
	modal._thermo_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#f4e2b8"), EvoUiStyle.COLOR_GOLD_BEVEL, 10))
	form_vbox.add_child(modal._thermo_card)

	var thermo_vbox := VBoxContainer.new()
	thermo_vbox.add_theme_constant_override("separation", 6)
	modal._thermo_card.add_child(thermo_vbox)

	var thermo_top := HBoxContainer.new()
	thermo_vbox.add_child(thermo_top)

	modal._thermo_title_lbl = Label.new()
	modal._thermo_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal._thermo_title_lbl.add_theme_font_size_override("font_size", 14)
	modal._thermo_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	thermo_top.add_child(modal._thermo_title_lbl)

	modal.auto_balance_button = Button.new()
	modal.auto_balance_button.pressed.connect(modal._auto_balance_vector)
	thermo_top.add_child(modal.auto_balance_button)

	modal.balance_bar = ProgressBar.new()
	modal.balance_bar.min_value = 0.0
	modal.balance_bar.max_value = 1.8
	modal.balance_bar.show_percentage = false
	modal.balance_bar.custom_minimum_size = Vector2(0, 14)
	thermo_vbox.add_child(modal.balance_bar)

	modal._thermo_metrics_lbl = Label.new()
	modal._thermo_metrics_lbl.add_theme_font_size_override("font_size", 12)
	modal._thermo_metrics_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	thermo_vbox.add_child(modal._thermo_metrics_lbl)

	modal.balance_status_label = Label.new()
	modal.balance_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.balance_status_label.add_theme_font_size_override("font_size", 12)
	thermo_vbox.add_child(modal.balance_status_label)


static func init_new_trait_or_decision(modal: Control) -> void:
	if modal._current_tab == "biological":
		modal.id_edit.text = modal._next_custom_id("bio")
		modal.name_edit.text = EvoUiStyle.tr_text(modal._lang, "Adaptación Metabólica", "Metabolic Adaptation")
		modal.desc_edit.text = EvoUiStyle.tr_text(
			modal._lang,
			"Rasgo biológico experimental diseñado en el laboratorio.",
			"Experimental biological trait crafted in the lab."
		)
		modal.enables_culture_check.button_pressed = false
		set_vector_to_sliders(modal, EvoTypes.BiophysicalVector.new(0.15, 0.30, 0.05, 0.20, 0.10, 0.20))
	else:
		modal.id_edit.text = modal._next_custom_id("cul")
		modal.name_edit.text = EvoUiStyle.tr_text(modal._lang, "Tradición Artesanal", "Artisanal Tradition")
		modal.desc_edit.text = EvoUiStyle.tr_text(
			modal._lang,
			"Práctica cultural transmitida socialmente entre generaciones.",
			"Socially transmitted cultural practice across generations."
		)
		set_vector_to_sliders(modal, EvoTypes.BiophysicalVector.new(0.20, 0.35, 0.15, 0.10, 0.35, 0.45))


static func save_trait_or_decision(modal: Control, clean_name: String, clean_desc: String) -> void:
	var raw_vec := read_vector_from_sliders(modal)
	var free_mode: bool = modal._world_state.free_sandbox_mode if modal._world_state != null else false
	var final_vec := raw_vec if free_mode else EvoUiStyle.balance_vector(raw_vec)
	set_vector_to_sliders(modal, final_vec)
	update_thermodynamics_preview(modal)

	var prefix := "bio" if modal._current_tab == "biological" else "cul"
	var tr := EvoTypes.TraitDef.new()
	tr.id = modal._resolve_target_id(prefix)
	tr.name = clean_name
	tr.description = clean_desc
	tr.category = modal._current_tab
	tr.origin = "user"
	tr.vector = final_vec
	tr.enables_cultural_transmission = modal.enables_culture_check.button_pressed if modal._current_tab == "biological" else false
	if modal._world_state != null and modal._world_state.traits_catalog.has(tr.id):
		var prev_tr: EvoTypes.TraitDef = modal._world_state.traits_catalog[tr.id]
		tr.mutually_exclusive_with = prev_tr.mutually_exclusive_with.duplicate()
	if modal._world_state != null:
		modal._world_state.traits_catalog[tr.id] = tr
		EvoUserSettings.save_user_catalog(modal._world_state)
	modal._selected_id = tr.id
	modal.id_edit.text = tr.id
	modal._rebuild_strategy_trait_checks()
	modal.catalog_item_saved.emit("trait", tr.to_dict())
	modal._rebuild_catalog_list()
	modal._update_labels()
	modal._show_saved_feedback(tr.id)


static func refresh_thermo_labels(modal: Control, is_strat: bool) -> void:
	modal.enables_culture_check.text = EvoUiStyle.tr_text(
		modal._lang,
		"Habilita transmisión cultural (enablesCulturalTransmission)",
		"Enables cultural transmission (enablesCulturalTransmission)"
	)

	modal.enables_culture_check.visible = (modal._current_tab == "biological")
	modal._sliders_card.visible = not is_strat
	modal._thermo_card.visible = not is_strat

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
	for s_key in modal.SLIDER_KEYS:
		var lbl: Label = modal._slider_title_labels[s_key]
		lbl.text = str(slider_names_en[s_key]) if modal._lang == "en" else str(slider_names_es[s_key])

	modal._thermo_title_lbl.text = EvoUiStyle.tr_text(
		modal._lang,
		"⚖️ Medidor de Equilibrio Termodinámico en Vivo",
		"⚖️ Live Thermodynamic Balance Meter"
	)
	modal.auto_balance_button.text = EvoUiStyle.tr_text(modal._lang, "Auto-Equilibrar Vector", "Auto-Balance Vector")


static func auto_balance_vector(modal: Control) -> void:
	var vec := read_vector_from_sliders(modal)
	var balanced := EvoUiStyle.balance_vector(vec)
	set_vector_to_sliders(modal, balanced)
	update_thermodynamics_preview(modal)


static func on_catalog_trait_clicked(modal: Control, trait_id: String) -> void:
	if modal._world_state == null or not modal._world_state.traits_catalog.has(trait_id):
		return
	var tr: EvoTypes.TraitDef = modal._world_state.traits_catalog[trait_id]
	modal._selected_id = tr.id
	modal.id_edit.text = tr.id
	modal.name_edit.text = EvoI18n.trait_name(modal._lang, tr)
	modal.desc_edit.text = EvoI18n.trait_description(modal._lang, tr)
	modal.enables_culture_check.button_pressed = tr.enables_cultural_transmission
	set_vector_to_sliders(modal, tr.vector)
	modal._feedback_lbl.text = ""
	modal._update_labels()
	modal._rebuild_catalog_list()
	update_thermodynamics_preview(modal)


static func set_vector_to_sliders(modal: Control, vec: EvoTypes.BiophysicalVector) -> void:
	modal._updating_sliders = true
	(modal.sliders["metabolic_cost"] as HSlider).value = vec.metabolic_cost
	(modal.sliders["extraction_efficiency"] as HSlider).value = vec.extraction_efficiency
	(modal.sliders["ecological_impact"] as HSlider).value = vec.ecological_impact
	(modal.sliders["spatial_mobility"] as HSlider).value = vec.spatial_mobility
	(modal.sliders["social_cohesion"] as HSlider).value = vec.social_cohesion
	(modal.sliders["transmission_threshold"] as HSlider).value = vec.transmission_threshold
	modal._updating_sliders = false
	refresh_slider_value_labels(modal)


static func read_vector_from_sliders(modal: Control) -> EvoTypes.BiophysicalVector:
	return EvoTypes.BiophysicalVector.new(
		snappedf((modal.sliders["metabolic_cost"] as HSlider).value, 0.01),
		snappedf((modal.sliders["extraction_efficiency"] as HSlider).value, 0.01),
		snappedf((modal.sliders["ecological_impact"] as HSlider).value, 0.01),
		snappedf((modal.sliders["spatial_mobility"] as HSlider).value, 0.01),
		snappedf((modal.sliders["social_cohesion"] as HSlider).value, 0.01),
		snappedf((modal.sliders["transmission_threshold"] as HSlider).value, 0.01)
	)


static func refresh_slider_value_labels(modal: Control) -> void:
	for s_key in modal.SLIDER_KEYS:
		var val: float = (modal.sliders[s_key] as HSlider).value
		var lbl: Label = modal._slider_val_labels[s_key]
		lbl.text = "%+.2f" % val if s_key != "transmission_threshold" else "%.2f" % val


static func update_thermodynamics_preview(modal: Control) -> void:
	if modal._thermo_metrics_lbl == null:
		return
	refresh_slider_value_labels(modal)
	var vec := read_vector_from_sliders(modal)
	var free_mode: bool = modal._world_state.free_sandbox_mode if modal._world_state != null else false
	var eval_res := EvoUiStyle.evaluate_thermodynamics(vec, free_mode)
	var a_plus: float = float(eval_res["a_plus"])
	var c_actual: float = float(eval_res["c_actual"])
	var c_req: float = float(eval_res["c_req"])
	var is_bal: bool = bool(eval_res["is_balanced"])
	var bal_vec: EvoTypes.BiophysicalVector = eval_res["balanced_vector"]

	modal.balance_bar.value = clampf(a_plus, modal.balance_bar.min_value, modal.balance_bar.max_value)
	EvoUiStyle.style_progress_bar(modal.balance_bar, EvoUiStyle.COLOR_GREEN_OK if is_bal else EvoUiStyle.COLOR_AMBER_WARN)

	modal._thermo_metrics_lbl.text = EvoUiStyle.tr_text(
		modal._lang,
		"Ventajas Positivas (A+): %.2f   |   Coste Actual (C_actual): %.2f   |   Coste Requerido (C_req): %.2f" % [a_plus, c_actual, c_req],
		"Positive Advantages (A+): %.2f   |   Actual Cost (C_actual): %.2f   |   Required Cost (C_req): %.2f" % [a_plus, c_actual, c_req]
	)

	if is_bal:
		modal.balance_status_label.text = EvoUiStyle.tr_text(
			modal._lang,
			"✓ Cumple la Ley de Conservación Termodinámica (C_actual >= C_req).",
			"✓ Complies with the Law of Thermodynamic Conservation (C_actual >= C_req)."
		)
		modal.balance_status_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	else:
		modal.balance_status_label.text = EvoUiStyle.tr_text(
			modal._lang,
			"⚠ Exceso de ventaja sin coste: al guardar se auto-equilibrará a Coste Metabólico = %+.2f, Impacto Eco = %+.2f." % [bal_vec.metabolic_cost, bal_vec.ecological_impact],
			"⚠ Uncompensated advantage: saving will auto-balance to Metabolic Cost = %+.2f, Eco Impact = %+.2f." % [bal_vec.metabolic_cost, bal_vec.ecological_impact]
		)
		modal.balance_status_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_AMBER_WARN)


static func on_slider_value_changed(modal: Control, _val: float, _key: String) -> void:
	if modal._updating_sliders:
		return
	update_thermodynamics_preview(modal)
