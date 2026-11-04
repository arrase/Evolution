import { useTranslation } from "react-i18next";
import { BookOpen, Sparkles, X } from "lucide-react";
import { useSimulationStore } from "../store/useSimulationStore";

export function MilestoneBanner() {
  const { t } = useTranslation();
  const latestMilestoneChronicle = useSimulationStore((s) => s.latestMilestoneChronicle);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);
  const dismissMilestoneBanner = useSimulationStore((s) => s.dismissMilestoneBanner);

  if (latestMilestoneChronicle === null) {
    return null;
  }

  return (
    <div
      role="status"
      className="pointer-events-auto flex w-full max-w-2xl items-center justify-between gap-4 rounded-xl border border-amber-500/50 bg-slate-900/95 px-4 py-3 text-slate-100 shadow-2xl backdrop-blur-md"
    >
      <div className="flex min-w-0 items-start gap-3">
        <Sparkles className="mt-0.5 h-5 w-5 shrink-0 text-amber-400" />
        <div className="min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-amber-300">
            {t(`notebook.types.${latestMilestoneChronicle.type}`)} · {t("notebook.generationBadge")} {latestMilestoneChronicle.generation}
          </div>
          <div className="truncate text-sm font-medium text-white">{latestMilestoneChronicle.title}</div>
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <button
          type="button"
          onClick={() => {
            setActiveModal("naturalist_notebook");
            dismissMilestoneBanner();
          }}
          className="flex items-center gap-1.5 rounded-lg bg-amber-500 px-3 py-1.5 text-xs font-semibold text-slate-950 hover:bg-amber-400 cursor-pointer"
        >
          <BookOpen className="h-3.5 w-3.5" />
          {t("notebook.readEntry")}
        </button>
        <button
          type="button"
          onClick={dismissMilestoneBanner}
          aria-label={t("common.dismiss")}
          className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
