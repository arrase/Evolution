class_name EvoMainHud
extends Control

signal preset_selected(preset_id: String)
signal export_json_requested(file_path: String)
signal import_json_requested(file_path: String)
signal state_imported(new_state: EvoTypes.WorldState)
signal play_pause_toggled(is_playing: bool)
signal step_generation_requested()
signal speed_changed(is_fast: bool)
signal language_changed(lang: String)
signal settings_changed(auto_pause: bool, unlimited_pressure: bool, free_sandbox: bool)
signal camera_preset_requested(action: String, value: float)
signal tool_changed(tool_id: String, sub_mode: String, brush_radius: int)
signal sea_level_change_requested(delta: float)
signal lens_changed(lens_id: String)
signal deme_selected(deme_id: String, hex_id: String)
signal hex_jump_requested(hex_id: String, deme_id: String)
signal lineage_highlight_requested(lineage_id: String)
signal inject_trait_requested(deme_id: String, trait_id: String)
signal catalog_item_saved(item_type: String, item_data: Dictionary)

const PRESET_LIST: Array[String] = [
	"preset-rift-savanna",
	"preset-darwin-archipelago",
	"preset-finite-island"
]

const DEFAULT_EXPORT_PATH: String = "user://evolution_world_state.json"

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

var _world_state: EvoTypes.WorldState = null
var _lang: String = "es"
var _is_playing: bool = false
var _is_fast: bool = false

var _active_tool: String = "inspect"
var _active_sub_mode: String = "savanna"
var _brush_radius: int = 1
var _active_lens: String = "biome"

var _selected_hex_id: String = "0,0"
var _selected_deme_id: String = ""
var _highlighted_lineage_id: String = ""
var _last_seen_chronicle_count: int = 0

var _step_1_done: bool = false
var _step_2_done: bool = false
var _step_3_done: bool = false

# Top-Left Valley Sign, Artifacts & Living Village Medallions
var _preset_option: OptionButton
var _export_btn: Button
var _import_btn: Button
var _notebook_btn: Button
var _tree_btn: Button
var _lab_btn: Button
var _lens_cycle_btn: Button
var _lens_strip_panel: PanelContainer
var _lens_buttons: Dictionary = {} # lens_id -> Button
var _legend_toggle_btn: Button
var _legend_panel: PanelContainer
var _legend_vbox: VBoxContainer
var _villages_title_lbl: Label
var _villages_list_vbox: VBoxContainer
var _village_buttons_pool: Array[Button] = []
var _empty_villages_lbl: Label
var _last_hotbar_visual_key: String = ""

# Top-Right Stardew Clock & Cognitive Engine Widget
var _season_portrait: SeasonTidePortrait
var _season_icon: TextureRect
var _gen_label: Label
var _season_label: Label
var _sea_level_label: Label
var _play_btn: Button
var _step_btn: Button
var _speed_btn: Button
var _pressure_bar: ProgressBar
var _pressure_label: Label
var _settings_btn: Button

# Settings, Camera & Ollama Models Diagnostic Popup
var _settings_popup: PanelContainer
var _models_diag_lbl: Label
var _live_models_check: CheckBox
var _lang_es_btn: Button
var _lang_en_btn: Button
var _auto_pause_check: CheckBox
var _unlimited_pressure_check: CheckBox
var _free_sandbox_check: CheckBox
var _cam_lbl: Label

# Bottom-Center 10-Slot Stardew Inventory Hotbar
var _hotbar_slot_buttons: Array[Button] = []
var _tool_buttons: Dictionary = {} # tool_id -> Button (API compatibility)
var _equipped_tool_banner: PanelContainer
var _equipped_tool_lbl: Label
var _sub_options_panel: PanelContainer
var _sub_options_flow: HFlowContainer
var _radius_1_btn: Button
var _radius_2_btn: Button

# Right Floating Parchment Scroll Inspector (`StardewScrollInspector`)
var _inspector_frame: PanelContainer
var _inspector_body_vbox: VBoxContainer
var _inspector_minimized: bool = false
var _inspector_minimize_btn: Button
var _inspector_tab: String = "deme" # "deme" | "traits" | "habitat"
var _inspector_header_swatch: ColorRect
var _inspector_header_title: Label
var _inspector_header_hl_btn: Button
var _inspector_model_badge_lbl: Label
var _tab_deme_btn: Button
var _tab_traits_btn: Button
var _tab_habitat_btn: Button
var _inspector_scroll: ScrollContainer
var _deme_sheet_vbox: VBoxContainer
var _traits_sheet_vbox: VBoxContainer
var _hex_sheet_vbox: VBoxContainer

# Banners, Toasts & First Steps
var _milestone_banner: PanelContainer
var _banner_title_lbl: Label
var _banner_summary_lbl: Label
var _toast_vbox: VBoxContainer
var _first_steps_panel: PanelContainer
var _step1_lbl: Label
var _step2_lbl: Label
var _step3_lbl: Label

# Modals
var notebook_modal: EvoNotebookModal
var tree_modal: EvoTreeModal
var lab_modal: EvoLabModal


class SeasonTidePortrait extends Control:
	var is_wet_warm: bool = true
	var sea_level_ratio: float = 0.12

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

		# Distant mountain & rolling hills
		var hill_back := Color("#15803d") if is_wet_warm else Color("#64748b")
		var hill_front := Color("#22c55e") if is_wet_warm else Color("#cbd5e1")
		var horizon_y := r.size.y * 0.56
		draw_circle(Vector2(r.size.x * 0.28, horizon_y + 18.0), 30.0, hill_back)
		draw_circle(Vector2(r.size.x * 0.74, horizon_y + 16.0), 28.0, hill_back.darkened(0.12))
		draw_circle(Vector2(r.size.x * 0.50, horizon_y + 24.0), 34.0, hill_front)

		# Pixel tree silhouette on hill
		var tx := r.size.x * 0.32
		var ty := horizon_y - 4.0
		draw_rect(Rect2(tx - 1.5, ty, 3.0, 7.0), Color("#5c3218"), true)
		draw_circle(Vector2(tx, ty - 2.0), 5.5, Color("#166534") if is_wet_warm else Color("#f1f5f9"))

		# Sea level tide at bottom
		var water_frac := clampf(0.18 + sea_level_ratio * 0.55, 0.14, 0.48)
		var water_h := r.size.y * water_frac
		var water_y := r.size.y - water_h
		var sea_col := Color("#0284c7") if is_wet_warm else Color("#1e3a8a")
		var foam_col := Color("#7dd3fc") if is_wet_warm else Color("#bae6fd")
		draw_rect(Rect2(0, water_y, r.size.x, water_h), sea_col, true)
		draw_rect(Rect2(0, water_y, r.size.x, 2.0), foam_col, true)

		# Inner wooden frame border + brass corner rivets
		draw_rect(r, EvoStardewStyle.COLOR_WOOD_DARK, false, 2.0)
		for corner in [Vector2(3, 3), Vector2(r.size.x - 5, 3), Vector2(3, r.size.y - 5), Vector2(r.size.x - 5, r.size.y - 5)]:
			draw_rect(Rect2(corner, Vector2(2, 2)), EvoStardewStyle.COLOR_GOLD_BRIGHT, true)


func _ready() -> void:
	if _preset_option != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = EvoStardewStyle.get_theme()
	_build_ui()
	set_process(true)
	set_process_unhandled_key_input(true)


func _process(delta: float) -> void:
	if _toast_vbox == null:
		return
	for child in _toast_vbox.get_children():
		if child.has_meta("ttl"):
			var ttl: float = float(child.get_meta("ttl")) - delta
			if ttl <= 0.0:
				child.queue_free()
			else:
				child.set_meta("ttl", ttl)
				if ttl < 1.0:
					(child as CanvasItem).modulate.a = clampf(ttl, 0.0, 1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if (notebook_modal != null and notebook_modal.visible) or (tree_modal != null and tree_modal.visible) or (lab_modal != null and lab_modal.visible):
		return
	var slot_idx := -1
	match ke.keycode:
		KEY_1, KEY_KP_1:
			slot_idx = 0
		KEY_2, KEY_KP_2:
			slot_idx = 1
		KEY_3, KEY_KP_3:
			slot_idx = 2
		KEY_4, KEY_KP_4:
			slot_idx = 3
		KEY_5, KEY_KP_5:
			slot_idx = 4
		KEY_6, KEY_KP_6:
			slot_idx = 5
		KEY_7, KEY_KP_7:
			slot_idx = 6
		KEY_8, KEY_KP_8:
			slot_idx = 7
		KEY_9, KEY_KP_9:
			slot_idx = 8
		KEY_0, KEY_KP_0:
			slot_idx = 9
	if slot_idx >= 0:
		_on_hotbar_slot_pressed(slot_idx)
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_build_top_left_valley_sign_and_medallions()
	_build_top_right_stardew_clock()
	_build_settings_popup()
	_build_bottom_stardew_hotbar()
	_build_legend_panel()
	_build_right_scroll_inspector()
	_build_banners_and_toasts()
	_build_modals()
	_update_static_labels()
	_rebuild_sub_tool_options()
	_rebuild_legend_content()


func _build_top_left_valley_sign_and_medallions() -> void:
	# 1. Hanging Wooden Valley Sign (~364 px wide in top-left corner)
	var sign_frame := PanelContainer.new()
	sign_frame.anchor_left = 0.0
	sign_frame.anchor_right = 0.0
	sign_frame.anchor_top = 0.0
	sign_frame.anchor_bottom = 0.0
	sign_frame.offset_left = 10
	sign_frame.offset_right = 376
	sign_frame.offset_top = 10
	sign_frame.offset_bottom = 128
	sign_frame.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(7))
	add_child(sign_frame)

	var sign_vbox := VBoxContainer.new()
	sign_vbox.add_theme_constant_override("separation", 5)
	sign_frame.add_child(sign_vbox)

	# Row 1: World Preset Selector + Compact Save/Load Buttons
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 4)
	sign_vbox.add_child(preset_row)

	_preset_option = OptionButton.new()
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_option.fit_to_longest_item = false
	_preset_option.clip_text = true
	_preset_option.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_preset_option)

	_export_btn = Button.new()
	_export_btn.custom_minimum_size = Vector2(32, 28)
	_export_btn.pressed.connect(_on_export_pressed)
	preset_row.add_child(_export_btn)

	_import_btn = Button.new()
	_import_btn.custom_minimum_size = Vector2(32, 28)
	_import_btn.pressed.connect(_on_import_pressed)
	preset_row.add_child(_import_btn)

	# Row 2: 4 Artifact Buttons (Diario, Linajes, Forja, Lente)
	var artifacts_row := HBoxContainer.new()
	artifacts_row.add_theme_constant_override("separation", 4)
	sign_vbox.add_child(artifacts_row)

	_notebook_btn = Button.new()
	_notebook_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notebook_btn.pressed.connect(open_notebook_modal)
	artifacts_row.add_child(_notebook_btn)

	_tree_btn = Button.new()
	_tree_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_btn.pressed.connect(_on_tree_btn_pressed)
	artifacts_row.add_child(_tree_btn)

	_lab_btn = Button.new()
	_lab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab_btn.pressed.connect(open_lab_modal)
	artifacts_row.add_child(_lab_btn)

	_lens_cycle_btn = Button.new()
	_lens_cycle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lens_cycle_btn.pressed.connect(_on_lens_cycle_btn_pressed)
	artifacts_row.add_child(_lens_cycle_btn)

	# Row 3: Compact Lens Pills + Map Legend Toggle
	_lens_strip_panel = PanelContainer.new()
	_lens_strip_panel.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_card(EvoStardewStyle.COLOR_PARCHMENT, EvoStardewStyle.COLOR_GOLD_BEVEL, 4))
	sign_vbox.add_child(_lens_strip_panel)

	var lens_hbox := HBoxContainer.new()
	lens_hbox.add_theme_constant_override("separation", 4)
	_lens_strip_panel.add_child(lens_hbox)

	for l_id in ["biome", "food", "health"]:
		var l_btn := Button.new()
		l_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l_btn.add_theme_font_size_override("font_size", 11)
		l_btn.pressed.connect(_on_lens_pressed.bind(l_id))
		lens_hbox.add_child(l_btn)
		_lens_buttons[l_id] = l_btn

	_legend_toggle_btn = Button.new()
	_legend_toggle_btn.add_theme_font_size_override("font_size", 11)
	_legend_toggle_btn.pressed.connect(_on_legend_toggle_pressed)
	lens_hbox.add_child(_legend_toggle_btn)

	# 2. Compact Strip of Living Village Medallions right below the Valley Sign
	var medallions_frame := PanelContainer.new()
	medallions_frame.anchor_left = 0.0
	medallions_frame.anchor_right = 0.0
	medallions_frame.anchor_top = 0.0
	medallions_frame.anchor_bottom = 0.0
	medallions_frame.offset_left = 10
	medallions_frame.offset_right = 278
	medallions_frame.offset_top = 134
	medallions_frame.offset_bottom = 330
	medallions_frame.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(6))
	add_child(medallions_frame)

	var med_inner := PanelContainer.new()
	med_inner.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_panel(6, true))
	medallions_frame.add_child(med_inner)

	var med_vbox := VBoxContainer.new()
	med_vbox.add_theme_constant_override("separation", 4)
	med_inner.add_child(med_vbox)

	_villages_title_lbl = Label.new()
	_villages_title_lbl.add_theme_font_size_override("font_size", 12)
	_villages_title_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	med_vbox.add_child(_villages_title_lbl)

	var med_scroll := ScrollContainer.new()
	med_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	med_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	med_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	med_vbox.add_child(med_scroll)

	_villages_list_vbox = VBoxContainer.new()
	_villages_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_villages_list_vbox.add_theme_constant_override("separation", 4)
	med_scroll.add_child(_villages_list_vbox)


