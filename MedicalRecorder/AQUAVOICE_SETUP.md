# Aqua Voice (Avalon) API 設定ガイド

## ✅ OpenAI互換APIとして実装済み

Aqua Voice (Avalon) API は OpenAI互換のAPIです。`AquaVoiceAPI.swift` は公式ドキュメントに基づいて実装済みです。

## 📋 実装済みの設定

### 1. **APIエンドポイント**
```swift
private let API_BASE_URL = "https://api.aquavoice.com/api/v1"
```
OpenAI互換のエンドポイント: `/audio/transcriptions`

### 2. **認証方法**
```swift
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
```
OpenAI形式の Bearer Token 認証

### 3. **モデル**
- **日本語**: `avalon-v1-ja`
- **英語**: `avalon-v1-en`

現在の実装では日本語モデル (`avalon-v1-ja`) を使用しています。

### 4. **レスポンス形式**
OpenAI Whisper API互換:
```json
{
  "text": "文字起こし結果"
}
```

## 🧪 使い方

1. **設定画面を開く**
   - アプリ右上の⚙️アイコンをタップ

2. **APIプロバイダーを選択**
   - 「文字起こしAPI」から「Aqua Voice (Avalon)」を選択

3. **APIキーを入力**
   - Aqua Voice APIキー（例: `ava_iRC09NP52BLufmQLl23L10pop2HyuU8ZUpWSvRxfH8k`）

4. **さくらのAI設定も入力**
   - LLM処理（要約・箇条書き）にはさくらのAIを使用するため
   - トークンIDとシークレットキーを入力

5. **テスト録音**
   - 短い録音（5秒程度）でテスト
   - Xcodeコンソールでログを確認
アプリを実行してAqua Voiceで録音すると、Xcodeのコンソールに以下のログが表示されます：

```
📍 リクエストURL: https://...
🔐 Aqua Voice API キー設定完了
📤 Aqua Voice API リクエスト送信: recording_xxx.m4a (xxx KB)
📥 Aqua Voice API レスポンス: 200
📄 レスポンスボディ: {...}
📊 JSONレスポンス: {...}
```

このログから以下を確認してください：
1. **ステータスコード** が `200` かどうか
2. **レスポンスボディ** の内容
3. **JSONレスポンス** のキー名

### よくあるエラーと対処法

#### ❌ ステータスコード 401 (Unauthorized)
→ APIキーが間違っているか、認証方法が正しくない

**対処法:**
1. 設定画面でAPIキーを再確認
2. 認証ヘッダーの形式を確認（Bearer, X-API-Key など）

#### ❌ ステータスコード 404 (Not Found)
→ エンドポイントURLが間違っている

**対処法:**
1. `API_BASE_URL` を確認
2. パスが `/transcribe` で正しいか確認

#### ❌ JSONに'text'キーが見つかりません
→ レスポンスの形式が想定と異なる

**対処法:**
1. コンソールログで「📊 利用可能なキー」を確認
2. `AquaVoiceAPI.swift` のJSONパース部分を修正

## 修正例

### エンドポイントの変更
```swift
// 変更前
private let API_BASE_URL = "https://api.aqua-voice.com/v1"

// 変更後（実際のURLに合わせる）
private let API_BASE_URL = "https://api.aquavoice.jp/v1"
```

### 認証方法の変更
```swift
// Bearer認証の場合
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

// API-Keyヘッダーの場合
request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
```

### レスポンスキーの変更
```swift
// "transcription" キーの場合
if let text = json["transcription"] as? String {
    // ...
}

// ネストされている場合
if let result = json["result"] as? [String: Any],
   let text = result["text"] as? String {
    // ...
}
```

## テスト手順

1. **設定画面で Aqua Voice を選択**
2. **APIキーを入力**
3. **短い録音でテスト**（5秒程度）
4. **Xcodeコンソールでログを確認**
5. **エラーメッセージに基づいて修正**

## 参考リンク

- Aqua Voice 公式ドキュメント: （実際のURLを記入）
- API仕様書: （実際のURLを記入）
- ダッシュボード: （実際のURLを記入）

## サポート

Aqua Voice APIの仕様が不明な場合は、Aqua Voiceのサポートに以下を問い合わせてください：

1. APIエンドポイントURL
2. 認証方法（ヘッダー名と形式）
3. 音声ファイルアップロードのパラメータ名
4. レスポンスのJSON形式
5. サポートされる音声フォーマット（m4a, wav など）
