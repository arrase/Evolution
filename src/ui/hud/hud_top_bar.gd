class_name EvoHudTopBar
extends RefCounted

const PRESET_LIST: Array[String] = [
	"preset-rift-savanna",
	"preset-darwin-archipelago",
	"preset-finite-island"
]


class SeasonTidePortrait extends Control:
	var is_wet_warm: bool = true
	var sea_level_ratio: float = 0.12

	func _init() -> void:
		clip_contents = true

	func set_state(p_wet_warm: bool, p_sea_level: float) -> void:
		if is_wet_warm != p_wet_warm or not is_equal_approx(sea_level_ratio, p_sea_level):
			is_wet_warm = p_wet_warm
			sea_level_ratio = clampf(p_sea_level, 0.0, 0.60)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 10.0 or r.size.y < 10.0:
			return
		# Sky background
		var sky_top := Color("#7dd3fc") if is_wet_warm else Color("#334155")
		var sky_bot := Color("#fef08a") if is_wet_warm else Color("#94a3b8")
		var steps := 12
		for i in range(steps):
			var t := float(i) / float(steps)
			var y0 := r.size.y * t
			var h0 := r.size.y / float(steps) + 1.0
			draw_rect(Rect2(0, y0, r.size.x, h0), sky_top.lerp(sky_bot, t), true)

		if is_wet_warm:
			# Radiant pixel sun
			var sun_c := Vector2(r.size.x * 0.72, r.size.y * 0.24)
			draw_circle(sun_c, 13.0, Color(1.0, 0.85, 0.25, 0.35))
			draw_circle(sun_c, 9.0, Color("#f59e0b"))
			draw_circle(sun_c, 6.5, Color("#fef08a"))
		else:
			# Pale winter moon & snowflakes
			var moon_c := Vector2(r.size.x * 0.74, r.size.y * 0.22)
			draw_circle(moon_c, 7.5, Color("#e2e8f0"))
			draw_circle(moon_c + Vector2(2.5, -1.5), 6.0, sky_top)
			for sx in [14, 28, 46, 64, 78, 22, 54]:
				var sy := int(sx * 1.3) % int(maxf(20.0, r.size.y * 0.55)) + 6
				draw_rect(Rect2(sx, sy, 2, 2), Color("#f8fafc"), true)

		# Compute water line first so hills clamp cleanly above the sea
		var water_frac := clampf(0.18 + sea_level_ratio * 0.55, 0.14, 0.48)
		var water_h := r.size.y * water_frac
		var water_y := r.size.y - water_h

		# Distant mountain & rolling hills clamped at water_y
		var hill_back := Color("#15803d") if is_wet_warm else Color("#64748b")
		var hill_front := Color("#22c55e") if is_wet_warm else Color("#cbd5e1")
		var horizon_y := minf(r.size.y * 0.50, water_y - 6.0)
		var back_poly := PackedVector2Array([
			Vector2(0.0, water_y),
			Vector2(0.0, horizon_y + 4.0),
			Vector2(r.size.x * 0.26, horizon_y - 3.0),
			Vector2(r.size.x * 0.54, horizon_y + 2.0),
			Vector2(r.size.x * 0.78, horizon_y - 2.0),
			Vector2(r.size.x, horizon_y + 3.0),
			Vector2(r.size.x, water_y),
		])
		draw_colored_polygon(back_poly, hill_back)
		var front_poly := PackedVector2Array([
			Vector2(0.0, water_y),
			Vector2(0.0, horizon_y + 7.0),
			Vector2(r.size.x * 0.36, horizon_y + 1.0),
			Vector2(r.size.x * 0.66, horizon_y + 5.0),
			Vector2(r.size.x, horizon_y + 2.0),
			Vector2(r.size.x, water_y),
		])
		draw_colored_polygon(front_poly, hill_front)

		# Pixel tree silhouette on hill
		var tx := r.size.x * 0.32
		var ty := horizon_y - 1.0
		draw_rect(Rect2(tx - 1.0, ty - 3.0, 2.0, 5.0), Color("#5c3218"), true)
		draw_circle(Vector2(tx, ty - 5.0), 3.5, Color("#166534") if is_wet_warm else Color("#f1f5f9"))

		# Sea level tide at bottom
		var sea_col := Color("#0284c7") if is_wet_warm else Color("#1e3a8a")
		var foam_col := Color("#7dd3fc") if is_wet_warm else Color("#bae6fd")
		draw_rect(Rect2(0, water_y, r.size.x, water_h), sea_col, true)
		draw_rect(Rect2(0, water_y, r.size.x, 2.0), foam_col, true)

		# Inner wooden frame border + brass corner rivets
		draw_rect(r, EvoUiStyle.COLOR_WOOD_DARK, false, 2.0)
		for corner in [Vector2(3, 3), Vector2(r.size.x - 5, 3), Vector2(3, r.size.y - 5), Vector2(r.size.x - 5, r.size.y - 5)]:
			draw_rect(Rect2(corner, Vector2(2, 2)), EvoUiStyle.COLOR_GOLD_BRIGHT, true)


