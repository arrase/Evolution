class_name EvoVillageUiSprites
extends EvoPixelCanvas


static func draw_village_or_ui_sprite(sprite_name: String) -> Image:
	match sprite_name:
		"tier1_tent", "hut_thatch":
			return _draw_hut_thatch()
		"tier1_campfire", "campfire":
			return _draw_campfire(0)
		"tier1_campfire_2":
			return _draw_campfire(1)
		"tier2_cottage", "house_clay":
			return _draw_house_clay()
		"tier2_barn", "granary":
			return _draw_granary()
		"tier3_townhall", "temple_totem":
			return _draw_temple_totem()
		"tier3_house", "house_stone":
			return _draw_house_stone()
		"tier4_citadel", "citadel_keep", "prop_defense_fortress", "act_fortify":
			return _draw_citadel_keep()
		"tier4_windmill", "windmill":
			return _draw_windmill()
		"tier4_tower", "watchtower":
			return _draw_watchtower()
		"tier5_metropolis", "cathedral":
			return _draw_cathedral()
		"prop_unity_monument", "act_merge":
			return _draw_prop_unity_monument()
		"prop_defense_palisade", "palisade_wall":
			return _draw_palisade_wall()
		"prop_defense_wall", "stone_wall":
			return _draw_stone_wall()
		"prop_tribute_chest", "act_tribute":
			return _draw_prop_tribute_chest()
		"prop_siege_engine", "siege_totem", "act_siege":
			return _draw_prop_siege_engine()
		"crop_field", "act_forage":
			return _draw_crop_field()
		"pasture_pen":
			return _draw_pasture_pen()
		"act_overexploit":
			return _draw_act_overexploit()
		"covered_wagon", "settler_wagon", "caravan_cart", "act_migrate":
			return _draw_covered_wagon()
		"totem_coop", "act_cooperate":
			return _draw_totem_pole(Color("#10b981"), Color("#fbbf24"))
		"act_exchange":
			return _draw_act_exchange()
		"totem_aggro", "act_dispute":
			return _draw_totem_pole(Color("#ef4444"), Color("#f97316"))
		"totem_innov", "cultural_totem", "act_innovate", "act_custom":
			return _draw_totem_pole(Color("#2a9d8f"), Color("#e9c46a"))
		"ruins", "ruins_stone", "prop_betrayal_ruin", "act_betrayal":
			return _draw_ruins_stone()
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
		"icon_war":
			return _draw_icon_war()
		"icon_raid":
			return _draw_icon_raid()
		"icon_pact":
			return _draw_icon_pact()
		"icon_betrayal":
			return _draw_icon_betrayal()
		"icon_defense":
			return _draw_icon_defense()
		"icon_merge":
			return _draw_icon_merge()
		"icon_tribute":
			return _draw_icon_tribute()
		"icon_siege":
			return _draw_icon_siege()
		"villager_idle":
			return draw_villager(0, Color("#e07a5f"))
		"villager_walk1":
			return draw_villager(1, Color("#e07a5f"))
		"villager_walk2":
			return draw_villager(2, Color("#e07a5f"))
		_:
			return _draw_ui_icon(sprite_name)


# 1. Tier 1 Yurt / Hide Tent (land3.jpeg top-left)
static func _draw_hut_thatch() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 46.0, 16.0, 0.38)

	# Cylindrical yurt body with felt walls
	var body := PackedVector2Array([
		Vector2(24, 62), Vector2(104, 62),
		Vector2(104, 96), Vector2(86, 108),
		Vector2(42, 108), Vector2(24, 96)
	])
	_poly_outlined(img, body, Color("#ede2cc"), Color("#c9b898"), C_OUTLINE, 2.5)

	# Ornate decorative textile bands (upper & lower)
	var upper_band := PackedVector2Array([
		Vector2(24, 62), Vector2(104, 62), Vector2(104, 71), Vector2(24, 71)
	])
	_poly_outlined(img, upper_band, Color("#e0c3fc"), Color("#c084fc"), C_OUTLINE, 2.0)
	var lower_band := PackedVector2Array([
		Vector2(24, 92), Vector2(104, 92), Vector2(86, 108), Vector2(42, 108)
	])
	_poly_outlined(img, lower_band, Color("#f3d5b5"), Color("#c084fc"), C_OUTLINE, 2.0)

	# Conical yurt dome roof
	var dome := PackedVector2Array([
		Vector2(22, 62), Vector2(46, 36), Vector2(82, 36), Vector2(106, 62), Vector2(64, 70)
	])
	_poly_outlined(img, dome, Color("#f5ebd6"), Color("#d4c3a3"), C_OUTLINE, 2.5)

	# Wooden crown wheel (toono) at apex + radiating ribs
	_aa_ellipse_outlined(img, 64.0, 36.0, 16.0, 7.0, Color("#7c4d28"), C_OUTLINE, 2.4)
	_aa_line(img, 50.0, 36.0, 78.0, 36.0, C_OUTLINE, 2.0)
	_aa_line(img, 64.0, 30.0, 64.0, 42.0, C_OUTLINE, 2.0)
	for rx_v in [32.0, 48.0, 64.0, 80.0, 96.0]:
		var rx: float = float(rx_v)
		_aa_line(img, 64.0, 42.0, rx, 64.0, Color("#8c5a32"), 1.8)

	# Front-left wooden doorway with rolled curtain flap
	var door := PackedVector2Array([
		Vector2(38, 68), Vector2(56, 72), Vector2(56, 106), Vector2(38, 102)
	])
	_poly_outlined(img, door, Color("#5c381e"), Color("#361f0e"), C_OUTLINE, 2.4)
	var flap := PackedVector2Array([
		Vector2(36, 66), Vector2(58, 70), Vector2(58, 77), Vector2(36, 73)
	])
	_poly_outlined(img, flap, Color("#d97706"), Color("#92400e"), C_OUTLINE, 2.0)
	return img


