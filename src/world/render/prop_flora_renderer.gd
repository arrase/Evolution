class_name EvoPropFloraRenderer
extends RefCounted

const STATUS_COLORS: Dictionary = {
	"thriving": Color("#34d399"),
	"stable": Color("#38bdf8"),
	"declining": Color("#f59e0b"),
	"struggling": Color("#fbbf24"),
	"starving": Color("#fb7185")
}

const NON_SWAYING_SPRITES := EvoFloraPropLayout.NON_SWAYING_SPRITES
const BIOME_FLORA_PALETTES := EvoFloraPropLayout.BIOME_FLORA_PALETTES
const DEFAULT_FLORA_PALETTE := EvoFloraPropLayout.DEFAULT_FLORA_PALETTE
const VILLAGER_POSES: Array[String] = ["villager_idle", "villager_walk1", "villager_walk2"]
const TRAVELER_ROAD_KINDS: Array[String] = ["collab", "bridge", "pact", "tribute", "merge", "rural_farm"]


class Prop:
	var hex_id: String = ""
	var world_xy: Vector2
	var top_z: float
	var screen_offset: Vector2
	var anchor_offset: Vector2
	var y: float
	var texture: Texture2D
	var rect: Rect2
	var modulate: Color
	var trim_color: Color = Color.TRANSPARENT
	var sways: bool = false
	var sway_phase: float = 0.0

	func _init(p_texture: Texture2D, scale: float, anchor_y: float, p_modulate: Color) -> void:
		texture = p_texture
		var tex_sz := p_texture.get_size()
		var dpi_norm: float = 0.32 if tex_sz.x <= 64.0 else 0.24
		var size := tex_sz * (scale * dpi_norm)
		anchor_offset = Vector2(size.x * 0.5, size.y * anchor_y)
		rect = Rect2(Vector2.ZERO, size)
		modulate = p_modulate

	func set_foot(foot: Vector2) -> void:
		rect.position = foot - anchor_offset
		y = foot.y

	func project(ground: Transform2D, lift: float) -> void:
		set_foot(ground * world_xy + Vector2(0.0, -top_z * lift) + screen_offset)


static func resolve_deme_strategy_color(world_state: EvoTypes.WorldState, deme: EvoTypes.Deme) -> Color:
	var fallback := Color.from_string(deme.color, Color(0.88, 0.48, 0.37))
	if world_state != null and world_state.strategies_catalog.has(deme.strategy_id):
		var strategy: EvoTypes.StrategyDef = world_state.strategies_catalog[deme.strategy_id]
		return Color.from_string(strategy.color, fallback)
	return fallback


static func get_villager_textures_for_color(r: Node2D, tunic_col: Color) -> Array[ImageTexture]:
	var hex_key := tunic_col.to_html(false)
	if r._villager_tex_sets.has(hex_key):
		return r._villager_tex_sets[hex_key]
	var tex_set: Array[ImageTexture] = [
		EvoPixelArtGen.get_villager_texture(VILLAGER_POSES[0], tunic_col),
		EvoPixelArtGen.get_villager_texture(VILLAGER_POSES[1], tunic_col),
		EvoPixelArtGen.get_villager_texture(VILLAGER_POSES[2], tunic_col)
	]
	r._villager_tex_sets[hex_key] = tex_set
	return tex_set


