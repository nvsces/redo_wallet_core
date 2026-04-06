// ═══════════════════════════════════════════════════════════════
//  TON Transfer — подпись и реальная отправка в сеть
//
//  1. Создаём кошелёк из мнемоники
//  2. Получаем sequence number (seqno) из сети
//  3. Строим и подписываем транзакцию через wallet-core FFI
//  4. Отправляем BOC в TON через toncenter API
//
//  Запуск: dart run example/sign_ton.dart
//
//  ⚠️  Используется testnet! Для mainnet замените:
//      - tonApiBase на https://toncenter.com/api/v2
//      - получите API key на https://toncenter.com
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:redo_wallet_core/redo_wallet_core.dart';
import 'package:redo_wallet_core/src/proto/TheOpenNetwork.pb.dart' as ton;

// Testnet API (без ключа, rate-limited)
const tonApiBase = 'https://testnet.toncenter.com/api/v2';

String _hex(Uint8List data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

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

/// Получить баланс кошелька в nanotons
Future<BigInt> getBalance(String address) async {
  final url = Uri.parse('$tonApiBase/getAddressBalance?address=$address');
  final resp = await http.get(url);
  final json = jsonDecode(resp.body);
  if (json['ok'] != true) return BigInt.zero;
  return BigInt.parse(json['result'].toString());
}

/// Получить sequence number (seqno) кошелька
Future<int> getSeqno(String address) async {
  final url = Uri.parse('$tonApiBase/runGetMethod');
  final resp = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'address': address,
      'method': 'seqno',
      'stack': [],
    }),
  );
  final json = jsonDecode(resp.body);
  if (json['ok'] != true) return 0; // кошелёк не инициализирован
  final stack = json['result']['stack'] as List;
  if (stack.isEmpty) return 0;
  return int.parse(stack[0][1].toString().replaceFirst('0x', ''), radix: 16);
}

/// Отправить подписанный BOC в сеть
Future<Map<String, dynamic>> sendBoc(String bocBase64) async {
  final url = Uri.parse('$tonApiBase/sendBoc');
  final resp = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'boc': bocBase64}),
  );
  return jsonDecode(resp.body) as Map<String, dynamic>;
}

void main() async {
  print('=== TON Transfer (real network) ===\n');

  final api = WalletCoreAPI();

  // ── 1. Кошелёк отправителя ──
  const senderMnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  final senderWallet = api.hdWalletFromMnemonic(senderMnemonic);
  final senderAddress = senderWallet.getAddressForCoin(TWCoinType.ton);
  final senderPrivateKey = senderWallet.getPrivateKeyForCoin(TWCoinType.ton);

  print('Отправитель:');
  print('  Адрес: $senderAddress');
  print('');

  // ── 2. Кошелёк получателя (генерируем новый) ──
  final receiverWallet = api.hdWalletCreate(strength: 128);
  final receiverAddress = receiverWallet.getAddressForCoin(TWCoinType.ton);

  print('Получатель:');
  print('  Адрес: $receiverAddress');
  print('');

  // ── 3. Запрашиваем данные из сети ──
  print('Запрос к TON testnet...');
  final balance = await getBalance(senderAddress);
  final balanceTon = (balance.toDouble() / 1e9).toStringAsFixed(4);
  print('  Баланс:  $balanceTon TON ($balance nanotons)');

  await Future.delayed(const Duration(seconds: 2));
  final seqno = await getSeqno(senderAddress);
  print('  Seqno:   $seqno');

  if (balance == BigInt.zero) {
    print('');
    print('⚠️  Баланс 0! Для тестирования пополните кошелёк:');
    print('   Адрес: $senderAddress');
    print('   Testnet faucet: https://t.me/testgiver_ton_bot');
    print('   Отправьте любую сумму на этот адрес и запустите снова.');
    senderWallet.delete();
    return;
  }

  // ── 4. Строим транзакцию ──
  // Отправляем половину баланса (чтобы хватило на комиссию ~0.005 TON)
  final amountNanotons = balance ~/ BigInt.two;
  final amountTon = (amountNanotons.toDouble() / 1e9).toStringAsFixed(4);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  print('');
  print('Транзакция:');
  print('  Сумма:       $amountTon TON');
  print('  Комментарий: Hello from Dart FFI!');
  print('  Expire:      ${DateTime.fromMillisecondsSinceEpoch((now + 600) * 1000)}');

  final signingInput = ton.SigningInput(
    privateKey: senderPrivateKey,
    walletVersion: ton.WalletVersion.WALLET_V4_R2,
    sequenceNumber: seqno,
    expireAt: now + 600,
    messages: [
      ton.Transfer(
        dest: receiverAddress,
        amount: _bigIntToBytes(amountNanotons),
        mode: 3,
        bounceable: false,
        comment: 'Hello from Dart FFI!',
      ),
    ],
  );

  // ── 5. Подписываем через wallet-core FFI ──
  final inputBytes = Uint8List.fromList(signingInput.writeToBuffer());
  final outputBytes = api.signTransaction(inputBytes, TWCoinType.ton);
  final signingOutput = ton.SigningOutput.fromBuffer(outputBytes);

  if (signingOutput.errorMessage.isNotEmpty) {
    print('  ОШИБКА подписи: ${signingOutput.errorMessage}');
    senderWallet.delete();
    return;
  }

  final boc = signingOutput.encoded;
  final txHash = _hex(Uint8List.fromList(signingOutput.hash));
  print('  TX hash: $txHash');
  print('');

  // ── 6. Отправляем в сеть! ──
  await Future.delayed(const Duration(seconds: 2));
  print('Отправляем в TON testnet...');
  final result = await sendBoc(boc);

  if (result['ok'] == true) {
    print('  ✅ Транзакция отправлена!');
    print('  TX hash: $txHash');
    print('  Explorer: https://testnet.tonviewer.com/transaction/$txHash');
  } else {
    final error = result['error']?.toString() ?? result.toString();
    print('  ❌ Ошибка от ноды: $error');

    if (error.contains('exitcode=0') && error.contains('steps=0')) {
      print('');
      print('  Скорее всего кошелёк не инициализирован (не деплоен).');
      print('  Для инициализации нужно ~0.05 TON на балансе.');
      print('  Пополните через testnet faucet: https://t.me/testgiver_ton_bot');
      print('  Адрес: $senderAddress');
    }

    print('');
    print('  BOC (для ручной отправки):');
    print('  $boc');
  }

  senderWallet.delete();
  receiverWallet.delete();
  print('\n=== Готово! ===');
}
