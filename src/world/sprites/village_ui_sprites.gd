class_name EvoVillageUiSprites
extends EvoPixelCanvas

const C_TINT_CLOTH := Color("#f0e9df")


static func draw_village_or_ui_sprite(sprite_name: String) -> Image:
	match sprite_name:
		"tent", "tier1_tent":
			return _draw_tent()
		"hut", "hut_thatch":
			return _draw_hut_thatch()
		"campfire", "tier1_campfire":
			return _draw_campfire(0)
		"tier1_campfire_2":
			return _draw_campfire(1)
		"house_clay", "tier2_cottage":
			return _draw_house_clay()
		"longhouse":
			return _draw_longhouse()
		"granary", "tier2_barn":
			return _draw_granary()
		"temple", "temple_totem":
			return _draw_temple_totem()
		"hall", "tier3_townhall":
			return _draw_townhall()
		"house", "house_stone", "tier3_house":
			return _draw_house_stone()
		"market", "act_exchange":
			return _draw_market()
		"citadel", "citadel_keep", "tier4_citadel":
			return _draw_citadel_keep()
		"windmill", "tier4_windmill":
			return _draw_windmill()
		"tower", "watchtower", "tier4_tower", "prop_defense_fortress":
			return _draw_watchtower()
		"cathedral", "tier5_metropolis":
			return _draw_cathedral()
		"dock":
			return _draw_dock()
		"prop_unity_monument":
			return _draw_prop_unity_monument()
		"palisade", "palisade_wall", "prop_defense_palisade":
			return _draw_palisade_wall()
		"stone_wall", "prop_defense_wall":
			return _draw_stone_wall()
		"prop_tribute_chest":
			return _draw_prop_tribute_chest()
		"siege_totem", "prop_siege_engine":
			return _draw_prop_siege_engine()
		"crop_field", "crops_wheat", "act_forage":
			return _draw_crop_field()
		"pasture_pen", "pasture_meadow":
			return _draw_pasture_pen()
		"act_overexploit":
			return _draw_act_overexploit()
		"covered_wagon", "settler_wagon", "act_migrate":
			return _draw_covered_wagon()
		"trader_cart", "caravan_cart":
			return _draw_trader_cart(C_TINT_CLOTH)
		"totem_coop", "act_cooperate":
			return _draw_totem_pole(Color("#10b981"), Color("#fbbf24"))
		"totem_aggro", "act_dispute":
			return _draw_totem_pole(Color("#ef4444"), Color("#f97316"))
		"totem_innov", "cultural_totem", "act_innovate", "act_custom":
			return _draw_totem_pole(Color("#2a9d8f"), Color("#e9c46a"))
		"ruins_stone", "ruins":
			return _draw_ruins_stone()
		"prop_betrayal_ruin", "act_betrayal":
			return _draw_prop_betrayal_ruin()
		"barricade_spikes":
			return _draw_barricade_spikes()
		"road_block_sign":
			return _draw_road_block_sign()
		"road_lantern":
			return _draw_road_lantern()
		"prop_war_banner", "act_war":
			return _draw_prop_war_banner()
		"prop_raid_loot", "act_raid":
			return _draw_prop_raid_loot()
		"prop_pact_totem", "act_pact":
			return _draw_prop_pact_totem()
		"effect_battle_sparks":
			return _draw_effect_battle_sparks()
		"villager_idle":
			return draw_villager_unit("villager_idle", C_TINT_CLOTH)
		"villager_walk1", "villager_walk_1":
			return draw_villager_unit("villager_walk_1", C_TINT_CLOTH)
		"villager_walk2", "villager_walk_2":
			return draw_villager_unit("villager_walk_2", C_TINT_CLOTH)
		"villager_work":
			return draw_villager_unit("villager_work", C_TINT_CLOTH)
		"traveler":
			return draw_villager_unit("traveler", C_TINT_CLOTH)
		"raider":
			return draw_villager_unit("raider", C_TINT_CLOTH)
		_:
			return EvoUiIconSprites.draw_ui_icon_sprite(sprite_name)


# 1a. Tier I Humble Nomad Hide Tent (conical stitched buckskin & crossed poles)
static func _draw_tent() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 105.0, 44.0, 15.0, 0.38)

	# Protruding crossed wooden tent poles at apex
	_aa_line(img, 55.0, 14.0, 69.0, 36.0, C_OUTLINE, 5.2)
	_aa_line(img, 55.0, 14.0, 69.0, 36.0, Color("#9e6639"), 2.8)
	_aa_line(img, 73.0, 14.0, 59.0, 36.0, C_OUTLINE, 5.2)
	_aa_line(img, 73.0, 14.0, 59.0, 36.0, Color("#734522"), 2.8)
	_aa_line(img, 59.0, 18.0, 69.0, 32.0, Color("#85522a"), 2.2)

	# Guy ropes & wooden ground pegs
	_aa_line(img, 36.0, 74.0, 18.0, 100.0, Color("#6e4c2e"), 1.6)
	_aa_line(img, 92.0, 74.0, 110.0, 100.0, Color("#4f351f"), 1.6)
	_aa_line(img, 18.0, 96.0, 18.0, 104.0, C_OUTLINE, 3.0)
	_aa_line(img, 110.0, 96.0, 110.0, 104.0, C_OUTLINE, 3.0)

	# Sunlit left hide panel (135 deg warm buckskin) & cool shaded right hide panel
	var hide_left := PackedVector2Array([
		Vector2(64, 26), Vector2(64, 108), Vector2(40, 105), Vector2(24, 95)
	])
	var hide_right := PackedVector2Array([
		Vector2(64, 26), Vector2(104, 95), Vector2(88, 105), Vector2(64, 108)
	])
	_poly_outlined(img, hide_left, Color("#ebcfa4"), Color("#c79f6d"), C_OUTLINE, 2.4)
	_poly_outlined(img, hide_right, Color("#b89368"), Color("#876744"), C_OUTLINE, 2.4)

	# Stitched leather patch seams & warm ochre tribal trim band
	_aa_line(img, 58.0, 36.0, 34.0, 98.0, Color("#784f2b"), 1.6)
	_aa_line(img, 70.0, 36.0, 94.0, 98.0, Color("#57371c"), 1.6)
	var trim_l := PackedVector2Array([
		Vector2(29, 86), Vector2(64, 95), Vector2(64, 102), Vector2(26, 92)
	])
	var trim_r := PackedVector2Array([
		Vector2(64, 95), Vector2(99, 86), Vector2(102, 92), Vector2(64, 102)
	])
	_poly_filled(img, trim_l, Color("#d97706"), Color("#b45309"))
	_poly_filled(img, trim_r, Color("#9a3412"), Color("#7c2d12"))

	# Smoke vent collar at crown
	var vent := PackedVector2Array([
		Vector2(57, 36), Vector2(64, 25), Vector2(71, 36), Vector2(64, 41)
	])
	_poly_outlined(img, vent, Color("#452712"), Color("#291508"), C_OUTLINE, 2.0)

	# Entrance opening with warm interior firelight & tied-back fur flap
	var opening := PackedVector2Array([
		Vector2(50, 106), Vector2(58, 66), Vector2(68, 68), Vector2(64, 108)
	])
	_poly_outlined(img, opening, Color("#b45309"), Color("#3b1d0a"), C_OUTLINE, 2.2)
	_aa_ellipse(img, 58.0, 96.0, 5.5, 8.0, Color(0.99, 0.78, 0.25, 0.55))
	var flap := PackedVector2Array([
		Vector2(44, 98), Vector2(58, 66), Vector2(52, 68), Vector2(39, 95)
	])
	_poly_outlined(img, flap, Color("#f5e1c0"), Color("#cfa878"), C_OUTLINE, 2.0)
	return img


# 1b. Tier I/II Rustic Wattle-and-Daub Round Thatched Hut
static func _draw_hut_thatch() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 46.0, 16.0, 0.38)

	# Stone footing plinth
	var plinth_l := PackedVector2Array([
		Vector2(26, 95), Vector2(64, 108), Vector2(64, 102), Vector2(26, 90)
	])
	var plinth_r := PackedVector2Array([
		Vector2(64, 108), Vector2(102, 95), Vector2(102, 90), Vector2(64, 102)
	])
	_poly_outlined(img, plinth_l, Color("#a8a29e"), Color("#78716c"), C_OUTLINE, 2.0)
	_poly_outlined(img, plinth_r, Color("#78716c"), Color("#57534e"), C_OUTLINE, 2.0)

	# Cylindrical wattle-and-daub walls (warm sunlit left, cool shaded right)
	var wall_l := PackedVector2Array([
		Vector2(28, 64), Vector2(64, 73), Vector2(64, 103), Vector2(28, 91)
	])
	var wall_r := PackedVector2Array([
		Vector2(64, 73), Vector2(100, 64), Vector2(100, 91), Vector2(64, 103)
	])
	_poly_outlined(img, wall_l, Color("#f4ead5"), Color("#dfd0b4"), C_OUTLINE, 2.3)
	_poly_outlined(img, wall_r, Color("#c9bba3"), Color("#9e907a"), C_OUTLINE, 2.3)

	# Exposed vertical timber studs + cast shadow under thatch eaves
	for sx_v in [38.0, 52.0, 76.0, 90.0]:
		var sx: float = float(sx_v)
		var y_off: float = (64.0 - absf(sx - 64.0)) * 0.24
		_aa_line(img, sx, 65.0 + y_off, sx, 92.0 + y_off, Color("#5c3a1e"), 2.4)
	_poly_filled(
		img,
		PackedVector2Array([Vector2(28, 64), Vector2(64, 74), Vector2(100, 64), Vector2(100, 71), Vector2(64, 81), Vector2(28, 71)]),
		Color(0.07, 0.04, 0.02, 0.36),
		Color(0.07, 0.04, 0.02, 0.05)
	)

	# Timber plank door on front-left & warm amber window on right
	var door := PackedVector2Array([
		Vector2(41, 97), Vector2(55, 101), Vector2(55, 76), Vector2(41, 72)
	])
	_poly_outlined(img, door, Color("#784822"), Color("#4a2b12"), C_OUTLINE, 2.1)
	_aa_line(img, 48.0, 74.0, 48.0, 99.0, C_OUTLINE, 1.5)
	_draw_iso_window(img, 81.0, 82.0, 5.5, 5.5, true, Color("#fef08a"), Color("#d97706"))

	# Thick overhanging conical golden straw thatch roof (135 deg lit left vs shaded right)
	var roof_l := PackedVector2Array([
		Vector2(64, 24), Vector2(64, 76), Vector2(40, 71), Vector2(18, 63)
	])
	var roof_r := PackedVector2Array([
		Vector2(64, 24), Vector2(110, 63), Vector2(88, 71), Vector2(64, 76)
	])
	_poly_outlined(img, roof_l, Color("#f7d56e"), Color("#dbb043"), C_OUTLINE, 2.5)
	_poly_outlined(img, roof_r, Color("#cfa138"), Color("#996f1d"), C_OUTLINE, 2.5)

	# Layered straw thatch bundle strokes
	for r_i in range(1, 4):
		var t := float(r_i) / 4.0
		var y_ring := lerpf(28.0, 68.0, t)
		var hw := lerpf(8.0, 40.0, t)
		_aa_line(img, 64.0 - hw, y_ring - 2.0, 64.0, y_ring + 4.0 * t, Color("#b88725"), 1.6)
		_aa_line(img, 64.0, y_ring + 4.0 * t, 64.0 + hw, y_ring - 2.0, Color("#785313"), 1.6)

	# Bound straw cap & wooden smoke ring at apex
	_aa_ellipse_outlined(img, 64.0, 26.0, 10.5, 4.8, Color("#7c4d25"), C_OUTLINE, 2.1)
	_aa_ellipse(img, 64.0, 26.0, 5.5, 2.2, Color("#2b1708"))
	return img


