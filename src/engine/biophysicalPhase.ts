import { demeHasCulturalCapacity } from "../catalog/baseTraits";
import type {
  BiophysicalVector,
  ChronicleEntry,
  Deme,
  DemeDecisionEvaluationOutput,
  HexCell,
  HexEdgeFlow,
  LineageNode,
  WorldState
} from "../types/simulation";
import { getExistingNeighborCells, isHexPassableForDeme } from "./hexGrid";

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function getDecisionProb(deme: Deme, decisionId: string): number {
  const prob = deme.lastDecisionProbabilities[decisionId];
  return prob !== undefined ? prob : 0;
}

function getNumericEntry(record: Record<string, number>, key: string): number {
  const value = record[key];
  return value !== undefined ? value : 0;
}

export function computeDemeDivergence(demeA: Deme, demeB: Deme): number {
  const traitsA = new Set([...demeA.biologicalTraitIds, ...demeA.culturalTraitIds]);
  const traitsB = new Set([...demeB.biologicalTraitIds, ...demeB.culturalTraitIds]);
  const union = new Set([...traitsA, ...traitsB]);

  if (union.size === 0) {
    return 0;
  }

  let intersectionSize = 0;
  for (const traitId of traitsA) {
    if (traitsB.has(traitId)) {
      intersectionSize += 1;
    }
  }

  return Number((1 - intersectionSize / union.size).toFixed(4));
}

export function computeEffectiveBiophysicalVector(
  deme: Deme,
  state: WorldState,
  probabilities: Record<string, number>
): BiophysicalVector {
  let metabolicCost = 0;
  let extractionEfficiency = 0;
  let ecologicalImpact = 0;
  let spatialMobility = 0;
  let socialCohesion = 0;
  let transmissionThreshold = 0;

  const allTraitIds = [...deme.biologicalTraitIds, ...deme.culturalTraitIds];
  for (const traitId of allTraitIds) {
    const trait = state.traitsCatalog[traitId];
    if (trait !== undefined) {
      metabolicCost += trait.biophysicalVector.metabolicCost;
      extractionEfficiency += trait.biophysicalVector.extractionEfficiency;
      ecologicalImpact += trait.biophysicalVector.ecologicalImpact;
      spatialMobility += trait.biophysicalVector.spatialMobility;
      socialCohesion += trait.biophysicalVector.socialCohesion;
      transmissionThreshold += trait.biophysicalVector.transmissionThreshold;
    }
  }

  for (const [decisionId, prob] of Object.entries(probabilities)) {
    const decision = state.decisionsCatalog[decisionId];
    if (decision !== undefined && prob > 0) {
      metabolicCost += prob * decision.biophysicalVector.metabolicCost;
      extractionEfficiency += prob * decision.biophysicalVector.extractionEfficiency;
      ecologicalImpact += prob * decision.biophysicalVector.ecologicalImpact;
      spatialMobility += prob * decision.biophysicalVector.spatialMobility;
      socialCohesion += prob * decision.biophysicalVector.socialCohesion;
      transmissionThreshold += prob * decision.biophysicalVector.transmissionThreshold;
    }
  }

  return {
    metabolicCost: Number(clamp(metabolicCost, -1.5, 1.5).toFixed(4)),
    extractionEfficiency: Number(clamp(extractionEfficiency, -1.5, 1.5).toFixed(4)),
    ecologicalImpact: Number(clamp(ecologicalImpact, -1.5, 1.5).toFixed(4)),
    spatialMobility: Number(clamp(spatialMobility, -1.5, 1.5).toFixed(4)),
    socialCohesion: Number(clamp(socialCohesion, -1.5, 1.5).toFixed(4)),
    transmissionThreshold: Number(clamp(transmissionThreshold, 0.0, 1.5).toFixed(4))
  };
}

