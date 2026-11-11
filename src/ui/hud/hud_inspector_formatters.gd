class_name EvoHudInspectorFormatters
extends RefCounted


static func resolve_deme_strategy_icon(state: EvoTypes.WorldState, d: EvoTypes.Deme) -> String:
	var strat_id := d.strategy_id
	if strat_id == "" and state.lineage_tree.has(d.lineage_id):
		strat_id = (state.lineage_tree[d.lineage_id] as EvoTypes.LineageNode).strategy_id
	if state.strategies_catalog.has(strat_id):
		return (state.strategies_catalog[strat_id] as EvoTypes.StrategyDef).icon
	return "🛡️"


static func format_salubrity_status(d: EvoTypes.Deme, lang: String) -> Dictionary:
	var sal_pct := int(round(d.salubrity * 100.0))
	var sal_badge := EvoUiStyle.tr_text(lang, "✓ Sano", "✓ Healthy")
	var sal_col := EvoUiStyle.COLOR_GREEN_OK
	if d.infection_turns > 0:
		sal_badge = EvoUiStyle.tr_text(lang, "☣ Infectado (%dt)" % d.infection_turns, "☣ Infected (%dt)" % d.infection_turns)
		sal_col = EvoUiStyle.COLOR_RED_DANGER
	elif d.immunity_turns > 0:
		sal_badge = EvoUiStyle.tr_text(lang, "🛡️ Inmune (%dt)" % d.immunity_turns, "🛡️ Immune (%dt)" % d.immunity_turns)
		sal_col = Color("#06b6d4")
	elif d.salubrity < 0.40:
		sal_col = EvoUiStyle.COLOR_RED_DANGER
	elif d.salubrity < 0.75:
		sal_col = EvoUiStyle.COLOR_AMBER_WARN
	return {
		"right_text": "%d%% · %s" % [sal_pct, sal_badge],
		"pct": clampf(d.salubrity * 100.0, 0.0, 100.0),
		"color": sal_col
	}


static func format_food_intake_status(d: EvoTypes.Deme) -> Dictionary:
	var food_ratio := d.last_food_intake / maxf(1.0, d.last_food_need) if d.last_food_need > 0.0 else 1.0
	var food_pct := int(round(food_ratio * 100.0))
	var food_col := EvoUiStyle.COLOR_GREEN_OK if food_ratio >= 0.95 else (EvoUiStyle.COLOR_AMBER_WARN if food_ratio >= 0.70 else EvoUiStyle.COLOR_RED_DANGER)
	return {
		"right_text": "%.1f / %.1f (%d%%)" % [d.last_food_intake, d.last_food_need, food_pct],
		"pct": clampf(food_ratio * 100.0, 0.0, 1.0 * 100.0),
		"color": food_col
	}


