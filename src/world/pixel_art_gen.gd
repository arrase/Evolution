class_name EvoPixelArtGen
extends EvoPixelCanvas

static var _texture_cache: Dictionary = {}
static var _image_cache: Dictionary = {}
static var _villager_colored_cache: Dictionary = {}
static var _initialized: bool = false

const HEX_TILE_SPRITES: Array[String] = [
	"hex_tile_tropical_forest",
	"hex_tile_savanna",
	"hex_tile_arid_steppe",
	"hex_tile_tundra",
	"hex_tile_high_mountain",
	"hex_tile_coastal_shallows",
	"hex_tile_ocean"
]

const TERRAIN_SPRITES: Array[String] = [
	"tree_tropical",
	"tree_tropical_2",
	"tree_savanna",
	"tree_savanna_2",
	"tree_tundra",
	"tree_tundra_2",
	"bush_arid",
	"bush_berry",
	"fallen_log",
	"mossy_rock",
	"tall_grass",
	"dry_scrub",
	"rock_mountain",
	"coastal_reeds",
	"tree_stump",
	"soil_crack",
	"wildflowers"
]

const VILLAGE_SPRITES: Array[String] = [
	"tier1_tent",
	"tier1_campfire",
	"tier1_campfire_2",
	"tier2_cottage",
	"tier2_barn",
	"tier3_townhall",
	"tier3_house",
	"tier4_citadel",
	"tier4_windmill",
	"tier4_tower",
	"act_forage",
	"act_overexploit",
	"act_migrate",
	"act_cooperate",
	"act_exchange",
	"act_dispute",
	"act_innovate",
	"act_custom",
	"cultural_totem",
	"ruins",
	"caravan_cart",
	"settler_wagon",
	"barricade_spikes",
	"road_block_sign",
	"road_lantern",
	"prop_war_banner",
	"prop_raid_loot",
	"prop_pact_totem",
	"prop_betrayal_ruin",
	"act_war",
	"act_raid",
	"act_pact",
	"act_betrayal",
	"effect_battle_sparks",
	"villager_idle",
	"villager_walk1",
	"villager_walk2"
]

const UI_SPRITES: Array[String] = [
	"tool_inspect",
	"tool_biome",
	"tool_altitude",
	"tool_fertility",
	"tool_sealevel",
	"season_wet",
	"season_dry",
	"status_thriving",
	"status_stable",
	"status_struggling",
	"status_starving",
	"icon_forage",
	"icon_overexploit",
	"icon_migrate",
	"icon_cooperate",
	"icon_exchange",
	"icon_dispute",
	"icon_innovate",
	"icon_custom",
	"icon_war",
	"icon_raid",
	"icon_pact",
	"icon_betrayal",
	"icon_coop_link",
	"icon_conflict_swords",
	"icon_broken_link",
	"thought_bubble"
]


static func ensure_all_assets(force_rebuild: bool = false) -> void:
	if _initialized and not force_rebuild:
		return
	_initialized = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/terrain"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/villages"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/ui"))

	for s_name in HEX_TILE_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/terrain/%s.png" % s_name, force_rebuild)
	for s_name in TERRAIN_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/terrain/%s.png" % s_name, force_rebuild)
	for s_name in VILLAGE_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/villages/%s.png" % s_name, force_rebuild)
	for s_name in UI_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/ui/%s.png" % s_name, force_rebuild)


static func get_texture(sprite_name: String) -> ImageTexture:
	if not _initialized:
		ensure_all_assets()
	if _texture_cache.has(sprite_name):
		return _texture_cache[sprite_name]
	var img := _build_sprite_image(sprite_name)
	var tex := ImageTexture.create_from_image(img)
	_image_cache[sprite_name] = img
	_texture_cache[sprite_name] = tex
	return tex


static func get_image(sprite_name: String) -> Image:
	if not _initialized:
		ensure_all_assets()
	if _image_cache.has(sprite_name):
		return _image_cache[sprite_name]
	get_texture(sprite_name)
	return _image_cache[sprite_name]


static func get_villager_texture(pose: String, tunic_color: Color) -> ImageTexture:
	if not _initialized:
		ensure_all_assets()
	var key := "%s_%s" % [pose, tunic_color.to_html(false)]
	if _villager_colored_cache.has(key):
		return _villager_colored_cache[key]
	var step := 0
	if pose == "villager_walk1":
		step = 1
	elif pose == "villager_walk2":
		step = 2
	var img := EvoVillageUiSprites.draw_villager(step, tunic_color)
	var tex := ImageTexture.create_from_image(img)
	_villager_colored_cache[key] = tex
	return tex


static func _generate_and_register(sprite_name: String, file_path: String, force_rebuild: bool = false) -> void:
	var abs_path := ProjectSettings.globalize_path(file_path)
	var img: Image
	if not force_rebuild and FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
		if sprite_name.begins_with("hex_tile_") and img.get_width() < 224:
			img = _build_sprite_image(sprite_name)
			img.save_png(abs_path)
	else:
		img = _build_sprite_image(sprite_name)
		img.save_png(abs_path)
	_image_cache[sprite_name] = img
	_texture_cache[sprite_name] = ImageTexture.create_from_image(img)


static func _build_sprite_image(sprite_name: String) -> Image:
	if sprite_name.begins_with("hex_tile_"):
		var biome_name := sprite_name.trim_prefix("hex_tile_")
		return EvoTerrainSprites.draw_hex_tile(biome_name)
	if sprite_name in TERRAIN_SPRITES:
		return EvoTerrainSprites.draw_terrain_sprite(sprite_name)
	return EvoVillageUiSprites.draw_village_or_ui_sprite(sprite_name)
