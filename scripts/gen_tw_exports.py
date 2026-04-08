#!/usr/bin/env python3
"""Generate native/tw_exports.c from used dartTW* symbols + TWC headers.

Why this exists
---------------
TrustWalletCore's C ABI symbols (`TWHashSHA256`, `TWHDWalletCreate`, ...) are
compiled with hidden visibility, which means `dart:ffi`'s `dlopen` cannot find
them in the resulting .dylib. The standard fix is a thin layer of
`__attribute__((visibility("default")))` C wrappers prefixed with `dart` to
avoid colliding with TWC's `tw_*` Rust symbols.

This script:
  1. Walks `lib/src/ffi/*.dart` to discover which `dartTW*` symbols are
     actually referenced from Dart.
  2. Parses the corresponding `TW*` declarations from
     `wallet-core-native/include/TrustWalletCore/*.h`.
  3. Emits `native/tw_exports.c` containing one wrapper per used symbol,
     followed by a hand-written block for the async wrappers (which need
     `int64_t port` parameters that don't appear in the regular TWC headers
     in a uniform shape).

Run from anywhere:

    python3 redo_wallet_core/scripts/gen_tw_exports.py

Re-run after adding a new `lib.lookupFunction(... 'dartTWFooBar')` to any
`lib/src/ffi/*.dart` file.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# ── paths ──────────────────────────────────────────────────────────────────

SCRIPT_DIR = Path(__file__).resolve().parent
PKG_ROOT = SCRIPT_DIR.parent  # redo_wallet_core/
FFI_DIR = PKG_ROOT / "lib" / "src" / "ffi"
OUTPUT_FILE = PKG_ROOT / "native" / "tw_exports.c"

# wallet-core-native is a sibling of redo_wallet_core in the workspace.
WORKSPACE_ROOT = PKG_ROOT.parent
HEADERS_DIR = WORKSPACE_ROOT / "wallet-core-native" / "include" / "TrustWalletCore"

# ── header parsing ─────────────────────────────────────────────────────────

TWC_ATTR_TOKENS = {
    "TW_EXPORT_STATIC_METHOD",
    "TW_EXPORT_METHOD",
    "TW_EXPORT_PROPERTY",
    "TW_EXPORT_CLASS",
    "TW_EXPORT_STRUCT",
    "TW_EXPORT_ENUM",
    "TW_EXPORT_FUNC",
    "TW_VISIBILITY_DEFAULT",
    "TW_EXTERN_C_BEGIN",
    "TW_EXTERN_C_END",
    "extern",
}

# dartTW* symbols that must NOT be emitted by the generator because they are
# provided manually in the ASYNC_WRAPPERS block at the bottom of the file.
MANUAL_ASYNC_SYMBOLS = {
    "dartTWHDWalletInitDartApiDL",
    "dartTWHDWalletCreateAsync",
    "dartTWHDWalletCreateWithMnemonicAsync",
    "dartTWTONMnemonicToKeyPair",
    "dartTWTONMnemonicToKeyPairAsync",
}

NULLABILITY_RE = re.compile(r"\s*\b_Nonnull\b|\s*\b_Nullable\b|\s*\b_Null_unspecified\b")


def strip_nullability(s: str) -> str:
    """Drop _Nonnull / _Nullable annotations — not portable in plain C wrappers."""
    return NULLABILITY_RE.sub("", s)


def clean_return_type(rt: str) -> str:
    """Strip TWC visibility/export macros and nullability from a return type."""
    tokens = rt.split()
    cleaned = [t for t in tokens if t not in TWC_ATTR_TOKENS]
    return strip_nullability(" ".join(cleaned)).strip()


def parse_headers() -> dict[str, tuple[str, str, str]]:
    """Return {func_name: (return_type, params, header_basename)}."""
    sigs: dict[str, tuple[str, str, str]] = {}
    for header in sorted(HEADERS_DIR.glob("*.h")):
        text = header.read_text()
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)  # block comments
        text = re.sub(r"//[^\n]*", "", text)                     # line comments
        text = re.sub(r"^\s*#.*$", "", text, flags=re.MULTILINE) # preprocessor
        flat = re.sub(r"\s+", " ", text)
        for stmt in flat.split(";"):
            stmt = stmt.strip()
            if "(" not in stmt or not stmt:
                continue
            m = re.match(r"^(.+?)\s+(\w+)\s*\((.*)\)\s*$", stmt)
            if not m:
                continue
            return_type = clean_return_type(m.group(1))
            name = m.group(2)
            params = m.group(3).strip()
            if not name.startswith("TW"):
                continue
            if "typedef" in return_type:
                continue
            sigs[name] = (return_type, params, header.name)
    return sigs


# ── parameter splitting ────────────────────────────────────────────────────


def split_params(params: str) -> list[tuple[str, str]]:
    """Return list of (type, name) pairs. For 'void' returns []."""
    params = strip_nullability(params)
    if not params or params.strip() == "void":
        return []
    result: list[tuple[str, str]] = []
    for raw in params.split(","):
        raw = raw.strip()
        if not raw:
            continue
        m = re.match(r"^(.+?)(\b\w+)\s*$", raw)
        if not m:
            result.append((raw, f"_arg{len(result)}"))
            continue
        ptype = m.group(1).strip()
        pname = m.group(2)
        result.append((ptype, pname))
    return result


# ── used symbol discovery ──────────────────────────────────────────────────


SYMBOL_RE = re.compile(r"'(dartTW[A-Za-z0-9_]+)'")


def collect_used_symbols() -> list[str]:
    used: set[str] = set()
    for dart_file in sorted(FFI_DIR.rglob("*.dart")):
        for m in SYMBOL_RE.finditer(dart_file.read_text()):
            used.add(m.group(1))
    return sorted(used)


# ── code generation ────────────────────────────────────────────────────────


def gen_wrapper(name: str, return_type: str, params: str) -> str:
    pairs = split_params(params)
    param_decl = ", ".join(f"{t} {n}" for t, n in pairs) if pairs else "void"
    arg_list = ", ".join(n for _, n in pairs)
    is_void = return_type.strip() == "void"
    return_kw = "" if is_void else "return "
    return (
        f"EXPORT {return_type} dart{name}({param_decl}) {{\n"
        f"    {return_kw}{name}({arg_list});\n"
        f"}}\n"
    )


ASYNC_WRAPPERS = """\
// ─── New async wrappers (Dart Native API DL) ──────────────────────

