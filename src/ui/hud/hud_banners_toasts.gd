class_name EvoHudBannersToasts
extends RefCounted


static func build_banners_and_toasts(hud: Control) -> void:
	# Top-Center Golden Parchment Milestone / Outcome Banner
	hud._milestone_banner = PanelContainer.new()
	hud._milestone_banner.visible = false
	hud._milestone_banner.anchor_left = 0.5
	hud._milestone_banner.anchor_right = 0.5
	hud._milestone_banner.anchor_top = 0.0
	hud._milestone_banner.anchor_bottom = 0.0
	hud._milestone_banner.offset_left = -220
	hud._milestone_banner.offset_right = 220
	hud._milestone_banner.offset_top = 12
	hud._milestone_banner.offset_bottom = 92
	hud._milestone_banner.z_index = 25
	var banner_style := EvoUiStyle.make_parchment_card(Color("#fef3c7"), EvoUiStyle.COLOR_GOLD_BRIGHT, 8)
	banner_style.border_width_left = 4
	banner_style.border_width_right = 4
	banner_style.border_width_top = 3
	banner_style.border_width_bottom = 3
	hud._milestone_banner.add_theme_stylebox_override("panel", banner_style)
	hud.add_child(hud._milestone_banner)

	var b_hbox := HBoxContainer.new()
	b_hbox.add_theme_constant_override("separation", 8)
	hud._milestone_banner.add_child(b_hbox)

	var b_vbox := VBoxContainer.new()
	b_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_vbox.add_theme_constant_override("separation", 3)
	b_hbox.add_child(b_vbox)

	hud._banner_title_lbl = Label.new()
	hud._banner_title_lbl.add_theme_font_size_override("font_size", 14)
	hud._banner_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._banner_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_vbox.add_child(hud._banner_title_lbl)

	hud._banner_summary_lbl = Label.new()
	hud._banner_summary_lbl.add_theme_font_size_override("font_size", 11)
	hud._banner_summary_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	hud._banner_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_vbox.add_child(hud._banner_summary_lbl)

	var close_banner_btn := Button.new()
	close_banner_btn.text = "✕"
	close_banner_btn.pressed.connect(func() -> void: hud._milestone_banner.visible = false)
	b_hbox.add_child(close_banner_btn)

	# Bottom-Left Chronicle Toast Stack
	hud._toast_vbox = VBoxContainer.new()
	hud._toast_vbox.anchor_left = 0.0
	hud._toast_vbox.anchor_right = 0.0
	hud._toast_vbox.anchor_top = 1.0
	hud._toast_vbox.anchor_bottom = 1.0
	hud._toast_vbox.offset_left = 10
	hud._toast_vbox.offset_right = 310
	hud._toast_vbox.offset_top = -240
	hud._toast_vbox.offset_bottom = -16
	hud._toast_vbox.alignment = BoxContainer.ALIGNMENT_END
	hud._toast_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._toast_vbox.add_theme_constant_override("separation", 5)
	hud.add_child(hud._toast_vbox)

	# Compact Collapsible First-Steps Quest Note (Hidden by default to keep bottom-left clear)
	hud._first_steps_panel = PanelContainer.new()
	hud._first_steps_panel.visible = false
	hud._first_steps_panel.anchor_left = 0.0
	hud._first_steps_panel.anchor_right = 0.0
	hud._first_steps_panel.anchor_top = 1.0
	hud._first_steps_panel.anchor_bottom = 1.0
	hud._first_steps_panel.offset_left = 10
	hud._first_steps_panel.offset_right = 278
	hud._first_steps_panel.offset_top = -88
	hud._first_steps_panel.offset_bottom = -8
	hud._first_steps_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(5))
	hud.add_child(hud._first_steps_panel)

	var fs_hbox := HBoxContainer.new()
	fs_hbox.add_theme_constant_override("separation", 6)
	hud._first_steps_panel.add_child(fs_hbox)

	var fs_vbox := VBoxContainer.new()
	fs_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_vbox.add_theme_constant_override("separation", 1)
	fs_hbox.add_child(fs_vbox)

	hud._step1_lbl = Label.new()
	hud._step1_lbl.add_theme_font_size_override("font_size", 10)
	fs_vbox.add_child(hud._step1_lbl)

	hud._step2_lbl = Label.new()
	hud._step2_lbl.add_theme_font_size_override("font_size", 10)
	fs_vbox.add_child(hud._step2_lbl)

	hud._step3_lbl = Label.new()
	hud._step3_lbl.add_theme_font_size_override("font_size", 10)
	fs_vbox.add_child(hud._step3_lbl)

	var hide_fs_btn := Button.new()
	hide_fs_btn.text = "✕"
	hide_fs_btn.custom_minimum_size = Vector2(22, 22)
	hide_fs_btn.pressed.connect(func() -> void: hud._first_steps_panel.visible = false)
	fs_hbox.add_child(hide_fs_btn)

	# Startup Ollama Offline / Missing Decision Models Modal (Full-Screen Blocking Backdrop)
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


