#!/bin/bash
# Builds, signs and uploads Poddeck to TestFlight on a macOS build machine
# (used by codemagic.yaml; the same steps as .github/workflows/testflight.yml).
#
# Needs: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (the .p8 file's text),
# APPLE_TEAM_ID, and BUILD_NUMBER (must be higher than any build already
# uploaded). Optional: RUN_TESTS=1 to run the PodcastCore tests first.
set -euo pipefail

: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8:?}" "${APPLE_TEAM_ID:?}" "${BUILD_NUMBER:?}"
export BUNDLE_ID=com.gruffaluff.podcasts
export WIDGETS_BUNDLE_ID=com.gruffaluff.podcasts.widgets
WORK="$(mktemp -d)"
KEYS="$WORK/keys"; mkdir -p "$KEYS"
KC="$WORK/signing.keychain-db"
cleanup() {
  rm -rf "$KEYS"
  security delete-keychain "$KC" 2>/dev/null || true
}
trap cleanup EXIT

echo "== Xcode"
xcodebuild -version

if [ "${RUN_TESTS:-0}" = 1 ]; then
  echo "== PodcastCore tests"
  swift test --package-path Packages/PodcastCore 2>&1 | tail -5
fi

echo "== Xcode project"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate

echo "== App Store certificate and profile"
export ASC_KEY_PATH="$KEYS/AuthKey_$ASC_KEY_ID.p8"
printf '%s\n' "$ASC_KEY_P8" > "$ASC_KEY_PATH"
python3 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install --quiet pyjwt cryptography
/usr/bin/openssl genrsa -out "$KEYS/signing.key" 2048 2>/dev/null
/usr/bin/openssl req -new -key "$KEYS/signing.key" -out "$KEYS/signing.csr" -subj "/CN=Poddeck CI/O=Poddeck/C=GB"
"$WORK/venv/bin/python" scripts/asc_signing.py prepare "$KEYS/signing.csr" "$KEYS" > "$WORK/signing.env"
PROFILE_NAME=$(grep '^PROFILE_NAME=' "$WORK/signing.env" | cut -d= -f2-)
PROFILE_UUID=$(grep '^PROFILE_UUID=' "$WORK/signing.env" | cut -d= -f2-)
WIDGETS_PROFILE_NAME=$(grep '^WIDGETS_PROFILE_NAME=' "$WORK/signing.env" | cut -d= -f2-)
WIDGETS_PROFILE_UUID=$(grep '^WIDGETS_PROFILE_UUID=' "$WORK/signing.env" | cut -d= -f2-)

/usr/bin/openssl x509 -inform DER -in "$KEYS/distribution.cer" -out "$KEYS/distribution.pem"
/usr/bin/openssl pkcs12 -export -inkey "$KEYS/signing.key" -in "$KEYS/distribution.pem" -out "$KEYS/signing.p12" -passout pass:ci
security create-keychain -p ci "$KC"
security set-keychain-settings -lut 3600 "$KC"
security unlock-keychain -p ci "$KC"
security import "$KEYS/signing.p12" -k "$KC" -P ci -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -s -k ci "$KC" >/dev/null
security list-keychains -d user -s "$KC" $(security list-keychains -d user | tr -d '"')
security find-identity -v -p codesigning "$KC"
for DIR in "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
  mkdir -p "$DIR"
  cp "$KEYS/profile.mobileprovision" "$DIR/$PROFILE_UUID.mobileprovision"
  cp "$KEYS/widgets.mobileprovision" "$DIR/$WIDGETS_PROFILE_UUID.mobileprovision"
done

echo "== Archive (build $BUILD_NUMBER)"
xcodebuild archive \
  -project Podcasts.xcodeproj \
  -scheme Podcasts \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$WORK/Podcasts.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  PODDECK_PROFILE="$PROFILE_NAME" \
  PODDECK_WIDGETS_PROFILE="$WIDGETS_PROFILE_NAME" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KC" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  > "$WORK/archive.log" 2>&1 || {
    echo "---- last lines ----"; tail -60 "$WORK/archive.log"
    echo "---- errors ----"; grep -E "error:|Provisioning|provisioning|entitlement" "$WORK/archive.log" | sort -u | head -40
    exit 1
  }
grep -E "ARCHIVE SUCCEEDED" "$WORK/archive.log"

echo "== Upload to TestFlight"
OPTS="$WORK/ExportOptions.plist"
cp Config/ExportOptions.plist "$OPTS"
/usr/libexec/PlistBuddy -c "Add :teamID string $APPLE_TEAM_ID" "$OPTS"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$OPTS"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$BUNDLE_ID string $PROFILE_NAME" "$OPTS"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$WIDGETS_BUNDLE_ID string $WIDGETS_PROFILE_NAME" "$OPTS"
xcodebuild -exportArchive \
  -archivePath "$WORK/Podcasts.xcarchive" \
  -exportOptionsPlist "$OPTS" \
  -exportPath "$WORK/export" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
echo "Build $BUILD_NUMBER uploaded. Apple takes about 5–30 minutes to process it."

echo "== What App Store Connect has"
"$WORK/venv/bin/python" scripts/asc_status.py || true
