class_name EvoHudInspectorPanel
extends RefCounted


static func build_right_scroll_inspector(hud: Control) -> void:
	hud._inspector_frame = PanelContainer.new()
	hud._inspector_frame.anchor_left = 1.0
	hud._inspector_frame.anchor_right = 1.0
	hud._inspector_frame.anchor_top = 0.0
	hud._inspector_frame.anchor_bottom = 0.0
	hud._inspector_frame.offset_left = -292
	hud._inspector_frame.offset_right = -8
	hud._inspector_frame.offset_top = 94
	hud._inspector_frame.offset_bottom = 696
	hud._inspector_frame.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(4))
	hud.add_child(hud._inspector_frame)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 3)
	hud._inspector_frame.add_child(outer_vbox)

	# Wooden Scroll Roller Header (Always visible even when minimized)
	var header_box := PanelContainer.new()
	header_box.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_header_box(5, 3))
	outer_vbox.add_child(header_box)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 3)
	header_box.add_child(header_vbox)

	# Row 1: Compact Village Selector Row (Swatch + ◀ + OptionButton + ▶ + Fold ▾/▸)
	var village_sel_row := HBoxContainer.new()
	village_sel_row.add_theme_constant_override("separation", 3)
	header_vbox.add_child(village_sel_row)

	hud._inspector_header_swatch = ColorRect.new()
	hud._inspector_header_swatch.custom_minimum_size = Vector2(10, 18)
	hud._inspector_header_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud._inspector_header_swatch.color = Color("#E07A5F")
	village_sel_row.add_child(hud._inspector_header_swatch)

	hud._village_prev_btn = Button.new()
	hud._village_prev_btn.text = "◀"
	hud._village_prev_btn.custom_minimum_size = Vector2(20, 20)
	hud._village_prev_btn.add_theme_font_size_override("font_size", 10)
	hud._village_prev_btn.pressed.connect(hud._on_village_cycle_pressed.bind(-1))
	village_sel_row.add_child(hud._village_prev_btn)

	hud._village_selector_opt = OptionButton.new()
	hud._village_selector_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._village_selector_opt.fit_to_longest_item = false
	hud._village_selector_opt.clip_text = true
	hud._village_selector_opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._village_selector_opt.add_theme_font_size_override("font_size", 10)
	hud._village_selector_opt.item_selected.connect(hud._on_village_selector_item_selected)
	village_sel_row.add_child(hud._village_selector_opt)

	hud.deme_selector_option = hud._village_selector_opt

	hud._village_next_btn = Button.new()
	hud._village_next_btn.text = "▶"
	hud._village_next_btn.custom_minimum_size = Vector2(20, 20)
	hud._village_next_btn.add_theme_font_size_override("font_size", 10)
	hud._village_next_btn.pressed.connect(hud._on_village_cycle_pressed.bind(1))
	village_sel_row.add_child(hud._village_next_btn)

	hud._inspector_minimize_btn = Button.new()
	hud._inspector_minimize_btn.text = "▾"
	hud._inspector_minimize_btn.custom_minimum_size = Vector2(20, 20)
	hud._inspector_minimize_btn.add_theme_font_size_override("font_size", 10)
	hud._inspector_minimize_btn.tooltip_text = "▾ / ▸"
	hud._inspector_minimize_btn.pressed.connect(hud._on_toggle_inspector_minimize)
	village_sel_row.add_child(hud._inspector_minimize_btn)

	# Row 2: System 1 Decision Model Badge + Lineage Highlight Button
	var h_top := HBoxContainer.new()
	h_top.add_theme_constant_override("separation", 4)
	header_vbox.add_child(h_top)

	var model_badge_panel := PanelContainer.new()
	model_badge_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_badge_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(Color("#271306"), EvoUiStyle.COLOR_GOLD_BEVEL))
	h_top.add_child(model_badge_panel)

	hud._inspector_model_badge_lbl = Label.new()
	hud._inspector_model_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._inspector_model_badge_lbl.clip_text = true
	hud._inspector_model_badge_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._inspector_model_badge_lbl.add_theme_font_size_override("font_size", 10)
	hud._inspector_model_badge_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_CREAM_TEXT)
	model_badge_panel.add_child(hud._inspector_model_badge_lbl)

	hud._inspector_header_hl_btn = Button.new()
	hud._inspector_header_hl_btn.add_theme_font_size_override("font_size", 10)
	hud._inspector_header_hl_btn.pressed.connect(hud._on_header_highlight_pressed)
	h_top.add_child(hud._inspector_header_hl_btn)

	# Row 3: Prominent Village Strategy Badge
	hud._strategy_badge_panel = PanelContainer.new()
	hud._strategy_badge_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._strategy_badge_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(Color("#271306"), Color("#10B981")))
	header_vbox.add_child(hud._strategy_badge_panel)

	hud.deme_strategy_label = Label.new()
	hud.deme_strategy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.deme_strategy_label.clip_text = true
	hud.deme_strategy_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.deme_strategy_label.add_theme_font_size_override("font_size", 10)
	hud.deme_strategy_label.add_theme_color_override("font_color", Color("#10B981"))
	hud._strategy_badge_panel.add_child(hud.deme_strategy_label)

	# Collapsible Scroll Body (3 Tabs + Cream Parchment Content)
	hud._inspector_body_vbox = VBoxContainer.new()
	hud._inspector_body_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud._inspector_body_vbox.add_theme_constant_override("separation", 3)
	outer_vbox.add_child(hud._inspector_body_vbox)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 3)
	hud._inspector_body_vbox.add_child(tabs_row)

	hud._tab_deme_btn = Button.new()
	hud._tab_deme_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._tab_deme_btn.add_theme_font_size_override("font_size", 10)
	hud._tab_deme_btn.pressed.connect(hud._on_inspector_tab_pressed.bind("deme"))
	tabs_row.add_child(hud._tab_deme_btn)

	hud._tab_traits_btn = Button.new()
	hud._tab_traits_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._tab_traits_btn.add_theme_font_size_override("font_size", 10)
	hud._tab_traits_btn.pressed.connect(hud._on_inspector_tab_pressed.bind("traits"))
	tabs_row.add_child(hud._tab_traits_btn)

	hud._tab_habitat_btn = Button.new()
	hud._tab_habitat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._tab_habitat_btn.add_theme_font_size_override("font_size", 10)
	hud._tab_habitat_btn.pressed.connect(hud._on_inspector_tab_pressed.bind("habitat"))
	tabs_row.add_child(hud._tab_habitat_btn)

	var parchment_body := PanelContainer.new()
	parchment_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parchment_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parchment_body.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(5, false))
	hud._inspector_body_vbox.add_child(parchment_body)

	hud._inspector_scroll = ScrollContainer.new()
	hud._inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud._inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parchment_body.add_child(hud._inspector_scroll)

	var sheets_holder := VBoxContainer.new()
	sheets_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheets_holder.add_theme_constant_override("separation", 4)
	hud._inspector_scroll.add_child(sheets_holder)

	hud._deme_sheet_vbox = VBoxContainer.new()
	hud._deme_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._deme_sheet_vbox.add_theme_constant_override("separation", 4)
	sheets_holder.add_child(hud._deme_sheet_vbox)

	hud._traits_sheet_vbox = VBoxContainer.new()
	hud._traits_sheet_vbox.visible = false
	hud._traits_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._traits_sheet_vbox.add_theme_constant_override("separation", 4)
	sheets_holder.add_child(hud._traits_sheet_vbox)

	hud._hex_sheet_vbox = VBoxContainer.new()
	hud._hex_sheet_vbox.visible = false
	hud._hex_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._hex_sheet_vbox.add_theme_constant_override("separation", 4)
	sheets_holder.add_child(hud._hex_sheet_vbox)


