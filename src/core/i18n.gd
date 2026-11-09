class_name EvoI18n
extends RefCounted

const STRINGS: Dictionary = {
	"es": {
		"app.title": "Evolution — Simulador Evolutivo de Poblaciones",
		"app.subtitle": "Sandbox Bio-Cultural y Evolutivo sobre Ecosistemas Hexagonales",
		"top.new_world": "Mundo / Escenario",
		"top.export_json": "Exportar JSON",
		"top.import_json": "Importar JSON",
		"top.play": "Reproducir",
		"top.pause": "Pausar",
		"top.step": "+1 Gen",
		"top.speed_normal": "1× Normal",
		"top.speed_fast": "2× Rápido",
		"top.generation": "Generación",
		"top.season.wet_warm": "Húmeda / Cálida",
		"top.season.dry_cold": "Seca / Fría",
		"top.pressure_points": "Presión Ambiental",
		"top.unlimited": "Ilimitada",
		"top.auto_pause": "Pausar en hitos",
		"top.lang": "Idioma",
		"biome.tropical_forest": "Selva Tropical",
		"biome.savanna": "Sabana",
		"biome.arid_steppe": "Estepa Árida",
		"biome.tundra": "Tundra",
		"biome.high_mountain": "Alta Montaña",
		"biome.coastal_shallows": "Bajíos Costeros",
		"biome.ocean": "Océano",
		"archetype.forage": "Recolección",
		"archetype.overexploit": "Sobreexplotación",
		"archetype.migrate": "Migración",
		"archetype.cooperate": "Cooperación",
		"archetype.exchange": "Intercambio",
		"archetype.dispute": "Conflicto",
		"archetype.innovate": "Innovación",
		"archetype.custom": "Personalizada",
		"status.thriving": "Prosperando",
		"status.stable": "Estable",
		"status.struggling": "En apuros",
		"status.starving": "En hambruna",
		"tier.1": "Campamento",
		"tier.2": "Aldea",
		"tier.3": "Villa",
		"tier.4": "Metrópolis",
		"tool.inspect": "Observar",
		"tool.set_biome": "Clima / Bioma",
		"tool.adjust_altitude": "Relieve / Altitud",
		"tool.adjust_carrying_capacity": "Alimento / Capacidad K",
		"tool.sea_level": "Nivel del Mar",
		"tool.raise_land": "Elevar (+0.18)",
		"tool.lower_land": "Hundir (-0.18)",
		"tool.add_food": "Enriquecer (+25%)",
		"tool.remove_food": "Agotar (-25%)",
		"tool.raise_sea": "Subir Mar (+0.05)",
		"tool.lower_sea": "Bajar Mar (-0.05)",
		"tool.brush_small": "Radio 1 (1 hex)",
		"tool.brush_large": "Radio 2 (7 hex)",
		"tool.chronicle": "Crónica",
		"tool.phylo_tree": "Linajes",
		"tool.catalog_lab": "Laboratorio",
		"lens.biome": "🌿 Bioma",
		"lens.food": "🌾 Alimento",
		"lens.health": "✚ Salud",
		"lens.diplomacy": "🤝 Diplom.",
		"lens.territory": "🚩 Territ.",
		"panel.populations": "Aldeas Activas",
		"panel.no_populations": "Todas las poblaciones se han extinguido.",
		"panel.population": "Población",
		"panel.reserves": "Reservas",
		"panel.trend": "Balance ΔE",
		"panel.highlight_lineage": "Resaltar Linaje",
		"panel.clear_highlight": "Quitar Resaltado",
		"panel.behavior": "Distribución Conductual",
		"panel.dominant": "Dominante",
		"panel.justification": "Justificación Contextual",
		"panel.traits_bio": "Rasgos Biológicos",
		"panel.traits_cul": "Tradiciones Culturales",
		"panel.no_traits": "Sin rasgos activos",
		"panel.inject_trait": "Inyectar Rasgo",
		"panel.inject_btn": "Inyectar",
		"panel.cultural_capacity_req": "Requiere capacidad cultural (Encefalización o Sociabilidad Instintiva).",
		"panel.milestones": "Progreso hacia Hitos",
		"panel.baldwin": "Asimilación Genética (Baldwin)",
		"panel.innovation": "Innovación Cultural",
		"panel.isolation": "Aislamiento Alopátrico",
		"panel.habitat": "Hábitat (Hexágono)",
		"panel.temperature": "Temperatura",
		"panel.humidity": "Humedad",
		"panel.altitude": "Altitud",
		"panel.food": "Recursos (R)",
		"panel.health": "Capacidad de Carga (K)",
		"panel.uninhabited": "Hexágono deshabitado",
		"axis.metabolic_cost": "Coste Metabólico",
		"axis.extraction_efficiency": "Eficiencia de Extracción",
		"axis.ecological_impact": "Impacto Ecológico",
		"axis.spatial_mobility": "Movilidad Espacial",
		"axis.social_cohesion": "Cohesión Social",
		"axis.transmission_threshold": "Umbral de Transmisión",
		"preset.preset-rift-savanna.name": "El Rift y la Sabana",
		"preset.preset-rift-savanna.desc": "Una falla tectónica divide una selva tropical estable al oeste de un mosaico de sabana en aridificación al este.",
		"preset.preset-rift-savanna.hyp": "Los demes orientales bajo aridificación estacional elevan su cooperación y migración, disparando asimilación de Baldwin o innovación cultural mientras el oeste conserva el forrajeo estable.",
		"preset.preset-darwin-archipelago.name": "Archipiélago de Darwin",
		"preset.preset-darwin-archipelago.desc": "Islas volcánicas conectadas por bajíos costeros que emergen y se inundan periódicamente con los ciclos glaciares del nivel del mar.",
		"preset.preset-darwin-archipelago.hyp": "Los demes colonizan islas por puentes terrestres durante el nivel del mar bajo y experimentan especiación alopátrica cuando la subida del mar aísla a las poblaciones insulares.",
		"preset.preset-finite-island.name": "La Isla Finita",
		"preset.preset-finite-island.desc": "Una isla fértil pero geográficamente confinada por un océano profundo infranqueable.",
		"preset.preset-finite-island.hyp": "Sin normas de conservación comunal, la competencia y la sobreexplotación intensiva degradan la capacidad de carga K por debajo del 60% de Kmax, provocando una Tragedia de los Comunes.",
		"trait.bio-r-strategy.name": "Estrategia r (Prolífica)",
		"trait.bio-r-strategy.desc": "Alta fecundidad, maduración rápida y baja inversión energética por descendiente que permite una rápida recuperación demográfica y dispersión.",
		"trait.bio-k-strategy.name": "Estrategia K (Longevidad y Cuidado Parental)",
		"trait.bio-k-strategy.desc": "Mayor longevidad, maduración tardía e inversión parental intensiva que amortiguan oscilaciones cerca de la capacidad de carga K.",
		"trait.bio-digestive-spec.name": "Especialización Digestiva Omnívora",
		"trait.bio-digestive-spec.desc": "Plasticidad enzimática e intestinal capaz de procesar flora fibrosa, tubérculos y fauna diversa, elevando la extracción calórica.",
		"trait.bio-thermal-tolerance.name": "Tolerancia Térmica e Hídrica",
		"trait.bio-thermal-tolerance.desc": "Termorregulación fisiológica y retención hídrica que reducen penalizaciones metabólicas en climas extremos y facilitan cruzar pasos de montaña.",
		"trait.bio-encephalization.name": "Encefalización (Tejido Neural Costoso)",
		"trait.bio-encephalization.desc": "Expansión neocortical y cognición ejecutiva a alto coste metabólico basal, desbloqueando transmisión cultural acumulativa e innovación.",
		"trait.bio-social-instinct.name": "Sociabilidad Instintiva (Gregarismo)",
		"trait.bio-social-instinct.desc": "Predisposición neuroendocrina hacia el altruismo grupal, coordinación afectiva y aprendizaje social que habilita la transmisión cultural.",
		"trait.cul-fire-processing.name": "Fuego y Procesado Térmico de Alimentos",
		"trait.cul-fire-processing.desc": "Dominio transmitido socialmente del fuego controlado y cocción que externaliza la digestión, reduce el gasto metabólico y aumenta la biodisponibilidad calórica.",
		"trait.cul-extraction-tools.name": "Herramientas de Extracción Especializadas",
		"trait.cul-extraction-tools.desc": "Tradición acumulativa de útiles líticos y orgánicos para caza y recolección intensiva que multiplica la extracción pero acelera el agotamiento del hábitat.",
		"trait.cul-communal-conservation.name": "Normas de Conservación Comunal",
		"trait.cul-communal-conservation.desc": "Tabúes institucionalizados, cuotas estacionales y custodia ecológica que previenen la Tragedia de los Comunes y regeneran la capacidad de carga K.",
		"trait.cul-interdeme-barter.name": "Redes de Trueque Inter-Deme",
		"trait.cul-interdeme-barter.desc": "Protocolos codificados de diplomacia intergrupal e intercambio recíproco que facilitan la cohabitación pacífica, bonos calóricos y difusión cultural.",
		"trait.cul-warrior-expansion.name": "Tradición Guerrera / Expansionista",
		"trait.cul-warrior-expansion.desc": "Organización marcial y doctrinas de expansión territorial que maximizan el dominio competitivo en disputas a alto coste energético y ecológico.",
		"decision.forage.name": "Forrajeo",
		"decision.forage.desc": "Recolección cuidadosa en el propio hexágono: +20% de cosecha sin dañar el hábitat.",
		"decision.intensify.name": "Sobreexplotar",
		"decision.intensify.desc": "Cosecha agresiva (+55%) que degrada permanentemente la capacidad de carga del hexágono.",
		"decision.fortify.name": "Fortificar",
		"decision.fortify.desc": "Invierte reservas y recursos del hexágono en subir un nivel de muralla.",
		"decision.innovate.name": "Innovar",
		"decision.innovate.desc": "Experimentación cultural que acumula progreso hacia una nueva tradición.",
		"decision.settle.name": "Colonizar",
		"decision.settle.desc": "Envía colonos y alimento a fundar un campamento en un hexágono vacío adyacente.",
		"decision.trade.name": "Comerciar",
		"decision.trade.desc": "Intercambio con un vecino: beneficio para ambos si es recíproco.",
		"decision.aid.name": "Ayudar",
		"decision.aid.desc": "Regala alimento a un vecino; aumenta su confianza y tu reputación.",
		"decision.offer_pact.name": "Proponer pacto",
		"decision.offer_pact.desc": "Ofrece una alianza; el vecino decide si la acepta el turno siguiente.",
		"decision.accept_pact.name": "Aceptar pacto",
		"decision.accept_pact.desc": "Acepta la alianza propuesta: bonificación de cosecha y defensa mutua.",
		"decision.demand_tribute.name": "Exigir tributo",
		"decision.demand_tribute.desc": "Exige alimento a un vecino más débil bajo amenaza.",
		"decision.pay_tribute.name": "Pagar tributo",
		"decision.pay_tribute.desc": "Paga el tributo exigido a cambio de una tregua.",
		"decision.raid.name": "Saquear",
		"decision.raid.desc": "Incursión para robar reservas y cosechas de un vecino no aliado.",
		"decision.betray.name": "Traicionar",
		"decision.betray.desc": "Rompe una alianza con un ataque por sorpresa contra el aliado.",
		"decision.conquer.name": "Conquistar",
		"decision.conquer.desc": "Envía un ejército a tomar el hexágono del vecino.",
		"decision.unite.name": "Proponer unión",
		"decision.unite.desc": "Propone a un aliado o pariente fusionar ambos asentamientos.",
		"decision.accept_union.name": "Aceptar unión",
		"decision.accept_union.desc": "Acepta la unión propuesta (sinecismo o unión amurallada).",
		"chronicle.type.baldwin_trait": "Asimilación de Baldwin",
		"chronicle.type.cultural_innovation": "Innovación Cultural",
		"chronicle.type.allopatric_speciation": "Especiación Alopátrica",
		"chronicle.type.cultural_loss": "Cuello de Botella Cultural",
		"chronicle.type.extinction": "Extinción",
		"chronicle.type.total_extinction": "Extinción Total",
		"chronicle.type.tragedy_of_commons": "Tragedia de los Comunes",
		"chronicle.type.symbiosis": "Simbiosis Cultural",
		"chronicle.type.single_survivor": "Hegemonía Evolutiva",
		"chronicle.type.ecological_equilibrium": "Equilibrio Ecológico",
		"chronicle.type.war": "Guerra de Conquista",
		"chronicle.type.raid": "Incursión de Saqueo",
		"chronicle.type.pact": "Pacto Formal",
		"chronicle.type.betrayal": "Traición de Pacto",
		"chronicle.type.fortify": "Fortificación Defensiva",
		"chronicle.type.merge": "Unión de Poblaciones",
		"chronicle.type.tribute": "Pago de Tributo",
		"chronicle.type.siege": "Asedio a Fortaleza",
		"chronicle.type.epidemic": "Epidemia Urbana",
		"chronicle.type.epidemic_spread": "Contagio Epidémico",
		"chronicle.type.epidemic_recovered": "Inmunidad Post-Epidemia",
		"chronicle.type.famine": "Hambruna Severa",
		"filter_war": "Guerra",
		"filter_raid": "Saqueo",
		"filter_pact": "Pactos",
		"filter_betrayal": "Traición",
		"filter_fortify": "Defensa",
		"filter_merge": "Unión",
		"filter_tribute": "Tributo",
		"filter_siege": "Asedio",
		"event_war": "Guerra de Conquista",
		"event_raid": "Incursión de Saqueo",
		"event_pact": "Pacto Formal",
		"event_betrayal": "Traición de Pacto",
		"event_fortify": "Fortificación Defensiva",
		"event_merge": "Unión de Poblaciones",
		"event_tribute": "Pago de Tributo",
		"event_siege": "Asedio a Fortaleza",
		"inspector_pacts": "Pactos y Alianzas",
		"inspector_no_pacts": "Sin pactos activos",
		"inspector_pact_with": "Pacto activo con {partner}",
		"inspector_defense_label": "Defensa",
		"inspector_defense_0": "Sin fortificar",
		"inspector_defense_1": "Nv.1 Empalizada (+45%)",
		"inspector_defense_2": "Nv.2 Muralla (+95%)",
		"inspector_defense_3": "Nv.3 Castillo (+155%)",
		"inspector_merged_city": "Ciudad Unificada ({count} pueblos)",
		"inspector_vendetta_with": "Rencor / Vendetta contra {partner}",
		"legend_flow_war": "Guerra / Invasión",
		"legend_flow_raid": "Saqueo / Incursión",
		"legend_flow_pact": "Pacto / Alianza",
		"legend_flow_betrayal": "Traición",
		"legend_flow_tribute": "Tributo / Tregua",
		"legend_flow_merge": "Unión en Ciudad",
		"legend_flow_siege": "Asedio Activo",
		"chronicle_war_victory_title": "Conquista Militar en ({hex})",
		"chronicle_war_victory_desc": "{attacker} derrotó a {defender} en el hexágono ({hex}), causando {casualties} bajas y capturando {loot} reservas energéticas.",
		"chronicle_war_repelled_title": "Invasión Repelida en ({hex})",
		"chronicle_war_repelled_desc": "{defender} repelió la ofensiva de {attacker} en ({hex}), infligiendo {casualties} bajas a los atacantes.",
		"chronicle_raid_title": "Incursión de Saqueo en ({hex})",
		"chronicle_raid_desc": "{raider} saqueó a {victim} en ({hex}), arrebatando {loot} unidades de reservas calóricas.",
		"chronicle_pact_title": "Pacto de Alianza en ({hex})",
		"chronicle_pact_desc": "{deme_a} y {deme_b} consolidaron un pacto formal de cooperación e intercambio mutuo en ({hex}).",
		"chronicle_betrayal_title": "Traición de Pacto en ({hex})",
		"chronicle_betrayal_desc": "{betrayer} rompió su alianza y atacó por sorpresa a {victim} en ({hex}), saqueando {loot} reservas energéticas.",
		"chronicle_fortify_title": "Fortificación Erigida en ({hex})",
		"chronicle_fortify_desc": "{deme} invirtió excedentes para erigir {tier_name} en ({hex}), reforzando su defensa territorial.",
		"chronicle_merge_title": "Unión de Pueblos en ({hex})",
		"chronicle_merge_desc": "{deme_a} y {deme_b} unieron sus poblaciones y defensas en una sola ciudad en ({hex}) (pob. {pop}).",
		"chronicle_tribute_title": "Tributo de Paz en ({hex})",
		"chronicle_tribute_desc": "{victim} entregó {loot} reservas como tributo a {raider} en ({hex}), evitando bajas y sellando una tregua.",
		"chronicle_siege_title": "Asedio Repelido en ({hex})",
		"chronicle_siege_desc": "Las fortificaciones de {defender} en ({hex}) resistieron el asedio de {attacker}, causando {casualties} bajas a los asaltantes.",
		"chronicle_epidemic_title": "Epidemia Urbana en ({hex})",
		"chronicle_epidemic_desc": "El hacinamiento y baja salubridad en ({hex}) desataron una epidemia en {deme}, causando {casualties} bajas.",
		"chronicle_epidemic_spread_title": "Contagio Epidémico en ({hex})",
		"chronicle_epidemic_spread_desc": "El contacto con {source} propagó la epidemia a {deme} en ({hex}), causando {casualties} bajas.",
		"chronicle_epidemic_recovered_title": "Fin de Epidemia en ({hex})",
		"chronicle_epidemic_recovered_desc": "{deme} superó el brote epidémico en ({hex}) y adquirió inmunidad temporal.",
		"chronicle_famine_title": "Hambruna en ({hex})",
		"chronicle_famine_desc": "El déficit calórico severo provocó una hambruna en {deme} ({hex}), con una pérdida de {casualties} habitantes.",
		"chronicle_walled_union_title": "Unión Amurallada en ({hex})",
		"chronicle_walled_union_desc": "{deme_a} y {deme_b} unificaron sus murallas perimetrales en una ciudad multi-hexágono ({hex}).",
		"strategy.strat-cooperation.name": "Alianza Cooperativa",
		"strategy.strat-cooperation.desc": "Fomenta la cohesión social, la conservación comunal del hábitat y el almacenamiento.",
		"strategy.strat-cooperation.doctrine": "Alianza Cooperativa: valoras la solidaridad, cumples tu palabra y proteges a tus vecinos; recuerdas quién te ayudó.",
		"strategy.strat-expansion.name": "Pioneros Expansionistas",
		"strategy.strat-expansion.desc": "Reproducción rápida, alta movilidad y tolerancia térmica para colonizar nuevos territorios.",
		"strategy.strat-expansion.doctrine": "Pioneros Expansionistas: valoras la tierra nueva y las familias numerosas; colonizas cada valle fértil.",
		"strategy.strat-trade.name": "Liga Mercantil",
		"strategy.strat-trade.desc": "Impulsa el trueque inter-tribal, la simbiosis comercial y la difusión cultural.",
		"strategy.strat-trade.doctrine": "Liga Mercantil: valoras los buenos tratos, la confianza y la reputación; la riqueza fluye hacia quien comercia.",
		"strategy.strat-war.name": "Horda Conquistadora",
		"strategy.strat-war.desc": "Expansión marcial agresiva y extracción intensiva para dominar territorios rivales.",
		"strategy.strat-war.doctrine": "Horda Conquistadora: honras la fuerza; la conquista, el saqueo y el tributo dan respeto; la debilidad invita al ataque.",
		"strategy.strat-innovation.name": "Tecnócratas Innovadores",
		"strategy.strat-innovation.desc": "Alta encefalización, procesado térmico y herramientas especializadas de extracción.",
		"strategy.strat-innovation.doctrine": "Tecnócratas Innovadores: valoras el conocimiento y las herramientas; inviertes en inventar y superas a tus rivales con ingenio.",
		"lab_tab_strat": "🛡️ Estrategias",
		"lab_new_strat": "+ Nueva Estrategia",
		"lab_save_strat": "💾 Guardar Estrategia",
		"lab_strat_icon": "Emblema",
		"lab_strat_color": "Color",
		"lab_strat_traits": "Rasgos de la Estrategia",
		"lab_strat_vector": "Huella Biofísica Combinada",
		"lab_use_strat_a": "Usar como Estrategia A",
		"lab_use_strat_b": "Usar como Estrategia B",
		"hud_matchup_vs": "⚔️",
		"hud_matchup_reset": "🔄",
		"hud_matchup_reset_tip": "Reiniciar duelo en Generación 0 con las estrategias seleccionadas",
		"insp_strategy": "Estrategia",
		"legend_strategies": "Duelo de Estrategias"
	},
	"en": {
		"app.title": "Evolution — Population Evolutionary Simulator",
		"app.subtitle": "Bio-Cultural & Evolutionary Sandbox on Hexagonal Ecosystems",
		"top.new_world": "World / Scenario",
		"top.export_json": "Export JSON",
		"top.import_json": "Import JSON",
		"top.play": "Play",
		"top.pause": "Pause",
		"top.step": "+1 Gen",
		"top.speed_normal": "1× Normal",
		"top.speed_fast": "2× Fast",
		"top.generation": "Generation",
		"top.season.wet_warm": "Wet / Warm",
		"top.season.dry_cold": "Dry / Cold",
		"top.pressure_points": "Selective Pressure",
		"top.unlimited": "Unlimited",
		"top.auto_pause": "Pause on milestones",
		"top.lang": "Language",
		"biome.tropical_forest": "Tropical Forest",
		"biome.savanna": "Savanna",
		"biome.arid_steppe": "Arid Steppe",
		"biome.tundra": "Tundra",
		"biome.high_mountain": "High Mountain",
		"biome.coastal_shallows": "Coastal Shallows",
		"biome.ocean": "Ocean",
		"archetype.forage": "Foraging",
		"archetype.overexploit": "Overexploitation",
		"archetype.migrate": "Migration",
		"archetype.cooperate": "Cooperation",
		"archetype.exchange": "Exchange",
		"archetype.dispute": "Conflict",
		"archetype.innovate": "Innovation",
		"archetype.custom": "Custom",
		"status.thriving": "Thriving",
		"status.stable": "Stable",
		"status.struggling": "Struggling",
		"status.starving": "Starving",
		"tier.1": "Camp",
		"tier.2": "Village",
		"tier.3": "Town",
		"tier.4": "Metropolis",
		"tool.inspect": "Observe",
		"tool.set_biome": "Climate / Biome",
		"tool.adjust_altitude": "Terrain / Altitude",
		"tool.adjust_carrying_capacity": "Food / Capacity K",
		"tool.sea_level": "Sea Level",
		"tool.raise_land": "Raise (+0.18)",
		"tool.lower_land": "Lower (-0.18)",
		"tool.add_food": "Enrich (+25%)",
		"tool.remove_food": "Deplete (-25%)",
		"tool.raise_sea": "Raise Sea (+0.05)",
		"tool.lower_sea": "Lower Sea (-0.05)",
		"tool.brush_small": "Radius 1 (1 hex)",
		"tool.brush_large": "Radius 2 (7 hex)",
		"tool.chronicle": "Chronicle",
		"tool.phylo_tree": "Lineages",
		"tool.catalog_lab": "Catalog Lab",
		"lens.biome": "🌿 Biome",
		"lens.food": "🌾 Food",
		"lens.health": "✚ Health",
		"lens.diplomacy": "🤝 Diplom.",
		"lens.territory": "🚩 Territ.",
		"panel.populations": "Active Villages",
		"panel.no_populations": "All populations are extinct.",
		"panel.population": "Population",
		"panel.reserves": "Reserves",
		"panel.trend": "Balance ΔE",
		"panel.highlight_lineage": "Highlight Lineage",
		"panel.clear_highlight": "Clear Highlight",
		"panel.behavior": "Behavioral Distribution",
		"panel.dominant": "Dominant",
		"panel.justification": "Contextual Justification",
		"panel.traits_bio": "Biological Traits",
		"panel.traits_cul": "Cultural Traditions",
		"panel.no_traits": "No active traits",
		"panel.inject_trait": "Inject Trait",
		"panel.inject_btn": "Inject",
		"panel.cultural_capacity_req": "Requires cultural capacity (Encephalization or Instinctive Sociability).",
		"panel.milestones": "Milestone Progress",
		"panel.baldwin": "Genetic Assimilation (Baldwin)",
		"panel.innovation": "Cultural Innovation",
		"panel.isolation": "Allopatric Isolation",
		"panel.habitat": "Habitat (Hexagon)",
		"panel.temperature": "Temperature",
		"panel.humidity": "Humidity",
		"panel.altitude": "Altitude",
		"panel.food": "Resources (R)",
		"panel.health": "Carrying Capacity (K)",
		"panel.uninhabited": "Uninhabited hexagon",
		"axis.metabolic_cost": "Metabolic Cost",
		"axis.extraction_efficiency": "Extraction Efficiency",
		"axis.ecological_impact": "Ecological Impact",
		"axis.spatial_mobility": "Spatial Mobility",
		"axis.social_cohesion": "Social Cohesion",
		"axis.transmission_threshold": "Transmission Threshold",
		"preset.preset-rift-savanna.name": "The Rift and the Savanna",
		"preset.preset-rift-savanna.desc": "A tectonic ridge divides a stable western tropical forest from a drying eastern savanna mosaic.",
		"preset.preset-rift-savanna.hyp": "Eastern demes under seasonal aridification increase cooperation and migration, triggering Baldwin assimilation or cultural innovation while western forest demes maintain conservative foraging.",
		"preset.preset-darwin-archipelago.name": "Darwin's Archipelago",
		"preset.preset-darwin-archipelago.desc": "Volcanic islands linked by shallow coastal land bridges that periodically flood and emerge with glacial sea-level cycles.",
		"preset.preset-darwin-archipelago.hyp": "Demes disperse across temporary land bridges during low sea levels and subsequently undergo allopatric speciation when rising seas isolate island populations.",
		"preset.preset-finite-island.name": "The Finite Island",
		"preset.preset-finite-island.desc": "A resource-rich but geographically bounded island surrounded by impassable deep ocean.",
		"preset.preset-finite-island.hyp": "Without communal conservation norms, inter-deme competition and intensive overexploitation degrade carrying capacity K below 60% of Kmax, causing a Tragedy of the Commons.",
		"trait.bio-r-strategy.name": "r-Strategy (Prolific)",
		"trait.bio-r-strategy.desc": "Life-history adaptation prioritizing rapid maturation, high fecundity, and low per-offspring energetic investment, enabling rapid demographic rebound and dispersal.",
		"trait.bio-k-strategy.name": "K-Strategy (Longevity & Parental Care)",
		"trait.bio-k-strategy.desc": "Life-history adaptation prioritizing extended longevity, delayed maturation, and intensive parental care that buffers demographic oscillations near carrying capacity.",
		"trait.bio-digestive-spec.name": "Omnivorous Digestive Specialization",
		"trait.bio-digestive-spec.desc": "Enzymatic and gastrointestinal plasticity capable of detoxifying fibrous flora, tubers, and diverse fauna across heterogeneous biomes.",
		"trait.bio-thermal-tolerance.name": "Thermal & Hydric Tolerance",
		"trait.bio-thermal-tolerance.desc": "Physiological thermoregulation and water-conservation adaptations that reduce metabolic penalties in extreme environments and facilitate barrier traversal.",
		"trait.bio-encephalization.name": "Encephalization (Costly Neural Tissue)",
		"trait.bio-encephalization.desc": "Expansion of neocortical volume and executive cognition at a steep resting metabolic cost, unlocking cumulative cultural transmission and tool innovation.",
		"trait.bio-social-instinct.name": "Instinctive Sociability (Gregariousness)",
		"trait.bio-social-instinct.desc": "Neuroendocrine predisposition toward kin altruism, affective coordination, and social learning that enables cultural transmission.",
		"trait.cul-fire-processing.name": "Fire & Thermal Food Processing",
		"trait.cul-fire-processing.desc": "Socially transmitted mastery of controlled fire and thermal food preparation that externalizes digestion, lowers metabolic expenditure, and increases caloric bioavailability.",
		"trait.cul-extraction-tools.name": "Specialized Extraction Tools",
		"trait.cul-extraction-tools.desc": "Cumulative lithic and organic toolkit tradition for intensive hunting and harvesting that sharply boosts extraction while accelerating habitat depletion.",
		"trait.cul-communal-conservation.name": "Communal Conservation Norms",
		"trait.cul-communal-conservation.desc": "Institutionalized taboos, seasonal harvesting quotas, and ecological stewardship norms that prevent the Tragedy of the Commons and regenerate carrying capacity K.",
		"trait.cul-interdeme-barter.name": "Inter-Deme Barter Networks",
		"trait.cul-interdeme-barter.desc": "Codified protocols of inter-group diplomacy and reciprocal exchange that facilitate peaceful cohabitation, mutual caloric bonuses, and cultural diffusion.",
		"trait.cul-warrior-expansion.name": "Warrior / Expansionist Tradition",
		"trait.cul-warrior-expansion.desc": "Militarized organization and territorial expansion norms that maximize competitive dominance in inter-deme disputes at high energetic and ecological cost.",
		"decision.forage.name": "Forage",
		"decision.forage.desc": "Careful gathering on the home hex: +20% harvest without harming the habitat.",
		"decision.intensify.name": "Overexploit",
		"decision.intensify.desc": "Aggressive harvest (+55%) that permanently degrades the hex carrying capacity.",
		"decision.fortify.name": "Fortify",
		"decision.fortify.desc": "Invest reserves and hex resources to raise the wall level by one.",
		"decision.innovate.name": "Innovate",
		"decision.innovate.desc": "Cultural experimentation that accumulates progress toward a new tradition.",
		"decision.settle.name": "Settle",
		"decision.settle.desc": "Send settlers and food to found a camp on an adjacent empty hex.",
		"decision.trade.name": "Trade",
		"decision.trade.desc": "Exchange with a neighbor: both gain if it is reciprocated.",
		"decision.aid.name": "Aid",
		"decision.aid.desc": "Give food to a neighbor; raises its trust and your reputation.",
		"decision.offer_pact.name": "Offer pact",
		"decision.offer_pact.desc": "Offer an alliance; the neighbor decides next turn whether to accept.",
		"decision.accept_pact.name": "Accept pact",
		"decision.accept_pact.desc": "Accept the proposed alliance: harvest bonus and mutual defense.",
		"decision.demand_tribute.name": "Demand tribute",
		"decision.demand_tribute.desc": "Demand food from a weaker neighbor under threat.",
		"decision.pay_tribute.name": "Pay tribute",
		"decision.pay_tribute.desc": "Pay the demanded tribute in exchange for a truce.",
		"decision.raid.name": "Raid",
		"decision.raid.desc": "Raid a non-allied neighbor to steal reserves and crops.",
		"decision.betray.name": "Betray",
		"decision.betray.desc": "Break an alliance with a surprise attack on the ally.",
		"decision.conquer.name": "Conquer",
		"decision.conquer.desc": "Send an army to seize the neighbor's hex.",
		"decision.unite.name": "Propose union",
		"decision.unite.desc": "Propose to an ally or kin to merge both settlements.",
		"decision.accept_union.name": "Accept union",
		"decision.accept_union.desc": "Accept the proposed union (synoecism or walled union).",
		"chronicle.type.baldwin_trait": "Baldwin Assimilation",
		"chronicle.type.cultural_innovation": "Cultural Innovation",
		"chronicle.type.allopatric_speciation": "Allopatric Speciation",
		"chronicle.type.cultural_loss": "Cultural Bottleneck",
		"chronicle.type.extinction": "Extinction",
		"chronicle.type.total_extinction": "Total Extinction",
		"chronicle.type.tragedy_of_commons": "Tragedy of the Commons",
		"chronicle.type.symbiosis": "Cultural Symbiosis",
		"chronicle.type.single_survivor": "Evolutionary Hegemony",
		"chronicle.type.ecological_equilibrium": "Ecological Equilibrium",
		"chronicle.type.war": "War of Conquest",
		"chronicle.type.raid": "Plunder Raid",
		"chronicle.type.pact": "Formal Pact",
		"chronicle.type.betrayal": "Pact Betrayal",
		"chronicle.type.fortify": "Defensive Fortification",
		"chronicle.type.merge": "Settlement Unification",
		"chronicle.type.tribute": "Tribute Payment",
		"chronicle.type.siege": "Fortress Siege",
		"chronicle.type.epidemic": "Urban Epidemic",
		"chronicle.type.epidemic_spread": "Epidemic Contagion",
		"chronicle.type.epidemic_recovered": "Epidemic Recovery",
		"chronicle.type.famine": "Severe Famine",
		"filter_war": "War",
		"filter_raid": "Raid",
		"filter_pact": "Pacts",
		"filter_betrayal": "Betrayal",
		"filter_fortify": "Defense",
		"filter_merge": "Union",
		"filter_tribute": "Tribute",
		"filter_siege": "Siege",
		"event_war": "War of Conquest",
		"event_raid": "Plunder Raid",
		"event_pact": "Formal Pact",
		"event_betrayal": "Pact Betrayal",
		"event_fortify": "Defensive Fortification",
		"event_merge": "Settlement Unification",
		"event_tribute": "Tribute Payment",
		"event_siege": "Fortress Siege",
		"inspector_pacts": "Pacts & Alliances",
		"inspector_no_pacts": "No active pacts",
		"inspector_pact_with": "Active pact with {partner}",
		"inspector_defense_label": "Defense",
		"inspector_defense_0": "Unfortified",
		"inspector_defense_1": "Lv.1 Palisade (+45%)",
		"inspector_defense_2": "Lv.2 Stone Wall (+95%)",
		"inspector_defense_3": "Lv.3 Castle (+155%)",
		"inspector_merged_city": "Unified City ({count} peoples)",
		"inspector_vendetta_with": "Grudge / Vendetta against {partner}",
		"legend_flow_war": "War / Invasion",
		"legend_flow_raid": "Raid / Plunder",
		"legend_flow_pact": "Pact / Alliance",
		"legend_flow_betrayal": "Betrayal",
		"legend_flow_tribute": "Tribute / Truce",
		"legend_flow_merge": "City Unification",
		"legend_flow_siege": "Active Siege",
		"chronicle_war_victory_title": "Military Conquest at ({hex})",
		"chronicle_war_victory_desc": "{attacker} defeated {defender} at hex ({hex}), inflicting {casualties} casualties and seizing {loot} energy reserves.",
		"chronicle_war_repelled_title": "Invasion Repelled at ({hex})",
		"chronicle_war_repelled_desc": "{defender} repelled the assault by {attacker} at ({hex}), inflicting {casualties} casualties on the attackers.",
		"chronicle_raid_title": "Plunder Raid at ({hex})",
		"chronicle_raid_desc": "{raider} raided {victim} at ({hex}), plundering {loot} caloric reserve units.",
		"chronicle_pact_title": "Alliance Pact at ({hex})",
		"chronicle_pact_desc": "{deme_a} and {deme_b} forged a formal pact of mutual cooperation and exchange at ({hex}).",
		"chronicle_betrayal_title": "Pact Betrayal at ({hex})",
		"chronicle_betrayal_desc": "{betrayer} broke their alliance and ambushed {victim} at ({hex}), plundering {loot} energy reserves.",
		"chronicle_fortify_title": "Fortification Built at ({hex})",
		"chronicle_fortify_desc": "{deme} invested surplus resources to build {tier_name} at ({hex}), reinforcing its territorial defense.",
		"chronicle_merge_title": "Unification of Peoples at ({hex})",
		"chronicle_merge_desc": "{deme_a} and {deme_b} united their populations and defenses into a single city at ({hex}) (pop. {pop}).",
		"chronicle_tribute_title": "Peace Tribute at ({hex})",
		"chronicle_tribute_desc": "{victim} paid {loot} reserves as tribute to {raider} at ({hex}), avoiding casualties and sealing a truce.",
		"chronicle_siege_title": "Siege Repelled at ({hex})",
		"chronicle_siege_desc": "The fortifications of {defender} at ({hex}) withstood the siege by {attacker}, inflicting {casualties} casualties on the assailants.",
		"chronicle_epidemic_title": "Urban Epidemic at ({hex})",
		"chronicle_epidemic_desc": "Crowding and poor sanitation at ({hex}) triggered an epidemic in {deme}, causing {casualties} casualties.",
		"chronicle_epidemic_spread_title": "Epidemic Contagion at ({hex})",
		"chronicle_epidemic_spread_desc": "Contact with {source} spread the epidemic to {deme} at ({hex}), causing {casualties} casualties.",
		"chronicle_epidemic_recovered_title": "Epidemic Subsided at ({hex})",
		"chronicle_epidemic_recovered_desc": "{deme} overcame the epidemic outbreak at ({hex}) and acquired temporary immunity.",
		"chronicle_famine_title": "Famine at ({hex})",
		"chronicle_famine_desc": "Severe caloric deficit triggered famine in {deme} ({hex}), causing a loss of {casualties} inhabitants.",
		"chronicle_walled_union_title": "Walled Union at ({hex})",
		"chronicle_walled_union_desc": "{deme_a} and {deme_b} joined their perimeter walls into a multi-hex city ({hex}).",
		"strategy.strat-cooperation.name": "Cooperative Alliance",
		"strategy.strat-cooperation.desc": "Fosters social cohesion, communal habitat conservation, and resource buffering.",
		"strategy.strat-cooperation.doctrine": "Cooperative Alliance: you value solidarity, keep your word and protect your neighbors; you remember who helped you.",
		"strategy.strat-expansion.name": "Expansionist Pioneers",
		"strategy.strat-expansion.desc": "Fast reproduction, high mobility, and thermal tolerance to colonize new territories.",
		"strategy.strat-expansion.doctrine": "Expansionist Pioneers: you prize new land and large families; you settle every fertile valley.",
		"strategy.strat-trade.name": "Merchant League",
		"strategy.strat-trade.desc": "Drives inter-village barter, commercial symbiosis, and cultural diffusion.",
		"strategy.strat-trade.doctrine": "Merchant League: you value profitable deals, trust and reputation; wealth flows to those who trade.",
		"strategy.strat-war.name": "Conquering Horde",
		"strategy.strat-war.desc": "Aggressive martial expansion and intensive extraction to dominate rival territories.",
		"strategy.strat-war.doctrine": "Conquering Horde: you honor strength; conquest, plunder and tribute earn respect; weakness invites attack.",
		"strategy.strat-innovation.name": "Innovator Technocrats",
		"strategy.strat-innovation.desc": "High encephalization, thermal processing, and specialized extraction tools.",
		"strategy.strat-innovation.doctrine": "Innovator Technocrats: you value knowledge and tools; you invest in invention and outthink your rivals.",
		"lab_tab_strat": "🛡️ Strategies",
		"lab_new_strat": "+ New Strategy",
		"lab_save_strat": "💾 Save Strategy",
		"lab_strat_icon": "Emblem",
		"lab_strat_color": "Color",
		"lab_strat_traits": "Strategy Traits",
		"lab_strat_vector": "Combined Biophysical Footprint",
		"lab_use_strat_a": "Set as Strategy A",
		"lab_use_strat_b": "Set as Strategy B",
		"hud_matchup_vs": "⚔️",
		"hud_matchup_reset": "🔄",
		"hud_matchup_reset_tip": "Reset duel at Generation 0 with the selected strategies",
		"insp_strategy": "Strategy",
		"legend_strategies": "Strategy Duel"
	}
}


