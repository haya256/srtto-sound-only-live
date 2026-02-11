# SRT Audio Streamer - プロジェクト構造

このドキュメントでは、プロジェクトの全体構造とファイルの役割を説明します。

## 📁 ディレクトリ構造

```
srtto-sound-only-live/
├── README.md                          # プロジェクト概要
├── QUICKSTART.md                      # クイックスタートガイド
├── TESTING.md                         # テストガイド
├── DEVELOPMENT.md                     # 開発者向けガイド
├── PROJECT_STRUCTURE.md               # このファイル
├── start-test-server.sh               # テストサーバー起動スクリプト
├── .gitignore                         # Git除外設定
│
├── SRTAudioStreamer.xcodeproj/        # Xcodeプロジェクト
│   └── project.pbxproj                # プロジェクト定義
│
└── SRTAudioStreamer/                  # ソースコード
    ├── Info.plist                     # アプリ設定
    ├── Assets.xcassets/               # アセット
    ├── SRTAudioStreamerApp.swift      # アプリエントリーポイント
    │
    ├── Models/                        # データモデル
    │   ├── StreamState.swift          # 配信状態の定義
    │   └── StreamConfiguration.swift  # SRT設定モデル
    │
    ├── ViewModels/                    # ビジネスロジック
    │   └── StreamViewModel.swift      # 状態管理とロジック
    │
    ├── Views/                         # UI コンポーネント
    │   ├── ContentView.swift          # メイン画面
    │   ├── StreamControlView.swift    # コントロールパネル
    │   └── StreamStatusView.swift     # 状態表示
    │
    ├── Services/                      # ビジネスサービス
    │   └── SRTStreamingService.swift  # SRTストリーミングロジック
    │
    └── Utilities/                     # ユーティリティ
        └── AudioSessionManager.swift  # オーディオセッション管理
```

## 📄 ファイル詳細

### ルートディレクトリ

| ファイル | 役割 | 対象読者 |
|---------|------|----------|
| **README.md** | プロジェクト全体の概要、機能説明、基本的な使い方 | すべてのユーザー |
| **QUICKSTART.md** | 5分で始められる最小限の手順 | 初めてのユーザー |
| **TESTING.md** | 詳細なテストケースと手順 | テスター、QA |
| **DEVELOPMENT.md** | アーキテクチャ、技術詳細、拡張方法 | 開発者 |
| **PROJECT_STRUCTURE.md** | プロジェクト構造の全体像 | 新規開発者 |
| **start-test-server.sh** | FFmpegテストサーバー起動スクリプト | 全ユーザー |
| **.gitignore** | Git管理除外ファイル設定 | 開発者 |

### ソースコード

#### 📱 アプリエントリーポイント

**SRTAudioStreamerApp.swift**
- アプリのエントリーポイント
- `@main`アトリビュート
- SwiftUIのApp構造体
- ContentViewを表示

