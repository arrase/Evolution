class_name EvoWorldRenderer
extends Node2D

const PixelArtGen = preload("res://src/world/pixel_art_gen.gd")
const CameraController = preload("res://src/world/camera_controller.gd")

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
var hovered_deme_id: String = ""
var brush_radius: int = 1

# Layer stack. Pan & zoom only change _world_layer's transform, so the cached
# command lists of the static layers are reused untouched while the camera moves.
var _world_layer := Node2D.new() # pan/zoom transform
var _terrain_layer := Node2D.new() # one cached canvas item per hex column, depth-sorted
var _network_layer := Node2D.new() # static roads, bridges & village plazas
var _anim_layer := Node2D.new() # per-frame: road traffic, beams, Y-sorted props & villagers
var _overlay_layer := Node2D.new() # per-frame, screen-space: signboards & particles

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
var _column_state_cache: Dictionary = {} # hex_id -> Array (visual signature)
var _last_sort_signature: Array = []
var _cell_flora_cache: Dictionary = {} # hex_id -> {key: Array, props: Array[Prop]}

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


# Schedules a rebuild of the cached static layers (world state, selection, lens or tool changed).
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
	_villages = _collect_villages()
	_roads = _collect_roads()
	_static_props = _collect_static_props()
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
	_reproject_roads()
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


# Hovering only touches a handful of columns: redraw those instead of the whole map.
func _update_brush() -> void:
	var previous := _brush_hexes
	_brush_hexes = _compute_brush_hexes()
	for hex_id in previous + _brush_hexes:
		_column_state_cache.erase(hex_id)
		_columns[hex_id].queue_redraw()


# Ocean swell moves whole water columns (they have no cliffs) via their transform.
func _bob_ocean_columns() -> void:
	var sea_z := _sea_z()
	for hex_id in _ocean_ids:
		if not _visible_world_rect.has_point(_hex_centers[hex_id]):
			continue
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
	var rows := int(vp_size.y / 96.0) + 1
	var cols := int(vp_size.x / 180.0) + 1
	for ry in range(rows):
		for cx in range(cols):
			var phase := _anim_time * 1.9 + float(ry) * 0.75 + float(cx) * 0.55
			var wx := float(cx * 180) + sin(phase) * 9.0 + float((ry % 2) * 82)
			var wy := float(ry * 96) + cos(phase * 0.8) * 3.0
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
		if active_lens == "health":
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
# INTER-VILLAGE NETWORK (ROADS, BRIDGES, BARRICADES, BROKEN ROADS, EXPEDITIONS)
# ============================================================================

