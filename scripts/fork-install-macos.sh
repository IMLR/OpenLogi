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
# 版本号不变时应用不会重新登记后台服务；删掉登记记录，让它按新签名重新登记，
# 否则 launchd 会因启动约束与签名不符而拒绝启动后台服务
rm -f "$HOME/.local/share/openlogi/registration-version"
open /Applications/OpenLogi.app
echo "已安装：/Applications/OpenLogi.app（签名：$identity）"
