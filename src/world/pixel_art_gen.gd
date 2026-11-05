class_name EvoPixelArtGen
extends RefCounted

static var _texture_cache: Dictionary = {}
static var _image_cache: Dictionary = {}
static var _villager_colored_cache: Dictionary = {}
static var _initialized: bool = false

const C_OUTLINE := Color("#23150c")
const C_SHADOW := Color(0.06, 0.04, 0.02, 0.35)

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
	"icon_coop_link",
	"icon_conflict_swords",
	"icon_broken_link",
	"thought_bubble"
]


static func ensure_all_assets() -> void:
	if _initialized:
		return
	_initialized = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/terrain"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/villages"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/ui"))

	for s_name in HEX_TILE_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/terrain/%s.png" % s_name)
	for s_name in TERRAIN_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/terrain/%s.png" % s_name)
	for s_name in VILLAGE_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/villages/%s.png" % s_name)
	for s_name in UI_SPRITES:
		_generate_and_register(s_name, "res://assets/sprites/ui/%s.png" % s_name)


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
	var img := _draw_villager(step, tunic_color)
	var tex := ImageTexture.create_from_image(img)
	_villager_colored_cache[key] = tex
	return tex


static func _generate_and_register(sprite_name: String, file_path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(file_path)
	var img: Image
	if FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
	else:
		img = _build_sprite_image(sprite_name)
		img.save_png(abs_path)
	_image_cache[sprite_name] = img
	_texture_cache[sprite_name] = ImageTexture.create_from_image(img)


static func _build_sprite_image(sprite_name: String) -> Image:
	if sprite_name.begins_with("hex_tile_"):
		var biome_name := sprite_name.trim_prefix("hex_tile_")
		return _draw_hex_tile(biome_name)

	match sprite_name:
		"tree_tropical":
			return _draw_tree_tropical()
		"tree_tropical_2":
			return _draw_tree_tropical_2()
		"tree_savanna":
			return _draw_tree_savanna()
		"tree_savanna_2":
			return _draw_tree_savanna_2()
		"tree_tundra":
			return _draw_tree_tundra()
		"tree_tundra_2":
			return _draw_tree_tundra_2()
		"bush_arid":
			return _draw_bush_arid()
		"bush_berry":
			return _draw_bush_berry()
		"fallen_log":
			return _draw_fallen_log()
		"mossy_rock":
			return _draw_mossy_rock()
		"tall_grass":
			return _draw_tall_grass()
		"dry_scrub":
			return _draw_dry_scrub()
		"rock_mountain":
			return _draw_rock_mountain()
		"coastal_reeds":
			return _draw_coastal_reeds()
		"tree_stump":
			return _draw_tree_stump()
		"soil_crack":
			return _draw_soil_crack()
		"wildflowers":
			return _draw_wildflowers()
		"tier1_tent":
			return _draw_tier1_tent()
		"tier1_campfire":
			return _draw_tier1_campfire(0)
		"tier1_campfire_2":
			return _draw_tier1_campfire(1)
		"tier2_cottage":
			return _draw_tier2_cottage()
		"tier2_barn":
			return _draw_tier2_barn()
		"tier3_townhall":
			return _draw_tier3_townhall()
		"tier3_house":
			return _draw_tier3_house()
		"tier4_citadel":
			return _draw_tier4_citadel()
		"tier4_windmill":
			return _draw_tier4_windmill()
		"tier4_tower":
			return _draw_tier4_tower()
		"act_forage":
			return _draw_act_forage()
		"act_overexploit":
			return _draw_act_overexploit()
		"act_migrate":
			return _draw_act_migrate()
		"act_cooperate":
			return _draw_act_cooperate()
		"act_exchange":
			return _draw_act_exchange()
		"act_dispute":
			return _draw_act_dispute()
		"act_innovate":
			return _draw_act_innovate()
		"act_custom":
			return _draw_act_custom()
		"cultural_totem":
			return _draw_cultural_totem()
		"ruins":
			return _draw_ruins()
		"caravan_cart":
			return _draw_caravan_cart()
		"settler_wagon":
			return _draw_settler_wagon()
		"barricade_spikes":
			return _draw_barricade_spikes()
		"road_block_sign":
			return _draw_road_block_sign()
		"road_lantern":
			return _draw_road_lantern()
		"villager_idle":
			return _draw_villager(0, Color("#e07a5f"))
		"villager_walk1":
			return _draw_villager(1, Color("#e07a5f"))
		"villager_walk2":
			return _draw_villager(2, Color("#e07a5f"))
		_:
			return _draw_ui_icon(sprite_name)


# ============================================================================
# PIXEL DRAWING PRIMITIVES
# ============================================================================

static func _new_canvas(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _hash2d(x: int, y: int, seed_val: int = 0) -> int:
	var h: int = (x * 374761393) + (y * 668265263) + (seed_val * 1442695041)
	h = (h ^ (h >> 13)) * 1274126177
	return abs(h ^ (h >> 16))


static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, col)


static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(y, y + h):
		for px_i in range(x, x + w):
			_px(img, px_i, py, col)


static func _rect_outlined(img: Image, x: int, y: int, w: int, h: int, fill: Color, outline: Color = C_OUTLINE) -> void:
	_rect(img, x, y, w, h, fill)
	for px_i in range(x, x + w):
		_px(img, px_i, y, outline)
		_px(img, px_i, y + h - 1, outline)
	for py in range(y, y + h):
		_px(img, x, py, outline)
		_px(img, x + w - 1, py, outline)


static func _circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var r2 := r * r
	for py in range(cy - r, cy + r + 1):
		for px_i in range(cx - r, cx + r + 1):
			var dx := px_i - cx
			var dy := py - cy
			if dx * dx + dy * dy <= r2:
				_px(img, px_i, py, col)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for py in range(cy - ry, cy + ry + 1):
		for px_i in range(cx - rx, cx + rx + 1):
			var nx := float(px_i - cx) / float(rx)
			var ny := float(py - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				_px(img, px_i, py, col)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx: int = abs(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -abs(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var cx: int = x0
	var cy: int = y0
	while true:
		_px(img, cx, cy, col)
		if cx == x1 and cy == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy


static func _apply_soft_outline(img: Image, outline_col: Color = C_OUTLINE) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var copy := img.duplicate() as Image
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(h):
		for x in range(w):
			var c := copy.get_pixel(x, y)
			if c.a > 0.5:
				continue
			for d in dirs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					var nc := copy.get_pixel(nx, ny)
					if nc.a > 0.85:
						img.set_pixel(x, y, outline_col)
						break


# ============================================================================
# DETAILED 16-BIT HEX PARCEL TEXTURES (112x96 px)
# ============================================================================

static func _draw_hex_tile(biome: String) -> Image:
	var w := 112
	var h := 96
	var img := _new_canvas(w, h)
	var cx := 56.0
	var cy := 48.0

	match biome:
		"tropical_forest":
			var tones := [
				Color("#1c6e38"),
				Color("#258545"),
				Color("#2f9e53"),
				Color("#3eb864")
			]
			for y in range(h):
				for x in range(w):
					var dist := Vector2((float(x) - cx) / 52.0, (float(y) - cy) / 44.0).length()
					var n := _hash2d(x / 2, y / 2, 11) % 4
					var fine := _hash2d(x, y, 17) % 5
					var idx := clampi(n + (1 if dist < 0.62 else 0) - (1 if dist > 0.86 else 0), 0, 3)
					var col: Color = tones[idx]
					if fine == 0:
						col = col.lightened(0.06)
					elif fine == 1:
						col = col.darkened(0.06)
					_px(img, x, y, col)

			# Rich moss patches & humus clearings
			var moss_spots := [
				Vector2i(34, 30), Vector2i(74, 28), Vector2i(28, 60),
				Vector2i(78, 62), Vector2i(55, 48), Vector2i(46, 70), Vector2i(62, 24)
			]
			for ms in moss_spots:
				_ellipse(img, ms.x, ms.y, 11, 7, Color("#175c2e"))
				_ellipse(img, ms.x - 1, ms.y - 1, 8, 5, Color("#2d9447"))
				_ellipse(img, ms.x + 2, ms.y + 1, 5, 3, Color("#49c468"))

			# Pixel ferns, tiny flowers & mossy stones across the parcel
			for i in range(28):
				var fx := 14 + (_hash2d(i, 1, 31) % 84)
				var fy := 12 + (_hash2d(i, 2, 31) % 72)
				if i % 3 == 0:
					# Mini pixel fern frond cluster
					_line(img, fx, fy, fx - 3, fy - 2, Color("#124d26"))
					_line(img, fx, fy, fx + 3, fy - 2, Color("#124d26"))
					_line(img, fx, fy - 1, fx - 2, fy - 3, Color("#52d173"))
					_line(img, fx, fy - 1, fx + 2, fy - 3, Color("#52d173"))
					_px(img, fx, fy - 2, Color("#7ae582"))
				elif i % 3 == 1:
					# Wildflower blossom
					var fl_col := Color("#ff6b8b") if i % 2 == 0 else Color("#ffd166")
					_px(img, fx, fy + 1, Color("#1b6332"))
					_px(img, fx - 1, fy, fl_col)
					_px(img, fx + 1, fy, fl_col)
					_px(img, fx, fy - 1, fl_col)
					_px(img, fx, fy, Color("#fff8d6"))
				else:
					# Mossy pebble
					_ellipse(img, fx, fy, 2, 1, Color("#576066"))
					_px(img, fx, fy - 1, Color("#49c468"))

		"savanna":
			var tones := [
				Color("#ab7e24"),
				Color("#c4932d"),
				Color("#d9ab3b"),
				Color("#e8be4e")
			]
			for y in range(h):
				for x in range(w):
					var dist := Vector2((float(x) - cx) / 52.0, (float(y) - cy) / 44.0).length()
					var wave := int(sin(float(x) * 0.14 + float(y) * 0.08) * 1.5)
					var n := (_hash2d(x / 2, y / 2, 23) + wave) % 4
					var idx := clampi(abs(n) + (1 if dist < 0.58 else 0), 0, 3)
					var col: Color = tones[idx]
					if _hash2d(x, y, 29) % 6 == 0:
						col = col.lightened(0.07)
					_px(img, x, y, col)

			# Warm red-earth natural animal trails / dry soil patches
			var dirt_patches := [
				Vector2i(36, 36), Vector2i(56, 48), Vector2i(74, 56),
				Vector2i(44, 64), Vector2i(68, 32)
			]
			for dp in dirt_patches:
				_ellipse(img, dp.x, dp.y, 12, 6, Color("#9c622b"))
				_ellipse(img, dp.x, dp.y, 8, 4, Color("#b57638"))

			# Tall golden grass tufts & reddish pebbles
			for i in range(32):
				var gx := 12 + (_hash2d(i, 3, 41) % 88)
				var gy := 10 + (_hash2d(i, 4, 41) % 76)
				if i % 3 != 0:
					_line(img, gx, gy, gx - 1, gy - 3, Color("#8c6518"))
					_line(img, gx + 1, gy, gx + 2, gy - 4, Color("#f2d06b"))
					_px(img, gx, gy - 2, Color("#e3b646"))
				else:
					_ellipse(img, gx, gy, 3, 2, Color("#8f4426"))
					_px(img, gx - 1, gy - 1, Color("#b85d38"))

		"arid_steppe":
			var tones := [
				Color("#b86628"),
				Color("#cc7735"),
				Color("#de8b47"),
				Color("#eda05c")
			]
			for y in range(h):
				for x in range(w):
					# Wind-carved sand dune ripples
					var ripple := sin(float(y) * 0.38 + sin(float(x) * 0.09) * 2.2)
					var idx := 1
					if ripple > 0.55:
						idx = 3
					elif ripple > 0.0:
						idx = 2
					elif ripple < -0.55:
						idx = 0
					if _hash2d(x, y, 53) % 5 == 0:
						idx = clampi(idx + 1, 0, 3)
					_px(img, x, y, tones[idx])

			# Terracotta pebbles, dry cracks & desert scrub spots
			for i in range(26):
				var sx := 14 + (_hash2d(i, 5, 61) % 84)
				var sy := 12 + (_hash2d(i, 6, 61) % 72)
				if i % 4 == 0:
					_line(img, sx - 4, sy, sx + 3, sy + 2, Color("#6e3819"))
					_line(img, sx, sy + 1, sx + 2, sy + 4, Color("#6e3819"))
				elif i % 2 == 0:
					_ellipse(img, sx, sy, 3, 2, Color("#7d4122"))
					_px(img, sx, sy - 1, Color("#a65a32"))
				else:
					_px(img, sx, sy, Color("#687530"))
					_px(img, sx - 1, sy - 1, Color("#83913f"))
					_px(img, sx + 1, sy - 1, Color("#83913f"))

		"tundra":
			var tones := [
				Color("#9eb6c4"),
				Color("#b8cedb"),
				Color("#d2e3ed"),
				Color("#eaf4f8")
			]
			for y in range(h):
				for x in range(w):
					var dist := Vector2((float(x) - cx) / 52.0, (float(y) - cy) / 44.0).length()
					var n := _hash2d(x / 2, y / 2, 71) % 4
					var idx := clampi(n + (1 if dist < 0.65 else 0), 0, 3)
					_px(img, x, y, tones[idx])

			# Boreal blue-grey moss & permafrost patches
			var moss_patches := [
				Vector2i(34, 34), Vector2i(72, 36), Vector2i(48, 62),
				Vector2i(64, 26), Vector2i(30, 56)
			]
			for mp in moss_patches:
				_ellipse(img, mp.x, mp.y, 10, 6, Color("#5e7887"))
				_ellipse(img, mp.x, mp.y, 7, 4, Color("#6e8c76"))

			# Ice crystals & frozen stones
			for i in range(24):
				var ix := 14 + (_hash2d(i, 7, 79) % 84)
				var iy := 12 + (_hash2d(i, 8, 79) % 72)
				if i % 2 == 0:
					_px(img, ix, iy, Color("#ffffff"))
					_px(img, ix - 1, iy, Color("#7dd3fc"))
					_px(img, ix + 1, iy, Color("#7dd3fc"))
					_px(img, ix, iy - 1, Color("#38bdf8"))
					_px(img, ix, iy + 1, Color("#38bdf8"))
				else:
					_ellipse(img, ix, iy, 3, 2, Color("#475569"))
					_px(img, ix, iy - 1, Color("#e2e8f0"))

		"high_mountain":
			var tones := [
				Color("#524e4a"),
				Color("#69645f"),
				Color("#807a74"),
				Color("#99928b")
			]
			for y in range(h):
				for x in range(w):
					# Stratified granite terraces
					var band := ((y + int(sin(float(x) * 0.12) * 4.0)) / 7) % 4
					var n := _hash2d(x, y, 89) % 4
					var idx := clampi((band + (1 if n > 2 else 0)) % 4, 0, 3)
					_px(img, x, y, tones[idx])

			# Alpine snow ridges & dark rock crevices
			var snow_caps := [
				Vector2i(46, 28), Vector2i(66, 34), Vector2i(54, 52), Vector2i(36, 48)
			]
			for sc in snow_caps:
				_ellipse(img, sc.x, sc.y, 11, 5, Color("#cbd5e1"))
				_ellipse(img, sc.x, sc.y - 1, 8, 3, Color("#f1f5f9"))

			for i in range(18):
				var rx := 16 + (_hash2d(i, 9, 97) % 80)
				var ry := 14 + (_hash2d(i, 10, 97) % 68)
				_line(img, rx - 4, ry, rx + 4, ry + 1, Color("#2e2b29"))
				_line(img, rx - 3, ry - 1, rx + 3, ry, Color("#b5afa8"))

		"coastal_shallows":
			# Outer turquoise shallow water, white foam ring, and inner golden sandbar
			for y in range(h):
				for x in range(w):
					var d := Vector2((float(x) - cx) / 48.0, (float(y) - cy) / 40.0).length()
					var jitter := float(_hash2d(x / 2, y / 2, 103) % 10) * 0.018
					var dj := d + jitter
					var col := Color("#258f86")
					if dj < 0.48:
						col = Color("#ebd294") if _hash2d(x, y, 107) % 3 == 0 else Color("#d9be7e")
					elif dj < 0.58:
						col = Color("#c2a361")
					elif dj < 0.66:
						col = Color("#e0f7fa")
					elif dj < 0.82:
						col = Color("#45c4b8") if _hash2d(x, y, 109) % 2 == 0 else Color("#32a89d")
					_px(img, x, y, col)

			# Starfish, seashells & water sparkles
			var shells := [Vector2i(48, 42), Vector2i(64, 50), Vector2i(42, 54), Vector2i(58, 36)]
			for idx in range(shells.size()):
				var sp: Vector2i = shells[idx]
				if idx % 2 == 0:
					# Orange starfish
					_px(img, sp.x, sp.y, Color("#fb923c"))
					_px(img, sp.x - 1, sp.y, Color("#f97316"))
					_px(img, sp.x + 1, sp.y, Color("#f97316"))
					_px(img, sp.x, sp.y - 1, Color("#f97316"))
					_px(img, sp.x, sp.y + 1, Color("#f97316"))
				else:
					# Pink seashell
					_rect(img, sp.x - 1, sp.y - 1, 3, 2, Color("#ff9ebb"))
					_px(img, sp.x, sp.y, Color("#ffe3ec"))

		_:
			# Deep pixel-art ocean with wave crests
			var tones := [
				Color("#134263"),
				Color("#19547d"),
				Color("#216899"),
				Color("#2b7bb3")
			]
			for y in range(h):
				for x in range(w):
					var wave := sin(float(x) * 0.16 + float(y) * 0.22)
					var idx := 1
					if wave > 0.55:
						idx = 3
					elif wave > 0.0:
						idx = 2
					elif wave < -0.55:
						idx = 0
					_px(img, x, y, tones[idx])
			for i in range(16):
				var wx := 14 + (_hash2d(i, 11, 131) % 84)
				var wy := 12 + (_hash2d(i, 12, 131) % 72)
				_line(img, wx - 4, wy, wx + 4, wy, Color("#7dd3fc"))
				_line(img, wx - 2, wy - 1, wx + 2, wy - 1, Color("#e0f2fe"))

	return img


# ============================================================================
# TERRAIN & FLORA SPRITES (36x36 / 32x32 / 24x24)
# ============================================================================

static func _draw_tree_tropical() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 10, 3, C_SHADOW)
	# Buttress roots and warm mahogany trunk
	_rect(img, 16, 20, 4, 12, Color("#6e3f23"))
	_rect(img, 17, 20, 2, 12, Color("#8c5330"))
	_line(img, 15, 27, 12, 32, Color("#593119"))
	_line(img, 20, 27, 23, 32, Color("#593119"))
	# Lush layered emerald canopy
	_circle(img, 18, 15, 11, Color("#0f5e36"))
	_circle(img, 12, 17, 7, Color("#147543"))
	_circle(img, 24, 17, 7, Color("#11663b"))
	_circle(img, 18, 12, 9, Color("#1d9454"))
	_circle(img, 15, 9, 6, Color("#34b86a"))
	_circle(img, 22, 13, 5, Color("#27a65c"))
	# Hanging lianas/vines
	_line(img, 10, 20, 10, 26, Color("#1d8049"))
	_line(img, 25, 20, 25, 25, Color("#1d8049"))
	# Exotic Stardew blossoms
	_px(img, 13, 10, Color("#ff6b8b"))
	_px(img, 14, 10, Color("#ffd166"))
	_px(img, 22, 14, Color("#ff6b8b"))
	_px(img, 21, 14, Color("#ffd166"))
	_px(img, 17, 17, Color("#ff9f1c"))
	_apply_soft_outline(img, Color("#172617"))
	return img


static func _draw_tree_tropical_2() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 9, 3, C_SHADOW)
	# Curved tropical palm / exotic fruit tree trunk
	for y in range(13, 32):
		var curve_x := 18 + int(sin(float(y - 13) * 0.18) * 2.5)
		_rect(img, curve_x - 2, y, 4, 1, Color("#7c4728") if y % 2 == 0 else Color("#995b36"))
	# Coconuts / fruit cluster under crown
	_circle(img, 16, 13, 2, Color("#5c3317"))
	_circle(img, 20, 13, 2, Color("#6b3e26"))
	# Sweeping palm fronds
	var frond_tips := [
		Vector2i(5, 14), Vector2i(8, 7), Vector2i(18, 3),
		Vector2i(28, 7), Vector2i(31, 14), Vector2i(10, 20), Vector2i(26, 20)
	]
	for tip in frond_tips:
		_line(img, 18, 11, tip.x, tip.y, Color("#16703d"))
		_line(img, 18, 10, tip.x, tip.y - 1, Color("#2eb865"))
		_line(img, 18, 12, tip.x, tip.y + 1, Color("#1e8f4e"))
	_circle(img, 18, 10, 4, Color("#4ad67d"))
	_apply_soft_outline(img, Color("#142618"))
	return img


static func _draw_tree_savanna() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 10, 3, C_SHADOW)
	# Branching acacia trunk
	_line(img, 17, 31, 18, 18, Color("#6b3e26"))
	_line(img, 18, 31, 19, 18, Color("#8a5232"))
	_line(img, 18, 19, 11, 13, Color("#6b3e26"))
	_line(img, 19, 19, 26, 14, Color("#6b3e26"))
	# Wide flat golden-olive canopy tiers
	_ellipse(img, 18, 12, 14, 4, Color("#6e7821"))
	_ellipse(img, 18, 11, 12, 3, Color("#8fa329"))
	_ellipse(img, 16, 9, 9, 2, Color("#b8c93a"))
	_ellipse(img, 25, 14, 7, 2, Color("#7d8c24"))
	_ellipse(img, 10, 14, 7, 2, Color("#9eb32d"))
	_apply_soft_outline(img, Color("#292111"))
	return img


static func _draw_tree_savanna_2() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 32, 10, 3, C_SHADOW)
	# Thick sculpted baobab trunk
	for y in range(15, 32):
		var hw := 3 + int(float(y - 15) * 0.22)
		_rect(img, 18 - hw, y, hw * 2 + 1, 1, Color("#8a5a3c") if y % 3 != 0 else Color("#70472e"))
		_rect(img, 18 - hw + 1, y, hw, 1, Color("#a36d4b"))
	# Warm golden-green crown puffs
	_ellipse(img, 12, 13, 6, 4, Color("#7d8c24"))
	_ellipse(img, 24, 13, 6, 4, Color("#6e7821"))
	_ellipse(img, 18, 10, 8, 5, Color("#9eb32d"))
	_ellipse(img, 17, 9, 5, 3, Color("#c5d945"))
	_apply_soft_outline(img, Color("#292111"))
	return img


