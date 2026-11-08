# 6-Axis Thermodynamics, Evolutionary Strategies & Trait Catalog

Every biological adaptation, cultural tradition, behavioral decision, and founding **Evolutionary Strategy** (`EvoTypes.StrategyDef`) in **Evolution** is governed by a standardized **6-Axis Biophysical Vector** (`EvoTypes.BiophysicalVector`). Rather than hardcoding ad-hoc special cases for individual traits, the simulation enforces a universal **Law of Thermodynamic Conservation** (`EvoThermodynamics`): no organism or society can evolve "free" advantages in caloric extraction, mobility, or social cohesion without paying commensurate energetic or ecological costs.

---

## Evolutionary Strategies (`StrategyDef`) & Default Archetypes

An **Evolutionary Strategy** (`EvoTypes.StrategyDef`) defines the founding bio-cultural identity for one side of a **1v1 Strategy Duel** (`state.strategy_a_id` vs. `state.strategy_b_id`). Each strategy bundles a curated set of compatible biological adaptations (`biological_trait_ids`) and cultural traditions (`cultural_trait_ids`) together with a visual emblem (`icon`) and color swatch (`color`).

### 1. Compatibility Rules & Cultural Substrate Enforcement
When a strategy is constructed in the **Forge (`EvoLabModal`)** or applied to a founding deme via `EvoCatalog.apply_strategy_to_deme(state, deme, strategy_id, lang)`:

* **Bidirectional $r/K$ Mutual Exclusion**: `bio-r-strategy` and `bio-k-strategy` represent opposite life-history poles (`mutually_exclusive_with`) and cannot coexist in the same strategy or deme. Selecting one in the Strategy Builder automatically unchecks the other.
* **Cultural Capacity Prerequisite (`enables_cultural_transmission`)**: Cultural traditions (`cul-*`) require at least one biological trait with `enables_cultural_transmission == true` (`bio-encephalization` or `bio-social-instinct`). When `apply_strategy_to_deme` assigns traits to a deme, it verifies `EvoCatalog.deme_has_cultural_capacity(deme, state.traits_catalog)`; if no biological trait enables culture, `deme.cultural_trait_ids` is cleared to `[]`.
* **Lineage & Deme Synchronization**: Applying a strategy sets `deme.strategy_id`, `deme.color`, `deme.biological_trait_ids`, and `deme.cultural_trait_ids`, and synchronizes the deme's `LineageNode` (`lin.strategy_id`, `lin.color`, `lin.biological_trait_ids`, `lin.cultural_trait_ids`, and `lin.acquired_trait_ids`).

### 2. Combined Strategy Biophysical Footprint (`compute_strategy_vector`) & Decision Affinities (`compute_strategy_baseline_probabilities`)
A strategy's baseline 6-axis footprint (`EvoCatalog.compute_strategy_vector(strategy, traits_catalog)`) is computed by summing the vectors of all included biological and cultural traits and clamping via `EvoThermodynamics.clamp_vector` (axes 1–5 in $[-1.0, +1.0]$, `transmission_threshold` in $[0.0, +1.0]$):

$$\mathbf{v}_{\text{strat}}(S) = \text{clamp}_{[-1.0, 1.0]}\left(\sum_{b \in S.\text{bio}} \mathbf{v}_b + \sum_{c \in S.\text{cul}} \mathbf{v}_c\right)$$

In addition, `EvoCatalog.compute_baseline_decision_weights(bio_ids, cul_ids, traits_catalog, decisions_catalog)` and `EvoCatalog.compute_strategy_baseline_probabilities(strategy, traits_catalog, decisions_catalog)` compute the intrinsic behavioral affinity distribution induced by a deme's or strategy's biological and cultural traits (coupling explicit trait affinities—such as `cul-warrior-expansion` boosting `dec-territorial-dispute` $+1.60$ and `dec-selective-migration` $+0.80$, `cul-communal-conservation` boosting `dec-cooperate-store` $+1.50$, or `cul-interdeme-barter` boosting `dec-exchange-symbiosis` $+1.65$—with 6-axis vector alignment).

### 3. The 5 Base Archetypal Strategies (`EvoCatalog.create_base_strategies_catalog`)

