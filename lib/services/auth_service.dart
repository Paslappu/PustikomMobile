import 'package:qrscan/models/auth_session.dart';
import 'package:qrscan/models/user_model.dart';
import 'package:qrscan/services/api_client.dart';
import 'package:qrscan/services/api_exception.dart';

abstract class AuthService {
  Future<AuthSession> login({
    required String email,
    required String password,
    required String deviceName,
  });

  Future<UserModel> fetchMe();

  /// [token] overrides the client token. Needed because the session is wiped
  /// locally before the best-effort server logout runs.
  Future<void> logout({String? token});
}

class HttpAuthService implements AuthService {
  HttpAuthService(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final json = await _api.sendJson(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password, 'device_name': deviceName},
      auth: false,
    );
    if (json is! Map) throw _unexpected();
    try {
      return AuthSession.fromJson(Map<String, dynamic>.from(json));
    } on FormatException {
      throw _unexpected();
    }
  }

  @override
  Future<UserModel> fetchMe() async {
    final json = await _api.getJson('/auth/me');
    if (json is! Map) throw _unexpected();
    final data = json['data'];
    final map = data is Map ? data : json;
    if (map['id'] is! num) throw _unexpected();
    return UserModel.fromJson(Map<String, dynamic>.from(map));
  }

  @override
  Future<void> logout({String? token}) async {
    await _api.sendJson(
      'POST',
      '/auth/logout',
      tokenOverride: token,
      timeout: const Duration(seconds: 5),
    );
  }

  ApiException _unexpected() =>
      const ApiException(ApiFailure.unknown, 'Terjadi kesalahan. Coba lagi.');
}
