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

    /// Set true by `deleteStoredKeys()`. Forces `encryptRaw`/`rotateKeys` to
    /// throw rather than silently regenerate keys for a user whose keys were
    /// explicitly deleted (audit BE-027). Cleared on `setSessionContext`
    /// (next legitimate auth event implies the user re-onboarded).
    private var keysDeleted: Bool = false

    /// Re-enable rotation guard explicitly — used internally when `rotateKeys`
    /// finishes successfully. Audit BE-014.
    private var isRotating: Bool = false

    func setSessionContext(_ ctx: LAContext) {
        sessionContext = ctx
        // Re-auth implies the user re-onboarded after deletion; clear the flag.
        keysDeleted = false
    }

    func clearSessionContext() {
        sessionContext = nil
    }

    func deleteStoredKeys() throws {
        try deleteKeyFromKeychain(tag: aesKeyTag)
        try deleteKeyFromKeychain(tag: chachaKeyTag)
        try deleteKeyFromKeychain(tag: hmacKeyTag)
        sessionContext = nil
        keysDeleted = true
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
        // Audit BE-027: refuse to silently regenerate keys after explicit deletion.
        // setSessionContext() clears this flag (re-auth = user re-onboarded).
        if keysDeleted {
            throw FTCryptoError.encryptFailed("Keys were explicitly deleted; re-authenticate to regenerate")
        }
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

        // Validate timestamp — reject data older than 2 years (stale/replayed).
        // Copy into aligned storage before reading — the Data slice may be unaligned.
        var timestampBits: UInt64 = 0
        withUnsafeMutableBytes(of: &timestampBits) { dst in
            ts.copyBytes(to: dst)
        }
        let timestamp = Date(timeIntervalSince1970: TimeInterval(bitPattern: timestampBits))
        let maxAge: TimeInterval = 2 * 365.25 * 24 * 3600  // ~2 years
        if abs(Date().timeIntervalSince(timestamp)) > maxAge {
            throw FTCryptoError.decryptFailed("HMAC timestamp outside valid window")
        }

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

    private func deleteKeyFromKeychain(tag: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: tag,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw FTCryptoError.keychainError(status)
        }
    }

    private func saveKeyToKeychain(_ key: SymmetricKey, tag: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        #if os(iOS) || os(macOS)
        // .biometryAny survives biometric re-enrollment (new fingerprint/face).
        // .biometryCurrentSet would invalidate keys on re-enrollment → data loss.
        let accessFlags: SecAccessControlCreateFlags = [.biometryAny]
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
        // Update-first pattern avoids the brief window of no key in delete-then-add.
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: tag,
        ]
        let update: [CFString: Any] = [
            kSecValueData:         keyData,
            kSecAttrAccessControl: acl,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecItemNotFound {
            let status = SecItemAdd(attrs as CFDictionary, nil)
            guard status == errSecSuccess else { throw FTCryptoError.keychainError(status) }
        } else if updateStatus != errSecSuccess {
            throw FTCryptoError.keychainError(updateStatus)
        }
    }

    // ── Key rotation: re-encrypt all blobs ───────────────
    // Safe order: decrypt → generate new keys → re-encrypt → delete old keys.
    // Old keys are only removed after ALL new blobs are successfully produced.

    func rotateKeys(blobs: [Data]) async throws -> [Data] {
        // Audit BE-014: explicit re-entry guard. The actor already serializes
        // calls, but an awaited authentication step inside this function could
        // overlap with a second rotation request that arrives before the first
        // completes; this flag makes the "no concurrent rotation" contract
        // observable instead of relying solely on actor serialization.
        guard !isRotating else {
            throw FTCryptoError.encryptFailed("Key rotation already in progress")
        }
        // Audit BE-027: refuse rotation after explicit deletion.
        if keysDeleted {
            throw FTCryptoError.encryptFailed("Keys were explicitly deleted; re-authenticate to regenerate")
        }
        isRotating = true
        defer { isRotating = false }

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
    /// Audit BE-016: set when `persistToDisk` fails after retry. UI / scenePhase
    /// observers can call `retryPersistIfFailed()` to attempt recovery, otherwise
    /// data may be lost on next launch. Distinct from `lastError` (which is
    /// transient) so consumers can show a persistent "save failed" indicator.
    @Published var persistenceFailed: Bool = false

    private let fm  = FileManager.default
    private var dir: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func url(_ name: String) -> URL { dir.appendingPathComponent("\(name).ftenc") }

    // loadFromDisk() is NOT called here. FitTrackerApp triggers it after biometric
    // auth succeeds so EncryptionService.shared already has a valid session context.
    init() {}

    /// Wipe all in-memory user data (called on sign-out / session lock).
    func clearInMemory() {
        dailyLogs       = []
        weeklySnapshots = []
        userProfile     = UserProfile()
        mealTemplates   = []
        userPreferences = UserPreferences()
        lastError       = nil
        loadError       = nil
    }

    func deletePersistedData() throws {
        clearInMemory()
        for name in ["logs", "snaps", "profile", "mealTemplates", "userPreferences"] {
            let fileURL = url(name)
            if fm.fileExists(atPath: fileURL.path) {
                try fm.removeItem(at: fileURL)
            }
        }
    }

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
    /// Delegates to ReadinessEngine (v2 — 5-component, goal-aware, evidence-based).
    /// Returns `nil` if there is insufficient data.
    func readinessScore(for date: Date, fallbackMetrics: LiveMetrics?) -> Int? {
        readinessResult(for: date, fallbackMetrics: fallbackMetrics)?.overallScore
    }

    /// Full readiness assessment with per-component breakdown.
    /// Uses ReadinessEngine.compute() — see ReadinessEngine.swift for formula details.
    func readinessResult(for date: Date, fallbackMetrics: LiveMetrics?) -> ReadinessResult? {
        // Merge stored biometrics with live HealthKit metrics.
        // Priority: live HealthKit data > stored biometrics (fresher wins).
        // Only fall back to stored data if live is unavailable.
        // Manual fallback values (manualHRV, manualRestingHR, manualSleepHours)
        // are only used if BOTH live and auto-synced values are nil.
        let todayLog = self.log(for: date)
        var metrics = fallbackMetrics ?? LiveMetrics()

        if let bio = todayLog?.biometrics {
            // Live wins over stored for sensor data (fresher reading)
            metrics.hrv = metrics.hrv ?? bio.effectiveHRV
            metrics.restingHR = metrics.restingHR ?? bio.effectiveRestingHR
            metrics.sleepHours = metrics.sleepHours ?? bio.effectiveSleep
            metrics.deepSleepMin = metrics.deepSleepMin ?? bio.deepSleepMinutes
            metrics.remSleepMin = metrics.remSleepMin ?? bio.remSleepMinutes
            // Weight is usually from scale (stored), not live — stored wins
            metrics.weightKg = bio.weightKg ?? metrics.weightKg
        }

        return ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: dailyLogs,
            goalMode: userPreferences.nutritionGoalMode,
            date: date,
            sleepGoalHours: userPreferences.sleepGoalHours,
            userAge: userProfile.age
        )
    }

    func saveProfile(_ p: UserProfile) {
        userProfile = p
        Task { await persistToDisk() }
    }

    // ── Persist / Load ───────────────────────────────────

    /// Persist the in-memory store to disk. Audit BE-016: a single transient
    /// failure (encryption hiccup, momentary disk pressure) used to silently
    /// strand data in memory until the next launch. Now: one retry on failure,
    /// then `persistenceFailed = true` so the UI / scenePhase observers can
    /// surface or attempt recovery via `retryPersistIfFailed()`.
    ///
    /// Existing call sites (30+) use fire-and-forget `Task { await persistToDisk() }`
    /// — that pattern is preserved by keeping the function `async -> Void` and
    /// signalling failure via published state instead of return value.
    func persistToDisk() async {
        if await attemptPersist() {
            await MainActor.run { persistenceFailed = false }
            return
        }
        // First write failed — try once more after a short backoff. Disk-full
        // and transient encryption errors often recover on the second attempt.
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        if await attemptPersist() {
            await MainActor.run { persistenceFailed = false }
            return
        }
        await MainActor.run { persistenceFailed = true }
    }

    /// Re-attempt persistence if the last `persistToDisk` call left the
    /// store in a failed state. Safe no-op when there's nothing to retry.
    /// Call this from `scenePhase == .active` and after surfacing a
    /// "save failed" UI affordance.
    func retryPersistIfFailed() async {
        guard persistenceFailed else { return }
        await persistToDisk()
    }

    /// Single persistence attempt. Returns true on success, false on any
    /// thrown error (encryption or disk). Updates `lastError` on failure
    /// so callers can inspect what went wrong.
    ///
    /// Audit DEEP-AUTH-011: writes use a two-phase commit pattern. All five
    /// encrypted blobs are first written to `<filename>.tmp` siblings; only
    /// after every `.tmp` write succeeds are the renames performed. A
    /// mid-sequence failure during encryption or `.tmp` write leaves the
    /// canonical files untouched (clean rollback). The remaining inconsistency
    /// window is the rename loop itself, which is much shorter than encryption.
    /// `Data.write(to:options: [.atomic])` already does per-file atomic
    /// rename internally — combined with the staged-tmp pattern, callers see
    /// either the previous full snapshot or the new full snapshot, never a
    /// partial mix from two different logical moments.
    private func attemptPersist() async -> Bool {
        do {
            let logsEnc      = try await EncryptionService.shared.encrypt(dailyLogs)
            let snapsEnc     = try await EncryptionService.shared.encrypt(weeklySnapshots)
            let profEnc      = try await EncryptionService.shared.encrypt(userProfile)
            let templatesEnc = try await EncryptionService.shared.encrypt(mealTemplates)
            let prefsEnc     = try await EncryptionService.shared.encrypt(userPreferences)

            // Two-phase commit. Phase 1: write everything to `.tmp` siblings.
            let writes: [(name: String, data: Data)] = [
                ("logs", logsEnc),
                ("snaps", snapsEnc),
                ("profile", profEnc),
                ("mealTemplates", templatesEnc),
                ("userPreferences", prefsEnc),
            ]

            var tmpURLs: [URL] = []
            do {
                for write in writes {
                    let tmpURL = url("\(write.name).tmp")
                    #if os(iOS)
                    try write.data.write(to: tmpURL, options: [.atomic, .completeFileProtectionUnlessOpen])
                    #else
                    try write.data.write(to: tmpURL, options: .atomic)
                    #endif
                    tmpURLs.append(tmpURL)
                }
            } catch {
                // Phase 1 failed mid-flight. Clean up any .tmp files we wrote.
                for tmp in tmpURLs { try? fm.removeItem(at: tmp) }
                throw error
            }

            // Phase 2: atomically rename each .tmp into place. Each rename is
            // atomic at the filesystem level. The window between renames is
            // small, but a crash here can still leave a mixed-snapshot state —
            // acceptable trade-off vs the previous "5 sequential encrypted
            // writes" risk window. `replaceItemAt` requires the destination
            // to exist, so first-time writes fall back to a plain `moveItem`.
            for write in writes {
                let tmpURL = url("\(write.name).tmp")
                let finalURL = url(write.name)
                if fm.fileExists(atPath: finalURL.path) {
                    _ = try fm.replaceItemAt(finalURL, withItemAt: tmpURL)
                } else {
                    try fm.moveItem(at: tmpURL, to: finalURL)
                }
            }
            return true
        } catch {
            await MainActor.run { lastError = error.localizedDescription }
            return false
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

    // ── Supabase sync merge helpers ───────────────────────

    /// Merge a remote DailyLog using last-modified-wins conflict resolution.
    func mergeDailyLog(_ remote: DailyLog) {
        let remoteLogicDayKey = remote.resolvedLogicDayKey
        if let i = dailyLogs.firstIndex(where: {
            $0.resolvedLogicDayKey == remoteLogicDayKey
        }) {
            if remote.lastModified > dailyLogs[i].lastModified {
                dailyLogs[i] = remote
            }
        } else {
            dailyLogs.append(remote)
            dailyLogs.sort { $0.date > $1.date }
        }
    }

    /// Merge a remote WeeklySnapshot: local wins if needsSync (unsaved changes), else remote wins.
    func mergeWeeklySnapshot(_ remote: WeeklySnapshot) {
        if let i = weeklySnapshots.firstIndex(where: {
            Calendar.current.isDate($0.weekStart, inSameDayAs: remote.weekStart)
        }) {
            guard !weeklySnapshots[i].needsSync else { return }  // local unsaved — skip
            weeklySnapshots[i] = remote
        } else {
            weeklySnapshots.append(remote)
            weeklySnapshots.sort { $0.weekStart > $1.weekStart }
        }
    }

    /// Mark a daily log as synced (clears needsSync flag).
    func markSynced(logID: UUID) {
        if let i = dailyLogs.firstIndex(where: { $0.id == logID }) {
            dailyLogs[i].needsSync = false
        }
    }

    /// Mark a weekly snapshot as synced.
    func markSnapshotSynced(id: UUID) {
        if let i = weeklySnapshots.firstIndex(where: { $0.id == id }) {
            weeklySnapshots[i].needsSync = false
        }
    }

    /// SHA-256 three-way merge for UserProfile singleton.
    /// Remote wins unless the local copy has been modified since the last sync.
    func mergeProfile(_ remote: UserProfile, remoteChecksum: String, digestKey: String) {
        guard let localBlob = try? JSONEncoder().encode(userProfile) else { return }
        let localChecksum = SHA256.hash(data: localBlob).hexString
        let lastSyncedChecksum = UserDefaults.standard.string(forKey: digestKey) ?? ""
        if localChecksum == remoteChecksum { return }              // identical — no-op
        if localChecksum != lastSyncedChecksum { return }          // local has unsaved changes — keep
        userProfile = remote
        UserDefaults.standard.set(remoteChecksum, forKey: digestKey)
    }

    /// SHA-256 three-way merge for UserPreferences singleton.
    func mergePreferences(_ remote: UserPreferences, remoteChecksum: String, digestKey: String) {
        guard let localBlob = try? JSONEncoder().encode(userPreferences) else { return }
        let localChecksum = SHA256.hash(data: localBlob).hexString
        let lastSyncedChecksum = UserDefaults.standard.string(forKey: digestKey) ?? ""
        if localChecksum == remoteChecksum { return }
        if localChecksum != lastSyncedChecksum { return }
        userPreferences = remote
        UserDefaults.standard.set(remoteChecksum, forKey: digestKey)
    }

    /// SHA-256 three-way merge for MealTemplates singleton.
    func mergeMealTemplates(_ remote: [MealTemplate], remoteChecksum: String, digestKey: String) {
        guard let localBlob = try? JSONEncoder().encode(mealTemplates) else { return }
        let localChecksum = SHA256.hash(data: localBlob).hexString
        let lastSyncedChecksum = UserDefaults.standard.string(forKey: digestKey) ?? ""
        if localChecksum == remoteChecksum { return }
        if localChecksum != lastSyncedChecksum { return }
        mealTemplates = remote
        UserDefaults.standard.set(remoteChecksum, forKey: digestKey)
    }

    /// Store the Supabase Storage path for a cardio asset on the matching CardioLog.
    func updateCardioImagePath(date: Date, cardioType: String, storagePath: String) {
        guard let logIdx = dailyLogs.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else { return }
        let key = cardioType.lowercased()
        if var cardioLog = dailyLogs[logIdx].cardioLogs[key] {
            cardioLog.summaryImageCloudID = storagePath
            dailyLogs[logIdx].cardioLogs[key] = cardioLog
        }
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