By default, every scenario starts with `DEFAULT_STRATEGY_A_ID = "strat-cooperation"` (🤝) vs. `DEFAULT_STRATEGY_B_ID = "strat-war"` (⚔️), and players can mix and match any of the 5 base archetypes or custom user strategies (`origin = "user"` persisted in `~/.config/Evolution/user_catalog.json`):

| Strategy ID | Emblem & Name (EN / ES) | Hex Color | Included Biological Traits (`bio-*`) | Included Cultural Traits (`cul-*`) | Combined Biophysical Footprint<br>`(Cost, Extr, Eco, Mob, Coh, Thr)` | Evolutionary Philosophy & Gameplay Role |
| :--- | :--- | :---: | :--- | :--- | :---: | :--- |
| `strat-cooperation` | 🤝 **Cooperative Alliance**<br>*Alianza Cooperativa* | `#10B981` | `bio-k-strategy`<br>`bio-social-instinct` | `cul-communal-conservation` | `(+0.55, +0.70, +0.75, +0.15, +1.00, 1.00)` | **Ecological Stewardship, Stability & Pacts**: Fosters maximum social cohesion (`+1.00`), communal habitat regeneration (`+0.75` eco), formal Alliance Pacts, and $K$-selected demographic buffering. |
| `strat-expansion` | 🧭 **Expansionist Pioneers**<br>*Pioneros Expansionistas* | `#3B82F6` | `bio-r-strategy`<br>`bio-thermal-tolerance`<br>`bio-social-instinct` | `cul-fire-processing` | `(+0.10, +0.95, -0.35, +0.90, +0.70, 1.00)` | **Rapid Dispersal & Barrier Crossing**: Combines density-dependent $r$-selected fecundity ($\times 1.28$ at low crowding) with high mobility (`+0.90`) and cooking efficiency (`+0.10` net cost) to colonize mountains and islands. |
| `strat-trade` | ⚖️ **Merchant League**<br>*Liga Mercantil* | `#F59E0B` | `bio-k-strategy`<br>`bio-encephalization` | `cul-interdeme-barter` | `(+1.00, +1.00, +0.30, +0.55, +1.00, 1.00)` | **Commercial Symbiosis & Cultural Hub**: High-cognition diplomatic network that unlocks $+20\%$ to $+35\%$ inter-cell border symbiosis surpluses, Alliance Pacts, sustainable ecology (`+0.30`), and rapid horizontal cultural diffusion. |
| `strat-war` | ⚔️ **Conquering Horde**<br>*Horda Conquistadora* | `#EF4444` | `bio-r-strategy`<br>`bio-social-instinct` | `cul-warrior-expansion`<br>`cul-extraction-tools` | `(+0.75, +1.00, -0.75, +0.90, +1.00, 1.00)` | **Martial Dominance, Raids & Conquest**: Wages territorial wars of conquest, launches cross-border plunder raids, and dominates inter-cell Hawk-Dove border disputes with maximum extraction (`+1.00`) and mobility (`+0.90`), at severe ecological cost (`-0.75`). |
| `strat-innovation` | 🔬 **Innovator Technocrats**<br>*Tecnócratas Innovadores* | `#A855F7` | `bio-encephalization`<br>`bio-digestive-spec` | `cul-fire-processing`<br>`cul-extraction-tools` | `(+0.70, +1.00, -0.45, +0.55, +0.80, 1.00)` | **Cognitive & Technological Acceleration**: Pairs neocortical expansion and omnivorous digestion with thermal processing and toolkits to maximize extraction (`+1.00`) and cumulative innovation. |

---

## The 6-Axis Biophysical Vector (`BiophysicalVector`)

Each vector consists of six floating-point axes rounded to $4$ decimal places (`snappedf(x, 0.0001)`):

