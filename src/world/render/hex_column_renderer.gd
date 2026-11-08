class_name EvoHexColumnRenderer
extends RefCounted

const BIOME_PALETTE: Dictionary = {
	"tropical_forest": {
		"edge": Color("#196132"),
		"tuft": Color("#3eb864"),
		"cliff_top": Color("#7c5333"),
		"cliff_bot": Color("#4d301b"),
		"overhang": Color("#258545")
	},
	"savanna": {
		"edge": Color("#946c1c"),
		"tuft": Color("#e8be4e"),
		"cliff_top": Color("#9c6234"),
		"cliff_bot": Color("#633a1c"),
		"overhang": Color("#cfa136")
	},
	"arid_steppe": {
		"edge": Color("#9e5822"),
		"tuft": Color("#eda05c"),
		"cliff_top": Color("#a85832"),
		"cliff_bot": Color("#6e3419"),
		"overhang": Color("#cc7735")
	},
	"tundra": {
		"edge": Color("#7592a3"),
		"tuft": Color("#eaf4f8"),
		"cliff_top": Color("#64748b"),
		"cliff_bot": Color("#3f4c5c"),
		"overhang": Color("#e2eff5")
	},
	"high_mountain": {
		"edge": Color("#4f4c49"),
		"tuft": Color("#cbd5e1"),
		"cliff_top": Color("#5c5855"),
		"cliff_bot": Color("#363331"),
		"overhang": Color("#99928b")
	},
	"coastal_shallows": {
		"edge": Color("#d9be7e"),
		"tuft": Color("#ebd294"),
		"cliff_top": Color("#a88e58"),
		"cliff_bot": Color("#705c35"),
		"overhang": Color("#d9be7e")
	},
	"ocean": {
		"edge": Color("#144566"),
		"tuft": Color("#7dd3fc"),
		"cliff_top": Color("#144566"),
		"cliff_bot": Color("#0d2f47"),
		"overhang": Color("#216899")
	}
}

const C_ROCK_CRACK := Color("#23150c")
const C_CLIFF_OUTLINE := Color("#23150c")
const C_SAND := Color("#ebd294")
const C_SURF := Color(0.95, 0.99, 1.0, 0.85)
const C_RIPPLE := Color(0.90, 0.98, 1.0, 0.60)


static func draw_hex_column(r: Node2D, column: Node2D, hex_id: String) -> void:
	var cell: EvoTypes.HexCell = r.world_state.cells[hex_id]
	var is_ocean: bool = r._is_water(cell)
	var eff_biome: String = "ocean" if is_ocean else cell.biome
	var pal: Dictionary = BIOME_PALETTE.get(eff_biome, BIOME_PALETTE["savanna"])
	var top_pts: PackedVector2Array = r._hex_polys[hex_id]

	if not is_ocean and cell.altitude - r.world_state.sea_level > 0.015:
		var bot_pts: PackedVector2Array = r._project_hex(HexMath.axial_to_world(cell.q, cell.r), 0.0)
		_draw_cliff_walls(r, column, cell, pal, top_pts, bot_pts)

	var tint_col := get_top_tint(r, cell, is_ocean)
	var v_colors := PackedColorArray([tint_col, tint_col, tint_col, tint_col, tint_col, tint_col])
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
	var strata_count: int = mini(tier + 1, 6)
	var cliff_top_col: Color = pal["cliff_top"]
	var cliff_bot_col: Color = pal["cliff_bot"]
	var center_y: float = r._hex_centers[cell.id].y
	var strata := PackedVector2Array()
	var cracks := PackedVector2Array()
	var vines := PackedVector2Array()
	var outlines := PackedVector2Array()

	for i in range(6):
		var next_i: int = (i + 1) % 6
		var p0 := top_pts[i]
		var p1 := top_pts[next_i]
		if (p0.y + p1.y) * 0.5 - center_y <= 0.5:
			continue
		var b1 := bot_pts[next_i]
		var b0 := bot_pts[i]

		var shade := 1.0 - float(i % 3) * 0.13
		var wall_col := cliff_top_col.lerp(cliff_bot_col, 0.45) * Color(shade, shade, shade, 1.0)
		column.draw_colored_polygon(PackedVector2Array([p0, p1, b1, b0]), wall_col)
		column.draw_colored_polygon(PackedVector2Array([p0, p1, p1.lerp(b1, 0.18), p0.lerp(b0, 0.18)]), cliff_top_col.darkened(0.18 * shade))

		for s_idx in range(1, strata_count + 1):
			var t: float = float(s_idx) / float(strata_count + 1)
			strata.append(p0.lerp(b0, t))
			strata.append(p1.lerp(b1, t))

		for c_idx in range(3):
			var u := 0.22 + float(c_idx) * 0.28 + float(r._cell_seed(cell.q, cell.r, i * 10 + c_idx) % 9 - 4) * 0.015
			var c_top := p0.lerp(p1, u)
			var c_bot := b0.lerp(b1, u)
			var t_start := 0.15 + float((c_idx + i) % 2) * 0.18
			cracks.append(c_top.lerp(c_bot, t_start))
			cracks.append(c_top.lerp(c_bot, minf(0.92, t_start + 0.45)))

		for v_idx in range(1, 5):
			var vu := float(v_idx) / 5.0
			var v_top := p0.lerp(p1, vu)
			var hang_len := 0.16 + float(r._cell_seed(cell.q, cell.r, i * 31 + v_idx) % 22) * 0.012
			vines.append(v_top)
			vines.append(v_top.lerp(b0.lerp(b1, vu), hang_len))

		outlines.append_array(PackedVector2Array([p0, p1, p1, b1, b1, b0, b0, p0]))

	if outlines.is_empty():
		return
	column.draw_multiline(strata, cliff_bot_col.darkened(0.22), 1.5)
	column.draw_multiline(cracks, C_ROCK_CRACK, 1.3)
	column.draw_multiline(vines, (pal["overhang"] as Color).darkened(0.08), 2.2)
	column.draw_multiline(outlines, C_CLIFF_OUTLINE, 1.2)


