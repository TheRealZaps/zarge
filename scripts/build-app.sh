#!/bin/bash
# Builds and signs build/Zarge.app.
#
#   scripts/build-app.sh                  sign with the first Apple Development or Developer ID identity
#   ZARGE_SIGN_IDENTITY="-" scripts/...   ad hoc (the helper then trusts any client named dev.zarge.Zarge)
#
# Identifiers here must match Sources/ZargeCore/HelperProtocol.swift and Resources/.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="dev.zarge.Zarge"
HELPER_ID="$APP_ID.helper"
APP="build/Zarge.app"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Library/LaunchDaemons" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "Resources/$HELPER_ID.plist" "$APP/Contents/Library/LaunchDaemons/"
cp "$BIN/Zarge" "$APP/Contents/MacOS/Zarge"
cp "$BIN/zarge-helper" "$APP/Contents/MacOS/zarge-helper"

# Icon Composer icon -> Assets.car (Liquid Glass, dark/clear/tinted) plus a Zarge.icns fallback.
# Absolute paths: actool hands the job to a long-lived helper that resolves relative paths
# against whatever directory it was first started from, not this one.
xcrun actool "$PWD/Resources/Zarge.icon" --compile "$PWD/$APP/Contents/Resources" \
  --platform macosx --target-device mac --minimum-deployment-target 26.0 --app-icon Zarge \
  --output-partial-info-plist "$PWD/build/icon-partial.plist" --output-format human-readable-text >/dev/null

IDENTITY="${ZARGE_SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application|Apple Development/ { print $2; exit }')}"
IDENTITY="${IDENTITY:--}"

# Developer ID builds get a secure timestamp, which notarization requires.
SIGN=(codesign --force --options runtime --sign "$IDENTITY")
if [[ "$IDENTITY" == "Developer ID Application"* ]]; then
  SIGN+=(--timestamp)
fi

# Inside out: the helper first, then the bundle that seals it.
"${SIGN[@]}" --identifier "$HELPER_ID" "$APP/Contents/MacOS/zarge-helper"
"${SIGN[@]}" "$APP"
codesign --verify --strict --deep "$APP"

echo "Built $APP, signed with: $IDENTITY"