static func _draw_tree_tundra() -> Image:
	var img := _new_canvas(32, 34)
	_ellipse(img, 16, 30, 8, 2, C_SHADOW)
	_rect(img, 15, 24, 3, 6, Color("#4f311c"))
	# Three pine tiers with snow caps
	for tier in range(3):
		var top_y: int = 4 + tier * 6
		var half_w: int = 5 + tier * 3
		for row in range(8):
			var w_row: int = int(float(row) / 7.0 * float(half_w))
			var py: int = top_y + row
			for dx in range(-w_row, w_row + 1):
				var col := Color("#1e4d3b") if dx > 0 else Color("#2b6951")
				if row <= 2 or (row == 3 and (dx + tier) % 2 == 0):
					col = Color("#eef6fa") if dx <= 0 else Color("#cbe0ec")
				_px(img, 16 + dx, py, col)
	_apply_soft_outline(img, Color("#162429"))
	return img


static func _draw_tree_tundra_2() -> Image:
	var img := _new_canvas(32, 34)
	_ellipse(img, 16, 30, 9, 2, C_SHADOW)
	# Twin snowy boreal firs
	for idx in range(2):
		var cx := 11 if idx == 0 else 21
		var top_y := 6 if idx == 0 else 10
		_rect(img, cx - 1, 25, 2, 5, Color("#4f311c"))
		for row in range(19 - idx * 3):
			var hw := 1 + int(float(row) * 0.34)
			var py := top_y + row
			for dx in range(-hw, hw + 1):
				var col := Color("#245945") if dx <= 0 else Color("#194233")
				if row % 5 <= 1:
					col = Color("#f0f7fa") if dx <= 0 else Color("#c8dfeb")
				_px(img, cx + dx, py, col)
	_apply_soft_outline(img, Color("#162429"))
	return img


