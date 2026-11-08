class_name EvoPropFloraRenderer
extends RefCounted

const C_SELECTION := Color("#fde047")

const STATUS_COLORS: Dictionary = {
	"thriving": Color("#34d399"),
	"stable": Color("#38bdf8"),
	"struggling": Color("#fbbf24"),
	"starving": Color("#fb7185")
}

const NON_SWAYING_SPRITES: Array[String] = ["mossy_rock", "fallen_log", "rock_mountain", "mountain_peak", "tree_stump", "soil_crack", "ruins_stone", "crop_field", "pasture_pen"]
const VILLAGER_POSES: Array[String] = ["villager_idle", "villager_walk1", "villager_walk2"]
const TRAVELER_ROAD_KINDS: Array[String] = ["collab", "bridge", "pact", "tribute", "merge", "rural_farm"]

const BIOME_FLORA_PALETTES: Dictionary = {
	"tropical_forest": [
		"tree_tropical", "tree_tropical_2", "bush_berry", "wildflowers",
		"tree_tropical", "fallen_log", "tall_grass", "mossy_rock",
		"tree_tropical_2", "bush_berry", "wildflowers", "tall_grass"
	],
	"savanna": [
		"tree_savanna", "tall_grass", "tree_savanna_2", "wildflowers",
		"mossy_rock", "tall_grass", "tree_savanna", "bush_berry",
		"fallen_log", "tall_grass"
	],
	"arid_steppe": [
		"bush_arid", "dry_scrub", "mossy_rock", "bush_arid",
		"rock_mountain", "dry_scrub", "soil_crack", "bush_arid"
	],
	"tundra": [
		"tree_tundra", "tree_tundra_2", "mossy_rock", "tree_tundra",
		"rock_mountain", "tree_tundra_2", "fallen_log", "bush_berry"
	],
	"high_mountain": [
		"mountain_peak", "rock_mountain", "mossy_rock", "tree_tundra",
		"mountain_peak", "mossy_rock", "tree_tundra_2", "rock_mountain"
	],
	"coastal_shallows": [
		"coastal_reeds", "wildflowers", "coastal_reeds", "tall_grass",
		"mossy_rock", "coastal_reeds"
	]
}
const DEFAULT_FLORA_PALETTE: Array[String] = ["tree_savanna", "wildflowers", "tall_grass"]


class Prop:
	var hex_id: String = ""
	var world_xy: Vector2
	var top_z: float
	var screen_offset: Vector2
	var anchor_offset: Vector2
	var y: float
	var texture: Texture2D
	var rect: Rect2
	var modulate: Color
	var trim_color: Color = Color.TRANSPARENT
	var sways: bool = false
	var sway_phase: float = 0.0

	func _init(p_texture: Texture2D, scale: float, anchor_y: float, p_modulate: Color) -> void:
		texture = p_texture
		var tex_sz := p_texture.get_size()
		var dpi_norm: float = 0.32 if tex_sz.x <= 64.0 else 0.24
		var size := tex_sz * (scale * dpi_norm)
		anchor_offset = Vector2(size.x * 0.5, size.y * anchor_y)
		rect = Rect2(Vector2.ZERO, size)
		modulate = p_modulate

	func set_foot(foot: Vector2) -> void:
		rect.position = foot - anchor_offset
		y = foot.y

	func project(ground: Transform2D, lift: float) -> void:
		set_foot(ground * world_xy + Vector2(0.0, -top_z * lift) + screen_offset)


static func resolve_deme_strategy_color(world_state: EvoTypes.WorldState, deme: EvoTypes.Deme) -> Color:
	var fallback := Color.from_string(deme.color, Color(0.88, 0.48, 0.37))
	if world_state != null and world_state.strategies_catalog.has(deme.strategy_id):
		var strategy: EvoTypes.StrategyDef = world_state.strategies_catalog[deme.strategy_id]
		return Color.from_string(strategy.color, fallback)
	return fallback


static func get_villager_textures_for_color(r: Node2D, tunic_col: Color) -> Array[ImageTexture]:
	var hex_key := tunic_col.to_html(false)
	if r._villager_tex_sets.has(hex_key):
		return r._villager_tex_sets[hex_key]
	var tex_set: Array[ImageTexture] = [
		EvoPixelArtGen.get_villager_texture(VILLAGER_POSES[0], tunic_col),
		EvoPixelArtGen.get_villager_texture(VILLAGER_POSES[1], tunic_col),
		EvoPixelArtGen.get_villager_texture(VILLAGER_POSES[2], tunic_col)
	]
	r._villager_tex_sets[hex_key] = tex_set
	return tex_set


