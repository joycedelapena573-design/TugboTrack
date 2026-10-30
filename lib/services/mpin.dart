/// 6-digit MPIN security: salted SHA-256 stored in the device keychain
/// (iOS Keychain / Android Keystore via flutter_secure_storage).
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _key = 'tis-mpin-credential';
const int _maxAttempts = 5;
const int _lockMs = 30000;
const int mpinLength = 6;

/// Thin seam over the platform keychain so tests can use an in-memory store.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class KeychainSecureStore implements SecureStore {
  const KeychainSecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class MpinService {
  MpinService({SecureStore? store}) : _store = store ?? const KeychainSecureStore();

  final SecureStore _store;

  bool isValidMpin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<_Credential?> _readCredential() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final hash = parsed['hash'];
      final salt = parsed['salt'];
      if (hash is String && salt is String) {
        return _Credential(
          hash: hash,
          salt: salt,
          attempts: parsed['attempts'] is num ? (parsed['attempts'] as num).toInt() : 0,
          lockedUntil:
              parsed['lockedUntil'] is num ? (parsed['lockedUntil'] as num).toInt() : 0,
        );
      }
    } catch (_) {
      // corrupted credential — treat as unset
    }
    return null;
  }

  Future<void> _writeCredential(_Credential cred) =>
      _store.write(_key, jsonEncode(cred.toJson()));

  Future<bool> hasMpin() async => (await _readCredential()) != null;

  /// Create (or replace) the stored MPIN.
  Future<void> createMpin(String pin) async {
    final salt = _randomSalt();
    await _writeCredential(
      _Credential(hash: _hashPin(pin, salt), salt: salt, attempts: 0, lockedUntil: 0),
    );
  }

  /// Remaining lockout time after too many wrong attempts (0 when not locked).
  Future<int> lockoutRemainingMs() async {
    final cred = await _readCredential();
    if (cred == null) return 0;
    final remaining = cred.lockedUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : 0;
  }

  Future<VerifyResult> verifyMpin(String pin) async {
    final cred = await _readCredential();
    if (cred == null) return VerifyResult.unset();

    final lockedFor =
        cred.lockedUntil - DateTime.now().millisecondsSinceEpoch;
    if (lockedFor > 0) return VerifyResult.locked(lockedFor);

    if (_hashPin(pin, cred.salt) == cred.hash) {
      if (cred.attempts != 0 || cred.lockedUntil != 0) {
        await _writeCredential(cred.copyWith(attempts: 0, lockedUntil: 0));
      }
      return VerifyResult.success();
    }

    final attempts = cred.attempts + 1;
    final lockNow = attempts >= _maxAttempts;
    final lockedUntil = lockNow
        ? DateTime.now().millisecondsSinceEpoch + _lockMs
        : 0;
    await _writeCredential(
      cred.copyWith(
        attempts: lockNow ? 0 : attempts,
        lockedUntil: lockedUntil,
      ),
    );
    return lockNow
        ? VerifyResult.locked(_lockMs)
        : VerifyResult.wrong(_maxAttempts - attempts);
  }

  /// Verify the old MPIN, then replace it with a new one.
  Future<VerifyResult> changeMpin(String oldPin, String newPin) async {
    final result = await verifyMpin(oldPin);
    if (!result.ok) return result;
    await createMpin(newPin);
    return VerifyResult.success();
  }
}

class VerifyResult {
  VerifyResult._({
    required this.ok,
    this.reason,
    this.attemptsLeft = 0,
    this.retryInMs = 0,
  });

  factory VerifyResult.success() => VerifyResult._(ok: true);
  factory VerifyResult.wrong(int attemptsLeft) =>
      VerifyResult._(ok: false, reason: 'wrong', attemptsLeft: attemptsLeft);
  factory VerifyResult.locked(int retryInMs) =>
      VerifyResult._(ok: false, reason: 'locked', retryInMs: retryInMs);
  factory VerifyResult.unset() => VerifyResult._(ok: false, reason: 'unset');

  final bool ok;
  final String? reason;
  final int attemptsLeft;
  final int retryInMs;
}

class _Credential {
  const _Credential({
    required this.hash,
    required this.salt,
    required this.attempts,
    required this.lockedUntil,
  });

  final String hash;
  final String salt;
  final int attempts;
  final int lockedUntil;

  _Credential copyWith({int? attempts, int? lockedUntil}) => _Credential(
        hash: hash,
        salt: salt,
        attempts: attempts ?? this.attempts,
        lockedUntil: lockedUntil ?? this.lockedUntil,
      );

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'salt': salt,
        'attempts': attempts,
        'lockedUntil': lockedUntil,
      };
}
