import 'dart:ffi';
import 'dart:typed_data';

import 'package:redo_wallet_core/src/core/tw_data.dart';
import 'package:redo_wallet_core/src/core/tw_string.dart';
import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_hash_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_hd_wallet_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_library.dart';
import 'package:redo_wallet_core/src/ffi/tw_mnemonic_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_private_key_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_any_address_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_any_signer_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_coin_config_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_ethereum_msg_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_stored_key_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_string_ffi.dart';
import 'package:redo_wallet_core/src/ffi/tw_ton_address_ffi.dart';

/// TWCoinType enum — основные монеты.
/// Полный список в wallet-core: include/TrustWalletCore/TWCoinType.h
class TWCoinType {
  static const int bitcoin = 0;
  static const int ethereum = 60;
  static const int solana = 501;
  static const int cosmos = 118;
  static const int tron = 195;
  static const int litecoin = 2;
  static const int dogecoin = 3;
  static const int polkadot = 354;
  static const int cardano = 1815;
  static const int ton = 607;
}

/// Единая точка входа для wallet-core API.
class WalletCoreAPI {
  final DynamicLibrary _lib;
  late final TWStringFFI _stringFFI;
  late final TWDataFFI _dataFFI;
  late final TWHashFFI _hashFFI;
  late final TWMnemonicFFI _mnemonicFFI;
  late final TWHDWalletFFI _hdWalletFFI;
  late final TWPrivateKeyFFI _privateKeyFFI;
  late final TWPublicKeyFFI _publicKeyFFI;
  late final TWAnyAddressFFI _anyAddressFFI;
  late final TWAnySignerFFI _anySignerFFI;
  late final TWCoinConfigFFI _coinConfigFFI;
  late final TWStoredKeyFFI _storedKeyFFI;
  late final TWEthereumMessageSignerFFI _ethMsgFFI;
  late final TWTONAddressConverterFFI _tonAddressFFI;

  WalletCoreAPI([String? libraryPath]) : _lib = loadTWLibrary(libraryPath) {
    _init();
  }

  /// Создать из уже загруженной DynamicLibrary (для Flutter plugin).
  WalletCoreAPI.fromLib(this._lib) {
    _init();
  }

  void _init() {
    _stringFFI = TWStringFFI(_lib);
    _dataFFI = TWDataFFI(_lib);
    _hashFFI = TWHashFFI(_lib);
    _mnemonicFFI = TWMnemonicFFI(_lib);
    _hdWalletFFI = TWHDWalletFFI(_lib);
    _privateKeyFFI = TWPrivateKeyFFI(_lib);
    _publicKeyFFI = TWPublicKeyFFI(_lib);
    _anyAddressFFI = TWAnyAddressFFI(_lib);
    _anySignerFFI = TWAnySignerFFI(_lib);
    _coinConfigFFI = TWCoinConfigFFI(_lib);
    _storedKeyFFI = TWStoredKeyFFI(_lib);
    _ethMsgFFI = TWEthereumMessageSignerFFI(_lib);
    _tonAddressFFI = TWTONAddressConverterFFI(_lib);
  }

  // ── Hash ──

  Uint8List hashSHA256(Uint8List data) => _hashOnce(_hashFFI.sha256, data);
  Uint8List hashSHA512(Uint8List data) => _hashOnce(_hashFFI.sha512, data);
  Uint8List hashKeccak256(Uint8List data) => _hashOnce(_hashFFI.keccak256, data);
  Uint8List hashRIPEMD(Uint8List data) => _hashOnce(_hashFFI.ripemd, data);
  Uint8List hashSHA256SHA256(Uint8List data) => _hashOnce(_hashFFI.sha256sha256, data);
  Uint8List hashSHA256RIPEMD(Uint8List data) => _hashOnce(_hashFFI.sha256ripemd, data);

  Uint8List _hashOnce(Pointer<Void> Function(Pointer<Void>) fn, Uint8List data) {
    return TWDataWrapper.withBytes(_dataFFI, data, (inputPtr) {
      final resultPtr = fn(inputPtr);
      final result = TWDataWrapper.fromPointer(_dataFFI, resultPtr);
      final bytes = result.toBytes();
      result.delete();
      return bytes;
    });
  }

  // ── Mnemonic ──

  bool mnemonicIsValid(String mnemonic) {
    return TWStringWrapper.withString(_stringFFI, mnemonic, (ptr) {
      return _mnemonicFFI.isValid(ptr);
    });
  }

  bool mnemonicIsValidWord(String word) {
    return TWStringWrapper.withString(_stringFFI, word, (ptr) {
      return _mnemonicFFI.isValidWord(ptr);
    });
  }

  // ── AnyAddress ──

