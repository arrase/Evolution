class_name EvoHudInspectorPanel
extends RefCounted

var _hud: Control = null
var deme_strategy_label: Label
var deme_selector_option: OptionButton


func _init(p_hud: Control = null) -> void:
	_hud = p_hud


func _refresh_deme_selector() -> void:
	if _hud != null:
		EvoHudInspectorPanel.rebuild_villages_list(_hud)


static func build_right_scroll_inspector(hud: Control) -> void:
	hud._inspector_frame = PanelContainer.new()
	hud._inspector_frame.anchor_left = 1.0
	hud._inspector_frame.anchor_right = 1.0
	hud._inspector_frame.anchor_top = 0.0
	hud._inspector_frame.anchor_bottom = 0.0
	hud._inspector_frame.offset_left = -356
	hud._inspector_frame.offset_right = -10
	hud._inspector_frame.offset_top = 132
	hud._inspector_frame.offset_bottom = 865
	hud._inspector_frame.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(7))
	hud.add_child(hud._inspector_frame)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 5)
	hud._inspector_frame.add_child(outer_vbox)

	# Wooden Scroll Roller Header (Always visible even when minimized)
	var header_box := PanelContainer.new()
	header_box.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_header_box(8, 5))
	outer_vbox.add_child(header_box)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 4)
	header_box.add_child(header_vbox)

	# Row 1: Compact Village Selector Row (Swatch + ◀ + OptionButton + ▶ + Minimize)
	var village_sel_row := HBoxContainer.new()
	village_sel_row.add_theme_constant_override("separation", 4)
	header_vbox.add_child(village_sel_row)

	hud._inspector_header_swatch = ColorRect.new()
	hud._inspector_header_swatch.custom_minimum_size = Vector2(12, 20)
	hud._inspector_header_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud._inspector_header_swatch.color = Color("#E07A5F")
	village_sel_row.add_child(hud._inspector_header_swatch)

	hud._village_prev_btn = Button.new()
	hud._village_prev_btn.text = "◀"
	hud._village_prev_btn.custom_minimum_size = Vector2(24, 24)
	hud._village_prev_btn.add_theme_font_size_override("font_size", 10)
	hud._village_prev_btn.pressed.connect(hud._on_village_cycle_pressed.bind(-1))
	village_sel_row.add_child(hud._village_prev_btn)

	hud._village_selector_opt = OptionButton.new()
	hud._village_selector_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._village_selector_opt.fit_to_longest_item = false
	hud._village_selector_opt.clip_text = true
	hud._village_selector_opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._village_selector_opt.add_theme_font_size_override("font_size", 11)
	hud._village_selector_opt.item_selected.connect(hud._on_village_selector_item_selected)
	village_sel_row.add_child(hud._village_selector_opt)

	hud.deme_selector_option = hud._village_selector_opt
	if hud.inspector_panel != null:
		hud.inspector_panel.deme_selector_option = hud._village_selector_opt

	hud._village_next_btn = Button.new()
	hud._village_next_btn.text = "▶"
	hud._village_next_btn.custom_minimum_size = Vector2(24, 24)
	hud._village_next_btn.add_theme_font_size_override("font_size", 10)
	hud._village_next_btn.pressed.connect(hud._on_village_cycle_pressed.bind(1))
	village_sel_row.add_child(hud._village_next_btn)

	hud._inspector_minimize_btn = Button.new()
	hud._inspector_minimize_btn.text = "▾"
	hud._inspector_minimize_btn.custom_minimum_size = Vector2(24, 24)
	hud._inspector_minimize_btn.pressed.connect(hud._on_toggle_inspector_minimize)
	village_sel_row.add_child(hud._inspector_minimize_btn)

	# Row 2: System 1 Decision Model Badge + Lineage Highlight Button
	var h_top := HBoxContainer.new()
	h_top.add_theme_constant_override("separation", 5)
	header_vbox.add_child(h_top)

	var model_badge_panel := PanelContainer.new()
	model_badge_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_badge_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(Color("#271306"), EvoUiStyle.COLOR_GOLD_BEVEL))
	h_top.add_child(model_badge_panel)

	hud._inspector_model_badge_lbl = Label.new()
	hud._inspector_model_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._inspector_model_badge_lbl.clip_text = true
	hud._inspector_model_badge_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._inspector_model_badge_lbl.add_theme_font_size_override("font_size", 11)
	hud._inspector_model_badge_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_CREAM_TEXT)
	model_badge_panel.add_child(hud._inspector_model_badge_lbl)

	hud._inspector_header_title = Label.new()
	hud._inspector_header_title.visible = false
	h_top.add_child(hud._inspector_header_title)

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
	hud.deme_strategy_label.add_theme_font_size_override("font_size", 11)
	hud.deme_strategy_label.add_theme_color_override("font_color", Color("#10B981"))
	hud._strategy_badge_panel.add_child(hud.deme_strategy_label)
	if hud.inspector_panel != null:
		hud.inspector_panel.deme_strategy_label = hud.deme_strategy_label

	# Collapsible Scroll Body (3 Tabs + Cream Parchment Content)
	hud._inspector_body_vbox = VBoxContainer.new()
	hud._inspector_body_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud._inspector_body_vbox.add_theme_constant_override("separation", 5)
	outer_vbox.add_child(hud._inspector_body_vbox)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	hud._inspector_body_vbox.add_child(tabs_row)

	hud._tab_deme_btn = Button.new()
	hud._tab_deme_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._tab_deme_btn.add_theme_font_size_override("font_size", 11)
	hud._tab_deme_btn.pressed.connect(hud._on_inspector_tab_pressed.bind("deme"))
	tabs_row.add_child(hud._tab_deme_btn)

	hud._tab_traits_btn = Button.new()
	hud._tab_traits_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._tab_traits_btn.add_theme_font_size_override("font_size", 11)
	hud._tab_traits_btn.pressed.connect(hud._on_inspector_tab_pressed.bind("traits"))
	tabs_row.add_child(hud._tab_traits_btn)

	hud._tab_habitat_btn = Button.new()
	hud._tab_habitat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._tab_habitat_btn.add_theme_font_size_override("font_size", 11)
	hud._tab_habitat_btn.pressed.connect(hud._on_inspector_tab_pressed.bind("habitat"))
	tabs_row.add_child(hud._tab_habitat_btn)

	var parchment_body := PanelContainer.new()
	parchment_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parchment_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parchment_body.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(8, false))
	hud._inspector_body_vbox.add_child(parchment_body)

	hud._inspector_scroll = ScrollContainer.new()
	hud._inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud._inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parchment_body.add_child(hud._inspector_scroll)

	var sheets_holder := VBoxContainer.new()
	sheets_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheets_holder.add_theme_constant_override("separation", 6)
	hud._inspector_scroll.add_child(sheets_holder)

	hud._deme_sheet_vbox = VBoxContainer.new()
	hud._deme_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._deme_sheet_vbox.add_theme_constant_override("separation", 6)
	sheets_holder.add_child(hud._deme_sheet_vbox)

	hud._traits_sheet_vbox = VBoxContainer.new()
	hud._traits_sheet_vbox.visible = false
	hud._traits_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._traits_sheet_vbox.add_theme_constant_override("separation", 6)
	sheets_holder.add_child(hud._traits_sheet_vbox)

	hud._hex_sheet_vbox = VBoxContainer.new()
	hud._hex_sheet_vbox.visible = false
	hud._hex_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._hex_sheet_vbox.add_theme_constant_override("separation", 6)
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
		var strat_icon := _resolve_deme_strategy_icon(hud._world_state, d)
		var item_lbl := "%s %s — %d %s" % [strat_icon, _format_deme_with_hex(d), d.population, pop_unit]
		hud._village_selector_opt.add_item(item_lbl, i)
		hud._village_selector_opt.set_item_metadata(i, d.id)
		if d.id == hud._selected_deme_id:
			selected_idx = i

	hud._village_selector_opt.select(selected_idx)


