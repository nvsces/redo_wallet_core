// ═══════════════════════════════════════════════════════════════
//  Этап 1: TWString — Dart обёртка над нативным TWString*
//
//  Dart String ↔ TWString* конвертация.
//  Автоматическое управление памятью через try/finally.
//
//  Паттерн использования:
//    final twStr = TWStringWrapper.fromString(lib, 'hello');
//    try {
//      // передаём twStr.pointer в нативную функцию
//    } finally {
//      twStr.delete();
//    }
//
//  Или через хелпер:
//    final result = TWStringWrapper.callWith(lib, 'hello', (ptr) {
//      return nativeFunction(ptr);
//    });
// ═══════════════════════════════════════════════════════════════

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';

class TWStringWrapper {
  final TWStringFFI _ffi;
  final Pointer<TWString> pointer;

  TWStringWrapper._(this._ffi, this.pointer);

  /// Создать TWString из Dart String
  factory TWStringWrapper.fromString(TWStringFFI ffi, String value) {
    final nativeStr = value.toNativeUtf8();
    final ptr = ffi.createWithUTF8Bytes(nativeStr);
    malloc.free(nativeStr);
    return TWStringWrapper._(ffi, ptr);
  }

  /// Обернуть существующий TWString* (принимает ownership — нужно удалить)
  factory TWStringWrapper.fromPointer(TWStringFFI ffi, Pointer<TWString> ptr) {
    return TWStringWrapper._(ffi, ptr);
  }

  /// Получить Dart String из TWString
  String toDartString() {
    final utf8Ptr = _ffi.utf8Bytes(pointer);
    return utf8Ptr.toDartString();
  }

  /// Длина строки
  int get length => _ffi.size(pointer);

  /// Освободить нативную память — ОБЯЗАТЕЛЬНО вызвать!
  void delete() {
    _ffi.delete(pointer);
  }

  /// Хелпер: создать TWString, выполнить callback, удалить.
  /// Для одноразового использования.
  static R withString<R>(TWStringFFI ffi, String value, R Function(Pointer<TWString>) fn) {
    final wrapper = TWStringWrapper.fromString(ffi, value);
    try {
      return fn(wrapper.pointer);
    } finally {
      wrapper.delete();
    }
  }

  @override
  String toString() => toDartString();
}
