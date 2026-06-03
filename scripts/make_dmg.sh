#!/usr/bin/env bash
# Release derler ve teslim için DMG üretir.
# Çıktı: dist/MentalDonusum-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="MentalDonusum.xcodeproj"
SCHEME="MentalDonusum"
CONFIGURATION="Release"
APP_NAME="MentalDonusum"
DISPLAY_NAME="Mental Dönüşüm"
VERSION="$(grep -E 'MARKETING_VERSION' "$PROJECT/project.pbxproj" | head -1 | sed -E 's/.*MARKETING_VERSION = ([0-9.]+).*/\1/')"
[ -z "$VERSION" ] && VERSION="1.0"

BUILD_DIR="build"
DERIVED="$BUILD_DIR/Derived"
PRODUCTS="$DERIVED/Build/Products/$CONFIGURATION"
DMG_STAGING="$BUILD_DIR/dmg-staging"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

echo "==> Eski artefaktları temizliyorum"
rm -rf "$BUILD_DIR" "$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
mkdir -p "$DIST_DIR" "$DMG_STAGING"

echo "==> Release derleme ($CONFIGURATION)"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED" \
    -destination "platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM="" \
    build 2>&1 | grep -E "(error:|warning:|BUILD)" | tail -10

APP_PATH="$PRODUCTS/${APP_NAME}.app"
[ ! -d "$APP_PATH" ] && { echo "Hata: $APP_PATH bulunamadı"; exit 1; }

echo "==> .app kopyalanıyor ve /Applications sembolik linki ekleniyor"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> DMG üretiliyor: $DMG_PATH"
hdiutil create \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    -imagekey zlib-level=9 \
    "$DMG_PATH" >/dev/null

echo
echo "==> Hazır:"
ls -lh "$DMG_PATH"
echo
echo "Kurulum: DMG'yi aç → MentalDonusum.app'i Applications'a sürükle"
echo "İlk açılışta macOS \"tanınmayan geliştirici\" uyarısı verirse:"
echo "  Finder → Applications → MentalDonusum.app'a sağ tık → Aç"
