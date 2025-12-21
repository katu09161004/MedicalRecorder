//
// CustomPromptManager.swift
// MedicalRecorder
//
// カスタムプロンプトの保存・管理
// ユーザーが独自の処理プロンプトを追加・編集・削除できる
// 組み込みプロンプトも編集可能（リセットで初期状態に戻せる）
//

import Foundation
import Combine

// MARK: - カスタムプロンプトモデル
struct CustomPrompt: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String           // プロンプト名（例: "診療記録"）
    var icon: String           // SFSymbol名
    var description: String    // 短い説明
    var systemPrompt: String   // LLMに送るシステムプロンプト
    var isBuiltIn: Bool        // 組み込みプロンプトか（デフォルトプロンプトのID）
    var isCustomized: Bool     // 組み込みプロンプトがカスタマイズされたか
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "doc.text",
        description: String,
        systemPrompt: String,
        isBuiltIn: Bool = false,
        isCustomized: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
        self.isCustomized = isCustomized
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - カスタムプロンプトマネージャー
class CustomPromptManager: ObservableObject {
    static let shared = CustomPromptManager()

    @Published var prompts: [CustomPrompt] = []
    @Published var selectedPromptId: UUID?

    private let userDefaultsKey = "customPrompts"
    private let builtInCustomizedKey = "builtInCustomizedPrompts"
    private let selectedPromptKey = "selectedPromptId"
    private let defaults = UserDefaults.standard

    private init() {
        loadPrompts()
        loadSelectedPrompt()
    }