func _collect_roads() -> Array[Dictionary]:
	var roads: Array[Dictionary] = []
	var handled_deme_pairs: Dictionary = {}
	var handled_hex_pairs: Dictionary = {}
	var intra_hex_badge_drawn: Dictionary = {}
	var badge_positions: Array[Vector2] = []
	var hex_traffic_counts: Dictionary = {}

	# 1. Explicit active flows from simulation engine
	for flow in world_state.active_flows:
		if not world_state.cells.has(flow.from_hex_id) or not world_state.cells.has(flow.to_hex_id):
			continue
		var cell_a: EvoTypes.HexCell = world_state.cells[flow.from_hex_id]
		var cell_b: EvoTypes.HexCell = world_state.cells[flow.to_hex_id]
		var is_same_hex := cell_a.id == cell_b.id
		var h_key := _make_pair_key(flow.from_hex_id, flow.to_hex_id)
		if not is_same_hex and handled_hex_pairs.has(h_key):
			continue

		var endpoints := _resolve_road_endpoints(cell_a, cell_b, flow.from_deme_id, flow.to_deme_id)
		var trim_a := _get_cell_plaza_trim(cell_a)
		var trim_b := _get_cell_plaza_trim(cell_b)
		var trimmed := _trim_road_segment(
			endpoints["p_a"] as Vector2,
			endpoints["p_b"] as Vector2,
			trim_a,
			trim_b
		)
		var p_a: Vector2 = trimmed["p_a"]
		var p_b: Vector2 = trimmed["p_b"]
		var curve_f := 0.035 if is_same_hex else 0.045
		var is_prio := (cell_a.id == selected_hex_id or cell_b.id == selected_hex_id or cell_a.id == hovered_hex_id or cell_b.id == hovered_hex_id)

		if not is_same_hex:
			handled_hex_pairs[h_key] = true
		if flow.from_deme_id != "" and flow.to_deme_id != "":
			handled_deme_pairs[_make_pair_key(flow.from_deme_id, flow.to_deme_id)] = true

		match flow.flow_type:
			"dispute":
				var b_pos := _cell_top_center(cell_a) if is_same_hex else (p_a + p_b) * 0.5
				var show_badge := true
				if is_same_hex:
					show_badge = not intra_hex_badge_drawn.has(cell_a.id)
					intra_hex_badge_drawn[cell_a.id] = true
				if show_badge:
					show_badge = _register_road_badge(b_pos, badge_positions, is_prio)
				roads.append({
					"kind": "dispute",
					"hex_a": cell_a.id,
					"hex_b": cell_b.id,
					"world_a": endpoints["world_a"],
					"z_a": endpoints["z_a"],
					"trim_a": trim_a,
					"world_b": endpoints["world_b"],
					"z_b": endpoints["z_b"],
					"trim_b": trim_b,
					"badge_world": HexMath.axial_to_world(cell_a.q, cell_a.r),
					"badge_z": _get_cell_top_z(cell_a),
					"p_a": p_a,
					"p_b": p_b,
					"is_same_hex": is_same_hex,
					"show_badge": show_badge,
					"badge_pos": b_pos
				})
			"exchange", "cooperate", "merge":
				var kind := "bridge" if (not is_same_hex and _should_use_bridge(cell_a, cell_b)) else "collab"
				var b_pos := _bridge_arch_point(p_a, p_b, 0.5) if kind == "bridge" else _sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f)
				var show_badge := _register_road_badge(b_pos, badge_positions, is_prio)
				var show_traffic := _claim_road_traffic(cell_a.id, cell_b.id, hex_traffic_counts, is_prio)
				roads.append({
					"kind": kind,
					"hex_a": cell_a.id,
					"hex_b": cell_b.id,
					"world_a": endpoints["world_a"],
					"z_a": endpoints["z_a"],
					"trim_a": trim_a,
					"world_b": endpoints["world_b"],
					"z_b": endpoints["z_b"],
					"trim_b": trim_b,
					"p_a": p_a,
					"p_b": p_b,
					"is_same_hex": is_same_hex,
					"curve_factor": curve_f,
					"show_badge": show_badge,
					"show_traffic": show_traffic,
					"color": Color("#eab308")
				})
			"migration":
				roads.append({
					"kind": "expedition",
					"hex_a": cell_a.id,
					"hex_b": cell_b.id,
					"world_a": endpoints["world_a"],
					"z_a": endpoints["z_a"],
					"trim_a": trim_a,
					"world_b": endpoints["world_b"],
					"z_b": endpoints["z_b"],
					"trim_b": trim_b,
					"p_a": p_a,
					"p_b": p_b,
					"curve_factor": curve_f
				})

	# 2. All cohabiting (dist == 0) and neighboring (dist == 1) village pairs
	var all_demes: Array[EvoTypes.Deme] = []
	for d_id in world_state.demes.keys():
		var d: EvoTypes.Deme = world_state.demes[d_id]
		if d.population > 0 and world_state.cells.has(d.hex_id):
			all_demes.append(d)

	var connected_deme_ids: Dictionary = {}
	for d in all_demes:
		var ca: EvoTypes.HexCell = world_state.cells[d.hex_id]
		if ca.deme_ids.size() > 1:
			connected_deme_ids[d.id] = true
			continue
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, world_state.cells):
			if not (world_state.cells[n_id] as EvoTypes.HexCell).deme_ids.is_empty():
				connected_deme_ids[d.id] = true
				break

	# 2a. Intra-hex cohabiting pairs (dist == 0)
	for hex_id in world_state.cells:
		var ca: EvoTypes.HexCell = world_state.cells[hex_id]
		if ca.deme_ids.size() < 2:
			continue
		var z_ca := _get_cell_top_z(ca)
		var world_ca := HexMath.axial_to_world(ca.q, ca.r)
		for i in range(ca.deme_ids.size()):
			var id_a: String = ca.deme_ids[i]
			if not world_state.demes.has(id_a):
				continue
			var da: EvoTypes.Deme = world_state.demes[id_a]
			for j in range(i + 1, ca.deme_ids.size()):
				var id_b: String = ca.deme_ids[j]
				if not world_state.demes.has(id_b):
					continue
				var db: EvoTypes.Deme = world_state.demes[id_b]
				var d_key := _make_pair_key(da.id, db.id)
				if handled_deme_pairs.has(d_key):
					continue
				handled_deme_pairs[d_key] = true

				var trim_r := _get_cell_plaza_trim(ca)
				var world_a := _get_deme_world_pos(ca, da.id)
				var world_b := _get_deme_world_pos(ca, db.id)
				var trimmed := _trim_road_segment(_project(world_a, z_ca), _project(world_b, z_ca), trim_r, trim_r)
				var p_a: Vector2 = trimmed["p_a"]
				var p_b: Vector2 = trimmed["p_b"]
				var is_prio := (ca.id == selected_hex_id or ca.id == hovered_hex_id)

				match _classify_village_pair_relation(da, db):
					"dispute_front":
						var b_pos := _cell_top_center(ca)
						var show_badge := not intra_hex_badge_drawn.has(ca.id)
						intra_hex_badge_drawn[ca.id] = true
						if show_badge:
							show_badge = _register_road_badge(b_pos, badge_positions, is_prio)
						roads.append({
							"kind": "dispute",
							"world_a": world_a,
							"z_a": z_ca,
							"trim_a": trim_r,
							"world_b": world_b,
							"z_b": z_ca,
							"trim_b": trim_r,
							"badge_world": world_ca,
							"badge_z": z_ca,
							"p_a": p_a,
							"p_b": p_b,
							"is_same_hex": true,
							"show_badge": show_badge,
							"badge_pos": b_pos
						})
					"active_road":
						var b_pos := _sample_road_curve(p_a, p_b, 0.5, 1.0, 0.035)
						var show_badge := _register_road_badge(b_pos, badge_positions, is_prio)
						var show_traffic := _claim_road_traffic(ca.id, ca.id, hex_traffic_counts, is_prio)
						roads.append({
							"kind": "collab",
							"hex_a": ca.id,
							"hex_b": ca.id,
							"world_a": world_a,
							"z_a": z_ca,
							"trim_a": trim_r,
							"world_b": world_b,
							"z_b": z_ca,
							"trim_b": trim_r,
							"p_a": p_a,
							"p_b": p_b,
							"is_same_hex": true,
							"curve_factor": 0.035,
							"show_badge": show_badge,
							"show_traffic": show_traffic,
							"color": Color(da.color)
						})
					_:
						var dis_age := _get_disused_road_age(da.id, db.id, ca.id, ca.id)
						if dis_age > 0 or (world_state.generation == 0 and world_state.active_flows.is_empty()):
							var b_pos := (p_a + p_b) * 0.5
							var show_badge := _register_road_badge(b_pos, badge_positions, is_prio)
							roads.append({
								"kind": "broken",
								"world_a": world_a,
								"z_a": z_ca,
								"trim_a": trim_r,
								"world_b": world_b,
								"z_b": z_ca,
								"trim_b": trim_r,
								"p_a": p_a,
								"p_b": p_b,
								"show_badge": show_badge,
								"alpha": 0.52 if dis_age == 2 else 0.90
							})

	# 2b. Inter-hex neighboring pairs (dist == 1): at most 1 road per hex border, connecting the closest facing sectors
	for hex_id in world_state.cells:
		var ca: EvoTypes.HexCell = world_state.cells[hex_id]
		if ca.deme_ids.is_empty():
			continue
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, world_state.cells):
			var cb: EvoTypes.HexCell = world_state.cells[n_id]
			if cb.deme_ids.is_empty():
				continue
			var h_key := _make_pair_key(ca.id, cb.id)
			if handled_hex_pairs.has(h_key):
				continue
			handled_hex_pairs[h_key] = true

			var pair := _find_closest_deme_pair(ca, cb)
			if pair.is_empty():
				continue
			var da: EvoTypes.Deme = pair["da"]
			var db: EvoTypes.Deme = pair["db"]
			handled_deme_pairs[_make_pair_key(da.id, db.id)] = true
			var world_a := _get_deme_world_pos(ca, da.id)
			var z_a := _get_cell_top_z(ca)
			var trim_a := _get_cell_plaza_trim(ca)
			var world_b := _get_deme_world_pos(cb, db.id)
			var z_b := _get_cell_top_z(cb)
			var trim_b := _get_cell_plaza_trim(cb)
			var trimmed := _trim_road_segment(
				_project(world_a, z_a),
				_project(world_b, z_b),
				trim_a,
				trim_b
			)
			var p_a: Vector2 = trimmed["p_a"]
			var p_b: Vector2 = trimmed["p_b"]
			var is_prio := (ca.id == selected_hex_id or cb.id == selected_hex_id or ca.id == hovered_hex_id or cb.id == hovered_hex_id)

			match _classify_village_pair_relation(da, db):
				"dispute_front":
					var b_pos := (p_a + p_b) * 0.5
					var show_badge := _register_road_badge(b_pos, badge_positions, is_prio)
					roads.append({
						"kind": "dispute",
						"world_a": world_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": world_b,
						"z_b": z_b,
						"trim_b": trim_b,
						"p_a": p_a,
						"p_b": p_b,
						"is_same_hex": false,
						"show_badge": show_badge,
						"badge_pos": b_pos
					})
				"active_road":
					var kind := "bridge" if _should_use_bridge(ca, cb) else "collab"
					var b_pos := _bridge_arch_point(p_a, p_b, 0.5) if kind == "bridge" else _sample_road_curve(p_a, p_b, 0.5, 1.0, 0.045)
					var show_badge := _register_road_badge(b_pos, badge_positions, is_prio)
					var show_traffic := _claim_road_traffic(ca.id, cb.id, hex_traffic_counts, is_prio)
					roads.append({
						"kind": kind,
						"hex_a": ca.id,
						"hex_b": cb.id,
						"world_a": world_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": world_b,
						"z_b": z_b,
						"trim_b": trim_b,
						"p_a": p_a,
						"p_b": p_b,
						"is_same_hex": false,
						"curve_factor": 0.045,
						"show_badge": show_badge,
						"show_traffic": show_traffic,
						"color": Color(da.color)
					})
				_:
					var dis_age := _get_disused_road_age(da.id, db.id, ca.id, cb.id)
					if dis_age > 0:
						var b_pos := (p_a + p_b) * 0.5
						var show_badge := _register_road_badge(b_pos, badge_positions, is_prio)
						roads.append({
							"kind": "broken",
							"world_a": world_a,
							"z_a": z_a,
							"trim_a": trim_a,
							"world_b": world_b,
							"z_b": z_b,
							"trim_b": trim_b,
							"p_a": p_a,
							"p_b": p_b,
							"show_badge": show_badge,
							"alpha": 0.52 if dis_age == 2 else 0.90
						})

	# 3. Initial split-lineage ancestral pass (only during early generations before expansion across the Rift)
	if world_state.generation <= 2 and all_demes.size() == 2 and world_state.cells.has("0,0") and (world_state.cells["0,0"] as EvoTypes.HexCell).deme_ids.is_empty():
		var da: EvoTypes.Deme = all_demes[0]
		var db: EvoTypes.Deme = all_demes[1]
		if not connected_deme_ids.has(da.id) and not connected_deme_ids.has(db.id):
			var d_key := _make_pair_key(da.id, db.id)
			if not handled_deme_pairs.has(d_key):
				handled_deme_pairs[d_key] = true
				var ca: EvoTypes.HexCell = world_state.cells[da.hex_id]
				var cb: EvoTypes.HexCell = world_state.cells[db.hex_id]
				var c_mid: EvoTypes.HexCell = world_state.cells["0,0"]
				var w_a := _get_deme_world_pos(ca, da.id)
				var z_a := _get_cell_top_z(ca)
				var trim_a := _get_cell_plaza_trim(ca)
				var w_mid := HexMath.axial_to_world(c_mid.q, c_mid.r)
				var z_mid := _get_cell_top_z(c_mid)
				var w_b := _get_deme_world_pos(cb, db.id)
				var z_b := _get_cell_top_z(cb)
				var trim_b := _get_cell_plaza_trim(cb)
				var p_mid := _project(w_mid, z_mid)
				var seg1 := _trim_road_segment(_project(w_a, z_a), p_mid, trim_a, 18.0)
				var seg2 := _trim_road_segment(p_mid, _project(w_b, z_b), 18.0, trim_b)
				var alpha_val := 0.90 if world_state.generation <= 1 else 0.55
				roads.append({
					"kind": "broken",
					"world_a": w_a,
					"z_a": z_a,
					"trim_a": trim_a,
					"world_b": w_mid,
					"z_b": z_mid,
					"trim_b": 18.0,
					"p_a": seg1["p_a"],
					"p_b": seg1["p_b"],
					"show_badge": true,
					"alpha": alpha_val
				})
				roads.append({
					"kind": "broken",
					"world_a": w_mid,
					"z_a": z_mid,
					"trim_a": 18.0,
					"world_b": w_b,
					"z_b": z_b,
					"trim_b": trim_b,
					"p_a": seg2["p_a"],
					"p_b": seg2["p_b"],
					"show_badge": true,
					"alpha": alpha_val
				})

	# 4. Pioneer / Coastal Shallows Exploration Causeways for single isolated villages with shallow land bridges
	for da in all_demes:
		if connected_deme_ids.has(da.id):
			continue
		var ca: EvoTypes.HexCell = world_state.cells[da.hex_id]
		var w_a := _get_deme_world_pos(ca, da.id)
		var z_a := _get_cell_top_z(ca)
		var p_a_raw := _project(w_a, z_a)
		var trim_a := _get_cell_plaza_trim(ca)
		for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, world_state.cells):
			var ncell: EvoTypes.HexCell = world_state.cells[n_id]
			if ncell.biome == "coastal_shallows" and ncell.altitude >= world_state.sea_level:
				var h_key := _make_pair_key(ca.id, ncell.id)
				if not handled_hex_pairs.has(h_key):
					handled_hex_pairs[h_key] = true
					var w_b := HexMath.axial_to_world(ncell.q, ncell.r)
					var z_b := _get_cell_top_z(ncell)
					var seg := _trim_road_segment(p_a_raw, _project(w_b, z_b), trim_a, 18.0)
					roads.append({
						"kind": "expedition",
						"world_a": w_a,
						"z_a": z_a,
						"trim_a": trim_a,
						"world_b": w_b,
						"z_b": z_b,
						"trim_b": 18.0,
						"p_a": seg["p_a"],
						"p_b": seg["p_b"],
						"curve_factor": 0.14
					})

	# 5. Recent disused connections from previous turns (visual remnant up to age <= 2 on adjacent/same hexes)
	for disused in world_state.disused_connections:
		var age_val := int(disused.get("age", 1))
		if age_val > 2:
			continue
		var from_id := str(disused.get("from_hex_id", ""))
		var to_id := str(disused.get("to_hex_id", ""))
		if not world_state.cells.has(from_id) or not world_state.cells.has(to_id):
			continue
		var ca: EvoTypes.HexCell = world_state.cells[from_id]
		var cb: EvoTypes.HexCell = world_state.cells[to_id]
		if HexMath.hex_distance(ca.q, ca.r, cb.q, cb.r) > 1:
			continue
		var is_same_hex := from_id == to_id
		var h_key := _make_pair_key(from_id, to_id)
		var fa := str(disused.get("from_deme_id", ""))
		var fb := str(disused.get("to_deme_id", ""))
		var d_key := _make_pair_key(fa, fb) if (fa != "" and fb != "") else ""
		if not is_same_hex and handled_hex_pairs.has(h_key):
			continue
		if d_key != "" and handled_deme_pairs.has(d_key):
			continue
		if not is_same_hex:
			handled_hex_pairs[h_key] = true
		if d_key != "":
			handled_deme_pairs[d_key] = true

		var endpoints := _resolve_road_endpoints(ca, cb, fa, fb)
		var trim_a := _get_cell_plaza_trim(ca)
		var trim_b := _get_cell_plaza_trim(cb)
		var seg := _trim_road_segment(
			endpoints["p_a"] as Vector2,
			endpoints["p_b"] as Vector2,
			trim_a,
			trim_b
		)
		var p_a: Vector2 = seg["p_a"]
		var p_b: Vector2 = seg["p_b"]
		var is_prio := (from_id == selected_hex_id or to_id == selected_hex_id or from_id == hovered_hex_id or to_id == hovered_hex_id)
		var show_badge := _register_road_badge((p_a + p_b) * 0.5, badge_positions, is_prio)
		roads.append({
			"kind": "broken",
			"world_a": endpoints["world_a"],
			"z_a": endpoints["z_a"],
			"trim_a": trim_a,
			"world_b": endpoints["world_b"],
			"z_b": endpoints["z_b"],
			"trim_b": trim_b,
			"p_a": p_a,
			"p_b": p_b,
			"show_badge": show_badge,
			"alpha": 0.52 if age_val == 2 else 0.90
		})

	return _prune_redundant_triangle_chords(roads)


