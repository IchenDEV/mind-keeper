#!/usr/bin/env bash
#
# build-app.sh — Build Mind Keeper.app and package as DMG
#
# Usage:
#   ./scripts/build-app.sh                        # build .app + .dmg
#   ./scripts/build-app.sh --app-only             # build .app only
#   ./scripts/build-app.sh --version=1.0.0        # set version
#   ./scripts/build-app.sh --sign=IDENTITY        # code signing identity
#

set -euo pipefail

APP_NAME="Mind Keeper"
SCHEME="MindKeeper"

if [ -z "${VERSION:-}" ]; then
    VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0-dev")"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DERIVED_DATA="${PROJECT_DIR}/.build/xcode"
BUILD_DIR="${DERIVED_DATA}/Build/Products/Release"
DIST_DIR="${PROJECT_DIR}/dist"
APP_ONLY=false
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

for arg in "$@"; do
    case "$arg" in
        --app-only)  APP_ONLY=true ;;
        --version=*) VERSION="${arg#*=}" ;;
        --sign=*)    SIGN_IDENTITY="${arg#*=}" ;;
        --help|-h)
            echo "Usage: $0 [--version=X.Y.Z] [--app-only] [--sign=IDENTITY]"
            exit 0
            ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_NAME="MindKeeper-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

step() { echo ""; echo "▶ $1"; }
done_msg() { echo "  ✓ $1"; }

# ── Step 1: Generate Xcode project ──────────────────────────────

step "Generating Xcode project (XcodeGen)…"
cd "${PROJECT_DIR}"

if ! command -v xcodegen &>/dev/null; then
    echo "  xcodegen not found, installing via Homebrew…"
    brew install xcodegen
fi

xcodegen generate --quiet 2>/dev/null || xcodegen generate
done_msg "Project generated"

# ── Step 2: Build Release ────────────────────────────────────────

step "Building ${APP_NAME} (Release, arm64)…"
xcodebuild \
    -project "${SCHEME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination 'platform=macOS' \
    ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO \
    build \
    -quiet
done_msg "Build succeeded"

# ── Step 3: Copy app bundle ─────────────────────────────────────

step "Preparing ${APP_NAME}.app…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${DIST_DIR}"
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DIST_DIR}/"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
done_msg "App bundle ready (v${VERSION})"

# ── Step 4: Code sign ───────────────────────────────────────────

step "Code signing…"

ENTITLEMENTS="${PROJECT_DIR}/MindKeeper/Resources/MindKeeper.entitlements"

if [ -z "$SIGN_IDENTITY" ]; then
    for candidate in "Developer ID Application" "Apple Development" "MindKeeper Signing"; do
        if security find-identity -v -p codesigning 2>/dev/null | grep -q "$candidate"; then
            SIGN_IDENTITY="$candidate"
            break
        fi
    done
fi

SIGN_FLAGS=(--force --deep --options runtime --entitlements "$ENTITLEMENTS")

if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    codesign "${SIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" "${APP_BUNDLE}"
    done_msg "Signed with: $SIGN_IDENTITY"
else
    codesign "${SIGN_FLAGS[@]}" --sign - "${APP_BUNDLE}"
    done_msg "Signed (ad-hoc)"
fi

# ── Step 5: Create DMG ──────────────────────────────────────────

if [ "$APP_ONLY" = true ]; then
    echo ""
    echo "═══════════════════════════════════════"
    echo "  Done!  ${APP_BUNDLE}"
    echo "═══════════════════════════════════════"
    exit 0
fi

step "Creating DMG…"
rm -f "${DMG_PATH}"

DMG_TMP="${DIST_DIR}/.dmg-staging"
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"
cp -R "${APP_BUNDLE}" "${DMG_TMP}/"
ln -s /Applications "${DMG_TMP}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TMP}" \
    -ov -format UDZO \
    "${DMG_PATH}" \
    -quiet

rm -rf "${DMG_TMP}"
done_msg "DMG created"

# ── Summary ─────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo "  App:  ${APP_BUNDLE}"
echo "  DMG:  ${DMG_PATH}"
echo ""
echo "  To install: open ${DMG_PATH}"
echo "═══════════════════════════════════════"
