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
    Uint8List? avatarBytes,
  }) : avatarBytes = avatarBytes == null
           ? null
           : Uint8List.fromList(avatarBytes).asUnmodifiableView();

  final String name;
  final String email;
  final String phone;
  final String username;
  final Uint8List? avatarBytes;

  LocalProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? username,
    Uint8List? avatarBytes,
    bool clearAvatar = false,
  }) => LocalProfile(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    username: username ?? this.username,
    avatarBytes: clearAvatar ? null : avatarBytes ?? this.avatarBytes,
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
  static const _tokenKey = 'auth_token';
  static const _profileKeys = [
    nameKey,
    emailKey,
    phoneKey,
    usernameKey,
    avatarKey,
  ];

  final Future<SharedPreferences> Function() _preferencesProvider;
  final http.Client _client;
  String? _loadedToken;

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
        // A damaged local photo should not prevent the profile from opening.
      }
    }
    _loadedToken = token;
    final name = preferences.getString(nameKey)?.trim();
    return LocalProfile(
      name: name == null || name.isEmpty ? fallbackName : name,
      email: preferences.getString(emailKey) ?? '',
      phone: preferences.getString(phoneKey) ?? '',
      username: preferences.getString(usernameKey) ?? '',
      avatarBytes: avatarBytes,
    );
  }

  Future<void> save(LocalProfile profile) async {
    final preferences = await _preferencesProvider();
    _assertCurrentSession(preferences);
    final previous = {
      for (final key in _profileKeys) key: preferences.getString(key),
    };
    final values = <String, String?>{
      nameKey: profile.name.trim(),
      emailKey: profile.email.trim(),
      phoneKey: profile.phone.trim(),
      usernameKey: profile.username.trim(),
      avatarKey: profile.avatarBytes == null
          ? null
          : base64Encode(profile.avatarBytes!),
    };

    try {
      await _updateRemote(profile, _loadedToken!);
      _assertCurrentSession(preferences);
      for (final entry in values.entries) {
        _assertCurrentSession(preferences);
        final saved = entry.value == null
            ? await preferences.remove(entry.key)
            : await preferences.setString(entry.key, entry.value!);
        if (!saved) {
          throw const ProfileException(
            'Profil belum berhasil disimpan di perangkat. Coba lagi.',
          );
        }
      }
      _assertCurrentSession(preferences);
    } catch (error) {
      // Never restore an earlier account's values over a newer session.
      if (_loadedToken == preferences.getString(_tokenKey)) {
        for (final entry in previous.entries) {
          if (_loadedToken != preferences.getString(_tokenKey)) break;
          try {
            if (entry.value == null) {
              await preferences.remove(entry.key);
            } else {
              await preferences.setString(entry.key, entry.value!);
            }
          } catch (_) {
            // Keep the original failure visible if rollback also fails.
          }
        }
      }
      if (error is ProfileException) rethrow;
      if (error is TimeoutException) {
        throw const ProfileException(
          'Server terlalu lama merespons. Coba simpan kembali.',
        );
      }
      if (error is http.ClientException) {
        throw const ProfileException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        );
      }
      throw const ProfileException(
        'Profil belum berhasil disimpan. Coba lagi.',
      );
    }
  }

  void _assertCurrentSession(SharedPreferences preferences) {
    if (_loadedToken == null ||
        preferences.getString(_tokenKey) != _loadedToken) {
      throw const ProfileException(
        'Sesi akun berubah. Buka kembali profil sebelum menyimpan.',
      );
    }
  }

  Future<void> _updateRemote(LocalProfile profile, String token) async {
    final response = await _client
        .put(
          _profileUri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'nama_lengkap': profile.name.trim(),
            'username': profile.username.trim(),
            'email': profile.email.trim(),
            'no_telepon': profile.phone.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ProfileException(
        'Sesi login tidak valid. Silakan masuk kembali.',
      );
    }

    String? message;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final errors = body['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty && value.first is String) {
              message = value.first as String;
              break;
            }
          }
        }
        final bodyMessage = body['message'];
        if (message == null && bodyMessage is String) {
          message = bodyMessage;
        }
      }
    } on FormatException {
      // The HTTP status still identifies the failed request.
    }
    if (response.statusCode == 404 || response.statusCode == 405) {
      throw const ProfileException(
        'Server belum menyediakan fitur pembaruan profil.',
      );
    }
    throw ProfileException(
      message ?? 'Profil gagal diperbarui di server (${response.statusCode}).',
    );
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

  /// Replaces all local profile values whenever an account signs in.
  static Future<bool> replaceForSession(
    SharedPreferences preferences, {
    required String name,
    String? email,
    String? phone,
    String? username,
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
    if (!await preferences.remove(avatarKey)) saved = false;
    return saved;
  }

  static Future<void> clearForSession(SharedPreferences preferences) async {
    for (final key in _profileKeys) {
      await preferences.remove(key);
    }
  }
}
