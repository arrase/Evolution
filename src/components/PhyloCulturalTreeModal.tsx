import React from "react";
import { useTranslation } from "react-i18next";
import { stratify, tree } from "d3-hierarchy";
import { GitBranch, Eraser, MapPin, Skull, Users } from "lucide-react";
import { useSimulationStore } from "../store/useSimulationStore";
import { LineageNode } from "../types/simulation";
import { Modal } from "./Modal";

export const PhyloCulturalTreeModal: React.FC = () => {
  const { t } = useTranslation();
  const world = useSimulationStore((s) => s.world);
  const activeModal = useSimulationStore((s) => s.activeModal);
  const highlightedLineageId = useSimulationStore((s) => s.highlightedLineageId);
  const setActiveModal = useSimulationStore((s) => s.setActiveModal);
  const setHighlightedLineageId = useSimulationStore((s) => s.setHighlightedLineageId);

  if (activeModal !== "phylo_tree") {
    return null;
  }

  const rawNodes = Object.values(world.lineageTree);
  const isRootNode = (node: LineageNode): boolean =>
    node.parentId === null || node.parentId === node.id || world.lineageTree[node.parentId] === undefined;
  const rootNodes = rawNodes.filter(isRootNode);

  const virtualOrigin: LineageNode = {
    id: "__origin__",
    parentId: null,
    name: "Biota Origin",
    color: "#64748b",
    foundedGeneration: 0,
    extinctGeneration: null,
    founderHexId: "0,0",
    acquiredTraitIds: [],
    divergenceReason: "initial"
  };

  const hierarchyInput: LineageNode[] =
    rootNodes.length === 1
      ? rawNodes.map((node) => (isRootNode(node) ? { ...node, parentId: null } : node))
      : [
          virtualOrigin,
          ...rawNodes.map((node) => (isRootNode(node) ? { ...node, parentId: "__origin__" } : node))
        ];

  const layoutRoot =
    rawNodes.length > 0
      ? tree<LineageNode>().nodeSize([180, 120])(
          stratify<LineageNode>()
            .id((d) => d.id)
            .parentId((d) => d.parentId)(hierarchyInput)
        )
      : null;

  const visibleNodes = layoutRoot !== null ? layoutRoot.descendants().filter((n) => n.data.id !== "__origin__") : [];
  const visibleLinks =
    layoutRoot !== null ? layoutRoot.links().filter((link) => link.source.data.id !== "__origin__") : [];

  const xs = visibleNodes.length > 0 ? visibleNodes.map((n) => n.x) : [0];
  const ys = visibleNodes.length > 0 ? visibleNodes.map((n) => n.y) : [0];
  const minX = Math.min(...xs) - 140;
  const maxX = Math.max(...xs) + 140;
  const minY = Math.min(...ys) - 80;
  const maxY = Math.max(...ys) + 120;
  const viewBoxWidth = Math.max(800, maxX - minX);
  const viewBoxHeight = Math.max(500, maxY - minY);

  const demesList = Object.values(world.demes);

  const getTraitName = (traitId: string): string => {
    const trait = world.traitsCatalog[traitId];
    if (!trait) {
      return traitId;
    }
    return trait.origin === "base" ? t(`catalog.traits.${trait.id}.name`) : trait.name;
  };

  return (
    <Modal
      title={t("phyloTree.title")}
      icon={<GitBranch className="w-5 h-5 text-amber-400" />}
      sizeClass="w-[72rem] h-[86vh]"
      onClose={() => setActiveModal("none")}
    >
        <div className="flex items-center justify-between gap-3 px-6 py-2.5 border-b border-slate-800 text-xs text-slate-400">
          <p>{t("phyloTree.highlightHint")}</p>
          {highlightedLineageId !== null && (
            <button
              type="button"
              onClick={() => setHighlightedLineageId(null)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg font-medium bg-amber-500/20 text-amber-300 border border-amber-500/40 hover:bg-amber-500/30 transition-colors cursor-pointer"
            >
              <Eraser className="w-3.5 h-3.5" />
              <span>{t("phyloTree.clearHighlight")}</span>
            </button>
          )}
        </div>

        {/* SVG Tree Viewport */}
        <div className="flex-1 overflow-auto bg-slate-950/50 p-4">
          <svg
            viewBox={`${minX} ${minY} ${viewBoxWidth} ${viewBoxHeight}`}
            className="w-full h-full min-w-[760px] min-h-[480px]"
          >
            {/* Cubic Bézier Links */}
            <g fill="none">
              {visibleLinks.map((link) => {
                const sx = link.source.x;
                const sy = link.source.y;
                const tx = link.target.x;
                const ty = link.target.y;
                const midY = (sy + ty) / 2;
                const d = `M ${sx} ${sy} C ${sx} ${midY}, ${tx} ${midY}, ${tx} ${ty}`;
                return (
                  <path
                    key={`${link.source.data.id}->${link.target.data.id}`}
                    d={d}
                    stroke={link.target.data.color}
                    strokeWidth={2.5}
                    strokeOpacity={0.65}
                  />
                );
              })}
            </g>

            {/* Lineage Nodes */}
            <g>
              {visibleNodes.map((hierarchyNode) => {
                const node = hierarchyNode.data;
                const livingDemesCount = demesList.filter(
                  (d) => d.lineageId === node.id
                ).length;
                const isExtinct = node.extinctGeneration !== null;
                const isHighlighted = highlightedLineageId === node.id;

                return (
                  <g
                    key={node.id}
                    transform={`translate(${hierarchyNode.x}, ${hierarchyNode.y})`}
                    onClick={() => {
                      setHighlightedLineageId(node.id);
                      setActiveModal("none");
                    }}
                    className="cursor-pointer"
                  >
                    <title>{node.name}</title>
                    <rect
                      x={-82}
                      y={-42}
                      width={164}
                      height={88}
                      rx={10}
                      fill="#0f172a"
                      stroke={node.color}
                      strokeWidth={isHighlighted ? 3.5 : 2}
                    />
                    <circle cx={-66} cy={-24} r={6} fill={node.color} />
                    <text
                      x={-54}
                      y={-20}
                      fill="#f8fafc"
                      fontSize={11}
                      fontWeight={600}
                    >
                      {node.name.slice(0, 18)}
                    </text>

                    <text x={-72} y={-4} fill="#94a3b8" fontSize={9.5}>
                      {`G${node.foundedGeneration} • ${t(`phyloTree.reasons.${node.divergenceReason}`)}`}
                    </text>

                    <text
                      x={-72}
                      y={12}
                      fill={isExtinct ? "#f87171" : "#34d399"}
                      fontSize={9.5}
                      fontWeight={600}
                    >
                      {isExtinct
                        ? `${t("phyloTree.extinctGen")}: G${node.extinctGeneration}`
                        : `${t("phyloTree.living")} (${livingDemesCount})`}
                    </text>

                    <text x={-72} y={26} fill="#cbd5e1" fontSize={9}>
                      {`${t("phyloTree.founderHex")}: (${node.founderHexId})`}
                    </text>

                    <text x={-72} y={39} fill="#a5b4fc" fontSize={8.5}>
                      {node.acquiredTraitIds
                        .slice(0, 2)
                        .map(getTraitName)
                        .join(", ")
                        .slice(0, 26)}
                    </text>
                  </g>
                );
              })}
            </g>
          </svg>
        </div>

        {/* Detailed Lineage Cards Legend */}
        <div className="border-t border-slate-800 bg-slate-900/90 px-6 py-3 max-h-48 overflow-y-auto">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            {visibleNodes.map((hierarchyNode) => {
              const node = hierarchyNode.data;
              const livingDemesCount = demesList.filter((d) => d.lineageId === node.id).length;
              const isExtinct = node.extinctGeneration !== null;
              const isHighlighted = highlightedLineageId === node.id;

              return (
                <button
                  key={node.id}
                  type="button"
                  onClick={() => {
                    setHighlightedLineageId(node.id);
                    setActiveModal("none");
                  }}
                  className={`text-left p-3 rounded-lg border transition-colors ${
                    isHighlighted
                      ? "border-amber-400 bg-amber-950/20"
                      : "border-slate-800 bg-slate-950/60 hover:bg-slate-800/50"
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <span
                        className="w-3 h-3 rounded-full shrink-0"
                        style={{ backgroundColor: node.color }}
                      />
                      <span className="text-sm font-semibold text-slate-100 truncate">
                        {node.name}
                      </span>
                    </div>
                    <span className="text-xs font-mono text-slate-400">
                      {`G${node.foundedGeneration}`}
                    </span>
                  </div>

                  <div className="flex items-center gap-3 mt-1.5 text-xs text-slate-400">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3 h-3 text-slate-500" />
                      {`(${node.founderHexId})`}
                    </span>
                    {isExtinct ? (
                      <span className="flex items-center gap-1 text-rose-400">
                        <Skull className="w-3 h-3" />
                        {`${t("phyloTree.extinctGen")} G${node.extinctGeneration}`}
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 text-emerald-400">
                        <Users className="w-3 h-3" />
                        {t("phyloTree.populationsCount", { count: livingDemesCount })}
                      </span>
                    )}
                  </div>

                  <div className="text-[11px] text-slate-400 mt-1">
                    {t(`phyloTree.reasons.${node.divergenceReason}`)}
                  </div>

                  {node.acquiredTraitIds.length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-2">
                      {node.acquiredTraitIds.map((traitId) => (
                        <span
                          key={traitId}
                          className="px-1.5 py-0.5 rounded bg-indigo-950/70 border border-indigo-500/30 text-[10px] text-indigo-200"
                        >
                          {getTraitName(traitId)}
                        </span>
                      ))}
                    </div>
                  )}
                </button>
              );
            })}
          </div>
        </div>
    </Modal>
  );
};
