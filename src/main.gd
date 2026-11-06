class_name EvoMainController
extends Node2D

const NORMAL_STEP_INTERVAL: float = 1.50
const FAST_STEP_INTERVAL: float = 0.30

var world_state: EvoTypes.WorldState
var camera: EvoCameraController
var world_renderer: EvoWorldRenderer
var ui_layer: CanvasLayer
var hud: EvoMainHud

var lang: String = "es"
var is_playing: bool = false
var is_fast: bool = false
var _play_timer: float = 0.0
var _async_wait_elapsed: float = 0.0
var _last_model_revision: int = 0


func _ready() -> void:
	if camera != null:
		return
	EvoUserSettings.load_settings()
	EvoDecisionModel.check_ollama_status(true)

	camera = EvoCameraController.new()
	camera.name = "CameraController"
	add_child(camera)

	world_renderer = EvoWorldRenderer.new()
	world_renderer.name = "WorldRenderer"
	add_child(world_renderer)
	world_renderer.set_camera(camera)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	hud = EvoMainHud.new()
	hud.name = "MainHud"
	ui_layer.add_child(hud)

	_connect_signals()
	load_preset("preset-rift-savanna")
	set_process(true)
	set_process_unhandled_key_input(true)


func _exit_tree() -> void:
	EvoDecisionModel.wait_for_workers()


func _process(delta: float) -> void:
	if world_state == null:
		return
	var async_res := EvoDecisionModel.apply_completed_live_results(world_state, lang, _last_model_revision)
	_last_model_revision = int(async_res["revision"])
	if bool(async_res["updated"]):
		hud.refresh(world_state)
		world_renderer.refresh_village_decisions()
		if bool(async_res.get("dom_changed", true)):
			world_renderer.refresh()

	if not is_playing:
		return
	var interval: float = FAST_STEP_INTERVAL if is_fast else NORMAL_STEP_INTERVAL
	_play_timer += delta
	if _play_timer >= interval:
		if world_state.use_live_decision_models and EvoDecisionModel.has_pending_jobs() and _async_wait_elapsed < 0.60:
			_async_wait_elapsed += delta
			return
		_play_timer = 0.0
		_async_wait_elapsed = 0.0
		step_generation()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE:
		_on_play_pause_toggled(not is_playing)
		hud.set_playing_state(is_playing)
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE:
		if hud._missing_models_modal != null and hud._missing_models_modal.visible:
			hud._on_missing_models_skip_pressed()
		elif hud._settings_popup != null and hud._settings_popup.visible:
			hud._settings_popup.visible = false
		elif hud.notebook_modal != null and hud.notebook_modal.visible:
			hud.notebook_modal.visible = false
		elif hud.tree_modal != null and hud.tree_modal.visible:
			hud.tree_modal.visible = false
		elif hud.lab_modal != null and hud.lab_modal.visible:
			hud.lab_modal.visible = false
		else:
			hud._on_tool_button_pressed("inspect")
		get_viewport().set_input_as_handled()


func _connect_signals() -> void:
	world_renderer.hex_clicked.connect(_on_world_hex_clicked)
	world_renderer.hex_dragged.connect(_on_world_hex_dragged)
	world_renderer.deme_clicked.connect(_on_world_deme_clicked)

	hud.preset_selected.connect(load_preset)
	hud.state_imported.connect(_on_state_imported)
	hud.play_pause_toggled.connect(_on_play_pause_toggled)
	hud.step_generation_requested.connect(step_generation)
	hud.speed_changed.connect(_on_speed_changed)
	hud.language_changed.connect(_on_language_changed)
	hud.settings_changed.connect(_on_settings_changed)
	hud.decision_models_changed.connect(_on_decision_models_changed)
	hud.camera_preset_requested.connect(_on_camera_preset_requested)
	hud.tool_changed.connect(_on_tool_changed)
	hud.sea_level_change_requested.connect(_on_sea_level_change_requested)
	hud.lens_changed.connect(_on_lens_changed)
	hud.deme_selected.connect(_on_hud_deme_selected)
	hud.hex_jump_requested.connect(_on_hud_hex_jump_requested)
	hud.lineage_highlight_requested.connect(_on_lineage_highlight_requested)
	hud.inject_trait_requested.connect(_on_inject_trait_requested)
	hud.catalog_item_saved.connect(_on_catalog_item_saved)


