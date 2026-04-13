import React, { useState, useMemo } from 'react';
import { DndContext, closestCenter, PointerSensor, KeyboardSensor, useSensor, useSensors, DragOverlay, useDroppable } from '@dnd-kit/core';
import { SortableContext, verticalListSortingStrategy, useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import FeatureCard from './FeatureCard';

const COLUMNS = [
  { id: 'backlog', label: 'Backlog', color: '#9CA3AF' },
  { id: 'research', label: 'Research', color: '#9CA3AF' },
  { id: 'prd', label: 'PRD', color: '#9CA3AF' },
  { id: 'ux', label: 'UX / Design', color: '#3B82F6' },
  { id: 'implement', label: 'Implement', color: '#3B82F6' },
  { id: 'testing', label: 'Testing', color: '#A855F7' },
  { id: 'review', label: 'Review', color: '#A855F7' },
  { id: 'done', label: 'Done', color: '#10B981' },
];

function SortableCard({ feature }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: feature.slug,
    data: { phase: feature.phase },
  });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
      <FeatureCard feature={feature} isDragging={isDragging} />
    </div>
  );
}

const COLUMN_IDS = new Set(COLUMNS.map(c => c.id));

function Column({ column, features, isOver }) {
  const { setNodeRef } = useDroppable({ id: column.id });

  return (
    <div className={`flex-shrink-0 w-64 ${isOver ? 'ring-2 ring-brand-primary/40 rounded-xl' : ''}`}>
      <div className="flex items-center gap-2 mb-3 px-1">
        <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: column.color }} />
        <h2 className="text-sm font-semibold text-gray-700 dark:text-gray-300">{column.label}</h2>
        <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded-full">
          {features.length}
        </span>
      </div>
      <div ref={setNodeRef} className="space-y-2 min-h-[120px] p-1 rounded-xl bg-gray-50/50 dark:bg-white/[0.02]">
        <SortableContext items={features.map(f => f.slug)} strategy={verticalListSortingStrategy}>
          {features.map(f => (
            <SortableCard key={f.slug} feature={f} />
          ))}
        </SortableContext>
        {features.length === 0 && (
          <div className="text-xs text-gray-300 dark:text-gray-600 text-center py-8">
            No items
          </div>
        )}
      </div>
    </div>
  );
}

export default function KanbanBoard({ features: initialFeatures, filters = {}, onPhaseChange }) {
  const [features, setFeatures] = useState(initialFeatures);
  const [activeId, setActiveId] = useState(null);
  const [overColumnId, setOverColumnId] = useState(null);
  const [undoAction, setUndoAction] = useState(null);
  const [hasLocalChanges, setHasLocalChanges] = useState(false);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor)
  );

  const filtered = useMemo(() => {
    return features.filter(f => {
      if (filters.phase && f.phase !== filters.phase) return false;
      if (filters.priority && f.priority !== filters.priority) return false;
      if (filters.category && f.category !== filters.category) return false;
      return true;
    });
  }, [features, filters]);

  const columns = COLUMNS.map(col => ({
    ...col,
    features: filtered.filter(f => {
      if (col.id === 'backlog') return f.phase === 'backlog';
      if (col.id === 'ux') return f.phase === 'ux' || f.phase === 'integration' || f.phase === 'tasks';
      if (col.id === 'done') return f.phase === 'done' || f.phase === 'docs' || f.phase === 'merge';
      return f.phase === col.id;
    }),
  }));

  function handleDragStart(event) {
    setActiveId(event.active.id);
  }

  function handleDragOver(event) {
    const overId = event.over?.id;
    if (!overId) return;
    if (COLUMN_IDS.has(overId)) {
      setOverColumnId(overId);
    } else {
      const overFeature = features.find(f => f.slug === overId);
      if (overFeature) setOverColumnId(overFeature.phase);
    }
  }

  function handleDragEnd(event) {
    setActiveId(null);
    setOverColumnId(null);

    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const draggedFeature = features.find(f => f.slug === active.id);
    if (!draggedFeature) return;

    // Determine target column from drop position
    let targetPhase;
    if (COLUMN_IDS.has(over.id)) {
      targetPhase = over.id;
    } else {
      const overFeature = features.find(f => f.slug === over.id);
      targetPhase = overFeature?.phase;
    }
    if (!targetPhase || draggedFeature.phase === targetPhase) return;

    const oldPhase = draggedFeature.phase;
    setFeatures(prev => prev.map(f =>
      f.slug === active.id ? { ...f, phase: targetPhase } : f
    ));

    setUndoAction({
      feature: draggedFeature.name,
      from: oldPhase,
      to: targetPhase,
      slug: active.id,
    });
    setHasLocalChanges(true);

    if (onPhaseChange) {
      onPhaseChange({
        slug: active.id,
        name: draggedFeature.name,
        from: oldPhase,
        to: targetPhase,
      });
    }

    setTimeout(() => setUndoAction(null), 5000);
  }

  function handleUndo() {
    if (!undoAction) return;
    setFeatures(prev => prev.map(f =>
      f.slug === undoAction.slug ? { ...f, phase: undoAction.from } : f
    ));
    setUndoAction(null);
  }

  const activeFeature = features.find(f => f.slug === activeId);

  return (
    <div className="relative">
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragStart={handleDragStart}
        onDragOver={handleDragOver}
        onDragEnd={handleDragEnd}
      >
        <div className="kanban-scroll flex gap-3 overflow-x-auto pb-4 scrollbar-thin">
          {columns.map(col => (
            <Column
              key={col.id}
              column={col}
              features={col.features}
              isOver={overColumnId === col.id}
            />
          ))}
        </div>

        <DragOverlay>
          {activeFeature && (
            <div className="w-64">
              <FeatureCard feature={activeFeature} isDragging />
            </div>
          )}
        </DragOverlay>
      </DndContext>

      {/* Local changes banner */}
      {hasLocalChanges && !undoAction && (
        <div className="mt-3 px-3 py-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg text-xs text-amber-700 dark:text-amber-300 flex items-center gap-2">
          <span>⚠</span>
          <span>Board changes are local only. Run <code className="font-mono bg-amber-100 dark:bg-amber-900/40 px-1 rounded">/pm-workflow</code> to sync to GitHub.</span>
        </div>
      )}

      {/* Undo toast */}
      {undoAction && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 bg-gray-900 dark:bg-gray-100 text-white dark:text-gray-900 px-4 py-3 rounded-xl shadow-lg flex items-center gap-3 text-sm z-50 animate-in slide-in-from-bottom">
          <span>Moved "{undoAction.feature}" to {undoAction.to}</span>
          <button
            onClick={handleUndo}
            className="font-semibold text-brand-primary hover:text-brand-warm transition-colors"
          >
            Undo
          </button>
        </div>
      )}
    </div>
  );
}
