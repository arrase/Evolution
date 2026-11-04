import type { BiomeType, ChronicleEntryType, HexCell, HexEdgeFlowType } from "../types/simulation";

export const BIOME_STYLES: Record<BiomeType, { fill: string; stroke: string }> = {
  tropical_forest: { fill: "#065f46", stroke: "#10b981" },
  savanna: { fill: "#92400e", stroke: "#f59e0b" },
  arid_steppe: { fill: "#b45309", stroke: "#fbbf24" },
  tundra: { fill: "#334155", stroke: "#94a3b8" },
  high_mountain: { fill: "#44403c", stroke: "#a8a29e" },
  coastal_shallows: { fill: "#0f766e", stroke: "#2dd4bf" },
  ocean: { fill: "#0f172a", stroke: "#1e3a8a" }
};

export const FLOW_STYLES: Record<HexEdgeFlowType, { stroke: string; dash: string }> = {
  migration: { stroke: "#38bdf8", dash: "6 3" },
  exchange: { stroke: "#34d399", dash: "3 3" },
  dispute: { stroke: "#f87171", dash: "4 2" }
};

export const CHRONICLE_BADGE_STYLES: Record<ChronicleEntryType, string> = {
  baldwin_trait: "bg-emerald-950/80 text-emerald-300 border-emerald-500/40",
  cultural_innovation: "bg-amber-950/80 text-amber-300 border-amber-500/40",
  allopatric_speciation: "bg-purple-950/80 text-purple-300 border-purple-500/40",
  cultural_loss: "bg-orange-950/80 text-orange-300 border-orange-500/40",
  extinction: "bg-rose-950/80 text-rose-300 border-rose-500/40",
  tragedy_of_commons: "bg-red-950/80 text-red-300 border-red-500/40",
  symbiosis: "bg-sky-950/80 text-sky-300 border-sky-500/40",
  single_survivor: "bg-fuchsia-950/80 text-fuchsia-300 border-fuchsia-500/40",
  ecological_equilibrium: "bg-teal-950/80 text-teal-300 border-teal-500/40"
};

export const FOOD_SCALE = ["#3b2a17", "#4d7c0f", "#a3e635"] as const;
export const HEALTH_SCALE = ["#b91c1c", "#d97706", "#15803d"] as const;

function mixHex(from: string, to: string, ratio: number): string {
  const channel = (hex: string, index: number) => parseInt(hex.slice(1 + index * 2, 3 + index * 2), 16);
  const mixed = [0, 1, 2].map((index) =>
    Math.round(channel(from, index) + (channel(to, index) - channel(from, index)) * ratio)
      .toString(16)
      .padStart(2, "0")
  );
  return `#${mixed.join("")}`;
}

export function colorOnScale(scale: readonly [string, string, string], ratio: number): string {
  const clamped = Math.min(1, Math.max(0, ratio));
  return clamped < 0.5
    ? mixHex(scale[0], scale[1], clamped * 2)
    : mixHex(scale[1], scale[2], (clamped - 0.5) * 2);
}

export function habitatHealthRatio(cell: HexCell): number {
  return cell.carryingCapacity / cell.carryingCapacityMax;
}
