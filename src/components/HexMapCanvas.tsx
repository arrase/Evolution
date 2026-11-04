import {
  useEffect,
  useState,
  type KeyboardEvent,
  type PointerEvent,
  type WheelEvent
} from "react";
import { useTranslation } from "react-i18next";
import { Minus, Plus, RotateCcw, X } from "lucide-react";
import {
  computeCellsViewBox,
  computeHex25DGeometry,
  getExistingNeighborCells,
  getHexIdsInRadius,
  HEX_SIZE,
  sortCellsFor25DPainterOrder,
  type Hex25DGeometry
} from "../engine/hexGrid";
import { useSimulationStore, type MapLens } from "../store/useSimulationStore";
import type {
  BiomeType,
  DecisionArchetype,
  Deme,
  HexCell,
  HexEdgeFlow
} from "../types/simulation";
import {
  BIOME_RELIEF_COLORS,
  BIOME_STYLES,
  colorOnScale,
  DECISION_ARCHETYPE_VISUALS,
  DEME_STATUS_RINGS,
  type DemeVitalStatus,
  FLOW_STYLES,
  FOOD_SCALE,
  getDemeStatus,
  habitatHealthRatio,
  HEALTH_SCALE
} from "./palette";

interface HoveredHex {
  hexId: string;
  left: number;
  top: number;
}

interface DemeTokenPosition {
  deme: Deme;
  x: number;
  y: number;
  radius: number;
  vitalStatus: DemeVitalStatus;
  dominantArchetype: DecisionArchetype;
  hasCulture: boolean;
}

interface PanDragState {
  startClientX: number;
  startClientY: number;
  startPanX: number;
  startPanY: number;
  moved: boolean;
}

const HOVER_CARD_WIDTH = 236;
const HOVER_CARD_HEIGHT = 176;
const HOVER_CARD_GAP = 16;
const MIN_ZOOM = 1.0;
const MAX_ZOOM = 2.75;
const ZOOM_STEP = 0.35;

