#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Translator"
APP_BUNDLE_NAME="${APP_NAME}.app"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_BUNDLE_NAME}"
DMG_STAGING_DIR="${DIST_DIR}/dmg-staging"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
INFO_PLIST_SOURCE="${ROOT_DIR}/Sources/Translator/Resources/Info.plist"

VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

echo "Building ${APP_NAME} in release mode..."
swift build -c release --package-path "${ROOT_DIR}"

BIN_DIR="$(swift build -c release --show-bin-path --package-path "${ROOT_DIR}")"
BINARY_PATH="${BIN_DIR}/${APP_NAME}"

if [[ ! -x "${BINARY_PATH}" ]]; then
  echo "Release binary not found at ${BINARY_PATH}" >&2
  exit 1
fi

echo "Preparing app bundle..."
rm -rf "${APP_DIR}" "${DMG_STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${INFO_PLIST_SOURCE}" "${APP_DIR}/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${APP_DIR}/Contents/Info.plist"

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "Codesigning app with identity: ${SIGN_IDENTITY}"
  codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_DIR}"
fi

echo "Preparing DMG layout..."
mkdir -p "${DMG_STAGING_DIR}"
cp -R "${APP_DIR}" "${DMG_STAGING_DIR}/${APP_BUNDLE_NAME}"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

echo "Creating DMG..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo
echo "Done."
echo "App: ${APP_DIR}"
echo "DMG: ${DMG_PATH}"
