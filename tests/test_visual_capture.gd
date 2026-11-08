extends SceneTree

const OUTPUT_DIR: String = "/home/arrase/Develop/Evolution/gh-pages/assets/img"
var _tmp_cfg_dir: String = ""


func _init() -> void:
	_tmp_cfg_dir = "/tmp/evolution_visual_capture_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_tmp_cfg_dir)
	EvoUserSettings.config_path_override = _tmp_cfg_dir.path_join("settings.json")
	call_deferred("_run_captures")


func _wait_and_save(main: EvoMainController, filename: String) -> void:
	if main.hud._missing_models_modal != null:
		main.hud._missing_models_modal.visible = false
	main.world_renderer.refresh()
	main.world_renderer._process(0.016)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	var full_path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = img.save_png(full_path)
	if err == OK:
		print("[CAPTURE OK] %s (%dx%d)" % [full_path, img.get_width(), img.get_height()])
	else:
		printerr("[CAPTURE FAIL] %s (err=%d)" % [full_path, err])


func _run_captures() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	root.add_child(main)
	for _i in range(5):
		await process_frame

	main.hud._startup_models_checked = true
	main.hud._set_startup_blocked(false)
	if main.hud._missing_models_modal != null:
		main.hud._missing_models_modal.visible = false
	main._on_language_changed("en")

	# 1. screenshot_rift_savanna.png (6 generations, village selected)
	main.load_preset("preset-rift-savanna")
	for _g in range(6):
		main.step_generation()
	main.hud.refresh(main.world_state)
	if main.world_state.demes.has("deme-rift-east"):
		main.hud.select_deme("deme-rift-east")
		main.world_renderer.selected_deme_id = "deme-rift-east"
	elif not main.world_state.demes.is_empty():
		var did := str(main.world_state.demes.keys()[0])
		main.hud.select_deme(did)
		main.world_renderer.selected_deme_id = did
	await _wait_and_save(main, "screenshot_rift_savanna.png")

	# 2. screenshot_darwin_archipelago.png (5 generations)
	main.load_preset("preset-darwin-archipelago")
	for _g in range(5):
		main.step_generation()
	main.hud.refresh(main.world_state)
	await _wait_and_save(main, "screenshot_darwin_archipelago.png")

	# 3. screenshot_finite_island.png (4 generations, map legend open + ecological lens)
	main.load_preset("preset-finite-island")
	for _g in range(4):
		main.step_generation()
	main.hud.refresh(main.world_state)
	main.hud._on_lens_pressed("health")
	if not main.hud._legend_panel.visible:
		main.hud._on_legend_toggle_pressed()
	await _wait_and_save(main, "screenshot_finite_island.png")

	# Restore biome lens and close legend before modals
	main.hud._on_lens_pressed("biome")
	if main.hud._legend_panel.visible:
		main.hud._on_legend_toggle_pressed()

	# Advance Finite Island a few more turns and trigger a Baldwin & Innovation event so Chronicle and Lineage Tree are rich
	for _g in range(4):
		main.step_generation()
	if not main.world_state.demes.is_empty():
		var first_d: EvoTypes.Deme = main.world_state.demes.values()[0]
		first_d.baldwin_counters[first_d.last_dominant_decision_id] = 8
		first_d.innovation_counter = 1.1
		EvoMilestonePhase.run_milestone_phase(main.world_state, main.lang)
		main.hud.refresh(main.world_state)

	# 4. screenshot_notebook_modal.png
	main.hud.open_notebook_modal()
	await _wait_and_save(main, "screenshot_notebook_modal.png")
	main.hud.notebook_modal.close_modal()

	# 5. screenshot_tree_modal.png (ensure hierarchical child lineage node exists for visual clarity)
	main.load_preset("preset-darwin-archipelago")
	for _g in range(4):
		main.step_generation()
	if main.world_state.demes.has("deme-darwin-founder"):
		var f_deme: EvoTypes.Deme = main.world_state.demes["deme-darwin-founder"]
		if main.world_state.cells.has(f_deme.hex_id):
			(main.world_state.cells[f_deme.hex_id] as EvoTypes.HexCell).deme_ids.erase(f_deme.id)
		var target_cell: EvoTypes.HexCell = main.world_state.cells["0,-2"]
		var prev_occ := target_cell.get_resident_deme_id()
		if prev_occ != "" and prev_occ != f_deme.id and main.world_state.demes.has(prev_occ):
			main.world_state.demes.erase(prev_occ)
		f_deme.hex_id = "0,-2"
		target_cell.set_resident_deme_id(f_deme.id)
		f_deme.isolation_turns = 10
		EvoMilestonePhase.run_milestone_phase(main.world_state, main.lang)
	main.hud.open_tree_modal()
	await _wait_and_save(main, "screenshot_tree_modal.png")
	main.hud.tree_modal.close_modal()

	# 6. screenshot_lab_modal.png
	main.hud.open_lab_modal()
	await _wait_and_save(main, "screenshot_lab_modal.png")
	main.hud.lab_modal.close_modal()

	# 7. screenshot_late_simulation.png (24 generations in Rift Savanna with active pacts, conflicts, and road networks)
	main.load_preset("preset-rift-savanna")
	for _g in range(24):
		main.step_generation()
	main.hud._milestone_banner.visible = false
	main.hud.refresh(main.world_state)
	var best_did: String = ""
	var best_pop: int = -1
	for d_id in main.world_state.demes.keys():
		var d: EvoTypes.Deme = main.world_state.demes[d_id]
		if d.population > best_pop:
			best_pop = d.population
			best_did = str(d_id)
	if best_did != "":
		main.hud.select_deme(best_did)
		main.world_renderer.selected_deme_id = best_did
		main.world_renderer.selected_hex_id = (main.world_state.demes[best_did] as EvoTypes.Deme).hex_id
	await _wait_and_save(main, "screenshot_late_simulation.png")

	main.free()
	EvoDecisionModel.wait_for_workers()
	var cat_path := _tmp_cfg_dir.path_join("user_catalog.json")
	if FileAccess.file_exists(cat_path):
		DirAccess.remove_absolute(cat_path)
	var cfg_path := _tmp_cfg_dir.path_join("settings.json")
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)
	if DirAccess.dir_exists_absolute(_tmp_cfg_dir):
		DirAccess.remove_absolute(_tmp_cfg_dir)
	EvoUserSettings.config_path_override = ""
	quit(0)