func _build_top_right_stardew_clock() -> void:
	var clock_frame := PanelContainer.new()
	clock_frame.anchor_left = 1.0
	clock_frame.anchor_right = 1.0
	clock_frame.anchor_top = 0.0
	clock_frame.anchor_bottom = 0.0
	clock_frame.offset_left = -356
	clock_frame.offset_right = -10
	clock_frame.offset_top = 10
	clock_frame.offset_bottom = 160
	clock_frame.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(7))
	add_child(clock_frame)

	var clock_hbox := HBoxContainer.new()
	clock_hbox.add_theme_constant_override("separation", 7)
	clock_frame.add_child(clock_hbox)

	# Left: Illustrated Season & Tide Window
	var portrait_card := PanelContainer.new()
	portrait_card.custom_minimum_size = Vector2(92, 0)
	portrait_card.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_card(EvoStardewStyle.COLOR_WOOD_DARK, EvoStardewStyle.COLOR_GOLD_BEVEL, 3))
	clock_hbox.add_child(portrait_card)

	var portrait_vbox := VBoxContainer.new()
	portrait_vbox.add_theme_constant_override("separation", 2)
	portrait_card.add_child(portrait_vbox)

	_season_portrait = SeasonTidePortrait.new()
	_season_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_season_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_season_portrait.custom_minimum_size = Vector2(82, 96)
	portrait_vbox.add_child(_season_portrait)

	var tide_row := HBoxContainer.new()
	tide_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tide_row.add_theme_constant_override("separation", 3)
	portrait_vbox.add_child(tide_row)

	_season_icon = TextureRect.new()
	_season_icon.custom_minimum_size = Vector2(14, 14)
	_season_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_season_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_season_icon.texture = EvoStardewStyle.get_pixel_icon("season_wet")
	tide_row.add_child(_season_icon)

	_sea_level_label = Label.new()
	_sea_level_label.text = "🌊 12%"
	_sea_level_label.add_theme_font_size_override("font_size", 11)
	_sea_level_label.add_theme_color_override("font_color", EvoStardewStyle.COLOR_GOLD_TEXT)
	tide_row.add_child(_sea_level_label)

	# Right: Generation Dial, Time Controls, Mana Bar & System 1 Models Badge
	var dial_panel := PanelContainer.new()
	dial_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dial_panel.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_panel(6, false))
	clock_hbox.add_child(dial_panel)

	var dial_vbox := VBoxContainer.new()
	dial_vbox.add_theme_constant_override("separation", 4)
	dial_panel.add_child(dial_vbox)

	# Row 1: Generation & Season Banner
	var gen_row := HBoxContainer.new()
	gen_row.add_theme_constant_override("separation", 6)
	dial_vbox.add_child(gen_row)

	_gen_label = Label.new()
	_gen_label.text = "📅 Gen 0"
	_gen_label.add_theme_font_size_override("font_size", 13)
	_gen_label.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	gen_row.add_child(_gen_label)

	_season_label = Label.new()
	_season_label.text = "☀️ Primavera Cálida"
	_season_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_season_label.clip_text = true
	_season_label.add_theme_font_size_override("font_size", 11)
	_season_label.add_theme_color_override("font_color", EvoStardewStyle.COLOR_SEPIA)
	gen_row.add_child(_season_label)

	# Row 2: Tactile Wood/Gold Time Controls
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 4)
	dial_vbox.add_child(time_row)

	_play_btn = Button.new()
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.pressed.connect(_on_play_pressed)
	time_row.add_child(_play_btn)

	_step_btn = Button.new()
	_step_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_btn.pressed.connect(_on_step_pressed)
	time_row.add_child(_step_btn)

	_speed_btn = Button.new()
	_speed_btn.pressed.connect(_on_speed_pressed)
	time_row.add_child(_speed_btn)

	# Row 3: Selective Pressure / Mana Bar (Stardew Energy Bar)
	var mana_box := PanelContainer.new()
	mana_box.add_theme_stylebox_override("panel", EvoStardewStyle.make_badge_style(EvoStardewStyle.COLOR_WOOD_DARK, EvoStardewStyle.COLOR_GOLD_BEVEL))
	dial_vbox.add_child(mana_box)

	var mana_vbox := VBoxContainer.new()
	mana_vbox.add_theme_constant_override("separation", 2)
	mana_box.add_child(mana_vbox)

	_pressure_label = Label.new()
	_pressure_label.text = "⚡ 30 pts · +15/gen"
	_pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pressure_label.add_theme_color_override("font_color", EvoStardewStyle.COLOR_GOLD_TEXT)
	_pressure_label.add_theme_font_size_override("font_size", 11)
	mana_vbox.add_child(_pressure_label)

	_pressure_bar = ProgressBar.new()
	_pressure_bar.min_value = 0.0
	_pressure_bar.max_value = 100.0
	_pressure_bar.value = 30.0
	_pressure_bar.show_percentage = false
	_pressure_bar.custom_minimum_size = Vector2(0, 6)
	EvoStardewStyle.style_progress_bar(_pressure_bar, Color("#22c55e"))
	mana_vbox.add_child(_pressure_bar)

	# Row 4: System 1 Decision Models Badge Button (opens Settings/Camera/Models popup)
	_settings_btn = Button.new()
	_settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_btn.add_theme_font_size_override("font_size", 11)
	_settings_btn.pressed.connect(_on_settings_btn_pressed)
	dial_vbox.add_child(_settings_btn)


func _build_settings_popup() -> void:
	_settings_popup = PanelContainer.new()
	_settings_popup.visible = false
	_settings_popup.anchor_left = 1.0
	_settings_popup.anchor_right = 1.0
	_settings_popup.anchor_top = 0.0
	_settings_popup.anchor_bottom = 0.0
	_settings_popup.offset_left = -364
	_settings_popup.offset_right = -10
	_settings_popup.offset_top = 166
	_settings_popup.offset_bottom = 486
	_settings_popup.z_index = 30
	_settings_popup.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(8))
	add_child(_settings_popup)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_panel(8, false))
	_settings_popup.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	inner.add_child(vbox)

	# System 1 Ollama Models Diagnostic Card
	var diag_card := PanelContainer.new()
	diag_card.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_card(Color("#fbf2de"), EvoStardewStyle.COLOR_GOLD_BEVEL, 6))
	vbox.add_child(diag_card)

	var diag_vbox := VBoxContainer.new()
	diag_vbox.add_theme_constant_override("separation", 4)
	diag_card.add_child(diag_vbox)

	_models_diag_lbl = Label.new()
	_models_diag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_models_diag_lbl.add_theme_font_size_override("font_size", 11)
	_models_diag_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	diag_vbox.add_child(_models_diag_lbl)

	_live_models_check = CheckBox.new()
	_live_models_check.button_pressed = true
	_live_models_check.toggled.connect(_on_live_models_toggled)
	diag_vbox.add_child(_live_models_check)

	# Language Row
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 6)
	vbox.add_child(lang_row)

	var lang_lbl := Label.new()
	lang_lbl.text = "🌐 Idioma / Language:"
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_lbl)

	_lang_es_btn = Button.new()
	_lang_es_btn.text = "ES"
	_lang_es_btn.pressed.connect(_on_lang_selected.bind("es"))
	lang_row.add_child(_lang_es_btn)

	_lang_en_btn = Button.new()
	_lang_en_btn.text = "EN"
	_lang_en_btn.pressed.connect(_on_lang_selected.bind("en"))
	lang_row.add_child(_lang_en_btn)

	_auto_pause_check = CheckBox.new()
	_auto_pause_check.toggled.connect(_on_settings_toggled)
	vbox.add_child(_auto_pause_check)

	_unlimited_pressure_check = CheckBox.new()
	_unlimited_pressure_check.toggled.connect(_on_settings_toggled)
	vbox.add_child(_unlimited_pressure_check)

	_free_sandbox_check = CheckBox.new()
	_free_sandbox_check.toggled.connect(_on_settings_toggled)
	vbox.add_child(_free_sandbox_check)

	_cam_lbl = Label.new()
	_cam_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	vbox.add_child(_cam_lbl)

	var cam_flow := HFlowContainer.new()
	cam_flow.add_theme_constant_override("h_separation", 5)
	cam_flow.add_theme_constant_override("v_separation", 5)
	vbox.add_child(cam_flow)

	for deg in [32.0, 48.0, 68.0]:
		var b := Button.new()
		b.text = "%d°" % int(deg)
		b.pressed.connect(_on_cam_preset_pressed.bind("pitch", deg))
		cam_flow.add_child(b)

	var rot_q_btn := Button.new()
	rot_q_btn.text = "↺ Q (-18°)"
	rot_q_btn.pressed.connect(_on_cam_preset_pressed.bind("yaw", -18.0))
	cam_flow.add_child(rot_q_btn)

	var rot_e_btn := Button.new()
	rot_e_btn.text = "↻ E (+18°)"
	rot_e_btn.pressed.connect(_on_cam_preset_pressed.bind("yaw", 18.0))
	cam_flow.add_child(rot_e_btn)

	var reset_cam_btn := Button.new()
	reset_cam_btn.text = "🎯 Reset"
	reset_cam_btn.pressed.connect(_on_cam_preset_pressed.bind("reset", 0.0))
	cam_flow.add_child(reset_cam_btn)


