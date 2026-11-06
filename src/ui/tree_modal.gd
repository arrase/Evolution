class_name EvoTreeModal
extends Control

signal lineage_highlight_requested(lineage_id: String)
signal modal_closed()

var _world_state: EvoTypes.WorldState = null
var _lang: String = "es"
var _selected_lineage_id: String = ""

var _title_label: Label
var _close_btn: Button
var _scroll: ScrollContainer
var _canvas: TreeCanvas
var _detail_vbox: VBoxContainer
var _highlight_btn: Button
var _clear_highlight_btn: Button


class TreeCanvas extends Control:
	signal node_clicked(lineage_id: String)

	const NODE_W: float = 250.0
	const NODE_H: float = 108.0
	const COL_GAP: float = 76.0
	const ROW_GAP: float = 26.0
	const PAD_X: float = 36.0
	const PAD_Y: float = 36.0

	var world_state: EvoTypes.WorldState = null
	var lang: String = "es"
	var selected_id: String = ""
	var node_rects: Dictionary = {} # lineage_id -> Rect2
	var children_map: Dictionary = {} # parent_id -> Array[String]
	var living_counts: Dictionary = {} # lineage_id -> int
	var _is_panning: bool = false

	func rebuild_layout(state: EvoTypes.WorldState, p_lang: String, p_selected_id: String) -> void:
		world_state = state
		lang = p_lang
		selected_id = p_selected_id
		node_rects.clear()
		children_map.clear()
		living_counts.clear()

		if world_state == null or world_state.lineage_tree.is_empty():
			custom_minimum_size = Vector2(560, 420)
			queue_redraw()
			return

		for d_key in world_state.demes.keys():
			var d: EvoTypes.Deme = world_state.demes[d_key]
			living_counts[d.lineage_id] = int(living_counts.get(d.lineage_id, 0)) + 1

		var roots: Array[String] = []
		for l_id in world_state.lineage_tree.keys():
			var node: EvoTypes.LineageNode = world_state.lineage_tree[l_id]
			if node.parent_id == "" or not world_state.lineage_tree.has(node.parent_id):
				roots.append(l_id)
			else:
				if not children_map.has(node.parent_id):
					children_map[node.parent_id] = []
				children_map[node.parent_id].append(l_id)

		roots.sort_custom(_sort_lineage_ids)
		for p_id in children_map.keys():
			var arr: Array = children_map[p_id]
			arr.sort_custom(_sort_lineage_ids)

		var leaf_counter: Array[int] = [0]
		var max_depth: Array[int] = [0]
		for r_id in roots:
			_place_subtree(r_id, 0, leaf_counter, max_depth)

		var total_cols := max_depth[0] + 1
		var total_rows := maxi(1, leaf_counter[0])
		var req_w := PAD_X * 2.0 + float(total_cols) * NODE_W + float(maxi(0, total_cols - 1)) * COL_GAP
		var req_h := PAD_Y * 2.0 + float(total_rows) * NODE_H + float(maxi(0, total_rows - 1)) * ROW_GAP
		custom_minimum_size = Vector2(maxf(560.0, req_w), maxf(440.0, req_h))
		queue_redraw()

	func _sort_lineage_ids(a: String, b: String) -> bool:
		var na: EvoTypes.LineageNode = world_state.lineage_tree[a]
		var nb: EvoTypes.LineageNode = world_state.lineage_tree[b]
		if na.founded_generation != nb.founded_generation:
			return na.founded_generation < nb.founded_generation
		return a < b

	func _place_subtree(lineage_id: String, depth: int, leaf_counter: Array[int], max_depth: Array[int]) -> float:
		if depth > max_depth[0]:
			max_depth[0] = depth
		var x := PAD_X + float(depth) * (NODE_W + COL_GAP)
		var kids: Array = children_map.get(lineage_id, [])
		if kids.is_empty():
			var row_idx := leaf_counter[0]
			leaf_counter[0] += 1
			var y := PAD_Y + float(row_idx) * (NODE_H + ROW_GAP)
			node_rects[lineage_id] = Rect2(Vector2(x, y), Vector2(NODE_W, NODE_H))
			return y

		var child_ys: Array[float] = []
		for k_id in kids:
			child_ys.append(_place_subtree(str(k_id), depth + 1, leaf_counter, max_depth))
		var mid_y := (child_ys[0] + child_ys[child_ys.size() - 1]) * 0.5
		node_rects[lineage_id] = Rect2(Vector2(x, mid_y), Vector2(NODE_W, NODE_H))
		return mid_y

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					for l_id in node_rects.keys():
						var r: Rect2 = node_rects[l_id]
						if r.has_point(event.position):
							node_clicked.emit(str(l_id))
							accept_event()
							return
					_is_panning = true
				else:
					_is_panning = false
		elif event is InputEventMouseMotion and _is_panning:
			var parent_scroll := get_parent() as ScrollContainer
			if parent_scroll != null:
				parent_scroll.scroll_horizontal -= int(event.relative.x)
				parent_scroll.scroll_vertical -= int(event.relative.y)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		if world_state == null or node_rects.is_empty():
			var msg := EvoUiStyle.tr_text(lang, "Sin linajes registrados.", "No lineages recorded.")
			draw_string(font, Vector2(40, 60), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, EvoUiStyle.COLOR_SEPIA)
			return

		# Draw connections first
		for p_id in children_map.keys():
			if not node_rects.has(p_id):
				continue
			var p_rect: Rect2 = node_rects[p_id]
			var start := Vector2(p_rect.end.x, p_rect.position.y + p_rect.size.y * 0.5)
			var kids: Array = children_map[p_id]
			for k_id in kids:
				if not node_rects.has(k_id):
					continue
				var c_rect: Rect2 = node_rects[k_id]
				var finish := Vector2(c_rect.position.x, c_rect.position.y + c_rect.size.y * 0.5)
				_draw_branch_curve(start, finish)

		# Draw nodes
		for l_id in node_rects.keys():
			var rect: Rect2 = node_rects[l_id]
			var node: EvoTypes.LineageNode = world_state.lineage_tree[l_id]
			var is_sel: bool = (str(l_id) == selected_id)
			var lin_color := Color.from_string(node.color, Color("#E07A5F"))
			var bg := Color("#fef3c7") if is_sel else Color("#fbf2de")
			var border := EvoUiStyle.COLOR_GOLD_BRIGHT if is_sel else EvoUiStyle.COLOR_WOOD_BG

			# Shadow & card body
			draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.15, 0.08, 0.02, 0.20), true)
			draw_rect(rect, bg, true)
			draw_rect(Rect2(rect.position, Vector2(8.0, rect.size.y)), lin_color, true)
			draw_rect(rect, border, false, 3.0 if is_sel else 2.0)

			# Lineage emblem circle
			var emblem_center := rect.position + Vector2(24.0, 22.0)
			draw_circle(emblem_center, 9.0, EvoUiStyle.COLOR_WOOD_DARK)
			draw_circle(emblem_center, 7.0, lin_color)

			# Title + Founded Gen
			var title_str := node.name
			if title_str.length() > 22:
				title_str = title_str.substr(0, 20) + "…"
			draw_string(font, rect.position + Vector2(40.0, 22.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, NODE_W - 88.0, 13, EvoUiStyle.COLOR_INK)

			var gen_str := "G%d" % node.founded_generation
			draw_string(font, rect.position + Vector2(NODE_W - 44.0, 22.0), gen_str, HORIZONTAL_ALIGNMENT_RIGHT, 38.0, 12, EvoUiStyle.COLOR_SEPIA)

			# Divergence reason
			var reason_str := EvoUiStyle.get_divergence_reason_label(node.divergence_reason, lang)
			draw_string(font, rect.position + Vector2(16.0, 44.0), reason_str, HORIZONTAL_ALIGNMENT_LEFT, NODE_W - 24.0, 12, EvoUiStyle.COLOR_SEPIA)

			# Living vs extinct status
			var alive_cnt: int = int(living_counts.get(l_id, 0))
			var status_str := ""
			var status_col := EvoUiStyle.COLOR_GREEN_OK
			if alive_cnt > 0:
				status_str = EvoUiStyle.tr_text(lang, "● %d aldeas vivas" % alive_cnt, "● %d living villages" % alive_cnt)
			else:
				var ext_g := node.extinct_generation if node.extinct_generation >= 0 else world_state.generation
				status_str = EvoUiStyle.tr_text(lang, "✕ Extinto en G%d" % ext_g, "✕ Extinct at G%d" % ext_g)
				status_col = EvoUiStyle.COLOR_RED_DANGER
			draw_string(font, rect.position + Vector2(16.0, 66.0), status_str, HORIZONTAL_ALIGNMENT_LEFT, NODE_W - 24.0, 12, status_col)

			# Founder hex & traits count
			var footer_str := EvoUiStyle.tr_text(
				lang,
				"Hex (%s) · %d rasgos" % [node.founder_hex_id, node.acquired_trait_ids.size()],
				"Hex (%s) · %d traits" % [node.founder_hex_id, node.acquired_trait_ids.size()]
			)
			draw_string(font, rect.position + Vector2(16.0, 88.0), footer_str, HORIZONTAL_ALIGNMENT_LEFT, NODE_W - 24.0, 11, EvoUiStyle.COLOR_MUTED)

	func _draw_branch_curve(start: Vector2, finish: Vector2) -> void:
		var pts := PackedVector2Array()
		var steps := 16
		var c1 := Vector2((start.x + finish.x) * 0.5, start.y)
		var c2 := Vector2((start.x + finish.x) * 0.5, finish.y)
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var omt := 1.0 - t
			var p := (omt * omt * omt) * start + (3.0 * omt * omt * t) * c1 + (3.0 * omt * t * t) * c2 + (t * t * t) * finish
			pts.append(p)
		draw_polyline(pts, EvoUiStyle.COLOR_WOOD_BG, 2.5, true)
		draw_circle(start, 3.5, EvoUiStyle.COLOR_GOLD_BEVEL)
		draw_circle(finish, 3.5, EvoUiStyle.COLOR_WOOD_BG)


func _ready() -> void:
	if _title_label != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = EvoUiStyle.get_theme()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_modal()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.03, 0.01, 0.72)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(980, 640)
	frame.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(14))
	center.add_child(frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	frame.add_child(main_vbox)

	# Header
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_header_box(12, 8))
	main_vbox.add_child(header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_panel.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.pressed.connect(close_modal)
	header_hbox.add_child(_close_btn)

	# Split body: Tree Canvas (left) + Detail Inspector (right)
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(body_hbox)

	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(8, false))
	body_hbox.add_child(canvas_panel)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(_scroll)

	_canvas = TreeCanvas.new()
	_canvas.node_clicked.connect(_on_node_clicked)
	_scroll.add_child(_canvas)

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(310, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(12, true))
	body_hbox.add_child(side_panel)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_vbox)

	var side_scroll := ScrollContainer.new()
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(side_scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 8)
	side_scroll.add_child(_detail_vbox)

	_highlight_btn = Button.new()
	_highlight_btn.pressed.connect(_on_highlight_pressed)
	side_vbox.add_child(_highlight_btn)

	_clear_highlight_btn = Button.new()
	_clear_highlight_btn.pressed.connect(_on_clear_highlight_pressed)
	side_vbox.add_child(_clear_highlight_btn)

	_update_labels()