static func _resolve_deme_strategy_icon(state: EvoTypes.WorldState, d: EvoTypes.Deme) -> String:
	var strat_id := d.strategy_id
	if strat_id == "" and state.lineage_tree.has(d.lineage_id):
		strat_id = (state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).strategy_id
	if state.strategies_catalog.has(strat_id):
		return (state.strategies_catalog[strat_id] as EvoTypes.StrategyDef).icon
	return "🛡️"


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
		hud._inspector_header_title.text = EvoUiStyle.tr_text(hud._lang, "Hex (%s)" % hud._selected_hex_id, "Hex (%s)" % hud._selected_hex_id)
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
	hud._inspector_header_title.text = "%s (%s)" % [d.name, d.hex_id]
	hud._inspector_header_hl_btn.visible = true
	var is_hl: bool = (hud._highlighted_lineage_id == d.lineage_id and hud._highlighted_lineage_id != "")
	hud._inspector_header_hl_btn.text = EvoUiStyle.tr_text(hud._lang, "✨ Linaje", "✨ Lineage")
	EvoUiStyle.apply_button_active(hud._inspector_header_hl_btn, is_hl)

	var conf_pct := int(round(d.last_confidence * 100.0))
	hud._inspector_model_badge_lbl.text = EvoUiStyle.tr_text(
		hud._lang,
		"🧠 Modelo: %s · %d%% · 📍 (%s)" % [d.decision_model_tag, conf_pct, d.hex_id],
		"🧠 Model: %s · %d%% · 📍 (%s)" % [d.decision_model_tag, conf_pct, d.hex_id]
	)

	if hud._inspector_tab == "traits":
		var mile_title := Label.new()
		mile_title.text = EvoUiStyle.tr_text(hud._lang, "⏳ Medidores de Hitos Evolutivos", "⏳ Evolutionary Milestone Meters")
		mile_title.add_theme_font_size_override("font_size", 12)
		mile_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
		hud._traits_sheet_vbox.add_child(mile_title)

		var max_baldwin := 0
		for b_k in d.baldwin_counters.keys():
			var cnt := int(d.baldwin_counters[b_k])
			if cnt > max_baldwin:
				max_baldwin = cnt
		_add_milestone_bar(
			hud._traits_sheet_vbox,
			EvoUiStyle.tr_text(hud._lang, "Asimilación Genética (Baldwin)", "Genetic Assimilation (Baldwin)"),
			"%d / 8 gen" % max_baldwin,
			clampf(float(max_baldwin) / 8.0 * 100.0, 0.0, 100.0),
			Color("#0d9488")
		)

		var innov_pct := clampf(d.innovation_counter * 100.0, 0.0, 100.0)
		_add_milestone_bar(
			hud._traits_sheet_vbox,
			EvoUiStyle.tr_text(hud._lang, "Innovación Cultural", "Cultural Innovation"),
			"%d%%" % int(round(innov_pct)),
			innov_pct,
			EvoUiStyle.COLOR_PURPLE_CULTURE
		)

		_add_milestone_bar(
			hud._traits_sheet_vbox,
			EvoUiStyle.tr_text(hud._lang, "Aislamiento Alopátrico", "Allopatric Isolation"),
			"%d / 10 gen" % d.isolation_turns,
			clampf(float(d.isolation_turns) / 10.0 * 100.0, 0.0, 100.0),
			EvoUiStyle.COLOR_BLUE_INFO
		)

		var traits_title := Label.new()
		traits_title.text = EvoUiStyle.tr_text(hud._lang, "🧬 Medallones de Rasgos y Tradiciones", "🧬 Trait & Tradition Medallions")
		traits_title.add_theme_font_size_override("font_size", 12)
		traits_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
		hud._traits_sheet_vbox.add_child(traits_title)

		var traits_flow := HFlowContainer.new()
		traits_flow.add_theme_constant_override("h_separation", 4)
		traits_flow.add_theme_constant_override("v_separation", 4)
		hud._traits_sheet_vbox.add_child(traits_flow)

		for t_id in d.biological_trait_ids:
			traits_flow.add_child(_make_trait_tag(hud._world_state, t_id, false))
		for t_id in d.cultural_trait_ids:
			traits_flow.add_child(_make_trait_tag(hud._world_state, t_id, true))

		var open_forge_btn := Button.new()
		open_forge_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_forge_btn.text = EvoUiStyle.tr_text(hud._lang, "⚗️ Abrir Forja / Inyectar Rasgo", "⚗️ Open Forge / Inject Trait")
		open_forge_btn.pressed.connect(hud.open_lab_modal)
		hud._traits_sheet_vbox.add_child(open_forge_btn)
		return

	# TAB 1: 🧠 ALDEA Y DECISIONES
	var meters_card := PanelContainer.new()
	meters_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 6))
	hud._deme_sheet_vbox.add_child(meters_card)

	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 4)
	meters_card.add_child(m_vbox)

	_add_sheet_kv(m_vbox, EvoUiStyle.tr_text(hud._lang, "🛡️ Linaje:", "🛡️ Lineage:"), lin_name)
	_add_sheet_kv(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "👥 Población:", "👥 Population:"),
		"%d hab. (%s)" % [d.population, EvoUiStyle.get_village_tier_label(d.population, hud._lang)]
	)

	_add_milestone_bar(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "🍯 Reserva Calórica", "🍯 Caloric Reserve"),
		"%.1f" % d.energy_reserves,
		clampf(d.energy_reserves / 220.0 * 100.0, 0.0, 100.0),
		EvoUiStyle.COLOR_GOLD_BRIGHT
	)

	var v_status := d.get_vital_status()
	var heart_icon := EvoUiStyle.get_vital_status_heart(v_status)
	var v_label := EvoUiStyle.get_vital_status_label(v_status, hud._lang)
	_add_sheet_kv(
		m_vbox,
		EvoUiStyle.tr_text(hud._lang, "⚡ Balance Turno:", "⚡ Turn Balance:"),
		"%+.1f · %s %s" % [d.last_energy_delta, heart_icon, v_label]
	)

	# Decision Model Intention Section (Top 3 probabilities, dominant marked with ★)
	var dec_title := Label.new()
	dec_title.text = EvoUiStyle.tr_text(
		hud._lang,
		"🧠 Intención Dominante:",
		"🧠 Dominant Intention:"
	)
	dec_title.add_theme_font_size_override("font_size", 12)
	dec_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._deme_sheet_vbox.add_child(dec_title)

	var prob_keys := d.last_decision_probabilities.keys()
	prob_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float(d.last_decision_probabilities[a]) > float(d.last_decision_probabilities[b])
	)
	for i in range(mini(3, prob_keys.size())):
		var dec_id := str(prob_keys[i])
		var prob: float = float(d.last_decision_probabilities[dec_id])
		var dec_lbl_str := dec_id
		if hud._world_state.decisions_catalog.has(dec_id):
			dec_lbl_str = (hud._world_state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).name
		var is_dom := (i == 0 or dec_id == d.last_dominant_decision_id)
		if i == 0:
			dec_lbl_str = "★ " + dec_lbl_str

		_add_milestone_bar(
			hud._deme_sheet_vbox,
			dec_lbl_str,
			"%d%%" % int(round(prob * 100.0)),
			prob * 100.0,
			EvoUiStyle.COLOR_GOLD_BEVEL if is_dom else EvoUiStyle.COLOR_SEPIA
		)

	# Village Relations & Roads Summary
	var rel_card := PanelContainer.new()
	rel_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#f4e2b8"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 6))
	hud._deme_sheet_vbox.add_child(rel_card)

	var rel_vbox := VBoxContainer.new()
	rel_vbox.add_theme_constant_override("separation", 3)
	rel_card.add_child(rel_vbox)

	var rel_title := Label.new()
	rel_title.text = EvoUiStyle.tr_text(hud._lang, "🛣️ Relaciones y Caminos:", "🛣️ Relations & Paths:")
	rel_title.add_theme_font_size_override("font_size", 11)
	rel_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	rel_vbox.add_child(rel_title)

	var rel_lines := build_deme_relations_lines(hud._world_state, hud._lang, d)
	for r_line in rel_lines:
		var rl := Label.new()
		rl.text = r_line
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_font_size_override("font_size", 11)
		rl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
		rel_vbox.add_child(rl)

	# Naturalist's Note (`last_justification`)
	var just_card := PanelContainer.new()
	just_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 6))
	hud._deme_sheet_vbox.add_child(just_card)

	var just_lbl := Label.new()
	var just_txt := d.last_justification if d.last_justification != "" else EvoUiStyle.tr_text(hud._lang, "Evaluación inicial de hábitat.", "Initial habitat evaluation.")
	just_lbl.text = "💬 " + just_txt
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
		hud._inspector_header_title.text = "%s (%d, %d)" % [EvoUiStyle.get_biome_label(cell.biome, hud._lang), cell.q, cell.r]
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

	_add_sheet_kv(hud._hex_sheet_vbox, EvoUiStyle.tr_text(hud._lang, "🌡️ Temperatura:", "🌡️ Temperature:"), "%+.2f" % cell.temperature)
	_add_sheet_kv(hud._hex_sheet_vbox, EvoUiStyle.tr_text(hud._lang, "💧 Humedad:", "💧 Humidity:"), "%d%%" % int(round(cell.humidity * 100.0)))
	_add_sheet_kv(hud._hex_sheet_vbox, EvoUiStyle.tr_text(hud._lang, "⛰️ Altitud:", "⛰️ Altitude:"), "%.2f" % cell.altitude)

	var r_ratio := clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity), 0.0, 1.0)
	_add_milestone_bar(
		hud._hex_sheet_vbox,
		EvoUiStyle.tr_text(hud._lang, "🌾 Biomasa Disponible (R)", "🌾 Available Biomass (R)"),
		"%.0f / %.0f" % [cell.current_resources, cell.carrying_capacity],
		r_ratio * 100.0,
		EvoUiStyle.COLOR_GOLD_BEVEL
	)

	var k_ratio := clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var h_col := EvoUiStyle.COLOR_GREEN_OK
	if k_ratio < 0.60:
		h_col = EvoUiStyle.COLOR_RED_DANGER
	elif k_ratio < 0.85:
		h_col = EvoUiStyle.COLOR_AMBER_WARN

	_add_milestone_bar(
		hud._hex_sheet_vbox,
		EvoUiStyle.tr_text(hud._lang, "💚 Salud Ecológica (K / Kmax)", "💚 Ecological Health (K / Kmax)"),
		"%.0f / %.0f (%d%%)" % [cell.carrying_capacity, cell.carrying_capacity_max, int(round(k_ratio * 100.0))],
		k_ratio * 100.0,
		h_col
	)


