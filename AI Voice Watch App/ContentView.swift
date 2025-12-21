//
// ContentView.swift
// AI Voice Watch
//
// Apple Watch 用インターフェース
//

import SwiftUI
import Combine
import WatchConnectivity

struct ContentView: View {
    @StateObject private var viewModel = WatchViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            // ステータス表示
            VStack(spacing: 4) {
                if viewModel.isConnectedToiPhone {
                    HStack(spacing: 4) {
                        Image(systemName: "iphone")
                            .font(.caption2)
                        Text("iPhone 接続中")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                } else {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "iphone.slash")
                                .font(.caption2)
                            Text("iPhone 未接続")
                                .font(.caption2)
                        }
                        .foregroundColor(.red)
                        
                        // 再接続ボタン
                        Button(action: { viewModel.retryConnection() }) {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                Text("再接続")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.mini)
                    }
                }
                
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 録音ボタン
            Button(action: { viewModel.toggleRecording() }) {
                VStack(spacing: 8) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(viewModel.isRecording ? .red : .blue)
                    
                    Text(viewModel.isRecording ? "停止" : "録音")
                        .font(.headline)
                        .foregroundColor(viewModel.isRecording ? .red : .blue)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!viewModel.isConnectedToiPhone || viewModel.isProcessing)
            
            // 進捗バー
            if viewModel.isProcessing {
                VStack(spacing: 4) {
                    ProgressView(value: viewModel.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // 作成者表記
            Text("by K.FUJITA")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - ViewModel

class WatchViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = "待機中"
    @Published var isConnectedToiPhone = false
    
    private var session: WCSession?
    private var connectionCheckTimer: Timer?
    
    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("⌚ Watch Connectivity 初期化")

            // 定期的に接続状態をチェック（5秒ごとに変更）
            connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.checkConnectionStatus()
            }

            // 初期状態を即座にチェック（遅延なし）
            DispatchQueue.main.async {
                if let session = self.session {
                    print("⌚ === 初期状態チェック ===")
                    print("⌚ isSupported: \(WCSession.isSupported())")
                    print("⌚ activationState: \(session.activationState.rawValue)")
                    print("⌚ isReachable: \(session.isReachable)")
                    #if os(iOS)
                    print("⌚ isPaired: \(session.isPaired)")
                    print("⌚ isWatchAppInstalled: \(session.isWatchAppInstalled)")
                    #endif
                    print("⌚ =======================")

                    // 初回接続チェック（即時）
                    self.checkConnectionStatus()
                }
            }
        } else {
            print("❌ Watch Connectivity はサポートされていません")
        }
    }
    
    deinit {
        connectionCheckTimer?.invalidate()
    }
    
    private func checkConnectionStatus() {
        guard let session = session else { return }
        
        DispatchQueue.main.async {
            let isActivated = (session.activationState == .activated)
            self.isConnectedToiPhone = isActivated && session.isReachable
            
            if self.isConnectedToiPhone {
                if self.statusMessage == "iPhoneアプリを起動してください" || self.statusMessage == "接続準備中..." {
                    self.statusMessage = "準備完了"
                }
            } else if isActivated {
                self.statusMessage = "iPhoneアプリを起動してください"
            } else {
                self.statusMessage = "接続準備中..."
            }
            
            print("⌚ 接続チェック: activated=\(isActivated), reachable=\(session.isReachable)")
        }
    }
    
    func toggleRecording() {
        // iPhone 接続チェック
        guard let session = session, session.isReachable else {
            statusMessage = "iPhoneアプリを起動してください"
            return
        }
        
        isRecording.toggle()
        
        // iPhone にメッセージ送信
        let messageType = isRecording ? "startRecording" : "stopRecording"
        let message: [String: Any] = ["type": messageType]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ iPhone送信エラー: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isRecording = false
                self.statusMessage = "送信エラー"
            }
        }
        
        statusMessage = isRecording ? "録音中..." : "処理中..."
        
        print("⌚ 録音リクエスト送信: \(messageType)")
    }
    
    func retryConnection() {
        guard let session = session else { return }
        
        print("⌚ 手動再接続試行")
        
        // セッションを再アクティベート
        if session.activationState != .activated {
            session.activate()
            statusMessage = "接続中..."
        } else {
            // 既にアクティベート済みの場合は状態チェックのみ
            checkConnectionStatus()
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchViewModel: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.isConnectedToiPhone = false
                self.statusMessage = "接続エラー"
                print("⌚ アクティベーションエラー: \(error.localizedDescription)")
                return
            }
            
            // アクティベート成功 + 到達可能性チェック
            let isActivated = (activationState == .activated)
            self.isConnectedToiPhone = isActivated && session.isReachable
            
            if isActivated {
                if session.isReachable {
                    self.statusMessage = "準備完了"
                    print("⌚ アクティベーション成功 & iPhone 到達可能")
                } else {
                    self.statusMessage = "iPhoneアプリを起動してください"
                    print("⌚ アクティベーション成功（iPhone アプリ未起動）")
                }
            } else {
                self.statusMessage = "接続準備中..."
                print("⌚ アクティベーション状態: \(activationState.rawValue)")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            // アクティベート済みかつ到達可能な場合のみ接続とみなす
            let isActivated = (session.activationState == .activated)
            self.isConnectedToiPhone = isActivated && session.isReachable
            
            print("⌚ === 接続状態変化 ===")
            print("⌚ activationState: \(session.activationState.rawValue)")
            print("⌚ isReachable: \(session.isReachable)")
            print("⌚ isConnectedToiPhone: \(self.isConnectedToiPhone)")
            print("⌚ ====================")
            
            if session.isReachable {
                self.statusMessage = "準備完了"
                print("⌚ iPhone 接続: 到達可能になりました")
            } else {
                self.statusMessage = "iPhoneアプリを起動してください"
                print("⌚ iPhone 切断: 到達不可になりました")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let type = message["type"] as? String else { return }
        
        print("⌚ メッセージ受信: \(type)")
        
        DispatchQueue.main.async {
            switch type {
            case "recordingStatus":
                if let isRecording = message["isRecording"] as? Bool {
                    self.isRecording = isRecording
                    self.statusMessage = isRecording ? "録音中..." : "処理中..."
                    print("⌚ 録音状態更新: \(isRecording)")
                }
                
            case "progress":
                if let progress = message["progress"] as? Double,
                   let msg = message["message"] as? String {
                    self.progress = progress
                    self.statusMessage = msg
                    self.isProcessing = true
                    print("⌚ 進捗更新: \(Int(progress * 100))% - \(msg)")
                }
                
            case "completion":
                if let success = message["success"] as? Bool,
                   let msg = message["message"] as? String {
                    self.isProcessing = false
                    self.progress = 0.0
                    self.statusMessage = success ? "✅ \(msg)" : "❌ \(msg)"
                    self.isRecording = false
                    
                    print("⌚ 完了通知: \(msg)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.statusMessage.hasPrefix("✅") || self.statusMessage.hasPrefix("❌") {
                            self.statusMessage = "待機中"
                        }
                    }
                }
                
            default:
                print("⌚ 未知のメッセージ: \(type)")
                break
            }
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