static func resolve_lang(lang: String) -> String:
	return "en" if lang == "en" else "es"


static func t(lang: String, key: String, params: Dictionary = {}) -> String:
	var table: Dictionary = STRINGS[resolve_lang(lang)]
	var res := key
	if table.has(key):
		res = str(table[key])
	elif STRINGS["es"].has(key):
		res = str(STRINGS["es"][key])
	return res.format(params) if not params.is_empty() else res


static func strategy_text(strategy_id: String, field: String, fallback: String = "", lang: String = "es") -> String:
	var key_suffix := "desc" if field == "description" else field
	var key := "strategy.%s.%s" % [strategy_id, key_suffix]
	var table: Dictionary = STRINGS[resolve_lang(lang)]
	if table.has(key):
		return str(table[key])
	return fallback


static func strategy_name(lang: String, strat_def: EvoTypes.StrategyDef) -> String:
	if strat_def is Object and strat_def.get("origin") != null and str(strat_def.get("origin")) not in ["base", "catalog"]:
		return str(strat_def.name)
	return strategy_text(strat_def.id, "name", strat_def.name, lang)


static func strategy_description(lang: String, strat_def: EvoTypes.StrategyDef) -> String:
	if strat_def is Object and strat_def.get("origin") != null and str(strat_def.get("origin")) not in ["base", "catalog"]:
		return str(strat_def.description)
	return strategy_text(strat_def.id, "desc", strat_def.description, lang)


