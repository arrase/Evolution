class_name EvoPropFloraRenderer
extends RefCounted

const C_SELECTION := Color("#fde047")

const STATUS_COLORS: Dictionary = {
	"thriving": Color("#34d399"),
	"stable": Color("#38bdf8"),
	"struggling": Color("#fbbf24"),
	"starving": Color("#fb7185")
}

const NON_SWAYING_SPRITES: Array[String] = ["mossy_rock", "fallen_log", "rock_mountain", "tree_stump", "soil_crack", "ruins"]
const VILLAGER_POSES: Array[String] = ["villager_idle", "villager_walk1", "villager_walk2"]
const TRAVELER_ROAD_KINDS: Array[String] = ["collab", "bridge", "pact", "tribute", "merge", "symbiosis"]

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

const ARCHETYPE_STYLE_MAP: Dictionary = {
	"forage": "forage_lodge",
	"cooperate": "amphitheater_dome",
	"exchange": "twin_canopy_market",
	"dispute": "horned_war_keep",
	"war": "horned_war_keep",
	"raid": "horned_war_keep",
	"betrayal": "horned_war_keep",
	"overexploit": "furnace_rig",
	"migrate": "nomad_pavilion",
	"innovate": "astronomical_spire"
}

const TRAIT_MODULE_MAP: Dictionary = {
	"bio-encephalization": {"structure_type": "monolith", "color": "#38bdf8"},
	"bio-social-instinct": {"structure_type": "hearth_circle", "color": "#fb923c"},
	"bio-r-strategy": {"structure_type": "brood_totem", "color": "#a3e635"},
	"bio-k-strategy": {"structure_type": "terraced_sanctuary", "color": "#2dd4bf"},
	"cul-warrior-expansion": {"structure_type": "war_brazier", "color": "#ef4444"},
	"cul-communal-conservation": {"structure_type": "grove_shrine", "color": "#10b981"},
	"cul-interdeme-barter": {"structure_type": "caravan_depot", "color": "#f59e0b"},
	"cul-symbolic-storage": {"structure_type": "granary_silo", "color": "#eab308"},
	"cul-extraction-tools": {"structure_type": "lithic_workshop", "color": "#94a3b8"}
}


class Prop:
	var hex_id: String = ""
	var kind: String = ""
	var world_xy: Vector2
	var top_z: float
	var screen_offset: Vector2
	var anchor_offset: Vector2
	var foot: Vector2
	var y: float
	var scale_val: float = 1.0
	var texture: Texture2D = null
	var rect: Rect2
	var modulate: Color
	var trim_color: Color = Color.TRANSPARENT
	var primary_color: Color = Color.WHITE
	var sways: bool = false
	var sway_phase: float = 0.0
	var anim_step: int = 0

	func _init(p_kind: String, p_scale: float, anchor_y: float, p_modulate: Color, p_texture: Texture2D = null) -> void:
		kind = p_kind
		scale_val = p_scale
		texture = p_texture
		var base_sz := p_texture.get_size() if p_texture != null else Vector2(24.0, 28.0)
		var size := base_sz * p_scale
		anchor_offset = Vector2(size.x * 0.5, size.y * anchor_y)
		rect = Rect2(Vector2.ZERO, size)
		modulate = p_modulate

	func set_foot(p_foot: Vector2) -> void:
		foot = p_foot
		rect.position = p_foot - anchor_offset
		y = p_foot.y

	func project(ground: Transform2D, lift: float) -> void:
		set_foot(ground * world_xy + Vector2(0.0, -top_z * lift) + screen_offset)


static func resolve_deme_strategy_color(world_state: EvoTypes.WorldState, deme: EvoTypes.Deme) -> Color:
	var fallback := Color.from_string(deme.color, Color(0.88, 0.48, 0.37))
	if world_state != null and world_state.strategies_catalog.has(deme.strategy_id):
		var strategy: EvoTypes.StrategyDef = world_state.strategies_catalog[deme.strategy_id]
		return Color.from_string(strategy.color, fallback)
	return fallback


static func resolve_dominant_archetype(state: EvoTypes.WorldState, deme: EvoTypes.Deme) -> String:
	if state != null and state.decisions_catalog.has(deme.last_dominant_decision_id):
		var dec: EvoTypes.DecisionDef = state.decisions_catalog[deme.last_dominant_decision_id]
		return dec.archetype
	var did := deme.last_dominant_decision_id
	if did.contains("war"):
		return "war"
	if did.contains("raid"):
		return "raid"
	if did.contains("pact"):
		return "pact"
	if did.contains("betrayal"):
		return "betrayal"
	if did.contains("overexploit"):
		return "overexploit"
	if did.contains("migration") or did.contains("migrate"):
		return "migrate"
	if did.contains("cooperate"):
		return "cooperate"
	if did.contains("exchange"):
		return "exchange"
	if did.contains("dispute"):
		return "dispute"
	if did.contains("innovate"):
		return "innovate"
	return "forage"


static func get_deme_dominant_archetype(r: Node2D, deme: EvoTypes.Deme) -> String:
	return resolve_dominant_archetype(r.world_state if r != null else null, deme)