static func _draw_bush_arid() -> Image:
	var img := _new_canvas(26, 26)
	_ellipse(img, 13, 22, 7, 2, C_SHADOW)
	# Saguaro cactus
	_rect(img, 11, 7, 4, 15, Color("#3a7d44"))
	_rect(img, 12, 7, 2, 15, Color("#52a35d"))
	# Left arm
	_rect(img, 7, 11, 4, 3, Color("#3a7d44"))
	_rect(img, 7, 8, 3, 4, Color("#52a35d"))
	# Right arm
	_rect(img, 15, 13, 4, 3, Color("#3a7d44"))
	_rect(img, 16, 10, 3, 4, Color("#3a7d44"))
	# Desert flower on top
	_px(img, 12, 6, Color("#ff5964"))
	_px(img, 13, 6, Color("#ffe74c"))
	# Dry scrub bush beside it
	_ellipse(img, 18, 20, 4, 2, Color("#9c662c"))
	_px(img, 17, 19, Color("#c48b3f"))
	_apply_soft_outline(img, Color("#241b10"))
	return img


static func _draw_bush_berry() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 20, 8, 2, C_SHADOW)
	_circle(img, 9, 15, 5, Color("#156134"))
	_circle(img, 15, 15, 5, Color("#12522b"))
	_circle(img, 12, 12, 6, Color("#1f8749"))
	_circle(img, 11, 11, 4, Color("#34b364"))
	# Glossy Stardew salmonberries / blackberries
	var berries := [
		Vector2i(8, 13), Vector2i(14, 11), Vector2i(11, 15),
		Vector2i(16, 15), Vector2i(10, 10)
	]
	for b in berries:
		_px(img, b.x, b.y, Color("#ef4444"))
		_px(img, b.x + 1, b.y, Color("#dc2626"))
		_px(img, b.x, b.y - 1, Color("#fca5a5"))
	_apply_soft_outline(img, Color("#142617"))
	return img


