class_name EvoHudStatsStrip
extends RefCounted

const METRIC_IDS: Array[String] = [
	"population",
	"food_ratio",
	"salubrity_avg",
	"rural_hexes"
]


class StatsHistoryChart extends Control:
	var history: Array[Dictionary] = []
	var metric: String = "population"
	var color_a: Color = Color("#10b981")
	var color_b: Color = Color("#ef4444")
	var name_a: String = "A"
	var name_b: String = "B"
	var lang: String = "es"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 20.0 or r.size.y < 20.0:
			return
		draw_rect(r, Color("#fbf2de"), true)
		draw_rect(r, EvoUiStyle.COLOR_PARCHMENT_BORDER, false, 1.0)

		var pad_l := 38.0
		var pad_r := 12.0
		var pad_t := 18.0
		var pad_b := 18.0
		var plot_w := maxf(10.0, r.size.x - pad_l - pad_r)
		var plot_h := maxf(10.0, r.size.y - pad_t - pad_b)
		var plot_rect := Rect2(pad_l, pad_t, plot_w, plot_h)

		var font := ThemeDB.fallback_font
		var max_val := _default_ceiling(metric)
		for snap in history:
			var sa: Dictionary = snap["a"]
			var sb: Dictionary = snap["b"]
			max_val = maxf(max_val, maxf(float(sa[metric]), float(sb[metric])))

		for i in range(3):
			var frac := float(i) / 2.0
			var gy := plot_rect.position.y + plot_rect.size.y * (1.0 - frac)
			draw_line(
				Vector2(plot_rect.position.x, gy),
				Vector2(plot_rect.end.x, gy),
				Color(0.45, 0.30, 0.18, 0.22),
				1.0
			)
			var axis_lbl := _format_metric_value(metric, max_val * frac)
			draw_string(
				font,
				Vector2(4.0, gy + 4.0),
				axis_lbl,
				HORIZONTAL_ALIGNMENT_LEFT,
				pad_l - 6.0,
				9,
				EvoUiStyle.COLOR_SEPIA
			)

		if history.is_empty():
			return

		var count := history.size()
		var pts_a := PackedVector2Array()
		var pts_b := PackedVector2Array()
		for i in range(count):
			var x_frac := float(i) / float(maxi(1, count - 1)) if count > 1 else 0.5
			var px := plot_rect.position.x + plot_rect.size.x * x_frac
			var snap: Dictionary = history[i]
			var val_a := float((snap["a"] as Dictionary)[metric])
			var val_b := float((snap["b"] as Dictionary)[metric])
			var py_a := plot_rect.position.y + plot_rect.size.y * (1.0 - clampf(val_a / max_val, 0.0, 1.0))
			var py_b := plot_rect.position.y + plot_rect.size.y * (1.0 - clampf(val_b / max_val, 0.0, 1.0))
			pts_a.append(Vector2(px, py_a))
			pts_b.append(Vector2(px, py_b))

		if count >= 2:
			draw_polyline(pts_a, color_a, 2.4, true)
			draw_polyline(pts_b, color_b, 2.4, true)
		draw_circle(pts_a[count - 1], 3.5, color_a)
		draw_circle(pts_b[count - 1], 3.5, color_b)

		var last_snap: Dictionary = history[count - 1]
		var last_a := _format_metric_value(metric, float((last_snap["a"] as Dictionary)[metric]))
		var last_b := _format_metric_value(metric, float((last_snap["b"] as Dictionary)[metric]))
		var header_a := "■ %s: %s" % [name_a, last_a]
		var header_b := "■ %s: %s" % [name_b, last_b]
		draw_string(font, Vector2(pad_l, 12.0), header_a, HORIZONTAL_ALIGNMENT_LEFT, plot_w * 0.48, 10, color_a.darkened(0.15))
		draw_string(font, Vector2(pad_l + plot_w * 0.50, 12.0), header_b, HORIZONTAL_ALIGNMENT_RIGHT, plot_w * 0.50, 10, color_b.darkened(0.15))

		var gen_first := int(history[0]["generation"])
		var gen_last := int(last_snap["generation"])
		draw_string(font, Vector2(pad_l, r.size.y - 4.0), "G%d" % gen_first, HORIZONTAL_ALIGNMENT_LEFT, 48.0, 9, EvoUiStyle.COLOR_SEPIA)
		draw_string(font, Vector2(plot_rect.end.x - 48.0, r.size.y - 4.0), "G%d" % gen_last, HORIZONTAL_ALIGNMENT_RIGHT, 48.0, 9, EvoUiStyle.COLOR_SEPIA)

	static func _default_ceiling(m: String) -> float:
		match m:
			"food_ratio":
				return 1.2
			"salubrity_avg":
				return 1.0
			"rural_hexes":
				return 4.0
		return 100.0

	static func _format_metric_value(m: String, val: float) -> String:
		match m:
			"food_ratio", "salubrity_avg":
				return "%d%%" % int(round(val * 100.0))
			"rural_hexes", "population":
				return "%d" % int(round(val))
		return "%.1f" % val