# 2. Tier 1 Blazing Campfire with Logs (land3.jpeg top-left)
static func _draw_campfire(frame: int) -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 104.0, 36.0, 13.0, 0.36)
	# Warm ground glow
	_aa_ellipse(img, 64.0, 100.0, 42.0, 16.0, Color(0.98, 0.65, 0.15, 0.28))

	# Radial firewood logs with cut ends
	var logs := [
		[Vector2(30, 98), Vector2(64, 92)],
		[Vector2(98, 98), Vector2(64, 92)],
		[Vector2(38, 108), Vector2(64, 94)],
		[Vector2(90, 108), Vector2(64, 94)],
		[Vector2(64, 112), Vector2(64, 94)]
	]
	for lg in logs:
		var p0: Vector2 = lg[0]
		var p1: Vector2 = lg[1]
		_aa_line(img, p0.x, p0.y, p1.x, p1.y, C_OUTLINE, 13.0)
		_aa_line(img, p0.x, p0.y, p1.x, p1.y, Color("#8c5228"), 9.0)
		_aa_circle_outlined(img, p0.x, p0.y, 5.5, Color("#e6be8a"), C_OUTLINE, 2.0)

	var shift := -3.0 if frame == 0 else 3.0
	# Outer crimson/orange flame
	var outer_flame := PackedVector2Array([
		Vector2(40, 94), Vector2(36, 68), Vector2(50, 52),
		Vector2(64.0 + shift, 24.0), Vector2(78, 50), Vector2(92, 68), Vector2(88, 94)
	])
	_poly_outlined(img, outer_flame, Color("#f97316"), Color("#dc2626"), C_OUTLINE, 2.2)

	# Mid golden flame
	var mid_flame := PackedVector2Array([
		Vector2(48, 94), Vector2(46, 70), Vector2(64.0 - shift * 0.6, 38.0),
		Vector2(82, 70), Vector2(80, 94)
	])
	_poly_filled(img, mid_flame, Color("#fde047"), Color("#f59e0b"))

	# Inner white-hot core
	var inner_flame := PackedVector2Array([
		Vector2(55, 94), Vector2(64.0, 58.0), Vector2(73, 94)
	])
	_poly_filled(img, inner_flame, Color("#ffffff"), Color("#fef08a"))
	return img


# 3. Tier 2 Timber Log Cabin (land3.jpeg top-left second platform)
static func _draw_house_clay() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 48.0, 18.0, 0.38)

	# Isometric log walls (base front at 64, 110)
	_draw_isometric_box(
		img, 64.0, 110.0, 38.0, 36.0, 32.0,
		Color("#784b25"), Color("#a66e3e"), Color("#7c4e29"), 2.4
	)
	# Horizontal log plank lines on left and right walls
	for h_off_v in [8.0, 16.0, 24.0]:
		var y_base: float = 110.0 - float(h_off_v)
		_aa_line(img, 26.0, y_base - 19.0, 64.0, y_base, C_OUTLINE, 1.6)
		_aa_line(img, 64.0, y_base, 100.0, y_base - 18.0, C_OUTLINE, 1.6)

	# Stone chimney on roof back-left
	_draw_isometric_box(
		img, 54.0, 48.0, 8.0, 8.0, 18.0,
		Color("#cbd5e1"), Color("#94a3b8"), Color("#64748b"), 2.0
	)

	# Pitched wooden plank roof
	_draw_pitched_roof(
		img, 64.0, 78.0, 42.0, 40.0, 26.0,
		Color("#8c5a34"), Color("#6e4425"), Color("#996238"), 2.5
	)

	# Door on front-left wall & warm window on front-right wall
	var door := PackedVector2Array([
		Vector2(42, 99), Vector2(52, 104), Vector2(52, 86), Vector2(42, 81)
	])
	_poly_outlined(img, door, Color("#5c361a"), Color("#3d2310"), C_OUTLINE, 2.0)

	var win := PackedVector2Array([
		Vector2(74, 96), Vector2(88, 89), Vector2(88, 77), Vector2(74, 84)
	])
	_poly_outlined(img, win, Color("#fef08a"), Color("#f59e0b"), C_OUTLINE, 2.0)
	return img


# 4. Tier 2 Thatched Wooden Barn / Granary with Barrels (land3.jpeg top-left)
static func _draw_granary() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 122.0, 56.0, 20.0, 0.38)

	# Isometric timber barn box
	_draw_isometric_box(
		img, 72.0, 124.0, 44.0, 44.0, 36.0,
		Color("#7c4e29"), Color("#9e6738"), Color("#754824"), 2.5
	)
	# Double barn doors on front-left wall
	var doors := PackedVector2Array([
		Vector2(38, 107), Vector2(60, 118), Vector2(60, 92), Vector2(38, 81)
	])
	_poly_outlined(img, doors, Color("#85522a"), Color("#593518"), C_OUTLINE, 2.2)
	_aa_line(img, 49.0, 86.5, 49.0, 112.5, C_OUTLINE, 2.0)

	# Golden straw thatched pitched roof
	_draw_pitched_roof(
		img, 72.0, 88.0, 48.0, 48.0, 30.0,
		Color("#f5d061"), Color("#dfb034"), Color("#8c582e"), 2.6
	)
	# Wooden barrels resting against front-right wall
	_aa_ellipse_outlined(img, 86.0, 112.0, 8.0, 10.0, Color("#6e4220"), C_OUTLINE, 2.0)
	_aa_ellipse_outlined(img, 98.0, 106.0, 8.0, 10.0, Color("#5c3618"), C_OUTLINE, 2.0)
	return img


# 5. Tier 3 Half-Timbered Medieval House (land3.jpeg top-center)
static func _draw_house_stone() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 54.0, 19.0, 0.40)

	# Lower stone & plaster story + upper overhang jetty story
	_draw_isometric_box(
		img, 72.0, 126.0, 42.0, 40.0, 46.0,
		Color("#d6c5ab"), Color("#f2e6d4"), Color("#d4c3aa"), 2.5
	)
	# Half-timber beams along left & right walls
	_aa_line(img, 30.0, 82.0, 72.0, 103.0, Color("#4a2e19"), 3.2)
	_aa_line(img, 72.0, 103.0, 112.0, 83.0, Color("#4a2e19"), 3.2)
	for vx_v in [44.0, 58.0]:
		var vx: float = float(vx_v)
		var vy: float = 126.0 - (72.0 - vx) * 0.5
		_aa_line(img, vx, vy, vx, vy - 46.0, Color("#4a2e19"), 2.8)
	for vx_v in [86.0, 100.0]:
		var vx: float = float(vx_v)
		var vy: float = 126.0 - (vx - 72.0) * 0.5
		_aa_line(img, vx, vy, vx, vy - 46.0, Color("#4a2e19"), 2.8)

	# Steep tiled pitched roof
	_draw_pitched_roof(
		img, 72.0, 80.0, 46.0, 44.0, 32.0,
		Color("#ab784e"), Color("#8c5d38"), Color("#ebe0ce"), 2.6
	)
	# Illuminated leaded windows
	var win_l := PackedVector2Array([
		Vector2(46, 94), Vector2(56, 99), Vector2(56, 87), Vector2(46, 82)
	])
	_poly_outlined(img, win_l, Color("#fde047"), Color("#d97706"), C_OUTLINE, 2.0)
	var win_r := PackedVector2Array([
		Vector2(86, 94), Vector2(98, 88), Vector2(98, 76), Vector2(86, 82)
	])
	_poly_outlined(img, win_r, Color("#fde047"), Color("#d97706"), C_OUTLINE, 2.0)
	return img