func _prune_redundant_triangle_chords(roads: Array[Dictionary]) -> Array[Dictionary]:
	var coop_pairs: Dictionary = {}
	for r in roads:
		var k := str(r.get("kind", ""))
		if k in ["collab", "bridge"] and not bool(r.get("is_same_hex", false)):
			var ha := str(r.get("hex_a", ""))
			var hb := str(r.get("hex_b", ""))
			if ha != "" and hb != "":
				coop_pairs[_make_pair_key(ha, hb)] = true

	var result: Array[Dictionary] = []
	for r in roads:
		var k := str(r.get("kind", ""))
		if k in ["collab", "bridge"] and not bool(r.get("is_same_hex", false)):
			var ha := str(r.get("hex_a", ""))
			var hb := str(r.get("hex_b", ""))
			if world_state.cells.has(ha) and world_state.cells.has(hb):
				var ca: EvoTypes.HexCell = world_state.cells[ha]
				var cb: EvoTypes.HexCell = world_state.cells[hb]
				if ca.r == cb.r and abs(ca.q - cb.q) == 1:
					var has_triangle_bypass := false
					for n_id in HexMath.get_neighbor_ids(ca.q, ca.r, world_state.cells):
						if n_id == hb:
							continue
						var nc: EvoTypes.HexCell = world_state.cells[n_id]
						if HexMath.hex_distance(cb.q, cb.r, nc.q, nc.r) == 1:
							if coop_pairs.has(_make_pair_key(ha, n_id)) and coop_pairs.has(_make_pair_key(hb, n_id)):
								has_triangle_bypass = true
								break
					if has_triangle_bypass:
						continue
		if r.has("color"):
			r["villager_textures"] = _get_villager_textures_for_color(r["color"])
		_project_road_entry(r)
		result.append(r)
	return result


func _project_road_entry(road: Dictionary) -> void:
	var raw_a := _project(road["world_a"] as Vector2, float(road["z_a"]))
	var raw_b := _project(road["world_b"] as Vector2, float(road["z_b"]))
	var trimmed := _trim_road_segment(raw_a, raw_b, float(road["trim_a"]), float(road["trim_b"]))
	var p_a: Vector2 = trimmed["p_a"]
	var p_b: Vector2 = trimmed["p_b"]
	road["p_a"] = p_a
	road["p_b"] = p_b
	road["a_pos"] = p_a
	road["b_pos"] = p_b
	var curve_f := float(road.get("curve_factor", 0.045))
	var curve_sign := -1.0 if road.get("kind", "") == "expedition" else 1.0
	var diff := p_b - p_a
	var dist := diff.length()
	var perp := Vector2(-diff.y, diff.x).normalized() if dist > 0.01 else Vector2.UP
	road["ctrl"] = (p_a + p_b) * 0.5 + perp * (minf(dist * curve_f, 12.0) * curve_sign)
	if road.get("kind", "") == "dispute":
		if bool(road.get("is_same_hex", false)) and road.has("badge_world"):
			road["badge_pos"] = _project(road["badge_world"] as Vector2, float(road["badge_z"]))
		else:
			road["badge_pos"] = (p_a + p_b) * 0.5


func _reproject_roads() -> void:
	for road in _roads:
		_project_road_entry(road)


func _draw_network() -> void:
	for road in _roads:
		match road["kind"]:
			"collab":
				_draw_collaboration_route(road)
			"bridge":
				_draw_wooden_bridge(road)
			"dispute":
				_draw_dispute_barricade_front(road)
			"broken":
				_draw_broken_cut_road(road)
			"expedition":
				_draw_migration_expedition(road)
	for village in _villages:
		_draw_village_plaza(village)


func _make_pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