static func collect_villages(r: Node2D) -> Array[Dictionary]:
	var villages: Array[Dictionary] = []
	r._village_by_deme_id.clear()
	r._rural_cell_ids.clear()
	var state: EvoTypes.WorldState = r.world_state
	var geo_by_deme := build_geopolitics_by_deme(state)
	var hex_list: Array = r._sorted_hex_ids if not r._sorted_hex_ids.is_empty() else state.cells.keys()
	for hex_id in hex_list:
		var cell: EvoTypes.HexCell = state.cells[hex_id]
		if r._is_water(cell):
			continue
		if cell.deme_ids.is_empty():
			if (cell.land_use in ["crops", "pasture"]) and cell.owner_deme_id != "":
				r._rural_cell_ids.append(hex_id)
			continue
		var deme_id: String = cell.deme_ids[0]
		if not state.demes.has(deme_id):
			continue
		var deme: EvoTypes.Deme = state.demes[deme_id]
		var world_xy := HexMath.axial_to_world(cell.q, cell.r)
		var top_z: float = r._get_cell_top_z(cell)
		var v_world := world_xy
		var is_dimmed: bool = r.highlighted_lineage_id != "" and deme.lineage_id != r.highlighted_lineage_id
		var tier := deme.get_village_tier()
		var strat_vis := EvoWorldOverlayRenderer._resolve_deme_strategy_visuals(state, deme, r.lang)
		var strat_color: Color = strat_vis["color"]

		var v_pos: Vector2 = r._project(v_world, top_z)
		var vital_status := deme.get_vital_status()
		var status_col: Color = STATUS_COLORS[vital_status] if STATUS_COLORS.has(vital_status) else Color("#38bdf8")
		var geo: Dictionary = geo_by_deme.get(deme.id, {})

		var v_entry := {
			"deme": deme,
			"deme_id": deme.id,
			"hex_id": hex_id,
			"is_capital": (hex_id == deme.hex_id),
			"posture": deme.defense_posture,
			"world_xy": v_world,
			"top_z": top_z,
			"pos": v_pos,
			"modulate": Color(1, 1, 1, 0.42) if is_dimmed else Color.WHITE,
			"is_dimmed": is_dimmed,
			"tier": tier,
			"archetype": get_deme_dominant_archetype(r, deme),
			"has_pact": geo["has_pact"],
			"in_war": geo["in_war"],
			"in_raid": geo["in_raid"],
			"in_betrayal": geo["in_betrayal"],
			"in_tribute": geo["in_tribute"],
			"in_siege": geo["in_siege"],
			"geo_icons": geo["geo_icons"],
			"status_col": status_col,
			"strat_color": strat_color,
			"strat_visuals": strat_vis,
			"villager_count": clampi(3 + tier + int(deme.population / 95), 3, 9),
			"villager_textures": get_villager_textures_for_color(r, strat_color),
			"hit_rect": Rect2(v_pos - Vector2(104, 92), Vector2(208, 168))
		}
		villages.append(v_entry)
		if hex_id == deme.hex_id:
			r._village_by_deme_id[deme.id] = v_entry
	return villages


