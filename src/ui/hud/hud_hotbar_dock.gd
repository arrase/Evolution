class_name EvoHudHotbarDock
extends RefCounted

const HOTBAR_SLOTS_DEF: Array[Dictionary] = [
	{"slot": 0, "key": "1", "tool": "inspect", "sub": "", "icon": "slot_inspect", "cost": 0},
	{"slot": 1, "key": "2", "tool": "set_biome", "sub": "tropical_forest", "icon": "slot_tropical", "cost": 10},
	{"slot": 2, "key": "3", "tool": "set_biome", "sub": "savanna", "icon": "slot_savanna", "cost": 10},
	{"slot": 3, "key": "4", "tool": "set_biome", "sub": "arid_steppe", "icon": "slot_arid", "cost": 10},
	{"slot": 4, "key": "5", "tool": "set_biome", "sub": "tundra", "icon": "slot_tundra", "cost": 10},
	{"slot": 5, "key": "6", "tool": "adjust_altitude", "sub": "raise", "icon": "slot_raise", "cost": 15},
	{"slot": 6, "key": "7", "tool": "adjust_altitude", "sub": "lower", "icon": "slot_lower", "cost": 15},
	{"slot": 7, "key": "8", "tool": "adjust_carrying_capacity", "sub": "enrich", "icon": "slot_enrich", "cost": 10},
	{"slot": 8, "key": "9", "tool": "adjust_carrying_capacity", "sub": "deplete", "icon": "slot_deplete", "cost": 10},
	{"slot": 9, "key": "0", "tool": "sea_level", "sub": "sea_level", "icon": "slot_sealevel", "cost": 25}
]

var _hud: Control = null


func _init(p_hud: Control = null) -> void:
	_hud = p_hud


func refresh_legend(state: EvoTypes.WorldState, lang: String = "es") -> void:
	if _hud != null:
		EvoHudHotbarDock.refresh_legend_for_hud(_hud, state, lang)