func _build_bottom_stardew_hotbar() -> void:
	# 1. Floating Sub-Options Bar (appears above the hotbar when Sea Level / extra biomes active)
	_sub_options_panel = PanelContainer.new()
	_sub_options_panel.visible = false
	_sub_options_panel.anchor_left = 0.5
	_sub_options_panel.anchor_right = 0.5
	_sub_options_panel.anchor_top = 1.0
	_sub_options_panel.anchor_bottom = 1.0
	_sub_options_panel.offset_left = -280
	_sub_options_panel.offset_right = 280
	_sub_options_panel.offset_top = -140
	_sub_options_panel.offset_bottom = -104
	_sub_options_panel.z_index = 16
	_sub_options_panel.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(5))
	add_child(_sub_options_panel)

	_sub_options_flow = HFlowContainer.new()
	_sub_options_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_sub_options_flow.add_theme_constant_override("h_separation", 6)
	_sub_options_flow.add_theme_constant_override("v_separation", 4)
	_sub_options_panel.add_child(_sub_options_flow)

	# 2. Floating Golden Equipped Tool Plaque right above the Hotbar
	_equipped_tool_banner = PanelContainer.new()
	_equipped_tool_banner.anchor_left = 0.5
	_equipped_tool_banner.anchor_right = 0.5
	_equipped_tool_banner.anchor_top = 1.0
	_equipped_tool_banner.anchor_bottom = 1.0
	_equipped_tool_banner.offset_left = -240
	_equipped_tool_banner.offset_right = 240
	_equipped_tool_banner.offset_top = -100
	_equipped_tool_banner.offset_bottom = -74
	_equipped_tool_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eq_style := EvoStardewStyle.make_parchment_card(Color("#fef3c7"), EvoStardewStyle.COLOR_GOLD_BRIGHT, 4)
	_equipped_tool_banner.add_theme_stylebox_override("panel", eq_style)
	add_child(_equipped_tool_banner)

	_equipped_tool_lbl = Label.new()
	_equipped_tool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipped_tool_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_equipped_tool_lbl.add_theme_font_size_override("font_size", 12)
	_equipped_tool_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	_equipped_tool_banner.add_child(_equipped_tool_lbl)

	# 3. Iconic 10-Slot Stardew Valley Inventory Hotbar + Brush Radius Switcher
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
	hotbar_frame.add_theme_stylebox_override("panel", EvoStardewStyle.make_hotbar_frame_box(8, 5))
	add_child(hotbar_frame)

	var hb_row := HBoxContainer.new()
	hb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_row.add_theme_constant_override("separation", 4)
	hotbar_frame.add_child(hb_row)

	_hotbar_slot_buttons.clear()
	for slot_def in HOTBAR_SLOTS_DEF:
		var s_idx: int = int(slot_def["slot"])
		var key_str: String = str(slot_def["key"])
		var icon_key: String = str(slot_def["icon"])
		var cost_val: int = int(slot_def["cost"])
		var tool_id: String = str(slot_def["tool"])

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(54, 54)
		slot_btn.pressed.connect(_on_hotbar_slot_pressed.bind(s_idx))
		hb_row.add_child(slot_btn)
		_hotbar_slot_buttons.append(slot_btn)

		if not _tool_buttons.has(tool_id):
			_tool_buttons[tool_id] = slot_btn

		# Slot internal overlay: Key number (top-left), Pixel Icon (center), Cost (bottom-right)
		var slot_overlay := Control.new()
		slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(slot_overlay)

		var key_lbl := Label.new()
		key_lbl.text = key_str
		key_lbl.position = Vector2(4, 1)
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_SEPIA)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_overlay.add_child(key_lbl)

		var icon_rect := TextureRect.new()
		icon_rect.texture = EvoStardewStyle.get_pixel_icon(icon_key)
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
			cost_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_overlay.add_child(cost_lbl)

	# Separator & Brush Size Switcher inside the right end of the hotbar
	var v_sep := VSeparator.new()
	hb_row.add_child(v_sep)

	var brush_vbox := VBoxContainer.new()
	brush_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	brush_vbox.add_theme_constant_override("separation", 3)
	hb_row.add_child(brush_vbox)

	_radius_1_btn = Button.new()
	_radius_1_btn.custom_minimum_size = Vector2(58, 25)
	_radius_1_btn.add_theme_font_size_override("font_size", 11)
	_radius_1_btn.pressed.connect(_on_brush_radius_pressed.bind(1))
	brush_vbox.add_child(_radius_1_btn)

	_radius_2_btn = Button.new()
	_radius_2_btn.custom_minimum_size = Vector2(58, 25)
	_radius_2_btn.add_theme_font_size_override("font_size", 11)
	_radius_2_btn.pressed.connect(_on_brush_radius_pressed.bind(2))
	brush_vbox.add_child(_radius_2_btn)


func _build_legend_panel() -> void:
	_legend_panel = PanelContainer.new()
	_legend_panel.visible = false
	_legend_panel.anchor_left = 0.0
	_legend_panel.anchor_right = 0.0
	_legend_panel.anchor_top = 0.0
	_legend_panel.anchor_bottom = 0.0
	_legend_panel.offset_left = 382
	_legend_panel.offset_right = 656
	_legend_panel.offset_top = 10
	_legend_panel.offset_bottom = 290
	_legend_panel.z_index = 22
	_legend_panel.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(7))
	add_child(_legend_panel)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_panel(8, false))
	_legend_panel.add_child(inner)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)

	_legend_vbox = VBoxContainer.new()
	_legend_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legend_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_legend_vbox)


func _build_right_scroll_inspector() -> void:
	_inspector_frame = PanelContainer.new()
	_inspector_frame.anchor_left = 1.0
	_inspector_frame.anchor_right = 1.0
	_inspector_frame.anchor_top = 0.0
	_inspector_frame.anchor_bottom = 0.0
	_inspector_frame.offset_left = -356
	_inspector_frame.offset_right = -10
	_inspector_frame.offset_top = 162
	_inspector_frame.offset_bottom = 840
	_inspector_frame.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(7))
	add_child(_inspector_frame)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 5)
	_inspector_frame.add_child(outer_vbox)

	# Wooden Scroll Roller Header (Always visible even when minimized)
	var header_box := PanelContainer.new()
	header_box.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_header_box(8, 5))
	outer_vbox.add_child(header_box)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 3)
	header_box.add_child(header_vbox)

	var h_top := HBoxContainer.new()
	h_top.add_theme_constant_override("separation", 6)
	header_vbox.add_child(h_top)

	_inspector_header_swatch = ColorRect.new()
	_inspector_header_swatch.custom_minimum_size = Vector2(14, 14)
	_inspector_header_swatch.color = Color("#E07A5F")
	h_top.add_child(_inspector_header_swatch)

	_inspector_header_title = Label.new()
	_inspector_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_header_title.clip_text = true
	_inspector_header_title.add_theme_font_size_override("font_size", 13)
	_inspector_header_title.add_theme_color_override("font_color", EvoStardewStyle.COLOR_GOLD_TEXT)
	h_top.add_child(_inspector_header_title)

	_inspector_header_hl_btn = Button.new()
	_inspector_header_hl_btn.add_theme_font_size_override("font_size", 10)
	_inspector_header_hl_btn.pressed.connect(_on_header_highlight_pressed)
	h_top.add_child(_inspector_header_hl_btn)

	_inspector_minimize_btn = Button.new()
	_inspector_minimize_btn.text = "▾"
	_inspector_minimize_btn.custom_minimum_size = Vector2(26, 22)
	_inspector_minimize_btn.pressed.connect(_on_toggle_inspector_minimize)
	h_top.add_child(_inspector_minimize_btn)

	# System 1 Decision Model Badge inside Scroll Header
	var model_badge_panel := PanelContainer.new()
	model_badge_panel.add_theme_stylebox_override("panel", EvoStardewStyle.make_badge_style(Color("#271306"), EvoStardewStyle.COLOR_GOLD_BEVEL))
	header_vbox.add_child(model_badge_panel)

	_inspector_model_badge_lbl = Label.new()
	_inspector_model_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspector_model_badge_lbl.add_theme_font_size_override("font_size", 11)
	_inspector_model_badge_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_CREAM_TEXT)
	model_badge_panel.add_child(_inspector_model_badge_lbl)

	# Collapsible Scroll Body (3 Tabs + Cream Parchment Content)
	_inspector_body_vbox = VBoxContainer.new()
	_inspector_body_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_body_vbox.add_theme_constant_override("separation", 5)
	outer_vbox.add_child(_inspector_body_vbox)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	_inspector_body_vbox.add_child(tabs_row)

	_tab_deme_btn = Button.new()
	_tab_deme_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_deme_btn.add_theme_font_size_override("font_size", 11)
	_tab_deme_btn.pressed.connect(_on_inspector_tab_pressed.bind("deme"))
	tabs_row.add_child(_tab_deme_btn)

	_tab_traits_btn = Button.new()
	_tab_traits_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_traits_btn.add_theme_font_size_override("font_size", 11)
	_tab_traits_btn.pressed.connect(_on_inspector_tab_pressed.bind("traits"))
	tabs_row.add_child(_tab_traits_btn)

	_tab_habitat_btn = Button.new()
	_tab_habitat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_habitat_btn.add_theme_font_size_override("font_size", 11)
	_tab_habitat_btn.pressed.connect(_on_inspector_tab_pressed.bind("habitat"))
	tabs_row.add_child(_tab_habitat_btn)

	var parchment_body := PanelContainer.new()
	parchment_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parchment_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parchment_body.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_panel(8, false))
	_inspector_body_vbox.add_child(parchment_body)

	_inspector_scroll = ScrollContainer.new()
	_inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parchment_body.add_child(_inspector_scroll)

	var sheets_holder := VBoxContainer.new()
	sheets_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheets_holder.add_theme_constant_override("separation", 6)
	_inspector_scroll.add_child(sheets_holder)

	_deme_sheet_vbox = VBoxContainer.new()
	_deme_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deme_sheet_vbox.add_theme_constant_override("separation", 6)
	sheets_holder.add_child(_deme_sheet_vbox)

	_traits_sheet_vbox = VBoxContainer.new()
	_traits_sheet_vbox.visible = false
	_traits_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_traits_sheet_vbox.add_theme_constant_override("separation", 6)
	sheets_holder.add_child(_traits_sheet_vbox)

	_hex_sheet_vbox = VBoxContainer.new()
	_hex_sheet_vbox.visible = false
	_hex_sheet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hex_sheet_vbox.add_theme_constant_override("separation", 6)
	sheets_holder.add_child(_hex_sheet_vbox)


