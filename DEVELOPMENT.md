# SRT Audio Streamer - 開発ガイド

このドキュメントでは、SRT Audio Streamerアプリの開発に関する技術的な詳細を説明します。

## アーキテクチャ概要

### MVVMパターン

アプリはMVVM（Model-View-ViewModel）パターンで設計されています。

```
┌─────────┐       ┌──────────────┐       ┌────────┐
│  View   │ ───▶ │  ViewModel   │ ───▶ │ Model  │
│ (SwiftUI)│ ◀─── │ (Observable) │ ◀─── │ (Data) │
└─────────┘       └──────────────┘       └────────┘
                         │
                         ▼
                  ┌──────────┐
                  │ Services │
                  └──────────┘
```

### コンポーネント構成

#### Models
- **StreamState.swift**: 配信状態の定義
  - `idle`, `connecting`, `streaming`, `disconnecting`, `error`
- **StreamConfiguration.swift**: SRT設定パラメータ
  - URL, レイテンシー, ビットレート, サンプルレート

#### ViewModels
- **StreamViewModel.swift**: ビジネスロジックと状態管理
  - `@Published`プロパティでUIにリアクティブに状態を通知
  - `SRTStreamingService`との連携
  - エラーハンドリング

#### Views
- **ContentView.swift**: メインコンテナ
- **StreamControlView.swift**: 配信コントロール（URL入力、ビットレート選択、開始/停止ボタン）
- **StreamStatusView.swift**: 状態表示（インジケーター、ビットレート、エラー）

#### Services
- **SRTStreamingService.swift**: SRTストリーミングの実装
  - `SRTConnection`と`SRTStream`の管理
  - マイク入力のアタッチ
  - 配信制御
  - ビットレート監視

#### Utilities
- **AudioSessionManager.swift**: AVAudioSession管理
  - オーディオセッションの設定
  - マイク権限の管理

## 技術スタック

### フレームワーク

- **SwiftUI**: UI構築
- **Combine**: リアクティブプログラミング
- **AVFoundation**: 音声入力とセッション管理
- **OSLog**: ロギング

### 外部ライブラリ

- **SRTHaishinKit.swift**: SRTプロトコル実装
  - GitHub: https://github.com/shogo4405/HaishinKit.swift
  - バージョン: 2.0.0以上

## コアロジック詳細

### 配信開始フロー

```swift
// 1. マイク権限確認
audioSessionManager.requestMicrophonePermission { granted in
    if granted {
        // 2. オーディオセッション設定
        try audioSessionManager.setupAudioSession()

        // 3. SRT接続とストリーム作成
        let connection = SRTConnection()
        let stream = SRTStream(connection: connection)

        // 4. 音声設定
        stream.audioSettings.bitRate = configuration.bitrate
        stream.audioSettings.sampleRate = configuration.sampleRate

        // 5. マイク入力アタッチ
        stream.attachAudio(audioDevice)

        // 6. SRT接続設定
        connection.uri = url
        connection.options.latency = configuration.latency

        // 7. 接続と配信開始
        connection.connect()
        stream.publish()
    }
}
```

### 状態管理

**StreamState**を中心に状態を管理:

```swift
enum StreamState: Equatable {
    case idle              // 待機中
    case connecting        // 接続中
    case streaming         // 配信中
    case disconnecting     // 切断中
    case error(String)     // エラー
}
```

**状態遷移**:
```
idle → connecting → streaming → disconnecting → idle
  ↓                     ↓
error ←─────────────────┘
```

### リアクティブUI更新

```swift
// ViewModelで状態を公開
@Published var currentState: StreamState = .idle
@Published var currentBitrate: Double = 0.0

// Serviceからコールバックで更新
streamingService.onStateChange = { [weak self] state in
    Task { @MainActor in
        self?.currentState = state
    }
}
```

### ビットレート監視

```swift
private func startBitrateMonitoring() {
    bitrateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self = self, let stream = self.stream else { return }
        let currentBitrate = Double(stream.audioSettings.bitRate) / 1000.0
        self.onBitrateUpdate?(currentBitrate)
    }
}
```

## AVFoundation設定

### AVAudioSession設定

```swift
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(
    .playAndRecord,                    // 録音と再生
    mode: .default,
    options: [.defaultToSpeaker, .allowBluetooth]
)
try audioSession.setPreferredSampleRate(44100.0)  // 44.1 kHz
try audioSession.setActive(true)
```

### マイク入力

```swift
if let audioDevice = AVCaptureDevice.default(for: .audio) {
    stream.attachAudio(audioDevice) { error in
        // エラーハンドリング
    }
}
```

## SRT設定

### 基本設定

```swift
connection.uri = URL(string: "srt://192.168.1.10:9710?mode=caller")
connection.options.latency = 120  // ms
```

### 音声エンコード設定

```swift
stream.audioSettings.bitRate = 64000     // 64 kbps
stream.audioSettings.sampleRate = 44100  // 44.1 kHz
```

### URL形式

```
srt://[host]:[port]?mode=[caller|listener]
```

- **caller**: クライアントモード（アプリ側）
- **listener**: サーバーモード（受信側）

## エラーハンドリング

### エラー型定義

```swift
enum StreamingError: LocalizedError {
    case invalidConfiguration(String)
    case permissionDenied
    case audioSessionFailed(String)
    case audioDeviceNotFound
    case invalidURL
    case connectionFailed(String)
}
```

