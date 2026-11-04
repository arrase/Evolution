import { type ReactNode } from "react";
import { Info } from "lucide-react";

type TooltipSide = "top" | "bottom" | "right" | "bottom-end";

const SIDE_CLASSES: Record<TooltipSide, string> = {
  top: "bottom-full left-1/2 -translate-x-1/2 mb-2",
  bottom: "top-full left-1/2 -translate-x-1/2 mt-2",
  "bottom-end": "top-full right-0 mt-2",
  right: "left-full top-1/2 -translate-y-1/2 ml-2"
};

interface TooltipProps {
  id: string;
  text: string;
  side: TooltipSide;
  children: ReactNode;
}

export function Tooltip({ id, text, side, children }: TooltipProps) {
  return (
    <span className="group relative inline-flex">
      {children}
      <span
        id={id}
        role="tooltip"
        className={`pointer-events-none invisible group-hover:visible group-has-focus-visible:visible absolute z-50 w-max max-w-60 rounded-md border border-slate-700 bg-slate-950 px-2.5 py-1.5 text-[11px] font-normal leading-snug text-slate-200 shadow-xl normal-case tracking-normal text-left ${SIDE_CLASSES[side]}`}
      >
        {text}
      </span>
    </span>
  );
}

export function InfoHint({ text }: { text: string }) {
  return (
    <span className="group relative inline-flex">
      <button
        type="button"
        aria-label={text}
        className="rounded-full text-slate-500 hover:text-slate-200 focus-visible:text-slate-200 cursor-help"
      >
        <Info className="w-3.5 h-3.5" />
      </button>
      <span
        aria-hidden="true"
        className="pointer-events-none invisible group-hover:visible group-has-focus-visible:visible absolute z-50 top-full left-0 mt-1.5 w-56 rounded-md border border-slate-700 bg-slate-950 px-2.5 py-1.5 text-[11px] font-normal leading-snug text-slate-200 shadow-xl normal-case tracking-normal"
      >
        {text}
      </span>
    </span>
  );
}
