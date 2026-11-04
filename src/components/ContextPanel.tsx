import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  ChevronRight,
  Dna,
  GitBranch,
  PanelRightClose,
  PanelRightOpen,
  Plus,
  ScrollText
} from "lucide-react";
import { demeHasCulturalCapacity } from "../catalog/baseTraits";
import { useSimulationStore } from "../store/useSimulationStore";
import type { Deme, HexCell } from "../types/simulation";
import { type DemeVitalStatus, getDemeStatus, habitatHealthRatio } from "./palette";
import { InfoHint } from "./Tooltip";

const STATUS_STYLES: Record<DemeVitalStatus, string> = {
  thriving: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
  stable: "bg-sky-500/15 text-sky-300 border-sky-500/40",
  struggling: "bg-amber-500/15 text-amber-300 border-amber-500/40",
  starving: "bg-rose-500/15 text-rose-300 border-rose-500/40"
};

const STATUS_DOTS: Record<DemeVitalStatus, string> = {
  thriving: "bg-emerald-400",
  stable: "bg-sky-400",
  struggling: "bg-amber-400",
  starving: "bg-rose-400"
};

const VISIBLE_BEHAVIORS = 3;
const SECTION_CLASS = "rounded-lg border border-slate-800 bg-slate-800/40 p-3";
const DISCLOSURE_SUMMARY_CLASS =
  "flex cursor-pointer list-none items-center gap-2 text-xs font-semibold text-slate-200 [&::-webkit-details-marker]:hidden";

function ProgressBar({ percent, colorClass }: { percent: number; colorClass: string }) {
  return (
    <div className="h-1.5 w-full overflow-hidden rounded-full bg-slate-950">
      <div className={`h-full transition-all ${colorClass}`} style={{ width: `${Math.min(100, percent)}%` }} />
    </div>
  );
}

