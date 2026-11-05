class_name EvoWorldRenderer
extends Node2D

const PixelArtGen = preload("res://src/world/pixel_art_gen.gd")
const CameraController = preload("res://src/world/camera_controller.gd")

signal hex_clicked(hex_id: String, button_index: int)
signal hex_dragged(hex_id: String)
signal deme_clicked(deme_id: String, hex_id: String)

const MAX_COLUMN_HEIGHT_PX: float = 44.0

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

const STATUS_COLORS: Dictionary = {
	"thriving": Color("#34d399"),
	"stable": Color("#38bdf8"),
	"struggling": Color("#fbbf24"),
	"starving": Color("#fb7185")
}

const C_ROCK_CRACK := Color("#23150c")
const C_CLIFF_OUTLINE := Color("#26160c")
const C_SAND := Color("#ebd294")
const C_SURF := Color(0.95, 0.99, 1.0, 0.85)
const C_RIPPLE := Color(0.90, 0.98, 1.0, 0.60)
const C_SELECTION := Color("#fde047")
const NON_SWAYING_SPRITES: Array[String] = ["mossy_rock", "fallen_log", "rock_mountain", "tree_stump", "soil_crack"]
const VILLAGER_POSES: Array[String] = ["villager_idle", "villager_walk1", "villager_walk2"]
const TRAVELER_ROAD_KINDS: Array[String] = ["collab", "bridge"]

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
		"rock_mountain", "mossy_rock", "tree_tundra", "rock_mountain",
		"mossy_rock", "tree_tundra_2", "rock_mountain"
	],
	"coastal_shallows": [
		"coastal_reeds", "wildflowers", "coastal_reeds", "tall_grass",
		"mossy_rock", "coastal_reeds"
	]
}
const DEFAULT_FLORA_PALETTE: Array[String] = ["tree_savanna", "wildflowers", "tall_grass"]


# A Y-sorted sprite in world-layer space, anchored at its foot point.
class Prop:
	var world_xy: Vector2
	var top_z: float
	var screen_offset: Vector2
	var anchor_offset: Vector2
	var y: float
	var texture: Texture2D
	var rect: Rect2
	var modulate: Color
	var sways: bool = false
	var sway_phase: float = 0.0

	func _init(p_texture: Texture2D, scale: float, anchor_y: float, p_modulate: Color) -> void:
		texture = p_texture
		var size := p_texture.get_size() * scale
		anchor_offset = Vector2(size.x * 0.5, size.y * anchor_y)
		rect = Rect2(Vector2.ZERO, size)
		modulate = p_modulate

	func set_foot(foot: Vector2) -> void:
		rect.position = foot - anchor_offset
		y = foot.y

	func project(ground: Transform2D, lift: float) -> void:
		set_foot(ground * world_xy + Vector2(0.0, -top_z * lift) + screen_offset)


var world_state: EvoTypes.WorldState
var camera: CameraController
var active_lens: String = "biome" # "biome" | "food" | "health"
var active_tool: String = "inspect"
var selected_hex_id: String = "0,0"
var selected_deme_id: String = ""
var highlighted_lineage_id: String = ""
var hovered_hex_id: String = ""
var brush_radius: int = 1

# Layer stack. Pan & zoom only change _world_layer's transform, so the cached
# command lists of the static layers are reused untouched while the camera moves.
var _world_layer := Node2D.new() # pan/zoom transform
var _terrain_layer := Node2D.new() # one cached canvas item per hex column, depth-sorted
var _network_layer := Node2D.new() # static roads, bridges & village plazas
var _anim_layer := Node2D.new() # per-frame: road traffic, beams, Y-sorted props & villagers
var _overlay_layer := Node2D.new() # per-frame, screen-space: signboards & particles

var _anim_time: float = 0.0
var _dirty: bool = true
var _built_yaw: float = NAN
var _built_pitch: float = NAN
var _ground := Transform2D.IDENTITY
var _lift: float = 0.0
var _hex_uvs := PackedVector2Array()
var _hex_corner_offsets := PackedVector2Array()

var _columns: Dictionary = {} # hex_id -> Node2D (static column)
var _water_fx: Dictionary = {} # hex_id -> Node2D (animated ripples/surf, child of column)
var _sorted_hex_ids: Array[String] = [] # back-to-front
var _hex_polys: Dictionary = {} # hex_id -> PackedVector2Array top polygon
var _hex_centers: Dictionary = {} # hex_id -> Vector2 top center
var _coast_dirs: Dictionary = {} # hex_id -> PackedInt32Array of edges facing water
var _diff_biome_dirs: Dictionary = {} # hex_id -> PackedInt32Array of inland edges facing another biome
var _animated_fx_ids: Array[String] = []
var _ocean_ids: Array[String] = []
var _brush_hexes: Array[String] = []
var _roads: Array[Dictionary] = []
var _villages: Array[Dictionary] = []
var _static_props: Array[Prop] = []
var _deme_hit_rects: Array[Dictionary] = [] # [{rect: Rect2 (screen), deme_id: String, hex_id: String}]

var _press_pos: Vector2 = Vector2.ZERO
var _is_left_down: bool = false
var _last_dragged_hex_id: String = ""
var _particles: Array[Dictionary] = []


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(6):
		var rad := deg_to_rad(60.0 * float(i) - 30.0)
		_hex_uvs.append(Vector2(0.5 + cos(rad) * 0.46, 0.5 + sin(rad) * 0.46))
		_hex_corner_offsets.append(Vector2(cos(rad), sin(rad)) * HexMath.HEX_SIZE)
	_init_particles()

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
	_anim_time += delta
	_update_particles(delta)

	if _dirty:
		_rebuild()
	elif camera.yaw_deg != _built_yaw or camera.pitch_deg != _built_pitch:
		_reproject()

	_world_layer.position = get_viewport_rect().size * 0.5 + camera.pan_offset
	_world_layer.scale = Vector2(camera.zoom_level, camera.zoom_level)
	_bob_ocean_columns()
	for hex_id in _animated_fx_ids:
		_water_fx[hex_id].queue_redraw()
	_anim_layer.queue_redraw()
	_overlay_layer.queue_redraw()
	queue_redraw()


func set_world_state(p_state: EvoTypes.WorldState) -> void:
	world_state = p_state
	_create_columns()
	_rebuild()


func set_camera(p_camera: CameraController) -> void:
	camera = p_camera
	_dirty = true


# Schedules a rebuild of the cached static layers (world state, selection, lens or tool changed).
func refresh() -> void:
	_dirty = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var hit_hex := _pick_hex_at(mm.position)
		if hit_hex != hovered_hex_id:
			hovered_hex_id = hit_hex
			_update_brush()
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
						hex_clicked.emit(str(hit_deme["hex_id"]), MOUSE_BUTTON_LEFT)
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
	_brush_hexes = _compute_brush_hexes()
	_rebuild_cell_topology()
	_villages = _collect_villages()
	_static_props = _collect_static_props()
	_reproject()


