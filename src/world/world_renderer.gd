class_name EvoWorldRenderer
extends Node2D

const PixelArtGen = preload("res://src/world/pixel_art_gen.gd")
const CameraController = preload("res://src/world/camera_controller.gd")
const OceanWavesShader = preload("res://src/world/shaders/ocean_waves.gdshader")
const Prop = EvoPropFloraRenderer.Prop

signal hex_clicked(hex_id: String, button_index: int)
signal hex_dragged(hex_id: String)
signal deme_clicked(deme_id: String, hex_id: String)

const MAX_COLUMN_HEIGHT_PX: float = 96.0
const BIOME_PALETTE := EvoHexColumnRenderer.BIOME_PALETTE

var world_state: EvoTypes.WorldState
var camera: CameraController
var lang: String = "es"
var active_lens: String = "biome"
var active_tool: String = "inspect"
var selected_hex_id: String = "0,0"
var selected_deme_id: String = ""
var highlighted_lineage_id: String = ""
var hovered_hex_id: String = ""
var hovered_deme_id: String = ""
var brush_radius: int = 1

var _backdrop_rect := ColorRect.new()
var _ocean_shader_mat := ShaderMaterial.new()
var _world_layer := Node2D.new()
var _terrain_layer := Node2D.new()
var _network_layer := Node2D.new()
var _anim_layer := Node2D.new()
var _overlay_layer := Node2D.new()

var _anim_time: float = 0.0
var _fx_accum: float = 0.0
var _walker_accum: float = 0.0
var _last_vp_size: Vector2 = Vector2.ZERO
var _dirty: bool = true
var _overlay_dirty: bool = true
var _last_camera_zoom: float = -1.0
var _last_active_lens: String = "biome"
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
var _village_by_deme_id: Dictionary = {}
var _rural_cell_ids: Array[String] = []
var _static_props: Array[Prop] = []
var _deme_hit_rects: Array[Dictionary] = []
var _column_state_cache: Dictionary = {}
var _last_sort_signature: Array = []
var _cell_flora_cache: Dictionary = {}
var _last_season: String = ""
var _last_network_cull_rect: Rect2 = Rect2()

var _press_pos: Vector2 = Vector2.ZERO
var _is_left_down: bool = false
var _last_dragged_hex_id: String = ""
var _particles: Array[Dictionary] = []
var _visible_world_rect: Rect2 = Rect2(-4000, -4000, 8000, 8000)
var _last_world_transform: Transform2D = Transform2D.IDENTITY
var _moving_prop_pool: Array[Prop] = []
var _moving_prop_count: int = 0
var _villager_tex_sets: Dictionary = {}
var _fx_active: Array[Dictionary] = []
var _fx_last_gen: int = -1
var replay_seconds: float = 2.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_world_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_network_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_anim_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_overlay_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_ocean_shader_mat.shader = OceanWavesShader
	_backdrop_rect.material = _ocean_shader_mat
	_backdrop_rect.color = Color("#0e3352")
	_backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_rect.show_behind_parent = true
	add_child(_backdrop_rect)

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


func _get_camera_zoom() -> float:
	return camera.zoom_level if camera != null else 1.0


func _process(delta: float) -> void:
	if world_state == null or camera == null:
		return
	_anim_time += delta
	EvoWorldOverlayRenderer.update_particles(self, delta)

	if active_lens != _last_active_lens:
		_last_active_lens = active_lens
		_dirty = true
		_overlay_dirty = true

	if _dirty:
		_rebuild()
	elif camera.yaw_deg != _built_yaw or camera.pitch_deg != _built_pitch:
		_reproject()

	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)
	var vp_changed := vp_size != _last_vp_size
	if vp_changed:
		_overlay_dirty = true
	_last_vp_size = vp_size
	_backdrop_rect.size = vp_size
	if world_state.season != _last_season:
		_update_ocean_shader_season()
	_world_layer.position = vp_size * 0.5 + camera.pan_offset
	var zoom_val := camera.zoom_level
	_world_layer.scale = Vector2(zoom_val, zoom_val)
	var zoom_changed := absf(zoom_val - _last_camera_zoom) > 0.005
	if zoom_changed:
		_last_camera_zoom = zoom_val
		_overlay_dirty = true

	var inv_xform := _world_layer.transform.affine_inverse()
	var tl := inv_xform * Vector2.ZERO
	var br := inv_xform * vp_size
	_visible_world_rect = Rect2(tl, br - tl).grow(280.0)

	if is_inside_tree() and _world_layer.transform != _last_world_transform:
		_last_world_transform = _world_layer.transform
		_overlay_dirty = true
		if _last_network_cull_rect.size == Vector2.ZERO or not _last_network_cull_rect.encloses(_visible_world_rect):
			_network_layer.queue_redraw()

	_fx_accum += delta
	var step_fx := false
	if _fx_accum >= 0.083:
		_fx_accum = fposmod(_fx_accum, 0.083)
		step_fx = true

	_walker_accum += delta
	var step_walker := false
	if _walker_accum >= 0.05:
		_walker_accum = fposmod(_walker_accum, 0.05)
		step_walker = true

	if step_fx or step_walker or zoom_changed:
		_bob_ocean_columns()
		_anim_layer.queue_redraw()
		if not _fx_active.is_empty() or active_lens == "health":
			_overlay_dirty = true

	if step_fx or vp_changed:
		for hex_id in _animated_fx_ids:
			if _visible_world_rect.has_point(_hex_centers[hex_id]):
				_water_fx[hex_id].queue_redraw()

	if _overlay_dirty:
		_overlay_layer.queue_redraw()


