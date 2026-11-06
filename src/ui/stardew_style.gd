class_name EvoStardewStyle
extends RefCounted

const COLOR_WOOD_BG := Color("#5c3218")
const COLOR_WOOD_DARK := Color("#3a1d0b")
const COLOR_WOOD_LIGHT := Color("#7a4524")
const COLOR_WOOD_PLANK := Color("#6b3b1e")
const COLOR_GOLD_BEVEL := Color("#d99b43")
const COLOR_GOLD_BRIGHT := Color("#f59e0b")
const COLOR_BRONZE_BORDER := Color("#b07228")

const COLOR_PARCHMENT := Color("#f6e7c8")
const COLOR_PARCHMENT_ALT := Color("#edd6a8")
const COLOR_PARCHMENT_DARK := Color("#dfc18d")
const COLOR_PARCHMENT_BORDER := Color("#c49a6c")

const COLOR_SLOT_BG := Color("#e5c896")
const COLOR_SLOT_HOVER := Color("#f7dfa8")
const COLOR_SLOT_ACTIVE := Color("#fff3c4")
const COLOR_SLOT_BORDER := Color("#8a5229")

const COLOR_BTN_NORMAL := Color("#f2ddb6")
const COLOR_BTN_HOVER := Color("#ffe8b8")
const COLOR_BTN_PRESSED := Color("#d9b478")
const COLOR_BTN_ACTIVE_BG := Color("#fef3c7")
const COLOR_BTN_ACTIVE_BORDER := Color("#f59e0b")

const COLOR_INK := Color("#3a2010")
const COLOR_SEPIA := Color("#6e472b")
const COLOR_MUTED := Color("#8c6244")
const COLOR_CREAM_TEXT := Color("#fff5e0")
const COLOR_GOLD_TEXT := Color("#ffd97d")

const COLOR_GREEN_OK := Color("#15803d")
const COLOR_AMBER_WARN := Color("#b45309")
const COLOR_RED_DANGER := Color("#b91c1c")
const COLOR_BLUE_INFO := Color("#1d4ed8")
const COLOR_PURPLE_CULTURE := Color("#7e22ce")

static var _cached_theme: Theme = null
static var _icon_cache: Dictionary = {}
static var _stylebox_cache: Dictionary = {}


static func tr_text(lang: String, es_text: String, en_text: String) -> String:
	return en_text if lang == "en" else es_text


static func get_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme
	_cached_theme = build_theme()
	return _cached_theme


