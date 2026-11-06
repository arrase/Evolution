class_name EvoWorldRenderer
extends Node2D

const PixelArtGen = preload("res://src/world/pixel_art_gen.gd")
const CameraController = preload("res://src/world/camera_controller.gd")
const Prop = EvoPropFloraRenderer.Prop

signal hex_clicked(hex_id: String, button_index: int)
signal hex_dragged(hex_id: String)
signal deme_clicked(deme_id: String, hex_id: String)

const MAX_COLUMN_HEIGHT_PX: float = 96.0

const BIOME_PALETTE: Dictionary = {
	"tropical_forest": {
		"top": Color("#2a8c4a"),
		"edge": Color("#196132"),
		"tuft": Color("#3eb864"),
		"cliff_top": Color("#7c5333"),
		"cliff_bot": Color("#4d301b"),
		"overhang": Color("#258545")
	},
	"savanna": {
		"top": Color("#c99e32"),
		"edge": Color("#946c1c"),
		"tuft": Color("#e8be4e"),
		"cliff_top": Color("#9c6234"),
		"cliff_bot": Color("#633a1c"),
		"overhang": Color("#cfa136")
	},
	"arid_steppe": {
		"top": Color("#d4873f"),
		"edge": Color("#9e5822"),
		"tuft": Color("#eda05c"),
		"cliff_top": Color("#a85832"),
		"cliff_bot": Color("#6e3419"),
		"overhang": Color("#cc7735")
	},
	"tundra": {
		"top": Color("#b8ced9"),
		"edge": Color("#7592a3"),
		"tuft": Color("#eaf4f8"),
		"cliff_top": Color("#64748b"),
		"cliff_bot": Color("#3f4c5c"),
		"overhang": Color("#e2eff5")
	},
	"high_mountain": {
		"top": Color("#787572"),
		"edge": Color("#4f4c49"),
		"tuft": Color("#cbd5e1"),
		"cliff_top": Color("#5c5855"),
		"cliff_bot": Color("#363331"),
		"overhang": Color("#99928b")
	},
	"coastal_shallows": {
		"top": Color("#32a89d"),
		"edge": Color("#d9be7e"),
		"tuft": Color("#ebd294"),
		"cliff_top": Color("#a88e58"),
		"cliff_bot": Color("#705c35"),
		"overhang": Color("#d9be7e")
	},
	"ocean": {
		"top": Color("#1d5f8a"),
		"edge": Color("#144566"),
		"tuft": Color("#7dd3fc"),
		"cliff_top": Color("#144566"),
		"cliff_bot": Color("#0d2f47"),
		"overhang": Color("#216899")
	}
}

const C_ROCK_CRACK := Color("#23150c")
const C_CLIFF_OUTLINE := Color("#26160c")
const C_SAND := Color("#ebd294")
const C_SURF := Color(0.95, 0.99, 1.0, 0.85)
const C_RIPPLE := Color(0.90, 0.98, 1.0, 0.60)
const C_SELECTION := Color("#fde047")

var world_state: EvoTypes.WorldState
var camera: CameraController
var active_lens: String = "biome"
var active_tool: String = "inspect"
var selected_hex_id: String = "0,0"
var selected_deme_id: String = ""
var highlighted_lineage_id: String = ""
var hovered_hex_id: String = ""
var hovered_deme_id: String = ""
var brush_radius: int = 1

var _world_layer := Node2D.new()
var _terrain_layer := Node2D.new()
var _network_layer := Node2D.new()
var _anim_layer := Node2D.new()
var _overlay_layer := Node2D.new()

var _anim_time: float = 0.0
var _fx_accum: float = 0.0
var _last_vp_size: Vector2 = Vector2.ZERO
var _dirty: bool = true
var _built_yaw: float = NAN
var _built_pitch: float = NAN
var _ground := Transform2D.IDENTITY
var _lift: float = 0.0
var _hex_uvs := PackedVector2Array()
var _hex_corner_offsets := PackedVector2Array()

