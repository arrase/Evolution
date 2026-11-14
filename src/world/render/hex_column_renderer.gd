class_name EvoHexColumnRenderer
extends RefCounted

const TerrainHexShader = preload("res://src/world/shaders/terrain_hex.gdshader")
const EDGE_DIR_MAP: Array[int] = [0, 5, 4, 3, 2, 1]

const BIOME_PALETTE: Dictionary = {
	"tropical_forest": {
		"surface": Color("#398a30"),
		"edge": Color("#196132"),
		"tuft": Color("#3eb864"),
		"cliff_top": Color("#7c5333"),
		"cliff_bot": Color("#4d301b"),
		"overhang": Color("#258545")
	},
	"savanna": {
		"surface": Color("#8fb838"),
		"edge": Color("#946c1c"),
		"tuft": Color("#e8be4e"),
		"cliff_top": Color("#9c6234"),
		"cliff_bot": Color("#633a1c"),
		"overhang": Color("#cfa136")
	},
	"arid_steppe": {
		"surface": Color("#e0b264"),
		"edge": Color("#9e5822"),
		"tuft": Color("#eda05c"),
		"cliff_top": Color("#a85832"),
		"cliff_bot": Color("#6e3419"),
		"overhang": Color("#cc7735")
	},
	"tundra": {
		"surface": Color("#d5e6f2"),
		"edge": Color("#7592a3"),
		"tuft": Color("#eaf4f8"),
		"cliff_top": Color("#64748b"),
		"cliff_bot": Color("#3f4c5c"),
		"overhang": Color("#e2eff5")
	},
	"high_mountain": {
		"surface": Color("#78736e"),
		"edge": Color("#4f4c49"),
		"tuft": Color("#cbd5e1"),
		"cliff_top": Color("#5c5855"),
		"cliff_bot": Color("#363331"),
		"overhang": Color("#99928b")
	},
	"coastal_shallows": {
		"surface": Color("#42bdb4"),
		"edge": Color("#d9be7e"),
		"tuft": Color("#ebd294"),
		"cliff_top": Color("#a88e58"),
		"cliff_bot": Color("#705c35"),
		"overhang": Color("#d9be7e")
	},
	"ocean": {
		"surface": Color("#1f5d8a"),
		"edge": Color("#144566"),
		"tuft": Color("#7dd3fc"),
		"cliff_top": Color("#144566"),
		"cliff_bot": Color("#0d2f47"),
		"overhang": Color("#216899")
	}
}

const C_ROCK_CRACK := Color(0.14, 0.08, 0.05, 0.42)
const C_CLIFF_OUTLINE := Color(0.14, 0.08, 0.05, 0.72)
const C_SAND := Color("#ebd294")
const C_SURF := Color(0.95, 0.99, 1.0, 0.85)
const C_RIPPLE := Color(0.90, 0.98, 1.0, 0.60)
const NW_SUN_DIR := Vector2(-0.92, -0.39)

static var _terrain_shader_mat: ShaderMaterial = null


static func get_terrain_shader_material() -> ShaderMaterial:
	if _terrain_shader_mat == null:
		_terrain_shader_mat = ShaderMaterial.new()
		_terrain_shader_mat.shader = TerrainHexShader
	return _terrain_shader_mat


