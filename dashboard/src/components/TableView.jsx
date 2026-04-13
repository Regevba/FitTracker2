import React, { useState, useMemo } from 'react';
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
} from '@tanstack/react-table';

const PHASE_ORDER = ['backlog', 'research', 'prd', 'tasks', 'ux', 'integration', 'implement', 'testing', 'review', 'merge', 'docs', 'done'];
const PRIORITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3 };

const PHASE_BADGE = {
  backlog: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
  research: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
  prd: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
  tasks: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
  ux: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
  integration: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
  implement: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
  testing: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300',
  review: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300',
  merge: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300',
  docs: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300',
  done: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300',
};

const PRIORITY_BADGE = {
  critical: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300',
  high: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300',
  medium: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-300',
  low: 'bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400',
};

const columns = [
  {
    accessorKey: 'name',
    header: 'Feature',
    cell: ({ getValue }) => (
      <span className="font-medium text-gray-900 dark:text-gray-100">{getValue()}</span>
    ),
  },
  {
    accessorKey: 'phase',
    header: 'Phase',
    sortingFn: (a, b) => PHASE_ORDER.indexOf(a.original.phase) - PHASE_ORDER.indexOf(b.original.phase),
    cell: ({ getValue }) => {
      const phase = getValue();
      return (
        <span className={`text-[11px] font-medium px-2 py-0.5 rounded-full ${PHASE_BADGE[phase] || PHASE_BADGE.backlog}`}>
          {phase}
        </span>
      );
    },
  },
  {
    accessorKey: 'priority',
    header: 'Priority',
    sortingFn: (a, b) => (PRIORITY_ORDER[a.original.priority] ?? 99) - (PRIORITY_ORDER[b.original.priority] ?? 99),
    cell: ({ getValue }) => {
      const p = getValue();
      if (!p) return <span className="text-gray-300 dark:text-gray-600">—</span>;
      return (
        <span className={`text-[11px] font-medium px-2 py-0.5 rounded-full ${PRIORITY_BADGE[p] || ''}`}>
          {p}
        </span>
      );
    },
  },
  {
    accessorKey: 'rice',
    header: 'RICE',
    cell: ({ getValue }) => {
      const v = getValue();
      if (!v) return <span className="text-gray-300 dark:text-gray-600">—</span>;
      return <span className="font-mono text-xs">{v}</span>;
    },
  },
  {
    accessorKey: 'category',
    header: 'Category',
    cell: ({ getValue }) => {
      const c = getValue();
      if (!c) return <span className="text-gray-300 dark:text-gray-600">—</span>;
      return <span className="text-xs text-gray-500 dark:text-gray-400">{c}</span>;
    },
  },
  {
    accessorKey: 'shipped',
    header: 'Shipped',
    cell: ({ getValue }) => {
      const d = getValue();
      if (!d) return <span className="text-gray-300 dark:text-gray-600">—</span>;
      return <span className="text-xs text-gray-500 dark:text-gray-400">{d}</span>;
    },
  },
];

export default function TableView({ features }) {
  const [sorting, setSorting] = useState([]);
  const [globalFilter, setGlobalFilter] = useState('');

  const table = useReactTable({
    data: features,
    columns,
    state: { sorting, globalFilter },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  });

  return (
    <div>
      {/* Search */}
      <div className="mb-3">
        <input
          type="text"
          value={globalFilter}
          onChange={e => setGlobalFilter(e.target.value)}
          placeholder="Search features..."
          className="w-full max-w-xs px-3 py-1.5 text-sm rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-[#1A1F2E] text-gray-900 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-brand-primary/30"
        />
      </div>

      {/* Table */}
      <div className="overflow-x-auto rounded-card border border-gray-100 dark:border-gray-800">
        <table className="w-full text-sm">
          <thead>
            {table.getHeaderGroups().map(hg => (
              <tr key={hg.id} className="bg-gray-50 dark:bg-[#1A1F2E] border-b border-gray-100 dark:border-gray-800">
                {hg.headers.map(header => (
                  <th
                    key={header.id}
                    onClick={header.column.getToggleSortingHandler()}
                    className="px-3 py-2 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:text-gray-700 dark:hover:text-gray-200 select-none"
                  >
                    <div className="flex items-center gap-1">
                      {flexRender(header.column.columnDef.header, header.getContext())}
                      {{ asc: ' ↑', desc: ' ↓' }[header.column.getIsSorted()] ?? ''}
                    </div>
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map(row => (
              <tr
                key={row.id}
                className="border-b border-gray-50 dark:border-gray-800/50 hover:bg-gray-50/50 dark:hover:bg-white/[0.02] transition-colors"
              >
                {row.getVisibleCells().map(cell => (
                  <td key={cell.id} className="px-3 py-2.5">
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        {table.getRowModel().rows.length === 0 && (
          <div className="text-center py-8 text-sm text-gray-400">No features match your search.</div>
        )}
      </div>

      <div className="mt-2 text-xs text-gray-400 dark:text-gray-500">
        {table.getRowModel().rows.length} of {features.length} features
      </div>
    </div>
  );
}
