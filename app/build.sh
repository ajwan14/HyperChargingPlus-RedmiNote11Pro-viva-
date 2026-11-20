#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$APP_DIR/.." && pwd)"

# Detect Android SDK
if [ -z "$ANDROID_HOME" ] && [ -n "$ANDROID_SDK_ROOT" ]; then
  ANDROID_HOME="$ANDROID_SDK_ROOT"
fi

if [ -z "$ANDROID_HOME" ]; then
  echo "Error: ANDROID_HOME or ANDROID_SDK_ROOT not set" >&2
  exit 1
fi

# Locate android.jar (platform 34 or 35)
ANDROID_JAR=$(find "$ANDROID_HOME/platforms" -name "android.jar" 2>/dev/null | sort -V | tail -n 1)
if [ ! -f "$ANDROID_JAR" ]; then
  echo "Error: android.jar not found in $ANDROID_HOME/platforms" >&2
  exit 1
fi

# Locate build-tools
BUILD_TOOLS_DIR=$(find "$ANDROID_HOME/build-tools" -maxdepth 1 -mindepth 1 2>/dev/null | sort -V | tail -n 1)
if [ -z "$BUILD_TOOLS_DIR" ]; then
  echo "Error: build-tools not found in $ANDROID_HOME/build-tools" >&2
  exit 1
fi

AAPT2="$BUILD_TOOLS_DIR/aapt2"
D8="$BUILD_TOOLS_DIR/d8"
ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"

echo "Using Android SDK: $ANDROID_JAR"
echo "Using Build-Tools: $BUILD_TOOLS_DIR"

BUILD_DIR="$APP_DIR/build"
GEN_DIR="$BUILD_DIR/gen"
BIN_DIR="$BUILD_DIR/bin"
DEX_DIR="$BUILD_DIR/dex"

rm -rf "$BUILD_DIR"
mkdir -p "$GEN_DIR" "$BIN_DIR" "$DEX_DIR"

echo "1. Compiling resources..."
"$AAPT2" compile --dir "$APP_DIR/res" -o "$BUILD_DIR/compiled_res.zip"

echo "2. Linking resources..."
"$AAPT2" link -I "$ANDROID_JAR" "$BUILD_DIR/compiled_res.zip" \
  --manifest "$APP_DIR/AndroidManifest.xml" \
  --java "$GEN_DIR" \
  -o "$BUILD_DIR/base.apk"

echo "3. Compiling Java sources..."
SRC_FILES=$(find "$APP_DIR/src" "$GEN_DIR" -name "*.java")
javac --release 17 -cp "$ANDROID_JAR:$GEN_DIR" -d "$BIN_DIR" $SRC_FILES

echo "4. Converting classes to DEX..."
CLASS_FILES=$(find "$BIN_DIR" -name "*.class")
"$D8" --min-api 29 --output "$DEX_DIR" $CLASS_FILES

echo "5. Packaging DEX into base APK..."
(cd "$DEX_DIR" && zip -u -j "$BUILD_DIR/base.apk" classes.dex)

echo "6. Aligning APK..."
"$ZIPALIGN" -p -f 4 "$BUILD_DIR/base.apk" "$BUILD_DIR/aligned.apk"

echo "7. Signing APK..."
KEYSTORE="$APP_DIR/release.keystore"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -v -keystore "$KEYSTORE" -alias hypercharge -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass hypercharge -keypass hypercharge -dname "CN=HyperCharge, OU=Dev, O=Razal, L=Jakarta, ST=ID, C=ID"
fi

FINAL_APK="$APP_DIR/HyperChargeService.apk"
"$APKSIGNER" sign --min-sdk-version 24 --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
  --ks "$KEYSTORE" --ks-pass pass:hypercharge --out "$FINAL_APK" "$BUILD_DIR/aligned.apk"

DEST="$ROOT_DIR/system/app/HyperChargingService/HyperChargeService.apk"
mkdir -p "$(dirname "$DEST")"
cp -f "$FINAL_APK" "$DEST"

echo "Build successful: $DEST"