static func build_deme_relations_lines(world_state: EvoTypes.WorldState, lang: String, d: EvoTypes.Deme) -> Array[String]:
	var lines: Array[String] = []
	if world_state == null:
		return lines

	var mentioned_deme_ids: Dictionary = {}
	var coop_full: Array[String] = []
	var coop_short: Array[String] = []
	var coop_coord: Array[String] = []
	var dispute_full: Array[String] = []
	var dispute_short: Array[String] = []
	var dispute_coord: Array[String] = []
	var mig_full: Array[String] = []
	var mig_short: Array[String] = []
	var mig_coord: Array[String] = []

	for fl in world_state.active_flows:
		var has_deme_endpoints := (fl.from_deme_id != "" or fl.to_deme_id != "")
		var touches := (fl.from_deme_id == d.id or fl.to_deme_id == d.id) if has_deme_endpoints else (fl.from_hex_id == d.hex_id or fl.to_hex_id == d.hex_id)
		if not touches:
			continue
		var other_hex := fl.to_hex_id if fl.from_hex_id == d.hex_id else fl.from_hex_id
		var coord_lbl := "(%s)" % other_hex
		var full_lbl := "Hex (%s)" % other_hex
		var short_lbl := coord_lbl
		var other_deme_id := fl.to_deme_id if fl.from_deme_id == d.id else fl.from_deme_id
		if other_deme_id != "" and world_state.demes.has(other_deme_id):
			var od_flow: EvoTypes.Deme = world_state.demes[other_deme_id]
			full_lbl = _format_deme_with_hex(od_flow)
			short_lbl = _format_short_deme_label(od_flow)
			coord_lbl = "(%s)" % od_flow.hex_id
			mentioned_deme_ids[other_deme_id] = true
		match fl.flow_type:
			"exchange", "cooperate", "merge":
				if not coop_full.has(full_lbl):
					coop_full.append(full_lbl)
					coop_short.append(short_lbl)
					coop_coord.append(coord_lbl)
			"dispute":
				if not dispute_full.has(full_lbl):
					dispute_full.append(full_lbl)
					dispute_short.append(short_lbl)
					dispute_coord.append(coord_lbl)
			"migration":
				if not mig_full.has(coord_lbl):
					mig_full.append(coord_lbl)
					mig_short.append(coord_lbl)
					mig_coord.append(coord_lbl)

	var coop_line := _format_relation_category(
		lang,
		"🛣️ Cooperación activa: %s", "🛣️ Active cooperation: %s",
		"🛣️ Cooperación activa (%d): %s", "🛣️ Active cooperation (%d): %s",
		coop_full, coop_short, coop_coord
	)
	if coop_line != "":
		lines.append(coop_line)

	var dispute_line := _format_relation_category(
		lang,
		"⚔️ En conflicto: %s", "⚔️ In conflict: %s",
		"⚔️ En conflicto (%d): %s", "⚔️ In conflict (%d): %s",
		dispute_full, dispute_short, dispute_coord
	)
	if dispute_line != "":
		lines.append(dispute_line)

	var mig_line := _format_relation_category(
		lang,
		"🧭 Expedición migratoria hacia %s", "🧭 Migratory expedition toward %s",
		"🧭 Migración (%d): %s", "🧭 Migration (%d): %s",
		mig_full, mig_short, mig_coord
	)
	if mig_line != "":
		lines.append(mig_line)

	var sev_full: Array[String] = []
	var sev_short: Array[String] = []
	var sev_coord: Array[String] = []
	for dis in world_state.disused_connections:
		var f_deme := str(dis.get("from_deme_id", ""))
		var t_deme := str(dis.get("to_deme_id", ""))
		var f_hex := str(dis.get("from_hex_id", ""))
		var t_hex := str(dis.get("to_hex_id", ""))
		var has_d := (f_deme != "" or t_deme != "")
		var touches_dis := (f_deme == d.id or t_deme == d.id) if has_d else (f_hex == d.hex_id or t_hex == d.hex_id)
		if touches_dis:
			var other_d_id := t_deme if f_deme == d.id else f_deme
			var target_h := t_hex if f_hex == d.hex_id else f_hex
			var coord_s := "(%s)" % target_h
			var full_s := coord_s
			var short_s := coord_s
			if other_d_id != "" and other_d_id != d.id and world_state.demes.has(other_d_id):
				var od_dis: EvoTypes.Deme = world_state.demes[other_d_id]
				full_s = _format_deme_with_hex(od_dis)
				short_s = _format_short_deme_label(od_dis)
				coord_s = "(%s)" % od_dis.hex_id
			var age_val := int(dis.get("age", 0))
			if age_val > 0:
				full_s = EvoUiStyle.tr_text(lang, "%s (hace %d gen.)" % [full_s, age_val], "%s (%d gen. ago)" % [full_s, age_val])
			if not sev_full.has(full_s):
				sev_full.append(full_s)
				sev_short.append(short_s)
				sev_coord.append(coord_s)

	var sev_line := _format_relation_category(
		lang,
		"🚧 Camino cortado con %s", "🚧 Severed path with %s",
		"🚧 Caminos cortados (%d): %s", "🚧 Severed paths (%d): %s",
		sev_full, sev_short, sev_coord
	)
	if sev_line != "":
		lines.append(sev_line)

	if world_state.cells.has(d.hex_id):
		var c: EvoTypes.HexCell = world_state.cells[d.hex_id]
		var coh_full: Array[String] = []
		var coh_short: Array[String] = []
		var coh_coord: Array[String] = []
		for other_id in c.deme_ids:
			if other_id != d.id and not mentioned_deme_ids.has(other_id) and world_state.demes.has(other_id):
				var od: EvoTypes.Deme = world_state.demes[other_id]
				var flbl := _format_deme_with_hex(od)
				if not coh_full.has(flbl):
					coh_full.append(flbl)
					coh_short.append(_format_short_deme_label(od))
					coh_coord.append("(%s)" % od.hex_id)
		var coh_line := _format_relation_category(
			lang,
			"🤝 Coexistiendo con %s", "🤝 Coexisting with %s",
			"🤝 Coexistiendo (%d): %s", "🤝 Coexisting (%d): %s",
			coh_full, coh_short, coh_coord
		)
		if coh_line != "":
			lines.append(coh_line)

		var neigh_full: Array[String] = []
		var neigh_short: Array[String] = []
		var neigh_coord: Array[String] = []
		var n_ids := HexMath.get_neighbor_ids(c.q, c.r, world_state.cells)
		for nid in n_ids:
			var nc: EvoTypes.HexCell = world_state.cells[nid]
			for nd_id in nc.deme_ids:
				if not mentioned_deme_ids.has(nd_id) and world_state.demes.has(nd_id):
					var nd: EvoTypes.Deme = world_state.demes[nd_id]
					var nlbl := _format_deme_with_hex(nd)
					if not neigh_full.has(nlbl):
						neigh_full.append(nlbl)
						neigh_short.append(_format_short_deme_label(nd))
						neigh_coord.append("(%s)" % nd.hex_id)
		var neigh_line := _format_relation_category(
			lang,
			"🏘️ Aldea vecina: %s", "🏘️ Neighbor village: %s",
			"🏘️ Aldeas vecinas (%d): %s", "🏘️ Neighbor villages (%d): %s",
			neigh_full, neigh_short, neigh_coord
		)
		if neigh_line != "":
			lines.append(neigh_line)

	if lines.is_empty():
		lines.append(EvoUiStyle.tr_text(lang, "🏞️ Sin caminos exteriores activos (aldea aislada)", "🏞️ No active outer roads (isolated village)"))
	return lines


