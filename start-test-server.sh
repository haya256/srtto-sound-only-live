#!/bin/bash

# SRT Audio Streamer - テストサーバー起動スクリプト

echo "======================================"
echo "SRT Audio Streamer - Test Server"
echo "======================================"
echo ""

# Check if FFmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ FFmpegがインストールされていません"
    echo ""
    echo "以下のコマンドでインストールしてください:"
    echo "  brew install ffmpeg"
    echo ""
    exit 1
fi

echo "✅ FFmpeg found: $(ffmpeg -version | head -n 1)"
echo ""

# Get local IP address
echo "📡 ネットワーク情報:"
echo "---"
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
if [ -z "$LOCAL_IP" ]; then
    echo "⚠️  IPアドレスが見つかりませんでした"
    echo "Wi-Fiに接続していることを確認してください"
else
    echo "MacのIPアドレス: $LOCAL_IP"
    echo ""
    echo "📱 iPhoneのアプリで以下のURLを入力してください:"
    echo "   srt://$LOCAL_IP:9710?mode=caller"
fi

echo ""
echo "======================================"
echo ""
echo "🎙️  SRT受信サーバーを起動します..."
echo "   ポート: 9710"
echo "   モード: listener"
echo ""
echo "終了するには Ctrl+C を押してください"
echo ""
echo "======================================"
echo ""

# Start FFmpeg SRT listener with audio playback
# Use -f audiotoolbox default to play audio on macOS
ffmpeg -v info -i srt://0.0.0.0:9710?mode=listener -f audiotoolbox default