static func collect_villages(r: Node2D) -> Array[Dictionary]:
	var villages: Array[Dictionary] = []
	r._village_by_deme_id.clear()
	r._rural_cell_ids.clear()
	var state: EvoTypes.WorldState = r.world_state
	var geo_by_deme := build_geopolitics_by_deme(state)
	var hex_list: Array = r._sorted_hex_ids if not r._sorted_hex_ids.is_empty() else state.cells.keys()
	for hex_id in hex_list:
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		if r._is_water(cell):
			continue
		if cell.deme_ids.is_empty():
			if (cell.land_use in ["crops", "pasture"]) and cell.owner_deme_id != "":
				r._rural_cell_ids.append(hex_id)
			continue
		var deme_id: String = cell.deme_ids[0]
		if not state.demes.has(deme_id):
			continue
		var deme: EvoTypes.Deme = state.demes[deme_id]
		var world_xy := HexMath.axial_to_world(cell.q, cell.r)
		var top_z: float = r._get_cell_top_z(cell)
		var v_world := world_xy + HexMath.compute_village_sector_offset(0, 1, HexMath.HEX_SIZE)
		var scale_factor := 1.0
		var is_dimmed: bool = r.highlighted_lineage_id != "" and deme.lineage_id != r.highlighted_lineage_id
		var tier := deme.get_village_tier()
		var strat_vis := EvoWorldOverlayRenderer._resolve_deme_strategy_visuals(state, deme, r.lang)
		var strat_color: Color = strat_vis["color"]

		var bb_offset := Vector2(0.0, -68.0)
		var sub_text := "%d pop" % deme.population if r.lang == "en" else "%d hab" % deme.population
		var box_size := Vector2(124.0, 32.0)
		var v_pos: Vector2 = r._project(v_world, top_z)
		var vital_status := deme.get_vital_status()
		var status_col: Color = STATUS_COLORS[vital_status] if STATUS_COLORS.has(vital_status) else Color("#38bdf8")
		var geo: Dictionary = geo_by_deme[deme.id] if geo_by_deme.has(deme.id) else resolve_deme_geopolitics(state, deme)

		var v_entry := {
			"deme": deme,
			"deme_id": deme.id,
			"hex_id": hex_id,
			"world_xy": v_world,
			"top_z": top_z,
			"pos": v_pos,
			"sf": scale_factor,
			"modulate": Color(1, 1, 1, 0.42) if is_dimmed else Color.WHITE,
			"is_dimmed": is_dimmed,
			"tier": tier,
			"salubrity": deme.salubrity,
			"walled_union_id": deme.walled_union_id,
			"archetype": get_deme_dominant_archetype(r, deme),
			"has_pact": geo["has_pact"],
			"in_war": geo["in_war"],
			"in_raid": geo["in_raid"],
			"in_betrayal": geo["in_betrayal"],
			"in_tribute": geo["in_tribute"],
			"in_siege": geo["in_siege"],
			"in_merge": geo["in_merge"],
			"geo_icons": geo["geo_icons"],
			"status_col": status_col,
			"strat_color": strat_color,
			"strat_visuals": strat_vis,
			"villager_count": clampi(3 + tier + int(deme.population / 95), 3, 9),
			"villager_textures": get_villager_textures_for_color(r, strat_color),
			"bb_offset": bb_offset,
			"sub_text": sub_text,
			"label_text": sub_text,
			"box_size": box_size,
			"pill_w": box_size.x,
			"hit_rect": Rect2(v_pos - Vector2(104, 92), Vector2(208, 168))
		}
		villages.append(v_entry)
		r._village_by_deme_id[deme.id] = v_entry
	return villages


