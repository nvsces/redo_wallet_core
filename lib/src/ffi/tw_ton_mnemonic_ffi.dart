import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

// ── sync entry point ─────────────────────────────────────────────
typedef _ToKeyPairNative = Pointer<TWData> Function(Pointer<TWString>, Pointer<TWString>);
typedef _ToKeyPairDart = Pointer<TWData> Function(Pointer<TWString>, Pointer<TWString>);

// ── async entry point (Dart Native API DL via std::thread) ──────
typedef _ToKeyPairAsyncNative = Void Function(Pointer<TWString>, Pointer<TWString>, Int64);
typedef _ToKeyPairAsyncDart = void Function(Pointer<TWString>, Pointer<TWString>, int);

/// Low-level FFI bindings for TON-specific entry points exported by the
/// dylib via `dartTWTONMnemonic*` wrappers.
///
/// Caller is responsible for:
///   - Allocating / freeing the [TWString] arguments via `TWStringWrapper`
///   - Calling `dartTWHDWalletInitDartApiDL` (through [TWHDWalletFFI])
///     once at startup before invoking [toKeyPairAsync]. The native side
///     uses one global Dart_PostCObject_DL initialization for both the
///     HDWallet and TON async paths.
class TWTONMnemonicFFI {
  final _ToKeyPairDart toKeyPair;
  final _ToKeyPairAsyncDart _toKeyPairAsync;

  TWTONMnemonicFFI(DynamicLibrary lib)
      : toKeyPair = lib.lookupFunction<_ToKeyPairNative, _ToKeyPairDart>(
            'dartTWTONMnemonicToKeyPair'),
        _toKeyPairAsync = lib.lookupFunction<_ToKeyPairAsyncNative, _ToKeyPairAsyncDart>(
            'dartTWTONMnemonicToKeyPairAsync');

  /// Async TON keypair derivation. Heavy PBKDF2 (~2.5s on iPhone) runs
  /// on a native std::thread inside the dylib; the result (a 64-byte
  /// NaCl secret key) is delivered back via [Dart_PostCObject_DL] as
  /// a [Uint8List] payload.
  ///
  /// Layout of the returned 64 bytes:
  ///   - bytes[0..32]  → seed (== first half of NaCl secret key)
  ///   - bytes[32..64] → ed25519 public key
  Future<Uint8List> toKeyPairAsync(
    Pointer<TWString> mnemonic,
    Pointer<TWString> password,
  ) async {
    final port = ReceivePort();
    try {
      _toKeyPairAsync(mnemonic, password, port.sendPort.nativePort);
      final result = await port.first;
      if (result is! Uint8List || result.length != 64) {
        throw StateError(
          'TON async derivation returned unexpected payload: '
          '${result.runtimeType}'
          '${result is Uint8List ? " len=${result.length}" : ""}',
        );
      }
      // Defensive copy: the buffer comes from the VM message queue and is
      // safe to keep, but we own it now and want a stable Uint8List.
      return Uint8List.fromList(result);
    } finally {
      port.close();
    }
  }
}
