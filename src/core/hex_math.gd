class_name HexMath
extends RefCounted

const HEX_SIZE: float = 240.0
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1)
]
static var _grid37_neighbors: Dictionary = {}
static var _grid91_neighbors: Dictionary = {}

static func make_id(q: int, r: int) -> String:
	return "%d,%d" % [q, r]

static func parse_id(hex_id: String) -> Vector2i:
	var parts := hex_id.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var s1 := -q1 - r1
	var s2 := -q2 - r2
	return int((abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2)

static func get_neighbor_ids(q: int, r: int, valid_cells: Dictionary) -> Array[String]:
	var cell_count := valid_cells.size()
	if cell_count == 91:
		var ikey91: int = (q + 8) * 16 + (r + 8)
		if _grid91_neighbors.has(ikey91):
			return _grid91_neighbors[ikey91]
		var cached91: Array[String] = []
		for dir in DIRECTIONS:
			var nid := "%d,%d" % [q + dir.x, r + dir.y]
			if valid_cells.has(nid):
				cached91.append(nid)
		if valid_cells.has("0,0") and valid_cells.has("5,0"):
			_grid91_neighbors[ikey91] = cached91
		return cached91
	if cell_count == 37:
		var ikey: int = (q + 8) * 16 + (r + 8)
		if _grid37_neighbors.has(ikey):
			return _grid37_neighbors[ikey]
		var cached: Array[String] = []
		for dir in DIRECTIONS:
			var nid := "%d,%d" % [q + dir.x, r + dir.y]
			if valid_cells.has(nid):
				cached.append(nid)
		if valid_cells.has("0,0") and valid_cells.has("3,0"):
			_grid37_neighbors[ikey] = cached
		return cached
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
	for cell_id in valid_cells.keys():
		var cid := str(cell_id)
		if cid == center_id:
			continue
		var coords := parse_id(cid)
		if hex_distance(center.x, center.y, coords.x, coords.y) <= radius - 1:
			result.append(cid)
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
		var dx := hex_size * 0.45
		var dy := hex_size * 0.14
		return Vector2(-dx if index == 0 else dx, -dy if index == 0 else dy)
	var angles := [-PI * 0.5, PI * 0.18, PI * 0.82]
	var sector := posmod(index, 3)
	var ang: float = angles[sector]
	var rad := hex_size * (0.48 if sector == 0 else 0.52)
	return Vector2(cos(ang) * rad, sin(ang) * rad)
