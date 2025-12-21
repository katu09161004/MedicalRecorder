//
//  AudioConverter.swift
//  MedicalRecorder
//
//  音声ファイルを適切な形式に変換するユーティリティ
//

import Foundation
import AVFoundation

enum AudioConversionError: LocalizedError {
    case invalidSourceFile
    case conversionFailed
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidSourceFile:
            return "変換元の音声ファイルが無効です"
        case .conversionFailed:
            return "音声の変換に失敗しました"
        case .exportFailed:
            return "変換後のファイルのエクスポートに失敗しました"
        }
    }
}

class AudioConverter {
    
    /// 音声ファイルを適切な形式に変換（必要な場合のみ）
    /// AmiVoice APIはm4a/AAC形式をサポートしているため、通常は変換不要
    /// - Parameter sourceURL: 変換元のファイルのURL
    /// - Returns: 変換後（または元の）ファイルのURL、変換が必要だったかどうか
    static func convertForAmiVoice(sourceURL: URL) async throws -> (url: URL, needsCleanup: Bool) {
        let ext = sourceURL.pathExtension.lowercased()
        
        // m4a, mp3, wav, flacはそのまま使用可能
        if ["m4a", "mp3", "wav", "flac"].contains(ext) {
            print("✅ \(ext.uppercased())形式はAmiVoice対応 - 変換不要")
            return (sourceURL, false)
        }
        
        // その他の形式の場合はm4aに変換
        print("🔄 \(ext.uppercased())形式を検出 - M4Aに変換します...")
        let convertedURL = try await convertToM4A(sourceURL: sourceURL)
        return (convertedURL, true)
    }
    
    /// 音声ファイルをM4A形式に変換
    /// - Parameter sourceURL: 変換元のファイルのURL
    /// - Returns: 変換後のM4AファイルのURL
    private static func convertToM4A(sourceURL: URL) async throws -> URL {
        print("🔄 音声ファイルをM4Aに変換開始: \(sourceURL.lastPathComponent)")
        
        // アセットの読み込み
        let asset = AVURLAsset(url: sourceURL)
        
        // エクスポート可能かチェック
        guard try await asset.load(.isExportable) else {
            throw AudioConversionError.invalidSourceFile
        }
        
        // 出力先URLの生成（一時ディレクトリ）
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        // 既存のファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        // エクスポートセッションの作成
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioConversionError.conversionFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // エクスポート実行
        await exportSession.export()
        
        // ステータスチェック
        switch exportSession.status {
        case .completed:
            print("✅ M4A変換完了: \(outputURL.lastPathComponent)")
            
            // ファイルサイズを取得して表示
            if let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
               let fileSize = attributes[.size] as? Int64 {
                print("📊 ファイルサイズ: \(fileSize / 1024)KB")
            }
            
            return outputURL
            
        case .failed, .cancelled:
            if let error = exportSession.error {
                print("❌ M4A変換失敗: \(error.localizedDescription)")
            }
            throw AudioConversionError.exportFailed
            
        default:
            throw AudioConversionError.exportFailed
        }
    }
    
    /// 変換した音声ファイルのクリーンアップ
    /// - Parameter url: 削除するファイルのURL
    static func cleanupConvertedFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("🗑️ 変換ファイルを削除: \(url.lastPathComponent)")
        } catch {
            print("⚠️ ファイル削除失敗: \(error.localizedDescription)")
        }
    }
}
