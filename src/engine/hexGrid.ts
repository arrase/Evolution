import { defineHex, distance, Grid, Orientation, ring, spiral } from "honeycomb-grid";
import type { HexCell } from "../types/simulation";

export const HEX_SIZE = 38;

export const EvolutionHex = defineHex({
  dimensions: HEX_SIZE,
  orientation: Orientation.POINTY,
  origin: "topLeft"
});

export function formatHexId(q: number, r: number): string {
  return `${q + 0},${r + 0}`;
}

export function parseHexId(hexId: string): { q: number; r: number } {
  const [qRaw, rRaw] = hexId.split(",");
  return {
    q: Number(qRaw) + 0,
    r: Number(rRaw) + 0
  };
}

export function createHexGridCoordinates(
  radius: number
): Array<{ id: string; q: number; r: number; s: number }> {
  const grid = new Grid(EvolutionHex, spiral({ start: [0, 0], radius }));
  return grid.toArray().map((hex) => ({
    id: formatHexId(hex.q, hex.r),
    q: hex.q + 0,
    r: hex.r + 0,
    s: hex.s + 0
  }));
}

export function getHexNeighborCoordinates(
  q: number,
  r: number
): Array<{ id: string; q: number; r: number }> {
  const neighborGrid = new Grid(EvolutionHex, ring({ center: [q, r], radius: 1 }));
  return neighborGrid.toArray().map((hex) => ({
    id: formatHexId(hex.q, hex.r),
    q: hex.q + 0,
    r: hex.r + 0
  }));
}

export function getExistingNeighborCells(
  cell: HexCell,
  cells: Record<string, HexCell>
): HexCell[] {
  const neighbors = getHexNeighborCoordinates(cell.q, cell.r);
  const existing: HexCell[] = [];
  for (const neighbor of neighbors) {
    const neighborCell = cells[neighbor.id];
    if (neighborCell !== undefined) {
      existing.push(neighborCell);
    }
  }
  return existing;
}

export function getHexIdsInRadius(
  centerQ: number,
  centerR: number,
  brushRadius: 1 | 2,
  cells: Record<string, HexCell>
): string[] {
  const subGrid = new Grid(
    EvolutionHex,
    spiral({ start: [centerQ, centerR], radius: brushRadius - 1 })
  );
  return subGrid
    .toArray()
    .map((hex) => formatHexId(hex.q, hex.r))
    .filter((id) => id in cells);
}

export interface Hex25DGeometry {
  centerX: number;
  centerY: number;
  topCenterY: number;
  elevationPx: number;
  corners: Array<{ x: number; y: number }>;
  topCorners: Array<{ x: number; y: number }>;
  polygonPoints: string;
  topPolygonPoints: string;
  leftSkirtPoints: string;
  rightSkirtPoints: string;
}

export function computeHexPixelGeometry(
  q: number,
  r: number
): {
  centerX: number;
  centerY: number;
  corners: Array<{ x: number; y: number }>;
  polygonPoints: string;
} {
  const hex = new EvolutionHex({ q, r });
  const corners = hex.corners.map((point) => ({ x: point.x, y: point.y }));
  const polygonPoints = corners.map((point) => `${point.x},${point.y}`).join(" ");
  return {
    centerX: hex.x,
    centerY: hex.y,
    corners,
    polygonPoints
  };
}

export function computeHex25DGeometry(
  q: number,
  r: number,
  altitude: number,
  isOcean: boolean
): Hex25DGeometry {
  const base = computeHexPixelGeometry(q, r);
  const clampedAltitude = Math.min(1, Math.max(0, altitude));
  const elevationPx = isOcean ? 0 : Math.min(10, Math.max(2, Math.round(2 + clampedAltitude * 8)));
  const topCenterY = base.centerY - elevationPx;
  const topCorners = base.corners.map((point) => ({
    x: point.x,
    y: point.y - elevationPx
  }));
  const topPolygonPoints = topCorners.map((point) => `${point.x},${point.y}`).join(" ");

  const lowerBaseCorners = base.corners
    .filter((point) => point.y > base.centerY)
    .sort((a, b) => a.x - b.x);
  const lowerLeft = lowerBaseCorners[0]!;
  const bottom = lowerBaseCorners[1]!;
  const lowerRight = lowerBaseCorners[2]!;

  const leftSkirtPoints = [
    `${lowerLeft.x},${lowerLeft.y - elevationPx}`,
    `${bottom.x},${bottom.y - elevationPx}`,
    `${bottom.x},${bottom.y}`,
    `${lowerLeft.x},${lowerLeft.y}`
  ].join(" ");

  const rightSkirtPoints = [
    `${bottom.x},${bottom.y - elevationPx}`,
    `${lowerRight.x},${lowerRight.y - elevationPx}`,
    `${lowerRight.x},${lowerRight.y}`,
    `${bottom.x},${bottom.y}`
  ].join(" ");

  return {
    centerX: base.centerX,
    centerY: base.centerY,
    topCenterY,
    elevationPx,
    corners: base.corners,
    topCorners,
    polygonPoints: base.polygonPoints,
    topPolygonPoints,
    leftSkirtPoints,
    rightSkirtPoints
  };
}

export function sortCellsFor25DPainterOrder(cells: HexCell[]): HexCell[] {
  return [...cells].sort((a, b) => (a.r !== b.r ? a.r - b.r : a.q - b.q));
}

export function computeCellsViewBox(cells: HexCell[], padding: number): string {
  if (cells.length === 0) {
    return "0 0 100 100";
  }
  const centers = cells.map((cell) => computeHexPixelGeometry(cell.q, cell.r));
  const xs = centers.map((center) => center.centerX);
  const ys = centers.map((center) => center.centerY);
  const minX = Math.min(...xs) - HEX_SIZE - padding;
  const maxX = Math.max(...xs) + HEX_SIZE + padding;
  const minY = Math.min(...ys) - HEX_SIZE - padding;
  const maxY = Math.max(...ys) + HEX_SIZE + padding;
  const width = maxX - minX;
  const height = maxY - minY;
  return `${minX} ${minY} ${width} ${height}`;
}

export function computeHexDistance(
  a: { q: number; r: number },
  b: { q: number; r: number }
): number {
  return distance(EvolutionHex.settings, a, b);
}

export function isHexPassableForDeme(
  targetCell: HexCell,
  effectiveSpatialMobility: number
): boolean {
  return targetCell.biome !== "ocean" && targetCell.altitude - 0.50 <= effectiveSpatialMobility;
}
