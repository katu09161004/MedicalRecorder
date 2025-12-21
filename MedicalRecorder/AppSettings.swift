//
// AppSettings.swift
// MedicalRecorder
//
// アプリケーション設定の管理
// 認証情報はKeychainに安全に保存
// 一般設定はUserDefaultsで保存
//

import Foundation
import Combine

class AppSettings: ObservableObject {
    // シングルトンインスタンス
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private let keychain = KeychainManager.shared

    // API プロバイダー選択
    @Published var transcriptionProvider: TranscriptionProvider {
        didSet {
            defaults.set(transcriptionProvider.rawValue, forKey: "transcriptionProvider")
        }
    }

    // さくらのAI API設定（Keychainに保存）
    @Published var sakuraTokenID: String {
        didSet {
            if sakuraTokenID.isEmpty {
                try? keychain.delete(forKey: KeychainManager.Keys.sakuraTokenID)
            } else {
                try? keychain.save(sakuraTokenID, forKey: KeychainManager.Keys.sakuraTokenID)
            }
        }
    }

    @Published var sakuraSecret: String {
        didSet {
            if sakuraSecret.isEmpty {
                try? keychain.delete(forKey: KeychainManager.Keys.sakuraSecret)
            } else {
                try? keychain.save(sakuraSecret, forKey: KeychainManager.Keys.sakuraSecret)
            }
        }
    }

    // Aqua Voice API設定（Keychainに保存）
    @Published var aquaVoiceAPIKey: String {
        didSet {
            if aquaVoiceAPIKey.isEmpty {
                try? keychain.delete(forKey: KeychainManager.Keys.aquaVoiceAPIKey)
            } else {
                try? keychain.save(aquaVoiceAPIKey, forKey: KeychainManager.Keys.aquaVoiceAPIKey)
            }
        }
    }

    // AmiVoice API設定（Keychainに保存）
    @Published var amiVoiceAPIKey: String {
        didSet {
            if amiVoiceAPIKey.isEmpty {
                try? keychain.delete(forKey: KeychainManager.Keys.amiVoiceAPIKey)
            } else {
                try? keychain.save(amiVoiceAPIKey, forKey: KeychainManager.Keys.amiVoiceAPIKey)
            }
        }
    }

    @Published var amiVoiceEngine: String {
        didSet { defaults.set(amiVoiceEngine, forKey: "amiVoiceEngine") }
    }

    // GitHub設定（トークンのみKeychainに保存）
    @Published var githubToken: String {
        didSet {
            if githubToken.isEmpty {
                try? keychain.delete(forKey: KeychainManager.Keys.githubToken)
            } else {
                try? keychain.save(githubToken, forKey: KeychainManager.Keys.githubToken)
            }
        }
    }

    @Published var githubOwner: String {
        didSet { defaults.set(githubOwner, forKey: "githubOwner") }
    }

    @Published var githubRepo: String {
        didSet { defaults.set(githubRepo, forKey: "githubRepo") }
    }

    @Published var githubBranch: String {
        didSet { defaults.set(githubBranch, forKey: "githubBranch") }
    }

    @Published var githubPath: String {
        didSet { defaults.set(githubPath, forKey: "githubPath") }
    }

    // 保存オプション
    @Published var saveRawTranscription: Bool {
        didSet { defaults.set(saveRawTranscription, forKey: "saveRawTranscription") }
    }

    @Published var saveAudioFile: Bool {
        didSet { defaults.set(saveAudioFile, forKey: "saveAudioFile") }
    }

    // 言語設定
    @Published var transcriptionLanguage: String {
        didSet { defaults.set(transcriptionLanguage, forKey: "transcriptionLanguage") }
    }

    // ローカルLLM設定
    @Published var useLocalLLM: Bool {
        didSet { defaults.set(useLocalLLM, forKey: "useLocalLLM") }
    }

    @Published var localLLMModelName: String {
        didSet { defaults.set(localLLMModelName, forKey: "localLLMModelName") }
    }

    // バックグラウンド録音設定
    @Published var enableBackgroundRecording: Bool {
        didSet { defaults.set(enableBackgroundRecording, forKey: "enableBackgroundRecording") }
    }

    // iCloud同期設定
    @Published var enableiCloudSync: Bool {
        didSet { defaults.set(enableiCloudSync, forKey: "enableiCloudSync") }
    }

