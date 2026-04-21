import React from 'react';

const SOURCE_META = {
  github: { label: 'GitHub Issues', icon: '●' },
  static: { label: 'Repo Data', icon: '●' },
  state: { label: 'PM State', icon: '●' },
  shared: { label: 'Shared Layer', icon: '●' },
  linear: { label: 'Linear', icon: '●' },
  notion: { label: 'Notion', icon: '○' },
  vercel: { label: 'Vercel', icon: '◍' },
  analytics: { label: 'Analytics', icon: '●' },
  docs: { label: 'Docs Debt', icon: '◌' },
};

export default function SourceHealth({ sources = {}, lastSync = null }) {
  const totalAlerts = Object.values(sources).reduce((sum, s) => sum + (s.alerts || 0), 0);

  return (
    <div className="bg-white dark:bg-[#1A1F2E] rounded-card p-4 shadow-card">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
          Source Health
        </h3>
        {lastSync && (
          <span className="text-[10px] text-gray-400 dark:text-gray-500">
            Last sync: {lastSync}
          </span>
        )}
      </div>

      <div className="flex flex-wrap gap-x-6 gap-y-2">
        {Object.entries(sources).map(([key, src]) => {
          const meta = SOURCE_META[key] || { label: key, icon: '●' };
          const color = src.healthy
            ? 'text-emerald-500'
            : src.alerts > 0
            ? 'text-amber-500'
            : 'text-gray-300 dark:text-gray-600';

          return (
            <div key={key} className="flex items-center gap-1.5 text-xs">
              <span className={color}>{meta.icon}</span>
              <span className="text-gray-600 dark:text-gray-400">{meta.label}</span>
              <span className="font-mono text-gray-900 dark:text-gray-100 font-medium">{src.count}</span>
              {src.mode && (
                <span className="rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] font-semibold text-gray-500 dark:bg-white/8 dark:text-white/52">
                  {src.mode}
                </span>
              )}
              {src.alerts > 0 && (
                <span className="text-amber-500 text-[10px]">({src.alerts})</span>
              )}
            </div>
          );
        })}
      </div>

      {totalAlerts > 0 && (
        <div className="mt-2 text-[10px] text-amber-600 dark:text-amber-400">
          {totalAlerts} discrepanc{totalAlerts === 1 ? 'y' : 'ies'} detected
        </div>
      )}
    </div>
  );
}
