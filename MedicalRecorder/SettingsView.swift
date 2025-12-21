//
// SettingsView.swift
// MedicalRecorder
//
// アプリケーション設定画面
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var promptManager = CustomPromptManager.shared
    @ObservedObject var iCloudSync = iCloudSyncManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var showingSaveAlert = false
    @State private var showingResetAlert = false
    @State private var showingPromptList = false

    // アプリバージョン情報
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationView {
            Form {
                // 処理モード（プロンプト）設定
                Section(header: Text("AI処理モード")) {
                    Button(action: { showingPromptList = true }) {
                        HStack {
                            if let selected = promptManager.selectedPrompt {
                                Image(systemName: selected.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.name)
                                        .foregroundColor(.primary)
                                    Text(selected.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("処理モードを選択")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("文字起こし後のAI処理方法を設定します。カスタムプロンプトの追加も可能です。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // ローカルLLM設定
                Section(header: Text("オフライン処理")) {
                    Toggle(isOn: $settings.useLocalLLM) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ローカルLLMを使用")
                                .font(.body)
                            Text("オフラインでAI処理を実行（機能制限あり）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if settings.useLocalLLM {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("ローカル処理ではシンプルな要約・整形のみ対応します")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 言語設定
                Section(header: Text("言語設定")) {
                    Picker("文字起こし言語", selection: $settings.transcriptionLanguage) {
                        ForEach(AppSettings.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("音声認識の対象言語を設定します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // API プロバイダー選択
                Section(header: Text("文字起こしAPI")) {
                    Picker("APIプロバイダー", selection: $settings.transcriptionProvider) {
                        ForEach(TranscriptionProvider.allCases) { provider in
                            HStack {
                                Image(systemName: provider.icon)
                                Text(provider.displayName)
                            }
                            .tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(settings.transcriptionProvider.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // さくらのAI API設定
                if settings.transcriptionProvider == .sakura && !settings.useLocalLLM {
                    Section(header: Text("さくらのAI API")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("トークンID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            TextField("例: 2d25ae00-57a9-...", text: $settings.sakuraTokenID)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.system(.body, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("シークレットキー")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            SecureField("例: KMFTq/MVZyd...", text: $settings.sakuraSecret)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("認証情報はKeychainで安全に保存されます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Link(destination: URL(string: "https://ai.sakura.ad.jp/")!) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                Text("さくらのAI ダッシュボード")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }
                }

                // Aqua Voice API設定
                if settings.transcriptionProvider == .aquaVoice {
                    Section(header: Text("Aqua Voice API")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APIキー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("Aqua Voice API Key", text: $settings.aquaVoiceAPIKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.system(.body, design: .monospaced))
                        }

                        Link(destination: URL(string: "https://aqua-voice.com/")!) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                Text("Aqua Voice ダッシュボード")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }

                    // Aqua Voice使用時もLLM処理のためさくらのAI設定が必要
                    if !settings.useLocalLLM {
                        Section(header: Text("さくらのAI API（LLM処理用）")) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("⚠️ AI要約処理にさくらのAIを使用します")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("文字起こしはAqua Voice、要約・箇条書きはさくらのAIで行います")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("トークンID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("例: 2d25ae00-57a9-...", text: $settings.sakuraTokenID)
                                    .textContentType(.password)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(.system(.body, design: .monospaced))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("シークレットキー")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("例: KMFTq/MVZyd...", text: $settings.sakuraSecret)
                                    .textContentType(.password)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }

                // AmiVoice API設定
                if settings.transcriptionProvider == .amiVoice {
                    Section(header: Text("AmiVoice Cloud API")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APIキー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("AmiVoice API Key", text: $settings.amiVoiceAPIKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.system(.body, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("エンジン")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("エンジン", selection: $settings.amiVoiceEngine) {
                                Text("-a-general（汎用）").tag("-a-general")
                                Text("-a-medical（医療）").tag("-a-medical")
                                Text("-a-business（ビジネス）").tag("-a-business")
                                Text("-a-call（コールセンター）").tag("-a-call")
                            }
                            .pickerStyle(.menu)
                        }

                        Link(destination: URL(string: "https://acp.amivoice.com/")!) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                Text("AmiVoice Cloud ダッシュボード")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }

                    // AmiVoice使用時もLLM処理のためさくらのAI設定が必要
                    if !settings.useLocalLLM {
                        Section(header: Text("さくらのAI API（LLM処理用）")) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("⚠️ AI要約処理にさくらのAIを使用します")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("文字起こしはAmiVoice、要約・箇条書きはさくらのAIで行います")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("トークンID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("例: 2d25ae00-57a9-...", text: $settings.sakuraTokenID)
                                    .textContentType(.password)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(.system(.body, design: .monospaced))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("シークレットキー")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("例: KMFTq/MVZyd...", text: $settings.sakuraSecret)
                                    .textContentType(.password)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }

                // GitHub設定
                Section(header: Text("GitHub連携")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Personal Access Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "lock.shield")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        SecureField("ghp_xxxxxxxxxxxx", text: $settings.githubToken)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                    }

                    TextField("オーナー名", text: $settings.githubOwner)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("リポジトリ名", text: $settings.githubRepo)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("ブランチ", text: $settings.githubBranch)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("保存パス", text: $settings.githubPath)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Link(destination: URL(string: "https://github.com/settings/tokens")!) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("GitHub トークン作成")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }

                // 録音設定
                Section(header: Text("録音設定")) {
                    Toggle(isOn: $settings.enableBackgroundRecording) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("バックグラウンド録音")
                                .font(.body)
                            Text("アプリがバックグラウンドでも録音を継続")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if settings.enableBackgroundRecording {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Info.plistにUIBackgroundModesの設定が必要です")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 保存オプション
                Section(header: Text("保存設定")) {
                    Toggle(isOn: $settings.saveRawTranscription) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("文字起こし生データを保存")
                                .font(.body)
                            Text("Whisperの出力そのまま (処理前)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $settings.saveAudioFile) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("音声ファイルを保存")
                                .font(.body)
                            Text("録音したm4aファイル (.m4a)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // iCloud同期
                Section(header: Text("iCloud同期")) {
                    Toggle(isOn: $settings.enableiCloudSync) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud同期を有効化")
                                .font(.body)
                            Text("プロンプト設定を他のデバイスと共有")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if settings.enableiCloudSync {
                        HStack {
                            if iCloudSync.isAvailable {
                                Image(systemName: "checkmark.icloud")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "xmark.icloud")
                                    .foregroundColor(.red)
                            }
                            Text(iCloudSync.statusDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            iCloudSync.uploadToiCloud()
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.icloud")
                                Text("今すぐ同期")
                            }
                        }
                        .disabled(!iCloudSync.isAvailable || iCloudSync.isSyncing)
                    }
                }

                // 情報・アクション
                Section {
                    Button(action: { showingSaveAlert = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("設定を保存")
                            Spacer()
                        }
                    }

                    Button(action: { showingResetAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundColor(.orange)
                            Text("設定をリセット")
                            Spacer()
                        }
                    }
                }

                // ステータス表示
                Section(header: Text("ステータス")) {
                    HStack {
                        Text("設定状態")
                        Spacer()
                        if settings.isConfigured {
                            Label("完了", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("未完了", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    HStack {
                        Text("セキュリティ")
                        Spacer()
                        Label("Keychain使用", systemImage: "lock.shield.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                // アプリ情報
                Section(header: Text("アプリ情報")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("ビルド")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .alert("設定を保存しました", isPresented: $showingSaveAlert) {
                Button("OK") { }
            }
            .alert("設定をリセットしますか?", isPresented: $showingResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("リセット", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
            .sheet(isPresented: $showingPromptList) {
                PromptListView()
            }
        }
    }
}
