# redo_wallet_core

Dart FFI bindings to [Trust Wallet Core](https://github.com/trustwallet/wallet-core) — the production-grade C++/Rust cryptography library that powers Trust Wallet and supports 130+ blockchains.

Instead of re-implementing crypto in Dart (slow and unsafe), this package loads the audited native library through `dart:ffi` and exposes a small, idiomatic Dart API on top of it: HD wallets, mnemonics, address derivation, transaction signing, hashing, and a few chain-specific helpers (TON, Ethereum messages, keystore v3).

> **Status:** alpha. The pure-Dart API is stable enough for the sibling [redo_wallet_provider](../redo_wallet_provider) and [redo_wallet_flutter](../redo_wallet_flutter) packages, but the public surface may still change.

## Features

- HD wallet creation / restore (BIP39, 12 or 24 words), with **async** variants that run PBKDF2 on a native background thread so the Dart isolate stays responsive.
- Address & private key derivation for any `TWCoinType` (Bitcoin, Ethereum, Solana, TON, Cosmos, Tron, Litecoin, Dogecoin, Polkadot, Cardano, …).
- Transaction signing through `TWAnySigner` (protobuf in / protobuf out).
- Address validation and canonical-format normalization (`TWAnyAddress`).
- Hashing primitives — SHA-256, SHA-512, Keccak-256, RIPEMD-160, double SHA-256, SHA-256+RIPEMD.
- Encrypted keystore (`TWStoredKey`) — import / export Ethereum keystore v3, save / load from disk, decrypt mnemonics.
- Ethereum message signer — `personal_sign` (EIP-191) and typed-data (EIP-712).
- TON helpers — bounceable / non-bounceable / testnet address conversion, and an **async** mnemonic→keypair derivation that is byte-for-byte compatible with the `tonutils` package.
- Coin metadata — symbol, decimals, name, slip44 id, explorer URLs.

## Requirements

- Dart SDK `^3.10.4`.
- macOS host for the bundled `lib/libTrustWalletCore.dylib`. Pre-built binaries for iOS / Android / Linux are not yet shipped — see [Building the native library](#building-the-native-library) below.

## Installation

This package is not (yet) on pub.dev. Add it as a path or git dependency:

```yaml
dependencies:
  redo_wallet_core:
    path: ../redo_wallet_core
```

## Quick start

```dart
import 'package:redo_wallet_core/redo_wallet_core.dart';

void main() async {
  final api = WalletCoreAPI();

  // 1. Create a fresh 24-word HD wallet (off the main isolate).
  final wallet = await api.hdWalletCreateAsync(strength: 256);
  print(wallet.mnemonic);

  // 2. Derive addresses for any supported coin.
  print(wallet.getAddressForCoin(TWCoinType.bitcoin));   // bc1q...
  print(wallet.getAddressForCoin(TWCoinType.ethereum));  // 0x...
  print(wallet.getAddressForCoin(TWCoinType.solana));    // base58...
  print(wallet.getAddressForCoin(TWCoinType.ton));       // raw form

  // 3. Convert a TON address to user-friendly form.
  final ton = wallet.getAddressForCoin(TWCoinType.ton);
  print(api.tonAddressToUserFriendly(ton, bounceable: false));

  // 4. Validate an address.
  print(api.addressIsValid('0x0000000000000000000000000000000000000000',
      TWCoinType.ethereum)); // true

  // 5. Hash some data with Keccak-256.
  final digest = api.hashKeccak256(Uint8List.fromList('hello'.codeUnits));

  // 6. Always release the native handle when you're done with the wallet.
  wallet.delete();
}
```

A more complete tour — coin metadata, keystore v3, address validation, hash demos — lives in [example/full_demo.dart](example/full_demo.dart). Run it with:

```bash
dart run example/full_demo.dart
```

## API tour

### `WalletCoreAPI`

Single entry point. Loads the dylib once and lazily wires up every FFI module.

```dart
final api = WalletCoreAPI();                    // looks up the dylib next to the package
final api = WalletCoreAPI('/path/to/lib.dylib'); // explicit path
final api = WalletCoreAPI.fromLib(myLibrary);    // for Flutter plugins that own the load
```

### HD wallets

```dart
// Sync — fast on desktop, blocks the isolate during PBKDF2 (~2.5s on iPhone).
final w1 = api.hdWalletCreate(strength: 128);
final w2 = api.hdWalletFromMnemonic('abandon abandon ... about');

// Async — runs the heavy work on a native std::thread.
final w3 = await api.hdWalletCreateAsync(strength: 256);
final w4 = await api.hdWalletFromMnemonicAsync('abandon ...');

w1.getAddressForCoin(TWCoinType.ethereum);
w1.getPrivateKeyForCoin(TWCoinType.ethereum); // Uint8List
w1.delete(); // free the native handle
```

### Mnemonics

```dart
api.mnemonicIsValid('abandon abandon ... about'); // bool
api.mnemonicIsValidWord('abandon');               // bool
```

### Addresses

```dart
api.addressIsValid('0x...', TWCoinType.ethereum);
api.addressNormalize('0x...', TWCoinType.ethereum); // canonical form, or null
```

### Signing transactions

`signTransaction` takes a serialized protobuf `SigningInput` and returns a serialized `SigningOutput`. The protobuf schemas live under [lib/src/proto](lib/src/proto). See [example/sign_ethereum.dart](example/sign_ethereum.dart) and [example/sign_ton.dart](example/sign_ton.dart) for end-to-end examples.

```dart
final output = api.signTransaction(serializedInput, TWCoinType.ethereum);
```

### Hashing

```dart
api.hashSHA256(bytes);
api.hashSHA512(bytes);
api.hashKeccak256(bytes);
api.hashRIPEMD(bytes);
api.hashSHA256SHA256(bytes);
api.hashSHA256RIPEMD(bytes);
```

### Encrypted keystore

```dart
final stored = api.storedKeyImportHDWallet(
  wallet.mnemonic, 'My Wallet', 'password', TWCoinType.ethereum,
);

stored.exportJSON();              // Uint8List — Ethereum keystore v3
stored.store('/path/to/key.json');
stored.decryptMnemonic('password');

final loaded = api.storedKeyLoad('/path/to/key.json');
loaded?.delete();
stored.delete();
```

### TON helpers

```dart
api.tonAddressToUserFriendly(addr, bounceable: false);            // UQ...
api.tonAddressToUserFriendly(addr, bounceable: true);             // EQ...
api.tonAddressToUserFriendly(addr, bounceable: false, testnet: true); // 0Q...

// `tonutils`-compatible mnemonic → ed25519 keypair (PBKDF2 100k iters,
// runs on a background thread).
final kp = await api.tonMnemonicToKeyPairAsync('word1 word2 ...');
kp.publicKey;  // 32 bytes
kp.privateKey; // 64 bytes — NaCl secret key (seed || pubkey)
```

### Ethereum message signing

```dart
api.ethSignMessage(privateKeyPtr, 'hello');             // EIP-191
api.ethSignTypedMessage(privateKeyPtr, jsonEip712);     // EIP-712
```

### Coin metadata

```dart
api.coinName(TWCoinType.ethereum);          // "Ethereum"
api.coinSymbol(TWCoinType.ethereum);        // "ETH"
api.coinDecimals(TWCoinType.ethereum);      // 18
api.coinID(TWCoinType.ethereum);            // "ethereum"
api.coinTransactionURL(TWCoinType.ethereum, '0xabc...');
```

## Memory management

Every `TW*` object backing a Dart wrapper is a native handle. The high-level wrappers (`HDWallet`, `StoredKey`, …) expose `.delete()` — call it when you are done. For one-shot string/bytes conversions the package uses scoped helpers (`TWStringWrapper.withString`, `TWDataWrapper.withBytes`) that free the temporary handle automatically.

> Forgetting to call `.delete()` leaks native memory. The Dart GC does not see it.

## Project layout

```
lib/
├── redo_wallet_core.dart           ← package barrel — re-exports the public API
├── libTrustWalletCore.dylib        ← bundled macOS binary
└── src/
    ├── core/                       ← idiomatic Dart wrappers
    │   ├── tw_string.dart          ← String ↔ TWString*
    │   ├── tw_data.dart            ← Uint8List ↔ TWData*
    │   └── wallet_core_api.dart    ← WalletCoreAPI, HDWallet, StoredKey, TWCoinType
    ├── ffi/                        ← raw FFI bindings (one file per TW module)
    │   ├── tw_library.dart         ← DynamicLibrary loader
    │   ├── tw_hash_ffi.dart
    │   ├── tw_hd_wallet_ffi.dart
    │   ├── tw_private_key_ffi.dart
    │   ├── tw_any_address_ffi.dart
    │   ├── tw_any_signer_ffi.dart
    │   ├── tw_stored_key_ffi.dart
    │   ├── tw_coin_config_ffi.dart
    │   ├── tw_ethereum_msg_ffi.dart
    │   ├── tw_ton_address_ffi.dart
    │   ├── tw_ton_mnemonic_ffi.dart
    │   └── ...
    └── proto/                      ← generated protobuf messages for AnySigner
example/
├── full_demo.dart                  ← end-to-end tour
├── sign_ethereum.dart
├── sign_ton.dart
├── show_address.dart
└── wallet_core_example.dart
native/
└── tw_exports.c                    ← visibility wrappers (see below)
scripts/
├── build_dylib.sh                  ← rebuilds libTrustWalletCore.dylib
└── gen_tw_exports.py               ← regenerates native/tw_exports.c
```

## How it works

```
Dart application
       │
       ▼
WalletCoreAPI (lib/src/core/)              ← high-level Dart facade
       │
       ▼
*FFI bindings (lib/src/ffi/)               ← lookupFunction for dartTW* symbols
       │
       ▼
native/tw_exports.c                        ← thin wrappers with default visibility
       │
       ▼
libTrustWalletCore.dylib
       │
       ├── libTrustWalletCore.a            ← C++ core (BIP32, secp256k1, ed25519, …)
       ├── libTrezorCrypto.a               ← Trezor crypto primitives
       ├── libwallet_core_rs.a             ← Rust modules (TON, Polkadot, …)
       └── libprotobuf.a
```

### Why `dartTW*` wrappers?

Trust Wallet Core is compiled with `__attribute__((visibility("hidden")))` on every `TW*` symbol. Even passing `-fvisibility=default` to CMake leaves the static archive's object files marked `.hidden`:

```bash
$ objdump -t build/libTrustWalletCore.a | grep TWHashSHA256
0000001524 g F __TEXT,__text .hidden _TWHashSHA256
```

`dart:ffi` can only call **exported** symbols. The fix is a tiny C file ([native/tw_exports.c](native/tw_exports.c)) that re-exports each used symbol with default visibility under a `dartTW*` prefix:

```c
#define EXPORT __attribute__((visibility("default")))

EXPORT TWData* dartTWHashSHA256(TWData* data) {
    return TWHashSHA256(data);
}
```

Each wrapper compiles to a single tail call — overhead is effectively zero. The `dartTW` prefix avoids clashes with the `tw_*` symbols already exported by the Rust side of wallet-core.

## Building the native library

You only need to do this if you change the upstream wallet-core, add new `TW*` symbols, or want to rebuild for a different host.

### Prerequisites

```bash
brew install boost ninja cmake
cargo install cbindgen
```

### One-time wallet-core setup

```bash
cd /path/to/workspace
git clone --depth 1 git@github.com:nvsces/wallet-core.git wallet-core-native
cd wallet-core-native

export BOOST_ROOT=$(brew --prefix boost)
tools/install-dependencies      # builds protoc, gtest, libcheck into build/local/
tools/generate-files            # protobuf, cbindgen, codegen-v2

cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DTW_UNITY_BUILD=ON
make -Cbuild -j12 TrustWalletCore
```

This produces the four static archives the Dart package links against:

- `build/libTrustWalletCore.a`
- `build/trezor-crypto/libTrezorCrypto.a`
- `build/local/lib/libprotobuf.a`
- `build/local/lib/libwallet_core_rs.a`

### Rebuild the dylib for `redo_wallet_core`

```bash
bash scripts/build_dylib.sh
```

The script:

1. Regenerates `native/tw_exports.c` from the `dartTW*` symbols actually referenced by the Dart bindings (`scripts/gen_tw_exports.py`).
2. Compiles `tw_exports.c` with `-fvisibility=default`.
3. Links it against the four static archives via `-Wl,-force_load` to produce `build/libTrustWalletCore.dylib`.
4. Copies the dylib into every consumer (`redo_wallet_core/lib/`, `redo_wallet_provider/lib/`, `redo_wallet_flutter/macos/Libs/`, …).
5. Verifies that the async wrappers (`dartTWHDWalletCreateAsync`, `dartTWTONMnemonicToKeyPairAsync`, …) are exported.

The iOS `.xcframework` is built separately — see `wallet-core-native/build-ios.sh`.

## Roadmap

- [ ] Pre-built `.a`/`.so`/`.xcframework` shipped via the Flutter plugin.
- [ ] Linux / Windows host binaries.
- [ ] More chain-specific helpers (Solana message signing, Bitcoin PSBT, …).
- [ ] Wider test coverage of the high-level Dart API.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).

This package contains Dart bindings to **Trust Wallet Core**, which is also Apache 2.0 licensed. Copyright 2017 Trust Wallet. See the upstream [LICENSE](https://github.com/trustwallet/wallet-core/blob/master/LICENSE) and [LICENSE-3RD-PARTY.txt](https://github.com/trustwallet/wallet-core/blob/master/LICENSE-3RD-PARTY.txt) for details on bundled third-party code (trezor-crypto, libsecp256k1, protobuf, …).