# 2. Blazing Hearth Campfire with Stone Ring, Logs & Sparks
static func _draw_campfire(frame: int) -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 104.0, 38.0, 13.5, 0.36)
	_aa_ellipse(img, 64.0, 99.0, 44.0, 17.0, Color(0.99, 0.62, 0.14, 0.28))

	# Ring of faceted hearth cobbles
	var stones: Array[Vector2] = [
		Vector2(30, 96), Vector2(42, 106), Vector2(64, 110),
		Vector2(86, 106), Vector2(98, 96), Vector2(86, 86), Vector2(42, 86)
	]
	for st in stones:
		var sunlit := st.x <= 64.0
		_aa_ellipse_outlined(
			img, st.x, st.y, 8.5, 5.5,
			Color("#a8a29e") if sunlit else Color("#6b7280"),
			C_OUTLINE, 1.9
		)

	# Glowing crimson-orange ember bed
	_aa_ellipse(img, 64.0, 96.0, 24.0, 9.5, Color("#dc2626"))
	_aa_ellipse(img, 64.0, 96.0, 16.0, 6.0, Color("#f97316"))

	# Radial split oak firewood logs
	var logs := [
		[Vector2(32, 99), Vector2(64, 92), Color("#9c6034")],
		[Vector2(96, 99), Vector2(64, 92), Color("#6e3f1e")],
		[Vector2(42, 107), Vector2(64, 94), Color("#8c5228")],
		[Vector2(86, 107), Vector2(64, 94), Color("#5c3418")]
	]
	for lg in logs:
		var p0: Vector2 = lg[0]
		var p1: Vector2 = lg[1]
		var lc: Color = lg[2]
		_aa_line(img, p0.x, p0.y, p1.x, p1.y, C_OUTLINE, 11.5)
		_aa_line(img, p0.x, p0.y, p1.x, p1.y, lc, 7.5)
		_aa_circle_outlined(img, p0.x, p0.y, 4.8, Color("#e8c391"), C_OUTLINE, 1.8)

	var shift := -3.5 if frame == 0 else 3.5
	var outer_flame := PackedVector2Array([
		Vector2(41, 94), Vector2(37, 68), Vector2(50, 50),
		Vector2(64.0 + shift, 22.0), Vector2(78, 49), Vector2(91, 68), Vector2(87, 94)
	])
	_poly_outlined(img, outer_flame, Color("#f97316"), Color("#dc2626"), C_OUTLINE, 2.2)

	var mid_flame := PackedVector2Array([
		Vector2(48, 94), Vector2(46, 70), Vector2(64.0 - shift * 0.6, 36.0),
		Vector2(82, 70), Vector2(80, 94)
	])
	_poly_filled(img, mid_flame, Color("#fde047"), Color("#f59e0b"))

	var inner_flame := PackedVector2Array([
		Vector2(55, 94), Vector2(64.0 + shift * 0.25, 56.0), Vector2(73, 94)
	])
	_poly_filled(img, inner_flame, Color("#ffffff"), Color("#fef08a"))

	# Rising glowing sparks
	_aa_circle(img, 54.0 - shift, 28.0, 2.2, Color("#fde047"))
	_aa_circle(img, 75.0 - shift, 34.0, 1.8, Color("#fb923c"))
	return img


# 3a. Tier II Rustic Cob & Timber Cottage
static func _draw_house_clay() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 48.0, 18.0, 0.39)

	# Stone foundation plinth + warm clay/timber walls (left warm lit, right cool shade)
	_draw_isometric_box(
		img, 64.0, 111.0, 38.0, 36.0, 7.0,
		Color("#8c857e"), Color("#a8a29e"), Color("#6b6661"), 2.2
	)
	_draw_isometric_box(
		img, 64.0, 104.0, 37.0, 35.0, 28.0,
		Color("#b89b78"), Color("#e8d3b3"), Color("#b59b7c"), 2.4
	)

	# Corner & horizontal timber beams
	_aa_line(img, 27.0, 85.5, 64.0, 104.0, Color("#5c3a1e"), 2.8)
	_aa_line(img, 64.0, 104.0, 99.0, 86.5, Color("#472c16"), 2.8)
	_aa_line(img, 27.0, 71.5, 64.0, 90.0, Color("#6e4523"), 2.2)
	_aa_line(img, 64.0, 90.0, 99.0, 72.5, Color("#4f3018"), 2.2)

	# Stone chimney on back-left slope
	_draw_isometric_box(
		img, 52.0, 48.0, 8.5, 8.5, 19.0,
		Color("#d6d3d1"), Color("#a8a29e"), Color("#6b7280"), 2.0
	)

	# Overhanging wood-shingle & thatch pitched roof with courses
	_draw_pitched_roof(
		img, 64.0, 77.0, 42.0, 40.0, 26.0,
		Color("#b87c44"), Color("#855329"), Color("#dec6a4"), 2.4
	)
	_draw_roof_courses(img, 64.0, 77.0, 42.0, 40.0, 26.0, 4, Color("#5c3718"), Color("#ab703c"), false)

	# Plank door with iron hinges on sunlit left wall + warm amber window on right wall
	var door := PackedVector2Array([
		Vector2(41, 99), Vector2(52, 104.5), Vector2(52, 83), Vector2(41, 77.5)
	])
	_poly_outlined(img, door, Color("#734420"), Color("#452711"), C_OUTLINE, 2.0)
	_aa_line(img, 42.0, 85.0, 49.0, 88.5, Color("#334155"), 1.6)
	_aa_line(img, 42.0, 94.0, 49.0, 97.5, Color("#334155"), 1.6)
	_draw_iso_window(img, 81.0, 85.0, 6.5, 6.0, true, Color("#fef08a"), Color("#d97706"))
	return img


# 3b. Tier II Communal Timber Longhouse (elongated hall with carved gable finials)
static func _draw_longhouse() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 120.0, 58.0, 21.0, 0.40)

	# Elongated stone base & sturdy oak plank hall (short front-left w=30, long depth d=54)
	_draw_isometric_box(
		img, 62.0, 125.0, 30.0, 54.0, 7.0,
		Color("#8c857e"), Color("#a8a29e"), Color("#686460"), 2.2
	)
	_draw_isometric_box(
		img, 62.0, 118.0, 29.0, 53.0, 28.0,
		Color("#8c582e"), Color("#ba7e49"), Color("#784b27"), 2.4
	)

	# Vertical structural timber posts along the long right wall
	for step_i in range(1, 4):
		var u := float(step_i) / 4.0
		var px_p := lerpf(62.0, 115.0, u)
		var py_p := lerpf(118.0, 91.5, u)
		_aa_line(img, px_p, py_p, px_p, py_p - 28.0, Color("#4a2c14"), 2.6)

	# Steep overhanging thatch-and-timber roof with straw courses
	_draw_pitched_roof(
		img, 62.0, 90.0, 34.0, 57.0, 28.0,
		Color("#ebb952"), Color("#ab7c26"), Color("#9e6637"), 2.5
	)
	_draw_roof_courses(img, 62.0, 90.0, 34.0, 57.0, 28.0, 4, Color("#785314"), Color("#d9a742"), true)

	# Crossed carved timber gable horns at front peak (45, 53.5)
	var peak := Vector2(45.0, 53.5)
	_aa_line(img, peak.x - 6.0, peak.y - 8.0, peak.x + 5.0, peak.y + 4.0, C_OUTLINE, 4.6)
	_aa_line(img, peak.x - 6.0, peak.y - 8.0, peak.x + 5.0, peak.y + 4.0, Color("#d9a05b"), 2.4)
	_aa_line(img, peak.x + 6.0, peak.y - 8.0, peak.x - 5.0, peak.y + 4.0, C_OUTLINE, 4.6)
	_aa_line(img, peak.x + 6.0, peak.y - 8.0, peak.x - 5.0, peak.y + 4.0, Color("#b0763c"), 2.4)

	# Warm hearth portal on sunlit front-left gable + 2 amber windows along long wall
	var portal := PackedVector2Array([
		Vector2(42, 108), Vector2(53, 113.5), Vector2(53, 91), Vector2(47.5, 86), Vector2(42, 87)
	])
	_poly_outlined(img, portal, Color("#f59e0b"), Color("#78350f"), C_OUTLINE, 2.1)
	_draw_iso_window(img, 78.0, 98.0, 5.5, 5.5, true, Color("#fef08a"), Color("#d97706"))
	_draw_iso_window(img, 99.0, 87.5, 5.5, 5.5, true, Color("#fef08a"), Color("#d97706"))
	return img


# 4. Tier II Elevated Timber Granary Barn with Golden Thatch Roof & Grain Sacks
static func _draw_granary() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 122.0, 56.0, 20.0, 0.39)

	# Corner staddle stones elevating the granary floor
	for st in [Vector2(30, 104), Vector2(72, 125), Vector2(114, 104)]:
		_draw_isometric_box(
			img, st.x, st.y, 7.0, 7.0, 8.0,
			Color("#cbd5e1"), Color("#a8a29e"), Color("#64748b"), 1.8
		)

	# Timber granary walls (sunlit honey-oak left, cool umber right)
	_draw_isometric_box(
		img, 72.0, 119.0, 44.0, 44.0, 34.0,
		Color("#8c582e"), Color("#ba7d45"), Color("#784925"), 2.5
	)
	# Diagonal X-timber bracing on right wall
	_aa_line(img, 74.0, 117.0, 114.0, 65.0, Color("#4a2c14"), 2.6)
	_aa_line(img, 74.0, 87.0, 114.0, 97.0, Color("#4a2c14"), 2.6)

	# Double barn doors on front-left wall
	var doors := PackedVector2Array([
		Vector2(39, 102.5), Vector2(61, 113.5), Vector2(61, 88), Vector2(39, 77)
	])
	_poly_outlined(img, doors, Color("#8f572b"), Color("#593418"), C_OUTLINE, 2.2)
	_aa_line(img, 50.0, 82.5, 50.0, 108.0, C_OUTLINE, 2.0)

	# Steep golden straw thatched roof with rich straw courses
	_draw_pitched_roof(
		img, 72.0, 85.0, 48.0, 48.0, 31.0,
		Color("#fae078"), Color("#cfa02e"), Color("#996234"), 2.6
	)
	_draw_roof_courses(img, 72.0, 85.0, 48.0, 48.0, 31.0, 5, Color("#8f6816"), Color("#fce992"), true)

	# Upper gable hoist beam & pulley
	_aa_line(img, 48.0, 43.0, 38.0, 48.0, C_OUTLINE, 4.5)
	_aa_line(img, 48.0, 43.0, 38.0, 48.0, Color("#784820"), 2.4)

	# Plump tied golden grain sacks & oak barrel beside right wall
	_aa_ellipse_outlined(img, 86.0, 116.0, 8.5, 9.5, Color("#e8cfa0"), C_OUTLINE, 2.0)
	_aa_ellipse(img, 86.0, 107.0, 5.0, 2.8, Color("#eab308"))
	_aa_ellipse_outlined(img, 99.0, 110.0, 8.0, 10.0, Color("#784822"), C_OUTLINE, 2.0)
	_aa_line(img, 92.0, 108.0, 106.0, 108.0, Color("#334155"), 1.8)
	return img


