#!/bin/bash
# StopMeow.app 번들 생성. 사용법: ./scripts/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)"
APP="build/StopMeow.app"

# 프로젝트가 Desktop(iCloud Drive 동기화 대상) 아래 있으면 File Provider 데몬이
# com.apple.FinderInfo/fileprovider 같은 xattr을 계속 다시 붙여서 codesign이
# "resource fork ... not allowed"로 실패한다. iCloud 동기화 안 되는 /tmp에서
# 조립+서명까지 끝내고, 이미 서명된 결과물만 build/로 옮긴다.
STAGING="$(mktemp -d)"
STAGED_APP="$STAGING/StopMeow.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$BIN/StopMeow" "$STAGED_APP/Contents/MacOS/StopMeow"
cp Resources/Info.plist "$STAGED_APP/Contents/Info.plist"
xattr -cr "$STAGED_APP"

# "StopMeow Dev" 로컬 자체서명 인증서로 서명 (없으면 ad-hoc로 폴백).
# ad-hoc(-sign -)은 빌드마다 서명 해시가 달라져서 손쉬운 사용 권한이 매번 풀렸음 —
# 안정된 인증서로 서명해야 권한이 재빌드 후에도 유지됨.
if security find-identity -v -p codesigning 2>/dev/null | grep -q "StopMeow Dev"; then
    codesign --force --sign "StopMeow Dev" "$STAGED_APP"
else
    echo "경고: 'StopMeow Dev' 서명 인증서를 못 찾아 ad-hoc으로 서명합니다 (권한이 빌드마다 풀릴 수 있음)." >&2
    codesign --force --sign - "$STAGED_APP"
fi
codesign --verify --verbose "$STAGED_APP"

rm -rf "$APP"
mkdir -p build
cp -R "$STAGED_APP" "$APP"
rm -rf "$STAGING"

echo "built: $APP"