func _build_banners_and_toasts() -> void:
	# Top-Center Golden Parchment Milestone / Outcome Banner
	_milestone_banner = PanelContainer.new()
	_milestone_banner.visible = false
	_milestone_banner.anchor_left = 0.5
	_milestone_banner.anchor_right = 0.5
	_milestone_banner.anchor_top = 0.0
	_milestone_banner.anchor_bottom = 0.0
	_milestone_banner.offset_left = -220
	_milestone_banner.offset_right = 220
	_milestone_banner.offset_top = 12
	_milestone_banner.offset_bottom = 92
	_milestone_banner.z_index = 25
	var banner_style := EvoStardewStyle.make_parchment_card(Color("#fef3c7"), EvoStardewStyle.COLOR_GOLD_BRIGHT, 8)
	banner_style.border_width_left = 4
	banner_style.border_width_right = 4
	banner_style.border_width_top = 3
	banner_style.border_width_bottom = 3
	_milestone_banner.add_theme_stylebox_override("panel", banner_style)
	add_child(_milestone_banner)

	var b_hbox := HBoxContainer.new()
	b_hbox.add_theme_constant_override("separation", 8)
	_milestone_banner.add_child(b_hbox)

	var b_vbox := VBoxContainer.new()
	b_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_vbox.add_theme_constant_override("separation", 3)
	b_hbox.add_child(b_vbox)

	_banner_title_lbl = Label.new()
	_banner_title_lbl.add_theme_font_size_override("font_size", 14)
	_banner_title_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	_banner_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_vbox.add_child(_banner_title_lbl)

	_banner_summary_lbl = Label.new()
	_banner_summary_lbl.add_theme_font_size_override("font_size", 11)
	_banner_summary_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_SEPIA)
	_banner_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_vbox.add_child(_banner_summary_lbl)

	var close_banner_btn := Button.new()
	close_banner_btn.text = "✕"
	close_banner_btn.pressed.connect(func() -> void: _milestone_banner.visible = false)
	b_hbox.add_child(close_banner_btn)

	# Bottom-Left Chronicle Toast Stack (Stardew item pickup notification style)
	_toast_vbox = VBoxContainer.new()
	_toast_vbox.anchor_left = 0.0
	_toast_vbox.anchor_right = 0.0
	_toast_vbox.anchor_top = 1.0
	_toast_vbox.anchor_bottom = 1.0
	_toast_vbox.offset_left = 10
	_toast_vbox.offset_right = 310
	_toast_vbox.offset_top = -310
	_toast_vbox.offset_bottom = -96
	_toast_vbox.alignment = BoxContainer.ALIGNMENT_END
	_toast_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_vbox.add_theme_constant_override("separation", 5)
	add_child(_toast_vbox)

	# Compact Collapsible First-Steps Quest Note (Bottom-Left)
	_first_steps_panel = PanelContainer.new()
	_first_steps_panel.anchor_left = 0.0
	_first_steps_panel.anchor_right = 0.0
	_first_steps_panel.anchor_top = 1.0
	_first_steps_panel.anchor_bottom = 1.0
	_first_steps_panel.offset_left = 10
	_first_steps_panel.offset_right = 278
	_first_steps_panel.offset_top = -88
	_first_steps_panel.offset_bottom = -8
	_first_steps_panel.add_theme_stylebox_override("panel", EvoStardewStyle.make_wood_frame_box(5))
	add_child(_first_steps_panel)

	var fs_hbox := HBoxContainer.new()
	fs_hbox.add_theme_constant_override("separation", 6)
	_first_steps_panel.add_child(fs_hbox)

	var fs_vbox := VBoxContainer.new()
	fs_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_vbox.add_theme_constant_override("separation", 1)
	fs_hbox.add_child(fs_vbox)

	_step1_lbl = Label.new()
	_step1_lbl.add_theme_font_size_override("font_size", 10)
	fs_vbox.add_child(_step1_lbl)

	_step2_lbl = Label.new()
	_step2_lbl.add_theme_font_size_override("font_size", 10)
	fs_vbox.add_child(_step2_lbl)

	_step3_lbl = Label.new()
	_step3_lbl.add_theme_font_size_override("font_size", 10)
	fs_vbox.add_child(_step3_lbl)

	var hide_fs_btn := Button.new()
	hide_fs_btn.text = "✕"
	hide_fs_btn.custom_minimum_size = Vector2(22, 22)
	hide_fs_btn.pressed.connect(func() -> void: _first_steps_panel.visible = false)
	fs_hbox.add_child(hide_fs_btn)


func _build_modals() -> void:
	notebook_modal = EvoNotebookModal.new()
	notebook_modal.visible = false
	notebook_modal.z_index = 40
	notebook_modal.jump_to_hex_requested.connect(_on_modal_jump_to_hex)
	add_child(notebook_modal)

	tree_modal = EvoTreeModal.new()
	tree_modal.visible = false
	tree_modal.z_index = 40
	tree_modal.lineage_highlight_requested.connect(_on_lineage_highlight_from_modal)
	add_child(tree_modal)

	lab_modal = EvoLabModal.new()
	lab_modal.visible = false
	lab_modal.z_index = 40
	lab_modal.catalog_item_saved.connect(_on_lab_item_saved)
	lab_modal.inject_trait_requested.connect(_on_lab_inject_trait)
	add_child(lab_modal)


func setup(world_state: EvoTypes.WorldState, lang: String = "es") -> void:
	if _preset_option == null:
		_ready()
	_lang = lang
	set_world_state(world_state)
	_update_static_labels()
	refresh(world_state)


func set_world_state(world_state: EvoTypes.WorldState) -> void:
	_world_state = world_state
	if _milestone_banner != null:
		_milestone_banner.visible = false
	if _toast_vbox != null:
		for child in _toast_vbox.get_children():
			child.queue_free()
	if _world_state != null:
		_last_seen_chronicle_count = _world_state.chronicle.size()
		if _selected_deme_id == "" or not _world_state.demes.has(_selected_deme_id):
			if not _world_state.demes.is_empty():
				var first_id := str(_world_state.demes.keys()[0])
				_selected_deme_id = first_id
				var d: EvoTypes.Deme = _world_state.demes[first_id]
				_selected_hex_id = d.hex_id
		if not _world_state.cells.has(_selected_hex_id) and not _world_state.cells.is_empty():
			_selected_hex_id = str(_world_state.cells.keys()[0])
	refresh(_world_state)


func refresh(world_state: EvoTypes.WorldState = null) -> void:
	if world_state != null:
		_world_state = world_state
	if _world_state == null:
		return

	if _world_state.chronicle.size() > _last_seen_chronicle_count:
		for i in range(_last_seen_chronicle_count, _world_state.chronicle.size()):
			var entry: EvoTypes.ChronicleEntry = _world_state.chronicle[i]
			push_chronicle_toast(entry)
			if entry.event_type in ["baldwin_trait", "cultural_innovation", "allopatric_speciation"]:
				show_milestone_banner(entry.title, entry.causal_explanation, false)
		_last_seen_chronicle_count = _world_state.chronicle.size()
	elif _world_state.chronicle.size() < _last_seen_chronicle_count:
		_last_seen_chronicle_count = _world_state.chronicle.size()

	if _world_state.macro_outcome_type != "":
		show_milestone_banner(_world_state.macro_outcome_title, _world_state.macro_outcome_summary, true)

	_update_top_bar_state()
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()
	_update_first_steps_labels()
	_update_hotbar_visuals()

	if notebook_modal != null and notebook_modal.visible:
		notebook_modal.refresh(_world_state)
	if tree_modal != null and tree_modal.visible:
		tree_modal.refresh(_world_state)
	if lab_modal != null and lab_modal.visible:
		lab_modal.refresh(_world_state, _selected_deme_id)


func _rebuild_active_inspector_sheet() -> void:
	if _inspector_minimized:
		return
	if _inspector_tab == "habitat":
		_rebuild_hex_sheet()
	else:
		_rebuild_deme_sheet()


func select_hex(hex_id: String) -> void:
	_selected_hex_id = hex_id
	if _world_state != null and _world_state.cells.has(hex_id):
		var cell: EvoTypes.HexCell = _world_state.cells[hex_id]
		if not cell.deme_ids.is_empty():
			if not cell.deme_ids.has(_selected_deme_id):
				_selected_deme_id = cell.deme_ids[0]
			_step_1_done = true
			if _inspector_tab == "habitat":
				_set_inspector_tab("deme")
		else:
			_set_inspector_tab("habitat")
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()
	_update_first_steps_labels()


func select_deme(deme_id: String) -> void:
	if _world_state == null or not _world_state.demes.has(deme_id):
		return
	_selected_deme_id = deme_id
	var d: EvoTypes.Deme = _world_state.demes[deme_id]
	_selected_hex_id = d.hex_id
	_step_1_done = true
	if _inspector_minimized:
		_on_toggle_inspector_minimize()
	if _inspector_tab == "habitat":
		_set_inspector_tab("deme")
	_rebuild_villages_list()
	_rebuild_active_inspector_sheet()
	_update_first_steps_labels()


func set_playing_state(is_playing: bool) -> void:
	_is_playing = is_playing
	_update_static_labels()


func set_language(lang: String) -> void:
	_lang = lang
	_update_static_labels()
	_rebuild_sub_tool_options()
	_rebuild_legend_content()
	if notebook_modal != null:
		notebook_modal.set_language(_lang)
	if tree_modal != null:
		tree_modal.set_language(_lang)
	if lab_modal != null:
		lab_modal.set_language(_lang)
	refresh(_world_state)


func mark_tool_used() -> void:
	_step_2_done = true
	_update_first_steps_labels()


func mark_generation_advanced() -> void:
	_step_3_done = true
	_update_first_steps_labels()


func get_active_tool() -> String:
	return _active_tool


func get_active_sub_mode() -> String:
	return _active_sub_mode


func get_brush_radius() -> int:
	return _brush_radius


func get_active_lens() -> String:
	return _active_lens


func open_notebook_modal() -> void:
	notebook_modal.open_modal(_world_state, _lang)


func open_tree_modal(lineage_id: String = "") -> void:
	var target_lin := lineage_id
	if target_lin == "" and _world_state != null and _world_state.demes.has(_selected_deme_id):
		var d: EvoTypes.Deme = _world_state.demes[_selected_deme_id]
		target_lin = d.lineage_id
	tree_modal.open_modal(_world_state, _lang, target_lin)


func open_lab_modal() -> void:
	lab_modal.open_modal(_world_state, _lang, _selected_deme_id)


func show_milestone_banner(title: String, summary: String, is_macro: bool = false) -> void:
	if _milestone_banner == null:
		return
	_banner_title_lbl.text = ("🏆 " if is_macro else "🌟 ") + title
	_banner_summary_lbl.text = summary
	_milestone_banner.visible = true


func push_chronicle_toast(entry: EvoTypes.ChronicleEntry) -> void:
	if _toast_vbox == null:
		return
	while _toast_vbox.get_child_count() >= 3:
		var oldest := _toast_vbox.get_child(0)
		_toast_vbox.remove_child(oldest)
		oldest.queue_free()

	var ev_color := EvoStardewStyle.get_event_type_color(entry.event_type)
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_meta("ttl", 5.5)
	var style := EvoStardewStyle.make_parchment_card(Color("#fbf2de"), ev_color, 6)
	style.border_width_left = 5
	toast.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	toast.add_child(vbox)

	var badge_lbl := Label.new()
	badge_lbl.text = "G%d · %s (%s)" % [entry.generation, EvoStardewStyle.get_event_type_label(entry.event_type, _lang), entry.hex_id]
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.add_theme_color_override("font_color", ev_color)
	vbox.add_child(badge_lbl)

	var title_lbl := Label.new()
	title_lbl.text = entry.title
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_INK)
	vbox.add_child(title_lbl)

	_toast_vbox.add_child(toast)


