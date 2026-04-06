// ═══════════════════════════════════════════════════════════════
//  Этап 1: TWData — Dart обёртка над нативным TWData*
//
//  Uint8List ↔ TWData* конвертация.
//
//  Паттерн:
//    final twData = TWDataWrapper.fromBytes(lib, myBytes);
//    try {
//      // передаём twData.pointer в нативную функцию
//    } finally {
//      twData.delete();
//    }
// ═══════════════════════════════════════════════════════════════

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';

class TWDataWrapper {
  final TWDataFFI _ffi;
  final Pointer<TWData> pointer;

  TWDataWrapper._(this._ffi, this.pointer);

  /// Создать TWData из Dart Uint8List
  factory TWDataWrapper.fromBytes(TWDataFFI ffi, Uint8List bytes) {
    final nativeBytes = malloc<Uint8>(bytes.length);
    nativeBytes.asTypedList(bytes.length).setAll(0, bytes);
    final ptr = ffi.createWithBytes(nativeBytes, bytes.length);
    malloc.free(nativeBytes);
    return TWDataWrapper._(ffi, ptr);
  }

  /// Обернуть существующий TWData* (принимает ownership)
  factory TWDataWrapper.fromPointer(TWDataFFI ffi, Pointer<TWData> ptr) {
    return TWDataWrapper._(ffi, ptr);
  }

  /// Получить Dart Uint8List из TWData
  Uint8List toBytes() {
    final size = _ffi.size(pointer);
    final bytesPtr = _ffi.bytes(pointer);
    return Uint8List.fromList(bytesPtr.asTypedList(size));
  }

  /// Размер данных
  int get length => _ffi.size(pointer);

  /// Освободить нативную память
  void delete() {
    _ffi.delete(pointer);
  }

  /// Хелпер: создать TWData, выполнить callback, удалить.
  static R withBytes<R>(TWDataFFI ffi, Uint8List bytes, R Function(Pointer<TWData>) fn) {
    final wrapper = TWDataWrapper.fromBytes(ffi, bytes);
    try {
      return fn(wrapper.pointer);
    } finally {
      wrapper.delete();
    }
  }
}
