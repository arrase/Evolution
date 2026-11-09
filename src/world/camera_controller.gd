class_name EvoCameraController
extends Node2D

const MIN_PITCH_DEG: float = 28.0
const MAX_PITCH_DEG: float = 75.0
const DEFAULT_PITCH_DEG: float = 48.0
const DEFAULT_YAW_DEG: float = 0.0
const MIN_ZOOM: float = 0.12
const MAX_ZOOM: float = 3.00
const DEFAULT_ZOOM: float = 0.82
const DEFAULT_PAN: Vector2 = Vector2(-175.0, 26.0)
const MAX_PAN_RADIUS: float = 3800.0
const MAX_COLUMN_HEIGHT_PX: float = 96.0
const FULL_MAP_WORLD_SIZE: Vector2 = Vector2(6235.38, 4178.0)

var yaw_deg: float = DEFAULT_YAW_DEG
var pitch_deg: float = DEFAULT_PITCH_DEG
var zoom_level: float = DEFAULT_ZOOM
var pan_offset: Vector2 = DEFAULT_PAN

var _target_pitch_deg: float = DEFAULT_PITCH_DEG
var _target_zoom: float = DEFAULT_ZOOM
var _target_pan: Vector2 = DEFAULT_PAN

var active_tool: String = "inspect"
var _is_panning: bool = false
var _is_orbiting: bool = false
var _drag_last_pos: Vector2 = Vector2.ZERO


func is_dragging() -> bool:
	return _is_panning or _is_orbiting


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)


func _is_text_input_or_modal_active() -> bool:
	if get_viewport() != null:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return true
	var p := get_parent()
	if p != null and "hud" in p and p.hud != null:
		var hud: Control = p.hud
		if (
			(hud.lab_modal != null and hud.lab_modal.visible)
			or (hud.notebook_modal != null and hud.notebook_modal.visible)
			or (hud.tree_modal != null and hud.tree_modal.visible)
			or (hud._settings_popup != null and hud._settings_popup.visible)
			or (hud._missing_models_modal != null and hud._missing_models_modal.visible)
		):
			return true
	return false


func _process(delta: float) -> void:
	var pan_speed: float = 820.0 * delta

	if not _is_text_input_or_modal_active():
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			_target_pan.y += pan_speed
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			_target_pan.y -= pan_speed
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			_target_pan.x += pan_speed
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			_target_pan.x -= pan_speed

	clamp_target()

	var lerp_t: float = clampf(delta * 12.0, 0.0, 1.0)
	pan_offset = pan_offset.lerp(_target_pan, lerp_t)
	if _target_pan.distance_to(pan_offset) < 0.25:
		pan_offset = _target_pan
	zoom_level = lerpf(zoom_level, _target_zoom, lerp_t)
	if absf(_target_zoom - zoom_level) < 0.001:
		zoom_level = _target_zoom

	# Pitch changes force a geometry rebuild, so snap once visually settled
	# instead of easing asymptotically for dozens of frames. Yaw is locked at 0.0.
	pitch_deg = lerpf(pitch_deg, _target_pitch_deg, lerp_t)
	if absf(_target_pitch_deg - pitch_deg) < 0.05:
		pitch_deg = _target_pitch_deg
	yaw_deg = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _is_text_input_or_modal_active():
		_is_panning = false
		_is_orbiting = false
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var vp_center := (get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)) * 0.5
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(0.14, mb.position - vp_center)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(-0.14, mb.position - vp_center)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = mb.pressed
			_drag_last_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			_drag_last_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_last_pos = mb.position
				if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_ALT):
					_is_orbiting = true
				elif active_tool == "inspect":
					_is_panning = true
			else:
				_is_panning = false
				_is_orbiting = false

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var delta_pos: Vector2 = mm.position - _drag_last_pos
		_drag_last_pos = mm.position
		if _is_orbiting:
			_target_pitch_deg = clampf(_target_pitch_deg - delta_pos.y * 0.25, MIN_PITCH_DEG, MAX_PITCH_DEG)
			yaw_deg = 0.0
			pitch_deg = _target_pitch_deg
		elif _is_panning:
			_target_pan += delta_pos
			clamp_target()
			pan_offset = _target_pan

	elif event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		match ke.keycode:
			KEY_R:
				tilt_by(8.0)
			KEY_F, KEY_0, KEY_KP_0:
				apply_preset("fit")
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				zoom_by(0.20)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_by(-0.20)
			KEY_HOME:
				reset_camera()


