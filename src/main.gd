class_name EvoMainController
extends Node2D

const NORMAL_STEP_INTERVAL: float = 1.50
const FAST_STEP_INTERVAL: float = 0.30
const SLOT_A_DEME_IDS: Array[String] = ["deme-rift-west", "deme-darwin-founder", "deme-island-1"]
const SLOT_B_DEME_IDS: Array[String] = ["deme-rift-east", "deme-darwin-rival", "deme-island-2"]

var world_state: EvoTypes.WorldState
var camera: EvoCameraController
var world_renderer: EvoWorldRenderer
var ui_layer: CanvasLayer
var hud: EvoMainHud

var lang: String = "es"
var current_lang: String:
	get:
		return lang
	set(value):
		lang = value
		if world_renderer != null:
			world_renderer.lang = value

var lab_modal: EvoLabModal:
	get:
		return hud.lab_modal if hud != null else null

var is_playing: bool = false
var is_fast: bool = false
var quit_on_close_enabled: bool = true
var _play_timer: float = 0.0
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
	world_renderer.lang = lang
	add_child(world_renderer)
	world_renderer.set_camera(camera)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	hud = EvoMainHud.new()
	hud.name = "MainHud"
	ui_layer.add_child(hud)
	if hud._preset_option == null:
		hud._ready()

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
		if EvoDecisionModel.has_pending_jobs():
			return
		_play_timer = 0.0
		step_generation()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE:
		if get_viewport() != null:
			var focus_owner := get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit or focus_owner is TextEdit:
				return
		if hud != null and (
			hud._ollama_startup_blocked
			or (hud._missing_models_modal != null and hud._missing_models_modal.visible)
			or (hud._settings_popup != null and hud._settings_popup.visible)
			or (hud.lab_modal != null and hud.lab_modal.visible)
			or (hud.notebook_modal != null and hud.notebook_modal.visible)
			or (hud.tree_modal != null and hud.tree_modal.visible)
		):
			return
		_on_play_pause_toggled(not is_playing)
		hud.set_playing_state(is_playing)
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE:
		if hud._missing_models_modal != null and hud._missing_models_modal.visible:
			hud._on_missing_models_skip_pressed()
		elif hud._settings_popup != null and hud._settings_popup.visible:
			hud._settings_popup.visible = false
		elif hud.notebook_modal != null and hud.notebook_modal.visible:
			hud.notebook_modal.close_modal()
		elif hud.tree_modal != null and hud.tree_modal.visible:
			hud.tree_modal.close_modal()
		elif hud.lab_modal != null and hud.lab_modal.visible:
			hud.lab_modal.close_modal()
		else:
			hud._on_tool_button_pressed("inspect")
		get_viewport().set_input_as_handled()


func _connect_signals() -> void:
	world_renderer.hex_clicked.connect(_on_world_hex_clicked)
	world_renderer.hex_dragged.connect(_on_world_hex_dragged)
	world_renderer.deme_clicked.connect(_on_world_deme_clicked)

	hud.preset_selected.connect(func(pid: String) -> void: load_preset(pid))
	hud.matchup_changed.connect(_on_matchup_changed)
	hud.matchup_reset_requested.connect(reset_matchup)
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
	hud.quit_requested.connect(_on_quit_requested)

	if hud.lab_modal != null:
		if hud.lab_modal.has_signal("strategy_saved"):
			hud.lab_modal.connect("strategy_saved", _on_strategy_saved)
		if hud.lab_modal.has_signal("strategy_assigned"):
			hud.lab_modal.connect("strategy_assigned", _on_strategy_assigned)


