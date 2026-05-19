#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Formatter"
BUNDLE_ID="com.jaradjohnson.formatter"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
EXECUTABLE="$ROOT/.build/debug/$APP_NAME"
SIGNING_IDENTITY="${FORMATTER_CODESIGN_IDENTITY:-}"

mode="${1:-run}"

stop_running() {
  pkill -x "$APP_NAME" 2>/dev/null || true
}

build_app() {
  cd "$ROOT"
  swift build

  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
  cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"

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
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
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
  <string>Copyright © 2026 Jarad Johnson. Released under the MIT License.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/awk -F '\"' '/Apple Development:/ { print $2; exit }')"
  fi

  if [[ -n "$SIGNING_IDENTITY" ]]; then
    /usr/bin/codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR" >/dev/null
  else
    /usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null
  fi
}

launch_app() {
  /usr/bin/open -n "$APP_DIR"
}

verify_app() {
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
}

case "$mode" in
  run|"")
    stop_running
    build_app
    launch_app
    ;;
  --verify)
    stop_running
    build_app
    launch_app
    verify_app
    ;;
  --logs)
    stop_running
    build_app
    launch_app
    /usr/bin/log stream --style compact --predicate "process == '$APP_NAME'" --info
    ;;
  --telemetry)
    stop_running
    build_app
    launch_app
    /usr/bin/log stream --style compact --predicate "process == '$APP_NAME'" --info
    ;;
  --build)
    stop_running
    build_app
    ;;
  --stop)
    stop_running
    ;;
  *)
    echo "Usage: $0 [--build|--verify|--logs|--telemetry|--stop]" >&2
    exit 64
    ;;
esac
