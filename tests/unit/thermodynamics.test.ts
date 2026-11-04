import { describe, expect, it } from "vitest";
import {
  computeThermodynamicMetrics,
  validateAndBalanceThermodynamics
} from "../../src/engine/thermodynamics";
import { BiophysicalVector } from "../../src/types/simulation";

describe("thermodynamics validation and auto-compensation", () => {
  it("keeps balanced vectors with advantages <= 0.60 unchanged", () => {
    const vector: BiophysicalVector = {
      metabolicCost: 0.1,
      extractionEfficiency: 0.35,
      ecologicalImpact: 0.1,
      spatialMobility: 0.0,
      socialCohesion: 0.05,
      transmissionThreshold: 0.05
    };

    const metrics = computeThermodynamicMetrics(vector);
    expect(metrics.positiveAdvantages).toBeCloseTo(0.4, 4);
    expect(metrics.requiredCompensatoryCost).toBe(0);
    expect(metrics.isBalanced).toBe(true);

    const result = validateAndBalanceThermodynamics(vector, false);
    expect(result.wasAdjusted).toBe(false);
    expect(result.requiredCompensation).toBe(0);
    expect(result.balancedVector).toEqual(vector);
  });

  it("keeps vectors with advantages > 0.60 unchanged when metabolicCost or negative ecologicalImpact already compensates", () => {
    const vectorWithMetabolicCompensation: BiophysicalVector = {
      metabolicCost: 0.45,
      extractionEfficiency: 0.35,
      ecologicalImpact: 0.0,
      spatialMobility: 0.2,
      socialCohesion: 0.45,
      transmissionThreshold: 0.6
    };

    const resultMetabolic = validateAndBalanceThermodynamics(vectorWithMetabolicCompensation, false);
    expect(resultMetabolic.wasAdjusted).toBe(false);
    expect(resultMetabolic.requiredCompensation).toBeCloseTo(0.2, 4);
    expect(resultMetabolic.balancedVector).toEqual(vectorWithMetabolicCompensation);

    const vectorWithEcologicalCompensation: BiophysicalVector = {
      metabolicCost: -0.1,
      extractionEfficiency: 0.35,
      ecologicalImpact: -0.25,
      spatialMobility: 0.1,
      socialCohesion: 0.25,
      transmissionThreshold: 0.4
    };

    const resultEco = validateAndBalanceThermodynamics(vectorWithEcologicalCompensation, false);
    expect(resultEco.wasAdjusted).toBe(false);
    expect(resultEco.requiredCompensation).toBeCloseTo(0.05, 4);
    expect(resultEco.balancedVector).toEqual(vectorWithEcologicalCompensation);
  });

  it("auto-compensates unbalanced cheat vectors when freeSandboxMode is false", () => {
    const cheatVector: BiophysicalVector = {
      metabolicCost: -0.2,
      extractionEfficiency: 0.9,
      ecologicalImpact: 0.2,
      spatialMobility: 0.8,
      socialCohesion: 0.7,
      transmissionThreshold: 0.5
    };

    const result = validateAndBalanceThermodynamics(cheatVector, false);
    const positiveAdvantages = 0.9 + 0.8 + 0.7;
    const expectedRequired = 0.5 * (positiveAdvantages - 0.6);

    expect(result.wasAdjusted).toBe(true);
    expect(result.requiredCompensation).toBeCloseTo(expectedRequired, 4);
    expect(result.balancedVector.metabolicCost).toBeCloseTo(0.9, 4);

    const finalCompensatoryCost =
      result.balancedVector.metabolicCost - Math.min(0, result.balancedVector.ecologicalImpact);
    expect(finalCompensatoryCost).toBeGreaterThanOrEqual(expectedRequired - 1e-6);
  });

  it("adjusts ecologicalImpact downward when metabolicCost reaches 1.0 and is still insufficient", () => {
    const extremeVector: BiophysicalVector = {
      metabolicCost: 0.0,
      extractionEfficiency: 1.0,
      ecologicalImpact: 0.5,
      spatialMobility: 1.0,
      socialCohesion: 1.0,
      transmissionThreshold: 0.5
    };

    const result = validateAndBalanceThermodynamics(extremeVector, false);
    expect(result.wasAdjusted).toBe(true);
    expect(result.requiredCompensation).toBeCloseTo(1.2, 4);
    expect(result.balancedVector.metabolicCost).toBe(1.0);
    expect(result.balancedVector.ecologicalImpact).toBeCloseTo(-0.2, 4);

    const finalCompensatoryCost =
      result.balancedVector.metabolicCost - Math.min(0, result.balancedVector.ecologicalImpact);
    expect(finalCompensatoryCost).toBeGreaterThanOrEqual(result.requiredCompensation - 1e-6);
  });

  it("bypasses auto-compensation when freeSandboxMode is true while clamping axis bounds", () => {
    const outOfBoundsCheatVector: BiophysicalVector = {
      metabolicCost: -1.5,
      extractionEfficiency: 1.8,
      ecologicalImpact: 1.2,
      spatialMobility: 0.95,
      socialCohesion: 0.85,
      transmissionThreshold: 1.4
    };

    const result = validateAndBalanceThermodynamics(outOfBoundsCheatVector, true);
    expect(result.wasAdjusted).toBe(false);
    expect(result.balancedVector).toEqual({
      metabolicCost: -1.0,
      extractionEfficiency: 1.0,
      ecologicalImpact: 1.0,
      spatialMobility: 0.95,
      socialCohesion: 0.85,
      transmissionThreshold: 1.0
    });
  });
});
