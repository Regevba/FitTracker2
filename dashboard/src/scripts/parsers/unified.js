import { parseBacklog } from './backlog.js';
import { parseRoadmap } from './roadmap.js';
import { parsePRD } from './prd.js';
import { parseMetrics } from './metrics.js';
import { parseStateFiles } from './state.js';
import { computeReadySet, computeBlockedSet, groupBySkill } from './tasks.js';

function slugify(name) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

/**
 * Merge all data sources into a unified feature list.
 * Each feature has: name, slug, phase, priority, rice, category, sources[], metrics.
 */
export function getUnifiedFeatures() {
  const backlog = parseBacklog();
  const roadmap = parseRoadmap();
  const prd = parsePRD();
  const metrics = parseMetrics();
  const stateFiles = parseStateFiles();

  const featureMap = new Map();

  function getOrCreate(name) {
    const slug = slugify(name);
    if (!featureMap.has(slug)) {
      featureMap.set(slug, {
        name,
        slug,
        phase: 'backlog',
        priority: null,
        rice: null,
        category: null,
        sources: [],
        prdSection: null,
        metricsCount: 0,
        shipped: null,
      });
    }
    return featureMap.get(slug);
  }

  // Backlog Done → shipped features
  for (const item of backlog.done) {
    const f = getOrCreate(item.name);
    f.phase = 'done';
    f.shipped = item.date;
    f.sources.push('backlog');
  }

  // Backlog Planned → roadmap features with RICE
  for (const item of backlog.planned) {
    const name = item.task.replace(/^Task \d+:\s*/, '');
    const f = getOrCreate(name);
    f.rice = item.rice;
    if (item.description?.includes('✅')) f.phase = 'done';
    f.sources.push('backlog-planned');
  }

  // Backlog items (unscheduled)
  for (const item of backlog.backlog) {
    const f = getOrCreate(item.name);
    if (!f.sources.includes('backlog')) f.sources.push('backlog-unscheduled');
  }

  // Roadmap RICE matrix
  for (const task of roadmap) {
    const f = getOrCreate(task.name);
    f.rice = task.rice;
    f.priority = task.priority || f.priority;
    if (!f.sources.includes('roadmap')) f.sources.push('roadmap');
  }

  // PRD sections
  for (const section of prd) {
    const f = getOrCreate(section.name);
    f.prdSection = section.section;
    if (!f.sources.includes('prd')) f.sources.push('prd');
  }

  // Metrics — count per PRD section
  const metricsBySection = {};
  for (const m of metrics) {
    if (m.prdSection) {
      metricsBySection[m.prdSection] = (metricsBySection[m.prdSection] || 0) + 1;
    }
  }
  for (const f of featureMap.values()) {
    if (f.prdSection && metricsBySection[f.prdSection]) {
      f.metricsCount = metricsBySection[f.prdSection];
    }
  }

  // State files (PM workflow)
  for (const state of stateFiles) {
    const f = getOrCreate(state.feature.replace(/-/g, ' '));
    f.phase = state.current_phase;
    if (!f.sources.includes('state')) f.sources.push('state');

    // Task-level metadata
    const tasks = state.tasks || [];
    if (tasks.length > 0) {
      f.tasks = tasks;
      f.taskCount = tasks.length;
      f.tasksDone = tasks.filter(t => t.status === 'done').length;
      f.tasksReady = computeReadySet(tasks).length;
      f.tasksBlocked = computeBlockedSet(tasks).length;
      f.workType = state.work_type || 'feature';
      f.skillDistribution = Object.fromEntries(groupBySkill(tasks));
    }
  }

  return {
    features: Array.from(featureMap.values()),
    sourceCounts: {
      backlog: backlog.done.length + backlog.planned.length + backlog.backlog.length,
      roadmap: roadmap.length,
      prd: prd.length,
      metrics: metrics.length,
      state: stateFiles.length,
    },
  };
}