static func _draw_fallen_log() -> Image:
	var img := _new_canvas(28, 20)
	_ellipse(img, 14, 16, 11, 2, C_SHADOW)
	# Horizontal hollow trunk
	_rect(img, 5, 10, 18, 6, Color("#6e3f23"))
	_rect(img, 5, 11, 18, 2, Color("#8c5330"))
	_ellipse(img, 5, 13, 2, 3, Color("#d4a373"))
	_px(img, 5, 13, Color("#3d2314"))
	_ellipse(img, 23, 13, 2, 3, Color("#4a2c18"))
	# Moss blanket & tiny red mushroom on log
	_rect(img, 8, 9, 9, 2, Color("#2d9447"))
	_rect(img, 10, 8, 5, 1, Color("#4cc470"))
	_px(img, 19, 8, Color("#fefae0"))
	_rect(img, 18, 6, 3, 2, Color("#ef4444"))
	_px(img, 19, 6, Color("#ffffff"))
	_apply_soft_outline(img, C_OUTLINE)
	return img


static func _draw_mossy_rock() -> Image:
	var img := _new_canvas(26, 22)
	_ellipse(img, 13, 18, 9, 2, C_SHADOW)
	_ellipse(img, 13, 14, 8, 5, Color("#64686e"))
	_ellipse(img, 12, 13, 6, 4, Color("#848991"))
	_ellipse(img, 11, 11, 5, 2, Color("#34a853"))
	_ellipse(img, 12, 10, 3, 1, Color("#5ce07a"))
	_px(img, 16, 14, Color("#ffd166"))
	_apply_soft_outline(img, Color("#22252a"))
	return img


static func _draw_tall_grass() -> Image:
	var img := _new_canvas(20, 20)
	var blades := [4, 7, 10, 13, 16]
	for i in range(blades.size()):
		var bx: int = blades[i]
		var top_y: int = 5 + (i % 2) * 2
		var bend: int = -1 if i % 2 == 0 else 1
		_line(img, bx, 17, bx + bend, top_y, Color("#248243"))
		_line(img, bx + 1, 17, bx + bend + 1, top_y + 1, Color("#46bf6b"))
		_px(img, bx + bend, top_y - 1, Color("#eab308"))
	_apply_soft_outline(img, Color("#152e1c"))
	return img


static func _draw_dry_scrub() -> Image:
	var img := _new_canvas(22, 20)
	_ellipse(img, 11, 17, 6, 2, C_SHADOW)
	_line(img, 11, 16, 6, 9, Color("#784b27"))
	_line(img, 11, 16, 16, 8, Color("#784b27"))
	_line(img, 11, 16, 11, 7, Color("#996236"))
	_line(img, 9, 13, 5, 12, Color("#996236"))
	_line(img, 13, 12, 17, 11, Color("#996236"))
	_apply_soft_outline(img, Color("#2b1b0e"))
	return img


static func _draw_rock_mountain() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 27, 10, 3, C_SHADOW)
	# Craggy alpine peak
	for y in range(8, 27):
		var progress := float(y - 8) / 18.0
		var half_w := int(2.0 + progress * 9.0)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#6c6965")
			if dx < -2:
				col = Color("#8c8781")
			elif dx > 2:
				col = Color("#4f4c49")
			if y < 14 + (abs(dx) % 2):
				col = Color("#f4f9fc") if dx <= 0 else Color("#cfe0eb")
			_px(img, 16 + dx, y, col)
	_apply_soft_outline(img, Color("#242220"))
	return img


static func _draw_coastal_reeds() -> Image:
	var img := _new_canvas(24, 24)
	var stalks := [7, 10, 13, 16]
	for idx in range(stalks.size()):
		var sx: int = stalks[idx]
		var top_y: int = 6 + (idx % 2) * 2
		_line(img, sx, 20, sx, top_y, Color("#3d8c40"))
		_rect(img, sx - 1, top_y + 1, 2, 4, Color("#6b3e26"))
	_rect(img, 15, 18, 4, 3, Color("#ff9ebb"))
	_px(img, 16, 19, Color("#ffd6e0"))
	_apply_soft_outline(img, Color("#1d2b1f"))
	return img


