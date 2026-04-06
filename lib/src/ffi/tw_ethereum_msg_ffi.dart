import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

class TWEthereumMessageSignerFFI {
  final Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>) signMessage;
  final Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>, int) signMessageEip155;
  final Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>) signTypedMessage;
  final bool Function(Pointer<Void>, Pointer<TWString>, Pointer<TWString>) verifyMessage;

  TWEthereumMessageSignerFFI(DynamicLibrary lib)
      : signMessage = lib.lookupFunction<Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>), Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>)>('dartTWEthereumMessageSignerSignMessage'),
        signMessageEip155 = lib.lookupFunction<Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>, Int32), Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>, int)>('dartTWEthereumMessageSignerSignMessageEip155'),
        signTypedMessage = lib.lookupFunction<Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>), Pointer<TWString> Function(Pointer<Void>, Pointer<TWString>)>('dartTWEthereumMessageSignerSignTypedMessage'),
        verifyMessage = lib.lookupFunction<Bool Function(Pointer<Void>, Pointer<TWString>, Pointer<TWString>), bool Function(Pointer<Void>, Pointer<TWString>, Pointer<TWString>)>('dartTWEthereumMessageSignerVerifyMessage');
}