# Pitch foreshortening of the ground plane. Zoom and pan are applied
# by the renderer as a node transform, so they never invalidate cached geometry.
func ground_transform() -> Transform2D:
	var sin_p := sin(deg_to_rad(pitch_deg))
	return Transform2D(
		Vector2(1.0, 0.0),
		Vector2(0.0, sin_p),
		Vector2.ZERO
	)


func height_scale() -> float:
	return cos(deg_to_rad(pitch_deg)) * 1.18


func get_depth(world_xy: Vector2, z_height: float) -> float:
	return world_xy.y + z_height * 0.02


func tilt_by(delta_deg: float) -> void:
	_target_pitch_deg = clampf(_target_pitch_deg + delta_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)


func set_pitch_preset(target_deg: float) -> void:
	_target_pitch_deg = clampf(target_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)


func fit_full_map() -> void:
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(1600.0, 960.0)
	var avail_w := maxf(320.0, vp.x - 420.0)
	var avail_h := maxf(240.0, vp.y - 210.0)
	var fit_zoom := clampf(
		minf(avail_w / FULL_MAP_WORLD_SIZE.x, avail_h / FULL_MAP_WORLD_SIZE.y),
		MIN_ZOOM,
		MAX_ZOOM
	)
	_target_zoom = fit_zoom
	zoom_level = fit_zoom
	_target_pan = Vector2.ZERO
	pan_offset = Vector2.ZERO


func apply_preset(preset_id: String) -> void:
	match preset_id:
		"fit", "map", "full":
			fit_full_map()
		"1", "low", "32":
			set_pitch_preset(32.0)
		"2", "mid", "48":
			set_pitch_preset(48.0)
		"3", "high", "68":
			set_pitch_preset(68.0)
		"4", "reset", "default":
			reset_camera()


func zoom_by(delta_zoom: float, pivot_screen_offset: Vector2 = Vector2.ZERO) -> void:
	var next_zoom := clampf(_target_zoom + delta_zoom, MIN_ZOOM, MAX_ZOOM)
	if absf(next_zoom - _target_zoom) < 0.0001:
		return
	var ratio := next_zoom / _target_zoom
	_target_pan = pivot_screen_offset + (_target_pan - pivot_screen_offset) * ratio
	_target_zoom = next_zoom
	clamp_target()


func reset_camera() -> void:
	_target_pitch_deg = DEFAULT_PITCH_DEG
	_target_zoom = DEFAULT_ZOOM
	_target_pan = DEFAULT_PAN


func focus_on_hex(q: int, r: int, altitude: float) -> void:
	var world_xy := HexMath.axial_to_world(q, r)
	var tier: float = clampf(ceilf(altitude * 10.0), 1.0, 10.0)
	var z_height: float = (tier / 10.0) * MAX_COLUMN_HEIGHT_PX
	var pitch_rad := deg_to_rad(_target_pitch_deg)

	var proj_offset := Vector2(
		world_xy.x * _target_zoom,
		(world_xy.y * sin(pitch_rad) - z_height * cos(pitch_rad) * 1.18) * _target_zoom
	)
	_target_pan = -proj_offset
	clamp_target()


func clamp_target() -> void:
	yaw_deg = 0.0
	_target_pitch_deg = clampf(_target_pitch_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)
	_target_zoom = clampf(_target_zoom, MIN_ZOOM, MAX_ZOOM)
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 960.0)
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(1600.0, 960.0)
	var half_vp := vp * 0.5
	var limit_x := (FULL_MAP_WORLD_SIZE.x * 0.5) * _target_zoom
	var limit_y := (FULL_MAP_WORLD_SIZE.y * 0.5) * _target_zoom
	if half_vp.x > limit_x:
		var slack_x := maxf(120.0, (half_vp.x - limit_x) * 0.65)
		_target_pan.x = clampf(_target_pan.x, -slack_x, slack_x)
		if not _is_panning:
			_target_pan.x = lerpf(_target_pan.x, 0.0, 0.25)
	if half_vp.y > limit_y:
		var slack_y := maxf(90.0, (half_vp.y - limit_y) * 0.65)
		_target_pan.y = clampf(_target_pan.y, -slack_y, slack_y)
		if not _is_panning:
			_target_pan.y = lerpf(_target_pan.y, 0.0, 0.25)
	var max_pan := MAX_PAN_RADIUS * maxf(1.0, _target_zoom / DEFAULT_ZOOM)
	if _target_pan.length() > max_pan:
		_target_pan = _target_pan.normalized() * max_pan