func _update_static_labels() -> void:
	if _preset_option == null:
		return

	var prev_sel := maxi(0, _preset_option.selected)
	_preset_option.clear()
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
		var lbl_str: String = preset_names_en[i] if _lang == "en" else preset_names_es[i]
		_preset_option.add_item(lbl_str, i)
		_preset_option.set_item_metadata(i, PRESET_LIST[i])
	if _world_state != null:
		var idx := PRESET_LIST.find(_world_state.preset_id)
		if idx >= 0:
			_preset_option.select(idx)
	elif prev_sel < _preset_option.item_count:
		_preset_option.select(prev_sel)

	_export_btn.text = "💾"
	_export_btn.tooltip_text = EvoStardewStyle.tr_text(_lang, "Exportar Mundo (JSON)", "Export World (JSON)")
	_import_btn.text = "📂"
	_import_btn.tooltip_text = EvoStardewStyle.tr_text(_lang, "Importar Mundo (JSON)", "Import World (JSON)")

	if _is_playing:
		_play_btn.text = EvoStardewStyle.tr_text(_lang, "⏸ Pausa", "⏸ Pause")
	else:
		_play_btn.text = EvoStardewStyle.tr_text(_lang, "▶ Play", "▶ Play")
	EvoStardewStyle.apply_button_active(_play_btn, _is_playing)

	_step_btn.text = EvoStardewStyle.tr_text(_lang, "⏭ +1", "⏭ +1")
	_speed_btn.text = "2x" if _is_fast else "1x"
	EvoStardewStyle.apply_button_active(_speed_btn, _is_fast)

	_notebook_btn.text = EvoStardewStyle.tr_text(_lang, "📖 Diario", "📖 Journal")
	_tree_btn.text = EvoStardewStyle.tr_text(_lang, "🌳 Linajes", "🌳 Lineages")
	_lab_btn.text = EvoStardewStyle.tr_text(_lang, "⚗️ Forja", "⚗️ Forge")
	_lens_cycle_btn.text = EvoStardewStyle.tr_text(_lang, "👁️ Lente", "👁️ Lens")

	EvoStardewStyle.apply_button_active(_lang_es_btn, _lang == "es")
	EvoStardewStyle.apply_button_active(_lang_en_btn, _lang == "en")

	_live_models_check.text = EvoStardewStyle.tr_text(
		_lang,
		"Modelos Ollama en Vivo (d3:4b / tev1:4b)",
		"Live Ollama Models (d3:4b / tev1:4b)"
	)
	_auto_pause_check.text = EvoStardewStyle.tr_text(_lang, "Auto-pausa en hitos", "Auto-pause on milestones")
	_unlimited_pressure_check.text = EvoStardewStyle.tr_text(_lang, "Energía Ilimitada", "Unlimited Energy")
	_free_sandbox_check.text = EvoStardewStyle.tr_text(_lang, "Sandbox Libre", "Free Sandbox")
	_cam_lbl.text = EvoStardewStyle.tr_text(_lang, "🎥 Ángulo y Rotación de Cámara:", "🎥 Camera Angle & Orbit:")

	_radius_1_btn.text = "◯ 1x"
	_radius_1_btn.tooltip_text = EvoStardewStyle.tr_text(_lang, "Pincel de 1 hexágono", "1-hex brush")
	_radius_2_btn.text = "◎ 7x"
	_radius_2_btn.tooltip_text = EvoStardewStyle.tr_text(_lang, "Pincel de 7 hexágonos", "7-hex brush")
	EvoStardewStyle.apply_button_active(_radius_1_btn, _brush_radius == 1)
	EvoStardewStyle.apply_button_active(_radius_2_btn, _brush_radius == 2)

	(_lens_buttons["biome"] as Button).text = EvoStardewStyle.tr_text(_lang, "🌿 Bioma", "🌿 Biome")
	(_lens_buttons["food"] as Button).text = EvoStardewStyle.tr_text(_lang, "🌾 Alimento", "🌾 Food")
	(_lens_buttons["health"] as Button).text = EvoStardewStyle.tr_text(_lang, "💚 Salud", "💚 Health")
	for l_id in _lens_buttons.keys():
		EvoStardewStyle.apply_button_active(_lens_buttons[l_id] as Button, _active_lens == l_id)

	_legend_toggle_btn.text = EvoStardewStyle.tr_text(_lang, "🗺️ Leyenda", "🗺️ Legend")
	EvoStardewStyle.apply_button_active(_legend_toggle_btn, _legend_panel.visible)

	_tab_deme_btn.text = EvoStardewStyle.tr_text(_lang, "🧠 Aldea", "🧠 Village")
	_tab_traits_btn.text = EvoStardewStyle.tr_text(_lang, "🧬 Rasgos", "🧬 Traits")
	_tab_habitat_btn.text = EvoStardewStyle.tr_text(_lang, "🌿 Hábitat", "🌿 Habitat")
	EvoStardewStyle.apply_button_active(_tab_deme_btn, _inspector_tab == "deme")
	EvoStardewStyle.apply_button_active(_tab_traits_btn, _inspector_tab == "traits")
	EvoStardewStyle.apply_button_active(_tab_habitat_btn, _inspector_tab == "habitat")

	_villages_title_lbl.text = EvoStardewStyle.tr_text(_lang, "🏘️ Aldeas Vivas del Valle", "🏘️ Living Valley Villages")
	_update_hotbar_visuals()
	_update_first_steps_labels()


func _update_top_bar_state() -> void:
	if _world_state == null:
		return
	var year_num := int(_world_state.generation / 2) + 1
	_gen_label.text = EvoStardewStyle.tr_text(
		_lang,
		"📅 Año %d · Gen %d" % [year_num, _world_state.generation],
		"📅 Yr %d · Gen %d" % [year_num, _world_state.generation]
	)
	var is_wet := (_world_state.season == "wet_warm")
	if is_wet:
		_season_label.text = EvoStardewStyle.tr_text(_lang, "☀️ Primavera Cálida", "☀️ Warm Spring")
		_season_icon.texture = EvoStardewStyle.get_pixel_icon("season_wet")
	else:
		_season_label.text = EvoStardewStyle.tr_text(_lang, "❄️ Invierno Seco", "❄️ Dry Winter")
		_season_icon.texture = EvoStardewStyle.get_pixel_icon("season_dry")

	var sea_pct := int(round(_world_state.sea_level * 100.0))
	_sea_level_label.text = "🌊 %d%%" % sea_pct
	_season_portrait.set_state(is_wet, _world_state.sea_level)

	if _world_state.unlimited_pressure_mode:
		_pressure_label.text = EvoStardewStyle.tr_text(_lang, "⚡ ∞ Maná Ilimitado", "⚡ ∞ Unlimited Mana")
		_pressure_bar.value = 100.0
	else:
		_pressure_label.text = "⚡ %d pts · +%d/gen" % [_world_state.selective_pressure_points, _world_state.selective_pressure_regen_per_turn]
		_pressure_bar.value = clampf(float(_world_state.selective_pressure_points), 0.0, 100.0)

	# Compute System 1 Models summary (d3:4b vs tev1:4b)
	var d3_count := 0
	var tev1_count := 0
	var avg_conf := 0.0
	for d_key in _world_state.demes.keys():
		var d: EvoTypes.Deme = _world_state.demes[d_key]
		if "tev1" in d.decision_model_tag:
			tev1_count += 1
		else:
			d3_count += 1
		avg_conf += d.last_confidence
	if not _world_state.demes.is_empty():
		avg_conf /= float(_world_state.demes.size())

	var mode_tag := "ON" if _world_state.use_live_decision_models else "HEUR"
	_settings_btn.text = "🧠 d3:4b · tev1:4b [%s] ⚙️" % mode_tag
	_models_diag_lbl.text = EvoStardewStyle.tr_text(
		_lang,
		"🧠 Motores Cognitivos Sistema 1:\n• d3:4b (Táctico/Instinto): %d aldeas\n• tev1:4b (Ecológico/Estratégico): %d aldeas\n• Confianza media: %d%%" % [d3_count, tev1_count, int(round(avg_conf * 100.0))],
		"🧠 System 1 Cognitive Engines:\n• d3:4b (Tactical/Instinct): %d villages\n• tev1:4b (Ecological/Strategic): %d villages\n• Avg confidence: %d%%" % [d3_count, tev1_count, int(round(avg_conf * 100.0))]
	)

	_live_models_check.set_pressed_no_signal(_world_state.use_live_decision_models)
	_auto_pause_check.set_pressed_no_signal(_world_state.auto_pause_on_milestone)
	_unlimited_pressure_check.set_pressed_no_signal(_world_state.unlimited_pressure_mode)
	_free_sandbox_check.set_pressed_no_signal(_world_state.free_sandbox_mode)


func _get_slot_title_and_desc(slot_idx: int) -> Dictionary:
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
	var arr := titles_en if _lang == "en" else titles_es
	var pair: Array = arr[clampi(slot_idx, 0, 9)]
	return {"title": str(pair[0]), "desc": str(pair[1])}


func _get_active_hotbar_slot_index() -> int:
	if _active_tool == "inspect":
		return 0
	if _active_tool == "set_biome":
		match _active_sub_mode:
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
	if _active_tool == "adjust_altitude":
		return 5 if _active_sub_mode == "raise" else 6
	if _active_tool == "adjust_carrying_capacity":
		return 7 if _active_sub_mode == "enrich" else 8
	if _active_tool == "sea_level":
		return 9
	return 0


func _update_hotbar_visuals() -> void:
	if _hotbar_slot_buttons.is_empty():
		return
	var visual_key := "%s|%s|%s" % [_active_tool, _active_sub_mode, _lang]
	if visual_key == _last_hotbar_visual_key:
		return
	_last_hotbar_visual_key = visual_key
	var active_idx := _get_active_hotbar_slot_index()
	for i in range(_hotbar_slot_buttons.size()):
		var btn := _hotbar_slot_buttons[i]
		var info := _get_slot_title_and_desc(i)
		btn.tooltip_text = "[%s] %s\n%s" % [str(HOTBAR_SLOTS_DEF[i]["key"]), info["title"], info["desc"]]
		EvoStardewStyle.apply_hotbar_slot_style(btn, i == active_idx)

	var cur_info := _get_slot_title_and_desc(active_idx)
	if _active_tool == "set_biome" and _active_sub_mode in ["coastal_shallows", "ocean", "high_mountain"]:
		var b_lbl := EvoStardewStyle.get_biome_label(_active_sub_mode, _lang)
		_equipped_tool_lbl.text = "🐚 %s — %s (⚡10)" % [b_lbl, EvoStardewStyle.tr_text(_lang, "Moldear bioma costero/cumbre", "Shape coastal/peak biome")]
	else:
		_equipped_tool_lbl.text = "%s — %s" % [cur_info["title"], cur_info["desc"]]


func _rebuild_sub_tool_options() -> void:
	if _sub_options_flow == null:
		return
	for child in _sub_options_flow.get_children():
		child.queue_free()

	var show_tidal_bar := (_active_tool == "sea_level") or (_active_tool == "set_biome" and _active_sub_mode in ["coastal_shallows", "ocean", "high_mountain"])
	if not show_tidal_bar:
		_sub_options_panel.visible = false
		return

	_sub_options_panel.visible = true

	var plus_sea := Button.new()
	plus_sea.text = EvoStardewStyle.tr_text(_lang, "🌊 +5% Mar (⚡25)", "🌊 +5% Sea (⚡25)")
	plus_sea.pressed.connect(_on_sea_level_btn_pressed.bind(0.05))
	_sub_options_flow.add_child(plus_sea)

	var minus_sea := Button.new()
	minus_sea.text = EvoStardewStyle.tr_text(_lang, "🌊 -5% Mar (⚡25)", "🌊 -5% Sea (⚡25)")
	minus_sea.pressed.connect(_on_sea_level_btn_pressed.bind(-0.05))
	_sub_options_flow.add_child(minus_sea)

	for extra_b in ["coastal_shallows", "ocean", "high_mountain"]:
		var b_btn := Button.new()
		b_btn.text = EvoStardewStyle.get_biome_label(extra_b, _lang)
		b_btn.icon = EvoStardewStyle.get_pixel_icon(extra_b)
		EvoStardewStyle.apply_button_active(b_btn, _active_tool == "set_biome" and _active_sub_mode == extra_b)
		b_btn.pressed.connect(func() -> void:
			_active_tool = "set_biome"
			_on_sub_mode_selected(extra_b)
			_update_hotbar_visuals()
		)
		_sub_options_flow.add_child(b_btn)


