// ═══════════════════════════════════════════════════════════════
//  Этап 1: TWString — FFI биндинги к строкам wallet-core
//
//  TWString — opaque pointer (const void*) к UTF-8 строке.
//  Wallet-core использует свой тип строки вместо char* потому что:
//  - Явное управление памятью (Create/Delete)
//  - Единый интерфейс для всех языков (Swift, Kotlin, Dart)
//
//  C API:
//    TWString* TWStringCreateWithUTF8Bytes(const char* bytes)
//    const char* TWStringUTF8Bytes(TWString* string)
//    size_t TWStringSize(TWString* string)
//    void TWStringDelete(TWString* string)
// ═══════════════════════════════════════════════════════════════

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ── Типы ──
// TWString — opaque pointer, в C это const void*
typedef TWString = Void;

// ── Нативные сигнатуры (C) ──
// const char* → Pointer<Char>, но для удобства конвертации используем Utf8
typedef TWStringCreateWithUTF8BytesNative = Pointer<TWString> Function(
    Pointer<Utf8> bytes);
typedef TWStringUTF8BytesNative = Pointer<Utf8> Function(
    Pointer<TWString> string);
typedef TWStringSizeNative = IntPtr Function(Pointer<TWString> string);
typedef TWStringDeleteNative = Void Function(Pointer<TWString> string);

// ── Dart сигнатуры ──
typedef TWStringCreateWithUTF8BytesDart = Pointer<TWString> Function(
    Pointer<Utf8> bytes);
typedef TWStringUTF8BytesDart = Pointer<Utf8> Function(
    Pointer<TWString> string);
typedef TWStringSizeDart = int Function(Pointer<TWString> string);
typedef TWStringDeleteDart = void Function(Pointer<TWString> string);

/// Загружает функции TWString из DynamicLibrary
class TWStringFFI {
  final TWStringCreateWithUTF8BytesDart createWithUTF8Bytes;
  final TWStringUTF8BytesDart utf8Bytes;
  final TWStringSizeDart size;
  final TWStringDeleteDart delete;

  TWStringFFI(DynamicLibrary lib)
      : createWithUTF8Bytes = lib.lookupFunction<
            TWStringCreateWithUTF8BytesNative,
            TWStringCreateWithUTF8BytesDart>('TWStringCreateWithUTF8Bytes'),
        utf8Bytes = lib.lookupFunction<TWStringUTF8BytesNative,
            TWStringUTF8BytesDart>('TWStringUTF8Bytes'),
        size = lib.lookupFunction<TWStringSizeNative, TWStringSizeDart>(
            'TWStringSize'),
        delete = lib.lookupFunction<TWStringDeleteNative, TWStringDeleteDart>(
            'TWStringDelete');
}
