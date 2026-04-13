import React from 'react';
import { DocumentCard, DocumentGroupCard, MetricList, Panel } from './controlCenterPrimitives';

export default function KnowledgeHub({ knowledgeHub, caseStudyFeed }) {
  const summary = knowledgeHub?.summary || { repoDocs: 0, sharedDocs: 0, externalDocs: 0, groups: 0, caseStudies: 0 };

  return (
    <div className="space-y-6">
      <Panel
        eyebrow="Knowledge"
        title="Read the current system from one canonical surface"
        description="This tab brings together repo docs, PM framework files, synced external references, and tracked case studies so the control center stays grounded in the actual source material."
      >
        <div className="grid gap-3 md:grid-cols-4">
          <MetricList
            title="Repo docs"
            items={[
              { label: 'Tracked docs', value: summary.repoDocs },
              { label: 'Groups', value: summary.groups },
            ]}
            dark
          />
          <MetricList
            title="Shared layer"
            items={[
              { label: 'Framework files', value: summary.sharedDocs },
              { label: 'Authority', value: 'Shared' },
            ]}
            dark
          />
          <MetricList
            title="External refs"
            items={[
              { label: 'Synced references', value: summary.externalDocs },
              { label: 'State', value: 'Live' },
            ]}
            dark
          />
          <MetricList
            title="Case studies"
            items={[
              { label: 'Tracked cases', value: summary.caseStudies },
              { label: 'Access', value: 'Knowledge + page' },
            ]}
            dark
          />
        </div>

        <div className="mt-4 rounded-[24px] border border-slate-200 bg-slate-50/70 px-4 py-4 dark:border-white/8 dark:bg-white/[0.03]">
          <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400 dark:text-white/38">Featured references</div>
          <div className="mt-3 grid gap-3 lg:grid-cols-2">
            {(knowledgeHub?.featuredDocs || []).map(doc => (
              <DocumentCard key={doc.id} doc={doc} />
            ))}
          </div>
        </div>
      </Panel>

      <Panel
        eyebrow="Case Studies"
        title="Tracked operational narratives"
        description="Case studies now live as a first-class knowledge source inside the dashboard and as a dedicated page for focused reading."
      >
        <div className="grid gap-3 lg:grid-cols-2">
          {caseStudyFeed.map(caseStudy => (
            <a
              key={caseStudy.id}
              href={caseStudy.href || '/case-studies'}
              target={caseStudy.href ? '_blank' : undefined}
              rel={caseStudy.href ? 'noopener noreferrer' : undefined}
              className="rounded-[24px] border border-slate-200 bg-white px-4 py-4 shadow-sm shadow-slate-900/5 transition-colors hover:border-slate-300 dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none dark:hover:border-white/15"
            >
              <div className="flex flex-wrap items-center gap-2">
                <div className="text-sm font-semibold text-slate-950 dark:text-white">{caseStudy.title}</div>
                <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold text-slate-700 dark:bg-white/10 dark:text-white/72">
                  {caseStudy.status}
                </span>
                <span className="rounded-full bg-sky-100 px-2.5 py-1 text-[11px] font-semibold text-sky-700 dark:bg-sky-400/15 dark:text-sky-100">
                  v{caseStudy.frameworkVersion}
                </span>
              </div>
              <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-white/62">{caseStudy.summary}</p>
              <div className="mt-4 grid gap-2 sm:grid-cols-2">
                <MetricList
                  title="Signal"
                  items={[
                    { label: 'Tests', value: caseStudy.metrics.testsPassing },
                    { label: 'Build', value: caseStudy.metrics.buildVerified ? 'Verified' : 'Pending' },
                  ]}
                  dark
                />
                <MetricList
                  title="Flow"
                  items={[
                    { label: 'Linear closed', value: caseStudy.metrics.linearIssuesClosed },
                    { label: 'Notion updates', value: caseStudy.metrics.notionPagesUpdated },
                  ]}
                  dark
                />
              </div>
            </a>
          ))}
        </div>
      </Panel>

      <Panel
        eyebrow="Document Index"
        title="Browse by source and category"
        description="Each group is labeled by truth mode so archive material stays available without being mistaken for the current operating picture."
      >
        <div className="grid gap-4">
          {(knowledgeHub?.groups || []).map(group => (
            <DocumentGroupCard key={group.id} group={group} />
          ))}
        </div>
      </Panel>
    </div>
  );
}
