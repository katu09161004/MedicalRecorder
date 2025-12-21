# MedicalRecorder アプリケーション仕様書

**バージョン:** 2.0
**最終更新:** 2025-12-16
**作成者:** Katsuyoshi Fujita

---

## 1. アプリケーション概要

### 1.1 目的
MedicalRecorder は、音声録音から文字起こし、AI要約、クラウド保存までを一貫して行う iOS/watchOS アプリケーションです。医療現場での会議記録、研修内容の記録、診療メモなど、様々な用途に対応します。

### 1.2 主要機能
1. **音声録音** - iPhone/Apple Watch から高品質な音声を録音
2. **文字起こし** - 複数のAI音声認識APIに対応
3. **AI処理** - カスタマイズ可能なプロンプトによる要約・整形
4. **クラウド保存** - GitHub リポジトリへの自動アップロード
5. **Apple Watch 連携** - リモート録音操作

---

## 2. システム構成

### 2.1 対応プラットフォーム

| プラットフォーム | 最小バージョン | 役割 |
|-----------------|---------------|------|
| iOS | 17.0+ | メインアプリ（録音、API通信、データ処理） |
| watchOS | 10.0+ | コンパニオンアプリ（リモート録音操作） |

### 2.2 技術スタック

- **言語:** Swift 5.0
- **UI フレームワーク:** SwiftUI
- **通信:** URLSession, WatchConnectivity
- **音声処理:** AVFoundation
- **データ保存:** UserDefaults

---

## 3. 機能詳細

### 3.1 音声録音

#### 録音仕様
| 項目 | 値 |
|-----|-----|
| フォーマット | M4A (MPEG4 AAC) |
| サンプルレート | 22,050 Hz |
| ビットレート | 64 kbps |
| チャンネル | モノラル |
| 品質 | Medium |

#### 録音機能
- 録音時間のリアルタイム表示
- 録音中の画面スリープ防止
- 電話着信時の自動一時停止
- 長時間録音対応（30分以上は自動分割）

### 3.2 文字起こし API

3つのAPIプロバイダーに対応：

#### さくらのAI (Whisper)
| 項目 | 値 |
|-----|-----|
| エンドポイント | `https://api.ai.sakura.ad.jp/v1/audio/transcriptions` |
| モデル | whisper-large-v3-turbo |
| 最大録音時間 | 30分 |
| 認証方式 | Basic認証 (TokenID:Secret) |
| 分割処理 | 必要（30分超過時自動分割） |

#### Aqua Voice
| 項目 | 値 |
|-----|-----|
| エンドポイント | `https://api.aquavoice.com/api/v1/audio/transcriptions` |
| モデル | avalon-v1-ja |
| 最大録音時間 | 120分 |
| 認証方式 | Bearer Token |
| 分割処理 | 不要 |

#### AmiVoice Cloud
| 項目 | 値 |
|-----|-----|
| エンドポイント | `https://acp-api.amivoice.com/v1/recognize` |
| エンジン | -a-general, -a-medical, -a-business, -a-call |
| 最大録音時間 | 60分 |
| 認証方式 | APIキー（フォームデータ） |
| 分割処理 | 不要 |
| 音声変換 | m4a → WAV (16kHz) 自動変換 |

### 3.3 AI処理（LLM）

文字起こし結果をLLMで処理し、指定されたフォーマットに整形します。

#### LLM仕様
| 項目 | 値 |
|-----|-----|
| プロバイダー | さくらのAI（固定） |
| エンドポイント | `https://api.ai.sakura.ad.jp/v1/chat/completions` |
| モデル | gpt-oss-120b |
| Temperature | 0.7 |
| Max Tokens | 2000 |

### 3.4 カスタムプロンプトシステム（v2.0 新機能）

ユーザーがLLM処理のプロンプトを自由に追加・編集できる機能です。

#### 組み込みプロンプト（5種類）

| 名前 | アイコン | 説明 |
|-----|---------|------|
| 会議の議事録 | person.3.fill | 決定事項、方針、フォローアップを抽出 |
| 教育の研修記録 | book.fill | 学習内容、実践ポイント、参考URLを整理 |
| アイデアメモ | note.text | 誤変換修正、要点整理 |
| 診療記録 | stethoscope | SOAP形式で診療内容を整理 |
| 文字起こしのみ | text.alignleft | AI処理なし、文字起こし結果をそのまま保存 |

