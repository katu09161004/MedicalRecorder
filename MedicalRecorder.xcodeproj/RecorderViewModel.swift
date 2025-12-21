//
//  RecorderViewModel.swift
//  AI VOICE WATCH
//
//  録音とAmiVoice文字起こしを統合するViewModel
//

import Foundation
import SwiftUI

@MainActor
class RecorderViewModel: ObservableObject {
    // 録音管理
    @Published var recorder = Recorder()
    
    // AmiVoiceクライアント
    @Published var amiVoiceClient: AmiVoiceClient
    
    // 文字起こし結果
    @Published var transcribedText: String = ""
    
    // 処理状態
    @Published var isTranscribing = false
    @Published var transcriptionError: Error?
    
    // 録音履歴
    @Published var recordings: [Recording] = []
    
    /// イニシャライザ
    /// - Parameter apiKey: AmiVoice APIキー
    init(apiKey: String, engineName: String = "-a-general") {
        let config = AmiVoiceConfig(
            apiKey: apiKey,
            engineName: engineName,
            endpoint: "https://acp-api.amivoice.com/v1/recognize",
            timeout: 60.0
        )
        self.amiVoiceClient = AmiVoiceClient(config: config)
        loadRecordings()
    }
    
    // MARK: - 録音操作
    
    /// 録音開始
    func startRecording() {
        do {
            try recorder.startRecording()
            transcribedText = ""
            transcriptionError = nil
            print("🎤 録音開始")
        } catch {
            print("❌ 録音開始エラー: \(error.localizedDescription)")
            transcriptionError = error
        }
    }
    
    /// 録音停止して文字起こし実行
    func stopRecordingAndTranscribe() async {
        guard let audioURL = recorder.stopRecording() else {
            print("⚠️ 録音ファイルが見つかりません")
            return
        }
        
        print("✅ 録音停止: \(audioURL)")
        
        // 録音を履歴に追加
        let recording = Recording(
            id: UUID(),
            url: audioURL,
            date: Date(),
            duration: Recorder.getAudioDuration(url: audioURL) ?? 0
        )
        recordings.insert(recording, at: 0)
        saveRecordings()
        
        // 文字起こし実行
        await transcribe(audioURL: audioURL)
    }
    
    /// 録音停止のみ（文字起こしなし）
    func stopRecording() {
        guard let audioURL = recorder.stopRecording() else {
            return
        }
        
        let recording = Recording(
            id: UUID(),
            url: audioURL,
            date: Date(),
            duration: Recorder.getAudioDuration(url: audioURL) ?? 0
        )
        recordings.insert(recording, at: 0)
        saveRecordings()
    }
    
    // MARK: - 文字起こし操作
    
    /// 音声ファイルを文字起こし
    /// - Parameter audioURL: 音声ファイルのURL
    func transcribe(audioURL: URL) async {
        isTranscribing = true
        transcriptionError = nil
        
        do {
            print("🔄 文字起こし開始...")
            let text = try await amiVoiceClient.transcribe(audioURL: audioURL)
            transcribedText = text
            
            // 録音履歴を更新
            if let index = recordings.firstIndex(where: { $0.url == audioURL }) {
                recordings[index].transcribedText = text
                saveRecordings()
            }
            
            print("✅ 文字起こし完了: \(text)")
        } catch {
            print("❌ 文字起こしエラー: \(error.localizedDescription)")
            transcriptionError = error
        }
        
        isTranscribing = false
    }
    
    /// 録音を削除
    /// - Parameter recording: 削除する録音
    func deleteRecording(_ recording: Recording) {
        // ファイルを削除
        try? FileManager.default.removeItem(at: recording.url)
        
        // 履歴から削除
        recordings.removeAll { $0.id == recording.id }
        saveRecordings()
    }
    
    // MARK: - 永続化
    
    private var recordingsFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("recordings.json")
    }
    
    private func saveRecordings() {
        do {
            let data = try JSONEncoder().encode(recordings)
            try data.write(to: recordingsFileURL)
        } catch {
            print("⚠️ 録音履歴の保存エラー: \(error)")
        }
    }
    
    private func loadRecordings() {
        do {
            let data = try Data(contentsOf: recordingsFileURL)
            recordings = try JSONDecoder().decode([Recording].self, from: data)
            
            // 存在しないファイルを除外
            recordings = recordings.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        } catch {
            print("ℹ️ 録音履歴の読み込み: 新規作成")
            recordings = []
        }
    }
}

// MARK: - 録音データモデル
struct Recording: Identifiable, Codable {
    let id: UUID
    let url: URL
    let date: Date
    let duration: TimeInterval
    var transcribedText: String?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
