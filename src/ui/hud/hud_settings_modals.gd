class_name EvoHudSettingsModals
extends RefCounted


static func build_settings_popup(hud: Control) -> void:
	hud._settings_popup = PanelContainer.new()
	hud._settings_popup.visible = false
	hud._settings_popup.anchor_left = 1.0
	hud._settings_popup.anchor_right = 1.0
	hud._settings_popup.anchor_top = 0.0
	hud._settings_popup.anchor_bottom = 0.0
	hud._settings_popup.offset_left = -736
	hud._settings_popup.offset_right = -364
	hud._settings_popup.offset_top = 10
	hud._settings_popup.offset_bottom = 450
	hud._settings_popup.z_index = 30
	hud._settings_popup.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(8))
	hud.add_child(hud._settings_popup)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(8, false))
	hud._settings_popup.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	inner.add_child(vbox)

	# System 1 Ollama Models Diagnostic & Selection Card
	var diag_card := PanelContainer.new()
	diag_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_GOLD_BEVEL, 6))
	vbox.add_child(diag_card)

	var diag_vbox := VBoxContainer.new()
	diag_vbox.add_theme_constant_override("separation", 5)
	diag_card.add_child(diag_vbox)

	hud._models_diag_lbl = Label.new()
	hud._models_diag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._models_diag_lbl.add_theme_font_size_override("font_size", 11)
	hud._models_diag_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	diag_vbox.add_child(hud._models_diag_lbl)

	# Primary Decision Model Row
	var p_row := HBoxContainer.new()
	p_row.add_theme_constant_override("separation", 6)
	diag_vbox.add_child(p_row)

	hud._primary_model_lbl = Label.new()
	hud._primary_model_lbl.custom_minimum_size = Vector2(140, 0)
	hud._primary_model_lbl.add_theme_font_size_override("font_size", 11)
	hud._primary_model_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	p_row.add_child(hud._primary_model_lbl)

	hud._primary_model_opt = OptionButton.new()
	hud._primary_model_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._primary_model_opt.fit_to_longest_item = false
	hud._primary_model_opt.clip_text = true
	hud._primary_model_opt.add_theme_font_size_override("font_size", 11)
	hud._primary_model_opt.item_selected.connect(hud._on_primary_model_selected)
	p_row.add_child(hud._primary_model_opt)

	# Secondary Decision Model Row
	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 6)
	diag_vbox.add_child(s_row)

	hud._secondary_model_lbl = Label.new()
	hud._secondary_model_lbl.custom_minimum_size = Vector2(140, 0)
	hud._secondary_model_lbl.add_theme_font_size_override("font_size", 11)
	hud._secondary_model_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	s_row.add_child(hud._secondary_model_lbl)

	hud._secondary_model_opt = OptionButton.new()
	hud._secondary_model_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._secondary_model_opt.fit_to_longest_item = false
	hud._secondary_model_opt.clip_text = true
	hud._secondary_model_opt.add_theme_font_size_override("font_size", 11)
	hud._secondary_model_opt.item_selected.connect(hud._on_secondary_model_selected)
	s_row.add_child(hud._secondary_model_opt)

	# Context Window Size (Free Input Field)
	var ctx_row := HBoxContainer.new()
	ctx_row.add_theme_constant_override("separation", 6)
	diag_vbox.add_child(ctx_row)

	hud._context_window_lbl = Label.new()
	hud._context_window_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._context_window_lbl.add_theme_font_size_override("font_size", 11)
	hud._context_window_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	ctx_row.add_child(hud._context_window_lbl)

	hud._context_window_input = LineEdit.new()
	hud._context_window_input.custom_minimum_size = Vector2(96, 24)
	hud._context_window_input.text = str(EvoUserSettings.context_length)
	hud._context_window_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._context_window_input.add_theme_font_size_override("font_size", 11)
	hud._context_window_input.text_submitted.connect(hud._on_context_window_submitted)
	hud._context_window_input.focus_exited.connect(hud._on_context_window_focus_exited)
	ctx_row.add_child(hud._context_window_input)

	# Dedicated Full-Width Refresh Models Button
	hud._refresh_models_btn = Button.new()
	hud._refresh_models_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._refresh_models_btn.add_theme_font_size_override("font_size", 11)
	hud._refresh_models_btn.pressed.connect(hud._on_refresh_models_pressed)
	diag_vbox.add_child(hud._refresh_models_btn)

	# Language Row
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 6)
	vbox.add_child(lang_row)

	var lang_lbl := Label.new()
	lang_lbl.text = "🌐 Idioma / Language:"
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_lbl)

	hud._lang_es_btn = Button.new()
	hud._lang_es_btn.text = "ES"
	hud._lang_es_btn.pressed.connect(hud._on_lang_selected.bind("es"))
	lang_row.add_child(hud._lang_es_btn)

	hud._lang_en_btn = Button.new()
	hud._lang_en_btn.text = "EN"
	hud._lang_en_btn.pressed.connect(hud._on_lang_selected.bind("en"))
	lang_row.add_child(hud._lang_en_btn)

	hud._auto_pause_check = CheckBox.new()
	hud._auto_pause_check.toggled.connect(hud._on_settings_toggled)
	vbox.add_child(hud._auto_pause_check)

	hud._unlimited_pressure_check = CheckBox.new()
	hud._unlimited_pressure_check.toggled.connect(hud._on_settings_toggled)
	vbox.add_child(hud._unlimited_pressure_check)

	hud._free_sandbox_check = CheckBox.new()
	hud._free_sandbox_check.toggled.connect(hud._on_settings_toggled)
	vbox.add_child(hud._free_sandbox_check)

	hud._cam_lbl = Label.new()
	hud._cam_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	vbox.add_child(hud._cam_lbl)

	var cam_flow := HFlowContainer.new()
	cam_flow.add_theme_constant_override("h_separation", 5)
	cam_flow.add_theme_constant_override("v_separation", 5)
	vbox.add_child(cam_flow)

	for deg in [32.0, 48.0, 68.0]:
		var b := Button.new()
		b.text = "%d°" % int(deg)
		b.pressed.connect(hud._on_cam_preset_pressed.bind("pitch", deg))
		cam_flow.add_child(b)

	var fit_cam_btn := Button.new()
	fit_cam_btn.text = "Mapa"
	fit_cam_btn.tooltip_text = "Vista de mapa completo (Tecla F / 0)"
	fit_cam_btn.pressed.connect(hud._on_cam_preset_pressed.bind("fit", 0.0))
	cam_flow.add_child(fit_cam_btn)

	var reset_cam_btn := Button.new()
	reset_cam_btn.text = "🎯 Reset"
	reset_cam_btn.pressed.connect(hud._on_cam_preset_pressed.bind("reset", 0.0))
	cam_flow.add_child(reset_cam_btn)


