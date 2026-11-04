import { useEffect } from "react";
import { CatalogLabModal } from "./components/CatalogLabModal";
import { ContextPanel } from "./components/ContextPanel";
import { EventToasts } from "./components/EventToasts";
import { FirstStepsStrip } from "./components/FirstStepsStrip";
import { HexMapCanvas } from "./components/HexMapCanvas";
import { MapLegend } from "./components/MapLegend";
import { MilestoneBanner } from "./components/MilestoneBanner";
import { NaturalistNotebookModal } from "./components/NaturalistNotebookModal";
import { OllamaDiagnosticsModal } from "./components/OllamaDiagnosticsModal";
import { PhyloCulturalTreeModal } from "./components/PhyloCulturalTreeModal";
import { ToolRail } from "./components/ToolRail";
import { TopControlBar } from "./components/TopControlBar";
import { WelcomeDialog } from "./components/WelcomeDialog";
import { useSimulationStore } from "./store/useSimulationStore";

export function App() {
  const refreshOllamaStatus = useSimulationStore((s) => s.refreshOllamaStatus);
  const togglePlayback = useSimulationStore((s) => s.togglePlayback);

  useEffect(() => {
    void refreshOllamaStatus();
  }, [refreshOllamaStatus]);

  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.code !== "Space") {
        return;
      }
      if (
        event.target instanceof HTMLElement &&
        event.target.closest("button, input, select, textarea, dialog") !== null
      ) {
        return;
      }
      const { activeModal, ollamaStatus, playbackMode } = useSimulationStore.getState();
      const isAiReady =
        ollamaStatus !== null &&
        ollamaStatus.connected &&
        ollamaStatus.systemOneModelReady &&
        ollamaStatus.systemTwoModelReady;
      if (activeModal !== "none" || !isAiReady || playbackMode === "stepping") {
        return;
      }
      event.preventDefault();
      togglePlayback();
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [togglePlayback]);

  return (
    <div className="flex flex-col w-screen h-screen bg-slate-950 text-slate-100 overflow-hidden select-none">
      <TopControlBar />

      <div className="flex flex-1 min-h-0">
        <ToolRail />

        <main className="relative flex-1 min-w-0 min-h-0">
          <HexMapCanvas />
          <div className="pointer-events-none absolute top-3 right-4 left-80 z-20 flex flex-col items-center gap-2">
            <FirstStepsStrip />
            <MilestoneBanner />
          </div>
          <MapLegend />
          <EventToasts />
        </main>

        <ContextPanel />
      </div>

      <WelcomeDialog />
      <CatalogLabModal />
      <PhyloCulturalTreeModal />
      <NaturalistNotebookModal />
      <OllamaDiagnosticsModal />
    </div>
  );
}
