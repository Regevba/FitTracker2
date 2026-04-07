import { useState } from 'react';

const STATUS_STYLES = {
  done: { dot: 'bg-green-500', text: 'text-green-600 dark:text-green-400', symbol: '\u2713' },
  in_progress: { dot: 'bg-blue-500', text: 'text-blue-600 dark:text-blue-400', symbol: '\u25CF' },
  ready: { dot: 'bg-white border-2 border-gray-400', text: 'text-gray-600 dark:text-gray-300', symbol: '\u25CB' },
  blocked: { dot: 'bg-gray-300 dark:bg-gray-600', text: 'text-gray-400 dark:text-gray-500', symbol: '\u25CC' },
};

const SKILL_STYLES = {
  '/dev': 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
  '/design': 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300',
  '/analytics': 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300',
  '/qa': 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300',
  '/marketing': 'bg-pink-100 text-pink-700 dark:bg-pink-900/30 dark:text-pink-300',
  '/ops': 'bg-cyan-100 text-cyan-700 dark:bg-cyan-900/30 dark:text-cyan-300',
  unassigned: 'bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300',
};

export default function TaskCard({ task, featureName, isDragging = false }) {
  const [showTooltip, setShowTooltip] = useState(false);

  const status = task.effectiveStatus || task.status || 'blocked';
  const sStyle = STATUS_STYLES[status] || STATUS_STYLES.blocked;
  const skillClass = SKILL_STYLES[task.skill] || SKILL_STYLES.unassigned;

  return (
    <div
      className={`
        relative bg-white dark:bg-[#1A1F2E] rounded-card border border-gray-200 dark:border-gray-700
        p-2.5 cursor-pointer select-none transition-all duration-150
        ${isDragging
          ? 'shadow-card-drag scale-[1.02] opacity-90 rotate-1'
          : 'shadow-card hover:shadow-card-hover'
        }
      `}
      onMouseEnter={() => setShowTooltip(true)}
      onMouseLeave={() => setShowTooltip(false)}
    >
      <div className="flex items-center gap-2">
        {/* Status dot */}
        <div className={`w-2.5 h-2.5 rounded-full shrink-0 ${sStyle.dot}`} />

        {/* Task ID badge */}
        <span className="text-[10px] font-mono font-bold text-gray-400 dark:text-gray-500 shrink-0">
          {task.id}
        </span>

        {/* Title */}
        <span className="text-xs font-semibold text-gray-900 dark:text-gray-100 leading-tight truncate">
          {task.title || task.name || task.id}
        </span>
      </div>

      {/* Skill + Effort row */}
      <div className="flex items-center gap-2 mt-1.5">
        {task.skill && (
          <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded-badge ${skillClass}`}>
            {task.skill}
          </span>
        )}
        {task.effort && (
          <span className="text-[10px] font-mono text-gray-400 dark:text-gray-500">
            {task.effort}
          </span>
        )}
      </div>

      {/* Hover tooltip */}
      {showTooltip && (
        <div className="absolute z-50 bottom-full left-0 mb-2 w-64 p-3 bg-gray-900 dark:bg-gray-100 text-white dark:text-gray-900 rounded-lg shadow-lg text-xs">
          <p className="font-semibold mb-1">{task.title || task.name || task.id}</p>
          {featureName && (
            <p className="text-gray-300 dark:text-gray-600 mb-1">Feature: {featureName}</p>
          )}
          {task.depends_on && task.depends_on.length > 0 && (
            <p className="text-gray-300 dark:text-gray-600">
              Deps: {task.depends_on.join(' → ')}
            </p>
          )}
          <p className={`mt-1 font-medium ${sStyle.text}`}>
            {status.replace('_', ' ')}
          </p>
        </div>
      )}
    </div>
  );
}
