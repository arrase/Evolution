class_name EvoLabStrategyEditor
extends RefCounted


static func build_strategy_form(modal: Control, form_vbox: VBoxContainer) -> void:
	modal._strategy_emblem_row = HBoxContainer.new()
	modal._strategy_emblem_row.add_theme_constant_override("separation", 10)
	form_vbox.add_child(modal._strategy_emblem_row)

	modal._strategy_icon_lbl = Label.new()
	modal._strategy_icon_lbl.custom_minimum_size = Vector2(110, 0)
	modal._strategy_emblem_row.add_child(modal._strategy_icon_lbl)

	modal.strategy_icon_option = OptionButton.new()
	modal.strategy_icon_option.custom_minimum_size = Vector2(90, 0)
	for i in range(modal.STRATEGY_ICONS.size()):
		modal.strategy_icon_option.add_item(modal.STRATEGY_ICONS[i], i)
		modal.strategy_icon_option.set_item_metadata(i, modal.STRATEGY_ICONS[i])
	modal._strategy_emblem_row.add_child(modal.strategy_icon_option)

	modal._strategy_color_lbl = Label.new()
	modal._strategy_emblem_row.add_child(modal._strategy_color_lbl)

	modal.strategy_color_picker = ColorPickerButton.new()
	modal.strategy_color_picker.custom_minimum_size = Vector2(56, 28)
	modal.strategy_color_picker.edit_alpha = false
	modal.strategy_color_picker.color = Color("#10B981")
	modal._strategy_emblem_row.add_child(modal.strategy_color_picker)

	for swatch_hex in modal.STRATEGY_SWATCH_COLORS:
		var swatch_btn := Button.new()
		swatch_btn.custom_minimum_size = Vector2(22, 22)
		var col := Color(swatch_hex)
		swatch_btn.add_theme_stylebox_override("normal", EvoUiStyle.make_button_style(col, col.darkened(0.35), 1, 2, 2))
		swatch_btn.add_theme_stylebox_override("hover", EvoUiStyle.make_button_style(col.lightened(0.15), EvoUiStyle.COLOR_GOLD_BRIGHT, 2, 2, 2))
		swatch_btn.pressed.connect(func() -> void: modal.strategy_color_picker.color = col)
		modal._strategy_emblem_row.add_child(swatch_btn)

	modal._strategy_traits_card = PanelContainer.new()
	modal._strategy_traits_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#fbf2de"), EvoUiStyle.COLOR_PARCHMENT_BORDER, 10))
	form_vbox.add_child(modal._strategy_traits_card)

	var strat_traits_outer := VBoxContainer.new()
	strat_traits_outer.add_theme_constant_override("separation", 6)
	modal._strategy_traits_card.add_child(strat_traits_outer)

	modal._strategy_traits_title_lbl = Label.new()
	modal._strategy_traits_title_lbl.add_theme_font_size_override("font_size", 14)
	modal._strategy_traits_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	strat_traits_outer.add_child(modal._strategy_traits_title_lbl)

	modal.strategy_traits_box = VBoxContainer.new()
	modal.strategy_traits_box.add_theme_constant_override("separation", 4)
	strat_traits_outer.add_child(modal.strategy_traits_box)

	modal._strategy_vector_card = PanelContainer.new()
	modal._strategy_vector_card.add_theme_stylebox_override("panel", EvoUiStyle.make_parchment_card(Color("#f4e2b8"), EvoUiStyle.COLOR_GOLD_BEVEL, 10))
	form_vbox.add_child(modal._strategy_vector_card)

	var strat_vec_vbox := VBoxContainer.new()
	strat_vec_vbox.add_theme_constant_override("separation", 4)
	modal._strategy_vector_card.add_child(strat_vec_vbox)

	modal._strategy_vector_title_lbl = Label.new()
	modal._strategy_vector_title_lbl.add_theme_font_size_override("font_size", 14)
	modal._strategy_vector_title_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	strat_vec_vbox.add_child(modal._strategy_vector_title_lbl)

	modal.strategy_vector_label = Label.new()
	modal.strategy_vector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.strategy_vector_label.add_theme_font_size_override("font_size", 12)
	modal.strategy_vector_label.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	strat_vec_vbox.add_child(modal.strategy_vector_label)


