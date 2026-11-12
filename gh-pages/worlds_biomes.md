# Worlds, Biomes & Geography

In **Evolution**, every simulation unfolds on a flat-plane hexagonal lattice projected into an angled 2.5D isometric view (`HEX_SIZE = 240.0`). Geography is not decorative: elevation, seasonal oscillation, carrying capacity, and biome boundaries act as continuous selective filters over migration corridors, agriculture, and disease.

---

## 1. Hexagonal Axial Topology & Ownership

Spatial geometry in [`HexMath`](https://github.com/arrase/Evolution/blob/main/src/core/hex_math.gd) uses **pointy-top axial coordinates** $(q, r)$ with implicit third cubic axis $s = -q - r$:

$$\begin{aligned}
x_{\text{world}} &= \text{HEX\_SIZE} \cdot \sqrt{3} \cdot \left(q + \frac{r}{2}\right) \\
y_{\text{world}} &= \text{HEX\_SIZE} \cdot \frac{3}{2} \cdot r
\end{aligned}$$

Discrete step distance between any two cells is exact on the hex grid:

$$d\big((q_1, r_1), (q_2, r_2)\big) = \frac{|q_1 - q_2| + |r_1 - r_2| + |s_1 - s_2|}{2}$$

### Exclusive Settlement Occupancy & Multi-Hex Districts

Unlike earlier prototypes that packed multiple bands inside a single hex, the current engine enforces **strict territorial exclusivity**:

- **Urban cap per hex**: Each `HexCell` stores `deme_ids: Array[String]` capped at **`<= 1` urban occupant** (one settlement or urban district center per tile). Adjacent demes never share a tile unless one conquers or absorbs it.
- **Multi-hex urban districts (`urban_hex_ids`)**: A deme's primary coordinate is `deme.hex_id`, while `deme.urban_hex_ids` lists all urban hexes belonging to that settlement (up to `EvoTypes.MAX_URBAN_HEXES = 3`, formed through peaceful **Walled Unions**). Each inhabited `urban_hex_ids` entry binds back to that deme in `cell.deme_ids`.
- **Rural Hinterlands**: Outside urban centers, settled demes claim surrounding passable, unowned hexes as agricultural (`crops`) or pastoral (`pasture`) rural hinterlands tagged with `cell.owner_deme_id`. `EvoTypes.urban_perimeter_hex_ids(deme, state)` computes the set of distinct exterior neighbor hexes bordering `deme.urban_hex_ids` for raids, fortification perimeters, and expansion checks.

---

## 2. The Seven Biome Regimes

`EvoTypes.BIOME_CLIMATE_DEFAULTS` defines the baseline physical parameters for all 7 biomes in [`src/core/types.gd`](https://github.com/arrase/Evolution/blob/main/src/core/types.gd):

| Biome ID | Temperature `T` | Humidity `H` | Altitude Range `[min, max]` | Max Capacity `K_max` | Seasonal Regen | Biome Character & Strategic Impact |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **`tropical_forest`** | `+0.45` | `0.85` | `[0.28, 0.65]` | `600.0` | `0.28` | Dense jungle with highest regenerative biomass; favors arboreal, foraging, and social lineages, while warm moisture increases epidemic susceptibility if overcrowded. |
| **`savanna`** | `+0.50` | `0.40` | `[0.28, 0.65]` | `420.0` | `0.18` | Sun-drenched woodland grassland balanced between forage, pasture, and mobile movement; the classic adaptive frontier. |
| **`arid_steppe`** | `+0.65` | `0.20` | `[0.30, 0.70]` | `280.0` | `0.12` | Sparse semi-desert; induces climate metabolic stress on unadapted groups unless buffered by thermal tolerance or dispersal. |
| **`tundra`** | `-0.55` | `0.35` | `[0.35, 0.74]` | `240.0` | `0.10` | Cryogenic plains; harsh cold stress and slower organic turnover reward `bio-thermal-tolerance` and `cul-fire-processing`. |
| **`high_mountain`** | `-0.40` | `0.25` | `[0.78, 0.98]` | `140.0` | `0.08` | Alpine ridge barrier; **impassable** unless a deme possesses `spatial_mobility >= 0.45`. Serves as a natural continental rift isolating clades. |
| **`coastal_shallows`** | `+0.20` | `0.70` | `[0.14, 0.24]` | `260.0` | `0.20` | Low-lying tidal flats and land bridges (`altitude < 0.25`). Vulnerable to drowning whenever `sea_level` rises during warm phases. |
| **`ocean`** | `+0.10` | `0.90` | `[0.02, 0.08]` | `50.0` | `0.02` | Impassable marine sink (`current_resources = 0.0`). Blocks all expansion, colonization corridors, and overland logistics. |

### Passability Gate

Movement, settling, raiding, conquest, and rural claiming evaluate `EvoActionMenu.is_passable_for(cell, mobility)`:

```gdscript
cell.biome != "ocean"
and (cell.biome != "high_mountain" or mobility >= 0.45)
and cell.altitude <= (0.88 if mobility >= 0.45 else 0.85)
```

Notice that `high_mountain` tiles strictly block both movement and sight-line adjacency until biological or cultural mobility pushes `spatial_mobility >= 0.45`, making ridge passes decisive biogeographic bottlenecks.

---

## 3. Environmental Cycles, Sea Level & Recovery

Every generation enters `EvoEnvPhase.run_environmental_phase()` (`src/engine/env_phase.gd`) before biophysical production and conflict run:

### Seasonal Alternation

The world oscillates strictly between two planetary regimes each turn:

- **`wet_warm`**: Seasonal resource regeneration factor $\gamma_{\text{season}} = 1.20$; slight warming/moistening shifts (`+0.02` temp / `+0.03` humidity on land hexes outside `ocean`).
- **`dry_cold`**: Seasonal resource regeneration factor $\gamma_{\text{season}} = 0.75$; cooling/drying stress (`-0.02` temp / `-0.03` humidity).

In addition, each turn restores **`+15` Selective Pressure points (mana)** up to play budgets so the observer can continue sculpting terrain via the bottom hotbar.

### Glacial Sea-Level Oscillation

When `glacial_sea_level_cycle` is enabled (as in **Darwin's Archipelago**), every 8 generations (`state.generation % 8 == 0`) alternates planetary sea level between glacial regression (`0.12`) and interglacial flooding (`0.25`). Whenever `cell.altitude < state.sea_level`, a terrestrial hex submerges into `ocean`; conversely, submerged seafloor rising above `state.sea_level` emerges as:

- `coastal_shallows` (`altitude < 0.25`)
- `savanna` (`0.25 <= altitude < 0.55`)
- `arid_steppe` (`0.55 <= altitude < 0.78`)
- `high_mountain` (`altitude >= 0.78`)

#### Submersion & Evacuation Rules

If an active settlement stands on a newly submerged tile, `EvoEnvPhase` resolves evacuation automatically:

1. **Multi-hex partial loss**: If the deme spans multiple `urban_hex_ids` and at least one district stays above water, only the flooded district detaches (updating `deme.hex_id` if needed and purging its rural claim).
2. **Full flood relocation**: If all urban districts flood, the deme flees to an adjacent passable empty hex (not owned by another rival), absorbs a **`0.80x` (`-20%`) penalty to `energy_reserves`**, clears prior urban districts onto the refuge tile, emits a `"migration"` flow (`intensity = 0.65`), and carries **no population percentage toll**.
3. **Drowning extinction**: If no passable empty escape hex exists, the entire deme drowns (`population = 0`), releases owned rural hexes, and logs an `"extinction"` event.

### Carrying Capacity Degradation, Ruin Decay & Path Aging

On every non-ocean tile, carrying capacity $K$ regenerates toward $K_{\max}$, while harvestable stock $R$ recovers proportionally to $\gamma_{\text{season}}$:

$$K_{t+1} = \text{clamp}\!\big(K_t + r_{\text{rec}} (K_{\max} - K_t),\ 10.0,\ K_{\max}\big)$$

$$R_{t+1} = \min\!\big(K_{t+1},\ R_t + K_{t+1} \cdot \text{regen\_rate} \cdot \gamma_{\text{season}}\big)$$

Crucially, **$r_{\text{rec}}$ drops from `0.05` (`5%`) in healthy land to `0.008` (`0.8%`) whenever `suffered_collapse` is true or $K_t < 0.60 \cdot K_{\max}$**, locking overexploited valleys into slow ecological hysteresis. At the same time:

- **Ruins decay**: Any `cell.ruin_turns > 0` decrements by `1` per turn (`cell.has_ruins = cell.ruin_turns > 0`), remaining visible on scorched fields or fallen settlements for up to `3` generations.
- **Disused trade/pact trails**: `state.disused_connections` increment `age += 1` each turn and are pruned once `age > 2`.

---

## 4. Three Scenario Presets

All scenarios live in [`src/core/presets.gd`](https://github.com/arrase/Evolution/blob/main/src/core/presets.gd) and generate a radius-`7` hex map (`169` total cells), seeded deterministically from `preset_id | strategy_a_id | strategy_b_id`, immediately claiming starting rural hinterlands and priming turn-0 LLM evaluations.

### Darwin's Archipelago (`preset-darwin-archipelago`)

![Darwin's Archipelago](assets/img/screenshot_darwin_archipelago.png)

- **Topography**: Dynamic glacial cycle enabled (`sea_level = 0.12 ↔ 0.25`, `glacial_sea_level_cycle = true`). A central forested duel core (`6` tiles around `0,0`) connects via `7` tidal `coastal_shallows` land bridges to `7` cold northern `tundra` tiles, `7` lush southern `tropical_forest` tiles, and `6` arid eastern `arid_steppe` tiles, framed by `ocean`.
- **Starting Demes**: `Western Island Founders` (`-1,0`, Slot A) and `Eastern Island Rivals` (`1,0`, Slot B), each starting at `population = 95`, `energy_reserves = 165.0`.
- **Evolutionary Dynamic**: Every 8 generations, interglacial rising water severs coastal land bridges, forcing geographic isolation, peripheral divergence, and allopatric speciation across islands before glacial drawdowns reconnect rival clades.

### Finite Island (`preset-finite-island`)

![Finite Island under Food Lens](assets/img/screenshot_finite_island.png)

- **Topography**: Static sea level (`0.20`), isolated oceanic plateau (`dist <= 1` inner `savanna` ring of `7` hexes, `2 <= dist <= 3` outer `arid_steppe` ring of `30` hexes, `coastal_shallows` perimeter reefs at `dist == 4` wherever $|q - r| \bmod 2 == 0$, and surrounding deep `ocean` beyond). Central `savanna` (`K_max = 600`, slow `regen = 0.08`) transitions to outer `arid_steppe` (`K_max = 300`, `regen = 0.08`).
- **Starting Demes**: `Northern Quarry Clan` (`-1,0`, Slot A) and `Southern Timber Clan` (`1,0`, Slot B), starting at `population = 95`, `energy_reserves = 140.0`.
- **Evolutionary Dynamic**: A hard ecological pressure cooker where runaway extraction collapses carrying capacity into the `0.8%` degraded recovery trap, directly rewarding strategies that invest in conservation, salubrity, or decisive conquest.

### Rift Savanna (`preset-rift-savanna`)

![Rift Savanna Opening View](assets/img/screenshot_rift_savanna.png)

- **Topography**: Static continental split (`sea_level = 0.12`). **`77` west hexes** of lush `tropical_forest` (`K_max = 650`, `regen = 0.30`) sit opposite **`77` east hexes** of alternating `savanna` (`39` hexes) and `arid_steppe` (`38` hexes, `K_max = 380`, `regen = 0.16`), divided along $q = 0$ by **`12` impassable `high_mountain` peaks** pierced by **`3` savanna mountain passes** at `(0, -3)`, `(0, 0)`, and `(0, 3)`.
- **Starting Demes**: `Western Forest Hominids` (`-2,1`, Slot A) and `Eastern Savanna Hominids` (`2,-1`, Slot B), starting at `population = 140`, `energy_reserves = 180.0`.
- **Evolutionary Dynamic**: Tests diverging evolutionary pressures—dense arboreal abundance versus arid savanna mobility—funneling contact, trade, raids, and military campaigns through the three narrow mountain passes until `spatial_mobility >= 0.45` unlocks high-altitude crossings.
