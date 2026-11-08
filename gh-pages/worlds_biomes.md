# Worlds, Biomes & Scientific Presets

**Evolution** models spatial ecology across a **`169`-hex (`map_radius = 7`)** pointy-top axial hexagonal grid (`HexMath`, `EvoTypes.HexCell`) where elevation, temperature, humidity, seasonal oscillations, rural hinterland cultivation (`crops` and `pasture`), and glacial sea-level cycles govern local carrying capacity ($K$), available biomass ($R$), and movement barriers.

Rather than relying on random unstructured noise, the simulator ships with three **Scientific World Presets** (`EvoPresets`) designed to test foundational hypotheses in evolutionary biology, human paleoecology, insular biogeography, urban-rural co-evolution, and evolutionary game theory.

---

## Hexagonal Grid Geometry & 1-Deme-Per-Hex Exclusivity (`HexMath`)

Every world is a pointy-top hexagonal spiral centered at axial coordinate $(q, r) = (0, 0)$ with cube constraint $s = -q - r$ ($q + r + s = 0$).

### Coordinate System, `169`-Hex Scale & Single-Deme Footprint

* **Hex Cell Identifier**: Stored as `"%d,%d" % [q, r]` (e.g., `"0,0"`, `"-2,1"`, `"2,-1"`).
* **Spiral Generation (`HexMath.generate_hex_spiral(radius)`)**: Iterates over $q \in [-R, +R]$ and $r \in [\max(-R, -q - R), \min(R, -q + R)]$. The total number of hexagonal cells for map radius $R$ is:
  $$N_{\text{cells}}(R) = 1 + 3R(R + 1)$$
  * **$R = 7$ (All 3 Scientific Presets — *The Rift Valley*, *Darwin's Archipelago*, and *The Finite Island*)**: **$169$ hexagons**
* **Axial Distance (`HexMath.hex_distance`)**:
  $$d\big((q_1, r_1), (q_2, r_2)\big) = \left\lfloor \frac{|q_1 - q_2| + |r_1 - r_2| + |(-q_1 - r_1) - (-q_2 - r_2)|}{2} \right\rfloor$$
* **6 Axial Neighbor Directions (`HexMath.DIRECTIONS`)**:
  $$\big[(+1, 0),\ (+1, -1),\ (0, -1),\ (-1, 0),\ (-1, +1),\ (0, +1)\big]$$
  Neighbor lookups (`HexMath.get_neighbor_ids`) are memoized in `_neighbor_caches_by_size` using the collision-free coordinate hash $(q + 16) \times 32 + (r + 16)$ (supporting `map_radius <= 15`).
* **Pointy-Top World Plane Projection (`HexMath.axial_to_world`, $\text{HEX\_SIZE} = 240.0$)**:
  $$x = 240.0 \cdot \sqrt{3} \cdot (q + 0.5r), \qquad y = 240.0 \cdot 1.5 \cdot r$$
* **Single-Deme-Per-Hex Exclusivity (`cell.deme_ids.size() <= 1`)**:
  Every habitable hex cell supports **at most one resident deme (`cell.deme_ids.size() <= 1`)**. `HexMath.compute_village_sector_offset` always returns `Vector2.ZERO`, giving every settlement the full $240\text{-px}$ radial footprint of its hexagon for its 4-tier urban architecture (`I · Camp` $\to$ `IV · Metropolis`), hex-edge perimeter walls (`wall_r = 0.78`), and animated villagers. All cooperation, trade, Hawk-Dove competition, raids, wars, rural hinterland cultivation, and synoecism occur **across adjacent hex edges**.

---

## The 7 Biomes, Rural Land Use & Climate Defaults

Each `HexCell` stores its active `biome`, `temperature` ($[-1.0, +1.0]$), `humidity` ($[0.0, +1.0]$), `altitude` ($[0.0, +1.0]$), current biomass `current_resources` ($R$), current `carrying_capacity` ($K$), undamaged ceiling `carrying_capacity_max` ($K_{\max}$), `seasonal_regen_rate` ($r_{\text{regen}}$), rural `land_use` (`"wild" | "crops" | "pasture"`), `owner_deme_id`, and persistent `has_ruins` flag.

The baseline biophysical parameters defined in `EvoTypes.BIOME_CLIMATE_DEFAULTS` are:

| Biome ID | Display Name (EN / ES) | Temp ($T$) | Humidity ($H$) | Altitude Range (`min`–`max`) | Seasonal Regen ($r_{\text{regen}}$) | Base $K_{\max}$ | Ecological Role & Rural Land-Use Conversion |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `tropical_forest` | **Tropical Forest** / *Bosque Tropical* | `+0.45` | `0.85` | `0.28 – 0.65` | `0.28` | `600.0` | High-biomass, high-regeneration sanctuary; converts to golden agricultural **`"crops"`** when claimed as a rural hinterland. |
| `savanna` | **Savanna** / *Sabana* | `+0.50` | `0.40` | `0.28 – 0.65` | `0.18` | `420.0` | Intermediate seasonal mosaic; rewards food storage, cooperation, and converts to **`"crops"`** when cultivated by an adjacent settlement. |
| `arid_steppe` | **Arid Steppe** / *Estepa Árida* | `+0.65` | `0.20` | `0.30 – 0.70` | `0.12` | `280.0` | Water-stressed scrubland; converts to fenced livestock **`"pasture"`** (`pasture_pen` & `granary`) when claimed as a rural hinterland. |
| `tundra` | **Tundra** / *Tundra* | `-0.55` | `0.35` | `0.35 – 0.74` | `0.10` | `240.0` | Sub-zero boreal habitat; imposes thermal metabolic costs and converts to pastoral **`"pasture"`** when claimed by an adjacent town. |
| `high_mountain` | **High Mountain** / *Alta Montaña* | `-0.40` | `0.25` | `0.78 – 0.98` | `0.08` | `140.0` | Tectonic barrier ridge. Traversable only when $\text{altitude} \le 0.85$ and $(\text{altitude} - 0.50) \le v_{\text{eff}}.\text{spatial\_mobility}$; cannot be claimed as rural farmland. |
| `coastal_shallows` | **Coastal Shallows** / *Bajíos Costeros* | `+0.20` | `0.70` | `0.14 – 0.24` | `0.20` | `260.0` | Intertidal land bridges (`alt = 0.18` in Darwin's Archipelago) that periodically emerge and flood with sea-level changes; converts to **`"crops"`** when exposed and claimed. |
| `ocean` | **Ocean** / *Océano* | `+0.10` | `0.90` | `0.02 – 0.08` | `0.02` | `50.0` | Deep marine barrier ($R = 0.0$). Impassable to terrestrial demes; submergence displaces or extinguishes resident populations. |

### Passability & Barrier Traversal Formula

Whether a deme can migrate into, claim rural hinterlands in, or maintain genetic contact across an adjacent hexagon `ncell` is governed by `EvoDemographyMigration.is_hex_passable_for_deme(ncell, spatial_mobility)`:

$$\text{Passable}(\text{ncell}, v_{\text{eff}}) \iff \text{ncell.biome} \neq \text{"ocean"} \;\land\; \text{ncell.altitude} \le 0.85 \;\land\; (\text{ncell.altitude} - 0.50) \le v_{\text{eff}}.\text{spatial\_mobility}$$

!!! info "Tectonic Ridges & Mountain Passes"
    In **The Rift Valley**, the central mountain ridge (`q == 0`) has `altitude = 0.88 > 0.85` except at three natural savanna mountain passes at **`(0, -3)`**, **`(0, 0)`**, and **`(0, 3)`** (`altitude = 0.52`), forcing populations to funnel through the passes, carve new corridors with the **Valley Pickaxe** (`-0.18` altitude), or evolve in geographic isolation.

---

## Dynamic Environmental Cycles (`EvoEnvPhase`)

At the start of every generation (`EvoEnvPhase.run_environmental_phase`), the physical world evolves through four deterministic environmental mechanisms:

```mermaid
flowchart TD
    Gen["Advance Generation (t → t + 1)\nFlip Season: wet_warm ↔ dry_cold"] --> Glacial{"Glacial Cycle Active\n& (t % 8 == 0)?"}
    Glacial -- "Yes" --> SeaToggle["Toggle Sea Level:\n0.12 (Low Tide) ↔ 0.25 (High Tide)"]
    Glacial -- "No" --> FloodCheck["Evaluate Coastal Elevation vs. sea_level"]
    SeaToggle --> FloodCheck
    FloodCheck --> Submerge["alt < sea_level → biome = 'ocean'\nClear land_use / owner_deme_id\nDisplace Deme to Empty Neighbor or Drown"]
    FloodCheck --> Emerge["alt >= sea_level (was ocean) → Emerge Land\ncoastal_shallows / savanna / steppe / mountain"]
    Submerge & Emerge --> Regen["Oscillate Cell Temp (±0.04) & Humidity (±0.05)\nRecover K (+5% or +0.5% if Collapsed)\nRegenerate Biomass R = min(K, R + K · r_regen · γ_season)"]
```

### 1. Seasonal Oscillation (`wet_warm` $\leftrightarrow$ `dry_cold`)
Every generation alternates between **Warm Spring (`wet_warm`)** and **Dry Winter (`dry_cold`)**:

* **Seasonal Biomass Multiplier ($\gamma_{\text{season}}$)**:
  $$\gamma_{\text{season}} = \begin{cases} 1.20 & \text{if } \text{season} = \text{"wet\_warm"} \\ 0.75 & \text{if } \text{season} = \text{"dry\_cold"} \end{cases}$$
* **Thermal & Hydric Drift**: Every non-ocean hex shifts by $\Delta T = \pm 0.04$ (clamped to $[-1.0, +1.0]$) and $\Delta H = \pm 0.05$ (clamped to $[0.0, +1.0]$).

### 2. Glacial Sea-Level Cycles & Land Bridges
When `state.glacial_sea_level_cycle == true` (active by default in `preset-darwin-archipelago`), global sea level oscillates every **8 generations**:

$$\text{sea\_level}(t) = \begin{cases} 0.12 \ (\text{Low Tide — Land Bridges Exposed}) & \text{if } (t / 8) \bmod 2 == 0 \\ 0.25 \ (\text{High Tide — Land Bridges Submerged}) & \text{if } (t / 8) \bmod 2 == 1 \end{cases}$$

* **Generations `1–7`**: `sea_level = 0.12` — the 7 coastal shallows (`altitude = 0.18`) remain passable land bridges.
* **Generations `8–15`**: `sea_level = 0.25` — coastal shallows flood into `ocean`, isolating outer island populations for 8 consecutive turns.
* **Generations `16–23`**: `sea_level = 0.12` — land bridges re-emerge as `coastal_shallows` with $K_{\max} = \max(160.0, K_{\max})$, $K = \max(\text{round}(0.88 \cdot K_{\max}), K)$, and $R = \max(R, \text{round}(0.35 \cdot K))$.

### 3. Coastal Submergence & 1-Deme-Per-Hex Relocation
Whenever a hex's `altitude` falls below `state.sea_level` (via glacial cycles or God-mode altitude/sea-level tools), it converts to `"ocean"`, resets `land_use = "wild"`, `owner_deme_id = ""`, and `has_ruins = false`, and any resident deme must evacuate immediately:

1. The engine scans all 6 adjacent neighbor hexes for valid **empty** refuges (`ncell.biome != "ocean"`, `ncell.deme_ids.is_empty()`, `ncell.altitude <= 0.85`, and `ncell.altitude - 0.50 <= v_eff.spatial_mobility`), sorted by highest `current_resources` ($R$).
2. **Emergency Relocation**: If an empty passable refuge exists, the deme relocates to the best neighbor (clearing any prior rural `owner_deme_id`/`land_use` on that hex), suffers a **$10\%$ transit population loss** and **$20\%$ energy reserve penalty** ($E_{\text{reserves}} \leftarrow 0.80 \cdot E_{\text{reserves}}$), and generates a `"migration"` flow (`intensity = 0.80`).
3. **Submergence Extinction**: If all surrounding hexes are ocean, impassable peaks (`altitude > 0.85`), or already occupied (`deme_ids.size() >= 1`), the deme drowns—recording an `"extinction"` entry in the Chronicle and releasing any rural hinterlands it owned into `has_ruins = true`.

### 4. Passive Carrying Capacity ($K$) & Biomass ($R$) Regeneration
Each non-ocean cell recovers its carrying capacity $K$ toward $K_{\max}$ and replenishes available food $R$:

$$r_{\text{recovery}} = \begin{cases} 0.005 \ (0.5\%\text{/turn}) & \text{if cell suffered Tragedy of the Commons at } t-1 \text{ or } R_t \le 0 \\ 0.050 \ (5.0\%\text{/turn}) & \text{otherwise} \end{cases}$$

$$K_{t+1} = \text{clamp}\Big(K_t + r_{\text{recovery}} \cdot (K_{\max} - K_t),\ 10.0,\ K_{\max}\Big)$$

$$R_{t+1} = \min\Big(K_{t+1},\ R_t + K_{t+1} \cdot r_{\text{regen}} \cdot \gamma_{\text{season}}\Big)$$

---

## Deep-Dive: The 3 Scientific World Presets (`169` Hexes) & 1v1 Strategy Matchups

Every preset world (`EvoPresets.create_preset_world(preset_id, lang, strategy_a_id, strategy_b_id)`) initializes a balanced **1v1 Evolutionary Strategy Duel** between **Founder A (`state.strategy_a_id`)** and **Founder B (`state.strategy_b_id`)** on a **`169`-hex (`map_radius = 7`)** map. By default, `strategy_a_id` is `strat-cooperation` (🤝 Cooperative Alliance, `#10B981`) and `strategy_b_id` is `strat-war` (⚔️ Conquering Horde, `#EF4444`), and players can switch either slot to any of the 5 base archetypes or custom user strategies (`~/.config/Evolution/user_catalog.json`) via the Top HUD Matchup Bar at Generation 0.

### 1. The Rift Valley (`preset-rift-savanna`)

> **Scientific Hypothesis**: *East Side Story / Tectonic Savanna Hypothesis* — How tectonic uplift and eastern rain-shadow aridification pit a western rainforest population (Strategy A) against an eastern savanna-steppe population (Strategy B) separated by a high-mountain ridge pierced by three mountain passes.

![Continuous Multi-Hex Walled Union & Hinterlands in The Rift Valley](assets/img/screenshot_late_simulation.png)

* **Map Geometry**: Radius $R = 7$ (**$169$ hexes**), `sea_level = 0.12`, `glacial_sea_level_cycle = false`.
* **Topographic Partition**:
  | Region | Axial Condition | Biome | Temp | Humidity | Altitude | Initial $R$ | Initial $K$ | $K_{\max}$ | Regen $r_{\text{regen}}$ |
  | :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Western Basin** | $q < 0$ (77 hexes) | `tropical_forest` | `+0.45` | `0.85` | `0.35` | `560.0` | `600.0` | `650.0` | `0.30` |
  | **3 Mountain Passes** | $q = 0,\ r \in \{-3, 0, +3\}$ (3 hexes) | `savanna` | `+0.25` | `0.45` | `0.52` | `240.0` | `280.0` | `320.0` | `0.18` |
  | **Tectonic Ridge** | $q = 0,\ r \notin \{-3, 0, +3\}$ (12 hexes) | `high_mountain` | `-0.35` | `0.25` | `0.88` | `70.0` | `108.0` | `120.0` | `0.08` |
  | **Eastern Mosaic (Odd)** | $q > 0,\ |q+r| \bmod 2 = 1$ (39 hexes) | `savanna` | `+0.60` | `0.30` | `0.42` | `260.0` | `335.0` | `380.0` | `0.16` |
  | **Eastern Mosaic (Even)** | $q > 0,\ |q+r| \bmod 2 = 0$ (38 hexes) | `arid_steppe` | `+0.60` | `0.30` | `0.42` | `260.0` | `335.0` | `380.0` | `0.16` |
* **1v1 Founding Lineages & Subpopulations**:
  | Slot | Deme ID & Name (EN / ES) | Lineage ID & Name (EN / ES) | Founder Hex | Initial Pop | Reserves | $\Delta E_0$ | Assigned Strategy | System 1 Model |
  | :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Strategy A** | `deme-rift-west`<br>**Western Forest Hominids**<br>*Homínidos del Bosque Occidental* | `lineage-rift-west`<br>**Western Rift Lineage**<br>*Linaje Occidental del Rift* | `-2,1`<br>(`tropical_forest`) | `140` | `180.0` | `+12.0` | `state.strategy_a_id`<br>*(Default: `strat-cooperation` 🤝)* | `d3:4b` |
  | **Strategy B** | `deme-rift-east`<br>**Eastern Savanna Hominids**<br>*Homínidos de la Sabana Oriental* | `lineage-rift-east`<br>**Eastern Rift Lineage**<br>*Linaje Oriental del Rift* | `2,-1`<br>(`arid_steppe`) | `140` | `180.0` | `+8.0` | `state.strategy_b_id`<br>*(Default: `strat-war` ⚔️)* | `tev1:4b` |
* **Evolutionary & Urban Dynamics**:
  * **Western Forest Hominids (`-2,1`)** begin at Tier II (`pop = 140`) in high-biomass `tropical_forest` ($R = 560, K = 600$), rapidly cultivating adjacent `"crops"` hinterlands and expanding across the western basin.
  * **Eastern Savanna Hominids (`2,-1`)** begin at Tier II (`pop = 140`) in the eastern mosaic, cultivating mixed `"crops"` (savanna) and `"pasture"` (arid steppe) hinterlands while navigating seasonal scarcity, mountain passes (`(0,-3)`, `(0,0)`, `(0,3)`), **Baldwin genetic assimilation**, **Cumulative Cultural Innovation**, and **Allopatric Speciation**.

---

### 2. Darwin's Archipelago (`preset-darwin-archipelago`)

> **Scientific Hypothesis**: *Insular Biogeography & Allopatric Speciation* — How glacial eustatic sea-level oscillations alternately connect volcanic islands via 7 temporary land bridges (`coastal_shallows`) and isolate rival colonizing founder strategies across contrasting thermal niches.

![Darwin's Archipelago — 169-Hex Insular Dispersal & Land Bridges](assets/img/screenshot_darwin_archipelago.png)

* **Map Geometry**: Radius $R = 7$ (**$169$ hexes**), `sea_level = 0.12`, `glacial_sea_level_cycle = true` (toggles `0.12` $\leftrightarrow$ `0.25` every 8 generations).
* **Archipelago Layout**:
  | Island / Feature | Hex Coordinates | Biome | Temp | Humidity | Altitude | Initial $R$ | Initial $K$ | $K_{\max}$ | Regen $r_{\text{regen}}$ |
  | :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Central Hub Island** | `0,0` (1 hex) | `tropical_forest` | `+0.20` | `0.75` | `0.40` | `320.0` | `395.0` | `450.0` | `0.24` |
  | **Central Duel Islands** | `-1,0`, `1,0`, `-2,0`, `-1,-1`, `2,-1`, `1,1` (6 hexes) | `tropical_forest` | `+0.22` | `0.75` | `0.65` | `220.0` | `220.0` | `220.0` | `0.24` |
  | **7 Tidal Land Bridges** | `0,-1`, `0,1`, `2,0`, `-2,1`, `0,-4`, `0,4`, `4,-1` (7 hexes) | `coastal_shallows` | `+0.15` | `0.65` | `0.18` | `200.0` | `230.0` | `260.0` | `0.22` |
  | **Northern Boreal Chain** | `0,-2`, `0,-3`, `1,-2`, `-1,-2`, `1,-3`, `0,-5`, `1,-4` (7 hexes) | `tundra` | `-0.55` | `0.40` | `0.55` | `360.0` | `380.0` | `420.0` | `0.24` |
  | **Southern Tropical Chain** | `0,2`, `0,3`, `-1,2`, `1,2`, `-1,3`, `0,5`, `-1,4` (7 hexes) | `tropical_forest` | `+0.55` | `0.85` | `0.45` | `420.0` | `450.0` | `500.0` | `0.28` |
  | **Eastern Xeric Chain** | `3,0`, `3,-1`, `4,0`, `3,1`, `4,-2`, `5,-1` (6 hexes) | `arid_steppe` | `+0.65` | `0.25` | `0.45` | `330.0` | `360.0` | `400.0` | `0.22` |
  | **Surrounding Deep Sea** | Remaining 135 hexes | `ocean` | `+0.10` | `0.90` | `0.05` | `0.0` | `20.0` | `60.0` | `0.05` |
* **1v1 Founding Lineages & Subpopulations**:
  | Slot | Deme ID & Name (EN / ES) | Lineage ID & Name (EN / ES) | Founder Hex | Initial Pop | Reserves | $\Delta E_0$ | Assigned Strategy | System 1 Model |
  | :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Strategy A** | `deme-darwin-founder`<br>**Western Island Founders**<br>*Fundadores Insulares del Oeste* | `lineage-darwin-a`<br>**Western Archipelago Lineage**<br>*Linaje Occidental del Archipiélago* | `-1,0`<br>(`tropical_forest`) | `95` | `165.0` | `+12.0` | `state.strategy_a_id`<br>*(Default: `strat-cooperation` 🤝)* | `d3:4b` |
  | **Strategy B** | `deme-darwin-rival`<br>**Eastern Island Rivals**<br>*Rivales Insulares del Este* | `lineage-darwin-b`<br>**Eastern Archipelago Lineage**<br>*Linaje Oriental del Archipiélago* | `1,0`<br>(`tropical_forest`) | `95` | `165.0` | `+10.0` | `state.strategy_b_id`<br>*(Default: `strat-war` ⚔️)* | `tev1:4b` |
* **Evolutionary Dynamics**:
  * Both rival founders begin on symmetric high-ground island perches (`-1,0` and `1,0`, `K = 220`) flanking the central hub `(0, 0)`.
  * During **Generations 1–7** (low tide, `sea_level = 0.12`), exposed coastal land bridges (`0,-1`, `0,1`, `2,0`, `-2,1`, `0,-4`, `0,4`, `4,-1`) allow budding daughter demes from both strategies to race across the central hub onto the outer Tundra, Southern Tropical, and Eastern Arid Steppe island chains.
  * At **Generation 8**, `sea_level` rises to `0.25`, submerging all 7 land bridges (`altitude = 0.18 < 0.25`) into `ocean`. Any deme standing on a bridge evacuates to an empty adjacent island hex or drowns, and isolated island colonies accumulate `isolation_turns` until reaching $\ge 10$ turns and diverging via **Allopatric Speciation** into new child species in `lineage_tree` (while retaining their parent `strategy_id`).

---

### 3. The Finite Island (`preset-finite-island`)

> **Scientific Hypothesis**: *The Tragedy of the Commons & Cultural Stewardship* — How two competing clans sharing a bounded island ecosystem with slow biomass regeneration ($r_{\text{regen}} = 0.08$) either exhaust their carrying capacity $K$ through intensive overexploitation and Hawk-Dove conflict, or stabilize via Communal Conservation Norms, rural hinterland stewardship, and Reciprocal Symbiosis.

![The Finite Island — Ecological Health Lens & Valley Legend](assets/img/screenshot_finite_island.png)

* **Map Geometry**: Radius $R = 7$ (**$169$ hexes**), `sea_level = 0.20`, `glacial_sea_level_cycle = false`.
* **Concentric Island Rings** (by axial distance $d = \text{hex\_distance}(0, 0, q, r)$):
  | Ring | Distance $d$ | Biome | Temp | Humidity | Altitude | Initial $R$ | Initial $K$ | $K_{\max}$ | Regen $r_{\text{regen}}$ |
  | :--- | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Fertile Core** | $d \le 1$ (7 hexes) | `savanna` | `+0.30` | `0.55` | `0.42` | `580.0` | `600.0` | `600.0` | `0.08` |
  | **Steppe Interior & Coast** | $2 \le d \le 3$ (30 hexes) | `arid_steppe` | `+0.45` | `0.30` | `0.48` | `220.0` | `270.0` | `300.0` | `0.08` |
  | **Outer Shallows Reefs** | $d = 4,\ |q-r| \bmod 2 = 0$ (12 hexes) | `coastal_shallows` | `+0.22` | `0.65` | `0.22` | `180.0` | `220.0` | `260.0` | `0.14` |
  | **Abyssal Ocean** | Remaining 120 hexes | `ocean` | `+0.15` | `0.90` | `0.05` | `0.0` | `20.0` | `60.0` | `0.05` |
* **1v1 Founding Lineages & Clans**:
  | Slot | Deme ID & Clan Name (EN / ES) | Lineage ID & Name (EN / ES) | Founder Hex | Initial Pop | Reserves | $\Delta E_0$ | Assigned Strategy | System 1 Model |
  | :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Strategy A** | `deme-island-1`<br>**Northern Quarry Clan**<br>*Clan de la Cantera Norte* | `lineage-island-1`<br>**Northern Quarry Lineage**<br>*Linaje de la Cantera Norte* | `-1,0`<br>(`savanna`) | `95` | `140.0` | `+8.0` | `state.strategy_a_id`<br>*(Default: `strat-cooperation` 🤝)* | `d3:4b` |
  | **Strategy B** | `deme-island-2`<br>**Southern Timber Clan**<br>*Clan Maderero del Sur* | `lineage-island-2`<br>**Southern Timber Lineage**<br>*Linaje Maderero del Sur* | `1,0`<br>(`savanna`) | `95` | `140.0` | `+8.0` | `state.strategy_b_id`<br>*(Default: `strat-war` ⚔️)* | `tev1:4b` |
* **Evolutionary Dynamics**:
  * **Northern Quarry Clan (`-1,0`, Strategy A)** and **Southern Timber Clan (`1,0`, Strategy B)** start on opposite sides of the fertile savanna core ($d \le 1$, where natural regeneration is constrained to $r_{\text{regen}} = 0.08$).
  * When an extractive or martial strategy (`strat-war` ⚔️ or `strat-innovation` 🔬 carrying `cul-extraction-tools` without `cul-communal-conservation`) expands across the island, intensive harvesting degrades $K$ by $18\% \cdot \sum v_{\text{eff}}.\text{ecological\_impact}$ per turn until $K < 0.60 \cdot K_{\max}$ triggers the **Tragedy of the Commons**—whereas cooperative or mercantile strategies (`strat-cooperation` 🤝, `strat-trade` ⚖️) preserve $K$, maintain urban `salubrity`, and build symbiotic trade networks and multi-hex walled unions.