export function ContextPanel() {
  const { t } = useTranslation();
  const world = useSimulationStore((s) => s.world);
  const selectedHexId = useSimulationStore((s) => s.selectedHexId);
  const selectedDemeId = useSimulationStore((s) => s.selectedDemeId);
  const highlightedLineageId = useSimulationStore((s) => s.highlightedLineageId);
  const selectDeme = useSimulationStore((s) => s.selectDeme);
  const setHighlightedLineageId = useSimulationStore((s) => s.setHighlightedLineageId);
  const injectTraitIntoDeme = useSimulationStore((s) => s.injectTraitIntoDeme);

  const [isCollapsed, setIsCollapsed] = useState(false);
  const [chosenTraitId, setChosenTraitId] = useState("");
  const selectedDeme = selectedDemeId !== null ? world.demes[selectedDemeId] : undefined;

  useEffect(() => {
    setChosenTraitId("");
  }, [selectedDemeId]);

  useEffect(() => {
    if (
      chosenTraitId !== "" &&
      (selectedDeme === undefined ||
        world.traitsCatalog[chosenTraitId] === undefined ||
        selectedDeme.biologicalTraitIds.includes(chosenTraitId) ||
        selectedDeme.culturalTraitIds.includes(chosenTraitId))
    ) {
      setChosenTraitId("");
    }
  }, [chosenTraitId, selectedDeme, world.traitsCatalog]);

  if (isCollapsed) {
    return (
      <aside className="flex w-11 shrink-0 flex-col items-center border-l border-slate-800 bg-slate-900 py-2">
        <button
          type="button"
          onClick={() => setIsCollapsed(false)}
          aria-label={t("panel.expand")}
          className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <PanelRightOpen className="w-5 h-5" />
        </button>
      </aside>
    );
  }

  const demes = Object.values(world.demes);
  const cell = selectedHexId !== null ? world.cells[selectedHexId] : undefined;

  function traitName(traitId: string): string {
    const trait = world.traitsCatalog[traitId]!;
    return trait.origin === "base" ? t(`catalog.traits.${traitId}.name`, { defaultValue: trait.name }) : trait.name;
  }

  function traitDescription(traitId: string): string {
    const trait = world.traitsCatalog[traitId]!;
    return trait.origin === "base"
      ? t(`catalog.traits.${traitId}.semanticDescriptor`, { defaultValue: trait.semanticDescriptor })
      : trait.semanticDescriptor;
  }

  function decisionName(decisionId: string): string {
    const decision = world.decisionsCatalog[decisionId]!;
    return decision.origin === "base"
      ? t(`catalog.decisions.${decisionId}.name`, { defaultValue: decision.name })
      : decision.name;
  }

  function renderPopulationList() {
    return (
      <section aria-labelledby="populations-heading" className="space-y-1.5">
        <h3 id="populations-heading" className="text-xs font-semibold uppercase tracking-wider text-slate-400">
          {t("panel.populations")} ({demes.length})
        </h3>
        {demes.length === 0 ? (
          <p className="text-xs text-slate-400">{t("panel.noPopulations")}</p>
        ) : (
          <ul className="max-h-44 space-y-0.5 overflow-y-auto pr-1">
            {demes.map((deme) => (
              <li key={deme.id}>
                <button
                  type="button"
                  aria-pressed={deme.id === selectedDemeId}
                  onClick={() => selectDeme(deme.id)}
                  className={`flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left text-xs cursor-pointer ${
                    deme.id === selectedDemeId ? "bg-slate-700 text-white" : "text-slate-300 hover:bg-slate-800"
                  }`}
                >
                  <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: deme.color }} />
                  <span className="flex-1 truncate">{deme.name}</span>
                  <span className="font-mono text-slate-300">{deme.population}</span>
                  <span
                    className={`h-1.5 w-1.5 rounded-full ${STATUS_DOTS[getDemeStatus(deme)]}`}
                    aria-label={t(`panel.status.${getDemeStatus(deme)}`)}
                  />
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    );
  }

  function renderTraitList(traitIds: string[], accentClass: string) {
    if (traitIds.length === 0) {
      return <p className="text-xs text-slate-500">{t("panel.noTraits")}</p>;
    }
    return (
      <ul className="space-y-1">
        {traitIds.map((traitId) => (
          <li key={traitId} className="rounded-md bg-slate-900/70 px-2 py-1.5">
            <div className={`text-xs font-medium ${accentClass}`}>{traitName(traitId)}</div>
            <div className="line-clamp-2 text-[11px] text-slate-400" title={traitDescription(traitId)}>
              {traitDescription(traitId)}
            </div>
          </li>
        ))}
      </ul>
    );
  }

  function renderDeme(deme: Deme) {
    const status = getDemeStatus(deme);
    const sortedBehaviors = Object.entries(deme.lastDecisionProbabilities).sort((a, b) => b[1] - a[1]);
    const [dominantId, dominantProbability] = sortedBehaviors[0]!;
    const hasCulturalCapacity = demeHasCulturalCapacity(deme, world.traitsCatalog);
    const baldwinMax = Math.max(0, ...Object.values(deme.baldwinCounters));
    const culturalPercent = hasCulturalCapacity ? Math.min(1, deme.innovationCounter) * 100 : 0;
    const milestoneProgress = [
      {
        key: "geneticAdaptation",
        percent: (Math.min(8, baldwinMax) / 8) * 100,
        color: "bg-cyan-400",
        label: `${Math.min(8, baldwinMax)} / 8`
      },
      {
        key: "culturalInnovation",
        percent: culturalPercent,
        color: "bg-purple-400",
        label: `${Math.round(culturalPercent)}%`
      },
      {
        key: "isolation",
        percent: (Math.min(10, deme.isolationTurns) / 10) * 100,
        color: "bg-amber-400",
        label: `${Math.min(10, deme.isolationTurns)} / 10`
      }
    ];
    const closestMilestone = Math.round(Math.min(100, Math.max(...milestoneProgress.map((m) => m.percent))));

    const availableTraits = Object.values(world.traitsCatalog).filter(
      (trait) => !deme.biologicalTraitIds.includes(trait.id) && !deme.culturalTraitIds.includes(trait.id)
    );
    const chosenTrait = chosenTraitId !== "" ? world.traitsCatalog[chosenTraitId] : undefined;
    const needsCulturalCapacity =
      chosenTrait !== undefined && chosenTrait.category === "cultural" && !hasCulturalCapacity;
    const isFamilyHighlighted = highlightedLineageId === deme.lineageId;

    return (
      <div className="space-y-3">
        {/* Identity & status */}
        <div className={SECTION_CLASS}>
          <div className="flex items-start justify-between gap-2">
            <div className="flex min-w-0 items-center gap-2">
              <span className="h-3.5 w-3.5 shrink-0 rounded-full" style={{ backgroundColor: deme.color }} />
              <h3 className="truncate text-sm font-semibold text-white">{deme.name}</h3>
            </div>
            <span className={`shrink-0 rounded-full border px-2 py-0.5 text-[11px] font-semibold ${STATUS_STYLES[status]}`}>
              {t(`panel.status.${status}`)}
            </span>
          </div>
          <dl className="mt-3 grid grid-cols-3 gap-2 text-xs">
            <div>
              <dt className="text-slate-400">{t("panel.population")}</dt>
              <dd className="font-mono text-sm font-bold text-white">{deme.population}</dd>
            </div>
            <div>
              <dt className="text-slate-400">{t("panel.reserves")}</dt>
              <dd className="font-mono text-sm font-bold text-white">{Math.round(deme.energyReserves)}</dd>
            </div>
            <div>
              <dt className="text-slate-400">{t("panel.trend")}</dt>
              <dd className={`font-mono text-sm font-bold ${deme.lastEnergyDelta >= 0 ? "text-emerald-400" : "text-rose-400"}`}>
                {deme.lastEnergyDelta >= 0 ? "+" : ""}
                {deme.lastEnergyDelta.toFixed(1)}
              </dd>
            </div>
          </dl>
          <button
            type="button"
            aria-pressed={isFamilyHighlighted}
            onClick={() => setHighlightedLineageId(isFamilyHighlighted ? null : deme.lineageId)}
            className="mt-3 inline-flex items-center gap-1.5 text-xs text-amber-300 hover:underline cursor-pointer"
          >
            <GitBranch className="w-3.5 h-3.5" />
            {isFamilyHighlighted ? t("panel.hideFamily") : t("panel.showFamily")}
          </button>
        </div>

        {/* Behaviour */}
        <section className={SECTION_CLASS}>
          <div className="flex items-center justify-between">
            <h4 className="text-xs font-semibold text-slate-200">{t("panel.behaviorTitle")}</h4>
            <InfoHint text={t("panel.behaviorHint")} />
          </div>
          <p className="mt-1.5 text-sm text-white">
            {t("panel.mostly")} <strong className="text-emerald-300">{decisionName(dominantId)}</strong>{" "}
            <span className="font-mono text-slate-400">({Math.round(dominantProbability * 100)}%)</span>
          </p>
          <ul className="mt-2.5 space-y-2">
            {sortedBehaviors.slice(0, VISIBLE_BEHAVIORS).map(([decisionId, probability]) => (
              <li key={decisionId} className="space-y-1">
                <div className="flex justify-between gap-2 text-xs">
                  <span className="truncate text-slate-300">{decisionName(decisionId)}</span>
                  <span className="font-mono text-slate-400">{(probability * 100).toFixed(1)}%</span>
                </div>
                <ProgressBar percent={probability * 100} colorClass={decisionId === dominantId ? "bg-emerald-400" : "bg-slate-500"} />
              </li>
            ))}
          </ul>
          {sortedBehaviors.length > VISIBLE_BEHAVIORS && (
            <details className="mt-2">
              <summary className="cursor-pointer text-xs text-slate-400 hover:text-slate-200">
                {t("panel.showAll", { count: sortedBehaviors.length })}
              </summary>
              <ul className="mt-2 space-y-2">
                {sortedBehaviors.slice(VISIBLE_BEHAVIORS).map(([decisionId, probability]) => (
                  <li key={decisionId} className="space-y-1">
                    <div className="flex justify-between gap-2 text-xs">
                      <span className="truncate text-slate-300">{decisionName(decisionId)}</span>
                      <span className="font-mono text-slate-400">{(probability * 100).toFixed(1)}%</span>
                    </div>
                    <ProgressBar percent={probability * 100} colorClass="bg-slate-500" />
                  </li>
                ))}
              </ul>
            </details>
          )}
          <div className="mt-3 border-t border-slate-800 pt-2.5">
            <h4 className="text-xs font-semibold text-slate-200">{t("panel.whyTitle")}</h4>
            <p className="mt-1 text-xs italic leading-relaxed text-slate-300">{deme.lastJustification}</p>
          </div>
        </section>

        {/* Traits */}
        <section className={`${SECTION_CLASS} space-y-3`}>
          <div>
            <h4 className="mb-1.5 flex items-center gap-1.5 text-xs font-semibold text-emerald-300">
              <Dna className="w-3.5 h-3.5" />
              {t("panel.biological")}
            </h4>
            {renderTraitList(deme.biologicalTraitIds, "text-emerald-200")}
          </div>
          <div>
            <h4 className="mb-1.5 flex items-center gap-1.5 text-xs font-semibold text-purple-300">
              <ScrollText className="w-3.5 h-3.5" />
              {t("panel.cultural")}
            </h4>
            {renderTraitList(deme.culturalTraitIds, "text-purple-200")}
          </div>
          <details className="border-t border-slate-800 pt-2.5">
            <summary className={DISCLOSURE_SUMMARY_CLASS}>
              <Plus className="w-3.5 h-3.5 text-indigo-300" />
              {t("panel.addTrait")}
            </summary>
            <div className="mt-2 space-y-1.5">
              <p className="text-[11px] text-slate-400">{t("panel.addTraitHint")}</p>
              <div className="flex gap-1.5">
                <select
                  id="panel-trait-select"
                  name="injectTraitId"
                  aria-label={t("panel.selectTraitPlaceholder")}
                  value={chosenTraitId}
                  onChange={(e) => setChosenTraitId(e.target.value)}
                  className="min-w-0 flex-1 rounded-md border border-slate-700 bg-slate-900 px-2 py-1 text-xs text-slate-200"
                >
                  <option value="">{t("panel.selectTraitPlaceholder")}</option>
                  {availableTraits.map((trait) => (
                    <option key={trait.id} value={trait.id}>
                      {traitName(trait.id)} · {trait.category === "biological" ? t("panel.biological") : t("panel.cultural")}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  disabled={chosenTraitId === "" || needsCulturalCapacity}
                  onClick={() => {
                    injectTraitIntoDeme(deme.id, chosenTraitId);
                    setChosenTraitId("");
                  }}
                  className="shrink-0 rounded-md bg-indigo-600 px-2.5 py-1 text-xs font-medium text-white hover:bg-indigo-500 disabled:bg-slate-800 disabled:text-slate-500 disabled:cursor-not-allowed cursor-pointer"
                >
                  {t("panel.addTraitButton")}
                </button>
              </div>
              {needsCulturalCapacity && <p className="text-[11px] text-amber-400">{t("panel.culturalCapacityRequired")}</p>}
            </div>
          </details>
        </section>

        {/* Milestones */}
        <details className={SECTION_CLASS}>
          <summary className={DISCLOSURE_SUMMARY_CLASS}>
            <ChevronRight className="w-3.5 h-3.5 text-slate-400 transition-transform [details[open]_&]:rotate-90" />
            <span className="flex-1">{t("panel.milestonesTitle")}</span>
            <span className="font-mono text-slate-400">{closestMilestone}%</span>
          </summary>
          <ul className="mt-3 space-y-2.5">
            {milestoneProgress.map((milestone) => (
              <li key={milestone.key} className="space-y-1">
                <div className="flex items-center justify-between gap-2 text-xs">
                  <span className="flex items-center gap-1.5 text-slate-300">
                    {t(`panel.${milestone.key}`)}
                    <InfoHint text={t(`panel.${milestone.key}Hint`)} />
                  </span>
                  <span className="font-mono text-slate-400">{milestone.label}</span>
                </div>
                <ProgressBar percent={milestone.percent} colorClass={milestone.color} />
              </li>
            ))}
          </ul>
        </details>
      </div>
    );
  }

  function renderHabitat(habitat: HexCell, isOpen: boolean) {
    const healthPercent = Math.round(habitatHealthRatio(habitat) * 100);
    return (
      <details className={SECTION_CLASS} open={isOpen}>
        <summary className={DISCLOSURE_SUMMARY_CLASS}>
          <ChevronRight className="w-3.5 h-3.5 text-slate-400 transition-transform [details[open]_&]:rotate-90" />
          <span className="flex-1">{t("panel.habitatTitle")}</span>
          <span className="font-normal text-slate-400">{t(`biomes.${habitat.biome}`)}</span>
        </summary>
        <dl className="mt-3 grid grid-cols-2 gap-2 text-xs">
          <div>
            <dt className="text-slate-400">{t("panel.temperature")}</dt>
            <dd className="font-mono text-slate-200">{habitat.temperature.toFixed(2)}</dd>
          </div>
          <div>
            <dt className="text-slate-400">{t("panel.humidity")}</dt>
            <dd className="font-mono text-slate-200">{Math.round(habitat.humidity * 100)}%</dd>
          </div>
          <div>
            <dt className="text-slate-400">{t("panel.altitude")}</dt>
            <dd className="font-mono text-slate-200">{habitat.altitude.toFixed(2)}</dd>
          </div>
          {habitat.biome !== "ocean" && (
            <div>
              <dt className="flex items-center gap-1 text-slate-400">
                {t("panel.food")}
                <InfoHint text={t("panel.foodHint")} />
              </dt>
              <dd className="font-mono text-emerald-300">{Math.round(habitat.currentResources)}</dd>
            </div>
          )}
        </dl>
        {habitat.biome !== "ocean" && (
          <div className="mt-3 space-y-1">
            <div className="flex items-center justify-between text-xs">
              <span className="flex items-center gap-1 text-slate-400">
                {t("panel.health")}
                <InfoHint text={t("panel.healthHint")} />
              </span>
              <span className="font-mono text-slate-200">{healthPercent}%</span>
            </div>
            <ProgressBar percent={healthPercent} colorClass={healthPercent >= 60 ? "bg-emerald-500" : "bg-amber-500"} />
          </div>
        )}
      </details>
    );
  }

  const demeInSelectedHex = selectedDeme !== undefined && cell !== undefined && selectedDeme.hexId === cell.id;

  return (
    <aside
      aria-label={t("panel.label")}
      className="flex w-80 shrink-0 flex-col border-l border-slate-800 bg-slate-900 text-slate-100"
    >
      <div className="flex items-center justify-end border-b border-slate-800 px-2 py-1.5">
        <button
          type="button"
          onClick={() => setIsCollapsed(true)}
          aria-label={t("panel.collapse")}
          className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <PanelRightClose className="w-4 h-4" />
        </button>
      </div>
      <div className="flex-1 space-y-4 overflow-y-auto p-4">
        {renderPopulationList()}
        {demeInSelectedHex && renderDeme(selectedDeme)}
        {cell !== undefined && !demeInSelectedHex && (
          <p className="rounded-lg border border-dashed border-slate-700 p-3 text-center text-xs text-slate-400">
            {t("panel.nobodyHere")}
          </p>
        )}
        {cell !== undefined && renderHabitat(cell, !demeInSelectedHex)}
      </div>
    </aside>
  );
}
