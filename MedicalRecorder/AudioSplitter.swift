//
// AudioSplitter.swift
// MedicalRecorder
//
// 音声ファイルを指定された長さで分割するユーティリティ
// さくらのAIの30分制限に対応
//

import Foundation
import AVFoundation

class AudioSplitter {
    
    /// 音声ファイルを指定秒数で分割
    /// - Parameters:
    ///   - sourceURL: 元の音声ファイルURL
    ///   - maxDuration: 最大長さ（秒）デフォルト1750秒（約29分）
    /// - Returns: 分割されたファイルのURL配列
    static func splitAudio(sourceURL: URL, maxDuration: TimeInterval = 1750) async throws -> [URL] {
        let asset = AVURLAsset(url: sourceURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // 30分以下ならそのまま返す
        if duration <= maxDuration {
            print("📊 音声ファイル長: \(Int(duration))秒 - 分割不要")
            return [sourceURL]
        }
        
        print("⚠️ 音声ファイルが\(Int(duration))秒あります。\(Int(maxDuration))秒ごとに分割します")
        
        // 分割数を計算
        let numberOfSegments = Int(ceil(duration / maxDuration))
        var outputURLs: [URL] = []
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        for i in 0..<numberOfSegments {
            let startTime = CMTime(seconds: Double(i) * maxDuration, preferredTimescale: 600)
            let endTime: CMTime
            
            if i == numberOfSegments - 1 {
                // 最後のセグメント
                endTime = asset.duration
            } else {
                endTime = CMTime(seconds: Double(i + 1) * maxDuration, preferredTimescale: 600)
            }
            
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            
            // 出力ファイル名
            let timestamp = Date().timeIntervalSince1970
            let outputFilename = "recording_\(timestamp)_part\(i+1)of\(numberOfSegments).m4a"
            let outputURL = documentsPath.appendingPathComponent(outputFilename)
            
            // エクスポート
            try await exportAudioSegment(
                asset: asset,
                timeRange: timeRange,
                outputURL: outputURL
            )
            
            outputURLs.append(outputURL)
            
            let segmentDuration = CMTimeGetSeconds(CMTimeSubtract(endTime, startTime))
            print("✅ セグメント \(i+1)/\(numberOfSegments) 作成完了: \(Int(segmentDuration))秒")
        }
        
        return outputURLs
    }
    
    /// 音声セグメントをエクスポート
    private static func exportAudioSegment(
        asset: AVAsset,
        timeRange: CMTimeRange,
        outputURL: URL
    ) async throws {
        // 既存ファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioSplitterError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return
        case .failed:
            throw AudioSplitterError.exportFailed(exportSession.error)
        case .cancelled:
            throw AudioSplitterError.exportCancelled
        default:
            throw AudioSplitterError.exportUnknownError
        }
    }
    
    /// 分割したファイルを削除
    static func cleanupSplitFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ 分割ファイル削除: \(url.lastPathComponent)")
        }
    }
}

// MARK: - エラー定義
enum AudioSplitterError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(Error?)
    case exportCancelled
    case exportUnknownError
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "エクスポートセッションの作成に失敗しました"
        case .exportFailed(let error):
            if let error = error {
                return "エクスポートに失敗しました: \(error.localizedDescription)"
            }
            return "エクスポートに失敗しました"
        case .exportCancelled:
            return "エクスポートがキャンセルされました"
        case .exportUnknownError:
            return "不明なエラーが発生しました"
        }
    }
}
