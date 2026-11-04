import { useState, type KeyboardEvent, type PointerEvent } from "react";
import { useTranslation } from "react-i18next";
import { X } from "lucide-react";
import {
  computeCellsViewBox,
  computeHexPixelGeometry,
  getHexIdsInRadius,
  HEX_SIZE
} from "../engine/hexGrid";
import { useSimulationStore, type MapLens } from "../store/useSimulationStore";
import type { Deme, HexCell, HexEdgeFlow } from "../types/simulation";
import {
  BIOME_STYLES,
  colorOnScale,
  FLOW_STYLES,
  FOOD_SCALE,
  habitatHealthRatio,
  HEALTH_SCALE
} from "./palette";

interface HoveredHex {
  hexId: string;
  left: number;
  top: number;
}

const HOVER_CARD_WIDTH = 208;
const HOVER_CARD_HEIGHT = 150;
const HOVER_CARD_GAP = 16;

const DEME_OFFSETS: Record<number, Array<{ dx: number; dy: number }>> = {
  1: [{ dx: 0, dy: 0 }],
  2: [
    { dx: -14, dy: 0 },
    { dx: 14, dy: 0 }
  ],
  3: [
    { dx: -14, dy: 8 },
    { dx: 14, dy: 8 },
    { dx: 0, dy: -14 }
  ]
};

function computeDemeRadius(population: number): number {
  return Math.max(9, Math.min(14, Math.log10(population) * 6));
}

function formatPopulation(population: number): string {
  return population >= 1000 ? `${(population / 1000).toFixed(1)}k` : String(population);
}