static func draw_hex_column(r: Node2D, column: Node2D, hex_id: String) -> void:
	var cell: EvoTypes.HexCell = r.world_state.cells[hex_id]
	var is_ocean: bool = r._is_water(cell)
	if is_ocean:
		if column.material != null:
			column.material = null
	else:
		var mat := get_terrain_shader_material()
		if column.material != mat:
			column.material = mat

	var eff_biome: String = "ocean" if is_ocean else cell.biome
	var pal: Dictionary = BIOME_PALETTE[eff_biome]
	var top_pts: PackedVector2Array = r._hex_polys[hex_id]

	if not is_ocean and cell.altitude - r.world_state.sea_level > 0.015:
		var bot_pts: PackedVector2Array = r._project_hex(HexMath.axial_to_world(cell.q, cell.r), 0.0)
		_draw_cliff_walls(r, column, cell, pal, top_pts, bot_pts)

	var tint_col := get_top_tint(r, cell, is_ocean)
	var v_colors := _compute_vertex_colors(r, cell, pal, tint_col, is_ocean)
	column.draw_polygon(top_pts, v_colors, r._hex_uvs, EvoPixelArtGen.get_texture("hex_tile_" + eff_biome))

	if not is_ocean:
		if cell.land_use == "crops" or cell.land_use == "pasture" or cell.has_ruins:
			_draw_rural_and_ruins_top_overlay(r, column, cell, top_pts)
		_draw_hex_borders(r, column, cell, pal, tint_col, top_pts)
		if r.active_lens == "food":
			var k_ratio: float = cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max)
			if k_ratio < 0.60:
				_draw_dashed_hex_border(column, top_pts, Color("#ef4444"), 2.6)
			elif k_ratio < 0.85:
				_draw_dashed_hex_border(column, top_pts, Color("#f59e0b"), 2.0)


static func _compute_vertex_colors(
	r: Node2D,
	cell: EvoTypes.HexCell,
	pal: Dictionary,
	tint_col: Color,
	is_ocean: bool
) -> PackedColorArray:
	if is_ocean or r.active_lens != "biome":
		return PackedColorArray([tint_col, tint_col, tint_col, tint_col, tint_col, tint_col])

	var self_surf: Color = pal["surface"]
	var low_coast: bool = cell.altitude - r.world_state.sea_level <= 0.14
	var v_colors := PackedColorArray()
	v_colors.resize(6)

	for v in range(6):
		var dir_a: int = EDGE_DIR_MAP[(v + 5) % 6]
		var dir_b: int = EDGE_DIR_MAP[v]
		var accum_col := Color(0.0, 0.0, 0.0, 0.0)
		var accum_w: float = 0.0

		for dir_idx in [dir_a, dir_b]:
			var nid: String = r._neighbor_id(cell, dir_idx)
			if not r.world_state.cells.has(nid) or r._is_water(r.world_state.cells[nid]):
				if low_coast:
					accum_col += C_SAND * 0.10
					accum_w += 0.10
			else:
				var nb_cell: EvoTypes.HexCell = r.world_state.cells[nid]
				if nb_cell.biome != cell.biome and absf(nb_cell.altitude - cell.altitude) <= 0.18:
					var nb_pal: Dictionary = BIOME_PALETTE[nb_cell.biome]
					var nb_surf: Color = nb_pal["surface"]
					accum_col += nb_surf * 0.12
					accum_w += 0.12

		if accum_w > 0.001:
			var target_surf := accum_col / accum_w
			var blend_w := clampf(accum_w, 0.18, 0.24)
			var mod_col := Color(
				clampf((target_surf.r + 0.18) / (self_surf.r + 0.18), 0.56, 1.52),
				clampf((target_surf.g + 0.18) / (self_surf.g + 0.18), 0.56, 1.52),
				clampf((target_surf.b + 0.18) / (self_surf.b + 0.18), 0.56, 1.52),
				1.0
			)
			v_colors[v] = tint_col * Color.WHITE.lerp(mod_col, blend_w)
		else:
			v_colors[v] = tint_col

	return v_colors


