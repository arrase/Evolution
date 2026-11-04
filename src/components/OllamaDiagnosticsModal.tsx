import { useTranslation } from "react-i18next";
import {
  AlertTriangle,
  CheckCircle2,
  Copy,
  Play,
  RefreshCw,
  Server,
  Terminal,
  XCircle
} from "lucide-react";
import { useSimulationStore } from "../store/useSimulationStore";
import { Modal } from "./Modal";

const REQUIRED_CLI_COMMANDS = [
  'OLLAMA_ORIGINS="*" ollama serve',
  "ollama pull d3:4b",
  "ollama pull gemma4:e4b-it-qat"
] as const;

export function OllamaDiagnosticsModal() {
  const { t } = useTranslation();
  const activeModal = useSimulationStore((s) => s.activeModal);
  const ollamaStatus = useSimulationStore((s) => s.ollamaStatus);
  const lastError = useSimulationStore((s) => s.lastError);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);
  const refreshOllamaStatus = useSimulationStore((s) => s.refreshOllamaStatus);
  const stepGeneration = useSimulationStore((s) => s.stepGeneration);

  if (activeModal !== "ollama_diagnostics") {
    return null;
  }

  const isConnected = ollamaStatus !== null && ollamaStatus.connected;
  const isSystemOneReady = ollamaStatus !== null && ollamaStatus.systemOneModelReady;
  const isSystemTwoReady = ollamaStatus !== null && ollamaStatus.systemTwoModelReady;
  const isFullyReady = isConnected && isSystemOneReady && isSystemTwoReady;
  const hostDisplay = ollamaStatus !== null ? ollamaStatus.host : "http://127.0.0.1:11434";

  function handleCopyCommand(cmd: string) {
    void navigator.clipboard.writeText(cmd);
  }

  async function handleRetryTurn() {
    setActiveModal("none");
    await refreshOllamaStatus();
    void stepGeneration();
  }

  return (
    <Modal
      title={t("diagnostics.title")}
      icon={<Server className="w-5 h-5 text-emerald-400" />}
      sizeClass="w-[36rem]"
      onClose={() => setActiveModal("none")}
    >
        {/* Body */}
        <div className="p-5 space-y-4 text-xs overflow-y-auto">
          {/* Overall Status Banner */}
          <div
            className={`flex items-center gap-3 rounded-lg border p-3 ${
              isFullyReady
                ? "bg-emerald-950/50 border-emerald-500/40 text-emerald-200"
                : "bg-rose-950/50 border-rose-500/40 text-rose-200"
            }`}
          >
            {isFullyReady ? (
              <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
            ) : (
              <XCircle className="w-5 h-5 text-rose-400 shrink-0" />
            )}
            <div className="flex-1">
              <div className="font-semibold text-sm">
                {isFullyReady
                  ? t("diagnostics.statusConnected")
                  : t("diagnostics.statusDisconnected")}
              </div>
              <div className="text-[11px] opacity-85 mt-0.5">
                {t("diagnostics.hostLabel")}:{" "}
                <span className="font-mono font-semibold">{hostDisplay}</span>
              </div>
            </div>
          </div>

          {/* Last Error Banner */}
          {lastError !== null && (
            <div className="flex items-start gap-2.5 rounded-lg bg-amber-950/60 border border-amber-500/50 p-3 text-amber-200">
              <AlertTriangle className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
              <div className="font-mono text-[11px] break-words">{lastError}</div>
            </div>
          )}

          {/* Model Readiness Badges */}
          <div className="space-y-2">
            <div className="flex items-center justify-between rounded-lg bg-slate-800/80 border border-slate-700/80 px-3.5 py-2.5">
              <div>
                <div className="font-semibold text-slate-200">
                  {t("diagnostics.systemOneLabel")}
                </div>
                {isSystemOneReady && ollamaStatus.resolvedSystemOneTag !== "" && (
                  <div className="text-[11px] font-mono text-slate-400">
                    {ollamaStatus.resolvedSystemOneTag}
                  </div>
                )}
              </div>
              <span
                className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 font-semibold border ${
                  isSystemOneReady
                    ? "bg-emerald-500/20 border-emerald-500/40 text-emerald-300"
                    : "bg-rose-500/20 border-rose-500/40 text-rose-300"
                }`}
              >
                {isSystemOneReady ? t("diagnostics.ready") : t("diagnostics.missing")}
              </span>
            </div>

            <div className="flex items-center justify-between rounded-lg bg-slate-800/80 border border-slate-700/80 px-3.5 py-2.5">
              <div>
                <div className="font-semibold text-slate-200">
                  {t("diagnostics.systemTwoLabel")}
                </div>
                {isSystemTwoReady && ollamaStatus.resolvedSystemTwoTag !== "" && (
                  <div className="text-[11px] font-mono text-slate-400">
                    {ollamaStatus.resolvedSystemTwoTag}
                  </div>
                )}
              </div>
              <span
                className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 font-semibold border ${
                  isSystemTwoReady
                    ? "bg-emerald-500/20 border-emerald-500/40 text-emerald-300"
                    : "bg-amber-500/20 border-amber-500/40 text-amber-300"
                }`}
              >
                {isSystemTwoReady ? t("diagnostics.ready") : t("diagnostics.missing")}
              </span>
            </div>
          </div>

          {/* Setup CLI Commands */}
          <div className="space-y-2">
            <div className="flex items-center gap-1.5 text-slate-300 font-medium">
              <Terminal className="w-3.5 h-3.5 text-emerald-400" />
              <span>{t("diagnostics.instructionsTitle")}</span>
            </div>
            <div className="space-y-1.5">
              {REQUIRED_CLI_COMMANDS.map((cmd) => (
                <div
                  key={cmd}
                  className="flex items-center justify-between rounded-md bg-slate-950 border border-slate-800 px-3 py-1.5 font-mono text-[11px] text-emerald-300"
                >
                  <span>{cmd}</span>
                  <button
                    type="button"
                    onClick={() => handleCopyCommand(cmd)}
                    className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-slate-400 hover:bg-slate-800 hover:text-slate-200 cursor-pointer"
                    title={cmd}
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="flex items-center justify-end gap-2 border-t border-slate-800 bg-slate-900/90 px-5 py-3 text-xs">
          <button
            type="button"
            onClick={() => void refreshOllamaStatus()}
            className="inline-flex items-center gap-1.5 rounded-lg bg-slate-800 border border-slate-700 px-3 py-1.5 font-medium text-slate-200 hover:bg-slate-700 cursor-pointer"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>{t("diagnostics.refreshStatusButton")}</span>
          </button>

          <button
            type="button"
            onClick={() => void handleRetryTurn()}
            className="inline-flex items-center gap-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 px-3.5 py-1.5 font-semibold text-slate-950 cursor-pointer"
          >
            <Play className="w-3.5 h-3.5" />
            <span>{t("diagnostics.retryTurnButton")}</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveModal("none")}
            className="rounded-lg bg-slate-800 border border-slate-700 px-3 py-1.5 font-medium text-slate-300 hover:bg-slate-700 cursor-pointer"
          >
            {t("diagnostics.close")}
          </button>
        </div>
    </Modal>
  );
}
