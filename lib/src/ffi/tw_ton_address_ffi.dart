import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

class TWTONAddressConverterFFI {
  final Pointer<TWString> Function(Pointer<TWString>) toBoc;
  final Pointer<TWString> Function(Pointer<TWString>) fromBoc;
  final Pointer<TWString> Function(Pointer<TWString>, bool, bool) toUserFriendly;

  TWTONAddressConverterFFI(DynamicLibrary lib)
      : toBoc = lib.lookupFunction<Pointer<TWString> Function(Pointer<TWString>), Pointer<TWString> Function(Pointer<TWString>)>('dartTWTONAddressConverterToBoc'),
        fromBoc = lib.lookupFunction<Pointer<TWString> Function(Pointer<TWString>), Pointer<TWString> Function(Pointer<TWString>)>('dartTWTONAddressConverterFromBoc'),
        toUserFriendly = lib.lookupFunction<Pointer<TWString> Function(Pointer<TWString>, Bool, Bool), Pointer<TWString> Function(Pointer<TWString>, bool, bool)>('dartTWTONAddressConverterToUserFriendly');
}