static func build_top_left_valley_sign_and_medallions(hud: Control) -> void:
	var sign_frame := PanelContainer.new()
	sign_frame.anchor_left = 0.0
	sign_frame.anchor_right = 0.0
	sign_frame.anchor_top = 0.0
	sign_frame.anchor_bottom = 0.0
	sign_frame.offset_left = 10
	sign_frame.offset_right = 376
	sign_frame.offset_top = 10
	sign_frame.offset_bottom = 122
	sign_frame.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(7))
	hud.add_child(sign_frame)

	var sign_vbox := VBoxContainer.new()
	sign_vbox.add_theme_constant_override("separation", 5)
	sign_frame.add_child(sign_vbox)

	# Row 1: World Preset Selector + Compact Save/Load Buttons
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 4)
	sign_vbox.add_child(preset_row)

	hud._preset_option = OptionButton.new()
	hud._preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._preset_option.fit_to_longest_item = false
	hud._preset_option.clip_text = true
	hud._preset_option.item_selected.connect(hud._on_preset_selected)
	preset_row.add_child(hud._preset_option)

	hud._export_btn = Button.new()
	hud._export_btn.custom_minimum_size = Vector2(32, 28)
	hud._export_btn.pressed.connect(hud._on_export_pressed)
	preset_row.add_child(hud._export_btn)

	hud._import_btn = Button.new()
	hud._import_btn.custom_minimum_size = Vector2(32, 28)
	hud._import_btn.pressed.connect(hud._on_import_pressed)
	preset_row.add_child(hud._import_btn)

	# Row 2: 3 Artifact Buttons (Diario, Linajes, Forja)
	var artifacts_row := HBoxContainer.new()
	artifacts_row.add_theme_constant_override("separation", 4)
	sign_vbox.add_child(artifacts_row)

	hud._notebook_btn = Button.new()
	hud._notebook_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._notebook_btn.pressed.connect(hud.open_notebook_modal)
	artifacts_row.add_child(hud._notebook_btn)

	hud._tree_btn = Button.new()
	hud._tree_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._tree_btn.pressed.connect(hud._on_tree_btn_pressed)
	artifacts_row.add_child(hud._tree_btn)

	hud._lab_btn = Button.new()
	hud._lab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._lab_btn.pressed.connect(hud.open_lab_modal)
	artifacts_row.add_child(hud._lab_btn)

	# Row 3: Compact Lens Pills + Map Legend Toggle
	hud._lens_strip_panel = PanelContainer.new()
	hud._lens_strip_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(EvoUiStyle.COLOR_PARCHMENT, EvoUiStyle.COLOR_GOLD_BEVEL, 4))
	sign_vbox.add_child(hud._lens_strip_panel)

	var lens_hbox := HBoxContainer.new()
	lens_hbox.add_theme_constant_override("separation", 4)
	hud._lens_strip_panel.add_child(lens_hbox)

	for l_id in ["biome", "food", "health"]:
		var l_btn := Button.new()
		l_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l_btn.add_theme_font_size_override("font_size", 11)
		l_btn.pressed.connect(hud._on_lens_pressed.bind(l_id))
		lens_hbox.add_child(l_btn)
		hud._lens_buttons[l_id] = l_btn

	hud._legend_toggle_btn = Button.new()
	hud._legend_toggle_btn.add_theme_font_size_override("font_size", 11)
	hud._legend_toggle_btn.pressed.connect(hud._on_legend_toggle_pressed)
	lens_hbox.add_child(hud._legend_toggle_btn)


