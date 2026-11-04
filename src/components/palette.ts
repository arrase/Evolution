import type {
  BiomeType,
  ChronicleEntryType,
  DecisionArchetype,
  Deme,
  HexCell,
  HexEdgeFlowType
} from "../types/simulation";

export type DemeVitalStatus = "thriving" | "stable" | "struggling" | "starving";

export function getDemeStatus(deme: Deme): DemeVitalStatus {
  if (deme.lastEnergyDelta >= 10) {
    return "thriving";
  }
  if (deme.lastEnergyDelta >= 0) {
    return "stable";
  }
  return deme.energyReserves > 40 ? "struggling" : "starving";
}

export const DEME_STATUS_RINGS: Record<DemeVitalStatus, string> = {
  thriving: "#34d399",
  stable: "#38bdf8",
  struggling: "#fbbf24",
  starving: "#fb7185"
};

export const BIOME_STYLES: Record<BiomeType, { fill: string; stroke: string }> = {
  tropical_forest: { fill: "#065f46", stroke: "#10b981" },
  savanna: { fill: "#92400e", stroke: "#f59e0b" },
  arid_steppe: { fill: "#b45309", stroke: "#fbbf24" },
  tundra: { fill: "#334155", stroke: "#94a3b8" },
  high_mountain: { fill: "#44403c", stroke: "#a8a29e" },
  coastal_shallows: { fill: "#0f766e", stroke: "#2dd4bf" },
  ocean: { fill: "#0f172a", stroke: "#1e3a8a" }
};

export const BIOME_RELIEF_COLORS: Record<
  BiomeType,
  { topHighlight: string; skirtLeft: string; skirtRight: string; motifStroke: string }
> = {
  tropical_forest: {
    topHighlight: "#047857",
    skirtLeft: "#064e3b",
    skirtRight: "#022c22",
    motifStroke: "#6ee7b7"
  },
  savanna: {
    topHighlight: "#b45309",
    skirtLeft: "#78350f",
    skirtRight: "#451a03",
    motifStroke: "#fcd34d"
  },
  arid_steppe: {
    topHighlight: "#d97706",
    skirtLeft: "#92400e",
    skirtRight: "#78350f",
    motifStroke: "#fde68a"
  },
  tundra: {
    topHighlight: "#475569",
    skirtLeft: "#1e293b",
    skirtRight: "#0f172a",
    motifStroke: "#cbd5e1"
  },
  high_mountain: {
    topHighlight: "#57534e",
    skirtLeft: "#292524",
    skirtRight: "#1c1917",
    motifStroke: "#e7e5e4"
  },
  coastal_shallows: {
    topHighlight: "#0d9488",
    skirtLeft: "#115e59",
    skirtRight: "#134e4a",
    motifStroke: "#5eead4"
  },
  ocean: {
    topHighlight: "#1e293b",
    skirtLeft: "#0f172a",
    skirtRight: "#020617",
    motifStroke: "#38bdf8"
  }
};

export const DECISION_ARCHETYPE_VISUALS: Record<
  DecisionArchetype,
  { color: string; bg: string; glyphPath: string }
> = {
  forage: {
    color: "#4ade80",
    bg: "#052e16",
    glyphPath: "M 0 3.5 L 0 -3 M 0 -1 C -3 -3.5 -4 0 0 1 M 0 -2 C 3 -4 4 -0.5 0 0.5"
  },
  overexploit: {
    color: "#fb923c",
    bg: "#431407",
    glyphPath: "M -3 -1 L 0 3 L 3 -1 M -3 -3.5 L 0 0.5 L 3 -3.5"
  },
  migrate: {
    color: "#38bdf8",
    bg: "#082f49",
    glyphPath: "M -3.5 0 L 3 0 M 0.5 -3 L 3.5 0 L 0.5 3"
  },
  cooperate: {
    color: "#60a5fa",
    bg: "#172554",
    glyphPath: "M -3.2 0 A 2.2 2.2 0 1 0 1.2 0 A 2.2 2.2 0 1 0 -3.2 0 M -1.2 0 A 2.2 2.2 0 1 0 3.2 0 A 2.2 2.2 0 1 0 -1.2 0"
  },
  exchange: {
    color: "#34d399",
    bg: "#022c22",
    glyphPath: "M -3 -1.5 L 3 -1.5 L 1 -3.5 M 3 1.5 L -3 1.5 L -1 3.5"
  },
  dispute: {
    color: "#f87171",
    bg: "#450a0a",
    glyphPath: "M -3 -3 L 3 3 M 3 -3 L -3 3"
  },
  innovate: {
    color: "#c084fc",
    bg: "#3b0764",
    glyphPath: "M 0 -4 L 1.1 -1.1 L 4 0 L 1.1 1.1 L 0 4 L -1.1 1.1 L -4 0 L -1.1 -1.1 Z"
  },
  custom: {
    color: "#facc15",
    bg: "#422006",
    glyphPath: "M 0 -3.5 L 3.5 0 L 0 3.5 L -3.5 0 Z"
  }
};

export const FLOW_STYLES: Record<HexEdgeFlowType, { stroke: string; dash: string; bg: string; glyphPath: string }> = {
  migration: {
    stroke: "#38bdf8",
    dash: "6 3",
    bg: "#082f49",
    glyphPath: "M -3 0 L 2.5 0 M 0 -2.5 L 3 0 L 0 2.5"
  },
  exchange: {
    stroke: "#34d399",
    dash: "4 3",
    bg: "#022c22",
    glyphPath: "M -2.5 -1.3 L 2.5 -1.3 M 2.5 1.3 L -2.5 1.3"
  },
  dispute: {
    stroke: "#f87171",
    dash: "4 2",
    bg: "#450a0a",
    glyphPath: "M -2.5 -2.5 L 2.5 2.5 M 2.5 -2.5 L -2.5 2.5"
  }
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