const DEME_OFFSETS: Record<number, Array<{ dx: number; dy: number }>> = {
  1: [{ dx: 0, dy: -2 }],
  2: [
    { dx: -15, dy: -2 },
    { dx: 15, dy: -2 }
  ],
  3: [
    { dx: -15, dy: 6 },
    { dx: 15, dy: 6 },
    { dx: 0, dy: -15 }
  ]
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function computeDemeRadius(population: number, cohabitingCount: number): number {
  if (cohabitingCount >= 3) {
    return clamp(Math.log10(population) * 4.5, 8.2, 10.2);
  }
  if (cohabitingCount === 2) {
    return clamp(Math.log10(population) * 5.2, 8.6, 11.5);
  }
  return clamp(Math.log10(population) * 6, 9, 13.8);
}

function formatPopulation(population: number): string {
  return population >= 1000 ? `${(population / 1000).toFixed(1)}k` : String(population);
}

function computeCellFill(cell: HexCell, lens: MapLens): string {
  if (lens === "biome" || cell.biome === "ocean") {
    return `url(#biome-grad-${cell.biome})`;
  }
  if (lens === "food") {
    return colorOnScale(FOOD_SCALE, cell.currentResources / cell.carryingCapacityMax);
  }
  return colorOnScale(HEALTH_SCALE, habitatHealthRatio(cell));
}

function renderBiomeMotif(biome: BiomeType, centerX: number, topCenterY: number) {
  const stroke = BIOME_RELIEF_COLORS[biome].motifStroke;
  switch (biome) {
    case "tropical_forest":
      return (
        <g
          transform={`translate(${centerX}, ${topCenterY})`}
          fill="none"
          stroke={stroke}
          strokeWidth={1.3}
          strokeLinecap="round"
          strokeLinejoin="round"
          opacity={0.38}
          className="pointer-events-none"
        >
          <path d="M -11 4 C -15 0 -9 -7 -5 -2 C -2 -8 6 -7 7 -1 C 12 -4 15 2 10 5 Z" />
          <path d="M -6 4 L -6 9 M 4 4 L 4 9" />
        </g>
      );
    case "savanna":
      return (
        <g
          transform={`translate(${centerX}, ${topCenterY})`}
          fill="none"
          stroke={stroke}
          strokeWidth={1.3}
          strokeLinecap="round"
          strokeLinejoin="round"
          opacity={0.38}
          className="pointer-events-none"
        >
          <path d="M -12 -3 L 10 -3 C 7 -7 -7 -7 -12 -3 Z" />
          <path d="M -1 -3 L -2 7 M -1 -3 L -6 0 M -1 -3 L 4 0" />
          <path d="M -13 7 L -11 4 M 9 7 L 11 4 L 13 7" />
        </g>
      );
    case "arid_steppe":
      return (
        <g
          transform={`translate(${centerX}, ${topCenterY})`}
          fill="none"
          stroke={stroke}
          strokeWidth={1.3}
          strokeLinecap="round"
          opacity={0.38}
          className="pointer-events-none"
        >
          <path d="M -16 2 Q -7 -5 2 2 T 16 1" />
          <path d="M -12 8 Q -3 3 8 8" />
        </g>
      );
    case "tundra":
      return (
        <g
          transform={`translate(${centerX}, ${topCenterY})`}
          fill="none"
          stroke={stroke}
          strokeWidth={1.2}
          strokeLinecap="round"
          opacity={0.4}
          className="pointer-events-none"
        >
          <path d="M 0 -7 L 0 7 M -6 -3.5 L 6 3.5 M -6 3.5 L 6 -3.5" />
          <path d="M -14 7 L 14 7" />
        </g>
      );
    case "high_mountain":
      return (
        <g
          transform={`translate(${centerX}, ${topCenterY})`}
          fill="none"
          stroke={stroke}
          strokeWidth={1.4}
          strokeLinecap="round"
          strokeLinejoin="round"
          opacity={0.5}
          className="pointer-events-none"
        >
          <path d="M -15 8 L -5 -8 L 4 8" />
          <path d="M -1 8 L 7 -5 L 15 8" />
          <path d="M -8 -3 L -5 -8 L -2 -3 M 5 -1.5 L 7 -5 L 9 -1.5" />
        </g>
      );
    case "coastal_shallows":
      return (
        <g
          transform={`translate(${centerX}, ${topCenterY})`}
          fill="none"
          stroke={stroke}
          strokeWidth={1.2}
          strokeLinecap="round"
          opacity={0.36}
          className="pointer-events-none"
        >
          <path d="M -14 -2 Q -7 -5 0 -2 T 14 -2" />
          <path d="M -10 4 Q -3 1 4 4 T 12 4" />
        </g>
      );
    case "ocean":
      return (
        <g
          transform={`translate(${centerX}, ${topCenterY})`}
          fill="none"
          stroke={stroke}
          strokeWidth={1.1}
          strokeLinecap="round"
          opacity={0.25}
          className="pointer-events-none"
        >
          <path d="M -15 -3 Q -8 -7 0 -3 T 15 -3" />
          <path d="M -12 4 Q -5 0 3 4 T 13 4" />
        </g>
      );
  }
}

export function HexMapCanvas() {
  const { t } = useTranslation();
  const world = useSimulationStore((s) => s.world);
  const mapLens = useSimulationStore((s) => s.mapLens);
  const selectedHexId = useSimulationStore((s) => s.selectedHexId);
  const selectedDemeId = useSimulationStore((s) => s.selectedDemeId);
  const activeBrush = useSimulationStore((s) => s.activeBrush);
  const highlightedLineageId = useSimulationStore((s) => s.highlightedLineageId);
  const selectHex = useSimulationStore((s) => s.selectHex);
  const selectDeme = useSimulationStore((s) => s.selectDeme);
  const applyBrushToHex = useSimulationStore((s) => s.applyBrushToHex);
  const setHighlightedLineageId = useSimulationStore((s) => s.setHighlightedLineageId);

  const [isPointerDown, setIsPointerDown] = useState(false);
  const [hovered, setHovered] = useState<HoveredHex | null>(null);
  const [zoom, setZoom] = useState(1.0);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [panDrag, setPanDrag] = useState<PanDragState | null>(null);

  useEffect(() => {
    setZoom(MIN_ZOOM);
    setPan({ x: 0, y: 0 });
    setHovered(null);
  }, [world.presetId]);

  const cellList = sortCellsFor25DPainterOrder(Object.values(world.cells));
  const baseViewBox = computeCellsViewBox(cellList, HEX_SIZE * 2.3);
  const [baseMinX, baseMinY, baseWidth, baseHeight] = baseViewBox.split(" ").map(Number) as [
    number,
    number,
    number,
    number
  ];

  const zoomedWidth = baseWidth / zoom;
  const zoomedHeight = baseHeight / zoom;
  const maxPanX = (baseWidth - zoomedWidth) * 0.65;
  const maxPanY = (baseHeight - zoomedHeight) * 0.65;
  const clampedPanX = clamp(pan.x, -maxPanX, maxPanX);
  const clampedPanY = clamp(pan.y, -maxPanY, maxPanY);
  const activeMinX = baseMinX + (baseWidth - zoomedWidth) / 2 + clampedPanX;
  const activeMinY = baseMinY + (baseHeight - zoomedHeight) / 2 + clampedPanY;
  const activeViewBox = `${activeMinX} ${activeMinY} ${zoomedWidth} ${zoomedHeight}`;

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

  const cellGeometries: Record<string, Hex25DGeometry> = {};
  const demePositions: Record<string, DemeTokenPosition> = {};

  for (const cell of cellList) {
    const geom = computeHex25DGeometry(cell.q, cell.r, cell.altitude, cell.biome === "ocean");
    cellGeometries[cell.id] = geom;

    const presentDemes = cell.demeIds
      .map((id) => world.demes[id])
      .filter((d): d is Deme => d !== undefined);
    const offsets = DEME_OFFSETS[presentDemes.length];

    if (offsets !== undefined) {
      presentDemes.forEach((deme, index) => {
        const offset = offsets[index]!;
        const dominantDecision = world.decisionsCatalog[deme.lastDominantDecisionId];
        const dominantArchetype: DecisionArchetype =
          dominantDecision !== undefined ? dominantDecision.archetype : "forage";

        demePositions[deme.id] = {
          deme,
          x: geom.centerX + offset.dx,
          y: geom.topCenterY + offset.dy,
          radius: computeDemeRadius(deme.population, presentDemes.length),
          vitalStatus: getDemeStatus(deme),
          dominantArchetype,
          hasCulture: deme.culturalTraitIds.length > 0
        };
      });
    }
  }

  function resolveDominantArchetype(deme: Deme): DecisionArchetype {
    const pos = demePositions[deme.id];
    if (pos !== undefined) {
      return pos.dominantArchetype;
    }
    const decision = world.decisionsCatalog[deme.lastDominantDecisionId];
    return decision !== undefined ? decision.archetype : "forage";
  }

  function adjustZoom(nextZoom: number) {
    const clampedZoom = Number(clamp(nextZoom, MIN_ZOOM, MAX_ZOOM).toFixed(2));
    setZoom(clampedZoom);
    if (clampedZoom <= MIN_ZOOM) {
      setPan({ x: 0, y: 0 });
    }
  }

  function resetCamera() {
    setZoom(MIN_ZOOM);
    setPan({ x: 0, y: 0 });
  }

  function handleWheel(event: WheelEvent<SVGSVGElement>) {
    event.preventDefault();
    const delta = event.deltaY < 0 ? ZOOM_STEP : -ZOOM_STEP;
    adjustZoom(zoom + delta);
  }

  function handleSvgPointerDown(event: PointerEvent<SVGSVGElement>) {
    if (isPainting) {
      return;
    }
    setPanDrag({
      startClientX: event.clientX,
      startClientY: event.clientY,
      startPanX: clampedPanX,
      startPanY: clampedPanY,
      moved: false
    });
  }

  function handleSvgPointerMove(event: PointerEvent<SVGSVGElement>) {
    if (panDrag === null || isPainting) {
      return;
    }
    const dxPx = event.clientX - panDrag.startClientX;
    const dyPx = event.clientY - panDrag.startClientY;
    if (Math.hypot(dxPx, dyPx) < 5 && !panDrag.moved) {
      return;
    }
    const svgBounds = event.currentTarget.getBoundingClientRect();
    const scaleX = zoomedWidth / Math.max(1, svgBounds.width);
    const scaleY = zoomedHeight / Math.max(1, svgBounds.height);

    setPanDrag({ ...panDrag, moved: true });
    setPan({
      x: clamp(panDrag.startPanX - dxPx * scaleX, -maxPanX, maxPanX),
      y: clamp(panDrag.startPanY - dyPx * scaleY, -maxPanY, maxPanY)
    });
  }

  function handleHexPointerDown(hexId: string) {
    setIsPointerDown(true);
    if (isPainting) {
      applyBrushToHex(hexId);
      selectHex(hexId);
    }
  }

  function handleHexClick(hexId: string) {
    if (panDrag !== null && panDrag.moved) {
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

  function renderCoastalShorelines(cell: HexCell, geom: Hex25DGeometry) {
    if (cell.biome === "ocean") {
      return null;
    }
    const oceanNeighbors = getExistingNeighborCells(cell, world.cells).filter(
      (neighbor) => neighbor.biome === "ocean"
    );
    if (oceanNeighbors.length === 0) {
      return null;
    }

    return (
      <g className="pointer-events-none">
        {oceanNeighbors.map((oceanCell) => {
          const oceanGeom = cellGeometries[oceanCell.id];
          if (oceanGeom === undefined) {
            return null;
          }
          const dx = oceanGeom.centerX - geom.centerX;
          const dy = oceanGeom.centerY - geom.centerY;
          const rankedCorners = [...geom.topCorners].sort((a, b) => {
            const dotA = (a.x - geom.centerX) * dx + (a.y - geom.topCenterY) * dy;
            const dotB = (b.x - geom.centerX) * dx + (b.y - geom.topCenterY) * dy;
            return dotB - dotA;
          });
          const c1 = rankedCorners[0]!;
          const c2 = rankedCorners[1]!;
          return (
            <line
              key={`coast-${cell.id}-${oceanCell.id}`}
              x1={c1.x}
              y1={c1.y}
              x2={c2.x}
              y2={c2.y}
              stroke="#38bdf8"
              strokeWidth={2.2}
              strokeLinecap="round"
              opacity={0.82}
            />
          );
        })}
      </g>
    );
  }

  function renderEcologicalOverlay(cell: HexCell, geom: Hex25DGeometry) {
    if (cell.biome === "ocean") {
      return null;
    }
    const resourceRatio = clamp(cell.currentResources / cell.carryingCapacityMax, 0, 1);
    const healthRatio = habitatHealthRatio(cell);
    const isDegraded = healthRatio < 0.85;
    const barWidth = 22;
    const barHeight = 3;
    const barX = geom.centerX - barWidth / 2;
    const barY = geom.topCenterY + HEX_SIZE * 0.56;

    return (
      <g className="pointer-events-none">
        {isDegraded && (
          <polygon
            points={geom.topPolygonPoints}
            fill="none"
            stroke={healthRatio < 0.6 ? "#f87171" : "#fbbf24"}
            strokeWidth={1.8}
            strokeDasharray="4 2"
            opacity={0.85}
          />
        )}
        <rect
          x={barX}
          y={barY}
          width={barWidth}
          height={barHeight}
          rx={1.5}
          fill="#020617"
          fillOpacity={0.75}
          stroke="#1e293b"
          strokeWidth={0.6}
        />
        <rect
          x={barX}
          y={barY}
          width={Math.max(2, barWidth * resourceRatio)}
          height={barHeight}
          rx={1.5}
          fill={colorOnScale(FOOD_SCALE, resourceRatio)}
        />
      </g>
    );
  }

  function renderCellDemes(cell: HexCell) {
    const geom = cellGeometries[cell.id]!;
    const presentPositions = cell.demeIds
      .map((id) => demePositions[id])
      .filter((pos): pos is DemeTokenPosition => pos !== undefined)
      .sort(
        (a, b) =>
          Number(a.deme.id === selectedDemeId) - Number(b.deme.id === selectedDemeId)
      );
    const selectedPos = presentPositions.find((pos) => pos.deme.id === selectedDemeId);
    const labelY =
      presentPositions.length > 0
        ? Math.min(...presentPositions.map((pos) => pos.y - pos.radius)) - 10
        : geom.topCenterY - 24;

    return (
      <>
        {presentPositions.map((pos) => {
          const { deme, x, y, radius, vitalStatus, dominantArchetype, hasCulture } = pos;
          const isSelected = deme.id === selectedDemeId;
          const isDimmed =
            highlightedLineageId !== null && deme.lineageId !== highlightedLineageId;
          const archetypeVisual = DECISION_ARCHETYPE_VISUALS[dominantArchetype];
          const badgeX = radius * 0.74;
          const badgeY = -radius * 0.74;

          return (
            <g
              key={deme.id}
              transform={`translate(${x}, ${y})`}
              opacity={isDimmed ? 0.22 : 1}
              role="button"
              tabIndex={0}
              aria-label={`${deme.name}: ${t("map.individuals", { count: deme.population })} · ${t(`panel.status.${vitalStatus}`)} · ${t(`catalogLab.archetypes.${dominantArchetype}`)}`}
              aria-pressed={isSelected}
              onPointerDown={(e) => {
                e.stopPropagation();
                selectPopulation(deme);
              }}
              onKeyDown={(e) => handleDemeKeyDown(deme, e)}
              className={`${isPainting ? "pointer-events-none" : "cursor-pointer"} outline-none [&:focus-visible>circle:first-of-type]:stroke-white`}
            >
              <circle
                r={radius + 4.2}
                fill="none"
                stroke={isSelected ? "#ffffff" : "transparent"}
                strokeWidth={2.2}
              />
              <circle
                r={radius + 2.0}
                fill="#020617"
                stroke={DEME_STATUS_RINGS[vitalStatus]}
                strokeWidth={1.9}
              />
              <circle r={radius} fill={deme.color} stroke="#020617" strokeWidth={1.5} />
              <text
                textAnchor="middle"
                dominantBaseline="central"
                fill="#020617"
                fontSize={radius > 11 ? 8 : 6.5}
                fontWeight={800}
                aria-hidden="true"
                className="pointer-events-none select-none"
              >
                {formatPopulation(deme.population)}
              </text>

              {hasCulture && (
                <g transform={`translate(${-badgeX}, ${badgeY})`} aria-hidden="true" className="pointer-events-none">
                  <circle r={4.4} fill="#2e1065" stroke="#c084fc" strokeWidth={1.1} />
                  <circle r={1.7} fill="#e9d5ff" />
                </g>
              )}

              <g transform={`translate(${badgeX}, ${badgeY})`} aria-hidden="true" className="pointer-events-none">
                <circle
                  r={5.2}
                  fill={archetypeVisual.bg}
                  stroke={archetypeVisual.color}
                  strokeWidth={1.2}
                />
                <path
                  d={archetypeVisual.glyphPath}
                  fill="none"
                  stroke={archetypeVisual.color}
                  strokeWidth={1.2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </g>
            </g>
          );
        })}

        {selectedPos !== undefined && (
          <text
            x={presentPositions.length > 1 ? geom.centerX : selectedPos.x}
            y={labelY}
            textAnchor="middle"
            fill="#f8fafc"
            fontSize={10}
            fontWeight={700}
            stroke="#020617"
            strokeWidth={3.5}
            paintOrder="stroke"
            aria-hidden="true"
            className="pointer-events-none select-none"
          >
            {selectedPos.deme.name}
          </text>
        )}
      </>
    );
  }

  function resolveFlowEndpoints(flow: HexEdgeFlow): {
    x1: number;
    y1: number;
    x2: number;
    y2: number;
    isIntraHex: boolean;
  } | null {
    const sourceGeom = cellGeometries[flow.fromHexId];
    const targetGeom = cellGeometries[flow.toHexId];
    if (sourceGeom === undefined || targetGeom === undefined) {
      return null;
    }

    const sourceDemePos = demePositions[flow.demeId];
    const x1 = sourceDemePos !== undefined ? sourceDemePos.x : sourceGeom.centerX;
    const y1 = sourceDemePos !== undefined ? sourceDemePos.y : sourceGeom.topCenterY;

    let targetDemePos =
      flow.targetDemeId !== undefined ? demePositions[flow.targetDemeId] : undefined;

    if (targetDemePos === undefined) {
      const targetCell = world.cells[flow.toHexId];
      if (targetCell !== undefined) {
        const fallbackId = targetCell.demeIds.find((id) => id !== flow.demeId);
        if (fallbackId !== undefined) {
          targetDemePos = demePositions[fallbackId];
        }
      }
    }

    const x2 = targetDemePos !== undefined ? targetDemePos.x : targetGeom.centerX;
    const y2 = targetDemePos !== undefined ? targetDemePos.y : targetGeom.topCenterY;

    return {
      x1,
      y1,
      x2,
      y2,
      isIntraHex: flow.fromHexId === flow.toHexId
    };
  }

  function renderFlowVector(flow: HexEdgeFlow, index: number) {
    const endpoints = resolveFlowEndpoints(flow);
    if (endpoints === null) {
      return null;
    }
    const { x1, y1, x2, y2, isIntraHex } = endpoints;
    const style = FLOW_STYLES[flow.type];
    const strokeWidth = 1.8 + flow.intensity * 2.0;

    const dx = x2 - x1;
    const dy = y2 - y1;
    const dist = Math.hypot(dx, dy);

    if (dist < 2) {
      const loopY = y1 - 16;
      const pathD = `M ${x1 - 7} ${y1 - 4} Q ${x1} ${loopY - 10} ${x1 + 7} ${y1 - 4}`;
      return (
        <g key={`${flow.demeId}-${flow.type}-${index}`} className="pointer-events-none">
          <path d={pathD} fill="none" stroke="#020617" strokeWidth={strokeWidth + 2} opacity={0.75} />
          <path
            d={pathD}
            fill="none"
            stroke={style.stroke}
            strokeWidth={strokeWidth}
            strokeDasharray={style.dash}
            className="flow-arc-animated"
          />
          <g transform={`translate(${x1}, ${loopY - 3})`}>
            <circle r={4.8} fill={style.bg} stroke={style.stroke} strokeWidth={1.1} />
            <path
              d={style.glyphPath}
              fill="none"
              stroke={style.stroke}
              strokeWidth={1.2}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </g>
        </g>
      );
    }

    const ux = dx / dist;
    const uy = dy / dist;
    const nx = -uy;
    const ny = ux;
    const startTrim = isIntraHex ? 9 : 11;
    const endTrim = isIntraHex ? 10 : 13;
    const sx = x1 + ux * Math.min(startTrim, dist * 0.28);
    const sy = y1 + uy * Math.min(startTrim, dist * 0.28);
    const ex = x2 - ux * Math.min(endTrim, dist * 0.28);
    const ey = y2 - uy * Math.min(endTrim, dist * 0.28);

    const curveMagnitude = isIntraHex ? 12 + (index % 2) * 5 : Math.min(22, dist * 0.22);
    const cx = (sx + ex) / 2 + nx * curveMagnitude;
    const cy = (sy + ey) / 2 + ny * curveMagnitude;

    const midX = 0.25 * sx + 0.5 * cx + 0.25 * ex;
    const midY = 0.25 * sy + 0.5 * cy + 0.25 * ey;
    const pathD = `M ${sx} ${sy} Q ${cx} ${cy} ${ex} ${ey}`;

    return (
      <g
        key={`${flow.demeId}-${flow.fromHexId}-${flow.toHexId}-${index}`}
        className="pointer-events-none"
      >
        <path
          d={pathD}
          fill="none"
          stroke="#020617"
          strokeWidth={strokeWidth + 2}
          strokeLinecap="round"
          opacity={0.7}
        />
        <path
          d={pathD}
          fill="none"
          stroke={style.stroke}
          strokeWidth={strokeWidth}
          strokeDasharray={style.dash}
          markerEnd={`url(#flow-arrow-${flow.type})`}
          opacity={0.95}
          className="flow-arc-animated"
        />
        <g transform={`translate(${midX}, ${midY})`}>
          <circle r={4.8} fill={style.bg} stroke={style.stroke} strokeWidth={1.1} />
          <path
            d={style.glyphPath}
            fill="none"
            stroke={style.stroke}
            strokeWidth={1.2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </g>
      </g>
    );
  }

  function renderHoverCard() {
    if (hovered === null || hoveredCell === undefined) {
      return null;
    }
    const residents = hoveredCell.demeIds
      .map((id) => world.demes[id])
      .filter((d): d is Deme => d !== undefined);
    const cellFlows = world.currentTurnFlows.filter(
      (flow) => flow.fromHexId === hoveredCell.id || flow.toHexId === hoveredCell.id
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
          {residents.length === 0 ? (
            <span className="text-slate-500">{t("map.uninhabited")}</span>
          ) : (
            residents.map((deme) => {
              const status = getDemeStatus(deme);
              const archetype = resolveDominantArchetype(deme);
              return (
                <div key={deme.id} className="flex items-center justify-between gap-1.5">
                  <div className="flex min-w-0 items-center gap-1.5">
                    <span
                      className="h-2.5 w-2.5 shrink-0 rounded-full border"
                      style={{
                        backgroundColor: deme.color,
                        borderColor: DEME_STATUS_RINGS[status]
                      }}
                    />
                    <span className="truncate font-medium text-slate-100">{deme.name}</span>
                  </div>
                  <span
                    className="shrink-0 text-[10px] font-medium"
                    style={{ color: DECISION_ARCHETYPE_VISUALS[archetype].color }}
                  >
                    {t(`catalogLab.archetypes.${archetype}`)}
                  </span>
                </div>
              );
            })
          )}
        </div>
        {cellFlows.length > 0 && (
          <div className="mt-1.5 border-t border-slate-800 pt-1.5">
            <div className="text-[10px] uppercase tracking-wider text-slate-400">
              {t("map.activeInteractions")}
            </div>
            <div className="mt-0.5 flex flex-wrap gap-1">
              {cellFlows.slice(0, 3).map((flow, idx) => (
                <span
                  key={`${flow.demeId}-${flow.type}-${idx}`}
                  className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-medium"
                  style={{
                    backgroundColor: FLOW_STYLES[flow.type].bg,
                    color: FLOW_STYLES[flow.type].stroke
                  }}
                >
                  {t(`map.flows.${flow.type}`)}
                </span>
              ))}
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
      className="relative h-full w-full overflow-hidden bg-slate-950 select-none"
      onPointerUp={() => {
        setIsPointerDown(false);
        setPanDrag(null);
      }}
      onPointerLeave={() => {
        setIsPointerDown(false);
        setPanDrag(null);
        setHovered(null);
      }}
    >
      {highlightedLineageId !== null && (
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
          aria-label={t("map.zoomOut")}
          disabled={zoom <= MIN_ZOOM}
          onClick={() => adjustZoom(zoom - ZOOM_STEP)}
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
          <RotateCcw className="h-3 w-3" />
          {Math.round(zoom * 100)}%
        </button>
        <button
          type="button"
          aria-label={t("map.zoomIn")}
          disabled={zoom >= MAX_ZOOM}
          onClick={() => adjustZoom(zoom + ZOOM_STEP)}
          className="rounded-lg p-1.5 text-slate-300 hover:bg-slate-800 hover:text-white disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
        >
          <Plus className="h-3.5 w-3.5" />
        </button>
      </div>

      <svg
        viewBox={activeViewBox}
        aria-label={t("map.label")}
        onWheel={handleWheel}
        onPointerDown={handleSvgPointerDown}
        onPointerMove={handleSvgPointerMove}
        className={`h-full w-full ${
          isPainting ? "cursor-crosshair" : panDrag?.moved ? "cursor-grabbing" : "cursor-grab"
        }`}
      >
        <defs>
          {(
            [
              "tropical_forest",
              "savanna",
              "arid_steppe",
              "tundra",
              "high_mountain",
              "coastal_shallows",
              "ocean"
            ] as const
          ).map((biome) => (
            <radialGradient key={biome} id={`biome-grad-${biome}`} cx="38%" cy="32%" r="72%">
              <stop offset="0%" stopColor={BIOME_RELIEF_COLORS[biome].topHighlight} />
              <stop offset="100%" stopColor={BIOME_STYLES[biome].fill} />
            </radialGradient>
          ))}
          {(["migration", "exchange", "dispute"] as const).map((flowType) => (
            <marker
              key={flowType}
              id={`flow-arrow-${flowType}`}
              viewBox="0 0 10 10"
              refX="7"
              refY="5"
              markerWidth="4.5"
              markerHeight="4.5"
              orient="auto-start-reverse"
            >
              <path d="M 0 1 L 10 5 L 0 9 z" fill={FLOW_STYLES[flowType].stroke} />
            </marker>
          ))}
        </defs>

        <g onPointerLeave={() => setHovered(null)}>
          {cellList.map((cell) => {
            const geom = cellGeometries[cell.id]!;
            const relief = BIOME_RELIEF_COLORS[cell.biome];
            return (
              <g
                key={cell.id}
                onPointerDown={() => handleHexPointerDown(cell.id)}
                onClick={() => handleHexClick(cell.id)}
                onPointerEnter={(e) => handleHexPointerEnter(cell.id, e)}
                className={isPainting ? "cursor-crosshair" : "cursor-pointer"}
              >
                {geom.elevationPx > 0 && (
                  <>
                    <polygon
                      points={geom.leftSkirtPoints}
                      fill={relief.skirtLeft}
                      stroke="#020617"
                      strokeWidth={0.7}
                    />
                    <polygon
                      points={geom.rightSkirtPoints}
                      fill={relief.skirtRight}
                      stroke="#020617"
                      strokeWidth={0.7}
                    />
                  </>
                )}
                <polygon
                  points={geom.topPolygonPoints}
                  fill={computeCellFill(cell, mapLens)}
                  fillOpacity={0.86 + cell.altitude * 0.14}
                  stroke={BIOME_STYLES[cell.biome].stroke}
                  strokeOpacity={mapLens === "biome" ? 0.78 : 0.35}
                  strokeWidth={1.15}
                />
                {mapLens === "biome" && renderBiomeMotif(cell.biome, geom.centerX, geom.topCenterY)}
                {renderCoastalShorelines(cell, geom)}
                {renderEcologicalOverlay(cell, geom)}
              </g>
            );
          })}
        </g>

        <g className="pointer-events-none">
          {brushPreviewIds.map((hexId) => {
            const geom = cellGeometries[hexId]!;
            return (
              <polygon
                key={`preview-${hexId}`}
                points={geom.topPolygonPoints}
                fill="#ffffff"
                fillOpacity={0.14}
                stroke="#ffffff"
                strokeWidth={2}
                strokeDasharray="5 3"
              />
            );
          })}
          {selectedHexId !== null && cellGeometries[selectedHexId] !== undefined && (
            <polygon
              points={cellGeometries[selectedHexId]!.topPolygonPoints}
              fill="none"
              stroke="#f8fafc"
              strokeWidth={2.6}
            />
          )}
          {[...eventHexIds].map((hexId) => {
            const geom = cellGeometries[hexId];
            if (geom === undefined) {
              return null;
            }
            return (
              <circle
                key={`event-${hexId}-${world.generation}`}
                cx={geom.centerX}
                cy={geom.topCenterY}
                r={HEX_SIZE * 0.8}
                fill="none"
                stroke="#fbbf24"
                strokeWidth={3}
                className="event-pulse"
              />
            );
          })}
        </g>

        <g>{world.currentTurnFlows.map((flow, index) => renderFlowVector(flow, index))}</g>

        <g className={isPainting ? "pointer-events-none" : undefined}>
          {cellList.map((cell) => (
            <g key={`demes-${cell.id}`}>{renderCellDemes(cell)}</g>
          ))}
        </g>
      </svg>

      {renderHoverCard()}
    </div>
  );
}