func load_preset(preset_id: String, strategy_a_id: String = "", strategy_b_id: String = "") -> void:
	is_playing = false
	_play_timer = 0.0
	EvoOllamaClient.clear_cache()

	var preserved_traits: Dictionary = {}
	var preserved_decisions: Dictionary = {}
	var preserved_strategies: Dictionary = {}
	if world_state != null:
		for tid in world_state.traits_catalog.keys():
			var tr: EvoTypes.TraitDef = world_state.traits_catalog[tid]
			if tr.origin in ["user", "custom"]:
				preserved_traits[tid] = tr.duplicate_trait()
		for did in world_state.decisions_catalog.keys():
			var dec: EvoTypes.DecisionDef = world_state.decisions_catalog[did]
			if dec.origin in ["user", "custom"]:
				preserved_decisions[did] = dec.duplicate_decision()
		for sid in world_state.strategies_catalog.keys():
			var strat: EvoTypes.StrategyDef = world_state.strategies_catalog[sid]
			if strat.origin in ["user", "custom"]:
				preserved_strategies[sid] = strat.duplicate_strategy()

	var strat_a := strategy_a_id
	if strat_a == "":
		strat_a = world_state.strategy_a_id if world_state != null and world_state.strategy_a_id != "" else EvoCatalog.DEFAULT_STRATEGY_A_ID
	var strat_b := strategy_b_id
	if strat_b == "":
		strat_b = world_state.strategy_b_id if world_state != null and world_state.strategy_b_id != "" else EvoCatalog.DEFAULT_STRATEGY_B_ID

	world_state = EvoCatalog.create_preset_world(preset_id, lang, strat_a, strat_b)

	var needs_reapply := false
	for tid in preserved_traits.keys():
		if not world_state.traits_catalog.has(tid):
			world_state.traits_catalog[tid] = preserved_traits[tid]
	for did in preserved_decisions.keys():
		if not world_state.decisions_catalog.has(did):
			world_state.decisions_catalog[did] = preserved_decisions[did]
	for sid in preserved_strategies.keys():
		if not world_state.strategies_catalog.has(sid):
			world_state.strategies_catalog[sid] = preserved_strategies[sid]

	if world_state.strategies_catalog.has(strat_a) and world_state.strategy_a_id != strat_a:
		world_state.strategy_a_id = strat_a
		needs_reapply = true
	if world_state.strategies_catalog.has(strat_b) and world_state.strategy_b_id != strat_b:
		world_state.strategy_b_id = strat_b
		needs_reapply = true

	if needs_reapply:
		_reapply_starting_strategies()

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


func set_matchup_strategies(strategy_a_id: String, strategy_b_id: String) -> void:
	var target_preset := world_state.preset_id if world_state != null and world_state.preset_id != "" else "preset-rift-savanna"
	load_preset(target_preset, strategy_a_id, strategy_b_id)


func reset_matchup() -> void:
	if world_state == null:
		load_preset("preset-rift-savanna")
		return
	load_preset(world_state.preset_id, world_state.strategy_a_id, world_state.strategy_b_id)


func _on_matchup_changed(strategy_a_id: String, strategy_b_id: String) -> void:
	set_matchup_strategies(strategy_a_id, strategy_b_id)


func _reapply_starting_strategies() -> void:
	if world_state == null:
		return
	for did in SLOT_A_DEME_IDS:
		if world_state.demes.has(did):
			EvoCatalog.apply_strategy_to_deme(world_state, world_state.demes[did], world_state.strategy_a_id, lang)
	for did in SLOT_B_DEME_IDS:
		if world_state.demes.has(did):
			EvoCatalog.apply_strategy_to_deme(world_state, world_state.demes[did], world_state.strategy_b_id, lang)
	EvoDecisionModel.evaluate_all_demes(world_state, lang)


