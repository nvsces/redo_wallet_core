#!/usr/bin/env bash
#
# Build libTrustWalletCore.dylib for redo_wallet_core (macOS host).
#
# Pipeline:
#   1. (Re)generate native/tw_exports.c from used dartTW* symbols + headers.
#   2. Make sure wallet-core-native/build/libTrustWalletCore.a exists
#      (this is the standalone TWC build produced by tools/build-and-test).
#   3. Compile native/tw_exports.c → build/tw_exports.o
#   4. Link tw_exports.o + 4 static archives into a shared .dylib with
#      default visibility on the dartTW* wrapper symbols.
#   5. Copy build/libTrustWalletCore.dylib → lib/libTrustWalletCore.dylib
#
# Run from anywhere:
#
#     bash redo_wallet_core/scripts/build_dylib.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$PKG_ROOT/.." && pwd)"
TWC_DIR="$WORKSPACE_ROOT/wallet-core-native"
TWC_BUILD="$TWC_DIR/build"
PKG_BUILD="$PKG_ROOT/build"

echo "==> Workspace: $WORKSPACE_ROOT"
echo "==> Package:   $PKG_ROOT"
echo "==> TWC:       $TWC_DIR"

# 1. Regenerate tw_exports.c
echo
echo "==> Regenerating native/tw_exports.c"
python3 "$SCRIPT_DIR/gen_tw_exports.py"

# 2. Sanity-check the static lib (built by tools/build-and-test)
TWC_STATIC="$TWC_BUILD/libTrustWalletCore.a"
TREZOR_STATIC="$TWC_BUILD/trezor-crypto/libTrezorCrypto.a"
PROTOBUF_STATIC="$TWC_BUILD/local/lib/libprotobuf.a"
RUST_STATIC="$TWC_BUILD/local/lib/libwallet_core_rs.a"

for archive in "$TWC_STATIC" "$TREZOR_STATIC" "$PROTOBUF_STATIC" "$RUST_STATIC"; do
    if [[ ! -f "$archive" ]]; then
        echo "ERROR: missing $archive" >&2
        echo "       Run \`cd $TWC_DIR && tools/build-and-test\` first." >&2
        exit 1
    fi
done

# 3. Compile tw_exports.c → tw_exports.o
mkdir -p "$PKG_BUILD"
echo
echo "==> Compiling tw_exports.c"
clang -c -fvisibility=default -O2 \
    -I "$TWC_DIR/include" \
    -I "$TWC_DIR/src" \
    -I "$TWC_BUILD/local/include" \
    "$PKG_ROOT/native/tw_exports.c" \
    -o "$PKG_BUILD/tw_exports.o"

# 4. Link everything into one dylib
echo
echo "==> Linking libTrustWalletCore.dylib"
clang++ -shared -o "$PKG_BUILD/libTrustWalletCore.dylib" \
    "$PKG_BUILD/tw_exports.o" \
    -Wl,-force_load,"$TWC_STATIC" \
    -Wl,-force_load,"$TREZOR_STATIC" \
    -Wl,-force_load,"$PROTOBUF_STATIC" \
    -Wl,-force_load,"$RUST_STATIC" \
    -lz \
    -framework Security -framework CoreFoundation \
    -Wl,-undefined,dynamic_lookup

# 5. Copy into every consumer that ships its own dylib copy.
#
#    - redo_wallet_core/lib/            → used by pure-Dart code via DynamicLibrary.open
#    - redo_wallet_provider/lib/        → sibling package with its own copy
#    - redo_wallet_flutter/macos/Libs/  → vendored by the Flutter macOS plugin podspec
#    - redo_wallet_flutter/native/macos/→ legacy copy, kept in sync for safety
#
#    iOS uses a separate .xcframework built from static archives — that path
#    is not updated here. See redo_wallet_flutter/ios/Frameworks/ and the
#    wallet-core-native/build-ios.sh script when iOS changes are needed.
echo
echo "==> Distributing libTrustWalletCore.dylib to consumers"
DYLIB="$PKG_BUILD/libTrustWalletCore.dylib"

destinations=(
    "$PKG_ROOT/lib/libTrustWalletCore.dylib"
    "$WORKSPACE_ROOT/redo_wallet_provider/lib/libTrustWalletCore.dylib"
    "$WORKSPACE_ROOT/redo_wallet_flutter/macos/Libs/libTrustWalletCore.dylib"
    "$WORKSPACE_ROOT/redo_wallet_flutter/native/macos/libTrustWalletCore.dylib"
)

for dest in "${destinations[@]}"; do
    if [[ -e "$dest" || -d "$(dirname "$dest")" ]]; then
        cp -f "$DYLIB" "$dest"
        echo "    wrote $dest"
    else
        echo "    skipped $dest (parent dir missing)"
    fi
done

# 6. Quick verification — async symbols must be visible
echo
echo "==> Verifying async symbols are exported"
exported_count=$(nm -gU "$PKG_ROOT/lib/libTrustWalletCore.dylib" | grep -c '_dartTW' || true)
echo "    Total dartTW* symbols:    $exported_count"
async_symbols=$(nm -gU "$PKG_ROOT/lib/libTrustWalletCore.dylib" \
    | grep -E '_dartTWHDWalletCreateAsync|_dartTWHDWalletCreateWithMnemonicAsync|_dartTWHDWalletInitDartApiDL|_dartTWTONMnemonicToKeyPair|_dartTWTONMnemonicToKeyPairAsync' \
    || true)
if [[ -z "$async_symbols" ]]; then
    echo "ERROR: async wrappers not found in dylib" >&2
    exit 1
fi
echo "$async_symbols" | sed 's/^/    /'

echo
echo "==> Done. lib/libTrustWalletCore.dylib is ready."