    // 初期化
    private init() {
        // API プロバイダー選択（デフォルト: さくらのAI）
        if let providerString = defaults.string(forKey: "transcriptionProvider"),
           let provider = TranscriptionProvider(rawValue: providerString) {
            self.transcriptionProvider = provider
        } else {
            self.transcriptionProvider = .sakura
        }

        // Keychainから認証情報を読み込み
        self.sakuraTokenID = keychain.loadOptional(forKey: KeychainManager.Keys.sakuraTokenID) ?? ""
        self.sakuraSecret = keychain.loadOptional(forKey: KeychainManager.Keys.sakuraSecret) ?? ""
        self.aquaVoiceAPIKey = keychain.loadOptional(forKey: KeychainManager.Keys.aquaVoiceAPIKey) ?? ""
        self.amiVoiceAPIKey = keychain.loadOptional(forKey: KeychainManager.Keys.amiVoiceAPIKey) ?? ""
        self.githubToken = keychain.loadOptional(forKey: KeychainManager.Keys.githubToken) ?? ""

        // UserDefaultsから設定を読み込み
        self.amiVoiceEngine = defaults.string(forKey: "amiVoiceEngine") ?? "-a-general"
        self.githubOwner = defaults.string(forKey: "githubOwner") ?? ""
        self.githubRepo = defaults.string(forKey: "githubRepo") ?? ""
        self.githubBranch = defaults.string(forKey: "githubBranch") ?? "main"
        self.githubPath = defaults.string(forKey: "githubPath") ?? "recordings"

        // 保存オプション
        self.saveRawTranscription = defaults.bool(forKey: "saveRawTranscription")
        self.saveAudioFile = defaults.bool(forKey: "saveAudioFile")

        // 言語設定（デフォルト: 日本語）
        self.transcriptionLanguage = defaults.string(forKey: "transcriptionLanguage") ?? "ja"

        // ローカルLLM設定
        self.useLocalLLM = defaults.bool(forKey: "useLocalLLM")
        self.localLLMModelName = defaults.string(forKey: "localLLMModelName") ?? ""

        // バックグラウンド録音設定
        self.enableBackgroundRecording = defaults.bool(forKey: "enableBackgroundRecording")

        // iCloud同期設定
        self.enableiCloudSync = defaults.bool(forKey: "enableiCloudSync")

        // 初回起動時の設定
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            self.saveRawTranscription = true
            defaults.set(true, forKey: "hasLaunchedBefore")
        }

        // UserDefaultsからKeychainへのマイグレーション
        migrateToKeychain()
    }

    // MARK: - UserDefaultsからKeychainへのマイグレーション
    private func migrateToKeychain() {
        // 古いUserDefaults保存から移行
        let keysToMigrate = [
            ("sakuraTokenID", KeychainManager.Keys.sakuraTokenID),
            ("sakuraSecret", KeychainManager.Keys.sakuraSecret),
            ("aquaVoiceAPIKey", KeychainManager.Keys.aquaVoiceAPIKey),
            ("amiVoiceAPIKey", KeychainManager.Keys.amiVoiceAPIKey),
            ("githubToken", KeychainManager.Keys.githubToken)
        ]

        for (oldKey, newKey) in keysToMigrate {
            if let value = defaults.string(forKey: oldKey), !value.isEmpty {
                // Keychainにまだ保存されていない場合のみ移行
                if keychain.loadOptional(forKey: newKey) == nil {
                    try? keychain.save(value, forKey: newKey)
                    print("🔐 マイグレーション: \(oldKey) → Keychain")
                }
                // UserDefaultsから削除
                defaults.removeObject(forKey: oldKey)
            }
        }
    }

    // 設定が完了しているか確認
    var isConfigured: Bool {
        let hasGitHub = !githubToken.isEmpty && !githubOwner.isEmpty && !githubRepo.isEmpty

        // ローカルLLM使用時はさくらのAI設定不要
        let hasSakuraLLM = useLocalLLM || (!sakuraTokenID.isEmpty && !sakuraSecret.isEmpty)

        let result: Bool

        switch transcriptionProvider {
        case .sakura:
            result = hasSakuraLLM && hasGitHub
            print("📝 設定チェック (さくらのAI)")
            print("  - さくらLLM: \(hasSakuraLLM)")
            print("  - GitHub: \(hasGitHub)")
            print("  - 結果: \(result)")
        case .aquaVoice:
            result = !aquaVoiceAPIKey.isEmpty && hasSakuraLLM && hasGitHub
            print("📝 設定チェック (Aqua Voice)")
            print("  - AquaVoice APIキー: \(!aquaVoiceAPIKey.isEmpty)")
            print("  - さくらLLM: \(hasSakuraLLM)")
            print("  - GitHub: \(hasGitHub)")
            print("  - 結果: \(result)")
        case .amiVoice:
            result = !amiVoiceAPIKey.isEmpty && hasSakuraLLM && hasGitHub
            print("📝 設定チェック (AmiVoice)")
            print("  - AmiVoice APIキー: \(!amiVoiceAPIKey.isEmpty)")
            print("  - さくらLLM: \(hasSakuraLLM)")
            print("  - GitHub: \(hasGitHub)")
            print("  - 結果: \(result)")
        }

        return result
    }

    // 利用可能な言語
    static let availableLanguages: [(code: String, name: String)] = [
        ("ja", "日本語"),
        ("en", "English"),
        ("zh", "中文"),
        ("ko", "한국어"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("pt", "Português"),
        ("ru", "Русский"),
        ("ar", "العربية"),
        ("auto", "自動検出")
    ]

    // 設定をリセット（認証情報はクリアのみ）
    func resetToDefaults() {
        transcriptionProvider = .sakura
        sakuraTokenID = ""
        sakuraSecret = ""
        aquaVoiceAPIKey = ""
        amiVoiceAPIKey = ""
        amiVoiceEngine = "-a-general"
        githubToken = ""
        githubOwner = ""
        githubRepo = ""
        githubBranch = "main"
        githubPath = "recordings"
        saveRawTranscription = true
        saveAudioFile = false
        transcriptionLanguage = "ja"
        useLocalLLM = false
        localLLMModelName = ""
        enableBackgroundRecording = false
        enableiCloudSync = false

        // Keychainもクリア
        try? keychain.deleteAll()
    }
}
