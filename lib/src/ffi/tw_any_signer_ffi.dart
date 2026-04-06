import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';

typedef _SignNative = Pointer<TWData> Function(Pointer<TWData>, Int32);
typedef _SignDart = Pointer<TWData> Function(Pointer<TWData>, int);

class TWAnySignerFFI {
  final _SignDart sign;
  final _SignDart plan;
  final _SignDart preImageHashes;

  TWAnySignerFFI(DynamicLibrary lib)
      : sign = lib.lookupFunction<_SignNative, _SignDart>('dartTWAnySignerSign'),
        plan = lib.lookupFunction<_SignNative, _SignDart>('dartTWAnySignerPlan'),
        preImageHashes = lib.lookupFunction<_SignNative, _SignDart>('dartTWTransactionCompilerPreImageHashes');
}
