//
// AudioImporter.swift
// MedicalRecorder
//
// 音声ファイルの直接インポート機能
// ファイルアプリや共有からの音声ファイルを処理
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import Combine

// MARK: - サポートする音声形式
enum AudioFormat: String, CaseIterable {
    case m4a = "m4a"
    case mp3 = "mp3"
    case wav = "wav"
    case aac = "aac-audio"
    case mp4 = "mp4"
    case caf = "caf"
    case aiff = "aiff"

    var utType: UTType {
        switch self {
        case .m4a: return UTType.mpeg4Audio
        case .mp3: return UTType.mp3
        case .wav: return UTType.wav
        case .aac: return UTType(filenameExtension: "aac") ?? .audio
        case .mp4: return UTType.mpeg4Movie
        case .caf: return UTType(filenameExtension: "caf") ?? .audio
        case .aiff: return UTType.aiff
        }
    }

    static var allUTTypes: [UTType] {
        return allCases.map { $0.utType }
    }
}

// MARK: - インポート結果
struct AudioImportResult {
    let originalURL: URL
    let processedURL: URL
    let duration: TimeInterval
    let format: String
    let fileSize: Int64
}

// MARK: - AudioImporter
class AudioImporter: ObservableObject {
    static let shared = AudioImporter()

    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var lastError: String?

    private init() {}

    // MARK: - ファイルをインポート
    func importAudioFile(from url: URL) async throws -> AudioImportResult {
        await MainActor.run {
            isImporting = true
            importProgress = 0
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isImporting = false
            }
        }

        // セキュリティスコープドリソースへのアクセス開始
        guard url.startAccessingSecurityScopedResource() else {
            throw AudioImportError.accessDenied
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // ファイル情報を取得
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioImportError.fileNotFound
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        await MainActor.run {
            importProgress = 0.2
        }

        // 音声ファイルの長さを取得
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds.isFinite && durationSeconds > 0 else {
            throw AudioImportError.invalidAudioFile
        }

        await MainActor.run {
            importProgress = 0.4
        }

        // ドキュメントディレクトリにコピー
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "imported_\(Date().timeIntervalSince1970).\(url.pathExtension)"
        let destinationURL = documentsPath.appendingPathComponent(fileName)

        // 既存ファイルがあれば削除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: url, to: destinationURL)

        await MainActor.run {
            importProgress = 0.8
        }

        // M4Aに変換が必要な場合（WAVなど大きいファイル）
        var processedURL = destinationURL
        if url.pathExtension.lowercased() == "wav" {
            if let convertedURL = try? await convertToM4A(from: destinationURL) {
                // 元のWAVファイルを削除
                try? fileManager.removeItem(at: destinationURL)
                processedURL = convertedURL
            }
        }

        await MainActor.run {
            importProgress = 1.0
        }

        return AudioImportResult(
            originalURL: url,
            processedURL: processedURL,
            duration: durationSeconds,
            format: url.pathExtension.uppercased(),
            fileSize: fileSize
        )
    }

    // MARK: - M4Aに変換
    private func convertToM4A(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("converted_\(Date().timeIntervalSince1970).m4a")

        // エクスポートセッションを作成
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioImportError.conversionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioImportError.conversionFailed
        }

        return outputURL
    }

    // MARK: - ファイルサイズをフォーマット
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - 時間をフォーマット
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - エラー定義
enum AudioImportError: LocalizedError {
    case accessDenied
    case fileNotFound
    case invalidAudioFile
    case conversionFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "ファイルへのアクセスが拒否されました"
        case .fileNotFound:
            return "ファイルが見つかりません"
        case .invalidAudioFile:
            return "無効な音声ファイルです"
        case .conversionFailed:
            return "ファイルの変換に失敗しました"
        case .unsupportedFormat:
            return "サポートされていない形式です"
        }
    }
}

// MARK: - ファイルピッカービュー
struct AudioFilePickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: AudioFormat.allUTTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AudioFilePickerView

        init(_ parent: AudioFilePickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
            parent.isPresented = false
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - インポートビュー
struct AudioImportView: View {
    @ObservedObject var importer = AudioImporter.shared
    @State private var showingFilePicker = false
    @State private var importResult: AudioImportResult?
    @State private var showingError = false

    let onImportComplete: (URL) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // ヘッダー
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("音声ファイルをインポート")
                    .font(.headline)

                Text("M4A, MP3, WAV, AAC形式に対応")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            // インポートボタン
            Button(action: {
                showingFilePicker = true
            }) {
                HStack {
                    Image(systemName: "folder")
                    Text("ファイルを選択")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(importer.isImporting)
            .padding(.horizontal)

            // プログレス
            if importer.isImporting {
                VStack(spacing: 8) {
                    ProgressView(value: importer.importProgress)
                        .progressViewStyle(LinearProgressViewStyle())

                    Text("インポート中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // 結果表示
            if let result = importResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("インポート完了")
                            .font(.headline)
                    }

                    Divider()

                    HStack {
                        Text("形式:")
                        Spacer()
                        Text(result.format)
                    }
                    .font(.caption)

                    HStack {
                        Text("長さ:")
                        Spacer()
                        Text(AudioImporter.formatDuration(result.duration))
                    }
                    .font(.caption)

                    HStack {
                        Text("サイズ:")
                        Spacer()
                        Text(AudioImporter.formatFileSize(result.fileSize))
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }

            Spacer()
        }
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePickerView(isPresented: $showingFilePicker) { url in
                Task {
                    do {
                        let result = try await importer.importAudioFile(from: url)
                        await MainActor.run {
                            importResult = result
                            onImportComplete(result.processedURL)
                        }
                    } catch {
                        await MainActor.run {
                            importer.lastError = error.localizedDescription
                            showingError = true
                        }
                    }
                }
            }
        }
        .alert("インポートエラー", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importer.lastError ?? "不明なエラー")
        }
    }
}
