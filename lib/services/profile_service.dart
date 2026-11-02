import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

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

/// Profile edits are local to the current login session, not sent to the API.
class ProfileService {
  ProfileService({Future<SharedPreferences> Function()? preferencesProvider})
    : _preferencesProvider =
          preferencesProvider ?? SharedPreferences.getInstance;

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
      throw const ProfileException(
        'Profil belum berhasil disimpan di perangkat. Coba lagi.',
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
