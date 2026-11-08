# Evolution

[![CI](https://github.com/arrase/Evolution/actions/workflows/ci.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/ci.yml)
[![CodeQL](https://github.com/arrase/Evolution/actions/workflows/codeql.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/codeql.yml)
[![Security Audit](https://github.com/arrase/Evolution/actions/workflows/security.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/security.yml)

**Evolution** is an interactive bio-cultural and evolutionary population simulator built with **Godot 4.7**, featuring a high-DPI 2.5D illustrated isometric hexagonal ecosystem (`169` hexes, `map_radius = 7`) powered by GPU terrain/ocean shaders (`ocean_waves.gdshader`, `hex_terrain.gdshader`, `prop_sway_glow.gdshader`) and procedural `#23150c` ink-outlined artwork.

Rather than commanding individual units directly, you act as the **Selective Pressure** and **Evolutionary Architect**—configuring **1v1 Evolutionary Strategy Duels (`Strategy A ⚔️ Strategy B`)** before pressing Play, forging custom strategies and traits, and shaping climates, terrain altitude, sea levels, and habitat carrying capacity ($K$)—while single-deme-per-hex subpopulations (*demes*) autonomously evaluate their surroundings, cultivate adjacent rural hinterlands (`crops` and `pasture`), manage urban salubrity (`salubrity`), erect hex-edge perimeter fortifications, wage wars, unite into multi-hex walled conurbations (`walled_union_id`), innovate, or diverge into new species.

![The Rift Valley — 169-Hex 2.5D Illustrated Ecosystem & HUD](gh-pages/assets/img/screenshot_rift_savanna.png)

---

## Key Features

### 1. 1v1 Evolutionary Strategy Duels (`Strategy A ⚔️ Strategy B`)
Before launching a simulation at Generation 0, you choose which two **Evolutionary Strategies** (`EvoTypes.StrategyDef`) will face off across the `169`-hex valley—or forge your own in the **Evolutionary Laboratory** (persisted automatically to `~/.config/Evolution/user_catalog.json`). Each strategy bundles compatible biological adaptations and cultural traditions, imbuing its founding lineage and daughter settlements with a distinct emblem, color identity, and combined 6-axis biophysical footprint:

| Strategy ID | Emblem & Name (EN / ES) | Color | Bundled Traits (`bio-*` + `cul-*`) | Evolutionary Philosophy |
| :--- | :--- | :---: | :--- | :--- |
| `strat-cooperation` | 🤝 **Cooperative Alliance**<br>*Alianza Cooperativa* | `#10B981` | `bio-k-strategy`, `bio-social-instinct` + `cul-communal-conservation` | Fosters social cohesion, communal habitat conservation, sanitation, and resource buffering. |
| `strat-expansion` | 🧭 **Expansionist Pioneers**<br>*Pioneros Expansionistas* | `#3B82F6` | `bio-r-strategy`, `bio-thermal-tolerance`, `bio-social-instinct` + `cul-fire-processing` | Fast reproduction, high mobility, and thermal tolerance to colonize new territories. |
| `strat-trade` | ⚖️ **Merchant League**<br>*Liga Mercantil* | `#F59E0B` | `bio-k-strategy`, `bio-encephalization` + `cul-interdeme-barter` | Drives inter-village barter, commercial symbiosis, and horizontal cultural diffusion. |
| `strat-war` | ⚔️ **Conquering Horde**<br>*Horda Conquistadora* | `#EF4444` | `bio-r-strategy`, `bio-social-instinct` + `cul-warrior-expansion`, `cul-extraction-tools` | Aggressive martial expansion, hinterland pillaging, and intensive extraction to dominate rival territories. |
| `strat-innovation` | 🔬 **Innovator Technocrats**<br>*Tecnócratas Innovadores* | `#A855F7` | `bio-encephalization`, `bio-digestive-spec` + `cul-fire-processing`, `cul-extraction-tools` | High encephalization, thermal food processing, and specialized extraction toolkits. |

### 2. Single-Deme-Per-Hex Spatial Ecology, 4-Tier Urban Hierarchy & Rural Hinterlands
Every scenario operates on a **`169`-hex (`map_radius = 7`, `HEX_SIZE = 240.0`)** pointy-top axial grid under a strict **1-Deme-Per-Hex Exclusivity invariant (`cell.deme_ids.size() <= 1`)**. Each settlement commands the full footprint of its hexagon (`HexMath.compute_village_sector_offset == Vector2.ZERO`), and all cooperation, trade, Hawk-Dove competition, raids, wars, and synoecism occur across adjacent hex edges:

- **4-Tier Urban Hierarchy (`I..IV` — `Deme.get_village_tier()`):**
  - **`I · Camp / Campamento` (`tier == 1`):** Nomadic frontier camp (`population < 120`, `defense_tier == 0`) with thatched huts (`hut_thatch`) and central campfires (`campfire`); relies entirely on local hex foraging (`urban_forage_mult = 1.0`).
  - **`II · Village / Aldea` (`tier == 2`):** Settled pastoral/farming village (`population >= 120` or `defense_tier == 1`) with clay houses (`house_clay`) and granaries (`granary`); claims up to **`1` adjacent rural hinterland hex**.
  - **`III · Town / Villa` (`tier == 3`):** Urbanized town (`population >= 240`, or `>= 170` with fortifications/unification) with stone houses (`house_stone`), temple totems (`temple_totem`), and windmills (`windmill`); urban density reduces local wild foraging (`urban_forage_mult = 0.55`) while expanding rural capacity to **`2` adjacent hinterland hexes**.
  - **`IV · Metropolis / Metrópolis` (`tier == 4`):** Monumental walled city (`population >= 380`, or `>= 280` with `defense_tier >= 2`, `merged_count >= 1`, or `walled_union_id != ""`) crowned by a citadel keep (`citadel_keep`), cathedral (`cathedral`), and watchtowers (`watchtower`); local wild foraging drops to `0.30` while the city cultivates up to **`4` adjacent rural hinterland hexes**.
- **Rural Hinterlands (`crops` & `pasture`) & Pillaging (`has_ruins`):** Tier II–IV settlements automatically claim and cultivate up to `1`, `2`, or `4` adjacent uninhabited terrestrial hexes (`altitude <= 0.85`), converting fertile biomes into golden wheat fields with windmills (`land_use = "crops"`, `crop_field`, `windmill`) and arid/boreal biomes into fenced livestock pastures with barns (`land_use = "pasture"`, `pasture_pen`, `granary`) connected by rural farm tracks with animated `covered_wagon`s. Each owned hinterland yields `min(R_rural, 0.35 * pop) * 0.70` calories per turn. During cross-border raids or sieges, attackers can **pillage rural hinterlands**, plundering up to `18.0` biomass and scorching the parcel into persistent stone ruins (`has_ruins = true`, `ruins_stone`) to starve fortified cities.
- **Urban Salubrity (`salubrity`) & Epidemics (`"epidemic"`):** High urban crowding (`pop / K`), Tier III–IV urban density (`+0.16 * max(0, tier - 2)`), and multi-hex union clustering (`+0.14 * union_partners`) degrade a settlement's `salubrity` (`[0.05, 1.0]`), whereas `cul-communal-conservation` (`+0.20`), `bio-k-strategy` (`+0.14`), and ambient humidity (`+0.08 * humidity`) bolster sanitation. Degraded salubrity dampens positive demographic growth (`* clamp(0.30 + 0.70 * salubrity, 0.25, 1.0)`) and, when **`salubrity < 0.35` with `population >= 130`**, triggers an **Urban Epidemic Outbreak (`"epidemic"`)** that inflicts `22%` population mortality (minimum `10`), rebounds salubrity by `+0.28`, and logs a causal entry in the Chronicle.

![Settlement Tiers I–III, Perimeter Walls & Cultivated Rural Hinterlands](gh-pages/assets/img/screenshot_settlement_tiers_hinterlands.png)

### 3. Authentic Evolutionary, Geopolitical & Dual Synoecism Dynamics
The simulation separates **behavioral intent** (probabilistic decision-making per deme) from **biophysical consequence** (deterministic laws of energy conservation, carrying capacity $K$, metabolic cost, and demography):

- **$r/K$ Selection Trade-offs & The Baldwin Effect:** Prolific density-dependent dispersal (`bio-r-strategy`) vs. high-longevity carrying-capacity buffering, sanitation, and fortification cost discounts (`bio-k-strategy`). Sustained non-foraging behavioral plasticity (`baldwin_counters >= 8`) consolidates into heritable biological adaptations derived from the assimilated decision vector.
- **Dual Inheritance & Complementary Trade (`exchange`):** Populations with cognitive or social capacity (*Encephalization* or *Instinctive Sociability*) unlock cumulative cultural traditions, toolmaking, and horizontal cultural transmission across trade routes—scaling caloric trade surplus up to **$1.35\times$** when trading across distinct biomes ($+12\%$) and distinct cultural repertoires ($+8\%$).
- **Hex-Edge Perimeter Fortifications (`defense_tier: 0..3`):** Settlements invest energy reserves and local hex resources (with a $15\%$ discount for conservation or $K$-strategy traits, plus **allied co-financing**) to construct 2.5D hex-edge perimeter walls (`palisade_wall` at Lv.1 `+45%` defense, `stone_wall` at Lv.2 `+95%` defense, and bastion-reinforced stone curtain walls at Lv.3 `+155%` defense with complete immunity to minor plunder raids).
- **Emergent Geopolitics (Pacts, Vendettas, Tribute, Defensive Coalitions, Sieges & Wars):** Neighboring demes forge **Alliance Pacts** ($+15\%$ mutual caloric bonus, distress aid, and up to $+1.10$ shared military defense), form **Defensive Coalitions**, pay **Tribute / Appeasement** ($18\%$ reserves with zero casualties and a 1-turn truce), harbor multi-turn **Vendettas (`active_pacts < 0`)** after betrayals (`-4` turns) or raids/wars (`-2`/`-3` turns), repel **Fortified Sieges**, and wage **Wars of Conquest** (`<id>-w<gen>` warbands). When an invading warband conquers an occupied hex, the defeated defender **retreats to an adjacent empty passable hex** or is **absorbed in place** (`1/3` population assimilated) if surrounded, strictly preserving `cell.deme_ids.size() <= 1`.
- **Dual Synoecism Architecture (Asymmetric Absorption vs. Continuous Multi-Hex Walled Unions):**
  1. **Asymmetric Category Absorption (`tier_a != tier_b`):** When two long-standing allied neighbors of *different* urban categories (`tier_a != tier_b`) unite, the lower-tier settlement merges into the higher-tier host city—combining population, reserves (up to `280`), and traits, expanding host $K$ (`+35` up to $1.35 \times K_{\max}$), and **automatically converting the vacated hex into a cultivated rural hinterland (`"crops"` or `"pasture"`) owned by the host city** while reducing active LLM inference evaluations per turn.
  2. **Continuous Multi-Hex Walled Unions (`tier_a == tier_b >= 2`, `walled_union_id`):** When two allied neighboring settlements of the *same* urban category (`tier >= 2`) unite, they form a **Continuous Multi-Hex Walled Union (`union-<a>-<b>`, up to 3 hexes)**—remaining on their respective hexes, upgrading perimeter walls (`defense_tier >= 1`), **culling the shared internal wall edge** between their hexes, connecting their plazas via a paved central union boulevard (`"merge"` flow), and pooling `+55%` partner population and `+25%` fortification bonus during combat.
- **Allopatric Speciation:** Geographic isolation (beyond 3 passable hex hops from founder or living lineage kin) across mountain ridges or flooded glacial land bridges triggers phylogenetic divergence into new species lineages while preserving their founding `strategy_id`.

![Continuous Multi-Hex Walled Union (Tier IV Metropolises) & Rural Hinterlands](gh-pages/assets/img/screenshot_late_simulation.png)

### 4. Dual-Model System 1 Cognitive Architecture & 2.5D Illustrated Shader World
- **System 1 Cognitive Engine (`d3:4b` & `tev1:4b` via Ollama):** Evaluates each deme via `/v1/systemone` every generation with its intrinsic trait prior (`strategy_traits_prior`), a **sliding 6-generation historical memory digest** (`war`, `raided`, `betrayal`, `pact`, `fortify`, `merge`, `tribute`, `siege`), active vendetta count, nearby conquering horde detection, and **rich neighbor relational tags** (`kin`, `ally`, `rival`, `vendetta` + posture + relative strength + defense tier), blending neural predictions (**$75\%$**) with deterministic environmental and geopolitical pressures (**$25\%$**).
- **2.5D High-DPI Illustrated & Shader Presentation:** Renders a GPU-accelerated ocean backdrop (`ocean_waves.gdshader`) with multi-ring coastal foam, 10-tier 2.5D cliff extrusions, `256x224` illustrated biome hex tiles (`hex_terrain.gdshader`), `128x128`–`160x160` isometric buildings and swaying flora (`prop_sway_glow.gdshader`) with `#23150c` ink outlines and mipmapped linear filtering (`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`), and a locked-yaw (`yaw_deg = 0.0`) 2.5D camera (`EvoCameraController`).

### 5. Standardized 6-Axis Biophysical Vector & Thermodynamic Conservation
Every biological trait, cultural tradition, and behavioral decision maps to a bounded 6-axis vector (`metabolic_cost`, `extraction_efficiency`, `ecological_impact`, `spatial_mobility`, `social_cohesion` in $[-1, +1]$, and `transmission_threshold` in $[0, +1]$). No trait or decision can violate thermodynamic conservation: positive advantages beyond `BASE_BUDGET = 0.60` strictly require commensurate metabolic or ecological costs ($C_{\text{curr}} \ge 0.50 \cdot (A^+ - 0.60)$).

---

## Scientific Scenarios & 1v1 World Presets (`169` Hexes, `map_radius = 7`)

Every scenario initializes a balanced **1v1 Evolutionary Strategy Duel** (`Strategy A` vs. `Strategy B`, defaulting to `strat-cooperation` 🤝 vs. `strat-war` ⚔️) across a `169`-hex (`map_radius = 7`) world that can be customized at Generation 0 from the top HUD matchup bar:

### The Rift Valley (`preset-rift-savanna`)
A tectonic mountain ridge (`q = 0`, `altitude = 0.88`, pierced by three savanna mountain passes at `(0, -3)`, `(0, 0)`, and `(0, 3)`) divides a lush western tropical rainforest (`84` hexes) from a drying eastern savanna-steppe mosaic (`84` hexes). **Western Forest Hominids** (`deme-rift-west` at `(-2, 1)`, Strategy A, `pop = 140`) face off against **Eastern Savanna Hominids** (`deme-rift-east` at `(2, -1)`, Strategy B, `pop = 140`).

### Darwin's Archipelago (`preset-darwin-archipelago`)
Volcanic islands linked by shallow intertidal land bridges (`0,-1`, `0,1`, `2,0`, `-2,1`, `0,-4`, `0,4`, `4,-1`) that periodically emerge and flood with 8-generation glacial sea-level cycles (`0.12` $\leftrightarrow$ `0.25`). Two rival island founders—**Western Island Founders** (`deme-darwin-founder` at `(-1, 0)`, Strategy A, `pop = 95`) and **Eastern Island Rivals** (`deme-darwin-rival` at `(1, 0)`, Strategy B, `pop = 95`)—race across temporary land bridges during low tides and undergo allopatric speciation when rising seas isolate colonies across northern tundra, southern rainforest, and eastern steppe islands.

![Darwin's Archipelago — 169-Hex Insular Dispersal & Tidal Land Bridges](gh-pages/assets/img/screenshot_darwin_archipelago.png)

### The Finite Island (`preset-finite-island`)
A fertile but geographically bounded island surrounded by deep ocean where two competing clans—**Northern Quarry Clan** (`deme-island-1` at `(-1, 0)`, Strategy A, `pop = 95`) and **Southern Timber Clan** (`deme-island-2` at `(1, 0)`, Strategy B, `pop = 95`)—share a fragile savanna core ($d \le 1$, $r_{\text{regen}} = 0.08$) encircled by arid steppe ($2 \le d \le 3$) and coastal shallows ($d = 4$). Without communal conservation norms and sustainable hinterland management, intensive overexploitation and Hawk-Dove conflict degrade carrying capacity $K$ below $60\%$ of $K_{\max}$ and trigger the *Tragedy of the Commons*.

![The Finite Island — Ecological Health Lens & Valley Legend](gh-pages/assets/img/screenshot_finite_island.png)

---

## Interactive Modals & Analytical Tools

### Naturalist's Notebook — Evolutionary Chronicle
Tracks every evolutionary, demographic, and geopolitical milestone (**Wars**, **Sieges**, **Plunder Raids**, **Tributes**, **Alliance Pacts**, **Settlement Unifications & Walled Unions**, **Fortifications**, **Betrayals**, **Baldwin Effect**, **Cultural Innovation**, **Allopatric Speciation**, **Symbiosis**, **Tragedy of the Commons**, **Cultural Loss**, **Extinction**, **Urban Epidemics**, **Evolutionary Hegemony**, and **Dynamic Equilibrium**) across **19 category filters** with one-click camera jumps to the exact hexagon where the event occurred.

![Naturalist's Notebook — Evolutionary Chronicle Modal](gh-pages/assets/img/screenshot_notebook_modal.png)

### Phylo-Cultural Lineage Tree
Visualizes ancestral and diverged lineages, founding and extinction generations, inherited `strategy_id`, acquired biological and cultural traits, and active settlements (`I–IV`), with interactive map lineage highlighting.

![Phylo-Cultural Lineage Tree Modal](gh-pages/assets/img/screenshot_tree_modal.png)

### Strategy, Trait & Decision Forge — Evolutionary Laboratory
An open 4-tab catalog editor (`🛡️ Strategies`, `🧬 Biological Traits`, `🔥 Cultural Traditions`, and `⚖️ Behavioral Decisions`) to inspect, tweak, or craft new traits, decisions, and custom evolutionary strategies—complete with a live **Thermodynamic Balance Meter**, combined 6-axis footprint preview, one-click assignment to **Strategy A / Strategy B**, direct trait injection into any active settlement, and automatic persistence to `~/.config/Evolution/user_catalog.json`.

![Trait & Decision Forge — Evolutionary Laboratory Modal](gh-pages/assets/img/screenshot_lab_modal.png)

---

## Controls & God-Mode Hotbar

| Input / Shortcut | Action |
| :--- | :--- |
| **Left Click** | Select settlement or hex (Observe mode) / Apply active terrain or climate brush (`1x` or `7x` radius) |
| **W / A / S / D** or **Middle / Right Click + Drag** | Pan camera across the `169`-hex 2.5D valley; **R / F** or **Right Drag** tilts pitch ($32^\circ\text{–}68^\circ$, locked horizontal yaw $0^\circ$) |
| **Mouse Wheel** or **+ / -** | Cursor-pivoted zoom (`0.18x` macro archipelago view to `2.80x` settlement close-up) |
| **Space** | Toggle Play / Pause generational simulation |
| **Keys `1` – `0`** | Equip slot from the 10-slot bottom Hotbar (`1`: Observe, `2–5`: Biome Brushes, `6–7`: Raise/Lower Altitude, `8–9`: Enrich/Deplete $K$, `0`: Sea Level & Tidal Bar) |
| **Escape** | Close active modal or return to the `Observe` tool |

---

## Installation & Getting Started

### Prerequisites
- **[Ollama](https://ollama.com/)** *(Required)* running locally on `http://127.0.0.1:11434` with the configured System 1 decision models (`d3:4b`, `tev1:4b`). Because Evolution exclusively studies neural decision-model behavior, if Ollama is offline at startup, a blocking warning popup prevents the game from starting and closes the application when dismissed.

### Prebuilt Release Binaries

Download the latest release for your operating system from the [**GitHub Releases**](https://github.com/arrase/Evolution/releases/latest) page:

#### Linux (`x86_64`)
1. Download `evolution-linux-x86_64.tar.gz`.
2. Extract the archive and run the executable:
   ```bash
   tar -xzf evolution-linux-x86_64.tar.gz
   chmod +x evolution-linux-x86_64
   ./evolution-linux-x86_64
   ```

#### Windows (`x86_64`)
1. Download `evolution-windows-x86_64.zip`.
2. Extract the `.zip` archive to any folder.
3. Double-click `evolution-windows-x86_64.exe` to launch the simulator (if Windows SmartScreen appears, click **More info** → **Run anyway**).

#### macOS (`Universal` — Apple Silicon & Intel)
1. Download `evolution-macos-universal.zip`.
2. Double-click the `.zip` file to extract `Evolution.app`, and optionally move it to `/Applications`.
3. Because the bundle is unsigned, remove the macOS Gatekeeper quarantine attribute before launching for the first time (or Right-Click → **Open**):
   ```bash
   xattr -dr com.apple.quarantine Evolution.app
   open Evolution.app
   ```

### Running from Source
Requires **Godot Engine 4.7+** (`4.7.2-stable` recommended):
```bash
# Import project assets and launch the simulator
godot --path .
```

### Running the Automated Test Suite
The repository includes a headless unit, integration, and UI verification suite covering `169`-hex axial geometry, 1-deme-per-hex invariants, 6-axis thermodynamic conservation, rural hinterlands, urban salubrity & epidemics, dual synoecism (`walled_union_id` & category absorption), i18n, and HUD interactions:
```bash
godot --headless --path . --script res://tests/test_runner.gd
```

### Regenerating Documentation Screenshots
To regenerate all documentation screenshots in `gh-pages/assets/img/`:
```bash
godot --path . --script res://tests/test_visual_capture.gd
```

---

## Project Structure

```text
├── assets/                 # Themes and auto-cached high-DPI illustrated sprite directories (v3_illustrated_hdpi)
├── gh-pages/               # MkDocs documentation & shared 1920x1080 screenshots (ignored by Godot via .gdignore)
├── scenes/main.tscn        # Root scene entry point
├── src/
│   ├── main.gd             # Main controller, turn loop timer, and signal orchestration
│   ├── core/               # Data structures (EvoTypes), 6-axis thermodynamics, 169-hex math, catalog, presets, i18n
│   ├── engine/             # Generational turn engine, biophysical/demographic phases, and dual-model cognitive engine
│   ├── ui/                 # Field-journal HUD, scroll inspector, hotbar dock, and modals (Journal, Lineages, Forge)
│   └── world/              # 2.5D illustrated hex renderer, GPU shaders, procedural HD sprites, walled unions, camera
└── tests/                  # Headless simulation/UI test runner and visual capture script
```