static func build_stats_strip(hud: Control) -> void:
	hud._stats_strip_panel = PanelContainer.new()
	hud._stats_strip_panel.anchor_left = 0.5
	hud._stats_strip_panel.anchor_right = 0.5
	hud._stats_strip_panel.anchor_top = 0.0
	hud._stats_strip_panel.anchor_bottom = 0.0
	hud._stats_strip_panel.offset_left = -250
	hud._stats_strip_panel.offset_right = 250
	hud._stats_strip_panel.offset_top = 8
	hud._stats_strip_panel.offset_bottom = 38
	hud._stats_strip_panel.z_index = 20
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = Color(EvoUiStyle.COLOR_PARCHMENT, 0.90)
	pill_box.border_color = EvoUiStyle.COLOR_GOLD_BEVEL
	pill_box.set_border_width_all(2)
	pill_box.set_corner_radius_all(14)
	pill_box.shadow_color = Color(0.08, 0.04, 0.01, 0.28)
	pill_box.shadow_size = 3
	pill_box.shadow_offset = Vector2(0, 1)
	pill_box.content_margin_left = 10
	pill_box.content_margin_right = 10
	pill_box.content_margin_top = 3
	pill_box.content_margin_bottom = 3
	hud._stats_strip_panel.add_theme_stylebox_override("panel", pill_box)
	hud.add_child(hud._stats_strip_panel)

	var main_hbox := HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 6)
	hud._stats_strip_panel.add_child(main_hbox)

	# Left: Strategy A
	var a_hbox := HBoxContainer.new()
	a_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_hbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(a_hbox)

	var a_swatch := ColorRect.new()
	a_swatch.custom_minimum_size = Vector2(10, 10)
	a_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a_swatch.color = Color("#10b981")
	a_hbox.add_child(a_swatch)

	var a_title_lbl := Label.new()
	a_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a_title_lbl.clip_text = true
	a_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	a_title_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	a_title_lbl.add_theme_font_size_override("font_size", 10)
	a_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	a_hbox.add_child(a_title_lbl)

	# Center: VS / Pacts & Wars + History Chart Toggle
	var center_hbox := HBoxContainer.new()
	center_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_hbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(center_hbox)

	var center_lbl := Label.new()
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_lbl.add_theme_font_size_override("font_size", 10)
	center_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	center_hbox.add_child(center_lbl)

	hud._stats_chart_toggle_btn = Button.new()
	hud._stats_chart_toggle_btn.text = "📈"
	hud._stats_chart_toggle_btn.custom_minimum_size = Vector2(24, 20)
	hud._stats_chart_toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud._stats_chart_toggle_btn.add_theme_font_size_override("font_size", 10)
	hud._stats_chart_toggle_btn.pressed.connect(func() -> void:
		hud._stats_chart_panel.visible = not hud._stats_chart_panel.visible
		EvoUiStyle.apply_button_active(hud._stats_chart_toggle_btn, hud._stats_chart_panel.visible)
		refresh_stats_strip(hud)
	)
	center_hbox.add_child(hud._stats_chart_toggle_btn)

	# Right: Strategy B
	var b_hbox := HBoxContainer.new()
	b_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_hbox.alignment = BoxContainer.ALIGNMENT_END
	b_hbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(b_hbox)

	var b_title_lbl := Label.new()
	b_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b_title_lbl.clip_text = true
	b_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b_title_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	b_title_lbl.add_theme_font_size_override("font_size", 10)
	b_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	b_hbox.add_child(b_title_lbl)

	var b_swatch := ColorRect.new()
	b_swatch.custom_minimum_size = Vector2(10, 10)
	b_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b_swatch.color = Color("#ef4444")
	b_hbox.add_child(b_swatch)

	# Collapsible History Chart Drawer right below the pill
	hud._stats_chart_panel = PanelContainer.new()
	hud._stats_chart_panel.visible = false
	hud._stats_chart_panel.anchor_left = 0.5
	hud._stats_chart_panel.anchor_right = 0.5
	hud._stats_chart_panel.anchor_top = 0.0
	hud._stats_chart_panel.anchor_bottom = 0.0
	hud._stats_chart_panel.offset_left = -230
	hud._stats_chart_panel.offset_right = 230
	hud._stats_chart_panel.offset_top = 42
	hud._stats_chart_panel.offset_bottom = 192
	hud._stats_chart_panel.z_index = 25
	hud._stats_chart_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(4))
	hud.add_child(hud._stats_chart_panel)

	var chart_inner := PanelContainer.new()
	chart_inner.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(5, false))
	hud._stats_chart_panel.add_child(chart_inner)

	var chart_vbox := VBoxContainer.new()
	chart_vbox.add_theme_constant_override("separation", 3)
	chart_inner.add_child(chart_vbox)

	var pills_row := HBoxContainer.new()
	pills_row.add_theme_constant_override("separation", 3)
	chart_vbox.add_child(pills_row)

	var metric_buttons: Dictionary = {}
	for m_id in METRIC_IDS:
		var m_btn := Button.new()
		m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_btn.add_theme_font_size_override("font_size", 10)
		m_btn.pressed.connect(func() -> void:
			hud._stats_chart_metric = m_id
			refresh_stats_strip(hud)
		)
		pills_row.add_child(m_btn)
		metric_buttons[m_id] = m_btn

	var chart_ctrl := StatsHistoryChart.new()
	chart_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_ctrl.custom_minimum_size = Vector2(0, 100)
	chart_vbox.add_child(chart_ctrl)

	hud.set_meta("_stats_a_swatch", a_swatch)
	hud.set_meta("_stats_a_title", a_title_lbl)
	hud.set_meta("_stats_b_swatch", b_swatch)
	hud.set_meta("_stats_b_title", b_title_lbl)
	hud.set_meta("_stats_center_lbl", center_lbl)
	hud.set_meta("_stats_metric_btns", metric_buttons)
	hud.set_meta("_stats_chart_ctrl", chart_ctrl)


