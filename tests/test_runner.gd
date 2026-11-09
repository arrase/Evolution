extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _suite_cfg_dir: String = ""
var _suite_cfg_path: String = ""


func _init() -> void:
	_suite_cfg_dir = "/tmp/evolution_test_suite_%d" % Time.get_ticks_usec()
	_suite_cfg_path = _suite_cfg_dir.path_join("settings.json")
	EvoUserSettings.config_path_override = _suite_cfg_path
	print("=== EVOLUTION GODOT 4 CORE SIMULATION TEST SUITE ===")
	EvoTestCoreDomain.run(self)
	EvoTestCognitiveOllama.run(self)
	EvoTestEngineBiophys.run(self)
	EvoTestUiAndWorld.run(self)

	EvoDecisionModel.wait_for_workers()
	var suite_catalog_path := _suite_cfg_dir.path_join("user_catalog.json")
	if FileAccess.file_exists(suite_catalog_path):
		DirAccess.remove_absolute(suite_catalog_path)
	if FileAccess.file_exists(_suite_cfg_path):
		DirAccess.remove_absolute(_suite_cfg_path)
	if DirAccess.dir_exists_absolute(_suite_cfg_dir):
		DirAccess.remove_absolute(_suite_cfg_dir)
	EvoUserSettings.config_path_override = ""
	print("====================================================")
	print("PASSED: %d | FAILED: %d" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] " + msg)
