import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';

const REPO_ROOT = resolve(import.meta.dirname, '../../../../');
const FEATURES_DIR = resolve(REPO_ROOT, '.claude/features');

// Read all .claude/features state.json files.
export function parseStateFiles() {
  if (!existsSync(FEATURES_DIR)) return [];

  const features = [];
  for (const dir of readdirSync(FEATURES_DIR, { withFileTypes: true })) {
    if (!dir.isDirectory()) continue;
    const statePath = join(FEATURES_DIR, dir.name, 'state.json');
    if (!existsSync(statePath)) continue;

    try {
      const data = JSON.parse(readFileSync(statePath, 'utf-8'));
      // Backstop: ensure `feature` is always populated. v7.7+ state.json
      // schema introduced `feature_name` as the primary key; older state
      // files use `feature`. Reconcile.js + downstream consumers all read
      // `feature`, so fall back through feature_name → directory name to
      // prevent normalize(undefined).toLowerCase() crashes (the dashboard
      // 500 we hit on 2026-04-28 after v7.7 shipped).
      if (!data.feature) {
        data.feature = data.feature_name || dir.name;
      }
      features.push(data);
    } catch {
      // Skip malformed state files
    }
  }

  return features;
}
