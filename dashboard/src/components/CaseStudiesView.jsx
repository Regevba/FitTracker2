import React from 'react';
import { DriftList, InfoTile, MetricList, Panel } from './controlCenterPrimitives';

export default function CaseStudiesView({ caseStudyFeed, title = 'Case Studies', description = 'A focused reading surface for tracked PM-flow, maintenance, and operational case studies.' }) {
  return (
    <div className="space-y-6">
      <Panel
        eyebrow="Case Studies"
        title={title}
        description={description}
      >
        <div className="grid gap-3 md:grid-cols-4">
          <MetricList
            title="Coverage"
            items={[
              { label: 'Tracked cases', value: caseStudyFeed.length },
              { label: 'Framework', value: 'v4.3' },
            ]}
            dark
          />
          <MetricList
            title="Flow"
            items={[
              { label: 'Cleanup programs', value: caseStudyFeed.filter(item => item.workType === 'cleanup_program').length },
              { label: 'Feature cases', value: caseStudyFeed.filter(item => item.workType !== 'cleanup_program').length },
            ]}
            dark
          />
          <MetricList
            title="Signal"
            items={[
              { label: 'Build-verified', value: caseStudyFeed.filter(item => item.metrics.buildVerified).length },
              { label: 'Tested', value: caseStudyFeed.filter(item => item.metrics.testsPassing > 0).length },
            ]}
            dark
          />
          <MetricList
            title="Access"
            items={[
              { label: 'Knowledge tab', value: 'Yes' },
              { label: 'Standalone page', value: 'Yes' },
            ]}
            dark
          />
        </div>
      </Panel>

      {caseStudyFeed.map(caseStudy => (
        <Panel
          key={caseStudy.id}
          eyebrow={caseStudy.workType.replace(/_/g, ' ')}
          title={caseStudy.title}
          description={caseStudy.summary}
        >
          <div className="grid gap-4 xl:grid-cols-[1.05fr_0.95fr]">
            <div className="space-y-4">
              <div className="grid gap-3 md:grid-cols-2">
                <InfoTile
                  title="Current status"
                  body={`${caseStudy.status} · Started ${caseStudy.started} · Updated ${caseStudy.updated} · Framework v${caseStudy.frameworkVersion}.`}
                />
                <InfoTile
                  title="Measured signal"
                  body={`${caseStudy.metrics.linearIssuesClosed} Linear issues closed, ${caseStudy.metrics.notionPagesUpdated} Notion pages updated, ${caseStudy.metrics.testsPassing} tests passing, build ${caseStudy.metrics.buildVerified ? 'verified' : 'pending'}.`}
                />
              </div>

              <div className="grid gap-3 md:grid-cols-3">
                <MetricList
                  title="Process"
                  items={[
                    { label: 'Files added', value: caseStudy.metrics.repoFilesAdded },
                    { label: 'Files updated', value: caseStudy.metrics.repoFilesUpdated },
                  ]}
                  dark
                />
                <MetricList
                  title="Quality"
                  items={[
                    { label: 'Critical', value: caseStudy.metrics.criticalFindings },
                    { label: 'High', value: caseStudy.metrics.highFindings },
                    { label: 'Medium', value: caseStudy.metrics.mediumFindings },
                  ]}
                  dark
                />
                <MetricList
                  title="Cycle"
                  items={[
                    { label: 'Snapshots', value: caseStudy.timeline.length },
                    { label: 'Artifacts', value: caseStudy.artifacts.length },
                  ]}
                  dark
                />
              </div>

              <div className="rounded-[24px] border border-slate-200 bg-slate-50/70 px-4 py-4 dark:border-white/8 dark:bg-white/[0.03]">
                <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400 dark:text-white/38">Timeline</div>
                <div className="mt-3 space-y-3">
                  {caseStudy.timeline.map(snapshot => (
                    <div key={`${caseStudy.id}-${snapshot.label}`} className="rounded-[24px] border border-slate-200 bg-white px-4 py-4 shadow-sm shadow-slate-900/5 dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none">
                      <div className="flex flex-wrap items-center gap-2">
                        <div className="text-sm font-semibold text-slate-950 dark:text-white">{snapshot.label}</div>
                        <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold text-slate-700 dark:bg-white/10 dark:text-white/72">
                          {snapshot.date}
                        </span>
                      </div>
                      <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/62">{snapshot.summary}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <DriftList
                title="Success cases"
                description="What this case study proved or improved."
                tone="info"
                items={caseStudy.successCases.map(item => ({
                  key: item.title,
                  title: item.title,
                  detail: item.evidence,
                }))}
                emptyMessage="No success cases recorded yet."
              />
              <DriftList
                title="Failure cases"
                description="What went wrong or stayed unresolved."
                tone="warning"
                items={caseStudy.failureCases.map(item => ({
                  key: item.title,
                  title: item.title,
                  detail: item.evidence,
                }))}
                emptyMessage="No failure cases recorded yet."
              />
              <DriftList
                title="Next checkpoints"
                description="What should happen next if this case study continues evolving."
                tone="info"
                items={caseStudy.nextCheckpoints.map(item => ({
                  key: item,
                  title: item,
                  detail: caseStudy.docPath || 'Shared PM monitoring',
                }))}
                emptyMessage="No next checkpoints recorded yet."
              />
            </div>
          </div>
        </Panel>
      ))}
    </div>
  );
}
