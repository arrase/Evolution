import { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { ArrowRight, Sparkles } from "lucide-react";
import { SCIENTIFIC_PRESETS } from "../catalog/presets";
import { computeCellsViewBox, computeHexPixelGeometry, HEX_SIZE } from "../engine/hexGrid";
import { useSimulationStore } from "../store/useSimulationStore";
import type { PresetScenario } from "../types/simulation";
import { Modal } from "./Modal";
import { BIOME_STYLES } from "./palette";

function PresetCard({ preset, isFirst, onStart }: { preset: PresetScenario; isFirst: boolean; onStart: () => void }) {
  const { t } = useTranslation();
  const cells = useMemo(() => Object.values(preset.createInitialWorld().cells), [preset]);

  return (
    <article className="flex flex-col overflow-hidden rounded-xl border border-slate-800 bg-slate-950/60">
      <svg viewBox={computeCellsViewBox(cells, HEX_SIZE)} className="h-36 w-full bg-slate-950 p-2" aria-hidden="true">
        {cells.map((cell) => (
          <polygon
            key={cell.id}
            points={computeHexPixelGeometry(cell.q, cell.r).polygonPoints}
            fill={BIOME_STYLES[cell.biome].fill}
            stroke={BIOME_STYLES[cell.biome].stroke}
            strokeWidth={1.5}
          />
        ))}
      </svg>
      <div className="flex flex-1 flex-col gap-2 p-4">
        <h3 className="text-base font-semibold text-white">{t(`presets.${preset.id}.name`)}</h3>
        <p className="text-sm leading-relaxed text-slate-300">{t(`presets.${preset.id}.description`)}</p>
        <p className="flex gap-2 rounded-lg bg-emerald-950/40 p-2.5 text-xs leading-relaxed text-emerald-200">
          <Sparkles className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          <span>
            <strong>{t("welcome.tryThis")}:</strong> {t(`presets.${preset.id}.tryThis`)}
          </span>
        </p>
        <div className="flex-1" />
        <button
          type="button"
          autoFocus={isFirst}
          onClick={onStart}
          className="mt-2 inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-400 cursor-pointer"
        >
          {t("welcome.start")}
          <ArrowRight className="h-4 w-4" />
        </button>
      </div>
    </article>
  );
}

export function WelcomeDialog() {
  const { t } = useTranslation();
  const activeModal = useSimulationStore((s) => s.activeModal);
  const loadPreset = useSimulationStore((s) => s.loadPreset);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);

  if (activeModal !== "welcome") {
    return null;
  }

  function startPreset(presetId: string) {
    loadPreset(presetId);
    setActiveModal("none");
  }

  return (
    <Modal
      title={t("welcome.title")}
      icon={
        <svg viewBox="0 0 32 32" className="h-6 w-6" aria-hidden="true">
          <polygon points="16,2 28,9 28,23 16,30 4,23 4,9" fill="#10b981" stroke="#064e3b" strokeWidth="2" />
          <circle cx="16" cy="16" r="5" fill="#ecfdf5" />
        </svg>
      }
      sizeClass="w-[64rem]"
      onClose={() => setActiveModal("none")}
    >
      <div className="overflow-y-auto p-6">
        <p className="max-w-3xl text-base leading-relaxed text-slate-200">{t("welcome.tagline")}</p>
        <h3 className="mt-6 mb-3 text-xs font-semibold uppercase tracking-wider text-slate-400">
          {t("welcome.chooseWorld")}
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          {SCIENTIFIC_PRESETS.map((preset, index) => (
            <PresetCard key={preset.id} preset={preset} isFirst={index === 0} onStart={() => startPreset(preset.id)} />
          ))}
        </div>
      </div>
    </Modal>
  );
}