static func build_top_right_clock(hud: Control) -> void:
	var clock_frame := PanelContainer.new()
	clock_frame.anchor_left = 1.0
	clock_frame.anchor_right = 1.0
	clock_frame.anchor_top = 0.0
	clock_frame.anchor_bottom = 0.0
	clock_frame.offset_left = -356
	clock_frame.offset_right = -10
	clock_frame.offset_top = 10
	clock_frame.offset_bottom = 126
	clock_frame.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(7))
	hud.add_child(clock_frame)

	var clock_hbox := HBoxContainer.new()
	clock_hbox.add_theme_constant_override("separation", 7)
	clock_frame.add_child(clock_hbox)

	# Left: Illustrated Season & Tide Window
	var portrait_card := PanelContainer.new()
	portrait_card.custom_minimum_size = Vector2(80, 0)
	portrait_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(EvoUiStyle.COLOR_WOOD_DARK, EvoUiStyle.COLOR_GOLD_BEVEL, 3))
	clock_hbox.add_child(portrait_card)

	var portrait_vbox := VBoxContainer.new()
	portrait_vbox.add_theme_constant_override("separation", 2)
	portrait_card.add_child(portrait_vbox)

	hud._season_portrait = SeasonTidePortrait.new()
	hud._season_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._season_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud._season_portrait.custom_minimum_size = Vector2(72, 76)
	portrait_vbox.add_child(hud._season_portrait)

	var tide_row := HBoxContainer.new()
	tide_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tide_row.add_theme_constant_override("separation", 3)
	portrait_vbox.add_child(tide_row)

	hud._sea_level_label = Label.new()
	hud._sea_level_label.text = "🌊 12%"
	hud._sea_level_label.add_theme_font_size_override("font_size", 11)
	hud._sea_level_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT)
	tide_row.add_child(hud._sea_level_label)

	# Right: Generation Dial, Time Controls & Mana Bar
	var dial_panel := PanelContainer.new()
	dial_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dial_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(6, false))
	clock_hbox.add_child(dial_panel)

	var dial_vbox := VBoxContainer.new()
	dial_vbox.add_theme_constant_override("separation", 4)
	dial_panel.add_child(dial_vbox)

	# Row 1: Generation & Season Banner
	var gen_row := HBoxContainer.new()
	gen_row.add_theme_constant_override("separation", 6)
	dial_vbox.add_child(gen_row)

	hud._gen_label = Label.new()
	hud._gen_label.text = "📅 Gen 0"
	hud._gen_label.add_theme_font_size_override("font_size", 13)
	hud._gen_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	gen_row.add_child(hud._gen_label)

	hud._season_label = Label.new()
	hud._season_label.text = "☀️ Primavera Cálida"
	hud._season_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._season_label.clip_text = true
	hud._season_label.add_theme_font_size_override("font_size", 11)
	hud._season_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	gen_row.add_child(hud._season_label)

	# Row 2: Tactile Wood/Gold Time Controls + Settings Gear
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 4)
	dial_vbox.add_child(time_row)

	hud._play_btn = Button.new()
	hud._play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._play_btn.pressed.connect(hud._on_play_pressed)
	time_row.add_child(hud._play_btn)

	hud._step_btn = Button.new()
	hud._step_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._step_btn.pressed.connect(hud._on_step_pressed)
	time_row.add_child(hud._step_btn)

	hud._speed_btn = Button.new()
	hud._speed_btn.pressed.connect(hud._on_speed_pressed)
	time_row.add_child(hud._speed_btn)

	hud._settings_btn = Button.new()
	hud._settings_btn.icon = EvoUiStyle.get_pixel_icon("settings_gear")
	hud._settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._settings_btn.custom_minimum_size = Vector2(30, 0)
	hud._settings_btn.pressed.connect(hud._on_settings_btn_pressed)
	time_row.add_child(hud._settings_btn)

	# Row 3: Selective Pressure / Mana Bar
	var mana_box := PanelContainer.new()
	mana_box.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(EvoUiStyle.COLOR_WOOD_DARK, EvoUiStyle.COLOR_GOLD_BEVEL))
	dial_vbox.add_child(mana_box)

	var mana_vbox := VBoxContainer.new()
	mana_vbox.add_theme_constant_override("separation", 2)
	mana_box.add_child(mana_vbox)

	hud._pressure_label = Label.new()
	hud._pressure_label.text = "⚡ 30 pts · +15/gen"
	hud._pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._pressure_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT)
	hud._pressure_label.add_theme_font_size_override("font_size", 11)
	mana_vbox.add_child(hud._pressure_label)

	hud._pressure_bar = ProgressBar.new()
	hud._pressure_bar.min_value = 0.0
	hud._pressure_bar.max_value = 100.0
	hud._pressure_bar.value = 30.0
	hud._pressure_bar.show_percentage = false
	hud._pressure_bar.custom_minimum_size = Vector2(0, 6)
	EvoUiStyle.style_progress_bar(hud._pressure_bar, Color("#22c55e"))
	mana_vbox.add_child(hud._pressure_bar)


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

	var rot_q_btn := Button.new()
	rot_q_btn.text = "↺ Q (-18°)"
	rot_q_btn.pressed.connect(hud._on_cam_preset_pressed.bind("yaw", -18.0))
	cam_flow.add_child(rot_q_btn)

	var rot_e_btn := Button.new()
	rot_e_btn.text = "↻ E (+18°)"
	rot_e_btn.pressed.connect(hud._on_cam_preset_pressed.bind("yaw", 18.0))
	cam_flow.add_child(rot_e_btn)

	var reset_cam_btn := Button.new()
	reset_cam_btn.text = "🎯 Reset"
	reset_cam_btn.pressed.connect(hud._on_cam_preset_pressed.bind("reset", 0.0))
	cam_flow.add_child(reset_cam_btn)


