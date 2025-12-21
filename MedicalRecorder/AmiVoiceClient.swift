//
//  AmiVoiceClient.swift
//  AI VOICE WATCH
//
//  AmiVoice Cloud APIとの通信を管理するクライアント
//

import Foundation
import Combine
import AVFoundation

/// AmiVoice APIレスポンス
struct AmiVoiceResponse: Codable {
    let text: String?
    let code: String?
    let message: String?
    let sessionid: String?
    let utteranceid: String?
    
    // 複数の結果フォーマットに対応
    struct Segment: Codable {
        let confidence: Double?
        let starttime: Int?
        let endtime: Int?
        let results: [Result]?
    }
    
    struct Result: Codable {
        let confidence: Double?
        let starttime: Int?
        let endtime: Int?
        let tags: [String]?
        let rulename: String?
        let text: String?
        let tokens: [Token]?
    }
    
    struct Token: Codable {
        let written: String?
        let confidence: Double?
        let starttime: Int?
        let endtime: Int?
        let spoken: String?
    }
    
    let results: [Result]?
    let segments: [Segment]?
}

/// AmiVoiceエラー
enum AmiVoiceError: LocalizedError {
    case invalidURL
    case invalidAudioData
    case networkError(Error)
    case apiError(code: String, message: String)
    case decodingError
    case missingAPIKey
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidAudioData:
            return "音声データが無効です"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "APIエラー [\(code)]: \(message)"
        case .decodingError:
            return "レスポンスのデコードに失敗しました"
        case .missingAPIKey:
            return "APIキーが設定されていません"
        case .unauthorized:
            return "認証に失敗しました。APIキーを確認してください"
        }
    }
}

/// AmiVoice API設定
struct AmiVoiceConfig {
    /// APIキー（AmiVoiceポータルから取得）
    let apiKey: String
    
    /// エンジン名（例: "-a-general", "-a-medical"）
    let engineName: String
    
    /// APIエンドポイント
    let endpoint: String
    
    /// タイムアウト（秒）
    let timeout: TimeInterval
    
    /// サンプリングレート（Hz）
    /// AmiVoiceは8000, 16000, 22050, 44100, 48000をサポート
    /// 音声認識には16000または22050が推奨
    let sampleRate: Int
    
    /// デフォルト設定（汎用エンジン）
    static func `default`(apiKey: String) -> AmiVoiceConfig {
        AmiVoiceConfig(
            apiKey: apiKey,
            engineName: "-a-general",
            endpoint: "https://acp-api.amivoice.com/v1/recognize",
            timeout: 60.0,
            sampleRate: 16000
        )
    }
    
    /// 医療用設定
    static func medical(apiKey: String) -> AmiVoiceConfig {
        AmiVoiceConfig(
            apiKey: apiKey,
            engineName: "-a-medical",
            endpoint: "https://acp-api.amivoice.com/v1/recognize",
            timeout: 60.0,
            sampleRate: 16000
        )
    }
    
    /// 高品質設定（22kHz）
    static func highQuality(apiKey: String) -> AmiVoiceConfig {
        AmiVoiceConfig(
            apiKey: apiKey,
            engineName: "-a-general",
            endpoint: "https://acp-api.amivoice.com/v1/recognize",
            timeout: 60.0,
            sampleRate: 22050
        )
    }
}

