class_name EvoPixelArtGen
extends EvoPixelCanvas

const ASSET_SCHEMA_VERSION: String = "v4_readability"

static var _texture_cache: Dictionary = {}
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
	"wildflowers",
	"mountain_peak",
	"tree_canopy",
	"palm_cluster",
	"savanna_tree",
	"acacia_tree",
	"bush_cluster",
	"marsh_reeds",
	"pine_tree"
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
	"tier5_metropolis",
	"hut_thatch",
	"house_clay",
	"house_stone",
	"campfire",
	"totem_coop",
	"totem_aggro",
	"totem_innov",
	"granary",
	"palisade_wall",
	"watchtower",
	"temple_totem",
	"citadel_keep",
	"stone_wall",
	"siege_totem",
	"windmill",
	"cathedral",
	"crop_field",
	"pasture_pen",
	"covered_wagon",
	"ruins_stone",
	"prop_unity_monument",
	"prop_defense_palisade",
	"prop_defense_wall",
	"prop_defense_fortress",
	"prop_tribute_chest",
	"prop_siege_engine",
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
	"icon_defense",
	"icon_merge",
	"icon_tribute",
	"icon_siege",
	"icon_coop_link",
	"icon_conflict_swords",
	"icon_broken_link",
	"icon_epidemic",
	"icon_famine",
	"icon_immune",
	"icon_vendetta",
	"icon_casualties",
	"icon_loot",
	"icon_migrants"
]

const ALIAS_MAP: Dictionary = {
	"tree_canopy": "tree_tropical",
	"palm_cluster": "tree_tropical_2",
	"savanna_tree": "tree_savanna",
	"acacia_tree": "tree_savanna_2",
	"pine_tree": "tree_tundra",
	"bush_cluster": "bush_arid",
	"marsh_reeds": "coastal_reeds",
	"mountain_peak": "rock_mountain",
	"tier1_tent": "hut_thatch",
	"tier1_campfire": "campfire",
	"tier2_cottage": "house_clay",
	"tier2_barn": "granary",
	"tier3_townhall": "temple_totem",
	"tier3_house": "house_stone",
	"tier4_citadel": "citadel_keep",
	"tier4_windmill": "windmill",
	"tier4_tower": "watchtower",
	"tier5_metropolis": "cathedral",
	"prop_defense_palisade": "palisade_wall",
	"prop_defense_wall": "stone_wall",
	"prop_defense_fortress": "watchtower",
	"prop_siege_engine": "siege_totem",
	"settler_wagon": "covered_wagon",
	"caravan_cart": "covered_wagon",
	"ruins": "ruins_stone"
}


static func _resolve_alias(sprite_name: String) -> String:
	var cur := sprite_name
	while ALIAS_MAP.has(cur):
		cur = str(ALIAS_MAP[cur])
	return cur


static func _canonical_sprite_path(sprite_name: String) -> String:
	if sprite_name.begins_with("hex_tile_") or sprite_name in TERRAIN_SPRITES:
		return "res://assets/sprites/terrain/%s.png" % sprite_name
	if sprite_name in UI_SPRITES:
		return "res://assets/sprites/ui/%s.png" % sprite_name
	return "res://assets/sprites/villages/%s.png" % sprite_name


static func ensure_all_assets(force_rebuild: bool = false) -> void:
	if _initialized and not force_rebuild:
		return
	_initialized = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/terrain"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/villages"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/ui"))

	var schema_path := ProjectSettings.globalize_path("res://assets/sprites/schema_version.txt")
	var current_schema := FileAccess.get_file_as_string(schema_path).strip_edges() if FileAccess.file_exists(schema_path) else ""
	var should_rebuild := force_rebuild or current_schema != ASSET_SCHEMA_VERSION

	for s_name in HEX_TILE_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/terrain/%s.png" % s_name, should_rebuild)
	for s_name in TERRAIN_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/terrain/%s.png" % s_name, should_rebuild)
	for s_name in VILLAGE_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/villages/%s.png" % s_name, should_rebuild)
	for s_name in UI_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/ui/%s.png" % s_name, should_rebuild)

	if should_rebuild:
		var f := FileAccess.open(schema_path, FileAccess.WRITE)
		if f != null:
			f.store_string(ASSET_SCHEMA_VERSION)


static func get_texture(sprite_name: String) -> ImageTexture:
	if not _initialized:
		ensure_all_assets()
	if _texture_cache.has(sprite_name):
		return _texture_cache[sprite_name]
	var canonical := _resolve_alias(sprite_name)
	if _texture_cache.has(canonical):
		_texture_cache[sprite_name] = _texture_cache[canonical]
		return _texture_cache[canonical]
	var img := _build_sprite_image(canonical)
	img.generate_mipmaps()
	_texture_cache[canonical] = ImageTexture.create_from_image(img)
	_texture_cache[sprite_name] = _texture_cache[canonical]
	return _texture_cache[canonical]


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
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_villager_colored_cache[key] = tex
	return tex


static func _min_expected_width(sprite_name: String) -> int:
	if sprite_name.begins_with("hex_tile_"):
		return 256
	if sprite_name.begins_with("villager_"):
		return 48
	if sprite_name in UI_SPRITES or sprite_name.begins_with("icon_"):
		return 64
	return 128


static func _generate_and_register(sprite_name: String, file_path: String, force_rebuild: bool = false) -> void:
	var canonical := _resolve_alias(sprite_name)
	var abs_path := ProjectSettings.globalize_path(file_path)
	if canonical != sprite_name:
		var canon_rel := _canonical_sprite_path(canonical)
		if force_rebuild or not _texture_cache.has(canonical):
			_generate_and_register(canonical, canon_rel, force_rebuild)
		if force_rebuild or not FileAccess.file_exists(abs_path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(canon_rel), abs_path)
		_texture_cache[sprite_name] = _texture_cache[canonical]
		return

	var img: Image
	var min_w := _min_expected_width(sprite_name)
	if not force_rebuild and FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
		if img == null or img.get_width() < min_w:
			img = _build_sprite_image(sprite_name)
			img.save_png(abs_path)
	else:
		img = _build_sprite_image(sprite_name)
		img.save_png(abs_path)

	img.generate_mipmaps()
	_texture_cache[sprite_name] = ImageTexture.create_from_image(img)


static func _build_sprite_image(sprite_name: String) -> Image:
	if sprite_name.begins_with("hex_tile_"):
		var biome_name := sprite_name.trim_prefix("hex_tile_")
		return EvoTerrainSprites.draw_hex_tile(biome_name)
	if sprite_name in TERRAIN_SPRITES:
		return EvoTerrainSprites.draw_terrain_sprite(sprite_name)
	return EvoVillageUiSprites.draw_village_or_ui_sprite(sprite_name)
