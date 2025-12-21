//
// LocalLLMManager.swift
// MedicalRecorder
//
// ローカルLLM（Core ML）を使用したオフライン処理
// Appleの機械学習フレームワークを活用
//

import Foundation
import NaturalLanguage
import Combine

// MARK: - ローカルLLM処理結果
struct LocalLLMResult {
    let processedText: String
    let processingTime: TimeInterval
    let modelUsed: String
}

// MARK: - ローカルLLMマネージャー
class LocalLLMManager: ObservableObject {
    static let shared = LocalLLMManager()

    @Published var isProcessing = false
    @Published var availableModels: [LocalLLMModel] = []
    @Published var downloadProgress: Double = 0

    private init() {
        loadAvailableModels()
    }

    // MARK: - 利用可能なモデル一覧
    struct LocalLLMModel: Identifiable {
        let id: String
        let name: String
        let description: String
        let size: String
        let isDownloaded: Bool
    }

    private func loadAvailableModels() {
        // 現在はAppleのNaturalLanguageフレームワークを使用
        // 将来的にCore MLモデルを追加可能
        availableModels = [
            LocalLLMModel(
                id: "apple_nl",
                name: "Apple NaturalLanguage",
                description: "iOS標準の自然言語処理。軽量で高速。",
                size: "内蔵",
                isDownloaded: true
            ),
            LocalLLMModel(
                id: "basic_summarizer",
                name: "基本要約エンジン",
                description: "シンプルなテキスト要約。オフラインで動作。",
                size: "内蔵",
                isDownloaded: true
            )
        ]
    }

    // MARK: - テキスト処理
    func processText(_ text: String, withPrompt prompt: String, modelId: String = "apple_nl") async -> LocalLLMResult {
        isProcessing = true
        let startTime = Date()

        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }

        switch modelId {
        case "apple_nl":
            return await processWithNaturalLanguage(text, prompt: prompt, startTime: startTime)
        case "basic_summarizer":
            return await processWithBasicSummarizer(text, prompt: prompt, startTime: startTime)
        default:
            return await processWithNaturalLanguage(text, prompt: prompt, startTime: startTime)
        }
    }

    // MARK: - Apple NaturalLanguageを使用した処理
    private func processWithNaturalLanguage(_ text: String, prompt: String, startTime: Date) async -> LocalLLMResult {
        var result = text

        // 言語検出
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage ?? .japanese

        // センテンス分割
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]))
            return true
        }

        // プロンプトに基づいて処理
        if prompt.contains("箇条書き") || prompt.contains("要点") {
            // 箇条書き形式に変換
            result = sentences.enumerated().map { index, sentence in
                "- \(sentence.trimmingCharacters(in: .whitespacesAndNewlines))"
            }.joined(separator: "\n")
        } else if prompt.contains("要約") {
            // 重要な文を抽出（シンプルな要約）
            let importantSentences = extractImportantSentences(sentences, count: min(5, sentences.count))
            result = "## 要約\n\n" + importantSentences.map { "- \($0)" }.joined(separator: "\n")
        } else if prompt.contains("SOAP") {
            // SOAP形式のテンプレート
            result = formatAsSOAP(text)
        } else if prompt.contains("議事録") {
            // 議事録形式
            result = formatAsMeetingMinutes(text, sentences: sentences)
        } else {
            // デフォルト：整形のみ
            result = "## 文字起こし結果\n\n" + text
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return LocalLLMResult(
            processedText: result,
            processingTime: processingTime,
            modelUsed: "Apple NaturalLanguage (\(language.rawValue))"
        )
    }

    // MARK: - 基本要約エンジン
    private func processWithBasicSummarizer(_ text: String, prompt: String, startTime: Date) async -> LocalLLMResult {
        // センテンス分割
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        }

        // 重要な文を抽出
        let importantSentences = extractImportantSentences(sentences, count: min(10, sentences.count))

        let result = """
        ## 要約（ローカル処理）

        \(importantSentences.map { "- \($0)" }.joined(separator: "\n"))

        ---
        *この要約はオフラインで処理されました*
        """

        let processingTime = Date().timeIntervalSince(startTime)

        return LocalLLMResult(
            processedText: result,
            processingTime: processingTime,
            modelUsed: "基本要約エンジン"
        )
    }

    // MARK: - 重要文抽出
    private func extractImportantSentences(_ sentences: [String], count: Int) -> [String] {
        // シンプルなヒューリスティック：
        // 1. 長すぎず短すぎない文
        // 2. 重要そうなキーワードを含む文

        let importantKeywords = ["決定", "重要", "必要", "確認", "報告", "対応", "実施", "検討", "承認", "依頼"]

        let scored = sentences.map { sentence -> (String, Int) in
            var score = 0

            // 適切な長さ
            let length = sentence.count
            if length >= 20 && length <= 100 {
                score += 2
            } else if length >= 10 && length <= 150 {
                score += 1
            }

            // キーワードを含む
            for keyword in importantKeywords {
                if sentence.contains(keyword) {
                    score += 3
                }
            }

            return (sentence, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(count)
            .map { $0.0 }
    }

    // MARK: - SOAP形式フォーマット
    private func formatAsSOAP(_ text: String) -> String {
        return """
        ## S (Subjective) - 主訴・自覚症状
        - （文字起こしから抽出された主訴を記載）

        ## O (Objective) - 客観的所見
        - （検査結果、バイタル等を記載）

        ## A (Assessment) - 評価・診断
        - （診断名、病態の評価を記載）

        ## P (Plan) - 治療計画
        - （処方、処置、次回予定を記載）

        ---
        ### 元の文字起こし
        \(text)

        *注意: ローカル処理のため、自動分類は行われていません。上記の項目を手動で編集してください。*
        """
    }

    // MARK: - 議事録形式フォーマット
    private func formatAsMeetingMinutes(_ text: String, sentences: [String]) -> String {
        let importantPoints = extractImportantSentences(sentences, count: min(5, sentences.count))

        return """
        ## 会議記録（ローカル処理）

        ### 主要なポイント
        \(importantPoints.map { "- \($0)" }.joined(separator: "\n"))

        ### 詳細記録
        \(text)

        ---
        *この記録はオフラインで処理されました。クラウドLLMを使用するとより詳細な分析が可能です。*
        """
    }

    // MARK: - ローカルLLMが利用可能か
    var isAvailable: Bool {
        return true // NaturalLanguageフレームワークは常に利用可能
    }
}