static func populate_traits_sheet(hud: Control, d: EvoTypes.Deme) -> void:
	var mile_title := Label.new()
	mile_title.text = EvoUiStyle.tr_text(hud._lang, "⏳ Medidores de Hitos Evolutivos", "⏳ Evolutionary Milestone Meters")
	mile_title.add_theme_font_size_override("font_size", 12)
	mile_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._traits_sheet_vbox.add_child(mile_title)

	var max_baldwin := 0
	for b_k in d.baldwin_counters.keys():
		var cnt := int(d.baldwin_counters[b_k])
		if cnt > max_baldwin:
			max_baldwin = cnt
	add_milestone_bar(
		hud._traits_sheet_vbox,
		EvoUiStyle.tr_text(hud._lang, "Asimilación Genética (Baldwin)", "Genetic Assimilation (Baldwin)"),
		"%d / 8 gen" % max_baldwin,
		clampf(float(max_baldwin) / 8.0 * 100.0, 0.0, 100.0),
		Color("#0d9488")
	)

	var innov_pct := clampf(d.innovation_counter * 100.0, 0.0, 100.0)
	add_milestone_bar(
		hud._traits_sheet_vbox,
		EvoUiStyle.tr_text(hud._lang, "Innovación Cultural", "Cultural Innovation"),
		"%d%%" % int(round(innov_pct)),
		innov_pct,
		EvoUiStyle.COLOR_PURPLE_CULTURE
	)

	add_milestone_bar(
		hud._traits_sheet_vbox,
		EvoUiStyle.tr_text(hud._lang, "Aislamiento Alopátrico", "Allopatric Isolation"),
		"%d / 10 gen" % d.isolation_turns,
		clampf(float(d.isolation_turns) / 10.0 * 100.0, 0.0, 100.0),
		EvoUiStyle.COLOR_BLUE_INFO
	)

	var traits_title := Label.new()
	traits_title.text = EvoUiStyle.tr_text(hud._lang, "🧬 Medallones de Rasgos y Tradiciones", "🧬 Trait & Tradition Medallions")
	traits_title.add_theme_font_size_override("font_size", 12)
	traits_title.add_theme_color_override("font_color", EvoUiStyle.COLOR_WOOD_DARK)
	hud._traits_sheet_vbox.add_child(traits_title)

	var traits_flow := HFlowContainer.new()
	traits_flow.add_theme_constant_override("h_separation", 4)
	traits_flow.add_theme_constant_override("v_separation", 4)
	hud._traits_sheet_vbox.add_child(traits_flow)

	for t_id in d.biological_trait_ids:
		traits_flow.add_child(make_trait_tag(hud._world_state, t_id, false, hud._lang))
	for t_id in d.cultural_trait_ids:
		traits_flow.add_child(make_trait_tag(hud._world_state, t_id, true, hud._lang))

	var open_forge_btn := Button.new()
	open_forge_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_forge_btn.text = EvoUiStyle.tr_text(hud._lang, "⚗️ Abrir Forja / Inyectar Rasgo", "⚗️ Open Forge / Inject Trait")
	open_forge_btn.pressed.connect(hud.open_lab_modal)
	hud._traits_sheet_vbox.add_child(open_forge_btn)


static func populate_hex_metrics(hud: Control, cell: EvoTypes.HexCell) -> void:
	add_sheet_kv(hud._hex_sheet_vbox, EvoUiStyle.tr_text(hud._lang, "🌡️ Temperatura:", "🌡️ Temperature:"), "%+.2f" % cell.temperature)
	add_sheet_kv(hud._hex_sheet_vbox, EvoUiStyle.tr_text(hud._lang, "💧 Humedad:", "💧 Humidity:"), "%d%%" % int(round(cell.humidity * 100.0)))
	add_sheet_kv(hud._hex_sheet_vbox, EvoUiStyle.tr_text(hud._lang, "⛰️ Altitud:", "⛰️ Altitude:"), "%.2f" % cell.altitude)

	if cell.land_use in ["crops", "pasture"] and cell.owner_deme_id != "":
		var lu_label := EvoUiStyle.tr_text(hud._lang, "Tierras de cultivo", "Crop fields") if cell.land_use == "crops" else EvoUiStyle.tr_text(hud._lang, "Pastizales", "Pasturelands")
		var owner_label := cell.owner_deme_id
		if hud._world_state.demes.has(cell.owner_deme_id):
			var owner_deme: EvoTypes.Deme = hud._world_state.demes[cell.owner_deme_id]
			owner_label = format_short_deme_label(owner_deme)
		add_sheet_kv(
			hud._hex_sheet_vbox,
			EvoUiStyle.tr_text(hud._lang, "🚜 Uso del suelo:", "🚜 Land use:"),
			"%s · %s" % [lu_label, owner_label]
		)

	if cell.has_ruins:
		add_sheet_kv(
			hud._hex_sheet_vbox,
			EvoUiStyle.tr_text(hud._lang, "🏚️ Estado:", "🏚️ Status:"),
			EvoUiStyle.tr_text(hud._lang, "Ruinas", "Ruins")
		)

	var r_ratio := clampf(cell.current_resources / maxf(1.0, cell.carrying_capacity), 0.0, 1.0)
	add_milestone_bar(
		hud._hex_sheet_vbox,
		EvoUiStyle.tr_text(hud._lang, "🌾 Biomasa Disponible (R)", "🌾 Available Biomass (R)"),
		"%.0f / %.0f" % [cell.current_resources, cell.carrying_capacity],
		r_ratio * 100.0,
		EvoUiStyle.COLOR_GOLD_BEVEL
	)

	var k_ratio := clampf(cell.carrying_capacity / maxf(1.0, cell.carrying_capacity_max), 0.0, 1.0)
	var h_col := EvoUiStyle.COLOR_GREEN_OK
	if k_ratio < 0.60:
		h_col = EvoUiStyle.COLOR_RED_DANGER
	elif k_ratio < 0.85:
		h_col = EvoUiStyle.COLOR_AMBER_WARN

	add_milestone_bar(
		hud._hex_sheet_vbox,
		EvoUiStyle.tr_text(hud._lang, "💚 Salud Ecológica (K / Kmax)", "💚 Ecological Health (K / Kmax)"),
		"%.0f / %.0f (%d%%)" % [cell.carrying_capacity, cell.carrying_capacity_max, int(round(k_ratio * 100.0))],
		k_ratio * 100.0,
		h_col
	)


