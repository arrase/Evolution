class_name EvoVillageUiSprites
extends EvoPixelCanvas


static func draw_village_or_ui_sprite(sprite_name: String) -> Image:
	match sprite_name:
		"tier1_tent":
			return _draw_tier1_tent()
		"tier1_campfire":
			return _draw_tier1_campfire(0)
		"tier1_campfire_2":
			return _draw_tier1_campfire(1)
		"tier2_cottage":
			return _draw_tier2_cottage()
		"tier2_barn":
			return _draw_tier2_barn()
		"tier3_townhall":
			return _draw_tier3_townhall()
		"tier3_house":
			return _draw_tier3_house()
		"tier4_citadel":
			return _draw_tier4_citadel()
		"tier4_windmill":
			return _draw_tier4_windmill()
		"tier4_tower":
			return _draw_tier4_tower()
		"tier5_metropolis":
			return _draw_tier5_metropolis()
		"prop_unity_monument", "act_merge":
			return _draw_prop_unity_monument()
		"prop_defense_palisade":
			return _draw_prop_defense_palisade()
		"prop_defense_wall":
			return _draw_prop_defense_wall()
		"prop_defense_fortress", "act_fortify":
			return _draw_prop_defense_fortress()
		"prop_tribute_chest", "act_tribute":
			return _draw_prop_tribute_chest()
		"prop_siege_engine", "act_siege":
			return _draw_prop_siege_engine()
		"act_forage":
			return _draw_act_forage()
		"act_overexploit":
			return _draw_act_overexploit()
		"act_migrate":
			return _draw_act_migrate()
		"act_cooperate":
			return _draw_act_cooperate()
		"act_exchange":
			return _draw_act_exchange()
		"act_dispute":
			return _draw_act_dispute()
		"act_innovate":
			return _draw_act_innovate()
		"act_custom":
			return _draw_act_custom()
		"cultural_totem":
			return _draw_cultural_totem()
		"ruins":
			return _draw_ruins()
		"caravan_cart":
			return _draw_caravan_cart()
		"settler_wagon":
			return _draw_settler_wagon()
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
		"prop_betrayal_ruin", "act_betrayal":
			return _draw_prop_betrayal_ruin()
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


static func _draw_tier1_tent() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 27, 11, 3, C_SHADOW)
	for y in range(10, 27):
		var half_w := int(float(y - 9) * 0.65)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#e8d1a7") if dx < 0 else Color("#cbb082")
			if abs(dx) <= 2 and y >= 18:
				col = Color("#3d2314")
			elif y == 14 or y == 20:
				col = col.darkened(0.08)
			_px(img, 16 + dx, y, col)
	_rect(img, 15, 8, 2, 3, Color("#6b3e26"))
	_apply_soft_outline(img)
	return img


static func _draw_tier1_campfire(frame: int) -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 18, 6, 2, C_SHADOW)
	_rect(img, 6, 16, 12, 3, Color("#6b3e26"))
	_rect(img, 8, 15, 8, 4, Color("#8c5230"))
	_circle(img, 7, 18, 2, Color("#78716c"))
	_circle(img, 17, 18, 2, Color("#78716c"))
	_circle(img, 12, 19, 2, Color("#57534e"))
	var flame_shift := -1 if frame == 0 else 1
	_ellipse(img, 12 + flame_shift, 13, 4, 4, Color("#ef4444"))
	_ellipse(img, 12, 13, 3, 3, Color("#f97316"))
	_ellipse(img, 12 - flame_shift, 14, 2, 2, Color("#fde047"))
	_px(img, 12 + flame_shift, 7 + frame, Color("#fb923c"))
	_apply_soft_outline(img)
	return img


static func _draw_tier2_cottage() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 31, 13, 3, C_SHADOW)
	_rect(img, 24, 7, 4, 9, Color("#78716c"))
	_rect(img, 23, 6, 6, 2, Color("#57534e"))
	_rect(img, 8, 17, 20, 13, Color("#b07d4f"))
	for y in range(18, 30, 3):
		_line(img, 8, y, 27, y, Color("#8c5830"))
	for y in range(8, 19):
		var half_w := 3 + int(float(y - 8) * 1.1)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#a8382b") if (y + dx) % 2 == 0 else Color("#8f2b20")
			if dx < 0:
				col = col.lightened(0.10)
			_px(img, 18 + dx, y, col)
	_rect(img, 13, 22, 4, 8, Color("#5c3317"))
	_px(img, 16, 26, Color("#fbbf24"))
	_rect(img, 20, 21, 5, 4, Color("#fde047"))
	_line(img, 22, 21, 22, 24, Color("#6b3e26"))
	_line(img, 20, 22, 24, 22, Color("#6b3e26"))
	_apply_soft_outline(img)
	return img


static func _draw_tier2_barn() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 31, 13, 3, C_SHADOW)
	_rect(img, 8, 16, 20, 14, Color("#b9382c"))
	_rect(img, 9, 16, 9, 14, Color("#cf4638"))
	for y in range(7, 17):
		var half_w := 4 + int(float(y - 7) * 1.05)
		for dx in range(-half_w, half_w + 1):
			_px(img, 18 + dx, y, Color("#6b3e26") if (y % 2 == 0) else Color("#542f1b"))
	_rect_outlined(img, 13, 21, 10, 9, Color("#9e2a20"), Color("#f5ebe0"))
	_line(img, 13, 21, 22, 29, Color("#f5ebe0"))
	_line(img, 22, 21, 13, 29, Color("#f5ebe0"))
	_rect(img, 16, 13, 4, 4, Color("#3b2112"))
	_rect(img, 16, 15, 4, 2, Color("#eab308"))
	_apply_soft_outline(img)
	return img


