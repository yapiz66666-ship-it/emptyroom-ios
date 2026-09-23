#!/bin/bash
# Launches the app built by the test step in the simulator with made-up demo data (-demo) and
# saves screenshots of the main screens to build/screenshots.
set -euo pipefail
UDID="$1"
APP="build/sim/Build/Products/Debug-iphonesimulator/EmptyRoom.app"
OUT="build/screenshots"
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "16:30" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 || true
xcrun simctl install "$UDID" "$APP"

shot() {
  local name="$1" wait="$2"
  shift 2
  xcrun simctl terminate "$UDID" com.csuft.emptyroom 2>/dev/null || true
  xcrun simctl launch "$UDID" com.csuft.emptyroom -demo "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "saved $name.png"
}

shot 1-home 4
shot 2-results 4 -screen results
shot 3-widget 4 -screen widget
shot 4-query 12 -screen query
shot 5-settings 3 -screen settings
