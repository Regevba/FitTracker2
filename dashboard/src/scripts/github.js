// SERVER-ONLY: This module must only run at build time (Astro frontmatter).
// Never import from client-side React components.
if (typeof window !== 'undefined') {
  throw new Error('github.js must not be imported in client-side code');
}

const OWNER = 'Regevba';
const REPO = 'FitTracker2';
const API_BASE = 'https://api.github.com';

export async function fetchIssues(token) {
  const headers = { Accept: 'application/vnd.github.v3+json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const issues = [];
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    const url = `${API_BASE}/repos/${OWNER}/${REPO}/issues?state=all&per_page=100&page=${page}`;
    const res = await fetch(url, { headers });
    if (!res.ok) throw new Error(`GitHub API ${res.status}: ${res.statusText}`);
    const batch = await res.json();
    issues.push(...batch.filter(i => !i.pull_request));
    hasMore = batch.length === 100;
    page++;
  }

  return issues.map(issue => ({
    number: issue.number,
    title: issue.title,
    state: issue.state,
    labels: issue.labels.map(l => ({ name: l.name, color: l.color })),
    milestone: issue.milestone?.title || null,
    assignee: issue.assignee?.login || null,
    assigneeAvatar: issue.assignee?.avatar_url || null,
    createdAt: issue.created_at,
    updatedAt: issue.updated_at,
    closedAt: issue.closed_at,
    url: issue.html_url,
    phase: extractLabel(issue.labels, 'phase:'),
    priority: extractLabel(issue.labels, 'priority:'),
    category: extractLabel(issue.labels, 'category:'),
  }));
}

function extractLabel(labels, prefix) {
  const match = labels.find(l => l.name.startsWith(prefix));
  return match ? match.name.replace(prefix, '') : null;
}

export async function updateIssueLabels(token, issueNumber, addLabels, removeLabels) {
  const headers = {
    Accept: 'application/vnd.github.v3+json',
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };

  for (const label of removeLabels) {
    await fetch(`${API_BASE}/repos/${OWNER}/${REPO}/issues/${issueNumber}/labels/${encodeURIComponent(label)}`, {
      method: 'DELETE',
      headers,
    });
  }

  if (addLabels.length > 0) {
    await fetch(`${API_BASE}/repos/${OWNER}/${REPO}/issues/${issueNumber}/labels`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ labels: addLabels }),
    });
  }
}
