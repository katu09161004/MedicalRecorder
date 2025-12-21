# AmiVoice API セットアップガイド

MedicalRecorderアプリでAmiVoice Cloud APIを使用する方法を説明します。

## ✅ 実装済み機能

このアプリには**AmiVoice Cloud API が既に統合されています**！

以下の3つの文字起こしAPIを切り替えて使用できます：
- 📡 **さくらのAI** (Whisper + GPT)
- 🌊 **Aqua Voice (Avalon)** - OpenAI互換
- 🎙️ **AmiVoice Cloud** - 日本語特化の音声認識 ← NEW!

## 🚀 使い方

### 1. AmiVoice Cloud のアカウントを作成

1. [AmiVoice Cloud Platform](https://acp.amivoice.com/) にアクセス
2. アカウントを作成
3. **APIキー**を取得
4. 使用するエンジンを選択（汎用、医療など）

### 2. アプリで設定

1. アプリの**設定画面**を開く
2. **文字起こしAPI** で「**AmiVoice Cloud**」を選択
3. **AmiVoice Cloud API** セクションで：
   - **APIキー**を入力
   - **エンジン**を選択：
     - `-a-general`（汎用）- デフォルト
     - `-a-medical`（医療）
     - `-a-business`（ビジネス）
     - `-a-call`（コールセンター）
4. **さくらのAI API（LLM処理用）** も設定
   - AmiVoiceは文字起こしのみ
   - 要約・箇条書きはさくらのAIで処理
5. 「**設定を保存**」をタップ

### 3. 使用開始

録音を開始すると、自動的にAmiVoice APIで文字起こしが行われます！


## 📋 利用可能なエンジン

AmiVoice Cloudには複数のエンジンがあります：

| エンジン名 | 説明 | 用途 |
|-----------|------|------|
| `-a-general` | 汎用音声認識 | デフォルト。日常会話や一般的な用途 |
| `-a-medical` | 医療用 | 医療用語に最適化。診療記録など |
| `-a-business` | ビジネス用 | ビジネス用語に最適化。会議など |
| `-a-call` | コールセンター用 | 電話音声に最適化 |

**注意**: 使用できるエンジンは契約プランによって異なります。

## 🔧 技術詳細

### アーキテクチャ

```
音声録音 (Recorder)
    ↓
NetworkManager
    ├─ 文字起こし (プロバイダー選択)
    │   ├─ さくらのAI (Whisper)
    │   ├─ Aqua Voice (Avalon)
    │   └─ AmiVoice Cloud ← ここで実行
    │
    └─ LLM処理 (常にさくらのAI)
        └─ 要約・箇条書き生成
```

### ファイル構成

- **`AmiVoiceClient.swift`**: AmiVoice APIクライアント
- **`NetworkManager.swift`**: 文字起こし処理の統合管理
- **`AppSettings.swift`**: 設定の保存
- **`SettingsView.swift`**: 設定画面UI
- **`TranscriptionProvider.swift`**: プロバイダーの定義

### コード例

設定から値を取得して使用：

```swift
// AppSettings.sharedから自動的に取得
let settings = AppSettings.shared

switch settings.transcriptionProvider {
case .amiVoice:
    let config = AmiVoiceConfig(
        apiKey: settings.amiVoiceAPIKey,
        engineName: settings.amiVoiceEngine,
        endpoint: "https://acp-api.amivoice.com/v1/recognize",
        timeout: 180.0
    )
    
    let client = AmiVoiceClient(config: config)
    let text = try await client.transcribe(audioURL: audioURL)
    print("文字起こし結果: \(text)")
    
default:
    // 他のプロバイダー
    break
}
```

## 🎯 処理フロー

1. **録音** → ユーザーが音声を録音
2. **プロバイダー選択** → 設定で選択したAPIを使用
3. **文字起こし** → AmiVoice APIで音声をテキストに変換
4. **LLM処理** → さくらのAI APIで要約・箇条書き生成
5. **GitHub保存** → 結果をGitHubリポジトリに保存

## ⚙️ カスタマイズ

### エンジンの変更

設定画面でエンジンを変更できます：

- 汎用 (`-a-general`)
- 医療 (`-a-medical`)
- ビジネス (`-a-business`)
- コールセンター (`-a-call`)

### タイムアウトの調整

`NetworkManager.swift` の `transcribeWithAmiVoice` で調整：

```swift
let config = AmiVoiceConfig(
    apiKey: settings.amiVoiceAPIKey,
    engineName: settings.amiVoiceEngine,
    endpoint: "https://acp-api.amivoice.com/v1/recognize",
    timeout: 300.0  // ← ここを変更（秒単位）
)
```


## ❌ エラーハンドリング

### よくあるエラーと対処法

#### 1. "認証に失敗しました"
```
❌ AmiVoice エラー: 認証に失敗しました。APIキーを確認してください
```

**原因**:
- APIキーが間違っている
- APIキーが無効または期限切れ
- 権限がない

**対処法**:
- [AmiVoice Cloud Platform](https://acp.amivoice.com/)でAPIキーを確認
- 新しいAPIキーを発行
- 契約プランを確認

#### 2. "ネットワークエラー"
```
❌ AmiVoice エラー: ネットワークエラー: The Internet connection appears to be offline
```

**対処法**:
- インターネット接続を確認
- Wi-Fiまたはモバイルデータをオン
- VPN設定を確認

#### 3. "文字起こし結果が空"

**原因**:
- 音声ファイルが無音
- 音声品質が低い
- 対応していない言語

**対処法**:
- 音声を再生して確認
- マイクの位置を調整
- ノイズの少ない環境で録音

#### 4. "APIエラー [400]"

**原因**:
- 音声フォーマットが非対応
- ファイルサイズが大きすぎる

**対処法**:
- M4A, WAV, MP3 形式を使用
- 音質設定を下げる（Recorder.swift）

### デバッグ方法

コンソールログを確認：

```
🎙️ AmiVoice Cloud API 呼び出し開始
🔑 APIキー: abcd1234...
⚙️ エンジン: -a-general
✅ AmiVoice 文字起こし完了: 1234文字
```

エラーの場合：

```
❌ AmiVoice エラー: APIエラー [401]: Unauthorized
```


## 🎵 音声フォーマット

### サポートされる形式

- ✅ **M4A (AAC)** - 推奨
- ✅ **WAV**
- ✅ **MP3**

### 推奨設定

```swift
// Recorder.swift の設定
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 16000.0,  // 16kHz
    AVNumberOfChannelsKey: 1,   // モノラル
    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
    AVEncoderBitRateKey: 64000  // 64kbps
]
```

### 制限

| 項目 | 制限 |
|------|------|
| 最大ファイルサイズ | 契約による |
| 最大録音時間 | 60分（推奨） |
| サンプルレート | 8kHz〜48kHz |
| チャンネル | モノラル推奨 |

## 🔒 セキュリティ

### ベストプラクティス

✅ **推奨**:
- APIキーはアプリ内の設定画面で入力
- UserDefaultsに保存（アプリのサンドボックス内）
- コードに直接書かない

❌ **避ける**:
- APIキーをソースコードに埋め込む
- GitHubにAPIキーをプッシュ
- 平文でログ出力

### 実装済みのセキュリティ

このアプリでは：

1. **UserDefaults保存**: APIキーは安全に保存
2. **SecureField**: 設定画面で入力時は非表示
3. **ログ出力**: APIキーの最初の10文字のみ表示

```swift
// 安全なログ出力の例
print("🔑 APIキー: \(settings.amiVoiceAPIKey.prefix(10))...")
// 出力: 🔑 APIキー: abcd123456...
```

## 💰 料金について

AmiVoice Cloud APIは**従量課金制**です：

- 📊 料金は音声の長さに基づく
- 🆓 無料トライアルがある場合もあります
- 💳 契約プランによって価格が異なる

詳細は [AmiVoice Cloud Platform](https://acp.amivoice.com/) で確認してください。

## 🆚 プロバイダー比較

| 機能 | さくらのAI | Aqua Voice | AmiVoice |
|------|-----------|------------|----------|
| 文字起こし | Whisper | Avalon | 独自エンジン |
| 日本語精度 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 医療用語 | △ | ○ | ◎ |
| 処理速度 | 速い | 速い | 速い |
| 長時間対応 | 30分まで | 120分 | 60分 |
| LLM処理 | ○ | - | - |

**注意**: LLM処理（要約・箇条書き）はどのプロバイダーでも**さくらのAI**を使用します。

## 🔗 関連リンク

- [AmiVoice Cloud Platform](https://acp.amivoice.com/)
- [AmiVoice Cloud ドキュメント](https://acp.amivoice.com/main/manual/)
- [AmiVoice サポート](https://acp.amivoice.com/main/support/)

## 📝 ライセンス

AmiVoice APIの使用には、Advanced Media社との契約が必要です。
利用規約をよく読んで使用してください。

## 🎉 完了！

これでAmiVoice APIが使えるようになりました！

### チェックリスト

- ✅ AmiVoice Cloudアカウント作成
- ✅ APIキー取得
- ✅ アプリの設定画面でAPIキーを入力
- ✅ エンジン選択
- ✅ さくらのAI設定（LLM処理用）
- ✅ 録音して確認

問題がある場合は、コンソールログを確認してください！
