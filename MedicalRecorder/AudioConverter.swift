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
    /// AmiVoice APIはWAV形式が最も安定しているため、m4aからWAVに変換
    /// - Parameters:
    ///   - sourceURL: 変換元のファイルのURL
    ///   - sampleRate: サンプリングレート（デフォルト: 16000Hz）
    /// - Returns: 変換後（または元の）ファイルのURL、変換が必要だったかどうか
    static func convertForAmiVoice(sourceURL: URL, sampleRate: Int = 16000) async throws -> (url: URL, needsCleanup: Bool) {
        let ext = sourceURL.pathExtension.lowercased()
        
        // WAVの場合はサンプリングレートを確認
        if ext == "wav" {
            // サンプリングレートをチェック
            let asset = AVURLAsset(url: sourceURL)
            if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
               let formatDescriptions = try? await audioTrack.load(.formatDescriptions),
               let formatDescription = formatDescriptions.first {
                
                let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                if let desc = audioStreamBasicDescription?.pointee {
                    let currentSampleRate = Int(desc.mSampleRate)
                    print("✅ WAV形式 - 現在のサンプリングレート: \(currentSampleRate)Hz")
                    
                    // サンプリングレートが一致していれば変換不要
                    if currentSampleRate == sampleRate {
                        print("✅ サンプリングレート一致 - 変換不要")
                        return (sourceURL, false)
                    } else {
                        print("🔄 サンプリングレート不一致 (\(currentSampleRate)Hz → \(sampleRate)Hz) - 変換します")
                        let convertedURL = try await convertToWAV(sourceURL: sourceURL, sampleRate: sampleRate)
                        return (convertedURL, true)
                    }
                }
            }
            
            // サンプリングレートが取得できない場合はそのまま使用
            print("✅ WAV形式 - 変換不要")
            return (sourceURL, false)
        }
        
        // m4aやその他の形式はWAVに変換
        print("🔄 \(ext.uppercased())形式を検出 - WAVに変換します（\(sampleRate)Hz）...")
        let convertedURL = try await convertToWAV(sourceURL: sourceURL, sampleRate: sampleRate)
        return (convertedURL, true)
    }
    
    /// 音声ファイルをWAV形式に変換（PCM形式）
    /// - Parameters:
    ///   - sourceURL: 変換元のファイルのURL
    ///   - sampleRate: サンプリングレート（デフォルト: 16000Hz）
    /// - Returns: 変換後のWAVファイルのURL
    private static func convertToWAV(sourceURL: URL, sampleRate: Int = 16000) async throws -> URL {
        print("🔄 音声ファイルをWAVに変換開始: \(sourceURL.lastPathComponent)")
        
        // アセットの読み込み
        let asset = AVURLAsset(url: sourceURL)
        
        // エクスポート可能かチェック
        guard try await asset.load(.isExportable) else {
            throw AudioConversionError.invalidSourceFile
        }
        
        // 出力先URLの生成（一時ディレクトリ）
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        // 既存のファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        // オーディオトラックの取得
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw AudioConversionError.invalidSourceFile
        }
        
        // リーダーとライターの設定
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
        
        // リーダーの出力設定（PCM形式）
        let readerOutput = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,  // AmiVoiceは16kHz推奨（8kHz〜48kHz対応）
                AVNumberOfChannelsKey: 1,  // モノラル
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        reader.add(readerOutput)
        
        // ライターの入力設定（WAVエンコード）
        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)
        
        // 変換開始
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // データの転送
        let processingQueue = DispatchQueue(label: "audioProcessingQueue")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writerInput.requestMediaDataWhenReady(on: processingQueue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        break
                    }
                }
            }
        }
        
        // 完了待機
        await writer.finishWriting()
        
        // ステータスチェック
        if writer.status == .completed {
            print("✅ WAV変換完了: \(outputURL.lastPathComponent)")
            
            // ファイルサイズを取得して表示
            if let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
               let fileSize = attributes[.size] as? Int64 {
                print("📊 ファイルサイズ: \(fileSize / 1024)KB")
            }
            
            // 変換後のフォーマット詳細を確認
            let checkAsset = AVURLAsset(url: outputURL)
            if let checkTrack = try? await checkAsset.loadTracks(withMediaType: .audio).first,
               let formatDescs = try? await checkTrack.load(.formatDescriptions),
               let formatDesc = formatDescs.first {
                let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
                if let format = audioFormat?.pointee {
                    print("🔍 変換後の詳細:")
                    print("   - サンプリングレート: \(format.mSampleRate) Hz")
                    print("   - チャンネル数: \(format.mChannelsPerFrame)")
                    print("   - ビット深度: \(format.mBitsPerChannel)")
                    print("   - フォーマットID: \(format.mFormatID)")
                    print("   - フォーマットフラグ: \(format.mFormatFlags)")
                }
            }
            
            return outputURL
        } else {
            if let error = writer.error {
                print("❌ WAV変換失敗: \(error.localizedDescription)")
            }
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