static func get_village_building_layout(
	tier: int,
	has_culture: bool,
	cultural_count: int,
	archetype: String
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var is_martial := archetype in ["war", "raid", "dispute", "betrayal"]
	var is_mercantile := archetype in ["exchange", "cooperate", "pact"]

	match tier:
		1:
			items.append({"sprite": "tent", "offset": Vector2(-68.0, -14.0), "scale": 2.15})
			items.append({"sprite": "tent", "offset": Vector2(0.0, -48.0), "scale": 2.20})
			items.append({"sprite": "tent", "offset": Vector2(68.0, -14.0), "scale": 2.15})
		2:
			items.append({"sprite": "longhouse", "offset": Vector2(0.0, -46.0), "scale": 2.25})
			items.append({"sprite": "granary", "offset": Vector2(-82.0, -18.0), "scale": 2.12})
			items.append({"sprite": "house_clay" if has_culture else "hut", "offset": Vector2(82.0, -18.0), "scale": 2.14})
			items.append({"sprite": "hut", "offset": Vector2(-58.0, 30.0), "scale": 2.08})
		3:
			var main_sprite := "tower" if is_martial else "hall"
			var civic_sprite := "market" if is_mercantile else ("temple" if has_culture else "windmill")
			items.append({"sprite": main_sprite, "offset": Vector2(0.0, -46.0), "scale": 2.30})
			items.append({"sprite": civic_sprite, "offset": Vector2(-84.0, -20.0), "scale": 2.18})
			items.append({"sprite": "house", "offset": Vector2(84.0, -20.0), "scale": 2.14})
			items.append({"sprite": "house", "offset": Vector2(-64.0, 30.0), "scale": 2.10})
			items.append({"sprite": "house", "offset": Vector2(64.0, 30.0), "scale": 2.10})
		_:
			var monument := "citadel" if (is_martial or (not has_culture and cultural_count == 0)) else "cathedral"
			var civic := "temple" if (monument == "citadel" and has_culture) else "hall"
			items.append({"sprite": monument, "offset": Vector2(0.0, -18.0), "scale": 2.38})
			items.append({"sprite": "tower", "offset": Vector2(0.0, -76.0), "scale": 2.18})
			items.append({"sprite": civic, "offset": Vector2(-92.0, -26.0), "scale": 2.18})
			items.append({"sprite": "market", "offset": Vector2(92.0, -26.0), "scale": 2.16})
			items.append({"sprite": "house", "offset": Vector2(-74.0, 30.0), "scale": 2.10})
			items.append({"sprite": "granary" if archetype == "forage" else "house", "offset": Vector2(74.0, 30.0), "scale": 2.10})

	return items


static func draw_village_plaza(r: Node2D, village: Dictionary) -> void:
	var v_pos: Vector2 = village["pos"]
	if r._visible_world_rect.size != Vector2.ZERO and not r._visible_world_rect.grow(HexMath.HEX_SIZE * 1.5).has_point(v_pos):
		return
	var ci: Node2D = r._network_layer
	var deme: EvoTypes.Deme = village["deme"]
	var modulate_col: Color = village["modulate"]
	var status_col: Color = village["status_col"]
	var plaza_center: Vector2 = v_pos + Vector2(0, 8.0)
	var strat_color: Color = village["strat_color"]
	var strat_hi := strat_color.lightened(0.25)

	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, v_pos + Vector2(0, -4.0), 124.0, 72.0, Color(0.36, 0.25, 0.16, 0.30) * modulate_col)
	var eff_tier: int = deme.get_village_tier()
	var layout := get_village_building_layout(
		eff_tier,
		not deme.cultural_trait_ids.is_empty(),
		deme.cultural_trait_ids.size(),
		str(village["archetype"])
	)
	for b_item in layout:
		var b_foot: Vector2 = v_pos + (b_item["offset"] as Vector2)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, b_foot + Vector2(0, -2.5), 26.0, 14.5, Color("#7c5c3b") * modulate_col)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, b_foot + Vector2(0, -2.5), 21.5, 11.5, Color("#cbb082") * modulate_col)

	var is_merged: bool = deme.merged_count > 0 or deme.is_multi_hex()
	var plinth_r := 54.0 if is_merged else 48.0
	var rim_r := plinth_r + 5.0
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, rim_r, rim_r * 0.58, Color("#5c4028") * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r, plinth_r * 0.58, Color("#c2a378") * modulate_col)
	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, plaza_center, plinth_r * 0.74, plinth_r * 0.74 * 0.58, Color("#d9be96") * modulate_col)
	if is_merged:
		EvoWorldOverlayRenderer.draw_ellipse_outline(
			ci,
			plaza_center,
			plinth_r * 0.64,
			plinth_r * 0.64 * 0.58,
			Color("#fbbf24") * modulate_col,
			2.4
		)

	var mosaic_outer_r := plinth_r * 0.52
	var mosaic_inner_r := plinth_r * 0.36
	EvoWorldOverlayRenderer.draw_ellipse_filled(
		ci,
		plaza_center,
		mosaic_outer_r,
		mosaic_outer_r * 0.58,
		strat_color.darkened(0.22) * modulate_col
	)
	EvoWorldOverlayRenderer.draw_ellipse_filled(
		ci,
		plaza_center,
		mosaic_inner_r,
		mosaic_inner_r * 0.58,
		strat_color * modulate_col
	)
	EvoWorldOverlayRenderer.draw_ellipse_outline(
		ci,
		plaza_center,
		mosaic_outer_r,
		mosaic_outer_r * 0.58,
		strat_hi * modulate_col,
		2.2
	)
	EvoWorldOverlayRenderer.draw_ellipse_filled(
		ci,
		plaza_center,
		plinth_r * 0.14,
		plinth_r * 0.14 * 0.58,
		Color("#fef3c7") * modulate_col
	)

	for c_i in range(14):
		var c_ang := TAU * float(c_i) / 14.0
		var c_pt := plaza_center + Vector2(cos(c_ang) * plinth_r * 0.84, sin(c_ang) * plinth_r * 0.48)
		ci.draw_circle(c_pt, 4.0, (strat_color.darkened(0.15) if c_i % 2 == 0 else Color("#a38358")) * modulate_col)

	var pole_base := plaza_center + Vector2(-34.0, -4.0)
	var pole_top := pole_base + Vector2(0.0, -26.0)
	ci.draw_circle(pole_base + Vector2(2.0, 1.5), 3.6, Color(0.0, 0.0, 0.0, 0.30) * modulate_col)
	ci.draw_line(pole_base, pole_top, Color("#5c3317") * modulate_col, 3.2)
	ci.draw_line(pole_base + Vector2(-0.6, 0.0), pole_top + Vector2(-0.6, 0.0), Color("#8c5230") * modulate_col, 1.4)
	ci.draw_circle(pole_top, 2.5, Color("#fbbf24") * modulate_col)

	var wave := sin(r._anim_time * 4.2 + v_pos.x * 0.04) * 2.0
	var flag_pts := PackedVector2Array([
		pole_top + Vector2(1.0, 1.0),
		pole_top + Vector2(19.0, 4.5 + wave),
		pole_top + Vector2(1.0, 11.0)
	])
	ci.draw_colored_polygon(flag_pts, strat_color * modulate_col)
	var flag_hi_pts := PackedVector2Array([
		pole_top + Vector2(1.0, 1.0),
		pole_top + Vector2(13.5, 3.5 + wave * 0.65),
		pole_top + Vector2(1.0, 5.5)
	])
	ci.draw_colored_polygon(flag_hi_pts, strat_hi * modulate_col)
	if is_merged:
		var sec_col := Color(deme.secondary_color) if deme.secondary_color != "" else Color("#fbbf24")
		var sec_flag_pts := PackedVector2Array([
			pole_top + Vector2(1.0, 10.5),
			pole_top + Vector2(16.0, 13.5 - wave * 0.8),
			pole_top + Vector2(1.0, 18.5)
		])
		ci.draw_colored_polygon(sec_flag_pts, sec_col * modulate_col)

	var ring_r := plinth_r + 4.8
	EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, ring_r, ring_r * 0.58, status_col * modulate_col, 3.2)


