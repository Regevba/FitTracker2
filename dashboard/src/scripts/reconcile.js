/**
 * Cross-source reconciliation engine.
 * Compares features across all data sources and generates alerts.
 */

const PHASES = ['backlog', 'research', 'prd', 'tasks', 'ux', 'integration', 'implement', 'testing', 'review', 'merge', 'docs', 'done'];

function normalize(name) {
  return name.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
}

function levenshtein(a, b) {
  const m = a.length, n = b.length;
  const dp = Array.from({ length: m + 1 }, (_, i) => [i, ...Array(n).fill(0)]);
  for (let j = 1; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++)
    for (let j = 1; j <= n; j++)
      dp[i][j] = a[i-1] === b[j-1] ? dp[i-1][j-1] : 1 + Math.min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]);
  return dp[m][n];
}

export function reconcile({ githubIssues = [], staticFeatures = [], stateFiles = [] }) {
  const alerts = [];
  const sources = {
    github: { count: githubIssues.length, healthy: true, alerts: 0 },
    static: { count: staticFeatures.length, healthy: true, alerts: 0 },
    state: { count: stateFiles.length, healthy: true, alerts: 0 },
  };

  const ghNames = new Set(githubIssues.map(i => normalize(i.title)));
  const staticNames = new Set(staticFeatures.map(f => normalize(f.name)));
  const stateNames = new Set(stateFiles.map(s => normalize(s.feature)));

  // Features in static data but not in GitHub
  for (const feature of staticFeatures) {
    const norm = normalize(feature.name);
    if (!ghNames.has(norm)) {
      alerts.push({
        type: 'missing',
        severity: 'amber',
        message: `"${feature.name}" exists in repo data but has no GitHub Issue`,
        feature: feature.name,
        source: 'github',
      });
      sources.github.alerts++;
    }
  }

  // Features in GitHub but not in static data
  for (const issue of githubIssues) {
    const norm = normalize(issue.title);
    if (!staticNames.has(norm)) {
      alerts.push({
        type: 'missing',
        severity: 'info',
        message: `GitHub Issue #${issue.number} "${issue.title}" not found in repo data files`,
        feature: issue.title,
        source: 'static',
      });
      sources.static.alerts++;
    }
  }

  // State files without GitHub Issues
  for (const state of stateFiles) {
    const norm = normalize(state.feature);
    if (!ghNames.has(norm)) {
      alerts.push({
        type: 'missing',
        severity: 'amber',
        message: `PM workflow "${state.feature}" (phase: ${state.current_phase}) has no GitHub Issue`,
        feature: state.feature,
        source: 'github',
      });
      sources.github.alerts++;
    }
  }

  // Phase/status conflicts between GitHub and state files
  for (const state of stateFiles) {
    const matchingIssue = githubIssues.find(i => normalize(i.title) === normalize(state.feature));
    if (matchingIssue && matchingIssue.phase) {
      const ghPhase = matchingIssue.phase;
      const stPhase = state.current_phase;
      if (ghPhase !== stPhase) {
        alerts.push({
          type: 'conflict',
          severity: 'red',
          message: `"${state.feature}": GitHub says "${ghPhase}" but state.json says "${stPhase}"`,
          feature: state.feature,
          source: 'both',
        });
      }
    }
  }

  // Duplicate detection (fuzzy match)
  const allNames = [...new Set([...staticFeatures.map(f => f.name), ...githubIssues.map(i => i.title)])];
  for (let i = 0; i < allNames.length; i++) {
    for (let j = i + 1; j < allNames.length; j++) {
      const na = normalize(allNames[i]);
      const nb = normalize(allNames[j]);
      if (na !== nb && levenshtein(na, nb) <= 3 && na.length > 5) {
        alerts.push({
          type: 'duplicate',
          severity: 'blue',
          message: `Possible duplicate: "${allNames[i]}" and "${allNames[j]}"`,
          feature: allNames[i],
          source: 'both',
        });
      }
    }
  }

  // Status conflicts (static says done but GitHub issue is open)
  for (const feature of staticFeatures.filter(f => f.phase === 'done')) {
    const matchingIssue = githubIssues.find(i => normalize(i.title) === normalize(feature.name));
    if (matchingIssue && matchingIssue.state === 'open') {
      alerts.push({
        type: 'conflict',
        severity: 'red',
        message: `"${feature.name}" is marked Done in repo but GitHub Issue #${matchingIssue.number} is still open`,
        feature: feature.name,
        source: 'both',
      });
    }
  }

  sources.github.healthy = sources.github.alerts === 0;
  sources.static.healthy = sources.static.alerts === 0;
  sources.state.healthy = sources.state.alerts === 0;

  return { alerts, sources };
}