static func build_theme() -> Theme:
	var theme := Theme.new()

	var btn_normal := make_button_style(COLOR_BTN_NORMAL, COLOR_WOOD_BG, 2)
	var btn_hover := make_button_style(COLOR_BTN_HOVER, COLOR_GOLD_BEVEL, 2)
	var btn_pressed := make_button_style(COLOR_BTN_PRESSED, COLOR_WOOD_DARK, 2)
	var btn_disabled := make_button_style(Color("#e2d5be", 0.65), Color("#9e8468", 0.65), 1)
	var btn_focus := make_button_style(COLOR_BTN_ACTIVE_BG, COLOR_BTN_ACTIVE_BORDER, 2)

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", btn_focus)

	theme.set_color("font_color", "Button", COLOR_INK)
	theme.set_color("font_hover_color", "Button", COLOR_INK)
	theme.set_color("font_pressed_color", "Button", COLOR_WOOD_DARK)
	theme.set_color("font_focus_color", "Button", COLOR_INK)
	theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	theme.set_font_size("font_size", "Button", 12)

	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)
	theme.set_stylebox("focus", "OptionButton", btn_focus)
	theme.set_color("font_color", "OptionButton", COLOR_INK)
	theme.set_color("font_hover_color", "OptionButton", COLOR_INK)
	theme.set_color("font_pressed_color", "OptionButton", COLOR_WOOD_DARK)
	theme.set_font_size("font_size", "OptionButton", 12)

	theme.set_color("font_color", "CheckBox", COLOR_INK)
	theme.set_color("font_hover_color", "CheckBox", COLOR_INK)
	theme.set_color("font_pressed_color", "CheckBox", COLOR_WOOD_DARK)
	theme.set_font_size("font_size", "CheckBox", 12)

	theme.set_color("font_color", "Label", COLOR_INK)
	theme.set_font_size("font_size", "Label", 12)

	theme.set_stylebox("panel", "PanelContainer", make_parchment_panel())
	theme.set_stylebox("panel", "PopupMenu", make_wood_frame_box())
	theme.set_color("font_color", "PopupMenu", COLOR_CREAM_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", COLOR_GOLD_TEXT)
	theme.set_stylebox("hover", "PopupMenu", make_button_style(COLOR_WOOD_LIGHT, COLOR_GOLD_BEVEL, 1))

	var input_normal := make_parchment_card(Color("#fff9eb"), COLOR_PARCHMENT_BORDER)
	var input_focus := make_parchment_card(Color("#fffdf7"), COLOR_GOLD_BRIGHT)
	theme.set_stylebox("normal", "LineEdit", input_normal)
	theme.set_stylebox("focus", "LineEdit", input_focus)
	theme.set_color("font_color", "LineEdit", COLOR_INK)
	theme.set_color("font_placeholder_color", "LineEdit", COLOR_MUTED)
	theme.set_color("caret_color", "LineEdit", COLOR_WOOD_DARK)

	theme.set_stylebox("normal", "TextEdit", input_normal)
	theme.set_stylebox("focus", "TextEdit", input_focus)
	theme.set_color("font_color", "TextEdit", COLOR_INK)
	theme.set_color("font_placeholder_color", "TextEdit", COLOR_MUTED)
	theme.set_color("caret_color", "TextEdit", COLOR_WOOD_DARK)

	theme.set_stylebox("background", "ProgressBar", make_progress_bg())
	theme.set_stylebox("fill", "ProgressBar", make_progress_fill(COLOR_GREEN_OK))
	theme.set_color("font_color", "ProgressBar", COLOR_INK)
	theme.set_font_size("font_size", "ProgressBar", 11)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = COLOR_PARCHMENT_DARK
	slider_bg.border_color = COLOR_WOOD_BG
	slider_bg.set_border_width_all(1)
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = COLOR_GOLD_BEVEL
	grabber_area.set_corner_radius_all(3)
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area)

	return theme


static func make_wood_frame_box(padding: int = 8) -> StyleBoxFlat:
	var key := "wood_frame:%d" % padding
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_WOOD_BG
	box.border_color = COLOR_GOLD_BEVEL
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0.06, 0.03, 0.01, 0.52)
	box.shadow_size = 7
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	_stylebox_cache[key] = box
	return box


static func make_wood_header_box(padding_h: int = 10, padding_v: int = 6) -> StyleBoxFlat:
	var key := "wood_header:%d:%d" % [padding_h, padding_v]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_WOOD_DARK
	box.border_color = COLOR_GOLD_BEVEL
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	box.content_margin_left = padding_h
	box.content_margin_right = padding_h
	box.content_margin_top = padding_v
	box.content_margin_bottom = padding_v
	_stylebox_cache[key] = box
	return box


static func make_hotbar_frame_box(padding_h: int = 10, padding_v: int = 8) -> StyleBoxFlat:
	var key := "hotbar_frame:%d:%d" % [padding_h, padding_v]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_WOOD_PLANK
	box.border_color = COLOR_GOLD_BEVEL
	box.set_border_width_all(3)
	box.set_corner_radius_all(7)
	box.shadow_color = Color(0.05, 0.02, 0.01, 0.58)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = padding_h
	box.content_margin_right = padding_h
	box.content_margin_top = padding_v
	box.content_margin_bottom = padding_v
	_stylebox_cache[key] = box
	return box