```swift
@main
struct SRTAudioStreamerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### 📊 Models (データモデル層)

**StreamState.swift** (46行)
- 配信状態の列挙型
- `idle`, `connecting`, `streaming`, `disconnecting`, `error`
- 各状態の説明テキスト
- 状態判定用プロパティ

**StreamConfiguration.swift** (52行)
- SRT設定のデータモデル
- URL, レイテンシー, ビットレート, サンプルレート
- バリデーション機能
- ビットレートプリセット

#### 🎭 ViewModels (プレゼンテーション層)

**StreamViewModel.swift** (112行)
- ObservableObject
- @Published プロパティで状態を公開
- SRTStreamingService との連携
- マイク権限チェック
- UI向けの計算プロパティ

**主要プロパティ:**
- `configuration`: SRT設定
- `currentState`: 現在の配信状態
- `currentBitrate`: 現在のビットレート
- `errorMessage`: エラーメッセージ

**主要メソッド:**
- `startStreaming()`: 配信開始
- `stopStreaming()`: 配信停止
- `updateBitrate()`: ビットレート更新

#### 🖼️ Views (UI層)

**ContentView.swift** (36行)
- メインコンテナView
- NavigationView でラップ
- StreamStatusView と StreamControlView を配置
- StreamViewModel を @StateObject で管理

**StreamControlView.swift** (88行)
- 配信コントロールUI
- SRT URL入力フィールド
- ビットレート選択（セグメント）
- 配信開始/停止ボタン
- 状態に応じた無効化処理

**StreamStatusView.swift** (80行)
- 配信状態の表示
- カラーインジケーター（円）
- ビットレート表示（配信中のみ）
- エラーメッセージ表示

#### ⚙️ Services (サービス層)

**SRTStreamingService.swift** (195行)
- SRTストリーミングのコアロジック
- SRTConnection と SRTStream の管理
- マイク入力のアタッチ
- 配信の開始・停止
- ビットレート監視（Timer使用）
- 状態変更コールバック

**主要メソッド:**
- `startStreaming(configuration:)`: 配信開始
- `stopStreaming()`: 配信停止
- `setupConnectionHandlers()`: 接続イベント設定
- `startBitrateMonitoring()`: ビットレート監視開始

#### 🛠️ Utilities (ユーティリティ層)

**AudioSessionManager.swift** (103行)
- AVAudioSession の管理
- マイク権限の要求
- オーディオセッションの設定
- サンプルレート設定（44.1 kHz）
- セッションのアクティブ化・非アクティブ化

**主要メソッド:**
- `setupAudioSession()`: セッション設定
- `requestMicrophonePermission()`: 権限要求
- `deactivateAudioSession()`: セッション終了

#### 📱 設定ファイル

**Info.plist**
- NSMicrophoneUsageDescription: マイク権限の説明
- UIBackgroundModes: バックグラウンドオーディオ

**Assets.xcassets/**
- AppIcon: アプリアイコン
- AccentColor: アクセントカラー

## 🔄 データフロー

### 配信開始フロー

```
User Tap Button
       ↓
ContentView
       ↓
StreamViewModel.startStreaming()
       ↓
AudioSessionManager.requestMicrophonePermission()
       ↓
SRTStreamingService.startStreaming()
       ↓
AVAudioSession Setup
       ↓
SRTConnection.connect()
       ↓
SRTStream.publish()
       ↓
Callback to ViewModel
       ↓
Update @Published properties
       ↓
UI Updates automatically
```

### 状態更新フロー

```
SRT Connection Event
       ↓
NotificationCenter
       ↓
SRTStreamingService.setupConnectionHandlers()
       ↓
onStateChange callback
       ↓
StreamViewModel updates @Published currentState
       ↓
SwiftUI automatically re-renders StreamStatusView
```

### ビットレート監視フロー

```
Timer (1 second interval)
       ↓
SRTStreamingService.startBitrateMonitoring()
       ↓
Read stream.audioSettings.bitRate
       ↓
onBitrateUpdate callback
       ↓
StreamViewModel updates @Published currentBitrate
       ↓
StreamStatusView displays updated bitrate
```

## 🏗️ アーキテクチャパターン

### MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────────┐
│                     Views                        │
│  (ContentView, StreamControlView, StatusView)   │
└──────────────────┬──────────────────────────────┘
                   │ @ObservedObject
                   │ @Published
                   ↓
┌─────────────────────────────────────────────────┐
│                 ViewModel                        │
│            (StreamViewModel)                     │
│  - @Published properties                         │
│  - Business logic                                │
│  - Coordination                                  │
└──────────────────┬──────────────────────────────┘
                   │ Delegates to
                   ↓
┌─────────────────────────────────────────────────┐
│                 Services                         │
│  (SRTStreamingService, AudioSessionManager)     │
│  - Core business logic                           │
│  - External API integration                      │
└──────────────────┬──────────────────────────────┘
                   │ Uses
                   ↓
┌─────────────────────────────────────────────────┐
│                  Models                          │
│    (StreamState, StreamConfiguration)           │
│  - Data structures                               │
│  - Business rules                                │
└─────────────────────────────────────────────────┘
```

### レイヤー責任

| レイヤー | 責任 | 依存方向 |
|---------|------|----------|
| **Views** | UI表示、ユーザー入力 | → ViewModels |
| **ViewModels** | プレゼンテーションロジック、状態管理 | → Services, Models |
| **Services** | ビジネスロジック、外部API統合 | → Models, Utilities |
| **Utilities** | 共通機能、ヘルパー | → Foundation |
| **Models** | データ構造、ビジネスルール | → None |

## 📊 コード統計