var _columns: Dictionary = {}
var _water_fx: Dictionary = {}
var _sorted_hex_ids: Array[String] = []
var _hex_polys: Dictionary = {}
var _hex_centers: Dictionary = {}
var _coast_dirs: Dictionary = {}
var _diff_biome_dirs: Dictionary = {}
var _animated_fx_ids: Array[String] = []
var _ocean_ids: Array[String] = []
var _brush_hexes: Array[String] = []
var _roads: Array[Dictionary] = []
var _villages: Array[Dictionary] = []
var _static_props: Array[Prop] = []
var _deme_hit_rects: Array[Dictionary] = []
var _column_state_cache: Dictionary = {}
var _last_sort_signature: Array = []
var _cell_flora_cache: Dictionary = {}

var _press_pos: Vector2 = Vector2.ZERO
var _is_left_down: bool = false
var _last_dragged_hex_id: String = ""
var _particles: Array[Dictionary] = []
var _visible_world_rect: Rect2 = Rect2(-4000, -4000, 8000, 8000)
var _last_world_transform: Transform2D = Transform2D.IDENTITY
var _moving_prop_pool: Array[Prop] = []
var _moving_prop_count: int = 0
var _villager_tex_sets: Dictionary = {}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(6):
		var rad := deg_to_rad(60.0 * float(i) - 30.0)
		_hex_uvs.append(Vector2(0.5 + cos(rad) * 0.46, 0.5 + sin(rad) * 0.46))
		_hex_corner_offsets.append(Vector2(cos(rad), sin(rad)) * HexMath.HEX_SIZE)
	EvoWorldOverlayRenderer.init_particles(_particles)

	add_child(_world_layer)
	_world_layer.add_child(_terrain_layer)
	_world_layer.add_child(_network_layer)
	_world_layer.add_child(_anim_layer)
	add_child(_overlay_layer)
	_network_layer.draw.connect(_draw_network)
	_anim_layer.draw.connect(_draw_animated)
	_overlay_layer.draw.connect(_draw_overlay)


func _ready() -> void:
	PixelArtGen.ensure_all_assets()


func _process(delta: float) -> void:
	if world_state == null or camera == null:
		return
	_anim_time += delta
	EvoWorldOverlayRenderer.update_particles(self, delta)

	if _dirty:
		_rebuild()
	elif camera.yaw_deg != _built_yaw or camera.pitch_deg != _built_pitch:
		_reproject()

	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)
	var vp_changed := vp_size != _last_vp_size
	_last_vp_size = vp_size
	_world_layer.position = vp_size * 0.5 + camera.pan_offset
	_world_layer.scale = Vector2(camera.zoom_level, camera.zoom_level)

	var inv_xform := _world_layer.transform.affine_inverse()
	var tl := inv_xform * Vector2.ZERO
	var br := inv_xform * vp_size
	_visible_world_rect = Rect2(tl, br - tl).grow(280.0)

	if is_inside_tree() and _world_layer.transform != _last_world_transform:
		_last_world_transform = _world_layer.transform
		var mouse_pos := get_viewport().get_mouse_position()
		var hit_hex := _pick_hex_at(mouse_pos)
		if hit_hex != hovered_hex_id:
			hovered_hex_id = hit_hex
			_update_brush()
		var hit_deme := _pick_deme_at(mouse_pos)
		var new_hov_deme := str(hit_deme.get("deme_id", ""))
		if new_hov_deme != hovered_deme_id:
			hovered_deme_id = new_hov_deme
			_network_layer.queue_redraw()

	_fx_accum += delta
	var step_fx := false
	if _fx_accum >= 0.083:
		_fx_accum = fposmod(_fx_accum, 0.083)
		step_fx = true

	_bob_ocean_columns()
	if step_fx or vp_changed:
		for hex_id in _animated_fx_ids:
			if _visible_world_rect.has_point(_hex_centers[hex_id]):
				_water_fx[hex_id].queue_redraw()
		queue_redraw()
	_anim_layer.queue_redraw()
	_overlay_layer.queue_redraw()


func set_world_state(p_state: EvoTypes.WorldState) -> void:
	world_state = p_state
	_create_columns()
	_rebuild()


func set_camera(p_camera: CameraController) -> void:
	camera = p_camera
	_dirty = true


func refresh() -> void:
	_dirty = true