# 6. Tier 3 Bell-Tower Church / Temple (land3.jpeg top-center right)
static func _draw_temple_totem() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 54.0, 19.0, 0.40)

	# Rear bell tower shaft & clock
	_draw_isometric_box(
		img, 88.0, 96.0, 22.0, 22.0, 56.0,
		Color("#d6c5ab"), Color("#f0e4d0"), Color("#cfc0a8"), 2.4
	)
	var spire := PackedVector2Array([
		Vector2(66, 29), Vector2(88, 12), Vector2(110, 29), Vector2(88, 40)
	])
	_poly_outlined(img, spire, Color("#9e6238"), Color("#6e4222"), C_OUTLINE, 2.4)
	_aa_line(img, 88.0, 4.0, 88.0, 14.0, C_OUTLINE, 2.6)
	_aa_circle_outlined(img, 77.0, 52.0, 6.0, Color("#fefae0"), C_OUTLINE, 2.0)

	# Main church nave body & pitched roof
	_draw_isometric_box(
		img, 64.0, 126.0, 36.0, 42.0, 34.0,
		Color("#d6c5ab"), Color("#f2e6d4"), Color("#d4c3aa"), 2.5
	)
	_draw_pitched_roof(
		img, 64.0, 92.0, 40.0, 44.0, 26.0,
		Color("#b57647"), Color("#945c34"), Color("#ebe0ce"), 2.5
	)
	# Portal doors on front-left gable
	var portal := PackedVector2Array([
		Vector2(40, 114), Vector2(52, 120), Vector2(52, 98), Vector2(40, 92)
	])
	_poly_outlined(img, portal, Color("#7c4d28"), Color("#4f2f16"), C_OUTLINE, 2.2)
	return img


# 7. Tier 4 Four-Turret Crenellated Castle Keep (land3.jpeg middle-left)
static func _draw_citadel_keep() -> Image:
	var img := _new_canvas(160, 160)
	_drop_shadow(img, 80.0, 138.0, 66.0, 24.0, 0.42)

	# Back corner tower
	_draw_isometric_box(
		img, 80.0, 92.0, 20.0, 20.0, 52.0,
		Color("#d4d0c8"), Color("#bdb8b0"), Color("#8f8a82"), 2.2
	)
	# Left & Right corner towers (drawn behind front wall)
	_draw_isometric_box(
		img, 36.0, 114.0, 20.0, 20.0, 54.0,
		Color("#d4d0c8"), Color("#c4bfb6"), Color("#948f86"), 2.4
	)
	_draw_isometric_box(
		img, 124.0, 114.0, 20.0, 20.0, 54.0,
		Color("#d4d0c8"), Color("#bab5ac"), Color("#87827a"), 2.4
	)
	# Main curtain walls box
	_draw_isometric_box(
		img, 80.0, 136.0, 48.0, 48.0, 42.0,
		Color("#9e9990"), Color("#c7c2b8"), Color("#969188"), 2.5
	)
	# Front corner tower
	_draw_isometric_box(
		img, 80.0, 142.0, 20.0, 20.0, 54.0,
		Color("#dedad2"), Color("#ccc7be"), Color("#969188"), 2.5
	)
	# Arched iron portcullis gate on front-left curtain wall
	var gate := PackedVector2Array([
		Vector2(46, 119), Vector2(62, 127), Vector2(62, 105), Vector2(54, 97), Vector2(46, 99)
	])
	_poly_outlined(img, gate, Color("#3b3530"), Color("#1f1b18"), C_OUTLINE, 2.4)
	_aa_line(img, 51.0, 99.0, 51.0, 121.0, Color("#78716c"), 1.8)
	_aa_line(img, 57.0, 101.0, 57.0, 124.0, Color("#78716c"), 1.8)
	return img


# 8. Tier 3/4 Windmill with Four Canvas Sails (land3.jpeg center)
static func _draw_windmill() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 38.0, 14.0, 0.38)

	# Tapering cylindrical/octagonal stone & timber tower
	var tower := PackedVector2Array([
		Vector2(54, 54), Vector2(90, 54), Vector2(98, 118),
		Vector2(72, 126), Vector2(46, 118)
	])
	_poly_outlined(img, tower, Color("#ebdcc4"), Color("#bfa98a"), C_OUTLINE, 2.5)

	# Conical wooden cap
	var cap := PackedVector2Array([
		Vector2(50, 54), Vector2(72, 34), Vector2(94, 54), Vector2(72, 60)
	])
	_poly_outlined(img, cap, Color("#996236"), Color("#633d1e"), C_OUTLINE, 2.5)

	# Four angled wooden/canvas sails radiating from hub (64, 54)
	var hub := Vector2(64.0, 54.0)
	var dirs := [
		Vector2(-38, -38), Vector2(38, -38), Vector2(38, 38), Vector2(-38, 38)
	]
	for d in dirs:
		var tip: Vector2 = hub + d
		var perp := Vector2(-d.y, d.x).normalized() * 9.0
		var blade := PackedVector2Array([
			hub + d * 0.18,
			tip,
			tip + perp,
			hub + d * 0.18 + perp
		])
		_poly_outlined(img, blade, Color("#fbf7ee"), Color("#dfd3bc"), C_OUTLINE, 2.2)
		_aa_line(img, hub.x, hub.y, tip.x, tip.y, Color("#5c3618"), 3.2)
	_aa_circle_outlined(img, hub.x, hub.y, 5.5, Color("#784820"), C_OUTLINE, 2.2)
	return img


