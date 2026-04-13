import { readFileSync, readdirSync } from 'node:fs';
import { basename, extname, relative, resolve } from 'node:path';
import featuresData from '../../data/features.json';
import caseStudiesData from '../../data/caseStudies.json';
import { reconcile } from '../reconcile.js';
import { fetchIssues } from '../github.js';
import { parseStateFiles } from '../parsers/state.js';

export const PRIMARY_VIEWS = [
  { id: 'control', label: 'Control Room' },
  { id: 'board', label: 'Board' },
  { id: 'table', label: 'Table' },
  { id: 'tasks', label: 'Tasks' },
  { id: 'knowledge', label: 'Knowledge' },
];

export const SECONDARY_WORKSPACES = [
  { id: 'case-studies', label: 'Case Studies', href: '/case-studies', routeOnly: true },
  { id: 'claude-research', label: 'Claude Research', href: '/?view=claude-research' },
  { id: 'codex-research', label: 'Codex Research', href: '/?view=codex-research' },
  { id: 'figma-handoff', label: 'Figma Handoff', href: '/?view=figma-handoff' },
];

const REPO_ROOT = resolve(process.cwd(), '..');
const GITHUB_BLOB_BASE = 'https://github.com/Regevba/FitTracker2/blob/main/';
const README_FIGMA_URL = 'https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD';

const DOC_GROUP_META = {
  root: {
    title: 'Core Docs',
    description: 'Brand, repo-level guidance, and service READMEs that frame the whole project.',
    truthMode: 'repo fallback',
  },
  product: {
    title: 'Product & Planning',
    description: 'PRD, backlog, metrics, and planning references that define what the product should do.',
    truthMode: 'repo fallback',
  },
  'master-plan': {
    title: 'Master Plan',
    description: 'Longer-running planning, reconciliation, and checkpoint docs from major project cycles.',
    truthMode: 'repo fallback',
  },
  'design-system': {
    title: 'Design System & UX',
    description: 'Design-system governance, UX foundations, visual audits, and handoff guidance.',
    truthMode: 'repo fallback',
  },
  skills: {
    title: 'PM Framework & Skills',
    description: 'The PM-flow v4.3 ecosystem, hub/spoke docs, and framework evolution references.',
    truthMode: 'repo fallback',
  },
  'case-studies': {
    title: 'Case Study Docs',
    description: 'Narrative writeups and showcase docs that explain what happened across major cycles.',
    truthMode: 'archive',
  },
  prompts: {
    title: 'Prompts & Automation',
    description: 'Prompt libraries and handoff runners that support repeatable execution.',
    truthMode: 'repo fallback',
  },
  setup: {
    title: 'Setup & Integrations',
    description: 'Activation and environment setup guidance for local and external systems.',
    truthMode: 'repo fallback',
  },
  process: {
    title: 'Process',
    description: 'Lifecycle and operating-process references for the product workflow.',
    truthMode: 'repo fallback',
  },
  archive: {
    title: 'Archive',
    description: 'Older references kept for continuity and historical access.',
    truthMode: 'archive',
  },
};

const SHARED_PRIORITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3 };

function readSharedJson(relativePath) {
  return JSON.parse(readFileSync(resolve(process.cwd(), relativePath), 'utf-8'));
}

function walkFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const fullPath = resolve(dir, entry.name);
    if (entry.name === '.DS_Store' || entry.name === '.gitkeep') return [];
    if (entry.isDirectory()) return walkFiles(fullPath);
    return [fullPath];
  });
}

function normalizeName(value) {
  return value.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
}

function toTitleCase(value) {
  return value.replace(/[-_]/g, ' ').replace(/\b\w/g, char => char.toUpperCase());
}

function prettyName(value) {
  return value
    .replace(/\.[^.]+$/, '')
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase());
}