func _reproject() -> void:
	_built_yaw = camera.yaw_deg
	_built_pitch = camera.pitch_deg
	_ground = camera.ground_transform()
	_lift = camera.height_scale()
	_layout_columns()
	_roads = _collect_roads()
	for village in _villages:
		var v_pos := _project(village["world_xy"], village["top_z"])
		var sf: float = village["sf"]
		village["pos"] = v_pos
		village["hit_rect"] = Rect2(v_pos - Vector2(22, 26) * sf, Vector2(44, 40) * sf)
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
		column.queue_redraw()
		_water_fx[hex_id].queue_redraw()


func _compute_brush_hexes() -> Array[String]:
	if hovered_hex_id == "":
		return []
	return HexMath.get_brush_hex_ids(hovered_hex_id, brush_radius, world_state.cells)


# Hovering only touches a handful of columns: redraw those instead of the whole map.
func _update_brush() -> void:
	var previous := _brush_hexes
	_brush_hexes = _compute_brush_hexes()
	for hex_id in previous + _brush_hexes:
		_columns[hex_id].queue_redraw()


# Ocean swell moves whole water columns (they have no cliffs) via their transform.
func _bob_ocean_columns() -> void:
	var sea_z := _sea_z()
	for hex_id in _ocean_ids:
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		var wave := sin(_anim_time * 2.4 + float(cell.q) * 0.7 + float(cell.r) * 0.9) * 1.2
		_columns[hex_id].position.y = -(maxf(0.0, sea_z + wave) - sea_z) * _lift


# ============================================================================
# GEOMETRY HELPERS (world-layer space: ground rotation & pitch, no pan/zoom)
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
# BACKDROP (screen-space, per frame)
# ============================================================================

func _draw() -> void:
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
	var rows := int(vp_size.y / 34.0) + 1
	var cols := int(vp_size.x / 58.0) + 1
	for ry in range(rows):
		for cx in range(cols):
			var phase := _anim_time * 1.9 + float(ry) * 0.75 + float(cx) * 0.55
			var wx := float(cx * 58) + sin(phase) * 9.0 + float((ry % 2) * 26)
			var wy := float(ry * 34) + cos(phase * 0.8) * 3.0
			draw_rect(Rect2(wx, wy, 16.0, 2.0), wave_col, true)
			draw_rect(Rect2(wx + 4.0, wy - 2.0, 8.0, 2.0), foam_col, true)


# ============================================================================
# TERRAIN COLUMNS (cached per hex, redrawn only when invalidated)
# ============================================================================

func _draw_hex_column(column: Node2D, hex_id: String) -> void:
	var cell: EvoTypes.HexCell = world_state.cells[hex_id]
	var is_ocean := _is_water(cell)
	var eff_biome: String = "ocean" if is_ocean else cell.biome
	var pal: Dictionary = BIOME_PALETTE.get(eff_biome, BIOME_PALETTE["savanna"])
	var top_pts: PackedVector2Array = _hex_polys[hex_id]

	if not is_ocean:
		var bot_pts := _project_hex(HexMath.axial_to_world(cell.q, cell.r), 0.0)
		_draw_cliff_walls(column, cell, pal, top_pts, bot_pts)

	# Pixel-Art Hex Parcel Texture Mapping (112x96 crisp 16-bit texture)
	var tint_col := _get_top_tint(cell, is_ocean)
	var v_colors := PackedColorArray([tint_col, tint_col, tint_col, tint_col, tint_col, tint_col])
	column.draw_polygon(top_pts, v_colors, _hex_uvs, PixelArtGen.get_texture("hex_tile_" + eff_biome))

	if not is_ocean:
		_draw_hex_borders(column, cell, pal, tint_col, top_pts)
		# Ecological degradation dashed border (amber for degraded, crimson for collapsed)
		var k_ratio: float = cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max)
		if k_ratio < 0.60:
			_draw_dashed_hex_border(column, top_pts, Color("#ef4444"), 2.6)
		elif k_ratio < 0.85:
			_draw_dashed_hex_border(column, top_pts, Color("#f59e0b"), 2.0)

	# Selection / Brush highlights
	var border_pts := top_pts.duplicate()
	border_pts.append(top_pts[0])
	if hex_id == selected_hex_id:
		column.draw_polyline(border_pts, C_SELECTION, 3.4)
	elif _brush_hexes.has(hex_id):
		var brush_col := Color("#38bdf8") if active_tool == "inspect" else Color("#fb923c")
		column.draw_polyline(border_pts, brush_col, 2.6)


# Stratified 3D cliff walls with cracks & hanging vines. Line details of all walls are
# batched into a few multiline commands instead of dozens of individual lines.
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
		# Back-face culling: only walls whose top edge lies in front of the hex center
		# are visible. The margin also skips edge-on walls (degenerate zero-width quads).
		if (p0.y + p1.y) * 0.5 - center_y <= 0.5:
			continue
		var b1 := bot_pts[next_i]
		var b0 := bot_pts[i]

		var shade := 1.0 - float(i % 3) * 0.13
		var wall_col := cliff_top_col.lerp(cliff_bot_col, 0.45) * Color(shade, shade, shade, 1.0)
		column.draw_colored_polygon(PackedVector2Array([p0, p1, b1, b0]), wall_col)
		# Upper darker rock lip under overhang
		column.draw_colored_polygon(PackedVector2Array([p0, p1, p1.lerp(b1, 0.18), p0.lerp(b0, 0.18)]), cliff_top_col.darkened(0.18 * shade))

		# Horizontal geological strata bands
		for s_idx in range(1, strata_count + 1):
			var t: float = float(s_idx) / float(strata_count + 1)
			strata.append(p0.lerp(b0, t))
			strata.append(p1.lerp(b1, t))

		# Vertical pixel fissures / rock cracks
		for c_idx in range(3):
			var u := 0.22 + float(c_idx) * 0.28 + float(_cell_seed(cell.q, cell.r, i * 10 + c_idx) % 9 - 4) * 0.015
			var c_top := p0.lerp(p1, u)
			var c_bot := b0.lerp(b1, u)
			var t_start := 0.15 + float((c_idx + i) % 2) * 0.18
			cracks.append(c_top.lerp(c_bot, t_start))
			cracks.append(c_top.lerp(c_bot, minf(0.92, t_start + 0.45)))

		# Hanging ivy / roots / moss / snow icicles draping from top edge onto cliff
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
	if world_state.season == "dry_cold":
		tint_col = tint_col.lerp(Color("#d8e8f2"), 0.16)
	return tint_col


# Organic pixel-art borders: golden sand on shorelines, grass/stone tufts inland.
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


# Animated water ripples & coastal surf, drawn right above their own column so
# front columns still occlude them correctly.
func _draw_water_fx(fx: Node2D, hex_id: String) -> void:
	var cell: EvoTypes.HexCell = world_state.cells[hex_id]
	var center: Vector2 = _hex_centers[hex_id]
	if _is_water(cell) or cell.biome == "coastal_shallows":
		var phase := _anim_time * 2.4 + float(cell.q) * 1.1 + float(cell.r) * 0.8
		var wave_offset := Vector2(sin(phase) * 4.5, cos(phase) * 2.2)
		fx.draw_line(center + wave_offset + Vector2(-11, -4), center + wave_offset + Vector2(11, -4), C_RIPPLE, 2.0)
		fx.draw_line(center - wave_offset + Vector2(-7, 6), center - wave_offset + Vector2(9, 6), C_RIPPLE, 1.6)

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
# INTER-VILLAGE NETWORK (ROADS, BRIDGES, BARRICADES, BROKEN ROADS, EXPEDITIONS)
# ============================================================================

