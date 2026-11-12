# Thermodynamics & Bio-Cultural Catalog

Biological evolution, cultural traditions, and strategic doctrines in **Evolution** share a single 6-dimensional biophysical accounting system implemented in [`EvoThermodynamics`](https://github.com/arrase/Evolution/blob/main/src/core/thermodynamics.gd) and [`EvoCatalog`](https://github.com/arrase/Evolution/blob/main/src/core/catalog.gd). Every advantage requires a metabolic or ecological price—forcing lineages into genuine trade-offs rather than unrestricted stat stacking.

---

## 1. The 6-Axis Biophysical Vector & Thermodynamic Balance

Each trait, strategy, and living deme evaluates to an `EvoTypes.BiophysicalVector` storing six clamped axes (rounded to 4 decimal places via `round4`):

| Axis | Property | Bounds | Role in Simulation |
| :--- | :--- | :---: | :--- |
| **1. Metabolic Cost ($F$)** | `metabolic_cost` | `[-1.0, +1.0]` | Scales per-capita maintenance expenditure (`0.42 * pop * (1 + 0.55 * F + climate_stress)`). |
| **2. Extraction Efficiency ($E$)** | `extraction_efficiency` | `[-1.0, +1.0]` | Increases forage yields, agricultural (`crops`) / pastoral (`pasture`) rural harvest multipliers, and economic surplus. |
| **3. Ecological Impact ($C$)** | `ecological_impact` | `[-1.0, +1.0]` | Negative values degrade tile carrying capacity $K$; values $> 0.20$ actively regenerate local $K$. |
| **4. Spatial Mobility ($M$)** | `spatial_mobility` | `[-1.0, +1.0]` | Values $\ge 0.45$ unlock `high_mountain` passes (`altitude <= 0.88`) and extend colonization & trade corridors up to 3 hops. |
| **5. Social Cohesion ($I$)** | `social_cohesion` | `[-1.0, +1.0]` | Aids defense, diplomacy, cultural innovation, and cooperative coordination; higher values demand cognitive upkeep. |
| **6. Cultural Threshold** | `transmission_threshold` | `[0.0, 1.0]` | Modulates trait complexity and cultural diffusion cost. |

### Zero Decision Weighting (Direct Trait Summation)

A deme's instantaneous vector (`EvoCatalog.compute_deme_vector()` and `EvoPayoffs.vector()`) is strictly the **clamped sum of its active biological traits and cultural traditions**:

$$\mathbf{v}_{\text{deme}} = \text{clamp}\!\left(\sum_{t \in \text{Bio}(d)} \mathbf{v}_t + \sum_{t \in \text{Cul}(d)} \mathbf{v}_t\right)$$

Behavioral axes clamp to `[-1.0, +1.0]`, while `transmission_threshold` clamps to `[0.0, 1.0]`. Unlike older drafts, momentary behavioral intentions never alter physical phenotype vectors directly; behavior only alters anatomy over evolutionary time via the **Baldwin Effect** and **Cultural Innovation** milestones.

### Thermodynamic Budget (`BASE_BUDGET = 0.60`)

Custom traits authored in the Forge (`free_sandbox_mode = false`) or synthesized as emergent milestones must satisfy `EvoThermodynamics.evaluate_thermodynamics()`:

$$\text{PositiveAdvantages} = \max(0, E) + \max(0, M) + \max(0, I)$$

$$\text{CurrentCost} = F - \min(0, C)$$

$$\text{RequiredCost} = \begin{cases} 0.5 \cdot (\text{PositiveAdvantages} - 0.60) & \text{if } \text{PositiveAdvantages} > 0.60 \\ 0 & \text{otherwise} \end{cases}$$

When `CurrentCost < RequiredCost - 1e-6`, `validate_and_balance_thermodynamics()` automatically enforces balance by raising `metabolic_cost` up to `+1.0` and, if demand exceeds `+1.0`, spilling the remaining deficit negatively into `ecological_impact` down to `-1.0`. Enabling **Free Sandbox Mode** bypasses automatic coercion in the Forge.

---

## 2. Base Trait Catalog (11 Canonical Traits)

### Biological Traits (6)

Only biological traits setting `enables_cultural_transmission = true` unlock cultural learning (`EvoCatalog.deme_has_cultural_capacity()`). If both `bio-encephalization` and `bio-social-instinct` are lost or stripped, a deme's active `cultural_trait_ids` clear immediately.

| ID | Trait Name | Vector `(F, E, C, M, I, Thresh)` | Exclusions & Flags |
| :--- | :--- | :---: | :--- |
| `bio-r-strategy` | **r-Strategy** | `(-0.15, +0.20, -0.20, +0.25, -0.15, 0.05)` | Excludes `bio-k-strategy`. Fast `0.16` logistic growth, lower settling thresholds (`pop >= 65`, `E >= 32`). |
| `bio-k-strategy` | **K-Strategy** | `(+0.20, +0.25, +0.15, +0.05, +0.40, 0.30)` | Excludes `bio-r-strategy`. Slower `0.095` growth, `+0.14` sanitation bonus, `0.80x` wall fortify cost, higher settling bar (`pop >= 145`, `E >= 75`). |
| `bio-digestive-spec` | **Digestive Specialization** | `(+0.10, +0.45, +0.05, +0.15, 0.00, 0.10)` | Pure extraction specialization maximizing biomass conversion with slight metabolic weight. |
| `bio-thermal-tolerance` | **Thermal Tolerance** | `(+0.15, +0.20, +0.05, +0.45, +0.10, 0.10)` | Immediate `+0.45` spatial mobility (passing `high_mountain` on turn 0) and halving extreme temperature/aridity stress. |
| `bio-encephalization` | **Encephalization** | `(+0.45, +0.35, 0.00, +0.20, +0.45, 0.60)` | `enables_cultural_transmission = true`. Accelerates `innovate` counter progress (`0.37+` vs `0.15`). |
| `bio-social-instinct` | **Social Instinct** | `(+0.20, +0.20, +0.05, +0.10, +0.60, 0.45)` | `enables_cultural_transmission = true`. High cohesion enabler for organized defense, pacts, and cultural storage. |

### Cultural Traditions (5)

| ID | Tradition Name | Vector `(F, E, C, M, I, Thresh)` | Structural Synergies |
| :--- | :--- | :---: | :--- |
| `cul-fire-processing` | **Fire Processing** | `(-0.10, +0.35, -0.25, +0.10, +0.15, 0.40)` | Lowers maintenance cost via external cooking digestion at the price of timber extraction impact (`-0.25` eco). |
| `cul-extraction-tools` | **Extraction Tools** | `(+0.25, +0.65, -0.25, +0.10, +0.20, 0.50)` | Highest single-trait extraction jump (`+0.65`), driving steep resource harvest alongside ecological pressure. |
| `cul-communal-conservation` | **Communal Conservation** | `(+0.15, +0.25, +0.55, 0.00, +0.50, 0.55)` | Grants `+0.55` ecological restoration, `+0.20` sanitation salubrity, and `0.80x` (`20%` off) wall fortification cost. |
| `cul-interdeme-barter` | **Inter-Deme Barter** | `(+0.35, +0.40, +0.15, +0.30, +0.50, 0.60)` | Boosts bilateral trade multipliers (`1.25x` if one partner holds Barter, `1.45x` if both hold Barter). |
| `cul-warrior-expansion` | **Warrior Expansion** | `(+0.35, +0.35, -0.25, +0.45, +0.45, 0.35)` | Combines `+0.45` mobility and cohesion with `+0.35` extraction for offensive projection; slows `innovate` progress when paired without encephalization. |

---

## 3. Five Competing Strategies & Doctrines

Strategies package biological inheritance, cultural traditions, and a natural-language **`doctrine`** text passed to Ollama during decision evaluation:

| ID & Emblem | Strategy Name | Starting Traits | Clamped Vector `(F, E, C, M, I, Thresh)` |
| :--- | :--- | :--- | :---: |
| `strat-cooperation` `🤝` | **Cooperation** | `bio-k-strategy`, `bio-social-instinct`, `cul-communal-conservation` | `(+0.55, +0.70, +0.75, +0.15, +1.00, 1.00)` |
| `strat-expansion` `🧭` | **Expansion** | `bio-r-strategy`, `bio-thermal-tolerance`, `bio-social-instinct`, `cul-fire-processing` | `(+0.10, +0.95, -0.35, +0.90, +0.70, 1.00)` |
| `strat-trade` `⚖️` | **Trade** | `bio-k-strategy`, `bio-encephalization`, `cul-interdeme-barter` | `(+1.00, +1.00, +0.30, +0.55, +1.00, 1.00)` |
| `strat-war` `⚔️` | **War** | `bio-r-strategy`, `bio-social-instinct`, `cul-warrior-expansion`, `cul-extraction-tools` | `(+0.65, +1.00, -0.65, +0.90, +1.00, 1.00)` |
| `strat-innovation` `🔬` | **Innovation** | `bio-encephalization`, `bio-digestive-spec`, `cul-fire-processing`, `cul-extraction-tools` | `(+0.70, +1.00, -0.45, +0.55, +0.80, 1.00)` |

Custom strategies created in the **3-Tab Bio-Cultural Forge** (`Strategies`, `Biological Traits`, `Cultural Traditions`)—along with custom traits and edited `Doctrine` prompts—persist between runs in `~/.config/Evolution/user_catalog.json` via `EvoUserSettings`. Decisions are no longer editable in the Forge UI (`user_catalog.json` stores `strategies` and `traits` only).

---

## 4. Sixteen-Action Decision Catalog Reference

`EvoCatalog.create_base_decisions_catalog()` registers **16 concrete decisions** matching the simulation's action menu and grouped under 11 `EvoTypes.ARCHETYPES`:

| Decision ID | Archetype | Reference Vector `(F, E, C, M, I, Thresh)` |
| :--- | :--- | :---: |
| `forage` | `forage` | `(+0.10, +0.35, +0.10, 0.00, +0.05, 0.05)` |
| `intensify` | `overexploit` | `(+0.25, +0.85, -0.65, 0.00, -0.10, 0.10)` |
| `fortify` | `cooperate` | `(+0.20, +0.10, 0.00, -0.20, +0.55, 0.20)` |
| `innovate` | `innovate` | `(+0.22, +0.42, +0.15, +0.40, +0.35, 0.65)` |
| `settle` | `migrate` | `(+0.30, +0.15, +0.15, +0.75, +0.05, 0.10)` |
| `trade` | `exchange` | `(+0.30, +0.50, +0.20, +0.20, +0.60, 0.45)` |
| `aid` | `cooperate` | `(+0.15, +0.20, +0.20, 0.00, +0.70, 0.35)` |
| `offer_pact` | `pact` | `(+0.10, +0.20, +0.10, +0.05, +0.65, 0.35)` |
| `accept_pact` | `pact` | `(+0.10, +0.20, +0.10, +0.05, +0.65, 0.35)` |
| `demand_tribute` | `dispute` | `(+0.30, +0.40, -0.10, +0.20, -0.15, 0.15)` |
| `pay_tribute` | `exchange` | `(+0.10, +0.10, +0.05, 0.00, +0.30, 0.20)` |
| `raid` | `raid` | `(+0.42, +0.48, -0.22, +0.35, -0.25, 0.15)` |
| `betray` | `betrayal` | `(+0.40, +0.55, -0.20, +0.25, -0.45, 0.15)` |
| `conquer` | `war` | `(+0.50, +0.45, -0.30, +0.55, +0.10, 0.20)` |
| `unite` | `pact` | `(+0.15, +0.30, +0.15, 0.00, +0.75, 0.40)` |
| `accept_union` | `pact` | `(+0.15, +0.30, +0.15, 0.00, +0.75, 0.40)` |

These reference vectors shape emergent trait synthesis during Baldwin assimilation and document behavioral archetypes; actual turn mechanics resolve deterministically in the biophysical subphases.

---

## 5. Emergent Evolution & Cultural Archetypes

Every generation, `EvoMilestonePhase.run_milestone_phase()` checks all living demes across three prioritized evolutionary triggers and activates **at most one highest-priority milestone** per turn:

1. **Priority 0 &mdash; Allopatric Speciation (`allopatric_speciation`)**:
   - **Condition**: `isolation_turns >= 10`, `< 3` emergent biological traits owned, and the deme is spatially separated from its lineage founder hex (`founder_cell == null` or `not deme.urban_hex_ids.has(founder_cell.id)`).
   - **Result**: Synthesizes `Allopatric Divergence (<biome>)` `(0.18, 0.35, 0.10, 0.30, 0.20, 0.20)` (thermodynamically validated), spawns a new child `LineageNode`, selects an unused clade hue from the 8-color `SPECIATION_PALETTE`, and resets `isolation_turns = 0`.
2. **Priority 1 &mdash; Baldwin Assimilation (`baldwin_assimilation`)**:
   - **Condition**: Any non-`forage` action counter in `baldwin_counters` reaches `>= 8` and `< 3` emergent biological traits owned.
   - **Result**: Synthesizes `Adaptive Homeostasis (<biome>)` by scaling the dominant decision's reference vector (`0.70 * cost`, `0.80 * extract`, `0.60 * eco`, `0.80 * mob`, `0.80 * coh`, `0.80 * thresh`), passes it through `validate_and_balance_thermodynamics`, appends the emergent biological trait, and zeroes that action's counter.
3. **Priority 2 &mdash; Cultural Innovation (`cultural_innovation`)**:
   - **Condition**: `innovation_counter >= 1.0`, cultural capacity enabled, emergent cultural traits `< 3` (`EvoActionMenu.MAX_EMERGENT_CULTURAL`), and `last_energy_delta >= 0.0 or energy_reserves >= 35.0`.
   - **Result**: Scores **6 `CULTURAL_ARCHETYPES`** against Baldwin history, fortification tier, traits, and biome (penalizing already-owned archetypes by `-100.0`), balances thermodynamically, grants the winning tradition (`origin = "emergent"`), and subtracts `1.0` from `innovation_counter`:

| Archetype ID | Cultural Tradition Base Name | Raw Vector `(F, E, C, M, I, Thresh)` | Primary Trigger Synergies |
| :--- | :--- | :---: | :--- |
| `agrarian` | **Agrarian Terrace Tradition** | `(+0.08, +0.34, +0.12, +0.08, +0.16, 0.32)` | `intensify`, `innovate`, `strat-innovation` |
| `wayfinder` | **Wayfinder Navigation** | `(+0.08, +0.18, +0.08, +0.38, +0.14, 0.30)` | `settle`, `strat-expansion`, `coastal_shallows` |
| `masonry` | **Fortified Masonry** | `(+0.07, +0.20, +0.16, +0.06, +0.34, 0.34)` | `fortify`, `defense_tier`, `bio-k-strategy` |
| `mercantile` | **Mercantile Guild Charter** | `(+0.06, +0.24, +0.10, +0.24, +0.28, 0.28)` | `trade`, `strat-trade`, `cul-interdeme-barter` |
| `martial` | **Martial Vanguard Code** | `(+0.14, +0.26, -0.08, +0.34, +0.22, 0.30)` | `raid`, `conquer`, `demand_tribute`, `betray`, `strat-war` |
| `agroforestry` | **Communal Agroforestry** | `(+0.05, +0.24, +0.30, +0.08, +0.28, 0.32)` | `aid`, `offer_pact`, `accept_pact`, `unite`, `strat-cooperation` |

---

## 6. Village Tiers & Vital States

Demographic strength and defenses project into four discrete architectural **Village Tiers** (`EvoTypes.Deme.get_village_tier()`):

| Tier | Roman Label | Elevation Criteria |
| :---: | :---: | :--- |
| **Tier 1** | `I` | Baseline band / hamlet (`pop < 120` and `defense_tier == 0`) |
| **Tier 2** | `II` | `pop >= 120` **or** `defense_tier >= 1` |
| **Tier 3** | `III` | `pop >= 240` **or** (`pop >= 170` **and** (`defense_tier >= 1` or `merged_count >= 1`)) |
| **Tier 4** | `IV` | `pop >= 380` **or** (`pop >= 280` **and** (`defense_tier >= 2` or `merged_count >= 1` or `urban_hex_ids.size() > 1`)) |

Simultaneously, `EvoTypes.Deme.get_vital_status()` classifies metabolic health in strict priority order:

1. **`extinct`**: `population <= 0`
2. **`starving`**: `energy_reserves < 25.0 or last_energy_delta <= -10.0`
3. **`thriving`**: `(last_energy_delta >= 10.0 and energy_reserves >= 40.0) or energy_reserves >= 120.0`
4. **`declining`**: `last_energy_delta < -5.0` *(labeled in the HUD UI as **`Struggling`** in English / **`En apuros`** in Spanish)*
5. **`stable`**: All intermediate steady states
