import React, { useState } from 'react';

const SEVERITY_STYLES = {
  red: { bg: 'bg-red-50 dark:bg-red-900/20', text: 'text-red-700 dark:text-red-300', icon: '✗' },
  amber: { bg: 'bg-amber-50 dark:bg-amber-900/20', text: 'text-amber-700 dark:text-amber-300', icon: '⚠' },
  blue: { bg: 'bg-blue-50 dark:bg-blue-900/20', text: 'text-blue-700 dark:text-blue-300', icon: '⊘' },
  purple: { bg: 'bg-purple-50 dark:bg-purple-900/20', text: 'text-purple-700 dark:text-purple-300', icon: '◉' },
  info: { bg: 'bg-gray-50 dark:bg-gray-800', text: 'text-gray-600 dark:text-gray-400', icon: 'ℹ' },
};

export default function AlertsBanner({ alerts = [] }) {
  const [expanded, setExpanded] = useState(false);

  if (alerts.length === 0) return null;

  const criticalCount = alerts.filter(a => a.severity === 'red').length;
  const warningCount = alerts.filter(a => a.severity === 'amber').length;

  return (
    <div className="bg-white dark:bg-[#1A1F2E] rounded-card shadow-card overflow-hidden">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-50 dark:hover:bg-white/[0.02] transition-colors"
      >
        <div className="flex items-center gap-2 text-sm">
          <span className="text-amber-500">⚠</span>
          <span className="text-gray-700 dark:text-gray-300 font-medium">
            {alerts.length} alert{alerts.length !== 1 ? 's' : ''}
          </span>
          {criticalCount > 0 && (
            <span className="text-xs bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300 px-1.5 py-0.5 rounded-badge">
              {criticalCount} conflicts
            </span>
          )}
          {warningCount > 0 && (
            <span className="text-xs bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 px-1.5 py-0.5 rounded-badge">
              {warningCount} missing
            </span>
          )}
        </div>
        <svg
          className={`w-4 h-4 text-gray-400 transition-transform ${expanded ? 'rotate-180' : ''}`}
          fill="none" stroke="currentColor" viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {expanded && (
        <div className="border-t border-gray-100 dark:border-gray-800 px-4 py-2 space-y-1.5 max-h-48 overflow-y-auto">
          {alerts.map((alert, i) => {
            const style = SEVERITY_STYLES[alert.severity] || SEVERITY_STYLES.info;
            return (
              <div key={i} className={`flex items-start gap-2 text-xs px-2 py-1.5 rounded-lg ${style.bg}`}>
                <span className="mt-0.5">{style.icon}</span>
                <span className={style.text}>{alert.message}</span>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
