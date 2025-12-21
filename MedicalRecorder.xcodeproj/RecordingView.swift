//
//  RecordingView.swift
//  AI VOICE WATCH
//
//  録音と文字起こしのメインビュー
//

import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel: RecorderViewModel
    @State private var showSettings = false
    
    init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: RecorderViewModel(apiKey: apiKey))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 録音コントロール
                recordingControlSection
                
                // 文字起こし結果
                transcriptionResultSection
                
                // 録音履歴
                recordingHistorySection
            }
            .padding()
            .navigationTitle("AmiVoice 録音")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    // MARK: - 録音コントロールセクション
    
    private var recordingControlSection: some View {
        VStack(spacing: 16) {
            // 録音ボタン
            Button {
                if viewModel.recorder.isRecording {
                    Task {
                        await viewModel.stopRecordingAndTranscribe()
                    }
                } else {
                    viewModel.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.recorder.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 4)
                    
                    Image(systemName: viewModel.recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
            }
            .disabled(viewModel.isTranscribing)
            
            // 録音時間表示
            if viewModel.recorder.isRecording {
                Text(viewModel.recorder.formattedRecordingTime())
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            // ステータスメッセージ
            if viewModel.isTranscribing {
                HStack {
                    ProgressView()
                    Text("文字起こし中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8)
        )
    }
    
    // MARK: - 文字起こし結果セクション
    
    private var transcriptionResultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("文字起こし結果")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.transcribedText.isEmpty {
                    Button {
                        UIPasteboard.general.string = viewModel.transcribedText
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline)
                    }
                }
            }
            
            ScrollView {
                Text(viewModel.transcribedText.isEmpty ? "録音を開始してください" : viewModel.transcribedText)
                    .font(.body)
                    .foregroundStyle(viewModel.transcribedText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            
            // エラー表示
            if let error = viewModel.transcriptionError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 録音履歴セクション
    
    private var recordingHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("録音履歴")
                .font(.headline)
            
            if viewModel.recordings.isEmpty {
                Text("録音履歴がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.recordings) { recording in
                        RecordingRowView(
                            recording: recording,
                            onTranscribe: {
                                Task {
                                    await viewModel.transcribe(audioURL: recording.url)
                                }
                            },
                            onDelete: {
                                viewModel.deleteRecording(recording)
                            }
                        )
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 300)
            }
        }
    }
}

// MARK: - 録音履歴行ビュー

struct RecordingRowView: View {
    let recording: Recording
    let onTranscribe: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.formattedDate)
                        .font(.subheadline)
                    Text(recording.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    onTranscribe()
                } label: {
                    Image(systemName: "text.bubble")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
            
            if let text = recording.transcribedText, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 設定ビュー

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("AmiVoice API") {
                    Text("APIキーとエンジン設定は初期化時に設定してください")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("情報") {
                    LabeledContent("バージョン", value: "1.0.0")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - プレビュー

#Preview {
    RecordingView(apiKey: "YOUR_API_KEY_HERE")
}
