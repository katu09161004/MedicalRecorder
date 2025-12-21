//
// KeychainManager.swift
// MedicalRecorder
//
// Keychainを使用した認証情報の安全な保存
// APIキーやトークンを暗号化して保存
//

import Foundation
import Security

// MARK: - Keychainエラー
enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "アイテムが既に存在します"
        case .itemNotFound:
            return "アイテムが見つかりません"
        case .unexpectedStatus(let status):
            return "Keychainエラー: \(status)"
        case .invalidData:
            return "無効なデータです"
        }
    }
}

// MARK: - Keychainマネージャー
class KeychainManager {
    static let shared = KeychainManager()

    private let service = "co.jp.katu0619.MedicalRecorder"

    private init() {}

    // MARK: - 保存
    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // 既存のアイテムを削除してから保存
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - 読み込み
    func load(forKey key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    // MARK: - 読み込み（オプショナル）
    func loadOptional(forKey key: String) -> String? {
        return try? load(forKey: key)
    }

    // MARK: - 削除
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - すべて削除
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - 存在チェック
    func exists(forKey key: String) -> Bool {
        return loadOptional(forKey: key) != nil
    }
}

// MARK: - Keychain キー定義
extension KeychainManager {
    struct Keys {
        static let sakuraTokenID = "sakura_token_id"
        static let sakuraSecret = "sakura_secret"
        static let aquaVoiceAPIKey = "aqua_voice_api_key"
        static let amiVoiceAPIKey = "ami_voice_api_key"
        static let githubToken = "github_token"
    }
}

// MARK: - 便利なプロパティラッパー
@propertyWrapper
struct KeychainStored {
    let key: String
    let defaultValue: String

    init(key: String, defaultValue: String = "") {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: String {
        get {
            KeychainManager.shared.loadOptional(forKey: key) ?? defaultValue
        }
        set {
            if newValue.isEmpty {
                try? KeychainManager.shared.delete(forKey: key)
            } else {
                try? KeychainManager.shared.save(newValue, forKey: key)
            }
        }
    }
}
