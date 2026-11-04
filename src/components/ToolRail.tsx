import { useEffect, useState, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import {
  BookOpen,
  Eye,
  FlaskConical,
  GitBranch,
  Mountain,
  Sprout,
  Trees,
  Waves,
  Zap,
  type LucideIcon
} from "lucide-react";
import { SEA_LEVEL_COST, useSimulationStore } from "../store/useSimulationStore";
import { BiomeTypeSchema, type BiomeType, type BrushTool } from "../types/simulation";
import { BIOME_STYLES } from "./palette";
import { Tooltip } from "./Tooltip";

type ToolId = "observe" | "climate" | "terrain" | "food" | "sea";

const TOOL_ICONS: Record<ToolId, LucideIcon> = {
  observe: Eye,
  climate: Trees,
  terrain: Mountain,
  food: Sprout,
  sea: Waves
};

const TOOL_BY_BRUSH: Record<BrushTool["kind"], ToolId> = {
  inspect: "observe",
  set_biome: "climate",
  adjust_altitude: "terrain",
  adjust_carrying_capacity: "food"
};

const CLIMATE_COST = 10;
const TERRAIN_COST = 15;
const FOOD_COST = 10;
const ALTITUDE_STEP = 0.18;
const FOOD_STEP = 0.25;

const SEGMENT_CLASS = "flex-1 rounded-md px-2 py-1.5 text-xs font-medium cursor-pointer";

function segmentClass(isActive: boolean): string {
  return `${SEGMENT_CLASS} ${isActive ? "bg-emerald-600 text-white" : "text-slate-300 hover:bg-slate-800"}`;
}

export function ToolRail() {
  const { t } = useTranslation();
  const world = useSimulationStore((s) => s.world);
  const activeBrush = useSimulationStore((s) => s.activeBrush);
  const activeModal = useSimulationStore((s) => s.activeModal);
  const chronicleSeenCount = useSimulationStore((s) => s.chronicleSeenCount);
  const setActiveBrush = useSimulationStore((s) => s.setActiveBrush);
  const adjustSeaLevel = useSimulationStore((s) => s.adjustSeaLevel);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);

  const [isSeaOpen, setIsSeaOpen] = useState(false);
  const [radius, setRadius] = useState<1 | 2>(1);
  const [biome, setBiome] = useState<BiomeType>("savanna");

  const activeTool: ToolId = isSeaOpen ? "sea" : TOOL_BY_BRUSH[activeBrush.kind];
  const energy = world.selectivePressurePoints;
  const canAfford = (cost: number) => world.unlimitedPressureMode || energy >= cost;
  const unreadCount = world.chronicle.length - chronicleSeenCount;

  function selectTool(tool: ToolId) {
    const nextTool = tool === activeTool ? "observe" : tool;
    setIsSeaOpen(nextTool === "sea");
    if (nextTool === "climate") {
      setActiveBrush({ kind: "set_biome", biome, radius, cost: CLIMATE_COST });
    } else if (nextTool === "terrain") {
      setActiveBrush({ kind: "adjust_altitude", delta: ALTITUDE_STEP, radius, cost: TERRAIN_COST });
    } else if (nextTool === "food") {
      setActiveBrush({ kind: "adjust_carrying_capacity", deltaFactor: FOOD_STEP, radius, cost: FOOD_COST });
    } else {
      setActiveBrush({ kind: "inspect" });
    }
  }

  function changeRadius(nextRadius: 1 | 2) {
    setRadius(nextRadius);
    if (activeBrush.kind !== "inspect") {
      setActiveBrush({ ...activeBrush, radius: nextRadius });
    }
  }

  function changeBiome(nextBiome: BiomeType) {
    setBiome(nextBiome);
    setActiveBrush({ kind: "set_biome", biome: nextBiome, radius, cost: CLIMATE_COST });
  }

  useEffect(() => {
    setIsSeaOpen(false);
  }, [world.presetId, activeModal]);

  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape" && activeModal === "none") {
        setIsSeaOpen(false);
        setActiveBrush({ kind: "inspect" });
      }
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [activeModal, setActiveBrush]);

  function renderBrushFooter(cost: number) {
    return (
      <div className="space-y-2 border-t border-slate-800 pt-3">
        <div className="flex items-center justify-between text-xs">
          <span className="text-slate-400">{t("tools.brushSize")}</span>
          <div className="flex w-36 gap-1 rounded-lg bg-slate-950 p-0.5">
            <button type="button" aria-pressed={radius === 1} onClick={() => changeRadius(1)} className={segmentClass(radius === 1)}>
              {t("tools.brushSmall")}
            </button>
            <button type="button" aria-pressed={radius === 2} onClick={() => changeRadius(2)} className={segmentClass(radius === 2)}>
              {t("tools.brushLarge")}
            </button>
          </div>
        </div>
        <p className="flex items-center gap-1.5 text-xs text-amber-300">
          <Zap className="w-3.5 h-3.5" />
          {t("tools.costPerClick", { cost })}
        </p>
        {!canAfford(cost) && <p className="text-xs text-rose-300">{t("tools.notEnoughEnergy")}</p>}
      </div>
    );
  }

  function renderFlyout(): ReactNode {
    if (activeTool === "climate" && activeBrush.kind === "set_biome") {
      return (
        <>
          <div className="grid grid-cols-2 gap-1.5">
            {BiomeTypeSchema.options.map((option) => (
              <button
                key={option}
                type="button"
                aria-pressed={activeBrush.biome === option}
                onClick={() => changeBiome(option)}
                className={`flex items-center gap-2 rounded-md border px-2 py-1.5 text-left text-xs cursor-pointer ${
                  activeBrush.biome === option
                    ? "border-emerald-400 bg-emerald-500/15 text-white"
                    : "border-slate-800 text-slate-300 hover:bg-slate-800"
                }`}
              >
                <span
                  className="h-3.5 w-3.5 shrink-0 rounded-sm border"
                  style={{ backgroundColor: BIOME_STYLES[option].fill, borderColor: BIOME_STYLES[option].stroke }}
                />
                <span className="truncate">{t(`biomes.${option}`)}</span>
              </button>
            ))}
          </div>
          {renderBrushFooter(CLIMATE_COST)}
        </>
      );
    }

    if (activeTool === "terrain" && activeBrush.kind === "adjust_altitude") {
      const isRaising = activeBrush.delta > 0;
      return (
        <>
          <div className="flex gap-1 rounded-lg bg-slate-950 p-0.5">
            <button
              type="button"
              aria-pressed={isRaising}
              onClick={() => setActiveBrush({ ...activeBrush, delta: ALTITUDE_STEP })}
              className={segmentClass(isRaising)}
            >
              {t("tools.raiseLand")}
            </button>
            <button
              type="button"
              aria-pressed={!isRaising}
              onClick={() => setActiveBrush({ ...activeBrush, delta: -ALTITUDE_STEP })}
              className={segmentClass(!isRaising)}
            >
              {t("tools.lowerLand")}
            </button>
          </div>
          {renderBrushFooter(TERRAIN_COST)}
        </>
      );
    }

    if (activeTool === "food" && activeBrush.kind === "adjust_carrying_capacity") {
      const isAdding = activeBrush.deltaFactor > 0;
      return (
        <>
          <div className="flex gap-1 rounded-lg bg-slate-950 p-0.5">
            <button
              type="button"
              aria-pressed={isAdding}
              onClick={() => setActiveBrush({ ...activeBrush, deltaFactor: FOOD_STEP })}
              className={segmentClass(isAdding)}
            >
              {t("tools.addFood")}
            </button>
            <button
              type="button"
              aria-pressed={!isAdding}
              onClick={() => setActiveBrush({ ...activeBrush, deltaFactor: -FOOD_STEP })}
              className={segmentClass(!isAdding)}
            >
              {t("tools.removeFood")}
            </button>
          </div>
          {renderBrushFooter(FOOD_COST)}
        </>
      );
    }

    return (
      <>
        <div className="flex items-baseline justify-between">
          <span className="text-xs text-slate-400">{t("tools.currentSeaLevel")}</span>
          <span className="font-mono text-lg font-bold text-sky-300">{Math.round(world.seaLevel * 100)}%</span>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            disabled={!canAfford(SEA_LEVEL_COST) || world.seaLevel >= 0.5}
            onClick={() => adjustSeaLevel(0.05)}
            className="flex-1 rounded-lg bg-sky-700 px-3 py-2 text-xs font-semibold text-white hover:bg-sky-600 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
          >
            {t("tools.raiseSea")}
          </button>
          <button
            type="button"
            disabled={!canAfford(SEA_LEVEL_COST) || world.seaLevel <= 0}
            onClick={() => adjustSeaLevel(-0.05)}
            className="flex-1 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs font-semibold text-slate-200 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
          >
            {t("tools.lowerSea")}
          </button>
        </div>
        <p className="flex items-center gap-1.5 border-t border-slate-800 pt-3 text-xs text-amber-300">
          <Zap className="w-3.5 h-3.5" />
          {t("tools.costPerChange", { cost: SEA_LEVEL_COST })}
        </p>
        {!canAfford(SEA_LEVEL_COST) && <p className="text-xs text-rose-300">{t("tools.notEnoughEnergy")}</p>}
      </>
    );
  }

  function renderRailButton(
    id: string,
    Icon: LucideIcon,
    label: string,
    hint: string,
    isActive: boolean,
    onClick: () => void,
    badge: number
  ) {
    return (
      <Tooltip id={`tip-${id}`} side="right" text={hint}>
        <button
          type="button"
          aria-pressed={isActive}
          aria-describedby={`tip-${id}`}
          onClick={onClick}
          className={`relative flex w-16 flex-col items-center gap-1 rounded-lg px-1 py-2 text-[11px] font-medium cursor-pointer transition-colors ${
            isActive ? "bg-emerald-500/20 text-emerald-200 ring-1 ring-emerald-400/60" : "text-slate-400 hover:bg-slate-800 hover:text-slate-100"
          }`}
        >
          <Icon className="w-5 h-5" />
          <span className="leading-tight">{label}</span>
          {badge > 0 && (
            <span className="absolute right-1 top-1 min-w-4 rounded-full bg-amber-500 px-1 text-[10px] font-bold leading-4 text-slate-950">
              {badge}
            </span>
          )}
        </button>
      </Tooltip>
    );
  }

  return (
    <nav
      aria-label={t("tools.label")}
      className="relative z-30 flex w-20 shrink-0 flex-col items-center gap-1 border-r border-slate-800 bg-slate-900 py-2"
    >
      <Tooltip id="tip-energy" side="right" text={t("tools.energyHint", { regen: world.selectivePressureRegenPerTurn })}>
        <div
          tabIndex={0}
          aria-describedby="tip-energy"
          className="mb-1 flex w-16 flex-col items-center rounded-lg border border-amber-500/30 bg-amber-950/30 px-1 py-1.5"
        >
          <span className="flex items-center gap-1 text-[10px] uppercase tracking-wide text-amber-300/80">
            <Zap className="w-3 h-3" />
            {t("tools.energy")}
          </span>
          <span className="font-mono text-base font-bold text-amber-200">
            {world.unlimitedPressureMode ? "∞" : energy}
          </span>
          <span className="font-mono text-[10px] text-amber-300/70">
            {t("tools.perGeneration", { regen: world.selectivePressureRegenPerTurn })}
          </span>
        </div>
      </Tooltip>

      {(Object.keys(TOOL_ICONS) as ToolId[]).map((tool) => (
        <div key={tool}>
          {renderRailButton(
            tool,
            TOOL_ICONS[tool],
            t(`tools.${tool}`),
            t(`tools.${tool}Hint`),
            activeTool === tool,
            () => selectTool(tool),
            0
          )}
        </div>
      ))}

      <div className="flex-1" />

      {renderRailButton("chronicle", BookOpen, t("tools.chronicle"), t("tools.chronicleHint"), false, () => setActiveModal("naturalist_notebook"), unreadCount)}
      {renderRailButton("tree", GitBranch, t("tools.familyTree"), t("tools.familyTreeHint"), false, () => setActiveModal("phylo_tree"), 0)}
      {renderRailButton("lab", FlaskConical, t("tools.lab"), t("tools.labHint"), false, () => setActiveModal("catalog_lab"), 0)}

      {activeTool !== "observe" && (
        <section
          aria-label={t(`tools.${activeTool}Title`)}
          className="absolute left-full top-2 ml-2 w-72 space-y-3 rounded-xl border border-slate-700 bg-slate-900/95 p-4 shadow-2xl backdrop-blur"
        >
          <header>
            <h2 className="text-sm font-semibold text-slate-100">{t(`tools.${activeTool}Title`)}</h2>
            <p className="mt-1 text-xs leading-relaxed text-slate-400">{t(`tools.${activeTool}Description`)}</p>
          </header>
          {renderFlyout()}
        </section>
      )}
    </nav>
  );
}