func refresh_village_decisions() -> void:
	for village in _villages:
		var deme: EvoTypes.Deme = village["deme"]
		village["archetype"] = _get_deme_dominant_archetype(deme)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var hit_hex := _pick_hex_at(mm.position)
		if hit_hex != hovered_hex_id:
			hovered_hex_id = hit_hex
			_update_brush()
		var hit_deme := _pick_deme_at(mm.position)
		var new_hov_deme := str(hit_deme.get("deme_id", ""))
		if new_hov_deme != hovered_deme_id:
			hovered_deme_id = new_hov_deme
			_network_layer.queue_redraw()
		if _is_left_down and active_tool != "inspect" and hit_hex != "" and hit_hex != _last_dragged_hex_id:
			_last_dragged_hex_id = hit_hex
			hex_dragged.emit(hit_hex)

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_is_left_down = true
				var hit_hex := _pick_hex_at(mb.position)
				_last_dragged_hex_id = hit_hex
				if active_tool != "inspect" and hit_hex != "":
					hex_clicked.emit(hit_hex, MOUSE_BUTTON_LEFT)
			else:
				_is_left_down = false
				_last_dragged_hex_id = ""
				if mb.position.distance_to(_press_pos) < 10.0 and active_tool == "inspect":
					var hit_deme := _pick_deme_at(mb.position)
					if not hit_deme.is_empty():
						deme_clicked.emit(str(hit_deme["deme_id"]), str(hit_deme["hex_id"]))
					else:
						var hit_hex := _pick_hex_at(mb.position)
						if hit_hex != "":
							hex_clicked.emit(hit_hex, MOUSE_BUTTON_LEFT)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_press_pos = mb.position
			elif mb.position.distance_to(_press_pos) < 8.0:
				var hit_hex := _pick_hex_at(mb.position)
				if hit_hex != "":
					hex_clicked.emit(hit_hex, MOUSE_BUTTON_RIGHT)


# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

func _create_columns() -> void:
	for column in _columns.values():
		column.free()
	_columns.clear()
	_water_fx.clear()
	_hex_polys.clear()
	_hex_centers.clear()
	_coast_dirs.clear()
	_diff_biome_dirs.clear()
	_column_state_cache.clear()
	_last_sort_signature.clear()
	_cell_flora_cache.clear()
	for hex_id in world_state.cells:
		var column := Node2D.new()
		column.draw.connect(_draw_hex_column.bind(column, hex_id))
		var fx := Node2D.new()
		fx.draw.connect(_draw_water_fx.bind(fx, hex_id))
		column.add_child(fx)
		_terrain_layer.add_child(column)
		_columns[hex_id] = column
		_water_fx[hex_id] = fx


func _rebuild() -> void:
	_dirty = false
	_built_yaw = camera.yaw_deg
	_built_pitch = camera.pitch_deg
	_ground = camera.ground_transform()
	_lift = camera.height_scale()
	_brush_hexes = _compute_brush_hexes()
	_rebuild_cell_topology()
	_villages = EvoPropFloraRenderer.collect_villages(self)
	_roads = EvoRoadNetworkRenderer.collect_roads(self)
	_static_props = EvoPropFloraRenderer.collect_static_props(self)
	_reproject()
	queue_redraw()


func _reproject() -> void:
	_built_yaw = camera.yaw_deg
	_built_pitch = camera.pitch_deg
	_ground = camera.ground_transform()
	_lift = camera.height_scale()
	_layout_columns()
	for village in _villages:
		var v_pos := _project(village["world_xy"], village["top_z"])
		var sf: float = village["sf"]
		village["pos"] = v_pos
		village["hit_rect"] = Rect2(v_pos - Vector2(74, 76) * sf, Vector2(148, 116) * sf)
	EvoRoadNetworkRenderer.reproject_roads(self)
	for prop in _static_props:
		prop.project(_ground, _lift)
	_static_props.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	_network_layer.queue_redraw()


func _rebuild_cell_topology() -> void:
	_animated_fx_ids.clear()
	_ocean_ids.clear()
	for hex_id in world_state.cells:
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		var is_water := _is_water(cell)
		var coast := PackedInt32Array()
		var diff_biome := PackedInt32Array()
		if is_water:
			_ocean_ids.append(hex_id)
		else:
			for dir_idx in range(6):
				var nid := _neighbor_id(cell, dir_idx)
				if not world_state.cells.has(nid) or _is_water(world_state.cells[nid]):
					coast.append(dir_idx)
				elif (world_state.cells[nid] as EvoTypes.HexCell).biome != cell.biome:
					diff_biome.append(dir_idx)
		_coast_dirs[hex_id] = coast
		_diff_biome_dirs[hex_id] = diff_biome
		if is_water or cell.biome == "coastal_shallows" or not coast.is_empty():
			_animated_fx_ids.append(hex_id)


