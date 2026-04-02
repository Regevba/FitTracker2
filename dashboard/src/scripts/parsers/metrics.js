import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const REPO_ROOT = resolve(import.meta.dirname, '../../../../');

/**
 * Parse docs/product/metrics-framework.md — extract all metrics tables.
 */
export function parseMetrics() {
  const raw = readFileSync(resolve(REPO_ROOT, 'docs/product/metrics-framework.md'), 'utf-8');
  const metrics = [];
  let currentCategory = null;

  for (const line of raw.split('\n')) {
    const catMatch = line.match(/^## \d+\.\s+(.+)/);
    if (catMatch) {
      currentCategory = catMatch[1];
      continue;
    }

    if (line.startsWith('|') && !line.startsWith('|---') && !line.startsWith('| Metric') && currentCategory) {
      const cols = line.split('|').map(c => c.trim()).filter(Boolean);
      if (cols.length >= 4) {
        metrics.push({
          category: currentCategory,
          name: cols[0],
          definition: cols[1],
          target: cols[2],
          instrumentation: cols[3],
          prdSection: cols[4] || null,
        });
      }
    }
  }

  return metrics;
}
