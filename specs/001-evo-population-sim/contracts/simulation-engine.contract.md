# Contract: Deterministic Biophysical Simulation Engine

**Feature**: `001-evo-population-sim`
**Module**: `src/engine/`
**Requirements Covered**: `FR-001`..`FR-004`, `FR-007`..`FR-009`, `FR-013`, `FR-014`, `SC-001`, `SC-002`, `SC-005`

## 1. Funciones Puras de Simulación (`src/engine/`)

El motor biofísico está compuesto por funciones deterministas organizadas en `src/engine/environmentalPhase.ts`, `src/engine/biophysicalPhase.ts`, `src/engine/milestonePhase.ts`, `src/engine/thermodynamics.ts` y orquestadas por `src/engine/turnEngine.ts`:

```typescript
export function executeGenerationalTurn(
  state: WorldState,
  provider: CognitiveProvider
): Promise<WorldState>;

export function runEnvironmentalPhase(state: WorldState): WorldState;

export function resolveBiophysicalAndDemographicPhase(
  state: WorldState,
  decisionsByDemeId: Record<string, DemeDecisionEvaluationOutput>
): WorldState;

export function detectEvolutionaryMilestones(
  state: WorldState
): MilestoneSynthesisInput[];

export function applySynthesizedMilestone(
  state: WorldState,
  input: MilestoneSynthesisInput,
  proposal: SynthesizedTraitProposal
): WorldState;

export function validateAndBalanceThermodynamics(
  vector: BiophysicalVector,
  freeSandboxMode: boolean
): { balancedVector: BiophysicalVector; wasAdjusted: boolean; requiredCompensation: number };

export function computeDemeDivergence(demeA: Deme, demeB: Deme): number;
```

---

## 2. Fórmulas Matemáticas por Fase del Turno (`FR-004`)

### Fase 1: Actualización Ambiental, Estacional y Nivel del Mar (`runEnvironmentalPhase`)

1. **Alternancia Estacional**: Cada generación alterna `season` entre `'wet_warm'` (modificador climático $\Delta T = +0.10, \Delta H = +0.12$, factor de regeneración $\gamma_{\text{season}} = 1.20$) y `'dry_cold'` ($\Delta T = -0.10, \Delta H = -0.12, \gamma_{\text{season}} = 0.75$).
2. **Ciclo de Nivel del Mar (en presets con ciclo glaciar activo)**:
   En *"Archipiélago de Darwin"*, cada 8 generaciones `seaLevel` alterna entre `0.12` (glaciación: las celdas con `altitude = 0.18` emergen como `coastal_shallows` transitables / puentes terrestres) y `0.25` (interglaciar: las celdas con `altitude < 0.25` pasan a `ocean` sumergido).
3. **Desplazamiento Forzado por Sumersión**: Si una celda con `demeIds.length > 0` pasa a `ocean`, cada *deme* residente se desplaza al hexágono terrestre vecino con mayor `currentResources` y `< 3` *demes* (aplicando una pérdida del $20\%$ de `energyReserves`); si no existe celda terrestre vecina con cupo, el *deme* se extingue registrando una `ChronicleEntry`.
4. **Regeneración Estacional de Recursos y $K$**:
   - Si la celda no sufrió sobreexplotación en el turno anterior, $K$ se recupera suavemente hacia $K_{\max}$:
     $$K_{t+1} = \min\left(K_{\max},\; K_t + 0.05 \cdot (K_{\max} - K_t)\right)$$
   - La biomasa disponible (`currentResources`) se regenera:
     $$R_{t+1} = \min\left(K_{t+1},\; R_t + K_{t+1} \cdot \text{seasonalRegenRate} \cdot \gamma_{\text{season}}\right)$$

---

### Fase 3: Resolución Biofísica, Teoría de Juegos, Fisión Migratoria y Demografía (`resolveBiophysicalAndDemographicPhase`)

Para cada *deme* $d$, sea $\vec{V}_{\text{traits}}(d)$ la suma de los vectores biofísicos de sus rasgos biológicos y tradiciones culturales activos, y sea $\vec{V}_{\text{dec}}(d) = \sum_i P_i \cdot \vec{V}(\text{decision}_i)$ el vector ponderado de sus decisiones del turno:
$$\vec{V}_{\text{eff}}(d) = \text{clamp}_{[-1.5, 1.5]}\left(\vec{V}_{\text{traits}}(d) + \vec{V}_{\text{dec}}(d)\right)$$

