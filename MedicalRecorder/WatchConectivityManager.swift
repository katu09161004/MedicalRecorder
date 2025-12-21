//
// WatchConnectivityManager.swift
// AI Voice to Transcribe Recorder
//
// iPhone ↔ Apple Watch 双方向通信管理
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchConnected = false
    @Published var isWatchReachable = false
    
    private var session: WCSession?
    private let queue = DispatchQueue(label: "com.medicalrecorder.watchconnectivity", qos: .userInitiated)
    
    // 録音コントロール用のクロージャ
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    
    deinit {
        print("🗑️ WatchConnectivityManager デイニシャライズ")
    }
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("✅ Watch Connectivity 初期化完了")
            
            // 初期状態をログ出力
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let session = self.session {
                    print("📱 === iPhone 初期状態チェック ===")
                    print("📱 isSupported: \(WCSession.isSupported())")
                    print("📱 activationState: \(session.activationState.rawValue)")
                    print("📱 isReachable: \(session.isReachable)")
                    print("📱 isPaired: \(session.isPaired)")
                    print("📱 isWatchAppInstalled: \(session.isWatchAppInstalled)")
                    print("📱 =================================")
                }
            }
        } else {
            print("❌ このデバイスはWatch Connectivityをサポートしていません")
        }
    }
    
    // MARK: - Watch にステータス送信
    
    /// 録音状態をWatchに送信
    func sendRecordingStatus(isRecording: Bool) {
        queue.async { [weak self] in
            guard let self = self,
                  let session = self.session,
                  session.isReachable else {
                print("⚠️ Watchに接続されていません")
                return
            }
            
            let message: [String: Any] = [
                "type": "recordingStatus",
                "isRecording": isRecording
            ]
            
            session.sendMessage(message, replyHandler: nil) { error in
                print("❌ Watch送信エラー: \(error.localizedDescription)")
            }
            
            print("📤 Watch に録音状態送信: \(isRecording)")
        }
    }
    
    /// 処理進捗をWatchに送信
    func sendProgress(progress: Double, message: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let session = self.session,
                  session.isReachable else { return }
            
            let data: [String: Any] = [
                "type": "progress",
                "progress": progress,
                "message": message
            ]
            
            session.sendMessage(data, replyHandler: nil, errorHandler: nil)
            print("📤 Watch に進捗送信: \(message) (\(Int(progress * 100))%)")
        }
    }
    
    /// 完了通知をWatchに送信
    func sendCompletion(success: Bool, message: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let session = self.session,
                  session.isReachable else { return }
            
            let data: [String: Any] = [
                "type": "completion",
                "success": success,
                "message": message
            ]
            
            session.sendMessage(data, replyHandler: nil, errorHandler: nil)
            print("✅ Watch に完了通知送信: \(message)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ Watch Connectivity エラー: \(error.localizedDescription)")
                self.isWatchConnected = false
                return
            }
            
            self.isWatchConnected = (activationState == .activated)
            self.isWatchReachable = session.isReachable
            
            if activationState == .activated {
                print("✅ Watch Connectivity アクティベート成功")
                if session.isReachable {
                    print("✅ Watch 到達可能")
                } else {
                    print("⚠️ Watch アクティベート済み（Watch アプリ未起動）")
                }
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            
            print("📱 === 接続状態変化 ===")
            print("📱 activationState: \(session.activationState.rawValue)")
            print("📱 isReachable: \(session.isReachable)")
            print("📱 isPaired: \(session.isPaired)")
            print("📱 isWatchAppInstalled: \(session.isWatchAppInstalled)")
            print("📱 ====================")
            print("📡 Watch 接続状態: \(session.isReachable ? "接続中" : "未接続")")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ Watch セッション非アクティブ")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ Watch セッション無効化")
        session.activate()
    }
    
    // MARK: - Watch からのメッセージ受信
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let type = message["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "startRecording":
                print("📥 Watch から録音開始リクエスト受信")
                self.onStartRecording?()
                
            case "stopRecording":
                print("📥 Watch から録音停止リクエスト受信")
                self.onStopRecording?()
                
            default:
                print("⚠️ 未知のメッセージタイプ: \(type)")
            }
        }
    }
}

