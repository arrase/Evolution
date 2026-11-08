class_name EvoUiIconSprites
extends EvoPixelCanvas


static func draw_ui_icon_sprite(sprite_name: String) -> Image:
	match sprite_name:
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
		_:
			return _draw_ui_icon(sprite_name)


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
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#16a34a"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 15.0, Color("#22c55e"))
			_aa_line(img, 24.0, 44.0, 38.0, 20.0, Color("#fef08a"), 3.6)
			_aa_ellipse_outlined(img, 27.0, 30.0, 6.0, 4.0, Color("#fde047"), C_OUTLINE, 1.6)
			_aa_ellipse_outlined(img, 37.0, 34.0, 6.0, 4.0, Color("#fde047"), C_OUTLINE, 1.6)
			_aa_ellipse_outlined(img, 35.0, 23.0, 6.0, 4.0, Color("#fef08a"), C_OUTLINE, 1.6)
		"icon_overexploit":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#ea580c"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 15.0, Color("#f97316"))
			_aa_line(img, 22.0, 42.0, 40.0, 22.0, Color("#78350f"), 4.2)
			var pick_head := PackedVector2Array([
				Vector2(24, 20), Vector2(38, 18), Vector2(46, 30), Vector2(36, 26)
			])
			_poly_outlined(img, pick_head, Color("#f8fafc"), Color("#cbd5e1"), C_OUTLINE, 1.8)
		"icon_migrate":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#0284c7"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 15.0, Color("#38bdf8"))
			_aa_line(img, 18.0, 32.0, 38.0, 32.0, Color("#f8fafc"), 4.5)
			var arrow_head := PackedVector2Array([
				Vector2(34, 21), Vector2(47, 32), Vector2(34, 43)
			])
			_poly_outlined(img, arrow_head, Color("#ffffff"), Color("#e0f2fe"), C_OUTLINE, 2.0)
		"icon_cooperate":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#059669"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 15.0, Color("#10b981"))
			_aa_ellipse_outlined(img, 26.0, 33.0, 9.0, 6.0, Color("#fde047"), C_OUTLINE, 2.0)
			_aa_ellipse_outlined(img, 38.0, 33.0, 9.0, 6.0, Color("#fef3c7"), C_OUTLINE, 2.0)
			_aa_circle(img, 32.0, 33.0, 4.5, Color("#fbbf24"))
		"icon_exchange":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#0d9488"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 15.0, Color("#14b8a6"))
			_aa_line(img, 20.0, 25.0, 42.0, 25.0, Color("#fef08a"), 3.6)
			_aa_line(img, 44.0, 39.0, 22.0, 39.0, Color("#fef08a"), 3.6)
			_aa_circle_outlined(img, 32.0, 32.0, 6.5, Color("#fbbf24"), C_OUTLINE, 1.8)
		"icon_dispute":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#be123c"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 15.0, Color("#e11d48"))
			_aa_line(img, 20.0, 42.0, 44.0, 20.0, Color("#f8fafc"), 4.0)
			_aa_line(img, 44.0, 42.0, 20.0, 20.0, Color("#f8fafc"), 4.0)
			_aa_circle(img, 32.0, 31.0, 4.5, Color("#fde047"))
		"icon_innovate":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#7e22ce"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 15.0, Color("#a855f7"))
			var star_v := PackedVector2Array([
				Vector2(32, 16), Vector2(36, 28), Vector2(48, 32),
				Vector2(36, 36), Vector2(32, 48), Vector2(28, 36),
				Vector2(16, 32), Vector2(28, 28)
			])
			_poly_outlined(img, star_v, Color("#fef08a"), Color("#fbbf24"), C_OUTLINE, 1.8)
		"icon_coop_link":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#10b981"), C_OUTLINE, 2.5)
			_aa_circle_outlined(img, 26.0, 32.0, 7.5, Color("#fef3c7"), C_OUTLINE, 2.0)
			_aa_circle_outlined(img, 38.0, 32.0, 7.5, Color("#fde047"), C_OUTLINE, 2.0)
		"icon_conflict_swords":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#ef4444"), C_OUTLINE, 2.5)
			_aa_line(img, 20.0, 42.0, 44.0, 20.0, Color("#f8fafc"), 4.2)
			_aa_line(img, 44.0, 42.0, 20.0, 20.0, Color("#f8fafc"), 4.2)
		"icon_broken_link":
			_aa_circle_outlined(img, 32.0, 32.0, 20.0, Color("#d97706"), C_OUTLINE, 2.5)
			_aa_line(img, 20.0, 24.0, 44.0, 40.0, Color("#fef3c7"), 4.0)
			_aa_line(img, 34.0, 18.0, 30.0, 46.0, Color("#ef4444"), 3.6)
		"icon_epidemic":
			_aa_circle_outlined(img, 32.0, 32.0, 21.0, Color("#65a30d"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 16.0, Color("#84cc16"))
			_aa_circle_outlined(img, 32.0, 24.0, 6.5, Color("#ecfccb"), C_OUTLINE, 2.0)
			_aa_circle_outlined(img, 25.0, 37.0, 6.5, Color("#ecfccb"), C_OUTLINE, 2.0)
			_aa_circle_outlined(img, 39.0, 37.0, 6.5, Color("#ecfccb"), C_OUTLINE, 2.0)
			_aa_circle(img, 32.0, 32.0, 4.0, C_OUTLINE)
		"icon_famine":
			_aa_circle_outlined(img, 32.0, 32.0, 21.0, Color("#b45309"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 16.0, Color("#d97706"))
			var bowl := PackedVector2Array([
				Vector2(18, 32), Vector2(46, 32), Vector2(40, 44), Vector2(24, 44)
			])
			_poly_outlined(img, bowl, Color("#fef3c7"), Color("#fde68a"), C_OUTLINE, 2.0)
			_aa_line(img, 24.0, 22.0, 40.0, 28.0, Color("#ef4444"), 3.4)
		"icon_immune":
			var shield := PackedVector2Array([
				Vector2(16, 14), Vector2(48, 14), Vector2(46, 38), Vector2(32, 52), Vector2(18, 38)
			])
			_poly_outlined(img, shield, Color("#22d3ee"), Color("#06b6d4"), C_OUTLINE, 2.5)
			_aa_line(img, 32.0, 22.0, 32.0, 40.0, Color("#ffffff"), 5.0)
			_aa_line(img, 23.0, 31.0, 41.0, 31.0, Color("#ffffff"), 5.0)
		"icon_vendetta":
			_aa_circle_outlined(img, 32.0, 32.0, 21.0, Color("#991b1b"), C_OUTLINE, 2.5)
			var drop := PackedVector2Array([
				Vector2(32, 14), Vector2(44, 34), Vector2(38, 48), Vector2(26, 48), Vector2(20, 34)
			])
			_poly_outlined(img, drop, Color("#ef4444"), Color("#dc2626"), C_OUTLINE, 2.2)
			_aa_line(img, 22.0, 18.0, 42.0, 46.0, Color("#e2e8f0"), 3.6)
		"icon_casualties":
			_aa_circle_outlined(img, 32.0, 32.0, 21.0, Color("#dc2626"), C_OUTLINE, 2.5)
			_aa_circle_outlined(img, 32.0, 28.0, 10.0, Color("#f8fafc"), C_OUTLINE, 2.0)
			_rect_outlined(img, 26, 34, 12, 9, Color("#f8fafc"), C_OUTLINE)
			_aa_circle(img, 28.5, 28.0, 2.5, C_OUTLINE)
			_aa_circle(img, 35.5, 28.0, 2.5, C_OUTLINE)
		"icon_loot":
			_aa_circle_outlined(img, 32.0, 32.0, 21.0, Color("#ca8a04"), C_OUTLINE, 2.5)
			_aa_circle_outlined(img, 32.0, 32.0, 15.0, Color("#eab308"), C_OUTLINE, 2.0)
			_aa_circle(img, 32.0, 32.0, 9.0, Color("#fef08a"))
		"icon_migrants":
			_aa_circle_outlined(img, 32.0, 32.0, 21.0, Color("#1d4ed8"), C_OUTLINE, 2.5)
			_aa_circle(img, 32.0, 32.0, 16.0, Color("#3b82f6"))
			_aa_ellipse_outlined(img, 25.0, 34.0, 7.0, 6.0, Color("#fef3c7"), C_OUTLINE, 1.8)
			var m_arrow := PackedVector2Array([
				Vector2(33, 22), Vector2(46, 32), Vector2(33, 42)
			])
			_poly_outlined(img, m_arrow, Color("#ffffff"), Color("#bae6fd"), C_OUTLINE, 2.0)
		_:
			_aa_circle_outlined(img, 32.0, 32.0, 16.0, Color("#eab308"), C_OUTLINE, 2.4)
	return img


static func _draw_heart(img: Image, main_col: Color, hi_col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(32, 52), Vector2(14, 32), Vector2(18, 18),
		Vector2(32, 24), Vector2(46, 18), Vector2(50, 32)
	])
	_poly_outlined(img, pts, hi_col, main_col, C_OUTLINE, 2.4)
