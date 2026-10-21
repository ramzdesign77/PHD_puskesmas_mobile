import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    http.Client? client,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _client = client ?? http.Client(),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const tokenKey = 'auth_token';
  static const rolesKey = 'auth_roles';
  static const sessionRoleKey = 'auth_role';
  static const userNameKey = 'auth_user_name';

  final http.Client _client;
  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<void> logout() async {
    final preferences = await _preferencesProvider();
    await preferences.remove(tokenKey);
    await preferences.remove(rolesKey);
    await preferences.remove(sessionRoleKey);
    await preferences.remove(userNameKey);
  }

  Uri get _loginUri {
    final baseUri = Uri.parse(AppConfig.apiBaseUrl.trim());
    final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final apiPath = basePath.endsWith('/api/v1')
        ? basePath
        : basePath.endsWith('/api')
        ? '$basePath/v1'
        : '$basePath/api/v1';
    return baseUri.replace(path: '$apiPath/login', query: null, fragment: null);
  }

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = identifier.trim();
    final identifierField = normalizedIdentifier.contains('@')
        ? 'email'
        : 'username';
    late final http.Response response;
    try {
      response = await _client
          .post(
            _loginUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'login': normalizedIdentifier,
              'identifier': normalizedIdentifier,
              identifierField: normalizedIdentifier,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on http.ClientException {
      throw const AuthException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on TimeoutException {
      throw const AuthException('Server terlalu lama merespons. Coba lagi.');
    } on Exception {
      throw const AuthException(
        'Gagal menghubungi server. Pastikan alamat API dan koneksi perangkat benar.',
      );
    }

    final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Format respons bukan objek JSON.');
      }
      body = decoded;
    } on FormatException {
      throw const AuthException('Respons server tidak dapat dibaca.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_errorMessage(body));
    }

    final UserModel user;
    try {
      user = UserModel.fromLoginJson(body);
    } on FormatException {
      throw const AuthException('Respons login tidak memuat token dan role.');
    }
    if (user.roles.isEmpty) {
      throw const AuthException(
        'Akun ini belum memiliki role yang dapat digunakan.',
      );
    }

    final preferences = await _preferencesProvider();
    final sessionRole = user.roles.firstWhere(
      (role) => role == 'petugas' || role == 'admin',
      orElse: () => user.roles.first,
    );
    final tokenSaved = await preferences.setString(tokenKey, user.token);
    final rolesSaved = await preferences.setStringList(rolesKey, user.roles);
    final sessionRoleSaved = await preferences.setString(
      sessionRoleKey,
      sessionRole,
    );
    final userNameSaved = await preferences.setString(
      userNameKey,
      user.name ?? '',
    );
    if (!tokenSaved || !rolesSaved || !sessionRoleSaved || !userNameSaved) {
      throw const AuthException(
        'Sesi login tidak dapat disimpan di perangkat.',
      );
    }

    return user;
  }

  String _errorMessage(Map<String, dynamic> body) {
    final data = body['data'];
    final nestedData = data is Map ? data : null;
    final errors = body['errors'] ?? nestedData?['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty && value.first is String) {
          return value.first as String;
        }
      }
    }

    final message = body['message'] ?? nestedData?['message'];
    if (message is String && message.trim().isNotEmpty) return message;

    return 'Username/email atau kata sandi tidak sesuai.';
  }
}
