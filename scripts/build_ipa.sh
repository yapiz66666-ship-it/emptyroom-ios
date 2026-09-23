#!/bin/bash
# Builds a device .ipa without an Apple developer account. The app and widget are ad-hoc signed
# with their entitlements so the sideloader (Sideloadly / AltStore) keeps the App Group when it
# re-signs them with the user's own Apple ID.
set -euo pipefail
mkdir -p build
set -o pipefail
xcodebuild build \
  -project EmptyRoom.xcodeproj -scheme EmptyRoom -configuration Release \
  -sdk iphoneos -destination "generic/platform=iOS" \
  -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>&1 | tee build/device.log \
  | grep -E "error:|\*\* BUILD"

APP="build/device/Build/Products/Release-iphoneos/EmptyRoom.app"
codesign -f -s - --entitlements Widget/EmptyRoomWidget.entitlements "$APP/PlugIns/EmptyRoomWidget.appex"
codesign -f -s - --entitlements App/EmptyRoom.entitlements "$APP"
codesign -d --entitlements - "$APP" || true

rm -rf build/Payload build/EmptyRoom.ipa
mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry EmptyRoom.ipa Payload)
ls -la build/EmptyRoom.ipa