static func build_settlement_morphology(
	deme: EvoTypes.Deme,
	cell: EvoTypes.HexCell,
	state: EvoTypes.WorldState,
	lang: String = "es"
) -> Dictionary:
	var arch := resolve_dominant_archetype(state, deme)
	var tier := deme.get_village_tier()
	var vital_status := deme.get_vital_status()
	var style: String = ARCHETYPE_STYLE_MAP.get(arch, "forage_lodge")

	var raw_traits: Array[Dictionary] = []
	for tid in deme.biological_trait_ids:
		if raw_traits.size() >= 6:
			break
		raw_traits.append({"trait_id": tid, "category": "biological"})
	for tid in deme.cultural_trait_ids:
		if raw_traits.size() >= 6:
			break
		raw_traits.append({"trait_id": tid, "category": "cultural"})

	var ring_1_traits: Array[Dictionary] = []
	var t_count := raw_traits.size()
	for i in range(t_count):
		var entry: Dictionary = raw_traits[i]
		var tid: String = entry["trait_id"]
		var cat: String = entry["category"]
		var spec: Dictionary
		if TRAIT_MODULE_MAP.has(tid):
			spec = TRAIT_MODULE_MAP[tid]
		elif tid.begins_with("emergent-"):
			spec = {"structure_type": "crystal_obelisk", "color": "#c084fc"}
		elif cat == "biological":
			spec = {"structure_type": "monolith", "color": "#34d399"}
		else:
			spec = {"structure_type": "grove_shrine", "color": "#f472b6"}
		var color_str := str(spec["color"])
		var color_val := Color.from_string(color_str, Color("#38bdf8"))
		var t_label := tid
		if state != null and state.traits_catalog.has(tid):
			t_label = EvoI18n.trait_name(lang, state.traits_catalog[tid])
		if t_label.length() > 13:
			t_label = t_label.substr(0, 12) + "…"
		ring_1_traits.append({
			"angle_deg": fmod(float(i) * (360.0 / float(maxi(1, t_count))) + 32.0, 360.0),
			"trait_id": tid,
			"category": cat,
			"structure_type": str(spec["structure_type"]),
			"color": color_str,
			"trait_color": color_val,
			"trait_label": t_label
		})

	var wall_type := "none"
	if deme.defense_tier == 1:
		wall_type = "palisade"
	elif deme.defense_tier == 2:
		wall_type = "stone_wall"
	elif deme.defense_tier >= 3:
		wall_type = "fortress_bastion"

	var k_ratio := clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0) if cell != null else 1.0
	var res_ratio := clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity), 0.0, 1.5) if cell != null else 1.0

	return {
		"deme_id": deme.id,
		"hex_id": cell.id if cell != null else deme.hex_id,
		"tier": tier,
		"archetype": arch,
		"vital_status": vital_status,
		"defense_tier": deme.defense_tier,
		"is_merged": deme.merged_count > 0,
		"ring_0_core": {
			"archetype": arch,
			"tier": tier,
			"style": style,
			"vital_status": vital_status
		},
		"ring_1_traits": ring_1_traits,
		"ring_2_defense": {
			"defense_tier": deme.defense_tier,
			"wall_type": wall_type
		},
		"biome_vitality": {
			"k_ratio": k_ratio,
			"res_ratio": res_ratio,
			"degraded": k_ratio < 0.75
		}
	}


static func collect_villages(r: Node2D) -> Array[Dictionary]:
	var villages: Array[Dictionary] = []
	var state: EvoTypes.WorldState = r.world_state
	var geo_by_deme := build_geopolitics_by_deme(state)
	var hex_list: Array = r._sorted_hex_ids if not r._sorted_hex_ids.is_empty() else state.cells.keys()
	for hex_id in hex_list:
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		if r._is_water(cell) or cell.deme_ids.is_empty():
			continue
		var deme_id: String = cell.deme_ids[0]
		if not state.demes.has(deme_id):
			continue
		var deme: EvoTypes.Deme = state.demes[deme_id]
		var world_xy := HexMath.axial_to_world(cell.q, cell.r)
		var v_world := world_xy
		var scale_factor := 1.0
		var top_z: float = r._get_cell_top_z(cell)
		var is_dimmed: bool = r.highlighted_lineage_id != "" and deme.lineage_id != r.highlighted_lineage_id
		var tier := deme.get_village_tier()
		var strat_vis := EvoWorldOverlayRenderer._resolve_deme_strategy_visuals(state, deme, r.lang)
		var strat_color: Color = strat_vis["color"]

		var sub_text := "%d pop" % deme.population if r.lang == "en" else "%d hab" % deme.population
		var v_pos: Vector2 = r._project(v_world, top_z)
		var vital_status := deme.get_vital_status()
		var status_col: Color = STATUS_COLORS[vital_status] if STATUS_COLORS.has(vital_status) else Color("#38bdf8")
		var geo: Dictionary = geo_by_deme[deme.id] if geo_by_deme.has(deme.id) else resolve_deme_geopolitics(state, deme)
		var morphology := build_settlement_morphology(deme, cell, state, r.lang)

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
			"archetype": morphology["archetype"],
			"morphology": morphology,
			"has_pact": geo["has_pact"],
			"in_war": geo["in_war"],
			"in_raid": geo["in_raid"],
			"in_betrayal": geo["in_betrayal"],
			"in_tribute": geo["in_tribute"],
			"in_siege": geo["in_siege"],
			"in_merge": geo["in_merge"],
			"geo_icons": geo["geo_icons"],
			"status_col": status_col,
			"strat_visuals": strat_vis,
			"strat_color": strat_color,
			"strategy_color": strat_color,
			"secondary_color": Color.from_string(deme.secondary_color, Color("#fbbf24")),
			"villager_count": clampi(2 + tier + int(deme.population / 110), 3, 7),
			"sub_text": sub_text,
			"hit_rect": Rect2(v_pos - Vector2(36, 32) * scale_factor, Vector2(72, 56) * scale_factor)
		})
	return villages


static func get_village_building_layout(
	tier: int,
	sf: float,
	has_culture: bool,
	cultural_count: int,
	archetype: String
) -> Array[Dictionary]:
	var items: Array[Dictionary] = [
		{"sprite": "act_" + archetype, "offset": Vector2(0, -12) * sf, "scale": (2.2 + float(tier) * 0.12) * sf}
	]
	if has_culture and cultural_count > 0:
		items.append({"sprite": "cultural_totem", "offset": Vector2(-42, 20) * sf, "scale": 2.1 * sf})
	return items