static func build_matchup_and_inject_rows(modal: Control, form_vbox: VBoxContainer) -> void:
	modal._strategy_matchup_row = HBoxContainer.new()
	modal._strategy_matchup_row.add_theme_constant_override("separation", 10)
	form_vbox.add_child(modal._strategy_matchup_row)

	modal.use_strategy_a_button = Button.new()
	modal.use_strategy_a_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.use_strategy_a_button.pressed.connect(modal._on_use_strategy_slot_pressed.bind("a"))
	modal._strategy_matchup_row.add_child(modal.use_strategy_a_button)

	modal.use_strategy_b_button = Button.new()
	modal.use_strategy_b_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.use_strategy_b_button.pressed.connect(modal._on_use_strategy_slot_pressed.bind("b"))
	modal._strategy_matchup_row.add_child(modal.use_strategy_b_button)

	modal._inject_row = HBoxContainer.new()
	modal._inject_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(modal._inject_row)

	modal._inject_deme_lbl = Label.new()
	modal._inject_row.add_child(modal._inject_deme_lbl)

	modal.inject_deme_option = OptionButton.new()
	modal.inject_deme_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.inject_deme_option.item_selected.connect(modal._on_inject_deme_option_selected)
	modal._inject_row.add_child(modal.inject_deme_option)

	modal.inject_button = Button.new()
	modal.inject_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.inject_button.pressed.connect(modal._on_inject_pressed)
	modal._inject_row.add_child(modal.inject_button)


static func init_new_strategy(modal: Control) -> void:
	modal.id_edit.text = modal._next_custom_id("strat")
	modal.name_edit.text = EvoUiStyle.tr_text(modal._lang, "Estrategia Personalizada", "Custom Strategy")
	modal.desc_edit.text = EvoUiStyle.tr_text(
		modal._lang,
		"Doctrina bio-cultural diseñada en el laboratorio para el duelo de estrategias.",
		"Bio-cultural doctrine crafted in the laboratory for the strategy duel."
	)
	select_strategy_icon(modal, "🛡️")
	modal.strategy_color_picker.color = Color("#10B981")
	rebuild_strategy_trait_checks(modal)
	set_checked_strategy_trait_ids(modal, ["bio-k-strategy", "bio-social-instinct", "cul-communal-conservation"])


static func save_strategy(modal: Control, clean_name: String, clean_desc: String) -> void:
	var strat := build_strategy_from_form(modal)
	strat.name = clean_name
	strat.description = clean_desc
	strat.origin = "user"
	if modal._world_state != null:
		modal._world_state.strategies_catalog[strat.id] = strat
		EvoUserSettings.save_user_catalog(modal._world_state)
	modal._selected_id = strat.id
	modal.id_edit.text = strat.id
	modal.strategy_saved.emit(strat.id)
	modal.catalog_item_saved.emit("strategy", strat.to_dict())
	modal._rebuild_catalog_list()
	modal._update_labels()
	update_strategy_vector_preview(modal)
	modal._show_saved_feedback(strat.id)


static func refresh_strategy_and_inject_labels(modal: Control, is_strat: bool) -> void:
	modal._strategy_icon_lbl.text = EvoI18n.t(modal._lang, "lab_strat_icon") + ":"
	modal._strategy_color_lbl.text = EvoI18n.t(modal._lang, "lab_strat_color") + ":"
	modal._strategy_traits_title_lbl.text = EvoI18n.t(modal._lang, "lab_strat_traits")
	modal._strategy_vector_title_lbl.text = EvoI18n.t(modal._lang, "lab_strat_vector")
	modal.use_strategy_a_button.text = EvoI18n.t(modal._lang, "lab_use_strat_a")
	modal.use_strategy_b_button.text = EvoI18n.t(modal._lang, "lab_use_strat_b")

	modal._strategy_emblem_row.visible = is_strat
	modal._strategy_traits_card.visible = is_strat
	modal._strategy_vector_card.visible = is_strat
	modal._strategy_matchup_row.visible = is_strat
	modal._inject_row.visible = (modal._current_tab in ["biological", "cultural"])

	modal._inject_deme_lbl.text = EvoUiStyle.tr_text(modal._lang, "Aldea:", "Village:")
	modal.inject_button.text = EvoUiStyle.tr_text(modal._lang, "💉 Inyectar en Aldea", "💉 Inject into Village")
	modal.inject_button.disabled = (
		modal._selected_deme_id == ""
		or modal._world_state == null
		or not modal._world_state.demes.has(modal._selected_deme_id)
	)


