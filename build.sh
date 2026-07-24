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

# ===== オプション解析 =====
COMMIT_MSG=""
NO_VERUP=false
while [ $# -gt 0 ]; do
    case "$1" in
        -cm) shift; COMMIT_MSG="$1" ;;
        -noverup) NO_VERUP=true ;;
    esac
    shift || true
done

# バージョン読み込み
VERSION=$(version_read)

# package.json / manifest.json のバージョンを更新
jq ".version = \"${VERSION}\"" package.json > package.json.tmp && mv package.json.tmp package.json
echo "  ✓ package.jsonのバージョンを v${VERSION} に更新しました"
if [ -f manifest.json ]; then
    jq ".version = \"${VERSION}\"" manifest.json > manifest.json.tmp && mv manifest.json.tmp manifest.json
    echo "  ✓ manifest.jsonのバージョンを v${VERSION} に更新しました"
fi

echo "🎨 ${APP_NAME} v${VERSION} をビルド中..."

# 開発サーバーの停止
dev_server_stop $DEV_PORT

# ビルド (vite → build/、デプロイ先へ rsync)
echo "🔨 ビルドを開始します..."
npm run build

mkdir -p "$DEPLOY_DIR"
rsync -a --delete build/ "$DEPLOY_DIR/"
echo "  ✓ ${DEPLOY_DIR}/ にコピーしました"

if [ -f manifest.json ]; then
    cp manifest.json "$DEPLOY_DIR/manifest.json"
    echo "  ✓ manifest.json をデプロイ先にコピーしました"
fi

echo "✅ ビルドが完了しました！"
echo "  📁 デプロイ先: ${DEPLOY_DIR}/"

# FTPアップロード
ftp_upload_dir "$DEPLOY_DIR" "bg-css-gen"

# 次回用バージョン保存
if ! $NO_VERUP; then
    echo ""
    echo "📝 次回用バージョンを更新しています..."
    version_save_next "$VERSION"
fi

# Git コミット
git_commit_build "$VERSION" "$COMMIT_MSG"

# 開発サーバーの再起動
dev_server_restart $DEV_PORT "npm run dev"

echo ""
echo "🎉 ${APP_NAME} v${VERSION} — すべて完了しました！"