static func draw_village_plaza(r: Node2D, village: Dictionary) -> void:
	var ci: Node2D = r._network_layer
	var deme: EvoTypes.Deme = village["deme"]
	var morphology: Dictionary = village["morphology"]
	var sf: float = village["sf"]
	var modulate_col: Color = village["modulate"]
	var status_col: Color = village["status_col"]
	var v_pos: Vector2 = village["pos"]
	var plaza_center: Vector2 = v_pos + Vector2(0.0, 6.0 * sf)
	var strat_color: Color = village["strategy_color"]
	var strat_hi := strat_color.lightened(0.28)
	var def_tier: int = deme.defense_tier
	var is_merged: bool = deme.merged_count > 0
	var tier: int = int(morphology["tier"])
	var arch: String = str(morphology["archetype"])
	var vital_status: String = str(morphology["vital_status"])
	var weights: Vector3 = r.get_zoom_tier_weights()

	# Outer earthen terrace pad
	var plinth_r := (56.0 if is_merged else 51.0) * sf
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r + 16.0 * sf, (plinth_r + 16.0 * sf) * 0.58, Color(0.28, 0.20, 0.13, 0.36) * modulate_col)

	# Ring 2: Defense Perimeter (palisade / stone_wall / fortress_bastion)
	_draw_ring_2_defense(ci, plaza_center, plinth_r + 10.0 * sf, def_tier, strat_color, modulate_col, sf)

	# Ring 0: Central stone plaza & strategy mosaic
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r + 4.0 * sf, (plinth_r + 4.0 * sf) * 0.58, Color("#4d3522") * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r, plinth_r * 0.58, Color("#bfa074") * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r * 0.78, plinth_r * 0.78 * 0.58, Color("#d8be98") * modulate_col)

	if is_merged:
		var sec_col: Color = village["secondary_color"]
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, plinth_r * 0.86, plinth_r * 0.86 * 0.58, sec_col * modulate_col, 2.8 * sf)

	# Inner Strategy Mosaic Carpet Ring
	var mosaic_r := plinth_r * 0.54
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, mosaic_r, mosaic_r * 0.58, strat_color.darkened(0.26) * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, mosaic_r * 0.70, mosaic_r * 0.70 * 0.58, strat_color * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, mosaic_r, mosaic_r * 0.58, strat_hi * modulate_col, 2.0 * sf)

	# Vital status ring
	var status_ring_r := plinth_r + (13.5 if def_tier > 0 else 5.5) * sf
	EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, status_ring_r, status_ring_r * 0.58, status_col * modulate_col, 3.0)

	# Ring 1: Radial Trait Crown structures (visible in Meso & Micro, full fidelity when micro_w > 0.05)
	var trait_vis := clampf(weights.y * 0.85 + weights.z * 1.0, 0.0, 1.0)
	if trait_vis > 0.05:
		var ring_1_traits: Array = morphology["ring_1_traits"]
		var ring1_rx := (plinth_r * 0.84) * sf
		var ring1_ry := ring1_rx * 0.58
		for t_mod in ring_1_traits:
			var ang := deg_to_rad(float(t_mod["angle_deg"]) - 90.0)
			var t_pos := plaza_center + Vector2(cos(ang) * ring1_rx, sin(ang) * ring1_ry)
			ci.draw_line(plaza_center.lerp(t_pos, 0.35), t_pos, Color("#8c6d46") * modulate_col, 3.0 * sf)
			_draw_ring_1_trait_module(ci, t_pos, str(t_mod["structure_type"]), t_mod["trait_color"] as Color, sf * (0.82 + 0.18 * weights.z), modulate_col)

	# Ring 0: Central Archetype Citadel / Hall
	_draw_ring_0_citadel(ci, plaza_center + Vector2(0.0, -4.0 * sf), arch, tier, vital_status, strat_color, strat_hi, modulate_col, sf)

	# Strategy Pennant Flag Pole
	var pole_base := plaza_center + Vector2(-24.0 * sf, 4.0 * sf)
	var pole_top := pole_base + Vector2(0.0, -28.0 * sf)
	ci.draw_line(pole_base, pole_top, Color("#4a2810") * modulate_col, 2.8 * sf)
	ci.draw_circle(pole_top, 2.4 * sf, Color("#fbbf24") * modulate_col)
	var wave := sin(v_pos.x * 0.04) * 2.2 * sf
	ci.draw_colored_polygon(PackedVector2Array([
		pole_top + Vector2(1.0 * sf, 1.0 * sf),
		pole_top + Vector2(18.0 * sf, 4.5 * sf + wave),
		pole_top + Vector2(1.0 * sf, 10.5 * sf)
	]), strat_color * modulate_col)

	if bool(village["in_siege"]):
		var siege_r := status_ring_r + 6.0 * sf
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, siege_r, siege_r * 0.58, Color(0.98, 0.32, 0.12, 0.85) * modulate_col, 3.2 * sf)

	if deme.id == r.selected_deme_id:
		var sel_r := status_ring_r + 5.5 * sf
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, sel_r, sel_r * 0.58, C_SELECTION, 4.0)
	elif deme.id == r.hovered_deme_id:
		var hov_r := status_ring_r + 4.5 * sf
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, hov_r, hov_r * 0.58, Color(1.0, 0.92, 0.68, 0.88), 2.6)


static func _draw_ring_2_defense(
	ci: CanvasItem,
	center: Vector2,
	def_r: float,
	def_tier: int,
	strat_color: Color,
	mod_col: Color,
	sf: float
) -> void:
	if def_tier <= 0:
		return
	var ry := def_r * 0.58
	if def_tier == 1:
		# Timber Palisade Ring
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, center, def_r, ry, Color("#5c3317") * mod_col, 3.6 * sf)
		for i in range(24):
			var ang := TAU * float(i) / 24.0
			if absf(ang - PI * 0.5) < 0.22:
				continue
			var base := center + Vector2(cos(ang) * def_r, sin(ang) * ry)
			var top := base + Vector2(0.0, -7.0 * sf)
			ci.draw_line(base, top, Color("#78350f") * mod_col, 2.6 * sf)
			ci.draw_circle(top, 1.4 * sf, Color("#fde68a") * mod_col)
	elif def_tier == 2:
		# Crenellated Stone Rampart Ring
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, center, def_r, ry, Color("#334155") * mod_col, 6.2 * sf)
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, center, def_r, ry, Color("#94a3b8") * mod_col, 3.6 * sf)
		for i in range(20):
			var ang := TAU * float(i) / 20.0
			if absf(ang - PI * 0.5) < 0.22:
				continue
			var pt := center + Vector2(cos(ang) * def_r, sin(ang) * ry) + Vector2(0.0, -2.5 * sf)
			ci.draw_rect(Rect2(pt - Vector2(2.2 * sf, 2.2 * sf), Vector2(4.4 * sf, 3.8 * sf)), Color("#cbd5e1") * mod_col, true)
	else:
		# Tier 3 Bastioned Fortress Wall with 6 Corner Towers
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, center, def_r, ry, Color("#1e293b") * mod_col, 7.8 * sf)
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, center, def_r, ry, Color("#94a3b8") * mod_col, 4.6 * sf)
		for i in range(24):
			var ang := TAU * float(i) / 24.0
			if absf(ang - PI * 0.5) < 0.20:
				continue
			var pt := center + Vector2(cos(ang) * def_r, sin(ang) * ry) + Vector2(0.0, -2.8 * sf)
			ci.draw_rect(Rect2(pt - Vector2(2.4 * sf, 2.4 * sf), Vector2(4.8 * sf, 4.2 * sf)), Color("#e2e8f0") * mod_col, true)
		for t_i in range(6):
			var b_ang := deg_to_rad(float(t_i) * 60.0 - 30.0)
			var b_pt := center + Vector2(cos(b_ang) * def_r, sin(b_ang) * ry)
			ci.draw_circle(b_pt, 6.8 * sf, Color("#334155") * mod_col)
			ci.draw_circle(b_pt + Vector2(0.0, -3.0 * sf), 5.2 * sf, Color("#cbd5e1") * mod_col)
			ci.draw_circle(b_pt + Vector2(0.0, -4.5 * sf), 3.4 * sf, strat_color * mod_col)
			ci.draw_circle(b_pt + Vector2(0.0, -5.5 * sf), 1.6 * sf, Color("#fbbf24") * mod_col)