static func rebuild_strategy_trait_checks(modal: Control) -> void:
	if modal.strategy_traits_box == null:
		return
	for child in modal.strategy_traits_box.get_children():
		child.queue_free()
	modal.strategy_trait_checks.clear()

	var traits_cat: Dictionary = modal._world_state.traits_catalog if modal._world_state != null else EvoCatalog.create_base_traits_catalog(modal._lang)

	var bio_hdr := Label.new()
	bio_hdr.text = "🧬 " + EvoI18n.t(modal._lang, "panel.traits_bio")
	bio_hdr.add_theme_font_size_override("font_size", 13)
	bio_hdr.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	modal.strategy_traits_box.add_child(bio_hdr)

	for tid in traits_cat.keys():
		var t: EvoTypes.TraitDef = traits_cat[tid]
		if t.category != "biological":
			continue
		var cb := make_strategy_trait_checkbox(modal, t)
		modal.strategy_trait_checks[t.id] = cb
		modal.strategy_traits_box.add_child(cb)

	var cul_hdr := Label.new()
	cul_hdr.text = "🔥 " + EvoI18n.t(modal._lang, "panel.traits_cul")
	cul_hdr.add_theme_font_size_override("font_size", 13)
	cul_hdr.add_theme_color_override("font_color", EvoUiStyle.COLOR_PURPLE_CULTURE)
	modal.strategy_traits_box.add_child(cul_hdr)

	for tid in traits_cat.keys():
		var t: EvoTypes.TraitDef = traits_cat[tid]
		if t.category != "cultural":
			continue
		var cb := make_strategy_trait_checkbox(modal, t)
		modal.strategy_trait_checks[t.id] = cb
		modal.strategy_traits_box.add_child(cb)


static func make_strategy_trait_checkbox(modal: Control, t: EvoTypes.TraitDef) -> CheckBox:
	var cb := CheckBox.new()
	var t_name := EvoI18n.trait_name(modal._lang, t)
	var summary := format_trait_vector_summary(t.vector)
	var culture_tag := ""
	if t.enables_cultural_transmission:
		culture_tag = " [★ Cultura]" if modal._lang != "en" else " [★ Culture]"
	cb.text = "%s%s  (%s)" % [t_name, culture_tag, summary]
	cb.tooltip_text = EvoI18n.trait_description(modal._lang, t)
	cb.toggled.connect(modal._on_strategy_trait_toggled.bind(t.id))
	return cb


static func format_trait_vector_summary(v: EvoTypes.BiophysicalVector) -> String:
	var parts: Array[String] = []
	if not is_zero_approx(v.metabolic_cost):
		parts.append("Cost %+.2f" % v.metabolic_cost)
	if not is_zero_approx(v.extraction_efficiency):
		parts.append("Ext %+.2f" % v.extraction_efficiency)
	if not is_zero_approx(v.ecological_impact):
		parts.append("Eco %+.2f" % v.ecological_impact)
	if not is_zero_approx(v.spatial_mobility):
		parts.append("Mob %+.2f" % v.spatial_mobility)
	if not is_zero_approx(v.social_cohesion):
		parts.append("Soc %+.2f" % v.social_cohesion)
	return ", ".join(parts) if not parts.is_empty() else "0.00"