static func compute_cell_flora_key(r: Node2D, cell: EvoTypes.HexCell, top_z: float) -> Array:
	return EvoFloraPropLayout.compute_cell_flora_key(r, cell, top_z)


static func collect_static_props(r: Node2D) -> Array[Prop]:
	return EvoFloraPropLayout.collect_static_props(r)


static func get_cell_road_corridors_local(
	r: Node2D,
	cell: EvoTypes.HexCell,
	village_local_centers: Array[Vector2]
) -> Array[Dictionary]:
	return EvoFloraPropLayout.get_cell_road_corridors_local(r, cell, village_local_centers)


static func collect_cell_flora_props(
	r: Node2D,
	cell: EvoTypes.HexCell,
	world_xy: Vector2,
	top_z: float,
	props: Array[Prop]
) -> void:
	EvoFloraPropLayout.collect_cell_flora_props(r, cell, world_xy, top_z, props)


static func collect_village_building_props(
	state: EvoTypes.WorldState,
	village: Dictionary,
	props: Array[Prop]
) -> void:
	var deme: EvoTypes.Deme = village["deme"]
	var cell: EvoTypes.HexCell = state.cells[str(village["hex_id"])]
	var v_pos: Vector2 = village["pos"]
	var m: Color = village["modulate"]
	var eff_tier: int = deme.get_village_tier()
	var c_count := deme.cultural_trait_ids.size()
	var arch := str(village["archetype"])
	var flags: int = 32 if bool(village.get("in_siege", false)) else 0
	var vp_key: Array = [
		eff_tier,
		c_count,
		arch,
		flags,
		deme.defense_tier,
		deme.merged_count,
		deme.is_multi_hex(),
		snappedf(deme.salubrity, 0.05),
		m,
		v_pos
	]
	if cell.has_meta("_vp_key") and (cell.get_meta("_vp_key") as Array) == vp_key:
		props.append_array(cell.get_meta("_vp_val") as Array[Prop])
		return

	var v_props: Array[Prop] = []
	var v_world: Vector2 = village["world_xy"]
	var top_z: float = village["top_z"]
	var layout := get_village_building_layout(eff_tier, c_count > 0, c_count, arch)
	for b_item in layout:
		var off: Vector2 = b_item["offset"]
		var p := world_prop(str(b_item["sprite"]), v_world, top_z, off, float(b_item["scale"]), m)
		p.set_foot(v_pos + off)
		v_props.append(p)
	_draw_settlement_props(village, v_props)
	cell.set_meta("_vp_key", vp_key)
	cell.set_meta("_vp_val", v_props)
	props.append_array(v_props)