static func build_bottom_hotbar(hud: Control) -> void:
	# 1. Floating Sub-Options Bar (appears right above the hotbar when Sea Level / extra biomes active)
	hud._sub_options_panel = PanelContainer.new()
	hud._sub_options_panel.visible = false
	hud._sub_options_panel.anchor_left = 0.5
	hud._sub_options_panel.anchor_right = 0.5
	hud._sub_options_panel.anchor_top = 1.0
	hud._sub_options_panel.anchor_bottom = 1.0
	hud._sub_options_panel.offset_left = -280
	hud._sub_options_panel.offset_right = 280
	hud._sub_options_panel.offset_top = -112
	hud._sub_options_panel.offset_bottom = -76
	hud._sub_options_panel.z_index = 16
	hud._sub_options_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(5))
	hud.add_child(hud._sub_options_panel)

	hud._sub_options_flow = HFlowContainer.new()
	hud._sub_options_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	hud._sub_options_flow.add_theme_constant_override("h_separation", 6)
	hud._sub_options_flow.add_theme_constant_override("v_separation", 4)
	hud._sub_options_panel.add_child(hud._sub_options_flow)

	# 2. Hidden Equipped Tool Plaque (tooltips + hotbar slot badges handle display)
	hud._equipped_tool_banner = PanelContainer.new()
	hud._equipped_tool_banner.visible = false
	hud._equipped_tool_banner.anchor_left = 0.5
	hud._equipped_tool_banner.anchor_right = 0.5
	hud._equipped_tool_banner.anchor_top = 1.0
	hud._equipped_tool_banner.anchor_bottom = 1.0
	hud._equipped_tool_banner.offset_left = -240
	hud._equipped_tool_banner.offset_right = 240
	hud._equipped_tool_banner.offset_top = -100
	hud._equipped_tool_banner.offset_bottom = -74
	hud._equipped_tool_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eq_style := EvoUiStyle.make_parchment_card(Color("#fef3c7"), EvoUiStyle.COLOR_GOLD_BRIGHT, 4)
	hud._equipped_tool_banner.add_theme_stylebox_override("panel", eq_style)
	hud.add_child(hud._equipped_tool_banner)

	hud._equipped_tool_lbl = Label.new()
	hud._equipped_tool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._equipped_tool_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud._equipped_tool_lbl.add_theme_font_size_override("font_size", 12)
	hud._equipped_tool_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._equipped_tool_banner.add_child(hud._equipped_tool_lbl)

	# 3. 10-Slot Inventory Hotbar + Brush Radius Switcher
	var hotbar_frame := PanelContainer.new()
	hotbar_frame.anchor_left = 0.5
	hotbar_frame.anchor_right = 0.5
	hotbar_frame.anchor_top = 1.0
	hotbar_frame.anchor_bottom = 1.0
	hotbar_frame.offset_left = -336
	hotbar_frame.offset_right = 336
	hotbar_frame.offset_top = -70
	hotbar_frame.offset_bottom = -6
	hotbar_frame.z_index = 15
	hotbar_frame.add_theme_stylebox_override("panel", EvoUiStyle.make_hotbar_frame_box(8, 5))
	hud.add_child(hotbar_frame)

	var hb_row := HBoxContainer.new()
	hb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_row.add_theme_constant_override("separation", 4)
	hotbar_frame.add_child(hb_row)

	hud._hotbar_slot_buttons.clear()
	for slot_def in HOTBAR_SLOTS_DEF:
		var s_idx: int = int(slot_def["slot"])
		var key_str: String = str(slot_def["key"])
		var icon_key: String = str(slot_def["icon"])
		var cost_val: int = int(slot_def["cost"])
		var tool_id: String = str(slot_def["tool"])

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(54, 54)
		slot_btn.pressed.connect(hud._on_hotbar_slot_pressed.bind(s_idx))
		hb_row.add_child(slot_btn)
		hud._hotbar_slot_buttons.append(slot_btn)

		if not hud._tool_buttons.has(tool_id):
			hud._tool_buttons[tool_id] = slot_btn

		# Slot internal overlay: Key number (top-left), Pixel Icon (center), Cost (bottom-right)
		var slot_overlay := Control.new()
		slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(slot_overlay)

		var key_lbl := Label.new()
		key_lbl.text = key_str
		key_lbl.position = Vector2(4, 1)
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_overlay.add_child(key_lbl)

		var icon_rect := TextureRect.new()
		icon_rect.texture = EvoUiStyle.get_pixel_icon(icon_key)
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(13, 11)
		icon_rect.size = Vector2(28, 28)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_overlay.add_child(icon_rect)

		if cost_val > 0:
			var cost_lbl := Label.new()
			cost_lbl.text = "⚡%d" % cost_val
			cost_lbl.position = Vector2(22, 37)
			cost_lbl.size = Vector2(29, 14)
			cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cost_lbl.add_theme_font_size_override("font_size", 9)
			cost_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_overlay.add_child(cost_lbl)

	# Separator & Brush Size Switcher inside the right end of the hotbar
	var v_sep := VSeparator.new()
	hb_row.add_child(v_sep)

	var brush_vbox := VBoxContainer.new()
	brush_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	brush_vbox.add_theme_constant_override("separation", 3)
	hb_row.add_child(brush_vbox)

	hud._radius_1_btn = Button.new()
	hud._radius_1_btn.custom_minimum_size = Vector2(58, 25)
	hud._radius_1_btn.add_theme_font_size_override("font_size", 11)
	hud._radius_1_btn.pressed.connect(hud._on_brush_radius_pressed.bind(1))
	brush_vbox.add_child(hud._radius_1_btn)

	hud._radius_2_btn = Button.new()
	hud._radius_2_btn.custom_minimum_size = Vector2(58, 25)
	hud._radius_2_btn.add_theme_font_size_override("font_size", 11)
	hud._radius_2_btn.pressed.connect(hud._on_brush_radius_pressed.bind(2))
	brush_vbox.add_child(hud._radius_2_btn)


static func build_legend_panel(hud: Control) -> void:
	hud._legend_panel = PanelContainer.new()
	hud._legend_panel.visible = false
	hud._legend_panel.anchor_left = 0.0
	hud._legend_panel.anchor_right = 0.0
	hud._legend_panel.anchor_top = 0.0
	hud._legend_panel.anchor_bottom = 0.0
	hud._legend_panel.offset_left = 428
	hud._legend_panel.offset_right = 736
	hud._legend_panel.offset_top = 10
	hud._legend_panel.offset_bottom = 434
	hud._legend_panel.z_index = 22
	hud._legend_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(7))
	hud.add_child(hud._legend_panel)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(8, false))
	hud._legend_panel.add_child(inner)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)

	hud._legend_vbox = VBoxContainer.new()
	hud._legend_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._legend_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(hud._legend_vbox)


