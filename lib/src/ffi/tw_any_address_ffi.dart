import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

typedef _IsValidNative = Bool Function(Pointer<TWString>, Int32);
typedef _IsValidDart = bool Function(Pointer<TWString>, int);
typedef _CreateWithStringNative = Pointer<Void> Function(Pointer<TWString>, Int32);
typedef _CreateWithStringDart = Pointer<Void> Function(Pointer<TWString>, int);
typedef _CreateWithPublicKeyNative = Pointer<Void> Function(Pointer<Void>, Int32);
typedef _CreateWithPublicKeyDart = Pointer<Void> Function(Pointer<Void>, int);
typedef _DeleteNative = Void Function(Pointer<Void>);
typedef _DeleteDart = void Function(Pointer<Void>);
typedef _DescriptionNative = Pointer<TWString> Function(Pointer<Void>);
typedef _DescriptionDart = Pointer<TWString> Function(Pointer<Void>);

class TWAnyAddressFFI {
  final _IsValidDart isValid;
  final _CreateWithStringDart createWithString;
  final _CreateWithPublicKeyDart createWithPublicKey;
  final _DeleteDart delete;
  final _DescriptionDart description;

  TWAnyAddressFFI(DynamicLibrary lib)
      : isValid = lib.lookupFunction<_IsValidNative, _IsValidDart>('dartTWAnyAddressIsValid'),
        createWithString = lib.lookupFunction<_CreateWithStringNative, _CreateWithStringDart>('dartTWAnyAddressCreateWithString'),
        createWithPublicKey = lib.lookupFunction<_CreateWithPublicKeyNative, _CreateWithPublicKeyDart>('dartTWAnyAddressCreateWithPublicKey'),
        delete = lib.lookupFunction<_DeleteNative, _DeleteDart>('dartTWAnyAddressDelete'),
        description = lib.lookupFunction<_DescriptionNative, _DescriptionDart>('dartTWAnyAddressDescription');
}
