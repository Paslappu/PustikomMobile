import 'package:qrscan/models/user_model.dart';

class AuthSession {
  const AuthSession({required this.token, required this.user, this.expiresAt});

  final String token;
  final UserModel user;
  final DateTime? expiresAt;

  /// Parses the bare `POST /auth/login` response.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Token tidak ditemukan.');
    }
    final user = json['user'];
    if (user is! Map) {
      throw const FormatException('Data pengguna tidak ditemukan.');
    }
    return AuthSession(
      token: token,
      user: UserModel.fromJson(Map<String, dynamic>.from(user)),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}