static func get_slot_title_and_desc(lang: String, slot_idx: int) -> Dictionary:
	var titles_es := [
		["🔍 Lupa del Naturalista", "Inspeccionar aldeas y hábitats (Coste: 0)"],
		["🌴 Semillas de Selva", "Plantar Bosque Tropical húmedo (Coste: ⚡10)"],
		["🌾 Semillas de Sabana", "Sembrar Sabana estacional (Coste: ⚡10)"],
		["🌵 Polvo del Desierto", "Transformar en Estepa Árida (Coste: ⚡10)"],
		["❄️ Cristal Boreal", "Congelar en Tundra alpina (Coste: ⚡10)"],
		["⛰️ Cincel de Cumbre", "Elevar Terreno +0.18 altitud (Coste: ⚡15)"],
		["⛏️ Pico de Valle", "Excavar Terreno -0.18 altitud (Coste: ⚡15)"],
		["💧 Regadera Dorada", "Enriquecer Fertilidad +25% K (Coste: ⚡10)"],
		["🔥 Hoz de Sequía", "Agotar Fertilidad -25% K (Coste: ⚡10)"],
		["🐚 Caracola de Mareas", "Nivel del Mar ±5% y Costas (Coste: ⚡25)"]
	]
	var titles_en := [
		["🔍 Naturalist's Loupe", "Inspect villages and habitats (Cost: 0)"],
		["🌴 Jungle Seeds", "Plant humid Tropical Forest (Cost: ⚡10)"],
		["🌾 Savanna Seeds", "Sow seasonal Savanna (Cost: ⚡10)"],
		["🌵 Desert Dust", "Turn into Arid Steppe (Cost: ⚡10)"],
		["❄️ Boreal Crystal", "Freeze into alpine Tundra (Cost: ⚡10)"],
		["⛰️ Peak Chisel", "Raise Terrain +0.18 altitude (Cost: ⚡15)"],
		["⛏️ Valley Pickaxe", "Excavate Terrain -0.18 altitude (Cost: ⚡15)"],
		["💧 Golden Watering Can", "Enrich Fertility +25% K (Cost: ⚡10)"],
		["🔥 Drought Sickle", "Deplete Fertility -25% K (Cost: ⚡10)"],
		["🐚 Tidal Conch", "Sea Level ±5% & Shallows (Cost: ⚡25)"]
	]
	var arr := titles_en if lang == "en" else titles_es
	var pair: Array = arr[clampi(slot_idx, 0, 9)]
	return {"title": str(pair[0]), "desc": str(pair[1])}


static func get_active_hotbar_slot_index(active_tool: String, active_sub_mode: String) -> int:
	if active_tool == "inspect":
		return 0
	if active_tool == "set_biome":
		match active_sub_mode:
			"tropical_forest":
				return 1
			"savanna":
				return 2
			"arid_steppe":
				return 3
			"tundra":
				return 4
			_:
				return 9
	if active_tool == "adjust_altitude":
		return 5 if active_sub_mode == "raise" else 6
	if active_tool == "adjust_carrying_capacity":
		return 7 if active_sub_mode == "enrich" else 8
	if active_tool == "sea_level":
		return 9
	return 0