function extractTitle(content, fallbackPath) {
  const heading = content
    .split('\n')
    .map(line => line.trim())
    .find(line => line.startsWith('# '));

  return heading ? heading.replace(/^#\s+/, '').trim() : prettyName(basename(fallbackPath));
}

function extractPreview(content, title) {
  const lines = content
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean)
    .filter(line => line !== '---')
    .filter(line => !line.startsWith('!['))
    .filter(line => !line.startsWith('#'))
    .map(line => line.replace(/^>\s*/, ''));

  const preview = lines.find(line => line !== title);
  return preview ? preview.slice(0, 180) : 'Open this document for the full reference.';
}

function buildMarkdownDoc(repoRelativePath, sourceLabel, truthMode = 'repo fallback') {
  const fullPath = resolve(REPO_ROOT, repoRelativePath);
  const content = readFileSync(fullPath, 'utf-8');
  const title = extractTitle(content, repoRelativePath);
  return {
    id: repoRelativePath,
    title,
    preview: extractPreview(content, title),
    path: repoRelativePath,
    href: `${GITHUB_BLOB_BASE}${repoRelativePath}`,
    sourceLabel,
    truthMode,
  };
}

function buildSharedDoc(fullPath) {
  const content = readFileSync(fullPath, 'utf-8');
  const repoRelativePath = relative(REPO_ROOT, fullPath).replace(/\\/g, '/');
  let preview = 'Shared framework data file.';

  try {
    const parsed = JSON.parse(content);
    preview = parsed.description || parsed.note || `${Object.keys(parsed).length} top-level keys.`;
  } catch {
    preview = 'Shared framework data file.';
  }

  return {
    id: repoRelativePath,
    title: prettyName(basename(fullPath)),
    preview: preview.slice(0, 180),
    path: repoRelativePath,
    href: `${GITHUB_BLOB_BASE}${repoRelativePath}`,
    sourceLabel: 'Shared State',
    truthMode: 'shared-layer',
  };
}

function mapSharedPhase(phase, status) {
  if (status === 'shipped' || phase === 'complete') return 'done';
  if (phase === 'implementation') return 'implement';
  if (phase === 'verification') return 'testing';
  if (phase === 'documentation') return 'docs';
  if (phase === 'not_started') return 'backlog';
  return phase || 'backlog';
}

function flattenStaticFeatures() {
  return [
    ...featuresData.shipped.map(feature => ({ ...feature, sourceBucket: 'shipped' })),
    ...featuresData.planned.map(feature => ({ ...feature, sourceBucket: 'planned' })),
    ...featuresData.backlog.map(feature => ({ ...feature, sourceBucket: 'backlog' })),
  ];
}

function buildStaticIndex(staticFeatures) {
  const index = new Map();

  for (const feature of staticFeatures) {
    const keys = new Set([
      normalizeName(feature.name),
      normalizeName(feature.slug || feature.name),
    ]);

    for (const key of keys) {
      if (!index.has(key)) index.set(key, feature);
    }
  }

  return index;
}

function buildFeatureDataset(featureRegistry) {
  const staticFeatures = flattenStaticFeatures();
  const staticIndex = buildStaticIndex(staticFeatures);
  const consumedStatic = new Set();

  const sharedFeatures = (featureRegistry.features || []).map(feature => {
    const match =
      staticIndex.get(normalizeName(feature.name)) ||
      staticIndex.get(normalizeName(feature.id)) ||
      staticIndex.get(normalizeName((feature.id || '').replace(/-/g, ' ')));

    if (match) consumedStatic.add(match.slug || match.name);

    return {
      name: feature.name,
      slug: match?.slug || feature.id || normalizeName(feature.name),
      phase: mapSharedPhase(feature.phase, feature.status),
      priority: match?.priority || null,
      rice: match?.rice || null,
      category: match?.category || feature.category || 'uncategorized',
      shipped: feature.status === 'shipped' ? match?.shipped || 'Shared layer' : null,
      prd: feature.prd || match?.prd || null,
      source: 'shared',
      truthMode: 'shared-layer',
      sourceBucket: 'shared',
      status: feature.status,
      sharedPhase: feature.phase,
      painPoint: feature.pain_point,
      metrics: feature.metrics,
    };
  });

  const staticOnlyFeatures = staticFeatures
    .filter(feature => !consumedStatic.has(feature.slug || feature.name))
    .map(feature => ({
      ...feature,
      source: 'static',
      truthMode: 'repo fallback',
    }));

  return [...sharedFeatures, ...staticOnlyFeatures].sort((left, right) => {
    const leftPriority = SHARED_PRIORITY_ORDER[left.priority] ?? 9;
    const rightPriority = SHARED_PRIORITY_ORDER[right.priority] ?? 9;
    return leftPriority - rightPriority || left.name.localeCompare(right.name);
  });
}