func _on_strategy_saved(strategy_id: String) -> void:
	if world_state == null:
		return
	EvoUserSettings.save_user_catalog(world_state)
	EvoOllamaClient.clear_cache()
	EvoDecisionModel.invalidate_state_caches(world_state)
	if world_state.generation == 0 and (strategy_id == world_state.strategy_a_id or strategy_id == world_state.strategy_b_id):
		if strategy_id == world_state.strategy_a_id:
			for did in SLOT_A_DEME_IDS:
				if world_state.demes.has(did):
					EvoCatalog.apply_strategy_to_deme(world_state, world_state.demes[did], strategy_id, lang)
		if strategy_id == world_state.strategy_b_id:
			for did in SLOT_B_DEME_IDS:
				if world_state.demes.has(did):
					EvoCatalog.apply_strategy_to_deme(world_state, world_state.demes[did], strategy_id, lang)
		for did in world_state.demes.keys():
			var d: EvoTypes.Deme = world_state.demes[did]
			if d.strategy_id == strategy_id:
				EvoCatalog.apply_strategy_to_deme(world_state, d, strategy_id, lang)
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
	elif world_state.strategies_catalog.has(strategy_id):
		var strat: EvoTypes.StrategyDef = world_state.strategies_catalog[strategy_id]
		for did in world_state.demes.keys():
			var d: EvoTypes.Deme = world_state.demes[did]
			if d.strategy_id == strategy_id:
				d.color = strat.color
				if world_state.lineage_tree.has(d.lineage_id):
					var lin: EvoTypes.LineageNode = world_state.lineage_tree[d.lineage_id]
					if lin.divergence_reason != "allopatric_speciation":
						lin.color = strat.color
	EvoDecisionModel.prefetch_for_state(world_state)
	hud.refresh(world_state)
	world_renderer.refresh()


func _on_strategy_assigned(slot: String, strategy_id: String) -> void:
	if world_state == null or strategy_id == "":
		return
	var strat_a := world_state.strategy_a_id
	var strat_b := world_state.strategy_b_id
	if slot.to_lower() == "a":
		strat_a = strategy_id
	elif slot.to_lower() == "b":
		strat_b = strategy_id
	set_matchup_strategies(strat_a, strat_b)


func _sync_selection_after_world_mutation() -> void:
	if world_state == null:
		return
	if world_renderer.selected_deme_id != "" and world_state.demes.has(world_renderer.selected_deme_id):
		var d: EvoTypes.Deme = world_state.demes[world_renderer.selected_deme_id]
		world_renderer.selected_hex_id = d.hex_id
	else:
		if world_state.cells.has(world_renderer.selected_hex_id):
			var cell: EvoTypes.HexCell = world_state.cells[world_renderer.selected_hex_id]
			if not cell.deme_ids.is_empty():
				world_renderer.selected_deme_id = cell.deme_ids[0]
			else:
				world_renderer.selected_deme_id = ""
		else:
			world_renderer.selected_deme_id = ""
	if hud != null:
		hud._selected_deme_id = world_renderer.selected_deme_id
		hud._selected_hex_id = world_renderer.selected_hex_id


func step_generation() -> void:
	_play_timer = 0.0
	if world_state == null:
		return
	if hud != null and (hud._ollama_startup_blocked or (hud._missing_models_modal != null and hud._missing_models_modal.visible)):
		return
	var res := EvoTurnEngine.advance_generation(world_state, lang)
	hud.mark_generation_advanced()
	_sync_selection_after_world_mutation()

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
		EvoDecisionModel.invalidate_state_caches(world_state)
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
		hud.mark_tool_used()
		if world_renderer.selected_deme_id != "" and world_state.demes.has(world_renderer.selected_deme_id) and (world_state.demes[world_renderer.selected_deme_id] as EvoTypes.Deme).hex_id != hex_id:
			_sync_selection_after_world_mutation()
		else:
			world_renderer.selected_hex_id = hex_id
			hud.select_hex(hex_id)
			world_renderer.selected_deme_id = hud._selected_deme_id
			_sync_selection_after_world_mutation()
		hud.refresh(world_state)
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
	if hud._world_state != world_state:
		hud.set_world_state(world_state)
	if not world_state.demes.has(hud._selected_deme_id):
		hud._selected_deme_id = str(world_state.demes.keys()[0]) if not world_state.demes.is_empty() else ""
	EvoOllamaClient.clear_cache()
	world_renderer.selected_deme_id = hud._selected_deme_id
	if world_state.demes.has(hud._selected_deme_id):
		world_renderer.selected_hex_id = (world_state.demes[hud._selected_deme_id] as EvoTypes.Deme).hex_id
	elif not world_state.cells.is_empty():
		if world_state.cells.has(hud._selected_hex_id):
			world_renderer.selected_hex_id = hud._selected_hex_id
		elif world_state.cells.has("0,0"):
			world_renderer.selected_hex_id = "0,0"
		else:
			world_renderer.selected_hex_id = str(world_state.cells.keys()[0])
	else:
		world_renderer.selected_hex_id = ""
	world_renderer.highlighted_lineage_id = ""
	hud._selected_hex_id = world_renderer.selected_hex_id
	EvoDecisionModel.evaluate_all_demes(world_state, hud._lang if hud != null else lang)
	EvoDecisionModel.prefetch_for_state(world_state)
	world_renderer.set_world_state(world_state)
	hud.refresh(world_state)


