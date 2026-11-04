import { useEffect } from "react";
import { useTranslation } from "react-i18next";
import { AlertTriangle, MapPin, X } from "lucide-react";
import { useSimulationStore, type Toast } from "../store/useSimulationStore";
import { CHRONICLE_BADGE_STYLES } from "./palette";

const TOAST_LIFETIME_MS = 6000;

function ToastItem({ toast }: { toast: Toast }) {
  const { t } = useTranslation();
  const dismissToast = useSimulationStore((s) => s.dismissToast);
  const selectHex = useSimulationStore((s) => s.selectHex);

  useEffect(() => {
    const timerId = setTimeout(() => dismissToast(toast.id), TOAST_LIFETIME_MS);
    return () => clearTimeout(timerId);
  }, [toast.id, dismissToast]);

  return (
    <li className="pointer-events-auto flex items-center gap-3 rounded-xl border border-slate-700 bg-slate-900/95 px-3 py-2 text-xs text-slate-200 shadow-xl backdrop-blur">
      {toast.kind === "event" ? (
        <>
          <span
            className={`shrink-0 rounded-full border px-2 py-0.5 text-[11px] font-medium ${CHRONICLE_BADGE_STYLES[toast.entry.type]}`}
          >
            {t(`notebook.types.${toast.entry.type}`)}
          </span>
          <span className="flex-1 truncate">{toast.entry.title}</span>
          <button
            type="button"
            onClick={() => selectHex(toast.entry.hexId)}
            className="inline-flex shrink-0 items-center gap-1 rounded-md px-2 py-1 text-emerald-300 hover:bg-slate-800 cursor-pointer"
          >
            <MapPin className="h-3.5 w-3.5" />
            {t("toasts.show")}
          </button>
        </>
      ) : (
        <>
          <AlertTriangle className="h-4 w-4 shrink-0 text-rose-400" />
          <span className="flex-1 text-rose-200">{t(toast.messageKey)}</span>
        </>
      )}
      <button
        type="button"
        onClick={() => dismissToast(toast.id)}
        aria-label={t("common.dismiss")}
        className="shrink-0 rounded-md p-1 text-slate-500 hover:bg-slate-800 hover:text-white cursor-pointer"
      >
        <X className="h-3.5 w-3.5" />
      </button>
    </li>
  );
}

export function EventToasts() {
  const toasts = useSimulationStore((s) => s.toasts);

  return (
    <div
      role="status"
      className="pointer-events-none absolute bottom-3 left-1/2 z-20 w-[min(30rem,calc(100%-36rem))] min-w-72 -translate-x-1/2"
    >
      <ul className="flex flex-col gap-2">
        {toasts.map((toast) => (
          <ToastItem key={toast.id} toast={toast} />
        ))}
      </ul>
    </div>
  );
}
