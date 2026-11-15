import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:qrscan/models/user_model.dart';
import 'package:qrscan/services/api_client.dart';
import 'package:qrscan/services/auth_service.dart';
import 'package:qrscan/services/token_storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthService service,
    required TokenStorage storage,
    required ApiClient api,
  }) : _service = service,
       _storage = storage,
       _api = api {
    _api.tokenReader = () => _token;
    _api.onUnauthorized = _handle401;
  }

  final AuthService _service;
  final TokenStorage _storage;
  final ApiClient _api;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _token;
  bool _sessionExpired = false;
  bool _disposed = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;

  /// True when the last sign-out was caused by an expired or revoked token.
  /// Cleared by the next successful [login].
  bool get sessionExpired => _sessionExpired;

  Future<void> restore() async {
    final token = await _storage.readToken();
    final user = await _storage.readUser();
    final expiresAt = await _storage.readExpiry();
    if (_disposed) return;

    if (token == null || user == null) {
      await _storage.clear();
      _status = AuthStatus.signedOut;
      _notify();
      return;
    }
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      await _localSignOut(sessionExpired: true);
      return;
    }

    _token = token;
    _user = user;
    _status = AuthStatus.signedIn;
    _notify();
    unawaited(refreshProfile().catchError((_) {}));
  }

  Future<void> login({required String email, required String password}) async {
    final installId = await _storage.readOrCreateInstallId();
    final session = await _service.login(
      email: email.trim(),
      password: password,
      deviceName: _deviceName(installId),
    );
    await _storage.save(session.token, session.user, session.expiresAt);
    _token = session.token;
    _user = session.user;
    _sessionExpired = false;
    _status = AuthStatus.signedIn;
    _notify();
  }

  Future<void> refreshProfile() async {
    final used = _token;
    if (used == null) return;
    // A 401 here is handled by the global handler (_handle401).
    final me = await _service.fetchMe();
    if (_token != used) return;
    _user = me;
    await _storage.saveUser(me);
    _notify();
  }

  Future<void> logout() async {
    final token = _token;
    await _localSignOut();
    if (token == null) return;
    try {
      await _service.logout(token: token).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best effort: the token is already forgotten locally.
    }
  }

  void _handle401(String? tokenUsed) {
    if (tokenUsed == null || tokenUsed != _token) return;
    unawaited(_localSignOut(sessionExpired: true));
  }

  Future<void> _localSignOut({bool sessionExpired = false}) async {
    _token = null;
    _user = null;
    _sessionExpired = sessionExpired;
    _status = AuthStatus.signedOut;
    // Notify first so the UI leaves protected screens immediately.
    _notify();
    await _storage.clear();
  }

  String _deviceName(String installId) {
    final short = installId.replaceAll('-', '').substring(0, 8);
    final name = 'SIPP ${Platform.operatingSystem} $short';
    return name.length > 100 ? name.substring(0, 100) : name;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _api.onUnauthorized = null;
    _api.tokenReader = null;
    super.dispose();
  }
}