static func get_village_building_layout(
	tier: int,
	sf: float,
	has_culture: bool,
	cultural_count: int,
	archetype: String
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var totem_sprite := "totem_innov"
	if archetype in ["cooperate", "pact", "exchange"]:
		totem_sprite = "totem_coop"
	elif archetype in ["war", "raid", "dispute", "betrayal"]:
		totem_sprite = "totem_aggro"

	match tier:
		1:
			items.append({"sprite": "campfire", "offset": Vector2(0, 6) * sf, "scale": 2.35 * sf})
			items.append({"sprite": "hut_thatch", "offset": Vector2(-68, -24) * sf, "scale": 2.48 * sf})
			items.append({"sprite": "hut_thatch", "offset": Vector2(66, -20) * sf, "scale": 2.44 * sf})
			items.append({"sprite": "hut_thatch", "offset": Vector2(-18, -54) * sf, "scale": 2.38 * sf})
		2:
			items.append({"sprite": "temple_totem" if has_culture else "campfire", "offset": Vector2(0, -20) * sf, "scale": 2.52 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(-76, -28) * sf, "scale": 2.48 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(76, -26) * sf, "scale": 2.46 * sf})
			items.append({"sprite": "hut_thatch", "offset": Vector2(-92, 18) * sf, "scale": 2.36 * sf})
			items.append({"sprite": "hut_thatch", "offset": Vector2(90, 20) * sf, "scale": 2.36 * sf})
			items.append({"sprite": "hut_thatch", "offset": Vector2(0, -64) * sf, "scale": 2.38 * sf})
			items.append({"sprite": "granary", "offset": Vector2(-48, 44) * sf, "scale": 2.40 * sf})
			items.append({"sprite": "watchtower", "offset": Vector2(56, -56) * sf, "scale": 2.42 * sf})
		3:
			items.append({"sprite": "temple_totem", "offset": Vector2(0, -26) * sf, "scale": 2.60 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(-64, -46) * sf, "scale": 2.48 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(64, -46) * sf, "scale": 2.48 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(0, -76) * sf, "scale": 2.44 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(-106, -8) * sf, "scale": 2.42 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(106, -8) * sf, "scale": 2.42 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(-86, 34) * sf, "scale": 2.38 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(86, 34) * sf, "scale": 2.38 * sf})
			items.append({"sprite": "granary", "offset": Vector2(-46, 52) * sf, "scale": 2.45 * sf})
			items.append({"sprite": "windmill", "offset": Vector2(110, -48) * sf, "scale": 2.52 * sf})
			items.append({"sprite": "watchtower", "offset": Vector2(-112, -48) * sf, "scale": 2.48 * sf})
		_:
			items.append({"sprite": "citadel_keep", "offset": Vector2(-24, -36) * sf, "scale": 2.72 * sf})
			items.append({"sprite": "cathedral", "offset": Vector2(34, -32) * sf, "scale": 2.64 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(0, -84) * sf, "scale": 2.48 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(-74, -62) * sf, "scale": 2.46 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(76, -62) * sf, "scale": 2.46 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(-116, -16) * sf, "scale": 2.44 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(116, -16) * sf, "scale": 2.44 * sf})
			items.append({"sprite": "house_stone", "offset": Vector2(-62, 16) * sf, "scale": 2.40 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(64, 16) * sf, "scale": 2.38 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(-96, 34) * sf, "scale": 2.38 * sf})
			items.append({"sprite": "house_clay", "offset": Vector2(96, 34) * sf, "scale": 2.38 * sf})
			items.append({"sprite": "granary", "offset": Vector2(-48, 56) * sf, "scale": 2.48 * sf})
			items.append({"sprite": "windmill", "offset": Vector2(122, -54) * sf, "scale": 2.55 * sf})
			items.append({"sprite": "watchtower", "offset": Vector2(-124, -54) * sf, "scale": 2.52 * sf})
			items.append({"sprite": "watchtower", "offset": Vector2(0, 68) * sf, "scale": 2.48 * sf})

	if has_culture:
		var totem_scale := (2.18 + mini(3, cultural_count) * 0.14) * sf
		var totem_off := Vector2(-58, 32) * sf if tier == 1 else Vector2(-34, 14) * sf
		items.append({"sprite": totem_sprite, "offset": totem_off, "scale": totem_scale})

	var act_offset := Vector2(58, 28) * sf if tier == 1 else Vector2(48, 50) * sf
	items.append({"sprite": "act_" + archetype, "offset": act_offset, "scale": 2.30 * sf})
	return items


static func draw_village_plaza(r: Node2D, village: Dictionary) -> void:
	_draw_village(r, village)


static func _draw_village(r: Node2D, village: Dictionary) -> void:
	var v_pos: Vector2 = village["pos"]
	if r._visible_world_rect.size != Vector2.ZERO and not r._visible_world_rect.grow(HexMath.HEX_SIZE * 1.5).has_point(v_pos):
		return
	var ci: Node2D = r._network_layer
	var deme: EvoTypes.Deme = village["deme"]
	var sf: float = village["sf"]
	var modulate_col: Color = village["modulate"]
	var status_col: Color = village["status_col"]
	var plaza_center: Vector2 = v_pos + Vector2(0, 8.0 * sf)
	var strat_color: Color = village["strat_color"]
	var strat_hi := strat_color.lightened(0.25)

	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, v_pos + Vector2(0, -4.0 * sf), 132.0 * sf, 76.0 * sf, Color(0.36, 0.25, 0.16, 0.34) * modulate_col)
	var eff_tier: int = 4 if (deme.merged_count >= 1 or deme.walled_union_id != "") else int(village["tier"])
	var layout := get_village_building_layout(
		eff_tier,
		sf,
		not deme.cultural_trait_ids.is_empty(),
		deme.cultural_trait_ids.size(),
		str(village["archetype"])
	)
	for b_item in layout:
		var b_foot: Vector2 = v_pos + (b_item["offset"] as Vector2)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, b_foot + Vector2(0, -3.0 * sf), 28.0 * sf, 15.5 * sf, Color("#7c5c3b") * modulate_col)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, b_foot + Vector2(0, -3.0 * sf), 23.0 * sf, 12.5 * sf, Color("#cbb082") * modulate_col)

	var is_merged: bool = deme.merged_count > 0 or deme.walled_union_id != ""
	var plinth_r := (58.0 if is_merged else 52.0) * sf
	var rim_r := plinth_r + 5.5 * sf
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, rim_r, rim_r * 0.58, Color("#5c4028") * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r, plinth_r * 0.58, Color("#c2a378") * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r * 0.74, plinth_r * 0.74 * 0.58, Color("#d9be96") * modulate_col)
	if is_merged:
		EvoWorldOverlayRenderer.draw_ellipse_outline(
			ci,
			plaza_center,
			plinth_r * 0.64,
			plinth_r * 0.64 * 0.58,
			Color("#fbbf24") * modulate_col,
			2.4 * sf
		)

	# Inner Strategy Mosaic / Carpet Ring
	var mosaic_outer_r := plinth_r * 0.52
	var mosaic_inner_r := plinth_r * 0.36
	EvoWorldOverlayRenderer.draw_ellipse_filled(
		ci,
		plaza_center,
		mosaic_outer_r,
		mosaic_outer_r * 0.58,
		strat_color.darkened(0.22) * modulate_col
	)
	EvoWorldOverlayRenderer.draw_ellipse_filled(
		ci,
		plaza_center,
		mosaic_inner_r,
		mosaic_inner_r * 0.58,
		strat_color * modulate_col
	)
	EvoWorldOverlayRenderer.draw_ellipse_outline(
		ci,
		plaza_center,
		mosaic_outer_r,
		mosaic_outer_r * 0.58,
		strat_hi * modulate_col,
		2.2 * sf
	)
	EvoWorldOverlayRenderer.draw_ellipse_filled(
		ci,
		plaza_center,
		plinth_r * 0.14,
		plinth_r * 0.14 * 0.58,
		Color("#fef3c7") * modulate_col
	)

	for c_i in range(14):
		var c_ang := TAU * float(c_i) / 14.0
		var c_pt := plaza_center + Vector2(cos(c_ang) * plinth_r * 0.84, sin(c_ang) * plinth_r * 0.48)
		ci.draw_circle(c_pt, 4.4 * sf, (strat_color.darkened(0.15) if c_i % 2 == 0 else Color("#a38358")) * modulate_col)

	# Village Plaza Wooden Banner Pole / Strategy Totem with Pennant Flag
	var pole_base := plaza_center + Vector2(-15.0 * sf, -6.0 * sf)
	var pole_top := pole_base + Vector2(0.0, -26.0 * sf)
	ci.draw_circle(pole_base + Vector2(0.0, 1.5 * sf), 3.6 * sf, Color(0.0, 0.0, 0.0, 0.32) * modulate_col)
	ci.draw_line(pole_base, pole_top, Color("#5c3317") * modulate_col, 3.2 * sf)
	ci.draw_line(pole_base + Vector2(-0.6 * sf, 0.0), pole_top + Vector2(-0.6 * sf, 0.0), Color("#8c5230") * modulate_col, 1.4 * sf)
	ci.draw_circle(pole_top, 2.5 * sf, Color("#fbbf24") * modulate_col)

	var wave := sin(r._anim_time * 4.2 + v_pos.x * 0.04) * 2.0 * sf
	var flag_pts := PackedVector2Array([
		pole_top + Vector2(1.0 * sf, 1.0 * sf),
		pole_top + Vector2(19.0 * sf, 4.5 * sf + wave),
		pole_top + Vector2(1.0 * sf, 11.0 * sf)
	])
	ci.draw_colored_polygon(flag_pts, strat_color * modulate_col)
	var flag_hi_pts := PackedVector2Array([
		pole_top + Vector2(1.0 * sf, 1.0 * sf),
		pole_top + Vector2(13.5 * sf, 3.5 * sf + wave * 0.65),
		pole_top + Vector2(1.0 * sf, 5.5 * sf)
	])
	ci.draw_colored_polygon(flag_hi_pts, strat_hi * modulate_col)
	if is_merged:
		var sec_col := Color(deme.secondary_color) if deme.secondary_color != "" else Color("#fbbf24")
		var sec_flag_pts := PackedVector2Array([
			pole_top + Vector2(1.0 * sf, 10.5 * sf),
			pole_top + Vector2(16.0 * sf, 13.5 * sf - wave * 0.8),
			pole_top + Vector2(1.0 * sf, 18.5 * sf)
		])
		ci.draw_colored_polygon(sec_flag_pts, sec_col * modulate_col)

	var ring_r := plinth_r + 5.0 * sf
	EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, ring_r, ring_r * 0.58, status_col * modulate_col, 3.4)