func _layout_columns() -> void:
	var sort_sig: Array = [_built_yaw, _built_pitch, snappedf(world_state.sea_level, 0.001), world_state.cells.size()]
	for hex_id in world_state.cells:
		var c: EvoTypes.HexCell = world_state.cells[hex_id]
		sort_sig.append(_get_cell_top_z(c))

	if sort_sig != _last_sort_signature or _sorted_hex_ids.size() != world_state.cells.size():
		_last_sort_signature = sort_sig
		_sorted_hex_ids.assign(world_state.cells.keys())
		var depths: Dictionary = {}
		for hex_id in _sorted_hex_ids:
			var cell: EvoTypes.HexCell = world_state.cells[hex_id]
			depths[hex_id] = camera.get_depth(HexMath.axial_to_world(cell.q, cell.r), _get_cell_top_z(cell))
		_sorted_hex_ids.sort_custom(func(a: String, b: String) -> bool: return depths[a] < depths[b])

		for i in range(_sorted_hex_ids.size()):
			var hex_id := _sorted_hex_ids[i]
			var cell: EvoTypes.HexCell = world_state.cells[hex_id]
			var world_xy := HexMath.axial_to_world(cell.q, cell.r)
			var top_z := _get_cell_top_z(cell)
			_hex_polys[hex_id] = _project_hex(world_xy, top_z)
			_hex_centers[hex_id] = _project(world_xy, top_z)

			var column: Node2D = _columns[hex_id]
			column.position = Vector2.ZERO
			_terrain_layer.move_child(column, i)

	_terrain_layer.modulate = Color(0.94, 0.96, 0.99, 1.0) if (active_lens == "biome" and world_state.season == "dry_cold") else Color.WHITE

	for i in range(_sorted_hex_ids.size()):
		var hex_id := _sorted_hex_ids[i]
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		var is_ocean := _is_water(cell)
		var eff_biome: String = "ocean" if is_ocean else cell.biome
		var top_z := _get_cell_top_z(cell)
		var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
		var k_band: int = 0 if k_ratio < 0.60 else (1 if k_ratio < 0.85 else 2)
		var r_band: int = int(roundf(clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0) * 50.0)) if active_lens == "food" else 0
		var is_brushed := _brush_hexes.has(hex_id)

		var col_key: Array = [
			_built_yaw,
			_built_pitch,
			eff_biome,
			top_z,
			active_lens,
			k_band,
			r_band,
			hex_id == selected_hex_id,
			is_brushed,
			active_tool == "inspect" if is_brushed else false,
			_coast_dirs[hex_id],
			_diff_biome_dirs[hex_id]
		]

		if not _column_state_cache.has(hex_id) or _column_state_cache[hex_id] != col_key:
			_column_state_cache[hex_id] = col_key
			_columns[hex_id].queue_redraw()
			_water_fx[hex_id].queue_redraw()


func _compute_brush_hexes() -> Array[String]:
	if hovered_hex_id == "":
		return []
	return HexMath.get_brush_hex_ids(hovered_hex_id, brush_radius, world_state.cells)


func _update_brush() -> void:
	var previous := _brush_hexes
	_brush_hexes = _compute_brush_hexes()
	for hex_id in previous + _brush_hexes:
		_column_state_cache.erase(hex_id)
		_columns[hex_id].queue_redraw()


func _bob_ocean_columns() -> void:
	var sea_z := _sea_z()
	for hex_id in _ocean_ids:
		if not _visible_world_rect.has_point(_hex_centers[hex_id]):
			continue
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		var wave := sin(_anim_time * 2.4 + float(cell.q) * 0.7 + float(cell.r) * 0.9) * 1.2
		_columns[hex_id].position.y = -(maxf(0.0, sea_z + wave) - sea_z) * _lift