static func make_hotbar_slot_style(is_active: bool, is_hover: bool = false) -> StyleBoxFlat:
	var key := "hotbar_slot:%s:%s" % [str(is_active), str(is_hover)]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	if is_active:
		box.bg_color = COLOR_SLOT_ACTIVE
		box.border_color = Color("#dc2626")
		box.set_border_width_all(3)
		box.shadow_color = Color(0.96, 0.62, 0.04, 0.45)
		box.shadow_size = 4
	elif is_hover:
		box.bg_color = COLOR_SLOT_HOVER
		box.border_color = COLOR_GOLD_BRIGHT
		box.set_border_width_all(2)
	else:
		box.bg_color = COLOR_SLOT_BG
		box.border_color = COLOR_SLOT_BORDER
		box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	_stylebox_cache[key] = box
	return box


static func apply_hotbar_slot_style(btn: Button, is_active: bool) -> void:
	btn.add_theme_stylebox_override("normal", make_hotbar_slot_style(is_active, false))
	btn.add_theme_stylebox_override("hover", make_hotbar_slot_style(is_active, true))
	btn.add_theme_stylebox_override("pressed", make_hotbar_slot_style(true, false))
	btn.add_theme_stylebox_override("focus", make_hotbar_slot_style(is_active, false))


static func make_parchment_panel(padding: int = 10, alt: bool = false) -> StyleBoxFlat:
	var key := "parchment_panel:%d:%s" % [padding, str(alt)]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PARCHMENT_ALT if alt else COLOR_PARCHMENT
	box.border_color = COLOR_PARCHMENT_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	box.shadow_color = Color(0.18, 0.09, 0.03, 0.18)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	_stylebox_cache[key] = box
	return box


static func make_parchment_card(bg: Color = COLOR_PARCHMENT_ALT, border: Color = COLOR_PARCHMENT_BORDER, padding: int = 8) -> StyleBoxFlat:
	var key := "parchment_card:%s:%s:%d" % [bg.to_html(), border.to_html(), padding]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.shadow_color = Color(0.18, 0.09, 0.03, 0.10)
	box.shadow_size = 1
	box.shadow_offset = Vector2(0, 1)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	_stylebox_cache[key] = box
	return box


static func make_button_style(bg: Color, border: Color, border_width: int = 2, padding_h: int = 7, padding_v: int = 4) -> StyleBoxFlat:
	var key := "button_style:%s:%s:%d:%d:%d" % [bg.to_html(), border.to_html(), border_width, padding_h, padding_v]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(4)
	box.content_margin_left = padding_h
	box.content_margin_right = padding_h
	box.content_margin_top = padding_v
	box.content_margin_bottom = padding_v
	_stylebox_cache[key] = box
	return box


static func make_active_button_style(padding_h: int = 7, padding_v: int = 4) -> StyleBoxFlat:
	var key := "active_button_style:%d:%d" % [padding_h, padding_v]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := make_button_style(COLOR_BTN_ACTIVE_BG, COLOR_BTN_ACTIVE_BORDER, 2, padding_h, padding_v)
	_stylebox_cache[key] = box
	return box


static func apply_button_active(btn: Button, is_active: bool) -> void:
	if is_active:
		var active_box := make_active_button_style()
		btn.add_theme_stylebox_override("normal", active_box)
		btn.add_theme_stylebox_override("hover", active_box)
		btn.add_theme_color_override("font_color", COLOR_WOOD_DARK)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_color_override("font_color")