static func on_strategy_trait_toggled(modal: Control, is_checked: bool, trait_id: String) -> void:
	if modal._updating_strategy_checks:
		return
	var traits_cat: Dictionary = modal._world_state.traits_catalog if modal._world_state != null else {}
	modal._updating_strategy_checks = true

	if is_checked:
		if trait_id == "bio-r-strategy" and modal.strategy_trait_checks.has("bio-k-strategy"):
			(modal.strategy_trait_checks["bio-k-strategy"] as CheckBox).button_pressed = false
		elif trait_id == "bio-k-strategy" and modal.strategy_trait_checks.has("bio-r-strategy"):
			(modal.strategy_trait_checks["bio-r-strategy"] as CheckBox).button_pressed = false

		if traits_cat.has(trait_id):
			var tr: EvoTypes.TraitDef = traits_cat[trait_id]
			for ex_id in tr.mutually_exclusive_with:
				if modal.strategy_trait_checks.has(ex_id):
					(modal.strategy_trait_checks[ex_id] as CheckBox).button_pressed = false
			for other_id in traits_cat.keys():
				var other_tr: EvoTypes.TraitDef = traits_cat[other_id]
				if other_tr.mutually_exclusive_with.has(trait_id) and modal.strategy_trait_checks.has(other_id):
					(modal.strategy_trait_checks[other_id] as CheckBox).button_pressed = false

			if tr.category == "cultural" and not has_checked_cultural_capacity(modal, traits_cat):
				var enabled_any := false
				for bid in ["bio-social-instinct", "bio-encephalization"]:
					if modal.strategy_trait_checks.has(bid):
						var can_enable := not traits_cat.has(bid) or (traits_cat[bid] as EvoTypes.TraitDef).enables_cultural_transmission
						if can_enable:
							(modal.strategy_trait_checks[bid] as CheckBox).button_pressed = true
							enabled_any = true
							break
				if not enabled_any:
					for bid in traits_cat.keys():
						var btr: EvoTypes.TraitDef = traits_cat[bid]
						if btr.category == "biological" and btr.enables_cultural_transmission and modal.strategy_trait_checks.has(bid):
							(modal.strategy_trait_checks[bid] as CheckBox).button_pressed = true
							break
	else:
		var is_culture_enabler := false
		if traits_cat.has(trait_id):
			var tr: EvoTypes.TraitDef = traits_cat[trait_id]
			is_culture_enabler = (tr.category == "biological" and tr.enables_cultural_transmission)
		else:
			is_culture_enabler = trait_id in ["bio-social-instinct", "bio-encephalization"]
		if is_culture_enabler and not has_checked_cultural_capacity(modal, traits_cat):
			for cid in modal.strategy_trait_checks.keys():
				var is_cul := str(cid).begins_with("cul-")
				if traits_cat.has(cid):
					is_cul = (traits_cat[cid] as EvoTypes.TraitDef).category == "cultural"
				if is_cul:
					(modal.strategy_trait_checks[cid] as CheckBox).button_pressed = false

	modal._updating_strategy_checks = false
	update_strategy_vector_preview(modal)


static func has_checked_cultural_capacity(modal: Control, traits_cat: Dictionary) -> bool:
	for tid in modal.strategy_trait_checks.keys():
		var cb: CheckBox = modal.strategy_trait_checks[tid]
		if not cb.button_pressed:
			continue
		if traits_cat.has(tid):
			var tr: EvoTypes.TraitDef = traits_cat[tid]
			if tr.category == "biological" and tr.enables_cultural_transmission:
				return true
		elif tid in ["bio-social-instinct", "bio-encephalization"]:
			return true
	return false


static func get_checked_strategy_trait_ids(modal: Control) -> Array[String]:
	var res: Array[String] = []
	for tid in modal.strategy_trait_checks.keys():
		if (modal.strategy_trait_checks[tid] as CheckBox).button_pressed:
			res.append(str(tid))
	return res


static func set_checked_strategy_trait_ids(modal: Control, trait_ids: Array) -> void:
	modal._updating_strategy_checks = true
	for tid in modal.strategy_trait_checks.keys():
		(modal.strategy_trait_checks[tid] as CheckBox).button_pressed = trait_ids.has(tid)
	modal._updating_strategy_checks = false
	update_strategy_vector_preview(modal)


