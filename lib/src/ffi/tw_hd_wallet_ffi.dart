import 'dart:ffi';
import 'dart:isolate';

import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

typedef _CreateNative = Pointer<Void> Function(Int32, Pointer<TWString>);
typedef _CreateDart = Pointer<Void> Function(int, Pointer<TWString>);
typedef _CreateMnemonicNative = Pointer<Void> Function(Pointer<TWString>, Pointer<TWString>);
typedef _CreateMnemonicDart = Pointer<Void> Function(Pointer<TWString>, Pointer<TWString>);
typedef _DeleteNative = Void Function(Pointer<Void>);
typedef _DeleteDart = void Function(Pointer<Void>);
typedef _MnemonicNative = Pointer<TWString> Function(Pointer<Void>);
typedef _MnemonicDart = Pointer<TWString> Function(Pointer<Void>);
typedef _SeedNative = Pointer<TWData> Function(Pointer<Void>);
typedef _SeedDart = Pointer<TWData> Function(Pointer<Void>);
typedef _GetKeyForCoinNative = Pointer<Void> Function(Pointer<Void>, Int32);
typedef _GetKeyForCoinDart = Pointer<Void> Function(Pointer<Void>, int);
typedef _GetAddressForCoinNative = Pointer<TWString> Function(Pointer<Void>, Int32);
typedef _GetAddressForCoinDart = Pointer<TWString> Function(Pointer<Void>, int);

// Async variants — heavy work runs on a native std::thread inside the
// dylib and posts the resulting TWHDWallet handle back via Dart_PostCObject_DL.
typedef _InitDartApiDLNative = Bool Function(Pointer<Void>);
typedef _InitDartApiDLDart = bool Function(Pointer<Void>);
typedef _CreateAsyncNative = Void Function(Int32, Pointer<TWString>, Int64);
typedef _CreateAsyncDart = void Function(int, Pointer<TWString>, int);
typedef _CreateMnemonicAsyncNative = Void Function(Pointer<TWString>, Pointer<TWString>, Int64);
typedef _CreateMnemonicAsyncDart = void Function(Pointer<TWString>, Pointer<TWString>, int);

class TWHDWalletFFI {
  final _CreateDart create;
  final _CreateMnemonicDart createWithMnemonic;
  final _DeleteDart delete;
  final _MnemonicDart mnemonic;
  final _SeedDart seed;
  final _GetKeyForCoinDart getKeyForCoin;
  final _GetAddressForCoinDart getAddressForCoin;

  // Async entry points and one-time DL initializer.
  final _InitDartApiDLDart _initDartApiDL;
  final _CreateAsyncDart _createAsync;
  final _CreateMnemonicAsyncDart _createWithMnemonicAsync;
  bool _dlInitialized = false;

  TWHDWalletFFI(DynamicLibrary lib)
      : create = lib.lookupFunction<_CreateNative, _CreateDart>('dartTWHDWalletCreate'),
        createWithMnemonic = lib.lookupFunction<_CreateMnemonicNative, _CreateMnemonicDart>('dartTWHDWalletCreateWithMnemonic'),
        delete = lib.lookupFunction<_DeleteNative, _DeleteDart>('dartTWHDWalletDelete'),
        mnemonic = lib.lookupFunction<_MnemonicNative, _MnemonicDart>('dartTWHDWalletMnemonic'),
        seed = lib.lookupFunction<_SeedNative, _SeedDart>('dartTWHDWalletSeed'),
        getKeyForCoin = lib.lookupFunction<_GetKeyForCoinNative, _GetKeyForCoinDart>('dartTWHDWalletGetKeyForCoin'),
        getAddressForCoin = lib.lookupFunction<_GetAddressForCoinNative, _GetAddressForCoinDart>('dartTWHDWalletGetAddressForCoin'),
        _initDartApiDL = lib.lookupFunction<_InitDartApiDLNative, _InitDartApiDLDart>('dartTWHDWalletInitDartApiDL'),
        _createAsync = lib.lookupFunction<_CreateAsyncNative, _CreateAsyncDart>('dartTWHDWalletCreateAsync'),
        _createWithMnemonicAsync = lib.lookupFunction<_CreateMnemonicAsyncNative, _CreateMnemonicAsyncDart>('dartTWHDWalletCreateWithMnemonicAsync');

  /// Bootstraps the dylib's `Dart_PostCObject_DL` function pointer once
  /// per process. Idempotent — safe to call from any async entry point
  /// (HDWallet, TON, future ones) before the first cross-thread post.
  void ensureDartApiDLInitialized() {
    if (_dlInitialized) return;
    final ok = _initDartApiDL(NativeApi.initializeApiDLData);
    if (!ok) {
      throw StateError('Failed to initialize Dart Native API DL in TrustWalletCore');
    }
    _dlInitialized = true;
  }

  /// Generates a new HDWallet on a background native thread. Returns the
  /// raw TWHDWallet handle as a `Pointer<Void>` (null on failure), so the
  /// caller can drive it through the existing sync getters and ultimately
  /// [delete] it.
  Future<Pointer<Void>> createAsync(int strength, Pointer<TWString> passphrase) async {
    ensureDartApiDLInitialized();
    final port = ReceivePort();
    try {
      _createAsync(strength, passphrase, port.sendPort.nativePort);
      final handleAddr = await port.first as int;
      return Pointer<Void>.fromAddress(handleAddr);
    } finally {
      port.close();
    }
  }

  /// Imports an HDWallet from a BIP39 mnemonic on a background native
  /// thread (PBKDF2 seed derivation runs off the calling isolate).
  Future<Pointer<Void>> createWithMnemonicAsync(
    Pointer<TWString> mnemonic,
    Pointer<TWString> passphrase,
  ) async {
    ensureDartApiDLInitialized();
    final port = ReceivePort();
    try {
      _createWithMnemonicAsync(mnemonic, passphrase, port.sendPort.nativePort);
      final handleAddr = await port.first as int;
      return Pointer<Void>.fromAddress(handleAddr);
    } finally {
      port.close();
    }
  }
}
