//
// TranscriptionProvider.swift
// MedicalRecorder
//
// 文字起こしAPIプロバイダーの選択
//

import Foundation

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case sakura = "さくらのAI"
    case aquaVoice = "Aqua Voice (Avalon)"
    case amiVoice = "AmiVoice Cloud"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .sakura:
            return "cloud.fill"
        case .aquaVoice:
            return "waveform"
        case .amiVoice:
            return "mic.fill"
        }
    }
    
    var description: String {
        switch self {
        case .sakura:
            return "さくらのAI API（Whisper + LLM）"
        case .aquaVoice:
            return "Aqua Voice (Avalon) API - OpenAI互換"
        case .amiVoice:
            return "AmiVoice Cloud API - 日本語特化の音声認識"
        }
    }
    
    // API仕様 - 時間制限
    var maxDuration: TimeInterval {
        switch self {
        case .sakura:
            return 1800 // 30分
        case .aquaVoice:
            return 7200 // 120分（仮定 - 実際の制限を確認）
        case .amiVoice:
            return 3600 // 60分（AmiVoice Cloud の一般的な制限）
        }
    }

    // API仕様 - ファイルサイズ制限（バイト単位）
    var maxFileSize: Int64 {
        switch self {
        case .sakura:
            return 30 * 1024 * 1024 // 30MB
        case .aquaVoice:
            return 100 * 1024 * 1024 // 100MB（仮定）
        case .amiVoice:
            return 50 * 1024 * 1024 // 50MB（仮定）
        }
    }

    // 分割が必要かどうか
    var needsSplitting: Bool {
        switch self {
        case .sakura:
            return true // 30分/30MB制限
        case .aquaVoice:
            return false // 長時間対応（要確認）
        case .amiVoice:
            return false // 長時間対応
        }
    }
    
    // モデル名
    var modelName: String {
        switch self {
        case .sakura:
            return "whisper-large-v3-turbo"
        case .aquaVoice:
            return "avalon-v1-ja" // 日本語用
        case .amiVoice:
            return "-a-general" // デフォルトは汎用エンジン
        }
    }
}
