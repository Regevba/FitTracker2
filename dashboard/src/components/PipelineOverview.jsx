import React from 'react';

const PHASE_COLORS = {
  backlog: '#9CA3AF',
  research: '#9CA3AF',
  prd: '#9CA3AF',
  tasks: '#9CA3AF',
  ux: '#3B82F6',
  integration: '#3B82F6',
  implement: '#3B82F6',
  testing: '#A855F7',
  review: '#A855F7',
  merge: '#A855F7',
  docs: '#10B981',
  done: '#10B981',
};

const PHASE_LABELS = {
  backlog: 'Backlog',
  research: 'Research',
  prd: 'PRD',
  ux: 'UX',
  implement: 'Impl',
  testing: 'Test',
  review: 'Review',
  done: 'Done',
};

export default function PipelineOverview({ features }) {
  const counts = {};
  for (const f of features) {
    const p = f.phase || 'backlog';
    counts[p] = (counts[p] || 0) + 1;
  }

  const total = features.length || 1;
  const segments = Object.entries(PHASE_LABELS).map(([key, label]) => ({
    key,
    label,
    count: counts[key] || 0,
    pct: ((counts[key] || 0) / total) * 100,
    color: PHASE_COLORS[key],
  })).filter(s => s.count > 0);

  return (
    <div className="bg-white dark:bg-[#1A1F2E] rounded-card p-4 shadow-card">
      {/* Stacked bar */}
      <div className="flex h-6 rounded-full overflow-hidden mb-3">
        {segments.map(s => (
          <div
            key={s.key}
            style={{ width: `${Math.max(s.pct, 2)}%`, backgroundColor: s.color }}
            className="transition-all duration-300"
            title={`${s.label}: ${s.count}`}
          />
        ))}
      </div>

      {/* Legend */}
      <div className="flex flex-wrap gap-x-4 gap-y-1">
        {segments.map(s => (
          <div key={s.key} className="flex items-center gap-1.5 text-xs text-gray-600 dark:text-gray-400">
            <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: s.color }} />
            <span>{s.label}: <strong className="text-gray-900 dark:text-gray-100">{s.count}</strong></span>
          </div>
        ))}
        <div className="text-xs text-gray-400 dark:text-gray-500 ml-auto">
          Total: {features.length}
        </div>
      </div>
    </div>
  );
}
