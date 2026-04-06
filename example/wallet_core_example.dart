// ═══════════════════════════════════════════════════════════════
//  Wallet Core FFI — полный пример
//
//  Запуск: dart run example/wallet_core_example.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:redo_wallet_core/redo_wallet_core.dart';

String _hex(Uint8List data) => data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  print('=== Wallet Core FFI ===\n');

  final api = WalletCoreAPI();

  // ── 1. Hash (нативный C++ через FFI) ──
  print('--- Hash ---');
  final input = Uint8List.fromList('hello'.codeUnits);
  final sha256 = api.hashSHA256(input);
  print('  SHA256("hello")    = ${_hex(sha256)}');
  final keccak = api.hashKeccak256(input);
  print('  Keccak256("hello") = ${_hex(keccak)}');
  final ripemd = api.hashRIPEMD(input);
  print('  RIPEMD160("hello") = ${_hex(ripemd)}');
  print('');

  // ── 2. Mnemonic ──
  print('--- Mnemonic ---');
  print('  "abandon" — valid word? ${api.mnemonicIsValidWord("abandon")}');
  print('  "asdfgh"  — valid word? ${api.mnemonicIsValidWord("asdfgh")}');

  const testMnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  print('  12-word mnemonic valid? ${api.mnemonicIsValid(testMnemonic)}');
  print('  "invalid words here" valid? ${api.mnemonicIsValid("invalid words here")}');
  print('');

  // ── 3. HD Wallet — создать новый ──
  print('--- HD Wallet (новый) ---');
  final wallet = api.hdWalletCreate(strength: 128);
  print('  Mnemonic: ${wallet.mnemonic}');
  print('  Seed: ${_hex(wallet.seed).substring(0, 32)}...');
  print('');

  // ── 4. Адреса для разных блокчейнов ──
  print('--- Адреса ---');
  print('  Bitcoin:  ${wallet.getAddressForCoin(TWCoinType.bitcoin)}');
  print('  Ethereum: ${wallet.getAddressForCoin(TWCoinType.ethereum)}');
  print('  Solana:   ${wallet.getAddressForCoin(TWCoinType.solana)}');
  print('  Cosmos:   ${wallet.getAddressForCoin(TWCoinType.cosmos)}');
  print('');

  // ── 5. Приватные ключи ──
  print('--- Приватные ключи ---');
  final ethKey = wallet.getPrivateKeyForCoin(TWCoinType.ethereum);
  print('  ETH private key: ${_hex(ethKey).substring(0, 16)}...');
  final btcKey = wallet.getPrivateKeyForCoin(TWCoinType.bitcoin);
  print('  BTC private key: ${_hex(btcKey).substring(0, 16)}...');
  print('');

  // ── 6. Восстановление из мнемоники ──
  print('--- Восстановление ---');
  final restored = api.hdWalletFromMnemonic(testMnemonic);
  print('  Мнемоника: $testMnemonic');
  print('  Bitcoin:  ${restored.getAddressForCoin(TWCoinType.bitcoin)}');
  print('  Ethereum: ${restored.getAddressForCoin(TWCoinType.ethereum)}');
  restored.delete();
  print('');

  // ── 7. Валидация адресов (AnyAddress) ──
  print('--- Валидация адресов ---');
  // Bitcoin
  print('  "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu" BTC? '
      '${api.addressIsValid("bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu", TWCoinType.bitcoin)}');
  print('  "0x..." как BTC? '
      '${api.addressIsValid("0xdeadbeef", TWCoinType.bitcoin)}');
  // Ethereum
  print('  "0x9858EfFD232B4033E47d90003D41EC34EcaEda94" ETH? '
      '${api.addressIsValid("0x9858EfFD232B4033E47d90003D41EC34EcaEda94", TWCoinType.ethereum)}');
  print('  "not_an_address" ETH? '
      '${api.addressIsValid("not_an_address", TWCoinType.ethereum)}');
  // Кросс-чейн валидация
  print('  ETH адрес как Solana? '
      '${api.addressIsValid("0x9858EfFD232B4033E47d90003D41EC34EcaEda94", TWCoinType.solana)}');
  print('');

  // ── 8. Нормализация адресов ──
  print('--- Нормализация ---');
  // Ethereum checksum
  final normalized = api.addressNormalize(
    '0x9858effd232b4033e47d90003d41ec34ecaeda94', // lowercase
    TWCoinType.ethereum,
  );
  print('  Lowercase → checksum: $normalized');
  print('');

  wallet.delete();
  print('=== Готово! ===');
}