# 5. Tier III Urban 2-Story Half-Timbered House with Terracotta Tile Roof
static func _draw_house_stone() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 54.0, 19.5, 0.40)

	# Dressed ashlar ground-story plinth
	_draw_isometric_box(
		img, 72.0, 127.0, 40.0, 38.0, 18.0,
		Color("#a8a29e"), Color("#d6d0c4"), Color("#8c867e"), 2.4
	)

	# Slightly overhanging upper half-timbered jetty story (warm cream left, cool taupe right)
	_draw_isometric_box(
		img, 72.0, 109.0, 43.0, 41.0, 30.0,
		Color("#d6c5ab"), Color("#f7edd9"), Color("#c7baa6"), 2.5
	)

	# Exposed dark-oak half-timber framing & diagonal braces
	_aa_line(img, 29.0, 87.5, 72.0, 109.0, Color("#452915"), 3.4)
	_aa_line(img, 72.0, 109.0, 113.0, 88.5, Color("#382010"), 3.4)
	for vx_v in [43.0, 58.0]:
		var vx: float = float(vx_v)
		var vy: float = 109.0 - (72.0 - vx) * 0.5
		_aa_line(img, vx, vy, vx, vy - 30.0, Color("#452915"), 2.8)
	for vx_v in [86.0, 100.0]:
		var vx: float = float(vx_v)
		var vy: float = 109.0 - (vx - 72.0) * 0.5
		_aa_line(img, vx, vy, vx, vy - 30.0, Color("#382010"), 2.8)
	_aa_line(img, 29.0, 87.5, 43.0, 64.5, Color("#452915"), 2.2)
	_aa_line(img, 100.0, 95.0, 113.0, 58.5, Color("#382010"), 2.2)

	# Brick/stone chimney at rear
	_draw_isometric_box(
		img, 62.0, 42.0, 8.5, 8.5, 20.0,
		Color("#d97757"), Color("#b85a3a"), Color("#7c3822"), 2.0
	)

	# Steep terracotta clay-tiled roof with crisp courses
	_draw_pitched_roof(
		img, 72.0, 79.0, 47.0, 45.0, 33.0,
		Color("#db7348"), Color("#a64b29"), Color("#efe3ce"), 2.6
	)
	_draw_roof_courses(img, 72.0, 79.0, 47.0, 45.0, 33.0, 5, Color("#732f16"), Color("#ed8f66"), false)

	# Arched oak street door on stone ground story + glowing leaded amber windows above
	var door := PackedVector2Array([
		Vector2(47, 114.5), Vector2(57, 119.5), Vector2(57, 104), Vector2(52, 99.5), Vector2(47, 101)
	])
	_poly_outlined(img, door, Color("#6e401e"), Color("#3d220e"), C_OUTLINE, 2.0)
	_draw_iso_window(img, 50.5, 86.0, 5.8, 6.2, false, Color("#fef08a"), Color("#d97706"))
	_draw_iso_window(img, 79.5, 92.0, 5.5, 6.0, true, Color("#fef08a"), Color("#d97706"))
	_draw_iso_window(img, 93.0, 85.0, 5.5, 6.0, true, Color("#fef08a"), Color("#d97706"))
	return img


# 6a. Tier III Urban Market Pavilion with Striped Canopy & Trade Goods
static func _draw_market() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 120.0, 56.0, 20.0, 0.38)

	# Cobblestone market plinth
	_draw_isometric_box(
		img, 72.0, 125.0, 46.0, 42.0, 6.0,
		Color("#d6d0c4"), Color("#b8b0a2"), Color("#857f74"), 2.2
	)

	# Timber display counters along front-left and front-right
	_draw_isometric_box(
		img, 54.0, 114.0, 22.0, 12.0, 14.0,
		Color("#deb887"), Color("#b07844"), Color("#784c26"), 2.1
	)
	_draw_isometric_box(
		img, 90.0, 112.0, 12.0, 22.0, 14.0,
		Color("#deb887"), Color("#a66e3c"), Color("#6e4420"), 2.1
	)

	# Produce baskets, golden grain, red apples & terracotta amphora
	_aa_ellipse_outlined(img, 48.0, 97.0, 7.5, 5.0, Color("#fbbf24"), C_OUTLINE, 1.8)
	_aa_ellipse_outlined(img, 60.0, 100.0, 7.0, 4.8, Color("#ef4444"), C_OUTLINE, 1.8)
	_aa_ellipse_outlined(img, 88.0, 95.0, 7.5, 5.0, Color("#10b981"), C_OUTLINE, 1.8)
	_aa_ellipse_outlined(img, 72.0, 116.0, 6.5, 9.0, Color("#c9643b"), C_OUTLINE, 1.9)

	# Four heavy oak corner posts supporting the canopy
	for post_x in [32.0, 70.0, 108.0]:
		var py_b: float = 118.0 if post_x == 70.0 else 99.0
		_aa_line(img, post_x, py_b, post_x, py_b - 38.0, C_OUTLINE, 6.0)
		_aa_line(img, post_x, py_b, post_x, py_b - 38.0, Color("#8c562b"), 3.4)

	# Festive crimson-and-ivory striped pitched market canopy
	_draw_pitched_roof(
		img, 72.0, 80.0, 46.0, 42.0, 24.0,
		Color("#ef4444"), Color("#dc2626"), Color("#fef3c7"), 2.4
	)
	# Cream stripes across front-right canopy slope
	var p_front := Vector2(49.0, 44.5)
	var p_back := Vector2(91.0, 23.5)
	var e_front := Vector2(72.0, 80.0)
	var e_right := Vector2(114.0, 59.0)
	for s_i in [1, 3]:
		var t0 := float(s_i) / 5.0
		var t1 := float(s_i + 1) / 5.0
		var stripe := PackedVector2Array([
			p_front.lerp(p_back, t0),
			p_front.lerp(p_back, t1),
			e_front.lerp(e_right, t1),
			e_front.lerp(e_right, t0)
		])
		_poly_filled(img, stripe, Color("#fef3c7"), Color("#dfd3bc"))

	# Scalloped valance trim under canopy eaves
	_aa_line(img, 26.0, 57.0, 72.0, 80.0, Color("#fbbf24"), 2.4)
	_aa_line(img, 72.0, 80.0, 114.0, 59.0, Color("#d97706"), 2.4)
	return img


# 6b. Tier III Sacred Stone Sanctuary Temple with Bell Turret & Solar Finial
static func _draw_temple_totem() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 54.0, 19.5, 0.40)

	# Stepped stone sanctuary podium
	_draw_isometric_box(
		img, 66.0, 128.0, 40.0, 44.0, 7.0,
		Color("#d6d0c4"), Color("#e8e0d2"), Color("#9e988e"), 2.2
	)

	# Slender rear bell tower shaft, spire & golden solar emblem
	_draw_isometric_box(
		img, 90.0, 96.0, 20.0, 20.0, 56.0,
		Color("#d6c5ab"), Color("#f2e8d5"), Color("#b5aa99"), 2.4
	)
	var spire_l := PackedVector2Array([Vector2(70, 30), Vector2(90, 12), Vector2(90, 40)])
	var spire_r := PackedVector2Array([Vector2(90, 12), Vector2(110, 30), Vector2(90, 40)])
	_poly_outlined(img, spire_l, Color("#d98a4e"), Color("#ab6430"), C_OUTLINE, 2.3)
	_poly_outlined(img, spire_r, Color("#9e5827"), Color("#6e3a16"), C_OUTLINE, 2.3)
	_aa_circle_outlined(img, 90.0, 8.0, 4.5, Color("#fde047"), C_OUTLINE, 1.8)
	_draw_iso_window(img, 80.0, 52.0, 4.5, 6.5, false, Color("#fef08a"), Color("#d97706"))

	# Main stone sanctuary nave & terracotta roof with courses
	_draw_isometric_box(
		img, 64.0, 121.0, 36.0, 40.0, 33.0,
		Color("#dfd5c4"), Color("#f5ecdc"), Color("#bfb4a2"), 2.5
	)
	# Fluted stone pilasters on sunlit facade
	for px_v in [34.0, 56.0]:
		var px_f: float = float(px_v)
		var py_f: float = 121.0 - (64.0 - px_f) * 0.5
		_aa_line(img, px_f, py_f, px_f, py_f - 32.0, Color("#fffbf2"), 2.4)

	_draw_pitched_roof(
		img, 64.0, 88.0, 40.0, 43.0, 26.0,
		Color("#d97f4a"), Color("#9e532b"), Color("#efe5d4"), 2.5
	)
	_draw_roof_courses(img, 64.0, 88.0, 40.0, 43.0, 26.0, 4, Color("#6e3416"), Color("#eb9966"), false)

	# Arched sanctuary portal + warm amber lancet windows
	var portal := PackedVector2Array([
		Vector2(40, 109), Vector2(51, 114.5), Vector2(51, 95), Vector2(45.5, 90), Vector2(40, 91)
	])
	_poly_outlined(img, portal, Color("#855228"), Color("#4a2b12"), C_OUTLINE, 2.1)
	_draw_iso_window(img, 76.0, 100.0, 4.8, 7.0, true, Color("#fef08a"), Color("#f59e0b"))
	_draw_iso_window(img, 91.0, 92.5, 4.8, 7.0, true, Color("#fef08a"), Color("#f59e0b"))
	return img


# 6c. Tier III Civic Town Hall / Guildhall with Stone Arcade & Slate Belfry
static func _draw_townhall() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 58.0, 20.5, 0.41)

	# Ground-floor dressed limestone arcade loggia
	_draw_isometric_box(
		img, 72.0, 127.0, 44.0, 44.0, 20.0,
		Color("#cbd5e1"), Color("#e8e2d5"), Color("#9c9890"), 2.4
	)
	# Dark arched colonnade bays along right facade
	for arch_x in [82.0, 98.0]:
		var ax: float = float(arch_x)
		var ay: float = 127.0 - (ax - 72.0) * 0.5
		var arch := PackedVector2Array([
			Vector2(ax - 5.0, ay + 2.5), Vector2(ax + 5.0, ay - 2.5),
			Vector2(ax + 5.0, ay - 13.0), Vector2(ax, ay - 15.0), Vector2(ax - 5.0, ay - 9.0)
		])
		_poly_outlined(img, arch, Color("#475569"), Color("#1e293b"), C_OUTLINE, 1.8)

	# Upper overhanging civic council story with rich timbering
	_draw_isometric_box(
		img, 72.0, 107.0, 46.0, 46.0, 26.0,
		Color("#dfd5c4"), Color("#f7efe0"), Color("#c4b9a6"), 2.5
	)
	_aa_line(img, 26.0, 84.0, 72.0, 107.0, Color("#452915"), 3.2)
	_aa_line(img, 72.0, 107.0, 118.0, 84.0, Color("#361f0f"), 3.2)
	for vx_v in [42.0, 57.0, 87.0, 102.0]:
		var vx: float = float(vx_v)
		var vy: float = 107.0 - absf(vx - 72.0) * 0.5
		_aa_line(img, vx, vy, vx, vy - 26.0, Color("#452915"), 2.5)

	# Steep blue-slate civic roof with courses
	_draw_pitched_roof(
		img, 72.0, 81.0, 49.0, 49.0, 30.0,
		Color("#6d7f91"), Color("#475569"), Color("#efe6d5"), 2.5
	)
	_draw_roof_courses(img, 72.0, 81.0, 49.0, 49.0, 30.0, 5, Color("#2c3642"), Color("#8ca0b5"), false)

	# Central timber clock-belfry turret & golden spire finial
	_draw_isometric_box(
		img, 72.0, 45.0, 12.0, 12.0, 16.0,
		Color("#9c6638"), Color("#c48852"), Color("#784925"), 2.1
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(60, 23), Vector2(72, 8), Vector2(84, 23), Vector2(72, 29)]),
		Color("#64748b"), Color("#334155"), C_OUTLINE, 2.1
	)
	_aa_circle_outlined(img, 66.0, 36.0, 4.2, Color("#fef9c3"), C_OUTLINE, 1.6)

	# Tall mullioned council windows glowing warm amber
	_draw_iso_window(img, 49.0, 83.0, 6.5, 6.5, false, Color("#fef08a"), Color("#d97706"))
	_draw_iso_window(img, 80.0, 90.0, 5.5, 6.2, true, Color("#fef08a"), Color("#d97706"))
	_draw_iso_window(img, 95.0, 82.5, 5.5, 6.2, true, Color("#fef08a"), Color("#d97706"))
	return img