static func _draw_tier3_townhall() -> Image:
	var img := _new_canvas(44, 44)
	_ellipse(img, 22, 38, 17, 4, C_SHADOW)
	_rect(img, 7, 20, 30, 17, Color("#e6ccb2"))
	_rect(img, 7, 32, 30, 5, Color("#78716c"))
	for px_i in [7, 15, 28, 36]:
		_rect(img, px_i, 20, 2, 17, Color("#6b3e26"))
	for y in range(11, 21):
		var half_w := 6 + int(float(y - 11) * 1.3)
		for dx in range(-half_w, half_w + 1):
			var col := Color("#3b6e8c") if (dx + y) % 2 == 0 else Color("#2d5873")
			if dx < 0:
				col = col.lightened(0.12)
			_px(img, 22 + dx, y, col)
	_rect(img, 17, 6, 10, 15, Color("#d4a373"))
	for y in range(2, 7):
		var hw := 1 + (y - 2) * 1
		_rect(img, 22 - hw, y, hw * 2 + 1, 1, Color("#b5651d"))
	_circle(img, 22, 13, 3, Color("#fefae0"))
	_px(img, 22, 13, C_OUTLINE)
	_px(img, 22, 11, C_OUTLINE)
	_px(img, 24, 13, C_OUTLINE)
	_rect(img, 19, 28, 6, 9, Color("#5c3317"))
	_rect(img, 10, 24, 4, 5, Color("#fde047"))
	_rect(img, 30, 24, 4, 5, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_tier3_house() -> Image:
	var img := _new_canvas(36, 36)
	_ellipse(img, 18, 31, 13, 3, C_SHADOW)
	_rect(img, 8, 17, 20, 13, Color("#f2d0a9"))
	_rect(img, 8, 27, 20, 3, Color("#8d99ae"))
	for y in range(8, 18):
		var hw := 3 + int(float(y - 8) * 1.1)
		for dx in range(-hw, hw + 1):
			_px(img, 18 + dx, y, Color("#c85a32") if dx < 0 else Color("#a64421"))
	_rect(img, 11, 22, 4, 8, Color("#6b3e26"))
	_rect(img, 19, 20, 6, 5, Color("#fde047"))
	_rect(img, 18, 25, 8, 2, Color("#6b3e26"))
	_px(img, 19, 24, Color("#ff5964"))
	_px(img, 21, 24, Color("#2ec4b6"))
	_px(img, 24, 24, Color("#ffbe0b"))
	_apply_soft_outline(img)
	return img


static func _draw_tier4_citadel() -> Image:
	var img := _new_canvas(48, 48)
	_ellipse(img, 24, 42, 19, 4, C_SHADOW)
	_rect(img, 6, 24, 36, 17, Color("#9ca3af"))
	_rect(img, 8, 24, 16, 17, Color("#d1d5db"))
	_rect(img, 5, 16, 8, 25, Color("#9ca3af"))
	_rect(img, 35, 16, 8, 25, Color("#6b7280"))
	_rect(img, 14, 12, 20, 16, Color("#e5e7eb"))
	for y in range(4, 13):
		var hw := 2 + int(float(y - 4) * 1.15)
		_rect(img, 24 - hw, y, hw * 2 + 1, 1, Color("#1d4ed8") if y % 2 == 0 else Color("#2563eb"))
	for cx in [9, 39]:
		for y in range(10, 17):
			var hw := 1 + int(float(y - 10) * 0.65)
			_rect(img, cx - hw, y, hw * 2 + 1, 1, Color("#b45309"))
	_circle(img, 24, 18, 3, Color("#fbbf24"))
	_rect(img, 20, 31, 8, 10, Color("#451a03"))
	_rect(img, 15, 19, 3, 4, Color("#fde047"))
	_rect(img, 30, 19, 3, 4, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_tier4_windmill() -> Image:
	var img := _new_canvas(40, 40)
	_ellipse(img, 20, 35, 11, 3, C_SHADOW)
	for y in range(12, 35):
		var hw := 4 + int(float(y - 12) * 0.22)
		_rect(img, 20 - hw, y, hw * 2, 1, Color("#f3e5ab") if y % 3 != 0 else Color("#e0ce8b"))
	_ellipse(img, 20, 12, 5, 3, Color("#8c3b2b"))
	_line(img, 7, 4, 33, 24, Color("#6b3e26"))
	_line(img, 33, 4, 7, 24, Color("#6b3e26"))
	_line(img, 8, 4, 33, 23, Color("#fefae0"))
	_line(img, 32, 4, 7, 23, Color("#fefae0"))
	_circle(img, 20, 14, 2, Color("#d97706"))
	_rect(img, 18, 28, 4, 7, Color("#5c3317"))
	_apply_soft_outline(img)
	return img


static func _draw_tier4_tower() -> Image:
	var img := _new_canvas(32, 36)
	_ellipse(img, 16, 32, 9, 2, C_SHADOW)
	_rect(img, 10, 11, 12, 21, Color("#94a3b8"))
	_rect(img, 11, 11, 5, 21, Color("#cbd5e1"))
	for bx in [9, 13, 17, 21]:
		_rect(img, bx, 8, 2, 4, Color("#cbd5e1"))
	_rect(img, 14, 16, 4, 5, Color("#fde047"))
	_rect(img, 14, 26, 4, 6, Color("#451a03"))
	_apply_soft_outline(img)
	return img


static func _draw_tier5_metropolis() -> Image:
	var img := _new_canvas(52, 52)
	_ellipse(img, 26, 46, 22, 4, C_SHADOW)
	# Stepped marble terrace
	_rect(img, 4, 41, 44, 5, Color("#94a3b8"))
	_rect(img, 6, 37, 40, 4, Color("#cbd5e1"))
	# Central gilded bronze dome
	_circle(img, 26, 20, 10, Color("#f59e0b"))
	_circle(img, 25, 19, 8, Color("#fbbf24"))
	_ellipse(img, 24, 16, 4, 3, Color("#fef08a"))
	_rect(img, 25, 6, 2, 5, Color("#fbbf24"))
	_circle(img, 26, 6, 2, Color("#fef08a"))
	# Central palace body & white colonnade pillars
	_rect(img, 15, 20, 22, 17, Color("#e2e8f0"))
	_rect(img, 14, 19, 24, 2, Color("#fbbf24"))
	for px_i in [16, 20, 31, 35]:
		_rect(img, px_i, 21, 2, 16, Color("#f8fafc"))
	# Twin flanking stone towers
	_rect(img, 6, 14, 10, 23, Color("#cbd5e1"))
	_rect(img, 11, 14, 5, 23, Color("#94a3b8"))
	_rect(img, 37, 14, 10, 23, Color("#cbd5e1"))
	_rect(img, 42, 14, 5, 23, Color("#94a3b8"))
	# Royal blue spires & gold finials
	for cx in [11, 42]:
		for y in range(6, 15):
			var hw := 1 + int(float(y - 6) * 0.55)
			_rect(img, cx - hw, y, hw * 2 + 1, 1, Color("#1e3a8a") if y % 2 == 0 else Color("#2563eb"))
		_rect(img, cx, 3, 2, 3, Color("#fbbf24"))
		_rect(img, cx - 1, 18, 3, 5, Color("#fde047"))
	# Arched double portal
	_circle(img, 26, 29, 4, Color("#451a03"))
	_rect(img, 22, 29, 8, 8, Color("#451a03"))
	_line(img, 26, 26, 26, 36, Color("#fbbf24"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_unity_monument() -> Image:
	var img := _new_canvas(28, 32)
	_ellipse(img, 14, 28, 10, 3, C_SHADOW)
	# Stepped stone plinth
	_rect(img, 4, 25, 20, 4, Color("#94a3b8"))
	_rect(img, 5, 23, 18, 2, Color("#cbd5e1"))
	# Twin marble pillars
	_rect(img, 6, 10, 5, 15, Color("#f8fafc"))
	_rect(img, 9, 10, 2, 15, Color("#cbd5e1"))
	_rect(img, 18, 10, 5, 15, Color("#f8fafc"))
	_rect(img, 21, 10, 2, 15, Color("#cbd5e1"))
	# Overarching stone lintel
	_rect(img, 5, 7, 19, 5, Color("#cbd5e1"))
	_rect(img, 6, 8, 17, 3, Color("#e2e8f0"))
	# Central golden keystone & jade inlay
	_rect(img, 12, 6, 5, 6, Color("#fbbf24"))
	_rect(img, 13, 7, 3, 4, Color("#10b981"))
	_px(img, 14, 8, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_defense_palisade() -> Image:
	var img := _new_canvas(32, 28)
	_ellipse(img, 16, 24, 13, 3, C_SHADOW)
	# 7 pointed vertical timber logs
	var log_xs := [4, 8, 12, 16, 20, 24, 27]
	for lx in log_xs:
		_rect(img, lx, 9, 3, 15, Color("#78350f"))
		_rect(img, lx, 9, 2, 15, Color("#92400e"))
		_rect(img, lx, 7, 3, 2, Color("#fde68a"))
		_px(img, lx + 1, 6, Color("#fde68a"))
	# Horizontal binding beams
	_rect(img, 4, 12, 26, 2, Color("#451a03"))
	_rect(img, 4, 19, 26, 2, Color("#451a03"))
	# Central arched timber gate
	_circle(img, 16, 16, 4, Color("#271508"))
	_rect(img, 12, 16, 8, 8, Color("#271508"))
	_line(img, 16, 13, 16, 23, Color("#78350f"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_defense_wall() -> Image:
	var img := _new_canvas(36, 32)
	_ellipse(img, 18, 28, 15, 3, C_SHADOW)
	# Ashlar stone curtain wall
	_rect(img, 4, 11, 28, 17, Color("#64748b"))
	_rect(img, 5, 12, 26, 15, Color("#94a3b8"))
	for y in [15, 19, 23]:
		_line(img, 5, y, 30, y, Color("#475569"))
	# 5 top crenellated merlons
	for mx in [4, 10, 16, 22, 28]:
		_rect(img, mx, 7, 4, 5, Color("#cbd5e1"))
	# Central arched gateway with iron portcullis grid
	_circle(img, 18, 19, 5, Color("#1e293b"))
	_rect(img, 13, 19, 10, 9, Color("#1e293b"))
	for gx in [15, 18, 21]:
		_line(img, gx, 15, gx, 27, Color("#475569"))
	for gy in [18, 22, 25]:
		_line(img, 14, gy, 22, gy, Color("#475569"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_defense_fortress() -> Image:
	var img := _new_canvas(40, 40)
	_ellipse(img, 20, 36, 17, 3, C_SHADOW)
	# Reinforced gatehouse
	_rect(img, 14, 14, 12, 21, Color("#64748b"))
	_rect(img, 15, 15, 10, 19, Color("#94a3b8"))
	# Twin cylindrical corner stone towers
	_rect(img, 4, 10, 10, 25, Color("#94a3b8"))
	_rect(img, 5, 10, 5, 25, Color("#cbd5e1"))
	_rect(img, 26, 10, 10, 25, Color("#94a3b8"))
	_rect(img, 27, 10, 5, 25, Color("#cbd5e1"))
	# Crimson/gold conical roofs on towers
	for cx in [9, 31]:
		for y in range(4, 11):
			var hw := 1 + int(float(y - 4) * 0.75)
			_rect(img, cx - hw, y, hw * 2 + 1, 1, Color("#991b1b") if y % 2 == 0 else Color("#dc2626"))
		_px(img, cx, 3, Color("#fbbf24"))
	# Gatehouse portal & golden shield emblem at (20, 19)
	_circle(img, 20, 26, 4, Color("#1e293b"))
	_rect(img, 16, 26, 8, 9, Color("#1e293b"))
	_circle(img, 20, 19, 3, Color("#fbbf24"))
	_px(img, 20, 19, Color("#fef08a"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_tribute_chest() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 20, 9, 2, C_SHADOW)
	# Overflowing reserve sacks/coins around chest
	_circle(img, 5, 18, 3, Color("#d97706"))
	_circle(img, 19, 18, 2, Color("#f59e0b"))
	# Ornate wooden chest
	_rect(img, 6, 11, 12, 9, Color("#78350f"))
	_rect(img, 7, 12, 10, 7, Color("#92400e"))
	# Overflowing gold/amber coins at top
	_ellipse(img, 12, 11, 5, 2, Color("#fbbf24"))
	_rect(img, 8, 9, 8, 2, Color("#fde047"))
	# Golden bands and lock
	_rect(img, 6, 13, 12, 2, Color("#fbbf24"))
	_rect(img, 8, 11, 2, 9, Color("#fbbf24"))
	_rect(img, 14, 11, 2, 9, Color("#fbbf24"))
	_rect(img, 11, 13, 2, 3, Color("#fef08a"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_siege_engine() -> Image:
	var img := _new_canvas(28, 28)
	_ellipse(img, 14, 24, 11, 3, C_SHADOW)
	# Timber catapult frame
	_rect(img, 5, 18, 18, 4, Color("#78350f"))
	_rect(img, 6, 19, 16, 2, Color("#92400e"))
	_line(img, 9, 19, 14, 10, Color("#78350f"))
	_line(img, 10, 19, 15, 10, Color("#92400e"))
	_line(img, 19, 19, 14, 10, Color("#78350f"))
	# Torsion arm & flaming stone payload
	_line(img, 15, 15, 6, 6, Color("#92400e"))
	_line(img, 16, 15, 7, 6, Color("#b45309"))
	_circle(img, 6, 6, 3, Color("#f97316"))
	_circle(img, 6, 6, 2, Color("#fbbf24"))
	_px(img, 6, 4, Color("#ef4444"))
	# Iron wheels
	_circle(img, 8, 22, 3, Color("#475569"))
	_px(img, 8, 22, Color("#cbd5e1"))
	_circle(img, 20, 22, 3, Color("#475569"))
	_px(img, 20, 22, Color("#cbd5e1"))
	_apply_soft_outline(img)
	return img


static func _draw_act_forage() -> Image:
	var img := _new_canvas(32, 32)
	_rect_outlined(img, 4, 12, 24, 15, Color("#6b4226"), Color("#9c6644"))
	for row_y in [15, 19, 23]:
		_line(img, 6, row_y, 25, row_y, Color("#4a2c18"))
	for cx in [8, 14, 20, 24]:
		_circle(img, cx, 15, 2, Color("#22c55e"))
		_circle(img, cx, 21, 2, Color("#f97316"))
		_px(img, cx, 19, Color("#15803d"))
	_apply_soft_outline(img)
	return img


static func _draw_act_overexploit() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 12, 3, C_SHADOW)
	_ellipse(img, 13, 20, 9, 7, Color("#78716c"))
	_rect(img, 9, 17, 8, 9, Color("#1c1917"))
	_rect(img, 8, 16, 10, 2, Color("#8c5230"))
	_rect(img, 20, 12, 7, 15, Color("#57534e"))
	_rect(img, 22, 22, 3, 4, Color("#f97316"))
	_circle(img, 23, 8, 3, Color("#9ca3af"))
	_circle(img, 25, 5, 2, Color("#d1d5db"))
	_apply_soft_outline(img)
	return img


static func _draw_act_migrate() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 15, 27, 11, 2, C_SHADOW)
	_rect(img, 6, 18, 16, 5, Color("#8c5230"))
	_ellipse(img, 14, 15, 8, 5, Color("#f5ebe0"))
	_line(img, 11, 11, 11, 18, Color("#d6c7b2"))
	_line(img, 17, 11, 17, 18, Color("#d6c7b2"))
	_circle(img, 9, 24, 3, Color("#5c3317"))
	_circle(img, 19, 24, 3, Color("#5c3317"))
	_rect(img, 25, 12, 2, 14, Color("#6b3e26"))
	_rect(img, 23, 14, 7, 3, Color("#deb887"))
	_apply_soft_outline(img)
	return img


static func _draw_act_cooperate() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 9, 2, C_SHADOW)
	_rect(img, 10, 11, 12, 17, Color("#c83e31"))
	_rect(img, 11, 11, 5, 17, Color("#e05346"))
	_line(img, 10, 16, 21, 16, Color("#fbbf24"))
	_line(img, 10, 22, 21, 22, Color("#fbbf24"))
	_ellipse(img, 16, 11, 6, 4, Color("#f59e0b"))
	_ellipse(img, 15, 10, 4, 2, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_act_exchange() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 12, 2, C_SHADOW)
	_rect(img, 6, 20, 20, 7, Color("#9c6644"))
	_rect(img, 7, 12, 2, 9, Color("#6b3e26"))
	_rect(img, 23, 12, 2, 9, Color("#6b3e26"))
	for x in range(5, 27):
		var stripe_col := Color("#10b981") if ((x - 5) / 3) % 2 == 0 else Color("#fefae0")
		_rect(img, x, 9, 1, 5, stripe_col)
	_circle(img, 12, 18, 2, Color("#f59e0b"))
	_circle(img, 17, 18, 2, Color("#ef4444"))
	_circle(img, 21, 18, 2, Color("#3b82f6"))
	_apply_soft_outline(img)
	return img


static func _draw_act_dispute() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 12, 2, C_SHADOW)
	for x in range(5, 26, 4):
		_rect(img, x, 14, 3, 13, Color("#7f4f24"))
		_px(img, x + 1, 12, Color("#b07d4f"))
		_rect(img, x, 13, 3, 1, Color("#b07d4f"))
	_rect(img, 14, 6, 2, 12, Color("#4a2c18"))
	_rect(img, 16, 7, 7, 5, Color("#ef4444"))
	_px(img, 18, 9, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_act_innovate() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 11, 2, C_SHADOW)
	_rect(img, 6, 19, 20, 4, Color("#8c5230"))
	_rect(img, 8, 23, 3, 5, Color("#5c3317"))
	_rect(img, 21, 23, 3, 5, Color("#5c3317"))
	_rect(img, 9, 17, 6, 2, Color("#fefae0"))
	for dy in range(-5, 6):
		var hw: int = 4 - int(abs(dy) * 0.75)
		if hw > 0:
			_rect(img, 19 - hw, 11 + dy, hw * 2, 1, Color("#38bdf8") if dy < 0 else Color("#0284c7"))
	_px(img, 18, 9, Color("#e0f2fe"))
	_apply_soft_outline(img)
	return img


static func _draw_act_custom() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 28, 10, 2, C_SHADOW)
	for y in range(6, 27):
		var hw := 1 + int(float(y - 6) * 0.2)
		_rect(img, 16 - hw, y, hw * 2 + 1, 1, Color("#fbbf24") if y % 2 == 0 else Color("#d97706"))
	_rect(img, 11, 25, 11, 3, Color("#78716c"))
	_px(img, 16, 12, Color("#a855f7"))
	_px(img, 16, 13, Color("#e9d5ff"))
	_apply_soft_outline(img)
	return img


static func _draw_cultural_totem() -> Image:
	var img := _new_canvas(28, 32)
	_ellipse(img, 14, 28, 7, 2, C_SHADOW)
	_rect(img, 11, 8, 6, 20, Color("#7c3aed"))
	_rect(img, 12, 8, 4, 20, Color("#9333ea"))
	_rect(img, 6, 12, 16, 3, Color("#fbbf24"))
	_px(img, 12, 11, Color("#34d399"))
	_px(img, 15, 11, Color("#34d399"))
	_rect(img, 12, 17, 4, 2, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_ruins() -> Image:
	var img := _new_canvas(32, 32)
	_ellipse(img, 16, 27, 12, 3, C_SHADOW)
	_rect(img, 7, 19, 6, 8, Color("#78716c"))
	_rect(img, 14, 22, 5, 5, Color("#57534e"))
	_rect(img, 20, 16, 5, 11, Color("#78716c"))
	_rect(img, 7, 18, 5, 2, Color("#4d7c0f"))
	_rect(img, 20, 15, 4, 3, Color("#65a30d"))
	_rect(img, 14, 21, 4, 2, Color("#4d7c0f"))
	_apply_soft_outline(img)
	return img


static func _draw_caravan_cart() -> Image:
	var img := _new_canvas(28, 24)
	_ellipse(img, 14, 20, 10, 2, C_SHADOW)
	_rect(img, 4, 11, 13, 5, Color("#8c5230"))
	_rect(img, 5, 12, 11, 3, Color("#b07d4f"))
	_rect(img, 5, 7, 5, 4, Color("#d97706"))
	_rect(img, 6, 8, 3, 2, Color("#fde047"))
	_circle(img, 13, 9, 3, Color("#eab308"))
	_circle(img, 7, 17, 3, Color("#4a2c18"))
	_px(img, 7, 17, Color("#d6b88a"))
	_circle(img, 14, 17, 3, Color("#4a2c18"))
	_px(img, 14, 17, Color("#d6b88a"))
	_rect(img, 18, 12, 6, 4, Color("#a16207"))
	_rect(img, 22, 9, 3, 4, Color("#a16207"))
	_line(img, 19, 16, 19, 19, Color("#713f12"))
	_line(img, 23, 16, 23, 19, Color("#713f12"))
	_apply_soft_outline(img)
	return img


static func _draw_settler_wagon() -> Image:
	var img := _new_canvas(32, 28)
	_ellipse(img, 16, 23, 12, 3, C_SHADOW)
	_rect(img, 6, 15, 18, 5, Color("#8c5230"))
	_ellipse(img, 15, 12, 9, 6, Color("#fefae0"))
	_line(img, 11, 7, 11, 15, Color("#d4c5b1"))
	_line(img, 15, 6, 15, 15, Color("#d4c5b1"))
	_line(img, 19, 7, 19, 15, Color("#d4c5b1"))
	_circle(img, 10, 21, 3, Color("#5c3317"))
	_px(img, 10, 21, Color("#eab308"))
	_circle(img, 20, 21, 3, Color("#5c3317"))
	_px(img, 20, 21, Color("#eab308"))
	_apply_soft_outline(img)
	return img


static func _draw_barricade_spikes() -> Image:
	var img := _new_canvas(32, 28)
	_ellipse(img, 16, 23, 13, 3, C_SHADOW)
	_rect(img, 5, 15, 22, 4, Color("#5c3317"))
	_rect(img, 6, 16, 20, 2, Color("#7f4f24"))
	var spike_xs := [7, 12, 17, 22]
	for sx in spike_xs:
		_line(img, sx - 3, 22, sx + 3, 7, Color("#6b3e26"))
		_line(img, sx - 2, 22, sx + 4, 7, Color("#9c6644"))
		_px(img, sx + 3, 6, Color("#fde047"))
		_line(img, sx + 3, 22, sx - 3, 8, Color("#5c3317"))
		_line(img, sx + 2, 22, sx - 2, 8, Color("#8c5230"))
	_circle(img, 16, 16, 4, Color("#dc2626"))
	_circle(img, 16, 16, 2, Color("#fbbf24"))
	_apply_soft_outline(img)
	return img


static func _draw_road_block_sign() -> Image:
	var img := _new_canvas(28, 26)
	_ellipse(img, 14, 22, 10, 2, C_SHADOW)
	_ellipse(img, 10, 20, 4, 2, Color("#4d7c0f"))
	_ellipse(img, 18, 20, 4, 2, Color("#65a30d"))
	_rect(img, 7, 10, 3, 12, Color("#5c3317"))
	_rect(img, 18, 10, 3, 12, Color("#5c3317"))
	_line(img, 5, 9, 23, 19, Color("#b45309"))
	_line(img, 5, 10, 23, 20, Color("#d97706"))
	_line(img, 5, 11, 23, 21, Color("#f59e0b"))
	_line(img, 23, 9, 5, 19, Color("#b45309"))
	_line(img, 23, 10, 5, 20, Color("#d97706"))
	_line(img, 23, 11, 5, 21, Color("#f59e0b"))
	_rect(img, 5, 8, 18, 3, Color("#d97706"))
	for sx in range(6, 22, 4):
		_rect(img, sx, 8, 2, 3, Color("#ef4444"))
	_apply_soft_outline(img)
	return img


static func _draw_road_lantern() -> Image:
	var img := _new_canvas(20, 28)
	_ellipse(img, 10, 24, 5, 2, C_SHADOW)
	_rect(img, 8, 7, 3, 17, Color("#5c3317"))
	_rect(img, 9, 7, 1, 17, Color("#8c5230"))
	_rect(img, 8, 7, 7, 2, Color("#5c3317"))
	_rect(img, 12, 9, 4, 5, Color("#fbbf24"))
	_rect(img, 13, 10, 2, 3, Color("#fef08a"))
	_rect(img, 11, 8, 6, 1, Color("#374151"))
	_rect(img, 12, 14, 4, 1, Color("#374151"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_war_banner() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 21, 7, 2, C_SHADOW)
	# Crossed war spears behind standard
	_line(img, 4, 20, 19, 5, Color("#5c3317"))
	_line(img, 5, 20, 19, 6, Color("#8c5230"))
	_line(img, 20, 20, 5, 5, Color("#5c3317"))
	_line(img, 19, 20, 5, 6, Color("#8c5230"))
	# Steel spearheads
	_rect(img, 18, 3, 3, 3, Color("#cbd5e1"))
	_px(img, 20, 2, Color("#f8fafc"))
	_rect(img, 3, 3, 3, 3, Color("#cbd5e1"))
	_px(img, 3, 2, Color("#f8fafc"))
	# Central iron pole & crossbar
	_rect(img, 11, 3, 2, 18, Color("#475569"))
	_line(img, 11, 3, 11, 20, Color("#94a3b8"))
	_rect(img, 6, 6, 12, 2, Color("#d97706"))
	_line(img, 7, 6, 16, 6, Color("#fde047"))
	_circle(img, 12, 3, 2, Color("#fbbf24"))
	# Tattered crimson battle pennant
	_rect(img, 8, 8, 8, 8, Color("#dc2626"))
	_rect(img, 9, 8, 6, 7, Color("#ef4444"))
	_rect(img, 8, 16, 2, 3, Color("#991b1b"))
	_rect(img, 11, 16, 2, 2, Color("#991b1b"))
	_rect(img, 14, 16, 2, 3, Color("#991b1b"))
	# Golden war emblem on banner
	_circle(img, 12, 11, 2, Color("#fde047"))
	_px(img, 12, 11, Color("#991b1b"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_raid_loot() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 21, 8, 2, C_SHADOW)
	# Spilled golden grain / amber reserves
	_circle(img, 5, 19, 2, Color("#f59e0b"))
	_px(img, 5, 18, Color("#fde047"))
	_circle(img, 18, 20, 2, Color("#fbbf24"))
	_px(img, 15, 21, Color("#fde047"))
	_px(img, 7, 21, Color("#fde047"))
	# Raider plunder sack
	_ellipse(img, 11, 15, 6, 5, Color("#7f4f24"))
	_ellipse(img, 10, 15, 5, 4, Color("#b07d4f"))
	_rect(img, 8, 9, 6, 2, Color("#d97706"))
	_line(img, 8, 10, 13, 10, Color("#fde047"))
	# Overflowing golden grain at sack mouth
	_ellipse(img, 11, 8, 4, 2, Color("#f59e0b"))
	_rect(img, 9, 7, 4, 2, Color("#fde047"))
	# Burning torch leaning on sack
	_line(img, 15, 20, 19, 10, Color("#5c3317"))
	_line(img, 16, 20, 20, 10, Color("#8c5230"))
	_ellipse(img, 19, 8, 3, 3, Color("#ef4444"))
	_circle(img, 19, 8, 2, Color("#f97316"))
	_px(img, 19, 7, Color("#fde047"))
	_px(img, 20, 5, Color("#fb923c"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_pact_totem() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 21, 8, 2, C_SHADOW)
	# Stepped stone pedestal
	_rect(img, 6, 18, 12, 3, Color("#78716c"))
	_rect(img, 7, 17, 10, 2, Color("#a8a29e"))
	# Twin emerald/gold banners flanking obelisk
	_rect(img, 4, 7, 16, 2, Color("#d97706"))
	_rect(img, 5, 9, 3, 7, Color("#059669"))
	_line(img, 6, 9, 6, 15, Color("#34d399"))
	_rect(img, 16, 9, 3, 7, Color("#059669"))
	_line(img, 17, 9, 17, 15, Color("#34d399"))
	# Carved stone & gold alliance obelisk
	_rect(img, 9, 6, 6, 12, Color("#d6d3d1"))
	_rect(img, 10, 6, 4, 12, Color("#e7e5e4"))
	for y in range(2, 6):
		var hw := y - 2
		_rect(img, 12 - hw, y, hw * 2 + 1, 1, Color("#fbbf24") if y < 5 else Color("#d97706"))
	# Emerald/cyan harmony bands & golden seal
	_rect(img, 9, 8, 6, 2, Color("#10b981"))
	_line(img, 10, 8, 13, 8, Color("#6ee7b7"))
	_rect(img, 9, 13, 6, 2, Color("#0d9488"))
	_line(img, 10, 13, 13, 13, Color("#2dd4bf"))
	_circle(img, 12, 11, 2, Color("#fbbf24"))
	_px(img, 12, 11, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_prop_betrayal_ruin() -> Image:
	var img := _new_canvas(24, 24)
	_ellipse(img, 12, 21, 8, 2, C_SHADOW)
	# Dark purple/charcoal smoke wisps
	_circle(img, 6, 10, 2, Color("#3b0764"))
	_circle(img, 7, 6, 2, Color("#4c1d95"))
	_circle(img, 18, 9, 2, Color("#374151"))
	_px(img, 5, 4, Color("#6b21a8"))
	# Shattered alliance pillar base
	_rect(img, 6, 18, 12, 3, Color("#44403c"))
	_rect(img, 8, 12, 8, 7, Color("#78716c"))
	_rect(img, 9, 13, 6, 5, Color("#57534e"))
	# Broken emerald band & rubble
	_rect(img, 8, 15, 3, 2, Color("#047857"))
	_rect(img, 17, 18, 3, 3, Color("#78716c"))
	# Jagged crimson fracture & piercing dagger
	_line(img, 9, 12, 14, 18, Color("#be123c"))
	_line(img, 10, 12, 13, 17, Color("#f43f5e"))
	_line(img, 17, 4, 11, 14, Color("#e2e8f0"))
	_line(img, 18, 5, 12, 14, Color("#ef4444"))
	_line(img, 15, 4, 19, 8, Color("#fbbf24"))
	_circle(img, 18, 4, 2, Color("#be123c"))
	_apply_soft_outline(img)
	return img


static func _draw_effect_battle_sparks() -> Image:
	var img := _new_canvas(24, 24)
	_line(img, 4, 12, 20, 12, Color("#ef4444"))
	_line(img, 12, 4, 12, 20, Color("#ef4444"))
	_line(img, 6, 6, 18, 18, Color("#f97316"))
	_line(img, 18, 6, 6, 18, Color("#f97316"))
	_circle(img, 12, 12, 4, Color("#fbbf24"))
	_circle(img, 12, 12, 2, Color("#fef08a"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_war() -> Image:
	var img := _new_canvas(16, 16)
	# Crossed war spears in steel
	_line(img, 2, 13, 13, 2, Color("#94a3b8"))
	_line(img, 3, 13, 13, 3, Color("#f8fafc"))
	_line(img, 13, 13, 2, 2, Color("#94a3b8"))
	_line(img, 12, 13, 2, 3, Color("#f8fafc"))
	# Vivid crimson & steel battle shield
	_rect(img, 5, 4, 6, 7, Color("#991b1b"))
	_rect(img, 6, 5, 4, 5, Color("#ef4444"))
	_rect(img, 6, 11, 4, 2, Color("#dc2626"))
	_line(img, 5, 4, 10, 4, Color("#cbd5e1"))
	_px(img, 8, 8, Color("#fde047"))
	_px(img, 7, 8, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_raid() -> Image:
	var img := _new_canvas(16, 16)
	# Plunder loot sack
	_ellipse(img, 7, 10, 4, 4, Color("#92400e"))
	_ellipse(img, 7, 10, 3, 3, Color("#d97706"))
	_rect(img, 5, 6, 4, 2, Color("#b45309"))
	_line(img, 5, 7, 8, 7, Color("#fde047"))
	# Amber coins / grain & flame spark
	_rect(img, 6, 4, 3, 2, Color("#fbbf24"))
	_px(img, 7, 9, Color("#fde047"))
	_px(img, 3, 13, Color("#fbbf24"))
	_px(img, 11, 13, Color("#fde047"))
	_circle(img, 12, 6, 2, Color("#ef4444"))
	_px(img, 12, 6, Color("#fde047"))
	_px(img, 12, 4, Color("#f97316"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_pact() -> Image:
	var img := _new_canvas(16, 16)
	# Golden/emerald alliance seal
	_circle(img, 8, 8, 6, Color("#d97706"))
	_circle(img, 8, 8, 5, Color("#fbbf24"))
	_circle(img, 8, 8, 4, Color("#059669"))
	_circle(img, 8, 8, 3, Color("#10b981"))
	# Clasped emblem across center
	_rect(img, 4, 7, 8, 2, Color("#fde047"))
	_rect(img, 6, 6, 4, 4, Color("#fef08a"))
	_rect(img, 7, 7, 2, 2, Color("#10b981"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_betrayal() -> Image:
	var img := _new_canvas(16, 16)
	# Broken golden ring/seal halves
	_circle(img, 5, 9, 3, Color("#d97706"))
	_px(img, 4, 9, Color("#fde047"))
	_circle(img, 11, 9, 3, Color("#d97706"))
	_px(img, 12, 9, Color("#fde047"))
	_rect(img, 7, 6, 2, 7, Color(0, 0, 0, 0))
	# Jagged crimson dagger breaking the seal
	_line(img, 12, 2, 5, 13, Color("#be123c"))
	_line(img, 11, 2, 4, 13, Color("#f8fafc"))
	_line(img, 11, 3, 6, 11, Color("#ef4444"))
	_line(img, 9, 2, 13, 6, Color("#fbbf24"))
	_px(img, 13, 2, Color("#f43f5e"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_defense() -> Image:
	var img := _new_canvas(16, 16)
	# Crenellated silver/gold fortress shield
	_rect(img, 3, 4, 10, 7, Color("#64748b"))
	_rect(img, 4, 5, 8, 6, Color("#cbd5e1"))
	_rect(img, 5, 11, 6, 2, Color("#94a3b8"))
	_rect(img, 7, 13, 2, 1, Color("#64748b"))
	# Top merlons
	for mx in [3, 7, 11]:
		_rect(img, mx, 2, 2, 2, Color("#e2e8f0"))
	# Gold trim & central emblem
	_rect(img, 6, 6, 4, 4, Color("#fbbf24"))
	_rect(img, 7, 7, 2, 2, Color("#fef08a"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_merge() -> Image:
	var img := _new_canvas(16, 16)
	# Twin banners/pillars uniting under a golden crown arch
	_rect(img, 3, 7, 3, 6, Color("#10b981"))
	_rect(img, 10, 7, 3, 6, Color("#38bdf8"))
	_rect(img, 2, 4, 12, 3, Color("#fbbf24"))
	_rect(img, 6, 3, 4, 4, Color("#fde047"))
	_line(img, 4, 12, 8, 8, Color("#fbbf24"))
	_line(img, 11, 12, 8, 8, Color("#fbbf24"))
	_circle(img, 8, 8, 2, Color("#fef08a"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_tribute() -> Image:
	var img := _new_canvas(16, 16)
	# Golden chest with an offering arrow
	_rect(img, 3, 8, 9, 6, Color("#92400e"))
	_rect(img, 4, 6, 7, 2, Color("#fbbf24"))
	_rect(img, 3, 10, 9, 1, Color("#fbbf24"))
	_rect(img, 7, 9, 2, 3, Color("#fef08a"))
	# Offering arrow pointing up-right
	_line(img, 9, 6, 13, 2, Color("#fde047"))
	_line(img, 10, 6, 13, 3, Color("#f59e0b"))
	_rect(img, 11, 2, 3, 2, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func _draw_icon_siege() -> Image:
	var img := _new_canvas(16, 16)
	# Crenellated tower with orange/red siege flames
	_rect(img, 5, 5, 6, 9, Color("#64748b"))
	_rect(img, 6, 6, 4, 7, Color("#94a3b8"))
	for mx in [4, 7, 10]:
		_rect(img, mx, 3, 2, 2, Color("#cbd5e1"))
	# Siege flames around tower
	_circle(img, 4, 11, 2, Color("#ef4444"))
	_px(img, 4, 11, Color("#fbbf24"))
	_circle(img, 12, 10, 2, Color("#f97316"))
	_px(img, 12, 10, Color("#fde047"))
	_circle(img, 8, 12, 2, Color("#ef4444"))
	_px(img, 8, 12, Color("#fde047"))
	_apply_soft_outline(img)
	return img


static func draw_villager(step: int, tunic_color: Color) -> Image:
	var img := _new_canvas(16, 16)
	_ellipse(img, 8, 14, 4, 1, C_SHADOW)
	var bob := -1 if step != 0 else 0
	_rect(img, 6, 2 + bob, 4, 2, Color("#5c3317"))
	_rect(img, 6, 4 + bob, 4, 3, Color("#fcd5b5"))
	_px(img, 7, 5 + bob, C_OUTLINE)
	_px(img, 9, 5 + bob, C_OUTLINE)
	_rect(img, 5, 7 + bob, 6, 4, tunic_color)
	_rect(img, 6, 7 + bob, 4, 3, tunic_color.lightened(0.18))
	var left_y := 11
	var right_y := 11
	if step == 1:
		left_y = 10
		right_y = 12
	elif step == 2:
		left_y = 12
		right_y = 10
	_rect(img, 6, left_y, 2, 3, Color("#3b4252"))
	_rect(img, 8, right_y, 2, 3, Color("#3b4252"))
	_apply_soft_outline(img)
	return img


static func _draw_ui_icon(icon_name: String) -> Image:
	if icon_name == "thought_bubble":
		return _draw_thought_bubble()

	var img := _new_canvas(24, 24)
	match icon_name:
		"tool_inspect":
			_circle(img, 10, 10, 6, Color("#38bdf8"))
			_circle(img, 10, 10, 4, Color("#bae6fd"))
			_line(img, 14, 14, 20, 20, Color("#8c5230"))
			_line(img, 15, 14, 20, 19, Color("#d97706"))
		"tool_biome":
			_ellipse(img, 12, 15, 5, 5, Color("#d4a373"))
			_line(img, 12, 10, 12, 5, Color("#22c55e"))
			_ellipse(img, 9, 7, 3, 2, Color("#4ade80"))
			_ellipse(img, 15, 7, 3, 2, Color("#22c55e"))
		"tool_altitude":
			_line(img, 5, 19, 18, 6, Color("#8c5230"))
			_line(img, 6, 19, 18, 7, Color("#b07d4f"))
			_line(img, 13, 4, 20, 11, Color("#94a3b8"))
			_line(img, 14, 4, 20, 10, Color("#e2e8f0"))
		"tool_fertility":
			_rect(img, 7, 11, 9, 8, Color("#fbbf24"))
			_rect(img, 8, 12, 7, 6, Color("#fde047"))
			_line(img, 16, 15, 21, 10, Color("#f59e0b"))
			_circle(img, 5, 14, 2, Color("#d97706"))
		"tool_sealevel":
			_ellipse(img, 12, 13, 7, 5, Color("#38bdf8"))
			_ellipse(img, 12, 11, 5, 3, Color("#7dd3fc"))
			_line(img, 4, 18, 20, 18, Color("#0284c7"))
		"season_wet":
			_circle(img, 12, 12, 5, Color("#fbbf24"))
			_circle(img, 12, 12, 3, Color("#fde047"))
			_ellipse(img, 16, 16, 4, 2, Color("#22c55e"))
		"season_dry":
			_line(img, 12, 4, 12, 20, Color("#7dd3fc"))
			_line(img, 4, 12, 20, 12, Color("#7dd3fc"))
			_line(img, 6, 6, 18, 18, Color("#bae6fd"))
			_line(img, 18, 6, 6, 18, Color("#bae6fd"))
		"status_thriving":
			_draw_heart(img, Color("#10b981"), Color("#6ee7b7"))
		"status_stable":
			_draw_heart(img, Color("#0ea5e9"), Color("#7dd3fc"))
		"status_struggling":
			_draw_heart(img, Color("#f59e0b"), Color("#fde047"))
		"status_starving":
			_draw_heart(img, Color("#ef4444"), Color("#fca5a5"))
		"icon_forage":
			_circle(img, 12, 13, 6, Color("#22c55e"))
			_circle(img, 10, 11, 2, Color("#ef4444"))
			_circle(img, 15, 14, 2, Color("#fbbf24"))
		"icon_overexploit":
			_ellipse(img, 12, 15, 6, 5, Color("#f97316"))
			_rect(img, 10, 6, 4, 6, Color("#78716c"))
		"icon_migrate":
			_rect(img, 6, 11, 12, 6, Color("#38bdf8"))
			_circle(img, 9, 18, 2, Color("#8c5230"))
			_circle(img, 15, 18, 2, Color("#8c5230"))
		"icon_cooperate":
			_rect(img, 8, 9, 8, 11, Color("#ef4444"))
			_ellipse(img, 12, 9, 4, 3, Color("#fbbf24"))
		"icon_exchange":
			_rect(img, 5, 7, 14, 4, Color("#10b981"))
			_rect(img, 6, 11, 12, 8, Color("#d4a373"))
		"icon_dispute":
			_line(img, 6, 18, 18, 6, Color("#ef4444"))
			_line(img, 6, 6, 18, 18, Color("#fca5a5"))
		"icon_innovate":
			_circle(img, 12, 12, 5, Color("#a855f7"))
			_circle(img, 12, 12, 3, Color("#e9d5ff"))
		"icon_coop_link":
			_circle(img, 12, 12, 9, Color("#059669"))
			_circle(img, 12, 12, 7, Color("#10b981"))
			_rect(img, 7, 10, 10, 6, Color("#d97706"))
			_rect(img, 7, 8, 10, 3, Color("#fbbf24"))
			_rect(img, 11, 10, 2, 3, Color("#fef08a"))
		"icon_conflict_swords":
			_circle(img, 12, 12, 9, Color("#991b1b"))
			_circle(img, 12, 12, 7, Color("#ef4444"))
			_line(img, 6, 18, 18, 6, Color("#f8fafc"))
			_line(img, 7, 18, 18, 7, Color("#cbd5e1"))
			_line(img, 6, 6, 18, 18, Color("#f8fafc"))
			_line(img, 7, 6, 18, 17, Color("#cbd5e1"))
			_circle(img, 12, 12, 2, Color("#fde047"))
		"icon_broken_link":
			_circle(img, 12, 12, 9, Color("#78350f"))
			_circle(img, 12, 12, 7, Color("#d97706"))
			_rect(img, 5, 10, 5, 4, Color("#e2e8f0"))
			_rect(img, 14, 10, 5, 4, Color("#e2e8f0"))
			_line(img, 10, 7, 14, 17, Color("#ef4444"))
			_line(img, 14, 7, 10, 17, Color("#ef4444"))
		_:
			_circle(img, 12, 12, 6, Color("#eab308"))
	_apply_soft_outline(img)
	return img


static func _draw_thought_bubble() -> Image:
	var img := _new_canvas(28, 28)
	_ellipse(img, 14, 12, 10, 8, Color("#fffbeb"))
	_circle(img, 8, 12, 5, Color("#fffbeb"))
	_circle(img, 20, 12, 5, Color("#fffbeb"))
	_circle(img, 14, 7, 5, Color("#fffbeb"))
	_circle(img, 9, 22, 2, Color("#fffbeb"))
	_circle(img, 6, 25, 1, Color("#fffbeb"))
	_apply_soft_outline(img, Color("#4a2c18"))
	return img


static func _draw_heart(img: Image, main_col: Color, hi_col: Color) -> void:
	_circle(img, 9, 10, 4, main_col)
	_circle(img, 15, 10, 4, main_col)
	for y in range(11, 19):
		var hw := 19 - y
		_rect(img, 12 - hw, y, hw * 2 + 1, 1, main_col)
	_px(img, 8, 8, hi_col)
	_px(img, 9, 8, hi_col)
