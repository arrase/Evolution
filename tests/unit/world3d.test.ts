import { describe, expect, it } from "vitest";
import { getPresetById } from "../../src/catalog/presets";
import { HEX_SIZE } from "../../src/engine/hexGrid";
import {
  buildTerritoryBiomeVoxels,
  buildVillageSettlementVoxels,
  buildWorld3DScene,
  classifyConnectionKind,
  classifyTerritoryEcology,
  clampCamera3D,
  computeVillageSectorLayout,
  DEFAULT_CAMERA_3D,
  getVillageTier,
  MAX_COLUMN_HEIGHT_PX,
  projectPoint3D,
  projectVoxelBoxFaces
} from "../../src/engine/world3d";
import {
  DecisionArchetypeSchema,
  type Deme,
  type HexCell,
  type WorldState
} from "../../src/types/simulation";

function makeTestCell(overrides: Partial<HexCell>): HexCell {
  return {
    id: "0,0",
    q: 0,
    r: 0,
    biome: "savanna",
    temperature: 0.4,
    humidity: 0.5,
    altitude: 0.35,
    currentResources: 350,
    carryingCapacity: 480,
    carryingCapacityMax: 500,
    seasonalRegenRate: 0.15,
    demeIds: [],
    ...overrides
  };
}

function makeTestDeme(overrides: Partial<Deme>): Deme {
  return {
    id: "deme-alpha",
    name: "Alpha Clan",
    lineageId: "lin-1",
    color: "#10b981",
    hexId: "0,0",
    population: 120,
    energyReserves: 140,
    lastEnergyDelta: 12,
    biologicalTraitIds: ["bio-encephalization"],
    culturalTraitIds: [],
    baldwinCounters: {},
    innovationCounter: 0.2,
    isolationTurns: 0,
    lastDecisionProbabilities: {
      "dec-conservative-forage": 1.0
    },
    lastDominantDecisionId: "dec-conservative-forage",
    lastJustification: "Stable local foraging.",
    ...overrides
  };
}