func _collect_roads() -> Array[Dictionary]:
	var roads: Array[Dictionary] = []
	var handled_deme_pairs: Dictionary = {}
	var handled_hex_pairs: Dictionary = {}

	# 1. Explicit active flows from simulation engine
	for flow in world_state.active_flows:
		if not world_state.cells.has(flow.from_hex_id) or not world_state.cells.has(flow.to_hex_id):
			continue
		var cell_a: EvoTypes.HexCell = world_state.cells[flow.from_hex_id]
		var cell_b: EvoTypes.HexCell = world_state.cells[flow.to_hex_id]
		var p_a := _get_flow_endpoint(cell_a, flow.from_deme_id, 0)
		var p_b := _get_flow_endpoint(cell_b, flow.to_deme_id, 1)

		handled_hex_pairs[_make_pair_key(flow.from_hex_id, flow.to_hex_id)] = true
		if flow.from_deme_id != "" and flow.to_deme_id != "":
			handled_deme_pairs[_make_pair_key(flow.from_deme_id, flow.to_deme_id)] = true

		match flow.flow_type:
			"dispute":
				roads.append({"kind": "dispute", "p_a": p_a, "p_b": p_b})
			"exchange", "cooperate", "merge":
				var kind := "bridge" if _should_use_bridge(cell_a, cell_b) else "collab"
				roads.append({"kind": kind, "p_a": p_a, "p_b": p_b, "color": Color("#eab308")})
			"migration":
				roads.append({"kind": "expedition", "p_a": p_a, "p_b": p_b})

	# 2. All cohabiting (dist == 0) and neighboring (dist == 1) village pairs
	var all_demes: Array[EvoTypes.Deme] = []
	for d_id in world_state.demes.keys():
		var d: EvoTypes.Deme = world_state.demes[d_id]
		if d.population > 0 and world_state.cells.has(d.hex_id):
			all_demes.append(d)

	var connected_deme_ids: Dictionary = {}

	for i in range(all_demes.size()):
		var da: EvoTypes.Deme = all_demes[i]
		var ca: EvoTypes.HexCell = world_state.cells[da.hex_id]
		for j in range(i + 1, all_demes.size()):
			var db: EvoTypes.Deme = all_demes[j]
			var cb: EvoTypes.HexCell = world_state.cells[db.hex_id]
			var dist := HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r)
			if dist > 1:
				continue

			connected_deme_ids[da.id] = true
			connected_deme_ids[db.id] = true

			var d_key := _make_pair_key(da.id, db.id)
			if handled_deme_pairs.has(d_key):
				continue
			handled_deme_pairs[d_key] = true
			handled_hex_pairs[_make_pair_key(ca.id, cb.id)] = true

			var p_a := _get_deme_local_pos(ca, da.id)
			var p_b := _get_deme_local_pos(cb, db.id)
			match _classify_village_pair_relation(da, db):
				"dispute_front":
					roads.append({"kind": "dispute", "p_a": p_a, "p_b": p_b})
				"active_road":
					var kind := "bridge" if dist == 1 and _should_use_bridge(ca, cb) else "collab"
					roads.append({"kind": kind, "p_a": p_a, "p_b": p_b, "color": Color(da.color)})
				_:
					roads.append({"kind": "broken", "p_a": p_a, "p_b": p_b})

	# 3. Long-range ancestral / split-lineage connections (e.g., across the Rift pass when dist > 1)
	if all_demes.size() >= 2:
		for i in range(all_demes.size()):
			var da: EvoTypes.Deme = all_demes[i]
			if connected_deme_ids.has(da.id):
				continue
			var ca: EvoTypes.HexCell = world_state.cells[da.hex_id]
			# Find closest other village within distance 4
			var best_db: EvoTypes.Deme = null
			var best_dist: int = 999
			for j in range(all_demes.size()):
				if i == j:
					continue
				var candidate: EvoTypes.Deme = all_demes[j]
				var cb_cand: EvoTypes.HexCell = world_state.cells[candidate.hex_id]
				var d_val := HexMath.hex_distance(ca.q, ca.r, cb_cand.q, cb_cand.r)
				if d_val <= 4 and d_val < best_dist:
					best_dist = d_val
					best_db = candidate
			if best_db != null:
				var d_key := _make_pair_key(da.id, best_db.id)
				if not handled_deme_pairs.has(d_key):
					handled_deme_pairs[d_key] = true
					var cb: EvoTypes.HexCell = world_state.cells[best_db.hex_id]
					var p_a := _get_deme_local_pos(ca, da.id)
					var p_b := _get_deme_local_pos(cb, best_db.id)
					var mid_cell_id := "0,0"
					if world_state.cells.has(mid_cell_id):
						var p_mid := _cell_top_center(world_state.cells[mid_cell_id])
						roads.append({"kind": "broken", "p_a": p_a, "p_b": p_mid})
						roads.append({"kind": "broken", "p_a": p_mid, "p_b": p_b})
					else:
						roads.append({"kind": "broken", "p_a": p_a, "p_b": p_b})

	# 4. Pioneer / Coastal Shallows Exploration Causeways for single isolated villages with shallow land bridges
	for da in all_demes:
		if connected_deme_ids.has(da.id):
			continue
		var ca: EvoTypes.HexCell = world_state.cells[da.hex_id]
		var p_a := _get_deme_local_pos(ca, da.id)
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, world_state.cells):
			var ncell: EvoTypes.HexCell = world_state.cells[n_id]
			if ncell.biome == "coastal_shallows" and ncell.altitude >= world_state.sea_level:
				var h_key := _make_pair_key(ca.id, ncell.id)
				if not handled_hex_pairs.has(h_key):
					handled_hex_pairs[h_key] = true
					roads.append({"kind": "expedition", "p_a": p_a, "p_b": _cell_top_center(ncell)})

	# 5. Disused connections from previous turns
	for disused in world_state.disused_connections:
		var from_id := str(disused.get("from_hex_id", ""))
		var to_id := str(disused.get("to_hex_id", ""))
		var h_key := _make_pair_key(from_id, to_id)
		if handled_hex_pairs.has(h_key):
			continue
		if world_state.cells.has(from_id) and world_state.cells.has(to_id):
			handled_hex_pairs[h_key] = true
			roads.append({
				"kind": "broken",
				"p_a": _cell_top_center(world_state.cells[from_id]),
				"p_b": _cell_top_center(world_state.cells[to_id])
			})

	return roads


func _draw_network() -> void:
	for road in _roads:
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		match road["kind"]:
			"collab":
				_draw_collaboration_route(p_a, p_b)
			"bridge":
				_draw_wooden_bridge(p_a, p_b)
			"dispute":
				_draw_dispute_barricade_front(p_a, p_b)
			"broken":
				_draw_broken_cut_road(p_a, p_b)
			"expedition":
				_draw_migration_expedition(p_a, p_b)
	for village in _villages:
		_draw_village_plaza(village)


func _make_pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


