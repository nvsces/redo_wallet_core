import 'dart:convert';
import 'dart:typed_data';

import 'package:redo_wallet_core/redo_wallet_core.dart';

void main() {
  final api = WalletCoreAPI();
  const m = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  final w = api.hdWalletFromMnemonic(m);

  final addr = w.getAddressForCoin(TWCoinType.ton);
  print('Bounceable (UQ...):  $addr');

  // wallet-core даёт UQ... (user-friendly bounceable)
  // Faucet хочет 0Q... (user-friendly non-bounceable, testnet)
  // Конвертируем: UQ → 0Q (меняем флаги в первом байте)

  // Декодируем base64url → 36 байт: [tag, workchain, 32-byte hash, crc16]
  var b64 = addr.replaceAll('-', '+').replaceAll('_', '/');
  while (b64.length % 4 != 0) {
    b64 += '=';
  }
  final bytes = base64Decode(b64);
  print('Raw bytes[0] tag: 0x${bytes[0].toRadixString(16)}');

  // TON address tag:
  //   0x11 = bounceable          → "EQ..." (base64url)
  //   0x51 = non-bounceable      → "UQ..." (base64url)
  // Wallet-core даёт UQ (0x51 = non-bounceable).
  // Faucet формат "0Q..." — это тоже non-bounceable, но с testnet флагом:
  //   0x51 | 0x80 = 0xD1 = testnet non-bounceable

  final modified = Uint8List.fromList(bytes);
  modified[0] = 0x51 | 0x80; // non-bounceable + testnet

  // Пересчитываем CRC16 (последние 2 байта)
  final payload = modified.sublist(0, 34);
  final crc = _crc16(payload);
  modified[34] = (crc >> 8) & 0xFF;
  modified[35] = crc & 0xFF;

  final testnetNonBounceable = base64Url.encode(modified).replaceAll('=', '');
  print('Non-bounceable (0Q): $testnetNonBounceable');

  print('');
  print('Для faucet (https://t.me/testgiver_ton_bot):');
  print('  $testnetNonBounceable');

  w.delete();
}

int _crc16(Uint8List data) {
  var crc = 0;
  for (final byte in data) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc;
}