| Axis # | Field (`types.gd`) | JSON Key | Bounds | Biophysical Meaning & Simulation Impact |
| :---: | :--- | :--- | :---: | :--- |
| **1** | `metabolic_cost` | `metabolicCost` | $[-1.0, +1.0]$ | **Caloric Expenditure**: Scales per-capita resting and active metabolic consumption $C_{\text{metabolic}}$. Negative values represent metabolic savings (e.g., `cul-fire-processing` externalizing digestion). |
| **2** | `extraction_efficiency` | `extractionEfficiency` | $[-1.0, +1.0]$ | **Biomass Harvesting Yield**: Scales a deme's caloric demand $D_i = P_i \cdot 0.50 \cdot (1.0 + 0.60 \cdot v_{\text{eff}}.\text{extraction\_efficiency})$ when harvesting hex resources $R$. |
| **3** | `ecological_impact` | `ecologicalImpact` | $[-1.0, +1.0]$ | **Habitat $K$ Footprint**: Negative values degrade local carrying capacity $K$ (`K * (1 + 0.18 * sum_eco_impact)`), whereas positive values (`> +0.10`, e.g., `cul-communal-conservation`) actively regenerate $K$ (`+5% * sum_eco_impact`). |
| **4** | `spatial_mobility` | `spatialMobility` | $[-1.0, +1.0]$ | **Dispersal & Barrier Traversal**: Determines maximum traversable elevation ($\text{altitude} - 0.50 \le v_{\text{eff}}.\text{spatial\_mobility}$) and buffers extreme thermal metabolic penalties ($|T_{\text{cell}}|$). |
| **5** | `social_cohesion` | `socialCohesion` | $[-1.0, +1.0]$ | **Coordination & Altruism**: Governs Dove resistance against inter-cell Hawk border resource capture, and unlocks horizontal cultural absorption across shared hex borders when $v_{\text{eff}}.\text{social\_cohesion} \ge \text{trait.transmission\_threshold}$. |
| **6** | `transmission_threshold` | `transmissionThreshold` | $[0.0, +1.0]$ | **Cognitive & Social Complexity**: Minimum receiver `social_cohesion` required to absorb a cultural trait via Inter-Cell Symbiosis, and determines which complex cultural trait is lost first during a demographic bottleneck ($P < 50$ or $-50\%$ pop loss). |

---

## Thermodynamic Conservation Law (`EvoThermodynamics`)

To prevent overpowered "super-traits" (whether synthesized during evolutionary milestones or crafted by players in the **Trait & Decision Forge**), `EvoThermodynamics` enforces a strict energetic budget with constant `BASE_BUDGET = 0.60`.

```mermaid
flowchart LR
    Vec["Input 6-Axis Vector v"] --> Clamp["1. Clamp & Snap (round4)\nAxes 1–5 ∈ [-1.0, +1.0]\nAxis 6 ∈ [0.0, +1.0]"]
    Clamp --> Adv["2. Positive Advantages A⁺\nmax(0, extract) + max(0, mobility)\n+ max(0, cohesion)"]
    Adv --> Check{"A⁺ <= 0.60\nOR C_curr >= C_req?"}
    Check -- "Yes (Balanced)" --> Valid["Vector Approved Unchanged"]
    Check -- "No (Deficit)" --> Balance["3. Auto-Balance Cost\nRaise metabolic_cost up to 1.0;\nSpill excess into -ecological_impact"]
    Balance --> Valid
```

### 1. Positive Advantages ($A^+$)
The sum of positive functional capabilities across extraction, mobility, and social cohesion:

$$A^+ = \text{round4}\Big(\max(0,\ \text{extraction\_efficiency}) + \max(0,\ \text{spatial\_mobility}) + \max(0,\ \text{social\_cohesion})\Big)$$

### 2. Current Cost ($C_{\text{curr}}$) & Required Cost ($C_{\text{req}}$)
Any positive advantage exceeding `BASE_BUDGET = 0.60` requires $50\%$ of the excess to be paid in combined **metabolic cost** and/or **negative ecological impact**:

$$C_{\text{curr}} = \text{round4}\Big(\text{metabolic\_cost} - \min(0,\ \text{ecological\_impact})\Big)$$

$$C_{\text{req}} = \begin{cases} \text{round4}\big(0.50 \times (A^+ - 0.60)\big) & \text{if } A^+ > 0.60 \\ 0.0 & \text{otherwise} \end{cases}$$

$$\text{is\_balanced} \iff (A^+ \le 0.60) \;\lor\; (C_{\text{curr}} \ge C_{\text{req}} - 10^{-6})$$