function computeCellFill(cell: HexCell, lens: MapLens): string {
  if (lens === "biome" || cell.biome === "ocean") {
    return BIOME_STYLES[cell.biome].fill;
  }
  if (lens === "food") {
    return colorOnScale(FOOD_SCALE, cell.currentResources / cell.carryingCapacityMax);
  }
  return colorOnScale(HEALTH_SCALE, habitatHealthRatio(cell));
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

  const cellList = Object.values(world.cells);
  const viewBox = computeCellsViewBox(cellList, HEX_SIZE * 2.2);
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

  function cellGeometry(hexId: string) {
    const cell = world.cells[hexId]!;
    return computeHexPixelGeometry(cell.q, cell.r);
  }

  function handleHexPointerDown(hexId: string) {
    setIsPointerDown(true);
    if (isPainting) {
      applyBrushToHex(hexId);
    }
    selectHex(hexId);
  }

  function handleHexPointerEnter(hexId: string, event: PointerEvent<SVGGElement>) {
    const bounds = event.currentTarget.ownerSVGElement!.getBoundingClientRect();
    const x = event.clientX - bounds.left;
    const y = event.clientY - bounds.top;
    setHovered({
      hexId,
      left: x + HOVER_CARD_GAP + HOVER_CARD_WIDTH > bounds.width ? x - HOVER_CARD_GAP - HOVER_CARD_WIDTH : x + HOVER_CARD_GAP,
      top: y + HOVER_CARD_GAP + HOVER_CARD_HEIGHT > bounds.height ? y - HOVER_CARD_GAP - HOVER_CARD_HEIGHT : y + HOVER_CARD_GAP
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

  function renderCellDemes(cell: HexCell, centerX: number, centerY: number) {
    const presentDemes = cell.demeIds.map((id) => world.demes[id]).filter((d): d is Deme => d !== undefined);
    const orderedDemes = presentDemes
      .map((deme, index) => ({ deme, offset: DEME_OFFSETS[presentDemes.length]![index]! }))
      .sort((a, b) => Number(a.deme.id === selectedDemeId) - Number(b.deme.id === selectedDemeId));

    return orderedDemes.map(({ deme, offset }) => {
      const radius = computeDemeRadius(deme.population);
      const isSelected = deme.id === selectedDemeId;
      const isDimmed = highlightedLineageId !== null && deme.lineageId !== highlightedLineageId;

      return (
        <g
          key={deme.id}
          transform={`translate(${centerX + offset.dx}, ${centerY + offset.dy})`}
          opacity={isDimmed ? 0.22 : 1}
          role="button"
          tabIndex={0}
          aria-label={`${deme.name}: ${t("map.individuals", { count: deme.population })}`}
          aria-pressed={isSelected}
          onPointerDown={(e) => {
            e.stopPropagation();
            selectPopulation(deme);
          }}
          onKeyDown={(e) => handleDemeKeyDown(deme, e)}
          className={`${isPainting ? "pointer-events-none" : "cursor-pointer"} outline-none [&:focus-visible>circle:first-of-type]:stroke-white`}
        >
          <circle r={radius + 4} fill="none" stroke={isSelected ? "#ffffff" : "transparent"} strokeWidth={2.5} />
          <circle r={radius} fill={deme.color} stroke="#020617" strokeWidth={2} />
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
          {isSelected && (
            <text
              y={-radius - 9}
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
              {deme.name}
            </text>
          )}
        </g>
      );
    });
  }

  function renderFlowVector(flow: HexEdgeFlow, index: number) {
    const source = world.cells[flow.fromHexId];
    const target = world.cells[flow.toHexId];
    if (source === undefined || target === undefined) {
      return null;
    }
    const sourceGeom = computeHexPixelGeometry(source.q, source.r);
    const targetGeom = computeHexPixelGeometry(target.q, target.r);
    const style = FLOW_STYLES[flow.type];
    const strokeWidth = 1.6 + flow.intensity * 2.2;

    if (flow.fromHexId === flow.toHexId) {
      return (
        <circle
          key={`${flow.demeId}-${flow.type}-${index}`}
          cx={sourceGeom.centerX}
          cy={sourceGeom.centerY}
          r={HEX_SIZE * 0.62}
          fill="none"
          stroke={style.stroke}
          strokeWidth={strokeWidth}
          strokeDasharray={style.dash}
          opacity={0.9}
          className="pointer-events-none"
        />
      );
    }

    const dx = targetGeom.centerX - sourceGeom.centerX;
    const dy = targetGeom.centerY - sourceGeom.centerY;
    const len = Math.hypot(dx, dy);
    const ux = dx / len;
    const uy = dy / len;

    return (
      <line
        key={`${flow.demeId}-${flow.fromHexId}-${flow.toHexId}-${index}`}
        x1={sourceGeom.centerX + ux * 14}
        y1={sourceGeom.centerY + uy * 14}
        x2={targetGeom.centerX - ux * 18}
        y2={targetGeom.centerY - uy * 18}
        stroke={style.stroke}
        strokeWidth={strokeWidth}
        strokeDasharray={style.dash}
        markerEnd={`url(#flow-arrow-${flow.type})`}
        opacity={0.92}
        className="pointer-events-none"
      />
    );
  }

  function renderHoverCard() {
    if (hovered === null || hoveredCell === undefined) {
      return null;
    }
    const residents = hoveredCell.demeIds.map((id) => world.demes[id]).filter((d): d is Deme => d !== undefined);
    return (
      <div
        className="pointer-events-none absolute z-20 rounded-lg border border-slate-700 bg-slate-950/95 px-3 py-2 text-xs text-slate-200 shadow-xl"
        style={{ left: hovered.left, top: hovered.top, width: HOVER_CARD_WIDTH }}
      >
        <div className="font-semibold text-slate-100">{t(`biomes.${hoveredCell.biome}`)}</div>
        {hoveredCell.biome !== "ocean" && (
          <div className="mt-1 grid grid-cols-2 gap-x-2 text-slate-400">
            <span>{t("map.food")}</span>
            <span className="text-right font-mono text-slate-200">{Math.round(hoveredCell.currentResources)}</span>
            <span>{t("map.health")}</span>
            <span className="text-right font-mono text-slate-200">
              {Math.round(habitatHealthRatio(hoveredCell) * 100)}%
            </span>
          </div>
        )}
        <div className="mt-1.5 border-t border-slate-800 pt-1.5">
          {residents.length === 0 ? (
            <span className="text-slate-500">{t("map.uninhabited")}</span>
          ) : (
            residents.map((deme) => (
              <div key={deme.id} className="flex items-center gap-1.5">
                <span className="h-2 w-2 rounded-full" style={{ backgroundColor: deme.color }} />
                <span className="truncate">{deme.name}</span>
              </div>
            ))
          )}
        </div>
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
      onPointerUp={() => setIsPointerDown(false)}
      onPointerLeave={() => {
        setIsPointerDown(false);
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

      <svg
        viewBox={viewBox}
        aria-label={t("map.label")}
        className={`h-full w-full ${isPainting ? "cursor-crosshair" : ""}`}
      >
        <defs>
          {(["migration", "exchange", "dispute"] as const).map((flowType) => (
            <marker
              key={flowType}
              id={`flow-arrow-${flowType}`}
              viewBox="0 0 10 10"
              refX="7"
              refY="5"
              markerWidth="5"
              markerHeight="5"
              orient="auto-start-reverse"
            >
              <path d="M 0 1 L 10 5 L 0 9 z" fill={FLOW_STYLES[flowType].stroke} />
            </marker>
          ))}
        </defs>

        <g onPointerLeave={() => setHovered(null)}>
          {cellList.map((cell) => {
            const geometry = computeHexPixelGeometry(cell.q, cell.r);
            return (
              <g
                key={cell.id}
                onPointerDown={() => handleHexPointerDown(cell.id)}
                onPointerEnter={(e) => handleHexPointerEnter(cell.id, e)}
                className={isPainting ? "cursor-crosshair" : "cursor-pointer"}
              >
                <polygon
                  points={geometry.polygonPoints}
                  fill={computeCellFill(cell, mapLens)}
                  fillOpacity={0.78 + cell.altitude * 0.22}
                  stroke={BIOME_STYLES[cell.biome].stroke}
                  strokeOpacity={mapLens === "biome" ? 0.7 : 0.25}
                  strokeWidth={1}
                />
              </g>
            );
          })}
        </g>

        <g className="pointer-events-none">
          {brushPreviewIds.map((hexId) => {
            return (
              <polygon
                key={`preview-${hexId}`}
                points={cellGeometry(hexId).polygonPoints}
                fill="#ffffff"
                fillOpacity={0.14}
                stroke="#ffffff"
                strokeWidth={2}
                strokeDasharray="5 3"
              />
            );
          })}
          {selectedHexId !== null && (
            <polygon
              points={cellGeometry(selectedHexId).polygonPoints}
              fill="none"
              stroke="#f8fafc"
              strokeWidth={2.6}
            />
          )}
          {[...eventHexIds].map((hexId) => {
            const geometry = cellGeometry(hexId);
            return (
              <circle
                key={`event-${hexId}-${world.generation}`}
                cx={geometry.centerX}
                cy={geometry.centerY}
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
          {cellList.map((cell) => {
            const geometry = computeHexPixelGeometry(cell.q, cell.r);
            return <g key={`demes-${cell.id}`}>{renderCellDemes(cell, geometry.centerX, geometry.centerY)}</g>;
          })}
        </g>
      </svg>

      {renderHoverCard()}
    </div>
  );
}