#### カスタムプロンプト機能
- **追加:** 新しいプロンプトを自由に作成
- **編集:** 既存のカスタムプロンプトを編集
- **削除:** カスタムプロンプトを削除
- **複製:** 組み込み/カスタムプロンプトをコピーして編集
- **アイコン選択:** 50種類以上のSFSymbolから選択可能

#### プロンプト構造
```swift
struct CustomPrompt {
    var id: UUID              // 一意識別子
    var name: String          // 表示名
    var icon: String          // SFSymbol名
    var description: String   // 短い説明
    var systemPrompt: String  // LLMに送るシステムプロンプト
    var isBuiltIn: Bool       // 組み込みフラグ
    var createdAt: Date       // 作成日時
    var updatedAt: Date       // 更新日時
}
```

### 3.5 GitHub連携

処理結果をGitHubリポジトリに自動保存します。

#### 保存構造
```
{githubPath}/
├── {mode}_{timestamp}.md           # 処理結果（Markdown）
├── raw/
│   └── {mode}_{timestamp}_raw.txt  # 生の文字起こしデータ（オプション）
└── audio/
    └── recording_{timestamp}.m4a   # 音声ファイル（オプション）
```

#### 保存オプション
| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| 生データ保存 | ON | Whisper出力をそのまま保存 |
| 音声ファイル保存 | OFF | 録音したm4aファイルを保存 |

### 3.6 Apple Watch 連携

WatchConnectivity フレームワークを使用した双方向通信。

#### Watch → iPhone
| メッセージ | 説明 |
|-----------|------|
| startRecording | 録音開始リクエスト |
| stopRecording | 録音停止リクエスト |

#### iPhone → Watch
| メッセージ | 説明 |
|-----------|------|
| recordingStatus | 録音状態の通知 |
| progress | 処理進捗（0.0〜1.0） |
| completion | 処理完了（成功/失敗） |

#### 接続チェック
- チェック間隔: 5秒
- 初期チェック: 即時（遅延なし）

---

## 4. データフロー

### 4.1 標準処理フロー

```
┌─────────────┐
│  録音開始   │
└─────┬───────┘
      ▼
┌─────────────┐
│  録音停止   │
└─────┬───────┘
      ▼
┌─────────────────────┐
│  音声ファイル生成   │  recording_{timestamp}.m4a
└─────┬───────────────┘
      ▼
┌─────────────────────┐
│  長さチェック       │
│  30分超過？         │
└─────┬───────────────┘
      │ YES          │ NO
      ▼              ▼
┌──────────┐   ┌──────────┐
│ 分割処理 │   │ 通常処理 │
└────┬─────┘   └────┬─────┘
     └──────┬───────┘
            ▼
┌─────────────────────┐
│  文字起こしAPI      │
│  (さくら/Aqua/Ami)  │
└─────┬───────────────┘
      ▼
┌─────────────────────┐
│  LLM処理            │
│  (カスタムプロンプト)│
└─────┬───────────────┘
      ▼
┌─────────────────────┐
│  GitHub保存         │
│  (MD + オプション)  │
└─────┬───────────────┘
      ▼
┌─────────────────────┐
│  完了通知           │
│  (iPhone/Watch)     │
└─────────────────────┘
```

### 4.2 エラー時の動作

| エラー種別 | 動作 |
|-----------|------|
| 文字起こし失敗 | 音声ファイルのみGitHubに保存（設定ON時） |
| 分割処理失敗 | 音声ファイルのみGitHubに保存（設定ON時） |
| LLM処理失敗 | エラーメッセージ表示、Watch通知 |
| GitHub保存失敗 | エラーメッセージ表示 |

### 4.3 リトライ機能

長時間録音の分割処理時：
- セグメントごとに最大2回リトライ
- タイムアウト: 5分/セグメント

---

## 5. 設定項目

### 5.1 API設定

