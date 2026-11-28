import 'package:klinik_sanitasi_mobile/services/auth_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryAuthTokenStore implements AuthTokenStore {
  String? token;
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<void> saveToken(String token) async {
    if (failWrites) {
      throw const AuthTokenStorageException('Secure storage unavailable.');
    }
    this.token = token;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(AuthTokenStorage.legacyTokenKey);
  }

  @override
  Future<String?> getToken() async {
    if (failReads) {
      throw const AuthTokenStorageException('Secure storage unavailable.');
    }
    if (token != null) return token;
    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences
        .getString(AuthTokenStorage.legacyTokenKey)
        ?.trim();
    if (legacyToken == null || legacyToken.isEmpty) return null;
    token = legacyToken;
    await preferences.remove(AuthTokenStorage.legacyTokenKey);
    return token;
  }

  @override
  Future<void> deleteToken() async {
    if (failWrites) {
      throw const AuthTokenStorageException('Secure storage unavailable.');
    }
    token = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(AuthTokenStorage.legacyTokenKey);
  }

  @override
  Future<void> clearAuthentication() => deleteToken();
}

class MemorySecureKeyValueStorage implements SecureKeyValueStorage {
  final Map<String, String> values = {};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read({required String key}) async {
    if (failReads) throw StateError('Secure read failed.');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('Secure write failed.');
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
