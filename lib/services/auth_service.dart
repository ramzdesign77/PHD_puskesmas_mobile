import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'auth_token_storage.dart';
import 'citizen_report_cache.dart';
import 'tracking_filter_preferences.dart';
import 'profile_service.dart';

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
    AuthTokenStore? tokenStore,
    CitizenReportCache? reportCache,
  }) : _client = client ?? http.Client(),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _tokenStore = tokenStore ?? AuthTokenStorage(),
       _reportCache = reportCache ?? CitizenReportCache.instance;

  static const rolesKey = 'auth_roles';
  static const sessionRoleKey = 'auth_role';
  static const userNameKey = 'auth_user_name';
  static const userPhoneKey = 'auth_user_phone';
  static const userVillageKey = 'auth_user_village';
  static const userRtKey = 'auth_user_rt';
  static const userRwKey = 'auth_user_rw';
  static const accountIdKey = TrackingFilterPreferences.accountIdKey;

  final http.Client _client;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final AuthTokenStore _tokenStore;
  final CitizenReportCache _reportCache;

  Future<void> logout() async {
    final preferences = await _preferencesProvider();
    final accountId = preferences.getString(accountIdKey);
    if (accountId != null && accountId.trim().isNotEmpty) {
      await _reportCache.clearAccount(accountId);
    }
    await _tokenStore.clearAuthentication();
    await preferences.remove(rolesKey);
    await preferences.remove(sessionRoleKey);
    await preferences.remove(userNameKey);
    await preferences.remove(userPhoneKey);
    await preferences.remove(userVillageKey);
    await preferences.remove(userRtKey);
    await preferences.remove(userRwKey);
    await preferences.remove(accountIdKey);
    await ProfileService.clearForSession(preferences);
    await ApiService.clearLegacyCitizenReportData(preferences);
  }

  Uri get _loginUri => _loginUriFor(versioned: true);

  Uri get _legacyLoginUri => _loginUriFor(versioned: false);

  Uri _loginUriFor({required bool versioned}) {
    final baseUri = Uri.parse(AppConfig.apiBaseUrl.trim());
    var apiPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    if (apiPath.endsWith('/api/auth')) {
      apiPath = apiPath.substring(0, apiPath.length - '/auth'.length);
    } else if (apiPath.endsWith('/api/v1')) {
      apiPath = apiPath.substring(0, apiPath.length - '/v1'.length);
    } else if (!apiPath.endsWith('/api')) {
      apiPath = '$apiPath/api';
    }

    final loginPath = versioned ? '$apiPath/v1/login' : '$apiPath/auth/login';
    return baseUri.replace(path: loginPath, query: null, fragment: null);
  }

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = identifier.trim();
    final identifierField = normalizedIdentifier.contains('@')
        ? 'email'
        : 'username';
    final requestBody = jsonEncode({
      'login': normalizedIdentifier,
      'identifier': normalizedIdentifier,
      identifierField: normalizedIdentifier,
      'password': password,
    });
    late http.Response response;
    try {
      response = await _client
          .post(
            _loginUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await _client
            .post(
              _legacyLoginUri,
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 20));
      }
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
    } on FormatException catch (error) {
      throw AuthException('Respons login tidak valid: ${error.message}');
    }
    if (user.roles.isEmpty) {
      throw const AuthException(
        'Akun ini belum memiliki role yang dapat digunakan.',
      );
    }

    final preferences = await _preferencesProvider();
    final oldAccountId = preferences.getString(accountIdKey);
    if (oldAccountId != null &&
        oldAccountId.trim().isNotEmpty &&
        oldAccountId != user.accountId) {
      await _reportCache.clearAccount(oldAccountId);
    }
    await _tokenStore.clearAuthentication();
    await ApiService.clearLegacyCitizenReportData(preferences);
    await _tokenStore.saveToken(user.token);
    final sessionRole = user.roles.firstWhere(
      (role) => role == 'petugas' || role == 'admin',
      orElse: () => user.roles.first,
    );
    final rolesSaved = await preferences.setStringList(rolesKey, user.roles);
    final sessionRoleSaved = await preferences.setString(
      sessionRoleKey,
      sessionRole,
    );
    final accountIdSaved = user.accountId == null
        ? await preferences.remove(accountIdKey)
        : await preferences.setString(accountIdKey, user.accountId!);
    final profileSaved = await ProfileService.replaceForSession(
      preferences,
      name: user.name ?? '',
      email: user.email,
      phone: user.phone,
      username: user.username,
      avatarUrl: user.avatarUrl,
    );
    await preferences.setString(userPhoneKey, user.phone ?? '');
    await preferences.setString(userVillageKey, user.villageName ?? '');
    await preferences.setString(userRtKey, user.rt ?? '');
    await preferences.setString(userRwKey, user.rw ?? '');
    if (!rolesSaved || !sessionRoleSaved || !accountIdSaved || !profileSaved) {
      await logout();
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
