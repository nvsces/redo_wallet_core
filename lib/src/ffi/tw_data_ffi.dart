// ═══════════════════════════════════════════════════════════════
//  Этап 1: TWData — FFI биндинги к бинарным данным wallet-core
//
//  TWData — opaque pointer к буферу байтов.
//  Все хеши, ключи, подписи передаются как TWData*.
//
//  C API:
//    TWData* TWDataCreateWithBytes(const uint8_t* bytes, size_t size)
//    uint8_t* TWDataBytes(TWData* data)
//    size_t TWDataSize(TWData* data)
//    void TWDataDelete(TWData* data)
// ═══════════════════════════════════════════════════════════════

import 'dart:ffi';

// TWData — opaque pointer
typedef TWData = Void;

// ── Нативные сигнатуры ──
typedef TWDataCreateWithBytesNative = Pointer<TWData> Function(
    Pointer<Uint8> bytes, IntPtr size);
typedef TWDataCreateWithSizeNative = Pointer<TWData> Function(IntPtr size);
typedef TWDataBytesNative = Pointer<Uint8> Function(Pointer<TWData> data);
typedef TWDataSizeNative = IntPtr Function(Pointer<TWData> data);
typedef TWDataDeleteNative = Void Function(Pointer<TWData> data);
typedef TWDataCreateWithHexStringNative = Pointer<TWData> Function(
    Pointer<Void> hex); // TWString*

// ── Dart сигнатуры ──
typedef TWDataCreateWithBytesDart = Pointer<TWData> Function(
    Pointer<Uint8> bytes, int size);
typedef TWDataCreateWithSizeDart = Pointer<TWData> Function(int size);
typedef TWDataBytesDart = Pointer<Uint8> Function(Pointer<TWData> data);
typedef TWDataSizeDart = int Function(Pointer<TWData> data);
typedef TWDataDeleteDart = void Function(Pointer<TWData> data);
typedef TWDataCreateWithHexStringDart = Pointer<TWData> Function(
    Pointer<Void> hex);

class TWDataFFI {
  final TWDataCreateWithBytesDart createWithBytes;
  final TWDataCreateWithSizeDart createWithSize;
  final TWDataBytesDart bytes;
  final TWDataSizeDart size;
  final TWDataDeleteDart delete;
  final TWDataCreateWithHexStringDart createWithHexString;

  TWDataFFI(DynamicLibrary lib)
      : createWithBytes = lib.lookupFunction<TWDataCreateWithBytesNative,
            TWDataCreateWithBytesDart>('TWDataCreateWithBytes'),
        createWithSize = lib.lookupFunction<TWDataCreateWithSizeNative,
            TWDataCreateWithSizeDart>('TWDataCreateWithSize'),
        bytes = lib.lookupFunction<TWDataBytesNative, TWDataBytesDart>(
            'TWDataBytes'),
        size = lib.lookupFunction<TWDataSizeNative, TWDataSizeDart>(
            'TWDataSize'),
        delete = lib.lookupFunction<TWDataDeleteNative, TWDataDeleteDart>(
            'TWDataDelete'),
        createWithHexString = lib.lookupFunction<
            TWDataCreateWithHexStringNative,
            TWDataCreateWithHexStringDart>('TWDataCreateWithHexString');
}
