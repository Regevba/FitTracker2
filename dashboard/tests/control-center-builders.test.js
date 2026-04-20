import { describe, it, expect } from 'vitest';
import { buildDashboardData, isPrimaryView, isSecondaryWorkspace } from '../src/scripts/builders/controlCenter.js';

describe('control center builders', () => {
  it('recognizes primary and secondary workspace ids', () => {
    expect(isPrimaryView('knowledge')).toBe(true);
    expect(isPrimaryView('claude-research')).toBe(false);
    expect(isSecondaryWorkspace('claude-research')).toBe(true);
    expect(isSecondaryWorkspace('control')).toBe(false);
  });

  it('builds dashboard data from shared PM sources', async () => {
    const data = await buildDashboardData();

    expect(data.frameworkManifest.framework_version).toBe('6.1');
    expect(data.workspaceMeta.primaryViews.map(item => item.id)).toContain('knowledge');
    expect(data.workspaceMeta.secondaryWorkspaces.map(item => item.id)).toContain('case-studies');
    expect(data.caseStudyFeed.some(item => item.id === 'cleanup-control-room-2026-04')).toBe(true);
    expect(data.caseStudyFeed.some(item => item.id === 'control-center-alignment-ia-refresh-2026-04')).toBe(true);
    expect(data.knowledgeHub.groups.some(group => group.id === 'tracked-case-studies')).toBe(true);
    expect(data.features.some(feature => feature.truthMode === 'shared-layer')).toBe(true);

    const allDocs = data.knowledgeHub.groups.flatMap(group => group.docs);
    expect(allDocs.some(doc => String(doc.path).includes('.claude/worktrees'))).toBe(false);
  });

  it('handles case-study entries with missing artifacts gracefully', async () => {
    const data = await buildDashboardData();
    expect(data.caseStudyFeed).toBeDefined();
    expect(Array.isArray(data.caseStudyFeed)).toBe(true);
    data.caseStudyFeed.forEach(item => {
      expect(typeof item.id).toBe('string');
    });
  });
});