static func _draw_tree_stump() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 19, 7, 2, C_SHADOW)
	_rect(img, 7, 13, 10, 6, Color("#6e3f23"))
	_rect(img, 8, 13, 4, 6, Color("#854f2d"))
	_px(img, 6, 18, Color("#593119"))
	_px(img, 17, 18, Color("#593119"))
	_ellipse(img, 12, 13, 5, 2, Color("#deb887"))
	_ellipse(img, 12, 13, 3, 1, Color("#b88655"))
	_px(img, 12, 13, Color("#6e3f23"))
	_apply_soft_outline(img, C_OUTLINE)
	return img


static func _draw_soil_crack() -> Image:
	var img := _new_canvas(24, 24)
	_line(img, 4, 12, 11, 14, Color("#3b1f0e"))
	_line(img, 11, 14, 19, 10, Color("#3b1f0e"))
	_line(img, 11, 14, 14, 20, Color("#3b1f0e"))
	_line(img, 8, 13, 5, 18, Color("#593119"))
	_line(img, 4, 11, 11, 13, Color("#8a5432"))
	return img


static func _draw_wildflowers() -> Image:
	var img := _new_canvas(24, 24)
	var spots := [
		{"x": 7, "y": 14, "c": Color("#ff6b8b")},
		{"x": 13, "y": 11, "c": Color("#ffd166")},
		{"x": 17, "y": 15, "c": Color("#70d6ff")},
		{"x": 10, "y": 18, "c": Color("#ff9f1c")}
	]
	for sp in spots:
		var sx: int = sp["x"]
		var sy: int = sp["y"]
		var fl_col: Color = sp["c"]
		_line(img, sx, sy + 1, sx, sy + 4, Color("#2d8a4e"))
		_px(img, sx - 1, sy, fl_col)
		_px(img, sx + 1, sy, fl_col)
		_px(img, sx, sy - 1, fl_col)
		_px(img, sx, sy + 1, fl_col)
		_px(img, sx, sy, Color("#fff3b0"))
	return img


# ============================================================================
# VILLAGE BUILDINGS BY TIER (32x32 / 44x44 / 48x48)
# ============================================================================

static func _draw_tier1_tent() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 27, 11, 3, C_SHADOW)
	for y in range(10, 27):
		var half_w := int(float(y - 9) * 0.65)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#e8d1a7") if dx < 0 else Color("#cbb082")
			if abs(dx) <= 2 and y >= 18:
				col = Color("#3d2314")
			elif y == 14 or y == 20:
				col = col.darkened(0.08)
			_px(img, 16 + dx, y, col)
	_rect(img, 15, 8, 2, 3, Color("#6b3e26"))
	_apply_soft_outline(img)
	return img


static func _draw_tier1_campfire(frame: int) -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 18, 6, 2, C_SHADOW)
	_rect(img, 6, 16, 12, 3, Color("#6b3e26"))
	_rect(img, 8, 15, 8, 4, Color("#8c5230"))
	_circle(img, 7, 18, 2, Color("#78716c"))
	_circle(img, 17, 18, 2, Color("#78716c"))
	_circle(img, 12, 19, 2, Color("#57534e"))
	var flame_shift := -1 if frame == 0 else 1
	_ellipse(img, 12 + flame_shift, 13, 4, 4, Color("#ef4444"))
	_ellipse(img, 12, 13, 3, 3, Color("#f97316"))
	_ellipse(img, 12 - flame_shift, 14, 2, 2, Color("#fde047"))
	_px(img, 12 + flame_shift, 7 + frame, Color("#fb923c"))
	_apply_soft_outline(img)
	return img


static func _draw_tier2_cottage() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 31, 13, 3, C_SHADOW)
	_rect(img, 24, 7, 4, 9, Color("#78716c"))
	_rect(img, 23, 6, 6, 2, Color("#57534e"))
	_rect(img, 8, 17, 20, 13, Color("#b07d4f"))
	for y in range(18, 30, 3):
		_line(img, 8, y, 27, y, Color("#8c5830"))
	for y in range(8, 19):
		var half_w := 3 + int(float(y - 8) * 1.1)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#a8382b") if (y + dx) % 2 == 0 else Color("#8f2b20")
			if dx < 0:
				col = col.lightened(0.10)
			_px(img, 18 + dx, y, col)
	_rect(img, 13, 22, 4, 8, Color("#5c3317"))
	_px(img, 16, 26, Color("#fbbf24"))
	_rect(img, 20, 21, 5, 4, Color("#fde047"))
	_line(img, 22, 21, 22, 24, Color("#6b3e26"))
	_line(img, 20, 22, 24, 22, Color("#6b3e26"))
	_apply_soft_outline(img)
	return img


static func _draw_tier2_barn() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 31, 13, 3, C_SHADOW)
	_rect(img, 8, 16, 20, 14, Color("#b9382c"))
	_rect(img, 9, 16, 9, 14, Color("#cf4638"))
	for y in range(7, 17):
		var half_w := 4 + int(float(y - 7) * 1.05)
		for dx in range(-half_w, half_w + 1):
			_px(img, 18 + dx, y, Color("#6b3e26") if (y % 2 == 0) else Color("#542f1b"))
	_rect_outlined(img, 13, 21, 10, 9, Color("#9e2a20"), Color("#f5ebe0"))
	_line(img, 13, 21, 22, 29, Color("#f5ebe0"))
	_line(img, 22, 21, 13, 29, Color("#f5ebe0"))
	_rect(img, 16, 13, 4, 4, Color("#3b2112"))
	_rect(img, 16, 15, 4, 2, Color("#eab308"))
	_apply_soft_outline(img)
	return img


static func _draw_tier3_townhall() -> Image:
	var img := _new_canvas(44, 44)
	_ellipse(img, 22, 38, 17, 4, C_SHADOW)
	_rect(img, 7, 20, 30, 17, Color("#e6ccb2"))
	_rect(img, 7, 32, 30, 5, Color("#78716c"))
	for px_i in [7, 15, 28, 36]:
		_rect(img, px_i, 20, 2, 17, Color("#6b3e26"))
	for y in range(11, 21):
		var half_w := 6 + int(float(y - 11) * 1.3)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#3b6e8c") if (dx + y) % 2 == 0 else Color("#2d5873")
			if dx < 0:
				col = col.lightened(0.12)
			_px(img, 22 + dx, y, col)
	_rect(img, 17, 6, 10, 15, Color("#d4a373"))
	for y in range(2, 7):
		var hw := 1 + (y - 2) * 1
		_rect(img, 22 - hw, y, hw * 2 + 1, 1, Color("#b5651d"))
	_circle(img, 22, 13, 3, Color("#fefae0"))
	_px(img, 22, 13, C_OUTLINE)
	_px(img, 22, 11, C_OUTLINE)
	_px(img, 24, 13, C_OUTLINE)
	_rect(img, 19, 28, 6, 9, Color("#5c3317"))
	_rect(img, 10, 24, 4, 5, Color("#fde047"))
	_rect(img, 30, 24, 4, 5, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_tier3_house() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 31, 13, 3, C_SHADOW)
	_rect(img, 8, 17, 20, 13, Color("#f2d0a9"))
	_rect(img, 8, 27, 20, 3, Color("#8d99ae"))
	for y in range(8, 18):
		var hw := 3 + int(float(y - 8) * 1.1)
		for dx in range(-hw, hw + 1):
			_px(img, 18 + dx, y, Color("#c85a32") if dx < 0 else Color("#a64421"))
	_rect(img, 11, 22, 4, 8, Color("#6b3e26"))
	_rect(img, 19, 20, 6, 5, Color("#fde047"))
	_rect(img, 18, 25, 8, 2, Color("#6b3e26"))
	_px(img, 19, 24, Color("#ff5964"))
	_px(img, 21, 24, Color("#2ec4b6"))
	_px(img, 24, 24, Color("#ffbe0b"))
	_apply_soft_outline(img)
	return img


