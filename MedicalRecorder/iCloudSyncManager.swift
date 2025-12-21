//
// iCloudSyncManager.swift
// MedicalRecorder
//
// iCloud Key-Value Storeを使用したプロンプト設定の同期
//

import Foundation
import Combine

class iCloudSyncManager: ObservableObject {
    static let shared = iCloudSyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let store = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    private let promptsKey = "syncedCustomPrompts"
    private let selectedPromptKey = "syncedSelectedPromptId"
    private let lastSyncKey = "lastSyncDate"

    private init() {
        setupNotifications()
        // 起動時に同期
        synchronize()
    }

    // MARK: - 通知設定
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    @objc private func handleStoreChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // 他のデバイスからの変更を受信
            DispatchQueue.main.async { [weak self] in
                self?.downloadFromiCloud()
            }
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            syncError = "iCloudストレージの容量制限に達しました"
        case NSUbiquitousKeyValueStoreAccountChange:
            // アカウント変更
            DispatchQueue.main.async { [weak self] in
                self?.downloadFromiCloud()
            }
        default:
            break
        }
    }

    // MARK: - 同期
    func synchronize() {
        store.synchronize()
    }

    // MARK: - iCloudへアップロード
    func uploadToiCloud() {
        guard AppSettings.shared.enableiCloudSync else { return }

        isSyncing = true
        syncError = nil

        let promptManager = CustomPromptManager.shared

        // カスタムプロンプトをJSON化
        let userPrompts = promptManager.prompts.filter { !$0.isBuiltIn }
        let customizedBuiltIns = promptManager.prompts.filter { $0.isBuiltIn && $0.isCustomized }
        let allPromptsToSync = userPrompts + customizedBuiltIns

        if let data = try? JSONEncoder().encode(allPromptsToSync),
           let jsonString = String(data: data, encoding: .utf8) {
            store.set(jsonString, forKey: promptsKey)
        }

        // 選択中のプロンプトID
        if let selectedId = promptManager.selectedPromptId {
            store.set(selectedId.uuidString, forKey: selectedPromptKey)
        }

        // 最終同期日時
        let now = Date()
        store.set(now.timeIntervalSince1970, forKey: lastSyncKey)
        lastSyncDate = now

        synchronize()

        print("☁️ iCloudへアップロード完了: \(allPromptsToSync.count)件のプロンプト")

        isSyncing = false
    }

    // MARK: - iCloudからダウンロード
    func downloadFromiCloud() {
        guard AppSettings.shared.enableiCloudSync else { return }

        isSyncing = true
        syncError = nil

        // プロンプトを読み込み
        if let jsonString = store.string(forKey: promptsKey),
           let data = jsonString.data(using: .utf8),
           let syncedPrompts = try? JSONDecoder().decode([CustomPrompt].self, from: data) {

            let promptManager = CustomPromptManager.shared

            // ユーザー定義プロンプトをマージ
            for syncedPrompt in syncedPrompts {
                if syncedPrompt.isBuiltIn {
                    // カスタマイズされた組み込みプロンプト
                    if let index = promptManager.prompts.firstIndex(where: { $0.id == syncedPrompt.id }) {
                        // 日時が新しい方を採用
                        if syncedPrompt.updatedAt > promptManager.prompts[index].updatedAt {
                            promptManager.prompts[index] = syncedPrompt
                        }
                    }
                } else {
                    // ユーザー定義プロンプト
                    if let index = promptManager.prompts.firstIndex(where: { $0.id == syncedPrompt.id }) {
                        // 既存の場合は日時が新しい方を採用
                        if syncedPrompt.updatedAt > promptManager.prompts[index].updatedAt {
                            promptManager.prompts[index] = syncedPrompt
                        }
                    } else {
                        // 新規の場合は追加
                        promptManager.prompts.append(syncedPrompt)
                    }
                }
            }

            print("☁️ iCloudからダウンロード完了: \(syncedPrompts.count)件のプロンプト")
        }

        // 選択中のプロンプトID
        if let selectedIdString = store.string(forKey: selectedPromptKey),
           let selectedId = UUID(uuidString: selectedIdString) {
            CustomPromptManager.shared.selectPrompt(selectedId)
        }

        // 最終同期日時
        let timestamp = store.double(forKey: lastSyncKey)
        if timestamp > 0 {
            lastSyncDate = Date(timeIntervalSince1970: timestamp)
        }

        isSyncing = false
    }

    // MARK: - 同期ステータス
    var isAvailable: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    var statusDescription: String {
        if !isAvailable {
            return "iCloudにサインインしていません"
        }
        if isSyncing {
            return "同期中..."
        }
        if let error = syncError {
            return "エラー: \(error)"
        }
        if let date = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            return "最終同期: \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
        return "同期可能"
    }
}

// MARK: - CustomPromptManager拡張
extension CustomPromptManager {
    func syncToiCloud() {
        iCloudSyncManager.shared.uploadToiCloud()
    }
}