static func show_ollama_offline_popup(hud: Control) -> void:
	if hud._missing_models_modal == null:
		return
	hud._set_startup_blocked(true)
	hud._missing_models_title_lbl.text = EvoUiStyle.tr_text(
		hud._lang,
		"⚠️ Ollama Está Offline",
		"⚠️ Ollama Is Offline"
	)
	hud._missing_models_desc_lbl.text = EvoUiStyle.tr_text(
		hud._lang,
		"No se ha podido conectar con el servidor local de Ollama (http://127.0.0.1:11434).\n\nEvolution requiere que Ollama esté activo para que los modelos de decisión dirijan las poblaciones. El juego no puede iniciarse con Ollama offline.",
		"Could not connect to the local Ollama server (http://127.0.0.1:11434).\n\nEvolution requires Ollama to be running so decision models can govern populations. The game cannot start while Ollama is offline."
	)
	hud._missing_models_progress_bar.visible = false
	hud._missing_models_progress_bar.value = 0.0
	hud._missing_models_status_lbl.visible = false
	hud._missing_models_download_btn.visible = false
	hud._missing_models_skip_btn.text = EvoUiStyle.tr_text(
		hud._lang,
		"Cerrar aplicación",
		"Close application"
	)
	hud._missing_models_modal.visible = true


static func show_missing_models_popup(hud: Control, missing_models: Array) -> void:
	if hud._missing_models_modal == null or missing_models.is_empty():
		return
	hud._set_startup_blocked(true)
	var models_str := ", ".join(PackedStringArray(missing_models))
	hud._missing_models_title_lbl.text = EvoUiStyle.tr_text(
		hud._lang,
		"⬇️ Modelos de Decisión No Descargados",
		"⬇️ Missing Decision Models"
	)
	hud._missing_models_desc_lbl.text = EvoUiStyle.tr_text(
		hud._lang,
		"Los siguientes modelos de decisión configurados no están descargados en Ollama:\n• %s\n\nEvolution requiere modelos de decisión activos para iniciar la simulación." % models_str,
		"The following configured decision models are not downloaded in Ollama:\n• %s\n\nEvolution requires active decision models to start the simulation." % models_str
	)
	hud._missing_models_progress_bar.visible = false
	hud._missing_models_progress_bar.value = 0.0
	hud._missing_models_status_lbl.visible = false
	hud._missing_models_download_btn.visible = true
	hud._missing_models_download_btn.disabled = false
	hud._missing_models_download_btn.text = EvoUiStyle.tr_text(
		hud._lang,
		"⬇️ Descargar automáticamente",
		"⬇️ Download automatically"
	)
	hud._missing_models_skip_btn.text = EvoUiStyle.tr_text(
		hud._lang,
		"Cerrar aplicación",
		"Close application"
	)
	hud._missing_models_modal.visible = true


static func process_toasts(toast_vbox: VBoxContainer, delta: float) -> void:
	if toast_vbox == null:
		return
	for child in toast_vbox.get_children():
		if child.has_meta("ttl"):
			var ttl: float = float(child.get_meta("ttl")) - delta
			if ttl <= 0.0:
				child.queue_free()
			else:
				child.set_meta("ttl", ttl)
				if ttl < 1.0:
					(child as CanvasItem).modulate.a = clampf(ttl, 0.0, 1.0)


