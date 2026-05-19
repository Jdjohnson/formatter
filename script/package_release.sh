#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Formatter"
BUNDLE_ID="com.jaradjohnson.formatter"
VERSION="${FORMATTER_VERSION:-0.1.0}"
BUILD_NUMBER="${FORMATTER_BUILD:-1}"
TEAM_ID="${FORMATTER_TEAM_ID:-}"
RELEASE_DIR="$ROOT/dist/release"
APP_DIR="$RELEASE_DIR/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"
ENTITLEMENTS="$ROOT/Formatter.entitlements"
IDENTITY="${FORMATTER_DEVELOPER_ID_IDENTITY:-}"
NOTARY_PROFILE="${FORMATTER_NOTARY_PROFILE:-}"
SKIP_NOTARIZATION=0

usage() {
  cat <<USAGE
Usage: $0 [--identity "Developer ID Application: ..."] [--notary-profile NAME] [--skip-notarization]

Builds a release app bundle, signs it for direct macOS distribution, submits it
to Apple's notary service, staples the ticket, and writes:

  $ZIP_PATH

Environment overrides:
  FORMATTER_VERSION
  FORMATTER_BUILD
  FORMATTER_TEAM_ID
  FORMATTER_DEVELOPER_ID_IDENTITY
  FORMATTER_NOTARY_PROFILE
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity)
      IDENTITY="${2:-}"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:-}"
      shift 2
      ;;
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

find_developer_id_identity() {
  /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
    | /usr/bin/awk -F '"' '
        /Developer ID Application:/ { print $2; exit }
      '
}

write_info_plist() {
  cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Formatter reads the active browser URL to choose the right formatting rules.</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Formatter uses Accessibility to copy and paste the selected text in the active app.</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>Formatter listens for your configured global formatting hotkey.</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Jarad Johnson. All rights reserved.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

zip_app() {
  rm -f "$ZIP_PATH"
  (cd "$RELEASE_DIR" && /usr/bin/ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH")
}

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(find_developer_id_identity)"
fi

if [[ -z "$IDENTITY" ]]; then
  cat >&2 <<BLOCKER
Release blocker: no "Developer ID Application" signing identity is installed in this keychain.

Install or create one for your Apple Developer team, then rerun:

  $0 --notary-profile FormatterNotary

Current codesigning identities:
BLOCKER
  /usr/bin/security find-identity -v -p codesigning >&2 || true
  exit 78
fi

if [[ "$IDENTITY" != Developer\ ID\ Application:* ]]; then
  cat >&2 <<BLOCKER
Release blocker: the selected signing identity is not a Developer ID Application certificate.

Selected identity:
  $IDENTITY

Direct macOS distribution needs a Developer ID Application certificate, not an
Apple Development, Mac Development, ad hoc, or App Store distribution identity.
BLOCKER
  exit 78
fi

cd "$ROOT"
/usr/bin/swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$ROOT/.build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
write_info_plist

/usr/bin/codesign \
  --force \
  --options runtime \
  --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP_DIR"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"
zip_app

if [[ "$SKIP_NOTARIZATION" -eq 1 ]]; then
  echo "Built signed, unnotarized archive: $ZIP_PATH"
  echo "Skipped notarization by request; this archive is not ready for broad sharing."
  exit 0
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
  team_arg="--team-id TEAM_ID"
  if [[ -n "$TEAM_ID" ]]; then
    team_arg="--team-id $TEAM_ID"
  fi

  cat >&2 <<BLOCKER
Notarization blocker: no notarytool keychain profile was supplied.

Create one once with an app-specific password or App Store Connect API key, for example:

  xcrun notarytool store-credentials FormatterNotary --apple-id APPLE_ID $team_arg --password APP_SPECIFIC_PASSWORD

Then rerun:

  $0 --notary-profile FormatterNotary

Signed archive created but not notarized:
  $ZIP_PATH
BLOCKER
  exit 78
fi

/usr/bin/xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
/usr/bin/xcrun stapler staple "$APP_DIR"
/usr/bin/xcrun stapler validate "$APP_DIR"
zip_app
/usr/sbin/spctl -a -vv "$APP_DIR"

echo "Distribution-ready archive: $ZIP_PATH"