# 7. Tier IV Monumental Stone Citadel with Central Donjon Keep & Conical Turrets
static func _draw_citadel_keep() -> Image:
	var img := _new_canvas(160, 160)
	_drop_shadow(img, 80.0, 138.0, 68.0, 24.0, 0.44)

	# Rear turret
	_draw_isometric_box(
		img, 80.0, 90.0, 18.0, 18.0, 48.0,
		Color("#d4d0c8"), Color("#cfc9be"), Color("#87868c"), 2.2
	)

	# Left & Right corner turrets with conical blue-slate roofs
	for tx_v in [34.0, 126.0]:
		var tx: float = float(tx_v)
		_draw_isometric_box(
			img, tx, 115.0, 19.0, 19.0, 52.0,
			Color("#d4d0c8"), Color("#ded8cc"), Color("#8e8d94"), 2.4
		)
		_poly_outlined(
			img,
			PackedVector2Array([Vector2(tx - 20.0, 53.0), Vector2(tx, 32.0), Vector2(tx, 63.0)]),
			Color("#6d7f91"), Color("#4b5969"), C_OUTLINE, 2.2
		)
		_poly_outlined(
			img,
			PackedVector2Array([Vector2(tx, 32.0), Vector2(tx + 20.0, 53.0), Vector2(tx, 63.0)]),
			Color("#4b5969"), Color("#313b47"), C_OUTLINE, 2.2
		)

	# Soaring central square Donjon Keep rising from inner ward
	_draw_isometric_box(
		img, 80.0, 112.0, 28.0, 28.0, 74.0,
		Color("#cbd5e1"), Color("#ebe5d8"), Color("#96959c"), 2.5
	)
	_draw_isometric_box(
		img, 80.0, 38.0, 31.0, 31.0, 9.0,
		Color("#e2ddd2"), Color("#f2ece0"), Color("#9e9da3"), 2.3
	)
	_draw_iso_window(img, 66.0, 66.0, 4.5, 7.0, false, Color("#fef08a"), Color("#d97706"))
	_draw_iso_window(img, 94.0, 66.0, 4.5, 7.0, true, Color("#fef08a"), Color("#d97706"))

	# Crimson & gold royal banner flying atop the Donjon
	_aa_line(img, 80.0, 6.0, 80.0, 24.0, C_OUTLINE, 3.2)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(80, 7), Vector2(98, 11), Vector2(80, 17)]),
		Color("#ef4444"), Color("#b91c1c"), C_OUTLINE, 1.8
	)

	# Heavy outer curtain walls
	_draw_isometric_box(
		img, 80.0, 138.0, 48.0, 48.0, 38.0,
		Color("#b8b3aa"), Color("#ded8cc"), Color("#919096"), 2.5
	)
	# Crenellated merlons along sunlit left & shaded right curtain tops
	for m_i in range(3):
		var u := 0.22 + float(m_i) * 0.28
		var ml := Vector2(32.0, 76.0).lerp(Vector2(80.0, 100.0), u)
		var mr := Vector2(80.0, 100.0).lerp(Vector2(128.0, 76.0), u)
		_draw_isometric_box(img, ml.x, ml.y, 6.0, 5.0, 6.0, Color("#ebe5d8"), Color("#f5efe4"), Color("#96959c"), 1.7)
		_draw_isometric_box(img, mr.x, mr.y, 5.0, 6.0, 6.0, Color("#d4cfc4"), Color("#ded8cc"), Color("#7d7c82"), 1.7)

	# Front gatehouse bastion & iron portcullis
	_draw_isometric_box(
		img, 80.0, 144.0, 20.0, 20.0, 48.0,
		Color("#e5dfd3"), Color("#ebe5d8"), Color("#8e8d94"), 2.5
	)
	var gate := PackedVector2Array([
		Vector2(45, 120.5), Vector2(59, 127.5), Vector2(59, 107), Vector2(52, 100), Vector2(45, 102)
	])
	_poly_outlined(img, gate, Color("#332e2a"), Color("#171412"), C_OUTLINE, 2.3)
	_aa_line(img, 49.5, 102.0, 49.5, 122.5, Color("#94a3b8"), 1.7)
	_aa_line(img, 54.5, 104.0, 54.5, 125.0, Color("#94a3b8"), 1.7)
	return img


# 8. Tapered Masonry & Limewash Windmill with Lattice-Canvas Sails
static func _draw_windmill() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 40.0, 15.0, 0.39)

	# Octagonal stone base plinth
	_draw_isometric_box(
		img, 72.0, 127.0, 26.0, 26.0, 14.0,
		Color("#a8a29e"), Color("#cfc8bc"), Color("#7d7870"), 2.3
	)

	# Tapered whitewashed tower (sunlit warm left, cool shaded right)
	var tower_l := PackedVector2Array([
		Vector2(54, 52), Vector2(72, 56), Vector2(72, 114), Vector2(47, 102)
	])
	var tower_r := PackedVector2Array([
		Vector2(72, 56), Vector2(90, 52), Vector2(97, 102), Vector2(72, 114)
	])
	_poly_outlined(img, tower_l, Color("#faf5eb"), Color("#e6dccb"), C_OUTLINE, 2.4)
	_poly_outlined(img, tower_r, Color("#cfc4b2"), Color("#a69b8a"), C_OUTLINE, 2.4)

	# Timber balcony ring & miller's doorway + warm window
	_aa_line(img, 48.0, 88.0, 72.0, 98.0, Color("#6e4220"), 3.6)
	_aa_line(img, 72.0, 98.0, 96.0, 88.0, Color("#4a2b12"), 3.6)
	_draw_iso_window(img, 83.0, 76.0, 4.5, 5.5, true, Color("#fef08a"), Color("#d97706"))
	var door := PackedVector2Array([
		Vector2(56, 118), Vector2(65, 122.5), Vector2(65, 106), Vector2(56, 101.5)
	])
	_poly_outlined(img, door, Color("#784820"), Color("#472910"), C_OUTLINE, 2.0)

	# Domed wooden-shingle cap
	var cap_l := PackedVector2Array([Vector2(50, 52), Vector2(72, 31), Vector2(72, 57)])
	var cap_r := PackedVector2Array([Vector2(72, 31), Vector2(94, 52), Vector2(72, 57)])
	_poly_outlined(img, cap_l, Color("#b57642"), Color("#855228"), C_OUTLINE, 2.4)
	_poly_outlined(img, cap_r, Color("#855228"), Color("#593416"), C_OUTLINE, 2.4)

	# Four lattice-and-canvas sails radiating from hub (64, 52)
	var hub := Vector2(64.0, 52.0)
	var dirs: Array[Vector2] = [
		Vector2(-39, -39), Vector2(39, -39), Vector2(39, 39), Vector2(-39, 39)
	]
	for d in dirs:
		var tip: Vector2 = hub + d
		var perp := Vector2(-d.y, d.x).normalized() * 9.5
		var p_in := hub + d * 0.18
		var blade := PackedVector2Array([
			p_in, tip, tip + perp, p_in + perp
		])
		_poly_outlined(img, blade, Color("#fcf9f0"), Color("#dfd3bc"), C_OUTLINE, 2.1)
		for rung_i in [1, 2, 3]:
			var rt := float(rung_i) / 4.0
			var r0 := p_in.lerp(tip, rt)
			var r1 := r0 + perp
			_aa_line(img, r0.x, r0.y, r1.x, r1.y, Color("#9c6638"), 1.3)
		_aa_line(img, hub.x, hub.y, tip.x, tip.y, Color("#5c3618"), 3.2)
	_aa_circle_outlined(img, hub.x, hub.y, 5.5, Color("#784820"), C_OUTLINE, 2.2)
	return img


# 9. Fortified Stone & Timber Watchtower with Slate Spire
static func _draw_watchtower() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 40.0, 15.0, 0.40)

	# Battered stone footing
	_draw_isometric_box(
		img, 72.0, 128.0, 29.0, 29.0, 12.0,
		Color("#9ca3af"), Color("#cfc8bc"), Color("#78757a"), 2.3
	)

	# Tall ashlar masonry shaft (warm limestone left, cool slate right)
	_draw_isometric_box(
		img, 72.0, 116.0, 25.0, 25.0, 46.0,
		Color("#b8b2a6"), Color("#e6dfd2"), Color("#949299"), 2.4
	)
	for h_course in [82.0, 96.0, 110.0]:
		var hy: float = float(h_course)
		_aa_line(img, 47.0, hy - 12.5, 72.0, hy, Color(0.14, 0.08, 0.05, 0.25), 1.3)
		_aa_line(img, 72.0, hy, 97.0, hy - 12.5, Color(0.14, 0.08, 0.05, 0.30), 1.3)

	# Illuminated lookout slit & arrow loop
	_draw_iso_window(img, 59.0, 86.0, 3.2, 6.5, false, Color("#fef08a"), Color("#d97706"))
	_aa_line(img, 85.0, 82.0, 85.0, 94.0, C_OUTLINE, 2.6)

	# Corbeled overhanging timber machicolation gallery (hourd)
	_draw_isometric_box(
		img, 72.0, 70.0, 30.0, 30.0, 18.0,
		Color("#7c4e29"), Color("#b07440"), Color("#6e4320"), 2.4
	)
	for cx_v in [50.0, 62.0, 82.0, 94.0]:
		var cx_p: float = float(cx_v)
		var cy_p: float = 70.0 - absf(cx_p - 72.0) * 0.5
		_aa_line(img, cx_p, cy_p, cx_p, cy_p + 5.0, C_OUTLINE, 2.8)

	# Steep pyramidal blue-slate roof with weathervane finial
	var roof_l := PackedVector2Array([Vector2(40, 36), Vector2(72, 12), Vector2(72, 52)])
	var roof_r := PackedVector2Array([Vector2(72, 12), Vector2(104, 36), Vector2(72, 52)])
	_poly_outlined(img, roof_l, Color("#708296"), Color("#4e5d6e"), C_OUTLINE, 2.4)
	_poly_outlined(img, roof_r, Color("#4e5d6e"), Color("#323c47"), C_OUTLINE, 2.4)
	_aa_line(img, 72.0, 5.0, 72.0, 13.0, C_OUTLINE, 2.4)
	_aa_circle(img, 72.0, 6.0, 2.4, Color("#fbbf24"))
	return img


