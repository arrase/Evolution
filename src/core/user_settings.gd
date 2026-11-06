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
	return OS.get_environment("HOME").path_join(".config/Evolution")


static func get_config_path() -> String:
	if config_path_override != "":
		return config_path_override
	return get_config_dir().path_join("settings.json")


static func load_settings() -> void:
	var path := get_config_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
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
	var payload := {
		"primary_model": primary_model,
		"secondary_model": secondary_model,
		"context_length": context_length
	}
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()