static func format_active_pacts_summary(world_state: EvoTypes.WorldState, lang: String, d: EvoTypes.Deme) -> String:
	var allies: Array[String] = []
	for other_id in world_state.demes.keys():
		if other_id == d.id:
			continue
		var od: EvoTypes.Deme = world_state.demes[other_id]
		if od.population > 0 and EvoTypes.is_pact_active(world_state, d.id, other_id):
			allies.append("🤝 " + format_short_deme_label(od))
	if allies.is_empty():
		return EvoI18n.t(lang, "inspector_no_pacts")
	return ", ".join(allies)


static func build_deme_relations_lines(world_state: EvoTypes.WorldState, lang: String, d: EvoTypes.Deme) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if world_state == null:
		return lines

	var mentioned_deme_ids: Dictionary = {}
	var pact_list: Array[String] = []
	var pact_hex := ""
	var pact_deme := ""
	var vendetta_list: Array[String] = []
	var vendetta_hex := ""
	var vendetta_deme := ""
	for other_id in world_state.demes.keys():
		if other_id == d.id:
			continue
		var od_pact: EvoTypes.Deme = world_state.demes[other_id]
		if od_pact.population <= 0:
			continue
		if EvoTypes.is_pact_active(world_state, d.id, other_id):
			pact_list.append(format_short_deme_label(od_pact))
			if pact_hex == "":
				pact_hex = od_pact.hex_id
				pact_deme = od_pact.id
			mentioned_deme_ids[other_id] = true
		elif EvoTypes.is_vendetta_active(world_state, d.id, other_id):
			vendetta_list.append(format_short_deme_label(od_pact))
			if vendetta_hex == "":
				vendetta_hex = od_pact.hex_id
				vendetta_deme = od_pact.id
			mentioned_deme_ids[other_id] = true

	var war_list: Array[String] = []
	var war_hex := ""
	var war_deme := ""
	var siege_list: Array[String] = []
	var siege_hex := ""
	var siege_deme := ""
	var raid_list: Array[String] = []
	var raid_hex := ""
	var raid_deme := ""
	var tribute_list: Array[String] = []
	var tribute_hex := ""
	var tribute_deme := ""
	var betrayal_list: Array[String] = []
	var betrayal_hex := ""
	var betrayal_deme := ""
	var coop_full: Array[String] = []
	var coop_short: Array[String] = []
	var coop_coord: Array[String] = []
	var coop_hex := ""
	var coop_deme := ""
	var dispute_full: Array[String] = []
	var dispute_short: Array[String] = []
	var dispute_coord: Array[String] = []
	var dispute_hex := ""
	var dispute_deme := ""
	var mig_full: Array[String] = []
	var mig_short: Array[String] = []
	var mig_coord: Array[String] = []
	var mig_hex := ""
	var mig_deme := ""

	for fl in world_state.active_flows:
		var has_deme_endpoints := (fl.from_deme_id != "" or fl.to_deme_id != "")
		var from_in_d := d.urban_hex_ids.has(fl.from_hex_id)
		var to_in_d := d.urban_hex_ids.has(fl.to_hex_id)
		var touches := (fl.from_deme_id == d.id or fl.to_deme_id == d.id) if has_deme_endpoints else (from_in_d or to_in_d)
		if not touches:
			continue
		if (fl.from_deme_id == d.id and fl.to_deme_id == d.id) or (not has_deme_endpoints and from_in_d and to_in_d):
			continue
		var other_hex := fl.to_hex_id if from_in_d else fl.from_hex_id
		var coord_lbl := "(%s)" % other_hex
		var full_lbl := "Hex (%s)" % other_hex
		var short_lbl := coord_lbl
		var other_deme_id := fl.to_deme_id if fl.from_deme_id == d.id else fl.from_deme_id
		var resolved_hex := other_hex
		var resolved_deme := ""
		if other_deme_id != "" and world_state.demes.has(other_deme_id):
			var od_flow: EvoTypes.Deme = world_state.demes[other_deme_id]
			full_lbl = format_deme_with_hex(od_flow)
			short_lbl = format_short_deme_label(od_flow)
			coord_lbl = "(%s)" % od_flow.hex_id
			resolved_hex = od_flow.hex_id
			resolved_deme = od_flow.id
			mentioned_deme_ids[other_deme_id] = true
		match fl.flow_type:
			"war":
				if not war_list.has(short_lbl):
					war_list.append(short_lbl)
					if war_hex == "":
						war_hex = resolved_hex
						war_deme = resolved_deme
			"siege":
				if not siege_list.has(short_lbl):
					siege_list.append(short_lbl)
					if siege_hex == "":
						siege_hex = resolved_hex
						siege_deme = resolved_deme
			"raid":
				if not raid_list.has(short_lbl):
					raid_list.append(short_lbl)
					if raid_hex == "":
						raid_hex = resolved_hex
						raid_deme = resolved_deme
			"tribute":
				if not tribute_list.has(short_lbl):
					tribute_list.append(short_lbl)
					if tribute_hex == "":
						tribute_hex = resolved_hex
						tribute_deme = resolved_deme
			"betrayal":
				if not betrayal_list.has(short_lbl):
					betrayal_list.append(short_lbl)
					if betrayal_hex == "":
						betrayal_hex = resolved_hex
						betrayal_deme = resolved_deme
			"pact":
				if not pact_list.has(short_lbl):
					pact_list.append(short_lbl)
					if pact_hex == "":
						pact_hex = resolved_hex
						pact_deme = resolved_deme
			"exchange", "cooperate", "merge":
				if not coop_full.has(full_lbl):
					coop_full.append(full_lbl)
					coop_short.append(short_lbl)
					coop_coord.append(coord_lbl)
					if coop_hex == "":
						coop_hex = resolved_hex
						coop_deme = resolved_deme
			"dispute":
				if not dispute_full.has(full_lbl):
					dispute_full.append(full_lbl)
					dispute_short.append(short_lbl)
					dispute_coord.append(coord_lbl)
					if dispute_hex == "":
						dispute_hex = resolved_hex
						dispute_deme = resolved_deme
			"migration":
				if not mig_full.has(coord_lbl):
					mig_full.append(coord_lbl)
					mig_short.append(coord_lbl)
					mig_coord.append(coord_lbl)
					if mig_hex == "":
						mig_hex = resolved_hex
						mig_deme = resolved_deme

	if not pact_list.is_empty():
		lines.append({"text": "🤝 " + EvoI18n.t(lang, "inspector_pact_with", {"partner": ", ".join(pact_list)}), "hex_id": pact_hex, "deme_id": pact_deme, "danger": false})
	if not vendetta_list.is_empty():
		lines.append({"text": "🩸 " + EvoI18n.t(lang, "inspector_vendetta_with", {"partner": ", ".join(vendetta_list)}), "hex_id": vendetta_hex, "deme_id": vendetta_deme, "danger": true})
	if not siege_list.is_empty():
		lines.append({"text": "🏰 %s: %s" % [EvoI18n.t(lang, "event_siege"), ", ".join(siege_list)], "hex_id": siege_hex, "deme_id": siege_deme, "danger": true})
	if not war_list.is_empty():
		lines.append({"text": "⚔️ %s: %s" % [EvoI18n.t(lang, "event_war"), ", ".join(war_list)], "hex_id": war_hex, "deme_id": war_deme, "danger": true})
	if not raid_list.is_empty():
		lines.append({"text": "🔥 %s: %s" % [EvoI18n.t(lang, "event_raid"), ", ".join(raid_list)], "hex_id": raid_hex, "deme_id": raid_deme, "danger": true})
	if not tribute_list.is_empty():
		lines.append({"text": "🪙 %s: %s" % [EvoI18n.t(lang, "event_tribute"), ", ".join(tribute_list)], "hex_id": tribute_hex, "deme_id": tribute_deme, "danger": false})
	if not betrayal_list.is_empty():
		lines.append({"text": "🗡️ %s: %s" % [EvoI18n.t(lang, "event_betrayal"), ", ".join(betrayal_list)], "hex_id": betrayal_hex, "deme_id": betrayal_deme, "danger": true})

	var coop_line := format_relation_category(
		lang,
		"🛣️ Cooperación activa: %s", "🛣️ Active cooperation: %s",
		"🛣️ Cooperación activa (%d): %s", "🛣️ Active cooperation (%d): %s",
		coop_full, coop_short, coop_coord
	)
	if coop_line != "":
		lines.append({"text": coop_line, "hex_id": coop_hex, "deme_id": coop_deme, "danger": false})

	var dispute_line := format_relation_category(
		lang,
		"⚔️ En conflicto: %s", "⚔️ In conflict: %s",
		"⚔️ En conflicto (%d): %s", "⚔️ In conflict (%d): %s",
		dispute_full, dispute_short, dispute_coord
	)
	if dispute_line != "":
		lines.append({"text": dispute_line, "hex_id": dispute_hex, "deme_id": dispute_deme, "danger": true})

	var mig_line := format_relation_category(
		lang,
		"🧭 Expedición migratoria hacia %s", "🧭 Migratory expedition toward %s",
		"🧭 Migración (%d): %s", "🧭 Migration (%d): %s",
		mig_full, mig_short, mig_coord
	)
	if mig_line != "":
		lines.append({"text": mig_line, "hex_id": mig_hex, "deme_id": mig_deme, "danger": false})

	var sev_full: Array[String] = []
	var sev_short: Array[String] = []
	var sev_coord: Array[String] = []
	var sev_hex := ""
	var sev_deme := ""
	for dis in world_state.disused_connections:
		var f_deme := str(dis.get("from_deme_id", ""))
		var t_deme := str(dis.get("to_deme_id", ""))
		var f_hex := str(dis.get("from_hex_id", ""))
		var t_hex := str(dis.get("to_hex_id", ""))
		var has_d := (f_deme != "" or t_deme != "")
		var f_in_d := d.urban_hex_ids.has(f_hex)
		var t_in_d := d.urban_hex_ids.has(t_hex)
		var touches_dis := (f_deme == d.id or t_deme == d.id) if has_d else (f_in_d or t_in_d)
		if touches_dis:
			if (f_deme == d.id and t_deme == d.id) or (not has_d and f_in_d and t_in_d):
				continue
			var other_d_id := t_deme if f_deme == d.id else f_deme
			var target_h := t_hex if f_in_d else f_hex
			var coord_s := "(%s)" % target_h
			var full_s := coord_s
			var short_s := coord_s
			var res_sev_hex := target_h
			var res_sev_deme := ""
			if other_d_id != "" and other_d_id != d.id and world_state.demes.has(other_d_id):
				var od_dis: EvoTypes.Deme = world_state.demes[other_d_id]
				full_s = format_deme_with_hex(od_dis)
				short_s = format_short_deme_label(od_dis)
				coord_s = "(%s)" % od_dis.hex_id
				res_sev_hex = od_dis.hex_id
				res_sev_deme = od_dis.id
			var age_val := int(dis.get("age", 0))
			if age_val > 0:
				full_s = EvoUiStyle.tr_text(lang, "%s (hace %d gen.)" % [full_s, age_val], "%s (%d gen. ago)" % [full_s, age_val])
			if not sev_full.has(full_s):
				sev_full.append(full_s)
				sev_short.append(short_s)
				sev_coord.append(coord_s)
				if sev_hex == "":
					sev_hex = res_sev_hex
					sev_deme = res_sev_deme

	var sev_line := format_relation_category(
		lang,
		"🚧 Camino cortado con %s", "🚧 Severed path with %s",
		"🚧 Caminos cortados (%d): %s", "🚧 Severed paths (%d): %s",
		sev_full, sev_short, sev_coord
	)
	if sev_line != "":
		lines.append({"text": sev_line, "hex_id": sev_hex, "deme_id": sev_deme, "danger": false})

	var perim_ids := EvoTypes.urban_perimeter_hex_ids(d, world_state)
	if not perim_ids.is_empty():
		var neigh_full: Array[String] = []
		var neigh_short: Array[String] = []
		var neigh_coord: Array[String] = []
		var neigh_hex := ""
		var neigh_deme := ""
		for nid in perim_ids:
			var nc: EvoTypes.HexCell = world_state.cells[nid]
			for nd_id in nc.deme_ids:
				if nd_id == d.id:
					continue
				if not mentioned_deme_ids.has(nd_id) and world_state.demes.has(nd_id):
					var nd: EvoTypes.Deme = world_state.demes[nd_id]
					var nlbl := format_deme_with_hex(nd)
					if not neigh_full.has(nlbl):
						neigh_full.append(nlbl)
						neigh_short.append(format_short_deme_label(nd))
						neigh_coord.append("(%s)" % nd.hex_id)
						if neigh_hex == "":
							neigh_hex = nd.hex_id
							neigh_deme = nd.id
		var neigh_line := format_relation_category(
			lang,
			"🏘️ Aldea vecina: %s", "🏘️ Neighbor village: %s",
			"🏘️ Aldeas vecinas (%d): %s", "🏘️ Neighbor villages (%d): %s",
			neigh_full, neigh_short, neigh_coord
		)
		if neigh_line != "":
			lines.append({"text": neigh_line, "hex_id": neigh_hex, "deme_id": neigh_deme, "danger": false})

	if lines.is_empty():
		lines.append({
			"text": EvoUiStyle.tr_text(lang, "🏞️ Sin caminos exteriores activos (aldea aislada)", "🏞️ No active outer roads (isolated village)"),
			"hex_id": "",
			"deme_id": "",
			"danger": false
		})
	return lines


