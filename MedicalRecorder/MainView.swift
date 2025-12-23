//
// ContentView.swift
// AI Voice to Transcribe Recorder
//
// メイン画面のUI (iPhone)
// 録音ボタン、文字起こし結果の表示、GitHub連携、Apple Watch連携
//

import SwiftUI
import MessageUI

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

    // 録音ファイル一覧
    @State private var showingRecordingsList = false
    @State private var recordingFiles: [URL] = []

    // メール送信
    @StateObject private var mailManager = MailManager.shared
    @State private var showingMailComposer = false
    
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

                // 音声ファイルインポートボタン & 録音一覧ボタン
                if !recorder.isRecording && !networkManager.isUploading {
                    HStack(spacing: 12) {
                        Button(action: { showingAudioImport = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 18))
                                Text("インポート")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }

                        Button(action: {
                            loadRecordingFiles()
                            showingRecordingsList = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 18))
                                Text("録音一覧")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
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
            .sheet(isPresented: $showingRecordingsList) {
                RecordingsListView(
                    recordingFiles: $recordingFiles,
                    onSendMail: { url in
                        sendMail(audioURL: url)
                    },
                    onDelete: { url in
                        deleteRecording(url: url)
                    }
                )
            }
            .sheet(isPresented: $showingMailComposer) {
                if mailManager.canSendMail {
                    MailComposerView(mailManager: mailManager) {
                        showingMailComposer = false
                    }
                }
            }
            .alert("メールエラー", isPresented: .init(
                get: { mailManager.mailError != nil },
                set: { if !$0 { mailManager.mailError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(mailManager.mailError ?? "")
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
    
    // MARK: - 録音ファイル一覧の読み込み
    private func loadRecordingFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            recordingFiles = files.filter { $0.pathExtension.lowercased() == "m4a" || $0.pathExtension.lowercased() == "wav" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            print("録音ファイルの読み込みエラー: \(error)")
            recordingFiles = []
        }
    }

    // MARK: - メール送信
    private func sendMail(audioURL: URL) {
        showingRecordingsList = false
        if mailManager.canSendMail {
            mailManager.prepareToSendMail(audioURL: audioURL)
            showingMailComposer = true
        } else {
            alertMessage = "メールアカウントが設定されていません。設定アプリでメールを設定してください。"
            showingAlert = true
        }
    }

    // MARK: - 録音ファイルの削除
    private func deleteRecording(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadRecordingFiles()
        } catch {
            print("ファイル削除エラー: \(error)")
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

// MARK: - 録音ファイル一覧ビュー
struct RecordingsListView: View {
    @Binding var recordingFiles: [URL]
    var onSendMail: (URL) -> Void
    var onDelete: (URL) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Group {
                if recordingFiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("録音ファイルがありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(recordingFiles, id: \.self) { url in
                            RecordingFileRow(url: url, onSendMail: onSendMail)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                onDelete(recordingFiles[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("録音ファイル一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - 録音ファイル行
struct RecordingFileRow: View {
    let url: URL
    var onSendMail: (URL) -> Void

    private var fileName: String {
        url.deletingPathExtension().lastPathComponent
    }

    private var fileSize: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return "不明"
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private var creationDate: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attributes[.creationDate] as? Date else {
            return "不明"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private var duration: String {
        guard let seconds = Recorder.getAudioDuration(url: url) else {
            return "不明"
        }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label(duration, systemImage: "clock")
                    Label(fileSize, systemImage: "doc")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                Text(creationDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { onSendMail(url) }) {
                Image(systemName: "envelope")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - プレビュー
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

