// ═══════════════════════════════════════════════════════════════
//  Полный demo всех возможностей wallet_core
//
//  Запуск: dart run example/full_demo.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:redo_wallet_core/redo_wallet_core.dart';

String _hex(Uint8List data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final api = WalletCoreAPI();

  // ════════════════════════════════════════════
  //  1. Coin Configuration
  // ════════════════════════════════════════════
  print('═══ Coin Configuration ═══');
  for (final coin in [
    TWCoinType.bitcoin,
    TWCoinType.ethereum,
    TWCoinType.solana,
    TWCoinType.ton,
    TWCoinType.cosmos,
    TWCoinType.tron,
    TWCoinType.dogecoin,
    TWCoinType.polkadot,
    TWCoinType.cardano,
  ]) {
    final name = api.coinName(coin);
    final symbol = api.coinSymbol(coin);
    final decimals = api.coinDecimals(coin);
    final id = api.coinID(coin);
    print('  $name ($symbol) — $decimals decimals — id: $id');
  }
  print('');

  // ════════════════════════════════════════════
  //  2. HD Wallet + адреса для всех сетей
  // ════════════════════════════════════════════
  print('═══ HD Wallet ═══');
  final wallet = api.hdWalletCreate(strength: 256); // 24 слова
  print('  Mnemonic (24 words): ${wallet.mnemonic}');
  print('');

  print('  Адреса:');
  for (final (coin, name) in [
    (TWCoinType.bitcoin, 'Bitcoin'),
    (TWCoinType.ethereum, 'Ethereum'),
    (TWCoinType.solana, 'Solana'),
    (TWCoinType.ton, 'TON'),
    (TWCoinType.cosmos, 'Cosmos'),
    (TWCoinType.tron, 'Tron'),
    (TWCoinType.litecoin, 'Litecoin'),
    (TWCoinType.dogecoin, 'Dogecoin'),
  ]) {
    print('    $name: ${wallet.getAddressForCoin(coin)}');
  }
  print('');

  // ════════════════════════════════════════════
  //  3. TON Address Converter
  // ════════════════════════════════════════════
  print('═══ TON Address Converter ═══');
  final tonAddr = wallet.getAddressForCoin(TWCoinType.ton);
  print('  Default:     $tonAddr');

  final bounceable = api.tonAddressToUserFriendly(tonAddr, bounceable: true);
  print('  Bounceable:  $bounceable');

  final nonBounceable = api.tonAddressToUserFriendly(tonAddr, bounceable: false);
  print('  Non-bounce:  $nonBounceable');

  final testnet = api.tonAddressToUserFriendly(tonAddr, bounceable: false, testnet: true);
  print('  Testnet:     $testnet');
  print('');

  // ════════════════════════════════════════════
  //  4. Explorer URLs
  // ════════════════════════════════════════════
  print('═══ Explorer URLs ═══');
  final ethAddr = wallet.getAddressForCoin(TWCoinType.ethereum);
  print('  ETH tx URL:  ${api.coinTransactionURL(TWCoinType.ethereum, "0xabc123")}');
  print('  BTC tx URL:  ${api.coinTransactionURL(TWCoinType.bitcoin, "abc123")}');
  print('');

  // ════════════════════════════════════════════
  //  5. StoredKey — шифрование кошелька
  // ════════════════════════════════════════════
  print('═══ StoredKey (шифрование) ═══');
  const password = 'my_secure_password';
  final storedKey = api.storedKeyImportHDWallet(
    wallet.mnemonic,
    'My Wallet',
    password,
    TWCoinType.ethereum,
  );

  print('  Name:        ${storedKey.name}');
  print('  Is mnemonic: ${storedKey.isMnemonic}');
  print('  Accounts:    ${storedKey.accountCount}');

  // Экспорт в JSON (keystore v3)
  final json = storedKey.exportJSON();
  if (json != null) {
    final jsonStr = utf8.decode(json);
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    print('  JSON crypto:  ${parsed['crypto']?['cipher'] ?? parsed['Crypto']?['cipher']}');
    print('  JSON version: ${parsed['version']}');

    // Сохраняем на диск
    final tmpPath = '${Directory.systemTemp.path}/wallet_test.json';
    storedKey.store(tmpPath);
    print('  Saved to:    $tmpPath');

    // Загружаем обратно
    final loaded = api.storedKeyLoad(tmpPath);
    if (loaded != null) {
      print('  Loaded name: ${loaded.name}');

      // Расшифровываем мнемонику
      final decrypted = loaded.decryptMnemonic(password);
      print('  Decrypted:   ${decrypted != null ? "OK (${decrypted.split(' ').length} words)" : "FAIL"}');
      loaded.delete();

      // Удаляем файл
      File(tmpPath).deleteSync();
    }
  }
  storedKey.delete();
  print('');

  // ════════════════════════════════════════════
  //  6. Хеширование
  // ════════════════════════════════════════════
  print('═══ Hash ═══');
  final data = Uint8List.fromList('Hello, Blockchain!'.codeUnits);
  print('  SHA256:         ${_hex(api.hashSHA256(data)).substring(0, 32)}...');
  print('  Keccak256:      ${_hex(api.hashKeccak256(data)).substring(0, 32)}...');
  print('  RIPEMD160:      ${_hex(api.hashRIPEMD(data))}');
  print('  SHA256+RIPEMD:  ${_hex(api.hashSHA256RIPEMD(data))}');
  print('  SHA256d:        ${_hex(api.hashSHA256SHA256(data)).substring(0, 32)}...');
  print('');

  // ════════════════════════════════════════════
  //  7. Адрес валидация (мульти-чейн)
  // ════════════════════════════════════════════
  print('═══ Address Validation ═══');
  final btcAddr = wallet.getAddressForCoin(TWCoinType.bitcoin);
  final solAddr = wallet.getAddressForCoin(TWCoinType.solana);

  for (final (addr, coin, coinName) in [
    (btcAddr, TWCoinType.bitcoin, 'BTC'),
    (ethAddr, TWCoinType.ethereum, 'ETH'),
    (solAddr, TWCoinType.solana, 'SOL'),
    (tonAddr, TWCoinType.ton, 'TON'),
    ('invalid', TWCoinType.bitcoin, 'BTC'),
  ]) {
    final short = addr.length > 20 ? '${addr.substring(0, 10)}...${addr.substring(addr.length - 6)}' : addr;
    print('  $short → $coinName: ${api.addressIsValid(addr, coin)}');
  }
  print('');

  wallet.delete();
  print('═══ Done! 123 native functions available ═══');
}