| 設定項目 | 保存先 | 説明 |
|---------|-------|------|
| transcriptionProvider | UserDefaults | 文字起こしAPIプロバイダー |
| sakuraTokenID | UserDefaults | さくらのAI トークンID |
| sakuraSecret | UserDefaults | さくらのAI シークレット |
| aquaVoiceAPIKey | UserDefaults | Aqua Voice APIキー |
| amiVoiceAPIKey | UserDefaults | AmiVoice APIキー |
| amiVoiceEngine | UserDefaults | AmiVoice エンジン名 |

### 5.2 GitHub設定

| 設定項目 | デフォルト | 説明 |
|---------|-----------|------|
| githubToken | (空) | Personal Access Token |
| githubOwner | (空) | リポジトリオーナー |
| githubRepo | (空) | リポジトリ名 |
| githubBranch | main | ブランチ名 |
| githubPath | recordings | 保存パス |

### 5.3 保存オプション

| 設定項目 | デフォルト | 説明 |
|---------|-----------|------|
| saveRawTranscription | true | 生データを保存 |
| saveAudioFile | false | 音声ファイルを保存 |

### 5.4 プロンプト設定

| 設定項目 | 保存先 | 説明 |
|---------|-------|------|
| customPrompts | UserDefaults (JSON) | ユーザー定義プロンプト |
| selectedPromptId | UserDefaults | 選択中のプロンプトID |

---

## 6. ファイル構成

### 6.1 iPhone アプリ

```
MedicalRecorder/
├── MedicalRecorderApp.swift      # アプリエントリーポイント
├── MainView.swift                # メイン画面
├── SettingsView.swift            # 設定画面
├── Recorder.swift                # 録音エンジン
├── NetworkManager.swift          # API通信
├── WatchConectivityManager.swift # Watch連携
├── AppSettings.swift             # 設定管理
├── TranscriptionProvider.swift   # APIプロバイダー定義
├── ProcessingMode.swift          # 処理モード定義（旧）
├── CustomPromptManager.swift     # カスタムプロンプト管理（新）
├── PromptEditorView.swift        # プロンプト編集画面（新）
├── ModeSelectorView.swift        # モード選択画面（旧）
├── AquaVoiceAPI.swift            # Aqua Voice クライアント
├── AmiVoiceClient.swift          # AmiVoice クライアント
├── AudioConverter.swift          # 音声変換
└── AudioSplitter.swift           # 音声分割
```

### 6.2 Apple Watch アプリ

```
AI Voice Watch App/
├── AI_Voice_WatchApp.swift       # アプリエントリーポイント
└── ContentView.swift             # メイン画面 + ViewModel
```

---

## 7. セキュリティ

### 7.1 認証情報の管理
- すべてのAPIキー/トークンはユーザーが設定画面で入力
- ハードコードされたデフォルト値なし
- UserDefaultsに保存（将来的にKeychainへの移行推奨）

### 7.2 通信
- すべてのAPI通信はHTTPS
- Basic認証、Bearer Token、フォームデータ認証に対応

---

## 8. 変更履歴

### v2.0 (2025-12-16)
- **新機能:** カスタムプロンプトシステム
  - プロンプトの追加・編集・削除・複製
  - 50種類以上のアイコン選択
  - 組み込みプロンプト5種類
- **改善:** 長時間録音処理
  - タイムアウト機能追加（5分/セグメント）
  - リトライ機能追加（最大2回）
  - 失敗時の音声ファイル保存
- **改善:** Apple Watch 接続
  - 接続チェック間隔: 30秒 → 5秒
  - 初期チェック: 即時
  - エラー通知機能追加
- **セキュリティ:** ハードコード認証情報の削除

### v1.0 (2025-11-03)
- 初回リリース

---

## 9. 今後の予定

- [ ] Keychain を使用した認証情報の安全な保存
- [ ] バックグラウンド録音対応
- [ ] iCloud 同期（プロンプト設定）
- [ ] 複数言語対応
- [ ] ローカルLLM対応（オフライン処理）
- [ ] 音声ファイルの直接インポート機能

---

*このドキュメントは MedicalRecorder アプリケーションの公式仕様書です。*
