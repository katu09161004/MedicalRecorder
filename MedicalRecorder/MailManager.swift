//
//  MailManager.swift
//  MedicalRecorder
//
//  録音ファイルをメールで送信する機能を提供
//

import Foundation
import MessageUI
import SwiftUI
import Combine

class MailManager: NSObject, ObservableObject {
    static let shared = MailManager()

    @Published var isShowingMailComposer = false
    @Published var mailError: String?

    private var pendingAudioURL: URL?

    private override init() {
        super.init()
    }

    /// メールが設定されているかチェック
    var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// 音声ファイルをメールで送信する準備
    func prepareToSendMail(audioURL: URL) {
        guard canSendMail else {
            mailError = "メールアカウントが設定されていません。設定アプリでメールを設定してください。"
            return
        }

        pendingAudioURL = audioURL
        isShowingMailComposer = true
    }

    /// メール送信用のViewControllerを作成
    func createMailComposeViewController() -> MFMailComposeViewController? {
        guard let audioURL = pendingAudioURL else { return nil }

        let mailVC = MFMailComposeViewController()

        // 件名を設定
        let fileName = audioURL.deletingPathExtension().lastPathComponent
        mailVC.setSubject("【MedicalRecorder】\(fileName)")

        // 本文を設定
        mailVC.setMessageBody("MedicalRecorderから録音ファイルを送信します。\n\nファイル名: \(audioURL.lastPathComponent)", isHTML: false)

        // 添付ファイルを追加
        if let audioData = try? Data(contentsOf: audioURL) {
            let mimeType = getMimeType(for: audioURL)
            mailVC.addAttachmentData(audioData, mimeType: mimeType, fileName: audioURL.lastPathComponent)
        }

        return mailVC
    }

    /// ファイルのMIMEタイプを取得
    private func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "aac":
            return "audio/aac"
        default:
            return "audio/mpeg"
        }
    }

    /// メール送信完了後のクリーンアップ
    func cleanUp() {
        pendingAudioURL = nil
        isShowingMailComposer = false
    }
}

// MARK: - SwiftUI用のメールコンポーザービュー
struct MailComposerView: UIViewControllerRepresentable {
    @ObservedObject var mailManager: MailManager
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailVC = mailManager.createMailComposeViewController() ?? MFMailComposeViewController()
        mailVC.mailComposeDelegate = context.coordinator
        return mailVC
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            switch result {
            case .cancelled:
                print("📧 メール送信がキャンセルされました")
            case .saved:
                print("📧 メールが下書きに保存されました")
            case .sent:
                print("📧 メールが送信されました")
            case .failed:
                if let error = error {
                    print("📧 メール送信エラー: \(error.localizedDescription)")
                    parent.mailManager.mailError = "メールの送信に失敗しました: \(error.localizedDescription)"
                }
            @unknown default:
                break
            }

            parent.mailManager.cleanUp()
            parent.onDismiss?()
        }
    }
}
