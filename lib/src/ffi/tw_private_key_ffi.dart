import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';

typedef _CreateNative = Pointer<Void> Function();
typedef _CreateDart = Pointer<Void> Function();
typedef _CreateWithDataNative = Pointer<Void> Function(Pointer<TWData>);
typedef _CreateWithDataDart = Pointer<Void> Function(Pointer<TWData>);
typedef _DeleteNative = Void Function(Pointer<Void>);
typedef _DeleteDart = void Function(Pointer<Void>);
typedef _DataNative = Pointer<TWData> Function(Pointer<Void>);
typedef _DataDart = Pointer<TWData> Function(Pointer<Void>);
typedef _GetPubKeySecp256k1Native = Pointer<Void> Function(Pointer<Void>, Bool);
typedef _GetPubKeySecp256k1Dart = Pointer<Void> Function(Pointer<Void>, bool);
typedef _GetPubKeyEd25519Native = Pointer<Void> Function(Pointer<Void>);
typedef _GetPubKeyEd25519Dart = Pointer<Void> Function(Pointer<Void>);
typedef _SignNative = Pointer<TWData> Function(Pointer<Void>, Pointer<TWData>, Int32);
typedef _SignDart = Pointer<TWData> Function(Pointer<Void>, Pointer<TWData>, int);

// PublicKey
typedef _PubKeyDeleteNative = Void Function(Pointer<Void>);
typedef _PubKeyDeleteDart = void Function(Pointer<Void>);
typedef _PubKeyDataNative = Pointer<TWData> Function(Pointer<Void>);
typedef _PubKeyDataDart = Pointer<TWData> Function(Pointer<Void>);

class TWPrivateKeyFFI {
  final _CreateDart create;
  final _CreateWithDataDart createWithData;
  final _DeleteDart delete;
  final _DataDart data;
  final _GetPubKeySecp256k1Dart getPublicKeySecp256k1;
  final _GetPubKeyEd25519Dart getPublicKeyEd25519;
  final _SignDart sign;

  TWPrivateKeyFFI(DynamicLibrary lib)
      : create = lib.lookupFunction<_CreateNative, _CreateDart>('dartTWPrivateKeyCreate'),
        createWithData = lib.lookupFunction<_CreateWithDataNative, _CreateWithDataDart>('dartTWPrivateKeyCreateWithData'),
        delete = lib.lookupFunction<_DeleteNative, _DeleteDart>('dartTWPrivateKeyDelete'),
        data = lib.lookupFunction<_DataNative, _DataDart>('dartTWPrivateKeyData'),
        getPublicKeySecp256k1 = lib.lookupFunction<_GetPubKeySecp256k1Native, _GetPubKeySecp256k1Dart>('dartTWPrivateKeyGetPublicKeySecp256k1'),
        getPublicKeyEd25519 = lib.lookupFunction<_GetPubKeyEd25519Native, _GetPubKeyEd25519Dart>('dartTWPrivateKeyGetPublicKeyEd25519'),
        sign = lib.lookupFunction<_SignNative, _SignDart>('dartTWPrivateKeySign');
}

class TWPublicKeyFFI {
  final _PubKeyDeleteDart delete;
  final _PubKeyDataDart data;

  TWPublicKeyFFI(DynamicLibrary lib)
      : delete = lib.lookupFunction<_PubKeyDeleteNative, _PubKeyDeleteDart>('dartTWPublicKeyDelete'),
        data = lib.lookupFunction<_PubKeyDataNative, _PubKeyDataDart>('dartTWPublicKeyData');
}