func set_world_state(p_state: EvoTypes.WorldState) -> void:
	world_state = p_state
	_fx_last_gen = p_state.generation if p_state != null else -1
	_fx_active.clear()
	_create_columns()
	_rebuild()


func set_camera(p_camera: CameraController) -> void:
	camera = p_camera
	_dirty = true
	_overlay_dirty = true


func refresh() -> void:
	_dirty = true
	_overlay_dirty = true


func refresh_overlay(state: EvoTypes.WorldState = null) -> void:
	if state != null:
		world_state = state
	_brush_hexes = _compute_brush_hexes()
	for village in _villages:
		var deme: EvoTypes.Deme = village["deme"]
		var is_dimmed: bool = highlighted_lineage_id != "" and deme.lineage_id != highlighted_lineage_id
		village["is_dimmed"] = is_dimmed
		var base_mod: Color = Color(1.0, 0.72, 0.68, 1.0) if deme.get_vital_status() == "starving" else Color.WHITE
		if is_dimmed:
			base_mod.a = 0.42
		village["modulate"] = base_mod
	_overlay_dirty = true
	_overlay_layer.queue_redraw()


func update_hover(screen_pos: Vector2) -> void:
	var hit_hex := _pick_hex_at(screen_pos)
	if hit_hex != hovered_hex_id:
		hovered_hex_id = hit_hex
		_update_brush()
		_overlay_dirty = true
	var hit_deme := _pick_deme_at(screen_pos)
	var new_hov_deme := str(hit_deme.get("deme_id", ""))
	if new_hov_deme != hovered_deme_id:
		hovered_deme_id = new_hov_deme
		_overlay_dirty = true


func _update_ocean_shader_season() -> void:
	if world_state == null:
		return
	_last_season = world_state.season
	var is_wet := _last_season == "wet_warm"
	_ocean_shader_mat.set_shader_parameter("deep_color", Vector4(0.055, 0.20, 0.32, 1.0) if is_wet else Vector4(0.043, 0.157, 0.251, 1.0))
	_ocean_shader_mat.set_shader_parameter("mid_color", Vector4(0.095, 0.34, 0.51, 1.0) if is_wet else Vector4(0.075, 0.27, 0.42, 1.0))
	if active_lens == "biome":
		_terrain_layer.modulate = Color(1.03, 0.99, 0.94, 1.0) if is_wet else Color(0.90, 0.95, 1.03, 1.0)
	_anim_layer.queue_redraw()