1. **Extracción Energética e Interacción Inter-Deme en el Hexágono (`FR-009`)**:
   - **Demanda Base de Extracción**:
     $$E_{\text{req}}(d) = \text{population}_d \cdot 0.50 \cdot \left(1 + 0.60 \cdot V_{\text{eff, extraction}}(d)\right)$$
   - **Matriz de Teoría de Juegos (cuando hay $\ge 2$ *demes* en la celda)**:
     - **Halcón vs. Halcón** (dos *demes* con $P_{\text{dispute}} \ge 0.25$): ambos sufren una pérdida directa del $15\%$ de población y un sobrecoste energético del $25\%$.
     - **Halcón vs. Paloma** (un *deme* con $P_{\text{dispute}} \ge 0.25$ y otro con $P_{\text{dispute}} < 0.25$): el agresor incrementa su cuota de recursos en $+25\% \cdot (1 + \max(0, V_{\text{eff, social}}(\text{halcón}) - V_{\text{eff, social}}(\text{paloma})))$ a costa de la cuota de la paloma.
     - **Intercambio / Simbiosis** (dos *demes* con $P_{\text{exchange}} \ge 0.20$): ambos reciben un bono de $+20\%$ sobre la energía extraída sin descontarlo de la celda, y si uno posee una Tradición Cultural que el otro no tiene (y el receptor posee `enablesCulturalTransmission`), se transfiere cuando $V_{\text{eff, social}} \ge \text{transmissionThreshold}$.
   - **Tragedia de los Comunes (Degradación de $K$)**:
     Si la extracción total combinada en la celda supera la regeneración natural y el impacto ecológico agregado $\sum_d V_{\text{eff, eco}}(d) < -0.15$:
     $$K_{t+1} = \max\left(10,\; K_t \cdot \left(1 + 0.18 \cdot \sum_d V_{\text{eff, eco}}(d)\right)\right)$$

2. **Coste Metabólico y Balance Demográfico ($r/K$)**:
   - **Gasto Metabólico**:
     $$C_{\text{met}}(d) = \text{population}_d \cdot 0.42 \cdot \left(1 + 0.55 \cdot V_{\text{eff, metabolic}}(d) + 0.20 \cdot |\text{temperature}_{\text{cell}}| \cdot (1 - \max(0, V_{\text{eff, mobility}}(d)))\right)$$
   - **Delta Energético y Crecimiento Poblacional**:
     $$\Delta E(d) = E_{\text{extraída}}(d) - C_{\text{met}}(d)$$
     $$E_{\text{reserves}, t+1}(d) = \max(0,\; E_{\text{reserves}, t}(d) + \Delta E(d))$$
     La tasa de crecimiento neto $g(d) \in [-0.45, +0.35]$ es proporcional a $\frac{\Delta E(d)}{\text{population}_d}$ modulada por la estrategia reproductiva (`bio-r-strategy` amplifica tanto el crecimiento en superávit como la caída en déficit en $\times 1.35$; `bio-k-strategy` amortigua las oscilaciones en $\times 0.75$).

3. **Fisión Migratoria y Colonización (`FR-004`)**:
   - La fracción migrante es $M(d) = \lfloor \text{population}_d \cdot P_{\text{migrate}} \cdot 0.45 \rfloor$.
   - Si $M(d) \ge 10$, se evalúan los 6 hexágonos vecinos buscando aquel que sea **transitable** (`biome !== 'ocean'` y `altitude - 0.50 <= V_eff_mobility(d)`), tenga $< 3$ *demes* (o contenga un *deme* del mismo `lineageId` con divergencia $< 0.10$) y maximice $\frac{\text{currentResources}}{\text{demesCount} + 1}$.
   - Si existe hexágono destino válido:
     - Se descuenta $M(d)$ de `population` del *deme* origen.
     - Se registra un `HexEdgeFlow` de tipo `'migration'` entre origen y destino.
     - Se instancia (o fusiona) el `Deme` en destino heredando `lineageId`, `biologicalTraitIds` y `culturalTraitIds`, transfiriendo su fracción proporcional de `energyReserves` (con un descuento del $15\%$ por desplazamiento) y reiniciando `baldwinCounters = {}`, `innovationCounter = 0` e `isolationTurns = 0`.

