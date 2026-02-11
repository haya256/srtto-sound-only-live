# さぁっと (SRT Audio Streamer)

音声のみをSRT（Secure Reliable Transport）プロトコルで配信するiOSアプリです。iPhoneのマイク音声をSRTサーバーにストリーミングし、低レイテンシーで信頼性の高い音声配信を実現します。

<!-- スクリーンショットを追加する場合は、以下のコメントを解除してください
## スクリーンショット

![アプリ画面](screenshots/app-screenshot.png)
-->

## 特徴

- 🎙️ マイク音声のリアルタイム配信
- 🔒 SRTプロトコルによる信頼性の高い伝送
- ⚡ 低レイテンシー配信（デフォルト120ms）
- 📊 リアルタイムビットレート表示
- 🎚️ ビットレート選択（64/96/128 kbps）
- 📱 iOS 17.0以上対応
- 🎨 シンプルで使いやすいUI

## 必要環境

- Xcode 15.0以上
- iOS 17.0以上のデバイスまたはシミュレーター
- Swift 5.0以上

## セットアップ

### 1. リポジトリをクローン

```bash
git clone https://github.com/haya256/srtto-sound-only-live.git
cd srtto-sound-only-live
```

### 2. プロジェクトを開く

```bash
open SRTAudioStreamer.xcodeproj
```

### 3. 依存関係の解決

Xcodeでプロジェクトを開くと、Swift Package Managerが自動的に依存関係をダウンロードします。

- **SRTHaishinKit.swift** (v2.0.0以上): SRTストリーミング機能を提供

### 4. ビルドと実行

1. Xcodeでターゲットデバイスを選択（実デバイス推奨）
2. Product > Run (⌘R) でアプリをビルド・実行

## プロジェクト構成

```
SRTAudioStreamer/
├── SRTAudioStreamerApp.swift          # アプリエントリーポイント
├── Models/
│   ├── StreamConfiguration.swift      # SRT設定モデル
│   └── StreamState.swift              # 配信状態の定義
├── ViewModels/
│   └── StreamViewModel.swift          # ビジネスロジック・状態管理
├── Views/
│   ├── ContentView.swift              # メイン画面
│   ├── StreamControlView.swift        # 配信コントロールUI
│   └── StreamStatusView.swift         # 状態表示UI
├── Services/
│   └── SRTStreamingService.swift      # SRTストリーミングロジック
└── Utilities/
    └── AudioSessionManager.swift      # AVAudioSession管理
```

## 使い方

### 1. テストサーバーの準備

#### オプション1: FFmpeg（推奨）

```bash
# FFmpegのインストール（初回のみ）
brew install ffmpeg

# SRT受信サーバーを起動
ffmpeg -i srt://0.0.0.0:9710?mode=listener -f null -
```

#### オプション2: OBS Studio

1. OBS Studioをインストール
2. 設定 → 配信 → サービス: カスタム
3. サーバー: `srt://0.0.0.0:9710?mode=listener`

### 2. ネットワーク設定

1. MacのIPアドレスを確認:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

2. iPhoneとMacを同じWi-Fiネットワークに接続

### 3. アプリでの配信

1. アプリを起動
2. 初回起動時、マイク権限を許可
3. SRT URLを入力: `srt://[MacのIP]:9710?mode=caller`
   - 例: `srt://192.168.1.10:9710?mode=caller`
4. ビットレートを選択（デフォルト: 64 kbps）
5. 「配信開始」ボタンをタップ
6. 状態が「配信中」になり、ビットレートが表示されることを確認
7. FFmpeg/OBSで音声が受信されることを確認

### 4. 配信の停止

「配信停止」ボタンをタップして配信を終了します。

## 状態遷移

```
待機中 → 接続中 → 配信中 → 切断中 → 待機中
  ↓                     ↓
エラー ←-----------------┘
```

## 機能説明

### 配信状態インジケーター

