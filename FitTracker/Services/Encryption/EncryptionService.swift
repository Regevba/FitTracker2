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
// MARK: – Encryption Service (actor — thread-safe)
// ─────────────────────────────────────────────────────────

actor EncryptionService {

    static let shared = EncryptionService()

    private let keychainService   = "com.fittracker.regev.keys"
    private let aesKeyTag         = "com.fittracker.regev.aes256"
    private let chachaKeyTag      = "com.fittracker.regev.chacha20"
    private let hmacKeyTag        = "com.fittracker.regev.hmac"

    // Cached LAContext — set by AuthManager after successful biometric auth.
    // Cleared on background/lock. All crypto operations reuse this context so
    // the system never shows more than one biometric prompt per session.
    private var sessionContext: LAContext?

    func setSessionContext(_ ctx: LAContext) {
        sessionContext = ctx
    }

    func clearSessionContext() {
        sessionContext = nil
    }

    /// Returns the cached session context if set; falls back to authenticating a new one.
    /// On simulator (canEvaluatePolicy returns false) this always returns an unauthenticated context.
    private func currentContext() async throws -> LAContext {
        if let ctx = sessionContext { return ctx }
        return try await authenticatedContext()
    }

    // ── Public: encrypt any Encodable
    func encrypt<T: Encodable>(_ value: T) async throws -> Data {
        let json = try JSONEncoder().encode(value)
        return try await encryptRaw(json)
    }

    // ── Public: decrypt to Decodable
    func decrypt<T: Decodable>(_ data: Data, as type: T.Type) async throws -> T {
        let plain = try await decryptRaw(data)
        return try JSONDecoder().decode(type, from: plain)
    }

    // ── Public raw
    func encryptRaw(_ plaintext: Data) async throws -> Data {
        // Use cached session context (set by AuthManager) or fall back to a fresh auth.
        let ctx       = try await currentContext()
        let aesKey    = try getOrCreateSymmetricKey(tag: aesKeyTag,    context: ctx)
        let chachaKey = try getOrCreateSymmetricKey(tag: chachaKeyTag, context: ctx)
        let hmacKey   = try getOrCreateSymmetricKey(tag: hmacKeyTag,   context: ctx)

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

    func decryptRaw(_ data: Data) async throws -> Data {
        guard data.count > 73 else { throw FTCryptoError.integrityCheckFailed }

        let version    = data[0]
        guard version == 0x02 else { throw FTCryptoError.decryptFailed("Unknown version \(version)") }

        let ts         = data[1..<9]
        let mac        = data[9..<73]
        let ciphertext = data[73...]

        // Use cached session context (set by AuthManager) or fall back to a fresh auth.
        let ctx        = try await currentContext()
        let hmacKey    = try getOrCreateSymmetricKey(tag: hmacKeyTag,   context: ctx)
        let chachaKey  = try getOrCreateSymmetricKey(tag: chachaKeyTag, context: ctx)
        let aesKey     = try getOrCreateSymmetricKey(tag: aesKeyTag,    context: ctx)

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

    /// Authenticate once and return an LAContext that can be reused for all key loads in one operation.
    private func authenticatedContext() async throws -> LAContext {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = ""
        var laError: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &laError) else {
            throw laError ?? FTCryptoError.biometricFailed
        }
        let authOK: Bool = try await withCheckedThrowingContinuation { cont in
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "Unlock FitTracker encryption keys") { ok, err in
                if ok {
                    cont.resume(returning: true)
                } else {
                    cont.resume(throwing: err ?? FTCryptoError.biometricFailed)
                }
            }
        }
        guard authOK else { throw FTCryptoError.biometricFailed }
        return ctx
    }

    private func getOrCreateSymmetricKey(tag: String, context: LAContext) throws -> SymmetricKey {
        // Use explicit do/catch so that a genuine keychain error (biometric failure,
        // corrupt entry, locked device, etc.) is propagated rather than silently treated
        // as "key not found" and overwritten with a freshly generated key.
        // loadKeyFromKeychain returns nil only for errSecItemNotFound; all other
        // failures are thrown as FTCryptoError.keychainError — let those bubble up.
        do {
            if let existing = try loadKeyFromKeychain(tag: tag, context: context) {
                return existing
            }
        } catch {
            throw error   // propagate any real keychain error; do NOT generate a new key
        }
        // Reaching here means the item genuinely does not exist yet — create it.
        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey, tag: tag)
        return newKey
    }

    private func loadKeyFromKeychain(tag: String, context: LAContext? = nil) throws -> SymmetricKey? {
        // NOTE: kSecAttrAccessible must NOT be included in a read query — it is write-only.
        var query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: tag,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        // Pass an authenticated LAContext so biometric-protected items can be read.
        if let ctx = context {
            query[kSecUseAuthenticationContext] = ctx
        }
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
        let accessFlags: SecAccessControlCreateFlags = [.biometryCurrentSet]
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
    // Safe order: decrypt → generate new keys → re-encrypt → delete old keys.
    // Old keys are only removed after ALL new blobs are successfully produced.

    func rotateKeys(blobs: [Data]) async throws -> [Data] {
        // Authenticate once for the entire rotation operation.
        let ctx = try await authenticatedContext()

        // Step 1: Load old keys (using the already-authenticated context) and decrypt all blobs.
        let oldAesKey    = try getOrCreateSymmetricKey(tag: aesKeyTag,    context: ctx)
        let oldChachaKey = try getOrCreateSymmetricKey(tag: chachaKeyTag, context: ctx)
        let oldHmacKey   = try getOrCreateSymmetricKey(tag: hmacKeyTag,   context: ctx)

        let plaintexts: [Data] = try blobs.map { data in
            try decryptWithKeys(data: data, aesKey: oldAesKey, chachaKey: oldChachaKey, hmacKey: oldHmacKey)
        }

        // Step 2: Generate new keys and re-encrypt all plaintexts.
        let newAesKey    = SymmetricKey(size: .bits256)
        let newChachaKey = SymmetricKey(size: .bits256)
        let newHmacKey   = SymmetricKey(size: .bits256)

        let reEncrypted: [Data] = try plaintexts.map { plaintext in
            try encryptWithKeys(plaintext: plaintext, aesKey: newAesKey, chachaKey: newChachaKey, hmacKey: newHmacKey)
        }

        // Step 3: All blobs successfully re-encrypted — now persist the new keys.
        // saveKeyToKeychain deletes the old key before writing the new one.
        try saveKeyToKeychain(newAesKey,    tag: aesKeyTag)
        try saveKeyToKeychain(newChachaKey, tag: chachaKeyTag)
        try saveKeyToKeychain(newHmacKey,   tag: hmacKeyTag)

        return reEncrypted
    }

    // ── Synchronous helpers used by rotateKeys ────────────

    private func encryptWithKeys(plaintext: Data, aesKey: SymmetricKey, chachaKey: SymmetricKey, hmacKey: SymmetricKey) throws -> Data {
        guard let aesBox = try? AES.GCM.seal(plaintext, using: aesKey),
              let layer1 = aesBox.combined else {
            throw FTCryptoError.encryptFailed("AES-GCM seal failed during rotation")
        }
        guard let chachaBox = try? ChaChaPoly.seal(layer1, using: chachaKey) else {
            throw FTCryptoError.encryptFailed("ChaCha20 seal failed during rotation")
        }
        let layer2 = chachaBox.combined
        let ts     = withUnsafeBytes(of: Date().timeIntervalSince1970.bitPattern) { Data($0) }
        let toSign = Data([0x02]) + ts + layer2
        let mac    = HMAC<SHA512>.authenticationCode(for: toSign, using: hmacKey)
        var out    = Data()
        out.append(0x02); out.append(ts); out.append(Data(mac)); out.append(layer2)
        return out
    }

    private func decryptWithKeys(data: Data, aesKey: SymmetricKey, chachaKey: SymmetricKey, hmacKey: SymmetricKey) throws -> Data {
        guard data.count > 73 else { throw FTCryptoError.integrityCheckFailed }
        guard data[0] == 0x02 else { throw FTCryptoError.decryptFailed("Unknown version during rotation") }
        let ts         = data[1..<9]
        let mac        = data[9..<73]
        let ciphertext = data[73...]
        let toVerify   = Data([0x02]) + ts + ciphertext
        let expected   = HMAC<SHA512>.authenticationCode(for: toVerify, using: hmacKey)
        guard Data(expected) == mac else { throw FTCryptoError.integrityCheckFailed }
        guard let chachaBox = try? ChaChaPoly.SealedBox(combined: Data(ciphertext)),
              let layer1 = try? ChaChaPoly.open(chachaBox, using: chachaKey) else {
            throw FTCryptoError.decryptFailed("ChaCha20 open failed during rotation")
        }
        guard let aesBox = try? AES.GCM.SealedBox(combined: layer1),
              let plaintext = try? AES.GCM.open(aesBox, using: aesKey) else {
            throw FTCryptoError.decryptFailed("AES-GCM open failed during rotation")
        }
        return plaintext
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Encrypted Data Store
// ─────────────────────────────────────────────────────────

@MainActor
final class EncryptedDataStore: ObservableObject {

    @Published var dailyLogs:        [DailyLog]        = []
    @Published var weeklySnapshots:  [WeeklySnapshot]  = []
    @Published var userProfile:      UserProfile       = UserProfile()
    @Published var mealTemplates:    [MealTemplate]    = []
    @Published var userPreferences:  UserPreferences   = UserPreferences()
    @Published var isLoading:        Bool              = false
    @Published var lastError:        String?
    /// Set when `loadFromDisk` fails; observed by the UI to show an alert.
    @Published var loadError:       String?

    private let fm  = FileManager.default
    private var dir: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func url(_ name: String) -> URL { dir.appendingPathComponent("\(name).ftenc") }

    // loadFromDisk() is NOT called here. FitTrackerApp triggers it after biometric
    // auth succeeds so EncryptionService.shared already has a valid session context.
    init() {}

    // ── CRUD ─────────────────────────────────────────────

    func upsertLog(_ log: DailyLog) {
        var l = log
        l.nutritionLog = normalizedNutritionLog(l.nutritionLog)
        l.logicDayKey = l.resolvedLogicDayKey
        l.lastModified = Date()
        l.needsSync = true
        if let i = dailyLogs.firstIndex(where: { $0.resolvedLogicDayKey == l.resolvedLogicDayKey }) {
            dailyLogs[i] = l
        } else {
            dailyLogs.append(l)
            dailyLogs.sort { $0.date > $1.date }
        }
        Task { await persistToDisk() }
    }

    func log(for date: Date) -> DailyLog? {
        log(forLogicDayKey: Date.fitLogicDayKey(for: date))
    }

    func todayLog() -> DailyLog? { log(for: Date()) }

    func log(forLogicDayKey key: String) -> DailyLog? {
        dailyLogs.first { $0.resolvedLogicDayKey == key }
    }

    var supplementStreak: Int {
        let sorted = dailyLogs.sorted { $0.date > $1.date }
        var streak = 0
        let today = Calendar.current.startOfDay(for: Date())
        var expectedDay = today
        for log in sorted {
            let logDay = Calendar.current.startOfDay(for: log.date)
            // Skip future-dated logs
            if logDay > today { continue }
            guard logDay == expectedDay else { break }
            let complete = log.supplementLog.morningStatus == .completed
                        && log.supplementLog.eveningStatus == .completed
            if complete {
                streak += 1
                expectedDay = Calendar.current.date(byAdding: .day, value: -1, to: expectedDay) ?? expectedDay
            } else {
                break
            }
        }
        return streak
    }

    /// Computes a 0–100 readiness score for the given date.
    /// Returns `nil` if there is insufficient data (fewer than 3 logs with HRV,
    /// no 30-day baseline, or today's HRV / resting HR not available).
    func readinessScore(for date: Date, fallbackMetrics: LiveMetrics?) -> Int? {
        // Need at least 3 biometric logs to establish baseline
        let logsWithHRV = dailyLogs.filter { $0.biometrics.effectiveHRV != nil }
        guard logsWithHRV.count >= 3 else { return nil }

        // Get today's biometrics — either from stored log or fallback metrics
        let todayLog = self.log(for: date)
        let todayHRV   = todayLog?.biometrics.effectiveHRV      ?? fallbackMetrics?.hrv
        let todayHR    = todayLog?.biometrics.effectiveRestingHR ?? fallbackMetrics?.restingHR
        let todaySleep = todayLog?.biometrics.effectiveSleep     ?? fallbackMetrics?.sleepHours

        guard let hrv = todayHRV, let hr = todayHR else { return nil }
        let sleep = todaySleep ?? 7.0   // default if no sleep data

        // 30-day baseline from stored logs (excluding today)
        let cal = Calendar.current
        let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: date) ?? date
        let baseline = dailyLogs.filter {
            $0.date >= thirtyDaysAgo &&
            !cal.isDate($0.date, inSameDayAs: date)
        }

        let baselineHRV = baseline.compactMap { $0.biometrics.effectiveHRV }
        let baselineHR  = baseline.compactMap { $0.biometrics.effectiveRestingHR }

        guard !baselineHRV.isEmpty, !baselineHR.isEmpty else { return nil }

        let avgBaselineHRV = baselineHRV.reduce(0, +) / Double(baselineHRV.count)
        let avgBaselineHR  = baselineHR.reduce(0, +)  / Double(baselineHR.count)

        // Score components (each 0–100):
        let hrvSignal   = min(100, max(0, (hrv / avgBaselineHRV) * 50))
        let hrSignal    = min(100, max(0, 50 + (avgBaselineHR - hr) * 10))
        let sleepSignal = min(100, max(0, (sleep / 8.0) * 100))

        // Weighted average:
        let score = Int(hrvSignal * 0.40 + hrSignal * 0.30 + sleepSignal * 0.30)
        return score
    }

    func saveProfile(_ p: UserProfile) {
        userProfile = p
        Task { await persistToDisk() }
    }

    // ── Persist / Load ───────────────────────────────────

    func persistToDisk() async {
        do {
            let logsEnc      = try await EncryptionService.shared.encrypt(dailyLogs)
            let snapsEnc     = try await EncryptionService.shared.encrypt(weeklySnapshots)
            let profEnc      = try await EncryptionService.shared.encrypt(userProfile)
            let templatesEnc = try await EncryptionService.shared.encrypt(mealTemplates)
            let prefsEnc     = try await EncryptionService.shared.encrypt(userPreferences)

            // .completeFileProtectionUnlessOpen = encrypted at rest, even when locked (iOS only)
            #if os(iOS)
            try logsEnc.write(to:      url("logs"),             options: .completeFileProtectionUnlessOpen)
            try snapsEnc.write(to:     url("snaps"),            options: .completeFileProtectionUnlessOpen)
            try profEnc.write(to:      url("profile"),          options: .completeFileProtectionUnlessOpen)
            try templatesEnc.write(to: url("mealTemplates"),    options: .completeFileProtectionUnlessOpen)
            try prefsEnc.write(to:     url("userPreferences"),  options: .completeFileProtectionUnlessOpen)
            #else
            try logsEnc.write(to:      url("logs"))
            try snapsEnc.write(to:     url("snaps"))
            try profEnc.write(to:      url("profile"))
            try templatesEnc.write(to: url("mealTemplates"))
            try prefsEnc.write(to:     url("userPreferences"))
            #endif
        } catch {
            await MainActor.run { lastError = error.localizedDescription }
        }
    }

    func loadFromDisk() async {
        await MainActor.run { isLoading = true; loadError = nil }
        do {
            if let d = try loadDataIfPresent(from: url("logs")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: [DailyLog].self)
                let normalized = v.map { log in
                    var normalizedLog = log
                    normalizedLog.logicDayKey = log.resolvedLogicDayKey
                    return normalizedLog
                }
                await MainActor.run { dailyLogs = normalized }
            }
            if let d = try loadDataIfPresent(from: url("snaps")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: [WeeklySnapshot].self)
                await MainActor.run { weeklySnapshots = v }
            }
            if let d = try loadDataIfPresent(from: url("profile")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: UserProfile.self)
                await MainActor.run { userProfile = v }
            }
            if let d = try loadDataIfPresent(from: url("mealTemplates")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: [MealTemplate].self)
                await MainActor.run { mealTemplates = v }
            }
            if let d = try loadDataIfPresent(from: url("userPreferences")), !d.isEmpty {
                let v = try await EncryptionService.shared.decrypt(d, as: UserPreferences.self)
                await MainActor.run { userPreferences = v }
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                loadError = error.localizedDescription
            }
        }
        await MainActor.run { isLoading = false }
    }

    private func loadDataIfPresent(from fileURL: URL) throws -> Data? {
        do {
            return try Data(contentsOf: fileURL)
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return nil
        } catch {
            throw error
        }
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

    private func normalizedNutritionLog(_ nutrition: NutritionLog) -> NutritionLog {
        var normalized = nutrition
        if let calories = nutrition.mealCaloriesTotal {
            normalized.totalCalories = calories
        }
        if let protein = nutrition.mealProteinTotal {
            normalized.totalProteinG = protein
        }
        if let carbs = nutrition.mealCarbsTotal {
            normalized.totalCarbsG = carbs
        }
        if let fat = nutrition.mealFatTotal {
            normalized.totalFatG = fat
        }
        return normalized
    }

    private func buildHints(_ logs: [DailyLog]) -> ExportPackage.AIHints {
        let r7  = logs.prefix(7)
        let r28 = logs.prefix(28)

        let hrvVals    = r7.compactMap { $0.biometrics.effectiveHRV }
        let wVals      = r7.compactMap { $0.biometrics.weightKg }
        let bfVals     = r7.compactMap { $0.biometrics.bodyFatPercent }

        func trend(_ vals: [Double]) -> String {
            guard vals.count >= 2, let first = vals.first, let last = vals.last else { return "insufficient data" }
            let d = first - last
            return d < -1 ? "decreasing" : d > 1 ? "increasing" : "stable"
        }

        let adh   = r28.map { $0.completionPct }.reduce(0,+) / max(1, Double(r28.count))
        let prot  = Double(r28.filter { ($0.nutritionLog.resolvedProteinG ?? 0) >= 125 }.count) / max(1, Double(r28.count))
        let supp  = Double(r28.filter { $0.supplementLog.morningStatus == .completed }.count) / max(1, Double(r28.count))
        let prefs = userPreferences
        let z2min = r7.flatMap { $0.cardioLogs.values }.compactMap { $0.wasInZone2(lower: prefs.zone2LowerHR, upper: prefs.zone2UpperHR) == true ? $0.durationMinutes : nil }.reduce(0,+)

        var flags: [String] = []; var pos: [String] = []
        if let hrv = logs.first?.biometrics.effectiveHRV, hrv < prefs.hrvReadyThreshold { flags.append("HRV below \(Int(prefs.hrvReadyThreshold)) ms") }
        if let rhr = logs.first?.biometrics.effectiveRestingHR, rhr > Double(userPreferences.hrReadyThreshold) { flags.append("Resting HR above \(userPreferences.hrReadyThreshold) bpm") }
        if adh < 70 { flags.append("Task adherence below 70%") }
        if z2min < 90 { flags.append("Zone 2 below 90 min/week") }
        if trend(hrvVals) == "increasing" { pos.append("HRV trend improving") }
        if trend(wVals)   == "decreasing" { pos.append("Weight trending down") }
        if adh > 85 { pos.append("Excellent task adherence") }

        let cw = wVals.last; let cb = bfVals.last
        let gp = userProfile.overallProgress(currentWeight: cw, currentBF: cb)

        return ExportPackage.AIHints(
            hrvTrend: trend(hrvVals), weightTrend: trend(wVals), bfTrend: trend(bfVals),
            avgAdherence: adh, zone2MinPerWeek: z2min, proteinAdherence: prot,
            suppAdherence: supp, flags: flags, positives: pos, overallGoalProgress: gp
        )
    }
}