  /// Проверить валидность адреса для данного блокчейна.
  bool addressIsValid(String address, int coinType) {
    return TWStringWrapper.withString(_stringFFI, address, (ptr) {
      return _anyAddressFFI.isValid(ptr, coinType);
    });
  }

  /// Нормализовать адрес (привести к каноническому формату).
  /// Возвращает null если адрес невалидный.
  String? addressNormalize(String address, int coinType) {
    return TWStringWrapper.withString(_stringFFI, address, (ptr) {
      final addrPtr = _anyAddressFFI.createWithString(ptr, coinType);
      if (addrPtr == nullptr) return null;
      final descPtr = _anyAddressFFI.description(addrPtr);
      final wrapper = TWStringWrapper.fromPointer(_stringFFI, descPtr);
      final result = wrapper.toDartString();
      wrapper.delete();
      _anyAddressFFI.delete(addrPtr);
      return result;
    });
  }

  // ── AnySigner ──

  /// Подписать транзакцию. input/output — сериализованные protobuf.
  Uint8List signTransaction(Uint8List input, int coinType) {
    return TWDataWrapper.withBytes(_dataFFI, input, (inputPtr) {
      final resultPtr = _anySignerFFI.sign(inputPtr, coinType);
      final result = TWDataWrapper.fromPointer(_dataFFI, resultPtr);
      final bytes = result.toBytes();
      result.delete();
      return bytes;
    });
  }

  /// Получить план UTXO транзакции (Bitcoin и др.).
  Uint8List transactionPlan(Uint8List input, int coinType) {
    return TWDataWrapper.withBytes(_dataFFI, input, (inputPtr) {
      final resultPtr = _anySignerFFI.plan(inputPtr, coinType);
      final result = TWDataWrapper.fromPointer(_dataFFI, resultPtr);
      final bytes = result.toBytes();
      result.delete();
      return bytes;
    });
  }

  /// Получить pre-image хеши для внешней подписи.
  Uint8List preImageHashes(Uint8List input, int coinType) {
    return TWDataWrapper.withBytes(_dataFFI, input, (inputPtr) {
      final resultPtr = _anySignerFFI.preImageHashes(inputPtr, coinType);
      final result = TWDataWrapper.fromPointer(_dataFFI, resultPtr);
      final bytes = result.toBytes();
      result.delete();
      return bytes;
    });
  }

  // ── CoinType Configuration ──

  /// Символ монеты (ETH, BTC, SOL...)
  String coinSymbol(int coinType) {
    final ptr = _coinConfigFFI.getSymbol(coinType);
    final w = TWStringWrapper.fromPointer(_stringFFI, ptr);
    final r = w.toDartString();
    w.delete();
    return r;
  }

  /// Кол-во десятичных знаков (18 для ETH, 8 для BTC...)
  int coinDecimals(int coinType) => _coinConfigFFI.getDecimals(coinType);

  /// ID монеты (ethereum, bitcoin, solana...)
  String coinID(int coinType) {
    final ptr = _coinConfigFFI.getID(coinType);
    final w = TWStringWrapper.fromPointer(_stringFFI, ptr);
    final r = w.toDartString();
    w.delete();
    return r;
  }

  /// Название монеты (Ethereum, Bitcoin, Solana...)
  String coinName(int coinType) {
    final ptr = _coinConfigFFI.getName(coinType);
    final w = TWStringWrapper.fromPointer(_stringFFI, ptr);
    final r = w.toDartString();
    w.delete();
    return r;
  }

  /// URL для просмотра транзакции в explorer.
  String coinTransactionURL(int coinType, String txHash) {
    return TWStringWrapper.withString(_stringFFI, txHash, (txPtr) {
      final ptr = _coinConfigFFI.getTransactionURL(coinType, txPtr);
      final w = TWStringWrapper.fromPointer(_stringFFI, ptr);
      final r = w.toDartString();
      w.delete();
      return r;
    });
  }

  // ── TON Address Converter ──

  /// Конвертировать TON адрес в user-friendly формат.
  /// bounceable: true = EQ.., false = UQ..
  /// testnet: true = 0Q..
  String? tonAddressToUserFriendly(String address, {bool bounceable = false, bool testnet = false}) {
    return TWStringWrapper.withString(_stringFFI, address, (ptr) {
      final resultPtr = _tonAddressFFI.toUserFriendly(ptr, bounceable, testnet);
      if (resultPtr == nullptr) return null;
      final w = TWStringWrapper.fromPointer(_stringFFI, resultPtr);
      final r = w.toDartString();
      w.delete();
      return r;
    });
  }

  // ── Ethereum Message Signer ──

