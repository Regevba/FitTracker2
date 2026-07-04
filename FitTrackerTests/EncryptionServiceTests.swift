// FitTrackerTests/EncryptionServiceTests.swift
// TEST-001: EncryptionService — encrypt/decrypt round-trip, HMAC verification,
// container format, empty data edge case, wrong-ciphertext rejection.
//
// Strategy: Uses the real EncryptionService actor and the real Keychain on iOS
// Simulator, where biometric auth is bypassed. No mock infrastructure needed.

import XCTest
import LocalAuthentication
@testable import FitTracker

final class EncryptionServiceTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Ensure session context is set so crypto ops don't require biometric prompt
        await EncryptionService.shared.setSessionContext(LAContext())
    }

    // MARK: - Round-trip

    func testEncryptDecrypt_roundTripPreservesData() async throws {
        let original = "FitMe secret health data".data(using: .utf8)!
        let encrypted = try await EncryptionService.shared.encryptRaw(original)
        let decrypted = try await EncryptionService.shared.decryptRaw(encrypted)
        XCTAssertEqual(decrypted, original, "Round-trip must preserve bytes exactly")
    }

    func testEncryptDecrypt_differentCiphertextForSamePlaintext() async throws {
        // AES-GCM uses a random IV → same plaintext should produce different ciphertext
        let plaintext = "same data".data(using: .utf8)!
        let blob1 = try await EncryptionService.shared.encryptRaw(plaintext)
        let blob2 = try await EncryptionService.shared.encryptRaw(plaintext)
        XCTAssertNotEqual(blob1, blob2,
                          "AES-GCM random IV must produce different ciphertexts for same plaintext")
    }

    func testEncryptDecrypt_CodableValue() async throws {
        struct Sample: Codable, Equatable {
            let name: String
            let count: Int
            let values: [Double]
        }
        let original = Sample(name: "test", count: 42, values: [1.1, 2.2, 3.3])
        let encrypted = try await EncryptionService.shared.encrypt(original)
        let decrypted = try await EncryptionService.shared.decrypt(encrypted, as: Sample.self)
        XCTAssertEqual(decrypted, original)
    }

    // MARK: - Container format

    func testEncryptedBlob_hasCorrectHeader() async throws {
        let plaintext = Data([0xFF, 0xEE, 0xDD])
        let blob = try await EncryptionService.shared.encryptRaw(plaintext)

        // Container layout: [version 1B][timestamp 8B][hmac 64B][ciphertext]
        XCTAssertGreaterThan(blob.count, 73, "Blob must be larger than header (73 bytes)")
        XCTAssertEqual(blob[0], 0x02, "Version byte must be 0x02")
    }

    // MARK: - Tamper detection

    func testDecrypt_tamperedCiphertext_throws() async throws {
        let plaintext = "authentic data".data(using: .utf8)!
        var blob = try await EncryptionService.shared.encryptRaw(plaintext)

        // Flip a bit in the ciphertext region (past the 73-byte header)
        let tamperIndex = blob.count - 1
        blob[tamperIndex] = blob[tamperIndex] ^ 0x01

        do {
            _ = try await EncryptionService.shared.decryptRaw(blob)
            XCTFail("Tampered ciphertext should fail HMAC verification")
        } catch {
            // Expected — HMAC or AEAD should reject tampered data
        }
    }

    func testDecrypt_tamperedHMAC_throws() async throws {
        let plaintext = "protected".data(using: .utf8)!
        var blob = try await EncryptionService.shared.encryptRaw(plaintext)

        // Flip a bit in the HMAC region (bytes 9..72)
        blob[10] = blob[10] ^ 0x01

        do {
            _ = try await EncryptionService.shared.decryptRaw(blob)
            XCTFail("Tampered HMAC should fail verification")
        } catch {
            // Expected
        }
    }

    func testDecrypt_wrongVersionByte_throws() async throws {
        let plaintext = "versioned".data(using: .utf8)!
        var blob = try await EncryptionService.shared.encryptRaw(plaintext)

        // Change version from 0x02 to 0x99
        blob[0] = 0x99

        do {
            _ = try await EncryptionService.shared.decryptRaw(blob)
            XCTFail("Unknown version byte must be rejected")
        } catch {
            // Expected
        }
    }

    // MARK: - Edge cases

    func testEncrypt_emptyData() async throws {
        let empty = Data()
        let blob = try await EncryptionService.shared.encryptRaw(empty)
        let decrypted = try await EncryptionService.shared.decryptRaw(blob)
        XCTAssertEqual(decrypted, empty)
    }

    func testDecrypt_truncatedBlob_throws() async {
        // A blob shorter than the 73-byte header must be rejected
        let tooShort = Data(repeating: 0, count: 50)

        do {
            _ = try await EncryptionService.shared.decryptRaw(tooShort)
            XCTFail("Truncated blob must be rejected")
        } catch {
            // Expected — integrityCheckFailed
        }
    }

    // MARK: - HMAC timestamp validation (added in Sprint B)

    func testDecrypt_freshBlob_passesTimestampCheck() async throws {
        // A freshly-encrypted blob must decrypt successfully (timestamp within 2-year window)
        let plaintext = "fresh".data(using: .utf8)!
        let blob = try await EncryptionService.shared.encryptRaw(plaintext)
        let decrypted = try await EncryptionService.shared.decryptRaw(blob)
        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - Concurrency + payload chaos (FIT-157 / T9 — adversarial edge cases)
    //
    // These exercise the session-context encrypt/decrypt path (the path the app
    // uses at runtime) under load / large data / high cardinality. The
    // biometric-gated `rotateKeys` path is NOT covered here: it calls
    // `authenticatedContext()`, which requires an enrolled authenticator the CI
    // simulator does not have (LAError -7 "No identities are enrolled"). Testing
    // rotation needs either a biometry-enrolled CI simulator or a prod-code test
    // seam — tracked as a follow-up (state.json task T2/T3), not attempted here.

    func testEncrypt_concurrentRoundTrips_allSucceed() async throws {
        // The EncryptionService actor must serialize concurrent crypto ops
        // without data races or cross-talk. Fire many parallel encrypt→decrypt
        // round-trips and assert every one preserves its own bytes.
        let enc = EncryptionService.shared
        let count = 32

        try await withThrowingTaskGroup(of: Bool.self) { group in
            for i in 0..<count {
                group.addTask {
                    let payload = "concurrent-\(i)-\(String(repeating: "x", count: i))".data(using: .utf8)!
                    let blob = try await enc.encryptRaw(payload)
                    let back = try await enc.decryptRaw(blob)
                    return back == payload
                }
            }
            var ok = 0
            for try await result in group where result { ok += 1 }
            XCTAssertEqual(ok, count, "Every concurrent round-trip must preserve its own bytes")
        }
    }

    func testEncrypt_largePayload_roundTripsLosslessly() async throws {
        // ~2 MB of random bytes must survive the double-seal (AES-GCM → ChaCha20)
        // container round-trip exactly — guards against buffer/length bugs on the
        // large end (a full day of health data is far smaller, but the ceiling
        // must hold).
        let enc = EncryptionService.shared
        var big = Data(count: 2 * 1024 * 1024)
        big.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!) }

        let blob = try await enc.encryptRaw(big)
        let back = try await enc.decryptRaw(blob)
        XCTAssertEqual(back, big, "Large payload must round-trip byte-for-byte")
        XCTAssertGreaterThan(blob.count, big.count, "Container must add header + auth overhead")
    }

    func testEncrypt_manyDistinctPayloads_noCrossContamination() async throws {
        // Encrypt many distinct plaintexts, then decrypt each blob and assert it
        // maps back to its OWN plaintext — a blob must never decrypt to another
        // record's data (IV/key reuse or container-mixup regression guard).
        let enc = EncryptionService.shared
        let payloads = (0..<50).map { "record-\($0)-value-\($0 * 7)".data(using: .utf8)! }

        var blobs: [Data] = []
        for p in payloads { blobs.append(try await enc.encryptRaw(p)) }

        for (idx, blob) in blobs.enumerated() {
            let back = try await enc.decryptRaw(blob)
            XCTAssertEqual(back, payloads[idx], "Blob \(idx) must decrypt to its own plaintext")
        }
    }
}