# 10. Tier IV Grand Gothic Cathedral with Twin Western Towers, Rose Window & Flèche Spire
static func _draw_cathedral() -> Image:
	var img := _new_canvas(160, 160)
	_drop_shadow(img, 80.0, 140.0, 68.0, 24.5, 0.43)

	# Main limestone nave & clerestory body
	_draw_isometric_box(
		img, 84.0, 134.0, 48.0, 50.0, 46.0,
		Color("#c4beb4"), Color("#ebe3d3"), Color("#aba49c"), 2.5
	)

	# Flying buttresses bracing the shaded south-east nave wall
	for b_u in [0.28, 0.58, 0.85]:
		var bx: float = lerpf(84.0, 134.0, float(b_u))
		var by: float = lerpf(134.0, 109.0, float(b_u))
		_draw_isometric_box(
			img, bx + 4.0, by + 3.0, 5.0, 6.0, 32.0,
			Color("#d4cec4"), Color("#ded7c8"), Color("#8e8880"), 1.9
		)

	# Steep copper-slate gothic nave roof with courses
	_draw_pitched_roof(
		img, 84.0, 88.0, 50.0, 52.0, 30.0,
		Color("#5a7d78"), Color("#3e5955"), Color("#e8dfd0"), 2.5
	)
	_draw_roof_courses(img, 84.0, 88.0, 50.0, 52.0, 30.0, 5, Color("#273b38"), Color("#789e98"), false)

	# Soaring central crossing tower & needle flèche spire
	_draw_isometric_box(
		img, 88.0, 62.0, 18.0, 18.0, 26.0,
		Color("#d4cec4"), Color("#ebe3d3"), Color("#a69f96"), 2.2
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(70, 27), Vector2(88, 4), Vector2(88, 36)]),
		Color("#688f89"), Color("#466661"), C_OUTLINE, 2.2
	)
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(88, 4), Vector2(106, 27), Vector2(88, 36)]),
		Color("#466661"), Color("#2c423f"), C_OUTLINE, 2.2
	)

	# Twin western facade bell towers flanking the sunlit portal
	for tw_pt in [Vector2(44, 118), Vector2(78, 135)]:
		var tp: Vector2 = tw_pt
		_draw_isometric_box(
			img, tp.x, tp.y, 14.0, 14.0, 60.0,
			Color("#ded7c8"), Color("#f2eadb"), Color("#b0a89e"), 2.3
		)
		_poly_outlined(
			img,
			PackedVector2Array([Vector2(tp.x - 14.0, tp.y - 67.0), Vector2(tp.x, tp.y - 86.0), Vector2(tp.x, tp.y - 60.0)]),
			Color("#688f89"), Color("#466661"), C_OUTLINE, 2.1
		)
		_poly_outlined(
			img,
			PackedVector2Array([Vector2(tp.x, tp.y - 86.0), Vector2(tp.x + 14.0, tp.y - 67.0), Vector2(tp.x, tp.y - 60.0)]),
			Color("#466661"), Color("#2d4541"), C_OUTLINE, 2.1
		)

	# Jewel-toned stained-glass Rose Window & grand arched portal on western facade
	_aa_circle_outlined(img, 58.0, 92.0, 8.0, Color("#f59e0b"), C_OUTLINE, 2.2)
	_aa_circle(img, 58.0, 92.0, 5.2, Color("#ef4444"))
	_aa_circle(img, 58.0, 92.0, 2.4, Color("#fef08a"))

	var portal := PackedVector2Array([
		Vector2(52, 120), Vector2(64, 126), Vector2(64, 108), Vector2(58, 102), Vector2(52, 104)
	])
	_poly_outlined(img, portal, Color("#6e401e"), Color("#381f0d"), C_OUTLINE, 2.1)

	# Tall stained-glass lancets along side wall & ceremonial stone steps
	for lx_v in [96.0, 112.0]:
		var lx: float = float(lx_v)
		var ly: float = 134.0 - (lx - 84.0) * 0.5 - 18.0
		_draw_iso_window(img, lx, ly, 4.2, 8.5, true, Color("#fde047"), Color("#e11d48"))

	var steps := PackedVector2Array([
		Vector2(48, 122), Vector2(68, 132), Vector2(56, 144), Vector2(36, 134)
	])
	_poly_outlined(img, steps, Color("#e8e2d5"), Color("#a8a29e"), C_OUTLINE, 2.1)
	return img


# 10b. Timber & Stone Harbor Dock / Pier with Crane & Cargo
static func _draw_dock() -> Image:
	var img := _new_canvas(144, 144)
	# Shallow harbor water ripples around submerged pilings
	_aa_ellipse(img, 76.0, 108.0, 56.0, 22.0, Color(0.20, 0.72, 0.76, 0.44))
	_aa_ellipse(img, 84.0, 112.0, 40.0, 14.0, Color(0.75, 0.96, 1.0, 0.45))

	# Stone embankment quay at rear-left
	_draw_isometric_box(
		img, 48.0, 98.0, 26.0, 28.0, 16.0,
		Color("#cbd5e1"), Color("#d6d0c4"), Color("#7d8590"), 2.3
	)

	# Heavy oak support pilings in water
	for pile in [Vector2(56, 112), Vector2(82, 125), Vector2(108, 112), Vector2(82, 99)]:
		var pl: Vector2 = pile
		_aa_line(img, pl.x, pl.y + 8.0, pl.x, pl.y - 16.0, C_OUTLINE, 7.0)
		_aa_line(img, pl.x, pl.y + 8.0, pl.x, pl.y - 16.0, Color("#6e4423"), 4.0)
		_aa_ellipse(img, pl.x, pl.y + 8.0, 7.5, 3.0, Color(0.90, 0.99, 1.0, 0.65))

	# Isometric planked wooden jetty deck
	_draw_isometric_box(
		img, 82.0, 114.0, 38.0, 34.0, 7.0,
		Color("#cfa06b"), Color("#a87442"), Color("#6e4622"), 2.4
	)
	for plank_i in range(1, 6):
		var t := float(plank_i) / 6.0
		var a := Vector2(44.0, 88.0).lerp(Vector2(82.0, 107.0), t)
		var b := Vector2(78.0, 71.0).lerp(Vector2(116.0, 90.0), t)
		_aa_line(img, a.x, a.y, b.x, b.y, Color("#6e4420"), 1.4)

	# Timber cargo crane jib, rope & crates/barrels on pier
	_aa_line(img, 62.0, 88.0, 62.0, 40.0, C_OUTLINE, 6.2)
	_aa_line(img, 62.0, 88.0, 62.0, 40.0, Color("#8c582e"), 3.6)
	_aa_line(img, 62.0, 42.0, 98.0, 52.0, C_OUTLINE, 5.5)
	_aa_line(img, 62.0, 42.0, 98.0, 52.0, Color("#ab7140"), 3.2)
	_aa_line(img, 96.0, 52.0, 96.0, 76.0, Color("#d6c5a9"), 1.8)
	_draw_isometric_box(
		img, 96.0, 88.0, 10.0, 10.0, 10.0,
		Color("#deb887"), Color("#b8824c"), Color("#7c5028"), 2.0
	)
	_aa_ellipse_outlined(img, 74.0, 92.0, 7.0, 8.5, Color("#784822"), C_OUTLINE, 1.9)
	return img


# 11. Megalithic Stone Circle / Unity Monument
static func _draw_prop_unity_monument() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 114.0, 56.0, 20.0, 0.37)

	var stones := [
		Vector2(34, 88), Vector2(54, 68), Vector2(86, 68),
		Vector2(110, 84), Vector2(96, 112), Vector2(48, 112)
	]
	for st in stones:
		_draw_isometric_box(
			img, st.x, st.y, 10.0, 8.0, 34.0,
			Color("#e2e8f0"), Color("#cbd5e1"), Color("#64748b"), 2.2
		)
	# Trilithon capstone lintel bridging the two rear-center monoliths
	_draw_isometric_box(
		img, 72.0, 36.0, 24.0, 9.0, 7.0,
		Color("#f1f5f9"), Color("#cbd5e1"), Color("#64748b"), 2.1
	)
	# Central carved altar with glowing golden-crimson emblem
	_draw_isometric_box(
		img, 72.0, 96.0, 16.0, 16.0, 10.0,
		Color("#fbbf24"), Color("#cbd5e1"), Color("#64748b"), 2.2
	)
	_aa_ellipse(img, 72.0, 81.0, 9.0, 4.5, Color("#ef4444"))
	return img


# 12. Isometric Sharpened-Log Palisade Wall
static func _draw_palisade_wall() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 104.0, 48.0, 16.0, 0.36)

	for i in range(9):
		var t := float(i) / 8.0
		var lx := lerpf(24.0, 104.0, t)
		var ly := lerpf(82.0, 116.0, t)
		var post_h := 46.0 + float((i * 3) % 3) * 4.0
		var post_l := PackedVector2Array([
			Vector2(lx - 5.2, ly), Vector2(lx - 5.2, ly - post_h),
			Vector2(lx, ly - post_h - 10.0), Vector2(lx, ly)
		])
		var post_r := PackedVector2Array([
			Vector2(lx, ly), Vector2(lx, ly - post_h - 10.0),
			Vector2(lx + 5.2, ly - post_h), Vector2(lx + 5.2, ly)
		])
		_poly_filled(img, post_l, Color("#c99460"), Color("#996538"))
		_poly_filled(img, post_r, Color("#855228"), Color("#573316"))
		_poly_outlined(
			img,
			PackedVector2Array([
				Vector2(lx - 5.2, ly), Vector2(lx - 5.2, ly - post_h),
				Vector2(lx, ly - post_h - 10.0), Vector2(lx + 5.2, ly - post_h), Vector2(lx + 5.2, ly)
			]),
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), C_OUTLINE, 2.1
		)
		_aa_line(img, lx - 3.5, ly - post_h, lx, ly - post_h - 8.5, Color("#f2d5ad"), 1.5)

	# Double horizontal timber cross-lashings
	_aa_line(img, 21.0, 60.0, 107.0, 96.0, C_OUTLINE, 6.4)
	_aa_line(img, 21.0, 60.0, 107.0, 96.0, Color("#784820"), 3.6)
	_aa_line(img, 21.0, 74.0, 107.0, 110.0, C_OUTLINE, 6.4)
	_aa_line(img, 21.0, 74.0, 107.0, 110.0, Color("#663b19"), 3.6)
	return img


# 13. Isometric Crenellated Ashlar Stone Curtain Wall
static func _draw_stone_wall() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 52.0, 18.0, 0.39)

	_draw_isometric_box(
		img, 88.0, 115.0, 64.0, 18.0, 42.0,
		Color("#dbd6cc"), Color("#cfc9be"), Color("#85848c"), 2.5
	)
	# Ashlar mortar courses along sunlit left rampart face
	for row_i in [1, 2, 3]:
		var ry := 115.0 - float(row_i) * 10.5
		_aa_line(img, 24.0, ry - 32.0, 88.0, ry, Color(0.14, 0.08, 0.05, 0.28), 1.4)

	# Narrow defensive arrow slit
	_aa_line(img, 56.0, 76.0, 56.0, 88.0, C_OUTLINE, 2.6)

	# Beveled crenellated merlons along top parapet
	for m in range(4):
		var mx := 34.0 + float(m) * 18.0
		var my := 45.0 + float(m) * 9.0
		_draw_isometric_box(
			img, mx, my, 10.0, 15.0, 10.5,
			Color("#ede8de"), Color("#ded8cc"), Color("#8e8d94"), 2.0
		)
	return img


# 14. Iron-Bound Treasure Chest Overflowing with Gold
static func _draw_prop_tribute_chest() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 38.0, 14.0, 0.38)
	_draw_isometric_box(
		img, 64.0, 108.0, 32.0, 26.0, 24.0,
		Color("#fbbf24"), Color("#a8642c"), Color("#6e3d16"), 2.5
	)
	_aa_line(img, 44.0, 98.0, 44.0, 74.0, Color("#475569"), 3.2)
	_aa_line(img, 80.0, 100.0, 80.0, 76.0, Color("#334155"), 3.2)
	_aa_ellipse_outlined(img, 64.0, 68.0, 24.0, 11.5, Color("#facc15"), C_OUTLINE, 2.2)
	_aa_ellipse(img, 61.0, 66.0, 16.0, 7.5, Color("#fef08a"))
	_aa_circle_outlined(img, 55.0, 64.0, 4.5, Color("#fde047"), C_OUTLINE, 1.6)
	_aa_circle_outlined(img, 71.0, 66.0, 4.0, Color("#fde047"), C_OUTLINE, 1.6)
	return img


# 15. Isometric Timber Catapult / Siege Engine
static func _draw_prop_siege_engine() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 44.0, 16.0, 0.38)
	_draw_isometric_box(
		img, 64.0, 104.0, 38.0, 28.0, 8.5,
		Color("#ad7240"), Color("#8f5a2e"), Color("#5c3618"), 2.4
	)
	_aa_line(img, 42.0, 88.0, 60.0, 46.0, C_OUTLINE, 7.0)
	_aa_line(img, 42.0, 88.0, 60.0, 46.0, Color("#9e6536"), 4.2)
	_aa_line(img, 76.0, 92.0, 60.0, 46.0, C_OUTLINE, 7.0)
	_aa_line(img, 76.0, 92.0, 60.0, 46.0, Color("#754722"), 4.2)
	_aa_line(img, 52.0, 74.0, 96.0, 28.0, C_OUTLINE, 7.5)
	_aa_line(img, 52.0, 74.0, 96.0, 28.0, Color("#ba7c46"), 4.5)
	_aa_circle_outlined(img, 98.0, 26.0, 9.5, Color("#94a3b8"), C_OUTLINE, 2.3)
	for wc in [Vector2(42, 96), Vector2(84, 96)]:
		_aa_circle_outlined(img, wc.x, wc.y, 11.5, Color("#64748b"), C_OUTLINE, 2.3)
		_aa_circle_outlined(img, wc.x, wc.y, 8.5, Color("#855228"), C_OUTLINE, 1.8)
		_aa_circle(img, wc.x, wc.y, 2.8, C_OUTLINE)
	return img


