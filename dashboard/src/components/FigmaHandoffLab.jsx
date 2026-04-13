import React from 'react';
import { MetricList, Panel } from './controlCenterPrimitives';

export default function FigmaHandoffLab({ workspace }) {
  return (
    <div className="space-y-6">
      <Panel
        eyebrow="Figma Handoff"
        title={workspace.title}
        description={workspace.summary}
      >
        <div className="grid gap-3 md:grid-cols-3">
          <MetricList
            title="Lab status"
            items={[
              { label: 'Mode', value: workspace.badge },
              { label: 'Prompt starters', value: workspace.promptStarters.length },
            ]}
            dark
          />
          <MetricList
            title="Linked assets"
            items={[
              { label: 'Connected refs', value: workspace.workItems.length },
              { label: 'Required docs', value: workspace.requiredDocs.length },
            ]}
            dark
          />
          <MetricList
            title="Integration posture"
            items={[
              { label: 'Embedded editor', value: 'No' },
              { label: 'Truth mode', value: workspace.truthMode },
            ]}
            dark
          />
        </div>
      </Panel>

      <div className="grid gap-4 xl:grid-cols-[1.05fr_0.95fr]">
        <Panel
          eyebrow="Design references"
          title="Linked sources for the next handoff"
          description="This is the truthful bridge into Figma: canonical file, revision specs, and implementation docs."
        >
          <div className="space-y-3">
            {workspace.workItems.map(item => (
              <a
                key={item.title}
                href={item.href}
                target="_blank"
                rel="noopener noreferrer"
                className="block rounded-[24px] border border-slate-200 bg-slate-50/70 px-4 py-4 transition-colors hover:border-slate-300 hover:bg-white dark:border-white/8 dark:bg-white/[0.03] dark:hover:border-white/15 dark:hover:bg-white/[0.05]"
              >
                <div className="text-sm font-semibold text-slate-950 dark:text-white">{item.title}</div>
                <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/62">{item.detail}</p>
              </a>
            ))}
          </div>
        </Panel>

        <div className="space-y-4">
          <Panel
            eyebrow="Readiness"
            title="Current handoff posture"
            description="Keep the design workflow visible without pretending live editing is already embedded."
          >
            <div className="space-y-3">
              {workspace.linkedItems.map(item => (
                <div key={item.title} className="rounded-[24px] border border-slate-200 bg-white px-4 py-4 shadow-sm shadow-slate-900/5 dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none">
                  <div className="text-sm font-semibold text-slate-950 dark:text-white">{item.title}</div>
                  <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/62">{item.detail}</p>
                </div>
              ))}
            </div>
          </Panel>

          <Panel
            eyebrow="Prompt starters"
            title="Use these to prep the next design sync"
            description="These prompts are designed for the current action-surface stage of the lab."
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
            eyebrow="Required docs"
            title="Read before handoff"
            description="These references keep design decisions tied to the same source-of-truth stack as the rest of the dashboard."
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
                  <div className="text-sm font-semibold text-slate-950 dark:text-white">{doc.title}</div>
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
