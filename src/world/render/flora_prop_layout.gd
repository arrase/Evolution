class_name EvoFloraPropLayout
extends RefCounted

const Prop = EvoPropFloraRenderer.Prop

const NON_SWAYING_SPRITES: Array[String] = [
	"mossy_rock", "fallen_log", "rock_mountain", "mountain_peak",
	"tree_stump", "soil_crack", "ruins_stone", "crop_field", "pasture_pen"
]

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
				if not ncell.deme_ids.is_empty() or ncell.land_use != "wild":
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
				var r_prop := EvoPropFloraRenderer.world_prop("ruins_stone", world_xy + Vector2(0, 12), r._get_cell_top_z(cell), Vector2.ZERO, 2.20, Color.WHITE)
				r_prop.project(r._ground, r._lift)
				dyn_props.append(r_prop)

	for village in r._villages:
		EvoPropFloraRenderer.collect_village_building_props(village, dyn_props)
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


static func get_cell_road_corridors_local(
	r: Node2D,
	cell: EvoTypes.HexCell,
	village_local_centers: Array[Vector2]
) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if village_local_centers.is_empty():
		return segments

	var state: EvoTypes.WorldState = r.world_state
	var cell_world := HexMath.axial_to_world(cell.q, cell.r)
	var best_vc: Vector2 = village_local_centers[0]
	for dir_idx in range(6):
		var n_id: String = r._neighbor_id(cell, dir_idx)
		if not state.cells.has(n_id):
			continue
		var ncell: EvoTypes.HexCell = state.cells[n_id]
		var has_link := not ncell.deme_ids.is_empty() or ncell.land_use != "wild"
		if has_link:
			var n_local := HexMath.axial_to_world(ncell.q, ncell.r) - cell_world
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
		var r1 := EvoPropFloraRenderer.world_prop("ruins_stone", world_xy + Vector2(-34.0, 10.0), top_z, Vector2.ZERO, 2.25, Color.WHITE)
		props.append(r1)
		if absi(base_seed) % 2 == 0:
			var r2 := EvoPropFloraRenderer.world_prop("ruins_stone", world_xy + Vector2(38.0, -16.0), top_z, Vector2.ZERO, 2.05, Color.WHITE)
			props.append(r2)

	var v_count := cell.deme_ids.size()
	if v_count == 0 and cell.land_use in ["crops", "pasture"]:
		if cell.land_use == "crops":
			props.append(EvoPropFloraRenderer.world_prop("crop_field", world_xy + Vector2(-62.0, -28.0), top_z, Vector2.ZERO, 2.40, Color.WHITE))
			props.append(EvoPropFloraRenderer.world_prop("crop_field", world_xy + Vector2(58.0, -24.0), top_z, Vector2.ZERO, 2.40, Color.WHITE))
			props.append(EvoPropFloraRenderer.world_prop("windmill", world_xy + Vector2(0.0, -68.0), top_z, Vector2.ZERO, 2.52, Color.WHITE))
		else:
			props.append(EvoPropFloraRenderer.world_prop("pasture_pen", world_xy + Vector2(-60.0, -24.0), top_z, Vector2.ZERO, 2.42, Color.WHITE))
			props.append(EvoPropFloraRenderer.world_prop("pasture_pen", world_xy + Vector2(56.0, -20.0), top_z, Vector2.ZERO, 2.42, Color.WHITE))
		for p_i in range(4):
			var p_ang := (TAU * float(p_i) / 4.0) + 0.35
			var p_rad := HexMath.HEX_SIZE * (0.74 + float((absi(base_seed) + p_i * 7) % 10) * 0.01)
			var p_off := Vector2(cos(p_ang), sin(p_ang)) * p_rad
			var periph_sprite: String = palette_sprites[p_i % palette_sprites.size()]
			var p_prop := EvoPropFloraRenderer.world_prop(periph_sprite, world_xy + p_off, top_z, Vector2.ZERO, 1.35, Color.WHITE)
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
	if v_count > 0:
		village_local_centers.append(Vector2.ZERO)
		prop_count = clampi(prop_count - v_count, 5, 10)

	var road_corridors := get_cell_road_corridors_local(r, cell, village_local_centers)
	var placed_offsets: Array[Vector2] = []
	var village_clear_r := 138.0
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

		var prop := EvoPropFloraRenderer.world_prop(sprite_key, world_xy + local_off, top_z, Vector2.ZERO, 1.45 + float(s1 % 20) * 0.015, Color.WHITE)
		prop.sways = can_sway and not NON_SWAYING_SPRITES.has(sprite_key)
		prop.sway_phase = float(idx) * 0.9 + float(cell.q)
		props.append(prop)
