import { useTranslation } from "react-i18next";
import { useSimulationStore, type MapLens } from "../store/useSimulationStore";
import {
  BiomeTypeSchema,
  DecisionArchetypeSchema,
  HexEdgeFlowTypeSchema
} from "../types/simulation";
import {
  BIOME_STYLES,
  DECISION_ARCHETYPE_VISUALS,
  DEME_STATUS_RINGS,
  type DemeVitalStatus,
  FLOW_STYLES,
  FOOD_SCALE,
  HEALTH_SCALE
} from "./palette";

const LENSES: MapLens[] = ["biome", "food", "health"];
const VITAL_STATUSES: DemeVitalStatus[] = ["thriving", "stable", "struggling", "starving"];

export function MapLegend() {
  const { t } = useTranslation();
  const mapLens = useSimulationStore((s) => s.mapLens);
  const setMapLens = useSimulationStore((s) => s.setMapLens);

  const scale = mapLens === "food" ? FOOD_SCALE : HEALTH_SCALE;

  return (
    <section
      aria-label={t("map.legend")}
      className="absolute bottom-3 left-3 z-10 w-68 max-h-[75vh] overflow-y-auto space-y-2.5 rounded-xl border border-slate-800 bg-slate-900/90 p-3 text-xs text-slate-300 shadow-lg backdrop-blur"
    >
      <div role="group" aria-label={t("map.lens")} className="flex gap-1 rounded-lg bg-slate-950 p-0.5">
        {LENSES.map((lens) => (
          <button
            key={lens}
            type="button"
            aria-pressed={mapLens === lens}
            onClick={() => setMapLens(lens)}
            className={`flex-1 rounded-md px-2 py-1 font-medium cursor-pointer ${
              mapLens === lens ? "bg-slate-700 text-white" : "text-slate-400 hover:text-slate-200"
            }`}
          >
            {t(`map.lenses.${lens}`)}
          </button>
        ))}
      </div>

      <details open>
        <summary className="cursor-pointer list-none text-[11px] uppercase tracking-wide text-slate-500 hover:text-slate-300 [&::-webkit-details-marker]:hidden">
          {t("map.legend")}
        </summary>
        <div className="mt-2 space-y-2.5">
          {mapLens === "biome" ? (
            <ul className="grid grid-cols-2 gap-x-3 gap-y-1">
              {BiomeTypeSchema.options.map((biome) => (
                <li key={biome} className="flex items-center gap-1.5 min-w-0">
                  <span
                    className="h-3 w-3 shrink-0 rounded-sm border"
                    style={{ backgroundColor: BIOME_STYLES[biome].fill, borderColor: BIOME_STYLES[biome].stroke }}
                  />
                  <span className="truncate">{t(`biomes.${biome}`)}</span>
                </li>
              ))}
            </ul>
          ) : (
            <div className="space-y-1">
              <div
                className="h-2.5 rounded-full"
                style={{ background: `linear-gradient(to right, ${scale[0]}, ${scale[1]}, ${scale[2]})` }}
              />
              <div className="flex justify-between text-[11px] text-slate-400">
                <span>{t("map.low")}</span>
                <span>{t("map.high")}</span>
              </div>
            </div>
          )}

          <div className="border-t border-slate-800 pt-2">
            <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-slate-400">
              {t("map.vitalStatus")}
            </div>
            <ul className="grid grid-cols-2 gap-x-2 gap-y-1">
              {VITAL_STATUSES.map((status) => (
                <li key={status} className="flex items-center gap-1.5 min-w-0">
                  <span
                    className="h-2.5 w-2.5 shrink-0 rounded-full border-2 bg-slate-950"
                    style={{ borderColor: DEME_STATUS_RINGS[status] }}
                  />
                  <span className="truncate text-[11px]">{t(`panel.status.${status}`)}</span>
                </li>
              ))}
            </ul>
            <div className="mt-1.5 flex items-center gap-1.5 text-[11px] text-purple-200">
              <span className="inline-flex h-3 w-3 shrink-0 items-center justify-center rounded-full border border-purple-400 bg-purple-950">
                <span className="h-1.5 w-1.5 rounded-full bg-purple-200" />
              </span>
              <span className="truncate">{t("map.cultureBadge")}</span>
            </div>
          </div>

          <div className="border-t border-slate-800 pt-2">
            <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-slate-400">
              {t("map.actions")}
            </div>
            <ul className="grid grid-cols-2 gap-x-2 gap-y-1">
              {DecisionArchetypeSchema.options.map((archetype) => {
                const visual = DECISION_ARCHETYPE_VISUALS[archetype];
                return (
                  <li key={archetype} className="flex items-center gap-1.5 min-w-0">
                    <svg width="14" height="14" viewBox="-6 -6 12 12" aria-hidden="true" className="shrink-0">
                      <circle r="5.5" fill={visual.bg} stroke={visual.color} strokeWidth="1" />
                      <path
                        d={visual.glyphPath}
                        fill="none"
                        stroke={visual.color}
                        strokeWidth="1.2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                    <span className="truncate text-[11px]">{t(`catalogLab.archetypes.${archetype}`)}</span>
                  </li>
                );
              })}
            </ul>
          </div>

          <ul className="flex flex-wrap gap-x-3 gap-y-1 border-t border-slate-800 pt-2">
            {HexEdgeFlowTypeSchema.options.map((flowType) => (
              <li key={flowType} className="flex items-center gap-1.5">
                <svg width="18" height="6" aria-hidden="true">
                  <line
                    x1="0"
                    y1="3"
                    x2="18"
                    y2="3"
                    stroke={FLOW_STYLES[flowType].stroke}
                    strokeWidth="2"
                    strokeDasharray={FLOW_STYLES[flowType].dash}
                  />
                </svg>
                {t(`map.flows.${flowType}`)}
              </li>
            ))}
          </ul>
        </div>
      </details>
    </section>
  );
}
