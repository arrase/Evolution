class_name EvoHudBannersToasts
extends RefCounted

const EVENT_FEED_FILTER_IDS: Array[String] = [
	"all",
	"war",
	"diplomacy",
	"health",
	"evolution"
]

const EVENT_FEED_FILTER_MAP: Dictionary = {
	"war": ["war", "war_repelled", "siege", "raid", "betrayal", "pillage"],
	"diplomacy": ["pact", "tribute", "merge", "walled_union", "absorption", "colonize"],
	"health": ["epidemic", "epidemic_spread", "epidemic_recovered", "famine", "tragedy_of_commons"],
	"evolution": [
		"baldwin_trait", "cultural_innovation", "allopatric_speciation", "symbiosis",
		"cultural_loss", "extinction", "total_extinction", "single_survivor",
		"ecological_equilibrium", "fortify"
	]
}


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
	hud._milestone_banner.offset_top = 76
	hud._milestone_banner.offset_bottom = 156
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

	EvoHudSettingsModals.build_missing_models_modal(hud)


static func build_event_feed_panel(hud: Control) -> void:
	hud._event_feed_panel = PanelContainer.new()
	hud._event_feed_panel.anchor_left = 0.0
	hud._event_feed_panel.anchor_right = 0.0
	hud._event_feed_panel.anchor_top = 1.0
	hud._event_feed_panel.anchor_bottom = 1.0
	hud._event_feed_panel.offset_left = 10
	hud._event_feed_panel.offset_right = 380
	hud._event_feed_panel.offset_top = -270
	hud._event_feed_panel.offset_bottom = -10
	hud._event_feed_panel.z_index = 18
	hud._event_feed_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(5))
	hud.add_child(hud._event_feed_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	hud._event_feed_panel.add_child(outer_vbox)

	# Header Row: Title + Filter Pills + Collapse Button
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 3)
	outer_vbox.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT)
	header_row.add_child(title_lbl)

	var filter_btns: Dictionary = {}
	for f_id in EVENT_FEED_FILTER_IDS:
		var f_btn := Button.new()
		f_btn.custom_minimum_size = Vector2(26, 22)
		f_btn.add_theme_font_size_override("font_size", 10)
		f_btn.pressed.connect(func() -> void:
			hud._event_feed_filter = f_id
			refresh_event_feed(hud)
		)
		header_row.add_child(f_btn)
		filter_btns[f_id] = f_btn

	var body_card := PanelContainer.new()
	body_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(5, false))
	outer_vbox.add_child(body_card)

	var collapse_btn := Button.new()
	collapse_btn.text = "▾"
	collapse_btn.custom_minimum_size = Vector2(22, 22)
	collapse_btn.add_theme_font_size_override("font_size", 10)
	collapse_btn.pressed.connect(func() -> void:
		hud._event_feed_collapsed = not hud._event_feed_collapsed
		body_card.visible = not hud._event_feed_collapsed
		collapse_btn.text = "▸" if hud._event_feed_collapsed else "▾"
		hud._event_feed_panel.offset_top = -46 if hud._event_feed_collapsed else -270
	)
	header_row.add_child(collapse_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_card.add_child(scroll)

	hud._event_feed_vbox = VBoxContainer.new()
	hud._event_feed_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._event_feed_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(hud._event_feed_vbox)

	hud.set_meta("_event_feed_title_lbl", title_lbl)
	hud.set_meta("_event_feed_filter_btns", filter_btns)


static func refresh_event_feed(hud: Control) -> void:
	if hud._event_feed_panel == null or hud._event_feed_vbox == null:
		return

	var lang: String = hud._lang
	var title_lbl := hud.get_meta("_event_feed_title_lbl") as Label
	title_lbl.text = EvoUiStyle.tr_text(lang, "📜 Crónica en Vivo", "📜 Live Chronicle")

	var filter_btns: Dictionary = hud.get_meta("_event_feed_filter_btns")
	for f_id in EVENT_FEED_FILTER_IDS:
		var btn := filter_btns[f_id] as Button
		btn.text = _filter_short_label(lang, f_id)
		btn.tooltip_text = _filter_tooltip_label(lang, f_id)
		EvoUiStyle.apply_button_active(btn, hud._event_feed_filter == f_id)

	if hud._world_state == null:
		for child in hud._event_feed_vbox.get_children():
			hud._event_feed_vbox.remove_child(child)
			child.queue_free()
		hud.set_meta("_last_event_feed_key", "")
		return

	var state: EvoTypes.WorldState = hud._world_state
	var active_filter: String = hud._event_feed_filter
	var last_entry_id: String = (state.chronicle[-1] as EvoTypes.ChronicleEntry).id if not state.chronicle.is_empty() else ""
	var feed_key := "%d:%d:%s:%s:%s:%d" % [
		state.get_instance_id(),
		state.generation,
		last_entry_id,
		active_filter,
		lang,
		state.chronicle.size()
	]
	if str(hud.get_meta("_last_event_feed_key", "")) == feed_key and hud._event_feed_vbox.get_child_count() > 0:
		return
	hud.set_meta("_last_event_feed_key", feed_key)

	for child in hud._event_feed_vbox.get_children():
		hud._event_feed_vbox.remove_child(child)
		child.queue_free()

	var allowed_types: Array = EVENT_FEED_FILTER_MAP[active_filter] if EVENT_FEED_FILTER_MAP.has(active_filter) else []

	var shown := 0
	for i in range(state.chronicle.size() - 1, -1, -1):
		var entry: EvoTypes.ChronicleEntry = state.chronicle[i]
		if active_filter != "all" and not (entry.event_type in allowed_types):
			continue
		var ev_color := EvoUiStyle.get_event_type_color(entry.event_type)
		var is_current := (entry.generation == state.generation)

		var row_btn := Button.new()
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.clip_text = true
		row_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row_btn.custom_minimum_size = Vector2(0, 24)
		row_btn.add_theme_font_size_override("font_size", 10)
		row_btn.text = "G%d · (%s) · %s" % [
			entry.generation,
			entry.hex_id,
			_clean_toast_title(entry.title)
		]
		row_btn.tooltip_text = "%s\n%s" % [entry.title, entry.causal_explanation]

		var bg_col := Color("#fff8db") if is_current else Color("#fbf2de")
		var border_col := ev_color.lightened(0.15) if is_current else ev_color
		var normal_style := EvoUiStyle.make_parchment_card(bg_col, border_col, 4)
		normal_style.border_width_left = 4
		var hover_style := EvoUiStyle.make_parchment_card(Color("#fef08a"), border_col, 4)
		hover_style.border_width_left = 4
		row_btn.add_theme_stylebox_override("normal", normal_style)
		row_btn.add_theme_stylebox_override("hover", hover_style)
		row_btn.add_theme_stylebox_override("pressed", hover_style)
		row_btn.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK if is_current else EvoUiStyle.COLOR_INK)
		row_btn.pressed.connect(hud._on_modal_jump_to_hex.bind(entry.hex_id, entry.deme_id))
		hud._event_feed_vbox.add_child(row_btn)

		shown += 1
		if shown >= 30:
			break

	if shown == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = EvoUiStyle.tr_text(lang, "Sin eventos registrados en este filtro.", "No recorded events in this filter.")
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
		hud._event_feed_vbox.add_child(empty_lbl)


static func _filter_short_label(lang: String, filter_id: String) -> String:
	match filter_id:
		"all":
			return EvoUiStyle.tr_text(lang, "Todo", "All")
		"war":
			return "⚔"
		"diplomacy":
			return "🤝"
		"health":
			return "☣"
		"evolution":
			return "🧬"
	return filter_id


static func _filter_tooltip_label(lang: String, filter_id: String) -> String:
	match filter_id:
		"all":
			return EvoUiStyle.tr_text(lang, "Todos los eventos", "All events")
		"war":
			return EvoUiStyle.tr_text(lang, "⚔ Guerra, asedio, saqueo y traición", "⚔ War, siege, raid & betrayal")
		"diplomacy":
			return EvoUiStyle.tr_text(lang, "🤝 Pactos, tributos, uniones y colonización", "🤝 Pacts, tribute, unions & colonization")
		"health":
			return EvoUiStyle.tr_text(lang, "☣ Epidemias, contagios y hambrunas", "☣ Epidemics, contagion & famine")
		"evolution":
			return EvoUiStyle.tr_text(lang, "🧬 Evolución, rasgos, fortificación y extinción", "🧬 Evolution, traits, fortification & extinction")
	return filter_id


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