/// AmiVoice Cloud APIクライアント
@MainActor
class AmiVoiceClient: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: Error?
    
    private let config: AmiVoiceConfig
    private var currentTask: URLSessionDataTask?
    
    /// イニシャライザ
    /// - Parameter config: AmiVoice API設定
    init(config: AmiVoiceConfig) {
        self.config = config
    }
    
    /// 音声ファイルを文字起こし（HTTP API）
    /// - Parameter audioURL: 音声ファイルのURL（m4a, wav, mp3など）
    /// - Returns: 文字起こし結果のテキスト
    func transcribe(audioURL: URL) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw AmiVoiceError.missingAPIKey
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // AmiVoice対応形式に変換（必要な場合のみ）
            let (workingURL, needsCleanup) = try await AudioConverter.convertForAmiVoice(
                sourceURL: audioURL,
                sampleRate: config.sampleRate
            )
            
            // 変換後のファイルは処理後に削除
            defer {
                if needsCleanup {
                    AudioConverter.cleanupConvertedFile(workingURL)
                }
            }
            
            // 音声データの読み込み
            let audioData = try Data(contentsOf: workingURL)
            
            // AmiVoiceはWAV/MP3/FLACのみサポート
            let contentType: String
            let ext = workingURL.pathExtension.lowercased()
            switch ext {
            case "wav":
                contentType = "audio/wav"
            case "mp3":
                contentType = "audio/mpeg"
            case "flac":
                contentType = "audio/flac"
            default:
                // 未対応フォーマットの場合はエラー
                throw AmiVoiceError.invalidAudioData
            }
            
            // WAVの場合はヘッダーを除去してPCMデータのみ抽出
            var processedData = audioData
            if ext == "wav" {
                // WAVヘッダーをスキップ（通常44バイト）
                // "data"チャンクを探してその後のデータを使用
                if let dataChunkIndex = findDataChunk(in: audioData) {
                    processedData = audioData.subdata(in: dataChunkIndex..<audioData.count)
                    print("📊 WAVヘッダー除去: \(audioData.count)バイト → \(processedData.count)バイト")
                } else {
                    print("⚠️ WAVの'data'チャンクが見つかりません。そのまま送信します")
                }
            }
            
            print("📤 送信フォーマット: \(contentType) (\(processedData.count / 1024)KB)")
            
            // 音声の長さと詳細フォーマットを確認
            let asset = AVURLAsset(url: workingURL)
            if let duration = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(duration)
                print("⏱️ 音声の長さ: \(String(format: "%.1f", seconds))秒")
            }
            
            // 送信前のフォーマット詳細確認
            if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
               let formatDescs = try? await audioTrack.load(.formatDescriptions),
               let formatDesc = formatDescs.first {
                let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
                if let format = audioFormat?.pointee {
                    print("🔍 送信前のフォーマット詳細:")
                    print("   - サンプリングレート: \(format.mSampleRate) Hz")
                    print("   - チャンネル数: \(format.mChannelsPerFrame)")
                    print("   - ビット深度: \(format.mBitsPerChannel)")
                    print("   - フォーマットID: 0x\(String(format: "%X", format.mFormatID))")
                    
                    // PCMかどうかチェック
                    let isPCM = format.mFormatID == kAudioFormatLinearPCM
                    print("   - PCM形式: \(isPCM ? "✅" : "❌")")
                }
            }
            
            return try await transcribe(audioData: processedData, contentType: contentType)
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// 音声データを文字起こし（HTTP API）
    /// - Parameters:
    ///   - audioData: 音声データ
    ///   - contentType: コンテンツタイプ（audio/wav, audio/mpeg, audio/flacのみ対応）
    /// - Returns: 文字起こし結果のテキスト
    func transcribe(audioData: Data, contentType: String = "audio/wav") async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw AmiVoiceError.missingAPIKey
        }
        
        guard !audioData.isEmpty else {
            throw AmiVoiceError.invalidAudioData
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // URLリクエストの構築
        guard let url = URL(string: config.endpoint) else {
            throw AmiVoiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        
        // マルチパートフォームデータの作成
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // リクエストボディの構築（curlコマンドと同じ形式）
        var body = Data()
        
        // u パラメータ（APIキー）
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"u\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(config.apiKey)\r\n".data(using: .utf8)!)
        
        // d パラメータ（エンジン設定）
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"d\"\r\n\r\n".data(using: .utf8)!)
        body.append("grammarFileNames=\(config.engineName) loggingOptOut=True\r\n".data(using: .utf8)!)
        
        // c パラメータ（コーデック指定）- PCMの場合必須
        // LSB16K = リトルエンディアン、16bit、16kHz
        // LSB22K = リトルエンディアン、16bit、22kHz
        let codecParam: String
        switch config.sampleRate {
        case 8000:
            codecParam = "LSB8K"
        case 16000:
            codecParam = "LSB16K"
        case 22050:
            codecParam = "LSB22K"
        case 44100:
            codecParam = "LSB44K"
        case 48000:
            codecParam = "LSB48K"
        default:
            codecParam = "LSB16K"  // デフォルト
        }
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"c\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(codecParam)\r\n".data(using: .utf8)!)
        
        // a パラメータ（音声ファイル）
        // AmiVoiceはPCMデータまたは圧縮形式を受け付ける
        let filename: String
        let fileContentType: String
        switch contentType {
        case "audio/wav":
            // WAVの場合はPCMデータとして送信（ヘッダーなし）
            filename = "audio.pcm"
            fileContentType = "application/octet-stream"
        case "audio/mpeg":
            filename = "audio.mp3"
            fileContentType = "audio/mpeg"
        case "audio/flac":
            filename = "audio.flac"
            fileContentType = "audio/flac"
        default:
            filename = "audio.pcm"
            fileContentType = "application/octet-stream"
        }
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"a\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(fileContentType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 終了バウンダリ
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🔑 Endpoint: \(url.absoluteString)")
        print("🔑 API Key: \(config.apiKey.prefix(10))...")
        print("🔑 Engine: \(config.engineName)")
        print("🔑 Sample Rate: \(config.sampleRate) Hz")
        print("🔑 Codec: \(codecParam)")
        print("🔑 Content-Type: multipart/form-data")
        print("🔑 Audio Data Size: \(audioData.count) bytes")
        print("🔑 Body Size: \(body.count) bytes")
        
        do {
            // APIリクエスト実行
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // HTTPレスポンスのチェック
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AmiVoiceError.networkError(NSError(domain: "AmiVoice", code: -1))
            }
            
            print("📡 AmiVoice API Response Status: \(httpResponse.statusCode)")
            
            // レスポンスの内容を出力（デバッグ用）
            if let responseText = String(data: data, encoding: .utf8) {
                print("📄 AmiVoice Response Body: \(responseText)")
            }
            
            // ステータスコードのチェック
            switch httpResponse.statusCode {
            case 200...299:
                // 成功
                break
            case 401:
                throw AmiVoiceError.unauthorized
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ AmiVoice API Error [\(httpResponse.statusCode)]: \(errorMessage)")
                throw AmiVoiceError.apiError(
                    code: "\(httpResponse.statusCode)",
                    message: errorMessage
                )
            }
            
            // レスポンスのパース
            return try parseResponse(data: data)
            
        } catch let error as AmiVoiceError {
            lastError = error
            throw error
        } catch {
            let wrappedError = AmiVoiceError.networkError(error)
            lastError = wrappedError
            throw wrappedError
        }
    }
    
    /// レスポンスデータをパースしてテキストを抽出
    private func parseResponse(data: Data) throws -> String {
        // デバッグ用：レスポンスを出力
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 AmiVoice Response: \(jsonString)")
        }
        
        // まずは辞書としてパースしてみる（より柔軟な方法）
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ JSON辞書としてパース成功")
                print("   Keys: \(json.keys.joined(separator: ", "))")
                
                // エラーチェック（空文字列はエラーではない）
                if let code = json["code"] as? String, !code.isEmpty,
                   let message = json["message"] as? String {
                    print("❌ APIエラー検出: code=\(code), message=\(message)")
                    throw AmiVoiceError.apiError(code: code, message: message)
                }
                
                // 1. 直接textフィールドから
                if let text = json["text"] as? String, !text.isEmpty {
                    print("✅ text フィールドから取得: \(text)")
                    return text
                }
                
                // 2. resultsから
                if let results = json["results"] as? [[String: Any]] {
                    print("   results配列を発見 (要素数: \(results.count))")
                    let texts = results.compactMap { $0["text"] as? String }
                    let combined = texts.joined(separator: "")
                    if !combined.isEmpty {
                        print("✅ results から取得: \(combined)")
                        return combined
                    }
                }
                
                // 3. segmentsから
                if let segments = json["segments"] as? [[String: Any]] {
                    print("   segments配列を発見 (要素数: \(segments.count))")
                    var allTexts: [String] = []
                    for segment in segments {
                        if let results = segment["results"] as? [[String: Any]] {
                            let texts = results.compactMap { $0["text"] as? String }
                            allTexts.append(contentsOf: texts)
                        }
                    }
                    let combined = allTexts.joined(separator: "")
                    if !combined.isEmpty {
                        print("✅ segments から取得: \(combined)")
                        return combined
                    }
                }
                
                print("⚠️ レスポンスにテキストが含まれていません")
                print("   利用可能なフィールド: \(json)")
            }
            
            // 空のレスポンスの場合
            return ""
            
        } catch let error as AmiVoiceError {
            throw error
        } catch {
            print("❌ JSON Parse Error: \(error)")
            
            // プレーンテキストとして扱えるか試す
            if let plainText = String(data: data, encoding: .utf8), !plainText.isEmpty {
                print("📝 プレーンテキストとして処理します: \(plainText)")
                return plainText
            }
            
            throw AmiVoiceError.decodingError
        }
    }
    
    /// 現在の処理をキャンセル
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
    }
    
    /// WAVファイルから'data'チャンクの開始位置を探す
    private func findDataChunk(in data: Data) -> Int? {
        // "data"という文字列を探す（ASCII: 0x64 0x61 0x74 0x61）
        let dataMarker: [UInt8] = [0x64, 0x61, 0x74, 0x61]
        
        for i in 0..<(data.count - 8) {
            var match = true
            for j in 0..<4 {
                if data[i + j] != dataMarker[j] {
                    match = false
                    break
                }
            }
            
            if match {
                // "data"の後の4バイトはチャンクサイズ、その後が実際のデータ
                return i + 8
            }
        }
        
        return nil
    }
    
    deinit {
        // Note: deinit cannot call main actor-isolated methods
        // Directly cancel the task instead
        currentTask?.cancel()
    }
}

// MARK: - リアルタイム音声認識用の拡張（WebSocket対応）
extension AmiVoiceClient {
    
    /// リアルタイム音声認識のセッションを開始
    /// （WebSocketを使用する場合の実装例）
    func startRealtimeRecognition() async throws {
        // WebSocket実装が必要な場合はここに追加
        // URLSessionWebSocketTaskを使用
        print("⚠️ リアルタイム音声認識はまだ実装されていません")
    }
}
