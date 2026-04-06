import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

class TWCoinConfigFFI {
  final Pointer<TWString> Function(int) getSymbol;
  final int Function(int) getDecimals;
  final Pointer<TWString> Function(int) getID;
  final Pointer<TWString> Function(int) getName;
  final Pointer<TWString> Function(int, Pointer<TWString>) getTransactionURL;
  final Pointer<TWString> Function(int, Pointer<TWString>) getAccountURL;

  TWCoinConfigFFI(DynamicLibrary lib)
      : getSymbol = lib.lookupFunction<Pointer<TWString> Function(Int32), Pointer<TWString> Function(int)>('dartTWCoinTypeConfigurationGetSymbol'),
        getDecimals = lib.lookupFunction<Int32 Function(Int32), int Function(int)>('dartTWCoinTypeConfigurationGetDecimals'),
        getID = lib.lookupFunction<Pointer<TWString> Function(Int32), Pointer<TWString> Function(int)>('dartTWCoinTypeConfigurationGetID'),
        getName = lib.lookupFunction<Pointer<TWString> Function(Int32), Pointer<TWString> Function(int)>('dartTWCoinTypeConfigurationGetName'),
        getTransactionURL = lib.lookupFunction<Pointer<TWString> Function(Int32, Pointer<TWString>), Pointer<TWString> Function(int, Pointer<TWString>)>('dartTWCoinTypeConfigurationGetTransactionURL'),
        getAccountURL = lib.lookupFunction<Pointer<TWString> Function(Int32, Pointer<TWString>), Pointer<TWString> Function(int, Pointer<TWString>)>('dartTWCoinTypeConfigurationGetAccountURL');
}
