#!/bin/sh
# 构建正式通道的 OpenLogi.app，用本机的 Apple Development 证书签名，
# 替换 /Applications/OpenLogi.app 并重新启动。说明见 FORK.md。
set -eu

cd "$(dirname "$0")/.."

identity="${OPENLOGI_LOCAL_PRODUCTION_IDENTITY:-}"
if [ -z "$identity" ]; then
    identity=$(security find-identity -v -p codesigning |
        sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -n 1)
fi
if [ -z "$identity" ]; then
    echo "没有找到 Apple Development 证书，请设置 OPENLOGI_LOCAL_PRODUCTION_IDENTITY" >&2
    exit 1
fi
export OPENLOGI_LOCAL_PRODUCTION_IDENTITY="$identity"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
PATH="$(dirname "$(rustup which cargo)"):$PATH"
export PATH

cargo run -p xtask --release -- macos bundle --channel production

app=target/release/bundle/osx/OpenLogi.app
osascript -e 'quit app id "org.openlogi.openlogi"' 2>/dev/null || true
rm -rf /Applications/OpenLogi.app
ditto "$app" /Applications/OpenLogi.app
# 后台服务由 launchd 管理，重启后加载新的程序
launchctl kickstart -k "gui/$(id -u)/org.openlogi.agent.service" 2>/dev/null || true
open /Applications/OpenLogi.app
echo "已安装：/Applications/OpenLogi.app（签名：$identity）"