function buildFrameworkPulse(authoritativeFeatures, featureRegistry, taskQueue) {
  const staticFeatures = flattenStaticFeatures();
  const sharedFeatures = featureRegistry.features || [];
  const staticMap = new Map(staticFeatures.map(feature => [normalizeName(feature.name), feature]));
  const sharedMap = new Map(sharedFeatures.map(feature => [normalizeName(feature.name), feature]));

  const missingInShared = staticFeatures.filter(feature => !sharedMap.has(normalizeName(feature.name)));
  const missingInStatic = sharedFeatures.filter(feature => !staticMap.has(normalizeName(feature.name)));
  const statusConflicts = [];

  for (const [key, staticFeature] of staticMap) {
    const sharedFeature = sharedMap.get(key);
    if (!sharedFeature) continue;

    const staticStatus = staticFeature.phase === 'done' ? 'shipped' : 'planned';
    const sharedStatus = sharedFeature.status || 'planned';
    if (staticStatus !== sharedStatus) {
      statusConflicts.push({
        name: staticFeature.name,
        staticStatus,
        sharedStatus,
      });
    }
  }

  const matchedCount = [...staticMap.keys()].filter(key => sharedMap.has(key)).length;
  const totalChecks = matchedCount + missingInShared.length + missingInStatic.length;
  const totalConflicts = missingInShared.length + missingInStatic.length + statusConflicts.length;
  const sourceTruthScore = Math.max(0, Math.round(((totalChecks - totalConflicts) / Math.max(1, totalChecks)) * 100));

  return {
    sourceTruthScore,
    authoritativeFeatureCount: authoritativeFeatures.length,
    sharedFeatureCount: sharedFeatures.length,
    queueCount: taskQueue.queue?.length || 0,
    queuePreview: (taskQueue.queue || []).slice(0, 4).map(item => ({
      title: item.title,
      priority: item.priority || 'unscored',
      workType: item.work_type || 'unspecified',
      phase: item.phase || 'not_started',
    })),
    missingInSharedCount: missingInShared.length,
    missingInStaticCount: missingInStatic.length,
    statusConflictCount: statusConflicts.length,
    totalConflicts,
    missingInShared: missingInShared.slice(0, 5).map(feature => ({
      name: feature.name,
      phase: feature.phase || 'backlog',
      priority: feature.priority || 'none',
    })),
    missingInStatic: missingInStatic.slice(0, 5).map(feature => ({
      name: feature.name,
      status: feature.status || 'planned',
      phase: feature.phase || 'not_started',
    })),
    highlights: [
      `${sharedFeatures.length} shared-layer features tracked`,
      `${taskQueue.queue?.length || 0} queued tasks in priority queue`,
      `${missingInShared.length} repo-fallback items still missing from shared state`,
      `${missingInStatic.length} shared-layer items still missing from dashboard fallback data`,
      `${statusConflicts.length} status conflicts between repo fallback data and the shared feature registry`,
    ],
    conflicts: statusConflicts.slice(0, 4),
  };
}