static func build_missing_models_modal(hud: Control) -> void:
	hud._missing_models_modal = ColorRect.new()
	hud._missing_models_modal.visible = false
	hud._missing_models_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud._missing_models_modal.color = Color(0.06, 0.04, 0.03, 0.72)
	hud._missing_models_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._missing_models_modal.z_index = 60
	hud.add_child(hud._missing_models_modal)

	var mm_card := PanelContainer.new()
	mm_card.anchor_left = 0.5
	mm_card.anchor_right = 0.5
	mm_card.anchor_top = 0.5
	mm_card.anchor_bottom = 0.5
	mm_card.offset_left = -230
	mm_card.offset_right = 230
	mm_card.offset_top = -120
	mm_card.offset_bottom = 120
	mm_card.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(8))
	hud._missing_models_modal.add_child(mm_card)

	var mm_inner := PanelContainer.new()
	mm_inner.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(10, false))
	mm_card.add_child(mm_inner)

	var mm_vbox := VBoxContainer.new()
	mm_vbox.add_theme_constant_override("separation", 8)
	mm_inner.add_child(mm_vbox)

	hud._missing_models_title_lbl = Label.new()
	hud._missing_models_title_lbl.add_theme_font_size_override("font_size", 14)
	hud._missing_models_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._missing_models_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mm_vbox.add_child(hud._missing_models_title_lbl)

	hud._missing_models_desc_lbl = Label.new()
	hud._missing_models_desc_lbl.add_theme_font_size_override("font_size", 11)
	hud._missing_models_desc_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	hud._missing_models_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mm_vbox.add_child(hud._missing_models_desc_lbl)

	hud._missing_models_progress_bar = ProgressBar.new()
	hud._missing_models_progress_bar.visible = false
	hud._missing_models_progress_bar.min_value = 0.0
	hud._missing_models_progress_bar.max_value = 100.0
	hud._missing_models_progress_bar.value = 0.0
	hud._missing_models_progress_bar.show_percentage = true
	hud._missing_models_progress_bar.custom_minimum_size = Vector2(0, 16)
	EvoUiStyle.style_progress_bar(hud._missing_models_progress_bar, EvoUiStyle.COLOR_GREEN_OK)
	mm_vbox.add_child(hud._missing_models_progress_bar)

	hud._missing_models_status_lbl = Label.new()
	hud._missing_models_status_lbl.visible = false
	hud._missing_models_status_lbl.add_theme_font_size_override("font_size", 11)
	hud._missing_models_status_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	hud._missing_models_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mm_vbox.add_child(hud._missing_models_status_lbl)

	var mm_btns := HBoxContainer.new()
	mm_btns.alignment = BoxContainer.ALIGNMENT_END
	mm_btns.add_theme_constant_override("separation", 8)
	mm_vbox.add_child(mm_btns)

	hud._missing_models_skip_btn = Button.new()
	hud._missing_models_skip_btn.pressed.connect(hud._on_missing_models_skip_pressed)
	mm_btns.add_child(hud._missing_models_skip_btn)

	hud._missing_models_download_btn = Button.new()
	hud._missing_models_download_btn.pressed.connect(hud._on_missing_models_download_pressed)
	mm_btns.add_child(hud._missing_models_download_btn)


