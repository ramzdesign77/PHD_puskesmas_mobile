class UserModel {
  const UserModel({
    required this.token,
    required this.roles,
    this.name,
    this.email,
  });

  final String token;
  final List<String> roles;
  final String? name;
  final String? email;

  factory UserModel.fromLoginJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']) ?? json;
    final user = _asMap(data['user']) ?? _asMap(json['user']) ?? const {};
    final rawToken = data['token'] ?? data['access_token'] ?? json['token'];
    final rawRoles = data['roles'] ?? user['roles'] ?? json['roles'];

    if (rawToken is! String || rawToken.trim().isEmpty) {
      throw const FormatException('Token tidak ditemukan pada respons login.');
    }
    if (rawRoles is! List ||
        rawRoles.any((role) => role is! String && role is! Map)) {
      throw const FormatException('Daftar role tidak valid pada respons login.');
    }

    return UserModel(
      token: rawToken.trim(),
      roles: rawRoles
          .map(_roleName)
          .whereType<String>()
          .map((role) => role.trim().toLowerCase())
          .where((role) => role.isNotEmpty)
          .toList(growable: false),
      name: _stringOrNull(user['name'] ?? user['nama_lengkap']),
      email: _stringOrNull(user['email']),
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  static String? _stringOrNull(Object? value) =>
      value is String ? value : null;

  static String? _roleName(Object? value) {
    if (value is String) return value;
    if (value is Map) {
      final name = value['name'] ?? value['slug'] ?? value['nama'];
      return name is String ? name : null;
    }
    return null;
  }
}
