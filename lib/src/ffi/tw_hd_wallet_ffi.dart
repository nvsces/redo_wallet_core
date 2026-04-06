import 'dart:ffi';

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

class TWHDWalletFFI {
  final _CreateDart create;
  final _CreateMnemonicDart createWithMnemonic;
  final _DeleteDart delete;
  final _MnemonicDart mnemonic;
  final _SeedDart seed;
  final _GetKeyForCoinDart getKeyForCoin;
  final _GetAddressForCoinDart getAddressForCoin;

  TWHDWalletFFI(DynamicLibrary lib)
      : create = lib.lookupFunction<_CreateNative, _CreateDart>('dartTWHDWalletCreate'),
        createWithMnemonic = lib.lookupFunction<_CreateMnemonicNative, _CreateMnemonicDart>('dartTWHDWalletCreateWithMnemonic'),
        delete = lib.lookupFunction<_DeleteNative, _DeleteDart>('dartTWHDWalletDelete'),
        mnemonic = lib.lookupFunction<_MnemonicNative, _MnemonicDart>('dartTWHDWalletMnemonic'),
        seed = lib.lookupFunction<_SeedNative, _SeedDart>('dartTWHDWalletSeed'),
        getKeyForCoin = lib.lookupFunction<_GetKeyForCoinNative, _GetKeyForCoinDart>('dartTWHDWalletGetKeyForCoin'),
        getAddressForCoin = lib.lookupFunction<_GetAddressForCoinNative, _GetAddressForCoinDart>('dartTWHDWalletGetAddressForCoin');
}
