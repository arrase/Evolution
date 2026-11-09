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
		r._village_by_deme_id[deme.id] = v_entry
	return villages


static func get_village_building_layout(
	tier: int,
	has_culture: bool,
	cultural_count: int,
	archetype: String
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var totem_sprite := "totem_innov"
	if archetype in ["cooperate", "pact", "exchange"]:
		totem_sprite = "totem_coop"
	elif archetype in ["war", "raid", "dispute", "betrayal"]:
		totem_sprite = "totem_aggro"

	match tier:
		1:
			items.append({"sprite": "campfire", "offset": Vector2(0, 6), "scale": 2.35})
			items.append({"sprite": "hut_thatch", "offset": Vector2(-68, -24), "scale": 2.48})
			items.append({"sprite": "hut_thatch", "offset": Vector2(66, -20), "scale": 2.44})
			items.append({"sprite": "hut_thatch", "offset": Vector2(-18, -54), "scale": 2.38})
		2:
			items.append({"sprite": "temple_totem" if has_culture else "campfire", "offset": Vector2(0, -20), "scale": 2.52})
			items.append({"sprite": "house_clay", "offset": Vector2(-76, -28), "scale": 2.48})
			items.append({"sprite": "house_clay", "offset": Vector2(76, -26), "scale": 2.46})
			items.append({"sprite": "hut_thatch", "offset": Vector2(-92, 18), "scale": 2.36})
			items.append({"sprite": "hut_thatch", "offset": Vector2(90, 20), "scale": 2.36})
			items.append({"sprite": "hut_thatch", "offset": Vector2(0, -64), "scale": 2.38})
			items.append({"sprite": "granary", "offset": Vector2(-48, 44), "scale": 2.40})
			items.append({"sprite": "watchtower", "offset": Vector2(56, -56), "scale": 2.42})
		3:
			items.append({"sprite": "temple_totem", "offset": Vector2(0, -26), "scale": 2.60})
			items.append({"sprite": "house_stone", "offset": Vector2(-64, -46), "scale": 2.48})
			items.append({"sprite": "house_stone", "offset": Vector2(64, -46), "scale": 2.48})
			items.append({"sprite": "house_stone", "offset": Vector2(0, -76), "scale": 2.44})
			items.append({"sprite": "house_clay", "offset": Vector2(-106, -8), "scale": 2.42})
			items.append({"sprite": "house_clay", "offset": Vector2(106, -8), "scale": 2.42})
			items.append({"sprite": "house_clay", "offset": Vector2(-86, 34), "scale": 2.38})
			items.append({"sprite": "house_clay", "offset": Vector2(86, 34), "scale": 2.38})
			items.append({"sprite": "granary", "offset": Vector2(-46, 52), "scale": 2.45})
			items.append({"sprite": "windmill", "offset": Vector2(110, -48), "scale": 2.52})
			items.append({"sprite": "watchtower", "offset": Vector2(-112, -48), "scale": 2.48})
		_:
			items.append({"sprite": "citadel_keep", "offset": Vector2(-24, -36), "scale": 2.72})
			items.append({"sprite": "cathedral", "offset": Vector2(34, -32), "scale": 2.64})
			items.append({"sprite": "house_stone", "offset": Vector2(0, -84), "scale": 2.48})
			items.append({"sprite": "house_stone", "offset": Vector2(-74, -62), "scale": 2.46})
			items.append({"sprite": "house_stone", "offset": Vector2(76, -62), "scale": 2.46})
			items.append({"sprite": "house_stone", "offset": Vector2(-116, -16), "scale": 2.44})
			items.append({"sprite": "house_stone", "offset": Vector2(116, -16), "scale": 2.44})
			items.append({"sprite": "house_stone", "offset": Vector2(-62, 16), "scale": 2.40})
			items.append({"sprite": "house_clay", "offset": Vector2(64, 16), "scale": 2.38})
			items.append({"sprite": "house_clay", "offset": Vector2(-96, 34), "scale": 2.38})
			items.append({"sprite": "house_clay", "offset": Vector2(96, 34), "scale": 2.38})
			items.append({"sprite": "granary", "offset": Vector2(-48, 56), "scale": 2.48})
			items.append({"sprite": "windmill", "offset": Vector2(122, -54), "scale": 2.55})
			items.append({"sprite": "watchtower", "offset": Vector2(-124, -54), "scale": 2.52})
			items.append({"sprite": "watchtower", "offset": Vector2(0, 68), "scale": 2.48})

	if has_culture:
		var totem_scale := 2.18 + mini(3, cultural_count) * 0.14
		var totem_off := Vector2(-58, 32) if tier == 1 else Vector2(-34, 14)
		items.append({"sprite": totem_sprite, "offset": totem_off, "scale": totem_scale})

	var act_offset := Vector2(58, 28) if tier == 1 else Vector2(48, 50)
	items.append({"sprite": "act_" + archetype, "offset": act_offset, "scale": 2.30})
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

	EvoWorldOverlayRenderer.draw_ellipse_filled(ci, v_pos + Vector2(0, -4.0), 132.0, 76.0, Color(0.36, 0.25, 0.16, 0.34) * modulate_col)
	var eff_tier: int = deme.get_village_tier()
	var layout := get_village_building_layout(
		eff_tier,
		not deme.cultural_trait_ids.is_empty(),
		deme.cultural_trait_ids.size(),
		str(village["archetype"])
	)
	for b_item in layout:
		var b_foot: Vector2 = v_pos + (b_item["offset"] as Vector2)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, b_foot + Vector2(0, -3.0), 28.0, 15.5, Color("#7c5c3b") * modulate_col)
		EvoWorldOverlayRenderer.draw_ellipse_filled(ci, b_foot + Vector2(0, -3.0), 23.0, 12.5, Color("#cbb082") * modulate_col)

	var is_merged: bool = deme.merged_count > 0 or deme.walled_union_id != ""
	var plinth_r := 58.0 if is_merged else 52.0
	var rim_r := plinth_r + 5.5
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
		ci.draw_circle(c_pt, 4.4, (strat_color.darkened(0.15) if c_i % 2 == 0 else Color("#a38358")) * modulate_col)

	var pole_base := plaza_center + Vector2(-15.0, -6.0)
	var pole_top := pole_base + Vector2(0.0, -26.0)
	ci.draw_circle(pole_base + Vector2(0.0, 1.5), 3.6, Color(0.0, 0.0, 0.0, 0.32) * modulate_col)
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

	var ring_r := plinth_r + 5.0
	EvoWorldOverlayRenderer.draw_ellipse_outline(ci, plaza_center, ring_r, ring_r * 0.58, status_col * modulate_col, 3.4)


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