func _rebuild_legend_content() -> void:
	if _legend_vbox == null:
		return
	for child in _legend_vbox.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = EvoStardewStyle.tr_text(_lang, "🗺️ Leyenda del Valle", "🗺️ Valley Legend")
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	_legend_vbox.add_child(title)

	for b_id in EvoTypes.BIOMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_legend_vbox.add_child(row)

		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(12, 12)
		sw.color = EvoStardewStyle.get_biome_color(b_id)
		row.add_child(sw)

		var lbl := Label.new()
		lbl.text = EvoStardewStyle.get_biome_label(b_id, _lang)
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = EvoStardewStyle.tr_text(
		_lang,
		"Aldeas: I Campamento · II Caserío · III Aldea · IV Poblado\nCaminos: 🛣️ Cooperación · ⚔️ Disputa · 🧭 Migración",
		"Villages: I Camp · II Hamlet · III Village · IV Settlement\nPaths: 🛣️ Cooperation · ⚔️ Dispute · 🧭 Migration"
	)
	tier_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_SEPIA)
	_legend_vbox.add_child(tier_lbl)


func _rebuild_villages_list() -> void:
	if _villages_list_vbox == null:
		return

	if _world_state == null or _world_state.demes.is_empty():
		for btn in _village_buttons_pool:
			btn.visible = false
		if _empty_villages_lbl == null:
			_empty_villages_lbl = Label.new()
			_empty_villages_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_RED_DANGER)
			_empty_villages_lbl.add_theme_font_size_override("font_size", 11)
			_villages_list_vbox.add_child(_empty_villages_lbl)
		_empty_villages_lbl.text = EvoStardewStyle.tr_text(_lang, "Sin aldeas vivas.", "No living villages.")
		_empty_villages_lbl.visible = true
		return

	if _empty_villages_lbl != null:
		_empty_villages_lbl.visible = false

	var deme_list: Array[EvoTypes.Deme] = []
	for d_id in _world_state.demes.keys():
		deme_list.append(_world_state.demes[d_id])
	deme_list.sort_custom(func(a: EvoTypes.Deme, b: EvoTypes.Deme) -> bool: return a.population > b.population)

	_villages_title_lbl.text = EvoStardewStyle.tr_text(
		_lang,
		"🏘️ Aldeas Vivas (%d)" % deme_list.size(),
		"🏘️ Living Villages (%d)" % deme_list.size()
	)

	while _village_buttons_pool.size() < deme_list.size():
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_pooled_village_btn_pressed.bind(btn))
		_villages_list_vbox.add_child(btn)
		_village_buttons_pool.append(btn)

	for i in range(_village_buttons_pool.size()):
		var btn := _village_buttons_pool[i]
		if i >= deme_list.size():
			btn.visible = false
			continue
		var d := deme_list[i]
		var status_key := d.get_vital_status()
		var heart := EvoStardewStyle.get_vital_status_heart(status_key)
		var short_model := "tev1" if "tev1" in d.decision_model_tag else "d3"
		var short_name := d.name
		if short_name.length() > 14:
			short_name = short_name.substr(0, 13) + "…"

		btn.visible = true
		btn.text = "%s %s · %s·%d [🧠%s]" % [heart, short_name, d.get_village_roman(), d.population, short_model]
		btn.tooltip_text = "%s (%s)\n%s · %d hab · 🧠 %s" % [
			d.name,
			d.hex_id,
			EvoStardewStyle.get_village_tier_label(d.population, _lang),
			d.population,
			d.decision_model_tag
		]
		btn.set_meta("deme_id", d.id)
		btn.set_meta("hex_id", d.hex_id)
		var is_active := d.id == _selected_deme_id
		if not btn.has_meta("is_active") or bool(btn.get_meta("is_active")) != is_active:
			btn.set_meta("is_active", is_active)
			EvoStardewStyle.apply_button_active(btn, is_active)


func _on_pooled_village_btn_pressed(btn: Button) -> void:
	var deme_id := str(btn.get_meta("deme_id", ""))
	var hex_id := str(btn.get_meta("hex_id", ""))
	if deme_id != "":
		_on_village_list_item_pressed(deme_id, hex_id)


func _rebuild_deme_sheet() -> void:
	if _deme_sheet_vbox == null or _traits_sheet_vbox == null:
		return
	for child in _deme_sheet_vbox.get_children():
		child.queue_free()
	for child in _traits_sheet_vbox.get_children():
		child.queue_free()

	if _world_state == null or _selected_deme_id == "" or not _world_state.demes.has(_selected_deme_id):
		_inspector_header_title.text = EvoStardewStyle.tr_text(_lang, "Hex (%s)" % _selected_hex_id, "Hex (%s)" % _selected_hex_id)
		_inspector_model_badge_lbl.text = EvoStardewStyle.tr_text(_lang, "🌿 Sin aldea seleccionada", "🌿 No village selected")
		_inspector_header_hl_btn.visible = false
		var empty_lbl := Label.new()
		empty_lbl.text = EvoStardewStyle.tr_text(
			_lang,
			"Haz clic en un medallón de aldea o en el mapa para abrir su pergamino.",
			"Click a village medallion or on the map to open its scroll."
		)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_SEPIA)
		_deme_sheet_vbox.add_child(empty_lbl)
		return

	var d: EvoTypes.Deme = _world_state.demes[_selected_deme_id]
	var lin_name := d.lineage_id
	if _world_state.lineage_tree.has(d.lineage_id):
		lin_name = (_world_state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).name

	# Update Scroll Header
	_inspector_header_swatch.color = Color.from_string(d.color, Color("#E07A5F"))
	_inspector_header_title.text = "%s (%s)" % [d.name, d.hex_id]
	_inspector_header_hl_btn.visible = true
	var is_hl := (_highlighted_lineage_id == d.lineage_id and _highlighted_lineage_id != "")
	_inspector_header_hl_btn.text = EvoStardewStyle.tr_text(_lang, "✨ Linaje", "✨ Lineage")
	EvoStardewStyle.apply_button_active(_inspector_header_hl_btn, is_hl)

	var conf_pct := int(round(d.last_confidence * 100.0))
	_inspector_model_badge_lbl.text = EvoStardewStyle.tr_text(
		_lang,
		"🧠 Modelo: %s · Confianza %d%%" % [d.decision_model_tag, conf_pct],
		"🧠 Model: %s · Confidence %d%%" % [d.decision_model_tag, conf_pct]
	)

	# ========================================================================
	# TAB 1: 🧠 ALDEA Y DECISIONES
	# ========================================================================
	var meters_card := PanelContainer.new()
	meters_card.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_card(Color("#fbf2de"), EvoStardewStyle.COLOR_PARCHMENT_BORDER, 6))
	_deme_sheet_vbox.add_child(meters_card)

	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 4)
	meters_card.add_child(m_vbox)

	_add_sheet_kv(m_vbox, EvoStardewStyle.tr_text(_lang, "🛡️ Linaje:", "🛡️ Lineage:"), lin_name)
	_add_sheet_kv(
		m_vbox,
		EvoStardewStyle.tr_text(_lang, "👥 Población:", "👥 Population:"),
		"%d hab. (%s)" % [d.population, EvoStardewStyle.get_village_tier_label(d.population, _lang)]
	)

	# Caloric Reserve Golden Bar
	_add_milestone_bar(
		m_vbox,
		EvoStardewStyle.tr_text(_lang, "🍯 Reserva Calórica", "🍯 Caloric Reserve"),
		"%.1f" % d.energy_reserves,
		clampf(d.energy_reserves / 220.0 * 100.0, 0.0, 100.0),
		EvoStardewStyle.COLOR_GOLD_BRIGHT
	)

	var v_status := d.get_vital_status()
	var heart_icon := EvoStardewStyle.get_vital_status_heart(v_status)
	var v_label := EvoStardewStyle.get_vital_status_label(v_status, _lang)
	_add_sheet_kv(
		m_vbox,
		EvoStardewStyle.tr_text(_lang, "⚡ Balance Turno:", "⚡ Turn Balance:"),
		"%+.1f · %s %s" % [d.last_energy_delta, heart_icon, v_label]
	)

	# Decision Model Intention Section
	var dec_title := Label.new()
	dec_title.text = EvoStardewStyle.tr_text(
		_lang,
		"🧠 Intención (%s):" % d.decision_model_tag,
		"🧠 Intention (%s):" % d.decision_model_tag
	)
	dec_title.add_theme_font_size_override("font_size", 12)
	dec_title.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	_deme_sheet_vbox.add_child(dec_title)

	var dom_name := d.last_dominant_decision_id
	if _world_state.decisions_catalog.has(d.last_dominant_decision_id):
		dom_name = (_world_state.decisions_catalog[d.last_dominant_decision_id] as EvoTypes.DecisionDef).name

	var dom_row := HBoxContainer.new()
	dom_row.add_theme_constant_override("separation", 6)
	_deme_sheet_vbox.add_child(dom_row)

	var dom_icon := TextureRect.new()
	dom_icon.custom_minimum_size = Vector2(18, 18)
	dom_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dom_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dom_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dom_icon.texture = EvoStardewStyle.get_pixel_icon(EvoStardewStyle.get_decision_icon_key(d.last_dominant_decision_id, _world_state))
	dom_row.add_child(dom_icon)

	var dom_lbl := Label.new()
	dom_lbl.text = dom_name
	dom_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dom_lbl.clip_text = true
	dom_lbl.add_theme_font_size_override("font_size", 12)
	dom_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_INK)
	dom_row.add_child(dom_lbl)

	var prob_keys := d.last_decision_probabilities.keys()
	prob_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float(d.last_decision_probabilities[a]) > float(d.last_decision_probabilities[b])
	)
	for dec_id_var in prob_keys:
		var dec_id := str(dec_id_var)
		var prob: float = float(d.last_decision_probabilities[dec_id])
		var dec_lbl_str := dec_id
		if _world_state.decisions_catalog.has(dec_id):
			dec_lbl_str = (_world_state.decisions_catalog[dec_id] as EvoTypes.DecisionDef).name

		_add_milestone_bar(
			_deme_sheet_vbox,
			dec_lbl_str,
			"%d%%" % int(round(prob * 100.0)),
			prob * 100.0,
			EvoStardewStyle.COLOR_GOLD_BEVEL if dec_id == d.last_dominant_decision_id else EvoStardewStyle.COLOR_SEPIA
		)

	# Village Relations & Roads Summary
	var rel_card := PanelContainer.new()
	rel_card.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_card(Color("#f4e2b8"), EvoStardewStyle.COLOR_PARCHMENT_BORDER, 6))
	_deme_sheet_vbox.add_child(rel_card)

	var rel_vbox := VBoxContainer.new()
	rel_vbox.add_theme_constant_override("separation", 3)
	rel_card.add_child(rel_vbox)

	var rel_title := Label.new()
	rel_title.text = EvoStardewStyle.tr_text(_lang, "🛣️ Relaciones y Caminos:", "🛣️ Relations & Paths:")
	rel_title.add_theme_font_size_override("font_size", 11)
	rel_title.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	rel_vbox.add_child(rel_title)

	var rel_lines := _build_deme_relations_lines(d)
	for r_line in rel_lines:
		var rl := Label.new()
		rl.text = r_line
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_font_size_override("font_size", 11)
		rl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_INK)
		rel_vbox.add_child(rl)

	# Naturalist's Note (`last_justification`)
	var just_card := PanelContainer.new()
	just_card.add_theme_stylebox_override("panel", EvoStardewStyle.make_parchment_card(Color("#fbf2de"), EvoStardewStyle.COLOR_PARCHMENT_BORDER, 6))
	_deme_sheet_vbox.add_child(just_card)

	var just_lbl := Label.new()
	var just_txt := d.last_justification if d.last_justification != "" else EvoStardewStyle.tr_text(_lang, "Evaluación inicial de hábitat.", "Initial habitat evaluation.")
	just_lbl.text = "💬 " + just_txt
	just_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	just_lbl.add_theme_font_size_override("font_size", 10)
	just_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_SEPIA)
	just_card.add_child(just_lbl)

	# ========================================================================
	# TAB 2: 🧬 RASGOS E HITOS
	# ========================================================================
	var mile_title := Label.new()
	mile_title.text = EvoStardewStyle.tr_text(_lang, "⏳ Medidores de Hitos Evolutivos", "⏳ Evolutionary Milestone Meters")
	mile_title.add_theme_font_size_override("font_size", 12)
	mile_title.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	_traits_sheet_vbox.add_child(mile_title)

	var max_baldwin := 0
	for b_k in d.baldwin_counters.keys():
		var cnt := int(d.baldwin_counters[b_k])
		if cnt > max_baldwin:
			max_baldwin = cnt
	_add_milestone_bar(
		_traits_sheet_vbox,
		EvoStardewStyle.tr_text(_lang, "Asimilación Genética (Baldwin)", "Genetic Assimilation (Baldwin)"),
		"%d / 8 gen" % max_baldwin,
		clampf(float(max_baldwin) / 8.0 * 100.0, 0.0, 100.0),
		Color("#0d9488")
	)

	var innov_pct := clampf(d.innovation_counter * 100.0, 0.0, 100.0)
	_add_milestone_bar(
		_traits_sheet_vbox,
		EvoStardewStyle.tr_text(_lang, "Innovación Cultural", "Cultural Innovation"),
		"%d%%" % int(round(innov_pct)),
		innov_pct,
		EvoStardewStyle.COLOR_PURPLE_CULTURE
	)

	_add_milestone_bar(
		_traits_sheet_vbox,
		EvoStardewStyle.tr_text(_lang, "Aislamiento Alopátrico", "Allopatric Isolation"),
		"%d / 10 gen" % d.isolation_turns,
		clampf(float(d.isolation_turns) / 10.0 * 100.0, 0.0, 100.0),
		EvoStardewStyle.COLOR_BLUE_INFO
	)

	var traits_title := Label.new()
	traits_title.text = EvoStardewStyle.tr_text(_lang, "🧬 Medallones de Rasgos y Tradiciones", "🧬 Trait & Tradition Medallions")
	traits_title.add_theme_font_size_override("font_size", 12)
	traits_title.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	_traits_sheet_vbox.add_child(traits_title)

	var traits_flow := HFlowContainer.new()
	traits_flow.add_theme_constant_override("h_separation", 4)
	traits_flow.add_theme_constant_override("v_separation", 4)
	_traits_sheet_vbox.add_child(traits_flow)

	for t_id in d.biological_trait_ids:
		traits_flow.add_child(_make_trait_tag(t_id, false))
	for t_id in d.cultural_trait_ids:
		traits_flow.add_child(_make_trait_tag(t_id, true))

	var inject_row := HBoxContainer.new()
	inject_row.add_theme_constant_override("separation", 4)
	_traits_sheet_vbox.add_child(inject_row)

	var trait_opt := OptionButton.new()
	trait_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trait_opt.fit_to_longest_item = false
	trait_opt.clip_text = true
	trait_opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	trait_opt.add_item(EvoStardewStyle.tr_text(_lang, "➕ Inyectar Rasgo Experimental...", "➕ Inject Experimental Trait..."), 0)
	trait_opt.set_item_metadata(0, "")
	var idx_counter := 1
	for cat_t_id in _world_state.traits_catalog.keys():
		var tr_def: EvoTypes.TraitDef = _world_state.traits_catalog[cat_t_id]
		trait_opt.add_item("%s (%s)" % [tr_def.name, tr_def.category], idx_counter)
		trait_opt.set_item_metadata(idx_counter, tr_def.id)
		idx_counter += 1
	trait_opt.item_selected.connect(func(sel_idx: int) -> void:
		var chosen_id := str(trait_opt.get_item_metadata(sel_idx))
		if chosen_id != "":
			_inject_trait_into_deme(d.id, chosen_id)
	)
	inject_row.add_child(trait_opt)