static func rebuild_villages_list(hud: Control) -> void:
	if hud._village_selector_opt == null:
		return

	hud._village_selector_opt.clear()

	if hud._world_state == null or hud._world_state.demes.is_empty():
		hud._village_selector_opt.add_item(EvoUiStyle.tr_text(hud._lang, "🏘️ 0 Aldeas Vivas", "🏘️ 0 Living Villages"), 0)
		hud._village_selector_opt.set_item_metadata(0, "")
		hud._village_selector_opt.disabled = true
		if hud._village_prev_btn != null:
			hud._village_prev_btn.disabled = true
		if hud._village_next_btn != null:
			hud._village_next_btn.disabled = true
		return

	hud._village_selector_opt.disabled = false

	var deme_list: Array[EvoTypes.Deme] = []
	for d_id in hud._world_state.demes.keys():
		deme_list.append(hud._world_state.demes[d_id])
	deme_list.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool: return a.population > b.population)

	var can_cycle := deme_list.size() > 1
	if hud._village_prev_btn != null:
		hud._village_prev_btn.disabled = not can_cycle
	if hud._village_next_btn != null:
		hud._village_next_btn.disabled = not can_cycle

	var selected_idx := -1
	var total_count := deme_list.size()
	var pop_unit := "pop." if hud._lang == "en" else "hab."
	for i in range(total_count):
		var d := deme_list[i]
		var strat_icon := EvoHudInspectorFormatters.resolve_deme_strategy_icon(hud._world_state, d)
		var item_lbl := "%s %s — %d %s" % [strat_icon, EvoHudInspectorFormatters.format_deme_with_hex(d), d.population, pop_unit]
		hud._village_selector_opt.add_item(item_lbl, i)
		hud._village_selector_opt.set_item_metadata(i, d.id)
		if d.id == hud._selected_deme_id:
			selected_idx = i

	hud._village_selector_opt.select(selected_idx)


