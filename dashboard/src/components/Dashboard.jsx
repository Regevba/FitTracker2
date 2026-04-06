import { useState } from 'react';
import KanbanBoard from './KanbanBoard';
import TableView from './TableView';
import TaskBoard from './TaskBoard';
import PipelineOverview from './PipelineOverview';
import AlertsBanner from './AlertsBanner';
import SourceHealth from './SourceHealth';
import ThemeToggle from './ThemeToggle';

const VIEW_TABS = [
  { id: 'board', label: 'Board' },
  { id: 'table', label: 'Table' },
  { id: 'tasks', label: 'Tasks' },
];

export default function Dashboard({ features, alerts, sources }) {
  const [view, setView] = useState('board');

  return (
    <div className="max-w-[1440px] mx-auto px-4 sm:px-6 lg:px-8 py-6">
      {/* Header */}
      <header className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-[#FA8F40] flex items-center justify-center">
            <span className="text-white font-bold text-sm">F</span>
          </div>
          <div>
            <h1 className="text-lg font-bold text-gray-900 dark:text-white">FitMe</h1>
            <p className="text-xs text-gray-500 dark:text-gray-400">Development Dashboard</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <a
            href="https://github.com/Regevba/FitTracker2"
            target="_blank"
            rel="noopener"
            className="text-xs text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors hidden sm:block"
          >
            GitHub
          </a>
          <ThemeToggle />
        </div>
      </header>

      {/* Alerts */}
      {alerts.length > 0 && (
        <div className="mb-4">
          <AlertsBanner alerts={alerts} />
        </div>
      )}

      {/* Pipeline Overview */}
      <div className="mb-6">
        <PipelineOverview features={features} />
      </div>

      {/* View Tabs */}
      <div className="flex items-center gap-4 mb-4">
        <div className="flex bg-gray-100 dark:bg-gray-800 rounded-lg p-0.5">
          {VIEW_TABS.map(tab => (
            <button
              key={tab.id}
              onClick={() => setView(tab.id)}
              className={`px-3 py-1.5 text-xs font-semibold rounded-md transition-colors ${
                view === tab.id
                  ? 'bg-white dark:bg-[#1A1F2E] text-gray-900 dark:text-white shadow-sm'
                  : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
        <div className="text-xs text-gray-400 dark:text-gray-500">
          {features.length} features across {new Set(features.map(f => f.phase)).size} stages
        </div>
      </div>

      {/* View Content */}
      <div className="mb-8">
        {view === 'board' && <KanbanBoard features={features} />}
        {view === 'table' && <TableView features={features} />}
        {view === 'tasks' && <TaskBoard features={features} />}
      </div>

      {/* Source Health */}
      <SourceHealth
        sources={sources}
        lastSync={new Date().toLocaleString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}
      />

      {/* Footer */}
      <footer className="mt-8 pt-4 border-t border-gray-100 dark:border-gray-800 text-center">
        <p className="text-[10px] text-gray-400 dark:text-gray-600">
          Built with /pm-workflow skill · Astro + React + Tailwind
        </p>
      </footer>
    </div>
  );
}