func _get_cell_plaza_trim(cell: EvoTypes.HexCell) -> float:
	var count := cell.deme_ids.size()
	if count <= 0:
		return 16.0
	var sf := 1.0 if count == 1 else (0.86 if count == 2 else 0.78)
	return 44.0 * sf


func _trim_road_segment(p_a: Vector2, p_b: Vector2, trim_a: float, trim_b: float) -> Dictionary:
	var diff := p_b - p_a
	var dist := diff.length()
	if dist < 1.0:
		return {"p_a": p_a, "p_b": p_b}
	var dir := diff / dist
	var ta := minf(trim_a, dist * 0.30)
	var tb := minf(trim_b, dist * 0.30)
	return {"p_a": p_a + dir * ta, "p_b": p_b - dir * tb}


func _register_road_badge(badge_pos: Vector2, badge_positions: Array[Vector2], is_priority: bool) -> bool:
	var min_v_dist := 42.0 if is_priority else 54.0
	for v in _villages:
		if badge_pos.distance_to(v["pos"] as Vector2) < min_v_dist:
			return false
	var min_b_dist := 34.0 if is_priority else 48.0
	for bp in badge_positions:
		if badge_pos.distance_to(bp) < min_b_dist:
			return false
	badge_positions.append(badge_pos)
	return true


func _claim_road_traffic(hex_a: String, hex_b: String, hex_traffic_counts: Dictionary, is_priority: bool) -> bool:
	var count_a := int(hex_traffic_counts.get(hex_a, 0))
	var count_b := int(hex_traffic_counts.get(hex_b, 0))
	if not is_priority and (count_a >= 3 or count_b >= 3):
		return false
	hex_traffic_counts[hex_a] = count_a + 1
	if hex_b != hex_a:
		hex_traffic_counts[hex_b] = count_b + 1
	return true


func _get_disused_road_age(da_id: String, db_id: String, hex_a: String, hex_b: String) -> int:
	for dis in world_state.disused_connections:
		var age_val := int(dis.get("age", 1))
		if age_val > 2:
			continue
		var fa := str(dis.get("from_deme_id", ""))
		var fb := str(dis.get("to_deme_id", ""))
		if (fa == da_id and fb == db_id) or (fa == db_id and fb == da_id):
			return maxi(1, age_val)
		var ha := str(dis.get("from_hex_id", ""))
		var hb := str(dis.get("to_hex_id", ""))
		if hex_a != hex_b and ((ha == hex_a and hb == hex_b) or (ha == hex_b and hb == hex_a)):
			return maxi(1, age_val)
	return -1


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


func _get_deme_world_pos(cell: EvoTypes.HexCell, deme_id: String) -> Vector2:
	var w_xy := HexMath.axial_to_world(cell.q, cell.r)
	var idx := cell.deme_ids.find(deme_id)
	if idx >= 0:
		w_xy += HexMath.compute_village_sector_offset(idx, cell.deme_ids.size(), HexMath.HEX_SIZE)
	return w_xy


func _get_deme_local_pos(cell: EvoTypes.HexCell, deme_id: String) -> Vector2:
	return _project(_get_deme_world_pos(cell, deme_id), _get_cell_top_z(cell))


func _find_closest_deme_pair(cell_a: EvoTypes.HexCell, cell_b: EvoTypes.HexCell) -> Dictionary:
	var best_da: EvoTypes.Deme = null
	var best_db: EvoTypes.Deme = null
	var best_dist_sq := INF
	for id_a in cell_a.deme_ids:
		if not world_state.demes.has(id_a):
			continue
		var da: EvoTypes.Deme = world_state.demes[id_a]
		var wa := _get_deme_world_pos(cell_a, id_a)
		for id_b in cell_b.deme_ids:
			if not world_state.demes.has(id_b):
				continue
			var db: EvoTypes.Deme = world_state.demes[id_b]
			var wb := _get_deme_world_pos(cell_b, id_b)
			var d2 := wa.distance_squared_to(wb)
			if d2 < best_dist_sq:
				best_dist_sq = d2
				best_da = da
				best_db = db
	if best_da == null or best_db == null:
		return {}
	return {"da": best_da, "db": best_db}


func _resolve_road_endpoints(cell_a: EvoTypes.HexCell, cell_b: EvoTypes.HexCell, from_deme_id: String, to_deme_id: String) -> Dictionary:
	var world_a: Vector2
	var world_b: Vector2
	if cell_a.id != cell_b.id and not cell_a.deme_ids.is_empty() and not cell_b.deme_ids.is_empty():
		var closest := _find_closest_deme_pair(cell_a, cell_b)
		if not closest.is_empty():
			world_a = _get_deme_world_pos(cell_a, (closest["da"] as EvoTypes.Deme).id)
			world_b = _get_deme_world_pos(cell_b, (closest["db"] as EvoTypes.Deme).id)
		else:
			world_a = _get_flow_endpoint_world(cell_a, from_deme_id, 0)
			world_b = _get_flow_endpoint_world(cell_b, to_deme_id, 1)
	else:
		world_a = _get_flow_endpoint_world(cell_a, from_deme_id, 0)
		world_b = _get_flow_endpoint_world(cell_b, to_deme_id, 1)
	var z_a := _get_cell_top_z(cell_a)
	var z_b := _get_cell_top_z(cell_b)
	return {
		"world_a": world_a,
		"z_a": z_a,
		"world_b": world_b,
		"z_b": z_b,
		"p_a": _project(world_a, z_a),
		"p_b": _project(world_b, z_b)
	}


func _get_flow_endpoint_world(cell: EvoTypes.HexCell, deme_id: String, fallback_idx: int) -> Vector2:
	var w_xy := HexMath.axial_to_world(cell.q, cell.r)
	var idx := cell.deme_ids.find(deme_id)
	if idx == -1 and cell.deme_ids.size() > 0:
		idx = fallback_idx % cell.deme_ids.size()
	if idx >= 0:
		w_xy += HexMath.compute_village_sector_offset(idx, cell.deme_ids.size(), HexMath.HEX_SIZE)
	return w_xy


func _get_flow_endpoint(cell: EvoTypes.HexCell, deme_id: String, fallback_idx: int) -> Vector2:
	return _project(_get_flow_endpoint_world(cell, deme_id, fallback_idx), _get_cell_top_z(cell))


func _sample_road_curve(p_a: Vector2, p_b: Vector2, t: float, curve_sign: float, curve_factor: float = 0.045) -> Vector2:
	var diff := p_b - p_a
	var dist := diff.length()
	var perp := Vector2(-diff.y, diff.x).normalized() if dist > 0.01 else Vector2.UP
	var ctrl := (p_a + p_b) * 0.5 + perp * (minf(dist * curve_factor, 12.0) * curve_sign)
	var u := 1.0 - t
	return (u * u) * p_a + (2.0 * u * t) * ctrl + (t * t) * p_b


func _bridge_arch_point(p_a: Vector2, p_b: Vector2, t: float) -> Vector2:
	return p_a.lerp(p_b, t) + Vector2(0, sin(t * PI) * -10.0)


func _draw_collaboration_route(road: Dictionary) -> void:
	var ci := _network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.14))
	var show_badge: bool = bool(road.get("show_badge", true))

	# 1. Sinuous Stardew Valley cobblestone road with stone curbs
	var segments := 26
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		pts.append(_sample_road_curve(p_a, p_b, float(i) / float(segments), 1.0, curve_f))

	# Dark earth foundation & stone curb border
	ci.draw_polyline(pts, Color("#4a3219"), 16.0)
	ci.draw_polyline(pts, Color("#8c6d46"), 12.8)
	ci.draw_polyline(pts, Color("#d6b88a"), 9.0)

	# Individual pixel-art cobblestones along the winding road
	for i in range(1, segments):
		var pt := pts[i]
		var dir := (pts[i + 1] - pts[i - 1]).normalized()
		var perp := Vector2(-dir.y, dir.x)
		ci.draw_circle(pt + perp * 2.8, 3.2, Color("#e6ccb2") if i % 2 == 0 else Color("#c4a474"))
		ci.draw_circle(pt - perp * 2.8, 2.9, Color("#b89566"))

	# Roadside wooden lantern post on the road shoulder when route is long enough
	var road_len := p_a.distance_to(p_b)
	if road_len > 150.0:
		var road_dir := (p_b - p_a) / road_len
		var road_perp := Vector2(-road_dir.y, road_dir.x)
		var lantern_pt := _sample_road_curve(p_a, p_b, 0.30, 1.0, curve_f) + road_perp * 15.0 + Vector2(0, -5.0)
		ci.draw_circle(lantern_pt + Vector2(2.0, -7.0), 13.0, Color(1.0, 0.88, 0.38, 0.25))
		_draw_centered_sprite(ci, "road_lantern", lantern_pt, 1.35)

	# Midpoint Alliance / Trade Emblem Badge
	if show_badge:
		var mid := _sample_road_curve(p_a, p_b, 0.5, 1.0, curve_f) + Vector2(0, -14.0)
		ci.draw_circle(mid, 11.5, Color("#064e3b"))
		ci.draw_circle(mid, 9.5, Color("#10b981"))
		_draw_centered_sprite(ci, "icon_coop_link", mid + Vector2(0, 6.8), 1.05)


