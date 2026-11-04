import {
  useEffect,
  useState,
  type KeyboardEvent,
  type PointerEvent,
  type WheelEvent
} from "react";
import { useTranslation } from "react-i18next";
import { Compass, Eye, Minus, Plus, RotateCcw, RotateCw, X } from "lucide-react";
import { computeCellsViewBox, getHexIdsInRadius, HEX_SIZE } from "../engine/hexGrid";
import {
  buildWorld3DScene,
  clampCamera3D,
  DEFAULT_CAMERA_3D,
  MAX_ZOOM_3D,
  MIN_ZOOM_3D,
  projectPoint3D,
  projectVoxelBoxFaces,
  type Camera3DState,
  type ProjectedVoxelBox3D,
  type VillageSettlement3D,
  type VoxelBox3D,
  type VoxelHexTerritory3D
} from "../engine/world3d";
import { useSimulationStore, type MapLens } from "../store/useSimulationStore";
import type { Deme, HexCell } from "../types/simulation";
import {
  BIOME_RELIEF_COLORS,
  BIOME_STYLES,
  colorOnScale,
  DECISION_ARCHETYPE_VISUALS,
  DEME_STATUS_RINGS,
  FOOD_SCALE,
  habitatHealthRatio,
  HEALTH_SCALE,
  INFRASTRUCTURE_3D_STYLES,
  shadeColorHex,
  VILLAGE_TIER_VISUALS
} from "./palette";

interface HoveredHex {
  hexId: string;
  left: number;
  top: number;
}

interface CameraDragState {
  mode: "pan" | "orbit";
  startClientX: number;
  startClientY: number;
  startCamera: Camera3DState;
  moved: boolean;
}

const HOVER_CARD_WIDTH = 248;
const HOVER_CARD_HEIGHT = 188;
const HOVER_CARD_GAP = 16;
const ZOOM_STEP = 0.3;
const PITCH_PRESETS = [32, 48, 68] as const;

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function formatPopulation(population: number): string {
  return population >= 1000 ? `${(population / 1000).toFixed(1)}k` : String(population);
}

function computeTerritoryTopFill(
  cell: HexCell,
  lens: MapLens,
  season: "wet_warm" | "dry_cold"
): string {
  if (cell.biome === "ocean") {
    return BIOME_STYLES.ocean.fill;
  }
  if (lens === "food") {
    return colorOnScale(FOOD_SCALE, cell.currentResources / cell.carryingCapacityMax);
  }
  if (lens === "health") {
    return colorOnScale(HEALTH_SCALE, habitatHealthRatio(cell));
  }
  const baseFill = BIOME_RELIEF_COLORS[cell.biome].topHighlight;
  return shadeColorHex(baseFill, season === "wet_warm" ? 1.04 : 0.94);
}

function renderProjectedVoxelBox(proj: ProjectedVoxelBox3D) {
  return (
    <g
      key={proj.id}
      className={proj.isAnimatedCaravan ? "voxel-caravan-animated" : undefined}
    >
      {proj.sideFaces.map((face, idx) => (
        <polygon
          key={`${proj.id}-side-${idx}`}
          points={face.points}
          fill={face.fill}
          stroke={face.stroke}
          strokeWidth={0.55}
          strokeLinejoin="round"
        />
      ))}
      <polygon
        points={proj.topPolygonPoints}
        fill={proj.topFill}
        stroke={proj.strokeColor}
        strokeWidth={0.6}
        strokeLinejoin="round"
      />
    </g>
  );
}

