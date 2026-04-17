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
}
