import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const REPO_ROOT = resolve(import.meta.dirname, '../../../../');

/**
 * Parse docs/master-plan/master-backlog-roadmap.md RICE matrix.
 */
export function parseRoadmap() {
  const raw = readFileSync(resolve(REPO_ROOT, 'docs/master-plan/master-backlog-roadmap.md'), 'utf-8');
  const tasks = [];
  let inMatrix = false;

  for (const line of raw.split('\n')) {
    if (line.includes('RICE PRIORITIZATION MATRIX')) { inMatrix = true; continue; }
    if (inMatrix && line.startsWith('---')) { inMatrix = false; continue; }

    if (inMatrix && line.startsWith('|') && !line.startsWith('|---') && !line.startsWith('| #')) {
      const cols = line.split('|').map(c => c.trim()).filter(Boolean);
      if (cols.length >= 7) {
        tasks.push({
          taskNumber: parseInt(cols[0]) || 0,
          name: cols[1].replace(/\*\*/g, ''),
          reach: parseInt(cols[2]) || 0,
          impact: parseFloat(cols[3]) || 0,
          confidence: cols[4],
          effortWeeks: parseFloat(cols[5]) || 0,
          rice: parseFloat(cols[6].replace(/\*/g, '')) || 0,
          priority: (cols[7] || '').replace(/\*\*/g, '').toLowerCase(),
        });
      }
    }
  }

  return tasks;
}