static func _draw_rural_and_ruins_top_overlay(r: Node2D, column: Node2D, cell: EvoTypes.HexCell, top_pts: PackedVector2Array) -> void:
	var center: Vector2 = r._hex_centers[cell.id]
	var inner_pts := PackedVector2Array()
	for pt in top_pts:
		inner_pts.append(center.lerp(pt, 0.76))
	if cell.land_use == "crops":
		column.draw_colored_polygon(inner_pts, Color(0.78, 0.60, 0.24, 0.28))
		var furrows := PackedVector2Array()
		for row in range(-4, 5):
			var t := float(row) / 5.5
			var y_off := t * 72.0
			var half_w := (1.0 - absf(t) * 0.55) * 96.0
			furrows.append(center + Vector2(-half_w, y_off - half_w * 0.14))
			furrows.append(center + Vector2(half_w, y_off + half_w * 0.14))
		column.draw_multiline(furrows, Color(0.38, 0.24, 0.10, 0.48), 2.2)
		var border := inner_pts.duplicate()
		border.append(inner_pts[0])
		column.draw_polyline(border, Color("#23150c") * Color(1, 1, 1, 0.45), 1.6)
	elif cell.land_use == "pasture":
		column.draw_colored_polygon(inner_pts, Color(0.32, 0.68, 0.34, 0.24))
		var fence := inner_pts.duplicate()
		fence.append(inner_pts[0])
		column.draw_polyline(fence, Color(0.55, 0.36, 0.18, 0.72), 2.2)
		for pt in inner_pts:
			column.draw_circle(pt, 2.8, Color("#23150c"))
	if cell.has_ruins:
		column.draw_circle(center + Vector2(-18.0, 8.0), 34.0, Color(0.18, 0.14, 0.12, 0.32))
		column.draw_circle(center + Vector2(22.0, -10.0), 26.0, Color(0.24, 0.20, 0.18, 0.28))