func _on_play_pause_toggled(p_playing: bool) -> void:
	if p_playing and hud != null and (hud._ollama_startup_blocked or (hud._missing_models_modal != null and hud._missing_models_modal.visible)):
		is_playing = false
		hud.set_playing_state(false)
		return
	is_playing = p_playing
	_play_timer = 0.0


func _on_quit_requested() -> void:
	is_playing = false
	EvoDecisionModel.wait_for_workers()
	if quit_on_close_enabled and get_tree() != null:
		get_tree().quit()


func _on_speed_changed(p_fast: bool) -> void:
	is_fast = p_fast
	_play_timer = 0.0


func _on_language_changed(new_lang: String) -> void:
	lang = new_lang
	if world_renderer != null:
		world_renderer.lang = lang
	if world_state != null:
		EvoI18n.localize_world_state(world_state, lang)
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
		EvoDecisionModel.invalidate_state_caches(world_state)
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
		hud.mark_tool_used()
		_sync_selection_after_world_mutation()
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
		var focus_alt := maxf(c.altitude, world_state.sea_level) if c.biome == "ocean" else c.altitude
		camera.focus_on_hex(c.q, c.r, focus_alt)
	world_renderer.refresh()


func _on_hud_hex_jump_requested(hex_id: String, deme_id: String) -> void:
	world_renderer.selected_hex_id = hex_id
	if deme_id != "" and world_state != null and world_state.demes.has(deme_id):
		world_renderer.selected_deme_id = deme_id
	if world_state != null and world_state.cells.has(hex_id):
		var c: EvoTypes.HexCell = world_state.cells[hex_id]
		var focus_alt := maxf(c.altitude, world_state.sea_level) if c.biome == "ocean" else c.altitude
		camera.focus_on_hex(c.q, c.r, focus_alt)
	world_renderer.refresh()


func _on_lineage_highlight_requested(lineage_id: String) -> void:
	world_renderer.highlighted_lineage_id = lineage_id
	world_renderer.refresh()


func _on_inject_trait_requested(_deme_id: String, _trait_id: String) -> void:
	if world_state != null:
		EvoDecisionModel.invalidate_state_caches(world_state)
		EvoDecisionModel.evaluate_all_demes(world_state, lang)
		EvoDecisionModel.prefetch_for_state(world_state)
		hud.refresh(world_state)
	world_renderer.refresh()


func _on_catalog_item_saved(item_type: String, item_data: Variant = null) -> void:
	if world_state != null:
		EvoUserSettings.save_user_catalog(world_state)
		if item_type == "strategy" and item_data is Dictionary and (item_data as Dictionary).has("id"):
			_on_strategy_saved(str((item_data as Dictionary)["id"]))
			return
		EvoOllamaClient.clear_cache()
		EvoDecisionModel.invalidate_state_caches(world_state)
		EvoDecisionModel.evaluate_all_demes(world_state, hud._lang if hud != null else lang)
		EvoDecisionModel.prefetch_for_state(world_state)
		hud.refresh(world_state)
		world_renderer.refresh()
