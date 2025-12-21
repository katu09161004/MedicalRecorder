//
// AI_Voice_WatchApp.swift
// AI Voice Watch
//
// Created by Katsuyoshi Fujita on 2025/11/04.
//

import SwiftUI
import WatchConnectivity

@main
struct AI_Voice_WatchApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Extension Delegate

/// アプリ起動時に Watch Connectivity を早期初期化
class ExtensionDelegate: NSObject, WKExtensionDelegate {
    func applicationDidFinishLaunching() {
        print("⌚ === Watch アプリ起動 ===")
        
        // Watch Connectivity の早期初期化
        if WCSession.isSupported() {
            let session = WCSession.default
            session.activate()
            print("⌚ WCSession 早期アクティベーション完了")
            
            // デバッグ情報
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("⌚ activationState: \(session.activationState.rawValue)")
                print("⌚ isReachable: \(session.isReachable)")
            }
        } else {
            print("❌ Watch Connectivity サポートなし")
        }
    }
    
    func applicationDidBecomeActive() {
        print("⌚ アプリがアクティブになりました")
    }
    
    func applicationWillResignActive() {
        print("⌚ アプリが非アクティブになります")
    }
}