func refresh_village_decisions() -> void:
	var any_arch_changed := false
	for village in _villages:
		var deme: EvoTypes.Deme = village["deme"]
		var new_arch := _get_deme_dominant_archetype(deme)
		if village["archetype"] != new_arch:
			village["archetype"] = new_arch
			any_arch_changed = true
		if village["posture"] != deme.defense_posture:
			village["posture"] = deme.defense_posture
			any_arch_changed = true
	if any_arch_changed:
		_static_props = EvoPropFloraRenderer.collect_static_props(self)
		_network_layer.queue_redraw()
		_overlay_dirty = true
		_overlay_layer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if camera != null and camera.is_dragging():
			return
		var mm := event as InputEventMouseMotion
		update_hover(mm.position)
		if _is_left_down and active_tool != "inspect" and hovered_hex_id != "" and hovered_hex_id != _last_dragged_hex_id:
			_last_dragged_hex_id = hovered_hex_id
			hex_dragged.emit(hovered_hex_id)

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
						var hit_deme_id := str(hit_deme.get("deme_id", ""))
						var hit_hex_id := str(hit_deme.get("hex_id", ""))
						if hit_deme_id != "":
							if _is_edge_ping_entry(hit_deme, hit_hex_id):
								_focus_camera_on_hex(hit_hex_id)
							deme_clicked.emit(hit_deme_id, hit_hex_id)
						elif hit_hex_id != "":
							_focus_camera_on_hex(hit_hex_id)
							hex_clicked.emit(hit_hex_id, MOUSE_BUTTON_LEFT)
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
	_overlay_dirty = true
	_built_yaw = camera.yaw_deg
	_built_pitch = camera.pitch_deg
	_ground = camera.ground_transform()
	_lift = camera.height_scale()
	_update_ocean_shader_season()
	_brush_hexes = _compute_brush_hexes()
	_rebuild_cell_topology()
	_layout_columns()
	_villages = EvoPropFloraRenderer.collect_villages(self)
	_roads = EvoRoadNetworkRenderer.collect_roads(self)
	_static_props = EvoPropFloraRenderer.collect_static_props(self)
	if world_state != null and world_state.generation != _fx_last_gen:
		_fx_last_gen = world_state.generation
		EvoEventFxRenderer.enqueue_turn(self, world_state.turn_events, replay_seconds)
	_network_layer.queue_redraw()
	_anim_layer.queue_redraw()
	_overlay_layer.queue_redraw()


func _reproject() -> void:
	_overlay_dirty = true
	_built_yaw = camera.yaw_deg
	_built_pitch = camera.pitch_deg
	_ground = camera.ground_transform()
	_lift = camera.height_scale()
	_layout_columns()
	for village in _villages:
		var v_pos := _project(village["world_xy"], village["top_z"])
		village["pos"] = v_pos
		village["hit_rect"] = Rect2(v_pos - Vector2(104, 92), Vector2(208, 168))
	EvoRoadNetworkRenderer.reproject_roads(self)
	for prop in _static_props:
		prop.project(_ground, _lift)
	_static_props.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	_network_layer.queue_redraw()
	_anim_layer.queue_redraw()
	_overlay_layer.queue_redraw()


func _rebuild_cell_topology() -> void:
	var topo_sig: Array = [world_state.cells.size()]
	for hex_id in world_state.cells:
		var c: EvoTypes.HexCell = world_state.cells[hex_id]
		topo_sig.append(c.biome if not _is_water(c) else "ocean")
	if _cell_flora_cache.has("__topo_sig__") and (_cell_flora_cache["__topo_sig__"] as Array) == topo_sig:
		return
	_cell_flora_cache["__topo_sig__"] = topo_sig
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
		var cam_changed: bool = _last_sort_signature.size() < 2 or float(_last_sort_signature[0]) != _built_yaw or float(_last_sort_signature[1]) != _built_pitch or _sorted_hex_ids.size() != world_state.cells.size()
		_last_sort_signature = sort_sig
		if cam_changed:
			_sorted_hex_ids.assign(world_state.cells.keys())
		var depths: Dictionary = {}
		for hex_id in _sorted_hex_ids:
			var cell: EvoTypes.HexCell = world_state.cells[hex_id]
			depths[hex_id] = camera.get_depth(HexMath.axial_to_world(cell.q, cell.r), _get_cell_top_z(cell))
		_sorted_hex_ids.sort_custom(func(a: String, b: String) -> bool: return depths[a] < depths[b])

		for i in range(_sorted_hex_ids.size()):
			var hex_id := _sorted_hex_ids[i]
			var cell: EvoTypes.HexCell = world_state.cells[hex_id]
			var top_z := _get_cell_top_z(cell)
			var proj_key := Vector3(_built_yaw, _built_pitch, top_z)
			if cam_changed or not _hex_polys.has(hex_id) or cell.get_meta("_proj_key", Vector3.INF) != proj_key:
				cell.set_meta("_proj_key", proj_key)
				var world_xy := HexMath.axial_to_world(cell.q, cell.r)
				_hex_polys[hex_id] = _project_hex(world_xy, top_z)
				_hex_centers[hex_id] = _project(world_xy, top_z)

			var column: Node2D = _columns[hex_id]
			column.position = Vector2.ZERO
			if column.get_index() != i:
				_terrain_layer.move_child(column, i)

	if active_lens == "biome":
		_terrain_layer.modulate = Color(0.90, 0.95, 1.03, 1.0) if world_state.season == "dry_cold" else Color(1.03, 0.99, 0.94, 1.0)
		_anim_layer.modulate = Color.WHITE
		_network_layer.modulate = Color.WHITE
	else:
		_terrain_layer.modulate = Color.WHITE
		_anim_layer.modulate = Color(1.0, 1.0, 1.0, 0.94)
		_network_layer.modulate = Color(1.0, 1.0, 1.0, 0.90)

	for i in range(_sorted_hex_ids.size()):
		var hex_id := _sorted_hex_ids[i]
		var cell: EvoTypes.HexCell = world_state.cells[hex_id]
		var is_ocean := _is_water(cell)
		if not is_ocean:
			_columns[hex_id].position = Vector2.ZERO
		var eff_biome: String = "ocean" if is_ocean else cell.biome
		var top_z := _get_cell_top_z(cell)
		var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
		var k_band: int = 0 if k_ratio < 0.60 else (1 if k_ratio < 0.85 else 2)
		var lens_band := _compute_lens_band(cell)

		var col_key: Array = [
			_built_yaw,
			_built_pitch,
			eff_biome,
			top_z,
			active_lens,
			k_band,
			lens_band,
			_coast_dirs[hex_id],
			_diff_biome_dirs[hex_id],
			cell.land_use,
			cell.owner_deme_id,
			cell.has_ruins
		]

		if not _column_state_cache.has(hex_id) or _column_state_cache[hex_id] != col_key:
			_column_state_cache[hex_id] = col_key
			_columns[hex_id].queue_redraw()
			_water_fx[hex_id].queue_redraw()