static func _draw_ring_0_citadel(
	ci: CanvasItem,
	pos: Vector2,
	arch: String,
	tier: int,
	vital_status: String,
	strat_color: Color,
	strat_hi: Color,
	mod_col: Color,
	sf: float
) -> void:
	var t_scale := (0.88 + float(clampi(tier, 1, 5)) * 0.10) * sf
	# Flanking wing pavilions for higher tiers
	if tier >= 2:
		var w_off := Vector2(20.0 * t_scale, 4.0 * t_scale)
		for side in [-1.0, 1.0]:
			if side > 0.0 and tier < 3:
				continue
			var wp := pos + Vector2(w_off.x * side, w_off.y)
			ci.draw_rect(Rect2(wp - Vector2(7.0, 10.0) * t_scale, Vector2(14.0, 11.0) * t_scale), Color("#7c5c3b") * mod_col, true)
			ci.draw_colored_polygon(PackedVector2Array([
				wp + Vector2(-9.0, -9.0) * t_scale,
				wp + Vector2(0.0, -17.0) * t_scale,
				wp + Vector2(9.0, -9.0) * t_scale
			]), strat_color.darkened(0.18) * mod_col)

	match arch:
		"cooperate":
			# Concentric Amphitheater Dome
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos, 18.0 * t_scale, 11.0 * t_scale, Color("#e2e8f0") * mod_col)
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos + Vector2(0.0, -5.0 * t_scale), 14.0 * t_scale, 9.0 * t_scale, strat_color * mod_col)
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos + Vector2(0.0, -9.0 * t_scale), 8.5 * t_scale, 5.5 * t_scale, strat_hi * mod_col)
			ci.draw_circle(pos + Vector2(0.0, -12.0 * t_scale), 3.0 * t_scale, Color("#fde047") * mod_col)
		"exchange":
			# Twin-Canopy Market Pavilion
			for side in [-1.0, 1.0]:
				var mp := pos + Vector2(side * 8.5 * t_scale, 0.0)
				ci.draw_rect(Rect2(mp - Vector2(6.5, 11.0) * t_scale, Vector2(13.0, 12.0) * t_scale), Color("#92400e") * mod_col, true)
				ci.draw_colored_polygon(PackedVector2Array([
					mp + Vector2(-9.0, -10.0) * t_scale,
					mp + Vector2(0.0, -20.0) * t_scale,
					mp + Vector2(9.0, -10.0) * t_scale
				]), (strat_color if side < 0.0 else strat_hi) * mod_col)
			ci.draw_line(pos + Vector2(-8.5, -15.0) * t_scale, pos + Vector2(8.5, -15.0) * t_scale, Color("#fbbf24") * mod_col, 2.4 * t_scale)
		"dispute", "war", "raid", "betrayal":
			# Horned Basalt War-Keep
			var keep_rect := Rect2(pos - Vector2(13.0, 18.0) * t_scale, Vector2(26.0, 20.0) * t_scale)
			ci.draw_rect(keep_rect, Color("#334155") * mod_col, true)
			ci.draw_rect(keep_rect, Color("#1e293b") * mod_col, false, 2.0)
			# Horned battlements
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-13.0, -18.0) * t_scale,
				pos + Vector2(-18.0, -28.0) * t_scale,
				pos + Vector2(-7.0, -18.0) * t_scale
			]), strat_color * mod_col)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(13.0, -18.0) * t_scale,
				pos + Vector2(18.0, -28.0) * t_scale,
				pos + Vector2(7.0, -18.0) * t_scale
			]), strat_color * mod_col)
			ci.draw_rect(Rect2(pos - Vector2(5.0, 9.0) * t_scale, Vector2(10.0, 11.0) * t_scale), Color("#ef4444") * mod_col, true)
		"overexploit":
			# Extraction Furnace Rig
			ci.draw_rect(Rect2(pos - Vector2(14.0, 15.0) * t_scale, Vector2(28.0, 17.0) * t_scale), Color("#451a03") * mod_col, true)
			ci.draw_rect(Rect2(pos + Vector2(-10.0, -26.0) * t_scale, Vector2(6.0, 14.0) * t_scale), Color("#57534e") * mod_col, true)
			ci.draw_rect(Rect2(pos + Vector2(4.0, -29.0) * t_scale, Vector2(6.0, 17.0) * t_scale), Color("#57534e") * mod_col, true)
			ci.draw_circle(pos + Vector2(0.0, -6.0 * t_scale), 5.0 * t_scale, Color("#f97316") * mod_col)
		"migrate":
			# Nomad Multi-Peaked Pavilion
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-17.0, 2.0) * t_scale,
				pos + Vector2(-7.0, -19.0) * t_scale,
				pos + Vector2(0.0, -12.0) * t_scale,
				pos + Vector2(7.0, -21.0) * t_scale,
				pos + Vector2(17.0, 2.0) * t_scale
			]), strat_color * mod_col)
			ci.draw_polyline(PackedVector2Array([
				pos + Vector2(-17.0, 2.0) * t_scale,
				pos + Vector2(-7.0, -19.0) * t_scale,
				pos + Vector2(0.0, -12.0) * t_scale,
				pos + Vector2(7.0, -21.0) * t_scale,
				pos + Vector2(17.0, 2.0) * t_scale
			]), Color("#fef3c7") * mod_col, 2.0)
		"innovate":
			# Stepped Astronomical Spire
			ci.draw_rect(Rect2(pos - Vector2(14.0, 8.0) * t_scale, Vector2(28.0, 10.0) * t_scale), Color("#475569") * mod_col, true)
			ci.draw_rect(Rect2(pos - Vector2(10.0, 16.0) * t_scale, Vector2(20.0, 9.0) * t_scale), strat_color.darkened(0.2) * mod_col, true)
			ci.draw_rect(Rect2(pos - Vector2(6.0, 24.0) * t_scale, Vector2(12.0, 9.0) * t_scale), strat_color * mod_col, true)
			var apex := pos + Vector2(0.0, -29.0 * t_scale)
			ci.draw_arc(apex, 5.5 * t_scale, 0.0, TAU, 16, Color("#38bdf8") * mod_col, 1.8)
			ci.draw_circle(apex, 2.6 * t_scale, Color("#fde047") * mod_col)
		_:
			# Forage Timber & Thatch Lodge
			ci.draw_rect(Rect2(pos - Vector2(12.0, 12.0) * t_scale, Vector2(24.0, 14.0) * t_scale), Color("#78350f") * mod_col, true)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-16.0, -10.0) * t_scale,
				pos + Vector2(0.0, -24.0) * t_scale,
				pos + Vector2(16.0, -10.0) * t_scale
			]), strat_color * mod_col)
			ci.draw_polyline(PackedVector2Array([
				pos + Vector2(-16.0, -10.0) * t_scale,
				pos + Vector2(0.0, -24.0) * t_scale,
				pos + Vector2(16.0, -10.0) * t_scale
			]), Color("#fde68a") * mod_col, 2.0)

	# Vital status visual reflection: warm golden hearths when thriving, cracks/smoke when starving
	if vital_status == "thriving":
		ci.draw_circle(pos + Vector2(0.0, -3.0 * t_scale), 4.5 * t_scale, Color(1.0, 0.88, 0.25, 0.85) * mod_col)
		ci.draw_circle(pos + Vector2(0.0, -3.0 * t_scale), 2.5 * t_scale, Color("#fef08a") * mod_col)
	elif vital_status == "starving" or vital_status == "struggling":
		ci.draw_line(pos + Vector2(-6.0, -14.0) * t_scale, pos + Vector2(2.0, -4.0) * t_scale, Color("#1c1917") * mod_col, 2.0)
		ci.draw_circle(pos + Vector2(0.0, -26.0 * t_scale), 3.5 * sf, Color(0.2, 0.2, 0.22, 0.55) * mod_col)


