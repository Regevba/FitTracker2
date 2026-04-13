import React from 'react';

export function Panel({ eyebrow, title, description, children, dark = false }) {
  const panelClasses = dark
    ? 'rounded-[28px] border border-white/8 bg-[linear-gradient(180deg,rgba(20,24,34,0.95)_0%,rgba(10,13,19,0.98)_100%)] p-5 shadow-none'
    : 'rounded-[28px] border border-slate-200 bg-[linear-gradient(180deg,rgba(255,255,255,0.95)_0%,rgba(248,250,252,0.98)_100%)] p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] dark:border-white/8 dark:bg-[linear-gradient(180deg,rgba(20,24,34,0.95)_0%,rgba(10,13,19,0.98)_100%)] dark:shadow-none';

  return (
    <section className={panelClasses}>
      <div className="mb-4">
        <div className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400 dark:text-white/36">{eyebrow}</div>
        <h3 className="mt-2 text-xl font-semibold tracking-tight text-slate-950 dark:text-white">{title}</h3>
        {description && <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600 dark:text-white/58">{description}</p>}
      </div>
      {children}
    </section>
  );
}

export function MetricList({ title, items, dark = false }) {
  return (
    <div className={`rounded-[24px] p-4 ${dark ? 'border border-slate-200 bg-white dark:border-white/8 dark:bg-black/15' : 'border border-white/8 bg-white/[0.04]'}`}>
      <div className={`mb-3 text-sm font-semibold ${dark ? 'text-slate-950 dark:text-white' : 'text-white'}`}>{title}</div>
      <div className="space-y-3">
        {items.map(item => (
          <div key={item.label} className="flex items-center justify-between gap-3 text-sm">
            <span className={dark ? 'text-slate-600 dark:text-white/64' : 'text-white/64'}>{item.label}</span>
            <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${dark ? 'bg-slate-100 text-slate-900 dark:bg-white/8 dark:text-white' : 'bg-white/8 text-white'}`}>
              {item.value}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function InfoTile({ title, body, meta = null }) {
  return (
    <div className="rounded-[24px] border border-slate-200 bg-slate-50/70 px-4 py-4 dark:border-white/8 dark:bg-white/[0.03]">
      {meta && <div className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400 dark:text-white/38">{meta}</div>}
      <div className="text-sm font-semibold text-slate-950 dark:text-white">{title}</div>
      <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-white/62">{body}</p>
    </div>
  );
}

export function DriftList({ title, description, items, emptyMessage, tone }) {
  const toneClasses =
    tone === 'warning'
      ? 'border-amber-200 bg-amber-50/80 dark:border-amber-300/20 dark:bg-amber-400/10'
      : 'border-sky-200 bg-sky-50/80 dark:border-sky-300/20 dark:bg-sky-400/10';

  return (
    <div className={`rounded-[24px] border px-4 py-4 ${toneClasses}`}>
      <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400 dark:text-white/38">{title}</div>
      <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/62">{description}</p>
      <div className="mt-4 space-y-3">
        {items.length === 0 ? (
          <div className="rounded-2xl border border-emerald-200 bg-white/80 px-3 py-3 text-sm leading-6 text-emerald-700 dark:border-emerald-300/20 dark:bg-black/15 dark:text-emerald-100">
            {emptyMessage}
          </div>
        ) : (
          items.map(item => (
            <div key={item.key} className="rounded-2xl border border-slate-200 bg-white/90 px-3 py-3 dark:border-white/8 dark:bg-black/15">
              <div className="text-sm font-semibold text-slate-950 dark:text-white">{item.title}</div>
              <div className="mt-1 text-xs leading-5 text-slate-500 dark:text-white/52">{item.detail}</div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export function ModeBadge({ mode }) {
  const classes = {
    live: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-400/15 dark:text-emerald-100',
    'shared-layer': 'bg-sky-100 text-sky-700 dark:bg-sky-400/15 dark:text-sky-100',
    'repo fallback': 'bg-amber-100 text-amber-700 dark:bg-amber-300/15 dark:text-amber-100',
    archive: 'bg-slate-100 text-slate-600 dark:bg-white/8 dark:text-white/62',
  };

  return (
    <span className={`rounded-full px-2.5 py-1 text-[11px] font-semibold ${classes[mode] || classes.archive}`}>
      {mode}
    </span>
  );
}

export function DocumentGroupCard({ group }) {
  return (
    <details className="rounded-[24px] border border-slate-200 bg-white px-4 py-4 shadow-sm shadow-slate-900/5 dark:border-white/8 dark:bg-white/[0.03] dark:shadow-none">
      <summary className="flex cursor-pointer list-none items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <div className="text-sm font-semibold text-slate-950 dark:text-white">{group.title}</div>
            <ModeBadge mode={group.truthMode} />
          </div>
          <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/62">{group.description}</p>
        </div>
        <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold text-slate-700 dark:bg-white/10 dark:text-white/72">
          {group.docs.length} docs
        </span>
      </summary>

      <div className="mt-4 grid gap-3 lg:grid-cols-2">
        {group.docs.map(doc => (
          <DocumentCard key={doc.id} doc={doc} compact />
        ))}
      </div>
    </details>
  );
}

export function DocumentCard({ doc, compact = false }) {
  return (
    <a
      href={doc.href}
      target="_blank"
      rel="noopener noreferrer"
      className={`block rounded-2xl border border-slate-200 bg-slate-50 px-4 py-4 transition-colors hover:border-slate-300 hover:bg-white dark:border-white/8 dark:bg-black/15 dark:hover:border-white/15 dark:hover:bg-white/[0.04] ${compact ? '' : 'shadow-sm shadow-slate-900/5 dark:shadow-none'}`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="text-sm font-semibold text-slate-950 dark:text-white">{doc.title}</div>
        <div className="flex flex-wrap justify-end gap-2">
          <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-slate-500 dark:bg-white/8 dark:text-white/62">
            {doc.sourceLabel}
          </span>
          <ModeBadge mode={doc.truthMode} />
        </div>
      </div>
      <p className="mt-3 text-sm leading-6 text-slate-600 dark:text-white/62">{doc.preview}</p>
      <div className="mt-3 text-xs leading-5 text-slate-400 dark:text-white/38">{doc.path}</div>
    </a>
  );
}

export function EmptyState({ title, body }) {
  return (
    <div className="rounded-[24px] border border-dashed border-slate-300 bg-slate-50/80 px-4 py-8 text-center dark:border-white/10 dark:bg-white/[0.03]">
      <div className="text-sm font-semibold text-slate-950 dark:text-white">{title}</div>
      <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-white/58">{body}</p>
    </div>
  );
}
