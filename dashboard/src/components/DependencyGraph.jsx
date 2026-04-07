import { useMemo } from 'react';

const STATUS_COLORS = {
  done: { fill: '#10B981', stroke: '#059669' },
  in_progress: { fill: '#3B82F6', stroke: '#2563EB' },
  ready: { fill: '#FFFFFF', stroke: '#9CA3AF' },
  blocked: { fill: '#D1D5DB', stroke: '#9CA3AF' },
};

const NODE_RADIUS = 18;
const LAYER_GAP_X = 100;
const NODE_GAP_Y = 60;
const PADDING_X = 40;
const PADDING_Y = 40;

/**
 * Simple layered left-to-right DAG visualization.
 * Assigns tasks to layers via topological ordering, then renders SVG.
 */
export default function DependencyGraph({ tasks, featureName, criticalPath = [] }) {
  const layout = useMemo(() => {
    if (!tasks || tasks.length === 0) return null;

    const taskMap = new Map(tasks.map(t => [t.id, t]));
    const criticalSet = new Set(criticalPath);

    // Build adjacency: dependency → dependent
    const adjList = new Map();
    const inDegree = new Map();
    for (const t of tasks) {
      adjList.set(t.id, []);
      inDegree.set(t.id, 0);
    }
    for (const t of tasks) {
      if (t.depends_on) {
        for (const depId of t.depends_on) {
          if (taskMap.has(depId)) {
            adjList.get(depId).push(t.id);
            inDegree.set(t.id, inDegree.get(t.id) + 1);
          }
        }
      }
    }

    // Assign layers via topological sort (longest path from roots)
    const layer = new Map();
    const queue = [];
    for (const [id, deg] of inDegree) {
      if (deg === 0) {
        queue.push(id);
        layer.set(id, 0);
      }
    }

    while (queue.length > 0) {
      const curr = queue.shift();
      for (const child of adjList.get(curr)) {
        const newLayer = layer.get(curr) + 1;
        layer.set(child, Math.max(layer.get(child) || 0, newLayer));
        inDegree.set(child, inDegree.get(child) - 1);
        if (inDegree.get(child) === 0) queue.push(child);
      }
    }

    // Group by layer
    const layers = new Map();
    for (const [id, l] of layer) {
      if (!layers.has(l)) layers.set(l, []);
      layers.get(l).push(id);
    }

    // Compute positions
    const maxLayer = Math.max(...layers.keys(), 0);
    const positions = new Map();

    for (let l = 0; l <= maxLayer; l++) {
      const ids = layers.get(l) || [];
      ids.forEach((id, i) => {
        positions.set(id, {
          x: PADDING_X + l * LAYER_GAP_X,
          y: PADDING_Y + i * NODE_GAP_Y,
        });
      });
    }

    // Compute SVG dimensions
    const maxNodesInLayer = Math.max(...Array.from(layers.values()).map(l => l.length), 1);
    const width = PADDING_X * 2 + maxLayer * LAYER_GAP_X + NODE_RADIUS * 2;
    const height = PADDING_Y * 2 + (maxNodesInLayer - 1) * NODE_GAP_Y + NODE_RADIUS * 2;

    // Build edges
    const edges = [];
    for (const t of tasks) {
      if (t.depends_on) {
        for (const depId of t.depends_on) {
          if (positions.has(depId) && positions.has(t.id)) {
            const isCritical = criticalSet.has(depId) && criticalSet.has(t.id);
            edges.push({
              from: positions.get(depId),
              to: positions.get(t.id),
              isCritical,
            });
          }
        }
      }
    }

    // Build nodes
    const nodes = tasks.map(t => {
      const pos = positions.get(t.id);
      if (!pos) return null;
      const status = t.effectiveStatus || t.status || 'blocked';
      const colors = STATUS_COLORS[status] || STATUS_COLORS.blocked;
      const isCritical = criticalSet.has(t.id);
      return { id: t.id, ...pos, colors, status, isCritical, title: t.title || t.name || t.id };
    }).filter(Boolean);

    return { nodes, edges, width, height };
  }, [tasks, criticalPath]);

  if (!layout) {
    return (
      <div className="text-xs text-gray-400 text-center py-4">No tasks to visualize</div>
    );
  }

  return (
    <svg
      width={Math.max(layout.width, 200)}
      height={Math.max(layout.height, 80)}
      viewBox={`0 0 ${Math.max(layout.width, 200)} ${Math.max(layout.height, 80)}`}
      className="w-full"
      style={{ maxHeight: 400 }}
    >
      <defs>
        <marker
          id="arrowhead"
          markerWidth="8"
          markerHeight="6"
          refX="8"
          refY="3"
          orient="auto"
        >
          <polygon points="0 0, 8 3, 0 6" fill="#9CA3AF" />
        </marker>
        <marker
          id="arrowhead-critical"
          markerWidth="8"
          markerHeight="6"
          refX="8"
          refY="3"
          orient="auto"
        >
          <polygon points="0 0, 8 3, 0 6" fill="#EF4444" />
        </marker>
      </defs>

      {/* Edges */}
      {layout.edges.map((edge, i) => (
        <line
          key={i}
          x1={edge.from.x + NODE_RADIUS}
          y1={edge.from.y}
          x2={edge.to.x - NODE_RADIUS}
          y2={edge.to.y}
          stroke={edge.isCritical ? '#EF4444' : '#D1D5DB'}
          strokeWidth={edge.isCritical ? 2.5 : 1.5}
          markerEnd={edge.isCritical ? 'url(#arrowhead-critical)' : 'url(#arrowhead)'}
        />
      ))}

      {/* Nodes */}
      {layout.nodes.map(node => (
        <g key={node.id}>
          <circle
            cx={node.x}
            cy={node.y}
            r={NODE_RADIUS}
            fill={node.colors.fill}
            stroke={node.isCritical ? '#EF4444' : node.colors.stroke}
            strokeWidth={node.isCritical ? 2.5 : 1.5}
          />
          <text
            x={node.x}
            y={node.y}
            textAnchor="middle"
            dominantBaseline="central"
            className="text-[9px] font-mono font-bold"
            fill={node.status === 'ready' ? '#6B7280' : '#FFFFFF'}
          >
            {node.id}
          </text>
          {/* Label below node */}
          <text
            x={node.x}
            y={node.y + NODE_RADIUS + 12}
            textAnchor="middle"
            className="text-[8px]"
            fill="#9CA3AF"
          >
            {node.title.length > 14 ? node.title.slice(0, 12) + '..' : node.title}
          </text>
        </g>
      ))}
    </svg>
  );
}
