import { describe, it, expect } from 'vitest';
import {
  computeReadySet,
  computeBlockedSet,
  computeCriticalPath,
  buildPriorityQueue,
  parseTasks,
} from '../src/scripts/parsers/tasks.js';

describe('computeReadySet', () => {
  it('returns tasks with no dependencies as ready', () => {
    const tasks = [
      { id: 'T1', status: 'pending', depends_on: [] },
      { id: 'T2', status: 'pending', depends_on: [] },
    ];
    const ready = computeReadySet(tasks);
    expect(ready.map(t => t.id)).toEqual(['T1', 'T2']);
  });

  it('excludes done and in_progress tasks', () => {
    const tasks = [
      { id: 'T1', status: 'done', depends_on: [] },
      { id: 'T2', status: 'in_progress', depends_on: [] },
      { id: 'T3', status: 'pending', depends_on: [] },
    ];
    const ready = computeReadySet(tasks);
    expect(ready.map(t => t.id)).toEqual(['T3']);
  });

  it('returns tasks whose dependencies are all done', () => {
    const tasks = [
      { id: 'T1', status: 'done', depends_on: [] },
      { id: 'T2', status: 'pending', depends_on: ['T1'] },
      { id: 'T3', status: 'pending', depends_on: ['T1', 'T2'] },
    ];
    const ready = computeReadySet(tasks);
    expect(ready.map(t => t.id)).toEqual(['T2']);
  });

  it('blocks tasks with unmet dependencies', () => {
    const tasks = [
      { id: 'T1', status: 'pending', depends_on: [] },
      { id: 'T2', status: 'pending', depends_on: ['T1'] },
    ];
    const ready = computeReadySet(tasks);
    expect(ready.map(t => t.id)).toEqual(['T1']);
  });

  it('handles tasks with no depends_on field', () => {
    const tasks = [
      { id: 'T1', status: 'pending' },
    ];
    const ready = computeReadySet(tasks);
    expect(ready.map(t => t.id)).toEqual(['T1']);
  });
});

describe('computeBlockedSet', () => {
  it('returns tasks with at least one unmet dependency', () => {
    const tasks = [
      { id: 'T1', status: 'pending', depends_on: [] },
      { id: 'T2', status: 'pending', depends_on: ['T1'] },
      { id: 'T3', status: 'pending', depends_on: ['T1', 'T2'] },
    ];
    const blocked = computeBlockedSet(tasks);
    expect(blocked.map(t => t.id)).toEqual(['T2', 'T3']);
  });

  it('returns empty when all dependencies are met', () => {
    const tasks = [
      { id: 'T1', status: 'done', depends_on: [] },
      { id: 'T2', status: 'pending', depends_on: ['T1'] },
    ];
    const blocked = computeBlockedSet(tasks);
    expect(blocked).toHaveLength(0);
  });
});

describe('computeCriticalPath', () => {
  it('returns empty array for empty input', () => {
    expect(computeCriticalPath([])).toEqual([]);
  });

  it('returns single task for no-dependency case', () => {
    const tasks = [{ id: 'T1', status: 'pending', depends_on: [] }];
    const path = computeCriticalPath(tasks);
    expect(path).toEqual(['T1']);
  });

  it('identifies the longest dependency chain', () => {
    const tasks = [
      { id: 'T1', status: 'done', depends_on: [] },
      { id: 'T2', status: 'pending', depends_on: ['T1'] },
      { id: 'T3', status: 'pending', depends_on: ['T2'] },
      { id: 'T4', status: 'pending', depends_on: ['T1'] }, // shorter branch
    ];
    const path = computeCriticalPath(tasks);
    expect(path).toEqual(['T1', 'T2', 'T3']);
    expect(path.length).toBe(3);
  });

  it('handles diamond dependencies correctly', () => {
    const tasks = [
      { id: 'T1', status: 'done', depends_on: [] },
      { id: 'T2', status: 'pending', depends_on: ['T1'] },
      { id: 'T3', status: 'pending', depends_on: ['T1'] },
      { id: 'T4', status: 'pending', depends_on: ['T2', 'T3'] },
    ];
    const path = computeCriticalPath(tasks);
    // Should be length 3: T1 -> T2|T3 -> T4
    expect(path.length).toBe(3);
    expect(path[0]).toBe('T1');
    expect(path[path.length - 1]).toBe('T4');
  });
});

