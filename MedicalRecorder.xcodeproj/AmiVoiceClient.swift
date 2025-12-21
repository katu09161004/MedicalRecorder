//
//  AmiVoiceClient.swift
//  AI VOICE WATCH
//
//  AmiVoice Cloud APIとの通信を管理するクライアント
//

import Foundation

/// AmiVoice APIレスポンス
struct AmiVoiceResponse: Codable {
    let text: String?
    let code: String?
    let message: String?
    
    // WebSocket用のレスポンス構造
    struct Result: Codable {
        let type: String?
        let text: String?
        let tokens: [Token]?
        let confidence: Double?
        
        struct Token: Codable {
            let written: String?
            let spoken: String?
            let confidence: Double?
        }
    }
    
    let results: [Result]?
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
    
    /// デフォルト設定（汎用エンジン）
    static func `default`(apiKey: String) -> AmiVoiceConfig {
        AmiVoiceConfig(
            apiKey: apiKey,
            engineName: "-a-general",
            endpoint: "https://acp-api.amivoice.com/v1/recognize",
            timeout: 60.0
        )
    }
    
    /// 医療用設定
    static func medical(apiKey: String) -> AmiVoiceConfig {
        AmiVoiceConfig(
            apiKey: apiKey,
            engineName: "-a-medical",
            endpoint: "https://acp-api.amivoice.com/v1/recognize",
            timeout: 60.0
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
            // 音声データの読み込み
            let audioData = try Data(contentsOf: audioURL)
            
            return try await transcribe(audioData: audioData, contentType: "audio/m4a")
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// 音声データを文字起こし（HTTP API）
    /// - Parameters:
    ///   - audioData: 音声データ
    ///   - contentType: コンテンツタイプ（audio/m4a, audio/wav, audio/mp3など）
    /// - Returns: 文字起こし結果のテキスト
    func transcribe(audioData: Data, contentType: String = "audio/m4a") async throws -> String {
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
        
        // ヘッダー設定
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        // エンジン名をクエリパラメータまたはヘッダーに追加
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "d", value: config.engineName),
            URLQueryItem(name: "u", value: "YOUR_APP_USER_ID") // オプション：ユーザーID
        ]
        
        if let finalURL = components?.url {
            request.url = finalURL
        }
        
        // 音声データをボディに設定
        request.httpBody = audioData
        
        do {
            // APIリクエスト実行
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // HTTPレスポンスのチェック
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AmiVoiceError.networkError(NSError(domain: "AmiVoice", code: -1))
            }
            
            print("📡 AmiVoice API Response Status: \(httpResponse.statusCode)")
            
            // ステータスコードのチェック
            switch httpResponse.statusCode {
            case 200...299:
                // 成功
                break
            case 401:
                throw AmiVoiceError.unauthorized
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ AmiVoice API Error: \(errorMessage)")
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
        
        do {
            let response = try JSONDecoder().decode(AmiVoiceResponse.self, from: data)
            
            // エラーチェック
            if let code = response.code, let message = response.message {
                throw AmiVoiceError.apiError(code: code, message: message)
            }
            
            // テキストの取得（複数のフォーマットに対応）
            if let text = response.text, !text.isEmpty {
                return text
            }
            
            if let results = response.results, !results.isEmpty {
                let texts = results.compactMap { $0.text }
                return texts.joined(separator: " ")
            }
            
            // テキストが見つからない場合
            return ""
            
        } catch {
            print("❌ JSON Decode Error: \(error)")
            throw AmiVoiceError.decodingError
        }
    }
    
    /// 現在の処理をキャンセル
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
    }
    
    deinit {
        cancelCurrentRequest()
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
