import { describe, it, expect } from 'vitest';
import { parseRoadmap } from '../src/scripts/parsers/roadmap.js';

describe('parseRoadmap', () => {
  it('reads the canonical master-plan roadmap path', () => {
    const tasks = parseRoadmap();

    expect(tasks.length).toBeGreaterThan(5);
    expect(tasks.some(task => task.taskNumber === 18)).toBe(true);
    expect(tasks.some(task => task.name.includes('Figma working prototype'))).toBe(true);
  });
});
