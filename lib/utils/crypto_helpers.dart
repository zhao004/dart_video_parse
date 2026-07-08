import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// 前端逆向算法迁移工具。
///
/// 这里只保留 Provider 需要的加密能力。所有方法均为同步纯 Dart 实现，
/// 便于 Android/iOS 直接调用，不依赖 Node、ExecJS 或服务端运行时。
abstract final class CryptoHelpers {
  static final _secureRandom = Random.secure();

  /// AES-ECB/PKCS7 加密并输出十六进制，兼容 ParseVideo。
  static String aesEcbPkcs7EncryptToHex(String plainText, String keyText) {
    final encrypted = _processAesEcb(
      true,
      utf8.encode(plainText),
      utf8.encode(keyText),
    );
    return _bytesToHex(encrypted);
  }

  /// AES-ECB/PKCS7 解密十六进制密文，兼容 ParseVideo 响应。
  static String aesEcbPkcs7DecryptHex(String cipherHex, String keyText) {
    final decrypted = _processAesEcb(
      false,
      _hexToBytes(cipherHex),
      utf8.encode(keyText),
    );
    return utf8.decode(decrypted);
  }

  /// AES-CBC/PKCS7 加密并输出 Base64，兼容 Kedou 请求体。
  static String aesCbcPkcs7EncryptBase64(
    String plainText,
    String keyText,
    Uint8List iv,
  ) {
    final encrypted = _processAesCbc(
      true,
      utf8.encode(plainText),
      utf8.encode(keyText),
      iv,
    );
    return base64Encode(encrypted);
  }

  /// AES-CBC/PKCS7 解密 Base64，兼容 KuKuTool 响应体。
  static String aesCbcPkcs7DecryptBase64(
    String cipherBase64,
    String keyText,
    String ivBase64,
  ) {
    final decrypted = _processAesCbc(
      false,
      base64Decode(cipherBase64),
      utf8.encode(keyText),
      base64Decode(ivBase64),
    );
    return utf8.decode(decrypted);
  }

  /// OpenSSL `Salted__` AES-256-CBC 加密，兼容 SPAPI。
  static String opensslAesEncrypt(String plainText, String passphrase) {
    final salt = _randomBytes(8);
    final keyIv = _evpBytesToKey(utf8.encode(passphrase), salt, 32, 16);
    final encrypted = _processAesCbc(
      true,
      utf8.encode(plainText),
      keyIv.key,
      keyIv.iv,
    );
    return base64Encode(
      Uint8List.fromList([...ascii.encode('Salted__'), ...salt, ...encrypted]),
    );
  }

  /// OpenSSL `Salted__` AES-256-CBC 解密，兼容 SPAPI。
  static String opensslAesDecrypt(String cipherTextBase64, String passphrase) {
    final data = base64Decode(cipherTextBase64);
    if (data.length < 16 || ascii.decode(data.sublist(0, 8)) != 'Salted__') {
      throw const FormatException('Unsupported OpenSSL ciphertext format');
    }
    final salt = data.sublist(8, 16);
    final encrypted = data.sublist(16);
    final keyIv = _evpBytesToKey(utf8.encode(passphrase), salt, 32, 16);
    final decrypted = _processAesCbc(false, encrypted, keyIv.key, keyIv.iv);
    return utf8.decode(decrypted);
  }

  /// RSA 公钥加密长文本并输出 Base64，兼容 Kedou。
  static String rsaPublicEncryptLongBase64(
    String text,
    String publicKeyPem, {
    int chunkSize = 117,
  }) {
    if (text.isEmpty) {
      return '';
    }
    final publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
    final engine = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final input = utf8.encode(text);
    final output = BytesBuilder();
    for (var offset = 0; offset < input.length; offset += chunkSize) {
      final end = min(offset + chunkSize, input.length);
      output.add(
        engine.process(Uint8List.fromList(input.sublist(offset, end))),
      );
    }
    return base64Encode(output.toBytes());
  }

  /// RSA 公钥解密 Base64，兼容 Kedou 服务端返回的 AES key 包装。
  static String rsaPublicDecryptBase64(
    String cipherBase64,
    String publicKeyPem,
  ) {
    final publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
    final engine = PKCS1Encoding(RSAEngine())
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
    final plain = engine.process(base64Decode(cipherBase64));
    return utf8.decode(plain);
  }

  /// AES-256-GCM 加密并把密文和 tag 拼接，兼容 KuKuTool 请求。
  static ({String payloadBase64, String ivBase64}) aesGcmEncryptJson(
    String jsonText,
    Uint8List key,
  ) {
    final iv = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(jsonText)));
    return (payloadBase64: base64Encode(encrypted), ivBase64: base64Encode(iv));
  }

  /// SHA256 字节摘要。
  static Uint8List sha256Bytes(String value) {
    return Uint8List.fromList(sha256.convert(utf8.encode(value)).bytes);
  }

  static Uint8List _processAesEcb(
    bool forEncryption,
    List<int> data,
    List<int> key,
  ) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
          ..init(
            forEncryption,
            PaddedBlockCipherParameters(
              KeyParameter(Uint8List.fromList(key)),
              null,
            ),
          );
    return cipher.process(Uint8List.fromList(data));
  }

  static Uint8List _processAesCbc(
    bool forEncryption,
    List<int> data,
    List<int> key,
    List<int> iv,
  ) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            forEncryption,
            PaddedBlockCipherParameters(
              ParametersWithIV(
                KeyParameter(Uint8List.fromList(key)),
                Uint8List.fromList(iv),
              ),
              null,
            ),
          );
    return cipher.process(Uint8List.fromList(data));
  }

  static _KeyIv _evpBytesToKey(
    List<int> password,
    List<int> salt,
    int keyLength,
    int ivLength,
  ) {
    final targetLength = keyLength + ivLength;
    final derived = <int>[];
    var block = <int>[];
    while (derived.length < targetLength) {
      block = md5.convert([...block, ...password, ...salt]).bytes;
      derived.addAll(block);
    }
    return _KeyIv(
      Uint8List.fromList(derived.sublist(0, keyLength)),
      Uint8List.fromList(derived.sublist(keyLength, targetLength)),
    );
  }

  static Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
    );
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.trim();
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _KeyIv {
  const _KeyIv(this.key, this.iv);

  final Uint8List key;
  final Uint8List iv;
}