static func refresh_stats_strip(hud: Control) -> void:
	if hud._stats_strip_panel == null or hud._world_state == null:
		return
	var state: EvoTypes.WorldState = hud._world_state
	var lang: String = hud._lang
	var stats := EvoTypes.compute_world_stats(state)
	var sa: Dictionary = stats["a"]
	var sb: Dictionary = stats["b"]

	var col_a := Color("#10b981")
	var col_b := Color("#ef4444")
	var name_a := "A"
	var name_b := "B"
	var full_a := "A"
	var full_b := "B"
	if state.strategies_catalog.has(state.strategy_a_id):
		var def_a: EvoTypes.StrategyDef = state.strategies_catalog[state.strategy_a_id]
		col_a = Color.from_string(def_a.color, col_a)
		full_a = EvoI18n.strategy_name(lang, def_a)
		name_a = _short_strategy_name(full_a)
	if state.strategies_catalog.has(state.strategy_b_id):
		var def_b: EvoTypes.StrategyDef = state.strategies_catalog[state.strategy_b_id]
		col_b = Color.from_string(def_b.color, col_b)
		full_b = EvoI18n.strategy_name(lang, def_b)
		name_b = _short_strategy_name(full_b)

	var a_swatch := hud.get_meta("_stats_a_swatch") as ColorRect
	var a_title := hud.get_meta("_stats_a_title") as Label
	var b_swatch := hud.get_meta("_stats_b_swatch") as ColorRect
	var b_title := hud.get_meta("_stats_b_title") as Label
	var center_lbl := hud.get_meta("_stats_center_lbl") as Label

	a_swatch.color = col_a
	b_swatch.color = col_b

	a_title.text = _format_pill_side(name_a, sa, false)
	a_title.tooltip_text = "%s\n%s" % [full_a, _format_side_subline(sa)]
	b_title.text = _format_pill_side(name_b, sb, true)
	b_title.tooltip_text = "%s\n%s" % [full_b, _format_side_subline(sb)]

	center_lbl.text = "🤝%d ⚔%d" % [
		int(stats["pacts"]),
		int(stats["wars"]) + int(stats["vendettas"])
	]
	center_lbl.tooltip_text = "🤝 %d · 🩸 %d · ⚔ %d" % [
		int(stats["pacts"]),
		int(stats["vendettas"]),
		int(stats["wars"])
	]
	hud._stats_chart_toggle_btn.tooltip_text = EvoUiStyle.tr_text(
		lang,
		"Mostrar / ocultar gráficas históricas A vs. B",
		"Show / hide A vs. B history charts"
	)

	var metric_buttons: Dictionary = hud.get_meta("_stats_metric_btns")
	for m_id in METRIC_IDS:
		var btn := metric_buttons[m_id] as Button
		btn.text = _metric_label(lang, m_id)
		EvoUiStyle.apply_button_active(btn, hud._stats_chart_metric == m_id)

	if hud._stats_chart_panel != null and hud._stats_chart_panel.visible:
		var chart_ctrl := hud.get_meta("_stats_chart_ctrl") as StatsHistoryChart
		if state.stats_history.is_empty():
			chart_ctrl.history = [stats]
		else:
			chart_ctrl.history = state.stats_history
		chart_ctrl.metric = hud._stats_chart_metric
		chart_ctrl.color_a = col_a
		chart_ctrl.color_b = col_b
		chart_ctrl.name_a = name_a
		chart_ctrl.name_b = name_b
		chart_ctrl.lang = lang
		chart_ctrl.queue_redraw()