func open_modal(world_state: EvoTypes.WorldState, lang: String = "es", initial_lineage_id: String = "") -> void:
	if _title_label == null:
		_ready()
	_world_state = world_state
	_lang = lang
	if initial_lineage_id != "" and _world_state != null and _world_state.lineage_tree.has(initial_lineage_id):
		_selected_lineage_id = initial_lineage_id
	elif _selected_lineage_id == "" or (_world_state != null and not _world_state.lineage_tree.has(_selected_lineage_id)):
		if _world_state != null and not _world_state.lineage_tree.is_empty():
			_selected_lineage_id = str(_world_state.lineage_tree.keys()[0])
	visible = true
	_update_labels()
	_refresh_view()


func refresh(world_state: EvoTypes.WorldState) -> void:
	_world_state = world_state
	if visible:
		_refresh_view()


func set_language(lang: String) -> void:
	_lang = lang
	_update_labels()
	if visible:
		_refresh_view()


func close_modal() -> void:
	visible = false
	modal_closed.emit()


func _update_labels() -> void:
	if _title_label == null:
		return
	_title_label.text = EvoUiStyle.tr_text(
		_lang,
		"🌳 Árbol Filo-Cultural de Linajes",
		"🌳 Phylo-Cultural Lineage Tree"
	)
	_close_btn.text = EvoUiStyle.tr_text(_lang, "✕ Cerrar", "✕ Close")
	_highlight_btn.text = EvoUiStyle.tr_text(_lang, "✨ Resaltar Linaje en el Mapa", "✨ Highlight Lineage on Map")
	_clear_highlight_btn.text = EvoUiStyle.tr_text(_lang, "🧹 Quitar Resaltado", "🧹 Clear Highlight")


