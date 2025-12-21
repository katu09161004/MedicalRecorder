//
//  MedicalRecorderApp.swift
//  MedicalRecorder
//
//  Created by Katsuyoshi Fujita on 2025/11/03.
//

import SwiftUI
import AVFoundation
import WatchConnectivity

// ✅ iPhone用のContentViewを明確に定義

@main
struct MedicalRecorderApp: App {
    
    init() {
        // アプリ起動時にオーディオセッションカテゴリを設定
        configureAudioSession()
        
        // Watch Connectivity の早期初期化
        initializeWatchConnectivity()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
    
    // MARK: - オーディオセッション初期設定
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            print("✅ オーディオセッション初期設定完了")
        } catch {
            print("❌ オーディオセッション設定エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Watch Connectivity 初期設定
    private func initializeWatchConnectivity() {
        // シングルトンマネージャーの初期化を待機せず、即座に起動
        DispatchQueue.main.async {
            _ = WatchConnectivityManager.shared
            print("✅ Watch Connectivity 初期化完了（アプリ起動時）")
        }
    }
}