func load_preset(preset_id: String) -> void:
	is_playing = false
	_play_timer = 0.0
	world_state = EvoCatalog.create_preset_world(preset_id, lang)
	camera.reset_camera()
	world_renderer.highlighted_lineage_id = ""
	world_renderer.set_world_state(world_state)

	if not world_state.demes.is_empty():
		var first_deme_id := str(world_state.demes.keys()[0])
		var first_deme: EvoTypes.Deme = world_state.demes[first_deme_id]
		world_renderer.selected_deme_id = first_deme_id
		world_renderer.selected_hex_id = first_deme.hex_id
	else:
		world_renderer.selected_deme_id = ""
		world_renderer.selected_hex_id = "0,0"

	hud.set_playing_state(false)
	hud.setup(world_state, lang)
	world_renderer.refresh()


func step_generation() -> void:
	if world_state == null:
		return
	var res := EvoTurnEngine.advance_generation(world_state, lang)
	hud.mark_generation_advanced()

	if world_renderer.selected_deme_id != "" and not world_state.demes.has(world_renderer.selected_deme_id):
		if not world_state.demes.is_empty():
			var next_id := str(world_state.demes.keys()[0])
			world_renderer.selected_deme_id = next_id
			world_renderer.selected_hex_id = (world_state.demes[next_id] as EvoTypes.Deme).hex_id
			hud.select_deme(next_id)
		else:
			world_renderer.selected_deme_id = ""
	elif world_renderer.selected_deme_id != "" and world_state.demes.has(world_renderer.selected_deme_id):
		var d: EvoTypes.Deme = world_state.demes[world_renderer.selected_deme_id]
		world_renderer.selected_hex_id = d.hex_id

	if bool(res["has_macro_outcome"]) or (world_state.auto_pause_on_milestone and bool(res["has_milestone"])):
		is_playing = false
		hud.set_playing_state(false)

	hud.refresh(world_state)
	world_renderer.refresh()


func _apply_brush_at_hex(hex_id: String) -> void:
	if world_state == null or not world_state.cells.has(hex_id):
		return
	var tool_id := hud.get_active_tool()
	var sub_mode := hud.get_active_sub_mode()
	var rad := hud.get_brush_radius()
	var target_hexes := HexMath.get_brush_hex_ids(hex_id, rad, world_state.cells)

	var applied := false
	if tool_id == "set_biome":
		applied = EvoTurnEngine.apply_set_biome(world_state, target_hexes, sub_mode, lang)
	elif tool_id == "adjust_altitude":
		var delta_alt := 0.18 if sub_mode == "raise" else -0.18
		applied = EvoTurnEngine.apply_adjust_altitude(world_state, target_hexes, delta_alt, lang)
	elif tool_id == "adjust_carrying_capacity":
		var delta_k := 0.25 if sub_mode == "enrich" else -0.25
		applied = EvoTurnEngine.apply_adjust_carrying_capacity(world_state, target_hexes, delta_k)

	if applied:
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
		hud.mark_tool_used()
		world_renderer.selected_hex_id = hex_id
		hud.select_hex(hex_id)
		hud._update_top_bar_state()
		world_renderer.refresh()


