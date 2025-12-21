//
// NetworkManager.swift
// MedicalRecorder
//
// さくらのAI APIに直接接続 + GitHub連携 (設定値使用)
// 文字起こし生データ保存、音声ファイル保存対応
//

import Foundation
import Combine
import AVFoundation
import UIKit

class NetworkManager: ObservableObject {
    // 処理状態の公開プロパティ
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var transcribedText: String = ""
    @Published var bulletPoints: String = ""
    @Published var errorMessage: String?
    @Published var githubURL: String?
    @Published var processingMessage: String = "" // 処理メッセージ（分割情報など）
    
    // 設定インスタンス
    private let settings = AppSettings.shared
    
    // さくらのAI APIエンドポイント
    private let WHISPER_API_URL = "https://api.ai.sakura.ad.jp/v1/audio/transcriptions"
    private let CHAT_API_URL = "https://api.ai.sakura.ad.jp/v1/chat/completions"
    
    // Basic認証用のヘッダーを生成 (設定値から取得)
    private func getBasicAuthHeader() -> String {
        let authString = "\(settings.sakuraTokenID):\(settings.sakuraSecret)"
        let authData = authString.data(using: .utf8)!
        let authB64 = authData.base64EncodedString()
        return "Basic \(authB64)"
    }
    
    // MARK: - 新しいカスタムプロンプト対応メイン処理関数
    func uploadAndTranscribeWithPrompt(audioURL: URL, systemPrompt: String, completion: @escaping (Bool) -> Void) {
        // 内部的には従来のメソッドを呼び出す（カスタムプロンプトモードとして）
        uploadAndTranscribe(audioURL: audioURL, mode: .customPrompt, customPrompt: systemPrompt, completion: completion)
    }

    // MARK: - メイン処理関数 (モード対応 + 生データ保存 + 分割対応 + プロバイダー選択)
    func uploadAndTranscribe(audioURL: URL, mode: ProcessingMode, customPrompt: String = "", completion: @escaping (Bool) -> Void) {
        // 設定チェック
        guard settings.isConfigured else {
            print("❌ 設定未完了")
            print("  - プロバイダー: \(settings.transcriptionProvider.displayName)")
            print("  - さくらTokenID: \(settings.sakuraTokenID.isEmpty ? "未設定" : "設定済み")")
            print("  - さくらSecret: \(settings.sakuraSecret.isEmpty ? "未設定" : "設定済み")")
            print("  - AquaVoiceKey: \(settings.aquaVoiceAPIKey.isEmpty ? "未設定" : "設定済み")")
            print("  - AmiVoiceKey: \(settings.amiVoiceAPIKey.isEmpty ? "未設定" : "設定済み")")
            print("  - GitHubToken: \(settings.githubToken.isEmpty ? "未設定" : "設定済み")")
            
            DispatchQueue.main.async {
                self.errorMessage = "設定が未完了です。設定画面でAPIキーとトークンを入力してください。"
            }
            completion(false)
            return
        }
        
        DispatchQueue.main.async {
            // 処理中は自動ロックを無効化
            UIApplication.shared.isIdleTimerDisabled = true
            
            self.isUploading = true
            self.uploadProgress = 0.0
            self.errorMessage = nil
            self.transcribedText = ""
            self.bulletPoints = ""
            self.githubURL = nil
            self.processingMessage = ""
        }
        
        print("🎤 音声処理開始: \(audioURL.lastPathComponent)")
        print("📝 処理モード: \(mode.rawValue)")
        print("🔧 APIプロバイダー: \(settings.transcriptionProvider.displayName)")
        print("✅ 設定確認済み")
        
        // 音声の長さとファイルサイズをチェック
        if let duration = Recorder.getAudioDuration(url: audioURL) {
            print("⏱️ 録音時間: \(Int(duration))秒 (\(Int(duration/60))分)")

            // ファイルサイズをチェック
            var fileSize: Int64 = 0
            if let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path) {
                fileSize = attributes[.size] as? Int64 ?? 0
                print("📁 ファイルサイズ: \(fileSize / 1024 / 1024)MB (\(fileSize)バイト)")
            }

            // プロバイダーの制限を確認
            let maxDuration = settings.transcriptionProvider.maxDuration
            let maxFileSize = settings.transcriptionProvider.maxFileSize

            // 制限を超える場合は分割処理（プロバイダーが分割必要な場合のみ）
            let needsDurationSplit = duration > maxDuration
            let needsSizeSplit = fileSize > maxFileSize

            if (needsDurationSplit || needsSizeSplit) && settings.transcriptionProvider.needsSplitting {
                if needsDurationSplit && needsSizeSplit {
                    print("⚠️ 時間(\(Int(maxDuration/60))分)とサイズ(\(maxFileSize / 1024 / 1024)MB)の両制限を超えているため分割処理を開始します")
                } else if needsDurationSplit {
                    print("⚠️ \(Int(maxDuration/60))分を超えているため分割処理を開始します")
                } else {
                    print("⚠️ \(maxFileSize / 1024 / 1024)MBを超えているため分割処理を開始します")
                }
                handleLongAudio(audioURL: audioURL, mode: mode, customPrompt: customPrompt, completion: completion)
                return
            }
        }
        
