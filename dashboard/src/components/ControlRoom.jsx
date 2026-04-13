import React from 'react';
import { DriftList, MetricList, Panel } from './controlCenterPrimitives';

const PHASE_GROUPS = {
  open: new Set(['backlog', 'research', 'prd']),
  active: new Set(['tasks', 'ux', 'integration', 'implement', 'testing', 'review', 'merge', 'docs']),
  closed: new Set(['done']),
};

function formatPhaseLabel(phase) {
  return phase.replace(/[-_]/g, ' ').replace(/\b\w/g, char => char.toUpperCase());
}

function summarizeFeatures(features) {
  const summary = {
    open: 0,
    active: 0,
    closed: 0,
    critical: 0,
    high: 0,
    categories: {},
    phases: {},
  };

  for (const feature of features) {
    const phase = feature.phase || 'backlog';
    if (PHASE_GROUPS.closed.has(phase)) summary.closed += 1;
    else if (PHASE_GROUPS.active.has(phase)) summary.active += 1;
    else summary.open += 1;

    if (feature.priority === 'critical') summary.critical += 1;
    if (feature.priority === 'high') summary.high += 1;

    const category = feature.category || 'uncategorized';
    summary.categories[category] = (summary.categories[category] || 0) + 1;
    summary.phases[phase] = (summary.phases[phase] || 0) + 1;
  }

  return summary;
}

function collectBlockers(features, alerts) {
  const alertBlockers = alerts.slice(0, 3).map(alert => ({
    title: alert.title || alert.message,
    detail: alert.description || alert.message,
    tone: 'warning',
  }));

  const featureBlockers = features
    .filter(feature => feature.priority === 'critical' || feature.priority === 'high')
    .filter(feature => feature.phase !== 'done')
    .slice(0, 4)
    .map(feature => ({
      title: feature.name,
      detail: `${formatPhaseLabel(feature.phase || 'backlog')} · ${feature.category || 'uncategorized'} · ${feature.truthMode}`,
      tone: feature.priority === 'critical' ? 'critical' : 'warning',
    }));

  return [...alertBlockers, ...featureBlockers].slice(0, 6);
}

function getSourceSummary(sources) {
  return Object.entries(sources).map(([key, source]) => ({
    key,
    label: key === 'static' ? 'Repo Fallback' : key === 'state' ? 'PM State' : key === 'github' ? 'GitHub' : formatPhaseLabel(key),
    count: source.count,
    alerts: source.alerts,
    healthy: source.healthy,
    mode: source.mode || 'repo fallback',
  }));
}

function toneClass(tone) {
  if (tone === 'critical') return 'border-red-400/40 bg-red-500/10 text-red-100';
  if (tone === 'warning') return 'border-amber-300/30 bg-amber-400/10 text-amber-50';
  return 'border-emerald-300/30 bg-emerald-400/10 text-emerald-50';
}

function formatStatusLabel(value) {
  return formatPhaseLabel(value || 'unknown');
}