static func are_traits_mutually_exclusive(tid_a: String, tid_b: String, traits_cat: Dictionary) -> bool:
	if (tid_a == "bio-r-strategy" and tid_b == "bio-k-strategy") or (tid_a == "bio-k-strategy" and tid_b == "bio-r-strategy"):
		return true
	if traits_cat.has(tid_a) and (traits_cat[tid_a] as EvoTypes.TraitDef).mutually_exclusive_with.has(tid_b):
		return true
	if traits_cat.has(tid_b) and (traits_cat[tid_b] as EvoTypes.TraitDef).mutually_exclusive_with.has(tid_a):
		return true
	return false


static func build_strategy_from_form(modal: Control) -> EvoTypes.StrategyDef:
	var strat := EvoTypes.StrategyDef.new()
	strat.id = modal._resolve_target_id("strat")
	strat.name = modal.name_edit.text.strip_edges()
	if strat.name == "":
		strat.name = "Custom Strategy"
	strat.description = modal.desc_edit.text.strip_edges()
	strat.icon = get_selected_strategy_icon(modal)
	strat.color = "#" + modal.strategy_color_picker.color.to_html(false).to_upper()

	var traits_cat: Dictionary = modal._world_state.traits_catalog if modal._world_state != null else {}
	var bio_ids: Array[String] = []
	var cul_ids: Array[String] = []
	var accepted_ids: Array[String] = []
	for tid_var in modal.strategy_trait_checks.keys():
		var tid := str(tid_var)
		var cb: CheckBox = modal.strategy_trait_checks[tid_var]
		if not cb.button_pressed:
			continue
		var has_conflict := false
		for kept_id in accepted_ids:
			if are_traits_mutually_exclusive(tid, kept_id, traits_cat):
				has_conflict = true
				break
		if has_conflict:
			continue
		accepted_ids.append(tid)
		var is_cul := tid.begins_with("cul-")
		if traits_cat.has(tid):
			is_cul = (traits_cat[tid] as EvoTypes.TraitDef).category == "cultural"
		if is_cul:
			cul_ids.append(tid)
		else:
			bio_ids.append(tid)

	if not cul_ids.is_empty():
		var has_cap := false
		for bid in bio_ids:
			if traits_cat.has(bid):
				if (traits_cat[bid] as EvoTypes.TraitDef).enables_cultural_transmission:
					has_cap = true
					break
			elif bid in ["bio-social-instinct", "bio-encephalization"]:
				has_cap = true
				break
		if not has_cap:
			var fallback_bio := ""
			for cand in ["bio-social-instinct", "bio-encephalization"]:
				if not traits_cat.has(cand) or (traits_cat[cand] as EvoTypes.TraitDef).enables_cultural_transmission:
					fallback_bio = cand
					break
			if fallback_bio == "":
				for tid in traits_cat.keys():
					var t: EvoTypes.TraitDef = traits_cat[tid]
					if t.category == "biological" and t.enables_cultural_transmission:
						fallback_bio = t.id
						break
			if fallback_bio != "" and not bio_ids.has(fallback_bio):
				bio_ids.append(fallback_bio)
			elif fallback_bio == "":
				cul_ids.clear()

	strat.biological_trait_ids = bio_ids
	strat.cultural_trait_ids = cul_ids
	return strat


static func update_strategy_vector_preview(modal: Control) -> void:
	if modal.strategy_vector_label == null:
		return
	var temp_strat := build_strategy_from_form(modal)
	var traits_cat: Dictionary = modal._world_state.traits_catalog if modal._world_state != null else EvoCatalog.create_base_traits_catalog(modal._lang)
	var vec := EvoCatalog.compute_strategy_vector(temp_strat, traits_cat)
	modal.strategy_vector_label.text = (
		"%s: %+.2f   |   %s: %+.2f   |   %s: %+.2f\n%s: %+.2f   |   %s: %+.2f   |   %s: %.2f" % [
			EvoI18n.t(modal._lang, "axis.metabolic_cost"), vec.metabolic_cost,
			EvoI18n.t(modal._lang, "axis.extraction_efficiency"), vec.extraction_efficiency,
			EvoI18n.t(modal._lang, "axis.ecological_impact"), vec.ecological_impact,
			EvoI18n.t(modal._lang, "axis.spatial_mobility"), vec.spatial_mobility,
			EvoI18n.t(modal._lang, "axis.social_cohesion"), vec.social_cohesion,
			EvoI18n.t(modal._lang, "axis.transmission_threshold"), vec.transmission_threshold
		]
	)