# 9. Tier 3/4 Two-Tier Guard Watchtower (land3.jpeg center-left)
static func _draw_watchtower() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 124.0, 38.0, 14.0, 0.38)

	# Lower stone-and-timber shaft
	_draw_isometric_box(
		img, 72.0, 126.0, 26.0, 26.0, 48.0,
		Color("#b8a68e"), Color("#d9cbb8"), Color("#b09e86"), 2.4
	)
	# Upper timber lookout gallery
	_draw_isometric_box(
		img, 72.0, 78.0, 30.0, 30.0, 22.0,
		Color("#7c4e29"), Color("#9c6438"), Color("#704523"), 2.4
	)
	# Pyramidal shingled roof
	var roof_l := PackedVector2Array([
		Vector2(42, 41), Vector2(72, 18), Vector2(72, 56)
	])
	var roof_r := PackedVector2Array([
		Vector2(72, 18), Vector2(102, 41), Vector2(72, 56)
	])
	_poly_outlined(img, roof_l, Color("#ab7042"), Color("#85532c"), C_OUTLINE, 2.4)
	_poly_outlined(img, roof_r, Color("#85532c"), Color("#613b1e"), C_OUTLINE, 2.4)
	return img


# 10. Tier 4 Grand Gothic Cathedral (land3.jpeg middle-right)
static func _draw_cathedral() -> Image:
	var img := _new_canvas(160, 160)
	_drop_shadow(img, 80.0, 140.0, 66.0, 24.0, 0.42)

	# Main stone nave & transept boxes
	_draw_isometric_box(
		img, 80.0, 136.0, 52.0, 52.0, 48.0,
		Color("#b8b2a8"), Color("#e0d6c5"), Color("#b5aa99"), 2.5
	)
	# Steep gothic slate roof
	_draw_pitched_roof(
		img, 80.0, 88.0, 54.0, 54.0, 32.0,
		Color("#7c858e"), Color("#576069"), Color("#dfd5c4"), 2.5
	)
	# Central crossing bell tower & tall gothic spire
	_draw_isometric_box(
		img, 80.0, 68.0, 22.0, 22.0, 32.0,
		Color("#b8b2a8"), Color("#e0d6c5"), Color("#b5aa99"), 2.4
	)
	var spire_l := PackedVector2Array([
		Vector2(58, 25), Vector2(80, 4), Vector2(80, 36)
	])
	var spire_r := PackedVector2Array([
		Vector2(80, 4), Vector2(102, 25), Vector2(80, 36)
	])
	_poly_outlined(img, spire_l, Color("#7c858e"), Color("#5c646d"), C_OUTLINE, 2.4)
	_poly_outlined(img, spire_r, Color("#5c646d"), Color("#3f464d"), C_OUTLINE, 2.4)

	# Glowing stained-glass lancet windows
	for wx_v in [44.0, 60.0]:
		var wx: float = float(wx_v)
		var wy: float = 136.0 - (80.0 - wx) * 0.5
		var win := PackedVector2Array([
			Vector2(wx, wy - 12.0), Vector2(wx + 8.0, wy - 8.0),
			Vector2(wx + 8.0, wy - 32.0), Vector2(wx + 4.0, wy - 38.0), Vector2(wx, wy - 34.0)
		])
		_poly_outlined(img, win, Color("#f59e0b"), Color("#ef4444"), C_OUTLINE, 2.0)

	# Sweeping stone front stairs
	var stairs := PackedVector2Array([
		Vector2(68, 130), Vector2(92, 130), Vector2(84, 148), Vector2(64, 148)
	])
	_poly_outlined(img, stairs, Color("#cbd5e1"), Color("#94a3b8"), C_OUTLINE, 2.2)
	return img


# 11. Megalithic Stone Circle / Unity Monument (land3.jpeg top-right)
static func _draw_prop_unity_monument() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 114.0, 56.0, 20.0, 0.36)

	var stones := [
		Vector2(34, 88), Vector2(54, 68), Vector2(82, 66),
		Vector2(110, 82), Vector2(96, 112), Vector2(48, 112)
	]
	for st in stones:
		_draw_isometric_box(
			img, st.x, st.y, 10.0, 8.0, 34.0,
			Color("#cbd5e1"), Color("#94a3b8"), Color("#64748b"), 2.2
		)
	# Central square altar with glowing crimson/gold seal
	_draw_isometric_box(
		img, 72.0, 96.0, 16.0, 16.0, 10.0,
		Color("#ef4444"), Color("#94a3b8"), Color("#64748b"), 2.2
	)
	return img


# 12. Isometric Timber Palisade Wall (land3.jpeg bottom-left)
static func _draw_palisade_wall() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 104.0, 48.0, 16.0, 0.35)
	for i in range(9):
		var t := float(i) / 8.0
		var lx := lerpf(26.0, 102.0, t)
		var ly := lerpf(84.0, 116.0, t)
		var post := PackedVector2Array([
			Vector2(lx - 5.0, ly), Vector2(lx - 5.0, ly - 46.0),
			Vector2(lx, ly - 56.0), Vector2(lx + 5.0, ly - 46.0), Vector2(lx + 5.0, ly)
		])
		_poly_outlined(img, post, Color("#b07d4f"), Color("#784820"), C_OUTLINE, 2.2)
	_aa_line(img, 24.0, 62.0, 104.0, 94.0, Color("#4a2c14"), 4.5)
	_aa_line(img, 24.0, 76.0, 104.0, 108.0, Color("#4a2c14"), 4.5)
	return img


# 13. Isometric Crenellated Stone Wall Segment (land3.jpeg bottom-left)
static func _draw_stone_wall() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 50.0, 18.0, 0.38)
	_draw_isometric_box(
		img, 88.0, 114.0, 64.0, 16.0, 42.0,
		Color("#d4d0c8"), Color("#b8b2a8"), Color("#87827a"), 2.5
	)
	for m in range(4):
		var mx := 34.0 + float(m) * 18.0
		var my := 45.0 + float(m) * 9.0
		_draw_isometric_box(
			img, mx, my, 10.0, 14.0, 10.0,
			Color("#e5e0d8"), Color("#c7c2b8"), Color("#948f86"), 2.0
		)
	return img


