class_name HexMath
extends RefCounted

const HEX_SIZE: float = 152.0
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1)
]

static func make_id(q: int, r: int) -> String:
	return "%d,%d" % [q, r]

static func parse_id(hex_id: String) -> Vector2i:
	var parts := hex_id.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var s1 := -q1 - r1
	var s2 := -q2 - r2
	return int((abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2)

static func get_neighbor_ids(q: int, r: int, valid_cells: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for dir in DIRECTIONS:
		var nid := make_id(q + dir.x, r + dir.y)
		if valid_cells.has(nid):
			result.append(nid)
	return result

static func get_brush_hex_ids(center_id: String, radius: int, valid_cells: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not valid_cells.has(center_id):
		return result
	result.append(center_id)
	if radius <= 1:
		return result
	var center := parse_id(center_id)
	for n_id in get_neighbor_ids(center.x, center.y, valid_cells):
		if not result.has(n_id):
			result.append(n_id)
	return result

static func generate_hex_spiral(radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		var r1: int = max(-radius, -q - radius)
		var r2: int = min(radius, -q + radius)
		for r in range(r1, r2 + 1):
			coords.append(Vector2i(q, r))
	return coords

static func axial_to_world(q: int, r: int, hex_size: float = HEX_SIZE) -> Vector2:
	# Pointy-top axial to 2D world coordinates
	var x: float = hex_size * sqrt(3.0) * (float(q) + float(r) * 0.5)
	var y: float = hex_size * 1.5 * float(r)
	return Vector2(x, y)

static func compute_village_sector_offset(index: int, total_count: int, hex_size: float = HEX_SIZE) -> Vector2:
	if total_count <= 1:
		return Vector2.ZERO
	if total_count == 2:
		var dx := hex_size * 0.44
		var dy := hex_size * 0.12
		return Vector2(-dx if index == 0 else dx, -dy if index == 0 else dy)
	var angles := [-PI * 0.5, PI * 0.18, PI * 0.82]
	var ang: float = angles[index % 3]
	var rad := hex_size * (0.46 if index % 3 == 0 else 0.50)
	return Vector2(cos(ang) * rad, sin(ang) * rad)