func _on_world_hex_clicked(hex_id: String, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	var tool_id := hud.get_active_tool()
	if tool_id == "inspect":
		world_renderer.selected_hex_id = hex_id
		if world_state != null and world_state.cells.has(hex_id):
			var c: EvoTypes.HexCell = world_state.cells[hex_id]
			if not c.deme_ids.is_empty():
				world_renderer.selected_deme_id = c.deme_ids[0]
			else:
				world_renderer.selected_deme_id = ""
		hud.select_hex(hex_id)
		world_renderer.refresh()
	elif tool_id in ["set_biome", "adjust_altitude", "adjust_carrying_capacity"]:
		_apply_brush_at_hex(hex_id)


func _on_world_hex_dragged(hex_id: String) -> void:
	var tool_id := hud.get_active_tool()
	if tool_id in ["set_biome", "adjust_altitude", "adjust_carrying_capacity"]:
		_apply_brush_at_hex(hex_id)


func _on_world_deme_clicked(deme_id: String, hex_id: String) -> void:
	world_renderer.selected_deme_id = deme_id
	world_renderer.selected_hex_id = hex_id
	hud.select_deme(deme_id)
	world_renderer.refresh()


func _on_state_imported(new_state: EvoTypes.WorldState) -> void:
	is_playing = false
	_play_timer = 0.0
	world_state = new_state
	hud.set_playing_state(false)
	world_renderer.set_world_state(world_state)
	hud.refresh(world_state)


func _on_play_pause_toggled(p_playing: bool) -> void:
	is_playing = p_playing
	_play_timer = 0.0


func _on_speed_changed(p_fast: bool) -> void:
	is_fast = p_fast
	_play_timer = 0.0


func _on_language_changed(new_lang: String) -> void:
	lang = new_lang
	if world_state != null:
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
		if hud != null and hud._lang != lang:
			hud.set_language(lang)
		else:
			hud.refresh(world_state)
		world_renderer.refresh()


func _on_settings_changed(auto_pause: bool, unlimited_pressure: bool, free_sandbox: bool) -> void:
	if world_state != null:
		world_state.auto_pause_on_milestone = auto_pause
		world_state.unlimited_pressure_mode = unlimited_pressure
		world_state.free_sandbox_mode = free_sandbox
		hud.refresh(world_state)


func _on_decision_models_changed() -> void:
	if world_renderer != null:
		world_renderer.refresh_village_decisions()
		world_renderer.refresh()


func _on_camera_preset_requested(action: String, value: float) -> void:
	if action == "pitch":
		camera.set_pitch_preset(value)
	elif action == "yaw":
		camera.rotate_by(value)
	elif action == "reset":
		camera.reset_camera()


func _on_tool_changed(tool_id: String, _sub_mode: String, brush_radius: int) -> void:
	camera.active_tool = tool_id
	world_renderer.active_tool = tool_id
	world_renderer.brush_radius = brush_radius
	world_renderer.refresh()


func _on_sea_level_change_requested(delta: float) -> void:
	if world_state == null:
		return
	if EvoTurnEngine.apply_adjust_sea_level(world_state, delta, lang):
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
		hud.mark_tool_used()
		hud.refresh(world_state)
		world_renderer.refresh()


func _on_lens_changed(lens_id: String) -> void:
	world_renderer.active_lens = lens_id
	world_renderer.refresh()


func _on_hud_deme_selected(deme_id: String, hex_id: String) -> void:
	world_renderer.selected_deme_id = deme_id
	world_renderer.selected_hex_id = hex_id
	if world_state != null and world_state.cells.has(hex_id):
		var c: EvoTypes.HexCell = world_state.cells[hex_id]
		camera.focus_on_hex(c.q, c.r, c.altitude)
	world_renderer.refresh()


func _on_hud_hex_jump_requested(hex_id: String, deme_id: String) -> void:
	world_renderer.selected_hex_id = hex_id
	if deme_id != "" and world_state != null and world_state.demes.has(deme_id):
		world_renderer.selected_deme_id = deme_id
	if world_state != null and world_state.cells.has(hex_id):
		var c: EvoTypes.HexCell = world_state.cells[hex_id]
		camera.focus_on_hex(c.q, c.r, c.altitude)
	world_renderer.refresh()


func _on_lineage_highlight_requested(lineage_id: String) -> void:
	world_renderer.highlighted_lineage_id = lineage_id
	world_renderer.refresh()


func _on_inject_trait_requested(_deme_id: String, _trait_id: String) -> void:
	world_renderer.refresh()


func _on_catalog_item_saved(_item_type: String, _item_data: Dictionary) -> void:
	if world_state != null:
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
		hud.refresh(world_state)
		world_renderer.refresh()
