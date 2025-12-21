//
// AquaVoiceAPI.swift
// MedicalRecorder
//
// Aqua Voice (Avalon) API クライアント
// OpenAI互換API
// https://api.aquavoice.com/
//

import Foundation

class AquaVoiceAPI {
    
    // Aqua Voice (Avalon) APIエンドポイント（OpenAI互換）
    private let API_BASE_URL = "https://api.aquavoice.com/api/v1"
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - 音声ファイルを文字起こし（OpenAI Whisper互換）
    func transcribeAudio(audioURL: URL, completion: @escaping (Bool, String) -> Void) {
        print("🚀 AquaVoiceAPI.transcribeAudio 開始")
        
        // OpenAI互換のエンドポイント
        guard let url = URL(string: "\(API_BASE_URL)/audio/transcriptions") else {
            print("❌ URL生成失敗")
            DispatchQueue.main.async {
                completion(false, "")
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300 // 5分
        
        // OpenAI形式の認証ヘッダー
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        print("🔐 Aqua Voice (Avalon) API キー設定完了")
        print("📍 リクエストURL: \(url.absoluteString)")
        print("🔑 APIキー（最初の10文字）: \(String(apiKey.prefix(10)))...")
        
        // マルチパートフォームデータ
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // model パラメータ（日本語の場合は avalon-v1-ja）
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("avalon-v1-ja\r\n".data(using: .utf8)!)
        
        // 音声ファイル
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        // 音声データ読み込み
        guard let audioData = try? Data(contentsOf: audioURL) else {
            print("❌ 音声ファイル読み込みエラー: \(audioURL)")
            DispatchQueue.main.async {
                completion(false, "")
            }
            return
        }
        
        print("📊 音声データ読み込み成功: \(audioData.count) bytes (\(audioData.count / 1024) KB)")
        
        data.append(audioData)
        data.append("\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = data
        
        print("📤 Aqua Voice API リクエスト送信開始")
        print("📝 モデル: avalon-v1-ja")
        print("📏 リクエストサイズ: \(data.count) bytes")
        
        // 開始時刻を記録
        let startTime = Date()
        
        // リクエスト実行
        let task = URLSession.shared.dataTask(with: request) { responseData, response, error in
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("⏱️ API応答時間: \(String(format: "%.2f", elapsedTime))秒")
            
            if let error = error {
                print("❌ Aqua Voice APIエラー: \(error.localizedDescription)")
                print("   エラータイプ: \(type(of: error))")
                DispatchQueue.main.async {
                    completion(false, "")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス（HTTPURLResponseではない）")
                DispatchQueue.main.async {
                    completion(false, "")
                }
                return
            }
            
            print("📥 Aqua Voice API レスポンス: \(httpResponse.statusCode)")
            print("📋 レスポンスヘッダー: \(httpResponse.allHeaderFields)")
            
            // レスポンスボディをログ出力（デバッグ用）
            if let responseData = responseData {
                print("📊 レスポンスサイズ: \(responseData.count) bytes")
                if let responseString = String(data: responseData, encoding: .utf8) {
                    print("📄 レスポンスボディ: \(responseString)")
                } else {
                    print("⚠️ レスポンスボディをUTF-8でデコードできません")
                }
            } else {
                print("❌ レスポンスデータが nil")
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ APIエラー: ステータスコード \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(false, "")
                }
                return
            }
            
            guard let responseData = responseData else {
                print("❌ レスポンスデータなし（ステータスは200）")
                DispatchQueue.main.async {
                    completion(false, "")
                }
                return
            }
            
            // JSONパース（OpenAI Whisper API互換形式）
            print("🔄 JSONパース開始")
            do {
                if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                    print("📊 JSONレスポンス: \(json)")
                    
                    // OpenAI形式: { "text": "..." }
                    if let text = json["text"] as? String {
                        print("✅ Aqua Voice 文字起こし成功!")
                        print("📝 文字数: \(text.count)")
                        print("📝 内容（最初の100文字）: \(text.prefix(100))...")
                        DispatchQueue.main.async {
                            completion(true, text)
                        }
                    } else {
                        print("❌ JSONに'text'キーが見つかりません")
                        print("📊 利用可能なキー: \(json.keys)")
                        DispatchQueue.main.async {
                            completion(false, "")
                        }
                    }
                } else {
                    print("❌ JSONが辞書形式ではありません")
                    DispatchQueue.main.async {
                        completion(false, "")
                    }
                }
            } catch {
                print("❌ JSONパースエラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "")
                }
            }
        }
        
        print("🏃 URLSessionタスク開始")
        task.resume()
        print("✅ タスク実行中...")
    }
}

