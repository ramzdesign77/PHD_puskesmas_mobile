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
    final user =
        _asMap(data['user']) ??
        _asMap(json['user']) ??
        _asMap(data['petugas']) ??
        _asMap(json['petugas']) ??
        const <String, dynamic>{};
    final rawToken = _firstNonNull([
      data['token'],
      data['access_token'],
      data['accessToken'],
      data['plainTextToken'],
      json['token'],
      json['access_token'],
      json['accessToken'],
      json['plainTextToken'],
    ]);
    final token = _tokenValue(rawToken);
    final rawRoles = _firstNonNull([
      data['roles'],
      user['roles'],
      json['roles'],
      data['role'],
      user['role'],
      json['role'],
    ]);

    if (token == null) {
      throw const FormatException('Token tidak ditemukan pada respons login.');
    }
    final roles = _roleList(rawRoles);
    if (roles.isEmpty) {
      throw const FormatException(
        'Daftar role tidak valid pada respons login.',
      );
    }

    return UserModel(
      token: token,
      roles: roles,
      name: _stringOrNull(
        user['name'] ?? user['nama_lengkap'] ?? data['name'] ?? json['name'],
      ),
      email: _stringOrNull(user['email']),
    );
  }

  static Object? _firstNonNull(Iterable<Object?> values) {
    for (final value in values) {
      if (value != null) return value;
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _tokenValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    final tokenMap = _asMap(value);
    if (tokenMap == null) return null;
    final nestedToken = _firstNonNull([
      tokenMap['plainTextToken'],
      tokenMap['access_token'],
      tokenMap['accessToken'],
      tokenMap['token'],
    ]);
    if (nestedToken is String && nestedToken.trim().isNotEmpty) {
      return nestedToken.trim();
    }
    return null;
  }

  static List<String> _roleList(Object? value) {
    final values = value is List ? value : [value];
    return values
        .map(_roleName)
        .whereType<String>()
        .map((role) => role.trim().toLowerCase())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String? _stringOrNull(Object? value) => value is String ? value : null;

  static String? _roleName(Object? value) {
    if (value is String) return value;
    if (value is Map) {
      final name =
          value['name'] ?? value['slug'] ?? value['nama'] ?? value['role'];
      return name is String ? name : null;
    }
    return null;
  }
}
