import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Загружает нативную библиотеку TrustWalletCore.
///
/// Поэтапная сборка:
///   1. Собрать wallet-core: cd wallet-core-native && ./bootstrap.sh
///   2. cmake -Bbuild && make -Cbuild -j12
///   3. Скопировать libTrustWalletCore.dylib / .so в lib/
DynamicLibrary loadTWLibrary([String? customPath]) {
  if (customPath != null) {
    return DynamicLibrary.open(customPath);
  }

  final String libName;
  if (Platform.isMacOS) {
    libName = 'libTrustWalletCore.dylib';
  } else if (Platform.isLinux) {
    libName = 'libTrustWalletCore.so';
  } else if (Platform.isWindows) {
    libName = 'TrustWalletCore.dll';
  } else {
    throw UnsupportedError('Platform ${Platform.operatingSystem} not supported');
  }

  // Пробуем несколько путей
  final candidates = [
    path.join(Directory.current.path, 'lib', libName),
    path.join(Directory.current.path, libName),
    path.join(Directory.current.path, 'build', libName),
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return DynamicLibrary.open(candidate);
    }
  }

  // Последняя попытка — системный путь
  return DynamicLibrary.open(libName);
}