export function HexMapCanvas() {
  const { t } = useTranslation();
  const world = useSimulationStore((s) => s.world);
  const previousWorld = useSimulationStore((s) => s.previousWorld);
  const mapLens = useSimulationStore((s) => s.mapLens);
  const selectedHexId = useSimulationStore((s) => s.selectedHexId);
  const selectedDemeId = useSimulationStore((s) => s.selectedDemeId);
  const activeBrush = useSimulationStore((s) => s.activeBrush);
  const activeModal = useSimulationStore((s) => s.activeModal);
  const highlightedLineageId = useSimulationStore((s) => s.highlightedLineageId);
  const selectHex = useSimulationStore((s) => s.selectHex);
  const selectDeme = useSimulationStore((s) => s.selectDeme);
  const applyBrushToHex = useSimulationStore((s) => s.applyBrushToHex);
  const setHighlightedLineageId = useSimulationStore((s) => s.setHighlightedLineageId);

  const [isPointerDown, setIsPointerDown] = useState(false);
  const [hovered, setHovered] = useState<HoveredHex | null>(null);
  const [camera, setCamera] = useState<Camera3DState>(DEFAULT_CAMERA_3D);
  const [dragState, setDragState] = useState<CameraDragState | null>(null);

  useEffect(() => {
    setCamera(DEFAULT_CAMERA_3D);
    setHovered(null);
  }, [world.presetId]);

  const cellArray = Object.values(world.cells);
  const baseViewBox = computeCellsViewBox(cellArray, HEX_SIZE * 2.8);
  const [baseMinX, baseMinY, baseWidth, baseHeight] = baseViewBox.split(" ").map(Number) as [
    number,
    number,
    number,
    number
  ];

  const scene = buildWorld3DScene(world, camera, {
    previousWorld,
    highlightedLineageId
  });

  useEffect(() => {
    if (selectedDemeId === null) {
      return;
    }
    const targetVillage = scene.villagesByDemeId[selectedDemeId];
    if (targetVillage === undefined) {
      return;
    }
    setCamera((prev) => {
      if (prev.zoom <= 1.0) {
        return prev;
      }
      const unpanned = projectPoint3D(
        { x: targetVillage.worldX, y: targetVillage.worldY, z: targetVillage.baseZ },
        { ...prev, panX: 0, panY: 0 },
        scene.origin
      );
      const maxPan = baseWidth * 0.55;
      return clampCamera3D({
        ...prev,
        panX: clamp(scene.origin.x - unpanned.screenX, -maxPan, maxPan),
        panY: clamp(scene.origin.y - unpanned.screenY, -maxPan, maxPan)
      });
    });
  }, [selectedDemeId]);

  const isPainting = activeBrush.kind !== "inspect";
  const hoveredCell = hovered !== null ? world.cells[hovered.hexId] : undefined;
  const brushPreviewIds =
    hoveredCell !== undefined && activeBrush.kind !== "inspect"
      ? getHexIdsInRadius(hoveredCell.q, hoveredCell.r, activeBrush.radius, world.cells)
      : [];

  const eventHexIds = new Set(
    world.chronicle
      .filter((entry) => entry.generation === world.generation && world.generation > 0)
      .map((entry) => entry.hexId)
  );

  function rotateCameraBy(deltaYaw: number) {
    setCamera((prev) => clampCamera3D({ ...prev, yawDeg: prev.yawDeg + deltaYaw }));
  }

  function cycleCameraTilt() {
    setCamera((prev) => {
      const currentIdx = PITCH_PRESETS.findIndex((p) => Math.abs(p - prev.pitchDeg) <= 6);
      const nextPitch =
        currentIdx === -1
          ? PITCH_PRESETS[0]
          : PITCH_PRESETS[(currentIdx + 1) % PITCH_PRESETS.length]!;
      return clampCamera3D({ ...prev, pitchDeg: nextPitch });
    });
  }

  function adjustZoom(nextZoom: number) {
    setCamera((prev) => {
      const clampedZoom = clamp(nextZoom, MIN_ZOOM_3D, MAX_ZOOM_3D);
      return clampCamera3D({
        ...prev,
        zoom: clampedZoom,
        panX: clampedZoom <= 1.0 ? 0 : prev.panX,
        panY: clampedZoom <= 1.0 ? 0 : prev.panY
      });
    });
  }

  function resetCamera() {
    setCamera(DEFAULT_CAMERA_3D);
  }

  function handleWheel(event: WheelEvent<SVGSVGElement>) {
    const delta = event.deltaY < 0 ? ZOOM_STEP : -ZOOM_STEP;
    adjustZoom(camera.zoom + delta);
  }

  function applyCameraShortcutKey(keyRaw: string): boolean {
    const key = keyRaw.toLowerCase();
    if (key === "q") {
      rotateCameraBy(-18);
      return true;
    }
    if (key === "e") {
      rotateCameraBy(18);
      return true;
    }
    if (key === "r") {
      setCamera((prev) => clampCamera3D({ ...prev, pitchDeg: prev.pitchDeg - 8 }));
      return true;
    }
    if (key === "f") {
      setCamera((prev) => clampCamera3D({ ...prev, pitchDeg: prev.pitchDeg + 8 }));
      return true;
    }
    if (key === "w" || keyRaw === "ArrowUp") {
      setCamera((prev) => clampCamera3D({ ...prev, panY: prev.panY + 24 }));
      return true;
    }
    if (key === "s" || keyRaw === "ArrowDown") {
      setCamera((prev) => clampCamera3D({ ...prev, panY: prev.panY - 24 }));
      return true;
    }
    if (key === "a" || keyRaw === "ArrowLeft") {
      setCamera((prev) => clampCamera3D({ ...prev, panX: prev.panX + 24 }));
      return true;
    }
    if (key === "d" || keyRaw === "ArrowRight") {
      setCamera((prev) => clampCamera3D({ ...prev, panX: prev.panX - 24 }));
      return true;
    }
    if (key === "+" || key === "=") {
      setCamera((prev) => {
        const clampedZoom = clamp(prev.zoom + ZOOM_STEP, MIN_ZOOM_3D, MAX_ZOOM_3D);
        return clampCamera3D({ ...prev, zoom: clampedZoom });
      });
      return true;
    }
    if (key === "-") {
      setCamera((prev) => {
        const clampedZoom = clamp(prev.zoom - ZOOM_STEP, MIN_ZOOM_3D, MAX_ZOOM_3D);
        return clampCamera3D({
          ...prev,
          zoom: clampedZoom,
          panX: clampedZoom <= 1.0 ? 0 : prev.panX,
          panY: clampedZoom <= 1.0 ? 0 : prev.panY
        });
      });
      return true;
    }
    if (key === "0") {
      resetCamera();
      return true;
    }
    return false;
  }

  useEffect(() => {
    function handleWindowKeyDown(event: globalThis.KeyboardEvent) {
      if (activeModal !== "none" || event.ctrlKey || event.metaKey || event.altKey) {
        return;
      }
      if (
        event.target instanceof HTMLElement &&
        event.target.closest("input, select, textarea, dialog") !== null
      ) {
        return;
      }
      if (applyCameraShortcutKey(event.key)) {
        event.preventDefault();
      }
    }
    window.addEventListener("keydown", handleWindowKeyDown);
    return () => window.removeEventListener("keydown", handleWindowKeyDown);
  }, [activeModal]);

  function handleCanvasKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.defaultPrevented) {
      return;
    }
    const tag = (event.target as HTMLElement).tagName;
    if (tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA") {
      return;
    }
    if (applyCameraShortcutKey(event.key)) {
      event.preventDefault();
    }
  }

  function handleSvgPointerDown(event: PointerEvent<SVGSVGElement>) {
    if (isPainting) {
      return;
    }
    const shouldOrbit = event.shiftKey || event.altKey || event.button === 2 || event.button === 1;
    setDragState({
      mode: shouldOrbit ? "orbit" : "pan",
      startClientX: event.clientX,
      startClientY: event.clientY,
      startCamera: camera,
      moved: false
    });
  }

  function handleSvgPointerMove(event: PointerEvent<SVGSVGElement>) {
    if (dragState === null || isPainting) {
      return;
    }
    const dxPx = event.clientX - dragState.startClientX;
    const dyPx = event.clientY - dragState.startClientY;
    if (Math.hypot(dxPx, dyPx) < 4 && !dragState.moved) {
      return;
    }

    setDragState({ ...dragState, moved: true });

    if (dragState.mode === "orbit") {
      setCamera(
        clampCamera3D({
          ...dragState.startCamera,
          yawDeg: dragState.startCamera.yawDeg + dxPx * 0.45,
          pitchDeg: dragState.startCamera.pitchDeg - dyPx * 0.25
        })
      );
      return;
    }

    const svgBounds = event.currentTarget.getBoundingClientRect();
    const scaleX = baseWidth / Math.max(1, svgBounds.width);
    const scaleY = baseHeight / Math.max(1, svgBounds.height);
    const maxPan = baseWidth * 0.55;

    setCamera(
      clampCamera3D({
        ...dragState.startCamera,
        panX: clamp(dragState.startCamera.panX + dxPx * scaleX, -maxPan, maxPan),
        panY: clamp(dragState.startCamera.panY + dyPx * scaleY, -maxPan, maxPan)
      })
    );
  }

  function handleHexPointerDown(hexId: string) {
    setIsPointerDown(true);
    if (isPainting) {
      applyBrushToHex(hexId);
      selectHex(hexId);
    }
  }

  function handleHexClick(hexId: string) {
    if (dragState !== null && dragState.moved) {
      return;
    }
    selectHex(hexId);
  }

  function handleHexPointerEnter(hexId: string, event: PointerEvent<SVGGElement>) {
    const bounds = event.currentTarget.ownerSVGElement!.getBoundingClientRect();
    const x = event.clientX - bounds.left;
    const y = event.clientY - bounds.top;
    setHovered({
      hexId,
      left:
        x + HOVER_CARD_GAP + HOVER_CARD_WIDTH > bounds.width
          ? x - HOVER_CARD_GAP - HOVER_CARD_WIDTH
          : x + HOVER_CARD_GAP,
      top:
        y + HOVER_CARD_GAP + HOVER_CARD_HEIGHT > bounds.height
          ? y - HOVER_CARD_GAP - HOVER_CARD_HEIGHT
          : y + HOVER_CARD_GAP
    });
    if (isPointerDown && isPainting) {
      applyBrushToHex(hexId);
    }
  }

  function selectPopulation(deme: Deme) {
    selectHex(deme.hexId);
    selectDeme(deme.id);
  }

  function handleDemeKeyDown(deme: Deme, event: KeyboardEvent<SVGGElement>) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      selectPopulation(deme);
    }
  }

  function renderTerritoryColumn(territory: VoxelHexTerritory3D) {
    const { cell } = territory;
    const relief = BIOME_RELIEF_COLORS[cell.biome];
    const warmFactor = world.season === "wet_warm" ? 1.03 : 0.92;
    const topFill = computeTerritoryTopFill(cell, mapLens, world.season);
    const resourceRatio = clamp(cell.currentResources / cell.carryingCapacityMax, 0, 1);
    const projectedProps = territory.biomeProps
      .map((box) => projectVoxelBoxFaces(box, scene.camera, world.season, scene.origin))
      .sort((a, b) => a.depthZ - b.depthZ);

    const cellRuins = scene.ruins.filter((r) => r.hexId === cell.id);
    const projectedRuins: ProjectedVoxelBox3D[] = [];
    for (const ruin of cellRuins) {
      for (const block of ruin.ruinBlocks) {
        projectedRuins.push(projectVoxelBoxFaces(block, scene.camera, world.season, scene.origin));
      }
    }
    projectedRuins.sort((a, b) => a.depthZ - b.depthZ);

    const residentVillages = cell.demeIds
      .map((id) => scene.villagesByDemeId[id])
      .filter((v): v is VillageSettlement3D => v !== undefined)
      .sort((a, b) => a.billboardAnchor.depthZ - b.billboardAnchor.depthZ);

    return (
      <g
        key={cell.id}
        onPointerDown={() => handleHexPointerDown(cell.id)}
        onClick={() => handleHexClick(cell.id)}
        onPointerEnter={(e) => handleHexPointerEnter(cell.id, e)}
        className={isPainting ? "cursor-crosshair" : "cursor-pointer"}
      >
        {territory.sideFaces.map((face) => (
          <g key={`side-${cell.id}-${face.edgeIndex}`}>
            <polygon
              points={face.points}
              fill={shadeColorHex(relief.skirtLeft, face.shadeFactor * warmFactor)}
              stroke="#020617"
              strokeWidth={0.65}
              strokeLinejoin="round"
            />
            {face.strataLines.map((line, sIdx) => (
              <line
                key={`strata-${cell.id}-${face.edgeIndex}-${sIdx}`}
                x1={line.x1}
                y1={line.y1}
                x2={line.x2}
                y2={line.y2}
                stroke="#020617"
                strokeOpacity={0.38}
                strokeWidth={0.55}
              />
            ))}
          </g>
        ))}

        <polygon
          points={territory.topPolygonPoints}
          fill={topFill}
          fillOpacity={cell.biome === "ocean" ? 0.92 : 0.96}
          stroke={BIOME_STYLES[cell.biome].stroke}
          strokeOpacity={mapLens === "biome" ? 0.82 : 0.42}
          strokeWidth={1.1}
          strokeLinejoin="round"
        />

        {(territory.isSubmerged || territory.waterZ > territory.topZ) && (
          <g className="pointer-events-none">
            {territory.waterSideFaces.map((wFace) => (
              <polygon
                key={`water-side-${cell.id}-${wFace.edgeIndex}`}
                points={wFace.points}
                fill="#0284c7"
                fillOpacity={0.42}
                stroke="#38bdf8"
                strokeOpacity={0.35}
                strokeWidth={0.5}
              />
            ))}
            <polygon
              points={territory.waterTopPolygonPoints}
              fill={cell.biome === "coastal_shallows" ? "#0d9488" : "#0369a1"}
              fillOpacity={cell.biome === "coastal_shallows" ? 0.34 : 0.54}
              stroke="#38bdf8"
              strokeOpacity={0.65}
              strokeWidth={0.85}
            />
          </g>
        )}

        {cell.biome !== "ocean" && territory.healthState !== "healthy" && (
          <polygon
            points={territory.topPolygonPoints}
            fill="none"
            stroke={territory.healthState === "collapsed" ? "#f87171" : "#fbbf24"}
            strokeWidth={1.6}
            strokeDasharray="4 2"
            opacity={0.85}
            className="pointer-events-none"
          />
        )}

        {cell.biome !== "ocean" && (
          <g className="pointer-events-none">
            <rect
              x={territory.projectedCenter.screenX - 10}
              y={territory.projectedCenter.screenY + HEX_SIZE * 0.36 * scene.camera.zoom}
              width={20}
              height={2.8}
              rx={1.2}
              fill="#020617"
              fillOpacity={0.78}
              stroke="#1e293b"
              strokeWidth={0.5}
            />
            <rect
              x={territory.projectedCenter.screenX - 10}
              y={territory.projectedCenter.screenY + HEX_SIZE * 0.36 * scene.camera.zoom}
              width={Math.max(2, 20 * resourceRatio)}
              height={2.8}
              rx={1.2}
              fill={colorOnScale(FOOD_SCALE, resourceRatio)}
            />
          </g>
        )}

        <g className="pointer-events-none">
          {projectedProps.map((proj) => renderProjectedVoxelBox(proj))}
          {projectedRuins.map((proj) => renderProjectedVoxelBox(proj))}
        </g>

        {residentVillages.map((village) => {
          const projectedBuildings = village.buildings
            .map((b) => projectVoxelBoxFaces(b, scene.camera, world.season, scene.origin))
            .sort((a, b) => a.depthZ - b.depthZ);
          const beaconBottom = projectPoint3D(
            { x: village.worldX, y: village.worldY, z: village.baseZ + 2 },
            scene.camera,
            scene.origin
          );
          const beaconTop = projectPoint3D(
            { x: village.worldX, y: village.worldY, z: village.baseZ + 42 },
            scene.camera,
            scene.origin
          );

          return (
            <g
              key={`village-3d-${village.deme.id}`}
              opacity={village.isDimmedByLineageFilter ? 0.25 : 1}
              onPointerDown={(e) => {
                if (!isPainting) {
                  e.stopPropagation();
                  selectPopulation(village.deme);
                }
              }}
              className={isPainting ? "pointer-events-none" : "cursor-pointer"}
            >
              {highlightedLineageId !== null && village.isHighlightedLineage && (
                <g className="lineage-beacon-pulse pointer-events-none">
                  <line
                    x1={beaconBottom.screenX}
                    y1={beaconBottom.screenY}
                    x2={beaconTop.screenX}
                    y2={beaconTop.screenY}
                    stroke={village.deme.color}
                    strokeWidth={6 * scene.camera.zoom}
                    strokeLinecap="round"
                    opacity={0.32}
                  />
                  <line
                    x1={beaconBottom.screenX}
                    y1={beaconBottom.screenY}
                    x2={beaconTop.screenX}
                    y2={beaconTop.screenY}
                    stroke="#ffffff"
                    strokeWidth={1.8 * scene.camera.zoom}
                    strokeLinecap="round"
                    opacity={0.85}
                  />
                </g>
              )}
              {projectedBuildings.map((proj) => renderProjectedVoxelBox(proj))}
            </g>
          );
        })}
      </g>
    );
  }

  function renderInterVillageStructuresLayer() {
    const allStructureBlocks: Array<{
      proj: ProjectedVoxelBox3D;
      opacity: number;
    }> = [];

    for (const structure of scene.structures) {
      const opacity = structure.status === "disused" ? 0.55 : 0.96;
      for (const block of structure.blocks) {
        allStructureBlocks.push({
          proj: projectVoxelBoxFaces(block, scene.camera, world.season, scene.origin),
          opacity
        });
      }
    }

    allStructureBlocks.sort((a, b) => a.proj.depthZ - b.proj.depthZ);

    return (
      <g className="pointer-events-none">
        {scene.structures.map((structure) => {
          const pStart = projectPoint3D(structure.startPoint, scene.camera, scene.origin);
          const pEnd = projectPoint3D(structure.endPoint, scene.camera, scene.origin);
          return (
            <line
              key={`guide-${structure.id}`}
              x1={pStart.screenX}
              y1={pStart.screenY}
              x2={pEnd.screenX}
              y2={pEnd.screenY}
              stroke={structure.color}
              strokeWidth={structure.kind === "bridge" ? 2.4 : 1.6}
              strokeDasharray={
                structure.status === "disused"
                  ? "3 3"
                  : structure.kind === "expedition"
                    ? "5 3"
                    : undefined
              }
              opacity={structure.status === "disused" ? 0.45 : 0.72}
            />
          );
        })}
        {allStructureBlocks.map(({ proj, opacity }) => (
          <g key={`struct-block-${proj.id}`} opacity={opacity}>
            {renderProjectedVoxelBox(proj)}
          </g>
        ))}
      </g>
    );
  }

  function renderBrushAndSelectionOverlays() {
    return (
      <g className="pointer-events-none">
        {brushPreviewIds.map((hexId) => {
          const territory = scene.territoriesByHexId[hexId];
          if (territory === undefined) {
            return null;
          }
          const previewBox: VoxelBox3D = {
            id: `brush-preview-${hexId}`,
            centerX: territory.baseCenterX,
            centerY: territory.baseCenterY,
            baseZ: territory.topZ,
            widthX: HEX_SIZE * 1.15,
            depthY: HEX_SIZE * 1.15,
            heightZ: 6,
            topColor: "#ffffff",
            leftColor: "#38bdf8",
            rightColor: "#0284c7",
            strokeColor: "#ffffff"
          };
          const proj = projectVoxelBoxFaces(previewBox, scene.camera, world.season, scene.origin);
          return (
            <g key={`preview-3d-${hexId}`} opacity={0.35}>
              <polygon
                points={territory.topPolygonPoints}
                fill="#ffffff"
                fillOpacity={0.22}
                stroke="#ffffff"
                strokeWidth={2}
                strokeDasharray="5 3"
              />
              <polygon
                points={proj.topPolygonPoints}
                fill="none"
                stroke="#38bdf8"
                strokeWidth={1.6}
                strokeDasharray="3 2"
              />
            </g>
          );
        })}

        {selectedHexId !== null && scene.territoriesByHexId[selectedHexId] !== undefined && (
          <polygon
            points={scene.territoriesByHexId[selectedHexId]!.topPolygonPoints}
            fill="none"
            stroke="#f8fafc"
            strokeWidth={2.5}
          />
        )}

        {[...eventHexIds].map((hexId) => {
          const territory = scene.territoriesByHexId[hexId];
          if (territory === undefined) {
            return null;
          }
          return (
            <circle
              key={`event-${hexId}-${world.generation}`}
              cx={territory.projectedCenter.screenX}
              cy={territory.projectedCenter.screenY}
              r={HEX_SIZE * 0.72 * scene.camera.zoom}
              fill="none"
              stroke="#fbbf24"
              strokeWidth={3}
              className="event-pulse"
            />
          );
        })}
      </g>
    );
  }

  function renderOcclusionSafeVillageBillboards() {
    return (
      <g className={isPainting ? "pointer-events-none" : undefined}>
        {scene.villages.map((village) => {
          const { deme, vitalStatus, dominantArchetype, hasCulture, tierRoman, tier } = village;
          const isSelected = deme.id === selectedDemeId;
          const archetypeVisual = DECISION_ARCHETYPE_VISUALS[dominantArchetype];
          const x = village.billboardAnchor.screenX;
          const y = village.billboardAnchor.screenY;

          return (
            <g
              key={`billboard-${deme.id}`}
              transform={`translate(${x}, ${y})`}
              opacity={village.isDimmedByLineageFilter ? 0.24 : 1}
              role="button"
              tabIndex={0}
              aria-label={`${deme.name} (${tierRoman} · ${t(`map.villageTiers.${tier}`)}): ${t("map.individuals", { count: deme.population })} · ${t(`panel.status.${vitalStatus}`)} · ${t(`catalogLab.archetypes.${dominantArchetype}`)}`}
              aria-pressed={isSelected}
              onPointerDown={(e) => {
                e.stopPropagation();
                selectPopulation(deme);
              }}
              onKeyDown={(e) => handleDemeKeyDown(deme, e)}
              className={`${isPainting ? "pointer-events-none" : "cursor-pointer"} outline-none [&:focus-visible>rect:first-of-type]:stroke-white`}
            >
              <line
                x1={0}
                y1={7}
                x2={village.roofAnchor.screenX - x}
                y2={village.roofAnchor.screenY - y}
                stroke={DEME_STATUS_RINGS[vitalStatus]}
                strokeWidth={1.4}
                opacity={0.85}
              />
              {village.isOccludedByFrontTerrain && (
                <rect
                  x={-22}
                  y={-11}
                  width={44}
                  height={20}
                  rx={10}
                  fill="none"
                  stroke="#38bdf8"
                  strokeWidth={1.6}
                  strokeDasharray="2 2"
                />
              )}
              <rect
                x={-20}
                y={-9}
                width={40}
                height={16}
                rx={8}
                fill="#020617"
                fillOpacity={0.92}
                stroke={isSelected ? "#ffffff" : DEME_STATUS_RINGS[vitalStatus]}
                strokeWidth={isSelected ? 2.2 : 1.5}
              />
              <circle cx={-12} cy={-1} r={4.2} fill={deme.color} stroke="#020617" strokeWidth={1} />
              <text
                x={2}
                y={-0.5}
                textAnchor="middle"
                dominantBaseline="central"
                fill="#f8fafc"
                fontSize={7.2}
                fontWeight={800}
                aria-hidden="true"
                className="pointer-events-none select-none font-mono"
              >
                {tierRoman}·{formatPopulation(deme.population)}
              </text>

              {hasCulture && (
                <g transform="translate(-16, -9)" aria-hidden="true" className="pointer-events-none">
                  <circle r={3.8} fill="#2e1065" stroke="#c084fc" strokeWidth={1} />
                  <circle r={1.4} fill="#e9d5ff" />
                </g>
              )}

              <g transform="translate(17, -8)" aria-hidden="true" className="pointer-events-none">
                <circle
                  r={4.8}
                  fill={archetypeVisual.bg}
                  stroke={archetypeVisual.color}
                  strokeWidth={1.1}
                />
                <path
                  d={archetypeVisual.glyphPath}
                  fill="none"
                  stroke={archetypeVisual.color}
                  strokeWidth={1.1}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </g>

              {isSelected && (
                <text
                  x={0}
                  y={-14}
                  textAnchor="middle"
                  fill="#f8fafc"
                  fontSize={9.5}
                  fontWeight={700}
                  stroke="#020617"
                  strokeWidth={3.2}
                  paintOrder="stroke"
                  aria-hidden="true"
                  className="pointer-events-none select-none"
                >
                  {deme.name}
                </text>
              )}
            </g>
          );
        })}
      </g>
    );
  }

  function renderHoverCard() {
    if (hovered === null || hoveredCell === undefined) {
      return null;
    }
    const residentVillages = hoveredCell.demeIds
      .map((id) => scene.villagesByDemeId[id])
      .filter((v): v is VillageSettlement3D => v !== undefined);
    const cellStructures = scene.structures.filter(
      (s) => s.fromHexId === hoveredCell.id || s.toHexId === hoveredCell.id
    );

    return (
      <div
        className="pointer-events-none absolute z-20 rounded-lg border border-slate-700 bg-slate-950/95 px-3 py-2 text-xs text-slate-200 shadow-xl"
        style={{ left: hovered.left, top: hovered.top, width: HOVER_CARD_WIDTH }}
      >
        <div className="flex items-center justify-between gap-2">
          <span className="font-semibold text-slate-100">{t(`biomes.${hoveredCell.biome}`)}</span>
          <span className="font-mono text-[10px] text-slate-400">
            {t("panel.altitude")} {hoveredCell.altitude.toFixed(2)}
          </span>
        </div>
        {hoveredCell.biome !== "ocean" && (
          <div className="mt-1 grid grid-cols-2 gap-x-2 text-slate-400">
            <span>{t("map.food")}</span>
            <span className="text-right font-mono text-slate-200">
              {Math.round(hoveredCell.currentResources)}
            </span>
            <span>{t("map.health")}</span>
            <span className="text-right font-mono text-slate-200">
              {Math.round(habitatHealthRatio(hoveredCell) * 100)}%
            </span>
          </div>
        )}
        <div className="mt-1.5 border-t border-slate-800 pt-1.5 space-y-1">
          {residentVillages.length === 0 ? (
            <span className="text-slate-500">{t("map.uninhabited")}</span>
          ) : (
            residentVillages.map((village) => {
              const { deme, vitalStatus, dominantArchetype, tier, tierRoman } = village;
              const tierVisual = VILLAGE_TIER_VISUALS[tier];
              return (
                <div key={deme.id} className="flex items-center justify-between gap-1.5">
                  <div className="flex min-w-0 items-center gap-1.5">
                    <span
                      className="h-2.5 w-2.5 shrink-0 rounded-full border"
                      style={{
                        backgroundColor: deme.color,
                        borderColor: DEME_STATUS_RINGS[vitalStatus]
                      }}
                    />
                    <span className="truncate font-medium text-slate-100">{deme.name}</span>
                    <span
                      className={`shrink-0 rounded border px-1 py-0.2 font-mono text-[9px] font-bold ${tierVisual.badgeClass}`}
                    >
                      {tierRoman}
                    </span>
                  </div>
                  <span
                    className="shrink-0 text-[10px] font-medium"
                    style={{ color: DECISION_ARCHETYPE_VISUALS[dominantArchetype].color }}
                  >
                    {t(`catalogLab.archetypes.${dominantArchetype}`)}
                  </span>
                </div>
              );
            })
          )}
        </div>
        {cellStructures.length > 0 && (
          <div className="mt-1.5 border-t border-slate-800 pt-1.5">
            <div className="text-[10px] uppercase tracking-wider text-slate-400">
              {t("map.activeInteractions")}
            </div>
            <div className="mt-0.5 flex flex-wrap gap-1">
              {cellStructures.slice(0, 3).map((structure) => {
                const style = INFRASTRUCTURE_3D_STYLES[structure.kind];
                return (
                  <span
                    key={structure.id}
                    className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-medium"
                    style={{
                      backgroundColor: style.sideColor,
                      color: style.accentColor
                    }}
                  >
                    {t(
                      structure.status === "disused"
                        ? "map.infrastructures.disusedRoad"
                        : style.labelKey
                    )}
                  </span>
                );
              })}
            </div>
          </div>
        )}
        {activeBrush.kind !== "inspect" && (
          <div className="mt-1.5 border-t border-slate-800 pt-1.5 text-amber-300">
            {t("tools.costPerClick", { cost: activeBrush.cost })}
          </div>
        )}
      </div>
    );
  }

  return (
    <div
      tabIndex={0}
      onKeyDown={handleCanvasKeyDown}
      onContextMenu={(e) => e.preventDefault()}
      className="relative h-full w-full overflow-hidden bg-slate-950 select-none outline-none"
      onPointerUp={() => {
        setIsPointerDown(false);
        setDragState(null);
      }}
      onPointerLeave={() => {
        setIsPointerDown(false);
        setDragState(null);
        setHovered(null);
      }}
    >
      {highlightedLineageId !== null && world.lineageTree[highlightedLineageId] !== undefined && (
        <div className="absolute top-3 left-3 z-20 flex items-center gap-2 rounded-lg bg-slate-900/95 border border-amber-500/50 px-3 py-1.5 text-xs text-amber-200 shadow-lg">
          <span>{world.lineageTree[highlightedLineageId]!.name}</span>
          <button
            type="button"
            onClick={() => setHighlightedLineageId(null)}
            className="inline-flex items-center gap-1 rounded bg-amber-500/20 px-2 py-0.5 text-amber-100 hover:bg-amber-500/30 cursor-pointer"
          >
            <X className="w-3.5 h-3.5" />
            {t("phyloTree.clearHighlight")}
          </button>
        </div>
      )}

      <div
        role="group"
        aria-label={t("map.label")}
        className="absolute bottom-3 right-3 z-10 flex items-center gap-1 rounded-xl border border-slate-800 bg-slate-900/90 p-1 text-xs text-slate-200 shadow-lg backdrop-blur"
      >
        <button
          type="button"
          aria-label={t("map.rotateLeft")}
          onClick={() => rotateCameraBy(-30)}
          className="rounded-lg p-1.5 text-slate-300 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <RotateCcw className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          aria-label={t("map.rotateRight")}
          onClick={() => rotateCameraBy(30)}
          className="rounded-lg p-1.5 text-slate-300 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <RotateCw className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          aria-label={t("map.tiltView")}
          onClick={cycleCameraTilt}
          className="inline-flex items-center gap-1 rounded-lg px-1.5 py-1 font-mono text-[11px] text-slate-300 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <Eye className="h-3 w-3" />
          {Math.round(scene.camera.pitchDeg)}°
        </button>
        <button
          type="button"
          aria-label={t("map.zoomOut")}
          disabled={scene.camera.zoom <= MIN_ZOOM_3D}
          onClick={() => adjustZoom(scene.camera.zoom - ZOOM_STEP)}
          className="rounded-lg p-1.5 text-slate-300 hover:bg-slate-800 hover:text-white disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
        >
          <Minus className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          aria-label={t("map.resetView")}
          onClick={resetCamera}
          className="inline-flex items-center gap-1 rounded-lg px-2 py-1 font-mono text-[11px] text-slate-300 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <Compass className="h-3 w-3" />
          {Math.round(scene.camera.zoom * 100)}%
        </button>
        <button
          type="button"
          aria-label={t("map.zoomIn")}
          disabled={scene.camera.zoom >= MAX_ZOOM_3D}
          onClick={() => adjustZoom(scene.camera.zoom + ZOOM_STEP)}
          className="rounded-lg p-1.5 text-slate-300 hover:bg-slate-800 hover:text-white disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
        >
          <Plus className="h-3.5 w-3.5" />
        </button>
      </div>

      <svg
        viewBox={`${baseMinX} ${baseMinY} ${baseWidth} ${baseHeight}`}
        aria-label={t("map.label")}
        onWheel={handleWheel}
        onPointerDown={handleSvgPointerDown}
        onPointerMove={handleSvgPointerMove}
        className={`h-full w-full ${
          isPainting ? "cursor-crosshair" : dragState?.moved ? "cursor-grabbing" : "cursor-grab"
        }`}
      >
        <g onPointerLeave={() => setHovered(null)}>
          {scene.territories.map((territory) => renderTerritoryColumn(territory))}
        </g>

        {renderInterVillageStructuresLayer()}
        {renderBrushAndSelectionOverlays()}
        {renderOcclusionSafeVillageBillboards()}
      </svg>

      {renderHoverCard()}
    </div>
  );
}
