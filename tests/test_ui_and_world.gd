class_name EvoTestUiAndWorld
extends RefCounted


static func run(r) -> void:
	_test_main_scene_and_ui_integration(r)
	_test_bugfix_regressions(r)
	_test_turn_events_and_world_stats(r)
	_test_ux_clarity_stats_lens_and_fx(r)


static func _test_main_scene_and_ui_integration(r) -> void:
	print("-- Testing Main Scene, WorldRenderer & UI Integration --")
	var packed: PackedScene = load("res://scenes/main.tscn")
	r._assert(packed != null, "res://scenes/main.tscn loads as PackedScene")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	r.root.add_child(main)
	if main.camera == null:
		main._ready()

	r._assert(main.camera != null, "main.camera exists and is configured")
	r._assert(main.world_renderer != null, "main.world_renderer exists and is configured")
	r._assert(main.hud != null, "main.hud exists and is configured")
	r._assert(main.world_state != null, "main.world_state initialized on startup")

	# Verify all 52 PNG files in res://assets/sprites/ and ImageTexture generation
	EvoPixelArtGen.ensure_all_assets()
	var total_sprites: int = 0
	for s_name in EvoPixelArtGen.TERRAIN_SPRITES:
		var path := "res://assets/sprites/terrain/%s.png" % s_name
		r._assert(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "Terrain PNG exists: %s" % path)
		var tex := EvoPixelArtGen.get_texture(s_name)
		r._assert(tex != null and tex.get_width() > 0, "Valid ImageTexture for %s" % s_name)
		total_sprites += 1
	for s_name in EvoPixelArtGen.VILLAGE_SPRITES:
		var path := "res://assets/sprites/villages/%s.png" % s_name
		r._assert(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "Village PNG exists: %s" % path)
		var tex := EvoPixelArtGen.get_texture(s_name)
		r._assert(tex != null and tex.get_width() > 0, "Valid ImageTexture for %s" % s_name)
		total_sprites += 1
	for s_name in EvoPixelArtGen.UI_SPRITES:
		var path := "res://assets/sprites/ui/%s.png" % s_name
		r._assert(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "UI PNG exists: %s" % path)
		var tex := EvoPixelArtGen.get_texture(s_name)
		r._assert(tex != null and tex.get_width() > 0, "Valid ImageTexture for %s" % s_name)
		total_sprites += 1
	var expected_sprites := EvoPixelArtGen.TERRAIN_SPRITES.size() + EvoPixelArtGen.VILLAGE_SPRITES.size() + EvoPixelArtGen.UI_SPRITES.size()
	r._assert(total_sprites == expected_sprites and total_sprites >= 60, "All %d pixel-art sprites verified" % total_sprites)

	# Verify Dual System 1 Decision Models (d3:4b + tev1:4b), Settings Persistence & Dynamic UI Text
	EvoUserSettings.config_path_override = ""
	r._assert(EvoUserSettings.get_config_dir().ends_with("/.config/Evolution"), "Default config dir points to ~/.config/Evolution")
	EvoUserSettings.config_path_override = r._suite_cfg_path
	r._assert(EvoUserSettings.DEFAULT_CONTEXT_LENGTH == 16384, "Default context window size is 16384")
	r._assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-rift-west") == "d3:4b", "deme-rift-west assigned to d3:4b")
	r._assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-rift-east") == "tev1:4b", "deme-rift-east assigned to tev1:4b")
	r._assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-island-1") == "d3:4b", "deme-island-1 assigned to d3:4b")
	r._assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-island-2") == "tev1:4b", "deme-island-2 assigned to tev1:4b")
	var ollama_status := EvoDecisionModel.check_ollama_status()
	r._assert(ollama_status.has("primary_tag") and ollama_status["primary_tag"] == "d3:4b", "Ollama status reports primary System 1 model d3:4b")
	r._assert(ollama_status.has("secondary_tag") and ollama_status["secondary_tag"] == "tev1:4b", "Ollama status reports secondary System 1 model tev1:4b")

	var mock_tags := [
		{"name": "d3:4b", "capabilities": ["decision", "vision"]},
		{"name": "tev1:4b", "capabilities": ["decision"]},
		{"name": "embeddinggemma:latest", "capabilities": ["embedding"]}
	]
	var filtered_dec := EvoOllamaClient.filter_decision_models_from_tags(mock_tags)
	r._assert(filtered_dec.size() == 2 and filtered_dec.has("d3:4b") and filtered_dec.has("tev1:4b"), "filter_decision_models_from_tags returns only models with 'decision' capability")

	var test_cfg_path := ProjectSettings.globalize_path("user://test_evolution_settings.json")
	EvoUserSettings.config_path_override = test_cfg_path
	EvoUserSettings.primary_model = "custom-dec-a:4b"
	EvoUserSettings.secondary_model = "custom-dec-b:4b"
	EvoUserSettings.context_length = 8192
	main.hud._commit_context_window_text("16384")
	r._assert(FileAccess.file_exists(test_cfg_path), "Settings file saved on change")
	EvoUserSettings.primary_model = "d3:4b"
	EvoUserSettings.secondary_model = "tev1:4b"
	EvoUserSettings.context_length = 8192
	EvoUserSettings.load_settings()
	r._assert(EvoUserSettings.primary_model == "custom-dec-a:4b" and EvoUserSettings.secondary_model == "custom-dec-b:4b" and EvoUserSettings.context_length == 16384, "Settings round-trip loads custom models and free-text context window 16384")
	main.hud._apply_decision_models_update()
	r._assert("custom-dec-a:4b" in main.hud._models_diag_lbl.text and "custom-dec-b:4b" in main.hud._models_diag_lbl.text and "16384" in main.hud._models_diag_lbl.text, "HUD diagnostic card updates dynamically with active models and context window")
	r._assert("custom-dec-a:4b" in main.hud._settings_btn.tooltip_text and "custom-dec-b:4b" in main.hud._settings_btn.tooltip_text, "Settings button tooltip updates dynamically when models change")
	var quit_signals: Array[int] = [0]
	main.hud.quit_requested.connect(func() -> void: quit_signals[0] += 1)

	# Verify Ollama Offline blocking popup prevents starting the game and closes app when dismissed
	EvoHudBannersToasts.show_ollama_offline_popup(main.hud)
	r._assert(main.hud._missing_models_modal.visible and main.hud._ollama_startup_blocked, "Ollama offline popup is visible and blocks startup")
	r._assert(main.hud._play_btn.disabled and main.hud._step_btn.disabled, "Play and Step buttons are disabled when Ollama is offline")
	r._assert(not main.hud._missing_models_download_btn.visible, "Download button is hidden when Ollama is offline")
	var blocked_gen := main.world_state.generation
	main.hud._on_play_pressed()
	main.step_generation()
	r._assert(not main.is_playing and main.world_state.generation == blocked_gen, "Game cannot start or advance generation while Ollama is offline")
	main.hud._on_missing_models_skip_pressed()
	r._assert(not main.hud._missing_models_modal.visible and quit_signals[0] == 1, "Closing Ollama offline popup emits quit_requested to close the application")

	# Verify Missing Models popup also blocks startup and closes app if dismissed without downloading
	EvoHudBannersToasts.show_missing_models_popup(main.hud, ["missing-dec:4b"])
	r._assert(main.hud._missing_models_modal.visible and "missing-dec:4b" in main.hud._missing_models_desc_lbl.text, "Missing models popup displays missing model tags at startup")
	r._assert(main.hud._ollama_startup_blocked and main.hud._play_btn.disabled and main.hud._step_btn.disabled, "Missing models popup blocks game startup until downloaded")
	main.hud._on_missing_models_skip_pressed()
	r._assert(not main.hud._missing_models_modal.visible and quit_signals[0] == 2, "Closing missing models popup emits quit_requested")

	# Unblock startup for subsequent UI interaction tests
	main.hud._set_startup_blocked(false)
	DirAccess.remove_absolute(test_cfg_path)
	EvoUserSettings.config_path_override = r._suite_cfg_path
	EvoUserSettings.primary_model = EvoUserSettings.DEFAULT_PRIMARY_MODEL
	EvoUserSettings.secondary_model = EvoUserSettings.DEFAULT_SECONDARY_MODEL
	EvoUserSettings.context_length = EvoUserSettings.DEFAULT_CONTEXT_LENGTH
	main.hud._apply_decision_models_update()

	# Advance generations via main.step_generation()
	var gen_before := main.world_state.generation
	main.step_generation()
	main.step_generation()
	r._assert(main.world_state.generation == gen_before + 2, "main.step_generation() advances world_state generation")
	r._assert(main.world_renderer.world_state == main.world_state, "world_renderer tracks updated world_state")

	# Preset switching
	main.load_preset("preset-darwin-archipelago")
	r._assert(main.world_state.preset_id == "preset-darwin-archipelago", "Switched to preset-darwin-archipelago")
	r._assert(main.world_state.cells.size() == 169, "Darwin preset has 169 cells in main")
	main.step_generation()

	main.load_preset("preset-finite-island")
	r._assert(main.world_state.preset_id == "preset-finite-island", "Switched to preset-finite-island")
	r._assert(main.world_state.cells.size() == 169, "Finite Island preset has 169 cells in main")
	main.step_generation()

	# Language switching
	main._on_language_changed("en")
	r._assert(main.lang == "en", "Language switched to en")
	main._on_language_changed("es")
	r._assert(main.lang == "es", "Language switched back to es")

	# Map lenses switching
	for lens_id in ["food", "health", "diplomacy", "territory", "biome"]:
		main.hud._on_lens_pressed(lens_id)
		r._assert(main.world_renderer.active_lens == lens_id, "Lens switched to %s" % lens_id)

	# Modals opening and closing
	main.hud.open_notebook_modal()
	r._assert(main.hud.notebook_modal.visible, "Notebook modal opens cleanly")
	main.hud.notebook_modal.close_modal()
	r._assert(not main.hud.notebook_modal.visible, "Notebook modal closes cleanly")

	main.hud.open_tree_modal()
	r._assert(main.hud.tree_modal.visible, "Tree modal opens cleanly")
	main.hud.tree_modal.close_modal()
	r._assert(not main.hud.tree_modal.visible, "Tree modal closes cleanly")

	main.hud.open_lab_modal()
	r._assert(main.hud.lab_modal.visible, "Lab modal opens cleanly")
	main.hud.lab_modal.close_modal()
	r._assert(not main.hud.lab_modal.visible, "Lab modal closes cleanly")

	# Environmental tools via HUD and MainController
	main.world_state.selective_pressure_points = 100
	main.hud._on_tool_button_pressed("set_biome")
	main.hud._on_sub_mode_selected("tundra")
	main._on_world_hex_clicked("0,0", MOUSE_BUTTON_LEFT)
	r._assert((main.world_state.cells["0,0"] as EvoTypes.HexCell).biome == "tundra", "Environmental tool set_biome applied via main controller")

	main.hud._on_tool_button_pressed("adjust_altitude")
	main.hud._on_sub_mode_selected("raise")
	var alt_before := (main.world_state.cells["0,0"] as EvoTypes.HexCell).altitude
	main._on_world_hex_clicked("0,0", MOUSE_BUTTON_LEFT)
	r._assert((main.world_state.cells["0,0"] as EvoTypes.HexCell).altitude > alt_before, "Environmental tool adjust_altitude applied via main controller")

	main.hud._on_tool_button_pressed("adjust_carrying_capacity")
	main.hud._on_sub_mode_selected("enrich")
	main._on_world_hex_clicked("0,0", MOUSE_BUTTON_LEFT)

	var sea_before := main.world_state.sea_level
	main._on_sea_level_change_requested(0.05)
	r._assert(is_equal_approx(main.world_state.sea_level, sea_before + 0.05), "Sea level tool applied via main controller")

	# Verify Expanded Hex Size (>= 220.0), >= 2x Village/Villager Scales & Lifecycle Anti-Overlap
	r._assert(HexMath.HEX_SIZE >= 220.0, "HexMath.HEX_SIZE expanded to >= 220.0 (is %.1f)" % HexMath.HEX_SIZE)
	var b_layout := main.world_renderer._get_village_building_layout(2, true, 2, "cooperate")
	r._assert(b_layout.size() >= 3 and float(b_layout[0]["scale"]) >= 2.0, "Village building scale is >= 2.0x baseline")
	main.load_preset("preset-rift-savanna")
	main.world_renderer._rebuild()
	var moving_props := main.world_renderer._collect_moving_props()
	r._assert(not moving_props.is_empty() and moving_props[0].rect.size.y >= 28.0, "Inhabitant/campfire moving props are >= 2x baseline size")

	# Verify disused_connections lifecycle aging and HUD inspector zero-information-loss
	var life_state := EvoCatalog.create_preset_world("preset-finite-island", "es")
	var ld1: EvoTypes.Deme = life_state.demes["deme-island-1"]
	var ld2: EvoTypes.Deme = life_state.demes["deme-island-2"]
	(life_state.cells[ld1.hex_id] as EvoTypes.HexCell).deme_ids.erase(ld1.id)
	(life_state.cells[ld2.hex_id] as EvoTypes.HexCell).deme_ids.erase(ld2.id)
	ld1.hex_id = "0,0"
	ld2.hex_id = "1,0"
	(life_state.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([ld1.id])
	(life_state.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([ld2.id])
	var coop_fl := EvoTypes.HexEdgeFlow.new()
	coop_fl.from_hex_id = "0,0"
	coop_fl.to_hex_id = "1,0"
	coop_fl.flow_type = "cooperate"
	coop_fl.from_deme_id = "deme-island-1"
	coop_fl.to_deme_id = "deme-island-2"
	life_state.active_flows.append(coop_fl)
	EvoEnvPhase.run_environmental_phase(life_state, "es")
	r._assert(life_state.disused_connections.size() == 1 and int(life_state.disused_connections[0].get("age", -1)) == 0, "Active friendly flow recorded into disused_connections with age 0")
	# Force raid so the friendly flow is severed
	ld1.chosen_action = EvoActionMenu.option("raid", ld2.id)
	ld2.chosen_action = EvoActionMenu.option("forage")
	EvoBiophysPhase.run_biophysical_phase(life_state, "es")
	r._assert(life_state.disused_connections.size() == 1 and int(life_state.disused_connections[0].get("age", 0)) == 1, "Severed friendly flow ages to 1 in biophys_phase")
	main.hud.set_world_state(life_state)
	var rel_lines := main.hud._build_deme_relations_lines(ld1)
	r._assert(rel_lines.size() >= 1, "HUD inspector preserves active/severed inter-hex relations without information loss")

	# Verify Right Inspector Village Selector & Cycling
	r._assert(main.hud._village_selector_opt != null and main.hud._village_selector_opt.item_count == life_state.demes.size(), "Right Inspector village selector populated with all demes")
	var prev_sel_deme := main.hud._selected_deme_id
	main.hud._on_village_cycle_pressed(1)
	r._assert(main.hud._selected_deme_id != prev_sel_deme, "Right Inspector village cycle button advances selected village")

	# Verify clicking an empty hex in inspect mode clears selected deme and switches inspector tab to habitat
	main.load_preset("preset-rift-savanna")
	main.hud._on_tool_button_pressed("inspect")
	var empty_hex_id := ""
	for hid in main.world_state.cells.keys():
		if (main.world_state.cells[hid] as EvoTypes.HexCell).deme_ids.is_empty():
			empty_hex_id = str(hid)
			break
	main._on_world_hex_clicked(empty_hex_id, MOUSE_BUTTON_LEFT)
	r._assert(main.world_renderer.selected_deme_id == "" and main.hud._selected_deme_id == "" and main.hud._inspector_tab == "habitat", "Clicking empty hex in inspect mode clears selected deme and switches inspector tab to habitat")

	main.free()


static func _test_bugfix_regressions(r) -> void:
	print("-- Testing Bugfix Regressions --")
	# 1. strip_migration_suffix preserves root deme IDs and strips migration/warband suffixes
	r._assert(EvoSettlementPhase.strip_migration_suffix("deme-rift-west") == "deme-rift-west", "strip_migration_suffix preserves 'deme-rift-west'")
	r._assert(EvoSettlementPhase.strip_migration_suffix("deme-rift-west-m3-0_0") == "deme-rift-west", "strip_migration_suffix strips '-m3-0_0' suffix")
	r._assert(EvoSettlementPhase.strip_migration_suffix("deme-rift-west-w2") == "deme-rift-west", "strip_migration_suffix strips '-w2' suffix")

	# 2. resolve_deme_decision_model_tag assigns deme-darwin-rival to secondary model
	r._assert(EvoDecisionModel.resolve_deme_decision_model_tag("deme-darwin-rival", "d3:4b", "tev1:4b") == "tev1:4b", "resolve_deme_decision_model_tag assigns 'deme-darwin-rival' to secondary model 'tev1:4b'")

	# 3. EvoActionMenu.is_passable rejects altitude > 0.85 (0.88 mountain barrier)
	var mountain_cell := EvoTypes.HexCell.new()
	mountain_cell.id = "0,1"
	mountain_cell.biome = "mountain"
	mountain_cell.altitude = 0.88
	mountain_cell.carrying_capacity = 100.0
	r._assert(not EvoActionMenu.is_passable(mountain_cell), "EvoActionMenu.is_passable rejects mountain barrier with altitude 0.88 (> 0.85)")

	# 4. validate_and_balance_thermodynamics preserves positive ecological_impact minus excess when target_metabolic > 1.0
	var high_vec := EvoTypes.BiophysicalVector.new(0.0, 1.0, 0.30, 1.0, 1.0, 0.0)
	# A+ = 3.0 -> required_cost = 0.5 * (3.0 - 0.60) = 1.20 -> target_metabolic = 1.20 -> excess = 0.20 -> ecological_impact = 0.30 - 0.20 = 0.10
	var balanced_high := EvoThermodynamics.validate_and_balance_thermodynamics(high_vec, false)
	r._assert(is_equal_approx(balanced_high.metabolic_cost, 1.0), "validate_and_balance_thermodynamics caps metabolic_cost at 1.0 when target_metabolic > 1.0")
	r._assert(is_equal_approx(balanced_high.ecological_impact, 0.10), "validate_and_balance_thermodynamics preserves positive ecological_impact minus excess (0.30 - 0.20 = 0.10)")

	# 5. EvoLabModal.refresh() preserves checked strategy traits in strategy_trait_checks
	var state := EvoCatalog.create_preset_world("preset-rift-savanna", "es")
	var lab := EvoLabModal.new()
	r.root.add_child(lab)
	if lab._title_label == null:
		lab._ready()
	lab.open_modal(state, "es")
	lab._switch_tab("strategies")
	lab._start_new_item()
	(lab.strategy_trait_checks["bio-thermal-tolerance"] as CheckBox).button_pressed = true
	(lab.strategy_trait_checks["bio-social-instinct"] as CheckBox).button_pressed = true
	lab.refresh(state)
	r._assert((lab.strategy_trait_checks["bio-thermal-tolerance"] as CheckBox).button_pressed and (lab.strategy_trait_checks["bio-social-instinct"] as CheckBox).button_pressed, "EvoLabModal.refresh() preserves checked strategy traits in strategy_trait_checks")
	lab.free()

	# 6. EvoUiStyle.get_village_tier_label matches Deme.get_village_tier() across all 4 tiers (I..IV)
	var tier_cases := [
		{"pop": 65, "merged": 0, "def": 0, "union": "", "tier": 1, "es": "I · Campamento", "en": "I · Camp"},
		{"pop": 90, "merged": 0, "def": 1, "union": "", "tier": 2, "es": "II · Aldea", "en": "II · Village"},
		{"pop": 140, "merged": 0, "def": 0, "union": "", "tier": 2, "es": "II · Aldea", "en": "II · Village"},
		{"pop": 185, "merged": 0, "def": 1, "union": "", "tier": 3, "es": "III · Villa", "en": "III · Town"},
		{"pop": 255, "merged": 0, "def": 0, "union": "", "tier": 3, "es": "III · Villa", "en": "III · Town"},
		{"pop": 295, "merged": 0, "def": 0, "union": "union-a-b", "tier": 4, "es": "IV · Metrópolis", "en": "IV · Metropolis"},
		{"pop": 395, "merged": 0, "def": 0, "union": "", "tier": 4, "es": "IV · Metrópolis", "en": "IV · Metropolis"}
	]
	for tc in tier_cases:
		var td := EvoTypes.Deme.new()
		td.population = int(tc["pop"])
		td.merged_count = int(tc["merged"])
		td.defense_tier = int(tc["def"])
		td.walled_union_id = str(tc["union"])
		var lbl_es := EvoUiStyle.get_village_tier_label(td.population, "es", td.merged_count, td.defense_tier, td.walled_union_id)
		var lbl_en := EvoUiStyle.get_village_tier_label(td.population, "en", td.merged_count, td.defense_tier, td.walled_union_id)
		r._assert(
			td.get_village_tier() == int(tc["tier"]) and lbl_es == str(tc["es"]) and lbl_en == str(tc["en"]) and lbl_es.begins_with(td.get_village_roman() + " · "),
			"EvoUiStyle.get_village_tier_label matches Deme.get_village_tier() for tier %d (pop=%d, def=%d, union=%s)" % [int(tc["tier"]), td.population, td.defense_tier, td.walled_union_id]
		)

	# 7. max_rural quota enforcement releases excess rural hexes when a deme drops in tier
	var state_quota := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	var q_deme: EvoTypes.Deme = state_quota.demes["deme-rift-west"]
	var q_other: EvoTypes.Deme = state_quota.demes["deme-rift-east"]
	(state_quota.cells[q_deme.hex_id] as EvoTypes.HexCell).deme_ids.erase(q_deme.id)
	(state_quota.cells[q_other.hex_id] as EvoTypes.HexCell).deme_ids.erase(q_other.id)
	q_deme.hex_id = "0,0"
	q_other.hex_id = "0,4"
	(state_quota.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([q_deme.id])
	(state_quota.cells["0,4"] as EvoTypes.HexCell).deme_ids.assign([q_other.id])
	q_deme.population = 400
	q_deme.defense_tier = 2
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		var nc: EvoTypes.HexCell = state_quota.cells[nid]
		nc.biome = "savanna"
		nc.altitude = 0.45
		nc.current_resources = 500.0
	EvoRuralHinterland.claim_hinterlands(state_quota)
	var count_t4 := 0
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		if (state_quota.cells[nid] as EvoTypes.HexCell).owner_deme_id == q_deme.id:
			count_t4 += 1
	r._assert(count_t4 == 4, "Tier 4 deme claims 4 rural hinterland hexes")

	q_deme.population = 180
	q_deme.defense_tier = 1
	EvoRuralHinterland.claim_hinterlands(state_quota)
	var count_t3 := 0
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		if (state_quota.cells[nid] as EvoTypes.HexCell).owner_deme_id == q_deme.id:
			count_t3 += 1
	r._assert(q_deme.get_village_tier() == 3 and count_t3 == 2, "Dropping to Tier 3 releases excess rural hexes down to max_rural == 2")

	q_deme.population = 70
	q_deme.defense_tier = 0
	EvoRuralHinterland.claim_hinterlands(state_quota)
	var count_t1 := 0
	for nid in HexMath.get_neighbor_ids(0, 0, state_quota.cells):
		if (state_quota.cells[nid] as EvoTypes.HexCell).owner_deme_id == q_deme.id:
			count_t1 += 1
	r._assert(q_deme.get_village_tier() == 1 and count_t1 == 0, "Dropping to Tier 1 releases all rural hexes (max_rural == 0)")

	# 8. Flood/mountain relocation clears non-adjacent rural hexes and revalidates walled_union_id
	var state_reloc := EvoPresets.create_preset_world("preset-rift-savanna", "en")
	state_reloc.unlimited_pressure_mode = true
	var r_d1: EvoTypes.Deme = state_reloc.demes["deme-rift-west"]
	var r_d2: EvoTypes.Deme = state_reloc.demes["deme-rift-east"]
	(state_reloc.cells[r_d1.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_d1.id)
	(state_reloc.cells[r_d2.hex_id] as EvoTypes.HexCell).deme_ids.erase(r_d2.id)
	r_d1.hex_id = "0,0"
	r_d2.hex_id = "1,0"
	(state_reloc.cells["0,0"] as EvoTypes.HexCell).deme_ids.assign([r_d1.id])
	(state_reloc.cells["1,0"] as EvoTypes.HexCell).deme_ids.assign([r_d2.id])
	r_d1.population = 180
	r_d2.population = 180
	r_d1.defense_tier = 1
	r_d2.defense_tier = 1
	r_d1.walled_union_id = "union-reloc-test"
	r_d2.walled_union_id = "union-reloc-test"
	EvoTypes.get_relation(state_reloc, r_d1.id, r_d2.id).pact_turns = 4
	for nid in HexMath.get_neighbor_ids(0, 0, state_reloc.cells):
		if nid != "1,0":
			var nc: EvoTypes.HexCell = state_reloc.cells[nid]
			nc.biome = "ocean"
			nc.altitude = 0.05
	var escape_cell: EvoTypes.HexCell = state_reloc.cells["-1,0"]
	escape_cell.biome = "savanna"
	escape_cell.altitude = 0.45
	escape_cell.current_resources = 500.0
	var far_rural_cell: EvoTypes.HexCell = state_reloc.cells["0,1"]
	far_rural_cell.biome = "savanna"
	far_rural_cell.altitude = 0.45
	far_rural_cell.current_resources = 10.0
	far_rural_cell.owner_deme_id = r_d1.id
	far_rural_cell.land_use = "crops"
	EvoTurnEngine.apply_set_biome(state_reloc, ["0,0"], "high_mountain", "en")
	r._assert(r_d1.hex_id == "-1,0", "Displaced deme relocates from high_mountain (0,0) to richest passable neighbor (-1,0)")
	r._assert(far_rural_cell.owner_deme_id == "" and far_rural_cell.land_use == "wild", "Relocation clears rural hex (0,1) that is no longer at hex_distance == 1 from (-1,0)")
	r._assert(r_d1.walled_union_id == "" and r_d2.walled_union_id == "", "Relocation out of adjacency dissolves walled_union_id on both partners")

	# 9. Seeded Ollama result application on next generation
	var state_pf := EvoPresets.create_preset_world("preset-rift-savanna", "es")
	var pf_west: EvoTypes.Deme = state_pf.demes["deme-rift-west"]
	EvoOllamaClient.seed_deme_result(pf_west.id, {
		"probabilities": {"intensify": 0.99, "forage": 0.01},
		"dominant_decision_id": "intensify",
		"confidence": 0.93
	})
	EvoDecisionModel.evaluate_all_demes(state_pf, "es", false)
	r._assert(is_equal_approx(pf_west.last_confidence, 0.93) and str(pf_west.chosen_action.get("type", "")) in ["intensify", "forage"], "evaluate_all_demes applies seeded Ollama result cleanly")
	EvoOllamaClient.clear_cache()


static func _test_turn_events_and_world_stats(r) -> void:
	print("-- Testing Turn Events Queue, World Stats History & Serialization --")
	var state := EvoPresets.create_preset_world("preset-rift-savanna", "en", "strat-war", "strat-cooperation")
	var total_events_seen := 0
	var all_events_valid := true
	for g_i in range(8):
		if g_i == 0 and state.demes.has("deme-rift-west"):
			var dw: EvoTypes.Deme = state.demes["deme-rift-west"]
			dw.energy_reserves = 200.0
			dw.chosen_action = EvoActionMenu.option("fortify")
		EvoTurnEngine.advance_generation(state, "en")
		total_events_seen += state.turn_events.size()
		for ev in state.turn_events:
			var ev_type := str(ev["type"])
			var from_hex := str(ev["from_hex"])
			var to_hex := str(ev["to_hex"])
			if not (ev_type in EvoTypes.EVENT_TYPES) or not state.cells.has(from_hex) or not state.cells.has(to_hex):
				all_events_valid = false
				break
	r._assert(total_events_seen > 0, "Multi-turn simulation populates state.turn_events (total=%d)" % total_events_seen)
	r._assert(all_events_valid, "All turn_events entries have canonical type in EvoTypes.EVENT_TYPES and valid hex IDs")
	r._assert(state.stats_history.size() == 8, "EvoTurnEngine.advance_generation records per-generation snapshot in state.stats_history")

	# Verify EvoEnvPhase.run_environmental_phase clears turn_events
	EvoTypes.push_event(state, "pact", "0,0", "1,0", "deme-rift-west", "deme-rift-east", 2.0, 0)
	r._assert(not state.turn_events.is_empty(), "EvoTypes.push_event appends to state.turn_events")
	EvoEnvPhase.run_environmental_phase(state, "en")
	r._assert(state.turn_events.is_empty(), "EvoEnvPhase.run_environmental_phase clears state.turn_events")

	# Verify STATS_HISTORY_LIMIT cap
	for g_idx in range(20, 20 + EvoTypes.STATS_HISTORY_LIMIT + 15):
		state.generation = g_idx
		EvoTypes.record_turn_stats(state)
	r._assert(state.stats_history.size() == EvoTypes.STATS_HISTORY_LIMIT, "EvoTypes.record_turn_stats caps state.stats_history at STATS_HISTORY_LIMIT (%d)" % EvoTypes.STATS_HISTORY_LIMIT)

	# Verify JSON round-trip preserves stats_history and new Deme fields
	var sample_deme: EvoTypes.Deme = state.demes.values()[0]
	sample_deme.infection_turns = 2
	sample_deme.immunity_turns = 5
	sample_deme.last_food_intake = 42.5
	sample_deme.last_food_need = 36.25
	sample_deme.last_population_delta = -7
	var json_str := JSON.stringify(state.to_dict())
	var parsed: Dictionary = JSON.parse_string(json_str)
	var restored := EvoTypes.WorldState.from_dict(parsed)
	r._assert(restored.stats_history.size() == state.stats_history.size(), "WorldState JSON round-trip preserves stats_history")
	var restored_deme: EvoTypes.Deme = restored.demes[sample_deme.id]
	r._assert(
		restored_deme.infection_turns == 2
		and restored_deme.immunity_turns == 5
		and is_equal_approx(restored_deme.last_food_intake, 42.5)
		and is_equal_approx(restored_deme.last_food_need, 36.25)
		and restored_deme.last_population_delta == -7,
		"Deme JSON round-trip preserves infection_turns, immunity_turns, last_food_intake, last_food_need, and last_population_delta"
	)


static func _test_ux_clarity_stats_lens_and_fx(r) -> void:
	print("-- Testing Event Replay FX, Live Chronicle Feed, Stats Strip & HUD Readability --")
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: EvoMainController = packed.instantiate() as EvoMainController
	main.quit_on_close_enabled = false
	r.root.add_child(main)
	if main.camera == null:
		main._ready()

	main.load_preset("preset-rift-savanna")
	main.hud._set_startup_blocked(false)

	r._assert(main.hud._stats_strip_panel != null and main.hud._stats_strip_panel.visible, "HUD A-vs-B stats strip panel exists and is visible")
	r._assert(main.hud._event_feed_panel != null and main.hud._event_feed_panel.visible, "HUD live chronicle feed panel exists and is visible")

	var saw_fx_active := false
	for g_i in range(6):
		if g_i == 0 and main.world_state.demes.has("deme-rift-west"):
			var dw: EvoTypes.Deme = main.world_state.demes["deme-rift-west"]
			dw.population = 90
			dw.defense_tier = 1
			dw.energy_reserves = 200.0
			dw.chosen_action = EvoActionMenu.option("fortify")
		main.step_generation()
		main.world_renderer._process(0.016)
		if not main.world_state.turn_events.is_empty() and not main.world_renderer._fx_active.is_empty():
			saw_fx_active = true
	r._assert(saw_fx_active, "world_renderer._fx_active is populated when turn_events is non-empty")

	# Ensure chronicle has at least one entry and test clicking a live chronicle feed row button
	var feed_btn: Button = null
	for child in main.hud._event_feed_vbox.get_children():
		if child is Button:
			feed_btn = child as Button
			break
	r._assert(feed_btn != null, "Live chronicle feed vbox contains clickable Button rows")
	var latest_entry: EvoTypes.ChronicleEntry = main.world_state.chronicle.back()
	main.world_renderer.selected_hex_id = "0,0"
	feed_btn.pressed.emit()
	r._assert(main.world_renderer.selected_hex_id == latest_entry.hex_id, "Clicking live chronicle feed button jumps world_renderer.selected_hex_id to entry hex (%s)" % latest_entry.hex_id)

	# Verify cycling speeds across 0, 1, 2
	r._assert(main.speed_index == 1 and EvoMainController.STEP_INTERVALS == [4.0, 2.0, 0.6], "Default speed_index is 1 with STEP_INTERVALS = [4.0, 2.0, 0.6]")
	main.hud._on_speed_pressed()
	r._assert(main.speed_index == 2, "First speed button press advances speed_index to 2 (0.6s)")
	main.hud._on_speed_pressed()
	r._assert(main.speed_index == 0, "Second speed button press wraps speed_index to 0 (4.0s)")
	main.hud._on_speed_pressed()
	r._assert(main.speed_index == 1, "Third speed button press returns speed_index to 1 (2.0s)")

	# Verify closing _milestone_banner when macro_outcome_type != "" does not re-show on subsequent refresh
	main.world_state.macro_outcome_type = "ecological_equilibrium"
	main.world_state.macro_outcome_title = "Equilibrium Reached"
	main.world_state.macro_outcome_summary = "Populations stabilized."
	main.hud.refresh(main.world_state)
	r._assert(main.hud._milestone_banner.visible, "Milestone banner appears when macro_outcome_type is first set")
	main.hud._milestone_banner.visible = false
	main.hud.refresh(main.world_state)
	r._assert(not main.hud._milestone_banner.visible, "Closed macro outcome banner does not re-open on subsequent hud.refresh() for the same macro_outcome_type")

	# Verify full-map camera zoom-out (MIN_ZOOM <= 0.15 and fit_full_map / apply_preset("fit")) and overlay refresh
	r._assert(EvoCameraController.MIN_ZOOM <= 0.15, "Camera MIN_ZOOM allows full-map zoom-out (%.2f <= 0.15)" % EvoCameraController.MIN_ZOOM)
	main.camera.apply_preset("fit")
	r._assert(main.camera._target_zoom < 0.25 and main.camera._target_pan == Vector2.ZERO, "Camera apply_preset('fit') zooms out to fit full map (%.3f) and centers on Vector2.ZERO" % main.camera._target_zoom)
	main.world_renderer._dirty = false
	main.world_renderer._overlay_dirty = false
	main.world_renderer.refresh_overlay(main.world_state)
	r._assert(main.world_renderer._overlay_dirty and not main.world_renderer._dirty, "world_renderer.refresh_overlay marks only _overlay_dirty without triggering full column/prop _dirty rebuild")
	main.hud.refresh_inspector_only(main.world_state)

	main.free()

	# Verify rural hinterland preservation when settling onto an open frontier
	var bugs_state := EvoPresets.create_preset_world("preset-rift-savanna", "es", "strat-cooperation", "strat-war")
	for cid in bugs_state.cells.keys():
		var c: EvoTypes.HexCell = bugs_state.cells[cid]
		c.deme_ids.clear()
		c.owner_deme_id = ""
		c.land_use = "wild"
	var d_a: EvoTypes.Deme = bugs_state.demes["deme-rift-west"].duplicate_deme()
	var d_b_tpl: EvoTypes.Deme = bugs_state.demes["deme-rift-east"].duplicate_deme()
	bugs_state.demes.clear()
	d_a.id = "deme-a-main"
	d_a.hex_id = "-2,1"
	d_a.population = 420
	d_a.defense_tier = 2
	d_a.energy_reserves = 210.0
	bugs_state.demes[d_a.id] = d_a
	(bugs_state.cells["-2,1"] as EvoTypes.HexCell).deme_ids.assign([d_a.id])
	var crop_coords: Array[String] = ["-2,0", "-3,1", "-3,2", "-2,2"]
	for cc in crop_coords:
		var ccell: EvoTypes.HexCell = bugs_state.cells[cc]
		ccell.biome = "savanna"
		ccell.altitude = 0.42
		ccell.owner_deme_id = d_a.id
		ccell.land_use = "crops"
	var db := d_b_tpl.duplicate_deme()
	db.id = "deme-b-1"
	db.hex_id = "1,0"
	db.population = 120
	db.defense_tier = 1
	db.energy_reserves = 120.0
	bugs_state.demes[db.id] = db
	(bugs_state.cells[db.hex_id] as EvoTypes.HexCell).deme_ids.assign([db.id])
	d_a.chosen_action = EvoActionMenu.option("settle", "-1,1")
	db.chosen_action = EvoActionMenu.option("forage")
	EvoBiophysPhase.run_biophysical_phase(bugs_state, "es")
	var budded_safe := false
	for did in bugs_state.demes.keys():
		var d: EvoTypes.Deme = bugs_state.demes[did]
		if d.lineage_id == d_a.lineage_id and d.id != d_a.id and d.hex_id == "-1,1":
			budded_safe = true
	var crops_kept := 0
	for cc in crop_coords:
		var ccell: EvoTypes.HexCell = bugs_state.cells[cc]
		if ccell.owner_deme_id == d_a.id and ccell.land_use == "crops" and ccell.deme_ids.is_empty():
			crops_kept += 1
	r._assert(budded_safe and crops_kept == 4, "City settles new camp on open neighbor (-1,1) while keeping all 4 crops intact")