static func update_hotbar_visuals(hud: Control) -> void:
	if hud._hotbar_slot_buttons.is_empty():
		return
	var visual_key := "%s|%s|%s" % [hud._active_tool, hud._active_sub_mode, hud._lang]
	if visual_key == hud._last_hotbar_visual_key:
		return
	hud._last_hotbar_visual_key = visual_key
	var active_idx := get_active_hotbar_slot_index(hud._active_tool, hud._active_sub_mode)
	for i in range(hud._hotbar_slot_buttons.size()):
		var btn: Button = hud._hotbar_slot_buttons[i]
		var info := get_slot_title_and_desc(hud._lang, i)
		btn.tooltip_text = "[%s] %s\n%s" % [str(HOTBAR_SLOTS_DEF[i]["key"]), info["title"], info["desc"]]
		EvoUiStyle.apply_hotbar_slot_style(btn, i == active_idx)

	var cur_info := get_slot_title_and_desc(hud._lang, active_idx)
	if hud._active_tool == "set_biome" and hud._active_sub_mode in ["coastal_shallows", "ocean", "high_mountain"]:
		var b_lbl := EvoUiStyle.get_biome_label(hud._active_sub_mode, hud._lang)
		hud._equipped_tool_lbl.text = "🐚 %s — %s (⚡10)" % [b_lbl, EvoUiStyle.tr_text(hud._lang, "Moldear bioma costero/cumbre", "Shape coastal/peak biome")]
	else:
		hud._equipped_tool_lbl.text = "%s — %s" % [cur_info["title"], cur_info["desc"]]


static func rebuild_sub_tool_options(hud: Control) -> void:
	if hud._sub_options_flow == null:
		return
	for child in hud._sub_options_flow.get_children():
		child.queue_free()

	var show_tidal_bar: bool = (hud._active_tool == "sea_level") or (hud._active_tool == "set_biome" and hud._active_sub_mode in ["coastal_shallows", "ocean", "high_mountain"])
	if not show_tidal_bar:
		hud._sub_options_panel.visible = false
		return

	hud._sub_options_panel.visible = true

	var plus_sea := Button.new()
	plus_sea.text = EvoUiStyle.tr_text(hud._lang, "🌊 +5% Mar (⚡25)", "🌊 +5% Sea (⚡25)")
	plus_sea.pressed.connect(hud._on_sea_level_btn_pressed.bind(0.05))
	hud._sub_options_flow.add_child(plus_sea)

	var minus_sea := Button.new()
	minus_sea.text = EvoUiStyle.tr_text(hud._lang, "🌊 -5% Mar (⚡25)", "🌊 -5% Sea (⚡25)")
	minus_sea.pressed.connect(hud._on_sea_level_btn_pressed.bind(-0.05))
	hud._sub_options_flow.add_child(minus_sea)

	for extra_b in ["coastal_shallows", "ocean", "high_mountain"]:
		var b_btn := Button.new()
		b_btn.text = EvoUiStyle.get_biome_label(extra_b, hud._lang)
		b_btn.icon = EvoUiStyle.get_pixel_icon(extra_b)
		EvoUiStyle.apply_button_active(b_btn, hud._active_tool == "set_biome" and hud._active_sub_mode == extra_b)
		b_btn.pressed.connect(func() -> void:
			hud._active_tool = "set_biome"
			hud._on_sub_mode_selected(extra_b)
			hud._update_hotbar_visuals()
		)
		hud._sub_options_flow.add_child(b_btn)


static func rebuild_legend_content(hud: Control) -> void:
	refresh_legend_for_hud(hud, hud._world_state, hud._lang)


