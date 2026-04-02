import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const REPO_ROOT = resolve(import.meta.dirname, '../../../../');

/**
 * Parse docs/product/backlog.md into structured feature arrays.
 */
export function parseBacklog() {
  const raw = readFileSync(resolve(REPO_ROOT, 'docs/product/backlog.md'), 'utf-8');
  const sections = { done: [], inProgress: [], planned: [], backlog: [] };
  let currentSection = null;

  for (const line of raw.split('\n')) {
    if (line.startsWith('## Done')) { currentSection = 'done'; continue; }
    if (line.startsWith('## In Progress')) { currentSection = 'inProgress'; continue; }
    if (line.startsWith('## Planned')) { currentSection = 'planned'; continue; }
    if (line.startsWith('## Backlog')) { currentSection = 'backlog'; continue; }

    if (currentSection === 'done' && line.startsWith('|') && !line.startsWith('|---') && !line.startsWith('| #')) {
      const cols = line.split('|').map(c => c.trim()).filter(Boolean);
      if (cols.length >= 4) {
        sections.done.push({ name: cols[1], ref: cols[2], date: cols[3], notes: cols[4] || '' });
      }
    }

    if (currentSection === 'inProgress' && line.startsWith('|') && !line.startsWith('|---') && !line.startsWith('| #')) {
      const cols = line.split('|').map(c => c.trim()).filter(Boolean);
      if (cols.length >= 4) {
        sections.inProgress.push({ name: cols[1], owner: cols[2], branch: cols[3], status: cols[4] || '' });
      }
    }

    if (currentSection === 'planned' && line.startsWith('|') && !line.startsWith('|---') && !line.startsWith('| RICE')) {
      const cols = line.split('|').map(c => c.trim()).filter(Boolean);
      if (cols.length >= 4) {
        const rice = parseFloat(cols[0]) || 0;
        sections.planned.push({ rice, task: cols[1], phase: cols[2], description: cols[3] });
      }
    }

    if (currentSection === 'backlog') {
      const match = line.match(/^- \[[ x]\] (.+?)(?:\s*—\s*(.+))?$/);
      if (match) {
        const done = line.includes('[x]');
        sections.backlog.push({ name: match[1], detail: match[2] || '', done });
      }
    }
  }

  return sections;
}
