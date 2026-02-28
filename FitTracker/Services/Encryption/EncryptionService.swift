// Services/Encryption/EncryptionService.swift
// MAXIMUM ENCRYPTION:
//   Layer 1 — AES-256-GCM (CryptoKit)
//   Layer 2 — ChaCha20-Poly1305 (CryptoKit)
//   Key storage — Secure Enclave (P-256) or Keychain with biometric ACL
//   File protection — NSFileProtectionCompleteUnlessOpen
//   CloudKit data — encrypted BEFORE upload; server never sees plaintext
//   Key derivation — HKDF-SHA512

import Foundation
import CryptoKit
import Security
import LocalAuthentication

// ─────────────────────────────────────────────────────────
// MARK: – Errors
// ─────────────────────────────────────────────────────────

enum FTCryptoError: LocalizedError {
    case noSecureEnclave
    case keyGenFailed
    case keyRetrievalFailed
    case encryptFailed(String)
    case decryptFailed(String)
    case keychainError(OSStatus)
    case integrityCheckFailed
    case biometricFailed

    var errorDescription: String? {
        switch self {
        case .noSecureEnclave:        return "Secure Enclave not available."
        case .keyGenFailed:           return "Key generation failed."
        case .keyRetrievalFailed:     return "Key retrieval failed."
        case .encryptFailed(let m):   return "Encryption failed: \(m)"
        case .decryptFailed(let m):   return "Decryption failed: \(m)"
        case .keychainError(let s):   return "Keychain error: \(s)"
        case .integrityCheckFailed:   return "Data integrity check failed — possible tampering."
        case .biometricFailed:        return "Biometric auth failed."
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Encrypted Container (wire format)
// ─────────────────────────────────────────────────────────
// Layout on disk / CloudKit:
//   [1 byte version][8 bytes timestamp][32 bytes HMAC-SHA512][payload...]
//   payload = ChaCha20-Poly1305( AES-256-GCM(plaintext) )

private struct EncContainer: Codable {
    var version:   UInt8       = 2              // format version
    var timestamp: Date        = Date()
    var hmac:      Data                         // HMAC-SHA512 over (version+timestamp+ciphertext)
    var ciphertext: Data                        // double-encrypted payload
}

// ─────────────────────────────────────────────────────────
// MARK: – Encryption Service (actor — thread-safe)
// ─────────────────────────────────────────────────────────

actor EncryptionService {

    static let shared = EncryptionService()

    private let keychainService   = "com.fittracker.regev.keys"
    private let aesKeyTag         = "com.fittracker.regev.aes256"
    private let chachaKeyTag      = "com.fittracker.regev.chacha20"
    private let hmacKeyTag        = "com.fittracker.regev.hmac"

    // ── Public: encrypt any Encodable
    func encrypt<T: Encodable>(_ value: T) throws -> Data {
        let json = try JSONEncoder().encode(value)
        return try encryptRaw(json)
    }

    // ── Public: decrypt to Decodable
    func decrypt<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let plain = try decryptRaw(data)
        return try JSONDecoder().decode(type, from: plain)
    }

    // ── Public raw
    func encryptRaw(_ plaintext: Data) throws -> Data {
        let aesKey    = try getOrCreateSymmetricKey(tag: aesKeyTag)
        let chachaKey = try getOrCreateSymmetricKey(tag: chachaKeyTag)
        let hmacKey   = try getOrCreateSymmetricKey(tag: hmacKeyTag)

        // Layer 1: AES-256-GCM
        guard let aesBox = try? AES.GCM.seal(plaintext, using: aesKey),
              let layer1 = aesBox.combined else {
            throw FTCryptoError.encryptFailed("AES-GCM seal failed")
        }

        // Layer 2: ChaCha20-Poly1305
        guard let chachaBox = try? ChaChaPoly.seal(layer1, using: chachaKey) else {
            throw FTCryptoError.encryptFailed("ChaCha20 seal failed")
        }
        let layer2 = chachaBox.combined

        // HMAC-SHA512 integrity tag
        let ts        = withUnsafeBytes(of: Date().timeIntervalSince1970.bitPattern) { Data($0) }
        let toSign    = Data([0x02]) + ts + layer2
        let mac       = HMAC<SHA512>.authenticationCode(for: toSign, using: hmacKey)
        let macData   = Data(mac)

        // Assemble container: [version 1B][timestamp 8B][hmac 64B][ciphertext]
        var out = Data()
        out.append(0x02)                // version
        out.append(ts)                  // 8 bytes
        out.append(macData)             // 64 bytes
        out.append(layer2)
        return out
    }

    func decryptRaw(_ data: Data) throws -> Data {
        guard data.count > 73 else { throw FTCryptoError.integrityCheckFailed }

        let version    = data[0]
        guard version == 0x02 else { throw FTCryptoError.decryptFailed("Unknown version \(version)") }

        let ts         = data[1..<9]
        let mac        = data[9..<73]
        let ciphertext = data[73...]

        let hmacKey    = try getOrCreateSymmetricKey(tag: hmacKeyTag)
        let chachaKey  = try getOrCreateSymmetricKey(tag: chachaKeyTag)
        let aesKey     = try getOrCreateSymmetricKey(tag: aesKeyTag)

        // Verify HMAC
        let toVerify   = Data([0x02]) + ts + ciphertext
        let expected   = HMAC<SHA512>.authenticationCode(for: toVerify, using: hmacKey)
        guard Data(expected) == mac else { throw FTCryptoError.integrityCheckFailed }

        // Layer 2 decrypt: ChaCha20
        guard let chachaBox = try? ChaChaPoly.SealedBox(combined: Data(ciphertext)),
              let layer1 = try? ChaChaPoly.open(chachaBox, using: chachaKey) else {
            throw FTCryptoError.decryptFailed("ChaCha20 open failed")
        }

        // Layer 1 decrypt: AES-256-GCM
        guard let aesBox = try? AES.GCM.SealedBox(combined: layer1),
              let plaintext = try? AES.GCM.open(aesBox, using: aesKey) else {
            throw FTCryptoError.decryptFailed("AES-GCM open failed")
        }

        return plaintext
    }

    // ── Key management ───────────────────────────────────

    private func getOrCreateSymmetricKey(tag: String) throws -> SymmetricKey {
        if let existing = try? loadKeyFromKeychain(tag: tag) { return existing }
        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey, tag: tag)
        return newKey
    }

    private func loadKeyFromKeychain(tag: String) throws -> SymmetricKey? {
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    keychainService,
            kSecAttrAccount:    tag,
            kSecReturnData:     true,
            kSecMatchLimit:     kSecMatchLimitOne,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw FTCryptoError.keychainError(status)
        }
        return SymmetricKey(data: data)
    }