function buildCaseStudyFeed(caseStudyMonitoring) {
  const narrativeMap = {
    [caseStudiesData.cleanupControlRoom.id]: caseStudiesData.cleanupControlRoom,
    ...(caseStudiesData.controlCenterAlignment
      ? { [caseStudiesData.controlCenterAlignment.id]: caseStudiesData.controlCenterAlignment }
      : {}),
  };

  return caseStudyMonitoring.cases
    .map(caseItem => {
      const narrative = narrativeMap[caseItem.case_id] || {};
      const docPath = caseItem.artifacts.find(item => item.startsWith('docs/case-studies/')) || null;
      const latestSnapshot = caseItem.snapshots[caseItem.snapshots.length - 1];

      return {
        id: caseItem.case_id,
        slug: caseItem.case_id,
        title: caseItem.title,
        status: toTitleCase(caseItem.status),
        workType: caseItem.work_type,
        started: caseItem.started_at.slice(0, 10),
        updated: caseItem.updated_at.slice(0, 10),
        frameworkVersion: caseItem.framework_version,
        summary: narrative.summary || latestSnapshot?.summary || 'Tracked PM-flow case study.',
        whyItMatters: narrative.why_it_matters || null,
        sourceTruthScore: narrative.monitoring?.source_truth_score ?? null,
        alertCount: narrative.monitoring?.alert_count ?? null,
        routedWorkspacesAdded: narrative.monitoring?.routed_workspaces_added ?? null,
        knowledgeGroupsExposed: narrative.monitoring?.knowledge_groups_exposed ?? null,
        metrics: {
          linearIssuesClosed: caseItem.process_metrics.linear_issues_closed,
          linearIssuesCreated: caseItem.process_metrics.linear_issues_created,
          notionPagesCreated: caseItem.process_metrics.notion_pages_created,
          notionPagesUpdated: caseItem.process_metrics.notion_pages_updated,
          repoFilesAdded: caseItem.process_metrics.repo_files_added,
          repoFilesUpdated: caseItem.process_metrics.repo_files_updated,
          testsPassing: caseItem.process_metrics.tests_passing,
          buildVerified: caseItem.process_metrics.build_verified,
          criticalFindings: caseItem.quality_metrics.critical_findings,
          highFindings: caseItem.quality_metrics.high_findings,
          mediumFindings: caseItem.quality_metrics.medium_findings,
        },
        timeline: caseItem.snapshots.map(snapshot => ({
          label: snapshot.label,
          date: snapshot.timestamp.slice(0, 10),
          summary: snapshot.summary,
          testsPassing: snapshot.metrics.tests_passing,
          buildVerified: snapshot.metrics.build_verified,
        })),
        skillsFramework: narrative.skills_framework || [],
        successCases: caseItem.success_cases,
        failureCases: caseItem.failure_cases,
        nextCheckpoints: caseItem.next_checkpoints,
        artifacts: caseItem.artifacts,
        docPath,
        href: docPath ? `${GITHUB_BLOB_BASE}${docPath}` : null,
        truthMode: 'shared-layer',
      };
    })
    .sort((left, right) => right.started.localeCompare(left.started));
}

function buildCleanupCaseStudy(caseStudyFeed) {
  return caseStudyFeed.find(caseStudy => caseStudy.id === 'cleanup-control-room-2026-04');
}

