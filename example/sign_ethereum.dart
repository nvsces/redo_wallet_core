// ═══════════════════════════════════════════════════════════════
//  Пример: подпись Ethereum транзакции через wallet-core FFI
//
//  Поток данных:
//  1. Строим SigningInput (protobuf) в Dart
//  2. Сериализуем в bytes
//  3. Передаём в TWAnySignerSign через FFI → C++ подписывает
//  4. Получаем SigningOutput (protobuf) → десериализуем в Dart
//  5. Извлекаем signed transaction bytes
//
//  Запуск: dart run example/sign_ethereum.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:redo_wallet_core/redo_wallet_core.dart';

// Сгенерированные protobuf-классы
import 'package:redo_wallet_core/src/proto/Ethereum.pb.dart' as eth;

String _hex(Uint8List data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Конвертировать BigInt в bytes (big-endian, без лидирующих нулей).
Uint8List _bigIntToBytes(BigInt value) {
  if (value == BigInt.zero) return Uint8List.fromList([0]);
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  print('=== Ethereum Transaction Signing ===\n');

  final api = WalletCoreAPI();

  // ── 1. Создаём кошелёк из известной мнемоники ──
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  final wallet = api.hdWalletFromMnemonic(mnemonic);
  final ethAddress = wallet.getAddressForCoin(TWCoinType.ethereum);
  final privateKey = wallet.getPrivateKeyForCoin(TWCoinType.ethereum);
  print('Адрес:       $ethAddress');
  print('Private key: ${_hex(privateKey).substring(0, 16)}...\n');

  // ── 2. Строим SigningInput ──
  // Отправляем 0.01 ETH на другой адрес (EIP-1559 транзакция)
  final signingInput = eth.SigningInput(
    chainId: _bigIntToBytes(BigInt.from(1)), // Ethereum mainnet
    nonce: _bigIntToBytes(BigInt.from(0)),
    txMode: eth.TransactionMode.Enveloped, // EIP-1559
    maxInclusionFeePerGas: _bigIntToBytes(BigInt.from(2000000000)), // 2 Gwei tip
    maxFeePerGas: _bigIntToBytes(BigInt.from(30000000000)), // 30 Gwei max
    gasLimit: _bigIntToBytes(BigInt.from(21000)), // стандартный transfer
    toAddress: '0x3535353535353535353535353535353535353535',
    privateKey: privateKey,
    transaction: eth.Transaction(
      transfer: eth.Transaction_Transfer(
        amount: _bigIntToBytes(BigInt.from(10000000000000000)), // 0.01 ETH в wei
      ),
    ),
  );

  print('--- SigningInput ---');
  print('  Chain ID:    1 (Ethereum)');
  print('  To:          0x3535...3535');
  print('  Amount:      0.01 ETH');
  print('  Gas limit:   21000');
  print('  Max fee:     30 Gwei');
  print('  Tx mode:     EIP-1559 (Enveloped)');
  print('');

  // ── 3. Сериализуем protobuf → bytes ──
  final inputBytes = Uint8List.fromList(signingInput.writeToBuffer());
  print('  Input size: ${inputBytes.length} bytes');

  // ── 4. Подписываем через FFI (C++ wallet-core) ──
  final outputBytes = api.signTransaction(inputBytes, TWCoinType.ethereum);
  print('  Output size: ${outputBytes.length} bytes');

  // ── 5. Десериализуем результат ──
  final signingOutput = eth.SigningOutput.fromBuffer(outputBytes);

  print('');
  print('--- SigningOutput ---');
  if (signingOutput.errorMessage.isNotEmpty) {
    print('  ERROR: ${signingOutput.errorMessage}');
  } else {
    print('  Encoded tx: ${_hex(Uint8List.fromList(signingOutput.encoded))}');
    print('  V: ${_hex(Uint8List.fromList(signingOutput.v))}');
    print('  R: ${_hex(Uint8List.fromList(signingOutput.r))}');
    print('  S: ${_hex(Uint8List.fromList(signingOutput.s))}');
    print('');
    print('  Signed transaction готова к отправке в сеть!');
    print('  Размер: ${signingOutput.encoded.length} bytes');
  }

  wallet.delete();
  print('\n=== Готово! ===');
}
