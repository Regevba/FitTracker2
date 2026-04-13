import React from 'react';
import { EmptyState, MetricList, Panel } from './controlCenterPrimitives';

export default function ResearchConsole({ workspace }) {
  if (!workspace) {
    return (
      <EmptyState
        title="Research console unavailable"
        body="The requested research workspace is not configured in the current dashboard snapshot."
      />
    );
  }

  return (
    <div className="space-y-6">
      <Panel
        eyebrow="Research Console"
        title={workspace.title}
        description={workspace.summary}
        dark
      >
        <div className="grid gap-3 md:grid-cols-3">
          <MetricList
            title="Work items"
            items={[
              { label: 'Queued', value: workspace.workItems.length },
              { label: 'Mode', value: workspace.badge },
            ]}
            dark
          />
          <MetricList
            title="Linked items"
            items={[
              { label: 'Connected refs', value: workspace.linkedItems.length },
              { label: 'Truth source', value: workspace.truthMode },
            ]}
            dark
          />
          <MetricList
            title="Required docs"
            items={[
              { label: 'Read first', value: workspace.requiredDocs.length },
              { label: 'Prompt starters', value: workspace.promptStarters.length },
            ]}
            dark
          />
        </div>
      </Panel>

      <div className="grid gap-4 xl:grid-cols-[1.05fr_0.95fr]">
        <Panel
          eyebrow="Queue"
          title="Active work items"
          description="These are the PM-flow chapters and follow-ups this workspace is meant to accelerate."
        >
          <div className="space-y-3">
            {workspace.workItems.length === 0 ? (
              <EmptyState
                title="No queued work items"
                body="This workspace is ready, but there are no active items assigned to it in the current shared queue."
              />
            ) : (
              workspace.workItems.map(item => (
                <div key={item.title} className="rounded-[24px] border border-slate-200 bg-slate-50/70 px-4 py-4 dark:border-white/8 dark:bg-white/[0.03]">
                  <div className="text-sm font-semibold text-slate-950 dark:text-white">{item.title}</div>
                  <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/62">{item.detail}</p>
                </div>
              ))
            )}
          </div>
        </Panel>

        <div className="space-y-4">
          <Panel
            eyebrow="Prompt starters"
            title="Use these to kick off the next pass"
            description="These are intentionally action-oriented so the workspace stays useful even before live agent tooling is embedded."
          >
            <div className="space-y-3">
              {workspace.promptStarters.map(prompt => (
                <div key={prompt} className="rounded-[24px] border border-slate-200 bg-white px-4 py-4 shadow-sm shadow-slate-900/5 dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none">
                  <p className="text-sm leading-6 text-slate-600 dark:text-white/62">{prompt}</p>
                </div>
              ))}
            </div>
          </Panel>

          <Panel
            eyebrow="Linked references"
            title="Connected issues and signals"
            description="These references keep the workspace anchored to live planning and operational context."
          >
            <div className="space-y-3">
              {workspace.linkedItems.map(item => (
                <div key={item.title} className="rounded-[24px] border border-slate-200 bg-white px-4 py-4 shadow-sm shadow-slate-900/5 dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none">
                  <div className="text-sm font-semibold text-slate-950 dark:text-white">{item.title}</div>
                  <div className="mt-1 text-xs leading-5 text-slate-500 dark:text-white/52">{item.detail}</div>
                </div>
              ))}
            </div>
          </Panel>

          <Panel
            eyebrow="Required docs"
            title="Canonical reading stack"
            description="These docs should be opened before the next spec or implementation move."
          >
            <div className="space-y-3">
              {workspace.requiredDocs.map(doc => (
                <a
                  key={doc.id}
                  href={doc.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block rounded-[24px] border border-slate-200 bg-white px-4 py-4 shadow-sm shadow-slate-900/5 transition-colors hover:border-slate-300 dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none dark:hover:border-white/15"
                >
                  <div className="flex items-center justify-between gap-3">
                    <div className="text-sm font-semibold text-slate-950 dark:text-white">{doc.title}</div>
                    <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold text-slate-700 dark:bg-white/10 dark:text-white/72">
                      {doc.sourceLabel}
                    </span>
                  </div>
                  <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/62">{doc.preview}</p>
                </a>
              ))}
            </div>
          </Panel>
        </div>
      </div>
    </div>
  );
}
