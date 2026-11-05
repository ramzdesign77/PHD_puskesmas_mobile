import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';

class LocalProfile {
  LocalProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.username,
    this.avatarUrl,
    this.avatarFileName,
    this.removeAvatar = false,
    Uint8List? avatarBytes,
  }) : avatarBytes = avatarBytes == null
           ? null
           : Uint8List.fromList(avatarBytes).asUnmodifiableView();

  final String name;
  final String email;
  final String phone;
  final String username;
  final String? avatarUrl;
  final String? avatarFileName;
  final bool removeAvatar;
  final Uint8List? avatarBytes;

  LocalProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? username,
    String? avatarUrl,
    String? avatarFileName,
    Uint8List? avatarBytes,
    bool clearAvatar = false,
  }) => LocalProfile(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    username: username ?? this.username,
    avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
    avatarFileName: clearAvatar ? null : avatarFileName ?? this.avatarFileName,
    avatarBytes: clearAvatar ? null : avatarBytes ?? this.avatarBytes,
    removeAvatar: clearAvatar,
  );
}

class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileService {
  ProfileService({
    Future<SharedPreferences> Function()? preferencesProvider,
    http.Client? client,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _client = client ?? http.Client();

  static const nameKey = 'auth_user_name';
  static const emailKey = 'auth_user_email';
  static const phoneKey = 'auth_user_phone';
  static const usernameKey = 'auth_user_username';
  static const avatarKey = 'auth_user_avatar';
  static const avatarUrlKey = 'auth_user_avatar_url';
  static const _tokenKey = 'auth_token';
  static const _profileKeys = [
    nameKey,
    emailKey,
    phoneKey,
    usernameKey,
    avatarKey,
    avatarUrlKey,
  ];

  final Future<SharedPreferences> Function() _preferencesProvider;
  final http.Client _client;
  String? _loadedToken;

  /// Reads the session cache. The profile screen uses loadRemote for freshness.
  Future<LocalProfile> load({required String fallbackName}) async {
    final preferences = await _preferencesProvider();
    final token = preferences.getString(_tokenKey);
    _loadedToken = null;
    if (token == null || token.trim().isEmpty) {
      throw const ProfileException('Silakan masuk untuk melihat profil.');
    }
    Uint8List? avatarBytes;
    final encodedAvatar = preferences.getString(avatarKey);
    if (encodedAvatar != null && encodedAvatar.isNotEmpty) {
      try {
        avatarBytes = base64Decode(encodedAvatar);
      } on FormatException {
        // Ignore damaged photos from the previous local-only implementation.
      }
    }
    _loadedToken = token;
    final name = preferences.getString(nameKey)?.trim();
    return LocalProfile(
      name: name == null || name.isEmpty ? fallbackName : name,
      email: preferences.getString(emailKey) ?? '',
      phone: preferences.getString(phoneKey) ?? '',
      username: preferences.getString(usernameKey) ?? '',
      avatarUrl: preferences.getString(avatarUrlKey),
      avatarBytes: avatarBytes,
    );
  }

  Future<LocalProfile> loadRemote({required String fallbackName}) =>
      _withNetworkErrors(() async {
        await load(fallbackName: fallbackName);
        final token = _loadedToken!;
        final preferences = await _preferencesProvider();
        _assertCurrentSession(preferences, token);
        final response = await _client
            .get(_profileUri, headers: _headers(token))
            .timeout(const Duration(seconds: 20));
        _assertCurrentSession(preferences, token);
        final profile = _profileFromResponse(response);
        await _cache(preferences, profile, token);
        return profile;
      });

  Future<LocalProfile> save(LocalProfile profile) =>
      _withNetworkErrors(() async {
        final preferences = await _preferencesProvider();
        final token = _loadedToken;
        _assertCurrentSession(preferences, token);
        final cachedAvatar = preferences.getString(avatarKey);
        final avatarChanged =
            profile.removeAvatar ||
            (profile.avatarBytes == null && cachedAvatar != null) ||
            (profile.avatarBytes != null &&
                (cachedAvatar == null ||
                    cachedAvatar != base64Encode(profile.avatarBytes!)));
        final saved = await _updateRemote(
          profile,
          token!,
          uploadAvatar: avatarChanged,
        );
        _assertCurrentSession(preferences, token);
        await _cache(preferences, saved, token);
        return saved;
      });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _withNetworkErrors(() async {
    final preferences = await _preferencesProvider();
    final token = _loadedToken;
    _assertCurrentSession(preferences, token);
    final response = await _client
        .put(
          _passwordUri,
          headers: _headers(token!, json: true),
          body: jsonEncode({
            'current_password': currentPassword,
            'password': newPassword,
            'password_confirmation': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _assertCurrentSession(preferences, token);
    _responseBody(response);
  });

  Map<String, String> _headers(String token, {bool json = false}) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    if (json) 'Content-Type': 'application/json',
  };

  void _assertCurrentSession(SharedPreferences preferences, String? token) {
    if (token == null ||
        _loadedToken != token ||
        preferences.getString(_tokenKey) != token) {
      throw const ProfileException(
        'Sesi akun berubah. Buka kembali profil sebelum menyimpan.',
      );
    }
  }

  Future<LocalProfile> _updateRemote(
    LocalProfile profile,
    String token, {
    required bool uploadAvatar,
  }) async {
    final fields = <String, String>{
      'nama_lengkap': profile.name.trim(),
      'username': profile.username.trim(),
      'email': profile.email.trim(),
      'no_telepon': profile.phone.trim(),
    };
    late http.Response response;
    if (uploadAvatar && profile.avatarBytes != null && !profile.removeAvatar) {
      final request = http.MultipartRequest('POST', _profileUri)
        ..headers.addAll(_headers(token))
        ..fields.addAll({...fields, '_method': 'PUT'})
        ..files.add(
          http.MultipartFile.fromBytes(
            'foto',
            profile.avatarBytes!,
            filename: profile.avatarFileName ?? 'avatar.jpg',
          ),
        );
      response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(const Duration(seconds: 30));
    } else {
      response = await _client
          .put(
            _profileUri,
            headers: _headers(token, json: true),
            body: jsonEncode({
              ...fields,
              if (profile.removeAvatar) 'hapus_foto': true,
            }),
          )
          .timeout(const Duration(seconds: 20));
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.isNotEmpty) {
          return _profileFromResponse(response);
        }
      } on FormatException {
        // Some profile endpoints return an empty successful response.
      }
      return profile;
    }
    return _profileFromResponse(response);
  }

  LocalProfile _profileFromResponse(http.Response response) {
    final body = _responseBody(response);
    final data = body['data'];
    final user = data is Map ? data['user'] : null;
    if (user is! Map ||
        user['nama_lengkap'] is! String ||
        user['username'] is! String ||
        user['email'] is! String) {
      throw const ProfileException('Data profil dari server tidak lengkap.');
    }
    return LocalProfile(
      name: user['nama_lengkap'] as String,
      email: user['email'] as String,
      username: user['username'] as String,
      phone: user['no_telepon'] is String ? user['no_telepon'] as String : '',
      avatarUrl: user['foto_url'] is String ? user['foto_url'] as String : null,
    );
  }

  Map<String, dynamic> _responseBody(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Status codes still identify authentication and server failures.
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ProfileException(
        'Sesi login tidak valid. Silakan masuk kembali.',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? {'success': true};
    }
    String? message;
    final errors = body?['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          message = value.first as String;
          break;
        }
      }
    }
    if (message == null && body?['message'] is String) {
      message = body!['message'] as String;
    }
    if (response.statusCode == 404 || response.statusCode == 405) {
      throw const ProfileException(
        'Endpoint profil belum tersedia. Pastikan backend sudah diperbarui.',
      );
    }
    if (response.statusCode == 429) {
      throw const ProfileException(
        'Terlalu banyak percobaan. Coba lagi dalam satu menit.',
      );
    }
    throw ProfileException(
      message ??
          'Permintaan belum berhasil dikonfirmasi server (${response.statusCode}).',
    );
  }