### 3. Automatic Vector Balancing (`validate_and_balance_thermodynamics`)
When `is_balanced` is `false` (and `free_sandbox_mode` is disabled), the engine automatically adjusts the vector by raising `metabolic_cost` first and subtracting any excess above `1.0` directly from `ecological_impact`:

$$\text{target\_metabolic} = C_{\text{req}} + \min(0,\ \text{ecological\_impact})$$

$$\text{metabolic\_cost}' = \text{clamp}_{[-1.0, 1.0]}\big(\text{round4}(\text{target\_metabolic})\big)$$

$$\text{ecological\_impact}' = \begin{cases} \text{clamp}_{[-1.0, 1.0]}\big(\text{round4}\big(\text{ecological\_impact} - (\text{target\_metabolic} - 1.0)\big)\big) & \text{if } \text{target\_metabolic} > 1.0 \\ \text{ecological\_impact} & \text{otherwise} \end{cases}$$

---

## Effective Deme Vector Aggregation

During Phase 3 (`EvoEcologyInteraction.compute_effective_vector`), a deme's effective 6-axis profile $\mathbf{v}_{\text{eff}}$ is computed by summing all active biological traits, all active cultural traditions, and the expectation over its behavioral decision probability distribution $P(d)$, then clamping to $[-1.5, +1.5]$ ($[0.0, +1.5]$ for `transmission_threshold`):

$$\mathbf{v}_{\text{eff}}(\text{deme}) = \text{clamp}_{[-1.5, 1.5]}\left(\sum_{b \in T_{\text{bio}}} \mathbf{v}_b + \sum_{c \in T_{\text{cul}}} \mathbf{v}_c + \sum_{d \in D} P(d) \cdot \mathbf{v}_d\right)$$

---

## Complete Biological Traits Catalog (`bio-*`) & Ring 1 Modules

Biological traits represent genetically heritable life-history strategies, physiological adaptations, and neuroanatomical structures defined in `EvoCatalog.create_base_traits_catalog`, each manifesting visually in the settlement's **Ring 1 Trait Crown** (`EvoPropFloraRenderer.TRAIT_MODULE_MAP`):

| Trait ID | Name (EN / ES) | Ring 1 Module | Cost | Extract | Eco | Mobility | Cohesion | Threshold | Exclusive With | Enables Culture | Biophysical & Evolutionary Role |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| `bio-r-strategy` | **r-Strategy (Prolific)**<br>*Estrategia r (Prolífica)* | `brood_totem` | `-0.15` | `+0.20` | `-0.20` | `+0.25` | `-0.15` | `0.05` | `bio-k-strategy` | No | Boosts demographic growth rate via a density-dependent multiplier (**$\times 1.28$** when crowding $< 0.55$, **$\times 1.16$** when $< 0.65$, **$\times 1.05$** when $\ge 0.65$) and lowers metabolic cost, accelerating colonization at the expense of habitat impact. |
| `bio-k-strategy` | **K-Strategy (Longevity & Parental Care)**<br>*Estrategia K (Longevidad y Cuidado Parental)* | `terraced_sanctuary` | `+0.20` | `+0.25` | `+0.15` | `+0.05` | `+0.40` | `0.30` | `bio-r-strategy` | No | Moderates demographic swings ($\times 0.88$ growth/decline multiplier), improves ecological stewardship (`+0.15`), strengthens social cohesion (`+0.40`), and grants a **$15\%$ cost discount** on Multi-Tier Defense fortifications. |
| `bio-digestive-spec` | **Omnivorous Digestive Specialization**<br>*Especialización Digestiva Omnívora* | `granary_silo` | `+0.10` | `+0.45` | `+0.05` | `+0.15` | `0.00` | `0.10` | *None* | No | Enzymatic plasticity that substantially increases caloric extraction (`+0.45`) across diverse flora and fauna with minimal metabolic overhead (`+0.10`). |
| `bio-thermal-tolerance` | **Thermal & Hydric Tolerance**<br>*Tolerancia Térmica e Hídrica* | `hearth_circle` | `+0.15` | `+0.20` | `+0.05` | `+0.45` | `+0.10` | `0.10` | *None* | No | High spatial mobility (`+0.45`) that unlocks high-altitude mountain passes and mitigates thermal metabolic penalties in Tundra and Arid Steppe biomes. |
| `bio-encephalization` | **Encephalization (Costly Neural Tissue)**<br>*Encefalización (Tejido Neural Costoso)* | `crystal_obelisk` | `+0.45` | `+0.35` | `0.00` | `+0.20` | `+0.45` | `0.60` | *None* | **Yes** | Steep resting metabolic cost (`+0.45`) for neocortical expansion; unlocks cumulative cultural traditions, `dec-exchange-symbiosis`, and tool innovation. |
| `bio-social-instinct` | **Instinctive Sociability (Gregariousness)**<br>*Sociabilidad Instintiva (Gregarismo)* | `monolith` | `+0.20` | `+0.20` | `+0.05` | `+0.10` | `+0.60` | `0.45` | *None* | **Yes** | Neuroendocrine predisposition toward kin altruism (`+0.60` social cohesion) at moderate energetic cost (`+0.20`); unlocks cultural transmission and symbiosis. |

