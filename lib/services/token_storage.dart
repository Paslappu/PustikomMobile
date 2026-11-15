import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrscan/models/user_model.dart';
import 'package:uuid/uuid.dart';

abstract class TokenStorage {
  Future<String?> readToken();
  Future<UserModel?> readUser();
  Future<DateTime?> readExpiry();
  Future<void> save(String token, UserModel user, DateTime? expiresAt);
  Future<void> saveUser(UserModel user);

  /// Removes the session. The install id is kept.
  Future<void> clear();

  /// Stable per-installation id, created on first use and kept across logout.
  Future<String> readOrCreateInstallId();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kExpires = 'auth_expires_at';
  static const _kInstallId = 'install_id';

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      debugPrint('SecureTokenStorage: read failed for $key');
      // A corrupted keystore blob (for example after a restore) cannot be
      // decrypted. Wipe it so the user can sign in again.
      try {
        await _storage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      debugPrint('SecureTokenStorage: write failed for $key');
    }
  }

  @override
  Future<String?> readToken() => _read(_kToken);

  @override
  Future<UserModel?> readUser() async {
    final raw = await _read(_kUser);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return UserModel.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<DateTime?> readExpiry() async {
    final raw = await _read(_kExpires);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> save(String token, UserModel user, DateTime? expiresAt) async {
    await _write(_kToken, token);
    await saveUser(user);
    if (expiresAt != null) {
      await _write(_kExpires, expiresAt.toIso8601String());
    } else {
      try {
        await _storage.delete(key: _kExpires);
      } catch (_) {}
    }
  }

  @override
  Future<void> saveUser(UserModel user) =>
      _write(_kUser, jsonEncode(user.toJson()));

  @override
  Future<void> clear() async {
    for (final key in const [_kToken, _kUser, _kExpires]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        debugPrint('SecureTokenStorage: delete failed for $key');
      }
    }
  }

  @override
  Future<String> readOrCreateInstallId() async {
    final existing = await _read(_kInstallId);
    if (existing != null && existing.length >= 8) return existing;
    final created = const Uuid().v4();
    await _write(_kInstallId, created);
    return created;
  }
}
