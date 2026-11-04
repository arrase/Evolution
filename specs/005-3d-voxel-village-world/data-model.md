# Phase 1 Data Model: Mundo 3D de Bloques, Aldeas Vivas e Infraestructuras Visuales de Interacción

**Feature**: `005-3d-voxel-village-world`  
**Date**: 2026-11-04

## 1. Core Simulation Entities Preserved (`src/types/simulation.ts`)

`WorldState`, `HexCell`, `Deme`, `HexEdgeFlow`, `TraitDefinition`, `DecisionDefinition`, `LineageNode`, and `ChronicleEntry` remain backward-compatible with all existing saved/exported JSON worlds and test suites. Each `Deme` is projected into the 3D world as a `VillageSettlement3D`.

---

## 2. 3D Camera & Projection Model (`src/engine/world3d.ts`)

### `Camera3DState`

Represents the orbital 3D camera state controlled by the user:

```ts
export interface Camera3DState {
  yawDeg: number;    // Normalized in [0, 360), default 0 (North-up)
  pitchDeg: number;  // Clamped in [25, 80], default 48 (classic 90s/2000s diorama angle)
  zoom: number;      // Clamped in [0.85, 3.25], default 1.0
  panX: number;      // Screen-space horizontal offset in px, default 0
  panY: number;      // Screen-space vertical offset in px, default 0
}
```

### `Point3D` & `ProjectedPoint3D`

```ts
export interface Point3D {
  x: number;
  y: number;
  z: number; // Vertical height in world px (0 = sea floor base, max = MAX_COLUMN_HEIGHT_PX <= 0.85 * HEX_SIZE)
}

export interface ProjectedPoint3D {
  screenX: number;
  screenY: number;
  depthZ: number; // Camera-space depth used for back-to-front painter's sorting
}
```

### `VoxelBox3D`

Fundamental 3D flat-shaded block primitive used to construct biome trees, rocks, village huts, halls, granaries, totems, palisades, bridge pillars, and caravans:

```ts
export interface VoxelBox3D {
  id: string;
  centerX: number;
  centerY: number;
  baseZ: number;
  widthX: number;
  depthY: number;
  heightZ: number;
  yawOffsetRad?: number;
  topColor: string;
  leftColor: string;
  rightColor: string;
  strokeColor?: string;
}
```

---

## 3. 3D Territory Model (`VoxelHexTerritory3D`)

Represents the 3D stepped block column and ecological state of a `HexCell`:

```ts
export type ResourceAbundanceTier = "high" | "medium" | "low";
export type EcologicalHealthState = "healthy" | "degraded" | "collapsed";

export interface VoxelHexTerritory3D {
  cell: HexCell;
  baseCenterX: number;
  baseCenterY: number;
  altitudeTier: number;               // Integer in [1..10] for terrestrial cells, 0 for deep ocean
  topZ: number;                       // Physical height of the hex top plateau in [0, 0.85 * HEX_SIZE]
  waterZ: number;                     // Physical height of the 3D sea plane (seaLevel * MAX_COLUMN_HEIGHT_PX)
  isSubmerged: boolean;               // cell.biome === "ocean" || cell.altitude < seaLevel
  isCoastalOrInundated: boolean;      // cell.biome === "coastal_shallows" || cell.altitude <= seaLevel + 0.04
  resourceTier: ResourceAbundanceTier;// high (>= 0.65), medium (0.30-0.64), low (< 0.30) of R / Kmax
  healthState: EcologicalHealthState; // healthy (>= 0.85), degraded (0.60-0.84), collapsed (< 0.60) of K / Kmax
  depthKey: number;                   // Camera-space depth of the column center for back-to-front sorting
  biomeProps: VoxelBox3D[];           // 3D trees, boulders, dunes, snow caps outside cleared village/road footprints
}
```