static func _draw_settlement_props(village: Dictionary, props: Array[Prop]) -> void:
	if bool(village.get("in_siege", false)):
		var v_world: Vector2 = village["world_xy"]
		var v_pos: Vector2 = village["pos"]
		var top_z: float = village["top_z"]
		var m: Color = village["modulate"]
		var off := Vector2(-96.0, 62.0)
		var p := world_prop("prop_siege_engine", v_world, top_z, off, 2.15, m)
		p.set_foot(v_pos + off)
		props.append(p)


static func build_geopolitics_by_deme(state: EvoTypes.WorldState) -> Dictionary:
	var geo_by_deme: Dictionary = {}
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		var empty_icons: Array[String] = []
		geo_by_deme[did] = {
			"has_pact": false,
			"has_vendetta": false,
			"in_war": false,
			"in_raid": false,
			"in_betrayal": false,
			"in_tribute": false,
			"in_siege": false,
			"in_merge": d.merged_count > 0 or d.is_multi_hex(),
			"geo_icons": empty_icons
		}
	for pk_var in state.relations.keys():
		var rel: EvoTypes.Relation = state.relations[pk_var]
		if rel.pact_turns > 0 or rel.feud_turns > 0:
			var pk := str(pk_var)
			var parts := pk.split("__")
			if parts.size() == 2 and geo_by_deme.has(parts[0]) and geo_by_deme.has(parts[1]):
				if rel.pact_turns > 0:
					geo_by_deme[parts[0]]["has_pact"] = true
					geo_by_deme[parts[1]]["has_pact"] = true
				if rel.feud_turns > 0:
					geo_by_deme[parts[0]]["has_vendetta"] = true
					geo_by_deme[parts[1]]["has_vendetta"] = true
	for flow in state.active_flows:
		var ft := flow.flow_type
		if ft == "union":
			ft = "merge"
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
		if bool(entry["in_siege"]):
			icons.append("siege")
		if bool(entry["in_war"]):
			icons.append("war")
		if d.infection_turns > 0:
			icons.append("epidemic")
		if d.get_vital_status() == "starving":
			icons.append("famine")
		if bool(entry["in_betrayal"]):
			icons.append("betrayal")
		if bool(entry["in_raid"]):
			icons.append("raid")
		if bool(entry["has_vendetta"]):
			icons.append("vendetta")
		if bool(entry["in_tribute"]):
			icons.append("tribute")
		if bool(entry["has_pact"]):
			icons.append("pact")
		if d.merged_count > 0 or d.is_multi_hex() or bool(entry["in_merge"]):
			icons.append("merge")
		if d.defense_tier > 0:
			icons.append("defense")
	return geo_by_deme


static func get_deme_dominant_archetype(r: Node2D, deme: EvoTypes.Deme) -> String:
	var action_type := str(deme.chosen_action["type"])
	var catalog: Dictionary = r.world_state.decisions_catalog
	if catalog.has(action_type):
		var dec: EvoTypes.DecisionDef = catalog[action_type]
		return dec.archetype
	return "forage"