func _should_use_bridge(cell_a: EvoTypes.HexCell, cell_b: EvoTypes.HexCell) -> bool:
	return (
		cell_a.biome == "coastal_shallows"
		or cell_b.biome == "coastal_shallows"
		or cell_a.altitude < world_state.sea_level
		or cell_b.altitude < world_state.sea_level
		or absf(cell_a.altitude - cell_b.altitude) >= 0.20
	)


func _get_deme_archetype_prob(deme: EvoTypes.Deme, target_arch: String) -> float:
	var total := 0.0
	for dec_id in deme.last_decision_probabilities.keys():
		var prob := float(deme.last_decision_probabilities[dec_id])
		if world_state.decisions_catalog.has(dec_id):
			var d_def: EvoTypes.DecisionDef = world_state.decisions_catalog[dec_id]
			if d_def.archetype == target_arch:
				total += prob
		elif str(dec_id).contains(target_arch):
			total += prob
	return total


func _classify_village_pair_relation(da: EvoTypes.Deme, db: EvoTypes.Deme) -> String:
	var arch_a := _get_deme_dominant_archetype(da)
	var arch_b := _get_deme_dominant_archetype(db)

	var disp_a := _get_deme_archetype_prob(da, "dispute")
	var disp_b := _get_deme_archetype_prob(db, "dispute")
	var over_a := _get_deme_archetype_prob(da, "overexploit")
	var over_b := _get_deme_archetype_prob(db, "overexploit")

	var has_conflict_stance: bool = (
		disp_a >= 0.10 or disp_b >= 0.10
		or over_a >= 0.30 or over_b >= 0.30
		or arch_a == "dispute" or arch_b == "dispute"
		or arch_a == "overexploit" or arch_b == "overexploit"
	)

	if da.lineage_id != db.lineage_id and has_conflict_stance:
		return "dispute_front"
	if arch_a == "dispute" or arch_b == "dispute":
		return "dispute_front"

	var coop_a := _get_deme_archetype_prob(da, "cooperate") + _get_deme_archetype_prob(da, "exchange")
	var coop_b := _get_deme_archetype_prob(db, "cooperate") + _get_deme_archetype_prob(db, "exchange")

	if coop_a >= 0.14 or coop_b >= 0.14 or arch_a in ["cooperate", "exchange"] or arch_b in ["cooperate", "exchange"]:
		return "active_road"
	if da.lineage_id == db.lineage_id and da.isolation_turns < 3 and db.isolation_turns < 3 and not has_conflict_stance:
		return "active_road"

	return "broken_road"


func _get_deme_local_pos(cell: EvoTypes.HexCell, deme_id: String) -> Vector2:
	var w_xy := HexMath.axial_to_world(cell.q, cell.r)
	var idx := cell.deme_ids.find(deme_id)
	if idx >= 0:
		w_xy += HexMath.compute_village_sector_offset(idx, cell.deme_ids.size(), HexMath.HEX_SIZE)
	return _project(w_xy, _get_cell_top_z(cell))


func _get_flow_endpoint(cell: EvoTypes.HexCell, deme_id: String, fallback_idx: int) -> Vector2:
	var w_xy := HexMath.axial_to_world(cell.q, cell.r)
	var idx := cell.deme_ids.find(deme_id)
	if idx == -1 and cell.deme_ids.size() > 0:
		idx = fallback_idx % cell.deme_ids.size()
	if idx >= 0:
		w_xy += HexMath.compute_village_sector_offset(idx, cell.deme_ids.size(), HexMath.HEX_SIZE)
	return _project(w_xy, _get_cell_top_z(cell))


func _sample_road_curve(p_a: Vector2, p_b: Vector2, t: float, curve_sign: float) -> Vector2:
	var diff := p_b - p_a
	var dist := diff.length()
	var perp := Vector2(-diff.y, diff.x).normalized() if dist > 0.01 else Vector2.UP
	var ctrl := (p_a + p_b) * 0.5 + perp * (minf(dist * 0.14, 14.0) * curve_sign)
	var u := 1.0 - t
	return (u * u) * p_a + (2.0 * u * t) * ctrl + (t * t) * p_b


func _bridge_arch_point(p_a: Vector2, p_b: Vector2, t: float) -> Vector2:
	return p_a.lerp(p_b, t) + Vector2(0, sin(t * PI) * -5.5)


func _draw_collaboration_route(p_a: Vector2, p_b: Vector2) -> void:
	var ci := _network_layer
	# 1. Sinuous Stardew Valley cobblestone road with stone curbs
	var segments := 18
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(_sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0))

	# Dark earth foundation & stone curb border
	ci.draw_polyline(pts, Color("#4a3219"), 10.5)
	ci.draw_polyline(pts, Color("#8c6d46"), 8.4)
	ci.draw_polyline(pts, Color("#d6b88a"), 5.8)

	# Individual pixel-art cobblestones along the winding road
	for i in range(1, segments):
		var pt := pts[i]
		var dir := (pts[i + 1] - pts[i - 1]).normalized()
		var perp := Vector2(-dir.y, dir.x)
		ci.draw_circle(pt + perp * 1.6, 2.1, Color("#e6ccb2") if i % 2 == 0 else Color("#c4a474"))
		ci.draw_circle(pt - perp * 1.6, 1.9, Color("#b89566"))

	# Roadside wooden lantern post with warm golden glow
	var lantern_pt := _sample_road_curve(p_a, p_b, 0.32, 1.0) + Vector2(0, -4.0)
	ci.draw_circle(lantern_pt + Vector2(2.0, -5.0), 8.0, Color(1.0, 0.88, 0.38, 0.25))
	_draw_centered_sprite(ci, "road_lantern", lantern_pt, 0.72)

	# Midpoint Alliance / Trade Emblem Badge
	var mid := _sample_road_curve(p_a, p_b, 0.5, 1.0) + Vector2(0, -10.0)
	ci.draw_circle(mid, 8.5, Color("#064e3b"))
	ci.draw_circle(mid, 7.2, Color("#10b981"))
	_draw_centered_sprite(ci, "icon_coop_link", mid + Vector2(0, 5.0), 0.72)


func _draw_wooden_bridge(p_a: Vector2, p_b: Vector2) -> void:
	var ci := _network_layer
	var diff := p_b - p_a
	var dir := diff.normalized() if diff.length() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	# Vertical wooden support pilings into the water/ravine below
	for t_pile in [0.22, 0.50, 0.78]:
		var base_pt := p_a.lerp(p_b, t_pile)
		var pile_top := base_pt + Vector2(0, -3.0)
		var pile_bot := base_pt + Vector2(0, 11.0)
		ci.draw_line(pile_top - perp * 3.5, pile_bot - perp * 3.5, Color("#3d2314"), 2.8)
		ci.draw_line(pile_top + perp * 3.5, pile_bot + perp * 3.5, Color("#4a2c18"), 2.8)
		# Water ripple around piling base
		ci.draw_line(pile_bot - Vector2(5.0, 0), pile_bot + Vector2(5.0, 0), Color(0.88, 0.97, 1.0, 0.65), 1.5)

	# Bridge deck & side beams
	var steps := 14
	var curve_pts := PackedVector2Array()
	var rail_left := PackedVector2Array()
	var rail_right := PackedVector2Array()
	for i in range(steps + 1):
		var pt := _bridge_arch_point(p_a, p_b, float(i) / float(steps))
		curve_pts.append(pt)
		rail_left.append(pt - perp * 4.8 + Vector2(0, -3.5))
		rail_right.append(pt + perp * 4.8 + Vector2(0, -3.5))

	ci.draw_polyline(curve_pts, Color("#3d2314"), 10.2)
	ci.draw_polyline(curve_pts, Color("#b07d4f"), 7.4)

	# Individual wooden planks perpendicular to bridge
	for i in range(1, steps):
		var c := curve_pts[i]
		ci.draw_line(c - perp * 4.4, c + perp * 4.4, Color("#d4a373") if i % 2 == 0 else Color("#8c5830"), 2.2)

	# Handrails
	ci.draw_polyline(rail_left, Color("#6b3e26"), 1.8)
	ci.draw_polyline(rail_right, Color("#6b3e26"), 1.8)

	var mid := curve_pts[steps / 2] + Vector2(0, -11.0)
	ci.draw_circle(mid, 8.0, Color("#064e3b"))
	ci.draw_circle(mid, 6.8, Color("#10b981"))
	_draw_centered_sprite(ci, "icon_coop_link", mid + Vector2(0, 4.8), 0.70)


