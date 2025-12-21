//
//  Recorder.swift
//  MedicalRecorder
//
//  音声録音を管理するクラス
//  無音状態でも継続録音が可能
//  バックグラウンド録音対応
//

import Foundation
import AVFoundation
import Combine
import UIKit

class Recorder: NSObject, ObservableObject {
    // 録音状態の公開プロパティ
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var timerCancellable: AnyCancellable?
    private var audioSessionInterruptionObserver: NSObjectProtocol?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    // 録音ファイルの保存先URL
    var currentRecordingURL: URL? {
        return audioRecorder?.url
    }

    override init() {
        super.init()
        setupAudioSessionObservers()
        setupAppLifecycleObservers()
    }

    deinit {
        // クリーンアップ
        stopRecording()
        timerCancellable?.cancel()
        if let observer = audioSessionInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        endBackgroundTask()
        print("🗑️ Recorder デイニシャライズ")
    }

    // MARK: - アプリライフサイクル監視
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        if isRecording && AppSettings.shared.enableBackgroundRecording {
            beginBackgroundTask()
            print("📱 バックグラウンド録音を継続")
        }
    }

    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        print("📱 フォアグラウンドに復帰")
    }

    // MARK: - バックグラウンドタスク管理
    private func beginBackgroundTask() {
        guard backgroundTaskIdentifier == .invalid else { return }

        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
            // タイムアウト時の処理
            print("⚠️ バックグラウンドタスクがタイムアウトしました")
            self?.endBackgroundTask()
        }

        print("🔄 バックグラウンドタスク開始: \(backgroundTaskIdentifier)")
    }

    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        print("✅ バックグラウンドタスク終了: \(backgroundTaskIdentifier)")
        backgroundTaskIdentifier = .invalid
    }

    // MARK: - オーディオセッション監視
    private func setupAudioSessionObservers() {
        audioSessionInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            switch type {
            case .began:
                // 割り込み開始（電話着信など）
                if self.isRecording {
                    print("⚠️ オーディオ割り込み発生 - 録音を一時停止")
                    _ = self.stopRecording()
                }
            case .ended:
                // 割り込み終了
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        print("✅ オーディオ割り込み終了 - 再開可能")
                    }
                }
            @unknown default:
                break
            }
        }
    }

    // 録音開始
    func startRecording() throws {
        // 自動ロックを無効化（録音中に画面が暗くならないようにする）
        UIApplication.shared.isIdleTimerDisabled = true

        // オーディオセッション設定
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // バックグラウンド録音対応のカテゴリ設定
            var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]

            if AppSettings.shared.enableBackgroundRecording {
                options.insert(.allowBluetooth)
                options.insert(.allowBluetoothA2DP)
            }

            try audioSession.setCategory(.playAndRecord, mode: .default, options: options)
            try audioSession.setActive(true)
        } catch {
            throw RecordingError.audioSessionError(error)
        }

        // 録音ファイルのURL生成（タイムスタンプ付き）
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)

        // 録音設定（AAC形式 - ストレージ節約、アップロード時にWAV変換）
        // AACは最低22050Hzのサンプリングレートが必要
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,  // AAC最低要件
            AVNumberOfChannelsKey: 1,   // モノラル
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 64000  // 64kbps (音声認識には十分)
        ]

        do {
            // レコーダー初期化
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            // 録音開始
            let success = audioRecorder?.record()

            if success == true {
                isRecording = true
                recordingStartTime = Date()

                // バックグラウンドタスク開始
                if AppSettings.shared.enableBackgroundRecording {
                    beginBackgroundTask()
                }

                // タイマー開始（録音時間をカウント）
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self, let startTime = self.recordingStartTime else { return }
                    self.recordingTime = Date().timeIntervalSince(startTime)
                }
            } else {
                throw RecordingError.recordingStartFailed
            }
        } catch {
            throw RecordingError.recorderInitializationError(error)
        }
    }

    // 録音停止
    func stopRecording() -> URL? {
        // 自動ロックを再度有効化
        UIApplication.shared.isIdleTimerDisabled = false

        // バックグラウンドタスク終了
        endBackgroundTask()

        // タイマーの無効化を最初に行う
        recordingTimer?.invalidate()
        recordingTimer = nil
        timerCancellable?.cancel()
        timerCancellable = nil

        // 録音状態を先に変更
        let wasRecording = isRecording
        isRecording = false
        recordingTime = 0
        recordingStartTime = nil

        // 録音停止
        audioRecorder?.stop()
        let url = audioRecorder?.url
        audioRecorder = nil

        // オーディオセッション非アクティブ化（録音していた場合のみ）
        if wasRecording {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("⚠️ オーディオセッション非アクティブ化エラー: \(error.localizedDescription)")
            }
        }

        return url
    }

    // 録音時間を文字列形式で取得
    func formattedRecordingTime() -> String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - 音声ファイルの長さを取得
    static func getAudioDuration(url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)

        guard durationInSeconds.isFinite && durationInSeconds > 0 else {
            return nil
        }

        return durationInSeconds
    }
}

// MARK: - AVAudioRecorderDelegate
extension Recorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("録音が正常に終了しませんでした")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("録音エンコードエラー: \(error.localizedDescription)")
        }
    }
}

// MARK: - エラー定義
enum RecordingError: LocalizedError {
    case audioSessionError(Error)
    case recorderInitializationError(Error)
    case recordingStartFailed

    var errorDescription: String? {
        switch self {
        case .audioSessionError(let error):
            return "オーディオセッションの設定に失敗しました: \(error.localizedDescription)"
        case .recorderInitializationError(let error):
            return "レコーダーの初期化に失敗しました: \(error.localizedDescription)"
        case .recordingStartFailed:
            return "録音の開始に失敗しました"
        }
    }
}
