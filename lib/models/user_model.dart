class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role,
  });

  final int id;
  final String name;
  final String email;
  final String? role;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString();
    return UserModel(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: (role == null || role.isEmpty) ? null : role,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
  };

  bool get isAdmin => role == 'admin';

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return '$first$second'.toUpperCase();
  }

  String get roleLabel {
    final r = role;
    if (r == null || r.isEmpty) return 'Pengguna';
    if (r == 'admin') return 'Administrator';
    return r.substring(0, 1).toUpperCase() + r.substring(1);
  }
}