export default function ControlRoom({ features, alerts, sources, frameworkManifest, frameworkPulse, externalSyncStatus }) {
  const summary = summarizeFeatures(features);
  const blockers = collectBlockers(features, alerts);
  const sourceSummary = getSourceSummary(sources);
  const externalSources = externalSyncStatus?.sources || {};
  const topCategories = Object.entries(summary.categories)
    .sort((left, right) => right[1] - left[1])
    .slice(0, 5);
  const topPhases = Object.entries(summary.phases)
    .sort((left, right) => right[1] - left[1])
    .slice(0, 6);

  return (
    <div className="space-y-6">
      <section className="overflow-hidden rounded-[32px] border border-white/10 bg-[radial-gradient(circle_at_top_left,rgba(250,143,64,0.26),transparent_34%),radial-gradient(circle_at_top_right,rgba(138,199,255,0.2),transparent_28%),linear-gradient(135deg,#151824_0%,#0f1218_46%,#0b0d11_100%)] p-6 text-white shadow-[0_24px_90px_rgba(6,10,18,0.35)] sm:p-8">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-3xl">
            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/6 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.22em] text-white/70">
              Operations Control Room
            </div>
            <h2 className="max-w-2xl text-3xl font-semibold tracking-tight sm:text-4xl">
              Executive health, source drift, planning sync, and blockers in one operator view.
            </h2>
            <p className="mt-4 max-w-2xl text-sm leading-6 text-white/72 sm:text-base">
              The control room is now intentionally narrow: it focuses on what is open, what is under pressure, where truth is drifting, and which operational source needs attention next.
            </p>
            <div className="mt-4 flex flex-wrap gap-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-white/58">
              <span className="rounded-full border border-white/12 bg-white/6 px-3 py-1">
                Framework v{frameworkManifest?.framework_version ?? '4.3'}
              </span>
              <span className="rounded-full border border-white/12 bg-white/6 px-3 py-1">
                {frameworkManifest?.structure?.total_skills ?? 11} skills
              </span>
              <span className="rounded-full border border-white/12 bg-white/6 px-3 py-1">
                {frameworkManifest?.structure?.shared_files ?? 15} shared files
              </span>
              <span className="rounded-full border border-white/12 bg-white/6 px-3 py-1">
                Source truth {frameworkPulse.sourceTruthScore}
              </span>
            </div>
          </div>

          <div className="grid min-w-[280px] gap-3 sm:grid-cols-2">
            <MetricCard label="Open" value={summary.open} accent="from-white/30 to-white/5" detail="Backlog, research, and PRD load" />
            <MetricCard label="Active" value={summary.active} accent="from-sky-300/40 to-sky-400/10" detail="Current implementation, test, and review work" />
            <MetricCard label="Closed" value={summary.closed} accent="from-emerald-300/40 to-emerald-400/10" detail="Shipped and fully closed work" />
            <MetricCard label="Risk" value={summary.critical + summary.high} accent="from-amber-300/40 to-rose-400/10" detail="Critical and high-priority unresolved items" />
          </div>
        </div>
      </section>

      <section className="grid gap-4 xl:grid-cols-[1.25fr_0.95fr]">
        <Panel
          eyebrow="System pulse"
          title="Where the system is heavy, drifting, or under-informed"
          description="This combines source health, blocker pressure, and PM framework truth into one operational readout."
        >
          <div className="grid gap-4 lg:grid-cols-[1.1fr_0.9fr]">
            <div className="rounded-[24px] border border-white/8 bg-white/[0.04] p-4">
              <div className="mb-3 flex items-center justify-between">
                <h3 className="text-sm font-semibold text-white">Source health</h3>
                <span className="text-[11px] uppercase tracking-[0.18em] text-white/45">Mode-aware</span>
              </div>
              <div className="space-y-3">
                {sourceSummary.map(source => (
                  <div key={source.key} className="rounded-2xl border border-white/8 bg-black/15 px-3 py-3">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-medium text-white">{source.label}</div>
                        <div className="text-xs text-white/45">{source.count} records inspected</div>
                      </div>
                      <div className="flex flex-wrap justify-end gap-2">
                        <span className="rounded-full bg-white/8 px-2.5 py-1 text-[11px] font-semibold text-white/72">{source.mode}</span>
                        <span className={`rounded-full px-2.5 py-1 text-[11px] font-semibold ${source.healthy ? 'bg-emerald-400/15 text-emerald-100' : 'bg-amber-300/15 text-amber-100'}`}>
                          {source.healthy ? 'Healthy' : `${source.alerts} alerts`}
                        </span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="rounded-[24px] border border-white/8 bg-white/[0.04] p-4">
              <div className="mb-3 flex items-center justify-between">
                <h3 className="text-sm font-semibold text-white">Top blockers</h3>
                <span className="text-[11px] uppercase tracking-[0.18em] text-white/45">Active risk stack</span>
              </div>
              <div className="space-y-3">
                {blockers.length === 0 ? (
                  <div className="rounded-2xl border border-emerald-300/20 bg-emerald-400/10 px-3 py-4 text-sm text-emerald-50">
                    No major blockers detected in the current snapshot.
                  </div>
                ) : (
                  blockers.map(blocker => (
                    <div key={blocker.title} className={`rounded-2xl border px-3 py-3 ${toneClass(blocker.tone)}`}>
                      <div className="text-sm font-semibold">{blocker.title}</div>
                      <div className="mt-1 text-xs text-current/80">{blocker.detail}</div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </Panel>

        <Panel
          eyebrow="Delivery mix"
          title="What the system is spending attention on"
          description="Keep the category and phase balance visible while the maintenance cycle is still cleaning up truth and execution surfaces."
        >
          <div className="grid gap-4 md:grid-cols-2">
            <MetricList title="By category" items={topCategories.map(([label, value]) => ({ label: formatPhaseLabel(label), value }))} />
            <MetricList title="By phase" items={topPhases.map(([label, value]) => ({ label: formatPhaseLabel(label), value }))} />
          </div>
        </Panel>
      </section>

      <section className="grid gap-4 xl:grid-cols-[1.15fr_1.05fr]">
        <Panel
          eyebrow="Framework truth"
          title="Shared layer vs repo fallback"
          description="This is the current PM-flow truth pulse: what the shared layer knows, what the fallback dataset still carries, and where mismatches remain."
        >
          <div className="grid gap-3 md:grid-cols-4">
            <MetricList title="Shared features" items={[{ label: 'Registry entries', value: frameworkPulse.sharedFeatureCount }]} />
            <MetricList title="Authoritative set" items={[{ label: 'Dashboard features', value: frameworkPulse.authoritativeFeatureCount }]} />
            <MetricList
              title="Coverage gaps"
              items={[
                { label: 'Missing in shared', value: frameworkPulse.missingInSharedCount },
                { label: 'Missing in static', value: frameworkPulse.missingInStaticCount },
              ]}
            />
            <MetricList title="Conflicts" items={[{ label: 'Status mismatches', value: frameworkPulse.statusConflictCount }]} />
          </div>

          <div className="mt-4 grid gap-4 lg:grid-cols-[0.95fr_1.05fr]">
            <div className="rounded-2xl border border-white/8 bg-black/15 px-4 py-4">
              <div className="text-[11px] font-semibold uppercase tracking-[0.18em] text-white/38">Highlights</div>
              <div className="mt-3 space-y-2">
                {frameworkPulse.highlights.map(item => (
                  <div key={item} className="text-sm leading-6 text-white/68">
                    {item}
                  </div>
                ))}
              </div>
            </div>

            <div className="rounded-2xl border border-white/8 bg-black/15 px-4 py-4">
              <div className="text-[11px] font-semibold uppercase tracking-[0.18em] text-white/38">Queue preview</div>
              <div className="mt-3 space-y-3">
                {frameworkPulse.queuePreview.map(item => (
                  <div key={item.title} className="rounded-2xl border border-white/8 bg-white/[0.04] px-3 py-3">
                    <div className="text-sm font-semibold text-white">{item.title}</div>
                    <div className="mt-1 text-xs leading-5 text-white/52">
                      {formatStatusLabel(item.priority)} priority · {formatStatusLabel(item.workType)} · {formatStatusLabel(item.phase)}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Panel>

        <div className="space-y-4">
          <DriftList
            title="Missing from shared layer"
            description="Items still visible in repo fallback data but not yet modeled in the shared PM registry."
            tone="warning"
            items={frameworkPulse.missingInShared.map(item => ({
              key: item.name,
              title: item.name,
              detail: `${formatStatusLabel(item.phase)} phase · ${formatStatusLabel(item.priority)} priority`,
            }))}
            emptyMessage="No repo-fallback-only items detected in the current snapshot."
          />
          <DriftList
            title="Missing from dashboard fallback"
            description="Items present in the shared registry that are still not mirrored in the fallback planning dataset."
            tone="info"
            items={frameworkPulse.missingInStatic.map(item => ({
              key: item.name,
              title: item.name,
              detail: `${formatStatusLabel(item.status)} status · ${formatStatusLabel(item.phase)} phase`,
            }))}
            emptyMessage="No shared-only items detected in the current snapshot."
          />
        </div>
      </section>

      <Panel
        eyebrow="Planning sync"
        title="External truth sources and remaining debt"
        description="The repo and shared layer are cleaner now. These are the live workspace findings that still need cleanup or validation."
      >
        <div className="grid gap-4 lg:grid-cols-2">
          <DriftList
            title="GitHub sync findings"
            description="Repo-truth and issue-hydration limits surfaced from the canonical checkout."
            tone="info"
            items={(externalSources.github?.findings || []).map(item => ({
              key: item,
              title: item,
              detail: externalSources.github.repo || 'Regevba/FitTracker2',
            }))}
            emptyMessage="No GitHub sync issues detected in the current snapshot."
          />
          <DriftList
            title="Linear sync findings"
            description="Roadmap and issue-state gaps surfaced from the current Linear workspace."
            tone="warning"
            items={(externalSources.linear?.findings || []).map(item => ({
              key: item,
              title: item,
              detail: externalSources.linear.project?.name || 'FitTracker Roadmap',
            }))}
            emptyMessage="No Linear sync issues detected in the current snapshot."
          />
          <DriftList
            title="Notion sync findings"
            description="Documentation-health findings from the tracked Notion status surfaces."
            tone="info"
            items={(externalSources.notion?.findings || []).map(item => ({
              key: item,
              title: item,
              detail: externalSources.notion.workspace_hub || 'FitMe — Product Hub',
            }))}
            emptyMessage="No Notion sync issues detected in the current snapshot."
          />
          <DriftList
            title="Vercel + analytics findings"
            description="Deployment, observability, and measurement gaps still visible in the live stack."
            tone="warning"
            items={[
              ...(externalSources.vercel?.findings || []).map(item => ({
                key: item,
                title: item,
                detail: externalSources.vercel.project?.name || 'fit-tracker2',
              })),
              ...(externalSources.analytics?.findings || []).map(item => ({
                key: `analytics-${item}`,
                title: item,
                detail: 'Analytics / observability',
              })),
            ]}
            emptyMessage="No Vercel or analytics issues detected in the current snapshot."
          />
        </div>
      </Panel>
    </div>
  );
}

function MetricCard({ label, value, accent, detail }) {
  return (
    <div className={`rounded-[24px] border border-white/10 bg-gradient-to-br ${accent} px-4 py-4 backdrop-blur`}>
      <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-white/55">{label}</div>
      <div className="mt-2 text-3xl font-semibold tracking-tight text-white">{value}</div>
      <div className="mt-2 text-xs leading-5 text-white/60">{detail}</div>
    </div>
  );
}
