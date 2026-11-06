class_name EvoNotebookModal
extends Control

signal jump_to_hex_requested(hex_id: String, deme_id: String)
signal modal_closed()

const FILTER_KEYS: Array[String] = [
	"all",
	"baldwin_trait",
	"cultural_innovation",
	"allopatric_speciation",
	"symbiosis",
	"tragedy_of_commons",
	"cultural_loss",
	"extinction"
]

var _world_state: EvoTypes.WorldState = null
var _active_filter: String = "all"
var _lang: String = "es"

var _title_label: Label
var _count_label: Label
var _close_btn: Button
var _filter_buttons: Dictionary = {}
var _cards_vbox: VBoxContainer


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

	var book_frame := PanelContainer.new()
	book_frame.custom_minimum_size = Vector2(920, 620)
	book_frame.add_theme_stylebox_override("panel", EvoUiStyle.make_wood_frame_box(14))
	center.add_child(book_frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	book_frame.add_child(main_vbox)

	# Header bar
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

	_count_label = Label.new()
	_count_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_CREAM_TEXT)
	_count_label.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(_count_label)

	_close_btn = Button.new()
	_close_btn.pressed.connect(close_modal)
	header_hbox.add_child(_close_btn)

	# Filter strip
	var filter_panel := PanelContainer.new()
	filter_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(8, true))
	main_vbox.add_child(filter_panel)

	var filter_flow := HFlowContainer.new()
	filter_flow.add_theme_constant_override("h_separation", 6)
	filter_flow.add_theme_constant_override("v_separation", 6)
	filter_panel.add_child(filter_flow)

	for f_key in FILTER_KEYS:
		var btn := Button.new()
		btn.pressed.connect(_on_filter_pressed.bind(f_key))
		filter_flow.add_child(btn)
		_filter_buttons[f_key] = btn

	# Parchment page body
	var page_panel := PanelContainer.new()
	page_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_panel.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_panel(12, false))
	main_vbox.add_child(page_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_panel.add_child(scroll)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards_vbox)

	_update_labels()


func open_modal(world_state: EvoTypes.WorldState, lang: String = "es") -> void:
	if _title_label == null:
		_ready()
	_world_state = world_state
	_lang = lang
	visible = true
	_update_labels()
	_rebuild_entries()


func refresh(world_state: EvoTypes.WorldState) -> void:
	_world_state = world_state
	if visible:
		_rebuild_entries()


func set_language(lang: String) -> void:
	_lang = lang
	_update_labels()
	if visible:
		_rebuild_entries()


func set_filter(filter_key: String) -> void:
	_active_filter = filter_key
	_update_filter_buttons()
	_rebuild_entries()


func close_modal() -> void:
	visible = false
	modal_closed.emit()


func _update_labels() -> void:
	if _title_label == null:
		return
	_title_label.text = EvoUiStyle.tr_text(
		_lang,
		"📖 Cuaderno del Naturalista — Crónica Evolutiva",
		"📖 Naturalist's Notebook — Evolutionary Chronicle"
	)
	_close_btn.text = EvoUiStyle.tr_text(_lang, "✕ Cerrar", "✕ Close")
	_update_filter_buttons()


func _update_filter_buttons() -> void:
	for f_key in FILTER_KEYS:
		if _filter_buttons.has(f_key):
			var btn: Button = _filter_buttons[f_key]
			btn.text = EvoUiStyle.get_event_type_label(f_key, _lang)
			EvoUiStyle.apply_button_active(btn, _active_filter == f_key)


func _rebuild_entries() -> void:
	if _cards_vbox == null:
		return
	for child in _cards_vbox.get_children():
		child.queue_free()

	if _world_state == null:
		_count_label.text = "0"
		return

	var filtered: Array[EvoTypes.ChronicleEntry] = []
	for i in range(_world_state.chronicle.size() - 1, -1, -1):
		var entry: EvoTypes.ChronicleEntry = _world_state.chronicle[i]
		if _active_filter == "all" or entry.event_type == _active_filter:
			filtered.append(entry)

	_count_label.text = EvoUiStyle.tr_text(
		_lang,
		"%d entradas" % filtered.size(),
		"%d entries" % filtered.size()
	)

	if filtered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = EvoUiStyle.tr_text(
			_lang,
			"No hay registros en el cuaderno para el filtro seleccionado.",
			"No chronicle entries found for the selected filter."
		)
		empty_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(0, 80)
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cards_vbox.add_child(empty_lbl)
		return

	var max_displayed := mini(filtered.size(), 100)
	for i in range(max_displayed):
		_cards_vbox.add_child(_create_entry_card(filtered[i]))


func _create_entry_card(entry: EvoTypes.ChronicleEntry) -> Control:
	var ev_color := EvoUiStyle.get_event_type_color(entry.event_type)
	var card := PanelContainer.new()
	var card_style := EvoUiStyle.make_parchment_card(Color("#fbf2de"), ev_color.lerp(EvoUiStyle.COLOR_PARCHMENT_BORDER, 0.45), 10)
	card_style.border_width_left = 6
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(top_hbox)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(ev_color))
	top_hbox.add_child(badge)

	var badge_lbl := Label.new()
	badge_lbl.text = EvoUiStyle.get_event_type_label(entry.event_type, _lang)
	badge_lbl.add_theme_color_override("font_color", Color.WHITE)
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge.add_child(badge_lbl)

	var gen_badge := PanelContainer.new()
	gen_badge.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(EvoUiStyle.COLOR_WOOD_BG, EvoUiStyle.COLOR_GOLD_BEVEL))
	top_hbox.add_child(gen_badge)

	var gen_lbl := Label.new()
	gen_lbl.text = "G%d" % entry.generation
	gen_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_TEXT)
	gen_lbl.add_theme_font_size_override("font_size", 11)
	gen_badge.add_child(gen_lbl)

	var hex_lbl := Label.new()
	hex_lbl.text = "Hex (%s)" % entry.hex_id
	hex_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	hex_lbl.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(hex_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var jump_btn := Button.new()
	jump_btn.text = EvoUiStyle.tr_text(_lang, "📍 Ver en el mapa", "📍 View on map")
	jump_btn.pressed.connect(_on_jump_pressed.bind(entry.hex_id, entry.deme_id))
	top_hbox.add_child(jump_btn)

	var title_lbl := Label.new()
	title_lbl.text = entry.title
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	title_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = entry.causal_explanation
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc_lbl)

	return card


func _on_filter_pressed(filter_key: String) -> void:
	set_filter(filter_key)


func _on_jump_pressed(hex_id: String, deme_id: String) -> void:
	jump_to_hex_requested.emit(hex_id, deme_id)
	close_modal()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_modal()
