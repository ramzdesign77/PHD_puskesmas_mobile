import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/services/auth_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_auth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AuthTokenStorage.legacyTokenKey: 'legacy-access-token',
      'other_preference': 'keep',
    });
  });

  test('migrates and verifies a legacy token before removing its old copy', () async {
    final secureStorage = MemorySecureKeyValueStorage();
    final tokenStorage = AuthTokenStorage(secureStorage: secureStorage);

    expect(await tokenStorage.getToken(), 'legacy-access-token');

    final preferences = await SharedPreferences.getInstance();
    expect(secureStorage.values['access_token'], 'legacy-access-token');
    expect(preferences.getString(AuthTokenStorage.legacyTokenKey), isNull);
    expect(preferences.getString('other_preference'), 'keep');
  });

  test('saves a verified token only in secure storage', () async {
    final secureStorage = MemorySecureKeyValueStorage();
    final tokenStorage = AuthTokenStorage(secureStorage: secureStorage);

    await tokenStorage.saveToken('new-access-token');

    final preferences = await SharedPreferences.getInstance();
    expect(secureStorage.values['access_token'], 'new-access-token');
    expect(preferences.getString(AuthTokenStorage.legacyTokenKey), isNull);
  });

  test('keeps the legacy token when secure migration fails', () async {
    final secureStorage = MemorySecureKeyValueStorage()..failWrites = true;
    final tokenStorage = AuthTokenStorage(secureStorage: secureStorage);

    await expectLater(
      tokenStorage.getToken(),
      throwsA(isA<AuthTokenStorageException>()),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(AuthTokenStorage.legacyTokenKey),
      'legacy-access-token',
    );
  });

  test('secure storage errors are surfaced without exposing token values', () async {
    final secureStorage = MemorySecureKeyValueStorage()..failReads = true;
    final tokenStorage = AuthTokenStorage(secureStorage: secureStorage);

    await expectLater(
      tokenStorage.getToken(),
      throwsA(
        isA<AuthTokenStorageException>().having(
          (error) => error.message,
          'message',
          isNot(contains('legacy-access-token')),
        ),
      ),
    );
  });

  test('delete removes secure and legacy tokens but keeps app preferences', () async {
    final secureStorage = MemorySecureKeyValueStorage()
      ..values['access_token'] = 'secure-access-token';
    final tokenStorage = AuthTokenStorage(secureStorage: secureStorage);

    await tokenStorage.deleteToken();

    final preferences = await SharedPreferences.getInstance();
    expect(secureStorage.values, isEmpty);
    expect(preferences.getString(AuthTokenStorage.legacyTokenKey), isNull);
    expect(preferences.getString('other_preference'), 'keep');
  });
}
