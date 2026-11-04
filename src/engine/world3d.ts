import {
  DECISION_ARCHETYPE_VISUALS,
  DEME_STATUS_RINGS,
  type DemeVitalStatus,
  getDemeStatus,
  INFRASTRUCTURE_3D_STYLES,
  shadeColorHex,
  VILLAGE_TIER_VISUALS,
  type VillageTierKey
} from "../components/palette";
import type {
  BiomeType,
  DecisionArchetype,
  DecisionDefinition,
  Deme,
  HexCell,
  SeasonType,
  WorldState
} from "../types/simulation";
import { computeHexPixelGeometry, getExistingNeighborCells, HEX_SIZE } from "./hexGrid";

export const MAX_COLUMN_HEIGHT_PX = Math.floor(HEX_SIZE * 0.85);
export const MIN_PITCH_DEG = 25;
export const MAX_PITCH_DEG = 80;
export const MIN_ZOOM_3D = 0.85;
export const MAX_ZOOM_3D = 3.25;

export interface Camera3DState {
  yawDeg: number;
  pitchDeg: number;
  zoom: number;
  panX: number;
  panY: number;
}

export const DEFAULT_CAMERA_3D: Camera3DState = {
  yawDeg: 0,
  pitchDeg: 48,
  zoom: 1.0,
  panX: 0,
  panY: 0
};

export interface Point3D {
  x: number;
  y: number;
  z: number;
}

export interface ProjectedPoint3D {
  screenX: number;
  screenY: number;
  depthZ: number;
}

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
  isAnimatedCaravan?: boolean;
}

export interface ProjectedPolygonFace3D {
  points: string;
  fill: string;
  stroke: string;
  depthZ: number;
}

export interface ProjectedVoxelBox3D {
  id: string;
  depthZ: number;
  topPolygonPoints: string;
  topFill: string;
  sideFaces: ProjectedPolygonFace3D[];
  strokeColor: string;
  isAnimatedCaravan: boolean;
}

export type ResourceAbundanceTier = "high" | "medium" | "low";
export type EcologicalHealthState = "healthy" | "degraded" | "collapsed";

export interface HexSideFace3D {
  edgeIndex: number;
  points: string;
  shadeFactor: number;
  strataLines: Array<{ x1: number; y1: number; x2: number; y2: number }>;
}

export interface VoxelHexTerritory3D {
  cell: HexCell;
  baseCenterX: number;
  baseCenterY: number;
  altitudeTier: number;
  topZ: number;
  waterZ: number;
  isSubmerged: boolean;
  isCoastalOrInundated: boolean;
  resourceTier: ResourceAbundanceTier;
  healthState: EcologicalHealthState;
  depthKey: number;
  topPolygonPoints: string;
  basePolygonPoints: string;
  waterTopPolygonPoints: string;
  waterSideFaces: HexSideFace3D[];
  sideFaces: HexSideFace3D[];
  topCorners: ProjectedPoint3D[];
  projectedCenter: ProjectedPoint3D;
  biomeProps: VoxelBox3D[];
}

export type VillageTier = VillageTierKey;

export interface VillageSettlement3D {
  deme: Deme;
  hexId: string;
  tier: VillageTier;
  tierLevel: 1 | 2 | 3 | 4;
  tierRoman: "I" | "II" | "III" | "IV";
  vitalStatus: DemeVitalStatus;
  dominantArchetype: DecisionArchetype;
  hasCulture: boolean;
  culturalLevel: number;
  isHighlightedLineage: boolean;
  isDimmedByLineageFilter: boolean;
  worldX: number;
  worldY: number;
  baseZ: number;
  footprintRadius: number;
  buildings: VoxelBox3D[];
  roofAnchor: ProjectedPoint3D;
  billboardAnchor: ProjectedPoint3D;
  isOccludedByFrontTerrain: boolean;
}

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
  blocks: VoxelBox3D[];
}

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

