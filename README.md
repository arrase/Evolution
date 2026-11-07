# Evolution

[![CI](https://github.com/arrase/Evolution/actions/workflows/ci.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/ci.yml)
[![CodeQL](https://github.com/arrase/Evolution/actions/workflows/codeql.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/codeql.yml)
[![Security Audit](https://github.com/arrase/Evolution/actions/workflows/security.yml/badge.svg)](https://github.com/arrase/Evolution/actions/workflows/security.yml)

**Evolution** is an interactive bio-cultural and evolutionary population simulator built with **Godot 4.7**, featuring a handcrafted cozy pixel-art aesthetic on an isometric hexagonal ecosystem.

Rather than commanding individual units directly, you act as the **Selective Pressure** and **Evolutionary Architect**—configuring **1v1 Evolutionary Strategy Duels (`Strategy A ⚔️ Strategy B`)** before pressing Play, forging custom strategies and traits, and shaping climates, terrain altitude, sea levels, and habitat carrying capacity ($K$)—while local subpopulations (*demes*) autonomously evaluate their surroundings, adapt, migrate, cooperate, innovate, or diverge into new species.

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

### 2. Authentic Evolutionary & Socio-Cultural Dynamics
The simulation separates **behavioral intent** (probabilistic decision-making per deme) from **biophysical consequence** (deterministic laws of energy conservation, carrying capacity $K$, metabolic cost, and demography):
- **$r/K$ Selection Trade-offs:** Prolific dispersal vs. high-longevity carrying-capacity buffering.
- **The Baldwin Effect (Genetic Assimilation):** Sustained behavioral plasticity under environmental stress consolidates into heritable biological adaptations.
- **Dual Inheritance Theory:** Populations with cognitive or social capacity (*Encephalization* or *Instinctive Sociability*) unlock cumulative cultural traditions, toolmaking, and horizontal cultural transmission across trade routes.
- **Evolutionary Game Theory:** Cohabiting and neighboring demes navigate *Hawk-Dove* territorial disputes, reciprocal symbiosis, or the *Tragedy of the Commons* when intensive overexploitation degrades $K$ below $60\%$ of $K_{\max}$.
- **Allopatric Speciation:** Geographic isolation across mountain ridges or flooded glacial land bridges triggers phylogenetic divergence into new lineages while preserving their founding `strategy_id`.

### 3. Dual-Model System 1 Cognitive Architecture (Ollama)
- **System 1 (High-Frequency Turn Scoring — `d3:4b` & `tev1:4b`):** Evaluates each deme and its 6-hex neighborhood every generation, deterministically assigning subpopulations across the primary (`d3:4b`) and secondary (`tev1:4b`) Ollama decision models to compute normalized probability distributions over behavioral archetypes.
- **Deterministic Milestone Synthesis (`EvoMilestonePhase`):** Synthesizes emergent traits, cultural innovations, allopatric speciation, and natural history chronicle entries within strict thermodynamic bounds.

### 4. Standardized 6-Axis Biophysical Vector & Thermodynamic Conservation
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
A fertile but geographically bounded island surrounded by deep ocean where two competing clans—**Northern Quarry Clan** (`deme-island-1` at `(-1, 0)`, Strategy A, `pop = 95`) and **Southern Timber Clan** (`deme-island-2` at `(1, 0)`, Strategy B, `pop = 95`)—share a fragile savanna core ($r_{\text{regen}} = 0.08$). Without communal conservation norms, intensive overexploitation and Hawk-Dove conflict degrade local carrying capacity $K$ below $60\%$ of $K_{\max}$ and trigger the *Tragedy of the Commons*.

![The Finite Island — Ecological Health Lens & Valley Legend](gh-pages/assets/img/screenshot_finite_island.png)

---

## Interactive Modals & Analytical Tools

### Naturalist's Notebook — Evolutionary Chronicle
Tracks every evolutionary milestone (Baldwin Effect, Cultural Innovation, Allopatric Speciation, Symbiosis, Tragedy of the Commons, Cultural Loss, and Extinction) with category filters and one-click camera jumps to the exact hexagon where the event occurred.

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
| **Mouse Wheel** | Zoom camera in / out |
| **Space** | Toggle Play / Pause generational simulation |
| **Keys `1` – `0`** | Equip slot from the 10-slot bottom Hotbar (`1`: Observe, `2–6`: Biome Brushes, `7–8`: Raise/Lower Altitude, `9`: Enrich Food $K$, `0`: Sea Level) |
| **Escape** | Close active modal or return to the `Observe` tool |

---

## Getting Started

### Prerequisites
- **Godot Engine 4.7+** (`4.7.2-stable` recommended)
- **[Ollama](https://ollama.com/)** *(Required)* running locally on `http://127.0.0.1:11434` with the configured System 1 decision models (`d3:4b`, `tev1:4b`). Because Evolution exclusively studies neural decision-model behavior, if Ollama is offline at startup, a blocking warning popup prevents the game from starting and closes the application when dismissed.

### Running from Source
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
├── assets/                 # Themes and sprite directories
├── gh-pages/               # MkDocs documentation & shared screenshots (ignored by Godot via .gdignore)
├── scenes/main.tscn        # Root scene entry point
├── src/
│   ├── main.gd             # Main controller, turn loop timer, and signal orchestration
│   ├── core/               # Data structures (EvoTypes), 6-axis thermodynamics, hex math, catalog, presets, i18n
│   ├── engine/             # Generational turn engine, biophysical phases, and dual-model cognitive engine
│   ├── ui/                 # Pixel-art HUD, scroll inspector, hotbar dock, and modals (Journal, Lineages, Forge)
│   └── world/              # 2.5D isometric hexagonal renderer, procedural pixel-art sprites, road networks, camera
└── tests/                  # Headless simulation/UI test runner and visual capture script
```
