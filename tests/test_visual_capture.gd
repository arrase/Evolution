extends SceneTree

const OUTPUT_DIR: String = "/home/arrase/Develop/Evolution/docs/images"


func _init() -> void:
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


func _run_captures() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	root.add_child(main)
	for _i in range(5):
		await process_frame

	main.hud._startup_models_checked = true
	if main.hud._missing_models_modal != null:
		main.hud._missing_models_modal.visible = false
	main._on_language_changed("en")

	# 1. screenshot_rift_savanna.png (6 generations, village selected)
	main.load_preset("preset-rift-savanna")
	main.world_state.use_live_decision_models = false
	for _g in range(6):
		main.step_generation()
	main.world_state.use_live_decision_models = true
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
	main.world_state.use_live_decision_models = false
	for _g in range(5):
		main.step_generation()
	main.world_state.use_live_decision_models = true
	main.hud.refresh(main.world_state)
	await _wait_and_save(main, "screenshot_darwin_archipelago.png")

	# 3. screenshot_finite_island.png (4 generations, map legend open + ecological lens)
	main.load_preset("preset-finite-island")
	main.world_state.use_live_decision_models = false
	for _g in range(4):
		main.step_generation()
	main.world_state.use_live_decision_models = true
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
	main.world_state.use_live_decision_models = false
	for _g in range(4):
		main.step_generation()
	main.world_state.use_live_decision_models = true
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
	main.world_state.use_live_decision_models = false
	for _g in range(4):
		main.step_generation()
	main.world_state.use_live_decision_models = true
	if main.world_state.demes.has("deme-darwin-founder"):
		var f_deme: EvoTypes.Deme = main.world_state.demes["deme-darwin-founder"]
		f_deme.hex_id = "0,-2"
		f_deme.isolation_turns = 10
		EvoMilestonePhase.run_milestone_phase(main.world_state, main.lang)
	main.hud.open_tree_modal()
	await _wait_and_save(main, "screenshot_tree_modal.png")
	main.hud.tree_modal.close_modal()

	# 6. screenshot_lab_modal.png
	main.hud.open_lab_modal()
	await _wait_and_save(main, "screenshot_lab_modal.png")
	main.hud.lab_modal.close_modal()

	# 7. screenshot_late_simulation.png (56 generations in Rift Savanna to verify clean road lifecycle and late-game UI polish)
	main.load_preset("preset-rift-savanna")
	main.world_state.use_live_decision_models = false
	for _g in range(56):
		main.step_generation()
	main.world_state.use_live_decision_models = true
	main.hud._milestone_banner.visible = false
	main.hud.refresh(main.world_state)
	if main.world_state.demes.has("deme-rift-east"):
		main.hud.select_deme("deme-rift-east")
		main.world_renderer.selected_deme_id = "deme-rift-east"
		main.world_renderer.selected_hex_id = (main.world_state.demes["deme-rift-east"] as EvoTypes.Deme).hex_id
	elif not main.world_state.demes.is_empty():
		var did := str(main.world_state.demes.keys()[0])
		main.hud.select_deme(did)
		main.world_renderer.selected_deme_id = did
	await _wait_and_save(main, "screenshot_late_simulation.png")

	main.free()
	EvoDecisionModel.wait_for_workers()
	quit(0)