func _format_deme_with_hex(od: EvoTypes.Deme) -> String:
	var suffix := "(%s)" % od.hex_id
	if od.name.ends_with(suffix):
		return od.name
	return "%s %s" % [od.name, suffix]


func _build_deme_relations_lines(d: EvoTypes.Deme) -> Array[String]:
	var lines: Array[String] = []
	if _world_state == null:
		return lines

	var mentioned_deme_ids: Dictionary = {}
	for fl in _world_state.active_flows:
		var has_deme_endpoints := (fl.from_deme_id != "" or fl.to_deme_id != "")
		var touches := (fl.from_deme_id == d.id or fl.to_deme_id == d.id) if has_deme_endpoints else (fl.from_hex_id == d.hex_id or fl.to_hex_id == d.hex_id)
		if not touches:
			continue
		var other_hex := fl.to_hex_id if fl.from_hex_id == d.hex_id else fl.from_hex_id
		var other_name := ("Hex (%s)" % other_hex)
		var other_deme_id := fl.to_deme_id if fl.from_deme_id == d.id else fl.from_deme_id
		if other_deme_id != "" and _world_state.demes.has(other_deme_id):
			var od_flow: EvoTypes.Deme = _world_state.demes[other_deme_id]
			other_name = _format_deme_with_hex(od_flow)
			mentioned_deme_ids[other_deme_id] = true
		var line_str := ""
		match fl.flow_type:
			"exchange", "cooperate", "merge":
				line_str = EvoStardewStyle.tr_text(_lang, "🛣️ Vía de cooperación activa con %s" % other_name, "🛣️ Active cooperation road with %s" % other_name)
			"dispute":
				line_str = EvoStardewStyle.tr_text(_lang, "⚔️ En conflicto / barricadas con %s" % other_name, "⚔️ In conflict / barricades with %s" % other_name)
			"migration":
				line_str = EvoStardewStyle.tr_text(_lang, "🧭 Expedición migratoria hacia (%s)" % other_hex, "🧭 Migratory expedition toward (%s)" % other_hex)
		if line_str != "" and not lines.has(line_str):
			lines.append(line_str)

	for dis in _world_state.disused_connections:
		var f_deme := str(dis.get("from_deme_id", ""))
		var t_deme := str(dis.get("to_deme_id", ""))
		var f_hex := str(dis.get("from_hex_id", ""))
		var t_hex := str(dis.get("to_hex_id", ""))
		var has_d := (f_deme != "" or t_deme != "")
		var touches_dis := (f_deme == d.id or t_deme == d.id) if has_d else (f_hex == d.hex_id or t_hex == d.hex_id)
		if touches_dis:
			var other_d_id := t_deme if f_deme == d.id else f_deme
			var target_h := t_hex if f_hex == d.hex_id else f_hex
			var target_label := "(%s)" % target_h
			if other_d_id != "" and other_d_id != d.id and _world_state.demes.has(other_d_id):
				var od_dis: EvoTypes.Deme = _world_state.demes[other_d_id]
				target_label = _format_deme_with_hex(od_dis)
			var age_val := int(dis.get("age", 0))
			var dis_str := ""
			if age_val > 0:
				dis_str = EvoStardewStyle.tr_text(
					_lang,
					"🚧 Camino cortado con %s (hace %d gen.)" % [target_label, age_val],
					"🚧 Severed path with %s (%d gen. ago)" % [target_label, age_val]
				)
			else:
				dis_str = EvoStardewStyle.tr_text(
					_lang,
					"🚧 Camino cortado con %s" % target_label,
					"🚧 Severed path with %s" % target_label
				)
			if not lines.has(dis_str):
				lines.append(dis_str)

	if _world_state.cells.has(d.hex_id):
		var c: EvoTypes.HexCell = _world_state.cells[d.hex_id]
		for other_id in c.deme_ids:
			if other_id != d.id and not mentioned_deme_ids.has(other_id) and _world_state.demes.has(other_id):
				var od: EvoTypes.Deme = _world_state.demes[other_id]
				lines.append(EvoStardewStyle.tr_text(_lang, "🤝 Coexistiendo en (%s) con %s" % [d.hex_id, od.name], "🤝 Coexisting at (%s) with %s" % [d.hex_id, od.name]))
		var n_ids := HexMath.get_neighbor_ids(c.q, c.r, _world_state.cells)
		for nid in n_ids:
			var nc: EvoTypes.HexCell = _world_state.cells[nid]
			for nd_id in nc.deme_ids:
				if not mentioned_deme_ids.has(nd_id) and _world_state.demes.has(nd_id):
					var nd: EvoTypes.Deme = _world_state.demes[nd_id]
					lines.append(EvoStardewStyle.tr_text(_lang, "🏘️ Aldea vecina: %s" % _format_deme_with_hex(nd), "🏘️ Neighbor village: %s" % _format_deme_with_hex(nd)))

	if lines.is_empty():
		lines.append(EvoStardewStyle.tr_text(_lang, "🏞️ Sin caminos exteriores activos (aldea aislada)", "🏞️ No active outer roads (isolated village)"))
	return lines


func _make_trait_tag(trait_id: String, is_cultural: bool) -> Control:
	var t_name := trait_id
	var tip := trait_id
	if _world_state != null and _world_state.traits_catalog.has(trait_id):
		var tr: EvoTypes.TraitDef = _world_state.traits_catalog[trait_id]
		t_name = tr.name
		var v := tr.vector
		tip = "%s\n%s\nCost: %+.2f | Extr: %+.2f | Eco: %+.2f | Mob: %+.2f | Coh: %+.2f | Thr: %.2f" % [
			tr.name, tr.description,
			v.metabolic_cost, v.extraction_efficiency, v.ecological_impact,
			v.spatial_mobility, v.social_cohesion, v.transmission_threshold
		]
	var badge := PanelContainer.new()
	var col := EvoStardewStyle.COLOR_PURPLE_CULTURE if is_cultural else Color("#0d9488")
	badge.add_theme_stylebox_override("panel", EvoStardewStyle.make_badge_style(col))
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


func _add_milestone_bar(parent: VBoxContainer, label_str: String, right_str: String, pct: float, fill_col: Color) -> void:
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
	EvoStardewStyle.style_progress_bar(bar, fill_col)
	vb.add_child(bar)