static func refresh_settings_static_labels(hud: Control) -> void:
	EvoUiStyle.apply_button_active(hud._lang_es_btn, hud._lang == "es")
	EvoUiStyle.apply_button_active(hud._lang_en_btn, hud._lang == "en")

	hud._primary_model_lbl.text = EvoUiStyle.tr_text(hud._lang, "Primario (Táctico):", "Primary (Tactical):")
	hud._secondary_model_lbl.text = EvoUiStyle.tr_text(hud._lang, "Secundario (Ecológico):", "Secondary (Ecological):")
	hud._refresh_models_btn.text = EvoUiStyle.tr_text(hud._lang, "🔄 Actualizar modelos de decisión", "🔄 Refresh decision models")
	hud._refresh_models_btn.tooltip_text = EvoUiStyle.tr_text(
		hud._lang,
		"Volver a consultar en Ollama los modelos de decisión descargados en la máquina",
		"Re-query Ollama for downloaded decision models on this machine"
	)
	hud._context_window_lbl.text = EvoUiStyle.tr_text(hud._lang, "Ventana de contexto (num_ctx):", "Context window (num_ctx):")
	if not hud._context_window_input.has_focus():
		hud._context_window_input.text = str(EvoUserSettings.context_length)
	refresh_decision_model_selectors(hud)
	hud._auto_pause_check.text = EvoUiStyle.tr_text(hud._lang, "Auto-pausa en hitos", "Auto-pause on milestones")
	hud._unlimited_pressure_check.text = EvoUiStyle.tr_text(hud._lang, "Energía Ilimitada", "Unlimited Energy")
	hud._free_sandbox_check.text = EvoUiStyle.tr_text(hud._lang, "Sandbox Libre", "Free Sandbox")
	hud._cam_lbl.text = EvoUiStyle.tr_text(hud._lang, "🎥 Ángulo y Rotación de Cámara:", "🎥 Camera Angle & Orbit:")