# 14. Overflowing Gold Treasure Chest (land3.jpeg bottom-right-center)
static func _draw_prop_tribute_chest() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 38.0, 14.0, 0.38)
	_draw_isometric_box(
		img, 64.0, 108.0, 32.0, 26.0, 24.0,
		Color("#fbbf24"), Color("#9c5a25"), Color("#6e3d16"), 2.5
	)
	# Gleaming gold coin mound inside open chest
	_aa_ellipse_outlined(img, 64.0, 68.0, 24.0, 12.0, Color("#fde047"), C_OUTLINE, 2.2)
	_aa_ellipse(img, 62.0, 66.0, 16.0, 8.0, Color("#fef08a"))
	return img


# 15. Isometric Timber Catapult / Siege Engine (land3.jpeg bottom-right)
static func _draw_prop_siege_engine() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 44.0, 16.0, 0.38)
	# Base timber frame
	_draw_isometric_box(
		img, 64.0, 104.0, 38.0, 28.0, 8.0,
		Color("#9c6638"), Color("#7c4d25"), Color("#5c3618"), 2.4
	)
	# Upright A-frame & throwing arm with spoon
	_aa_line(img, 42.0, 88.0, 60.0, 46.0, C_OUTLINE, 7.0)
	_aa_line(img, 42.0, 88.0, 60.0, 46.0, Color("#8c582e"), 4.2)
	_aa_line(img, 76.0, 92.0, 60.0, 46.0, C_OUTLINE, 7.0)
	_aa_line(img, 76.0, 92.0, 60.0, 46.0, Color("#8c582e"), 4.2)
	_aa_line(img, 52.0, 74.0, 96.0, 28.0, C_OUTLINE, 7.5)
	_aa_line(img, 52.0, 74.0, 96.0, 28.0, Color("#a86e3e"), 4.5)
	_aa_circle_outlined(img, 98.0, 26.0, 10.0, Color("#784820"), C_OUTLINE, 2.4)
	# Wooden wheels
	_aa_circle_outlined(img, 42.0, 96.0, 11.0, Color("#6e4220"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 84.0, 96.0, 11.0, Color("#6e4220"), C_OUTLINE, 2.4)
	return img


# 16. Rural Plowed Golden Wheat Field with Haystacks (crop_field)
static func _draw_crop_field() -> Image:
	var img := _new_canvas(144, 144)
	var plot := PackedVector2Array([
		Vector2(72, 34), Vector2(132, 66), Vector2(72, 102), Vector2(12, 66)
	])
	_poly_outlined(img, plot, Color("#8c5a32"), Color("#5c381c"), C_OUTLINE, 2.4)
	# Golden wheat furrow strips
	for i in range(1, 6):
		var t := float(i) / 6.0
		var a := Vector2(12, 66).lerp(Vector2(72, 34), t)
		var b := Vector2(72, 102).lerp(Vector2(132, 66), t)
		_aa_line(img, a.x + 8.0, a.y + 4.0, b.x - 8.0, b.y - 4.0, Color("#eab308"), 5.5)
		_aa_line(img, a.x + 8.0, a.y + 2.0, b.x - 8.0, b.y - 6.0, Color("#fde047"), 3.0)
	# Bundled golden haystacks
	for hs in [Vector2(56, 62), Vector2(88, 72)]:
		var stack := PackedVector2Array([
			Vector2(hs.x - 16.0, hs.y + 10.0), Vector2(hs.x, hs.y - 16.0), Vector2(hs.x + 16.0, hs.y + 10.0)
		])
		_poly_outlined(img, stack, Color("#fde047"), Color("#d97706"), C_OUTLINE, 2.2)
	return img


# 17. Rural Wooden Paddock with Grazing Sheep & Cattle (pasture_pen)
static func _draw_pasture_pen() -> Image:
	var img := _new_canvas(144, 144)
	var meadow := PackedVector2Array([
		Vector2(72, 36), Vector2(130, 68), Vector2(72, 102), Vector2(14, 68)
	])
	_poly_outlined(img, meadow, Color("#84cc16"), Color("#4d7c0f"), C_OUTLINE, 2.4)
	# Split-rail wooden fence along edges
	var corners := [Vector2(72, 36), Vector2(130, 68), Vector2(72, 102), Vector2(14, 68)]
	for i in range(4):
		var c0: Vector2 = corners[i]
		var c1: Vector2 = corners[(i + 1) % 4]
		_aa_line(img, c0.x, c0.y - 10.0, c1.x, c1.y - 10.0, Color("#8c582e"), 3.0)
		_aa_line(img, c0.x, c0.y, c0.x, c0.y - 16.0, C_OUTLINE, 3.5)
	# Grazing fluffy white sheep & brown cow
	_aa_ellipse_outlined(img, 54.0, 66.0, 11.0, 8.0, Color("#f8fafc"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 44.0, 64.0, 4.5, Color("#334155"), C_OUTLINE, 1.8)
	_aa_ellipse_outlined(img, 86.0, 72.0, 14.0, 9.0, Color("#9a5828"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 98.0, 69.0, 5.5, Color("#783f18"), C_OUTLINE, 1.8)
	return img


static func _draw_act_overexploit() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 42.0, 15.0, 0.38)
	_draw_isometric_box(
		img, 64.0, 108.0, 34.0, 34.0, 36.0,
		Color("#475569"), Color("#78716c"), Color("#57534e"), 2.5
	)
	_aa_circle_outlined(img, 52.0, 84.0, 10.0, Color("#f97316"), C_OUTLINE, 2.2)
	_aa_circle(img, 52.0, 84.0, 5.0, Color("#fde047"))
	return img


# 18. Isometric Covered Trade Wagon (land3.jpeg bottom-center)
static func _draw_covered_wagon() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 44.0, 15.0, 0.38)

	# Wooden wagon box
	_draw_isometric_box(
		img, 68.0, 98.0, 36.0, 26.0, 14.0,
		Color("#9c6638"), Color("#8c582e"), Color("#694020"), 2.4
	)
	# Rounded canvas canopy hood with stripes
	var hood := PackedVector2Array([
		Vector2(34, 68), Vector2(44, 38), Vector2(74, 30),
		Vector2(98, 46), Vector2(94, 72), Vector2(68, 84)
	])
	_poly_outlined(img, hood, Color("#f7f2e4"), Color("#d8cbb2"), C_OUTLINE, 2.5)
	_aa_line(img, 52.0, 36.0, 50.0, 74.0, Color("#10b981"), 4.0)
	_aa_line(img, 72.0, 32.0, 72.0, 80.0, Color("#f97316"), 4.0)

	# Spoked wooden wheels
	for wc in [Vector2(48, 96), Vector2(82, 92)]:
		_aa_circle_outlined(img, wc.x, wc.y, 13.0, Color("#855228"), C_OUTLINE, 2.5)
		_aa_circle_outlined(img, wc.x, wc.y, 8.0, Color("#c9b898"), C_OUTLINE, 1.8)
		_aa_circle(img, wc.x, wc.y, 3.0, C_OUTLINE)
	return img


# 19. Carved Eagle/Owl Totem Pole (land3.jpeg bottom-left)
static func _draw_totem_pole(wing_col: Color, accent_col: Color) -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 112.0, 28.0, 10.0, 0.38)

	# Outstretched carved wings
	var wings := PackedVector2Array([
		Vector2(18, 42), Vector2(64, 52), Vector2(110, 42),
		Vector2(102, 58), Vector2(64, 66), Vector2(26, 58)
	])
	_poly_outlined(img, wings, wing_col, accent_col, C_OUTLINE, 2.5)

	# Vertical carved cedar column
	var pole := PackedVector2Array([
		Vector2(50, 22), Vector2(78, 22), Vector2(78, 112), Vector2(50, 112)
	])
	_poly_outlined(img, pole, Color("#b07848"), Color("#784b26"), C_OUTLINE, 2.6)

	# Eagle beak & eyes
	var beak := PackedVector2Array([
		Vector2(58, 36), Vector2(70, 36), Vector2(64, 48)
	])
	_poly_outlined(img, beak, Color("#fbbf24"), Color("#d97706"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 57.0, 32.0, 4.0, Color("#fefae0"), C_OUTLINE, 1.8)
	_aa_circle_outlined(img, 71.0, 32.0, 4.0, Color("#fefae0"), C_OUTLINE, 1.8)
	return img


static func _draw_act_exchange() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 44.0, 15.0, 0.36)
	_draw_isometric_box(
		img, 64.0, 108.0, 36.0, 28.0, 18.0,
		Color("#deb887"), Color("#9c6644"), Color("#6b3e26"), 2.4
	)
	var awning := PackedVector2Array([
		Vector2(24, 56), Vector2(64, 38), Vector2(104, 56), Vector2(64, 74)
	])
	_poly_outlined(img, awning, Color("#10b981"), Color("#059669"), C_OUTLINE, 2.5)
	return img