static func _format_deme_with_hex(od: EvoTypes.Deme) -> String:
	var suffix := "(%s)" % od.hex_id
	if od.name.ends_with(suffix):
		return od.name
	return "%s %s" % [od.name, suffix]


static func _format_short_deme_label(od: EvoTypes.Deme) -> String:
	var suffix := "(%s)" % od.hex_id
	var base := od.name
	if base.ends_with(suffix):
		base = base.substr(0, base.length() - suffix.length()).strip_edges()
	if base.length() > 16:
		base = base.substr(0, 15) + "…"
	return "%s (%s)" % [base, od.hex_id]


static func _format_relation_category(
	lang: String,
	single_es: String,
	single_en: String,
	multi_es: String,
	multi_en: String,
	full_list: Array[String],
	short_list: Array[String],
	coord_list: Array[String]
) -> String:
	var n := full_list.size()
	if n == 0:
		return ""
	if n == 1:
		return EvoUiStyle.tr_text(lang, single_es % full_list[0], single_en % full_list[0])
	if n == 2:
		var joined_two := ", ".join(short_list)
		return EvoUiStyle.tr_text(lang, multi_es % [n, joined_two], multi_en % [n, joined_two])
	var shown: Array[String] = []
	for i in range(mini(4, n)):
		shown.append(coord_list[i])
	if n > 4:
		shown.append(EvoUiStyle.tr_text(lang, "+%d más" % (n - 4), "+%d more" % (n - 4)))
	var joined_many := ", ".join(shown)
	return EvoUiStyle.tr_text(lang, multi_es % [n, joined_many], multi_en % [n, joined_many])