  Future<void> _cache(
    SharedPreferences preferences,
    LocalProfile profile,
    String token,
  ) async {
    _assertCurrentSession(preferences, token);
    final previous = {
      for (final key in _profileKeys) key: preferences.getString(key),
    };
    final values = <String, String?>{
      nameKey: profile.name,
      emailKey: profile.email,
      phoneKey: profile.phone,
      usernameKey: profile.username,
      avatarUrlKey: profile.avatarUrl,
      avatarKey: profile.avatarBytes == null || profile.removeAvatar
          ? null
          : base64Encode(profile.avatarBytes!),
    };
    try {
      for (final entry in values.entries) {
        _assertCurrentSession(preferences, token);
        final saved = entry.value == null
            ? await preferences.remove(entry.key)
            : await preferences.setString(entry.key, entry.value!);
        if (!saved) throw StateError('Profile cache write failed');
      }
      _assertCurrentSession(preferences, token);
    } catch (error) {
      // A response from a previous account must never replace a new session.
      for (final entry in previous.entries) {
        if (_loadedToken != token || preferences.getString(_tokenKey) != token)
          break;
        try {
          if (entry.value == null) {
            await preferences.remove(entry.key);
          } else {
            await preferences.setString(entry.key, entry.value!);
          }
        } catch (_) {
          // Keep the original error if rollback also fails.
        }
      }
      if (error is ProfileException) rethrow;
      throw const ProfileException(
        'Data sudah diterima server, tetapi salinan di perangkat gagal diperbarui. '
        'Buka kembali halaman profil untuk memuat data terbaru.',
      );
    }
  }