func _draw_wooden_bridge(road: Dictionary) -> void:
	var ci := _network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var show_badge: bool = bool(road.get("show_badge", true))
	var diff := p_b - p_a
	var dir := diff.normalized() if diff.length() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	# Vertical wooden support pilings into the water/ravine below
	for t_pile in [0.22, 0.50, 0.78]:
		var base_pt := p_a.lerp(p_b, t_pile)
		var pile_top := base_pt + Vector2(0, -4.0)
		var pile_bot := base_pt + Vector2(0, 18.0)
		ci.draw_line(pile_top - perp * 6.0, pile_bot - perp * 6.0, Color("#3d2314"), 4.2)
		ci.draw_line(pile_top + perp * 6.0, pile_bot + perp * 6.0, Color("#4a2c18"), 4.2)
		# Water ripple around piling base
		ci.draw_line(pile_bot - Vector2(9.0, 0), pile_bot + Vector2(9.0, 0), Color(0.88, 0.97, 1.0, 0.65), 2.2)

	# Bridge deck & side beams
	var steps := 20
	var curve_pts := PackedVector2Array()
	var rail_left := PackedVector2Array()
	var rail_right := PackedVector2Array()
	for i in range(steps + 1):
		var pt := _bridge_arch_point(p_a, p_b, float(i) / float(steps))
		curve_pts.append(pt)
		rail_left.append(pt - perp * 7.6 + Vector2(0, -5.2))
		rail_right.append(pt + perp * 7.6 + Vector2(0, -5.2))

	ci.draw_polyline(curve_pts, Color("#3d2314"), 15.8)
	ci.draw_polyline(curve_pts, Color("#b07d4f"), 11.6)

	# Individual wooden planks perpendicular to bridge
	for i in range(1, steps):
		var c := curve_pts[i]
		ci.draw_line(c - perp * 7.0, c + perp * 7.0, Color("#d4a373") if i % 2 == 0 else Color("#8c5830"), 3.4)

	# Handrails
	ci.draw_polyline(rail_left, Color("#6b3e26"), 2.8)
	ci.draw_polyline(rail_right, Color("#6b3e26"), 2.8)

	if show_badge:
		var mid := curve_pts[steps / 2] + Vector2(0, -15.0)
		ci.draw_circle(mid, 11.5, Color("#064e3b"))
		ci.draw_circle(mid, 9.5, Color("#10b981"))
		_draw_centered_sprite(ci, "icon_coop_link", mid + Vector2(0, 6.8), 1.05)


func _draw_dispute_barricade_front(road: Dictionary) -> void:
	var ci := _network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var diff := p_b - p_a
	var dist := diff.length()
	var dir := diff / dist if dist > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var mid := (p_a + p_b) * 0.5
	var is_intra_hex := bool(road.get("is_same_hex", dist < 210.0))

	# 1. Split trampled war-paths stopping at the frontier barricades
	var stop_a := p_a.lerp(p_b, 0.34 if is_intra_hex else 0.38)
	var stop_b := p_b.lerp(p_a, 0.34 if is_intra_hex else 0.38)
	ci.draw_line(p_a, stop_a, Color("#3b2313"), 9.2 if is_intra_hex else 10.8)
	ci.draw_line(p_a, stop_a, Color("#785233"), 6.0 if is_intra_hex else 7.2)
	ci.draw_line(p_b, stop_b, Color("#3b2313"), 9.2 if is_intra_hex else 10.8)
	ci.draw_line(p_b, stop_b, Color("#785233"), 6.0 if is_intra_hex else 7.2)

	# Scorched earth & battle debris in the no-man's-land center
	var scorch_rx := 15.0 if is_intra_hex else 22.0
	_draw_ellipse_filled(ci, mid, scorch_rx, scorch_rx * 0.58, Color(0.16, 0.08, 0.05, 0.72))
	ci.draw_line(mid - perp * scorch_rx, mid + perp * scorch_rx, Color("#dc2626"), 2.8)

	# 2. Sharpened log barricades (`barricade_spikes`) blocking the road
	if is_intra_hex:
		_draw_centered_sprite(ci, "barricade_spikes", mid + Vector2(0, 3.0), 1.35)
	else:
		_draw_centered_sprite(ci, "barricade_spikes", p_a.lerp(p_b, 0.40) + Vector2(0, 3.0), 1.50)
		_draw_centered_sprite(ci, "barricade_spikes", p_a.lerp(p_b, 0.60) + Vector2(0, 3.0), 1.50)


func _draw_broken_cut_road(road: Dictionary) -> void:
	var ci := _network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var alpha: float = float(road.get("alpha", 0.90))
	var show_badge: bool = bool(road.get("show_badge", true))
	var mod_col := Color(1.0, 1.0, 1.0, alpha)
	var mid := (p_a + p_b) * 0.5

	# 1. Weathered cobblestone remnants on both ends that break off before the middle
	for rng in [Vector2(0.08, 0.36), Vector2(0.64, 0.92)]:
		var steps := 7
		for i in range(steps + 1):
			var pt := p_a.lerp(p_b, lerpf(rng.x, rng.y, float(i) / float(steps)))
			ci.draw_circle(pt, 5.2, Color("#47423c") * mod_col)
			ci.draw_circle(pt, 3.6, (Color("#8c8479") if i % 2 == 0 else Color("#6e675f")) * mod_col)

	# 2. Cracked ground & encroaching wild weeds in the severed gap
	_draw_centered_sprite(ci, "soil_crack", mid + Vector2(0, 5.0), 1.30, mod_col)
	ci.draw_circle(mid + Vector2(-8.0, 3.0), 4.6, Color("#4d7c0f") * mod_col)
	ci.draw_circle(mid + Vector2(8.0, 1.5), 4.0, Color("#65a30d") * mod_col)

	# 3. Wooden 'X' Road-Closed Barrier (`road_block_sign`) & Broken Link Icon
	_draw_centered_sprite(ci, "road_block_sign", mid + Vector2(0, 4.0), 1.30, mod_col)
	if show_badge:
		_draw_centered_sprite(ci, "icon_broken_link", mid + Vector2(0, -11.0), 1.05, mod_col)


func _draw_migration_expedition(road: Dictionary) -> void:
	var ci := _network_layer
	var p_a: Vector2 = road["p_a"]
	var p_b: Vector2 = road["p_b"]
	var curve_f: float = float(road.get("curve_factor", 0.14))
	var steps := 18
	for i in range(1, steps):
		var pt := _sample_road_curve(p_a, p_b, float(i) / float(steps), -1.0, curve_f)
		ci.draw_circle(pt, 4.8, Color("#0369a1"))
		ci.draw_circle(pt, 3.2, Color("#bae6fd") if i % 2 == 0 else Color("#e0f2fe"))


# ============================================================================
# VILLAGES: PLAZAS (static), BUILDINGS & FLORA (cached props), VILLAGERS (per frame)
# ============================================================================

func _get_villager_textures_for_color(tunic_col: Color) -> Array[ImageTexture]:
	var hex_key := tunic_col.to_html(false)
	if _villager_tex_sets.has(hex_key):
		return _villager_tex_sets[hex_key]
	var tex_set: Array[ImageTexture] = [
		PixelArtGen.get_villager_texture(VILLAGER_POSES[0], tunic_col),
		PixelArtGen.get_villager_texture(VILLAGER_POSES[1], tunic_col),
		PixelArtGen.get_villager_texture(VILLAGER_POSES[2], tunic_col)
	]
	_villager_tex_sets[hex_key] = tex_set
	return tex_set


