import { useState } from "react";
import { useTranslation } from "react-i18next";
import { AlertTriangle, CheckCircle2, ChevronRight, FlaskConical, Plus, Save, Sparkles, Syringe } from "lucide-react";
import { demeHasCulturalCapacity } from "../catalog/baseTraits";
import { computeThermodynamicMetrics, validateAndBalanceThermodynamics } from "../engine/thermodynamics";
import { useSimulationStore } from "../store/useSimulationStore";
import {
  DecisionArchetypeSchema,
  type BiophysicalVector,
  type DecisionArchetype,
  type DecisionDefinition,
  type TraitDefinition
} from "../types/simulation";
import { Modal } from "./Modal";

type CatalogTab = "biological_trait" | "cultural_trait" | "decision";

const TABS: Array<{ id: CatalogTab; activeClass: string }> = [
  { id: "biological_trait", activeClass: "border-emerald-400 text-emerald-300" },
  { id: "cultural_trait", activeClass: "border-purple-400 text-purple-300" },
  { id: "decision", activeClass: "border-sky-400 text-sky-300" }
];

const INITIAL_VECTOR: BiophysicalVector = {
  metabolicCost: 0.1,
  extractionEfficiency: 0.2,
  ecologicalImpact: -0.05,
  spatialMobility: 0.0,
  socialCohesion: 0.1,
  transmissionThreshold: 0.3
};

const BIPOLAR_AXES: Array<keyof BiophysicalVector> = [
  "metabolicCost",
  "extractionEfficiency",
  "ecologicalImpact",
  "spatialMobility",
  "socialCohesion"
];

const FIELD_LABEL_CLASS = "mb-1 block text-xs font-medium text-slate-400";
const FIELD_CLASS = "w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100";

function normalizeField(text: string, minLen: number, maxLen: number, fallback: string): string {
  const trimmed = text.trim();
  const padded = trimmed.length < minLen ? `${trimmed} ${fallback}`.trim() : trimmed;
  return padded.slice(0, maxLen);
}

function newItemId(tab: CatalogTab): string {
  return `user-${tab.slice(0, 3)}-${Date.now()}`;
}