!!! warning "Bidirectional Mutual Exclusion (`r` vs. `K` Strategy)"
    `bio-r-strategy` and `bio-k-strategy` are mutually exclusive life-history poles. Injecting `bio-r-strategy` into a village via `EvoCatalog.inject_trait_into_deme` automatically strips `bio-k-strategy` (and vice versa). Furthermore, if removing a biological trait leaves a deme with neither `bio-encephalization` nor `bio-social-instinct`, all active cultural traditions are cleared because the population loses its cognitive/social substrate (`enables_cultural_transmission`).

---

## Complete Cultural Traditions Catalog (`cul-*`) & Ring 1 Modules

Cultural traditions require at least one biological trait with `enables_cultural_transmission = true` (`bio-encephalization` or `bio-social-instinct`). Unlike genetic traits, cultural traditions can diffuse **horizontally** across shared hex borders between trading demes during Symbiosis and can be **lost** during demographic bottlenecks:

| Trait ID | Name (EN / ES) | Ring 1 Module | Cost | Extract | Eco | Mobility | Cohesion | Threshold | Biophysical & Socio-Ecological Role |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| `cul-fire-processing` | **Fire & Thermal Food Processing**<br>*Fuego y Procesado Térmico de Alimentos* | `hearth_circle` | `-0.10` | `+0.35` | `-0.25` | `+0.10` | `+0.15` | `0.40` | Externalizes digestion through cooking, lowering `metabolic_cost` (`-0.10`) and raising caloric extraction (`+0.35`) at the cost of fuelwood depletion (`-0.25` eco). |
| `cul-extraction-tools` | **Specialized Extraction Tools**<br>*Herramientas de Extracción Especializadas* | `lithic_workshop` | `+0.25` | `+0.65` | `-0.25` | `+0.10` | `+0.20` | `0.50` | Cumulative lithic/organic toolkit that massively amplifies extraction (`+0.65`) and triggers the `tech_overexploit` behavioral branch unless paired with conservation norms. |
| `cul-communal-conservation` | **Communal Conservation Norms**<br>*Normas de Conservación Comunal* | `grove_shrine` | `+0.15` | `+0.25` | `+0.55` | `0.00` | `+0.50` | `0.55` | Institutionalized harvesting quotas and taboos (`+0.55` `ecological_impact`, `+0.50` `social_cohesion`) that prevent the *Tragedy of the Commons*, actively rebuild $K$, and grant a **$15\%$ cost discount** on Multi-Tier Defense fortifications. |
| `cul-interdeme-barter` | **Inter-Deme Barter Networks**<br>*Redes de Trueque Inter-Deme* | `caravan_depot` | `+0.35` | `+0.40` | `+0.15` | `+0.30` | `+0.50` | `0.60` | Diplomatic and trade protocols that raise extraction (`+0.40`), mobility (`+0.30`), and social cohesion (`+0.50`), accelerating horizontal cultural diffusion and complementary inter-biome trade surpluses (up to $1.35\times$). |
| `cul-warrior-expansion` | **Warrior / Expansionist Tradition**<br>*Tradición Guerrera / Expansionista* | `war_brazier` | `+0.45` | `+0.30` | `-0.35` | `+0.45` | `+0.60` | `0.45` | High-cohesion (`+0.60`), high-mobility (`+0.45`) militarized organization that drives territorial wars, plunder raids, and inter-cell Hawk-Dove dominance at severe metabolic (`+0.45`) and ecological (`-0.35`) cost. |