static func compute_cell_flora_key(r: Node2D, cell: EvoTypes.HexCell, top_z: float) -> Array:
	var state: EvoTypes.WorldState = r.world_state
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var base_count := 8
	if cell.biome == "tropical_forest":
		base_count = 13
	elif cell.biome == "savanna":
		base_count = 10
	elif cell.biome == "tundra":
		base_count = 9
	elif cell.biome == "coastal_shallows":
		base_count = 7
	var prop_count: int = clampi(int(round(float(base_count) * (0.55 + 0.45 * k_ratio))), 6, 13)
	var v_count := cell.deme_ids.size()
	if v_count > 0:
		prop_count = clampi(prop_count - v_count, 5, 10)
	var k_band: int = 0 if k_ratio < 0.60 else (1 if k_ratio < 0.85 else 2)
	var link_mask: int = 0
	if v_count > 0:
		for dir_idx in range(6):
			var n_id: String = r._neighbor_id(cell, dir_idx)
			if state.cells.has(n_id):
				var ncell: EvoTypes.HexCell = state.cells[n_id]
				if not ncell.deme_ids.is_empty() or ncell.land_use != "wild" or (ncell.biome == "coastal_shallows" and ncell.altitude >= state.sea_level):
					link_mask |= (1 << dir_idx)
	var cell_hash: int = int(cell.altitude * 100.0) * 1000 + prop_count * 10 + cell.biome.hash() + cell.land_use.hash() * 31 + (17 if cell.has_ruins else 0)
	return [cell_hash, cell.biome, cell.land_use, cell.has_ruins, top_z, prop_count, v_count, k_band, link_mask, r._built_yaw, r._built_pitch]


static func collect_static_props(r: Node2D) -> Array[Prop]:
	var state: EvoTypes.WorldState = r.world_state
	var hex_list: Array = r._sorted_hex_ids if not r._sorted_hex_ids.is_empty() else state.cells.keys()
	var cam_vec := Vector2(r._built_yaw, r._built_pitch)
	var full_flora_rebuild: bool = (
		not r._cell_flora_cache.has("__sorted_flora__")
		or r._cell_flora_cache.get("__flora_cam__", Vector2.INF) != cam_vec
	)
	var changed_hexes: Dictionary = {}
	for hex_id in hex_list:
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		if r._is_water(cell):
			if r._cell_flora_cache.has(hex_id):
				r._cell_flora_cache.erase(hex_id)
				changed_hexes[hex_id] = true
			continue
		var top_z: float = r._get_cell_top_z(cell)
		var flora_key := compute_cell_flora_key(r, cell, top_z)
		if not r._cell_flora_cache.has(hex_id) or (r._cell_flora_cache[hex_id]["key"] as Array) != flora_key:
			changed_hexes[hex_id] = true
			var world_xy := HexMath.axial_to_world(cell.q, cell.r)
			var cell_props: Array[Prop] = []
			collect_cell_flora_props(r, cell, world_xy, top_z, cell_props)
			for cp in cell_props:
				cp.hex_id = hex_id
				cp.project(r._ground, r._lift)
			for i in range(1, cell_props.size()):
				var kp: Prop = cell_props[i]
				var ky: float = kp.y
				var j: int = i - 1
				while j >= 0 and cell_props[j].y > ky:
					cell_props[j + 1] = cell_props[j]
					j -= 1
				cell_props[j + 1] = kp
			r._cell_flora_cache[hex_id] = {"key": flora_key, "props": cell_props}

	var flora_sorted: Array[Prop] = []
	if full_flora_rebuild or changed_hexes.size() > 95:
		for hex_id in hex_list:
			var cell: EvoTypes.HexCell = state.cells[hex_id]
			if r._is_water(cell):
				continue
			if r._cell_flora_cache.has(hex_id):
				flora_sorted.append_array(r._cell_flora_cache[hex_id]["props"] as Array[Prop])
		for i in range(1, flora_sorted.size()):
			var key_prop: Prop = flora_sorted[i]
			var key_y: float = key_prop.y
			var j: int = i - 1
			while j >= 0 and flora_sorted[j].y > key_y:
				flora_sorted[j + 1] = flora_sorted[j]
				j -= 1
			flora_sorted[j + 1] = key_prop
		r._cell_flora_cache["__sorted_flora__"] = flora_sorted
		r._cell_flora_cache["__flora_cam__"] = cam_vec
	elif not changed_hexes.is_empty():
		var prev_sorted: Array[Prop] = r._cell_flora_cache["__sorted_flora__"] as Array[Prop]
		var added_props: Array[Prop] = []
		for ch_id in changed_hexes.keys():
			if r._cell_flora_cache.has(ch_id):
				added_props.append_array(r._cell_flora_cache[ch_id]["props"] as Array[Prop])
		for i in range(1, added_props.size()):
			var kp: Prop = added_props[i]
			var ky: float = kp.y
			var j: int = i - 1
			while j >= 0 and added_props[j].y > ky:
				added_props[j + 1] = added_props[j]
				j -= 1
			added_props[j + 1] = kp
		var p_idx := 0
		var a_idx := 0
		var p_len := prev_sorted.size()
		var a_len := added_props.size()
		while p_idx < p_len:
			var pp: Prop = prev_sorted[p_idx]
			if changed_hexes.has(pp.hex_id):
				p_idx += 1
				continue
			while a_idx < a_len and added_props[a_idx].y <= pp.y:
				flora_sorted.append(added_props[a_idx])
				a_idx += 1
			flora_sorted.append(pp)
			p_idx += 1
		while a_idx < a_len:
			flora_sorted.append(added_props[a_idx])
			a_idx += 1
		r._cell_flora_cache["__sorted_flora__"] = flora_sorted
	else:
		flora_sorted = r._cell_flora_cache["__sorted_flora__"] as Array[Prop]

	var dyn_props: Array[Prop] = []
	for hex_id in state.recent_extinction_hexes:
		if state.cells.has(hex_id):
			var cell: EvoTypes.HexCell = state.cells[hex_id]
			if not r._is_water(cell) and not cell.has_ruins:
				var world_xy := HexMath.axial_to_world(cell.q, cell.r)
				var r_prop := world_prop("ruins_stone", world_xy + Vector2(0, 12), r._get_cell_top_z(cell), Vector2.ZERO, 2.20, Color.WHITE)
				r_prop.project(r._ground, r._lift)
				dyn_props.append(r_prop)

	for village in r._villages:
		collect_village_building_props(village, dyn_props)
	for i in range(1, dyn_props.size()):
		var key_dp: Prop = dyn_props[i]
		var key_dy: float = key_dp.y
		var j: int = i - 1
		while j >= 0 and dyn_props[j].y > key_dy:
			dyn_props[j + 1] = dyn_props[j]
			j -= 1
		dyn_props[j + 1] = key_dp

	var props: Array[Prop] = []
	var f_idx := 0
	var d_idx := 0
	var f_len := flora_sorted.size()
	var d_len := dyn_props.size()
	while f_idx < f_len and d_idx < d_len:
		if flora_sorted[f_idx].y <= dyn_props[d_idx].y:
			props.append(flora_sorted[f_idx])
			f_idx += 1
		else:
			props.append(dyn_props[d_idx])
			d_idx += 1
	while f_idx < f_len:
		props.append(flora_sorted[f_idx])
		f_idx += 1
	while d_idx < d_len:
		props.append(dyn_props[d_idx])
		d_idx += 1

	return props


