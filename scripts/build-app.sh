#!/bin/bash
# StopMeow.app 번들 생성. 사용법: ./scripts/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)"
APP="build/StopMeow.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/StopMeow" "$APP/Contents/MacOS/StopMeow"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# ad-hoc 서명: 로컬 실행 및 Accessibility 권한 부여에 필요
codesign --force --sign - "$APP"

echo "built: $APP"