static func _draw_tier4_citadel() -> Image:
	var img := _new_canvas(48, 48)
	_ellipse(img, 24, 42, 19, 4, C_SHADOW)
	_rect(img, 6, 24, 36, 17, Color("#9ca3af"))
	_rect(img, 8, 24, 16, 17, Color("#d1d5db"))
	_rect(img, 5, 16, 8, 25, Color("#9ca3af"))
	_rect(img, 35, 16, 8, 25, Color("#6b7280"))
	_rect(img, 14, 12, 20, 16, Color("#e5e7eb"))
	for y in range(4, 13):
		var hw := 2 + int(float(y - 4) * 1.15)
		_rect(img, 24 - hw, y, hw * 2 + 1, 1, Color("#1d4ed8") if y % 2 == 0 else Color("#2563eb"))
	for cx in [9, 39]:
		for y in range(10, 17):
			var hw := 1 + int(float(y - 10) * 0.65)
			_rect(img, cx - hw, y, hw * 2 + 1, 1, Color("#b45309"))
	_circle(img, 24, 18, 3, Color("#fbbf24"))
	_rect(img, 20, 31, 8, 10, Color("#451a03"))
	_rect(img, 15, 19, 3, 4, Color("#fde047"))
	_rect(img, 30, 19, 3, 4, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_tier4_windmill() -> Image:
	var img := _new_canvas(40, 40)
	_ellipse(img, 20, 35, 11, 3, C_SHADOW)
	for y in range(12, 35):
		var hw := 4 + int(float(y - 12) * 0.22)
		_rect(img, 20 - hw, y, hw * 2, 1, Color("#f3e5ab") if y % 3 != 0 else Color("#e0ce8b"))
	_ellipse(img, 20, 12, 5, 3, Color("#8c3b2b"))
	_line(img, 7, 4, 33, 24, Color("#6b3e26"))
	_line(img, 33, 4, 7, 24, Color("#6b3e26"))
	_line(img, 8, 4, 33, 23, Color("#fefae0"))
	_line(img, 32, 4, 7, 23, Color("#fefae0"))
	_circle(img, 20, 14, 2, Color("#d97706"))
	_rect(img, 18, 28, 4, 7, Color("#5c3317"))
	_apply_soft_outline(img)
	return img


static func _draw_tier4_tower() -> Image:
	var img := _new_canvas(32, 36)
	_ellipse(img, 16, 32, 9, 2, C_SHADOW)
	_rect(img, 10, 11, 12, 21, Color("#94a3b8"))
	_rect(img, 11, 11, 5, 21, Color("#cbd5e1"))
	for bx in [9, 13, 17, 21]:
		_rect(img, bx, 8, 2, 4, Color("#cbd5e1"))
	_rect(img, 14, 16, 4, 5, Color("#fde047"))
	_rect(img, 14, 26, 4, 6, Color("#451a03"))
	_apply_soft_outline(img)
	return img


# ============================================================================
# ARCHETYPE ACTIVITY SPRITES & INTER-VILLAGE NETWORK PROPS
# ============================================================================

static func _draw_act_forage() -> Image:
	var img := _new_canvas(32, 32)
	_rect_outlined(img, 4, 12, 24, 15, Color("#6b4226"), Color("#9c6644"))
	for row_y in [15, 19, 23]:
		_line(img, 6, row_y, 25, row_y, Color("#4a2c18"))
	for cx in [8, 14, 20, 24]:
		_circle(img, cx, 15, 2, Color("#22c55e"))
		_circle(img, cx, 21, 2, Color("#f97316"))
		_px(img, cx, 19, Color("#15803d"))
	_apply_soft_outline(img)
	return img


static func _draw_act_overexploit() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 12, 3, C_SHADOW)
	_ellipse(img, 13, 20, 9, 7, Color("#78716c"))
	_rect(img, 9, 17, 8, 9, Color("#1c1917"))
	_rect(img, 8, 16, 10, 2, Color("#8c5230"))
	_rect(img, 20, 12, 7, 15, Color("#57534e"))
	_rect(img, 22, 22, 3, 4, Color("#f97316"))
	_circle(img, 23, 8, 3, Color("#9ca3af"))
	_circle(img, 25, 5, 2, Color("#d1d5db"))
	_apply_soft_outline(img)
	return img


static func _draw_act_migrate() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 15, 27, 11, 2, C_SHADOW)
	_rect(img, 6, 18, 16, 5, Color("#8c5230"))
	_ellipse(img, 14, 15, 8, 5, Color("#f5ebe0"))
	_line(img, 11, 11, 11, 18, Color("#d6c7b2"))
	_line(img, 17, 11, 17, 18, Color("#d6c7b2"))
	_circle(img, 9, 24, 3, Color("#5c3317"))
	_circle(img, 19, 24, 3, Color("#5c3317"))
	_rect(img, 25, 12, 2, 14, Color("#6b3e26"))
	_rect(img, 23, 14, 7, 3, Color("#deb887"))
	_apply_soft_outline(img)
	return img


static func _draw_act_cooperate() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 9, 2, C_SHADOW)
	_rect(img, 10, 11, 12, 17, Color("#c83e31"))
	_rect(img, 11, 11, 5, 17, Color("#e05346"))
	_line(img, 10, 16, 21, 16, Color("#fbbf24"))
	_line(img, 10, 22, 21, 22, Color("#fbbf24"))
	_ellipse(img, 16, 11, 6, 4, Color("#f59e0b"))
	_ellipse(img, 15, 10, 4, 2, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_act_exchange() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 12, 2, C_SHADOW)
	_rect(img, 6, 20, 20, 7, Color("#9c6644"))
	_rect(img, 7, 12, 2, 9, Color("#6b3e26"))
	_rect(img, 23, 12, 2, 9, Color("#6b3e26"))
	for x in range(5, 27):
		var stripe_col := Color("#10b981") if ((x - 5) / 3) % 2 == 0 else Color("#fefae0")
		_rect(img, x, 9, 1, 5, stripe_col)
	_circle(img, 12, 18, 2, Color("#f59e0b"))
	_circle(img, 17, 18, 2, Color("#ef4444"))
	_circle(img, 21, 18, 2, Color("#3b82f6"))
	_apply_soft_outline(img)
	return img


static func _draw_act_dispute() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 12, 2, C_SHADOW)
	for x in range(5, 26, 4):
		_rect(img, x, 14, 3, 13, Color("#7f4f24"))
		_px(img, x + 1, 12, Color("#b07d4f"))
		_rect(img, x, 13, 3, 1, Color("#b07d4f"))
	_rect(img, 14, 6, 2, 12, Color("#4a2c18"))
	_rect(img, 16, 7, 7, 5, Color("#ef4444"))
	_px(img, 18, 9, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_act_innovate() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 11, 2, C_SHADOW)
	_rect(img, 6, 19, 20, 4, Color("#8c5230"))
	_rect(img, 8, 23, 3, 5, Color("#5c3317"))
	_rect(img, 21, 23, 3, 5, Color("#5c3317"))
	_rect(img, 9, 17, 6, 2, Color("#fefae0"))
	for dy in range(-5, 6):
		var hw: int = 4 - int(abs(dy) * 0.75)
		if hw > 0:
			_rect(img, 19 - hw, 11 + dy, hw * 2, 1, Color("#38bdf8") if dy < 0 else Color("#0284c7"))
	_px(img, 18, 9, Color("#e0f2fe"))
	_apply_soft_outline(img)
	return img