# 16. Dense Golden Wheat Field with Standing Stalks & Bound Sheaves
static func _draw_crop_field() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 72.0, 60.0, 34.0, 0.24)

	# Isometric rich plowed loam plot
	var plot := PackedVector2Array([
		Vector2(72, 34), Vector2(132, 66), Vector2(72, 104), Vector2(12, 66)
	])
	_poly_outlined(img, plot, Color("#784924"), Color("#4f2e15"), C_OUTLINE, 2.4)

	# Dense standing golden wheat rows (layered back-to-front for lush volume)
	for row_i in range(1, 8):
		var t := float(row_i) / 8.0
		var a := Vector2(16, 66).lerp(Vector2(72, 37), t)
		var b := Vector2(72, 100).lerp(Vector2(128, 66), t)
		_aa_line(img, a.x + 4.0, a.y + 2.0, b.x - 4.0, b.y - 2.0, Color("#b45309"), 6.5)
		var stalks := 13
		for s_i in range(stalks):
			var u := (float(s_i) + 0.5) / float(stalks)
			var base := a.lerp(b, u)
			var sway := float((_hash2d(row_i, s_i, 19) % 5) - 2) * 0.8
			_aa_line(img, base.x, base.y + 1.0, base.x + sway - 1.0, base.y - 11.0, Color("#ca8a04"), 2.4)
			_aa_line(img, base.x, base.y, base.x + sway - 1.5, base.y - 12.5, Color("#facc15"), 1.9)
			_aa_ellipse(img, base.x + sway - 1.8, base.y - 13.0, 2.2, 3.6, Color("#fef08a"))

	# Two tied golden wheat sheaves / haystacks with 135 deg shading
	for hs in [Vector2(54, 62), Vector2(88, 72)]:
		_drop_shadow(img, hs.x + 2.0, hs.y + 9.0, 15.0, 6.0, 0.32)
		var sh_l := PackedVector2Array([
			Vector2(hs.x - 14.0, hs.y + 9.0), Vector2(hs.x, hs.y - 17.0), Vector2(hs.x, hs.y + 10.0)
		])
		var sh_r := PackedVector2Array([
			Vector2(hs.x, hs.y - 17.0), Vector2(hs.x + 14.0, hs.y + 9.0), Vector2(hs.x, hs.y + 10.0)
		])
		_poly_outlined(img, sh_l, Color("#fef08a"), Color("#eab308"), C_OUTLINE, 2.1)
		_poly_outlined(img, sh_r, Color("#eab308"), Color("#b45309"), C_OUTLINE, 2.1)
		_aa_line(img, hs.x - 9.0, hs.y, hs.x + 9.0, hs.y, Color("#92400e"), 2.2)
	return img


# 17. Lush Isometric Pasture Paddock with Fence, Water Trough & Livestock
static func _draw_pasture_pen() -> Image:
	var img := _new_canvas(144, 144)
	var meadow := PackedVector2Array([
		Vector2(72, 36), Vector2(130, 68), Vector2(72, 102), Vector2(14, 68)
	])
	_poly_outlined(img, meadow, Color("#7ccf35"), Color("#488a1c"), C_OUTLINE, 2.4)
	_aa_ellipse(img, 62.0, 64.0, 34.0, 16.0, Color(0.64, 0.90, 0.28, 0.35))

	# Back split-rail fences first for clean depth occlusion
	var corners := [Vector2(14, 68), Vector2(72, 36), Vector2(130, 68), Vector2(72, 102)]
	for e_i in [0, 1]:
		var c0: Vector2 = corners[e_i]
		var c1: Vector2 = corners[e_i + 1]
		_aa_line(img, c0.x, c0.y - 11.0, c1.x, c1.y - 11.0, C_OUTLINE, 4.6)
		_aa_line(img, c0.x, c0.y - 11.0, c1.x, c1.y - 11.0, Color("#a86e3e"), 2.4)
		_aa_line(img, c0.x, c0.y - 5.0, c1.x, c1.y - 5.0, Color("#855228"), 2.0)

	# Wooden water trough with sky-blue water reflection
	_draw_isometric_box(
		img, 72.0, 58.0, 14.0, 8.0, 6.0,
		Color("#38bdf8"), Color("#9c6638"), Color("#633d1e"), 1.8
	)

	# Grazing fluffy sheep (left) & brown dairy cow (right) with contact shadows
	_drop_shadow(img, 50.0, 72.0, 12.0, 4.5, 0.30)
	_aa_ellipse_outlined(img, 50.0, 65.0, 11.5, 8.0, Color("#ffffff"), C_OUTLINE, 2.0)
	_aa_ellipse(img, 53.0, 67.0, 8.0, 5.2, Color("#dce4ed"))
	_aa_circle_outlined(img, 40.0, 63.0, 4.8, Color("#334155"), C_OUTLINE, 1.8)

	_drop_shadow(img, 86.0, 78.0, 15.0, 5.5, 0.32)
	_aa_ellipse_outlined(img, 85.0, 70.0, 14.0, 9.0, Color("#a86030"), C_OUTLINE, 2.0)
	_aa_ellipse(img, 82.0, 68.0, 6.0, 4.5, Color("#f8fafc"))
	_aa_circle_outlined(img, 98.0, 67.0, 5.5, Color("#783f18"), C_OUTLINE, 1.8)

	# Front split-rail fences & corner posts
	for e_i in [2, 3]:
		var c0: Vector2 = corners[e_i]
		var c1: Vector2 = corners[(e_i + 1) % 4]
		_aa_line(img, c0.x, c0.y - 11.0, c1.x, c1.y - 11.0, C_OUTLINE, 4.6)
		_aa_line(img, c0.x, c0.y - 11.0, c1.x, c1.y - 11.0, Color("#996033"), 2.4)
	for cp in corners:
		_aa_line(img, cp.x, cp.y, cp.x, cp.y - 16.0, C_OUTLINE, 4.8)
		_aa_line(img, cp.x, cp.y, cp.x, cp.y - 16.0, Color("#b07644"), 2.4)
	return img


static func _draw_act_overexploit() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 42.0, 15.0, 0.38)
	_draw_isometric_box(
		img, 64.0, 108.0, 34.0, 34.0, 32.0,
		Color("#334155"), Color("#948d84"), Color("#57534e"), 2.5
	)
	_aa_circle_outlined(img, 52.0, 84.0, 10.0, Color("#f97316"), C_OUTLINE, 2.2)
	_aa_circle(img, 51.0, 83.0, 5.0, Color("#fde047"))
	return img


# 18a. Pioneer Arched-Canopy Covered Wagon
static func _draw_covered_wagon() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 46.0, 15.5, 0.38)

	_draw_isometric_box(
		img, 68.0, 97.0, 36.0, 26.0, 14.0,
		Color("#ab7240"), Color("#9c6234"), Color("#694020"), 2.4
	)
	var hood_l := PackedVector2Array([
		Vector2(33, 68), Vector2(44, 36), Vector2(72, 29),
		Vector2(68, 83)
	])
	var hood_r := PackedVector2Array([
		Vector2(72, 29), Vector2(98, 45), Vector2(94, 71), Vector2(68, 83)
	])
	_poly_outlined(img, hood_l, Color("#fbf7ee"), Color("#e6dcc8"), C_OUTLINE, 2.4)
	_poly_outlined(img, hood_r, Color("#dfd3bc"), Color("#bfb197"), C_OUTLINE, 2.4)
	_aa_line(img, 53.0, 34.0, 50.0, 74.0, Color("#9c8d76"), 1.8)

	for wc in [Vector2(47, 96), Vector2(83, 92)]:
		_aa_circle_outlined(img, wc.x, wc.y, 13.0, Color("#64748b"), C_OUTLINE, 2.4)
		_aa_circle_outlined(img, wc.x, wc.y, 10.5, Color("#996033"), C_OUTLINE, 1.8)
		_aa_circle_outlined(img, wc.x, wc.y, 6.5, Color("#dfd3bc"), C_OUTLINE, 1.5)
		_aa_circle(img, wc.x, wc.y, 2.8, C_OUTLINE)
	return img


# 18b. Merchant Trader Cart with Barrels, Amphora & Tint-Receptive Canopy
static func _draw_trader_cart(cloth_col: Color) -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 105.0, 46.0, 15.0, 0.38)

	# Pulling shafts at front-left
	_aa_line(img, 36.0, 86.0, 14.0, 94.0, C_OUTLINE, 5.2)
	_aa_line(img, 36.0, 86.0, 14.0, 94.0, Color("#8c582e"), 2.8)

	# Open slatted oak merchant cart bed
	_draw_isometric_box(
		img, 68.0, 96.0, 36.0, 26.0, 13.0,
		Color("#ba804a"), Color("#a86e3b"), Color("#6e4420"), 2.4
	)

	# Cargo: wooden wine cask, golden grain sack & terracotta amphora
	_aa_ellipse_outlined(img, 60.0, 68.0, 11.0, 8.5, Color("#855228"), C_OUTLINE, 2.0)
	_aa_ellipse_outlined(img, 76.0, 66.0, 10.0, 8.0, Color("#e8d3ab"), C_OUTLINE, 2.0)
	_aa_ellipse_outlined(img, 68.0, 74.0, 6.5, 8.0, Color("#cf653c"), C_OUTLINE, 1.9)

	# Tilted rear sun-canopy in smooth tint-receptive cloth_col
	var posts := [Vector2(56, 74), Vector2(88, 72)]
	for pt in posts:
		var pp: Vector2 = pt
		_aa_line(img, pp.x, pp.y, pp.x, pp.y - 30.0, C_OUTLINE, 4.4)
		_aa_line(img, pp.x, pp.y, pp.x, pp.y - 30.0, Color("#784820"), 2.2)

	var awning := PackedVector2Array([
		Vector2(48, 44), Vector2(76, 32), Vector2(102, 44), Vector2(74, 56)
	])
	_poly_outlined(img, awning, cloth_col.lightened(0.14), cloth_col.darkened(0.14), C_OUTLINE, 2.3)
	_aa_line(img, 48.0, 44.0, 74.0, 56.0, Color("#fbbf24"), 2.2)

	# Large spoked wooden wheels with iron rims
	for wc in [Vector2(50, 96), Vector2(84, 91)]:
		_aa_circle_outlined(img, wc.x, wc.y, 13.5, Color("#64748b"), C_OUTLINE, 2.4)
		_aa_circle_outlined(img, wc.x, wc.y, 11.0, Color("#9e6436"), C_OUTLINE, 1.8)
		_aa_circle_outlined(img, wc.x, wc.y, 6.8, Color("#e6dcc8"), C_OUTLINE, 1.5)
		_aa_line(img, wc.x - 9.0, wc.y, wc.x + 9.0, wc.y, C_OUTLINE, 1.4)
		_aa_line(img, wc.x, wc.y - 9.0, wc.x, wc.y + 9.0, C_OUTLINE, 1.4)
		_aa_circle(img, wc.x, wc.y, 3.0, C_OUTLINE)
	return img