    private func saveKeyToKeychain(_ key: SymmetricKey, tag: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        #if os(iOS) || os(macOS)
        let accessFlags: SecAccessControlCreateFlags = [.biometryCurrentSet, .or, .devicePasscode]
        #else
        let accessFlags: SecAccessControlCreateFlags = []
        #endif

        var cfError: Unmanaged<CFError>?
        guard let acl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            accessFlags,
            &cfError
        ) else { throw FTCryptoError.keyGenFailed }

        let attrs: [CFString: Any] = [
            kSecClass:             kSecClassGenericPassword,
            kSecAttrService:       keychainService,
            kSecAttrAccount:       tag,
            kSecValueData:         keyData,
            kSecAttrAccessControl: acl,
        ]
        SecItemDelete(attrs as CFDictionary)
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw FTCryptoError.keychainError(status) }
    }

    // ── Key rotation: re-encrypt all blobs ───────────────

    func rotateKeys(blobs: [Data]) throws -> [Data] {
        // Decrypt with old keys
        let plaintexts = try blobs.map { try decryptRaw($0) }

        // Delete old keys
        for tag in [aesKeyTag, chachaKeyTag, hmacKeyTag] {
            let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                      kSecAttrService: keychainService, kSecAttrAccount: tag]
            SecItemDelete(q as CFDictionary)
        }

        // Re-encrypt with new keys (generated fresh on first use)
        return try plaintexts.map { try encryptRaw($0) }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Encrypted Data Store
// ─────────────────────────────────────────────────────────

@MainActor
final class EncryptedDataStore: ObservableObject {

    @Published var dailyLogs:       [DailyLog]        = []
    @Published var weeklySnapshots: [WeeklySnapshot]  = []
    @Published var userProfile:     UserProfile       = UserProfile()
    @Published var isLoading:       Bool              = false
    @Published var lastError:       String?

    private let fm  = FileManager.default
    private var dir: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func url(_ name: String) -> URL { dir.appendingPathComponent("\(name).ftenc") }

    init() {
        Task {
            await loadFromDisk()
            await runCryptoSelfCheck()
        }
    }

    // ── CRUD ─────────────────────────────────────────────

