# Evolution

[![CI](https://github.com/arrase/Evolution/actions/workflows/ci.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/ci.yml)
[![CodeQL](https://github.com/arrase/Evolution/actions/workflows/codeql.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/codeql.yml)
[![Security Audit](https://github.com/arrase/Evolution/actions/workflows/security.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/security.yml)

**Evolution** is an interactive bio-cultural and evolutionary population simulator built with **Godot 4.7**, featuring a high-definition 2.5D procedural vector and GPU-shader isometric hexagonal ecosystem with concentric morphological living settlements and a 3-tier semantic zoom lens (`Macro`, `Meso`, `Micro`).

Rather than commanding individual units directly, you act as the **Selective Pressure** and **Evolutionary Architect**—configuring **1v1 Evolutionary Strategy Duels (`Strategy A ⚔️ Strategy B`)** before pressing Play, forging custom strategies and traits, and shaping climates, terrain altitude, sea levels, and habitat carrying capacity ($K$)—while local subpopulations (*demes*, strictly one sovereign settlement per hex cell) autonomously evaluate their surroundings, adapt, migrate, cooperate, innovate, or diverge into new species across shared hexagonal borders.

![The Rift Valley — Isometric Hexagonal Ecosystem & HUD](gh-pages/assets/img/screenshot_rift_savanna.png)

---

## Key Features

### 1. 1v1 Evolutionary Strategy Duels (`Strategy A ⚔️ Strategy B`)
Before launching a simulation at Generation 0, you choose which two **Evolutionary Strategies** (`EvoTypes.StrategyDef`) will face off across the valley—or forge your own in the **Evolutionary Laboratory** (persisted automatically to `~/.config/Evolution/user_catalog.json`). Each strategy bundles compatible biological adaptations and cultural traditions, imbuing its founding lineage and daughter villages with a distinct emblem, color identity, and combined 6-axis biophysical footprint:

| Strategy ID | Emblem & Name (EN / ES) | Color | Bundled Traits (`bio-*` + `cul-*`) | Evolutionary Philosophy |
| :--- | :--- | :---: | :--- | :--- |
| `strat-cooperation` | 🤝 **Cooperative Alliance**<br>*Alianza Cooperativa* | `#10B981` | `bio-k-strategy`, `bio-social-instinct` + `cul-communal-conservation` | Fosters social cohesion, communal habitat conservation, and resource buffering. |
| `strat-expansion` | 🧭 **Expansionist Pioneers**<br>*Pioneros Expansionistas* | `#3B82F6` | `bio-r-strategy`, `bio-thermal-tolerance`, `bio-social-instinct` + `cul-fire-processing` | Fast reproduction, high mobility, and thermal tolerance to colonize new territories. |
| `strat-trade` | ⚖️ **Merchant League**<br>*Liga Mercantil* | `#F59E0B` | `bio-k-strategy`, `bio-encephalization` + `cul-interdeme-barter` | Drives inter-village barter, commercial symbiosis, and horizontal cultural diffusion. |
| `strat-war` | ⚔️ **Conquering Horde**<br>*Horda Conquistadora* | `#EF4444` | `bio-r-strategy`, `bio-social-instinct` + `cul-warrior-expansion`, `cul-extraction-tools` | Aggressive martial expansion and intensive extraction to dominate rival territories. |
| `strat-innovation` | 🔬 **Innovator Technocrats**<br>*Tecnócratas Innovadores* | `#A855F7` | `bio-encephalization`, `bio-digestive-spec` + `cul-fire-processing`, `cul-extraction-tools` | High encephalization, thermal food processing, and specialized extraction toolkits. |

### 2. Sovereign Hex Cells & Inter-Cell Border Dynamics
The simulation separates **behavioral intent** (probabilistic decision-making per deme) from **biophysical consequence** (deterministic laws of energy conservation, carrying capacity $K$, metabolic cost, and demography) on a **strictly 1-deme-per-hex** (`cell.deme_ids.size() <= 1`, `get_resident_deme_id` / `set_resident_deme_id`) territorial grid where all inter-deme interactions occur across shared hex borders (`HexEdgeFlow`):
- **$r/K$ Selection Trade-offs:** Prolific dispersal into empty passable neighbor hexes vs. high-longevity carrying-capacity buffering and fortification cost discounts.
- **The Baldwin Effect (Genetic Assimilation):** Sustained behavioral plasticity under environmental stress consolidates into heritable biological adaptations derived from the dominant behavioral vector.
- **Dual Inheritance & Inter-Cell Complementary Trade (`exchange`):** Populations with cognitive or social capacity (*Encephalization* or *Instinctive Sociability*) unlock cumulative cultural traditions, toolmaking, and horizontal cultural transmission across shared hex borders—boosting mutual energy extraction by $+20\%$ (`1.20x`) and scaling caloric trade surplus up to **$1.35\times$** when trading across distinct biomes ($+12\%$) and distinct cultural repertoires ($+8\%$).
- **Multi-Tier Defense System (`defense_tier: 0..3`):** Settlements invest energy reserves and local hex resources (with a $15\%$ discount for conservation, storage, or $K$-strategy traits, plus **allied co-financing** from wealthy pact partners) to construct concentric Ring 2 perimeter fortifications with per-turn upkeep:
  - **Tier 1 — Palisade & Watchtower (`+45%` defense, `-25%` raid loot & casualties, `1.5` upkeep/turn)**
  - **Tier 2 — Stone Wall & Fort (`+95%` defense, `-60%` raid loot, `-50%` raid casualties, `3.0` upkeep/turn)**
  - **Tier 3 — Castle / Fortified Citadel (`+155%` defense, complete immunity to minor plunder raids, heavy siege attrition to attackers, `5.0` upkeep/turn)**
- **Inter-Cell Border Geopolitics (Hawk-Dove Disputes, Pacts, Vendettas, Tribute, Sieges & Wars):** Adjacent demes across shared hex borders forge formal **Alliance Pacts** (providing $+15\%$ mutual caloric bonuses, distress aid transfers, and up to $+1.10$ shared military defense), form **Defensive Coalitions** (lowered cooperation threshold `0.22` when facing an adjacent martial horde threat), clash in **Inter-Cell Hawk-Dove Border Disputes** (where Hawks annex border resources from adjacent Doves or suffer mutual $-15\%$ population and $\times 1.25$ metabolic attrition against rival Hawks), pay **Tribute / Appeasement** ($18\%$ reserves to deter raids with zero casualties), harbor multi-turn **Vendettas (`active_pacts < 0`)**, repel **Fortified Sieges**, and launch **Wars of Conquest** across hex borders or face the *Tragedy of the Commons* ($K < 60\%$ of $K_{\max}$).
- **3-Step Displacement Cascade (`evacuate_or_merge_displaced_deme`):** Whenever a deme is displaced by warband invasion or coastal submergence, it resolves deterministically through: (1) **Evacuation** to the richest empty passable neighbor hex, (2) **Refugee Merger** into the largest adjacent allied (`is_pact_active`) or compatible kin (`divergence <= 0.35`) settlement, or (3) **Extinction** if no refuge exists.
- **Inter-Cell Kin Mergers & City Unification / Synoecism (`merge`, Tier 5 Unified Metropolis):** Compatible adjacent kin (`divergence <= 0.25`) or long-standing adjacent allies (`pact >= 4`, or `>= 3` under threat or fortification) unite across their shared border into a single **Tier 5 Unified Metropolis (`Deme`)**—combining population, reserves (up to `280`), and biological/cultural traits, elevating shared castle defenses, expanding host hex urban carrying capacity $K$ ($+35$ up to $1.35 \times K_{\max}$), rendering dual concentric strategy rings, and **directly reducing the number of LLM inference requests per turn**.
- **Allopatric Speciation:** Geographic isolation (beyond 3 passable hex hops from founder or living lineage kin) across mountain ridges or flooded glacial land bridges triggers phylogenetic divergence into new lineages while preserving their founding `strategy_id`.

### 3. Procedural Vector World, Concentric Living Settlements & 3-Tier Semantic Zoom
- **GPU-Shader 2.5D Hex Columns (`EvoWorldRenderer`):** Renders procedural 2.5D vector hex columns with GPU `ShaderMaterial` shaders (`OCEAN_SHADER_CODE` animated waves/foam and `TERRAIN_SHADER_CODE` biome micro-relief across outer, mid, and inner bevel rings with `season_warmth` uniforms), while `EvoPixelArtGen` generates only in-memory `UI_SPRITES` (`ImageTexture`s) with zero disk PNG I/O.
- **Concentric Morphological Settlements (`EvoPropFloraRenderer`):** Every settlement (`build_settlement_morphology` / `get_settlement_morphology_summary`) is synthesized procedurally in three concentric rings:
  - **Ring 0 (Core Plaza & Citadel):** Earthen terrace, stone plaza, strategy mosaic ring (doubled for merged metropolises), and an archetype-driven central citadel (`forage_lodge`, `amphitheater_dome`, `twin_canopy_market`, `horned_war_keep`, `furnace_rig`, `nomad_pavilion`, `astronomical_spire`) scaled across Tiers 1..5.
  - **Ring 1 (Trait Crown):** Up to 6 radial architectural modules mapped deterministically from the deme's `biological_trait_ids` and `cultural_trait_ids` (`TRAIT_MODULE_MAP` / `TRAIT_RING_CATALOG`: e.g., `crystal_obelisk`, `hearth_circle`, `brood_totem`, `terraced_sanctuary`, `war_brazier`, `grove_shrine`, `caravan_depot`, `granary_silo`, `lithic_workshop`, `monolith`).
  - **Ring 2 (Defense Perimeter & Flora):** Tiered perimeter fortifications (`defense_tier 0..3`: timber palisades, crenellated stone walls, or 6-towered bastions) surrounded by biome-reactive procedural flora.
- **Priority-Ranked Border Flows & Fronts (`EvoRoadNetworkRenderer`):** Deduplicates inter-cell border interactions by `FLOW_PRIORITY` (`"merge" > "war" > "siege" > "betrayal" > "raid" > "tribute" > "pact" > "migration" > "collab" > "symbiosis" > "exchange" > "cooperate" > "dispute"`) and draws persistent diplomatic/conflict fronts along shared hex edges.
- **3-Tier Semantic Zoom (`Macro`, `Meso`, `Micro`):**
  - **Macro (`zoom < 0.68`):** Territory strategy color wash on occupied hexes, high-contrast lineage medallions (`pop` + strategy badge + vital arc), and inter-cell border fronts (micro props and villagers culled).
  - **Meso (`0.68 <= zoom < 1.35`):** Concentric morphological settlements (Ring 0/1/2), Decision Intent Crests, compact village nameplates, and animated directional border flows.
  - **Micro (`zoom >= 1.35`):** Micro diagnostic overlays (`pop / K_eff`, `energy_reserves` delta badge, and `baldwin` / `innovation` / `isolation` progress bars), radial Ring 1 trait labels, and orbiting villager activity.

### 4. Sequential 4-Step Micro-Phase Turn Playback & Dual-Model System 1 (Ollama)
- **Sequential 4-Step Micro-Phase Playback (`EvoTurnEngine` & `EvoHudTopBar`):** At `1x` speed, each generation unfolds visually across 4 sequential micro-phases tracked by the **4-pip Turn Phase Bar** (`1. Env`, `2. Mind`, `3. Clash`, `4. Lineage`) and dedicated world overlay visual beats (`EvoWorldOverlayRenderer`):
  1. **`1. Env` (`step_phase_1_environment`):** Advances climate/tides, regenerates hex resources (expanding emerald/amber resource pulse rings), and triggers Phase 1 Ollama signature prefetching (`prefetch_for_state(state, true)`).
  2. **`2. Mind` (`step_phase_2_decisions`):** Applies System 1 neural decision probabilities blended with environmental weights and displays Decision Intent Crests with dashed golden intent tethers to occupied neighbor hexes.
  3. **`3. Clash` (`step_phase_3_ecology_borders`):** Resolves resource extraction, inter-cell Hawk-Dove border disputes, symbiotic trade, pacts, raids, tributes, and fortifications with pulsing crimson/emerald border clash rings at shared hex edge midpoints.
  4. **`4. Lineage` (`step_phase_4_demography_milestones`):** Resolves metabolic upkeep, population growth, warband invasions, fission migrations, kin/synoecism merges, and evolutionary milestones with floating `+Pop / -Pop` delta badges, then prefetches next-turn lookahead Ollama signatures (`prefetch_for_state(state, false)`).
- **System 1 (High-Frequency Turn Scoring — `d3:4b` & `tev1:4b`):** Evaluates each deme via `/v1/systemone` using a compact state prompt featuring `BorderCompetition: adjRivals, adjKin, pacts, vendettas`, intrinsic trait priors (`strategy_traits_prior`), a 6-generation historical memory digest, and neighbor relational tags, blending neural outputs (**$75\%$**) with deterministic environmental & geopolitical pressures (**$25\%$**).

### 5. Standardized 6-Axis Biophysical Vector & Thermodynamic Conservation
Every biological trait, cultural tradition, and behavioral decision maps to a bounded 6-axis vector:
1. `metabolic_cost` ($[-1, +1]$)
2. `extraction_efficiency` ($[-1, +1]$)
3. `ecological_impact` ($[-1, +1]$)
4. `spatial_mobility` ($[-1, +1]$)
5. `social_cohesion` ($[-1, +1]$)
6. `transmission_threshold` ($[0, +1]$)

No trait or decision can violate thermodynamic conservation: high caloric extraction or neural complexity requires commensurate metabolic or ecological costs.

---

## Scientific Scenarios & 1v1 World Presets

Every scenario initializes a balanced **1v1 Evolutionary Strategy Duel** (`Strategy A` vs. `Strategy B`, defaulting to `strat-cooperation` 🤝 vs. `strat-war` ⚔️) that can be customized at Generation 0 from the top HUD matchup bar:

### The Rift Valley (`preset-rift-savanna`)
A tectonic mountain ridge divides a stable western tropical rainforest from a drying eastern savanna-steppe mosaic. **Western Forest Hominids** (`deme-rift-west` at `(-2, 1)`, Strategy A, `pop = 140`) face off across the ridge against **Eastern Savanna Hominids** (`deme-rift-east` at `(2, -1)`, Strategy B, `pop = 140`). Seasonal aridification in the east drives cooperation, storage, migration, Baldwin assimilation, and cultural innovation while western forest populations leverage abundant biomass.

![Late Simulation in The Rift Valley — Consolidated Settlements & Road Networks](gh-pages/assets/img/screenshot_late_simulation.png)

### Darwin's Archipelago (`preset-darwin-archipelago`)
Volcanic islands linked by shallow coastal land bridges (`0,-1`, `0,1`, `2,0`) that periodically emerge and flood with 8-generation glacial sea-level cycles. Two rival island founders—**Western Island Founders** (`deme-darwin-founder` at `(-1, 0)`, Strategy A, `pop = 95`) and **Eastern Island Rivals** (`deme-darwin-rival` at `(1, 0)`, Strategy B, `pop = 95`)—race across temporary land bridges during low tides and undergo allopatric speciation when rising seas isolate colonies across tundra, forest, and arid steppe islands.

![Darwin's Archipelago — Insular Dispersal & Land Bridges](gh-pages/assets/img/screenshot_darwin_archipelago.png)

### The Finite Island (`preset-finite-island`)
A fertile but geographically bounded island surrounded by deep ocean where two competing clans—**Northern Quarry Clan** (`deme-island-1` at `(-1, 0)`, Strategy A, `pop = 95`) and **Southern Timber Clan** (`deme-island-2` at `(1, 0)`, Strategy B, `pop = 95`)—occupy neighboring hexes across a fragile savanna core ($r_{\text{regen}} = 0.08$). Without communal conservation norms, intensive overexploitation and inter-cell Hawk-Dove border conflict degrade local carrying capacity $K$ below $60\%$ of $K_{\max}$ and trigger the *Tragedy of the Commons*.

![The Finite Island — Ecological Health Lens & Valley Legend](gh-pages/assets/img/screenshot_finite_island.png)

---

## Interactive Modals & Analytical Tools

### Naturalist's Notebook — Evolutionary Chronicle
Tracks every evolutionary and geopolitical milestone (**Wars**, **Sieges**, **Plunder Raids**, **Tributes**, **Alliance Pacts**, **City Unifications**, **Fortifications**, **Betrayals**, **Baldwin Effect**, **Cultural Innovation**, **Allopatric Speciation**, **Symbiosis**, **Tragedy of the Commons**, **Cultural Loss**, **Extinction**, **Evolutionary Hegemony**, and **Dynamic Equilibrium**) across **18 category filters** with one-click camera jumps to the exact hexagon where the event occurred.

![Naturalist's Notebook — Evolutionary Chronicle Modal](gh-pages/assets/img/screenshot_notebook_modal.png)

### Phylo-Cultural Lineage Tree
Visualizes ancestral and diverged lineages, founding and extinction generations, inherited `strategy_id`, acquired biological and cultural traits, and active villages, with interactive map lineage highlighting.

![Phylo-Cultural Lineage Tree Modal](gh-pages/assets/img/screenshot_tree_modal.png)

### Strategy, Trait & Decision Forge — Evolutionary Laboratory
An open 4-tab catalog editor (`🧬 Biological Traits`, `🔥 Cultural Traditions`, `⚖️ Behavioral Decisions`, and `🛡️ Strategies`) to inspect, tweak, or craft new traits, decisions, and custom evolutionary strategies—complete with a live **Thermodynamic Balance Meter**, combined 6-axis footprint preview, one-click assignment to **Strategy A / Strategy B**, direct trait injection into any active village, and automatic persistence to `~/.config/Evolution/user_catalog.json`.

![Trait & Decision Forge — Evolutionary Laboratory Modal](gh-pages/assets/img/screenshot_lab_modal.png)

---

## Controls & God-Mode Hotbar

| Input / Shortcut | Action |
| :--- | :--- |
| **Left Click** | Select village or hex (Observe mode) / Apply active terrain or climate brush |
| **Right Click + Drag** / **Middle Click + Drag** | Pan camera across the hexagonal valley |
| **Mouse Wheel** | Zoom camera smoothly across `Macro` (`< 0.68`), `Meso` (`0.68–1.35`), and `Micro` (`>= 1.35`) semantic zoom tiers |
| **Space** | Toggle Play / Pause generational simulation |
| **Keys `1` – `0`** | Equip slot from the 10-slot bottom Hotbar (`1`: Observe, `2–6`: Biome Brushes, `7–8`: Raise/Lower Altitude, `9`: Enrich Food $K$, `0`: Sea Level) |
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
The repository includes a headless unit, integration, and UI verification suite covering hexagonal math, thermodynamic conservation, demographic turn phases, i18n, and HUD interactions:
```bash
godot --headless --path . --script res://tests/test_runner.gd
```

### Regenerating Documentation Screenshots
To regenerate all English screenshots in `gh-pages/assets/img/`:
```bash
godot --path . --script res://tests/test_visual_capture.gd
```

---

## Project Structure

```text
├── assets/                 # Themes and UI resources
├── gh-pages/               # MkDocs documentation & shared screenshots (ignored by Godot via .gdignore)
├── scenes/main.tscn        # Root scene entry point
├── src/
│   ├── main.gd             # Main controller, 4-step micro-phase turn timer, and signal orchestration
│   ├── core/               # Data structures (EvoTypes), 6-axis thermodynamics, hex math, catalog, presets, i18n
│   ├── engine/             # 4-phase generational turn engine, border biophysical phases, and System 1 cognitive engine
│   ├── ui/                 # Naturalist HUD, 4-pip Turn Phase Bar, scroll inspector, hotbar dock, and modals
│   └── world/              # 2.5D GPU-shader hex renderer, concentric morphological settlements, border networks, camera
└── tests/                  # Headless simulation/UI test runner and visual capture script
```