static func strategy_doctrine(lang: String, strat_def: EvoTypes.StrategyDef) -> String:
	if strat_def is Object and strat_def.get("origin") != null and str(strat_def.get("origin")) not in ["base", "catalog"]:
		return str(strat_def.doctrine)
	return strategy_text(strat_def.id, "doctrine", strat_def.doctrine, lang)


static func localize_world_state(state: EvoTypes.WorldState, lang: String = "es") -> void:
	if state == null:
		return
	var is_en := resolve_lang(lang) == "en"
	state.world_name = preset_title(lang, state.preset_id)
	for tr_id in state.traits_catalog.keys():
		var tr: EvoTypes.TraitDef = state.traits_catalog[tr_id]
		if tr.origin in ["catalog", "base"]:
			tr.name = trait_name(lang, tr)
			tr.description = trait_description(lang, tr)
		if tr.has_meta("compact_str"):
			tr.remove_meta("compact_str")
	for dec_id in state.decisions_catalog.keys():
		var dec: EvoTypes.DecisionDef = state.decisions_catalog[dec_id]
		if dec.origin in ["catalog", "base"]:
			dec.name = decision_name(lang, dec)
			dec.description = decision_description(lang, dec)
		if dec.has_meta("compact_criterion"):
			dec.remove_meta("compact_criterion")
	if state.has_meta("dec_cat_hash"):
		state.remove_meta("dec_cat_hash")
	for strat_id in state.strategies_catalog.keys():
		var strat: EvoTypes.StrategyDef = state.strategies_catalog[strat_id]
		if strat.origin in ["base", "catalog"]:
			strat.name = strategy_text(strat.id, "name", strat.name, lang)
			strat.description = strategy_text(strat.id, "desc", strat.description, lang)

	var base_deme_names := {
		"deme-rift-west": "Western Forest Hominids" if is_en else "Homínidos del Bosque Occidental",
		"deme-rift-east": "Eastern Savanna Hominids" if is_en else "Homínidos de la Sabana Oriental",
		"deme-darwin-founder": "Western Island Founders" if is_en else "Fundadores Insulares del Oeste",
		"deme-darwin-rival": "Eastern Island Rivals" if is_en else "Rivales Insulares del Este",
		"deme-island-1": "Northern Quarry Clan" if is_en else "Clan de la Cantera Norte",
		"deme-island-2": "Southern Timber Clan" if is_en else "Clan Maderero del Sur"
	}
	var base_lineage_names := {
		"lineage-rift-west": "Western Rift Lineage" if is_en else "Linaje Occidental del Rift",
		"lineage-rift-east": "Eastern Rift Lineage" if is_en else "Linaje Oriental del Rift",
		"lineage-darwin-a": "Western Archipelago Lineage" if is_en else "Linaje Occidental del Archipiélago",
		"lineage-darwin-b": "Eastern Archipelago Lineage" if is_en else "Linaje Oriental del Archipiélago",
		"lineage-island-1": "Northern Quarry Lineage" if is_en else "Linaje de la Cantera Norte",
		"lineage-island-2": "Southern Timber Lineage" if is_en else "Linaje Maderero del Sur"
	}
	for did in state.demes.keys():
		var d: EvoTypes.Deme = state.demes[did]
		if base_deme_names.has(did):
			d.name = str(base_deme_names[did])
		elif base_lineage_names.has(d.lineage_id):
			var root_id := EvoSettlementPhase.strip_migration_suffix(str(did))
			if base_deme_names.has(root_id):
				if str(did).contains("-w"):
					d.name = "%s · %s (%s)" % [base_deme_names[root_id], "Warband" if is_en else "Horda", d.hex_id]
				else:
					d.name = "%s (%s)" % [base_deme_names[root_id], d.hex_id]

	for lid in state.lineage_tree.keys():
		if base_lineage_names.has(lid):
			(state.lineage_tree[lid] as EvoTypes.LineageNode).name = str(base_lineage_names[lid])


