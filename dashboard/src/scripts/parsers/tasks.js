/**
 * Task parser — reads state.json files and computes task status,
 * dependency chains, skill groupings, and priority queues.
 */

/**
 * Given a tasks array, return tasks whose depends_on are all "done".
 * Tasks with no dependencies are always ready (unless already done/in_progress).
 */
export function computeReadySet(tasks) {
  const statusById = new Map(tasks.map(t => [t.id, t.status]));

  return tasks.filter(t => {
    if (t.status === 'done' || t.status === 'in_progress') return false;
    if (!t.depends_on || t.depends_on.length === 0) return true;
    return t.depends_on.every(depId => statusById.get(depId) === 'done');
  });
}

/**
 * Identify blocked tasks — tasks with at least one unmet dependency.
 */
export function computeBlockedSet(tasks) {
  const statusById = new Map(tasks.map(t => [t.id, t.status]));

  return tasks.filter(t => {
    if (t.status === 'done' || t.status === 'in_progress') return false;
    if (!t.depends_on || t.depends_on.length === 0) return false;
    return t.depends_on.some(depId => statusById.get(depId) !== 'done');
  });
}

/**
 * Topological sort + longest path to find the critical path.
 * Returns an array of task IDs representing the longest dependency chain.
 */
export function computeCriticalPath(tasks) {
  if (!tasks || tasks.length === 0) return [];

  const taskMap = new Map(tasks.map(t => [t.id, t]));
  const inDegree = new Map();
  const adjList = new Map(); // parent → children
  const dist = new Map();   // longest path ending at each node
  const pred = new Map();   // predecessor on longest path

  // Initialize
  for (const t of tasks) {
    inDegree.set(t.id, 0);
    adjList.set(t.id, []);
    dist.set(t.id, 1); // each task has weight 1
    pred.set(t.id, null);
  }

  // Build graph: edge from dependency → dependent
  for (const t of tasks) {
    if (t.depends_on) {
      for (const depId of t.depends_on) {
        if (taskMap.has(depId)) {
          adjList.get(depId).push(t.id);
          inDegree.set(t.id, (inDegree.get(t.id) || 0) + 1);
        }
      }
    }
  }

  // Kahn's algorithm for topological sort
  const queue = [];
  for (const [id, deg] of inDegree) {
    if (deg === 0) queue.push(id);
  }

  const topoOrder = [];
  while (queue.length > 0) {
    const curr = queue.shift();
    topoOrder.push(curr);

    for (const child of adjList.get(curr)) {
      const newDist = dist.get(curr) + 1;
      if (newDist > dist.get(child)) {
        dist.set(child, newDist);
        pred.set(child, curr);
      }
      inDegree.set(child, inDegree.get(child) - 1);
      if (inDegree.get(child) === 0) queue.push(child);
    }
  }

  // Find the node with the longest path
  let maxDist = 0;
  let endNode = null;
  for (const [id, d] of dist) {
    if (d > maxDist) {
      maxDist = d;
      endNode = id;
    }
  }

  // Trace back the critical path
  const path = [];
  let node = endNode;
  while (node !== null) {
    path.unshift(node);
    node = pred.get(node);
  }

  return path;
}

/**
 * Group tasks by skill.
 * Returns a Map of skill → task[].
 */
export function groupBySkill(tasks) {
  const groups = new Map();
  for (const t of tasks) {
    const skill = t.skill || 'unassigned';
    if (!groups.has(skill)) groups.set(skill, []);
    groups.get(skill).push(t);
  }
  return groups;
}

/**
 * Score and sort all ready tasks across features.
 * Default scoring: priority_score from task, boosted for fixes.
 */
export function buildPriorityQueue(allTasks, scoringRules = {}) {
  const {
    fixBoost = 10,
    readyBoost = 5,
    defaultScore = 0,
  } = scoringRules;

  const statusById = new Map(allTasks.map(t => [t.id, t.status]));

  // Only consider tasks that are ready (not done, not blocked)
  const readyTasks = allTasks.filter(t => {
    if (t.status === 'done' || t.status === 'in_progress') return false;
    if (!t.depends_on || t.depends_on.length === 0) return true;
    return t.depends_on.every(depId => statusById.get(depId) === 'done');
  });

  return readyTasks
    .map(t => {
      let score = t.priority_score ?? defaultScore;
      // Boost fixes over features
      if (t.work_type === 'fix' || t.work_type === 'bug') score += fixBoost;
      // Small ready boost for being actionable
      score += readyBoost;
      return { ...t, computedScore: score };
    })
    .sort((a, b) => b.computedScore - a.computedScore);
}

/**
 * Main parser: process state files and extract full task intelligence.
 *
 * @param {Array} stateFiles - array of parsed state.json objects
 * @returns {{ byFeature: Map, bySkill: Map, readyQueue: Array, criticalPaths: Map }}
 */
export function parseTasks(stateFiles) {
  const byFeature = new Map();
  const allTasks = [];
  const criticalPaths = new Map();

  for (const state of stateFiles) {
    const featureName = state.feature || 'unknown';
    const tasks = state.tasks || [];
    if (tasks.length === 0) continue;

    const statusById = new Map(tasks.map(t => [t.id, t.status]));

    // Compute effective status for each task
    const enrichedTasks = tasks.map(t => {
      let effectiveStatus = t.status;
      if (t.status !== 'done' && t.status !== 'in_progress') {
        if (!t.depends_on || t.depends_on.length === 0) {
          effectiveStatus = 'ready';
        } else if (t.depends_on.every(depId => statusById.get(depId) === 'done')) {
          effectiveStatus = 'ready';
        } else {
          effectiveStatus = 'blocked';
        }
      }
      return { ...t, effectiveStatus, featureName };
    });

    byFeature.set(featureName, enrichedTasks);
    allTasks.push(...enrichedTasks);

    // Critical path per feature
    criticalPaths.set(featureName, computeCriticalPath(tasks));
  }

  // Group all tasks by skill
  const bySkill = groupBySkill(allTasks);

  // Build priority queue from all tasks
  const readyQueue = buildPriorityQueue(allTasks);

  return { byFeature, bySkill, readyQueue, criticalPaths };
}