func _collect_villages() -> Array[Dictionary]:
	var villages: Array[Dictionary] = []
	var font := ThemeDB.fallback_font
	for hex_id in world_state.cells:
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		if _is_water(cell):
			continue
		var count := cell.deme_ids.size()
		var scale_factor := 1.0
		if count == 2:
			scale_factor = 0.86
		elif count >= 3:
			scale_factor = 0.78
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

			var bb_offset := Vector2(0.0, 32.0)
			var sub_text := "%d" % deme.population
			var sub_size := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			var box_size := Vector2(maxf(38.0, sub_size.x + 20.0), 16.0)
			var v_pos := _project(v_world, top_z)

			villages.append({
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
				"archetype": _get_deme_dominant_archetype(deme),
				"status_col": STATUS_COLORS.get(deme.get_vital_status(), Color("#38bdf8")),
				"villager_count": clampi(2 + tier + int(deme.population / 110), 3, 7),
				"villager_textures": _get_villager_textures_for_color(Color(deme.color)),
				"bb_offset": bb_offset * scale_factor,
				"sub_text": sub_text,
				"label_text": sub_text,
				"sub_size": sub_size,
				"box_size": box_size,
				"pill_w": box_size.x,
				"hit_rect": Rect2(v_pos - Vector2(74, 76) * scale_factor, Vector2(148, 116) * scale_factor)
			})
	return villages


func _get_village_building_layout(tier: int, sf: float, has_culture: bool, cultural_count: int, archetype: String) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	match tier:
		1:
			items.append({"sprite": "tier1_tent", "offset": Vector2(-48, -18) * sf, "scale": 2.50 * sf})
		2:
			items.append({"sprite": "tier2_cottage", "offset": Vector2(-52, -25) * sf, "scale": 2.54 * sf})
			items.append({"sprite": "tier2_barn", "offset": Vector2(52, -25) * sf, "scale": 2.38 * sf})
		3:
			items.append({"sprite": "tier3_townhall", "offset": Vector2(0, -44) * sf, "scale": 2.58 * sf})
			items.append({"sprite": "tier3_house", "offset": Vector2(-62, -10) * sf, "scale": 2.38 * sf})
		_:
			items.append({"sprite": "tier4_citadel", "offset": Vector2(0, -48) * sf, "scale": 2.65 * sf})
			items.append({"sprite": "tier4_tower", "offset": Vector2(-66, -14) * sf, "scale": 2.38 * sf})
			items.append({"sprite": "tier4_windmill", "offset": Vector2(66, -14) * sf, "scale": 2.38 * sf})

	if has_culture:
		var totem_scale := (2.12 + mini(3, cultural_count) * 0.16) * sf
		items.append({"sprite": "cultural_totem", "offset": Vector2(-52, 29) * sf, "scale": totem_scale})

	var act_offset := Vector2(48, -12) * sf if tier == 1 else (Vector2(62, -10) * sf if tier == 3 else Vector2(52, 29) * sf)
	items.append({"sprite": "act_" + archetype, "offset": act_offset, "scale": 2.32 * sf})
	return items


func _draw_village_plaza(village: Dictionary) -> void:
	var ci := _network_layer
	var deme: EvoTypes.Deme = village["deme"]
	var sf: float = village["sf"]
	var modulate_col: Color = village["modulate"]
	var status_col: Color = village["status_col"]
	var v_pos: Vector2 = village["pos"]
	var plaza_center: Vector2 = v_pos + Vector2(0, 8.0 * sf)

	# 1. Soft village compound earth clearing & individual stone pads under each building
	_draw_ellipse_filled(ci, v_pos + Vector2(0, -4.0 * sf), 86.0 * sf, 50.0 * sf, Color(0.36, 0.25, 0.16, 0.34) * modulate_col)
	var layout := _get_village_building_layout(
		int(village["tier"]),
		sf,
		not deme.cultural_trait_ids.is_empty(),
		deme.cultural_trait_ids.size(),
		str(village["archetype"])
	)
	for b_item in layout:
		var b_foot: Vector2 = v_pos + (b_item["offset"] as Vector2)
		_draw_ellipse_filled(ci, b_foot + Vector2(0, -3.0 * sf), 26.0 * sf, 14.5 * sf, Color("#7c5c3b") * modulate_col)
		_draw_ellipse_filled(ci, b_foot + Vector2(0, -3.0 * sf), 21.5 * sf, 11.5 * sf, Color("#cbb082") * modulate_col)

	# 2. Town Square Cobblestone Plaza & Vital Status Ring (drawn on ground)
	var plinth_r := 50.0 * sf
	var rim_r := plinth_r + 5.5 * sf
	_draw_ellipse_filled(ci, plaza_center, rim_r, rim_r * 0.58, Color("#5c4028") * modulate_col)
	_draw_ellipse_filled(ci, plaza_center, plinth_r, plinth_r * 0.58, Color("#c2a378") * modulate_col)
	_draw_ellipse_filled(ci, plaza_center, plinth_r * 0.74, plinth_r * 0.74 * 0.58, Color("#d9be96") * modulate_col)

	# Individual cobblestone tiles around the village courtyard
	for c_i in range(14):
		var c_ang := TAU * float(c_i) / 14.0
		var c_pt := plaza_center + Vector2(cos(c_ang) * plinth_r * 0.84, sin(c_ang) * plinth_r * 0.48)
		ci.draw_circle(c_pt, 4.4 * sf, Color("#a38358") * modulate_col)

	var ring_r := plinth_r + 4.5 * sf
	_draw_ellipse_outline(ci, plaza_center, ring_r, ring_r * 0.58, status_col * modulate_col, 3.4)

	if deme.id == selected_deme_id:
		var sel_r := plinth_r + 11.0 * sf
		_draw_ellipse_outline(ci, plaza_center, sel_r, sel_r * 0.58, C_SELECTION, 4.2)
	elif deme.id == hovered_deme_id:
		var hov_r := plinth_r + 9.5 * sf
		_draw_ellipse_outline(ci, plaza_center, hov_r, hov_r * 0.58, Color(1.0, 0.92, 0.68, 0.88), 2.8)


func _compute_cell_flora_key(cell: EvoTypes.HexCell, top_z: float) -> Array:
	var r_ratio: float = clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
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
	var prop_count: int = clampi(int(round(float(base_count) * (0.55 + 0.45 * r_ratio))), 6, 13)
	var v_count := cell.deme_ids.size()
	if v_count > 0:
		prop_count = clampi(prop_count - v_count, 5, 10)
	var k_band: int = 0 if k_ratio < 0.60 else (1 if k_ratio < 0.85 else 2)
	var link_mask: int = 0
	if v_count > 0:
		var n_ids := HexMath.get_neighbor_ids(cell.q, cell.r, world_state.cells)
		for n_idx in range(n_ids.size()):
			var n_id := n_ids[n_idx]
			var ncell: EvoTypes.HexCell = world_state.cells[n_id]
			var has_link := not ncell.deme_ids.is_empty() or (ncell.biome == "coastal_shallows" and ncell.altitude >= world_state.sea_level)
			if not has_link:
				for flow in world_state.active_flows:
					if (flow.from_hex_id == cell.id and flow.to_hex_id == n_id) or (flow.from_hex_id == n_id and flow.to_hex_id == cell.id):
						has_link = true
						break
			if has_link:
				link_mask |= (1 << n_idx)
	return [cell.biome, top_z, prop_count, v_count, k_band, link_mask]


func _collect_static_props() -> Array[Prop]:
	var props: Array[Prop] = []
	for hex_id in world_state.cells:
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		if _is_water(cell):
			continue
		var world_xy := HexMath.axial_to_world(cell.q, cell.r)
		var top_z := _get_cell_top_z(cell)
		var flora_key := _compute_cell_flora_key(cell, top_z)
		if _cell_flora_cache.has(hex_id) and (_cell_flora_cache[hex_id]["key"] as Array) == flora_key:
			props.append_array(_cell_flora_cache[hex_id]["props"] as Array[Prop])
		else:
			var cell_props: Array[Prop] = []
			_collect_cell_flora_props(cell, world_xy, top_z, cell_props)
			_cell_flora_cache[hex_id] = {"key": flora_key, "props": cell_props}
			props.append_array(cell_props)
		# Ruins if recent extinction occurred here
		if world_state.recent_extinction_hexes.has(hex_id):
			props.append(_world_prop("ruins", world_xy + Vector2(0, 12), top_z, Vector2.ZERO, 2.20, Color.WHITE))

	for village in _villages:
		_collect_village_building_props(village, props)

	return props


