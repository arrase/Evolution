class_name EvoCameraController
extends Node2D

const MIN_PITCH_DEG: float = 28.0
const MAX_PITCH_DEG: float = 75.0
const DEFAULT_PITCH_DEG: float = 48.0
const DEFAULT_YAW_DEG: float = 0.0
const MIN_ZOOM: float = 0.28
const MAX_ZOOM: float = 3.00
const DEFAULT_ZOOM: float = 0.82
const DEFAULT_PAN: Vector2 = Vector2(-175.0, 26.0)
const MAX_PAN_RADIUS: float = 3800.0
const MAX_COLUMN_HEIGHT_PX: float = 96.0

var yaw_deg: float = DEFAULT_YAW_DEG
var pitch_deg: float = DEFAULT_PITCH_DEG
var zoom_level: float = DEFAULT_ZOOM
var pan_offset: Vector2 = DEFAULT_PAN

var _target_yaw_deg: float = DEFAULT_YAW_DEG
var _target_pitch_deg: float = DEFAULT_PITCH_DEG
var _target_zoom: float = DEFAULT_ZOOM
var _target_pan: Vector2 = DEFAULT_PAN

var active_tool: String = "inspect"
var _is_panning: bool = false
var _is_orbiting: bool = false
var _drag_last_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	var pan_speed: float = 820.0 * delta

	var line_edit_focused := get_viewport() != null and get_viewport().gui_get_focus_owner() is LineEdit
	if not line_edit_focused:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			_target_pan.y += pan_speed
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			_target_pan.y -= pan_speed
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			_target_pan.x += pan_speed
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			_target_pan.x -= pan_speed

	_clamp_targets()

	var lerp_t: float = clampf(delta * 12.0, 0.0, 1.0)
	pan_offset = pan_offset.lerp(_target_pan, lerp_t)
	if _target_pan.distance_to(pan_offset) < 0.25:
		pan_offset = _target_pan
	zoom_level = lerpf(zoom_level, _target_zoom, lerp_t)
	if absf(_target_zoom - zoom_level) < 0.001:
		zoom_level = _target_zoom

	# Yaw/pitch changes force a geometry rebuild, so snap once visually settled
	# instead of easing asymptotically for dozens of frames.
	pitch_deg = lerpf(pitch_deg, _target_pitch_deg, lerp_t)
	if absf(_target_pitch_deg - pitch_deg) < 0.05:
		pitch_deg = _target_pitch_deg
	var yaw_diff: float = wrapf(_target_yaw_deg - yaw_deg, -180.0, 180.0)
	yaw_deg = _target_yaw_deg if absf(yaw_diff) < 0.05 else fposmod(yaw_deg + yaw_diff * lerp_t, 360.0)


func _unhandled_input(event: InputEvent) -> void:
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
			_target_yaw_deg = fposmod(_target_yaw_deg + delta_pos.x * 0.45, 360.0)
			_target_pitch_deg = clampf(_target_pitch_deg - delta_pos.y * 0.25, MIN_PITCH_DEG, MAX_PITCH_DEG)
			yaw_deg = _target_yaw_deg
			pitch_deg = _target_pitch_deg
		elif _is_panning:
			_target_pan += delta_pos
			_clamp_targets()
			pan_offset = _target_pan

	elif event is InputEventKey:
		if get_viewport() != null and get_viewport().gui_get_focus_owner() is LineEdit:
			return
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		match ke.keycode:
			KEY_Q:
				rotate_by(-18.0)
			KEY_E:
				rotate_by(18.0)
			KEY_R:
				tilt_by(8.0)
			KEY_F:
				tilt_by(-8.0)
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				zoom_by(0.20)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_by(-0.20)
			KEY_HOME:
				reset_camera()


# Yaw rotation + pitch foreshortening of the ground plane. Zoom and pan are applied
# by the renderer as a node transform, so they never invalidate cached geometry.
func ground_transform() -> Transform2D:
	var yaw_rad := deg_to_rad(yaw_deg)
	var sin_p := sin(deg_to_rad(pitch_deg))
	return Transform2D(
		Vector2(cos(yaw_rad), sin(yaw_rad) * sin_p),
		Vector2(-sin(yaw_rad), cos(yaw_rad) * sin_p),
		Vector2.ZERO
	)


func height_scale() -> float:
	return cos(deg_to_rad(pitch_deg)) * 1.18


func get_depth(world_xy: Vector2, z_height: float) -> float:
	var yaw_rad := deg_to_rad(yaw_deg)
	var rot_y: float = world_xy.x * sin(yaw_rad) + world_xy.y * cos(yaw_rad)
	return rot_y + z_height * 0.02


func rotate_by(delta_deg: float) -> void:
	_target_yaw_deg = fposmod(_target_yaw_deg + delta_deg, 360.0)


func tilt_by(delta_deg: float) -> void:
	_target_pitch_deg = clampf(_target_pitch_deg + delta_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)


func set_pitch_preset(target_deg: float) -> void:
	_target_pitch_deg = clampf(target_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)


func zoom_by(delta_zoom: float, pivot_screen_offset: Vector2 = Vector2.ZERO) -> void:
	var next_zoom := clampf(_target_zoom + delta_zoom, MIN_ZOOM, MAX_ZOOM)
	if absf(next_zoom - _target_zoom) < 0.0001:
		return
	var ratio := next_zoom / _target_zoom
	_target_pan = pivot_screen_offset + (_target_pan - pivot_screen_offset) * ratio
	_target_zoom = next_zoom
	_clamp_targets()


func reset_camera() -> void:
	_target_yaw_deg = DEFAULT_YAW_DEG
	_target_pitch_deg = DEFAULT_PITCH_DEG
	_target_zoom = DEFAULT_ZOOM
	_target_pan = DEFAULT_PAN


func focus_on_hex(q: int, r: int, altitude: float) -> void:
	var world_xy := HexMath.axial_to_world(q, r)
	var tier: float = clampf(ceilf(altitude * 10.0), 1.0, 10.0)
	var z_height: float = (tier / 10.0) * MAX_COLUMN_HEIGHT_PX
	var yaw_rad := deg_to_rad(_target_yaw_deg)
	var pitch_rad := deg_to_rad(_target_pitch_deg)
	var rot_x: float = world_xy.x * cos(yaw_rad) - world_xy.y * sin(yaw_rad)
	var rot_y: float = world_xy.x * sin(yaw_rad) + world_xy.y * cos(yaw_rad)

	var proj_offset := Vector2(
		rot_x * _target_zoom,
		(rot_y * sin(pitch_rad) - z_height * cos(pitch_rad) * 1.18) * _target_zoom
	)
	_target_pan = -proj_offset
	_clamp_targets()


func _clamp_targets() -> void:
	_target_pitch_deg = clampf(_target_pitch_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)
	_target_zoom = clampf(_target_zoom, MIN_ZOOM, MAX_ZOOM)
	var max_pan := MAX_PAN_RADIUS * maxf(1.0, _target_zoom / DEFAULT_ZOOM)
	if _target_pan.length() > max_pan:
		_target_pan = _target_pan.normalized() * max_pan