static func show_milestone_banner(hud: Control, title: String, summary: String, is_macro: bool = false) -> void:
	if hud._milestone_banner == null:
		return
	hud._banner_title_lbl.text = ("🏆 " if is_macro else "🌟 ") + title
	hud._banner_summary_lbl.text = summary
	hud._milestone_banner.visible = true


static func _clean_toast_title(raw_title: String) -> String:
	var cleaned := raw_title.strip_edges()
	for prefix in ["Hito Evolutivo en ", "Evolutionary Milestone in ", "Pérdida Cultural: ", "Cultural Loss: "]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
			break
	return cleaned


static func push_chronicle_toast(hud: Control, entry: EvoTypes.ChronicleEntry) -> void:
	if hud._toast_vbox == null:
		return

	var header_text := "G%d · %s · 📍(%s)" % [
		entry.generation,
		EvoUiStyle.get_event_type_label(entry.event_type, hud._lang),
		entry.hex_id
	]
	var body_text := _clean_toast_title(entry.title)

	if hud._toast_vbox.get_child_count() > 0:
		var newest: Node = hud._toast_vbox.get_child(hud._toast_vbox.get_child_count() - 1)
		if int(newest.get_meta("generation", -1)) == entry.generation and str(newest.get_meta("event_type", "")) == entry.event_type:
			var top_existing := newest.get_meta("top_lbl") as Label
			var title_existing := newest.get_meta("title_lbl") as Label
			top_existing.text = header_text
			title_existing.text = body_text
			newest.set_meta("ttl", 3.8)
			(newest as CanvasItem).modulate.a = 1.0
			return

	while hud._toast_vbox.get_child_count() >= 2:
		var oldest: Node = hud._toast_vbox.get_child(0)
		hud._toast_vbox.remove_child(oldest)
		oldest.queue_free()

	var ev_color := EvoUiStyle.get_event_type_color(entry.event_type)
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_meta("ttl", 3.8)
	toast.set_meta("generation", entry.generation)
	toast.set_meta("event_type", entry.event_type)
	var style := EvoUiStyle.make_parchment_card(Color("#fbf2de"), ev_color, 5)
	style.border_width_left = 4
	toast.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	toast.add_child(vbox)

	var top_lbl := Label.new()
	top_lbl.text = header_text
	top_lbl.add_theme_font_size_override("font_size", 10)
	top_lbl.add_theme_color_override("font_color", ev_color)
	vbox.add_child(top_lbl)

	var title_lbl := Label.new()
	title_lbl.text = body_text
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.max_lines_visible = 2
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	vbox.add_child(title_lbl)

	toast.set_meta("top_lbl", top_lbl)
	toast.set_meta("title_lbl", title_lbl)
	hud._toast_vbox.add_child(toast)


static func update_first_steps_labels(hud: Control) -> void:
	if hud._step1_lbl == null:
		return
	var c1 := "☑" if hud._step_1_done else "☐"
	var c2 := "☑" if hud._step_2_done else "☐"
	var c3 := "☑" if hud._step_3_done else "☐"

	hud._step1_lbl.text = EvoUiStyle.tr_text(hud._lang, "%s 1. Seleccionar aldea" % c1, "%s 1. Select village" % c1)
	hud._step2_lbl.text = EvoUiStyle.tr_text(hud._lang, "%s 2. Usar herramienta (1-0)" % c2, "%s 2. Use tool (1-0)" % c2)
	hud._step3_lbl.text = EvoUiStyle.tr_text(hud._lang, "%s 3. Avanzar generación" % c3, "%s 3. Advance generation" % c3)

	hud._step1_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT if hud._step_1_done else EvoUiStyle.COLOR_CREAM_TEXT)
	hud._step2_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT if hud._step_2_done else EvoUiStyle.COLOR_CREAM_TEXT)
	hud._step3_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT if hud._step_3_done else EvoUiStyle.COLOR_CREAM_TEXT)