static func biome_name(lang: String, biome: String) -> String:
	return t(lang, "biome." + biome)


static func trait_name(lang: String, trait_def: EvoTypes.TraitDef) -> String:
	if trait_def is Object and trait_def.get("origin") != null and str(trait_def.get("origin")) not in ["catalog", "base"]:
		return str(trait_def.name)
	var key := "trait." + trait_def.id + ".name"
	var table: Dictionary = STRINGS[resolve_lang(lang)]
	if table.has(key):
		return str(table[key])
	return trait_def.name


static func trait_description(lang: String, trait_def: EvoTypes.TraitDef) -> String:
	if trait_def is Object and trait_def.get("origin") != null and str(trait_def.get("origin")) not in ["catalog", "base"]:
		return str(trait_def.description)
	var key := "trait." + trait_def.id + ".desc"
	var table: Dictionary = STRINGS[resolve_lang(lang)]
	if table.has(key):
		return str(table[key])
	return trait_def.description


static func decision_name(lang: String, dec_def: EvoTypes.DecisionDef) -> String:
	if dec_def is Object and dec_def.get("origin") != null and str(dec_def.get("origin")) not in ["catalog", "base"]:
		return str(dec_def.name)
	var key := "decision." + dec_def.id + ".name"
	var table: Dictionary = STRINGS[resolve_lang(lang)]
	if table.has(key):
		if dec_def.name != "" and dec_def.name != str(STRINGS["es"][key]) and dec_def.name != str(STRINGS["en"][key]):
			return dec_def.name
		return str(table[key])
	return dec_def.name


static func decision_description(lang: String, dec_def: EvoTypes.DecisionDef) -> String:
	if dec_def is Object and dec_def.get("origin") != null and str(dec_def.get("origin")) not in ["catalog", "base"]:
		return str(dec_def.description)
	var key := "decision." + dec_def.id + ".desc"
	var table: Dictionary = STRINGS[resolve_lang(lang)]
	if table.has(key):
		if dec_def.description != "" and dec_def.description != str(STRINGS["es"][key]) and dec_def.description != str(STRINGS["en"][key]):
			return dec_def.description
		return str(table[key])
	return dec_def.description


static func preset_title(lang: String, preset_id: String) -> String:
	return t(lang, "preset." + preset_id + ".name")