4. **Fusión Automática (`< 10%` de Divergencia) y Cuello de Botella Cultural**:
   - Al cierre de la Fase 3, en cada hexágono se evalúan los pares de *demes* con el mismo `lineageId`. La divergencia se mide por distancia de Jaccard sobre la unión de rasgos biológicos y tradiciones culturales:
     $$D(A, B) = 1 - \frac{|T_A \cap T_B|}{|T_A \cup T_B|}$$
     Si $D(A, B) < 0.10$, se fusionan sumando poblaciones y reservas calóricas y promediando ponderadamente sus contadores.
   - Si un *deme* pierde $\ge 50\%$ de su población en el turno o cae a $10 \le \text{population} < 50$ y tiene `culturalTraitIds.length > 0`, pierde la tradición cultural de mayor `transmissionThreshold`.

---

### Fase 4: Umbrales de Hitos Evolutivos y Culturales (`detectEvolutionaryMilestones` — `FR-013`)

1. **Efecto Baldwin (`baldwin_assimilation`)**:
   Si la decisión dominante $i^*$ del *deme* (distinta de `dec-conservative-forage`) tiene $P_{i^*} \ge 0.35$, se incrementa `baldwinCounters[i^*] += 1`. Cuando `baldwinCounters[i^*] >= 8`, se emite un `MilestoneSynthesisInput` de tipo `'baldwin_assimilation'` y se reinicia ese contador a `0`.
2. **Innovación Cultural (`cultural_innovation`)**:
   En cada turno, `innovationCounter = Math.min(2.0, innovationCounter + P_innovate * 0.45)`. Si `innovationCounter >= 1.0` y el *deme* posee al menos un rasgo con `enablesCulturalTransmission === true`, se emite un `MilestoneSynthesisInput` de tipo `'cultural_innovation'` y se resta `1.0` al acumulador.
3. **Especiación Alopátrica (`allopatric_speciation`)**:
   Si un *deme* no ha tenido flujo migratorio ni fusión con ningún otro *deme* de su mismo `lineageId` en el turno (y reside en un hexágono sin otros *demes* de su linaje ni en celdas vecinas), `isolationTurns += 1` (en caso contrario se reinicia a `0`). Si `isolationTurns >= 10` y su divergencia respecto al nodo fundador de su `lineageId` es $\ge 0.30$ (o ha adquirido al menos 1 rasgo biológico nuevo desde su separación), se crea un nuevo `LineageNode` hijo en `lineageTree`, se actualiza el `lineageId` y `color` del *deme*, y se registra en el Cuaderno del Naturalista.

---

## 3. Especificación de los 3 Presets Científicos (`FR-014`, `SC-001`)

1. **`preset-rift-savanna` ("El Rift y la Sabana")**:
   - Radio del mapa: $R = 5$ ($91$ celdas).
   - Geografía: Columna central ($q = 0$) de fallas y *Alta Montaña* (`altitude = 0.88`) con un único paso estrecho en $(0, 0)$. Oeste ($q < 0$): *Selva Tropical* (`humidity = 0.85`, alta regeneración). Este ($q > 0$): *Sabana* y *Estepa Árida* (`humidity = 0.30`, alta variabilidad estacional).
   - Población inicial: 2 *demes* del linaje ancestral `"Homínidos del Rift"` (con `bio-k-strategy` y `bio-social-instinct`), uno en $(-2, 1)$ y otro en $(2, -1)$.
2. **`preset-darwin-archipelago` ("Archipiélago de Darwin")**:
   - Radio del mapa: $R = 5$ ($91$ celdas).
   - Geografía: 4 islas con microclimas distintos (Isla Volcánica Fría al norte, Isla Tropical al sur, Isla Árida al este, Isla Central Templada en $(0,0)$) conectadas por hexágonos de `coastal_shallows` (`altitude = 0.18`) rodeados de `ocean` (`altitude = 0.05`). Ciclo glaciar de nivel del mar activo cada 8 generaciones.
   - Población inicial: 1 *deme* fundador en la Isla Central $(0, 0)$ con alta propensión migratoria inicial durante la fase de puente terrestre abierto (`seaLevel = 0.12`).
3. **`preset-finite-island` ("La Isla Finita")**:
   - Radio del mapa: $R = 4$ ($61$ celdas).
   - Geografía: Isla compacta rodeada de océano. Anillo central de alta fertilidad inicial (`carryingCapacity = 600`, pero `seasonalRegenRate = 0.08` baja).
   - Población inicial: 3 *demes* en el centro con `bio-encephalization`, `cul-extraction-tools` y alta población inicial (`population = 320` cada uno), sin `cul-communal-conservation`, configurados para desencadenar la Tragedia de los Comunes si el jugador no interviene.