function buildKnowledgeHub(externalSyncStatus, caseStudyFeed) {
  const docsRoot = resolve(REPO_ROOT, 'docs');
  const sharedRoot = resolve(REPO_ROOT, '.claude/shared');
  const docFiles = walkFiles(docsRoot).filter(file => ['.md', '.csv'].includes(extname(file)));
  const groupedRepoDocs = new Map();

  const rootDocs = [
    'README.md',
    'CLAUDE.md',
    'ai-engine/README.md',
    'backend/README.md',
  ].map(path => buildMarkdownDoc(path, 'Core', 'repo fallback'));

  groupedRepoDocs.set('root', rootDocs);

  for (const fullPath of docFiles) {
    const repoRelativePath = relative(REPO_ROOT, fullPath).replace(/\\/g, '/');
    const [, groupKey = 'archive'] = repoRelativePath.split('/');
    const groupId = DOC_GROUP_META[groupKey] ? groupKey : 'archive';
    const docs = groupedRepoDocs.get(groupId) || [];
    docs.push(buildMarkdownDoc(repoRelativePath, 'Repo Docs', DOC_GROUP_META[groupId].truthMode));
    groupedRepoDocs.set(groupId, docs);
  }

  const sharedDocs = walkFiles(sharedRoot)
    .filter(file => extname(file) === '.json')
    .map(buildSharedDoc)
    .sort((a, b) => a.title.localeCompare(b.title));

  const externalDocs = [
    ...(externalSyncStatus?.sources?.notion?.tracked_pages || []).map(page => ({
      id: `notion-${page.title}`,
      title: page.title,
      preview: page.role,
      path: 'Notion',
      href: page.url,
      sourceLabel: 'Notion',
      truthMode: 'live',
    })),
    ...(externalSyncStatus?.sources?.linear?.project
      ? [{
          id: 'linear-project',
          title: externalSyncStatus.sources.linear.project.name,
          preview: `Linear project · ${externalSyncStatus.sources.linear.project.status}`,
          path: 'Linear',
          href: externalSyncStatus.sources.linear.project.url,
          sourceLabel: 'Linear',
          truthMode: 'live',
        }]
      : []),
    ...(externalSyncStatus?.sources?.linear?.tracked_issues || []).map(issue => ({
      id: issue.id,
      title: `${issue.id} — ${issue.title}`,
      preview: `${issue.status} · ${issue.priority} priority`,
      path: 'Linear',
      href: `https://linear.app/fitme-project/issue/${issue.id.toLowerCase()}/${normalizeName(issue.title)}`,
      sourceLabel: 'Linear',
      truthMode: 'live',
    })),
    ...(externalSyncStatus?.sources?.vercel?.projects
      ? Object.values(externalSyncStatus.sources.vercel.projects).map(project => ({
          id: `vercel-${project.name}`,
          title: `${project.name} Vercel Project`,
          preview: `${project.framework} · ${project.live ? 'canonical' : 'cleanup debt'} project`,
          path: 'Vercel',
          href: project.url,
          sourceLabel: 'Vercel',
          truthMode: 'live',
        }))
      : []),
  ];

  const featuredCandidates = [
    'README.md',
    'docs/product/PRD.md',
    'docs/product/backlog.md',
    'docs/master-plan/master-backlog-roadmap.md',
    'docs/skills/README.md',
    '.claude/shared/framework-manifest.json',
    '.claude/shared/external-sync-status.json',
  ];

  const repoAndSharedDocs = [...groupedRepoDocs.values()].flat().concat(sharedDocs);
  const featuredDocs = featuredCandidates
    .map(path => repoAndSharedDocs.find(doc => doc.path === path))
    .filter(Boolean);

  const groups = [
    ...Object.entries(DOC_GROUP_META)
      .filter(([groupId]) => groupedRepoDocs.has(groupId))
      .map(([groupId, meta]) => ({
        id: groupId,
        title: meta.title,
        description: meta.description,
        truthMode: meta.truthMode,
        docs: (groupedRepoDocs.get(groupId) || []).sort((a, b) => a.title.localeCompare(b.title)),
      })),
    {
      id: 'tracked-case-studies',
      title: 'Case Studies',
      description: 'Tracked operational and feature case studies built from shared PM monitoring and linked narrative docs.',
      truthMode: 'shared-layer',
      docs: caseStudyFeed.map(caseStudy => ({
        id: caseStudy.id,
        title: caseStudy.title,
        preview: caseStudy.summary,
        path: caseStudy.docPath || caseStudy.id,
        href: caseStudy.href || '/case-studies',
        sourceLabel: 'Case Study',
        truthMode: 'shared-layer',
      })),
    },
    {
      id: 'shared-state',
      title: 'Shared State & Framework Data',
      description: 'Canonical JSON files that power the PM-flow framework, control room, and maintenance monitoring.',
      truthMode: 'shared-layer',
      docs: sharedDocs,
    },
    {
      id: 'external',
      title: 'Synced External Sources',
      description: 'Linked Notion, Linear, and Vercel references that the control room is already syncing against.',
      truthMode: 'live',
      docs: externalDocs,
    },
  ];

  return {
    summary: {
      repoDocs: [...groupedRepoDocs.values()].flat().length,
      sharedDocs: sharedDocs.length,
      externalDocs: externalDocs.length,
      groups: groups.length,
      caseStudies: caseStudyFeed.length,
    },
    featuredDocs,
    groups,
  };
}