static func format_deme_with_hex(od: EvoTypes.Deme) -> String:
	var suffix := "(%s)" % od.hex_id
	if od.name.ends_with(suffix):
		return od.name
	return "%s %s" % [od.name, suffix]


static func format_short_deme_label(od: EvoTypes.Deme) -> String:
	var suffix := "(%s)" % od.hex_id
	var base := od.name
	if base.ends_with(suffix):
		base = base.substr(0, base.length() - suffix.length()).strip_edges()
	if base.length() > 16:
		base = base.substr(0, 15) + "…"
	return "%s (%s)" % [base, od.hex_id]


static func format_relation_category(
	lang: String,
	single_es: String,
	single_en: String,
	multi_es: String,
	multi_en: String,
	full_list: Array[String],
	short_list: Array[String],
	coord_list: Array[String]
) -> String:
	var n := full_list.size()
	if n == 0:
		return ""
	if n == 1:
		return EvoUiStyle.tr_text(lang, single_es % full_list[0], single_en % full_list[0])
	if n == 2:
		var joined_two := ", ".join(short_list)
		return EvoUiStyle.tr_text(lang, multi_es % [n, joined_two], multi_en % [n, joined_two])
	var shown: Array[String] = []
	for i in range(mini(4, n)):
		shown.append(coord_list[i])
	if n > 4:
		shown.append(EvoUiStyle.tr_text(lang, "+%d más" % (n - 4), "+%d more" % (n - 4)))
	var joined_many := ", ".join(shown)
	return EvoUiStyle.tr_text(lang, multi_es % [n, joined_many], multi_en % [n, joined_many])