# 20. Ivy-Covered Crumbling Stone Ruins (land3.jpeg bottom-right)
static func _draw_ruins_stone() -> Image:
	var img := _new_canvas(144, 144)
	_drop_shadow(img, 72.0, 122.0, 56.0, 20.0, 0.38)

	# Broken left stone wall with jagged top
	var left_wall := PackedVector2Array([
		Vector2(24, 96), Vector2(24, 52), Vector2(40, 46),
		Vector2(52, 68), Vector2(66, 62), Vector2(72, 84), Vector2(72, 120)
	])
	_poly_outlined(img, left_wall, Color("#c7c2b8"), Color("#948f86"), C_OUTLINE, 2.5)

	# Broken right stone wall
	var right_wall := PackedVector2Array([
		Vector2(72, 120), Vector2(72, 74), Vector2(88, 44),
		Vector2(104, 56), Vector2(120, 48), Vector2(120, 96)
	])
	_poly_outlined(img, right_wall, Color("#9e9990"), Color("#706b63"), C_OUTLINE, 2.5)

	# Overgrown green ivy & moss clusters
	for iv in [Vector2(30, 56), Vector2(86, 52), Vector2(114, 62), Vector2(68, 96)]:
		_aa_circle_outlined(img, iv.x, iv.y, 12.0, Color("#52a838"), C_OUTLINE, 2.0)
		_aa_circle(img, iv.x - 2.0, iv.y - 2.0, 7.0, Color("#7ae058"))
	return img


static func _draw_barricade_spikes() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 44.0, 14.0, 0.35)
	_aa_line(img, 24.0, 76.0, 104.0, 96.0, C_OUTLINE, 9.0)
	_aa_line(img, 24.0, 76.0, 104.0, 96.0, Color("#8c582e"), 5.5)
	for sx_v in [36.0, 54.0, 72.0, 90.0]:
		var sx: float = float(sx_v)
		_aa_line(img, sx - 12.0, 106.0, sx + 12.0, 52.0, C_OUTLINE, 7.0)
		_aa_line(img, sx - 12.0, 106.0, sx + 12.0, 52.0, Color("#a86e3e"), 4.2)
		_aa_line(img, sx + 12.0, 106.0, sx - 12.0, 54.0, C_OUTLINE, 7.0)
		_aa_line(img, sx + 12.0, 106.0, sx - 12.0, 54.0, Color("#784820"), 4.2)
	return img


static func _draw_road_block_sign() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 106.0, 36.0, 12.0, 0.34)
	_aa_line(img, 40.0, 104.0, 40.0, 54.0, Color("#5c3317"), 6.0)
	_aa_line(img, 88.0, 104.0, 88.0, 54.0, Color("#5c3317"), 6.0)
	var board := PackedVector2Array([
		Vector2(28, 52), Vector2(100, 52), Vector2(100, 74), Vector2(28, 74)
	])
	_poly_outlined(img, board, Color("#f59e0b"), Color("#d97706"), C_OUTLINE, 2.4)
	return img


# 21. Wooden Lamppost with Glowing Lantern (land3.jpeg bottom-right)
static func _draw_road_lantern() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 110.0, 22.0, 8.0, 0.34)
	var post := PackedVector2Array([
		Vector2(66, 26), Vector2(76, 26), Vector2(76, 110), Vector2(66, 110)
	])
	_poly_outlined(img, post, Color("#9c6638"), Color("#694020"), C_OUTLINE, 2.4)
	var arm := PackedVector2Array([
		Vector2(44, 32), Vector2(78, 26), Vector2(78, 34), Vector2(44, 40)
	])
	_poly_outlined(img, arm, Color("#9c6638"), Color("#694020"), C_OUTLINE, 2.2)
	# Glowing lantern box
	var lantern := PackedVector2Array([
		Vector2(40, 48), Vector2(56, 48), Vector2(54, 68), Vector2(42, 68)
	])
	_poly_outlined(img, lantern, Color("#fef08a"), Color("#f59e0b"), C_OUTLINE, 2.2)
	return img