func _draw_dispute_barricade_front(p_a: Vector2, p_b: Vector2) -> void:
	var ci := _network_layer
	var diff := p_b - p_a
	var dir := diff.normalized() if diff.length() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := (p_a + p_b) * 0.5

	# 1. Split trampled war-paths stopping at the frontier barricades
	var stop_a := p_a.lerp(p_b, 0.36)
	var stop_b := p_b.lerp(p_a, 0.36)
	ci.draw_line(p_a, stop_a, Color("#3b2313"), 7.5)
	ci.draw_line(p_a, stop_a, Color("#785233"), 5.0)
	ci.draw_line(p_b, stop_b, Color("#3b2313"), 7.5)
	ci.draw_line(p_b, stop_b, Color("#785233"), 5.0)

	# Scorched earth & battle debris in the no-man's-land center
	_draw_ellipse_filled(ci, mid, 13.0, 7.5, Color(0.16, 0.08, 0.05, 0.78))
	ci.draw_line(mid - perp * 11.0, mid + perp * 11.0, Color("#dc2626"), 2.2)

	# 2. Two opposing sharpened log barricades (`barricade_spikes`) blocking the road
	_draw_centered_sprite(ci, "barricade_spikes", p_a.lerp(p_b, 0.40) + Vector2(0, 2.0), 0.86)
	_draw_centered_sprite(ci, "barricade_spikes", p_a.lerp(p_b, 0.60) + Vector2(0, 2.0), 0.86)


func _draw_broken_cut_road(p_a: Vector2, p_b: Vector2) -> void:
	var ci := _network_layer
	var mid := (p_a + p_b) * 0.5

	# 1. Weathered cobblestone remnants on both ends that break off before the middle
	for rng in [Vector2(0.08, 0.34), Vector2(0.66, 0.92)]:
		var steps := 5
		for i in range(steps + 1):
			var pt := p_a.lerp(p_b, lerpf(rng.x, rng.y, float(i) / float(steps)))
			ci.draw_circle(pt, 3.6, Color("#47423c"))
			ci.draw_circle(pt, 2.4, Color("#8c8479") if i % 2 == 0 else Color("#6e675f"))

	# 2. Cracked ground & encroaching wild weeds in the severed gap
	_draw_centered_sprite(ci, "soil_crack", mid + Vector2(0, 4.0), 0.85)
	ci.draw_circle(mid + Vector2(-5.0, 2.0), 3.2, Color("#4d7c0f"))
	ci.draw_circle(mid + Vector2(5.0, 1.0), 2.8, Color("#65a30d"))

	# 3. Wooden 'X' Road-Closed Barrier (`road_block_sign`) & Broken Link Icon
	_draw_centered_sprite(ci, "road_block_sign", mid + Vector2(0, 3.0), 0.86)
	_draw_centered_sprite(ci, "icon_broken_link", mid + Vector2(0, -7.0), 0.72)


func _draw_migration_expedition(p_a: Vector2, p_b: Vector2) -> void:
	var ci := _network_layer
	var steps := 12
	for i in range(1, steps):
		var pt := _sample_road_curve(p_a, p_b, float(i) / float(steps), -1.0)
		ci.draw_circle(pt, 3.2, Color("#0369a1"))
		ci.draw_circle(pt, 2.1, Color("#bae6fd") if i % 2 == 0 else Color("#e0f2fe"))


# ============================================================================
# VILLAGES: PLAZAS (static), BUILDINGS & FLORA (cached props), VILLAGERS (per frame)
# ============================================================================

func _collect_villages() -> Array[Dictionary]:
	var villages: Array[Dictionary] = []
	for hex_id in world_state.cells:
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		if _is_water(cell):
			continue
		var count := cell.deme_ids.size()
		var scale_factor := 1.0
		if count == 2:
			scale_factor = 0.86
		elif count >= 3:
			scale_factor = 0.76
		var world_xy := HexMath.axial_to_world(cell.q, cell.r)
		var top_z := _get_cell_top_z(cell)

		for idx in range(count):
			var deme_id: String = cell.deme_ids[idx]
			if not world_state.demes.has(deme_id):
				continue
			var deme: EvoTypes.Deme = world_state.demes[deme_id]
			var v_world := world_xy + HexMath.compute_village_sector_offset(idx, count, HexMath.HEX_SIZE)
			var is_dimmed: bool = highlighted_lineage_id != "" and deme.lineage_id != highlighted_lineage_id
			var tier := deme.get_village_tier()

			var bb_offset := Vector2(0, -31.0)
			if count == 2:
				bb_offset = Vector2(-42.0 if idx == 0 else 42.0, -32.0)
			elif count >= 3:
				if idx == 0:
					bb_offset = Vector2(0.0, -40.0)
				elif idx == 1:
					bb_offset = Vector2(56.0, -22.0)
				else:
					bb_offset = Vector2(-56.0, -22.0)

			villages.append({
				"deme": deme,
				"hex_id": hex_id,
				"world_xy": v_world,
				"top_z": top_z,
				"pos": Vector2.ZERO,
				"sf": scale_factor,
				"modulate": Color(1, 1, 1, 0.42) if is_dimmed else Color.WHITE,
				"is_dimmed": is_dimmed,
				"tier": tier,
				"archetype": _get_deme_dominant_archetype(deme),
				"status_col": STATUS_COLORS.get(deme.get_vital_status(), Color("#38bdf8")),
				"villager_count": clampi(2 + tier + int(deme.population / 110), 3, 7),
				"bb_offset": bb_offset * scale_factor,
				"hit_rect": Rect2()
			})
	return villages