static func _draw_ring_1_trait_module(
	ci: CanvasItem,
	pos: Vector2,
	structure_type: String,
	col: Color,
	sf: float,
	mod_col: Color
) -> void:
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos, 9.5 * sf, 5.8 * sf, Color("#57534e") * mod_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos, 7.5 * sf, 4.5 * sf, Color("#a8a29e") * mod_col)
	match structure_type:
		"monolith":
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-3.5, 1.0) * sf,
				pos + Vector2(-2.2, -15.0) * sf,
				pos + Vector2(0.0, -18.5) * sf,
				pos + Vector2(2.2, -15.0) * sf,
				pos + Vector2(3.5, 1.0) * sf
			]), Color("#1e293b") * mod_col)
			ci.draw_line(pos + Vector2(0.0, -2.0) * sf, pos + Vector2(0.0, -15.0) * sf, col * mod_col, 2.0 * sf)
		"hearth_circle":
			for i in range(6):
				var a := TAU * float(i) / 6.0
				ci.draw_circle(pos + Vector2(cos(a) * 5.2, sin(a) * 3.2) * sf, 2.0 * sf, Color("#78716c") * mod_col)
			ci.draw_circle(pos + Vector2(0.0, -2.5 * sf), 3.6 * sf, col * mod_col)
			ci.draw_circle(pos + Vector2(0.0, -2.5 * sf), 1.8 * sf, Color("#fef08a") * mod_col)
		"brood_totem":
			ci.draw_line(pos, pos + Vector2(0.0, -15.0 * sf), Color("#78350f") * mod_col, 4.2 * sf)
			ci.draw_circle(pos + Vector2(0.0, -6.0 * sf), 3.6 * sf, col * mod_col)
			ci.draw_circle(pos + Vector2(0.0, -12.0 * sf), 3.0 * sf, col.lightened(0.2) * mod_col)
		"terraced_sanctuary":
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos + Vector2(0.0, -2.0 * sf), 6.5 * sf, 3.8 * sf, col.darkened(0.25) * mod_col)
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos + Vector2(0.0, -5.0 * sf), 4.2 * sf, 2.5 * sf, col * mod_col)
		"war_brazier":
			ci.draw_line(pos + Vector2(-4.0, 1.0) * sf, pos + Vector2(0.0, -7.0) * sf, Color("#1e293b") * mod_col, 2.0 * sf)
			ci.draw_line(pos + Vector2(4.0, 1.0) * sf, pos + Vector2(0.0, -7.0) * sf, Color("#1e293b") * mod_col, 2.0 * sf)
			ci.draw_circle(pos + Vector2(0.0, -8.5 * sf), 4.0 * sf, col * mod_col)
			ci.draw_circle(pos + Vector2(0.0, -10.0 * sf), 2.2 * sf, Color("#fde047") * mod_col)
		"grove_shrine":
			ci.draw_line(pos, pos + Vector2(0.0, -9.0 * sf), Color("#78350f") * mod_col, 2.8 * sf)
			ci.draw_circle(pos + Vector2(0.0, -11.5 * sf), 5.8 * sf, col * mod_col)
			ci.draw_circle(pos + Vector2(-2.0, -13.0) * sf, 3.2 * sf, col.lightened(0.25) * mod_col)
		"caravan_depot":
			ci.draw_rect(Rect2(pos + Vector2(-5.5, -9.0) * sf, Vector2(11.0, 9.0) * sf), Color("#92400e") * mod_col, true)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-7.0, -9.0) * sf,
				pos + Vector2(0.0, -14.5) * sf,
				pos + Vector2(7.0, -9.0) * sf
			]), col * mod_col)
		"granary_silo":
			ci.draw_rect(Rect2(pos + Vector2(-4.2, -12.0) * sf, Vector2(8.4, 12.0) * sf), Color("#d6d3d1") * mod_col, true)
			ci.draw_circle(pos + Vector2(0.0, -12.0 * sf), 4.4 * sf, col * mod_col)
		"lithic_workshop":
			ci.draw_rect(Rect2(pos + Vector2(-5.0, -6.5) * sf, Vector2(10.0, 6.5) * sf), col * mod_col, true)
			ci.draw_line(pos + Vector2(-6.0, -6.5) * sf, pos + Vector2(6.0, -6.5) * sf, Color("#334155") * mod_col, 2.5 * sf)
		"crystal_obelisk":
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -2.0 * sf),
				pos + Vector2(-4.2 * sf, -10.0 * sf),
				pos + Vector2(0.0, -18.0 * sf),
				pos + Vector2(4.2 * sf, -10.0 * sf)
			]), col * mod_col)
			ci.draw_circle(pos + Vector2(0.0, -10.0 * sf), 2.0 * sf, Color.WHITE * mod_col)
		_:
			ci.draw_circle(pos + Vector2(0.0, -7.0 * sf), 4.5 * sf, col * mod_col)