**Derivation & Validation Rules (`FR-001`, `FR-002`, `FR-003`)**:
- `MAX_COLUMN_HEIGHT_PX = Math.floor(HEX_SIZE * 0.85)` ($32\text{ px}$ when `HEX_SIZE = 38`), ensuring $H_{\max} \le 0.85 \cdot R_{\text{hex}}$.
- `altitudeTier`: For `cell.biome === "ocean"`, `0`; otherwise `Math.max(1, Math.min(10, Math.ceil(cell.altitude * 10)))`.
- `topZ`: `(altitudeTier / 10) * MAX_COLUMN_HEIGHT_PX`.
- `resourceRatio = cell.currentResources / cell.carryingCapacityMax`:
  - `>= 0.65` $\rightarrow$ `"high"`
  - `0.30 .. 0.64` $\rightarrow$ `"medium"`
  - `< 0.30` $\rightarrow$ `"low"`
- `healthRatio = cell.carryingCapacity / cell.carryingCapacityMax`:
  - `>= 0.85` $\rightarrow$ `"healthy"`
  - `0.60 .. 0.84` $\rightarrow$ `"degraded"`
  - `< 0.60` $\rightarrow$ `"collapsed"`

---

## 4. 3D Village Settlement Model (`VillageSettlement3D`)

Represents each active `Deme` as a collective 3D settlement on its territory plateau:

```ts
export type VillageTier = "camp" | "hamlet" | "village" | "settlement";

export interface VillageSettlement3D {
  deme: Deme;
  hexId: string;
  tier: VillageTier;                  // camp (10-49), hamlet (50-149), village (150-399), settlement (400+)
  tierLevel: 1 | 2 | 3 | 4;
  tierRoman: "I" | "II" | "III" | "IV";
  vitalStatus: DemeVitalStatus;       // thriving | stable | struggling | starving
  dominantArchetype: DecisionArchetype;// forage | overexploit | migrate | cooperate | exchange | dispute | innovate | custom
  hasCulture: boolean;                // deme.culturalTraitIds.length > 0
  culturalLevel: number;              // deme.culturalTraitIds.length
  isHighlightedLineage: boolean;      // highlightedLineageId === null || deme.lineageId === highlightedLineageId
  isDimmedByLineageFilter: boolean;   // highlightedLineageId !== null && deme.lineageId !== highlightedLineageId
  worldX: number;                     // 3D sector center X on the hex plateau
  worldY: number;                     // 3D sector center Y on the hex plateau
  baseZ: number;                      // Equal to parent territory topZ
  footprintRadius: number;            // Cleared radius on the plateau (compacted when 2 or 3 villages cohabit)
  buildings: VoxelBox3D[];            // Dwellings, central hall, totem monolith, and dominant decision activity blocks
  billboardAnchor: ProjectedPoint3D;  // Projected roof anchor for the occlusion-safe floating badge
  isOccludedByFrontTerrain: boolean;  // True when a front territory column with higher topZ overlaps the village
}
```

**Derivation Rules (`FR-004`, `FR-005`, `FR-006`)**:
- `getVillageTier(population: number)`:
  - `10 <= population <= 49` $\rightarrow$ `{ tier: "camp", tierLevel: 1, tierRoman: "I" }`
  - `50 <= population <= 149` $\rightarrow$ `{ tier: "hamlet", tierLevel: 2, tierRoman: "II" }`
  - `150 <= population <= 399` $\rightarrow$ `{ tier: "village", tierLevel: 3, tierRoman: "III" }`
  - `population >= 400` $\rightarrow$ `{ tier: "settlement", tierLevel: 4, tierRoman: "IV" }`
- **Cohabitation Sector Assignment (`cohabitingCount` $\in \{1, 2, 3\}$)**:
  - `1` village: Centered at `(baseCenterX, baseCenterY)` with `footprintRadius = HEX_SIZE * 0.44`.
  - `2` villages: Positioned at symmetric opposite sectors with `footprintRadius = HEX_SIZE * 0.30`.
  - `3` villages: Positioned at $120^\circ$ triangular sectors with `footprintRadius = HEX_SIZE * 0.25`; Tier 3 and Tier 4 buildings increase vertical block height (`+25%`) to preserve architectural distinction within the compact sector.