static func collect_village_building_props(village: Dictionary, props: Array[Prop]) -> void:
	var deme: EvoTypes.Deme = village["deme"]
	var v_pos: Vector2 = village["pos"]
	var m: Color = village["modulate"]
	var eff_tier: int = deme.get_village_tier()
	var c_count := deme.cultural_trait_ids.size()
	var arch := str(village["archetype"])
	var flags: int = (
		(1 if bool(village.get("has_pact", false)) else 0)
		| (2 if bool(village.get("in_war", false)) else 0)
		| (4 if bool(village.get("in_raid", false)) else 0)
		| (8 if bool(village.get("in_betrayal", false)) else 0)
		| (16 if bool(village.get("in_tribute", false)) else 0)
		| (32 if bool(village.get("in_siege", false)) else 0)
	)
	var vp_key: Array = [
		eff_tier,
		c_count,
		arch,
		flags,
		deme.defense_tier,
		deme.merged_count,
		deme.walled_union_id,
		snappedf(deme.salubrity, 0.05),
		m,
		v_pos
	]
	if deme.has_meta("_vp_key") and (deme.get_meta("_vp_key") as Array) == vp_key:
		props.append_array(deme.get_meta("_vp_val") as Array[Prop])
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
	deme.set_meta("_vp_key", vp_key)
	deme.set_meta("_vp_val", v_props)
	props.append_array(v_props)