func _compute_lens_band(cell: EvoTypes.HexCell) -> int:
	if active_lens == "food":
		return int(roundf(clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0) * 50.0))
	if active_lens == "health":
		if not cell.deme_ids.is_empty() and world_state.demes.has(cell.deme_ids[0]):
			var d: EvoTypes.Deme = world_state.demes[cell.deme_ids[0]]
			return (1000 if d.infection_turns > 0 else 0) + (500 if d.immunity_turns > 0 else 0) + int(roundf(d.salubrity * 100.0))
		return -1
	if active_lens == "diplomacy" or active_lens == "territory":
		if not cell.deme_ids.is_empty() and world_state.demes.has(cell.deme_ids[0]):
			var d: EvoTypes.Deme = world_state.demes[cell.deme_ids[0]]
			return d.strategy_id.hash() ^ (1 if EvoTypes._is_side_b_deme(world_state, d) else 2)
		if (cell.land_use == "crops" or cell.land_use == "pasture") and cell.owner_deme_id != "" and world_state.demes.has(cell.owner_deme_id):
			var owner: EvoTypes.Deme = world_state.demes[cell.owner_deme_id]
			return owner.strategy_id.hash() ^ (3 if EvoTypes._is_side_b_deme(world_state, owner) else 4)
		return 0
	return 0


func _compute_brush_hexes() -> Array[String]:
	if hovered_hex_id == "":
		return []
	return HexMath.get_brush_hex_ids(hovered_hex_id, brush_radius, world_state.cells)


func _update_brush() -> void:
	_brush_hexes = _compute_brush_hexes()
	_overlay_dirty = true
	_overlay_layer.queue_redraw()


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

func _draw_hex_column(column: Node2D, hex_id: String) -> void:
	EvoHexColumnRenderer.draw_hex_column(self, column, hex_id)


func _get_top_tint(cell: EvoTypes.HexCell, is_ocean: bool) -> Color:
	return EvoHexColumnRenderer.get_top_tint(self, cell, is_ocean)


func _draw_water_fx(fx: Node2D, hex_id: String) -> void:
	EvoHexColumnRenderer.draw_water_fx(self, fx, hex_id)


# ============================================================================
# DELEGATED LAYERS: NETWORK, ANIMATED PROPS & OVERLAY
# ============================================================================

func _draw_network() -> void:
	_last_network_cull_rect = _visible_world_rect.grow(HexMath.HEX_SIZE * 1.5) if _visible_world_rect.size != Vector2.ZERO else Rect2()
	for village in _villages:
		EvoPropFloraRenderer.draw_village_plaza(self, village)
	EvoRoadNetworkRenderer.draw_network_roads(self)