static func select_strategy_icon(modal: Control, icon: String) -> void:
	if modal.strategy_icon_option == null:
		return
	for i in range(modal.strategy_icon_option.item_count):
		if modal.strategy_icon_option.get_item_text(i) == icon:
			modal.strategy_icon_option.select(i)
			return
	if modal.strategy_icon_option.item_count > 0:
		modal.strategy_icon_option.select(0)


static func get_selected_strategy_icon(modal: Control) -> String:
	if modal.strategy_icon_option == null:
		return "🛡️"
	var idx: int = modal.strategy_icon_option.selected
	if idx >= 0 and idx < modal.strategy_icon_option.item_count:
		return modal.strategy_icon_option.get_item_text(idx)
	return "🛡️"


static func is_strategy_form_dirty(modal: Control, existing: EvoTypes.StrategyDef) -> bool:
	var form_strat := build_strategy_from_form(modal)
	if form_strat.id != existing.id or form_strat.name != existing.name or form_strat.description != existing.description:
		return true
	if form_strat.icon != existing.icon or form_strat.color.to_upper() != existing.color.to_upper():
		return true
	if form_strat.biological_trait_ids != existing.biological_trait_ids or form_strat.cultural_trait_ids != existing.cultural_trait_ids:
		return true
	return false


static func on_use_strategy_slot_pressed(modal: Control, slot: String) -> void:
	if modal._current_tab != "strategy":
		return
	var target_id: String = modal.id_edit.text.strip_edges()
	if target_id == "":
		target_id = modal._selected_id
	if target_id == "" or modal._world_state == null or not modal._world_state.strategies_catalog.has(target_id) or is_strategy_form_dirty(modal, modal._world_state.strategies_catalog[target_id]):
		modal._save_current_item()
	if modal._world_state != null:
		if slot == "a":
			modal._world_state.strategy_a_id = modal._selected_id
		elif slot == "b":
			modal._world_state.strategy_b_id = modal._selected_id
	modal.strategy_assigned.emit(slot, modal._selected_id)
	modal._feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	modal._feedback_lbl.text = "%s: %s" % [
		EvoI18n.t(modal._lang, "lab_use_strat_a" if slot == "a" else "lab_use_strat_b"),
		modal._selected_id
	]


static func on_catalog_strategy_clicked(modal: Control, strategy_id: String) -> void:
	if modal._world_state == null or not modal._world_state.strategies_catalog.has(strategy_id):
		return
	var strat: EvoTypes.StrategyDef = modal._world_state.strategies_catalog[strategy_id]
	modal._selected_id = strat.id
	modal.id_edit.text = strat.id
	modal.name_edit.text = EvoI18n.strategy_name(modal._lang, strat)
	modal.desc_edit.text = EvoI18n.strategy_description(modal._lang, strat)
	select_strategy_icon(modal, strat.icon)
	modal.strategy_color_picker.color = Color.from_string(strat.color, Color("#10B981"))

	var combined_traits: Array[String] = []
	for bid in strat.biological_trait_ids:
		combined_traits.append(bid)
	for cid in strat.cultural_trait_ids:
		combined_traits.append(cid)
	set_checked_strategy_trait_ids(modal, combined_traits)

	modal._feedback_lbl.text = ""
	modal._update_labels()
	modal._rebuild_catalog_list()
	update_strategy_vector_preview(modal)


