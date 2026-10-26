#!/bin/bash
# Builds a Developer ID-signed, notarized, stapled NFCRename.app and zips it for GitHub Releases.
#
# Requires Xcode signed in (Settings → Accounts) to an Apple ID on team 5AVW8WCFJ2 — Xcode
# creates the Developer ID certificate and submits to the notary service with that account.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT=build/release
VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
ARCHIVE="$OUT/NFCRename.xcarchive"
APP="$OUT/export/NFCRename.app"
ZIP="$OUT/NFCRename-$VERSION.zip"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> Archiving NFCRename $VERSION"
xcodegen generate --quiet
xcodebuild archive \
    -project NFCRename.xcodeproj \
    -scheme NFCRename \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -quiet

echo "==> Signing with Developer ID and uploading for notarization"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -exportPath "$OUT/upload" \
    -allowProvisioningUpdates \
    -quiet

echo "==> Waiting for notarization"
until xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$OUT/export" > "$OUT/notarize.log" 2>&1; do
    if grep -qi "invalid\|rejected" "$OUT/notarize.log"; then
        cat "$OUT/notarize.log"
        exit 1
    fi
    sleep 20
done

xcrun stapler validate "$APP"
spctl --assess --type execute --verbose "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP"
echo "==> Done: $ZIP"
