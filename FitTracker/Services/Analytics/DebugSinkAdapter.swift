// Services/Analytics/DebugSinkAdapter.swift
// Phase 2.A.3 of analytics-observability per
// docs/master-plan/analytics-master-plan-2026-05-13.md §6.1 Sub-system A.
//
// Wraps another AnalyticsProvider and TEES every event to a local
// HTTP/SSE sink (default: http://127.0.0.1:8765/event — the server
// shipped in Phase 2.A.1) IFF the `DEBUG_ANALYTICS=1` env var is set.
//
// Design properties:
//   - PRODUCTION SAFE: when env var unset, this is a transparent passthrough
//     to the inner adapter. Firebase/GA4 receives every event identically.
//   - PASSIVE TEE: production path is never blocked by sink failures.
//     POST is fire-and-forget; errors are discarded. The local debug sink
//     is dev-only — losing events there must never affect real analytics.
//   - DEPENDENCY-INJECTED: the AnalyticsDebugEventSink protocol abstracts
//     the HTTP path so unit tests can verify behavior without network I/O.
//   - PII SAFE: only logEvent + logScreenView are mirrored. setUserID and
//     setUserProperty (which can carry per-user identifiers) are passed
//     to the inner adapter only — never teed to the local sink.
//
// USAGE
// -----
// Wired via AnalyticsService.makeDefault() (see that file). To enable
// during local development:
//   1. Run the SSE server in a separate terminal:
//        python3 scripts/analytics-watch-server.py
//   2. In Xcode Edit Scheme → Run → Arguments → Environment Variables,
//      add:  DEBUG_ANALYTICS = 1
//   3. Run the app. Tail events with:
//        python3 scripts/analytics-watch.py
//
// To override the sink URL, set:
//   DEBUG_ANALYTICS_URL = http://127.0.0.1:9999/event

import Foundation

/// Receives an event for forwarding to the local debug sink.
///
/// Default impl is `URLSessionEventSink`. Tests can substitute a recording
/// double to assert on calls without performing network I/O.
protocol AnalyticsDebugEventSink {
    func send(name: String, parameters: [String: Any]?)
}

/// Real network sink: fire-and-forget HTTP POST to the SSE server's `/event`
/// endpoint. Errors are discarded (this is a dev-only mirror).
final class URLSessionEventSink: AnalyticsDebugEventSink {

    private let url: URL
    private let session: URLSession

    init(url: URL, session: URLSession? = nil) {
        self.url = url
        // Use ephemeral session — no caching, no persistence, no cookies.
        self.session = session ?? URLSession(configuration: .ephemeral)
    }

    func send(name: String, parameters: [String: Any]?) {
        var payload: [String: Any] = ["event_name": name]
        if let parameters {
            // Convert non-JSON-safe values to strings so JSONSerialization
            // doesn't throw on Date / NSNumber subclasses / etc.
            payload["params"] = parameters.mapValues(Self.jsonSafe(_:))
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        // Fire and forget. The completion handler discards everything
        // including errors — this sink must never block or surface anything
        // to the production code path.
        session.dataTask(with: request) { _, _, _ in }.resume()
    }

    /// Coerce a value into something `JSONSerialization` will accept.
    private static func jsonSafe(_ value: Any) -> Any {
        switch value {
        case let v as String: return v
        case let v as Bool: return v
        case let v as Int: return v
        case let v as Double: return v
        case let v as Float: return Double(v)
        case let v as Date: return ISO8601DateFormatter().string(from: v)
        default: return String(describing: value)
        }
    }
}

/// Wraps an existing AnalyticsProvider; conditionally tees events to a
/// local debug sink while preserving the production analytics path.
final class DebugSinkAdapter: AnalyticsProvider {

    /// Default URL for the local mirror sink (Phase 2.A.1 server default).
    static let defaultSinkURL = URL(string: "http://127.0.0.1:8765/event")!

    private let inner: AnalyticsProvider
    private let sink: AnalyticsDebugEventSink?

    init(
        wrapping inner: AnalyticsProvider,
        sink: AnalyticsDebugEventSink? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.inner = inner
        // Resolve the sink:
        //   1. Caller-provided override wins (used by tests + advanced users)
        //   2. Otherwise: enabled iff DEBUG_ANALYTICS=1; URL from
        //      DEBUG_ANALYTICS_URL or the default localhost:8765/event
        if let sink {
            self.sink = sink
        } else if environment["DEBUG_ANALYTICS"] == "1" {
            let urlString = environment["DEBUG_ANALYTICS_URL"]
            let url = urlString.flatMap(URL.init(string:)) ?? Self.defaultSinkURL
            self.sink = URLSessionEventSink(url: url)
        } else {
            self.sink = nil
        }
    }

    /// True iff events are currently being teed to a sink.
    var isTeeing: Bool { sink != nil }

    // MARK: - AnalyticsProvider conformance

    func configure() {
        inner.configure()
    }

    func logEvent(_ name: String, parameters: [String: Any]?) {
        inner.logEvent(name, parameters: parameters)
        sink?.send(name: name, parameters: parameters)
    }

    func logScreenView(_ screenName: String, screenClass: String?) {
        inner.logScreenView(screenName, screenClass: screenClass)
        sink?.send(
            name: "screen_view",
            parameters: [
                "screen_name": screenName,
                "screen_class": screenClass ?? ""
            ]
        )
    }

    func setUserProperty(_ value: String?, forName name: String) {
        // NEVER teed. User properties may carry per-user identifiers.
        inner.setUserProperty(value, forName: name)
    }

    func setUserID(_ id: String?) {
        // NEVER teed. User IDs are PII.
        inner.setUserID(id)
    }

    func setConsent(analyticsStorage: Bool, adStorage: Bool) {
        // NEVER teed. Operator-side state, not an analytics event.
        inner.setConsent(analyticsStorage: analyticsStorage, adStorage: adStorage)
    }
}
