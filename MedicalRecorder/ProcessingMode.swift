//
// ProcessingMode.swift
// MedicalRecorder
//
// 処理モード定義 (会議議事録、研修記録、メモ、カスタムプロンプト)
//

import Foundation

enum ProcessingMode: String, CaseIterable, Identifiable {
    case meetingMinutes = "会議の議事録"
    case trainingRecord = "教育の研修記録"
    case personalMemo = "アイデアメモ"
    case customPrompt = "カスタムプロンプト"
    
    var id: String { self.rawValue }
    
    var systemPrompt: String {
        switch self {
        case .meetingMinutes:
            return """
            医療会議の記録を以下の形式で箇条書きにしてください:
            
            ## 主要な決定事項
            - [決定内容]
            
            ## 検査・診療方針
            - [方針]
            
            ## 患者対応
            - [対応内容]
            
            ## 次回フォローアップ
            - [予定]
            """
            
        case .trainingRecord:
            return """
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
            """
            
        case .personalMemo:
            return """
            以下のアイデアメモを整理してください:
            - 文脈から明らかな誤変換があれば修正
            - 要点を箇条書きで整理
            - 重要なキーワードを強調
            - 必要に応じてカテゴリ分け
            
            ## メモ内容
            [整理された内容]
            """
            
        case .customPrompt:
            return "" // ユーザー入力
        }
    }
    
    var icon: String {
        switch self {
        case .meetingMinutes: return "person.3.fill"
        case .trainingRecord: return "book.fill"
        case .personalMemo: return "note.text"
        case .customPrompt: return "text.cursor"
        }
    }
    
    var description: String {
        switch self {
        case .meetingMinutes: return "決定事項、方針、フォローアップ"
        case .trainingRecord: return "学習内容、実践ポイント、参考URL"
        case .personalMemo: return "誤変換修正、要点整理"
        case .customPrompt: return "自由にプロンプトを記載"
        }
    }
}