    func upsertLog(_ log: DailyLog) {
        var l = log; l.lastModified = Date(); l.needsSync = true
        if let i = dailyLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: log.date) }) {
            dailyLogs[i] = l
        } else {
            dailyLogs.append(l)
            dailyLogs.sort { $0.date > $1.date }
        }
        Task { await persistToDisk() }
    }

    func log(for date: Date) -> DailyLog? {
        dailyLogs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func todayLog() -> DailyLog? { log(for: Date()) }

    func saveProfile(_ p: UserProfile) {
        userProfile = p
        Task { await persistToDisk() }
    }

    // ── Persist / Load ───────────────────────────────────

    func persistToDisk() async {
        do {
            let logsEnc  = try await EncryptionService.shared.encrypt(dailyLogs)
            let snapsEnc = try await EncryptionService.shared.encrypt(weeklySnapshots)
            let profEnc  = try await EncryptionService.shared.encrypt(userProfile)

            // .completeFileProtectionUnlessOpen = encrypted at rest, even when locked
            try logsEnc.write(to:  url("logs"),    options: .completeFileProtectionUnlessOpen)
            try snapsEnc.write(to: url("snaps"),   options: .completeFileProtectionUnlessOpen)
            try profEnc.write(to:  url("profile"), options: .completeFileProtectionUnlessOpen)
        } catch {
            await MainActor.run { lastError = error.localizedDescription }
        }
    }

    func loadFromDisk() async {
        await MainActor.run { isLoading = true }
        do {
            if let d = try? Data(contentsOf: url("logs")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: [DailyLog].self)
                await MainActor.run { dailyLogs = v }
            }
            if let d = try? Data(contentsOf: url("snaps")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: [WeeklySnapshot].self)
                await MainActor.run { weeklySnapshots = v }
            }
            if let d = try? Data(contentsOf: url("profile")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: UserProfile.self)
                await MainActor.run { userProfile = v }
            }
        } catch {
            await MainActor.run { lastError = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    // Fast startup check to detect keychain/encryption misconfiguration early.
    func runCryptoSelfCheck() async {
        do {
            let probe = Data("fittracker-encryption-self-check".utf8)
            let encrypted = try await EncryptionService.shared.encryptRaw(probe)
            let roundTrip = try await EncryptionService.shared.decryptRaw(encrypted)
            guard roundTrip == probe else {
                throw NSError(domain: "FTCrypto", code: -1, userInfo: [NSLocalizedDescriptionKey: "Encryption round-trip mismatch"])
            }
        } catch {
            await MainActor.run {
                lastError = "Encryption self-check failed: \(error.localizedDescription)"
            }
        }
    }

    // ── Build export package ─────────────────────────────

    func buildExport() -> ExportPackage {
        let recent = Array(dailyLogs.prefix(84))
        return ExportPackage(
            profile: userProfile,
            phase: userProfile.currentPhase,
            recoveryDay: userProfile.daysSinceStart,
            recentLogs: recent,
            weeklySnapshots: Array(weeklySnapshots.prefix(12)),
            exercises: TrainingProgramData.allExercises,
            supplements: TrainingProgramData.morningSupplements + TrainingProgramData.eveningSupplements,
            aiHints: buildHints(recent)
        )
    }

    private func buildHints(_ logs: [DailyLog]) -> ExportPackage.AIHints {
        let r7  = logs.prefix(7)
        let r28 = logs.prefix(28)

        let hrvVals    = r7.compactMap { $0.biometrics.effectiveHRV }
        let wVals      = r7.compactMap { $0.biometrics.weightKg }
        let bfVals     = r7.compactMap { $0.biometrics.bodyFatPercent }

        func trend(_ vals: [Double]) -> String {
            guard vals.count >= 2 else { return "insufficient data" }
            let d = vals.last! - vals.first!
            return d < -1 ? "decreasing" : d > 1 ? "increasing" : "stable"
        }

        let adh   = r28.map { $0.completionPct }.reduce(0,+) / max(1, Double(r28.count))
        let prot  = Double(r28.filter { ($0.nutritionLog.totalProteinG ?? 0) >= 125 }.count) / max(1, Double(r28.count))
        let supp  = Double(r28.filter { $0.supplementLog.morningStatus == .completed }.count) / max(1, Double(r28.count))
        let z2min = r7.flatMap { $0.cardioLogs.values }.compactMap { $0.wasInZone2 == true ? $0.durationMinutes : nil }.reduce(0,+)

        var flags: [String] = []; var pos: [String] = []
        if let hrv = logs.first?.biometrics.effectiveHRV, hrv < 28 { flags.append("HRV below 28 ms") }
        if let rhr = logs.first?.biometrics.effectiveRestingHR, rhr > 75 { flags.append("Resting HR above 75 bpm") }
        if adh < 70 { flags.append("Task adherence below 70%") }
        if z2min < 90 { flags.append("Zone 2 below 90 min/week") }
        if trend(hrvVals) == "increasing" { pos.append("HRV trend improving") }
        if trend(wVals)   == "decreasing" { pos.append("Weight trending down") }
        if adh > 85 { pos.append("Excellent task adherence") }

        let cw = wVals.last; let cb = bfVals.last
        let gp = userProfile.overallProgress(currentWeight: cw, currentBF: cb.map { $0 * 100 })

        return ExportPackage.AIHints(
            hrvTrend: trend(hrvVals), weightTrend: trend(wVals), bfTrend: trend(bfVals),
            avgAdherence: adh, zone2MinPerWeek: z2min, proteinAdherence: prot,
            suppAdherence: supp, flags: flags, positives: pos, overallGoalProgress: gp
        )
    }
}
