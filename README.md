# wallet_core

Dart FFI биндинги к [Trust Wallet Core](https://github.com/trustwallet/wallet-core) — C++ библиотеке криптографии для 130+ блокчейнов.

Вместо того чтобы переписывать криптографию на Dart (небезопасно и медленно), мы используем проверенный C++/Rust код через `dart:ffi`.

## Что работает

```dart
final api = WalletCoreAPI();

// Хеширование (нативный C++ trezor-crypto)
api.hashSHA256(data);
api.hashKeccak256(data);

// BIP39 мнемоника
api.mnemonicIsValid('abandon abandon ... about'); // true

// HD-кошелёк — создание и восстановление
final wallet = api.hdWalletCreate(strength: 128); // 12 слов
wallet.mnemonic;                                   // "word1 word2 ..."
wallet.getAddressForCoin(TWCoinType.ethereum);     // "0x..."
wallet.getAddressForCoin(TWCoinType.bitcoin);      // "bc1q..."
wallet.getAddressForCoin(TWCoinType.solana);       // "base58..."
wallet.getPrivateKeyForCoin(TWCoinType.ethereum);  // Uint8List
wallet.delete();                                   // освобождаем нативную память
```

## Архитектура

```
Dart API            (lib/src/core/)       ← WalletCoreAPI, HDWallet
    ↓
FFI Bindings        (lib/src/ffi/)        ← lookupFunction к dartTW* символам
    ↓
tw_exports.c        (build/)              ← visibility-обёртки (см. ниже почему)
    ↓
C Interface         (include/TW*.h)       ← strict C ABI wallet-core
    ↓
C++ Core + Rust     (src/, rust/)         ← secp256k1, ed25519, BIP32, 130+ блокчейнов
    ↓
trezor-crypto       (trezor-crypto/)      ← форк Trezor — криптографические примитивы
```

## Как мы это собирали — пошаговое руководство

### Шаг 1: Клонируем wallet-core

```bash
cd /Users/nvsces/source/dart/core
git clone --depth 1 https://github.com/trustwallet/wallet-core.git wallet-core-native
cd wallet-core-native
```

### Шаг 2: Устанавливаем системные зависимости

```bash
brew install boost ninja cmake
cargo install cbindgen   # для генерации Rust→C хедеров
```

### Шаг 3: Устанавливаем зависимости wallet-core

```bash
# Скачивает и собирает: protobuf, googletest, libcheck
export BOOST_ROOT=$(brew --prefix boost)
tools/install-dependencies
```

Это создаёт `build/local/` с protoc, gtest и другими инструментами.

### Шаг 4: Генерируем код

Wallet-core использует кодогенерацию — protobuf, Rust bindgen, C typedef headers:

```bash
export PATH="$HOME/.cargo/bin:$PWD/build/local/bin:$PATH"
export BOOST_ROOT=$(brew --prefix boost)

# 1. Protobuf → C++ (основные .proto файлы)
cd src && protoc -I=proto --cpp_out=proto proto/*.proto && cd ..

# 2. Protobuf → C++ (блокчейн-специфичные .proto)
find src -name "*.proto" -not -path "src/proto/*" | while read f; do
  dir=$(dirname "$f")
  protoc -I="$dir" --cpp_out="$dir" "$f"
done

# 3. Protobuf → C typedef headers (для include/TrustWalletCore/)
PREFIX="$PWD/build/local"
$PREFIX/bin/protoc -I=$PREFIX/include -I=src/proto \
  --plugin=$PREFIX/bin/protoc-gen-c-typedef \
  --c-typedef_out include/TrustWalletCore \
  src/proto/*.proto

# 4. Rust → C header (cbindgen)
cd rust && cbindgen --crate wallet-core-rs \
  --output ../src/rust/bindgen/WalletCoreRSBindgen.h && cd ..
cp rust/target/release/libwallet_core_rs.a build/local/lib/

# 5. C++ codegen (генерирует доп. хедеры)
cd codegen-v2 && cargo run -- cpp && cd ..
```

### Шаг 5: Собираем статическую библиотеку

```bash
cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DTW_UNITY_BUILD=ON \
  -DCMAKE_C_FLAGS="-fvisibility=default" \
  -DCMAKE_CXX_FLAGS="-fvisibility=default"

make -Cbuild -j12 TrustWalletCore
```

Результат: `build/libTrustWalletCore.a` — статическая библиотека.

### Шаг 6: Проблема с visibility (и как мы её решили)

**Проблема:** wallet-core компилируется с `__attribute__((visibility("hidden")))` на всех TW* функциях. Даже с `-fvisibility=default` в cmake, объектные файлы содержат `.hidden` маркер:

```bash
$ objdump -t build/libTrustWalletCore.a | grep TWHashSHA256
0000001524 g F __TEXT,__text .hidden _TWHashSHA256
#                                    ^^^^^^^ — не видна в .dylib!
```

`dart:ffi` может вызывать только **exported** (глобально видимые) символы из `.dylib`. TWString и TWData экспортируются (у них нет hidden), но все остальные TW* функции — скрыты.

**Решение:** C-файл `tw_exports.c` — тонкие обёртки с `visibility("default")`:

```c
#define EXPORT __attribute__((visibility("default")))

// Вместо скрытого TWHashSHA256 экспортируем dartTWHashSHA256
EXPORT TWData* dartTWHashSHA256(TWData* data) {
    return TWHashSHA256(data);  // вызывает hidden функцию внутри .a
}
```

Каждая обёртка — это один `call` instruction, overhead ~0.

**Почему префикс `dartTW`?** Rust-часть wallet-core уже использует `tw_` префикс для своих символов (например `tw_any_address_delete`). Чтобы избежать конфликтов, наши обёртки называются `dartTW*`.

### Шаг 7: Собираем .dylib из всех частей

```bash
# Компилируем обёртку
clang -c -fvisibility=default \
  -I include -I src -I build/local/include \
  build/tw_exports.c -o build/tw_exports.o

# Линкуем всё в одну .dylib
clang++ -shared -o build/libTrustWalletCore.dylib \
  build/tw_exports.o \
  -Wl,-force_load,build/libTrustWalletCore.a \
  -Wl,-force_load,build/trezor-crypto/libTrezorCrypto.a \
  -Wl,-force_load,build/local/lib/libprotobuf.a \
  -Wl,-force_load,build/local/lib/libwallet_core_rs.a \
  -lc++ -lz -framework Security -framework CoreFoundation \
  -Wl,-undefined,dynamic_lookup
```

`-force_load` — загрузить ВСЕ объектные файлы из `.a` (иначе линкер выбросит "ненужные").

`-undefined,dynamic_lookup` — несколько Monero-специфичных символов отсутствуют, подавляем ошибку.

Проверяем что символы экспортируются:

```bash
$ nm -gU build/libTrustWalletCore.dylib | grep "dartTW" | wc -l
37
```

### Шаг 8: Копируем в Dart проект

```bash
cp build/libTrustWalletCore.dylib ../wallet_core/lib/
```

### Шаг 9: Запускаем

```bash
cd ../wallet_core
dart run example/wallet_core_example.dart
```

## Структура Dart-проекта

```
lib/
├── wallet_core.dart              ← экспорт всех модулей
├── src/
│   ├── ffi/                      ← сырые FFI биндинги
│   │   ├── tw_library.dart       ← загрузка .dylib
│   │   ├── tw_string_ffi.dart    ← TWString: Create/Delete/UTF8Bytes
│   │   ├── tw_data_ffi.dart      ← TWData: Create/Delete/Bytes/Size
│   │   ├── tw_hash_ffi.dart      ← SHA256/Keccak256/RIPEMD/Blake2b
│   │   ├── tw_mnemonic_ffi.dart  ← IsValid/IsValidWord/Suggest
│   │   ├── tw_hd_wallet_ffi.dart ← Create/Mnemonic/Seed/GetKey/GetAddress
│   │   └── tw_private_key_ffi.dart ← Create/Sign/GetPublicKey
│   └── core/                     ← удобные Dart-обёртки
│       ├── tw_string.dart        ← TWStringWrapper (String ↔ TWString*)
│       ├── tw_data.dart          ← TWDataWrapper (Uint8List ↔ TWData*)
│       └── wallet_core_api.dart  ← WalletCoreAPI, HDWallet, TWCoinType
example/
└── wallet_core_example.dart      ← рабочий пример
```

## Как устроены FFI биндинги

Все TW* типы — **opaque pointers** (`Pointer<Void>` в Dart):

```dart
// C:  TWString* TWStringCreateWithUTF8Bytes(const char* bytes)
// Dart FFI:
typedef TWStringCreateNative = Pointer<Void> Function(Pointer<Utf8>);
typedef TWStringCreateDart   = Pointer<Void> Function(Pointer<Utf8>);

final create = lib.lookupFunction<TWStringCreateNative, TWStringCreateDart>(
  'TWStringCreateWithUTF8Bytes',
);
```

**Управление памятью** — ручное, через Create/Delete:

```dart
final twStr = TWStringWrapper.fromString(ffi, 'hello');
try {
  // используем twStr.pointer
} finally {
  twStr.delete();  // ОБЯЗАТЕЛЬНО — иначе утечка нативной памяти
}

// Или через хелпер:
TWStringWrapper.withString(ffi, 'hello', (ptr) {
  // автоматически удалится после callback
});
```

## Что дальше

- [ ] TWAnyAddress — валидация адресов
- [ ] TWAnySigner — подпись транзакций (protobuf)
- [ ] TWEthereumAbi — вызовы смарт-контрактов
- [ ] Тесты
- [ ] Flutter plugin (iOS/Android с предсобранными .a/.so)