static func draw_props(r: Node2D) -> void:
	var zoom_val: float = r._get_camera_zoom() if r.has_method("_get_camera_zoom") else (r.camera.zoom_level if r.camera != null else 1.0)
	var vis_rect: Rect2 = r._visible_world_rect
	if zoom_val < 0.35:
		for prop in r._static_props:
			if not vis_rect.intersects(prop.rect):
				continue
			r._anim_layer.draw_texture_rect(prop.texture, prop.rect, false, prop.modulate)
		EvoRoadWallDrawer.draw_settlement_front_walls(r, r._anim_layer)
		return

	var moving := collect_moving_props(r)
	moving.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)

	var road_edges := EvoRoadWallDrawer.collect_settlement_road_edges(r)
	var has_cull: bool = vis_rect.size != Vector2.ZERO
	var wall_cull: Rect2 = vis_rect.grow(HexMath.HEX_SIZE * 1.5) if has_cull else Rect2()
	var front_walls: Array[Dictionary] = []
	for village in r._villages:
		if has_cull and not wall_cull.has_point(village["pos"] as Vector2):
			continue
		var fy := EvoRoadWallDrawer.compute_village_front_wall_y(r, village)
		if fy < INF:
			front_walls.append({"y": fy, "village": village})
	front_walls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["y"]) < float(b["y"])
	)

	var m_idx := 0
	var w_idx := 0
	for prop in r._static_props:
		if not vis_rect.intersects(prop.rect):
			continue
		while m_idx < moving.size() or w_idx < front_walls.size():
			var next_m_y: float = moving[m_idx].y if m_idx < moving.size() else INF
			var next_w_y: float = float(front_walls[w_idx]["y"]) if w_idx < front_walls.size() else INF
			if minf(next_m_y, next_w_y) >= prop.y:
				break
			if next_m_y <= next_w_y:
				draw_prop(r, moving[m_idx])
				m_idx += 1
			else:
				EvoRoadWallDrawer.draw_village_wall_pass(
					r,
					front_walls[w_idx]["village"] as Dictionary,
					r._anim_layer,
					true,
					road_edges
				)
				w_idx += 1
		draw_prop(r, prop)

	while m_idx < moving.size() or w_idx < front_walls.size():
		var next_m_y: float = moving[m_idx].y if m_idx < moving.size() else INF
		var next_w_y: float = float(front_walls[w_idx]["y"]) if w_idx < front_walls.size() else INF
		if next_m_y <= next_w_y:
			draw_prop(r, moving[m_idx])
			m_idx += 1
		else:
			EvoRoadWallDrawer.draw_village_wall_pass(
				r,
				front_walls[w_idx]["village"] as Dictionary,
				r._anim_layer,
				true,
				road_edges
			)
			w_idx += 1


static func draw_prop(r: Node2D, prop: Prop) -> void:
	var rect := prop.rect
	var sway_x := sin(r._anim_time * 2.1 + prop.sway_phase) * 1.15 if prop.sways else 0.0
	rect.position.x += sway_x
	var foot := prop.rect.position + prop.anchor_offset
	var ci: Node2D = r._anim_layer

	var sh_rx := clampf(rect.size.x * 0.27, 6.0, 26.0)
	var sh_ry := sh_rx * 0.50
	var sh_pos := foot + Vector2(sh_rx * 0.28 + sway_x * 0.35, sh_ry * 0.22)
	EvoWorldOverlayRenderer.draw_ellipse_filled(
		ci,
		sh_pos,
		sh_rx,
		sh_ry,
		Color(0.06, 0.04, 0.02, 0.22 * prop.modulate.a)
	)

	if prop.trim_color.a > 0.0:
		var ring_rx := clampf(rect.size.x * 0.26, 6.5, 13.0)
		var ring_ry := ring_rx * 0.56
		var ring_center := foot + Vector2(0.0, 1.0)
		var fill_col := prop.trim_color
		fill_col.a *= 0.32
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, ring_center, ring_rx, ring_ry, fill_col)
		EvoWorldOverlayRenderer.draw_ellipse_outline(ci, ring_center, ring_rx, ring_ry, prop.trim_color, 1.8)

	ci.draw_texture_rect(prop.texture, rect, false, prop.modulate)