# 22. Heraldic War Banner Standard (land3.jpeg bottom-right-center)
static func _draw_prop_war_banner() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 110.0, 28.0, 10.0, 0.36)
	_aa_line(img, 64.0, 18.0, 64.0, 110.0, C_OUTLINE, 7.0)
	_aa_line(img, 64.0, 18.0, 64.0, 110.0, Color("#8c582e"), 4.2)
	_aa_line(img, 36.0, 28.0, 92.0, 28.0, C_OUTLINE, 6.5)
	_aa_line(img, 36.0, 28.0, 92.0, 28.0, Color("#d97706"), 4.0)
	var banner := PackedVector2Array([
		Vector2(42, 30), Vector2(86, 30), Vector2(86, 82),
		Vector2(64, 96), Vector2(42, 82)
	])
	_poly_outlined(img, banner, Color("#ef4444"), Color("#b91c1c"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 64.0, 58.0, 11.0, Color("#fde047"), C_OUTLINE, 2.0)
	return img


static func _draw_prop_raid_loot() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 108.0, 36.0, 12.0, 0.36)
	_aa_ellipse_outlined(img, 58.0, 86.0, 26.0, 22.0, Color("#b07d4f"), C_OUTLINE, 2.5)
	_aa_ellipse_outlined(img, 58.0, 62.0, 16.0, 8.0, Color("#fbbf24"), C_OUTLINE, 2.2)
	_aa_line(img, 76.0, 104.0, 94.0, 48.0, Color("#5c3317"), 5.5)
	_aa_circle_outlined(img, 94.0, 42.0, 11.0, Color("#f97316"), C_OUTLINE, 2.0)
	_aa_circle(img, 94.0, 42.0, 6.0, Color("#fde047"))
	return img


static func _draw_prop_pact_totem() -> Image:
	var img := _new_canvas(128, 128)
	_drop_shadow(img, 64.0, 110.0, 34.0, 12.0, 0.36)
	_draw_isometric_box(
		img, 64.0, 110.0, 26.0, 26.0, 64.0,
		Color("#fbbf24"), Color("#e2e8f0"), Color("#94a3b8"), 2.4
	)
	_aa_circle_outlined(img, 64.0, 62.0, 12.0, Color("#10b981"), C_OUTLINE, 2.2)
	return img


static func _draw_effect_battle_sparks() -> Image:
	var img := _new_canvas(128, 128)
	_aa_line(img, 24.0, 64.0, 104.0, 64.0, Color("#ef4444"), 4.5)
	_aa_line(img, 64.0, 24.0, 64.0, 104.0, Color("#ef4444"), 4.5)
	_aa_line(img, 34.0, 34.0, 94.0, 94.0, Color("#f97316"), 4.0)
	_aa_line(img, 94.0, 34.0, 34.0, 94.0, Color("#f97316"), 4.0)
	_aa_circle_outlined(img, 64.0, 64.0, 18.0, Color("#fbbf24"), C_OUTLINE, 2.2)
	_aa_circle(img, 64.0, 64.0, 9.0, Color("#fef08a"))
	return img


# High-DPI 48x48 Illustrated Villager (land.jpeg / land2.jpeg)
static func draw_villager(step: int, tunic_color: Color) -> Image:
	var img := _new_canvas(48, 48)
	_drop_shadow(img, 24.0, 42.0, 11.0, 4.5, 0.35)
	var bob := -2.0 if step != 0 else 0.0

	# Legs
	var left_y := 33.0
	var right_y := 33.0
	if step == 1:
		left_y = 30.0
		right_y = 35.0
	elif step == 2:
		left_y = 35.0
		right_y = 30.0
	_aa_line(img, 20.0, 28.0 + bob, 19.0, left_y + 7.0, C_OUTLINE, 6.5)
	_aa_line(img, 20.0, 28.0 + bob, 19.0, left_y + 7.0, Color("#475569"), 3.8)
	_aa_line(img, 28.0, 28.0 + bob, 29.0, right_y + 7.0, C_OUTLINE, 6.5)
	_aa_line(img, 28.0, 28.0 + bob, 29.0, right_y + 7.0, Color("#475569"), 3.8)

	# Tunic torso
	var tunic := PackedVector2Array([
		Vector2(16, 18.0 + bob), Vector2(32, 18.0 + bob),
		Vector2(34, 32.0 + bob), Vector2(14, 32.0 + bob)
	])
	_poly_outlined(img, tunic, tunic_color.lightened(0.15), tunic_color.darkened(0.12), C_OUTLINE, 2.2)

	# Head & hair
	_aa_circle_outlined(img, 24.0, 13.0 + bob, 7.5, Color("#fcd5b5"), C_OUTLINE, 2.2)
	var hair := PackedVector2Array([
		Vector2(16, 12.0 + bob), Vector2(20, 5.0 + bob),
		Vector2(28, 5.0 + bob), Vector2(32, 12.0 + bob)
	])
	_poly_outlined(img, hair, Color("#6e3f20"), Color("#4a2912"), C_OUTLINE, 2.0)
	_aa_circle(img, 21.5, 13.5 + bob, 1.2, C_OUTLINE)
	_aa_circle(img, 26.5, 13.5 + bob, 1.2, C_OUTLINE)
	return img


# 64x64 UI Icons
static func _draw_icon_war() -> Image:
	var img := _new_canvas(64, 64)
	_aa_line(img, 10.0, 54.0, 54.0, 10.0, Color("#cbd5e1"), 5.0)
	_aa_line(img, 54.0, 54.0, 10.0, 10.0, Color("#cbd5e1"), 5.0)
	var shield := PackedVector2Array([
		Vector2(20, 16), Vector2(44, 16), Vector2(44, 38), Vector2(32, 52), Vector2(20, 38)
	])
	_poly_outlined(img, shield, Color("#ef4444"), Color("#991b1b"), C_OUTLINE, 2.5)
	_aa_circle(img, 32.0, 32.0, 5.0, Color("#fde047"))
	return img


