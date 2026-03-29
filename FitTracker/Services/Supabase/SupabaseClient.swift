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

/// Shared Supabase client. Initialized lazily on first access.
/// Returns a stub client during unit-test runs (avoids fatalError — no network calls
/// are made in tests, and any Supabase tests that need a real client are @testable-skipped).
/// Fatals in production/debug if Info.plist keys are missing (developer error).
let supabase: SupabaseClient = {
    if isRunningTests {
        return SupabaseClient(
            supabaseURL: URL(string: "https://placeholder.supabase.co")!,
            supabaseKey: "placeholder-anon-key"
        )
    }
    guard
        let urlStr = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
        let url = URL(string: urlStr),
        !urlStr.contains("YOUR_PROJECT_ID"),
        let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
        !key.isEmpty,
        !key.contains("YOUR_SUPABASE")
    else {
        fatalError("SupabaseURL and SupabaseAnonKey must be set in Info.plist before using Supabase features.")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: key)
}()
