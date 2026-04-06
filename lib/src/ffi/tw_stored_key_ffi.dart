import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

class TWStoredKeyFFI {
  final Pointer<Void> Function(Pointer<TWString>, Pointer<TWData>) create;
  final Pointer<Void> Function(Pointer<TWString>, Pointer<TWString>, Pointer<TWData>, int) importHDWallet;
  final Pointer<Void> Function(Pointer<TWData>, Pointer<TWString>, Pointer<TWData>, int) importPrivateKey;
  final Pointer<Void> Function(Pointer<TWData>) importJSON;
  final Pointer<Void> Function(Pointer<TWString>) load;
  final void Function(Pointer<Void>) delete;
  final Pointer<TWString> Function(Pointer<Void>) name;
  final Pointer<TWString> Function(Pointer<Void>) identifier;
  final bool Function(Pointer<Void>) isMnemonic;
  final int Function(Pointer<Void>) accountCount;
  final bool Function(Pointer<Void>, Pointer<TWString>) store;
  final Pointer<TWData> Function(Pointer<Void>, Pointer<TWData>) decryptPrivateKey;
  final Pointer<TWString> Function(Pointer<Void>, Pointer<TWData>) decryptMnemonic;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<TWData>) privateKey;
  final Pointer<Void> Function(Pointer<Void>, Pointer<TWData>) wallet;
  final Pointer<TWData> Function(Pointer<Void>) exportJSON;
  final bool Function(Pointer<Void>, Pointer<TWData>) fixAddresses;

  TWStoredKeyFFI(DynamicLibrary lib)
      : create = lib.lookupFunction<Pointer<Void> Function(Pointer<TWString>, Pointer<TWData>), Pointer<Void> Function(Pointer<TWString>, Pointer<TWData>)>('dartTWStoredKeyCreate'),
        importHDWallet = lib.lookupFunction<Pointer<Void> Function(Pointer<TWString>, Pointer<TWString>, Pointer<TWData>, Int32), Pointer<Void> Function(Pointer<TWString>, Pointer<TWString>, Pointer<TWData>, int)>('dartTWStoredKeyImportHDWallet'),
        importPrivateKey = lib.lookupFunction<Pointer<Void> Function(Pointer<TWData>, Pointer<TWString>, Pointer<TWData>, Int32), Pointer<Void> Function(Pointer<TWData>, Pointer<TWString>, Pointer<TWData>, int)>('dartTWStoredKeyImportPrivateKey'),
        importJSON = lib.lookupFunction<Pointer<Void> Function(Pointer<TWData>), Pointer<Void> Function(Pointer<TWData>)>('dartTWStoredKeyImportJSON'),
        load = lib.lookupFunction<Pointer<Void> Function(Pointer<TWString>), Pointer<Void> Function(Pointer<TWString>)>('dartTWStoredKeyLoad'),
        delete = lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('dartTWStoredKeyDelete'),
        name = lib.lookupFunction<Pointer<TWString> Function(Pointer<Void>), Pointer<TWString> Function(Pointer<Void>)>('dartTWStoredKeyName'),
        identifier = lib.lookupFunction<Pointer<TWString> Function(Pointer<Void>), Pointer<TWString> Function(Pointer<Void>)>('dartTWStoredKeyIdentifier'),
        isMnemonic = lib.lookupFunction<Bool Function(Pointer<Void>), bool Function(Pointer<Void>)>('dartTWStoredKeyIsMnemonic'),
        accountCount = lib.lookupFunction<IntPtr Function(Pointer<Void>), int Function(Pointer<Void>)>('dartTWStoredKeyAccountCount'),
        store = lib.lookupFunction<Bool Function(Pointer<Void>, Pointer<TWString>), bool Function(Pointer<Void>, Pointer<TWString>)>('dartTWStoredKeyStore'),
        decryptPrivateKey = lib.lookupFunction<Pointer<TWData> Function(Pointer<Void>, Pointer<TWData>), Pointer<TWData> Function(Pointer<Void>, Pointer<TWData>)>('dartTWStoredKeyDecryptPrivateKey'),
        decryptMnemonic = lib.lookupFunction<Pointer<TWString> Function(Pointer<Void>, Pointer<TWData>), Pointer<TWString> Function(Pointer<Void>, Pointer<TWData>)>('dartTWStoredKeyDecryptMnemonic'),
        privateKey = lib.lookupFunction<Pointer<Void> Function(Pointer<Void>, Int32, Pointer<TWData>), Pointer<Void> Function(Pointer<Void>, int, Pointer<TWData>)>('dartTWStoredKeyPrivateKey'),
        wallet = lib.lookupFunction<Pointer<Void> Function(Pointer<Void>, Pointer<TWData>), Pointer<Void> Function(Pointer<Void>, Pointer<TWData>)>('dartTWStoredKeyWallet'),
        exportJSON = lib.lookupFunction<Pointer<TWData> Function(Pointer<Void>), Pointer<TWData> Function(Pointer<Void>)>('dartTWStoredKeyExportJSON'),
        fixAddresses = lib.lookupFunction<Bool Function(Pointer<Void>, Pointer<TWData>), bool Function(Pointer<Void>, Pointer<TWData>)>('dartTWStoredKeyFixAddresses');
}
