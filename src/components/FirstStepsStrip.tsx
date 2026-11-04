import { useTranslation } from "react-i18next";
import { CheckCircle2, Circle, X } from "lucide-react";
import { useSimulationStore, type FirstSteps } from "../store/useSimulationStore";

const STEP_ORDER: Array<keyof FirstSteps> = ["play", "select", "tool"];

export function FirstStepsStrip() {
  const { t } = useTranslation();
  const firstSteps = useSimulationStore((s) => s.firstSteps);
  const firstStepsDismissed = useSimulationStore((s) => s.firstStepsDismissed);
  const activeModal = useSimulationStore((s) => s.activeModal);
  const dismissFirstSteps = useSimulationStore((s) => s.dismissFirstSteps);

  if (firstStepsDismissed || activeModal === "welcome") {
    return null;
  }

  return (
    <section
      aria-label={t("firstSteps.title")}
      className="pointer-events-auto flex flex-wrap items-center gap-x-4 gap-y-1 rounded-2xl border border-emerald-500/40 bg-slate-900/95 py-2 pl-4 pr-2 text-xs text-slate-200 shadow-xl backdrop-blur"
    >
      <span className="font-semibold text-emerald-300">{t("firstSteps.title")}</span>
      <ol className="flex flex-wrap items-center gap-x-4 gap-y-1">
        {STEP_ORDER.map((step, index) => (
          <li
            key={step}
            className={`flex items-center gap-1.5 ${firstSteps[step] ? "text-slate-500 line-through" : ""}`}
          >
            {firstSteps[step] ? (
              <CheckCircle2 className="h-4 w-4 text-emerald-400" />
            ) : (
              <Circle className="h-4 w-4 text-slate-500" />
            )}
            <span>
              {index + 1}. {t(`firstSteps.${step}`)}
            </span>
          </li>
        ))}
      </ol>
      <button
        type="button"
        onClick={dismissFirstSteps}
        aria-label={t("firstSteps.dismiss")}
        className="rounded-full p-1 text-slate-400 hover:bg-slate-800 hover:text-white cursor-pointer"
      >
        <X className="h-4 w-4" />
      </button>
    </section>
  );
}