static func collect_village_building_props(village: Dictionary, props: Array[Prop]) -> void:
	var deme: EvoTypes.Deme = village["deme"]
	var v_pos: Vector2 = village["pos"]
	var sf: float = village["sf"]
	var m: Color = village["modulate"]
	var tier := int(village["tier"])
	var eff_tier: int = 4 if (deme.merged_count >= 1 or deme.walled_union_id != "") else tier
	var c_count := deme.cultural_trait_ids.size()
	var arch := str(village["archetype"])
	var flags: int = (
		(1 if bool(village.get("has_pact", false)) else 0)
		| (2 if bool(village.get("in_war", false)) else 0)
		| (4 if bool(village.get("in_raid", false)) else 0)
		| (8 if bool(village.get("in_betrayal", false)) else 0)
		| (16 if bool(village.get("in_tribute", false)) else 0)
		| (32 if bool(village.get("in_siege", false)) else 0)
	)
	var vp_key: Array = [
		eff_tier,
		sf,
		c_count,
		arch,
		flags,
		deme.defense_tier,
		deme.merged_count,
		deme.walled_union_id,
		snappedf(deme.salubrity, 0.05),
		m,
		v_pos
	]
	if deme.has_meta("_vp_key") and (deme.get_meta("_vp_key") as Array) == vp_key:
		props.append_array(deme.get_meta("_vp_val") as Array[Prop])
		return

	var v_props: Array[Prop] = []
	var v_world: Vector2 = village["world_xy"]
	var top_z: float = village["top_z"]
	var layout := get_village_building_layout(eff_tier, sf, c_count > 0, c_count, arch)
	for b_item in layout:
		var off: Vector2 = b_item["offset"]
		var p := world_prop(str(b_item["sprite"]), v_world, top_z, off, float(b_item["scale"]), m)
		p.set_foot(v_pos + off)
		v_props.append(p)
	_draw_settlement_props(village, v_props)
	deme.set_meta("_vp_key", vp_key)
	deme.set_meta("_vp_val", v_props)
	props.append_array(v_props)