# ============================================================================
# GEOMETRY HELPERS
# ============================================================================

func _project(world_xy: Vector2, z_height: float) -> Vector2:
	return _ground * world_xy + Vector2(0.0, -z_height * _lift)


func _project_hex(world_xy: Vector2, z_height: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for offset in _hex_corner_offsets:
		pts.append(_project(world_xy + offset, z_height))
	return pts


func _cell_top_center(cell: EvoTypes.HexCell) -> Vector2:
	return _project(HexMath.axial_to_world(cell.q, cell.r), _get_cell_top_z(cell))


func _is_water(cell: EvoTypes.HexCell) -> bool:
	return cell.biome == "ocean" or cell.altitude < world_state.sea_level


func _sea_z() -> float:
	return clampf(world_state.sea_level, 0.0, 0.5) * MAX_COLUMN_HEIGHT_PX


func _get_cell_top_z(cell: EvoTypes.HexCell) -> float:
	if _is_water(cell):
		return _sea_z()
	var tier: float = clampf(ceilf(cell.altitude * 10.0), 1.0, 10.0)
	return (tier / 10.0) * MAX_COLUMN_HEIGHT_PX


func _neighbor_id(cell: EvoTypes.HexCell, dir_idx: int) -> String:
	var dir: Vector2i = HexMath.DIRECTIONS[dir_idx]
	return HexMath.make_id(cell.q + dir.x, cell.r + dir.y)


func _cell_seed(q: int, r: int, salt: int = 0) -> int:
	var h: int = (q * 73856093) ^ (r * 19349663) ^ (salt * 83492791)
	return abs(h)


# ============================================================================
# BACKDROP & TERRAIN COLUMNS
# ============================================================================

func _draw() -> void:
	if world_state == null or camera == null:
		return
	var vp_size := get_viewport_rect().size
	var is_wet := world_state.season == "wet_warm"
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color("#0e3352") if is_wet else Color("#0b2840"), true)

	var band_col := Color("#134066") if is_wet else Color("#103352")
	var band_h := 48.0
	var num_bands := int(vp_size.y / band_h) + 1
	for b in range(0, num_bands, 2):
		draw_rect(Rect2(0.0, float(b) * band_h, vp_size.x, band_h * 0.55), band_col, true)

	var wave_col := Color(0.42, 0.78, 0.96, 0.18)
	var foam_col := Color(0.85, 0.96, 1.0, 0.22)
	var rows := int(vp_size.y / 96.0) + 1
	var cols := int(vp_size.x / 180.0) + 1
	for ry in range(rows):
		for cx in range(cols):
			var phase := _anim_time * 1.9 + float(ry) * 0.75 + float(cx) * 0.55
			var wx := float(cx * 180) + sin(phase) * 9.0 + float((ry % 2) * 82)
			var wy := float(ry * 96) + cos(phase * 0.8) * 3.0
			draw_rect(Rect2(wx, wy, 16.0, 2.0), wave_col, true)
			draw_rect(Rect2(wx + 4.0, wy - 2.0, 8.0, 2.0), foam_col, true)


func _draw_hex_column(column: Node2D, hex_id: String) -> void:
	var cell: EvoTypes.HexCell = world_state.cells[hex_id]
	var is_ocean := _is_water(cell)
	var eff_biome: String = "ocean" if is_ocean else cell.biome
	var pal: Dictionary = BIOME_PALETTE.get(eff_biome, BIOME_PALETTE["savanna"])
	var top_pts: PackedVector2Array = _hex_polys[hex_id]

	if not is_ocean:
		var bot_pts := _project_hex(HexMath.axial_to_world(cell.q, cell.r), 0.0)
		_draw_cliff_walls(column, cell, pal, top_pts, bot_pts)

	var tint_col := _get_top_tint(cell, is_ocean)
	var v_colors := PackedColorArray([tint_col, tint_col, tint_col, tint_col, tint_col, tint_col])
	column.draw_polygon(top_pts, v_colors, _hex_uvs, PixelArtGen.get_texture("hex_tile_" + eff_biome))

	if not is_ocean:
		_draw_hex_borders(column, cell, pal, tint_col, top_pts)
		if active_lens == "health":
			var k_ratio: float = cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max)
			if k_ratio < 0.60:
				_draw_dashed_hex_border(column, top_pts, Color("#ef4444"), 2.6)
			elif k_ratio < 0.85:
				_draw_dashed_hex_border(column, top_pts, Color("#f59e0b"), 2.0)

	var border_pts := top_pts.duplicate()
	border_pts.append(top_pts[0])
	if hex_id == selected_hex_id:
		column.draw_polyline(border_pts, C_SELECTION, 3.4)
	elif _brush_hexes.has(hex_id):
		var brush_col := Color("#38bdf8") if active_tool == "inspect" else Color("#fb923c")
		column.draw_polyline(border_pts, brush_col, 2.6)