static func _draw_cliff_walls(
	r: Node2D,
	column: Node2D,
	cell: EvoTypes.HexCell,
	pal: Dictionary,
	top_pts: PackedVector2Array,
	bot_pts: PackedVector2Array
) -> void:
	var tier: int = clampi(int(ceilf(cell.altitude * 10.0)), 1, 10)
	var strata_count: int = clampi((tier + 1) / 2, 2, 5)
	var cliff_top_col: Color = pal["cliff_top"]
	var cliff_bot_col: Color = pal["cliff_bot"]
	var overhang_col: Color = pal["overhang"]
	var top_z: float = r._get_cell_top_z(cell)
	var sea_z: float = r._sea_z()
	var t_sea: float = clampf(1.0 - sea_z / maxf(1.0, top_z), 0.0, 1.0)

	var strata_lines := PackedVector2Array()
	var cracks := PackedVector2Array()
	var outlines := PackedVector2Array()

	for i in range(6):
		var next_i: int = (i + 1) % 6
		var p0 := top_pts[i]
		var p1 := top_pts[next_i]
		if p0.x - p1.x <= 0.5:
			continue
		var b1 := bot_pts[next_i]
		var b0 := bot_pts[i]

		var face_rad := deg_to_rad(60.0 * float(i) + r._built_yaw)
		var normal := Vector2(cos(face_rad), sin(face_rad))
		var light_t := clampf((normal.dot(NW_SUN_DIR) + 0.88) / 1.65, 0.0, 1.0)
		var light_mod := Color(0.60, 0.66, 0.79, 1.0).lerp(Color(1.15, 1.06, 0.91, 1.0), light_t)

		var w_top := cliff_top_col * light_mod
		var w_bot := cliff_bot_col * light_mod
		column.draw_polygon(
			PackedVector2Array([p0, p1, b1, b0]),
			PackedColorArray([w_top, w_top, w_bot, w_bot])
		)

		for s_idx in range(1, strata_count + 1):
			var t0 := float(s_idx) / float(strata_count + 1)
			var t1 := minf(0.96, t0 + 0.065)
			var band_col := Color(0.12, 0.08, 0.06, 0.17) if (s_idx % 2 == 1) else Color(0.95, 0.88, 0.76, 0.11)
			column.draw_colored_polygon(
				PackedVector2Array([p0.lerp(b0, t0), p1.lerp(b1, t0), p1.lerp(b1, t1), p0.lerp(b0, t1)]),
				band_col
			)
			strata_lines.append(p0.lerp(b0, t0))
			strata_lines.append(p1.lerp(b1, t0))

		var lip_shadow_top := Color(0.07, 0.04, 0.03, 0.28)
		var lip_shadow_bot := Color(0.07, 0.04, 0.03, 0.0)
		column.draw_polygon(
			PackedVector2Array([p0, p1, p1.lerp(b1, 0.15), p0.lerp(b0, 0.15)]),
			PackedColorArray([lip_shadow_top, lip_shadow_top, lip_shadow_bot, lip_shadow_bot])
		)
		column.draw_colored_polygon(
			PackedVector2Array([p0, p1, p1.lerp(b1, 0.045), p0.lerp(b0, 0.045)]),
			overhang_col * light_mod
		)

		var ao_clear := Color(0.05, 0.04, 0.08, 0.0)
		var ao_base := Color(0.05, 0.04, 0.08, 0.54)
		column.draw_polygon(
			PackedVector2Array([p0.lerp(b0, 0.76), p1.lerp(b1, 0.76), b1, b0]),
			PackedColorArray([ao_clear, ao_clear, ao_base, ao_base])
		)

		var dir_idx: int = EDGE_DIR_MAP[i]
		var nid: String = r._neighbor_id(cell, dir_idx)
		var nb_is_water: bool = not r.world_state.cells.has(nid) or r._is_water(r.world_state.cells[nid])
		if nb_is_water and t_sea > 0.08:
			var t_up := maxf(0.04, t_sea - 0.20)
			var sea_ao_top := Color(0.03, 0.08, 0.14, 0.0)
			var sea_ao_bot := Color(0.03, 0.08, 0.14, 0.58)
			column.draw_polygon(
				PackedVector2Array([p0.lerp(b0, t_up), p1.lerp(b1, t_up), p1.lerp(b1, t_sea), p0.lerp(b0, t_sea)]),
				PackedColorArray([sea_ao_top, sea_ao_top, sea_ao_bot, sea_ao_bot])
			)
		elif not nb_is_water:
			var nb_z: float = r._get_cell_top_z(r.world_state.cells[nid])
			if nb_z < top_z - 1.0:
				var t_terr := clampf(1.0 - nb_z / maxf(1.0, top_z), 0.08, 1.0)
				var t_terr_up := maxf(0.04, t_terr - 0.18)
				column.draw_polygon(
					PackedVector2Array([p0.lerp(b0, t_terr_up), p1.lerp(b1, t_terr_up), p1.lerp(b1, t_terr), p0.lerp(b0, t_terr)]),
					PackedColorArray([ao_clear, ao_clear, ao_base, ao_base])
				)

		for c_idx in range(2):
			var u := 0.28 + float(c_idx) * 0.42 + float(r._cell_seed(cell.q, cell.r, i * 10 + c_idx) % 9 - 4) * 0.015
			var c_top := p0.lerp(p1, u)
			var c_bot := b0.lerp(b1, u)
			var t_start := 0.18 + float((c_idx + i) % 2) * 0.20
			cracks.append(c_top.lerp(c_bot, t_start))
			cracks.append(c_top.lerp(c_bot, minf(0.90, t_start + 0.38)))

		outlines.append_array(PackedVector2Array([p0, p1, p1, b1, b1, b0, b0, p0]))

	if outlines.is_empty():
		return
	column.draw_multiline(strata_lines, cliff_bot_col.darkened(0.26) * Color(1, 1, 1, 0.52), 1.2)
	column.draw_multiline(cracks, C_ROCK_CRACK, 1.2)
	column.draw_multiline(outlines, C_CLIFF_OUTLINE, 1.1)