func _draw_animated() -> void:
	EvoRoadNetworkRenderer.draw_animated_roads(self)

	if highlighted_lineage_id != "":
		for village in _villages:
			if not bool(village["is_capital"]):
				continue
			var deme: EvoTypes.Deme = village["deme"]
			if deme.lineage_id == highlighted_lineage_id:
				var v_pos: Vector2 = village["pos"]
				if not _visible_world_rect.has_point(v_pos):
					continue
				var beam_col := Color(deme.color)
				beam_col.a = 0.28 + 0.10 * sin(_anim_time * 4.0)
				var beam_w := 44.0
				_anim_layer.draw_rect(Rect2(v_pos.x - beam_w * 0.5, v_pos.y - 180.0, beam_w, 180.0), beam_col, true)

	EvoPropFloraRenderer.draw_props(self)
	if world_state == null or _villages.is_empty():
		return

	var season_gain := 1.0 if world_state.season == "dry_cold" else 0.52
	var lens_gain := 1.0 if active_lens == "biome" else 0.40
	for village in _villages:
		var v_pos: Vector2 = village["pos"]
		if not _visible_world_rect.has_point(v_pos):
			continue
		var tier := int(village["tier"])
		var phase := v_pos.x * 0.037 + v_pos.y * 0.053
		var flicker := 1.0 + 0.11 * sin(_anim_time * 6.7 + phase) + 0.06 * sin(_anim_time * 13.3 + phase * 1.7)
		var dim_gain := 0.35 if bool(village["is_dimmed"]) else 1.0
		var intensity := season_gain * lens_gain * dim_gain * flicker
		var base_r := (88.0 + float(tier) * 14.0) * (1.0 + (flicker - 1.0) * 0.22)
		var glow_center := v_pos + Vector2(0.0, -4.0)
		var hearth_center := v_pos + (Vector2(0.0, 20.0) if tier >= 4 else Vector2(0.0, 2.0))
		_anim_layer.draw_circle(glow_center, base_r, Color(1.0, 0.60, 0.16, 0.030 * intensity))
		_anim_layer.draw_circle(glow_center, base_r * 0.68, Color(1.0, 0.69, 0.24, 0.036 * intensity))
		_anim_layer.draw_circle(glow_center, base_r * 0.42, Color(1.0, 0.78, 0.34, 0.044 * intensity))
		_anim_layer.draw_circle(hearth_center, 26.0 * (0.94 + 0.06 * flicker), Color(1.0, 0.88, 0.48, 0.052 * intensity))


func _draw_overlay() -> void:
	_overlay_dirty = false
	EvoWorldOverlayRenderer.draw_overlay(self)


func _get_village_building_layout(
	tier: int,
	has_culture: bool = false,
	cultural_count: int = 0,
	archetype: String = "forage"
) -> Array[Dictionary]:
	return EvoPropFloraRenderer.get_village_building_layout(tier, has_culture, cultural_count, archetype)


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


func _is_edge_ping_entry(entry: Dictionary, hex_id: String) -> bool:
	if entry.has("is_edge_ping") and bool(entry["is_edge_ping"]):
		return true
	if hex_id == "" or not _hex_centers.has(hex_id):
		return false
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)
	var safe_rect := Rect2(Vector2.ZERO, vp_size).grow(-36.0)
	var screen_hex_pos := _world_layer.transform * (_hex_centers[hex_id] as Vector2)
	if safe_rect.has_point(screen_hex_pos):
		return false
	return is_equal_approx((entry["rect"] as Rect2).size.y, 30.0) or not Rect2(Vector2.ZERO, vp_size).grow(64.0).has_point(screen_hex_pos)


func _focus_camera_on_hex(hex_id: String) -> void:
	if camera == null or world_state == null or not world_state.cells.has(hex_id):
		return
	var cell: EvoTypes.HexCell = world_state.cells[hex_id]
	var focus_alt := maxf(cell.altitude, world_state.sea_level) if cell.biome == "ocean" else cell.altitude
	camera.focus_on_hex(cell.q, cell.r, focus_alt)


func _pick_hex_at(screen_pos: Vector2) -> String:
	var world_pos := _world_layer.transform.affine_inverse() * screen_pos
	for i in range(_sorted_hex_ids.size() - 1, -1, -1):
		var hex_id := _sorted_hex_ids[i]
		var pos: Vector2 = _hex_centers.get(hex_id, world_pos)
		if absf(world_pos.x - pos.x) > 210.0 or absf(world_pos.y - pos.y) > 242.0:
			continue
		if Geometry2D.is_point_in_polygon(world_pos, _hex_polys[hex_id]):
			return hex_id
	return ""