static func _draw_act_custom() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 10, 2, C_SHADOW)
	for y in range(6, 27):
		var hw := 1 + int(float(y - 6) * 0.2)
		_rect(img, 16 - hw, y, hw * 2 + 1, 1, Color("#fbbf24") if y % 2 == 0 else Color("#d97706"))
	_rect(img, 11, 25, 11, 3, Color("#78716c"))
	_px(img, 16, 12, Color("#a855f7"))
	_px(img, 16, 13, Color("#e9d5ff"))
	_apply_soft_outline(img)
	return img


static func _draw_cultural_totem() -> Image:
	var img := _new_canvas(28, 32)
	_ellipse(img, 14, 28, 7, 2, C_SHADOW)
	_rect(img, 11, 8, 6, 20, Color("#7c3aed"))
	_rect(img, 12, 8, 4, 20, Color("#9333ea"))
	_rect(img, 6, 12, 16, 3, Color("#fbbf24"))
	_px(img, 12, 11, Color("#34d399"))
	_px(img, 15, 11, Color("#34d399"))
	_rect(img, 12, 17, 4, 2, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_ruins() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 27, 12, 3, C_SHADOW)
	_rect(img, 7, 19, 6, 8, Color("#78716c"))
	_rect(img, 14, 22, 5, 5, Color("#57534e"))
	_rect(img, 20, 16, 5, 11, Color("#78716c"))
	_rect(img, 7, 18, 5, 2, Color("#4d7c0f"))
	_rect(img, 20, 15, 4, 3, Color("#65a30d"))
	_rect(img, 14, 21, 4, 2, Color("#4d7c0f"))
	_apply_soft_outline(img)
	return img


static func _draw_caravan_cart() -> Image:
	var img := _new_canvas(28, 24)
	_ellipse(img, 14, 20, 10, 2, C_SHADOW)
	# Wooden merchant cart loaded with trade goods
	_rect(img, 4, 11, 13, 5, Color("#8c5230"))
	_rect(img, 5, 12, 11, 3, Color("#b07d4f"))
	# Trade chest & golden sacks
	_rect(img, 5, 7, 5, 4, Color("#d97706"))
	_rect(img, 6, 8, 3, 2, Color("#fde047"))
	_circle(img, 13, 9, 3, Color("#eab308"))
	# Spoked wooden wheels
	_circle(img, 7, 17, 3, Color("#4a2c18"))
	_px(img, 7, 17, Color("#d6b88a"))
	_circle(img, 14, 17, 3, Color("#4a2c18"))
	_px(img, 14, 17, Color("#d6b88a"))
	# Draft ox/horse in front
	_rect(img, 18, 12, 6, 4, Color("#a16207"))
	_rect(img, 22, 9, 3, 4, Color("#a16207"))
	_line(img, 19, 16, 19, 19, Color("#713f12"))
	_line(img, 23, 16, 23, 19, Color("#713f12"))
	_apply_soft_outline(img)
	return img


static func _draw_settler_wagon() -> Image:
	var img := _new_canvas(32, 28)
	_ellipse(img, 16, 23, 12, 3, C_SHADOW)
	# Covered pioneer wagon
	_rect(img, 6, 15, 18, 5, Color("#8c5230"))
	_ellipse(img, 15, 12, 9, 6, Color("#fefae0"))
	_line(img, 11, 7, 11, 15, Color("#d4c5b1"))
	_line(img, 15, 6, 15, 15, Color("#d4c5b1"))
	_line(img, 19, 7, 19, 15, Color("#d4c5b1"))
	_circle(img, 10, 21, 3, Color("#5c3317"))
	_px(img, 10, 21, Color("#eab308"))
	_circle(img, 20, 21, 3, Color("#5c3317"))
	_px(img, 20, 21, Color("#eab308"))
	_apply_soft_outline(img)
	return img


static func _draw_barricade_spikes() -> Image:
	var img := _new_canvas(32, 28)
	_ellipse(img, 16, 23, 13, 3, C_SHADOW)
	# Horizontal heavy timber beam
	_rect(img, 5, 15, 22, 4, Color("#5c3317"))
	_rect(img, 6, 16, 20, 2, Color("#7f4f24"))
	# Diagonal sharpened cheval-de-frise log spikes
	var spike_xs := [7, 12, 17, 22]
	for sx in spike_xs:
		_line(img, sx - 3, 22, sx + 3, 7, Color("#6b3e26"))
		_line(img, sx - 2, 22, sx + 4, 7, Color("#9c6644"))
		_px(img, sx + 3, 6, Color("#fde047"))
		_line(img, sx + 3, 22, sx - 3, 8, Color("#5c3317"))
		_line(img, sx + 2, 22, sx - 2, 8, Color("#8c5230"))
	# Crimson war shield & iron bindings in center
	_circle(img, 16, 16, 4, Color("#dc2626"))
	_circle(img, 16, 16, 2, Color("#fbbf24"))
	_apply_soft_outline(img)
	return img


static func _draw_road_block_sign() -> Image:
	var img := _new_canvas(28, 26)
	_ellipse(img, 14, 22, 10, 2, C_SHADOW)
	# Overgrown weeds & cracked cobbles at base
	_ellipse(img, 10, 20, 4, 2, Color("#4d7c0f"))
	_ellipse(img, 18, 20, 4, 2, Color("#65a30d"))
	# Support posts
	_rect(img, 7, 10, 3, 12, Color("#5c3317"))
	_rect(img, 18, 10, 3, 12, Color("#5c3317"))
	# Crossed wooden X planks (road closed barrier)
	_line(img, 5, 9, 23, 19, Color("#b45309"))
	_line(img, 5, 10, 23, 20, Color("#d97706"))
	_line(img, 5, 11, 23, 21, Color("#f59e0b"))
	_line(img, 23, 9, 5, 19, Color("#b45309"))
	_line(img, 23, 10, 5, 20, Color("#d97706"))
	_line(img, 23, 11, 5, 21, Color("#f59e0b"))
	# Warning red/white stripes on top bar
	_rect(img, 5, 8, 18, 3, Color("#d97706"))
	for sx in range(6, 22, 4):
		_rect(img, sx, 8, 2, 3, Color("#ef4444"))
	_apply_soft_outline(img)
	return img


static func _draw_road_lantern() -> Image:
	var img := _new_canvas(20, 28)
	_ellipse(img, 10, 24, 5, 2, C_SHADOW)
	# Wooden lamppost & cross-arm
	_rect(img, 8, 7, 3, 17, Color("#5c3317"))
	_rect(img, 9, 7, 1, 17, Color("#8c5230"))
	_rect(img, 8, 7, 7, 2, Color("#5c3317"))
	# Warm glowing hanging lantern
	_rect(img, 12, 9, 4, 5, Color("#fbbf24"))
	_rect(img, 13, 10, 2, 3, Color("#fef08a"))
	_rect(img, 11, 8, 6, 1, Color("#374151"))
	_rect(img, 12, 14, 4, 1, Color("#374151"))
	_apply_soft_outline(img)
	return img


# ============================================================================
# ANIMATED VILLAGER SPRITES (16x16)
# ============================================================================

