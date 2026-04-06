import 'dart:ffi';

import 'package:redo_wallet_core/src/ffi/tw_data_ffi.dart';

typedef _HashNative = Pointer<TWData> Function(Pointer<TWData>);
typedef _HashDart = Pointer<TWData> Function(Pointer<TWData>);
typedef _Blake2bNative = Pointer<TWData> Function(Pointer<TWData>, IntPtr);
typedef _Blake2bDart = Pointer<TWData> Function(Pointer<TWData>, int);

class TWHashFFI {
  final _HashDart sha1;
  final _HashDart sha256;
  final _HashDart sha512;
  final _HashDart keccak256;
  final _HashDart keccak512;
  final _HashDart sha3_256;
  final _HashDart ripemd;
  final _Blake2bDart blake2b;
  final _HashDart sha256sha256;
  final _HashDart sha256ripemd;

  TWHashFFI(DynamicLibrary lib)
      : sha1 = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashSHA1'),
        sha256 = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashSHA256'),
        sha512 = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashSHA512'),
        keccak256 = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashKeccak256'),
        keccak512 = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashKeccak512'),
        sha3_256 = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashSHA3_256'),
        ripemd = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashRIPEMD'),
        blake2b = lib.lookupFunction<_Blake2bNative, _Blake2bDart>('dartTWHashBlake2b'),
        sha256sha256 = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashSHA256SHA256'),
        sha256ripemd = lib.lookupFunction<_HashNative, _HashDart>('dartTWHashSHA256RIPEMD');
}