- **グレー（待機中）**: 配信待機状態
- **オレンジ（接続中）**: サーバーに接続中
- **グリーン（配信中）**: 正常に配信中
- **レッド（エラー）**: エラー発生

### ビットレート選択

3つのプリセットから選択可能:
- **64 kbps**: 標準品質（推奨）
- **96 kbps**: 高品質
- **128 kbps**: 最高品質

### リアルタイム監視

配信中は1秒ごとにビットレートが更新表示されます。

## トラブルシューティング

### 接続できない

1. MacとiPhoneが同じWi-Fiに接続されているか確認
2. MacのIPアドレスが正しいか確認
3. FFmpeg/OBSが起動しているか確認
4. Macのファイアウォール設定を確認
5. ポート9710が開放されているか確認

### 音声が届かない

1. マイク権限が許可されているか確認
   - 設定 → プライバシーとセキュリティ → マイク
2. アプリの配信状態が「配信中」になっているか確認
3. iPhoneのマイクが正常に動作しているか確認
4. ビットレート表示が更新されているか確認

### エラーメッセージ

- **マイクへのアクセスが許可されていません**: 設定アプリでマイク権限を許可
- **無効なSRT URLです**: URLが `srt://` で始まることを確認
- **オーディオデバイスが見つかりません**: アプリを再起動
- **接続に失敗しました**: サーバー設定とネットワーク接続を確認

## テスト方法

### 基本機能テスト

1. ✅ 初回起動 → マイク権限ダイアログ確認
2. ✅ 配信開始 → 状態遷移確認（待機中 → 接続中 → 配信中）
3. ✅ 配信中 → ビットレート更新確認
4. ✅ 配信停止 → 待機中に戻ることを確認

### エラーハンドリングテスト

5. ✅ 無効なURL入力 → エラーメッセージ確認
6. ✅ 接続失敗 → エラー表示確認
7. ✅ マイク権限拒否 → エラーメッセージ確認

### パフォーマンステスト

8. ✅ 長時間配信（30分〜1時間）
9. ✅ ビットレート切り替え

## アーキテクチャ

### MVVMパターン

- **Model**: `StreamState`, `StreamConfiguration` - データモデル
- **View**: `ContentView`, `StreamControlView`, `StreamStatusView` - UI
- **ViewModel**: `StreamViewModel` - ビジネスロジックと状態管理

### レイヤー構造

1. **Views**: ユーザーインターフェース
2. **ViewModels**: プレゼンテーションロジック
3. **Services**: SRTストリーミングロジック
4. **Utilities**: 共通ユーティリティ（オーディオセッション管理）
5. **Models**: データモデル

## 技術スタック

- **言語**: Swift 5.0
- **フレームワーク**: SwiftUI, AVFoundation, Combine
- **ライブラリ**: SRTHaishinKit.swift
- **プロトコル**: SRT (Secure Reliable Transport)
- **音声処理**: AVAudioSession, AVCaptureDevice
- **ログ**: OSLog (os.log)

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。

### 依存ライブラリ

このプロジェクトは以下のオープンソースライブラリを使用しています:

- **[HaishinKit.swift](https://github.com/shogo4405/HaishinKit.swift)** - BSD 3-Clause License
  - SRTストリーミング機能を提供

各ライブラリのライセンスについては、それぞれのリポジトリを参照してください。

## 貢献

プルリクエストや問題報告を歓迎します。

## 参考資料

- [SRTHaishinKit.swift GitHub](https://github.com/shogo4405/HaishinKit.swift)
- [SRT Alliance](https://www.srtalliance.org/)
- [Apple AVFoundation Documentation](https://developer.apple.com/documentation/avfoundation)

## 今後の拡張案

- [ ] 配信履歴の記録
- [ ] プリセット設定の保存
- [ ] ネットワーク品質の監視
- [ ] バックグラウンド配信の最適化
- [ ] 複数のビットレートでの同時配信
- [ ] 音声レベルメーター
- [ ] 録音機能