func _draw_village_plaza(village: Dictionary) -> void:
	var ci := _network_layer
	var deme: EvoTypes.Deme = village["deme"]
	var sf: float = village["sf"]
	var modulate_col: Color = village["modulate"]
	var status_col: Color = village["status_col"]

	# Town Square Cobblestone Plaza & Vital Status Ring (drawn on ground)
	var plinth_r := 21.0 * sf
	var plaza_center: Vector2 = village["pos"] + Vector2(0, 3.0 * sf)
	var rim_r := plinth_r + 2.5 * sf
	_draw_ellipse_filled(ci, plaza_center, rim_r, rim_r * 0.58, Color("#5c4028") * modulate_col)
	_draw_ellipse_filled(ci, plaza_center, plinth_r, plinth_r * 0.58, Color("#c2a378") * modulate_col)
	_draw_ellipse_filled(ci, plaza_center, plinth_r * 0.74, plinth_r * 0.74 * 0.58, Color("#d9be96") * modulate_col)

	# Individual cobblestone tiles around the village courtyard
	for c_i in range(8):
		var c_ang := TAU * float(c_i) / 8.0
		var c_pt := plaza_center + Vector2(cos(c_ang) * plinth_r * 0.82, sin(c_ang) * plinth_r * 0.46)
		ci.draw_circle(c_pt, 2.2 * sf, Color("#a38358") * modulate_col)

	var ring_r := plinth_r + 2.2 * sf
	_draw_ellipse_outline(ci, plaza_center, ring_r, ring_r * 0.58, status_col * modulate_col, 2.4)

	if deme.id == selected_deme_id:
		var sel_r := plinth_r + 5.5 * sf
		_draw_ellipse_outline(ci, plaza_center, sel_r, sel_r * 0.58, C_SELECTION, 2.8)


func _collect_static_props() -> Array[Prop]:
	var props: Array[Prop] = []
	for hex_id in world_state.cells:
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		if _is_water(cell):
			continue
		var world_xy := HexMath.axial_to_world(cell.q, cell.r)
		var top_z := _get_cell_top_z(cell)
		_collect_cell_flora_props(cell, world_xy, top_z, props)
		# Ruins if recent extinction occurred here
		if world_state.recent_extinction_hexes.has(hex_id):
			props.append(_world_prop("ruins", world_xy + Vector2(0, 6), top_z, Vector2.ZERO, 1.0, Color.WHITE))

	for village in _villages:
		_collect_village_building_props(village, props)

	return props


func _collect_village_building_props(village: Dictionary, props: Array[Prop]) -> void:
	var deme: EvoTypes.Deme = village["deme"]
	var v_world: Vector2 = village["world_xy"]
	var top_z: float = village["top_z"]
	var sf: float = village["sf"]
	var m: Color = village["modulate"]

	# Tiered Village Buildings (Tier 1..4); the tier 1 campfire is animated per frame
	match int(village["tier"]):
		1:
			props.append(_world_prop("tier1_tent", v_world, top_z, Vector2(-8, -4) * sf, 0.94 * sf, m))
		2:
			props.append(_world_prop("tier2_cottage", v_world, top_z, Vector2(-8, -5) * sf, 0.96 * sf, m))
			props.append(_world_prop("tier2_barn", v_world, top_z, Vector2(9, -2) * sf, 0.86 * sf, m))
		3:
			props.append(_world_prop("tier3_townhall", v_world, top_z, Vector2(2, -7) * sf, 0.98 * sf, m))
			props.append(_world_prop("tier3_house", v_world, top_z, Vector2(-11, -2) * sf, 0.86 * sf, m))
		_:
			props.append(_world_prop("tier4_citadel", v_world, top_z, Vector2(0, -9) * sf, 1.0 * sf, m))
			props.append(_world_prop("tier4_tower", v_world, top_z, Vector2(-13, -4) * sf, 0.86 * sf, m))
			props.append(_world_prop("tier4_windmill", v_world, top_z, Vector2(13, -4) * sf, 0.88 * sf, m))

	# Cultural Sanctuary / Totem
	if not deme.cultural_trait_ids.is_empty():
		var totem_scale := (0.78 + mini(3, deme.cultural_trait_ids.size()) * 0.08) * sf
		props.append(_world_prop("cultural_totem", v_world, top_z, Vector2(-14, 5) * sf, totem_scale, m))

	# Dominant Decision Archetype Activity Structure
	props.append(_world_prop("act_" + str(village["archetype"]), v_world, top_z, Vector2(13, 6) * sf, 0.84 * sf, m))


func _collect_cell_flora_props(cell: EvoTypes.HexCell, world_xy: Vector2, top_z: float, props: Array[Prop]) -> void:
	var r_ratio: float = clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)

	# Determine target count: between 6 and 14 pixel-art landscape elements per parcel
	var base_count := 8
	if cell.biome == "tropical_forest":
		base_count = 14
	elif cell.biome == "savanna":
		base_count = 11
	elif cell.biome == "tundra":
		base_count = 10
	elif cell.biome == "coastal_shallows":
		base_count = 7

	var prop_count: int = clampi(int(round(float(base_count) * (0.55 + 0.45 * r_ratio))), 6, 14)

	# Compute village centers in local hex coordinates to keep a cozy clearing around buildings
	var village_local_centers: Array[Vector2] = []
	var v_count := cell.deme_ids.size()
	for v_idx in range(v_count):
		village_local_centers.append(HexMath.compute_village_sector_offset(v_idx, v_count, HexMath.HEX_SIZE))

	var palette_sprites: Array = BIOME_FLORA_PALETTES.get(cell.biome, DEFAULT_FLORA_PALETTE)

	for idx in range(prop_count):
		var s1 := _cell_seed(cell.q, cell.r, idx * 13 + 1)
		var s2 := _cell_seed(cell.q, cell.r, idx * 29 + 7)
		var angle := (TAU * float(idx) / float(prop_count)) + float(s1 % 31 - 15) * 0.035
		var rad_norm := 0.34 + float(s2 % 56) * 0.01
		if v_count > 0:
			rad_norm = clampf(rad_norm + 0.16, 0.48, 0.84)
		var local_off := Vector2(cos(angle), sin(angle)) * (HexMath.HEX_SIZE * rad_norm)

		# Ensure clearing around villages
		var too_close := false
		for vc in village_local_centers:
			if local_off.distance_to(vc) < 17.0:
				local_off = vc + (local_off - vc).normalized() * 19.0
				if local_off.length() > HexMath.HEX_SIZE * 0.86:
					too_close = true
				break
		if too_close:
			continue

		var sprite_key: String = palette_sprites[idx % palette_sprites.size()]
		var can_sway := true

		# Ecological degradation replacement ($K / K_max < 0.85$ or $< 0.60$)
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

		var prop := _world_prop(sprite_key, world_xy + local_off, top_z, Vector2.ZERO, 0.78 + float(s1 % 22) * 0.012, Color.WHITE)
		prop.sways = can_sway and not NON_SWAYING_SPRITES.has(sprite_key)
		prop.sway_phase = float(idx) * 0.9 + float(cell.q)
		props.append(prop)


func _get_deme_dominant_archetype(deme: EvoTypes.Deme) -> String:
	if world_state.decisions_catalog.has(deme.last_dominant_decision_id):
		var dec: EvoTypes.DecisionDef = world_state.decisions_catalog[deme.last_dominant_decision_id]
		return dec.archetype
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


# ============================================================================
# ANIMATED LAYER (per frame): road traffic, lineage beams, Y-sorted props
# ============================================================================