### エラー伝播

```swift
// Service → ViewModel → View
streamingService.onStateChange?(.error("エラーメッセージ"))
```

## ロギング

### OSLogの使用

```swift
import os.log

private let logger = Logger(
    subsystem: "com.example.SRTAudioStreamer",
    category: "SRTStreaming"
)

logger.info("Streaming started")
logger.error("Connection failed: \(error)")
```

### ログレベル

- **info**: 通常の動作ログ
- **warning**: 警告
- **error**: エラー
- **debug**: デバッグ情報

## メモリ管理

### リソース解放

```swift
func stopStreaming() {
    // タイマー停止
    bitrateTimer?.invalidate()
    bitrateTimer = nil

    // ストリーム・接続クローズ
    stream?.close()
    connection?.close()

    // 参照解放
    stream = nil
    connection = nil

    // オーディオセッション非アクティブ化
    audioSessionManager.deactivateAudioSession()
}
```

### weak self の使用

```swift
// クロージャで循環参照を防ぐ
streamingService.onStateChange = { [weak self] state in
    guard let self = self else { return }
    self.currentState = state
}
```

## バックグラウンド対応

### Info.plist設定

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### AVAudioSession設定

```swift
try audioSession.setCategory(
    .playAndRecord,
    mode: .default,
    options: [.defaultToSpeaker, .allowBluetooth]
)
```

## テストとデバッグ

### Xcodeコンソールでのログ確認

```bash
# フィルタリング例
subsystem:com.example.SRTAudioStreamer
category:SRTStreaming
```

### ブレークポイント

重要な箇所:
- `SRTStreamingService.startStreaming()`: 配信開始
- `StreamViewModel.startStreaming()`: UI トリガー
- `setupConnectionHandlers()`: 接続イベント
- `onStateChange`: 状態変更

### メモリデバッグ

Xcodeの「Debug Memory Graph」を使用:
1. 配信開始
2. メモリグラフキャプチャ
3. 配信停止
4. 再度メモリグラフキャプチャ
5. リーク検出

## 拡張ポイント

### 新機能の追加

1. **配信履歴の記録**
   - `Models/StreamHistory.swift`を作成
   - CoreDataやFileManagerで永続化

2. **プリセット設定**
   - `Models/StreamPreset.swift`を作成
   - UserDefaultsで保存

3. **音声レベルメーター**
   - AVAudioRecorderのmetering機能を使用
   - リアルタイム表示

4. **録音機能**
   - AVAudioRecorderを併用
   - ローカルファイルに保存

### カスタマイズ

#### ビットレートプリセットの変更

```swift
// StreamConfiguration.swift
static let bitratePresets: [Int] = [32, 64, 96, 128, 192]
```

#### レイテンシーの変更

```swift
// StreamConfiguration.swift
var latency: Int32 = 120  // デフォルト120ms
```

#### UIカスタマイズ

```swift
// StreamStatusView.swift
private var stateColor: Color {
    // 色のカスタマイズ
}
```

## トラブルシューティング

### よくある問題

#### 1. ビルドエラー: Package not found

**原因**: Swift Package Managerの依存関係が解決されていない

**解決策**:
```
File → Packages → Resolve Package Versions
```

#### 2. 音声が配信されない

**チェック項目**:
- [ ] マイク権限が許可されているか
- [ ] AVAudioSessionが正しく設定されているか
- [ ] AudioDeviceがアタッチされているか
- [ ] SRT URLが正しいか
- [ ] サーバーが起動しているか

#### 3. メモリリーク

**チェック項目**:
- [ ] Timerが適切にinvalidateされているか
- [ ] NotificationObserverが削除されているか
- [ ] クロージャでweak selfを使用しているか
- [ ] Stream/Connectionがクローズされているか

#### 4. バックグラウンドで停止する

**チェック項目**:
- [ ] Info.plistにUIBackgroundModesが設定されているか
- [ ] AVAudioSessionのカテゴリが適切か

## パフォーマンス最適化

### ベストプラクティス

1. **@MainActorの適切な使用**
   - UI更新は必ずメインスレッドで

2. **非同期処理**
   - ネットワーク処理はバックグラウンドで
   - async/awaitを活用

3. **タイマーの最適化**
   - 不要なタイマーは停止
   - 更新頻度を調整（1秒は適切）

4. **メモリ管理**
   - 大きなオブジェクトは適切に解放
   - weak参照で循環参照を防ぐ

## 参考資料

### 公式ドキュメント

- [AVFoundation Programming Guide](https://developer.apple.com/documentation/avfoundation)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)

### SRT関連

- [SRT Alliance](https://www.srtalliance.org/)
- [SRTHaishinKit.swift GitHub](https://github.com/shogo4405/HaishinKit.swift)
- [SRT Protocol Specification](https://github.com/Haivision/srt/blob/master/docs/API.md)

### コーディング規約

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui/state-and-data-flow)

## 貢献ガイドライン

### コードスタイル

- Swift標準のコーディング規約に従う
- 4スペースインデント
- 適切なコメントとドキュメンテーション
- ログ出力の追加

### Pull Requestプロセス

1. 新しいブランチを作成
2. 機能を実装
3. テストを実施
4. PRを作成（説明を詳細に）
5. レビュー対応
6. マージ

## ライセンス

MIT License

---

質問や問題があれば、Issueを作成してください。
