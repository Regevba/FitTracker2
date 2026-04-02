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
      features.push(data);
    } catch {
      // Skip malformed state files
    }
  }

  return features;
}