static func _make_trait_tag(world_state: EvoTypes.WorldState, trait_id: String, is_cultural: bool) -> Control:
	var t_name := trait_id
	var tip := trait_id
	if world_state != null and world_state.traits_catalog.has(trait_id):
		var tr: EvoTypes.TraitDef = world_state.traits_catalog[trait_id]
		t_name = tr.name
		var v := tr.vector
		tip = "%s\n%s\nCost: %+.2f | Extr: %+.2f | Eco: %+.2f | Mob: %+.2f | Coh: %+.2f | Thr: %.2f" % [
			tr.name, tr.description,
			v.metabolic_cost, v.extraction_efficiency, v.ecological_impact,
			v.spatial_mobility, v.social_cohesion, v.transmission_threshold
		]
	var badge := PanelContainer.new()
	var col := EvoUiStyle.COLOR_PURPLE_CULTURE if is_cultural else Color("#0d9488")
	badge.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(col))
	badge.tooltip_text = tip

	var lbl := Label.new()
	var short_name := t_name
	if short_name.length() > 30:
		short_name = short_name.substr(0, 28) + "…"
	lbl.text = ("🔥 " if is_cultural else "🧬 ") + short_name
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(lbl)
	return badge


static func _add_milestone_bar(parent: VBoxContainer, label_str: String, right_str: String, pct: float, fill_col: Color) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	parent.add_child(vb)

	var hb := HBoxContainer.new()
	vb.add_child(hb)

	var l1 := Label.new()
	l1.text = label_str
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1.clip_text = true
	l1.add_theme_font_size_override("font_size", 11)
	hb.add_child(l1)

	var l2 := Label.new()
	l2.text = right_str
	l2.add_theme_font_size_override("font_size", 11)
	hb.add_child(l2)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = pct
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 9)
	EvoUiStyle.style_progress_bar(bar, fill_col)
	vb.add_child(bar)


static func _add_sheet_kv(parent: VBoxContainer, k_str: String, v_str: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	parent.add_child(hb)

	var kl := Label.new()
	kl.text = k_str
	kl.add_theme_font_size_override("font_size", 11)
	kl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	hb.add_child(kl)

	var vl := Label.new()
	vl.text = v_str
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vl.add_theme_font_size_override("font_size", 11)
	vl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	hb.add_child(vl)
