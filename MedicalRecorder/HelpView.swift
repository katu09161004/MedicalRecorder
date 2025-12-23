//
//  HelpView.swift
//  MedicalRecorder
//
//  アプリ内ヘルプ・操作マニュアル表示
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedSection: HelpSection = .overview

    var body: some View {
        NavigationView {
            List {
                ForEach(HelpSection.allCases, id: \.self) { section in
                    NavigationLink(destination: HelpDetailView(section: section)) {
                        HStack(spacing: 12) {
                            Image(systemName: section.icon)
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.body)
                                Text(section.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("ヘルプ")
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

// MARK: - ヘルプセクション定義
enum HelpSection: String, CaseIterable {
    case overview
    case recording
    case mailSend
    case fileManagement
    case settings
    case troubleshooting

    var title: String {
        switch self {
        case .overview: return "アプリ概要"
        case .recording: return "録音機能"
        case .mailSend: return "メール送信"
        case .fileManagement: return "ファイル管理"
        case .settings: return "設定について"
        case .troubleshooting: return "トラブルシューティング"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "MedicalRecorderの基本機能"
        case .recording: return "録音の開始・停止方法"
        case .mailSend: return "録音ファイルをメールで送信"
        case .fileManagement: return "録音一覧と削除"
        case .settings: return "API設定・保存オプション"
        case .troubleshooting: return "よくある問題と解決方法"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "info.circle.fill"
        case .recording: return "mic.circle.fill"
        case .mailSend: return "envelope.fill"
        case .fileManagement: return "folder.fill"
        case .settings: return "gearshape.fill"
        case .troubleshooting: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - ヘルプ詳細ビュー
struct HelpDetailView: View {
    let section: HelpSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー
                HStack {
                    Image(systemName: section.icon)
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text(section.title)
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 8)

                // コンテンツ
                contentView
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var contentView: some View {
        switch section {
        case .overview:
            overviewContent
        case .recording:
            recordingContent
        case .mailSend:
            mailSendContent
        case .fileManagement:
            fileManagementContent
        case .settings:
            settingsContent
        case .troubleshooting:
            troubleshootingContent
        }
    }

    // MARK: - アプリ概要
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MedicalRecorderは、音声録音から文字起こし、AI要約、クラウド保存までを一貫して行うアプリです。")

            HelpCard(title: "主な機能", items: [
                "🎙️ 高品質な音声録音",
                "📝 AIによる文字起こし",
                "🤖 カスタマイズ可能なAI処理",
                "☁️ GitHubへの自動保存",
                "⌚ Apple Watch連携",
                "📧 メールでファイル共有"
            ])

            HelpCard(title: "対応API", items: [
                "さくらのAI（Whisper）",
                "Aqua Voice",
                "AmiVoice Cloud"
            ])
        }
    }

    // MARK: - 録音機能
    private var recordingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpStep(number: 1, title: "録音開始", description: "メイン画面の「録音開始」ボタンをタップします。")
            HelpStep(number: 2, title: "録音中", description: "録音時間がリアルタイムで表示されます。")
            HelpStep(number: 3, title: "録音停止", description: "「録音停止」ボタンをタップすると、自動的に文字起こし処理が開始されます。")

            Divider()

            HelpCard(title: "録音仕様", items: [
                "フォーマット: M4A (AAC)",
                "サンプルレート: 22,050 Hz",
                "ビットレート: 64 kbps",
                "チャンネル: モノラル"
            ])

            HelpTip(text: "30分以上の録音は自動的に分割処理されます。")
        }
    }

    // MARK: - メール送信
    private var mailSendContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("録音ファイルをメールに添付して送信できます。")

            HelpStep(number: 1, title: "録音一覧を開く", description: "メイン画面の「録音一覧」ボタンをタップします。")
            HelpStep(number: 2, title: "ファイルを選択", description: "送信したいファイルの📧アイコンをタップします。")
            HelpStep(number: 3, title: "宛先を入力", description: "メール作成画面で宛先を入力します。件名と本文は自動入力されます。")
            HelpStep(number: 4, title: "送信", description: "「送信」ボタンをタップしてメールを送信します。")

            Divider()

            HelpCard(title: "メール仕様", items: [
                "件名: 【MedicalRecorder】ファイル名",
                "本文: 自動生成（編集可能）",
                "添付: 選択した音声ファイル"
            ])

            HelpCard(title: "対応フォーマット", items: [
                "M4A (audio/mp4)",
                "WAV (audio/wav)",
                "MP3 (audio/mpeg)",
                "AAC (audio/aac)"
            ])

            HelpWarning(text: "メール送信にはiPhoneにメールアカウントの設定が必要です。")
        }
    }

    // MARK: - ファイル管理
    private var fileManagementContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("録音一覧画面でファイルを管理できます。")

            HelpCard(title: "表示される情報", items: [
                "📄 ファイル名",
                "🕐 録音時間",
                "💾 ファイルサイズ",
                "📅 作成日時"
            ])

            Divider()

            Text("ファイルの削除")
                .font(.headline)

            HelpStep(number: 1, title: "スワイプ削除", description: "ファイルを左にスワイプして「削除」をタップします。")

            Text("または")
                .foregroundColor(.secondary)

            HelpStep(number: 2, title: "編集モード", description: "右上の「編集」ボタンをタップして、削除したいファイルを選択します。")

            HelpWarning(text: "削除したファイルは復元できません。重要なファイルはメール送信やバックアップを行ってください。")
        }
    }

    // MARK: - 設定について
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("設定画面で各種APIの設定や保存オプションを変更できます。")

            HelpCard(title: "API設定", items: [
                "文字起こしAPIの選択",
                "さくらのAI認証情報",
                "Aqua Voice APIキー",
                "AmiVoice APIキー"
            ])

            HelpCard(title: "GitHub連携", items: [
                "Personal Access Token",
                "リポジトリ情報",
                "保存パスの設定"
            ])

            HelpCard(title: "保存オプション", items: [
                "文字起こし生データの保存",
                "音声ファイルの保存",
                "iCloud同期"
            ])

            HelpTip(text: "認証情報はKeychainで安全に保存されます。")
        }
    }

    // MARK: - トラブルシューティング
    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TroubleshootItem(
                problem: "メールが送信できない",
                solutions: [
                    "メールアカウントが設定されているか確認",
                    "インターネット接続を確認",
                    "ファイルサイズが添付制限内か確認（通常20-25MB）"
                ]
            )

            TroubleshootItem(
                problem: "録音ファイルが表示されない",
                solutions: [
                    "アプリを再起動",
                    "録音が正常に完了したか確認"
                ]
            )

            TroubleshootItem(
                problem: "文字起こしが失敗する",
                solutions: [
                    "API設定を確認",
                    "インターネット接続を確認",
                    "APIの利用制限を確認"
                ]
            )

            TroubleshootItem(
                problem: "Apple Watchと接続できない",
                solutions: [
                    "BluetoothがONになっているか確認",
                    "iPhoneとWatchが近くにあるか確認",
                    "両方のアプリを再起動"
                ]
            )

            Divider()

            HelpCard(title: "お問い合わせ", items: [
                "GitHubリポジトリでIssueを作成",
                "開発者へ直接連絡"
            ])
        }
    }
}

// MARK: - ヘルプUIコンポーネント

struct HelpCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .font(.body)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct HelpStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct HelpTip: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            Text(text)
                .font(.callout)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HelpWarning: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(text)
                .font(.callout)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TroubleshootItem: View {
    let problem: String
    let solutions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.red)
                Text(problem)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(solutions, id: \.self) { solution in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(solution)
                            .font(.body)
                    }
                }
            }
            .padding(.leading, 28)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - プレビュー
struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