static func update_static_labels(hud: Control) -> void:
	if hud._preset_option == null:
		return

	var prev_sel := maxi(0, hud._preset_option.selected)
	hud._preset_option.clear()
	var preset_names_es := [
		"🌍 El Valle del Rift",
		"🏝️ Archipiélago de Darwin",
		"🗿 La Isla Finita"
	]
	var preset_names_en := [
		"🌍 The Rift Valley",
		"🏝️ Darwin's Archipelago",
		"🗿 The Finite Island"
	]
	for i in range(PRESET_LIST.size()):
		var lbl_str: String = preset_names_en[i] if hud._lang == "en" else preset_names_es[i]
		hud._preset_option.add_item(lbl_str, i)
		hud._preset_option.set_item_metadata(i, PRESET_LIST[i])
	if hud._world_state != null:
		var idx := PRESET_LIST.find(hud._world_state.preset_id)
		if idx >= 0:
			hud._preset_option.select(idx)
	elif prev_sel < hud._preset_option.item_count:
		hud._preset_option.select(prev_sel)

	hud._export_btn.text = "💾"
	hud._export_btn.tooltip_text = EvoUiStyle.tr_text(hud._lang, "Exportar Mundo (JSON)", "Export World (JSON)")
	hud._import_btn.text = "📂"
	hud._import_btn.tooltip_text = EvoUiStyle.tr_text(hud._lang, "Importar Mundo (JSON)", "Import World (JSON)")

	if hud._is_playing:
		hud._play_btn.text = EvoUiStyle.tr_text(hud._lang, "⏸ Pausa", "⏸ Pause")
	else:
		hud._play_btn.text = EvoUiStyle.tr_text(hud._lang, "▶ Play", "▶ Play")
	EvoUiStyle.apply_button_active(hud._play_btn, hud._is_playing)

	hud._step_btn.text = EvoUiStyle.tr_text(hud._lang, "⏭ +1", "⏭ +1")
	hud._speed_btn.text = "2x" if hud._is_fast else "1x"
	EvoUiStyle.apply_button_active(hud._speed_btn, hud._is_fast)

	hud._notebook_btn.text = EvoUiStyle.tr_text(hud._lang, "📖 Diario", "📖 Journal")
	hud._tree_btn.text = EvoUiStyle.tr_text(hud._lang, "🌳 Linajes", "🌳 Lineages")
	hud._lab_btn.text = EvoUiStyle.tr_text(hud._lang, "⚗️ Forja", "⚗️ Forge")
	if hud._lens_cycle_btn != null:
		hud._lens_cycle_btn.text = EvoUiStyle.tr_text(hud._lang, "👁️ Lente", "👁️ Lens")

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

	hud._radius_1_btn.text = "◯ 1x"
	hud._radius_1_btn.tooltip_text = EvoUiStyle.tr_text(hud._lang, "Pincel de 1 hexágono", "1-hex brush")
	hud._radius_2_btn.text = "◎ 7x"
	hud._radius_2_btn.tooltip_text = EvoUiStyle.tr_text(hud._lang, "Pincel de 7 hexágonos", "7-hex brush")
	EvoUiStyle.apply_button_active(hud._radius_1_btn, hud._brush_radius == 1)
	EvoUiStyle.apply_button_active(hud._radius_2_btn, hud._brush_radius == 2)

	(hud._lens_buttons["biome"] as Button).text = EvoUiStyle.tr_text(hud._lang, "🌿 Bioma", "🌿 Biome")
	(hud._lens_buttons["food"] as Button).text = EvoUiStyle.tr_text(hud._lang, "🌾 Alimento", "🌾 Food")
	(hud._lens_buttons["health"] as Button).text = EvoUiStyle.tr_text(hud._lang, "💚 Salud", "💚 Health")
	for l_id in hud._lens_buttons.keys():
		EvoUiStyle.apply_button_active(hud._lens_buttons[l_id] as Button, hud._active_lens == l_id)

	hud._legend_toggle_btn.text = EvoUiStyle.tr_text(hud._lang, "🗺️ Leyenda", "🗺️ Legend")
	EvoUiStyle.apply_button_active(hud._legend_toggle_btn, hud._legend_panel.visible)

	hud._tab_deme_btn.text = EvoUiStyle.tr_text(hud._lang, "🧠 Aldea", "🧠 Village")
	hud._tab_traits_btn.text = EvoUiStyle.tr_text(hud._lang, "🧬 Rasgos", "🧬 Traits")
	hud._tab_habitat_btn.text = EvoUiStyle.tr_text(hud._lang, "🌿 Hábitat", "🌿 Habitat")
	EvoUiStyle.apply_button_active(hud._tab_deme_btn, hud._inspector_tab == "deme")
	EvoUiStyle.apply_button_active(hud._tab_traits_btn, hud._inspector_tab == "traits")
	EvoUiStyle.apply_button_active(hud._tab_habitat_btn, hud._inspector_tab == "habitat")

	if hud._villages_title_lbl != null:
		hud._villages_title_lbl.text = EvoUiStyle.tr_text(hud._lang, "🏘️ Aldeas Vivas del Valle", "🏘️ Living Valley Villages")


