#!/usr/bin/env bash
# ==============================================================================
# GearLease Production Release Build Script (Bash)
# Builds obfuscated artifacts with split debug symbol tables
# ==============================================================================

set -euo pipefail

TARGET="${1:-appbundle}"
FLAVOR="${2:-prod}"

echo "=========================================================="
echo "  GEARLEASE PRODUCTION RELEASE BUILD PIPELINE"
echo "  Target: ${TARGET} | Flavor: ${FLAVOR}"
echo "=========================================================="

echo "[1/4] Ensuring clean dependencies..."
flutter pub get

echo "[2/4] Running Quality Gates (Analyzer & Tests)..."
flutter analyze --fatal-infos
flutter test --coverage

SYMBOLS_DIR="./build/symbols/${TARGET}/${FLAVOR}"
mkdir -p "${SYMBOLS_DIR}"
echo "[3/4] Symbols will be preserved in: ${SYMBOLS_DIR}"

ENTRY_POINT="lib/main_${FLAVOR}.dart"
if [ ! -f "${ENTRY_POINT}" ]; then
  ENTRY_POINT="lib/main.dart"
fi

echo "[4/4] Building release binary with code obfuscation and symbol splitting..."
case "${TARGET}" in
  appbundle)
    flutter build appbundle \
      --release \
      -t "${ENTRY_POINT}" \
      --obfuscate \
      --split-debug-info="${SYMBOLS_DIR}"
    ;;
  apk)
    flutter build apk \
      --release \
      -t "${ENTRY_POINT}" \
      --obfuscate \
      --split-debug-info="${SYMBOLS_DIR}"
    ;;
  ipa)
    flutter build ipa \
      --release \
      -t "${ENTRY_POINT}" \
      --obfuscate \
      --split-debug-info="${SYMBOLS_DIR}"
    ;;
  *)
    echo "Unknown target: ${TARGET}. Valid options: appbundle, apk, ipa"
    exit 1
    ;;
esac

echo "=========================================================="
echo "  BUILD SUCCESSFUL!"
echo "  Debug symbols archived in: ${SYMBOLS_DIR}"
echo "=========================================================="
