#!/bin/bash
set -e

PROJECT_DIR="/Users/jm/Engineering/snaproute"
cd "$PROJECT_DIR"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/Users/jm"

source ~/.config/ios-signing/.env

AUTH_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_$APPSTORE_KEY_ID.p8"

echo "==> Unlocking codesign keychain..."
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "==> Regenerating Xcode project..."
xcodegen generate

echo "==> Skipping default browser registration (pending approval)..."

echo "==> Archiving with xcodebuild..."
xcodebuild -project SnapRoute.xcodeproj \
  -scheme SnapRoute \
  -configuration Release \
  -archivePath build/ios/archive/SnapRoute.xcarchive \
  archive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$AUTH_KEY_PATH" \
  -authenticationKeyID "$APPSTORE_KEY_ID" \
  -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID" \
  COMPILER_INDEX_STORE_ENABLE=NO

echo "==> Exporting and uploading to TestFlight..."
xcodebuild -exportArchive \
  -archivePath build/ios/archive/SnapRoute.xcarchive \
  -exportOptionsPlist "$PROJECT_DIR/scripts/ExportOptions.plist" \
  -exportPath build/ios/ipa \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$AUTH_KEY_PATH" \
  -authenticationKeyID "$APPSTORE_KEY_ID" \
  -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID"

echo "==> DONE! Build exported and uploaded to TestFlight."