describe("3D Voxel World Engine (US1, US2, US3, SC-001..SC-004)", () => {
  describe("US1: 3D Camera Projection, Stepped Altitude Tiers & Ecological States", () => {
    it("clamps camera yaw into [0, 360), pitch into [25, 80], and zoom into [0.85, 3.25]", () => {
      const clamped = clampCamera3D({
        yawDeg: -45,
        pitchDeg: 10,
        zoom: 5.0,
        panX: 12,
        panY: -8
      });
      expect(clamped.yawDeg).toBe(315);
      expect(clamped.pitchDeg).toBe(25);
      expect(clamped.zoom).toBe(3.25);
      expect(clamped.panX).toBe(12);
      expect(clamped.panY).toBe(-8);

      const highPitch = clampCamera3D({ yawDeg: 720, pitchDeg: 95, zoom: 0.2 });
      expect(highPitch.yawDeg).toBe(0);
      expect(highPitch.pitchDeg).toBe(80);
      expect(highPitch.zoom).toBe(0.85);
    });

    it("projects 3D points and voxel box faces deterministically across seasons", () => {
      const low = projectPoint3D({ x: 10, y: 20, z: 0 }, DEFAULT_CAMERA_3D, { x: 0, y: 0 });
      const high = projectPoint3D({ x: 10, y: 20, z: 24 }, DEFAULT_CAMERA_3D, { x: 0, y: 0 });
      expect(high.screenY).toBeLessThan(low.screenY);
      expect(high.depthZ).toBeGreaterThan(low.depthZ);

      const box = {
        id: "test-box",
        centerX: 0,
        centerY: 0,
        baseZ: 0,
        widthX: 6,
        depthY: 6,
        heightZ: 8,
        topColor: "#10b981",
        leftColor: "#059669",
        rightColor: "#047857"
      };
      const wetFaces = projectVoxelBoxFaces(box, DEFAULT_CAMERA_3D, "wet_warm");
      const dryFaces = projectVoxelBoxFaces(box, DEFAULT_CAMERA_3D, "dry_cold");
      expect(wetFaces.topFill).not.toBe(dryFaces.topFill);
      expect(wetFaces.sideFaces.length).toBeGreaterThanOrEqual(1);
    });

    it("quantizes altitude into 0..10 tiers bounded by <= 0.85 * HEX_SIZE and classifies resource/health tiers", () => {
      expect(MAX_COLUMN_HEIGHT_PX).toBeLessThanOrEqual(HEX_SIZE * 0.85);

      const oceanEcology = classifyTerritoryEcology(
        makeTestCell({ biome: "ocean", altitude: 0.04 }),
        0.15
      );
      expect(oceanEcology.altitudeTier).toBe(0);
      expect(oceanEcology.topZ).toBe(0);
      expect(oceanEcology.isSubmerged).toBe(true);

      const highHealthy = classifyTerritoryEcology(
        makeTestCell({
          altitude: 0.95,
          currentResources: 400,
          carryingCapacity: 460,
          carryingCapacityMax: 500
        }),
        0.15
      );
      expect(highHealthy.altitudeTier).toBe(10);
      expect(highHealthy.topZ).toBeLessThanOrEqual(HEX_SIZE * 0.85);
      expect(highHealthy.resourceTier).toBe("high");
      expect(highHealthy.healthState).toBe("healthy");

      const mediumDegraded = classifyTerritoryEcology(
        makeTestCell({
          altitude: 0.42,
          currentResources: 225,
          carryingCapacity: 350,
          carryingCapacityMax: 500
        }),
        0.15
      );
      expect(mediumDegraded.altitudeTier).toBe(5);
      expect(mediumDegraded.resourceTier).toBe("medium");
      expect(mediumDegraded.healthState).toBe("degraded");

      const lowCollapsed = classifyTerritoryEcology(
        makeTestCell({
          altitude: 0.12,
          currentResources: 100,
          carryingCapacity: 250,
          carryingCapacityMax: 500
        }),
        0.10
      );
      expect(lowCollapsed.altitudeTier).toBe(2);
      expect(lowCollapsed.resourceTier).toBe("low");
      expect(lowCollapsed.healthState).toBe("collapsed");
    });

    it("sorts territories in back-to-front depth order across all 4 cardinal yaw angles (0, 90, 180, 270)", () => {
      const world = getPresetById("preset-rift-savanna").createInitialWorld();
      for (const yawDeg of [0, 90, 180, 270]) {
        const scene = buildWorld3DScene(world, { ...DEFAULT_CAMERA_3D, yawDeg });
        for (let i = 1; i < scene.territories.length; i += 1) {
          expect(scene.territories[i]!.depthKey).toBeGreaterThanOrEqual(
            scene.territories[i - 1]!.depthKey
          );
        }
      }

      const sceneNorth = buildWorld3DScene(world, { ...DEFAULT_CAMERA_3D, yawDeg: 0 });
      const sceneSouth = buildWorld3DScene(world, { ...DEFAULT_CAMERA_3D, yawDeg: 180 });
      expect(sceneNorth.territories[0]!.cell.id).not.toBe(sceneSouth.territories[0]!.cell.id);
    });
  });

  describe("US2: 3D Village Tiers, Cohabitation Compaction, Footprint Clearing & Lifecycle Transitions", () => {
    it("maps population deterministically across all 4 settlement tiers (I-IV)", () => {
      expect(getVillageTier(10)).toEqual({ tier: "camp", tierLevel: 1, tierRoman: "I" });
      expect(getVillageTier(49)).toEqual({ tier: "camp", tierLevel: 1, tierRoman: "I" });
      expect(getVillageTier(50)).toEqual({ tier: "hamlet", tierLevel: 2, tierRoman: "II" });
      expect(getVillageTier(149)).toEqual({ tier: "hamlet", tierLevel: 2, tierRoman: "II" });
      expect(getVillageTier(150)).toEqual({ tier: "village", tierLevel: 3, tierRoman: "III" });
      expect(getVillageTier(399)).toEqual({ tier: "village", tierLevel: 3, tierRoman: "III" });
      expect(getVillageTier(400)).toEqual({ tier: "settlement", tierLevel: 4, tierRoman: "IV" });
    });

    it("assigns non-overlapping cohabitation sectors for 1, 2, and 3 villages and scales Tier 3/4 height by +25% on 3-village cohabitation", () => {
      const d1 = makeTestDeme({ id: "d1", population: 30 });
      const d2 = makeTestDeme({ id: "d2", population: 180 });
      const d3 = makeTestDeme({ id: "d3", population: 450 });

      const single = computeVillageSectorLayout({ x: 0, y: 0 }, 16, [d1]);
      expect(single).toHaveLength(1);
      expect(single[0]!.worldX).toBe(0);
      expect(single[0]!.worldY).toBe(0);

      const pair = computeVillageSectorLayout({ x: 0, y: 0 }, 16, [d1, d2]);
      expect(pair).toHaveLength(2);
      const pairDist = Math.hypot(
        pair[0]!.worldX - pair[1]!.worldX,
        pair[0]!.worldY - pair[1]!.worldY
      );
      expect(pairDist).toBeGreaterThan(pair[0]!.footprintRadius + pair[1]!.footprintRadius);

      const triple = computeVillageSectorLayout({ x: 0, y: 0 }, 16, [d1, d2, d3]);
      expect(triple).toHaveLength(3);
      for (let i = 0; i < 3; i += 1) {
        for (let j = i + 1; j < 3; j += 1) {
          const dist = Math.hypot(
            triple[i]!.worldX - triple[j]!.worldX,
            triple[i]!.worldY - triple[j]!.worldY
          );
          expect(dist).toBeGreaterThan(triple[i]!.footprintRadius + triple[j]!.footprintRadius);
        }
      }
      expect(triple[0]!.heightScale).toBe(1.0);
      expect(triple[1]!.heightScale).toBe(1.25);
      expect(triple[2]!.heightScale).toBe(1.25);
    });

    it("clears biome vegetation props inside occupied village footprints and road corridors", () => {
      const cell = makeTestCell({ biome: "tropical_forest", currentResources: 480 });
      const uncleared = buildTerritoryBiomeVoxels(
        {
          cell,
          baseCenterX: 0,
          baseCenterY: 0,
          topZ: 12,
          waterZ: 4,
          resourceTier: "high",
          healthState: "healthy"
        },
        [],
        []
      );
      expect(uncleared.length).toBeGreaterThan(0);

      const fullyCleared = buildTerritoryBiomeVoxels(
        {
          cell,
          baseCenterX: 0,
          baseCenterY: 0,
          topZ: 12,
          waterZ: 4,
          resourceTier: "high",
          healthState: "healthy"
        },
        [{ x: 0, y: 0, radius: 30 }],
        []
      );
      expect(fullyCleared).toHaveLength(0);
    });

    it("generates local activity voxel blocks for all 8 DecisionArchetype values and erects a Cultural Totem when cultural traits exist", () => {
      const demeWithCulture = makeTestDeme({
        id: "deme-cultured",
        population: 220,
        culturalTraitIds: ["cul-fire-processing", "cul-extraction-tools"]
      });
      const placement = computeVillageSectorLayout({ x: 0, y: 0 }, 14, [demeWithCulture])[0]!;

      for (const archetype of DecisionArchetypeSchema.options) {
        const blocks = buildVillageSettlementVoxels(placement, "thriving", archetype);
        const activityBlocks = blocks.filter((b) =>
          b.id.startsWith(`deme-cultured-activity-${archetype}`)
        );
        expect(activityBlocks.length).toBeGreaterThanOrEqual(2);
        const totemBlock = blocks.find((b) => b.id === "deme-cultured-cultural-totem");
        expect(totemBlock).toBeDefined();
      }
    });

    it("distinguishes sibling merge integration trails from true extinction ruins across consecutive turns", () => {
      const prevWorld = getPresetById("preset-rift-savanna").createInitialWorld();
      const firstDeme = Object.values(prevWorld.demes)[0]!;
      const siblingDeme = makeTestDeme({
        id: "deme-sibling",
        name: "Sibling Clan",
        lineageId: firstDeme.lineageId,
        hexId: firstDeme.hexId,
        population: 45
      });
      const doomedDeme = makeTestDeme({
        id: "deme-doomed",
        name: "Doomed Clan",
        lineageId: firstDeme.lineageId,
        hexId: "0,0",
        population: 15
      });

      prevWorld.demes[siblingDeme.id] = siblingDeme;
      prevWorld.cells[firstDeme.hexId]!.demeIds.push(siblingDeme.id);
      prevWorld.demes[doomedDeme.id] = doomedDeme;
      prevWorld.cells["0,0"]!.demeIds.push(doomedDeme.id);

      const nextWorld: WorldState = structuredClone(prevWorld);
      nextWorld.generation = prevWorld.generation + 1;
      delete nextWorld.demes[siblingDeme.id];
      nextWorld.cells[firstDeme.hexId]!.demeIds = nextWorld.cells[
        firstDeme.hexId
      ]!.demeIds.filter((id) => id !== siblingDeme.id);

      delete nextWorld.demes[doomedDeme.id];
      nextWorld.cells["0,0"]!.demeIds = nextWorld.cells["0,0"]!.demeIds.filter(
        (id) => id !== doomedDeme.id
      );
      nextWorld.chronicle.push({
        id: "ext-doomed",
        generation: nextWorld.generation,
        type: "extinction",
        title: "Doomed Clan Extinct",
        body: "Doomed Clan collapsed.",
        demeId: doomedDeme.id,
        lineageId: doomedDeme.lineageId,
        hexId: "0,0"
      });

      const scene = buildWorld3DScene(nextWorld, DEFAULT_CAMERA_3D, {
        previousWorld: prevWorld,
        highlightedLineageId: null
      });

      expect(scene.ruins.some((r) => r.demeId === doomedDeme.id)).toBe(true);
      expect(scene.ruins.some((r) => r.demeId === siblingDeme.id)).toBe(false);
      expect(
        scene.structures.some(
          (s) => s.kind === "merge_integration" && s.sourceDemeId === siblingDeme.id
        )
      ).toBe(true);
    });
  });

  describe("US3: Deterministic 3D Roads, Stepped Ramps, Pillar Bridges, Dispute Precedence & 1-Turn Disused Memory", () => {
    it("classifies connection kind into road, ramp, or bridge according to exact altitude and coastal rules", () => {
      const flatA = makeTestCell({ id: "0,0", biome: "savanna", altitude: 0.32 });
      const flatB = makeTestCell({ id: "1,0", biome: "savanna", altitude: 0.38 });
      expect(classifyConnectionKind(flatA, flatB, 0.15)).toBe("road");

      const rampB = makeTestCell({ id: "1,0", biome: "arid_steppe", altitude: 0.48 });
      expect(classifyConnectionKind(flatA, rampB, 0.15)).toBe("ramp");

      const cliffB = makeTestCell({ id: "1,0", biome: "high_mountain", altitude: 0.72 });
      expect(classifyConnectionKind(flatA, cliffB, 0.15)).toBe("bridge");

      const shallowB = makeTestCell({ id: "1,0", biome: "coastal_shallows", altitude: 0.22 });
      expect(classifyConnectionKind(flatA, shallowB, 0.15)).toBe("bridge");

      const inundatedB = makeTestCell({ id: "1,0", biome: "savanna", altitude: 0.18 });
      expect(classifyConnectionKind(flatA, inundatedB, 0.15)).toBe("bridge");
    });

    it("builds cooperation roads, enforces dispute_front precedence over trade roads, and decays ceased routes to 'disused' for 1 turn", () => {
      const worldA = getPresetById("preset-rift-savanna").createInitialWorld();
      const demes = Object.values(worldA.demes);
      const demeA = demes[0]!;
      const demeB = demes[1]!;

      demeA.hexId = "0,0";
      demeB.hexId = "1,0";
      worldA.cells["0,0"]!.biome = "savanna";
      worldA.cells["0,0"]!.altitude = 0.35;
      worldA.cells["0,0"]!.demeIds = [demeA.id];
      worldA.cells["1,0"]!.biome = "savanna";
      worldA.cells["1,0"]!.altitude = 0.38;
      worldA.cells["1,0"]!.demeIds = [demeB.id];

      demeA.lastDecisionProbabilities = { "dec-cooperate-store": 0.6, "dec-conservative-forage": 0.4 };
      demeB.lastDecisionProbabilities = { "dec-cooperate-store": 0.5, "dec-conservative-forage": 0.5 };
      worldA.currentTurnFlows = [];

      const coopScene = buildWorld3DScene(worldA, DEFAULT_CAMERA_3D);
      expect(
        coopScene.structures.some(
          (s) => s.kind === "road" && s.status === "active"
        )
      ).toBe(true);

      const disputeWorld: WorldState = structuredClone(worldA);
      disputeWorld.currentTurnFlows = [
        {
          fromHexId: "0,0",
          toHexId: "1,0",
          demeId: demeA.id,
          targetDemeId: demeB.id,
          color: demeA.color,
          type: "exchange",
          intensity: 0.5
        },
        {
          fromHexId: "0,0",
          toHexId: "1,0",
          demeId: demeA.id,
          targetDemeId: demeB.id,
          color: demeA.color,
          type: "dispute",
          intensity: 0.8
        }
      ];

      const disputeScene = buildWorld3DScene(disputeWorld, DEFAULT_CAMERA_3D);
      expect(disputeScene.structures.some((s) => s.kind === "dispute_front")).toBe(true);
      expect(disputeScene.structures.some((s) => s.kind === "road")).toBe(false);

      const ceasedWorld: WorldState = structuredClone(worldA);
      ceasedWorld.generation = worldA.generation + 1;
      ceasedWorld.demes[demeA.id]!.lastDecisionProbabilities = { "dec-conservative-forage": 1.0 };
      ceasedWorld.demes[demeB.id]!.lastDecisionProbabilities = { "dec-conservative-forage": 1.0 };
      ceasedWorld.currentTurnFlows = [];

      const disusedScene = buildWorld3DScene(ceasedWorld, DEFAULT_CAMERA_3D, {
        previousWorld: worldA,
        highlightedLineageId: null
      });
      expect(
        disusedScene.structures.some((s) => s.kind === "road" && s.status === "disused")
      ).toBe(true);
    });
  });

  describe("SC-004: 3D Scene Construction Performance Benchmark", () => {
    it("constructs and depth-sorts the complete 3D voxel scene in under 100 ms", () => {
      const world = getPresetById("preset-darwin-archipelago").createInitialWorld();
      const startMs = performance.now();
      const scene = buildWorld3DScene(world, DEFAULT_CAMERA_3D);
      const elapsedMs = performance.now() - startMs;

      expect(scene.territories.length).toBeGreaterThanOrEqual(61);
      expect(elapsedMs).toBeLessThan(100);
    });
  });
});