function buildExternalSyncStatus(baseStatus, githubIssues) {
  const status = structuredClone(baseStatus);

  if (githubIssues.length > 0) {
    const openIssues = githubIssues.filter(issue => issue.state === 'open');
    const closedIssues = githubIssues.filter(issue => issue.state === 'closed');
    const issuesWithPhase = githubIssues.filter(issue => issue.phase).length;
    const githubSource = status.sources.github;

    githubSource.repo_summary.live_issue_api_connected = true;
    githubSource.repo_summary.live_issue_count = githubIssues.length;
    githubSource.issue_summary = {
      total: githubIssues.length,
      open: openIssues.length,
      closed: closedIssues.length,
      with_phase_labels: issuesWithPhase,
    };
    githubSource.alerts = githubSource.repo_summary.working_tree_changes > 0 ? 1 : 0;
    githubSource.healthy = githubSource.repo_summary.working_tree_changes === 0;
    githubSource.findings = [
      'The canonical repo is on main and aligned with origin/main, which keeps repo truth stable.',
      githubSource.repo_summary.working_tree_changes > 0
        ? 'The working tree on main is intentionally dirty with active framework and dashboard cleanup changes, so local state still needs a deliberate commit or branch cut.'
        : 'The working tree is currently clean, so repo truth and deployment truth are easier to compare.',
      `GitHub issue hydration is live at build time: ${githubIssues.length} issues were fetched, ${openIssues.length} remain open, and ${issuesWithPhase} carry phase labels.`,
    ];
    status.aggregate.alerts = Object.values(status.sources).reduce((sum, source) => sum + (source.alerts || 0), 0);
    status.aggregate.source_truth_score = Math.min(100, status.aggregate.source_truth_score + 4);
  }

  return status;
}

