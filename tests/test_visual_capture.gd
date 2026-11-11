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
	for _i in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var img: Image = root.get_texture().get_image()
	var full_path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = img.save_png(full_path)
	if err == OK:
		print("[CAPTURE OK] %s (%dx%d)" % [full_path, img.get_width(), img.get_height()])
	else:
		printerr("[CAPTURE FAIL] %s (err=%d)" % [full_path, err])


func _step_sync(main: EvoMainController, count: int) -> void:
	for _g in range(count):
		EvoOllamaClient.clear_cache()
		main.step_generation()


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
	_step_sync(main, 6)
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
	_step_sync(main, 5)
	main.hud.refresh(main.world_state)
	await _wait_and_save(main, "screenshot_darwin_archipelago.png")

	# 3. screenshot_finite_island.png (4 generations, map legend open + ecological lens)
	main.load_preset("preset-finite-island")
	_step_sync(main, 4)
	main.hud.refresh(main.world_state)
	main.hud._on_lens_pressed("health")
	if not main.hud._legend_panel.visible:
		main.hud._on_legend_toggle_pressed()
	await _wait_and_save(main, "screenshot_finite_island.png")

	# Restore biome lens and close legend before modals
	main.hud._on_lens_pressed("biome")
	if main.hud._legend_panel.visible:
		main.hud._on_legend_toggle_pressed()

	# Advance Finite Island a few more turns and trigger a Baldwin & Speciation event so Chronicle and Lineage Tree are rich
	_step_sync(main, 4)
	if not main.world_state.demes.is_empty():
		var first_d: EvoTypes.Deme = main.world_state.demes.values()[0]
		first_d.baldwin_counters["fortify"] = 8
		first_d.innovation_counter = 1.1
		EvoMilestonePhase.run_milestone_phase(main.world_state, main.lang)
		main.hud.refresh(main.world_state)

	# 4. screenshot_notebook_modal.png
	main.hud.open_notebook_modal()
	await _wait_and_save(main, "screenshot_notebook_modal.png")
	main.hud.notebook_modal.close_modal()

	# 5. screenshot_tree_modal.png (ensure hierarchical child lineage node exists for visual clarity)
	main.load_preset("preset-darwin-archipelago")
	_step_sync(main, 4)
	if main.world_state.demes.has("deme-darwin-founder"):
		var f_deme: EvoTypes.Deme = main.world_state.demes["deme-darwin-founder"]
		if main.world_state.cells.has(f_deme.hex_id):
			(main.world_state.cells[f_deme.hex_id] as EvoTypes.HexCell).deme_ids.erase(f_deme.id)
		f_deme.hex_id = "0,-2"
		f_deme.urban_hex_ids = ["0,-2"]
		(main.world_state.cells["0,-2"] as EvoTypes.HexCell).deme_ids.append(f_deme.id)
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
	_step_sync(main, 24)
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

	# 8. screenshot_lens_diplomacy.png (diplomacy lens + dynamic legend)
	main.hud._on_lens_pressed("diplomacy")
	if not main.hud._legend_panel.visible:
		main.hud._on_legend_toggle_pressed()
	await _wait_and_save(main, "screenshot_lens_diplomacy.png")

	# 9. screenshot_lens_territory.png (territory lens)
	main.hud._on_lens_pressed("territory")
	await _wait_and_save(main, "screenshot_lens_territory.png")

	# 10. screenshot_lens_food.png (food lens)
	main.hud._on_lens_pressed("food")
	await _wait_and_save(main, "screenshot_lens_food.png")

	# 11. screenshot_stats_chart.png (biome lens + A-vs-B history chart drawer open)
	if main.hud._legend_panel.visible:
		main.hud._on_legend_toggle_pressed()
	main.hud._on_lens_pressed("biome")
	main.hud._stats_chart_panel.visible = true
	EvoUiStyle.apply_button_active(main.hud._stats_chart_toggle_btn, true)
	EvoHudStatsStrip.refresh_stats_strip(main.hud)
	await _wait_and_save(main, "screenshot_stats_chart.png")
	main.hud._stats_chart_panel.visible = false
	EvoUiStyle.apply_button_active(main.hud._stats_chart_toggle_btn, false)

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