func _collect_village_building_props(village: Dictionary, props: Array[Prop]) -> void:
	var deme: EvoTypes.Deme = village["deme"]
	var v_world: Vector2 = village["world_xy"]
	var top_z: float = village["top_z"]
	var sf: float = village["sf"]
	var m: Color = village["modulate"]

	var layout := _get_village_building_layout(
		int(village["tier"]),
		sf,
		not deme.cultural_trait_ids.is_empty(),
		deme.cultural_trait_ids.size(),
		str(village["archetype"])
	)
	for b_item in layout:
		props.append(_world_prop(str(b_item["sprite"]), v_world, top_z, b_item["offset"], float(b_item["scale"]), m))


func _get_cell_road_corridors_local(cell: EvoTypes.HexCell, village_local_centers: Array[Vector2]) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var v_count := village_local_centers.size()
	if v_count == 0:
		return segments

	for i in range(v_count):
		for j in range(i + 1, v_count):
			segments.append({"a": village_local_centers[i], "b": village_local_centers[j]})

	var cell_world := HexMath.axial_to_world(cell.q, cell.r)
	for n_id in HexMath.get_neighbor_ids(cell.q, cell.r, world_state.cells):
		var ncell: EvoTypes.HexCell = world_state.cells[n_id]
		var has_link := not ncell.deme_ids.is_empty() or (ncell.biome == "coastal_shallows" and ncell.altitude >= world_state.sea_level)
		if not has_link:
			for flow in world_state.active_flows:
				if (flow.from_hex_id == cell.id and flow.to_hex_id == n_id) or (flow.from_hex_id == n_id and flow.to_hex_id == cell.id):
					has_link = true
					break
		if has_link:
			var n_local := HexMath.axial_to_world(ncell.q, ncell.r) - cell_world
			for vc in village_local_centers:
				segments.append({"a": vc, "b": n_local})
	return segments


func _collect_cell_flora_props(cell: EvoTypes.HexCell, world_xy: Vector2, top_z: float, props: Array[Prop]) -> void:
	var r_ratio: float = clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)

	# Determine target count: between 6 and 14 pixel-art landscape elements per parcel
	var base_count := 8
	if cell.biome == "tropical_forest":
		base_count = 13
	elif cell.biome == "savanna":
		base_count = 10
	elif cell.biome == "tundra":
		base_count = 9
	elif cell.biome == "coastal_shallows":
		base_count = 7

	var prop_count: int = clampi(int(round(float(base_count) * (0.55 + 0.45 * r_ratio))), 6, 13)

	# Compute village centers in local hex coordinates to keep a generous clearing around buildings
	var village_local_centers: Array[Vector2] = []
	var v_count := cell.deme_ids.size()
	for v_idx in range(v_count):
		village_local_centers.append(HexMath.compute_village_sector_offset(v_idx, v_count, HexMath.HEX_SIZE))

	if v_count > 0:
		prop_count = clampi(prop_count - v_count, 5, 10)

	var road_corridors := _get_cell_road_corridors_local(cell, village_local_centers)
	var palette_sprites: Array = BIOME_FLORA_PALETTES.get(cell.biome, DEFAULT_FLORA_PALETTE)
	var placed_offsets: Array[Vector2] = []
	var village_clear_r := 118.0 if v_count == 1 else 88.0
	var inner_count: int = 0 if v_count > 0 else maxi(2, prop_count / 3)
	var outer_count: int = prop_count - inner_count

	for idx in range(prop_count):
		var s1 := _cell_seed(cell.q, cell.r, idx * 13 + 1)
		var s2 := _cell_seed(cell.q, cell.r, idx * 29 + 7)
		var angle := 0.0
		var rad_norm := 0.0
		if idx < inner_count:
			angle = (TAU * float(idx) / float(inner_count)) + float(s1 % 31 - 15) * 0.045
			rad_norm = 0.22 + float(s2 % 22) * 0.01
		else:
			var o_idx := idx - inner_count
			angle = (TAU * float(o_idx) / float(maxi(1, outer_count))) + 0.32 + float(s1 % 31 - 15) * 0.032
			if v_count > 0:
				rad_norm = 0.62 + float(s2 % 20) * 0.01
			else:
				rad_norm = 0.50 + float(s2 % 28) * 0.01

		var local_off := Vector2(cos(angle), sin(angle)) * (HexMath.HEX_SIZE * rad_norm)

		# Ensure generous clearing around villages & intra-hex center
		var valid_spot := true
		for vc in village_local_centers:
			if local_off.distance_to(vc) < village_clear_r:
				var push_dir := (local_off - vc).normalized() if local_off.distance_to(vc) > 0.01 else Vector2(cos(angle), sin(angle))
				local_off = vc + push_dir * (village_clear_r + 8.0)
				if local_off.length() > HexMath.HEX_SIZE * 0.82:
					valid_spot = false
				break
		if not valid_spot:
			continue
		if v_count >= 2 and local_off.length() < 74.0:
			continue
		for vc in village_local_centers:
			if local_off.distance_to(vc) < village_clear_r - 2.0:
				valid_spot = false
				break
		if not valid_spot:
			continue

		# Keep road corridors clear of trees/rocks
		for seg in road_corridors:
			var closest := Geometry2D.get_closest_point_to_segment(local_off, seg["a"], seg["b"])
			if local_off.distance_to(closest) < 42.0:
				valid_spot = false
				break
		if not valid_spot:
			continue

		# Enforce minimum separation between flora props so trees and rocks never pile up
		for prev in placed_offsets:
			if local_off.distance_to(prev) < 52.0:
				valid_spot = false
				break
		if not valid_spot:
			continue

		placed_offsets.append(local_off)
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

		var prop := _world_prop(sprite_key, world_xy + local_off, top_z, Vector2.ZERO, 1.12 + float(s1 % 20) * 0.015, Color.WHITE)
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
		if not _visible_world_rect.has_point(p_a) and not _visible_world_rect.has_point(p_b):
			continue
		var curve_f: float = float(road.get("curve_factor", 0.14))
		match road["kind"]:
			"collab":
				if bool(road.get("show_traffic", true)):
					var raw_t := fposmod(_anim_time * 0.32 + float(int(p_a.x + p_b.y) % 7) * 0.13, 1.0)
					var t_cart := lerpf(0.22, 0.78, raw_t)
					_draw_centered_sprite(_anim_layer, "caravan_cart", _sample_road_curve(p_a, p_b, t_cart, 1.0, curve_f) + Vector2(0, -6.0), 1.55)
			"bridge":
				if bool(road.get("show_traffic", true)):
					var raw_b := fposmod(_anim_time * 0.32, 1.0)
					var cart_pos := _bridge_arch_point(p_a, p_b, lerpf(0.20, 0.80, raw_b)) + Vector2(0, -6.0)
					_draw_centered_sprite(_anim_layer, "caravan_cart", cart_pos, 1.55)
			"dispute":
				if bool(road.get("show_badge", true)):
					_draw_battle_sparks(road.get("badge_pos", (p_a + p_b) * 0.5))
			"expedition":
				var raw_w := fposmod(_anim_time * 0.38, 1.0)
				var wagon_pos := _sample_road_curve(p_a, p_b, lerpf(0.20, 0.82, raw_w), -1.0, curve_f) + Vector2(0, -6.0)
				_draw_centered_sprite(_anim_layer, "settler_wagon", wagon_pos, 1.55)

	# Highlighted lineage vertical light beam
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

	_draw_props()


func _draw_battle_sparks(mid: Vector2) -> void:
	var pulse := 1.0 + 0.22 * sin(_anim_time * 8.5)
	for s_i in range(4):
		var ang := _anim_time * 5.0 + float(s_i) * (TAU * 0.25)
		var spark_pos := mid + Vector2(cos(ang) * 11.0, sin(ang) * 6.5 - 6.0)
		_anim_layer.draw_circle(spark_pos, 3.0, Color("#fde047") if s_i % 2 == 0 else Color("#f97316"))

	var badge_pos := mid + Vector2(0, -18.0)
	_anim_layer.draw_circle(badge_pos, 14.0 * pulse, Color(0.94, 0.20, 0.20, 0.38))
	_draw_centered_sprite(_anim_layer, "icon_conflict_swords", badge_pos + Vector2(0, 8.0), 1.20)


# Merges the pre-sorted static props with the few moving ones sorted each frame.
func _draw_props() -> void:
	var moving := _collect_moving_props()
	moving.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	var m_idx := 0
	for prop in _static_props:
		if not _visible_world_rect.intersects(prop.rect):
			continue
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