static func make_badge_style(bg_color: Color, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var key := "badge_style:%s:%s" % [bg_color.to_html(), border_color.to_html()]
	if _stylebox_cache.has(key):
		return _stylebox_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = bg_color.darkened(0.28) if border_color == Color.TRANSPARENT else border_color
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	_stylebox_cache[key] = box
	return box


static func make_progress_bg() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#d8be94")
	box.border_color = Color("#7c4d25")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box


static func make_progress_fill(fill_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill_color
	box.border_color = fill_color.lightened(0.22)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box


static func style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	bar.add_theme_stylebox_override("background", make_progress_bg())
	bar.add_theme_stylebox_override("fill", make_progress_fill(fill_color))


static func get_event_type_color(event_type: String) -> Color:
	match event_type:
		"baldwin_trait":
			return Color("#0d9488")
		"cultural_innovation":
			return Color("#7e22ce")
		"allopatric_speciation":
			return Color("#2563eb")
		"symbiosis":
			return Color("#15803d")
		"tragedy_of_commons":
			return Color("#d97706")
		"cultural_loss":
			return Color("#c2410c")
		"extinction":
			return Color("#b91c1c")
	return COLOR_SEPIA


static func get_event_type_label(event_type: String, lang: String = "es") -> String:
	match event_type:
		"all":
			return tr_text(lang, "Todos", "All")
		"baldwin_trait":
			return tr_text(lang, "Efecto Baldwin", "Baldwin Effect")
		"cultural_innovation":
			return tr_text(lang, "Innovación Cultural", "Cultural Innovation")
		"allopatric_speciation":
			return tr_text(lang, "Especiación Alopátrica", "Allopatric Speciation")
		"symbiosis":
			return tr_text(lang, "Simbiosis", "Symbiosis")
		"tragedy_of_commons":
			return tr_text(lang, "Tragedia de los Comunes", "Tragedy of the Commons")
		"cultural_loss":
			return tr_text(lang, "Pérdida Cultural", "Cultural Loss")
		"extinction":
			return tr_text(lang, "Extinción", "Extinction")
	return event_type


static func get_divergence_reason_label(reason: String, lang: String = "es") -> String:
	match reason:
		"initial":
			return tr_text(lang, "Ancestral", "Ancestral")
		"allopatric_speciation":
			return tr_text(lang, "Especiación Alopátrica", "Allopatric Speciation")
		"baldwin_assimilation":
			return tr_text(lang, "Asimilación Baldwin", "Baldwin Assimilation")
		"cultural_schism":
			return tr_text(lang, "Cisma Cultural", "Cultural Schism")
	return reason


static func get_biome_label(biome: String, lang: String = "es") -> String:
	match biome:
		"tropical_forest":
			return tr_text(lang, "Bosque Tropical", "Tropical Forest")
		"savanna":
			return tr_text(lang, "Sabana", "Savanna")
		"arid_steppe":
			return tr_text(lang, "Estepa Árida", "Arid Steppe")
		"tundra":
			return tr_text(lang, "Tundra", "Tundra")
		"high_mountain":
			return tr_text(lang, "Alta Montaña", "High Mountain")
		"coastal_shallows":
			return tr_text(lang, "Bajíos Costeros", "Coastal Shallows")
		"ocean":
			return tr_text(lang, "Océano", "Ocean")
	return biome


static func get_biome_color(biome: String) -> Color:
	match biome:
		"tropical_forest":
			return Color("#10b981")
		"savanna":
			return Color("#f59e0b")
		"arid_steppe":
			return Color("#d97706")
		"tundra":
			return Color("#94a3b8")
		"high_mountain":
			return Color("#78716c")
		"coastal_shallows":
			return Color("#2dd4bf")
		"ocean":
			return Color("#1e3a8a")
	return COLOR_SEPIA


static func get_archetype_label(archetype: String, lang: String = "es") -> String:
	match archetype:
		"forage":
			return tr_text(lang, "Recolección (forage)", "Foraging (forage)")
		"overexploit":
			return tr_text(lang, "Sobreexplotación (overexploit)", "Overexploitation (overexploit)")
		"migrate":
			return tr_text(lang, "Migración (migrate)", "Migration (migrate)")
		"cooperate":
			return tr_text(lang, "Cooperación (cooperate)", "Cooperation (cooperate)")
		"exchange":
			return tr_text(lang, "Intercambio / Simbiosis (exchange)", "Exchange / Symbiosis (exchange)")
		"dispute":
			return tr_text(lang, "Disputa Territorial (dispute)", "Territorial Dispute (dispute)")
		"innovate":
			return tr_text(lang, "Exploración / Innovación (innovate)", "Exploration / Innovation (innovate)")
		"custom":
			return tr_text(lang, "Personalizado (custom)", "Custom (custom)")
	return archetype


static func get_decision_icon_key(decision_id: String, state: EvoTypes.WorldState) -> String:
	var arch := "forage"
	if state != null and state.decisions_catalog.has(decision_id):
		arch = (state.decisions_catalog[decision_id] as EvoTypes.DecisionDef).archetype
	elif "cooperate" in decision_id:
		arch = "cooperate"
	elif "migrate" in decision_id or "migration" in decision_id:
		arch = "migrate"
	elif "exchange" in decision_id or "symbiosis" in decision_id:
		arch = "exchange"
	elif "dispute" in decision_id:
		arch = "dispute"
	elif "overexploit" in decision_id:
		arch = "overexploit"
	elif "innovate" in decision_id:
		arch = "innovate"
	return "icon_" + arch


static func get_vital_status_label(status: String, lang: String = "es") -> String:
	match status:
		"thriving":
			return tr_text(lang, "Prosperando", "Thriving")
		"stable":
			return tr_text(lang, "Estable", "Stable")
		"struggling":
			return tr_text(lang, "En apuros", "Struggling")
		"starving":
			return tr_text(lang, "Hambruna", "Starving")
	return status


static func get_vital_status_heart(status: String) -> String:
	match status:
		"thriving":
			return "💚"
		"stable":
			return "💙"
		"struggling":
			return "💛"
		"starving":
			return "❤️‍🩹"
	return "💚"


static func get_vital_status_color(status: String) -> Color:
	match status:
		"thriving":
			return Color("#16a34a")
		"stable":
			return Color("#0284c7")
		"struggling":
			return Color("#d97706")
		"starving":
			return Color("#dc2626")
	return COLOR_SEPIA


static func get_village_tier_label(population: int, lang: String = "es") -> String:
	if population >= 400:
		return tr_text(lang, "IV · Poblado", "IV · Settlement")
	if population >= 150:
		return tr_text(lang, "III · Aldea", "III · Village")
	if population >= 50:
		return tr_text(lang, "II · Caserío", "II · Hamlet")
	return tr_text(lang, "I · Campamento", "I · Camp")


static func evaluate_thermodynamics(vec: EvoTypes.BiophysicalVector, free_sandbox: bool = false) -> Dictionary:
	var metrics := EvoThermodynamics.evaluate_thermodynamics(vec)
	var is_balanced: bool = free_sandbox or bool(metrics["is_balanced"])
	var balanced_vec := EvoThermodynamics.validate_and_balance_thermodynamics(vec, free_sandbox)
	return {
		"a_plus": metrics["positive_advantages"],
		"c_actual": metrics["current_cost"],
		"c_req": metrics["required_cost"],
		"is_balanced": is_balanced,
		"balanced_vector": balanced_vec
	}


static func balance_vector(vec: EvoTypes.BiophysicalVector) -> EvoTypes.BiophysicalVector:
	return EvoThermodynamics.validate_and_balance_thermodynamics(vec, false)


static func get_pixel_icon(icon_key: String) -> ImageTexture:
	if _icon_cache.has(icon_key):
		return _icon_cache[icon_key]

	var sprite_map := {
		"inspect": "tool_inspect",
		"slot_inspect": "tool_inspect",
		"set_biome": "tool_biome",
		"adjust_altitude": "tool_altitude",
		"adjust_carrying_capacity": "tool_fertility",
		"sea_level": "tool_sealevel",
		"slot_sealevel": "tool_sealevel",
		"season_wet": "season_wet",
		"season_dry": "season_dry",
		"tropical_forest": "tree_tropical",
		"slot_tropical": "tree_tropical",
		"savanna": "tree_savanna",
		"slot_savanna": "tree_savanna",
		"arid_steppe": "bush_arid",
		"slot_arid": "bush_arid",
		"tundra": "tree_tundra",
		"slot_tundra": "tree_tundra",
		"high_mountain": "rock_mountain",
		"coastal_shallows": "coastal_reeds",
		"status_thriving": "status_thriving",
		"status_stable": "status_stable",
		"status_struggling": "status_struggling",
		"status_starving": "status_starving",
		"icon_forage": "icon_forage",
		"icon_overexploit": "icon_overexploit",
		"icon_migrate": "icon_migrate",
		"icon_cooperate": "icon_cooperate",
		"icon_exchange": "icon_exchange",
		"icon_dispute": "icon_dispute",
		"icon_innovate": "icon_innovate",
		"icon_custom": "icon_custom"
	}
	if sprite_map.has(icon_key):
		var tex_from_gen := EvoPixelArtGen.get_texture(str(sprite_map[icon_key]))
		if tex_from_gen != null:
			_icon_cache[icon_key] = tex_from_gen
			return tex_from_gen

	var img := _draw_custom_ui_pixel_icon(icon_key)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[icon_key] = tex
	return tex


static func _draw_custom_ui_pixel_icon(icon_key: String) -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline := Color("#2b1608")

	match icon_key:
		"slot_raise":
			# Mountain chisel & upward golden arrow
			for y in range(7, 17):
				var hw := int((y - 6) * 0.65)
				for dx in range(-hw, hw + 1):
					img.set_pixel(10 + dx, y, Color("#a8a29e") if dx <= 0 else Color("#57534e"))
			for dx in range(-3, 4):
				img.set_pixel(10 + dx, 4 + abs(dx), Color("#f59e0b"))
				img.set_pixel(10 + dx, 5 + abs(dx), Color("#fde047"))
		"slot_lower":
			# Pickaxe & downward valley cut
			for i in range(4, 15):
				img.set_pixel(i, i, Color("#8c5230"))
				img.set_pixel(min(19, i + 1), i, Color("#6b3e26"))
			for d in range(-4, 5):
				var px := clampi(7 - d, 2, 17)
				var py := clampi(7 + d, 2, 17)
				img.set_pixel(px, py, Color("#cbd5e1"))
				img.set_pixel(px, min(19, py + 1), Color("#64748b"))
		"slot_enrich":
			# Golden Stardew watering can + water drops
			for y in range(8, 16):
				for x in range(6, 15):
					img.set_pixel(x, y, Color("#fbbf24") if y < 12 else Color("#d97706"))
			for i in range(4):
				img.set_pixel(15 + i, 10 - i, Color("#f59e0b"))
			img.set_pixel(17, 13, Color("#38bdf8"))
			img.set_pixel(15, 15, Color("#38bdf8"))
			img.set_pixel(4, 10, Color("#b45309"))
			img.set_pixel(4, 11, Color("#b45309"))
		"slot_deplete":
			# Drought sickle + amber flame
			for angle_i in range(12):
				var ang := float(angle_i) * 0.25
				var rx := clampi(int(10.0 + cos(ang) * 5.0), 2, 17)
				var ry := clampi(int(9.0 - sin(ang) * 5.0), 2, 17)
				img.set_pixel(rx, ry, Color("#f97316"))
				img.set_pixel(rx, min(19, ry + 1), Color("#dc2626"))
			for y in range(11, 17):
				img.set_pixel(8, y, Color("#78350f"))
				img.set_pixel(9, y, Color("#92400e"))
		_:
			var primary := Color("#3b82f6") if icon_key == "ocean" else COLOR_GOLD_BEVEL
			var accent := Color("#1e3a8a") if icon_key == "ocean" else COLOR_PARCHMENT
			for y in range(3, 17):
				for x in range(3, 17):
					var dist := Vector2(x - 9.5, y - 9.5).length()
					if dist <= 6.5:
						if dist >= 5.3:
							img.set_pixel(x, y, outline)
						elif (x + y) % 3 == 0:
							img.set_pixel(x, y, accent)
						else:
							img.set_pixel(x, y, primary)
	return img
