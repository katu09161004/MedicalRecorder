# MedicalRecorder 開発スレッドサマリー

**日付**: 2025年12月16日 - 2025年12月19日

---

## 概要

MedicalRecorderアプリ（iOS/watchOS医療録音アプリ）のバグ修正と機能追加を行いました。

---

## 1. 初期調査

### 1.1 リポジトリ構造
- **メインリポジトリ**: `/Users/mars/MedicalRecorder`
- **Worktree**: `/Users/mars/.claude-worktrees/MedicalRecorder/objective-faraday`（基本テンプレートのみ）

### 1.2 アプリ構成
- **iPhone版**: MedicalRecorder（音声録音・文字起こし・LLM処理・GitHub保存）
- **Apple Watch版**: AI Voice Watch（録音・iPhoneとの連携）

---

## 2. 報告されたバグ

### 2.1 長時間録音の問題
- **症状**: 長時間録音すると文字起こし処理が失敗する
- **原因**: タイムアウト設定がなく、大きなファイルで処理が止まる

### 2.2 音声ファイルの喪失
- **症状**: 文字起こし失敗時に音声ファイルが削除される
- **要望**: 音声ファイルは常に保存されるようにしたい

### 2.3 Apple Watch接続問題
- **症状**: Apple Watchで「未接続」と表示される
- **原因**: ポーリング間隔が30秒と長すぎる

---

## 3. 実施した修正

### 3.1 NetworkManager.swift
```swift
// タイムアウト設定（5分）
private func withTaskTimeoutResult<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T?

// リトライ機能（2回）
// 音声ファイル保存の保証（失敗時も保持）
```

### 3.2 AI Voice Watch App/ContentView.swift
```swift
// ポーリング間隔: 30秒 → 5秒
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true)

// 初期チェック: 即座に実行
checkiPhoneConnection()
```

### 3.3 MainView.swift
- Watch連携のエラー通知追加
- CustomPromptManagerの統合

### 3.4 AppSettings.swift
- ハードコードされたAPIキー・認証情報の削除（セキュリティ修正）

---

## 4. 新機能: カスタムプロンプトシステム

### 4.1 CustomPromptManager.swift（新規作成）
LLM処理プロンプトの管理機能:

- **組み込みプロンプト**（5種類）:
  1. 会議の議事録
  2. 教育の研修記録
  3. アイデアメモ
  4. 診療記録（SOAP形式）
  5. 文字起こしのみ

- **機能**:
  - ユーザー定義プロンプトの追加・編集・削除
  - 組み込みプロンプトの名前・内容の編集
  - 編集した組み込みプロンプトをデフォルトにリセット
  - プロンプトの複製
  - アイコン選択

### 4.2 PromptEditorView.swift（新規作成）
プロンプト編集UI:

- プロンプト一覧表示（PromptListView）
- プロンプト編集画面（PromptEditorView）
- アイコン選択画面（IconPickerView）
- スワイプ操作での編集・削除
- コンテキストメニュー対応

### 4.3 NetworkManager.swift追加メソッド
```swift
func uploadAndTranscribeWithPrompt(audioURL: URL, systemPrompt: String, completion: @escaping (Bool) -> Void)
```

### 4.4 SettingsView.swift更新
- 「AI処理モード」セクション追加
- PromptListViewへのナビゲーション

---

## 5. ドキュメント作成

### 5.1 SPECIFICATION.md
アプリの完全な仕様書:
- 基本情報
- アーキテクチャ
- 機能詳細
- データフロー
- API連携
- ファイル構成
- 設定項目
- 技術仕様

### 5.2 CHANGELOG_2025-12-16.md
修正内容の詳細な記録

---

## 6. Xcodeビルドエラーの解決

### 6.1 問題
```
Attempted to install `.app` which is not a .app bundle
```

### 6.2 原因
1. 新規Swiftファイルのパーミッションが制限的（`-rw-------`）
2. `PRODUCT_NAME`が空文字に設定されていた

### 6.3 解決策
```bash
# パーミッション修正
chmod 644 CustomPromptManager.swift PromptEditorView.swift NetworkManager.swift

# Xcodeキャッシュクリア
rm -rf ~/Library/Developer/Xcode/DerivedData/MedicalRecorder-*
```

### 6.4 project.pbxproj修正
```
PRODUCT_NAME = "";  →  PRODUCT_NAME = "AI Voice Watch";
```

---

## 7. 組み込みプロンプト編集機能

### 7.1 実装済み機能
組み込みプロンプトは以下の操作で編集可能:

1. **スワイプ操作**: 左スワイプで「編集」ボタン表示
2. **長押し（コンテキストメニュー）**:
   - 編集
   - 複製して編集
   - デフォルトに戻す（編集済みの場合）

3. **編集後の表示**:
   - 「編集済」バッジが表示される
   - いつでも「デフォルトに戻す」が可能

### 7.2 データ保存
```swift
// 組み込みプロンプトのカスタマイズ内容は別キーで保存
private let builtInCustomizedKey = "builtInCustomizedPrompts"
```

---

## 8. ファイル一覧

### 新規作成
| ファイル | 説明 |
|---------|------|
| `CustomPromptManager.swift` | プロンプト管理クラス |
| `PromptEditorView.swift` | プロンプト編集UI |
| `SPECIFICATION.md` | アプリ仕様書 |
| `CHANGELOG_2025-12-16.md` | 変更履歴 |

### 修正
| ファイル | 修正内容 |
|---------|----------|
| `NetworkManager.swift` | タイムアウト、リトライ、カスタムプロンプト対応 |
| `MainView.swift` | カスタムプロンプト統合 |
| `SettingsView.swift` | AI処理モードセクション追加 |
| `AppSettings.swift` | 認証情報削除 |
| `AI Voice Watch App/ContentView.swift` | ポーリング間隔改善 |
| `project.pbxproj` | PRODUCT_NAME修正 |

---

## 9. 使い方

### カスタムプロンプトの設定
1. アプリの「設定」を開く
2. 「AI処理モード」をタップ
3. 使用したいプロンプトをタップして選択
4. 組み込みプロンプトを編集する場合:
   - 左スワイプ → 「編集」
   - または長押し → 「編集」
5. 新しいプロンプトを追加する場合:
   - 右上の「+」ボタンをタップ

### 実行スキームの選択
- **MedicalRecorder**: iPhoneアプリを実行
- **AI Voice Watch**: Watchアプリを実行（単体では動作しない）

---

## 10. 技術的な注意点

### PBXFileSystemSynchronizedRootGroup
Xcode 15以降の新機能。`MedicalRecorder`フォルダ内のファイルは自動的にプロジェクトに追加される。

### UserDefaultsキー
```swift
"customPrompts"              // ユーザー定義プロンプト
"builtInCustomizedPrompts"   // カスタマイズされた組み込みプロンプト
"selectedPromptId"           // 選択中のプロンプトID
```

---

## 11. 今後の改善提案

1. **音声分割処理の最適化**: 長時間録音を小さなチャンクに分割して処理
2. **オフライン対応**: ネットワーク不可時のキューイング
3. **iCloud同期**: カスタムプロンプトのデバイス間同期
4. **プロンプトのインポート/エクスポート**: JSON形式での共有機能