static func _draw_icon_raid() -> Image:
	var img := _new_canvas(64, 64)
	_aa_ellipse_outlined(img, 28.0, 40.0, 16.0, 14.0, Color("#d97706"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 46.0, 24.0, 9.0, Color("#ef4444"), C_OUTLINE, 2.2)
	_aa_circle(img, 46.0, 24.0, 4.5, Color("#fde047"))
	return img


static func _draw_icon_pact() -> Image:
	var img := _new_canvas(64, 64)
	_aa_circle_outlined(img, 32.0, 32.0, 22.0, Color("#fbbf24"), C_OUTLINE, 2.5)
	_aa_circle_outlined(img, 32.0, 32.0, 15.0, Color("#10b981"), C_OUTLINE, 2.0)
	_aa_circle(img, 32.0, 32.0, 6.0, Color("#fef08a"))
	return img


static func _draw_icon_betrayal() -> Image:
	var img := _new_canvas(64, 64)
	_aa_circle_outlined(img, 22.0, 36.0, 12.0, Color("#d97706"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 42.0, 36.0, 12.0, Color("#d97706"), C_OUTLINE, 2.4)
	_aa_line(img, 48.0, 10.0, 18.0, 54.0, Color("#e11d48"), 5.5)
	return img


static func _draw_icon_defense() -> Image:
	var img := _new_canvas(64, 64)
	var shield := PackedVector2Array([
		Vector2(14, 14), Vector2(50, 14), Vector2(48, 40), Vector2(32, 54), Vector2(16, 40)
	])
	_poly_outlined(img, shield, Color("#cbd5e1"), Color("#64748b"), C_OUTLINE, 2.5)
	_aa_circle_outlined(img, 32.0, 32.0, 8.0, Color("#fbbf24"), C_OUTLINE, 2.0)
	return img


static func _draw_icon_merge() -> Image:
	var img := _new_canvas(64, 64)
	_aa_circle_outlined(img, 22.0, 36.0, 12.0, Color("#10b981"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 42.0, 36.0, 12.0, Color("#38bdf8"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 32.0, 22.0, 10.0, Color("#fbbf24"), C_OUTLINE, 2.4)
	return img


static func _draw_icon_tribute() -> Image:
	var img := _new_canvas(64, 64)
	var chest := PackedVector2Array([
		Vector2(14, 28), Vector2(50, 28), Vector2(50, 50), Vector2(14, 50)
	])
	_poly_outlined(img, chest, Color("#d97706"), Color("#78350f"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 32.0, 24.0, 10.0, Color("#fde047"), C_OUTLINE, 2.2)
	return img


static func _draw_icon_siege() -> Image:
	var img := _new_canvas(64, 64)
	var tower := PackedVector2Array([
		Vector2(20, 16), Vector2(44, 16), Vector2(46, 52), Vector2(18, 52)
	])
	_poly_outlined(img, tower, Color("#94a3b8"), Color("#475569"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 18.0, 44.0, 8.0, Color("#ef4444"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 46.0, 42.0, 8.0, Color("#f97316"), C_OUTLINE, 2.0)
	return img


static func _draw_ui_icon(icon_name: String) -> Image:
	if icon_name == "thought_bubble":
		return _draw_thought_bubble()

	var img := _new_canvas(64, 64)
	match icon_name:
		"tool_inspect":
			_aa_circle_outlined(img, 28.0, 28.0, 16.0, Color("#bae6fd"), C_OUTLINE, 2.5)
			_aa_line(img, 40.0, 40.0, 54.0, 54.0, Color("#8c5230"), 6.0)
		"tool_biome":
			_aa_ellipse_outlined(img, 32.0, 42.0, 16.0, 12.0, Color("#d4a373"), C_OUTLINE, 2.4)
			_aa_circle_outlined(img, 32.0, 22.0, 12.0, Color("#22c55e"), C_OUTLINE, 2.4)
		"tool_altitude":
			var mtn := PackedVector2Array([Vector2(12, 50), Vector2(32, 14), Vector2(52, 50)])
			_poly_outlined(img, mtn, Color("#cbd5e1"), Color("#64748b"), C_OUTLINE, 2.5)
		"tool_fertility":
			_aa_circle_outlined(img, 32.0, 32.0, 18.0, Color("#fde047"), C_OUTLINE, 2.5)
		"tool_sealevel":
			_aa_ellipse_outlined(img, 32.0, 36.0, 20.0, 12.0, Color("#38bdf8"), C_OUTLINE, 2.5)
		"season_wet":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#fbbf24"), C_OUTLINE, 2.5)
		"season_dry":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#7dd3fc"), C_OUTLINE, 2.5)
		"status_thriving":
			_draw_heart(img, Color("#10b981"), Color("#6ee7b7"))
		"status_stable":
			_draw_heart(img, Color("#0ea5e9"), Color("#7dd3fc"))
		"status_struggling":
			_draw_heart(img, Color("#f59e0b"), Color("#fde047"))
		"status_starving":
			_draw_heart(img, Color("#ef4444"), Color("#fca5a5"))
		"icon_forage":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#22c55e"), C_OUTLINE, 2.4)
		"icon_overexploit":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#f97316"), C_OUTLINE, 2.4)
		"icon_migrate":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#38bdf8"), C_OUTLINE, 2.4)
		"icon_cooperate":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#ef4444"), C_OUTLINE, 2.4)
		"icon_exchange":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#10b981"), C_OUTLINE, 2.4)
		"icon_dispute":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#e11d48"), C_OUTLINE, 2.4)
		"icon_innovate":
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#a855f7"), C_OUTLINE, 2.4)
		"icon_coop_link":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#10b981"), C_OUTLINE, 2.5)
		"icon_conflict_swords":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#ef4444"), C_OUTLINE, 2.5)
		"icon_broken_link":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#d97706"), C_OUTLINE, 2.5)
		_:
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#eab308"), C_OUTLINE, 2.4)
	return img


static func _draw_thought_bubble() -> Image:
	var img := _new_canvas(64, 64)
	_aa_ellipse_outlined(img, 32.0, 28.0, 22.0, 16.0, Color("#fffbeb"), C_OUTLINE, 2.4)
	_aa_circle_outlined(img, 20.0, 48.0, 5.0, Color("#fffbeb"), C_OUTLINE, 2.0)
	_aa_circle_outlined(img, 14.0, 56.0, 3.0, Color("#fffbeb"), C_OUTLINE, 1.8)
	return img


static func _draw_heart(img: Image, main_col: Color, hi_col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(32, 52), Vector2(14, 32), Vector2(18, 18),
		Vector2(32, 24), Vector2(46, 18), Vector2(50, 32)
	])
	_poly_outlined(img, pts, hi_col, main_col, C_OUTLINE, 2.4)