export interface World3DScene {
  origin: { x: number; y: number };
  camera: Camera3DState;
  territories: VoxelHexTerritory3D[];
  territoriesByHexId: Record<string, VoxelHexTerritory3D>;
  villages: VillageSettlement3D[];
  villagesByDemeId: Record<string, VillageSettlement3D>;
  structures: InterVillageStructure3D[];
  ruins: ExtinctionRuins3D[];
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function normalizeYawDeg(yawDeg: number): number {
  const mod = ((yawDeg % 360) + 360) % 360;
  return mod === 360 ? 0 : Number(mod.toFixed(2));
}

export function clampCamera3D(camera: Partial<Camera3DState>): Camera3DState {
  const yawDeg = camera.yawDeg !== undefined ? normalizeYawDeg(camera.yawDeg) : DEFAULT_CAMERA_3D.yawDeg;
  const pitchDeg =
    camera.pitchDeg !== undefined
      ? Number(clamp(camera.pitchDeg, MIN_PITCH_DEG, MAX_PITCH_DEG).toFixed(2))
      : DEFAULT_CAMERA_3D.pitchDeg;
  const zoom =
    camera.zoom !== undefined
      ? Number(clamp(camera.zoom, MIN_ZOOM_3D, MAX_ZOOM_3D).toFixed(2))
      : DEFAULT_CAMERA_3D.zoom;
  const panX = camera.panX !== undefined ? Number(camera.panX.toFixed(2)) : DEFAULT_CAMERA_3D.panX;
  const panY = camera.panY !== undefined ? Number(camera.panY.toFixed(2)) : DEFAULT_CAMERA_3D.panY;

  return {
    yawDeg,
    pitchDeg,
    zoom,
    panX,
    panY
  };
}

function rotateWorldXY(
  x: number,
  y: number,
  originX: number,
  originY: number,
  yawDeg: number
): { rotX: number; rotY: number } {
  const dx = x - originX;
  const dy = y - originY;
  const yawRad = (yawDeg * Math.PI) / 180;
  const cosYaw = Math.cos(yawRad);
  const sinYaw = Math.sin(yawRad);
  return {
    rotX: dx * cosYaw - dy * sinYaw,
    rotY: dx * sinYaw + dy * cosYaw
  };
}

export function projectPoint3D(
  point: Point3D,
  camera: Camera3DState,
  origin?: { x: number; y: number }
): ProjectedPoint3D {
  const ox = origin !== undefined ? origin.x : 0;
  const oy = origin !== undefined ? origin.y : 0;
  const { rotX, rotY } = rotateWorldXY(point.x, point.y, ox, oy, camera.yawDeg);
  const pitchRad = (camera.pitchDeg * Math.PI) / 180;
  const groundScaleY = Math.sin(pitchRad);
  const verticalScaleZ = Math.cos(pitchRad) * 1.18;

  const screenX = ox + rotX * camera.zoom + camera.panX;
  const screenY = oy + (rotY * groundScaleY - point.z * verticalScaleZ) * camera.zoom + camera.panY;
  const depthZ = rotY + point.z * 0.02;

  return {
    screenX: Number(screenX.toFixed(2)),
    screenY: Number(screenY.toFixed(2)),
    depthZ: Number(depthZ.toFixed(3))
  };
}

export function projectVoxelBoxFaces(
  box: VoxelBox3D,
  camera: Camera3DState,
  season: SeasonType,
  origin?: { x: number; y: number }
): ProjectedVoxelBox3D {
  const ox = origin !== undefined ? origin.x : 0;
  const oy = origin !== undefined ? origin.y : 0;
  const hx = box.widthX / 2;
  const hy = box.depthY / 2;
  const localYaw = box.yawOffsetRad !== undefined ? box.yawOffsetRad : Math.PI / 6;
  const cosLocal = Math.cos(localYaw);
  const sinLocal = Math.sin(localYaw);

  const rawOffsets: Array<[number, number]> = [
    [-hx, -hy],
    [hx, -hy],
    [hx, hy],
    [-hx, hy]
  ];

  const worldCornersXY = rawOffsets.map(([lx, ly]) => ({
    x: box.centerX + lx * cosLocal - ly * sinLocal,
    y: box.centerY + lx * sinLocal + ly * cosLocal
  }));

  const z0 = box.baseZ;
  const z1 = box.baseZ + box.heightZ;

  const bottomCorners = worldCornersXY.map((c) =>
    projectPoint3D({ x: c.x, y: c.y, z: z0 }, camera, { x: ox, y: oy })
  );
  const topCorners = worldCornersXY.map((c) =>
    projectPoint3D({ x: c.x, y: c.y, z: z1 }, camera, { x: ox, y: oy })
  );

  const centerRot = rotateWorldXY(box.centerX, box.centerY, ox, oy, camera.yawDeg);
  const warmSeason = season === "wet_warm";
  const topFill = shadeColorHex(box.topColor, warmSeason ? 1.06 : 0.96);
  const leftFill = shadeColorHex(box.leftColor, warmSeason ? 1.02 : 0.91);
  const rightFill = shadeColorHex(box.rightColor, warmSeason ? 0.86 : 0.78);
  const strokeColor = box.strokeColor !== undefined ? box.strokeColor : "#020617";

  const sideFaces: ProjectedPolygonFace3D[] = [];
  for (let i = 0; i < 4; i += 1) {
    const next = (i + 1) % 4;
    const cA = worldCornersXY[i]!;
    const cB = worldCornersXY[next]!;
    const midRot = rotateWorldXY((cA.x + cB.x) / 2, (cA.y + cB.y) / 2, ox, oy, camera.yawDeg);
    const normalX = midRot.rotX - centerRot.rotX;
    const normalY = midRot.rotY - centerRot.rotY;

    if (normalY > 0.05) {
      const tA = topCorners[i]!;
      const tB = topCorners[next]!;
      const bB = bottomCorners[next]!;
      const bA = bottomCorners[i]!;
      const points = [
        `${tA.screenX},${tA.screenY}`,
        `${tB.screenX},${tB.screenY}`,
        `${bB.screenX},${bB.screenY}`,
        `${bA.screenX},${bA.screenY}`
      ].join(" ");
      sideFaces.push({
        points,
        fill: normalX <= 0 ? leftFill : rightFill,
        stroke: strokeColor,
        depthZ: Number(((tA.depthZ + tB.depthZ + bA.depthZ + bB.depthZ) / 4).toFixed(3))
      });
    }
  }

  sideFaces.sort((a, b) => a.depthZ - b.depthZ);

  const topPolygonPoints = topCorners.map((p) => `${p.screenX},${p.screenY}`).join(" ");
  const centerProj = projectPoint3D(
    { x: box.centerX, y: box.centerY, z: box.baseZ + box.heightZ * 0.5 },
    camera,
    { x: ox, y: oy }
  );

  return {
    id: box.id,
    depthZ: centerProj.depthZ,
    topPolygonPoints,
    topFill,
    sideFaces,
    strokeColor,
    isAnimatedCaravan: box.isAnimatedCaravan === true
  };
}

export function classifyTerritoryEcology(
  cell: HexCell,
  seaLevel: number
): {
  altitudeTier: number;
  topZ: number;
  waterZ: number;
  isSubmerged: boolean;
  isCoastalOrInundated: boolean;
  resourceTier: ResourceAbundanceTier;
  healthState: EcologicalHealthState;
} {
  const isSubmerged = cell.biome === "ocean" || cell.altitude < seaLevel;
  const altitudeTier = isSubmerged
    ? 0
    : Math.max(1, Math.min(10, Math.ceil(clamp(cell.altitude, 0, 1) * 10)));
  const topZ = Number(((altitudeTier / 10) * MAX_COLUMN_HEIGHT_PX).toFixed(2));
  const waterZ = Number((clamp(seaLevel, 0, 0.5) * MAX_COLUMN_HEIGHT_PX).toFixed(2));
  const isCoastalOrInundated =
    cell.biome === "coastal_shallows" || cell.altitude <= seaLevel + 0.04;

  const resourceRatio =
    cell.carryingCapacityMax > 0 ? cell.currentResources / cell.carryingCapacityMax : 0;
  const resourceTier: ResourceAbundanceTier =
    resourceRatio >= 0.65 ? "high" : resourceRatio >= 0.30 ? "medium" : "low";

  const healthRatio =
    cell.carryingCapacityMax > 0 ? cell.carryingCapacity / cell.carryingCapacityMax : 0;
  const healthState: EcologicalHealthState =
    healthRatio >= 0.85 ? "healthy" : healthRatio >= 0.60 ? "degraded" : "collapsed";

  return {
    altitudeTier,
    topZ,
    waterZ,
    isSubmerged,
    isCoastalOrInundated,
    resourceTier,
    healthState
  };
}

function pointToSegmentDistance(
  px: number,
  py: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number
): number {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const lenSq = dx * dx + dy * dy;
  if (lenSq < 1e-6) {
    return Math.hypot(px - x1, py - y1);
  }
  const t = clamp(((px - x1) * dx + (py - y1) * dy) / lenSq, 0, 1);
  const projX = x1 + t * dx;
  const projY = y1 + t * dy;
  return Math.hypot(px - projX, py - projY);
}

function isFootprintCleared(
  x: number,
  y: number,
  propRadius: number,
  occupiedCircles: Array<{ x: number; y: number; radius: number }>,
  roadSegments: Array<{ x1: number; y1: number; x2: number; y2: number; width: number }>
): boolean {
  for (const circle of occupiedCircles) {
    if (Math.hypot(x - circle.x, y - circle.y) <= circle.radius + propRadius) {
      return true;
    }
  }
  for (const seg of roadSegments) {
    if (pointToSegmentDistance(x, y, seg.x1, seg.y1, seg.x2, seg.y2) <= seg.width + propRadius) {
      return true;
    }
  }
  return false;
}

const BIOME_PROP_SLOTS: Array<{ dx: number; dy: number }> = [
  { dx: -14, dy: -10 },
  { dx: 14, dy: -9 },
  { dx: -15, dy: 9 },
  { dx: 14, dy: 10 },
  { dx: 0, dy: -16 },
  { dx: 0, dy: 15 }
];

function buildSingleBiomeCluster(
  biome: BiomeType,
  healthState: EcologicalHealthState,
  idPrefix: string,
  x: number,
  y: number,
  baseZ: number,
  waterZ: number,
  slotIndex: number
): VoxelBox3D[] {
  if (biome === "ocean") {
    return [
      {
        id: `${idPrefix}-wave-${slotIndex}`,
        centerX: x,
        centerY: y,
        baseZ: waterZ,
        widthX: 6.5,
        depthY: 2.6,
        heightZ: 1.5,
        topColor: "#7dd3fc",
        leftColor: "#0284c7",
        rightColor: "#0369a1",
        strokeColor: "#0c4a6e"
      }
    ];
  }

  if (healthState === "collapsed" && biome !== "high_mountain") {
    return [
      {
        id: `${idPrefix}-stump-${slotIndex}`,
        centerX: x,
        centerY: y,
        baseZ,
        widthX: 3.4,
        depthY: 3.4,
        heightZ: 2.2,
        topColor: "#78350f",
        leftColor: "#451a03",
        rightColor: "#292524",
        strokeColor: "#1c1917"
      },
      {
        id: `${idPrefix}-crack-${slotIndex}`,
        centerX: x + 2.4,
        centerY: y + 1.8,
        baseZ,
        widthX: 4.2,
        depthY: 3.0,
        heightZ: 1.0,
        topColor: "#57534e",
        leftColor: "#44403c",
        rightColor: "#292524",
        strokeColor: "#1c1917"
      }
    ];
  }

  switch (biome) {
    case "tropical_forest": {
      const canopyHeight = healthState === "healthy" ? 7.2 : 4.6;
      const canopyTop = healthState === "healthy" ? "#10b981" : "#65a30d";
      const canopyLeft = healthState === "healthy" ? "#059669" : "#4d7c0f";
      const canopyRight = healthState === "healthy" ? "#047857" : "#3f6212";
      const blocks: VoxelBox3D[] = [
        {
          id: `${idPrefix}-trunk-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ,
          widthX: 2.6,
          depthY: 2.6,
          heightZ: 4.2,
          topColor: "#78350f",
          leftColor: "#78350f",
          rightColor: "#451a03",
          strokeColor: "#1c1917"
        },
        {
          id: `${idPrefix}-canopy-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ: baseZ + 3.4,
          widthX: 6.8,
          depthY: 6.8,
          heightZ: canopyHeight,
          topColor: canopyTop,
          leftColor: canopyLeft,
          rightColor: canopyRight,
          strokeColor: "#022c22"
        }
      ];
      if (healthState === "degraded" && slotIndex % 2 === 1) {
        blocks.push({
          id: `${idPrefix}-degraded-stump-${slotIndex}`,
          centerX: x + 4.2,
          centerY: y + 1.6,
          baseZ,
          widthX: 2.8,
          depthY: 2.8,
          heightZ: 1.8,
          topColor: "#92400e",
          leftColor: "#78350f",
          rightColor: "#451a03",
          strokeColor: "#1c1917"
        });
      }
      return blocks;
    }

    case "savanna": {
      const crownColor = healthState === "healthy" ? "#eab308" : "#d97706";
      return [
        {
          id: `${idPrefix}-acacia-trunk-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ,
          widthX: 2.2,
          depthY: 2.2,
          heightZ: 4.5,
          topColor: "#78350f",
          leftColor: "#78350f",
          rightColor: "#451a03",
          strokeColor: "#1c1917"
        },
        {
          id: `${idPrefix}-acacia-crown-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ: baseZ + 4.2,
          widthX: 7.6,
          depthY: 6.2,
          heightZ: 2.4,
          topColor: crownColor,
          leftColor: "#ca8a04",
          rightColor: "#a16207",
          strokeColor: "#422006"
        }
      ];
    }

    case "arid_steppe":
      return [
        {
          id: `${idPrefix}-mesa-rock-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ,
          widthX: 5.2,
          depthY: 4.4,
          heightZ: healthState === "healthy" ? 3.8 : 2.4,
          topColor: "#fbbf24",
          leftColor: "#d97706",
          rightColor: "#92400e",
          strokeColor: "#451a03"
        }
      ];

    case "tundra":
      return [
        {
          id: `${idPrefix}-pine-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ,
          widthX: 4.6,
          depthY: 4.6,
          heightZ: healthState === "healthy" ? 6.0 : 3.6,
          topColor: "#e2e8f0",
          leftColor: "#475569",
          rightColor: "#1e293b",
          strokeColor: "#0f172a"
        }
      ];

    case "high_mountain":
      return [
        {
          id: `${idPrefix}-crag-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ,
          widthX: 6.2,
          depthY: 5.8,
          heightZ: 6.5,
          topColor: "#a8a29e",
          leftColor: "#57534e",
          rightColor: "#292524",
          strokeColor: "#1c1917"
        },
        {
          id: `${idPrefix}-snowcap-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ: baseZ + 6.2,
          widthX: 4.8,
          depthY: 4.4,
          heightZ: 2.6,
          topColor: "#f8fafc",
          leftColor: "#cbd5e1",
          rightColor: "#94a3b8",
          strokeColor: "#334155"
        }
      ];

    case "coastal_shallows":
      return [
        {
          id: `${idPrefix}-shoal-${slotIndex}`,
          centerX: x,
          centerY: y,
          baseZ: Math.max(baseZ, waterZ),
          widthX: 5.0,
          depthY: 4.2,
          heightZ: 2.0,
          topColor: "#5eead4",
          leftColor: "#14b8a6",
          rightColor: "#0f766e",
          strokeColor: "#134e4a"
        }
      ];
  }
}

export function buildTerritoryBiomeVoxels(
  territory: Pick<
    VoxelHexTerritory3D,
    "cell" | "baseCenterX" | "baseCenterY" | "topZ" | "waterZ" | "resourceTier" | "healthState"
  >,
  occupiedCircles: Array<{ x: number; y: number; radius: number }>,
  roadSegments: Array<{ x1: number; y1: number; x2: number; y2: number; width: number }>
): VoxelBox3D[] {
  const { cell, baseCenterX, baseCenterY, topZ, waterZ, resourceTier, healthState } = territory;
  const maxClusters =
    cell.biome === "ocean"
      ? 2
      : resourceTier === "high"
        ? 5
        : resourceTier === "medium"
          ? 3
          : 1;

  const props: VoxelBox3D[] = [];
  let placedClusters = 0;

  for (let i = 0; i < BIOME_PROP_SLOTS.length; i += 1) {
    if (placedClusters >= maxClusters) {
      break;
    }
    const slot = BIOME_PROP_SLOTS[i]!;
    const propX = baseCenterX + slot.dx;
    const propY = baseCenterY + slot.dy;

    if (isFootprintCleared(propX, propY, 4.0, occupiedCircles, roadSegments)) {
      continue;
    }

    const cluster = buildSingleBiomeCluster(
      cell.biome,
      healthState,
      `biome-${cell.id}`,
      propX,
      propY,
      topZ,
      waterZ,
      i
    );
    props.push(...cluster);
    placedClusters += 1;
  }

  return props;
}

export function getVillageTier(population: number): {
  tier: VillageTier;
  tierLevel: 1 | 2 | 3 | 4;
  tierRoman: "I" | "II" | "III" | "IV";
} {
  if (population >= 400) {
    return { tier: "settlement", tierLevel: 4, tierRoman: "IV" };
  }
  if (population >= 150) {
    return { tier: "village", tierLevel: 3, tierRoman: "III" };
  }
  if (population >= 50) {
    return { tier: "hamlet", tierLevel: 2, tierRoman: "II" };
  }
  return { tier: "camp", tierLevel: 1, tierRoman: "I" };
}

export interface VillageSectorPlacement {
  deme: Deme;
  worldX: number;
  worldY: number;
  baseZ: number;
  footprintRadius: number;
  heightScale: number;
}

export function computeVillageSectorLayout(
  cellCenter: { x: number; y: number },
  topZ: number,
  residentDemes: Deme[]
): VillageSectorPlacement[] {
  const count = residentDemes.length;
  if (count === 0) {
    return [];
  }

  if (count === 1) {
    const deme = residentDemes[0]!;
    return [
      {
        deme,
        worldX: cellCenter.x,
        worldY: cellCenter.y,
        baseZ: topZ,
        footprintRadius: Number((HEX_SIZE * 0.44).toFixed(2)),
        heightScale: 1.0
      }
    ];
  }

  if (count === 2) {
    const offsets = [
      { dx: -HEX_SIZE * 0.36, dy: -2 },
      { dx: HEX_SIZE * 0.36, dy: 2 }
    ];
    return residentDemes.map((deme, index) => {
      const offset = offsets[index]!;
      const tierInfo = getVillageTier(deme.population);
      return {
        deme,
        worldX: Number((cellCenter.x + offset.dx).toFixed(2)),
        worldY: Number((cellCenter.y + offset.dy).toFixed(2)),
        baseZ: topZ,
        footprintRadius: Number((HEX_SIZE * 0.30).toFixed(2)),
        heightScale: tierInfo.tierLevel >= 3 ? 1.15 : 1.0
      };
    });
  }

  const triOffsets = [
    { dx: -HEX_SIZE * 0.35, dy: HEX_SIZE * 0.18 },
    { dx: HEX_SIZE * 0.35, dy: HEX_SIZE * 0.18 },
    { dx: 0, dy: -HEX_SIZE * 0.34 }
  ];
  return residentDemes.slice(0, 3).map((deme, index) => {
    const offset = triOffsets[index]!;
    const tierInfo = getVillageTier(deme.population);
    return {
      deme,
      worldX: Number((cellCenter.x + offset.dx).toFixed(2)),
      worldY: Number((cellCenter.y + offset.dy).toFixed(2)),
      baseZ: topZ,
      footprintRadius: Number((HEX_SIZE * 0.25).toFixed(2)),
      heightScale: tierInfo.tierLevel >= 3 ? 1.25 : 1.0
    };
  });
}

function buildArchetypeActivityVoxels(
  demeId: string,
  lineageColor: string,
  archetype: DecisionArchetype,
  worldX: number,
  worldY: number,
  baseZ: number,
  compactFactor: number
): VoxelBox3D[] {
  const ox = 5.4 * compactFactor;
  const oy = 4.6 * compactFactor;
  const prefix = `${demeId}-activity-${archetype}`;
  const visual = DECISION_ARCHETYPE_VISUALS[archetype];

  switch (archetype) {
    case "forage":
      return [
        {
          id: `${prefix}-cropbed-1`,
          centerX: worldX - ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 4.6 * compactFactor,
          depthY: 3.4 * compactFactor,
          heightZ: 1.8,
          topColor: "#4ade80",
          leftColor: "#16a34a",
          rightColor: "#14532d",
          strokeColor: "#052e16"
        },
        {
          id: `${prefix}-cropbed-2`,
          centerX: worldX - ox + 3.2 * compactFactor,
          centerY: worldY + oy,
          baseZ,
          widthX: 3.2 * compactFactor,
          depthY: 2.8 * compactFactor,
          heightZ: 2.4,
          topColor: "#86efac",
          leftColor: "#22c55e",
          rightColor: "#15803d",
          strokeColor: "#052e16"
        }
      ];

    case "overexploit":
      return [
        {
          id: `${prefix}-quarry`,
          centerX: worldX + ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 4.8 * compactFactor,
          depthY: 4.0 * compactFactor,
          heightZ: 2.6,
          topColor: "#fb923c",
          leftColor: "#9a3412",
          rightColor: "#431407",
          strokeColor: "#1c1917"
        },
        {
          id: `${prefix}-smokestack`,
          centerX: worldX + ox,
          centerY: worldY + oy,
          baseZ: baseZ + 2.6,
          widthX: 2.4 * compactFactor,
          depthY: 2.4 * compactFactor,
          heightZ: 4.0,
          topColor: "#a8a29e",
          leftColor: "#57534e",
          rightColor: "#292524",
          strokeColor: "#1c1917"
        }
      ];

    case "migrate":
      return [
        {
          id: `${prefix}-cart`,
          centerX: worldX + ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 4.6 * compactFactor,
          depthY: 3.0 * compactFactor,
          heightZ: 2.8,
          topColor: "#38bdf8",
          leftColor: "#0284c7",
          rightColor: "#075985",
          strokeColor: "#082f49"
        },
        {
          id: `${prefix}-waypost`,
          centerX: worldX + ox + 2.4 * compactFactor,
          centerY: worldY + oy - 1.5 * compactFactor,
          baseZ,
          widthX: 1.8 * compactFactor,
          depthY: 1.8 * compactFactor,
          heightZ: 5.2,
          topColor: "#e0f2fe",
          leftColor: "#38bdf8",
          rightColor: "#0369a1",
          strokeColor: "#082f49"
        }
      ];

    case "cooperate":
      return [
        {
          id: `${prefix}-granary-base`,
          centerX: worldX - ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 5.0 * compactFactor,
          depthY: 4.4 * compactFactor,
          heightZ: 3.8,
          topColor: "#60a5fa",
          leftColor: "#2563eb",
          rightColor: "#1e3a8a",
          strokeColor: "#172554"
        },
        {
          id: `${prefix}-granary-dome`,
          centerX: worldX - ox,
          centerY: worldY + oy,
          baseZ: baseZ + 3.8,
          widthX: 4.0 * compactFactor,
          depthY: 3.6 * compactFactor,
          heightZ: 2.2,
          topColor: "#fcd34d",
          leftColor: "#f59e0b",
          rightColor: "#b45309",
          strokeColor: "#451a03"
        }
      ];

    case "exchange":
      return [
        {
          id: `${prefix}-market-stall`,
          centerX: worldX + ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 5.0 * compactFactor,
          depthY: 3.6 * compactFactor,
          heightZ: 3.2,
          topColor: "#34d399",
          leftColor: "#059669",
          rightColor: "#065f46",
          strokeColor: "#022c22"
        },
        {
          id: `${prefix}-trade-bales`,
          centerX: worldX + ox - 2.6 * compactFactor,
          centerY: worldY + oy + 1.4 * compactFactor,
          baseZ,
          widthX: 2.8 * compactFactor,
          depthY: 2.6 * compactFactor,
          heightZ: 2.2,
          topColor: "#fde68a",
          leftColor: "#d97706",
          rightColor: "#92400e",
          strokeColor: "#451a03"
        }
      ];

    case "dispute":
      return [
        {
          id: `${prefix}-palisade`,
          centerX: worldX + ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 5.6 * compactFactor,
          depthY: 2.4 * compactFactor,
          heightZ: 4.4,
          topColor: "#f87171",
          leftColor: "#b91c1c",
          rightColor: "#7f1d1d",
          strokeColor: "#450a0a"
        },
        {
          id: `${prefix}-watchtower`,
          centerX: worldX + ox + 2.2 * compactFactor,
          centerY: worldY + oy - 1.6 * compactFactor,
          baseZ,
          widthX: 2.8 * compactFactor,
          depthY: 2.8 * compactFactor,
          heightZ: 6.4,
          topColor: "#ef4444",
          leftColor: "#991b1b",
          rightColor: "#450a0a",
          strokeColor: "#1c1917"
        }
      ];

    case "innovate":
      return [
        {
          id: `${prefix}-workshop`,
          centerX: worldX - ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 4.6 * compactFactor,
          depthY: 4.0 * compactFactor,
          heightZ: 3.4,
          topColor: "#c084fc",
          leftColor: "#9333ea",
          rightColor: "#581c87",
          strokeColor: "#3b0764"
        },
        {
          id: `${prefix}-discovery-cube`,
          centerX: worldX - ox,
          centerY: worldY + oy,
          baseZ: baseZ + 3.8,
          widthX: 2.8 * compactFactor,
          depthY: 2.8 * compactFactor,
          heightZ: 3.0,
          topColor: "#f3e8ff",
          leftColor: "#d8b4fe",
          rightColor: "#a855f7",
          strokeColor: "#3b0764"
        }
      ];

    case "custom":
      return [
        {
          id: `${prefix}-pavilion`,
          centerX: worldX + ox,
          centerY: worldY + oy,
          baseZ,
          widthX: 4.8 * compactFactor,
          depthY: 4.2 * compactFactor,
          heightZ: 3.6,
          topColor: visual.color,
          leftColor: shadeColorHex(lineageColor, 0.95),
          rightColor: shadeColorHex(lineageColor, 0.72),
          strokeColor: "#422006"
        },
        {
          id: `${prefix}-obelisk`,
          centerX: worldX + ox,
          centerY: worldY + oy,
          baseZ: baseZ + 3.6,
          widthX: 2.4 * compactFactor,
          depthY: 2.4 * compactFactor,
          heightZ: 3.4,
          topColor: "#fef08a",
          leftColor: "#eab308",
          rightColor: "#a16207",
          strokeColor: "#422006"
        }
      ];
  }
}

export function buildVillageSettlementVoxels(
  placement: VillageSectorPlacement,
  vitalStatus: DemeVitalStatus,
  dominantArchetype: DecisionArchetype
): VoxelBox3D[] {
  const { deme, worldX, worldY, baseZ, footprintRadius, heightScale } = placement;
  const tierInfo = getVillageTier(deme.population);
  const tierVisual = VILLAGE_TIER_VISUALS[tierInfo.tier];
  const compactFactor = clamp(footprintRadius / (HEX_SIZE * 0.44), 0.58, 1.0);
  const statusRingColor = DEME_STATUS_RINGS[vitalStatus];
  const roofColor = deme.color;
  const wallLeft = shadeColorHex(tierVisual.wallColor, vitalStatus === "starving" ? 0.68 : 0.95);
  const wallRight = shadeColorHex(tierVisual.wallColor, vitalStatus === "starving" ? 0.52 : 0.76);

  const blocks: VoxelBox3D[] = [
    {
      id: `${deme.id}-plinth`,
      centerX: worldX,
      centerY: worldY,
      baseZ,
      widthX: footprintRadius * 1.45,
      depthY: footprintRadius * 1.32,
      heightZ: 1.4,
      topColor: shadeColorHex(statusRingColor, 0.48),
      leftColor: shadeColorHex(statusRingColor, 0.36),
      rightColor: shadeColorHex(statusRingColor, 0.25),
      strokeColor: statusRingColor
    }
  ];

  const plinthTopZ = baseZ + 1.4;

  if (tierInfo.tier === "camp") {
    const h = Number((4.0 * heightScale).toFixed(2));
    blocks.push(
      {
        id: `${deme.id}-camp-hut-1`,
        centerX: worldX - 3.6 * compactFactor,
        centerY: worldY - 1.5 * compactFactor,
        baseZ: plinthTopZ,
        widthX: 4.4 * compactFactor,
        depthY: 4.0 * compactFactor,
        heightZ: h,
        topColor: roofColor,
        leftColor: wallLeft,
        rightColor: wallRight,
        strokeColor: "#020617"
      },
      {
        id: `${deme.id}-camp-hut-2`,
        centerX: worldX + 3.6 * compactFactor,
        centerY: worldY - 1.0 * compactFactor,
        baseZ: plinthTopZ,
        widthX: 4.0 * compactFactor,
        depthY: 3.8 * compactFactor,
        heightZ: h * 0.88,
        topColor: shadeColorHex(roofColor, 0.92),
        leftColor: wallLeft,
        rightColor: wallRight,
        strokeColor: "#020617"
      },
      {
        id: `${deme.id}-camp-hearth`,
        centerX: worldX,
        centerY: worldY + 1.8 * compactFactor,
        baseZ: plinthTopZ,
        widthX: 2.8 * compactFactor,
        depthY: 2.8 * compactFactor,
        heightZ: 2.2,
        topColor: vitalStatus === "starving" ? "#fb7185" : "#fbbf24",
        leftColor: "#b45309",
        rightColor: "#78350f",
        strokeColor: "#020617"
      }
    );
  } else if (tierInfo.tier === "hamlet") {
    const h = Number((5.4 * heightScale).toFixed(2));
    const houseOffsets = [
      { dx: -4.6, dy: -3.2, scale: 1.0 },
      { dx: 4.6, dy: -3.0, scale: 0.92 },
      { dx: -4.2, dy: 2.8, scale: 0.88 }
    ];
    houseOffsets.forEach((off, idx) => {
      blocks.push({
        id: `${deme.id}-hamlet-house-${idx}`,
        centerX: worldX + off.dx * compactFactor,
        centerY: worldY + off.dy * compactFactor,
        baseZ: plinthTopZ,
        widthX: 4.6 * compactFactor,
        depthY: 4.2 * compactFactor,
        heightZ: h * off.scale,
        topColor: idx === 0 ? roofColor : shadeColorHex(roofColor, 0.9),
        leftColor: wallLeft,
        rightColor: wallRight,
        strokeColor: "#020617"
      });
    });
    blocks.push({
      id: `${deme.id}-hamlet-store`,
      centerX: worldX + 1.2 * compactFactor,
      centerY: worldY + 0.4 * compactFactor,
      baseZ: plinthTopZ,
      widthX: 3.8 * compactFactor,
      depthY: 3.4 * compactFactor,
      heightZ: h * 0.72,
      topColor: tierVisual.roofColor,
      leftColor: wallLeft,
      rightColor: wallRight,
      strokeColor: "#020617"
    });
  } else if (tierInfo.tier === "village") {
    const h = Number((7.2 * heightScale).toFixed(2));
    blocks.push({
      id: `${deme.id}-village-hall`,
      centerX: worldX,
      centerY: worldY - 1.2 * compactFactor,
      baseZ: plinthTopZ,
      widthX: 6.4 * compactFactor,
      depthY: 5.4 * compactFactor,
      heightZ: h,
      topColor: roofColor,
      leftColor: wallLeft,
      rightColor: wallRight,
      strokeColor: "#020617"
    });
    const wingOffsets = [
      { dx: -6.2, dy: -3.6, scale: 0.78 },
      { dx: 6.2, dy: -3.6, scale: 0.78 },
      { dx: -5.8, dy: 3.2, scale: 0.74 },
      { dx: 5.8, dy: 3.2, scale: 0.74 }
    ];
    wingOffsets.forEach((off, idx) => {
      blocks.push({
        id: `${deme.id}-village-dwelling-${idx}`,
        centerX: worldX + off.dx * compactFactor,
        centerY: worldY + off.dy * compactFactor,
        baseZ: plinthTopZ,
        widthX: 4.4 * compactFactor,
        depthY: 4.0 * compactFactor,
        heightZ: h * off.scale,
        topColor: shadeColorHex(roofColor, 0.88),
        leftColor: wallLeft,
        rightColor: wallRight,
        strokeColor: "#020617"
      });
    });
  } else {
    const h = Number((9.6 * heightScale).toFixed(2));
    blocks.push(
      {
        id: `${deme.id}-settlement-citadel-base`,
        centerX: worldX,
        centerY: worldY - 1.0 * compactFactor,
        baseZ: plinthTopZ,
        widthX: 7.8 * compactFactor,
        depthY: 6.8 * compactFactor,
        heightZ: h * 0.68,
        topColor: shadeColorHex(roofColor, 0.92),
        leftColor: wallLeft,
        rightColor: wallRight,
        strokeColor: "#020617"
      },
      {
        id: `${deme.id}-settlement-citadel-spire`,
        centerX: worldX,
        centerY: worldY - 1.0 * compactFactor,
        baseZ: plinthTopZ + h * 0.68,
        widthX: 4.8 * compactFactor,
        depthY: 4.4 * compactFactor,
        heightZ: h * 0.48,
        topColor: roofColor,
        leftColor: shadeColorHex(wallLeft, 1.05),
        rightColor: wallRight,
        strokeColor: "#020617"
      }
    );
    const towerOffsets = [
      { dx: -7.2, dy: -4.8 },
      { dx: 7.2, dy: -4.8 },
      { dx: -7.2, dy: 4.4 },
      { dx: 7.2, dy: 4.4 }
    ];
    towerOffsets.forEach((off, idx) => {
      blocks.push({
        id: `${deme.id}-settlement-tower-${idx}`,
        centerX: worldX + off.dx * compactFactor,
        centerY: worldY + off.dy * compactFactor,
        baseZ: plinthTopZ,
        widthX: 4.2 * compactFactor,
        depthY: 4.2 * compactFactor,
        heightZ: h * 0.82,
        topColor: tierVisual.roofColor,
        leftColor: wallLeft,
        rightColor: wallRight,
        strokeColor: "#020617"
      });
    });
  }

  if (deme.culturalTraitIds.length > 0) {
    const totemHeight = Number(
      ((5.5 + Math.min(4, deme.culturalTraitIds.length) * 1.8) * heightScale).toFixed(2)
    );
    blocks.push({
      id: `${deme.id}-cultural-totem`,
      centerX: worldX,
      centerY: worldY - 5.2 * compactFactor,
      baseZ: plinthTopZ,
      widthX: 2.6 * compactFactor,
      depthY: 2.6 * compactFactor,
      heightZ: totemHeight,
      topColor: "#e9d5ff",
      leftColor: "#a855f7",
      rightColor: "#6b21a8",
      strokeColor: "#3b0764"
    });
  }

  blocks.push(
    ...buildArchetypeActivityVoxels(
      deme.id,
      deme.color,
      dominantArchetype,
      worldX,
      worldY,
      plinthTopZ,
      compactFactor
    )
  );

  return blocks;
}

export function classifyConnectionKind(
  cellA: HexCell,
  cellB: HexCell,
  seaLevel: number
): "road" | "ramp" | "bridge" {
  const isCoastalOrInundatedA =
    cellA.biome === "coastal_shallows" ||
    cellA.biome === "ocean" ||
    cellA.altitude <= seaLevel + 0.04;
  const isCoastalOrInundatedB =
    cellB.biome === "coastal_shallows" ||
    cellB.biome === "ocean" ||
    cellB.altitude <= seaLevel + 0.04;
  const altitudeDelta = Math.abs(cellA.altitude - cellB.altitude);

  if (isCoastalOrInundatedA || isCoastalOrInundatedB || altitudeDelta >= 0.25) {
    return "bridge";
  }
  if (cellA.id !== cellB.id && altitudeDelta >= 0.10) {
    return "ramp";
  }
  return "road";
}

function getArchetypeProbability(
  deme: Deme,
  decisionsCatalog: Record<string, DecisionDefinition>,
  archetype: DecisionArchetype
): number {
  let total = 0;
  for (const [decisionId, prob] of Object.entries(deme.lastDecisionProbabilities)) {
    const def = decisionsCatalog[decisionId];
    if (def !== undefined && def.archetype === archetype) {
      total += prob;
    }
  }
  return total;
}

function resolveDominantArchetypeForDeme(
  deme: Deme,
  decisionsCatalog: Record<string, DecisionDefinition>
): DecisionArchetype {
  const dominantDef = decisionsCatalog[deme.lastDominantDecisionId];
  return dominantDef !== undefined ? dominantDef.archetype : "forage";
}

function makePairKey(demeIdA: string, demeIdB: string): string {
  return demeIdA < demeIdB ? `${demeIdA}::${demeIdB}` : `${demeIdB}::${demeIdA}`;
}

function collectActiveCommercialOrCoopPairs(
  world: WorldState
): Map<string, { sourceDemeId: string; targetDemeId: string; fromHexId: string; toHexId: string }> {
  const pairs = new Map<
    string,
    { sourceDemeId: string; targetDemeId: string; fromHexId: string; toHexId: string }
  >();

  for (const flow of world.currentTurnFlows) {
    if (flow.type !== "exchange") {
      continue;
    }
    const sourceDeme = world.demes[flow.demeId];
    if (sourceDeme === undefined) {
      continue;
    }
    let targetDemeId = flow.targetDemeId;
    if (targetDemeId === undefined || world.demes[targetDemeId] === undefined) {
      const targetCell = world.cells[flow.toHexId];
      if (targetCell !== undefined) {
        targetDemeId = targetCell.demeIds.find((id) => id !== flow.demeId);
      }
    }
    if (targetDemeId !== undefined && world.demes[targetDemeId] !== undefined) {
      const targetDeme = world.demes[targetDemeId]!;
      const key = makePairKey(sourceDeme.id, targetDeme.id);
      pairs.set(key, {
        sourceDemeId: sourceDeme.id,
        targetDemeId: targetDeme.id,
        fromHexId: sourceDeme.hexId,
        toHexId: targetDeme.hexId
      });
    }
  }

  const demes = Object.values(world.demes);
  for (let i = 0; i < demes.length; i += 1) {
    const demeA = demes[i]!;
    const coopA =
      getArchetypeProbability(demeA, world.decisionsCatalog, "cooperate") >= 0.25 ||
      resolveDominantArchetypeForDeme(demeA, world.decisionsCatalog) === "cooperate";
    if (!coopA) {
      continue;
    }
    const cellA = world.cells[demeA.hexId];
    if (cellA === undefined || cellA.biome === "ocean") {
      continue;
    }
    const neighborIds = new Set(
      getExistingNeighborCells(cellA, world.cells).map((n) => n.id)
    );

    for (let j = i + 1; j < demes.length; j += 1) {
      const demeB = demes[j]!;
      if (demeA.hexId !== demeB.hexId && !neighborIds.has(demeB.hexId)) {
        continue;
      }
      const coopB =
        getArchetypeProbability(demeB, world.decisionsCatalog, "cooperate") >= 0.25 ||
        resolveDominantArchetypeForDeme(demeB, world.decisionsCatalog) === "cooperate";
      if (!coopB) {
        continue;
      }
      const key = makePairKey(demeA.id, demeB.id);
      if (!pairs.has(key)) {
        pairs.set(key, {
          sourceDemeId: demeA.id,
          targetDemeId: demeB.id,
          fromHexId: demeA.hexId,
          toHexId: demeB.hexId
        });
      }
    }
  }

  return pairs;
}

function buildConnectionBlocks(
  id: string,
  kind: InterVillageStructureKind,
  status: InfrastructureLifecycleStatus,
  startPoint: Point3D,
  endPoint: Point3D,
  waterZ: number
): VoxelBox3D[] {
  const style = INFRASTRUCTURE_3D_STYLES[kind];
  const topColor = status === "disused" ? "#78716c" : style.topColor;
  const sideColor = status === "disused" ? "#44403c" : style.sideColor;
  const rightColor = shadeColorHex(sideColor, 0.78);
  const dx = endPoint.x - startPoint.x;
  const dy = endPoint.y - startPoint.y;
  const yawOffsetRad = Math.atan2(dy, dx);
  const blocks: VoxelBox3D[] = [];

  if (kind === "dispute_front") {
    const midX = (startPoint.x + endPoint.x) / 2;
    const midY = (startPoint.y + endPoint.y) / 2;
    const midZ = Math.max(startPoint.z, endPoint.z);
    const nx = -Math.sin(yawOffsetRad);
    const ny = Math.cos(yawOffsetRad);
    blocks.push(
      {
        id: `${id}-barricade-a`,
        centerX: midX - Math.cos(yawOffsetRad) * 3.5 + nx * 2.5,
        centerY: midY - Math.sin(yawOffsetRad) * 3.5 + ny * 2.5,
        baseZ: midZ,
        widthX: 3.4,
        depthY: 6.2,
        heightZ: 4.8,
        yawOffsetRad,
        topColor: "#dc2626",
        leftColor: "#991b1b",
        rightColor: "#450a0a",
        strokeColor: "#1c1917"
      },
      {
        id: `${id}-barricade-b`,
        centerX: midX + Math.cos(yawOffsetRad) * 3.5 - nx * 2.5,
        centerY: midY + Math.sin(yawOffsetRad) * 3.5 - ny * 2.5,
        baseZ: midZ,
        widthX: 3.4,
        depthY: 6.2,
        heightZ: 4.8,
        yawOffsetRad,
        topColor: "#ef4444",
        leftColor: "#7f1d1d",
        rightColor: "#450a0a",
        strokeColor: "#1c1917"
      },
      {
        id: `${id}-clash-spark`,
        centerX: midX,
        centerY: midY,
        baseZ: midZ + 4.4,
        widthX: 3.2,
        depthY: 3.2,
        heightZ: 3.2,
        yawOffsetRad,
        topColor: "#fef08a",
        leftColor: "#f97316",
        rightColor: "#dc2626",
        strokeColor: "#450a0a"
      }
    );
    return blocks;
  }

  if (kind === "bridge") {
    const deckZ = Math.max(startPoint.z, endPoint.z, waterZ) + 3.2;
    const steps = 5;
    for (let i = 1; i < steps; i += 1) {
      const t = i / steps;
      const sx = startPoint.x + dx * t;
      const sy = startPoint.y + dy * t;
      blocks.push({
        id: `${id}-deck-${i}`,
        centerX: sx,
        centerY: sy,
        baseZ: deckZ,
        widthX: 5.4,
        depthY: 3.8,
        heightZ: 1.5,
        yawOffsetRad,
        topColor,
        leftColor: sideColor,
        rightColor,
        strokeColor: "#1c1917"
      });
      if (i === 1 || i === 3 || i === 4) {
        const floorZ = Math.min(startPoint.z, endPoint.z, waterZ);
        const pillarHeight = Math.max(2.0, deckZ - floorZ);
        blocks.push({
          id: `${id}-pillar-${i}`,
          centerX: sx,
          centerY: sy,
          baseZ: floorZ,
          widthX: 2.4,
          depthY: 2.4,
          heightZ: pillarHeight,
          yawOffsetRad,
          topColor: sideColor,
          leftColor: sideColor,
          rightColor,
          strokeColor: "#1c1917"
        });
      }
    }
    if (status === "active") {
      blocks.push({
        id: `${id}-caravan`,
        centerX: (startPoint.x + endPoint.x) / 2,
        centerY: (startPoint.y + endPoint.y) / 2,
        baseZ: deckZ + 1.5,
        widthX: 3.2,
        depthY: 2.4,
        heightZ: 2.2,
        yawOffsetRad,
        topColor: "#fde68a",
        leftColor: "#10b981",
        rightColor: "#047857",
        strokeColor: "#022c22",
        isAnimatedCaravan: true
      });
    }
    return blocks;
  }

  if (kind === "ramp") {
    const steps = 5;
    for (let i = 1; i < steps; i += 1) {
      const t = i / steps;
      const sx = startPoint.x + dx * t;
      const sy = startPoint.y + dy * t;
      const sz = startPoint.z + (endPoint.z - startPoint.z) * t;
      blocks.push({
        id: `${id}-step-${i}`,
        centerX: sx,
        centerY: sy,
        baseZ: sz - 0.8,
        widthX: 4.8,
        depthY: 3.8,
        heightZ: 2.0,
        yawOffsetRad,
        topColor,
        leftColor: sideColor,
        rightColor,
        strokeColor: "#1c1917"
      });
    }
    if (status === "active") {
      blocks.push({
        id: `${id}-caravan`,
        centerX: (startPoint.x + endPoint.x) / 2,
        centerY: (startPoint.y + endPoint.y) / 2,
        baseZ: (startPoint.z + endPoint.z) / 2 + 1.2,
        widthX: 3.0,
        depthY: 2.2,
        heightZ: 2.0,
        yawOffsetRad,
        topColor: "#fde68a",
        leftColor: "#34d399",
        rightColor: "#059669",
        strokeColor: "#022c22",
        isAnimatedCaravan: true
      });
    }
    return blocks;
  }

  const steps = kind === "merge_integration" ? 4 : 5;
  for (let i = 1; i < steps; i += 1) {
    const t = i / steps;
    const sx = startPoint.x + dx * t;
    const sy = startPoint.y + dy * t;
    const sz = startPoint.z + (endPoint.z - startPoint.z) * t;
    blocks.push({
      id: `${id}-slab-${i}`,
      centerX: sx,
      centerY: sy,
      baseZ: sz,
      widthX: kind === "expedition" ? 3.2 : 4.6,
      depthY: kind === "expedition" ? 2.6 : 3.2,
      heightZ: 1.0,
      yawOffsetRad,
      topColor,
      leftColor: sideColor,
      rightColor,
      strokeColor: "#1c1917"
    });
  }

  if (status === "active" && (kind === "road" || kind === "expedition")) {
    blocks.push({
      id: `${id}-caravan`,
      centerX: (startPoint.x + endPoint.x) / 2,
      centerY: (startPoint.y + endPoint.y) / 2,
      baseZ: (startPoint.z + endPoint.z) / 2 + 1.0,
      widthX: 3.2,
      depthY: 2.4,
      heightZ: 2.2,
      yawOffsetRad,
      topColor: kind === "expedition" ? "#e0f2fe" : "#fef08a",
      leftColor: kind === "expedition" ? "#38bdf8" : "#34d399",
      rightColor: kind === "expedition" ? "#0284c7" : "#059669",
      strokeColor: "#020617",
      isAnimatedCaravan: true
    });
  }

  return blocks;
}

export function buildInterVillageStructures3D(
  world: WorldState,
  previousWorld: WorldState | null,
  villagesByDemeId: Record<string, VillageSettlement3D>,
  territoriesByHexId: Record<string, VoxelHexTerritory3D>
): {
  structures: InterVillageStructure3D[];
  ruins: ExtinctionRuins3D[];
} {
  const structures: InterVillageStructure3D[] = [];
  const ruins: ExtinctionRuins3D[] = [];
  const disputedPairKeys = new Set<string>();
  const waterZ = Number((clamp(world.seaLevel, 0, 0.5) * MAX_COLUMN_HEIGHT_PX).toFixed(2));

  for (let idx = 0; idx < world.currentTurnFlows.length; idx += 1) {
    const flow = world.currentTurnFlows[idx]!;
    if (flow.type !== "dispute") {
      continue;
    }
    const sourceVillage = villagesByDemeId[flow.demeId];
    const fromTerritory = territoriesByHexId[flow.fromHexId];
    const toTerritory = territoriesByHexId[flow.toHexId];
    if (fromTerritory === undefined || toTerritory === undefined) {
      continue;
    }

    let targetDemeId = flow.targetDemeId;
    if (targetDemeId === undefined || villagesByDemeId[targetDemeId] === undefined) {
      targetDemeId = toTerritory.cell.demeIds.find((id) => id !== flow.demeId);
    }
    const targetVillage = targetDemeId !== undefined ? villagesByDemeId[targetDemeId] : undefined;

    if (sourceVillage !== undefined && targetVillage !== undefined) {
      const pairKey = makePairKey(sourceVillage.deme.id, targetVillage.deme.id);
      if (disputedPairKeys.has(pairKey)) {
        continue;
      }
      disputedPairKeys.add(pairKey);

      const startPoint: Point3D = {
        x: sourceVillage.worldX,
        y: sourceVillage.worldY,
        z: sourceVillage.baseZ
      };
      const endPoint: Point3D = {
        x: targetVillage.worldX,
        y: targetVillage.worldY,
        z: targetVillage.baseZ
      };
      const id = `dispute-${pairKey}`;
      structures.push({
        id,
        kind: "dispute_front",
        status: "active",
        fromHexId: sourceVillage.hexId,
        toHexId: targetVillage.hexId,
        sourceDemeId: sourceVillage.deme.id,
        targetDemeId: targetVillage.deme.id,
        startPoint,
        endPoint,
        color: INFRASTRUCTURE_3D_STYLES.dispute_front.accentColor,
        altitudeDelta: Math.abs(fromTerritory.cell.altitude - toTerritory.cell.altitude),
        crossesWaterOrShallows:
          fromTerritory.isCoastalOrInundated || toTerritory.isCoastalOrInundated,
        blocks: buildConnectionBlocks(id, "dispute_front", "active", startPoint, endPoint, waterZ)
      });
    }
  }

  const activePairs = collectActiveCommercialOrCoopPairs(world);
  const emittedActivePairKeys = new Set<string>();

  for (const [pairKey, pair] of activePairs.entries()) {
    if (disputedPairKeys.has(pairKey)) {
      continue;
    }
    const villageA = villagesByDemeId[pair.sourceDemeId];
    const villageB = villagesByDemeId[pair.targetDemeId];
    if (villageA === undefined || villageB === undefined) {
      continue;
    }
    const territoryA = territoriesByHexId[villageA.hexId];
    const territoryB = territoriesByHexId[villageB.hexId];
    if (territoryA === undefined || territoryB === undefined) {
      continue;
    }

    emittedActivePairKeys.add(pairKey);
    const kind = classifyConnectionKind(territoryA.cell, territoryB.cell, world.seaLevel);
    const startPoint: Point3D = { x: villageA.worldX, y: villageA.worldY, z: villageA.baseZ };
    const endPoint: Point3D = { x: villageB.worldX, y: villageB.worldY, z: villageB.baseZ };
    const id = `${kind}-active-${pairKey}`;

    structures.push({
      id,
      kind,
      status: "active",
      fromHexId: villageA.hexId,
      toHexId: villageB.hexId,
      sourceDemeId: villageA.deme.id,
      targetDemeId: villageB.deme.id,
      startPoint,
      endPoint,
      color: INFRASTRUCTURE_3D_STYLES[kind].accentColor,
      altitudeDelta: Math.abs(territoryA.cell.altitude - territoryB.cell.altitude),
      crossesWaterOrShallows: territoryA.isCoastalOrInundated || territoryB.isCoastalOrInundated,
      blocks: buildConnectionBlocks(id, kind, "active", startPoint, endPoint, waterZ)
    });
  }

  for (let idx = 0; idx < world.currentTurnFlows.length; idx += 1) {
    const flow = world.currentTurnFlows[idx]!;
    if (flow.type !== "migration") {
      continue;
    }
    const fromTerritory = territoriesByHexId[flow.fromHexId];
    const toTerritory = territoriesByHexId[flow.toHexId];
    if (fromTerritory === undefined || toTerritory === undefined) {
      continue;
    }
    const demeVillage = villagesByDemeId[flow.demeId];
    const startPoint: Point3D = {
      x: fromTerritory.baseCenterX,
      y: fromTerritory.baseCenterY,
      z: fromTerritory.topZ
    };
    const endPoint: Point3D =
      demeVillage !== undefined && demeVillage.hexId === flow.toHexId
        ? { x: demeVillage.worldX, y: demeVillage.worldY, z: demeVillage.baseZ }
        : { x: toTerritory.baseCenterX, y: toTerritory.baseCenterY, z: toTerritory.topZ };
    const id = `expedition-${flow.demeId}-${flow.fromHexId}-${flow.toHexId}-${idx}`;

    structures.push({
      id,
      kind: "expedition",
      status: "active",
      fromHexId: flow.fromHexId,
      toHexId: flow.toHexId,
      sourceDemeId: flow.demeId,
      targetDemeId: flow.demeId,
      startPoint,
      endPoint,
      color: flow.color,
      altitudeDelta: Math.abs(fromTerritory.cell.altitude - toTerritory.cell.altitude),
      crossesWaterOrShallows:
        fromTerritory.isCoastalOrInundated || toTerritory.isCoastalOrInundated,
      blocks: buildConnectionBlocks(id, "expedition", "active", startPoint, endPoint, waterZ)
    });
  }

  if (previousWorld !== null) {
    const previousDisputedKeys = new Set<string>();
    for (const prevFlow of previousWorld.currentTurnFlows) {
      if (prevFlow.type === "dispute" && prevFlow.targetDemeId !== undefined) {
        previousDisputedKeys.add(makePairKey(prevFlow.demeId, prevFlow.targetDemeId));
      }
    }

    const previousActivePairs = collectActiveCommercialOrCoopPairs(previousWorld);
    for (const [pairKey, prevPair] of previousActivePairs.entries()) {
      if (
        previousDisputedKeys.has(pairKey) ||
        emittedActivePairKeys.has(pairKey) ||
        disputedPairKeys.has(pairKey)
      ) {
        continue;
      }
      const villageA = villagesByDemeId[prevPair.sourceDemeId];
      const villageB = villagesByDemeId[prevPair.targetDemeId];
      if (villageA === undefined || villageB === undefined) {
        continue;
      }
      const territoryA = territoriesByHexId[villageA.hexId];
      const territoryB = territoriesByHexId[villageB.hexId];
      if (
        territoryA === undefined ||
        territoryB === undefined ||
        territoryA.isSubmerged ||
        territoryB.isSubmerged
      ) {
        continue;
      }

      const kind = classifyConnectionKind(territoryA.cell, territoryB.cell, world.seaLevel);
      const startPoint: Point3D = { x: villageA.worldX, y: villageA.worldY, z: villageA.baseZ };
      const endPoint: Point3D = { x: villageB.worldX, y: villageB.worldY, z: villageB.baseZ };
      const id = `${kind}-disused-${pairKey}`;

      structures.push({
        id,
        kind,
        status: "disused",
        fromHexId: villageA.hexId,
        toHexId: villageB.hexId,
        sourceDemeId: villageA.deme.id,
        targetDemeId: villageB.deme.id,
        startPoint,
        endPoint,
        color: "#78716c",
        altitudeDelta: Math.abs(territoryA.cell.altitude - territoryB.cell.altitude),
        crossesWaterOrShallows:
          territoryA.isCoastalOrInundated || territoryB.isCoastalOrInundated,
        blocks: buildConnectionBlocks(id, kind, "disused", startPoint, endPoint, waterZ)
      });
    }

    const currentExtinctionDemeIds = new Set(
      world.chronicle
        .filter((entry) => entry.generation === world.generation && entry.type === "extinction")
        .map((entry) => entry.demeId)
    );

    for (const prevDeme of Object.values(previousWorld.demes)) {
      if (world.demes[prevDeme.id] !== undefined) {
        continue;
      }
      const territory = territoriesByHexId[prevDeme.hexId];
      if (territory === undefined || territory.isSubmerged) {
        continue;
      }

      const prevCell = previousWorld.cells[prevDeme.hexId];
      const prevResidents =
        prevCell !== undefined
          ? prevCell.demeIds
              .map((id) => previousWorld.demes[id])
              .filter((d): d is Deme => d !== undefined)
          : [prevDeme];
      const prevLayouts = computeVillageSectorLayout(
        { x: territory.baseCenterX, y: territory.baseCenterY },
        territory.topZ,
        prevResidents
      );
      const prevSector =
        prevLayouts.find((p) => p.deme.id === prevDeme.id) !== undefined
          ? prevLayouts.find((p) => p.deme.id === prevDeme.id)!
          : {
              deme: prevDeme,
              worldX: territory.baseCenterX,
              worldY: territory.baseCenterY,
              baseZ: territory.topZ,
              footprintRadius: 10,
              heightScale: 1
            };

      if (currentExtinctionDemeIds.has(prevDeme.id)) {
        ruins.push({
          id: `ruins-${prevDeme.id}`,
          demeId: prevDeme.id,
          demeName: prevDeme.name,
          lineageColor: prevDeme.color,
          hexId: prevDeme.hexId,
          worldX: prevSector.worldX,
          worldY: prevSector.worldY,
          baseZ: territory.topZ,
          ruinBlocks: [
            {
              id: `ruins-${prevDeme.id}-1`,
              centerX: prevSector.worldX - 2.4,
              centerY: prevSector.worldY - 1.2,
              baseZ: territory.topZ,
              widthX: 3.8,
              depthY: 3.4,
              heightZ: 2.2,
              topColor: "#78716c",
              leftColor: "#57534e",
              rightColor: "#292524",
              strokeColor: "#1c1917"
            },
            {
              id: `ruins-${prevDeme.id}-2`,
              centerX: prevSector.worldX + 2.2,
              centerY: prevSector.worldY + 1.4,
              baseZ: territory.topZ,
              widthX: 3.2,
              depthY: 2.8,
              heightZ: 1.5,
              topColor: shadeColorHex(prevDeme.color, 0.55),
              leftColor: "#44403c",
              rightColor: "#1c1917",
              strokeColor: "#0c0a09"
            }
          ]
        });
      } else {
        const siblingSurvivorId = territory.cell.demeIds.find((id) => {
          const survivor = world.demes[id];
          return survivor !== undefined && survivor.lineageId === prevDeme.lineageId;
        });
        const survivorVillage =
          siblingSurvivorId !== undefined ? villagesByDemeId[siblingSurvivorId] : undefined;

        if (survivorVillage !== undefined) {
          const startPoint: Point3D = {
            x: prevSector.worldX,
            y: prevSector.worldY,
            z: territory.topZ
          };
          const endPoint: Point3D = {
            x: survivorVillage.worldX,
            y: survivorVillage.worldY,
            z: survivorVillage.baseZ
          };
          const id = `merge-${prevDeme.id}-${survivorVillage.deme.id}`;
          structures.push({
            id,
            kind: "merge_integration",
            status: "active",
            fromHexId: territory.cell.id,
            toHexId: territory.cell.id,
            sourceDemeId: prevDeme.id,
            targetDemeId: survivorVillage.deme.id,
            startPoint,
            endPoint,
            color: prevDeme.color,
            altitudeDelta: 0,
            crossesWaterOrShallows: false,
            blocks: buildConnectionBlocks(
              id,
              "merge_integration",
              "active",
              startPoint,
              endPoint,
              waterZ
            )
          });
        }
      }
    }
  }

  return { structures, ruins };
}

function computeHexColumnSideFaces(
  cornersXY: Array<{ x: number; y: number }>,
  centerX: number,
  centerY: number,
  bottomZ: number,
  topZ: number,
  strataCount: number,
  camera: Camera3DState,
  origin: { x: number; y: number }
): HexSideFace3D[] {
  if (topZ <= bottomZ + 0.05) {
    return [];
  }
  const centerRot = rotateWorldXY(centerX, centerY, origin.x, origin.y, camera.yawDeg);
  const faces: HexSideFace3D[] = [];

  for (let i = 0; i < 6; i += 1) {
    const next = (i + 1) % 6;
    const cA = cornersXY[i]!;
    const cB = cornersXY[next]!;
    const midRot = rotateWorldXY((cA.x + cB.x) / 2, (cA.y + cB.y) / 2, origin.x, origin.y, camera.yawDeg);
    const nx = midRot.rotX - centerRot.rotX;
    const ny = midRot.rotY - centerRot.rotY;

    if (ny <= 0.05) {
      continue;
    }

    const tA = projectPoint3D({ x: cA.x, y: cA.y, z: topZ }, camera, origin);
    const tB = projectPoint3D({ x: cB.x, y: cB.y, z: topZ }, camera, origin);
    const bB = projectPoint3D({ x: cB.x, y: cB.y, z: bottomZ }, camera, origin);
    const bA = projectPoint3D({ x: cA.x, y: cA.y, z: bottomZ }, camera, origin);

    const points = [
      `${tA.screenX},${tA.screenY}`,
      `${tB.screenX},${tB.screenY}`,
      `${bB.screenX},${bB.screenY}`,
      `${bA.screenX},${bA.screenY}`
    ].join(" ");

    const shadeFactor = nx < -2 ? 1.0 : nx > 2 ? 0.72 : 0.86;
    const strataLines: Array<{ x1: number; y1: number; x2: number; y2: number }> = [];

    for (let s = 1; s < strataCount; s += 1) {
      const zStep = bottomZ + ((topZ - bottomZ) * s) / strataCount;
      const p1 = projectPoint3D({ x: cA.x, y: cA.y, z: zStep }, camera, origin);
      const p2 = projectPoint3D({ x: cB.x, y: cB.y, z: zStep }, camera, origin);
      strataLines.push({ x1: p1.screenX, y1: p1.screenY, x2: p2.screenX, y2: p2.screenY });
    }

    faces.push({
      edgeIndex: i,
      points,
      shadeFactor,
      strataLines
    });
  }

  return faces;
}

export function computeWorldOrigin(cells: Record<string, HexCell>): { x: number; y: number } {
  const cellList = Object.values(cells);
  if (cellList.length === 0) {
    return { x: 0, y: 0 };
  }
  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;

  for (const cell of cellList) {
    const geom = computeHexPixelGeometry(cell.q, cell.r);
    if (geom.centerX < minX) minX = geom.centerX;
    if (geom.centerX > maxX) maxX = geom.centerX;
    if (geom.centerY < minY) minY = geom.centerY;
    if (geom.centerY > maxY) maxY = geom.centerY;
  }

  return {
    x: Number(((minX + maxX) / 2).toFixed(2)),
    y: Number(((minY + maxY) / 2).toFixed(2))
  };
}

export interface BuildWorld3DSceneOptions {
  previousWorld?: WorldState | null;
  highlightedLineageId?: string | null;
}

export function buildWorld3DScene(
  world: WorldState,
  rawCamera: Partial<Camera3DState>,
  options?: BuildWorld3DSceneOptions
): World3DScene {
  const previousWorld =
    options !== undefined && options.previousWorld !== undefined ? options.previousWorld : null;
  const highlightedLineageId =
    options !== undefined && options.highlightedLineageId !== undefined
      ? options.highlightedLineageId
      : null;
  const camera = clampCamera3D(rawCamera);
  const origin = computeWorldOrigin(world.cells);
  const cellList = Object.values(world.cells);

  const territoriesByHexId: Record<string, VoxelHexTerritory3D> = {};
  const villagesByDemeId: Record<string, VillageSettlement3D> = {};
  const occupiedCirclesByHexId: Record<string, Array<{ x: number; y: number; radius: number }>> = {};

  for (const cell of cellList) {
    const baseGeom = computeHexPixelGeometry(cell.q, cell.r);
    const ecology = classifyTerritoryEcology(cell, world.seaLevel);
    const topCorners = baseGeom.corners.map((c) =>
      projectPoint3D({ x: c.x, y: c.y, z: ecology.topZ }, camera, origin)
    );
    const baseCorners = baseGeom.corners.map((c) =>
      projectPoint3D({ x: c.x, y: c.y, z: 0 }, camera, origin)
    );
    const waterTopCorners = baseGeom.corners.map((c) =>
      projectPoint3D({ x: c.x, y: c.y, z: Math.max(ecology.topZ, ecology.waterZ) }, camera, origin)
    );

    const sideFaces = computeHexColumnSideFaces(
      baseGeom.corners,
      baseGeom.centerX,
      baseGeom.centerY,
      0,
      ecology.topZ,
      ecology.altitudeTier,
      camera,
      origin
    );
    const waterSideFaces =
      ecology.isSubmerged || ecology.waterZ > ecology.topZ
        ? computeHexColumnSideFaces(
            baseGeom.corners,
            baseGeom.centerX,
            baseGeom.centerY,
            ecology.topZ,
            ecology.waterZ,
            1,
            camera,
            origin
          )
        : [];

    const projectedCenter = projectPoint3D(
      { x: baseGeom.centerX, y: baseGeom.centerY, z: ecology.topZ },
      camera,
      origin
    );

    territoriesByHexId[cell.id] = {
      cell,
      baseCenterX: baseGeom.centerX,
      baseCenterY: baseGeom.centerY,
      altitudeTier: ecology.altitudeTier,
      topZ: ecology.topZ,
      waterZ: ecology.waterZ,
      isSubmerged: ecology.isSubmerged,
      isCoastalOrInundated: ecology.isCoastalOrInundated,
      resourceTier: ecology.resourceTier,
      healthState: ecology.healthState,
      depthKey: projectedCenter.depthZ,
      topPolygonPoints: topCorners.map((p) => `${p.screenX},${p.screenY}`).join(" "),
      basePolygonPoints: baseCorners.map((p) => `${p.screenX},${p.screenY}`).join(" "),
      waterTopPolygonPoints: waterTopCorners.map((p) => `${p.screenX},${p.screenY}`).join(" "),
      waterSideFaces,
      sideFaces,
      topCorners,
      projectedCenter,
      biomeProps: []
    };

    const residentDemes = cell.demeIds
      .map((id) => world.demes[id])
      .filter((d): d is Deme => d !== undefined);
    const placements = computeVillageSectorLayout(
      { x: baseGeom.centerX, y: baseGeom.centerY },
      ecology.topZ,
      residentDemes
    );

    occupiedCirclesByHexId[cell.id] = placements.map((p) => ({
      x: p.worldX,
      y: p.worldY,
      radius: p.footprintRadius
    }));

    const pendingCellVillages = placements.map((placement) => {
      const { deme, worldX, worldY, baseZ, footprintRadius } = placement;
      const tierInfo = getVillageTier(deme.population);
      const vitalStatus = getDemeStatus(deme);
      const dominantArchetype = resolveDominantArchetypeForDeme(deme, world.decisionsCatalog);
      const buildings = buildVillageSettlementVoxels(placement, vitalStatus, dominantArchetype);
      const maxBuildingTopZ = Math.max(...buildings.map((b) => b.baseZ + b.heightZ));
      const roofAnchor = projectPoint3D(
        { x: worldX, y: worldY, z: maxBuildingTopZ },
        camera,
        origin
      );
      return {
        deme,
        worldX,
        worldY,
        baseZ,
        footprintRadius,
        tierInfo,
        vitalStatus,
        dominantArchetype,
        buildings,
        roofAnchor
      };
    });

    pendingCellVillages.sort((a, b) => a.roofAnchor.screenX - b.roofAnchor.screenX);

    for (let vIdx = 0; vIdx < pendingCellVillages.length; vIdx += 1) {
      const item = pendingCellVillages[vIdx]!;
      const {
        deme,
        worldX,
        worldY,
        baseZ,
        footprintRadius,
        tierInfo,
        vitalStatus,
        dominantArchetype,
        buildings,
        roofAnchor
      } = item;

      let offsetX = 0;
      let offsetY = -14;
      if (pendingCellVillages.length === 2) {
        offsetX = vIdx === 0 ? -15 : 15;
        offsetY = -15;
      } else if (pendingCellVillages.length >= 3) {
        if (vIdx === 0) {
          offsetX = -20;
          offsetY = -12;
        } else if (vIdx === 1) {
          offsetX = 0;
          offsetY = -28;
        } else {
          offsetX = 20;
          offsetY = -12;
        }
      }

      const billboardAnchor: ProjectedPoint3D = {
        screenX: Number((roofAnchor.screenX + offsetX).toFixed(2)),
        screenY: Number((roofAnchor.screenY + offsetY).toFixed(2)),
        depthZ: roofAnchor.depthZ
      };

      villagesByDemeId[deme.id] = {
        deme,
        hexId: cell.id,
        tier: tierInfo.tier,
        tierLevel: tierInfo.tierLevel,
        tierRoman: tierInfo.tierRoman,
        vitalStatus,
        dominantArchetype,
        hasCulture: deme.culturalTraitIds.length > 0,
        culturalLevel: deme.culturalTraitIds.length,
        isHighlightedLineage:
          highlightedLineageId === null || deme.lineageId === highlightedLineageId,
        isDimmedByLineageFilter:
          highlightedLineageId !== null && deme.lineageId !== highlightedLineageId,
        worldX,
        worldY,
        baseZ,
        footprintRadius,
        buildings,
        roofAnchor,
        billboardAnchor,
        isOccludedByFrontTerrain: false
      };
    }
  }

  const { structures, ruins } = buildInterVillageStructures3D(
    world,
    previousWorld,
    villagesByDemeId,
    territoriesByHexId
  );

  for (const r of ruins) {
    const circles = occupiedCirclesByHexId[r.hexId];
    if (circles !== undefined) {
      circles.push({ x: r.worldX, y: r.worldY, radius: 9.5 });
    }
  }

  const roadSegmentsByHexId: Record<
    string,
    Array<{ x1: number; y1: number; x2: number; y2: number; width: number }>
  > = {};
  for (const cell of cellList) {
    roadSegmentsByHexId[cell.id] = [];
  }
  for (const structure of structures) {
    const seg = {
      x1: structure.startPoint.x,
      y1: structure.startPoint.y,
      x2: structure.endPoint.x,
      y2: structure.endPoint.y,
      width: 4.5
    };
    if (roadSegmentsByHexId[structure.fromHexId] !== undefined) {
      roadSegmentsByHexId[structure.fromHexId]!.push(seg);
    }
    if (
      structure.toHexId !== structure.fromHexId &&
      roadSegmentsByHexId[structure.toHexId] !== undefined
    ) {
      roadSegmentsByHexId[structure.toHexId]!.push(seg);
    }
  }

  for (const territory of Object.values(territoriesByHexId)) {
    territory.biomeProps = buildTerritoryBiomeVoxels(
      territory,
      occupiedCirclesByHexId[territory.cell.id]!,
      roadSegmentsByHexId[territory.cell.id]!
    );
  }

  const sortedTerritories = Object.values(territoriesByHexId).sort((a, b) =>
    a.depthKey !== b.depthKey ? a.depthKey - b.depthKey : a.cell.id.localeCompare(b.cell.id)
  );

  const villages = Object.values(villagesByDemeId).sort(
    (a, b) => a.billboardAnchor.depthZ - b.billboardAnchor.depthZ
  );

  for (const village of villages) {
    const parentTerritory = territoriesByHexId[village.hexId];
    if (parentTerritory === undefined) {
      continue;
    }
    const occluded = sortedTerritories.some(
      (frontTerritory) =>
        frontTerritory.cell.id !== village.hexId &&
        frontTerritory.depthKey > parentTerritory.depthKey + 4 &&
        frontTerritory.topZ > village.baseZ + 6 &&
        Math.hypot(
          frontTerritory.projectedCenter.screenX - village.billboardAnchor.screenX,
          frontTerritory.projectedCenter.screenY - village.billboardAnchor.screenY
        ) <
          HEX_SIZE * camera.zoom * 0.92
    );
    village.isOccludedByFrontTerrain = occluded;
  }

  return {
    origin,
    camera,
    territories: sortedTerritories,
    territoriesByHexId,
    villages,
    villagesByDemeId,
    structures,
    ruins
  };
}