static func update_top_bar_state(hud: Control) -> void:
	if hud._world_state == null:
		return
	var year_num := int(hud._world_state.generation / 2) + 1
	hud._gen_label.text = EvoUiStyle.tr_text(
		hud._lang,
		"📅 Año %d · Gen %d" % [year_num, hud._world_state.generation],
		"📅 Yr %d · Gen %d" % [year_num, hud._world_state.generation]
	)
	var is_wet: bool = (hud._world_state.season == "wet_warm")
	if is_wet:
		hud._season_label.text = EvoUiStyle.tr_text(hud._lang, "☀️ Primavera Cálida", "☀️ Warm Spring")
		if hud._season_icon != null:
			hud._season_icon.texture = EvoUiStyle.get_pixel_icon("season_wet")
	else:
		hud._season_label.text = EvoUiStyle.tr_text(hud._lang, "❄️ Invierno Seco", "❄️ Dry Winter")
		if hud._season_icon != null:
			hud._season_icon.texture = EvoUiStyle.get_pixel_icon("season_dry")

	var sea_pct := int(round(hud._world_state.sea_level * 100.0))
	hud._sea_level_label.text = "🌊 %d%%" % sea_pct
	hud._season_portrait.set_state(is_wet, hud._world_state.sea_level)

	if hud._world_state.unlimited_pressure_mode:
		hud._pressure_label.text = EvoUiStyle.tr_text(hud._lang, "⚡ ∞ Maná Ilimitado", "⚡ ∞ Unlimited Mana")
		hud._pressure_bar.value = 100.0
	else:
		hud._pressure_label.text = "⚡ %d pts · +%d/gen" % [hud._world_state.selective_pressure_points, hud._world_state.selective_pressure_regen_per_turn]
		hud._pressure_bar.value = clampf(float(hud._world_state.selective_pressure_points), 0.0, 100.0)

	# Compute System 1 Models summary dynamically using active primary and secondary models
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