  /// Подписать сообщение (EIP-191 personal_sign).
  /// Возвращает hex-строку подписи.
  String ethSignMessage(Pointer<Void> privateKeyPtr, String message) {
    return TWStringWrapper.withString(_stringFFI, message, (msgPtr) {
      final resultPtr = _ethMsgFFI.signMessage(privateKeyPtr, msgPtr);
      final w = TWStringWrapper.fromPointer(_stringFFI, resultPtr);
      final r = w.toDartString();
      w.delete();
      return r;
    });
  }

  /// Подписать typed data (EIP-712).
  String ethSignTypedMessage(Pointer<Void> privateKeyPtr, String messageJson) {
    return TWStringWrapper.withString(_stringFFI, messageJson, (jsonPtr) {
      final resultPtr = _ethMsgFFI.signTypedMessage(privateKeyPtr, jsonPtr);
      final w = TWStringWrapper.fromPointer(_stringFFI, resultPtr);
      final r = w.toDartString();
      w.delete();
      return r;
    });
  }

  // ── StoredKey ──

  /// Создать зашифрованный ключ из мнемоники.
  StoredKey storedKeyImportHDWallet(String mnemonic, String name, String password, int coinType) {
    final mnemonicStr = TWStringWrapper.fromString(_stringFFI, mnemonic);
    final nameStr = TWStringWrapper.fromString(_stringFFI, name);
    final passData = TWDataWrapper.fromBytes(_dataFFI, Uint8List.fromList(password.codeUnits));
    try {
      final ptr = _storedKeyFFI.importHDWallet(mnemonicStr.pointer, nameStr.pointer, passData.pointer, coinType);
      return StoredKey._(this, ptr);
    } finally {
      mnemonicStr.delete();
      nameStr.delete();
      passData.delete();
    }
  }

  /// Загрузить зашифрованный ключ из файла.
  StoredKey? storedKeyLoad(String path) {
    return TWStringWrapper.withString(_stringFFI, path, (pathPtr) {
      final ptr = _storedKeyFFI.load(pathPtr);
      if (ptr == nullptr) return null;
      return StoredKey._(this, ptr);
    });
  }

  /// Импортировать из JSON (keystore v3).
  StoredKey? storedKeyImportJSON(Uint8List json) {
    return TWDataWrapper.withBytes(_dataFFI, json, (jsonPtr) {
      final ptr = _storedKeyFFI.importJSON(jsonPtr);
      if (ptr == nullptr) return null;
      return StoredKey._(this, ptr);
    });
  }

  // ── HD Wallet ──

  /// Создать новый HD-кошелёк (генерирует мнемонику).
  /// strength: 128 = 12 слов, 256 = 24 слова.
  HDWallet hdWalletCreate({int strength = 128, String passphrase = ''}) {
    return TWStringWrapper.withString(_stringFFI, passphrase, (passPtr) {
      final ptr = _hdWalletFFI.create(strength, passPtr);
      return HDWallet._(this, ptr);
    });
  }

  /// Восстановить HD-кошелёк из мнемоники.
  HDWallet hdWalletFromMnemonic(String mnemonic, {String passphrase = ''}) {
    final mnemonicStr = TWStringWrapper.fromString(_stringFFI, mnemonic);
    final passStr = TWStringWrapper.fromString(_stringFFI, passphrase);
    try {
      final ptr = _hdWalletFFI.createWithMnemonic(mnemonicStr.pointer, passStr.pointer);
      return HDWallet._(this, ptr);
    } finally {
      mnemonicStr.delete();
      passStr.delete();
    }
  }

  /// Async version of [hdWalletCreate]. The heavy work (entropy generation
  /// + PBKDF2 seed derivation) runs on a native std::thread inside the
  /// dylib, so the calling Dart isolate's UI/event loop stays responsive.
  ///
  /// All subsequent getter calls on the returned [HDWallet] are still
  /// synchronous — derivation of address/private key is fast.
  Future<HDWallet> hdWalletCreateAsync({int strength = 128, String passphrase = ''}) async {
    final passStr = TWStringWrapper.fromString(_stringFFI, passphrase);
    try {
      final ptr = await _hdWalletFFI.createAsync(strength, passStr.pointer);
      return HDWallet._(this, ptr);
    } finally {
      passStr.delete();
    }
  }

  /// Async version of [hdWalletFromMnemonic]. PBKDF2 seed derivation
  /// (the slow part of mnemonic import) runs on a native background
  /// thread.
  Future<HDWallet> hdWalletFromMnemonicAsync(String mnemonic, {String passphrase = ''}) async {
    final mnemonicStr = TWStringWrapper.fromString(_stringFFI, mnemonic);
    final passStr = TWStringWrapper.fromString(_stringFFI, passphrase);
    try {
      final ptr = await _hdWalletFFI.createWithMnemonicAsync(mnemonicStr.pointer, passStr.pointer);
      return HDWallet._(this, ptr);
    } finally {
      mnemonicStr.delete();
      passStr.delete();
    }
  }

}