export function resolveBiophysicalAndDemographicPhase(
  state: WorldState,
  decisionsByDemeId: Record<string, DemeDecisionEvaluationOutput>
): WorldState {
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
  const currentTurnFlows: HexEdgeFlow[] = [...state.currentTurnFlows];

  const initialPopulationByDemeId: Record<string, number> = {};
  const effectiveVectorByDemeId: Record<string, BiophysicalVector> = {};
  const hawkPenaltyByDemeId: Record<string, number> = {};
  const extractedEnergyByDemeId: Record<string, number> = {};
  const symbiosisBonusAppliedDemeIds = new Set<string>();
  const hadLineageContactDemeIds = new Set<string>();

  const getEffectiveVector = (deme: Deme): BiophysicalVector => {
    const cached = effectiveVectorByDemeId[deme.id];
    if (cached !== undefined) {
      return cached;
    }
    const computed = computeEffectiveBiophysicalVector(
      deme,
      state,
      deme.lastDecisionProbabilities
    );
    effectiveVectorByDemeId[deme.id] = computed;
    return computed;
  };

  for (const deme of Object.values(demes)) {
    initialPopulationByDemeId[deme.id] = deme.population;
    hawkPenaltyByDemeId[deme.id] = 1.0;
    extractedEnergyByDemeId[deme.id] = 0;

    const decisionEval = decisionsByDemeId[deme.id];
    if (decisionEval !== undefined) {
      deme.lastDecisionProbabilities = { ...decisionEval.probabilities };
      deme.lastDominantDecisionId = decisionEval.dominantDecisionId;
      deme.lastJustification = decisionEval.justification;
    }

    effectiveVectorByDemeId[deme.id] = computeEffectiveBiophysicalVector(
      deme,
      state,
      deme.lastDecisionProbabilities
    );
  }

  for (const cell of Object.values(cells)) {
    const residentDemes = cell.demeIds
      .map((id) => demes[id])
      .filter((deme): deme is Deme => deme !== undefined);

    if (residentDemes.length === 0) {
      continue;
    }

    const demandByDemeId: Record<string, number> = {};
    for (const deme of residentDemes) {
      const vEff = getEffectiveVector(deme);
      demandByDemeId[deme.id] = Math.max(
        0,
        deme.population * 0.50 * (1 + 0.60 * vEff.extractionEfficiency)
      );
    }

    const hawks = residentDemes.filter(
      (deme) => getDecisionProb(deme, "dec-territorial-dispute") >= 0.25
    );
    const doves = residentDemes.filter(
      (deme) => getDecisionProb(deme, "dec-territorial-dispute") < 0.25
    );
    const exchangers = residentDemes.filter(
      (deme) => getDecisionProb(deme, "dec-exchange-symbiosis") >= 0.20
    );

    if (residentDemes.length >= 2) {
      if (hawks.length >= 2) {
        for (const hawk of hawks) {
          hawk.population = Math.max(1, Math.floor(hawk.population * 0.85));
          hawkPenaltyByDemeId[hawk.id] = 1.25;
          const vEff = getEffectiveVector(hawk);
          demandByDemeId[hawk.id] = Math.max(
            0,
            hawk.population * 0.50 * (1 + 0.60 * vEff.extractionEfficiency)
          );
          currentTurnFlows.push({
            fromHexId: cell.id,
            toHexId: cell.id,
            demeId: hawk.id,
            color: hawk.color,
            type: "dispute",
            intensity: 0.75
          });
        }
      } else if (hawks.length >= 1 && doves.length >= 1) {
        const avgDoveSocial =
          doves.reduce((sum, dove) => sum + getEffectiveVector(dove).socialCohesion, 0) /
          doves.length;

        for (const hawk of hawks) {
          const hawkSocial = getEffectiveVector(hawk).socialCohesion;
          const captureMultiplier = 0.25 * (1 + Math.max(0, hawkSocial - avgDoveSocial));
          const hawkDemand = getNumericEntry(demandByDemeId, hawk.id);
          const requestedBonus = hawkDemand * captureMultiplier;
          const totalDoveDemand = doves.reduce(
            (sum, dove) => sum + getNumericEntry(demandByDemeId, dove.id),
            0
          );
          const actualCaptured = Math.min(totalDoveDemand, requestedBonus);

          demandByDemeId[hawk.id] = hawkDemand + actualCaptured;
          if (totalDoveDemand > 0) {
            for (const dove of doves) {
              const currentDoveDemand = getNumericEntry(demandByDemeId, dove.id);
              const doveShare = currentDoveDemand / totalDoveDemand;
              demandByDemeId[dove.id] = Math.max(
                0,
                currentDoveDemand - actualCaptured * doveShare
              );
            }
          }

          currentTurnFlows.push({
            fromHexId: cell.id,
            toHexId: cell.id,
            demeId: hawk.id,
            color: hawk.color,
            type: "dispute",
            intensity: 0.65
          });
        }
      }
    }

    const totalDemand = residentDemes.reduce(
      (sum, deme) => sum + getNumericEntry(demandByDemeId, deme.id),
      0
    );
    const totalExtracted = Math.min(cell.currentResources, totalDemand);

    for (const deme of residentDemes) {
      const demeDemand = getNumericEntry(demandByDemeId, deme.id);
      const extracted = totalDemand > 0 ? totalExtracted * (demeDemand / totalDemand) : 0;
      extractedEnergyByDemeId[deme.id] = extracted;
    }

    cell.currentResources = Math.max(
      0,
      Number((cell.currentResources - totalExtracted).toFixed(2))
    );

    if (exchangers.length >= 2) {
      let loggedSymbiosisInCell = false;

      for (const exchanger of exchangers) {
        const baseExtracted = getNumericEntry(extractedEnergyByDemeId, exchanger.id);
        extractedEnergyByDemeId[exchanger.id] = Number((baseExtracted * 1.20).toFixed(4));
        symbiosisBonusAppliedDemeIds.add(exchanger.id);
        currentTurnFlows.push({
          fromHexId: cell.id,
          toHexId: cell.id,
          demeId: exchanger.id,
          color: exchanger.color,
          type: "exchange",
          intensity: 0.60
        });
      }

      for (const donor of exchangers) {
        for (const receiver of exchangers) {
          if (donor.id === receiver.id) {
            continue;
          }
          if (!demeHasCulturalCapacity(receiver, state.traitsCatalog)) {
            continue;
          }
          const receiverSocial = getEffectiveVector(receiver).socialCohesion;
          const receiverExchangeProb = getDecisionProb(receiver, "dec-exchange-symbiosis");

          for (const traitId of donor.culturalTraitIds) {
            if (receiver.culturalTraitIds.includes(traitId)) {
              continue;
            }
            const traitDef = state.traitsCatalog[traitId];
            if (
              traitDef !== undefined &&
              (receiverSocial >= traitDef.biophysicalVector.transmissionThreshold ||
                receiverExchangeProb >= 0.25)
            ) {
              receiver.culturalTraitIds.push(traitId);
              if (!loggedSymbiosisInCell) {
                loggedSymbiosisInCell = true;
                chronicle.push({
                  id: `chronicle-symbiosis-${state.generation}-${cell.id}-${receiver.id}`,
                  generation: state.generation,
                  type: "symbiosis",
                  title: `Cultural Symbiosis: ${traitDef.name}`,
                  body: `${receiver.name} acquired ${traitDef.name} through symbiotic exchange with ${donor.name} in hex (${cell.id}).`,
                  demeId: receiver.id,
                  lineageId: receiver.lineageId,
                  hexId: cell.id
                });
              }
            }
          }
        }
      }
    }

    const naturalRegen = cell.carryingCapacity * cell.seasonalRegenRate;
    const sumEcoImpact = residentDemes.reduce(
      (sum, deme) => sum + getEffectiveVector(deme).ecologicalImpact,
      0
    );
    const hasIntensiveOverexploit = residentDemes.some(
      (deme) => getDecisionProb(deme, "dec-intensive-overexploit") >= 0.30
    );

    if (
      totalExtracted > naturalRegen &&
      (sumEcoImpact < -0.15 || (hasIntensiveOverexploit && sumEcoImpact < -0.10))
    ) {
      const degradedK = Math.max(
        10,
        Number((cell.carryingCapacity * (1 + 0.18 * sumEcoImpact)).toFixed(2))
      );
      cell.carryingCapacity = degradedK;
      if (cell.currentResources > degradedK) {
        cell.currentResources = degradedK;
      }

      const alreadyLoggedTragedy = chronicle.some(
        (entry) => entry.type === "tragedy_of_commons" && entry.hexId === cell.id
      );
      const primaryDeme = residentDemes[0];
      if (
        !alreadyLoggedTragedy &&
        degradedK < 0.60 * cell.carryingCapacityMax &&
        primaryDeme !== undefined
      ) {
        chronicle.push({
          id: `chronicle-tragedy-${state.generation}-${cell.id}`,
          generation: state.generation,
          type: "tragedy_of_commons",
          title: `Tragedy of the Commons in (${cell.id})`,
          body: `Intensive overexploitation degraded local carrying capacity to ${degradedK} (below 60% of maximum ${cell.carryingCapacityMax}).`,
          demeId: primaryDeme.id,
          lineageId: primaryDeme.lineageId,
          hexId: cell.id
        });
      }
    }
  }

  for (const donor of Object.values(demes)) {
    if (getDecisionProb(donor, "dec-exchange-symbiosis") < 0.20) {
      continue;
    }
    const donorCell = cells[donor.hexId];
    if (donorCell === undefined) {
      continue;
    }
    const neighborCells = getExistingNeighborCells(donorCell, cells);

    for (const neighborCell of neighborCells) {
      for (const neighborDemeId of neighborCell.demeIds) {
        const receiver = demes[neighborDemeId];
        if (
          receiver === undefined ||
          getDecisionProb(receiver, "dec-exchange-symbiosis") < 0.20
        ) {
          continue;
        }

        if (!symbiosisBonusAppliedDemeIds.has(donor.id)) {
          const baseExtracted = getNumericEntry(extractedEnergyByDemeId, donor.id);
          extractedEnergyByDemeId[donor.id] = Number((baseExtracted * 1.20).toFixed(4));
          symbiosisBonusAppliedDemeIds.add(donor.id);
        }

        currentTurnFlows.push({
          fromHexId: donorCell.id,
          toHexId: neighborCell.id,
          demeId: donor.id,
          color: donor.color,
          type: "exchange",
          intensity: 0.55
        });

        if (demeHasCulturalCapacity(receiver, state.traitsCatalog)) {
          const receiverSocial = getEffectiveVector(receiver).socialCohesion;
          const receiverExchangeProb = getDecisionProb(receiver, "dec-exchange-symbiosis");

          for (const traitId of donor.culturalTraitIds) {
            if (receiver.culturalTraitIds.includes(traitId)) {
              continue;
            }
            const traitDef = state.traitsCatalog[traitId];
            if (
              traitDef !== undefined &&
              (receiverSocial >= traitDef.biophysicalVector.transmissionThreshold ||
                receiverExchangeProb >= 0.25)
            ) {
              receiver.culturalTraitIds.push(traitId);
            }
          }
        }
      }
    }
  }

  for (const deme of Object.values(demes)) {
    const cell = cells[deme.hexId];
    if (cell === undefined) {
      continue;
    }
    const vEff = getEffectiveVector(deme);
    const storedMultiplier = hawkPenaltyByDemeId[deme.id];
    const hawkMultiplier = storedMultiplier !== undefined ? storedMultiplier : 1.0;
    const extracted = getNumericEntry(extractedEnergyByDemeId, deme.id);

    const metabolicCost =
      deme.population *
      0.42 *
      (1 +
        0.55 * vEff.metabolicCost +
        0.20 * Math.abs(cell.temperature) * (1 - Math.max(0, vEff.spatialMobility))) *
      hawkMultiplier;

    const deltaE = extracted - metabolicCost;
    const previousReserves = deme.energyReserves;

    const effectiveDeltaE =
      deltaE < 0 && previousReserves > deme.population * 0.30
        ? deltaE + Math.min(-deltaE, previousReserves * 0.50)
        : deltaE;

    deme.lastEnergyDelta = Number(deltaE.toFixed(2));
    deme.energyReserves = Math.max(0, Number((previousReserves + deltaE).toFixed(2)));

    let growthRate = clamp(
      (effectiveDeltaE / Math.max(10, deme.population)) * 0.45,
      -0.45,
      0.35
    );
    if (deme.biologicalTraitIds.includes("bio-r-strategy")) {
      growthRate *= 1.35;
    }
    if (deme.biologicalTraitIds.includes("bio-k-strategy")) {
      growthRate *= 0.75;
    }
    growthRate = clamp(growthRate, -0.45, 0.35);

    const nextPop = Math.round(deme.population * (1 + growthRate));
    deme.population =
      effectiveDeltaE < 0 && nextPop >= deme.population ? deme.population - 1 : nextPop;

    for (const [decisionId, prob] of Object.entries(deme.lastDecisionProbabilities)) {
      if (decisionId !== "dec-conservative-forage" && prob >= 0.35) {
        const currentCount = getNumericEntry(deme.baldwinCounters, decisionId);
        deme.baldwinCounters[decisionId] = currentCount + 1;
      }
    }

    const pExplore = getDecisionProb(deme, "dec-explore-innovate");
    const pCooperate = getDecisionProb(deme, "dec-cooperate-store");
    const pInnovate = pExplore + 0.35 * pCooperate;
    deme.innovationCounter = Math.min(
      2.0,
      Number((deme.innovationCounter + pInnovate * 0.45).toFixed(4))
    );
  }

  const preFissionDemes = Object.values(demes);
  for (const deme of preFissionDemes) {
    if (deme.population < 20) {
      continue;
    }

    const pMigrate = getDecisionProb(deme, "dec-selective-migration");
    const migrants = Math.floor(deme.population * pMigrate * 0.45);

    if (migrants < 10 || deme.population - migrants < 10) {
      continue;
    }

    const currentCell = cells[deme.hexId];
    if (currentCell === undefined) {
      continue;
    }
    const vEffMobility = getEffectiveVector(deme).spatialMobility;

    const isEmergencyEvacuation = currentCell.currentResources < deme.population * 0.20;
    const candidateNeighbors = getExistingNeighborCells(currentCell, cells)
      .filter((neighbor) => {
        if (!isHexPassableForDeme(neighbor, vEffMobility)) {
          return false;
        }
        if (neighbor.demeIds.length >= 3) {
          return false;
        }
        if (!isEmergencyEvacuation) {
          const hasCompatibleSameLineage = neighbor.demeIds.some((id) => {
            const other = demes[id];
            return (
              other !== undefined &&
              other.lineageId === deme.lineageId &&
              computeDemeDivergence(deme, other) < 0.10
            );
          });
          if (hasCompatibleSameLineage) {
            return false;
          }
        }
        return true;
      })
      .sort(
        (a, b) =>
          b.currentResources / (b.demeIds.length + 1) -
          a.currentResources / (a.demeIds.length + 1)
      );

    const targetCell = candidateNeighbors[0];
    if (targetCell === undefined) {
      continue;
    }

    const originalPop = deme.population;
    const energyFraction = deme.energyReserves * (migrants / originalPop);
    const transferredEnergy = Number((energyFraction * 0.85).toFixed(2));

    deme.population -= migrants;
    deme.energyReserves = Math.max(0, Number((deme.energyReserves - energyFraction).toFixed(2)));

    const daughterId = `${deme.id}-m${state.generation}-${targetCell.q}_${targetCell.r}`;
    const daughterDeme: Deme = {
      id: daughterId,
      name: `${deme.name} (${targetCell.id})`.slice(0, 60),
      lineageId: deme.lineageId,
      color: deme.color,
      hexId: targetCell.id,
      population: migrants,
      energyReserves: transferredEnergy,
      lastEnergyDelta: 0,
      biologicalTraitIds: [...deme.biologicalTraitIds],
      culturalTraitIds: [...deme.culturalTraitIds],
      baldwinCounters: {},
      innovationCounter: 0,
      isolationTurns: 0,
      lastDecisionProbabilities: { ...deme.lastDecisionProbabilities },
      lastDominantDecisionId: deme.lastDominantDecisionId,
      lastJustification: deme.lastJustification
    };

    demes[daughterId] = daughterDeme;
    targetCell.demeIds.push(daughterId);
    initialPopulationByDemeId[daughterId] = migrants;
    effectiveVectorByDemeId[daughterId] = getEffectiveVector(deme);

    hadLineageContactDemeIds.add(deme.id);
    hadLineageContactDemeIds.add(daughterId);

    currentTurnFlows.push({
      fromHexId: currentCell.id,
      toHexId: targetCell.id,
      demeId: deme.id,
      color: deme.color,
      type: "migration",
      intensity: Number(clamp(migrants / originalPop, 0.05, 1.0).toFixed(2))
    });
  }

  for (const cell of Object.values(cells)) {
    for (let i = 0; i < cell.demeIds.length; i += 1) {
      for (let j = i + 1; j < cell.demeIds.length; j += 1) {
        const idA = cell.demeIds[i];
        const idB = cell.demeIds[j];
        if (idA === undefined || idB === undefined) {
          continue;
        }
        const demeA = demes[idA];
        const demeB = demes[idB];

        if (
          demeA !== undefined &&
          demeB !== undefined &&
          demeA.lineageId === demeB.lineageId &&
          computeDemeDivergence(demeA, demeB) < 0.10
        ) {
          const totalPop = demeA.population + demeB.population;
          const weightA = demeA.population / totalPop;
          const weightB = demeB.population / totalPop;

          demeA.innovationCounter = Math.min(
            2.0,
            Number(
              (demeA.innovationCounter * weightA + demeB.innovationCounter * weightB).toFixed(4)
            )
          );

          const counterKeys = new Set([
            ...Object.keys(demeA.baldwinCounters),
            ...Object.keys(demeB.baldwinCounters)
          ]);
          const mergedCounters: Record<string, number> = {};
          for (const key of counterKeys) {
            const countA = getNumericEntry(demeA.baldwinCounters, key);
            const countB = getNumericEntry(demeB.baldwinCounters, key);
            mergedCounters[key] = Math.round(countA * weightA + countB * weightB);
          }
          demeA.baldwinCounters = mergedCounters;

          demeA.population = totalPop;
          demeA.energyReserves = Number((demeA.energyReserves + demeB.energyReserves).toFixed(2));
          demeA.biologicalTraitIds = Array.from(
            new Set([...demeA.biologicalTraitIds, ...demeB.biologicalTraitIds])
          );
          demeA.culturalTraitIds = Array.from(
            new Set([...demeA.culturalTraitIds, ...demeB.culturalTraitIds])
          );

          initialPopulationByDemeId[demeA.id] =
            getNumericEntry(initialPopulationByDemeId, demeA.id) +
            getNumericEntry(initialPopulationByDemeId, demeB.id);

          delete demes[demeB.id];
          cell.demeIds.splice(j, 1);
          j -= 1;

          hadLineageContactDemeIds.add(demeA.id);
        }
      }
    }
  }

  for (const deme of Object.values(demes)) {
    if (deme.population < 10) {
      const cell = cells[deme.hexId];
      if (cell !== undefined) {
        cell.demeIds = cell.demeIds.filter((id) => id !== deme.id);
      }
      delete demes[deme.id];

      chronicle.push({
        id: `chronicle-extinct-${state.generation}-${deme.id}`,
        generation: state.generation,
        type: "extinction",
        title: `${deme.name} Extinct`,
        body: `${deme.name} fell below minimum viable population (${deme.population}) in hex (${deme.hexId}).`,
        demeId: deme.id,
        lineageId: deme.lineageId,
        hexId: deme.hexId
      });

      const hasLivingRelatives = Object.values(demes).some(
        (remaining) => remaining.lineageId === deme.lineageId
      );
      const lineageNode = lineageTree[deme.lineageId];
      if (!hasLivingRelatives && lineageNode !== undefined) {
        lineageNode.extinctGeneration = state.generation;
      }
      continue;
    }

    const initialPop = getNumericEntry(initialPopulationByDemeId, deme.id);
    const lostHalfOrMore = deme.population <= initialPop * 0.50;

    if ((lostHalfOrMore || deme.population < 50) && deme.culturalTraitIds.length > 0) {
      let highestTraitId = "";
      let highestThreshold = -1;

      for (const traitId of deme.culturalTraitIds) {
        const traitDef = state.traitsCatalog[traitId];
        const threshold =
          traitDef !== undefined ? traitDef.biophysicalVector.transmissionThreshold : 0;
        if (threshold > highestThreshold) {
          highestThreshold = threshold;
          highestTraitId = traitId;
        }
      }

      if (highestTraitId.length > 0) {
        deme.culturalTraitIds = deme.culturalTraitIds.filter((id) => id !== highestTraitId);
        const lostTraitDef = state.traitsCatalog[highestTraitId];
        const lostTraitName = lostTraitDef !== undefined ? lostTraitDef.name : highestTraitId;

        chronicle.push({
          id: `chronicle-culloss-${state.generation}-${deme.id}-${highestTraitId}`,
          generation: state.generation,
          type: "cultural_loss",
          title: `Cultural Loss: ${lostTraitName}`,
          body: `${deme.name} experienced a demographic bottleneck (pop ${deme.population}) and lost ${lostTraitName}.`,
          demeId: deme.id,
          lineageId: deme.lineageId,
          hexId: deme.hexId
        });
      }
    }
  }

  for (const deme of Object.values(demes)) {
    const cell = cells[deme.hexId];
    if (cell === undefined) {
      continue;
    }
    const vEff = computeEffectiveBiophysicalVector(deme, state, deme.lastDecisionProbabilities);

    const hasSameLineageCohabitant = cell.demeIds.some((otherId) => {
      if (otherId === deme.id) {
        return false;
      }
      const other = demes[otherId];
      return other !== undefined && other.lineageId === deme.lineageId;
    });

    const hasSameLineageInPassableNeighbor = getExistingNeighborCells(cell, cells).some(
      (neighbor) => {
        if (!isHexPassableForDeme(neighbor, vEff.spatialMobility)) {
          return false;
        }
        return neighbor.demeIds.some((otherId) => {
          const other = demes[otherId];
          return other !== undefined && other.lineageId === deme.lineageId;
        });
      }
    );

    if (
      hadLineageContactDemeIds.has(deme.id) ||
      hasSameLineageCohabitant ||
      hasSameLineageInPassableNeighbor
    ) {
      deme.isolationTurns = 0;
    } else {
      deme.isolationTurns += 1;
    }
  }

  return {
    ...state,
    cells,
    demes,
    lineageTree,
    chronicle,
    currentTurnFlows
  };
}