static func compute_cell_flora_key(r: Node2D, cell: EvoTypes.HexCell, top_z: float) -> Array:
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var k_band: int = 0 if k_ratio < 0.75 else (1 if k_ratio < 0.90 else 2)
	var v_count := cell.deme_ids.size()
	return [cell.biome, top_z, v_count, k_band, r._built_yaw, r._built_pitch]


static func collect_static_props(r: Node2D) -> Array[Prop]:
	var state: EvoTypes.WorldState = r.world_state
	var hex_list: Array = r._sorted_hex_ids if not r._sorted_hex_ids.is_empty() else state.cells.keys()
	var cam_vec := Vector2(r._built_yaw, r._built_pitch)
	var full_flora_rebuild: bool = (
		not r._cell_flora_cache.has("__sorted_flora__")
		or r._cell_flora_cache.get("__flora_cam__", Vector2.INF) != cam_vec
	)
	var changed_hexes: Dictionary = {}
	for hex_id in hex_list:
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		if r._is_water(cell):
			if r._cell_flora_cache.has(hex_id):
				r._cell_flora_cache.erase(hex_id)
				changed_hexes[hex_id] = true
			continue
		var top_z: float = r._get_cell_top_z(cell)
		var flora_key := compute_cell_flora_key(r, cell, top_z)
		if not r._cell_flora_cache.has(hex_id) or (r._cell_flora_cache[hex_id]["key"] as Array) != flora_key:
			changed_hexes[hex_id] = true
			var world_xy := HexMath.axial_to_world(cell.q, cell.r)
			var cell_props: Array[Prop] = []
			collect_cell_flora_props(r, cell, world_xy, top_z, cell_props)
			for cp in cell_props:
				cp.hex_id = hex_id
				cp.project(r._ground, r._lift)
			cell_props.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
			r._cell_flora_cache[hex_id] = {"key": flora_key, "props": cell_props}

	var flora_sorted: Array[Prop] = []
	if full_flora_rebuild or not changed_hexes.is_empty():
		for hex_id in hex_list:
			var cell: EvoTypes.HexCell = state.cells[hex_id]
			if r._is_water(cell):
				continue
			if r._cell_flora_cache.has(hex_id):
				flora_sorted.append_array(r._cell_flora_cache[hex_id]["props"] as Array[Prop])
		flora_sorted.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
		r._cell_flora_cache["__sorted_flora__"] = flora_sorted
		r._cell_flora_cache["__flora_cam__"] = cam_vec
	else:
		flora_sorted = r._cell_flora_cache["__sorted_flora__"] as Array[Prop]

	var props: Array[Prop] = flora_sorted.duplicate()
	for hex_id in state.recent_extinction_hexes:
		if state.cells.has(hex_id):
			var cell: EvoTypes.HexCell = state.cells[hex_id]
			if not r._is_water(cell):
				var world_xy := HexMath.axial_to_world(cell.q, cell.r)
				var r_prop := world_prop("ruins", world_xy + Vector2(0, 12), r._get_cell_top_z(cell), Vector2.ZERO, 1.8, Color.WHITE)
				r_prop.project(r._ground, r._lift)
				props.append(r_prop)

	props.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	return props


static func collect_cell_flora_props(
	r: Node2D,
	cell: EvoTypes.HexCell,
	world_xy: Vector2,
	top_z: float,
	props: Array[Prop]
) -> void:
	var k_ratio: float = clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var base_count := 8
	if cell.biome == "tropical_forest":
		base_count = 12
	elif cell.biome == "savanna":
		base_count = 9
	elif cell.biome == "tundra":
		base_count = 8
	elif cell.biome == "coastal_shallows":
		base_count = 6

	var has_village := not cell.deme_ids.is_empty()
	var prop_count: int = clampi(int(round(float(base_count) * (0.55 + 0.45 * k_ratio))), 5, 12)
	if has_village:
		prop_count = clampi(prop_count - 2, 5, 9)

	var palette_sprites: Array = BIOME_FLORA_PALETTES.get(cell.biome, DEFAULT_FLORA_PALETTE)
	var base_seed: int = cell.q * 73856093 ^ cell.r * 19349663

	for idx in range(prop_count):
		var s1: int = absi(base_seed ^ ((idx * 13 + 1) * 83492791))
		var s2: int = absi(base_seed ^ ((idx * 29 + 7) * 83492791))
		var angle := (TAU * float(idx) / float(maxi(1, prop_count))) + float(s1 % 23 - 11) * 0.035
		var rad_norm := (0.66 + float(s2 % 16) * 0.01) if has_village else (0.32 + float(s2 % 44) * 0.01)
		var local_off := Vector2(cos(angle), sin(angle)) * (HexMath.HEX_SIZE * rad_norm)

		var sprite_key: String = palette_sprites[idx % palette_sprites.size()]
		var can_sway := true
		if k_ratio < 0.75:
			can_sway = false
			if idx % 3 == 0:
				sprite_key = "tree_stump"
			elif idx % 3 == 1:
				sprite_key = "soil_crack"
			else:
				sprite_key = "dry_scrub"

		var prop := world_prop(sprite_key, world_xy + local_off, top_z, Vector2.ZERO, 1.0 + float(s1 % 16) * 0.02, Color.WHITE)
		prop.sways = can_sway and not NON_SWAYING_SPRITES.has(sprite_key)
		prop.sway_phase = float(idx) * 0.9 + float(cell.q)
		props.append(prop)


