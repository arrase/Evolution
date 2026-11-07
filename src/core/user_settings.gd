class_name EvoUserSettings
extends RefCounted

const DEFAULT_PRIMARY_MODEL: String = "d3:4b"
const DEFAULT_SECONDARY_MODEL: String = "tev1:4b"
const DEFAULT_CONTEXT_LENGTH: int = 8192

static var primary_model: String = DEFAULT_PRIMARY_MODEL
static var secondary_model: String = DEFAULT_SECONDARY_MODEL
static var context_length: int = DEFAULT_CONTEXT_LENGTH
static var config_path_override: String = ""


static func get_config_dir() -> String:
	if config_path_override != "":
		return config_path_override.get_base_dir()
	var home := OS.get_environment("HOME")
	if home == "":
		return OS.get_user_data_dir()
	return home.path_join(".config/Evolution")


static func get_config_path() -> String:
	if config_path_override != "":
		return config_path_override
	return get_config_dir().path_join("settings.json")


static func load_settings() -> void:
	var path := get_config_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var data := parsed as Dictionary
		if data.has("primary_model") and str(data["primary_model"]).strip_edges() != "":
			primary_model = str(data["primary_model"]).strip_edges()
		if data.has("secondary_model") and str(data["secondary_model"]).strip_edges() != "":
			secondary_model = str(data["secondary_model"]).strip_edges()
		if data.has("context_length") and int(data["context_length"]) > 0:
			context_length = int(data["context_length"])


static func save_settings() -> void:
	DirAccess.make_dir_recursive_absolute(get_config_dir())
	var file := FileAccess.open(get_config_path(), FileAccess.WRITE)
	if file == null:
		return
	var payload := {
		"primary_model": primary_model,
		"secondary_model": secondary_model,
		"context_length": context_length
	}
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()


static func get_user_catalog_path() -> String:
	return get_config_dir().path_join("user_catalog.json")


static func save_user_catalog(state: EvoTypes.WorldState) -> void:
	if state == null:
		return
	DirAccess.make_dir_recursive_absolute(get_config_dir())
	var file := FileAccess.open(get_user_catalog_path(), FileAccess.WRITE)
	if file == null:
		return
	var strategies_arr: Array = []
	for sid in state.strategies_catalog.keys():
		var strat: EvoTypes.StrategyDef = state.strategies_catalog[sid]
		if strat.origin in ["user", "custom"]:
			strategies_arr.append(strat.to_dict())
	var traits_arr: Array = []
	for tid in state.traits_catalog.keys():
		var tr: EvoTypes.TraitDef = state.traits_catalog[tid]
		if tr.origin in ["user", "custom"]:
			traits_arr.append(tr.to_dict())
	var decisions_arr: Array = []
	for did in state.decisions_catalog.keys():
		var dec: EvoTypes.DecisionDef = state.decisions_catalog[did]
		if dec.origin in ["user", "custom"]:
			decisions_arr.append(dec.to_dict())
	var payload := {
		"strategies": strategies_arr,
		"traits": traits_arr,
		"decisions": decisions_arr
	}
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()


static func load_user_catalog_into(state: EvoTypes.WorldState) -> void:
	if state == null:
		return
	var path := get_user_catalog_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var data := parsed as Dictionary
	if data.has("traits") and data["traits"] is Array:
		for item in data["traits"]:
			if item is Dictionary:
				var tr := EvoTypes.TraitDef.from_dict(item as Dictionary)
				state.traits_catalog[tr.id] = tr
	if data.has("decisions") and data["decisions"] is Array:
		for item in data["decisions"]:
			if item is Dictionary:
				var dec := EvoTypes.DecisionDef.from_dict(item as Dictionary)
				state.decisions_catalog[dec.id] = dec
	if data.has("strategies") and data["strategies"] is Array:
		for item in data["strategies"]:
			if item is Dictionary:
				var strat := EvoTypes.StrategyDef.from_dict(item as Dictionary)
				state.strategies_catalog[strat.id] = strat
