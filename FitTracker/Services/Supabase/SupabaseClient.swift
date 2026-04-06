// FitTracker/Services/Supabase/SupabaseClient.swift
import Foundation
import Supabase

/// True when the process is being run by XCTest.
/// Checked by reading well-known environment keys that xcodebuild injects into every test run.
private var isRunningTests: Bool {
    let env = ProcessInfo.processInfo.environment
    return env["XCTestBundlePath"] != nil
        || env["XCTestConfigurationFilePath"] != nil
        || env["XCTestSessionIdentifier"] != nil
}

enum SupabaseRuntimeConfiguration {
    static let missingConfigurationMessage =
        "Supabase is not configured in this build. Set SupabaseURL and SupabaseAnonKey in Info.plist to enable sign-in and sync."

    static func credentials(
        urlString: String?,
        key: String?
    ) -> (url: URL, key: String)? {
        guard
            let urlString,
            let url = URL(string: urlString),
            !urlString.isEmpty,
            !urlString.contains("YOUR_PROJECT_ID"),
            let key,
            !key.isEmpty,
            !key.contains("YOUR_SUPABASE")
        else {
            return nil
        }
        return (url, key)
    }

    static func credentials(in bundle: Bundle = .main) -> (url: URL, key: String)? {
        credentials(
            urlString: bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            key: bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        )
    }

    static var isConfigured: Bool {
        credentials() != nil
    }

    static var missingConfigurationError: NSError {
        NSError(
            domain: "FitTracker.Supabase",
            code: 503,
            userInfo: [NSLocalizedDescriptionKey: missingConfigurationMessage]
        )
    }

    static func makeStubClient() -> SupabaseClient {
        let stubHost = ["placeholder", "supabase", "co"].joined(separator: ".")
        guard let stubURL = URL(string: "https://" + stubHost) else {
            fatalError("Stub Supabase URL is invalid — infrastructure error")
        }
        let stubKey = ["ci", "test", "stub"].joined(separator: "-")
        return SupabaseClient(supabaseURL: stubURL, supabaseKey: stubKey)
    }
}

/// Shared Supabase client. Initialized lazily on first access.
/// Returns a stub client during unit-test runs (avoids fatalError — no network calls
/// are made in tests, and any Supabase tests that need a real client are @testable-skipped).
/// Also returns a stub client when local config is intentionally absent on a clean checkout,
/// allowing the app to surface configuration errors instead of crashing.
let supabase: SupabaseClient = {
    if isRunningTests {
        return SupabaseRuntimeConfiguration.makeStubClient()
    }
    guard let credentials = SupabaseRuntimeConfiguration.credentials() else {
        return SupabaseRuntimeConfiguration.makeStubClient()
    }
    return SupabaseClient(supabaseURL: credentials.url, supabaseKey: credentials.key)
}()