func _draw_cliff_walls(
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
	var center_y: float = _hex_centers[cell.id].y
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
			var u := 0.22 + float(c_idx) * 0.28 + float(_cell_seed(cell.q, cell.r, i * 10 + c_idx) % 9 - 4) * 0.015
			var c_top := p0.lerp(p1, u)
			var c_bot := b0.lerp(b1, u)
			var t_start := 0.15 + float((c_idx + i) % 2) * 0.18
			cracks.append(c_top.lerp(c_bot, t_start))
			cracks.append(c_top.lerp(c_bot, minf(0.92, t_start + 0.45)))

		for v_idx in range(1, 5):
			var vu := float(v_idx) / 5.0
			var v_top := p0.lerp(p1, vu)
			var hang_len := 0.16 + float(_cell_seed(cell.q, cell.r, i * 31 + v_idx) % 22) * 0.012
			vines.append(v_top)
			vines.append(v_top.lerp(b0.lerp(b1, vu), hang_len))

		outlines.append_array(PackedVector2Array([p0, p1, p1, b1, b1, b0, b0, p0]))

	if outlines.is_empty():
		return
	column.draw_multiline(strata, cliff_bot_col.darkened(0.22), 1.5)
	column.draw_multiline(cracks, C_ROCK_CRACK, 1.3)
	column.draw_multiline(vines, (pal["overhang"] as Color).darkened(0.08), 2.2)
	column.draw_multiline(outlines, C_CLIFF_OUTLINE, 1.2)


func _get_top_tint(cell: EvoTypes.HexCell, is_ocean: bool) -> Color:
	var tint_col := Color.WHITE
	if is_ocean:
		return tint_col
	if active_lens == "food":
		var ratio_r: float = clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
		if ratio_r < 0.35:
			return Color("#8c583a").lerp(Color("#eab308"), ratio_r / 0.35)
		return Color("#eab308").lerp(Color("#65f06c"), (ratio_r - 0.35) / 0.65)
	if active_lens == "health":
		var ratio_k: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
		if ratio_k < 0.60:
			return Color("#f87171")
		if ratio_k < 0.85:
			return Color("#fbbf24")
		return Color("#6ee7b7")
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	if k_ratio < 0.60:
		tint_col = tint_col.lerp(Color("#9c6b4e"), 0.42)
	elif k_ratio < 0.85:
		tint_col = tint_col.lerp(Color("#c29b61"), 0.22)
	return tint_col


func _draw_hex_borders(column: Node2D, cell: EvoTypes.HexCell, pal: Dictionary, tint_col: Color, top_pts: PackedVector2Array) -> void:
	var coast_dirs: PackedInt32Array = _coast_dirs[cell.id]
	var diff_dirs: PackedInt32Array = _diff_biome_dirs[cell.id]
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
				float(_cell_seed(cell.q, cell.r, dir_idx * 17 + ts) % 5 - 2),
				float(_cell_seed(cell.q, cell.r, dir_idx * 23 + ts) % 5 - 2)
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


func _draw_dashed_hex_border(column: Node2D, pts: PackedVector2Array, col: Color, width: float) -> void:
	var dashes := PackedVector2Array()
	for i in range(6):
		var a := pts[i]
		var b := pts[(i + 1) % 6]
		dashes.append_array(PackedVector2Array([a.lerp(b, 0.14), a.lerp(b, 0.44), a.lerp(b, 0.58), a.lerp(b, 0.88)]))
	column.draw_multiline(dashes, col, width)


func _draw_water_fx(fx: Node2D, hex_id: String) -> void:
	var cell: EvoTypes.HexCell = world_state.cells[hex_id]
	var center: Vector2 = _hex_centers[hex_id]
	if _is_water(cell) or cell.biome == "coastal_shallows":
		var phase := _anim_time * 2.4 + float(cell.q) * 1.1 + float(cell.r) * 0.8
		var wave_offset := Vector2(sin(phase) * 7.5, cos(phase) * 3.8)
		fx.draw_line(center + wave_offset + Vector2(-24, -10), center + wave_offset + Vector2(24, -10), C_RIPPLE, 2.0)
		fx.draw_line(center - wave_offset + Vector2(-18, 12), center - wave_offset + Vector2(20, 12), C_RIPPLE, 1.6)

	var top_pts: PackedVector2Array = _hex_polys[hex_id]
	for dir_idx in _coast_dirs[hex_id]:
		var surf_pulse := 0.5 + 0.5 * sin(_anim_time * 3.2 + float(dir_idx + cell.q))
		var inset := 0.06 + surf_pulse * 0.04
		fx.draw_line(
			top_pts[dir_idx].lerp(center, inset),
			top_pts[(dir_idx + 1) % 6].lerp(center, inset),
			C_SURF,
			2.0 + surf_pulse
		)


# ============================================================================
# DELEGATED LAYERS: NETWORK, ANIMATED PROPS & OVERLAY
# ============================================================================

func _draw_network() -> void:
	EvoRoadNetworkRenderer.draw_network_roads(self)
	for village in _villages:
		EvoPropFloraRenderer.draw_village_plaza(self, village)


func _draw_animated() -> void:
	EvoRoadNetworkRenderer.draw_animated_roads(self)

	if highlighted_lineage_id != "":
		for village in _villages:
			var deme: EvoTypes.Deme = village["deme"]
			if deme.lineage_id == highlighted_lineage_id:
				var v_pos: Vector2 = village["pos"]
				if not _visible_world_rect.has_point(v_pos):
					continue
				var sf: float = village["sf"]
				var beam_col := Color(deme.color)
				beam_col.a = 0.28 + 0.10 * sin(_anim_time * 4.0)
				var beam_w := 44.0 * sf
				_anim_layer.draw_rect(Rect2(v_pos.x - beam_w * 0.5, v_pos.y - 180.0 * sf, beam_w, 180.0 * sf), beam_col, true)

	EvoPropFloraRenderer.draw_props(self)


func _draw_overlay() -> void:
	EvoWorldOverlayRenderer.draw_overlay(self)


func _get_villager_textures_for_color(tunic_col: Color) -> Array[ImageTexture]:
	return EvoPropFloraRenderer.get_villager_textures_for_color(self, tunic_col)


func _get_village_building_layout(
	tier: int,
	sf: float,
	has_culture: bool,
	cultural_count: int,
	archetype: String
) -> Array[Dictionary]:
	return EvoPropFloraRenderer.get_village_building_layout(tier, sf, has_culture, cultural_count, archetype)


func _get_deme_dominant_archetype(deme: EvoTypes.Deme) -> String:
	return EvoPropFloraRenderer.get_deme_dominant_archetype(self, deme)


func _collect_moving_props() -> Array[Prop]:
	return EvoPropFloraRenderer.collect_moving_props(self)


# ============================================================================
# HIT-TESTING HELPERS
# ============================================================================

func _pick_deme_at(screen_pos: Vector2) -> Dictionary:
	for i in range(_deme_hit_rects.size() - 1, -1, -1):
		var entry: Dictionary = _deme_hit_rects[i]
		if (entry["rect"] as Rect2).has_point(screen_pos):
			return entry
	return {}


func _pick_hex_at(screen_pos: Vector2) -> String:
	var local_pos := _world_layer.transform.affine_inverse() * screen_pos
	var max_r_sq := HexMath.HEX_SIZE * HexMath.HEX_SIZE * 1.35
	for i in range(_sorted_hex_ids.size() - 1, -1, -1):
		var hex_id := _sorted_hex_ids[i]
		if local_pos.distance_squared_to(_hex_centers.get(hex_id, local_pos)) > max_r_sq:
			continue
		if Geometry2D.is_point_in_polygon(local_pos, _hex_polys[hex_id]):
			return hex_id
	return ""