static func refresh_settings_popup(hud: Control) -> void:
	if hud._world_state == null:
		return
	var p_model := EvoUserSettings.primary_model
	var s_model := EvoUserSettings.secondary_model
	var ctx_len := EvoUserSettings.context_length
	var primary_count := 0
	var secondary_count := 0
	var avg_conf := 0.0
	for d_key in hud._world_state.demes.keys():
		var d: EvoTypes.Deme = hud._world_state.demes[d_key]
		if p_model == s_model:
			if EvoDecisionModel.resolve_deme_decision_model_tag(d.id, "__primary__", "__secondary__") == "__secondary__":
				secondary_count += 1
			else:
				primary_count += 1
		elif d.decision_model_tag == s_model:
			secondary_count += 1
		elif d.decision_model_tag == p_model:
			primary_count += 1
		elif EvoDecisionModel.resolve_deme_decision_model_tag(d.id, "__primary__", "__secondary__") == "__secondary__":
			secondary_count += 1
		else:
			primary_count += 1
		avg_conf += d.last_confidence
	if not hud._world_state.demes.is_empty():
		avg_conf /= float(hud._world_state.demes.size())

	hud._settings_btn.text = ""
	hud._settings_btn.icon = EvoUiStyle.get_pixel_icon("settings_gear")
	hud._settings_btn.tooltip_text = "🧠 %s (%d) · %s (%d) · ctx %d" % [p_model, primary_count, s_model, secondary_count, ctx_len]
	hud._models_diag_lbl.text = EvoUiStyle.tr_text(
		hud._lang,
		"🧠 Motores Cognitivos:\n• %s (Táctico/Instinto): %d aldeas\n• %s (Ecológico/Estratégico): %d aldeas\n• Ventana de contexto: %d · Confianza media: %d%%" % [p_model, primary_count, s_model, secondary_count, ctx_len, int(round(avg_conf * 100.0))],
		"🧠 Cognitive Engines:\n• %s (Tactical/Instinct): %d villages\n• %s (Ecological/Strategic): %d villages\n• Context window: %d · Avg confidence: %d%%" % [p_model, primary_count, s_model, secondary_count, ctx_len, int(round(avg_conf * 100.0))]
	)
	if (hud._settings_popup != null and hud._settings_popup.visible) or (hud._primary_model_opt != null and hud._primary_model_opt.item_count == 0):
		refresh_decision_model_selectors(hud)

	hud._auto_pause_check.set_pressed_no_signal(hud._world_state.auto_pause_on_milestone)
	hud._unlimited_pressure_check.set_pressed_no_signal(hud._world_state.unlimited_pressure_mode)
	hud._free_sandbox_check.set_pressed_no_signal(hud._world_state.free_sandbox_mode)


static func refresh_decision_model_selectors(hud: Control) -> void:
	if hud._primary_model_opt == null or hud._secondary_model_opt == null:
		return
	var status := EvoDecisionModel.check_ollama_status(false)
	var decision_models: Array = status["decision_models"] if status.has("decision_models") else []
	var p_model := EvoUserSettings.primary_model
	var s_model := EvoUserSettings.secondary_model

	hud._primary_model_opt.clear()
	hud._secondary_model_opt.clear()

	if decision_models.is_empty():
		var empty_lbl := EvoUiStyle.tr_text(hud._lang, "Sin modelos de decisión descargados", "No decision models downloaded")
		hud._primary_model_opt.add_item("%s (%s)" % [p_model, empty_lbl], 0)
		hud._primary_model_opt.set_item_metadata(0, p_model)
		hud._primary_model_opt.disabled = true
		hud._secondary_model_opt.add_item("%s (%s)" % [s_model, empty_lbl], 0)
		hud._secondary_model_opt.set_item_metadata(0, s_model)
		hud._secondary_model_opt.disabled = true
		return

	hud._primary_model_opt.disabled = false
	hud._secondary_model_opt.disabled = false

	var p_idx := 0
	var s_idx := 0
	for i in range(decision_models.size()):
		var m_tag := str(decision_models[i])
		hud._primary_model_opt.add_item(m_tag, i)
		hud._primary_model_opt.set_item_metadata(i, m_tag)
		if m_tag == p_model:
			p_idx = i

		hud._secondary_model_opt.add_item(m_tag, i)
		hud._secondary_model_opt.set_item_metadata(i, m_tag)
		if m_tag == s_model:
			s_idx = i

	hud._primary_model_opt.select(p_idx)
	hud._secondary_model_opt.select(s_idx)
