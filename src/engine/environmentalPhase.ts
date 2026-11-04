import type {
  ChronicleEntry,
  Deme,
  HexCell,
  HexEdgeFlow,
  LineageNode,
  SeasonType,
  WorldState
} from "../types/simulation";
import { getExistingNeighborCells } from "./hexGrid";

export function runEnvironmentalPhase(state: WorldState): WorldState {
  const nextGeneration = state.generation + 1;
  const nextSeason: SeasonType = state.season === "wet_warm" ? "dry_cold" : "wet_warm";
  const gammaSeason = nextSeason === "wet_warm" ? 1.20 : 0.75;

  const nextSeaLevel =
    state.presetId === "preset-darwin-archipelago" && nextGeneration % 8 === 0
      ? (nextGeneration / 8) % 2 === 0
        ? 0.12
        : 0.25
      : state.seaLevel;

  const cells: Record<string, HexCell> = {};
  for (const [id, cell] of Object.entries(state.cells)) {
    cells[id] = {
      ...cell,
      demeIds: [...cell.demeIds]
    };
  }

  const demes: Record<string, Deme> = {};
  for (const [id, deme] of Object.entries(state.demes)) {
    demes[id] = {
      ...deme,
      biologicalTraitIds: [...deme.biologicalTraitIds],
      culturalTraitIds: [...deme.culturalTraitIds],
      baldwinCounters: { ...deme.baldwinCounters },
      lastDecisionProbabilities: { ...deme.lastDecisionProbabilities }
    };
  }

  const lineageTree: Record<string, LineageNode> = {};
  for (const [id, node] of Object.entries(state.lineageTree)) {
    lineageTree[id] = {
      ...node,
      acquiredTraitIds: [...node.acquiredTraitIds]
    };
  }

  const chronicle: ChronicleEntry[] = [...state.chronicle];
  const currentTurnFlows: HexEdgeFlow[] = [];

  for (const cell of Object.values(cells)) {
    if (cell.altitude < nextSeaLevel && cell.biome !== "ocean") {
      cell.biome = "ocean";
    } else if (cell.altitude >= nextSeaLevel && cell.biome === "ocean") {
      if (cell.altitude < 0.25) {
        cell.biome = "coastal_shallows";
      } else if (cell.altitude < 0.55) {
        cell.biome = "savanna";
      } else if (cell.altitude < 0.78) {
        cell.biome = "arid_steppe";
      } else {
        cell.biome = "high_mountain";
      }
      cell.carryingCapacityMax = Math.max(160, cell.carryingCapacityMax);
      cell.carryingCapacity = Math.max(80, cell.carryingCapacity);
      cell.currentResources = Math.max(
        cell.currentResources,
        Math.round(cell.carryingCapacity * 0.35)
      );
    }
  }

  for (const cell of Object.values(cells)) {
    if (cell.biome === "ocean" && cell.demeIds.length > 0) {
      const residentDemeIds = [...cell.demeIds];
      cell.demeIds = [];

      for (const demeId of residentDemeIds) {
        const deme = demes[demeId];
        if (deme === undefined) {
          continue;
        }

        const candidates = getExistingNeighborCells(cell, cells)
          .filter(
            (neighbor) =>
              neighbor.biome !== "ocean" &&
              neighbor.demeIds.length < 3 &&
              neighbor.altitude <= 0.85
          )
          .sort((a, b) => b.currentResources - a.currentResources);

        const targetCell = candidates[0];
        if (targetCell !== undefined) {
          deme.hexId = targetCell.id;
          deme.energyReserves = Number((deme.energyReserves * 0.80).toFixed(2));
          targetCell.demeIds.push(deme.id);
          currentTurnFlows.push({
            fromHexId: cell.id,
            toHexId: targetCell.id,
            demeId: deme.id,
            color: deme.color,
            type: "migration",
            intensity: 0.65
          });
        } else {
          delete demes[demeId];
          chronicle.push({
            id: `chronicle-submerge-${nextGeneration}-${deme.id}`,
            generation: nextGeneration,
            type: "extinction",
            title: `${deme.name} Submerged`,
            body: `${deme.name} went extinct when cell (${cell.id}) submerged into ocean with no accessible terrestrial refuge.`,
            demeId: deme.id,
            lineageId: deme.lineageId,
            hexId: cell.id
          });

          const hasLivingRelatives = Object.values(demes).some(
            (remaining) => remaining.lineageId === deme.lineageId
          );
          const lineageNode = lineageTree[deme.lineageId];
          if (!hasLivingRelatives && lineageNode !== undefined) {
            lineageNode.extinctGeneration = nextGeneration;
          }
        }
      }
    }
  }

  const deltaTemp = nextSeason === "wet_warm" ? 0.04 : -0.04;
  const deltaHum = nextSeason === "wet_warm" ? 0.05 : -0.05;

  for (const cell of Object.values(cells)) {
    if (cell.biome === "ocean") {
      cell.currentResources = 0;
      continue;
    }

    cell.temperature = Math.max(-1, Math.min(1, Number((cell.temperature + deltaTemp).toFixed(2))));
    cell.humidity = Math.max(0, Math.min(1, Number((cell.humidity + deltaHum).toFixed(2))));

    const sufferedCollapse = state.chronicle.some(
      (entry) =>
        entry.type === "tragedy_of_commons" &&
        entry.hexId === cell.id &&
        entry.generation === state.generation
    );
    const recoveryRate = sufferedCollapse || cell.currentResources === 0 ? 0.005 : 0.05;

    const nextK = Math.max(
      10,
      Math.min(
        cell.carryingCapacityMax,
        Number(
          (
            cell.carryingCapacity +
            recoveryRate * (cell.carryingCapacityMax - cell.carryingCapacity)
          ).toFixed(2)
        )
      )
    );
    const nextR = Math.min(
      nextK,
      Number((cell.currentResources + nextK * cell.seasonalRegenRate * gammaSeason).toFixed(2))
    );

    cell.carryingCapacity = nextK;
    cell.currentResources = nextR;
  }

  return {
    ...state,
    generation: nextGeneration,
    season: nextSeason,
    seaLevel: nextSeaLevel,
    selectivePressurePoints: state.selectivePressurePoints + state.selectivePressureRegenPerTurn,
    cells,
    demes,
    lineageTree,
    chronicle,
    currentTurnFlows
  };
}