export function CatalogLabModal() {
  const { t } = useTranslation();
  const locale = useSimulationStore((s) => s.locale);
  const world = useSimulationStore((s) => s.world);
  const activeModal = useSimulationStore((s) => s.activeModal);
  const selectedDemeId = useSimulationStore((s) => s.selectedDemeId);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);
  const upsertTrait = useSimulationStore((s) => s.upsertTrait);
  const upsertDecision = useSimulationStore((s) => s.upsertDecision);
  const injectTraitIntoDeme = useSimulationStore((s) => s.injectTraitIntoDeme);
  const coDesignWithAI = useSimulationStore((s) => s.coDesignWithAI);

  const [activeTab, setActiveTab] = useState<CatalogTab>("biological_trait");
  const [isEditing, setIsEditing] = useState(false);
  const [itemId, setItemId] = useState(() => newItemId("biological_trait"));
  const [name, setName] = useState("");
  const [semanticDescriptor, setSemanticDescriptor] = useState("");
  const [affinityCondition, setAffinityCondition] = useState("");
  const [archetype, setArchetype] = useState<DecisionArchetype>("custom");
  const [enablesCulturalTransmission, setEnablesCulturalTransmission] = useState(false);
  const [freeSandboxMode, setFreeSandboxMode] = useState(false);
  const [vector, setVector] = useState<BiophysicalVector>(INITIAL_VECTOR);
  const [userConcept, setUserConcept] = useState("");
  const [isGenerating, setIsGenerating] = useState(false);
  const [hasAiFailed, setHasAiFailed] = useState(false);
  const [isSaved, setIsSaved] = useState(false);

  if (activeModal !== "catalog_lab") {
    return null;
  }

  const traitsList = Object.values(world.traitsCatalog).filter((trait) =>
    activeTab === "biological_trait" ? trait.category === "biological" : trait.category === "cultural"
  );
  const decisionsList = Object.values(world.decisionsCatalog);
  const metrics = computeThermodynamicMetrics(vector);
  const validation = validateAndBalanceThermodynamics(vector, freeSandboxMode);
  const selectedDeme = selectedDemeId !== null ? world.demes[selectedDemeId] : undefined;
  const isTraitTab = activeTab !== "decision";
  const lacksCulturalCapacity =
    selectedDeme !== undefined &&
    activeTab === "cultural_trait" &&
    !demeHasCulturalCapacity(selectedDeme, world.traitsCatalog);

  function startEditing(nextItemId: string) {
    setItemId(nextItemId);
    setIsEditing(true);
    setIsSaved(false);
  }

  function selectTab(tab: CatalogTab) {
    setActiveTab(tab);
    setIsEditing(false);
    setItemId(newItemId(tab));
  }

  function createBlank() {
    setName("");
    setSemanticDescriptor("");
    setAffinityCondition("");
    setArchetype("custom");
    setEnablesCulturalTransmission(false);
    setFreeSandboxMode(false);
    setVector(INITIAL_VECTOR);
    startEditing(newItemId(activeTab));
  }

  function selectTrait(trait: TraitDefinition) {
    const isBase = trait.origin === "base";
    setName(isBase ? t(`catalog.traits.${trait.id}.name`) : trait.name);
    setSemanticDescriptor(isBase ? t(`catalog.traits.${trait.id}.semanticDescriptor`) : trait.semanticDescriptor);
    setAffinityCondition(isBase ? t(`catalog.traits.${trait.id}.affinityCondition`) : trait.affinityCondition);
    setEnablesCulturalTransmission(trait.enablesCulturalTransmission);
    setFreeSandboxMode(trait.freeSandboxMode);
    setVector(trait.biophysicalVector);
    startEditing(trait.id);
  }

  function selectDecision(decision: DecisionDefinition) {
    const isBase = decision.origin === "base";
    setName(isBase ? t(`catalog.decisions.${decision.id}.name`) : decision.name);
    setSemanticDescriptor(
      isBase ? t(`catalog.decisions.${decision.id}.semanticDescriptor`) : decision.semanticDescriptor
    );
    setArchetype(decision.archetype);
    setFreeSandboxMode(decision.freeSandboxMode);
    setVector(decision.biophysicalVector);
    startEditing(decision.id);
  }

  async function designWithAI() {
    setIsGenerating(true);
    setHasAiFailed(false);
    try {
      const proposal = await coDesignWithAI({ locale, userConcept, targetType: activeTab });
      setName(proposal.name);
      setSemanticDescriptor(proposal.semanticDescriptor);
      setAffinityCondition(proposal.affinityCondition);
      setArchetype(proposal.archetype);
      setVector(proposal.biophysicalVector);
      startEditing(newItemId(activeTab));
    } catch {
      setHasAiFailed(true);
    } finally {
      setIsGenerating(false);
    }
  }

  function buildTraitDefinition(): TraitDefinition {
    const existing = world.traitsCatalog[itemId];
    return {
      id: itemId,
      name: normalizeField(name, 1, 60, "Custom Adaptation"),
      category: activeTab === "biological_trait" ? "biological" : "cultural",
      semanticDescriptor: normalizeField(semanticDescriptor, 10, 300, "Adaptive modification shaped by ecological selection."),
      affinityCondition: normalizeField(affinityCondition, 5, 200, "Variable ecological conditions"),
      mutuallyExclusiveWith: existing !== undefined ? existing.mutuallyExclusiveWith : [],
      enablesCulturalTransmission: activeTab === "biological_trait" ? enablesCulturalTransmission : false,
      biophysicalVector: validation.balancedVector,
      origin: existing !== undefined ? existing.origin : "user",
      freeSandboxMode
    };
  }

  function save() {
    if (activeTab === "decision") {
      const existing = world.decisionsCatalog[itemId];
      upsertDecision({
        id: itemId,
        name: normalizeField(name, 1, 60, "Custom Strategy"),
        archetype,
        semanticDescriptor: normalizeField(
          semanticDescriptor,
          10,
          300,
          "Behavioral strategy responding to local ecological pressures."
        ),
        requiredTraitIds: existing !== undefined ? existing.requiredTraitIds : [],
        biophysicalVector: validation.balancedVector,
        origin: existing !== undefined ? existing.origin : "user",
        freeSandboxMode
      });
    } else {
      upsertTrait(buildTraitDefinition());
    }
    setVector(validation.balancedVector);
    setIsSaved(true);
  }

  function saveAndInject(demeId: string) {
    save();
    injectTraitIntoDeme(demeId, itemId);
  }

  function renderList() {
    if (activeTab === "decision") {
      return decisionsList.map((decision) => (
        <li key={decision.id}>
          <button
            type="button"
            aria-pressed={isEditing && itemId === decision.id}
            onClick={() => selectDecision(decision)}
            className={`w-full rounded-lg border p-2.5 text-left cursor-pointer ${
              isEditing && itemId === decision.id
                ? "border-sky-500/60 bg-sky-950/40 text-white"
                : "border-slate-800 bg-slate-900/60 text-slate-300 hover:bg-slate-800/60"
            }`}
          >
            <span className="block truncate text-sm font-medium">
              {decision.origin === "base" ? t(`catalog.decisions.${decision.id}.name`) : decision.name}
            </span>
            <span className="mt-0.5 block text-xs text-slate-400">
              {t(`catalogLab.archetypes.${decision.archetype}`)} · {t(`catalogLab.origins.${decision.origin}`)}
            </span>
          </button>
        </li>
      ));
    }
    return traitsList.map((trait) => (
      <li key={trait.id}>
        <button
          type="button"
          aria-pressed={isEditing && itemId === trait.id}
          onClick={() => selectTrait(trait)}
          className={`w-full rounded-lg border p-2.5 text-left cursor-pointer ${
            isEditing && itemId === trait.id
              ? "border-emerald-500/60 bg-emerald-950/40 text-white"
              : "border-slate-800 bg-slate-900/60 text-slate-300 hover:bg-slate-800/60"
          }`}
        >
          <span className="block truncate text-sm font-medium">
            {trait.origin === "base" ? t(`catalog.traits.${trait.id}.name`) : trait.name}
          </span>
          <span className="mt-0.5 block text-xs text-slate-400">{t(`catalogLab.origins.${trait.origin}`)}</span>
        </button>
      </li>
    ));
  }

  function renderForm() {
    return (
      <div className="space-y-5">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div>
            <label htmlFor="catalog-item-name" className={FIELD_LABEL_CLASS}>
              {t("catalogLab.nameLabel")}
            </label>
            <input
              id="catalog-item-name"
              name="itemName"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className={FIELD_CLASS}
            />
          </div>
          {isTraitTab ? (
            <div>
              <label htmlFor="catalog-item-affinity" className={FIELD_LABEL_CLASS}>
                {t("catalogLab.affinityConditionLabel")}
              </label>
              <input
                id="catalog-item-affinity"
                name="affinityCondition"
                type="text"
                value={affinityCondition}
                onChange={(e) => setAffinityCondition(e.target.value)}
                className={FIELD_CLASS}
              />
            </div>
          ) : (
            <div>
              <label htmlFor="catalog-item-archetype" className={FIELD_LABEL_CLASS}>
                {t("catalogLab.archetypeLabel")}
              </label>
              <select
                id="catalog-item-archetype"
                name="archetype"
                value={archetype}
                onChange={(e) => setArchetype(e.target.value as DecisionArchetype)}
                className={FIELD_CLASS}
              >
                {DecisionArchetypeSchema.options.map((option) => (
                  <option key={option} value={option}>
                    {t(`catalogLab.archetypes.${option}`)}
                  </option>
                ))}
              </select>
            </div>
          )}
          <div className="md:col-span-2">
            <label htmlFor="catalog-item-descriptor" className={FIELD_LABEL_CLASS}>
              {t("catalogLab.semanticDescriptorLabel")}
            </label>
            <textarea
              id="catalog-item-descriptor"
              name="semanticDescriptor"
              rows={3}
              value={semanticDescriptor}
              onChange={(e) => setSemanticDescriptor(e.target.value)}
              className={FIELD_CLASS}
            />
          </div>
          {activeTab === "biological_trait" && (
            <label htmlFor="catalog-cultural-transmission" className="flex items-center gap-2 text-sm text-slate-300 cursor-pointer md:col-span-2">
              <input
                id="catalog-cultural-transmission"
                name="enablesCulturalTransmission"
                type="checkbox"
                checked={enablesCulturalTransmission}
                onChange={(e) => setEnablesCulturalTransmission(e.target.checked)}
                className="accent-emerald-500"
              />
              {t("catalogLab.enablesCulturalTransmission")}
            </label>
          )}
        </div>

        <details className="rounded-xl border border-slate-800 bg-slate-950/40 p-4">
          <summary className="flex cursor-pointer list-none items-center gap-2 text-sm font-medium text-slate-200 [&::-webkit-details-marker]:hidden">
            <ChevronRight className="h-4 w-4 text-slate-400 transition-transform [details[open]_&]:rotate-90" />
            <span className="flex-1">{t("catalogLab.biophysicalAxesTitle")}</span>
            {validation.wasAdjusted ? (
              <span className="text-xs text-amber-300">{t("catalogLab.thermodynamicAdjusted")}</span>
            ) : (
              <span className="text-xs text-emerald-300">{t("catalogLab.thermodynamicBalanced")}</span>
            )}
          </summary>
          <p className="mt-2 text-xs text-slate-400">{t("catalogLab.biophysicalAxesHint")}</p>
          <div className="mt-4 grid grid-cols-1 gap-x-6 gap-y-3 md:grid-cols-2">
            {[...BIPOLAR_AXES, "transmissionThreshold" as const].map((axis) => (
              <div key={axis} className="space-y-1">
                <div className="flex justify-between text-xs">
                  <label htmlFor={`axis-${axis}`} className="text-slate-300">
                    {t(`axes.${axis}`)}
                  </label>
                  <span className="font-mono text-slate-200">{vector[axis].toFixed(2)}</span>
                </div>
                <input
                  id={`axis-${axis}`}
                  name={axis}
                  type="range"
                  min={axis === "transmissionThreshold" ? 0 : -1}
                  max={1}
                  step={0.05}
                  value={vector[axis]}
                  onChange={(e) => setVector((prev) => ({ ...prev, [axis]: Number(e.target.value) }))}
                  className="w-full accent-emerald-500"
                />
              </div>
            ))}
          </div>

          <div
            className={`mt-4 space-y-2 rounded-xl border p-3 ${
              metrics.isBalanced ? "border-emerald-500/40 bg-emerald-950/20" : "border-amber-500/40 bg-amber-950/20"
            }`}
          >
            <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-200">
              {validation.wasAdjusted ? (
                <AlertTriangle className="h-4 w-4 text-amber-400" />
              ) : (
                <CheckCircle2 className="h-4 w-4 text-emerald-400" />
              )}
              {t("catalogLab.thermodynamicStatus")}
            </div>
            <dl className="grid grid-cols-3 gap-2 font-mono text-xs">
              <div className="rounded bg-slate-900/70 p-2">
                <dt className="text-[10px] text-slate-400">{t("catalogLab.advantages")}</dt>
                <dd>{metrics.positiveAdvantages.toFixed(2)}</dd>
              </div>
              <div className="rounded bg-slate-900/70 p-2">
                <dt className="text-[10px] text-slate-400">{t("catalogLab.currentCost")}</dt>
                <dd>{metrics.currentCompensatoryCost.toFixed(2)}</dd>
              </div>
              <div className="rounded bg-slate-900/70 p-2">
                <dt className="text-[10px] text-slate-400">{t("catalogLab.requiredCost")}</dt>
                <dd>{metrics.requiredCompensatoryCost.toFixed(2)}</dd>
              </div>
            </dl>
            {validation.wasAdjusted && (
              <p className="font-mono text-xs text-amber-300">
                {t("catalogLab.adjustedMetabolicCost")}: {validation.balancedVector.metabolicCost.toFixed(2)}
              </p>
            )}
            <label htmlFor="catalog-free-sandbox" className="flex items-center gap-2 pt-1 text-xs text-slate-300 cursor-pointer">
              <input
                id="catalog-free-sandbox"
                name="freeSandboxMode"
                type="checkbox"
                checked={freeSandboxMode}
                onChange={(e) => setFreeSandboxMode(e.target.checked)}
                className="accent-amber-500"
              />
              {t("catalogLab.freeSandboxToggle")}
            </label>
          </div>
        </details>
      </div>
    );
  }

  return (
    <Modal
      title={t("catalogLab.title")}
      icon={<FlaskConical className="h-5 w-5 text-emerald-400" />}
      sizeClass="w-[72rem] h-[88vh]"
      onClose={() => setActiveModal("none")}
    >
      <div role="tablist" className="flex shrink-0 gap-2 border-b border-slate-800 bg-slate-950/30 px-6">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            type="button"
            role="tab"
            aria-selected={activeTab === tab.id}
            onClick={() => selectTab(tab.id)}
            className={`border-b-2 px-4 py-2.5 text-sm font-medium cursor-pointer ${
              activeTab === tab.id ? tab.activeClass : "border-transparent text-slate-400 hover:text-slate-200"
            }`}
          >
            {t(`catalogLab.tabs.${tab.id}`)}
          </button>
        ))}
      </div>

      <div className="flex min-h-0 flex-1">
        <div className="flex w-72 shrink-0 flex-col border-r border-slate-800 bg-slate-950/40">
          <div className="border-b border-slate-800 p-3">
            <button
              type="button"
              onClick={createBlank}
              className="flex w-full items-center justify-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm font-medium text-slate-100 hover:bg-slate-700 cursor-pointer"
            >
              <Plus className="h-4 w-4" />
              {t("catalogLab.createNew")}
            </button>
          </div>
          <ul className="flex-1 space-y-1.5 overflow-y-auto p-3">{renderList()}</ul>
        </div>

        <div className="flex min-w-0 flex-1 flex-col">
          <div className="flex-1 space-y-5 overflow-y-auto p-6">
            <form
              onSubmit={(e) => {
                e.preventDefault();
                void designWithAI();
              }}
              className="space-y-2 rounded-xl border border-indigo-500/30 bg-indigo-950/20 p-4"
            >
              <label htmlFor="catalog-ai-concept" className="flex items-center gap-2 text-sm font-medium text-indigo-200">
                <Sparkles className="h-4 w-4" />
                {t("catalogLab.aiCoDesignTitle")}
              </label>
              <div className="flex gap-3">
                <input
                  id="catalog-ai-concept"
                  name="userConcept"
                  type="text"
                  value={userConcept}
                  onChange={(e) => setUserConcept(e.target.value)}
                  placeholder={t("catalogLab.aiConceptPlaceholder")}
                  className="flex-1 rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none"
                />
                <button
                  type="submit"
                  disabled={isGenerating || userConcept.trim().length < 3}
                  className="flex shrink-0 items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                >
                  <Sparkles className="h-4 w-4" />
                  {isGenerating ? t("catalogLab.aiGenerating") : t("catalogLab.aiGenerateButton")}
                </button>
              </div>
              {hasAiFailed && <p className="text-xs text-rose-300">{t("catalogLab.aiFailed")}</p>}
            </form>

            {isEditing ? (
              renderForm()
            ) : (
              <div className="flex flex-col items-center justify-center rounded-xl border border-dashed border-slate-700 p-10 text-center">
                <FlaskConical className="mb-3 h-10 w-10 text-slate-600" />
                <h3 className="text-sm font-semibold text-slate-200">{t("catalogLab.emptyTitle")}</h3>
                <p className="mt-1 max-w-md text-sm text-slate-400">{t("catalogLab.emptyHint")}</p>
              </div>
            )}
          </div>

          {isEditing && (
            <footer className="flex shrink-0 items-center justify-end gap-3 border-t border-slate-800 bg-slate-950/60 px-6 py-3">
              {isSaved && (
                <span className="mr-auto flex items-center gap-1.5 text-sm text-emerald-300" role="status">
                  <CheckCircle2 className="h-4 w-4" />
                  {t("catalogLab.saved")}
                </span>
              )}
              {isTraitTab && lacksCulturalCapacity && (
                <span className="text-xs text-amber-300">{t("panel.culturalCapacityRequired")}</span>
              )}
              <button
                type="button"
                onClick={save}
                className="flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-500 cursor-pointer"
              >
                <Save className="h-4 w-4" />
                {t("catalogLab.saveToCatalog")}
              </button>
              {isTraitTab && selectedDeme !== undefined && (
                <button
                  type="button"
                  disabled={lacksCulturalCapacity}
                  onClick={() => saveAndInject(selectedDeme.id)}
                  className="flex items-center gap-2 rounded-lg bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-500 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                >
                  <Syringe className="h-4 w-4" />
                  {t("catalogLab.injectIntoSelectedDeme", { name: selectedDeme.name })}
                </button>
              )}
            </footer>
          )}
        </div>
      </div>
    </Modal>
  );
}
