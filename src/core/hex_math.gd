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
static var _neighbor_caches_by_size: Dictionary = {}

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
	if cell_count in [37, 61, 91, 127, 169, 217] and absi(q) <= 15 and absi(r) <= 15 and valid_cells.has("0,0"):
		var ikey: int = (q + 16) * 32 + (r + 16)
		var size_cache: Dictionary
		if _neighbor_caches_by_size.has(cell_count):
			size_cache = _neighbor_caches_by_size[cell_count] as Dictionary
			if size_cache.has(ikey):
				return size_cache[ikey]
		else:
			size_cache = {}
			_neighbor_caches_by_size[cell_count] = size_cache
		var cached: Array[String] = []
		for dir in DIRECTIONS:
			var nid := "%d,%d" % [q + dir.x, r + dir.y]
			if valid_cells.has(nid):
				cached.append(nid)
		size_cache[ikey] = cached
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
	var max_dist := radius - 1
	for dq in range(-max_dist, max_dist + 1):
		var r1 := maxi(-max_dist, -dq - max_dist)
		var r2 := mini(max_dist, -dq + max_dist)
		for dr in range(r1, r2 + 1):
			if dq == 0 and dr == 0:
				continue
			var cid := make_id(center.x + dq, center.y + dr)
			if valid_cells.has(cid):
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

static func compute_village_sector_offset(_index: int, _total_count: int, _hex_size: float = HEX_SIZE) -> Vector2:
	return Vector2.ZERO
