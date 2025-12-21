//
// ModeSelectorView.swift
// MedicalRecorder
//
// 処理モード選択画面
//

import SwiftUI

struct ModeSelectorView: View {
    @Binding var selectedMode: ProcessingMode
    @Binding var customPrompt: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ProcessingMode.allCases) { mode in
                    Button(action: {
                        selectedMode = mode
                        if mode != .customPrompt {
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // カスタムプロンプト入力欄
                    if mode == .customPrompt && selectedMode == .customPrompt {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("カスタムプロンプト")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $customPrompt)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            
                            Button("設定") {
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("処理モード選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