static func _draw_settlement_props(village: Dictionary, props: Array[Prop]) -> void:
	var deme: EvoTypes.Deme = village["deme"]
	var v_world: Vector2 = village["world_xy"]
	var v_pos: Vector2 = village["pos"]
	var top_z: float = village["top_z"]
	var m: Color = village["modulate"]
	if bool(village.get("has_pact", false)):
		var off := Vector2(-36, 30)
		var p := world_prop("prop_pact_totem", v_world, top_z, off, 2.15, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if deme.merged_count > 0 or deme.walled_union_id != "":
		var off := Vector2(36, 30)
		var p := world_prop("prop_unity_monument", v_world, top_z, off, 2.15, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_war", false)):
		var off := Vector2(-58, 12)
		var p := world_prop("prop_war_banner", v_world, top_z, off, 2.25, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_raid", false)):
		var off := Vector2(58, 12)
		var p := world_prop("prop_raid_loot", v_world, top_z, off, 2.15, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_tribute", false)):
		var off := Vector2(56, 16)
		var p := world_prop("prop_tribute_chest", v_world, top_z, off, 2.10, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_siege", false)):
		var off := Vector2(-66, 18)
		var p := world_prop("prop_siege_engine", v_world, top_z, off, 2.25, m)
		p.set_foot(v_pos + off)
		props.append(p)
	if bool(village.get("in_betrayal", false)):
		var off := Vector2(0, -28)
		var p := world_prop("prop_betrayal_ruin", v_world, top_z, off, 2.20, m)
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
			"in_merge": d.merged_count > 0 or d.walled_union_id != "",
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
		if d.merged_count > 0 or d.walled_union_id != "" or bool(entry["in_merge"]):
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
			if prop.trim_color.a > 0.0:
				var trim_rect := Rect2(
					prop.rect.position + Vector2(prop.rect.size.x * 0.30, prop.rect.size.y * 0.44),
					Vector2(prop.rect.size.x * 0.40, maxf(2.0, prop.rect.size.y * 0.06))
				)
				r._anim_layer.draw_rect(trim_rect, prop.trim_color, true)
		return
	var moving := collect_moving_props(r)
	moving.sort_custom(func(a: Prop, b: Prop) -> bool: return a.y < b.y)
	var m_idx := 0
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
	var rect := prop.rect
	if prop.sways:
		rect.position.x += sin(r._anim_time * 2.1 + prop.sway_phase) * 1.15
	r._anim_layer.draw_texture_rect(prop.texture, rect, false, prop.modulate)
	if prop.trim_color.a > 0.0:
		var trim_rect := Rect2(
			rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.44),
			Vector2(rect.size.x * 0.40, maxf(2.0, rect.size.y * 0.06))
		)
		r._anim_layer.draw_rect(trim_rect, prop.trim_color, true)


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
		var strat_color: Color = village["strat_color"]
		var cape_trim := strat_color.lightened(0.25) * m
		if int(village["tier"]) == 1:
			var fire_sprite := "tier1_campfire" if int(anim_time * 5.0) % 2 == 0 else "tier1_campfire_2"
			props.append(acquire_moving_prop(r, EvoPixelArtGen.get_texture(fire_sprite), v_pos + Vector2(0, 6), 2.35, 0.78, m))

		var villager_count: int = village["villager_count"]
		var v_textures: Array = village.get("villager_textures", [])
		for v_idx in range(villager_count):
			var orbit_angle := anim_time * (0.90 + float(v_idx % 3) * 0.20) + float(v_idx) * (TAU / float(villager_count))
			var orbit_r := 34.0 + float(v_idx % 4) * 14.0
			var foot := v_pos + Vector2(cos(orbit_angle) * orbit_r, sin(orbit_angle) * (orbit_r * 0.56) + 9.0)
			var frame := int((anim_time * 6.0) + float(v_idx)) % 3
			var v_prop := acquire_moving_prop(r, v_textures[frame] as ImageTexture, foot, 2.55, 0.85, m)
			v_prop.trim_color = cape_trim
			props.append(v_prop)

	for r_idx in range(r._roads.size()):
		var road: Dictionary = r._roads[r_idx]
		if not TRAVELER_ROAD_KINDS.has(road["kind"]) or not road["show_traffic"]:
			continue
		var p_a: Vector2 = road["p_a"]
		var p_b: Vector2 = road["p_b"]
		if not vis_rect.has_point(p_a) and not vis_rect.has_point(p_b):
			continue
		var curve_f: float = float(road["curve_factor"])
		var r_textures: Array[ImageTexture] = road["villager_textures"]
		if road["kind"] == "rural_farm":
			var raw_wagon := fposmod(anim_time * 0.22 + float(r_idx) * 0.37, 1.0)
			var t_wagon := lerpf(0.22, 0.82, raw_wagon)
			var w_foot := EvoRoadNetworkRenderer.sample_road_curve(p_a, p_b, t_wagon, 1.0, curve_f)
			props.append(acquire_moving_prop(r, EvoPixelArtGen.get_texture("covered_wagon"), w_foot, 1.85, 0.82, Color.WHITE))
		for traveler_i in range(2):
			var raw_walk := fposmod(anim_time * 0.24 + float(r_idx) * 0.31 + float(traveler_i) * 0.48, 1.0)
			if traveler_i == 1:
				raw_walk = 1.0 - raw_walk
			var t_walk := lerpf(0.24, 0.76, raw_walk)
			var foot := EvoRoadNetworkRenderer.sample_road_curve(p_a, p_b, t_walk, 1.0, curve_f)
			var frame := int((anim_time * 6.5) + float(traveler_i + r_idx)) % 3
			props.append(acquire_moving_prop(r, r_textures[frame], foot, 2.50, 0.85, Color.WHITE))
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