static func rebuild_deme_sheet(hud: Control) -> void:
	if hud._deme_sheet_vbox == null or hud._traits_sheet_vbox == null:
		return
	if hud._inspector_tab == "traits":
		for child in hud._traits_sheet_vbox.get_children():
			child.queue_free()
	else:
		for child in hud._deme_sheet_vbox.get_children():
			child.queue_free()

	if hud._world_state == null or hud._selected_deme_id == "" or not hud._world_state.demes.has(hud._selected_deme_id):
		hud._inspector_model_badge_lbl.text = EvoUiStyle.tr_text(hud._lang, "🌿 Sin aldea seleccionada", "🌿 No village selected")
		hud._inspector_header_hl_btn.visible = false
		if hud._strategy_badge_panel != null:
			hud._strategy_badge_panel.visible = false
		if hud.deme_strategy_label != null:
			hud.deme_strategy_label.text = ""
		var empty_lbl := Label.new()
		empty_lbl.text = EvoUiStyle.tr_text(
			hud._lang,
			"Selecciona una aldea en el selector superior o en el mapa para abrir su pergamino.",
			"Select a village in the top selector or on the map to open its scroll."
		)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
		var target_box: VBoxContainer = hud._traits_sheet_vbox if hud._inspector_tab == "traits" else hud._deme_sheet_vbox
		target_box.add_child(empty_lbl)
		return

	var d: EvoTypes.Deme = hud._world_state.demes[hud._selected_deme_id]
	var lin_name := d.lineage_id
	if hud._world_state.lineage_tree.has(d.lineage_id):
		lin_name = (hud._world_state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).name

	var strat_id := d.strategy_id
	if strat_id == "" and hud._world_state.lineage_tree.has(d.lineage_id):
		strat_id = (hud._world_state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).strategy_id
	var strat_icon := "🛡️"
	var strat_name := strat_id if strat_id != "" else "—"
	var strat_color_hex := d.color
	if hud._world_state.strategies_catalog.has(strat_id):
		var strat: EvoTypes.StrategyDef = hud._world_state.strategies_catalog[strat_id]
		strat_icon = strat.icon
		strat_name = EvoI18n.strategy_name(hud._lang, strat)
		strat_color_hex = strat.color

	var strat_col := Color.from_string(strat_color_hex, Color("#10B981"))
	if hud._strategy_badge_panel != null:
		hud._strategy_badge_panel.visible = true
		hud._strategy_badge_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(Color("#271306"), strat_col))
	if hud.deme_strategy_label != null:
		hud.deme_strategy_label.text = "🛡️ %s: %s %s" % [EvoI18n.t(hud._lang, "insp_strategy"), strat_icon, strat_name]
		hud.deme_strategy_label.add_theme_color_override("font_color", strat_col)

	# Update Scroll Header
	hud._inspector_header_swatch.color = Color.from_string(d.color, Color("#E07A5F"))
	hud._inspector_header_hl_btn.visible = true
	var is_hl: bool = (hud._highlighted_lineage_id == d.lineage_id and hud._highlighted_lineage_id != "")
	hud._inspector_header_hl_btn.text = EvoUiStyle.tr_text(hud._lang, "✨ Linaje", "✨ Lineage")
	EvoUiStyle.apply_button_active(hud._inspector_header_hl_btn, is_hl)

	var conf_pct := int(round(d.last_confidence * 100.0))
	var coords_str := ") · (".join(d.urban_hex_ids) if d.is_multi_hex() else d.hex_id
	hud._inspector_model_badge_lbl.text = EvoUiStyle.tr_text(
		hud._lang,
		"🧠 Modelo: %s · %d%% · 📍 (%s)" % [d.decision_model_tag, conf_pct, coords_str],
		"🧠 Model: %s · %d%% · 📍 (%s)" % [d.decision_model_tag, conf_pct, coords_str]
	)

	if hud._inspector_tab == "traits":
		EvoHudInspectorFormatters.populate_traits_sheet(hud, d)
		return

	# TAB 1: 🧠 ALDEA Y DECISIONES
	var meters_card := PanelContainer.new()
	meters_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 4))
	hud._deme_sheet_vbox.add_child(meters_card)

	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 2)
	meters_card.add_child(m_vbox)

	EvoHudInspectorFormatters.add_sheet_kv(m_vbox, EvoUiStyle.tr_text(hud._lang, "🛡️ Linaje:", "🛡️ Lineage:"), lin_name)
	var pop_unit := "pop." if hud._lang == "en" else "hab."
	var pop_delta_str := " (%+d)" % d.last_population_delta if d.last_population_delta != 0 else ""
	var tier_lbl := EvoUiStyle.get_village_tier_label(d.population, hud._lang, d.merged_count, d.defense_tier, d.is_multi_hex())
	EvoHudInspectorFormatters.add_sheet_kv(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "👥 Población:", "👥 Population:"),
		"%d %s%s · %s" % [d.population, pop_unit, pop_delta_str, tier_lbl]
	)

	EvoHudInspectorFormatters.add_milestone_bar(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "🍯 Reserva Calórica", "🍯 Caloric Reserve"),
		"%.1f" % d.energy_reserves,
		clampf(d.energy_reserves / 220.0 * 100.0, 0.0, 100.0),
		EvoUiStyle.COLOR_GOLD_BRIGHT
	)

	var food_info := EvoHudInspectorFormatters.format_food_intake_status(d)
	EvoHudInspectorFormatters.add_milestone_bar(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "🍖 Ingesta / Necesidad", "🍖 Intake / Need"),
		str(food_info["right_text"]),
		float(food_info["pct"]),
		food_info["color"] as Color
	)

	var v_status := d.get_vital_status()
	var heart_icon := EvoUiStyle.get_vital_status_heart(v_status)
	var v_label := EvoUiStyle.get_vital_status_label(v_status, hud._lang)
	EvoHudInspectorFormatters.add_sheet_kv(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "⚡ Balance Turno:", "⚡ Turn Balance:"),
		"%+.1f · %s %s" % [d.last_energy_delta, heart_icon, v_label]
	)

	var sal_info := EvoHudInspectorFormatters.format_salubrity_status(d, hud._lang)
	EvoHudInspectorFormatters.add_milestone_bar(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "🏥 Salubridad", "🏥 Salubrity"),
		str(sal_info["right_text"]),
		float(sal_info["pct"]),
		sal_info["color"] as Color
	)
	EvoHudInspectorFormatters.add_sheet_kv(
		m_vbox,
		"🏰 " + EvoI18n.t(hud._lang, "inspector_defense_label") + ":",
		EvoI18n.t(hud._lang, "inspector_defense_%d" % clampi(d.defense_tier, 0, 3))
	)
	EvoHudInspectorFormatters.add_sheet_kv(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "🛡️ Postura Rural:", "🛡️ Rural Posture:"),
		EvoUiStyle.get_defense_posture_label(d.defense_posture, hud._lang)
	)
	if d.merged_count > 0:
		EvoHudInspectorFormatters.add_sheet_kv(
			m_vbox,
			"🏛️ " + EvoUiStyle.tr_text(hud._lang, "Unificación:", "Unification:"),
			EvoI18n.t(hud._lang, "inspector_merged_city", {"count": str(d.merged_count + 1)})
		)
	if d.is_multi_hex():
		EvoHudInspectorFormatters.add_sheet_kv(
			m_vbox,
			"🧱 " + EvoUiStyle.tr_text(hud._lang, "Unión Amurallada:", "Walled Union:"),
			EvoUiStyle.tr_text(
				hud._lang,
				"%d distritos unidos (%s)" % [d.urban_hex_ids.size(), coords_str],
				"%d united districts (%s)" % [d.urban_hex_ids.size(), coords_str]
			)
		)
	EvoHudInspectorFormatters.add_sheet_kv(
		m_vbox,
		"🤝 " + EvoI18n.t(hud._lang, "inspector_pacts") + ":",
		format_active_pacts_summary(hud._world_state, hud._lang, d)
	)
	EvoHudInspectorFormatters.add_sheet_kv(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "⚖️ Reputación:", "⚖️ Reputation:"),
		"%+.2f (%s)" % [d.reputation, EvoRelations.reputation_word(d.reputation)]
	)

	# Action Policy Section (Top 3 action options, chosen action marked with ★)
	var dec_title := Label.new()
	dec_title.text = EvoUiStyle.tr_text(hud._lang, "🧠 Acción Elegida:", "🧠 Chosen Action:")
	dec_title.add_theme_font_size_override("font_size", 11)
	dec_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._deme_sheet_vbox.add_child(dec_title)

	var chosen_key := str(d.chosen_action["key"])
	var prob_keys := d.action_probabilities.keys()
	prob_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ka := str(a)
		var kb := str(b)
		if ka == chosen_key and kb != chosen_key:
			return true
		if kb == chosen_key and ka != chosen_key:
			return false
		return float(d.action_probabilities[a]) > float(d.action_probabilities[b])
	)
	for i in range(mini(3, prob_keys.size())):
		var act_key := str(prob_keys[i])
		var prob := float(d.action_probabilities[act_key])
		var parsed := EvoActionMenu.parse_key(act_key)
		var act_type := str(parsed["type"])
		var act_target := str(parsed["target"])
		var act_lbl_str := act_type
		if hud._world_state.decisions_catalog.has(act_type):
			act_lbl_str = EvoI18n.decision_name(hud._lang, hud._world_state.decisions_catalog[act_type])
		if act_target != "":
			if hud._world_state.demes.has(act_target):
				act_lbl_str += " → " + EvoHudInspectorFormatters.format_short_deme_label(hud._world_state.demes[act_target])
			else:
				act_lbl_str += " → (%s)" % act_target
		var is_chosen := (act_key == chosen_key)
		if is_chosen:
			act_lbl_str = "★ " + act_lbl_str

		EvoHudInspectorFormatters.add_milestone_bar(
			hud._deme_sheet_vbox,
			act_lbl_str,
			"%d%%" % int(round(prob * 100.0)),
			prob * 100.0,
			EvoUiStyle.COLOR_GOLD_BEVEL if is_chosen else EvoUiStyle.COLOR_SEPIA
		)

	# Village Relations & Roads Summary
	var rel_card := PanelContainer.new()
	rel_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#f4e2b8"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 4))
	hud._deme_sheet_vbox.add_child(rel_card)

	var rel_vbox := VBoxContainer.new()
	rel_vbox.add_theme_constant_override("separation", 2)
	rel_card.add_child(rel_vbox)

	var rel_title := Label.new()
	rel_title.text = EvoUiStyle.tr_text(hud._lang, "🛣️ Relaciones y Caminos:", "🛣️ Relations & Paths:")
	rel_title.add_theme_font_size_override("font_size", 10)
	rel_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	rel_vbox.add_child(rel_title)

	var rel_lines := build_deme_relations_lines(hud._world_state, hud._lang, d)
	for item in rel_lines:
		var r_btn := Button.new()
		r_btn.flat = true
		r_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		r_btn.text = str(item["text"])
		r_btn.clip_text = true
		r_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r_btn.add_theme_font_size_override("font_size", 10)
		var txt_col := EvoUiStyle.COLOR_RED_DANGER if bool(item["danger"]) else EvoUiStyle.COLOR_INK
		r_btn.add_theme_color_override("font_color", txt_col)
		r_btn.add_theme_color_override("font_hover_color", EvoUiStyle.COLOR_WOOD_DARK)
		var target_hex := str(item["hex_id"])
		var target_deme := str(item["deme_id"])
		if target_hex != "":
			r_btn.pressed.connect(hud._on_modal_jump_to_hex.bind(target_hex, target_deme))
		rel_vbox.add_child(r_btn)

	# Outcome, Forecast & Memory Card
	var just_card := PanelContainer.new()
	just_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 4))
	hud._deme_sheet_vbox.add_child(just_card)

	var just_lbl := Label.new()
	var note_parts: Array[String] = []
	if d.action_forecasts.has(chosen_key):
		note_parts.append("🎯 " + str(d.action_forecasts[chosen_key]))
	if d.last_outcome != "":
		note_parts.append("📜 " + d.last_outcome)
	if not d.memory.is_empty():
		var recent_mem := d.memory.slice(maxi(0, d.memory.size() - 3), d.memory.size())
		note_parts.append("🧠 " + " | ".join(recent_mem))
	var just_txt := "\n".join(note_parts) if not note_parts.is_empty() else EvoUiStyle.tr_text(hud._lang, "Evaluación inicial de hábitat.", "Initial habitat evaluation.")
	just_lbl.text = just_txt
	just_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	just_lbl.add_theme_font_size_override("font_size", 10)
	just_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	just_card.add_child(just_lbl)


