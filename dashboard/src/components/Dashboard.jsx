import React, { useState, useEffect } from 'react';
import KanbanBoard from './KanbanBoard';
import TableView from './TableView';
import TaskBoard from './TaskBoard';
import PipelineOverview from './PipelineOverview';
import AlertsBanner from './AlertsBanner';
import SourceHealth from './SourceHealth';
import ThemeToggle from './ThemeToggle';
import ControlRoom from './ControlRoom';
import KnowledgeHub from './KnowledgeHub';
import ResearchConsole from './ResearchConsole';
import FigmaHandoffLab from './FigmaHandoffLab';
import { trackDashboardLoad } from '../scripts/analytics.js';

const PRIMARY_VIEW_SET = new Set(['control', 'board', 'table', 'tasks', 'knowledge']);
const SECONDARY_VIEW_SET = new Set(['claude-research', 'codex-research', 'figma-handoff']);

function getViewFromURL(fallback = 'control') {
  if (typeof window === 'undefined') return fallback;
  const params = new URLSearchParams(window.location.search);
  return params.get('view') || 'control';
}

export default function Dashboard({
  features,
  alerts,
  sources,
  frameworkManifest,
  frameworkPulse,
  documentationDebt,
  externalSyncStatus,
  cleanupCaseStudy,
  knowledgeHub,
  caseStudyFeed,
  researchWorkspaces,
  workspaceMeta,
  activeView: initialView = 'control',
  lastSync,
}) {
  const [activeView, setActiveView] = useState(() => getViewFromURL(initialView));

  useEffect(() => {
    const onPopState = () => setActiveView(getViewFromURL());
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  // T1 — fire dashboard_load once on mount for TTC baseline capture (unified-control-center).
  // Idempotent guard inside helper. Uses initial view from URL/state.
  useEffect(() => {
    trackDashboardLoad(activeView);
    // Intentionally empty deps — fire once per mount, not on view switch.
    // Per `rerender-dependencies`: keep deps primitive and stable.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function navigateTo(viewId) {
    const url = viewId === 'control' ? '/' : `/?view=${viewId}`;
    window.history.pushState({}, '', url);
    setActiveView(viewId);
  }

  const openCount = features.filter(feature => !['done'].includes(feature.phase)).length;
  const activeCount = features.filter(feature => !['backlog', 'research', 'prd', 'done'].includes(feature.phase)).length;
  const closedCount = features.filter(feature => feature.phase === 'done').length;
  const selectedPrimaryView = PRIMARY_VIEW_SET.has(activeView) ? activeView : 'control';

  return (
    <div className="mx-auto max-w-[1500px] px-4 py-6 sm:px-6 lg:px-8">
      <header className="mb-6 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex items-start gap-4">
          <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[linear-gradient(135deg,#FA8F40_0%,#FFD39F_45%,#8AC7FF_100%)] shadow-[0_12px_30px_rgba(250,143,64,0.35)]">
            <span className="text-sm font-bold text-slate-950">FM</span>
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-xl font-semibold tracking-tight text-slate-950 dark:text-white">FitMe Operations Control Room</h1>
              <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-500 dark:bg-white/8 dark:text-white/55">
                Maintenance mode
              </span>
              <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-500 dark:bg-white/8 dark:text-white/55">
                PM-flow v{frameworkManifest?.framework_version ?? '4.3'}
              </span>
            </div>
            <p className="mt-1 max-w-2xl text-sm leading-6 text-slate-500 dark:text-white/52">
              Delivery, PM truth, design handoff, research workspaces, and case-study monitoring in one operational surface.
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <StatPill label="Open" value={openCount} />
          <StatPill label="Active" value={activeCount} />
          <StatPill label="Closed" value={closedCount} />
          <a
            href="https://github.com/Regevba/FitTracker2"
            target="_blank"
            rel="noopener"
            className="hidden rounded-full border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-500 transition-colors hover:text-slate-800 dark:border-white/10 dark:bg-white/[0.03] dark:text-white/55 dark:hover:text-white sm:block"
          >
            GitHub
          </a>
          <div className="rounded-full border border-slate-200 bg-white p-1 dark:border-white/10 dark:bg-white/[0.03]">
            <ThemeToggle />
          </div>
        </div>
      </header>

      {alerts.length > 0 && (
        <div className="mb-4">
          <AlertsBanner alerts={alerts} />
        </div>
      )}

      <div className="mb-6">
        <PipelineOverview features={features} />
      </div>

      <div className="mb-4 flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
        <nav className="flex flex-wrap gap-2 rounded-2xl border border-slate-200 bg-white/90 p-1 shadow-sm shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.03] dark:shadow-none">
          {workspaceMeta.primaryViews.map(tab => (
            <WorkspaceLink
              key={tab.id}
              label={tab.label}
              active={selectedPrimaryView === tab.id}
              onClick={() => navigateTo(tab.id)}
            />
          ))}
        </nav>

        <div className="flex flex-wrap items-center gap-3">
          <details className="group relative">
            <summary className="flex cursor-pointer list-none items-center gap-2 rounded-2xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-600 shadow-sm shadow-slate-900/5 transition-colors hover:text-slate-900 dark:border-white/10 dark:bg-white/[0.03] dark:text-white/62 dark:shadow-none dark:hover:text-white">
              Workspaces
              <span className="text-[10px] text-slate-400 dark:text-white/36">▼</span>
            </summary>
            <div className="absolute right-0 z-20 mt-2 min-w-[220px] rounded-2xl border border-slate-200 bg-white p-2 shadow-[0_18px_50px_rgba(15,23,42,0.1)] dark:border-white/10 dark:bg-[#10141d]">
              {workspaceMeta.secondaryWorkspaces.map(item => {
                const active = activeView === item.id;
                const isRouteOnly = item.routeOnly;
                return isRouteOnly ? (
                  <a
                    key={item.id}
                    href={item.href}
                    className={`block rounded-xl px-3 py-2 text-sm transition-colors ${
                      active
                        ? 'bg-slate-950 text-white dark:bg-white dark:text-slate-950'
                        : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 dark:text-white/68 dark:hover:bg-white/[0.05] dark:hover:text-white'
                    }`}
                  >
                    {item.label}
                  </a>
                ) : (
                  <button
                    key={item.id}
                    onClick={() => navigateTo(item.id)}
                    className={`block w-full rounded-xl px-3 py-2 text-left text-sm transition-colors ${
                      active
                        ? 'bg-slate-950 text-white dark:bg-white dark:text-slate-950'
                        : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 dark:text-white/68 dark:hover:bg-white/[0.05] dark:hover:text-white'
                    }`}
                  >
                    {item.label}
                  </button>
                );
              })}
            </div>
          </details>

          <div className="text-xs uppercase tracking-[0.18em] text-slate-400 dark:text-white/36">
            {features.length} features · {frameworkManifest?.structure?.total_skills ?? 11} skills · {frameworkManifest?.structure?.shared_files ?? 15} shared files
          </div>
        </div>
      </div>

      <div className="mb-8">
        {/* Secondary workspaces replace the primary view when active */}
        {activeView === 'claude-research' ? (
          <ResearchConsole workspace={researchWorkspaces.claudeResearch} />
        ) : activeView === 'codex-research' ? (
          <ResearchConsole workspace={researchWorkspaces.codexResearch} />
        ) : activeView === 'figma-handoff' ? (
          <FigmaHandoffLab workspace={researchWorkspaces.figmaHandoff} />
        ) : (
          <>
            {selectedPrimaryView === 'control' && (
              <ControlRoom
                features={features}
                alerts={alerts}
                sources={sources}
                frameworkManifest={frameworkManifest}
                frameworkPulse={frameworkPulse}
                documentationDebt={documentationDebt}
                externalSyncStatus={externalSyncStatus}
                cleanupCaseStudy={cleanupCaseStudy}
              />
            )}
            {selectedPrimaryView === 'board' && <KanbanBoard features={features} />}
            {selectedPrimaryView === 'table' && <TableView features={features} />}
            {selectedPrimaryView === 'tasks' && <TaskBoard features={features} />}
            {selectedPrimaryView === 'knowledge' && <KnowledgeHub knowledgeHub={knowledgeHub} caseStudyFeed={caseStudyFeed} />}
          </>
        )}
      </div>

      <div className="rounded-[28px] border border-slate-200 bg-white/90 p-4 shadow-[0_18px_50px_rgba(15,23,42,0.05)] dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none">
        <SourceHealth
          sources={sources}
          lastSync={lastSync}
        />
      </div>

      <footer className="mt-8 border-t border-slate-200/80 pt-4 text-center dark:border-white/8">
        <p className="text-[10px] uppercase tracking-[0.18em] text-slate-400 dark:text-white/34">
          Built with /pm-workflow v{frameworkManifest?.framework_version ?? '4.3'} · Astro + React + Tailwind
        </p>
      </footer>
    </div>
  );
}

function StatPill({ label, value }) {
  return (
    <div className="rounded-full border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-600 shadow-sm shadow-slate-900/5 dark:border-white/10 dark:bg-white/[0.03] dark:text-white/70 dark:shadow-none">
      {label}: <span className="text-slate-950 dark:text-white">{value}</span>
    </div>
  );
}

function WorkspaceLink({ label, active, onClick }) {
  return (
    <button
      onClick={onClick}
      className={`rounded-xl px-3 py-2 text-xs font-semibold transition-colors ${
        active
          ? 'bg-slate-950 text-white shadow-sm dark:bg-white dark:text-slate-950'
          : 'text-slate-500 hover:text-slate-800 dark:text-white/50 dark:hover:text-white'
      }`}
    >
      {label}
    </button>
  );
}