func _rebuild_hex_sheet() -> void:
	if _hex_sheet_vbox == null:
		return
	for child in _hex_sheet_vbox.get_children():
		child.queue_free()

	if _world_state == null or not _world_state.cells.has(_selected_hex_id):
		return

	var cell: EvoTypes.HexCell = _world_state.cells[_selected_hex_id]

	var bio_row := HBoxContainer.new()
	bio_row.add_theme_constant_override("separation", 8)
	_hex_sheet_vbox.add_child(bio_row)

	var bio_icon := TextureRect.new()
	bio_icon.custom_minimum_size = Vector2(24, 24)
	bio_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bio_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bio_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bio_icon.texture = EvoStardewStyle.get_pixel_icon(cell.biome)
	bio_row.add_child(bio_icon)

	var title := Label.new()
	title.text = "%s (%d, %d)" % [EvoStardewStyle.get_biome_label(cell.biome, _lang), cell.q, cell.r]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", EvoStardewStyle.COLOR_WOOD_DARK)
	bio_row.add_child(title)

	_add_sheet_kv(_hex_sheet_vbox, EvoStardewStyle.tr_text(_lang, "🌡️ Temperatura:", "🌡️ Temperature:"), "%+.2f" % cell.temperature)
	_add_sheet_kv(_hex_sheet_vbox, EvoStardewStyle.tr_text(_lang, "💧 Humedad:", "💧 Humidity:"), "%d%%" % int(round(cell.humidity * 100.0)))
	_add_sheet_kv(_hex_sheet_vbox, EvoStardewStyle.tr_text(_lang, "⛰️ Altitud:", "⛰️ Altitude:"), "%.2f" % cell.altitude)

	var r_ratio := clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity), 0.0, 1.0)
	_add_milestone_bar(
		_hex_sheet_vbox,
		EvoStardewStyle.tr_text(_lang, "🌾 Biomasa Disponible (R)", "🌾 Available Biomass (R)"),
		"%.0f / %.0f" % [cell.current_resources, cell.carrying_capacity],
		r_ratio * 100.0,
		EvoStardewStyle.COLOR_GOLD_BEVEL
	)

	var k_ratio := clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var h_col := EvoStardewStyle.COLOR_GREEN_OK
	if k_ratio < 0.60:
		h_col = EvoStardewStyle.COLOR_RED_DANGER
	elif k_ratio < 0.85:
		h_col = EvoStardewStyle.COLOR_AMBER_WARN

	_add_milestone_bar(
		_hex_sheet_vbox,
		EvoStardewStyle.tr_text(_lang, "💚 Salud Ecológica (K / Kmax)", "💚 Ecological Health (K / Kmax)"),
		"%.0f / %.0f (%d%%)" % [cell.carrying_capacity, cell.carrying_capacity_max, int(round(k_ratio * 100.0))],
		k_ratio * 100.0,
		h_col
	)


func _add_sheet_kv(parent: VBoxContainer, k_str: String, v_str: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	parent.add_child(hb)

	var kl := Label.new()
	kl.text = k_str
	kl.add_theme_font_size_override("font_size", 11)
	kl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_SEPIA)
	hb.add_child(kl)

	var vl := Label.new()
	vl.text = v_str
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vl.add_theme_font_size_override("font_size", 11)
	vl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_INK)
	hb.add_child(vl)


func _update_first_steps_labels() -> void:
	if _step1_lbl == null:
		return
	var c1 := "☑" if _step_1_done else "☐"
	var c2 := "☑" if _step_2_done else "☐"
	var c3 := "☑" if _step_3_done else "☐"

	_step1_lbl.text = EvoStardewStyle.tr_text(_lang, "%s 1. Seleccionar aldea" % c1, "%s 1. Select village" % c1)
	_step2_lbl.text = EvoStardewStyle.tr_text(_lang, "%s 2. Usar herramienta (1-0)" % c2, "%s 2. Use tool (1-0)" % c2)
	_step3_lbl.text = EvoStardewStyle.tr_text(_lang, "%s 3. Avanzar generación" % c3, "%s 3. Advance generation" % c3)

	_step1_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_GOLD_TEXT if _step_1_done else EvoStardewStyle.COLOR_CREAM_TEXT)
	_step2_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_GOLD_TEXT if _step_2_done else EvoStardewStyle.COLOR_CREAM_TEXT)
	_step3_lbl.add_theme_color_override("font_color", EvoStardewStyle.COLOR_GOLD_TEXT if _step_3_done else EvoStardewStyle.COLOR_CREAM_TEXT)


func _inject_trait_into_deme(deme_id: String, trait_id: String) -> void:
	if _world_state != null:
		EvoCatalog.inject_trait_into_deme(_world_state, deme_id, trait_id, _lang)
	inject_trait_requested.emit(deme_id, trait_id)
	refresh(_world_state)


func _set_inspector_tab(tab_id: String) -> void:
	_inspector_tab = tab_id
	if _deme_sheet_vbox != null:
		_deme_sheet_vbox.visible = (_inspector_tab == "deme")
	if _traits_sheet_vbox != null:
		_traits_sheet_vbox.visible = (_inspector_tab == "traits")
	if _hex_sheet_vbox != null:
		_hex_sheet_vbox.visible = (_inspector_tab == "habitat")
	_update_static_labels()


func _on_inspector_tab_pressed(tab_id: String) -> void:
	_set_inspector_tab(tab_id)
	_rebuild_active_inspector_sheet()


func _on_toggle_inspector_minimize() -> void:
	_inspector_minimized = not _inspector_minimized
	_inspector_body_vbox.visible = not _inspector_minimized
	_inspector_minimize_btn.text = "▸" if _inspector_minimized else "▾"
	_inspector_frame.offset_bottom = 232 if _inspector_minimized else 626
	if not _inspector_minimized:
		_rebuild_active_inspector_sheet()


func _on_header_highlight_pressed() -> void:
	if _world_state != null and _world_state.demes.has(_selected_deme_id):
		var d: EvoTypes.Deme = _world_state.demes[_selected_deme_id]
		_on_toggle_highlight_lineage(d.lineage_id)


func _on_hotbar_slot_pressed(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= HOTBAR_SLOTS_DEF.size():
		return
	var def: Dictionary = HOTBAR_SLOTS_DEF[slot_idx]
	_active_tool = str(def["tool"])
	var sub := str(def["sub"])
	if sub != "":
		_active_sub_mode = sub
	if _active_tool != "inspect":
		_step_2_done = true
	_update_static_labels()
	_rebuild_sub_tool_options()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_lens_cycle_btn_pressed() -> void:
	var order := ["biome", "food", "health"]
	var next_idx := (order.find(_active_lens) + 1) % order.size()
	_on_lens_pressed(str(order[next_idx]))


func _on_live_models_toggled(pressed: bool) -> void:
	if _world_state != null:
		_world_state.use_live_decision_models = pressed
		_update_top_bar_state()


func _on_preset_selected(index: int) -> void:
	var preset_id := str(_preset_option.get_item_metadata(index))
	preset_selected.emit(preset_id)


func _on_export_pressed() -> void:
	if _world_state != null:
		var json_str := JSON.stringify(_world_state.to_dict(), "\t")
		var f := FileAccess.open(DEFAULT_EXPORT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(json_str)
			f.close()
		show_milestone_banner(
			EvoStardewStyle.tr_text(_lang, "Mundo Exportado (JSON)", "World Exported (JSON)"),
			EvoStardewStyle.tr_text(_lang, "Guardado en %s" % DEFAULT_EXPORT_PATH, "Saved to %s" % DEFAULT_EXPORT_PATH),
			false
		)
	export_json_requested.emit(DEFAULT_EXPORT_PATH)


func _on_import_pressed() -> void:
	if FileAccess.file_exists(DEFAULT_EXPORT_PATH):
		var f := FileAccess.open(DEFAULT_EXPORT_PATH, FileAccess.READ)
		if f != null:
			var raw := f.get_as_text()
			f.close()
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				var imported := EvoTypes.WorldState.from_dict(parsed)
				set_world_state(imported)
				state_imported.emit(imported)
	import_json_requested.emit(DEFAULT_EXPORT_PATH)


func _on_play_pressed() -> void:
	_is_playing = not _is_playing
	if _is_playing:
		_step_3_done = true
	_update_static_labels()
	play_pause_toggled.emit(_is_playing)


func _on_step_pressed() -> void:
	_step_3_done = true
	_update_first_steps_labels()
	step_generation_requested.emit()


func _on_speed_pressed() -> void:
	_is_fast = not _is_fast
	_update_static_labels()
	speed_changed.emit(_is_fast)


func _on_tree_btn_pressed() -> void:
	open_tree_modal()


func _on_settings_btn_pressed() -> void:
	_settings_popup.visible = not _settings_popup.visible


func _on_lang_selected(lang: String) -> void:
	set_language(lang)
	language_changed.emit(lang)


func _on_settings_toggled(_pressed: bool) -> void:
	var ap := _auto_pause_check.button_pressed
	var up := _unlimited_pressure_check.button_pressed
	var fs := _free_sandbox_check.button_pressed
	if _world_state != null:
		_world_state.auto_pause_on_milestone = ap
		_world_state.unlimited_pressure_mode = up
		_world_state.free_sandbox_mode = fs
		_update_top_bar_state()
	settings_changed.emit(ap, up, fs)


func _on_cam_preset_pressed(action: String, val: float) -> void:
	camera_preset_requested.emit(action, val)


func _on_tool_button_pressed(tool_id: String) -> void:
	_active_tool = tool_id
	if tool_id == "set_biome" and not EvoTypes.BIOMES.has(_active_sub_mode):
		_active_sub_mode = "savanna"
	elif tool_id == "adjust_altitude" and not (_active_sub_mode in ["raise", "lower"]):
		_active_sub_mode = "raise"
	elif tool_id == "adjust_carrying_capacity" and not (_active_sub_mode in ["enrich", "deplete"]):
		_active_sub_mode = "enrich"
	elif tool_id != "inspect":
		_step_2_done = true
	_update_static_labels()
	_rebuild_sub_tool_options()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_sub_mode_selected(sub_mode: String) -> void:
	_active_sub_mode = sub_mode
	_step_2_done = true
	_rebuild_sub_tool_options()
	_update_hotbar_visuals()
	_update_first_steps_labels()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_sea_level_btn_pressed(delta: float) -> void:
	_step_2_done = true
	_update_first_steps_labels()
	sea_level_change_requested.emit(delta)


func _on_brush_radius_pressed(rad: int) -> void:
	_brush_radius = rad
	_update_static_labels()
	tool_changed.emit(_active_tool, _active_sub_mode, _brush_radius)


func _on_lens_pressed(lens_id: String) -> void:
	_active_lens = lens_id
	_update_static_labels()
	lens_changed.emit(_active_lens)


func _on_legend_toggle_pressed() -> void:
	_legend_panel.visible = not _legend_panel.visible
	_update_static_labels()


func _on_village_list_item_pressed(deme_id: String, hex_id: String) -> void:
	select_deme(deme_id)
	deme_selected.emit(deme_id, hex_id)


func _on_toggle_highlight_lineage(lineage_id: String) -> void:
	if _highlighted_lineage_id == lineage_id:
		_highlighted_lineage_id = ""
	else:
		_highlighted_lineage_id = lineage_id
	_rebuild_deme_sheet()
	lineage_highlight_requested.emit(_highlighted_lineage_id)


func _on_modal_jump_to_hex(hex_id: String, deme_id: String) -> void:
	if deme_id != "" and _world_state != null and _world_state.demes.has(deme_id):
		select_deme(deme_id)
	else:
		select_hex(hex_id)
	hex_jump_requested.emit(hex_id, deme_id)


func _on_lineage_highlight_from_modal(lineage_id: String) -> void:
	_highlighted_lineage_id = lineage_id
	_rebuild_deme_sheet()
	lineage_highlight_requested.emit(lineage_id)


func _on_lab_item_saved(item_type: String, item_data: Dictionary) -> void:
	refresh(_world_state)
	catalog_item_saved.emit(item_type, item_data)


func _on_lab_inject_trait(deme_id: String, trait_id: String) -> void:
	_inject_trait_into_deme(deme_id, trait_id)