func _draw_animated() -> void:
	for road in _roads:
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		match road["kind"]:
			"collab":
				# Merchant caravan cart traveling between the villages
				var t_cart := fposmod(_anim_time * 0.36 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
				_draw_centered_sprite(_anim_layer, "caravan_cart", _sample_road_curve(p_a, p_b, t_cart, 1.0) + Vector2(0, -4.0), 0.84)
			"bridge":
				var cart_pos := _bridge_arch_point(p_a, p_b, fposmod(_anim_time * 0.36, 1.0)) + Vector2(0, -4.0)
				_draw_centered_sprite(_anim_layer, "caravan_cart", cart_pos, 0.82)
			"dispute":
				_draw_battle_sparks((p_a + p_b) * 0.5)
			"expedition":
				# Settler covered wagon moving toward destination
				var wagon_pos := _sample_road_curve(p_a, p_b, fposmod(_anim_time * 0.42, 1.0), -1.0) + Vector2(0, -4.0)
				_draw_centered_sprite(_anim_layer, "settler_wagon", wagon_pos, 0.85)

	# Highlighted lineage vertical light beam
	for village in _villages:
		var deme: EvoTypes.Deme = village["deme"]
		if highlighted_lineage_id != "" and deme.lineage_id == highlighted_lineage_id:
			var sf: float = village["sf"]
			var v_pos: Vector2 = village["pos"]
			var beam_col := Color(deme.color)
			beam_col.a = 0.28 + 0.10 * sin(_anim_time * 4.0)
			var beam_w := 24.0 * sf
			_anim_layer.draw_rect(Rect2(v_pos.x - beam_w * 0.5, v_pos.y - 115.0 * sf, beam_w, 115.0 * sf), beam_col, true)

	_draw_props()


func _draw_battle_sparks(mid: Vector2) -> void:
	var pulse := 1.0 + 0.22 * sin(_anim_time * 8.5)
	for s_i in range(4):
		var ang := _anim_time * 5.0 + float(s_i) * (TAU * 0.25)
		var spark_pos := mid + Vector2(cos(ang) * 7.0, sin(ang) * 4.0 - 4.0)
		_anim_layer.draw_circle(spark_pos, 2.0, Color("#fde047") if s_i % 2 == 0 else Color("#f97316"))

	var badge_pos := mid + Vector2(0, -13.0)
	_anim_layer.draw_circle(badge_pos, 9.5 * pulse, Color(0.94, 0.20, 0.20, 0.38))
	_draw_centered_sprite(_anim_layer, "icon_conflict_swords", badge_pos + Vector2(0, 5.5), 0.82)


# Merges the pre-sorted static props with the few moving ones sorted each frame.
func _draw_props() -> void:
	var moving := _collect_moving_props()
	moving.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	var m_idx := 0
	for prop in _static_props:
		while m_idx < moving.size() and moving[m_idx].y < prop.y:
			_draw_prop(moving[m_idx])
			m_idx += 1
		_draw_prop(prop)
	for i in range(m_idx, moving.size()):
		_draw_prop(moving[i])


func _draw_prop(prop: Prop) -> void:
	var rect := prop.rect
	if prop.sways:
		rect.position.x += sin(_anim_time * 2.1 + prop.sway_phase) * 1.15
	_anim_layer.draw_texture_rect(prop.texture, rect, false, prop.modulate)


func _collect_moving_props() -> Array[Prop]:
	var props: Array[Prop] = []
	for village in _villages:
		var deme: EvoTypes.Deme = village["deme"]
		var v_pos: Vector2 = village["pos"]
		var sf: float = village["sf"]
		var m: Color = village["modulate"]
		if int(village["tier"]) == 1:
			var fire_sprite := "tier1_campfire" if int(_anim_time * 5.0) % 2 == 0 else "tier1_campfire_2"
			props.append(_sprite_prop(fire_sprite, v_pos + Vector2(6, 3) * sf, 0.92 * sf, m))

		# Animated Pixel-Art Villagers walking around the village courtyard
		var villager_count: int = village["villager_count"]
		var tunic_col := Color(deme.color)
		for v_idx in range(villager_count):
			var orbit_angle := _anim_time * (1.05 + float(v_idx % 3) * 0.24) + float(v_idx) * (TAU / float(villager_count))
			var orbit_r := (12.0 + float(v_idx % 2) * 5.0) * sf
			var foot := v_pos + Vector2(cos(orbit_angle) * orbit_r, sin(orbit_angle) * (orbit_r * 0.56) + 5.0 * sf)
			var frame := int((_anim_time * 6.0) + float(v_idx)) % 3
			props.append(_villager_prop(frame, tunic_col, foot, 0.92 * sf, m))

	# Road travelers walking along active collaboration roads
	for r_idx in range(_roads.size()):
		var road: Dictionary = _roads[r_idx]
		if not TRAVELER_ROAD_KINDS.has(road["kind"]):
			continue
		for traveler_i in range(2):
			var t_walk := fposmod(_anim_time * 0.28 + float(r_idx) * 0.31 + float(traveler_i) * 0.48, 1.0)
			if traveler_i == 1:
				t_walk = 1.0 - t_walk
			var foot := _sample_road_curve(road["p_a"], road["p_b"], t_walk, 1.0)
			var frame := int((_anim_time * 6.5) + float(traveler_i + r_idx)) % 3
			props.append(_villager_prop(frame, road["color"], foot, 0.90, Color.WHITE))
	return props


func _world_prop(sprite_name: String, world_xy: Vector2, top_z: float, screen_offset: Vector2, scale_val: float, modulate_col: Color) -> Prop:
	var prop := Prop.new(PixelArtGen.get_texture(sprite_name), scale_val, 0.78, modulate_col)
	prop.world_xy = world_xy
	prop.top_z = top_z
	prop.screen_offset = screen_offset
	return prop


func _sprite_prop(sprite_name: String, foot: Vector2, scale_val: float, modulate_col: Color) -> Prop:
	var prop := Prop.new(PixelArtGen.get_texture(sprite_name), scale_val, 0.78, modulate_col)
	prop.set_foot(foot)
	return prop


func _villager_prop(frame: int, tunic_col: Color, foot: Vector2, scale_val: float, modulate_col: Color) -> Prop:
	var prop := Prop.new(PixelArtGen.get_villager_texture(VILLAGER_POSES[frame], tunic_col), scale_val, 0.85, modulate_col)
	prop.set_foot(foot)
	return prop


# ============================================================================
# SCREEN-SPACE OVERLAY (per frame): signboards, thought bubbles & particles
# ============================================================================

func _draw_overlay() -> void:
	var to_screen := _world_layer.transform
	_deme_hit_rects.clear()
	for village in _villages:
		_deme_hit_rects.append({"rect": to_screen * (village["hit_rect"] as Rect2), "deme_id": (village["deme"] as EvoTypes.Deme).id, "hex_id": village["hex_id"]})
	for village in _villages:
		_draw_village_billboard(village, to_screen * (village["pos"] + village["bb_offset"]))
	_draw_seasonal_particles()


func _draw_village_billboard(village: Dictionary, pos: Vector2) -> void:
	var ci := _overlay_layer
	var deme: EvoTypes.Deme = village["deme"]
	var is_dimmed: bool = village["is_dimmed"]

	var font := ThemeDB.fallback_font
	var font_size := 11
	var label_text := "%s · %d" % [deme.get_village_roman(), deme.population]
	if not deme.cultural_trait_ids.is_empty():
		label_text += " ★%d" % deme.cultural_trait_ids.size()

	var is_tev := deme.decision_model_tag.to_lower().begins_with("tev")
	var model_short := "tev1" if is_tev else "d3"
	var model_w := font.get_string_size(model_short, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 8.0

	var text_w := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pill_w := text_w + model_w + 26.0
	var pill_h := 22.0
	var rect := Rect2(pos.x - pill_w * 0.5, pos.y - pill_h, pill_w, pill_h)

	var alpha := 0.48 if is_dimmed else 0.96
	var outer_wood := Color("#4a2810")
	outer_wood.a = alpha
	var inner_parchment := Color("#f5e4c3")
	inner_parchment.a = alpha
	var is_selected := deme.id == selected_deme_id
	var border_col := C_SELECTION if is_selected else Color("#8c5230")
	border_col.a = alpha

	# 1. Carved Stardew Wooden Signboard with drop shadow & brass corner nails
	ci.draw_rect(Rect2(rect.position + Vector2(1, 3), rect.size), Color(0, 0, 0, 0.38 * alpha), true)
	ci.draw_rect(rect.grow(1.5), outer_wood, true)
	ci.draw_rect(rect, inner_parchment, true)
	ci.draw_rect(rect, border_col, false, 2.2 if is_selected else 1.5)

	for corner in [
		rect.position + Vector2(2.5, 2.5),
		Vector2(rect.end.x - 2.5, rect.position.y + 2.5),
		Vector2(rect.position.x + 2.5, rect.end.y - 2.5),
		rect.end - Vector2(2.5, 2.5)
	]:
		ci.draw_circle(corner, 1.3, Color(0.85, 0.65, 0.20, alpha))

	# 2. Heraldic Lineage Shield Icon
	var shield_c := Vector2(rect.position.x + 10.0, rect.position.y + pill_h * 0.5)
	ci.draw_circle(shield_c, 5.6, Color(0.14, 0.08, 0.04, alpha))
	var lin_col := Color(deme.color)
	lin_col.a = alpha
	ci.draw_circle(shield_c, 4.4, lin_col)
	ci.draw_circle(shield_c + Vector2(-1.2, -1.2), 1.4, lin_col.lightened(0.32))

	# 3. Crisp Village Tier & Population Text
	var text_pos := Vector2(rect.position.x + 18.0, rect.position.y + 15.0)
	ci.draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.20, 0.11, 0.05, alpha))

	# 4. Decision Model Tag Badge (`d3` sky-blue or `tev1` golden-amber)
	var badge_rect := Rect2(rect.end.x - model_w - 4.0, rect.position.y + 4.0, model_w, 14.0)
	var badge_bg := Color("#d97706") if is_tev else Color("#0284c7")
	var badge_fg := Color("#fef9c3") if is_tev else Color("#e0f2fe")
	badge_bg.a = alpha
	badge_fg.a = alpha
	ci.draw_rect(badge_rect, badge_bg, true)
	ci.draw_rect(badge_rect, Color(0.15, 0.08, 0.04, alpha), false, 1.0)
	ci.draw_string(font, Vector2(badge_rect.position.x + 4.0, badge_rect.position.y + 10.5), model_short, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, badge_fg)

	# 5. Pixel-Art Comic Thought Bubble (`thought_bubble`) with Dominant Activity Icon
	var village_pos: Vector2 = village["pos"]
	var bob := sin(_anim_time * 3.2 + village_pos.x * 0.05) * 1.8
	var bubble_rect := Rect2(rect.end.x + 3.0, rect.position.y - 5.0 + bob, 26.0, 26.0)
	ci.draw_texture_rect(PixelArtGen.get_texture("thought_bubble"), bubble_rect, false, Color(1, 1, 1, alpha))

	var icon_rect := Rect2(bubble_rect.position.x + 6.0, bubble_rect.position.y + 3.0, 14.0, 14.0)
	ci.draw_texture_rect(PixelArtGen.get_texture("icon_" + str(village["archetype"])), icon_rect, false, Color(1, 1, 1, alpha))

	_deme_hit_rects.append({"rect": rect.merge(bubble_rect), "deme_id": deme.id, "hex_id": village["hex_id"]})