static func acquire_moving_prop(
	r: Node2D,
	tex: ImageTexture,
	foot: Vector2,
	scale_val: float,
	anchor_y_ratio: float,
	modulate_col: Color
) -> Prop:
	var prop: Prop
	if r._moving_prop_count < r._moving_prop_pool.size():
		prop = r._moving_prop_pool[r._moving_prop_count]
	else:
		prop = Prop.new(tex, scale_val, anchor_y_ratio, modulate_col)
		r._moving_prop_pool.append(prop)
	r._moving_prop_count += 1
	prop.texture = tex
	var tex_sz := tex.get_size()
	var dpi_norm: float = 0.32 if tex_sz.x <= 64.0 else 0.24
	var sz: Vector2 = tex_sz * (scale_val * dpi_norm)
	prop.anchor_offset = Vector2(sz.x * 0.5, sz.y * anchor_y_ratio)
	prop.rect = Rect2(foot - prop.anchor_offset, sz)
	prop.y = foot.y
	prop.modulate = modulate_col
	prop.trim_color = Color.TRANSPARENT
	prop.sways = false
	return prop


static func collect_moving_props(r: Node2D) -> Array[Prop]:
	r._moving_prop_count = 0
	var props: Array[Prop] = []
	var vis_rect: Rect2 = r._visible_world_rect
	var anim_time: float = r._anim_time

	for village in r._villages:
		var v_pos: Vector2 = village["pos"]
		if not vis_rect.has_point(v_pos):
			continue
		var m: Color = village["modulate"]
		var tier := int(village["tier"])
		var fire_sprite := "tier1_campfire" if int(anim_time * 5.0) % 2 == 0 else "tier1_campfire_2"
		var fire_off := Vector2(0.0, 26.0) if tier >= 4 else Vector2(0.0, 6.0)
		var fire_scale := 2.25 if tier == 1 else 2.05
		props.append(acquire_moving_prop(r, EvoPixelArtGen.get_texture(fire_sprite), v_pos + fire_off, fire_scale, 0.78, m))

	for r_idx in range(r._roads.size()):
		var road: Dictionary = r._roads[r_idx]
		if not bool(road.get("active_flow", false)) or not bool(road.get("show_traffic", true)):
			continue
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not vis_rect.has_point(p_a) and not vis_rect.has_point(p_b):
			continue

		var ft := str(road.get("flow_type", ""))
		var f_col: Color = road.get("color", Color("#eab308"))
		var ring_col := f_col.lightened(0.18)

		match ft:
			"rural_farm":
				var raw_w := fposmod(anim_time * 0.24 + float(r_idx) * 0.37, 1.0)
				var w_foot := EvoRoadNetworkRenderer.sample_road_path(road, lerpf(0.22, 0.80, raw_w), 1.0)
				props.append(acquire_moving_prop(r, EvoPixelArtGen.get_texture("covered_wagon"), w_foot, 1.85, 0.82, Color.WHITE))
				var raw_f := fposmod(raw_w + 0.45, 1.0)
				var f_foot := EvoRoadNetworkRenderer.sample_road_path(road, lerpf(0.80, 0.22, raw_f), 1.0)
				var f_pose := "villager_work" if int(anim_time * 5.0 + float(r_idx)) % 2 == 0 else "villager_walk1"
				var f_prop := acquire_moving_prop(r, EvoPixelArtGen.get_villager_texture(f_pose, f_col), f_foot, 2.45, 0.88, Color.WHITE)
				f_prop.trim_color = ring_col
				props.append(f_prop)

			"trade", "exchange", "cooperate", "pact":
				for u_i in range(2):
					var raw_t := fposmod(anim_time * 0.26 + float(r_idx) * 0.31 + float(u_i) * 0.48, 1.0)
					var t_val := lerpf(0.20, 0.80, raw_t) if u_i == 0 else lerpf(0.80, 0.20, raw_t)
					var foot := EvoRoadNetworkRenderer.sample_road_path(road, t_val, 1.0)
					var pose := "traveler" if (int(anim_time * 5.5) + u_i) % 2 == 0 else "villager_walk1"
					var u_prop := acquire_moving_prop(r, EvoPixelArtGen.get_villager_texture(pose, f_col), foot, 2.48, 0.88, Color.WHITE)
					u_prop.trim_color = ring_col
					props.append(u_prop)

			"aid", "tribute":
				for u_i in range(2):
					var raw_a := fposmod(anim_time * 0.30 + float(r_idx) * 0.29 + float(u_i) * 0.46, 1.0)
					var foot := EvoRoadNetworkRenderer.sample_road_path(road, lerpf(0.18, 0.82, raw_a), 1.0)
					var pose := "traveler" if (int(anim_time * 5.5) + u_i) % 2 == 0 else "villager_work"
					var u_prop := acquire_moving_prop(r, EvoPixelArtGen.get_villager_texture(pose, f_col), foot, 2.48, 0.88, Color.WHITE)
					u_prop.trim_color = ring_col
					props.append(u_prop)

			"union", "merge", "colonize", "migration":
				var c_sign := -1.0 if str(road.get("kind", "")) == "expedition" else 1.0
				for u_i in range(2):
					var raw_m := fposmod(anim_time * 0.32 + float(r_idx) * 0.27 + float(u_i) * 0.44, 1.0)
					var foot := EvoRoadNetworkRenderer.sample_road_path(road, lerpf(0.18, 0.82, raw_m), c_sign)
					var pose := "traveler" if (int(anim_time * 6.0) + u_i) % 2 == 0 else "villager_walk2"
					var u_prop := acquire_moving_prop(r, EvoPixelArtGen.get_villager_texture(pose, f_col), foot, 2.48, 0.88, Color.WHITE)
					u_prop.trim_color = ring_col
					props.append(u_prop)

			"war", "siege", "betrayal":
				var diff := p_b - p_a
				var perp := Vector2(-diff.y, diff.x).normalized() if diff.length() > 0.01 else Vector2.UP
				for w_i in range(3):
					var raw_w := fposmod(anim_time * 0.38 + float(w_i) * 0.28, 1.0)
					var foot := EvoRoadNetworkRenderer.sample_road_path(road, lerpf(0.14, 0.74, raw_w), 0.0) + perp * (float(w_i - 1) * 4.5)
					var pose := "raider" if (int(anim_time * 7.0) + w_i) % 2 == 0 else "villager_walk1"
					var w_prop := acquire_moving_prop(r, EvoPixelArtGen.get_villager_texture(pose, f_col), foot, 2.50, 0.88, Color.WHITE)
					w_prop.trim_color = Color("#ef4444")
					props.append(w_prop)

			"raid":
				for r_i in range(2):
					var raw_r := fposmod(anim_time * 0.52 + float(r_i) * 0.48, 1.0)
					var foot := EvoRoadNetworkRenderer.sample_road_path(road, lerpf(0.84, 0.18, raw_r), 0.0)
					var pose := "raider" if (int(anim_time * 8.0) + r_i) % 2 == 0 else "villager_walk2"
					var r_prop := acquire_moving_prop(r, EvoPixelArtGen.get_villager_texture(pose, f_col), foot, 2.50, 0.88, Color.WHITE)
					r_prop.trim_color = Color("#f97316")
					props.append(r_prop)

			"raid_repelled":
				for r_i in range(2):
					var raw_r := fposmod(anim_time * 0.52 + float(r_i) * 0.46, 1.0)
					var t_rep := lerpf(0.16, 0.72, raw_r / 0.55) if raw_r < 0.55 else lerpf(0.72, 0.20, (raw_r - 0.55) / 0.45)
					var foot := EvoRoadNetworkRenderer.sample_road_path(road, t_rep, 0.0)
					var pose := "raider" if raw_r < 0.55 else "villager_walk1"
					var r_prop := acquire_moving_prop(r, EvoPixelArtGen.get_villager_texture(pose, f_col), foot, 2.50, 0.88, Color.WHITE)
					r_prop.trim_color = Color("#f97316")
					props.append(r_prop)

	return props


static func world_prop(
	sprite_name: String,
	world_xy: Vector2,
	top_z: float,
	screen_offset: Vector2,
	scale_val: float,
	modulate_col: Color
) -> Prop:
	var prop := Prop.new(EvoPixelArtGen.get_texture(sprite_name), scale_val, 0.78, modulate_col)
	prop.world_xy = world_xy
	prop.top_z = top_z
	prop.screen_offset = screen_offset
	return prop