static func _resolve_lens_ring_color(r: Node2D, cell: EvoTypes.HexCell) -> Color:
	if r.active_lens == "food":
		var ratio_r: float = clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
		if ratio_r < 0.35:
			return Color("#ef4444").lerp(Color("#f59e0b"), ratio_r / 0.35)
		return Color("#f59e0b").lerp(Color("#22c55e"), (ratio_r - 0.35) / 0.65)
	if r.active_lens == "health":
		if not cell.deme_ids.is_empty() and r.world_state.demes.has(cell.deme_ids[0]):
			var d: EvoTypes.Deme = r.world_state.demes[cell.deme_ids[0]]
			if d.infection_turns > 0:
				return Color("#84cc16")
			if d.salubrity < 0.40:
				return Color("#ef4444")
			if d.salubrity < 0.75:
				return Color("#fbbf24")
			return Color("#10b981")
		return Color.TRANSPARENT
	if r.active_lens == "diplomacy" or r.active_lens == "territory":
		if not cell.deme_ids.is_empty() and r.world_state.demes.has(cell.deme_ids[0]):
			var d: EvoTypes.Deme = r.world_state.demes[cell.deme_ids[0]]
			return EvoPropFloraRenderer.resolve_deme_strategy_color(r.world_state, d).lightened(0.10)
		if (cell.land_use == "crops" or cell.land_use == "pasture") and cell.owner_deme_id != "" and r.world_state.demes.has(cell.owner_deme_id):
			var owner: EvoTypes.Deme = r.world_state.demes[cell.owner_deme_id]
			var s_col := EvoPropFloraRenderer.resolve_deme_strategy_color(r.world_state, owner)
			return Color(s_col.r, s_col.g, s_col.b, 0.88)
		return Color.TRANSPARENT
	return Color.TRANSPARENT


static func get_top_tint(r: Node2D, cell: EvoTypes.HexCell, is_ocean: bool) -> Color:
	if is_ocean:
		return Color.WHITE
	if r.active_lens == "food":
		return Color.WHITE.lerp(_resolve_lens_ring_color(r, cell), 0.42)
	if r.active_lens == "health":
		var h_col := _resolve_lens_ring_color(r, cell)
		if h_col.a > 0.01:
			return Color.WHITE.lerp(h_col, 0.44)
		return Color.WHITE.lerp(Color("#cbd5e1"), 0.38)
	if r.active_lens == "diplomacy" or r.active_lens == "territory":
		if not cell.deme_ids.is_empty() and r.world_state.demes.has(cell.deme_ids[0]):
			var d: EvoTypes.Deme = r.world_state.demes[cell.deme_ids[0]]
			var s_col := EvoPropFloraRenderer.resolve_deme_strategy_color(r.world_state, d)
			return Color.WHITE.lerp(s_col, 0.45)
		if (cell.land_use == "crops" or cell.land_use == "pasture") and cell.owner_deme_id != "" and r.world_state.demes.has(cell.owner_deme_id):
			var owner: EvoTypes.Deme = r.world_state.demes[cell.owner_deme_id]
			var s_col := EvoPropFloraRenderer.resolve_deme_strategy_color(r.world_state, owner)
			return Color.WHITE.lerp(s_col, 0.38)
		return Color.WHITE.lerp(Color("#cbd5e1"), 0.38)

	var tint_col := Color.WHITE
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	if k_ratio < 0.60:
		tint_col = tint_col.lerp(Color("#9c6b4e"), 0.36)
	elif k_ratio < 0.85:
		tint_col = tint_col.lerp(Color("#c29b61"), 0.18)
	if cell.land_use == "crops":
		tint_col = tint_col.lerp(Color("#e8c468"), 0.22)
	elif cell.land_use == "pasture":
		tint_col = tint_col.lerp(Color("#76c975"), 0.20)
	if cell.has_ruins:
		tint_col = tint_col.lerp(Color("#5c4a3e"), 0.26)
	return tint_col