static func get_top_tint(r: Node2D, cell: EvoTypes.HexCell, is_ocean: bool) -> Color:
	var tint_col := Color.WHITE
	if is_ocean:
		return tint_col
	if r.active_lens == "food":
		var ratio_r: float = clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
		if ratio_r < 0.35:
			return Color("#8c583a").lerp(Color("#eab308"), ratio_r / 0.35)
		return Color("#eab308").lerp(Color("#65f06c"), (ratio_r - 0.35) / 0.65)
	if r.active_lens == "health":
		if not cell.deme_ids.is_empty() and r.world_state.demes.has(cell.deme_ids[0]):
			var d: EvoTypes.Deme = r.world_state.demes[cell.deme_ids[0]]
			if d.infection_turns > 0:
				return Color("#84cc16")
			if d.salubrity < 0.40:
				return Color("#f87171")
			if d.salubrity < 0.75:
				return Color("#fbbf24")
			return Color("#34d399")
		return Color("#94a3b8")
	if r.active_lens == "diplomacy" or r.active_lens == "territory":
		if not cell.deme_ids.is_empty() and r.world_state.demes.has(cell.deme_ids[0]):
			var d: EvoTypes.Deme = r.world_state.demes[cell.deme_ids[0]]
			var s_col := EvoPropFloraRenderer.resolve_deme_strategy_color(r.world_state, d)
			return Color("#cbd5e1").lerp(s_col, 0.62)
		if (cell.land_use == "crops" or cell.land_use == "pasture") and cell.owner_deme_id != "" and r.world_state.demes.has(cell.owner_deme_id):
			var owner: EvoTypes.Deme = r.world_state.demes[cell.owner_deme_id]
			var s_col := EvoPropFloraRenderer.resolve_deme_strategy_color(r.world_state, owner)
			return Color("#cbd5e1").lerp(s_col, 0.38)
		return Color("#94a3b8")
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	if k_ratio < 0.60:
		tint_col = tint_col.lerp(Color("#9c6b4e"), 0.42)
	elif k_ratio < 0.85:
		tint_col = tint_col.lerp(Color("#c29b61"), 0.22)
	if cell.land_use == "crops":
		tint_col = tint_col.lerp(Color("#e8c468"), 0.24)
	elif cell.land_use == "pasture":
		tint_col = tint_col.lerp(Color("#76c975"), 0.22)
	if cell.has_ruins:
		tint_col = tint_col.lerp(Color("#5c4a3e"), 0.28)
	return tint_col


static func _draw_hex_borders(r: Node2D, column: Node2D, cell: EvoTypes.HexCell, pal: Dictionary, tint_col: Color, top_pts: PackedVector2Array) -> void:
	var coast_dirs: PackedInt32Array = r._coast_dirs[cell.id]
	var diff_dirs: PackedInt32Array = r._diff_biome_dirs[cell.id]
	var sand_lines := PackedVector2Array()
	var edge_lines := PackedVector2Array()
	var tufts := PackedVector2Array()
	for dir_idx in range(6):
		var c0 := top_pts[dir_idx]
		var c1 := top_pts[(dir_idx + 1) % 6]
		if coast_dirs.has(dir_idx):
			sand_lines.append(c0)
			sand_lines.append(c1)
			continue
		edge_lines.append(c0)
		edge_lines.append(c1)
		var tuft_steps := 5 if diff_dirs.has(dir_idx) else 3
		for ts in range(1, tuft_steps + 1):
			var jitter := Vector2(
				float(r._cell_seed(cell.q, cell.r, dir_idx * 17 + ts) % 5 - 2),
				float(r._cell_seed(cell.q, cell.r, dir_idx * 23 + ts) % 5 - 2)
			) * 0.6
			var pt := c0.lerp(c1, float(ts) / float(tuft_steps + 1)) + jitter
			tufts.append(pt - Vector2(2.0, 0.0))
			tufts.append(pt + Vector2(2.0, 0.0))

	if not sand_lines.is_empty():
		column.draw_multiline(sand_lines, C_SAND, 3.2)
	if not edge_lines.is_empty():
		column.draw_multiline(edge_lines, (pal["edge"] as Color).darkened(0.18), 1.2)
	if not tufts.is_empty():
		column.draw_multiline(tufts, pal["tuft"] * tint_col, 3.8)


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
		var surf_pulse := 0.5 + 0.5 * sin(r._anim_time * 3.2 + float(dir_idx + cell.q))
		var inset_inner := 0.05 + surf_pulse * 0.03
		var inset_outer := -0.05 - surf_pulse * 0.03
		var c0 := top_pts[dir_idx]
		var c1 := top_pts[(dir_idx + 1) % 6]
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
