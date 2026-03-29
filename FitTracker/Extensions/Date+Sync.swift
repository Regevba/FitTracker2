// FitTracker/Extensions/Date+Sync.swift
import Foundation
import CryptoKit

extension Date {
    /// ISO 8601 date string (no time component) — "2026-03-17".
    /// Used as the `logic_date` and `week_start` keys in Supabase sync_records.
    var isoDateString: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: self)
    }

    /// Full ISO 8601 timestamp — "2026-03-17T09:30:00Z".
    /// Used as the `last_modified` value in Supabase sync_records.
    var iso8601String: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }
}

extension Digest {
    /// Lower-case hex string representation of a CryptoKit digest.
    var hexString: String {
        makeIterator().map { String(format: "%02x", $0) }.joined()
    }
}
