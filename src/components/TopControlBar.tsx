import { useRef, type ChangeEvent } from "react";
import { useTranslation } from "react-i18next";
import {
  AlertTriangle,
  ChevronDown,
  Download,
  Loader2,
  Pause,
  Play,
  Plus,
  Settings,
  SkipForward,
  Upload
} from "lucide-react";
import { LANGUAGE_LABELS } from "../i18n";
import { useSimulationStore } from "../store/useSimulationStore";
import { SUPPORTED_LOCALES, type SupportedLocale } from "../types/simulation";
import { Tooltip } from "./Tooltip";

const MENU_ITEM_CLASS =
  "flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm text-slate-200 hover:bg-slate-800 cursor-pointer";

export function TopControlBar() {
  const { t } = useTranslation();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const worldMenuRef = useRef<HTMLDivElement>(null);

  const locale = useSimulationStore((s) => s.locale);
  const world = useSimulationStore((s) => s.world);
  const playbackMode = useSimulationStore((s) => s.playbackMode);
  const playbackSpeed = useSimulationStore((s) => s.playbackSpeed);
  const ollamaStatus = useSimulationStore((s) => s.ollamaStatus);

  const setLocale = useSimulationStore((s) => s.setLocale);
  const stepGeneration = useSimulationStore((s) => s.stepGeneration);
  const togglePlayback = useSimulationStore((s) => s.togglePlayback);
  const setPlaybackSpeed = useSimulationStore((s) => s.setPlaybackSpeed);
  const toggleAutoPauseOnMilestone = useSimulationStore((s) => s.toggleAutoPauseOnMilestone);
  const toggleUnlimitedPressure = useSimulationStore((s) => s.toggleUnlimitedPressure);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);
  const exportWorldJson = useSimulationStore((s) => s.exportWorldJson);
  const importWorldJson = useSimulationStore((s) => s.importWorldJson);

  const isPlaying = playbackMode === "playing_normal" || playbackMode === "playing_fast";
  const isStepping = playbackMode === "stepping";
  const isAiReady =
    ollamaStatus !== null &&
    ollamaStatus.connected &&
    ollamaStatus.systemOneModelReady &&
    ollamaStatus.systemTwoModelReady;
  const isAiOffline = ollamaStatus !== null && !isAiReady;

  function runWorldMenuAction(action: () => void) {
    worldMenuRef.current!.hidePopover();
    action();
  }

  function handleExportJson() {
    const blob = new Blob([exportWorldJson()], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `evolution-gen-${world.generation}.json`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  async function handleImportFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files![0]!;
    importWorldJson(await file.text());
    event.target.value = "";
  }

  return (
    <header className="relative z-40 h-12 w-full shrink-0 bg-slate-900 border-b border-slate-800 px-3 flex items-center gap-3 text-sm text-slate-200">
      {/* Brand + World menu */}
      <div className="flex flex-1 items-center gap-2 min-w-0">
        <svg viewBox="0 0 32 32" className="w-6 h-6 shrink-0" aria-hidden="true">
          <polygon points="16,2 28,9 28,23 16,30 4,23 4,9" fill="#10b981" stroke="#064e3b" strokeWidth="2" />
          <circle cx="16" cy="16" r="5" fill="#ecfdf5" />
        </svg>
        <span className="font-bold tracking-tight text-emerald-400 hidden lg:inline">
          {t("app.shortTitle")}
        </span>
        <button
          type="button"
          popoverTarget="world-menu"
          className="flex items-center gap-1.5 min-w-0 rounded-md px-2.5 py-1.5 text-slate-200 hover:bg-slate-800 cursor-pointer"
        >
          <span className="truncate">{t(`presets.${world.presetId}.name`)}</span>
          <ChevronDown className="w-4 h-4 shrink-0 text-slate-400" />
        </button>
        <div
          ref={worldMenuRef}
          id="world-menu"
          popover="auto"
          className="fixed inset-auto top-13 left-3 m-0 w-60 rounded-lg border border-slate-700 bg-slate-900 p-1 text-slate-100 shadow-2xl"
        >
          <button
            type="button"
            className={MENU_ITEM_CLASS}
            onClick={() => runWorldMenuAction(() => setActiveModal("welcome"))}
          >
            <Plus className="w-4 h-4 text-emerald-400" />
            {t("topBar.newWorld")}
          </button>
          <hr className="my-1 border-slate-800" />
          <button
            type="button"
            className={MENU_ITEM_CLASS}
            onClick={() => runWorldMenuAction(handleExportJson)}
          >
            <Download className="w-4 h-4 text-slate-400" />
            {t("topBar.exportJson")}
          </button>
          <button
            type="button"
            className={MENU_ITEM_CLASS}
            onClick={() => runWorldMenuAction(() => fileInputRef.current!.click())}
          >
            <Upload className="w-4 h-4 text-slate-400" />
            {t("topBar.importJson")}
          </button>
        </div>
        <input
          id="import-world-json"
          name="importWorldJson"
          aria-label={t("topBar.importJson")}
          ref={fileInputRef}
          type="file"
          accept=".json,application/json"
          onChange={(e) => void handleImportFile(e)}
          className="hidden"
        />
      </div>

      {/* Time controls */}
      <div className="flex items-center gap-2">
        <Tooltip
          id="tip-play"
          side="bottom"
          text={isAiOffline ? t("topBar.aiOfflineHint") : t("topBar.playHint")}
        >
          <button
            type="button"
            onClick={togglePlayback}
            disabled={isAiOffline || isStepping}
            aria-describedby="tip-play"
            className={`inline-flex w-28 items-center justify-center gap-2 rounded-lg px-4 py-1.5 font-semibold transition-colors cursor-pointer disabled:cursor-not-allowed disabled:bg-slate-800 disabled:text-slate-500 ${
              isPlaying
                ? "bg-amber-500 text-slate-950 hover:bg-amber-400"
                : "bg-emerald-500 text-slate-950 hover:bg-emerald-400"
            }`}
          >
            {isPlaying ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
            {isPlaying ? t("topBar.pause") : t("topBar.play")}
          </button>
        </Tooltip>

        <Tooltip id="tip-step" side="bottom" text={t("topBar.stepHint")}>
          <button
            type="button"
            onClick={() => void stepGeneration()}
            disabled={isPlaying || isStepping || isAiOffline}
            aria-describedby="tip-step"
            className="inline-flex items-center gap-1.5 rounded-lg border border-slate-700 bg-slate-800 px-3 py-1.5 text-slate-200 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
          >
            <SkipForward className="w-4 h-4" />
            {t("topBar.stepOneGen")}
          </button>
        </Tooltip>

        <div
          role="group"
          aria-label={t("topBar.speed")}
          className="flex rounded-lg border border-slate-700 bg-slate-800 p-0.5 text-xs font-mono"
        >
          {(["normal", "fast"] as const).map((speed) => (
            <button
              key={speed}
              type="button"
              aria-pressed={playbackSpeed === speed}
              onClick={() => setPlaybackSpeed(speed)}
              className={`rounded-md px-2 py-1 cursor-pointer ${
                playbackSpeed === speed ? "bg-slate-600 text-white" : "text-slate-400 hover:text-slate-200"
              }`}
            >
              {speed === "normal" ? t("topBar.speedNormal") : t("topBar.speedFast")}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-1.5 pl-2 text-slate-300 whitespace-nowrap" aria-live="polite">
          {isStepping && <Loader2 className="w-4 h-4 animate-spin text-emerald-400" />}
          <span>
            {t("topBar.generation")} <span className="font-mono font-bold text-white">{world.generation}</span>
          </span>
          <span className="text-slate-600">·</span>
          <span className={world.season === "wet_warm" ? "text-emerald-300" : "text-amber-300"}>
            {t(`topBar.seasons.${world.season}`)}
          </span>
        </div>
      </div>

      {/* Status + settings */}
      <div className="flex flex-1 items-center justify-end gap-2">
        {isAiOffline && (
          <button
            type="button"
            onClick={() => setActiveModal("ollama_diagnostics")}
            className="inline-flex items-center gap-1.5 rounded-lg border border-rose-500/60 bg-rose-950/70 px-2.5 py-1.5 text-rose-200 hover:bg-rose-900/70 cursor-pointer"
          >
            <AlertTriangle className="w-4 h-4" />
            {t("topBar.aiOffline")}
          </button>
        )}

        <button
          type="button"
          popoverTarget="settings-menu"
          aria-label={t("settings.title")}
          className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white cursor-pointer"
        >
          <Settings className="w-4.5 h-4.5" />
        </button>
        <div
          id="settings-menu"
          popover="auto"
          className="fixed inset-auto top-13 right-3 m-0 w-72 rounded-lg border border-slate-700 bg-slate-900 p-4 text-slate-100 shadow-2xl"
        >
          <div className="space-y-4 text-sm">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400">
              {t("settings.title")}
            </h2>

            <label htmlFor="locale-select" className="flex items-center justify-between gap-3">
              <span>{t("settings.language")}</span>
              <select
                id="locale-select"
                name="locale"
                value={locale}
                onChange={(e) => setLocale(e.target.value as SupportedLocale)}
                className="rounded-md border border-slate-700 bg-slate-950 px-2 py-1 text-slate-100 cursor-pointer"
              >
                {SUPPORTED_LOCALES.map((loc) => (
                  <option key={loc} value={loc}>
                    {LANGUAGE_LABELS[loc]}
                  </option>
                ))}
              </select>
            </label>

            <label htmlFor="auto-pause-milestones" className="flex items-start gap-2.5 cursor-pointer">
              <input
                id="auto-pause-milestones"
                name="autoPauseOnMilestone"
                type="checkbox"
                checked={world.autoPauseOnMilestone}
                onChange={toggleAutoPauseOnMilestone}
                className="mt-1 accent-emerald-500"
              />
              <span>
                <span className="block">{t("settings.autoPauseMilestones")}</span>
                <span className="block text-xs text-slate-400">{t("settings.autoPauseHint")}</span>
              </span>
            </label>

            <label htmlFor="unlimited-energy" className="flex items-start gap-2.5 cursor-pointer">
              <input
                id="unlimited-energy"
                name="unlimitedPressureMode"
                type="checkbox"
                checked={world.unlimitedPressureMode}
                onChange={toggleUnlimitedPressure}
                className="mt-1 accent-amber-500"
              />
              <span>
                <span className="block">{t("settings.unlimitedBudget")}</span>
                <span className="block text-xs text-slate-400">{t("settings.unlimitedBudgetHint")}</span>
              </span>
            </label>

            <div className="flex items-center justify-between gap-3 border-t border-slate-800 pt-3">
              <span className="flex items-center gap-2">
                <span
                  className={`h-2 w-2 rounded-full ${isAiReady ? "bg-emerald-400" : "bg-rose-400"}`}
                  aria-hidden="true"
                />
                {t("settings.aiEngine")}: {isAiReady ? t("settings.aiReady") : t("settings.aiOffline")}
              </span>
              <button
                type="button"
                popoverTarget="settings-menu"
                popoverTargetAction="hide"
                onClick={() => setActiveModal("ollama_diagnostics")}
                className="text-xs text-emerald-300 hover:underline cursor-pointer"
              >
                {t("settings.aiDetails")}
              </button>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
