// dashboard/src/scripts/analytics.js
//
// Minimal GA4 client-side helper for the current Astro dashboard at
// fit-tracker2.vercel.app. Exists ONLY to capture the Time-to-Confidence (TTC)
// baseline before the unified-control-center migration starts.
//
// Per the unified-control-center PRD §5.1, the migration is gated on 7 days of
// real TTC data measured on the Astro dashboard. This helper fires:
//   - dashboard_load   (page paint timestamp anchor)
//   - dashboard_blocker_acknowledged   (operator clicks an alert; param: time_since_load_ms)
//
// Best-practice references applied (per vercel-plugin:react-best-practices):
//   - bundle-defer-third-party: gtag is loaded via defer in the layout head
//   - rerender-move-effect-to-event: blocker_acknowledged fires from onClick, not useEffect
//
// Once the migration ships, this helper is decommissioned along with the rest
// of dashboard/. Tracked under feature `unified-control-center` task T1.

// Anchor the page-load time as early as possible.
// We attach to window so any component can read time_since_load_ms.
if (typeof window !== 'undefined' && !window.__dashboardLoadAt) {
  window.__dashboardLoadAt = Date.now();
}

function gtag(...args) {
  if (typeof window === 'undefined') return;
  if (typeof window.gtag === 'function') {
    window.gtag(...args);
  }
  // If window.gtag is not yet loaded (gtag.js still deferred), the call is a
  // no-op for THIS event. The next call will fire once gtag.js loads.
  // We accept this trade-off: defer-loading the third-party is more important
  // than guaranteeing every event fires on cold load.
}

/**
 * Fire dashboard_load. Should be called once on Dashboard component mount.
 * Idempotent — guarded by a window flag.
 */
export function trackDashboardLoad(view) {
  if (typeof window === 'undefined') return;
  if (window.__dashboardLoadFired) return;
  window.__dashboardLoadFired = true;
  gtag('event', 'dashboard_load', {
    route: view || 'overview',
    data_freshness_minutes: null, // Astro dashboard has no freshness.json yet
    auth_method: 'public', // current Astro is public; the new Next.js dashboard will gate
  });
}

/**
 * Fire dashboard_blocker_acknowledged. Should be called from onClick of any
 * high-priority alert in AlertsBanner.
 *
 * Records time_since_load_ms which is the Time-to-Confidence (TTC) raw signal.
 */
export function trackBlockerAcknowledged({ featureId, alertSeverity }) {
  if (typeof window === 'undefined') return;
  const loadAt = window.__dashboardLoadAt || Date.now();
  const timeSinceLoadMs = Date.now() - loadAt;
  gtag('event', 'dashboard_blocker_acknowledged', {
    feature_id: featureId || 'unknown',
    alert_severity: alertSeverity || 'unknown',
    time_since_load_ms: timeSinceLoadMs,
  });
}
