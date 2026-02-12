#!/bin/bash
set -e

# ===== bg-css-gen ビルドスクリプト (Vite + Vue) =====

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="bg-css-gen"
DEV_PORT=5174
DEPLOY_DIR="../apps.tomippe.jp/bg-css-gen"

# 共通スクリプト読み込み
source "$SCRIPT_DIR/../build-common/version.sh"
source "$SCRIPT_DIR/../build-common/ftp-upload.sh"
source "$SCRIPT_DIR/../build-common/dev-server.sh"
source "$SCRIPT_DIR/../build-common/git-commit.sh"

# バージョン読み込み
VERSION=$(version_read)

# package.json のバージョンを更新
jq ".version = \"${VERSION}\"" package.json > package.json.tmp && mv package.json.tmp package.json
echo "  ✓ package.jsonのバージョンを v${VERSION} に更新しました"

echo "🎨 ${APP_NAME} v${VERSION} をビルド中..."

# 開発サーバーの停止
dev_server_stop $DEV_PORT

# ビルド (vite.config.js で outDir が ../apps.tomippe.jp/bg-css-gen に設定済み)
echo "🔨 ビルドを開始します..."
npm run build

echo "✅ ビルドが完了しました！"
echo "  📁 デプロイ先: ${DEPLOY_DIR}/"

# FTPアップロード
ftp_upload_dir "$DEPLOY_DIR" "bg-css-gen"

# 次回用バージョン保存
echo ""
echo "📝 次回用バージョンを更新しています..."
version_save_next "$VERSION"

# Git コミット
git_commit_build "$VERSION"

# 開発サーバーの再起動
dev_server_restart $DEV_PORT "npm run dev"

echo ""
echo "🎉 ${APP_NAME} v${VERSION} — すべて完了しました！"