static func _short_strategy_name(full_name: String) -> String:
	if full_name.length() <= 11:
		return full_name
	return full_name.substr(0, 10) + "…"


static func _format_pill_side(short_name: String, side: Dictionary, reverse_order: bool) -> String:
	var v_cnt := int(side["villages"])
	var pop := int(side["population"])
	var delta := int(side["pop_delta"])
	var delta_str := "(%+d)" % delta if delta != 0 else ""
	var food_pct := int(round(float(side["food_ratio"]) * 100.0))
	var inf := int(side["infected"])
	var inf_str := (" ☣%d" % inf) if inf > 0 else ""
	if reverse_order:
		return "🍖%d%% 👥%d%s 🏘%d%s · %s" % [food_pct, pop, delta_str, v_cnt, inf_str, short_name]
	return "%s · 🏘%d 👥%d%s 🍖%d%%%s" % [short_name, v_cnt, pop, delta_str, food_pct, inf_str]


static func _format_side_subline(side: Dictionary) -> String:
	var food_pct := int(round(float(side["food_ratio"]) * 100.0))
	var sal_pct := int(round(float(side["salubrity_avg"]) * 100.0))
	var rural := int(side["rural_hexes"])
	var inf := int(side["infected"])
	var base := "🍖%d%% · ✚%d%% · 🌾%d" % [food_pct, sal_pct, rural]
	if inf > 0:
		return base + (" · ☣%d" % inf)
	return base


static func _metric_label(lang: String, metric_id: String) -> String:
	match metric_id:
		"population":
			return EvoUiStyle.tr_text(lang, "👥 Población", "👥 Population")
		"food_ratio":
			return EvoUiStyle.tr_text(lang, "🍖 Alimento %", "🍖 Food %")
		"salubrity_avg":
			return EvoUiStyle.tr_text(lang, "✚ Salubridad %", "✚ Salubrity %")
		"rural_hexes":
			return EvoUiStyle.tr_text(lang, "🌾 Territorio", "🌾 Territory")
	return metric_id