EXPORT bool dartTWHDWalletInitDartApiDL(void* data) {
    return TWHDWalletInitDartApiDL(data);
}

EXPORT void dartTWHDWalletCreateAsync(int strength, TWString* passphrase, int64_t port) {
    TWHDWalletCreateAsync(strength, passphrase, port);
}

EXPORT void dartTWHDWalletCreateWithMnemonicAsync(TWString* mnemonic, TWString* passphrase, int64_t port) {
    TWHDWalletCreateWithMnemonicAsync(mnemonic, passphrase, port);
}

EXPORT TWData* dartTWTONMnemonicToKeyPair(TWString* mnemonic, TWString* password) {
    return TWTONMnemonicToKeyPair(mnemonic, password);
}

EXPORT void dartTWTONMnemonicToKeyPairAsync(TWString* mnemonic, TWString* password, int64_t port) {
    TWTONMnemonicToKeyPairAsync(mnemonic, password, port);
}
"""


def main() -> int:
    if not HEADERS_DIR.is_dir():
        print(f"ERROR: TWC headers not found at {HEADERS_DIR}", file=sys.stderr)
        return 2
    if not FFI_DIR.is_dir():
        print(f"ERROR: FFI dir not found at {FFI_DIR}", file=sys.stderr)
        return 2

    used = collect_used_symbols()
    sigs = parse_headers()
    print(f"Discovered {len(used)} used dartTW* symbols", file=sys.stderr)
    print(f"Parsed {len(sigs)} TW* declarations from headers", file=sys.stderr)

    missing: list[str] = []
    wrappers: list[str] = []
    headers_needed: set[str] = set()

    for dart_name in used:
        # Skip symbols that have hand-written wrappers in ASYNC_WRAPPERS,
        # otherwise we'd emit two definitions of the same function.
        if dart_name in MANUAL_ASYNC_SYMBOLS:
            continue
        tw_name = dart_name[len("dart"):]
        if tw_name not in sigs:
            missing.append(tw_name)
            continue
        return_type, params, header = sigs[tw_name]
        headers_needed.add(header)
        wrappers.append(gen_wrapper(tw_name, return_type, params))

    if missing:
        print(
            f"WARNING: {len(missing)} symbols not found in headers:",
            file=sys.stderr,
        )
        for m in missing:
            print(f"  - {m}", file=sys.stderr)

    out: list[str] = []
    out.append("// SPDX-License-Identifier: Apache-2.0\n")
    out.append("//\n")
    out.append("// Auto-generated by scripts/gen_tw_exports.py — DO NOT EDIT BY HAND.\n")
    out.append("//\n")
    out.append("// Provides default-visibility `dartTW*` thin wrappers around the\n")
    out.append("// hidden-visibility TWC C ABI so dart:ffi can find them via dlopen.\n")
    out.append("\n")
    out.append("#define EXPORT __attribute__((visibility(\"default\")))\n")
    out.append("\n")
    out.append("#include <stdbool.h>\n")
    out.append("#include <stdint.h>\n")
    out.append("\n")
    for h in sorted(headers_needed):
        out.append(f"#include <TrustWalletCore/{h}>\n")
    # Headers required by ASYNC_WRAPPERS — these are not auto-discovered
    # because their symbols live in MANUAL_ASYNC_SYMBOLS and are excluded
    # from the parser-driven path.
    out.append("#include <TrustWalletCore/TWHDWalletAsync.h>\n")
    out.append("#include <TrustWalletCore/TWTONMnemonic.h>\n")
    out.append("\n")
    out.extend(w + "\n" for w in wrappers)
    out.append(ASYNC_WRAPPERS)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text("".join(out))
    manual_count = len(MANUAL_ASYNC_SYMBOLS)
    print(
        f"Wrote {OUTPUT_FILE.relative_to(PKG_ROOT)}: "
        f"{len(wrappers)} generated + {manual_count} manual async",
        file=sys.stderr,
    )
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