        // 通常処理（制限時間以内）
        processAudio(audioURL: audioURL, mode: mode, customPrompt: customPrompt, cleanup: false, completion: completion)
    }
    
    // MARK: - 長時間音声の分割処理
    private func handleLongAudio(audioURL: URL, mode: ProcessingMode, customPrompt: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // 分割基準を作成（時間とファイルサイズの両方を考慮）
                let criteria = AudioSplitter.SplitCriteria(
                    maxDuration: settings.transcriptionProvider.maxDuration * 0.95,  // 5%のマージン
                    maxFileSize: Int64(Double(settings.transcriptionProvider.maxFileSize) * 0.93)  // 7%のマージン
                )

                await MainActor.run {
                    self.processingMessage = "音声ファイルを分割しています..."
                }

                // 時間とファイルサイズの両方を考慮して分割
                let splitURLs = try await AudioSplitter.splitAudioWithCriteria(sourceURL: audioURL, criteria: criteria)

                print("✅ 音声を\(splitURLs.count)個に分割しました")

                await MainActor.run {
                    self.uploadProgress = 0.1
                    self.processingMessage = "\(splitURLs.count)個に分割完了"
                }

                // 各セグメントを順次処理（タイムアウト付き）
                var allTranscriptions: [String] = []
                let progressPerSegment = 0.8 / Double(splitURLs.count) // 0.1〜0.9の範囲
                let maxRetries = 2 // セグメントごとの最大リトライ回数

                for (index, segmentURL) in splitURLs.enumerated() {
                    print("📤 セグメント \(index + 1)/\(splitURLs.count) を処理中...")

                    await MainActor.run {
                        self.uploadProgress = 0.1 + (Double(index) * progressPerSegment)
                        self.processingMessage = "セグメント \(index + 1)/\(splitURLs.count) を文字起こし中..."
                    }

                    // リトライ機能付きで文字起こし
                    var segmentText = ""
                    var segmentSuccess = false

                    for retryCount in 0...maxRetries {
                        if retryCount > 0 {
                            print("🔄 セグメント \(index + 1) リトライ \(retryCount)/\(maxRetries)")
                            await MainActor.run {
                                self.processingMessage = "セグメント \(index + 1)/\(splitURLs.count) リトライ中..."
                            }
                        }

                        // タイムアウト付きで文字起こし（5分）
                        let result = await withTaskTimeoutResult(seconds: 300) {
                            await withCheckedContinuation { continuation in
                                self.transcribeAudio(audioURL: segmentURL) { success, text in
                                    continuation.resume(returning: (success, text))
                                }
                            }
                        }

                        if let (success, text) = result {
                            segmentSuccess = success
                            segmentText = text
                            if success {
                                break // 成功したらリトライループを抜ける
                            }
                        } else {
                            print("⏱️ セグメント \(index + 1) タイムアウト")
                        }
                    }

                    if segmentSuccess {
                        allTranscriptions.append(segmentText)
                        print("✅ セグメント \(index + 1) 文字起こし完了: \(segmentText.prefix(50))...")
                    } else {
                        print("❌ セグメント \(index + 1) 文字起こし失敗（リトライ後）")

                        // 失敗しても音声ファイルは保存する
                        if settings.saveAudioFile {
                            await MainActor.run {
                                self.processingMessage = "文字起こし失敗 - 音声ファイルを保存中..."
                            }
                            await saveAudioFileOnly(audioURL: audioURL, mode: mode)
                        }

                        await MainActor.run {
                            UIApplication.shared.isIdleTimerDisabled = false
                            self.isUploading = false
                            self.processingMessage = ""
                            self.errorMessage = "セグメント \(index + 1) の文字起こしに失敗しました。音声ファイルは保存されました。"
                        }
                        AudioSplitter.cleanupSplitFiles(splitURLs)
                        completion(false)
                        return
                    }
                }

                // 全ての文字起こし結果を結合
                let combinedText = allTranscriptions.joined(separator: "\n\n")

                await MainActor.run {
                    self.transcribedText = combinedText
                    self.uploadProgress = 0.9
                    self.processingMessage = "文字起こし完了 - AI処理中..."
                }

                print("✅ 全セグメントの文字起こし完了")
                print("📝 結合後の文字数: \(combinedText.count)")

                // 分割ファイルをクリーンアップ
                AudioSplitter.cleanupSplitFiles(splitURLs)

                // LLM処理へ進む（元のURLを使用）
                processWithLLM(text: combinedText, mode: mode, customPrompt: customPrompt, audioURL: audioURL, completion: completion)

            } catch {
                print("❌ 音声分割エラー: \(error.localizedDescription)")

                // エラー時も音声ファイルは保存する
                if settings.saveAudioFile {
                    await MainActor.run {
                        self.processingMessage = "分割エラー - 音声ファイルを保存中..."
                    }
                    await saveAudioFileOnly(audioURL: audioURL, mode: mode)
                }

                await MainActor.run {
                    UIApplication.shared.isIdleTimerDisabled = false
                    self.isUploading = false
                    self.processingMessage = ""
                    self.errorMessage = "音声の分割処理に失敗しました: \(error.localizedDescription)\n音声ファイルは保存されました。"
                }
                completion(false)
            }
        }
    }

    // MARK: - タイムアウト付きタスク実行
    private func withTaskTimeoutResult<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            group.addTask {
                return await operation()
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }

            // 最初に完了したものを返す
            if let result = await group.next() {
                group.cancelAll()
                return result
            }
            return nil
        }
    }

    // MARK: - 音声ファイルのみを保存（文字起こし失敗時）
    private func saveAudioFileOnly(audioURL: URL, mode: ProcessingMode) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let timestamp = dateFormatter.string(from: Date())

        await withCheckedContinuation { continuation in
            uploadAudioFile(audioURL: audioURL, timestamp: timestamp, mode: mode) { _ in
                continuation.resume()
            }
        }
    }
    
    // MARK: - 通常の音声処理
    private func processAudio(audioURL: URL, mode: ProcessingMode, customPrompt: String, cleanup: Bool, completion: @escaping (Bool) -> Void) {
        // ステップ1: Whisper APIで文字起こし
        transcribeAudio(audioURL: audioURL) { [weak self] success, text in
            guard let self = self else { return }

            if !success {
                // 文字起こし失敗時も音声ファイルは保存する
                if self.settings.saveAudioFile {
                    DispatchQueue.main.async {
                        self.processingMessage = "文字起こし失敗 - 音声ファイルを保存中..."
                    }
                    Task {
                        await self.saveAudioFileOnly(audioURL: audioURL, mode: mode)
                        await MainActor.run {
                            UIApplication.shared.isIdleTimerDisabled = false
                            self.isUploading = false
                            self.processingMessage = ""
                            self.errorMessage = "文字起こしに失敗しました。音声ファイルは保存されました。"
                        }
                        completion(false)
                    }
                } else {
                    DispatchQueue.main.async {
                        UIApplication.shared.isIdleTimerDisabled = false
                        self.isUploading = false
                        self.processingMessage = ""
                        self.errorMessage = "文字起こしに失敗しました"
                    }
                    completion(false)
                }
                return
            }

            DispatchQueue.main.async {
                self.transcribedText = text
                self.uploadProgress = 0.25
            }

            print("✅ 文字起こし成功: \(text.prefix(50))...")

            // ステップ2: 生データをGitHubに保存 (オプション)
            if self.settings.saveRawTranscription {
                self.uploadRawTranscription(text: text, mode: mode, audioURL: audioURL) { _ in
                    // 成否に関わらず次へ進む
                    DispatchQueue.main.async {
                        self.uploadProgress = 0.40
                    }
                    self.processWithLLM(text: text, mode: mode, customPrompt: customPrompt, audioURL: audioURL, completion: completion)
                }
            } else {
                self.processWithLLM(text: text, mode: mode, customPrompt: customPrompt, audioURL: audioURL, completion: completion)
            }
        }
    }
    
    // MARK: - LLM処理 + メイン結果アップロード
    private func processWithLLM(text: String, mode: ProcessingMode, customPrompt: String, audioURL: URL, completion: @escaping (Bool) -> Void) {
        // ステップ3: LLM APIで処理 (モード対応)
        let prompt = mode == .customPrompt ? customPrompt : mode.systemPrompt
        self.summarizeToBulletPoints(text: text, systemPrompt: prompt) { success in
            if !success {
                DispatchQueue.main.async {
                    // 処理完了 - 自動ロックを再度有効化
                    UIApplication.shared.isIdleTimerDisabled = false
                    self.isUploading = false
                    self.processingMessage = ""
                }
                completion(false)
                return
            }
            
            DispatchQueue.main.async {
                self.uploadProgress = 0.70
            }
            
            // ステップ4: 処理結果をGitHubへアップロード
            self.uploadProcessedResult(mode: mode, audioURL: audioURL) { githubSuccess in
                DispatchQueue.main.async {
                    // 処理完了 - 自動ロックを再度有効化
                    UIApplication.shared.isIdleTimerDisabled = false
                    self.isUploading = false
                    self.uploadProgress = 1.0
                    self.processingMessage = "" // 処理完了時にクリア
                }
                completion(githubSuccess)
            }
        }
    }
    
    // MARK: - 音声ファイルを文字起こし（プロバイダー自動選択）
    private func transcribeAudio(audioURL: URL, completion: @escaping (Bool, String) -> Void) {
        print("🔀 プロバイダー選択: \(settings.transcriptionProvider.displayName)")
        
        switch settings.transcriptionProvider {
        case .sakura:
            print("➡️ さくらのAI を使用")
            transcribeWithSakura(audioURL: audioURL, completion: completion)
        case .aquaVoice:
            print("➡️ Aqua Voice を使用")
            transcribeWithAquaVoice(audioURL: audioURL, completion: completion)
        case .amiVoice:
            print("➡️ AmiVoice Cloud を使用")
            transcribeWithAmiVoice(audioURL: audioURL, completion: completion)
        }
    }
    
    // MARK: - さくらのAI Whisper API
    private func transcribeWithSakura(audioURL: URL, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: WHISPER_API_URL) else {
            print("❌ URL生成失敗")
            completion(false, "")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300 // 5分
        
        // マルチパートフォームデータ
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(getBasicAuthHeader(), forHTTPHeaderField: "Authorization")
        
        print("🔐 Basic認証ヘッダー設定完了")
        
        var data = Data()
        
        // model パラメータ (元のコードと同じ)
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-large-v3-turbo\r\n".data(using: .utf8)!)  // ✅ 正しいモデル名
        
        // 音声ファイル
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            data.append(audioData)
            print("📁 音声ファイルサイズ: \(audioData.count / 1024)KB")
        } catch {
            print("❌ 音声ファイル読み込みエラー: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "音声ファイルの読み込みに失敗: \(error.localizedDescription)"
            }
            completion(false, "")
            return
        }
        
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        print("📤 Whisper APIへリクエスト送信開始...")
        
        let task = URLSession.shared.uploadTask(with: request, from: data) { [weak self] responseData, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ アップロードエラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "アップロードエラー: \(error.localizedDescription)"
                }
                completion(false, "")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス")
                DispatchQueue.main.async {
                    self.errorMessage = "無効なレスポンス"
                }
                completion(false, "")
                return
            }
            
            print("📊 Whisper APIレスポンスステータス: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Whisper APIエラー: \(httpResponse.statusCode)")
                if let responseData = responseData, let errorText = String( data: responseData, encoding: .utf8) {
                    print("❌ エラー詳細: \(errorText)")
                }
                DispatchQueue.main.async {
                    self.errorMessage = "APIエラー: \(httpResponse.statusCode)"
                }
                completion(false, "")
                return
            }
            
            guard let responseData = responseData else {
                print("❌ レスポンスデータなし")
                DispatchQueue.main.async {
                    self.errorMessage = "レスポンスデータなし"
                }
                completion(false, "")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
                let text = json?["text"] as? String ?? ""
                print("✅ 文字起こし完了: \(text.count)文字")
                completion(true, text)
            } catch {
                print("❌ JSONパースエラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "JSONパースエラー: \(error.localizedDescription)"
                }
                completion(false, "")
            }
        }
        
        task.resume()
    }
    
    // MARK: - Aqua Voice API
    private func transcribeWithAquaVoice(audioURL: URL, completion: @escaping (Bool, String) -> Void) {
        print("🎯 Aqua Voice API 呼び出し開始")
        print("🔑 APIキー: \(settings.aquaVoiceAPIKey.prefix(10))...")
        
        let aquaAPI = AquaVoiceAPI(apiKey: settings.aquaVoiceAPIKey)
        aquaAPI.transcribeAudio(audioURL: audioURL) { [weak self] success, text in
            guard let self = self else { return }
            
            print("🎯 Aqua Voice API コールバック: success=\(success), text=\(text.prefix(50))")
            
            if !success {
                DispatchQueue.main.async {
                    self.errorMessage = "Aqua Voice API で文字起こしに失敗しました。コンソールログを確認してください。"
                }
            }
            
            completion(success, text)
        }
    }
    
    // MARK: - AmiVoice Cloud API
    private func transcribeWithAmiVoice(audioURL: URL, completion: @escaping (Bool, String) -> Void) {
        print("🎙️ AmiVoice Cloud API 呼び出し開始")
        print("🔑 APIキー: \(settings.amiVoiceAPIKey.prefix(10))...")
        print("⚙️ エンジン: \(settings.amiVoiceEngine)")
        
        Task { @MainActor in
            // エンジン設定に応じた設定を作成
            let config: AmiVoiceConfig
            if settings.amiVoiceEngine.contains("medical") {
                config = AmiVoiceConfig.medical(apiKey: settings.amiVoiceAPIKey)
            } else {
                // カスタムエンジン名を使用
                config = AmiVoiceConfig(
                    apiKey: settings.amiVoiceAPIKey,
                    engineName: settings.amiVoiceEngine,
                    endpoint: "https://acp-api.amivoice.com/v1/recognize",
                    timeout: 60.0,
                    sampleRate: 16000  // デフォルトは16kHz
                )
            }
            
            let client = AmiVoiceClient(config: config)
            
            do {
                let text = try await client.transcribe(audioURL: audioURL)
                print("✅ AmiVoice 文字起こし完了: \(text.count)文字")
                print("📝 内容（最初の100文字）: \(text.prefix(100))...")
                completion(true, text)
            } catch let error as AmiVoiceError {
                print("❌ AmiVoice エラー: \(error.localizedDescription)")
                self.errorMessage = "AmiVoice API で文字起こしに失敗しました: \(error.localizedDescription)"
                completion(false, "")
            } catch {
                print("❌ AmiVoice 予期しないエラー: \(error.localizedDescription)")
                self.errorMessage = "AmiVoice API で文字起こしに失敗しました: \(error.localizedDescription)"
                completion(false, "")
            }
        }
    }
    
    // MARK: - LLM API: テキストを箇条書きに変換（常にさくらのAI使用）
    private func summarizeToBulletPoints(text: String, systemPrompt: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: CHAT_API_URL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(getBasicAuthHeader(), forHTTPHeaderField: "Authorization")
        
        print("📝 LLM APIへリクエスト送信中...")
        
        let requestBody: [String: Any] = [
            "model": "gpt-oss-120b",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 2000,
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("❌ リクエスト作成エラー: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "リクエスト作成エラー: \(error.localizedDescription)"
            }
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 要約エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "要約エラー: \(error.localizedDescription)"
                }
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 要約レスポンス無効")
                DispatchQueue.main.async {
                    self.errorMessage = "要約レスポンス無効"
                }
                completion(false)
                return
            }
            
            print("📊 LLM APIレスポンスステータス: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ 要約APIエラー: \(httpResponse.statusCode)")
                if let responseData = responseData, let errorText = String( data: responseData, encoding: .utf8) {
                    print("❌ エラー詳細: \(errorText)")
                }
                DispatchQueue.main.async {
                    self.errorMessage = "要約APIエラー: \(httpResponse.statusCode)"
                }
                completion(false)
                return
            }
            
            guard let responseData = responseData else {
                print("❌ 要約レスポンスデータなし")
                DispatchQueue.main.async {
                    self.errorMessage = "要約レスポンスデータなし"
                }
                completion(false)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
                let choices = json?["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: Any]
                let content = message?["content"] as? String ?? ""
                
                print("✅ 箇条書き化完了: \(content.count)文字")
                
                DispatchQueue.main.async {
                    self.bulletPoints = content
                }
                completion(true)
            } catch {
                print("❌ 要約JSONパースエラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "要約JSONパースエラー: \(error.localizedDescription)"
                }
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // MARK: - GitHub: 文字起こし生データを保存
    private func uploadRawTranscription(text: String, mode: ProcessingMode, audioURL: URL, completion: @escaping (Bool) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let timestamp = dateFormatter.string(from: Date())
        
        let modePrefix = getModePrefix(mode: mode)
        let filename = "\(modePrefix)_\(timestamp)_raw.txt"
        let path = "\(settings.githubPath)/raw/\(filename)"
        
        // プレーンテキスト形式
        let content = """
        # 文字起こし生データ (Whisper出力)
        日時: \(timestamp)
        処理モード: \(mode.rawValue)
        音声ファイル: \(audioURL.lastPathComponent)
        
        ---
        
        \(text)
        """
        
        print("📤 生データをGitHubに保存中: \(path)")
        uploadToGitHub(content: content, path: path, message: "Add raw transcription: \(timestamp)", completion: completion)
    }
    
    // MARK: - GitHub: 処理済み結果を保存
    private func uploadProcessedResult(mode: ProcessingMode, audioURL: URL, completion: @escaping (Bool) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let timestamp = dateFormatter.string(from: Date())
        
        let modePrefix = getModePrefix(mode: mode)
        let filename = "\(modePrefix)_\(timestamp).md"
        let path = "\(settings.githubPath)/\(filename)"
        
        // Markdown形式でコンテンツ作成
        var markdownContent = """
        # \(mode.rawValue) - \(timestamp)
        
        ## 処理結果
        \(bulletPoints)
        
        ---
        
        ## 元のテキスト
        \(transcribedText)
        
        ---
        """
        
        // 音声ファイルリンク (保存する場合)
        if settings.saveAudioFile {
            markdownContent += "\n## 音声ファイル\n[🎤 \(audioURL.lastPathComponent)](\(settings.githubPath)/audio/\(audioURL.lastPathComponent))\n\n---\n"
        }
        
        markdownContent += "\n*Generated by MedicalRecorder iOS App*\n"
        
        print("📤 処理結果をGitHubに保存中: \(path)")
        uploadToGitHub(content: markdownContent, path: path, message: "Add \(mode.rawValue): \(timestamp)") { success in
            if success && self.settings.saveAudioFile {
                // 音声ファイルもアップロード
                self.uploadAudioFile(audioURL: audioURL, timestamp: timestamp, mode: mode) { _ in
                    completion(success)
                }
            } else {
                completion(success)
            }
        }
    }
    
    // MARK: - GitHub: 音声ファイルをアップロード
    private func uploadAudioFile(audioURL: URL, timestamp: String, mode: ProcessingMode, completion: @escaping (Bool) -> Void) {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            print("❌ 音声ファイル読み込みエラー")
            completion(false)
            return
        }
        
        let base64Audio = audioData.base64EncodedString()
        let filename = audioURL.lastPathComponent
        let path = "\(settings.githubPath)/audio/\(filename)"
        
        let modePrefix = getModePrefix(mode: mode)
        
        print("📤 音声ファイルをGitHubに保存中: \(path)")
        uploadToGitHubRaw(base64Content: base64Audio, path: path, message: "Add audio file: \(modePrefix)_\(timestamp)", completion: completion)
    }
    
    // MARK: - GitHub共通アップロード処理 (テキストコンテンツ)
    private func uploadToGitHub(content: String, path: String, message: String, completion: @escaping (Bool) -> Void) {
        guard let contentData = content.data(using: .utf8) else {
            print("❌ Base64エンコード失敗")
            completion(false)
            return
        }
        let base64Content = contentData.base64EncodedString()
        uploadToGitHubRaw(base64Content: base64Content, path: path, message: message, completion: completion)
    }
    
    // MARK: - GitHub共通アップロード処理 (Base64コンテンツ)
    private func uploadToGitHubRaw(base64Content: String, path: String, message: String, completion: @escaping (Bool) -> Void) {
        let apiURL = "https://api.github.com/repos/\(settings.githubOwner)/\(settings.githubRepo)/contents/\(path)"
        guard let url = URL(string: apiURL) else {
            print("❌ 無効なURL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("MedicalRecorder-iOS", forHTTPHeaderField: "User-Agent")
        
        let requestBody: [String: Any] = [
            "message": message,
            "content": base64Content,
            "branch": settings.githubBranch
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("❌ GitHub リクエスト作成エラー: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        print("📤 GitHubへアップロード開始: \(path)")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ GitHubアップロードエラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "GitHubアップロードエラー: \(error.localizedDescription)"
                }
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス")
                completion(false)
                return
            }
            
            print("📊 GitHub APIレスポンスステータス: \(httpResponse.statusCode)")
            
            if (200...201).contains(httpResponse.statusCode) {
                // 成功
                if let responseData = responseData,
                   let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let content = json["content"] as? [String: Any],
                   let htmlURL = content["html_url"] as? String {
                    print("✅ GitHubアップロード成功: \(htmlURL)")
                    DispatchQueue.main.async {
                        self.githubURL = htmlURL
                    }
                }
                completion(true)
            } else {
                // エラー
                if let responseData = responseData,
                   let errorText = String( data: responseData, encoding: .utf8) {
                    print("❌ GitHubエラー詳細: \(errorText)")
                }
                DispatchQueue.main.async {
                    self.errorMessage = "GitHubアップロード失敗: \(httpResponse.statusCode)"
                }
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // MARK: - ユーティリティ: モードプレフィックス取得
    private func getModePrefix(mode: ProcessingMode) -> String {
        switch mode {
        case .meetingMinutes: return "meeting"
        case .trainingRecord: return "training"
        case .personalMemo: return "memo"
        case .customPrompt: return "custom"
        }
    }
    
    // 結果をリセット
    func reset() {
        transcribedText = ""
        bulletPoints = ""
        errorMessage = nil
        githubURL = nil
        uploadProgress = 0.0
    }
}