function buildResearchWorkspaces(taskQueue, featureRegistry, externalSyncStatus) {
  const queue = taskQueue.queue || [];
  const trackedIssues = externalSyncStatus.sources.linear?.tracked_issues || [];
  const researchQueue = queue.filter(item => item.phase === 'research');
  const verificationQueue = queue.filter(item => item.phase === 'verification' || item.priority === 'critical');
  const inProgressFeatures = (featureRegistry.features || []).filter(feature => feature.status === 'in_progress');

  return {
    claudeResearch: {
      id: 'claude-research',
      title: 'Claude Research Console',
      badge: 'Workflow Surface',
      summary: 'Drive PM-flow research, backlog synthesis, UX framing, and spec preparation from one research-first workspace.',
      promptStarters: [
        'Summarize the current research chapter and identify the missing decisions before PRD approval.',
        'Compare repo truth, Notion context, and Linear scope for the active feature.',
        'Extract the key risks, success metrics, and open questions from the latest PRD and roadmap docs.',
      ],
      workItems: researchQueue.map(item => ({
        title: item.title,
        detail: `${toTitleCase(item.priority)} priority · ${toTitleCase(item.work_type)} · ${item.note}`,
      })),
      linkedItems: trackedIssues
        .filter(issue => ['FIT-23', 'FIT-24', 'FIT-25', 'FIT-17'].includes(issue.id))
        .map(issue => ({
          title: `${issue.id} — ${issue.title}`,
          detail: `${issue.status} · ${issue.priority} priority`,
        })),
      requiredDocs: [
        buildMarkdownDoc('docs/skills/pm-workflow.md', 'PM Hub', 'repo fallback'),
        buildMarkdownDoc('docs/product/backlog.md', 'Backlog', 'repo fallback'),
        buildMarkdownDoc('docs/master-plan/master-backlog-roadmap.md', 'Master Plan', 'repo fallback'),
      ],
      truthMode: 'shared-layer',
    },
    codexResearch: {
      id: 'codex-research',
      title: 'Codex Research Console',
      badge: 'Implementation Surface',
      summary: 'Focus implementation-oriented follow-ups, verification targets, and architecture cleanup without losing the PM-flow context.',
      promptStarters: [
        'Review the highest-risk implementation gap and produce the shortest safe verification path.',
        'Compare current shared-layer priorities with repo code reality and propose the next execution checkpoint.',
        'Map runtime or dependency risk to the exact code paths and verification artifacts that would close it.',
      ],
      workItems: verificationQueue.map(item => ({
        title: item.title,
        detail: `${toTitleCase(item.priority)} priority · ${toTitleCase(item.phase)} phase · ${item.note}`,
      })),
      linkedItems: [
        ...trackedIssues
          .filter(issue => ['FIT-6', 'FIT-21', 'FIT-22'].includes(issue.id))
          .map(issue => ({
            title: `${issue.id} — ${issue.title}`,
            detail: `${issue.status} · ${issue.priority} priority`,
          })),
        ...externalSyncStatus.sources.vercel.findings.slice(0, 2).map(item => ({
          title: item,
          detail: 'Vercel / observability finding',
        })),
      ],
      requiredDocs: [
        buildMarkdownDoc('docs/setup/auth-runtime-verification-playbook.md', 'Setup', 'repo fallback'),
        buildMarkdownDoc('docs/product/prd/18.6-authentication.md', 'PRD', 'repo fallback'),
        buildMarkdownDoc('README.md', 'Core', 'repo fallback'),
      ],
      truthMode: 'shared-layer',
    },
    figmaHandoff: {
      id: 'figma-handoff',
      title: 'Figma Handoff Lab',
      badge: 'Design Workflow',
      summary: 'Stage design review, screen handoff, and Figma follow-up work with truthful linked references instead of a fake embedded editor.',
      promptStarters: [
        'Prepare a handoff checklist for the next screen refresh, including screenshots, docs, and required design-system checks.',
        'Summarize the design debt that should move into Figma after code verification is complete.',
        'List the repo docs and nodes that should be reviewed before a Figma sync run.',
      ],
      workItems: [
        {
          title: 'Primary design file',
          detail: `FitMe Design System Library · ${README_FIGMA_URL}`,
          href: README_FIGMA_URL,
        },
        {
          title: 'Comprehensive revision plan',
          detail: 'Cross-surface code + Figma revision backlog for auth, home, nutrition, stats, and training.',
          href: `${GITHUB_BLOB_BASE}docs/design-system/comprehensive-revision-plan.md`,
        },
        {
          title: 'Design revision spec',
          detail: 'Repo-native visual revision spec tied to the live Figma file.',
          href: `${GITHUB_BLOB_BASE}docs/design-system/design-revision-spec.md`,
        },
      ],
      linkedItems: [
        {
          title: 'Connection status',
          detail: 'Figma handoff is represented as a workflow surface. Live embedded editing is intentionally not part of this pass.',
        },
        {
          title: 'Current readiness',
          detail: 'The design file and handoff docs are connected. Executable Figma sync remains the next evolution step.',
        },
      ],
      requiredDocs: [
        buildMarkdownDoc('docs/skills/design.md', 'Skill', 'repo fallback'),
        buildMarkdownDoc('docs/design-system/ux-foundations.md', 'UX', 'repo fallback'),
        buildMarkdownDoc('docs/master-plan/master-backlog-roadmap.md', 'Master Plan', 'repo fallback'),
      ],
      truthMode: 'repo fallback',
    },
  };
}

