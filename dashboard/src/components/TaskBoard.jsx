import React, { useState, useMemo } from 'react';
import TaskCard from './TaskCard';
import DependencyGraph from './DependencyGraph';
import { parseTasks } from '../scripts/parsers/tasks.js';

const STATUS_LEGEND = [
  { label: 'Done', dot: 'bg-green-500', symbol: '\u2713' },
  { label: 'In Progress', dot: 'bg-blue-500', symbol: '\u25CF' },
  { label: 'Ready', dot: 'bg-white border-2 border-gray-400', symbol: '\u25CB' },
  { label: 'Blocked', dot: 'bg-gray-300 dark:bg-gray-600', symbol: '\u25CC' },
];

export default function TaskBoard({ features }) {
  const [selectedFeature, setSelectedFeature] = useState('__all__');
  const [showGraph, setShowGraph] = useState(null);

  // Build state-like objects from features that have task data
  const stateFiles = useMemo(() => {
    return features
      .filter(f => f.tasks && f.tasks.length > 0)
      .map(f => ({ feature: f.slug || f.name, tasks: f.tasks }));
  }, [features]);

  const { byFeature, bySkill, readyQueue, criticalPaths } = useMemo(
    () => parseTasks(stateFiles),
    [stateFiles]
  );

  // Filter tasks by selected feature
  const visibleTasks = useMemo(() => {
    if (selectedFeature === '__all__') {
      return Array.from(byFeature.values()).flat();
    }
    return byFeature.get(selectedFeature) || [];
  }, [selectedFeature, byFeature]);

  const visibleBySkill = useMemo(() => {
    const groups = new Map();
    for (const t of visibleTasks) {
      const skill = t.skill || 'unassigned';
      if (!groups.has(skill)) groups.set(skill, []);
      groups.get(skill).push(t);
    }
    return groups;
  }, [visibleTasks]);

  const featureNames = Array.from(byFeature.keys());

  if (stateFiles.length === 0) {
    return (
      <div className="text-center py-16 text-gray-400 dark:text-gray-500">
        <p className="text-sm">No tasks found in any feature state files.</p>
        <p className="text-xs mt-1">Tasks are defined in .claude/features/*/state.json</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Controls row */}
      <div className="flex items-center gap-4">
        <select
          value={selectedFeature}
          onChange={e => setSelectedFeature(e.target.value)}
          className="text-xs font-medium bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded-lg px-3 py-1.5 border-0 outline-none"
        >
          <option value="__all__">All Features</option>
          {featureNames.map(name => (
            <option key={name} value={name}>{name}</option>
          ))}
        </select>

        <div className="text-xs text-gray-400 dark:text-gray-500">
          {visibleTasks.length} tasks across {visibleBySkill.size} skills
        </div>
      </div>

      <div className="flex gap-4">
        {/* Main swim lanes */}
        <div className="flex-1 space-y-3">
          {Array.from(visibleBySkill.entries()).map(([skill, tasks]) => (
            <div key={skill} className="bg-gray-50/50 dark:bg-white/[0.02] rounded-xl p-3">
              <div className="flex items-center gap-2 mb-2">
                <h3 className="text-xs font-semibold text-gray-700 dark:text-gray-300">{skill}</h3>
                <span className="text-[10px] text-gray-400 bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded-full">
                  {tasks.length}
                </span>
              </div>
              <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-thin">
                {tasks.map(t => (
                  <div key={t.id} className="flex-shrink-0 w-52">
                    <TaskCard task={t} featureName={t.featureName} />
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Priority queue sidebar */}
        <div className="w-56 shrink-0">
          <div className="bg-gray-50/50 dark:bg-white/[0.02] rounded-xl p-3">
            <h3 className="text-xs font-semibold text-gray-700 dark:text-gray-300 mb-2">
              Priority Queue
            </h3>
            <div className="space-y-1.5">
              {readyQueue.slice(0, 10).map((t, i) => (
                <div
                  key={t.id}
                  className="flex items-center gap-2 px-2 py-1.5 bg-white dark:bg-[#1A1F2E] rounded-lg border border-gray-200 dark:border-gray-700"
                >
                  <span className="text-[10px] font-bold text-gray-400 w-4">{i + 1}</span>
                  <span className="text-[10px] font-mono text-gray-500">{t.id}</span>
                  <span className="text-xs text-gray-900 dark:text-gray-100 truncate flex-1">
                    {t.title || t.name || t.id}
                  </span>
                </div>
              ))}
              {readyQueue.length === 0 && (
                <p className="text-[10px] text-gray-400 text-center py-4">No ready tasks</p>
              )}
            </div>
          </div>

          {/* Dependency graph toggles */}
          {featureNames.length > 0 && (
            <div className="mt-3 bg-gray-50/50 dark:bg-white/[0.02] rounded-xl p-3">
              <h3 className="text-xs font-semibold text-gray-700 dark:text-gray-300 mb-2">
                Dependency Graphs
              </h3>
              <div className="space-y-1">
                {featureNames.map(name => (
                  <button
                    key={name}
                    onClick={() => setShowGraph(showGraph === name ? null : name)}
                    className={`w-full text-left text-[10px] px-2 py-1 rounded transition-colors ${
                      showGraph === name
                        ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 font-medium'
                        : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                    }`}
                  >
                    {name}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Dependency graph overlay */}
      {showGraph && byFeature.has(showGraph) && (
        <div className="bg-white dark:bg-[#1A1F2E] rounded-xl border border-gray-200 dark:border-gray-700 p-4">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-gray-900 dark:text-gray-100">
              {showGraph} — Dependencies
            </h3>
            <button
              onClick={() => setShowGraph(null)}
              className="text-xs text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              Close
            </button>
          </div>
          <DependencyGraph
            tasks={byFeature.get(showGraph)}
            featureName={showGraph}
            criticalPath={criticalPaths.get(showGraph) || []}
          />
        </div>
      )}

      {/* Status legend */}
      <div className="flex items-center gap-4 pt-2 border-t border-gray-100 dark:border-gray-800">
        {STATUS_LEGEND.map(s => (
          <div key={s.label} className="flex items-center gap-1.5">
            <div className={`w-2.5 h-2.5 rounded-full ${s.dot}`} />
            <span className="text-[10px] text-gray-400 dark:text-gray-500">{s.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