func _init_particles() -> void:
	_particles.clear()
	for i in range(42):
		_particles.append({
			"x": float((i * 97) % 1280),
			"y": float((i * 53) % 720),
			"speed": 14.0 + float((i * 19) % 22),
			"phase": float(i) * 0.65,
			"size": 2.0 + float(i % 2)
		})


func _update_particles(delta: float) -> void:
	var vp_size := get_viewport_rect().size
	var is_wet := world_state.season == "wet_warm"
	for p in _particles:
		var spd: float = p["speed"]
		var ph: float = p["phase"] + delta * 1.4
		p["phase"] = ph
		if is_wet:
			p["y"] = fposmod(float(p["y"]) - spd * 0.45 * delta, vp_size.y)
			p["x"] = fposmod(float(p["x"]) + sin(ph) * 14.0 * delta, vp_size.x)
		else:
			p["y"] = fposmod(float(p["y"]) + spd * 1.15 * delta, vp_size.y)
			p["x"] = fposmod(float(p["x"]) + cos(ph) * 18.0 * delta, vp_size.x)


func _draw_seasonal_particles() -> void:
	var is_wet := world_state.season == "wet_warm"
	for p in _particles:
		var sz: float = p["size"]
		var glow := 0.45 + 0.35 * sin(float(p["phase"]) * 2.0)
		var col := Color(1.0, 0.88, 0.38, glow) if is_wet else Color(0.90, 0.96, 1.0, glow)
		_overlay_layer.draw_rect(Rect2(Vector2(float(p["x"]), float(p["y"])), Vector2(sz, sz)), col, true)


# ============================================================================
# DRAWING & HIT-TESTING HELPERS
# ============================================================================

func _draw_centered_sprite(ci: CanvasItem, sprite_name: String, center_pos: Vector2, scale_val: float) -> void:
	var tex: ImageTexture = PixelArtGen.get_texture(sprite_name)
	var sz: Vector2 = tex.get_size() * scale_val
	ci.draw_texture_rect(tex, Rect2(Vector2(center_pos.x - sz.x * 0.5, center_pos.y - sz.y * 0.78), sz), false)


func _draw_ellipse_filled(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


func _draw_ellipse_outline(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(19):
		var a := TAU * float(i) / 18.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, col, width)


func _pick_deme_at(screen_pos: Vector2) -> Dictionary:
	for i in range(_deme_hit_rects.size() - 1, -1, -1):
		var entry: Dictionary = _deme_hit_rects[i]
		if (entry["rect"] as Rect2).has_point(screen_pos):
			return entry
	return {}


func _pick_hex_at(screen_pos: Vector2) -> String:
	var local_pos := _world_layer.transform.affine_inverse() * screen_pos
	for i in range(_sorted_hex_ids.size() - 1, -1, -1):
		var hex_id := _sorted_hex_ids[i]
		if Geometry2D.is_point_in_polygon(local_pos, _hex_polys[hex_id]):
			return hex_id
	return ""