static func refresh_legend_for_hud(hud: Control, state: EvoTypes.WorldState, lang: String = "es") -> void:
	if hud._legend_vbox == null:
		return
	for child in hud._legend_vbox.get_children():
		child.queue_free()

	if state != null and not state.strategies_catalog.is_empty():
		var strat_header := Label.new()
		strat_header.text = "⚔️ %s" % EvoI18n.t(lang, "legend_strategies")
		strat_header.add_theme_font_size_override("font_size", 13)
		strat_header.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
		hud._legend_vbox.add_child(strat_header)

		var active_strat_ids: Array[String] = []
		if state.strategy_a_id != "" and state.strategies_catalog.has(state.strategy_a_id):
			active_strat_ids.append(state.strategy_a_id)
		if state.strategy_b_id != "" and state.strategies_catalog.has(state.strategy_b_id) and not active_strat_ids.has(state.strategy_b_id):
			active_strat_ids.append(state.strategy_b_id)

		for d_id in state.demes.keys():
			var d: EvoTypes.Deme = state.demes[d_id]
			var sid := d.strategy_id
			if sid == "" and state.lineage_tree.has(d.lineage_id):
				sid = (state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).strategy_id
			if sid != "" and state.strategies_catalog.has(sid) and not active_strat_ids.has(sid):
				active_strat_ids.append(sid)

		for sid in active_strat_ids:
			var strat: EvoTypes.StrategyDef = state.strategies_catalog[sid]
			var v_count := 0
			var total_pop := 0
			for d_id in state.demes.keys():
				var d: EvoTypes.Deme = state.demes[d_id]
				var d_sid := d.strategy_id
				if d_sid == "" and state.lineage_tree.has(d.lineage_id):
					d_sid = (state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).strategy_id
				if d_sid == sid:
					v_count += 1
					total_pop += d.population

			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 6)
			hud._legend_vbox.add_child(s_row)

			var s_sw := ColorRect.new()
			s_sw.custom_minimum_size = Vector2(12, 12)
			s_sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			s_sw.color = Color.from_string(strat.color, Color("#10B981"))
			s_row.add_child(s_sw)

			var s_name := EvoI18n.strategy_name(lang, strat)
			var s_lbl_text := ""
			if lang == "en":
				var v_word := "village" if v_count == 1 else "villages"
				s_lbl_text = "%s %s (%d %s · %d pop.)" % [strat.icon, s_name, v_count, v_word, total_pop]
			else:
				var v_word := "aldea" if v_count == 1 else "aldeas"
				s_lbl_text = "%s %s (%d %s · %d hab.)" % [strat.icon, s_name, v_count, v_word, total_pop]

			var s_lbl := Label.new()
			s_lbl.text = s_lbl_text
			s_lbl.add_theme_font_size_override("font_size", 11)
			s_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
			s_row.add_child(s_lbl)

		var sep := HSeparator.new()
		hud._legend_vbox.add_child(sep)

	var title := Label.new()
	title.text = EvoUiStyle.tr_text(lang, "🗺️ Leyenda del Valle", "🗺️ Valley Legend")
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._legend_vbox.add_child(title)

	for b_id in EvoTypes.BIOMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		hud._legend_vbox.add_child(row)

		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(12, 12)
		sw.color = EvoUiStyle.get_biome_color(b_id)
		row.add_child(sw)

		var lbl := Label.new()
		lbl.text = EvoUiStyle.get_biome_label(b_id, lang)
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = EvoUiStyle.tr_text(
		lang,
		"Aldeas: I Campamento · II Caserío · III Aldea · IV Poblado\nCaminos: 🛣️ Cooperación · ⚔️ Disputa · 🧭 Migración",
		"Villages: I Camp · II Hamlet · III Village · IV Settlement\nPaths: 🛣️ Cooperation · ⚔️ Dispute · 🧭 Migration"
	)
	tier_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	hud._legend_vbox.add_child(tier_lbl)

	var flow_sep := HSeparator.new()
	hud._legend_vbox.add_child(flow_sep)

	var geo_title := Label.new()
	geo_title.text = EvoUiStyle.tr_text(lang, "🗺️ Leyenda Geopolítica", "🗺️ Geopolitical Legend")
	geo_title.add_theme_font_size_override("font_size", 12)
	geo_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._legend_vbox.add_child(geo_title)

	var legend_defs := [
		{"key": "legend_flow_pact", "icon": "icon_pact", "color": Color("#10b981")},
		{"key": "legend_flow_war", "icon": "icon_war", "color": Color("#ef4444")},
		{"key": "legend_flow_raid", "icon": "icon_raid", "color": Color("#f97316")},
		{"key": "legend_flow_betrayal", "icon": "icon_betrayal", "color": Color("#be123c")}
	]
	for def in legend_defs:
		var f_row := HBoxContainer.new()
		f_row.add_theme_constant_override("separation", 6)
		hud._legend_vbox.add_child(f_row)

		var f_sw := ColorRect.new()
		f_sw.custom_minimum_size = Vector2(12, 12)
		f_sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f_sw.color = def["color"]
		f_row.add_child(f_sw)

		var f_icon := TextureRect.new()
		f_icon.custom_minimum_size = Vector2(14, 14)
		f_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		f_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		f_icon.texture = EvoUiStyle.get_pixel_icon(str(def["icon"]))
		f_row.add_child(f_icon)

		var f_lbl := Label.new()
		f_lbl.text = EvoI18n.t(lang, str(def["key"]))
		f_lbl.add_theme_font_size_override("font_size", 11)
		f_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
		f_row.add_child(f_lbl)