function buildDashboardSources(reconcileResult, externalSyncStatus, frameworkPulse, githubIssues) {
  const { sources } = reconcileResult;

  return {
    ...sources,
    github: githubIssues.length > 0
      ? {
          ...sources.github,
          mode: 'live',
        }
      : {
          count: externalSyncStatus.sources.github.repo_summary.local_branches,
          healthy: externalSyncStatus.sources.github.healthy,
          alerts: externalSyncStatus.sources.github.alerts,
          mode: 'repo fallback',
        },
    static: {
      ...sources.static,
      mode: 'repo fallback',
    },
    state: {
      ...sources.state,
      mode: 'repo fallback',
    },
    shared: {
      count: frameworkPulse.sharedFeatureCount,
      healthy: frameworkPulse.totalConflicts === 0,
      alerts: frameworkPulse.totalConflicts,
      mode: 'shared-layer',
    },
    linear: {
      count: externalSyncStatus.sources.linear.issue_summary.total,
      healthy: externalSyncStatus.sources.linear.healthy,
      alerts: externalSyncStatus.sources.linear.alerts,
      mode: 'live',
    },
    notion: {
      count: externalSyncStatus.sources.notion.page_summary.tracked_pages,
      healthy: externalSyncStatus.sources.notion.healthy,
      alerts: externalSyncStatus.sources.notion.alerts,
      mode: 'live',
    },
    analytics: {
      count: externalSyncStatus.sources.analytics.instrumentation_summary.total_metrics,
      healthy: externalSyncStatus.sources.analytics.healthy,
      alerts: externalSyncStatus.sources.analytics.alerts,
      mode: 'live',
    },
    vercel: {
      count: externalSyncStatus.sources.vercel.deployment_summary.recent_deployments_reviewed,
      healthy: externalSyncStatus.sources.vercel.healthy,
      alerts: externalSyncStatus.sources.vercel.alerts,
      mode: 'live',
    },
    archive: {
      count: 1,
      healthy: true,
      alerts: 0,
      mode: 'archive',
    },
  };
}

export function isPrimaryView(view) {
  return PRIMARY_VIEWS.some(item => item.id === view);
}

export function isSecondaryWorkspace(view) {
  return SECONDARY_WORKSPACES.some(item => item.id === view);
}

export async function buildDashboardData({ token } = {}) {
  const frameworkManifest = readSharedJson('../.claude/shared/framework-manifest.json');
  const baseExternalSyncStatus = readSharedJson('../.claude/shared/external-sync-status.json');
  const caseStudyMonitoring = readSharedJson('../.claude/shared/case-study-monitoring.json');
  const featureRegistry = readSharedJson('../.claude/shared/feature-registry.json');
  const taskQueue = readSharedJson('../.claude/shared/task-queue.json');

  const authoritativeFeatures = buildFeatureDataset(featureRegistry);
  const caseStudyFeed = buildCaseStudyFeed(caseStudyMonitoring);
  const cleanupCaseStudy = buildCleanupCaseStudy(caseStudyFeed);

  let githubIssues = [];
  try {
    if (token) githubIssues = await fetchIssues(token);
  } catch (error) {
    console.warn('GitHub API unavailable:', error.message);
  }

  const externalSyncStatus = buildExternalSyncStatus(baseExternalSyncStatus, githubIssues);
  const knowledgeHub = buildKnowledgeHub(externalSyncStatus, caseStudyFeed);
  const frameworkPulse = buildFrameworkPulse(authoritativeFeatures, featureRegistry, taskQueue);
  const researchWorkspaces = buildResearchWorkspaces(taskQueue, featureRegistry, externalSyncStatus);

  let stateFiles = [];
  try {
    stateFiles = parseStateFiles();
  } catch {
    stateFiles = [];
  }

  const reconcileResult = reconcile({
    githubIssues,
    staticFeatures: authoritativeFeatures,
    stateFiles,
  });

  return {
    features: authoritativeFeatures,
    alerts: reconcileResult.alerts,
    sources: buildDashboardSources(reconcileResult, externalSyncStatus, frameworkPulse, githubIssues),
    frameworkManifest,
    frameworkPulse,
    externalSyncStatus,
    cleanupCaseStudy,
    knowledgeHub,
    caseStudyFeed,
    researchWorkspaces,
    workspaceMeta: {
      primaryViews: PRIMARY_VIEWS,
      secondaryWorkspaces: SECONDARY_WORKSPACES,
    },
  };
}