static func rebuild_hex_sheet(hud: Control) -> void:
	if hud._hex_sheet_vbox == null:
		return
	for child in hud._hex_sheet_vbox.get_children():
		child.queue_free()

	if hud._world_state == null or not hud._world_state.cells.has(hud._selected_hex_id):
		return

	var cell: EvoTypes.HexCell = hud._world_state.cells[hud._selected_hex_id]
	if hud._selected_deme_id == "" or not hud._world_state.demes.has(hud._selected_deme_id):
		hud._inspector_header_swatch.color = EvoUiStyle.get_biome_color(cell.biome)
		hud._inspector_model_badge_lbl.text = EvoUiStyle.tr_text(hud._lang, "🌿 Parcela sin aldeas · 📍 (%s)" % hud._selected_hex_id, "🌿 Uninhabited parcel · 📍 (%s)" % hud._selected_hex_id)
		hud._inspector_header_hl_btn.visible = false
		if hud._strategy_badge_panel != null:
			hud._strategy_badge_panel.visible = false

	var bio_row := HBoxContainer.new()
	bio_row.add_theme_constant_override("separation", 8)
	hud._hex_sheet_vbox.add_child(bio_row)

	var bio_icon := TextureRect.new()
	bio_icon.custom_minimum_size = Vector2(24, 24)
	bio_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bio_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bio_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bio_icon.texture = EvoUiStyle.get_pixel_icon(cell.biome)
	bio_row.add_child(bio_icon)

	var title := Label.new()
	title.text = "%s (%d, %d)" % [EvoUiStyle.get_biome_label(cell.biome, hud._lang), cell.q, cell.r]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	bio_row.add_child(title)

	EvoHudInspectorFormatters.populate_hex_metrics(hud, cell)


static func format_active_pacts_summary(world_state: EvoTypes.WorldState, lang: String, d: EvoTypes.Deme) -> String:
	return EvoHudInspectorFormatters.format_active_pacts_summary(world_state, lang, d)


static func build_deme_relations_lines(world_state: EvoTypes.WorldState, lang: String, d: EvoTypes.Deme) -> Array[Dictionary]:
	return EvoHudInspectorFormatters.build_deme_relations_lines(world_state, lang, d)
