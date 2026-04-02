import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const REPO_ROOT = resolve(import.meta.dirname, '../../../../');

/**
 * Parse docs/product/PRD.md — extract feature sections (2.x headers).
 */
export function parsePRD() {
  const raw = readFileSync(resolve(REPO_ROOT, 'docs/product/PRD.md'), 'utf-8');
  const features = [];
  let current = null;

  for (const line of raw.split('\n')) {
    // Match "### 2.1 Training Tracking" or "## 2.1 Training Tracking"
    const headerMatch = line.match(/^#{2,3}\s+(\d+\.\d+)\s+(.+)/);
    if (headerMatch) {
      if (current) features.push(current);
      current = {
        section: headerMatch[1],
        name: headerMatch[2].replace(/[*_]/g, ''),
        metrics: [],
        status: null,
      };
      continue;
    }

    if (!current) continue;

    // Extract status
    if (line.match(/\*\*Status\*\*:?\s*/i)) {
      current.status = line.replace(/.*\*\*Status\*\*:?\s*/i, '').trim();
    }

    // Extract metrics lines
    if (line.match(/^\s*[-•]\s*.*(metric|target|baseline|measure)/i)) {
      current.metrics.push(line.replace(/^\s*[-•]\s*/, '').trim());
    }
  }

  if (current) features.push(current);
  return features;
}