    // MARK: - 組み込みプロンプト定義
    static let builtInPrompts: [CustomPrompt] = [
        CustomPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "会議の議事録",
            icon: "person.3.fill",
            description: "決定事項、方針、フォローアップ",
            systemPrompt: """
            医療会議の記録を以下の形式で箇条書きにしてください:

            ## 主要な決定事項
            - [決定内容]

            ## 検査・診療方針
            - [方針]

            ## 患者対応
            - [対応内容]

            ## 次回フォローアップ
            - [予定]
            """,
            isBuiltIn: true
        ),
        CustomPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "教育の研修記録",
            icon: "book.fill",
            description: "学習内容、実践ポイント、参考URL",
            systemPrompt: """
            研修・教育記録を以下の形式で整理してください:

            ## 研修テーマ
            - [テーマ名]

            ## 主要な学習内容
            - [内容]

            ## 実践ポイント
            - [実務への応用方法]

            ## 参考資料・URL
            - [関連するURL、文献、ガイドライン等があれば記載]

            ## 今後のアクションアイテム
            - [実践予定、追加学習項目]
            """,
            isBuiltIn: true
        ),
        CustomPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "アイデアメモ",
            icon: "note.text",
            description: "誤変換修正、要点整理",
            systemPrompt: """
            以下のアイデアメモを整理してください:
            - 文脈から明らかな誤変換があれば修正
            - 要点を箇条書きで整理
            - 重要なキーワードを強調
            - 必要に応じてカテゴリ分け

            ## メモ内容
            [整理された内容]
            """,
            isBuiltIn: true
        ),
        CustomPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "診療記録",
            icon: "stethoscope",
            description: "SOAP形式で診療内容を整理",
            systemPrompt: """
            以下の診療内容をSOAP形式で整理してください:

            ## S (Subjective) - 主訴・自覚症状
            - [患者の訴え]

            ## O (Objective) - 客観的所見
            - [検査結果、バイタル等]

            ## A (Assessment) - 評価・診断
            - [診断名、病態の評価]

            ## P (Plan) - 治療計画
            - [処方、処置、次回予定]
            """,
            isBuiltIn: true
        ),
        CustomPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "文字起こしのみ",
            icon: "text.alignleft",
            description: "AI処理なし、文字起こし結果をそのまま保存",
            systemPrompt: """
            以下のテキストをそのまま出力してください。修正や整形は不要です:
            """,
            isBuiltIn: true
        )
    ]

    // MARK: - プロンプト読み込み
    private func loadPrompts() {
        // カスタマイズされた組み込みプロンプトを読み込み
        var customizedBuiltIns: [UUID: CustomPrompt] = [:]
        if let data = defaults.data(forKey: builtInCustomizedKey),
           let customized = try? JSONDecoder().decode([CustomPrompt].self, from: data) {
            for prompt in customized {
                customizedBuiltIns[prompt.id] = prompt
            }
        }

        // 組み込みプロンプト（カスタマイズ版があればそちらを使用）
        var allPrompts: [CustomPrompt] = Self.builtInPrompts.map { original in
            if let customized = customizedBuiltIns[original.id] {
                return customized
            }
            return original
        }

        // ユーザー定義プロンプトを読み込み
        if let data = defaults.data(forKey: userDefaultsKey),
           let userPrompts = try? JSONDecoder().decode([CustomPrompt].self, from: data) {
            allPrompts.append(contentsOf: userPrompts)
        }

        prompts = allPrompts
    }

    // MARK: - 選択中プロンプト読み込み
    private func loadSelectedPrompt() {
        if let idString = defaults.string(forKey: selectedPromptKey),
           let id = UUID(uuidString: idString) {
            selectedPromptId = id
        } else {
            // デフォルトは「アイデアメモ」
            selectedPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")
        }
    }

    // MARK: - ユーザー定義プロンプトのみ保存
    private func saveUserPrompts() {
        let userPrompts = prompts.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(userPrompts) {
            defaults.set(data, forKey: userDefaultsKey)
        }
    }

    // MARK: - カスタマイズされた組み込みプロンプトを保存
    private func saveCustomizedBuiltInPrompts() {
        let customizedBuiltIns = prompts.filter { $0.isBuiltIn && $0.isCustomized }
        if let data = try? JSONEncoder().encode(customizedBuiltIns) {
            defaults.set(data, forKey: builtInCustomizedKey)
        }
    }

    // MARK: - 選択中プロンプト保存
    func selectPrompt(_ id: UUID) {
        selectedPromptId = id
        defaults.set(id.uuidString, forKey: selectedPromptKey)
    }

    // MARK: - 選択中のプロンプトを取得
    var selectedPrompt: CustomPrompt? {
        prompts.first { $0.id == selectedPromptId }
    }

    // MARK: - プロンプト追加
    func addPrompt(_ prompt: CustomPrompt) {
        var newPrompt = prompt
        newPrompt.isBuiltIn = false
        newPrompt.createdAt = Date()
        newPrompt.updatedAt = Date()
        prompts.append(newPrompt)
        saveUserPrompts()
    }

    // MARK: - プロンプト更新
    func updatePrompt(_ prompt: CustomPrompt) {
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            var updatedPrompt = prompt
            updatedPrompt.updatedAt = Date()

            // 組み込みプロンプトの場合はカスタマイズフラグを立てる
            if updatedPrompt.isBuiltIn {
                updatedPrompt.isCustomized = true
            }

            prompts[index] = updatedPrompt

            // 組み込みとユーザー定義で保存先を分ける
            if updatedPrompt.isBuiltIn {
                saveCustomizedBuiltInPrompts()
            } else {
                saveUserPrompts()
            }
        }
    }

    // MARK: - プロンプト削除
    func deletePrompt(_ id: UUID) {
        // 組み込みプロンプトは削除不可
        guard let prompt = prompts.first(where: { $0.id == id }), !prompt.isBuiltIn else {
            return
        }
        prompts.removeAll { $0.id == id }

        // 削除したプロンプトが選択中だった場合、デフォルトに戻す
        if selectedPromptId == id {
            selectedPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")
            defaults.set(selectedPromptId?.uuidString, forKey: selectedPromptKey)
        }

        saveUserPrompts()
    }

    // MARK: - プロンプト複製
    func duplicatePrompt(_ id: UUID) -> CustomPrompt? {
        guard let original = prompts.first(where: { $0.id == id }) else {
            return nil
        }

        let newPrompt = CustomPrompt(
            name: "\(original.name) (コピー)",
            icon: original.icon,
            description: original.description,
            systemPrompt: original.systemPrompt,
            isBuiltIn: false
        )

        addPrompt(newPrompt)
        return newPrompt
    }

    // MARK: - ユーザー定義プロンプトをリセット
    func resetUserPrompts() {
        prompts = Self.builtInPrompts
        defaults.removeObject(forKey: userDefaultsKey)
        defaults.removeObject(forKey: builtInCustomizedKey)
        selectedPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")
        defaults.set(selectedPromptId?.uuidString, forKey: selectedPromptKey)
    }

    // MARK: - 特定の組み込みプロンプトをデフォルトにリセット
    func resetBuiltInPrompt(_ id: UUID) {
        guard let original = Self.builtInPrompts.first(where: { $0.id == id }) else { return }

        if let index = prompts.firstIndex(where: { $0.id == id }) {
            prompts[index] = original
            saveCustomizedBuiltInPrompts()
        }
    }

    // MARK: - 組み込みプロンプトがカスタマイズされているかチェック
    func isBuiltInCustomized(_ id: UUID) -> Bool {
        guard let prompt = prompts.first(where: { $0.id == id }) else { return false }
        return prompt.isBuiltIn && prompt.isCustomized
    }

    // MARK: - オリジナルの組み込みプロンプトを取得
    func getOriginalBuiltInPrompt(_ id: UUID) -> CustomPrompt? {
        return Self.builtInPrompts.first(where: { $0.id == id })
    }
}

// MARK: - 利用可能なアイコン一覧
extension CustomPromptManager {
    static let availableIcons: [String] = [
        "doc.text",
        "doc.text.fill",
        "note.text",
        "list.bullet",
        "list.bullet.rectangle",
        "checklist",
        "text.alignleft",
        "text.quote",
        "book.fill",
        "books.vertical.fill",
        "person.3.fill",
        "person.fill",
        "stethoscope",
        "cross.case.fill",
        "heart.text.square.fill",
        "waveform.path.ecg",
        "brain.head.profile",
        "pills.fill",
        "syringe.fill",
        "bandage.fill",
        "lightbulb.fill",
        "star.fill",
        "bookmark.fill",
        "tag.fill",
        "folder.fill",
        "tray.full.fill",
        "mic.fill",
        "speaker.wave.2.fill",
        "bubble.left.fill",
        "bubble.left.and.bubble.right.fill",
        "phone.fill",
        "video.fill",
        "calendar",
        "clock.fill",
        "alarm.fill",
        "bell.fill",
        "flag.fill",
        "mappin.and.ellipse",
        "house.fill",
        "building.2.fill",
        "briefcase.fill",
        "hammer.fill",
        "wrench.and.screwdriver.fill",
        "gearshape.fill",
        "cpu.fill",
        "desktopcomputer",
        "laptopcomputer",
        "iphone",
        "applewatch"
    ]
}
