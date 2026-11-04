import { useEffect, useId, useRef, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { X } from "lucide-react";

interface ModalProps {
  title: string;
  icon: ReactNode;
  sizeClass: string;
  onClose: () => void;
  children: ReactNode;
}

export function Modal({ title, icon, sizeClass, onClose, children }: ModalProps) {
  const { t } = useTranslation();
  const dialogRef = useRef<HTMLDialogElement>(null);
  const titleId = useId();

  useEffect(() => {
    dialogRef.current!.showModal();
  }, []);

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby={titleId}
      onClose={onClose}
      {...{ closedby: "any" }}
      className={`m-auto open:flex flex-col max-w-[calc(100vw-2rem)] max-h-[calc(100vh-2rem)] rounded-xl border border-slate-700 bg-slate-900 p-0 text-slate-100 shadow-2xl overflow-hidden backdrop:bg-slate-950/80 backdrop:backdrop-blur-sm ${sizeClass}`}
    >
      <header className="flex items-center justify-between gap-4 px-5 py-3.5 border-b border-slate-800 bg-slate-950/60 shrink-0">
        <div className="flex items-center gap-3 min-w-0">
          {icon}
          <h2 id={titleId} className="text-base font-semibold tracking-tight truncate">
            {title}
          </h2>
        </div>
        <button
          type="button"
          onClick={() => dialogRef.current!.close()}
          aria-label={t("common.close")}
          className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <X className="w-4 h-4" />
        </button>
      </header>
      {children}
    </dialog>
  );
}