---

## Complete Behavioral Decisions Catalog (`dec-*`) & Ring 0 Citadel Styles

Every generation, the cognitive engine assigns a normalized probability distribution $P(d)$ ($\sum_{d} P(d) = 1.0$) over the eligible decisions in `EvoCatalog.create_base_decisions_catalog`, shaping the settlement's **Ring 0 Citadel** (`EvoPropFloraRenderer.ARCHETYPE_STYLE_MAP`):

| Decision ID | Archetype & Ring 0 Citadel | Name (EN / ES) | Cost | Extract | Eco | Mobility | Cohesion | Threshold | Required Traits (Any) | Behavioral Profile & Simulation Effect |
| :--- | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `dec-conservative-forage` | `forage`<br>(`forage_lodge`) | **Conservative Foraging**<br>*Forrajeo Conservador* | `+0.10` | `+0.35` | `+0.10` | `0.00` | `+0.05` | `0.05` | *None* | Default low-risk gathering within local regeneration limits; does not increment Baldwin counters. |
| `dec-intensive-overexploit` | `overexploit`<br>(`furnace_rig`) | **Intensive Overexploitation**<br>*Sobreexplotación Intensiva* | `+0.25` | `+0.85` | `-0.65` | `0.00` | `-0.10` | `0.10` | *None* | Maximizes immediate caloric intake (`+0.85`) while severely degrading habitat carrying capacity $K$ (`-0.65`); contributes to raid and betrayal propensity. |
| `dec-selective-migration` | `migrate`<br>(`nomad_pavilion`) | **Selective Migration**<br>*Migración Selectiva* | `+0.30` | `+0.15` | `+0.15` | `+0.75` | `+0.05` | `0.10` | *None* | High spatial mobility (`+0.75`) that boosts migration reach ($+0.25 \cdot P(\text{"migrate"})$) and drives empty-hex population fission or martial territorial invasion. |
| `dec-cooperate-store` | `cooperate`<br>(`amphitheater_dome`) | **Cooperation & Storage**<br>*Cooperación y Almacenamiento* | `+0.25` | `+0.45` | `+0.15` | `-0.10` | `+0.65` | `0.35` | *None* | Collective resource pooling and food preservation; contributes $0.35 \cdot P(\text{"cooperate"})$ to cultural innovation, fosters **Alliance Pacts**, **Defensive Coalitions**, **Ring 2 Fortifications** (`defense_tier` 1–3), and **City Unification (Synoecism)**. |
| `dec-exchange-symbiosis` | `exchange`<br>(`twin_canopy_market`) | **Exchange / Symbiosis**<br>*Intercambio / Simbiosis* | `+0.35` | `+0.50` | `+0.20` | `+0.20` | `+0.60` | `0.45` | `bio-encephalization` OR `bio-social-instinct` | Unlocks **$1.20\times\text{–}1.35\times$ inter-cell complementary trade surplus** ($+12\%$ inter-biome, $+8\%$ cross-cultural), horizontal cultural trait transmission across borders, **Tribute Appeasement**, and formal **Alliance Pacts** / **Synoecism**. |
| `dec-territorial-dispute` | `dispute`<br>(`horned_war_keep`) | **Territorial Dispute**<br>*Disputa Territorial* | `+0.55` | `+0.40` | `-0.30` | `+0.25` | `+0.55` | `0.20` | *None* | Agonistic **Hawk** strategy ($P(\text{"dispute"}) \ge 0.25$); annexes adjacent Dove border resources, triggers **Plunder Raids** and **Wars of Conquest**, or causes inter-cell Hawk-Hawk border clashes ($-15\%$ pop, $\times 1.25$ metabolic cost). |
| `dec-explore-innovate` | `innovate`<br>(`astronomical_spire`) | **Exploration / Innovation**<br>*Exploración / Innovación* | `+0.50` | `+0.15` | `0.00` | `+0.40` | `+0.35` | `0.65` | *None* | High-cost (`+0.50`) experimentation that sacrifices immediate foraging yield (`+0.15`) to rapidly advance `innovation_counter`. |