static func _draw_villager(step: int, tunic_color: Color) -> Image:
	var img := _new_canvas(16, 16)
	_ellipse(img, 8, 14, 4, 1, C_SHADOW)
	var bob := -1 if step != 0 else 0
	# Hair & head
	_rect(img, 6, 2 + bob, 4, 2, Color("#5c3317"))
	_rect(img, 6, 4 + bob, 4, 3, Color("#fcd5b5"))
	_px(img, 7, 5 + bob, C_OUTLINE)
	_px(img, 9, 5 + bob, C_OUTLINE)
	# Tunic / shirt in deme lineage color
	_rect(img, 5, 7 + bob, 6, 4, tunic_color)
	_rect(img, 6, 7 + bob, 4, 3, tunic_color.lightened(0.18))
	# Trousers & walking legs
	var left_y := 11
	var right_y := 11
	if step == 1:
		left_y = 10
		right_y = 12
	elif step == 2:
		left_y = 12
		right_y = 10
	_rect(img, 6, left_y, 2, 3, Color("#3b4252"))
	_rect(img, 8, right_y, 2, 3, Color("#3b4252"))
	_apply_soft_outline(img)
	return img


# ============================================================================
# UI & INTERACTION PIXEL ART ICONS (24x24 / 28x28)
# ============================================================================

static func _draw_ui_icon(icon_name: String) -> Image:
	if icon_name == "thought_bubble":
		return _draw_thought_bubble()

	var img := _new_canvas(24, 24)
	match icon_name:
		"tool_inspect":
			_circle(img, 10, 10, 6, Color("#38bdf8"))
			_circle(img, 10, 10, 4, Color("#bae6fd"))
			_line(img, 14, 14, 20, 20, Color("#8c5230"))
			_line(img, 15, 14, 20, 19, Color("#d97706"))
		"tool_biome":
			_ellipse(img, 12, 15, 5, 5, Color("#d4a373"))
			_line(img, 12, 10, 12, 5, Color("#22c55e"))
			_ellipse(img, 9, 7, 3, 2, Color("#4ade80"))
			_ellipse(img, 15, 7, 3, 2, Color("#22c55e"))
		"tool_altitude":
			_line(img, 5, 19, 18, 6, Color("#8c5230"))
			_line(img, 6, 19, 18, 7, Color("#b07d4f"))
			_line(img, 13, 4, 20, 11, Color("#94a3b8"))
			_line(img, 14, 4, 20, 10, Color("#e2e8f0"))
		"tool_fertility":
			_rect(img, 7, 11, 9, 8, Color("#fbbf24"))
			_rect(img, 8, 12, 7, 6, Color("#fde047"))
			_line(img, 16, 15, 21, 10, Color("#f59e0b"))
			_circle(img, 5, 14, 2, Color("#d97706"))
		"tool_sealevel":
			_ellipse(img, 12, 13, 7, 5, Color("#38bdf8"))
			_ellipse(img, 12, 11, 5, 3, Color("#7dd3fc"))
			_line(img, 4, 18, 20, 18, Color("#0284c7"))
		"season_wet":
			_circle(img, 12, 12, 5, Color("#fbbf24"))
			_circle(img, 12, 12, 3, Color("#fde047"))
			_ellipse(img, 16, 16, 4, 2, Color("#22c55e"))
		"season_dry":
			_line(img, 12, 4, 12, 20, Color("#7dd3fc"))
			_line(img, 4, 12, 20, 12, Color("#7dd3fc"))
			_line(img, 6, 6, 18, 18, Color("#bae6fd"))
			_line(img, 18, 6, 6, 18, Color("#bae6fd"))
		"status_thriving":
			_draw_heart(img, Color("#10b981"), Color("#6ee7b7"))
		"status_stable":
			_draw_heart(img, Color("#0ea5e9"), Color("#7dd3fc"))
		"status_struggling":
			_draw_heart(img, Color("#f59e0b"), Color("#fde047"))
		"status_starving":
			_draw_heart(img, Color("#ef4444"), Color("#fca5a5"))
		"icon_forage":
			_circle(img, 12, 13, 6, Color("#22c55e"))
			_circle(img, 10, 11, 2, Color("#ef4444"))
			_circle(img, 15, 14, 2, Color("#fbbf24"))
		"icon_overexploit":
			_ellipse(img, 12, 15, 6, 5, Color("#f97316"))
			_rect(img, 10, 6, 4, 6, Color("#78716c"))
		"icon_migrate":
			_rect(img, 6, 11, 12, 6, Color("#38bdf8"))
			_circle(img, 9, 18, 2, Color("#8c5230"))
			_circle(img, 15, 18, 2, Color("#8c5230"))
		"icon_cooperate":
			_rect(img, 8, 9, 8, 11, Color("#ef4444"))
			_ellipse(img, 12, 9, 4, 3, Color("#fbbf24"))
		"icon_exchange":
			_rect(img, 5, 7, 14, 4, Color("#10b981"))
			_rect(img, 6, 11, 12, 8, Color("#d4a373"))
		"icon_dispute":
			_line(img, 6, 18, 18, 6, Color("#ef4444"))
			_line(img, 6, 6, 18, 18, Color("#fca5a5"))
		"icon_innovate":
			_circle(img, 12, 12, 5, Color("#a855f7"))
			_circle(img, 12, 12, 3, Color("#e9d5ff"))
		"icon_coop_link":
			# Emerald medallion with golden alliance chest / clasped hands
			_circle(img, 12, 12, 9, Color("#059669"))
			_circle(img, 12, 12, 7, Color("#10b981"))
			_rect(img, 7, 10, 10, 6, Color("#d97706"))
			_rect(img, 7, 8, 10, 3, Color("#fbbf24"))
			_rect(img, 11, 10, 2, 3, Color("#fef08a"))
		"icon_conflict_swords":
			# Crimson war shield with crossed steel swords
			_circle(img, 12, 12, 9, Color("#991b1b"))
			_circle(img, 12, 12, 7, Color("#ef4444"))
			_line(img, 6, 18, 18, 6, Color("#f8fafc"))
			_line(img, 7, 18, 18, 7, Color("#cbd5e1"))
			_line(img, 6, 6, 18, 18, Color("#f8fafc"))
			_line(img, 7, 6, 18, 17, Color("#cbd5e1"))
			_circle(img, 12, 12, 2, Color("#fde047"))
		"icon_broken_link":
			# Amber warning badge with broken chain / X
			_circle(img, 12, 12, 9, Color("#78350f"))
			_circle(img, 12, 12, 7, Color("#d97706"))
			_rect(img, 5, 10, 5, 4, Color("#e2e8f0"))
			_rect(img, 14, 10, 5, 4, Color("#e2e8f0"))
			_line(img, 10, 7, 14, 17, Color("#ef4444"))
			_line(img, 14, 7, 10, 17, Color("#ef4444"))
		_:
			_circle(img, 12, 12, 6, Color("#eab308"))
	_apply_soft_outline(img)
	return img


static func _draw_thought_bubble() -> Image:
	var img := _new_canvas(28, 28)
	# Cloud-shaped pixel-art comic bubble
	_ellipse(img, 14, 12, 10, 8, Color("#fffbeb"))
	_circle(img, 8, 12, 5, Color("#fffbeb"))
	_circle(img, 20, 12, 5, Color("#fffbeb"))
	_circle(img, 14, 7, 5, Color("#fffbeb"))
	# Bottom thought tail droplets
	_circle(img, 9, 22, 2, Color("#fffbeb"))
	_circle(img, 6, 25, 1, Color("#fffbeb"))
	_apply_soft_outline(img, Color("#4a2c18"))
	return img


static func _draw_heart(img: Image, main_col: Color, hi_col: Color) -> void:
	_circle(img, 9, 10, 4, main_col)
	_circle(img, 15, 10, 4, main_col)
	for y in range(11, 19):
		var hw := 19 - y
		_rect(img, 12 - hw, y, hw * 2 + 1, 1, main_col)
	_px(img, 8, 8, hi_col)
	_px(img, 9, 8, hi_col)