### ファイルサイズ

| ファイル | 行数 | 役割の重要度 |
|---------|------|------------|
| SRTStreamingService.swift | ~195 | ⭐⭐⭐⭐⭐ |
| StreamViewModel.swift | ~112 | ⭐⭐⭐⭐⭐ |
| AudioSessionManager.swift | ~103 | ⭐⭐⭐⭐ |
| StreamControlView.swift | ~88 | ⭐⭐⭐ |
| StreamStatusView.swift | ~80 | ⭐⭐⭐ |
| StreamConfiguration.swift | ~52 | ⭐⭐⭐ |
| StreamState.swift | ~46 | ⭐⭐⭐ |
| ContentView.swift | ~36 | ⭐⭐ |
| SRTAudioStreamerApp.swift | ~16 | ⭐ |

**合計: 約728行**

### 依存関係

```
External Dependencies:
  └── SRTHaishinKit (v2.0.0+)
      └── Swift Package Manager

Internal Dependencies:
  Views
    └── ViewModels
        └── Services
            └── Models
            └── Utilities
```

## 🔍 重要なコンポーネント

### 最も重要な5つのファイル

1. **SRTStreamingService.swift** ⭐⭐⭐⭐⭐
   - SRTストリーミングのコアロジック
   - 配信の開始・停止を管理
   - 最も複雑で重要

2. **StreamViewModel.swift** ⭐⭐⭐⭐⭐
   - UI と Services を接続
   - 状態管理の中心
   - リアクティブな更新

3. **AudioSessionManager.swift** ⭐⭐⭐⭐
   - オーディオ入力の基盤
   - マイク権限管理
   - 必須コンポーネント

4. **StreamState.swift** ⭐⭐⭐
   - 状態の定義
   - アプリ全体で使用
   - 状態遷移の基礎

5. **StreamControlView.swift** ⭐⭐⭐
   - メインのユーザーインタラクション
   - 入力とボタン
   - UXの中心

## 🎯 拡張ポイント

### 新機能を追加する場合

#### 1. 配信履歴機能

**追加ファイル:**
- `Models/StreamHistory.swift` - 履歴データモデル
- `Services/HistoryService.swift` - 履歴管理
- `Views/HistoryView.swift` - 履歴表示UI

**変更ファイル:**
- `StreamViewModel.swift` - 履歴保存ロジック追加
- `ContentView.swift` - 履歴表示ボタン追加

#### 2. 音声レベルメーター

**追加ファイル:**
- `Views/AudioLevelMeterView.swift` - メーター表示
- `Services/AudioLevelMonitor.swift` - レベル監視

**変更ファイル:**
- `SRTStreamingService.swift` - レベル取得ロジック
- `StreamControlView.swift` - メーター配置

#### 3. プリセット設定

**追加ファイル:**
- `Models/StreamPreset.swift` - プリセットモデル
- `Services/PresetService.swift` - プリセット管理
- `Views/PresetSelectionView.swift` - プリセット選択UI

**変更ファイル:**
- `StreamViewModel.swift` - プリセット読み込み
- `StreamControlView.swift` - プリセット選択

## 📚 学習パス

### 初心者向け

1. **README.md** を読む - 全体像を把握
2. **QUICKSTART.md** を実行 - 動作確認
3. **ContentView.swift** を読む - UI構造理解
4. **StreamState.swift** を読む - 状態の定義理解

### 中級者向け

1. **StreamViewModel.swift** を読む - MVVM理解
2. **StreamControlView.swift** を読む - SwiftUI実装
3. **AudioSessionManager.swift** を読む - AVFoundation
4. **TESTING.md** でテスト実施

### 上級者向け

1. **SRTStreamingService.swift** を読む - コアロジック理解
2. **DEVELOPMENT.md** を読む - アーキテクチャ詳細
3. 新機能の実装にチャレンジ
4. パフォーマンス最適化

## 🔗 関連ドキュメント

- **README.md**: 全体概要と機能説明
- **QUICKSTART.md**: 5分で始めるガイド
- **TESTING.md**: テストケースと手順
- **DEVELOPMENT.md**: 開発者向け詳細ガイド

---

このプロジェクト構造は、保守性と拡張性を考慮して設計されています。
質問があれば、GitHubでIssueを作成してください。