static func build_geopolitics_by_deme(state: EvoTypes.WorldState) -> Dictionary:
	var geo_by_deme: Dictionary = {}
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		var empty_icons: Array[String] = []
		geo_by_deme[did] = {
			"has_pact": false,
			"in_war": false,
			"in_raid": false,
			"in_betrayal": false,
			"in_tribute": false,
			"in_siege": false,
			"in_merge": d.merged_count > 0,
			"geo_icons": empty_icons
		}
	for pk_var in state.active_pacts.keys():
		if int(state.active_pacts[pk_var]) >= 2:
			var pk := str(pk_var)
			var sep := "__" if pk.contains("__") else "|"
			var parts := pk.split(sep)
			if parts.size() == 2 and geo_by_deme.has(parts[0]) and geo_by_deme.has(parts[1]):
				geo_by_deme[parts[0]]["has_pact"] = true
				geo_by_deme[parts[1]]["has_pact"] = true
	for flow in state.active_flows:
		var ft := flow.flow_type
		if not ft in ["war", "raid", "betrayal", "pact", "tribute", "siege", "merge"]:
			continue
		var flag_key := "has_pact" if ft == "pact" else ("in_" + ft)
		if flow.from_deme_id != "" or flow.to_deme_id != "":
			if geo_by_deme.has(flow.from_deme_id):
				geo_by_deme[flow.from_deme_id][flag_key] = true
			if geo_by_deme.has(flow.to_deme_id):
				geo_by_deme[flow.to_deme_id][flag_key] = true
		else:
			if state.cells.has(flow.from_hex_id):
				for did in (state.cells[flow.from_hex_id] as EvoTypes.HexCell).deme_ids:
					if geo_by_deme.has(did):
						geo_by_deme[did][flag_key] = true
			if state.cells.has(flow.to_hex_id):
				for did in (state.cells[flow.to_hex_id] as EvoTypes.HexCell).deme_ids:
					if geo_by_deme.has(did):
						geo_by_deme[did][flag_key] = true
	for did in geo_by_deme.keys():
		var d: EvoTypes.Deme = state.demes[did]
		var entry: Dictionary = geo_by_deme[did]
		var icons: Array[String] = entry["geo_icons"]
		if d.defense_tier > 0:
			icons.append("defense")
		if d.merged_count > 0 or bool(entry["in_merge"]):
			icons.append("merge")
		if bool(entry["in_siege"]):
			icons.append("siege")
		if bool(entry["in_war"]):
			icons.append("war")
		if bool(entry["in_betrayal"]):
			icons.append("betrayal")
		if bool(entry["in_raid"]):
			icons.append("raid")
		if bool(entry["in_tribute"]):
			icons.append("tribute")
		if bool(entry["has_pact"]):
			icons.append("pact")
	return geo_by_deme


static func resolve_deme_geopolitics(state: EvoTypes.WorldState, deme: EvoTypes.Deme) -> Dictionary:
	var all_geo := build_geopolitics_by_deme(state)
	if all_geo.has(deme.id):
		return all_geo[deme.id]
	return {
		"has_pact": false,
		"in_war": false,
		"in_raid": false,
		"in_betrayal": false,
		"in_tribute": false,
		"in_siege": false,
		"in_merge": deme.merged_count > 0,
		"geo_icons": []
	}


static func draw_props(r: Node2D) -> void:
	var moving := collect_moving_props(r)
	moving.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	var m_idx := 0
	var vis_rect: Rect2 = r._visible_world_rect
	for prop in r._static_props:
		if not vis_rect.intersects(prop.rect):
			continue
		while m_idx < moving.size() and moving[m_idx].y < prop.y:
			draw_prop(r, moving[m_idx])
			m_idx += 1
		draw_prop(r, prop)
	for i in range(m_idx, moving.size()):
		draw_prop(r, moving[i])


static func draw_prop(r: Node2D, prop: Prop) -> void:
	var ci: Node2D = r._anim_layer
	var pos := prop.foot
	if prop.sways:
		pos.x += sin(r._anim_time * 2.1 + prop.sway_phase) * 1.4
	var s := prop.scale_val
	var m := prop.modulate

	match prop.kind:
		"villager":
			var step_off := sin(float(prop.anim_step) * 2.1) * 1.5 * s
			ci.draw_circle(pos + Vector2(0.0, 1.0 * s), 3.2 * s, Color(0.0, 0.0, 0.0, 0.28) * m)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-3.2 * s, 0.0),
				pos + Vector2(-2.0 * s, -8.5 * s),
				pos + Vector2(2.0 * s, -8.5 * s),
				pos + Vector2(3.2 * s, 0.0)
			]), prop.primary_color * m)
			if prop.trim_color.a > 0.0:
				ci.draw_line(pos + Vector2(-2.6 * s, -3.5 * s), pos + Vector2(2.6 * s, -3.5 * s), prop.trim_color * m, 1.8 * s)
			ci.draw_circle(pos + Vector2(step_off * 0.3, -10.8 * s), 2.5 * s, Color("#fde68a") * m)
		"tree_tropical", "tree_tropical_2":
			ci.draw_circle(pos, 5.5 * s, Color(0.0, 0.0, 0.0, 0.22) * m)
			ci.draw_line(pos, pos + Vector2(0.0, -14.0 * s), Color("#5c3a21") * m, 3.2 * s)
			ci.draw_circle(pos + Vector2(0.0, -17.0 * s), 9.5 * s, Color("#15803d") * m)
			ci.draw_circle(pos + Vector2(-4.0 * s, -14.0 * s), 6.5 * s, Color("#16a34a") * m)
			ci.draw_circle(pos + Vector2(4.0 * s, -15.0 * s), 6.0 * s, Color("#22c55e") * m)
		"tree_savanna", "tree_savanna_2":
			ci.draw_circle(pos, 5.0 * s, Color(0.0, 0.0, 0.0, 0.20) * m)
			ci.draw_line(pos, pos + Vector2(0.0, -13.0 * s), Color("#6b4226") * m, 2.8 * s)
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos + Vector2(0.0, -15.0 * s), 12.0 * s, 5.0 * s, Color("#4d7c0f") * m)
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos + Vector2(1.5 * s, -16.5 * s), 8.5 * s, 3.5 * s, Color("#65a30d") * m)
		"tree_tundra", "tree_tundra_2":
			ci.draw_line(pos, pos + Vector2(0.0, -14.0 * s), Color("#4a2c18") * m, 2.6 * s)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-7.5 * s, -4.0 * s),
				pos + Vector2(0.0, -19.0 * s),
				pos + Vector2(7.5 * s, -4.0 * s)
			]), Color("#0f5132") * m)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-5.5 * s, -10.0 * s),
				pos + Vector2(0.0, -21.0 * s),
				pos + Vector2(5.5 * s, -10.0 * s)
			]), Color("#e2e8f0") * m)
		"bush_arid", "dry_scrub":
			ci.draw_line(pos, pos + Vector2(-4.5 * s, -6.0 * s), Color("#92400e") * m, 1.8 * s)
			ci.draw_line(pos, pos + Vector2(4.5 * s, -6.5 * s), Color("#92400e") * m, 1.8 * s)
			ci.draw_line(pos, pos + Vector2(0.0, -8.0 * s), Color("#b45309") * m, 1.8 * s)
		"bush_berry", "wildflowers", "tall_grass":
			ci.draw_circle(pos + Vector2(0.0, -3.5 * s), 4.5 * s, Color("#22c55e") * m)
			ci.draw_circle(pos + Vector2(2.0 * s, -5.0 * s), 1.8 * s, Color("#fbbf24") * m)
		"coastal_reeds":
			ci.draw_line(pos + Vector2(-2.5 * s, 0.0), pos + Vector2(-3.5 * s, -10.0 * s), Color("#0d9488") * m, 1.8 * s)
			ci.draw_line(pos, pos + Vector2(0.0, -12.0 * s), Color("#14b8a6") * m, 2.0 * s)
			ci.draw_line(pos + Vector2(2.5 * s, 0.0), pos + Vector2(3.5 * s, -9.5 * s), Color("#0d9488") * m, 1.8 * s)
		"rock_mountain", "mossy_rock", "fallen_log":
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-7.0 * s, 0.0),
				pos + Vector2(-4.0 * s, -7.5 * s),
				pos + Vector2(3.5 * s, -6.0 * s),
				pos + Vector2(7.0 * s, 0.0)
			]), Color("#64748b") * m)
		"tree_stump":
			ci.draw_rect(Rect2(pos + Vector2(-4.0 * s, -5.0 * s), Vector2(8.0 * s, 5.0 * s)), Color("#5c3a21") * m, true)
			EvoWorldOverlayRenderer.draw_ellipse_filled(ci, pos + Vector2(0.0, -5.0 * s), 4.2 * s, 2.2 * s, Color("#a16207") * m)
		"soil_crack":
			ci.draw_polyline(PackedVector2Array([
				pos + Vector2(-7.0 * s, -2.0 * s),
				pos + Vector2(-1.5 * s, 0.0),
				pos + Vector2(2.5 * s, -3.0 * s),
				pos + Vector2(7.5 * s, 1.0 * s)
			]), Color("#451a03") * m, 2.0 * s)
		"ruins":
			ci.draw_rect(Rect2(pos + Vector2(-8.0 * s, -9.0 * s), Vector2(5.0 * s, 9.0 * s)), Color("#64748b") * m, true)
			ci.draw_rect(Rect2(pos + Vector2(2.0 * s, -6.0 * s), Vector2(5.0 * s, 6.0 * s)), Color("#475569") * m, true)
		_:
			if prop.texture != null:
				ci.draw_texture_rect(prop.texture, prop.rect, false, m)


