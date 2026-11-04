import { useTranslation } from "react-i18next";
import { BookOpen, MapPin } from "lucide-react";
import { useSimulationStore } from "../store/useSimulationStore";
import { Modal } from "./Modal";
import { CHRONICLE_BADGE_STYLES } from "./palette";

export function NaturalistNotebookModal() {
  const { t } = useTranslation();
  const world = useSimulationStore((s) => s.world);
  const activeModal = useSimulationStore((s) => s.activeModal);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);
  const selectHex = useSimulationStore((s) => s.selectHex);

  if (activeModal !== "naturalist_notebook") {
    return null;
  }

  const chronicleNewestFirst = [...world.chronicle].sort((a, b) => b.generation - a.generation);

  function focusHex(hexId: string) {
    selectHex(hexId);
    setActiveModal("none");
  }

  return (
    <Modal
      title={t("notebook.title")}
      icon={<BookOpen className="h-5 w-5 text-amber-400" />}
      sizeClass="w-[56rem] h-[84vh]"
      onClose={() => setActiveModal("none")}
    >
      <div className="flex-1 space-y-4 overflow-y-auto p-6">
        {chronicleNewestFirst.length === 0 ? (
          <div className="flex h-64 flex-col items-center justify-center text-center text-sm text-slate-400">
            <BookOpen className="mb-3 h-10 w-10 text-slate-600" />
            <p className="max-w-sm">{t("notebook.emptyFeed")}</p>
          </div>
        ) : (
          chronicleNewestFirst.map((entry) => (
            <article key={entry.id} className="space-y-2.5 rounded-xl border border-slate-800 bg-slate-950/60 p-5">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <span className={`rounded-full border px-2.5 py-0.5 text-xs font-medium ${CHRONICLE_BADGE_STYLES[entry.type]}`}>
                    {t(`notebook.types.${entry.type}`)}
                  </span>
                  <span className="font-mono text-xs text-slate-400">
                    {t("notebook.generationBadge")} {entry.generation}
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => focusHex(entry.hexId)}
                  className="flex items-center gap-1 rounded-md border border-slate-700 bg-slate-900 px-2.5 py-1 text-xs text-slate-300 hover:bg-slate-800 hover:text-white cursor-pointer"
                >
                  <MapPin className="h-3.5 w-3.5 text-emerald-400" />
                  {t("notebook.showOnMap")}
                </button>
              </div>
              <h3 className="text-base font-semibold text-slate-100">{entry.title}</h3>
              <p className="text-sm leading-relaxed text-slate-300">{entry.body}</p>
            </article>
          ))
        )}
      </div>
    </Modal>
  );
}