func _acquire_moving_prop(tex: ImageTexture, foot: Vector2, scale_val: float, anchor_y_ratio: float, modulate_col: Color) -> Prop:
	var prop: Prop
	if _moving_prop_count < _moving_prop_pool.size():
		prop = _moving_prop_pool[_moving_prop_count]
	else:
		prop = Prop.new(tex, scale_val, anchor_y_ratio, modulate_col)
		_moving_prop_pool.append(prop)
	_moving_prop_count += 1
	prop.texture = tex
	var sz: Vector2 = tex.get_size() * scale_val
	prop.anchor_offset = Vector2(sz.x * 0.5, sz.y * anchor_y_ratio)
	prop.rect = Rect2(foot - prop.anchor_offset, sz)
	prop.y = foot.y
	prop.modulate = modulate_col
	prop.sways = false
	return prop


func _collect_moving_props() -> Array[Prop]:
	_moving_prop_count = 0
	var props: Array[Prop] = []
	for village in _villages:
		var v_pos: Vector2 = village["pos"]
		if not _visible_world_rect.has_point(v_pos):
			continue
		var sf: float = village["sf"]
		var m: Color = village["modulate"]
		if int(village["tier"]) == 1:
			var fire_sprite := "tier1_campfire" if int(_anim_time * 5.0) % 2 == 0 else "tier1_campfire_2"
			props.append(_acquire_moving_prop(PixelArtGen.get_texture(fire_sprite), v_pos + Vector2(4, 8) * sf, 2.42 * sf, 0.78, m))

		# Animated Pixel-Art Villagers walking around the village courtyard
		var villager_count: int = village["villager_count"]
		var v_textures: Array[ImageTexture] = village["villager_textures"]
		for v_idx in range(villager_count):
			var orbit_angle := _anim_time * (0.95 + float(v_idx % 3) * 0.22) + float(v_idx) * (TAU / float(villager_count))
			var orbit_r := (28.0 + float(v_idx % 3) * 9.0) * sf
			var foot := v_pos + Vector2(cos(orbit_angle) * orbit_r, sin(orbit_angle) * (orbit_r * 0.56) + 9.0 * sf)
			var frame := int((_anim_time * 6.0) + float(v_idx)) % 3
			props.append(_acquire_moving_prop(v_textures[frame], foot, 2.60 * sf, 0.85, m))

	# Road travelers walking along active collaboration roads (clamped outside village plazas)
	for r_idx in range(_roads.size()):
		var road: Dictionary = _roads[r_idx]
		if not TRAVELER_ROAD_KINDS.has(road["kind"]) or not bool(road.get("show_traffic", true)):
			continue
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not _visible_world_rect.has_point(p_a) and not _visible_world_rect.has_point(p_b):
			continue
		var curve_f: float = float(road.get("curve_factor", 0.045))
		var r_textures: Array[ImageTexture] = road["villager_textures"]
		for traveler_i in range(2):
			var raw_walk := fposmod(_anim_time * 0.24 + float(r_idx) * 0.31 + float(traveler_i) * 0.48, 1.0)
			if traveler_i == 1:
				raw_walk = 1.0 - raw_walk
			var t_walk := lerpf(0.24, 0.76, raw_walk)
			var foot := _sample_road_curve(p_a, p_b, t_walk, 1.0, curve_f)
			var frame := int((_anim_time * 6.5) + float(traveler_i + r_idx)) % 3
			props.append(_acquire_moving_prop(r_textures[frame], foot, 2.55, 0.85, Color.WHITE))
	return props


func _world_prop(sprite_name: String, world_xy: Vector2, top_z: float, screen_offset: Vector2, scale_val: float, modulate_col: Color) -> Prop:
	var prop := Prop.new(PixelArtGen.get_texture(sprite_name), scale_val, 0.78, modulate_col)
	prop.world_xy = world_xy
	prop.top_z = top_z
	prop.screen_offset = screen_offset
	return prop


# ============================================================================
# SCREEN-SPACE OVERLAY (per frame): signboards, thought bubbles & particles
# ============================================================================

func _draw_overlay() -> void:
	var to_screen := _world_layer.transform
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)
	var screen_cull_rect := Rect2(Vector2(-240.0, -200.0), vp_size + Vector2(480.0, 400.0))

	_deme_hit_rects.clear()
	for village in _villages:
		var v_pos: Vector2 = village["pos"]
		var screen_pos: Vector2 = to_screen * v_pos
		if not screen_cull_rect.has_point(screen_pos):
			continue
		var deme_id := str(village.get("deme_id", (village["deme"] as EvoTypes.Deme).id))
		var hex_id := str(village.get("hex_id", ""))
		_deme_hit_rects.append({
			"rect": to_screen * (village["hit_rect"] as Rect2),
			"deme_id": deme_id,
			"hex_id": hex_id
		})
		var crest_pos: Vector2 = to_screen * (v_pos + Vector2(0.0, 30.0 * float(village["sf"])))
		_draw_village_billboard(village, crest_pos)
	_draw_seasonal_particles()


func _draw_village_billboard(village: Dictionary, pos: Vector2) -> void:
	var ci := _overlay_layer
	var deme: EvoTypes.Deme = village["deme"]
	var is_dimmed: bool = village["is_dimmed"]

	var font := ThemeDB.fallback_font
	var sub_text: String = village["sub_text"]
	var box_size: Vector2 = village["box_size"]
	var rect := Rect2(pos.x - box_size.x * 0.5, pos.y - box_size.y * 0.5, box_size.x, box_size.y)

	var alpha := 0.48 if is_dimmed else 0.96
	var is_selected := deme.id == selected_deme_id
	var is_hovered := deme.id == hovered_deme_id

	# Stationary dark-wood & brass Plaza Crest anchored at front rim of cobblestone plaza
	if is_selected:
		ci.draw_rect(rect.grow(2.0), Color(1.0, 0.88, 0.28, 0.38 * alpha), false, 2.0)
		var pip_top := Vector2(pos.x, rect.position.y - 3.5)
		ci.draw_colored_polygon(
			PackedVector2Array([pip_top, pip_top + Vector2(-3.5, 3.5), pip_top + Vector2(3.5, 3.5)]),
			C_SELECTION
		)

	ci.draw_rect(Rect2(rect.position + Vector2(0, 1.5), rect.size), Color(0, 0, 0, 0.34 * alpha), true)
	ci.draw_rect(rect, Color(0.14, 0.08, 0.04, 0.90 * alpha), true)

	var border_col := C_SELECTION if is_selected else (Color(1.0, 0.92, 0.68, alpha) if is_hovered else Color("#78472a"))
	border_col.a = alpha
	var border_w := 2.0 if is_selected else (1.6 if is_hovered else 1.2)
	ci.draw_rect(rect, border_col, false, border_w)

	var shield_c := Vector2(rect.position.x + 8.5, pos.y)
	ci.draw_circle(shield_c, 4.6, Color(0.08, 0.04, 0.02, alpha))
	var lin_col := Color(deme.color)
	lin_col.a = alpha
	ci.draw_circle(shield_c, 3.8, lin_col)
	ci.draw_circle(shield_c + Vector2(-1.0, -1.0), 1.1, lin_col.lightened(0.32))

	var text_col := Color("#fde047") if is_selected else Color("#fef3c7")
	text_col.a = alpha
	ci.draw_string(font, Vector2(rect.position.x + 15.5, pos.y + 3.5), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)
	_deme_hit_rects.append({"rect": rect, "deme_id": deme.id, "hex_id": village["hex_id"]})


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
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)
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

func _draw_centered_sprite(ci: CanvasItem, sprite_name: String, center_pos: Vector2, scale_val: float, modulate_col: Color = Color.WHITE) -> void:
	var tex: ImageTexture = PixelArtGen.get_texture(sprite_name)
	var sz: Vector2 = tex.get_size() * scale_val
	ci.draw_texture_rect(tex, Rect2(Vector2(center_pos.x - sz.x * 0.5, center_pos.y - sz.y * 0.78), sz), false, modulate_col)


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
	var max_r_sq := HexMath.HEX_SIZE * HexMath.HEX_SIZE * 1.35
	for i in range(_sorted_hex_ids.size() - 1, -1, -1):
		var hex_id := _sorted_hex_ids[i]
		if local_pos.distance_squared_to(_hex_centers.get(hex_id, local_pos)) > max_r_sq:
			continue
		if Geometry2D.is_point_in_polygon(local_pos, _hex_polys[hex_id]):
			return hex_id
	return ""