static func acquire_moving_prop(
	r: Node2D,
	p_kind: String,
	foot: Vector2,
	scale_val: float,
	primary_col: Color,
	trim_col: Color,
	anim_step: int,
	modulate_col: Color
) -> Prop:
	var prop: Prop
	if r._moving_prop_count < r._moving_prop_pool.size():
		prop = r._moving_prop_pool[r._moving_prop_count]
	else:
		prop = Prop.new(p_kind, scale_val, 0.85, modulate_col)
		r._moving_prop_pool.append(prop)
	r._moving_prop_count += 1
	prop.kind = p_kind
	prop.scale_val = scale_val
	prop.primary_color = primary_col
	prop.trim_color = trim_col
	prop.anim_step = anim_step
	prop.modulate = modulate_col
	prop.sways = false
	prop.set_foot(foot)
	return prop


static func collect_moving_props(r: Node2D) -> Array[Prop]:
	r._moving_prop_count = 0
	var props: Array[Prop] = []
	if r.get_semantic_zoom_tier() == "macro":
		return props
	var vis_rect: Rect2 = r._visible_world_rect
	var anim_time: float = r._anim_time

	for village in r._villages:
		var v_pos: Vector2 = village["pos"]
		if not vis_rect.has_point(v_pos):
			continue
		var sf: float = village["sf"]
		var m: Color = village["modulate"]
		var strat_color: Color = village["strategy_color"]
		var cape_trim := strat_color.lightened(0.25)
		var villager_count: int = village["villager_count"]
		for v_idx in range(villager_count):
			var orbit_angle := anim_time * (0.95 + float(v_idx % 3) * 0.22) + float(v_idx) * (TAU / float(villager_count))
			var orbit_r := (28.0 + float(v_idx % 3) * 8.0) * sf
			var foot := v_pos + Vector2(cos(orbit_angle) * orbit_r, sin(orbit_angle) * (orbit_r * 0.56) + 8.0 * sf)
			var frame := int((anim_time * 6.0) + float(v_idx)) % 3
			props.append(acquire_moving_prop(r, "villager", foot, 1.05 * sf, strat_color, cape_trim, frame, m))

	for r_idx in range(r._roads.size()):
		var road: Dictionary = r._roads[r_idx]
		if not TRAVELER_ROAD_KINDS.has(str(road.get("kind", ""))) or not bool(road.get("show_traffic", false)):
			continue
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not vis_rect.has_point(p_a) and not vis_rect.has_point(p_b):
			continue
		var curve_f: float = float(road.get("curve_factor", 0.045))
		var r_col: Color = road.get("color", Color("#eab308"))
		for traveler_i in range(2):
			var raw_walk := fposmod(anim_time * 0.24 + float(r_idx) * 0.31 + float(traveler_i) * 0.48, 1.0)
			if traveler_i == 1:
				raw_walk = 1.0 - raw_walk
			var t_walk := lerpf(0.22, 0.78, raw_walk)
			var foot := EvoRoadNetworkRenderer.sample_road_curve(p_a, p_b, t_walk, 1.0, curve_f)
			var frame := int((anim_time * 6.5) + float(traveler_i + r_idx)) % 3
			props.append(acquire_moving_prop(r, "villager", foot, 1.0, r_col, r_col.lightened(0.25), frame, Color.WHITE))
	return props


static func world_prop(
	sprite_name: String,
	world_xy: Vector2,
	top_z: float,
	screen_offset: Vector2,
	scale_val: float,
	modulate_col: Color
) -> Prop:
	var prop := Prop.new(sprite_name, scale_val, 0.78, modulate_col)
	prop.world_xy = world_xy
	prop.top_z = top_z
	prop.screen_offset = screen_offset
	return prop