describe('buildPriorityQueue', () => {
  it('returns only ready tasks sorted by computed score', () => {
    const tasks = [
      { id: 'T1', status: 'done', depends_on: [], priority_score: 10 },
      { id: 'T2', status: 'pending', depends_on: [], priority_score: 5 },
      { id: 'T3', status: 'pending', depends_on: [], priority_score: 20 },
      { id: 'T4', status: 'pending', depends_on: ['T2'], priority_score: 100 },
    ];
    const queue = buildPriorityQueue(tasks);
    // T1 is done, T4 is blocked — only T2 and T3 should appear
    const ids = queue.map(t => t.id);
    expect(ids).not.toContain('T1');
    expect(ids).not.toContain('T4');
    expect(ids.indexOf('T3')).toBeLessThan(ids.indexOf('T2'));
  });

  it('boosts fixes over features', () => {
    const tasks = [
      { id: 'T1', status: 'pending', depends_on: [], priority_score: 10, work_type: 'feature' },
      { id: 'T2', status: 'pending', depends_on: [], priority_score: 10, work_type: 'fix' },
    ];
    const queue = buildPriorityQueue(tasks);
    expect(queue[0].id).toBe('T2');
  });

  it('boosts bugs over features', () => {
    const tasks = [
      { id: 'T1', status: 'pending', depends_on: [], priority_score: 10, work_type: 'feature' },
      { id: 'T2', status: 'pending', depends_on: [], priority_score: 10, work_type: 'bug' },
    ];
    const queue = buildPriorityQueue(tasks);
    expect(queue[0].id).toBe('T2');
  });
});

describe('parseTasks', () => {
  const sampleState = [
    {
      feature: 'auth',
      current_phase: 'implement',
      tasks: [
        { id: 'T1', title: 'Setup DB', status: 'done', depends_on: [], skill: '/dev' },
        { id: 'T2', title: 'Build API', status: 'pending', depends_on: ['T1'], skill: '/dev' },
        { id: 'T3', title: 'Design UI', status: 'pending', depends_on: [], skill: '/design' },
        { id: 'T4', title: 'Write tests', status: 'pending', depends_on: ['T2', 'T3'], skill: '/qa' },
      ],
    },
  ];

  it('groups tasks by feature', () => {
    const { byFeature } = parseTasks(sampleState);
    expect(byFeature.has('auth')).toBe(true);
    expect(byFeature.get('auth')).toHaveLength(4);
  });

  it('groups tasks by skill', () => {
    const { bySkill } = parseTasks(sampleState);
    expect(bySkill.has('/dev')).toBe(true);
    expect(bySkill.get('/dev')).toHaveLength(2);
    expect(bySkill.has('/design')).toBe(true);
    expect(bySkill.get('/design')).toHaveLength(1);
    expect(bySkill.has('/qa')).toBe(true);
    expect(bySkill.get('/qa')).toHaveLength(1);
  });

  it('computes effective status correctly', () => {
    const { byFeature } = parseTasks(sampleState);
    const tasks = byFeature.get('auth');
    const taskMap = new Map(tasks.map(t => [t.id, t]));

    expect(taskMap.get('T1').effectiveStatus).toBe('done');
    expect(taskMap.get('T2').effectiveStatus).toBe('ready');  // T1 is done
    expect(taskMap.get('T3').effectiveStatus).toBe('ready');  // no deps
    expect(taskMap.get('T4').effectiveStatus).toBe('blocked'); // T2 not done
  });

  it('builds a ready queue', () => {
    const { readyQueue } = parseTasks(sampleState);
    expect(readyQueue.length).toBeGreaterThan(0);
    // All items in the queue should be ready (not done, not blocked)
    for (const item of readyQueue) {
      expect(item.effectiveStatus || 'ready').toBe('ready');
    }
  });

  it('computes critical paths per feature', () => {
    const { criticalPaths } = parseTasks(sampleState);
    expect(criticalPaths.has('auth')).toBe(true);
    const path = criticalPaths.get('auth');
    expect(path.length).toBeGreaterThanOrEqual(2);
    // The critical path should be T1 -> T2 -> T4 (length 3)
    expect(path).toEqual(['T1', 'T2', 'T4']);
  });

  it('skips state files with no tasks', () => {
    const result = parseTasks([{ feature: 'empty', current_phase: 'backlog', tasks: [] }]);
    expect(result.byFeature.size).toBe(0);
  });

  it('handles multiple features', () => {
    const multiState = [
      ...sampleState,
      {
        feature: 'onboarding',
        current_phase: 'prd',
        tasks: [
          { id: 'O1', title: 'Research', status: 'done', depends_on: [], skill: '/dev' },
          { id: 'O2', title: 'Build flow', status: 'pending', depends_on: ['O1'], skill: '/dev' },
        ],
      },
    ];
    const { byFeature, bySkill } = parseTasks(multiState);
    expect(byFeature.size).toBe(2);
    // /dev should have tasks from both features
    expect(bySkill.get('/dev').length).toBe(4);
  });
});