static func rebuild_inject_deme_options(modal: Control) -> void:
	if modal.inject_deme_option == null:
		return
	modal.inject_deme_option.clear()
	if modal._world_state == null or modal._world_state.demes.is_empty():
		return
	var idx := 0
	var selected_idx := 0
	for did in modal._world_state.demes.keys():
		var d: EvoTypes.Deme = modal._world_state.demes[did]
		modal.inject_deme_option.add_item(d.name, idx)
		modal.inject_deme_option.set_item_metadata(idx, d.id)
		if d.id == modal._selected_deme_id:
			selected_idx = idx
		idx += 1
	modal.inject_deme_option.select(selected_idx)
	modal._selected_deme_id = str(modal.inject_deme_option.get_item_metadata(selected_idx))


static func on_inject_deme_option_selected(modal: Control, index: int) -> void:
	if modal.inject_deme_option == null or index < 0 or index >= modal.inject_deme_option.item_count:
		return
	modal._selected_deme_id = str(modal.inject_deme_option.get_item_metadata(index))
	modal._update_labels()


static func is_selected_builtin_trait_unmodified(modal: Control) -> bool:
	if modal._world_state == null or modal._selected_id == "" or not modal._world_state.traits_catalog.has(modal._selected_id):
		return false
	var existing: EvoTypes.TraitDef = modal._world_state.traits_catalog[modal._selected_id]
	if existing.origin not in ["catalog", "base"]:
		return false
	var target_id: String = modal.id_edit.text.strip_edges()
	if target_id != "" and target_id != existing.id:
		return false
	var clean_name: String = modal.name_edit.text.strip_edges()
	if clean_name != EvoI18n.trait_name(modal._lang, existing).strip_edges() and clean_name != existing.name.strip_edges():
		return false
	var clean_desc: String = modal.desc_edit.text.strip_edges()
	if clean_desc != EvoI18n.trait_description(modal._lang, existing).strip_edges() and clean_desc != existing.description.strip_edges():
		return false
	if modal._current_tab == "biological" and modal.enables_culture_check.button_pressed != existing.enables_cultural_transmission:
		return false
	var form_vec: EvoTypes.BiophysicalVector = modal._read_vector_from_sliders()
	var ex_vec := existing.vector
	return (
		is_equal_approx(form_vec.metabolic_cost, snappedf(ex_vec.metabolic_cost, 0.01))
		and is_equal_approx(form_vec.extraction_efficiency, snappedf(ex_vec.extraction_efficiency, 0.01))
		and is_equal_approx(form_vec.ecological_impact, snappedf(ex_vec.ecological_impact, 0.01))
		and is_equal_approx(form_vec.spatial_mobility, snappedf(ex_vec.spatial_mobility, 0.01))
		and is_equal_approx(form_vec.social_cohesion, snappedf(ex_vec.social_cohesion, 0.01))
		and is_equal_approx(form_vec.transmission_threshold, snappedf(ex_vec.transmission_threshold, 0.01))
	)


static func on_inject_pressed(modal: Control) -> void:
	if modal._current_tab not in ["biological", "cultural"] or modal._selected_deme_id == "":
		return
	if modal._current_tab == "cultural" and modal._world_state != null and modal._world_state.demes.has(modal._selected_deme_id):
		var target_deme: EvoTypes.Deme = modal._world_state.demes[modal._selected_deme_id]
		if not EvoCatalog.deme_has_cultural_capacity(target_deme, modal._world_state.traits_catalog):
			modal._feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GOLD_WARN)
			modal._feedback_lbl.text = EvoUiStyle.tr_text(
				modal._lang,
				"⚠ La aldea seleccionada carece de capacidad cultural (requiere Encefalización o Sociabilidad Instintiva).",
				"⚠ Selected village lacks cultural capacity (requires Encephalization or Instinctive Sociability)."
			)
			return
	if not is_selected_builtin_trait_unmodified(modal):
		modal._save_current_item()
	modal._feedback_lbl.add_theme_color_override("font_color", EvoUiStyle.COLOR_GREEN_OK)
	modal.inject_trait_requested.emit(modal._selected_deme_id, modal._selected_id)
	modal._update_labels()
	modal._feedback_lbl.text = EvoUiStyle.tr_text(
		modal._lang,
		"💉 Rasgo '%s' inyectado en la aldea seleccionada." % modal.name_edit.text,
		"💉 Trait '%s' injected into selected village." % modal.name_edit.text
	)
