import { describe, expect, it } from "vitest";
import {
  computeCellsViewBox,
  computeHex25DGeometry,
  computeHexDistance,
  computeHexPixelGeometry,
  createHexGridCoordinates,
  formatHexId,
  getExistingNeighborCells,
  getHexIdsInRadius,
  getHexNeighborCoordinates,
  HEX_SIZE,
  isHexPassableForDeme,
  parseHexId,
  sortCellsFor25DPainterOrder
} from "../../src/engine/hexGrid";
import type { HexCell } from "../../src/types/simulation";

function createTestCell(overrides: Partial<HexCell> & { q: number; r: number }): HexCell {
  const { q, r, ...rest } = overrides;
  return {
    id: formatHexId(q, r),
    q,
    r,
    biome: "savanna",
    temperature: 0.2,
    humidity: 0.4,
    altitude: 0.35,
    currentResources: 250,
    carryingCapacity: 300,
    carryingCapacityMax: 400,
    seasonalRegenRate: 0.15,
    demeIds: [],
    ...rest
  };
}

describe("hexGrid geometry helpers", () => {
  it("formats and parses hex coordinate IDs deterministically", () => {
    expect(formatHexId(0, 0)).toBe("0,0");
    expect(formatHexId(-3, 4)).toBe("-3,4");
    expect(parseHexId("-3,4")).toEqual({ q: -3, r: 4 });
    expect(parseHexId("0,0")).toEqual({ q: 0, r: 0 });
  });

  it("produces 61 cells for radius 4 and 91 cells for radius 5 with cube invariant q + r + s = 0", () => {
    const gridR4 = createHexGridCoordinates(4);
    const gridR5 = createHexGridCoordinates(5);

    expect(gridR4).toHaveLength(61);
    expect(gridR5).toHaveLength(91);

    for (const coord of gridR5) {
      expect(coord.q + coord.r + coord.s).toBe(0);
      expect(coord.id).toBe(formatHexId(coord.q, coord.r));
      expect(computeHexDistance({ q: 0, r: 0 }, { q: coord.q, r: coord.r })).toBeLessThanOrEqual(5);
    }
  });

  it("ensures every interior cell has exactly 6 equidistant neighbors at hex distance 1 (FR-001)", () => {
    const radius = 5;
    const coords = createHexGridCoordinates(radius);
    const cells: Record<string, HexCell> = {};
    for (const c of coords) {
      cells[c.id] = createTestCell({ q: c.q, r: c.r });
    }

    const interiorCoords = coords.filter(
      (c) => computeHexDistance({ q: 0, r: 0 }, { q: c.q, r: c.r }) < radius
    );
    expect(interiorCoords).toHaveLength(61);

    const centerToCornerDistance = HEX_SIZE * Math.sqrt(3);

    for (const cellCoord of interiorCoords) {
      const neighborCoords = getHexNeighborCoordinates(cellCoord.q, cellCoord.r);
      expect(neighborCoords).toHaveLength(6);

      const interiorCell = createTestCell({ q: cellCoord.q, r: cellCoord.r });
      const existingNeighbors = getExistingNeighborCells(interiorCell, cells);
      expect(existingNeighbors).toHaveLength(6);

      const centerGeom = computeHexPixelGeometry(cellCoord.q, cellCoord.r);

      for (const neighbor of existingNeighbors) {
        expect(
          computeHexDistance({ q: cellCoord.q, r: cellCoord.r }, { q: neighbor.q, r: neighbor.r })
        ).toBe(1);

        const neighborGeom = computeHexPixelGeometry(neighbor.q, neighbor.r);
        const euclideanDist = Math.hypot(
          neighborGeom.centerX - centerGeom.centerX,
          neighborGeom.centerY - centerGeom.centerY
        );
        expect(euclideanDist).toBeCloseTo(centerToCornerDistance, 5);
      }
    }
  });

  it("computes 6 polygon vertices and valid SVG polygonPoints for a hex cell", () => {
    const geom = computeHexPixelGeometry(0, 0);

    expect(geom.corners).toHaveLength(6);
    for (const corner of geom.corners) {
      const distFromCenter = Math.hypot(corner.x - geom.centerX, corner.y - geom.centerY);
      expect(distFromCenter).toBeCloseTo(HEX_SIZE, 5);
    }

    const pointPairs = geom.polygonPoints.split(" ");
    expect(pointPairs).toHaveLength(6);
    for (const pair of pointPairs) {
      expect(pair).toMatch(/^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/);
    }
  });

  it("returns 1 cell for brushRadius = 1 and up to 7 cells for brushRadius = 2 filtered to existing cells", () => {
    const coords = createHexGridCoordinates(4);
    const cells: Record<string, HexCell> = {};
    for (const c of coords) {
      cells[c.id] = createTestCell({ q: c.q, r: c.r });
    }

    const singleCenter = getHexIdsInRadius(0, 0, 1, cells);
    expect(singleCenter).toEqual(["0,0"]);

    const centerBrush2 = getHexIdsInRadius(0, 0, 2, cells);
    expect(centerBrush2).toHaveLength(7);
    expect(centerBrush2).toContain("0,0");

    // Border cell at (4, 0) has only 3 neighbors inside radius-4 grid (+ itself = 4 cells)
    const borderBrush2 = getHexIdsInRadius(4, 0, 2, cells);
    expect(borderBrush2.length).toBe(4);
    expect(borderBrush2).toContain("4,0");
  });

  it("enforces biome and altitude mobility rules in isHexPassableForDeme", () => {
    const oceanCell = createTestCell({ q: 1, r: 0, biome: "ocean", altitude: 0.05 });
    const savannaCell = createTestCell({ q: 0, r: 1, biome: "savanna", altitude: 0.35 });
    const highMountainCell = createTestCell({
      q: 0,
      r: 0,
      biome: "high_mountain",
      altitude: 0.88
    });

    expect(isHexPassableForDeme(oceanCell, 0.9)).toBe(false);
    expect(isHexPassableForDeme(savannaCell, 0.0)).toBe(true);
    expect(isHexPassableForDeme(highMountainCell, 0.20)).toBe(false);
    expect(isHexPassableForDeme(highMountainCell, 0.45)).toBe(true);
  });

  it("computes fallback and bounded SVG viewBox strings in computeCellsViewBox", () => {
    expect(computeCellsViewBox([], 24)).toBe("0 0 100 100");

    const singleCell = [createTestCell({ q: 0, r: 0 })];
    const viewBox = computeCellsViewBox(singleCell, 10);
    const parts = viewBox.split(" ").map(Number);
    expect(parts).toHaveLength(4);
    expect(parts[2]).toBeCloseTo((HEX_SIZE + 10) * 2, 5);
    expect(parts[3]).toBeCloseTo((HEX_SIZE + 10) * 2, 5);
  });

  it("computes 2.5D elevation skirts proportional to altitude and sorts cells in back-to-front painter's order", () => {
    const oceanGeom = computeHex25DGeometry(0, 0, 0.08, true);
    expect(oceanGeom.elevationPx).toBe(0);
    expect(oceanGeom.topCenterY).toBe(oceanGeom.centerY);

    const lowlandGeom = computeHex25DGeometry(0, 0, 0.1, false);
    const mountainGeom = computeHex25DGeometry(0, 0, 0.95, false);
    expect(lowlandGeom.elevationPx).toBeGreaterThanOrEqual(2);
    expect(mountainGeom.elevationPx).toBeGreaterThan(lowlandGeom.elevationPx);
    expect(mountainGeom.elevationPx).toBeLessThanOrEqual(10);
    expect(mountainGeom.topCenterY).toBe(mountainGeom.centerY - mountainGeom.elevationPx);
    expect(mountainGeom.leftSkirtPoints.split(" ")).toHaveLength(4);
    expect(mountainGeom.rightSkirtPoints.split(" ")).toHaveLength(4);

    const cells = [
      createTestCell({ q: 1, r: 2 }),
      createTestCell({ q: -1, r: -2 }),
      createTestCell({ q: 2, r: 0 }),
      createTestCell({ q: -1, r: 0 })
    ];
    const sorted = sortCellsFor25DPainterOrder(cells);
    expect(sorted.map((c) => c.id)).toEqual(["-1,-2", "-1,0", "2,0", "1,2"]);
  });
});