static func make_trait_tag(world_state: EvoTypes.WorldState, trait_id: String, is_cultural: bool, lang: String = "es") -> Control:
	var t_name := trait_id
	var tip := trait_id
	if world_state != null and world_state.traits_catalog.has(trait_id):
		var tr: EvoTypes.TraitDef = world_state.traits_catalog[trait_id]
		t_name = EvoI18n.trait_name(lang, tr)
		var t_desc := EvoI18n.trait_description(lang, tr)
		var v := tr.vector
		tip = "%s\n%s\nCost: %+.2f | Extr: %+.2f | Eco: %+.2f | Mob: %+.2f | Coh: %+.2f | Thr: %.2f" % [
			t_name, t_desc,
			v.metabolic_cost, v.extraction_efficiency, v.ecological_impact,
			v.spatial_mobility, v.social_cohesion, v.transmission_threshold
		]
	var badge := PanelContainer.new()
	var col := EvoUiStyle.COLOR_PURPLE_CULTURE if is_cultural else Color("#0d9488")
	badge.add_theme_stylebox_override("panel", EvoUiStyle.make_badge_style(col))
	badge.tooltip_text = tip

	var lbl := Label.new()
	var short_name := t_name
	if short_name.length() > 30:
		short_name = short_name.substr(0, 28) + "…"
	lbl.text = ("🔥 " if is_cultural else "🧬 ") + short_name
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(lbl)
	return badge


static func add_milestone_bar(parent: VBoxContainer, label_str: String, right_str: String, pct: float, fill_col: Color) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	parent.add_child(vb)

	var hb := HBoxContainer.new()
	vb.add_child(hb)

	var l1 := Label.new()
	l1.text = label_str
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1.clip_text = true
	l1.add_theme_font_size_override("font_size", 11)
	hb.add_child(l1)

	var l2 := Label.new()
	l2.text = right_str
	l2.add_theme_font_size_override("font_size", 11)
	hb.add_child(l2)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = pct
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 9)
	EvoUiStyle.style_progress_bar(bar, fill_col)
	vb.add_child(bar)


static func add_sheet_kv(parent: VBoxContainer, k_str: String, v_str: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	parent.add_child(hb)

	var kl := Label.new()
	kl.text = k_str
	kl.add_theme_font_size_override("font_size", 11)
	kl.add_theme_color_override("font_color", EvoUiStyle.COLOR_SEPIA)
	hb.add_child(kl)

	var vl := Label.new()
	vl.text = v_str
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vl.add_theme_font_size_override("font_size", 11)
	vl.add_theme_color_override("font_color", EvoUiStyle.COLOR_INK)
	hb.add_child(vl)
