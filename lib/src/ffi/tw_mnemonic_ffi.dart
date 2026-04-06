import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

typedef _IsValidNative = Bool Function(Pointer<TWString>);
typedef _IsValidDart = bool Function(Pointer<TWString>);
typedef _SuggestNative = Pointer<TWString> Function(Pointer<TWString>);
typedef _SuggestDart = Pointer<TWString> Function(Pointer<TWString>);

class TWMnemonicFFI {
  final _IsValidDart isValid;
  final _IsValidDart isValidWord;
  final _SuggestDart suggest;

  TWMnemonicFFI(DynamicLibrary lib)
      : isValid = lib.lookupFunction<_IsValidNative, _IsValidDart>('dartTWMnemonicIsValid'),
        isValidWord = lib.lookupFunction<_IsValidNative, _IsValidDart>('dartTWMnemonicIsValidWord'),
        suggest = lib.lookupFunction<_SuggestNative, _SuggestDart>('dartTWMnemonicSuggest');
}