---

## Emergent Milestone Traits (`origin = "emergent"`)

When a deme achieves an evolutionary milestone during Phase 4 (`EvoMilestonePhase.run_milestone_phase`), `EvoHeuristicScorer.synthesize_milestone_trait` dynamically generates a new biome-contextualized trait, validates it through `EvoThermodynamics.validate_and_balance_thermodynamics`, and registers it into `state.traits_catalog`:

| Milestone Trigger | Synthesized Category | Generated Name Pattern (EN / ES) | Cost | Extract | Eco | Mobility | Cohesion | Threshold | Thermodynamic Verification |
| :--- | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| `allopatric_speciation` | `biological` | **Allopatric Divergence (\<Biome\>)**<br>*Divergencia Alopátrica (\<Bioma\>)* | `+0.18` | `+0.35` | `+0.10` | `+0.30` | `+0.20` | `0.20` | $A^+ = 0.85 \Rightarrow C_{\text{req}} = 0.125 \le 0.18$ (Balanced) |
| `baldwin_assimilation` | `biological` | **Adaptive Homeostasis (\<Biome\>)**<br>*Homeostasis Adaptativa (\<Bioma\>)* | $\max(0.10,\ 0.70 d_{\text{cost}})$ | $\text{clamp}(\max(0.15,\ 0.80 d_{\text{ext}}), 0, 0.85)$ | $\text{clamp}(0.60 d_{\text{eco}}, -0.50, 0.50)$ | $\text{clamp}(\max(0,\ 0.80 d_{\text{mob}}), 0, 0.85)$ | $\text{clamp}(\max(0.05,\ 0.80 d_{\text{coh}}), 0, 0.85)$ | `0.20` | Derived proportionally from the assimilated `baldwin_decision_id` vector $\mathbf{v}_d$ (or fallback `(+0.18, +0.35, +0.10, +0.30, +0.20, 0.20)`) and auto-balanced via `validate_and_balance_thermodynamics` |
| `cultural_innovation` | `cultural` | **Cooperative Ecological Tradition (\<Biome\>)**<br>*Tradición Ecológica Cooperativa (\<Bioma\>)* | `+0.20` | `+0.35` | `+0.20` | `+0.15` | `+0.40` | `0.45` | $A^+ = 0.90 \Rightarrow C_{\text{req}} = 0.150 \le 0.20$ (Balanced) |

---

## Unified Vital Status System (`Deme.get_vital_status`)

Both the UI (`EvoHudInspectorPanel`, `EvoWorldOverlayRenderer`) and the Cognitive Engine (`EvoHeuristicScorer._compute_vital_status`) evaluate each deme's physiological state via a unified 5-state classification based on `population`, `energy_reserves` ($E$), and `last_energy_delta` ($\Delta E$):

| Vital Status ID | Condition (`types.gd` & `heuristic_scorer.gd`) | Meaning & Simulation Impact |
| :--- | :--- | :--- |
| `"extinct"` | `population <= 0` | Population has collapsed; excluded from biophysical and cognitive processing. |
| `"starving"` | `energy_reserves < 25.0` **OR** `last_energy_delta <= -10.0` | Severe caloric deficit; triggers emergency migration, distress aid from pact allies, or opportunistic betrayal/raids. |
| `"thriving"` | `(last_energy_delta >= 10.0 and energy_reserves >= 40.0)` **OR** `energy_reserves >= 120.0` | Energetic abundance; favors demographic growth, cooperative storage, innovation, and martial expansion. |
| `"declining"` | `last_energy_delta < -5.0` *(and not `"starving"`)* | Moderate caloric contraction; shifts environmental decision weights toward selective migration or adaptive foraging. |
| `"stable"` | Otherwise | Homeostatic balance between caloric intake and metabolic expenditure. |
