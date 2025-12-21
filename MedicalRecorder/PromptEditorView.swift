//
// PromptEditorView.swift
// MedicalRecorder
//
// カスタムプロンプトの編集・追加画面
//

import SwiftUI

// MARK: - プロンプト編集画面
struct PromptEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var promptManager = CustomPromptManager.shared

    @State var prompt: CustomPrompt
    let isNewPrompt: Bool

    @State private var showingIconPicker = false
    @State private var showingDeleteAlert = false
    @State private var showingResetAlert = false

    init(prompt: CustomPrompt? = nil) {
        if let prompt = prompt {
            _prompt = State(initialValue: prompt)
            isNewPrompt = false
        } else {
            _prompt = State(initialValue: CustomPrompt(
                name: "",
                icon: "doc.text",
                description: "",
                systemPrompt: ""
            ))
            isNewPrompt = true
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // 基本情報
                Section(header: Text("基本情報")) {
                    HStack {
                        Button(action: { showingIconPicker = true }) {
                            Image(systemName: prompt.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        TextField("プロンプト名", text: $prompt.name)
                            .font(.headline)
                    }

                    TextField("説明（短く）", text: $prompt.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // システムプロンプト
                Section(header: Text("システムプロンプト")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文字起こし結果をどのように処理するか指示を記述してください")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $prompt.systemPrompt)
                            .frame(minHeight: 200)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                // プロンプトのヒント
                Section(header: Text("ヒント")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HintRow(icon: "lightbulb.fill", text: "## や - を使ってMarkdown形式で出力を指定できます")
                        HintRow(icon: "text.quote", text: "[項目名] のようにプレースホルダを使用できます")
                        HintRow(icon: "list.bullet", text: "箇条書きで整理するよう指示すると読みやすくなります")
                    }
                    .font(.caption)
                }

                // 削除ボタン（既存プロンプトかつ非組み込みの場合のみ）
                if !isNewPrompt && !prompt.isBuiltIn {
                    Section {
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("このプロンプトを削除")
                            }
                            .foregroundColor(.red)
                        }
                    }
                }

                // 組み込みプロンプトの場合のリセットボタン
                if prompt.isBuiltIn && prompt.isCustomized {
                    Section {
                        Button(action: { showingResetAlert = true }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("デフォルトに戻す")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }

                // 組み込みプロンプトの場合の注意
                if prompt.isBuiltIn {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("組み込みプロンプトです。編集内容は保存され、いつでもデフォルトに戻せます。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isNewPrompt ? "新規プロンプト" : "プロンプト編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        savePrompt()
                    }
                    .disabled(prompt.name.isEmpty || prompt.systemPrompt.isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $prompt.icon)
            }
            .alert("プロンプトを削除しますか?", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    promptManager.deletePrompt(prompt.id)
                    dismiss()
                }
            } message: {
                Text("この操作は取り消せません。")
            }
            .alert("デフォルトに戻しますか?", isPresented: $showingResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("リセット", role: .destructive) {
                    promptManager.resetBuiltInPrompt(prompt.id)
                    if let original = promptManager.getOriginalBuiltInPrompt(prompt.id) {
                        prompt = original
                    }
                }
            } message: {
                Text("このプロンプトを初期状態に戻します。")
            }
        }
    }

    private func savePrompt() {
        if isNewPrompt {
            promptManager.addPrompt(prompt)
        } else {
            promptManager.updatePrompt(prompt)
        }
        dismiss()
    }
}

// MARK: - ヒント行
struct HintRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - アイコン選択画面
struct IconPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedIcon: String

    let columns = [
        GridItem(.adaptive(minimum: 50))
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(CustomPromptManager.availableIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(selectedIcon == icon ? .white : .blue)
                                .frame(width: 50, height: 50)
                                .background(selectedIcon == icon ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("アイコンを選択")
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

// MARK: - プロンプト一覧・管理画面
struct PromptListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var promptManager = CustomPromptManager.shared

    @State private var showingEditor = false
    @State private var editingPrompt: CustomPrompt?
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            List {
                // 組み込みプロンプト
                Section(header: Text("組み込みプロンプト")) {
                    ForEach(promptManager.prompts.filter { $0.isBuiltIn }) { prompt in
                        PromptRow(prompt: prompt, isSelected: promptManager.selectedPromptId == prompt.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                promptManager.selectPrompt(prompt.id)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    editingPrompt = prompt
                                    showingEditor = true
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button(action: {
                                    editingPrompt = prompt
                                    showingEditor = true
                                }) {
                                    Label("編集", systemImage: "pencil")
                                }

                                Button(action: {
                                    if let duplicated = promptManager.duplicatePrompt(prompt.id) {
                                        editingPrompt = duplicated
                                        showingEditor = true
                                    }
                                }) {
                                    Label("複製して編集", systemImage: "doc.on.doc")
                                }

                                if promptManager.isBuiltInCustomized(prompt.id) {
                                    Divider()
                                    Button(action: {
                                        promptManager.resetBuiltInPrompt(prompt.id)
                                    }) {
                                        Label("デフォルトに戻す", systemImage: "arrow.counterclockwise")
                                    }
                                }
                            }
                    }
                }

                // ユーザー定義プロンプト
                let userPrompts = promptManager.prompts.filter { !$0.isBuiltIn }
                if !userPrompts.isEmpty {
                    Section(header: Text("カスタムプロンプト")) {
                        ForEach(userPrompts) { prompt in
                            PromptRow(prompt: prompt, isSelected: promptManager.selectedPromptId == prompt.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    promptManager.selectPrompt(prompt.id)
                                }
                                .contextMenu {
                                    Button(action: {
                                        editingPrompt = prompt
                                        showingEditor = true
                                    }) {
                                        Label("編集", systemImage: "pencil")
                                    }

                                    Button(action: {
                                        _ = promptManager.duplicatePrompt(prompt.id)
                                    }) {
                                        Label("複製", systemImage: "doc.on.doc")
                                    }

                                    Divider()

                                    Button(role: .destructive, action: {
                                        promptManager.deletePrompt(prompt.id)
                                    }) {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        promptManager.deletePrompt(prompt.id)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }

                                    Button {
                                        editingPrompt = prompt
                                        showingEditor = true
                                    } label: {
                                        Label("編集", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }

                // リセットボタン
                Section {
                    Button(action: { showingResetAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundColor(.orange)
                            Text("カスタムプロンプトをリセット")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("処理モード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingPrompt = nil
                        showingEditor = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let prompt = editingPrompt {
                    PromptEditorView(prompt: prompt)
                } else {
                    PromptEditorView()
                }
            }
            .alert("すべてリセットしますか?", isPresented: $showingResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("リセット", role: .destructive) {
                    promptManager.resetUserPrompts()
                }
            } message: {
                Text("ユーザーが追加したプロンプトは削除され、組み込みプロンプトは初期状態に戻ります。")
            }
        }
    }
}

// MARK: - プロンプト行
struct PromptRow: View {
    let prompt: CustomPrompt
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: prompt.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(prompt.name)
                        .font(.body)

                    if prompt.isBuiltIn {
                        if prompt.isCustomized {
                            Text("編集済")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        } else {
                            Text("組込")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }

                Text(prompt.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - プレビュー
struct PromptEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PromptEditorView()
    }
}

struct PromptListView_Previews: PreviewProvider {
    static var previews: some View {
        PromptListView()
    }
}