static func draw_biome_edge_transitions(
	r: Node2D,
	column: Node2D,
	cell: EvoTypes.HexCell,
	pal: Dictionary,
	top_pts: PackedVector2Array
) -> void:
	var center: Vector2 = r._hex_centers[cell.id]
	var coast_dirs: PackedInt32Array = r._coast_dirs[cell.id]
	var diff_dirs: PackedInt32Array = r._diff_biome_dirs[cell.id]
	var my_z: float = r._get_cell_top_z(cell)
	var low_coast: bool = cell.altitude - r.world_state.sea_level <= 0.14

	var shore_rims := PackedVector2Array()
	var sunlit_lips := PackedVector2Array()
	var shaded_lips := PackedVector2Array()

	for e in range(6):
		var dir_idx: int = EDGE_DIR_MAP[e]
		var c0 := top_pts[e]
		var c1 := top_pts[(e + 1) % 6]
		var cm := (c0 + c1) * 0.5
		var edge_rad := deg_to_rad(60.0 * float(e) + r._built_yaw)
		var normal := Vector2(cos(edge_rad), sin(edge_rad))
		var is_sunlit := normal.dot(NW_SUN_DIR) > -0.05

		if coast_dirs.has(dir_idx):
			if low_coast:
				var in0 := c0.lerp(center, 0.10)
				var inm := cm.lerp(center, 0.13 + float(r._cell_seed(cell.q, cell.r, e * 13 + 3) % 5) * 0.008)
				var in1 := c1.lerp(center, 0.10)
				var sand_out := Color(C_SAND.r, C_SAND.g, C_SAND.b, 0.52)
				var sand_in := Color(C_SAND.r, C_SAND.g, C_SAND.b, 0.0)
				column.draw_polygon(PackedVector2Array([c0, cm, inm, in0]), PackedColorArray([sand_out, sand_out, sand_in, sand_in]))
				column.draw_polygon(PackedVector2Array([cm, c1, in1, inm]), PackedColorArray([sand_out, sand_out, sand_in, sand_in]))
				shore_rims.append(c0)
				shore_rims.append(c1)
			elif is_sunlit:
				sunlit_lips.append(c0)
				sunlit_lips.append(c1)
			else:
				shaded_lips.append(c0)
				shaded_lips.append(c1)
			continue

		var nid: String = r._neighbor_id(cell, dir_idx)
		if not r.world_state.cells.has(nid):
			continue
		var nb_cell: EvoTypes.HexCell = r.world_state.cells[nid]
		var nb_z: float = r._get_cell_top_z(nb_cell)

		if diff_dirs.has(dir_idx) and absf(nb_cell.altitude - cell.altitude) <= 0.18:
			var nb_pal: Dictionary = BIOME_PALETTE[nb_cell.biome]
			var nb_surf: Color = nb_pal["surface"]
			var in0 := c0.lerp(center, 0.11)
			var inm := cm.lerp(center, 0.15 + float(r._cell_seed(cell.q, cell.r, e * 19 + 7) % 6) * 0.008)
			var in1 := c1.lerp(center, 0.11)
			var b_out := Color(nb_surf.r, nb_surf.g, nb_surf.b, 0.25)
			var b_in := Color(nb_surf.r, nb_surf.g, nb_surf.b, 0.0)
			column.draw_polygon(PackedVector2Array([c0, cm, inm, in0]), PackedColorArray([b_out, b_out, b_in, b_in]))
			column.draw_polygon(PackedVector2Array([cm, c1, in1, inm]), PackedColorArray([b_out, b_out, b_in, b_in]))

		if nb_z < my_z - 1.0:
			if is_sunlit:
				sunlit_lips.append(c0)
				sunlit_lips.append(c1)
			else:
				shaded_lips.append(c0)
				shaded_lips.append(c1)

	if not shore_rims.is_empty():
		column.draw_multiline(shore_rims, Color(0.95, 0.86, 0.64, 0.68), 2.2)
	if not sunlit_lips.is_empty():
		column.draw_multiline(sunlit_lips, Color(1.0, 0.96, 0.84, 0.40), 2.0)
	if not shaded_lips.is_empty():
		column.draw_multiline(shaded_lips, (pal["edge"] as Color).darkened(0.24) * Color(1, 1, 1, 0.60), 1.5)


