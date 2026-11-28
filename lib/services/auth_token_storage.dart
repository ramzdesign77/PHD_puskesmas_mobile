import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AuthTokenStore {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> deleteToken();
  Future<void> clearAuthentication();
}

abstract interface class SecureKeyValueStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class _FlutterSecureKeyValueStorage implements SecureKeyValueStorage {
  _FlutterSecureKeyValueStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class AuthTokenStorage implements AuthTokenStore {
  AuthTokenStorage({
    SecureKeyValueStorage? secureStorage,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _secureStorage =
           secureStorage ??
           _FlutterSecureKeyValueStorage(const FlutterSecureStorage()),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const legacyTokenKey = 'auth_token';
  static const _accessTokenKey = 'access_token';

  final SecureKeyValueStorage _secureStorage;
  final Future<SharedPreferences> Function() _preferencesProvider;

  @override
  Future<void> saveToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw const AuthTokenStorageException('Token sesi tidak valid.');
    }

    try {
      await _secureStorage.write(key: _accessTokenKey, value: normalizedToken);
      final savedToken = await _secureStorage.read(key: _accessTokenKey);
      if (savedToken != normalizedToken) {
        throw const AuthTokenStorageException(
          'Token sesi tidak dapat diverifikasi di penyimpanan aman.',
        );
      }
      await _removeLegacyToken();
    } on AuthTokenStorageException {
      rethrow;
    } catch (_) {
      throw const AuthTokenStorageException(
        'Token sesi tidak dapat disimpan di penyimpanan aman.',
      );
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      final token = await _secureStorage.read(key: _accessTokenKey);
      if (token != null && token.trim().isNotEmpty) {
        await _removeLegacyToken();
        return token;
      }

      final preferences = await _preferencesProvider();
      final legacyToken = preferences.getString(legacyTokenKey)?.trim();
      if (legacyToken == null || legacyToken.isEmpty) return null;

      await _secureStorage.write(key: _accessTokenKey, value: legacyToken);
      final migratedToken = await _secureStorage.read(key: _accessTokenKey);
      if (migratedToken != legacyToken) {
        throw const AuthTokenStorageException(
          'Token lama belum dapat diverifikasi di penyimpanan aman.',
        );
      }
      await _removeLegacyToken(preferences);
      return migratedToken;
    } on AuthTokenStorageException {
      rethrow;
    } catch (_) {
      throw const AuthTokenStorageException(
        'Sesi tidak dapat dibaca dari penyimpanan aman.',
      );
    }
  }

  @override
  Future<void> deleteToken() => clearAuthentication();

  @override
  Future<void> clearAuthentication() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      if (await _secureStorage.read(key: _accessTokenKey) != null) {
        throw const AuthTokenStorageException(
          'Token sesi tidak dapat dihapus dari penyimpanan aman.',
        );
      }
      await _removeLegacyToken();
    } on AuthTokenStorageException {
      rethrow;
    } catch (_) {
      throw const AuthTokenStorageException(
        'Sesi tidak dapat dihapus dari penyimpanan aman.',
      );
    }
  }

  Future<void> _removeLegacyToken([SharedPreferences? preferences]) async {
    final store = preferences ?? await _preferencesProvider();
    if (!store.containsKey(legacyTokenKey)) return;
    final removed = await store.remove(legacyTokenKey);
    if (!removed || store.containsKey(legacyTokenKey)) {
      throw const AuthTokenStorageException(
        'Token lama belum dapat dihapus dari penyimpanan perangkat.',
      );
    }
  }
}

class AuthTokenStorageException implements Exception {
  const AuthTokenStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
