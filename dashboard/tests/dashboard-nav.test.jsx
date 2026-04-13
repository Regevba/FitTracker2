import React from 'react';
import { describe, it, expect } from 'vitest';
import { renderToStaticMarkup } from 'react-dom/server';
import Dashboard from '../src/components/Dashboard.jsx';

const baseProps = {
  features: [
    { name: 'Authentication', slug: 'authentication', phase: 'testing', priority: 'critical', category: 'product' },
    { name: 'Knowledge Hub', slug: 'knowledge-hub', phase: 'done', priority: 'high', category: 'tooling' },
  ],
  alerts: [],
  sources: {
    github: { count: 1, healthy: true, alerts: 0, mode: 'live' },
    shared: { count: 2, healthy: true, alerts: 0, mode: 'shared-layer' },
  },
  frameworkManifest: { framework_version: '4.3', structure: { total_skills: 11, shared_files: 15 } },
  frameworkPulse: {
    sourceTruthScore: 88,
    sharedFeatureCount: 2,
    authoritativeFeatureCount: 2,
    queueCount: 1,
    queuePreview: [{ title: 'Auth runtime verification', priority: 'critical', workType: 'fix', phase: 'verification' }],
    missingInSharedCount: 0,
    missingInStaticCount: 0,
    statusConflictCount: 0,
    totalConflicts: 0,
    missingInShared: [],
    missingInStatic: [],
    highlights: ['2 shared-layer features tracked'],
    conflicts: [],
  },
  externalSyncStatus: {
    aggregate: { source_truth_score: 80, healthy: false },
    sources: {
      github: { repo: 'Regevba/FitTracker2', findings: [] },
      linear: { project: { name: 'FitTracker Roadmap' }, findings: [] },
      notion: { workspace_hub: 'FitMe — Product Hub', findings: [] },
      vercel: { project: { name: 'fit-tracker2' }, findings: [] },
      analytics: { findings: [] },
    },
  },
  cleanupCaseStudy: { title: 'Cleanup', summary: 'Summary' },
  knowledgeHub: {
    summary: { repoDocs: 1, sharedDocs: 1, externalDocs: 0, groups: 1, caseStudies: 1 },
    featuredDocs: [
      { id: 'readme', title: 'README', preview: 'Preview', path: 'README.md', href: '#', sourceLabel: 'Core', truthMode: 'repo fallback' },
    ],
    groups: [
      {
        id: 'tracked-case-studies',
        title: 'Case Studies',
        description: 'Tracked cases',
        truthMode: 'shared-layer',
        docs: [
          { id: 'case-a', title: 'Case A', preview: 'Summary', path: 'docs/case-a.md', href: '#', sourceLabel: 'Case Study', truthMode: 'shared-layer' },
        ],
      },
    ],
  },
  caseStudyFeed: [
    {
      id: 'case-a',
      title: 'Case A',
      status: 'In Progress',
      frameworkVersion: '4.3',
      summary: 'Summary',
      metrics: { testsPassing: 10, buildVerified: true, linearIssuesClosed: 1, notionPagesUpdated: 1 },
    },
  ],
  researchWorkspaces: {
    claudeResearch: {
      title: 'Claude Research Console',
      badge: 'Workflow Surface',
      summary: 'Summary',
      workItems: [],
      linkedItems: [],
      requiredDocs: [],
      promptStarters: [],
      truthMode: 'shared-layer',
    },
    codexResearch: {
      title: 'Codex Research Console',
      badge: 'Implementation Surface',
      summary: 'Summary',
      workItems: [],
      linkedItems: [],
      requiredDocs: [],
      promptStarters: [],
      truthMode: 'shared-layer',
    },
    figmaHandoff: {
      title: 'Figma Handoff Lab',
      badge: 'Design Workflow',
      summary: 'Summary',
      workItems: [],
      linkedItems: [],
      requiredDocs: [],
      promptStarters: [],
      truthMode: 'repo fallback',
    },
  },
  workspaceMeta: {
    primaryViews: [
      { id: 'control', label: 'Control Room' },
      { id: 'board', label: 'Board' },
      { id: 'table', label: 'Table' },
      { id: 'tasks', label: 'Tasks' },
      { id: 'knowledge', label: 'Knowledge' },
    ],
    secondaryWorkspaces: [
      { id: 'case-studies', label: 'Case Studies', href: '/case-studies' },
      { id: 'claude-research', label: 'Claude Research', href: '/?view=claude-research' },
      { id: 'codex-research', label: 'Codex Research', href: '/?view=codex-research' },
      { id: 'figma-handoff', label: 'Figma Handoff', href: '/?view=figma-handoff' },
    ],
  },
};

describe('Dashboard navigation', () => {
  it('renders the knowledge tab and workspace dropdown entries', () => {
    const markup = renderToStaticMarkup(<Dashboard {...baseProps} activeView="knowledge" />);

    expect(markup).toContain('Knowledge');
    expect(markup).toContain('Workspaces');
    expect(markup).toContain('Claude Research');
    expect(markup).toContain('/case-studies');
    expect(markup).toContain('Read the current system from one canonical surface');
  });

  it('renders the claude research workspace when selected', () => {
    const markup = renderToStaticMarkup(<Dashboard {...baseProps} activeView="claude-research" />);

    expect(markup).toContain('Claude Research Console');
    expect(markup).toContain('Research Console');
  });
});