# 19. Carved Cedar Totem Pole
static func _draw_totem_pole(wing_col: Color, accent_col: Color) -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 28.0, 10.0, 0.38)

	var wings := PackedVector2Array([
		Vector2(18, 42), Vector2(64, 52), Vector2(110, 42),
		Vector2(102, 58), Vector2(64, 66), Vector2(26, 58)
	])
	_poly_outlined(img, wings, wing_col.lightened(0.10), accent_col.darkened(0.08), C_OUTLINE, 2.5)

	var pole_l := PackedVector2Array([Vector2(50, 22), Vector2(64, 22), Vector2(64, 112), Vector2(50, 112)])
	var pole_r := PackedVector2Array([Vector2(64, 22), Vector2(78, 22), Vector2(78, 112), Vector2(64, 112)])
	_poly_outlined(img, pole_l, Color("#c28752"), Color("#8f5b30"), C_OUTLINE, 2.4)
	_poly_outlined(img, pole_r, Color("#8f5b30"), Color("#5e391b"), C_OUTLINE, 2.4)

	var beak := PackedVector2Array([Vector2(58, 36), Vector2(70, 36), Vector2(64, 49)])
	_poly_outlined(img, beak, Color("#fde047"), Color("#d97706"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 57.0, 32.0, 4.0, Color("#fefae0"), C_OUTLINE, 1.8)
	_aa_circle_outlined(img, 71.0, 32.0, 4.0, Color("#fefae0"), C_OUTLINE, 1.8)
	return img


# 20. Ancient Ivy-Draped Ashlar Stone Ruins & Broken Column
static func _draw_ruins_stone() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 121.0, 58.0, 20.5, 0.39)

	# Cracked stone pavement slab
	var slab := PackedVector2Array([
		Vector2(72, 86), Vector2(124, 108), Vector2(72, 130), Vector2(20, 108)
	])
	_poly_outlined(img, slab, Color("#b8b3aa"), Color("#858078"), C_OUTLINE, 2.2)

	# Jagged broken sunlit left ashlar wall & shaded right wall
	var left_wall := PackedVector2Array([
		Vector2(26, 104), Vector2(26, 54), Vector2(42, 46),
		Vector2(54, 68), Vector2(66, 62), Vector2(72, 82), Vector2(72, 122)
	])
	var right_wall := PackedVector2Array([
		Vector2(72, 122), Vector2(72, 76), Vector2(88, 44),
		Vector2(104, 58), Vector2(118, 50), Vector2(118, 104)
	])
	_poly_outlined(img, left_wall, Color("#ded8cc"), Color("#a8a298"), C_OUTLINE, 2.5)
	_poly_outlined(img, right_wall, Color("#969399"), Color("#636166"), C_OUTLINE, 2.5)

	# Standing weathered column stub & fallen column drum in foreground
	_draw_isometric_box(
		img, 48.0, 114.0, 8.0, 8.0, 32.0,
		Color("#ebe5d8"), Color("#dfd8ca"), Color("#8e8c91"), 2.0
	)
	_aa_ellipse_outlined(img, 92.0, 114.0, 11.0, 7.0, Color("#cfc9be"), C_OUTLINE, 2.0)

	# 3-tone creeping ivy & moss clusters
	_draw_foliage_clump(img, 34.0, 56.0, 11.5, Color("#1d5c28"), Color("#389c45"), Color("#74de68"))
	_draw_foliage_clump(img, 88.0, 52.0, 12.0, Color("#1b5424"), Color("#328c3e"), Color("#68cf5e"))
	_draw_foliage_clump(img, 70.0, 106.0, 10.5, Color("#1d5c28"), Color("#389c45"), Color("#74de68"))
	return img


static func _draw_prop_betrayal_ruin() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 122.0, 54.0, 18.0, 0.42)

	var left_shard := PackedVector2Array([
		Vector2(28, 110), Vector2(32, 42), Vector2(54, 30),
		Vector2(64, 68), Vector2(60, 118)
	])
	var right_shard := PackedVector2Array([
		Vector2(82, 118), Vector2(78, 64), Vector2(92, 34),
		Vector2(114, 48), Vector2(110, 110)
	])
	_poly_outlined(img, left_shard, Color("#64748b"), Color("#1e293b"), C_OUTLINE, 2.5)
	_poly_outlined(img, right_shard, Color("#334155"), Color("#0f172a"), C_OUTLINE, 2.5)

	_aa_line(img, 70.0, 26.0, 66.0, 68.0, Color("#7e22ce"), 7.0)
	_aa_line(img, 66.0, 68.0, 74.0, 118.0, Color("#7e22ce"), 7.0)
	_aa_line(img, 70.0, 26.0, 66.0, 68.0, Color("#e11d48"), 3.6)
	_aa_line(img, 66.0, 68.0, 74.0, 118.0, Color("#e11d48"), 3.6)
	_aa_line(img, 70.0, 26.0, 66.0, 68.0, Color("#fda4af"), 1.6)

	_aa_line(img, 42.0, 116.0, 102.0, 44.0, C_OUTLINE, 6.0)
	_aa_line(img, 42.0, 116.0, 102.0, 44.0, Color("#78350f"), 3.6)
	var torn_banner := PackedVector2Array([
		Vector2(76, 56), Vector2(106, 50), Vector2(100, 74),
		Vector2(88, 68), Vector2(80, 84)
	])
	_poly_outlined(img, torn_banner, Color("#be123c"), Color("#581c87"), C_OUTLINE, 2.2)
	return img


static func _draw_barricade_spikes() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 44.0, 14.0, 0.35)
	_aa_line(img, 24.0, 76.0, 104.0, 96.0, C_OUTLINE, 9.0)
	_aa_line(img, 24.0, 76.0, 104.0, 96.0, Color("#8c582e"), 5.5)
	for sx_v in [36.0, 54.0, 72.0, 90.0]:
		var sx: float = float(sx_v)
		_aa_line(img, sx - 12.0, 106.0, sx + 12.0, 52.0, C_OUTLINE, 7.0)
		_aa_line(img, sx - 12.0, 106.0, sx + 12.0, 52.0, Color("#ba7e48"), 4.2)
		_aa_line(img, sx + 12.0, 106.0, sx - 12.0, 54.0, C_OUTLINE, 7.0)
		_aa_line(img, sx + 12.0, 106.0, sx - 12.0, 54.0, Color("#784820"), 4.2)
	return img


static func _draw_road_block_sign() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 36.0, 12.0, 0.34)
	_aa_line(img, 40.0, 104.0, 40.0, 54.0, C_OUTLINE, 7.5)
	_aa_line(img, 40.0, 104.0, 40.0, 54.0, Color("#784820"), 4.5)
	_aa_line(img, 88.0, 104.0, 88.0, 54.0, C_OUTLINE, 7.5)
	_aa_line(img, 88.0, 104.0, 88.0, 54.0, Color("#5c3317"), 4.5)
	var board := PackedVector2Array([
		Vector2(26, 50), Vector2(102, 50), Vector2(102, 74), Vector2(26, 74)
	])
	_poly_outlined(img, board, Color("#fbbf24"), Color("#d97706"), C_OUTLINE, 2.4)
	_aa_line(img, 36.0, 62.0, 92.0, 62.0, Color("#991b1b"), 4.5)
	return img


static func _draw_road_lantern() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 70.0, 110.0, 22.0, 8.0, 0.34)
	_aa_ellipse(img, 48.0, 58.0, 20.0, 20.0, Color(0.99, 0.85, 0.30, 0.28))
	var post := PackedVector2Array([
		Vector2(66, 24), Vector2(76, 24), Vector2(76, 110), Vector2(66, 110)
	])
	_poly_outlined(img, post, Color("#ad7240"), Color("#694020"), C_OUTLINE, 2.4)
	var arm := PackedVector2Array([
		Vector2(42, 30), Vector2(78, 24), Vector2(78, 32), Vector2(42, 38)
	])
	_poly_outlined(img, arm, Color("#ad7240"), Color("#694020"), C_OUTLINE, 2.2)
	var lantern := PackedVector2Array([
		Vector2(40, 46), Vector2(56, 46), Vector2(54, 68), Vector2(42, 68)
	])
	_poly_outlined(img, lantern, Color("#fef9c3"), Color("#f59e0b"), C_OUTLINE, 2.2)
	return img


static func _draw_prop_war_banner() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 110.0, 28.0, 10.0, 0.36)
	_aa_line(img, 64.0, 14.0, 64.0, 110.0, C_OUTLINE, 7.0)
	_aa_line(img, 64.0, 14.0, 64.0, 110.0, Color("#9c6234"), 4.2)
	_aa_line(img, 36.0, 28.0, 92.0, 28.0, C_OUTLINE, 6.5)
	_aa_line(img, 36.0, 28.0, 92.0, 28.0, Color("#eab308"), 4.0)
	var banner := PackedVector2Array([
		Vector2(42, 30), Vector2(86, 30), Vector2(86, 84),
		Vector2(64, 98), Vector2(42, 84)
	])
	_poly_outlined(img, banner, Color("#ef4444"), Color("#991b1b"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 64.0, 58.0, 11.0, Color("#fde047"), C_OUTLINE, 2.0)
	return img


static func _draw_prop_raid_loot() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 36.0, 12.0, 0.36)
	_aa_ellipse_outlined(img, 58.0, 86.0, 26.0, 22.0, Color("#c99864"), C_OUTLINE, 2.5)
	_aa_ellipse(img, 63.0, 90.0, 18.0, 14.0, Color("#9c6b3b"))
	_aa_ellipse_outlined(img, 58.0, 62.0, 16.0, 8.0, Color("#fde047"), C_OUTLINE, 2.2)
	_aa_line(img, 76.0, 104.0, 94.0, 48.0, C_OUTLINE, 7.5)
	_aa_line(img, 76.0, 104.0, 94.0, 48.0, Color("#6e401e"), 4.5)
	_aa_circle_outlined(img, 94.0, 42.0, 11.0, Color("#f97316"), C_OUTLINE, 2.0)
	_aa_circle(img, 93.0, 41.0, 6.0, Color("#fef08a"))
	return img


static func _draw_prop_pact_totem() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 110.0, 34.0, 12.0, 0.36)
	_draw_isometric_box(
		img, 64.0, 110.0, 24.0, 24.0, 64.0,
		Color("#fbbf24"), Color("#f1f5f9"), Color("#94a3b8"), 2.4
	)
	_aa_circle_outlined(img, 64.0, 62.0, 12.0, Color("#10b981"), C_OUTLINE, 2.2)
	_aa_circle(img, 62.0, 60.0, 5.5, Color("#a7f3d0"))
	return img


static func _draw_effect_battle_sparks() -> Image:
	var img := _new_canvas(128, 128)
	_aa_line(img, 22.0, 64.0, 106.0, 64.0, Color("#ef4444"), 4.8)
	_aa_line(img, 64.0, 22.0, 64.0, 106.0, Color("#ef4444"), 4.8)
	_aa_line(img, 32.0, 32.0, 96.0, 96.0, Color("#f97316"), 4.2)
	_aa_line(img, 96.0, 32.0, 32.0, 96.0, Color("#f97316"), 4.2)
	_aa_circle_outlined(img, 64.0, 64.0, 18.0, Color("#fbbf24"), C_OUTLINE, 2.2)
	_aa_circle(img, 64.0, 64.0, 9.5, Color("#ffffff"))
	return img


# High-DPI 48x48 Illustrated Humanoid & Cart Units with Clean Tint-Receptive Garments
static func draw_villager(step: int, tunic_color: Color) -> Image:
	if step == 1:
		return _draw_villager_body(1, tunic_color)
	if step == 2:
		return _draw_villager_body(2, tunic_color)
	if step == 3:
		return _draw_villager_work(tunic_color)
	return _draw_villager_body(0, tunic_color)


static func draw_villager_unit(pose: String, tunic_color: Color) -> Image:
	match pose:
		"villager_walk1", "villager_walk_1":
			return _draw_villager_body(1, tunic_color)
		"villager_walk2", "villager_walk_2":
			return _draw_villager_body(2, tunic_color)
		"villager_work":
			return _draw_villager_work(tunic_color)
		"traveler":
			return _draw_traveler(tunic_color)
		"raider":
			return _draw_raider(tunic_color)
		"trader_cart", "caravan_cart":
			return _draw_trader_cart(tunic_color)
		_:
			return _draw_villager_body(0, tunic_color)


