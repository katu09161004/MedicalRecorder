//
// ContentView.swift
// AI Voice to Transcribe Recorder
//
// メイン画面のUI (iPhone)
// 録音ボタン、文字起こし結果の表示、GitHub連携、Apple Watch連携
//

import SwiftUI

struct MainView: View {
    @StateObject private var recorder = Recorder()
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var watchManager = WatchConnectivityManager.shared
    @ObservedObject private var promptManager = CustomPromptManager.shared

    @State private var showingResult = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // 処理モード選択（新しいカスタムプロンプトシステム対応）
    @State private var showingPromptSelector = false

    // 設定画面
    @State private var showingSettings = false

    // 音声インポート
    @State private var showingAudioImport = false
    @ObservedObject private var audioImporter = AudioImporter.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("AI Voice to Transcribe Recorder")
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("音声認識 & AI処理")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 使用中のAPIプロバイダー表示
                    HStack(spacing: 4) {
                        Image(systemName: AppSettings.shared.transcriptionProvider.icon)
                            .font(.caption2)
                        Text(AppSettings.shared.transcriptionProvider.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    
                    // 設定状態表示（デバッグ用）
                    HStack(spacing: 4) {
                        Image(systemName: AppSettings.shared.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(AppSettings.shared.isConfigured ? "設定完了" : "設定未完了")
                            .font(.caption2)
                    }
                    .foregroundColor(AppSettings.shared.isConfigured ? .green : .red)
                    
                    // Watch接続状態表示
                    if watchManager.isWatchConnected {
                        HStack(spacing: 4) {
                            Image(systemName: "applewatch")
                                .font(.caption2)
                            Text(watchManager.isWatchReachable ? "Watch 接続中" : "Watch 圏外")
                                .font(.caption2)
                        }
                        .foregroundColor(watchManager.isWatchReachable ? .green : .orange)
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // 録音時間表示
                if recorder.isRecording {
                    VStack(spacing: 12) {
                        Text("録音中")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(recorder.formattedRecordingTime())
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                        
                        // 録音中のアニメーション
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red)
                                    .frame(width: 4, height: CGFloat.random(in: 10...40))
                                    .animation(
                                        Animation.easeInOut(duration: 0.5)
                                            .repeatForever()
                                            .delay(Double(index) * 0.1),
                                        value: recorder.isRecording
                                    )
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(16)
                }
                
                // アップロード進捗
                if networkManager.isUploading {
                    VStack(spacing: 12) {
                        ProgressView("処理中...", value: networkManager.uploadProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        // 分割処理メッセージ表示
                        if !networkManager.processingMessage.isEmpty {
                            Text(networkManager.processingMessage)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                        
                        Text("さくらのAIで処理中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(networkManager.uploadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
                
                // 処理モード選択（新しいカスタムプロンプトシステム）
                if !recorder.isRecording && !networkManager.isUploading {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("処理モード", systemImage: "doc.text.fill")
                            .font(.headline)
                            .padding(.horizontal)

                        Button(action: { showingPromptSelector = true }) {
                            HStack {
                                if let selectedPrompt = promptManager.selectedPrompt {
                                    Image(systemName: selectedPrompt.icon)
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedPrompt.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(selectedPrompt.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Image(systemName: "questionmark.circle")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                        .frame(width: 30)

                                    Text("処理モードを選択")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
                
                // 録音ボタン
                Button(action: toggleRecording) {
                    HStack(spacing: 12) {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 24))
                        Text(recorder.isRecording ? "録音停止" : "録音開始")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(recorder.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(networkManager.isUploading)
                .padding(.horizontal)

                // 音声ファイルインポートボタン
                if !recorder.isRecording && !networkManager.isUploading {
                    Button(action: { showingAudioImport = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 20))
                            Text("音声ファイルをインポート")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // GitHubリンク
                if let githubURL = networkManager.githubURL {
                    VStack(spacing: 8) {
                        Link(destination: URL(string: githubURL)!) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("GitHubにアップロード完了")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Text("※ GitHubでの反映に数秒かかる場合があります")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // 結果表示ボタン
                if !networkManager.bulletPoints.isEmpty {
                    Button("文字起こし結果を表示") {
                        showingResult = true
                    }
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding()
                }
                
                Spacer()
                
                // 作成者名
                VStack(spacing: 4) {
                    Text("Developed by")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("KATSUYOSHI FUJITA")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .alert("エラー", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingResult) {
                ResultView(
                    bulletPoints: networkManager.bulletPoints,
                    transcribedText: networkManager.transcribedText
                )
            }
            .sheet(isPresented: $showingPromptSelector) {
                PromptListView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAudioImport) {
                NavigationView {
                    AudioImportView { importedURL in
                        // インポートした音声ファイルを処理
                        processImportedAudio(url: importedURL)
                    }
                    .navigationTitle("音声インポート")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("キャンセル") {
                                showingAudioImport = false
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            setupWatchConnectivity()
        }
        .onDisappear {
            // クリーンアップ：録音中なら停止
            if recorder.isRecording {
                _ = recorder.stopRecording()
            }
        }
    }
    
    // MARK: - 録音開始/停止の切り替え
    private func toggleRecording() {
        if recorder.isRecording {
            // 録音停止
            if let audioURL = recorder.stopRecording() {
                // Watch に録音停止通知
                watchManager.sendRecordingStatus(isRecording: false)
                
                // 設定チェック
                guard AppSettings.shared.isConfigured else {
                    let provider = AppSettings.shared.transcriptionProvider.displayName
                    let aquaKey = !AppSettings.shared.aquaVoiceAPIKey.isEmpty
                    let sakuraToken = !AppSettings.shared.sakuraTokenID.isEmpty
                    let sakuraSecret = !AppSettings.shared.sakuraSecret.isEmpty
                    let github = !AppSettings.shared.githubToken.isEmpty
                    
                    var missingItems: [String] = []
                    if AppSettings.shared.transcriptionProvider == .aquaVoice && !aquaKey {
                        missingItems.append("• Aqua Voice APIキー")
                    }
                    if !sakuraToken { missingItems.append("• さくらTokenID") }
                    if !sakuraSecret { missingItems.append("• さくらSecret") }
                    if !github { missingItems.append("• GitHubトークン") }
                    
                    alertMessage = """
                    【\(provider)】設定未完了
                    
                    不足している設定:
                    \(missingItems.joined(separator: "\n"))
                    
                    設定画面（⚙️）で入力してください
                    """
                    showingAlert = true
                    watchManager.sendCompletion(success: false, message: "設定未完了")
                    return
                }
                
                // サーバーにアップロード（新しいカスタムプロンプトシステム使用）
                let systemPrompt = promptManager.selectedPrompt?.systemPrompt ?? ""
                networkManager.uploadAndTranscribeWithPrompt(
                    audioURL: audioURL,
                    systemPrompt: systemPrompt
                ) { success in
                    if success {
                        showingResult = true
                        // Watch に成功通知
                        watchManager.sendCompletion(success: true, message: "処理完了")
                    } else if let error = networkManager.errorMessage {
                        alertMessage = error
                        showingAlert = true
                        // Watch にエラー通知
                        watchManager.sendCompletion(success: false, message: "処理失敗")
                    }
                }
            }
        } else {
            // 録音開始
            do {
                try recorder.startRecording()
                // Watch に録音開始通知
                watchManager.sendRecordingStatus(isRecording: true)
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    // MARK: - インポートした音声を処理
    private func processImportedAudio(url: URL) {
        showingAudioImport = false

        // 設定チェック
        guard AppSettings.shared.isConfigured else {
            alertMessage = "設定が完了していません。設定画面で必要な情報を入力してください。"
            showingAlert = true
            return
        }

        // サーバーにアップロード
        let systemPrompt = promptManager.selectedPrompt?.systemPrompt ?? ""
        networkManager.uploadAndTranscribeWithPrompt(
            audioURL: url,
            systemPrompt: systemPrompt
        ) { success in
            if success {
                showingResult = true
            } else if let error = networkManager.errorMessage {
                alertMessage = error
                showingAlert = true
            }
        }
    }

    // MARK: - Watch Connectivity セットアップ
    private func setupWatchConnectivity() {
        // Watch からの録音開始リクエスト
        watchManager.onStartRecording = { [recorder, watchManager] in
            if !recorder.isRecording {
                do {
                    try recorder.startRecording()
                    watchManager.sendRecordingStatus(isRecording: true)
                    print("✅ Watch からの録音開始リクエスト処理完了")
                } catch {
                    print("❌ 録音開始エラー: \(error)")
                    watchManager.sendCompletion(success: false, message: "録音開始失敗")
                }
            }
        }
        
        // Watch からの録音停止リクエスト
        watchManager.onStopRecording = { [recorder, networkManager, watchManager, promptManager] in
            if recorder.isRecording {
                if let audioURL = recorder.stopRecording() {
                    watchManager.sendRecordingStatus(isRecording: false)

                    // 設定チェック
                    guard AppSettings.shared.isConfigured else {
                        watchManager.sendCompletion(success: false, message: "設定未完了")
                        return
                    }

                    print("✅ Watch からの録音停止リクエスト処理完了")

                    // 進捗通知を送信
                    watchManager.sendProgress(progress: 0.1, message: "文字起こし中...")

                    // アップロード & 処理（選択中のプロンプトを使用）
                    let systemPrompt = promptManager.selectedPrompt?.systemPrompt ?? ""
                    networkManager.uploadAndTranscribeWithPrompt(
                        audioURL: audioURL,
                        systemPrompt: systemPrompt
                    ) { success in
                        // 完了通知を送信（成功/失敗両方）
                        if success {
                            print("✅ Watch 経由の録音処理成功")
                            watchManager.sendCompletion(success: true, message: "処理完了")
                        } else {
                            print("❌ Watch 経由の録音処理失敗")
                            let errorMsg = networkManager.errorMessage ?? "不明なエラー"
                            watchManager.sendCompletion(success: false, message: errorMsg)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 結果表示画面
struct ResultView: View {
    let bulletPoints: String
    let transcribedText: String
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false

    // 共有用のテキストを生成
    private var shareText: String {
        """
        【処理結果】
        \(bulletPoints)

        【元のテキスト】
        \(transcribedText)
        """
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 箇条書き部分
                    VStack(alignment: .leading, spacing: 12) {
                        Label("処理結果", systemImage: "list.bullet")
                            .font(.headline)

                        Text(bulletPoints)
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Divider()

                    // 元のテキスト
                    VStack(alignment: .leading, spacing: 12) {
                        Label("元のテキスト", systemImage: "text.alignleft")
                            .font(.headline)

                        Text(transcribedText)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("文字起こし結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }
}

// MARK: - 共有シート
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - プレビュー
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

