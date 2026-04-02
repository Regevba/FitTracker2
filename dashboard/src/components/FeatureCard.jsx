const PRIORITY_STYLES = {
  critical: { dot: 'bg-priority-critical', text: 'text-priority-critical', label: 'P0' },
  high: { dot: 'bg-priority-high', text: 'text-priority-high', label: 'P1' },
  medium: { dot: 'bg-priority-medium', text: 'text-amber-600 dark:text-priority-medium', label: 'P2' },
  low: { dot: 'bg-priority-low', text: 'text-gray-400', label: 'P3' },
};

const STATUS_BORDER = {
  backlog: 'border-l-status-backlog',
  research: 'border-l-status-research',
  prd: 'border-l-status-prd',
  tasks: 'border-l-status-prd',
  ux: 'border-l-status-ux',
  integration: 'border-l-status-integration',
  implement: 'border-l-status-implement',
  testing: 'border-l-status-testing',
  review: 'border-l-status-review',
  merge: 'border-l-status-merge',
  docs: 'border-l-status-docs',
  done: 'border-l-status-done',
};

const CATEGORY_BADGE = {
  product: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
  gdpr: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300',
  infra: 'bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300',
  design: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300',
  ai: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300',
  measurement: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300',
  platform: 'bg-cyan-100 text-cyan-700 dark:bg-cyan-900/30 dark:text-cyan-300',
  marketing: 'bg-pink-100 text-pink-700 dark:bg-pink-900/30 dark:text-pink-300',
  process: 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300',
};

export default function FeatureCard({ feature, isDragging = false, onClick }) {
  const { name, phase, priority, rice, category, shipped, eta } = feature;
  const pStyle = priority ? PRIORITY_STYLES[priority] : null;
  const borderClass = STATUS_BORDER[phase] || 'border-l-gray-300';
  const catClass = CATEGORY_BADGE[category] || CATEGORY_BADGE.product;

  return (
    <div
      onClick={onClick}
      className={`
        bg-white dark:bg-[#1A1F2E] rounded-card border-l-4 ${borderClass}
        p-3 cursor-pointer select-none transition-all duration-150
        ${isDragging
          ? 'shadow-card-drag scale-[1.02] opacity-90 rotate-1'
          : 'shadow-card hover:shadow-card-hover'
        }
      `}
    >
      {/* Priority + Title */}
      <div className="flex items-start gap-2 mb-2">
        {pStyle && (
          <span className={`text-xs font-bold ${pStyle.text} mt-0.5 shrink-0`}>
            {pStyle.label}
          </span>
        )}
        <h3 className="text-sm font-semibold text-gray-900 dark:text-gray-100 leading-tight line-clamp-2">
          {name}
        </h3>
      </div>

      {/* Category + RICE */}
      <div className="flex items-center gap-2 mb-2">
        {category && (
          <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded-badge ${catClass}`}>
            {category}
          </span>
        )}
        {rice && (
          <span className="text-[10px] font-mono text-gray-400 dark:text-gray-500">
            RICE {rice}
          </span>
        )}
      </div>

      {/* Footer: date or ETA */}
      <div className="flex items-center justify-between text-[10px] text-gray-400 dark:text-gray-500">
        {shipped && <span>Shipped {shipped}</span>}
        {eta && <span>ETA: {eta}</span>}
        {!shipped && !eta && <span>&nbsp;</span>}
      </div>
    </div>
  );
}
