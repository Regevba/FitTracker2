// FitTracker/Services/Supabase/SupabaseClient.swift
import Foundation
import Supabase

/// Shared Supabase client. Initialized lazily on first access.
/// Fatal in debug if Info.plist keys are missing (developer error, caught at startup).
let supabase: SupabaseClient = {
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
