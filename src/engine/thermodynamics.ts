import { BiophysicalVector } from "../types/simulation";

function clampAndRound(value: number, min: number, max: number): number {
  const clamped = Math.min(max, Math.max(min, value));
  return Number(clamped.toFixed(4));
}

function clampVector(vector: BiophysicalVector): BiophysicalVector {
  return {
    metabolicCost: clampAndRound(vector.metabolicCost, -1.0, 1.0),
    extractionEfficiency: clampAndRound(vector.extractionEfficiency, -1.0, 1.0),
    ecologicalImpact: clampAndRound(vector.ecologicalImpact, -1.0, 1.0),
    spatialMobility: clampAndRound(vector.spatialMobility, -1.0, 1.0),
    socialCohesion: clampAndRound(vector.socialCohesion, -1.0, 1.0),
    transmissionThreshold: clampAndRound(vector.transmissionThreshold, 0.0, 1.0)
  };
}

export function computeThermodynamicMetrics(vector: BiophysicalVector): {
  positiveAdvantages: number;
  currentCompensatoryCost: number;
  requiredCompensatoryCost: number;
  isBalanced: boolean;
} {
  const clamped = clampVector(vector);
  const positiveAdvantages = Number(
    (
      Math.max(0, clamped.extractionEfficiency) +
      Math.max(0, clamped.spatialMobility) +
      Math.max(0, clamped.socialCohesion)
    ).toFixed(4)
  );
  const currentCompensatoryCost = Number(
    (clamped.metabolicCost - Math.min(0, clamped.ecologicalImpact)).toFixed(4)
  );
  const requiredCompensatoryCost =
    positiveAdvantages > 0.6
      ? Number((0.5 * (positiveAdvantages - 0.6)).toFixed(4))
      : 0;
  const isBalanced =
    positiveAdvantages <= 0.6 ||
    currentCompensatoryCost >= requiredCompensatoryCost - 1e-6;

  return {
    positiveAdvantages,
    currentCompensatoryCost,
    requiredCompensatoryCost,
    isBalanced
  };
}

export function validateAndBalanceThermodynamics(
  vector: BiophysicalVector,
  freeSandboxMode: boolean
): {
  balancedVector: BiophysicalVector;
  wasAdjusted: boolean;
  requiredCompensation: number;
} {
  const clamped = clampVector(vector);
  const metrics = computeThermodynamicMetrics(clamped);

  if (freeSandboxMode || metrics.isBalanced) {
    return {
      balancedVector: clamped,
      wasAdjusted: false,
      requiredCompensation: metrics.requiredCompensatoryCost
    };
  }

  const requiredCompensation = metrics.requiredCompensatoryCost;
  const targetMetabolic = requiredCompensation + Math.min(0, clamped.ecologicalImpact);
  const adjustedMetabolicCost = Math.min(1.0, Number(targetMetabolic.toFixed(4)));
  let adjustedEcologicalImpact = clamped.ecologicalImpact;

  if (targetMetabolic > 1.0) {
    const excess = targetMetabolic - 1.0;
    const baseEcologicalImpact = Math.min(0, clamped.ecologicalImpact);
    adjustedEcologicalImpact = Math.max(
      -1.0,
      Number((baseEcologicalImpact - excess).toFixed(4))
    );
  }

  return {
    balancedVector: {
      ...clamped,
      metabolicCost: adjustedMetabolicCost,
      ecologicalImpact: adjustedEcologicalImpact
    },
    wasAdjusted: true,
    requiredCompensation
  };
}
