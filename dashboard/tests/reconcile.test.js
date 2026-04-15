import { describe, it, expect } from 'vitest';
import { reconcile } from '../src/scripts/reconcile.js';

describe('reconcile', () => {
  it('returns empty alerts when all sources are empty', () => {
    const result = reconcile({ githubIssues: [], staticFeatures: [], stateFiles: [] });
    expect(result.alerts).toEqual([]);
    expect(result.sources.github.healthy).toBe(true);
    expect(result.sources.static.healthy).toBe(true);
    expect(result.sources.state.healthy).toBe(true);
  });

  it('detects features in static data missing from GitHub', () => {
    const result = reconcile({
      githubIssues: [{ number: 99, title: 'Other Feature', labels: [], state: 'open' }],
      staticFeatures: [{ name: 'Training Tracking', phase: 'done' }],
      stateFiles: [],
    });
    const missing = result.alerts.filter(a => a.type === 'missing' && a.message.includes('Training Tracking'));
    expect(missing).toHaveLength(1);
    expect(missing[0].severity).toBe('amber');
    expect(result.sources.github.healthy).toBe(false);
  });

  it('detects GitHub issues not in static data', () => {
    const result = reconcile({
      githubIssues: [{ number: 1, title: 'New Feature', labels: [], state: 'open' }],
      staticFeatures: [],
      stateFiles: [],
    });
    expect(result.alerts).toHaveLength(1);
    expect(result.alerts[0].type).toBe('missing');
    expect(result.alerts[0].source).toBe('static');
  });

  it('detects no conflict when sources match', () => {
    const result = reconcile({
      githubIssues: [{ number: 1, title: 'Training Tracking', labels: [{ name: 'phase:done' }], state: 'closed' }],
      staticFeatures: [{ name: 'Training Tracking', phase: 'done' }],
      stateFiles: [],
    });
    // No missing alerts — both sources have it
    const missingAlerts = result.alerts.filter(a => a.type === 'missing');
    expect(missingAlerts).toHaveLength(0);
  });

  it('detects phase conflicts between GitHub and state files', () => {
    // reconcile expects githubIssues to already have a `phase` field (extracted by fetchIssues)
    const result = reconcile({
      githubIssues: [{ number: 12, title: 'development-dashboard', labels: [{ name: 'phase:testing' }], state: 'open', phase: 'testing' }],
      staticFeatures: [],
      stateFiles: [{ feature: 'development-dashboard', current_phase: 'implement' }],
    });
    const conflicts = result.alerts.filter(a => a.type === 'conflict');
    expect(conflicts.length).toBeGreaterThanOrEqual(1);
    expect(conflicts[0].severity).toBe('red');
    expect(conflicts[0].message).toContain('testing');
    expect(conflicts[0].message).toContain('implement');
  });

  it('detects done feature with open GitHub issue', () => {
    const result = reconcile({
      githubIssues: [{ number: 1, title: 'Auth Feature', labels: [{ name: 'phase:done' }], state: 'open' }],
      staticFeatures: [{ name: 'Auth Feature', phase: 'done' }],
      stateFiles: [],
    });
    const conflicts = result.alerts.filter(a => a.type === 'conflict');
    expect(conflicts.length).toBeGreaterThanOrEqual(1);
    expect(conflicts[0].message).toContain('still open');
  });

  it('detects possible duplicates via fuzzy matching', () => {
    const result = reconcile({
      githubIssues: [],
      staticFeatures: [
        { name: 'Training Tracking', phase: 'done' },
        { name: 'Training Trackng', phase: 'done' },
      ],
      stateFiles: [],
    });
    const dupes = result.alerts.filter(a => a.type === 'duplicate');
    expect(dupes.length).toBeGreaterThanOrEqual(1);
    expect(dupes[0].severity).toBe('blue');
  });

  it('detects state files without GitHub issues', () => {
    const result = reconcile({
      githubIssues: [{ number: 99, title: 'Other Feature', labels: [], state: 'open' }],
      staticFeatures: [],
      stateFiles: [{ feature: 'new-feature', current_phase: 'research' }],
    });
    const missing = result.alerts.filter(a => a.type === 'missing' && a.message.includes('PM workflow'));
    expect(missing).toHaveLength(1);
    expect(missing[0].severity).toBe('amber');
    expect(result.sources.github.healthy).toBe(false);
  });

  it('reports correct source counts', () => {
    const result = reconcile({
      githubIssues: [{ number: 1, title: 'A', labels: [], state: 'open' }],
      staticFeatures: [{ name: 'B', phase: 'backlog' }, { name: 'C', phase: 'done' }],
      stateFiles: [{ feature: 'D', current_phase: 'prd' }],
    });
    expect(result.sources.github.count).toBe(1);
    expect(result.sources.static.count).toBe(2);
    expect(result.sources.state.count).toBe(1);
  });
});