func _refresh_view() -> void:
	if _canvas == null:
		return
	_canvas.rebuild_layout(_world_state, _lang, _selected_lineage_id)
	_rebuild_detail_panel()


func _rebuild_detail_panel() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()

	if _world_state == null or not _world_state.lineage_tree.has(_selected_lineage_id):
		_highlight_btn.disabled = true
		var empty_lbl := Label.new()
		empty_lbl.text = EvoUiStyle.tr_text(
			_lang,
			"Selecciona un nodo del árbol para inspeccionar su historia evolutiva.",
			"Select a node in the tree to inspect its evolutionary history."
		)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
		_detail_vbox.add_child(empty_lbl)
		return

	_highlight_btn.disabled = false
	var node: EvoTypes.LineageNode = _world_state.lineage_tree[_selected_lineage_id]
	var lin_color := Color.from_string(node.color, Color("#E07A5F"))

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	_detail_vbox.add_child(header_hbox)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.color = lin_color
	header_hbox.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = node.name
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	header_hbox.add_child(name_lbl)

	var living_demes: Array[EvoTypes.Deme] = []
	for d_key in _world_state.demes.keys():
		var d: EvoTypes.Deme = _world_state.demes[d_key]
		if d.lineage_id == node.id:
			living_demes.append(d)

	_add_kv_row(
		EvoUiStyle.tr_text(_lang, "Fundación:", "Founded:"),
		"G%d · Hex (%s)" % [node.founded_generation, node.founder_hex_id]
	)
	_add_kv_row(
		EvoUiStyle.tr_text(_lang, "Divergencia:", "Divergence:"),
		EvoUiStyle.get_divergence_reason_label(node.divergence_reason, _lang)
	)
	if node.parent_id != "" and _world_state.lineage_tree.has(node.parent_id):
		var p_node: EvoTypes.LineageNode = _world_state.lineage_tree[node.parent_id]
		_add_kv_row(EvoUiStyle.tr_text(_lang, "Ancestro:", "Parent:"), p_node.name)

	var status_text := ""
	if living_demes.size() > 0:
		status_text = EvoUiStyle.tr_text(_lang, "%d aldeas vivas" % living_demes.size(), "%d living villages" % living_demes.size())
	else:
		var ext_g := node.extinct_generation if node.extinct_generation >= 0 else _world_state.generation
		status_text = EvoUiStyle.tr_text(_lang, "Extinto en G%d" % ext_g, "Extinct at G%d" % ext_g)
	_add_kv_row(EvoUiStyle.tr_text(_lang, "Estado:", "Status:"), status_text)

	# Acquired traits list
	var traits_title := Label.new()
	traits_title.text = EvoUiStyle.tr_text(
		_lang,
		"Rasgos Fundacionales / Adquiridos (%d):" % node.acquired_trait_ids.size(),
		"Acquired Traits (%d):" % node.acquired_trait_ids.size()
	)
	traits_title.add_theme_font_size_override("font_size", 13)
	traits_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	_detail_vbox.add_child(traits_title)

	for t_id in node.acquired_trait_ids:
		var t_name := t_id
		if _world_state.traits_catalog.has(t_id):
			var t_def: EvoTypes.TraitDef = _world_state.traits_catalog[t_id]
			t_name = "• %s (%s)" % [t_def.name, t_def.category]
		var tl := Label.new()
		tl.text = t_name
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.add_theme_font_size_override("font_size", 12)
		tl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
		_detail_vbox.add_child(tl)

	# Living demes list
	if not living_demes.is_empty():
		var villages_title := Label.new()
		villages_title.text = EvoUiStyle.tr_text(_lang, "Aldeas Activas:", "Active Villages:")
		villages_title.add_theme_font_size_override("font_size", 13)
		villages_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
		_detail_vbox.add_child(villages_title)

		for d in living_demes:
			var dl := Label.new()
			dl.text = "• %s [%s · %d hab · 🧠 %s · (%s)]" % [d.name, d.get_village_roman(), d.population, d.decision_model_tag, d.hex_id]
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.add_theme_font_size_override("font_size", 12)
			dl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
			_detail_vbox.add_child(dl)


func _add_kv_row(key_str: String, val_str: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	_detail_vbox.add_child(hbox)

	var k_lbl := Label.new()
	k_lbl.text = key_str
	k_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	k_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(k_lbl)

	var v_lbl := Label.new()
	v_lbl.text = val_str
	v_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	v_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(v_lbl)


func _on_node_clicked(lineage_id: String) -> void:
	_selected_lineage_id = lineage_id
	_refresh_view()


func _on_highlight_pressed() -> void:
	if _selected_lineage_id != "":
		lineage_highlight_requested.emit(_selected_lineage_id)
		close_modal()


func _on_clear_highlight_pressed() -> void:
	lineage_highlight_requested.emit("")
	close_modal()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_modal()