/// HD-кошелёк — обёртка над TWHDWallet*.
class HDWallet {
  final WalletCoreAPI _api;
  final Pointer<Void> _ptr;

  HDWallet._(this._api, this._ptr);

  /// Мнемоническая фраза (12 или 24 слова).
  String get mnemonic {
    final strPtr = _api._hdWalletFFI.mnemonic(_ptr);
    final wrapper = TWStringWrapper.fromPointer(_api._stringFFI, strPtr);
    final result = wrapper.toDartString();
    wrapper.delete();
    return result;
  }

  /// Seed (64 байта).
  Uint8List get seed {
    final dataPtr = _api._hdWalletFFI.seed(_ptr);
    final wrapper = TWDataWrapper.fromPointer(_api._dataFFI, dataPtr);
    final result = wrapper.toBytes();
    wrapper.delete();
    return result;
  }

  /// Получить приватный ключ для монеты.
  Uint8List getPrivateKeyForCoin(int coinType) {
    final keyPtr = _api._hdWalletFFI.getKeyForCoin(_ptr, coinType);
    final dataPtr = _api._privateKeyFFI.data(keyPtr);
    final wrapper = TWDataWrapper.fromPointer(_api._dataFFI, dataPtr);
    final result = wrapper.toBytes();
    wrapper.delete();
    _api._privateKeyFFI.delete(keyPtr);
    return result;
  }

  /// Получить адрес для монеты.
  String getAddressForCoin(int coinType) {
    final strPtr = _api._hdWalletFFI.getAddressForCoin(_ptr, coinType);
    final wrapper = TWStringWrapper.fromPointer(_api._stringFFI, strPtr);
    final result = wrapper.toDartString();
    wrapper.delete();
    return result;
  }

  /// Освободить нативную память.
  void delete() {
    _api._hdWalletFFI.delete(_ptr);
  }
}

/// Зашифрованный ключ — обёртка над TWStoredKey*.
/// Хранит мнемонику/приватный ключ зашифрованным паролем.
class StoredKey {
  final WalletCoreAPI _api;
  final Pointer<Void> _ptr;

  StoredKey._(this._api, this._ptr);

  /// Имя ключа.
  String get name {
    final ptr = _api._storedKeyFFI.name(_ptr);
    final w = TWStringWrapper.fromPointer(_api._stringFFI, ptr);
    final r = w.toDartString();
    w.delete();
    return r;
  }

  /// Это HD-кошелёк (мнемоника)?
  bool get isMnemonic => _api._storedKeyFFI.isMnemonic(_ptr);

  /// Кол-во аккаунтов.
  int get accountCount => _api._storedKeyFFI.accountCount(_ptr);

  /// Расшифровать мнемонику паролем.
  String? decryptMnemonic(String password) {
    final passData = TWDataWrapper.fromBytes(_api._dataFFI, Uint8List.fromList(password.codeUnits));
    try {
      final ptr = _api._storedKeyFFI.decryptMnemonic(_ptr, passData.pointer);
      if (ptr == nullptr) return null;
      final w = TWStringWrapper.fromPointer(_api._stringFFI, ptr);
      final r = w.toDartString();
      w.delete();
      return r;
    } finally {
      passData.delete();
    }
  }

  /// Расшифровать приватный ключ паролем.
  Uint8List? decryptPrivateKey(String password) {
    final passData = TWDataWrapper.fromBytes(_api._dataFFI, Uint8List.fromList(password.codeUnits));
    try {
      final ptr = _api._storedKeyFFI.decryptPrivateKey(_ptr, passData.pointer);
      if (ptr == nullptr) return null;
      final w = TWDataWrapper.fromPointer(_api._dataFFI, ptr);
      final r = w.toBytes();
      w.delete();
      return r;
    } finally {
      passData.delete();
    }
  }

  /// Экспортировать в JSON (keystore v3 формат).
  Uint8List? exportJSON() {
    final ptr = _api._storedKeyFFI.exportJSON(_ptr);
    if (ptr == nullptr) return null;
    final w = TWDataWrapper.fromPointer(_api._dataFFI, ptr);
    final r = w.toBytes();
    w.delete();
    return r;
  }

  /// Сохранить на диск.
  bool store(String path) {
    return TWStringWrapper.withString(_api._stringFFI, path, (pathPtr) {
      return _api._storedKeyFFI.store(_ptr, pathPtr);
    });
  }

  /// Освободить нативную память.
  void delete() {
    _api._storedKeyFFI.delete(_ptr);
  }
}