static func _draw_humanoid_legs(img: Image, step: int, bob: float) -> void:
	var ly := 39.5
	var ry := 39.5
	var lx := 19.5
	var rx := 28.5
	if step == 1:
		ly = 37.0
		ry = 41.0
		lx = 18.0
		rx = 30.0
	elif step == 2:
		ly = 41.0
		ry = 37.0
		lx = 18.5
		rx = 29.5
	_aa_line(img, 20.5, 29.0 + bob, lx, ly, C_OUTLINE, 6.4)
	_aa_line(img, 20.5, 29.0 + bob, lx, ly, Color("#475569"), 3.6)
	_aa_circle_outlined(img, lx, ly + 0.8, 3.0, Color("#5c3618"), C_OUTLINE, 1.5)

	_aa_line(img, 27.5, 29.0 + bob, rx, ry, C_OUTLINE, 6.4)
	_aa_line(img, 27.5, 29.0 + bob, rx, ry, Color("#334155"), 3.6)
	_aa_circle_outlined(img, rx, ry + 0.8, 3.0, Color("#472910"), C_OUTLINE, 1.5)


static func _draw_tunic_torso(img: Image, cy_top: float, tunic_color: Color) -> void:
	var c_lit := tunic_color.lightened(0.22)
	var c_mid := tunic_color
	var c_shd := tunic_color.darkened(0.22)

	var tunic_l := PackedVector2Array([
		Vector2(16, cy_top), Vector2(24, cy_top),
		Vector2(24, cy_top + 15.0), Vector2(13.5, cy_top + 14.5)
	])
	var tunic_r := PackedVector2Array([
		Vector2(24, cy_top), Vector2(32, cy_top),
		Vector2(34.5, cy_top + 14.5), Vector2(24, cy_top + 15.0)
	])
	_poly_filled(img, tunic_l, c_lit, c_mid)
	_poly_filled(img, tunic_r, c_mid, c_shd)
	_poly_outlined(
		img,
		PackedVector2Array([
			Vector2(16, cy_top), Vector2(32, cy_top),
			Vector2(34.5, cy_top + 14.5), Vector2(13.5, cy_top + 14.5)
		]),
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), C_OUTLINE, 2.1
	)

	# Shoulder mantle collar + leather belt & brass buckle (no external rectangle needed)
	var collar := PackedVector2Array([
		Vector2(15.5, cy_top), Vector2(32.5, cy_top),
		Vector2(30.0, cy_top + 4.5), Vector2(24.0, cy_top + 6.0), Vector2(18.0, cy_top + 4.5)
	])
	_poly_outlined(img, collar, c_lit.lightened(0.12), c_mid, C_OUTLINE, 1.6)
	_aa_line(img, 15.0, cy_top + 9.5, 33.0, cy_top + 9.5, Color("#4a2b12"), 2.8)
	_aa_circle(img, 24.0, cy_top + 9.5, 1.8, Color("#fbbf24"))


static func _draw_humanoid_head(img: Image, cx: float, cy: float, hair_col: Color) -> void:
	_aa_circle_outlined(img, cx, cy, 7.2, Color("#f7cfa8"), C_OUTLINE, 2.1)
	_aa_circle(img, cx - 2.0, cy - 1.5, 4.2, Color("#fde2c4"))
	var hair := PackedVector2Array([
		Vector2(cx - 7.5, cy - 1.0), Vector2(cx - 5.0, cy - 8.0),
		Vector2(cx + 5.0, cy - 8.0), Vector2(cx + 7.5, cy - 1.0),
		Vector2(cx + 2.0, cy - 3.5), Vector2(cx - 3.0, cy - 3.5)
	])
	_poly_outlined(img, hair, hair_col.lightened(0.12), hair_col.darkened(0.15), C_OUTLINE, 1.9)
	_aa_circle(img, cx - 2.4, cy + 0.6, 1.15, C_OUTLINE)
	_aa_circle(img, cx + 2.4, cy + 0.6, 1.15, C_OUTLINE)


static func _draw_villager_body(step: int, tunic_color: Color) -> Image:
	var img := _new_canvas(48, 48)
	_drop_shadow(img, 24.0, 42.0, 11.5, 4.5, 0.35)
	var bob := -1.5 if step != 0 else 0.0

	_draw_humanoid_legs(img, step, bob)

	var l_arm_y := 27.5 + bob + (-2.0 if step == 2 else (2.0 if step == 1 else 0.0))
	var r_arm_y := 27.5 + bob + (2.0 if step == 2 else (-2.0 if step == 1 else 0.0))
	_aa_line(img, 16.0, 19.5 + bob, 11.5, l_arm_y, C_OUTLINE, 5.4)
	_aa_line(img, 16.0, 19.5 + bob, 11.5, l_arm_y, tunic_color.lightened(0.14), 3.0)
	_aa_circle_outlined(img, 11.2, l_arm_y + 1.0, 2.4, Color("#f7cfa8"), C_OUTLINE, 1.4)

	_aa_line(img, 32.0, 19.5 + bob, 36.5, r_arm_y, C_OUTLINE, 5.4)
	_aa_line(img, 32.0, 19.5 + bob, 36.5, r_arm_y, tunic_color.darkened(0.16), 3.0)
	_aa_circle_outlined(img, 36.8, r_arm_y + 1.0, 2.4, Color("#ebbc91"), C_OUTLINE, 1.4)

	_draw_tunic_torso(img, 18.0 + bob, tunic_color)
	_draw_humanoid_head(img, 24.0, 12.0 + bob, Color("#6e3f20"))
	return img


static func _draw_villager_work(tunic_color: Color) -> Image:
	var img := _new_canvas(48, 48)
	_drop_shadow(img, 24.0, 42.0, 12.5, 4.8, 0.36)

	_draw_humanoid_legs(img, 1, -0.5)
	_draw_tunic_torso(img, 18.5, tunic_color)

	# Reaching arms + wooden-handled iron hoe / sickle & straw sun-brim
	_aa_line(img, 16.0, 20.0, 11.0, 26.0, C_OUTLINE, 5.4)
	_aa_line(img, 16.0, 20.0, 11.0, 26.0, tunic_color.lightened(0.14), 3.0)
	_aa_line(img, 32.0, 20.0, 37.0, 25.0, C_OUTLINE, 5.4)
	_aa_line(img, 32.0, 20.0, 37.0, 25.0, tunic_color.darkened(0.15), 3.0)

	# Farming tool handle & curved steel blade
	_aa_line(img, 10.0, 31.0, 39.0, 17.0, C_OUTLINE, 4.4)
	_aa_line(img, 10.0, 31.0, 39.0, 17.0, Color("#9c6638"), 2.3)
	var blade := PackedVector2Array([
		Vector2(37, 16), Vector2(44, 19), Vector2(41, 27), Vector2(37, 21)
	])
	_poly_outlined(img, blade, Color("#f1f5f9"), Color("#94a3b8"), C_OUTLINE, 1.7)

	_draw_humanoid_head(img, 24.5, 12.5, Color("#6e3f20"))
	_aa_ellipse_outlined(img, 24.5, 7.5, 10.5, 3.6, Color("#facc15"), C_OUTLINE, 1.7)
	return img


static func _draw_traveler(tunic_color: Color) -> Image:
	var img := _new_canvas(48, 48)
	_drop_shadow(img, 24.0, 42.0, 12.5, 4.8, 0.36)

	# Leather travel backpack slung on left-back shoulder
	_aa_ellipse_outlined(img, 14.5, 24.0, 6.0, 8.0, Color("#9c6234"), C_OUTLINE, 1.9)
	_aa_ellipse_outlined(img, 15.0, 17.0, 5.0, 3.0, Color("#e8d3ab"), C_OUTLINE, 1.6)

	_draw_humanoid_legs(img, 1, -1.0)

	# Flowing hooded travel cloak in 3-tone tunic_color
	var cloak_l := PackedVector2Array([
		Vector2(17, 16), Vector2(24, 16), Vector2(24, 34), Vector2(11.5, 33)
	])
	var cloak_r := PackedVector2Array([
		Vector2(24, 16), Vector2(31, 16), Vector2(35.5, 33), Vector2(24, 34)
	])
	_poly_filled(img, cloak_l, tunic_color.lightened(0.22), tunic_color)
	_poly_filled(img, cloak_r, tunic_color, tunic_color.darkened(0.24))
	_poly_outlined(
		img,
		PackedVector2Array([Vector2(17, 16), Vector2(31, 16), Vector2(35.5, 33), Vector2(11.5, 33)]),
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), C_OUTLINE, 2.1
	)
	_aa_circle_outlined(img, 24.0, 18.0, 2.2, Color("#fbbf24"), C_OUTLINE, 1.4)

	# Hooded head & tall oak walking staff on right
	_aa_circle_outlined(img, 24.5, 11.5, 7.8, tunic_color.lightened(0.12), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 25.0, 12.2, 5.6, Color("#f7cfa8"), C_OUTLINE, 1.7)
	_aa_circle(img, 23.2, 12.4, 1.1, C_OUTLINE)
	_aa_circle(img, 27.2, 12.4, 1.1, C_OUTLINE)

	_aa_line(img, 37.5, 6.0, 35.5, 41.0, C_OUTLINE, 4.6)
	_aa_line(img, 37.5, 6.0, 35.5, 41.0, Color("#a86e3b"), 2.4)
	_aa_circle_outlined(img, 36.2, 24.5, 2.4, Color("#f7cfa8"), C_OUTLINE, 1.4)
	return img


static func _draw_raider(tunic_color: Color) -> Image:
	var img := _new_canvas(48, 48)
	_drop_shadow(img, 24.0, 42.0, 13.0, 5.0, 0.38)

	# Flowing war-cape behind shoulders
	var cape := PackedVector2Array([
		Vector2(16, 17), Vector2(31, 17), Vector2(34, 35), Vector2(11, 35)
	])
	_poly_outlined(img, cape, tunic_color.darkened(0.08), tunic_color.darkened(0.32), C_OUTLINE, 2.0)

	_draw_humanoid_legs(img, 2, -1.0)

	# Angled steel-tipped war spear held in left hand
	_aa_line(img, 8.0, 35.0, 16.0, 5.0, C_OUTLINE, 4.6)
	_aa_line(img, 8.0, 35.0, 16.0, 5.0, Color("#8c562b"), 2.3)
	var spear_tip := PackedVector2Array([
		Vector2(16.5, 2.5), Vector2(19.5, 10.0), Vector2(15.5, 9.5), Vector2(13.0, 9.0)
	])
	_poly_outlined(img, spear_tip, Color("#f8fafc"), Color("#94a3b8"), C_OUTLINE, 1.6)

	_draw_tunic_torso(img, 17.5, tunic_color)

	# Head with conical steel nasal helm
	_aa_circle_outlined(img, 24.0, 12.0, 6.8, Color("#f7cfa8"), C_OUTLINE, 2.0)
	var helm_l := PackedVector2Array([Vector2(16.5, 11.0), Vector2(24.0, 3.5), Vector2(24.0, 11.0)])
	var helm_r := PackedVector2Array([Vector2(24.0, 3.5), Vector2(31.5, 11.0), Vector2(24.0, 11.0)])
	_poly_outlined(img, helm_l, Color("#f1f5f9"), Color("#cbd5e1"), C_OUTLINE, 1.9)
	_poly_outlined(img, helm_r, Color("#94a3b8"), Color("#475569"), C_OUTLINE, 1.9)
	_aa_line(img, 24.0, 10.5, 24.0, 14.2, Color("#cbd5e1"), 1.8)

	# Round iron-rimmed faction shield with steel boss on right arm
	_aa_circle_outlined(img, 33.5, 26.5, 8.5, Color("#94a3b8"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 33.5, 26.5, 6.5, tunic_color.lightened(0.12), C_OUTLINE, 1.5)
	_aa_circle_outlined(img, 33.5, 26.5, 2.6, Color("#f8fafc"), C_OUTLINE, 1.4)
	return img