---

## 5. 3D Inter-Village Infrastructure & Lifecycle Transition Models

### `InterVillageStructure3D`

Represents a 3D physical connection or frontier between two villages (`sourceDemeId` and `targetDemeId`):

```ts
export type InterVillageStructureKind =
  | "road"
  | "ramp"
  | "bridge"
  | "dispute_front"
  | "expedition"
  | "merge_integration";

export type InfrastructureLifecycleStatus = "active" | "disused";

export interface InterVillageStructure3D {
  id: string;
  kind: InterVillageStructureKind;
  status: InfrastructureLifecycleStatus;
  fromHexId: string;
  toHexId: string;
  sourceDemeId: string;
  targetDemeId: string;
  startPoint: Point3D;
  endPoint: Point3D;
  color: string;
  altitudeDelta: number;
  crossesWaterOrShallows: boolean;
  blocks: VoxelBox3D[]; // Deck slabs, ramp steps, bridge pillars, palisades/barricades, or caravan/settler blocks
}
```

### `ExtinctionRuins3D`

Represents the 1-generation collapsed block ruins left when a village suffers a true extinction (`chronicle` entry with `type === "extinction"`):

```ts
export interface ExtinctionRuins3D {
  id: string;
  demeId: string;
  demeName: string;
  lineageColor: string;
  hexId: string;
  worldX: number;
  worldY: number;
  baseZ: number;
  ruinBlocks: VoxelBox3D[];
}
```

**Deterministic Classification Rules (`FR-007`, `FR-008`, `Edge Cases`)**:
1. **Precedence**: For any pair of villages `(A, B)`, if a `dispute` flow exists between `A` and `B` in `currentTurnFlows`, emit `kind: "dispute_front"` (`status: "active"`) and suppress any `road`, `ramp`, or `bridge` between `(A, B)`.
2. **Commercial & Collaborative Connection (`road` | `ramp` | `bridge`)**:
   - Emitted when `(A, B)` has an `exchange` flow in `currentTurnFlows` OR when `A` and `B` cohabit or occupy adjacent passable territories and both have cooperation probability `getArchetypeProb(deme, "cooperate") >= 0.25` (or dominant archetype `"cooperate"`).
   - Given `altitudeDelta = Math.abs(cellA.altitude - cellB.altitude)` and `crossesWaterOrShallows = isCoastalOrInundated(cellA) || isCoastalOrInundated(cellB)`:
     - If `crossesWaterOrShallows || altitudeDelta >= 0.25` $\rightarrow$ `kind: "bridge"` (elevated deck + vertical support pillars).
     - Else if `fromHexId !== toHexId && altitudeDelta >= 0.10` $\rightarrow$ `kind: "ramp"` (stepped block ramp).
     - Else $\rightarrow$ `kind: "road"` (flat block road).
3. **1-Turn Disused Memory**:
   - If pair `(A, B)` had an `active` `road`, `ramp`, or `bridge` in generation $t - 1$, both `A` and `B` remain alive on non-submerged territories in generation $t$, and neither an active trade/collaboration nor a `dispute_front` exists between them in generation $t$, emit the structure with `status: "disused"` for generation $t$ only.
4. **Sibling Merge vs. True Extinction**:
   - If deme `B` in hex $H$ existed in generation $t - 1$ and is absent in generation $t$:
     - If a same-lineage deme `A` in hex $H$ survived and no `extinction` chronicle entry was logged for `B` in generation $t$, emit a `merge_integration` trail from `B`'s previous sector to `A`'s sector (zero ruins).
     - If `world.chronicle` contains an entry with `type === "extinction"`, `generation === world.generation`, and `demeId === B.id`, emit `ExtinctionRuins3D` on `B`'s sector for generation $t$.