static func _draw_hex_borders(
	r: Node2D,
	column: Node2D,
	cell: EvoTypes.HexCell,
	pal: Dictionary,
	_tint_col: Color,
	top_pts: PackedVector2Array
) -> void:
	if r.active_lens == "biome":
		draw_biome_edge_transitions(r, column, cell, pal, top_pts)
		return

	var coast_dirs: PackedInt32Array = r._coast_dirs[cell.id]
	var sand_lines := PackedVector2Array()
	var edge_lines := PackedVector2Array()
	for e in range(6):
		var dir_idx: int = EDGE_DIR_MAP[e]
		var c0 := top_pts[e]
		var c1 := top_pts[(e + 1) % 6]
		if coast_dirs.has(dir_idx):
			sand_lines.append(c0)
			sand_lines.append(c1)
		else:
			edge_lines.append(c0)
			edge_lines.append(c1)

	if not sand_lines.is_empty():
		column.draw_multiline(sand_lines, C_SAND * Color(1, 1, 1, 0.75), 2.4)
	if not edge_lines.is_empty():
		column.draw_multiline(edge_lines, (pal["edge"] as Color).darkened(0.20) * Color(1, 1, 1, 0.42), 1.1)

	var ring_col := _resolve_lens_ring_color(r, cell)
	if ring_col.a > 0.01:
		var center: Vector2 = r._hex_centers[cell.id]
		var ring_pts := PackedVector2Array()
		ring_pts.resize(7)
		for i in range(7):
			ring_pts[i] = center.lerp(top_pts[i % 6], 0.86)
		column.draw_polyline(ring_pts, Color(0.08, 0.05, 0.03, 0.68 * ring_col.a), 5.6)
		column.draw_polyline(ring_pts, ring_col, 4.0)


static func _draw_dashed_hex_border(column: Node2D, pts: PackedVector2Array, col: Color, width: float) -> void:
	var dashes := PackedVector2Array()
	for i in range(6):
		var a := pts[i]
		var b := pts[(i + 1) % 6]
		dashes.append_array(PackedVector2Array([a.lerp(b, 0.14), a.lerp(b, 0.44), a.lerp(b, 0.58), a.lerp(b, 0.88)]))
	column.draw_multiline(dashes, col, width)


static func draw_water_fx(r: Node2D, fx: Node2D, hex_id: String) -> void:
	var cell: EvoTypes.HexCell = r.world_state.cells[hex_id]
	var center: Vector2 = r._hex_centers[hex_id]
	if r._is_water(cell) or cell.biome == "coastal_shallows":
		var phase: float = r._anim_time * 2.4 + float(cell.q) * 1.1 + float(cell.r) * 0.8
		var wave_offset := Vector2(sin(phase) * 7.5, cos(phase) * 3.8)
		fx.draw_line(center + wave_offset + Vector2(-24, -10), center + wave_offset + Vector2(24, -10), C_RIPPLE, 2.0)
		fx.draw_line(center - wave_offset + Vector2(-18, 12), center - wave_offset + Vector2(20, 12), C_RIPPLE, 1.6)

	var top_pts: PackedVector2Array = r._hex_polys[hex_id]
	for dir_idx in r._coast_dirs[hex_id]:
		var edge_idx: int = EDGE_DIR_MAP[dir_idx]
		var surf_pulse := 0.5 + 0.5 * sin(r._anim_time * 3.2 + float(dir_idx + cell.q))
		var inset_inner := 0.05 + surf_pulse * 0.03
		var inset_outer := -0.05 - surf_pulse * 0.03
		var c0 := top_pts[edge_idx]
		var c1 := top_pts[(edge_idx + 1) % 6]
		fx.draw_line(
			c0.lerp(center, inset_inner),
			c1.lerp(center, inset_inner),
			C_SURF,
			2.4 + surf_pulse
		)
		fx.draw_line(
			c0.lerp(center, inset_outer),
			c1.lerp(center, inset_outer),
			C_RIPPLE,
			1.6 + surf_pulse * 0.6
		)