static func _draw_settlement_props(village: Dictionary, props: Array[Prop]) -> void:
	var deme: EvoTypes.Deme = village["deme"]
	var v_world: Vector2 = village["world_xy"]
	var v_pos: Vector2 = village["pos"]
	var top_z: float = village["top_z"]
	var sf: float = village["sf"]
	var m: Color = village["modulate"]
	if bool(village.get("has_pact", false)):
		var off := Vector2(-36, 30) * sf
		var p := world_prop("prop_pact_totem", v_world, top_z, off, 2.15 * sf, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if deme.merged_count > 0 or deme.walled_union_id != "":
		var off := Vector2(36, 30) * sf
		var p := world_prop("prop_unity_monument", v_world, top_z, off, 2.15 * sf, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_war", false)):
		var off := Vector2(-58, 12) * sf
		var p := world_prop("prop_war_banner", v_world, top_z, off, 2.25 * sf, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_raid", false)):
		var off := Vector2(58, 12) * sf
		var p := world_prop("prop_raid_loot", v_world, top_z, off, 2.15 * sf, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_tribute", false)):
		var off := Vector2(56, 16) * sf
		var p := world_prop("prop_tribute_chest", v_world, top_z, off, 2.10 * sf, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_siege", false)):
		var off := Vector2(-66, 18) * sf
		var p := world_prop("prop_siege_engine", v_world, top_z, off, 2.25 * sf, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_betrayal", false)):
		var off := Vector2(0, -28) * sf
		var p := world_prop("prop_betrayal_ruin", v_world, top_z, off, 2.20 * sf, m)
		p.set_foot(v_pos + off)
		props.append(p)


static func build_geopolitics_by_deme(state: EvoTypes.WorldState) -> Dictionary:
	var geo_by_deme: Dictionary = {}
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		var empty_icons: Array[String] = []
		geo_by_deme[did] = {
			"has_pact": false,
			"in_war": false,
			"in_raid": false,
			"in_betrayal": false,
			"in_tribute": false,
			"in_siege": false,
			"in_merge": d.merged_count > 0,
			"geo_icons": empty_icons
		}
	for pk_var in state.active_pacts.keys():
		if int(state.active_pacts[pk_var]) >= 2:
			var pk := str(pk_var)
			var sep := "__" if pk.contains("__") else "|"
			var parts := pk.split(sep)
			if parts.size() == 2 and geo_by_deme.has(parts[0]) and geo_by_deme.has(parts[1]):
				geo_by_deme[parts[0]]["has_pact"] = true
				geo_by_deme[parts[1]]["has_pact"] = true
	for flow in state.active_flows:
		var ft := flow.flow_type
		if not ft in ["war", "raid", "betrayal", "pact", "tribute", "siege", "merge"]:
			continue
		var flag_key := "has_pact" if ft == "pact" else ("in_" + ft)
		if flow.from_deme_id != "" or flow.to_deme_id != "":
			if geo_by_deme.has(flow.from_deme_id):
				geo_by_deme[flow.from_deme_id][flag_key] = true
			if geo_by_deme.has(flow.to_deme_id):
				geo_by_deme[flow.to_deme_id][flag_key] = true
		else:
			if state.cells.has(flow.from_hex_id):
				for did in (state.cells[flow.from_hex_id] as EvoTypes.HexCell).deme_ids:
					if geo_by_deme.has(did):
						geo_by_deme[did][flag_key] = true
			if state.cells.has(flow.to_hex_id):
				for did in (state.cells[flow.to_hex_id] as EvoTypes.HexCell).deme_ids:
					if geo_by_deme.has(did):
						geo_by_deme[did][flag_key] = true
	for did in geo_by_deme.keys():
		var d: EvoTypes.Deme = state.demes[did]
		var entry: Dictionary = geo_by_deme[did]
		var icons: Array[String] = entry["geo_icons"]
		if d.defense_tier > 0:
			icons.append("defense")
		if d.merged_count > 0 or bool(entry["in_merge"]):
			icons.append("merge")
		if bool(entry["in_siege"]):
			icons.append("siege")
		if bool(entry["in_war"]):
			icons.append("war")
		if bool(entry["in_betrayal"]):
			icons.append("betrayal")
		if bool(entry["in_raid"]):
			icons.append("raid")
		if bool(entry["in_tribute"]):
			icons.append("tribute")
		if bool(entry["has_pact"]):
			icons.append("pact")
	return geo_by_deme


static func resolve_deme_geopolitics(state: EvoTypes.WorldState, deme: EvoTypes.Deme) -> Dictionary:
	var has_pact := false
	var in_war := false
	var in_raid := false
	var in_betrayal := false
	var in_tribute := false
	var in_siege := false
	var in_merge := deme.merged_count > 0
	if not state.active_pacts.is_empty():
		for other_id in state.demes.keys():
			if other_id != deme.id and EvoTypes.is_pact_active(state, deme.id, other_id):
				has_pact = true
				break
	for flow in state.active_flows:
		var touches_deme: bool = (flow.from_deme_id == deme.id or flow.to_deme_id == deme.id)
		if not touches_deme and flow.from_deme_id == "" and flow.to_deme_id == "":
			touches_deme = (flow.from_hex_id == deme.hex_id or flow.to_hex_id == deme.hex_id)
		if not touches_deme:
			continue
		match flow.flow_type:
			"war":
				in_war = true
			"raid":
				in_raid = true
			"betrayal":
				in_betrayal = true
			"pact":
				has_pact = true
			"tribute":
				in_tribute = true
			"siege":
				in_siege = true
			"merge":
				in_merge = true
	var geo_icons: Array[String] = []
	if deme.defense_tier > 0:
		geo_icons.append("defense")
	if deme.merged_count > 0 or in_merge:
		geo_icons.append("merge")
	if in_siege:
		geo_icons.append("siege")
	if in_war:
		geo_icons.append("war")
	if in_betrayal:
		geo_icons.append("betrayal")
	if in_raid:
		geo_icons.append("raid")
	if in_tribute:
		geo_icons.append("tribute")
	if has_pact:
		geo_icons.append("pact")
	return {
		"has_pact": has_pact,
		"in_war": in_war,
		"in_raid": in_raid,
		"in_betrayal": in_betrayal,
		"in_tribute": in_tribute,
		"in_siege": in_siege,
		"in_merge": in_merge,
		"geo_icons": geo_icons
	}


static func get_cell_road_corridors_local(
	r: Node2D,
	cell: EvoTypes.HexCell,
	village_local_centers: Array[Vector2]
) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var v_count := village_local_centers.size()
	if v_count == 0:
		return segments

	for i in range(v_count):
		for j in range(i + 1, v_count):
			segments.append({"a": village_local_centers[i], "b": village_local_centers[j]})

	var state: EvoTypes.WorldState = r.world_state
	var cell_world := HexMath.axial_to_world(cell.q, cell.r)
	for dir_idx in range(6):
		var n_id: String = r._neighbor_id(cell, dir_idx)
		if not state.cells.has(n_id):
			continue
		var ncell: EvoTypes.HexCell = state.cells[n_id]
		var has_link := not ncell.deme_ids.is_empty() or (ncell.biome == "coastal_shallows" and ncell.altitude >= state.sea_level)
		if has_link:
			var n_local := HexMath.axial_to_world(ncell.q, ncell.r) - cell_world
			var best_vc: Vector2 = village_local_centers[0]
			var best_d2: float = best_vc.distance_squared_to(n_local)
			for v_i in range(1, v_count):
				var d2 := village_local_centers[v_i].distance_squared_to(n_local)
				if d2 < best_d2:
					best_d2 = d2
					best_vc = village_local_centers[v_i]
			segments.append({"a": best_vc, "b": n_local})
	return segments


static func collect_cell_flora_props(
	r: Node2D,
	cell: EvoTypes.HexCell,
	world_xy: Vector2,
	top_z: float,
	props: Array[Prop]
) -> void:
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var base_seed: int = cell.q * 73856093 ^ cell.r * 19349663
	var palette_sprites: Array = BIOME_FLORA_PALETTES[cell.biome] if BIOME_FLORA_PALETTES.has(cell.biome) else DEFAULT_FLORA_PALETTE

	if cell.has_ruins:
		var r1 := world_prop("ruins_stone", world_xy + Vector2(-34.0, 10.0), top_z, Vector2.ZERO, 2.25, Color.WHITE)
		props.append(r1)
		if absi(base_seed) % 2 == 0:
			var r2 := world_prop("ruins_stone", world_xy + Vector2(38.0, -16.0), top_z, Vector2.ZERO, 2.05, Color.WHITE)
			props.append(r2)

	var v_count := cell.deme_ids.size()
	if v_count == 0 and cell.land_use in ["crops", "pasture"]:
		if cell.land_use == "crops":
			props.append(world_prop("crop_field", world_xy + Vector2(-62.0, -28.0), top_z, Vector2.ZERO, 2.40, Color.WHITE))
			props.append(world_prop("crop_field", world_xy + Vector2(58.0, -24.0), top_z, Vector2.ZERO, 2.40, Color.WHITE))
			props.append(world_prop("windmill", world_xy + Vector2(0.0, -68.0), top_z, Vector2.ZERO, 2.52, Color.WHITE))
			props.append(world_prop("granary", world_xy + Vector2(52.0, 34.0), top_z, Vector2.ZERO, 2.38, Color.WHITE))
		else:
			props.append(world_prop("pasture_pen", world_xy + Vector2(-60.0, -24.0), top_z, Vector2.ZERO, 2.42, Color.WHITE))
			props.append(world_prop("pasture_pen", world_xy + Vector2(56.0, -20.0), top_z, Vector2.ZERO, 2.42, Color.WHITE))
			var shed_sprite := "granary" if absi(base_seed) % 2 == 0 else "house_clay"
			props.append(world_prop(shed_sprite, world_xy + Vector2(0.0, -64.0), top_z, Vector2.ZERO, 2.38, Color.WHITE))
		for p_i in range(4):
			var p_ang := (TAU * float(p_i) / 4.0) + 0.35
			var p_rad := HexMath.HEX_SIZE * (0.74 + float((absi(base_seed) + p_i * 7) % 10) * 0.01)
			var p_off := Vector2(cos(p_ang), sin(p_ang)) * p_rad
			var periph_sprite: String = palette_sprites[p_i % palette_sprites.size()]
			var p_prop := world_prop(periph_sprite, world_xy + p_off, top_z, Vector2.ZERO, 1.35, Color.WHITE)
			p_prop.sways = not NON_SWAYING_SPRITES.has(periph_sprite)
			p_prop.sway_phase = float(p_i) * 0.8 + float(cell.q)
			props.append(p_prop)
		return

	var base_count := 8
	if cell.biome == "tropical_forest":
		base_count = 13
	elif cell.biome == "savanna":
		base_count = 10
	elif cell.biome == "tundra":
		base_count = 9
	elif cell.biome == "coastal_shallows":
		base_count = 7

	var prop_count: int = clampi(int(round(float(base_count) * (0.55 + 0.45 * k_ratio))), 6, 13)

	var village_local_centers: Array[Vector2] = []
	for v_idx in range(v_count):
		village_local_centers.append(HexMath.compute_village_sector_offset(v_idx, v_count, HexMath.HEX_SIZE))

	if v_count > 0:
		prop_count = clampi(prop_count - v_count, 5, 10)

	var road_corridors := get_cell_road_corridors_local(r, cell, village_local_centers)
	var placed_offsets: Array[Vector2] = []
	var village_clear_r := 138.0 if v_count == 1 else 88.0
	var village_clear_r_sq := village_clear_r * village_clear_r
	var village_clear_r2_sq := (village_clear_r - 2.0) * (village_clear_r - 2.0)
	var max_rad_sq := (HexMath.HEX_SIZE * 0.84) * (HexMath.HEX_SIZE * 0.84)
	var inner_count: int = 0 if v_count > 0 else maxi(2, prop_count / 3)
	var outer_count: int = prop_count - inner_count

	for idx in range(prop_count):
		var s1: int = absi(base_seed ^ ((idx * 13 + 1) * 83492791))
		var s2: int = absi(base_seed ^ ((idx * 29 + 7) * 83492791))
		var angle := 0.0
		var rad_norm := 0.0
		if idx < inner_count:
			angle = (TAU * float(idx) / float(inner_count)) + float(s1 % 31 - 15) * 0.045
			rad_norm = 0.22 + float(s2 % 22) * 0.01
		else:
			var o_idx := idx - inner_count
			angle = (TAU * float(o_idx) / float(maxi(1, outer_count))) + 0.32 + float(s1 % 31 - 15) * 0.032
			if v_count > 0:
				rad_norm = 0.66 + float(s2 % 18) * 0.01
			else:
				rad_norm = 0.50 + float(s2 % 28) * 0.01

		var local_off := Vector2(cos(angle), sin(angle)) * (HexMath.HEX_SIZE * rad_norm)

		var valid_spot := true
		for vc in village_local_centers:
			var d_sq := local_off.distance_squared_to(vc)
			if d_sq < village_clear_r_sq:
				var push_dir := (local_off - vc).normalized() if d_sq > 0.0001 else Vector2(cos(angle), sin(angle))
				local_off = vc + push_dir * (village_clear_r + 8.0)
				if local_off.length_squared() > max_rad_sq:
					valid_spot = false
				break
		if not valid_spot:
			continue
		for vc in village_local_centers:
			if local_off.distance_squared_to(vc) < village_clear_r2_sq:
				valid_spot = false
				break
		if not valid_spot:
			continue

		for seg in road_corridors:
			var closest := Geometry2D.get_closest_point_to_segment(local_off, seg["a"], seg["b"])
			if local_off.distance_squared_to(closest) < 1764.0:
				valid_spot = false
				break
		if not valid_spot:
			continue

		for prev in placed_offsets:
			if local_off.distance_squared_to(prev) < 2704.0:
				valid_spot = false
				break
		if not valid_spot:
			continue

		placed_offsets.append(local_off)
		var sprite_key: String = palette_sprites[idx % palette_sprites.size()]
		var can_sway := true

		if k_ratio < 0.60:
			can_sway = false
			if idx % 3 == 0:
				sprite_key = "tree_stump"
			elif idx % 3 == 1:
				sprite_key = "soil_crack"
			else:
				sprite_key = "dry_scrub"
		elif k_ratio < 0.85 and idx % 2 == 1:
			can_sway = false
			sprite_key = "tree_stump" if idx % 4 == 1 else ("soil_crack" if idx % 4 == 3 else "dry_scrub")

		var prop := world_prop(sprite_key, world_xy + local_off, top_z, Vector2.ZERO, 1.45 + float(s1 % 20) * 0.015, Color.WHITE)
		prop.sways = can_sway and not NON_SWAYING_SPRITES.has(sprite_key)
		prop.sway_phase = float(idx) * 0.9 + float(cell.q)
		props.append(prop)


static func get_deme_dominant_archetype(r: Node2D, deme: EvoTypes.Deme) -> String:
	var catalog: Dictionary = r.world_state.decisions_catalog
	if catalog.has(deme.last_dominant_decision_id):
		var dec: EvoTypes.DecisionDef = catalog[deme.last_dominant_decision_id]
		return dec.archetype
	if deme.last_dominant_decision_id.contains("war"):
		return "war"
	if deme.last_dominant_decision_id.contains("raid"):
		return "raid"
	if deme.last_dominant_decision_id.contains("pact"):
		return "pact"
	if deme.last_dominant_decision_id.contains("betrayal"):
		return "betrayal"
	if deme.last_dominant_decision_id.contains("overexploit"):
		return "overexploit"
	if deme.last_dominant_decision_id.contains("migration"):
		return "migrate"
	if deme.last_dominant_decision_id.contains("cooperate"):
		return "cooperate"
	if deme.last_dominant_decision_id.contains("exchange"):
		return "exchange"
	if deme.last_dominant_decision_id.contains("dispute"):
		return "dispute"
	if deme.last_dominant_decision_id.contains("innovate"):
		return "innovate"
	return "forage"


static func draw_props(r: Node2D) -> void:
	var moving := collect_moving_props(r)
	moving.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	var m_idx := 0
	var vis_rect: Rect2 = r._visible_world_rect
	for prop in r._static_props:
		if not vis_rect.intersects(prop.rect):
			continue
		while m_idx < moving.size() and moving[m_idx].y < prop.y:
			draw_prop(r, moving[m_idx])
			m_idx += 1
		draw_prop(r, prop)
	for i in range(m_idx, moving.size()):
		draw_prop(r, moving[i])


static func draw_prop(r: Node2D, prop: Prop) -> void:
	var rect := prop.rect
	if prop.sways:
		rect.position.x += sin(r._anim_time * 2.1 + prop.sway_phase) * 1.15
	r._anim_layer.draw_texture_rect(prop.texture, rect, false, prop.modulate)
	if prop.trim_color.a > 0.0:
		var trim_rect := Rect2(
			rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.44),
			Vector2(rect.size.x * 0.40, maxf(2.0, rect.size.y * 0.06))
		)
		r._anim_layer.draw_rect(trim_rect, prop.trim_color, true)


static func acquire_moving_prop(
	r: Node2D,
	tex: ImageTexture,
	foot: Vector2,
	scale_val: float,
	anchor_y_ratio: float,
	modulate_col: Color
) -> Prop:
	var prop: Prop
	if r._moving_prop_count < r._moving_prop_pool.size():
		prop = r._moving_prop_pool[r._moving_prop_count]
	else:
		prop = Prop.new(tex, scale_val, anchor_y_ratio, modulate_col)
		r._moving_prop_pool.append(prop)
	r._moving_prop_count += 1
	prop.texture = tex
	var tex_sz := tex.get_size()
	var dpi_norm: float = 0.32 if tex_sz.x <= 64.0 else 0.24
	var sz: Vector2 = tex_sz * (scale_val * dpi_norm)
	prop.anchor_offset = Vector2(sz.x * 0.5, sz.y * anchor_y_ratio)
	prop.rect = Rect2(foot - prop.anchor_offset, sz)
	prop.y = foot.y
	prop.modulate = modulate_col
	prop.trim_color = Color.TRANSPARENT
	prop.sways = false
	return prop


static func collect_moving_props(r: Node2D) -> Array[Prop]:
	r._moving_prop_count = 0
	var props: Array[Prop] = []
	var vis_rect: Rect2 = r._visible_world_rect
	var anim_time: float = r._anim_time

	for village in r._villages:
		var v_pos: Vector2 = village["pos"]
		if not vis_rect.has_point(v_pos):
			continue
		var sf: float = village["sf"]
		var m: Color = village["modulate"]
		var strat_color: Color = village["strat_color"]
		var cape_trim := strat_color.lightened(0.25) * m
		if int(village["tier"]) == 1:
			var fire_sprite := "tier1_campfire" if int(anim_time * 5.0) % 2 == 0 else "tier1_campfire_2"
			props.append(acquire_moving_prop(r, EvoPixelArtGen.get_texture(fire_sprite), v_pos + Vector2(0, 6) * sf, 2.35 * sf, 0.78, m))

		var villager_count: int = village["villager_count"]
		var v_textures: Array = village.get("villager_textures", [])
		for v_idx in range(villager_count):
			var orbit_angle := anim_time * (0.90 + float(v_idx % 3) * 0.20) + float(v_idx) * (TAU / float(villager_count))
			var orbit_r := (34.0 + float(v_idx % 4) * 14.0) * sf
			var foot := v_pos + Vector2(cos(orbit_angle) * orbit_r, sin(orbit_angle) * (orbit_r * 0.56) + 9.0 * sf)
			var frame := int((anim_time * 6.0) + float(v_idx)) % 3
			var v_prop := acquire_moving_prop(r, v_textures[frame] as ImageTexture, foot, 2.55 * sf, 0.85, m)
			v_prop.trim_color = cape_trim
			props.append(v_prop)

	for r_idx in range(r._roads.size()):
		var road: Dictionary = r._roads[r_idx]
		if not TRAVELER_ROAD_KINDS.has(road["kind"]) or not road["show_traffic"]:
			continue
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not vis_rect.has_point(p_a) and not vis_rect.has_point(p_b):
			continue
		var curve_f: float = float(road["curve_factor"])
		var r_textures: Array[ImageTexture] = road["villager_textures"]
		if road["kind"] == "rural_farm":
			var raw_wagon := fposmod(anim_time * 0.22 + float(r_idx) * 0.37, 1.0)
			var t_wagon := lerpf(0.22, 0.82, raw_wagon)
			var w_foot := EvoRoadNetworkRenderer.sample_road_curve(p_a, p_b, t_wagon, 1.0, curve_f)
			props.append(acquire_moving_prop(r, EvoPixelArtGen.get_texture("covered_wagon"), w_foot, 1.85, 0.82, Color.WHITE))
		for traveler_i in range(2):
			var raw_walk := fposmod(anim_time * 0.24 + float(r_idx) * 0.31 + float(traveler_i) * 0.48, 1.0)
			if traveler_i == 1:
				raw_walk = 1.0 - raw_walk
			var t_walk := lerpf(0.24, 0.76, raw_walk)
			var foot := EvoRoadNetworkRenderer.sample_road_curve(p_a, p_b, t_walk, 1.0, curve_f)
			var frame := int((anim_time * 6.5) + float(traveler_i + r_idx)) % 3
			props.append(acquire_moving_prop(r, r_textures[frame], foot, 2.50, 0.85, Color.WHITE))
	return props


static func world_prop(
	sprite_name: String,
	world_xy: Vector2,
	top_z: float,
	screen_offset: Vector2,
	scale_val: float,
	modulate_col: Color
) -> Prop:
	var prop := Prop.new(EvoPixelArtGen.get_texture(sprite_name), scale_val, 0.78, modulate_col)
	prop.world_xy = world_xy
	prop.top_z = top_z
	prop.screen_offset = screen_offset
	return prop