  Future<T> _withNetworkErrors<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on TimeoutException {
      throw const ProfileException(
        'Server terlalu lama merespons. Muat ulang profil untuk memeriksa perubahan.',
      );
    } on http.ClientException {
      throw const ProfileException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  Uri get _profileUri {
    final baseUri = Uri.parse(AppConfig.apiBaseUrl.trim());
    var apiPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    if (apiPath.endsWith('/api/auth')) {
      apiPath = apiPath.substring(0, apiPath.length - '/auth'.length);
    } else if (apiPath.endsWith('/api/v1')) {
      apiPath = apiPath.substring(0, apiPath.length - '/v1'.length);
    } else if (!apiPath.endsWith('/api')) {
      apiPath = '$apiPath/api';
    }
    return baseUri.replace(
      path: '$apiPath/v1/profile',
      query: null,
      fragment: null,
    );
  }

  Uri get _passwordUri =>
      _profileUri.replace(path: '${_profileUri.path}/password');

  static Future<bool> replaceForSession(
    SharedPreferences preferences, {
    required String name,
    String? email,
    String? phone,
    String? username,
    String? avatarUrl,
  }) async {
    var saved = true;
    for (final entry in {
      nameKey: name,
      emailKey: email ?? '',
      phoneKey: phone ?? '',
      usernameKey: username ?? '',
    }.entries) {
      if (!await preferences.setString(entry.key, entry.value)) saved = false;
    }
    if (avatarUrl == null || avatarUrl.isEmpty) {
      if (!await preferences.remove(avatarUrlKey)) saved = false;
    } else if (!await preferences.setString(avatarUrlKey, avatarUrl)) {
      saved = false;
    }
    if (!await preferences.remove(avatarKey)) saved = false;
    return saved;
  }

  static Future<void> clearForSession(SharedPreferences preferences) async {
    for (final key in _profileKeys) {
      await preferences.remove(key);
    }
  }
}
